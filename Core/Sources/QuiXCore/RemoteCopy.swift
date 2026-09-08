import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Copie vérifiée d'un fichier servi par la caméra en HTTP.
///
/// Mêmes garanties que `VerifiedCopy`, par les mêmes moyens : écriture dans un temporaire,
/// empreinte calculée pendant la réception, relecture du fichier écrit, renommage seulement si tout
/// concorde. La source n'est jamais touchée — ici c'est structurel, on ne fait que des `GET`.
///
/// La taille attendue vient du catalogue de la caméra, pas d'un `stat` : c'est elle qui permet de
/// détecter un transfert tronqué par un débranchement en cours de route.
public enum RemoteVerifiedCopy {

    @discardableResult
    public static func copy(
        from source: URL,
        expectedSize: UInt64,
        modified: Date?,
        to destination: URL,
        fileManager: FileManager = .default,
        isCancelled: () -> Bool = { false },
        progress: (UInt64) -> Void = { _ in }
    ) throws -> UInt32 {
        // La réception est synchrone : les fermetures ne survivent pas à cet appel, mais
        // `URLSession` exige des `@escaping`. `withoutActuallyEscaping` dit exactement cela,
        // plutôt que d'imposer des `@escaping` à tout l'appelant.
        try withoutActuallyEscaping(isCancelled) { isCancelled in
        try withoutActuallyEscaping(progress) { progress in

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CopyFailure.destinationExists(destination)
        }

        let temporary = URL(fileURLWithPath: destination.path + VerifiedCopy.partialSuffix)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }
        guard fileManager.createFile(atPath: temporary.path, contents: nil) else {
            throw CopyFailure.destinationExists(temporary)
        }

        let sink = try Sink(path: temporary, isCancelled: isCancelled, progress: progress)
        do {
            try sink.download(source)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        guard sink.written == expectedSize else {
            try? fileManager.removeItem(at: temporary)
            throw CopyFailure.sizeMismatch(expected: expectedSize, written: sink.written)
        }

        let destinationCRC: UInt32
        do {
            destinationCRC = try VerifiedCopy.checksum(of: temporary)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        guard destinationCRC == sink.crc.value else {
            try? fileManager.removeItem(at: temporary)
            throw CopyFailure.checksumMismatch(source: sink.crc.value, destination: destinationCRC)
        }

        // Même règle que pour une carte : le clip garde sa date de tournage, sans quoi le tri par
        // date dans le Finder ne dirait plus rien.
        if let modified {
            try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: temporary.path)
        }

        try fileManager.moveItem(at: temporary, to: destination)
        return sink.crc.value
        }
        }
    }

    /// Réception en flux : les octets sont écrits et empreintés au fil de l'eau, jamais accumulés
    /// en mémoire. Un clip GoPro pèse couramment plusieurs gigaoctets.
    private final class Sink: NSObject, URLSessionDataDelegate {
        private let handle: FileHandle
        private let semaphore = DispatchSemaphore(value: 0)

        // Optionnelles, et relâchées dès la fin du transfert.
        //
        // `URLSession` retient son délégué au-delà de `download()` — `finishTasksAndInvalidate()`
        // rend la main avant d'avoir relâché quoi que ce soit. Garder ici des fermetures que
        // l'appelant a déclarées non-échappantes les ferait survivre à leur portée, et Swift arrête
        // le programme quand il le détecte. On les lâche donc avant de rendre la main.
        private var isCancelled: (() -> Bool)?
        private var progress: ((UInt64) -> Void)?

        private(set) var crc = CRC32()
        private(set) var written: UInt64 = 0
        private var failure: Error?
        private var status: Int = 0

        init(path: URL, isCancelled: @escaping () -> Bool, progress: @escaping (UInt64) -> Void) throws {
            self.handle = try FileHandle(forWritingTo: path)
            self.isCancelled = isCancelled
            self.progress = progress
        }

        func download(_ url: URL) throws {
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
            var request = URLRequest(url: url)
            // Un clip de plusieurs gigaoctets prend son temps ; c'est l'absence de données qui doit
            // faire échouer, pas la durée totale.
            request.timeoutInterval = 3600
            let task = session.dataTask(with: request)
            task.resume()
            semaphore.wait()
            // Passé ce point, plus aucun rappel de délégué ne touche aux fermetures : la
            // sémaphore n'est levée que par `didCompleteWithError`, qui clôt le transfert.
            isCancelled = nil
            progress = nil
            session.finishTasksAndInvalidate()
            try? handle.close()

            if let failure { throw failure }
            guard (200...299).contains(status) else {
                throw GoProCamera.CameraError.badStatus(status)
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                        didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            status = (response as? HTTPURLResponse)?.statusCode ?? 0
            completionHandler(.allow)
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            if isCancelled?() == true {
                failure = CopyFailure.cancelled
                dataTask.cancel()
                return
            }
            crc.update(data)
            try? handle.write(contentsOf: data)
            written += UInt64(data.count)
            progress?(written)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if failure == nil, let error {
                // Une annulation demandée par nous a déjà posé `CopyFailure.cancelled` ; on ne la
                // remplace pas par le « cancelled » générique d'URLSession, moins parlant.
                failure = error
            }
            semaphore.signal()
        }
    }
}

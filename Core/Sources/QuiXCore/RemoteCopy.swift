import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Copie vérifiée d'un fichier servi par la caméra en HTTP, **reprenable**.
///
/// Mêmes garanties que `VerifiedCopy` : écriture dans un temporaire, empreinte calculée pendant la
/// réception, relecture du fichier écrit, renommage seulement si tout concorde. La source n'est
/// jamais touchée — ici c'est structurel, on ne fait que des `GET`.
///
/// **La reprise.** Un clip GoPro pèse des gigaoctets et l'USB se débranche ; recommencer de zéro
/// coûtait cher alors que la caméra honore `Range`. Un transfert interrompu laisse donc son
/// `.quix-partiel`, et le suivant repart de l'octet où il s'était arrêté.
///
/// Ce qui rendait la reprise délicate, c'est la chaîne de vérification. L'empreinte d'origine se
/// calcule sur les octets **reçus du réseau** ; la relecture finale la compare à ce qui est
/// réellement sur le disque. Reprendre naïvement casserait ce lien : les octets du premier
/// transfert seraient relus du disque et comparés à eux-mêmes, ce qui ne prouve plus rien. D'où le
/// petit fichier d'état posé à côté du temporaire, qui retient l'empreinte des octets reçus. À la
/// reprise on vérifie que le temporaire porte toujours exactement cette empreinte — le lien est
/// rétabli — et sinon on repart de zéro.
public enum RemoteVerifiedCopy {

    /// Suffixe du fichier d'état, à côté du `.quix-partiel`.
    static let stateSuffix = ".etat"

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
        let stateFile = URL(fileURLWithPath: temporary.path + stateSuffix)

        try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)

        let resume = resumePoint(temporary: temporary, state: stateFile,
                                 expectedSize: expectedSize, fileManager: fileManager)
        if resume == nil {
            try? fileManager.removeItem(at: temporary)
            try? fileManager.removeItem(at: stateFile)
            guard fileManager.createFile(atPath: temporary.path, contents: nil) else {
                throw CopyFailure.destinationExists(temporary)
            }
        }

        let sink = try Sink(path: temporary,
                            startingAt: resume?.bytes ?? 0,
                            crc: resume.map { CRC32(resuming: $0.crc) } ?? CRC32(),
                            isCancelled: isCancelled,
                            progress: progress)
        do {
            try sink.download(source)
        } catch {
            // Un transfert coupé garde ses octets : c'est tout l'intérêt. On note où on en est
            // pour que la prochaine tentative reparte de là.
            writeState(sink, to: stateFile)
            throw error
        }

        guard sink.written == expectedSize else {
            // Une taille qui ne tombe pas juste n'est pas une interruption : les octets reçus ne
            // valent rien, on ne propose pas de reprendre dessus.
            try? fileManager.removeItem(at: temporary)
            try? fileManager.removeItem(at: stateFile)
            throw CopyFailure.sizeMismatch(expected: expectedSize, written: sink.written)
        }

        let destinationCRC: UInt32
        do {
            destinationCRC = try VerifiedCopy.checksum(of: temporary)
        } catch {
            try? fileManager.removeItem(at: temporary)
            try? fileManager.removeItem(at: stateFile)
            throw error
        }

        guard destinationCRC == sink.crc.value else {
            try? fileManager.removeItem(at: temporary)
            try? fileManager.removeItem(at: stateFile)
            throw CopyFailure.checksumMismatch(source: sink.crc.value, destination: destinationCRC)
        }

        // Même règle que pour une carte : le clip garde sa date de tournage, sans quoi le tri par
        // date dans le Finder ne dirait plus rien.
        if let modified {
            try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: temporary.path)
        }

        try? fileManager.removeItem(at: stateFile)
        try fileManager.moveItem(at: temporary, to: destination)
        return sink.crc.value
        }
        }
    }

    /// Y a-t-il un transfert à reprendre, et si oui à partir d'où ?
    ///
    /// Rend `nil` — donc « repartir de zéro » — à la moindre incohérence. Un octet douteux repris
    /// coûterait un clip corrompu qui passerait la vérification finale sans rien signaler, ce qui
    /// est bien pire que de retélécharger.
    static func resumePoint(
        temporary: URL, state: URL, expectedSize: UInt64, fileManager: FileManager
    ) -> (bytes: UInt64, crc: UInt32)? {

        guard let raw = try? String(contentsOf: state, encoding: .utf8) else { return nil }
        let fields = raw.split(separator: "\n").map(String.init)
        guard fields.count == 3, fields[0] == "quix 1",
              let bytes = UInt64(fields[1]), let crc = UInt32(fields[2]),
              bytes > 0, bytes < expectedSize,
              let onDisk = ImportPlanner.sizeOnDisk(temporary), onDisk == bytes
        else { return nil }

        // Le contrôle qui donne son sens à la reprise : les octets encore sur le disque sont-ils
        // bien ceux qu'on avait reçus ? Sans lui, la vérification finale comparerait le disque à
        // lui-même pour toute la partie déjà téléchargée.
        guard let actual = try? VerifiedCopy.checksum(of: temporary), actual == crc else {
            return nil
        }
        return (bytes, crc)
    }

    private static func writeState(_ sink: Sink, to file: URL) {
        guard sink.written > 0 else { return }
        try? "quix 1\n\(sink.written)\n\(sink.crc.value)\n".write(to: file, atomically: true,
                                                                  encoding: .utf8)
    }

    /// Réception en flux : les octets sont écrits et empreintés au fil de l'eau, jamais accumulés
    /// en mémoire. Un clip GoPro pèse couramment plusieurs gigaoctets.
    /// `@unchecked Sendable` parce que la Foundation de Linux exige un délégué `Sendable`, et que
    /// l'état mutable ci-dessous n'est de toute façon touché que par un seul fil à la fois : les
    /// rappels du délégué arrivent sur une file sérielle, et `download()` n'y revient qu'après la
    /// sémaphore, levée par le dernier d'entre eux.
    private final class Sink: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let handle: FileHandle
        private let semaphore = DispatchSemaphore(value: 0)
        private let resumeFrom: UInt64

        // Optionnelles, et relâchées dès la fin du transfert.
        //
        // `URLSession` retient son délégué au-delà de `download()` — `finishTasksAndInvalidate()`
        // rend la main avant d'avoir relâché quoi que ce soit. Garder ici des fermetures que
        // l'appelant a déclarées non-échappantes les ferait survivre à leur portée, et Swift arrête
        // le programme quand il le détecte. On les lâche donc avant de rendre la main.
        private var isCancelled: (() -> Bool)?
        private var progress: ((UInt64) -> Void)?

        private(set) var crc: CRC32
        private(set) var written: UInt64
        private var failure: Error?
        private var status: Int = 0

        init(path: URL, startingAt offset: UInt64, crc: CRC32,
             isCancelled: @escaping () -> Bool, progress: @escaping (UInt64) -> Void) throws {
            self.handle = try FileHandle(forWritingTo: path)
            self.resumeFrom = offset
            self.crc = crc
            self.written = offset
            self.isCancelled = isCancelled
            self.progress = progress
            super.init()
            try handle.seek(toOffset: offset)
        }

        func download(_ url: URL) throws {
            let session = URLSession(configuration: HTTP.downloadConfiguration(),
                                     delegate: self, delegateQueue: nil)
            var request = URLRequest(url: url)
            // Un clip de plusieurs gigaoctets prend son temps ; c'est l'absence de données qui doit
            // faire échouer, pas la durée totale.
            request.timeoutInterval = 3600
            if resumeFrom > 0 {
                request.setValue("bytes=\(resumeFrom)-", forHTTPHeaderField: "Range")
            }
            let task = session.dataTask(with: request)
            task.resume()
            waitForCompletion(of: task)
            // Passé ce point, plus aucun rappel de délégué ne touche aux fermetures : la
            // sémaphore n'est levée que par `didCompleteWithError`, qui clôt le transfert.
            isCancelled = nil
            progress = nil
            session.finishTasksAndInvalidate()
            try? handle.synchronize()
            try? handle.close()

            if let failure { throw failure }
            guard (200...299).contains(status) else {
                throw GoProCamera.CameraError.badStatus(status)
            }
        }

        /// Combien de temps un transfert peut se taire avant qu'on le déclare perdu.
        ///
        /// On ne borne pas la durée totale — un clip de plusieurs gigaoctets prend légitimement
        /// son temps — mais l'absence de progression. Sans cette borne, une attente sans fin :
        /// un câble arraché au mauvais moment gelait l'import, sans erreur et sans reprise
        /// possible, puisque plus rien n'avançait ni n'échouait.
        static let stallTimeout: TimeInterval = 120

        private func waitForCompletion(of task: URLSessionDataTask) {
            var lastCount: Int64 = -1
            var lastProgress = Date()

            while semaphore.wait(timeout: .now() + 5) == .timedOut {
                let received = task.countOfBytesReceived
                if received != lastCount {
                    lastCount = received
                    lastProgress = Date()
                } else if Date().timeIntervalSince(lastProgress) > Sink.stallTimeout {
                    task.cancel()
                    // `cancel()` provoque `didCompleteWithError` : on l'attend, sans s'éterniser
                    // si ce rappel ne venait pas non plus.
                    _ = semaphore.wait(timeout: .now() + 10)
                    return
                }
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                        didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            status = (response as? HTTPURLResponse)?.statusCode ?? 0

            // On a demandé une reprise et le serveur renvoie tout depuis le début : il ignore
            // `Range`. Plutôt que d'ajouter le fichier entier à la suite de ce qu'on avait, on
            // repart de zéro — c'est plus lent, mais c'est le seul résultat correct.
            if resumeFrom > 0, status == 200 {
                try? handle.truncate(atOffset: 0)
                try? handle.seek(toOffset: 0)
                crc = CRC32()
                written = 0
            }
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

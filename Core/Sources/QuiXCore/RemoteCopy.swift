import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A verified, **resumable** copy of a file served by the camera over HTTP.
///
/// The same guarantees as `VerifiedCopy`: writing to a temporary file, a checksum computed while
/// receiving, the written file read back, and a rename only if everything agrees. The source is
/// never touched — here that is structural, we only ever issue `GET`s.
///
/// **Resuming.** A GoPro clip weighs gigabytes and USB cables come loose; starting from zero was
/// expensive when the camera honours `Range`. An interrupted transfer therefore leaves its
/// `.quix-partiel` behind, and the next one restarts from the byte where it stopped.
///
/// What made resuming delicate is the verification chain. The original checksum is computed over
/// the bytes **received from the network**; the final read-back compares it with what is really on
/// disk. Resuming naively would break that link: the first transfer's bytes would be read back
/// from disk and compared with themselves, which proves nothing any more. Hence the small state
/// file laid beside the temporary one, holding the checksum of the bytes received. On resuming we
/// check that the temporary file still carries exactly that checksum — the link is re-established
/// — and otherwise we start over.
public enum RemoteVerifiedCopy {

    /// Suffix of the state file, beside the `.quix-partiel`.
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
        // Receiving is synchronous: the closures do not outlive this call, but `URLSession`
        // requires `@escaping` ones. `withoutActuallyEscaping` says exactly that, rather than
        // forcing `@escaping` on every caller.
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
            // An interrupted transfer keeps its bytes: that is the whole point. We record where we
            // are so the next attempt starts from there.
            writeState(sink, to: stateFile)
            throw error
        }

        guard sink.written == expectedSize else {
            // A size that does not come out right is not an interruption: the bytes received are
            // worth nothing, and we do not offer to resume on top of them.
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

        // Same rule as for a card: the clip keeps its shooting date, without which sorting by date
        // in the Finder would say nothing any more.
        if let modified {
            try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: temporary.path)
        }

        try? fileManager.removeItem(at: stateFile)
        try fileManager.moveItem(at: temporary, to: destination)
        return sink.crc.value
        }
        }
    }

    /// Is there a transfer to resume, and if so from where?
    ///
    /// Returns `nil` — meaning "start from zero" — at the slightest inconsistency. One doubtful
    /// byte resumed would cost a corrupted clip that passed the final verification without a word,
    /// which is far worse than downloading again.
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

        // The check that gives resuming its meaning: are the bytes still on disk the ones we
        // received? Without it, the final verification would compare the disk with itself for the
        // whole part already downloaded.
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

    /// Streamed receiving: bytes are written and checksummed as they arrive, never accumulated in
    /// memory. A GoPro clip commonly weighs several gigabytes.
    /// `@unchecked Sendable` because Linux's Foundation requires a `Sendable` delegate, and the
    /// mutable state below is in any case only touched by one thread at a time: the delegate's
    /// callbacks arrive on a serial queue, and `download()` only comes back to it after the
    /// semaphore, raised by the last of them.
    private final class Sink: NSObject, URLSessionDataDelegate, @unchecked Sendable {
        private let handle: FileHandle
        private let semaphore = DispatchSemaphore(value: 0)
        private let resumeFrom: UInt64

        // Optional, and released as soon as the transfer ends.
        //
        // `URLSession` holds on to its delegate beyond `download()` — `finishTasksAndInvalidate()`
        // returns before it has released anything. Keeping closures here that the caller declared
        // non-escaping would make them outlive their scope, and Swift stops the program when it
        // detects that. So we let them go before returning.
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
            // A clip of several gigabytes takes its time; it is the absence of data that must fail,
            // not the total duration.
            request.timeoutInterval = 3600
            if resumeFrom > 0 {
                request.setValue("bytes=\(resumeFrom)-", forHTTPHeaderField: "Range")
            }
            let task = session.dataTask(with: request)
            task.resume()
            waitForCompletion(of: task)
            // Past this point no delegate callback touches the closures any more: the semaphore is
            // only raised by `didCompleteWithError`, which closes the transfer.
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

        /// How long a transfer may stay silent before we declare it lost.
        ///
        /// The total duration is not bounded — a clip of several gigabytes legitimately takes its
        /// time — but the absence of progress is. Without that bound, an endless wait: a cable
        /// pulled at the wrong moment froze the import, with no error and no way to resume, since
        /// nothing was advancing and nothing was failing.
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
                    // `cancel()` triggers `didCompleteWithError`: we wait for it, without hanging
                    // about if that callback never came either.
                    _ = semaphore.wait(timeout: .now() + 10)
                    return
                }
            }
        }

        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                        didReceive response: URLResponse,
                        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            status = (response as? HTTPURLResponse)?.statusCode ?? 0

            // We asked to resume and the server is sending everything from the start: it ignores
            // `Range`. Rather than append the whole file to what we had, we start from zero — it is
            // slower, but it is the only correct outcome.
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
                // A cancellation we asked for has already set `CopyFailure.cancelled`; we do not
                // replace it with URLSession's generic "cancelled", which says less.
                failure = error
            }
            semaphore.signal()
        }
    }
}

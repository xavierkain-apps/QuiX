import Foundation

public enum CopyFailure: Error, Equatable {
    /// A file already exists at the destination. We never overwrite it.
    case destinationExists(URL)
    /// The number of bytes written does not match the size announced by the source.
    case sizeMismatch(expected: UInt64, written: UInt64)
    /// Reading the written file back does not give the same checksum as the source.
    case checksumMismatch(source: UInt32, destination: UInt32)
    case cancelled
}

/// A verified copy of one file.
///
/// **This function never touches the source.** It opens for reading, writes elsewhere, and calls
/// `removeItem` only on its own temporary file. That is the rule that matters: a failed import can
/// be recovered from, an erased card cannot.
///
/// How it goes:
///
/// 1. Writing goes to a temporary file, not straight to the destination. An interrupted copy
///    leaves an obvious `.quix-partiel`, not an `.MP4` of plausible size and truncated content
///    that the Finder would show as a valid clip.
/// 2. The source's checksum is computed **while** copying, without reading it again.
/// 3. The written file is read back to recompute its own. That is where verification happens:
///    comparing the source with itself would prove nothing.
/// 4. Only if everything agrees does the temporary file take its final name.
public enum VerifiedCopy {

    public static let partialSuffix = ".quix-partiel"

    /// Block size. Large enough for the per-call cost to disappear, small enough for progress to
    /// stay smooth and memory not to climb on a loaded server.
    public static let chunkSize = 4 * 1024 * 1024

    @discardableResult
    public static func copy(
        from source: URL,
        to destination: URL,
        fileManager: FileManager = .default,
        isCancelled: () -> Bool = { false },
        progress: (UInt64) -> Void = { _ in }
    ) throws -> UInt32 {

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CopyFailure.destinationExists(destination)
        }

        let expectedSize = ImportPlanner.sizeOnDisk(source) ?? 0
        let temporary = URL(fileURLWithPath: destination.path + partialSuffix)

        try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        // A temporary file left by an earlier attempt is ours, and ours alone.
        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }
        guard fileManager.createFile(atPath: temporary.path, contents: nil) else {
            throw CopyFailure.destinationExists(temporary)
        }

        var sourceCRC = CRC32()
        var written: UInt64 = 0

        do {
            let input = try FileHandle(forReadingFrom: source)
            let output = try FileHandle(forWritingTo: temporary)

            while true {
                if isCancelled() {
                    try? input.close()
                    try? output.close()
                    try? fileManager.removeItem(at: temporary)
                    throw CopyFailure.cancelled
                }
                guard let block = try input.read(upToCount: chunkSize), !block.isEmpty else { break }
                sourceCRC.update(block)
                try output.write(contentsOf: block)
                written += UInt64(block.count)
                progress(written)
            }

            try output.synchronize()
            try output.close()
            try input.close()
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        guard written == expectedSize else {
            try? fileManager.removeItem(at: temporary)
            throw CopyFailure.sizeMismatch(expected: expectedSize, written: written)
        }

        let destinationCRC: UInt32
        do {
            destinationCRC = try checksum(of: temporary)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        guard destinationCRC == sourceCRC.value else {
            try? fileManager.removeItem(at: temporary)
            throw CopyFailure.checksumMismatch(source: sourceCRC.value, destination: destinationCRC)
        }

        // The shooting date follows the copy: without it, every imported clip would bear the date
        // of the import and sorting by date in the Finder would say nothing any more.
        if let modified = try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: temporary.path)
        }

        try fileManager.moveItem(at: temporary, to: destination)
        return sourceCRC.value
    }

    /// The checksum of a file already written.
    public static func checksum(of url: URL) throws -> UInt32 {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var crc = CRC32()
        while let block = try handle.read(upToCount: chunkSize), !block.isEmpty {
            crc.update(block)
        }
        return crc.value
    }
}

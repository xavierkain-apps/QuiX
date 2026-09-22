import Foundation

/// Random-access reading over a sequence of bytes.
///
/// The abstraction exists for one precise reason: it lets the MP4 atom walk be tested against
/// bytes built in memory, without writing a single file. The cases that matter — 64-bit size,
/// zero size, truncated atom — are painful to produce on disk and trivial to write into an
/// array.
public protocol ByteReader {
    /// Total size in bytes.
    var length: UInt64 { get }

    /// Reads at most `count` bytes from `offset`. May return fewer near the end of the source,
    /// and an empty array past it. Does not throw for an out-of-bounds read: it is up to the atom
    /// walk to decide what a truncated file means.
    func read(at offset: UInt64, count: Int) throws -> [UInt8]
}

extension ByteReader {
    /// Reads exactly `count` bytes, or returns `nil` if there are not that many.
    func readExact(at offset: UInt64, count: Int) throws -> [UInt8]? {
        let bytes = try read(at: offset, count: count)
        return bytes.count == count ? bytes : nil
    }
}

/// A reader over an array of bytes in memory.
public struct DataByteReader: ByteReader, Sendable {
    private let bytes: [UInt8]

    public init(_ bytes: [UInt8]) { self.bytes = bytes }
    public init(_ data: Data) { self.bytes = [UInt8](data) }

    public var length: UInt64 { UInt64(bytes.count) }

    public func read(at offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0, offset < UInt64(bytes.count) else { return [] }
        let start = Int(offset)
        let end = min(start + count, bytes.count)
        return Array(bytes[start..<end])
    }
}

/// A reader over a file, by seeking and short reads.
///
/// In GoPro files the `moov` atom closes the file: the ~90 MB of `mdat` are skipped by their size
/// instead of being read. A full scan costs a handful of seeks and about 34 KB read, whatever the
/// size of the clip. That is what makes sorting free — see `docs/HILIGHT.md`.
public final class FileByteReader: ByteReader {
    private let handle: FileHandle
    public let length: UInt64

    public init(url: URL) throws {
        // The size is read before opening: if that fails, no descriptor has been opened and there
        // is nothing to close — an `init` that throws never calls `deinit`.
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        self.length = UInt64(values.fileSize ?? 0)
        self.handle = try FileHandle(forReadingFrom: url)
    }

    deinit { try? handle.close() }

    public func read(at offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0, offset < length else { return [] }
        try handle.seek(toOffset: offset)
        guard let data = try handle.read(upToCount: count) else { return [] }
        return [UInt8](data)
    }
}

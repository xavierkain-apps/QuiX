import Foundation

/// An MP4 atom located in the file: its type, and where its payload lives.
///
/// The contents are never kept, only positions. A 34 KB `moov` is read only if somebody asks for
/// it, and `mdat` never is.
public struct MP4Box: Equatable, Sendable {
    /// The four-character code, as written in the file (`moov`, `udta`, `HMMT`…).
    public let type: String
    /// Position of the payload's first byte, header excluded.
    public let payloadOffset: UInt64
    /// Length of the payload, header excluded.
    public let payloadLength: UInt64

    var payloadEnd: UInt64 { payloadOffset + payloadLength }
}

public enum MP4 {

    /// Walks the atoms of a `start..<end` range without descending into their children.
    ///
    /// Three header shapes exist, and all three turn up in real files:
    ///
    /// - a 32-bit size, 8-byte header — the common case;
    /// - size `1`, with the real size following in 64 bits, 16-byte header — an `mdat` over 4 GB,
    ///   which a long take in 5.3K eventually produces;
    /// - size `0`, the atom runs to the end of the range. Written by an interrupted recorder.
    ///   **An `mdat` of zero size swallows the `moov` that follows it**: the file then has no
    ///   readable tags, which reads as "no highlights", never as "error".
    ///
    /// The walk stops as soon as a header is inconsistent rather than trying to recover: on a
    /// damaged file, better to return the atoms already read than to go hunting for bytes at
    /// random.
    public static func boxes(in reader: ByteReader, from start: UInt64, to end: UInt64) throws -> [MP4Box] {
        var result: [MP4Box] = []
        var position = start

        while position + 8 <= end {
            guard let header = try reader.readExact(at: position, count: 8) else { break }

            let declared = UInt64(be32(header, 0))
            let type = fourCC(header, 4)
            var headerSize: UInt64 = 8
            var size = declared

            if declared == 1 {
                guard let extended = try reader.readExact(at: position + 8, count: 8) else { break }
                size = be64(extended, 0)
                headerSize = 16
            } else if declared == 0 {
                size = end - position
            }

            // An atom smaller than its own header, or one that runs past the range, is the sign of
            // a truncated file or of bytes that are not MP4. We return what we have.
            guard size >= headerSize, position + size <= end else { break }

            result.append(MP4Box(type: type,
                                 payloadOffset: position + headerSize,
                                 payloadLength: size - headerSize))

            position += size
        }

        return result
    }

    /// Walks the top-level atoms of the whole file.
    public static func topLevelBoxes(in reader: ByteReader) throws -> [MP4Box] {
        try boxes(in: reader, from: 0, to: reader.length)
    }

    /// Walks the children of a container atom.
    public static func children(of box: MP4Box, in reader: ByteReader) throws -> [MP4Box] {
        try boxes(in: reader, from: box.payloadOffset, to: box.payloadEnd)
    }

    // MARK: - Reading big-endian integers

    static func be32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    static func be64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 { value = value << 8 | UInt64(bytes[offset + index]) }
        return value
    }

    static func fourCC(_ bytes: [UInt8], _ offset: Int) -> String {
        String(bytes[offset..<(offset + 4)].map { Character(UnicodeScalar($0)) })
    }
}

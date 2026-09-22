import Foundation

/// A CRC-32 checksum (IEEE polynomial), computed as a stream.
///
/// The goal is to catch a damaged copy — a card pulled out mid-way, an unreadable sector, a full
/// disk — not to resist someone trying to fool the verification. A CRC-32 is ample for that, and
/// it costs little enough to be computed over every byte of every file without showing beside the
/// copy time.
public struct CRC32: Sendable, Equatable {

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    private var state: UInt32 = 0xFFFF_FFFF

    public init() {}

    /// Resumes an interrupted computation from its partial checksum.
    ///
    /// Used when resuming a download: the bytes already received are not read again from the
    /// network, but their checksum picks up where it left off.
    public init(resuming value: UInt32) {
        state = value ^ 0xFFFF_FFFF
    }

    public mutating func update(_ data: Data) {
        var state = self.state
        data.withUnsafeBytes { raw in
            for byte in raw {
                state = CRC32.table[Int((state ^ UInt32(byte)) & 0xFF)] ^ (state >> 8)
            }
        }
        self.state = state
    }

    public mutating func update(bytes: [UInt8]) {
        var state = self.state
        for byte in bytes {
            state = CRC32.table[Int((state ^ UInt32(byte)) & 0xFF)] ^ (state >> 8)
        }
        self.state = state
    }

    public var value: UInt32 { state ^ 0xFFFF_FFFF }
}

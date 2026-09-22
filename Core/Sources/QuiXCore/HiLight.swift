import Foundation

/// What a HiLight read found in a file.
///
/// The only sorting criterion is `isHighlighted`. Everything else is information for the
/// interface: nothing here may stop an import from completing.
public struct HiLightScan: Equatable, Sendable {

    /// Tagged moments, in milliseconds from the start **of this chapter** — not of the take.
    /// A long take cut into chapters restarts the counter in every file.
    public let moments: [UInt32]

    /// What got in the way of the read, if anything. Never a reason to skip a file at import.
    public let anomaly: Anomaly?

    public init(moments: [UInt32], anomaly: Anomaly? = nil) {
        self.moments = moments
        self.anomaly = anomaly
    }

    /// A file is highlighted when it carries **at least one moment**.
    ///
    /// Emphatically not "when the HMMT atom exists": the camera writes the same 332-byte atom
    /// on every clip, tagged or not. See `HMMT.parse`.
    public var isHighlighted: Bool { !moments.isEmpty }

    /// No tags, and nothing to report.
    public static let none = HiLightScan(moments: [])

    public enum Anomaly: Equatable, Sendable {
        /// No top-level `moov` atom. A truncated file, or not an MP4 at all.
        case noMoov
        /// `moov` without `udta/HMMT`. Normal for a remuxed file or one from another camera.
        case noHMMT
        /// `HMMT` too short to carry even its own counter.
        case truncatedHMMT
        /// The counter announces more moments than the atom has slots. We read what fits.
        case countExceedsSlots(declared: UInt32, slots: Int)
    }
}

/// Decoding of the `moov/udta/HMMT` atom, where the GoPro writes the HiLight tags pressed while
/// filming.
///
/// ```
/// payload, 324 bytes on a HERO12, invariant:
///   [0..3]     uint32 big-endian   number of moments
///   [4..323]   uint32 big-endian × 80   slots, filled with zeros
/// ```
///
/// **The trap lives here.** GoPro preallocates 80 slots: the clip without a single highlight
/// carries exactly the same 332-byte atom as the tagged one, and only the counter differs.
/// Inferring the number of moments from the size of the atom would give 80 on *every* clip, send
/// everything to `Highlights/` and cost the app its only reason to exist — without raising a
/// single error. The `hero12-sans-highlight.mp4` fixture exists so that it never happens.
public enum HMMT {

    static let atomType = "HMMT"

    /// Read ceiling for the payload. See `HiLightReader.scan`.
    static let maximumPayloadLength: UInt64 = 65_536

    /// Decodes an HMMT payload that has already been read.
    public static func parse(payload: [UInt8]) -> HiLightScan {
        guard payload.count >= 4 else {
            return HiLightScan(moments: [], anomaly: .truncatedHMMT)
        }

        let declared = MP4.be32(payload, 0)
        let slots = (payload.count - 4) / 4
        let readable = min(Int(declared), slots)

        var moments: [UInt32] = []
        moments.reserveCapacity(readable)
        for index in 0..<readable {
            moments.append(MP4.be32(payload, 4 + index * 4))
        }

        // The counter is authoritative: zero values are not filtered out. A highlight pressed in
        // the take's first millisecond reads as 0, and it counts like any other.
        let anomaly: HiLightScan.Anomaly? = Int(declared) > slots
            ? .countExceedsSlots(declared: declared, slots: slots)
            : nil

        return HiLightScan(moments: moments, anomaly: anomaly)
    }
}

public enum HiLightReader {

    /// Reads the tags of an MP4 file.
    ///
    /// Only throws on a real I/O error. A file that is *structurally* unreadable — no `moov`, no
    /// `HMMT` — yields a result with no moments and an anomaly: it goes to `Clips/`, which is the
    /// right default.
    public static func scan(fileURL: URL) throws -> HiLightScan {
        let reader = try FileByteReader(url: fileURL)
        return try scan(reader: reader)
    }

    public static func scan(reader: ByteReader) throws -> HiLightScan {
        // In GoPro files `moov` closes the file, behind an `mdat` of tens of megabytes. So we walk
        // the top-level atoms reading only their headers, and skip `mdat` by its size. `last`
        // rather than `first`: if a file carried two `moov` atoms, the last one is the one that
        // counts.
        let topLevel = try MP4.topLevelBoxes(in: reader)
        guard let moov = topLevel.last(where: { $0.type == "moov" }) else {
            return HiLightScan(moments: [], anomaly: .noMoov)
        }

        guard let udta = try MP4.children(of: moov, in: reader).first(where: { $0.type == "udta" }),
              let hmmt = try MP4.children(of: udta, in: reader).first(where: { $0.type == HMMT.atomType })
        else {
            return HiLightScan(moments: [], anomaly: .noHMMT)
        }

        // A single read, of the atom's exact size. 332 bytes on a HERO12.
        // The bound is not idle paranoia: a damaged file can announce an HMMT of several
        // megabytes, and we do not want to allocate that to find a counter that fits in the first
        // four bytes. 80 slots make 324; 65,536 leaves a very wide margin for a future, chattier
        // model.
        let capped = Int(min(hmmt.payloadLength, HMMT.maximumPayloadLength))
        let payload = try reader.read(at: hmmt.payloadOffset, count: capped)
        return HMMT.parse(payload: payload)
    }
}

import Foundation

/// What a GoPro file name says about itself.
///
/// `GX010123.MP4`: `GX` the encoding, `01` the chapter, `0123` the **take number**.
///
/// The take number is what matters. A long take is cut into 4 GB chapters that share that number
/// and have, apart from it, nothing tying them together. It is the only link between
/// `GX010123.MP4` and `GX020123.MP4`.
public struct GoProFileName: Equatable, Hashable, Sendable {

    /// The first two letters: `GX` (HEVC), `GH` (AVC), `GL` (LRV proxy), `GP`/`GOPR` (older
    /// models). Kept for display, never to decide a grouping — a take has one encoding, but
    /// relying on it would only add one more way to cut it in two.
    public let encoding: String

    /// Chapter number. `0` for the old `GOPR0123.MP4` form, which is the first chapter of a take
    /// whose continuation is called `GP010123.MP4`.
    public let chapter: Int

    /// Take number, shared by every chapter.
    public let take: Int

    /// The extension in upper case, without the dot.
    public let fileExtension: String

    public var kind: MediaKind { MediaKind(fileExtension: fileExtension) }

    /// Parses a file name. Returns `nil` if it is not a GoPro name — in which case the file is not
    /// imported, rather than filed at random.
    public init?(_ filename: String) {
        let name = (filename as NSString).lastPathComponent
        guard let dot = name.lastIndex(of: ".") else { return nil }

        let stem = String(name[name.startIndex..<dot]).uppercased()
        let ext = String(name[name.index(after: dot)...]).uppercased()
        guard stem.count == 8, !ext.isEmpty else { return nil }

        let characters = Array(stem)
        let digits = characters.map { $0.isNumber }

        // Old form: GOPR0123 — the first chapter of a take.
        if stem.hasPrefix("GOPR"), digits[4...].allSatisfy({ $0 }) {
            self.encoding = "GOPR"
            self.chapter = 0
            self.take = Int(String(characters[4..<8]))!
            self.fileExtension = ext
            return
        }

        // Current form: two encoding characters, two chapter digits, four take digits.
        guard characters[0].isLetter,
              characters[1].isLetter || characters[1].isNumber,
              digits[2], digits[3],
              digits[4], digits[5], digits[6], digits[7]
        else { return nil }

        self.encoding = String(characters[0..<2])
        self.chapter = Int(String(characters[2..<4]))!
        self.take = Int(String(characters[4..<8]))!
        self.fileExtension = ext
    }
}

/// What we do with a file found on the card.
public enum MediaKind: Equatable, Sendable {
    /// `.MP4` — the only type imported.
    case video
    /// `.LRV` — the low-resolution copy the camera writes beside every clip. Ignored.
    case proxy
    /// `.THM` — the thumbnail. Ignored.
    case thumbnail
    /// Everything else: photos, system files. Ignored.
    case other(String)

    init(fileExtension: String) {
        switch fileExtension.uppercased() {
        case "MP4": self = .video
        case "LRV": self = .proxy
        case "THM": self = .thumbnail
        case let other: self = .other(other)
        }
    }

    public var isVideo: Bool { self == .video }
}

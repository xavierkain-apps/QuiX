import Foundation

/// A file found on the card, with what it takes to identify it without reading it again.
public struct MediaFile: Equatable, Sendable {
    public let url: URL
    /// The DCIM folder holding it (`100GOPRO`), as is.
    public let folder: String
    public let name: GoProFileName
    public let size: UInt64
    public let modified: Date

    public init(url: URL, folder: String, name: GoProFileName, size: UInt64, modified: Date) {
        self.url = url
        self.folder = folder
        self.name = name
        self.size = size
        self.modified = modified
    }

    public var filename: String { url.lastPathComponent }
}

/// A file and its tags.
public struct ScannedFile: Equatable, Sendable {
    public let file: MediaFile
    public let hiLight: HiLightScan

    public init(file: MediaFile, hiLight: HiLightScan) {
        self.file = file
        self.hiLight = hiLight
    }
}

/// A take: every chapter that shares a GoPro file number.
///
/// **The unit of import is the take, never the chapter.** If a single chapter carries a
/// highlight, the whole take goes to `Highlights/`. Splitting one take's chapters between the two
/// folders would give two halves of a video, neither of them watchable.
public struct Take: Equatable, Sendable {

    /// Take number, shared by the chapters.
    public let number: Int
    /// The DCIM folder it came from. Part of the identity: two different cards can carry the same
    /// take number, and the camera's counter eventually wraps back through zero.
    public let folder: String
    /// The chapters, sorted by chapter number.
    public let chapters: [ScannedFile]

    public init(number: Int, folder: String, chapters: [ScannedFile]) {
        self.number = number
        self.folder = folder
        self.chapters = chapters.sorted { $0.file.name.chapter < $1.file.name.chapter }
    }

    /// True as soon as **one** chapter carries at least one moment.
    public var isHighlighted: Bool { chapters.contains { $0.hiLight.isHighlighted } }

    /// Total number of tagged moments across the whole take.
    public var momentCount: Int { chapters.reduce(0) { $0 + $1.hiLight.moments.count } }

    /// Total weight of the take, chapters included.
    public var totalSize: UInt64 { chapters.reduce(0) { $0 + $1.file.size } }
}

public enum TakeBuilder {

    /// Groups scanned files into takes, sorted by folder then by number.
    public static func group(_ files: [ScannedFile]) -> [Take] {
        struct Key: Hashable { let folder: String; let number: Int }

        var buckets: [Key: [ScannedFile]] = [:]
        for scanned in files {
            let key = Key(folder: scanned.file.folder, number: scanned.file.name.take)
            buckets[key, default: []].append(scanned)
        }

        return buckets
            .map { Take(number: $0.key.number, folder: $0.key.folder, chapters: $0.value) }
            .sorted { ($0.folder, $0.number) < ($1.folder, $1.number) }
    }
}

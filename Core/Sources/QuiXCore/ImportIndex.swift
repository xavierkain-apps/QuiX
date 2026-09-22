import Foundation

/// A memory of what has already been imported, so that plugging the card in again only copies what is new.
///
/// The key is **name + size + modification date**, as the brief asks. Three files would have to
/// match on all three to be confused, which does not happen between two real clips. The name alone
/// would not do: two cards can each carry a `GX010001.MP4`.
public struct ImportIndex: Codable, Equatable, Sendable {

    public struct Entry: Codable, Equatable, Sendable {
        public let filename: String
        public let size: UInt64
        public let modified: Date
        /// Path of the imported file, **relative to the root of the library**. Relative and not
        /// absolute: moving or renaming the library must not invalidate the whole index.
        public let destination: String
        public let importedAt: Date
    }

    private var entries: [String: Entry]

    public init() { self.entries = [:] }

    public var count: Int { entries.count }
    public var allEntries: [Entry] { Array(entries.values) }

    /// The date is rounded to the second: FAT32 cards only store the modification time to within
    /// two seconds, and a library read back from another file system must not end up with an
    /// entirely stale index.
    static func key(filename: String, size: UInt64, modified: Date) -> String {
        "\(filename.uppercased())|\(size)|\(Int64(modified.timeIntervalSince1970.rounded()))"
    }

    static func key(for file: MediaFile) -> String {
        key(filename: file.filename, size: file.size, modified: file.modified)
    }

    public func entry(for file: MediaFile) -> Entry? {
        entries[ImportIndex.key(for: file)]
    }

    public mutating func record(_ file: MediaFile, relativeDestination: String, at date: Date) {
        entries[ImportIndex.key(for: file)] = Entry(
            filename: file.filename,
            size: file.size,
            modified: file.modified,
            destination: relativeDestination,
            importedAt: date
        )
    }
}

/// Reading and writing the index on disk.
///
/// The file lives **at the root of the library** (`.quix-index.json`) and not in the application's
/// data: deleting the imported folder must be enough to be able to import everything again. An
/// index hidden elsewhere would make the app believe the clips are still there after they have gone.
public enum ImportIndexStore {

    public static let filename = ".quix-index.json"

    public static func url(inLibrary library: URL) -> URL {
        library.appendingPathComponent(filename, isDirectory: false)
    }

    /// Loads the index. **Never throws.** An absent or unreadable index yields an empty one: at
    /// worst some files already present are copied again — and the plan skips them anyway when it
    /// sees them at the destination. Refusing to import because a JSON file is damaged would be
    /// the wrong half of the trade.
    public static func load(fromLibrary library: URL) -> ImportIndex {
        guard let data = try? Data(contentsOf: url(inLibrary: library)),
              let index = try? JSONDecoder().decode(ImportIndex.self, from: data)
        else { return ImportIndex() }
        return index
    }

    /// Writes the index atomically: a card yanked out mid-write leaves the old index intact rather
    /// than a truncated JSON file.
    public static func save(_ index: ImportIndex, toLibrary library: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try data.write(to: url(inLibrary: library), options: .atomic)
    }
}

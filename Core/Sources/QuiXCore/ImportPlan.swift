import Foundation

/// The name of the import folder.
public enum ImportFolderName {

    /// An ISO date, `2026-09-07`. Sorts chronologically in the Finder, with no format ambiguity
    /// between regions.
    public static func iso(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// One copy to make.
public struct PlannedCopy: Equatable, Sendable {
    public let source: MediaFile
    public let destination: URL
    /// `destination` relative to the root of the library, for the index.
    public let relativeDestination: String
    public let takeNumber: Int
    public let isHighlighted: Bool
}

/// What is going to happen, decided before a single byte is written.
public struct ImportPlan: Equatable, Sendable {

    /// The two subfolders, and nothing else.
    public static let highlightsFolder = "Highlights"
    public static let clipsFolder = "Clips"

    /// `<library>/2026-09-07`.
    public let importFolder: URL
    public let copies: [PlannedCopy]
    /// Skipped because already present at the destination.
    public let alreadyImported: [MediaFile]

    public var isEmpty: Bool { copies.isEmpty }
    public var byteCount: UInt64 { copies.reduce(0) { $0 + $1.source.size } }
    public var highlightedCopies: [PlannedCopy] { copies.filter(\.isHighlighted) }
    public var highlightedTakeCount: Int { Set(highlightedCopies.map(\.takeNumber)).count }
    public var takeCount: Int { Set(copies.map(\.takeNumber)).count }
}

public enum ImportPlanner {

    /// Builds the import plan.
    ///
    /// Two things happen here, and both matter:
    ///
    /// - **The whole take follows its highlight.** The destination is chosen once per take, from
    ///   `Take.isHighlighted`, then applied to all of its chapters.
    /// - **Idempotence is checked against disk, not only against the index.** A file is skipped
    ///   only if the index knows it *and* the copy is really there, at the right size. Trusting
    ///   the index alone would mean a folder deleted by hand never gets imported again.
    public static func plan(
        takes: [Take],
        into library: URL,
        folderName: String,
        index: ImportIndex,
        existingSize: (URL) -> UInt64? = ImportPlanner.sizeOnDisk
    ) -> ImportPlan {

        let importFolder = library.appendingPathComponent(folderName, isDirectory: true)
        var copies: [PlannedCopy] = []
        var alreadyImported: [MediaFile] = []
        var claimed: Set<String> = []

        for take in takes {
            let subfolder = take.isHighlighted ? ImportPlan.highlightsFolder : ImportPlan.clipsFolder

            for chapter in take.chapters {
                let file = chapter.file

                if let entry = index.entry(for: file) {
                    let known = library.appendingPathComponent(entry.destination)
                    if existingSize(known) == file.size {
                        alreadyImported.append(file)
                        continue
                    }
                }

                // Name collision: two DCIM folders can hold the same file name after the camera's
                // counter wraps. We disambiguate rather than overwrite — a take lost in silence is
                // exactly what this product exists to avoid.
                var filename = file.filename
                var relative = "\(folderName)/\(subfolder)/\(filename)"
                if claimed.contains(relative.uppercased()) {
                    let stem = (filename as NSString).deletingPathExtension
                    let ext = (filename as NSString).pathExtension
                    filename = "\(stem)-\(file.folder).\(ext)"
                    relative = "\(folderName)/\(subfolder)/\(filename)"
                }
                claimed.insert(relative.uppercased())

                copies.append(PlannedCopy(
                    source: file,
                    destination: importFolder
                        .appendingPathComponent(subfolder, isDirectory: true)
                        .appendingPathComponent(filename, isDirectory: false),
                    relativeDestination: relative,
                    takeNumber: take.number,
                    isHighlighted: take.isHighlighted
                ))
            }
        }

        return ImportPlan(importFolder: importFolder, copies: copies, alreadyImported: alreadyImported)
    }

    /// The file's size if it exists, `nil` otherwise.
    public static func sizeOnDisk(_ url: URL) -> UInt64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize
        else { return nil }
        return UInt64(size)
    }
}

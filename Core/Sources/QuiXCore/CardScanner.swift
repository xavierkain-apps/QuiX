import Foundation

/// Finding and reading a GoPro card mounted as an ordinary volume.
///
/// This is the faster road: the card shows up under `/Volumes/` and copying is markedly quicker
/// than over the cable. The other source — the camera over USB-C, which exposes no volume at all —
/// is handled by `CameraScanner`, with the same contract and the same `Take` values.
public enum CardScanner {

    /// What the scan found.
    public struct Result: Sendable {
        public let takes: [Take]
        /// Files skipped before the tags were even read, and why.
        public let ignored: [IgnoredFile]

        public var highlightedTakes: [Take] { takes.filter(\.isHighlighted) }
        public var totalSize: UInt64 { takes.reduce(0) { $0 + $1.totalSize } }
    }

    public struct IgnoredFile: Equatable, Sendable {
        public let url: URL
        public let reason: Reason

        public enum Reason: Equatable, Sendable {
            /// `.LRV`, `.THM`, a photo… the camera writes some beside every clip.
            case notAVideo(MediaKind)
            /// A name that does not follow GoPro's convention. Not imported rather than filed at random.
            case unrecognisedName
        }
    }

    /// A card is recognised as a GoPro card by the **presence of a `DCIM/###GOPRO` folder**, never
    /// by the volume name: the user may have renamed it, and another device's card may perfectly
    /// well be called "GOPRO". The structural criterion is the only one that does not lie, and it
    /// is what guarantees another device's card is never touched.
    public static func isGoProCard(_ volume: URL, fileManager: FileManager = .default) -> Bool {
        !mediaFolders(on: volume, fileManager: fileManager).isEmpty
    }

    /// A volume's `DCIM/###GOPRO` folders, sorted by name.
    public static func mediaFolders(on volume: URL, fileManager: FileManager = .default) -> [URL] {
        let dcim = volume.appendingPathComponent("DCIM", isDirectory: true)
        guard let entries = try? fileManager.contentsOfDirectory(
            at: dcim, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
        ) else { return [] }

        return entries
            .filter { isGoProFolderName($0.lastPathComponent) }
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// `100GOPRO` through `999GOPRO`. The brief says `1xxGOPRO`; we accept all three digits, which
    /// is a safe superset — the camera opens one more folder every 999 files.
    static func isGoProFolderName(_ name: String) -> Bool {
        let upper = name.uppercased()
        guard upper.count == 8, upper.hasSuffix("GOPRO") else { return false }
        return upper.prefix(3).allSatisfy(\.isNumber)
    }

    /// Scans a whole card: lists the files, reads the tags, groups them into takes.
    ///
    /// `progress` is called after each file read, with the number already handled and the total.
    /// It runs on the caller's thread, which is not meant to be the main one.
    public static func scan(
        volume: URL,
        fileManager: FileManager = .default,
        progress: (Int, Int) -> Void = { _, _ in }
    ) throws -> Result {

        var videos: [MediaFile] = []
        var ignored: [IgnoredFile] = []

        for folder in mediaFolders(on: volume, fileManager: fileManager) {
            let folderName = folder.lastPathComponent
            let entries = (try? fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )) ?? []

            for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let name = GoProFileName(entry.lastPathComponent) else {
                    ignored.append(IgnoredFile(url: entry, reason: .unrecognisedName))
                    continue
                }
                guard name.kind.isVideo else {
                    ignored.append(IgnoredFile(url: entry, reason: .notAVideo(name.kind)))
                    continue
                }

                let values = try? entry.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                videos.append(MediaFile(
                    url: entry,
                    folder: folderName,
                    name: name,
                    size: UInt64(values?.fileSize ?? 0),
                    modified: values?.contentModificationDate ?? Date(timeIntervalSince1970: 0)
                ))
            }
        }

        var scanned: [ScannedFile] = []
        scanned.reserveCapacity(videos.count)
        for (position, video) in videos.enumerated() {
            // A read error on one file does not fail the card scan: the clip goes to `Clips/`,
            // which is the safe default. Losing the whole import because one file in fifty is
            // damaged would be the worse of the two behaviours.
            let tags = (try? HiLightReader.scan(fileURL: video.url)) ?? HiLightScan(moments: [], anomaly: .noMoov)
            scanned.append(ScannedFile(file: video, hiLight: tags))
            progress(position + 1, videos.count)
        }

        return Result(takes: TakeBuilder.group(scanned), ignored: ignored)
    }
}

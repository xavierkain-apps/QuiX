import Foundation

/// Finding and reading takes directly on the camera over USB.
///
/// The twin of `CardScanner`, for the source the HERO12 imposes over the cable. The contract is
/// deliberately identical — same `Take`, same `Result` — so that the import, the index and the
/// interface never know which source they came from.
public enum CameraScanner {

    public enum ScanFailure: Error, Equatable {
        /// No camera answered on any of the machine's USB networks.
        case noCamera
        /// The camera is there but refuses partial reads: free sorting is impossible.
        /// Reported rather than quietly worked around, because the workaround would cost the full
        /// download of every clip before knowing where it goes.
        case rangeUnsupported
    }

    /// Scans the card through the camera, without copying a byte.
    ///
    /// `progress` is called after each clip read, with the number already handled and the total.
    public static func scan(
        camera: GoProCamera,
        progress: (Int, Int) -> Void = { _, _ in }
    ) throws -> CardScanner.Result {

        camera.enableWiredControl()
        let entries = try camera.mediaList()

        var videos: [MediaFile] = []
        var ignored: [CardScanner.IgnoredFile] = []

        for entry in entries {
            guard let name = GoProFileName(entry.filename) else {
                ignored.append(.init(url: entry.url, reason: .unrecognisedName))
                continue
            }
            guard name.kind.isVideo else {
                ignored.append(.init(url: entry.url, reason: .notAVideo(name.kind)))
                continue
            }
            videos.append(MediaFile(
                url: entry.url,
                folder: entry.folder,
                name: name,
                size: entry.size,
                modified: entry.created
            ))
        }

        // One check for the whole session: discovering at the sixtieth clip that the server
        // ignores `Range` would be discovering that sixty clips were downloaded for nothing.
        if let first = videos.first,
           !HTTPRangeByteReader.supportsRange(url: first.url) {
            throw ScanFailure.rangeUnsupported
        }

        var scanned: [ScannedFile] = []
        scanned.reserveCapacity(videos.count)
        for (position, video) in videos.enumerated() {
            // Same rule as on a card: an unreadable clip goes to `Clips/` rather than failing the
            // whole import.
            let reader = HTTPRangeByteReader(url: video.url, length: video.size)
            let tags = (try? HiLightReader.scan(reader: reader))
                ?? HiLightScan(moments: [], anomaly: .noMoov)
            scanned.append(ScannedFile(file: video, hiLight: tags))
            progress(position + 1, videos.count)
        }

        return CardScanner.Result(takes: TakeBuilder.group(scanned), ignored: ignored)
    }
}

import Foundation

/// Repérage et lecture des prises directement sur la caméra branchée en USB.
///
/// Jumeau de `CardScanner`, pour la source que la HERO12 impose par le câble. Le contrat est
/// volontairement le même — mêmes `Take`, même `Result` — pour que l'import, l'index et l'interface
/// ne sachent pas de quelle source ils viennent.
public enum CameraScanner {

    public enum ScanFailure: Error, Equatable {
        /// Aucune caméra n'a répondu sur les réseaux USB de la machine.
        case noCamera
        /// La caméra est là mais refuse les lectures partielles : le tri gratuit est impossible.
        /// Remonté plutôt que contourné en silence, parce que le contournement coûterait le
        /// téléchargement intégral de chaque clip avant de savoir où il va.
        case rangeUnsupported
    }

    /// Analyse la carte à travers la caméra, sans copier un octet.
    ///
    /// `progress` est appelé après chaque clip lu, avec le nombre déjà traité et le total.
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

        // Une seule vérification pour toute la session : découvrir au soixantième clip que le
        // serveur ignore `Range` serait découvrir qu'on a téléchargé soixante clips pour rien.
        if let first = videos.first,
           !HTTPRangeByteReader.supportsRange(url: first.url) {
            throw ScanFailure.rangeUnsupported
        }

        var scanned: [ScannedFile] = []
        scanned.reserveCapacity(videos.count)
        for (position, video) in videos.enumerated() {
            // Même règle que sur une carte : un clip illisible part dans `Clips/` plutôt que de
            // faire échouer tout l'import.
            let reader = HTTPRangeByteReader(url: video.url, length: video.size)
            let tags = (try? HiLightReader.scan(reader: reader))
                ?? HiLightScan(moments: [], anomaly: .noMoov)
            scanned.append(ScannedFile(file: video, hiLight: tags))
            progress(position + 1, videos.count)
        }

        return CardScanner.Result(takes: TakeBuilder.group(scanned), ignored: ignored)
    }
}

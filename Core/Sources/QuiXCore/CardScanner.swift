import Foundation

/// Repérage et lecture d'une carte GoPro montée comme un volume ordinaire.
///
/// C'est le chemin le plus rapide : la carte apparaît sous `/Volumes/` et la copie va nettement
/// plus vite que par le câble. L'autre source — la caméra branchée en USB-C, qui n'expose aucun
/// volume — est traitée par `CameraScanner`, avec le même contrat et les mêmes `Take`.
public enum CardScanner {

    /// Ce que le scan a trouvé.
    public struct Result: Sendable {
        public let takes: [Take]
        /// Fichiers écartés avant même la lecture des tags, et pourquoi.
        public let ignored: [IgnoredFile]

        public var highlightedTakes: [Take] { takes.filter(\.isHighlighted) }
        public var totalSize: UInt64 { takes.reduce(0) { $0 + $1.totalSize } }
    }

    public struct IgnoredFile: Equatable, Sendable {
        public let url: URL
        public let reason: Reason

        public enum Reason: Equatable, Sendable {
            /// `.LRV`, `.THM`, photo… la caméra en écrit à côté de chaque clip.
            case notAVideo(MediaKind)
            /// Un nom qui ne suit pas la convention GoPro. Non importé plutôt que rangé au hasard.
            case unrecognisedName
        }
    }

    /// Une carte est reconnue GoPro par la **présence d'un dossier `DCIM/###GOPRO`**, jamais par le
    /// nom du volume : l'utilisateur peut l'avoir renommé, et une carte d'un autre appareil peut
    /// très bien s'appeler « GOPRO ». Le critère structurel est le seul qui ne mente pas, et c'est
    /// lui qui garantit qu'on ne touche jamais à la carte d'un autre appareil.
    public static func isGoProCard(_ volume: URL, fileManager: FileManager = .default) -> Bool {
        !mediaFolders(on: volume, fileManager: fileManager).isEmpty
    }

    /// Les dossiers `DCIM/###GOPRO` d'un volume, triés par nom.
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

    /// `100GOPRO` à `999GOPRO`. Le brief parle de `1xxGOPRO` ; on accepte les trois chiffres, ce
    /// qui est un sur-ensemble sûr — la caméra ouvre un dossier de plus tous les 999 fichiers.
    static func isGoProFolderName(_ name: String) -> Bool {
        let upper = name.uppercased()
        guard upper.count == 8, upper.hasSuffix("GOPRO") else { return false }
        return upper.prefix(3).allSatisfy(\.isNumber)
    }

    /// Analyse une carte entière : liste les fichiers, lit les tags, regroupe en prises.
    ///
    /// `progress` est appelé après chaque fichier lu, avec le nombre déjà traité et le total.
    /// Il tourne sur le fil de l'appelant, qui n'est pas censé être le principal.
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
            // Une erreur de lecture sur un fichier ne fait pas échouer le scan de la carte : le
            // clip part dans `Clips/`, ce qui est le défaut sûr. Perdre l'import entier parce
            // qu'un fichier sur cinquante est abîmé serait le pire des deux comportements.
            let tags = (try? HiLightReader.scan(fileURL: video.url)) ?? HiLightScan(moments: [], anomaly: .noMoov)
            scanned.append(ScannedFile(file: video, hiLight: tags))
            progress(position + 1, videos.count)
        }

        return Result(takes: TakeBuilder.group(scanned), ignored: ignored)
    }
}

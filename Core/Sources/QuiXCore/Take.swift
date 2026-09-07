import Foundation

/// Un fichier repéré sur la carte, avec ce qu'il faut pour l'identifier sans le relire.
public struct MediaFile: Equatable, Sendable {
    public let url: URL
    /// Le dossier DCIM qui le contient (`100GOPRO`), tel quel.
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

/// Un fichier et ses tags.
public struct ScannedFile: Equatable, Sendable {
    public let file: MediaFile
    public let hiLight: HiLightScan

    public init(file: MediaFile, hiLight: HiLightScan) {
        self.file = file
        self.hiLight = hiLight
    }
}

/// Une prise : tous les chapitres qui partagent un numéro de fichier GoPro.
///
/// **L'unité d'import, c'est la prise, jamais le chapitre.** Si un seul chapitre porte un
/// highlight, la prise entière va dans `Highlights/`. Répartir les chapitres d'une même prise
/// entre les deux dossiers donnerait deux moitiés de vidéo dont aucune n'est regardable.
public struct Take: Equatable, Sendable {

    /// Numéro de prise, commun aux chapitres.
    public let number: Int
    /// Dossier DCIM d'origine. Fait partie de l'identité : deux cartes différentes peuvent porter
    /// le même numéro de prise, et le compteur de la caméra finit par repasser par zéro.
    public let folder: String
    /// Les chapitres, triés par numéro de chapitre.
    public let chapters: [ScannedFile]

    public init(number: Int, folder: String, chapters: [ScannedFile]) {
        self.number = number
        self.folder = folder
        self.chapters = chapters.sorted { $0.file.name.chapter < $1.file.name.chapter }
    }

    /// Vrai dès qu'**un** chapitre porte au moins un moment.
    public var isHighlighted: Bool { chapters.contains { $0.hiLight.isHighlighted } }

    /// Nombre total de moments tagués sur toute la prise.
    public var momentCount: Int { chapters.reduce(0) { $0 + $1.hiLight.moments.count } }

    /// Poids total de la prise, chapitres compris.
    public var totalSize: UInt64 { chapters.reduce(0) { $0 + $1.file.size } }
}

public enum TakeBuilder {

    /// Regroupe des fichiers analysés en prises, triées par dossier puis par numéro.
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

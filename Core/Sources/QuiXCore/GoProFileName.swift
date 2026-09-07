import Foundation

/// Ce qu'un nom de fichier GoPro dit de lui-même.
///
/// `GX010123.MP4` : `GX` l'encodage, `01` le chapitre, `0123` le **numéro de prise**.
///
/// Le numéro de prise est ce qui compte. Une longue prise est découpée en chapitres de 4 Go qui
/// partagent ce numéro et n'ont, à part lui, rien qui les relie. C'est le seul lien entre
/// `GX010123.MP4` et `GX020123.MP4`.
public struct GoProFileName: Equatable, Hashable, Sendable {

    /// Les deux premières lettres : `GX` (HEVC), `GH` (AVC), `GL` (proxy LRV), `GP`/`GOPR` (anciens
    /// modèles). On la garde pour l'affichage, jamais pour décider d'un regroupement — une prise
    /// n'a qu'un encodage, mais s'y fier ne ferait qu'ajouter une façon de la couper en deux.
    public let encoding: String

    /// Numéro de chapitre. `0` pour la forme ancienne `GOPR0123.MP4`, qui est le premier chapitre
    /// d'une prise dont la suite s'appelle `GP010123.MP4`.
    public let chapter: Int

    /// Numéro de prise, commun à tous les chapitres.
    public let take: Int

    /// L'extension en majuscules, sans le point.
    public let fileExtension: String

    public var kind: MediaKind { MediaKind(fileExtension: fileExtension) }

    /// Analyse un nom de fichier. Rend `nil` si ce n'est pas un nom GoPro — auquel cas le fichier
    /// n'est pas importé, plutôt que d'être rangé au hasard.
    public init?(_ filename: String) {
        let name = (filename as NSString).lastPathComponent
        guard let dot = name.lastIndex(of: ".") else { return nil }

        let stem = String(name[name.startIndex..<dot]).uppercased()
        let ext = String(name[name.index(after: dot)...]).uppercased()
        guard stem.count == 8, !ext.isEmpty else { return nil }

        let characters = Array(stem)
        let digits = characters.map { $0.isNumber }

        // Forme ancienne : GOPR0123 — premier chapitre d'une prise.
        if stem.hasPrefix("GOPR"), digits[4...].allSatisfy({ $0 }) {
            self.encoding = "GOPR"
            self.chapter = 0
            self.take = Int(String(characters[4..<8]))!
            self.fileExtension = ext
            return
        }

        // Forme courante : deux caractères d'encodage, deux chiffres de chapitre, quatre de prise.
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

/// Ce qu'on fait d'un fichier trouvé sur la carte.
public enum MediaKind: Equatable, Sendable {
    /// `.MP4` — le seul type importé.
    case video
    /// `.LRV` — la copie basse résolution que la caméra écrit à côté de chaque clip. Ignorée.
    case proxy
    /// `.THM` — la vignette. Ignorée.
    case thumbnail
    /// Tout le reste : photos, fichiers système. Ignoré.
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

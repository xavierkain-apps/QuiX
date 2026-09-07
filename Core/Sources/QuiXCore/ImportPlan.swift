import Foundation

/// Nom du dossier d'import.
public enum ImportFolderName {

    /// Date ISO, `2026-09-07`. Triable chronologiquement dans le Finder, sans ambiguïté de format
    /// entre les régions.
    public static func iso(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

/// Une copie à faire.
public struct PlannedCopy: Equatable, Sendable {
    public let source: MediaFile
    public let destination: URL
    /// Chemin de `destination` relatif à la racine de la bibliothèque, pour l'index.
    public let relativeDestination: String
    public let takeNumber: Int
    public let isHighlighted: Bool
}

/// Ce qui va se passer, décidé avant d'écrire le moindre octet.
public struct ImportPlan: Equatable, Sendable {

    /// Les deux sous-dossiers, et rien d'autre.
    public static let highlightsFolder = "Highlights"
    public static let clipsFolder = "Clips"

    /// `<bibliothèque>/2026-09-07`.
    public let importFolder: URL
    public let copies: [PlannedCopy]
    /// Écartés parce que déjà présents à destination.
    public let alreadyImported: [MediaFile]

    public var isEmpty: Bool { copies.isEmpty }
    public var byteCount: UInt64 { copies.reduce(0) { $0 + $1.source.size } }
    public var highlightedCopies: [PlannedCopy] { copies.filter(\.isHighlighted) }
    public var highlightedTakeCount: Int { Set(highlightedCopies.map(\.takeNumber)).count }
    public var takeCount: Int { Set(copies.map(\.takeNumber)).count }
}

public enum ImportPlanner {

    /// Construit le plan d'import.
    ///
    /// Deux choses s'y jouent, et les deux comptent :
    ///
    /// - **La prise entière suit son highlight.** La destination est choisie une fois par prise, à
    ///   partir de `Take.isHighlighted`, puis appliquée à tous ses chapitres.
    /// - **L'idempotence se vérifie sur le disque, pas seulement dans l'index.** Un fichier n'est
    ///   écarté que si l'index le connaît *et* que la copie est réellement là, à la bonne taille.
    ///   Se fier à l'index seul ferait qu'un dossier supprimé à la main ne se réimporterait jamais.
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

                // Collision de noms : deux dossiers DCIM peuvent porter le même nom de fichier
                // après un tour de compteur de la caméra. On désambiguïse plutôt que d'écraser —
                // une prise perdue en silence est exactement ce que ce produit doit éviter.
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

    /// Taille du fichier s'il existe, `nil` sinon.
    public static func sizeOnDisk(_ url: URL) -> UInt64? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
              let size = values.fileSize
        else { return nil }
        return UInt64(size)
    }
}

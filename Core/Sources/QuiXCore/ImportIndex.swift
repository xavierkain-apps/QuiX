import Foundation

/// Mémoire de ce qui a déjà été importé, pour que rebrancher la carte ne recopie que le neuf.
///
/// La clé est **nom + taille + date de modification**, comme le demande le brief. Trois fichiers
/// devraient se ressembler jusque-là pour être confondus, ce qui n'arrive pas entre deux clips
/// réels. Le nom seul ne suffirait pas : deux cartes peuvent porter le même `GX010001.MP4`.
public struct ImportIndex: Codable, Equatable, Sendable {

    public struct Entry: Codable, Equatable, Sendable {
        public let filename: String
        public let size: UInt64
        public let modified: Date
        /// Chemin du fichier importé, **relatif à la racine de la bibliothèque**. Relatif et non
        /// absolu : déplacer ou renommer la bibliothèque ne doit pas invalider tout l'index.
        public let destination: String
        public let importedAt: Date
    }

    private var entries: [String: Entry]

    public init() { self.entries = [:] }

    public var count: Int { entries.count }
    public var allEntries: [Entry] { Array(entries.values) }

    /// La date est arrondie à la seconde : les cartes en FAT32 ne stockent la minute de
    /// modification qu'à deux secondes près, et une bibliothèque relue depuis un autre système de
    /// fichiers ne doit pas se retrouver avec un index entièrement périmé.
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

/// Lecture et écriture de l'index sur disque.
///
/// Le fichier vit **à la racine de la bibliothèque** (`.quix-index.json`) et non dans les données
/// de l'application : supprimer le dossier importé doit suffire à pouvoir tout réimporter. Un index
/// caché ailleurs ferait croire à l'app que les clips sont déjà là alors qu'ils ont disparu.
public enum ImportIndexStore {

    public static let filename = ".quix-index.json"

    public static func url(inLibrary library: URL) -> URL {
        library.appendingPathComponent(filename, isDirectory: false)
    }

    /// Charge l'index. **Ne lève jamais.** Un index absent ou illisible rend un index vide : au
    /// pire on recopie des fichiers déjà présents — et le plan les écarte de toute façon en
    /// constatant leur présence à destination. Refuser d'importer parce qu'un fichier JSON est
    /// abîmé serait la mauvaise moitié du compromis.
    public static func load(fromLibrary library: URL) -> ImportIndex {
        guard let data = try? Data(contentsOf: url(inLibrary: library)),
              let index = try? JSONDecoder().decode(ImportIndex.self, from: data)
        else { return ImportIndex() }
        return index
    }

    /// Écrit l'index de façon atomique : un arrachage de carte en pleine écriture laisse l'ancien
    /// index intact plutôt qu'un JSON tronqué.
    public static func save(_ index: ImportIndex, toLibrary library: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(index)
        try FileManager.default.createDirectory(at: library, withIntermediateDirectories: true)
        try data.write(to: url(inLibrary: library), options: .atomic)
    }
}

import Foundation

public enum CopyFailure: Error, Equatable {
    /// Un fichier existe déjà à la destination. On ne l'écrase jamais.
    case destinationExists(URL)
    /// Le nombre d'octets écrits ne correspond pas à la taille annoncée par la source.
    case sizeMismatch(expected: UInt64, written: UInt64)
    /// La relecture du fichier écrit ne donne pas la même empreinte que la source.
    case checksumMismatch(source: UInt32, destination: UInt32)
    case cancelled
}

/// Copie vérifiée d'un fichier.
///
/// **Cette fonction ne touche jamais à la source.** Elle ouvre en lecture, écrit ailleurs, et
/// n'appelle `removeItem` que sur son propre fichier temporaire. C'est la règle qui compte : une
/// erreur d'import se rattrape, une carte effacée non.
///
/// Le déroulé :
///
/// 1. On écrit dans un fichier temporaire, pas directement à la destination. Une copie interrompue
///    laisse un `.quix-partiel` évident, pas un `.MP4` de bonne taille apparente et de contenu
///    tronqué que le Finder afficherait comme un clip valide.
/// 2. L'empreinte de la source se calcule **pendant** la copie, sans la relire.
/// 3. Le fichier écrit est relu pour recalculer la sienne. C'est là que la vérification a lieu :
///    comparer la source à elle-même ne prouverait rien.
/// 4. Seulement si tout concorde, le temporaire prend son nom définitif.
public enum VerifiedCopy {

    public static let partialSuffix = ".quix-partiel"

    /// Taille de bloc. Assez grande pour que le coût par appel disparaisse, assez petite pour que
    /// la progression reste fluide et que la mémoire ne monte pas sur un serveur chargé.
    public static let chunkSize = 4 * 1024 * 1024

    @discardableResult
    public static func copy(
        from source: URL,
        to destination: URL,
        fileManager: FileManager = .default,
        isCancelled: () -> Bool = { false },
        progress: (UInt64) -> Void = { _ in }
    ) throws -> UInt32 {

        guard !fileManager.fileExists(atPath: destination.path) else {
            throw CopyFailure.destinationExists(destination)
        }

        let expectedSize = ImportPlanner.sizeOnDisk(source) ?? 0
        let temporary = URL(fileURLWithPath: destination.path + partialSuffix)

        try fileManager.createDirectory(at: destination.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        // Un temporaire laissé par une tentative précédente est à nous, et à nous seuls.
        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }
        guard fileManager.createFile(atPath: temporary.path, contents: nil) else {
            throw CopyFailure.destinationExists(temporary)
        }

        var sourceCRC = CRC32()
        var written: UInt64 = 0

        do {
            let input = try FileHandle(forReadingFrom: source)
            let output = try FileHandle(forWritingTo: temporary)

            while true {
                if isCancelled() {
                    try? input.close()
                    try? output.close()
                    try? fileManager.removeItem(at: temporary)
                    throw CopyFailure.cancelled
                }
                guard let block = try input.read(upToCount: chunkSize), !block.isEmpty else { break }
                sourceCRC.update(block)
                try output.write(contentsOf: block)
                written += UInt64(block.count)
                progress(written)
            }

            try output.synchronize()
            try output.close()
            try input.close()
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        guard written == expectedSize else {
            try? fileManager.removeItem(at: temporary)
            throw CopyFailure.sizeMismatch(expected: expectedSize, written: written)
        }

        let destinationCRC: UInt32
        do {
            destinationCRC = try checksum(of: temporary)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }

        guard destinationCRC == sourceCRC.value else {
            try? fileManager.removeItem(at: temporary)
            throw CopyFailure.checksumMismatch(source: sourceCRC.value, destination: destinationCRC)
        }

        // La date de tournage suit la copie : sans ça, tous les clips importés porteraient la date
        // de l'import et le tri par date dans le Finder ne dirait plus rien.
        if let modified = try? source.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
            try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: temporary.path)
        }

        try fileManager.moveItem(at: temporary, to: destination)
        return sourceCRC.value
    }

    /// Empreinte d'un fichier déjà écrit.
    public static func checksum(of url: URL) throws -> UInt32 {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var crc = CRC32()
        while let block = try handle.read(upToCount: chunkSize), !block.isEmpty {
            crc.update(block)
        }
        return crc.value
    }
}

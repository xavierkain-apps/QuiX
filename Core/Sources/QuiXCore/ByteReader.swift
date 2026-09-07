import Foundation

/// Accès en lecture aléatoire à une suite d'octets.
///
/// L'abstraction existe pour une raison précise : elle permet de tester le parcours des atomes MP4
/// sur des octets fabriqués en mémoire, sans écrire un seul fichier. Les cas qui comptent — taille
/// 64 bits, taille nulle, atome tronqué — sont pénibles à produire sur disque et triviaux à écrire
/// dans un tableau.
public protocol ByteReader {
    /// Taille totale en octets.
    var length: UInt64 { get }

    /// Lit au plus `count` octets à partir de `offset`. Peut en renvoyer moins en fin de source,
    /// et un tableau vide au-delà de la fin. Ne lève pas d'erreur pour une lecture hors bornes :
    /// c'est au parcours d'atomes de décider ce qu'un fichier tronqué signifie.
    func read(at offset: UInt64, count: Int) throws -> [UInt8]
}

extension ByteReader {
    /// Lit exactement `count` octets, ou renvoie `nil` s'il n'y en a pas autant.
    func readExact(at offset: UInt64, count: Int) throws -> [UInt8]? {
        let bytes = try read(at: offset, count: count)
        return bytes.count == count ? bytes : nil
    }
}

/// Lecteur sur un tableau d'octets en mémoire.
public struct DataByteReader: ByteReader, Sendable {
    private let bytes: [UInt8]

    public init(_ bytes: [UInt8]) { self.bytes = bytes }
    public init(_ data: Data) { self.bytes = [UInt8](data) }

    public var length: UInt64 { UInt64(bytes.count) }

    public func read(at offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0, offset < UInt64(bytes.count) else { return [] }
        let start = Int(offset)
        let end = min(start + count, bytes.count)
        return Array(bytes[start..<end])
    }
}

/// Lecteur sur un fichier, par `seek` et lectures courtes.
///
/// Chez GoPro l'atome `moov` ferme le fichier : on saute les ~90 Mo de `mdat` par sa taille au lieu
/// de les lire. Une analyse complète coûte une poignée de `seek` et environ 34 Ko lus, quelle que
/// soit la taille du clip. C'est ce qui rend le tri gratuit — voir `docs/HILIGHT.md`.
public final class FileByteReader: ByteReader {
    private let handle: FileHandle
    public let length: UInt64

    public init(url: URL) throws {
        // La taille se lit avant d'ouvrir : si elle échoue, aucun descripteur n'a été ouvert et
        // il n'y a donc rien à refermer — un `init` qui échoue n'appelle pas `deinit`.
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        self.length = UInt64(values.fileSize ?? 0)
        self.handle = try FileHandle(forReadingFrom: url)
    }

    deinit { try? handle.close() }

    public func read(at offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0, offset < length else { return [] }
        try handle.seek(toOffset: offset)
        guard let data = try handle.read(upToCount: count) else { return [] }
        return [UInt8](data)
    }
}

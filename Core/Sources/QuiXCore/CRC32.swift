import Foundation

/// Somme de contrôle CRC-32 (polynôme IEEE), calculée en flux.
///
/// Le but est de détecter une copie abîmée — carte débranchée en cours de route, secteur illisible,
/// disque plein — pas de résister à quelqu'un qui chercherait à tromper la vérification. Un CRC-32
/// suffit largement pour ça, et il coûte assez peu pour qu'on puisse le calculer sur chaque octet
/// de chaque fichier sans que ça se voie à côté du temps de copie.
public struct CRC32: Sendable, Equatable {

    private static let table: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = (value & 1) != 0 ? (0xEDB8_8320 ^ (value >> 1)) : (value >> 1)
        }
        return value
    }

    private var state: UInt32 = 0xFFFF_FFFF

    public init() {}

    /// Reprend un calcul interrompu à partir de son empreinte partielle.
    ///
    /// Sert à la reprise d'un téléchargement : les octets déjà reçus ne sont pas relus depuis le
    /// réseau, mais leur empreinte est reprise là où elle s'était arrêtée.
    public init(resuming value: UInt32) {
        state = value ^ 0xFFFF_FFFF
    }

    public mutating func update(_ data: Data) {
        var state = self.state
        data.withUnsafeBytes { raw in
            for byte in raw {
                state = CRC32.table[Int((state ^ UInt32(byte)) & 0xFF)] ^ (state >> 8)
            }
        }
        self.state = state
    }

    public mutating func update(bytes: [UInt8]) {
        var state = self.state
        for byte in bytes {
            state = CRC32.table[Int((state ^ UInt32(byte)) & 0xFF)] ^ (state >> 8)
        }
        self.state = state
    }

    public var value: UInt32 { state ^ 0xFFFF_FFFF }
}

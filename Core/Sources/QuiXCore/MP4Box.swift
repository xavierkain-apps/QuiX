import Foundation

/// Un atome MP4 repéré dans le fichier : son type et l'endroit où vit sa charge utile.
///
/// On ne garde jamais le contenu, seulement des positions. Un `moov` de 34 Ko n'est lu que si
/// quelqu'un le demande, et `mdat` ne l'est jamais.
public struct MP4Box: Equatable, Sendable {
    /// Le code à quatre caractères, tel qu'écrit dans le fichier (`moov`, `udta`, `HMMT`…).
    public let type: String
    /// Position du premier octet de la charge utile, en-tête exclu.
    public let payloadOffset: UInt64
    /// Longueur de la charge utile, en-tête exclu.
    public let payloadLength: UInt64

    var payloadEnd: UInt64 { payloadOffset + payloadLength }
}

public enum MP4 {

    /// Parcourt les atomes d'une plage `start..<end` sans descendre dans leurs enfants.
    ///
    /// Trois formes d'en-tête existent et les trois arrivent sur de vrais fichiers :
    ///
    /// - taille sur 32 bits, en-tête de 8 octets — le cas courant ;
    /// - taille `1`, la vraie taille suit sur 64 bits, en-tête de 16 octets — un `mdat` de plus de
    ///   4 Go, qu'une longue prise en 5,3K finit par produire ;
    /// - taille `0`, l'atome va jusqu'à la fin de la plage. Écrit par un enregistreur interrompu.
    ///   **Un `mdat` de taille nulle avale le `moov` qui le suit** : le fichier n'a alors pas de
    ///   tags lisibles, ce qui se lit « aucun highlight », jamais « erreur ».
    ///
    /// Le parcours s'arrête dès qu'un en-tête est incohérent plutôt que d'essayer de se rattraper :
    /// sur un fichier abîmé, mieux vaut rendre les atomes déjà lus que d'aller chercher des octets
    /// au hasard.
    public static func boxes(in reader: ByteReader, from start: UInt64, to end: UInt64) throws -> [MP4Box] {
        var result: [MP4Box] = []
        var position = start

        while position + 8 <= end {
            guard let header = try reader.readExact(at: position, count: 8) else { break }

            let declared = UInt64(be32(header, 0))
            let type = fourCC(header, 4)
            var headerSize: UInt64 = 8
            var size = declared

            if declared == 1 {
                guard let extended = try reader.readExact(at: position + 8, count: 8) else { break }
                size = be64(extended, 0)
                headerSize = 16
            } else if declared == 0 {
                size = end - position
            }

            // Un atome plus petit que son propre en-tête, ou qui déborde de la plage, est le signe
            // d'un fichier tronqué ou d'octets qui ne sont pas du MP4. On rend ce qu'on a.
            guard size >= headerSize, position + size <= end else { break }

            result.append(MP4Box(type: type,
                                 payloadOffset: position + headerSize,
                                 payloadLength: size - headerSize))

            position += size
        }

        return result
    }

    /// Parcourt les atomes de premier niveau du fichier entier.
    public static func topLevelBoxes(in reader: ByteReader) throws -> [MP4Box] {
        try boxes(in: reader, from: 0, to: reader.length)
    }

    /// Parcourt les enfants d'un atome conteneur.
    public static func children(of box: MP4Box, in reader: ByteReader) throws -> [MP4Box] {
        try boxes(in: reader, from: box.payloadOffset, to: box.payloadEnd)
    }

    // MARK: - Lecture d'entiers gros-boutistes

    static func be32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24
            | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8
            | UInt32(bytes[offset + 3])
    }

    static func be64(_ bytes: [UInt8], _ offset: Int) -> UInt64 {
        var value: UInt64 = 0
        for index in 0..<8 { value = value << 8 | UInt64(bytes[offset + index]) }
        return value
    }

    static func fourCC(_ bytes: [UInt8], _ offset: Int) -> String {
        String(bytes[offset..<(offset + 4)].map { Character(UnicodeScalar($0)) })
    }
}

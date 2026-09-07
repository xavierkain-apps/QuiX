import Foundation

/// Ce qu'une lecture de tags HiLight a trouvé dans un fichier.
///
/// Le seul critère de tri, c'est `isHighlighted`. Tout le reste est de l'information pour
/// l'interface : rien ici ne doit empêcher un import d'aboutir.
public struct HiLightScan: Equatable, Sendable {

    /// Instants tagués, en millisecondes depuis le début **de ce chapitre** — pas de la prise.
    /// Une longue prise découpée en chapitres redémarre le compteur à chaque fichier.
    public let moments: [UInt32]

    /// Ce qui a gêné la lecture, le cas échéant. Jamais une raison d'écarter un fichier de l'import.
    public let anomaly: Anomaly?

    public init(moments: [UInt32], anomaly: Anomaly? = nil) {
        self.moments = moments
        self.anomaly = anomaly
    }

    /// Un fichier est highlighté quand il porte **au moins un moment**.
    ///
    /// Surtout pas « quand l'atome HMMT existe » : la caméra écrit le même atome de 332 octets
    /// sur tous les clips, tagués ou non. Voir `HMMT.parse`.
    public var isHighlighted: Bool { !moments.isEmpty }

    /// Aucun tag, et rien à signaler.
    public static let none = HiLightScan(moments: [])

    public enum Anomaly: Equatable, Sendable {
        /// Aucun atome `moov` de premier niveau. Fichier tronqué, ou pas un MP4.
        case noMoov
        /// `moov` sans `udta/HMMT`. Normal pour un fichier remuxé ou venu d'une autre caméra.
        case noHMMT
        /// `HMMT` trop court pour porter ne serait-ce que son compteur.
        case truncatedHMMT
        /// Le compteur annonce plus de moments que l'atome n'a d'emplacements. On lit ce qui tient.
        case countExceedsSlots(declared: UInt32, slots: Int)
    }
}

/// Décodage de l'atome `moov/udta/HMMT`, où la GoPro écrit les tags HiLight posés pendant le
/// tournage.
///
/// ```
/// charge utile, 324 octets sur HERO12, invariante :
///   [0..3]     uint32 gros-boutiste   nombre de moments
///   [4..323]   uint32 gros-boutiste × 80   emplacements, remplis de zéros
/// ```
///
/// **Le piège est là.** GoPro préalloue 80 emplacements : le clip sans le moindre highlight porte
/// exactement le même atome de 332 octets que le clip tagué, seul le compteur change. Déduire le
/// nombre de moments de la taille de l'atome donnerait 80 sur *tous* les clips, enverrait tout dans
/// `Highlights/` et ferait perdre à l'app sa seule raison d'être — sans lever la moindre erreur.
/// L'échantillon `hero12-sans-highlight.mp4` est là pour que ça ne passe jamais.
public enum HMMT {

    static let atomType = "HMMT"

    /// Plafond de lecture de la charge utile. Voir `HiLightReader.scan`.
    static let maximumPayloadLength: UInt64 = 65_536

    /// Décode une charge utile HMMT déjà lue.
    public static func parse(payload: [UInt8]) -> HiLightScan {
        guard payload.count >= 4 else {
            return HiLightScan(moments: [], anomaly: .truncatedHMMT)
        }

        let declared = MP4.be32(payload, 0)
        let slots = (payload.count - 4) / 4
        let readable = min(Int(declared), slots)

        var moments: [UInt32] = []
        moments.reserveCapacity(readable)
        for index in 0..<readable {
            moments.append(MP4.be32(payload, 4 + index * 4))
        }

        // Le compteur fait autorité : on ne filtre pas les valeurs nulles. Un highlight posé dans
        // la première milliseconde de la prise vaut 0, et il compte comme les autres.
        let anomaly: HiLightScan.Anomaly? = Int(declared) > slots
            ? .countExceedsSlots(declared: declared, slots: slots)
            : nil

        return HiLightScan(moments: moments, anomaly: anomaly)
    }
}

public enum HiLightReader {

    /// Lit les tags d'un fichier MP4.
    ///
    /// Ne lève que sur une erreur d'entrée-sortie réelle. Un fichier illisible *structurellement*
    /// — pas de `moov`, pas de `HMMT` — rend un résultat sans moment et avec une anomalie : il
    /// partira dans `Clips/`, ce qui est le bon comportement par défaut.
    public static func scan(fileURL: URL) throws -> HiLightScan {
        let reader = try FileByteReader(url: fileURL)
        return try scan(reader: reader)
    }

    public static func scan(reader: ByteReader) throws -> HiLightScan {
        // Chez GoPro `moov` ferme le fichier, derrière un `mdat` de dizaines de méga-octets. On
        // parcourt donc les atomes de premier niveau en ne lisant que leurs en-têtes, et on saute
        // `mdat` par sa taille. `last` plutôt que `first` : si un fichier portait deux `moov`, le
        // dernier est celui qui fait foi.
        let topLevel = try MP4.topLevelBoxes(in: reader)
        guard let moov = topLevel.last(where: { $0.type == "moov" }) else {
            return HiLightScan(moments: [], anomaly: .noMoov)
        }

        guard let udta = try MP4.children(of: moov, in: reader).first(where: { $0.type == "udta" }),
              let hmmt = try MP4.children(of: udta, in: reader).first(where: { $0.type == HMMT.atomType })
        else {
            return HiLightScan(moments: [], anomaly: .noHMMT)
        }

        // Une seule lecture, de la taille exacte de l'atome. 332 octets sur HERO12.
        // La borne n'est pas de la paranoïa gratuite : un fichier abîmé peut annoncer un HMMT de
        // plusieurs méga-octets, et on ne veut pas allouer ça pour trouver un compteur qui tient
        // dans les quatre premiers octets. 80 emplacements en font 324 ; 65 536 laisse une marge
        // très large à un futur modèle plus bavard.
        let capped = Int(min(hmmt.payloadLength, HMMT.maximumPayloadLength))
        let payload = try reader.read(at: hmmt.payloadOffset, count: capped)
        return HMMT.parse(payload: payload)
    }
}

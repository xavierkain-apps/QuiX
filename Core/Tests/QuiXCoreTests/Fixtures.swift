import Foundation
import XCTest
@testable import QuiXCore

/// Accès aux deux `moov` réels extraits de la HERO12 de Xavier, et fabrication de cartes factices.
enum Fixtures {

    static var directory: URL {
        Bundle.module.resourceURL!.appendingPathComponent("Fixtures", isDirectory: true)
    }

    /// Clip sans le moindre highlight. Son HMMT fait 332 octets quand même.
    static var withoutHighlight: URL { directory.appendingPathComponent("hero12-sans-highlight.mp4") }

    /// Clip portant un moment à 3436 ms.
    static var withHighlight: URL { directory.appendingPathComponent("hero12-un-highlight.mp4") }

    // MARK: - Fabrication d'octets MP4

    /// Construit un atome : taille sur 32 bits, type, charge utile.
    static func box(_ type: String, _ payload: [UInt8] = []) -> [UInt8] {
        let size = UInt32(8 + payload.count)
        return be32(size) + Array(type.utf8) + payload
    }

    static func be32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24 & 0xFF), UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)]
    }

    static func be64(_ value: UInt64) -> [UInt8] {
        (0..<8).map { UInt8((value >> (56 - 8 * $0)) & 0xFF) }
    }

    /// Une charge utile HMMT au format de la caméra : un compteur, puis `slots` emplacements
    /// dont seuls les premiers sont remplis.
    static func hmmtPayload(moments: [UInt32], slots: Int = 80, declaredCount: UInt32? = nil) -> [UInt8] {
        var payload = be32(declaredCount ?? UInt32(moments.count))
        for index in 0..<slots {
            payload += be32(index < moments.count ? moments[index] : 0)
        }
        return payload
    }

    /// Un fichier complet à la géométrie GoPro : `mdat` d'abord, `moov` en dernier.
    static func goProFile(moments: [UInt32], slots: Int = 80, declaredCount: UInt32? = nil) -> [UInt8] {
        let hmmt = box("HMMT", hmmtPayload(moments: moments, slots: slots, declaredCount: declaredCount))
        let udta = box("udta", hmmt)
        let moov = box("moov", udta)
        return box("ftyp", Array(repeating: 0, count: 12)) + box("mdat", Array(repeating: 0xAB, count: 64)) + moov
    }

    // MARK: - Cartes factices

    /// Crée un dossier temporaire, supprimé à la fin du test.
    static func temporaryDirectory(_ test: XCTestCase) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quix-tests-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        test.addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    /// Monte une fausse carte GoPro : `DCIM/100GOPRO/` peuplé des fichiers demandés.
    ///
    /// `files` associe un nom de fichier au contenu voulu — l'un des deux échantillons réels, ou
    /// des octets fabriqués.
    static func card(_ test: XCTestCase, folder: String = "100GOPRO", files: [String: [UInt8]]) throws -> URL {
        let volume = try temporaryDirectory(test)
        let dcim = volume.appendingPathComponent("DCIM/\(folder)", isDirectory: true)
        try FileManager.default.createDirectory(at: dcim, withIntermediateDirectories: true)
        for (name, bytes) in files {
            try Data(bytes).write(to: dcim.appendingPathComponent(name))
        }
        return volume
    }

    static func bytes(of url: URL) throws -> [UInt8] {
        [UInt8](try Data(contentsOf: url))
    }
}

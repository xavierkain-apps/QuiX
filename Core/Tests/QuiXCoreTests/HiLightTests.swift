import XCTest
@testable import QuiXCore

/// Les tests qui protègent le cœur du produit. Voir `docs/HILIGHT.md`.
final class HiLightTests: XCTestCase {

    // MARK: - Les deux clips réels

    func testRealClipWithOneHighlight() throws {
        let scan = try HiLightReader.scan(fileURL: Fixtures.withHighlight)
        XCTAssertEqual(scan.moments, [3436], "le moment relevé sur la HERO12 est à 3436 ms")
        XCTAssertTrue(scan.isHighlighted)
        XCTAssertNil(scan.anomaly)
    }

    /// **Le test le plus important du dépôt.**
    ///
    /// La caméra écrit un HMMT de 332 octets sur *tous* les clips, tagués ou non. Un parseur qui
    /// déduirait le nombre de moments de la taille de l'atome trouverait ici 80 highlights, tout
    /// partirait dans `Highlights/`, et l'app n'aurait plus d'objet — sans lever d'erreur.
    func testRealClipWithoutHighlightHasTheSameAtomButNoMoments() throws {
        let scan = try HiLightReader.scan(fileURL: Fixtures.withoutHighlight)
        XCTAssertEqual(scan.moments, [], "aucun moment, malgré un atome HMMT bien présent")
        XCTAssertFalse(scan.isHighlighted)
        XCTAssertNil(scan.anomaly, "l'absence de tags n'est pas une anomalie")
    }

    /// Et l'atome fait bien la même taille dans les deux fichiers : c'est le fait qui rend le piège
    /// possible, autant le figer.
    func testBothRealClipsCarryAnIdenticallySizedHMMT() throws {
        func hmmtLength(_ url: URL) throws -> UInt64 {
            let reader = try FileByteReader(url: url)
            let moov = try XCTUnwrap(MP4.topLevelBoxes(in: reader).last { $0.type == "moov" })
            let udta = try XCTUnwrap(MP4.children(of: moov, in: reader).first { $0.type == "udta" })
            let hmmt = try XCTUnwrap(MP4.children(of: udta, in: reader).first { $0.type == "HMMT" })
            return hmmt.payloadLength
        }
        XCTAssertEqual(try hmmtLength(Fixtures.withHighlight), 324)
        XCTAssertEqual(try hmmtLength(Fixtures.withoutHighlight), 324)
    }

    /// Chez GoPro `moov` ferme le fichier. Un lecteur qui chercherait les tags dans les premiers
    /// kilo-octets ne trouverait jamais rien.
    func testMoovComesAfterMdat() throws {
        let reader = try FileByteReader(url: Fixtures.withHighlight)
        let types = try MP4.topLevelBoxes(in: reader).map(\.type)
        XCTAssertEqual(types, ["ftyp", "free", "mdat", "moov"])
    }

    // MARK: - Décodage de HMMT

    func testCountIsAuthoritativeNotAtomSize() {
        let payload = Fixtures.hmmtPayload(moments: [1000, 2000], slots: 80)
        XCTAssertEqual(payload.count, 324)
        XCTAssertEqual(HMMT.parse(payload: payload).moments, [1000, 2000])
    }

    /// Un highlight posé dans la première milliseconde vaut 0. Filtrer les zéros le perdrait.
    func testZeroIsAValidMoment() {
        let scan = HMMT.parse(payload: Fixtures.hmmtPayload(moments: [0]))
        XCTAssertEqual(scan.moments, [0])
        XCTAssertTrue(scan.isHighlighted)
    }

    /// Un compteur aberrant ne doit pas faire lire au-delà de l'atome.
    func testCountLargerThanSlotsIsClampedAndReported() {
        let payload = Fixtures.hmmtPayload(moments: [10, 20], slots: 4, declaredCount: 999)
        let scan = HMMT.parse(payload: payload)
        XCTAssertEqual(scan.moments.count, 4, "on lit les quatre emplacements disponibles, pas 999")
        XCTAssertEqual(scan.moments.prefix(2).map { $0 }, [10, 20])
        XCTAssertEqual(scan.anomaly, .countExceedsSlots(declared: 999, slots: 4))
    }

    func testTruncatedHMMTIsReportedNotCrashed() {
        let scan = HMMT.parse(payload: [0, 0])
        XCTAssertEqual(scan.moments, [])
        XCTAssertEqual(scan.anomaly, .truncatedHMMT)
    }

    // MARK: - Fichiers qui ne coopèrent pas

    func testFileWithoutMoovReadsAsNoHighlightsNotAsAnError() throws {
        let bytes = Fixtures.box("ftyp", [0, 0, 0, 0]) + Fixtures.box("mdat", [1, 2, 3, 4])
        let scan = try HiLightReader.scan(reader: DataByteReader(bytes))
        XCTAssertFalse(scan.isHighlighted)
        XCTAssertEqual(scan.anomaly, .noMoov)
    }

    func testMoovWithoutHMMTReadsAsNoHighlights() throws {
        let moov = Fixtures.box("moov", Fixtures.box("udta", Fixtures.box("FIRM", [65, 66])))
        let scan = try HiLightReader.scan(reader: DataByteReader(Fixtures.box("mdat", [0]) + moov))
        XCTAssertFalse(scan.isHighlighted)
        XCTAssertEqual(scan.anomaly, .noHMMT)
    }

    func testEmptyFileDoesNotCrash() throws {
        let scan = try HiLightReader.scan(reader: DataByteReader([]))
        XCTAssertEqual(scan.anomaly, .noMoov)
    }

    func testSyntheticGoProGeometryIsRead() throws {
        let scan = try HiLightReader.scan(reader: DataByteReader(Fixtures.goProFile(moments: [500, 12_000])))
        XCTAssertEqual(scan.moments, [500, 12_000])
    }
}

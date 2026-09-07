import XCTest
@testable import QuiXCore

final class MP4BoxTests: XCTestCase {

    func testWalksSuccessiveBoxes() throws {
        let bytes = Fixtures.box("ftyp", [1, 2, 3, 4]) + Fixtures.box("mdat", [9, 9]) + Fixtures.box("moov")
        let boxes = try MP4.topLevelBoxes(in: DataByteReader(bytes))
        XCTAssertEqual(boxes.map(\.type), ["ftyp", "mdat", "moov"])
        XCTAssertEqual(boxes[0].payloadLength, 4)
        XCTAssertEqual(boxes[1].payloadOffset, 12 + 8)
        XCTAssertEqual(boxes[2].payloadLength, 0)
    }

    /// Une longue prise en 5,3K finit par produire un `mdat` de plus de 4 Go, écrit avec une taille
    /// sur 64 bits. Mal le sauter ferait perdre le `moov` qui suit — donc tous les highlights du
    /// fichier, en silence.
    func testSixtyFourBitSizeIsUnderstood() throws {
        let payload: [UInt8] = Array(repeating: 0x11, count: 10)
        let large = Fixtures.be32(1) + Array("mdat".utf8) + Fixtures.be64(UInt64(16 + payload.count)) + payload
        let bytes = large + Fixtures.box("moov", Fixtures.box("udta"))

        let boxes = try MP4.topLevelBoxes(in: DataByteReader(bytes))
        XCTAssertEqual(boxes.map(\.type), ["mdat", "moov"])
        XCTAssertEqual(boxes[0].payloadOffset, 16)
        XCTAssertEqual(boxes[0].payloadLength, 10)
    }

    /// Taille nulle : l'atome va jusqu'à la fin. Écrit par un enregistrement interrompu — la carte
    /// arrachée pendant que la caméra tournait. Le `moov` est alors avalé par `mdat` et le fichier
    /// n'a pas de tags lisibles ; il doit se lire « aucun highlight », jamais planter.
    func testZeroSizeBoxExtendsToTheEndAndEndsTheWalk() throws {
        let bytes = Fixtures.box("ftyp", [0, 0, 0, 0])
            + Fixtures.be32(0) + Array("mdat".utf8) + Array(repeating: 0xEE, count: 40)

        let boxes = try MP4.topLevelBoxes(in: DataByteReader(bytes))
        XCTAssertEqual(boxes.map(\.type), ["ftyp", "mdat"])
        XCTAssertEqual(boxes[1].payloadLength, 40)

        let scan = try HiLightReader.scan(reader: DataByteReader(bytes))
        XCTAssertEqual(scan.anomaly, .noMoov)
    }

    /// Un atome dont la taille annoncée déborde du fichier : on rend ce qui a été lu et on
    /// s'arrête, plutôt que d'aller chercher des octets au hasard.
    func testBoxLongerThanTheFileStopsTheWalk() throws {
        let bytes = Fixtures.box("ftyp", [0, 0, 0, 0]) + Fixtures.be32(9999) + Array("moov".utf8)
        let boxes = try MP4.topLevelBoxes(in: DataByteReader(bytes))
        XCTAssertEqual(boxes.map(\.type), ["ftyp"])
    }

    /// Une taille inférieure à l'en-tête ferait boucler à l'infini un parcours naïf.
    func testBoxSmallerThanItsHeaderStopsTheWalk() throws {
        let bytes = Fixtures.box("ftyp") + Fixtures.be32(3) + Array("junk".utf8) + [0, 0, 0, 0]
        let boxes = try MP4.topLevelBoxes(in: DataByteReader(bytes))
        XCTAssertEqual(boxes.map(\.type), ["ftyp"])
    }

    func testTruncatedHeaderStopsTheWalk() throws {
        let boxes = try MP4.topLevelBoxes(in: DataByteReader([0, 0, 0]))
        XCTAssertTrue(boxes.isEmpty)
    }

    func testChildrenStayInsideTheirParent() throws {
        let moov = Fixtures.box("moov", Fixtures.box("mvhd", [1, 2]) + Fixtures.box("udta", Fixtures.box("HMMT")))
        let reader = DataByteReader(moov + Fixtures.box("free", [0, 0, 0, 0]))
        let top = try MP4.topLevelBoxes(in: reader)
        let children = try MP4.children(of: top[0], in: reader)
        XCTAssertEqual(children.map(\.type), ["mvhd", "udta"], "`free` est un frère de `moov`, pas son enfant")
    }
}

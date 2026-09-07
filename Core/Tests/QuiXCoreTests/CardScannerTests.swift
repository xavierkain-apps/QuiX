import XCTest
@testable import QuiXCore

final class CardScannerTests: XCTestCase {

    func testRecognisesFolderNames() {
        XCTAssertTrue(CardScanner.isGoProFolderName("100GOPRO"))
        XCTAssertTrue(CardScanner.isGoProFolderName("101GOPRO"))
        XCTAssertTrue(CardScanner.isGoProFolderName("999GOPRO"))
        XCTAssertFalse(CardScanner.isGoProFolderName("100APPLE"))
        XCTAssertFalse(CardScanner.isGoProFolderName("GOPRO"))
        XCTAssertFalse(CardScanner.isGoProFolderName("10GOPRO"))
        XCTAssertFalse(CardScanner.isGoProFolderName(""))
    }

    /// Le nom du volume ne prouve rien : l'utilisateur a pu le renommer, et une carte d'un autre
    /// appareil peut très bien s'appeler « GOPRO ». Seule la structure `DCIM/###GOPRO` fait foi.
    /// C'est cette garde qui empêche l'app de toucher à la carte d'un autre appareil.
    func testAVolumeWithoutDCIMIsNotAGoProCard() throws {
        let volume = try Fixtures.temporaryDirectory(self)
        XCTAssertFalse(CardScanner.isGoProCard(volume))

        try FileManager.default.createDirectory(
            at: volume.appendingPathComponent("DCIM/100APPLE"), withIntermediateDirectories: true)
        XCTAssertFalse(CardScanner.isGoProCard(volume), "une carte d'iPhone n'est pas une carte GoPro")
    }

    func testAVolumeWithAGoProFolderIsACard() throws {
        let volume = try Fixtures.card(self, files: ["GX010001.MP4": Fixtures.goProFile(moments: [])])
        XCTAssertTrue(CardScanner.isGoProCard(volume))
    }

    /// L'aller-retour complet sur les deux vrais clips de la HERO12.
    func testScansTheTwoRealClips() throws {
        let volume = try Fixtures.card(self, files: [
            "GX013129.MP4": try Fixtures.bytes(of: Fixtures.withHighlight),
            "GX013097.MP4": try Fixtures.bytes(of: Fixtures.withoutHighlight)
        ])

        let result = try CardScanner.scan(volume: volume)
        XCTAssertEqual(result.takes.count, 2)
        XCTAssertEqual(result.highlightedTakes.map(\.number), [3129])
        XCTAssertEqual(result.takes.first { $0.number == 3129 }?.momentCount, 1)
        XCTAssertEqual(result.takes.first { $0.number == 3097 }?.momentCount, 0)
    }

    func testIgnoresProxiesThumbnailsAndForeignFiles() throws {
        let volume = try Fixtures.card(self, files: [
            "GX010001.MP4": Fixtures.goProFile(moments: []),
            "GL010001.LRV": [0, 1, 2],
            "GX010001.THM": [0, 1, 2],
            "notes.txt": [0, 1, 2]
        ])

        let result = try CardScanner.scan(volume: volume)
        XCTAssertEqual(result.takes.count, 1)
        XCTAssertEqual(result.takes[0].chapters.count, 1, "le proxy ne compte pas comme un chapitre")
        XCTAssertEqual(result.ignored.count, 3)
    }

    func testReadsSeveralDCIMFolders() throws {
        let volume = try Fixtures.card(self, folder: "100GOPRO",
                                       files: ["GX010001.MP4": Fixtures.goProFile(moments: [])])
        let second = volume.appendingPathComponent("DCIM/101GOPRO", isDirectory: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try Data(Fixtures.goProFile(moments: [999]))
            .write(to: second.appendingPathComponent("GX011500.MP4"))

        let result = try CardScanner.scan(volume: volume)
        XCTAssertEqual(result.takes.count, 2)
        XCTAssertEqual(result.highlightedTakes.map(\.number), [1500])
    }

    /// Un clip abîmé sur cinquante ne doit pas faire perdre l'import entier. Il part dans `Clips/`,
    /// ce qui est le défaut sûr.
    func testAnUnreadableFileDoesNotAbortTheScan() throws {
        let volume = try Fixtures.card(self, files: [
            "GX010001.MP4": Fixtures.goProFile(moments: [1000]),
            "GX010002.MP4": Array(repeating: 0x00, count: 30)
        ])

        let result = try CardScanner.scan(volume: volume)
        XCTAssertEqual(result.takes.count, 2)
        XCTAssertEqual(result.highlightedTakes.map(\.number), [1])
        XCTAssertFalse(result.takes.first { $0.number == 2 }!.isHighlighted)
    }

    func testProgressCountsEveryVideo() throws {
        let volume = try Fixtures.card(self, files: [
            "GX010001.MP4": Fixtures.goProFile(moments: []),
            "GX010002.MP4": Fixtures.goProFile(moments: []),
            "GL010001.LRV": [0]
        ])

        var seen: [Int] = []
        var total = 0
        _ = try CardScanner.scan(volume: volume, progress: { done, count in
            seen.append(done); total = count
        })
        XCTAssertEqual(seen, [1, 2])
        XCTAssertEqual(total, 2, "les .LRV ne sont pas comptés dans la progression")
    }

    func testRecordsFileSizes() throws {
        let bytes = Fixtures.goProFile(moments: [])
        let volume = try Fixtures.card(self, files: ["GX010001.MP4": bytes])
        let result = try CardScanner.scan(volume: volume)
        XCTAssertEqual(result.totalSize, UInt64(bytes.count))
    }
}

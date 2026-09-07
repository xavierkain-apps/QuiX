import XCTest
@testable import QuiXCore

final class GoProFileNameTests: XCTestCase {

    func testModernName() throws {
        let name = try XCTUnwrap(GoProFileName("GX010123.MP4"))
        XCTAssertEqual(name.encoding, "GX")
        XCTAssertEqual(name.chapter, 1)
        XCTAssertEqual(name.take, 123)
        XCTAssertEqual(name.kind, .video)
    }

    /// Les deux fichiers réels de Xavier, tels que la HERO12 les a nommés.
    func testRealNamesFromTheCamera() throws {
        XCTAssertEqual(try XCTUnwrap(GoProFileName("GX013097.MP4")).take, 3097)
        XCTAssertEqual(try XCTUnwrap(GoProFileName("GX013129.MP4")).take, 3129)
    }

    /// Forme ancienne : `GOPR0123.MP4` est le premier chapitre, `GP010123.MP4` le second. Les deux
    /// portent la prise 123 et doivent se retrouver ensemble.
    func testLegacyFirstChapter() throws {
        let first = try XCTUnwrap(GoProFileName("GOPR0123.MP4"))
        let second = try XCTUnwrap(GoProFileName("GP010123.MP4"))
        XCTAssertEqual(first.chapter, 0)
        XCTAssertEqual(second.chapter, 1)
        XCTAssertEqual(first.take, second.take)
    }

    func testChapterOrdering() throws {
        let chapters = ["GX030123.MP4", "GX010123.MP4", "GX020123.MP4"]
            .compactMap(GoProFileName.init)
            .map(\.chapter)
            .sorted()
        XCTAssertEqual(chapters, [1, 2, 3])
    }

    func testCompanionFilesAreRecognisedButNotVideos() throws {
        XCTAssertEqual(try XCTUnwrap(GoProFileName("GL010123.LRV")).kind, .proxy)
        XCTAssertEqual(try XCTUnwrap(GoProFileName("GX010123.THM")).kind, .thumbnail)
        XCTAssertEqual(try XCTUnwrap(GoProFileName("GOPR0123.JPG")).kind, .other("JPG"))
        XCTAssertFalse(try XCTUnwrap(GoProFileName("GL010123.LRV")).kind.isVideo)
    }

    func testLowercaseNamesAreAccepted() throws {
        let name = try XCTUnwrap(GoProFileName("gx010123.mp4"))
        XCTAssertEqual(name.take, 123)
        XCTAssertEqual(name.kind, .video)
    }

    func testFullPathsAreAccepted() throws {
        XCTAssertEqual(try XCTUnwrap(GoProFileName("/Volumes/GOPRO/DCIM/100GOPRO/GX010123.MP4")).take, 123)
    }

    /// Ce qui n'est pas un nom GoPro n'est pas importé, plutôt que rangé au hasard.
    func testRejectsWhatIsNotAGoProName() {
        for candidate in ["GX01012.MP4", "GX0101234.MP4", "GXAB0123.MP4", "IMG_0123.MP4",
                          "GX010123", "", ".MP4", "GX01012A.MP4"] {
            XCTAssertNil(GoProFileName(candidate), "« \(candidate) » ne devrait pas être accepté")
        }
    }
}

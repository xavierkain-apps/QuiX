import XCTest
@testable import QuiXCore

final class TakeTests: XCTestCase {

    private func scanned(_ filename: String, folder: String = "100GOPRO",
                         moments: [UInt32] = [], size: UInt64 = 1000) -> ScannedFile {
        ScannedFile(
            file: MediaFile(url: URL(fileURLWithPath: "/carte/DCIM/\(folder)/\(filename)"),
                            folder: folder,
                            name: GoProFileName(filename)!,
                            size: size,
                            modified: Date(timeIntervalSince1970: 1_700_000_000)),
            hiLight: HiLightScan(moments: moments)
        )
    }

    func testChaptersOfOneTakeAreGroupedTogether() {
        let takes = TakeBuilder.group([
            scanned("GX020123.MP4"), scanned("GX010123.MP4"), scanned("GX010124.MP4")
        ])
        XCTAssertEqual(takes.count, 2)
        XCTAssertEqual(takes[0].number, 123)
        XCTAssertEqual(takes[0].chapters.count, 2)
        XCTAssertEqual(takes[1].chapters.count, 1)
    }

    func testChaptersAreOrdered() {
        let take = TakeBuilder.group([
            scanned("GX030123.MP4"), scanned("GX010123.MP4"), scanned("GX020123.MP4")
        ])[0]
        XCTAssertEqual(take.chapters.map(\.file.name.chapter), [1, 2, 3])
    }

    /// **La règle du produit.** Un highlight sur un seul chapitre emporte la prise entière.
    /// Répartir les chapitres entre `Highlights/` et `Clips/` donnerait deux moitiés de vidéo
    /// dont aucune n'est regardable.
    func testOneTaggedChapterMakesTheWholeTakeHighlighted() {
        let take = TakeBuilder.group([
            scanned("GX010123.MP4"),
            scanned("GX020123.MP4", moments: [4200]),
            scanned("GX030123.MP4")
        ])[0]
        XCTAssertTrue(take.isHighlighted)
        XCTAssertEqual(take.momentCount, 1)
        XCTAssertEqual(take.chapters.count, 3)
    }

    func testATakeWithoutAnyMomentIsNotHighlighted() {
        let take = TakeBuilder.group([scanned("GX010123.MP4"), scanned("GX020123.MP4")])[0]
        XCTAssertFalse(take.isHighlighted)
        XCTAssertEqual(take.momentCount, 0)
    }

    /// La forme ancienne mélange `GOPR0123` et `GP010123` : même prise, deux préfixes.
    func testLegacyChaptersJoinTheSameTake() {
        let takes = TakeBuilder.group([scanned("GOPR0123.MP4"), scanned("GP010123.MP4", moments: [10])])
        XCTAssertEqual(takes.count, 1)
        XCTAssertTrue(takes[0].isHighlighted)
    }

    /// Le compteur de la caméra repasse par zéro et deux dossiers DCIM peuvent porter le même
    /// numéro de prise. Ce sont deux prises différentes, pas une prise à quatre chapitres.
    func testSameNumberInTwoFoldersAreTwoDistinctTakes() {
        let takes = TakeBuilder.group([
            scanned("GX010001.MP4", folder: "100GOPRO"),
            scanned("GX010001.MP4", folder: "101GOPRO", moments: [1])
        ])
        XCTAssertEqual(takes.count, 2)
        XCTAssertEqual(takes.filter(\.isHighlighted).count, 1)
    }

    func testTotalSizeAddsUpChapters() {
        let take = TakeBuilder.group([
            scanned("GX010123.MP4", size: 4_000_000_000),
            scanned("GX020123.MP4", size: 1_500_000_000)
        ])[0]
        XCTAssertEqual(take.totalSize, 5_500_000_000)
    }
}

import XCTest
@testable import QuiXCore

final class ImportIndexTests: XCTestCase {

    private func file(_ filename: String, size: UInt64 = 1000, modified: TimeInterval = 1_700_000_000) -> MediaFile {
        MediaFile(url: URL(fileURLWithPath: "/carte/DCIM/100GOPRO/\(filename)"),
                  folder: "100GOPRO", name: GoProFileName(filename)!,
                  size: size, modified: Date(timeIntervalSince1970: modified))
    }

    func testRecordThenFind() {
        var index = ImportIndex()
        let media = file("GX010123.MP4")
        XCTAssertNil(index.entry(for: media))

        index.record(media, relativeDestination: "2026-09-07/Clips/GX010123.MP4", at: Date())
        XCTAssertEqual(index.entry(for: media)?.destination, "2026-09-07/Clips/GX010123.MP4")
        XCTAssertEqual(index.count, 1)
    }

    /// La clé, c'est nom + taille + date. Le nom seul confondrait deux cartes différentes portant
    /// chacune son `GX010001.MP4`.
    func testDifferentSizeIsADifferentFile() {
        var index = ImportIndex()
        index.record(file("GX010123.MP4", size: 1000), relativeDestination: "a", at: Date())
        XCTAssertNil(index.entry(for: file("GX010123.MP4", size: 2000)))
    }

    func testDifferentDateIsADifferentFile() {
        var index = ImportIndex()
        index.record(file("GX010123.MP4", modified: 1_700_000_000), relativeDestination: "a", at: Date())
        XCTAssertNil(index.entry(for: file("GX010123.MP4", modified: 1_700_000_500)))
    }

    /// Les cartes en FAT32 ne gardent la date qu'à deux secondes près et un aller-retour par un
    /// autre système de fichiers peut décaler les millisecondes. La clé arrondit à la seconde pour
    /// qu'un index ne se périme pas tout seul.
    func testSubSecondDifferencesDoNotBreakTheKey() {
        var index = ImportIndex()
        index.record(file("GX010123.MP4", modified: 1_700_000_000.2), relativeDestination: "a", at: Date())
        XCTAssertNotNil(index.entry(for: file("GX010123.MP4", modified: 1_700_000_000.4)))
    }

    func testRoundTripsThroughDisk() throws {
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        index.record(file("GX010123.MP4"), relativeDestination: "2026-09-07/Highlights/GX010123.MP4", at: Date())
        try ImportIndexStore.save(index, toLibrary: library)

        let reloaded = ImportIndexStore.load(fromLibrary: library)
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded.entry(for: file("GX010123.MP4"))?.destination,
                       "2026-09-07/Highlights/GX010123.MP4")
    }

    func testMissingIndexLoadsEmpty() throws {
        let library = try Fixtures.temporaryDirectory(self)
        XCTAssertEqual(ImportIndexStore.load(fromLibrary: library).count, 0)
    }

    /// Un index abîmé ne doit jamais empêcher un import : au pire on recopie, et le plan écarte de
    /// toute façon ce qui est déjà présent à destination.
    func testCorruptIndexLoadsEmptyRatherThanThrowing() throws {
        let library = try Fixtures.temporaryDirectory(self)
        try Data("ceci n'est pas du JSON".utf8).write(to: ImportIndexStore.url(inLibrary: library))
        XCTAssertEqual(ImportIndexStore.load(fromLibrary: library).count, 0)
    }

    /// L'index vit dans la bibliothèque : supprimer le dossier importé doit suffire à pouvoir tout
    /// réimporter.
    func testIndexLivesInTheLibrary() throws {
        let library = try Fixtures.temporaryDirectory(self)
        try ImportIndexStore.save(ImportIndex(), toLibrary: library)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: library.appendingPathComponent(".quix-index.json").path))
    }
}

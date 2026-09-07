import XCTest
@testable import QuiXCore

/// Le parcours complet, des octets réels de la caméra jusqu'aux fichiers rangés : scan, plan,
/// copie vérifiée, index. C'est ce test qui dit si le produit fait ce qu'il promet.
final class ImportEndToEndTests: XCTestCase {

    private func realCard(_ test: XCTestCase) throws -> URL {
        try Fixtures.card(test, files: [
            // Prise 3129 : taguée, un seul chapitre.
            "GX013129.MP4": try Fixtures.bytes(of: Fixtures.withHighlight),
            // Prise 3097 : sans tag.
            "GX013097.MP4": try Fixtures.bytes(of: Fixtures.withoutHighlight),
            // Prise 3200 : deux chapitres, seul le second est tagué.
            "GX013200.MP4": try Fixtures.bytes(of: Fixtures.withoutHighlight),
            "GX023200.MP4": try Fixtures.bytes(of: Fixtures.withHighlight),
            // Compagnons ignorés.
            "GL013129.LRV": [0, 1, 2],
            "GX013129.THM": [0, 1, 2]
        ])
    }

    private func runImport(card: URL, library: URL, folder: String = "2026-09-07",
                           index: inout ImportIndex) throws -> ImportReport {
        let scan = try CardScanner.scan(volume: card)
        let plan = ImportPlanner.plan(takes: scan.takes, into: library,
                                      folderName: folder, index: index)
        let report = ImportRunner.run(plan, library: library, index: &index)
        try ImportIndexStore.save(index, toLibrary: library)
        return report
    }

    private func contents(_ url: URL) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted()
    }

    func testSortsHighlightsFromClipsWithoutSplittingATake() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()

        let report = try runImport(card: card, library: library, index: &index)
        XCTAssertTrue(report.failures.isEmpty, "\(report.failures)")

        let folder = library.appendingPathComponent("2026-09-07")
        XCTAssertEqual(contents(folder.appendingPathComponent("Highlights")),
                       ["GX013129.MP4", "GX013200.MP4", "GX023200.MP4"],
                       "les deux chapitres de la prise 3200 partent ensemble, malgré un seul tag")
        XCTAssertEqual(contents(folder.appendingPathComponent("Clips")), ["GX013097.MP4"])
    }

    func testCopiedFilesAreIdenticalToTheOriginals() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        _ = try runImport(card: card, library: library, index: &index)

        let source = card.appendingPathComponent("DCIM/100GOPRO/GX013129.MP4")
        let copy = library.appendingPathComponent("2026-09-07/Highlights/GX013129.MP4")
        XCTAssertEqual(try Data(contentsOf: copy), try Data(contentsOf: source))

        // Et la copie porte toujours ses tags : c'est le même fichier, pas seulement la même taille.
        XCTAssertEqual(try HiLightReader.scan(fileURL: copy).moments, [3436])
    }

    /// **Jamais d'effacement de la carte.** Après un import complet, elle doit être intacte.
    func testTheCardIsUntouched() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        let folder = card.appendingPathComponent("DCIM/100GOPRO")
        let before = contents(folder)
        let sizes = before.map { ImportPlanner.sizeOnDisk(folder.appendingPathComponent($0)) }

        var index = ImportIndex()
        _ = try runImport(card: card, library: library, index: &index)

        XCTAssertEqual(contents(folder), before)
        XCTAssertEqual(before.map { ImportPlanner.sizeOnDisk(folder.appendingPathComponent($0)) }, sizes)
    }

    /// Rebrancher la carte ne recopie que le neuf.
    func testSecondImportOfTheSameCardCopiesNothing() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)

        var index = ImportIndex()
        let first = try runImport(card: card, library: library, index: &index)
        XCTAssertEqual(first.copied.count, 4)

        var reloaded = ImportIndexStore.load(fromLibrary: library)
        let second = try runImport(card: card, library: library, folder: "2026-09-08", index: &reloaded)
        XCTAssertTrue(second.copied.isEmpty)
        XCTAssertEqual(second.alreadyImported.count, 4)
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: library.appendingPathComponent("2026-09-08/Clips").path),
            "aucun dossier vide ne doit apparaître pour un import qui ne copie rien")
    }

    func testNewClipsOnASecondImportAreTheOnlyOnesCopied() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        _ = try runImport(card: card, library: library, index: &index)

        try Data(Fixtures.goProFile(moments: [777]))
            .write(to: card.appendingPathComponent("DCIM/100GOPRO/GX013300.MP4"))

        var reloaded = ImportIndexStore.load(fromLibrary: library)
        let second = try runImport(card: card, library: library, folder: "2026-09-08", index: &reloaded)

        XCTAssertEqual(second.copied.map(\.source.filename), ["GX013300.MP4"])
        XCTAssertEqual(contents(library.appendingPathComponent("2026-09-08/Highlights")), ["GX013300.MP4"])
    }

    /// Si Xavier supprime le dossier importé, le fichier doit revenir. L'index seul ne décide pas.
    func testDeletingTheImportedFolderMakesTheClipsComeBack() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        _ = try runImport(card: card, library: library, index: &index)

        try FileManager.default.removeItem(at: library.appendingPathComponent("2026-09-07"))

        var reloaded = ImportIndexStore.load(fromLibrary: library)
        let second = try runImport(card: card, library: library, folder: "2026-09-09", index: &reloaded)
        XCTAssertEqual(second.copied.count, 4)
    }

    func testReportPointsAtTheHighlightsFolder() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        let report = try runImport(card: card, library: library, index: &index)

        XCTAssertEqual(report.highlightsFolder.path,
                       library.appendingPathComponent("2026-09-07/Highlights").path)
        XCTAssertEqual(report.highlightedTakeCount, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: report.highlightsFolder.path))
    }

    func testProgressReachesTheEnd() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        let scan = try CardScanner.scan(volume: card)
        let plan = ImportPlanner.plan(takes: scan.takes, into: library,
                                      folderName: "2026-09-07", index: index)

        var last: ImportProgress?
        ImportRunner.run(plan, library: library, index: &index, progress: { last = $0 })

        XCTAssertEqual(last?.bytesCopied, plan.byteCount)
        XCTAssertEqual(last?.fraction, 1)
    }

    /// Un échec sur un fichier ne doit pas emporter les autres.
    func testOneFailureDoesNotStopTheRest() throws {
        let card = try realCard(self)
        let library = try Fixtures.temporaryDirectory(self)
        var index = ImportIndex()
        let scan = try CardScanner.scan(volume: card)
        let plan = ImportPlanner.plan(takes: scan.takes, into: library,
                                      folderName: "2026-09-07", index: index)

        // On plante volontairement une copie en occupant sa destination.
        let blocked = plan.copies[0]
        try FileManager.default.createDirectory(at: blocked.destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data("occupé".utf8).write(to: blocked.destination)

        let report = ImportRunner.run(plan, library: library, index: &index)
        XCTAssertEqual(report.failures.count, 1)
        XCTAssertEqual(report.copied.count, plan.copies.count - 1)
    }
}

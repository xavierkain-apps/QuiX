import XCTest
@testable import QuiXCore

final class ImportPlannerTests: XCTestCase {

    private let library = URL(fileURLWithPath: "/Users/xavier/Films/GoPro", isDirectory: true)
    private let modified = Date(timeIntervalSince1970: 1_700_000_000)

    private func file(_ filename: String, folder: String = "100GOPRO", size: UInt64 = 1000) -> MediaFile {
        MediaFile(url: URL(fileURLWithPath: "/carte/DCIM/\(folder)/\(filename)"),
                  folder: folder, name: GoProFileName(filename)!, size: size, modified: modified)
    }

    private func take(_ number: Int, files: [(String, [UInt32])], folder: String = "100GOPRO") -> Take {
        Take(number: number, folder: folder, chapters: files.map { name, moments in
            ScannedFile(file: file(name, folder: folder), hiLight: HiLightScan(moments: moments))
        })
    }

    private func plan(_ takes: [Take], index: ImportIndex = ImportIndex(),
                      existing: @escaping (URL) -> UInt64? = { _ in nil }) -> ImportPlan {
        ImportPlanner.plan(takes: takes, into: library, folderName: "2026-09-07",
                           index: index, existingSize: existing)
    }

    func testHighlightedTakeGoesToHighlightsAndTheRestToClips() {
        let result = plan([
            take(123, files: [("GX010123.MP4", [3436])]),
            take(124, files: [("GX010124.MP4", [])])
        ])
        XCTAssertEqual(result.copies.map(\.relativeDestination), [
            "2026-09-07/Highlights/GX010123.MP4",
            "2026-09-07/Clips/GX010124.MP4"
        ])
    }

    /// La destination est décidée une fois pour la prise. Aucun chapitre ne part de son côté.
    func testEveryChapterOfATaggedTakeFollowsItIntoHighlights() {
        let result = plan([take(123, files: [
            ("GX010123.MP4", []), ("GX020123.MP4", [4200]), ("GX030123.MP4", [])
        ])])
        XCTAssertEqual(result.copies.count, 3)
        XCTAssertTrue(result.copies.allSatisfy { $0.isHighlighted })
        XCTAssertTrue(result.copies.allSatisfy { $0.relativeDestination.contains("/Highlights/") })
    }

    func testImportFolderIsTheDatedFolderInsideTheLibrary() {
        XCTAssertEqual(plan([take(1, files: [("GX010001.MP4", [])])]).importFolder.path,
                       library.appendingPathComponent("2026-09-07").path)
    }

    func testByteCountAndCountsAreReported() {
        let result = plan([
            take(1, files: [("GX010001.MP4", [5])]),
            take(2, files: [("GX010002.MP4", []), ("GX020002.MP4", [])])
        ])
        XCTAssertEqual(result.byteCount, 3000)
        XCTAssertEqual(result.takeCount, 2)
        XCTAssertEqual(result.highlightedTakeCount, 1)
    }

    // MARK: - Idempotence

    /// Rebrancher la carte ne recopie que le neuf.
    func testAlreadyImportedFileIsSkipped() {
        var index = ImportIndex()
        let known = file("GX010123.MP4")
        index.record(known, relativeDestination: "2026-09-01/Clips/GX010123.MP4", at: Date())

        let result = plan([take(123, files: [("GX010123.MP4", [])]),
                           take(124, files: [("GX010124.MP4", [])])],
                          index: index,
                          existing: { $0.path.hasSuffix("2026-09-01/Clips/GX010123.MP4") ? 1000 : nil })

        XCTAssertEqual(result.copies.map(\.source.filename), ["GX010124.MP4"])
        XCTAssertEqual(result.alreadyImported.map(\.filename), ["GX010123.MP4"])
    }

    /// L'index seul ne suffit pas : si Xavier a supprimé le dossier importé, le fichier doit
    /// revenir. Se fier à l'index sans regarder le disque le rendrait définitivement introuvable.
    func testIndexedButMissingOnDiskIsImportedAgain() {
        var index = ImportIndex()
        index.record(file("GX010123.MP4"), relativeDestination: "2026-09-01/Clips/GX010123.MP4", at: Date())

        let result = plan([take(123, files: [("GX010123.MP4", [])])], index: index, existing: { _ in nil })
        XCTAssertEqual(result.copies.count, 1)
        XCTAssertTrue(result.alreadyImported.isEmpty)
    }

    /// Une copie de la bonne taille est la preuve qu'on cherche ; une copie tronquée ne l'est pas.
    func testIndexedButWrongSizeOnDiskIsImportedAgain() {
        var index = ImportIndex()
        index.record(file("GX010123.MP4"), relativeDestination: "2026-09-01/Clips/GX010123.MP4", at: Date())

        let result = plan([take(123, files: [("GX010123.MP4", [])])], index: index, existing: { _ in 12 })
        XCTAssertEqual(result.copies.count, 1)
    }

    /// Un clip modifié entre deux branchements n'est plus le même fichier : la clé de l'index tient
    /// compte de la taille et de la date.
    func testSameNameButDifferentSizeIsNotConsideredImported() {
        var index = ImportIndex()
        index.record(file("GX010123.MP4", size: 1000),
                     relativeDestination: "2026-09-01/Clips/GX010123.MP4", at: Date())

        let bigger = Take(number: 123, folder: "100GOPRO", chapters: [
            ScannedFile(file: file("GX010123.MP4", size: 2000), hiLight: .none)
        ])
        XCTAssertEqual(plan([bigger], index: index, existing: { _ in 1000 }).copies.count, 1)
    }

    // MARK: - Collisions

    /// Deux dossiers DCIM peuvent porter le même nom de fichier après un tour de compteur. Écraser
    /// la première copie perdrait une prise en silence — exactement ce que ce produit doit éviter.
    func testSameFilenameInTwoFoldersDoesNotOverwrite() {
        let result = plan([
            take(1, files: [("GX010001.MP4", [])], folder: "100GOPRO"),
            take(1, files: [("GX010001.MP4", [])], folder: "101GOPRO")
        ])
        let destinations = Set(result.copies.map(\.relativeDestination))
        XCTAssertEqual(destinations.count, 2, "les deux copies doivent viser des chemins différents")
        XCTAssertTrue(destinations.contains("2026-09-07/Clips/GX010001.MP4"))
        XCTAssertTrue(destinations.contains("2026-09-07/Clips/GX010001-101GOPRO.MP4"))
    }

    // MARK: - Nom du dossier

    func testFolderNameIsISODate() {
        let date = Date(timeIntervalSince1970: 1_757_260_800) // 2025-09-07 16:00 UTC, soit 18:00 à Paris
        XCTAssertEqual(ImportFolderName.iso(for: date, timeZone: TimeZone(identifier: "Europe/Paris")!),
                       "2025-09-07")
    }

    func testFolderNameFollowsTheLocalDayNotUTC() {
        let date = Date(timeIntervalSince1970: 1_757_286_000) // 2025-09-07 23:00 UTC, soit le 8 à 11:00 à Auckland
        XCTAssertEqual(ImportFolderName.iso(for: date, timeZone: TimeZone(identifier: "Pacific/Auckland")!),
                       "2025-09-08")
    }
}

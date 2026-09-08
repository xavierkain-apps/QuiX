import XCTest
@testable import QuiXCore

/// L'effacement est la seule opération irréversible de l'app. Ces tests portent moins sur ce
/// qu'elle fait que sur tout ce qu'elle doit refuser de faire.
final class CameraCleanupTests: XCTestCase {

    private let library = URL(fileURLWithPath: "/tmp/bibliothèque")

    private func file(_ name: String, take: Int, chapter: Int = 1, size: UInt64 = 1_000) -> MediaFile {
        MediaFile(url: URL(string: "http://172.27.102.51:8080/videos/DCIM/100GOPRO/\(name)")!,
                  folder: "100GOPRO",
                  name: GoProFileName(name)!,
                  size: size,
                  modified: Date(timeIntervalSince1970: 1_700_000_000))
    }

    private func take(_ number: Int, _ files: [MediaFile]) -> Take {
        Take(number: number, folder: "100GOPRO",
             chapters: files.map { ScannedFile(file: $0, hiLight: .none) })
    }

    /// Un index qui connaît les fichiers, et un disque qui les porte à la bonne taille.
    private func index(for files: [MediaFile]) -> ImportIndex {
        var index = ImportIndex()
        for file in files {
            index.record(file, relativeDestination: "2026-09-08/Clips/\(file.filename)",
                         at: Date())
        }
        return index
    }

    func testEverythingCopiedMakesTheCameraSafeToErase() {
        let files = [file("GX010001.MP4", take: 1), file("GX010002.MP4", take: 2)]
        let plan = CameraCleanup.plan(takes: [take(1, [files[0]]), take(2, [files[1]])],
                                      library: library, index: index(for: files),
                                      existingSize: { _ in 1_000 })
        XCTAssertEqual(plan.cameraCount, 2)
        XCTAssertEqual(plan.verifiedCount, 2)
        XCTAssertTrue(plan.isSafeToErase)
    }

    /// Le cas qui compte : un seul fichier non prouvé retient tout.
    func testOneMissingCopyWithholdsTheWholeErase() {
        let copied = file("GX010001.MP4", take: 1)
        let missing = file("GX010002.MP4", take: 2)
        let plan = CameraCleanup.plan(
            takes: [take(1, [copied]), take(2, [missing])],
            library: library, index: index(for: [copied]),      // le second n'a jamais été importé
            existingSize: { _ in 1_000 })

        XCTAssertEqual(plan.verifiedCount, 1)
        XCTAssertEqual(plan.unverified.map(\.filename), ["GX010002.MP4"])
        XCTAssertFalse(plan.isSafeToErase)
    }

    /// L'index seul ne suffit pas : c'est le disque qui fait foi. Un dossier vidé à la main doit
    /// retenir l'effacement, même si l'index se souvient d'un import réussi.
    func testAnIndexedFileDeletedFromTheDiskIsNotVerified() {
        let files = [file("GX010001.MP4", take: 1)]
        let plan = CameraCleanup.plan(takes: [take(1, files)], library: library,
                                      index: index(for: files),
                                      existingSize: { _ in nil })   // plus rien sur le disque
        XCTAssertFalse(plan.isSafeToErase)
        XCTAssertEqual(plan.unverified.count, 1)
    }

    /// Une copie de la mauvaise taille est une copie ratée, pas une copie.
    func testATruncatedCopyIsNotVerified() {
        let files = [file("GX010001.MP4", take: 1, size: 5_000)]
        let plan = CameraCleanup.plan(takes: [take(1, files)], library: library,
                                      index: index(for: files),
                                      existingSize: { _ in 4_096 })
        XCTAssertFalse(plan.isSafeToErase)
    }

    /// Tous les chapitres d'une prise comptent, pas seulement le premier.
    func testEveryChapterOfATakeIsAccountedFor() {
        let chapters = [file("GX010001.MP4", take: 1), file("GX020001.MP4", take: 1)]
        let plan = CameraCleanup.plan(takes: [take(1, chapters)], library: library,
                                      index: index(for: [chapters[0]]),
                                      existingSize: { _ in 1_000 })
        XCTAssertEqual(plan.cameraCount, 2)
        XCTAssertFalse(plan.isSafeToErase)
    }

    /// Une caméra vide n'est pas « sûre à effacer » : il n'y a rien à effacer.
    func testAnEmptyCameraIsNotOfferedForErasing() {
        let plan = CameraCleanup.plan(takes: [], library: library, index: ImportIndex(),
                                      existingSize: { _ in nil })
        XCTAssertFalse(plan.isSafeToErase)
    }

    /// La garde est dans le moteur, pas seulement dans le bouton grisé de la fenêtre.
    func testEraseRefusesAPlanThatIsNotSafe() {
        let missing = file("GX010002.MP4", take: 2)
        let plan = CameraCleanup.plan(takes: [take(2, [missing])], library: library,
                                      index: ImportIndex(), existingSize: { _ in nil })
        XCTAssertThrowsError(try CameraCleanup.erase(plan, from: GoProCamera(host: "127.0.0.1"))) {
            XCTAssertEqual($0 as? CameraCleanup.Failure, .notVerified)
        }
    }
}

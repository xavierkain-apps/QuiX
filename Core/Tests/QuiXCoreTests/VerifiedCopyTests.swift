import XCTest
@testable import QuiXCore

final class VerifiedCopyTests: XCTestCase {

    private func makeSource(_ directory: URL, name: String = "GX010123.MP4",
                            bytes: Int = 300_000) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data((0..<bytes).map { UInt8($0 % 251) }).write(to: url)
        return url
    }

    func testCopiesContentExactly() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let destination = directory.appendingPathComponent("out/GX010123.MP4")

        try VerifiedCopy.copy(from: source, to: destination)

        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: source))
    }

    func testCreatesMissingDirectories() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let destination = directory.appendingPathComponent("2026-09-07/Highlights/GX010123.MP4")

        try VerifiedCopy.copy(from: source, to: destination)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    /// **La règle qui ne se négocie pas.** Une erreur d'import se rattrape, une carte effacée non.
    func testNeverTouchesTheSource() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let before = try Data(contentsOf: source)

        try VerifiedCopy.copy(from: source, to: directory.appendingPathComponent("out/copie.MP4"))

        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: source), before)
    }

    func testRefusesToOverwriteAnExistingFile() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let destination = directory.appendingPathComponent("existant.MP4")
        try Data("déjà là".utf8).write(to: destination)

        XCTAssertThrowsError(try VerifiedCopy.copy(from: source, to: destination)) { error in
            XCTAssertEqual(error as? CopyFailure, .destinationExists(destination))
        }
        XCTAssertEqual(try Data(contentsOf: destination), Data("déjà là".utf8))
    }

    /// Une copie interrompue ne doit pas laisser un `.MP4` de bonne apparence et de contenu
    /// tronqué, que le Finder afficherait comme un clip valide.
    func testCancellationLeavesNothingBehind() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory, bytes: 12_000_000)
        let destination = directory.appendingPathComponent("out/GX010123.MP4")

        var calls = 0
        XCTAssertThrowsError(try VerifiedCopy.copy(from: source, to: destination,
                                                   isCancelled: { calls += 1; return calls > 1 })) { error in
            XCTAssertEqual(error as? CopyFailure, .cancelled)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: destination.path + VerifiedCopy.partialSuffix))
    }

    /// Sans ça, tous les clips importés porteraient la date de l'import et le tri par date dans le
    /// Finder ne dirait plus rien.
    func testKeepsTheShootingDate() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let shot = Date(timeIntervalSince1970: 1_600_000_000)
        try FileManager.default.setAttributes([.modificationDate: shot], ofItemAtPath: source.path)

        let destination = directory.appendingPathComponent("out/GX010123.MP4")
        try VerifiedCopy.copy(from: source, to: destination)

        let copied = try destination.resourceValues(forKeys: [.contentModificationDateKey])
        XCTAssertEqual(copied.contentModificationDate?.timeIntervalSince1970 ?? 0,
                       shot.timeIntervalSince1970, accuracy: 2)
    }

    func testReportsProgressUpToTheFullSize() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory, bytes: 9_000_000)
        var reported: [UInt64] = []

        try VerifiedCopy.copy(from: source, to: directory.appendingPathComponent("out/c.MP4"),
                              progress: { reported.append($0) })

        XCTAssertEqual(reported.last, 9_000_000)
        XCTAssertEqual(reported, reported.sorted(), "la progression ne recule jamais")
        XCTAssertGreaterThan(reported.count, 1, "un fichier de 9 Mo passe par plusieurs blocs")
    }

    /// La vérification relit le fichier écrit : comparer la source à elle-même ne prouverait rien.
    func testChecksumOfTheWrittenFileMatchesTheSource() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let destination = directory.appendingPathComponent("out/c.MP4")

        let announced = try VerifiedCopy.copy(from: source, to: destination)
        XCTAssertEqual(announced, try VerifiedCopy.checksum(of: destination))
        XCTAssertEqual(announced, try VerifiedCopy.checksum(of: source))
    }

    func testAnOldPartialFileIsReplacedNotAppendedTo() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory)
        let destination = directory.appendingPathComponent("out/GX010123.MP4")
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(repeating: 0xFF, count: 5000)
            .write(to: URL(fileURLWithPath: destination.path + VerifiedCopy.partialSuffix))

        try VerifiedCopy.copy(from: source, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination), try Data(contentsOf: source))
    }

    func testCopiesAnEmptyFile() throws {
        let directory = try Fixtures.temporaryDirectory(self)
        let source = try makeSource(directory, bytes: 0)
        let destination = directory.appendingPathComponent("out/vide.MP4")

        try VerifiedCopy.copy(from: source, to: destination)
        XCTAssertEqual(try Data(contentsOf: destination).count, 0)
    }
}

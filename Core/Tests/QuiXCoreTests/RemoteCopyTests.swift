import XCTest
@testable import QuiXCore

/// Les deux chemins que la caméra impose : lire des morceaux, puis rapatrier le fichier entier.
final class RemoteCopyTests: XCTestCase {

    private var server: TinyHTTPServer!
    private var directory: URL!

    /// Un contenu assez gros pour traverser plusieurs blocs de réception.
    private let payload: [UInt8] = (0..<(600_000)).map { UInt8($0 % 251) }

    override func setUpWithError() throws {
        server = try TinyHTTPServer(payload: payload)
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quix-remote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        server.stop()
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Lecture par morceaux

    func testReadsAWindowInTheMiddle() throws {
        let reader = HTTPRangeByteReader(url: server.baseURL, length: UInt64(payload.count))
        let bytes = try reader.read(at: 1_000, count: 256)
        XCTAssertEqual(bytes, Array(payload[1_000..<1_256]))
    }

    /// Le cas qui compte vraiment : chez GoPro le `moov` ferme le fichier.
    func testReadsTheTailWhereTheMoovLives() throws {
        let reader = HTTPRangeByteReader(url: server.baseURL, length: UInt64(payload.count))
        let bytes = try reader.read(at: UInt64(payload.count - 4_096), count: 4_096)
        XCTAssertEqual(bytes.count, 4_096)
        XCTAssertEqual(bytes, Array(payload.suffix(4_096)))
    }

    func testClampsAReadThatWouldRunPastTheEnd() throws {
        let reader = HTTPRangeByteReader(url: server.baseURL, length: UInt64(payload.count))
        let bytes = try reader.read(at: UInt64(payload.count - 10), count: 4_096)
        XCTAssertEqual(bytes.count, 10)
    }

    func testReadsBeyondTheEndGiveNothing() throws {
        let reader = HTTPRangeByteReader(url: server.baseURL, length: UInt64(payload.count))
        XCTAssertEqual(try reader.read(at: UInt64(payload.count), count: 16), [])
    }

    /// Un serveur qui ignore `Range` renverrait le fichier entier à chaque atome consulté. On le
    /// signale plutôt que de le subir en silence.
    func testDetectsAServerThatIgnoresRange() throws {
        let deaf = try TinyHTTPServer(payload: payload, honoursRange: false)
        defer { deaf.stop() }
        let reader = HTTPRangeByteReader(url: deaf.baseURL, length: UInt64(payload.count))
        XCTAssertThrowsError(try reader.read(at: 0, count: 64)) { error in
            XCTAssertEqual(error as? HTTPRangeByteReader.RangeFailure, .ignored(status: 200))
        }
        XCTAssertFalse(HTTPRangeByteReader.supportsRange(url: deaf.baseURL))
    }

    func testRecognisesAServerThatHonoursRange() {
        XCTAssertTrue(HTTPRangeByteReader.supportsRange(url: server.baseURL))
    }

    // MARK: - Téléchargement vérifié

    func testDownloadsTheFileExactly() throws {
        let destination = directory.appendingPathComponent("GX010001.MP4")
        try RemoteVerifiedCopy.copy(from: server.baseURL,
                                    expectedSize: UInt64(payload.count),
                                    modified: nil,
                                    to: destination)
        XCTAssertEqual([UInt8](try Data(contentsOf: destination)), payload)
    }

    /// La régression qui a fait planter l'app après le premier clip importé.
    ///
    /// `URLSession` retient son délégué au-delà du retour de la copie. Si celui-ci garde des
    /// fermetures que l'appelant a déclarées non-échappantes, Swift arrête le programme — et
    /// l'import s'interrompait juste après le premier fichier. Ce test appelle donc la copie
    /// exactement comme `ImportRunner` le fait : avec des fermetures non-échappantes.
    func testAcceptsNonEscapingCallbacks() throws {
        let destination = directory.appendingPathComponent("GX010002.MP4")
        var seen: UInt64 = 0

        func run(isCancelled: () -> Bool, progress: (UInt64) -> Void) throws {
            try RemoteVerifiedCopy.copy(from: server.baseURL,
                                        expectedSize: UInt64(payload.count),
                                        modified: nil,
                                        to: destination,
                                        isCancelled: isCancelled,
                                        progress: progress)
        }

        try run(isCancelled: { false }, progress: { seen = $0 })
        XCTAssertEqual(seen, UInt64(payload.count))
    }

    func testRefusesToOverwriteAnExistingFile() throws {
        let destination = directory.appendingPathComponent("déjà.MP4")
        try Data([1, 2, 3]).write(to: destination)
        XCTAssertThrowsError(try RemoteVerifiedCopy.copy(
            from: server.baseURL, expectedSize: UInt64(payload.count),
            modified: nil, to: destination))
        XCTAssertEqual(try Data(contentsOf: destination).count, 3)
    }

    /// Un transfert coupé ne doit jamais laisser un `.MP4` d'apparence valide.
    func testAnnouncedSizeMismatchLeavesNothingBehind() throws {
        let destination = directory.appendingPathComponent("tronqué.MP4")
        XCTAssertThrowsError(try RemoteVerifiedCopy.copy(
            from: server.baseURL,
            expectedSize: UInt64(payload.count + 1),   // la caméra en annonçait un de plus
            modified: nil, to: destination)) { error in
            guard case CopyFailure.sizeMismatch = error else {
                return XCTFail("attendu sizeMismatch, obtenu \(error)")
            }
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: destination.path + VerifiedCopy.partialSuffix))
    }

    func testKeepsTheShootingDate() throws {
        let destination = directory.appendingPathComponent("daté.MP4")
        let shot = Date(timeIntervalSince1970: 1_700_000_000)
        try RemoteVerifiedCopy.copy(from: server.baseURL,
                                    expectedSize: UInt64(payload.count),
                                    modified: shot, to: destination)
        let written = try destination.resourceValues(forKeys: [.contentModificationDateKey])
        XCTAssertEqual(written.contentModificationDate?.timeIntervalSince1970 ?? 0,
                       shot.timeIntervalSince1970, accuracy: 2)
    }
}

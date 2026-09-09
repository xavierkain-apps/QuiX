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

/// La reprise d'un transfert coupé.
///
/// Un import USB pèse des gigaoctets et le câble se débranche : recommencer de zéro coûtait cher
/// alors que la caméra honore `Range`. Ce qui se teste ici n'est pas seulement « ça reprend », mais
/// que la reprise ne casse pas la chaîne de vérification.
final class ResumeTests: XCTestCase {

    private var directory: URL!
    private let payload: [UInt8] = (0..<400_000).map { UInt8($0 % 251) }

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("quix-resume-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func partial(_ destination: URL) -> URL {
        URL(fileURLWithPath: destination.path + VerifiedCopy.partialSuffix)
    }
    private func state(_ destination: URL) -> URL {
        URL(fileURLWithPath: partial(destination).path + RemoteVerifiedCopy.stateSuffix)
    }

    /// Coupure puis reprise : le fichier final doit être exactement le contenu servi.
    func testResumesWhereTheTransferStopped() throws {
        let destination = directory.appendingPathComponent("GX010001.MP4")

        let cut = try TinyHTTPServer(payload: payload, cutAfter: 150_000)
        XCTAssertThrowsError(try RemoteVerifiedCopy.copy(
            from: cut.baseURL, expectedSize: UInt64(payload.count),
            modified: nil, to: destination))
        cut.stop()

        // Les octets reçus sont gardés, et l'état note où l'on en était.
        XCTAssertTrue(FileManager.default.fileExists(atPath: partial(destination).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: state(destination).path))
        // Combien d'octets ont franchi le câble avant la coupure dépend du tampon réseau : ce qui
        // compte est qu'il en reste, et pas la totalité.
        let kept = ImportPlanner.sizeOnDisk(partial(destination)) ?? 0
        XCTAssertGreaterThan(kept, 0)
        XCTAssertLessThan(kept, UInt64(payload.count))

        let whole = try TinyHTTPServer(payload: payload)
        defer { whole.stop() }
        try RemoteVerifiedCopy.copy(from: whole.baseURL, expectedSize: UInt64(payload.count),
                                    modified: nil, to: destination)

        XCTAssertEqual([UInt8](try Data(contentsOf: destination)), payload)
        // Ni temporaire ni état ne survivent à une copie réussie.
        XCTAssertFalse(FileManager.default.fileExists(atPath: partial(destination).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: state(destination).path))
    }

    /// Le cas qui justifie le fichier d'état : un temporaire modifié depuis la coupure ne doit
    /// **jamais** être repris, sinon la vérification finale comparerait le disque à lui-même et
    /// laisserait passer un clip corrompu sans rien signaler.
    func testRefusesToResumeOnATamperedPartial() throws {
        let destination = directory.appendingPathComponent("GX010002.MP4")

        let cut = try TinyHTTPServer(payload: payload, cutAfter: 100_000)
        XCTAssertThrowsError(try RemoteVerifiedCopy.copy(
            from: cut.baseURL, expectedSize: UInt64(payload.count),
            modified: nil, to: destination))
        cut.stop()

        // On abîme un octet au milieu, sans toucher à la taille.
        var damaged = [UInt8](try Data(contentsOf: partial(destination)))
        try XCTSkipIf(damaged.isEmpty, "rien n'a été reçu avant la coupure")
        damaged[damaged.count / 2] ^= 0xFF
        try Data(damaged).write(to: partial(destination))

        XCTAssertNil(RemoteVerifiedCopy.resumePoint(
            temporary: partial(destination), state: state(destination),
            expectedSize: UInt64(payload.count), fileManager: .default))

        // Et la copie repart de zéro, donc rend le bon contenu malgré le temporaire abîmé.
        let whole = try TinyHTTPServer(payload: payload)
        defer { whole.stop() }
        try RemoteVerifiedCopy.copy(from: whole.baseURL, expectedSize: UInt64(payload.count),
                                    modified: nil, to: destination)
        XCTAssertEqual([UInt8](try Data(contentsOf: destination)), payload)
    }

    /// Un temporaire dont la taille ne correspond plus à l'état n'est pas repris non plus.
    func testRefusesToResumeOnASizeThatDoesNotMatchTheState() throws {
        let destination = directory.appendingPathComponent("GX010003.MP4")
        let cut = try TinyHTTPServer(payload: payload, cutAfter: 80_000)
        XCTAssertThrowsError(try RemoteVerifiedCopy.copy(
            from: cut.baseURL, expectedSize: UInt64(payload.count),
            modified: nil, to: destination))
        cut.stop()

        let received = [UInt8](try Data(contentsOf: partial(destination)))
        try XCTSkipIf(received.count < 2, "rien n'a été reçu avant la coupure")
        try Data(received.dropLast(received.count / 4)).write(to: partial(destination))

        XCTAssertNil(RemoteVerifiedCopy.resumePoint(
            temporary: partial(destination), state: state(destination),
            expectedSize: UInt64(payload.count), fileManager: .default))
    }

    /// Sans fichier d'état, on ne devine pas : on repart de zéro.
    func testDoesNotResumeWithoutState() throws {
        let destination = directory.appendingPathComponent("GX010004.MP4")
        try Data(Array(payload.prefix(1_000))).write(to: partial(destination))
        XCTAssertNil(RemoteVerifiedCopy.resumePoint(
            temporary: partial(destination), state: state(destination),
            expectedSize: UInt64(payload.count), fileManager: .default))
    }

    /// Ce que voit vraiment l'utilisateur : deux coupures d'affilée, puis ça passe — sans qu'il
    /// ait rien à refaire. C'est le scénario qui laissait un clip manquant et obligeait à relancer
    /// un second import.
    func testRetriesCarryTheTransferThroughRepeatedCuts() throws {
        let destination = directory.appendingPathComponent("GX010006.MP4")
        let flaky = try TinyHTTPServer(payload: payload, cutAfter: 90_000, cutCount: 2)
        defer { flaky.stop() }

        let plan = ImportPlan(
            importFolder: directory,
            copies: [PlannedCopy(
                source: MediaFile(url: flaky.baseURL, folder: "100GOPRO",
                                  name: GoProFileName("GX010006.MP4")!,
                                  size: UInt64(payload.count),
                                  modified: Date(timeIntervalSince1970: 1_700_000_000)),
                destination: destination,
                relativeDestination: "Clips/GX010006.MP4",
                takeNumber: 6, isHighlighted: false)],
            alreadyImported: [])

        var index = ImportIndex()
        let report = ImportRunner.run(plan, library: directory, index: &index)

        XCTAssertEqual(report.failures.count, 0)
        XCTAssertEqual(report.copied.count, 1)
        XCTAssertEqual([UInt8](try Data(contentsOf: destination)), payload)
    }

    /// Une reprise demandée à un serveur qui ignore `Range` ne doit pas coller le fichier entier
    /// derrière ce qu'on avait déjà.
    func testAServerThatIgnoresRangeStartsOver() throws {
        let destination = directory.appendingPathComponent("GX010005.MP4")

        let cut = try TinyHTTPServer(payload: payload, cutAfter: 120_000)
        XCTAssertThrowsError(try RemoteVerifiedCopy.copy(
            from: cut.baseURL, expectedSize: UInt64(payload.count),
            modified: nil, to: destination))
        cut.stop()

        let deaf = try TinyHTTPServer(payload: payload, honoursRange: false)
        defer { deaf.stop() }
        try RemoteVerifiedCopy.copy(from: deaf.baseURL, expectedSize: UInt64(payload.count),
                                    modified: nil, to: destination)
        XCTAssertEqual([UInt8](try Data(contentsOf: destination)), payload)
    }
}

import XCTest
@testable import QuiXCore

final class CRC32Tests: XCTestCase {

    /// Le vecteur de référence du CRC-32 IEEE : « 123456789 » vaut 0xCBF43926.
    func testKnownVector() {
        var crc = CRC32()
        crc.update(Data("123456789".utf8))
        XCTAssertEqual(crc.value, 0xCBF4_3926)
    }

    func testEmptyInputIsZero() {
        XCTAssertEqual(CRC32().value, 0)
    }

    /// Le calcul se fait bloc par bloc pendant la copie : découper l'entrée ne doit rien changer.
    func testChunkingDoesNotChangeTheResult() {
        let payload = Data((0..<10_000).map { UInt8($0 % 251) })

        var whole = CRC32()
        whole.update(payload)

        var chunked = CRC32()
        var offset = 0
        while offset < payload.count {
            let end = min(offset + 997, payload.count)
            chunked.update(payload.subdata(in: offset..<end))
            offset = end
        }

        XCTAssertEqual(whole.value, chunked.value)
    }

    /// Un octet qui change doit se voir — c'est toute la raison d'être de la vérification.
    func testASingleFlippedByteChangesTheChecksum() {
        var original = Data(repeating: 7, count: 4096)
        var first = CRC32(); first.update(original)
        original[2048] = 8
        var second = CRC32(); second.update(original)
        XCTAssertNotEqual(first.value, second.value)
    }
}

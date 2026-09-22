import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Random-access reading of a remote file, through HTTP `Range` requests.
///
/// This is the piece that saves the app's principle over the USB cable. On a card, `FileByteReader`
/// reaches the `moov` at the end of the file with three seeks; here, three `Range` requests do the
/// same work on the camera. The clip is not pulled down to be sorted — about 34 KB are read and we
/// know where it goes, exactly as on a card.
///
/// If the camera ignored `Range` and returned the whole file, this reader would detect it instead
/// of quietly downloading 90 MB: see `RangeFailure.ignored`.
public final class HTTPRangeByteReader: ByteReader {

    public let url: URL
    public let length: UInt64
    private let timeout: TimeInterval

    public enum RangeFailure: Error, Equatable {
        /// The server answered 200 instead of 206: it ignores `Range` and would return the whole
        /// file. Reading that way would cost the entire clip per atom consulted.
        case ignored(status: Int)
        case badStatus(Int)
        case noLength
    }

    /// - Parameter length: the file's size, already known from the camera's catalogue. That avoids
    ///   one `HEAD` request per clip.
    public init(url: URL, length: UInt64, timeout: TimeInterval = 30) {
        self.url = url
        self.length = length
        self.timeout = timeout
    }

    public func read(at offset: UInt64, count: Int) throws -> [UInt8] {
        guard count > 0, offset < length else { return [] }
        let last = min(offset + UInt64(count) - 1, length - 1)

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("bytes=\(offset)-\(last)", forHTTPHeaderField: "Range")

        let (data, response) = try HTTP.send(request)
        guard let http = response as? HTTPURLResponse else { throw RangeFailure.noLength }

        switch http.statusCode {
        case 206:
            return [UInt8](data)
        case 200:
            // The server sent everything. We do not use it: accepting here would amount to
            // downloading the whole clip for every atom consulted, with nothing to signal it.
            throw RangeFailure.ignored(status: 200)
        default:
            throw RangeFailure.badStatus(http.statusCode)
        }
    }

    /// Checks in one request that the server really honours `Range`.
    ///
    /// To be called once per session, before scanning: better to know straight away than to
    /// discover the problem at the sixtieth clip.
    public static func supportsRange(url: URL, timeout: TimeInterval = 15) -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("bytes=0-63", forHTTPHeaderField: "Range")
        guard let (_, response) = try? HTTP.send(request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 206
    }
}

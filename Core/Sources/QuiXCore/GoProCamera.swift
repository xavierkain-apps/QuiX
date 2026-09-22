import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// The camera plugged in over USB-C, seen as an HTTP server.
///
/// This is the road Quik took, and the only one the HERO12 offers over the cable: it exposes
/// **no** mass-storage interface at all. It brings up a network (CDC NCM) and answers on
/// `http://172.2X.1YZ.51:8080` — the "Open GoPro" API. The MTP interface visible beside it
/// publishes only two service files; it gives no access to the clips.
///
/// The decisive point is that this server speaks HTTP: if it honours the `Range` header, the
/// ~34 KB of `moov` can be read without pulling the clip down, and sorting stays free exactly as
/// on a card. See `HTTPRangeByteReader`.
public struct GoProCamera: Sendable, Equatable {

    public let host: String
    public let port: Int

    public init(host: String, port: Int = 8080) {
        self.host = host
        self.port = port
    }

    public var baseURL: URL { URL(string: "http://\(host):\(port)")! }

    public struct Info: Decodable, Sendable, Equatable {
        public let modelName: String
        public let serialNumber: String
        public let firmwareVersion: String

        enum CodingKeys: String, CodingKey {
            case modelName = "model_name"
            case serialNumber = "serial_number"
            case firmwareVersion = "firmware_version"
        }
    }

    public enum CameraError: Error, Equatable {
        case notFound
        case badStatus(Int)
        case malformedResponse
        /// The camera answers but refuses partial reads. Sorting without copying is then
        /// impossible: an architectural decision, not a detail. See `HTTPRangeByteReader`.
        case rangeUnsupported
    }

    // MARK: - Discovery

    /// Looks for a camera on the USB networks the machine has brought up.
    ///
    /// The address is not guessable in the absolute: GoPro derives it from the serial number,
    /// which gives `172.2X.1YZ.51`. Rather than reproduce that calculation — which would require
    /// knowing the serial *before* talking to the camera — we start from the local interfaces: the
    /// machine gets an address in the same `/24`, and the camera always sits at `.51`.
    public static func discover(timeout: TimeInterval = 2) -> GoProCamera? {
        for candidate in candidateHosts() {
            let camera = GoProCamera(host: candidate)
            if (try? camera.info(timeout: timeout)) != nil { return camera }
        }
        return nil
    }

    /// The `.51` addresses of the `172.x.y.0/24` subnets where the machine has an address.
    public static func candidateHosts() -> [String] {
        var hosts: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }

            // `sa_len` is a BSD field: Linux does not have it, and the size is derived there from
            // the address family. We have already filtered on `AF_INET` just above.
            #if canImport(Darwin)
            let addressLength = socklen_t(address.pointee.sa_len)
            #else
            let addressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            #endif

            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, addressLength,
                              &buffer, socklen_t(buffer.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }

            let ip = String(cString: buffer)
            let parts = ip.split(separator: ".")
            // The camera's USB network is in 172.2x.1yz.0/24; nothing else is swept.
            guard parts.count == 4, parts[0] == "172", let second = Int(parts[1]),
                  (20...29).contains(second) else { continue }

            let candidate = "\(parts[0]).\(parts[1]).\(parts[2]).51"
            if candidate != ip, !hosts.contains(candidate) { hosts.append(candidate) }
        }
        return hosts
    }

    // MARK: - API

    public func info(timeout: TimeInterval = 5) throws -> Info {
        let data = try get(path: "/gopro/camera/info", timeout: timeout)
        guard let info = try? JSONDecoder().decode(Info.self, from: data) else {
            throw CameraError.malformedResponse
        }
        return info
    }

    /// Switches the camera to wired control.
    ///
    /// Without this call, the camera may cut the HTTP session after a few seconds to return to its
    /// default mode. It is sent before any scan, and its failure is ignored: on firmwares where
    /// the call does not exist, everything else works anyway.
    public func enableWiredControl() {
        _ = try? get(path: "/gopro/camera/control/wired_usb?p=1", timeout: 5)
    }

    /// The files present on the card, as the camera declares them.
    public func mediaList(timeout: TimeInterval = 30) throws -> [CameraMediaFile] {
        let data = try get(path: "/gopro/media/list", timeout: timeout)
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let media = root["media"] as? [[String: Any]] else {
            throw CameraError.malformedResponse
        }

        var files: [CameraMediaFile] = []
        for directory in media {
            guard let folder = directory["d"] as? String,
                  let entries = directory["fs"] as? [[String: Any]] else { continue }
            for entry in entries {
                guard let name = entry["n"] as? String else { continue }
                files.append(CameraMediaFile(
                    folder: folder,
                    filename: name,
                    size: UInt64(anyString(entry["s"]) ?? "") ?? 0,
                    created: Date(timeIntervalSince1970: TimeInterval(anyString(entry["cre"]) ?? "") ?? 0),
                    url: mediaURL(folder: folder, filename: name)
                ))
            }
        }
        return files.sorted { ($0.folder, $0.filename) < ($1.folder, $1.filename) }
    }

    /// Erases one file from the card, through the camera.
    ///
    /// The only call in all of QuiX that destroys anything. It is never sent by a detection or by
    /// the end of an import: only from `CameraCleanup.erase`, which requires every file's copy to
    /// have been proven present on the Mac beforehand.
    public func delete(folder: String, filename: String, timeout: TimeInterval = 20) throws {
        _ = try get(path: "/gopro/media/delete/file?path=\(folder)/\(filename)", timeout: timeout)
    }

    /// The download URL of a file on the card.
    public func mediaURL(folder: String, filename: String) -> URL {
        baseURL.appendingPathComponent("videos/DCIM/\(folder)/\(filename)")
    }

    /// The API returns numbers sometimes as strings, sometimes as numbers, depending on firmware.
    private func anyString(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    // MARK: - HTTP

    func get(path: String, timeout: TimeInterval) throws -> Data {
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw CameraError.malformedResponse
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try HTTP.send(request)
        guard let http = response as? HTTPURLResponse else { throw CameraError.malformedResponse }
        guard (200...299).contains(http.statusCode) else { throw CameraError.badStatus(http.statusCode) }
        return data
    }
}

/// A file as the camera declares it in `/gopro/media/list`.
public struct CameraMediaFile: Equatable, Sendable {
    public let folder: String
    public let filename: String
    public let size: UInt64
    public let created: Date
    public let url: URL
}

/// A synchronous HTTP request.
///
/// The engine already scans on a background thread, and every `ByteReader` is synchronous by
/// contract: making the chain asynchronous all the way here would mean rewriting the atom parser,
/// which has no reason to know where its bytes come from.
enum HTTP {

    /// One connection at a time towards the camera.
    ///
    /// Its server holds only one. With `URLSession.shared`, scanning left an idle but open
    /// connection behind it, and the first download that followed asked for a second — which the
    /// camera refused. The symptom was disorienting: the first clip failed, the following ones went
    /// through, and a second import always succeeded.
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 1
        // Absent from Linux's Foundation, where the property is read-only. The camera is at the end
        // of a cable: waiting for connectivity that will not come makes no sense.
        #if canImport(Darwin)
        configuration.waitsForConnectivity = false
        #endif
        return URLSession(configuration: configuration)
    }()

    /// The same constraint, for the delegate-based download sessions.
    static func downloadConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.httpMaximumConnectionsPerHost = 1
        #if canImport(Darwin)
        configuration.waitsForConnectivity = false
        #endif
        return configuration
    }

    /// The result travels through a reference, never through a captured variable.
    ///
    /// `URLSession`'s closure runs on another thread: mutating a local variable from there is
    /// refused by the compiler under strict concurrency. The write and the read are separated by
    /// the semaphore, which establishes the order between them.
    private final class Outcome: @unchecked Sendable {
        var result: Result<(Data, URLResponse?), Error> = .failure(GoProCamera.CameraError.notFound)
    }

    static func send(_ request: URLRequest) throws -> (Data, URLResponse?) {
        let semaphore = DispatchSemaphore(value: 0)
        let outcome = Outcome()

        let task = session.dataTask(with: request) { data, response, error in
            if let error {
                outcome.result = .failure(error)
            } else {
                outcome.result = .success((data ?? Data(), response))
            }
            semaphore.signal()
        }
        task.resume()

        if semaphore.wait(timeout: .now() + request.timeoutInterval + 5) == .timedOut {
            task.cancel()
            throw GoProCamera.CameraError.notFound
        }
        return try outcome.result.get()
    }
}

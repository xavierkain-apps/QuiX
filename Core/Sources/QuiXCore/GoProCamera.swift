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
        if case .found(let camera, _) = probe(timeout: timeout) { return camera }
        return nil
    }

    /// What a search of the USB networks concluded.
    public enum Probe {
        /// A camera answered.
        case found(GoProCamera, Info)
        /// A camera network exists and macOS forbids talking to it — the "Local Network"
        /// permission. The only outcome that asks the user for something.
        case denied
        /// No camera network, or nothing answering on one. `reason` is kept for the log: a
        /// camera that is plugged in and silent is the hardest thing to diagnose afterwards,
        /// and "no card" on screen says nothing about why.
        case absent(reason: String?)
    }

    /// Looks for a camera, **probing every candidate at once**.
    ///
    /// Sequentially was a mistake. A personal hotspot opens a `172.20.10.0/28` network, nothing
    /// answers at `.51`, and every poll spent the whole timeout there before so much as trying
    /// the camera. The narrower filter in `candidateHosts()` rules that case out, but any other
    /// stray subnet would cost the same — so the candidates are raced instead of queued.
    public static func probe(timeout: TimeInterval = 2) -> Probe {
        let hosts = candidateHosts()
        guard !hosts.isEmpty else { return .absent(reason: nil) }

        let outcomes = Outcomes()
        let group = DispatchGroup()
        let queue = DispatchQueue(label: "quix.probe", attributes: .concurrent)

        for host in hosts {
            group.enter()
            queue.async {
                defer { group.leave() }
                let camera = GoProCamera(host: host)
                do { outcomes.found(camera, try camera.info(timeout: timeout)) }
                catch { outcomes.failed(host, error) }
            }
        }
        group.wait()
        return outcomes.verdict()
    }

    /// Collects what the parallel probes found. A class, because several queues write to it.
    private final class Outcomes: @unchecked Sendable {
        private let lock = NSLock()
        private var success: (GoProCamera, Info)?
        private var denied = false
        private var reasons: [String] = []

        func found(_ camera: GoProCamera, _ info: Info) {
            lock.lock(); defer { lock.unlock() }
            if success == nil { success = (camera, info) }
        }

        func failed(_ host: String, _ error: Error) {
            lock.lock(); defer { lock.unlock() }
            if LocalNetworkDenial.matches(error) { denied = true }
            reasons.append("\(host): \(LocalNetworkDenial.summary(of: error))")
        }

        func verdict() -> Probe {
            lock.lock(); defer { lock.unlock() }
            if let success { return .found(success.0, success.1) }
            if denied { return .denied }
            return .absent(reason: reasons.isEmpty ? nil : reasons.joined(separator: " · "))
        }
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
            // The camera's USB network is `172.2X.1YZ.0/24` — the third octet always has three
            // digits and starts with a 1, so 100 through 199. Checking it is not pedantry: an
            // iPhone personal hotspot hands out `172.20.10.x`, which passes the first two octets
            // and costs a full timeout on every single poll.
            guard parts.count == 4, parts[0] == "172",
                  let second = Int(parts[1]), (20...29).contains(second),
                  let third = Int(parts[2]), (100...199).contains(third) else { continue }

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
        let request = HTTP.request(url, timeout: timeout)
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
    /// A request the camera's server will not keep alive.
    ///
    /// **This is not a detail.** The camera closes a connection after a couple of seconds of
    /// silence, but `URLSession` keeps it in its pool and reuses it on the next request. The
    /// socket is already gone, so the task fails instantly with `-1005`, "network connection
    /// lost" — on a path macOS reports as *satisfied*, which rules out the permission and leaves
    /// nothing else to look at.
    ///
    /// The symptom is brutal: `curl` to the very same address answers in 30 ms, because it opens
    /// a fresh connection every time, while QuiX fails on every poll and reports "no card" for a
    /// camera that is plugged in, switched on, and holding fifty clips.
    ///
    /// `Connection: close` costs one TCP handshake per request. Over a USB cable that is nothing,
    /// and this server would have closed the connection anyway.
    static func request(_ url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("close", forHTTPHeaderField: "Connection")
        // The camera's answers are never worth caching: `media/list` changes with every clip
        // filmed, and a stale catalogue would mean a missed import.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

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

/// Telling a refused "Local Network" permission apart from a camera that is simply not there.
///
/// macOS does not give this its own error code, and the code it does give **has changed**. It was
/// `-1009`, "the Internet connection appears to be offline", which says nothing true: neither the
/// Internet nor an outage is involved. On macOS 26 the same refusal arrives as `-1005`, "network
/// connection lost", after the connection has been allowed to start and then torn down.
///
/// Matching on the code was therefore wrong in a way that only showed much later: the app
/// reported "no card" for a camera that was plugged in, switched on, and answering `curl` — the
/// exact failure the permission screen exists to prevent.
///
/// What does not change is the path attached to the error. It names the reason in clear text,
/// under a key Apple does not publish, which is why the code is read as a fallback rather than
/// trusted alone.
public enum LocalNetworkDenial {

    public static func matches(_ error: Error) -> Bool {
        let error = error as NSError
        guard error.domain == NSURLErrorDomain else { return false }
        if path(in: error)?.localizedCaseInsensitiveContains("local network") == true { return true }
        // No path to read: `-1009` on a USB camera subnet can hardly mean anything else.
        return error.code == NSURLErrorNotConnectedToInternet
    }

    /// One readable line for the log. Never shown to the user — the window says what to do, not
    /// what the socket said.
    public static func summary(of error: Error) -> String {
        let error = error as NSError
        if let path = path(in: error) { return "\(error.code) — \(path)" }
        return "\(error.code)"
    }

    /// The network path macOS attached to the failure, wherever it buried it.
    private static func path(in error: NSError) -> String? {
        for candidate in [error] + (error.userInfo[NSUnderlyingErrorKey] as? NSError).map({ [$0] }).orEmpty {
            if let path = candidate.userInfo["_NSURLErrorNWPathKey"] {
                return String(describing: path)
            }
        }
        return nil
    }
}

private extension Optional where Wrapped == [NSError] {
    var orEmpty: [NSError] { self ?? [] }
}

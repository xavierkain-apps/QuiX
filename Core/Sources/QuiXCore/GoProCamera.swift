import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// La caméra branchée en USB-C, vue comme un serveur HTTP.
///
/// C'est le chemin que prenait Quik, et le seul que la HERO12 offre par le câble : elle n'expose
/// **aucune** interface de stockage de masse. Elle monte un réseau (CDC NCM) et répond sur
/// `http://172.2X.1YZ.51:8080` — l'API « Open GoPro ». Le MTP visible à côté ne publie, lui, que
/// deux fichiers de service ; il ne donne pas accès aux clips.
///
/// L'intérêt décisif est que ce serveur parle HTTP : s'il honore l'en-tête `Range`, on lit les
/// ~34 Ko du `moov` sans rapatrier le clip, et le tri reste gratuit exactement comme sur une carte.
/// Voir `HTTPRangeByteReader`.
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
        /// La caméra répond mais refuse les lectures partielles. Le tri sans copie est alors
        /// impossible : c'est une décision d'architecture, pas un détail. Voir `HTTPRangeByteReader`.
        case rangeUnsupported
    }

    // MARK: - Découverte

    /// Cherche une caméra sur les réseaux USB montés par la machine.
    ///
    /// L'adresse n'est pas devinable dans l'absolu : GoPro la dérive du numéro de série, ce qui
    /// donne `172.2X.1YZ.51`. Plutôt que de reproduire ce calcul — qui demanderait de connaître le
    /// série *avant* de parler à la caméra — on part des interfaces locales : la machine reçoit une
    /// adresse dans le même `/24`, et la caméra y occupe toujours `.51`.
    public static func discover(timeout: TimeInterval = 2) -> GoProCamera? {
        for candidate in candidateHosts() {
            let camera = GoProCamera(host: candidate)
            if (try? camera.info(timeout: timeout)) != nil { return camera }
        }
        return nil
    }

    /// Les `.51` des sous-réseaux `172.x.y.0/24` où la machine a une adresse.
    public static func candidateHosts() -> [String] {
        var hosts: [String] = []
        var pointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&pointer) == 0, let first = pointer else { return [] }
        defer { freeifaddrs(pointer) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            guard let address = interface.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }

            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len),
                              &buffer, socklen_t(buffer.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }

            let ip = String(cString: buffer)
            let parts = ip.split(separator: ".")
            // Le réseau USB de la caméra est en 172.2x.1yz.0/24 ; on ne balaie rien d'autre.
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

    /// Bascule la caméra en contrôle filaire.
    ///
    /// Sans cet appel, la caméra peut couper la session HTTP au bout de quelques secondes pour
    /// revenir à son mode par défaut. On l'émet avant tout scan, et on ignore son échec : sur les
    /// firmwares où l'appel n'existe pas, le reste fonctionne quand même.
    public func enableWiredControl() {
        _ = try? get(path: "/gopro/camera/control/wired_usb?p=1", timeout: 5)
    }

    /// Les fichiers présents sur la carte, tels que la caméra les déclare.
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

    /// L'URL de téléchargement d'un fichier de la carte.
    public func mediaURL(folder: String, filename: String) -> URL {
        baseURL.appendingPathComponent("videos/DCIM/\(folder)/\(filename)")
    }

    /// L'API renvoie les nombres tantôt en chaîne, tantôt en nombre selon le firmware.
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

/// Un fichier tel que la caméra le déclare dans `/gopro/media/list`.
public struct CameraMediaFile: Equatable, Sendable {
    public let folder: String
    public let filename: String
    public let size: UInt64
    public let created: Date
    public let url: URL
}

/// Requête HTTP synchrone.
///
/// Le moteur scanne déjà sur un fil de fond, et tout `ByteReader` est synchrone par contrat :
/// rendre la chaîne asynchrone jusqu'ici obligerait à réécrire le parseur d'atomes, qui n'a aucune
/// raison de savoir d'où viennent ses octets.
enum HTTP {
    static func send(_ request: URLRequest) throws -> (Data, URLResponse?) {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<(Data, URLResponse?), Error> = .failure(GoProCamera.CameraError.notFound)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                result = .failure(error)
            } else {
                result = .success((data ?? Data(), response))
            }
            semaphore.signal()
        }
        task.resume()

        if semaphore.wait(timeout: .now() + request.timeoutInterval + 5) == .timedOut {
            task.cancel()
            throw GoProCamera.CameraError.notFound
        }
        return try result.get()
    }
}

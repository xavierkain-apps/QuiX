import Foundation
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

/// Un serveur HTTP minimal, le temps d'un test.
///
/// Il existe parce que les deux chemins réseau de QuiX — la lecture `Range` et le téléchargement
/// vérifié — ne se testaient pas du tout, et qu'un bug de cycle de vie y a fait planter l'app en
/// production alors que les 85 tests passaient. Un vrai socket est le seul moyen d'exercer
/// `URLSession` telle qu'elle se comporte vraiment, y compris la libération asynchrone de son
/// délégué qui est précisément ce qui avait explosé.
final class TinyHTTPServer: @unchecked Sendable {

    private var listener: Int32 = -1
    private var thread: Thread?
    private let payload: [UInt8]
    /// Pour éprouver une caméra qui ignorerait `Range` et renverrait tout.
    private let honoursRange: Bool
    /// Nombre d'octets servis avant de raccrocher, pour simuler un câble débranché.
    private let cutAfter: Int?
    /// Combien de requêtes coupent avant que le serveur ne se comporte normalement.
    private let cutCount: Int
    private let counter = NSLock()
    private var served = 0

    private(set) var port: UInt16 = 0

    init(payload: [UInt8], honoursRange: Bool = true,
         cutAfter: Int? = nil, cutCount: Int = .max) throws {
        self.payload = payload
        self.honoursRange = honoursRange
        self.cutAfter = cutAfter
        self.cutCount = cutCount
        try open()
    }

    var baseURL: URL { URL(string: "http://127.0.0.1:\(port)/clip.mp4")! }

    private func open() throws {
        // `SOCK_STREAM` est un `Int32` sur Darwin et une énumération C sur Linux.
        #if canImport(Darwin)
        let streamType = SOCK_STREAM
        #else
        let streamType = Int32(SOCK_STREAM.rawValue)
        #endif
        listener = socket(AF_INET, streamType, 0)
        guard listener >= 0 else { throw Failure.socket }

        var yes: Int32 = 1
        setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0                      // le noyau choisit un port libre
        address.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listener, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0, listen(listener, 8) == 0 else { throw Failure.bind }

        var actual = sockaddr_in()
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(listener, $0, &size) }
        }
        port = UInt16(bigEndian: actual.sin_port)

        let thread = Thread { [weak self] in self?.serve() }
        thread.start()
        self.thread = thread
    }

    func stop() {
        if listener >= 0 { close(listener); listener = -1 }
    }

    deinit { stop() }

    private func serve() {
        while listener >= 0 {
            let client = accept(listener, nil, nil)
            guard client >= 0 else { return }

            // Une connexion par fil. En série, une connexion ouverte sans requête — libcurl en
            // garde en réserve, et la Foundation de Linux s'appuie dessus — bloquait `recv` et
            // empêchait d'accepter la suivante : le client attendait une réponse que le serveur
            // ne pouvait plus servir, et la suite de tests se figeait sans rien dire.
            Thread { [weak self] in
                self?.handle(client)
                close(client)
            }.start()
        }
    }

    private func handle(_ client: Int32) {
        // Et une connexion muette ne doit pas retenir son fil indéfiniment.
        var patience = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &patience,
                   socklen_t(MemoryLayout<timeval>.size))

        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(client, &buffer, buffer.count, 0)
        guard count > 0 else { return }
        let request = String(decoding: buffer[0..<count], as: UTF8.self)

        var start = 0
        var end = payload.count - 1
        var partial = false

        if honoursRange, let header = request
            .split(separator: "\r\n")
            .first(where: { $0.lowercased().hasPrefix("range:") }) {
            let spec = header.split(separator: "=").last.map(String.init) ?? ""
            let bounds = spec.split(separator: "-", omittingEmptySubsequences: false)
            if let low = Int(bounds.first ?? "") {
                start = low
                if bounds.count > 1, let high = Int(bounds[1]) { end = min(high, payload.count - 1) }
                partial = true
            }
        }

        guard start <= end, start < payload.count else { return }
        let body = Array(payload[start...end])

        var head = partial
            ? "HTTP/1.1 206 Partial Content\r\n"
            : "HTTP/1.1 200 OK\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Accept-Ranges: bytes\r\n"
        if partial { head += "Content-Range: bytes \(start)-\(end)/\(payload.count)\r\n" }
        head += "Connection: close\r\n\r\n"

        // Le corps annoncé reste celui du fichier complet : c'est bien une coupure en cours de
        // route, pas une réponse courte et honnête.
        counter.lock()
        let cutting = served < cutCount
        served += 1
        counter.unlock()
        let sent = (cutting ? cutAfter.map { Array(body.prefix($0)) } : nil) ?? body

        var out = [UInt8](head.utf8)
        out.append(contentsOf: sent)
        out.withUnsafeBufferPointer { _ = send(client, $0.baseAddress, $0.count, 0) }
    }

    enum Failure: Error { case socket, bind }
}

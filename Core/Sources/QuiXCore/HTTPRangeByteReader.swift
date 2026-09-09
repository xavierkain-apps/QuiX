import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Lecture aléatoire d'un fichier distant, par requêtes HTTP `Range`.
///
/// C'est la pièce qui sauve le principe de l'app par le câble USB. Sur une carte, `FileByteReader`
/// atteint le `moov` de fin de fichier par trois `seek` ; ici, trois requêtes `Range` font le même
/// travail sur la caméra. Le clip n'est pas rapatrié pour être trié — on lit ~34 Ko et on sait où
/// il va, exactement comme sur une carte.
///
/// Si la caméra ignorait `Range` et renvoyait le fichier entier, ce lecteur le détecterait au lieu
/// de télécharger 90 Mo en silence : voir `RangeFailure.ignored`.
public final class HTTPRangeByteReader: ByteReader {

    public let url: URL
    public let length: UInt64
    private let timeout: TimeInterval

    public enum RangeFailure: Error, Equatable {
        /// Le serveur a répondu 200 au lieu de 206 : il ignore `Range` et renverrait tout le
        /// fichier. Lire ainsi coûterait le clip entier par atome consulté.
        case ignored(status: Int)
        case badStatus(Int)
        case noLength
    }

    /// - Parameter length: taille du fichier, déjà connue par le catalogue de la caméra. On évite
    ///   ainsi une requête `HEAD` par clip.
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
            // Le serveur a tout envoyé. On ne s'en sert pas : accepter ici reviendrait à
            // télécharger le clip entier à chaque atome consulté, sans que rien ne le signale.
            throw RangeFailure.ignored(status: 200)
        default:
            throw RangeFailure.badStatus(http.statusCode)
        }
    }

    /// Vérifie en une requête que le serveur honore bien `Range`.
    ///
    /// À appeler une fois par session, avant de scanner : mieux vaut savoir tout de suite que
    /// découvrir le problème au soixantième clip.
    public static func supportsRange(url: URL, timeout: TimeInterval = 15) -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("bytes=0-63", forHTTPHeaderField: "Range")
        guard let (_, response) = try? HTTP.send(request),
              let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 206
    }
}

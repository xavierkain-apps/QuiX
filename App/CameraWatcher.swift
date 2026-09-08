import Foundation
import QuiXCore

/// Surveille la GoPro branchée en USB-C.
///
/// Il n'y a rien à « monter » ici : la caméra n'expose aucun stockage de masse, elle monte un
/// réseau et répond en HTTP. On ne peut donc pas s'abonner à une notification comme pour un volume
/// — on interroge, à intervalle régulier et à faible coût, les sous-réseaux que la machine a
/// ouverts. Tant qu'aucune caméra n'est branchée, aucune requête n'est émise du tout :
/// `candidateHosts()` ne renvoie rien.
@MainActor
final class CameraWatcher {

    /// Ce que la dernière tentative a appris.
    enum State: Equatable {
        /// Aucun réseau caméra sur la machine : rien n'est branché.
        case absent
        /// Un réseau caméra existe, mais macOS interdit à QuiX de s'y adresser.
        /// C'est la permission « Réseau local », et c'est le seul état qui demande une action.
        case denied
        /// La caméra répond.
        case connected(GoProCamera, GoProCamera.Info)
    }

    private(set) var state: State = .absent
    private var timer: Timer?
    private let onChange: (State) -> Void

    /// - Parameter interval: la caméra ne se branche pas souvent ; sonder plus vite ne servirait
    ///   qu'à réveiller la machine pour rien.
    init(interval: TimeInterval = 3, onChange: @escaping (State) -> Void) {
        self.onChange = onChange
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            MainActor.assumeIsolated { self.poll() }
        }
        poll()
    }

    deinit { timer?.invalidate() }

    func poll() {
        let hosts = GoProCamera.candidateHosts()
        guard !hosts.isEmpty else {
            update(.absent)
            return
        }

        Task.detached(priority: .utility) {
            var next: State = .absent
            for host in hosts {
                let camera = GoProCamera(host: host)
                do {
                    let info = try camera.info(timeout: 3)
                    next = .connected(camera, info)
                    break
                } catch let error as NSError where LocalNetwork.isPermissionDenial(error) {
                    // Un réseau caméra existe et QuiX n'a pas le droit de lui parler : c'est une
                    // caméra branchée, pas une caméra absente. Les deux ne se disent pas pareil à
                    // l'utilisateur.
                    next = .denied
                } catch {
                    continue
                }
            }
            await MainActor.run { self.update(next) }
        }
    }

    private func update(_ new: State) {
        guard new != state else { return }
        state = new
        onChange(new)
    }
}

/// Reconnaissance du refus de la permission « Réseau local ».
///
/// macOS ne la distingue pas d'une panne réseau dans le code d'erreur : il rend `-1009`, « la
/// connexion Internet semble hors service ». La seule marque du refus est dans le `userInfo`, sous
/// une clé non publiée. On la lit sans s'y fier aveuglément — d'où le repli sur le code seul, qui
/// pour une adresse 172.2x en USB ne peut de toute façon signifier qu'une chose.
enum LocalNetwork {
    static func isPermissionDenial(_ error: NSError) -> Bool {
        guard error.domain == NSURLErrorDomain, error.code == NSURLErrorNotConnectedToInternet
        else { return false }
        return true
    }

    /// Ouvre le panneau « Réseau local » des Réglages Système.
    static var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")!
    }
}

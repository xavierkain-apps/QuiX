import Foundation
import OSLog
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
        /// Un réseau caméra existe, macOS laisse passer, et pourtant rien ne répond.
        ///
        /// Cet état a coûté une soirée. L'app disait « aucune carte » pour une caméra branchée,
        /// allumée, qui répondait à `curl` en trente millisecondes — c'était un filtre réseau
        /// tiers qui coupait les connexions de QuiX, et rien à l'écran ne pouvait le laisser
        /// deviner. Une caméra qu'on voit et qu'on n'atteint pas n'est pas une caméra absente.
        case unreachable(String)
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
        guard !GoProCamera.candidateHosts().isEmpty else {
            update(.absent)
            return
        }

        Task.detached(priority: .utility) {
            let next: State
            switch GoProCamera.probe(timeout: 3) {
            case .found(let camera, let info):
                next = .connected(camera, info)
            case .denied:
                // A camera network exists and QuiX is not allowed to talk to it: that is a camera
                // plugged in, not a camera absent. The two do not read the same to the user.
                next = .denied
            case .absent(let reason):
                // A camera that is plugged in, switched on, and silent is the hardest thing to
                // diagnose after the fact. "No card" on screen says nothing about why; this line
                // does, and it costs nothing when there is nothing to say.
                if let reason {
                    Log.camera.info("no camera answered — \(reason, privacy: .public)")
                    next = .unreachable(reason)
                } else {
                    next = .absent
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

/// The "Local Network" permission panel in System Settings.
///
/// Recognising a refusal lives in `LocalNetworkDenial`, in the engine, next to the code that
/// makes the requests — see the note there on why matching the error code alone was wrong.
enum LocalNetwork {
    static var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork")!
    }
}

/// One channel, so `log show --predicate 'subsystem == "fr.xavier-kain.quix"'` shows what QuiX
/// decided and nothing else.
enum Log {
    static let camera = Logger(subsystem: "fr.xavier-kain.quix", category: "camera")
}

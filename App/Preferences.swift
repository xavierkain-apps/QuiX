import Foundation
import Observation

/// Les deux seuls réglages de l'app.
///
/// Le dossier d'import n'a pas de valeur par défaut : il est choisi au premier lancement. Deviner
/// un `~/Movies/GoPro` créerait un dossier que Xavier n'a pas demandé, à côté de celui où sont
/// déjà ses clips.
@Observable
final class Preferences {

    private enum Key {
        static let library = "libraryPath"
        static let askBeforeImporting = "askBeforeImporting"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.library = defaults.string(forKey: Key.library).map { URL(fileURLWithPath: $0, isDirectory: true) }
        self.askBeforeImporting = defaults.bool(forKey: Key.askBeforeImporting)
        self.agentIsLoaded = CameraAutoLaunch.isEnabled
    }

    /// Racine de la bibliothèque. Les dossiers datés se créent dedans.
    var library: URL? {
        didSet { defaults.set(library?.path, forKey: Key.library) }
    }

    /// Faux par défaut : brancher la carte lance l'import, comme le faisait Quik Desktop.
    ///
    /// La case existe quand même parce que brancher la carte d'un autre appareil ne doit pas
    /// déclencher une copie surprise. La vraie garde est ailleurs — une carte sans `DCIM/###GOPRO`
    /// n'est jamais touchée, réglage ou pas — mais laisser le choix coûte une ligne.
    var askBeforeImporting: Bool {
        didSet { defaults.set(askBeforeImporting, forKey: Key.askBeforeImporting) }
    }

    /// Lancer QuiX au branchement de la caméra.
    ///
    /// L'état ne vit pas dans les réglages : il vit dans `launchd`, qui est seul à savoir si
    /// l'agent est réellement chargé. Le lire ailleurs afficherait une case cochée pour un agent
    /// que le système aurait désactivé de son côté, dans les Réglages Système.
    ///
    /// Mais il faut quand même le **stocker** ici. Une propriété purement calculée, qui serait allée
    /// interroger `launchd` à chaque lecture, n'aurait rien donné à observer à SwiftUI : la case
    /// changeait d'état sans que rien ne se redessine, et il fallait relancer l'app pour la voir
    /// bouger. La valeur stockée est donc un reflet, relu de `launchd` après chaque écriture — et
    /// jamais une source de vérité qu'on croirait sur parole.
    private var agentIsLoaded: Bool

    var launchOnCameraConnection: Bool {
        get { agentIsLoaded }
        set {
            if newValue { CameraAutoLaunch.enable() } else { CameraAutoLaunch.disable() }
            // On réinterroge plutôt que d'écrire `newValue` : si l'installation échoue, la case
            // doit revenir d'où elle vient au lieu d'annoncer un agent qui n'existe pas.
            agentIsLoaded = CameraAutoLaunch.isEnabled
        }
    }

    /// Relit l'état réel de l'agent. À appeler quand la fenêtre revient au premier plan : il a pu
    /// être désactivé entre-temps depuis les Réglages Système.
    func refreshLaunchAgentState() {
        agentIsLoaded = CameraAutoLaunch.isEnabled
    }
}

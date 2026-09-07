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
}

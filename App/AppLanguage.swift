import AppKit
import Foundation

/// La langue de l'interface, quand on ne veut pas celle du système.
///
/// macOS choisit seul d'après les langues préférées du Mac, et c'est le bon défaut. Mais il n'offre
/// aucun moyen simple de voir l'app dans l'autre langue sans changer le réglage du système entier —
/// ni pour Xavier qui relit ses traductions, ni pour quelqu'un dont le Mac est en allemand et qui
/// préfère le français à l'anglais.
///
/// Le choix s'écrit dans `AppleLanguages`, **dans le domaine de QuiX seul**. Aucune autre app n'est
/// touchée, et macOS le relit au lancement suivant : d'où le redémarrage.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system, english, french

    var id: String { rawValue }

    /// Le code que `AppleLanguages` attend, ou `nil` pour laisser macOS décider.
    var code: String? {
        switch self {
        case .system: nil
        case .english: "en"
        case .french: "fr"
        }
    }

    /// Chaque langue s'écrit dans la sienne : « Français » reste « Français » dans une interface
    /// anglaise. C'est ce que font les Réglages Système, et c'est le seul libellé qu'on puisse lire
    /// quand on s'est trompé de langue et qu'on cherche à revenir.
    var label: String {
        switch self {
        case .system: String(localized: "Automatic")
        case .english: "English"
        case .french: "Français"
        }
    }

    private static let key = "AppleLanguages"

    static var current: AppLanguage {
        let stored = UserDefaults.standard.array(forKey: key) as? [String]
        guard let first = stored?.first else { return .system }
        return allCases.first { $0.code == first } ?? .system
    }

    /// Enregistre le choix. Ne redémarre rien : l'appelant décide quand.
    static func store(_ language: AppLanguage) {
        if let code = language.code {
            UserDefaults.standard.set([code], forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        UserDefaults.standard.synchronize()
    }

    /// Relance QuiX pour que la nouvelle langue prenne.
    ///
    /// Le relanceur est un `sh` détaché : il survit à la mort de l'app, attend qu'elle ait
    /// réellement quitté, puis la rouvre. Rouvrir depuis l'app elle-même reviendrait à demander à
    /// `launchd` de démarrer un processus dont le parent est en train de disparaître.
    static func restart() {
        let bundle = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open -a \"\(bundle)\""]
        try? task.run()
        NSApp.terminate(nil)
    }
}

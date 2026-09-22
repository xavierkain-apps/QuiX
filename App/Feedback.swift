import AppKit
import Foundation

/// Signaler un bug, ou demander une fonctionnalité.
///
/// **Pourquoi une page web et pas un formulaire dans l'app.** Un formulaire intégré ferait
/// transiter par QuiX des textes que l'utilisateur n'aurait pas vus partir, et demanderait à
/// l'app de porter une politique de confidentialité. La page, elle, montre ce qui part avant
/// qu'il n'appuie. Rien ne quitte le Mac sans un clic de sa part.
///
/// **Et pas GitHub non plus** : le dépôt est public, mais un compte GitHub est un mur pour
/// quelqu'un qui vient d'Instagram pour trier ses clips de surf.
///
/// **Ce qui est pré-rempli**, et rien d'autre : la version de QuiX, celle de macOS, le modèle de
/// Mac, et le modèle de caméra si une a été vue. Aucun nom de fichier, aucun chemin, aucune
/// adresse. Ce sont les quatre choses sans lesquelles un rapport de bug GoPro ne mène nulle part —
/// le format HiLight n'a été mesuré que sur une HERO12.
enum Feedback {

    enum Kind {
        case bug, idea

        var slug: String {
            switch self {
            case .bug: "bug"
            case .idea: "idea"
            }
        }
    }

    /// Le formulaire de retour du site.
    static let destination = "https://quix.xavier-kain.fr/retour"

    /// Ouvre le formulaire, avec le contexte technique déjà rempli.
    ///
    /// Les paramètres ne portent que des versions et des modèles. Jamais un chemin, jamais un nom
    /// de fichier, jamais une adresse : ce qui passe par une URL se retrouve dans les journaux du
    /// serveur, et rien de personnel n'a à y être.
    static func open(_ kind: Kind, cameraName: String?) {
        var items = [
            URLQueryItem(name: "type", value: kind.slug),
            URLQueryItem(name: "version", value: version),
            URLQueryItem(name: "os", value: systemVersion),
            URLQueryItem(name: "mac", value: model),
            URLQueryItem(name: "lang", value: interfaceLanguage),
        ]
        if let cameraName { items.append(URLQueryItem(name: "camera", value: cameraName)) }
        var components = URLComponents(string: destination)
        components?.queryItems = items
        guard let url = components?.url else { return }
        NSWorkspace.shared.open(url)
    }

    /// The language the interface is actually shown in — `en` or `fr` — so the form opens in the
    /// same one.
    ///
    /// Not `Locale.current`: that is the Mac's *region*, which says nothing about the language on
    /// screen. A Mac set to France showing QuiX in English sent `fr_FR`, and the form answered in
    /// French. `preferredLocalizations` is the localisation the bundle really resolved, including
    /// the choice made in QuiX's own settings.
    static var interfaceLanguage: String {
        let resolved = Bundle.main.preferredLocalizations.first ?? "en"
        return resolved.hasPrefix("fr") ? "fr" : "en"
    }

    /// Ce que l'écran des réglages affiche, pour qu'on voie ce qui sera joint.
    static func environment(cameraName: String?) -> String {
        var lines = ["QuiX \(version)", "macOS \(systemVersion)", model]
        if let cameraName { lines.append("Camera \(cameraName)") }
        return lines.joined(separator: " · ")
    }

    static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return "\(short ?? "?") (\(build ?? "?"))"
    }

    /// L'identifiant matériel — « Mac15,3 ». Utile parce qu'un défaut de copie USB peut tenir au
    /// contrôleur, et inutile pour identifier qui que ce soit : des centaines de milliers de Mac
    /// portent le même.
    static var systemVersion: String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
    }

    static var model: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "?" }
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }
}

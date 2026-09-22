import AppKit
import Foundation

/// Signaler un bug, ou demander une fonctionnalité.
///
/// **Pourquoi pas un formulaire dans l'app.** Un formulaire demanderait un serveur, une adresse
/// où poster, et ferait transiter par QuiX des textes libres que l'utilisateur n'a pas vus
/// partir. Ouvrir une page pré-remplie ne fait rien de tout ça : l'utilisateur lit ce qui part,
/// l'efface s'il veut, et envoie lui-même. Rien ne quitte le Mac sans qu'il ait cliqué.
///
/// **Ce qui est pré-rempli**, et rien d'autre : la version de QuiX, celle de macOS, le modèle de
/// Mac, et le modèle de caméra si une a été vue. Aucun nom de fichier, aucun chemin, aucune
/// adresse. Ce sont les quatre choses sans lesquelles un rapport de bug GoPro ne mène nulle part —
/// le format HiLight n'a été mesuré que sur une HERO12.
enum Feedback {

    enum Kind {
        case bug, idea

        var title: String {
            switch self {
            case .bug: "Bug : "
            case .idea: "Idée : "
            }
        }

        var label: String {
            switch self {
            case .bug: "bug"
            case .idea: "enhancement"
            }
        }
    }

    /// Le dépôt qui reçoit les retours. Le jour où le site porte un formulaire, c'est la seule
    /// ligne à changer.
    static let destination = "https://github.com/xavierkain-apps/QuiX/issues/new"

    static func open(_ kind: Kind, cameraName: String?) {
        var components = URLComponents(string: destination)
        components?.queryItems = [
            URLQueryItem(name: "title", value: kind.title),
            URLQueryItem(name: "labels", value: kind.label),
            URLQueryItem(name: "body", value: body(kind, cameraName: cameraName)),
        ]
        guard let url = components?.url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Le corps pré-rempli : d'abord ce que l'utilisateur a à écrire, puis ce qu'on a mesuré.
    private static func body(_ kind: Kind, cameraName: String?) -> String {
        let prompt = switch kind {
        case .bug:
            String(localized: """
                **What happened**


                **What you expected**


                **How to reproduce it**

                """)
        case .idea:
            String(localized: """
                **What you would like**


                **What you are trying to do**

                """)
        }
        return prompt + "\n---\n\n" + environment(cameraName: cameraName)
    }

    static func environment(cameraName: String?) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var lines = [
            "QuiX \(version)",
            "macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            model,
        ]
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
    private static var model: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "?" }
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &bytes, &size, nil, 0)
        return String(cString: bytes)
    }
}

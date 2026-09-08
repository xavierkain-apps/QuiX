import Foundation

/// Lancer QuiX quand la GoPro est branchée.
///
/// Il n'y a rien à surveiller pour ça, parce qu'il n'y a rien à surveiller quand l'app ne tourne
/// pas. C'est `launchd` qui s'en charge : on lui dépose un agent qui déclare vouloir être réveillé
/// à l'apparition d'un périphérique USB GoPro. Tant que la caméra n'est pas branchée, aucun
/// processus n'existe et rien ne consomme quoi que ce soit.
///
/// **L'agent lance `open`, pas l'exécutable.** C'est ce qui évite un second exemplaire quand QuiX
/// tourne déjà : `open` se contente d'activer l'app existante. Lancer directement le binaire
/// donnerait deux fenêtres et deux imports concurrents sur la même carte.
///
/// Trois détails de l'appariement ont été trouvés à l'essai, et aucun n'est devinable — un agent
/// qui n'apparie rien ne se plaint pas, il ne se déclenche simplement jamais :
///
/// - la clé de l'évènement doit s'appeler **`com.apple.device-attach`** ; un nom libre est accepté
///   par `launchd`, affiché par `launchctl print`, et ne déclenche rien ;
/// - la classe est **`IOUSBDevice`**, pas `IOUSBHostDevice` — c'est le nom hérité que publie encore
///   le nœud USB, et c'est celui que `UserEventAgent` regarde ;
/// - **`idProduct` est obligatoire.** Apparier le seul `idVendor` ne déclenche rien, alors qu'un
///   fabricant seul semblerait pourtant suffire.
///
/// Le dernier point coûte quelque chose : l'agent ne reconnaît que le modèle mesuré. Une autre
/// GoPro demanderait son propre identifiant, relevé par
/// `ioreg -p IOUSB -l | grep -A20 GoPro`.
enum CameraAutoLaunch {

    static let label = "com.xavierkain.QuiX.camera"

    /// GoPro. `0x2672`, relevé sur la HERO12 — voir `docs/USB.md`.
    static let goProVendorID = 9842
    /// HERO12 Black, `0x0059`. Voir la remarque ci-dessus : il n'est pas facultatif.
    static let hero12ProductID = 89

    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Vrai si `launchd` connaît l'agent — pas seulement si le fichier traîne sur le disque.
    static var isEnabled: Bool {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return false }
        return launchctl(["print", "gui/\(getuid())/\(label)"]) == 0
    }

    @discardableResult
    static func enable() -> Bool {
        let bundle = Bundle.main.bundleURL.path
        let plist: [String: Any] = [
            "Label": label,
            // `-g` : ouvrir sans passer devant ce que fait l'utilisateur. Il verra la fenêtre en
            // revenant, plutôt que de se la prendre au milieu d'autre chose.
            "ProgramArguments": ["/usr/bin/open", "-g", "-a", bundle],
            "LaunchEvents": [
                "com.apple.iokit.matching": [
                    "com.apple.device-attach": [
                        "IOProviderClass": "IOUSBDevice",
                        "IOMatchLaunchStream": true,
                        "idVendor": goProVendorID,
                        "idProduct": hero12ProductID,
                    ]
                ]
            ],
            // L'agent réagit à un évènement ; il ne doit ni démarrer à l'ouverture de session ni
            // être relancé quand il se termine.
            "RunAtLoad": false,
            "KeepAlive": false,
        ]

        do {
            try FileManager.default.createDirectory(
                at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: plist,
                                                          format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } catch {
            return false
        }

        // Un agent déjà chargé refuse d'être rechargé : on le retire avant, sans se soucier de
        // l'échec s'il n'y était pas.
        _ = launchctl(["bootout", "gui/\(getuid())/\(label)"])
        return launchctl(["bootstrap", "gui/\(getuid())", plistURL.path]) == 0
    }

    @discardableResult
    static func disable() -> Bool {
        _ = launchctl(["bootout", "gui/\(getuid())/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
        return true
    }

    @discardableResult
    private static func launchctl(_ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

import AppKit
import Foundation
import XPC

/// Lancer QuiX quand la GoPro est branchée.
///
/// Il n'y a rien à surveiller pour ça, parce qu'il n'y a rien à surveiller quand l'app ne tourne
/// pas. C'est `launchd` qui s'en charge : on lui dépose un agent qui déclare vouloir être réveillé
/// à l'apparition d'un périphérique USB GoPro. Tant que la caméra n'est pas branchée, aucun
/// processus n'existe et rien ne consomme quoi que ce soit.
///
/// **L'agent lance l'exécutable de l'app, et non `open`.** C'est contre-intuitif — `open` gère seul
/// le cas de l'app déjà lancée — mais il ne sait pas *consommer* l'évènement `launchd`. Or tant
/// qu'un évènement reste en attente, `launchd` considère le travail comme inachevé et le relance
/// toutes les dizaines de secondes : l'app se rouvrait donc toute seule dès qu'on la fermait,
/// caméra encore branchée. Seul un programme qui appelle `xpc_set_event_stream_handler` met fin à
/// ce cycle, et ce programme doit donc être l'app.
///
/// Le prix à payer est le second exemplaire, que `open` évitait gratuitement : `launchd` lance le
/// binaire sans passer par LaunchServices, donc sans sa règle d'instance unique. `QuiXApp` s'en
/// charge — le nouveau venu consomme l'évènement, ramène la fenêtre existante, et se retire.
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

    /// Remet l'agent à jour s'il date d'une version précédente de l'app.
    ///
    /// Sans ça, un agent installé une fois garderait pour toujours le comportement qu'il avait au
    /// moment où on a coché la case — ici, une app qui s'ouvrait derrière les autres. On ne le
    /// réécrit que s'il diffère : recharger un agent à chaque démarrage pour rien serait une
    /// façon discrète de le rendre instable.
    static func refreshIfOutdated() {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }
        guard let onDisk = NSDictionary(contentsOf: plistURL) as? [String: Any] else { return }
        let wanted = agent()
        guard !NSDictionary(dictionary: onDisk).isEqual(to: wanted) else { return }
        enable()
    }

    /// La définition de l'agent, telle qu'elle doit être sur le disque.
    private static func agent() -> [String: Any] {
        let executable = Bundle.main.executableURL?.path
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/QuiX").path
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
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
        return plist
    }

    @discardableResult
    static func enable() -> Bool {
        let plist = agent()

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

    // MARK: - L'évènement qu'il faut consommer

    private static let delivered = DispatchSemaphore(value: 0)

    /// Consomme les évènements que `launchd` a mis en attente pour nous.
    ///
    /// À appeler au tout début du démarrage, **même quand l'app a été ouverte à la main** : elle
    /// peut l'avoir été alors qu'un évènement traînait, et un évènement jamais consommé fait
    /// relancer l'app indéfiniment.
    static func consumeLaunchEvents() {
        xpc_set_event_stream_handler("com.apple.iokit.matching", nil) { _ in
            delivered.signal()
        }
    }

    /// Laisse à `launchd` le temps de livrer son évènement avant qu'on se retire.
    ///
    /// Sert au second exemplaire : partir trop vite laisserait l'évènement en attente, et la
    /// boucle de relance reprendrait exactement là où on croyait l'avoir arrêtée.
    static func waitForLaunchEvent(timeout: TimeInterval = 3) {
        _ = delivered.wait(timeout: .now() + timeout)
    }

    /// Un autre exemplaire de QuiX tourne-t-il déjà ? Si oui, on lui rend la main.
    static func handOverToRunningInstance() -> Bool {
        guard let identifier = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: identifier)
            .filter { $0.processIdentifier != getpid() }
        guard let existing = others.first else { return false }
        existing.activate(options: [.activateAllWindows])
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

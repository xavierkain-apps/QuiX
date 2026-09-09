import AppKit
import SwiftUI

/// Ce que SwiftUI seul ne sait pas faire au démarrage.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Avant toute chose. `launchd` relance indéfiniment un travail dont l'évènement n'a pas
        // été consommé : sans cet appel, fermer QuiX caméra branchée le rouvrait dix secondes plus
        // tard, sans fin.
        CameraAutoLaunch.consumeLaunchEvents()

        // `launchd` lance le binaire sans passer par LaunchServices, donc sans sa règle d'instance
        // unique : quand QuiX tourne déjà, c'est un second exemplaire qui démarre ici. Il ramène
        // la fenêtre existante et se retire — après avoir laissé l'évènement arriver, faute de
        // quoi la boucle de relance reprendrait.
        if CameraAutoLaunch.handOverToRunningInstance() {
            CameraAutoLaunch.waitForLaunchEvent()
            exit(0)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Réveillée par `launchd` au branchement de la caméra, l'app s'ouvre sans passer devant :
        // on va chercher sa fenêtre à la main alors qu'on vient justement de brancher pour ça.
        //
        // `activate()` seul ne suffit pas ici. Depuis macOS 14, l'activation est « coopérative » :
        // l'app au premier plan peut la refuser, et un processus sorti de `launchd` n'a rien pour
        // la lui faire céder. Il faut la forme impérative, dépréciée mais seule à fonctionner —
        // ce que l'utilisateur a demandé en branchant sa caméra prime sur la politesse entre apps.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // Un agent installé par une version précédente garde le comportement qu'il avait alors.
        CameraAutoLaunch.refreshIfOutdated()
    }

    /// Rebrancher la caméra alors que QuiX tourne déjà doit ramener sa fenêtre, pas ne rien faire.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct QuiXApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = ImportModel()

    var body: some Scene {
        Window("QuiX", id: "quix") {
            ContentView(model: model)
        }
        .commands {
            // L'app fait une chose : il n'y a rien à créer, rien à ouvrir.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

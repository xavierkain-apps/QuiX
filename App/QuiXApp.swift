import AppKit
import SwiftUI

/// Ce que SwiftUI seul ne sait pas faire au démarrage.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Réveillée par `launchd` au branchement de la caméra, l'app s'ouvre sans passer devant :
        // on va chercher sa fenêtre à la main alors qu'on vient justement de brancher pour ça.
        NSApp.activate()

        // Un agent installé par une version précédente garde le comportement qu'il avait alors.
        CameraAutoLaunch.refreshIfOutdated()
    }

    /// Rebrancher la caméra alors que QuiX tourne déjà doit ramener sa fenêtre, pas ne rien faire.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        NSApp.activate()
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

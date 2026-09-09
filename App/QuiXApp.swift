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
        // Le redesign est sombre par choix, pas par suivi du thème : sans ça les barres de titre
        // et les contrôles système restent clairs au milieu de fenêtres à l'encre.
        NSApp.appearance = NSAppearance(named: .darkAqua)
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
        // Le siège de l'app : un item de barre de menus, et un popover qui suit l'état.
        MenuBarExtra {
            MenuBarPopover(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)

        Window("Transfert", id: WindowID.transfer) {
            TransferWindow(model: model)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: Metrics.transferWidth, height: 640)

        Window("Bibliothèque", id: WindowID.library) {
            LibraryWindow(model: model)
        }
        .defaultSize(width: Metrics.libraryWidth, height: Metrics.libraryHeight)
        .commands {
            // L'app fait une chose : il n'y a rien à créer, rien à ouvrir.
            CommandGroup(replacing: .newItem) {}
        }
    }
}

/// L'item de barre de menus : le glyphe, et une pastille pendant un import.
///
/// Il porte aussi l'ouverture automatique de la fenêtre Transfert, et c'est délibéré : le popover
/// ne peut pas s'ouvrir par programme, si bien qu'un import démarré tout seul — caméra branchée,
/// app réveillée par `launchd` — n'aurait aucune surface où se montrer. Cette vue-ci est la seule
/// qui vive en permanence ; la placer dans la fenêtre Transfert reviendrait à n'ouvrir celle-ci
/// que lorsqu'elle est déjà ouverte.
private struct MenuBarLabel: View {
    let model: ImportModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: MenuBarIcon.image)
            if model.stageKind == .importing {
                Circle().fill(Ink.blue).frame(width: 5, height: 5)
            }
        }
        .onChange(of: model.stageKind) { _, kind in
            guard kind == .importing || kind == .ready else { return }
            openWindow(id: WindowID.transfer)
        }
    }
}

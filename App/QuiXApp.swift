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

        // Le délégué des notifications se pose au démarrage, avant toute bannière : c'est lui
        // qui les fait apparaître même quand QuiX est déjà devant.
        Notifier.shared.start()

        // Un agent installé par une version précédente garde le comportement qu'il avait alors.
        CameraAutoLaunch.refreshIfOutdated()

    }

    /// Rebrancher la caméra alors que QuiX tourne déjà doit ramener sa fenêtre, pas ne rien faire.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        // `hasVisibleWindows` est faux quand on a fermé la fenêtre : il faut la recréer, pas
        // seulement activer l'app — sinon le clic sur le Dock ne fait rien de visible.
        if !hasVisibleWindows {
            NotificationCenter.default.post(name: .quixOpenMainWindow, object: nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }
}

@main
struct QuiXApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = ImportModel()
    @State private var router = AppRouter()

    var body: some Scene {
        // Le siège de l'app : un item de barre de menus, et un popover qui suit l'état.
        MenuBarExtra {
            MenuBarPopover(model: model, router: router)
                .environment(\.appRouter, router)
        } label: {
            MenuBarLabel(model: model, router: router)
        }
        .menuBarExtraStyle(.window)

        Window("QuiX", id: WindowID.main) {
            MainWindow(model: model, router: router)
                .environment(\.appRouter, router)
        }
        .defaultSize(width: 1280, height: 760)
        .commands {
            // Ce que SwiftUI ajoute par défaut ne correspond à rien ici : l'app ne crée pas de
            // document, n'imprime pas, n'a pas de barre d'outils. On retire, plutôt que de laisser
            // des menus grisés qui donnent l'air d'une app inachevée.
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .saveItem) {}
            CommandGroup(replacing: .printItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .toolbar) {}
            CommandGroup(replacing: .sidebar) {}
            // Le menu Aide était vide. C'est l'endroit où l'on cherche « comment leur dire
            // que ça ne marche pas ».
            CommandGroup(replacing: .help) {
                Button("Report a bug…") { Feedback.open(.bug, cameraName: model.cameraName) }
                Button("Suggest a feature…") { Feedback.open(.idea, cameraName: model.cameraName) }
            }

            CommandGroup(after: .windowArrangement) {
                Button("Transfer") { router.tab = .transfer }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Library") { router.tab = .library }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Settings") { router.tab = .settings }
                    .keyboardShortcut("3", modifiers: .command)
            }

            // Les réglages sont un onglet, pas une fenêtre à part : aller les chercher dans le
            // menu de l'app n'était pas le premier endroit où on les cherche.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { router.tab = .settings }
                    .keyboardShortcut(",", modifiers: .command)
            }
        }

    }
}

/// L'item de barre de menus : le glyphe, et une pastille pendant un import.
///
/// Il porte aussi l'ouverture automatique de la fenêtre, et c'est délibéré : le popover ne peut pas
/// s'ouvrir par programme, si bien qu'un import démarré tout seul — caméra branchée, app réveillée
/// par `launchd` — n'aurait aucune surface où se montrer. Cette vue-ci est la seule qui vive en
/// permanence ; la placer dans la fenêtre reviendrait à ne l'ouvrir que lorsqu'elle l'est déjà.
private struct MenuBarLabel: View {
    let model: ImportModel
    let router: AppRouter
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 3) {
            Image(nsImage: MenuBarIcon.image)
            if model.stageKind == .importing {
                Circle().fill(Ink.blue).frame(width: 5, height: 5)
            }
        }
        // Le tout premier lancement n'a pas de carte à annoncer : sans cela, l'accueil
        // n'apparaîtrait qu'au moment où l'on brancherait quelque chose — c'est-à-dire trop tard
        // pour expliquer ce qu'il faut autoriser avant de brancher.
        // Lancer l'app ouvre sa fenêtre. Cela semble aller de soi ; ça n'allait pas : une app
        // qui vit dans la barre de menus n'en ouvre aucune au démarrage. On cliquait l'icône du
        // Dock, elle rebondissait, et il fallait aller la chercher dans le menu du haut.
        //
        // C'est ici et pas dans l'`AppDelegate` : `applicationDidFinishLaunching` court avant
        // que cette vue n'existe, et sa notification n'aurait eu personne pour l'entendre.
        .onAppear {
            if !model.preferences.onboardingDone { router.tab = .transfer }
            openWindow(id: WindowID.main)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .quixOpenMainWindow)) { _ in
            openWindow(id: WindowID.main)
            NSApp.activate(ignoringOtherApps: true)
        }
        .onChange(of: model.stageKind) { _, kind in
            // Tout état qui attend quelque chose ouvre la fenêtre, pas seulement ceux qui
            // montrent une table : une app qui attend un dossier d'import doit le demander là où
            // l'on regarde, et pas dans un popover qu'il faut penser à ouvrir.
            switch kind {
            case .scanning, .ready, .importing, .needsLibrary, .needsLocalNetwork:
                router.tab = .transfer
                openWindow(id: WindowID.main)
                // L'activation au démarrage ne suffit pas : la fenêtre n'existe pas encore à ce
                // moment-là. Il faut la réclamer une fois qu'elle est ouverte, sinon elle apparaît
                // derrière ce qu'on avait sous les yeux.
                NSApp.activate(ignoringOtherApps: true)
            case .waiting, .finished, .failed:
                break
            }
        }
    }
}

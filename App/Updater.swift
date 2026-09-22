import Foundation
import Observation
import Sparkle

/// Les mises à jour, par Sparkle.
///
/// QuiX se distribue hors de l'App Store : rien ne prévient personne qu'une version corrige le
/// bug qu'il vient de signaler. Sans ce mécanisme, une version défectueuse reste installée chez
/// tout le monde jusqu'à ce que chacun repasse sur le site de son plein gré — c'est-à-dire
/// jamais.
///
/// **La signature est le cœur du dispositif.** Une mise à jour automatique est un moyen
/// d'exécuter du code sur la machine de quelqu'un. Sparkle refuse toute archive dont la
/// signature EdDSA ne correspond pas à `SUPublicEDKey`, inscrite dans l'`Info.plist`. La clé
/// privée ne vit que dans le trousseau de Xavier et dans un secret de l'intégration continue :
/// quelqu'un qui prendrait le contrôle du serveur ne pourrait pas pour autant faire installer
/// son propre binaire.
@MainActor
@Observable
final class Updater {

    static let shared = Updater()

    private let controller: SPUStandardUpdaterController

    /// Suit l'autorisation de chercher des mises à jour, pour que la case des réglages la
    /// reflète sans qu'on ait à relancer l'app.
    var checksAutomatically: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    private init() {
        // `startingUpdater: true` lance le contrôleur tout de suite. Le premier contrôle n'est
        // pas immédiat pour autant : Sparkle attend que l'app ait fini de démarrer, et respecte
        // l'intervalle de `SUScheduledCheckInterval`.
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
    }

    /// Le contrôle demandé à la main, depuis le menu ou les réglages.
    func checkNow() {
        controller.updater.checkForUpdates()
    }

    /// La date du dernier contrôle, telle qu'on l'affiche.
    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }
}

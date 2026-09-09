import Observation
import SwiftUI

/// L'onglet affiché par la fenêtre principale.
///
/// Transfert et Bibliothèque étaient deux fenêtres ; ce sont deux onglets d'une seule. Le choix
/// vit ici, hors des vues, parce que trois endroits le changent : le popover, la barre de menus, et
/// le bouton « Ouvrir les highlights » du Transfert.
@MainActor
@Observable
final class AppRouter {

    enum Tab: String, CaseIterable, Identifiable {
        case transfer = "Transfert"
        case library = "Bibliothèque"
        case settings = "Réglages"

        var id: String { rawValue }
    }

    /// Le Transfert par défaut : c'est ce qu'on vient voir quand on branche une carte.
    var tab: Tab = .transfer
}

/// Le routeur, accessible des vues profondes sans le passer de main en main.
extension EnvironmentValues {
    @Entry var appRouter: AppRouter?
}

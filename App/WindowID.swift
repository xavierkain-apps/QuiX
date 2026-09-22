import Foundation

/// L'identifiant de la fenêtre principale.
///
/// Il n'y en a qu'une : Transfert et Bibliothèque en sont deux onglets, pas deux fenêtres.
enum WindowID {
    static let main = "quix"
}

/// Demander l'ouverture de la fenêtre depuis l'`AppDelegate`.
///
/// `openWindow` n'existe que dans l'environnement d'une vue. L'`AppDelegate`, lui, est le seul à
/// savoir que l'app vient d'être lancée ou que son icône du Dock vient d'être cliquée. Il poste,
/// la barre de menus écoute — c'est la seule vue qui vive en permanence.
extension Notification.Name {
    static let quixOpenMainWindow = Notification.Name("quix.openMainWindow")
}

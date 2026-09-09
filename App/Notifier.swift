import Foundation
import UserNotifications

/// Prévient quand un import se termine.
///
/// Sans elle, un import qui démarre tout seul se termine tout seul, sans que rien ne le dise : on
/// ne sait pas quand débrancher. C'est le seul rôle de cette notification, et elle ne remplace pas
/// la fenêtre — le détail, le comparatif et l'effacement y restent.
enum Notifier {

    /// L'autorisation se demande une fois, au premier import terminé plutôt qu'au lancement : une
    /// invite système avant même d'avoir rien fait est du bruit.
    static func notify(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content, trigger: nil))
        }
    }
}

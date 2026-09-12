import Foundation
import UserNotifications

/// Prévient quand un import se termine.
///
/// Sans elle, un import qui démarre tout seul se termine tout seul, sans que rien ne le dise : on
/// ne sait pas quand débrancher. C'est son seul rôle, et elle ne remplace pas la fenêtre — le
/// détail, le comparatif et l'effacement y restent.
///
/// **Pourquoi un délégué.** macOS supprime la bannière quand l'app qui la poste est au premier
/// plan : il considère qu'on est déjà devant. Or QuiX s'y met justement pour montrer l'import.
/// La notification n'apparaissait donc qu'une fois sur deux — celles où l'on avait cliqué
/// ailleurs entre-temps. Répondre `banner` à `willPresent` lève cette suppression.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {

    static let shared = Notifier()

    private var authorized = false

    /// À appeler une fois au démarrage.
    ///
    /// L'autorisation se demande ici plutôt qu'à la première notification : demandée au moment de
    /// poster, la première bannière se perdait pendant que l'invite système attendait une réponse.
    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            self?.authorized = granted
        }
    }

    func notify(title: String, body: String) {
        guard authorized else {
            // L'autorisation peut encore être en cours d'obtention au tout premier lancement :
            // on redemande plutôt que de laisser tomber la notification en silence.
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
                guard granted else { return }
                self?.authorized = true
                self?.post(title: title, body: body)
            }
            return
        }
        post(title: title, body: body)
    }

    private func post(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Afficher la bannière même quand QuiX est devant.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

import Foundation

/// Drapeau d'annulation partagé entre la fenêtre et la copie, qui tournent sur deux fils.
///
/// La copie est un `while` synchrone dans une tâche détachée : elle ne peut pas lire une propriété
/// isolée sur l'acteur principal. Un verrou est la façon la plus simple de faire passer un booléen
/// dans ce sens-là.
final class CancellationFlag: @unchecked Sendable {

    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
    }
}

import AppKit

/// Surveille les volumes montés et démontés.
///
/// Ne concerne que la carte dans un lecteur : elle apparaît sous `/Volumes/` comme n'importe quel
/// disque. La caméra branchée en USB-C, elle, n'expose aucun volume — elle monte un réseau et se
/// lit en HTTP ; c'est `CameraWatcher` qui s'en occupe.
@MainActor
final class VolumeWatcher {

    private var observers: [NSObjectProtocol] = []
    private let center = NSWorkspace.shared.notificationCenter

    /// - Parameters:
    ///   - onMount: appelé pour chaque volume monté, **et pour ceux déjà montés au démarrage**.
    ///     Sans ce rattrapage, lancer l'app carte déjà branchée ne ferait rien du tout — ce qui est
    ///     précisément ce qui arrive quand on installe l'app pour la première fois.
    init(onMount: @escaping (URL) -> Void, onUnmount: @escaping (URL) -> Void) {
        observers.append(center.addObserver(forName: NSWorkspace.didMountNotification,
                                           object: nil, queue: .main) { notification in
            guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            MainActor.assumeIsolated { onMount(url) }
        })

        observers.append(center.addObserver(forName: NSWorkspace.didUnmountNotification,
                                           object: nil, queue: .main) { notification in
            guard let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL else { return }
            MainActor.assumeIsolated { onUnmount(url) }
        })

        for volume in VolumeWatcher.mountedVolumes() { onMount(volume) }
    }

    deinit {
        let center = NSWorkspace.shared.notificationCenter
        for observer in observers { center.removeObserver(observer) }
    }

    static func mountedVolumes() -> [URL] {
        FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) ?? []
    }
}

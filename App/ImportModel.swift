import AppKit
import Observation
import QuiXCore

/// L'état de l'app, du branchement de la carte au dossier ouvert dans le Finder.
@MainActor
@Observable
final class ImportModel {

    enum Stage {
        /// Aucune carte GoPro branchée, aucune caméra en USB.
        case waiting
        /// Une caméra est branchée mais macOS interdit à QuiX de lui parler.
        /// La caméra étant un périphérique réseau, c'est la permission « Réseau local ».
        case needsLocalNetwork
        /// Lecture des en-têtes. Quelques secondes pour une carte entière.
        case scanning(done: Int, total: Int)
        /// Carte lue, mais aucun dossier d'import n'a encore été choisi.
        case needsLibrary(CardScanner.Result)
        /// Carte lue, import en attente d'un clic. N'arrive que si le réglage le demande.
        case ready(CardScanner.Result, ImportPlan)
        case importing(ImportProgress)
        case finished(ImportReport)
        case failed(String)
    }

    private(set) var stage: Stage = .waiting
    private(set) var card: URL?
    /// La caméra branchée en USB, si elle répond. Source alternative à la carte.
    private(set) var camera: GoProCamera?
    private(set) var cameraName: String?

    let preferences: Preferences
    private var watcher: VolumeWatcher?
    private var cameraWatcher: CameraWatcher?
    private var cancellation: CancellationFlag?

    init(preferences: Preferences = Preferences()) {
        self.preferences = preferences
        self.watcher = VolumeWatcher(
            onMount: { [weak self] url in self?.volumeAppeared(url) },
            onUnmount: { [weak self] url in self?.volumeDisappeared(url) }
        )
        self.cameraWatcher = CameraWatcher { [weak self] state in
            self?.cameraChanged(state)
        }
    }

    // MARK: - Caméra en USB

    /// La carte dans un lecteur reste prioritaire : elle est plus rapide que le câble, et si les
    /// deux sont là, c'est elle que l'utilisateur a délibérément branchée.
    private func cameraChanged(_ state: CameraWatcher.State) {
        switch state {
        case .absent:
            camera = nil
            cameraName = nil
            if card == nil, case .waiting = stage { return }
            if card == nil, !isBusy { stage = .waiting }

        case .denied:
            camera = nil
            cameraName = nil
            guard card == nil, !isBusy else { return }
            stage = .needsLocalNetwork

        case .connected(let found, let info):
            guard card == nil else { return }
            camera = found
            cameraName = info.modelName
            guard !isBusy else { return }
            scanCamera(found)
        }
    }

    /// Vrai dès qu'un travail est en cours ou qu'un résultat est affiché : on ne l'écrase pas
    /// parce qu'une sonde périodique a changé d'avis.
    private var isBusy: Bool {
        switch stage {
        case .waiting, .needsLocalNetwork: return false
        default: return true
        }
    }

    private func scanCamera(_ camera: GoProCamera) {
        stage = .scanning(done: 0, total: 0)

        Task.detached(priority: .userInitiated) { [self] in
            do {
                let result = try CameraScanner.scan(camera: camera, progress: { done, total in
                    Task { @MainActor in self.progressed(done: done, total: total) }
                })
                await cameraScanned(result, from: camera)
            } catch CameraScanner.ScanFailure.rangeUnsupported {
                await report(failure: "Cette caméra ne permet pas de lire les clips par morceaux. "
                    + "Utilisez la carte dans un lecteur.")
            } catch {
                await report(failure: "Lecture de la caméra impossible — \(error.localizedDescription)")
            }
        }
    }

    private func cameraScanned(_ result: CardScanner.Result, from source: GoProCamera) {
        guard camera?.host == source.host, card == nil else { return }
        planOrAsk(result)
    }

    /// Ouvre les Réglages Système à la page qui manque.
    func openLocalNetworkSettings() {
        NSWorkspace.shared.open(LocalNetwork.settingsURL)
    }

    /// Force une nouvelle tentative après un aller-retour dans les Réglages.
    func recheckCamera() {
        cameraWatcher?.poll()
    }

    // MARK: - Volumes

    private func volumeAppeared(_ volume: URL) {
        // La garde qui compte : on ne regarde jamais le nom du volume, seulement la présence d'un
        // dossier `DCIM/###GOPRO`. La carte d'un autre appareil n'est pas touchée, même si elle
        // s'appelle « GOPRO ».
        guard CardScanner.isGoProCard(volume), card == nil else { return }
        card = volume
        scan(volume)
    }

    private func volumeDisappeared(_ volume: URL) {
        guard card == volume else { return }
        card = nil
        cancellation?.cancel()
        if case .finished = stage { return }   // on garde le compte rendu du dernier import
        stage = .waiting
    }

    // MARK: - Scan

    private func scan(_ volume: URL) {
        stage = .scanning(done: 0, total: 0)

        Task.detached(priority: .userInitiated) { [self] in
            do {
                let result = try CardScanner.scan(volume: volume, progress: { done, total in
                    Task { @MainActor in self.progressed(done: done, total: total) }
                })
                await cardScanned(result, on: volume)
            } catch {
                await report(failure: "Lecture de la carte impossible — \(error.localizedDescription)")
            }
        }
    }

    private func progressed(done: Int, total: Int) {
        guard case .scanning = stage else { return }
        stage = .scanning(done: done, total: total)
    }

    private func cardScanned(_ result: CardScanner.Result, on volume: URL) {
        guard card == volume else { return }
        planOrAsk(result)
    }

    private func planOrAsk(_ result: CardScanner.Result) {
        // Sans dossier d'import, rien ne part : la carte est lue, il ne manque que la destination.
        guard let library = preferences.library else {
            stage = .needsLibrary(result)
            return
        }

        let index = ImportIndexStore.load(fromLibrary: library)
        let plan = ImportPlanner.plan(takes: result.takes, into: library,
                                      folderName: ImportFolderName.iso(for: Date()), index: index)

        if preferences.askBeforeImporting || plan.isEmpty {
            stage = .ready(result, plan)
        } else {
            start(plan)
        }
    }

    // MARK: - Import

    func startPlannedImport() {
        guard case .ready(_, let plan) = stage else { return }
        start(plan)
    }

    private func start(_ plan: ImportPlan) {
        guard let library = preferences.library else { return }

        let flag = CancellationFlag()
        cancellation = flag
        stage = .importing(ImportProgress(fileIndex: 0, fileCount: plan.copies.count,
                                          currentFile: "", bytesCopied: 0, byteCount: plan.byteCount))

        Task.detached(priority: .userInitiated) { [self] in
            var index = ImportIndexStore.load(fromLibrary: library)
            var lastPercent = -1

            let report = ImportRunner.run(
                plan, library: library, index: &index,
                isCancelled: { flag.isCancelled },
                progress: { progress in
                    // La copie émet une progression par bloc de 4 Mo. Ne remonter que les
                    // changements de pourcentage évite d'inonder l'acteur principal pour des
                    // rafraîchissements que personne ne voit.
                    let percent = Int(progress.fraction * 100)
                    guard percent != lastPercent else { return }
                    lastPercent = percent
                    Task { @MainActor in self.stage = .importing(progress) }
                }
            )

            try? ImportIndexStore.save(index, toLibrary: library)
            await importFinished(report)
        }
    }

    func cancel() {
        cancellation?.cancel()
    }

    private func importFinished(_ report: ImportReport) {
        cancellation = nil
        stage = .finished(report)
    }

    private func report(failure: String) {
        stage = .failed(failure)
    }

    // MARK: - Actions de la fenêtre

    /// Choix du dossier d'import. Posé une fois, au premier lancement, puis modifiable.
    func chooseLibrary() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Choisir"
        panel.message = "Où ranger les clips importés ?"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        preferences.library = url
        // La source est déjà là : on refait le plan sans attendre un rebranchement.
        if let volume = card { scan(volume) } else if let camera { scanCamera(camera) }
    }

    func revealHighlights() {
        guard case .finished(let report) = stage else { return }
        let folder = FileManager.default.fileExists(atPath: report.highlightsFolder.path)
            ? report.highlightsFolder
            : report.importFolder
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }

    /// Referme le compte rendu. Si la carte est encore là, on la relit plutôt que d'afficher
    /// « branchez la carte » alors qu'elle est branchée.
    func dismissReport() {
        if let volume = card { scan(volume) }
        else if let camera { scanCamera(camera) }
        else { stage = .waiting }
    }
}

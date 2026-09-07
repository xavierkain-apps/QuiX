import AppKit
import Observation
import QuiXCore

/// L'état de l'app, du branchement de la carte au dossier ouvert dans le Finder.
@MainActor
@Observable
final class ImportModel {

    enum Stage {
        /// Aucune carte GoPro branchée.
        case waiting
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

    let preferences: Preferences
    private var watcher: VolumeWatcher?
    private var cancellation: CancellationFlag?

    init(preferences: Preferences = Preferences()) {
        self.preferences = preferences
        self.watcher = VolumeWatcher(
            onMount: { [weak self] url in self?.volumeAppeared(url) },
            onUnmount: { [weak self] url in self?.volumeDisappeared(url) }
        )
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
        if let volume = card { scan(volume) }   // la carte est déjà là : on refait le plan
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
        if let volume = card { scan(volume) } else { stage = .waiting }
    }
}

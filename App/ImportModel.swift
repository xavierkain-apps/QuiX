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

    /// Le comparatif caméra ↔ Mac, calculé après un import depuis la caméra. `nil` pour une carte :
    /// l'effacement ne concerne que la caméra, une carte se formate dans l'appareil.
    private(set) var cleanup: CameraCleanup.Plan?
    private(set) var erasing = false
    private(set) var eraseOutcome: CameraCleanup.Outcome?

    /// La dernière analyse, gardée pour établir le comparatif sans relire la caméra.
    private var lastScan: CardScanner.Result?

    /// Lecture seule de la dernière analyse, pour l'affichage.
    var lastScanResult: CardScanner.Result? { lastScan }

    /// L'état, réduit à son genre — de quoi comparer sans déballer les valeurs associées.
    enum StageKind { case waiting, needsLocalNetwork, scanning, needsLibrary, ready, importing, finished, failed }

    var stageKind: StageKind {
        switch stage {
        case .waiting: .waiting
        case .needsLocalNetwork: .needsLocalNetwork
        case .scanning: .scanning
        case .needsLibrary: .needsLibrary
        case .ready: .ready
        case .importing: .importing
        case .finished: .finished
        case .failed: .failed
        }
    }

    /// Le plan en cours, gardé pour afficher la file des fichiers pendant la copie.
    private(set) var activePlan: ImportPlan?
    /// Position du fichier en cours de copie dans ce plan.
    private var copyingIndex = 0
    /// Début de l'import, pour l'estimation de durée restante.
    private(set) var importStartedAt: Date?

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
        lastScan = result
        // Sans dossier d'import, rien ne part : la carte est lue, il ne manque que la destination.
        guard let library = preferences.library else {
            stage = .needsLibrary(result)
            return
        }

        let index = ImportIndexStore.load(fromLibrary: library)
        let plan = ImportPlanner.plan(takes: result.takes, into: library,
                                      folderName: ImportFolderName.iso(for: Date()), index: index)

        // Le plan est publié dès qu'il existe, et pas seulement au démarrage de la copie : la
        // fenêtre Transfert montre la file « en attente » avant qu'on ait cliqué sur Importer.
        activePlan = plan
        copyingIndex = 0

        if preferences.askBeforeImporting || plan.isEmpty {
            // Le cas le plus fréquent une fois la carte à jour : plus rien à copier. C'est
            // justement là qu'on veut pouvoir vider la caméra, donc le comparatif doit exister
            // sans attendre un import qui n'aura pas lieu.
            if plan.isEmpty { refreshCleanup() }
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

        activePlan = plan
        copyingIndex = 0
        importStartedAt = Date()
        let flag = CancellationFlag()
        cancellation = flag
        stage = .importing(ImportProgress(fileIndex: 0, fileCount: plan.copies.count,
                                          currentFile: "", bytesCopied: 0, byteCount: plan.byteCount))

        Task.detached(priority: .userInitiated) { [self] in
            var index = ImportIndexStore.load(fromLibrary: library)
            var lastPercent = -1
            var lastFile = -1

            let report = ImportRunner.run(
                plan, library: library, index: &index,
                isCancelled: { flag.isCancelled },
                progress: { progress in
                    // La copie émet une progression par bloc de 4 Mo. Ne remonter que les
                    // changements de pourcentage évite d'inonder l'acteur principal pour des
                    // rafraîchissements que personne ne voit.
                    let percent = Int(progress.fraction * 100)
                    guard percent != lastPercent || progress.fileIndex != lastFile else { return }
                    lastPercent = percent
                    lastFile = progress.fileIndex
                    Task { @MainActor in self.advanced(progress) }
                }
            )

            try? ImportIndexStore.save(index, toLibrary: library)
            await importFinished(report)
        }
    }

    /// Le passage d'un fichier au suivant compte autant que le pourcentage : sans lui, la file
    /// afficherait le premier fichier « en cours » pendant tout un import de petits clips.
    private func advanced(_ progress: ImportProgress) {
        copyingIndex = progress.fileIndex
        stage = .importing(progress)
    }

    func cancel() {
        cancellation?.cancel()
    }

    private func importFinished(_ report: ImportReport) {
        cancellation = nil
        stage = .finished(report)
        copyingIndex = report.copied.count
        eraseOutcome = nil
        refreshCleanup()
        announce(report)
    }

    /// Le comparatif entre ce que porte la caméra et ce qui est prouvé sur le Mac.
    ///
    /// Recalculé à partir du disque à chaque fois, jamais mémorisé : c'est ce qui fait que la
    /// suppression d'un dossier derrière le dos de l'app retient l'effacement.
    private func refreshCleanup() {
        guard camera != nil, let library = preferences.library, let scan = lastScan else {
            cleanup = nil
            return
        }
        cleanup = CameraCleanup.plan(takes: scan.takes, library: library,
                                     index: ImportIndexStore.load(fromLibrary: library))
    }

    private func announce(_ report: ImportReport) {
        guard !report.copied.isEmpty || !report.failures.isEmpty else { return }
        let clips = report.copied.count == 1 ? "1 clip importé" : "\(report.copied.count) clips importés"
        var body = clips
        if report.highlightedTakeCount > 0 {
            body += report.highlightedTakeCount == 1
                ? ", 1 prise taguée" : ", \(report.highlightedTakeCount) prises taguées"
        }
        if !report.failures.isEmpty { body += " — \(report.failures.count) en échec" }
        Notifier.shared.notify(title: report.wasCancelled ? "Import interrompu" : "Import terminé",
                               body: body)
    }

    // MARK: - Effacer la caméra

    /// Efface les clips de la caméra, après confirmation explicite.
    ///
    /// Trois verrous, et aucun n'est décoratif : le bouton n'apparaît que si le comparatif est
    /// complet, cette alerte demande une confirmation nommant le décompte, et `CameraCleanup.erase`
    /// refuse de son côté tout plan qui ne serait pas vérifié. Rien dans l'app n'efface sans qu'on
    /// l'ait demandé.
    func eraseCamera() {
        guard let plan = cleanup, plan.isSafeToErase, let camera else { return }

        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Effacer \(plan.cameraCount) clip(s) de la GoPro ?"
        alert.informativeText = """
            Les \(plan.cameraCount) clips de la caméra sont tous présents sur ce Mac, vérifiés un             par un. Ils seront effacés de la carte et ne pourront pas être récupérés.
            """
        alert.addButton(withTitle: "Effacer de la GoPro")
        alert.addButton(withTitle: "Annuler")
        alert.buttons.first?.hasDestructiveAction = true
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        erasing = true
        Task.detached(priority: .userInitiated) { [self] in
            let outcome = try? CameraCleanup.erase(plan, from: camera)
            await erased(outcome)
        }
    }

    private func erased(_ outcome: CameraCleanup.Outcome?) {
        erasing = false
        eraseOutcome = outcome
        cleanup = nil
        lastScan = nil
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

// MARK: - La file des fichiers

/// Un fichier du plan, avec où il en est.
///
/// Le popover et la fenêtre Transfert affichent la même file : elle est donc calculée ici, à partir
/// du plan et de la progression, plutôt que dessinée deux fois de deux manières qui finiraient par
/// diverger.
struct QueuedFile: Identifiable, Equatable {
    let id: String
    let name: String
    let size: UInt64
    /// Nombre de tags HiLight du chapitre. Zéro pour un clip sans tag.
    let tagCount: Int
    let state: State

    enum State: Equatable {
        case pending
        case copying
        case verified
        case failed(String)

        /// Le mot affiché dans la colonne « Vérification ».
        var label: String {
            switch self {
            case .pending: "en attente"
            case .copying: "en cours"
            case .verified: "vérifié"
            case .failed(let reason): reason
            }
        }
    }
}

extension ImportModel {

    /// Les fichiers du plan en cours, ou ceux du dernier import terminé.
    var queue: [QueuedFile] {
        guard let plan = activePlan else { return [] }
        let moments = momentsByFilename
        let failures = failuresByPath

        return plan.copies.enumerated().map { position, copy in
            QueuedFile(
                id: copy.relativeDestination,
                name: copy.source.filename,
                size: copy.source.size,
                tagCount: moments[copy.source.filename] ?? 0,
                state: fileState(at: position, of: copy, failures: failures)
            )
        }
    }

    private func fileState(at position: Int, of copy: PlannedCopy,
                           failures: [URL: String]) -> QueuedFile.State {
        if let reason = failures[copy.source.url] { return .failed(reason) }
        switch stage {
        case .finished: return .verified
        case .importing:
            if position < copyingIndex { return .verified }
            return position == copyingIndex ? .copying : .pending
        default: return .pending
        }
    }

    private var failuresByPath: [URL: String] {
        guard case .finished(let report) = stage else { return [:] }
        return Dictionary(report.failures.map { ($0.source, $0.reason) },
                          uniquingKeysWith: { first, _ in first })
    }

    /// Le nombre de moments par nom de fichier, relevé pendant l'analyse.
    ///
    /// Le plan ne porte qu'un booléen « la prise est taguée » ; la pastille, elle, montre un
    /// nombre. On le retrouve dans l'analyse plutôt que de relire les clips.
    var momentsByFilename: [String: Int] {
        guard let scan = lastScanResult else { return [:] }
        var counts: [String: Int] = [:]
        for take in scan.takes {
            for chapter in take.chapters {
                counts[chapter.file.filename] = chapter.hiLight.moments.count
            }
        }
        return counts
    }
}

// MARK: - Ce que le popover affiche au repos

extension ImportModel {

    /// Le chemin du dossier d'import, raccourci avec `~`.
    var libraryDisplayPath: String {
        guard let library = preferences.library else { return "aucun" }
        return (library.path as NSString).abbreviatingWithTildeInPath
    }

    /// La date du dernier import, lue des dossiers datés de la bibliothèque.
    ///
    /// On regarde le disque plutôt que l'index : c'est ce que l'utilisateur voit dans le Finder,
    /// et un dossier supprimé à la main doit disparaître d'ici aussi.
    var lastImportDate: String? {
        guard let library = preferences.library else { return nil }
        let entries = (try? FileManager.default.contentsOfDirectory(
            atPath: library.path)) ?? []
        return entries.filter(ImportModel.isDatedFolder).max()
    }

    static func isDatedFolder(_ name: String) -> Bool {
        name.count == 10 && name.prefix(4).allSatisfy(\.isNumber)
            && Array(name)[4] == "-" && Array(name)[7] == "-"
    }
}

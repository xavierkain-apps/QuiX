import SwiftUI
import QuiXCore

/// La vue détaillée d'un import : d'où, vers où, et où en est chaque fichier.
///
/// Elle partage sa source de vérité avec la file du popover — `ImportModel.queue` — plutôt que de
/// redessiner la même chose autrement.
struct TransferWindow: View {

    let model: ImportModel
    @Environment(\.appRouter) private var router

    var body: some View {
        route.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Chaque état a sa place ici, et pas seulement les trois qui montrent une table.
    ///
    /// Le premier import a échoué sur ce point : l'app attendait qu'on lui donne un dossier, ne le
    /// disait que dans le popover, et cet onglet affichait « Aucun transfert en cours ». On
    /// cherchait la panne alors que l'app attendait une réponse.
    @ViewBuilder
    private var route: some View {
        switch model.stage {
        case .importing, .ready, .finished:
            content

        case .scanning(let done, let total):
            Waiting(title: model.camera != nil ? "Reading the camera" : "Reading the card",
                    detail: "Only the headers are read — no video is copied at this stage.",
                    pulsing: true) {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressTrack(fraction: total > 0 ? Double(done) / Double(total) : 0, height: 6)
                        .frame(width: 320)
                    Text(total > 0 ? "\(done) of \(total) clips" : "in progress…")
                        .font(Type.small).foregroundStyle(Ink.secondary)
                }
            }

        case .needsLibrary(let result):
            Waiting(title: "Card detected",
                    detail: "\(summary(of: result))\n\nAll that is left is to choose where the clips go.") {
                Button("Choose import folder…") { model.chooseLibrary() }
                    .buttonStyle(FilledBlue())
            }

        case .needsLocalNetwork:
            Waiting(title: "Permission needed",
                    detail: "Your GoPro is plugged in, but macOS is stopping QuiX from talking to it. Over USB-C the camera is a network device: QuiX has to be allowed under “Local Network”.",
                    warning: true) {
                HStack(spacing: 10) {
                    Button("Open Settings…") { model.openLocalNetworkSettings() }
                        .buttonStyle(FilledBlue())
                    Button("Check again") { model.recheckCamera() }
                        .buttonStyle(OutlinedDark())
                }
            }

        case .failed(let reason):
            Waiting(title: "Failed", detail: "\(reason)", warning: true) {
                Button("Done") { model.dismissReport() }.buttonStyle(OutlinedDark())
            }

        case .waiting:
            Waiting(title: "No card",
                    detail: "Plug the GoPro in over USB-C, or the card into a reader — the import will show up here.") {
                if model.preferences.library == nil {
                    Button("Choose import folder…") { model.chooseLibrary() }
                        .buttonStyle(FilledBlue())
                }
            }
        }
    }

    private func summary(of result: CardScanner.Result) -> String {
        let taken = result.highlightedTakes.count
        let takes = String(localized: "\(result.takes.count) takes")
        return "\(takes) — \(Bytes.short(result.totalSize))"
            + (taken > 0 ? " — " + String(localized: "\(taken) tagged") : "")
    }

    private var content: some View {
        // Le haut est fixe, la table prend ce qui reste, le pied est ancré en bas. Dans une
        // fenêtre à hauteur libre la table pouvait se contenter d'une hauteur plafonnée ; dans un
        // onglet, ça laissait un grand vide sous son en-tête.
        VStack(spacing: 0) {
            Route(model: model)
            progress
            FileTable(files: model.queue)
                // `.top` n'est pas décoratif : sans lui, une table plus courte que la place
                // disponible se centre, et son en-tête flotte au milieu du vide.
                .frame(maxHeight: .infinity, alignment: .top)
            footer
        }
    }

    // MARK: Progression

    private var progress: some View {
        HStack(spacing: 16) {
            ProgressTrack(fraction: fraction, verifying: verifying, height: 6)
            Text(verbatim: "\(Bytes.short(copiedBytes)) of \(Bytes.short(totalBytes))")
                .font(Type.body).foregroundStyle(Ink.primary.opacity(0.6))
                .fixedSize()
            if let estimate {
                Text(verbatim: estimate).font(Type.mono(12)).foregroundStyle(Ink.tertiary).fixedSize()
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 20)
    }

    /// La portion pâle : le fichier en cours d'écriture, dont l'empreinte n'est pas encore relue.
    private var verifying: Double {
        guard case .importing = model.stage, totalBytes > 0,
              let current = model.queue.first(where: { $0.state == .copying })
        else { return 0 }
        return min(0.12, Double(current.size) / Double(totalBytes))
    }

    private var fraction: Double {
        if case .importing(let progress) = model.stage { return progress.fraction }
        if case .finished = model.stage { return 1 }
        return 0
    }

    private var copiedBytes: UInt64 {
        switch model.stage {
        case .importing(let progress): progress.bytesCopied
        case .finished(let report): report.copiedBytes
        default: 0
        }
    }

    private var totalBytes: UInt64 {
        model.activePlan?.byteCount ?? copiedBytes
    }

    /// Une estimation n'a de sens que pendant la copie, et seulement si elle a commencé.
    private var estimate: String? {
        guard case .importing(let progress) = model.stage,
              progress.fraction > 0.02, let started = model.importStartedAt else { return nil }
        let elapsed = Date().timeIntervalSince(started)
        let remaining = elapsed / progress.fraction - elapsed
        guard remaining.isFinite, remaining > 0 else { return nil }
        if remaining < 60 { return "≈ \(Int(remaining)) s" }
        return "≈ \(Int((remaining / 60).rounded())) min"
    }

    // MARK: Pied

    private var footer: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("The checksum is computed while writing, then read back from the written file. The card is never modified.")
                .font(.system(size: 12)).foregroundStyle(Ink.primary.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420, alignment: .leading)
            Spacer()
            actions
        }
        .padding(.init(top: 16, leading: 28, bottom: 20, trailing: 28))
        .overlay(alignment: .top) { Rule() }
    }

    @ViewBuilder
    private var actions: some View {
        if case .importing = model.stage {
            Button("Stop") { model.cancel() }.buttonStyle(OutlinedDark())
        }
        if case .ready(_, let plan) = model.stage, !plan.isEmpty {
            Button("Import") { model.startPlannedImport() }.buttonStyle(FilledBlue())
        } else {
            erase
            Button("Open highlights") { router?.tab = .library }
                .buttonStyle(FilledBlue())
        }
    }

    /// L'effacement de la caméra, là où l'on vient de vérifier que tout est arrivé.
    ///
    /// Il existait déjà dans le popover, mais c'est ici qu'on regarde la table ligne à ligne pour
    /// s'assurer que rien ne manque — et donc ici qu'on décide de vider la carte. Les trois verrous
    /// ne changent pas : le bouton n'apparaît que si chaque fichier de la caméra est retrouvé sur
    /// le Mac, une alerte demande confirmation, et le moteur refuse tout plan non vérifié.
    @ViewBuilder
    private var erase: some View {
        if let plan = model.cleanup, plan.isSafeToErase {
            if model.erasing {
                ProgressView().controlSize(.small)
            } else {
                Button("Erase GoPro (\(plan.cameraCount))…") { model.eraseCamera() }
                    .buttonStyle(OutlinedDark())
            }
        } else if let outcome = model.eraseOutcome {
            Label("\(outcome.erased.count) erased", systemImage: "checkmark.circle")
                .font(Type.caption).foregroundStyle(Ink.secondary)
        }
    }
}

// MARK: - Le bandeau source → destination

private struct Route: View {
    let model: ImportModel

    var body: some View {
        HStack(spacing: 20) {
            SourceCard(header: "Source", title: sourceName,
                       summary: sourceSummary, path: sourcePath, highlighted: highlightedCount)
            ZStack {
                Circle().fill(Ink.blue).frame(width: 34, height: 34)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            SourceCard(header: "Destination", title: destinationName,
                       summary: "Highlights / — Clips /", path: model.libraryDisplayPath,
                       highlighted: nil)
        }
        .padding(.init(top: 28, leading: 28, bottom: 24, trailing: 28))
    }

    private var sourceName: String {
        model.cameraName ?? model.card?.lastPathComponent ?? "GOPRO"
    }

    private var sourcePath: String {
        if let camera = model.camera { return camera.baseURL.absoluteString }
        guard let card = model.card else { return "—" }
        return card.appendingPathComponent("DCIM").path
    }

    private var sourceSummary: String {
        guard let scan = model.lastScanResult else { return "—" }
        return String(localized: "\(scan.takes.count) takes") + " — \(Bytes.short(scan.totalSize))"
    }

    private var highlightedCount: Int? {
        guard let scan = model.lastScanResult, !scan.highlightedTakes.isEmpty else { return nil }
        return scan.highlightedTakes.count
    }

    private var destinationName: String {
        model.activePlan?.importFolder.lastPathComponent
            ?? ImportFolderName.iso(for: Date())
    }
}

private struct SourceCard: View {
    let header: String.LocalizationValue
    let title: String
    let summary: String
    let path: String
    let highlighted: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColumnHeader(header)
            Text(verbatim: title).font(Type.cardTitle).kerning(-0.17).lineLimit(1)
            HStack(spacing: 0) {
                Text(verbatim: summary)
                if let highlighted {
                    Text(verbatim: " — ")
                    Text("\(highlighted) tagged")
                        .foregroundStyle(Ink.blueText)
                }
            }
            .font(.system(size: 13)).foregroundStyle(Ink.secondary)
            Text(verbatim: path).font(Type.mono(11.5)).foregroundStyle(Ink.tertiary)
                .lineLimit(1).truncationMode(.head)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.init(top: 18, leading: 20, bottom: 18, trailing: 20))
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Ink.rule, lineWidth: 0.5))
    }
}

// MARK: - La table des fichiers

private struct FileTable: View {
    let files: [QueuedFile]

    private static let columns: [CGFloat?] = [24, nil, 90, 70, 100]

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(files) { file in FileRow(file: file) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.white.opacity(0.025))
        .overlay(alignment: .top) { Rule() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            // La hauteur compte autant que la largeur : une `Color` sans hauteur imposée
            // s'étire, et c'est tout l'en-tête qui part occuper la fenêtre.
            Color.clear.frame(width: 24, height: 12)
            ColumnHeader("File").frame(maxWidth: .infinity, alignment: .leading)
            ColumnHeader("Size").frame(width: 90, alignment: .leading)
            ColumnHeader("Tags").frame(width: 70, alignment: .leading)
            ColumnHeader("Verification").frame(width: 100, alignment: .trailing)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rule() }
    }
}

private struct FileRow: View {
    let file: QueuedFile
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 12) {
            state.frame(width: 24, alignment: .leading)
            Text(verbatim: file.name).font(Type.mono(12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(verbatim: Bytes.short(file.size)).font(.system(size: 13))
                .foregroundStyle(Ink.secondary).frame(width: 90, alignment: .leading)
            TagBadge(count: file.tagCount, style: .light).frame(width: 70, alignment: .leading)
            Text(verbatim: file.state.label).font(.system(size: 12))
                .foregroundStyle(isFailed ? .orange : Ink.primary.opacity(0.45))
                .lineLimit(1)
                .frame(width: 100, alignment: .trailing)
        }
        .foregroundStyle(isFailed ? .orange : Ink.primary)
        .padding(.horizontal, 28)
        .padding(.vertical, 11)
        .background(hovered ? Ink.titleBar : .clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.05)).frame(height: 0.5) }
        .onHover { hovered = $0 }
    }

    private var isFailed: Bool { if case .failed = file.state { true } else { false } }

    /// La pastille de gauche dit l'état sans qu'on ait à lire la colonne de droite.
    @ViewBuilder
    private var state: some View {
        switch file.state {
        case .verified: Circle().fill(Ink.blue).frame(width: 7, height: 7)
        case .copying: PulsingDot()
        case .failed: Circle().fill(Color.orange).frame(width: 7, height: 7)
        case .pending: Circle().fill(Color.white.opacity(0.22)).frame(width: 7, height: 7)
        }
    }
}

/// Un état qui attend quelque chose : une lecture en cours, une réponse de l'utilisateur, une
/// autorisation. Toujours un titre, une raison, et de quoi agir quand il y a à agir.
struct Waiting<Action: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var pulsing = false
    var warning = false
    @ViewBuilder let action: Action

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 9) {
                if pulsing { PulsingDot() }
                Text(title).font(Type.section)
                    .foregroundStyle(warning ? Color.orange : Ink.primary)
            }
            Text(detail)
                .font(Type.small).foregroundStyle(Ink.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)
            action
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Ce qu'une fenêtre montre quand elle n'a rien à montrer.
struct Placeholder: View {
    let text: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            Text(text).font(Type.section)
            Text(detail).font(Type.small).foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

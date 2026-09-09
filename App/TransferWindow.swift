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

    @ViewBuilder
    private var route: some View {
        switch model.stage {
        case .importing, .ready, .finished:
            content
        default:
            Placeholder(text: "Aucun transfert en cours.",
                        detail: "Branchez la GoPro ou la carte : l'import s'affichera ici.")
        }
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
            Text("\(Bytes.short(copiedBytes)) sur \(Bytes.short(totalBytes))")
                .font(Type.body).foregroundStyle(Ink.primary.opacity(0.6))
                .fixedSize()
            if let estimate {
                Text(estimate).font(Type.mono(12)).foregroundStyle(Ink.tertiary).fixedSize()
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
            Text("Empreinte calculée pendant l'écriture puis relue sur le fichier écrit. "
                 + "La carte n'est jamais modifiée.")
                .font(.system(size: 12)).foregroundStyle(Ink.primary.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 480, alignment: .leading)
            Spacer()
            if case .importing = model.stage {
                Button("Arrêter") { model.cancel() }.buttonStyle(OutlinedDark())
            }
            if case .ready(_, let plan) = model.stage, !plan.isEmpty {
                Button("Importer") { model.startPlannedImport() }.buttonStyle(FilledBlue())
            } else {
                Button("Ouvrir les highlights") { router?.tab = .library }
                    .buttonStyle(FilledBlue())
            }
        }
        .padding(.init(top: 16, leading: 28, bottom: 20, trailing: 28))
        .overlay(alignment: .top) { Rule() }
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
        let plural = scan.takes.count == 1 ? "prise" : "prises"
        return "\(scan.takes.count) \(plural) — \(Bytes.short(scan.totalSize))"
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
    let header: String
    let title: String
    let summary: String
    let path: String
    let highlighted: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColumnHeader(header)
            Text(title).font(Type.cardTitle).kerning(-0.17).lineLimit(1)
            HStack(spacing: 0) {
                Text(summary)
                if let highlighted {
                    Text(" — ")
                    Text("\(highlighted) taguée\(highlighted == 1 ? "" : "s")")
                        .foregroundStyle(Ink.blueText)
                }
            }
            .font(.system(size: 13)).foregroundStyle(Ink.secondary)
            Text(path).font(Type.mono(11.5)).foregroundStyle(Ink.tertiary)
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
            ColumnHeader("Fichier").frame(maxWidth: .infinity, alignment: .leading)
            ColumnHeader("Taille").frame(width: 90, alignment: .leading)
            ColumnHeader("Tags").frame(width: 70, alignment: .leading)
            ColumnHeader("Vérification").frame(width: 100, alignment: .trailing)
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
            Text(file.name).font(Type.mono(12.5))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Bytes.short(file.size)).font(.system(size: 13))
                .foregroundStyle(Ink.secondary).frame(width: 90, alignment: .leading)
            TagBadge(count: file.tagCount, style: .light).frame(width: 70, alignment: .leading)
            Text(file.state.label).font(.system(size: 12))
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

/// Ce qu'une fenêtre montre quand elle n'a rien à montrer.
struct Placeholder: View {
    let text: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(text).font(Type.section)
            Text(detail).font(Type.small).foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
}

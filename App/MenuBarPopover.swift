import SwiftUI
import QuiXCore

/// Le popover de la barre de menus : le lieu par défaut de l'app.
///
/// Il suit `ImportModel.Stage` — un état, une mise en page — et ne montre jamais plus que ce que
/// l'état permet de dire. Largeur fixe de 300 pt, hauteur selon le contenu.
struct MenuBarPopover: View {

    let model: ImportModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch model.stage {
            case .waiting: idle
            case .needsLocalNetwork: permission
            case .scanning(let done, let total): scanning(done: done, total: total)
            case .needsLibrary: needsLibrary
            case .ready(let result, let plan): ready(result, plan)
            case .importing(let progress): importing(progress)
            case .finished(let report): finished(report)
            case .failed(let reason): failed(reason)
            }
        }
        .frame(width: Metrics.popoverWidth)
        .background(Ink.popover)
        .background(.ultraThinMaterial)
        .foregroundStyle(Ink.primary)
    }

    // MARK: 1 — Au repos

    private var idle: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(model.cameraName ?? "Aucune carte").font(Type.section)
                Text("Branchez la carte, l'import démarre tout seul.")
                    .font(Type.small).foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rule()
            VStack(alignment: .leading, spacing: 8) {
                KeyValue("Dernier import", value: model.lastImportDate ?? "aucun")
                if model.preferences.library == nil {
                    Button("Choisir le dossier d'import…") { model.chooseLibrary() }
                        .buttonStyle(FilledBlue(fullWidth: true))
                } else {
                    KeyValue("Dossier", value: model.libraryDisplayPath)
                }
            }
            settings
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: L'autorisation manquante

    private var permission: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Autorisation requise").font(Type.section).foregroundStyle(.orange)
            Text("Votre GoPro est branchée, mais macOS empêche QuiX de lui parler. "
                 + "Il faut l'autoriser dans « Réseau local ».")
                .font(Type.small).foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir les Réglages…") { model.openLocalNetworkSettings() }
                .buttonStyle(FilledBlue(fullWidth: true))
            Button("Revérifier") { model.recheckCamera() }
                .buttonStyle(OutlinedDark(fullWidth: true))
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: 2 — Lecture de la carte

    private func scanning(done: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                PulsingDot()
                Text(model.camera != nil ? "Lecture de la caméra" : "Lecture de la carte")
                    .font(Type.section)
            }
            ScanBars(done: done, total: total)
            HStack {
                Text(total > 0 ? "\(done) clips sur \(total)" : "en cours")
                Spacer()
                Text("en-têtes seuls")
            }
            .font(Type.small).foregroundStyle(Ink.secondary)
            Text("Aucune vidéo n'est copiée à ce stade.")
                .font(Type.caption).foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: Le dossier manque

    private var needsLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Carte détectée").font(Type.section)
            Text("Il reste à choisir où ranger les clips.")
                .font(Type.small).foregroundStyle(Ink.secondary)
            Button("Choisir le dossier d'import…") { model.chooseLibrary() }
                .buttonStyle(FilledBlue(fullWidth: true))
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: L'import attend un clic

    private func ready(_ result: CardScanner.Result, _ plan: ImportPlan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.cameraName ?? "Carte GoPro").font(Type.section)
                Text(summary(of: result)).font(Type.small).foregroundStyle(Ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if plan.isEmpty {
                Text("Tout est déjà importé. Rien à copier.")
                    .font(Type.small).foregroundStyle(Ink.secondary)
                if let cleanup = model.cleanup, cleanup.isSafeToErase {
                    Button("Effacer les clips de la GoPro…") { model.eraseCamera() }
                        .buttonStyle(OutlinedDark(fullWidth: true))
                }
            } else {
                Text("\(plan.copies.count) fichier(s) — \(Bytes.short(plan.byteCount))")
                    .font(Type.small).foregroundStyle(Ink.secondary)
                Button("Importer") {
                    model.startPlannedImport()
                    openWindow(id: WindowID.transfer)
                }
                .buttonStyle(FilledBlue(fullWidth: true))
            }
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: 3 — Import

    private func importing(_ progress: ImportProgress) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Import").font(Type.section)
                    Spacer()
                    Text("\(Bytes.short(progress.bytesCopied)) / \(Bytes.short(progress.byteCount))")
                        .font(Type.mono(11.5)).foregroundStyle(Ink.secondary)
                }
                ProgressTrack(fraction: progress.fraction, height: 3)
            }
            .padding(.init(top: 20, leading: 18, bottom: 16, trailing: 18))

            VStack(spacing: 0) {
                ForEach(model.queue.prefix(6)) { file in
                    QueueRow(file: file)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            Rule()
            Button("Arrêter") { model.cancel() }
                .buttonStyle(OutlinedDark(fullWidth: true))
                .padding(.init(top: 12, leading: 16, bottom: 14, trailing: 16))
        }
    }

    // MARK: 4 — Terminé

    private func finished(_ report: ImportReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(report.wasCancelled ? "Import interrompu" : "Import terminé")
                    .font(Type.section)
                Text("\(report.copied.count) fichiers — \(Bytes.short(report.copiedBytes)) — vérifiés")
                    .font(Type.small).foregroundStyle(Ink.secondary)
            }

            HStack(spacing: 8) {
                Tally(number: report.highlightedTakeCount, label: "Highlights", accent: true)
                Tally(number: takeCount(report) - report.highlightedTakeCount, label: "Clips")
            }

            Button("Ouvrir les highlights") { openWindow(id: WindowID.library) }
                .buttonStyle(FilledBlue(fullWidth: true))

            if let cleanup = model.cleanup, cleanup.isSafeToErase {
                Button("Effacer les clips de la GoPro…") { model.eraseCamera() }
                    .buttonStyle(OutlinedDark(fullWidth: true))
            }

            Text("La carte n'a pas été modifiée.")
                .font(Type.caption).foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: L'échec

    private func failed(_ reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Échec").font(Type.section)
            Text(reason).font(Type.small).foregroundStyle(Ink.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Terminer") { model.dismissReport() }
                .buttonStyle(OutlinedDark(fullWidth: true))
        }
        .padding(.init(top: 22, leading: 18, bottom: 16, trailing: 18))
    }

    // MARK: Pied commun

    private var settings: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rule()
            Toggle("Demander confirmation", isOn: Binding(
                get: { model.preferences.askBeforeImporting },
                set: { model.preferences.askBeforeImporting = $0 }))
            Toggle("Ouvrir au branchement", isOn: Binding(
                get: { model.preferences.launchOnCameraConnection },
                set: { model.preferences.launchOnCameraConnection = $0 }))
            HStack(spacing: 10) {
                Button("Bibliothèque…") { openWindow(id: WindowID.library) }
                Spacer()
                Button("Quitter") { NSApp.terminate(nil) }
            }
            .buttonStyle(.link)
            .font(Type.caption)
            .padding(.top, 2)
        }
        .font(Type.caption)
        .toggleStyle(.checkbox)
        .foregroundStyle(Ink.secondary)
    }

    private func takeCount(_ report: ImportReport) -> Int {
        Set(report.copied.map(\.takeNumber)).count
    }

    private func summary(of result: CardScanner.Result) -> String {
        let taken = result.highlightedTakes.count
        let plural = result.takes.count == 1 ? "prise" : "prises"
        return "\(result.takes.count) \(plural) — \(Bytes.short(result.totalSize))"
            + (taken > 0 ? " — \(taken) taguée\(taken == 1 ? "" : "s")" : "")
    }
}

// MARK: - Petites pièces

/// Séparateur de 0,5 pt, à la valeur du handoff.
struct Rule: View {
    var body: some View { Rectangle().fill(Ink.hairline).frame(height: 0.5) }
}

private struct KeyValue: View {
    let key: String
    let value: String
    init(_ key: String, value: String) { self.key = key; self.value = value }

    var body: some View {
        HStack {
            Text(key)
            Spacer()
            Text(value).font(Type.mono(12.5)).foregroundStyle(Ink.primary.opacity(0.8))
                .lineLimit(1).truncationMode(.head)
        }
        .font(Type.small).foregroundStyle(Ink.secondary)
    }
}

/// Les quatorze barres de la lecture de carte.
///
/// Décoratives : leurs hauteurs sont fixes et ne représentent aucune forme d'onde. Seule leur
/// couleur porte une information — bleu pour ce qui est déjà lu.
private struct ScanBars: View {
    let done: Int
    let total: Int

    private static let heights: [CGFloat] = [12, 20, 9, 26, 15, 22, 11, 24, 17, 13, 25, 10, 19, 14]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(Self.heights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 1)
                    .fill(isRead(index) ? Ink.blue : Color.white.opacity(0.16))
                    .frame(height: height)
            }
        }
        .frame(height: 26)
    }

    private func isRead(_ index: Int) -> Bool {
        guard total > 0 else { return false }
        return Double(index) / Double(Self.heights.count) < Double(done) / Double(total)
    }
}

/// La barre de progression, à un ou deux tons.
struct ProgressTrack: View {
    let fraction: Double
    var verifying: Double = 0
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Ink.rule)
                HStack(spacing: 0) {
                    Capsule().fill(Ink.blue)
                        .frame(width: geometry.size.width * min(1, max(0, fraction)))
                    if verifying > 0 {
                        Rectangle().fill(Ink.blueVerifying)
                            .frame(width: geometry.size.width * verifying)
                    }
                }
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

/// Une ligne de la file, dans le popover.
private struct QueueRow: View {
    let file: QueuedFile
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 10) {
            Text(file.name).font(Type.mono(12.5)).foregroundStyle(Ink.primary.opacity(0.85))
            Spacer(minLength: 4)
            // La cellule est toujours réservée, même vide : sans ça les tailles danseraient d'une
            // ligne à l'autre selon qu'un clip est tagué ou non.
            TagBadge(count: file.tagCount, style: .solid)
            Text(Bytes.short(file.size))
                .font(Type.caption).foregroundStyle(Ink.tertiary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(hovered ? Ink.hover : .clear, in: RoundedRectangle(cornerRadius: 8))
        .onHover { hovered = $0 }
    }
}

/// La pastille « nombre de tags ». Deux habillages selon le fond.
struct TagBadge: View {
    let count: Int
    var style: Style = .solid

    enum Style { case solid, light, badge }

    var body: some View {
        Group {
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: style == .solid ? 10.5 : 11, weight: .medium))
                    .foregroundStyle(style == .solid ? Color.white : Ink.onLight)
                    .padding(.horizontal, style == .solid ? 6 : 7)
                    .padding(.vertical, 1)
                    .background(background, in: RoundedRectangle(cornerRadius: style == .solid ? 4 : 5))
            } else {
                Color.clear.frame(width: 0, height: 14)
            }
        }
    }

    private var background: Color {
        switch style {
        case .solid: Ink.blue
        case .light: Ink.blueLight
        case .badge: Ink.blueBadge
        }
    }
}

/// Une tuile de bilan : un grand nombre, un libellé.
private struct Tally: View {
    let number: Int
    let label: String
    var accent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(number)").font(Type.figure)
                .foregroundStyle(accent ? Ink.blueBadge : Ink.primary)
            Text(label).font(Type.caption).foregroundStyle(Ink.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.init(top: 12, leading: 12, bottom: 10, trailing: 12))
        .background(Ink.hover, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

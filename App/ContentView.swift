import SwiftUI
import QuiXCore

struct ContentView: View {

    let model: ImportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            stageView
            Spacer(minLength: 0)
            Divider()
            Footer(preferences: model.preferences, chooseLibrary: model.chooseLibrary)
        }
        .padding(24)
        .frame(minWidth: 460, minHeight: 320)
    }

    // MARK: - L'état courant

    @ViewBuilder
    private var stageView: some View {
        switch model.stage {

        case .waiting:
            Message(title: "Branchez la carte GoPro",
                    detail: model.preferences.library == nil
                        ? "Choisissez d'abord où ranger les clips."
                        : "L'import démarrera tout seul.",
                    symbol: "sdcard")

        case .scanning(let done, let total):
            VStack(alignment: .leading, spacing: 12) {
                Text("Lecture de la carte").font(.title2)
                if total > 0 {
                    ProgressView(value: Double(done), total: Double(total))
                    Text("\(done) clip(s) sur \(total)").foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
                Text("Seuls les en-têtes sont lus : aucune vidéo n'est copiée à ce stade.")
                    .font(.callout).foregroundStyle(.secondary)
            }

        case .needsLibrary(let result):
            VStack(alignment: .leading, spacing: 12) {
                Text("Carte GoPro détectée").font(.title2)
                Text(summary(of: result))
                Text("Il reste à choisir où ranger les clips.").foregroundStyle(.secondary)
                Button("Choisir le dossier d'import…") { model.chooseLibrary() }
                    .keyboardShortcut(.defaultAction)
            }

        case .ready(let result, let plan):
            VStack(alignment: .leading, spacing: 12) {
                Text("Carte GoPro détectée").font(.title2)
                Text(summary(of: result))
                if plan.isEmpty {
                    Text("Tout est déjà importé. Rien à copier.").foregroundStyle(.secondary)
                } else {
                    Text("\(plan.copies.count) fichier(s) à copier — \(bytes(plan.byteCount))")
                        .foregroundStyle(.secondary)
                    Text("Destination : \(plan.importFolder.lastPathComponent)")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Importer") { model.startPlannedImport() }
                        .keyboardShortcut(.defaultAction)
                }
            }

        case .importing(let progress):
            VStack(alignment: .leading, spacing: 12) {
                Text("Import en cours").font(.title2)
                ProgressView(value: progress.fraction)
                Text("\(bytes(progress.bytesCopied)) sur \(bytes(progress.byteCount))")
                    .foregroundStyle(.secondary)
                if !progress.currentFile.isEmpty {
                    Text(progress.currentFile).font(.callout).monospaced().foregroundStyle(.secondary)
                }
                Button("Arrêter", role: .cancel) { model.cancel() }
            }

        case .finished(let report):
            VStack(alignment: .leading, spacing: 12) {
                Text(report.wasCancelled ? "Import interrompu" : "Import terminé").font(.title2)
                Text("\(report.copied.count) fichier(s) copié(s) — \(bytes(report.copiedBytes))")
                if report.highlightedTakeCount > 0 {
                    Text("\(report.highlightedTakeCount) prise(s) taguée(s) dans Highlights")
                        .foregroundStyle(.secondary)
                }
                if !report.alreadyImported.isEmpty {
                    Text("\(report.alreadyImported.count) déjà importé(s), ignoré(s)")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(report.failures, id: \.source) { failure in
                    Label("\(failure.source.lastPathComponent) — \(failure.reason)",
                          systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                }
                HStack {
                    Button("Ouvrir les highlights") { model.revealHighlights() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(report.copied.isEmpty)
                    Button("Terminer") { model.dismissReport() }
                }
                Text("La carte n'a pas été modifiée. L'effacement reste une action manuelle, dans la caméra.")
                    .font(.callout).foregroundStyle(.secondary)
            }

        case .failed(let reason):
            Message(title: "Échec", detail: reason, symbol: "exclamationmark.triangle")
        }
    }

    // MARK: - Formatage

    private func summary(of result: CardScanner.Result) -> String {
        let takes = result.takes.count
        let tagged = result.highlightedTakes.count
        return "\(takes) prise(s), dont \(tagged) taguée(s) — \(bytes(result.totalSize))"
    }

    private func bytes(_ count: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(count), countStyle: .file)
    }
}

private struct Message: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 30)).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title2)
                Text(detail).foregroundStyle(.secondary)
            }
        }
    }
}


/// Réglages et mise en garde, au pied de la fenêtre.
private struct Footer: View {

    @Bindable var preferences: Preferences
    let chooseLibrary: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Dossier d'import :").foregroundStyle(.secondary)
                Text(preferences.library?.path ?? "aucun")
                    .lineLimit(1).truncationMode(.head)
                Spacer()
                Button(preferences.library == nil ? "Choisir…" : "Modifier…", action: chooseLibrary)
            }
            .font(.callout)

            Toggle("Demander confirmation avant d'importer", isOn: $preferences.askBeforeImporting)
                .font(.callout)

            // Ce n'est pas un bug à corriger, c'est une limite du format : les highlights posés
            // après coup dans l'app mobile Quik ne sont jamais réécrits dans le MP4. Le dire ici
            // évite de chercher longtemps pourquoi une prise manque à l'appel.
            Text("Seuls les highlights posés pendant le tournage — bouton ou commande vocale — sont "
                 + "inscrits dans le fichier. Ceux ajoutés après coup dans l'app Quik restent dans l'app.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

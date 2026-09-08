import AppKit
import SwiftUI
import QuiXCore

/// Le comparatif caméra ↔ Mac, et l'effacement qu'il autorise ou retient.
///
/// Le décompte est montré **avant** le bouton, et non en petit à côté : c'est lui qui justifie
/// qu'on propose une opération irréversible. Quand il ne tombe pas juste, le bouton n'est pas
/// grisé — il n'est pas là du tout, et la raison est nommée.
private struct CameraBalance: View {

    let plan: CameraCleanup.Plan
    let erasing: Bool
    let erase: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sur la GoPro").font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                GridRow {
                    Text("Clips sur la caméra").foregroundStyle(.secondary)
                    Text("\(plan.cameraCount)").monospacedDigit()
                }
                GridRow {
                    Text("Vérifiés sur ce Mac").foregroundStyle(.secondary)
                    Text("\(plan.verifiedCount)").monospacedDigit()
                        .foregroundStyle(plan.isSafeToErase ? Color.primary : Color.orange)
                }
            }
            .font(.callout)

            if plan.isSafeToErase {
                Text("Chaque clip de la caméra a été retrouvé sur ce Mac, à la bonne taille.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if erasing {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Effacer les clips de la GoPro…", role: .destructive, action: erase)
                }
            } else {
                Label("\(plan.unverified.count) clip(s) ne sont pas confirmés sur ce Mac.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
                Text("L'effacement n'est pas proposé tant qu'il en manque un seul.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

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
        // L'agent a pu être désactivé depuis les Réglages Système pendant qu'on regardait
        // ailleurs. On relit son état réel au retour, plutôt que d'afficher ce qu'on croyait.
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            model.preferences.refreshLaunchAgentState()
        }
    }

    // MARK: - L'état courant

    @ViewBuilder
    private var stageView: some View {
        switch model.stage {

        case .waiting:
            Message(title: "Branchez la GoPro",
                    detail: model.preferences.library == nil
                        ? "Choisissez d'abord où ranger les clips."
                        : "Par le câble USB-C ou la carte dans un lecteur. L'import démarrera tout seul.",
                    symbol: "sdcard")

        case .needsLocalNetwork:
            // Le seul état où l'app est bloquée par une autorisation. Il est explicite plutôt que
            // silencieux : sans ça, une caméra branchée et une permission refusée se ressemblent
            // exactement — l'app a l'air de ne rien voir.
            VStack(alignment: .leading, spacing: 12) {
                Label("Autorisation requise", systemImage: "exclamationmark.triangle.fill")
                    .font(.title2).foregroundStyle(.orange)
                Text("Votre GoPro est branchée, mais macOS empêche QuiX de lui parler.")
                Text("Branchée en USB-C, la caméra se présente comme un périphérique réseau. "
                     + "Il faut donc autoriser QuiX dans « Réseau local ».")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Ouvrir les Réglages…") { model.openLocalNetworkSettings() }
                        .keyboardShortcut(.defaultAction)
                    Button("Revérifier") { model.recheckCamera() }
                }
                Text("Réglages Système → Confidentialité et sécurité → Réseau local → activer QuiX.")
                    .font(.caption).foregroundStyle(.secondary)
            }

        case .scanning(let done, let total):
            VStack(alignment: .leading, spacing: 12) {
                Text(model.camera != nil ? "Lecture de la caméra" : "Lecture de la carte")
                    .font(.title2)
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
                Text(model.cameraName ?? "Carte GoPro détectée").font(.title2)
                Text(summary(of: result))
                Text("Il reste à choisir où ranger les clips.").foregroundStyle(.secondary)
                Button("Choisir le dossier d'import…") { model.chooseLibrary() }
                    .keyboardShortcut(.defaultAction)
            }

        case .ready(let result, let plan):
            VStack(alignment: .leading, spacing: 12) {
                Text(model.cameraName ?? "Carte GoPro détectée").font(.title2)
                Text(summary(of: result))
                if plan.isEmpty {
                    Text("Tout est déjà importé. Rien à copier.").foregroundStyle(.secondary)
                    if let cleanup = model.cleanup {
                        Divider()
                        CameraBalance(plan: cleanup, erasing: model.erasing,
                                      erase: model.eraseCamera)
                    }
                    if let outcome = model.eraseOutcome {
                        Label("\(outcome.erased.count) clip(s) effacé(s) de la GoPro",
                              systemImage: "checkmark.circle").foregroundStyle(.secondary)
                    }
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

                if let outcome = model.eraseOutcome {
                    Divider()
                    Label("\(outcome.erased.count) clip(s) effacé(s) de la GoPro",
                          systemImage: "checkmark.circle")
                        .foregroundStyle(.secondary)
                    if !outcome.failed.isEmpty {
                        Text("\(outcome.failed.count) n'ont pas pu être effacés — ils sont toujours sur la carte.")
                            .font(.callout).foregroundStyle(.orange)
                    }
                } else if let plan = model.cleanup {
                    Divider()
                    CameraBalance(plan: plan, erasing: model.erasing, erase: model.eraseCamera)
                } else {
                    Text("La carte n'a pas été modifiée.")
                        .font(.callout).foregroundStyle(.secondary)
                }
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

            Toggle("Ouvrir QuiX quand la GoPro est branchée", isOn: $preferences.launchOnCameraConnection)
                .font(.callout)

            if preferences.launchOnCameraConnection {
                Text("QuiX ne tourne pas en attendant : c'est macOS qui le réveille au branchement.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Ce n'est pas un bug à corriger, c'est une limite du format : les highlights posés
            // après coup dans l'app mobile Quik ne sont jamais réécrits dans le MP4. Le dire ici
            // évite de chercher longtemps pourquoi une prise manque à l'appel.
            Text("Seuls les highlights posés pendant le tournage — bouton ou commande vocale — sont "
                 + "inscrits dans le fichier. Ceux ajoutés après coup dans l'app Quik restent dans l'app.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

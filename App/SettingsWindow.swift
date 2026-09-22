import SwiftUI

/// Les réglages, rassemblés.
///
/// Ils vivaient au pied du popover, qui n'est pas fait pour ça : on y venait pour savoir où en est
/// l'import, pas pour cocher des cases. Fenêtre séparée, ouverte par ⌘, comme partout sur macOS.
///
/// Elle montre aussi l'**état des autorisations**, ce qu'aucun autre écran ne fait. Les deux que
/// QuiX demande échouent de la même façon trompeuse — l'app voit le matériel et ne trouve rien —
/// et un endroit où lire « accordée » ou « manquante » évite de chercher longtemps.
struct SettingsWindow: View {

    let model: ImportModel
    @State private var networkGranted: Bool?
    @State private var language = AppLanguage.current
    @State private var pendingLanguage: AppLanguage?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Clé distincte : « Import » le titre de section et « Import » le bouton se
            // traduisent différemment en français — « Import » et « Importer ».
            Section("settings.section.import") {
                Row("Import folder", detail: model.libraryDisplayPath) {
                    Button(model.preferences.library == nil ? "Choose…" : "Change…") {
                        model.chooseLibrary()
                    }
                    .buttonStyle(OutlinedDark())
                }
                Toggle("Ask before importing", isOn: Binding(
                    get: { model.preferences.askBeforeImporting },
                    set: { model.preferences.askBeforeImporting = $0 }))
                Note("Without confirmation, plugging the card in starts the copy right away. The guard that matters is elsewhere: a card with no DCIM/###GOPRO folder is never touched, setting or no setting.")
            }

            Divider().overlay(Ink.hairline)

            Section("Language") {
                Picker("", selection: Binding(get: { language }, set: { choose($0) })) {
                    ForEach(AppLanguage.allCases) { option in
                        Text(verbatim: option.label).tag(option)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                Note("Automatic follows the Mac. Choosing a language restarts QuiX — macOS only reads it at launch.")
            }

            Divider().overlay(Ink.hairline)

            Section("Connection") {
                Toggle("Open QuiX when the GoPro is plugged in", isOn: Binding(
                    get: { model.preferences.launchOnCameraConnection },
                    set: { model.preferences.launchOnCameraConnection = $0 }))
                Note("QuiX is not running in the meantime — macOS wakes it when the camera arrives. The match only recognises the HERO12 Black.")
            }

            Divider().overlay(Ink.hairline)

            Section("Permissions") {
                Permission(name: "Local Network",
                           granted: networkGranted,
                           why: "Over USB-C the camera is a network device as far as macOS is concerned.",
                           open: model.openLocalNetworkSettings)
                Permission(name: "Removable Volumes",
                           granted: nil,
                           why: "To read a card in a reader. macOS asks the first time one is inserted; without it, the card looks empty.",
                           open: nil)
            }
        }
        .frame(width: 520, alignment: .leading)
        .background(Ink.window)
        .foregroundStyle(Ink.primary)
        .toggleStyle(.checkbox)
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
        .alert("Restart QuiX?", isPresented: Binding(
            get: { pendingLanguage != nil },
            set: { if !$0 { pendingLanguage = nil } })) {
            Button("Restart") {
                if let pendingLanguage { AppLanguage.store(pendingLanguage) }
                AppLanguage.restart()
            }
            Button("Cancel", role: .cancel) {
                // Le segment a déjà bougé : on le remet là où il était.
                language = AppLanguage.current
                pendingLanguage = nil
            }
        } message: {
            Text("The interface language is read once, when the app starts.")
        }
    }

    /// Un changement de langue ne s'applique qu'au lancement suivant : on le dit, et on propose
    /// de relancer tout de suite plutôt que de laisser l'utilisateur se demander si ça a marché.
    private func choose(_ new: AppLanguage) {
        language = new
        guard new != AppLanguage.current else { return }
        pendingLanguage = new
    }

    /// L'état de l'autorisation réseau se déduit de ce que la caméra répond, faute d'API pour
    /// l'interroger : « manquante » n'est affirmé que si une caméra est branchée et refuse.
    private func refresh() {
        model.recheckCamera()
        networkGranted = model.stageKind == .needsLocalNetwork ? false
            : (model.camera != nil ? true : nil)
    }

    // MARK: Petites pièces

    private struct Section<Content: View>: View {
        let title: String.LocalizationValue
        @ViewBuilder let content: Content
        init(_ title: String.LocalizationValue, @ViewBuilder content: () -> Content) {
            self.title = title
            self.content = content()
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                ColumnHeader(title)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private struct Row<Trailing: View>: View {
        let title: LocalizedStringKey
        let detail: String
        @ViewBuilder let trailing: Trailing
        init(_ title: LocalizedStringKey, detail: String, @ViewBuilder trailing: () -> Trailing) {
            self.title = title
            self.detail = detail
            self.trailing = trailing()
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Type.body)
                    Text(verbatim: detail).font(Type.mono(12)).foregroundStyle(Ink.tertiary)
                        .lineLimit(1).truncationMode(.head)
                }
                Spacer()
                trailing
            }
        }
    }

    private struct Note: View {
        let text: LocalizedStringKey
        init(_ text: LocalizedStringKey) { self.text = text }
        var body: some View {
            Text(text).font(Type.caption).foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct Permission: View {
        let name: LocalizedStringKey
        /// `nil` quand rien ne permet de trancher — ce qui est le cas le plus fréquent.
        let granted: Bool?
        let why: LocalizedStringKey
        let open: (() -> Void)?

        var body: some View {
            HStack(alignment: .top, spacing: 10) {
                Circle().fill(colour).frame(width: 7, height: 7).padding(.top, 5)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(name).font(Type.body)
                        Text(status).font(Type.caption).foregroundStyle(Ink.tertiary)
                    }
                    Text(why).font(Type.caption).foregroundStyle(Ink.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if let open {
                    Button("Settings…", action: open).buttonStyle(OutlinedDark())
                }
            }
        }

        private var colour: Color {
            switch granted {
            case true: Ink.blue
            case false: .orange
            case nil: Color.white.opacity(0.22)
            }
        }

        private var status: LocalizedStringKey {
            switch granted {
            case true: "granted"
            case false: "missing"
            case nil: "asked when needed"
            }
        }
    }
}

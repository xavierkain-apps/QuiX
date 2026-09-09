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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Section("Import") {
                Row("Dossier d'import", detail: model.libraryDisplayPath) {
                    Button(model.preferences.library == nil ? "Choisir…" : "Modifier…") {
                        model.chooseLibrary()
                    }
                    .buttonStyle(OutlinedDark())
                }
                Toggle("Demander confirmation avant d'importer", isOn: Binding(
                    get: { model.preferences.askBeforeImporting },
                    set: { model.preferences.askBeforeImporting = $0 }))
                Note("Sans confirmation, brancher la carte lance la copie tout de suite. "
                     + "La garde qui compte est ailleurs : une carte sans dossier DCIM/###GOPRO "
                     + "n'est jamais touchée, réglage ou pas.")
            }

            Divider().overlay(Ink.hairline)

            Section("Branchement") {
                Toggle("Ouvrir QuiX quand la GoPro est branchée", isOn: Binding(
                    get: { model.preferences.launchOnCameraConnection },
                    set: { model.preferences.launchOnCameraConnection = $0 }))
                Note("QuiX ne tourne pas en attendant : c'est macOS qui le réveille au "
                     + "branchement. L'appariement ne reconnaît que la HERO12 Black.")
            }

            Divider().overlay(Ink.hairline)

            Section("Autorisations") {
                Permission(name: "Réseau local",
                           granted: networkGranted,
                           why: "Branchée en USB-C, la caméra est un périphérique réseau pour macOS.",
                           open: model.openLocalNetworkSettings)
                Permission(name: "Volumes amovibles",
                           granted: nil,
                           why: "Pour lire une carte insérée dans un lecteur. macOS la demande au "
                                + "premier branchement ; sans elle, la carte paraît vide.",
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
        let title: String
        @ViewBuilder let content: Content
        init(_ title: String, @ViewBuilder content: () -> Content) {
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
        let title: String
        let detail: String
        @ViewBuilder let trailing: Trailing
        init(_ title: String, detail: String, @ViewBuilder trailing: () -> Trailing) {
            self.title = title
            self.detail = detail
            self.trailing = trailing()
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Type.body)
                    Text(detail).font(Type.mono(12)).foregroundStyle(Ink.tertiary)
                        .lineLimit(1).truncationMode(.head)
                }
                Spacer()
                trailing
            }
        }
    }

    private struct Note: View {
        let text: String
        init(_ text: String) { self.text = text }
        var body: some View {
            Text(text).font(Type.caption).foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private struct Permission: View {
        let name: String
        /// `nil` quand rien ne permet de trancher — ce qui est le cas le plus fréquent.
        let granted: Bool?
        let why: String
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
                    Button("Réglages…", action: open).buttonStyle(OutlinedDark())
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

        private var status: String {
            switch granted {
            case true: "accordée"
            case false: "manquante"
            case nil: "demandée au besoin"
            }
        }
    }
}

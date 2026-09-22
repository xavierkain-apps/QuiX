import AppKit
import SwiftUI
import UserNotifications

/// Ce qu'on montre au tout premier lancement, et une seule fois.
///
/// QuiX a besoin de deux choses avant de servir à quoi que ce soit : savoir où ranger les clips,
/// et avoir le droit de parler à la caméra. Les deux se découvraient jusqu'ici en panne — une
/// fenêtre qui dit « aucune carte » alors que la GoPro est branchée, parce que macOS bloque
/// silencieusement le réseau local. Les demander d'avance coûte trois écrans.
struct Onboarding: View {

    let model: ImportModel
    let finish: () -> Void

    // L'étape se laisse imposer au lancement — `open -a QuiX --args -quixOnboardingStep 2` —
    // pour qu'on puisse photographier chacune sans cliquer à l'aveugle sur l'écran. Le domaine
    // des arguments ne survit pas au lancement : rien n'est écrit nulle part.
    @State private var step = UserDefaults.standard.integer(forKey: "quixOnboardingStep")
    @State private var notificationsAsked = false

    private static let lastStep = 2

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Rule()
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Ink.window)
        .foregroundStyle(Ink.primary)
    }

    @ViewBuilder
    private var content: some View {
        switch step {
        case 0: welcome
        case 1: library
        default: permissions
        }
    }

    // MARK: 1 — Ce que fait l'app

    private var welcome: some View {
        Pane(title: "QuiX sorts your GoPro highlights",
             detail: "Plug the camera in over USB-C, or the card into a reader. QuiX reads the tags you pressed while filming and files each take in Highlights or Clips. It never modifies the card.") {
            HStack(spacing: 14) {
                Trait(symbol: "bolt.fill", title: "No waiting",
                      detail: "Sorting reads 34 KB per clip, not the whole file.")
                Trait(symbol: "checkmark.shield.fill", title: "Verified",
                      detail: "Every copy is checksummed, then read back from disk.")
                Trait(symbol: "hand.raised.fill", title: "Never erases",
                      detail: "The card is only emptied by a button you press.")
            }
            .frame(maxWidth: 720)
        }
    }

    // MARK: 2 — Où ranger les clips

    private var library: some View {
        Pane(title: "Where should the clips go?",
             detail: "QuiX creates one dated folder per import, with Highlights and Clips inside it. Pick somewhere you already keep footage — QuiX will not invent a folder for you.") {
            VStack(spacing: 12) {
                Button(model.preferences.library == nil ? "Choose a folder…" : "Change folder…") {
                    model.chooseLibrary()
                }
                .buttonStyle(FilledBlue())
                if model.preferences.library != nil {
                    Label {
                        Text(verbatim: model.libraryDisplayPath).font(Type.mono(12))
                    } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Ink.blue)
                    }
                    .foregroundStyle(Ink.secondary)
                }
            }
        }
    }

    // MARK: 3 — Les autorisations

    private var permissions: some View {
        Pane(title: "Two permissions macOS will ask for",
             detail: "Neither is optional, and both fail the same misleading way — QuiX sees the hardware and finds nothing on it.") {
            VStack(alignment: .leading, spacing: 16) {
                Ask(symbol: "network", title: "Local Network",
                    detail: "Over USB-C the GoPro is a network device. macOS asks the first time QuiX talks to it; if you refuse, the camera looks empty.")
                Ask(symbol: "sdcard", title: "Removable Volumes",
                    detail: "For a card in a reader. macOS asks on the first card; without it, the card looks empty.")
                Ask(symbol: "bell.badge", title: "Notifications",
                    detail: "So you know when an import is done and the camera can be unplugged.") {
                    Button(notificationsAsked ? "Asked" : "Allow notifications…") {
                        notificationsAsked = true
                        Notifier.shared.start()
                    }
                    .buttonStyle(OutlinedDark())
                    .disabled(notificationsAsked)
                }
                Divider().overlay(Ink.hairline)
                Toggle("Open QuiX when the GoPro is plugged in", isOn: Binding(
                    get: { model.preferences.launchOnCameraConnection },
                    set: { model.preferences.launchOnCameraConnection = $0 }))
                    .toggleStyle(.checkbox)
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
    }

    // MARK: Le pied

    private var footer: some View {
        HStack(spacing: 14) {
            HStack(spacing: 7) {
                ForEach(0...Self.lastStep, id: \.self) { index in
                    Circle()
                        .fill(index == step ? Ink.blue : Color.white.opacity(0.18))
                        .frame(width: 6, height: 6)
                }
            }
            Spacer()
            if step > 0 {
                Button("Back") { step -= 1 }.buttonStyle(OutlinedDark())
            }
            if step < Self.lastStep {
                Button("Continue") { step += 1 }
                    .buttonStyle(FilledBlue())
                    // Sans dossier d'import, l'écran suivant n'a rien à proposer et le premier
                    // branchement retomberait sur la même question.
                    .disabled(step == 1 && model.preferences.library == nil)
            } else {
                Button("Plug in your GoPro", action: finish).buttonStyle(FilledBlue())
            }
        }
        .padding(.init(top: 16, leading: 28, bottom: 18, trailing: 28))
    }
}

// MARK: - Petites pièces

private struct Pane<Content: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 72, height: 72)
            VStack(spacing: 10) {
                Text(title).font(.system(size: 22, weight: .semibold))
                Text(detail)
                    .font(Type.small).foregroundStyle(Ink.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560)
            }
            content
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
    }
}

private struct Trait: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(Ink.blue)
            Text(title).font(.system(size: 13.5, weight: .medium))
            Text(detail).font(Type.caption).foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.init(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(Ink.raised, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Ink.rule, lineWidth: 0.5))
    }
}

private struct Ask<Trailing: View>: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    @ViewBuilder var trailing: Trailing

    init(symbol: String, title: LocalizedStringKey, detail: LocalizedStringKey,
         @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14)).foregroundStyle(Ink.blue)
                .frame(width: 20, alignment: .center).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Type.body)
                Text(detail).font(Type.caption).foregroundStyle(Ink.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

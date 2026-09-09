import SwiftUI

/// Les jetons du redesign, en un seul endroit.
///
/// Les maquettes du handoff sont dessinées en CSS, avec des couleurs en `oklch` que SwiftUI ne sait
/// pas lire. Les valeurs ci-dessous sont les équivalents sRGB donnés par le handoff lui-même ; on
/// les nomme par leur **rôle** et non par leur teinte, pour que changer l'accent un jour se fasse
/// ici et nulle part ailleurs.
enum Ink {

    // MARK: Fonds

    /// Fond des fenêtres.
    static let window = Color(hex: 0x1A191D)
    /// Fond du popover, posé sur le flou du système.
    static let popover = Color(hex: 0x18171A).opacity(0.94)
    /// Barre de titre.
    static let titleBar = Color(hex: 0x232228)
    /// Panneau secondaire : inspecteur, en-tête de liste.
    static let panel = Color(hex: 0x1F1E23)
    /// Colonne de gauche de la Bibliothèque.
    static let sidebar = Color(hex: 0x201F25)

    /// Cartes et lignes sélectionnées.
    static let raised = Color.white.opacity(0.05)
    /// Survol des lignes de liste.
    static let hover = Color.white.opacity(0.06)

    // MARK: Filets

    /// Séparateurs.
    static let hairline = Color.white.opacity(0.08)
    /// Bordures de cartes et pistes de progression.
    static let rule = Color.white.opacity(0.12)

    // MARK: Textes

    static let primary = Color(hex: 0xF2F0EC)
    static let secondary = Color(hex: 0xF2F0EC).opacity(0.55)
    static let tertiary = Color(hex: 0xF2F0EC).opacity(0.40)

    // MARK: Accent

    /// Bleu GoPro. Progression, boutons pleins, marqueurs.
    static let blue = Color(hex: 0x00A3E4)
    /// Le même, enfoncé.
    static let bluePressed = Color(hex: 0x0090CC)
    /// Bleu clair : flèche de l'icône, pastilles de tags des tables.
    static let blueLight = Color(hex: 0xA9DCF5)
    /// Bleu des pastilles « nombre de tags » sur les vignettes.
    static let blueBadge = Color(hex: 0x3FB2E8)
    /// Bleu du texte : « 3 taguées », pourcentages.
    static let blueText = Color(hex: 0x5BBDEE)
    /// Portion en cours de vérification, dans la barre à deux tons.
    static let blueVerifying = Color(hex: 0xC2E7F8)
    /// Encre sur fond bleu clair.
    static let onLight = Color(hex: 0x17161A)
}

/// L'échelle typographique du handoff.
///
/// Les tailles sont données au demi-point près et ne correspondent à aucun style natif : on les
/// pose telles quelles plutôt que d'approcher avec `.callout` et de dériver écran par écran.
enum Type {
    /// Titre de section, 15 pt semibold.
    static let section = Font.system(size: 15, weight: .semibold)
    /// Corps, 13,5 pt.
    static let body = Font.system(size: 13.5)
    /// Secondaire, 12,5 pt.
    static let small = Font.system(size: 12.5)
    /// Légende, 11,5 pt.
    static let caption = Font.system(size: 11.5)
    /// Nom d'une carte ou d'un dossier, 17 pt semibold.
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    /// Chiffre de bilan, 22 pt semibold.
    static let figure = Font.system(size: 22, weight: .semibold)

    /// Monospace : valeurs numériques et noms de fichiers.
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// En-tête de colonne : mono, majuscules, très interlettré.
struct ColumnHeader: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(Type.mono(10.5))
            .tracking(1.2)
            .foregroundStyle(Ink.tertiary)
    }
}

/// Le bouton plein bleu, texte blanc.
struct FilledBlue: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5, weight: .medium))
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(configuration.isPressed ? Ink.bluePressed : Ink.blue,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
    }
}

/// Le bouton à contour, sur fond sombre.
struct OutlinedDark: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13.5))
            .foregroundStyle(Ink.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(configuration.isPressed ? Color.white.opacity(0.08) : Color.white.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
            .contentShape(Rectangle())
    }
}

/// La pastille bleue qui bat pendant qu'une lecture ou une copie est en cours.
///
/// L'unique animation du redesign : opacité 0,35 ↔ 1, 1,6 s, aller-retour.
struct PulsingDot: View {
    var size: CGFloat = 7
    var color: Color = Ink.blue
    @State private var faded = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(faded ? 0.35 : 1)
            .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: faded)
            .onAppear { faded = true }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

/// Tailles et formats partagés.
enum Metrics {
    static let popoverWidth: CGFloat = 300
    static let transferWidth: CGFloat = 860
    static let libraryWidth: CGFloat = 1120
    static let libraryHeight: CGFloat = 620
    static let sidebarWidth: CGFloat = 214
    static let inspectorWidth: CGFloat = 268
    static let headerHeight: CGFloat = 46
}

/// Formatage des tailles, en français : « 11,9 Go ».
enum Bytes {
    static func short(_ value: UInt64) -> String {
        let units = ["o", "Ko", "Mo", "Go", "To"]
        var size = Double(value)
        var unit = 0
        while size >= 1024, unit < units.count - 1 { size /= 1024; unit += 1 }
        if unit == 0 { return "\(value) o" }
        return String(format: "%.1f %@", size, units[unit])
            .replacingOccurrences(of: ".", with: ",")
    }
}

/// Durée d'un clip : « 8:04 ».
enum Clock {
    static func short(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let total = Int(seconds.rounded())
        let minutes = total / 60, secs = total % 60
        if minutes >= 60 { return String(format: "%d:%02d:%02d", minutes / 60, minutes % 60, secs) }
        return String(format: "%d:%02d", minutes, secs)
    }

    /// Instant d'un tag HiLight : « 3,436 s » devient « 0:03 ».
    static func moment(milliseconds: UInt32) -> String {
        short(Double(milliseconds) / 1000)
    }
}

/// Le sélecteur segmenté du handoff : fond discret, segment actif surélevé et liseré.
///
/// Il sert au filtre de la Bibliothèque comme aux onglets de la fenêtre. Générique plutôt que
/// dupliqué : deux exemplaires à peine différents auraient fini par diverger.
struct Segmented<Option: Hashable>: View {

    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    init(selection: Binding<Option>, options: [Option], label: @escaping (Option) -> String) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let active = selection == option
                Button { selection = option } label: {
                    Text(label(option))
                        .font(.system(size: 12.5, weight: active ? .medium : .regular))
                        .foregroundStyle(active ? Ink.primary : Ink.secondary)
                        .padding(.vertical, 3).padding(.horizontal, 12)
                        .background(active ? Ink.raised : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            if active {
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Ink.rule, lineWidth: 0.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Ink.hairline, in: RoundedRectangle(cornerRadius: 8))
    }
}

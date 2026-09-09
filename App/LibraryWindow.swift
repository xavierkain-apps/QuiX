import SwiftUI
import QuiXCore

/// Retrouver les prises taguées après l'import.
///
/// Trois colonnes : les sessions, la grille, l'inspecteur. Seule la grille s'étire quand la fenêtre
/// s'agrandit.
struct LibraryWindow: View {

    let model: ImportModel
    @State private var library = LibraryModel()
    @State private var thumbnails = Thumbnails()

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(library: library, model: model)
                .frame(width: Metrics.sidebarWidth)
            Divider().overlay(Ink.hairline)
            Shelf(library: library, thumbnails: thumbnails)
                .frame(maxWidth: .infinity)
            Divider().overlay(Ink.hairline)
            Inspector(library: library, thumbnails: thumbnails)
                .frame(width: Metrics.inspectorWidth)
        }
        .frame(minWidth: Metrics.libraryWidth, minHeight: Metrics.libraryHeight)
        .background(Ink.window)
        .foregroundStyle(Ink.primary)
        .onAppear { library.load(from: model.preferences.library) }
        // Un import qui se termine ajoute une session : la bibliothèque doit la voir sans qu'on
        // ait à la rouvrir.
        .onChange(of: isFinished) { _, finished in
            if finished { library.load(from: model.preferences.library) }
        }
    }

    private var isFinished: Bool {
        if case .finished = model.stage { true } else { false }
    }
}

// MARK: - Colonne de gauche

private struct Sidebar: View {
    let library: LibraryModel
    let model: ImportModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: Metrics.headerHeight)

            VStack(alignment: .leading, spacing: 2) {
                Global(dot: Ink.blue, title: "Tous les highlights", count: library.allHighlights,
                       selected: library.selectedSession == nil && library.filter == .highlights) {
                    library.selectedSession = nil
                    library.filter = .highlights
                }
                Global(dot: Color.white.opacity(0.2), title: "Tous les clips", count: library.allClips,
                       selected: library.selectedSession == nil && library.filter == .all) {
                    library.selectedSession = nil
                    library.filter = .all
                }

                ColumnHeader("Sessions")
                    .padding(.init(top: 20, leading: 10, bottom: 8, trailing: 10))

                ForEach(library.sessions) { session in
                    SessionRow(session: session,
                               selected: library.selectedSession == session.id,
                               progress: progress(for: session)) {
                        library.selectedSession = session.id
                        library.selectedClip = nil
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)
            Rule()
            VStack(alignment: .leading, spacing: 5) {
                Text("Dossier d'import").font(Type.caption).foregroundStyle(Ink.tertiary)
                Button {
                    model.chooseLibrary()
                    library.load(from: model.preferences.library)
                } label: {
                    Text(model.libraryDisplayPath)
                        .font(Type.mono(12)).foregroundStyle(Ink.primary.opacity(0.85))
                        .lineLimit(1).truncationMode(.head)
                }
                .buttonStyle(.plain)
            }
            .padding(.init(top: 14, leading: 16, bottom: 16, trailing: 16))
        }
        .background(Ink.sidebar)
    }

    /// La session en cours d'import s'affiche avec son pourcentage.
    private func progress(for session: LibraryModel.Session) -> Double? {
        guard case .importing(let p) = model.stage,
              model.activePlan?.importFolder.lastPathComponent == session.id else { return nil }
        return p.fraction
    }
}

private struct Global: View {
    let dot: Color
    let title: String
    let count: Int
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Circle().fill(dot).frame(width: 6, height: 6)
                Text(title).font(.system(size: 13.5, weight: selected ? .medium : .regular))
                Spacer()
                Text("\(count)").font(.system(size: 12)).foregroundStyle(Ink.tertiary)
            }
            .foregroundStyle(selected ? Ink.primary : Ink.primary.opacity(0.85))
            .padding(.vertical, 7).padding(.horizontal, 10)
            .background(selected ? Color.white.opacity(0.09) : (hovered ? Ink.hover : .clear),
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

private struct SessionRow: View {
    let session: LibraryModel.Session
    let selected: Bool
    let progress: Double?
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.date).font(Type.mono(12.5))
                Spacer()
                if let progress {
                    HStack(spacing: 6) {
                        PulsingDot(size: 5)
                        Text("\(Int(progress * 100)) %").font(Type.caption)
                    }
                    .foregroundStyle(Ink.blueText)
                } else {
                    Text("\(session.clips.count)").font(.system(size: 12))
                        .foregroundStyle(Ink.tertiary)
                }
            }
            .foregroundStyle(Ink.primary.opacity(0.85))
            .padding(.vertical, 7).padding(.horizontal, 10)
            .background(background, in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                if progress != nil {
                    RoundedRectangle(cornerRadius: 7).strokeBorder(Ink.rule, lineWidth: 0.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var background: Color {
        if progress != nil { return Ink.raised }
        if selected { return Color.white.opacity(0.09) }
        return hovered ? Ink.hover : .clear
    }
}

// MARK: - Colonne centrale

private struct Shelf: View {
    let library: LibraryModel
    let thumbnails: Thumbnails

    // 196 pt donne les trois colonnes de la maquette à la largeur nominale, et une de plus
    // dès que la fenêtre s'élargit assez pour la porter.
    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            header
            if library.visibleClips.isEmpty {
                Placeholder(text: library.isLoading ? "Lecture…" : "Rien ici",
                            detail: library.isLoading
                                ? "La bibliothèque est en cours de lecture."
                                : "Aucune prise ne correspond à ce filtre.")
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(library.visibleClips) { clip in
                            Thumb(clip: clip, thumbnails: thumbnails,
                                  selected: library.selectedClip?.id == clip.id) {
                                library.selectedClip = clip
                            }
                        }
                    }
                    .padding(.init(top: 18, leading: 20, bottom: 20, trailing: 20))
                }
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(library.selectedSession ?? "Toute la bibliothèque")
                    .font(.system(size: 13.5, weight: .semibold))
                Text(summary).font(Type.small).foregroundStyle(Ink.tertiary)
            }
            Spacer()
            Segmented(filter: Binding(get: { library.filter }, set: { library.filter = $0 }))
        }
        .padding(.horizontal, 20)
        .frame(height: Metrics.headerHeight)
        .background(Ink.panel)
        .overlay(alignment: .bottom) { Rule() }
    }

    private var summary: String {
        let clips = library.visibleSessions.flatMap(\.clips)
        let tagged = clips.filter(\.isHighlighted).count
        let plural = clips.count == 1 ? "prise" : "prises"
        return "\(clips.count) \(plural) — \(tagged) taguée\(tagged == 1 ? "" : "s")"
    }
}

private struct Segmented: View {
    @Binding var filter: LibraryModel.Filter

    var body: some View {
        HStack(spacing: 4) {
            ForEach(LibraryModel.Filter.allCases, id: \.self) { option in
                let active = filter == option
                Button { filter = option } label: {
                    Text(option.rawValue)
                        .font(.system(size: 12.5, weight: active ? .medium : .regular))
                        .foregroundStyle(active ? Ink.primary : Ink.secondary)
                        .padding(.vertical, 3).padding(.horizontal, 12)
                        .background(active ? Ink.raised : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            if active {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Ink.rule, lineWidth: 0.5)
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

private struct Thumb: View {
    let clip: LibraryModel.Clip
    let thumbnails: Thumbnails
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                Poster(clip: clip, thumbnails: thumbnails)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(selected ? Ink.blue : Color.white.opacity(0.1),
                                      lineWidth: selected ? 2 : 0.5))
                    .overlay(alignment: .topLeading) {
                        TagBadge(count: clip.tagCount, style: .badge).padding(7)
                    }
                HStack {
                    Text(clip.name).font(Type.mono(12))
                    Spacer()
                    Text(clip.duration.map(Clock.short) ?? "—")
                        .font(.system(size: 12)).foregroundStyle(Ink.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// L'image d'un clip, ou les rayures en attendant qu'elle soit extraite.
private struct Poster: View {
    let clip: LibraryModel.Clip
    let thumbnails: Thumbnails

    var body: some View {
        // Le cadre impose le 16:9 et l'image s'y recadre. Sans `GeometryReader`, c'est l'image qui
        // dictait sa taille : une prise filmée à la verticale étirait la vignette sur toute la
        // hauteur de la grille.
        GeometryReader { geometry in
            ZStack {
                Stripes()
                if let image = thumbnails.image(for: clip) {
                    Image(nsImage: image)
                        .resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }
}

struct Stripes: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .color(Color.white.opacity(0.03)))
            var x: CGFloat = -size.height
            while x < size.width {
                let bar = Path { path in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    path.addLine(to: CGPoint(x: x + size.height + 6, y: 0))
                    path.addLine(to: CGPoint(x: x + 6, y: size.height))
                    path.closeSubpath()
                }
                context.fill(bar, with: .color(Color.white.opacity(0.04)))
                x += 12
            }
        }
    }
}

// MARK: - Inspecteur

private struct Inspector: View {
    let library: LibraryModel
    let thumbnails: Thumbnails

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Inspecteur")
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.secondary)
                .padding(.horizontal, 18)
                .frame(height: Metrics.headerHeight, alignment: .leading)
                .overlay(alignment: .bottom) { Rule() }

            if let clip = library.selectedClip {
                ScrollView { detail(clip) }
            } else {
                Spacer()
                Text("Sélectionnez une prise.")
                    .font(Type.small).foregroundStyle(Ink.tertiary)
                    .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .background(Ink.panel)
    }

    private func detail(_ clip: LibraryModel.Clip) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Poster(clip: clip, thumbnails: thumbnails)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.name).font(Type.mono(14))
                Text(subtitle(clip)).font(Type.small).foregroundStyle(Ink.tertiary)
            }

            if !clip.moments.isEmpty {
                Moments(clip: clip)
            }

            Button("Révéler dans le Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([clip.url])
            }
            .buttonStyle(FilledBlue(fullWidth: true))

            Text("Les highlights ajoutés après coup dans l'app Quik restent dans l'app.")
                .font(Type.caption).foregroundStyle(Ink.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
    }

    private func subtitle(_ clip: LibraryModel.Clip) -> String {
        [clip.duration.map(Clock.short), Bytes.short(clip.size), clip.format]
            .compactMap { $0 }.joined(separator: " — ")
    }
}

/// La piste des moments, et leur liste.
private struct Moments: View {
    let clip: LibraryModel.Clip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ColumnHeader("\(clip.tagCount) moment\(clip.tagCount == 1 ? "" : "s")")

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Stripes()
                    ForEach(Array(clip.moments.enumerated()), id: \.offset) { _, moment in
                        RoundedRectangle(cornerRadius: 1).fill(Ink.blue)
                            .frame(width: 2)
                            .offset(x: geometry.size.width * position(of: moment))
                    }
                }
            }
            .frame(height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))

            VStack(spacing: 0) {
                ForEach(Array(clip.moments.enumerated()), id: \.offset) { _, moment in
                    MomentRow(clip: clip, moment: moment)
                }
            }
        }
    }

    /// Sans durée connue, on ne peut pas placer un moment au prorata : on les répartit alors
    /// régulièrement plutôt que de les empiler tous à gauche.
    private func position(of moment: UInt32) -> Double {
        guard let duration = clip.duration, duration > 0 else {
            guard let index = clip.moments.firstIndex(of: moment), clip.moments.count > 1 else { return 0 }
            return Double(index) / Double(clip.moments.count)
        }
        return min(0.98, Double(moment) / 1000 / duration)
    }
}

private struct MomentRow: View {
    let clip: LibraryModel.Clip
    let moment: UInt32
    @State private var hovered = false

    var body: some View {
        Button {
            // À défaut d'un lecteur intégré, on ouvre le clip : QuickTime s'ouvre au début, mais
            // l'instant reste affiché ici pour l'y retrouver.
            NSWorkspace.shared.open(clip.url)
        } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Ink.blue).frame(width: 3, height: 14)
                Text(Clock.moment(milliseconds: moment)).font(Type.mono(12.5))
                Spacer()
                Text("tournage").font(Type.caption).foregroundStyle(Ink.tertiary)
            }
            .padding(.vertical, 6).padding(.horizontal, 8)
            .background(hovered ? Ink.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

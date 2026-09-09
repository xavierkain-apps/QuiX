import AVFoundation
import Observation
import QuiXCore
import SwiftUI

/// Ce que la bibliothèque contient, lu du disque.
///
/// Rien n'est déduit de l'index : on liste les dossiers datés et ce qu'ils portent. C'est ce que
/// l'utilisateur voit dans le Finder, et une session déplacée à la main doit disparaître d'ici
/// aussi.
@MainActor
@Observable
final class LibraryModel {

    /// Une prise importée, telle qu'elle s'affiche dans la grille.
    struct Clip: Identifiable, Hashable {
        let id: String
        let url: URL
        let name: String
        let size: UInt64
        let isHighlighted: Bool
        /// Instants tagués, en millisecondes depuis le début du chapitre.
        var moments: [UInt32] = []
        var duration: Double?
        var format: String?

        var tagCount: Int { moments.count }
    }

    struct Session: Identifiable, Hashable {
        let id: String
        let folder: URL
        var clips: [Clip]

        var date: String { id }
        var highlighted: [Clip] { clips.filter(\.isHighlighted) }
    }

    enum Filter: String, CaseIterable { case highlights = "Highlights", clips = "Clips", all = "Tout" }

    private(set) var sessions: [Session] = []
    private(set) var isLoading = false

    /// `nil` veut dire « toutes les sessions ».
    var selectedSession: String?
    var filter: Filter = .highlights
    var selectedClip: Clip?

    private var library: URL?

    var allHighlights: Int { sessions.reduce(0) { $0 + $1.highlighted.count } }
    var allClips: Int { sessions.reduce(0) { $0 + $1.clips.count } }

    var visibleSessions: [Session] {
        guard let selectedSession else { return sessions }
        return sessions.filter { $0.id == selectedSession }
    }

    /// Les prises affichées dans la grille, selon la session et le filtre choisis.
    var visibleClips: [Clip] {
        let pool = visibleSessions.flatMap(\.clips)
        return switch filter {
        case .highlights: pool.filter(\.isHighlighted)
        case .clips: pool.filter { !$0.isHighlighted }
        case .all: pool
        }
    }

    // MARK: Lecture

    func load(from library: URL?) {
        self.library = library
        guard let library else { sessions = []; return }
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let found = LibraryModel.scan(library)
            await MainActor.run {
                self.sessions = found
                self.isLoading = false
                if self.selectedClip == nil { self.selectedClip = self.visibleClips.first }
            }
            // Les tags, la durée et le format demandent d'ouvrir chaque fichier : on les ajoute
            // après coup plutôt que de retarder l'affichage de la grille.
            await self.enrich(found)
        }
    }

    private nonisolated static func scan(_ library: URL) -> [Session] {
        let manager = FileManager.default
        let entries = (try? manager.contentsOfDirectory(atPath: library.path)) ?? []

        return entries
            .filter(ImportModel.isDatedFolder)
            .sorted(by: >)
            .map { name in
                let folder = library.appendingPathComponent(name, isDirectory: true)
                var clips: [Clip] = []
                for (subfolder, tagged) in [(ImportPlan.highlightsFolder, true),
                                            (ImportPlan.clipsFolder, false)] {
                    let directory = folder.appendingPathComponent(subfolder, isDirectory: true)
                    let files = (try? manager.contentsOfDirectory(
                        at: directory, includingPropertiesForKeys: [.fileSizeKey],
                        options: [.skipsHiddenFiles])) ?? []
                    for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                        guard GoProFileName(file.lastPathComponent)?.kind.isVideo == true else { continue }
                        clips.append(Clip(
                            id: "\(name)/\(subfolder)/\(file.lastPathComponent)",
                            url: file,
                            name: file.lastPathComponent,
                            size: UInt64((try? file.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0),
                            isHighlighted: tagged))
                    }
                }
                return Session(id: name, folder: folder, clips: clips)
            }
            .filter { !$0.clips.isEmpty }
    }

    /// Complète chaque prise : ses moments HiLight, sa durée, son format.
    private func enrich(_ found: [Session]) async {
        for session in found {
            for clip in session.clips {
                let detail = await Task.detached(priority: .utility) { () -> (UInt32Array, Double?, String?) in
                    let moments = (try? HiLightReader.scan(fileURL: clip.url))?.moments ?? []
                    let asset = AVURLAsset(url: clip.url)
                    let duration = try? await asset.load(.duration).seconds
                    var format: String?
                    if let track = try? await asset.loadTracks(withMediaType: .video).first,
                       let size = try? await track.load(.naturalSize),
                       let rate = try? await track.load(.nominalFrameRate) {
                        format = "\(Int(size.width))×\(Int(size.height)) \(Int(rate.rounded())) i/s"
                    }
                    return (UInt32Array(moments), duration, format)
                }.value

                apply(detail, to: clip.id)
            }
        }
    }

    private func apply(_ detail: (UInt32Array, Double?, String?), to id: String) {
        for (s, session) in sessions.enumerated() {
            guard let c = session.clips.firstIndex(where: { $0.id == id }) else { continue }
            sessions[s].clips[c].moments = detail.0.values
            sessions[s].clips[c].duration = detail.1
            sessions[s].clips[c].format = detail.2
            if selectedClip?.id == id { selectedClip = sessions[s].clips[c] }
            return
        }
    }
}

/// Emballage `Sendable` pour traverser la frontière d'un `Task.detached`.
struct UInt32Array: Sendable {
    let values: [UInt32]
    init(_ values: [UInt32]) { self.values = values }
}

// MARK: - Vignettes

/// Extrait et met en cache une image de chaque clip.
///
/// L'image est prise **au premier moment tagué** quand il y en a un : c'est celle qui dit pourquoi
/// la prise est dans `Highlights/`. À défaut, une image proche du début — pas la toute première,
/// souvent noire.
@MainActor
@Observable
final class Thumbnails {

    private var cache: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    func image(for clip: LibraryModel.Clip) -> NSImage? {
        if let ready = cache[clip.id] { return ready }
        guard !inFlight.contains(clip.id) else { return nil }
        inFlight.insert(clip.id)

        let at = clip.moments.first.map { Double($0) / 1000 } ?? 1.0
        Task.detached(priority: .utility) { [url = clip.url] in
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 640, height: 360)
            let time = CMTime(seconds: at, preferredTimescale: 600)
            guard let cgImage = try? await generator.image(at: time).image else { return }
            let image = NSImage(cgImage: cgImage, size: .zero)
            await MainActor.run { self.store(image, for: clip.id) }
        }
        return nil
    }

    private func store(_ image: NSImage, for id: String) {
        cache[id] = image
        inFlight.remove(id)
    }
}

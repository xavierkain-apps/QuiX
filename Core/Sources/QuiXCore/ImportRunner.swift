import Foundation

/// Où en est l'import.
public struct ImportProgress: Equatable, Sendable {
    public let fileIndex: Int
    public let fileCount: Int
    public let currentFile: String
    /// Octets copiés depuis le début du plan, fichier en cours compris.
    public let bytesCopied: UInt64
    public let byteCount: UInt64

    public init(fileIndex: Int, fileCount: Int, currentFile: String,
                bytesCopied: UInt64, byteCount: UInt64) {
        self.fileIndex = fileIndex
        self.fileCount = fileCount
        self.currentFile = currentFile
        self.bytesCopied = bytesCopied
        self.byteCount = byteCount
    }

    public var fraction: Double {
        byteCount == 0 ? 1 : min(1, Double(bytesCopied) / Double(byteCount))
    }
}

public struct ImportFailure: Equatable, Sendable {
    public let source: URL
    public let reason: String
}

/// Ce qu'un import a réellement fait.
public struct ImportReport: Equatable, Sendable {
    public let importFolder: URL
    public let copied: [PlannedCopy]
    public let failures: [ImportFailure]
    public let alreadyImported: [MediaFile]
    public let wasCancelled: Bool

    public var highlightsFolder: URL {
        importFolder.appendingPathComponent(ImportPlan.highlightsFolder, isDirectory: true)
    }
    public var copiedBytes: UInt64 { copied.reduce(0) { $0 + $1.source.size } }
    public var highlightedTakeCount: Int { Set(copied.filter(\.isHighlighted).map(\.takeNumber)).count }
}

public enum ImportRunner {

    /// Combien de fois retenter un clip que le réseau a fait échouer.
    ///
    /// La caméra en USB n'est pas un disque : une requête peut échouer sans que le clip soit en
    /// cause. Abandonner à la première erreur laissait un fichier manquant qu'il fallait aller
    /// rechercher par un second import — pour un incident qui se règle en attendant une seconde.
    static let attempts = 3

    /// Ce qu'on attend avant de réessayer. Court, puis moins court : si la caméra a besoin de
    /// souffler, insister immédiatement ne sert à rien.
    static let backoff: [TimeInterval] = [1, 3]

    /// Copie un clip depuis la caméra, en réessayant ce qui mérite de l'être.
    ///
    /// La reprise rend ces tentatives presque gratuites : la seconde repart des octets déjà reçus
    /// au lieu de tout retélécharger. Deux échecs ne se retentent jamais — une annulation demandée
    /// par l'utilisateur, et une destination déjà occupée, qui ne s'arrangeront pas d'eux-mêmes.
    private static func copyFromCamera(
        _ planned: PlannedCopy,
        fileManager: FileManager,
        isCancelled: () -> Bool,
        progress: (UInt64) -> Void
    ) throws {
        var lastFailure: Error?

        for attempt in 0..<attempts {
            if attempt > 0 {
                if isCancelled() { throw CopyFailure.cancelled }
                Thread.sleep(forTimeInterval: backoff[min(attempt - 1, backoff.count - 1)])
                if isCancelled() { throw CopyFailure.cancelled }
            }

            do {
                try RemoteVerifiedCopy.copy(
                    from: planned.source.url,
                    expectedSize: planned.source.size,
                    modified: planned.source.modified,
                    to: planned.destination,
                    fileManager: fileManager,
                    isCancelled: isCancelled,
                    progress: progress
                )
                return
            } catch CopyFailure.cancelled {
                throw CopyFailure.cancelled
            } catch let failure as CopyFailure {
                if case .destinationExists = failure { throw failure }
                lastFailure = failure
            } catch {
                lastFailure = error
            }
        }

        throw lastFailure ?? CopyFailure.cancelled
    }

    /// Exécute un plan.
    ///
    /// Deux partis pris :
    ///
    /// - **Un échec sur un fichier n'arrête pas l'import.** Un clip illisible est signalé et les
    ///   quarante-neuf autres arrivent quand même. Tout abandonner à cause d'un secteur abîmé
    ///   ferait perdre l'import entier pour rien.
    /// - **L'index est écrit après chaque fichier.** Un débranchement en cours de route laisse
    ///   l'index d'accord avec le disque, et le rebranchement reprend là où on s'était arrêté au
    ///   lieu de tout recopier.
    @discardableResult
    public static func run(
        _ plan: ImportPlan,
        library: URL,
        index: inout ImportIndex,
        now: Date = Date(),
        fileManager: FileManager = .default,
        isCancelled: () -> Bool = { false },
        progress: (ImportProgress) -> Void = { _ in }
    ) -> ImportReport {

        var copied: [PlannedCopy] = []
        var failures: [ImportFailure] = []
        var completedBytes: UInt64 = 0
        var cancelled = false

        for (position, planned) in plan.copies.enumerated() {
            if isCancelled() { cancelled = true; break }

            progress(ImportProgress(fileIndex: position,
                                    fileCount: plan.copies.count,
                                    currentFile: planned.source.filename,
                                    bytesCopied: completedBytes,
                                    byteCount: plan.byteCount))

            let onBytes: (UInt64) -> Void = { bytes in
                progress(ImportProgress(fileIndex: position,
                                        fileCount: plan.copies.count,
                                        currentFile: planned.source.filename,
                                        bytesCopied: completedBytes + bytes,
                                        byteCount: plan.byteCount))
            }

            do {
                // La source décide de la manière, pas de la garantie : carte montée ou caméra en
                // USB, les deux chemins écrivent dans un temporaire, vérifient l'empreinte relue,
                // et ne renomment qu'ensuite.
                if planned.source.url.isFileURL {
                    try VerifiedCopy.copy(
                        from: planned.source.url,
                        to: planned.destination,
                        fileManager: fileManager,
                        isCancelled: isCancelled,
                        progress: onBytes
                    )
                } else {
                    try copyFromCamera(planned, fileManager: fileManager,
                                       isCancelled: isCancelled, progress: onBytes)
                }

                completedBytes += planned.source.size
                copied.append(planned)
                index.record(planned.source, relativeDestination: planned.relativeDestination, at: now)
                try? ImportIndexStore.save(index, toLibrary: library)

            } catch CopyFailure.cancelled {
                cancelled = true
                break
            } catch {
                completedBytes += planned.source.size
                failures.append(ImportFailure(source: planned.source.url,
                                              reason: String(describing: error)))
            }
        }

        return ImportReport(importFolder: plan.importFolder,
                            copied: copied,
                            failures: failures,
                            alreadyImported: plan.alreadyImported,
                            wasCancelled: cancelled)
    }
}

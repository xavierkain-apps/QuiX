import Foundation

/// Where the import stands.
public struct ImportProgress: Equatable, Sendable {
    public let fileIndex: Int
    public let fileCount: Int
    public let currentFile: String
    /// Bytes copied since the start of the plan, current file included.
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

/// What an import actually did.
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

    /// How many times to retry a clip the network made fail.
    ///
    /// The camera over USB is not a disk: a request can fail without the clip being at fault.
    /// Giving up on the first error left a missing file to be fetched by a second import — for an
    /// incident that settles itself by waiting a second.
    static let attempts = 3

    /// How long to wait before trying again. Short, then less short: if the camera needs a moment,
    /// insisting immediately achieves nothing.
    static let backoff: [TimeInterval] = [1, 3]

    /// Copies a clip from the camera, retrying what is worth retrying.
    ///
    /// Resuming makes those attempts nearly free: the second starts from the bytes already
    /// received instead of downloading everything again. Two failures are never retried — a
    /// cancellation asked for by the user, and an occupied destination, neither of which improves on its own.
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

    /// Runs a plan.
    ///
    /// Two deliberate choices:
    ///
    /// - **One file failing does not stop the import.** An unreadable clip is reported and the
    ///   other forty-nine arrive all the same. Abandoning everything over one damaged sector
    ///   would lose the whole import for nothing.
    /// - **The index is written after every file.** A cable pulled mid-way leaves the index in
    ///   agreement with the disk, and plugging back in resumes where it stopped instead of copying
    ///   everything again.
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
                // The source decides the means, not the guarantee: mounted card or camera over
                // USB, both paths write to a temporary file, verify the checksum read back, and
                // only then rename.
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

import Foundation

/// Erasing the clips from the camera, once they are on the Mac.
///
/// This is the only operation in QuiX that destroys anything, and the only irreversible one: a
/// take erased from the card exists nowhere any more if the import went wrong. Three rules hold
/// it, and they are not negotiable.
///
/// 1. **Never automatically.** Erasing takes a click, then a confirmation. Nothing in the app
///    triggers it on its own, at any point.
/// 2. **A file is erasable only if it is proven present on the Mac** — the index knows it, the
///    copy is there, and its size matches exactly. We do not trust "the import went fine": we look
///    at the disk, file by file, at the moment of offering to erase.
/// 3. **One unverified file is enough to hold everything back.** The count is shown to the user,
///    and the button stays inert as long as the camera holds anything whose copy is not certain.
///
///
/// The third is deliberately stricter than necessary: we could erase only the verified files and
/// keep the rest. But a silent partial erase makes it look as though everything is filed away, and
/// that is precisely the mistake that cannot be undone.
public enum CameraCleanup {

    /// The count between what the camera holds and what is on the Mac.
    public struct Plan: Equatable, Sendable {

        /// Videos present on the camera.
        public let onCamera: [MediaFile]
        /// Those whose copy is verified on the Mac, at the right size.
        public let verified: [MediaFile]
        /// Those whose copy could not be confirmed. They hold the whole erase back.
        public let unverified: [MediaFile]

        public var cameraCount: Int { onCamera.count }
        public var verifiedCount: Int { verified.count }
        public var cameraBytes: UInt64 { onCamera.reduce(0) { $0 + $1.size } }
        public var verifiedBytes: UInt64 { verified.reduce(0) { $0 + $1.size } }

        /// True only if **everything** the camera holds is proven present on the Mac.
        public var isSafeToErase: Bool { !onCamera.isEmpty && unverified.isEmpty }
    }

    /// Compares the camera's contents with the library, file by file.
    ///
    /// - Parameter existingSize: injectable for tests; by default, the real size on disk. Disk is
    ///   what counts, not the index: a folder emptied by hand behind the app's back must hold the
    ///   erase back.
    public static func plan(
        takes: [Take],
        library: URL,
        index: ImportIndex,
        existingSize: (URL) -> UInt64? = ImportPlanner.sizeOnDisk
    ) -> Plan {

        let files = takes.flatMap { $0.chapters.map(\.file) }
        var verified: [MediaFile] = []
        var unverified: [MediaFile] = []

        for file in files {
            guard let entry = index.entry(for: file) else {
                unverified.append(file)
                continue
            }
            let copy = library.appendingPathComponent(entry.destination)
            if existingSize(copy) == file.size {
                verified.append(file)
            } else {
                unverified.append(file)
            }
        }

        return Plan(onCamera: files, verified: verified, unverified: unverified)
    }

    /// What an erase did.
    public struct Outcome: Equatable, Sendable {
        public let erased: [MediaFile]
        public let failed: [MediaFile]
    }

    /// Erases from the camera the files of a **safe** plan.
    ///
    /// Refuses to do anything if the plan is not: the guard lives here, in the engine, and not only
    /// in the window that greys out a button.
    public static func erase(
        _ plan: Plan,
        from camera: GoProCamera,
        progress: (Int, Int) -> Void = { _, _ in }
    ) throws -> Outcome {

        guard plan.isSafeToErase else { throw Failure.notVerified }

        var erased: [MediaFile] = []
        var failed: [MediaFile] = []

        for (position, file) in plan.verified.enumerated() {
            do {
                try camera.delete(folder: file.folder, filename: file.filename)
                erased.append(file)
            } catch {
                // One failure does not stop the others: the camera can refuse an isolated file, and
                // leaving the following forty-nine on the card would help nobody.
                failed.append(file)
            }
            progress(position + 1, plan.verified.count)
        }

        return Outcome(erased: erased, failed: failed)
    }

    public enum Failure: Error, Equatable {
        /// Not everything on the camera is proven present on the Mac.
        case notVerified
    }
}

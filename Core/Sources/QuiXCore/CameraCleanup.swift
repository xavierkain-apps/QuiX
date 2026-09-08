import Foundation

/// Effacer les clips de la caméra, une fois qu'ils sont sur le Mac.
///
/// C'est la seule opération de QuiX qui détruit quelque chose, et la seule qui soit irréversible :
/// une prise effacée de la carte n'existe plus nulle part si l'import s'est mal passé. Trois règles
/// l'encadrent, et elles ne sont pas négociables.
///
/// 1. **Jamais automatiquement.** L'effacement demande un clic, puis une confirmation. Rien dans
///    l'app ne l'enclenche seul, à aucun moment.
/// 2. **Un fichier n'est effaçable que s'il est prouvé présent sur le Mac** — l'index le connaît,
///    la copie est là, et sa taille correspond exactement. On ne se fie pas à « l'import s'est bien
///    passé » : on regarde le disque, fichier par fichier, au moment de proposer l'effacement.
/// 3. **Un seul fichier non vérifié suffit à tout retenir.** Le décompte est présenté à
///    l'utilisateur, et le bouton reste inerte tant que la caméra contient quoi que ce soit dont la
///    copie n'est pas certaine.
///
/// La troisième est volontairement plus stricte que nécessaire : on pourrait n'effacer que les
/// fichiers vérifiés et garder les autres. Mais un effacement partiel silencieux laisse croire que
/// tout est rangé, et c'est précisément l'erreur qu'on ne peut pas rattraper.
public enum CameraCleanup {

    /// Le décompte entre ce que porte la caméra et ce qui est sur le Mac.
    public struct Plan: Equatable, Sendable {

        /// Vidéos présentes sur la caméra.
        public let onCamera: [MediaFile]
        /// Celles dont la copie est vérifiée sur le Mac, à la bonne taille.
        public let verified: [MediaFile]
        /// Celles dont la copie n'a pas pu être confirmée. Elles retiennent tout l'effacement.
        public let unverified: [MediaFile]

        public var cameraCount: Int { onCamera.count }
        public var verifiedCount: Int { verified.count }
        public var cameraBytes: UInt64 { onCamera.reduce(0) { $0 + $1.size } }
        public var verifiedBytes: UInt64 { verified.reduce(0) { $0 + $1.size } }

        /// Vrai seulement si **tout** ce que porte la caméra est prouvé présent sur le Mac.
        public var isSafeToErase: Bool { !onCamera.isEmpty && unverified.isEmpty }
    }

    /// Compare le contenu de la caméra à la bibliothèque, fichier par fichier.
    ///
    /// - Parameter existingSize: injectable pour les tests ; par défaut, la taille réelle sur le
    ///   disque. C'est bien le disque qui fait foi, pas l'index : un dossier vidé à la main derrière
    ///   le dos de l'app doit retenir l'effacement.
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

    /// Ce qu'un effacement a fait.
    public struct Outcome: Equatable, Sendable {
        public let erased: [MediaFile]
        public let failed: [MediaFile]
    }

    /// Efface de la caméra les fichiers d'un plan **sûr**.
    ///
    /// Refuse de rien faire si le plan ne l'est pas : la garde est ici, dans le moteur, et pas
    /// seulement dans la fenêtre qui grise un bouton.
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
                // Un échec n'arrête pas les autres : la caméra peut refuser un fichier isolé, et
                // laisser les quarante-neuf suivants sur la carte n'aiderait personne.
                failed.append(file)
            }
            progress(position + 1, plan.verified.count)
        }

        return Outcome(erased: erased, failed: failed)
    }

    public enum Failure: Error, Equatable {
        /// Tout le contenu de la caméra n'est pas prouvé présent sur le Mac.
        case notVerified
    }
}

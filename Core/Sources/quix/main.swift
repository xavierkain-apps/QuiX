import Foundation
import QuiXCore

// Pilotage du moteur en ligne de commande. C'est l'outil qui permet de valider tout l'import sur
// une copie de carte, sur Linux comme sur le Mac, avant qu'il existe la moindre fenêtre.
//
// Tout vit dans des fonctions plutôt qu'au niveau supérieur : en Swift 6, le code de `main.swift`
// est isolé sur l'acteur principal, et un état mutable capturé dans une closure de progression y
// deviendrait un problème de concurrence pour rien.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data(("quix: " + message + "\n").utf8))
    exit(1)
}

func printUsage() {
    print("""
    quix — moteur d'import GoPro

    quix hilight <fichier.mp4>...        lit les tags HiLight d'un ou plusieurs clips
    quix scan <volume>                   liste les prises d'une carte et dit lesquelles sont taguées
    quix import <volume> <bibliothèque>  importe, en séparant Highlights/ et Clips/
        --dry-run                        montre le plan sans écrire un octet
        --date AAAA-MM-JJ                force le nom du dossier daté
    """)
}

func humanBytes(_ bytes: UInt64) -> String {
    let units = ["o", "Ko", "Mo", "Go", "To"]
    var value = Double(bytes)
    var unit = 0
    while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
    return unit == 0 ? "\(bytes) o" : String(format: "%.1f %@", value, units[unit])
}

func describe(_ take: Take) -> String {
    let marker = take.isHighlighted ? "★" : " "
    let chapters = take.chapters.count == 1 ? "1 chapitre" : "\(take.chapters.count) chapitres"
    let moments = take.isHighlighted ? ", \(take.momentCount) moment(s)" : ""
    return "  \(marker) prise \(take.number) — \(chapters), \(humanBytes(take.totalSize))\(moments)"
}

func requireGoProCard(_ volume: URL) {
    guard CardScanner.isGoProCard(volume) else {
        fail("aucun dossier DCIM/###GOPRO sous \(volume.path) — ce n'est pas une carte GoPro")
    }
}

// MARK: - Commandes

func commandHiLight(_ paths: [String]) -> Int32 {
    guard !paths.isEmpty else { printUsage(); return 1 }
    for path in paths {
        let url = URL(fileURLWithPath: path)
        do {
            let scan = try HiLightReader.scan(fileURL: url)
            let moments = scan.moments.map { String(format: "%.3f s", Double($0) / 1000) }
            print("\(url.lastPathComponent) : \(scan.moments.count) moment(s)"
                  + (moments.isEmpty ? "" : " — " + moments.joined(separator: ", ")))
            if let anomaly = scan.anomaly { print("   note : \(anomaly)") }
        } catch {
            print("\(url.lastPathComponent) : illisible — \(error)")
        }
    }
    return 0
}

func commandScan(_ arguments: [String]) -> Int32 {
    guard let path = arguments.first else { printUsage(); return 1 }
    let volume = URL(fileURLWithPath: path, isDirectory: true)
    requireGoProCard(volume)

    do {
        let result = try CardScanner.scan(volume: volume)
        print("\(result.takes.count) prise(s), dont \(result.highlightedTakes.count) taguée(s)"
              + " — \(humanBytes(result.totalSize))")
        for take in result.takes { print(describe(take)) }
        if !result.ignored.isEmpty {
            print("\(result.ignored.count) fichier(s) ignoré(s) — .LRV, .THM, noms hors convention")
        }
        return 0
    } catch {
        fail("échec du scan : \(error)")
    }
}

func commandImport(_ arguments: [String]) -> Int32 {
    guard arguments.count >= 2 else { printUsage(); return 1 }
    let volume = URL(fileURLWithPath: arguments[0], isDirectory: true)
    let library = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let dryRun = arguments.contains("--dry-run")

    var folderName = ImportFolderName.iso(for: Date())
    if let flag = arguments.firstIndex(of: "--date"), flag + 1 < arguments.count {
        folderName = arguments[flag + 1]
    }

    requireGoProCard(volume)

    do {
        let result = try CardScanner.scan(volume: volume)
        var index = ImportIndexStore.load(fromLibrary: library)
        let plan = ImportPlanner.plan(takes: result.takes, into: library,
                                      folderName: folderName, index: index)

        print("destination : \(plan.importFolder.path)")
        print("\(plan.copies.count) fichier(s) à copier — \(humanBytes(plan.byteCount))"
              + ", \(plan.highlightedTakeCount) prise(s) taguée(s) sur \(plan.takeCount)")
        if !plan.alreadyImported.isEmpty {
            print("\(plan.alreadyImported.count) déjà importé(s), ignoré(s)")
        }

        if dryRun {
            for copy in plan.copies { print("  \(copy.source.filename) -> \(copy.relativeDestination)") }
            return 0
        }

        var lastPercent = -1
        let report = ImportRunner.run(plan, library: library, index: &index, progress: { progress in
            let percent = Int(progress.fraction * 100)
            if percent != lastPercent {
                lastPercent = percent
                FileHandle.standardError.write(Data("\r\(percent) %  \(progress.currentFile)     ".utf8))
            }
        })
        FileHandle.standardError.write(Data("\r\u{1B}[K".utf8))

        try? ImportIndexStore.save(index, toLibrary: library)

        print("importé : \(report.copied.count) fichier(s), \(humanBytes(report.copiedBytes))")
        print("highlights : \(report.highlightsFolder.path)")
        for failure in report.failures {
            print("  échec — \(failure.source.lastPathComponent) : \(failure.reason)")
        }
        if report.wasCancelled { print("interrompu") }
        return report.failures.isEmpty ? 0 : 2
    } catch {
        fail("échec de l'import : \(error)")
    }
}

// MARK: - Aiguillage

let commandLine = Array(CommandLine.arguments.dropFirst())
let rest = Array(commandLine.dropFirst())

switch commandLine.first {
case "hilight": exit(commandHiLight(rest))
case "scan":    exit(commandScan(rest))
case "import":  exit(commandImport(rest))
default:        printUsage(); exit(commandLine.isEmpty ? 1 : 0)
}

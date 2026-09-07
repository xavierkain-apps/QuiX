// swift-tools-version: 6.0
import PackageDescription

// QuiXCore ne dépend que de Foundation : aucune référence à AppKit ou AVFoundation.
// C'est ce qui lui permet de se compiler et de se tester sur Linux, où l'app ne peut pas.
// Toute la valeur du produit — lecture des tags HiLight, regroupement par prise, copie
// vérifiée — vit ici, et se prouve en intégration continue sans machine Apple.
let package = Package(
    name: "QuiXCore",
    products: [
        .library(name: "QuiXCore", targets: ["QuiXCore"]),
        .executable(name: "quix", targets: ["quix"])
    ],
    targets: [
        .target(
            name: "QuiXCore",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "quix",
            dependencies: ["QuiXCore"],
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "QuiXCoreTests",
            dependencies: ["QuiXCore"],
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormationFocusedSourceTrace",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "FormationFocusedSourceTraceCLI",
            dependencies: [
                .product(name: "BirdFlowMetal", package: "BirdFlowMetal")
            ]
        )
    ]
)

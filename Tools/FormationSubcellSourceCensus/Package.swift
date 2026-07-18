// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormationSubcellSourceCensus",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "FormationSubcellSourceCensusCLI",
            dependencies: [
                .product(name: "BirdFlowMetal", package: "BirdFlowMetal")
            ]
        )
    ]
)

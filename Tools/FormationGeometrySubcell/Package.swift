// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FormationGeometrySubcell",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "FormationGeometrySubcellCLI",
            dependencies: [
                .product(name: "BirdFlowMetal", package: "BirdFlowMetal")
            ]
        )
    ]
)

// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BirdFlowMetal",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "BirdFlowCore", targets: ["BirdFlowCore"]),
        .library(name: "BirdFlowMetal", targets: ["BirdFlowMetal"]),
        .library(
            name: "BirdFlowVisualization",
            targets: ["BirdFlowVisualization"]
        ),
        .executable(name: "birdflow", targets: ["BirdFlowCLI"]),
        .executable(
            name: "birdflow-formation-geometry",
            targets: ["FormationGeometryBridgeCLI"]
        ),
        .executable(name: "birdflow-viewer", targets: ["BirdFlowViewerApp"])
    ],
    targets: [
        .target(name: "BirdFlowCore"),
        .target(
            name: "BirdFlowMetal",
            dependencies: ["BirdFlowCore"],
            resources: [
                .copy("Metal")
            ]
        ),
        .executableTarget(
            name: "BirdFlowCLI",
            dependencies: ["BirdFlowCore", "BirdFlowMetal"]
        ),
        .executableTarget(
            name: "FormationGeometryBridgeCLI",
            dependencies: ["BirdFlowMetal"]
        ),
        .target(
            name: "BirdFlowVisualization",
            dependencies: ["BirdFlowCore", "BirdFlowMetal"],
            resources: [
                .copy("Metal")
            ]
        ),
        .executableTarget(
            name: "BirdFlowViewerApp",
            dependencies: [
                "BirdFlowCore",
                "BirdFlowMetal",
                "BirdFlowVisualization",
            ]
        ),
        .testTarget(
            name: "BirdFlowCoreTests",
            dependencies: ["BirdFlowCore"]
        ),
        .testTarget(
            name: "BirdFlowMetalTests",
            dependencies: ["BirdFlowCore", "BirdFlowMetal"]
        ),
        .testTarget(
            name: "BirdFlowVisualizationTests",
            dependencies: [
                "BirdFlowCore",
                "BirdFlowMetal",
                "BirdFlowVisualization",
            ]
        )
    ]
)

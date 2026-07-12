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
        .executable(name: "birdflow", targets: ["BirdFlowCLI"])
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
        .testTarget(
            name: "BirdFlowCoreTests",
            dependencies: ["BirdFlowCore"]
        ),
        .testTarget(
            name: "BirdFlowMetalTests",
            dependencies: ["BirdFlowCore", "BirdFlowMetal"]
        )
    ]
)

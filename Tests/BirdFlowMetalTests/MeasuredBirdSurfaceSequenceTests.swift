@testable import BirdFlowMetal
import Foundation
import Testing

private var measuredBirdSurfaceManifestURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(
            "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
        )
}

@Test
func measuredBirdSurfaceLoaderLocksIndexedNonperiodicContract() throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    #expect(
        dataset.datasetIdentifier
            == "deetjen-ob-2018-12-11-f03-complete-surface-v1"
    )
    #expect(dataset.scientificTier == "derived-measured-complete-surface")
    #expect(dataset.sourceLicense == "CC0-1.0")
    #expect(dataset.frameCount == 144)
    #expect(dataset.vertexCount == 2_157)
    #expect(dataset.triangleCount == 3_968)
    #expect(dataset.components.map(\.name) == [
        "body", "leftWing", "rightWing", "tail",
    ])
    #expect(dataset.components.map(\.partIdentifier) == [1, 2, 3, 4])
    #expect(dataset.trianglePartIdentifiers.count == 3_968)
    #expect(dataset.completeBirdSurfaceReady)
    #expect(!dataset.quantitativeForceAcceptanceReady)
    #expect(
        dataset.manifestSHA256
            == "ad42148aa9ee72d994d668ba16f8b6572cb8b192b77539fe66d97586ed9e1a13"
    )
    #expect(
        abs(dataset.maximumPointSpeedMetersPerSecond - 25.230_47) < 1e-4
    )

    for frame in [0, 33, 89, 126, 143] {
        let vertex = dataset.components[frame == 143 ? 3 : 1].vertexOffset
        let state = dataset.state(
            timeSeconds: dataset.frameTimesSeconds[frame],
            vertexIndex: vertex
        )
        let source = dataset.vertex(frame: frame, index: vertex)
        #expect(vectorError(state.positionMeters, source) < 1e-7)
        #expect(state.velocityMetersPerSecond.x.isFinite)
        #expect(state.velocityMetersPerSecond.y.isFinite)
        #expect(state.velocityMetersPerSecond.z.isFinite)
    }
}

@Test
func measuredBirdSurfaceLoaderRejectsBinaryDrift() throws {
    let sourceDirectory = measuredBirdSurfaceManifestURL
        .deletingLastPathComponent()
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    for name in ["manifest.json", "positions.f32le", "triangles.u16le"] {
        try FileManager.default.copyItem(
            at: sourceDirectory.appendingPathComponent(name),
            to: temporaryDirectory.appendingPathComponent(name)
        )
    }
    let positionsURL = temporaryDirectory.appendingPathComponent(
        "positions.f32le"
    )
    var positions = try Data(contentsOf: positionsURL)
    positions[0] ^= 0x1
    try positions.write(to: positionsURL)
    #expect(throws: MeasuredBirdSurfaceSequenceError.self) {
        _ = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: temporaryDirectory.appendingPathComponent(
                "manifest.json"
            )
        )
    }
}

#if canImport(Metal)
@Test
func indexedBirdSurfaceMetalGeometryClosesAllFramesAndCPUMilestones() throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let report = try MetalIndexedBirdSurfaceValidator.audit(dataset)
    #expect(report.passed)
    #expect(report.frameAudits.count == 144)
    #expect(report.cpuRasterMilestoneFrames == [0, 33, 89, 126, 143])
    #expect(report.fractionalInterpolationProbeTimesSeconds.count == 5)
    #expect(report.maximumPreparedPositionErrorMeters <= 2e-7)
    #expect(report.maximumPreparedVelocityErrorMetersPerSecond <= 5e-3)
    #expect(report.maximumCPUMaskMismatchCellCount == 0)
    #expect(report.maximumCPUWallVelocityDifferenceLattice <= 2.5e-5)
    #expect(report.maximumCPUSignedDistanceDifferenceCells <= 2e-5)
    #expect(report.allComponentsPresentEveryFrame)
    #expect(report.allValuesFinite)
    #expect(!report.fluidCollisionExecuted)
    #expect(!report.forceAccumulationExecuted)
    #expect(report.frameAudits.allSatisfy {
        $0.componentSolidCellCounts.count == 4
            && $0.componentSolidCellCounts.allSatisfy { $0 > 0 }
    })
}

@Test
func indexedBirdSurfaceClosesProductionMovingBoundaryImpulse() throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let report = try MetalIndexedBirdSurfaceCouplingValidator.audit(dataset)
    #expect(report.passed)
    #expect(report.steps >= 8)
    #expect(report.newlyCoveredCellEvents > 0)
    #expect(report.newlyUncoveredCellEvents > 0)
    #expect(report.persistentBoundaryLinkEvents > 0)
    #expect(report.maximumTopologyCounterMismatchCells == 0)
    #expect(report.componentSolidCellCounts.count == 4)
    #expect(report.componentSolidCellCounts.allSatisfy { $0 > 0 })
    #expect(report.periodicBoundaries)
    #expect(report.spongeStrength == 0)
    #expect(report.maximumWallMach <= 0.15)
    #expect(report.relativeRMSBoundaryClosureResidual <= 0.005)
    #expect(report.allValuesFinite)
    #expect(report.fluidKernel == "stepFluidTRT")
    #expect(report.forceEstimator == "conservative-moving-domain-mode-6")
    #expect(report.samples.allSatisfy {
        $0.sourceLedgerTransitionCellCount
            == $0.newlyCoveredCellCount + $0.newlyUncoveredCellCount
            && $0.farFieldImpulseToFluid == .zero
            && $0.spongeImpulseToFluid == .zero
    })
}
#endif

private func vectorError(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>
) -> Float {
    let delta = first - second
    return sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
}

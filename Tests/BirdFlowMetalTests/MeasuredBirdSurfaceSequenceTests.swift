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

private var measuredBirdForceTargetURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(
            "ValidationInputs/deetjen-ob-f03-force-v1.json"
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

@Test
func measuredBirdForceTargetLocksAxesTimingAndCoreWindow() throws {
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    #expect(target.sampleCount == 287)
    #expect(target.comparisonSampleCount == 187)
    #expect(target.comparisonFirstSourceFrame == -1_918)
    #expect(target.comparisonLastSourceFrame == -1_825)
    #expect(target.comparisonFirstSampleIndex == 50)
    #expect(target.comparisonLastSampleIndex == 236)
    #expect(abs(target.comparisonFirstTimeSeconds - 0.025) <= 1e-12)
    #expect(abs(target.comparisonLastTimeSeconds - 0.118) <= 1e-12)
    #expect(target.forceXNewtons.count == target.sampleCount)
    #expect(target.forceZNewtons.count == target.sampleCount)
    #expect(
        target.targetSHA256
            == "0ec3caf21e4b22c2f7dd81e9d5b129fec2d0535dac147d486446975144d6b12c"
    )
}

@Test
func measuredBirdCoarsePilotPlanLocksCostAndClaimBoundary() throws {
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let plan = try MetalIndexedBirdSurfacePilotValidator.plan(
        surface: surface,
        target: target
    )
    #expect(plan.fluidStepsPerForceSample == 16)
    #expect(abs(plan.fluidTimeStepSeconds - 0.000_031_25) <= 1e-12)
    #expect(plan.preRollFluidSteps == 800)
    #expect(plan.totalFluidSteps == 3_776)
    #expect(plan.comparisonForceSamples == 187)
    #expect(plan.maximumWallMach <= 0.15)
    #expect(!plan.sourceViscosityRepresentableAtPilotGrid)
    #expect(plan.sourceConditionTauPlusAtPilotGrid < plan.minimumAllowedTauPlus)
    #expect(plan.pilotToSourceViscosityRatio > 1)
    #expect(!plan.experimentalAgreementGateApplied)
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionPreRollPopulationDiagnosticStride == 1
    )
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionPreRollMaximumActivationFraction == 0.05
    )
    let operators = MetalIndexedBirdSurfacePilotValidator
        .collisionPreRollOperators
    #expect(operators.map(\.rawValue) == [
        "production-trt",
        "positivity-preserving-regularized-bgk",
        "positivity-preserving-recursive-regularized-bgk",
    ])
    #expect(operators.map(\.caseParameterW) == [-1, -3, -4])
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

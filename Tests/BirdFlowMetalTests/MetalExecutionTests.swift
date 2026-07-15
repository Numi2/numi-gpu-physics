@testable import BirdFlowMetal
import BirdFlowCore
import Foundation
import Testing

private var measuredFixtureURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Examples/measured-bird-schema-v1.json")
}

@Test
func measuredBirdFixtureAuditsAndReplaysThroughProductionMetal() throws {
    let loaded = try MeasuredBirdDatasetLoader.load(from: measuredFixtureURL)
    let audit = try MeasuredBirdReplay.audit(loaded, chordCells: 12)

    #expect(audit.passed)
    #expect(audit.geometryRepresentation == "registeredAnalyticProxyV1")
    #expect(audit.kinematicKeyframeCount == 4)
    #expect(audit.estimatedMaximumLatticeMach <= 0.15)
    #expect(audit.sourceSHA256.count == 64)

    let dataset = loaded.dataset
    let scaling = try LatticeScaling(
        characteristicLengthMeters: dataset.geometry.wingRootChordMeters,
        characteristicLengthCells: 12,
        referenceSpeedMetersPerSecond:
            dataset.replay.referenceSpeedMetersPerSecond,
        targetReynoldsNumber: dataset.replay.targetReynoldsNumber,
        physicalAirDensity: dataset.replay.physicalAirDensity,
        latticeReferenceSpeed: dataset.replay.latticeReferenceSpeed
    )
    let configuration = try SimulationConfiguration(
        grid: audit.grid,
        domainOriginMeters: dataset.replay.domainOriginMeters,
        scaling: scaling,
        physicalAirDensity: dataset.replay.physicalAirDensity,
        farFieldVelocityMetersPerSecond:
            dataset.replay.farFieldVelocityMetersPerSecond,
        spongeWidthCells: 10,
        spongeStrength: dataset.replay.spongeStrength,
        gravityMetersPerSecondSquared:
            dataset.replay.gravityMetersPerSecondSquared
    )
    let simulation = try BirdFlowSimulation(
        configuration: configuration,
        bird: dataset.geometry.birdParameters(
            measuredKinematics: dataset.kinematics
        ),
        initialBodyState: BirdBodyState(
            positionMeters: dataset.replay.bodyPositionMeters,
            orientationBodyToWorld:
                dataset.replay.bodyOrientationBodyToWorld
        )
    )
    let frame = try #require(simulation.acquireLatestGPUFieldFrame())
    #expect(
        abs(
            frame.metadata.geometry.leftChord.w
                - dataset.kinematics.keyframes[0].left.tipTwistRadians
        ) < 1e-6
    )
    #expect(
        abs(
            frame.metadata.geometry.leftAngularVelocity.w
                - dataset.kinematics.keyframes[0]
                    .left.tipTwistRateRadiansPerSecond
        ) < 1e-5
    )
    frame.releaseImmediately()

    let report = try MeasuredBirdReplay.run(
        loaded,
        chordCells: 12,
        steps: 2,
        batchSize: 1
    )
    #expect(report.passed)
    #expect(report.samples.count == 2)
    #expect(report.samples.allSatisfy {
        $0.aerodynamicLoad.forceNewtons.x.isFinite
            && $0.aerodynamicLoad.forceNewtons.y.isFinite
            && $0.aerodynamicLoad.forceNewtons.z.isFinite
    })
}

@Test
func measuredBirdLoaderRejectsUnknownKeys() throws {
    let source = try String(contentsOf: measuredFixtureURL, encoding: .utf8)
    let invalid = source.replacingOccurrences(
        of: "\"schemaVersion\": 1,",
        with: "\"schemaVersion\": 1, \"unknownScientificUnit\": 7,"
    )
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("birdflow-invalid-measured-\(UUID()).json")
    try Data(invalid.utf8).write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(throws: MeasuredBirdReplayError.self) {
        _ = try MeasuredBirdDatasetLoader.load(from: url)
    }
}

#if canImport(Metal)
import Metal

func compactMetalTestCase(freeFlight: Bool = false) throws -> (
    configuration: SimulationConfiguration,
    bird: BirdParameters,
    state: BirdBodyState
) {
    let bird = BirdParameters(
        bodyRadiiMeters: SIMD3<Float>(0.015, 0.011, 0.012),
        massKilograms: 0.025,
        principalInertiaKilogramMetersSquared: SIMD3<Float>(
            0.000_004,
            0.000_007,
            0.000_008
        ),
        wingSpanMeters: 0.025,
        wingRootChordMeters: 0.020,
        wingTipChordMeters: 0.012,
        wingThicknessMeters: 0.008,
        wingSweepMeters: 0.004,
        wingRootOffsetMeters: SIMD3<Float>(0, 0.010, 0.003),
        tailLengthMeters: 0.020,
        tailHalfWidthMeters: 0.014,
        tailThicknessMeters: 0.008,
        wingKinematics: WingKinematics(
            frequencyHz: 3,
            strokeAmplitudeRadians: 0.25,
            pitchMeanRadians: 0,
            pitchAmplitudeRadians: 0.15,
            pitchPhaseRadians: 0.4
        )
    )
    let grid = try GridSize(x: 48, y: 48, z: 48)
    let scaling = try LatticeScaling(
        characteristicLengthMeters: bird.wingRootChordMeters,
        characteristicLengthCells: 8,
        referenceSpeedMetersPerSecond: 1,
        targetReynoldsNumber: 100,
        physicalAirDensity: 1.225,
        latticeReferenceSpeed: 0.03
    )
    let configuration = try SimulationConfiguration(
        grid: grid,
        domainOriginMeters: .zero,
        scaling: scaling,
        farFieldVelocityMetersPerSecond: freeFlight
            ? .zero
            : SIMD3<Float>(-1, 0, 0),
        spongeWidthCells: 4,
        spongeStrength: 0.04,
        freeFlight: freeFlight,
        gravityMetersPerSecondSquared: .zero,
        fastMath: false
    )
    let state = BirdBodyState(
        positionMeters: configuration.domainSizeMeters * 0.5,
        linearVelocityMetersPerSecond: freeFlight
            ? SIMD3<Float>(1, 0, 0)
            : .zero
    )
    return (configuration, bird, state)
}

@Test
func metalBatchPartitionPreservesLoadsAndCapturedFields() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase()
    let batched = try BirdFlowSimulation(
        configuration: testCase.configuration,
        bird: testCase.bird,
        initialBodyState: testCase.state
    )
    let singleStep = try BirdFlowSimulation(
        configuration: testCase.configuration,
        bird: testCase.bird,
        initialBodyState: testCase.state
    )

    // Exercises two queued command buffers with only the final fluid step
    // capturing density/velocity, then compares against a synchronized stepwise
    // execution of the identical command graph.
    try batched.advance(steps: 16, batchSize: 4)
    for _ in 0..<16 {
        try singleStep.advance(steps: 1, batchSize: 1)
    }

    let batchedSnapshot = try batched.snapshot()
    let singleSnapshot = try singleStep.snapshot()
    #expect(batchedSnapshot.step == singleSnapshot.step)
    #expect(batchedSnapshot.timeSeconds == singleSnapshot.timeSeconds)
    #expect(
        vectorLength(
            batchedSnapshot.aerodynamicLoad.forceNewtons
                - singleSnapshot.aerodynamicLoad.forceNewtons
        ) < 1e-6
    )
    #expect(
        vectorLength(
            batchedSnapshot.aerodynamicLoad.torqueNewtonMeters
                - singleSnapshot.aerodynamicLoad.torqueNewtonMeters
        ) < 1e-6
    )

    let batchedFields = try batched.copyMacroscopicFields()
    let singleFields = try singleStep.copyMacroscopicFields()
    var maximumDensityDifference: Float = 0
    var maximumVelocityDifference: Float = 0
    for index in batchedFields.density.indices {
        maximumDensityDifference = max(
            maximumDensityDifference,
            abs(batchedFields.density[index] - singleFields.density[index])
        )
        maximumVelocityDifference = max(
            maximumVelocityDifference,
            vectorLength(
                batchedFields.velocity[index] - singleFields.velocity[index]
            )
        )
    }
    #expect(maximumDensityDifference < 1e-6)
    #expect(maximumVelocityDifference < 1e-6)
    #expect(batchedSnapshot.aerodynamicLoad.forceNewtons.x.isFinite)
}

@Test
func metalFreeFlightBatchPartitionPreservesBodyState() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let batched = try BirdFlowSimulation(
        configuration: testCase.configuration,
        bird: testCase.bird,
        initialBodyState: testCase.state
    )
    let singleStep = try BirdFlowSimulation(
        configuration: testCase.configuration,
        bird: testCase.bird,
        initialBodyState: testCase.state
    )

    try batched.advance(steps: 8, batchSize: 2)
    for _ in 0..<8 {
        try singleStep.advance(steps: 1, batchSize: 1)
    }

    let a = try batched.snapshot()
    let b = try singleStep.snapshot()
    #expect(vectorLength(a.body.positionMeters - b.body.positionMeters) < 1e-6)
    #expect(
        vectorLength(
            a.body.linearVelocityMetersPerSecond
                - b.body.linearVelocityMetersPerSecond
        ) < 1e-6
    )
    #expect(
        vectorLength(
            a.body.angularVelocityBodyRadiansPerSecond
                - b.body.angularVelocityBodyRadiansPerSecond
        ) < 1e-6
    )
    #expect(
        vectorLength(
            a.body.orientationBodyToWorld.vector
                - b.body.orientationBodyToWorld.vector
        ) < 1e-6
    )
    #expect(
        abs(
            a.body.orientationBodyToWorld.scalar
                - b.body.orientationBodyToWorld.scalar
        ) < 1e-6
    )
    #expect(
        vectorLength(
            a.aerodynamicLoad.forceNewtons - b.aerodynamicLoad.forceNewtons
        ) < 1e-5
    )
    #expect(
        vectorLength(
            a.aerodynamicLoad.torqueNewtonMeters
                - b.aerodynamicLoad.torqueNewtonMeters
        ) < 1e-5
    )
}

@Test
func metalRigidBodyIntegratorMatchesCPUReferenceOneStep() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let backend = try MetalBackend(fastMath: false)
    let pipeline = try backend.pipeline(named: "integrateBirdBody")
    var initial = BirdBodyState(
        positionMeters: testCase.state.positionMeters,
        orientationBodyToWorld: Quaternion.axisAngle(
            axis: SIMD3<Float>(0.2, 0.7, -0.1),
            angle: 0.31
        ),
        linearVelocityMetersPerSecond: SIMD3<Float>(0.8, -0.1, 0.05),
        angularVelocityBodyRadiansPerSecond: SIMD3<Float>(0.3, -0.2, 0.1)
    )
    let force = SIMD3<Float>(0.03, -0.01, 0.02)
    let torque = SIMD3<Float>(0.000_01, -0.000_02, 0.000_015)
    let bodyBuffer = try backend.makeSharedBuffer(
        value: GPUBirdBodyState(initial)
    )
    let birdBuffer = try backend.makeSharedBuffer(
        value: GPUBirdParameters(testCase.bird)
    )
    let loadBuffer = try backend.makeSharedBuffer(
        value: GPUForceTorque(
            force: SIMD4<Float>(force.x, force.y, force.z, 0),
            torque: SIMD4<Float>(torque.x, torque.y, torque.z, 0)
        )
    )
    var uniforms = GPUUniforms(
        configuration: testCase.configuration,
        time: testCase.configuration.scaling.timeStepSeconds
    )

    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
    encoder.setBuffer(bodyBuffer, offset: 0, index: 0)
    encoder.setBuffer(birdBuffer, offset: 0, index: 1)
    encoder.setBuffer(loadBuffer, offset: 0, index: 2)
    encoder.setBytes(
        &uniforms,
        length: MemoryLayout<GPUUniforms>.stride,
        index: 3
    )
    backend.dispatch1D(encoder: encoder, pipeline: pipeline, count: 1)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)

    RigidBodyIntegrator.integrate(
        state: &initial,
        parameters: testCase.bird,
        forceWorldNewtons: force,
        torqueWorldNewtonMeters: torque,
        gravityWorldMetersPerSecondSquared: .zero,
        timeStepSeconds: testCase.configuration.scaling.timeStepSeconds
    )
    let gpu = bodyBuffer.contents()
        .assumingMemoryBound(to: GPUBirdBodyState.self)
        .pointee
        .coreValue
    #expect(vectorLength(gpu.positionMeters - initial.positionMeters) < 1e-6)
    #expect(
        vectorLength(
            gpu.linearVelocityMetersPerSecond
                - initial.linearVelocityMetersPerSecond
        ) < 1e-6
    )
    #expect(
        vectorLength(
            gpu.angularVelocityBodyRadiansPerSecond
                - initial.angularVelocityBodyRadiansPerSecond
        ) < 1e-6
    )
    #expect(
        vectorLength(
            gpu.orientationBodyToWorld.vector
                - initial.orientationBodyToWorld.vector
        ) < 1e-6
    )
    #expect(
        abs(
            gpu.orientationBodyToWorld.scalar
                - initial.orientationBodyToWorld.scalar
        ) < 1e-6
    )
}

@Test
func productionMetalShearWavePassesCanonicalGates() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalShearWaveValidator.run()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(report.cases.map(\.resolution) == [16, 24, 32])
    #expect(report.finestRelativeDecayError < report.maximumAllowedDecayError)
    #expect(
        report.maximumRelativeMassDrift < report.maximumAllowedMassDrift
    )
    #expect(
        report.estimatedOrder >= report.minimumRequiredConvergenceOrder
    )
    #expect(
        report.maximumPopulationDifferenceFromCPU
            < report.maximumAllowedCPUReferenceDifference
    )
    #expect(
        report.maximumBatchDensityDifference
            < report.maximumAllowedBatchDifference
    )
    #expect(
        report.maximumBatchVelocityDifference
            < report.maximumAllowedBatchDifference
    )
    #expect(report.passed)
}

@Test
func productionMetalMovingWallPassesCanonicalGates() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalMovingWallValidator.run()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(report.couetteCases.map(\.resolution) == [16, 24, 32])
    #expect(report.oscillatingCases.map(\.resolution) == [16, 24, 32])
    #expect(
        report.couetteCases.allSatisfy {
            $0.normalizedProfileL2Error < report.maximumAllowedProfileError
                && $0.relativeTopWallForceError
                    < report.maximumAllowedCouetteForceError
                && $0.maximumCrossFlowSpeed
                    < report.maximumAllowedCrossFlowSpeed
        }
    )
    #expect(
        report.oscillatingCases.allSatisfy {
            $0.normalizedProfileL2Error < report.maximumAllowedProfileError
                && $0.relativeForcePhasorError
                    < report.maximumAllowedOscillatingForceError
                && abs($0.forcePhaseErrorRadians)
                    < report.maximumAllowedForcePhaseErrorRadians
                && $0.maximumCrossFlowSpeed
                    < report.maximumAllowedCrossFlowSpeed
        }
    )
    #expect(
        report.oscillatingProfileConvergenceOrder
            >= report.minimumRequiredProfileConvergenceOrder
    )
    #expect(
        report.couetteForceConvergenceOrder
            >= report.minimumRequiredForceConvergenceOrder
    )
    #expect(
        report.oscillatingForceConvergenceOrder
            >= report.minimumRequiredForceConvergenceOrder
    )
    #expect(
        report.maximumBatchDensityDifference
            < report.maximumAllowedBatchDifference
    )
    #expect(
        report.maximumBatchVelocityDifference
            < report.maximumAllowedBatchDifference
    )
    #expect(
        report.maximumBatchForceDifference
            < report.maximumAllowedBatchDifference
    )
    #expect(report.passed)
}

@Test
func productionMetalHighReFixedMovingWallRemainsFinite() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalMovingWallValidator.runHighReStability()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(!report.topologyChanges)
    #expect(report.cases.map(\.matchedBirdChordCells) == [8, 12, 16])
    #expect(report.cases.allSatisfy {
        $0.finiteSteps == report.requestedSteps
            && $0.firstNonFiniteStep == nil
            && $0.fieldsFinite
            && $0.loadsFinite
            && ($0.relativePopulationMassDrift ?? .infinity)
                <= report.maximumAllowedRelativePopulationMassDrift
            && ($0.maximumAbsolutePopulation ?? .infinity)
                <= report.maximumAllowedAbsolutePopulation
            && $0.passed
    })
    #expect(report.passed)
}

@Test
func productionMetalTranslatingBodyTopologyClosesMomentumBudget() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator.run()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(report.topologyKernel == "buildTranslatingSphereTopology")
    #expect(report.displacementCells >= 2)
    #expect(report.newlyCoveredCellEvents > 0)
    #expect(report.newlyUncoveredCellEvents > 0)
    #expect(report.topologyTransitionSteps > 0)
    #expect(report.maximumSolidControlSurfaceCrossingLinkCount == 0)
    #expect(
        report.maximumConservativeForceResidual
            <= report.maximumAllowedConservativeForceResidual
    )
    #expect(
        report.conservativeRelativeRMSResidual
            <= report.maximumAllowedConservativeRelativeRMSResidual
    )
    #expect(
        report.conservativeImprovementFactor
            >= report.minimumRequiredImprovementFactor
    )
    #expect(
        report.maximumRawBudgetDifferenceBetweenRuns
            <= report.maximumAllowedRawBudgetDifferenceBetweenRuns
    )
    #expect(report.passed)
}

@Test
func productionMetalHighReTranslatingBodyLocalizesInstability() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runHighReStability()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(report.topologyKernel == "buildTranslatingSphereTopology")
    #expect(report.topologyChanges)
    #expect(report.translationSpeedLattice > 0)
    #expect(report.wallVelocityLattice > 0)
    #expect(report.cases.map(\.matchedBirdChordCells) == [8, 12, 16])
    #expect(report.cases.allSatisfy {
        guard let firstInvalid = $0.firstNonFiniteLoadStep else {
            return false
        }
        return (200...400).contains(firstInvalid)
            && $0.finiteLoadSteps == firstInvalid - 1
            && !$0.populationsFinite
            && !$0.fieldsFinite
            && !$0.loadsFinite
            && $0.newlyCoveredCellEvents > 0
            && $0.newlyUncoveredCellEvents > 0
            && $0.topologyTransitionSteps > 0
            && $0.maximumSolidControlSurfaceCrossingLinkCount == 0
            && !$0.passed
    })
    #expect(!report.passed)
}

@Test
func productionMetalHighReFixedOccupancySphereLocalizesCurvedLinkInstability()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runHighReFixedOccupancyStability()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(report.topologyKernel == "buildTranslatingSphereTopology")
    #expect(!report.topologyChanges)
    #expect(report.translationSpeedLattice == 0)
    #expect(report.wallVelocityLattice > 0)
    #expect(report.cases.map(\.matchedBirdChordCells) == [8, 12, 16])
    #expect(report.cases.allSatisfy {
        guard let firstInvalid = $0.firstNonFiniteLoadStep else {
            return false
        }
        return (50...100).contains(firstInvalid)
            && $0.finiteLoadSteps == firstInvalid - 1
            && !$0.populationsFinite
            && !$0.fieldsFinite
            && !$0.loadsFinite
            && $0.newlyCoveredCellEvents == 0
            && $0.newlyUncoveredCellEvents == 0
            && $0.topologyTransitionSteps == 0
            && $0.maximumSolidControlSurfaceCrossingLinkCount == 0
            && !$0.passed
    })
    #expect(!report.passed)
}

@Test
func productionMetalHighReWallComponentDecompositionConfirmsGeneralInstability()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runHighReFixedOccupancyWallDecomposition()

    #expect(report.diagnosticCompleted)
    #expect(
        report.classification
            == "general-curved-moving-link-instability-confirmed"
    )
    #expect(!report.tangential.passed)
    #expect(!report.normal.passed)
    #expect(report.tangential.wallVelocityMode == "tangential-only")
    #expect(report.normal.wallVelocityMode == "normal-only")
    #expect(
        report.tangential.cases.compactMap(\.firstNonFiniteLoadStep)
            == [186, 187, 189]
    )
    #expect(
        report.normal.cases.compactMap(\.firstNonFiniteLoadStep)
            == [86, 86, 86]
    )
    #expect(
        (report.tangential.cases + report.normal.cases).allSatisfy {
            $0.newlyCoveredCellEvents == 0
                && $0.newlyUncoveredCellEvents == 0
                && $0.topologyTransitionSteps == 0
                && !$0.passed
        }
    )
}

@Test
func productionMetalHighReStationaryWallSphereConfirmsGeneralCurvedLinkInstability()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runHighReStationaryWallSphereStability()

    #expect(!report.passed)
    #expect(
        report.classification
            == "high-re-stationary-wall-sphere-unstable-general-curved-link-path-confirmed"
    )
    #expect(!report.topologyChanges)
    #expect(!report.periodicBoundaries)
    #expect(report.spongeStrength > 0)
    #expect(report.translationSpeedLattice == 0)
    #expect(report.wallVelocityLattice == 0)
    #expect(report.wallVelocityMode == "stationary")
    #expect(report.farFieldVelocityLattice > 0)
    #expect(report.cases.map(\.matchedBirdChordCells) == [8, 12, 16])
    #expect(
        report.cases.compactMap(\.firstNonFiniteLoadStep)
            == [105, 105, 105]
    )
    #expect(report.cases.allSatisfy {
        $0.finiteLoadSteps == 104
            && !$0.populationsFinite
            && !$0.fieldsFinite
            && !$0.loadsFinite
            && $0.newlyCoveredCellEvents == 0
            && $0.newlyUncoveredCellEvents == 0
            && $0.topologyTransitionSteps == 0
            && $0.maximumSolidControlSurfaceCrossingLinkCount == 0
            && ($0.maximumMeasuredForceMagnitude ?? 0) > 0.01
            && $0.relativeResidualGateApplied
            && !$0.passed
    })
}

@Test
func productionMetalStationaryWallRelaxationSweepBracketsMonotonicThreshold()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallRelaxationSweep()

    #expect(report.diagnosticCompleted)
    #expect(
        report.classification
            == "stationary-wall-relaxation-threshold-bracketed"
    )
    #expect(report.firstTransitionBracketed)
    #expect(report.stabilityMonotonicWithMargin)
    #expect(report.thresholdBracketed)
    #expect(report.points.count == 14)
    #expect(
        report.points.map(\.stabilityPassed)
            == [
                false, false, false, false, false, false, true,
                true, true, true, true, true, true, true,
            ]
    )
    #expect(
        report.points.map(\.firstNonFiniteLoadStep)
            == [
                105, 107, 112, 123, 208, 454, nil,
                nil, nil, nil, nil, nil, nil, nil,
            ]
    )
    #expect(report.unstableTauPlusMarginsAfterFirstStable.isEmpty)
    #expect(
        abs((report.firstTransitionLowerUnstableTauPlusMarginAboveHalf ?? 0)
            - 0.009_999_990_463_256_836) < 1.0e-12
    )
    #expect(
        abs((report.firstTransitionUpperStableTauPlusMarginAboveHalf ?? 0)
            - 0.012_499_988_079_071_045) < 1.0e-12
    )
    #expect(report.points.allSatisfy {
        $0.newlyCoveredCellEvents == 0
            && $0.newlyUncoveredCellEvents == 0
            && $0.topologyTransitionSteps == 0
            && ($0.maximumMeasuredForceMagnitude ?? 0) > 0
            && !$0.fullAcceptancePassed
    })
}

@Test
func productionMetalStationaryWallLongHorizonSurvivesCorrectedThreshold()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallLongHorizonSurvival()

    #expect(report.diagnosticCompleted)
    #expect(
        report.classification
            == "stationary-wall-apparent-stability-survives-1000"
    )
    #expect(report.survivingPointCount == 3)
    #expect(report.allApparentStablePointsSurvived)
    #expect(
        report.points.map(\.firstNonFiniteLoadStep)
            == [nil, nil, nil]
    )
    #expect(report.points.allSatisfy {
        $0.stabilityPassed
            && !$0.fullAcceptancePassed
            && $0.populationsFinite
            && $0.fieldsFinite
            && $0.loadsFinite
            && $0.newlyCoveredCellEvents == 0
            && $0.newlyUncoveredCellEvents == 0
            && $0.topologyTransitionSteps == 0
            && ($0.maximumMeasuredForceMagnitude ?? 0) > 0
    })
}

@Test
func productionMetalStationaryWallC16LocatesFirstPopulationPositivityLoss()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallC16PopulationPositivity()
    let repeated = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallC16PopulationPositivity()
    let firstNegative = try #require(report.firstNegative)
    let firstNonFinite = try #require(report.firstNonFinite)
    let repeatedNegative = try #require(repeated.firstNegative)
    let repeatedNonFinite = try #require(repeated.firstNonFinite)

    #expect(report.diagnosticCompleted)
    #expect(report.diagnosticKernel == "reducePopulationMinimum")
    #expect(
        report.classification
            == "stationary-wall-c16-first-positivity-loss-curved-boundary-adjacent-fluid-pull"
    )
    #expect(report.domainCells == SIMD3<Int>(56, 24, 24))
    #expect(report.matchedBirdChordCells == 16)
    #expect(report.completedSteps == 106)
    #expect(report.minimumHistory.count == report.completedSteps + 1)
    #expect((report.initialMinimum.minimumPopulation ?? 0) > 0)
    #expect(firstNegative.step == 27)
    #expect(firstNegative.directionIndex == 10)
    #expect(firstNegative.cell == SIMD3<Int>(5, 9, 12))
    #expect(firstNegative.pullSourceCell == SIMD3<Int>(6, 8, 12))
    #expect(firstNegative.cellAdjacentToSphere)
    #expect(!firstNegative.pullSourceIsSolid)
    #expect(!firstNegative.insideSponge)
    #expect(
        firstNegative.populationUpdatePath
            == "ordinary-fluid-pull-trt-collision"
    )
    #expect(
        abs(firstNegative.signedDistanceToSphereSurfaceCells
            - 0.320_714_214_271_425_2) < 1.0e-12
    )
    #expect(firstNonFinite.step == 105)
    #expect(firstNonFinite.directionIndex == 0)
    #expect(firstNonFinite.cell == SIMD3<Int>(2, 10, 9))
    #expect(firstNonFinite.valueClassification == "nan")
    #expect(report.firstNonFiniteLoadStep == 105)
    #expect(report.newlyCoveredCellEvents == 0)
    #expect(report.newlyUncoveredCellEvents == 0)
    #expect(report.topologyTransitionSteps == 0)
    #expect(repeatedNegative.step == firstNegative.step)
    #expect(repeatedNegative.directionIndex == firstNegative.directionIndex)
    #expect(repeatedNegative.cell == firstNegative.cell)
    #expect(repeatedNonFinite.step == firstNonFinite.step)
    #expect(repeatedNonFinite.directionIndex == firstNonFinite.directionIndex)
    #expect(repeatedNonFinite.cell == firstNonFinite.cell)
}

@Test
func productionMetalStationaryWallC16IsolatesSymmetricTRTOvershoot()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallC16TRTCollisionDecomposition()
    let repeated = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallC16TRTCollisionDecomposition()
    let failing = report.failingDirection

    #expect(report.diagnosticCompleted)
    #expect(
        report.classification
            == "stationary-wall-c16-trt-symmetric-relaxation-overshoot"
    )
    #expect(report.captureStep == 27)
    #expect(report.targetCell == SIMD3<Int>(5, 9, 12))
    #expect(report.targetAdjacentToSphere)
    #expect(!report.targetIsSolid)
    #expect(report.solidPullSourceCount == 5)
    #expect(report.outsideDomainPullSourceCount == 0)
    #expect(report.spongeFactor == 0)
    #expect(report.allPulledPopulationsPositive)
    #expect(report.directionTerms.count == D3Q19.count)
    #expect(report.minimumActualPostCollisionDirection == 10)
    #expect(report.dominantDestabilizingRelaxationMode == "symmetric")
    #expect(report.maximumAbsolutePredictionResidual <= 1.0e-7)
    #expect(report.maximumAbsoluteBoundaryWallCorrection == 0)
    #expect(report.failingBoundaryInterpolation == nil)
    #expect(failing.directionIndex == 10)
    #expect(failing.latticeDirection == SIMD3<Int>(-1, 1, 0))
    #expect(failing.pullSourceCell == SIMD3<Int>(6, 8, 12))
    #expect(failing.pullSourceInsideDomain)
    #expect(!failing.pullSourceIsSolid)
    #expect(abs(failing.pulledPopulation - 0.030_865_484_848_618_507) < 1e-12)
    #expect(
        abs(failing.symmetricRelaxationIncrement
            - -0.030_936_071_649_193_764) < 1e-12
    )
    #expect(
        abs(failing.antisymmetricRelaxationIncrement
            - 0.000_009_069_985_026_144_423) < 1e-12
    )
    #expect(failing.postWithoutSymmetricIncrement > 0)
    #expect(failing.postWithoutAntisymmetricIncrement < 0)
    #expect(abs(failing.actualPostCollision - -0.000_061_517_086_578_533_05) < 1e-12)
    #expect(report.newlyCoveredCellEvents == 0)
    #expect(report.newlyUncoveredCellEvents == 0)
    #expect(report.topologyTransitionSteps == 0)
    #expect(
        repeated.classification == report.classification
            && repeated.failingDirection.directionIndex
                == failing.directionIndex
            && repeated.failingDirection.pulledPopulation
                == failing.pulledPopulation
            && repeated.failingDirection.symmetricRelaxationIncrement
                == failing.symmetricRelaxationIncrement
            && repeated.failingDirection.antisymmetricRelaxationIncrement
                == failing.antisymmetricRelaxationIncrement
            && repeated.failingDirection.actualPostCollision
                == failing.actualPostCollision
    )
}

@Test
func productionMetalStationaryWallC16LimiterAttributesOpenFlowSources()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallC16SymmetricLimiterAB()
    let repeated = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallC16SymmetricLimiterAB()
    let control = report.control
    let treatment = report.treatment

    #expect(report.diagnosticCompleted)
    #expect(
        report.classification
            == "stationary-wall-c16-limiter-clears-positivity-open-flow-sources-attributed"
    )
    #expect(control.firstNegativePopulationStep == 27)
    #expect(control.firstNonFinitePopulationStep == 105)
    #expect(control.firstNonFiniteLoadStep == 105)
    #expect(control.limiterActivationCellSteps == 0)
    #expect(treatment.completedSteps == 500)
    #expect(treatment.firstNegativePopulationStep == nil)
    #expect(treatment.firstNonFinitePopulationStep == nil)
    #expect(treatment.firstNonFiniteLoadStep == nil)
    #expect(treatment.populationsFinite)
    #expect(treatment.fieldsFinite)
    #expect(treatment.loadsFinite)
    #expect(treatment.limiterActivationCellSteps == 1_417_658)
    #expect(treatment.limiterActivationSteps == 467)
    #expect(treatment.firstLimiterActivationStep == 27)
    #expect(treatment.firstZeroLimiterScaleStep == nil)
    #expect(treatment.maximumLimiterActivationsInOneStep == 6_819)
    #expect(treatment.minimumLimiterScale == 0.001_427_769_660_949_707)
    #expect(!treatment.stabilityPassed)
    #expect(!treatment.forceBudgetPassed)
    #expect(!treatment.fullAcceptancePassed)
    #expect(
        abs((treatment.relativePopulationMassDrift ?? 0)
            - 0.001_828_893_701_613_996_1) < 1e-12
    )
    #expect(
        abs((treatment.minimumObservedPopulation ?? 0)
            - 8.728_420_652_914_792e-9) < 1e-16
    )
    #expect(
        abs((treatment.maximumConservativeForceResidual ?? 0)
            - 0.240_913_338_520_273_2) < 1e-10
    )
    #expect(
        abs((treatment.conservativeRelativeRMSResidual ?? 0)
            - 0.039_365_997_984_204_02) < 1e-10
    )
    #expect(report.maximumPreActivationMeasuredForceDifference == 0)
    #expect(report.maximumPreActivationBudgetForceDifference == 0)
    let ledger = report.treatmentConservationLedger
    #expect(ledger.samples.count == 500)
    #expect(ledger.samples.map(\.step) == Array(1...500))
    #expect(ledger.globalLedgerClosed)
    #expect(ledger.forceResidualLedgerClosed)
    #expect(ledger.dominantGlobalMassContribution == "open-far-field")
    #expect(ledger.dominantControlVolumeMomentumContribution == "sponge")
    #expect(ledger.relativeCumulativeLimiterMassContribution < 1.0e-6)
    #expect(ledger.relativeRMSUnexplainedForceResidual < 5.0e-3)
    #expect(ledger.maximumPeakUnexplainedForceResidualFraction < 1.0e-2)
    #expect(ledger.relativeRMSBoundaryLoadClosureResidual < 1.0e-6)
    #expect(
        abs(ledger.cumulativeObservedGlobal.mass
            - -58.992_806_583_177_3) < 1.0e-9
    )
    #expect(
        abs(ledger.cumulativeFarFieldGlobal.mass
            - -212.358_820_101_246_24) < 1.0e-9
    )
    #expect(
        abs(ledger.cumulativeSpongeGlobal.mass
            - 152.514_207_968_932_17) < 1.0e-9
    )
    #expect(
        abs(ledger.RMSControlVolumeSpongeForceNewtons
            - 0.125_603_589_121_954_38) < 1.0e-10
    )
    #expect(ledger.RMSControlVolumeSymmetricLimiterForceNewtons < 1.0e-6)
    #expect(ledger.maximumBoundaryLoadClosureResidualNewtons < 5.0e-6)
    #expect(
        repeated.classification == report.classification
            && repeated.control.firstNegativePopulationStep
                == control.firstNegativePopulationStep
            && repeated.treatment.firstNegativePopulationStep
                == treatment.firstNegativePopulationStep
            && repeated.treatment.limiterActivationCellSteps
                == treatment.limiterActivationCellSteps
            && repeated.treatment.firstZeroLimiterScaleStep
                == treatment.firstZeroLimiterScaleStep
            && repeated.treatment.minimumObservedPopulation
                == treatment.minimumObservedPopulation
            && repeated.treatmentConservationLedger
                .cumulativeObservedGlobal.mass
                == ledger.cumulativeObservedGlobal.mass
            && repeated.treatmentConservationLedger
                .RMSControlVolumeSpongeForceNewtons
                == ledger.RMSControlVolumeSpongeForceNewtons
    )
}

@Test
func productionMetalFixedSpherePassesCanonicalGates() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalSphereValidator.run()

    #expect(report.productionKernel == "stepFluidTRT")
    #expect(report.cases.map(\.resolution) == [80, 120, 160])
    #expect(report.cases.map(\.crossflowResolution) == [48, 72, 96])
    #expect(report.cases.map(\.diameterCells) == [8, 12, 16])
    #expect(report.cases.allSatisfy {
        $0.reachedSteadyState
            && $0.steadyWindowRelativeRange
                <= report.maximumAllowedSteadyWindowRange
            && $0.sideForceToDragRatio
                <= report.maximumAllowedSideForceRatio
            && $0.torqueToDragDiameterRatio
                <= report.maximumAllowedTorqueRatio
            && $0.normalizedVelocitySymmetryError
                <= report.maximumAllowedVelocitySymmetryError
    })
    #expect(
        report.cases.last!.relativeDragError
            <= report.maximumAllowedFinestDragError
    )
    #expect(
        report.relativeFinestTwoDragChange
            <= report.maximumAllowedFinestTwoDragChange
    )
    #expect(
        report.maximumBatchDensityDifference
            <= report.maximumAllowedBatchDifference
    )
    #expect(
        report.maximumBatchVelocityDifference
            <= report.maximumAllowedBatchDifference
    )
    #expect(
        report.maximumBatchForceDifference
            <= report.maximumAllowedBatchDifference
    )
    #expect(report.passed)
}

@Test
func productionMetalFixedWingDiagnosticMatchesLockedBaseline() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let result = try MetalWingValidator.runSingleCase(resolution: 80)

    #expect(result.resolution == 80)
    #expect(result.chordCells == 8)
    #expect(result.spanCells == 16)
    #expect(result.steps == 1_300)
    #expect(abs(result.liftCoefficient - 0.542_694_722_624_437_9) < 1e-6)
    #expect(abs(result.dragCoefficient - 0.672_869_301_552_491) < 1e-6)
    #expect(result.sideForceRatio < MetalWingValidator.maximumSideForceRatio)
    #expect(
        result.rollYawMomentCoefficient
            < MetalWingValidator.maximumRollYawMomentCoefficient
    )
    #expect(
        result.normalizedSpanSymmetryError
            < MetalWingValidator.maximumSpanSymmetryError
    )
}

@Test
func productionMetalPrescribedWingSmokeCapturesPhaseDiagnostics() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let result = try MetalFlappingWingValidator.runSingleCase(
        chordCells: 8,
        cycles: 1
    )

    #expect(result.chordCells == 8)
    #expect(result.cycleSteps == 2_142)
    #expect(result.phaseSamples.count == 100)
    #expect(result.vortexMetrics.count == 5)
    #expect(result.vortexTimingCoverageComplete)
    #expect(abs(result.actualReynoldsNumber - 100) < 0.1)
    #expect(result.meanLiftCoefficient.isFinite)
    #expect(result.meanDragCoefficient.isFinite)
}

@Test
func interpolatedBounceBackReferenceMatchesPublishedBranches() {
    let correction = 0.07
    let reflected = 0.31
    let farther = 0.19
    let previous = 0.23

    #expect(abs(
        InterpolatedBounceBackReference.population(
            linkFraction: 0.5,
            reflected: reflected,
            fartherOutgoing: farther,
            previousIncoming: previous,
            movingWallCorrection: correction
        ) - (reflected + correction)
    ) < 1.0e-15)
    #expect(abs(
        InterpolatedBounceBackReference.population(
            linkFraction: 0.25,
            reflected: reflected,
            fartherOutgoing: farther,
            previousIncoming: previous,
            movingWallCorrection: correction
        ) - (0.5 * reflected + 0.5 * farther + correction)
    ) < 1.0e-15)
    #expect(abs(
        InterpolatedBounceBackReference.population(
            linkFraction: 0.75,
            reflected: reflected,
            fartherOutgoing: farther,
            previousIncoming: previous,
            movingWallCorrection: correction
        ) - ((reflected + correction) / 1.5 + previous / 3)
    ) < 1.0e-15)
    #expect(abs(
        InterpolatedBounceBackReference.linkFraction(
            fluidImplicit: 0.25,
            solidImplicit: -0.75
        ) - 0.25
    ) < 1.0e-15)
}

@Test
func movingDomainReferenceIncludesCoveredAndUncoveredStencilImpulse() {
    let covered = InterpolatedBounceBackReference
        .conservativeCoveredBodyImpulse(
            previousFluidMomentum: SIMD3<Double>(0.2, -0.3, 0.4)
        )
    #expect(covered == SIMD3<Double>(0.2, -0.3, 0.4))

    let uncovered = InterpolatedBounceBackReference
        .conservativeUncoveredBodyImpulse(
            refillMomentum: SIMD3<Double>(1, 2, 3),
            persistentNeighborStencils: [
                MovingDomainNeighborStencil(
                    directionFromUncoveredCell: SIMD3<Double>(1, 0, 0),
                    oldSolidOutgoing: 0.2,
                    suppressedNeighborIncoming: 0.3
                ),
                MovingDomainNeighborStencil(
                    directionFromUncoveredCell: SIMD3<Double>(0, 1, 0),
                    oldSolidOutgoing: 0.1,
                    suppressedNeighborIncoming: 0.4
                ),
            ]
        )
    #expect(uncovered == SIMD3<Double>(-1.5, -2.5, -3))
}

@Test
func productionMetalPrescribedWingInputFixtureValidatesSubcellLinks() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let audit = try MetalFlappingWingValidator.auditInputs(chordCells: 8)

    #expect(audit.analyticInputsPassed)
    #expect(audit.metalGeometryPassed)
    #expect(audit.passed)
    #expect(abs(audit.normalizedPlanformArea - 1) < 1.0e-12)
    #expect(abs(audit.normalizedRadialCentroid - 0.5) < 1.0e-12)
    #expect(
        abs(
            audit.normalizedRadiusOfGyration
                - MetalFlappingWingValidator.radiusOfGyration
        ) < 1.0e-12
    )
    #expect(audit.geometry.count == 4)
    #expect(
        audit.geometry.allSatisfy {
            $0.mismatchedCellFraction <= 0.01
                && $0.maximumSolidWallVelocityError <= 1.0e-5
                && $0.boundaryLinkCount > 0
                && $0.auditedBoundaryLinkCount > 0
                && $0.maximumInterpolatedWallPositionErrorCells <= 0.10
                && $0.maximumInterpolatedWallPositionErrorCells
                    < $0.maximumHalfwayWallPositionErrorCells
        }
    )
    let midstroke = try #require(
        audit.geometry.first { abs($0.phase - 0.25) < 1.0e-12 }
    )
    #expect(midstroke.mismatchedCellCount == 0)
    #expect(midstroke.normalizedVoxelVolume > 1.4)
    #expect(midstroke.normalizedPublishedThicknessVoxelVolume > 3.5)
    #expect(midstroke.maximumLinkFractionError < 0.10)
}

@Test
func productionMetalPrescribedWingLoadDecompositionCloses() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalFlappingWingValidator.diagnoseLoadDecomposition(
        chordCells: 8,
        cycles: 1
    )

    #expect(report.total.phaseSamples.count == 100)
    #expect(report.linkExchange.phaseSamples.count == 100)
    #expect(report.coverUncoverImpulse.phaseSamples.count == 100)
    #expect(report.closurePassed)
    #expect(
        report.maximumLiftCoefficientClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(
        report.maximumDragCoefficientClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(report.total.meanLiftCoefficient.isFinite)
    #expect(report.total.meanDragCoefficient.isFinite)
}

@Test
func productionMetalPrescribedWingLinkForceEstimatorsCompare() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalFlappingWingValidator.compareLinkForceEstimators(
        chordCells: 8,
        cycles: 1
    )

    #expect(report.galileanInvariantLinkExchange.phaseSamples.count == 100)
    #expect(
        report.interpolatedPopulationConventionalLinkExchange
            .phaseSamples.count == 100
    )
    #expect(report.conventionalMovingBodyTotal.phaseSamples.count == 100)
    #expect(report.closurePassed)
    #expect(
        report.maximumGalileanInvariantLiftClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(
        report.maximumGalileanInvariantDragClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(report.conventionalToGalileanMeanLiftRatio.isFinite)
    #expect(report.conventionalToGalileanMeanDragRatio.isFinite)
    #expect(report.maximumLinkLiftCoefficientDifference > 0)
    #expect(report.maximumLinkDragCoefficientDifference > 0)
}

@Test
func productionMetalPrescribedWingLinkNumeratorDecompositionCloses() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalFlappingWingValidator
        .diagnoseLinkNumeratorDecomposition(
            chordCells: 8,
            cycles: 1
        )

    #expect(report.galileanInvariantLinkExchange.phaseSamples.count == 100)
    #expect(report.conventionalLinkExchange.phaseSamples.count == 100)
    #expect(report.components.count == 4)
    #expect(
        report.components.allSatisfy {
            $0.load.phaseSamples.count == 100
        }
    )
    #expect(report.closurePassed)
    #expect(
        report.maximumConventionalLiftClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(
        report.maximumConventionalDragClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(
        report.maximumGalileanInvariantLiftClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(
        report.maximumGalileanInvariantDragClosureError
            <= report.maximumAllowedCoefficientClosureError
    )
    #expect(
        report.components.contains {
            $0.name == report.dominantMeanLiftComponent
        }
    )
    #expect(
        report.components.contains {
            $0.name == report.dominantMeanDragComponent
        }
    )
}

@Test
func productionMetalPrescribedWingConservativeEstimatorClosesBudget() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalFlappingWingValidator
        .diagnoseNearWingMomentumBudget(
            chordCells: 8,
            cycles: 1
        )

    #expect(
        report.independentFluidMomentumBudget.phaseSamples.count == 100
    )
    #expect(report.conventionalBoundaryLoad.phaseSamples.count == 100)
    #expect(report.rawFluidMomentumBudget.phaseSamples.count == 100)
    #expect(
        report.conservativeMovingDomainBoundaryLoad.phaseSamples.count == 100
    )
    #expect(report.controlSurfaceClearOfSolid)
    #expect(report.controlSurfaceOutsideSponge)
    #expect(report.maximumSolidControlSurfaceCrossingLinkCount == 0)
    #expect(!report.conventionalClosurePassed)
    #expect(report.boundaryLoadBiasDetected)
    #expect(report.conservativeMovingDomainClosurePassed)
    #expect(report.conventionalMeanLiftBiasFactor > 4)
    #expect(report.conventionalMeanDragBiasFactor > 4)
    #expect(
        report.maximumConventionalLiftCoefficientResidual
            > report.maximumAllowedCoefficientResidual
    )
    #expect(
        report.maximumConventionalDragCoefficientResidual
            > report.maximumAllowedCoefficientResidual
    )
    #expect(
        report.maximumConservativeLiftCoefficientResidual
            <= report.maximumAllowedCoefficientResidual
    )
    #expect(
        report.maximumConservativeDragCoefficientResidual
            <= report.maximumAllowedCoefficientResidual
    )
    #expect(
        report.conservativeCorrectionRelativeToConventionalBoundaryLoad
            .meanLiftCoefficient < -1
    )
    #expect(
        report.conservativeCorrectionRelativeToConventionalBoundaryLoad
            .meanDragCoefficient < -1
    )
    #expect(
        report.classification
            == "conservativeMovingDomainEstimatorCloses"
    )
}
#endif

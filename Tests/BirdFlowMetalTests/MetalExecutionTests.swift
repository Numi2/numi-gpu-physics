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

@Test
func measuredBirdSchema2RequiresAndAcceptsRigidWingMassContract() throws {
    let data = try Data(contentsOf: measuredFixtureURL)
    var root = try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
    root["schemaVersion"] = 2
    let properties: [String: Any] = [
        "massKilograms": 0.01,
        "centerOfMassFromHingeMeters": [0.0, 0.15, 0.0],
        "principalInertiaKilogramMetersSquared": [1e-5, 2e-6, 1e-5],
    ]
    root["prescribedWingDynamics"] = [
        "model": "prescribedRigidWingMomentumV1",
        "sourceCitation": "synthetic schema conformance properties",
        "massDefinition": "wholeBirdIncludingWings",
        "inertiaDefinition": "wholeBirdAtRegisteredReferencePose",
        "left": properties,
        "right": properties,
    ]
    var kinematics = try #require(root["kinematics"] as? [String: Any])
    var frames = try #require(kinematics["keyframes"] as? [[String: Any]])
    for index in frames.indices {
        for side in ["left", "right"] {
            var state = try #require(frames[index][side] as? [String: Any])
            state["tipTwistRadians"] = 0.0
            state["tipTwistRateRadiansPerSecond"] = 0.0
            frames[index][side] = state
        }
    }
    kinematics["keyframes"] = frames
    root["kinematics"] = kinematics
    let encoded = try JSONSerialization.data(withJSONObject: root)
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("birdflow-schema2-\(UUID()).json")
    try encoded.write(to: url)
    defer { try? FileManager.default.removeItem(at: url) }

    let loaded = try MeasuredBirdDatasetLoader.load(from: url)
    let audit = try MeasuredBirdReplay.audit(loaded, chordCells: 12)
    #expect(audit.schemaVersion == 2)
    #expect(audit.quantitativeFreeFlightContractPassed)
    #expect(
        audit.wingInertialTreatment == "prescribedRigidWingMomentumV1"
    )
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
    let wingReactionBuffer = try backend.makeSharedBuffer(
        value: GPUWingInertialReaction.zero
    )
    var refinedConfiguration = testCase.configuration
    refinedConfiguration.bodySubsteps = 4
    var uniforms = GPUUniforms(
        configuration: refinedConfiguration,
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
    encoder.setBuffer(wingReactionBuffer, offset: 0, index: 4)
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
        timeStepSeconds: testCase.configuration.scaling.timeStepSeconds,
        substeps: 4
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
func metalRuntimeSafetyLedgerRecordsExactFirstMachViolation() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let backend = try MetalBackend(fastMath: false)
    let pipeline = try backend.pipeline(named: "monitorBirdRuntimeSafety")
    var state = testCase.state
    state.linearVelocityMetersPerSecond = SIMD3<Float>(100, 0, 0)
    let body = try backend.makeSharedBuffer(value: GPUBirdBodyState(state))
    let bird = try backend.makeSharedBuffer(
        value: GPUBirdParameters(testCase.bird)
    )
    let ledger = try backend.makeSharedBuffer(
        value: GPURuntimeSafetyRecord.clear
    )
    var uniforms = GPUUniforms(
        configuration: testCase.configuration,
        time: testCase.configuration.scaling.timeStepSeconds
    )
    var step = SIMD4<UInt32>(42, 0, 0, 0)
    let commandBuffer = try #require(backend.queue.makeCommandBuffer())
    let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
    encoder.setBuffer(body, offset: 0, index: 0)
    encoder.setBuffer(bird, offset: 0, index: 1)
    encoder.setBuffer(ledger, offset: 0, index: 2)
    encoder.setBytes(
        &uniforms,
        length: MemoryLayout<GPUUniforms>.stride,
        index: 3
    )
    encoder.setBytes(
        &step,
        length: MemoryLayout<SIMD4<UInt32>>.stride,
        index: 4
    )
    backend.dispatch1D(encoder: encoder, pipeline: pipeline, count: 1)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    #expect(commandBuffer.status == .completed)
    let value = ledger.contents()
        .assumingMemoryBound(to: GPURuntimeSafetyRecord.self)
        .pointee
    #expect(value.event.x == 42)
    #expect(value.event.z & 1 != 0)
    #expect(value.metrics.x > 0.15)
}

@Test
func metalRigidBodyMatchesCPUAcrossMultiStepRotationalCanonicals() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let backend = try MetalBackend(fastMath: false)
    let pipeline = try backend.pipeline(named: "integrateBirdBody")
    var configuration = testCase.configuration
    configuration.bodySubsteps = 2
    let cases: [(name: String, torque: SIMD3<Float>)] = [
        ("torque-free", .zero),
        ("constant-torque", SIMD3<Float>(8e-7, -4e-7, 6e-7)),
    ]
    for item in cases {
        var cpu = BirdBodyState(
            positionMeters: testCase.state.positionMeters,
            orientationBodyToWorld: Quaternion.axisAngle(
                axis: SIMD3<Float>(0.3, -0.4, 0.2),
                angle: 0.27
            ),
            angularVelocityBodyRadiansPerSecond:
                SIMD3<Float>(0.7, -0.45, 0.3)
        )
        let body = try backend.makeSharedBuffer(value: GPUBirdBodyState(cpu))
        let bird = try backend.makeSharedBuffer(
            value: GPUBirdParameters(testCase.bird)
        )
        let load = try backend.makeSharedBuffer(
            value: GPUForceTorque(
                force: .zero,
                torque: SIMD4<Float>(item.torque, 0)
            )
        )
        let wingReaction = try backend.makeSharedBuffer(
            value: GPUWingInertialReaction.zero
        )
        var uniforms = GPUUniforms(
            configuration: configuration,
            time: configuration.scaling.timeStepSeconds
        )
        let commandBuffer = try #require(backend.queue.makeCommandBuffer())
        let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
        encoder.label = "\(item.name) multi-step rigid-body canonical"
        encoder.setBuffer(body, offset: 0, index: 0)
        encoder.setBuffer(bird, offset: 0, index: 1)
        encoder.setBuffer(load, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        encoder.setBuffer(wingReaction, offset: 0, index: 4)
        for _ in 0..<256 {
            backend.dispatch1D(encoder: encoder, pipeline: pipeline, count: 1)
            RigidBodyIntegrator.integrate(
                state: &cpu,
                parameters: testCase.bird,
                forceWorldNewtons: .zero,
                torqueWorldNewtonMeters: item.torque,
                gravityWorldMetersPerSecondSquared: .zero,
                timeStepSeconds: configuration.scaling.timeStepSeconds,
                substeps: configuration.bodySubsteps
            )
        }
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        #expect(commandBuffer.status == .completed)
        let gpu = body.contents()
            .assumingMemoryBound(to: GPUBirdBodyState.self)
            .pointee
            .coreValue
        #expect(
            vectorLength(
                gpu.angularVelocityBodyRadiansPerSecond
                    - cpu.angularVelocityBodyRadiansPerSecond
            ) < 2e-5,
            "\(item.name) angular velocity"
        )
        #expect(
            vectorLength(
                gpu.orientationBodyToWorld.vector
                    - cpu.orientationBodyToWorld.vector
            ) < 2e-5,
            "\(item.name) orientation vector"
        )
        #expect(
            abs(
                gpu.orientationBodyToWorld.scalar
                    - cpu.orientationBodyToWorld.scalar
            ) < 2e-5,
            "\(item.name) orientation scalar"
        )
    }
}

@Test
func metalWingInertialReactionMatchesIndependentCPUReference() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let properties = WingInertialProperties(
        massKilograms: 0.001,
        centerOfMassFromHingeMeters: SIMD3<Float>(0, 0.01, 0),
        principalInertiaKilogramMetersSquared:
            SIMD3<Float>(2e-8, 3e-8, 1e-7)
    )
    var birdParameters = testCase.bird
    birdParameters.prescribedWingDynamics = PrescribedWingDynamics(
        sourceCitation: "same-specimen test mass properties",
        left: properties,
        right: properties
    )
    let backend = try MetalBackend(fastMath: false)
    let pipeline = try backend.pipeline(named: "updateWingInertialReaction")
    let initialPrepared = GPUPreparedBirdGeometry(
        bodyPosition: .zero,
        orientation: SIMD4<Float>(0, 0, 0, 1),
        linearVelocity: .zero,
        omegaBodyWorld: .zero,
        leftRoot: .zero,
        leftChord: SIMD4<Float>(1, 0, 0, 0),
        leftSpan: SIMD4<Float>(0, 1, 0, 0),
        leftNormal: SIMD4<Float>(0, 0, 1, 0),
        leftAngularVelocity: .zero,
        rightRoot: .zero,
        rightChord: SIMD4<Float>(1, 0, 0, 0),
        rightSpan: SIMD4<Float>(0, 1, 0, 0),
        rightNormal: SIMD4<Float>(0, 0, 1, 0),
        rightAngularVelocity: .zero
    )
    let prepared = try backend.makeSharedBuffer(value: initialPrepared)
    let bird = try backend.makeSharedBuffer(
        value: GPUBirdParameters(birdParameters)
    )
    let momentum = try backend.makeSharedBuffer(
        value: GPUWingMomentumState.zero
    )
    let reaction = try backend.makeSharedBuffer(
        value: GPUWingInertialReaction.zero
    )
    var uniforms = GPUUniforms(
        configuration: testCase.configuration,
        time: 0
    )

    func dispatch(initialize: UInt32) throws {
        var flag = initialize
        let commandBuffer = try #require(backend.queue.makeCommandBuffer())
        let encoder = try #require(commandBuffer.makeComputeCommandEncoder())
        encoder.setBuffer(momentum, offset: 0, index: 0)
        encoder.setBuffer(reaction, offset: 0, index: 1)
        encoder.setBuffer(prepared, offset: 0, index: 2)
        encoder.setBuffer(bird, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        encoder.setBytes(
            &flag,
            length: MemoryLayout<UInt32>.stride,
            index: 5
        )
        backend.dispatch1D(encoder: encoder, pipeline: pipeline, count: 1)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        #expect(commandBuffer.status == .completed)
    }

    try dispatch(initialize: 1)
    prepared.contents()
        .assumingMemoryBound(to: GPUPreparedBirdGeometry.self)
        .pointee.leftAngularVelocity = SIMD4<Float>(0, 0, 1, 0)
    try dispatch(initialize: 0)

    let previous = PrescribedWingMomentumModel.momentum(
        properties: properties,
        hingeWorldMeters: .zero,
        chordWorld: SIMD3<Float>(1, 0, 0),
        spanWorld: SIMD3<Float>(0, 1, 0),
        normalWorld: SIMD3<Float>(0, 0, 1),
        relativeAngularVelocityWorldRadiansPerSecond: .zero,
        bodyOriginWorldMeters: .zero
    )
    let current = PrescribedWingMomentumModel.momentum(
        properties: properties,
        hingeWorldMeters: .zero,
        chordWorld: SIMD3<Float>(1, 0, 0),
        spanWorld: SIMD3<Float>(0, 1, 0),
        normalWorld: SIMD3<Float>(0, 0, 1),
        relativeAngularVelocityWorldRadiansPerSecond:
            SIMD3<Float>(0, 0, 1),
        bodyOriginWorldMeters: .zero
    )
    let expected = PrescribedWingMomentumModel.inertialReaction(
        previous: previous,
        current: current,
        timeStepSeconds: testCase.configuration.scaling.timeStepSeconds
    )
    let gpu = reaction.contents()
        .assumingMemoryBound(to: GPUWingInertialReaction.self)
        .pointee
    let gpuLeftForce = SIMD3<Float>(
        gpu.leftForce.x,
        gpu.leftForce.y,
        gpu.leftForce.z
    )
    let gpuLeftTorque = SIMD3<Float>(
        gpu.leftTorque.x,
        gpu.leftTorque.y,
        gpu.leftTorque.z
    )
    let gpuRightForce = SIMD3<Float>(
        gpu.rightForce.x,
        gpu.rightForce.y,
        gpu.rightForce.z
    )
    let gpuRightTorque = SIMD3<Float>(
        gpu.rightTorque.x,
        gpu.rightTorque.y,
        gpu.rightTorque.z
    )
    #expect(
        vectorLength(gpuLeftForce - expected.forceNewtons) < 1e-6
    )
    #expect(
        vectorLength(gpuLeftTorque - expected.torqueNewtonMeters) < 1e-6
    )
    #expect(vectorLength(gpuRightForce) < 1e-8)
    #expect(vectorLength(gpuRightTorque) < 1e-8)
}

@Test
func productionFreeFlightClosesCoupledExternalMomentumLedger() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    var testCase = try compactMetalTestCase(freeFlight: true)
    testCase.configuration.gravityMetersPerSecondSquared =
        SIMD3<Float>(0, -0.5, 0)
    let wing = WingInertialProperties(
        massKilograms: 0.001,
        centerOfMassFromHingeMeters: SIMD3<Float>(0, 0.012, 0),
        principalInertiaKilogramMetersSquared:
            SIMD3<Float>(2e-8, 3e-8, 1e-7)
    )
    var bird = testCase.bird
    bird.prescribedWingDynamics = PrescribedWingDynamics(
        sourceCitation: "same-specimen coupled-ledger fixture",
        left: wing,
        right: wing
    )
    let simulation = try BirdFlowSimulation(
        configuration: testCase.configuration,
        bird: bird,
        initialBodyState: testCase.state
    )
    let result = try simulation.advanceWithCoupledMomentumLedger(steps: 4)

    #expect(result.advanceResult.runSamples.count == 4)
    #expect(result.ledger.samples.count == 4)
    #expect(try JSONEncoder().encode(result.ledger).count > 0)
    #expect(result.ledger.finite)
    #expect(result.ledger.passed)
    #expect(
        result.ledger.relativeRMSBoundaryClosureResidual
            <= result.ledger
                .maximumAllowedRelativeRMSBoundaryClosureResidual
    )
    #expect(
        result.ledger.relativeRMSExternalSystemClosureResidual
            <= result.ledger
                .maximumAllowedRelativeRMSExternalSystemClosureResidual
    )
    #expect(
        result.ledger.samples.contains {
            $0.persistentBoundaryLinkCount > 0
                && $0.topologyTransitionCellCount > 0
        }
    )
    #expect(
        result.ledger.samples.allSatisfy {
            $0.farFieldLinkCount > 0 && $0.spongeCellCount > 0
        }
    )
    #expect(
        result.ledger.samples.allSatisfy {
            $0.gravityImpulse.y < 0
        }
    )
    #expect(
        result.ledger.samples.contains {
            let delta = $0.prescribedWingInternalMomentumAfter
                - $0.prescribedWingInternalMomentumBefore
            return sqrt(delta.x * delta.x + delta.y * delta.y
                + delta.z * delta.z) > 1e-12
        }
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
func productionMetalStationaryWallC16LimiterPassesSourceAwareAcceptance()
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
            == "stationary-wall-c16-symmetric-limiter-source-aware-accepted"
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
    let sourceAware = report.sourceAwareTreatment
    let sourceAwareLedger = report.sourceAwareTreatmentConservationLedger
    #expect(report.sourceAwareControlMinimumCells == SIMD3<Int>(4, 4, 4))
    #expect(
        report.sourceAwareControlMaximumExclusiveCells
            == SIMD3<Int>(52, 20, 20)
    )
    #expect(report.sourceAwareMaximumSolidControlSurfaceCrossingLinkCount == 0)
    #expect(report.sourceAwareControlVolumeOutsideSponge)
    #expect(report.sourceAwareStabilityPassed)
    #expect(report.sourceAwareForceBudgetPassed)
    #expect(report.sourceAwareAcceptancePassed)
    #expect(sourceAware.completedSteps == 500)
    #expect(sourceAware.firstNegativePopulationStep == nil)
    #expect(sourceAware.firstNonFinitePopulationStep == nil)
    #expect(sourceAware.firstNonFiniteLoadStep == nil)
    #expect(sourceAware.forceBudgetPassed)
    #expect(!sourceAware.stabilityPassed)
    #expect(!sourceAware.fullAcceptancePassed)
    #expect(
        abs((sourceAware.maximumConservativeForceResidual ?? 0)
            - 0.000_464_316_268_781_87) < 1e-10
    )
    #expect(
        abs((sourceAware.conservativeRelativeRMSResidual ?? 0)
            - 0.000_053_737_304_229_604_57) < 1e-12
    )
    #expect(sourceAwareLedger.globalLedgerClosed)
    #expect(!sourceAwareLedger.forceResidualLedgerClosed)
    #expect(
        sourceAwareLedger.samples.allSatisfy {
            $0.controlVolumeSpongeCellCount == 0
        }
    )
    #expect(sourceAwareLedger.RMSControlVolumeSpongeForceNewtons == 0)
    #expect(sourceAwareLedger.relativeRMSBoundaryLoadClosureResidual < 1.0e-6)
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
            && repeated.sourceAwareAcceptancePassed
                == report.sourceAwareAcceptancePassed
            && repeated.sourceAwareTreatment.maximumConservativeForceResidual
                == sourceAware.maximumConservativeForceResidual
            && repeated.sourceAwareTreatmentConservationLedger
                .RMSControlVolumeSpongeForceNewtons
                == sourceAwareLedger.RMSControlVolumeSpongeForceNewtons
    )
}

@Test
func productionMetalGeometricLimiterLadderBlocksNonConvergedPromotion()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallGeometricLimiterLadder()

    #expect(
        report.classification
            == "stationary-wall-geometric-limiter-ladder-not-accepted"
    )
    #expect(report.cases.map(\.diameterCells) == [8, 12, 16])
    #expect(
        report.cases.map(\.domainCells) == [
            SIMD3<Int>(80, 48, 48),
            SIMD3<Int>(120, 72, 72),
            SIMD3<Int>(160, 96, 96),
        ]
    )
    #expect(report.cases.map(\.requestedSteps) == [500, 750, 1_000])
    #expect(report.cases.allSatisfy {
        $0.minimumObservedPopulation! > 0
            && $0.sourceAwareStabilityPassed
            && $0.forceBudgetPassed
            && !$0.limiterNonIntrusivePassed
            && !$0.passed
            && $0.maximumSolidControlSurfaceCrossingLinkCount == 0
            && $0.controlVolumeOutsideSponge
            && $0.globalLedgerClosed
    })
    #expect(
        report.cases.map(\.limiterActivationFraction) == [
            0.032_554_785_156_25,
            0.061_734_134_945_130_32,
            0.073_959_859_212_239_59,
        ]
    )
    #expect(
        report.cases.map(\.relativeLimiterL1Correction) == [
            0.039_466_866_773_455_86,
            0.060_925_142_060_480_24,
            0.060_801_055_789_557_98,
        ]
    )
    #expect(
        report.cases.map(\.relativeLimiterL2Correction) == [
            0.120_882_998_429_520_5,
            0.143_460_069_513_615_34,
            0.138_081_972_217_033_08,
        ]
    )
    #expect(
        report.cases.map(\.controlVolumeLimiterActivationFraction) == [
            0.035_294_635_416_666_664,
            0.066_522_040_466_392_32,
            0.080_699_371_744_791_66,
        ]
    )
    #expect(
        report.cases.map(\.relativeControlVolumeLimiterL1Correction) == [
            0.033_979_475_908_227_016,
            0.058_723_323_395_726_42,
            0.061_685_687_048_698_354,
        ]
    )
    #expect(
        report.cases.map(\.relativeControlVolumeLimiterL2Correction) == [
            0.117_068_803_764_230_1,
            0.147_424_460_209_431_98,
            0.145_388_060_159_023_25,
        ]
    )
    #expect(
        abs(report.relativeFinestTwoDragChange
            - 0.148_124_168_221_390_2) < 1.0e-12
    )
    #expect(!report.limiterActivationNonIncreasing)
    #expect(!report.limiterCorrectionNonIncreasing)
    #expect(report.observedDragConvergenceOrder == nil)
    #expect(report.richardsonExtrapolatedDragCoefficient == nil)
    #expect(report.fineGridConvergenceIndex == nil)
    #expect(!report.passed)
}

@Test
func productionMetalRecursiveRegularizationLadderBlocksForcePromotion()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallRecursiveRegularizationLadder()

    #expect(
        report.classification
            == "stationary-wall-recursive-regularization-ladder-not-accepted"
    )
    #expect(report.cases.map(\.diameterCells) == [8, 12, 16])
    #expect(
        report.cases.map(\.domainCells) == [
            SIMD3<Int>(80, 48, 48),
            SIMD3<Int>(120, 72, 72),
            SIMD3<Int>(160, 96, 96),
        ]
    )
    #expect(report.cases.map(\.requestedSteps) == [500, 750, 1_000])
    #expect(report.cases.allSatisfy {
        $0.minimumObservedPopulation! > 0
            && $0.sourceAwareStabilityPassed
            && $0.forceBudgetPassed
            && $0.limiterNonIntrusivePassed
            && $0.passed
            && $0.maximumSolidControlSurfaceCrossingLinkCount == 0
            && $0.controlVolumeOutsideSponge
            && $0.globalLedgerClosed
    })
    #expect(
        report.cases.map(\.meanDragCoefficientLastConvectiveTime) == [
            1.320_419_274_473_607_9,
            0.937_999_642_875_562_3,
            1.047_765_781_965_056,
        ]
    )
    #expect(
        report.cases.map(\.controlVolumeLimiterActivationFraction) == [
            0.000_135_208_333_333_333_34,
            0.000_108_731_138_545_953_36,
            0.000_064_514_973_958_333_33,
        ]
    )
    #expect(
        report.cases.map(\.relativeControlVolumeLimiterL1Correction) == [
            0.000_243_629_770_367_964_17,
            0.000_234_932_111_125_003_3,
            0.000_193_226_315_210_837_67,
        ]
    )
    #expect(
        report.cases.map(\.relativeControlVolumeLimiterL2Correction) == [
            0.004_133_143_671_728_516,
            0.003_779_166_883_736_146,
            0.003_527_852_471_536_101_6,
        ]
    )
    #expect(
        report.relativeFinestTwoDragChange
            == 0.104_762_095_669_540_23
    )
    #expect(report.limiterActivationNonIncreasing)
    #expect(report.limiterCorrectionNonIncreasing)
    #expect(report.observedDragConvergenceOrder == nil)
    #expect(report.richardsonExtrapolatedDragCoefficient == nil)
    #expect(report.fineGridConvergenceIndex == nil)
    #expect(!report.passed)
}

@Test
func productionMetalRecursiveRegularizationDurationIsolatedToCoarseGrid()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallRecursiveRegularizationDurationSensitivity()

    #expect(report.diagnosticCompleted)
    #expect(report.passed)
    #expect(report.allIndividualGatesPassed)
    #expect(!report.durationStabilityPassed)
    #expect(!report.baselineWindowBiasConfirmed)
    #expect(
        report.classification
            == "stationary-wall-recursive-regularization-duration-sensitivity-unresolved"
    )
    #expect(report.cases.map(\.numericalCase.diameterCells) == [8, 12])
    #expect(report.cases.map(\.numericalCase.requestedSteps) == [1_000, 1_500])
    #expect(report.cases.map(\.durationStabilityPassed) == [false, true])
    #expect(report.cases.allSatisfy {
        $0.convectiveWindowMeanDragCoefficients.count == 10
            && $0.numericalCase.minimumObservedPopulation! > 0
            && $0.numericalCase.sourceAwareStabilityPassed
            && $0.numericalCase.forceBudgetPassed
            && $0.numericalCase.limiterNonIntrusivePassed
            && $0.numericalCase.passed
    })
    #expect(
        report.cases.map(\.convectiveWindowMeanDragCoefficients) == [
            [
                2.369_455_981_679_001_5,
                1.408_184_798_511_469_5,
                1.731_478_738_960_702_7,
                1.472_755_450_406_484_4,
                1.320_419_274_473_607_4,
                1.096_411_397_415_869,
                0.915_080_342_850_593_9,
                0.888_956_676_225_704_2,
                1.500_565_699_113_433_5,
                1.021_846_406_462_214_4,
            ],
            [
                1.984_614_267_531_931_4,
                1.206_195_965_715_711_7,
                1.232_629_458_775_543,
                1.062_570_391_176_398,
                0.937_999_642_875_561_6,
                1.043_141_320_901_888_3,
                0.854_767_216_137_004_2,
                0.957_864_771_781_523_6,
                0.959_717_456_202_050_5,
                0.918_010_967_125_758_7,
            ],
        ]
    )
    #expect(
        abs(report.cases[0].ninthToTenthRelativeDragChange
            - 0.468_484_587_922_188_06) < 1.0e-12
    )
    #expect(
        abs(report.cases[1].ninthToTenthRelativeDragChange
            - 0.045_431_362_554_275_93) < 1.0e-12
    )
    #expect(
        abs(report.cases[0].fifthToTenthRelativeDragChange
            - 0.292_189_575_774_990_6) < 1.0e-12
    )
    #expect(
        abs(report.cases[1].fifthToTenthRelativeDragChange
            - 0.021_773_896_462_682_064) < 1.0e-12
    )
}

@Test
func productionMetalRadialLimiterLocalizationConfirmsBulkSpread()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallRadialLimiterLocalization()

    #expect(
        report.classification
            == "stationary-wall-c16-limiter-spreads-beyond-one-diameter"
    )
    #expect(report.diameterCells == 16)
    #expect(report.domainCells == SIMD3<Int>(160, 96, 96))
    #expect(report.requestedSteps == 1_000)
    #expect(report.firstLimiterActivationStep == 15)
    #expect(report.captureSteps == [15, 100, 250, 500, 750, 1_000])
    #expect(report.snapshots.count == 6)
    #expect(report.snapshots.allSatisfy {
        $0.bins.count == 8
            && $0.controlVolumeActivatedCellCount
                == $0.radialActivatedCellCount
    })
    #expect(report.populationPositivityPassed)
    #expect(report.controlVolumeIsolationPassed)
    #expect(report.radialClosurePassed)
    #expect(
        report.maximumObservedRadialClosureResidual
            == 8.020_495_835_516_945e-7
    )
    #expect(
        report.snapshots.map(\.nearSurfaceLimiterL1Fraction) == [
            1.0,
            0.978_399_312_519_672_6,
            0.615_454_825_060_189_7,
            0.088_729_193_613_708_62,
            0.014_959_690_373_206_012,
            0.011_087_400_338_434_607,
        ]
    )
    #expect(
        report.snapshots.map(\.farFieldLimiterL1Fraction) == [
            0.0,
            0.0,
            0.0,
            0.615_804_579_684_624_1,
            0.846_335_207_430_926_7,
            0.885_807_187_892_694_4,
        ]
    )
    #expect(
        report.snapshots.last!.bins.map(\.activatedCellCount) == [
            525, 639, 1_615, 5_144, 20_518, 105_636, 102_338, 6_289,
        ]
    )
    #expect(
        report.snapshots.last!.bins.map(\.boundaryLinkCount) == [
            4_416, 288, 0, 0, 0, 0, 0, 0,
        ]
    )
    #expect(!report.boundaryLocalized)
    #expect(report.passed)
}

@Test
func productionMetalBulkCollisionABRejectsNarrowL2GateMiss()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallBulkCollisionOperatorAB()

    #expect(
        report.classification
            == "stationary-wall-c16-regularized-candidate-rejected"
    )
    #expect(report.diameterCells == 16)
    #expect(report.domainCells == SIMD3<Int>(160, 96, 96))
    #expect(report.requestedSteps == 1_000)
    #expect(report.requestedConvectiveTimes == 5)
    #expect(report.maximumAllowedRelativeRMSForceResidual == 5.0e-3)
    #expect(report.maximumAllowedPeakForceResidualRatio == 1.0e-3)
    #expect(
        report.maximumAllowedCorrectionActivationFraction == 5.0e-2
    )
    #expect(report.maximumAllowedRelativeCorrection == 1.0e-2)
    #expect(report.control.operatorName == "symmetric-limited-trt")
    #expect(
        report.candidate.operatorName
            == "positivity-preserving-regularized-bgk"
    )
    #expect(report.control.populationPositivityPassed)
    #expect(report.control.forceBudgetPassed)
    #expect(report.control.globalLedgerClosed)
    #expect(report.candidate.populationPositivityPassed)
    #expect(report.candidate.forceBudgetPassed)
    #expect(report.candidate.globalLedgerClosed)
    #expect(report.candidate.radialCaptureCompleted)
    #expect(
        report.control.controlVolumeCorrectionActivationFraction
            == 0.080_699_371_744_791_66
    )
    #expect(
        report.candidate.controlVolumeCorrectionActivationFraction
            == 0.000_280_282_118_055_555_54
    )
    #expect(
        report.candidate.relativeControlVolumeCorrectionL1
            == 0.000_530_436_675_618_787_3
    )
    #expect(
        report.candidate.relativeControlVolumeCorrectionL2
            == 0.010_968_289_256_290_249
    )
    #expect(
        report.candidate.maximumObservedRadialClosureResidual
            == 6.833_866_619_265_361e-9
    )
    #expect(
        report.candidate.conservativeRelativeRMSForceResidual
            == 0.001_206_533_568_215_771_8
    )
    #expect(
        report.candidate.maximumForceBudgetResidualRatio
            == 0.000_700_797_686_941_622_9
    )
    #expect(report.candidateToControlActivationRatio < 0.0035)
    #expect(report.candidateToControlCorrectionL1Ratio < 0.0087)
    #expect(!report.candidate.correctionNonIntrusivePassed)
    #expect(!report.candidateEligibleForRefinement)
    #expect(report.gridConvergenceStillRequired)
    #expect(report.diagnosticCompleted)
    #expect(report.passed)
}

@Test
func productionMetalRecursiveRegularizationABClearsLockedGates()
    throws
{
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let report = try MetalTranslatingBodyTopologyValidator
        .runStationaryWallRecursiveRegularizationAB()

    #expect(
        report.classification
            == "stationary-wall-c16-recursive-regularized-candidate-eligible-for-refinement"
    )
    #expect(report.diameterCells == 16)
    #expect(report.domainCells == SIMD3<Int>(160, 96, 96))
    #expect(report.requestedSteps == 1_000)
    #expect(report.requestedConvectiveTimes == 5)
    #expect(report.maximumAllowedRelativeRMSForceResidual == 5.0e-3)
    #expect(report.maximumAllowedPeakForceResidualRatio == 1.0e-3)
    #expect(
        report.maximumAllowedCorrectionActivationFraction == 5.0e-2
    )
    #expect(report.maximumAllowedRelativeCorrection == 1.0e-2)
    #expect(
        report.control.operatorName
            == "positivity-preserving-regularized-bgk"
    )
    #expect(
        report.candidate.operatorName
            == "positivity-preserving-recursive-regularized-bgk"
    )
    #expect(report.candidate.populationPositivityPassed)
    #expect(report.candidate.forceBudgetPassed)
    #expect(report.candidate.globalLedgerClosed)
    #expect(report.candidate.radialCaptureCompleted)
    #expect(
        report.candidate.controlVolumeCorrectionActivationFraction
            == 0.000_064_514_973_958_333_33
    )
    #expect(
        report.candidate.relativeControlVolumeCorrectionL1
            == 0.000_193_226_315_210_837_67
    )
    #expect(
        report.candidate.relativeControlVolumeCorrectionL2
            == 0.003_527_852_471_536_101_6
    )
    #expect(
        report.candidate.maximumObservedRadialClosureResidual
            == 4.786_849_790_866_838_3e-8
    )
    #expect(
        report.candidate.conservativeRelativeRMSForceResidual
            == 0.001_606_350_268_579_750_8
    )
    #expect(
        report.candidate.maximumForceBudgetResidualRatio
            == 0.000_799_085_929_176_518_1
    )
    #expect(report.candidateToControlActivationRatio < 0.231)
    #expect(report.candidateToControlCorrectionL1Ratio < 0.365)
    #expect(report.candidate.correctionNonIntrusivePassed)
    #expect(report.candidateEligibleForRefinement)
    #expect(report.gridConvergenceStillRequired)
    #expect(report.diagnosticCompleted)
    #expect(report.passed)
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

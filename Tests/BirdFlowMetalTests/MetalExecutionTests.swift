@testable import BirdFlowMetal
import BirdFlowCore
import Testing

#if canImport(Metal)
import Metal

private func compactMetalTestCase(freeFlight: Bool = false) throws -> (
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
#endif

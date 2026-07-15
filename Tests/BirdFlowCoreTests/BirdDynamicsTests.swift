import BirdFlowCore
import Foundation
import Testing

@Test
func wingKinematicsReturnsAnalyticRates() {
    let kinematics = WingKinematics(
        frequencyHz: 5,
        strokeAmplitudeRadians: 0.7,
        pitchMeanRadians: 0.1,
        pitchAmplitudeRadians: 0.3,
        pitchPhaseRadians: 0.4
    )
    let sample = kinematics.sample(at: 0)

    #expect(abs(sample.strokeAngle) < 1e-7)
    #expect(abs(sample.strokeRate - 2 * Float.pi * 5 * 0.7) < 1e-5)
    #expect(abs(sample.pitchAngle - (0.1 + 0.3 * sin(0.4))) < 1e-6)
}

@Test
func rigidBodyTranslationUsesSemiImplicitEuler() {
    var state = BirdBodyState(positionMeters: .zero)
    let bird = BirdParameters.demonstration

    RigidBodyIntegrator.integrate(
        state: &state,
        parameters: bird,
        forceWorldNewtons: SIMD3<Float>(bird.massKilograms, 0, 0),
        torqueWorldNewtonMeters: .zero,
        gravityWorldMetersPerSecondSquared: .zero,
        timeStepSeconds: 0.1
    )

    #expect(abs(state.linearVelocityMetersPerSecond.x - 0.1) < 1e-6)
    #expect(abs(state.positionMeters.x - 0.01) < 1e-6)
    #expect(state.orientationBodyToWorld == .identity)
}

@Test
func rigidBodySubstepsRefineOnlyIntegratorTimeStep() {
    let bird = BirdParameters.demonstration
    var one = BirdBodyState(positionMeters: .zero)
    var four = BirdBodyState(positionMeters: .zero)
    for substeps in [1, 4] {
        var state = BirdBodyState(positionMeters: .zero)
        RigidBodyIntegrator.integrate(
            state: &state,
            parameters: bird,
            forceWorldNewtons: SIMD3<Float>(bird.massKilograms, 0, 0),
            torqueWorldNewtonMeters: .zero,
            gravityWorldMetersPerSecondSquared: .zero,
            timeStepSeconds: 0.1,
            substeps: substeps
        )
        if substeps == 1 { one = state } else { four = state }
    }
    #expect(abs(one.linearVelocityMetersPerSecond.x - 0.1) < 1e-6)
    #expect(abs(four.linearVelocityMetersPerSecond.x - 0.1) < 1e-6)
    #expect(abs(one.positionMeters.x - 0.01) < 1e-6)
    #expect(abs(four.positionMeters.x - 0.00625) < 1e-6)
}

@Test
func prescribedRigidWingDynamicsRejectDistributedTwist() throws {
    let configuration = try demonstrationConfiguration()
    var bird = BirdParameters.demonstration
    bird.measuredWingKinematics = measuredTestKinematics()
    let properties = WingInertialProperties(
        massKilograms: 0.01,
        centerOfMassFromHingeMeters: SIMD3<Float>(0, 0.15, 0),
        principalInertiaKilogramMetersSquared:
            SIMD3<Float>(1e-5, 2e-6, 1e-5)
    )
    bird.prescribedWingDynamics = PrescribedWingDynamics(
        sourceCitation: "measured same-specimen wing mass properties",
        left: properties,
        right: properties
    )
    #expect(throws: BirdFlowConfigurationError.self) {
        try bird.validate(for: configuration)
    }
}

@Test
func prescribedWingMomentumReactionHasIndependentClosedForm() {
    let properties = WingInertialProperties(
        massKilograms: 0.01,
        centerOfMassFromHingeMeters: SIMD3<Float>(0, 0.1, 0),
        principalInertiaKilogramMetersSquared:
            SIMD3<Float>(2e-6, 3e-6, 1e-5)
    )
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
    let reaction = PrescribedWingMomentumModel.inertialReaction(
        previous: previous,
        current: current,
        timeStepSeconds: 0.1
    )
    #expect(abs(reaction.forceNewtons.x - 0.01) < 1e-7)
    #expect(abs(reaction.forceNewtons.y) < 1e-7)
    #expect(abs(reaction.forceNewtons.z) < 1e-7)
    #expect(abs(reaction.torqueNewtonMeters.z + 0.0011) < 1e-7)
}

@Test
func quaternionRotationRoundTrips() {
    let q = Quaternion.axisAngle(
        axis: SIMD3<Float>(0.2, 0.8, -0.1),
        angle: 0.73
    )
    let point = SIMD3<Float>(0.4, -1.2, 0.7)
    let recovered = q.unrotate(q.rotate(point))
    #expect(vectorLength(recovered - point) < 1e-5)
}

private func demonstrationConfiguration() throws -> SimulationConfiguration {
    let grid = try GridSize(x: 96, y: 112, z: 96)
    let scaling = try LatticeScaling(
        characteristicLengthMeters: BirdParameters.demonstration.wingRootChordMeters,
        characteristicLengthCells: 12,
        referenceSpeedMetersPerSecond: 8,
        targetReynoldsNumber: 2_000,
        physicalAirDensity: 1.225,
        latticeReferenceSpeed: 0.04
    )
    return try SimulationConfiguration(
        grid: grid,
        domainOriginMeters: .zero,
        scaling: scaling,
        farFieldVelocityMetersPerSecond: SIMD3<Float>(-8, 0, 0),
        spongeWidthCells: 8,
        spongeStrength: 0.06
    )
}

@Test
func demonstrationBirdFitsAndRespectsMovingMachLimit() throws {
    let configuration = try demonstrationConfiguration()
    let center = configuration.domainSizeMeters * 0.5
    try BirdParameters.demonstration.validate(
        initialBodyState: BirdBodyState(positionMeters: center),
        for: configuration
    )
}

@Test
func excessiveWingFrequencyIsRejected() throws {
    let configuration = try demonstrationConfiguration()
    var bird = BirdParameters.demonstration
    bird.wingKinematics.frequencyHz = 20
    let center = configuration.domainSizeMeters * 0.5

    #expect(throws: BirdFlowConfigurationError.self) {
        try bird.validate(
            initialBodyState: BirdBodyState(positionMeters: center),
            for: configuration
        )
    }
}


@Test
func birdInitialPoseInsideSpongeIsRejected() throws {
    let configuration = try demonstrationConfiguration()

    #expect(throws: BirdFlowConfigurationError.self) {
        try BirdParameters.demonstration.validate(
            initialBodyState: BirdBodyState(
                positionMeters: configuration.domainOriginMeters
            ),
            for: configuration
        )
    }
}

private func measuredTestKinematics() -> MeasuredWingKinematics {
    let states = (0..<4).map { index -> MeasuredWingKeyframe in
        let phase = Float(index) * 0.25
        let angle = 2 * Float.pi * phase
        let state = MeasuredWingState(
            strokeRadians: sin(angle),
            deviationRadians: 0.1 * cos(angle),
            pitchRadians: 0.2 * sin(angle),
            tipTwistRadians: 0.05 * cos(angle),
            strokeRateRadiansPerSecond: 2 * Float.pi * 5 * cos(angle),
            deviationRateRadiansPerSecond:
                -0.1 * 2 * Float.pi * 5 * sin(angle),
            pitchRateRadiansPerSecond:
                0.2 * 2 * Float.pi * 5 * cos(angle),
            tipTwistRateRadiansPerSecond:
                -0.05 * 2 * Float.pi * 5 * sin(angle)
        )
        return MeasuredWingKeyframe(
            phase: phase,
            left: state,
            right: state
        )
    }
    return MeasuredWingKinematics(frequencyHz: 5, keyframes: states)
}

@Test
func measuredWingHermiteInterpolationIsPeriodicAndHitsRatesAtKnots() throws {
    let kinematics = measuredTestKinematics()
    try kinematics.validate()

    let phase0 = kinematics.sample(atPhase: 0).left
    let phase1 = kinematics.sample(atPhase: 1).left
    let negative = kinematics.sample(atPhase: -0.25).left
    let phase75 = kinematics.sample(atPhase: 0.75).left

    #expect(abs(phase0.strokeRadians) < 1e-7)
    #expect(
        abs(phase0.strokeRateRadiansPerSecond - 10 * Float.pi) < 1e-5
    )
    #expect(phase0 == phase1)
    #expect(negative == phase75)
}

@Test
func measuredWingKinematicsRejectNonIncreasingPhase() {
    var kinematics = measuredTestKinematics()
    kinematics.keyframes[2].phase = kinematics.keyframes[1].phase

    #expect(throws: MeasuredBirdDatasetError.self) {
        try kinematics.validate()
    }
}

@Test
func measuredWingMachBoundFindsRateExtremaBetweenKeyframes() throws {
    let angles: [Float] = [0, 1, 0, -1]
    let frames = angles.enumerated().map { index, angle in
        let state = MeasuredWingState(
            strokeRadians: angle,
            deviationRadians: 0,
            pitchRadians: 0,
            strokeRateRadiansPerSecond: 0,
            pitchRateRadiansPerSecond: 0
        )
        return MeasuredWingKeyframe(
            phase: Float(index) * 0.25,
            left: state,
            right: state
        )
    }
    let kinematics = MeasuredWingKinematics(
        frequencyHz: 1,
        keyframes: frames
    )
    try kinematics.validate()

    #expect(abs(kinematics.maximumAngularRateRadiansPerSecond - 6) < 1e-5)
    #expect(
        abs(
            kinematics.maximumSurfaceSpeedMetersPerSecond(
                wingSpanMeters: 0.5,
                maximumChordMeters: 0.1
            ) - 3
        ) < 1e-5
    )
}

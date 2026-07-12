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

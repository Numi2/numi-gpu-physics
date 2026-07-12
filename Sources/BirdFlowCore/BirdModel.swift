import Foundation

@frozen
public struct WingKinematics: Sendable, Equatable {
    public var frequencyHz: Float
    public var strokeAmplitudeRadians: Float
    public var strokeBiasRadians: Float
    public var pitchMeanRadians: Float
    public var pitchAmplitudeRadians: Float
    public var pitchPhaseRadians: Float

    public init(
        frequencyHz: Float,
        strokeAmplitudeRadians: Float,
        strokeBiasRadians: Float = 0,
        pitchMeanRadians: Float,
        pitchAmplitudeRadians: Float,
        pitchPhaseRadians: Float
    ) {
        self.frequencyHz = frequencyHz
        self.strokeAmplitudeRadians = strokeAmplitudeRadians
        self.strokeBiasRadians = strokeBiasRadians
        self.pitchMeanRadians = pitchMeanRadians
        self.pitchAmplitudeRadians = pitchAmplitudeRadians
        self.pitchPhaseRadians = pitchPhaseRadians
    }

    public func sample(at time: Float) -> WingKinematicSample {
        let angularFrequency = 2 * Float.pi * frequencyHz
        let phase = angularFrequency * time

        return WingKinematicSample(
            strokeAngle: strokeBiasRadians + strokeAmplitudeRadians * sin(phase),
            strokeRate: angularFrequency * strokeAmplitudeRadians * cos(phase),
            pitchAngle: pitchMeanRadians
                + pitchAmplitudeRadians * sin(phase + pitchPhaseRadians),
            pitchRate: angularFrequency
                * pitchAmplitudeRadians
                * cos(phase + pitchPhaseRadians)
        )
    }
}

@frozen
public struct WingKinematicSample: Sendable, Equatable {
    public var strokeAngle: Float
    public var strokeRate: Float
    public var pitchAngle: Float
    public var pitchRate: Float
}

@frozen
public struct BirdBodyState: Sendable, Equatable {
    public var positionMeters: SIMD3<Float>
    public var orientationBodyToWorld: Quaternion
    public var linearVelocityMetersPerSecond: SIMD3<Float>
    public var angularVelocityBodyRadiansPerSecond: SIMD3<Float>

    public init(
        positionMeters: SIMD3<Float>,
        orientationBodyToWorld: Quaternion = .identity,
        linearVelocityMetersPerSecond: SIMD3<Float> = .zero,
        angularVelocityBodyRadiansPerSecond: SIMD3<Float> = .zero
    ) {
        self.positionMeters = positionMeters
        self.orientationBodyToWorld = orientationBodyToWorld
        self.linearVelocityMetersPerSecond = linearVelocityMetersPerSecond
        self.angularVelocityBodyRadiansPerSecond = angularVelocityBodyRadiansPerSecond
    }
}

@frozen
public struct BirdParameters: Sendable, Equatable {
    public var bodyRadiiMeters: SIMD3<Float>
    public var massKilograms: Float
    public var principalInertiaKilogramMetersSquared: SIMD3<Float>

    public var wingSpanMeters: Float
    public var wingRootChordMeters: Float
    public var wingTipChordMeters: Float
    public var wingThicknessMeters: Float
    public var wingSweepMeters: Float
    public var wingRootOffsetMeters: SIMD3<Float>

    public var tailLengthMeters: Float
    public var tailHalfWidthMeters: Float
    public var tailThicknessMeters: Float

    public var wingKinematics: WingKinematics

    public init(
        bodyRadiiMeters: SIMD3<Float>,
        massKilograms: Float,
        principalInertiaKilogramMetersSquared: SIMD3<Float>,
        wingSpanMeters: Float,
        wingRootChordMeters: Float,
        wingTipChordMeters: Float,
        wingThicknessMeters: Float,
        wingSweepMeters: Float,
        wingRootOffsetMeters: SIMD3<Float>,
        tailLengthMeters: Float,
        tailHalfWidthMeters: Float,
        tailThicknessMeters: Float,
        wingKinematics: WingKinematics
    ) {
        self.bodyRadiiMeters = bodyRadiiMeters
        self.massKilograms = massKilograms
        self.principalInertiaKilogramMetersSquared = principalInertiaKilogramMetersSquared
        self.wingSpanMeters = wingSpanMeters
        self.wingRootChordMeters = wingRootChordMeters
        self.wingTipChordMeters = wingTipChordMeters
        self.wingThicknessMeters = wingThicknessMeters
        self.wingSweepMeters = wingSweepMeters
        self.wingRootOffsetMeters = wingRootOffsetMeters
        self.tailLengthMeters = tailLengthMeters
        self.tailHalfWidthMeters = tailHalfWidthMeters
        self.tailThicknessMeters = tailThicknessMeters
        self.wingKinematics = wingKinematics
    }

    /// A numerically convenient development case, not a calibrated species.
    public static let demonstration = BirdParameters(
        bodyRadiiMeters: SIMD3<Float>(0.18, 0.065, 0.075),
        massKilograms: 0.42,
        principalInertiaKilogramMetersSquared: SIMD3<Float>(0.0024, 0.0068, 0.0074),
        wingSpanMeters: 0.34,
        wingRootChordMeters: 0.14,
        wingTipChordMeters: 0.055,
        wingThicknessMeters: 0.018,
        wingSweepMeters: 0.055,
        wingRootOffsetMeters: SIMD3<Float>(0.02, 0.055, 0.02),
        tailLengthMeters: 0.17,
        tailHalfWidthMeters: 0.11,
        tailThicknessMeters: 0.018,
        wingKinematics: WingKinematics(
            frequencyHz: 4.5,
            strokeAmplitudeRadians: radians(42),
            strokeBiasRadians: radians(2),
            pitchMeanRadians: radians(8),
            pitchAmplitudeRadians: radians(24),
            pitchPhaseRadians: radians(78)
        )
    )


    private var localHalfExtentMeters: SIMD3<Float> {
        let maximumChord = max(wingRootChordMeters, wingTipChordMeters)
        let maximumStroke = abs(wingKinematics.strokeBiasRadians)
            + abs(wingKinematics.strokeAmplitudeRadians)
        let wingX = abs(wingRootOffsetMeters.x)
            + abs(wingSweepMeters)
            + 0.5 * maximumChord
        let wingY = abs(wingRootOffsetMeters.y)
            + wingSpanMeters
            + 0.5 * wingThicknessMeters
        let wingZ = abs(wingRootOffsetMeters.z)
            + wingSpanMeters * min(1, abs(sin(maximumStroke)))
            + 0.5 * maximumChord
            + 0.5 * wingThicknessMeters

        return SIMD3<Float>(
            max(bodyRadiiMeters.x + tailLengthMeters, wingX),
            max(max(bodyRadiiMeters.y, tailHalfWidthMeters), wingY),
            max(bodyRadiiMeters.z + 0.5 * tailThicknessMeters, wingZ)
        )
    }

    public var maximumPrescribedWingSpeedMetersPerSecond: Float {
        let angularFrequency = 2 * Float.pi * wingKinematics.frequencyHz
        let strokeContribution = angularFrequency
            * abs(wingKinematics.strokeAmplitudeRadians)
            * wingSpanMeters
        let pitchContribution = angularFrequency
            * abs(wingKinematics.pitchAmplitudeRadians)
            * max(wingRootChordMeters, wingTipChordMeters)
        return strokeContribution + pitchContribution
    }

    public func validate(for configuration: SimulationConfiguration) throws {
        let dx = configuration.scaling.cellSizeMeters
        guard massKilograms > 0,
              bodyRadiiMeters.minimumComponent > 0,
              principalInertiaKilogramMetersSquared.minimumComponent > 0,
              wingSpanMeters > 0,
              wingRootChordMeters > 0,
              wingTipChordMeters > 0,
              wingThicknessMeters >= 1.5 * dx,
              tailLengthMeters > 0,
              tailHalfWidthMeters > 0,
              tailThicknessMeters >= 1.5 * dx,
              wingKinematics.frequencyHz >= 0 else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "Bird dimensions, mass, inertia, and wing frequency must be positive; thin surfaces must be at least 1.5 grid cells thick."
            )
        }

        let margin = Float(configuration.spongeWidthCells + 3) * dx
        let marginVector = SIMD3<Float>(repeating: margin)
        let required = 2 * (localHalfExtentMeters + marginVector)
        let domain = configuration.domainSizeMeters

        if required.x > domain.x || required.y > domain.y || required.z > domain.z {
            throw BirdFlowConfigurationError.birdDoesNotFitDomain
        }
    }

    public func validate(
        initialBodyState: BirdBodyState,
        for configuration: SimulationConfiguration
    ) throws {
        try validate(for: configuration)

        // Rotate the local bounding box into world axes and require the whole
        // initial bird to remain outside the far-field sponge plus a small
        // stencil margin.
        let q = initialBodyState.orientationBodyToWorld.normalized
        let localExtent = localHalfExtentMeters
        let worldExtent = absoluteComponents(
            q.rotate(SIMD3<Float>(localExtent.x, 0, 0))
        ) + absoluteComponents(
            q.rotate(SIMD3<Float>(0, localExtent.y, 0))
        ) + absoluteComponents(
            q.rotate(SIMD3<Float>(0, 0, localExtent.z))
        )
        let margin = Float(configuration.spongeWidthCells + 3)
            * configuration.scaling.cellSizeMeters
        let lower = configuration.domainOriginMeters
            + worldExtent
            + SIMD3<Float>(repeating: margin)
        let upper = configuration.domainOriginMeters
            + configuration.domainSizeMeters
            - worldExtent
            - SIMD3<Float>(repeating: margin)
        let position = initialBodyState.positionMeters
        guard position.x >= lower.x, position.y >= lower.y, position.z >= lower.z,
              position.x <= upper.x, position.y <= upper.y, position.z <= upper.z else {
            throw BirdFlowConfigurationError.birdDoesNotFitDomain
        }

        let relativeTranslation = vectorLength(
            initialBodyState.linearVelocityMetersPerSecond
                - configuration.farFieldVelocityMetersPerSecond
        )
        let boundingRadius = vectorLength(bodyRadiiMeters) + wingSpanMeters
        let rigidRotation = vectorLength(
            initialBodyState.angularVelocityBodyRadiansPerSecond
        ) * boundingRadius
        let maximumSurfaceSpeed = relativeTranslation
            + rigidRotation
            + maximumPrescribedWingSpeedMetersPerSecond
        let latticeMach = maximumSurfaceSpeed
            * configuration.scaling.velocityToLattice
            / D3Q19.soundSpeed

        guard latticeMach <= 0.15 else {
            throw BirdFlowConfigurationError.latticeMachTooHigh(latticeMach)
        }
    }
}

private func absoluteComponents(_ value: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(abs(value.x), abs(value.y), abs(value.z))
}

private extension SIMD3 where Scalar == Float {
    var minimumComponent: Float { Swift.min(x, Swift.min(y, z)) }
}

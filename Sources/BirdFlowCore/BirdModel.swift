import Foundation

@frozen
public struct WingKinematics: Sendable, Equatable, Codable {
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
public struct BirdBodyState: Sendable, Equatable, Codable {
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

/// Measured mass properties of one wing in its instantaneous untwisted
/// chord/span/normal frame. The inertia is about the wing center of mass and
/// is diagonal in that registered frame.
@frozen
public struct WingInertialProperties: Sendable, Equatable, Codable {
    public var massKilograms: Float
    public var centerOfMassFromHingeMeters: SIMD3<Float>
    public var principalInertiaKilogramMetersSquared: SIMD3<Float>

    public init(
        massKilograms: Float,
        centerOfMassFromHingeMeters: SIMD3<Float>,
        principalInertiaKilogramMetersSquared: SIMD3<Float>
    ) {
        self.massKilograms = massKilograms
        self.centerOfMassFromHingeMeters = centerOfMassFromHingeMeters
        self.principalInertiaKilogramMetersSquared =
            principalInertiaKilogramMetersSquared
    }
}

/// Prescribed-wing momentum exchange model used by quantitative free flight.
/// Whole-bird mass and inertia include both wings at the registered reference
/// pose; the solver subtracts the phase-resolved internal wing momentum rate
/// so inertial hinge reactions are not silently discarded.
@frozen
public struct PrescribedWingDynamics: Sendable, Equatable, Codable {
    public static let modelIdentifier = "prescribedRigidWingMomentumV1"
    public static let massDefinition = "wholeBirdIncludingWings"
    public static let inertiaDefinition =
        "wholeBirdAtRegisteredReferencePose"

    public var model: String
    public var sourceCitation: String
    public var massDefinition: String
    public var inertiaDefinition: String
    public var left: WingInertialProperties
    public var right: WingInertialProperties

    public init(
        model: String = modelIdentifier,
        sourceCitation: String,
        massDefinition: String = PrescribedWingDynamics.massDefinition,
        inertiaDefinition: String = PrescribedWingDynamics.inertiaDefinition,
        left: WingInertialProperties,
        right: WingInertialProperties
    ) {
        self.model = model
        self.sourceCitation = sourceCitation
        self.massDefinition = massDefinition
        self.inertiaDefinition = inertiaDefinition
        self.left = left
        self.right = right
    }
}

@frozen
public struct BirdParameters: Sendable, Equatable, Codable {
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
    /// When present, the GPU samples these measured periodic keyframes instead
    /// of the analytic sinusoid. Kept optional for checkpoint compatibility.
    public var measuredWingKinematics: MeasuredWingKinematics?
    /// Nil retains the historical massless-prescribed-wing development mode.
    /// Quantitative free flight requires measured properties here.
    public var prescribedWingDynamics: PrescribedWingDynamics?

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
        wingKinematics: WingKinematics,
        measuredWingKinematics: MeasuredWingKinematics? = nil,
        prescribedWingDynamics: PrescribedWingDynamics? = nil
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
        self.measuredWingKinematics = measuredWingKinematics
        self.prescribedWingDynamics = prescribedWingDynamics
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


    /// Conservative body-frame half extent of every articulated surface over
    /// the registered stroke. Runtime domain monitoring rotates this box into
    /// world axes after every free-flight update.
    public var conservativeLocalHalfExtentMeters: SIMD3<Float> {
        if measuredWingKinematics != nil {
            let crossSectionRadius = abs(wingSweepMeters)
                + 0.5 * max(wingRootChordMeters, wingTipChordMeters)
                + 0.5 * wingThicknessMeters
            let wingExtent = absoluteComponents(wingRootOffsetMeters)
                + SIMD3<Float>(
                    repeating: wingSpanMeters + crossSectionRadius
                )
            return maximumComponents(
                wingExtent,
                SIMD3<Float>(
                    bodyRadiiMeters.x + tailLengthMeters,
                    max(bodyRadiiMeters.y, tailHalfWidthMeters),
                    bodyRadiiMeters.z + 0.5 * tailThicknessMeters
                )
            )
        }
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

    /// Radius enclosing the conservative articulated bounding box.
    public var conservativeBoundingRadiusMeters: Float {
        vectorLength(conservativeLocalHalfExtentMeters)
    }

    public var maximumPrescribedWingSpeedMetersPerSecond: Float {
        if let measuredWingKinematics {
            let chord = max(wingRootChordMeters, wingTipChordMeters)
            return measuredWingKinematics
                .maximumSurfaceSpeedMetersPerSecond(
                    wingSpanMeters: wingSpanMeters,
                    maximumChordMeters: chord
                )
        }
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
        try measuredWingKinematics?.validate()
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
              wingKinematics.frequencyHz >= 0,
              measuredWingKinematics?.frequencyHz ?? wingKinematics.frequencyHz >= 0 else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "Bird dimensions, mass, inertia, and wing frequency must be positive; thin surfaces must be at least 1.5 grid cells thick."
            )
        }

        if let dynamics = prescribedWingDynamics {
            try validatePrescribedWingDynamics(dynamics)
        }

        let margin = Float(configuration.spongeWidthCells + 3) * dx
        let marginVector = SIMD3<Float>(repeating: margin)
        let required = 2 * (conservativeLocalHalfExtentMeters + marginVector)
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
        let localExtent = conservativeLocalHalfExtentMeters
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
        let boundingRadius = conservativeBoundingRadiusMeters
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

    public func validatePrescribedWingDynamics(
        _ dynamics: PrescribedWingDynamics
    ) throws {
        guard dynamics.model == PrescribedWingDynamics.modelIdentifier,
              dynamics.massDefinition == PrescribedWingDynamics.massDefinition,
              dynamics.inertiaDefinition
                == PrescribedWingDynamics.inertiaDefinition,
              !dynamics.sourceCitation.trimmingCharacters(
                in: .whitespacesAndNewlines
              ).isEmpty else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "Prescribed wing dynamics must use the registered model, whole-bird mass/inertia definitions, and a source citation."
            )
        }
        for (side, properties) in [
            ("left", dynamics.left),
            ("right", dynamics.right),
        ] {
            let center = properties.centerOfMassFromHingeMeters
            let inertia = properties.principalInertiaKilogramMetersSquared
            guard properties.massKilograms.isFinite,
                  properties.massKilograms > 0,
                  center.x.isFinite, center.y.isFinite, center.z.isFinite,
                  center.y >= 0, center.y <= wingSpanMeters,
                  abs(center.x) <= max(wingRootChordMeters, wingTipChordMeters),
                  abs(center.z) <= wingThicknessMeters,
                  inertia.x.isFinite, inertia.y.isFinite, inertia.z.isFinite,
                  inertia.minimumComponent > 0 else {
                throw BirdFlowConfigurationError.invalidPhysicalScale(
                    "The \(side) wing mass, hinge-relative center of mass, and principal inertia must be finite, positive, and lie inside the registered wing envelope."
                )
            }
        }
        guard dynamics.left.massKilograms + dynamics.right.massKilograms
                < massKilograms else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "The two measured wing masses must be smaller than whole-bird mass."
            )
        }
        if let measuredWingKinematics {
            let hasDistributedTwist = measuredWingKinematics.keyframes.contains {
                abs($0.left.tipTwistRadians) > 1e-5
                    || abs($0.right.tipTwistRadians) > 1e-5
                    || abs($0.left.tipTwistRateRadiansPerSecond) > 1e-4
                    || abs($0.right.tipTwistRateRadiansPerSecond) > 1e-4
            }
            guard !hasDistributedTwist else {
                throw BirdFlowConfigurationError.invalidPhysicalScale(
                    "prescribedRigidWingMomentumV1 requires zero distributed tip twist; use a future distributed-mass model for twisting wings."
                )
            }
        }
    }
}

private func absoluteComponents(_ value: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(abs(value.x), abs(value.y), abs(value.z))
}

private func maximumComponents(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>
) -> SIMD3<Float> {
    SIMD3<Float>(
        max(first.x, second.x),
        max(first.y, second.y),
        max(first.z, second.z)
    )
}

private extension SIMD3 where Scalar == Float {
    var minimumComponent: Float { Swift.min(x, Swift.min(y, z)) }
}

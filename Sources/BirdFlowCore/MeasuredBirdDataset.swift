import Foundation

public enum MeasuredBirdDatasetError: Error, CustomStringConvertible, Equatable {
    case unsupportedSchema(Int)
    case invalidField(String)

    public var description: String {
        switch self {
        case .unsupportedSchema(let version):
            return "Measured-bird schema \(version) is unsupported; expected schema 1 or 2."
        case .invalidField(let message):
            return "Invalid measured-bird dataset: \(message)"
        }
    }
}

/// Angles and physical angular rates for one articulated rigid wing.
///
/// The registered replay convention is intentionally explicit:
/// stroke rotates about body +x, deviation then rotates about the
/// stroke-rotated wing normal, pitch rotates about the resulting span axis,
/// and twist is a linear root-to-tip deformation about that span axis.
@frozen
public struct MeasuredWingState: Sendable, Equatable, Codable {
    public var strokeRadians: Float
    public var deviationRadians: Float
    public var pitchRadians: Float
    public var tipTwistRadians: Float
    public var strokeRateRadiansPerSecond: Float
    public var deviationRateRadiansPerSecond: Float
    public var pitchRateRadiansPerSecond: Float
    public var tipTwistRateRadiansPerSecond: Float

    public init(
        strokeRadians: Float,
        deviationRadians: Float,
        pitchRadians: Float,
        tipTwistRadians: Float = 0,
        strokeRateRadiansPerSecond: Float,
        deviationRateRadiansPerSecond: Float = 0,
        pitchRateRadiansPerSecond: Float,
        tipTwistRateRadiansPerSecond: Float = 0
    ) {
        self.strokeRadians = strokeRadians
        self.deviationRadians = deviationRadians
        self.pitchRadians = pitchRadians
        self.tipTwistRadians = tipTwistRadians
        self.strokeRateRadiansPerSecond = strokeRateRadiansPerSecond
        self.deviationRateRadiansPerSecond = deviationRateRadiansPerSecond
        self.pitchRateRadiansPerSecond = pitchRateRadiansPerSecond
        self.tipTwistRateRadiansPerSecond = tipTwistRateRadiansPerSecond
    }

    fileprivate var angles: SIMD4<Float> {
        SIMD4<Float>(
            strokeRadians,
            deviationRadians,
            pitchRadians,
            tipTwistRadians
        )
    }

    fileprivate var rates: SIMD4<Float> {
        SIMD4<Float>(
            strokeRateRadiansPerSecond,
            deviationRateRadiansPerSecond,
            pitchRateRadiansPerSecond,
            tipTwistRateRadiansPerSecond
        )
    }

    fileprivate init(angles: SIMD4<Float>, rates: SIMD4<Float>) {
        self.init(
            strokeRadians: angles.x,
            deviationRadians: angles.y,
            pitchRadians: angles.z,
            tipTwistRadians: angles.w,
            strokeRateRadiansPerSecond: rates.x,
            deviationRateRadiansPerSecond: rates.y,
            pitchRateRadiansPerSecond: rates.z,
            tipTwistRateRadiansPerSecond: rates.w
        )
    }
}

@frozen
public struct MeasuredWingKeyframe: Sendable, Equatable, Codable {
    /// Cycle phase in `[0, 1)`. The first keyframe must be exactly zero.
    public var phase: Float
    public var left: MeasuredWingState
    public var right: MeasuredWingState

    public init(
        phase: Float,
        left: MeasuredWingState,
        right: MeasuredWingState
    ) {
        self.phase = phase
        self.left = left
        self.right = right
    }
}

@frozen
public struct MeasuredWingKinematics: Sendable, Equatable, Codable {
    public var frequencyHz: Float
    public var keyframes: [MeasuredWingKeyframe]

    public init(frequencyHz: Float, keyframes: [MeasuredWingKeyframe]) {
        self.frequencyHz = frequencyHz
        self.keyframes = keyframes
    }

    public func validate() throws {
        guard frequencyHz.isFinite, frequencyHz > 0 else {
            throw MeasuredBirdDatasetError.invalidField(
                "kinematics.frequencyHz must be finite and positive"
            )
        }
        guard (4...4096).contains(keyframes.count) else {
            throw MeasuredBirdDatasetError.invalidField(
                "kinematics.keyframes must contain 4...4096 samples"
            )
        }
        guard keyframes[0].phase == 0 else {
            throw MeasuredBirdDatasetError.invalidField(
                "the first kinematic phase must be exactly zero"
            )
        }
        var previous: Float = -1
        for (index, keyframe) in keyframes.enumerated() {
            guard keyframe.phase.isFinite,
                  keyframe.phase >= 0,
                  keyframe.phase < 1,
                  keyframe.phase > previous else {
                throw MeasuredBirdDatasetError.invalidField(
                    "kinematic phases must be finite, strictly increasing, and in [0, 1); failure at index \(index)"
                )
            }
            previous = keyframe.phase
            for value in [
                keyframe.left.angles,
                keyframe.left.rates,
                keyframe.right.angles,
                keyframe.right.rates,
            ] where !allFinite(value) {
                throw MeasuredBirdDatasetError.invalidField(
                    "kinematic angles and rates must be finite; failure at index \(index)"
                )
            }
        }
    }

    /// Periodic cubic-Hermite interpolation. Input rates are physical rates,
    /// so replay wall velocity is consistent with the interpolated pose.
    public func sample(atPhase phase: Float) -> (
        left: MeasuredWingState,
        right: MeasuredWingState
    ) {
        precondition(!keyframes.isEmpty)
        var wrapped = phase.truncatingRemainder(dividingBy: 1)
        if wrapped < 0 { wrapped += 1 }

        let upper = keyframes.firstIndex { $0.phase > wrapped }
        let lowerIndex: Int
        let upperIndex: Int
        let phase0: Float
        let phase1: Float
        if let upper {
            lowerIndex = upper - 1
            upperIndex = upper
            phase0 = keyframes[lowerIndex].phase
            phase1 = keyframes[upperIndex].phase
        } else {
            lowerIndex = keyframes.count - 1
            upperIndex = 0
            phase0 = keyframes[lowerIndex].phase
            phase1 = 1
        }

        let interval = phase1 - phase0
        let adjustedPhase = upperIndex == 0 && wrapped < phase0
            ? wrapped + 1
            : wrapped
        let fraction = (adjustedPhase - phase0) / interval
        let seconds = interval / frequencyHz
        let lower = keyframes[lowerIndex]
        let upperFrame = keyframes[upperIndex]
        return (
            hermite(lower.left, upperFrame.left, fraction, seconds),
            hermite(lower.right, upperFrame.right, fraction, seconds)
        )
    }

    public var maximumAngularRateRadiansPerSecond: Float {
        max(
            maximumComponentRate(left: true),
            maximumComponentRate(left: false)
        )
    }

    /// Exact maximum of the conservative rigid/twist speed expression over
    /// every Hermite interval. Quadratic-rate zeros split the absolute-value
    /// sum into pieces whose extrema are analytic.
    public func maximumSurfaceSpeedMetersPerSecond(
        wingSpanMeters: Float,
        maximumChordMeters: Float
    ) -> Float {
        max(
            maximumSurfaceSpeed(
                left: true,
                span: wingSpanMeters,
                chord: maximumChordMeters
            ),
            maximumSurfaceSpeed(
                left: false,
                span: wingSpanMeters,
                chord: maximumChordMeters
            )
        )
    }

    private func maximumComponentRate(left: Bool) -> Float {
        var result: Float = 0
        for interval in hermiteRateIntervals(left: left) {
            for polynomial in interval {
                var candidates: [Float] = [0, 1]
                if abs(polynomial.a) > 1e-12 {
                    let vertex = -polynomial.b / (2 * polynomial.a)
                    if vertex > 0, vertex < 1 {
                        candidates.append(vertex)
                    }
                }
                for candidate in candidates {
                    result = max(result, abs(polynomial.value(candidate)))
                }
            }
        }
        return result
    }

    private func maximumSurfaceSpeed(
        left: Bool,
        span: Float,
        chord: Float
    ) -> Float {
        let weights = [span, span, chord, chord]
        var maximum: Float = 0
        for interval in hermiteRateIntervals(left: left) {
            var cuts: [Float] = [0, 1]
            for polynomial in interval {
                cuts.append(contentsOf: polynomial.rootsInUnitInterval)
            }
            cuts.sort()
            var unique: [Float] = []
            for cut in cuts where unique.last.map({ abs($0 - cut) > 1e-6 }) ?? true {
                unique.append(cut)
            }
            for index in 0..<(unique.count - 1) {
                let lower = unique[index]
                let upper = unique[index + 1]
                guard upper - lower > 1e-7 else { continue }
                let middle = 0.5 * (lower + upper)
                var combined = Quadratic.zero
                for component in 0..<4 {
                    let polynomial = interval[component]
                    let sign: Float = polynomial.value(middle) >= 0 ? 1 : -1
                    combined += polynomial * (weights[component] * sign)
                }
                var candidates = [lower, upper]
                if abs(combined.a) > 1e-12 {
                    let vertex = -combined.b / (2 * combined.a)
                    if vertex > lower, vertex < upper {
                        candidates.append(vertex)
                    }
                }
                for candidate in candidates {
                    var speed: Float = 0
                    for component in 0..<4 {
                        speed += weights[component]
                            * abs(interval[component].value(candidate))
                    }
                    maximum = max(maximum, speed)
                }
            }
        }
        return maximum
    }

    private func hermiteRateIntervals(left: Bool) -> [[Quadratic]] {
        keyframes.indices.map { index in
            let nextIndex = (index + 1) % keyframes.count
            let first = left ? keyframes[index].left : keyframes[index].right
            let second = left
                ? keyframes[nextIndex].left
                : keyframes[nextIndex].right
            let nextPhase = nextIndex == 0
                ? keyframes[nextIndex].phase + 1
                : keyframes[nextIndex].phase
            let seconds = (nextPhase - keyframes[index].phase) / frequencyHz
            return (0..<4).map { component in
                let angle0 = first.angles[component]
                let angle1 = second.angles[component]
                let rate0 = first.rates[component]
                let rate1 = second.rates[component]
                return Quadratic(
                    a: (
                        6 * angle0 + 3 * seconds * rate0
                            - 6 * angle1 + 3 * seconds * rate1
                    ) / seconds,
                    b: (
                        -6 * angle0 - 4 * seconds * rate0
                            + 6 * angle1 - 2 * seconds * rate1
                    ) / seconds,
                    c: rate0
                )
            }
        }
    }
}

@frozen
public struct MeasuredBirdProvenance: Sendable, Equatable, Codable {
    public var specimenIdentifier: String
    public var geometryCitation: String
    public var kinematicsCitation: String
    public var dataLicense: String
    public var processingDescription: String

    public init(
        specimenIdentifier: String,
        geometryCitation: String,
        kinematicsCitation: String,
        dataLicense: String,
        processingDescription: String
    ) {
        self.specimenIdentifier = specimenIdentifier
        self.geometryCitation = geometryCitation
        self.kinematicsCitation = kinematicsCitation
        self.dataLicense = dataLicense
        self.processingDescription = processingDescription
    }
}

@frozen
public struct MeasuredBirdUnits: Sendable, Equatable, Codable {
    public var length: String
    public var mass: String
    public var time: String
    public var angle: String
    public var angularRate: String

    public init(
        length: String = "meter",
        mass: String = "kilogram",
        time: String = "second",
        angle: String = "radian",
        angularRate: String = "radianPerSecond"
    ) {
        self.length = length
        self.mass = mass
        self.time = time
        self.angle = angle
        self.angularRate = angularRate
    }

    public static let si = MeasuredBirdUnits()
}

@frozen
public struct MeasuredBirdCoordinateFrame: Sendable, Equatable, Codable {
    public var handedness: String
    public var origin: String
    public var xAxis: String
    public var yAxis: String
    public var zAxis: String

    public init(
        handedness: String = "rightHanded",
        origin: String = "centerOfMass",
        xAxis: String = "forward",
        yAxis: String = "left",
        zAxis: String = "up"
    ) {
        self.handedness = handedness
        self.origin = origin
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.zAxis = zAxis
    }

    public static let birdFlowPrincipalAxes = MeasuredBirdCoordinateFrame()
}

/// Measured morphometrics registered to the solver's analytic proxy boundary.
/// This is a useful ingestion tier, but deliberately not a scanned-mesh claim.
@frozen
public struct RegisteredAnalyticBirdGeometry: Sendable, Equatable, Codable {
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
        tailThicknessMeters: Float
    ) {
        self.bodyRadiiMeters = bodyRadiiMeters
        self.massKilograms = massKilograms
        self.principalInertiaKilogramMetersSquared =
            principalInertiaKilogramMetersSquared
        self.wingSpanMeters = wingSpanMeters
        self.wingRootChordMeters = wingRootChordMeters
        self.wingTipChordMeters = wingTipChordMeters
        self.wingThicknessMeters = wingThicknessMeters
        self.wingSweepMeters = wingSweepMeters
        self.wingRootOffsetMeters = wingRootOffsetMeters
        self.tailLengthMeters = tailLengthMeters
        self.tailHalfWidthMeters = tailHalfWidthMeters
        self.tailThicknessMeters = tailThicknessMeters
    }

    public init(from bird: BirdParameters) {
        self.init(
            bodyRadiiMeters: bird.bodyRadiiMeters,
            massKilograms: bird.massKilograms,
            principalInertiaKilogramMetersSquared:
                bird.principalInertiaKilogramMetersSquared,
            wingSpanMeters: bird.wingSpanMeters,
            wingRootChordMeters: bird.wingRootChordMeters,
            wingTipChordMeters: bird.wingTipChordMeters,
            wingThicknessMeters: bird.wingThicknessMeters,
            wingSweepMeters: bird.wingSweepMeters,
            wingRootOffsetMeters: bird.wingRootOffsetMeters,
            tailLengthMeters: bird.tailLengthMeters,
            tailHalfWidthMeters: bird.tailHalfWidthMeters,
            tailThicknessMeters: bird.tailThicknessMeters
        )
    }

    public func birdParameters(
        measuredKinematics: MeasuredWingKinematics,
        prescribedWingDynamics: PrescribedWingDynamics? = nil
    ) -> BirdParameters {
        BirdParameters(
            bodyRadiiMeters: bodyRadiiMeters,
            massKilograms: massKilograms,
            principalInertiaKilogramMetersSquared:
                principalInertiaKilogramMetersSquared,
            wingSpanMeters: wingSpanMeters,
            wingRootChordMeters: wingRootChordMeters,
            wingTipChordMeters: wingTipChordMeters,
            wingThicknessMeters: wingThicknessMeters,
            wingSweepMeters: wingSweepMeters,
            wingRootOffsetMeters: wingRootOffsetMeters,
            tailLengthMeters: tailLengthMeters,
            tailHalfWidthMeters: tailHalfWidthMeters,
            tailThicknessMeters: tailThicknessMeters,
            wingKinematics: WingKinematics(
                frequencyHz: measuredKinematics.frequencyHz,
                strokeAmplitudeRadians: 0,
                pitchMeanRadians: 0,
                pitchAmplitudeRadians: 0,
                pitchPhaseRadians: 0
            ),
            measuredWingKinematics: measuredKinematics,
            prescribedWingDynamics: prescribedWingDynamics
        )
    }
}

@frozen
public struct MeasuredBirdReplayConditions: Sendable, Equatable, Codable {
    public var domainOriginMeters: SIMD3<Float>
    public var domainSizeMeters: SIMD3<Float>
    public var bodyPositionMeters: SIMD3<Float>
    public var bodyOrientationBodyToWorld: Quaternion
    public var farFieldVelocityMetersPerSecond: SIMD3<Float>
    public var gravityMetersPerSecondSquared: SIMD3<Float>
    public var referenceSpeedMetersPerSecond: Float
    public var targetReynoldsNumber: Float
    public var physicalAirDensity: Float
    public var latticeReferenceSpeed: Float
    public var spongeStrength: Float

    public init(
        domainOriginMeters: SIMD3<Float>,
        domainSizeMeters: SIMD3<Float>,
        bodyPositionMeters: SIMD3<Float>,
        bodyOrientationBodyToWorld: Quaternion = .identity,
        farFieldVelocityMetersPerSecond: SIMD3<Float>,
        gravityMetersPerSecondSquared: SIMD3<Float> = .zero,
        referenceSpeedMetersPerSecond: Float,
        targetReynoldsNumber: Float,
        physicalAirDensity: Float,
        latticeReferenceSpeed: Float = 0.04,
        spongeStrength: Float = 0.06
    ) {
        self.domainOriginMeters = domainOriginMeters
        self.domainSizeMeters = domainSizeMeters
        self.bodyPositionMeters = bodyPositionMeters
        self.bodyOrientationBodyToWorld = bodyOrientationBodyToWorld
        self.farFieldVelocityMetersPerSecond = farFieldVelocityMetersPerSecond
        self.gravityMetersPerSecondSquared = gravityMetersPerSecondSquared
        self.referenceSpeedMetersPerSecond = referenceSpeedMetersPerSecond
        self.targetReynoldsNumber = targetReynoldsNumber
        self.physicalAirDensity = physicalAirDensity
        self.latticeReferenceSpeed = latticeReferenceSpeed
        self.spongeStrength = spongeStrength
    }
}

@frozen
public struct MeasuredBirdDataset: Sendable, Equatable, Codable {
    public static let currentSchemaVersion = 2
    public static let analyticProxyRepresentation =
        "registeredAnalyticProxyV1"

    public var schemaVersion: Int
    public var datasetIdentifier: String
    public var provenance: MeasuredBirdProvenance
    public var units: MeasuredBirdUnits
    public var coordinateFrame: MeasuredBirdCoordinateFrame
    public var geometryRepresentation: String
    public var geometry: RegisteredAnalyticBirdGeometry
    public var kinematics: MeasuredWingKinematics
    /// Required by schema 2. Schema 1 remains readable for prescribed replay,
    /// but is not quantitative-free-flight qualified.
    public var prescribedWingDynamics: PrescribedWingDynamics?
    public var replay: MeasuredBirdReplayConditions

    public init(
        schemaVersion: Int = currentSchemaVersion,
        datasetIdentifier: String,
        provenance: MeasuredBirdProvenance,
        units: MeasuredBirdUnits = .si,
        coordinateFrame: MeasuredBirdCoordinateFrame = .birdFlowPrincipalAxes,
        geometryRepresentation: String = analyticProxyRepresentation,
        geometry: RegisteredAnalyticBirdGeometry,
        kinematics: MeasuredWingKinematics,
        prescribedWingDynamics: PrescribedWingDynamics? = nil,
        replay: MeasuredBirdReplayConditions
    ) {
        self.schemaVersion = schemaVersion
        self.datasetIdentifier = datasetIdentifier
        self.provenance = provenance
        self.units = units
        self.coordinateFrame = coordinateFrame
        self.geometryRepresentation = geometryRepresentation
        self.geometry = geometry
        self.kinematics = kinematics
        self.prescribedWingDynamics = prescribedWingDynamics
        self.replay = replay
    }

    public func validate() throws {
        guard (1...Self.currentSchemaVersion).contains(schemaVersion) else {
            throw MeasuredBirdDatasetError.unsupportedSchema(schemaVersion)
        }
        guard schemaVersion < 2 || prescribedWingDynamics != nil else {
            throw MeasuredBirdDatasetError.invalidField(
                "schema 2 requires prescribedWingDynamics with measured bilateral mass properties"
            )
        }
        guard !datasetIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty else {
            throw MeasuredBirdDatasetError.invalidField(
                "datasetIdentifier must not be empty"
            )
        }
        for (name, value) in [
            ("specimenIdentifier", provenance.specimenIdentifier),
            ("geometryCitation", provenance.geometryCitation),
            ("kinematicsCitation", provenance.kinematicsCitation),
            ("dataLicense", provenance.dataLicense),
            ("processingDescription", provenance.processingDescription),
        ] where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw MeasuredBirdDatasetError.invalidField(
                "provenance.\(name) must not be empty"
            )
        }
        guard units == .si else {
            throw MeasuredBirdDatasetError.invalidField(
                "units must be meter/kilogram/second/radian/radianPerSecond"
            )
        }
        guard coordinateFrame == .birdFlowPrincipalAxes else {
            throw MeasuredBirdDatasetError.invalidField(
                "coordinateFrame must be right-handed, COM-centered principal axes with +x forward, +y left, +z up"
            )
        }
        guard geometryRepresentation == Self.analyticProxyRepresentation else {
            throw MeasuredBirdDatasetError.invalidField(
                "geometryRepresentation must be registeredAnalyticProxyV1; mesh/SDF replay is not implemented"
            )
        }
        try kinematics.validate()
        if let prescribedWingDynamics {
            let bird = geometry.birdParameters(
                measuredKinematics: kinematics,
                prescribedWingDynamics: prescribedWingDynamics
            )
            do {
                try bird.validatePrescribedWingDynamics(
                    prescribedWingDynamics
                )
            } catch {
                throw MeasuredBirdDatasetError.invalidField(
                    String(describing: error)
                )
            }
        }
        let numeric = [
            geometry.bodyRadiiMeters.x,
            geometry.bodyRadiiMeters.y,
            geometry.bodyRadiiMeters.z,
            geometry.massKilograms,
            geometry.principalInertiaKilogramMetersSquared.x,
            geometry.principalInertiaKilogramMetersSquared.y,
            geometry.principalInertiaKilogramMetersSquared.z,
            geometry.wingSpanMeters,
            geometry.wingRootChordMeters,
            geometry.wingTipChordMeters,
            geometry.wingThicknessMeters,
            geometry.wingSweepMeters,
            geometry.wingRootOffsetMeters.x,
            geometry.wingRootOffsetMeters.y,
            geometry.wingRootOffsetMeters.z,
            geometry.tailLengthMeters,
            geometry.tailHalfWidthMeters,
            geometry.tailThicknessMeters,
            replay.domainOriginMeters.x,
            replay.domainOriginMeters.y,
            replay.domainOriginMeters.z,
            replay.domainSizeMeters.x,
            replay.domainSizeMeters.y,
            replay.domainSizeMeters.z,
            replay.bodyPositionMeters.x,
            replay.bodyPositionMeters.y,
            replay.bodyPositionMeters.z,
            replay.farFieldVelocityMetersPerSecond.x,
            replay.farFieldVelocityMetersPerSecond.y,
            replay.farFieldVelocityMetersPerSecond.z,
            replay.referenceSpeedMetersPerSecond,
            replay.targetReynoldsNumber,
            replay.physicalAirDensity,
            replay.latticeReferenceSpeed,
            replay.spongeStrength,
        ]
        guard numeric.allSatisfy(\.isFinite),
              geometry.bodyRadiiMeters.x > 0,
              geometry.bodyRadiiMeters.y > 0,
              geometry.bodyRadiiMeters.z > 0,
              geometry.massKilograms > 0,
              geometry.principalInertiaKilogramMetersSquared.x > 0,
              geometry.principalInertiaKilogramMetersSquared.y > 0,
              geometry.principalInertiaKilogramMetersSquared.z > 0,
              geometry.wingSpanMeters > 0,
              geometry.wingRootChordMeters > 0,
              geometry.wingTipChordMeters > 0,
              geometry.wingThicknessMeters > 0,
              geometry.wingRootOffsetMeters.y >= 0,
              geometry.tailLengthMeters > 0,
              geometry.tailHalfWidthMeters > 0,
              geometry.tailThicknessMeters > 0,
              replay.domainSizeMeters.x > 0,
              replay.domainSizeMeters.y > 0,
              replay.domainSizeMeters.z > 0,
              replay.referenceSpeedMetersPerSecond > 0,
              replay.targetReynoldsNumber > 0,
              replay.physicalAirDensity > 0,
              replay.latticeReferenceSpeed > 0,
              replay.spongeStrength >= 0,
              replay.spongeStrength <= 1,
              allFinite(replay.bodyOrientationBodyToWorld.simd4),
              quaternionLength(replay.bodyOrientationBodyToWorld.simd4) > 0 else {
            throw MeasuredBirdDatasetError.invalidField(
                "geometry and replay dimensions, dynamics, and flow values must be finite and physically positive"
            )
        }
    }
}

private func hermite(
    _ first: MeasuredWingState,
    _ second: MeasuredWingState,
    _ fraction: Float,
    _ intervalSeconds: Float
) -> MeasuredWingState {
    let t = fraction
    let t2 = t * t
    let t3 = t2 * t
    let h00 = 2 * t3 - 3 * t2 + 1
    let h10 = t3 - 2 * t2 + t
    let h01 = -2 * t3 + 3 * t2
    let h11 = t3 - t2
    let angles = h00 * first.angles
        + h10 * intervalSeconds * first.rates
        + h01 * second.angles
        + h11 * intervalSeconds * second.rates
    let derivative = (6 * t2 - 6 * t) * first.angles
        + (3 * t2 - 4 * t + 1) * intervalSeconds * first.rates
        + (-6 * t2 + 6 * t) * second.angles
        + (3 * t2 - 2 * t) * intervalSeconds * second.rates
    return MeasuredWingState(
        angles: angles,
        rates: derivative / intervalSeconds
    )
}

private func allFinite(_ value: SIMD4<Float>) -> Bool {
    value.x.isFinite && value.y.isFinite
        && value.z.isFinite && value.w.isFinite
}

private func quaternionLength(_ value: SIMD4<Float>) -> Float {
    sqrt(value.x * value.x + value.y * value.y
        + value.z * value.z + value.w * value.w)
}

private struct Quadratic {
    var a: Float
    var b: Float
    var c: Float

    static let zero = Quadratic(a: 0, b: 0, c: 0)

    func value(_ x: Float) -> Float { (a * x + b) * x + c }

    var rootsInUnitInterval: [Float] {
        if abs(a) <= 1e-12 {
            guard abs(b) > 1e-12 else { return [] }
            let root = -c / b
            return root > 0 && root < 1 ? [root] : []
        }
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return [] }
        let root = sqrt(discriminant)
        return [(-b - root) / (2 * a), (-b + root) / (2 * a)]
            .filter { $0 > 0 && $0 < 1 }
    }

    static func * (lhs: Quadratic, rhs: Float) -> Quadratic {
        Quadratic(a: lhs.a * rhs, b: lhs.b * rhs, c: lhs.c * rhs)
    }

    static func += (lhs: inout Quadratic, rhs: Quadratic) {
        lhs.a += rhs.a
        lhs.b += rhs.b
        lhs.c += rhs.c
    }
}

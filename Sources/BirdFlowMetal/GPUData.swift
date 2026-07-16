import BirdFlowCore
import Foundation

struct GPUUniforms {
    var grid: SIMD4<UInt32>
    var originAndCellSize: SIMD4<Float>
    var timeStepAndScales: SIMD4<Float>
    var latticeAndSponge: SIMD4<Float>
    var farFieldLattice: SIMD4<Float>
    var gravity: SIMD4<Float>
    var caseParameters: SIMD4<Float>
    var flags: SIMD4<UInt32>
    var integration: SIMD4<UInt32>

    init(
        configuration: SimulationConfiguration,
        time: Float,
        captureMacroscopicFields: Bool = true,
        accumulateLoads: Bool = true,
        hasPreviousGeometry: Bool = false,
        periodicBoundaries: Bool = false,
        usePreStepLocalDensityForMovingWall: Bool = false,
        shearWaveAmplitude: Float = 0,
        caseParameters: SIMD4<Float>? = nil
    ) {
        grid = SIMD4<UInt32>(
            UInt32(configuration.grid.x),
            UInt32(configuration.grid.y),
            UInt32(configuration.grid.z),
            UInt32(configuration.grid.cellCount)
        )
        originAndCellSize = SIMD4<Float>(
            configuration.domainOriginMeters.x,
            configuration.domainOriginMeters.y,
            configuration.domainOriginMeters.z,
            configuration.scaling.cellSizeMeters
        )
        timeStepAndScales = SIMD4<Float>(
            time,
            configuration.scaling.timeStepSeconds,
            configuration.scaling.velocityToLattice,
            configuration.scaling.forceToPhysical
        )
        latticeAndSponge = SIMD4<Float>(
            configuration.scaling.omegaPlus,
            configuration.scaling.omegaMinus,
            configuration.spongeStrength,
            Float(configuration.spongeWidthCells)
        )
        farFieldLattice = SIMD4<Float>(
            configuration.farFieldVelocityMetersPerSecond.x
                * configuration.scaling.velocityToLattice,
            configuration.farFieldVelocityMetersPerSecond.y
                * configuration.scaling.velocityToLattice,
            configuration.farFieldVelocityMetersPerSecond.z
                * configuration.scaling.velocityToLattice,
            1
        )
        gravity = SIMD4<Float>(
            configuration.gravityMetersPerSecondSquared.x,
            configuration.gravityMetersPerSecondSquared.y,
            configuration.gravityMetersPerSecondSquared.z,
            accumulateLoads ? 1 : 0
        )
        self.caseParameters = caseParameters
            ?? SIMD4<Float>(shearWaveAmplitude, 0, 0, 0)
        flags = SIMD4<UInt32>(
            configuration.freeFlight ? 1 : 0,
            captureMacroscopicFields ? 1 : 0,
            hasPreviousGeometry ? 1 : 0,
            periodicBoundaries ? 1 : 0
        )
        integration = SIMD4<UInt32>(
            UInt32(configuration.bodySubsteps),
            usePreStepLocalDensityForMovingWall ? 1 : 0,
            0,
            0
        )
    }
}

struct GPUBirdParameters {
    var bodyRadiiAndMass: SIMD4<Float>
    var inertia: SIMD4<Float>
    var wingGeometry0: SIMD4<Float>
    var wingGeometry1: SIMD4<Float>
    var tailGeometry: SIMD4<Float>
    var wingKinematics0: SIMD4<Float>
    var wingKinematics1: SIMD4<Float>
    var safetyGeometry: SIMD4<Float>
    var safetyLimits: SIMD4<Float>
    var leftWingMassAndCOM: SIMD4<Float>
    var leftWingInertia: SIMD4<Float>
    var rightWingMassAndCOM: SIMD4<Float>
    var rightWingInertia: SIMD4<Float>

    init(_ parameters: BirdParameters) {
        bodyRadiiAndMass = SIMD4<Float>(
            parameters.bodyRadiiMeters.x,
            parameters.bodyRadiiMeters.y,
            parameters.bodyRadiiMeters.z,
            parameters.massKilograms
        )
        inertia = SIMD4<Float>(
            parameters.principalInertiaKilogramMetersSquared.x,
            parameters.principalInertiaKilogramMetersSquared.y,
            parameters.principalInertiaKilogramMetersSquared.z,
            0
        )
        wingGeometry0 = SIMD4<Float>(
            parameters.wingSpanMeters,
            parameters.wingRootChordMeters,
            parameters.wingTipChordMeters,
            parameters.wingThicknessMeters
        )
        wingGeometry1 = SIMD4<Float>(
            parameters.wingSweepMeters,
            parameters.wingRootOffsetMeters.x,
            parameters.wingRootOffsetMeters.y,
            parameters.wingRootOffsetMeters.z
        )
        tailGeometry = SIMD4<Float>(
            parameters.tailLengthMeters,
            parameters.tailHalfWidthMeters,
            parameters.tailThicknessMeters,
            0
        )
        wingKinematics0 = SIMD4<Float>(
            parameters.wingKinematics.frequencyHz,
            parameters.wingKinematics.strokeAmplitudeRadians,
            parameters.wingKinematics.strokeBiasRadians,
            parameters.wingKinematics.pitchMeanRadians
        )
        wingKinematics1 = SIMD4<Float>(
            parameters.wingKinematics.pitchAmplitudeRadians,
            parameters.wingKinematics.pitchPhaseRadians,
            Float(parameters.measuredWingKinematics?.keyframes.count ?? 0),
            parameters.measuredWingKinematics == nil ? 0 : 1
        )
        safetyGeometry = SIMD4<Float>(
            parameters.conservativeLocalHalfExtentMeters,
            parameters.conservativeBoundingRadiusMeters
        )
        safetyLimits = SIMD4<Float>(
            parameters.maximumPrescribedWingSpeedMetersPerSecond,
            0.15,
            0,
            0
        )
        if let dynamics = parameters.prescribedWingDynamics {
            leftWingMassAndCOM = SIMD4<Float>(
                dynamics.left.massKilograms,
                dynamics.left.centerOfMassFromHingeMeters.x,
                dynamics.left.centerOfMassFromHingeMeters.y,
                dynamics.left.centerOfMassFromHingeMeters.z
            )
            leftWingInertia = SIMD4<Float>(
                dynamics.left.principalInertiaKilogramMetersSquared,
                1
            )
            rightWingMassAndCOM = SIMD4<Float>(
                dynamics.right.massKilograms,
                dynamics.right.centerOfMassFromHingeMeters.x,
                dynamics.right.centerOfMassFromHingeMeters.y,
                dynamics.right.centerOfMassFromHingeMeters.z
            )
            rightWingInertia = SIMD4<Float>(
                dynamics.right.principalInertiaKilogramMetersSquared,
                1
            )
        } else {
            leftWingMassAndCOM = .zero
            leftWingInertia = .zero
            rightWingMassAndCOM = .zero
            rightWingInertia = .zero
        }
    }
}

struct GPUWingMomentumState {
    var leftLinear: SIMD4<Float>
    var leftAngular: SIMD4<Float>
    var rightLinear: SIMD4<Float>
    var rightAngular: SIMD4<Float>

    static let zero = GPUWingMomentumState(
        leftLinear: .zero,
        leftAngular: .zero,
        rightLinear: .zero,
        rightAngular: .zero
    )
}

struct GPUWingInertialReaction {
    var leftForce: SIMD4<Float>
    var leftTorque: SIMD4<Float>
    var rightForce: SIMD4<Float>
    var rightTorque: SIMD4<Float>

    static let zero = GPUWingInertialReaction(
        leftForce: .zero,
        leftTorque: .zero,
        rightForce: .zero,
        rightTorque: .zero
    )

    var total: ForceTorque {
        ForceTorque(
            forceNewtons: (leftForce + rightForce).xyz,
            torqueNewtonMeters: (leftTorque + rightTorque).xyz
        )
    }
}

/// Compact opt-in partial used by the coupled total-system momentum ledger.
/// `massAndMomentum` stores mass in x and lattice momentum in yzw.
struct GPUFluidMassMomentum {
    var massAndMomentum: SIMD4<Float>
}

/// External fluid sources reconstructed outside the production hot path.
/// Each float4 stores mass in x and lattice momentum in yzw.
struct GPUExternalFluidSourceLedger {
    var farField: SIMD4<Float>
    var sponge: SIMD4<Float>
    var persistentLinkExchange: SIMD4<Float>
    /// x=far-field links, y=sponge cells, z=persistent boundary links,
    /// w=cover + uncover transition cells.
    var counts: SIMD4<UInt32>
}

/// GPU-owned extrema and first-event ledger for free-flight validity bounds.
/// A single monitoring thread updates it after every body integration.
struct GPURuntimeSafetyRecord {
    /// x=max Mach, y=min clearance, z=Mach at first event,
    /// w=clearance at first event.
    var metrics: SIMD4<Float>
    /// x/y=first event step low/high words; z=violation flags.
    var event: SIMD4<UInt32>

    static let clear = GPURuntimeSafetyRecord(
        metrics: SIMD4<Float>(0, .greatestFiniteMagnitude, 0, 0),
        event: .zero
    )
}

/// One measured periodic keyframe. Float4-only packing is shared verbatim
/// with Metal; the preparation kernel is the sole consumer per fluid step.
struct GPUMeasuredWingKeyframe {
    var phase: SIMD4<Float>
    var leftAngles: SIMD4<Float>
    var leftRates: SIMD4<Float>
    var rightAngles: SIMD4<Float>
    var rightRates: SIMD4<Float>

    init(_ keyframe: MeasuredWingKeyframe) {
        phase = SIMD4<Float>(keyframe.phase, 0, 0, 0)
        leftAngles = SIMD4<Float>(
            keyframe.left.strokeRadians,
            keyframe.left.deviationRadians,
            keyframe.left.pitchRadians,
            keyframe.left.tipTwistRadians
        )
        leftRates = SIMD4<Float>(
            keyframe.left.strokeRateRadiansPerSecond,
            keyframe.left.deviationRateRadiansPerSecond,
            keyframe.left.pitchRateRadiansPerSecond,
            keyframe.left.tipTwistRateRadiansPerSecond
        )
        rightAngles = SIMD4<Float>(
            keyframe.right.strokeRadians,
            keyframe.right.deviationRadians,
            keyframe.right.pitchRadians,
            keyframe.right.tipTwistRadians
        )
        rightRates = SIMD4<Float>(
            keyframe.right.strokeRateRadiansPerSecond,
            keyframe.right.deviationRateRadiansPerSecond,
            keyframe.right.pitchRateRadiansPerSecond,
            keyframe.right.tipTwistRateRadiansPerSecond
        )
    }
}

struct GPUBirdBodyState {
    var position: SIMD4<Float>
    var orientation: SIMD4<Float>
    var linearVelocity: SIMD4<Float>
    var angularVelocityBody: SIMD4<Float>

    init(_ state: BirdBodyState) {
        position = SIMD4<Float>(
            state.positionMeters.x,
            state.positionMeters.y,
            state.positionMeters.z,
            0
        )
        orientation = state.orientationBodyToWorld.normalized.simd4
        linearVelocity = SIMD4<Float>(
            state.linearVelocityMetersPerSecond.x,
            state.linearVelocityMetersPerSecond.y,
            state.linearVelocityMetersPerSecond.z,
            0
        )
        angularVelocityBody = SIMD4<Float>(
            state.angularVelocityBodyRadiansPerSecond.x,
            state.angularVelocityBodyRadiansPerSecond.y,
            state.angularVelocityBodyRadiansPerSecond.z,
            0
        )
    }

    var coreValue: BirdBodyState {
        BirdBodyState(
            positionMeters: position.xyz,
            orientationBodyToWorld: Quaternion(simd4: orientation).normalized,
            linearVelocityMetersPerSecond: linearVelocity.xyz,
            angularVelocityBodyRadiansPerSecond: angularVelocityBody.xyz
        )
    }
}

/// Dispatch-uniform pose and articulated wing frames prepared once per fluid
/// step. Every field is a float4 so Swift and Metal retain identical packing.
struct GPUPreparedBirdGeometry {
    var bodyPosition: SIMD4<Float>
    var orientation: SIMD4<Float>
    var linearVelocity: SIMD4<Float>
    var omegaBodyWorld: SIMD4<Float>
    var leftRoot: SIMD4<Float>
    var leftChord: SIMD4<Float>
    var leftSpan: SIMD4<Float>
    var leftNormal: SIMD4<Float>
    var leftAngularVelocity: SIMD4<Float>
    var rightRoot: SIMD4<Float>
    var rightChord: SIMD4<Float>
    var rightSpan: SIMD4<Float>
    var rightNormal: SIMD4<Float>
    var rightAngularVelocity: SIMD4<Float>
}

extension GPUPreparedBirdGeometry {
    var publicValue: BirdGeometryFrame {
        BirdGeometryFrame(
            bodyPosition: bodyPosition,
            orientation: orientation,
            linearVelocity: linearVelocity,
            omegaBodyWorld: omegaBodyWorld,
            leftRoot: leftRoot,
            leftChord: leftChord,
            leftSpan: leftSpan,
            leftNormal: leftNormal,
            leftAngularVelocity: leftAngularVelocity,
            rightRoot: rightRoot,
            rightChord: rightChord,
            rightSpan: rightSpan,
            rightNormal: rightNormal,
            rightAngularVelocity: rightAngularVelocity
        )
    }

    init(_ value: BirdGeometryFrame) {
        bodyPosition = value.bodyPosition
        orientation = value.orientation
        linearVelocity = value.linearVelocity
        omegaBodyWorld = value.omegaBodyWorld
        leftRoot = value.leftRoot
        leftChord = value.leftChord
        leftSpan = value.leftSpan
        leftNormal = value.leftNormal
        leftAngularVelocity = value.leftAngularVelocity
        rightRoot = value.rightRoot
        rightChord = value.rightChord
        rightSpan = value.rightSpan
        rightNormal = value.rightNormal
        rightAngularVelocity = value.rightAngularVelocity
    }
}

/// Fixed Li--Nabawy benchmark inputs. Float4-only packing keeps the structure
/// identical in Swift and Metal and lets the per-cell geometry kernel consume
/// a single, cache-friendly constant record.
struct GPUFlappingWingParameters {
    var rootAndChord: SIMD4<Float>
    var geometry: SIMD4<Float>
    var kinematics0: SIMD4<Float>
    var kinematics1: SIMD4<Float>
}

/// Pose and rigid velocity data prepared once per time step for the prescribed
/// wing. Expensive trigonometry is therefore independent of the grid size.
struct GPUPreparedFlappingWing {
    var root: SIMD4<Float>
    var chord: SIMD4<Float>
    var span: SIMD4<Float>
    var normal: SIMD4<Float>
    var angularVelocity: SIMD4<Float>
    var state: SIMD4<Float>
}

/// Compact structured measured surface shared by the preparation and topology
/// kernels. Counts and float4-only records keep Swift/Metal packing explicit.
struct GPUMeasuredWingSurfaceParameters {
    var counts: SIMD4<UInt32>
    var pointCounts: SIMD4<UInt32>
    var rootAndHalfThickness: SIMD4<Float>
    var timingAndBounds: SIMD4<Float>
}

/// Fixed indexed complete-bird surface. counts.w is the host-selected first
/// interpolation frame; queryTimeAndThickness.x is the current nonperiodic time.
struct GPUIndexedBirdSurfaceParameters {
    var counts: SIMD4<UInt32>
    var queryTimeAndThickness: SIMD4<Float>
    var translationAndVelocityScale: SIMD4<Float>
}

struct GPUPreparedMeasuredWingPoint {
    var position: SIMD4<Float>
    var velocity: SIMD4<Float>
}

struct GPUForceTorque {
    var force: SIMD4<Float>
    var torque: SIMD4<Float>

    static let zero = GPUForceTorque(force: .zero, torque: .zero)

    var coreValue: ForceTorque {
        ForceTorque(
            forceNewtons: force.xyz,
            torqueNewtonMeters: torque.xyz
        )
    }
}

struct GPURunSample {
    var timeAndPosition: SIMD4<Float>
    var orientation: SIMD4<Float>
    var linearVelocity: SIMD4<Float>
    var angularVelocityBody: SIMD4<Float>
    var force: SIMD4<Float>
    var torque: SIMD4<Float>
    var leftHingeForce: SIMD4<Float>
    var leftHingeTorque: SIMD4<Float>
    var rightHingeForce: SIMD4<Float>
    var rightHingeTorque: SIMD4<Float>
    var step: SIMD4<UInt32>

    var publicValue: RunSample {
        let step64 = UInt64(step.x) | (UInt64(step.y) << 32)
        return RunSample(
            step: step64,
            timeSeconds: timeAndPosition.x,
            body: BirdBodyState(
                positionMeters: SIMD3<Float>(
                    timeAndPosition.y,
                    timeAndPosition.z,
                    timeAndPosition.w
                ),
                orientationBodyToWorld: Quaternion(simd4: orientation).normalized,
                linearVelocityMetersPerSecond: linearVelocity.xyz,
                angularVelocityBodyRadiansPerSecond: angularVelocityBody.xyz
            ),
            aerodynamicLoad: ForceTorque(
                forceNewtons: force.xyz,
                torqueNewtonMeters: torque.xyz
            ),
            wingHingeReactionLoads: WingHingeReactionLoads(
                left: ForceTorque(
                    forceNewtons: leftHingeForce.xyz,
                    torqueNewtonMeters: leftHingeTorque.xyz
                ),
                right: ForceTorque(
                    forceNewtons: rightHingeForce.xyz,
                    torqueNewtonMeters: rightHingeTorque.xyz
                )
            )
        )
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

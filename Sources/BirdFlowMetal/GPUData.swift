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

    init(
        configuration: SimulationConfiguration,
        time: Float,
        captureMacroscopicFields: Bool = true,
        accumulateLoads: Bool = true,
        hasPreviousGeometry: Bool = false,
        periodicBoundaries: Bool = false,
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
            0,
            0
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
            )
        )
    }
}

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

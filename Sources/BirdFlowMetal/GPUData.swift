import BirdFlowCore
import Foundation

struct GPUUniforms {
    var grid: SIMD4<UInt32>
    var originAndCellSize: SIMD4<Float>
    var timeStepAndScales: SIMD4<Float>
    var latticeAndSponge: SIMD4<Float>
    var farFieldLattice: SIMD4<Float>
    var gravity: SIMD4<Float>
    var flags: SIMD4<UInt32>

    init(
        configuration: SimulationConfiguration,
        time: Float,
        captureMacroscopicFields: Bool = true,
        hasPreviousGeometry: Bool = false
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
            0
        )
        flags = SIMD4<UInt32>(
            configuration.freeFlight ? 1 : 0,
            captureMacroscopicFields ? 1 : 0,
            hasPreviousGeometry ? 1 : 0,
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

private extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

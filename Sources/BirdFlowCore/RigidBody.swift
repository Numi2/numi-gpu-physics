import Foundation

@frozen
public struct WingMomentum: Sendable, Equatable {
    public var linearKilogramMetersPerSecond: SIMD3<Float>
    public var angularKilogramMetersSquaredPerSecond: SIMD3<Float>

    public init(
        linearKilogramMetersPerSecond: SIMD3<Float>,
        angularKilogramMetersSquaredPerSecond: SIMD3<Float>
    ) {
        self.linearKilogramMetersPerSecond =
            linearKilogramMetersPerSecond
        self.angularKilogramMetersSquaredPerSecond =
            angularKilogramMetersSquaredPerSecond
    }
}

/// Independent CPU reference for the prescribed rigid-wing momentum model
/// implemented in Metal. Axes and angular velocity are expressed in world
/// coordinates; inertia is diagonal in chord/span/normal axes.
public enum PrescribedWingMomentumModel {
    public static func momentum(
        properties: WingInertialProperties,
        hingeWorldMeters: SIMD3<Float>,
        chordWorld: SIMD3<Float>,
        spanWorld: SIMD3<Float>,
        normalWorld: SIMD3<Float>,
        relativeAngularVelocityWorldRadiansPerSecond: SIMD3<Float>,
        bodyOriginWorldMeters: SIMD3<Float>
    ) -> WingMomentum {
        let center = chordWorld
                * properties.centerOfMassFromHingeMeters.x
            + spanWorld * properties.centerOfMassFromHingeMeters.y
            + normalWorld * properties.centerOfMassFromHingeMeters.z
        let centerVelocity = cross(
            relativeAngularVelocityWorldRadiansPerSecond,
            center
        )
        let linear = properties.massKilograms * centerVelocity
        let inertia = properties.principalInertiaKilogramMetersSquared
        let spin = chordWorld
                * (inertia.x * dot(
                    relativeAngularVelocityWorldRadiansPerSecond,
                    chordWorld
                ))
            + spanWorld
                * (inertia.y * dot(
                    relativeAngularVelocityWorldRadiansPerSecond,
                    spanWorld
                ))
            + normalWorld
                * (inertia.z * dot(
                    relativeAngularVelocityWorldRadiansPerSecond,
                    normalWorld
                ))
        return WingMomentum(
            linearKilogramMetersPerSecond: linear,
            angularKilogramMetersSquaredPerSecond: cross(
                hingeWorldMeters + center - bodyOriginWorldMeters,
                linear
            ) + spin
        )
    }

    public static func inertialReaction(
        previous: WingMomentum,
        current: WingMomentum,
        timeStepSeconds: Float
    ) -> ForceTorque {
        precondition(timeStepSeconds > 0)
        return ForceTorque(
            forceNewtons: -(
                current.linearKilogramMetersPerSecond
                    - previous.linearKilogramMetersPerSecond
            ) / timeStepSeconds,
            torqueNewtonMeters: -(
                current.angularKilogramMetersSquaredPerSecond
                    - previous.angularKilogramMetersSquaredPerSecond
            ) / timeStepSeconds
        )
    }
}

public enum RigidBodyIntegrator {
    /// Semi-implicit Euler for translation and first-order quaternion
    /// integration for rotation. The Metal kernel implements the same update.
    public static func integrate(
        state: inout BirdBodyState,
        parameters: BirdParameters,
        forceWorldNewtons: SIMD3<Float>,
        torqueWorldNewtonMeters: SIMD3<Float>,
        gravityWorldMetersPerSecondSquared: SIMD3<Float>,
        timeStepSeconds dt: Float,
        substeps: Int = 1
    ) {
        precondition(dt > 0 && substeps > 0)

        let substepTime = dt / Float(substeps)
        for _ in 0..<substeps {
            let acceleration = forceWorldNewtons / parameters.massKilograms
                + gravityWorldMetersPerSecondSquared
            state.linearVelocityMetersPerSecond += acceleration * substepTime
            state.positionMeters += state.linearVelocityMetersPerSecond
                * substepTime

            let q = state.orientationBodyToWorld.normalized
            let torqueBody = q.unrotate(torqueWorldNewtonMeters)
            let omega = state.angularVelocityBodyRadiansPerSecond
            let inertia = parameters.principalInertiaKilogramMetersSquared
            let angularMomentum = inertia * omega
            let gyroscopic = cross(omega, angularMomentum)
            let angularAcceleration = (torqueBody - gyroscopic) / inertia
            let omegaNew = omega + angularAcceleration * substepTime

            let omegaQuaternion = Quaternion(vector: omegaNew, scalar: 0)
            let derivative = q * omegaQuaternion
            state.orientationBodyToWorld = Quaternion(
                vector: q.vector
                    + derivative.vector * (0.5 * substepTime),
                scalar: q.scalar
                    + derivative.scalar * (0.5 * substepTime)
            ).normalized
            state.angularVelocityBodyRadiansPerSecond = omegaNew
        }
    }
}

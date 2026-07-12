import Foundation

public enum RigidBodyIntegrator {
    /// Semi-implicit Euler for translation and first-order quaternion
    /// integration for rotation. The Metal kernel implements the same update.
    public static func integrate(
        state: inout BirdBodyState,
        parameters: BirdParameters,
        forceWorldNewtons: SIMD3<Float>,
        torqueWorldNewtonMeters: SIMD3<Float>,
        gravityWorldMetersPerSecondSquared: SIMD3<Float>,
        timeStepSeconds dt: Float
    ) {
        precondition(dt > 0)

        let acceleration = forceWorldNewtons / parameters.massKilograms
            + gravityWorldMetersPerSecondSquared
        state.linearVelocityMetersPerSecond += acceleration * dt
        state.positionMeters += state.linearVelocityMetersPerSecond * dt

        let q = state.orientationBodyToWorld.normalized
        let torqueBody = q.unrotate(torqueWorldNewtonMeters)
        let omega = state.angularVelocityBodyRadiansPerSecond
        let inertia = parameters.principalInertiaKilogramMetersSquared
        let angularMomentum = inertia * omega
        let gyroscopic = cross(omega, angularMomentum)
        let angularAcceleration = (torqueBody - gyroscopic) / inertia
        let omegaNew = omega + angularAcceleration * dt

        let omegaQuaternion = Quaternion(vector: omegaNew, scalar: 0)
        let derivative = q * omegaQuaternion
        state.orientationBodyToWorld = Quaternion(
            vector: q.vector + derivative.vector * (0.5 * dt),
            scalar: q.scalar + derivative.scalar * (0.5 * dt)
        ).normalized
        state.angularVelocityBodyRadiansPerSecond = omegaNew
    }
}

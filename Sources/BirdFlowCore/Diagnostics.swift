import Foundation

@frozen
public struct ForceTorque: Sendable, Equatable, Codable {
    public var forceNewtons: SIMD3<Float>
    public var torqueNewtonMeters: SIMD3<Float>

    public init(
        forceNewtons: SIMD3<Float> = .zero,
        torqueNewtonMeters: SIMD3<Float> = .zero
    ) {
        self.forceNewtons = forceNewtons
        self.torqueNewtonMeters = torqueNewtonMeters
    }
}

@frozen
public struct SimulationSnapshot: Sendable, Equatable, Codable {
    public var step: UInt64
    public var timeSeconds: Float
    public var body: BirdBodyState
    public var aerodynamicLoad: ForceTorque

    public init(
        step: UInt64,
        timeSeconds: Float,
        body: BirdBodyState,
        aerodynamicLoad: ForceTorque
    ) {
        self.step = step
        self.timeSeconds = timeSeconds
        self.body = body
        self.aerodynamicLoad = aerodynamicLoad
    }
}

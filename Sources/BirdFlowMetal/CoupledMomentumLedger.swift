import BirdFlowCore
import Foundation

/// One independently reduced linear-momentum balance for a coupled fluid/body
/// step. Impulses use SI kilogram-metres per second.
@frozen
public struct CoupledMomentumLedgerSample: Codable, Sendable {
    public var step: UInt64
    public var timeSeconds: Float
    public var fluidMomentumBefore: SIMD3<Double>
    public var fluidMomentumAfter: SIMD3<Double>
    public var directlyReducedFluidMomentumChange: SIMD3<Double>
    public var wholeBirdTranslationalMomentumBefore: SIMD3<Double>
    public var wholeBirdTranslationalMomentumAfter: SIMD3<Double>
    public var prescribedWingInternalMomentumBefore: SIMD3<Double>
    public var prescribedWingInternalMomentumAfter: SIMD3<Double>
    public var aerodynamicImpulse: SIMD3<Double>
    public var gravityImpulse: SIMD3<Double>
    public var farFieldImpulseToFluid: SIMD3<Double>
    public var spongeImpulseToFluid: SIMD3<Double>
    public var persistentLinkExchangeImpulseToFluid: SIMD3<Double>
    public var inferredTopologyConversionImpulseToFluid: SIMD3<Double>
    public var fluidBoundaryImpulse: SIMD3<Double>
    public var boundaryClosureResidual: SIMD3<Double>
    public var totalSystemMomentumChange: SIMD3<Double>
    public var recordedExternalImpulse: SIMD3<Double>
    public var externalSystemClosureResidual: SIMD3<Double>
    public var farFieldLinkCount: Int
    public var spongeCellCount: Int
    public var persistentBoundaryLinkCount: Int
    public var topologyTransitionCellCount: Int
}

/// Publication-facing summary of the opt-in coupled momentum diagnostic.
/// The gate is deliberately independent of force-estimator algebra: fluid
/// momentum is reduced directly from the population field on both sides of
/// every step.
@frozen
public struct CoupledMomentumLedgerReport: Codable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var deviceName: String
    public var steps: Int
    public var timeStepSeconds: Float
    public var momentumDefinition: String
    public var topologyDefinition: String
    public var samples: [CoupledMomentumLedgerSample]
    public var RMSAerodynamicImpulse: Double
    public var RMSExternalImpulse: Double
    public var RMSBoundaryClosureResidual: Double
    public var RMSExternalSystemClosureResidual: Double
    public var maximumBoundaryClosureResidual: Double
    public var maximumExternalSystemClosureResidual: Double
    public var relativeRMSBoundaryClosureResidual: Double
    public var relativeRMSExternalSystemClosureResidual: Double
    public var maximumAllowedRelativeRMSBoundaryClosureResidual: Double
    public var maximumAllowedRelativeRMSExternalSystemClosureResidual: Double
    public var finite: Bool
    public var passed: Bool
    public var scientificVerdict: String
}

@frozen
public struct CoupledMomentumAdvanceResult: Sendable {
    public var advanceResult: AdvanceResult
    public var ledger: CoupledMomentumLedgerReport

    public init(
        advanceResult: AdvanceResult,
        ledger: CoupledMomentumLedgerReport
    ) {
        self.advanceResult = advanceResult
        self.ledger = ledger
    }
}

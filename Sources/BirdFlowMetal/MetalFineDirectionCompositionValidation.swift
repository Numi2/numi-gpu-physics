import Foundation

public struct MetalFineDirectionComponent: Codable, Sendable {
    public let partIdentifier: Int
    public let componentName: String
}

public struct MetalFineDirectionProductionLinkReference: Codable, Sendable {
    public let referenceLengthCells: Int
    public let activeLinkCount: Int
}

public struct MetalFineDirectionCompositionPreregistration: Codable, Sendable {
    public let schemaVersion: Int
    public let preregistrationIdentifier: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceCurvedPreregistrationSHA256: String
    public let sourceCurvedReportSHA256: String
    public let sourceCurvedAuditSHA256: String
    public let sourceD28ProvenanceSHA256: String
    public let sourceD32ProvenanceSHA256: String
    public let sourceProvenanceAuditSHA256: String
    public let sourceRefinementSHA256: String
    public let sourceRefinementAuditSHA256: String
    public let referenceLengthCells: [Int]
    public let expectedGridCells: [String: [Int]]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let halfThicknessMeters: Double
    public let components: [MetalFineDirectionComponent]
    public let directionIndices: [Int]
    public let oppositeDirectionPairs: [[Int]]
    public let fixedPopulationProfiles: [
        MetalDirectionCompositionPopulationProfile
    ]
    public let productionActiveLinkReference: [
        MetalFineDirectionProductionLinkReference
    ]
    public let maximumMetalCPUMaskMismatchCellCount: Int
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let maximumCensusToProductionActiveLinkRelativeDifference: Double
    public let maximumWholeSurfaceOppositeDirectionCountMismatch: Int
    public let maximumEquilibriumWholeSurfaceNetLedgerFraction: Double
    public let maximumWholeSurfaceDirectionHistogramTotalVariation: Double
    public let maximumComponentDirectionHistogramTotalVariation: Double
    public let maximumWholeSurfaceProfileResponseLedgerDifference: Double
    public let maximumComponentProfileResponseLedgerDifference: Double
    public let responseDefinition: String
    public let normalizationDefinition: String
    public let selectionRule: String
    public let classificationRule: String
    public let fluidEvolutionAuthorized: Bool
    public let populationAllocationAuthorized: Bool
    public let newPhysicsKernelAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let d36RunAuthorized: Bool
    public let gridConvergenceGateApplied: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
    public let passed: Bool
}

public struct MetalFineDirectionCountBin: Codable, Sendable, Equatable {
    public let partIdentifier: Int
    public let directionIndex: Int
    public let linkCount: Int
}

public struct MetalFineDirectionCensusCase: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let referenceLengthCells: Int
    public let gridCells: [Int]
    public let cellSizeMeters: Double
    public let halfThicknessMeters: Double
    public let frozenSourceTimeSeconds: Double
    public let runtimeSeconds: Double
    public let metalBins: [MetalFineDirectionCountBin]
    public let cpuBins: [MetalFineDirectionCountBin]
    public let totalMetalLinkCount: Int
    public let totalCPULinkCount: Int
    public let productionActiveLinkReference: Int
    public let censusToProductionActiveLinkRelativeDifference: Double
    public let metalCPUMaskMismatchCellCount: Int
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let metalCPUExactDirectionCountMatch: Bool
    public let allValuesFinite: Bool
    public let parityGatePassed: Bool
    public let productionLinkSetConsistencyGatePassed: Bool
}

public struct MetalFineDirectionCensusReport: Codable, Sendable {
    public let schemaVersion: Int
    public let censusIdentifier: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourcePreregistrationSHA256: String
    public let deviceName: String
    public let runtimeSeconds: Double
    public let fluidEvolutionExecuted: Bool
    public let populationAllocationPerformed: Bool
    public let newPhysicsKernelExecuted: Bool
    public let cases: [MetalFineDirectionCensusCase]
    public let maximumMetalCPUMaskMismatchCellCount: Int
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let maximumCensusToProductionActiveLinkRelativeDifference: Double
    public let censusPassed: Bool
    public let productionModificationAuthorized: Bool
    public let d36RunAuthorized: Bool
    public let gridConvergenceGateApplied: Bool
    public let experimentalAgreementGateApplied: Bool
    public let classification: String
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalFineDirectionPhaseProductionLinkReference: Codable, Sendable {
    public let sourceSampleIndex: Int
    public let sourceTimeSeconds: Double
    public let referenceLengthCells: Int
    public let activeLinkCount: Int
}

public struct MetalFineDirectionPhaseWindowPreregistration: Codable, Sendable {
    public let schemaVersion: Int
    public let preregistrationIdentifier: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceSinglePhasePreregistrationSHA256: String
    public let sourceSinglePhaseCensusSHA256: String
    public let sourceSinglePhaseDiscriminatorSHA256: String
    public let sourceSinglePhaseAuditSHA256: String
    public let sourceD28ProvenanceSHA256: String
    public let sourceD32ProvenanceSHA256: String
    public let referenceLengthCells: [Int]
    public let expectedGridCells: [String: [Int]]
    public let sourceSampleIndices: [Int]
    public let sourceTimesSeconds: [Double]
    public let halfThicknessMeters: Double
    public let components: [MetalFineDirectionComponent]
    public let directionIndices: [Int]
    public let oppositeDirectionPairs: [[Int]]
    public let fixedPopulationProfiles: [
        MetalDirectionCompositionPopulationProfile
    ]
    public let productionActiveLinkReferences: [
        MetalFineDirectionPhaseProductionLinkReference
    ]
    public let maximumMetalCPUMaskMismatchCellCount: Int
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let maximumCensusToProductionActiveLinkRelativeDifference: Double
    public let maximumWholeSurfaceOppositeDirectionCountMismatch: Int
    public let maximumEquilibriumWholeSurfaceNetLedgerFraction: Double
    public let maximumWholeSurfaceDirectionHistogramTotalVariation: Double
    public let maximumComponentDirectionHistogramTotalVariation: Double
    public let maximumWholeSurfaceProfileResponseLedgerDifference: Double
    public let maximumComponentProfileResponseLedgerDifference: Double
    public let responseDefinition: String
    public let normalizationDefinition: String
    public let selectionRule: String
    public let classificationRule: String
    public let fluidEvolutionAuthorized: Bool
    public let populationAllocationAuthorized: Bool
    public let newPhysicsKernelAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let d36RunAuthorized: Bool
    public let gridConvergenceGateApplied: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
    public let passed: Bool
}

public struct MetalFineDirectionPhaseCensusCase: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let sourceSampleIndex: Int
    public let sourceTimeSeconds: Double
    public let referenceLengthCells: Int
    public let gridCells: [Int]
    public let cellSizeMeters: Double
    public let halfThicknessMeters: Double
    public let runtimeSeconds: Double
    public let metalBins: [MetalFineDirectionCountBin]
    public let cpuBins: [MetalFineDirectionCountBin]
    public let totalMetalLinkCount: Int
    public let totalCPULinkCount: Int
    public let productionActiveLinkReference: Int
    public let censusToProductionActiveLinkRelativeDifference: Double
    public let metalCPUMaskMismatchCellCount: Int
    public let maskMismatches: [MetalFineDirectionMaskMismatch]
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let metalCPUExactDirectionCountMatch: Bool
    public let allValuesFinite: Bool
    public let parityGatePassed: Bool
    public let productionLinkSetConsistencyGatePassed: Bool
}

public struct MetalFineDirectionMaskMismatch: Codable, Sendable {
    public let cellCoordinate: [Int]
    public let metalPartIdentifier: Int
    public let cpuPartIdentifier: Int
    public let metalSignedDistanceCells: Double
    public let cpuSignedDistanceCells: Double
}

public struct MetalFineDirectionPhaseCensusReport: Codable, Sendable {
    public let schemaVersion: Int
    public let censusIdentifier: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourcePreregistrationSHA256: String
    public let deviceName: String
    public let runtimeSeconds: Double
    public let fluidEvolutionExecuted: Bool
    public let populationAllocationPerformed: Bool
    public let newPhysicsKernelExecuted: Bool
    public let cases: [MetalFineDirectionPhaseCensusCase]
    public let maximumMetalCPUMaskMismatchCellCount: Int
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let maximumCensusToProductionActiveLinkRelativeDifference: Double
    public let censusPassed: Bool
    public let productionModificationAuthorized: Bool
    public let d36RunAuthorized: Bool
    public let gridConvergenceGateApplied: Bool
    public let experimentalAgreementGateApplied: Bool
    public let classification: String
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

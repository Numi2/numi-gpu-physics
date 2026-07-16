import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal
#endif

public struct MetalIndexedBirdSurfaceFrameAudit: Codable, Sendable {
    public let frameIndex: Int
    public let sourceFrameNumber: Int
    public let timeSeconds: Double
    public let solidCellCount: Int
    public let componentSolidCellCounts: [Int]
    public let occupancySHA256: String
    public let maximumLatticeWallSpeed: Double
    public let maximumPreparedPositionErrorMeters: Double
    public let maximumPreparedVelocityErrorMetersPerSecond: Double
    public let cpuRasterCompared: Bool
    public let cpuMaskMismatchCellCount: Int?
    public let maximumCPUWallVelocityDifferenceLattice: Double?
    public let maximumCPUSignedDistanceDifferenceCells: Double?
}

public struct MetalIndexedBirdSurfaceReplayReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let scientificTier: String
    public let manifestSHA256: String
    public let sourceSurfaceSHA256: String
    public let sourceMuscleModelSHA256: String
    public let frameCount: Int
    public let vertexCount: Int
    public let triangleCount: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cellSizeMeters: Double
    public let halfThicknessCells: Double
    public let runtimeSeconds: Double
    public let geometryKernelSequence: [String]
    public let cpuRasterMilestoneFrames: [Int]
    public let fractionalInterpolationProbeTimesSeconds: [Double]
    public let maximumPreparedPositionErrorMeters: Double
    public let maximumPreparedVelocityErrorMetersPerSecond: Double
    public let maximumCPUWallVelocityDifferenceLattice: Double
    public let maximumCPUSignedDistanceDifferenceCells: Double
    public let maximumCPUMaskMismatchCellCount: Int
    public let allComponentsPresentEveryFrame: Bool
    public let allValuesFinite: Bool
    public let fluidCollisionExecuted: Bool
    public let forceAccumulationExecuted: Bool
    public let frameAudits: [MetalIndexedBirdSurfaceFrameAudit]
    public let passed: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceCouplingSample: Codable, Sendable {
    public let step: Int
    public let sourceTimeSeconds: Double
    public let newlyCoveredCellCount: Int
    public let newlyUncoveredCellCount: Int
    public let sourceLedgerTransitionCellCount: Int
    public let persistentBoundaryLinkCount: Int
    public let fluidMomentumBefore: SIMD3<Double>
    public let fluidMomentumAfter: SIMD3<Double>
    public let aerodynamicImpulse: SIMD3<Double>
    public let farFieldImpulseToFluid: SIMD3<Double>
    public let spongeImpulseToFluid: SIMD3<Double>
    public let diagnosticPersistentLinkImpulseToFluid: SIMD3<Double>
    public let remainingImpulseAfterDiagnosticLinks: SIMD3<Double>
    public let fluidBoundaryImpulse: SIMD3<Double>
    public let boundaryClosureResidual: SIMD3<Double>
}

public struct MetalIndexedBirdSurfaceCouplingReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cellSizeMeters: Double
    public let timeStepSeconds: Double
    public let steps: Int
    public let runtimeSeconds: Double
    public let maximumWallSpeedLattice: Double
    public let maximumWallMach: Double
    public let acceptanceDefinition: String
    public let geometryKernels: [String]
    public let linkKernel: String
    public let fluidKernel: String
    public let forceEstimator: String
    public let periodicBoundaries: Bool
    public let spongeStrength: Double
    public let componentSolidCellCounts: [Int]
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let persistentBoundaryLinkEvents: Int
    public let maximumTopologyCounterMismatchCells: Int
    public let relativeRMSBoundaryClosureResidual: Double
    public let maximumRelativeBoundaryClosureResidual: Double
    public let maximumAllowedRelativeRMSBoundaryClosureResidual: Double
    public let maximumBoundaryClosureResidualKilogramMetersPerSecond: Double
    public let allValuesFinite: Bool
    public let samples: [MetalIndexedBirdSurfaceCouplingSample]
    public let passed: Bool
    public let claimBoundary: String
}

public enum MetalIndexedBirdSurfaceCollisionOperator: String, Codable, Sendable {
    case productionTRT = "production-trt"
    case positivityPreservingRegularizedBGK =
        "positivity-preserving-regularized-bgk"
    case positivityPreservingRecursiveRegularizedBGK =
        "positivity-preserving-recursive-regularized-bgk"

    var caseParameterW: Float {
        switch self {
        case .productionTRT: return -1
        case .positivityPreservingRegularizedBGK: return -3
        case .positivityPreservingRecursiveRegularizedBGK: return -4
        }
    }
}

public enum MetalIndexedBirdSurfaceMovingWallNormalization:
    String, Codable, Sendable
{
    case referenceDensity = "reference-density"
    case preStepLocalDensity = "pre-step-local-density"

    var usesPreStepLocalDensity: Bool {
        self == .preStepLocalDensity
    }
}

public struct MetalIndexedBirdSurfacePilotPlan: Codable, Sendable {
    public let cellSizeMeters: Double
    public let halfThicknessCells: Double
    public let paddingCells: Int
    public let spongeWidthCells: Int
    public let spongeStrength: Double
    public let forceSamplesPerSecond: Double
    public let fluidStepsPerForceSample: Int
    public let fluidTimeStepSeconds: Double
    public let totalFluidSteps: Int
    public let preRollFluidSteps: Int
    public let comparisonForceSamples: Int
    public let maximumSurfaceSpeedMetersPerSecond: Double
    public let latticeReferenceSpeed: Double
    public let maximumWallMach: Double
    public let pilotTauPlus: Double
    public let pilotReynoldsNumber: Double
    public let sourceAirDensityKilogramsPerCubicMeter: Double
    public let sourceDynamicViscosityPascalSeconds: Double
    public let sourceConditionTauPlusAtPilotGrid: Double
    public let minimumAllowedTauPlus: Double
    public let sourceViscosityRepresentableAtPilotGrid: Bool
    public let maximumCellSizeForSourceViscosityMeters: Double
    public let pilotDynamicViscosityPascalSeconds: Double
    public let pilotToSourceViscosityRatio: Double
    public let experimentalAgreementGateApplied: Bool
}

public struct MetalIndexedBirdSurfacePilotSample: Codable, Sendable {
    public let targetSampleIndex: Int
    public let sourceTimeSeconds: Double
    public let sourceFrameCoordinate: Double
    public let measuredForceXNewtons: Double
    public let measuredForceZNewtons: Double
    public let endpointComputedForceNewtons: SIMD3<Double>
    public let intervalMeanComputedForceNewtons: SIMD3<Double>
    public let endpointResidualXNewtons: Double
    public let endpointResidualZNewtons: Double
    public let intervalMeanResidualXNewtons: Double
    public let intervalMeanResidualZNewtons: Double
    public let minimumPopulation: Double
    public let componentSolidCellCounts: [Int]
}

public struct MetalIndexedBirdSurfacePilotReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let plan: MetalIndexedBirdSurfacePilotPlan
    public let runtimeSeconds: Double
    public let completedFluidSteps: Int
    public let recordedComparisonSamples: Int
    public let recordedPopulationDiagnosticSamples: Int
    public let populationDiagnosticStride: Int
    public let collisionOperator: String
    public let collisionLimiterActivationCount: Double
    public let collisionLimiterActivationFractionOfCellSteps: Double
    public let maximumCollisionRestriction: Double
    public let forceEstimator: String
    public let periodicBoundaries: Bool
    public let allComponentsPresentAtComparisonSamples: Bool
    public let allLoadsFinite: Bool
    public let allSampledPopulationsFinite: Bool
    public let sampledPopulationPositivityPassed: Bool
    public let minimumSampledPopulation: Double
    public let firstNonFiniteLoadStep: Int?
    public let firstNonFinitePopulationStep: Int?
    public let firstNegativePopulationStep: Int?
    public let firstNegativePopulationTimeSeconds: Double?
    public let firstNegativePopulationLinearIndex: Int?
    public let firstNegativePopulationDirection: Int?
    public let firstNegativePopulationCellCoordinate: SIMD3<Int>?
    public let firstNegativePopulationDistanceFromSurfaceCells: Double?
    public let firstNegativePopulationPartIdentifier: Int?
    public let measuredMeanForceXNewtons: Double?
    public let measuredMeanForceZNewtons: Double?
    public let endpointMeanForceXNewtons: Double?
    public let endpointMeanForceZNewtons: Double?
    public let intervalMeanForceXNewtons: Double?
    public let intervalMeanForceZNewtons: Double?
    public let endpointNormalizedRMSError: Double?
    public let intervalMeanNormalizedRMSError: Double?
    public let measuredImpulseXNewtonSeconds: Double?
    public let measuredImpulseZNewtonSeconds: Double?
    public let endpointImpulseXNewtonSeconds: Double?
    public let endpointImpulseZNewtonSeconds: Double?
    public let intervalMeanImpulseXNewtonSeconds: Double?
    public let intervalMeanImpulseZNewtonSeconds: Double?
    public let measuredPeakTimeSeconds: Double?
    public let endpointPeakTimeSeconds: Double?
    public let intervalMeanPeakTimeSeconds: Double?
    public let experimentalAgreementGateApplied: Bool
    public let integrationGatePassed: Bool
    public let samples: [MetalIndexedBirdSurfacePilotSample]
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceCollisionPreRollCase: Codable, Sendable {
    public let collisionOperator: String
    public let requestedPreRollSteps: Int
    public let completedPreRollSteps: Int
    public let perStepPopulationDiagnostics: Bool
    public let positivityAndFiniteLoadGatePassed: Bool
    public let correctionIntrusionGatePassed: Bool
    public let eligibleForExtendedPilot: Bool
    public let report: MetalIndexedBirdSurfacePilotReport
}

public struct MetalIndexedBirdSurfaceCollisionPreRollABReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let requestedPreRollSteps: Int
    public let populationDiagnosticStride: Int
    public let maximumCorrectionActivationFraction: Double
    public let fixedInputs: String
    public let cases: [MetalIndexedBirdSurfaceCollisionPreRollCase]
    public let controlFailureReproduced: Bool
    public let eligibleCollisionOperators: [String]
    public let screeningGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceControlVolumeBounds:
    Codable, Sendable {
    public let minimumX: Int
    public let minimumY: Int
    public let minimumZ: Int
    public let maximumExclusiveX: Int
    public let maximumExclusiveY: Int
    public let maximumExclusiveZ: Int
}

public struct MetalIndexedBirdSurfaceMomentumClosureSample:
    Codable, Sendable {
    public let step: Int
    public let sourceTimeSeconds: Double
    public let aerodynamicForceNewtons: SIMD3<Double>
    public let negativeFluidMomentumStorageRateNewtons: SIMD3<Double>
    public let negativeControlSurfaceMomentumFluxNewtons: SIMD3<Double>
    public let topologyReservoirCorrectionNewtons: SIMD3<Double>
    public let rawControlVolumeBudgetForceNewtons: SIMD3<Double>
    public let rawControlVolumeClosureResidualNewtons: SIMD3<Double>
    public let globalFluidMomentumChangeRateNewtons: SIMD3<Double>
    public let globalFarFieldMomentumSourceRateNewtons: SIMD3<Double>
    public let globalSpongeMomentumSourceRateNewtons: SIMD3<Double>
    public let globalFluidBudgetForceNewtons: SIMD3<Double>
    public let globalFluidClosureResidualNewtons: SIMD3<Double>
    public let solidControlSurfaceCrossingLinkCount: Int
    public let minimumPopulation: Double
}

public struct MetalIndexedBirdSurfaceMomentumClosureCase:
    Codable, Sendable {
    public let collisionOperator: String
    public let requestedSteps: Int
    public let completedSteps: Int
    public let runtimeSeconds: Double
    public let collisionLimiterActivationCount: Double
    public let collisionLimiterActivationFractionOfCellSteps: Double
    public let maximumCollisionRestriction: Double
    public let minimumPopulation: Double
    public let allValuesFinite: Bool
    public let sampledPopulationPositivityPassed: Bool
    public let maximumSolidControlSurfaceCrossingLinkCount: Int
    public let RMSAerodynamicForceNewtons: Double
    public let RMSRawControlVolumeBudgetForceNewtons: Double
    public let RMSRawControlVolumeClosureResidualNewtons: Double
    public let relativeRMSRawControlVolumeClosureResidual: Double
    public let maximumRawControlVolumeClosureResidualNewtons: Double
    public let RMSGlobalFluidBudgetForceNewtons: Double
    public let RMSGlobalFluidClosureResidualNewtons: Double
    public let relativeRMSGlobalFluidClosureResidual: Double
    public let maximumGlobalFluidClosureResidualNewtons: Double
    public let momentumClosurePassed: Bool
    public let eligibleForExtendedPilot: Bool
    public let samples: [MetalIndexedBirdSurfaceMomentumClosureSample]
}

public struct MetalIndexedBirdSurfaceMomentumClosureReport:
    Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let requestedSteps: Int
    public let controlVolume: MetalIndexedBirdSurfaceControlVolumeBounds
    public let spongeWidthCells: Int
    public let minimumControlSurfaceDistanceFromDomainBoundaryCells: Int
    public let minimumControlSurfaceDistanceFromSweptSurfaceCells: Double
    public let maximumAllowedRelativeRMSClosureResidual: Double
    public let maximumCorrectionActivationFraction: Double
    public let fixedInputs: String
    public let cases: [MetalIndexedBirdSurfaceMomentumClosureCase]
    public let eligibleCollisionOperators: [String]
    public let allCandidateRunsCompleted: Bool
    public let screeningGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceExtendedPilotCase: Codable, Sendable {
    public let collisionOperator: String
    public let completionAndPositivityGatePassed: Bool
    public let correctionIntrusionGatePassed: Bool
    public let eligibleForRefinementDiscrimination: Bool
    public let report: MetalIndexedBirdSurfacePilotReport
}

public struct MetalIndexedBirdSurfaceExtendedPilotReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let requestedFluidSteps: Int
    public let requestedComparisonSamples: Int
    public let populationDiagnosticStride: Int
    public let maximumCorrectionActivationFraction: Double
    public let fixedInputs: String
    public let cases: [MetalIndexedBirdSurfaceExtendedPilotCase]
    public let eligibleCollisionOperators: [String]
    public let allCandidateRunsCompleted: Bool
    public let endpointPairwiseNormalizedRMSDifference: Double?
    public let intervalMeanPairwiseNormalizedRMSDifference: Double?
    public let screeningGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceRefinementGridContract:
    Codable, Sendable, Equatable
{
    public let referenceLengthCells: Int
    public let cellSizeMeters: Double
    public let halfThicknessCells: Double
    public let paddingCells: Int
    public let spongeWidthCells: Int
    public let fluidStepsPerForceSample: Int
    public let preRollFluidSteps: Int
    public let totalFluidSteps: Int
    public let tauPlus: Double
    public let maximumWallMach: Double
    public let pilotToSourceViscosityRatio: Double
}

public struct MetalIndexedBirdSurfaceCrossCanonicalEvidence:
    Codable, Sendable, Equatable
{
    public let collisionOperator: String
    public let artifactPath: String
    public let relativeCorrectionL2: Double
    public let maximumAllowedRelativeCorrectionL2: Double
    public let crossCanonicalGatePassed: Bool
}

public struct MetalIndexedBirdSurfaceCollisionGridPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let candidateOperators: [String]
    public let discriminatorReferenceLengthCells: [Int]
    public let completionReferenceLengthCells: Int
    public let gridContracts: [MetalIndexedBirdSurfaceRefinementGridContract]
    public let maximumCorrectionActivationFraction: Double
    public let maximumCrossCanonicalTrendPenalty: Double
    public let crossCanonicalEvidence:
        [MetalIndexedBirdSurfaceCrossCanonicalEvidence]
    public let selectionRule: String
    public let fixedInputs: String
    public let experimentalAgreementGateApplied: Bool
    public let passed: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceCollisionGridCase:
    Codable, Sendable
{
    public let collisionOperator: String
    public let referenceLengthCells: Int
    public let completionAndPositivityGatePassed: Bool
    public let correctionIntrusionGatePassed: Bool
    public let eligibleForSelection: Bool
    public let report: MetalIndexedBirdSurfacePilotReport
}

public struct MetalIndexedBirdSurfaceCollisionGridAssessment:
    Codable, Sendable
{
    public let collisionOperator: String
    public let d8ToD12IntervalForceNormalizedRMSDifference: Double
    public let d8ToD12MeanForceRelativeDifference: Double
    public let d8ToD12ImpulseRelativeDifference: Double
    public let d8ToD12PeakTimeDifferenceSeconds: Double
    public let gridTrendScore: Double
    public let crossCanonicalGatePassed: Bool
    public let crossCanonicalTrendPenalty: Double
    public let eligibleAtBothGrids: Bool
    public let selectionEligible: Bool
}

public struct MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let preregistration:
        MetalIndexedBirdSurfaceCollisionGridPreregistration
    public let cases: [MetalIndexedBirdSurfaceCollisionGridCase]
    public let assessments: [MetalIndexedBirdSurfaceCollisionGridAssessment]
    public let d8OperatorPairwiseNormalizedRMSDifference: Double?
    public let d12OperatorPairwiseNormalizedRMSDifference: Double?
    public let selectedCollisionOperator: String?
    public let d16CompletionAuthorized: Bool
    public let allDiscriminatorRunsCompleted: Bool
    public let screeningGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceCollisionGridCompletionReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let selectedCollisionOperator: String
    public let discriminatorReferenceLengthCells: [Int]
    public let completionReferenceLengthCells: Int
    public let d16Case: MetalIndexedBirdSurfaceCollisionGridCase
    public let d12ToD16IntervalForceNormalizedRMSDifference: Double?
    public let d12ToD16MeanForceRelativeDifference: Double?
    public let d12ToD16ImpulseRelativeDifference: Double?
    public let d12ToD16PeakTimeDifferenceSeconds: Double?
    public let maximumAllowedFineGridRelativeDifference: Double
    public let fineGridForceConvergencePassed: Bool
    public let completionGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfacePopulationStageSample:
    Codable, Sendable
{
    public let step: Int
    public let sourceTimeSeconds: Double
    public let cellCoordinate: SIMD3<Int>
    public let cellLinearIndex: Int
    public let direction: Int
    public let topologyBranch: String
    public let wasSolid: Bool
    public let isSolid: Bool
    public let selectedSourcePartIdentifier: Int
    public let preStepPopulation: Double
    public let reconstructedDirectionPopulation: Double
    public let reconstructedPopulations: [Double]
    public let minimumReconstructedPopulation: Double
    public let farFieldDirections: [Int]
    public let movingBoundaryDirections: [Int]
    public let localFluidDirections: [Int]
    public let nonFiniteReconstructionDirections: [Int]
    public let reconstructedDensity: Double
    public let reconstructedVelocityLattice: SIMD3<Double>
    public let reconstructedSpeedLattice: Double
    public let reconstructedLatticeMach: Double
    public let restEquilibriumPositivitySpeedLimit: Double
    public let equilibriumDirectionPopulation: Double
    public let regularizedNonequilibriumDirectionPopulation: Double
    public let unboundedPostCollisionDirectionPopulation: Double
    public let positivityScale: Double
    public let populationFloor: Double
    public let postCollisionDirectionPopulation: Double
    public let spongeFactor: Double
    public let predictedPostSpongeDirectionPopulation: Double
    public let actualOutputDirectionPopulation: Double
    public let predictionAbsoluteError: Double
}

public struct MetalIndexedBirdSurfacePopulationStageProvenanceReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let selectedCollisionOperator: String
    public let referenceLengthCells: Int
    public let targetCellCoordinate: SIMD3<Int>
    public let targetCellLinearIndex: Int
    public let targetDirection: Int
    public let capturedSteps: [Int]
    public let diagnosticKernelSequence: [String]
    public let productionStateModifiedByDiagnostic: Bool
    public let maximumAllowedPredictionAbsoluteError: Double
    public let maximumPredictionAbsoluteError: Double
    public let replayFirstNegativePopulationStep: Int?
    public let replayFirstNegativePopulationDirection: Int?
    public let replayFirstNegativePopulationCellCoordinate: SIMD3<Int>?
    public let firstNegativeCapturedStage: String?
    public let firstNegativeCapturedStep: Int?
    public let selectedDirectionRemainedPositiveThroughReconstructionAtFailure:
        Bool
    public let negativeReconstructedDirectionsAtFailure: [Int]
    public let negativeMovingBoundaryReconstructedDirectionsAtFailure: [Int]
    public let upstreamMovingBoundaryReconstructionPresentAtFailure: Bool
    public let targetDirectionMovingBoundaryReconstructedAtFailure: Bool
    public let topologyRefillAtFailure: Bool
    public let farFieldUsedAtFailure: Bool
    public let spongeUsedAtFailure: Bool
    public let equilibriumReferencePositiveAtFailure: Bool
    public let provenanceGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let samples: [MetalIndexedBirdSurfacePopulationStageSample]
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceBoundaryTermSample:
    Codable, Sendable
{
    public let step: Int
    public let sourceTimeSeconds: Double
    public let targetCellCoordinate: SIMD3<Int>
    public let direction: Int
    public let sourceCellCoordinate: SIMD3<Int>?
    public let sourcePartIdentifier: Int
    public let branch: String
    public let linkFraction: Double
    public let reflectedPopulation: Double
    public let auxiliaryPopulation: Double
    public let auxiliaryCellCoordinate: SIMD3<Int>?
    public let auxiliaryRole: String
    public let rawWallCorrection: Double
    public let halfwayWallCorrection: Double
    public let productionWallDirectionProjectionLattice: Double
    public let sourceWallDirectionProjectionLattice: Double
    public let reflectedContribution: Double
    public let auxiliaryContribution: Double
    public let wallCorrectionContribution: Double
    public let productionReconstructedPopulation: Double
    public let contributionClosureResidual: Double
    public let halfwayMovingWallPopulation: Double
    public let interpolatedZeroWallPopulation: Double
    public let halfwayZeroWallPopulation: Double
    public let interpolatedNoAuxiliaryPopulation: Double
    public let productionPopulationNegative: Bool
    public let dominantNegativeContribution: String
}

public struct MetalIndexedBirdSurfaceBoundaryTermDecompositionReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let selectedCollisionOperator: String
    public let referenceLengthCells: Int
    public let targetCellCoordinate: SIMD3<Int>
    public let capturedSteps: [Int]
    public let diagnosticKernel: String
    public let productionStateModifiedByDiagnostic: Bool
    public let maximumAllowedAbsoluteResidual: Double
    public let maximumContributionClosureResidual: Double
    public let maximumReconstructionDifferenceFromStageArtifact: Double
    public let negativeMovingBoundaryDirectionsPreviousStep: [Int]
    public let negativeMovingBoundaryDirectionsAtFailure: [Int]
    public let directionsWithNegativeReflectedPopulation: [Int]
    public let directionsWithNegativeAuxiliaryContribution: [Int]
    public let directionsWithNegativeWallContribution: [Int]
    public let directionsMadeNonnegativeByHalfwayMovingWall: [Int]
    public let directionsMadeNonnegativeByInterpolatedZeroWall: [Int]
    public let directionsMadeNonnegativeByHalfwayZeroWall: [Int]
    public let directionsMadeNonnegativeByRemovingAuxiliary: [Int]
    public let directionsRemainingNegativeUnderHalfwayZeroWall: [Int]
    public let dominantRepairTarget: String
    public let boundaryTermGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let samples: [MetalIndexedBirdSurfaceBoundaryTermSample]
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallCandidateSummary:
    Codable, Sendable
{
    public let identifier: String
    public let correctionScaleRelativeToReferenceDensity: Double
    public let positivityInterventionActive: Bool
    public let reconstructedDensity: Double
    public let reconstructedMomentum: SIMD3<Double>
    public let reconstructedVelocity: SIMD3<Double>
    public let reconstructedSpeed: Double
    public let reconstructedLatticeMach: Double
    public let minimumPopulation: Double
    public let minimumEquilibriumPopulation: Double
    public let negativePopulationDirections: [Int]
    public let populationFloorViolationDirections: [Int]
    public let wallMassContribution: Double
    public let wallMomentumContribution: SIMD3<Double>
    public let populationGatePassed: Bool
    public let equilibriumGatePassed: Bool
}

public struct MetalIndexedBirdSurfaceMovingWallDirectionABSample:
    Codable, Sendable
{
    public let direction: Int
    public let basePopulationWithoutWallCorrection: Double
    public let referenceDensityPopulation: Double
    public let preStepLocalDensityPopulation: Double
    public let selfConsistentLocalDensityPopulation: Double
    public let positivityAdmissiblePopulation: Double
    public let referenceDensityWallContribution: Double
}

public struct MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let selectedCollisionOperator: String
    public let referenceLengthCells: Int
    public let targetCellCoordinate: SIMD3<Int>
    public let failureStep: Int
    public let sourceBoundaryTermGatePassed: Bool
    public let sourcePopulationProvenanceGatePassed: Bool
    public let productionStateModifiedByDiagnostic: Bool
    public let fluidSimulationRerun: Bool
    public let referenceDensity: Double
    public let populationFloor: Double
    public let preStepPopulationCoverageDirections: [Int]
    public let preStepLocalDensity: Double
    public let baseDensityWithoutWallCorrection: Double
    public let selfConsistentLocalDensity: Double
    public let selfConsistentDensityDenominator: Double
    public let globalPositivityAdmissibilityScale: Double
    public let restEquilibriumPositivitySpeedLimit: Double
    public let referenceDensityBaseline:
        MetalIndexedBirdSurfaceMovingWallCandidateSummary
    public let candidateA:
        MetalIndexedBirdSurfaceMovingWallCandidateSummary
    public let candidateB:
        MetalIndexedBirdSurfaceMovingWallCandidateSummary
    public let selfConsistentDensityCrosscheck:
        MetalIndexedBirdSurfaceMovingWallCandidateSummary
    public let directionSamples:
        [MetalIndexedBirdSurfaceMovingWallDirectionABSample]
    public let candidateAuthorizedForProductionLedger: String?
    public let admissibilityABGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallLedgerReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceAdmissibilityCandidateIdentifier: String
    public let sourceAdmissibilityGatePassed: Bool
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let requestedSteps: Int
    public let plan: MetalIndexedBirdSurfacePilotPlan
    public let controlVolume: MetalIndexedBirdSurfaceControlVolumeBounds
    public let spongeWidthCells: Int
    public let minimumControlSurfaceDistanceFromDomainBoundaryCells: Int
    public let minimumControlSurfaceDistanceFromSweptSurfaceCells: Double
    public let maximumAllowedRelativeRMSClosureResidual: Double
    public let maximumAllowedCollisionCorrectionActivationFraction: Double
    public let movingWallPositivityLimiterImplemented: Bool
    public let movingWallPositivityLimiterActivationCount: Int
    public let productionDefaultModified: Bool
    public let result: MetalIndexedBirdSurfaceMomentumClosureCase
    public let allStepsCompleted: Bool
    public let populationPositivityPassed: Bool
    public let forceAndMomentumAccountingPassed: Bool
    public let collisionCorrectionIntrusionPassed: Bool
    public let ledgerGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallFullWindowForceSample:
    Codable, Sendable
{
    public let targetSampleIndex: Int
    public let sourceTimeSeconds: Double
    public let measuredForceXNewtons: Double
    public let measuredForceZNewtons: Double
    public let intervalMeanComputedForceNewtons: SIMD3<Double>
    public let residualXNewtons: Double
    public let residualZNewtons: Double
}

public struct MetalIndexedBirdSurfaceMovingWallFullWindowReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceRetainedLedgerGatePassed: Bool
    public let sourceRetainedLedgerSteps: Int
    public let sourceCandidateIdentifier: String
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let requestedSteps: Int
    public let plan: MetalIndexedBirdSurfacePilotPlan
    public let controlVolume: MetalIndexedBirdSurfaceControlVolumeBounds
    public let spongeWidthCells: Int
    public let minimumControlSurfaceDistanceFromDomainBoundaryCells: Int
    public let minimumControlSurfaceDistanceFromSweptSurfaceCells: Double
    public let maximumAllowedRelativeRMSClosureResidual: Double
    public let maximumAllowedCollisionCorrectionActivationFraction: Double
    public let movingWallPositivityLimiterImplemented: Bool
    public let movingWallPositivityLimiterActivationCount: Int
    public let productionDefaultModified: Bool
    public let ledgerResult: MetalIndexedBirdSurfaceMomentumClosureCase
    public let registeredForceSamples:
        [MetalIndexedBirdSurfaceMovingWallFullWindowForceSample]
    public let registeredComparisonSampleCount: Int
    public let measuredMeanForceXNewtons: Double?
    public let measuredMeanForceZNewtons: Double?
    public let computedMeanForceXNewtons: Double?
    public let computedMeanForceZNewtons: Double?
    public let normalizedRMSError: Double?
    public let measuredImpulseXNewtonSeconds: Double?
    public let measuredImpulseZNewtonSeconds: Double?
    public let computedImpulseXNewtonSeconds: Double?
    public let computedImpulseZNewtonSeconds: Double?
    public let measuredPeakTimeSeconds: Double?
    public let computedPeakTimeSeconds: Double?
    public let allStepsCompleted: Bool
    public let populationPositivityPassed: Bool
    public let forceAndMomentumAccountingPassed: Bool
    public let collisionCorrectionIntrusionPassed: Bool
    public let registeredWindowComplete: Bool
    public let fullWindowGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallSpatialPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceD16FullWindowSHA256: String
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let caseReferenceLengthCells: [Int]
    public let reusedReferenceLengthCells: Int
    public let gridContracts: [MetalIndexedBirdSurfaceRefinementGridContract]
    public let maximumAllowedRelativeRMSClosureResidual: Double
    public let maximumAllowedCollisionCorrectionActivationFraction: Double
    public let maximumAllowedFineGridRelativeDifference: Double
    public let requireMonotonicTrendReduction: Bool
    public let selectionRule: String
    public let fixedInputs: String
    public let experimentalAgreementGateApplied: Bool
    public let passed: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallSpatialCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let sourceSpatialPreregistrationSHA256: String
    public let sourceD16FullWindowSHA256: String
    public let referenceLengthCells: Int
    public let fullWindowReport:
        MetalIndexedBirdSurfaceMovingWallFullWindowReport
    public let caseGatePassed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallSpatialTrendMetrics:
    Codable, Sendable, Equatable
{
    public let coarseReferenceLengthCells: Int
    public let fineReferenceLengthCells: Int
    public let intervalForceNormalizedRMSDifference: Double
    public let meanForceRelativeDifference: Double
    public let impulseRelativeDifference: Double
    public let peakTimeDifferenceSeconds: Double
    public let normalizedPeakTimeDifference: Double
    public let gridTrendScore: Double
}

public struct MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceSpatialPreregistrationSHA256: String
    public let sourceD8CaseSHA256: String
    public let sourceD12CaseSHA256: String
    public let sourceD16FullWindowSHA256: String
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let referenceLengthCells: [Int]
    public let d8ToD12: MetalIndexedBirdSurfaceMovingWallSpatialTrendMetrics
    public let d12ToD16: MetalIndexedBirdSurfaceMovingWallSpatialTrendMetrics
    public let intervalForceTrendReductionRatio: Double
    public let meanForceTrendReductionRatio: Double
    public let impulseTrendReductionRatio: Double
    public let maximumAllowedFineGridRelativeDifference: Double
    public let allCaseGatesPassed: Bool
    public let monotonicTrendReductionPassed: Bool
    public let fineGridForceConvergencePassed: Bool
    public let spatialRefinementGatePassed: Bool
    public let productionPromotionAuthorized: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceSpatialDiscriminatorSHA256: String
    public let sourceLagBandSHA256: String
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let referenceLengthCells: [Int]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let forceBinDurationSeconds: Double
    public let forceBinCount: Int
    public let maximumAllowedRelativeRMSClosureResidual: Double
    public let maximumAllowedCollisionCorrectionActivationFraction: Double
    public let maximumAllowedTopologyCorrectionNewtons: Double
    public let maximumAllowedImpulseIdentityRelativeError: Double
    public let maximumAllowedFineGridRelativeDifference: Double
    public let minimumAggregationImprovementFraction: Double
    public let maximumAggregationRelativeSpreadFraction: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin:
    Codable, Sendable
{
    public let binIndex: Int
    public let elapsedStartSeconds: Double
    public let elapsedEndSeconds: Double
    public let substepCount: Int
    public let endpointForceNewtons: SIMD3<Double>
    public let sampleTrapezoidalMeanForceNewtons: SIMD3<Double>
    public let impulsePreservingMeanForceNewtons: SIMD3<Double>
    public let directForceImpulseNewtonSeconds: SIMD3<Double>
    public let impulseIdentityRelativeError: Double
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalSamplingCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceTemporalPreregistrationSHA256: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let surfaceTimeAdvanceSeconds: Double
    public let forceBinDurationSeconds: Double
    public let forceBinCount: Int
    public let fluidStepsPerForceBin: Int
    public let requestedSteps: Int
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let ledgerResult: MetalIndexedBirdSurfaceMomentumClosureCase
    public let bins: [MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin]
    public let directTotalForceImpulseNewtonSeconds: SIMD3<Double>
    public let binnedTotalForceImpulseNewtonSeconds: SIMD3<Double>
    public let maximumImpulseIdentityRelativeError: Double
    public let maximumTopologyCorrectionNewtons: Double
    public let fixedGeometryTopologyGatePassed: Bool
    public let impulseIdentityGatePassed: Bool
    public let numericalCaseGatePassed: Bool
    public let productionDefaultModified: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalSamplingMetrics:
    Codable, Sendable
{
    public let endpointPairwiseNormalizedRMSDifference: Double
    public let sampleTrapezoidalPairwiseNormalizedRMSDifference: Double
    public let impulsePreservingPairwiseNormalizedRMSDifference: Double
    public let endpointToImpulseImprovementFraction: Double
    public let aggregationRelativeSpreadFraction: Double
    public let directTotalImpulseRelativeDifference: Double
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceTemporalPreregistrationSHA256: String
    public let sourceSpatialDiscriminatorSHA256: String
    public let sourceLagBandSHA256: String
    public let d12: MetalIndexedBirdSurfaceMovingWallTemporalSamplingCaseReport
    public let d16: MetalIndexedBirdSurfaceMovingWallTemporalSamplingCaseReport
    public let metrics: MetalIndexedBirdSurfaceMovingWallTemporalSamplingMetrics
    public let temporalAggregationSensitivityLikely: Bool
    public let fixedGeometryGridResponseCleared: Bool
    public let aggregationInvariantGridDisagreementLikely: Bool
    public let classification: String
    public let d20DiagnosticAuthorized: Bool
    public let rawSpatialGateModified: Bool
    public let productionPromotionAuthorized: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceTemporalPreregistrationSHA256: String
    public let sourceTemporalSamplingSHA256: String
    public let selectedCollisionOperator: String
    public let movingWallNormalization: String
    public let referenceLengthCells: [Int]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let forceBinDurationSeconds: Double
    public let baselineForceBinCount: Int
    public let extendedForceBinCount: Int
    public let nestedPrefixBinCounts: [Int]
    public let blockBinCount: Int
    public let maximumAllowedPrefixReproductionRelativeError: Double
    public let maximumAllowedFineGridRelativeDifference: Double
    public let minimumLateBlockImprovementFraction: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow:
    Codable, Sendable
{
    public let identifier: String
    public let startBin: Int
    public let endBinExclusive: Int
    public let metrics: MetalIndexedBirdSurfaceMovingWallTemporalSamplingMetrics
}

public struct MetalIndexedBirdSurfaceMovingWallTemporalDurationReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceDurationPreregistrationSHA256: String
    public let sourceTemporalSamplingSHA256: String
    public let extendedSampling:
        MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport
    public let prefixWindows:
        [MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow]
    public let blockWindows:
        [MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow]
    public let baselinePrefixMaximumRelativeError: Double
    public let baselinePrefixReproduced: Bool
    public let lateBlockImprovementFraction: Double
    public let durationCleared: Bool
    public let startupRelaxationLikely: Bool
    public let persistentFixedWallGridDisagreementLikely: Bool
    public let classification: String
    public let d20DiagnosticAuthorized: Bool
    public let rawSpatialGateModified: Bool
    public let productionPromotionAuthorized: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkGeometryPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceDurationPreregistrationSHA256: String
    public let sourceDurationReportSHA256: String
    public let referenceLengthCells: [Int]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let interpolationFractionBinCount: Int
    public let maximumAllowedMetalCPUMaskMismatchCells: Int
    public let maximumAllowedMetalCPUWallVelocityDifferenceLattice: Double
    public let maximumAllowedMetalCPUSignedDistanceDifferenceCells: Double
    public let maximumAllowedMetalCPUAggregateRelativeDifference: Double
    public let maximumAllowedTotalLinkMeasureRelativeDifference: Double
    public let maximumAllowedComponentLinkMeasureRelativeDifference: Double
    public let maximumAllowedInterpolationHistogramTotalVariation: Double
    public let maximumAllowedComponentInterpolationHistogramTotalVariation:
        Double
    public let maximumAllowedGridMeanVelocityDifferenceRelativeToQuadratureRMS:
        Double
    public let maximumAllowedGridRMSSpeedRelativeDifference: Double
    public let maximumAllowedLinkToQuadratureMeanVelocityError: Double
    public let maximumAllowedLinkToQuadratureRMSSpeedRelativeError: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let contractRevisionRationale: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkGeometryBin: Codable, Sendable {
    public let partIdentifier: Int
    public let directionIndex: Int
    public let linkCount: Int
    public let linkMeasureSquareMeters: Double
    public let interpolationFractionIntegralSquareMeters: Double
    public let interpolationFractionSquaredIntegralSquareMeters: Double
    public let interpolationFractionMeasureHistogram: [Double]
    public let wallVelocityIntegralSquareMeterMetersPerSecond: SIMD3<Double>
    public let wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared:
        Double
}

public struct MetalIndexedBirdSurfaceTriangleQuadratureComponent:
    Codable, Sendable
{
    public let partIdentifier: Int
    public let componentName: String
    public let triangleCount: Int
    public let boundaryEdgeCount: Int
    public let midSurfaceAreaSquareMeters: Double
    public let thickenedD3Q19MeasureSquareMeters: Double
    public let meanWallVelocityMetersPerSecond: SIMD3<Double>
    public let rmsWallSpeedMetersPerSecond: Double
}

public struct MetalIndexedBirdSurfaceLinkGeometryComponent: Codable, Sendable {
    public let partIdentifier: Int
    public let componentName: String
    public let linkCount: Int
    public let linkMeasureSquareMeters: Double
    public let interpolationFractionMean: Double
    public let interpolationFractionStandardDeviation: Double
    public let interpolationFractionMeasureHistogram: [Double]
    public let meanWallVelocityMetersPerSecond: SIMD3<Double>
    public let rmsWallSpeedMetersPerSecond: Double
    public let triangleQuadrature:
        MetalIndexedBirdSurfaceTriangleQuadratureComponent
    public let linkToQuadratureMeasureRatio: Double
    public let meanVelocityErrorRelativeToQuadratureRMS: Double
    public let rmsSpeedRelativeError: Double
}

public struct MetalIndexedBirdSurfaceLinkGeometryCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cellSizeMeters: Double
    public let halfThicknessMeters: Double
    public let frozenSourceTimeSeconds: Double
    public let runtimeSeconds: Double
    public let metalBins: [MetalIndexedBirdSurfaceLinkGeometryBin]
    public let cpuBins: [MetalIndexedBirdSurfaceLinkGeometryBin]
    public let components: [MetalIndexedBirdSurfaceLinkGeometryComponent]
    public let metalCPUMaskMismatchCellCount: Int
    public let maximumMetalCPUWallVelocityDifferenceLattice: Double
    public let maximumMetalCPUSignedDistanceDifferenceCells: Double
    public let metalCPUExactLinkCountMatch: Bool
    public let metalCPUMaximumLinkMeasureDifferenceSquareMeters: Double
    public let maximumMetalCPUAggregateRelativeDifference: Double
    public let allValuesFinite: Bool
    public let parityGatePassed: Bool
}

public struct MetalIndexedBirdSurfaceLinkGeometryMetrics: Codable, Sendable {
    public let totalLinkMeasureRelativeDifference: Double
    public let maximumComponentLinkMeasureRelativeDifference: Double
    public let interpolationHistogramTotalVariation: Double
    public let maximumComponentInterpolationHistogramTotalVariation: Double
    public let maximumGridMeanVelocityDifferenceRelativeToQuadratureRMS: Double
    public let maximumGridRMSSpeedRelativeDifference: Double
    public let maximumLinkToQuadratureMeanVelocityError: Double
    public let maximumLinkToQuadratureRMSSpeedRelativeError: Double
}

public struct MetalIndexedBirdSurfaceLinkGeometryReport: Codable, Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkGeometryPreregistrationSHA256: String
    public let sourceDurationPreregistrationSHA256: String
    public let sourceDurationReportSHA256: String
    public let d12: MetalIndexedBirdSurfaceLinkGeometryCaseReport
    public let d16: MetalIndexedBirdSurfaceLinkGeometryCaseReport
    public let metrics: MetalIndexedBirdSurfaceLinkGeometryMetrics
    public let wallRepresentationCleared: Bool
    public let linkMeasureBiasLikely: Bool
    public let interpolationBiasLikely: Bool
    public let wallVelocityDepositionBiasLikely: Bool
    public let classification: String
    public let d20DiagnosticAuthorized: Bool
    public let rawSpatialGateModified: Bool
    public let productionPromotionAuthorized: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkVelocityPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkGeometryPreregistrationSHA256: String
    public let sourceLinkGeometryReportSHA256: String
    public let referenceLengthCells: [Int]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let maximumAllowedSourceReproductionRelativeError: Double
    public let maximumAllowedOffsetSurfaceRMSResidualCells: Double
    public let maximumAllowedOffsetSurfaceMaximumResidualCells: Double
    public let maximumAllowedExactMeanVelocityError: Double
    public let maximumAllowedExactRMSSpeedRelativeError: Double
    public let maximumAllowedEndpointMeanVelocityError: Double
    public let maximumAllowedEndpointRMSSpeedRelativeError: Double
    public let maximumAllowedD12D16MeanVelocityDifference: Double
    public let minimumCausalImprovementFraction: Double
    public let minimumContributionImprovementFraction: Double
    public let minimumEndpointCaptureOfExactImprovementFraction: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkVelocityCandidate: Codable, Sendable {
    public let identifier: String
    public let meanWallVelocityMetersPerSecond: SIMD3<Double>
    public let rmsWallSpeedMetersPerSecond: Double
    public let meanVelocityErrorRelativeToQuadratureRMS: Double
    public let rmsSpeedRelativeError: Double
}

public struct MetalIndexedBirdSurfaceLinkVelocityBin: Codable, Sendable {
    public let partIdentifier: Int
    public let directionIndex: Int
    public let linkCount: Int
    public let linkMeasureSquareMeters: Double
    public let endpointVelocityIntegralSquareMeterMetersPerSecond:
        SIMD3<Double>
    public let exactVelocityIntegralSquareMeterMetersPerSecond: SIMD3<Double>
    public let endpointSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared:
        Double
    public let exactSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared:
        Double
    public let offsetSurfaceResidualSquaredIntegralSquareMeterCellsSquared:
        Double
    public let offsetSurfaceMaximumResidualCells: Double
}

public struct MetalIndexedBirdSurfaceLinkVelocityComponent: Codable, Sendable {
    public let partIdentifier: Int
    public let componentName: String
    public let linkCount: Int
    public let linkMeasureSquareMeters: Double
    public let productionSolidNode: MetalIndexedBirdSurfaceLinkVelocityCandidate
    public let endpointInterpolated: MetalIndexedBirdSurfaceLinkVelocityCandidate
    public let exactLinkIntersection:
        MetalIndexedBirdSurfaceLinkVelocityCandidate
    public let offsetSurfaceRMSResidualCells: Double
    public let offsetSurfaceMaximumResidualCells: Double
}

public struct MetalIndexedBirdSurfaceLinkVelocityCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let frozenSourceTimeSeconds: Double
    public let runtimeSeconds: Double
    public let bins: [MetalIndexedBirdSurfaceLinkVelocityBin]
    public let components: [MetalIndexedBirdSurfaceLinkVelocityComponent]
    public let sourceProductionMaximumRelativeDifference: Double
    public let allValuesFinite: Bool
    public let sourceReproductionPassed: Bool
}

public struct MetalIndexedBirdSurfaceLinkVelocityMetrics: Codable, Sendable {
    public let maximumSourceProductionRelativeDifference: Double
    public let maximumProductionMeanVelocityError: Double
    public let maximumEndpointMeanVelocityError: Double
    public let maximumExactMeanVelocityError: Double
    public let maximumProductionRMSSpeedRelativeError: Double
    public let maximumEndpointRMSSpeedRelativeError: Double
    public let maximumExactRMSSpeedRelativeError: Double
    public let maximumEndpointD12D16MeanVelocityDifference: Double
    public let maximumExactD12D16MeanVelocityDifference: Double
    public let maximumOffsetSurfaceRMSResidualCells: Double
    public let maximumOffsetSurfaceResidualCells: Double
    public let minimumLeftWingExactImprovementFraction: Double
    public let minimumLeftWingEndpointImprovementFraction: Double
    public let minimumEndpointCaptureOfExactImprovementFraction: Double
}

public struct MetalIndexedBirdSurfaceLinkVelocityReport: Codable, Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkVelocityPreregistrationSHA256: String
    public let sourceLinkGeometryPreregistrationSHA256: String
    public let sourceLinkGeometryReportSHA256: String
    public let d12: MetalIndexedBirdSurfaceLinkVelocityCaseReport
    public let d16: MetalIndexedBirdSurfaceLinkVelocityCaseReport
    public let metrics: MetalIndexedBirdSurfaceLinkVelocityMetrics
    public let intersectionPlacementPassed: Bool
    public let exactIntersectionClearsBias: Bool
    public let solidNodeSamplingCausal: Bool
    public let endpointInterpolationQualified: Bool
    public let classification: String
    public let d20DiagnosticAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let rawSpatialGateModified: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkIntersectionPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkVelocityPreregistrationSHA256: String
    public let sourceLinkVelocityReportSHA256: String
    public let referenceLengthCells: [Int]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let outlierResidualThresholdCells: Double
    public let barycentricFeatureTolerance: Double
    public let maximumJunctionAlternateSurfaceResidualCells: Double
    public let minimumEdgeOrJunctionAssociationFraction: Double
    public let minimumDirectionConcentrationFraction: Double
    public let minimumInteriorAssociationFraction: Double
    public let maximumAllowedSourceMaximumResidualDifferenceCells: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkIntersectionOutlier:
    Codable, Sendable
{
    public let partIdentifier: Int
    public let componentName: String
    public let directionIndex: Int
    public let cellCoordinate: SIMD3<Int>
    public let neighborCellCoordinate: SIMD3<Int>
    public let linkMeasureSquareMeters: Double
    public let solidSignedDistanceCells: Double
    public let fluidSignedDistanceCells: Double
    public let fluidToIntersectionFraction: Double
    public let intersectionMeters: SIMD3<Double>
    public let nearestPointMeters: SIMD3<Double>
    public let nearestTriangleIndex: Int
    public let nearestTriangleVertexIndices: SIMD3<Int>
    public let nearestTriangleBarycentric: SIMD3<Double>
    public let nearestTriangleFeature: String
    public let meshBoundaryAssociated: Bool
    public let midSurfaceDistanceCells: Double
    public let signedOffsetSurfaceResidualCells: Double
    public let offsetSurfaceResidualCells: Double
    public let nearestAlternatePartIdentifier: Int?
    public let nearestAlternateComponentName: String?
    public let nearestAlternateTriangleIndex: Int?
    public let nearestAlternateMidSurfaceDistanceCells: Double?
    public let nearestAlternateOffsetSurfaceResidualCells: Double?
    public let componentJunctionCandidate: Bool
}

public struct MetalIndexedBirdSurfaceLinkIntersectionCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let frozenSourceTimeSeconds: Double
    public let runtimeSeconds: Double
    public let totalLinkCount: Int
    public let totalLinkMeasureSquareMeters: Double
    public let outlierCount: Int
    public let outlierLinkMeasureSquareMeters: Double
    public let outlierCountFraction: Double
    public let outlierLinkMeasureFraction: Double
    public let meshBoundaryAssociatedOutlierCount: Int
    public let componentJunctionCandidateOutlierCount: Int
    public let edgeOrJunctionAssociatedOutlierCount: Int
    public let interiorAssociatedOutlierCount: Int
    public let edgeOrJunctionAssociatedMeasureFraction: Double
    public let interiorAssociatedMeasureFraction: Double
    public let dominantDirectionIndex: Int?
    public let dominantDirectionMeasureFraction: Double
    public let maximumOffsetSurfaceResidualCells: Double
    public let sourceMaximumResidualDifferenceCells: Double
    public let sourceLinkCountMatched: Bool
    public let allOutliersArchived: Bool
    public let allValuesFinite: Bool
    public let outliers: [MetalIndexedBirdSurfaceLinkIntersectionOutlier]
}

public struct MetalIndexedBirdSurfaceLinkIntersectionMetrics:
    Codable, Sendable
{
    public let maximumSourceMaximumResidualDifferenceCells: Double
    public let d12OutlierCount: Int
    public let d16OutlierCount: Int
    public let d12OutlierLinkMeasureFraction: Double
    public let d16OutlierLinkMeasureFraction: Double
    public let minimumEdgeOrJunctionAssociatedMeasureFraction: Double
    public let minimumInteriorAssociatedMeasureFraction: Double
    public let minimumDominantDirectionMeasureFraction: Double
    public let sameDominantDirectionAcrossGrids: Bool
    public let maximumOffsetSurfaceResidualCells: Double
}

public struct MetalIndexedBirdSurfaceLinkIntersectionReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkIntersectionPreregistrationSHA256: String
    public let sourceLinkVelocityPreregistrationSHA256: String
    public let sourceLinkVelocityReportSHA256: String
    public let d12: MetalIndexedBirdSurfaceLinkIntersectionCaseReport
    public let d16: MetalIndexedBirdSurfaceLinkIntersectionCaseReport
    public let metrics: MetalIndexedBirdSurfaceLinkIntersectionMetrics
    public let sourceReproductionPassed: Bool
    public let edgeOrJunctionAssociated: Bool
    public let directionAssociated: Bool
    public let interiorAssociated: Bool
    public let classification: String
    public let d20DiagnosticAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let fluidEvolutionExecuted: Bool
    public let rawSpatialGateModified: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkRayRootPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkIntersectionPreregistrationSHA256: String
    public let sourceLinkIntersectionReportSHA256: String
    public let referenceLengthCells: [Int]
    public let frozenSourceSampleIndex: Int
    public let frozenSourceTimeSeconds: Double
    public let expectedOutlierCounts: [Int]
    public let expectedJunctionCandidateCounts: [Int]
    public let reverseScanSubdivisions: Int
    public let bisectionIterations: Int
    public let maximumAllowedRootClosureResidualCells: Double
    public let maximumAllowedGlobalRootRMSShiftCells: Double
    public let maximumAllowedGlobalRootMaximumShiftCells: Double
    public let minimumRequiredOwnerToGlobalRMSReductionFraction: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkRayRootSample: Codable, Sendable {
    public let sourceOutlierIndex: Int
    public let partIdentifier: Int
    public let componentName: String
    public let directionIndex: Int
    public let cellCoordinate: SIMD3<Int>
    public let componentJunctionCandidate: Bool
    public let linkMeasureSquareMeters: Double
    public let productionSolidToFluidFraction: Double
    public let productionFluidToIntersectionFraction: Double
    public let productionOwnerOffsetResidualCells: Double
    public let productionGlobalOffsetResidualCells: Double
    public let productionNearestGlobalPartIdentifier: Int
    public let exactSolidEndpointSignedDistanceCells: Double
    public let exactFluidEndpointSignedDistanceCells: Double
    public let exactSolidEndpointGlobalPartIdentifier: Int
    public let exactFluidEndpointGlobalPartIdentifier: Int
    public let endpointNearestComponentChanged: Bool
    public let fluidEndpointUsesRecordedAlternateComponent: Bool
    public let exactOwnerSolidToFluidFraction: Double
    public let exactOwnerFluidToIntersectionFraction: Double
    public let exactOwnerRootTriangleIndex: Int
    public let exactOwnerRootClosureResidualCells: Double
    public let exactGlobalSolidToFluidFraction: Double
    public let exactGlobalFluidToIntersectionFraction: Double
    public let exactGlobalRootPartIdentifier: Int
    public let exactGlobalRootTriangleIndex: Int
    public let exactGlobalRootClosureResidualCells: Double
    public let productionToOwnerRootShiftCells: Double
    public let productionToGlobalRootShiftCells: Double
    public let ownerToGlobalShiftReductionFraction: Double
    public let globalRootUsesOwnerComponent: Bool
    public let globalRootUsesRecordedAlternateComponent: Bool
}

public struct MetalIndexedBirdSurfaceLinkRayRootCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let referenceLengthCells: Int
    public let runtimeSeconds: Double
    public let sampleCount: Int
    public let junctionCandidateCount: Int
    public let interiorOutlierCount: Int
    public let globalRootComponentSwitchCount: Int
    public let endpointNearestComponentChangeCount: Int
    public let junctionOwnerRootRMSShiftCells: Double
    public let junctionGlobalRootRMSShiftCells: Double
    public let junctionGlobalRootMaximumShiftCells: Double
    public let junctionOwnerToGlobalRMSReductionFraction: Double
    public let allOwnerRootRMSShiftCells: Double
    public let allGlobalRootRMSShiftCells: Double
    public let allGlobalRootMaximumShiftCells: Double
    public let allOwnerToGlobalRMSReductionFraction: Double
    public let interiorGlobalRootMaximumShiftCells: Double?
    public let maximumRootClosureResidualCells: Double
    public let sourceRecordsMatched: Bool
    public let allRootsBracketed: Bool
    public let allValuesFinite: Bool
    public let samples: [MetalIndexedBirdSurfaceLinkRayRootSample]
}

public struct MetalIndexedBirdSurfaceLinkRayRootMetrics:
    Codable, Sendable
{
    public let maximumJunctionGlobalRootRMSShiftCells: Double
    public let maximumJunctionGlobalRootMaximumShiftCells: Double
    public let minimumJunctionOwnerToGlobalRMSReductionFraction: Double
    public let maximumAllGlobalRootRMSShiftCells: Double
    public let maximumAllGlobalRootMaximumShiftCells: Double
    public let minimumAllOwnerToGlobalRMSReductionFraction: Double
    public let maximumInteriorGlobalRootShiftCells: Double?
    public let maximumRootClosureResidualCells: Double
    public let totalGlobalRootComponentSwitchCount: Int
    public let totalEndpointNearestComponentChangeCount: Int
}

public struct MetalIndexedBirdSurfaceLinkRayRootReport: Codable, Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkRayRootPreregistrationSHA256: String
    public let sourceLinkIntersectionPreregistrationSHA256: String
    public let sourceLinkIntersectionReportSHA256: String
    public let d12: MetalIndexedBirdSurfaceLinkRayRootCaseReport
    public let d16: MetalIndexedBirdSurfaceLinkRayRootCaseReport
    public let metrics: MetalIndexedBirdSurfaceLinkRayRootMetrics
    public let sourceReproductionPassed: Bool
    public let rootClosurePassed: Bool
    public let junctionGlobalUnionPlacementPassed: Bool
    public let allGlobalUnionPlacementPassed: Bool
    public let ownerToGlobalReductionPassed: Bool
    public let classification: String
    public let priorPlacementClassificationSuperseded: Bool
    public let d20DiagnosticAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let fluidEvolutionExecuted: Bool
    public let rawSpatialGateModified: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkCoefficientPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkRayRootPreregistrationSHA256: String
    public let sourceLinkRayRootReportSHA256: String
    public let referenceLengthCells: [Int]
    public let expectedSampleCounts: [Int]
    public let branchThreshold: Double
    public let maximumAllowedWeightedRMSCoefficientL1Difference: Double
    public let maximumAllowedCoefficientL1Difference: Double
    public let maximumAllowedSymmetricOperatorNormRatio: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkCoefficients:
    Codable, Sendable, Equatable
{
    public let reflected: Double
    public let fartherOutgoing: Double
    public let previousIncoming: Double
    public let fluidEndpointWallProjection: Double
    public let solidEndpointWallProjection: Double
}

public struct MetalIndexedBirdSurfaceLinkCoefficientSample:
    Codable, Sendable
{
    public let sourceOutlierIndex: Int
    public let partIdentifier: Int
    public let componentName: String
    public let directionIndex: Int
    public let cellCoordinate: SIMD3<Int>
    public let componentJunctionCandidate: Bool
    public let linkMeasureSquareMeters: Double
    public let productionFluidToIntersectionFraction: Double
    public let exactGlobalFluidToIntersectionFraction: Double
    public let absoluteFractionDifference: Double
    public let productionBranch: String
    public let exactGlobalBranch: String
    public let branchChanged: Bool
    public let productionCoefficients:
        MetalIndexedBirdSurfaceLinkCoefficients
    public let exactGlobalCoefficients:
        MetalIndexedBirdSurfaceLinkCoefficients
    public let coefficientL1Difference: Double
    public let maximumAbsoluteCoefficientDifference: Double
    public let wallProjectionCoefficientL1Difference: Double
    public let productionOperatorL1Norm: Double
    public let exactGlobalOperatorL1Norm: Double
    public let symmetricOperatorNormRatio: Double
}

public struct MetalIndexedBirdSurfaceLinkCoefficientCaseReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let referenceLengthCells: Int
    public let runtimeSeconds: Double
    public let sampleCount: Int
    public let productionNearBranchCount: Int
    public let exactGlobalNearBranchCount: Int
    public let nearToFarBranchChangeCount: Int
    public let farToNearBranchChangeCount: Int
    public let branchChangeCount: Int
    public let branchChangeLinkMeasureFraction: Double
    public let weightedRMSFractionDifference: Double
    public let maximumFractionDifference: Double
    public let weightedRMSCoefficientL1Difference: Double
    public let maximumCoefficientL1Difference: Double
    public let maximumAbsoluteCoefficientDifference: Double
    public let weightedRMSWallProjectionCoefficientL1Difference: Double
    public let maximumSymmetricOperatorNormRatio: Double
    public let sourceRecordsMatched: Bool
    public let allValuesFinite: Bool
    public let samples: [MetalIndexedBirdSurfaceLinkCoefficientSample]
}

public struct MetalIndexedBirdSurfaceLinkCoefficientMetrics:
    Codable, Sendable
{
    public let totalBranchChangeCount: Int
    public let maximumBranchChangeLinkMeasureFraction: Double
    public let maximumWeightedRMSFractionDifference: Double
    public let maximumFractionDifference: Double
    public let maximumWeightedRMSCoefficientL1Difference: Double
    public let maximumCoefficientL1Difference: Double
    public let maximumAbsoluteCoefficientDifference: Double
    public let maximumWeightedRMSWallProjectionCoefficientL1Difference:
        Double
    public let maximumSymmetricOperatorNormRatio: Double
}

public struct MetalIndexedBirdSurfaceLinkCoefficientReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkCoefficientPreregistrationSHA256: String
    public let sourceLinkRayRootPreregistrationSHA256: String
    public let sourceLinkRayRootReportSHA256: String
    public let d12: MetalIndexedBirdSurfaceLinkCoefficientCaseReport
    public let d16: MetalIndexedBirdSurfaceLinkCoefficientCaseReport
    public let metrics: MetalIndexedBirdSurfaceLinkCoefficientMetrics
    public let sourceReproductionPassed: Bool
    public let coefficientInsensitiveGatePassed: Bool
    public let classification: String
    public let validationOnlyPopulationReplayAuthorized: Bool
    public let d20DiagnosticAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let fluidEvolutionExecuted: Bool
    public let rawSpatialGateModified: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkPopulationPreregistration:
    Codable, Sendable, Equatable
{
    public let schemaVersion: Int
    public let contractRevision: Int
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkCoefficientPreregistrationSHA256: String
    public let sourceLinkCoefficientReportSHA256: String
    public let sourceTemporalDurationPreregistrationSHA256: String
    public let sourceTemporalDurationReportSHA256: String
    public let referenceLengthCells: Int
    public let frozenSourceTimeSeconds: Double
    public let captureStartStep: Int
    public let captureEndStep: Int
    public let captureStride: Int
    public let expectedLinkCount: Int
    public let expectedUniqueBranchChangeCount: Int
    public let expectedProductionFallbackLinkCount: Int
    public let expectedExactGlobalFallbackLinkCount: Int
    public let branchThreshold: Double
    public let maximumAllowedProductionFractionDifference: Double
    public let maximumAllowedProductionReconstructionDifference: Double
    public let minimumMaterialPopulationRelativeRMSDifference: Double
    public let minimumMaterialOutlierForceRelativeRMSDifference: Double
    public let minimumPotentialGlobalForceRMSContribution: Double
    public let minimumPotentialGlobalImpulseContribution: Double
    public let selectionRule: String
    public let fixedInputs: String
    public let passed: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
}

public struct MetalIndexedBirdSurfaceLinkPopulationSample:
    Codable, Sendable
{
    public let step: Int
    public let sourceOutlierIndex: Int
    public let partIdentifier: Int
    public let componentName: String
    public let directionIndex: Int
    public let solidCellCoordinate: SIMD3<Int>
    public let fluidCellCoordinate: SIMD3<Int>
    public let rasterFluidToIntersectionFraction: Double
    public let productionFluidToIntersectionFraction: Double
    public let exactGlobalFluidToIntersectionFraction: Double
    public let productionBranch: String
    public let exactGlobalBranch: String
    public let branchChanged: Bool
    public let productionFallbackApplied: Bool
    public let exactGlobalFallbackApplied: Bool
    public let reflectedPopulation: Double
    public let fartherOutgoingPopulation: Double
    public let previousIncomingPopulation: Double
    public let preStepLocalDensity: Double
    public let fluidEndpointWallProjectionLattice: Double
    public let solidEndpointWallProjectionLattice: Double
    public let productionWallProjectionLattice: Double
    public let exactGlobalWallProjectionLattice: Double
    public let productionRawWallCorrection: Double
    public let exactGlobalRawWallCorrection: Double
    public let productionReconstructedPopulation: Double
    public let independentlyReconstructedProductionPopulation: Double
    public let exactGlobalReconstructedPopulation: Double
    public let populationDifference: Double
    public let productionReconstructionDifference: Double
    public let productionLinkForceNewtons: SIMD3<Double>
    public let exactGlobalLinkForceNewtons: SIMD3<Double>
    public let linkForceDifferenceNewtons: SIMD3<Double>
    public let productionLinkTorqueNewtonMeters: SIMD3<Double>
    public let exactGlobalLinkTorqueNewtonMeters: SIMD3<Double>
    public let linkTorqueDifferenceNewtonMeters: SIMD3<Double>
}

public struct MetalIndexedBirdSurfaceLinkPopulationStep:
    Codable, Sendable
{
    public let step: Int
    public let aerodynamicForceNewtons: SIMD3<Double>
    public let productionOutlierForceNewtons: SIMD3<Double>
    public let exactGlobalOutlierForceNewtons: SIMD3<Double>
    public let outlierForceDifferenceNewtons: SIMD3<Double>
    public let productionOutlierTorqueNewtonMeters: SIMD3<Double>
    public let exactGlobalOutlierTorqueNewtonMeters: SIMD3<Double>
    public let outlierTorqueDifferenceNewtonMeters: SIMD3<Double>
}

public struct MetalIndexedBirdSurfaceLinkPopulationMetrics:
    Codable, Sendable
{
    public let uniqueBranchChangeCount: Int
    public let productionFallbackLinkCount: Int
    public let exactGlobalFallbackLinkCount: Int
    public let capturedSampleCount: Int
    public let populationRelativeRMSDifference: Double
    public let outlierForceRelativeRMSDifference: Double
    public let outlierTorqueRelativeRMSDifference: Double
    public let deltaForceRMSNewtons: Double
    public let deltaTorqueRMSNewtonMeters: Double
    public let globalAerodynamicForceRMSNewtons: Double
    public let deltaForceToGlobalAerodynamicForceRMSRatio: Double
    public let deltaForceImpulseNewtonSeconds: SIMD3<Double>
    public let globalAerodynamicForceImpulseNewtonSeconds: SIMD3<Double>
    public let deltaImpulseToGlobalAerodynamicImpulseRatio: Double
    public let maximumStepDeltaForceToAerodynamicForceRatio: Double
    public let maximumProductionFractionDifference: Double
    public let maximumProductionReconstructionDifference: Double
    public let minimumPreStepLocalDensity: Double
}

public struct MetalIndexedBirdSurfaceLinkPopulationReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let manifestSHA256: String
    public let forceTargetIdentifier: String
    public let forceTargetSHA256: String
    public let sourceLinkPopulationPreregistrationSHA256: String
    public let sourceLinkCoefficientPreregistrationSHA256: String
    public let sourceLinkCoefficientReportSHA256: String
    public let sourceTemporalDurationPreregistrationSHA256: String
    public let sourceTemporalDurationReportSHA256: String
    public let referenceLengthCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cellSizeMeters: Double
    public let fluidTimeStepSeconds: Double
    public let forceToPhysical: Double
    public let domainOriginMeters: SIMD3<Double>
    public let bodyCenterMeters: SIMD3<Double>
    public let frozenSourceTimeSeconds: Double
    public let requestedSteps: Int
    public let completedSteps: Int
    public let runtimeSeconds: Double
    public let samples: [MetalIndexedBirdSurfaceLinkPopulationSample]
    public let steps: [MetalIndexedBirdSurfaceLinkPopulationStep]
    public let metrics: MetalIndexedBirdSurfaceLinkPopulationMetrics
    public let sourceReproductionPassed: Bool
    public let populationMaterialityPassed: Bool
    public let outlierForceMaterialityPassed: Bool
    public let potentialGlobalForceContributionPassed: Bool
    public let potentialGlobalImpulseContributionPassed: Bool
    public let classification: String
    public let validationOnlyBoundaryABAuthorized: Bool
    public let d16CaptureAuthorized: Bool
    public let d20DiagnosticAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let rawSpatialGateModified: Bool
    public let experimentalAgreementGateApplied: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public enum MetalIndexedBirdSurfacePilotValidator {
    public static let sourceAirDensity: Float = 1.18
    public static let sourceDynamicViscosity: Float = 1.849e-5
    public static let minimumTauPlus: Float = 0.500_05
    public static let pilotTauPlus: Float = 0.501
    public static let paddingCells = 12
    public static let spongeWidthCells = 6
    public static let spongeStrength: Float = 0.08
    public static let fluidStepsPerForceSample = 16
    public static let collisionPreRollPopulationDiagnosticStride = 1
    public static let collisionPreRollMaximumActivationFraction = 0.05
    public static let collisionMomentumMaximumRelativeRMSResidual = 0.005
    public static let collisionExtendedPilotPopulationDiagnosticStride = 1
    public static let refinementReferenceLengthMeters: Float = 0.08
    public static let refinementBaseCellSizeMeters: Float = 0.01
    public static let refinementBaseHalfThicknessMeters: Float = 0.0075
    public static let refinementBasePaddingMeters: Float = 0.12
    public static let refinementBaseSpongeWidthMeters: Float = 0.06
    public static let collisionMomentumCandidateOperators:
        [MetalIndexedBirdSurfaceCollisionOperator] = [
            .positivityPreservingRegularizedBGK,
            .positivityPreservingRecursiveRegularizedBGK
        ]
    public static let collisionPreRollOperators:
        [MetalIndexedBirdSurfaceCollisionOperator] = [
            .productionTRT,
            .positivityPreservingRegularizedBGK,
            .positivityPreservingRecursiveRegularizedBGK
        ]

    public static func plan(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75,
        referenceLengthCells: Int = 8,
        stepsPerForceSample: Int = fluidStepsPerForceSample,
        paddingCellCount: Int = paddingCells,
        spongeWidthCellCount: Int = spongeWidthCells
    ) throws -> MetalIndexedBirdSurfacePilotPlan {
        guard cellSizeMeters.isFinite,
              cellSizeMeters > 0,
              halfThicknessCells.isFinite,
              (0.5...2).contains(halfThicknessCells),
              referenceLengthCells >= 8,
              stepsPerForceSample >= fluidStepsPerForceSample,
              paddingCellCount >= 4,
              spongeWidthCellCount >= 4,
              paddingCellCount >= spongeWidthCellCount,
              target.comparisonLastTimeSeconds
                <= Double(surface.frameTimesSeconds.last!) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "coarse pilot geometry or comparison time is invalid"
            )
        }
        let forceRate = target.forceSampleRateHertz
        let dt = 1.0 / (
            forceRate * Double(stepsPerForceSample)
        )
        let maximumSpeed = Double(
            surface.maximumPointSpeedMetersPerSecond
        )
        let latticeSpeed = maximumSpeed * dt / Double(cellSizeMeters)
        let maximumMach = latticeSpeed / Double(D3Q19.soundSpeed)
        guard maximumMach <= 0.15 else {
            throw BirdFlowConfigurationError.latticeMachTooHigh(
                Float(maximumMach)
            )
        }
        let baselineDT = 1.0 / (
            forceRate * Double(fluidStepsPerForceSample)
        )
        let baselineNuLattice = (Double(pilotTauPlus) - 0.5) / 3.0
        let pilotNuPhysical = baselineNuLattice
            * pow(Double(refinementBaseCellSizeMeters), 2) / baselineDT
        let pilotNuLattice = pilotNuPhysical * dt
            / pow(Double(cellSizeMeters), 2)
        let localPilotTauPlus = 0.5 + 3.0 * pilotNuLattice
        guard localPilotTauPlus >= Double(minimumTauPlus) else {
            throw BirdFlowConfigurationError.relaxationTooCloseToLimit(
                Float(localPilotTauPlus)
            )
        }
        let pilotReynolds = maximumSpeed
            * Double(cellSizeMeters) * Double(referenceLengthCells)
            / pilotNuPhysical
        let sourceNu = Double(sourceDynamicViscosity / sourceAirDensity)
        let sourceNuLattice = sourceNu * dt
            / pow(Double(cellSizeMeters), 2)
        let sourceTau = 0.5 + 3.0 * sourceNuLattice
        let pilotDynamicViscosity = Double(sourceAirDensity)
            * pilotNuPhysical
        let maximumSourceCellSize = 3.0 * sourceNu * latticeSpeed
            / (maximumSpeed * Double(minimumTauPlus - 0.5))
        let totalSteps = Int(round(
            target.comparisonLastTimeSeconds / dt
        ))
        let preRollSteps = Int(round(
            target.comparisonFirstTimeSeconds / dt
        ))
        guard abs(Double(totalSteps) * dt
                - target.comparisonLastTimeSeconds) <= 1e-12,
              abs(Double(preRollSteps) * dt
                - target.comparisonFirstTimeSeconds) <= 1e-12 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "force timestamps are not integral fluid steps"
            )
        }
        return MetalIndexedBirdSurfacePilotPlan(
            cellSizeMeters: Double(cellSizeMeters),
            halfThicknessCells: Double(halfThicknessCells),
            paddingCells: paddingCellCount,
            spongeWidthCells: spongeWidthCellCount,
            spongeStrength: Double(spongeStrength),
            forceSamplesPerSecond: forceRate,
            fluidStepsPerForceSample: stepsPerForceSample,
            fluidTimeStepSeconds: dt,
            totalFluidSteps: totalSteps,
            preRollFluidSteps: preRollSteps,
            comparisonForceSamples: target.comparisonSampleCount,
            maximumSurfaceSpeedMetersPerSecond: maximumSpeed,
            latticeReferenceSpeed: latticeSpeed,
            maximumWallMach: maximumMach,
            pilotTauPlus: localPilotTauPlus,
            pilotReynoldsNumber: pilotReynolds,
            sourceAirDensityKilogramsPerCubicMeter:
                Double(sourceAirDensity),
            sourceDynamicViscosityPascalSeconds:
                Double(sourceDynamicViscosity),
            sourceConditionTauPlusAtPilotGrid: sourceTau,
            minimumAllowedTauPlus: Double(minimumTauPlus),
            sourceViscosityRepresentableAtPilotGrid:
                sourceTau >= Double(minimumTauPlus),
            maximumCellSizeForSourceViscosityMeters:
                maximumSourceCellSize,
            pilotDynamicViscosityPascalSeconds:
                pilotDynamicViscosity,
            pilotToSourceViscosityRatio:
                pilotDynamicViscosity
                    / Double(sourceDynamicViscosity),
            experimentalAgreementGateApplied: false
        )
    }

    public static func refinementPlan(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        referenceLengthCells: Int
    ) throws -> MetalIndexedBirdSurfacePilotPlan {
        guard [8, 12, 16].contains(referenceLengthCells) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "dove collision refinement supports only D=8, D=12, or D=16"
            )
        }
        return try plan(
            surface: surface,
            target: target,
            cellSizeMeters:
                refinementReferenceLengthMeters / Float(referenceLengthCells),
            halfThicknessCells:
                refinementBaseHalfThicknessMeters
                    / (refinementReferenceLengthMeters
                        / Float(referenceLengthCells)),
            referenceLengthCells: referenceLengthCells,
            stepsPerForceSample: fluidStepsPerForceSample
                * referenceLengthCells / 8,
            paddingCellCount: Int(round(
                refinementBasePaddingMeters
                    / (refinementReferenceLengthMeters
                        / Float(referenceLengthCells))
            )),
            spongeWidthCellCount: Int(round(
                refinementBaseSpongeWidthMeters
                    / (refinementReferenceLengthMeters
                        / Float(referenceLengthCells))
            ))
        )
    }

    public static func collisionGridPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget
    ) throws -> MetalIndexedBirdSurfaceCollisionGridPreregistration {
        let grids = try [8, 12, 16].map { cells in
            let plan = try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: cells
            )
            return MetalIndexedBirdSurfaceRefinementGridContract(
                referenceLengthCells: cells,
                cellSizeMeters: plan.cellSizeMeters,
                halfThicknessCells: plan.halfThicknessCells,
                paddingCells: plan.paddingCells,
                spongeWidthCells: plan.spongeWidthCells,
                fluidStepsPerForceSample: plan.fluidStepsPerForceSample,
                preRollFluidSteps: plan.preRollFluidSteps,
                totalFluidSteps: plan.totalFluidSteps,
                tauPlus: plan.pilotTauPlus,
                maximumWallMach: plan.maximumWallMach,
                pilotToSourceViscosityRatio:
                    plan.pilotToSourceViscosityRatio
            )
        }
        let regularized = MetalIndexedBirdSurfaceCrossCanonicalEvidence(
            collisionOperator:
                MetalIndexedBirdSurfaceCollisionOperator
                    .positivityPreservingRegularizedBGK.rawValue,
            artifactPath: (
                "ValidationArtifacts/measured-wing-stationary-wall-c16-"
                    + "bulk-collision-operator-ab.json"
            ),
            relativeCorrectionL2: 0.010_968_289_256_290_249,
            maximumAllowedRelativeCorrectionL2: 0.01,
            crossCanonicalGatePassed: false
        )
        let recursive = MetalIndexedBirdSurfaceCrossCanonicalEvidence(
            collisionOperator:
                MetalIndexedBirdSurfaceCollisionOperator
                    .positivityPreservingRecursiveRegularizedBGK.rawValue,
            artifactPath: (
                "ValidationArtifacts/measured-wing-stationary-wall-c16-"
                    + "recursive-regularization-ab.json"
            ),
            relativeCorrectionL2: 0.003_527_852_471_536_101_6,
            maximumAllowedRelativeCorrectionL2: 0.01,
            crossCanonicalGatePassed: true
        )
        return MetalIndexedBirdSurfaceCollisionGridPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            candidateOperators:
                collisionMomentumCandidateOperators.map(\.rawValue),
            discriminatorReferenceLengthCells: [8, 12],
            completionReferenceLengthCells: 16,
            gridContracts: grids,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            maximumCrossCanonicalTrendPenalty: 0.10,
            crossCanonicalEvidence: [regularized, recursive],
            selectionRule: (
                "Run both candidates at D=8 and D=12. Require completion, "
                    + "positive finite populations and loads, all four "
                    + "surface components, and correction activation at or "
                    + "below 5%. Select exactly one candidate only if it "
                    + "passes the locked stationary-wall cross-canonical "
                    + "correction gate and its normalized D8-to-D12 trend "
                    + "score is no more than 10% worse than the best eligible "
                    + "candidate. Otherwise authorize no D=16 run."
            ),
            fixedInputs: (
                "0.08 m reference length; 0.0075 m surface half-thickness; "
                    + "0.12 m padding; 0.06 m sponge width; 2000 Hz force "
                    + "registration; 16/24/32 fluid steps per force sample; "
                    + "fixed physical viscosity floor, density, geometry, "
                    + "kinematics, far-field treatment, moving-boundary "
                    + "operator, force estimator, and numerical gates"
            ),
            experimentalAgreementGateApplied: false,
            passed: grids.map(\.referenceLengthCells) == [8, 12, 16]
                && grids.allSatisfy {
                    $0.maximumWallMach <= 0.15
                        && abs($0.pilotToSourceViscosityRatio
                            - grids[0].pilotToSourceViscosityRatio) <= 1e-4
                },
            claimBoundary: (
                "This preregistration freezes allocation and selection before "
                    + "any D=12 or D=16 measured-dove result is observed. "
                    + "The 68.07x viscosity-floor force error cannot select "
                    + "an operator or establish experimental agreement."
            )
        )
    }

    public static func collisionGridDiscriminator(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration
    ) throws -> MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport {
        let expected = try collisionGridPreregistration(
            surface: surface,
            target: target
        )
        guard preregistration == expected, preregistration.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "collision-grid preregistration does not match locked inputs"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        var cases: [MetalIndexedBirdSurfaceCollisionGridCase] = []
        for cells in preregistration.discriminatorReferenceLengthCells {
            for collisionOperator in collisionMomentumCandidateOperators {
                cases.append(try runCollisionGridCase(
                    backend: backend,
                    surface: surface,
                    target: target,
                    collisionOperator: collisionOperator,
                    referenceLengthCells: cells
                ))
            }
        }
        let rawAssessments = try collisionMomentumCandidateOperators.map {
            collisionOperator -> (
                MetalIndexedBirdSurfaceCollisionOperator,
                CollisionGridTrendMetrics,
                Bool,
                Bool
            ) in
            guard let d8 = cases.first(where: {
                $0.referenceLengthCells == 8
                    && $0.collisionOperator == collisionOperator.rawValue
            }), let d12 = cases.first(where: {
                $0.referenceLengthCells == 12
                    && $0.collisionOperator == collisionOperator.rawValue
            }), let evidence = preregistration.crossCanonicalEvidence.first(
                where: { $0.collisionOperator == collisionOperator.rawValue }
            ) else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "collision-grid discriminator case matrix is incomplete"
                )
            }
            return (
                collisionOperator,
                try collisionGridTrend(
                    coarse: d8.report,
                    fine: d12.report
                ),
                evidence.crossCanonicalGatePassed,
                d8.eligibleForSelection && d12.eligibleForSelection
            )
        }
        let bestScore = rawAssessments.filter { $0.3 }
            .map { $0.1.score }.min() ?? .infinity
        let assessments = rawAssessments.map { raw in
            let penalty = bestScore.isFinite && bestScore > 1e-30
                ? max(0, raw.1.score / bestScore - 1)
                : 0
            let selectionEligible = raw.3 && raw.2
                && penalty
                    <= preregistration.maximumCrossCanonicalTrendPenalty
            return MetalIndexedBirdSurfaceCollisionGridAssessment(
                collisionOperator: raw.0.rawValue,
                d8ToD12IntervalForceNormalizedRMSDifference:
                    raw.1.intervalForceNormalizedRMSDifference,
                d8ToD12MeanForceRelativeDifference:
                    raw.1.meanForceRelativeDifference,
                d8ToD12ImpulseRelativeDifference:
                    raw.1.impulseRelativeDifference,
                d8ToD12PeakTimeDifferenceSeconds:
                    raw.1.peakTimeDifferenceSeconds,
                gridTrendScore: raw.1.score,
                crossCanonicalGatePassed: raw.2,
                crossCanonicalTrendPenalty: penalty,
                eligibleAtBothGrids: raw.3,
                selectionEligible: selectionEligible
            )
        }
        let selectable = assessments.filter(\.selectionEligible)
        let selected = selectable.count == 1
            ? selectable[0].collisionOperator : nil
        let allCompleted = cases.count == 4 && cases.allSatisfy {
            $0.report.completedFluidSteps == $0.report.plan.totalFluidSteps
        }
        let d8Difference = operatorDifference(cases: cases, cells: 8)
        let d12Difference = operatorDifference(cases: cases, cells: 12)
        let passed = allCompleted && selected != nil
        return MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            preregistration: preregistration,
            cases: cases,
            assessments: assessments,
            d8OperatorPairwiseNormalizedRMSDifference: d8Difference,
            d12OperatorPairwiseNormalizedRMSDifference: d12Difference,
            selectedCollisionOperator: selected,
            d16CompletionAuthorized: passed,
            allDiscriminatorRunsCompleted: allCompleted,
            screeningGatePassed: passed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: passed
                ? (
                    "The preregistered D=8/D=12 discriminator selected "
                        + selected! + " and authorizes exactly one D=16 "
                        + "completion run."
                )
                : (
                    "The preregistered D=8/D=12 discriminator did not "
                        + "produce exactly one cross-canonically consistent "
                        + "candidate inside the locked trend penalty. No "
                        + "D=16 run is authorized."
                ),
            claimBoundary: (
                "This gate selects collision physics for one D=16 engineering "
                    + "completion allocation only. It does not use measured-"
                    + "force error, establish spatial convergence, or claim "
                    + "experimental agreement."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridCompletion(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport
    ) throws -> MetalIndexedBirdSurfaceCollisionGridCompletionReport {
        let expected = try collisionGridPreregistration(
            surface: surface,
            target: target
        )
        guard preregistration == expected,
              discriminator.preregistration == preregistration,
              discriminator.screeningGatePassed,
              discriminator.d16CompletionAuthorized,
              let selected = discriminator.selectedCollisionOperator,
              let collisionOperator =
                MetalIndexedBirdSurfaceCollisionOperator(rawValue: selected),
              collisionOperator != .productionTRT,
              let d12 = discriminator.cases.first(where: {
                $0.referenceLengthCells == 12
                    && $0.collisionOperator == selected
              }) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D=16 completion is not authorized by the locked discriminator"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let d16 = try runCollisionGridCase(
            backend: backend,
            surface: surface,
            target: target,
            collisionOperator: collisionOperator,
            referenceLengthCells:
                preregistration.completionReferenceLengthCells
        )
        let trend = try? collisionGridTrend(
            coarse: d12.report,
            fine: d16.report
        )
        let fineLimit = 0.05
        let convergencePassed = trend.map {
            $0.intervalForceNormalizedRMSDifference <= fineLimit
                && $0.meanForceRelativeDifference <= fineLimit
                && $0.impulseRelativeDifference <= fineLimit
        } ?? false
        let completed = d16.eligibleForSelection
        return MetalIndexedBirdSurfaceCollisionGridCompletionReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            selectedCollisionOperator: selected,
            discriminatorReferenceLengthCells:
                preregistration.discriminatorReferenceLengthCells,
            completionReferenceLengthCells:
                preregistration.completionReferenceLengthCells,
            d16Case: d16,
            d12ToD16IntervalForceNormalizedRMSDifference:
                trend?.intervalForceNormalizedRMSDifference,
            d12ToD16MeanForceRelativeDifference:
                trend?.meanForceRelativeDifference,
            d12ToD16ImpulseRelativeDifference:
                trend?.impulseRelativeDifference,
            d12ToD16PeakTimeDifferenceSeconds:
                trend?.peakTimeDifferenceSeconds,
            maximumAllowedFineGridRelativeDifference: fineLimit,
            fineGridForceConvergencePassed: convergencePassed,
            completionGatePassed: completed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: completed
                ? (convergencePassed
                    ? (
                        "The selected operator completed D=16 and the locked "
                            + "D12-to-D16 five-percent force-history, mean, "
                            + "and impulse gates pass."
                    )
                    : (
                        "The selected operator completed D=16 with positive "
                            + "finite populations, but at least one locked "
                            + "D12-to-D16 five-percent force convergence gate "
                            + "fails."
                    ))
                : (
                    "The selected operator did not complete the authorized "
                        + "D=16 numerical gate."
                ),
            claimBoundary: (
                "This completes only the selected viscosity-floor engineering "
                    + "ladder. Experimental comparison remains disabled at "
                    + "the declared 68.07x viscosity floor, regardless of "
                    + "the spatial trend."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridPopulationStageProvenance(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport,
        completion:
            MetalIndexedBirdSurfaceCollisionGridCompletionReport
    ) throws -> MetalIndexedBirdSurfacePopulationStageProvenanceReport {
        let expected = try collisionGridPreregistration(
            surface: surface,
            target: target
        )
        guard preregistration == expected,
              discriminator.preregistration == preregistration,
              discriminator.screeningGatePassed,
              discriminator.d16CompletionAuthorized,
              let selected = discriminator.selectedCollisionOperator,
              selected == completion.selectedCollisionOperator,
              selected == MetalIndexedBirdSurfaceCollisionOperator
                .positivityPreservingRecursiveRegularizedBGK.rawValue,
              completion.completionReferenceLengthCells
                == preregistration.completionReferenceLengthCells,
              !completion.completionGatePassed,
              completion.d16Case.collisionOperator == selected,
              let failureStep = completion.d16Case.report
                .firstNegativePopulationStep,
              let failureDirection = completion.d16Case.report
                .firstNegativePopulationDirection,
              let failureCoordinate = completion.d16Case.report
                .firstNegativePopulationCellCoordinate,
              failureStep == completion.d16Case.report.completedFluidSteps,
              failureStep > 4,
              (0..<D3Q19.count).contains(failureDirection) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "population provenance requires the locked failed RR3 D=16 completion"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let referenceLengthCells = preregistration
            .completionReferenceLengthCells
        let plan = try refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: referenceLengthCells
        )
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        guard failureCoordinate.x >= 0,
              failureCoordinate.y >= 0,
              failureCoordinate.z >= 0,
              failureCoordinate.x < replay.grid.x,
              failureCoordinate.y < replay.grid.y,
              failureCoordinate.z < replay.grid.z else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "failed D=16 population coordinate is outside the replay grid"
            )
        }
        let targetCell = failureCoordinate.x
            + replay.grid.x * (
                failureCoordinate.y + replay.grid.y * failureCoordinate.z
            )
        guard targetCell == completion.d16Case.report
            .firstNegativePopulationLinearIndex.map({
                $0 % replay.grid.cellCount
            }) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "failed D=16 population coordinate and linear index disagree"
            )
        }
        let capturedSteps = Array((failureStep - 4)...failureStep)
        let capture = try MetalIndexedPopulationStageCapture(
            backend: backend,
            capturedSteps: capturedSteps,
            targetCellLinearIndex: targetCell,
            targetDirection: failureDirection
        )
        let replayReport = try replay.runCoarseForcePilot(
            target: target,
            plan: plan,
            collisionOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            maximumFluidSteps: failureStep,
            populationDiagnosticStride: 1,
            stopAtFirstNegativePopulation: true,
            populationStageCapture: capture
        )
        let rawRecords = capture.readRecords()
        let topologyBranches = [
            "persistent-fluid-reconstruction",
            "newly-uncovered-equilibrium-refill",
            "solid-equilibrium-write",
        ]
        func directions(_ mask: UInt32) -> [Int] {
            (0..<D3Q19.count).filter {
                mask & (UInt32(1) << UInt32($0)) != 0
            }
        }
        func reconstructed(_ raw: GPUIndexedPopulationStageProvenance)
            -> [Double]
        {
            let packed = [
                raw.reconstructed0, raw.reconstructed1,
                raw.reconstructed2, raw.reconstructed3,
                raw.reconstructed4,
            ]
            return packed.flatMap { value in
                [value.x, value.y, value.z, value.w].map(Double.init)
            }.prefix(D3Q19.count).map { $0 }
        }
        let soundSpeed = sqrt(1.0 / 3.0)
        let restPositivitySpeedLimit = sqrt(2.0 / 3.0)
        let samples = rawRecords.map { raw in
            let step = Int(raw.metadata.x)
            let branchIndex = Int(raw.metadata.w)
            let actual = Double(raw.extrema.w)
            let predicted = Double(raw.output.w)
            return MetalIndexedBirdSurfacePopulationStageSample(
                step: step,
                sourceTimeSeconds: Double(surface.frameTimesSeconds[0])
                    + Double(step) * plan.fluidTimeStepSeconds,
                cellCoordinate: failureCoordinate,
                cellLinearIndex: Int(raw.metadata.y),
                direction: Int(raw.metadata.z),
                topologyBranch: topologyBranches.indices.contains(branchIndex)
                    ? topologyBranches[branchIndex] : "unknown",
                wasSolid: raw.state.x != 0,
                isSolid: raw.state.y != 0,
                selectedSourcePartIdentifier: Int(raw.state.z),
                preStepPopulation: Double(raw.preReconstruction.x),
                reconstructedDirectionPopulation:
                    Double(raw.preReconstruction.y),
                reconstructedPopulations: reconstructed(raw),
                minimumReconstructedPopulation: Double(raw.extrema.x),
                farFieldDirections: directions(raw.sourceMasks.x),
                movingBoundaryDirections: directions(raw.sourceMasks.y),
                localFluidDirections: directions(raw.sourceMasks.z),
                nonFiniteReconstructionDirections:
                    directions(raw.sourceMasks.w),
                reconstructedDensity: Double(raw.preReconstruction.z),
                reconstructedVelocityLattice: SIMD3<Double>(
                    Double(raw.macroscopic.x),
                    Double(raw.macroscopic.y),
                    Double(raw.macroscopic.z)
                ),
                reconstructedSpeedLattice: Double(raw.preReconstruction.w),
                reconstructedLatticeMach:
                    Double(raw.preReconstruction.w) / soundSpeed,
                restEquilibriumPositivitySpeedLimit:
                    restPositivitySpeedLimit,
                equilibriumDirectionPopulation: Double(raw.collision.x),
                regularizedNonequilibriumDirectionPopulation:
                    Double(raw.collision.y),
                unboundedPostCollisionDirectionPopulation:
                    Double(raw.collision.z),
                positivityScale: Double(raw.collision.w),
                populationFloor: Double(raw.output.x),
                postCollisionDirectionPopulation: Double(raw.output.y),
                spongeFactor: Double(raw.output.z),
                predictedPostSpongeDirectionPopulation: predicted,
                actualOutputDirectionPopulation: actual,
                predictionAbsoluteError: abs(predicted - actual)
            )
        }
        let predictionTolerance = 1.0e-7
        let maximumPredictionError = samples.map(
            \.predictionAbsoluteError
        ).max() ?? .infinity
        let failureSample = samples.first {
            $0.actualOutputDirectionPopulation < 0
        }
        let negativeStage: String? = failureSample.map { sample in
            if sample.reconstructedDirectionPopulation < 0 {
                return "reconstruction"
            }
            if sample.postCollisionDirectionPopulation < 0 {
                return "post-collision"
            }
            if sample.predictedPostSpongeDirectionPopulation < 0 {
                return "post-sponge"
            }
            return "production-output-unexplained"
        }
        let replayMatchesCompletion = replayReport.completedFluidSteps
                == failureStep
            && replayReport.firstNegativePopulationStep == failureStep
            && replayReport.firstNegativePopulationDirection
                == failureDirection
            && replayReport.firstNegativePopulationCellCoordinate
                == failureCoordinate
        let recordsComplete = samples.map(\.step) == capturedSteps
            && samples.allSatisfy {
                $0.cellLinearIndex == targetCell
                    && $0.direction == failureDirection
                    && $0.nonFiniteReconstructionDirections.isEmpty
                    && $0.predictionAbsoluteError <= predictionTolerance
            }
        let priorCapturedOutputsPositive = samples.dropLast().allSatisfy {
            $0.actualOutputDirectionPopulation > 0
        }
        let gatePassed = replayMatchesCompletion
            && recordsComplete
            && priorCapturedOutputsPositive
            && failureSample?.step == failureStep
            && negativeStage != nil
        let upstreamBoundary = failureSample.map {
            !$0.movingBoundaryDirections.isEmpty
        } ?? false
        let negativeReconstructedDirections = failureSample.map { sample in
            sample.reconstructedPopulations.enumerated().compactMap {
                $0.element < 0 ? $0.offset : nil
            }
        } ?? []
        let negativeBoundaryDirections = failureSample.map { sample in
            negativeReconstructedDirections.filter {
                sample.movingBoundaryDirections.contains($0)
            }
        } ?? []
        let targetBoundary = failureSample.map {
            $0.movingBoundaryDirections.contains(failureDirection)
        } ?? false
        let topologyRefill = failureSample?.topologyBranch
            == "newly-uncovered-equilibrium-refill"
        let farFieldUsed = failureSample.map {
            !$0.farFieldDirections.isEmpty
        } ?? false
        let spongeUsed = (failureSample?.spongeFactor ?? 0) > 0
        let equilibriumPositive = (
            failureSample?.equilibriumDirectionPopulation ?? -.infinity
        ) > 0
        let verdict: String
        if negativeStage == "post-collision" && !equilibriumPositive {
            verdict = (
                "Moving-boundary reconstruction already produces negative "
                    + "incoming directions "
                    + String(describing: negativeBoundaryDirections)
                    + ", while selected direction 0 remains positive. RR3 "
                    + "then first writes direction 0 negative at "
                    + "collision because the reconstructed local speed makes "
                    + "the direction-0 equilibrium itself negative. A zero "
                    + "positivity scale returns that inadmissible equilibrium; "
                    + "topology refill, far field, and sponge are not the "
                    + "target-direction writer."
            )
        } else {
            verdict = (
                "The sparse production-parity capture classified the first "
                    + "negative selected population at stage "
                    + (negativeStage ?? "unresolved") + "."
            )
        }
        return MetalIndexedBirdSurfacePopulationStageProvenanceReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            selectedCollisionOperator: selected,
            referenceLengthCells: referenceLengthCells,
            targetCellCoordinate: failureCoordinate,
            targetCellLinearIndex: targetCell,
            targetDirection: failureDirection,
            capturedSteps: capturedSteps,
            diagnosticKernelSequence: [
                "captureIndexedPopulationStageProvenanceBeforeStep",
                "stepFluidTRT (production, unmodified)",
                "captureIndexedPopulationStageProvenanceAfterStep",
            ],
            productionStateModifiedByDiagnostic: false,
            maximumAllowedPredictionAbsoluteError: predictionTolerance,
            maximumPredictionAbsoluteError: maximumPredictionError,
            replayFirstNegativePopulationStep:
                replayReport.firstNegativePopulationStep,
            replayFirstNegativePopulationDirection:
                replayReport.firstNegativePopulationDirection,
            replayFirstNegativePopulationCellCoordinate:
                replayReport.firstNegativePopulationCellCoordinate,
            firstNegativeCapturedStage: negativeStage,
            firstNegativeCapturedStep: failureSample?.step,
            selectedDirectionRemainedPositiveThroughReconstructionAtFailure:
                (failureSample?.reconstructedDirectionPopulation ?? -.infinity)
                    > 0,
            negativeReconstructedDirectionsAtFailure:
                negativeReconstructedDirections,
            negativeMovingBoundaryReconstructedDirectionsAtFailure:
                negativeBoundaryDirections,
            upstreamMovingBoundaryReconstructionPresentAtFailure:
                upstreamBoundary,
            targetDirectionMovingBoundaryReconstructedAtFailure:
                targetBoundary,
            topologyRefillAtFailure: topologyRefill,
            farFieldUsedAtFailure: farFieldUsed,
            spongeUsedAtFailure: spongeUsed,
            equilibriumReferencePositiveAtFailure: equilibriumPositive,
            provenanceGatePassed: gatePassed,
            experimentalAgreementGateApplied: false,
            samples: samples,
            scientificVerdict: verdict,
            claimBoundary: (
                "This diagnostic identifies the first writer of the retained "
                    + "D=16 numerical failure. It does not prove that upstream "
                    + "moving-boundary inputs are physically correct, repair "
                    + "the operator, authorize another refinement run, or "
                    + "establish experimental agreement."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridBoundaryTermDecomposition(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport,
        completion:
            MetalIndexedBirdSurfaceCollisionGridCompletionReport,
        provenance:
            MetalIndexedBirdSurfacePopulationStageProvenanceReport
    ) throws -> MetalIndexedBirdSurfaceBoundaryTermDecompositionReport {
        let expected = try collisionGridPreregistration(
            surface: surface,
            target: target
        )
        guard preregistration == expected,
              discriminator.preregistration == preregistration,
              discriminator.screeningGatePassed,
              discriminator.d16CompletionAuthorized,
              let selected = discriminator.selectedCollisionOperator,
              selected == completion.selectedCollisionOperator,
              selected == provenance.selectedCollisionOperator,
              selected == MetalIndexedBirdSurfaceCollisionOperator
                .positivityPreservingRecursiveRegularizedBGK.rawValue,
              !completion.completionGatePassed,
              provenance.provenanceGatePassed,
              !provenance.productionStateModifiedByDiagnostic,
              provenance.referenceLengthCells
                == preregistration.completionReferenceLengthCells,
              let failureStep = completion.d16Case.report
                .firstNegativePopulationStep,
              provenance.firstNegativeCapturedStep == failureStep,
              provenance.firstNegativeCapturedStage == "post-collision",
              provenance.targetCellCoordinate
                == completion.d16Case.report
                    .firstNegativePopulationCellCoordinate,
              provenance.targetDirection == 0,
              failureStep > 1 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "boundary decomposition requires the locked D=16 provenance"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let referenceLengthCells = preregistration
            .completionReferenceLengthCells
        let plan = try refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: referenceLengthCells
        )
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let targetCoordinate = provenance.targetCellCoordinate
        guard targetCoordinate.x >= 0,
              targetCoordinate.y >= 0,
              targetCoordinate.z >= 0,
              targetCoordinate.x < replay.grid.x,
              targetCoordinate.y < replay.grid.y,
              targetCoordinate.z < replay.grid.z else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "boundary decomposition target lies outside D=16"
            )
        }
        let targetCell = targetCoordinate.x
            + replay.grid.x * (
                targetCoordinate.y + replay.grid.y * targetCoordinate.z
            )
        let capturedSteps = [failureStep - 1, failureStep]
        guard capturedSteps.allSatisfy({ step in
            provenance.samples.contains { $0.step == step }
        }) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "boundary decomposition steps are absent from provenance"
            )
        }
        let capture = try MetalIndexedBoundaryTermCapture(
            backend: backend,
            capturedSteps: capturedSteps,
            targetCellLinearIndex: targetCell
        )
        let replayReport = try replay.runCoarseForcePilot(
            target: target,
            plan: plan,
            collisionOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            maximumFluidSteps: failureStep,
            populationDiagnosticStride: 1,
            stopAtFirstNegativePopulation: true,
            boundaryTermCapture: capture
        )
        let rawRecords = capture.readRecords()
        func coordinate(_ index: UInt32) -> SIMD3<Int>? {
            guard index != UInt32.max else { return nil }
            let value = Int(index)
            guard value >= 0, value < replay.grid.cellCount else { return nil }
            return SIMD3<Int>(
                value % replay.grid.x,
                (value / replay.grid.x) % replay.grid.y,
                value / (replay.grid.x * replay.grid.y)
            )
        }
        let stageByStep = Dictionary(uniqueKeysWithValues:
            provenance.samples.map { ($0.step, $0) }
        )
        var maximumReconstructionDifference = 0.0
        var maximumClosureResidual = 0.0
        var samples: [MetalIndexedBirdSurfaceBoundaryTermSample] = []
        for (sampleIndex, step) in capturedSteps.enumerated() {
            guard let stage = stageByStep[step] else { continue }
            for direction in 0..<D3Q19.count {
                let raw = rawRecords[sampleIndex][direction]
                let reconstructed = Double(raw.contributions.w)
                maximumReconstructionDifference = max(
                    maximumReconstructionDifference,
                    abs(reconstructed
                        - stage.reconstructedPopulations[direction])
                )
                guard raw.branch.z != 0 else { continue }
                let branchCode = Int(raw.branch.x)
                let branch: String
                let auxiliaryRole: String
                switch branchCode {
                case 1:
                    branch = "halfway-fallback"
                    auxiliaryRole = "none"
                case 2:
                    branch = "interpolated-near-wall"
                    auxiliaryRole = "farther-fluid-outgoing"
                case 3:
                    branch = "interpolated-far-wall"
                    auxiliaryRole = "previous-target-incoming"
                default:
                    branch = "unknown-boundary-branch"
                    auxiliaryRole = "unknown"
                }
                let contributionSum = Double(raw.contributions.x)
                    + Double(raw.contributions.y)
                    + Double(raw.contributions.z)
                let closure = reconstructed - contributionSum
                maximumClosureResidual = max(
                    maximumClosureResidual,
                    abs(closure)
                )
                let contributions = [
                    ("reflected", Double(raw.contributions.x)),
                    ("auxiliary", Double(raw.contributions.y)),
                    ("wall-correction", Double(raw.contributions.z)),
                ]
                let dominantNegative = contributions.min {
                    $0.1 < $1.1
                }.map { $0.1 < 0 ? $0.0 : "none" } ?? "none"
                samples.append(MetalIndexedBirdSurfaceBoundaryTermSample(
                    step: step,
                    sourceTimeSeconds:
                        Double(surface.frameTimesSeconds[0])
                            + Double(step) * plan.fluidTimeStepSeconds,
                    targetCellCoordinate: targetCoordinate,
                    direction: direction,
                    sourceCellCoordinate: coordinate(raw.metadata.y),
                    sourcePartIdentifier: Int(raw.metadata.w),
                    branch: branch,
                    linkFraction: Double(raw.primitive.y),
                    reflectedPopulation: Double(raw.primitive.x),
                    auxiliaryPopulation: Double(raw.primitive.z),
                    auxiliaryCellCoordinate: coordinate(raw.metadata.z),
                    auxiliaryRole: auxiliaryRole,
                    rawWallCorrection: Double(raw.primitive.w),
                    halfwayWallCorrection:
                        Double(raw.counterfactuals.x),
                    productionWallDirectionProjectionLattice:
                        Double(raw.alternatives.y),
                    sourceWallDirectionProjectionLattice:
                        Double(raw.alternatives.z),
                    reflectedContribution:
                        Double(raw.contributions.x),
                    auxiliaryContribution:
                        Double(raw.contributions.y),
                    wallCorrectionContribution:
                        Double(raw.contributions.z),
                    productionReconstructedPopulation: reconstructed,
                    contributionClosureResidual: closure,
                    halfwayMovingWallPopulation:
                        Double(raw.counterfactuals.y),
                    interpolatedZeroWallPopulation:
                        Double(raw.counterfactuals.z),
                    halfwayZeroWallPopulation:
                        Double(raw.counterfactuals.w),
                    interpolatedNoAuxiliaryPopulation:
                        Double(raw.alternatives.x),
                    productionPopulationNegative: reconstructed < 0,
                    dominantNegativeContribution: dominantNegative
                ))
            }
        }
        let failureSamples = samples.filter { $0.step == failureStep }
        let previousNegativeDirections = samples.filter {
            $0.step == capturedSteps[0] && $0.productionPopulationNegative
        }.map(\.direction).sorted()
        let negative = failureSamples.filter(\.productionPopulationNegative)
        let negativeDirections = negative.map(\.direction).sorted()
        func directions(where predicate:
            (MetalIndexedBirdSurfaceBoundaryTermSample) -> Bool
        ) -> [Int] {
            negative.filter(predicate).map(\.direction).sorted()
        }
        let negativeReflected = directions { $0.reflectedPopulation < 0 }
        let negativeAuxiliary = directions { $0.auxiliaryContribution < 0 }
        let negativeWall = directions { $0.wallCorrectionContribution < 0 }
        let halfwayMoving = directions {
            $0.halfwayMovingWallPopulation >= 0
        }
        let zeroWall = directions {
            $0.interpolatedZeroWallPopulation >= 0
        }
        let halfwayZero = directions {
            $0.halfwayZeroWallPopulation >= 0
        }
        let noAuxiliary = directions {
            $0.interpolatedNoAuxiliaryPopulation >= 0
        }
        let remainingHalfwayZero = directions {
            $0.halfwayZeroWallPopulation < 0
        }
        let dominantRepairTarget: String
        if !remainingHalfwayZero.isEmpty {
            dominantRepairTarget = "inherited-reflected-population"
        } else if Set(halfwayMoving) == Set(negativeDirections) {
            dominantRepairTarget = "interpolated-boundary-branch"
        } else if Set(zeroWall) == Set(negativeDirections) {
            dominantRepairTarget = "moving-wall-correction"
        } else if Set(noAuxiliary) == Set(negativeDirections) {
            dominantRepairTarget = "interpolation-auxiliary-term"
        } else {
            dominantRepairTarget = "mixed-boundary-terms"
        }
        let tolerance = 1.0e-7
        let replayMatches = replayReport.completedFluidSteps == failureStep
            && replayReport.firstNegativePopulationStep == failureStep
            && replayReport.firstNegativePopulationDirection == 0
            && replayReport.firstNegativePopulationCellCoordinate
                == targetCoordinate
        let allFinite = samples.allSatisfy { sample in
            [
                sample.linkFraction,
                sample.reflectedPopulation,
                sample.auxiliaryPopulation,
                sample.rawWallCorrection,
                sample.halfwayWallCorrection,
                sample.productionWallDirectionProjectionLattice,
                sample.sourceWallDirectionProjectionLattice,
                sample.reflectedContribution,
                sample.auxiliaryContribution,
                sample.wallCorrectionContribution,
                sample.productionReconstructedPopulation,
                sample.contributionClosureResidual,
                sample.halfwayMovingWallPopulation,
                sample.interpolatedZeroWallPopulation,
                sample.halfwayZeroWallPopulation,
                sample.interpolatedNoAuxiliaryPopulation,
            ].allSatisfy(\.isFinite)
        }
        let passed = replayMatches
            && maximumReconstructionDifference <= tolerance
            && maximumClosureResidual <= tolerance
            && negativeDirections
                == provenance
                    .negativeMovingBoundaryReconstructedDirectionsAtFailure
            && !negativeDirections.isEmpty
            && allFinite
            && samples.filter({ $0.step == capturedSteps[0] }).count
                == failureSamples.count
        return MetalIndexedBirdSurfaceBoundaryTermDecompositionReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            selectedCollisionOperator: selected,
            referenceLengthCells: referenceLengthCells,
            targetCellCoordinate: targetCoordinate,
            capturedSteps: capturedSteps,
            diagnosticKernel: "captureIndexedBoundaryTermDecomposition",
            productionStateModifiedByDiagnostic: false,
            maximumAllowedAbsoluteResidual: tolerance,
            maximumContributionClosureResidual: maximumClosureResidual,
            maximumReconstructionDifferenceFromStageArtifact:
                maximumReconstructionDifference,
            negativeMovingBoundaryDirectionsPreviousStep:
                previousNegativeDirections,
            negativeMovingBoundaryDirectionsAtFailure: negativeDirections,
            directionsWithNegativeReflectedPopulation: negativeReflected,
            directionsWithNegativeAuxiliaryContribution: negativeAuxiliary,
            directionsWithNegativeWallContribution: negativeWall,
            directionsMadeNonnegativeByHalfwayMovingWall: halfwayMoving,
            directionsMadeNonnegativeByInterpolatedZeroWall: zeroWall,
            directionsMadeNonnegativeByHalfwayZeroWall: halfwayZero,
            directionsMadeNonnegativeByRemovingAuxiliary: noAuxiliary,
            directionsRemainingNegativeUnderHalfwayZeroWall:
                remainingHalfwayZero,
            dominantRepairTarget: dominantRepairTarget,
            boundaryTermGatePassed: passed,
            experimentalAgreementGateApplied: false,
            samples: samples,
            scientificVerdict: (
                "The negative moving-boundary direction set changes from "
                    + String(describing: previousNegativeDirections)
                    + " to " + String(describing: negativeDirections)
                    + " at the retained failure. All terms close with "
                    + "production parity. The locked counterfactuals "
                    + "identify " + dominantRepairTarget
                    + " as the first repair surface; no counterfactual is "
                    + "enabled in production."
            ),
            claimBoundary: (
                "This sparse diagnostic attributes algebraic contributions "
                    + "at one retained failure cell. It does not prove a "
                    + "counterfactual boundary law is physically correct, "
                    + "modify collision or boundary production state, "
                    + "authorize refinement, or establish experimental "
                    + "agreement."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallAdmissibilityAB(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport,
        completion:
            MetalIndexedBirdSurfaceCollisionGridCompletionReport,
        provenance:
            MetalIndexedBirdSurfacePopulationStageProvenanceReport,
        boundaryTerms:
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport
    ) throws -> MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport {
        let expected = try collisionGridPreregistration(
            surface: surface,
            target: target
        )
        guard preregistration == expected,
              discriminator.preregistration == preregistration,
              discriminator.screeningGatePassed,
              discriminator.d16CompletionAuthorized,
              let selected = discriminator.selectedCollisionOperator,
              selected == completion.selectedCollisionOperator,
              selected == provenance.selectedCollisionOperator,
              selected == boundaryTerms.selectedCollisionOperator,
              selected == MetalIndexedBirdSurfaceCollisionOperator
                .positivityPreservingRecursiveRegularizedBGK.rawValue,
              !completion.completionGatePassed,
              provenance.provenanceGatePassed,
              boundaryTerms.boundaryTermGatePassed,
              boundaryTerms.dominantRepairTarget == "moving-wall-correction",
              !provenance.productionStateModifiedByDiagnostic,
              !boundaryTerms.productionStateModifiedByDiagnostic,
              boundaryTerms.referenceLengthCells
                == preregistration.completionReferenceLengthCells,
              provenance.referenceLengthCells
                == boundaryTerms.referenceLengthCells,
              provenance.targetCellCoordinate
                == boundaryTerms.targetCellCoordinate,
              let failureStep = completion.d16Case.report
                .firstNegativePopulationStep,
              provenance.firstNegativeCapturedStep == failureStep,
              boundaryTerms.capturedSteps.last == failureStep,
              let stage = provenance.samples.first(where: {
                  $0.step == failureStep
              }),
              stage.reconstructedPopulations.count == D3Q19.count else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall A/B requires the locked D=16 boundary evidence"
            )
        }
        let boundarySamples = boundaryTerms.samples.filter {
            $0.step == failureStep
        }
        guard !boundarySamples.isEmpty,
              Set(boundarySamples.map(\.direction)).count
                == boundarySamples.count,
              boundarySamples.map(\.direction).sorted()
                == stage.movingBoundaryDirections.sorted() else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall A/B boundary direction coverage is incomplete"
            )
        }

        var preStepPopulations = Array<Double?>(
            repeating: nil,
            count: D3Q19.count
        )
        preStepPopulations[provenance.targetDirection] = stage.preStepPopulation
        for sample in boundarySamples {
            preStepPopulations[D3Q19.opposite[sample.direction]] =
                sample.reflectedPopulation
            if sample.auxiliaryRole == "previous-target-incoming" {
                preStepPopulations[sample.direction] =
                    sample.auxiliaryPopulation
            }
        }
        let coverage = preStepPopulations.indices.filter {
            preStepPopulations[$0] != nil
        }
        guard coverage.count == D3Q19.count else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall A/B cannot reconstruct all pre-step populations"
            )
        }
        let preStep = preStepPopulations.map { $0! }
        let preStepDensity = preStep.reduce(0, +)

        var wallContributions = Array(
            repeating: 0.0,
            count: D3Q19.count
        )
        for sample in boundarySamples {
            wallContributions[sample.direction] =
                sample.wallCorrectionContribution
        }
        let referencePopulations = stage.reconstructedPopulations
        let basePopulations = referencePopulations.indices.map {
            referencePopulations[$0] - wallContributions[$0]
        }
        let referenceDensity = 1.0
        let populationFloor = stage.populationFloor
        let baseDensity = basePopulations.reduce(0, +)
        let referenceWallMass = wallContributions.reduce(0, +)
        let selfConsistentDenominator = 1.0
            - referenceWallMass / referenceDensity
        guard referenceDensity > 0,
              populationFloor >= 0,
              preStepDensity > 0,
              baseDensity > 0,
              selfConsistentDenominator > 0 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall A/B densities are not admissible"
            )
        }
        let selfConsistentDensity = baseDensity
            / selfConsistentDenominator
        let localDensityScale = preStepDensity / referenceDensity
        let selfConsistentScale = selfConsistentDensity / referenceDensity
        var positivityScale = 1.0
        for direction in 0..<D3Q19.count
        where wallContributions[direction] < 0 {
            positivityScale = min(
                positivityScale,
                (basePopulations[direction] - populationFloor)
                    / -wallContributions[direction]
            )
        }
        positivityScale = max(0, min(1, positivityScale))

        func populations(scale: Double) -> [Double] {
            basePopulations.indices.map {
                basePopulations[$0] + scale * wallContributions[$0]
            }
        }
        let localDensityPopulations = populations(scale: localDensityScale)
        let selfConsistentPopulations = populations(
            scale: selfConsistentScale
        )
        let positivityPopulations = populations(scale: positivityScale)
        let tolerance = 1.0e-12

        func summary(
            identifier: String,
            scale: Double,
            values: [Double],
            positivityInterventionActive: Bool
        ) -> MetalIndexedBirdSurfaceMovingWallCandidateSummary {
            let density = values.reduce(0, +)
            var momentum = SIMD3<Double>.zero
            for direction in 0..<D3Q19.count {
                let raw = D3Q19.directions[direction]
                momentum += SIMD3<Double>(
                    Double(raw.x),
                    Double(raw.y),
                    Double(raw.z)
                ) * values[direction]
            }
            let velocity = density > 0 ? momentum / density : .zero
            let speed = sqrt(
                velocity.x * velocity.x
                    + velocity.y * velocity.y
                    + velocity.z * velocity.z
            )
            let mach = speed / Double(D3Q19.soundSpeed)
            var equilibrium = [Double]()
            equilibrium.reserveCapacity(D3Q19.count)
            let speedSquared = speed * speed
            for direction in 0..<D3Q19.count {
                let raw = D3Q19.directions[direction]
                let lattice = SIMD3<Double>(
                    Double(raw.x),
                    Double(raw.y),
                    Double(raw.z)
                )
                let projection = lattice.x * velocity.x
                    + lattice.y * velocity.y
                    + lattice.z * velocity.z
                equilibrium.append(
                    Double(D3Q19.weights[direction]) * density
                        * (1.0 + 3.0 * projection
                            + 4.5 * projection * projection
                            - 1.5 * speedSquared)
                )
            }
            var wallMomentum = SIMD3<Double>.zero
            for direction in 0..<D3Q19.count {
                let raw = D3Q19.directions[direction]
                wallMomentum += SIMD3<Double>(
                    Double(raw.x),
                    Double(raw.y),
                    Double(raw.z)
                ) * (scale * wallContributions[direction])
            }
            let negative = values.indices.filter { values[$0] < 0 }
            let floorViolations = values.indices.filter {
                values[$0] < populationFloor - tolerance
            }
            let allFinite = values.allSatisfy(\.isFinite)
                && equilibrium.allSatisfy(\.isFinite)
                && density.isFinite && speed.isFinite
            let minimumPopulation = values.min() ?? -.infinity
            let minimumEquilibrium = equilibrium.min() ?? -.infinity
            return MetalIndexedBirdSurfaceMovingWallCandidateSummary(
                identifier: identifier,
                correctionScaleRelativeToReferenceDensity: scale,
                positivityInterventionActive: positivityInterventionActive,
                reconstructedDensity: density,
                reconstructedMomentum: momentum,
                reconstructedVelocity: velocity,
                reconstructedSpeed: speed,
                reconstructedLatticeMach: mach,
                minimumPopulation: minimumPopulation,
                minimumEquilibriumPopulation: minimumEquilibrium,
                negativePopulationDirections: negative,
                populationFloorViolationDirections: floorViolations,
                wallMassContribution: scale * referenceWallMass,
                wallMomentumContribution: wallMomentum,
                populationGatePassed: allFinite
                    && floorViolations.isEmpty,
                equilibriumGatePassed: allFinite
                    && minimumEquilibrium >= -tolerance
                    && speed <= stage.restEquilibriumPositivitySpeedLimit
            )
        }

        let reference = summary(
            identifier: "reference-density-production-baseline",
            scale: 1,
            values: referencePopulations,
            positivityInterventionActive: false
        )
        let candidateA = summary(
            identifier: "pre-step-local-density-normalization",
            scale: localDensityScale,
            values: localDensityPopulations,
            positivityInterventionActive: false
        )
        let candidateB = summary(
            identifier: "reference-density-global-positivity-scale",
            scale: positivityScale,
            values: positivityPopulations,
            positivityInterventionActive: positivityScale < 1
        )
        let selfConsistent = summary(
            identifier: "self-consistent-local-density-crosscheck",
            scale: selfConsistentScale,
            values: selfConsistentPopulations,
            positivityInterventionActive: false
        )
        let directionSamples = (0..<D3Q19.count).map { direction in
            MetalIndexedBirdSurfaceMovingWallDirectionABSample(
                direction: direction,
                basePopulationWithoutWallCorrection:
                    basePopulations[direction],
                referenceDensityPopulation:
                    referencePopulations[direction],
                preStepLocalDensityPopulation:
                    localDensityPopulations[direction],
                selfConsistentLocalDensityPopulation:
                    selfConsistentPopulations[direction],
                positivityAdmissiblePopulation:
                    positivityPopulations[direction],
                referenceDensityWallContribution:
                    wallContributions[direction]
            )
        }
        let inputParity = abs(
            reference.reconstructedDensity - stage.reconstructedDensity
        ) <= 1.0e-9
            && reference.negativePopulationDirections
                == provenance.negativeReconstructedDirectionsAtFailure
        let passed = inputParity
            && coverage == Array(0..<D3Q19.count)
            && !reference.populationGatePassed
            && !reference.equilibriumGatePassed
            && candidateA.populationGatePassed
            && candidateA.equilibriumGatePassed
            && candidateB.populationGatePassed
            && candidateB.equilibriumGatePassed
            && selfConsistent.populationGatePassed
            && selfConsistent.equilibriumGatePassed
            && localDensityScale <= positivityScale
            && positivityScale < 1
        let authorized = passed ? candidateA.identifier : nil
        return MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport(
            schemaVersion: 1,
            deviceName: boundaryTerms.deviceName,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            selectedCollisionOperator: selected,
            referenceLengthCells: boundaryTerms.referenceLengthCells,
            targetCellCoordinate: boundaryTerms.targetCellCoordinate,
            failureStep: failureStep,
            sourceBoundaryTermGatePassed:
                boundaryTerms.boundaryTermGatePassed,
            sourcePopulationProvenanceGatePassed:
                provenance.provenanceGatePassed,
            productionStateModifiedByDiagnostic: false,
            fluidSimulationRerun: false,
            referenceDensity: referenceDensity,
            populationFloor: populationFloor,
            preStepPopulationCoverageDirections: coverage,
            preStepLocalDensity: preStepDensity,
            baseDensityWithoutWallCorrection: baseDensity,
            selfConsistentLocalDensity: selfConsistentDensity,
            selfConsistentDensityDenominator: selfConsistentDenominator,
            globalPositivityAdmissibilityScale: positivityScale,
            restEquilibriumPositivitySpeedLimit:
                stage.restEquilibriumPositivitySpeedLimit,
            referenceDensityBaseline: reference,
            candidateA: candidateA,
            candidateB: candidateB,
            selfConsistentDensityCrosscheck: selfConsistent,
            directionSamples: directionSamples,
            candidateAuthorizedForProductionLedger: authorized,
            admissibilityABGatePassed: passed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "Candidate A applies the pre-step local density as one "
                    + "uniform wall-correction scale and restores both "
                    + "population and equilibrium admissibility without a "
                    + "positivity limiter. Candidate B also restores "
                    + "admissibility but requires a worst-link global "
                    + "positivity intervention. Candidate A advances only "
                    + "to a controlled production ledger experiment."
            ),
            claimBoundary: (
                "This archive-only one-cell discriminator does not mutate "
                    + "the production boundary law, rerun fluid dynamics, "
                    + "prove momentum consistency, authorize refinement, "
                    + "or establish experimental agreement. The selected "
                    + "candidate must close the force and fluid-momentum "
                    + "ledgers before any production promotion."
            )
        )
    }

    public static func collisionGridMovingWallLedger(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport,
        completion:
            MetalIndexedBirdSurfaceCollisionGridCompletionReport,
        provenance:
            MetalIndexedBirdSurfacePopulationStageProvenanceReport,
        boundaryTerms:
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport,
        admissibility:
            MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport
    ) throws -> MetalIndexedBirdSurfaceMovingWallLedgerReport {
        let expectedAdmissibility = try collisionGridMovingWallAdmissibilityAB(
            surface: surface,
            target: target,
            preregistration: preregistration,
            discriminator: discriminator,
            completion: completion,
            provenance: provenance,
            boundaryTerms: boundaryTerms
        )
        let candidateIdentifier =
            "pre-step-local-density-normalization"
        guard admissibility.datasetIdentifier == surface.datasetIdentifier,
              admissibility.manifestSHA256 == surface.manifestSHA256,
              admissibility.forceTargetIdentifier == target.datasetIdentifier,
              admissibility.forceTargetSHA256 == target.targetSHA256,
              admissibility.selectedCollisionOperator
                == expectedAdmissibility.selectedCollisionOperator,
              admissibility.referenceLengthCells
                == preregistration.completionReferenceLengthCells,
              admissibility.failureStep
                == expectedAdmissibility.failureStep,
              admissibility.admissibilityABGatePassed,
              expectedAdmissibility.admissibilityABGatePassed,
              admissibility.candidateAuthorizedForProductionLedger
                == candidateIdentifier,
              expectedAdmissibility.candidateAuthorizedForProductionLedger
                == candidateIdentifier,
              admissibility.candidateA.identifier == candidateIdentifier,
              !admissibility.candidateA.positivityInterventionActive,
              let collisionOperator =
                MetalIndexedBirdSurfaceCollisionOperator(
                    rawValue: admissibility.selectedCollisionOperator
                ),
              collisionOperator
                == .positivityPreservingRecursiveRegularizedBGK else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall ledger requires the authorized candidate-A D=16 evidence"
            )
        }
        let referenceLengthCells =
            preregistration.completionReferenceLengthCells
        let requestedSteps = admissibility.failureStep
        let plan = try refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: referenceLengthCells
        )
        guard requestedSteps > 0,
              requestedSteps <= plan.preRollFluidSteps,
              completion.d16Case.report.firstNegativePopulationStep
                == requestedSteps else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall ledger horizon does not match the retained D=16 failure"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let result = try replay.runCollisionMomentumClosure(
            plan: plan,
            collisionOperator: collisionOperator,
            maximumRelativeRMSResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            requestedSteps: requestedSteps,
            movingWallNormalization: .preStepLocalDensity
        )
        let metadata = replay.collisionMomentumControlVolumeMetadata
        let allStepsCompleted = result.completedSteps == requestedSteps
            && result.samples.count == requestedSteps
        let populationPassed = result.allValuesFinite
            && result.sampledPopulationPositivityPassed
            && result.minimumPopulation > 0
        let accountingPassed =
            result.maximumSolidControlSurfaceCrossingLinkCount == 0
            && result.relativeRMSRawControlVolumeClosureResidual
                <= collisionMomentumMaximumRelativeRMSResidual
            && result.relativeRMSGlobalFluidClosureResidual
                <= collisionMomentumMaximumRelativeRMSResidual
        let collisionCorrectionPassed =
            result.collisionLimiterActivationFractionOfCellSteps
                <= collisionPreRollMaximumActivationFraction
            && result.maximumCollisionRestriction.isFinite
        let passed = admissibility.admissibilityABGatePassed
            && allStepsCompleted && populationPassed && accountingPassed
            && collisionCorrectionPassed && result.momentumClosurePassed
            && metadata.minimumDomainDistanceCells
                >= plan.spongeWidthCells
            && metadata.minimumSweptSurfaceDistanceCells > 0
        return MetalIndexedBirdSurfaceMovingWallLedgerReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceAdmissibilityCandidateIdentifier: candidateIdentifier,
            sourceAdmissibilityGatePassed:
                admissibility.admissibilityABGatePassed,
            selectedCollisionOperator: collisionOperator.rawValue,
            movingWallNormalization:
                MetalIndexedBirdSurfaceMovingWallNormalization
                    .preStepLocalDensity.rawValue,
            referenceLengthCells: referenceLengthCells,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            requestedSteps: requestedSteps,
            plan: plan,
            controlVolume: metadata.bounds,
            spongeWidthCells: plan.spongeWidthCells,
            minimumControlSurfaceDistanceFromDomainBoundaryCells:
                metadata.minimumDomainDistanceCells,
            minimumControlSurfaceDistanceFromSweptSurfaceCells:
                metadata.minimumSweptSurfaceDistanceCells,
            maximumAllowedRelativeRMSClosureResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumAllowedCollisionCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            movingWallPositivityLimiterImplemented: false,
            movingWallPositivityLimiterActivationCount: 0,
            productionDefaultModified: false,
            result: result,
            allStepsCompleted: allStepsCompleted,
            populationPositivityPassed: populationPassed,
            forceAndMomentumAccountingPassed: accountingPassed,
            collisionCorrectionIntrusionPassed:
                collisionCorrectionPassed,
            ledgerGatePassed: passed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: passed
                ? (
                    "Candidate A completed the retained D=16 failure horizon "
                        + "with positive finite populations and closed both "
                        + "the near-wing and global force/momentum ledgers. "
                        + "It advances only to the full registered D=16 window."
                )
                : (
                    "Candidate A failed at least one retained D=16 positivity, "
                        + "force-accounting, momentum-closure, or collision-"
                        + "intrusion gate and is rejected before a full run."
                ),
            claimBoundary: (
                "This opt-in validation replay changes only the moving-wall "
                    + "density normalization and stops at the historical "
                    + "failure horizon. It does not modify the production "
                    + "default, authorize refinement, apply an experimental-"
                    + "agreement gate, or establish free-flight validity."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallFullWindow(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport,
        completion:
            MetalIndexedBirdSurfaceCollisionGridCompletionReport,
        provenance:
            MetalIndexedBirdSurfacePopulationStageProvenanceReport,
        boundaryTerms:
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport,
        admissibility:
            MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport,
        retainedLedger:
            MetalIndexedBirdSurfaceMovingWallLedgerReport,
        referenceLengthCells requestedReferenceLengthCells: Int? = nil
    ) throws -> MetalIndexedBirdSurfaceMovingWallFullWindowReport {
        let expectedAdmissibility = try collisionGridMovingWallAdmissibilityAB(
            surface: surface,
            target: target,
            preregistration: preregistration,
            discriminator: discriminator,
            completion: completion,
            provenance: provenance,
            boundaryTerms: boundaryTerms
        )
        let candidateIdentifier =
            "pre-step-local-density-normalization"
        guard expectedAdmissibility.admissibilityABGatePassed,
              admissibility.admissibilityABGatePassed,
              admissibility.candidateAuthorizedForProductionLedger
                == candidateIdentifier,
              retainedLedger.datasetIdentifier == surface.datasetIdentifier,
              retainedLedger.manifestSHA256 == surface.manifestSHA256,
              retainedLedger.forceTargetIdentifier == target.datasetIdentifier,
              retainedLedger.forceTargetSHA256 == target.targetSHA256,
              retainedLedger.sourceAdmissibilityCandidateIdentifier
                == candidateIdentifier,
              retainedLedger.sourceAdmissibilityGatePassed,
              retainedLedger.selectedCollisionOperator
                == admissibility.selectedCollisionOperator,
              retainedLedger.movingWallNormalization
                == MetalIndexedBirdSurfaceMovingWallNormalization
                    .preStepLocalDensity.rawValue,
              retainedLedger.referenceLengthCells
                == preregistration.completionReferenceLengthCells,
              retainedLedger.requestedSteps == admissibility.failureStep,
              retainedLedger.result.completedSteps
                == retainedLedger.requestedSteps,
              retainedLedger.ledgerGatePassed,
              retainedLedger.populationPositivityPassed,
              retainedLedger.forceAndMomentumAccountingPassed,
              retainedLedger.collisionCorrectionIntrusionPassed,
              !retainedLedger.movingWallPositivityLimiterImplemented,
              retainedLedger.movingWallPositivityLimiterActivationCount == 0,
              !retainedLedger.productionDefaultModified,
              !retainedLedger.experimentalAgreementGateApplied,
              let collisionOperator =
                MetalIndexedBirdSurfaceCollisionOperator(
                    rawValue: retainedLedger.selectedCollisionOperator
                ),
              collisionOperator
                == .positivityPreservingRecursiveRegularizedBGK else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "full moving-wall window requires the passed retained candidate-A ledger"
            )
        }
        let referenceLengthCells = requestedReferenceLengthCells
            ?? preregistration.completionReferenceLengthCells
        guard requestedReferenceLengthCells == nil
                || [8, 12].contains(referenceLengthCells) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall spatial cases support only D=8 or D=12"
            )
        }
        let plan = try refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: referenceLengthCells
        )
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let result = try replay.runCollisionMomentumClosure(
            plan: plan,
            collisionOperator: collisionOperator,
            maximumRelativeRMSResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            requestedSteps: plan.totalFluidSteps,
            movingWallNormalization: .preStepLocalDensity
        )
        let metadata = replay.collisionMomentumControlVolumeMetadata
        var forceSamples =
            [MetalIndexedBirdSurfaceMovingWallFullWindowForceSample]()
        forceSamples.reserveCapacity(target.comparisonSampleCount)
        if result.samples.count >= plan.fluidStepsPerForceSample {
            for targetIndex in target.comparisonFirstSampleIndex...target.comparisonLastSampleIndex {
                let endStep = targetIndex * plan.fluidStepsPerForceSample
                let startIndex = endStep - plan.fluidStepsPerForceSample
                guard endStep <= result.samples.count,
                      startIndex >= 0 else { continue }
                let interval = result.samples[startIndex..<endStep]
                let sum = interval.reduce(SIMD3<Double>.zero) {
                    $0 + $1.aerodynamicForceNewtons
                }
                let mean = sum / Double(plan.fluidStepsPerForceSample)
                let measuredX = target.forceXNewtons[targetIndex]
                let measuredZ = target.forceZNewtons[targetIndex]
                forceSamples.append(
                    MetalIndexedBirdSurfaceMovingWallFullWindowForceSample(
                        targetSampleIndex: targetIndex,
                        sourceTimeSeconds: target.timesSeconds[targetIndex],
                        measuredForceXNewtons: measuredX,
                        measuredForceZNewtons: measuredZ,
                        intervalMeanComputedForceNewtons: mean,
                        residualXNewtons: mean.x - measuredX,
                        residualZNewtons: mean.z - measuredZ
                    )
                )
            }
        }
        let registeredWindowComplete = forceSamples.count
            == target.comparisonSampleCount
        let measuredPairs = forceSamples.map {
            SIMD2<Double>($0.measuredForceXNewtons, $0.measuredForceZNewtons)
        }
        let computedPairs = forceSamples.map {
            SIMD2<Double>(
                $0.intervalMeanComputedForceNewtons.x,
                $0.intervalMeanComputedForceNewtons.z
            )
        }
        let comparisonAvailable = registeredWindowComplete
            && !forceSamples.isEmpty
        let measuredImpulse = comparisonAvailable
            ? pilotTrapezoidalImpulse(
                measuredPairs,
                sampleRateHertz: target.forceSampleRateHertz
            ) : nil
        let computedImpulse = comparisonAvailable
            ? pilotTrapezoidalImpulse(
                computedPairs,
                sampleRateHertz: target.forceSampleRateHertz
            ) : nil
        let measuredPeak = comparisonAvailable
            ? forceSamples.max(by: {
                let lhs = $0.measuredForceXNewtons
                    * $0.measuredForceXNewtons
                    + $0.measuredForceZNewtons
                        * $0.measuredForceZNewtons
                let rhs = $1.measuredForceXNewtons
                    * $1.measuredForceXNewtons
                    + $1.measuredForceZNewtons
                        * $1.measuredForceZNewtons
                return lhs < rhs
            })?.sourceTimeSeconds : nil
        let computedPeak = comparisonAvailable
            ? forceSamples.max(by: {
                let lhs = $0.intervalMeanComputedForceNewtons
                let rhs = $1.intervalMeanComputedForceNewtons
                return lhs.x * lhs.x + lhs.z * lhs.z
                    < rhs.x * rhs.x + rhs.z * rhs.z
            })?.sourceTimeSeconds : nil
        let allStepsCompleted = result.completedSteps == plan.totalFluidSteps
            && result.samples.count == plan.totalFluidSteps
        let populationPassed = result.allValuesFinite
            && result.sampledPopulationPositivityPassed
            && result.minimumPopulation > 0
        let accountingPassed =
            result.maximumSolidControlSurfaceCrossingLinkCount == 0
            && result.relativeRMSRawControlVolumeClosureResidual
                <= collisionMomentumMaximumRelativeRMSResidual
            && result.relativeRMSGlobalFluidClosureResidual
                <= collisionMomentumMaximumRelativeRMSResidual
        let collisionCorrectionPassed =
            result.collisionLimiterActivationFractionOfCellSteps
                <= collisionPreRollMaximumActivationFraction
            && result.maximumCollisionRestriction.isFinite
        let passed = retainedLedger.ledgerGatePassed
            && allStepsCompleted && populationPassed && accountingPassed
            && collisionCorrectionPassed && registeredWindowComplete
            && result.momentumClosurePassed
            && metadata.minimumDomainDistanceCells
                >= plan.spongeWidthCells
            && metadata.minimumSweptSurfaceDistanceCells > 0
        return MetalIndexedBirdSurfaceMovingWallFullWindowReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceRetainedLedgerGatePassed: retainedLedger.ledgerGatePassed,
            sourceRetainedLedgerSteps: retainedLedger.requestedSteps,
            sourceCandidateIdentifier: candidateIdentifier,
            selectedCollisionOperator: collisionOperator.rawValue,
            movingWallNormalization:
                MetalIndexedBirdSurfaceMovingWallNormalization
                    .preStepLocalDensity.rawValue,
            referenceLengthCells: referenceLengthCells,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            requestedSteps: plan.totalFluidSteps,
            plan: plan,
            controlVolume: metadata.bounds,
            spongeWidthCells: plan.spongeWidthCells,
            minimumControlSurfaceDistanceFromDomainBoundaryCells:
                metadata.minimumDomainDistanceCells,
            minimumControlSurfaceDistanceFromSweptSurfaceCells:
                metadata.minimumSweptSurfaceDistanceCells,
            maximumAllowedRelativeRMSClosureResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumAllowedCollisionCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            movingWallPositivityLimiterImplemented: false,
            movingWallPositivityLimiterActivationCount: 0,
            productionDefaultModified: false,
            ledgerResult: result,
            registeredForceSamples: forceSamples,
            registeredComparisonSampleCount: forceSamples.count,
            measuredMeanForceXNewtons: comparisonAvailable
                ? pilotMean(forceSamples.map(\.measuredForceXNewtons)) : nil,
            measuredMeanForceZNewtons: comparisonAvailable
                ? pilotMean(forceSamples.map(\.measuredForceZNewtons)) : nil,
            computedMeanForceXNewtons: comparisonAvailable
                ? pilotMean(forceSamples.map {
                    $0.intervalMeanComputedForceNewtons.x
                }) : nil,
            computedMeanForceZNewtons: comparisonAvailable
                ? pilotMean(forceSamples.map {
                    $0.intervalMeanComputedForceNewtons.z
                }) : nil,
            normalizedRMSError: comparisonAvailable
                ? pilotNormalizedRMSError(
                    measured: measuredPairs,
                    computed: computedPairs
                ) : nil,
            measuredImpulseXNewtonSeconds: measuredImpulse?.x,
            measuredImpulseZNewtonSeconds: measuredImpulse?.y,
            computedImpulseXNewtonSeconds: computedImpulse?.x,
            computedImpulseZNewtonSeconds: computedImpulse?.y,
            measuredPeakTimeSeconds: measuredPeak,
            computedPeakTimeSeconds: computedPeak,
            allStepsCompleted: allStepsCompleted,
            populationPositivityPassed: populationPassed,
            forceAndMomentumAccountingPassed: accountingPassed,
            collisionCorrectionIntrusionPassed:
                collisionCorrectionPassed,
            registeredWindowComplete: registeredWindowComplete,
            fullWindowGatePassed: passed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: passed
                ? (
                    "Candidate A completed the full registered D="
                        + String(referenceLengthCells) + " window "
                        + "with positive finite populations, complete force "
                        + "sampling, and closed near-wing/global momentum "
                        + "ledgers. This case can enter only the locked "
                        + "candidate-A spatial refinement discriminator."
                )
                : (
                    "Candidate A failed at least one full-window positivity, "
                        + "force-sampling, momentum-closure, or collision-"
                        + "intrusion gate and is rejected before refinement."
                ),
            claimBoundary: (
                "The force comparison is descriptive because the locked "
                    + "engineering condition remains 68.07x over-viscous. "
                    + "This opt-in result does not modify production, pass "
                    + "spatial refinement, establish experimental agreement, "
                    + "or validate free flight."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallTemporalSamplingPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        spatialDiscriminator:
            MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport,
        sourceSpatialDiscriminatorSHA256: String,
        sourceLagBandSHA256: String
    ) throws
        -> MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration
    {
        let spatialSHA = sourceSpatialDiscriminatorSHA256.lowercased()
        let lagBandSHA = sourceLagBandSHA256.lowercased()
        let validHashes = [spatialSHA, lagBandSHA].allSatisfy {
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }
        let frozenSampleIndex = 53
        let frozenTime = 0.0265
        let forceBinDuration = 1.0 / target.forceSampleRateHertz
        let plans = try [12, 16].map {
            try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: $0
            )
        }
        guard validHashes,
              spatialDiscriminator.datasetIdentifier
                == surface.datasetIdentifier,
              spatialDiscriminator.manifestSHA256 == surface.manifestSHA256,
              spatialDiscriminator.forceTargetIdentifier
                == target.datasetIdentifier,
              spatialDiscriminator.forceTargetSHA256 == target.targetSHA256,
              spatialDiscriminator.referenceLengthCells == [8, 12, 16],
              spatialDiscriminator.allCaseGatesPassed,
              spatialDiscriminator.monotonicTrendReductionPassed,
              !spatialDiscriminator.fineGridForceConvergencePassed,
              !spatialDiscriminator.spatialRefinementGatePassed,
              !spatialDiscriminator.productionPromotionAuthorized,
              !spatialDiscriminator.experimentalAgreementGateApplied,
              target.timesSeconds.indices.contains(frozenSampleIndex),
              abs(target.timesSeconds[frozenSampleIndex] - frozenTime)
                <= 1e-12,
              plans.map(\.fluidStepsPerForceSample) == [24, 32],
              plans.allSatisfy({
                  abs(Double($0.fluidStepsPerForceSample)
                    * $0.fluidTimeStepSeconds - forceBinDuration) <= 1e-12
              }) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "temporal-sampling preregistration requires the rejected locked D12/D16 spatial endpoint"
            )
        }
        return MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceSpatialDiscriminatorSHA256: spatialSHA,
            sourceLagBandSHA256: lagBandSHA,
            selectedCollisionOperator:
                spatialDiscriminator.selectedCollisionOperator,
            movingWallNormalization:
                spatialDiscriminator.movingWallNormalization,
            referenceLengthCells: [12, 16],
            frozenSourceSampleIndex: frozenSampleIndex,
            frozenSourceTimeSeconds: frozenTime,
            forceBinDurationSeconds: forceBinDuration,
            forceBinCount: 8,
            maximumAllowedRelativeRMSClosureResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumAllowedCollisionCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            maximumAllowedTopologyCorrectionNewtons: 1e-10,
            maximumAllowedImpulseIdentityRelativeError: 1e-12,
            maximumAllowedFineGridRelativeDifference: 0.05,
            minimumAggregationImprovementFraction: 0.20,
            maximumAggregationRelativeSpreadFraction: 0.10,
            selectionRule: (
                "At source sample 53 (26.5 ms), hold measured geometry and "
                    + "deposited wall velocity fixed for eight 0.5 ms bins on "
                    + "D12 and D16. Capture conservative force every fluid "
                    + "step and compare endpoint, sample-centered trapezoidal, "
                    + "and direct impulse-preserving bin means. Call temporal "
                    + "aggregation sensitive only when the direct-impulse "
                    + "history is at most 5% different, the endpoint history "
                    + "is over 5% different, and the improvement is at least "
                    + "20%. Call grid response aggregation-invariant only when "
                    + "all three differences exceed 5% and their relative "
                    + "spread is at most 10%."
            ),
            fixedInputs: (
                "Recursive regularized BGK; candidate-A pre-step local-density "
                    + "moving-wall normalization; source sample 53; fixed "
                    + "geometry and wall velocity; equilibrium fluid start; "
                    + "D12/D16 physical grids, thickness, viscosity-floor, "
                    + "far field, sponge, force estimator, and momentum ledgers."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This nonphysical treadmilling-surface canonical isolates "
                    + "temporal force aggregation from topology and evolving "
                    + "measured kinematics. It cannot pass the raw spatial "
                    + "gate, establish aerodynamic agreement, authorize D20, "
                    + "or modify production defaults."
            )
        )
    }

    public static func collisionGridMovingWallTemporalSampling(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        spatialDiscriminator:
            MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport,
        sourceSpatialDiscriminatorSHA256: String,
        sourceLagBandSHA256: String,
        temporalPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration,
        sourceTemporalPreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport {
        try runCollisionGridMovingWallTemporalSampling(
            surface: surface,
            target: target,
            spatialDiscriminator: spatialDiscriminator,
            sourceSpatialDiscriminatorSHA256:
                sourceSpatialDiscriminatorSHA256,
            sourceLagBandSHA256: sourceLagBandSHA256,
            temporalPreregistration: temporalPreregistration,
            sourceTemporalPreregistrationSHA256:
                sourceTemporalPreregistrationSHA256,
            forceBinCount: temporalPreregistration.forceBinCount
        )
    }

    private static func runCollisionGridMovingWallTemporalSampling(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        spatialDiscriminator:
            MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport,
        sourceSpatialDiscriminatorSHA256: String,
        sourceLagBandSHA256: String,
        temporalPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration,
        sourceTemporalPreregistrationSHA256: String,
        forceBinCount: Int
    ) throws -> MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport {
        let expected = try collisionGridMovingWallTemporalSamplingPreregistration(
            surface: surface,
            target: target,
            spatialDiscriminator: spatialDiscriminator,
            sourceSpatialDiscriminatorSHA256:
                sourceSpatialDiscriminatorSHA256,
            sourceLagBandSHA256: sourceLagBandSHA256
        )
        let temporalSHA = sourceTemporalPreregistrationSHA256.lowercased()
        guard temporalPreregistration == expected,
              temporalPreregistration.passed,
              temporalSHA.count == 64,
              temporalSHA.allSatisfy(\.isHexDigit),
              let collisionOperator =
                MetalIndexedBirdSurfaceCollisionOperator(
                    rawValue: temporalPreregistration
                        .selectedCollisionOperator
                ),
              collisionOperator
                == .positivityPreservingRecursiveRegularizedBGK,
              temporalPreregistration.movingWallNormalization
                == MetalIndexedBirdSurfaceMovingWallNormalization
                    .preStepLocalDensity.rawValue,
              [temporalPreregistration.forceBinCount, 24]
                .contains(forceBinCount) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "temporal-sampling run does not match its locked preregistration"
            )
        }
#if canImport(Metal)
        func runCase(_ referenceLengthCells: Int) throws
            -> MetalIndexedBirdSurfaceMovingWallTemporalSamplingCaseReport
        {
            let plan = try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: referenceLengthCells
            )
            let requestedSteps = plan.fluidStepsPerForceSample
                * forceBinCount
            let backend = try MetalBackend(fastMath: false)
            let replay = try MetalIndexedBirdSurfaceReplay(
                backend: backend,
                dataset: surface,
                cellSizeMeters: Float(plan.cellSizeMeters),
                halfThicknessCells: Float(plan.halfThicknessCells),
                referenceLengthCells: referenceLengthCells,
                paddingCells: plan.paddingCells,
                physicalAirDensity: sourceAirDensity,
                targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
                latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
                spongeWidthCells: plan.spongeWidthCells,
                spongeStrength: Float(plan.spongeStrength)
            )
            let result = try replay.runCollisionMomentumClosure(
                plan: plan,
                collisionOperator: collisionOperator,
                maximumRelativeRMSResidual: temporalPreregistration
                    .maximumAllowedRelativeRMSClosureResidual,
                maximumCorrectionActivationFraction: temporalPreregistration
                    .maximumAllowedCollisionCorrectionActivationFraction,
                requestedSteps: requestedSteps,
                movingWallNormalization: .preStepLocalDensity,
                fixedSurfaceTimeSeconds:
                    Float(temporalPreregistration.frozenSourceTimeSeconds)
            )
            let dt = plan.fluidTimeStepSeconds
            let binDuration = temporalPreregistration.forceBinDurationSeconds
            var bins =
                [MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin]()
            bins.reserveCapacity(forceBinCount)
            for binIndex in 0..<forceBinCount {
                let start = binIndex * plan.fluidStepsPerForceSample
                let end = start + plan.fluidStepsPerForceSample
                guard end <= result.samples.count else { break }
                let samples = result.samples[start..<end]
                    .map(\.aerodynamicForceNewtons)
                let sum = samples.reduce(SIMD3<Double>.zero, +)
                let directImpulse = sum * dt
                let impulseMean = directImpulse / binDuration
                let trapezoidalSum = samples.dropFirst().dropLast()
                    .reduce(
                        0.5 * samples.first! + 0.5 * samples.last!,
                        +
                    )
                let trapezoidalMean = trapezoidalSum
                    / Double(samples.count - 1)
                let reconstructedImpulse = impulseMean * binDuration
                let identityError = vectorMagnitude(
                    reconstructedImpulse - directImpulse
                ) / max(
                    vectorMagnitude(reconstructedImpulse),
                    vectorMagnitude(directImpulse),
                    1e-30
                )
                bins.append(
                    MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin(
                        binIndex: binIndex,
                        elapsedStartSeconds: Double(binIndex) * binDuration,
                        elapsedEndSeconds: Double(binIndex + 1) * binDuration,
                        substepCount: samples.count,
                        endpointForceNewtons: samples.last!,
                        sampleTrapezoidalMeanForceNewtons: trapezoidalMean,
                        impulsePreservingMeanForceNewtons: impulseMean,
                        directForceImpulseNewtonSeconds: directImpulse,
                        impulseIdentityRelativeError: identityError
                    )
                )
            }
            let directTotal = result.samples.reduce(SIMD3<Double>.zero) {
                $0 + $1.aerodynamicForceNewtons * dt
            }
            let binnedTotal = bins.reduce(SIMD3<Double>.zero) {
                $0 + $1.directForceImpulseNewtonSeconds
            }
            let maximumIdentityError = bins.map(
                \.impulseIdentityRelativeError
            ).max() ?? .infinity
            let maximumTopologyCorrection = result.samples.map {
                vectorMagnitude($0.topologyReservoirCorrectionNewtons)
            }.max() ?? .infinity
            let topologyPassed = maximumTopologyCorrection
                <= temporalPreregistration
                    .maximumAllowedTopologyCorrectionNewtons
            let impulsePassed = maximumIdentityError
                    <= temporalPreregistration
                        .maximumAllowedImpulseIdentityRelativeError
                && vectorMagnitude(directTotal - binnedTotal)
                    <= temporalPreregistration
                        .maximumAllowedImpulseIdentityRelativeError
                    * max(
                        vectorMagnitude(directTotal),
                        vectorMagnitude(binnedTotal),
                        1e-30
                    )
            let numericalPassed = result.momentumClosurePassed
                && result.completedSteps == requestedSteps
                && result.samples.count == requestedSteps
                && bins.count == forceBinCount
                && topologyPassed && impulsePassed
            return MetalIndexedBirdSurfaceMovingWallTemporalSamplingCaseReport(
                schemaVersion: 1,
                deviceName: backend.device.name,
                datasetIdentifier: surface.datasetIdentifier,
                manifestSHA256: surface.manifestSHA256,
                forceTargetIdentifier: target.datasetIdentifier,
                forceTargetSHA256: target.targetSHA256,
                sourceTemporalPreregistrationSHA256: temporalSHA,
                referenceLengthCells: referenceLengthCells,
                gridX: replay.grid.x,
                gridY: replay.grid.y,
                gridZ: replay.grid.z,
                frozenSourceSampleIndex:
                    temporalPreregistration.frozenSourceSampleIndex,
                frozenSourceTimeSeconds:
                    temporalPreregistration.frozenSourceTimeSeconds,
                surfaceTimeAdvanceSeconds: 0,
                forceBinDurationSeconds: binDuration,
                forceBinCount: forceBinCount,
                fluidStepsPerForceBin: plan.fluidStepsPerForceSample,
                requestedSteps: requestedSteps,
                selectedCollisionOperator: collisionOperator.rawValue,
                movingWallNormalization:
                    MetalIndexedBirdSurfaceMovingWallNormalization
                        .preStepLocalDensity.rawValue,
                ledgerResult: result,
                bins: bins,
                directTotalForceImpulseNewtonSeconds: directTotal,
                binnedTotalForceImpulseNewtonSeconds: binnedTotal,
                maximumImpulseIdentityRelativeError: maximumIdentityError,
                maximumTopologyCorrectionNewtons: maximumTopologyCorrection,
                fixedGeometryTopologyGatePassed: topologyPassed,
                impulseIdentityGatePassed: impulsePassed,
                numericalCaseGatePassed: numericalPassed,
                productionDefaultModified: false,
                experimentalAgreementGateApplied: false,
                claimBoundary: temporalPreregistration.claimBoundary
            )
        }
        let d12 = try runCase(12)
        let d16 = try runCase(16)
        guard d12.numericalCaseGatePassed,
              d16.numericalCaseGatePassed,
              d12.bins.count == d16.bins.count,
              let endpointDifference = pilotPairwiseNormalizedRMSDifference(
                first: d12.bins.map(\.endpointForceNewtons),
                second: d16.bins.map(\.endpointForceNewtons)
              ),
              let trapezoidalDifference =
                pilotPairwiseNormalizedRMSDifference(
                    first: d12.bins.map(
                        \.sampleTrapezoidalMeanForceNewtons
                    ),
                    second: d16.bins.map(
                        \.sampleTrapezoidalMeanForceNewtons
                    )
                ),
              let impulseDifference = pilotPairwiseNormalizedRMSDifference(
                first: d12.bins.map(
                    \.impulsePreservingMeanForceNewtons
                ),
                second: d16.bins.map(
                    \.impulsePreservingMeanForceNewtons
                )
              ) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "temporal-sampling cases failed their numerical contract"
            )
        }
        let estimatorDifferences = [
            endpointDifference, trapezoidalDifference, impulseDifference
        ]
        let maximumEstimatorDifference = estimatorDifferences.max()!
        let minimumEstimatorDifference = estimatorDifferences.min()!
        let spread = (maximumEstimatorDifference - minimumEstimatorDifference)
            / max(maximumEstimatorDifference, 1e-30)
        let improvement = 1.0
            - impulseDifference / max(endpointDifference, 1e-30)
        func relativeDifference(
            _ first: SIMD3<Double>,
            _ second: SIMD3<Double>
        ) -> Double {
            vectorMagnitude(first - second)
                / max(
                    vectorMagnitude(first),
                    vectorMagnitude(second),
                    1e-30
                )
        }
        let totalImpulseDifference = relativeDifference(
            d12.directTotalForceImpulseNewtonSeconds,
            d16.directTotalForceImpulseNewtonSeconds
        )
        let limit = temporalPreregistration
            .maximumAllowedFineGridRelativeDifference
        let aggregationSensitive = impulseDifference <= limit
            && endpointDifference > limit
            && improvement >= temporalPreregistration
                .minimumAggregationImprovementFraction
        let fixedGeometryCleared = estimatorDifferences.allSatisfy {
            $0 <= limit
        }
        let invariantDisagreement = estimatorDifferences.allSatisfy {
            $0 > limit
        } && spread <= temporalPreregistration
            .maximumAggregationRelativeSpreadFraction
        let classification = aggregationSensitive
            ? "temporal-aggregation-sensitive"
            : fixedGeometryCleared
                ? "fixed-geometry-grid-cleared"
                : invariantDisagreement
                    ? "aggregation-invariant-grid-disagreement"
                    : "mixed-unresolved"
        let nextAction: String
        switch classification {
        case "temporal-aggregation-sensitive":
            nextAction = (
                "Audit registered-bin endpoint semantics against the direct "
                    + "impulse-preserving estimator before another grid run."
            )
        case "fixed-geometry-grid-cleared":
            nextAction = (
                "Run a two-phase frozen-flow discriminator to separate "
                    + "evolving-vortex resolution from phase-specific wall geometry."
            )
        case "aggregation-invariant-grid-disagreement":
            nextAction = (
                "Isolate D12/D16 wall representation at the same frozen phase "
                    + "before any D20 allocation."
            )
        default:
            nextAction = (
                "Extend only the frozen-phase bin count or add one locked phase; "
                    + "D20 remains blocked."
            )
        }
        let metrics = MetalIndexedBirdSurfaceMovingWallTemporalSamplingMetrics(
            endpointPairwiseNormalizedRMSDifference: endpointDifference,
            sampleTrapezoidalPairwiseNormalizedRMSDifference:
                trapezoidalDifference,
            impulsePreservingPairwiseNormalizedRMSDifference:
                impulseDifference,
            endpointToImpulseImprovementFraction: improvement,
            aggregationRelativeSpreadFraction: spread,
            directTotalImpulseRelativeDifference: totalImpulseDifference
        )
        return MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceTemporalPreregistrationSHA256: temporalSHA,
            sourceSpatialDiscriminatorSHA256:
                expected.sourceSpatialDiscriminatorSHA256,
            sourceLagBandSHA256: expected.sourceLagBandSHA256,
            d12: d12,
            d16: d16,
            metrics: metrics,
            temporalAggregationSensitivityLikely: aggregationSensitive,
            fixedGeometryGridResponseCleared: fixedGeometryCleared,
            aggregationInvariantGridDisagreementLikely:
                invariantDisagreement,
            classification: classification,
            d20DiagnosticAuthorized: false,
            rawSpatialGateModified: false,
            productionPromotionAuthorized: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The fixed-geometry D12/D16 temporal-sampling classification "
                    + "is " + classification + ". The raw 6.268% moving-window "
                    + "spatial rejection remains unchanged."
            ),
            nextAction: nextAction,
            claimBoundary: temporalPreregistration.claimBoundary
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallTemporalDurationPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        temporalPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration,
        sourceTemporalPreregistrationSHA256: String,
        temporalSampling:
            MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport,
        sourceTemporalSamplingSHA256: String
    ) throws
        -> MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration
    {
        let preregistrationSHA = sourceTemporalPreregistrationSHA256
            .lowercased()
        let samplingSHA = sourceTemporalSamplingSHA256.lowercased()
        let validHashes = [preregistrationSHA, samplingSHA].allSatisfy {
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }
        guard validHashes,
              temporalPreregistration.passed,
              temporalPreregistration.datasetIdentifier
                == surface.datasetIdentifier,
              temporalPreregistration.manifestSHA256
                == surface.manifestSHA256,
              temporalPreregistration.forceTargetIdentifier
                == target.datasetIdentifier,
              temporalPreregistration.forceTargetSHA256
                == target.targetSHA256,
              temporalPreregistration.forceBinCount == 8,
              temporalSampling.datasetIdentifier == surface.datasetIdentifier,
              temporalSampling.manifestSHA256 == surface.manifestSHA256,
              temporalSampling.forceTargetIdentifier
                == target.datasetIdentifier,
              temporalSampling.forceTargetSHA256 == target.targetSHA256,
              temporalSampling.sourceTemporalPreregistrationSHA256
                == preregistrationSHA,
              temporalSampling.d12.numericalCaseGatePassed,
              temporalSampling.d16.numericalCaseGatePassed,
              temporalSampling.d12.forceBinCount == 8,
              temporalSampling.d16.forceBinCount == 8,
              temporalSampling.classification == "mixed-unresolved",
              !temporalSampling.d20DiagnosticAuthorized,
              !temporalSampling.rawSpatialGateModified,
              !temporalSampling.productionPromotionAuthorized else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "duration extension requires the locked mixed eight-bin temporal result"
            )
        }
        return MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceTemporalPreregistrationSHA256: preregistrationSHA,
            sourceTemporalSamplingSHA256: samplingSHA,
            selectedCollisionOperator:
                temporalPreregistration.selectedCollisionOperator,
            movingWallNormalization:
                temporalPreregistration.movingWallNormalization,
            referenceLengthCells: [12, 16],
            frozenSourceSampleIndex:
                temporalPreregistration.frozenSourceSampleIndex,
            frozenSourceTimeSeconds:
                temporalPreregistration.frozenSourceTimeSeconds,
            forceBinDurationSeconds:
                temporalPreregistration.forceBinDurationSeconds,
            baselineForceBinCount: 8,
            extendedForceBinCount: 24,
            nestedPrefixBinCounts: [8, 16, 24],
            blockBinCount: 8,
            maximumAllowedPrefixReproductionRelativeError: 1e-12,
            maximumAllowedFineGridRelativeDifference: 0.05,
            minimumLateBlockImprovementFraction: 0.20,
            selectionRule: (
                "Independently restart the exact fixed phase and extend D12/D16 "
                    + "from 8 to 24 force bins. Require the first eight endpoint, "
                    + "sample-trapezoidal, impulse-mean, and direct-impulse "
                    + "vectors to reproduce within 1e-12 relative error. Report "
                    + "8/16/24-bin prefixes and three non-overlapping eight-bin "
                    + "blocks. Duration clears only when the 24-bin impulse-history "
                    + "and cumulative-impulse differences are both at most 5%. "
                    + "Startup relaxation requires the late block at most 5%, at "
                    + "least 20% improvement from the first block, and cumulative "
                    + "24-bin impulse at most 5%. Persistent bias requires all "
                    + "three block histories above 5% with less than 20% late-block "
                    + "improvement."
            ),
            fixedInputs: (
                "The hashed eight-bin preregistration and result; source sample "
                    + "53 at 26.5 ms; fixed geometry and wall velocity; independent "
                    + "equilibrium restarts; D12/D16 grids; RR3 collision; candidate-A "
                    + "wall normalization; unchanged thickness, viscosity-floor, "
                    + "far field, sponge, estimator, and momentum ledgers."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This duration discriminator is a fixed-wall startup diagnostic. "
                    + "It cannot alter the raw moving-window spatial gate, establish "
                    + "experimental agreement, authorize D20, or modify production."
            )
        )
    }

    public static func collisionGridMovingWallTemporalDuration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        spatialDiscriminator:
            MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport,
        sourceSpatialDiscriminatorSHA256: String,
        sourceLagBandSHA256: String,
        temporalPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration,
        sourceTemporalPreregistrationSHA256: String,
        temporalSampling:
            MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport,
        sourceTemporalSamplingSHA256: String,
        durationPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration,
        sourceDurationPreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceMovingWallTemporalDurationReport {
        let expected = try collisionGridMovingWallTemporalDurationPreregistration(
            surface: surface,
            target: target,
            temporalPreregistration: temporalPreregistration,
            sourceTemporalPreregistrationSHA256:
                sourceTemporalPreregistrationSHA256,
            temporalSampling: temporalSampling,
            sourceTemporalSamplingSHA256: sourceTemporalSamplingSHA256
        )
        let durationSHA = sourceDurationPreregistrationSHA256.lowercased()
        guard durationPreregistration == expected,
              durationPreregistration.passed,
              durationSHA.count == 64,
              durationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "temporal duration run does not match its locked preregistration"
            )
        }
        let extended = try runCollisionGridMovingWallTemporalSampling(
            surface: surface,
            target: target,
            spatialDiscriminator: spatialDiscriminator,
            sourceSpatialDiscriminatorSHA256:
                sourceSpatialDiscriminatorSHA256,
            sourceLagBandSHA256: sourceLagBandSHA256,
            temporalPreregistration: temporalPreregistration,
            sourceTemporalPreregistrationSHA256:
                sourceTemporalPreregistrationSHA256,
            forceBinCount: durationPreregistration.extendedForceBinCount
        )
        guard extended.d12.numericalCaseGatePassed,
              extended.d16.numericalCaseGatePassed,
              extended.d12.bins.count
                == durationPreregistration.extendedForceBinCount,
              extended.d16.bins.count
                == durationPreregistration.extendedForceBinCount else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "temporal duration extension failed its numerical cases"
            )
        }
        func relativeDifference(
            _ first: SIMD3<Double>,
            _ second: SIMD3<Double>
        ) -> Double {
            vectorMagnitude(first - second)
                / max(
                    vectorMagnitude(first),
                    vectorMagnitude(second),
                    1e-30
                )
        }
        func metrics(
            d12: ArraySlice<MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin>,
            d16: ArraySlice<MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin>
        ) throws -> MetalIndexedBirdSurfaceMovingWallTemporalSamplingMetrics {
            guard d12.count == d16.count,
                  !d12.isEmpty,
                  let endpoint = pilotPairwiseNormalizedRMSDifference(
                    first: d12.map(\.endpointForceNewtons),
                    second: d16.map(\.endpointForceNewtons)
                  ),
                  let trapezoidal = pilotPairwiseNormalizedRMSDifference(
                    first: d12.map(\.sampleTrapezoidalMeanForceNewtons),
                    second: d16.map(\.sampleTrapezoidalMeanForceNewtons)
                  ),
                  let impulse = pilotPairwiseNormalizedRMSDifference(
                    first: d12.map(\.impulsePreservingMeanForceNewtons),
                    second: d16.map(\.impulsePreservingMeanForceNewtons)
                  ) else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "temporal duration metric window is invalid"
                )
            }
            let values = [endpoint, trapezoidal, impulse]
            let maximum = values.max()!
            let minimum = values.min()!
            let d12Impulse = d12.reduce(SIMD3<Double>.zero) {
                $0 + $1.directForceImpulseNewtonSeconds
            }
            let d16Impulse = d16.reduce(SIMD3<Double>.zero) {
                $0 + $1.directForceImpulseNewtonSeconds
            }
            return MetalIndexedBirdSurfaceMovingWallTemporalSamplingMetrics(
                endpointPairwiseNormalizedRMSDifference: endpoint,
                sampleTrapezoidalPairwiseNormalizedRMSDifference:
                    trapezoidal,
                impulsePreservingPairwiseNormalizedRMSDifference: impulse,
                endpointToImpulseImprovementFraction:
                    1.0 - impulse / max(endpoint, 1e-30),
                aggregationRelativeSpreadFraction:
                    (maximum - minimum) / max(maximum, 1e-30),
                directTotalImpulseRelativeDifference: relativeDifference(
                    d12Impulse, d16Impulse
                )
            )
        }
        var prefixWindows =
            [MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow]()
        for count in durationPreregistration.nestedPrefixBinCounts {
            prefixWindows.append(
                MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow(
                    identifier: "prefix-\(count)",
                    startBin: 0,
                    endBinExclusive: count,
                    metrics: try metrics(
                        d12: extended.d12.bins[0..<count],
                        d16: extended.d16.bins[0..<count]
                    )
                )
            )
        }
        var blockWindows =
            [MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow]()
        for start in stride(
            from: 0,
            to: durationPreregistration.extendedForceBinCount,
            by: durationPreregistration.blockBinCount
        ) {
            let end = start + durationPreregistration.blockBinCount
            blockWindows.append(
                MetalIndexedBirdSurfaceMovingWallTemporalDurationWindow(
                    identifier: "block-\(start)-\(end)",
                    startBin: start,
                    endBinExclusive: end,
                    metrics: try metrics(
                        d12: extended.d12.bins[start..<end],
                        d16: extended.d16.bins[start..<end]
                    )
                )
            )
        }
        func binDifference(
            _ first: MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin,
            _ second: MetalIndexedBirdSurfaceMovingWallTemporalSamplingBin
        ) -> Double {
            [
                relativeDifference(
                    first.endpointForceNewtons,
                    second.endpointForceNewtons
                ),
                relativeDifference(
                    first.sampleTrapezoidalMeanForceNewtons,
                    second.sampleTrapezoidalMeanForceNewtons
                ),
                relativeDifference(
                    first.impulsePreservingMeanForceNewtons,
                    second.impulsePreservingMeanForceNewtons
                ),
                relativeDifference(
                    first.directForceImpulseNewtonSeconds,
                    second.directForceImpulseNewtonSeconds
                ),
            ].max()!
        }
        var prefixReproductionError = 0.0
        for index in 0..<durationPreregistration.baselineForceBinCount {
            prefixReproductionError = max(
                prefixReproductionError,
                binDifference(
                    temporalSampling.d12.bins[index],
                    extended.d12.bins[index]
                ),
                binDifference(
                    temporalSampling.d16.bins[index],
                    extended.d16.bins[index]
                )
            )
        }
        let prefixReproduced = prefixReproductionError
            <= durationPreregistration
                .maximumAllowedPrefixReproductionRelativeError
        let firstBlock = blockWindows.first!.metrics
            .impulsePreservingPairwiseNormalizedRMSDifference
        let lateBlock = blockWindows.last!.metrics
            .impulsePreservingPairwiseNormalizedRMSDifference
        let lateImprovement = 1.0 - lateBlock / max(firstBlock, 1e-30)
        let finalPrefix = prefixWindows.last!.metrics
        let limit = durationPreregistration
            .maximumAllowedFineGridRelativeDifference
        let durationCleared = prefixReproduced
            && finalPrefix.impulsePreservingPairwiseNormalizedRMSDifference
                <= limit
            && finalPrefix.directTotalImpulseRelativeDifference <= limit
        let startupRelaxation = prefixReproduced && !durationCleared
            && firstBlock > limit && lateBlock <= limit
            && lateImprovement >= durationPreregistration
                .minimumLateBlockImprovementFraction
            && finalPrefix.directTotalImpulseRelativeDifference <= limit
        let persistentBias = prefixReproduced && !durationCleared
            && !startupRelaxation
            && blockWindows.allSatisfy {
                $0.metrics.impulsePreservingPairwiseNormalizedRMSDifference
                    > limit
            }
            && lateImprovement < durationPreregistration
                .minimumLateBlockImprovementFraction
        let classification = !prefixReproduced
            ? "invalid-prefix-reproduction"
            : durationCleared
                ? "duration-cleared"
                : startupRelaxation
                    ? "startup-relaxation"
                    : persistentBias
                        ? "persistent-fixed-wall-grid-disagreement"
                        : "mixed-unresolved"
        let nextAction: String
        switch classification {
        case "duration-cleared":
            nextAction = (
                "Add one preregistered frozen phase before reconsidering evolving-flow allocation."
            )
        case "startup-relaxation":
            nextAction = (
                "Audit fixed-wall startup/pre-roll semantics against the full moving-window pre-roll."
            )
        case "persistent-fixed-wall-grid-disagreement":
            nextAction = (
                "Isolate D12/D16 wall representation at the same phase; keep D20 blocked."
            )
        default:
            nextAction = (
                "Keep D20 blocked and add one preregistered phase only if prefix reproduction passed."
            )
        }
        return MetalIndexedBirdSurfaceMovingWallTemporalDurationReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceDurationPreregistrationSHA256: durationSHA,
            sourceTemporalSamplingSHA256:
                durationPreregistration.sourceTemporalSamplingSHA256,
            extendedSampling: extended,
            prefixWindows: prefixWindows,
            blockWindows: blockWindows,
            baselinePrefixMaximumRelativeError: prefixReproductionError,
            baselinePrefixReproduced: prefixReproduced,
            lateBlockImprovementFraction: lateImprovement,
            durationCleared: durationCleared,
            startupRelaxationLikely: startupRelaxation,
            persistentFixedWallGridDisagreementLikely: persistentBias,
            classification: classification,
            d20DiagnosticAuthorized: false,
            rawSpatialGateModified: false,
            productionPromotionAuthorized: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The 24-bin fixed-wall duration classification is "
                    + classification + ". The raw moving-window rejection "
                    + "and D20 block remain unchanged."
            ),
            nextAction: nextAction,
            claimBoundary: durationPreregistration.claimBoundary
        )
    }

    public static func collisionGridMovingWallLinkGeometryPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        durationPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration,
        sourceDurationPreregistrationSHA256: String,
        durationReport:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationReport,
        sourceDurationReportSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkGeometryPreregistration {
        let durationPreregistrationSHA =
            sourceDurationPreregistrationSHA256.lowercased()
        let durationReportSHA = sourceDurationReportSHA256.lowercased()
        let hashes = [durationPreregistrationSHA, durationReportSHA]
        guard hashes.allSatisfy({
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }),
        durationPreregistration.datasetIdentifier == surface.datasetIdentifier,
        durationPreregistration.manifestSHA256 == surface.manifestSHA256,
        durationPreregistration.forceTargetIdentifier == target.datasetIdentifier,
        durationPreregistration.forceTargetSHA256 == target.targetSHA256,
        durationPreregistration.referenceLengthCells == [12, 16],
        durationPreregistration.frozenSourceSampleIndex == 53,
        abs(durationPreregistration.frozenSourceTimeSeconds - 0.0265) <= 1e-12,
        durationReport.datasetIdentifier == surface.datasetIdentifier,
        durationReport.manifestSHA256 == surface.manifestSHA256,
        durationReport.forceTargetIdentifier == target.datasetIdentifier,
        durationReport.forceTargetSHA256 == target.targetSHA256,
        durationReport.sourceDurationPreregistrationSHA256
            == durationPreregistrationSHA,
        durationReport.baselinePrefixReproduced,
        durationReport.persistentFixedWallGridDisagreementLikely,
        durationReport.classification
            == "persistent-fixed-wall-grid-disagreement",
        !durationReport.d20DiagnosticAuthorized,
        !durationReport.rawSpatialGateModified,
        !durationReport.productionPromotionAuthorized else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-geometry preregistration requires the locked persistent fixed-wall D12/D16 result"
            )
        }
        return MetalIndexedBirdSurfaceLinkGeometryPreregistration(
            schemaVersion: 2,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceDurationPreregistrationSHA256:
                durationPreregistrationSHA,
            sourceDurationReportSHA256: durationReportSHA,
            referenceLengthCells: [12, 16],
            frozenSourceSampleIndex: 53,
            frozenSourceTimeSeconds: 0.0265,
            interpolationFractionBinCount: 20,
            maximumAllowedMetalCPUMaskMismatchCells: 0,
            maximumAllowedMetalCPUWallVelocityDifferenceLattice: 5e-5,
            maximumAllowedMetalCPUSignedDistanceDifferenceCells: 2e-5,
            maximumAllowedMetalCPUAggregateRelativeDifference: 0.005,
            maximumAllowedTotalLinkMeasureRelativeDifference: 0.05,
            maximumAllowedComponentLinkMeasureRelativeDifference: 0.10,
            maximumAllowedInterpolationHistogramTotalVariation: 0.10,
            maximumAllowedComponentInterpolationHistogramTotalVariation: 0.15,
            maximumAllowedGridMeanVelocityDifferenceRelativeToQuadratureRMS:
                0.05,
            maximumAllowedGridRMSSpeedRelativeDifference: 0.05,
            maximumAllowedLinkToQuadratureMeanVelocityError: 0.10,
            maximumAllowedLinkToQuadratureRMSSpeedRelativeError: 0.10,
            selectionRule: (
                "At the frozen 26.5 ms surface phase, reconstruct the exact "
                    + "production solid-to-fluid D3Q19 link convention on D12 "
                    + "and D16 without allocating populations or advancing fluid. "
                    + "Measure each link as 6*w_q*dx^2; bin the production "
                    + "d_f/(d_f-d_s) interpolation fraction into 20 fixed bins; "
                    + "and integrate the solid-node deposited wall velocity per "
                    + "component. Require exact Metal/CPU occupancy and link-count "
                    + "parity, pointwise fields within the archived geometry envelope, "
                    + "and every link aggregate within 0.5%. Wall representation "
                    + "clears only when total/component measures, q histograms, "
                    + "D12/D16 wall moments, and both grids versus the independent "
                    + "thickened-triangle D3Q19 quadrature all pass their frozen limits."
            ),
            fixedInputs: (
                "Hashed 24-bin duration preregistration and result; source sample "
                    + "53 at 26.5 ms; D12/D16 refinement plans; physical 7.5 mm "
                    + "half-thickness; production indexed raster, signed-distance "
                    + "link fraction, D3Q19 directions and weights, part identifiers, "
                    + "and solid-node wall-velocity convention. No populations, "
                    + "collision, streaming, force estimator, or topology evolution."
            ),
            contractRevisionRationale: (
                "Revision 2 replaces an unarchived draft 1e-5 pointwise wall-velocity "
                    + "limit that was tighter than the pre-existing indexed-surface "
                    + "Metal/CPU artifact's 2.1819e-5 envelope. It freezes a 5e-5 "
                    + "pointwise guard plus a stricter force-relevant 0.5% bound on "
                    + "every q, histogram, velocity, and speed link aggregate. The "
                    + "D12/D16 scientific limits are unchanged."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This is a geometry/link representation discriminator. It cannot "
                    + "validate the bulk collision response, alter the raw moving-window "
                    + "spatial rejection, establish experimental agreement, authorize "
                    + "D20, or modify production defaults."
            )
        )
    }

    public static func collisionGridMovingWallLinkGeometry(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        durationPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration,
        sourceDurationPreregistrationSHA256: String,
        durationReport:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationReport,
        sourceDurationReportSHA256: String,
        preregistration: MetalIndexedBirdSurfaceLinkGeometryPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkGeometryReport {
#if canImport(Metal)
        let expected = try collisionGridMovingWallLinkGeometryPreregistration(
            surface: surface,
            target: target,
            durationPreregistration: durationPreregistration,
            sourceDurationPreregistrationSHA256:
                sourceDurationPreregistrationSHA256,
            durationReport: durationReport,
            sourceDurationReportSHA256: sourceDurationReportSHA256
        )
        let preregistrationSHA = sourcePreregistrationSHA256.lowercased()
        guard preregistration == expected,
              preregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-geometry run does not match its locked preregistration"
            )
        }
        let backend = try MetalBackend(fastMath: false)
        let quadrature = linkGeometryTriangleQuadrature(
            surface: surface,
            timeSeconds: Float(preregistration.frozenSourceTimeSeconds),
            halfThicknessMeters: refinementBaseHalfThicknessMeters
        )
        let cases = try preregistration.referenceLengthCells.map { cells in
            let plan = try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: cells
            )
            return try linkGeometryCase(
                backend: backend,
                surface: surface,
                plan: plan,
                referenceLengthCells: cells,
                timeSeconds: Float(preregistration.frozenSourceTimeSeconds),
                quadrature: quadrature,
                preregistration: preregistration
            )
        }
        guard cases.count == 2 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-geometry discriminator requires exactly D12 and D16"
            )
        }
        let d12 = cases[0]
        let d16 = cases[1]
        func relativeDifference(_ first: Double, _ second: Double) -> Double {
            abs(first - second) / max(abs(first), abs(second), 1e-30)
        }
        func histogramTV(_ first: [Double], _ second: [Double]) -> Double {
            let firstTotal = first.reduce(0, +)
            let secondTotal = second.reduce(0, +)
            guard first.count == second.count,
                  firstTotal > 0, secondTotal > 0 else { return .infinity }
            return 0.5 * zip(first, second).reduce(0.0) {
                $0 + abs($1.0 / firstTotal - $1.1 / secondTotal)
            }
        }
        func totalMeasure(_ report: MetalIndexedBirdSurfaceLinkGeometryCaseReport)
            -> Double
        {
            report.components.reduce(0) { $0 + $1.linkMeasureSquareMeters }
        }
        func totalHistogram(
            _ report: MetalIndexedBirdSurfaceLinkGeometryCaseReport
        ) -> [Double] {
            var result = [Double](
                repeating: 0,
                count: preregistration.interpolationFractionBinCount
            )
            for component in report.components {
                for index in result.indices {
                    result[index] += component
                        .interpolationFractionMeasureHistogram[index]
                }
            }
            return result
        }
        var maximumComponentMeasureDifference = 0.0
        var maximumComponentHistogramTV = 0.0
        var maximumGridMeanDifference = 0.0
        var maximumGridRMSDifference = 0.0
        var maximumQuadratureMeanError = 0.0
        var maximumQuadratureRMSError = 0.0
        for index in d12.components.indices {
            let first = d12.components[index]
            let second = d16.components[index]
            guard first.partIdentifier == second.partIdentifier else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "D12/D16 link components are not aligned"
                )
            }
            maximumComponentMeasureDifference = max(
                maximumComponentMeasureDifference,
                relativeDifference(
                    first.linkMeasureSquareMeters,
                    second.linkMeasureSquareMeters
                )
            )
            maximumComponentHistogramTV = max(
                maximumComponentHistogramTV,
                histogramTV(
                    first.interpolationFractionMeasureHistogram,
                    second.interpolationFractionMeasureHistogram
                )
            )
            let referenceRMS = max(
                first.triangleQuadrature.rmsWallSpeedMetersPerSecond,
                1e-30
            )
            maximumGridMeanDifference = max(
                maximumGridMeanDifference,
                vectorMagnitude(
                    first.meanWallVelocityMetersPerSecond
                        - second.meanWallVelocityMetersPerSecond
                ) / referenceRMS
            )
            maximumGridRMSDifference = max(
                maximumGridRMSDifference,
                relativeDifference(
                    first.rmsWallSpeedMetersPerSecond,
                    second.rmsWallSpeedMetersPerSecond
                )
            )
            maximumQuadratureMeanError = max(
                maximumQuadratureMeanError,
                first.meanVelocityErrorRelativeToQuadratureRMS,
                second.meanVelocityErrorRelativeToQuadratureRMS
            )
            maximumQuadratureRMSError = max(
                maximumQuadratureRMSError,
                first.rmsSpeedRelativeError,
                second.rmsSpeedRelativeError
            )
        }
        let metrics = MetalIndexedBirdSurfaceLinkGeometryMetrics(
            totalLinkMeasureRelativeDifference: relativeDifference(
                totalMeasure(d12), totalMeasure(d16)
            ),
            maximumComponentLinkMeasureRelativeDifference:
                maximumComponentMeasureDifference,
            interpolationHistogramTotalVariation: histogramTV(
                totalHistogram(d12), totalHistogram(d16)
            ),
            maximumComponentInterpolationHistogramTotalVariation:
                maximumComponentHistogramTV,
            maximumGridMeanVelocityDifferenceRelativeToQuadratureRMS:
                maximumGridMeanDifference,
            maximumGridRMSSpeedRelativeDifference:
                maximumGridRMSDifference,
            maximumLinkToQuadratureMeanVelocityError:
                maximumQuadratureMeanError,
            maximumLinkToQuadratureRMSSpeedRelativeError:
                maximumQuadratureRMSError
        )
        let parityPassed = d12.parityGatePassed && d16.parityGatePassed
        let measureBias = metrics.totalLinkMeasureRelativeDifference
                > preregistration.maximumAllowedTotalLinkMeasureRelativeDifference
            || metrics.maximumComponentLinkMeasureRelativeDifference
                > preregistration.maximumAllowedComponentLinkMeasureRelativeDifference
        let interpolationBias = metrics.interpolationHistogramTotalVariation
                > preregistration.maximumAllowedInterpolationHistogramTotalVariation
            || metrics.maximumComponentInterpolationHistogramTotalVariation
                > preregistration
                    .maximumAllowedComponentInterpolationHistogramTotalVariation
        let velocityBias = metrics
                .maximumGridMeanVelocityDifferenceRelativeToQuadratureRMS
                > preregistration
                    .maximumAllowedGridMeanVelocityDifferenceRelativeToQuadratureRMS
            || metrics.maximumGridRMSSpeedRelativeDifference
                > preregistration.maximumAllowedGridRMSSpeedRelativeDifference
            || metrics.maximumLinkToQuadratureMeanVelocityError
                > preregistration.maximumAllowedLinkToQuadratureMeanVelocityError
            || metrics.maximumLinkToQuadratureRMSSpeedRelativeError
                > preregistration
                    .maximumAllowedLinkToQuadratureRMSSpeedRelativeError
        let cleared = parityPassed && !measureBias && !interpolationBias
            && !velocityBias
        let biasCount = [measureBias, interpolationBias, velocityBias]
            .filter { $0 }.count
        let classification = !parityPassed
            ? "invalid-metal-cpu-geometry-parity"
            : cleared
                ? "wall-representation-cleared"
                : biasCount > 1
                    ? "mixed-wall-representation-bias"
                    : measureBias
                        ? "link-measure-bias"
                        : interpolationBias
                            ? "interpolation-fraction-bias"
                            : "wall-velocity-deposition-bias"
        let nextAction = cleared
            ? "Keep D20 blocked and isolate the D12/D16 bulk fluid-grid response under the same frozen wall with one force-response transfer-function diagnostic."
            : "Keep D20 blocked and correct the failing production wall/link representation metric before another population-evolving refinement run."
        return MetalIndexedBirdSurfaceLinkGeometryReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkGeometryPreregistrationSHA256: preregistrationSHA,
            sourceDurationPreregistrationSHA256:
                expected.sourceDurationPreregistrationSHA256,
            sourceDurationReportSHA256: expected.sourceDurationReportSHA256,
            d12: d12,
            d16: d16,
            metrics: metrics,
            wallRepresentationCleared: cleared,
            linkMeasureBiasLikely: parityPassed && measureBias,
            interpolationBiasLikely: parityPassed && interpolationBias,
            wallVelocityDepositionBiasLikely: parityPassed && velocityBias,
            classification: classification,
            d20DiagnosticAuthorized: false,
            rawSpatialGateModified: false,
            productionPromotionAuthorized: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The frozen-phase D12/D16 geometry-only discriminator is "
                    + classification + ". The raw moving-window rejection and "
                    + "D20 block remain unchanged."
            ),
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallLinkVelocityPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkGeometryPreregistration:
            MetalIndexedBirdSurfaceLinkGeometryPreregistration,
        sourceLinkGeometryPreregistrationSHA256: String,
        linkGeometryReport: MetalIndexedBirdSurfaceLinkGeometryReport,
        sourceLinkGeometryReportSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkVelocityPreregistration {
        let geometryPreregistrationSHA =
            sourceLinkGeometryPreregistrationSHA256.lowercased()
        let geometryReportSHA = sourceLinkGeometryReportSHA256.lowercased()
        let hashes = [geometryPreregistrationSHA, geometryReportSHA]
        guard hashes.allSatisfy({
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }),
        linkGeometryPreregistration.datasetIdentifier == surface.datasetIdentifier,
        linkGeometryPreregistration.manifestSHA256 == surface.manifestSHA256,
        linkGeometryPreregistration.forceTargetIdentifier == target.datasetIdentifier,
        linkGeometryPreregistration.forceTargetSHA256 == target.targetSHA256,
        linkGeometryPreregistration.referenceLengthCells == [12, 16],
        linkGeometryReport.datasetIdentifier == surface.datasetIdentifier,
        linkGeometryReport.manifestSHA256 == surface.manifestSHA256,
        linkGeometryReport.forceTargetIdentifier == target.datasetIdentifier,
        linkGeometryReport.forceTargetSHA256 == target.targetSHA256,
        linkGeometryReport.sourceLinkGeometryPreregistrationSHA256
            == geometryPreregistrationSHA,
        linkGeometryReport.d12.parityGatePassed,
        linkGeometryReport.d16.parityGatePassed,
        !linkGeometryReport.wallRepresentationCleared,
        !linkGeometryReport.linkMeasureBiasLikely,
        !linkGeometryReport.interpolationBiasLikely,
        linkGeometryReport.wallVelocityDepositionBiasLikely,
        linkGeometryReport.classification == "wall-velocity-deposition-bias",
        !linkGeometryReport.d20DiagnosticAuthorized,
        !linkGeometryReport.productionPromotionAuthorized else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-velocity preregistration requires the locked wall-velocity-deposition result"
            )
        }
        return MetalIndexedBirdSurfaceLinkVelocityPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkGeometryPreregistrationSHA256:
                geometryPreregistrationSHA,
            sourceLinkGeometryReportSHA256: geometryReportSHA,
            referenceLengthCells: [12, 16],
            frozenSourceSampleIndex:
                linkGeometryPreregistration.frozenSourceSampleIndex,
            frozenSourceTimeSeconds:
                linkGeometryPreregistration.frozenSourceTimeSeconds,
            maximumAllowedSourceReproductionRelativeError: 1e-10,
            maximumAllowedOffsetSurfaceRMSResidualCells: 0.10,
            maximumAllowedOffsetSurfaceMaximumResidualCells: 0.75,
            maximumAllowedExactMeanVelocityError: 0.05,
            maximumAllowedExactRMSSpeedRelativeError: 0.05,
            maximumAllowedEndpointMeanVelocityError: 0.05,
            maximumAllowedEndpointRMSSpeedRelativeError: 0.05,
            maximumAllowedD12D16MeanVelocityDifference: 0.05,
            minimumCausalImprovementFraction: 0.50,
            minimumContributionImprovementFraction: 0.20,
            minimumEndpointCaptureOfExactImprovementFraction: 0.80,
            selectionRule: (
                "On the exact frozen D12/D16 production links, reproduce the "
                    + "archived solid-node wall moments within 1e-10. For every "
                    + "link compare (A) the production solid-node velocity, "
                    + "(B) q*u_solid+(1-q)*u_fluid where production q is measured "
                    + "from the fluid node, and (C) the same-component triangle "
                    + "barycentric velocity at x_solid+(1-q)c_q*dx. Verify the "
                    + "intersection is on the physical 7.5 mm offset surface within "
                    + "0.10-cell RMS and 0.75-cell maximum. Solid-node sampling is "
                    + "causal only if exact intersections reduce the left-wing mean "
                    + "error by at least 50%, clear 5% mean/RMS and D12/D16 limits. "
                    + "Endpoint interpolation qualifies only if it also clears 5% "
                    + "and captures at least 80% of the exact improvement."
            ),
            fixedInputs: (
                "Hashed link-geometry preregistration and result; source phase "
                    + "26.5 ms; D12/D16 Metal rasters; production signed-distance "
                    + "q, D3Q19 measure and component attribution; source triangle "
                    + "topology and barycentric kinematics; unchanged 7.5 mm physical "
                    + "half-thickness. No populations, collision, streaming, loads, "
                    + "topology evolution, or production mutation."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This A/B identifies the velocity sampling mechanism only. It does "
                    + "not authorize a production operator change, fluid allocation, "
                    + "D20, experimental agreement, or relaxation of any prior gate."
            )
        )
    }

    public static func collisionGridMovingWallLinkVelocity(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkGeometryPreregistration:
            MetalIndexedBirdSurfaceLinkGeometryPreregistration,
        sourceLinkGeometryPreregistrationSHA256: String,
        linkGeometryReport: MetalIndexedBirdSurfaceLinkGeometryReport,
        sourceLinkGeometryReportSHA256: String,
        preregistration: MetalIndexedBirdSurfaceLinkVelocityPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkVelocityReport {
#if canImport(Metal)
        let expected = try collisionGridMovingWallLinkVelocityPreregistration(
            surface: surface,
            target: target,
            linkGeometryPreregistration: linkGeometryPreregistration,
            sourceLinkGeometryPreregistrationSHA256:
                sourceLinkGeometryPreregistrationSHA256,
            linkGeometryReport: linkGeometryReport,
            sourceLinkGeometryReportSHA256: sourceLinkGeometryReportSHA256
        )
        let preregistrationSHA = sourcePreregistrationSHA256.lowercased()
        guard preregistration == expected,
              preregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-velocity run does not match its locked preregistration"
            )
        }
        let backend = try MetalBackend(fastMath: false)
        let sourceCases = [linkGeometryReport.d12, linkGeometryReport.d16]
        let cases = try zip(
            preregistration.referenceLengthCells,
            sourceCases
        ).map { cells, sourceCase in
            let plan = try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: cells
            )
            return try linkVelocityCase(
                backend: backend,
                surface: surface,
                plan: plan,
                referenceLengthCells: cells,
                timeSeconds: Float(preregistration.frozenSourceTimeSeconds),
                sourceCase: sourceCase,
                maximumSourceError:
                    preregistration.maximumAllowedSourceReproductionRelativeError
            )
        }
        let d12 = cases[0]
        let d16 = cases[1]
        let allComponents = d12.components + d16.components
        func candidate(
            _ component: MetalIndexedBirdSurfaceLinkVelocityComponent,
            _ keyPath: KeyPath<MetalIndexedBirdSurfaceLinkVelocityComponent,
                MetalIndexedBirdSurfaceLinkVelocityCandidate>
        ) -> MetalIndexedBirdSurfaceLinkVelocityCandidate {
            component[keyPath: keyPath]
        }
        func maximumError(
            _ keyPath: KeyPath<MetalIndexedBirdSurfaceLinkVelocityComponent,
                MetalIndexedBirdSurfaceLinkVelocityCandidate>,
            _ value: KeyPath<MetalIndexedBirdSurfaceLinkVelocityCandidate, Double>
        ) -> Double {
            allComponents.map { candidate($0, keyPath)[keyPath: value] }.max()!
        }
        func gridMeanDifference(
            _ keyPath: KeyPath<MetalIndexedBirdSurfaceLinkVelocityComponent,
                MetalIndexedBirdSurfaceLinkVelocityCandidate>
        ) -> Double {
            zip(d12.components, d16.components).map { first, second in
                let referenceRMS = max(
                    sourceCases[0].components.first {
                        $0.partIdentifier == first.partIdentifier
                    }!.triangleQuadrature.rmsWallSpeedMetersPerSecond,
                    1e-30
                )
                return vectorMagnitude(
                    candidate(first, keyPath).meanWallVelocityMetersPerSecond
                        - candidate(second, keyPath).meanWallVelocityMetersPerSecond
                ) / referenceRMS
            }.max()!
        }
        let leftWingPairs = [d12, d16].map { report -> (
            production: Double, endpoint: Double, exact: Double
        ) in
            let component = report.components.first {
                $0.partIdentifier == 2
            }!
            return (
                component.productionSolidNode
                    .meanVelocityErrorRelativeToQuadratureRMS,
                component.endpointInterpolated
                    .meanVelocityErrorRelativeToQuadratureRMS,
                component.exactLinkIntersection
                    .meanVelocityErrorRelativeToQuadratureRMS
            )
        }
        let exactImprovements = leftWingPairs.map {
            1.0 - $0.exact / max($0.production, 1e-30)
        }
        let endpointImprovements = leftWingPairs.map {
            1.0 - $0.endpoint / max($0.production, 1e-30)
        }
        let endpointCapture = leftWingPairs.map {
            let exactImprovement = $0.production - $0.exact
            return exactImprovement > 0
                ? ($0.production - $0.endpoint) / exactImprovement
                : 0
        }
        let metrics = MetalIndexedBirdSurfaceLinkVelocityMetrics(
            maximumSourceProductionRelativeDifference: max(
                d12.sourceProductionMaximumRelativeDifference,
                d16.sourceProductionMaximumRelativeDifference
            ),
            maximumProductionMeanVelocityError: maximumError(
                \.productionSolidNode,
                \.meanVelocityErrorRelativeToQuadratureRMS
            ),
            maximumEndpointMeanVelocityError: maximumError(
                \.endpointInterpolated,
                \.meanVelocityErrorRelativeToQuadratureRMS
            ),
            maximumExactMeanVelocityError: maximumError(
                \.exactLinkIntersection,
                \.meanVelocityErrorRelativeToQuadratureRMS
            ),
            maximumProductionRMSSpeedRelativeError: maximumError(
                \.productionSolidNode,
                \.rmsSpeedRelativeError
            ),
            maximumEndpointRMSSpeedRelativeError: maximumError(
                \.endpointInterpolated,
                \.rmsSpeedRelativeError
            ),
            maximumExactRMSSpeedRelativeError: maximumError(
                \.exactLinkIntersection,
                \.rmsSpeedRelativeError
            ),
            maximumEndpointD12D16MeanVelocityDifference:
                gridMeanDifference(\.endpointInterpolated),
            maximumExactD12D16MeanVelocityDifference:
                gridMeanDifference(\.exactLinkIntersection),
            maximumOffsetSurfaceRMSResidualCells: allComponents.map(
                \.offsetSurfaceRMSResidualCells
            ).max()!,
            maximumOffsetSurfaceResidualCells: allComponents.map(
                \.offsetSurfaceMaximumResidualCells
            ).max()!,
            minimumLeftWingExactImprovementFraction:
                exactImprovements.min()!,
            minimumLeftWingEndpointImprovementFraction:
                endpointImprovements.min()!,
            minimumEndpointCaptureOfExactImprovementFraction:
                endpointCapture.min()!
        )
        let sourceReproduced = metrics.maximumSourceProductionRelativeDifference
            <= preregistration.maximumAllowedSourceReproductionRelativeError
        let placementPassed = metrics.maximumOffsetSurfaceRMSResidualCells
                <= preregistration.maximumAllowedOffsetSurfaceRMSResidualCells
            && metrics.maximumOffsetSurfaceResidualCells
                <= preregistration.maximumAllowedOffsetSurfaceMaximumResidualCells
        let exactClears = metrics.maximumExactMeanVelocityError
                <= preregistration.maximumAllowedExactMeanVelocityError
            && metrics.maximumExactRMSSpeedRelativeError
                <= preregistration.maximumAllowedExactRMSSpeedRelativeError
            && metrics.maximumExactD12D16MeanVelocityDifference
                <= preregistration.maximumAllowedD12D16MeanVelocityDifference
        let causal = sourceReproduced && placementPassed && exactClears
            && metrics.minimumLeftWingExactImprovementFraction
                >= preregistration.minimumCausalImprovementFraction
        let endpointQualified = causal
            && metrics.maximumEndpointMeanVelocityError
                <= preregistration.maximumAllowedEndpointMeanVelocityError
            && metrics.maximumEndpointRMSSpeedRelativeError
                <= preregistration.maximumAllowedEndpointRMSSpeedRelativeError
            && metrics.maximumEndpointD12D16MeanVelocityDifference
                <= preregistration.maximumAllowedD12D16MeanVelocityDifference
            && metrics.minimumEndpointCaptureOfExactImprovementFraction
                >= preregistration
                    .minimumEndpointCaptureOfExactImprovementFraction
        let classification = !sourceReproduced
            ? "invalid-source-production-reproduction"
            : !placementPassed
                ? "signed-distance-intersection-placement-bias"
                : causal && endpointQualified
                    ? "endpoint-interpolation-repair-qualified"
                    : causal
                        ? "exact-intersection-velocity-sampling-causal"
                        : metrics.minimumLeftWingExactImprovementFraction
                                >= preregistration
                                    .minimumContributionImprovementFraction
                            ? "solid-node-velocity-sampling-contributes"
                            : "link-weighting-dominant"
        let nextAction: String
        switch classification {
        case "endpoint-interpolation-repair-qualified":
            nextAction = "Implement endpoint-interpolated link wall velocity behind an opt-in validation mode, then rerun only the short frozen-wall D12/D16 force-response discriminator."
        case "exact-intersection-velocity-sampling-causal":
            nextAction = "Carry the resolved source-triangle identity into link construction and test exact-intersection velocity behind an opt-in validation mode before fluid allocation."
        case "signed-distance-intersection-placement-bias":
            nextAction = "Correct the signed-distance link intersection location before changing wall velocity or running fluid."
        default:
            nextAction = "Keep production unchanged and decompose link-weighted surface quadrature by left-wing region before any fluid or D20 allocation."
        }
        return MetalIndexedBirdSurfaceLinkVelocityReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkVelocityPreregistrationSHA256: preregistrationSHA,
            sourceLinkGeometryPreregistrationSHA256:
                expected.sourceLinkGeometryPreregistrationSHA256,
            sourceLinkGeometryReportSHA256:
                expected.sourceLinkGeometryReportSHA256,
            d12: d12,
            d16: d16,
            metrics: metrics,
            intersectionPlacementPassed: placementPassed,
            exactIntersectionClearsBias: exactClears,
            solidNodeSamplingCausal: causal,
            endpointInterpolationQualified: endpointQualified,
            classification: classification,
            d20DiagnosticAuthorized: false,
            productionModificationAuthorized: false,
            rawSpatialGateModified: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The frozen link-velocity A/B is " + classification
                    + ". Production, the raw spatial rejection, and the D20 "
                    + "block remain unchanged."
            ),
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallLinkIntersectionPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkVelocityPreregistration:
            MetalIndexedBirdSurfaceLinkVelocityPreregistration,
        sourceLinkVelocityPreregistrationSHA256: String,
        linkVelocityReport: MetalIndexedBirdSurfaceLinkVelocityReport,
        sourceLinkVelocityReportSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkIntersectionPreregistration {
        let velocityPreregistrationSHA =
            sourceLinkVelocityPreregistrationSHA256.lowercased()
        let velocityReportSHA = sourceLinkVelocityReportSHA256.lowercased()
        let hashes = [velocityPreregistrationSHA, velocityReportSHA]
        guard hashes.allSatisfy({
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }),
        linkVelocityPreregistration.datasetIdentifier
            == surface.datasetIdentifier,
        linkVelocityPreregistration.manifestSHA256 == surface.manifestSHA256,
        linkVelocityPreregistration.forceTargetIdentifier
            == target.datasetIdentifier,
        linkVelocityPreregistration.forceTargetSHA256 == target.targetSHA256,
        linkVelocityPreregistration.referenceLengthCells == [12, 16],
        linkVelocityPreregistration.passed,
        linkVelocityReport.datasetIdentifier == surface.datasetIdentifier,
        linkVelocityReport.manifestSHA256 == surface.manifestSHA256,
        linkVelocityReport.forceTargetIdentifier == target.datasetIdentifier,
        linkVelocityReport.forceTargetSHA256 == target.targetSHA256,
        linkVelocityReport.sourceLinkVelocityPreregistrationSHA256
            == velocityPreregistrationSHA,
        linkVelocityReport.d12.referenceLengthCells == 12,
        linkVelocityReport.d16.referenceLengthCells == 16,
        linkVelocityReport.d12.sourceReproductionPassed,
        linkVelocityReport.d16.sourceReproductionPassed,
        !linkVelocityReport.intersectionPlacementPassed,
        !linkVelocityReport.exactIntersectionClearsBias,
        !linkVelocityReport.solidNodeSamplingCausal,
        !linkVelocityReport.endpointInterpolationQualified,
        linkVelocityReport.classification
            == "signed-distance-intersection-placement-bias",
        linkVelocityReport.metrics.maximumOffsetSurfaceResidualCells
            > linkVelocityPreregistration
                .maximumAllowedOffsetSurfaceMaximumResidualCells,
        !linkVelocityReport.d20DiagnosticAuthorized,
        !linkVelocityReport.productionModificationAuthorized else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-intersection preregistration requires the locked placement-bias result"
            )
        }
        return MetalIndexedBirdSurfaceLinkIntersectionPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkVelocityPreregistrationSHA256:
                velocityPreregistrationSHA,
            sourceLinkVelocityReportSHA256: velocityReportSHA,
            referenceLengthCells: [12, 16],
            frozenSourceSampleIndex:
                linkVelocityPreregistration.frozenSourceSampleIndex,
            frozenSourceTimeSeconds:
                linkVelocityPreregistration.frozenSourceTimeSeconds,
            outlierResidualThresholdCells:
                linkVelocityPreregistration
                    .maximumAllowedOffsetSurfaceMaximumResidualCells,
            barycentricFeatureTolerance: 1e-5,
            maximumJunctionAlternateSurfaceResidualCells: 0.25,
            minimumEdgeOrJunctionAssociationFraction: 0.80,
            minimumDirectionConcentrationFraction: 0.50,
            minimumInteriorAssociationFraction: 0.50,
            maximumAllowedSourceMaximumResidualDifferenceCells: 1e-10,
            selectionRule: (
                "Archive every D12/D16 link whose absolute distance from the "
                    + "physical 7.5 mm offset surface exceeds 0.75 cell. Record "
                    + "component, direction, solid/fluid cells, q, intersection, "
                    + "nearest triangle and barycentrics, signed residual, true "
                    + "mesh-boundary feature, and nearest alternate component. "
                    + "A junction candidate is within 0.25 cell of another "
                    + "component offset surface. Edge/junction association requires "
                    + "at least 80% of outlier link measure on both grids. Direction "
                    + "association requires the same direction and at least 50% on "
                    + "both grids. Interior association requires at least 50% on "
                    + "both grids. These are associations, not causal repairs."
            ),
            fixedInputs: (
                "Hashed link-velocity preregistration and placement-bias report; "
                    + "source phase 26.5 ms; D12/D16 Metal rasters; production "
                    + "signed-distance q and D3Q19 link measure; source component "
                    + "triangle topology; unchanged 7.5 mm physical half-thickness. "
                    + "No populations, collision, streaming, force evaluation, "
                    + "topology evolution, or production mutation."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This gate localizes sparse signed-distance intersection outliers. "
                    + "It does not prove their causal mechanism, authorize a "
                    + "production geometry or velocity change, evolve fluid, "
                    + "allocate D20, establish experimental agreement, or relax "
                    + "any prior gate."
            )
        )
    }

    public static func collisionGridMovingWallLinkIntersection(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkVelocityPreregistration:
            MetalIndexedBirdSurfaceLinkVelocityPreregistration,
        sourceLinkVelocityPreregistrationSHA256: String,
        linkVelocityReport: MetalIndexedBirdSurfaceLinkVelocityReport,
        sourceLinkVelocityReportSHA256: String,
        preregistration:
            MetalIndexedBirdSurfaceLinkIntersectionPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkIntersectionReport {
#if canImport(Metal)
        let expected = try
            collisionGridMovingWallLinkIntersectionPreregistration(
                surface: surface,
                target: target,
                linkVelocityPreregistration: linkVelocityPreregistration,
                sourceLinkVelocityPreregistrationSHA256:
                    sourceLinkVelocityPreregistrationSHA256,
                linkVelocityReport: linkVelocityReport,
                sourceLinkVelocityReportSHA256:
                    sourceLinkVelocityReportSHA256
            )
        let preregistrationSHA = sourcePreregistrationSHA256.lowercased()
        guard preregistration == expected,
              preregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-intersection run does not match its locked preregistration"
            )
        }
        let backend = try MetalBackend(fastMath: false)
        let sourceCases = [linkVelocityReport.d12, linkVelocityReport.d16]
        let cases = try zip(
            preregistration.referenceLengthCells,
            sourceCases
        ).map { cells, sourceCase in
            let plan = try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: cells
            )
            return try linkIntersectionCase(
                backend: backend,
                surface: surface,
                plan: plan,
                referenceLengthCells: cells,
                timeSeconds: Float(preregistration.frozenSourceTimeSeconds),
                sourceCase: sourceCase,
                preregistration: preregistration
            )
        }
        let d12 = cases[0]
        let d16 = cases[1]
        let sameDirection = d12.dominantDirectionIndex != nil
            && d12.dominantDirectionIndex == d16.dominantDirectionIndex
        let metrics = MetalIndexedBirdSurfaceLinkIntersectionMetrics(
            maximumSourceMaximumResidualDifferenceCells: max(
                d12.sourceMaximumResidualDifferenceCells,
                d16.sourceMaximumResidualDifferenceCells
            ),
            d12OutlierCount: d12.outlierCount,
            d16OutlierCount: d16.outlierCount,
            d12OutlierLinkMeasureFraction: d12.outlierLinkMeasureFraction,
            d16OutlierLinkMeasureFraction: d16.outlierLinkMeasureFraction,
            minimumEdgeOrJunctionAssociatedMeasureFraction: min(
                d12.edgeOrJunctionAssociatedMeasureFraction,
                d16.edgeOrJunctionAssociatedMeasureFraction
            ),
            minimumInteriorAssociatedMeasureFraction: min(
                d12.interiorAssociatedMeasureFraction,
                d16.interiorAssociatedMeasureFraction
            ),
            minimumDominantDirectionMeasureFraction: min(
                d12.dominantDirectionMeasureFraction,
                d16.dominantDirectionMeasureFraction
            ),
            sameDominantDirectionAcrossGrids: sameDirection,
            maximumOffsetSurfaceResidualCells: max(
                d12.maximumOffsetSurfaceResidualCells,
                d16.maximumOffsetSurfaceResidualCells
            )
        )
        let sourceReproduced = d12.sourceLinkCountMatched
            && d16.sourceLinkCountMatched
            && d12.allOutliersArchived && d16.allOutliersArchived
            && metrics.maximumSourceMaximumResidualDifferenceCells
                <= preregistration
                    .maximumAllowedSourceMaximumResidualDifferenceCells
            && d12.outlierCount > 0 && d16.outlierCount > 0
        let edgeAssociated = sourceReproduced
            && metrics.minimumEdgeOrJunctionAssociatedMeasureFraction
                >= preregistration
                    .minimumEdgeOrJunctionAssociationFraction
        let directionAssociated = sourceReproduced && sameDirection
            && metrics.minimumDominantDirectionMeasureFraction
                >= preregistration.minimumDirectionConcentrationFraction
        let interiorAssociated = sourceReproduced
            && metrics.minimumInteriorAssociatedMeasureFraction
                >= preregistration.minimumInteriorAssociationFraction
        let classification = !sourceReproduced
            ? "invalid-outlier-reproduction"
            : edgeAssociated
                ? "mesh-edge-or-component-junction-associated"
                : directionAssociated
                    ? "stencil-direction-associated"
                    : interiorAssociated
                        ? "interior-link-placement-outliers"
                        : "mixed-sparse-placement-outliers"
        let nextAction: String
        switch classification {
        case "mesh-edge-or-component-junction-associated":
            nextAction = d12.meshBoundaryAssociatedOutlierCount == 0
                    && d16.meshBoundaryAssociatedOutlierCount == 0
                ? "Compare linear signed-distance q with an exact offset-surface ray root on the 14 archived component-junction candidates plus the one D12 interior outlier, preserving component ownership, before changing the general link formula."
                : "Compare linear signed-distance q with an exact offset-surface ray root only on the archived boundary/junction links, preserving component ownership, before changing the general link formula."
        case "stencil-direction-associated":
            nextAction = "Compare linear signed-distance q with an exact offset-surface ray root for the archived dominant D3Q19 direction before changing other links."
        case "interior-link-placement-outliers":
            nextAction = "Run an archive-only linear-q versus exact offset-surface ray-root A/B on the recorded interior links before modifying production link placement."
        default:
            nextAction = "Run an archive-only exact offset-surface ray-root A/B on every recorded outlier, stratified by feature and direction, before modifying production."
        }
        return MetalIndexedBirdSurfaceLinkIntersectionReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkIntersectionPreregistrationSHA256:
                preregistrationSHA,
            sourceLinkVelocityPreregistrationSHA256:
                expected.sourceLinkVelocityPreregistrationSHA256,
            sourceLinkVelocityReportSHA256:
                expected.sourceLinkVelocityReportSHA256,
            d12: d12,
            d16: d16,
            metrics: metrics,
            sourceReproductionPassed: sourceReproduced,
            edgeOrJunctionAssociated: edgeAssociated,
            directionAssociated: directionAssociated,
            interiorAssociated: interiorAssociated,
            classification: classification,
            d20DiagnosticAuthorized: false,
            productionModificationAuthorized: false,
            fluidEvolutionExecuted: false,
            rawSpatialGateModified: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The frozen link-intersection localization is "
                    + classification + ". It records association only; "
                    + "production, the raw spatial rejection, and the D20 block "
                    + "remain unchanged."
            ),
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallLinkRayRootPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkIntersectionPreregistration:
            MetalIndexedBirdSurfaceLinkIntersectionPreregistration,
        sourceLinkIntersectionPreregistrationSHA256: String,
        linkIntersectionReport:
            MetalIndexedBirdSurfaceLinkIntersectionReport,
        sourceLinkIntersectionReportSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkRayRootPreregistration {
        let intersectionPreregistrationSHA =
            sourceLinkIntersectionPreregistrationSHA256.lowercased()
        let intersectionReportSHA =
            sourceLinkIntersectionReportSHA256.lowercased()
        let hashes = [intersectionPreregistrationSHA, intersectionReportSHA]
        guard hashes.allSatisfy({
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }),
        linkIntersectionPreregistration.datasetIdentifier
            == surface.datasetIdentifier,
        linkIntersectionPreregistration.manifestSHA256
            == surface.manifestSHA256,
        linkIntersectionPreregistration.forceTargetIdentifier
            == target.datasetIdentifier,
        linkIntersectionPreregistration.forceTargetSHA256
            == target.targetSHA256,
        linkIntersectionPreregistration.referenceLengthCells == [12, 16],
        linkIntersectionPreregistration.passed,
        linkIntersectionReport.datasetIdentifier == surface.datasetIdentifier,
        linkIntersectionReport.manifestSHA256 == surface.manifestSHA256,
        linkIntersectionReport.forceTargetIdentifier == target.datasetIdentifier,
        linkIntersectionReport.forceTargetSHA256 == target.targetSHA256,
        linkIntersectionReport.sourceLinkIntersectionPreregistrationSHA256
            == intersectionPreregistrationSHA,
        linkIntersectionReport.sourceReproductionPassed,
        linkIntersectionReport.d12.outlierCount == 8,
        linkIntersectionReport.d16.outlierCount == 7,
        linkIntersectionReport.d12.componentJunctionCandidateOutlierCount == 7,
        linkIntersectionReport.d16.componentJunctionCandidateOutlierCount == 7,
        linkIntersectionReport.d12.meshBoundaryAssociatedOutlierCount == 0,
        linkIntersectionReport.d16.meshBoundaryAssociatedOutlierCount == 0,
        linkIntersectionReport.edgeOrJunctionAssociated,
        !linkIntersectionReport.directionAssociated,
        !linkIntersectionReport.interiorAssociated,
        linkIntersectionReport.classification
            == "mesh-edge-or-component-junction-associated",
        !linkIntersectionReport.d20DiagnosticAuthorized,
        !linkIntersectionReport.productionModificationAuthorized,
        !linkIntersectionReport.fluidEvolutionExecuted else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-ray-root preregistration requires the locked junction-associated outlier archive"
            )
        }
        return MetalIndexedBirdSurfaceLinkRayRootPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkIntersectionPreregistrationSHA256:
                intersectionPreregistrationSHA,
            sourceLinkIntersectionReportSHA256: intersectionReportSHA,
            referenceLengthCells: [12, 16],
            frozenSourceSampleIndex:
                linkIntersectionPreregistration.frozenSourceSampleIndex,
            frozenSourceTimeSeconds:
                linkIntersectionPreregistration.frozenSourceTimeSeconds,
            expectedOutlierCounts: [8, 7],
            expectedJunctionCandidateCounts: [7, 7],
            reverseScanSubdivisions: 256,
            bisectionIterations: 48,
            maximumAllowedRootClosureResidualCells: 1e-5,
            maximumAllowedGlobalRootRMSShiftCells: 0.10,
            maximumAllowedGlobalRootMaximumShiftCells: 0.75,
            minimumRequiredOwnerToGlobalRMSReductionFraction: 0.80,
            selectionRule: (
                "For each of the 15 hashed outlier links, reconstruct the solid "
                    + "and fluid endpoints and production t=1-q. From the fluid "
                    + "endpoint scan 256 uniform intervals toward solid, select "
                    + "the first outside-to-inside bracket, and apply 48 bisection "
                    + "iterations to distance-to-mid-surface minus the physical "
                    + "7.5 mm half-thickness. Evaluate both the source part alone "
                    + "and the production global union over all components. Roots "
                    + "must close within 1e-5 cell. Global-union placement clears "
                    + "only at <=0.10-cell measure-weighted RMS and <=0.75-cell "
                    + "maximum on both grids. An ownership interpretation requires "
                    + "at least 80% RMS shift reduction relative to owner roots."
            ),
            fixedInputs: (
                "Hashed intersection-localization preregistration and all 15 "
                    + "per-link records; source phase 26.5 ms; D12/D16 cell sizes, "
                    + "D3Q19 directions, production q, source triangle topology, "
                    + "and 7.5 mm physical half-thickness. The production raster's "
                    + "globally nearest-triangle union semantics are authoritative. "
                    + "No Metal dispatch, populations, collision, streaming, force "
                    + "evaluation, topology evolution, or production mutation."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This archive-only A/B distinguishes owner-surface diagnostic "
                    + "error from global-union linear-root error on 15 links. It "
                    + "does not authorize a production q or ownership change, "
                    + "fluid evolution, D20, experimental agreement, or relaxation "
                    + "of the raw spatial gate."
            )
        )
    }

    public static func collisionGridMovingWallLinkRayRoot(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkIntersectionPreregistration:
            MetalIndexedBirdSurfaceLinkIntersectionPreregistration,
        sourceLinkIntersectionPreregistrationSHA256: String,
        linkIntersectionReport:
            MetalIndexedBirdSurfaceLinkIntersectionReport,
        sourceLinkIntersectionReportSHA256: String,
        preregistration:
            MetalIndexedBirdSurfaceLinkRayRootPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkRayRootReport {
#if canImport(Metal)
        let expected = try collisionGridMovingWallLinkRayRootPreregistration(
            surface: surface,
            target: target,
            linkIntersectionPreregistration:
                linkIntersectionPreregistration,
            sourceLinkIntersectionPreregistrationSHA256:
                sourceLinkIntersectionPreregistrationSHA256,
            linkIntersectionReport: linkIntersectionReport,
            sourceLinkIntersectionReportSHA256:
                sourceLinkIntersectionReportSHA256
        )
        let preregistrationSHA = sourcePreregistrationSHA256.lowercased()
        guard preregistration == expected,
              preregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-ray-root run does not match its locked preregistration"
            )
        }
        let sourceCases = [
            linkIntersectionReport.d12,
            linkIntersectionReport.d16,
        ]
        let cases = try zip(
            preregistration.referenceLengthCells,
            sourceCases
        ).map { cells, sourceCase in
            try linkRayRootCase(
                surface: surface,
                referenceLengthCells: cells,
                timeSeconds: Float(preregistration.frozenSourceTimeSeconds),
                sourceCase: sourceCase,
                preregistration: preregistration
            )
        }
        let d12 = cases[0]
        let d16 = cases[1]
        let interiorShifts = [
            d12.interiorGlobalRootMaximumShiftCells,
            d16.interiorGlobalRootMaximumShiftCells,
        ].compactMap { $0 }
        let metrics = MetalIndexedBirdSurfaceLinkRayRootMetrics(
            maximumJunctionGlobalRootRMSShiftCells: max(
                d12.junctionGlobalRootRMSShiftCells,
                d16.junctionGlobalRootRMSShiftCells
            ),
            maximumJunctionGlobalRootMaximumShiftCells: max(
                d12.junctionGlobalRootMaximumShiftCells,
                d16.junctionGlobalRootMaximumShiftCells
            ),
            minimumJunctionOwnerToGlobalRMSReductionFraction: min(
                d12.junctionOwnerToGlobalRMSReductionFraction,
                d16.junctionOwnerToGlobalRMSReductionFraction
            ),
            maximumAllGlobalRootRMSShiftCells: max(
                d12.allGlobalRootRMSShiftCells,
                d16.allGlobalRootRMSShiftCells
            ),
            maximumAllGlobalRootMaximumShiftCells: max(
                d12.allGlobalRootMaximumShiftCells,
                d16.allGlobalRootMaximumShiftCells
            ),
            minimumAllOwnerToGlobalRMSReductionFraction: min(
                d12.allOwnerToGlobalRMSReductionFraction,
                d16.allOwnerToGlobalRMSReductionFraction
            ),
            maximumInteriorGlobalRootShiftCells: interiorShifts.max(),
            maximumRootClosureResidualCells: max(
                d12.maximumRootClosureResidualCells,
                d16.maximumRootClosureResidualCells
            ),
            totalGlobalRootComponentSwitchCount:
                d12.globalRootComponentSwitchCount
                    + d16.globalRootComponentSwitchCount,
            totalEndpointNearestComponentChangeCount:
                d12.endpointNearestComponentChangeCount
                    + d16.endpointNearestComponentChangeCount
        )
        let sourceReproduced = d12.sourceRecordsMatched
            && d16.sourceRecordsMatched
            && d12.sampleCount == preregistration.expectedOutlierCounts[0]
            && d16.sampleCount == preregistration.expectedOutlierCounts[1]
            && d12.junctionCandidateCount
                == preregistration.expectedJunctionCandidateCounts[0]
            && d16.junctionCandidateCount
                == preregistration.expectedJunctionCandidateCounts[1]
            && d12.allRootsBracketed && d16.allRootsBracketed
            && d12.allValuesFinite && d16.allValuesFinite
        let closurePassed = sourceReproduced
            && metrics.maximumRootClosureResidualCells
                <= preregistration.maximumAllowedRootClosureResidualCells
        let junctionPassed = closurePassed
            && metrics.maximumJunctionGlobalRootRMSShiftCells
                <= preregistration.maximumAllowedGlobalRootRMSShiftCells
            && metrics.maximumJunctionGlobalRootMaximumShiftCells
                <= preregistration.maximumAllowedGlobalRootMaximumShiftCells
        let allPassed = closurePassed
            && metrics.maximumAllGlobalRootRMSShiftCells
                <= preregistration.maximumAllowedGlobalRootRMSShiftCells
            && metrics.maximumAllGlobalRootMaximumShiftCells
                <= preregistration.maximumAllowedGlobalRootMaximumShiftCells
        let reductionPassed = closurePassed
            && metrics.minimumJunctionOwnerToGlobalRMSReductionFraction
                >= preregistration
                    .minimumRequiredOwnerToGlobalRMSReductionFraction
        let classification = !sourceReproduced || !closurePassed
            ? "invalid-ray-root-reconstruction"
            : allPassed && reductionPassed
                ? "global-union-root-clears-owner-surface-outliers"
                : junctionPassed && reductionPassed
                    ? "component-junction-owner-surface-diagnostic-artifact"
                    : !junctionPassed
                        ? "junction-global-root-linearization-bias"
                        : "owner-versus-global-union-root-mixed"
        let superseded = classification
            == "global-union-root-clears-owner-surface-outliers"
        let nextAction: String
        switch classification {
        case "global-union-root-clears-owner-surface-outliers":
            nextAction = "Recompute the full D12/D16 link-placement gate against the production global-union surface definition; do not modify production q because the exact-root A/B has cleared these archived links."
        case "component-junction-owner-surface-diagnostic-artifact":
            nextAction = "Recompute the full gate with global-union distance while retaining the isolated interior outlier as a separate exact-root diagnostic; do not modify junction q."
        case "junction-global-root-linearization-bias":
            nextAction = "Reconstruct the production interpolation coefficients for the 15 archived links with linear q versus exact global-union q, including q-branch changes and coefficient amplification, before implementing any validation-only boundary change or fluid run."
        default:
            nextAction = "Keep production unchanged and stratify the 15 exact-root shifts by component pair and direction before selecting a correction surface."
        }
        return MetalIndexedBirdSurfaceLinkRayRootReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkRayRootPreregistrationSHA256: preregistrationSHA,
            sourceLinkIntersectionPreregistrationSHA256:
                expected.sourceLinkIntersectionPreregistrationSHA256,
            sourceLinkIntersectionReportSHA256:
                expected.sourceLinkIntersectionReportSHA256,
            d12: d12,
            d16: d16,
            metrics: metrics,
            sourceReproductionPassed: sourceReproduced,
            rootClosurePassed: closurePassed,
            junctionGlobalUnionPlacementPassed: junctionPassed,
            allGlobalUnionPlacementPassed: allPassed,
            ownerToGlobalReductionPassed: reductionPassed,
            classification: classification,
            priorPlacementClassificationSuperseded: superseded,
            d20DiagnosticAuthorized: false,
            productionModificationAuthorized: false,
            fluidEvolutionExecuted: false,
            rawSpatialGateModified: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The 15-link exact ray-root A/B is " + classification
                    + ". It changes diagnostic interpretation only; production, "
                    + "the raw force-history rejection, and D20 remain unchanged."
            ),
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionGridMovingWallLinkCoefficientPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkRayRootPreregistration:
            MetalIndexedBirdSurfaceLinkRayRootPreregistration,
        sourceLinkRayRootPreregistrationSHA256: String,
        linkRayRootReport: MetalIndexedBirdSurfaceLinkRayRootReport,
        sourceLinkRayRootReportSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkCoefficientPreregistration {
        let rayPreregistrationSHA =
            sourceLinkRayRootPreregistrationSHA256.lowercased()
        let rayReportSHA = sourceLinkRayRootReportSHA256.lowercased()
        guard [rayPreregistrationSHA, rayReportSHA].allSatisfy({
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }),
        linkRayRootPreregistration.datasetIdentifier
            == surface.datasetIdentifier,
        linkRayRootPreregistration.manifestSHA256
            == surface.manifestSHA256,
        linkRayRootPreregistration.forceTargetIdentifier
            == target.datasetIdentifier,
        linkRayRootPreregistration.forceTargetSHA256 == target.targetSHA256,
        linkRayRootPreregistration.referenceLengthCells == [12, 16],
        linkRayRootPreregistration.expectedOutlierCounts == [8, 7],
        linkRayRootPreregistration.passed,
        linkRayRootReport.datasetIdentifier == surface.datasetIdentifier,
        linkRayRootReport.manifestSHA256 == surface.manifestSHA256,
        linkRayRootReport.forceTargetIdentifier == target.datasetIdentifier,
        linkRayRootReport.forceTargetSHA256 == target.targetSHA256,
        linkRayRootReport.sourceLinkRayRootPreregistrationSHA256
            == rayPreregistrationSHA,
        linkRayRootReport.d12.sampleCount == 8,
        linkRayRootReport.d16.sampleCount == 7,
        linkRayRootReport.sourceReproductionPassed,
        linkRayRootReport.rootClosurePassed,
        !linkRayRootReport.junctionGlobalUnionPlacementPassed,
        !linkRayRootReport.allGlobalUnionPlacementPassed,
        linkRayRootReport.classification
            == "junction-global-root-linearization-bias",
        !linkRayRootReport.d20DiagnosticAuthorized,
        !linkRayRootReport.productionModificationAuthorized,
        !linkRayRootReport.fluidEvolutionExecuted else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-coefficient preregistration requires the locked ray-root linearization-bias archive"
            )
        }
        return MetalIndexedBirdSurfaceLinkCoefficientPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkRayRootPreregistrationSHA256: rayPreregistrationSHA,
            sourceLinkRayRootReportSHA256: rayReportSHA,
            referenceLengthCells: [12, 16],
            expectedSampleCounts: [8, 7],
            branchThreshold: 0.5,
            maximumAllowedWeightedRMSCoefficientL1Difference: 0.10,
            maximumAllowedCoefficientL1Difference: 0.25,
            maximumAllowedSymmetricOperatorNormRatio: 1.10,
            selectionRule: (
                "For each of the 15 hashed ray-root samples, evaluate the "
                    + "published interpolated bounce-back equation at production "
                    + "linear q and exact global-union q. q<=0.5 uses "
                    + "[2q,1-2q,0,1-q,q]; q>0.5 uses "
                    + "[1/(2q),0,(2q-1)/(2q),(1-q)/(2q),1/2]. The five "
                    + "coefficients multiply reflected, farther outgoing, "
                    + "previous incoming, and the fluid/solid endpoint wall "
                    + "projections after factoring the common moving-wall scale. "
                    + "The bias is coefficient-insensitive only with zero branch "
                    + "changes, <=0.10 measure-weighted RMS L1 change, <=0.25 "
                    + "maximum L1 change, and <=1.10 symmetric operator-L1-norm "
                    + "ratio on both grids."
            ),
            fixedInputs: (
                "Hashed ray-root preregistration and D12/D16 report; all 15 "
                    + "sample identities, link measures, production q, exact "
                    + "global-union q, the q=0.5 branch boundary, and the "
                    + "production Metal coefficient equations. No populations, "
                    + "wall velocities, geometry search, Metal dispatch, force "
                    + "evaluation, fluid evolution, or production mutation."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This archive-only coefficient bound establishes whether the "
                    + "15 stored q errors can materially alter the normalized "
                    + "boundary operator. It may authorize only a validation-only "
                    + "population replay with captured production primitives; it "
                    + "does not establish a force correction, authorize production "
                    + "changes or D20, or relax the raw spatial rejection."
            )
        )
    }

    public static func collisionGridMovingWallLinkCoefficient(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkRayRootPreregistration:
            MetalIndexedBirdSurfaceLinkRayRootPreregistration,
        sourceLinkRayRootPreregistrationSHA256: String,
        linkRayRootReport: MetalIndexedBirdSurfaceLinkRayRootReport,
        sourceLinkRayRootReportSHA256: String,
        preregistration:
            MetalIndexedBirdSurfaceLinkCoefficientPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkCoefficientReport {
        let expected = try
            collisionGridMovingWallLinkCoefficientPreregistration(
                surface: surface,
                target: target,
                linkRayRootPreregistration: linkRayRootPreregistration,
                sourceLinkRayRootPreregistrationSHA256:
                    sourceLinkRayRootPreregistrationSHA256,
                linkRayRootReport: linkRayRootReport,
                sourceLinkRayRootReportSHA256:
                    sourceLinkRayRootReportSHA256
            )
        let preregistrationSHA = sourcePreregistrationSHA256.lowercased()
        guard preregistration == expected,
              preregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-coefficient run does not match its locked preregistration"
            )
        }
        let d12 = linkCoefficientCase(
            source: linkRayRootReport.d12,
            branchThreshold: preregistration.branchThreshold
        )
        let d16 = linkCoefficientCase(
            source: linkRayRootReport.d16,
            branchThreshold: preregistration.branchThreshold
        )
        let metrics = MetalIndexedBirdSurfaceLinkCoefficientMetrics(
            totalBranchChangeCount:
                d12.branchChangeCount + d16.branchChangeCount,
            maximumBranchChangeLinkMeasureFraction: max(
                d12.branchChangeLinkMeasureFraction,
                d16.branchChangeLinkMeasureFraction
            ),
            maximumWeightedRMSFractionDifference: max(
                d12.weightedRMSFractionDifference,
                d16.weightedRMSFractionDifference
            ),
            maximumFractionDifference: max(
                d12.maximumFractionDifference,
                d16.maximumFractionDifference
            ),
            maximumWeightedRMSCoefficientL1Difference: max(
                d12.weightedRMSCoefficientL1Difference,
                d16.weightedRMSCoefficientL1Difference
            ),
            maximumCoefficientL1Difference: max(
                d12.maximumCoefficientL1Difference,
                d16.maximumCoefficientL1Difference
            ),
            maximumAbsoluteCoefficientDifference: max(
                d12.maximumAbsoluteCoefficientDifference,
                d16.maximumAbsoluteCoefficientDifference
            ),
            maximumWeightedRMSWallProjectionCoefficientL1Difference: max(
                d12.weightedRMSWallProjectionCoefficientL1Difference,
                d16.weightedRMSWallProjectionCoefficientL1Difference
            ),
            maximumSymmetricOperatorNormRatio: max(
                d12.maximumSymmetricOperatorNormRatio,
                d16.maximumSymmetricOperatorNormRatio
            )
        )
        let sourceReproduced = d12.sourceRecordsMatched
            && d16.sourceRecordsMatched
            && d12.sampleCount == preregistration.expectedSampleCounts[0]
            && d16.sampleCount == preregistration.expectedSampleCounts[1]
            && d12.allValuesFinite && d16.allValuesFinite
        let insensitive = sourceReproduced
            && metrics.totalBranchChangeCount == 0
            && metrics.maximumWeightedRMSCoefficientL1Difference
                <= preregistration
                    .maximumAllowedWeightedRMSCoefficientL1Difference
            && metrics.maximumCoefficientL1Difference
                <= preregistration.maximumAllowedCoefficientL1Difference
            && metrics.maximumSymmetricOperatorNormRatio
                <= preregistration.maximumAllowedSymmetricOperatorNormRatio
        let classification = !sourceReproduced
            ? "invalid-coefficient-reconstruction"
            : metrics.totalBranchChangeCount > 0
                ? "branch-changing-coefficient-sensitive"
                : insensitive
                    ? "coefficient-insensitive-linear-q-bias"
                    : "same-branch-coefficient-sensitive"
        let validationReplayAuthorized = sourceReproduced && !insensitive
        let nextAction = validationReplayAuthorized
            ? "Capture the production reflected, auxiliary, previous-incoming, wall-projection, and density primitives for these 15 links at the frozen D12 phase, then replay production-q versus exact-global-q populations and link momentum offline before any boundary implementation or full fluid A/B."
            : "Retain production q and return to the rejected full-window force convergence, because the archived geometric bias is too weak to justify a boundary experiment."
        return MetalIndexedBirdSurfaceLinkCoefficientReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkCoefficientPreregistrationSHA256: preregistrationSHA,
            sourceLinkRayRootPreregistrationSHA256:
                expected.sourceLinkRayRootPreregistrationSHA256,
            sourceLinkRayRootReportSHA256:
                expected.sourceLinkRayRootReportSHA256,
            d12: d12,
            d16: d16,
            metrics: metrics,
            sourceReproductionPassed: sourceReproduced,
            coefficientInsensitiveGatePassed: insensitive,
            classification: classification,
            validationOnlyPopulationReplayAuthorized:
                validationReplayAuthorized,
            d20DiagnosticAuthorized: false,
            productionModificationAuthorized: false,
            fluidEvolutionExecuted: false,
            rawSpatialGateModified: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The preregistered 15-link coefficient discriminator is "
                    + classification + ". It bounds normalized operator "
                    + "sensitivity only; force causality and production remain "
                    + "unresolved."
            ),
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
    }

    private static func linkCoefficients(
        q: Double,
        branchThreshold: Double
    ) -> MetalIndexedBirdSurfaceLinkCoefficients {
        precondition(q > 0 && q <= 1)
        if q <= branchThreshold {
            return MetalIndexedBirdSurfaceLinkCoefficients(
                reflected: 2 * q,
                fartherOutgoing: 1 - 2 * q,
                previousIncoming: 0,
                fluidEndpointWallProjection: 1 - q,
                solidEndpointWallProjection: q
            )
        }
        return MetalIndexedBirdSurfaceLinkCoefficients(
            reflected: 1 / (2 * q),
            fartherOutgoing: 0,
            previousIncoming: (2 * q - 1) / (2 * q),
            fluidEndpointWallProjection: (1 - q) / (2 * q),
            solidEndpointWallProjection: 0.5
        )
    }

    private static func linkCoefficientCase(
        source: MetalIndexedBirdSurfaceLinkRayRootCaseReport,
        branchThreshold: Double
    ) -> MetalIndexedBirdSurfaceLinkCoefficientCaseReport {
        let started = Date().timeIntervalSinceReferenceDate
        func values(_ coefficients: MetalIndexedBirdSurfaceLinkCoefficients)
            -> [Double]
        {
            [
                coefficients.reflected,
                coefficients.fartherOutgoing,
                coefficients.previousIncoming,
                coefficients.fluidEndpointWallProjection,
                coefficients.solidEndpointWallProjection,
            ]
        }
        let samples = source.samples.map { sample in
            let productionQ = sample.productionFluidToIntersectionFraction
            let exactQ = sample.exactGlobalFluidToIntersectionFraction
            let production = linkCoefficients(
                q: productionQ,
                branchThreshold: branchThreshold
            )
            let exact = linkCoefficients(
                q: exactQ,
                branchThreshold: branchThreshold
            )
            let productionValues = values(production)
            let exactValues = values(exact)
            let differences = zip(productionValues, exactValues).map {
                abs($0 - $1)
            }
            let productionNorm = productionValues.reduce(0) { $0 + abs($1) }
            let exactNorm = exactValues.reduce(0) { $0 + abs($1) }
            let productionNear = productionQ <= branchThreshold
            let exactNear = exactQ <= branchThreshold
            return MetalIndexedBirdSurfaceLinkCoefficientSample(
                sourceOutlierIndex: sample.sourceOutlierIndex,
                partIdentifier: sample.partIdentifier,
                componentName: sample.componentName,
                directionIndex: sample.directionIndex,
                cellCoordinate: sample.cellCoordinate,
                componentJunctionCandidate:
                    sample.componentJunctionCandidate,
                linkMeasureSquareMeters: sample.linkMeasureSquareMeters,
                productionFluidToIntersectionFraction: productionQ,
                exactGlobalFluidToIntersectionFraction: exactQ,
                absoluteFractionDifference: abs(productionQ - exactQ),
                productionBranch: productionNear
                    ? "near-q-le-half" : "far-q-gt-half",
                exactGlobalBranch: exactNear
                    ? "near-q-le-half" : "far-q-gt-half",
                branchChanged: productionNear != exactNear,
                productionCoefficients: production,
                exactGlobalCoefficients: exact,
                coefficientL1Difference: differences.reduce(0, +),
                maximumAbsoluteCoefficientDifference:
                    differences.max() ?? .infinity,
                wallProjectionCoefficientL1Difference:
                    differences[3] + differences[4],
                productionOperatorL1Norm: productionNorm,
                exactGlobalOperatorL1Norm: exactNorm,
                symmetricOperatorNormRatio: max(
                    productionNorm / max(exactNorm, 1e-30),
                    exactNorm / max(productionNorm, 1e-30)
                )
            )
        }
        let totalMeasure = samples.reduce(0) {
            $0 + $1.linkMeasureSquareMeters
        }
        func weightedRMS(
            _ keyPath: KeyPath<
                MetalIndexedBirdSurfaceLinkCoefficientSample, Double
            >
        ) -> Double {
            sqrt(samples.reduce(0) {
                let value = $1[keyPath: keyPath]
                return $0 + $1.linkMeasureSquareMeters * value * value
            } / max(totalMeasure, 1e-30))
        }
        let branchChanges = samples.filter(\.branchChanged)
        let finite = samples.allSatisfy { sample in
            [
                sample.linkMeasureSquareMeters,
                sample.productionFluidToIntersectionFraction,
                sample.exactGlobalFluidToIntersectionFraction,
                sample.absoluteFractionDifference,
                sample.coefficientL1Difference,
                sample.maximumAbsoluteCoefficientDifference,
                sample.wallProjectionCoefficientL1Difference,
                sample.productionOperatorL1Norm,
                sample.exactGlobalOperatorL1Norm,
                sample.symmetricOperatorNormRatio,
            ].allSatisfy(\.isFinite)
                && values(sample.productionCoefficients).allSatisfy(\.isFinite)
                && values(sample.exactGlobalCoefficients).allSatisfy(\.isFinite)
        }
        let sourceMatched = samples.count == source.sampleCount
            && zip(samples, source.samples).allSatisfy { sample, source in
                sample.sourceOutlierIndex == source.sourceOutlierIndex
                    && sample.partIdentifier == source.partIdentifier
                    && sample.componentName == source.componentName
                    && sample.directionIndex == source.directionIndex
                    && sample.cellCoordinate == source.cellCoordinate
                    && sample.componentJunctionCandidate
                        == source.componentJunctionCandidate
                    && sample.linkMeasureSquareMeters
                        == source.linkMeasureSquareMeters
                    && sample.productionFluidToIntersectionFraction
                        == source.productionFluidToIntersectionFraction
                    && sample.exactGlobalFluidToIntersectionFraction
                        == source.exactGlobalFluidToIntersectionFraction
            }
        return MetalIndexedBirdSurfaceLinkCoefficientCaseReport(
            schemaVersion: 1,
            referenceLengthCells: source.referenceLengthCells,
            runtimeSeconds:
                Date().timeIntervalSinceReferenceDate - started,
            sampleCount: samples.count,
            productionNearBranchCount: samples.filter {
                $0.productionBranch == "near-q-le-half"
            }.count,
            exactGlobalNearBranchCount: samples.filter {
                $0.exactGlobalBranch == "near-q-le-half"
            }.count,
            nearToFarBranchChangeCount: branchChanges.filter {
                $0.productionBranch == "near-q-le-half"
            }.count,
            farToNearBranchChangeCount: branchChanges.filter {
                $0.productionBranch == "far-q-gt-half"
            }.count,
            branchChangeCount: branchChanges.count,
            branchChangeLinkMeasureFraction: branchChanges.reduce(0) {
                $0 + $1.linkMeasureSquareMeters
            } / max(totalMeasure, 1e-30),
            weightedRMSFractionDifference:
                weightedRMS(\.absoluteFractionDifference),
            maximumFractionDifference: samples.map(
                \.absoluteFractionDifference
            ).max() ?? .infinity,
            weightedRMSCoefficientL1Difference:
                weightedRMS(\.coefficientL1Difference),
            maximumCoefficientL1Difference: samples.map(
                \.coefficientL1Difference
            ).max() ?? .infinity,
            maximumAbsoluteCoefficientDifference: samples.map(
                \.maximumAbsoluteCoefficientDifference
            ).max() ?? .infinity,
            weightedRMSWallProjectionCoefficientL1Difference:
                weightedRMS(\.wallProjectionCoefficientL1Difference),
            maximumSymmetricOperatorNormRatio: samples.map(
                \.symmetricOperatorNormRatio
            ).max() ?? .infinity,
            sourceRecordsMatched: sourceMatched,
            allValuesFinite: finite,
            samples: samples
        )
    }

    public static func collisionGridMovingWallLinkPopulationPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkCoefficientPreregistration:
            MetalIndexedBirdSurfaceLinkCoefficientPreregistration,
        sourceLinkCoefficientPreregistrationSHA256: String,
        linkCoefficientReport:
            MetalIndexedBirdSurfaceLinkCoefficientReport,
        sourceLinkCoefficientReportSHA256: String,
        temporalDurationPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration,
        sourceTemporalDurationPreregistrationSHA256: String,
        temporalDurationReport:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationReport,
        sourceTemporalDurationReportSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkPopulationPreregistration {
        let coefficientPreregistrationSHA =
            sourceLinkCoefficientPreregistrationSHA256.lowercased()
        let coefficientReportSHA =
            sourceLinkCoefficientReportSHA256.lowercased()
        let durationPreregistrationSHA =
            sourceTemporalDurationPreregistrationSHA256.lowercased()
        let durationReportSHA =
            sourceTemporalDurationReportSHA256.lowercased()
        guard [
            coefficientPreregistrationSHA, coefficientReportSHA,
            durationPreregistrationSHA, durationReportSHA,
        ].allSatisfy({
            $0.count == 64 && $0.allSatisfy(\.isHexDigit)
        }),
        linkCoefficientPreregistration.datasetIdentifier
            == surface.datasetIdentifier,
        linkCoefficientPreregistration.manifestSHA256
            == surface.manifestSHA256,
        linkCoefficientPreregistration.forceTargetIdentifier
            == target.datasetIdentifier,
        linkCoefficientPreregistration.forceTargetSHA256
            == target.targetSHA256,
        linkCoefficientPreregistration.passed,
        linkCoefficientReport.datasetIdentifier == surface.datasetIdentifier,
        linkCoefficientReport.manifestSHA256 == surface.manifestSHA256,
        linkCoefficientReport.forceTargetIdentifier == target.datasetIdentifier,
        linkCoefficientReport.forceTargetSHA256 == target.targetSHA256,
        linkCoefficientReport.sourceLinkCoefficientPreregistrationSHA256
            == coefficientPreregistrationSHA,
        linkCoefficientReport.sourceReproductionPassed,
        !linkCoefficientReport.coefficientInsensitiveGatePassed,
        linkCoefficientReport.classification
            == "branch-changing-coefficient-sensitive",
        linkCoefficientReport.d12.sampleCount == 8,
        linkCoefficientReport.d12.branchChangeCount == 3,
        linkCoefficientReport.validationOnlyPopulationReplayAuthorized,
        !linkCoefficientReport.productionModificationAuthorized,
        temporalDurationPreregistration.datasetIdentifier
            == surface.datasetIdentifier,
        temporalDurationPreregistration.manifestSHA256
            == surface.manifestSHA256,
        temporalDurationPreregistration.forceTargetIdentifier
            == target.datasetIdentifier,
        temporalDurationPreregistration.forceTargetSHA256
            == target.targetSHA256,
        temporalDurationPreregistration.selectedCollisionOperator
            == MetalIndexedBirdSurfaceCollisionOperator
                .positivityPreservingRecursiveRegularizedBGK.rawValue,
        temporalDurationPreregistration.movingWallNormalization
            == MetalIndexedBirdSurfaceMovingWallNormalization
                .preStepLocalDensity.rawValue,
        temporalDurationPreregistration.referenceLengthCells == [12, 16],
        temporalDurationPreregistration.extendedForceBinCount == 24,
        temporalDurationPreregistration.passed,
        temporalDurationReport.datasetIdentifier == surface.datasetIdentifier,
        temporalDurationReport.manifestSHA256 == surface.manifestSHA256,
        temporalDurationReport.forceTargetIdentifier == target.datasetIdentifier,
        temporalDurationReport.forceTargetSHA256 == target.targetSHA256,
        temporalDurationReport.sourceDurationPreregistrationSHA256
            == durationPreregistrationSHA,
        temporalDurationReport.extendedSampling.d12.referenceLengthCells == 12,
        temporalDurationReport.extendedSampling.d12.requestedSteps == 576,
        temporalDurationReport.extendedSampling.d12.ledgerResult.completedSteps
            == 576,
        temporalDurationReport.extendedSampling.d12.numericalCaseGatePassed,
        temporalDurationReport.extendedSampling.d12
            .fixedGeometryTopologyGatePassed,
        temporalDurationReport.classification
            == "persistent-fixed-wall-grid-disagreement",
        !temporalDurationReport.d20DiagnosticAuthorized,
        !temporalDurationReport.productionPromotionAuthorized else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-population preregistration requires the locked coefficient and 24-bin D12 duration archives"
            )
        }
        return MetalIndexedBirdSurfaceLinkPopulationPreregistration(
            schemaVersion: 1,
            contractRevision: 2,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkCoefficientPreregistrationSHA256:
                coefficientPreregistrationSHA,
            sourceLinkCoefficientReportSHA256: coefficientReportSHA,
            sourceTemporalDurationPreregistrationSHA256:
                durationPreregistrationSHA,
            sourceTemporalDurationReportSHA256: durationReportSHA,
            referenceLengthCells: 12,
            frozenSourceTimeSeconds:
                temporalDurationPreregistration.frozenSourceTimeSeconds,
            captureStartStep: 1,
            captureEndStep: 576,
            captureStride: 1,
            expectedLinkCount: 8,
            expectedUniqueBranchChangeCount: 3,
            expectedProductionFallbackLinkCount: 4,
            expectedExactGlobalFallbackLinkCount: 1,
            branchThreshold: 0.5,
            maximumAllowedProductionFractionDifference: 1e-6,
            maximumAllowedProductionReconstructionDifference: 1e-6,
            minimumMaterialPopulationRelativeRMSDifference: 0.10,
            minimumMaterialOutlierForceRelativeRMSDifference: 0.10,
            minimumPotentialGlobalForceRMSContribution: 0.01,
            minimumPotentialGlobalImpulseContribution: 0.01,
            selectionRule: (
                "Revision 2 retains every materiality threshold from the "
                    + "initial preregistration after its diagnostic replay "
                    + "revealed four production halfway fallbacks. Replay the "
                    + "already qualified topology-free D12 fixed-phase "
                    + "canonical for all 576 steps with RR3 collision and "
                    + "pre-step local-density moving-wall normalization. At "
                    + "every step capture the production reflected, farther, "
                    + "previous-incoming, density, and endpoint wall-projection "
                    + "primitives on all eight hashed D12 outlier links. Rebuild "
                    + "the effective production q within 1e-6, then substitute "
                    + "exact global q offline while holding the captured state "
                    + "fixed. An exact q <=0.5 retains halfway fallback when "
                    + "the production capture proves the farther node is solid. "
                    + "Material "
                    + "local response requires >=10% population and outlier-force "
                    + "relative RMS change. A D12 boundary A/B requires the delta "
                    + "to reach >=1% of global aerodynamic-force RMS or impulse."
            ),
            fixedInputs: (
                "Hashed coefficient and 24-bin duration archives; source time "
                    + "26.5 ms; D12 grid and 576-step window; RR3 collision; "
                    + "pre-step local density; all eight outlier identities; "
                    + "production and exact q; D3Q19 weights/directions; mode-6 "
                    + "conventional link exchange; four expected production "
                    + "fallback links and one expected exact-q fallback link. "
                    + "The counterfactual changes feasible q branches only and "
                    + "never writes populations or geometry."
            ),
            passed: true,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This fallback-aware validation-only replay measures realized "
                    + "q sensitivity "
                    + "within one topology-free D12 frozen-phase canonical. It "
                    + "does not implement an exact-root boundary, establish "
                    + "experimental force agreement, authorize production or "
                    + "D20, or generalize beyond the captured state window."
            )
        )
    }

    public static func collisionGridMovingWallLinkPopulation(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        linkCoefficientPreregistration:
            MetalIndexedBirdSurfaceLinkCoefficientPreregistration,
        sourceLinkCoefficientPreregistrationSHA256: String,
        linkCoefficientReport:
            MetalIndexedBirdSurfaceLinkCoefficientReport,
        sourceLinkCoefficientReportSHA256: String,
        temporalDurationPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration,
        sourceTemporalDurationPreregistrationSHA256: String,
        temporalDurationReport:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationReport,
        sourceTemporalDurationReportSHA256: String,
        preregistration:
            MetalIndexedBirdSurfaceLinkPopulationPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalIndexedBirdSurfaceLinkPopulationReport {
#if canImport(Metal)
        let expected = try
            collisionGridMovingWallLinkPopulationPreregistration(
                surface: surface,
                target: target,
                linkCoefficientPreregistration:
                    linkCoefficientPreregistration,
                sourceLinkCoefficientPreregistrationSHA256:
                    sourceLinkCoefficientPreregistrationSHA256,
                linkCoefficientReport: linkCoefficientReport,
                sourceLinkCoefficientReportSHA256:
                    sourceLinkCoefficientReportSHA256,
                temporalDurationPreregistration:
                    temporalDurationPreregistration,
                sourceTemporalDurationPreregistrationSHA256:
                    sourceTemporalDurationPreregistrationSHA256,
                temporalDurationReport: temporalDurationReport,
                sourceTemporalDurationReportSHA256:
                    sourceTemporalDurationReportSHA256
            )
        let preregistrationSHA = sourcePreregistrationSHA256.lowercased()
        guard preregistration == expected,
              preregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy(\.isHexDigit) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-population run does not match its locked preregistration"
            )
        }
        let plan = try refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: preregistration.referenceLengthCells
        )
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: preregistration.referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let capturedSteps = Array(stride(
            from: preregistration.captureStartStep,
            through: preregistration.captureEndStep,
            by: preregistration.captureStride
        ))
        let coefficientSamples = linkCoefficientReport.d12.samples
        let captureCoordinates = try coefficientSamples.map { sample in
            let direction = D3Q19.directions[sample.directionIndex]
            let fluid = SIMD3<Int>(
                sample.cellCoordinate.x + Int(direction.x),
                sample.cellCoordinate.y + Int(direction.y),
                sample.cellCoordinate.z + Int(direction.z)
            )
            guard fluid.x >= 0, fluid.x < replay.grid.x,
                  fluid.y >= 0, fluid.y < replay.grid.y,
                  fluid.z >= 0, fluid.z < replay.grid.z else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "link-population target fluid cell lies outside D12"
                )
            }
            return fluid
        }
        let captures = try captureCoordinates.map { coordinate in
            let linear = coordinate.x + replay.grid.x * (
                coordinate.y + replay.grid.y * coordinate.z
            )
            return try MetalIndexedBoundaryTermCapture(
                backend: backend,
                capturedSteps: capturedSteps,
                targetCellLinearIndex: linear
            )
        }
        let result = try replay.runCollisionMomentumClosure(
            plan: plan,
            collisionOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            maximumRelativeRMSResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            requestedSteps: preregistration.captureEndStep,
            movingWallNormalization: .preStepLocalDensity,
            fixedSurfaceTimeSeconds:
                Float(preregistration.frozenSourceTimeSeconds),
            boundaryTermCaptures: captures
        )
        let rawByLink = captures.map { $0.readRecords() }
        let bodyCenterFloat = 0.5 * (
            surface.minimumPositionMeters + surface.maximumPositionMeters
        )
        let bodyCenter = SIMD3<Double>(
            Double(bodyCenterFloat.x), Double(bodyCenterFloat.y),
            Double(bodyCenterFloat.z)
        )
        let origin = replay.domainOriginMeters
        let dx = plan.cellSizeMeters
        let forceScale = Double(replay.forceToPhysical)
        func cross(
            _ first: SIMD3<Double>,
            _ second: SIMD3<Double>
        ) -> SIMD3<Double> {
            SIMD3<Double>(
                first.y * second.z - first.z * second.y,
                first.z * second.x - first.x * second.z,
                first.x * second.y - first.y * second.x
            )
        }
        func reconstruct(
            q: Double,
            reflected: Double,
            farther: Double,
            previous: Double,
            wallCorrection: Double
        ) -> Double {
            if q <= preregistration.branchThreshold {
                return 2 * q * reflected + (1 - 2 * q) * farther
                    + wallCorrection
            }
            return (reflected + wallCorrection) / (2 * q)
                + (2 * q - 1) * previous / (2 * q)
        }
        var samples = [MetalIndexedBirdSurfaceLinkPopulationSample]()
        var steps = [MetalIndexedBirdSurfaceLinkPopulationStep]()
        samples.reserveCapacity(capturedSteps.count * coefficientSamples.count)
        steps.reserveCapacity(capturedSteps.count)
        var maximumFractionDifference = 0.0
        var maximumReconstructionDifference = 0.0
        var minimumDensity = Double.infinity
        var populationDifferenceEnergy = 0.0
        var populationReferenceEnergy = 0.0
        var sourceRecordsMatched = true
        for (stepOffset, step) in capturedSteps.enumerated() {
            var productionForce = SIMD3<Double>.zero
            var exactForce = SIMD3<Double>.zero
            var productionTorque = SIMD3<Double>.zero
            var exactTorque = SIMD3<Double>.zero
            for linkIndex in coefficientSamples.indices {
                let source = coefficientSamples[linkIndex]
                let raw = rawByLink[linkIndex][stepOffset][source.directionIndex]
                let directionRaw = D3Q19.directions[source.directionIndex]
                let direction = SIMD3<Double>(
                    Double(directionRaw.x), Double(directionRaw.y),
                    Double(directionRaw.z)
                )
                let productionQ = Double(raw.primitive.y)
                let exactQ = source.exactGlobalFluidToIntersectionFraction
                let productionFallback = raw.branch.x == 1
                let exactFallback = productionFallback
                    && exactQ <= preregistration.branchThreshold
                let productionBranch = productionFallback
                    ? "halfway-fallback" : source.productionBranch
                let exactBranch = exactFallback
                    ? "halfway-fallback" : source.exactGlobalBranch
                let branchChanged = productionBranch != exactBranch
                let reflected = Double(raw.primitive.x)
                let farther = Double(raw.captured.x)
                let previous = Double(raw.captured.y)
                let density = Double(raw.captured.z)
                let fluidProjection = Double(raw.captured.w)
                let solidProjection = Double(raw.alternatives.z)
                let productionProjection = Double(raw.alternatives.y)
                let exactProjection = exactFallback
                    ? productionProjection
                    : (1 - exactQ) * fluidProjection
                        + exactQ * solidProjection
                let productionWallCorrection = Double(raw.primitive.w)
                let exactWallCorrection = exactFallback
                    ? productionWallCorrection
                    : 2 * Double(D3Q19.weights[source.directionIndex])
                        * density * exactProjection
                        / Double(D3Q19.soundSpeedSquared)
                let productionValue = Double(raw.contributions.w)
                let productionIndependent = reconstruct(
                    q: productionQ,
                    reflected: reflected,
                    farther: farther,
                    previous: previous,
                    wallCorrection: productionWallCorrection
                )
                let exactValue = exactFallback
                    ? productionValue
                    : reconstruct(
                        q: exactQ,
                        reflected: reflected,
                        farther: farther,
                        previous: previous,
                        wallCorrection: exactWallCorrection
                    )
                let difference = exactValue - productionValue
                let productionLinkForce = -(
                    productionValue + reflected
                ) * direction * forceScale
                let exactLinkForce = -(
                    exactValue + reflected
                ) * direction * forceScale
                let forceDifference = exactLinkForce - productionLinkForce
                let fluidCoordinate = captureCoordinates[linkIndex]
                let fluidWorld = SIMD3<Double>(
                    Double(origin.x) + Double(fluidCoordinate.x) * dx,
                    Double(origin.y) + Double(fluidCoordinate.y) * dx,
                    Double(origin.z) + Double(fluidCoordinate.z) * dx
                )
                let productionPoint = fluidWorld
                    - productionQ * direction * dx
                let exactPoint = fluidWorld
                    - (exactFallback ? productionQ : exactQ)
                        * direction * dx
                let productionLinkTorque = cross(
                    productionPoint - bodyCenter,
                    productionLinkForce
                )
                let exactLinkTorque = cross(
                    exactPoint - bodyCenter,
                    exactLinkForce
                )
                let torqueDifference = exactLinkTorque
                    - productionLinkTorque
                let fractionDifference = abs(
                    productionQ
                        - (productionFallback
                            ? preregistration.branchThreshold
                            : source.productionFluidToIntersectionFraction)
                )
                let reconstructionDifference = abs(
                    productionIndependent - productionValue
                )
                maximumFractionDifference = max(
                    maximumFractionDifference,
                    fractionDifference
                )
                maximumReconstructionDifference = max(
                    maximumReconstructionDifference,
                    reconstructionDifference
                )
                minimumDensity = min(minimumDensity, density)
                populationDifferenceEnergy += difference * difference
                populationReferenceEnergy += 0.5 * (
                    productionValue * productionValue
                        + exactValue * exactValue
                )
                let sourceCoordinate = Int(raw.metadata.y)
                let expectedSource = source.cellCoordinate.x + replay.grid.x * (
                    source.cellCoordinate.y
                        + replay.grid.y * source.cellCoordinate.z
                )
                let productionBranchCodeMatches = productionFallback
                    ? raw.branch.x == 1
                    : raw.branch.x == 2
                sourceRecordsMatched = sourceRecordsMatched
                    && Int(raw.metadata.x) == source.directionIndex
                    && sourceCoordinate == expectedSource
                    && Int(raw.metadata.w) == source.partIdentifier
                    && productionBranchCodeMatches && raw.branch.y == 1
                    && raw.branch.z == 1 && raw.branch.w == 0
                    && productionQ <= preregistration.branchThreshold
                samples.append(
                    MetalIndexedBirdSurfaceLinkPopulationSample(
                        step: step,
                        sourceOutlierIndex: source.sourceOutlierIndex,
                        partIdentifier: source.partIdentifier,
                        componentName: source.componentName,
                        directionIndex: source.directionIndex,
                        solidCellCoordinate: source.cellCoordinate,
                        fluidCellCoordinate: fluidCoordinate,
                        rasterFluidToIntersectionFraction:
                            source.productionFluidToIntersectionFraction,
                        productionFluidToIntersectionFraction: productionQ,
                        exactGlobalFluidToIntersectionFraction: exactQ,
                        productionBranch: productionBranch,
                        exactGlobalBranch: exactBranch,
                        branchChanged: branchChanged,
                        productionFallbackApplied: productionFallback,
                        exactGlobalFallbackApplied: exactFallback,
                        reflectedPopulation: reflected,
                        fartherOutgoingPopulation: farther,
                        previousIncomingPopulation: previous,
                        preStepLocalDensity: density,
                        fluidEndpointWallProjectionLattice: fluidProjection,
                        solidEndpointWallProjectionLattice: solidProjection,
                        productionWallProjectionLattice: productionProjection,
                        exactGlobalWallProjectionLattice: exactProjection,
                        productionRawWallCorrection:
                            productionWallCorrection,
                        exactGlobalRawWallCorrection: exactWallCorrection,
                        productionReconstructedPopulation: productionValue,
                        independentlyReconstructedProductionPopulation:
                            productionIndependent,
                        exactGlobalReconstructedPopulation: exactValue,
                        populationDifference: difference,
                        productionReconstructionDifference:
                            reconstructionDifference,
                        productionLinkForceNewtons: productionLinkForce,
                        exactGlobalLinkForceNewtons: exactLinkForce,
                        linkForceDifferenceNewtons: forceDifference,
                        productionLinkTorqueNewtonMeters:
                            productionLinkTorque,
                        exactGlobalLinkTorqueNewtonMeters: exactLinkTorque,
                        linkTorqueDifferenceNewtonMeters: torqueDifference
                    )
                )
                productionForce += productionLinkForce
                exactForce += exactLinkForce
                productionTorque += productionLinkTorque
                exactTorque += exactLinkTorque
            }
            let aerodynamic = result.samples[step - 1]
                .aerodynamicForceNewtons
            steps.append(MetalIndexedBirdSurfaceLinkPopulationStep(
                step: step,
                aerodynamicForceNewtons: aerodynamic,
                productionOutlierForceNewtons: productionForce,
                exactGlobalOutlierForceNewtons: exactForce,
                outlierForceDifferenceNewtons: exactForce - productionForce,
                productionOutlierTorqueNewtonMeters: productionTorque,
                exactGlobalOutlierTorqueNewtonMeters: exactTorque,
                outlierTorqueDifferenceNewtonMeters:
                    exactTorque - productionTorque
            ))
        }
        func relativeRMS(
            _ first: [SIMD3<Double>],
            _ second: [SIMD3<Double>]
        ) -> Double {
            func squaredMagnitude(_ value: SIMD3<Double>) -> Double {
                value.x * value.x + value.y * value.y + value.z * value.z
            }
            var differenceEnergy = 0.0
            var referenceEnergy = 0.0
            for index in first.indices {
                let difference = second[index] - first[index]
                differenceEnergy += squaredMagnitude(difference)
                referenceEnergy += 0.5 * (
                    squaredMagnitude(first[index])
                        + squaredMagnitude(second[index])
                )
            }
            return sqrt(differenceEnergy / max(referenceEnergy, 1e-30))
        }
        let productionForces = steps.map(\.productionOutlierForceNewtons)
        let exactForces = steps.map(\.exactGlobalOutlierForceNewtons)
        let deltaForces = steps.map(\.outlierForceDifferenceNewtons)
        let productionTorques = steps.map(
            \.productionOutlierTorqueNewtonMeters
        )
        let exactTorques = steps.map(\.exactGlobalOutlierTorqueNewtonMeters)
        let deltaTorques = steps.map(\.outlierTorqueDifferenceNewtonMeters)
        let aerodynamicForces = steps.map(\.aerodynamicForceNewtons)
        let deltaForceRMS = vectorRMS(deltaForces)
        let deltaTorqueRMS = vectorRMS(deltaTorques)
        let aerodynamicRMS = vectorRMS(aerodynamicForces)
        let dt = plan.fluidTimeStepSeconds
        let deltaImpulse = deltaForces.reduce(.zero, +) * dt
        let aerodynamicImpulse = aerodynamicForces.reduce(.zero, +) * dt
        let firstStepSamples = samples.filter {
            $0.step == preregistration.captureStartStep
        }
        let metrics = MetalIndexedBirdSurfaceLinkPopulationMetrics(
            uniqueBranchChangeCount: firstStepSamples.filter(
                \.branchChanged
            ).count,
            productionFallbackLinkCount: firstStepSamples.filter(
                \.productionFallbackApplied
            ).count,
            exactGlobalFallbackLinkCount: firstStepSamples.filter(
                \.exactGlobalFallbackApplied
            ).count,
            capturedSampleCount: samples.count,
            populationRelativeRMSDifference: sqrt(
                populationDifferenceEnergy
                    / max(populationReferenceEnergy, 1e-30)
            ),
            outlierForceRelativeRMSDifference: relativeRMS(
                productionForces,
                exactForces
            ),
            outlierTorqueRelativeRMSDifference: relativeRMS(
                productionTorques,
                exactTorques
            ),
            deltaForceRMSNewtons: deltaForceRMS,
            deltaTorqueRMSNewtonMeters: deltaTorqueRMS,
            globalAerodynamicForceRMSNewtons: aerodynamicRMS,
            deltaForceToGlobalAerodynamicForceRMSRatio:
                deltaForceRMS / max(aerodynamicRMS, 1e-30),
            deltaForceImpulseNewtonSeconds: deltaImpulse,
            globalAerodynamicForceImpulseNewtonSeconds:
                aerodynamicImpulse,
            deltaImpulseToGlobalAerodynamicImpulseRatio: vectorMagnitude(
                deltaImpulse
            ) / max(vectorMagnitude(aerodynamicImpulse), 1e-30),
            maximumStepDeltaForceToAerodynamicForceRatio: zip(
                deltaForces,
                aerodynamicForces
            ).map {
                vectorMagnitude($0) / max(vectorMagnitude($1), 1e-30)
            }.max() ?? .infinity,
            maximumProductionFractionDifference:
                maximumFractionDifference,
            maximumProductionReconstructionDifference:
                maximumReconstructionDifference,
            minimumPreStepLocalDensity:
                minimumDensity.isFinite ? minimumDensity : 0
        )
        let sourceReproduced = sourceRecordsMatched
            && samples.count == capturedSteps.count
                * preregistration.expectedLinkCount
            && metrics.uniqueBranchChangeCount
                == preregistration.expectedUniqueBranchChangeCount
            && metrics.productionFallbackLinkCount
                == preregistration.expectedProductionFallbackLinkCount
            && metrics.exactGlobalFallbackLinkCount
                == preregistration.expectedExactGlobalFallbackLinkCount
            && metrics.maximumProductionFractionDifference
                <= preregistration.maximumAllowedProductionFractionDifference
            && metrics.maximumProductionReconstructionDifference
                <= preregistration
                    .maximumAllowedProductionReconstructionDifference
            && metrics.minimumPreStepLocalDensity > 0
            && result.completedSteps == preregistration.captureEndStep
            && result.samples.count == preregistration.captureEndStep
            && result.momentumClosurePassed
            && result.sampledPopulationPositivityPassed
            && result.allValuesFinite
        let populationMaterial = sourceReproduced
            && metrics.populationRelativeRMSDifference
                >= preregistration
                    .minimumMaterialPopulationRelativeRMSDifference
        let outlierForceMaterial = sourceReproduced
            && metrics.outlierForceRelativeRMSDifference
                >= preregistration
                    .minimumMaterialOutlierForceRelativeRMSDifference
        let globalForcePotential = sourceReproduced
            && metrics.deltaForceToGlobalAerodynamicForceRMSRatio
                >= preregistration.minimumPotentialGlobalForceRMSContribution
        let globalImpulsePotential = sourceReproduced
            && metrics.deltaImpulseToGlobalAerodynamicImpulseRatio
                >= preregistration.minimumPotentialGlobalImpulseContribution
        let localMaterial = populationMaterial && outlierForceMaterial
        let globallyMaterial = localMaterial
            && (globalForcePotential || globalImpulsePotential)
        let classification = !sourceReproduced
            ? "invalid-realized-population-replay"
            : !localMaterial
                ? "realized-population-insensitive"
                : globallyMaterial
                    ? "realized-force-significant"
                    : "realized-link-sensitive-globally-small"
        let boundaryABAuthorized = classification
            == "realized-force-significant"
        let d16Authorized = classification
            == "realized-link-sensitive-globally-small"
        let nextAction: String
        switch classification {
        case "realized-force-significant":
            nextAction = "Implement a validation-only D12 exact-global-q boundary A/B with every other solver input fixed; production remains unchanged until population positivity, momentum closure, and force-history improvement pass."
        case "realized-link-sensitive-globally-small":
            nextAction = "Repeat only this captured-primitive replay on the already qualified 768-step D16 fixed-phase window, where all seven archived links cross branches, before considering a boundary kernel A/B."
        case "realized-population-insensitive":
            nextAction = "Reject these sparse q outliers as the dominant fixed-phase force discrepancy and return to distributed wall-velocity or non-outlier interpolation diagnostics without changing production."
        default:
            nextAction = "Repair the capture provenance or production reconstruction mismatch before drawing a force conclusion."
        }
        return MetalIndexedBirdSurfaceLinkPopulationReport(
            schemaVersion: 2,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceLinkPopulationPreregistrationSHA256:
                preregistrationSHA,
            sourceLinkCoefficientPreregistrationSHA256:
                expected.sourceLinkCoefficientPreregistrationSHA256,
            sourceLinkCoefficientReportSHA256:
                expected.sourceLinkCoefficientReportSHA256,
            sourceTemporalDurationPreregistrationSHA256:
                expected.sourceTemporalDurationPreregistrationSHA256,
            sourceTemporalDurationReportSHA256:
                expected.sourceTemporalDurationReportSHA256,
            referenceLengthCells: preregistration.referenceLengthCells,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            cellSizeMeters: dx,
            fluidTimeStepSeconds: dt,
            forceToPhysical: forceScale,
            domainOriginMeters: SIMD3<Double>(
                Double(origin.x), Double(origin.y), Double(origin.z)
            ),
            bodyCenterMeters: bodyCenter,
            frozenSourceTimeSeconds:
                preregistration.frozenSourceTimeSeconds,
            requestedSteps: preregistration.captureEndStep,
            completedSteps: result.completedSteps,
            runtimeSeconds: result.runtimeSeconds,
            samples: samples,
            steps: steps,
            metrics: metrics,
            sourceReproductionPassed: sourceReproduced,
            populationMaterialityPassed: populationMaterial,
            outlierForceMaterialityPassed: outlierForceMaterial,
            potentialGlobalForceContributionPassed: globalForcePotential,
            potentialGlobalImpulseContributionPassed:
                globalImpulsePotential,
            classification: classification,
            validationOnlyBoundaryABAuthorized: boundaryABAuthorized,
            d16CaptureAuthorized: d16Authorized,
            d20DiagnosticAuthorized: false,
            productionModificationAuthorized: false,
            rawSpatialGateModified: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: (
                "The full-window D12 production-primitive replay is "
                    + classification + ". It changes q offline only and leaves "
                    + "the solver state and production boundary untouched."
            ),
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

#if canImport(Metal)
    private static func linkGeometryTriangleQuadrature(
        surface: MeasuredBirdSurfaceSequence,
        timeSeconds: Float,
        halfThicknessMeters: Float
    ) -> [MetalIndexedBirdSurfaceTriangleQuadratureComponent] {
        let states = (0..<surface.vertexCount).map {
            surface.state(timeSeconds: timeSeconds, vertexIndex: $0)
        }
        let positions = states.map(\.positionMeters)
        let velocities = states.map(\.velocityMetersPerSecond)
        let representativeDirections = stride(from: 1, through: 17, by: 2)
        func cross(_ first: SIMD3<Float>, _ second: SIMD3<Float>)
            -> SIMD3<Float>
        {
            SIMD3<Float>(
                first.y * second.z - first.z * second.y,
                first.z * second.x - first.x * second.z,
                first.x * second.y - first.y * second.x
            )
        }
        func d3q19MeasureFactor(_ normal: SIMD3<Float>) -> Double {
            representativeDirections.reduce(0.0) { result, direction in
                let raw = D3Q19.directions[direction]
                let projection = abs(
                    Double(raw.x) * Double(normal.x)
                        + Double(raw.y) * Double(normal.y)
                        + Double(raw.z) * Double(normal.z)
                )
                return result + 6.0 * Double(D3Q19.weights[direction])
                    * projection
            }
        }
        struct EdgeKey: Hashable {
            let lower: Int
            let upper: Int
        }
        struct EdgeRecord {
            var count: Int
            let first: Int
            let second: Int
            let adjacentNormal: SIMD3<Float>
        }
        return surface.components.map { component in
            var midSurfaceArea = 0.0
            var measure = 0.0
            var velocityIntegral = SIMD3<Double>.zero
            var speedSquaredIntegral = 0.0
            var edges = [EdgeKey: EdgeRecord]()
            let triangleRange = component.triangleOffset..<(component
                .triangleOffset + component.triangleCount)
            for triangle in triangleRange {
                let indices = surface.triangle(triangle)
                let ia = Int(indices.x)
                let ib = Int(indices.y)
                let ic = Int(indices.z)
                let a = positions[ia]
                let b = positions[ib]
                let c = positions[ic]
                let rawNormal = cross(b - a, c - a)
                let twiceArea = vectorLength(rawNormal)
                guard twiceArea > 0 else { continue }
                let normal = rawNormal / twiceArea
                let area = 0.5 * Double(twiceArea)
                let triangleMeasure = 2.0 * area
                    * d3q19MeasureFactor(normal)
                let velocity = SIMD3<Double>(
                    (velocities[ia] + velocities[ib] + velocities[ic]) / 3
                )
                let speedSquared = velocity.x * velocity.x
                    + velocity.y * velocity.y + velocity.z * velocity.z
                midSurfaceArea += area
                measure += triangleMeasure
                velocityIntegral += triangleMeasure * velocity
                speedSquaredIntegral += triangleMeasure * speedSquared
                for (first, second) in [(ia, ib), (ib, ic), (ic, ia)] {
                    let key = EdgeKey(
                        lower: min(first, second),
                        upper: max(first, second)
                    )
                    if var record = edges[key] {
                        record.count += 1
                        edges[key] = record
                    } else {
                        edges[key] = EdgeRecord(
                            count: 1,
                            first: first,
                            second: second,
                            adjacentNormal: normal
                        )
                    }
                }
            }
            let boundaryEdges = edges.values.filter { $0.count == 1 }
            for edge in boundaryEdges {
                let edgeVector = positions[edge.second] - positions[edge.first]
                let edgeLength = vectorLength(edgeVector)
                guard edgeLength > 0 else { continue }
                let rawCapNormal = cross(edgeVector, edge.adjacentNormal)
                let capNormalLength = vectorLength(rawCapNormal)
                guard capNormalLength > 0 else { continue }
                let capNormal = rawCapNormal / capNormalLength
                let capArea = 2.0 * Double(halfThicknessMeters)
                    * Double(edgeLength)
                let capMeasure = capArea * d3q19MeasureFactor(capNormal)
                let velocity = SIMD3<Double>(
                    0.5 * (velocities[edge.first] + velocities[edge.second])
                )
                let speedSquared = velocity.x * velocity.x
                    + velocity.y * velocity.y + velocity.z * velocity.z
                measure += capMeasure
                velocityIntegral += capMeasure * velocity
                speedSquaredIntegral += capMeasure * speedSquared
            }
            return MetalIndexedBirdSurfaceTriangleQuadratureComponent(
                partIdentifier: Int(component.partIdentifier),
                componentName: component.name,
                triangleCount: component.triangleCount,
                boundaryEdgeCount: boundaryEdges.count,
                midSurfaceAreaSquareMeters: midSurfaceArea,
                thickenedD3Q19MeasureSquareMeters: measure,
                meanWallVelocityMetersPerSecond:
                    measure > 0 ? velocityIntegral / measure : .zero,
                rmsWallSpeedMetersPerSecond:
                    measure > 0
                        ? sqrt(max(0, speedSquaredIntegral / measure))
                        : 0
            )
        }
    }

    private static func linkGeometryBins(
        partIdentifiers: [UInt8],
        wallVelocityAndDistance: [SIMD4<Float>],
        grid: GridSize,
        cellSizeMeters: Double,
        velocityToLattice: Float,
        histogramBinCount: Int
    ) -> [MetalIndexedBirdSurfaceLinkGeometryBin] {
        let binCount = 4 * (D3Q19.count - 1)
        var counts = [Int](repeating: 0, count: binCount)
        var measures = [Double](repeating: 0, count: binCount)
        var qIntegrals = [Double](repeating: 0, count: binCount)
        var qSquaredIntegrals = [Double](repeating: 0, count: binCount)
        var histograms = [[Double]](
            repeating: [Double](repeating: 0, count: histogramBinCount),
            count: binCount
        )
        var velocityIntegrals = [SIMD3<Double>](
            repeating: .zero,
            count: binCount
        )
        var speedSquaredIntegrals = [Double](repeating: 0, count: binCount)
        let dxSquared = cellSizeMeters * cellSizeMeters
        for index in partIdentifiers.indices {
            let part = Int(partIdentifiers[index])
            guard (1...4).contains(part) else { continue }
            let x = index % grid.x
            let yz = index / grid.x
            let y = yz % grid.y
            let z = yz / grid.y
            let solidDistance = min(
                Double(wallVelocityAndDistance[index].w),
                0
            )
            let latticeVelocity = wallVelocityAndDistance[index]
            let physicalVelocity = SIMD3<Double>(
                Double(latticeVelocity.x / velocityToLattice),
                Double(latticeVelocity.y / velocityToLattice),
                Double(latticeVelocity.z / velocityToLattice)
            )
            let speedSquared = physicalVelocity.x * physicalVelocity.x
                + physicalVelocity.y * physicalVelocity.y
                + physicalVelocity.z * physicalVelocity.z
            for direction in 1..<D3Q19.count {
                let raw = D3Q19.directions[direction]
                let nx = x + Int(raw.x)
                let ny = y + Int(raw.y)
                let nz = z + Int(raw.z)
                guard nx >= 0, nx < grid.x,
                      ny >= 0, ny < grid.y,
                      nz >= 0, nz < grid.z else { continue }
                let neighbor = nx + grid.x * (ny + grid.y * nz)
                guard partIdentifiers[neighbor] == 0 else { continue }
                let fluidDistance = max(
                    Double(wallVelocityAndDistance[neighbor].w),
                    0
                )
                let fraction = min(
                    1,
                    max(
                        1e-4,
                        fluidDistance
                            / max(fluidDistance - solidDistance, 1e-6)
                    )
                )
                let measure = 6.0 * Double(D3Q19.weights[direction])
                    * dxSquared
                let bin = (part - 1) * (D3Q19.count - 1) + direction - 1
                let histogramIndex = min(
                    Int(floor(fraction * Double(histogramBinCount))),
                    histogramBinCount - 1
                )
                counts[bin] += 1
                measures[bin] += measure
                qIntegrals[bin] += measure * fraction
                qSquaredIntegrals[bin] += measure * fraction * fraction
                histograms[bin][histogramIndex] += measure
                velocityIntegrals[bin] += measure * physicalVelocity
                speedSquaredIntegrals[bin] += measure * speedSquared
            }
        }
        return (1...4).flatMap { part in
            (1..<D3Q19.count).map { direction in
                let index = (part - 1) * (D3Q19.count - 1) + direction - 1
                return MetalIndexedBirdSurfaceLinkGeometryBin(
                    partIdentifier: part,
                    directionIndex: direction,
                    linkCount: counts[index],
                    linkMeasureSquareMeters: measures[index],
                    interpolationFractionIntegralSquareMeters:
                        qIntegrals[index],
                    interpolationFractionSquaredIntegralSquareMeters:
                        qSquaredIntegrals[index],
                    interpolationFractionMeasureHistogram: histograms[index],
                    wallVelocityIntegralSquareMeterMetersPerSecond:
                        velocityIntegrals[index],
                    wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared:
                        speedSquaredIntegrals[index]
                )
            }
        }
    }

    private static func linkGeometryComponents(
        bins: [MetalIndexedBirdSurfaceLinkGeometryBin],
        surface: MeasuredBirdSurfaceSequence,
        quadrature: [MetalIndexedBirdSurfaceTriangleQuadratureComponent],
        histogramBinCount: Int
    ) -> [MetalIndexedBirdSurfaceLinkGeometryComponent] {
        surface.components.map { component in
            let part = Int(component.partIdentifier)
            let selected = bins.filter { $0.partIdentifier == part }
            let measure = selected.reduce(0) {
                $0 + $1.linkMeasureSquareMeters
            }
            let qIntegral = selected.reduce(0) {
                $0 + $1.interpolationFractionIntegralSquareMeters
            }
            let qSquaredIntegral = selected.reduce(0) {
                $0 + $1.interpolationFractionSquaredIntegralSquareMeters
            }
            var histogram = [Double](
                repeating: 0,
                count: histogramBinCount
            )
            var velocityIntegral = SIMD3<Double>.zero
            var speedSquaredIntegral = 0.0
            for bin in selected {
                velocityIntegral +=
                    bin.wallVelocityIntegralSquareMeterMetersPerSecond
                speedSquaredIntegral += bin
                    .wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared
                for index in histogram.indices {
                    histogram[index] +=
                        bin.interpolationFractionMeasureHistogram[index]
                }
            }
            let reference = quadrature.first {
                $0.partIdentifier == part
            }!
            let meanQ = measure > 0 ? qIntegral / measure : 0
            let meanVelocity = measure > 0
                ? velocityIntegral / measure : .zero
            let rmsSpeed = measure > 0
                ? sqrt(max(0, speedSquaredIntegral / measure)) : 0
            let referenceRMS = max(reference.rmsWallSpeedMetersPerSecond, 1e-30)
            return MetalIndexedBirdSurfaceLinkGeometryComponent(
                partIdentifier: part,
                componentName: component.name,
                linkCount: selected.reduce(0) { $0 + $1.linkCount },
                linkMeasureSquareMeters: measure,
                interpolationFractionMean: meanQ,
                interpolationFractionStandardDeviation: sqrt(max(
                    0,
                    measure > 0 ? qSquaredIntegral / measure - meanQ * meanQ : 0
                )),
                interpolationFractionMeasureHistogram: histogram,
                meanWallVelocityMetersPerSecond: meanVelocity,
                rmsWallSpeedMetersPerSecond: rmsSpeed,
                triangleQuadrature: reference,
                linkToQuadratureMeasureRatio: measure
                    / max(reference.thickenedD3Q19MeasureSquareMeters, 1e-30),
                meanVelocityErrorRelativeToQuadratureRMS:
                    vectorMagnitude(
                        meanVelocity - reference.meanWallVelocityMetersPerSecond
                    ) / referenceRMS,
                rmsSpeedRelativeError: abs(
                    rmsSpeed - reference.rmsWallSpeedMetersPerSecond
                ) / referenceRMS
            )
        }
    }

    private static func linkGeometryCase(
        backend: MetalBackend,
        surface: MeasuredBirdSurfaceSequence,
        plan: MetalIndexedBirdSurfacePilotPlan,
        referenceLengthCells: Int,
        timeSeconds: Float,
        quadrature: [MetalIndexedBirdSurfaceTriangleQuadratureComponent],
        preregistration: MetalIndexedBirdSurfaceLinkGeometryPreregistration
    ) throws -> MetalIndexedBirdSurfaceLinkGeometryCaseReport {
        let start = Date().timeIntervalSinceReferenceDate
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: 0
        )
        let snapshot = try replay.snapshot(
            timeSeconds: timeSeconds,
            includeWallField: true
        )
        guard let metalWall = snapshot.wallVelocityAndDistance else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-geometry snapshot omitted its wall field"
            )
        }
        let cpu = replay.cpuRaster(timeSeconds: timeSeconds)
        let metalBins = linkGeometryBins(
            partIdentifiers: snapshot.partIdentifiers,
            wallVelocityAndDistance: metalWall,
            grid: replay.grid,
            cellSizeMeters: plan.cellSizeMeters,
            velocityToLattice: replay.velocityToLattice,
            histogramBinCount: preregistration.interpolationFractionBinCount
        )
        let cpuBins = linkGeometryBins(
            partIdentifiers: cpu.partIdentifiers,
            wallVelocityAndDistance: cpu.wallVelocityAndDistance,
            grid: replay.grid,
            cellSizeMeters: plan.cellSizeMeters,
            velocityToLattice: replay.velocityToLattice,
            histogramBinCount: preregistration.interpolationFractionBinCount
        )
        var maskMismatch = 0
        var maximumVelocityDifference = 0.0
        var maximumDistanceDifference = 0.0
        for index in snapshot.partIdentifiers.indices {
            if snapshot.partIdentifiers[index] != cpu.partIdentifiers[index] {
                maskMismatch += 1
            }
            let delta = metalWall[index] - cpu.wallVelocityAndDistance[index]
            maximumVelocityDifference = max(
                maximumVelocityDifference,
                Double(vectorLength(SIMD3<Float>(delta.x, delta.y, delta.z)))
            )
            maximumDistanceDifference = max(
                maximumDistanceDifference,
                Double(abs(delta.w))
            )
        }
        let exactLinkCountMatch = zip(metalBins, cpuBins).allSatisfy {
            $0.linkCount == $1.linkCount
        }
        let maximumLinkMeasureDifference = zip(metalBins, cpuBins).reduce(0.0) {
            max($0, abs($1.0.linkMeasureSquareMeters
                - $1.1.linkMeasureSquareMeters))
        }
        func relativeDifference(_ first: Double, _ second: Double) -> Double {
            abs(first - second) / max(abs(first), abs(second), 1e-30)
        }
        var maximumAggregateDifference = 0.0
        for (metal, cpu) in zip(metalBins, cpuBins) {
            maximumAggregateDifference = max(
                maximumAggregateDifference,
                relativeDifference(
                    metal.interpolationFractionIntegralSquareMeters,
                    cpu.interpolationFractionIntegralSquareMeters
                ),
                relativeDifference(
                    metal.interpolationFractionSquaredIntegralSquareMeters,
                    cpu.interpolationFractionSquaredIntegralSquareMeters
                ),
                vectorMagnitude(
                    metal.wallVelocityIntegralSquareMeterMetersPerSecond
                        - cpu.wallVelocityIntegralSquareMeterMetersPerSecond
                ) / max(
                    vectorMagnitude(
                        metal.wallVelocityIntegralSquareMeterMetersPerSecond
                    ),
                    vectorMagnitude(
                        cpu.wallVelocityIntegralSquareMeterMetersPerSecond
                    ),
                    1e-30
                ),
                relativeDifference(
                    metal.wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared,
                    cpu.wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared
                )
            )
            let measure = max(
                metal.linkMeasureSquareMeters,
                cpu.linkMeasureSquareMeters,
                1e-30
            )
            for (metalValue, cpuValue) in zip(
                metal.interpolationFractionMeasureHistogram,
                cpu.interpolationFractionMeasureHistogram
            ) {
                maximumAggregateDifference = max(
                    maximumAggregateDifference,
                    abs(metalValue - cpuValue) / measure
                )
            }
        }
        let components = linkGeometryComponents(
            bins: metalBins,
            surface: surface,
            quadrature: quadrature,
            histogramBinCount: preregistration.interpolationFractionBinCount
        )
        let finite = metalBins.allSatisfy {
            $0.linkMeasureSquareMeters.isFinite
                && $0.interpolationFractionIntegralSquareMeters.isFinite
                && $0.interpolationFractionSquaredIntegralSquareMeters.isFinite
                && $0.interpolationFractionMeasureHistogram.allSatisfy(\.isFinite)
                && $0.wallVelocityIntegralSquareMeterMetersPerSecond.x.isFinite
                && $0.wallVelocityIntegralSquareMeterMetersPerSecond.y.isFinite
                && $0.wallVelocityIntegralSquareMeterMetersPerSecond.z.isFinite
                && $0.wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared
                    .isFinite
        } && components.allSatisfy {
            $0.linkMeasureSquareMeters.isFinite
                && $0.interpolationFractionMean.isFinite
                && $0.interpolationFractionStandardDeviation.isFinite
                && $0.meanWallVelocityMetersPerSecond.x.isFinite
                && $0.meanWallVelocityMetersPerSecond.y.isFinite
                && $0.meanWallVelocityMetersPerSecond.z.isFinite
                && $0.rmsWallSpeedMetersPerSecond.isFinite
                && $0.linkToQuadratureMeasureRatio.isFinite
                && $0.meanVelocityErrorRelativeToQuadratureRMS.isFinite
                && $0.rmsSpeedRelativeError.isFinite
        }
        let parity = maskMismatch
                <= preregistration.maximumAllowedMetalCPUMaskMismatchCells
            && maximumVelocityDifference
                <= preregistration
                    .maximumAllowedMetalCPUWallVelocityDifferenceLattice
            && maximumDistanceDifference
                <= preregistration
                    .maximumAllowedMetalCPUSignedDistanceDifferenceCells
            && exactLinkCountMatch
            && maximumLinkMeasureDifference <= 1e-15
            && maximumAggregateDifference
                <= preregistration
                    .maximumAllowedMetalCPUAggregateRelativeDifference
            && finite
        return MetalIndexedBirdSurfaceLinkGeometryCaseReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            referenceLengthCells: referenceLengthCells,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            cellSizeMeters: plan.cellSizeMeters,
            halfThicknessMeters: plan.cellSizeMeters * plan.halfThicknessCells,
            frozenSourceTimeSeconds: Double(timeSeconds),
            runtimeSeconds: Date().timeIntervalSinceReferenceDate - start,
            metalBins: metalBins,
            cpuBins: cpuBins,
            components: components,
            metalCPUMaskMismatchCellCount: maskMismatch,
            maximumMetalCPUWallVelocityDifferenceLattice:
                maximumVelocityDifference,
            maximumMetalCPUSignedDistanceDifferenceCells:
                maximumDistanceDifference,
            metalCPUExactLinkCountMatch: exactLinkCountMatch,
            metalCPUMaximumLinkMeasureDifferenceSquareMeters:
                maximumLinkMeasureDifference,
            maximumMetalCPUAggregateRelativeDifference:
                maximumAggregateDifference,
            allValuesFinite: finite,
            parityGatePassed: parity
        )
    }

    private static func linkVelocityCase(
        backend: MetalBackend,
        surface: MeasuredBirdSurfaceSequence,
        plan: MetalIndexedBirdSurfacePilotPlan,
        referenceLengthCells: Int,
        timeSeconds: Float,
        sourceCase: MetalIndexedBirdSurfaceLinkGeometryCaseReport,
        maximumSourceError: Double
    ) throws -> MetalIndexedBirdSurfaceLinkVelocityCaseReport {
        let start = Date().timeIntervalSinceReferenceDate
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: 0
        )
        let snapshot = try replay.snapshot(
            timeSeconds: timeSeconds,
            includeWallField: true
        )
        guard let wall = snapshot.wallVelocityAndDistance else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-velocity snapshot omitted its wall field"
            )
        }
        let states = (0..<surface.vertexCount).map {
            surface.state(timeSeconds: timeSeconds, vertexIndex: $0)
        }
        let positions = states.map(\.positionMeters)
        let velocities = states.map(\.velocityMetersPerSecond)
        let componentByPart = Dictionary(uniqueKeysWithValues:
            surface.components.map { (Int($0.partIdentifier), $0) }
        )
        let binCount = 4 * (D3Q19.count - 1)
        var counts = [Int](repeating: 0, count: binCount)
        var measures = [Double](repeating: 0, count: binCount)
        var endpointVelocity = [SIMD3<Double>](
            repeating: .zero,
            count: binCount
        )
        var exactVelocity = [SIMD3<Double>](
            repeating: .zero,
            count: binCount
        )
        var endpointSpeedSquared = [Double](repeating: 0, count: binCount)
        var exactSpeedSquared = [Double](repeating: 0, count: binCount)
        var offsetResidualSquared = [Double](repeating: 0, count: binCount)
        var offsetMaximum = [Double](repeating: 0, count: binCount)
        let dx = Float(plan.cellSizeMeters)
        let dxSquared = Double(dx * dx)
        let halfThickness = Float(
            plan.cellSizeMeters * plan.halfThicknessCells
        )
        let origin = replay.domainOriginMeters
        for index in snapshot.partIdentifiers.indices {
            let part = Int(snapshot.partIdentifiers[index])
            guard let component = componentByPart[part] else { continue }
            let x = index % replay.grid.x
            let yz = index / replay.grid.x
            let y = yz % replay.grid.y
            let z = yz / replay.grid.y
            let solidWorld = origin + SIMD3<Float>(
                (Float(x) + 0.5) * dx,
                (Float(y) + 0.5) * dx,
                (Float(z) + 0.5) * dx
            )
            let solidDistance = min(Double(wall[index].w), 0)
            let solidVelocity = SIMD3<Double>(
                Double(wall[index].x / replay.velocityToLattice),
                Double(wall[index].y / replay.velocityToLattice),
                Double(wall[index].z / replay.velocityToLattice)
            )
            for direction in 1..<D3Q19.count {
                let raw = D3Q19.directions[direction]
                let nx = x + Int(raw.x)
                let ny = y + Int(raw.y)
                let nz = z + Int(raw.z)
                guard nx >= 0, nx < replay.grid.x,
                      ny >= 0, ny < replay.grid.y,
                      nz >= 0, nz < replay.grid.z else { continue }
                let neighbor = nx + replay.grid.x
                    * (ny + replay.grid.y * nz)
                guard snapshot.partIdentifiers[neighbor] == 0 else { continue }
                let fluidDistance = max(Double(wall[neighbor].w), 0)
                let q = min(
                    1,
                    max(
                        1e-4,
                        fluidDistance
                            / max(fluidDistance - solidDistance, 1e-6)
                    )
                )
                let measure = 6.0 * Double(D3Q19.weights[direction])
                    * dxSquared
                let fluidVelocity = SIMD3<Double>(
                    Double(wall[neighbor].x / replay.velocityToLattice),
                    Double(wall[neighbor].y / replay.velocityToLattice),
                    Double(wall[neighbor].z / replay.velocityToLattice)
                )
                let interpolatedVelocity = q * solidVelocity
                    + (1.0 - q) * fluidVelocity
                let solidToBoundary = Float(1.0 - q)
                let intersection = solidWorld + SIMD3<Float>(
                    Float(raw.x) * solidToBoundary * dx,
                    Float(raw.y) * solidToBoundary * dx,
                    Float(raw.z) * solidToBoundary * dx
                )
                var bestDistanceSquared = Float.infinity
                var bestVelocity = SIMD3<Float>.zero
                let triangleEnd = component.triangleOffset
                    + component.triangleCount
                for triangle in component.triangleOffset..<triangleEnd {
                    let indices = surface.triangle(triangle)
                    let closest = triangleClosestPoint(
                        point: intersection,
                        a: positions[Int(indices.x)],
                        b: positions[Int(indices.y)],
                        c: positions[Int(indices.z)]
                    )
                    let delta = intersection - closest.position
                    let distanceSquared = dot(delta, delta)
                    if distanceSquared < bestDistanceSquared {
                        bestDistanceSquared = distanceSquared
                        bestVelocity = closest.barycentric.x
                                * velocities[Int(indices.x)]
                            + closest.barycentric.y
                                * velocities[Int(indices.y)]
                            + closest.barycentric.z
                                * velocities[Int(indices.z)]
                    }
                }
                let exact = SIMD3<Double>(
                    Double(bestVelocity.x),
                    Double(bestVelocity.y),
                    Double(bestVelocity.z)
                )
                let offsetResidual = abs(
                    Double(sqrt(bestDistanceSquared) - halfThickness)
                        / Double(dx)
                )
                let bin = (part - 1) * (D3Q19.count - 1) + direction - 1
                counts[bin] += 1
                measures[bin] += measure
                endpointVelocity[bin] += measure
                    * interpolatedVelocity
                exactVelocity[bin] += measure * exact
                endpointSpeedSquared[bin] += measure
                    * vectorMagnitude(interpolatedVelocity)
                    * vectorMagnitude(interpolatedVelocity)
                exactSpeedSquared[bin] += measure
                    * vectorMagnitude(exact) * vectorMagnitude(exact)
                offsetResidualSquared[bin] += measure
                    * offsetResidual * offsetResidual
                offsetMaximum[bin] = max(
                    offsetMaximum[bin],
                    offsetResidual
                )
            }
        }
        func relativeDifference(_ first: Double, _ second: Double) -> Double {
            abs(first - second) / max(abs(first), abs(second), 1e-30)
        }
        let histogramBinCount = sourceCase.metalBins.first?
            .interpolationFractionMeasureHistogram.count ?? 20
        let productionReconstruction = linkGeometryComponents(
            bins: sourceCase.metalBins,
            surface: surface,
            quadrature: sourceCase.components.map(\.triangleQuadrature),
            histogramBinCount: histogramBinCount
        )
        let bins = (1...4).flatMap { part in
            (1..<D3Q19.count).map { direction in
                let index = (part - 1) * (D3Q19.count - 1) + direction - 1
                return MetalIndexedBirdSurfaceLinkVelocityBin(
                    partIdentifier: part,
                    directionIndex: direction,
                    linkCount: counts[index],
                    linkMeasureSquareMeters: measures[index],
                    endpointVelocityIntegralSquareMeterMetersPerSecond:
                        endpointVelocity[index],
                    exactVelocityIntegralSquareMeterMetersPerSecond:
                        exactVelocity[index],
                    endpointSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared:
                        endpointSpeedSquared[index],
                    exactSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared:
                        exactSpeedSquared[index],
                    offsetSurfaceResidualSquaredIntegralSquareMeterCellsSquared:
                        offsetResidualSquared[index],
                    offsetSurfaceMaximumResidualCells: offsetMaximum[index]
                )
            }
        }
        var sourceDifference = 0.0
        let components = surface.components.map { component in
            let part = Int(component.partIdentifier)
            let selected = bins.filter { $0.partIdentifier == part }
            let count = selected.reduce(0) { $0 + $1.linkCount }
            let measure = selected.reduce(0) {
                $0 + $1.linkMeasureSquareMeters
            }
            let endpointVelocityIntegral = selected.reduce(
                SIMD3<Double>.zero
            ) {
                $0 + $1.endpointVelocityIntegralSquareMeterMetersPerSecond
            }
            let exactVelocityIntegral = selected.reduce(
                SIMD3<Double>.zero
            ) {
                $0 + $1.exactVelocityIntegralSquareMeterMetersPerSecond
            }
            let endpointSpeedIntegral = selected.reduce(0) {
                $0
                    + $1.endpointSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared
            }
            let exactSpeedIntegral = selected.reduce(0) {
                $0
                    + $1.exactSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared
            }
            let residualSquaredIntegral = selected.reduce(0) {
                $0
                    + $1.offsetSurfaceResidualSquaredIntegralSquareMeterCellsSquared
            }
            let residualMaximum = selected.map(
                \.offsetSurfaceMaximumResidualCells
            ).max() ?? 0
            let reference = sourceCase.components.first {
                $0.partIdentifier == part
            }!
            let quadrature = reference.triangleQuadrature
            let referenceRMS = max(
                quadrature.rmsWallSpeedMetersPerSecond,
                1e-30
            )
            func summary(
                identifier: String,
                velocityIntegral: SIMD3<Double>,
                speedSquaredIntegral: Double
            ) -> MetalIndexedBirdSurfaceLinkVelocityCandidate {
                let mean = velocityIntegral / max(measure, 1e-30)
                let rms = sqrt(max(0, speedSquaredIntegral / max(measure, 1e-30)))
                return MetalIndexedBirdSurfaceLinkVelocityCandidate(
                    identifier: identifier,
                    meanWallVelocityMetersPerSecond: mean,
                    rmsWallSpeedMetersPerSecond: rms,
                    meanVelocityErrorRelativeToQuadratureRMS:
                        vectorMagnitude(
                            mean - quadrature.meanWallVelocityMetersPerSecond
                        ) / referenceRMS,
                    rmsSpeedRelativeError: abs(
                        rms - quadrature.rmsWallSpeedMetersPerSecond
                    ) / referenceRMS
                )
            }
            let reconstructedProduction = productionReconstruction.first {
                $0.partIdentifier == part
            }!
            let production = MetalIndexedBirdSurfaceLinkVelocityCandidate(
                identifier: "production-solid-node",
                meanWallVelocityMetersPerSecond:
                    reconstructedProduction.meanWallVelocityMetersPerSecond,
                rmsWallSpeedMetersPerSecond:
                    reconstructedProduction.rmsWallSpeedMetersPerSecond,
                meanVelocityErrorRelativeToQuadratureRMS:
                    reconstructedProduction
                        .meanVelocityErrorRelativeToQuadratureRMS,
                rmsSpeedRelativeError:
                    reconstructedProduction.rmsSpeedRelativeError
            )
            let endpoint = summary(
                identifier: "endpoint-interpolated",
                velocityIntegral: endpointVelocityIntegral,
                speedSquaredIntegral: endpointSpeedIntegral
            )
            let exact = summary(
                identifier: "exact-link-intersection-barycentric",
                velocityIntegral: exactVelocityIntegral,
                speedSquaredIntegral: exactSpeedIntegral
            )
            if count != reference.linkCount {
                sourceDifference = .infinity
            } else {
                sourceDifference = max(
                    sourceDifference,
                    vectorMagnitude(
                        production.meanWallVelocityMetersPerSecond
                            - reference.meanWallVelocityMetersPerSecond
                    ) / max(
                        vectorMagnitude(
                            reference.meanWallVelocityMetersPerSecond
                        ),
                        1e-30
                    ),
                    relativeDifference(
                        production.rmsWallSpeedMetersPerSecond,
                        reference.rmsWallSpeedMetersPerSecond
                    )
                )
            }
            return MetalIndexedBirdSurfaceLinkVelocityComponent(
                partIdentifier: part,
                componentName: component.name,
                linkCount: count,
                linkMeasureSquareMeters: measure,
                productionSolidNode: production,
                endpointInterpolated: endpoint,
                exactLinkIntersection: exact,
                offsetSurfaceRMSResidualCells: sqrt(max(
                    0,
                    residualSquaredIntegral / max(measure, 1e-30)
                )),
                offsetSurfaceMaximumResidualCells: residualMaximum
            )
        }
        let finite = sourceDifference.isFinite && components.allSatisfy {
            [
                $0.linkMeasureSquareMeters,
                $0.productionSolidNode.rmsWallSpeedMetersPerSecond,
                $0.endpointInterpolated.rmsWallSpeedMetersPerSecond,
                $0.exactLinkIntersection.rmsWallSpeedMetersPerSecond,
                $0.productionSolidNode.meanVelocityErrorRelativeToQuadratureRMS,
                $0.endpointInterpolated.meanVelocityErrorRelativeToQuadratureRMS,
                $0.exactLinkIntersection.meanVelocityErrorRelativeToQuadratureRMS,
                $0.offsetSurfaceRMSResidualCells,
                $0.offsetSurfaceMaximumResidualCells,
            ].allSatisfy(\.isFinite)
                && [
                    $0.productionSolidNode.meanWallVelocityMetersPerSecond,
                    $0.endpointInterpolated.meanWallVelocityMetersPerSecond,
                    $0.exactLinkIntersection.meanWallVelocityMetersPerSecond,
                ].allSatisfy {
                    $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                }
        }
        return MetalIndexedBirdSurfaceLinkVelocityCaseReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            referenceLengthCells: referenceLengthCells,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            frozenSourceTimeSeconds: Double(timeSeconds),
            runtimeSeconds: Date().timeIntervalSinceReferenceDate - start,
            bins: bins,
            components: components,
            sourceProductionMaximumRelativeDifference: sourceDifference,
            allValuesFinite: finite,
            sourceReproductionPassed:
                finite && sourceDifference <= maximumSourceError
        )
    }

    private static func linkIntersectionCase(
        backend: MetalBackend,
        surface: MeasuredBirdSurfaceSequence,
        plan: MetalIndexedBirdSurfacePilotPlan,
        referenceLengthCells: Int,
        timeSeconds: Float,
        sourceCase: MetalIndexedBirdSurfaceLinkVelocityCaseReport,
        preregistration:
            MetalIndexedBirdSurfaceLinkIntersectionPreregistration
    ) throws -> MetalIndexedBirdSurfaceLinkIntersectionCaseReport {
        struct EdgeKey: Hashable {
            let lower: Int
            let upper: Int

            init(_ first: Int, _ second: Int) {
                lower = min(first, second)
                upper = max(first, second)
            }
        }

        let start = Date().timeIntervalSinceReferenceDate
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: 0
        )
        let snapshot = try replay.snapshot(
            timeSeconds: timeSeconds,
            includeWallField: true
        )
        guard let wall = snapshot.wallVelocityAndDistance else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-intersection snapshot omitted its wall field"
            )
        }
        let positions = (0..<surface.vertexCount).map {
            surface.state(timeSeconds: timeSeconds, vertexIndex: $0)
                .positionMeters
        }
        let componentByPart = Dictionary(uniqueKeysWithValues:
            surface.components.map { (Int($0.partIdentifier), $0) }
        )
        var edgeCountsByPart = [Int: [EdgeKey: Int]]()
        var boundaryVerticesByPart = [Int: Set<Int>]()
        for component in surface.components {
            let part = Int(component.partIdentifier)
            var counts = [EdgeKey: Int]()
            let triangleEnd = component.triangleOffset
                + component.triangleCount
            for triangle in component.triangleOffset..<triangleEnd {
                let indices = surface.triangle(triangle)
                let values = [Int(indices.x), Int(indices.y), Int(indices.z)]
                for edge in [
                    EdgeKey(values[0], values[1]),
                    EdgeKey(values[1], values[2]),
                    EdgeKey(values[2], values[0]),
                ] {
                    counts[edge, default: 0] += 1
                }
            }
            edgeCountsByPart[part] = counts
            var boundaryVertices = Set<Int>()
            for (edge, count) in counts where count == 1 {
                boundaryVertices.insert(edge.lower)
                boundaryVertices.insert(edge.upper)
            }
            boundaryVerticesByPart[part] = boundaryVertices
        }

        let dx = Float(plan.cellSizeMeters)
        let dxSquared = Double(dx * dx)
        let halfThicknessCells = Double(plan.halfThicknessCells)
        let halfThickness = Float(
            plan.cellSizeMeters * plan.halfThicknessCells
        )
        let origin = replay.domainOriginMeters
        let featureTolerance = Float(
            preregistration.barycentricFeatureTolerance
        )
        var totalLinkCount = 0
        var totalLinkMeasure = 0.0
        var observedCounts = [Int](repeating: 0, count: 4 * 18)
        var maximumResidual = 0.0
        var outliers = [MetalIndexedBirdSurfaceLinkIntersectionOutlier]()
        var directionOutlierMeasures = [Double](
            repeating: 0,
            count: D3Q19.count
        )

        for index in snapshot.partIdentifiers.indices {
            let part = Int(snapshot.partIdentifiers[index])
            guard let component = componentByPart[part] else { continue }
            let x = index % replay.grid.x
            let yz = index / replay.grid.x
            let y = yz % replay.grid.y
            let z = yz / replay.grid.y
            let solidWorld = origin + SIMD3<Float>(
                (Float(x) + 0.5) * dx,
                (Float(y) + 0.5) * dx,
                (Float(z) + 0.5) * dx
            )
            let solidDistance = min(Double(wall[index].w), 0)
            for direction in 1..<D3Q19.count {
                let raw = D3Q19.directions[direction]
                let nx = x + Int(raw.x)
                let ny = y + Int(raw.y)
                let nz = z + Int(raw.z)
                guard nx >= 0, nx < replay.grid.x,
                      ny >= 0, ny < replay.grid.y,
                      nz >= 0, nz < replay.grid.z else { continue }
                let neighbor = nx + replay.grid.x
                    * (ny + replay.grid.y * nz)
                guard snapshot.partIdentifiers[neighbor] == 0 else { continue }
                let fluidDistance = max(Double(wall[neighbor].w), 0)
                let q = min(
                    1,
                    max(
                        1e-4,
                        fluidDistance
                            / max(fluidDistance - solidDistance, 1e-6)
                    )
                )
                let measure = 6.0 * Double(D3Q19.weights[direction])
                    * dxSquared
                totalLinkCount += 1
                totalLinkMeasure += measure
                let bin = (part - 1) * 18 + direction - 1
                observedCounts[bin] += 1
                let solidToBoundary = Float(1.0 - q)
                let intersection = solidWorld + SIMD3<Float>(
                    Float(raw.x) * solidToBoundary * dx,
                    Float(raw.y) * solidToBoundary * dx,
                    Float(raw.z) * solidToBoundary * dx
                )
                var bestDistanceSquared = Float.infinity
                var bestTriangle = -1
                var bestClosest: TriangleClosestPoint?
                let triangleEnd = component.triangleOffset
                    + component.triangleCount
                for triangle in component.triangleOffset..<triangleEnd {
                    let indices = surface.triangle(triangle)
                    let closest = triangleClosestPoint(
                        point: intersection,
                        a: positions[Int(indices.x)],
                        b: positions[Int(indices.y)],
                        c: positions[Int(indices.z)]
                    )
                    let delta = intersection - closest.position
                    let distanceSquared = dot(delta, delta)
                    if distanceSquared < bestDistanceSquared {
                        bestDistanceSquared = distanceSquared
                        bestTriangle = triangle
                        bestClosest = closest
                    }
                }
                guard bestTriangle >= 0, let closest = bestClosest else {
                    throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                        "link-intersection nearest-triangle search failed"
                    )
                }
                let midSurfaceDistanceCells = Double(
                    sqrt(bestDistanceSquared)
                ) / Double(dx)
                // Match the source A/B's archived Float operation order exactly;
                // changing the order creates a replay-only 1e-8-cell delta.
                let signedResidual = Double(
                    sqrt(bestDistanceSquared) - halfThickness
                ) / Double(dx)
                let residual = abs(signedResidual)
                maximumResidual = max(maximumResidual, residual)
                guard residual
                        > preregistration.outlierResidualThresholdCells else {
                    continue
                }

                let indices = surface.triangle(bestTriangle)
                let triangleVertices = SIMD3<Int>(
                    Int(indices.x), Int(indices.y), Int(indices.z)
                )
                let barycentric = closest.barycentric
                let zeroIndices = [
                    barycentric.x <= featureTolerance,
                    barycentric.y <= featureTolerance,
                    barycentric.z <= featureTolerance,
                ].enumerated().compactMap { $0.element ? $0.offset : nil }
                let feature: String
                let meshBoundary: Bool
                if zeroIndices.isEmpty {
                    feature = "face-interior"
                    meshBoundary = false
                } else if zeroIndices.count == 1 {
                    let edge: EdgeKey
                    switch zeroIndices[0] {
                    case 0:
                        edge = EdgeKey(triangleVertices.y, triangleVertices.z)
                    case 1:
                        edge = EdgeKey(triangleVertices.x, triangleVertices.z)
                    default:
                        edge = EdgeKey(triangleVertices.x, triangleVertices.y)
                    }
                    meshBoundary = edgeCountsByPart[part]?[edge] == 1
                    feature = meshBoundary
                        ? "boundary-edge" : "interior-edge"
                } else {
                    let values = [
                        barycentric.x, barycentric.y, barycentric.z,
                    ]
                    let localVertex = values.indices.max {
                        values[$0] < values[$1]
                    } ?? 0
                    let vertex = [
                        triangleVertices.x,
                        triangleVertices.y,
                        triangleVertices.z,
                    ][localVertex]
                    meshBoundary = boundaryVerticesByPart[part]?.contains(
                        vertex
                    ) ?? false
                    feature = meshBoundary
                        ? "boundary-vertex" : "interior-vertex"
                }

                var alternateDistanceSquared = Float.infinity
                var alternatePart: Int?
                var alternateName: String?
                var alternateTriangle: Int?
                for alternate in surface.components
                where alternate.partIdentifier != component.partIdentifier {
                    let alternateEnd = alternate.triangleOffset
                        + alternate.triangleCount
                    for triangle in alternate.triangleOffset..<alternateEnd {
                        let alternateIndices = surface.triangle(triangle)
                        let alternateClosest = triangleClosestPoint(
                            point: intersection,
                            a: positions[Int(alternateIndices.x)],
                            b: positions[Int(alternateIndices.y)],
                            c: positions[Int(alternateIndices.z)]
                        )
                        let delta = intersection
                            - alternateClosest.position
                        let distanceSquared = dot(delta, delta)
                        if distanceSquared < alternateDistanceSquared {
                            alternateDistanceSquared = distanceSquared
                            alternatePart = Int(alternate.partIdentifier)
                            alternateName = alternate.name
                            alternateTriangle = triangle
                        }
                    }
                }
                let alternateMidSurfaceDistanceCells =
                    alternateDistanceSquared.isFinite
                    ? Double(sqrt(alternateDistanceSquared) / dx) : nil
                let alternateOffsetResidual =
                    alternateMidSurfaceDistanceCells.map {
                        abs($0 - halfThicknessCells)
                    }
                let junctionCandidate = alternateOffsetResidual.map {
                    $0 <= preregistration
                        .maximumJunctionAlternateSurfaceResidualCells
                } ?? false
                directionOutlierMeasures[direction] += measure
                outliers.append(
                    MetalIndexedBirdSurfaceLinkIntersectionOutlier(
                        partIdentifier: part,
                        componentName: component.name,
                        directionIndex: direction,
                        cellCoordinate: SIMD3<Int>(x, y, z),
                        neighborCellCoordinate: SIMD3<Int>(nx, ny, nz),
                        linkMeasureSquareMeters: measure,
                        solidSignedDistanceCells: solidDistance,
                        fluidSignedDistanceCells: fluidDistance,
                        fluidToIntersectionFraction: q,
                        intersectionMeters: SIMD3<Double>(
                            Double(intersection.x),
                            Double(intersection.y),
                            Double(intersection.z)
                        ),
                        nearestPointMeters: SIMD3<Double>(
                            Double(closest.position.x),
                            Double(closest.position.y),
                            Double(closest.position.z)
                        ),
                        nearestTriangleIndex: bestTriangle,
                        nearestTriangleVertexIndices: triangleVertices,
                        nearestTriangleBarycentric: SIMD3<Double>(
                            Double(barycentric.x),
                            Double(barycentric.y),
                            Double(barycentric.z)
                        ),
                        nearestTriangleFeature: feature,
                        meshBoundaryAssociated: meshBoundary,
                        midSurfaceDistanceCells: midSurfaceDistanceCells,
                        signedOffsetSurfaceResidualCells: signedResidual,
                        offsetSurfaceResidualCells: residual,
                        nearestAlternatePartIdentifier: alternatePart,
                        nearestAlternateComponentName: alternateName,
                        nearestAlternateTriangleIndex: alternateTriangle,
                        nearestAlternateMidSurfaceDistanceCells:
                            alternateMidSurfaceDistanceCells,
                        nearestAlternateOffsetSurfaceResidualCells:
                            alternateOffsetResidual,
                        componentJunctionCandidate: junctionCandidate
                    )
                )
            }
        }

        let outlierMeasure = outliers.reduce(0) {
            $0 + $1.linkMeasureSquareMeters
        }
        let boundaryCount = outliers.filter(
            \.meshBoundaryAssociated
        ).count
        let junctionCount = outliers.filter(
            \.componentJunctionCandidate
        ).count
        let edgeOrJunction = outliers.filter {
            $0.meshBoundaryAssociated || $0.componentJunctionCandidate
        }
        let interior = outliers.filter {
            !$0.meshBoundaryAssociated && !$0.componentJunctionCandidate
        }
        let edgeOrJunctionMeasure = edgeOrJunction.reduce(0) {
            $0 + $1.linkMeasureSquareMeters
        }
        let interiorMeasure = interior.reduce(0) {
            $0 + $1.linkMeasureSquareMeters
        }
        let dominantDirection = (1..<D3Q19.count).max {
            directionOutlierMeasures[$0]
                < directionOutlierMeasures[$1]
        }
        let sourceCountsMatched = zip(
            observedCounts,
            sourceCase.bins.map(\.linkCount)
        ).allSatisfy(==)
        let sourceMaximum = sourceCase.components.map(
            \.offsetSurfaceMaximumResidualCells
        ).max() ?? .infinity
        let sourceDifference = abs(maximumResidual - sourceMaximum)
        let finite = maximumResidual.isFinite
            && sourceDifference.isFinite
            && outliers.allSatisfy {
                let required = [
                    $0.linkMeasureSquareMeters,
                    $0.solidSignedDistanceCells,
                    $0.fluidSignedDistanceCells,
                    $0.fluidToIntersectionFraction,
                    $0.midSurfaceDistanceCells,
                    $0.signedOffsetSurfaceResidualCells,
                    $0.offsetSurfaceResidualCells,
                ]
                let vectors = [
                    $0.intersectionMeters,
                    $0.nearestPointMeters,
                    $0.nearestTriangleBarycentric,
                ]
                return required.allSatisfy(\.isFinite)
                    && vectors.allSatisfy {
                        $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                    }
                    && ($0.nearestAlternateMidSurfaceDistanceCells?
                        .isFinite ?? true)
                    && ($0.nearestAlternateOffsetSurfaceResidualCells?
                        .isFinite ?? true)
            }
        return MetalIndexedBirdSurfaceLinkIntersectionCaseReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            referenceLengthCells: referenceLengthCells,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            frozenSourceTimeSeconds: Double(timeSeconds),
            runtimeSeconds: Date().timeIntervalSinceReferenceDate - start,
            totalLinkCount: totalLinkCount,
            totalLinkMeasureSquareMeters: totalLinkMeasure,
            outlierCount: outliers.count,
            outlierLinkMeasureSquareMeters: outlierMeasure,
            outlierCountFraction: Double(outliers.count)
                / max(Double(totalLinkCount), 1),
            outlierLinkMeasureFraction: outlierMeasure
                / max(totalLinkMeasure, 1e-30),
            meshBoundaryAssociatedOutlierCount: boundaryCount,
            componentJunctionCandidateOutlierCount: junctionCount,
            edgeOrJunctionAssociatedOutlierCount: edgeOrJunction.count,
            interiorAssociatedOutlierCount: interior.count,
            edgeOrJunctionAssociatedMeasureFraction:
                edgeOrJunctionMeasure / max(outlierMeasure, 1e-30),
            interiorAssociatedMeasureFraction:
                interiorMeasure / max(outlierMeasure, 1e-30),
            dominantDirectionIndex: outliers.isEmpty
                ? nil : dominantDirection,
            dominantDirectionMeasureFraction: outliers.isEmpty
                ? 0
                : directionOutlierMeasures[dominantDirection ?? 0]
                    / max(outlierMeasure, 1e-30),
            maximumOffsetSurfaceResidualCells: maximumResidual,
            sourceMaximumResidualDifferenceCells: sourceDifference,
            sourceLinkCountMatched: sourceCountsMatched,
            allOutliersArchived: outliers.allSatisfy {
                $0.offsetSurfaceResidualCells
                    > preregistration.outlierResidualThresholdCells
            },
            allValuesFinite: finite,
            outliers: outliers
        )
    }

    private static func linkRayRootCase(
        surface: MeasuredBirdSurfaceSequence,
        referenceLengthCells: Int,
        timeSeconds: Float,
        sourceCase: MetalIndexedBirdSurfaceLinkIntersectionCaseReport,
        preregistration: MetalIndexedBirdSurfaceLinkRayRootPreregistration
    ) throws -> MetalIndexedBirdSurfaceLinkRayRootCaseReport {
        struct DistanceResult {
            let signedDistanceMeters: Double
            let partIdentifier: Int
            let triangleIndex: Int
        }
        struct RootResult {
            let solidToFluidFraction: Double
            let closureResidualCells: Double
            let partIdentifier: Int
            let triangleIndex: Int
        }

        let start = Date().timeIntervalSinceReferenceDate
        let positions = (0..<surface.vertexCount).map {
            surface.state(timeSeconds: timeSeconds, vertexIndex: $0)
                .positionMeters
        }
        let componentByPart = Dictionary(uniqueKeysWithValues:
            surface.components.map { (Int($0.partIdentifier), $0) }
        )
        let dx = refinementReferenceLengthMeters
            / Float(referenceLengthCells)
        let halfThickness = refinementBaseHalfThicknessMeters

        func distance(
            at point: SIMD3<Float>,
            restrictedTo part: Int?
        ) -> DistanceResult {
            let triangles: Range<Int>
            if let part, let component = componentByPart[part] {
                triangles = component.triangleOffset..<(component
                    .triangleOffset + component.triangleCount)
            } else {
                triangles = 0..<surface.triangleCount
            }
            var bestDistanceSquared = Float.infinity
            var bestTriangle = -1
            for triangle in triangles {
                let indices = surface.triangle(triangle)
                let closest = triangleClosestPoint(
                    point: point,
                    a: positions[Int(indices.x)],
                    b: positions[Int(indices.y)],
                    c: positions[Int(indices.z)]
                )
                let delta = point - closest.position
                let value = dot(delta, delta)
                if value < bestDistanceSquared {
                    bestDistanceSquared = value
                    bestTriangle = triangle
                }
            }
            let resolvedPart = bestTriangle >= 0
                ? Int(surface.trianglePartIdentifiers[bestTriangle]) : 0
            return DistanceResult(
                signedDistanceMeters: Double(
                    sqrt(bestDistanceSquared) - halfThickness
                ),
                partIdentifier: resolvedPart,
                triangleIndex: bestTriangle
            )
        }

        func root(
            solid: SIMD3<Float>,
            fluid: SIMD3<Float>,
            restrictedTo part: Int?
        ) -> RootResult? {
            func value(_ fraction: Double) -> DistanceResult {
                distance(
                    at: solid + Float(fraction) * (fluid - solid),
                    restrictedTo: part
                )
            }
            let solidValue = value(0)
            let fluidValue = value(1)
            guard solidValue.signedDistanceMeters <= 0,
                  fluidValue.signedDistanceMeters > 0 else { return nil }
            var outside = 1.0
            var inside: Double?
            for step in stride(
                from: preregistration.reverseScanSubdivisions - 1,
                through: 0,
                by: -1
            ) {
                let fraction = Double(step)
                    / Double(preregistration.reverseScanSubdivisions)
                if value(fraction).signedDistanceMeters <= 0 {
                    inside = fraction
                    break
                }
                outside = fraction
            }
            guard var inside else { return nil }
            for _ in 0..<preregistration.bisectionIterations {
                let middle = 0.5 * (inside + outside)
                if value(middle).signedDistanceMeters <= 0 {
                    inside = middle
                } else {
                    outside = middle
                }
            }
            let fraction = 0.5 * (inside + outside)
            let resolved = value(fraction)
            return RootResult(
                solidToFluidFraction: fraction,
                closureResidualCells:
                    abs(resolved.signedDistanceMeters) / Double(dx),
                partIdentifier: resolved.partIdentifier,
                triangleIndex: resolved.triangleIndex
            )
        }

        var allRootsBracketed = true
        var samples = [MetalIndexedBirdSurfaceLinkRayRootSample]()
        for (sourceIndex, source) in sourceCase.outliers.enumerated() {
            let direction = D3Q19.directions[source.directionIndex]
            let directionCells = SIMD3<Float>(
                Float(direction.x),
                Float(direction.y),
                Float(direction.z)
            )
            let productionT = 1.0
                - source.fluidToIntersectionFraction
            let intersection = SIMD3<Float>(
                Float(source.intersectionMeters.x),
                Float(source.intersectionMeters.y),
                Float(source.intersectionMeters.z)
            )
            let solid = intersection
                - Float(productionT) * directionCells * dx
            let fluid = solid + directionCells * dx
            guard let ownerRoot = root(
                solid: solid,
                fluid: fluid,
                restrictedTo: source.partIdentifier
            ),
            let globalRoot = root(
                solid: solid,
                fluid: fluid,
                restrictedTo: nil
            ) else {
                allRootsBracketed = false
                continue
            }
            let productionGlobal = distance(
                at: intersection,
                restrictedTo: nil
            )
            let solidGlobal = distance(at: solid, restrictedTo: nil)
            let fluidGlobal = distance(at: fluid, restrictedTo: nil)
            let linkLengthCells = sqrt(
                Double(direction.x * direction.x
                    + direction.y * direction.y
                    + direction.z * direction.z)
            )
            let ownerShift = abs(
                ownerRoot.solidToFluidFraction - productionT
            ) * linkLengthCells
            let globalShift = abs(
                globalRoot.solidToFluidFraction - productionT
            ) * linkLengthCells
            let reduction = ownerShift > 1e-30
                ? 1.0 - globalShift / ownerShift : 0
            samples.append(
                MetalIndexedBirdSurfaceLinkRayRootSample(
                    sourceOutlierIndex: sourceIndex,
                    partIdentifier: source.partIdentifier,
                    componentName: source.componentName,
                    directionIndex: source.directionIndex,
                    cellCoordinate: source.cellCoordinate,
                    componentJunctionCandidate:
                        source.componentJunctionCandidate,
                    linkMeasureSquareMeters:
                        source.linkMeasureSquareMeters,
                    productionSolidToFluidFraction: productionT,
                    productionFluidToIntersectionFraction:
                        source.fluidToIntersectionFraction,
                    productionOwnerOffsetResidualCells:
                        source.offsetSurfaceResidualCells,
                    productionGlobalOffsetResidualCells: abs(
                        productionGlobal.signedDistanceMeters
                    ) / Double(dx),
                    productionNearestGlobalPartIdentifier:
                        productionGlobal.partIdentifier,
                    exactSolidEndpointSignedDistanceCells:
                        solidGlobal.signedDistanceMeters / Double(dx),
                    exactFluidEndpointSignedDistanceCells:
                        fluidGlobal.signedDistanceMeters / Double(dx),
                    exactSolidEndpointGlobalPartIdentifier:
                        solidGlobal.partIdentifier,
                    exactFluidEndpointGlobalPartIdentifier:
                        fluidGlobal.partIdentifier,
                    endpointNearestComponentChanged:
                        solidGlobal.partIdentifier
                            != fluidGlobal.partIdentifier,
                    fluidEndpointUsesRecordedAlternateComponent:
                        fluidGlobal.partIdentifier
                            == source.nearestAlternatePartIdentifier,
                    exactOwnerSolidToFluidFraction:
                        ownerRoot.solidToFluidFraction,
                    exactOwnerFluidToIntersectionFraction:
                        1.0 - ownerRoot.solidToFluidFraction,
                    exactOwnerRootTriangleIndex:
                        ownerRoot.triangleIndex,
                    exactOwnerRootClosureResidualCells:
                        ownerRoot.closureResidualCells,
                    exactGlobalSolidToFluidFraction:
                        globalRoot.solidToFluidFraction,
                    exactGlobalFluidToIntersectionFraction:
                        1.0 - globalRoot.solidToFluidFraction,
                    exactGlobalRootPartIdentifier:
                        globalRoot.partIdentifier,
                    exactGlobalRootTriangleIndex:
                        globalRoot.triangleIndex,
                    exactGlobalRootClosureResidualCells:
                        globalRoot.closureResidualCells,
                    productionToOwnerRootShiftCells: ownerShift,
                    productionToGlobalRootShiftCells: globalShift,
                    ownerToGlobalShiftReductionFraction: reduction,
                    globalRootUsesOwnerComponent:
                        globalRoot.partIdentifier == source.partIdentifier,
                    globalRootUsesRecordedAlternateComponent:
                        globalRoot.partIdentifier
                            == source.nearestAlternatePartIdentifier
                )
            )
        }

        func weightedRMS(
            _ selected: [MetalIndexedBirdSurfaceLinkRayRootSample],
            _ keyPath: KeyPath<MetalIndexedBirdSurfaceLinkRayRootSample, Double>
        ) -> Double {
            let measure = selected.reduce(0) {
                $0 + $1.linkMeasureSquareMeters
            }
            return sqrt(selected.reduce(0) {
                let value = $1[keyPath: keyPath]
                return $0 + $1.linkMeasureSquareMeters * value * value
            } / max(measure, 1e-30))
        }
        let junction = samples.filter(\.componentJunctionCandidate)
        let interior = samples.filter { !$0.componentJunctionCandidate }
        let junctionOwnerRMS = weightedRMS(
            junction,
            \.productionToOwnerRootShiftCells
        )
        let junctionGlobalRMS = weightedRMS(
            junction,
            \.productionToGlobalRootShiftCells
        )
        let allOwnerRMS = weightedRMS(
            samples,
            \.productionToOwnerRootShiftCells
        )
        let allGlobalRMS = weightedRMS(
            samples,
            \.productionToGlobalRootShiftCells
        )
        let maximumClosure = samples.flatMap {
            [
                $0.exactOwnerRootClosureResidualCells,
                $0.exactGlobalRootClosureResidualCells,
            ]
        }.max() ?? .infinity
        let finite = allRootsBracketed && samples.allSatisfy {
            [
                $0.linkMeasureSquareMeters,
                $0.productionSolidToFluidFraction,
                $0.productionFluidToIntersectionFraction,
                $0.productionOwnerOffsetResidualCells,
                $0.productionGlobalOffsetResidualCells,
                $0.exactSolidEndpointSignedDistanceCells,
                $0.exactFluidEndpointSignedDistanceCells,
                $0.exactOwnerSolidToFluidFraction,
                $0.exactOwnerFluidToIntersectionFraction,
                $0.exactOwnerRootClosureResidualCells,
                $0.exactGlobalSolidToFluidFraction,
                $0.exactGlobalFluidToIntersectionFraction,
                $0.exactGlobalRootClosureResidualCells,
                $0.productionToOwnerRootShiftCells,
                $0.productionToGlobalRootShiftCells,
                $0.ownerToGlobalShiftReductionFraction,
            ].allSatisfy(\.isFinite)
        }
        let sourceMatched = samples.count == sourceCase.outlierCount
            && zip(samples, sourceCase.outliers).allSatisfy { sample, source in
                sample.sourceOutlierIndex < sourceCase.outliers.count
                    && sample.partIdentifier == source.partIdentifier
                    && sample.componentName == source.componentName
                    && sample.directionIndex == source.directionIndex
                    && sample.cellCoordinate == source.cellCoordinate
                    && sample.componentJunctionCandidate
                        == source.componentJunctionCandidate
                    && sample.linkMeasureSquareMeters
                        == source.linkMeasureSquareMeters
                    && sample.productionFluidToIntersectionFraction
                        == source.fluidToIntersectionFraction
            }
        return MetalIndexedBirdSurfaceLinkRayRootCaseReport(
            schemaVersion: 1,
            referenceLengthCells: referenceLengthCells,
            runtimeSeconds: Date().timeIntervalSinceReferenceDate - start,
            sampleCount: samples.count,
            junctionCandidateCount: junction.count,
            interiorOutlierCount: interior.count,
            globalRootComponentSwitchCount: samples.filter {
                !$0.globalRootUsesOwnerComponent
            }.count,
            endpointNearestComponentChangeCount: samples.filter(
                \.endpointNearestComponentChanged
            ).count,
            junctionOwnerRootRMSShiftCells: junctionOwnerRMS,
            junctionGlobalRootRMSShiftCells: junctionGlobalRMS,
            junctionGlobalRootMaximumShiftCells: junction.map(
                \.productionToGlobalRootShiftCells
            ).max() ?? .infinity,
            junctionOwnerToGlobalRMSReductionFraction:
                1.0 - junctionGlobalRMS / max(junctionOwnerRMS, 1e-30),
            allOwnerRootRMSShiftCells: allOwnerRMS,
            allGlobalRootRMSShiftCells: allGlobalRMS,
            allGlobalRootMaximumShiftCells: samples.map(
                \.productionToGlobalRootShiftCells
            ).max() ?? .infinity,
            allOwnerToGlobalRMSReductionFraction:
                1.0 - allGlobalRMS / max(allOwnerRMS, 1e-30),
            interiorGlobalRootMaximumShiftCells: interior.map(
                \.productionToGlobalRootShiftCells
            ).max(),
            maximumRootClosureResidualCells: maximumClosure,
            sourceRecordsMatched: sourceMatched,
            allRootsBracketed: allRootsBracketed,
            allValuesFinite: finite,
            samples: samples
        )
    }
#endif

    public static func collisionGridMovingWallSpatialPreregistration(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        sourceD16FullWindow:
            MetalIndexedBirdSurfaceMovingWallFullWindowReport,
        sourceD16FullWindowSHA256: String
    ) throws -> MetalIndexedBirdSurfaceMovingWallSpatialPreregistration {
        let candidateIdentifier = "pre-step-local-density-normalization"
        let expectedOperator = MetalIndexedBirdSurfaceCollisionOperator
            .positivityPreservingRecursiveRegularizedBGK.rawValue
        let expectedNormalization = MetalIndexedBirdSurfaceMovingWallNormalization
            .preStepLocalDensity.rawValue
        let normalizedSHA = sourceD16FullWindowSHA256.lowercased()
        guard normalizedSHA.count == 64,
              normalizedSHA.allSatisfy({ $0.isHexDigit }),
              sourceD16FullWindow.datasetIdentifier
                == surface.datasetIdentifier,
              sourceD16FullWindow.manifestSHA256 == surface.manifestSHA256,
              sourceD16FullWindow.forceTargetIdentifier
                == target.datasetIdentifier,
              sourceD16FullWindow.forceTargetSHA256 == target.targetSHA256,
              sourceD16FullWindow.sourceCandidateIdentifier
                == candidateIdentifier,
              sourceD16FullWindow.selectedCollisionOperator
                == expectedOperator,
              sourceD16FullWindow.movingWallNormalization
                == expectedNormalization,
              sourceD16FullWindow.referenceLengthCells == 16,
              sourceD16FullWindow.requestedSteps
                == sourceD16FullWindow.plan.totalFluidSteps,
              sourceD16FullWindow.fullWindowGatePassed,
              sourceD16FullWindow.allStepsCompleted,
              sourceD16FullWindow.populationPositivityPassed,
              sourceD16FullWindow.forceAndMomentumAccountingPassed,
              sourceD16FullWindow.collisionCorrectionIntrusionPassed,
              sourceD16FullWindow.registeredWindowComplete,
              !sourceD16FullWindow.productionDefaultModified,
              !sourceD16FullWindow.experimentalAgreementGateApplied else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "spatial preregistration requires the passed candidate-A D=16 full window"
            )
        }
        let grids = try [8, 12, 16].map { cells in
            let plan = try refinementPlan(
                surface: surface,
                target: target,
                referenceLengthCells: cells
            )
            return MetalIndexedBirdSurfaceRefinementGridContract(
                referenceLengthCells: cells,
                cellSizeMeters: plan.cellSizeMeters,
                halfThicknessCells: plan.halfThicknessCells,
                paddingCells: plan.paddingCells,
                spongeWidthCells: plan.spongeWidthCells,
                fluidStepsPerForceSample: plan.fluidStepsPerForceSample,
                preRollFluidSteps: plan.preRollFluidSteps,
                totalFluidSteps: plan.totalFluidSteps,
                tauPlus: plan.pilotTauPlus,
                maximumWallMach: plan.maximumWallMach,
                pilotToSourceViscosityRatio:
                    plan.pilotToSourceViscosityRatio
            )
        }
        return MetalIndexedBirdSurfaceMovingWallSpatialPreregistration(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceD16FullWindowSHA256: normalizedSHA,
            selectedCollisionOperator: expectedOperator,
            movingWallNormalization: expectedNormalization,
            caseReferenceLengthCells: [8, 12],
            reusedReferenceLengthCells: 16,
            gridContracts: grids,
            maximumAllowedRelativeRMSClosureResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumAllowedCollisionCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            maximumAllowedFineGridRelativeDifference: 0.05,
            requireMonotonicTrendReduction: true,
            selectionRule: (
                "Run candidate A with pre-step local-density moving-wall "
                    + "normalization through the complete registered D=8 and "
                    + "D=12 windows, then reuse the passed source D=16 archive. "
                    + "Require every case to pass positivity, complete force "
                    + "registration, near-wing/global 0.5% momentum closure, "
                    + "and the 5% collision-intrusion bound. Require the D12-"
                    + "to-D16 force-history, mean, and impulse differences "
                    + "each to be no larger than both 5% and its corresponding "
                    + "D8-to-D12 difference. Measured-force error is forbidden "
                    + "from selecting or passing the numerical model."
            ),
            fixedInputs: (
                "Recursive regularized BGK; pre-step local-density moving-wall "
                    + "normalization; 0.08 m reference length; 0.0075 m surface "
                    + "half-thickness; 0.12 m padding; 0.06 m sponge width; "
                    + "2000 Hz registered forces; 16/24/32 fluid steps per "
                    + "force sample; fixed density, 68.07195x viscosity-floor "
                    + "condition, geometry, kinematics, far-field, sponge, "
                    + "force estimator, and ledger definitions"
            ),
            experimentalAgreementGateApplied: false,
            passed: grids.map(\.referenceLengthCells) == [8, 12, 16]
                && grids.allSatisfy {
                    $0.maximumWallMach <= 0.15
                        && abs($0.pilotToSourceViscosityRatio
                            - grids[0].pilotToSourceViscosityRatio) <= 1e-4
                },
            claimBoundary: (
                "This preregistration freezes the candidate-A engineering "
                    + "spatial test before D=8 or D=12 results are observed. "
                    + "Even a pass cannot establish source-viscosity or "
                    + "experimental agreement, authorize production promotion, "
                    + "or validate free flight."
            )
        )
    }

    public static func collisionGridMovingWallSpatialCase(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        preregistration:
            MetalIndexedBirdSurfaceCollisionGridPreregistration,
        discriminator:
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport,
        completion:
            MetalIndexedBirdSurfaceCollisionGridCompletionReport,
        provenance:
            MetalIndexedBirdSurfacePopulationStageProvenanceReport,
        boundaryTerms:
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport,
        admissibility:
            MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport,
        retainedLedger:
            MetalIndexedBirdSurfaceMovingWallLedgerReport,
        spatialPreregistration:
            MetalIndexedBirdSurfaceMovingWallSpatialPreregistration,
        sourceSpatialPreregistrationSHA256: String,
        sourceD16FullWindow:
            MetalIndexedBirdSurfaceMovingWallFullWindowReport,
        sourceD16FullWindowSHA256: String,
        referenceLengthCells: Int
    ) throws -> MetalIndexedBirdSurfaceMovingWallSpatialCaseReport {
        let expected = try collisionGridMovingWallSpatialPreregistration(
            surface: surface,
            target: target,
            sourceD16FullWindow: sourceD16FullWindow,
            sourceD16FullWindowSHA256: sourceD16FullWindowSHA256
        )
        let preregistrationSHA = sourceSpatialPreregistrationSHA256.lowercased()
        guard spatialPreregistration == expected,
              spatialPreregistration.passed,
              preregistrationSHA.count == 64,
              preregistrationSHA.allSatisfy({ $0.isHexDigit }),
              spatialPreregistration.caseReferenceLengthCells
                .contains(referenceLengthCells) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall spatial case does not match the locked preregistration"
            )
        }
        let report = try collisionGridMovingWallFullWindow(
            surface: surface,
            target: target,
            preregistration: preregistration,
            discriminator: discriminator,
            completion: completion,
            provenance: provenance,
            boundaryTerms: boundaryTerms,
            admissibility: admissibility,
            retainedLedger: retainedLedger,
            referenceLengthCells: referenceLengthCells
        )
        return MetalIndexedBirdSurfaceMovingWallSpatialCaseReport(
            schemaVersion: 1,
            sourceSpatialPreregistrationSHA256: preregistrationSHA,
            sourceD16FullWindowSHA256:
                sourceD16FullWindowSHA256.lowercased(),
            referenceLengthCells: referenceLengthCells,
            fullWindowReport: report,
            caseGatePassed: report.fullWindowGatePassed,
            experimentalAgreementGateApplied: false,
            claimBoundary: (
                "This archive is one preregistered candidate-A engineering "
                    + "grid case. It cannot independently pass spatial "
                    + "refinement or establish experimental agreement."
            )
        )
    }

    public static func collisionGridMovingWallSpatialDiscriminator(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        spatialPreregistration:
            MetalIndexedBirdSurfaceMovingWallSpatialPreregistration,
        sourceSpatialPreregistrationSHA256: String,
        d8Case: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport,
        sourceD8CaseSHA256: String,
        d12Case: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport,
        sourceD12CaseSHA256: String,
        d16FullWindow:
            MetalIndexedBirdSurfaceMovingWallFullWindowReport,
        sourceD16FullWindowSHA256: String
    ) throws -> MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport {
        let expected = try collisionGridMovingWallSpatialPreregistration(
            surface: surface,
            target: target,
            sourceD16FullWindow: d16FullWindow,
            sourceD16FullWindowSHA256: sourceD16FullWindowSHA256
        )
        let spatialSHA = sourceSpatialPreregistrationSHA256.lowercased()
        let d8SHA = sourceD8CaseSHA256.lowercased()
        let d12SHA = sourceD12CaseSHA256.lowercased()
        let d16SHA = sourceD16FullWindowSHA256.lowercased()
        let validHashes = [spatialSHA, d8SHA, d12SHA, d16SHA]
            .allSatisfy { hash in
                hash.count == 64 && hash.allSatisfy { $0.isHexDigit }
            }
        func caseMatches(
            _ candidate: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport,
            referenceLengthCells: Int
        ) -> Bool {
            let report = candidate.fullWindowReport
            return candidate.schemaVersion == 1
                && candidate.referenceLengthCells == referenceLengthCells
                && candidate.sourceSpatialPreregistrationSHA256 == spatialSHA
                && candidate.sourceD16FullWindowSHA256 == d16SHA
                && candidate.caseGatePassed && report.fullWindowGatePassed
                && report.referenceLengthCells == referenceLengthCells
                && report.datasetIdentifier == surface.datasetIdentifier
                && report.manifestSHA256 == surface.manifestSHA256
                && report.forceTargetIdentifier == target.datasetIdentifier
                && report.forceTargetSHA256 == target.targetSHA256
                && report.selectedCollisionOperator
                    == expected.selectedCollisionOperator
                && report.movingWallNormalization
                    == expected.movingWallNormalization
                && report.registeredComparisonSampleCount
                    == target.comparisonSampleCount
                && !candidate.experimentalAgreementGateApplied
                && !report.experimentalAgreementGateApplied
                && !report.productionDefaultModified
        }
        guard spatialPreregistration == expected,
              spatialPreregistration.passed,
              validHashes,
              d16SHA == spatialPreregistration.sourceD16FullWindowSHA256,
              caseMatches(d8Case, referenceLengthCells: 8),
              caseMatches(d12Case, referenceLengthCells: 12),
              d16FullWindow.fullWindowGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "spatial discriminator inputs do not match the locked case matrix"
            )
        }
        let d8ToD12 = try movingWallSpatialTrend(
            coarse: d8Case.fullWindowReport,
            fine: d12Case.fullWindowReport
        )
        let d12ToD16 = try movingWallSpatialTrend(
            coarse: d12Case.fullWindowReport,
            fine: d16FullWindow
        )
        let monotonic = d12ToD16.intervalForceNormalizedRMSDifference
                <= d8ToD12.intervalForceNormalizedRMSDifference
            && d12ToD16.meanForceRelativeDifference
                <= d8ToD12.meanForceRelativeDifference
            && d12ToD16.impulseRelativeDifference
                <= d8ToD12.impulseRelativeDifference
        let limit = spatialPreregistration
            .maximumAllowedFineGridRelativeDifference
        let finePassed = d12ToD16.intervalForceNormalizedRMSDifference <= limit
            && d12ToD16.meanForceRelativeDifference <= limit
            && d12ToD16.impulseRelativeDifference <= limit
        let allCases = d8Case.caseGatePassed && d12Case.caseGatePassed
            && d16FullWindow.fullWindowGatePassed
        let passed = allCases && monotonic && finePassed
        return MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport(
            schemaVersion: 1,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            sourceSpatialPreregistrationSHA256: spatialSHA,
            sourceD8CaseSHA256: d8SHA,
            sourceD12CaseSHA256: d12SHA,
            sourceD16FullWindowSHA256: d16SHA,
            selectedCollisionOperator:
                spatialPreregistration.selectedCollisionOperator,
            movingWallNormalization:
                spatialPreregistration.movingWallNormalization,
            referenceLengthCells: [8, 12, 16],
            d8ToD12: d8ToD12,
            d12ToD16: d12ToD16,
            intervalForceTrendReductionRatio:
                d8ToD12.intervalForceNormalizedRMSDifference
                    / max(d12ToD16.intervalForceNormalizedRMSDifference, 1e-30),
            meanForceTrendReductionRatio:
                d8ToD12.meanForceRelativeDifference
                    / max(d12ToD16.meanForceRelativeDifference, 1e-30),
            impulseTrendReductionRatio:
                d8ToD12.impulseRelativeDifference
                    / max(d12ToD16.impulseRelativeDifference, 1e-30),
            maximumAllowedFineGridRelativeDifference: limit,
            allCaseGatesPassed: allCases,
            monotonicTrendReductionPassed: monotonic,
            fineGridForceConvergencePassed: finePassed,
            spatialRefinementGatePassed: passed,
            productionPromotionAuthorized: false,
            experimentalAgreementGateApplied: false,
            scientificVerdict: passed
                ? (
                    "Candidate A passes the preregistered D=8/12/16 "
                        + "viscosity-floor engineering spatial-refinement "
                        + "gate. Production and experimental promotion remain "
                        + "disabled by the non-source viscosity condition."
                )
                : (
                    "Candidate A fails at least one preregistered full-window, "
                        + "monotonic-trend, or five-percent D12-to-D16 force "
                        + "convergence gate and is not spatially cleared."
                ),
            claimBoundary: (
                "The discriminator never uses measured-force error. A pass "
                    + "establishes only grid refinement of the fixed 68.07195x "
                    + "over-viscous engineering condition; it cannot establish "
                    + "experimental agreement, production promotion, or free "
                    + "flight validity."
            )
        )
    }

    private struct CollisionGridTrendMetrics {
        let intervalForceNormalizedRMSDifference: Double
        let meanForceRelativeDifference: Double
        let impulseRelativeDifference: Double
        let peakTimeDifferenceSeconds: Double
        let score: Double
    }

#if canImport(Metal)
    private static func runCollisionGridCase(
        backend: MetalBackend,
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator,
        referenceLengthCells: Int
    ) throws -> MetalIndexedBirdSurfaceCollisionGridCase {
        let plan = try refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: referenceLengthCells
        )
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: Float(plan.cellSizeMeters),
            halfThicknessCells: Float(plan.halfThicknessCells),
            referenceLengthCells: referenceLengthCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let report = try replay.runCoarseForcePilot(
            target: target,
            plan: plan,
            collisionOperator: collisionOperator,
            maximumFluidSteps: plan.totalFluidSteps,
            populationDiagnosticStride:
                collisionExtendedPilotPopulationDiagnosticStride,
            stopAtFirstNegativePopulation: true
        )
        let completionPassed = report.completedFluidSteps
                == plan.totalFluidSteps
            && report.recordedComparisonSamples
                == plan.comparisonForceSamples
            && report.recordedPopulationDiagnosticSamples
                == plan.totalFluidSteps
            && report.allComponentsPresentAtComparisonSamples
            && report.allLoadsFinite
            && report.allSampledPopulationsFinite
            && report.sampledPopulationPositivityPassed
            && report.firstNonFiniteLoadStep == nil
            && report.firstNonFinitePopulationStep == nil
            && report.firstNegativePopulationStep == nil
            && report.integrationGatePassed
        let correctionPassed = report
                .collisionLimiterActivationFractionOfCellSteps
                <= collisionPreRollMaximumActivationFraction
            && report.maximumCollisionRestriction.isFinite
        return MetalIndexedBirdSurfaceCollisionGridCase(
            collisionOperator: collisionOperator.rawValue,
            referenceLengthCells: referenceLengthCells,
            completionAndPositivityGatePassed: completionPassed,
            correctionIntrusionGatePassed: correctionPassed,
            eligibleForSelection: completionPassed && correctionPassed,
            report: report
        )
    }
#endif

    private static func movingWallSpatialTrend(
        coarse: MetalIndexedBirdSurfaceMovingWallFullWindowReport,
        fine: MetalIndexedBirdSurfaceMovingWallFullWindowReport
    ) throws -> MetalIndexedBirdSurfaceMovingWallSpatialTrendMetrics {
        let coarseSamples = coarse.registeredForceSamples
        let fineSamples = fine.registeredForceSamples
        let sampleAxesMatch = zip(coarseSamples, fineSamples).allSatisfy {
            $0.targetSampleIndex == $1.targetSampleIndex
                && abs($0.sourceTimeSeconds - $1.sourceTimeSeconds) <= 1e-12
        }
        let coarseForces = coarseSamples.map(
            \.intervalMeanComputedForceNewtons
        )
        let fineForces = fineSamples.map(
            \.intervalMeanComputedForceNewtons
        )
        guard coarseSamples.count == fineSamples.count,
              !coarseSamples.isEmpty,
              sampleAxesMatch,
              let historyDifference = pilotPairwiseNormalizedRMSDifference(
                first: coarseForces,
                second: fineForces
              ),
              let coarsePeak = coarse.computedPeakTimeSeconds,
              let finePeak = fine.computedPeakTimeSeconds else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "moving-wall spatial force histories are incomplete"
            )
        }
        func mean(_ values: [SIMD3<Double>]) -> SIMD3<Double> {
            values.reduce(SIMD3<Double>.zero, +) / Double(values.count)
        }
        func impulse(
            _ values: [SIMD3<Double>],
            forceRate: Double
        ) -> SIMD3<Double> {
            values.reduce(SIMD3<Double>.zero, +) / forceRate
        }
        func relativeDifference(
            _ first: SIMD3<Double>,
            _ second: SIMD3<Double>
        ) -> Double {
            vectorMagnitude(first - second)
                / max(vectorMagnitude(first), vectorMagnitude(second), 1e-30)
        }
        let meanDifference = relativeDifference(
            mean(coarseForces),
            mean(fineForces)
        )
        let impulseDifference = relativeDifference(
            impulse(
                coarseForces,
                forceRate: coarse.plan.forceSamplesPerSecond
            ),
            impulse(
                fineForces,
                forceRate: fine.plan.forceSamplesPerSecond
            )
        )
        let peakDifference = abs(coarsePeak - finePeak)
        let comparisonDuration = coarseSamples.last!.sourceTimeSeconds
            - coarseSamples.first!.sourceTimeSeconds
        let normalizedPeakDifference = peakDifference
            / max(comparisonDuration, 1e-30)
        return MetalIndexedBirdSurfaceMovingWallSpatialTrendMetrics(
            coarseReferenceLengthCells: coarse.referenceLengthCells,
            fineReferenceLengthCells: fine.referenceLengthCells,
            intervalForceNormalizedRMSDifference: historyDifference,
            meanForceRelativeDifference: meanDifference,
            impulseRelativeDifference: impulseDifference,
            peakTimeDifferenceSeconds: peakDifference,
            normalizedPeakTimeDifference: normalizedPeakDifference,
            gridTrendScore: max(
                historyDifference,
                meanDifference,
                impulseDifference,
                normalizedPeakDifference
            )
        )
    }

    private static func collisionGridTrend(
        coarse: MetalIndexedBirdSurfacePilotReport,
        fine: MetalIndexedBirdSurfacePilotReport
    ) throws -> CollisionGridTrendMetrics {
        let coarseForces = coarse.samples.map(
            \.intervalMeanComputedForceNewtons
        )
        let fineForces = fine.samples.map(
            \.intervalMeanComputedForceNewtons
        )
        guard coarseForces.count == fineForces.count,
              !coarseForces.isEmpty,
              let historyDifference = pilotPairwiseNormalizedRMSDifference(
                first: coarseForces,
                second: fineForces
              ),
              let coarsePeak = coarse.intervalMeanPeakTimeSeconds,
              let finePeak = fine.intervalMeanPeakTimeSeconds else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "collision-grid force histories are incomplete"
            )
        }
        func mean(_ values: [SIMD3<Double>]) -> SIMD3<Double> {
            values.reduce(SIMD3<Double>.zero, +) / Double(values.count)
        }
        func impulse(
            _ values: [SIMD3<Double>],
            forceRate: Double
        ) -> SIMD3<Double> {
            values.reduce(SIMD3<Double>.zero, +) / forceRate
        }
        func relativeDifference(
            _ first: SIMD3<Double>,
            _ second: SIMD3<Double>
        ) -> Double {
            vectorMagnitude(first - second)
                / max(vectorMagnitude(first), vectorMagnitude(second), 1e-30)
        }
        let meanDifference = relativeDifference(
            mean(coarseForces),
            mean(fineForces)
        )
        let impulseDifference = relativeDifference(
            impulse(
                coarseForces,
                forceRate: coarse.plan.forceSamplesPerSecond
            ),
            impulse(
                fineForces,
                forceRate: fine.plan.forceSamplesPerSecond
            )
        )
        let peakDifference = abs(coarsePeak - finePeak)
        let firstTime = coarse.samples.first!.sourceTimeSeconds
        let lastTime = coarse.samples.last!.sourceTimeSeconds
        let normalizedPeakDifference = peakDifference
            / max(lastTime - firstTime, 1e-30)
        return CollisionGridTrendMetrics(
            intervalForceNormalizedRMSDifference: historyDifference,
            meanForceRelativeDifference: meanDifference,
            impulseRelativeDifference: impulseDifference,
            peakTimeDifferenceSeconds: peakDifference,
            score: max(
                historyDifference,
                meanDifference,
                impulseDifference,
                normalizedPeakDifference
            )
        )
    }

    private static func operatorDifference(
        cases: [MetalIndexedBirdSurfaceCollisionGridCase],
        cells: Int
    ) -> Double? {
        let matching = cases.filter { $0.referenceLengthCells == cells }
        guard matching.count == 2 else { return nil }
        return pilotPairwiseNormalizedRMSDifference(
            first: matching[0].report.samples.map(
                \.intervalMeanComputedForceNewtons
            ),
            second: matching[1].report.samples.map(
                \.intervalMeanComputedForceNewtons
            )
        )
    }

    public static func audit(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75
    ) throws -> MetalIndexedBirdSurfacePilotReport {
        let plan = try plan(
            surface: surface,
            target: target,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        return try replay.runCoarseForcePilot(
            target: target,
            plan: plan
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionPreRollAB(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75
    ) throws -> MetalIndexedBirdSurfaceCollisionPreRollABReport {
        let plan = try plan(
            surface: surface,
            target: target,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let cases = try collisionPreRollOperators.map { collisionOperator in
            let report = try replay.runCoarseForcePilot(
                target: target,
                plan: plan,
                collisionOperator: collisionOperator,
                maximumFluidSteps: plan.preRollFluidSteps,
                populationDiagnosticStride:
                    collisionPreRollPopulationDiagnosticStride,
                stopAtFirstNegativePopulation: true
            )
            let positivityAndFiniteLoadGatePassed =
                report.completedFluidSteps == plan.preRollFluidSteps
                && report.allLoadsFinite
                && report.allSampledPopulationsFinite
                && report.sampledPopulationPositivityPassed
                && report.firstNegativePopulationStep == nil
                && report.firstNonFinitePopulationStep == nil
                && report.firstNonFiniteLoadStep == nil
                && report.allComponentsPresentAtComparisonSamples
            let correctionIntrusionGatePassed =
                report.collisionLimiterActivationFractionOfCellSteps
                    <= collisionPreRollMaximumActivationFraction
                && report.maximumCollisionRestriction.isFinite
            return MetalIndexedBirdSurfaceCollisionPreRollCase(
                collisionOperator: collisionOperator.rawValue,
                requestedPreRollSteps: plan.preRollFluidSteps,
                completedPreRollSteps: report.completedFluidSteps,
                perStepPopulationDiagnostics: true,
                positivityAndFiniteLoadGatePassed:
                    positivityAndFiniteLoadGatePassed,
                correctionIntrusionGatePassed:
                    correctionIntrusionGatePassed,
                eligibleForExtendedPilot:
                    collisionOperator != .productionTRT
                        && positivityAndFiniteLoadGatePassed
                        && correctionIntrusionGatePassed,
                report: report
            )
        }
        let controlFailureReproduced = cases.first?.collisionOperator
                == MetalIndexedBirdSurfaceCollisionOperator.productionTRT.rawValue
            && cases.first?.positivityAndFiniteLoadGatePassed == false
        let eligible = cases.filter(\.eligibleForExtendedPilot)
            .map(\.collisionOperator)
        let screeningPassed = controlFailureReproduced && !eligible.isEmpty
        let verdict = screeningPassed
            ? (
                "At least one positivity-preserving collision candidate "
                    + "survived the fixed 800-step dove pre-roll with per-step "
                    + "population diagnostics and activation below the fixed "
                    + "five-percent cell-step ceiling."
            )
            : (
                "No collision candidate cleared the fixed 800-step dove "
                    + "pre-roll screening contract, or the production-TRT "
                    + "control failure did not reproduce."
            )
        return MetalIndexedBirdSurfaceCollisionPreRollABReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            requestedPreRollSteps: plan.preRollFluidSteps,
            populationDiagnosticStride:
                collisionPreRollPopulationDiagnosticStride,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            fixedInputs: (
                "geometry, kinematics, grid, time step, viscosity floor, "
                    + "far-field boundary, sponge, moving-boundary operator, "
                    + "force estimator, and numerical gates"
            ),
            cases: cases,
            controlFailureReproduced: controlFailureReproduced,
            eligibleCollisionOperators: eligible,
            screeningGatePassed: screeningPassed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: verdict,
            claimBoundary: (
                "This short A/B/C is a collision-stability screening gate. "
                    + "Eligibility permits a candidate-specific momentum "
                    + "closure and extended pilot; it does not promote the "
                    + "operator to production, compare experimental forces, "
                    + "or establish grid convergence."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionMomentumClosure(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75
    ) throws -> MetalIndexedBirdSurfaceMomentumClosureReport {
        let plan = try plan(
            surface: surface,
            target: target,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let cases = try collisionMomentumCandidateOperators.map {
            try replay.runCollisionMomentumClosure(
                plan: plan,
                collisionOperator: $0,
                maximumRelativeRMSResidual:
                    collisionMomentumMaximumRelativeRMSResidual,
                maximumCorrectionActivationFraction:
                    collisionPreRollMaximumActivationFraction
            )
        }
        let metadata = replay.collisionMomentumControlVolumeMetadata
        let eligible = cases.filter(\.eligibleForExtendedPilot)
            .map(\.collisionOperator)
        let allCompleted = cases.count
                == collisionMomentumCandidateOperators.count
            && cases.allSatisfy {
                $0.completedSteps == plan.preRollFluidSteps
            }
        let passed = allCompleted && !eligible.isEmpty
        return MetalIndexedBirdSurfaceMomentumClosureReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            requestedSteps: plan.preRollFluidSteps,
            controlVolume: metadata.bounds,
            spongeWidthCells: plan.spongeWidthCells,
            minimumControlSurfaceDistanceFromDomainBoundaryCells:
                metadata.minimumDomainDistanceCells,
            minimumControlSurfaceDistanceFromSweptSurfaceCells:
                metadata.minimumSweptSurfaceDistanceCells,
            maximumAllowedRelativeRMSClosureResidual:
                collisionMomentumMaximumRelativeRMSResidual,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            fixedInputs: (
                "geometry, kinematics, grid, time step, viscosity floor, "
                    + "far-field boundary, sponge, moving-boundary operator, "
                    + "force estimator, and numerical gates"
            ),
            cases: cases,
            eligibleCollisionOperators: eligible,
            allCandidateRunsCompleted: allCompleted,
            screeningGatePassed: passed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: passed
                ? (eligible.count == cases.count
                    ? (
                        "Both positivity-preserving collision candidates "
                            + "closed the independent near-wing and global "
                            + "measured-dove momentum budgets through the "
                            + "fixed 800-step pre-roll."
                    )
                    : (
                        "At least one positivity-preserving collision "
                            + "candidate closed both independent measured-"
                            + "dove momentum budgets through the fixed "
                            + "800-step pre-roll."
                    ))
                : (
                    "No candidate completed and closed both independent "
                        + "measured-dove momentum budgets under the locked "
                        + "pre-roll contract."
                ),
            claimBoundary: (
                "This gate accepts candidate-specific momentum consistency "
                    + "only. Eligibility permits the fixed extended pilot; "
                    + "it does not select a production collision operator, "
                    + "compare experimental forces, or establish grid "
                    + "convergence."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func collisionExtendedPilot(
        surface: MeasuredBirdSurfaceSequence,
        target: MeasuredBirdForceTarget,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75
    ) throws -> MetalIndexedBirdSurfaceExtendedPilotReport {
        let plan = try plan(
            surface: surface,
            target: target,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: surface,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells,
            paddingCells: plan.paddingCells,
            physicalAirDensity: sourceAirDensity,
            targetReynoldsNumber: Float(plan.pilotReynoldsNumber),
            latticeReferenceSpeed: Float(plan.latticeReferenceSpeed),
            spongeWidthCells: plan.spongeWidthCells,
            spongeStrength: Float(plan.spongeStrength)
        )
        let cases = try collisionMomentumCandidateOperators.map { collisionOperator in
            let report = try replay.runCoarseForcePilot(
                target: target,
                plan: plan,
                collisionOperator: collisionOperator,
                maximumFluidSteps: plan.totalFluidSteps,
                populationDiagnosticStride:
                    collisionExtendedPilotPopulationDiagnosticStride,
                stopAtFirstNegativePopulation: true
            )
            let completionPassed = report.completedFluidSteps
                    == plan.totalFluidSteps
                && report.recordedComparisonSamples
                    == plan.comparisonForceSamples
                && report.recordedPopulationDiagnosticSamples
                    == plan.totalFluidSteps
                && report.allComponentsPresentAtComparisonSamples
                && report.allLoadsFinite
                && report.allSampledPopulationsFinite
                && report.sampledPopulationPositivityPassed
                && report.firstNonFiniteLoadStep == nil
                && report.firstNonFinitePopulationStep == nil
                && report.firstNegativePopulationStep == nil
                && report.integrationGatePassed
            let correctionPassed = report
                    .collisionLimiterActivationFractionOfCellSteps
                    <= collisionPreRollMaximumActivationFraction
                && report.maximumCollisionRestriction.isFinite
            return MetalIndexedBirdSurfaceExtendedPilotCase(
                collisionOperator: collisionOperator.rawValue,
                completionAndPositivityGatePassed: completionPassed,
                correctionIntrusionGatePassed: correctionPassed,
                eligibleForRefinementDiscrimination:
                    completionPassed && correctionPassed,
                report: report
            )
        }
        let eligible = cases.filter(\.eligibleForRefinementDiscrimination)
            .map(\.collisionOperator)
        let allCompleted = cases.count
                == collisionMomentumCandidateOperators.count
            && cases.allSatisfy {
                $0.report.completedFluidSteps == plan.totalFluidSteps
            }
        let endpointDifference = pilotPairwiseNormalizedRMSDifference(
            first: cases.first?.report.samples.map(
                \.endpointComputedForceNewtons
            ),
            second: cases.last?.report.samples.map(
                \.endpointComputedForceNewtons
            )
        )
        let intervalDifference = pilotPairwiseNormalizedRMSDifference(
            first: cases.first?.report.samples.map(
                \.intervalMeanComputedForceNewtons
            ),
            second: cases.last?.report.samples.map(
                \.intervalMeanComputedForceNewtons
            )
        )
        let passed = allCompleted && !eligible.isEmpty
        return MetalIndexedBirdSurfaceExtendedPilotReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: surface.datasetIdentifier,
            manifestSHA256: surface.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            requestedFluidSteps: plan.totalFluidSteps,
            requestedComparisonSamples: plan.comparisonForceSamples,
            populationDiagnosticStride:
                collisionExtendedPilotPopulationDiagnosticStride,
            maximumCorrectionActivationFraction:
                collisionPreRollMaximumActivationFraction,
            fixedInputs: (
                "geometry, kinematics, grid, time step, viscosity floor, "
                    + "far-field boundary, sponge, moving-boundary operator, "
                    + "force estimator, comparison window, and numerical "
                    + "gates"
            ),
            cases: cases,
            eligibleCollisionOperators: eligible,
            allCandidateRunsCompleted: allCompleted,
            endpointPairwiseNormalizedRMSDifference: endpointDifference,
            intervalMeanPairwiseNormalizedRMSDifference: intervalDifference,
            screeningGatePassed: passed,
            experimentalAgreementGateApplied: false,
            scientificVerdict: passed
                ? (eligible.count == cases.count
                    ? (
                        "Both momentum-closed collision candidates completed "
                            + "the fixed full-window dove pilot with positive "
                            + "finite populations and loads."
                    )
                    : (
                        "One momentum-closed collision candidate completed "
                            + "the fixed full-window dove pilot."
                    ))
                : (
                    "No momentum-closed collision candidate completed the "
                        + "fixed full-window dove pilot under the locked "
                        + "stability and correction contract."
                ),
            claimBoundary: (
                "This is a viscosity-floor engineering extension through the "
                    + "registered force window. Measured-force errors and "
                    + "candidate differences are descriptive only. Passing "
                    + "permits a controlled collision-discrimination study; "
                    + "it does not select a production operator, establish "
                    + "experimental agreement, or clear grid refinement."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

public enum MetalIndexedBirdSurfaceCouplingValidator {
    public static func audit(
        _ dataset: MeasuredBirdSurfaceSequence,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75,
        minimumSteps: Int = 8,
        maximumSteps: Int = 32,
        minimumTopologyTransitions: Int = 1,
        maximumRelativeRMSResidual: Double = 0.005
    ) throws -> MetalIndexedBirdSurfaceCouplingReport {
        guard minimumSteps > 0,
              maximumSteps >= minimumSteps,
              minimumTopologyTransitions > 0,
              maximumRelativeRMSResidual.isFinite,
              maximumRelativeRMSResidual > 0 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed coupling audit bounds are invalid"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: dataset,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
        return try replay.auditProductionCoupling(
            minimumSteps: minimumSteps,
            maximumSteps: maximumSteps,
            minimumTopologyTransitions: minimumTopologyTransitions,
            maximumRelativeRMSResidual: maximumRelativeRMSResidual
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

public enum MetalIndexedBirdSurfaceValidator {
    public static func audit(
        _ dataset: MeasuredBirdSurfaceSequence,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75,
        cpuRasterMilestoneFrames: [Int] = [0, 33, 89, 126, 143]
    ) throws -> MetalIndexedBirdSurfaceReplayReport {
        guard cellSizeMeters.isFinite,
              cellSizeMeters > 0,
              halfThicknessCells.isFinite,
              (0.5...2).contains(halfThicknessCells) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "geometry audit cell size and thickness are invalid"
            )
        }
        let milestones = Array(Set(cpuRasterMilestoneFrames)).sorted()
        guard milestones.allSatisfy({ $0 >= 0 && $0 < dataset.frameCount }) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "CPU raster milestone is outside the surface sequence"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: dataset,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
        var frameAudits: [MetalIndexedBirdSurfaceFrameAudit] = []
        frameAudits.reserveCapacity(dataset.frameCount)
        var maximumPositionError = 0.0
        var maximumVelocityError = 0.0
        var maximumWallDifference = 0.0
        var maximumDistanceDifference = 0.0
        var maximumMaskMismatch = 0
        var allComponentsPresent = true
        var allFinite = true

        for frame in 0..<dataset.frameCount {
            let compareCPU = milestones.contains(frame)
            let time = dataset.frameTimesSeconds[frame]
            let snapshot = try replay.snapshot(
                timeSeconds: time,
                includeWallField: compareCPU
            )
            var framePositionError = 0.0
            var frameVelocityError = 0.0
            for vertex in 0..<dataset.vertexCount {
                let expected = dataset.state(
                    timeSeconds: time,
                    vertexIndex: vertex
                )
                let actual = snapshot.prepared[vertex]
                let position = SIMD3<Float>(
                    actual.position.x,
                    actual.position.y,
                    actual.position.z
                )
                let velocityPhysical = SIMD3<Float>(
                    actual.velocity.x,
                    actual.velocity.y,
                    actual.velocity.z
                ) / replay.velocityToLattice
                framePositionError = max(
                    framePositionError,
                    Double(vectorLength(position - expected.positionMeters))
                )
                frameVelocityError = max(
                    frameVelocityError,
                    Double(vectorLength(
                        velocityPhysical - expected.velocityMetersPerSecond
                    ))
                )
                allFinite = allFinite
                    && position.x.isFinite && position.y.isFinite
                    && position.z.isFinite && velocityPhysical.x.isFinite
                    && velocityPhysical.y.isFinite
                    && velocityPhysical.z.isFinite
            }
            maximumPositionError = max(maximumPositionError, framePositionError)
            maximumVelocityError = max(maximumVelocityError, frameVelocityError)

            var counts = [Int](repeating: 0, count: dataset.components.count)
            var solidCount = 0
            for identifier in snapshot.partIdentifiers where identifier != 0 {
                solidCount += 1
                let index = Int(identifier) - 1
                if counts.indices.contains(index) {
                    counts[index] += 1
                } else {
                    allFinite = false
                }
            }
            allComponentsPresent = allComponentsPresent
                && counts.allSatisfy { $0 > 0 }

            var maximumLatticeWallSpeed = 0.0
            var mismatch: Int?
            var wallDifference: Double?
            var distanceDifference: Double?
            if compareCPU, let gpuWall = snapshot.wallVelocityAndDistance {
                let cpu = replay.cpuRaster(timeSeconds: time)
                var localMismatch = 0
                var localWallDifference = 0.0
                var localDistanceDifference = 0.0
                for cell in 0..<snapshot.partIdentifiers.count {
                    if snapshot.partIdentifiers[cell] != cpu.partIdentifiers[cell] {
                        localMismatch += 1
                    }
                    let gpu = gpuWall[cell]
                    let expected = cpu.wallVelocityAndDistance[cell]
                    // Wall velocity is consumed only on occupied moving-boundary
                    // cells. Candidate AABB cells retain distance diagnostics but
                    // may contain extrapolated barycentrics that never reach the
                    // boundary operator.
                    if snapshot.partIdentifiers[cell] != 0
                        || cpu.partIdentifiers[cell] != 0 {
                        localWallDifference = max(
                            localWallDifference,
                            Double(vectorLength(SIMD3<Float>(
                                gpu.x - expected.x,
                                gpu.y - expected.y,
                                gpu.z - expected.z
                            )))
                        )
                    }
                    localDistanceDifference = max(
                        localDistanceDifference,
                        Double(abs(gpu.w - expected.w))
                    )
                    if snapshot.partIdentifiers[cell] != 0 {
                        maximumLatticeWallSpeed = max(
                            maximumLatticeWallSpeed,
                            Double(vectorLength(SIMD3<Float>(
                                gpu.x, gpu.y, gpu.z
                            )))
                        )
                    }
                    allFinite = allFinite
                        && gpu.x.isFinite && gpu.y.isFinite
                        && gpu.z.isFinite && gpu.w.isFinite
                }
                mismatch = localMismatch
                wallDifference = localWallDifference
                distanceDifference = localDistanceDifference
                maximumMaskMismatch = max(maximumMaskMismatch, localMismatch)
                maximumWallDifference = max(
                    maximumWallDifference,
                    localWallDifference
                )
                maximumDistanceDifference = max(
                    maximumDistanceDifference,
                    localDistanceDifference
                )
            } else {
                // Prepared vertex speed bounds every barycentric surface speed.
                maximumLatticeWallSpeed = snapshot.prepared.reduce(0.0) {
                    max($0, Double(vectorLength(SIMD3<Float>(
                        $1.velocity.x, $1.velocity.y, $1.velocity.z
                    ))))
                }
            }
            let occupancyData = Data(snapshot.partIdentifiers)
            frameAudits.append(MetalIndexedBirdSurfaceFrameAudit(
                frameIndex: frame,
                sourceFrameNumber: dataset.frameNumbers[frame],
                timeSeconds: Double(time),
                solidCellCount: solidCount,
                componentSolidCellCounts: counts,
                occupancySHA256: CheckpointArchive.sha256(occupancyData),
                maximumLatticeWallSpeed: maximumLatticeWallSpeed,
                maximumPreparedPositionErrorMeters: framePositionError,
                maximumPreparedVelocityErrorMetersPerSecond: frameVelocityError,
                cpuRasterCompared: compareCPU,
                cpuMaskMismatchCellCount: mismatch,
                maximumCPUWallVelocityDifferenceLattice: wallDifference,
                maximumCPUSignedDistanceDifferenceCells: distanceDifference
            ))
        }

        let fractionalProbeIntervals = [0, 33, 89, 126, 142]
        let fractionalProbeTimes = fractionalProbeIntervals.map { frame in
            0.5 * (
                dataset.frameTimesSeconds[frame]
                    + dataset.frameTimesSeconds[frame + 1]
            )
        }
        for time in fractionalProbeTimes {
            let snapshot = try replay.snapshot(
                timeSeconds: time,
                includeWallField: false
            )
            var counts = [Int](repeating: 0, count: dataset.components.count)
            for identifier in snapshot.partIdentifiers where identifier != 0 {
                let index = Int(identifier) - 1
                if counts.indices.contains(index) {
                    counts[index] += 1
                } else {
                    allFinite = false
                }
            }
            allComponentsPresent = allComponentsPresent
                && counts.allSatisfy { $0 > 0 }
            for vertex in 0..<dataset.vertexCount {
                let expected = dataset.state(
                    timeSeconds: time,
                    vertexIndex: vertex
                )
                let actual = snapshot.prepared[vertex]
                let position = SIMD3<Float>(
                    actual.position.x,
                    actual.position.y,
                    actual.position.z
                )
                let velocityPhysical = SIMD3<Float>(
                    actual.velocity.x,
                    actual.velocity.y,
                    actual.velocity.z
                ) / replay.velocityToLattice
                maximumPositionError = max(
                    maximumPositionError,
                    Double(vectorLength(position - expected.positionMeters))
                )
                maximumVelocityError = max(
                    maximumVelocityError,
                    Double(vectorLength(
                        velocityPhysical - expected.velocityMetersPerSecond
                    ))
                )
                allFinite = allFinite
                    && position.x.isFinite && position.y.isFinite
                    && position.z.isFinite && velocityPhysical.x.isFinite
                    && velocityPhysical.y.isFinite && velocityPhysical.z.isFinite
            }
        }

        let passed = maximumPositionError <= 2.0e-7
            && maximumVelocityError <= 5.0e-3
            && maximumMaskMismatch == 0
            // CPU SIMD and strict Metal arithmetic need not fuse the same
            // barycentric operations. This remains below 0.1% of the measured
            // maximum wall speed while occupancy must still match exactly.
            && maximumWallDifference <= 2.5e-5
            && maximumDistanceDifference <= 2.0e-5
            && allComponentsPresent
            && allFinite
            && frameAudits.allSatisfy {
                $0.solidCellCount > 0
                    && $0.maximumLatticeWallSpeed.isFinite
                    && $0.maximumLatticeWallSpeed <= 0.08
            }
            && dataset.completeBirdSurfaceReady
            && !dataset.quantitativeForceAcceptanceReady
        return MetalIndexedBirdSurfaceReplayReport(
            schemaVersion: 2,
            deviceName: backend.device.name,
            datasetIdentifier: dataset.datasetIdentifier,
            scientificTier: dataset.scientificTier,
            manifestSHA256: dataset.manifestSHA256,
            sourceSurfaceSHA256: dataset.sourceSurfaceSHA256,
            sourceMuscleModelSHA256: dataset.sourceMuscleModelSHA256,
            frameCount: dataset.frameCount,
            vertexCount: dataset.vertexCount,
            triangleCount: dataset.triangleCount,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            cellSizeMeters: Double(cellSizeMeters),
            halfThicknessCells: Double(halfThicknessCells),
            runtimeSeconds: Date().timeIntervalSince(startTime),
            geometryKernelSequence: [
                "prepareIndexedBirdSurface",
                "clearMeasuredWingSurface",
                "rasterizeIndexedBirdSurface",
                "resolveIndexedBirdSurface",
            ],
            cpuRasterMilestoneFrames: milestones,
            fractionalInterpolationProbeTimesSeconds:
                fractionalProbeTimes.map(Double.init),
            maximumPreparedPositionErrorMeters: maximumPositionError,
            maximumPreparedVelocityErrorMetersPerSecond: maximumVelocityError,
            maximumCPUWallVelocityDifferenceLattice: maximumWallDifference,
            maximumCPUSignedDistanceDifferenceCells: maximumDistanceDifference,
            maximumCPUMaskMismatchCellCount: maximumMaskMismatch,
            allComponentsPresentEveryFrame: allComponentsPresent,
            allValuesFinite: allFinite,
            fluidCollisionExecuted: false,
            forceAccumulationExecuted: false,
            frameAudits: frameAudits,
            passed: passed,
            claimBoundary: (
                "This geometry-only gate closes indexed loading, non-periodic "
                    + "interpolation, component occupancy, rasterization, and "
                    + "wall velocity. It executes no fluid collision or force "
                    + "accumulation and implies no aerodynamic agreement."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

#if canImport(Metal)
private struct GPUIndexedControlVolumeBounds {
    var minimum: SIMD4<UInt32>
    var maximumExclusive: SIMD4<UInt32>
}

private struct GPUIndexedControlVolumeBudget {
    var oldFluidMomentum: SIMD4<Float>
    var newFluidMomentum: SIMD4<Float>
    var outwardMomentumFlux: SIMD4<Float>
    var topologyReservoirCorrection: SIMD4<Float>
}

private final class IndexedControlVolumeDiagnosticResources {
    private let backend: MetalBackend
    private let partialCount: Int
    private let beforePipeline: MTLComputePipelineState
    private let afterPipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let beforeA: MTLBuffer
    private let beforeB: MTLBuffer
    private let afterA: MTLBuffer
    private let afterB: MTLBuffer

    init(backend: MetalBackend, cellCount: Int) throws {
        self.backend = backend
        partialCount = max(1, (cellCount + 255) / 256)
        beforePipeline = try backend.pipeline(
            named: "measureControlVolumeMomentumBeforeStep"
        )
        afterPipeline = try backend.pipeline(
            named: "measureControlVolumeMomentumAfterStep"
        )
        reductionPipeline = try backend.pipeline(
            named: "reduceControlVolumeMomentumBudget"
        )
        let bytes = partialCount
            * MemoryLayout<GPUIndexedControlVolumeBudget>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            bytes, bytes, bytes, bytes
        ])
        beforeA = try backend.makeSharedBuffer(length: bytes)
        beforeB = try backend.makeSharedBuffer(length: bytes)
        afterA = try backend.makeSharedBuffer(length: bytes)
        afterB = try backend.makeSharedBuffer(length: bytes)
    }

    func encodeBefore(
        commandBuffer: MTLCommandBuffer,
        populations: MTLBuffer,
        solid: MTLBuffer,
        bounds: GPUIndexedControlVolumeBounds,
        uniforms: inout GPUUniforms
    ) throws -> MTLBuffer {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed control-volume pre-step momentum."
            )
        }
        var localBounds = bounds
        encoder.setBuffer(populations, offset: 0, index: 0)
        encoder.setBuffer(solid, offset: 0, index: 1)
        encoder.setBuffer(beforeA, offset: 0, index: 2)
        encoder.setBytes(
            &localBounds,
            length: MemoryLayout<GPUIndexedControlVolumeBounds>.stride,
            index: 3
        )
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: beforePipeline,
            count: Int(uniforms.grid.w),
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
        return try encodeReduction(
            commandBuffer: commandBuffer,
            input: beforeA,
            scratch: beforeB
        )
    }

    func encodeAfter(
        commandBuffer: MTLCommandBuffer,
        populations: MTLBuffer,
        solidPrevious: MTLBuffer,
        solidCurrent: MTLBuffer,
        wallVelocity: MTLBuffer,
        coveredFluidMomentum: MTLBuffer,
        bounds: GPUIndexedControlVolumeBounds,
        uniforms: inout GPUUniforms
    ) throws -> MTLBuffer {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed control-volume post-step momentum."
            )
        }
        var localBounds = bounds
        encoder.setBuffer(populations, offset: 0, index: 0)
        encoder.setBuffer(solidPrevious, offset: 0, index: 1)
        encoder.setBuffer(solidCurrent, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(coveredFluidMomentum, offset: 0, index: 4)
        encoder.setBuffer(afterA, offset: 0, index: 5)
        encoder.setBytes(
            &localBounds,
            length: MemoryLayout<GPUIndexedControlVolumeBounds>.stride,
            index: 6
        )
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: afterPipeline,
            count: Int(uniforms.grid.w),
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
        return try encodeReduction(
            commandBuffer: commandBuffer,
            input: afterA,
            scratch: afterB
        )
    }

    func read(_ buffer: MTLBuffer) -> GPUIndexedControlVolumeBudget {
        buffer.contents()
            .assumingMemoryBound(to: GPUIndexedControlVolumeBudget.self)
            .pointee
    }

    private func encodeReduction(
        commandBuffer: MTLCommandBuffer,
        input initial: MTLBuffer,
        scratch initialScratch: MTLBuffer
    ) throws -> MTLBuffer {
        var input = initial
        var output = initialScratch
        var count = partialCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to reduce indexed control-volume momentum."
                )
            }
            encoder.setBuffer(input, offset: 0, index: 0)
            encoder.setBuffer(output, offset: 0, index: 1)
            encoder.setBytes(
                &count32,
                length: MemoryLayout<UInt32>.stride,
                index: 2
            )
            backend.dispatch1D(
                encoder: encoder,
                pipeline: reductionPipeline,
                count: outputCount
            )
            encoder.endEncoding()
            count = outputCount
            input = output
            output = output === initial
                ? initialScratch : initial
        }
        return input
    }
}

private final class MetalIndexedBoundaryTermCapture {
    let capturedSteps: [Int]
    let targetCellLinearIndex: Int

    private let backend: MetalBackend
    private let stepIndices: [Int: Int]
    private let records: MTLBuffer
    private let pipeline: MTLComputePipelineState

    init(
        backend: MetalBackend,
        capturedSteps: [Int],
        targetCellLinearIndex: Int
    ) throws {
        guard !capturedSteps.isEmpty,
              Set(capturedSteps).count == capturedSteps.count,
              capturedSteps.allSatisfy({ $0 > 0 }),
              targetCellLinearIndex >= 0 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "boundary-term capture request is invalid"
            )
        }
        self.backend = backend
        self.capturedSteps = capturedSteps.sorted()
        self.targetCellLinearIndex = targetCellLinearIndex
        stepIndices = Dictionary(uniqueKeysWithValues:
            self.capturedSteps.enumerated().map { ($0.element, $0.offset) }
        )
        let byteCount = self.capturedSteps.count * D3Q19.count
            * MemoryLayout<GPUIndexedBoundaryTerm>.stride
        try backend.validateAllocationPlan(bufferLengths: [byteCount])
        records = try backend.makeSharedBuffer(length: byteCount)
        records.label = "Indexed moving-boundary term decomposition"
        memset(records.contents(), 0, byteCount)
        pipeline = try backend.pipeline(
            named: "captureIndexedBoundaryTermDecomposition"
        )
    }

    func encodeBoundaryTerms(
        commandBuffer: MTLCommandBuffer,
        step: Int,
        populationsIn: MTLBuffer,
        solidCurrent: MTLBuffer,
        wallVelocity: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let sampleIndex = stepIndices[step] else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed moving-boundary terms."
            )
        }
        var target = SIMD4<UInt32>(
            UInt32(targetCellLinearIndex),
            UInt32(step),
            UInt32(sampleIndex),
            0
        )
        encoder.label = "Indexed moving-boundary term decomposition"
        encoder.setBuffer(populationsIn, offset: 0, index: 0)
        encoder.setBuffer(solidCurrent, offset: 0, index: 1)
        encoder.setBuffer(wallVelocity, offset: 0, index: 2)
        encoder.setBuffer(records, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        encoder.setBytes(
            &target,
            length: MemoryLayout<SIMD4<UInt32>>.stride,
            index: 5
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: pipeline,
            count: D3Q19.count
        )
        encoder.endEncoding()
    }

    func readRecords() -> [[GPUIndexedBoundaryTerm]] {
        let pointer = records.contents().assumingMemoryBound(
            to: GPUIndexedBoundaryTerm.self
        )
        return capturedSteps.indices.map { sampleIndex in
            let start = sampleIndex * D3Q19.count
            return (0..<D3Q19.count).map { pointer[start + $0] }
        }
    }
}

private final class MetalIndexedPopulationStageCapture {
    let capturedSteps: [Int]
    let targetCellLinearIndex: Int
    let targetDirection: Int

    private let backend: MetalBackend
    private let stepIndices: [Int: Int]
    private let records: MTLBuffer
    private let beforePipeline: MTLComputePipelineState
    private let afterPipeline: MTLComputePipelineState

    init(
        backend: MetalBackend,
        capturedSteps: [Int],
        targetCellLinearIndex: Int,
        targetDirection: Int
    ) throws {
        guard !capturedSteps.isEmpty,
              Set(capturedSteps).count == capturedSteps.count,
              capturedSteps.allSatisfy({ $0 > 0 }),
              targetCellLinearIndex >= 0,
              (0..<D3Q19.count).contains(targetDirection) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "population-stage capture request is invalid"
            )
        }
        self.backend = backend
        self.capturedSteps = capturedSteps.sorted()
        self.targetCellLinearIndex = targetCellLinearIndex
        self.targetDirection = targetDirection
        stepIndices = Dictionary(uniqueKeysWithValues:
            self.capturedSteps.enumerated().map { ($0.element, $0.offset) }
        )
        let byteCount = self.capturedSteps.count
            * MemoryLayout<GPUIndexedPopulationStageProvenance>.stride
        try backend.validateAllocationPlan(bufferLengths: [byteCount])
        records = try backend.makeSharedBuffer(length: byteCount)
        records.label = "Indexed population stage provenance"
        memset(records.contents(), 0, byteCount)
        beforePipeline = try backend.pipeline(
            named: "captureIndexedPopulationStageProvenanceBeforeStep"
        )
        afterPipeline = try backend.pipeline(
            named: "captureIndexedPopulationStageProvenanceAfterStep"
        )
    }

    func encodeBefore(
        commandBuffer: MTLCommandBuffer,
        step: Int,
        populationsIn: MTLBuffer,
        solidPrevious: MTLBuffer,
        solidCurrent: MTLBuffer,
        wallVelocity: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let sampleIndex = stepIndices[step] else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed population stage provenance."
            )
        }
        var target = SIMD4<UInt32>(
            UInt32(targetCellLinearIndex),
            UInt32(targetDirection),
            UInt32(step),
            UInt32(sampleIndex)
        )
        encoder.label = "Indexed population provenance before fluid step"
        encoder.setBuffer(populationsIn, offset: 0, index: 0)
        encoder.setBuffer(solidPrevious, offset: 0, index: 1)
        encoder.setBuffer(solidCurrent, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(records, offset: 0, index: 4)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
        )
        encoder.setBytes(
            &target,
            length: MemoryLayout<SIMD4<UInt32>>.stride,
            index: 6
        )
        backend.dispatch1D(encoder: encoder, pipeline: beforePipeline, count: 1)
        encoder.endEncoding()
    }

    func encodeAfter(
        commandBuffer: MTLCommandBuffer,
        step: Int,
        populationsOut: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let sampleIndex = stepIndices[step] else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed population output provenance."
            )
        }
        var target = SIMD4<UInt32>(
            UInt32(targetCellLinearIndex),
            UInt32(targetDirection),
            UInt32(step),
            UInt32(sampleIndex)
        )
        encoder.label = "Indexed population provenance after fluid step"
        encoder.setBuffer(populationsOut, offset: 0, index: 0)
        encoder.setBuffer(records, offset: 0, index: 1)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 2
        )
        encoder.setBytes(
            &target,
            length: MemoryLayout<SIMD4<UInt32>>.stride,
            index: 3
        )
        backend.dispatch1D(encoder: encoder, pipeline: afterPipeline, count: 1)
        encoder.endEncoding()
    }

    func readRecords() -> [GPUIndexedPopulationStageProvenance] {
        let pointer = records.contents().assumingMemoryBound(
            to: GPUIndexedPopulationStageProvenance.self
        )
        return capturedSteps.indices.map { pointer[$0] }
    }
}

private final class MetalIndexedBirdSurfaceReplay {
    struct Snapshot {
        let prepared: [GPUPreparedMeasuredWingPoint]
        let partIdentifiers: [UInt8]
        let wallVelocityAndDistance: [SIMD4<Float>]?
    }

    struct CPURaster {
        let partIdentifiers: [UInt8]
        let wallVelocityAndDistance: [SIMD4<Float>]
    }

    let grid: GridSize
    let velocityToLattice: Float
    var forceToPhysical: Float {
        configuration.scaling.forceToPhysical
    }
    var domainOriginMeters: SIMD3<Float> {
        configuration.domainOriginMeters
    }

    private let backend: MetalBackend
    private let dataset: MeasuredBirdSurfaceSequence
    private let configuration: SimulationConfiguration
    private let halfThicknessMeters: Float
    private let parameters: MTLBuffer
    private let sourcePoints: MTLBuffer
    private let frameTimes: MTLBuffer
    private let triangleIndices: MTLBuffer
    private let trianglePartIdentifiers: MTLBuffer
    private let prepared: MTLBuffer
    private let partMask: MTLBuffer
    private let wallVelocityAndDistance: MTLBuffer
    private let distanceKeys: MTLBuffer
    private let preparedStaging: MTLBuffer
    private let maskStaging: MTLBuffer
    private let wallStaging: MTLBuffer
    private let preparePipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState
    private let rasterPipeline: MTLComputePipelineState
    private let resolvePipeline: MTLComputePipelineState
    private let flowResolvePipeline: MTLComputePipelineState

    init(
        backend: MetalBackend,
        dataset: MeasuredBirdSurfaceSequence,
        cellSizeMeters: Float,
        halfThicknessCells: Float,
        referenceLengthCells: Int = 8,
        paddingCells: Int = 4,
        physicalAirDensity: Float = 1,
        targetReynoldsNumber: Float = 1_000,
        latticeReferenceSpeed: Float = 0.04,
        spongeWidthCells: Int = 4,
        spongeStrength: Float = 0
    ) throws {
        self.backend = backend
        self.dataset = dataset
        halfThicknessMeters = halfThicknessCells * cellSizeMeters
        guard paddingCells >= 4,
              spongeWidthCells >= 4,
              paddingCells >= spongeWidthCells else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed surface padding must clear the sponge"
            )
        }
        let minimum = dataset.minimumPositionMeters
            - SIMD3<Float>(repeating: Float(paddingCells) * cellSizeMeters)
        let maximum = dataset.maximumPositionMeters
            + SIMD3<Float>(repeating: Float(paddingCells) * cellSizeMeters)
        let extent = maximum - minimum
        grid = try GridSize(
            x: max(16, Int(ceil(extent.x / cellSizeMeters)) + 1),
            y: max(16, Int(ceil(extent.y / cellSizeMeters)) + 1),
            z: max(16, Int(ceil(extent.z / cellSizeMeters)) + 1)
        )
        let maximumSpeed = dataset.maximumPointSpeedMetersPerSecond
        let scaling = try LatticeScaling(
            characteristicLengthMeters:
                Float(referenceLengthCells) * cellSizeMeters,
            characteristicLengthCells: referenceLengthCells,
            referenceSpeedMetersPerSecond: maximumSpeed,
            targetReynoldsNumber: targetReynoldsNumber,
            physicalAirDensity: physicalAirDensity,
            latticeReferenceSpeed: latticeReferenceSpeed
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: minimum,
            scaling: scaling,
            physicalAirDensity: physicalAirDensity,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: spongeWidthCells,
            spongeStrength: spongeStrength,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        velocityToLattice = scaling.velocityToLattice
        let gpuParameters = GPUIndexedBirdSurfaceParameters(
            counts: SIMD4<UInt32>(
                UInt32(dataset.vertexCount),
                UInt32(dataset.triangleCount),
                UInt32(dataset.frameCount),
                0
            ),
            queryTimeAndThickness: SIMD4<Float>(
                dataset.frameTimesSeconds[0],
                halfThicknessMeters,
                cellSizeMeters,
                0
            ),
            translationAndVelocityScale: SIMD4<Float>(
                0, 0, 0, scaling.velocityToLattice
            )
        )
        parameters = try backend.makeSharedBuffer(value: gpuParameters)

        let packedPoints = dataset.packedPoints()
        let sourcePointsBuffer = try backend.makeSharedBuffer(
            length: packedPoints.count * MemoryLayout<SIMD4<Float>>.stride
        )
        _ = packedPoints.withUnsafeBytes { source in
            memcpy(
                sourcePointsBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        sourcePoints = sourcePointsBuffer
        let frameTimesBuffer = try backend.makeSharedBuffer(
            length: dataset.frameTimesSeconds.count * MemoryLayout<Float>.stride
        )
        _ = dataset.frameTimesSeconds.withUnsafeBytes { source in
            memcpy(
                frameTimesBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        frameTimes = frameTimesBuffer
        let triangleIndicesBuffer = try backend.makeSharedBuffer(
            length: dataset.triangleIndices.count * MemoryLayout<UInt16>.stride
        )
        _ = dataset.triangleIndices.withUnsafeBytes { source in
            memcpy(
                triangleIndicesBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        triangleIndices = triangleIndicesBuffer
        let trianglePartIdentifiersBuffer = try backend.makeSharedBuffer(
            length: dataset.trianglePartIdentifiers.count
        )
        _ = dataset.trianglePartIdentifiers.withUnsafeBytes { source in
            memcpy(
                trianglePartIdentifiersBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        trianglePartIdentifiers = trianglePartIdentifiersBuffer

        let preparedBytes = dataset.vertexCount
            * MemoryLayout<GPUPreparedMeasuredWingPoint>.stride
        let maskBytes = grid.cellCount
        let wallBytes = grid.cellCount * MemoryLayout<SIMD4<Float>>.stride
        let distanceBytes = grid.cellCount * MemoryLayout<UInt32>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            parameters.length,
            sourcePoints.length,
            frameTimes.length,
            triangleIndices.length,
            trianglePartIdentifiers.length,
            preparedBytes,
            maskBytes,
            wallBytes,
            distanceBytes,
            preparedBytes,
            maskBytes,
            wallBytes,
        ])
        prepared = try backend.makePrivateBuffer(length: preparedBytes)
        partMask = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocityAndDistance = try backend.makePrivateBuffer(length: wallBytes)
        distanceKeys = try backend.makePrivateBuffer(length: distanceBytes)
        preparedStaging = try backend.makeSharedBuffer(length: preparedBytes)
        maskStaging = try backend.makeSharedBuffer(length: maskBytes)
        wallStaging = try backend.makeSharedBuffer(length: wallBytes)
        preparePipeline = try backend.pipeline(named: "prepareIndexedBirdSurface")
        clearPipeline = try backend.pipeline(named: "clearMeasuredWingSurface")
        rasterPipeline = try backend.pipeline(named: "rasterizeIndexedBirdSurface")
        resolvePipeline = try backend.pipeline(named: "resolveIndexedBirdSurface")
        flowResolvePipeline = try backend.pipeline(
            named: "resolveIndexedBirdSurfaceForFlow"
        )
    }

    func snapshot(
        timeSeconds: Float,
        includeWallField: Bool
    ) throws -> Snapshot {
        updateSurfaceTime(timeSeconds)
        var uniforms = GPUUniforms(
            configuration: configuration,
            time: 0,
            captureMacroscopicFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create indexed-bird geometry command buffer."
            )
        }
        try encodeIndexedPreparation(commandBuffer: commandBuffer)
        try encodeClear(commandBuffer: commandBuffer, uniforms: &uniforms)
        try encodeIndexedRaster(commandBuffer: commandBuffer, uniforms: &uniforms)
        try encodeIndexedResolve(commandBuffer: commandBuffer, uniforms: &uniforms)
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create indexed-bird geometry audit blit."
            )
        }
        blit.copy(
            from: prepared,
            sourceOffset: 0,
            to: preparedStaging,
            destinationOffset: 0,
            size: prepared.length
        )
        blit.copy(
            from: partMask,
            sourceOffset: 0,
            to: maskStaging,
            destinationOffset: 0,
            size: partMask.length
        )
        if includeWallField {
            blit.copy(
                from: wallVelocityAndDistance,
                sourceOffset: 0,
                to: wallStaging,
                destinationOffset: 0,
                size: wallVelocityAndDistance.length
            )
        }
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)

        let preparedValues = Array(UnsafeBufferPointer(
            start: preparedStaging.contents().assumingMemoryBound(
                to: GPUPreparedMeasuredWingPoint.self
            ),
            count: dataset.vertexCount
        ))
        let maskValues = Array(UnsafeBufferPointer(
            start: maskStaging.contents().assumingMemoryBound(to: UInt8.self),
            count: grid.cellCount
        ))
        let wallValues: [SIMD4<Float>]? = includeWallField
            ? Array(UnsafeBufferPointer(
                start: wallStaging.contents().assumingMemoryBound(
                    to: SIMD4<Float>.self
                ),
                count: grid.cellCount
            ))
            : nil
        return Snapshot(
            prepared: preparedValues,
            partIdentifiers: maskValues,
            wallVelocityAndDistance: wallValues
        )
    }

    private func updateSurfaceTime(_ timeSeconds: Float) {
        let interval = dataset.interpolationInterval(timeSeconds: timeSeconds)
        let surface = parameters.contents().assumingMemoryBound(
            to: GPUIndexedBirdSurfaceParameters.self
        )
        surface.pointee.counts.w = UInt32(interval.first)
        surface.pointee.queryTimeAndThickness.x = timeSeconds
    }

    func cpuRaster(timeSeconds: Float) -> CPURaster {
        let states = (0..<dataset.vertexCount).map {
            dataset.state(timeSeconds: timeSeconds, vertexIndex: $0)
        }
        let positions = states.map(\.positionMeters)
        let velocities = states.map {
            $0.velocityMetersPerSecond * velocityToLattice
        }
        var distanceKeys = [UInt32](
            repeating: UInt32.max,
            count: grid.cellCount
        )
        let origin = configuration.domainOriginMeters
        let cellSize = configuration.scaling.cellSizeMeters
        for triangle in 0..<dataset.triangleCount {
            let indices = dataset.triangle(triangle)
            let a = positions[Int(indices.x)]
            let b = positions[Int(indices.y)]
            let c = positions[Int(indices.z)]
            let guardDistance = halfThicknessMeters + 2 * cellSize
            let lowerWorld = componentMinimum(a, b, c)
                - SIMD3<Float>(repeating: guardDistance)
            let upperWorld = componentMaximum(a, b, c)
                + SIMD3<Float>(repeating: guardDistance)
            let lower = clampedCell(
                world: lowerWorld,
                origin: origin,
                cellSize: cellSize,
                upper: false
            )
            let upper = clampedCell(
                world: upperWorld,
                origin: origin,
                cellSize: cellSize,
                upper: true
            )
            for z in lower.z...upper.z {
                for y in lower.y...upper.y {
                    for x in lower.x...upper.x {
                        let world = origin + (
                            SIMD3<Float>(Float(x), Float(y), Float(z))
                                + SIMD3<Float>(repeating: 0.5)
                        ) * cellSize
                        let closest = triangleClosestPoint(
                            point: world,
                            a: a,
                            b: b,
                            c: c
                        )
                        let distanceCells = vectorLength(
                            world - closest.position
                        ) / cellSize
                        let bin = min(
                            UInt32((distanceCells * 65_536).rounded()),
                            0xF_FFFF
                        )
                        let key = (bin << 12) | UInt32(triangle)
                        let index = x + grid.x * (y + grid.y * z)
                        distanceKeys[index] = min(distanceKeys[index], key)
                    }
                }
            }
        }

        var mask = [UInt8](repeating: 0, count: grid.cellCount)
        var wall = [SIMD4<Float>](
            repeating: SIMD4<Float>(0, 0, 0, 16),
            count: grid.cellCount
        )
        for index in 0..<grid.cellCount {
            let key = distanceKeys[index]
            guard key != UInt32.max else { continue }
            let triangle = Int(key & 0xFFF)
            let indices = dataset.triangle(triangle)
            let x = index % grid.x
            let yz = index / grid.x
            let y = yz % grid.y
            let z = yz / grid.y
            let world = origin + (
                SIMD3<Float>(Float(x), Float(y), Float(z))
                    + SIMD3<Float>(repeating: 0.5)
            ) * cellSize
            let closest = triangleClosestPoint(
                point: world,
                a: positions[Int(indices.x)],
                b: positions[Int(indices.y)],
                c: positions[Int(indices.z)]
            )
            let velocity = closest.barycentric.x * velocities[Int(indices.x)]
                + closest.barycentric.y * velocities[Int(indices.y)]
                + closest.barycentric.z * velocities[Int(indices.z)]
            let signedDistance = vectorLength(world - closest.position)
                - halfThicknessMeters
            if signedDistance <= 0 {
                mask[index] = dataset.trianglePartIdentifiers[triangle]
            }
            wall[index] = SIMD4<Float>(
                velocity,
                signedDistance / cellSize
            )
        }
        return CPURaster(
            partIdentifiers: mask,
            wallVelocityAndDistance: wall
        )
    }

    var collisionMomentumControlVolumeMetadata: (
        bounds: MetalIndexedBirdSurfaceControlVolumeBounds,
        minimumDomainDistanceCells: Int,
        minimumSweptSurfaceDistanceCells: Double
    ) {
        let inset = configuration.spongeWidthCells + 1
        let maximumX = grid.x - inset
        let maximumY = grid.y - inset
        let maximumZ = grid.z - inset
        let bounds = MetalIndexedBirdSurfaceControlVolumeBounds(
            minimumX: inset,
            minimumY: inset,
            minimumZ: inset,
            maximumExclusiveX: maximumX,
            maximumExclusiveY: maximumY,
            maximumExclusiveZ: maximumZ
        )
        let minimumDomainDistance = min(
            inset - 1,
            grid.x - 1 - maximumX,
            grid.y - 1 - maximumY,
            grid.z - 1 - maximumZ
        )
        let origin = configuration.domainOriginMeters
        let cellSize = configuration.scaling.cellSizeMeters
        let lowerSurface = origin + SIMD3<Float>(repeating: Float(inset))
            * cellSize
        let upperSurface = origin + SIMD3<Float>(
            Float(maximumX), Float(maximumY), Float(maximumZ)
        ) * cellSize
        let lowerClearance = (dataset.minimumPositionMeters - lowerSurface)
            / SIMD3<Float>(repeating: cellSize)
        let upperClearance = (upperSurface - dataset.maximumPositionMeters)
            / SIMD3<Float>(repeating: cellSize)
        let sweptDistance = min(
            lowerClearance.x,
            lowerClearance.y,
            lowerClearance.z,
            upperClearance.x,
            upperClearance.y,
            upperClearance.z
        )
        return (
            bounds,
            minimumDomainDistance,
            Double(sweptDistance)
        )
    }

    func runCollisionMomentumClosure(
        plan: MetalIndexedBirdSurfacePilotPlan,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator,
        maximumRelativeRMSResidual: Double,
        maximumCorrectionActivationFraction: Double,
        requestedSteps stepLimit: Int? = nil,
        movingWallNormalization:
            MetalIndexedBirdSurfaceMovingWallNormalization = .referenceDensity,
        fixedSurfaceTimeSeconds: Float? = nil,
        boundaryTermCaptures: [MetalIndexedBoundaryTermCapture] = []
    ) throws -> MetalIndexedBirdSurfaceMomentumClosureCase {
        let started = Date()
        let requestedSteps = stepLimit ?? plan.preRollFluidSteps
        guard requestedSteps > 0,
              requestedSteps <= plan.totalFluidSteps,
              collisionOperator != .productionTRT,
              maximumRelativeRMSResidual.isFinite,
              maximumRelativeRMSResidual > 0,
              maximumCorrectionActivationFraction.isFinite,
              maximumCorrectionActivationFraction > 0 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "collision momentum-closure contract is invalid"
            )
        }
        let metadata = collisionMomentumControlVolumeMetadata
        guard metadata.minimumDomainDistanceCells
                >= configuration.spongeWidthCells,
              metadata.minimumSweptSurfaceDistanceCells > 0 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "collision momentum control surface overlaps the sponge or swept bird"
            )
        }
        let bounds = GPUIndexedControlVolumeBounds(
            minimum: SIMD4<UInt32>(
                UInt32(metadata.bounds.minimumX),
                UInt32(metadata.bounds.minimumY),
                UInt32(metadata.bounds.minimumZ),
                0
            ),
            maximumExclusive: SIMD4<UInt32>(
                UInt32(metadata.bounds.maximumExclusiveX),
                UInt32(metadata.bounds.maximumExclusiveY),
                UInt32(metadata.bounds.maximumExclusiveZ),
                0
            )
        )
        let cellCount = grid.cellCount
        let populationCount = D3Q19.count * cellCount
        let populationBytes = populationCount * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let partialCount = max(1, (cellCount + 255) / 256)
        let reductionBytes = partialCount
            * MemoryLayout<GPUForceTorque>.stride
        let populationPartialCount = max(1, (populationCount + 255) / 256)
        let populationMinimumBytes = populationPartialCount
            * MemoryLayout<GPUIndexedPopulationMinimum>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            populationBytes, populationBytes,
            maskBytes, densityBytes, velocityBytes,
            reductionBytes, reductionBytes,
            populationMinimumBytes,
            MemoryLayout<GPUBirdBodyState>.stride
        ])
        let populationsA = try backend.makePrivateBuffer(
            length: populationBytes
        )
        let populationsB = try backend.makePrivateBuffer(
            length: populationBytes
        )
        let solidPrevious = try backend.makePrivateBuffer(length: maskBytes)
        let densityScratch = try backend.makePrivateBuffer(length: densityBytes)
        let velocityAndCoveredMomentum = try backend.makePrivateBuffer(
            length: velocityBytes
        )
        let reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        let reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        let populationMinimumPartials = try backend.makeSharedBuffer(
            length: populationMinimumBytes
        )
        let bodyCenter = 0.5 * (
            dataset.minimumPositionMeters + dataset.maximumPositionMeters
        )
        let bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: bodyCenter))
        )
        let controlDiagnostics = try IndexedControlVolumeDiagnosticResources(
            backend: backend,
            cellCount: cellCount
        )
        let globalDiagnostics = try CoupledMomentumDiagnosticResources(
            backend: backend,
            cellCount: cellCount
        )
        let initializePipeline = try backend.pipeline(
            named: "initializePopulations"
        )
        let linkPipeline = try backend.pipeline(
            named: "buildMeasuredWingSurfaceLinks"
        )
        let fluidPipeline = try backend.pipeline(named: "stepFluidTRT")
        let forceReductionPipeline = try backend.pipeline(
            named: "reduceForceTorque"
        )
        let populationMinimumPipeline = try backend.pipeline(
            named: "reducePopulationMinimum"
        )

        let initialTime = fixedSurfaceTimeSeconds
            ?? dataset.frameTimesSeconds[0]
        guard initialTime >= dataset.frameTimesSeconds[0],
              initialTime <= dataset.frameTimesSeconds.last! else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "fixed collision momentum surface time is outside the sequence"
            )
        }
        updateSurfaceTime(initialTime)
        var initialUniforms = makePilotUniforms(
            step: 0,
            hasPreviousGeometry: false,
            collisionOperator: collisionOperator,
            movingWallNormalization: movingWallNormalization
        )
        guard let initialization = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to initialize collision momentum closure."
            )
        }
        try encodeIndexedPreparation(commandBuffer: initialization)
        try encodeClear(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        try encodeIndexedRaster(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        try encodeIndexedResolve(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        guard let initialBlit = initialization.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to copy the collision momentum initial mask."
            )
        }
        initialBlit.copy(
            from: partMask,
            sourceOffset: 0,
            to: solidPrevious,
            destinationOffset: 0,
            size: maskBytes
        )
        initialBlit.endEncoding()
        try encodeCouplingInitialization(
            commandBuffer: initialization,
            populations: populationsA,
            solid: solidPrevious,
            density: densityScratch,
            velocity: velocityAndCoveredMomentum,
            uniforms: &initialUniforms,
            pipeline: initializePipeline
        )
        initialization.commit()
        initialization.waitUntilCompleted()
        try check(initialization)

        var populationsIn = populationsA
        var populationsOut = populationsB
        var completedSteps = 0
        var activationCount = 0.0
        var maximumRestriction = 0.0
        var minimumPopulation = Double.infinity
        var maximumSolidCrossings = 0
        var allFinite = true
        var samples: [MetalIndexedBirdSurfaceMomentumClosureSample] = []
        samples.reserveCapacity(requestedSteps)
        let forceScale = Double(configuration.scaling.forceToPhysical)

        for step in 1...requestedSteps {
            let sourceTime = fixedSurfaceTimeSeconds ?? (
                initialTime
                    + Float(step) * configuration.scaling.timeStepSeconds
            )
            guard sourceTime <= dataset.frameTimesSeconds.last! + 1e-7 else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "collision momentum closure exceeds the surface sequence"
                )
            }
            updateSurfaceTime(sourceTime)
            var uniforms = makePilotUniforms(
                step: step,
                hasPreviousGeometry: true,
                collisionOperator: collisionOperator,
                movingWallNormalization: movingWallNormalization
            )
            var beforeUniforms = uniforms
            let globalFluidBefore = try globalDiagnostics.measureFluid(
                populations: populationsIn,
                solid: solidPrevious,
                uniforms: &beforeUniforms
            )
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create collision momentum step."
                )
            }
            let beforeBudget = try controlDiagnostics.encodeBefore(
                commandBuffer: commandBuffer,
                populations: populationsIn,
                solid: solidPrevious,
                bounds: bounds,
                uniforms: &uniforms
            )
            try encodeIndexedPreparation(commandBuffer: commandBuffer)
            try encodeClear(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeIndexedRaster(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeFlowResolve(
                commandBuffer: commandBuffer,
                solidPrevious: solidPrevious,
                previousPopulations: populationsIn,
                coveredFluidMomentum: velocityAndCoveredMomentum,
                uniforms: &uniforms
            )
            try encodeCouplingLinks(
                commandBuffer: commandBuffer,
                populations: populationsIn,
                uniforms: &uniforms,
                pipeline: linkPipeline
            )
            for capture in boundaryTermCaptures {
                try capture.encodeBoundaryTerms(
                    commandBuffer: commandBuffer,
                    step: step,
                    populationsIn: populationsIn,
                    solidCurrent: partMask,
                    wallVelocity: wallVelocityAndDistance,
                    uniforms: &uniforms
                )
            }
            try encodeCouplingFluid(
                commandBuffer: commandBuffer,
                populationsIn: populationsIn,
                populationsOut: populationsOut,
                solidPrevious: solidPrevious,
                density: densityScratch,
                velocity: velocityAndCoveredMomentum,
                partialLoads: reductionA,
                bodyState: bodyState,
                uniforms: &uniforms,
                pipeline: fluidPipeline
            )
            let reducedLoad = try encodeCouplingForceReduction(
                commandBuffer: commandBuffer,
                reductionA: reductionA,
                reductionB: reductionB,
                partialCount: partialCount,
                pipeline: forceReductionPipeline
            )
            let afterBudget = try controlDiagnostics.encodeAfter(
                commandBuffer: commandBuffer,
                populations: populationsOut,
                solidPrevious: solidPrevious,
                solidCurrent: partMask,
                wallVelocity: wallVelocityAndDistance,
                coveredFluidMomentum: velocityAndCoveredMomentum,
                bounds: bounds,
                uniforms: &uniforms
            )
            try encodePopulationMinimum(
                commandBuffer: commandBuffer,
                populations: populationsOut,
                partials: populationMinimumPartials,
                populationCount: populationCount,
                pipeline: populationMinimumPipeline
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            completedSteps = step

            let rawLoad = reducedLoad.contents()
                .assumingMemoryBound(to: GPUForceTorque.self)
                .pointee
            activationCount += Double(rawLoad.force.w)
            maximumRestriction = max(
                maximumRestriction,
                Double(rawLoad.torque.w)
            )
            let load = rawLoad.coreValue.forceNewtons
            let aerodynamic = SIMD3<Double>(
                Double(load.x), Double(load.y), Double(load.z)
            )
            let before = controlDiagnostics.read(beforeBudget)
            let after = controlDiagnostics.read(afterBudget)
            let oldMomentum = indexedControlVector(
                before.oldFluidMomentum
            )
            let newMomentum = indexedControlVector(
                after.newFluidMomentum
            )
            let outwardFlux = indexedControlVector(
                before.outwardMomentumFlux
            )
            let reservoir = indexedControlVector(
                after.topologyReservoirCorrection
            )
            let negativeStorage = (oldMomentum - newMomentum) * forceScale
            let negativeFlux = -outwardFlux * forceScale
            let reservoirForce = reservoir * forceScale
            let rawBudget = negativeStorage + negativeFlux
            let rawResidual = aerodynamic - rawBudget
            let solidCrossings = Int(
                before.outwardMomentumFlux.w.rounded()
            )
            maximumSolidCrossings = max(
                maximumSolidCrossings,
                solidCrossings
            )

            var afterUniforms = uniforms
            let globalFluidAfter = try globalDiagnostics.measureFluid(
                populations: populationsOut,
                solid: partMask,
                uniforms: &afterUniforms
            )
            let globalSources = try globalDiagnostics.captureSources(
                populationsIn: populationsIn,
                populationsOut: populationsOut,
                solidPrevious: solidPrevious,
                solidCurrent: partMask,
                wallVelocity: wallVelocityAndDistance,
                uniforms: &uniforms,
                advanceSolidPrevious: solidPrevious
            )
            let globalChange = physicalMomentum(
                globalFluidAfter - globalFluidBefore,
                scale: 1
            )
            let farField = physicalMomentum(
                globalSources.farField,
                scale: 1
            )
            let sponge = physicalMomentum(
                globalSources.sponge,
                scale: 1
            )
            let globalChangeRate = globalChange * forceScale
            let farFieldRate = farField * forceScale
            let spongeRate = sponge * forceScale
            let globalBudget = -globalChangeRate
                + farFieldRate + spongeRate
            let globalResidual = aerodynamic - globalBudget
            let minimum = readPopulationMinimum(
                partials: populationMinimumPartials,
                partialCount: populationPartialCount
            )
            let populationValue = minimum.nonFinite == 0
                ? Double(minimum.rawValue) : 0
            minimumPopulation = min(minimumPopulation, populationValue)
            let sample = MetalIndexedBirdSurfaceMomentumClosureSample(
                step: step,
                sourceTimeSeconds: Double(sourceTime),
                aerodynamicForceNewtons: aerodynamic,
                negativeFluidMomentumStorageRateNewtons: negativeStorage,
                negativeControlSurfaceMomentumFluxNewtons: negativeFlux,
                topologyReservoirCorrectionNewtons: reservoirForce,
                rawControlVolumeBudgetForceNewtons: rawBudget,
                rawControlVolumeClosureResidualNewtons: rawResidual,
                globalFluidMomentumChangeRateNewtons: globalChangeRate,
                globalFarFieldMomentumSourceRateNewtons: farFieldRate,
                globalSpongeMomentumSourceRateNewtons: spongeRate,
                globalFluidBudgetForceNewtons: globalBudget,
                globalFluidClosureResidualNewtons: globalResidual,
                solidControlSurfaceCrossingLinkCount: solidCrossings,
                minimumPopulation: populationValue
            )
            samples.append(sample)
            allFinite = allFinite
                && minimum.nonFinite == 0
                && rawLoad.force.w.isFinite
                && rawLoad.torque.w.isFinite
                && momentumClosureSampleIsFinite(sample)
            if !allFinite || populationValue <= 0 {
                break
            }
            swap(&populationsIn, &populationsOut)
        }

        let aerodynamicRMS = vectorRMS(
            samples.map(\.aerodynamicForceNewtons)
        )
        let rawBudgetRMS = vectorRMS(
            samples.map(\.rawControlVolumeBudgetForceNewtons)
        )
        let rawResidualRMS = vectorRMS(
            samples.map(\.rawControlVolumeClosureResidualNewtons)
        )
        let globalBudgetRMS = vectorRMS(
            samples.map(\.globalFluidBudgetForceNewtons)
        )
        let globalResidualRMS = vectorRMS(
            samples.map(\.globalFluidClosureResidualNewtons)
        )
        let relativeRaw = rawResidualRMS
            / max(aerodynamicRMS, rawBudgetRMS, 1.0e-30)
        let relativeGlobal = globalResidualRMS
            / max(aerodynamicRMS, globalBudgetRMS, 1.0e-30)
        let maximumRaw = samples.map {
            vectorMagnitude($0.rawControlVolumeClosureResidualNewtons)
        }.max() ?? .infinity
        let maximumGlobal = samples.map {
            vectorMagnitude($0.globalFluidClosureResidualNewtons)
        }.max() ?? .infinity
        let activationFraction = activationCount
            / max(Double(cellCount * completedSteps), 1)
        let positivityPassed = allFinite && minimumPopulation > 0
        let passed = completedSteps == requestedSteps
            && samples.count == requestedSteps
            && positivityPassed
            && maximumSolidCrossings == 0
            && relativeRaw <= maximumRelativeRMSResidual
            && relativeGlobal <= maximumRelativeRMSResidual
            && activationFraction <= maximumCorrectionActivationFraction
            && metadata.minimumDomainDistanceCells
                >= configuration.spongeWidthCells
            && metadata.minimumSweptSurfaceDistanceCells > 0
        return MetalIndexedBirdSurfaceMomentumClosureCase(
            collisionOperator: collisionOperator.rawValue,
            requestedSteps: requestedSteps,
            completedSteps: completedSteps,
            runtimeSeconds: Date().timeIntervalSince(started),
            collisionLimiterActivationCount: activationCount,
            collisionLimiterActivationFractionOfCellSteps:
                activationFraction,
            maximumCollisionRestriction: maximumRestriction,
            minimumPopulation: minimumPopulation.isFinite
                ? minimumPopulation : 0,
            allValuesFinite: allFinite,
            sampledPopulationPositivityPassed: positivityPassed,
            maximumSolidControlSurfaceCrossingLinkCount:
                maximumSolidCrossings,
            RMSAerodynamicForceNewtons: aerodynamicRMS,
            RMSRawControlVolumeBudgetForceNewtons: rawBudgetRMS,
            RMSRawControlVolumeClosureResidualNewtons: rawResidualRMS,
            relativeRMSRawControlVolumeClosureResidual: relativeRaw,
            maximumRawControlVolumeClosureResidualNewtons: maximumRaw,
            RMSGlobalFluidBudgetForceNewtons: globalBudgetRMS,
            RMSGlobalFluidClosureResidualNewtons: globalResidualRMS,
            relativeRMSGlobalFluidClosureResidual: relativeGlobal,
            maximumGlobalFluidClosureResidualNewtons: maximumGlobal,
            momentumClosurePassed: passed,
            eligibleForExtendedPilot: passed,
            samples: samples
        )
    }

    func runCoarseForcePilot(
        target: MeasuredBirdForceTarget,
        plan: MetalIndexedBirdSurfacePilotPlan,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator =
            .productionTRT,
        maximumFluidSteps: Int? = nil,
        populationDiagnosticStride: Int = 16,
        stopAtFirstNegativePopulation: Bool = false,
        populationStageCapture: MetalIndexedPopulationStageCapture? = nil,
        boundaryTermCapture: MetalIndexedBoundaryTermCapture? = nil
    ) throws -> MetalIndexedBirdSurfacePilotReport {
        let started = Date()
        let requestedFluidSteps = maximumFluidSteps ?? plan.totalFluidSteps
        guard requestedFluidSteps > 0,
              requestedFluidSteps <= plan.totalFluidSteps,
              populationDiagnosticStride > 0,
              plan.fluidStepsPerForceSample % populationDiagnosticStride == 0
        else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "coarse-pilot step or population-diagnostic contract is invalid"
            )
        }
        let cellCount = grid.cellCount
        let populationCount = D3Q19.count * cellCount
        let populationBytes = populationCount * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let partialCount = max(1, (cellCount + 255) / 256)
        let reductionBytes = partialCount
            * MemoryLayout<GPUForceTorque>.stride
        let populationPartialCount = max(1, (populationCount + 255) / 256)
        let populationMinimumBytes = populationPartialCount
            * MemoryLayout<GPUIndexedPopulationMinimum>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            populationBytes, populationBytes,
            maskBytes, densityBytes, velocityBytes,
            reductionBytes, reductionBytes,
            populationMinimumBytes, maskBytes,
            MemoryLayout<GPUBirdBodyState>.stride
        ])
        let populationsA = try backend.makePrivateBuffer(
            length: populationBytes
        )
        let populationsB = try backend.makePrivateBuffer(
            length: populationBytes
        )
        let solidPrevious = try backend.makePrivateBuffer(length: maskBytes)
        let densityScratch = try backend.makePrivateBuffer(length: densityBytes)
        let velocityAndCoveredMomentum = try backend.makePrivateBuffer(
            length: velocityBytes
        )
        let reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        let reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        let populationMinimumPartials = try backend.makeSharedBuffer(
            length: populationMinimumBytes
        )
        let currentMaskStaging = try backend.makeSharedBuffer(length: maskBytes)
        let bodyCenter = 0.5 * (
            dataset.minimumPositionMeters + dataset.maximumPositionMeters
        )
        let bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: bodyCenter))
        )
        let initializePipeline = try backend.pipeline(
            named: "initializePopulations"
        )
        let linkPipeline = try backend.pipeline(
            named: "buildMeasuredWingSurfaceLinks"
        )
        let fluidPipeline = try backend.pipeline(named: "stepFluidTRT")
        let forceReductionPipeline = try backend.pipeline(
            named: "reduceForceTorque"
        )
        let populationMinimumPipeline = try backend.pipeline(
            named: "reducePopulationMinimum"
        )

        let initialTime = dataset.frameTimesSeconds[0]
        guard abs(initialTime) <= 1e-8,
              abs(
                Double(configuration.scaling.timeStepSeconds)
                    - plan.fluidTimeStepSeconds
              ) <= 1e-10 else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "coarse pilot time scaling does not match the force target"
            )
        }
        updateSurfaceTime(initialTime)
        var initialUniforms = makePilotUniforms(
            step: 0,
            hasPreviousGeometry: false,
            collisionOperator: collisionOperator
        )
        guard let initialization = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create coarse-pilot initialization."
            )
        }
        try encodeIndexedPreparation(commandBuffer: initialization)
        try encodeClear(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        try encodeIndexedRaster(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        try encodeIndexedResolve(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        guard let initialBlit = initialization.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to copy the initial coarse-pilot mask."
            )
        }
        initialBlit.copy(
            from: partMask,
            sourceOffset: 0,
            to: solidPrevious,
            destinationOffset: 0,
            size: maskBytes
        )
        initialBlit.endEncoding()
        try encodeCouplingInitialization(
            commandBuffer: initialization,
            populations: populationsA,
            solid: solidPrevious,
            density: densityScratch,
            velocity: velocityAndCoveredMomentum,
            uniforms: &initialUniforms,
            pipeline: initializePipeline
        )
        initialization.commit()
        initialization.waitUntilCompleted()
        try check(initialization)

        var populationsIn = populationsA
        var populationsOut = populationsB
        var completedSteps = 0
        var intervalForce = SIMD3<Double>.zero
        var samples: [MetalIndexedBirdSurfacePilotSample] = []
        samples.reserveCapacity(plan.comparisonForceSamples)
        var allComponentsPresent = true
        var allLoadsFinite = true
        var allSampledPopulationsFinite = true
        var populationDiagnosticSamples = 0
        var minimumSampledPopulation = Double.infinity
        var firstNonFiniteLoadStep: Int?
        var firstNonFinitePopulationStep: Int?
        var firstNegativePopulationStep: Int?
        var firstNegativePopulationTime: Double?
        var firstNegativePopulationLinearIndex: Int?
        var firstNegativePopulationDirection: Int?
        var firstNegativePopulationCellCoordinate: SIMD3<Int>?
        var firstNegativePopulationDistance: Double?
        var firstNegativePopulationPartIdentifier: Int?
        var collisionLimiterActivationCount = 0.0
        var maximumCollisionRestriction = 0.0
        let dt = configuration.scaling.timeStepSeconds

        for step in 1...requestedFluidSteps {
            let sourceTime = initialTime + Float(step) * dt
            guard sourceTime <= dataset.frameTimesSeconds.last! + 1e-7 else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "coarse pilot exceeds the nonperiodic surface sequence"
                )
            }
            let forceEndpoint = step % plan.fluidStepsPerForceSample == 0
            let populationDiagnostic =
                step % populationDiagnosticStride == 0
            updateSurfaceTime(sourceTime)
            var uniforms = makePilotUniforms(
                step: step,
                hasPreviousGeometry: true,
                collisionOperator: collisionOperator
            )
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create coarse-pilot fluid step."
                )
            }
            try encodeIndexedPreparation(commandBuffer: commandBuffer)
            try encodeClear(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeIndexedRaster(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeFlowResolve(
                commandBuffer: commandBuffer,
                solidPrevious: solidPrevious,
                previousPopulations: populationsIn,
                coveredFluidMomentum: velocityAndCoveredMomentum,
                uniforms: &uniforms
            )
            try encodeCouplingLinks(
                commandBuffer: commandBuffer,
                populations: populationsIn,
                uniforms: &uniforms,
                pipeline: linkPipeline
            )
            try boundaryTermCapture?.encodeBoundaryTerms(
                commandBuffer: commandBuffer,
                step: step,
                populationsIn: populationsIn,
                solidCurrent: partMask,
                wallVelocity: wallVelocityAndDistance,
                uniforms: &uniforms
            )
            try populationStageCapture?.encodeBefore(
                commandBuffer: commandBuffer,
                step: step,
                populationsIn: populationsIn,
                solidPrevious: solidPrevious,
                solidCurrent: partMask,
                wallVelocity: wallVelocityAndDistance,
                uniforms: &uniforms
            )
            try encodeCouplingFluid(
                commandBuffer: commandBuffer,
                populationsIn: populationsIn,
                populationsOut: populationsOut,
                solidPrevious: solidPrevious,
                density: densityScratch,
                velocity: velocityAndCoveredMomentum,
                partialLoads: reductionA,
                bodyState: bodyState,
                uniforms: &uniforms,
                pipeline: fluidPipeline
            )
            try populationStageCapture?.encodeAfter(
                commandBuffer: commandBuffer,
                step: step,
                populationsOut: populationsOut,
                uniforms: &uniforms
            )
            let reducedLoad = try encodeCouplingForceReduction(
                commandBuffer: commandBuffer,
                reductionA: reductionA,
                reductionB: reductionB,
                partialCount: partialCount,
                pipeline: forceReductionPipeline
            )
            if populationDiagnostic {
                try encodePopulationMinimum(
                    commandBuffer: commandBuffer,
                    populations: populationsOut,
                    partials: populationMinimumPartials,
                    populationCount: populationCount,
                    pipeline: populationMinimumPipeline
                )
            }
            guard let stepBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to advance the coarse-pilot topology."
                )
            }
            if populationDiagnostic {
                stepBlit.copy(
                    from: partMask,
                    sourceOffset: 0,
                    to: currentMaskStaging,
                    destinationOffset: 0,
                    size: maskBytes
                )
                stepBlit.copy(
                    from: wallVelocityAndDistance,
                    sourceOffset: 0,
                    to: wallStaging,
                    destinationOffset: 0,
                    size: wallVelocityAndDistance.length
                )
            }
            stepBlit.copy(
                from: partMask,
                sourceOffset: 0,
                to: solidPrevious,
                destinationOffset: 0,
                size: maskBytes
            )
            stepBlit.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            completedSteps = step

            let rawLoad = reducedLoad.contents()
                .assumingMemoryBound(to: GPUForceTorque.self)
                .pointee
            let load = rawLoad.coreValue.forceNewtons
            if rawLoad.force.w.isFinite {
                collisionLimiterActivationCount += Double(rawLoad.force.w)
            }
            if rawLoad.torque.w.isFinite {
                maximumCollisionRestriction = max(
                    maximumCollisionRestriction,
                    Double(rawLoad.torque.w)
                )
            }
            let endpointForce = SIMD3<Double>(
                Double(load.x), Double(load.y), Double(load.z)
            )
            let loadFinite = endpointForce.x.isFinite
                && endpointForce.y.isFinite && endpointForce.z.isFinite
            if !loadFinite {
                allLoadsFinite = false
                firstNonFiniteLoadStep = firstNonFiniteLoadStep ?? step
            } else {
                intervalForce += endpointForce
            }

            var populationMinimum: GPUIndexedPopulationMinimum?
            if populationDiagnostic {
                populationDiagnosticSamples += 1
                let minimum = readPopulationMinimum(
                    partials: populationMinimumPartials,
                    partialCount: populationPartialCount
                )
                populationMinimum = minimum
                if minimum.nonFinite != 0 {
                    allSampledPopulationsFinite = false
                    firstNonFinitePopulationStep =
                        firstNonFinitePopulationStep ?? step
                } else {
                    let value = Double(minimum.rawValue)
                    minimumSampledPopulation = min(
                        minimumSampledPopulation,
                        value
                    )
                    if value < 0 {
                        if firstNegativePopulationStep == nil {
                            let linearIndex = Int(minimum.linearIndex)
                            let direction = linearIndex / cellCount
                            let cell = linearIndex % cellCount
                            let x = cell % grid.x
                            let yz = cell / grid.x
                            let y = yz % grid.y
                            let z = yz / grid.y
                            let distance = wallStaging.contents()
                                .assumingMemoryBound(to: SIMD4<Float>.self)[cell]
                                .w
                            let partIdentifier = currentMaskStaging.contents()
                                .assumingMemoryBound(to: UInt8.self)[cell]
                            firstNegativePopulationStep = step
                            firstNegativePopulationTime = Double(sourceTime)
                            firstNegativePopulationLinearIndex = linearIndex
                            firstNegativePopulationDirection = direction
                            firstNegativePopulationCellCoordinate = SIMD3(
                                x, y, z
                            )
                            firstNegativePopulationDistance = Double(distance)
                            firstNegativePopulationPartIdentifier =
                                Int(partIdentifier)
                        }
                    }
                }
            }

            if forceEndpoint {
                let targetIndex = step / plan.fluidStepsPerForceSample
                let intervalMean = intervalForce
                    / Double(plan.fluidStepsPerForceSample)
                intervalForce = .zero
                if targetIndex >= target.comparisonFirstSampleIndex,
                   targetIndex <= target.comparisonLastSampleIndex,
                   loadFinite,
                   let populationMinimum,
                   populationMinimum.nonFinite == 0 {
                    var componentCounts = [Int](
                        repeating: 0,
                        count: dataset.components.count
                    )
                    let mask = currentMaskStaging.contents()
                        .assumingMemoryBound(to: UInt8.self)
                    for cell in 0..<cellCount where mask[cell] != 0 {
                        let component = Int(mask[cell]) - 1
                        if componentCounts.indices.contains(component) {
                            componentCounts[component] += 1
                        }
                    }
                    let componentsPresent = componentCounts.allSatisfy { $0 > 0 }
                    allComponentsPresent = allComponentsPresent
                        && componentsPresent
                    let measuredX = target.forceXNewtons[targetIndex]
                    let measuredZ = target.forceZNewtons[targetIndex]
                    samples.append(MetalIndexedBirdSurfacePilotSample(
                        targetSampleIndex: targetIndex,
                        sourceTimeSeconds: target.timesSeconds[targetIndex],
                        sourceFrameCoordinate:
                            target.surfaceFrameCoordinates[targetIndex],
                        measuredForceXNewtons: measuredX,
                        measuredForceZNewtons: measuredZ,
                        endpointComputedForceNewtons: endpointForce,
                        intervalMeanComputedForceNewtons: intervalMean,
                        endpointResidualXNewtons: endpointForce.x - measuredX,
                        endpointResidualZNewtons: endpointForce.z - measuredZ,
                        intervalMeanResidualXNewtons: intervalMean.x - measuredX,
                        intervalMeanResidualZNewtons: intervalMean.z - measuredZ,
                        minimumPopulation: Double(populationMinimum.rawValue),
                        componentSolidCellCounts: componentCounts
                    ))
                }
            }
            swap(&populationsIn, &populationsOut)
            let sampledNegative = populationMinimum.map {
                $0.nonFinite == 0 && $0.rawValue < 0
            } ?? false
            if !loadFinite
                || (populationMinimum?.nonFinite ?? 0) != 0
                || (stopAtFirstNegativePopulation && sampledNegative) {
                break
            }
        }

        let minimumPopulation = minimumSampledPopulation.isFinite
            ? minimumSampledPopulation : 0
        let positivityPassed = allSampledPopulationsFinite
            && minimumPopulation > 0
        let comparisonMetricsAvailable = !samples.isEmpty
        let measuredMeanX = comparisonMetricsAvailable
            ? pilotMean(samples.map(\.measuredForceXNewtons)) : nil
        let measuredMeanZ = comparisonMetricsAvailable
            ? pilotMean(samples.map(\.measuredForceZNewtons)) : nil
        let endpointMeanX = comparisonMetricsAvailable
            ? pilotMean(samples.map { $0.endpointComputedForceNewtons.x }) : nil
        let endpointMeanZ = comparisonMetricsAvailable
            ? pilotMean(samples.map { $0.endpointComputedForceNewtons.z }) : nil
        let intervalMeanX = comparisonMetricsAvailable
            ? pilotMean(samples.map { $0.intervalMeanComputedForceNewtons.x })
            : nil
        let intervalMeanZ = comparisonMetricsAvailable
            ? pilotMean(samples.map { $0.intervalMeanComputedForceNewtons.z })
            : nil
        let measuredPairs = samples.map {
            SIMD2<Double>($0.measuredForceXNewtons, $0.measuredForceZNewtons)
        }
        let endpointPairs = samples.map {
            SIMD2<Double>(
                $0.endpointComputedForceNewtons.x,
                $0.endpointComputedForceNewtons.z
            )
        }
        let intervalPairs = samples.map {
            SIMD2<Double>(
                $0.intervalMeanComputedForceNewtons.x,
                $0.intervalMeanComputedForceNewtons.z
            )
        }
        let measuredImpulse = pilotTrapezoidalImpulse(
            measuredPairs,
            sampleRateHertz: target.forceSampleRateHertz
        )
        let endpointImpulse = pilotTrapezoidalImpulse(
            endpointPairs,
            sampleRateHertz: target.forceSampleRateHertz
        )
        let intervalImpulse = pilotTrapezoidalImpulse(
            intervalPairs,
            sampleRateHertz: target.forceSampleRateHertz
        )
        let integrationPassed = completedSteps == plan.totalFluidSteps
            && samples.count == plan.comparisonForceSamples
            && allComponentsPresent && comparisonMetricsAvailable
            && allLoadsFinite
            && positivityPassed
            && plan.maximumWallMach <= 0.15
            && configuration.scaling.tauPlus
                >= MetalIndexedBirdSurfacePilotValidator.minimumTauPlus
            && !plan.sourceViscosityRepresentableAtPilotGrid
            && !plan.experimentalAgreementGateApplied
        let verdict = integrationPassed
            ? (
                "The viscosity-floor coarse pilot completed the phase-locked "
                    + "measured-motion Metal path with finite positive sampled "
                    + "populations and all four surface components present."
            )
            : (
                "The viscosity-floor coarse pilot exposed an integration or "
                    + "population-stability failure before any experimental-"
                    + "agreement claim."
            )
        return MetalIndexedBirdSurfacePilotReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: dataset.datasetIdentifier,
            manifestSHA256: dataset.manifestSHA256,
            forceTargetIdentifier: target.datasetIdentifier,
            forceTargetSHA256: target.targetSHA256,
            gridX: grid.x,
            gridY: grid.y,
            gridZ: grid.z,
            plan: plan,
            runtimeSeconds: Date().timeIntervalSince(started),
            completedFluidSteps: completedSteps,
            recordedComparisonSamples: samples.count,
            recordedPopulationDiagnosticSamples: populationDiagnosticSamples,
            populationDiagnosticStride: populationDiagnosticStride,
            collisionOperator: collisionOperator.rawValue,
            collisionLimiterActivationCount:
                collisionLimiterActivationCount,
            collisionLimiterActivationFractionOfCellSteps:
                collisionLimiterActivationCount
                    / max(Double(cellCount * completedSteps), 1),
            maximumCollisionRestriction: maximumCollisionRestriction,
            forceEstimator: "conservative-moving-domain-mode-6",
            periodicBoundaries: false,
            allComponentsPresentAtComparisonSamples:
                allComponentsPresent && comparisonMetricsAvailable,
            allLoadsFinite: allLoadsFinite,
            allSampledPopulationsFinite: allSampledPopulationsFinite,
            sampledPopulationPositivityPassed: positivityPassed,
            minimumSampledPopulation: minimumPopulation,
            firstNonFiniteLoadStep: firstNonFiniteLoadStep,
            firstNonFinitePopulationStep: firstNonFinitePopulationStep,
            firstNegativePopulationStep: firstNegativePopulationStep,
            firstNegativePopulationTimeSeconds: firstNegativePopulationTime,
            firstNegativePopulationLinearIndex:
                firstNegativePopulationLinearIndex,
            firstNegativePopulationDirection:
                firstNegativePopulationDirection,
            firstNegativePopulationCellCoordinate:
                firstNegativePopulationCellCoordinate,
            firstNegativePopulationDistanceFromSurfaceCells:
                firstNegativePopulationDistance,
            firstNegativePopulationPartIdentifier:
                firstNegativePopulationPartIdentifier,
            measuredMeanForceXNewtons: measuredMeanX,
            measuredMeanForceZNewtons: measuredMeanZ,
            endpointMeanForceXNewtons: endpointMeanX,
            endpointMeanForceZNewtons: endpointMeanZ,
            intervalMeanForceXNewtons: intervalMeanX,
            intervalMeanForceZNewtons: intervalMeanZ,
            endpointNormalizedRMSError: comparisonMetricsAvailable
                ? pilotNormalizedRMSError(
                    measured: measuredPairs,
                    computed: endpointPairs
                ) : nil,
            intervalMeanNormalizedRMSError: comparisonMetricsAvailable
                ? pilotNormalizedRMSError(
                    measured: measuredPairs,
                    computed: intervalPairs
                ) : nil,
            measuredImpulseXNewtonSeconds:
                comparisonMetricsAvailable ? measuredImpulse.x : nil,
            measuredImpulseZNewtonSeconds:
                comparisonMetricsAvailable ? measuredImpulse.y : nil,
            endpointImpulseXNewtonSeconds:
                comparisonMetricsAvailable ? endpointImpulse.x : nil,
            endpointImpulseZNewtonSeconds:
                comparisonMetricsAvailable ? endpointImpulse.y : nil,
            intervalMeanImpulseXNewtonSeconds:
                comparisonMetricsAvailable ? intervalImpulse.x : nil,
            intervalMeanImpulseZNewtonSeconds:
                comparisonMetricsAvailable ? intervalImpulse.y : nil,
            measuredPeakTimeSeconds: comparisonMetricsAvailable
                ? pilotPeakTime(samples: samples) {
                    SIMD2($0.measuredForceXNewtons, $0.measuredForceZNewtons)
                } : nil,
            endpointPeakTimeSeconds: comparisonMetricsAvailable
                ? pilotPeakTime(samples: samples) {
                    SIMD2(
                        $0.endpointComputedForceNewtons.x,
                        $0.endpointComputedForceNewtons.z
                    )
                } : nil,
            intervalMeanPeakTimeSeconds: comparisonMetricsAvailable
                ? pilotPeakTime(samples: samples) {
                    SIMD2(
                        $0.intervalMeanComputedForceNewtons.x,
                        $0.intervalMeanComputedForceNewtons.z
                    )
                } : nil,
            experimentalAgreementGateApplied: false,
            integrationGatePassed: integrationPassed,
            samples: samples,
            scientificVerdict: verdict,
            claimBoundary: (
                "This is a bounded engineering pilot for startup, sign, "
                    + "phase, moving-boundary force accounting, and sampled "
                    + "population positivity. Its viscosity is "
                    + String(format: "%.3g", plan.pilotToSourceViscosityRatio)
                    + " times the measured source condition, so its force "
                    + "errors are descriptive only and cannot establish "
                    + "experimental agreement or quantitative bird flight."
            )
        )
    }

    func auditProductionCoupling(
        minimumSteps: Int,
        maximumSteps: Int,
        minimumTopologyTransitions: Int,
        maximumRelativeRMSResidual: Double
    ) throws -> MetalIndexedBirdSurfaceCouplingReport {
        let started = Date()
        let cellCount = grid.cellCount
        let populationBytes = D3Q19.count * cellCount
            * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let partialCount = max(1, (cellCount + 255) / 256)
        let reductionBytes = partialCount
            * MemoryLayout<GPUForceTorque>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            populationBytes, populationBytes,
            maskBytes, densityBytes, velocityBytes,
            reductionBytes, reductionBytes,
            maskBytes, maskBytes,
            MemoryLayout<GPUBirdBodyState>.stride,
        ])
        let populationsA = try backend.makePrivateBuffer(
            length: populationBytes
        )
        let populationsB = try backend.makePrivateBuffer(
            length: populationBytes
        )
        let solidPrevious = try backend.makePrivateBuffer(length: maskBytes)
        let densityScratch = try backend.makePrivateBuffer(length: densityBytes)
        let velocityAndCoveredMomentum = try backend.makePrivateBuffer(
            length: velocityBytes
        )
        let reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        let reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        let previousMaskStaging = try backend.makeSharedBuffer(length: maskBytes)
        let currentMaskStaging = try backend.makeSharedBuffer(length: maskBytes)
        let bodyCenter = 0.5 * (
            dataset.minimumPositionMeters + dataset.maximumPositionMeters
        )
        let bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: bodyCenter))
        )
        let initializePipeline = try backend.pipeline(
            named: "initializePopulations"
        )
        let linkPipeline = try backend.pipeline(
            named: "buildMeasuredWingSurfaceLinks"
        )
        let fluidPipeline = try backend.pipeline(named: "stepFluidTRT")
        let forceReductionPipeline = try backend.pipeline(
            named: "reduceForceTorque"
        )
        let diagnostics = try CoupledMomentumDiagnosticResources(
            backend: backend,
            cellCount: cellCount
        )

        let initialTime = dataset.frameTimesSeconds[0]
        updateSurfaceTime(initialTime)
        var initialUniforms = makeCouplingUniforms(
            step: 0,
            hasPreviousGeometry: false
        )
        guard let initialization = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create indexed coupling initialization."
            )
        }
        try encodeIndexedPreparation(commandBuffer: initialization)
        try encodeClear(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        try encodeIndexedRaster(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        try encodeIndexedResolve(
            commandBuffer: initialization,
            uniforms: &initialUniforms
        )
        guard let initialBlit = initialization.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to copy the initial indexed coupling mask."
            )
        }
        initialBlit.copy(
            from: partMask,
            sourceOffset: 0,
            to: solidPrevious,
            destinationOffset: 0,
            size: maskBytes
        )
        initialBlit.endEncoding()
        try encodeCouplingInitialization(
            commandBuffer: initialization,
            populations: populationsA,
            solid: solidPrevious,
            density: densityScratch,
            velocity: velocityAndCoveredMomentum,
            uniforms: &initialUniforms,
            pipeline: initializePipeline
        )
        initialization.commit()
        initialization.waitUntilCompleted()
        try check(initialization)

        var populationsIn = populationsA
        var populationsOut = populationsB
        var samples: [MetalIndexedBirdSurfaceCouplingSample] = []
        samples.reserveCapacity(maximumSteps)
        var totalCovered = 0
        var totalUncovered = 0
        var totalPersistentLinks = 0
        var maximumTopologyCounterMismatch = 0
        var finalComponentCounts = [Int](
            repeating: 0,
            count: dataset.components.count
        )
        var allFinite = true
        let dt = configuration.scaling.timeStepSeconds
        let momentumScale = Double(configuration.scaling.forceToPhysical)
            * Double(dt)

        for step in 1...maximumSteps {
            let sourceTime = initialTime + Float(step) * dt
            guard sourceTime <= dataset.frameTimesSeconds.last! else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "coupling audit exceeds the nonperiodic surface sequence"
                )
            }
            var beforeUniforms = makeCouplingUniforms(
                step: step - 1,
                hasPreviousGeometry: true
            )
            let fluidBeforeRaw = try diagnostics.measureFluid(
                populations: populationsIn,
                solid: solidPrevious,
                uniforms: &beforeUniforms
            )

            updateSurfaceTime(sourceTime)
            var uniforms = makeCouplingUniforms(
                step: step,
                hasPreviousGeometry: true
            )
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create indexed coupling step."
                )
            }
            try encodeIndexedPreparation(commandBuffer: commandBuffer)
            try encodeClear(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeIndexedRaster(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeFlowResolve(
                commandBuffer: commandBuffer,
                solidPrevious: solidPrevious,
                previousPopulations: populationsIn,
                coveredFluidMomentum: velocityAndCoveredMomentum,
                uniforms: &uniforms
            )
            try encodeCouplingLinks(
                commandBuffer: commandBuffer,
                populations: populationsIn,
                uniforms: &uniforms,
                pipeline: linkPipeline
            )
            try encodeCouplingFluid(
                commandBuffer: commandBuffer,
                populationsIn: populationsIn,
                populationsOut: populationsOut,
                solidPrevious: solidPrevious,
                density: densityScratch,
                velocity: velocityAndCoveredMomentum,
                partialLoads: reductionA,
                bodyState: bodyState,
                uniforms: &uniforms,
                pipeline: fluidPipeline
            )
            let reducedLoad = try encodeCouplingForceReduction(
                commandBuffer: commandBuffer,
                reductionA: reductionA,
                reductionB: reductionB,
                partialCount: partialCount,
                pipeline: forceReductionPipeline
            )
            guard let maskBlit = commandBuffer.makeBlitCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to audit indexed topology transitions."
                )
            }
            maskBlit.copy(
                from: solidPrevious,
                sourceOffset: 0,
                to: previousMaskStaging,
                destinationOffset: 0,
                size: maskBytes
            )
            maskBlit.copy(
                from: partMask,
                sourceOffset: 0,
                to: currentMaskStaging,
                destinationOffset: 0,
                size: maskBytes
            )
            maskBlit.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)

            var newlyCovered = 0
            var newlyUncovered = 0
            var componentCounts = [Int](
                repeating: 0,
                count: dataset.components.count
            )
            let oldMask = previousMaskStaging.contents()
                .assumingMemoryBound(to: UInt8.self)
            let newMask = currentMaskStaging.contents()
                .assumingMemoryBound(to: UInt8.self)
            for cell in 0..<cellCount {
                let oldSolid = oldMask[cell] != 0
                let newIdentifier = newMask[cell]
                let newSolid = newIdentifier != 0
                if !oldSolid && newSolid { newlyCovered += 1 }
                if oldSolid && !newSolid { newlyUncovered += 1 }
                if newSolid {
                    let index = Int(newIdentifier) - 1
                    if componentCounts.indices.contains(index) {
                        componentCounts[index] += 1
                    } else {
                        allFinite = false
                    }
                }
            }
            finalComponentCounts = componentCounts

            let fluidAfterRaw = try diagnostics.measureFluid(
                populations: populationsOut,
                solid: partMask,
                uniforms: &uniforms
            )
            let sources = try diagnostics.captureSources(
                populationsIn: populationsIn,
                populationsOut: populationsOut,
                solidPrevious: solidPrevious,
                solidCurrent: partMask,
                wallVelocity: wallVelocityAndDistance,
                uniforms: &uniforms
            )
            let load = reducedLoad.contents()
                .assumingMemoryBound(to: GPUForceTorque.self)
                .pointee.coreValue
            let fluidBefore = physicalMomentum(
                fluidBeforeRaw,
                scale: momentumScale
            )
            let fluidAfter = physicalMomentum(
                fluidAfterRaw,
                scale: momentumScale
            )
            let aerodynamicImpulse = SIMD3<Double>(
                Double(load.forceNewtons.x) * Double(dt),
                Double(load.forceNewtons.y) * Double(dt),
                Double(load.forceNewtons.z) * Double(dt)
            )
            let farFieldImpulse = physicalMomentum(
                sources.farField,
                scale: momentumScale
            )
            let spongeImpulse = physicalMomentum(
                sources.sponge,
                scale: momentumScale
            )
            let persistentImpulse = physicalMomentum(
                sources.persistentLinkExchange,
                scale: momentumScale
            )
            let fluidBoundaryImpulse = fluidAfter - fluidBefore
                - farFieldImpulse - spongeImpulse
            let remainingImpulse = fluidBoundaryImpulse - persistentImpulse
            let residual = aerodynamicImpulse + fluidBoundaryImpulse
            let sourceTransitions = Int(sources.counts.w)
            maximumTopologyCounterMismatch = max(
                maximumTopologyCounterMismatch,
                abs(sourceTransitions - newlyCovered - newlyUncovered)
            )
            totalCovered += newlyCovered
            totalUncovered += newlyUncovered
            totalPersistentLinks += Int(sources.counts.z)
            let sample = MetalIndexedBirdSurfaceCouplingSample(
                step: step,
                sourceTimeSeconds: Double(sourceTime),
                newlyCoveredCellCount: newlyCovered,
                newlyUncoveredCellCount: newlyUncovered,
                sourceLedgerTransitionCellCount: sourceTransitions,
                persistentBoundaryLinkCount: Int(sources.counts.z),
                fluidMomentumBefore: fluidBefore,
                fluidMomentumAfter: fluidAfter,
                aerodynamicImpulse: aerodynamicImpulse,
                farFieldImpulseToFluid: farFieldImpulse,
                spongeImpulseToFluid: spongeImpulse,
                diagnosticPersistentLinkImpulseToFluid: persistentImpulse,
                remainingImpulseAfterDiagnosticLinks: remainingImpulse,
                fluidBoundaryImpulse: fluidBoundaryImpulse,
                boundaryClosureResidual: residual
            )
            samples.append(sample)
            allFinite = allFinite
                && fluidBeforeRaw.x.isFinite && fluidAfterRaw.x.isFinite
                && couplingSampleIsFinite(sample)

            if samples.count >= minimumSteps,
               totalCovered + totalUncovered >= minimumTopologyTransitions {
                break
            }
            try copyCouplingMask(
                from: partMask,
                to: solidPrevious,
                byteCount: maskBytes
            )
            swap(&populationsIn, &populationsOut)
        }

        let aerodynamicRMS = vectorRMS(samples.map(\.aerodynamicImpulse))
        let boundaryRMS = vectorRMS(samples.map(\.fluidBoundaryImpulse))
        let residualRMS = vectorRMS(samples.map(\.boundaryClosureResidual))
        let relativeRMS = residualRMS
            / max(aerodynamicRMS, boundaryRMS, 1.0e-30)
        let maximumRelative = samples.map { sample in
            vectorMagnitude(sample.boundaryClosureResidual)
                / max(
                    vectorMagnitude(sample.aerodynamicImpulse),
                    vectorMagnitude(sample.fluidBoundaryImpulse),
                    1.0e-30
                )
        }.max() ?? .infinity
        let maximumResidual = samples.map {
            vectorMagnitude($0.boundaryClosureResidual)
        }.max() ?? .infinity
        let maximumWallSpeed = Double(
            dataset.maximumPointSpeedMetersPerSecond * velocityToLattice
        )
        let maximumMach = maximumWallSpeed / Double(D3Q19.soundSpeed)
        let passed = samples.count >= minimumSteps
            && totalCovered + totalUncovered >= minimumTopologyTransitions
            && totalPersistentLinks > 0
            && maximumTopologyCounterMismatch == 0
            && samples.allSatisfy {
                $0.farFieldImpulseToFluid == .zero
                    && $0.spongeImpulseToFluid == .zero
            }
            && finalComponentCounts.allSatisfy { $0 > 0 }
            && maximumMach <= 0.15
            && relativeRMS <= maximumRelativeRMSResidual
            && allFinite
            && dataset.completeBirdSurfaceReady
            && !dataset.quantitativeForceAcceptanceReady
        return MetalIndexedBirdSurfaceCouplingReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: dataset.datasetIdentifier,
            manifestSHA256: dataset.manifestSHA256,
            gridX: grid.x,
            gridY: grid.y,
            gridZ: grid.z,
            cellSizeMeters: Double(configuration.scaling.cellSizeMeters),
            timeStepSeconds: Double(dt),
            steps: samples.count,
            runtimeSeconds: Date().timeIntervalSince(started),
            maximumWallSpeedLattice: maximumWallSpeed,
            maximumWallMach: maximumMach,
            acceptanceDefinition: (
                "production aerodynamic impulse + independently reduced "
                    + "before/after fluid momentum change; the diagnostic "
                    + "persistent-link split is reported but is not used for "
                    + "acceptance"
            ),
            geometryKernels: [
                "prepareIndexedBirdSurface",
                "clearMeasuredWingSurface",
                "rasterizeIndexedBirdSurface",
                "resolveIndexedBirdSurfaceForFlow",
            ],
            linkKernel: "buildMeasuredWingSurfaceLinks",
            fluidKernel: "stepFluidTRT",
            forceEstimator: "conservative-moving-domain-mode-6",
            periodicBoundaries: true,
            spongeStrength: 0,
            componentSolidCellCounts: finalComponentCounts,
            newlyCoveredCellEvents: totalCovered,
            newlyUncoveredCellEvents: totalUncovered,
            persistentBoundaryLinkEvents: totalPersistentLinks,
            maximumTopologyCounterMismatchCells:
                maximumTopologyCounterMismatch,
            relativeRMSBoundaryClosureResidual: relativeRMS,
            maximumRelativeBoundaryClosureResidual: maximumRelative,
            maximumAllowedRelativeRMSBoundaryClosureResidual:
                maximumRelativeRMSResidual,
            maximumBoundaryClosureResidualKilogramMetersPerSecond:
                maximumResidual,
            allValuesFinite: allFinite,
            samples: samples,
            passed: passed,
            claimBoundary: (
                "This short periodic, zero-sponge gate closes the accepted "
                    + "indexed surface against the production interpolated "
                    + "link, conservative topology-force, and TRT fluid path. "
                    + "It is an integration/impulse test, not a developed-flow "
                    + "or experimental-force comparison."
            )
        )
    }

    private func clampedCell(
        world: SIMD3<Float>,
        origin: SIMD3<Float>,
        cellSize: Float,
        upper: Bool
    ) -> SIMD3<Int> {
        let scaled = (world - origin) / cellSize
            - SIMD3<Float>(repeating: 0.5)
        let converted = SIMD3<Int>(
            Int(upper ? ceil(scaled.x) : floor(scaled.x)),
            Int(upper ? ceil(scaled.y) : floor(scaled.y)),
            Int(upper ? ceil(scaled.z) : floor(scaled.z))
        )
        return SIMD3<Int>(
            min(max(converted.x, 0), grid.x - 1),
            min(max(converted.y, 0), grid.y - 1),
            min(max(converted.z, 0), grid.z - 1)
        )
    }

    private func encodeIndexedPreparation(
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird preparation."
            )
        }
        encoder.setBuffer(sourcePoints, offset: 0, index: 0)
        encoder.setBuffer(frameTimes, offset: 0, index: 1)
        encoder.setBuffer(prepared, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        backend.dispatch1D(
            encoder: encoder,
            pipeline: preparePipeline,
            count: dataset.vertexCount
        )
        encoder.endEncoding()
    }

    private func encodeClear(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird clear."
            )
        }
        encoder.setBuffer(partMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 1)
        encoder.setBuffer(distanceKeys, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: clearPipeline,
            count: grid.cellCount
        )
        encoder.endEncoding()
    }

    private func encodeIndexedRaster(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird rasterization."
            )
        }
        encoder.setBuffer(prepared, offset: 0, index: 0)
        encoder.setBuffer(triangleIndices, offset: 0, index: 1)
        encoder.setBuffer(distanceKeys, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: rasterPipeline,
            count: dataset.triangleCount
        )
        encoder.endEncoding()
    }

    private func encodeIndexedResolve(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird resolution."
            )
        }
        encoder.setBuffer(partMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 1)
        encoder.setBuffer(prepared, offset: 0, index: 2)
        encoder.setBuffer(triangleIndices, offset: 0, index: 3)
        encoder.setBuffer(trianglePartIdentifiers, offset: 0, index: 4)
        encoder.setBuffer(distanceKeys, offset: 0, index: 5)
        encoder.setBuffer(parameters, offset: 0, index: 6)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: resolvePipeline,
            count: grid.cellCount
        )
        encoder.endEncoding()
    }

    private func makeCouplingUniforms(
        step: Int,
        hasPreviousGeometry: Bool
    ) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: Float(step),
            captureMacroscopicFields: false,
            accumulateLoads: true,
            hasPreviousGeometry: hasPreviousGeometry,
            periodicBoundaries: true,
            caseParameters: SIMD4<Float>(0, 6, 0, -1)
        )
    }

    private func makePilotUniforms(
        step: Int,
        hasPreviousGeometry: Bool,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator,
        movingWallNormalization:
            MetalIndexedBirdSurfaceMovingWallNormalization = .referenceDensity
    ) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: Float(step),
            captureMacroscopicFields: false,
            accumulateLoads: true,
            hasPreviousGeometry: hasPreviousGeometry,
            periodicBoundaries: false,
            usePreStepLocalDensityForMovingWall:
                movingWallNormalization.usesPreStepLocalDensity,
            caseParameters: SIMD4<Float>(
                0, 6, 0, collisionOperator.caseParameterW
            )
        )
    }

    private func encodeCouplingInitialization(
        commandBuffer: MTLCommandBuffer,
        populations: MTLBuffer,
        solid: MTLBuffer,
        density: MTLBuffer,
        velocity: MTLBuffer,
        uniforms: inout GPUUniforms,
        pipeline: MTLComputePipelineState
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to initialize indexed coupling populations."
            )
        }
        encoder.setBuffer(populations, offset: 0, index: 0)
        encoder.setBuffer(solid, offset: 0, index: 1)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 2)
        encoder.setBuffer(density, offset: 0, index: 3)
        encoder.setBuffer(velocity, offset: 0, index: 4)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: pipeline,
            count: grid.cellCount
        )
        encoder.endEncoding()
    }

    private func encodeFlowResolve(
        commandBuffer: MTLCommandBuffer,
        solidPrevious: MTLBuffer,
        previousPopulations: MTLBuffer,
        coveredFluidMomentum: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to resolve indexed flow geometry."
            )
        }
        encoder.setBuffer(partMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 1)
        encoder.setBuffer(solidPrevious, offset: 0, index: 2)
        encoder.setBuffer(prepared, offset: 0, index: 3)
        encoder.setBuffer(triangleIndices, offset: 0, index: 4)
        encoder.setBuffer(trianglePartIdentifiers, offset: 0, index: 5)
        encoder.setBuffer(distanceKeys, offset: 0, index: 6)
        encoder.setBuffer(parameters, offset: 0, index: 7)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 8
        )
        encoder.setBuffer(previousPopulations, offset: 0, index: 9)
        encoder.setBuffer(coveredFluidMomentum, offset: 0, index: 10)
        backend.dispatch1D(
            encoder: encoder,
            pipeline: flowResolvePipeline,
            count: grid.cellCount
        )
        encoder.endEncoding()
    }

    private func encodeCouplingLinks(
        commandBuffer: MTLCommandBuffer,
        populations: MTLBuffer,
        uniforms: inout GPUUniforms,
        pipeline: MTLComputePipelineState
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to build indexed coupling links."
            )
        }
        encoder.setBuffer(partMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 1)
        encoder.setBuffer(populations, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch3D(
            encoder: encoder,
            pipeline: pipeline,
            width: grid.x,
            height: grid.y,
            depth: grid.z
        )
        encoder.endEncoding()
    }

    private func encodeCouplingFluid(
        commandBuffer: MTLCommandBuffer,
        populationsIn: MTLBuffer,
        populationsOut: MTLBuffer,
        solidPrevious: MTLBuffer,
        density: MTLBuffer,
        velocity: MTLBuffer,
        partialLoads: MTLBuffer,
        bodyState: MTLBuffer,
        uniforms: inout GPUUniforms,
        pipeline: MTLComputePipelineState
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to advance indexed coupling fluid."
            )
        }
        encoder.setBuffer(populationsIn, offset: 0, index: 0)
        encoder.setBuffer(populationsOut, offset: 0, index: 1)
        encoder.setBuffer(solidPrevious, offset: 0, index: 2)
        encoder.setBuffer(partMask, offset: 0, index: 3)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 4)
        encoder.setBuffer(density, offset: 0, index: 5)
        encoder.setBuffer(velocity, offset: 0, index: 6)
        encoder.setBuffer(partialLoads, offset: 0, index: 7)
        encoder.setBuffer(bodyState, offset: 0, index: 8)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 9
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: pipeline,
            count: grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func encodeCouplingForceReduction(
        commandBuffer: MTLCommandBuffer,
        reductionA: MTLBuffer,
        reductionB: MTLBuffer,
        partialCount: Int,
        pipeline: MTLComputePipelineState
    ) throws -> MTLBuffer {
        var input = reductionA
        var output = reductionB
        var count = partialCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to reduce indexed coupling load."
                )
            }
            encoder.setBuffer(input, offset: 0, index: 0)
            encoder.setBuffer(output, offset: 0, index: 1)
            encoder.setBytes(
                &count32,
                length: MemoryLayout<UInt32>.stride,
                index: 2
            )
            backend.dispatch1D(
                encoder: encoder,
                pipeline: pipeline,
                count: outputCount
            )
            encoder.endEncoding()
            count = outputCount
            input = output
            output = output === reductionA ? reductionB : reductionA
        }
        return input
    }

    private func encodePopulationMinimum(
        commandBuffer: MTLCommandBuffer,
        populations: MTLBuffer,
        partials: MTLBuffer,
        populationCount: Int,
        pipeline: MTLComputePipelineState
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode coarse-pilot population minimum."
            )
        }
        var count = UInt32(populationCount)
        encoder.setBuffer(populations, offset: 0, index: 0)
        encoder.setBuffer(partials, offset: 0, index: 1)
        encoder.setBytes(
            &count,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: pipeline,
            count: populationCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func readPopulationMinimum(
        partials: MTLBuffer,
        partialCount: Int
    ) -> GPUIndexedPopulationMinimum {
        let pointer = partials.contents().assumingMemoryBound(
            to: GPUIndexedPopulationMinimum.self
        )
        var selected = pointer[0]
        if partialCount > 1 {
            for index in 1..<partialCount {
                let candidate = pointer[index]
                if candidate.comparisonValue < selected.comparisonValue
                    || (candidate.comparisonValue
                            == selected.comparisonValue
                        && candidate.linearIndex < selected.linearIndex) {
                    selected = candidate
                }
            }
        }
        return selected
    }

    private func copyCouplingMask(
        from source: MTLBuffer,
        to destination: MTLBuffer,
        byteCount: Int
    ) throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to advance indexed coupling topology."
            )
        }
        blit.copy(
            from: source,
            sourceOffset: 0,
            to: destination,
            destinationOffset: 0,
            size: byteCount
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Indexed-bird geometry command failed."
            )
        }
    }
}

private struct GPUIndexedPopulationStageProvenance {
    var preReconstruction: SIMD4<Float>
    var macroscopic: SIMD4<Float>
    var collision: SIMD4<Float>
    var output: SIMD4<Float>
    var extrema: SIMD4<Float>
    var reconstructed0: SIMD4<Float>
    var reconstructed1: SIMD4<Float>
    var reconstructed2: SIMD4<Float>
    var reconstructed3: SIMD4<Float>
    var reconstructed4: SIMD4<Float>
    var metadata: SIMD4<UInt32>
    var sourceMasks: SIMD4<UInt32>
    var state: SIMD4<UInt32>
}

private struct GPUIndexedBoundaryTerm {
    var primitive: SIMD4<Float>
    var contributions: SIMD4<Float>
    var counterfactuals: SIMD4<Float>
    var alternatives: SIMD4<Float>
    var captured: SIMD4<Float>
    var metadata: SIMD4<UInt32>
    var branch: SIMD4<UInt32>
}

private struct GPUIndexedPopulationMinimum {
    var comparisonValue: Float
    var rawValue: Float
    var linearIndex: UInt32
    var nonFinite: UInt32
}

private func physicalMomentum(
    _ raw: SIMD4<Float>,
    scale: Double
) -> SIMD3<Double> {
    SIMD3<Double>(
        Double(raw.y) * scale,
        Double(raw.z) * scale,
        Double(raw.w) * scale
    )
}

private func indexedControlVector(
    _ raw: SIMD4<Float>
) -> SIMD3<Double> {
    SIMD3<Double>(Double(raw.x), Double(raw.y), Double(raw.z))
}

private func pilotMean(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

private func pilotNormalizedRMSError(
    measured: [SIMD2<Double>],
    computed: [SIMD2<Double>]
) -> Double {
    guard measured.count == computed.count, !measured.isEmpty else { return 0 }
    var numerator = 0.0
    var denominator = 0.0
    for index in measured.indices {
        let residual = computed[index] - measured[index]
        numerator += residual.x * residual.x + residual.y * residual.y
        denominator += measured[index].x * measured[index].x
            + measured[index].y * measured[index].y
    }
    return sqrt(numerator / max(denominator, 1e-30))
}

private func pilotPairwiseNormalizedRMSDifference(
    first: [SIMD3<Double>]?,
    second: [SIMD3<Double>]?
) -> Double? {
    guard let first,
          let second,
          first.count == second.count,
          !first.isEmpty else { return nil }
    var numerator = 0.0
    var firstEnergy = 0.0
    var secondEnergy = 0.0
    for index in first.indices {
        let difference = first[index] - second[index]
        numerator += difference.x * difference.x
            + difference.y * difference.y
            + difference.z * difference.z
        firstEnergy += first[index].x * first[index].x
            + first[index].y * first[index].y
            + first[index].z * first[index].z
        secondEnergy += second[index].x * second[index].x
            + second[index].y * second[index].y
            + second[index].z * second[index].z
    }
    return sqrt(numerator / max(0.5 * (firstEnergy + secondEnergy), 1e-30))
}

private func pilotTrapezoidalImpulse(
    _ values: [SIMD2<Double>],
    sampleRateHertz: Double
) -> SIMD2<Double> {
    guard values.count >= 2 else { return .zero }
    var result = SIMD2<Double>.zero
    for index in 1..<values.count {
        result += 0.5 * (values[index - 1] + values[index])
            / sampleRateHertz
    }
    return result
}

private func pilotPeakTime(
    samples: [MetalIndexedBirdSurfacePilotSample],
    value: (MetalIndexedBirdSurfacePilotSample) -> SIMD2<Double>
) -> Double {
    guard let peak = samples.max(by: {
        let lhs = value($0)
        let rhs = value($1)
        return lhs.x * lhs.x + lhs.y * lhs.y
            < rhs.x * rhs.x + rhs.y * rhs.y
    }) else { return 0 }
    return peak.sourceTimeSeconds
}

private func couplingSampleIsFinite(
    _ sample: MetalIndexedBirdSurfaceCouplingSample
) -> Bool {
    [
        sample.fluidMomentumBefore,
        sample.fluidMomentumAfter,
        sample.aerodynamicImpulse,
        sample.farFieldImpulseToFluid,
        sample.spongeImpulseToFluid,
        sample.diagnosticPersistentLinkImpulseToFluid,
        sample.remainingImpulseAfterDiagnosticLinks,
        sample.fluidBoundaryImpulse,
        sample.boundaryClosureResidual,
    ].allSatisfy { vector in
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    }
}

private func momentumClosureSampleIsFinite(
    _ sample: MetalIndexedBirdSurfaceMomentumClosureSample
) -> Bool {
    [
        sample.aerodynamicForceNewtons,
        sample.negativeFluidMomentumStorageRateNewtons,
        sample.negativeControlSurfaceMomentumFluxNewtons,
        sample.topologyReservoirCorrectionNewtons,
        sample.rawControlVolumeBudgetForceNewtons,
        sample.rawControlVolumeClosureResidualNewtons,
        sample.globalFluidMomentumChangeRateNewtons,
        sample.globalFarFieldMomentumSourceRateNewtons,
        sample.globalSpongeMomentumSourceRateNewtons,
        sample.globalFluidBudgetForceNewtons,
        sample.globalFluidClosureResidualNewtons,
    ].allSatisfy { vector in
        vector.x.isFinite && vector.y.isFinite && vector.z.isFinite
    } && sample.minimumPopulation.isFinite
}

private func vectorMagnitude(_ vector: SIMD3<Double>) -> Double {
    sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}

private func vectorRMS(_ vectors: [SIMD3<Double>]) -> Double {
    guard !vectors.isEmpty else { return .infinity }
    return sqrt(
        vectors.reduce(0.0) {
            $0 + $1.x * $1.x + $1.y * $1.y + $1.z * $1.z
        } / Double(vectors.count)
    )
}

private struct TriangleClosestPoint {
    let position: SIMD3<Float>
    let barycentric: SIMD3<Float>
}

private func triangleClosestPoint(
    point: SIMD3<Float>,
    a: SIMD3<Float>,
    b: SIMD3<Float>,
    c: SIMD3<Float>
) -> TriangleClosestPoint {
    let ab = b - a
    let ac = c - a
    let ap = point - a
    let d1 = dot(ab, ap)
    let d2 = dot(ac, ap)
    if d1 <= 0, d2 <= 0 {
        return TriangleClosestPoint(position: a, barycentric: SIMD3(1, 0, 0))
    }
    let bp = point - b
    let d3 = dot(ab, bp)
    let d4 = dot(ac, bp)
    if d3 >= 0, d4 <= d3 {
        return TriangleClosestPoint(position: b, barycentric: SIMD3(0, 1, 0))
    }
    let vc = d1 * d4 - d3 * d2
    if vc <= 0, d1 >= 0, d3 <= 0 {
        let value = d1 / (d1 - d3)
        return TriangleClosestPoint(
            position: a + value * ab,
            barycentric: SIMD3(1 - value, value, 0)
        )
    }
    let cp = point - c
    let d5 = dot(ab, cp)
    let d6 = dot(ac, cp)
    if d6 >= 0, d5 <= d6 {
        return TriangleClosestPoint(position: c, barycentric: SIMD3(0, 0, 1))
    }
    let vb = d5 * d2 - d1 * d6
    if vb <= 0, d2 >= 0, d6 <= 0 {
        let value = d2 / (d2 - d6)
        return TriangleClosestPoint(
            position: a + value * ac,
            barycentric: SIMD3(1 - value, 0, value)
        )
    }
    let va = d3 * d6 - d5 * d4
    if va <= 0, d4 - d3 >= 0, d5 - d6 >= 0 {
        let value = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return TriangleClosestPoint(
            position: b + value * (c - b),
            barycentric: SIMD3(0, 1 - value, value)
        )
    }
    let inverse = 1 / max(va + vb + vc, 1.0e-20)
    let v = vb * inverse
    let w = vc * inverse
    return TriangleClosestPoint(
        position: a + v * ab + w * ac,
        barycentric: SIMD3(1 - v - w, v, w)
    )
}

private func dot(_ first: SIMD3<Float>, _ second: SIMD3<Float>) -> Float {
    first.x * second.x + first.y * second.y + first.z * second.z
}

private func componentMinimum(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ third: SIMD3<Float>
) -> SIMD3<Float> {
    SIMD3<Float>(
        min(first.x, second.x, third.x),
        min(first.y, second.y, third.y),
        min(first.z, second.z, third.z)
    )
}

private func componentMaximum(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ third: SIMD3<Float>
) -> SIMD3<Float> {
    SIMD3<Float>(
        max(first.x, second.x, third.x),
        max(first.y, second.y, third.y),
        max(first.z, second.z, third.z)
    )
}

private func vectorLength(_ vector: SIMD3<Float>) -> Float {
    sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}
#endif

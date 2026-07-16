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
        maximumCorrectionActivationFraction: Double
    ) throws -> MetalIndexedBirdSurfaceMomentumClosureCase {
        let started = Date()
        let requestedSteps = plan.preRollFluidSteps
        guard requestedSteps > 0,
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

        let initialTime = dataset.frameTimesSeconds[0]
        updateSurfaceTime(initialTime)
        var initialUniforms = makePilotUniforms(
            step: 0,
            hasPreviousGeometry: false,
            collisionOperator: collisionOperator
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
            let sourceTime = initialTime
                + Float(step) * configuration.scaling.timeStepSeconds
            guard sourceTime <= dataset.frameTimesSeconds.last! + 1e-7 else {
                throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                    "collision momentum closure exceeds the surface sequence"
                )
            }
            updateSurfaceTime(sourceTime)
            var uniforms = makePilotUniforms(
                step: step,
                hasPreviousGeometry: true,
                collisionOperator: collisionOperator
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
        stopAtFirstNegativePopulation: Bool = false
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
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator
    ) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: Float(step),
            captureMacroscopicFields: false,
            accumulateLoads: true,
            hasPreviousGeometry: hasPreviousGeometry,
            periodicBoundaries: false,
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

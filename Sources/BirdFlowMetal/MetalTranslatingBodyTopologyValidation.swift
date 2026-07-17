import BirdFlowCore
import Foundation

public enum MetalTranslatingBodyTopologyValidationError:
    Error, CustomStringConvertible
{
    case failed(String)

    public var description: String {
        switch self {
        case .failed(let message):
            return "Metal translating-body topology validation failed: \(message)"
        }
    }
}

public struct MetalTranslatingBodyTopologySample: Codable, Sendable {
    public let step: Int
    public let newlyCoveredCells: Int
    public let newlyUncoveredCells: Int
    public let solidControlSurfaceCrossingLinkCount: Int
    public let rawBudgetForceX: Double
    public let rawBudgetForceY: Double
    public let rawBudgetForceZ: Double
    public let legacyForceX: Double
    public let legacyForceY: Double
    public let legacyForceZ: Double
    public let conservativeForceX: Double
    public let conservativeForceY: Double
    public let conservativeForceZ: Double
    public let legacyResidualMagnitude: Double
    public let conservativeResidualMagnitude: Double
}

public struct MetalTranslatingBodyTopologyValidationReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let topologyKernel: String
    public let passed: Bool
    public let gridResolution: Int
    public let sphereRadiusCells: Double
    public let translationSpeedLattice: Double
    public let steps: Int
    public let displacementCells: Double
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let topologyTransitionSteps: Int
    public let maximumSolidControlSurfaceCrossingLinkCount: Int
    public let rawBudgetMeanForceX: Double
    public let legacyMeanForceX: Double
    public let conservativeMeanForceX: Double
    public let legacyRMSForceResidual: Double
    public let conservativeRMSForceResidual: Double
    public let maximumLegacyForceResidual: Double
    public let maximumConservativeForceResidual: Double
    public let conservativeRelativeRMSResidual: Double
    public let conservativeImprovementFactor: Double
    public let maximumRawBudgetDifferenceBetweenRuns: Double
    public let maximumAllowedConservativeForceResidual: Double
    public let maximumAllowedConservativeRelativeRMSResidual: Double
    public let minimumRequiredImprovementFactor: Double
    public let maximumAllowedRawBudgetDifferenceBetweenRuns: Double
    public let samples: [MetalTranslatingBodyTopologySample]
}

public struct MetalHighReTranslatingBodyCaseResult: Codable, Sendable {
    public let matchedBirdChordCells: Int
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let tauPlusMarginAboveHalf: Double
    public let requestedSteps: Int
    public let finiteLoadSteps: Int
    public let firstNonFiniteLoadStep: Int?
    public let initialPopulationMass: Double
    public let finalPopulationMass: Double?
    public let relativePopulationMassDrift: Double?
    public let minimumPopulation: Double?
    public let maximumPopulation: Double?
    public let maximumAbsolutePopulation: Double?
    public let populationsFinite: Bool
    public let fieldsFinite: Bool
    public let loadsFinite: Bool
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let topologyTransitionSteps: Int
    public let maximumSolidControlSurfaceCrossingLinkCount: Int
    public let conservativeRMSForceResidual: Double?
    public let maximumConservativeForceResidual: Double?
    public let conservativeRelativeRMSResidual: Double?
    public let rawBudgetRMSForceMagnitude: Double?
    public let maximumMeasuredForceMagnitude: Double?
    public let relativeResidualGateApplied: Bool
    public let passed: Bool
}

public struct MetalHighReTranslatingBodyStabilityReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let topologyKernel: String
    public let topologyChanges: Bool
    public let periodicBoundaries: Bool
    public let spongeStrength: Double
    public let domainCells: SIMD3<Int>
    public let sphereRadiusCells: Double
    public let translationSpeedLattice: Double
    public let wallVelocityLattice: Double
    public let wallVelocityMode: String
    public let farFieldVelocityLattice: Double
    public let requestedSteps: Int
    public let displacementCells: Double
    public let runtimeSeconds: Double
    public let maximumAllowedRelativePopulationMassDrift: Double
    public let maximumAllowedAbsolutePopulation: Double
    public let maximumAllowedConservativeForceResidual: Double
    public let maximumAllowedConservativeRelativeRMSResidual: Double
    public let classification: String
    public let scientificVerdict: String
    public let cases: [MetalHighReTranslatingBodyCaseResult]
    public let passed: Bool
}

public struct MetalHighReFixedOccupancyWallDecompositionReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let topologyKernel: String
    public let requestedStepsPerComponent: Int
    public let maximumWallVelocityLattice: Double
    public let runtimeSeconds: Double
    public let tangential: MetalHighReTranslatingBodyStabilityReport
    public let normal: MetalHighReTranslatingBodyStabilityReport
    public let classification: String
    public let scientificVerdict: String
    public let diagnosticCompleted: Bool
}

public struct MetalStationaryWallRelaxationSweepPoint:
    Codable, Sendable
{
    public let requestedTauPlusMarginAboveHalf: Double
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let tauPlusMarginAboveHalf: Double
    public let requestedSteps: Int
    public let finiteLoadSteps: Int
    public let firstNonFiniteLoadStep: Int?
    public let relativePopulationMassDrift: Double?
    public let maximumAbsolutePopulation: Double?
    public let maximumMeasuredForceMagnitude: Double?
    public let populationsFinite: Bool
    public let fieldsFinite: Bool
    public let loadsFinite: Bool
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let topologyTransitionSteps: Int
    public let stabilityPassed: Bool
    public let fullAcceptancePassed: Bool
}

public struct MetalStationaryWallRelaxationSweepReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let topologyKernel: String
    public let domainCells: SIMD3<Int>
    public let sphereRadiusCells: Double
    public let farFieldVelocityLattice: Double
    public let wallVelocityLattice: Double
    public let periodicBoundaries: Bool
    public let spongeStrength: Double
    public let requestedStepsPerPoint: Int
    public let runtimeSeconds: Double
    public let firstTransitionLowerUnstableTauPlusMarginAboveHalf: Double?
    public let firstTransitionUpperStableTauPlusMarginAboveHalf: Double?
    public let firstTransitionBracketWidth: Double?
    public let firstTransitionBracketed: Bool
    public let stabilityMonotonicWithMargin: Bool
    public let unstableTauPlusMarginsAfterFirstStable: [Double]
    public let thresholdBracketed: Bool
    public let classification: String
    public let scientificVerdict: String
    public let points: [MetalStationaryWallRelaxationSweepPoint]
    public let diagnosticCompleted: Bool
}

public struct MetalStationaryWallLongHorizonSurvivalReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let topologyKernel: String
    public let domainCells: SIMD3<Int>
    public let sphereRadiusCells: Double
    public let farFieldVelocityLattice: Double
    public let wallVelocityLattice: Double
    public let periodicBoundaries: Bool
    public let spongeStrength: Double
    public let requestedStepsPerPoint: Int
    public let runtimeSeconds: Double
    public let survivingPointCount: Int
    public let allApparentStablePointsSurvived: Bool
    public let classification: String
    public let scientificVerdict: String
    public let points: [MetalStationaryWallRelaxationSweepPoint]
    public let diagnosticCompleted: Bool
}

public struct MetalStationaryWallPopulationMinimumSample:
    Codable, Sendable
{
    public let step: Int
    public let minimumPopulation: Double?
    public let valueClassification: String
    public let directionIndex: Int
    public let latticeDirection: SIMD3<Int>
    public let cell: SIMD3<Int>
    public let signedDistanceToSphereSurfaceCells: Double
    public let absoluteDistanceToSphereSurfaceCells: Double
    public let cellIsSolid: Bool
    public let cellAdjacentToSphere: Bool
    public let pullSourceCell: SIMD3<Int>
    public let pullSourceInsideDomain: Bool
    public let pullSourceIsSolid: Bool
    public let pullSourceSignedDistanceToSphereSurfaceCells: Double?
    public let populationUpdatePath: String
    public let distanceToNearestDomainBoundaryCells: Int
    public let insideSponge: Bool
    public let spongeFactor: Double
}

public struct MetalStationaryWallPopulationPositivityReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let diagnosticKernel: String
    public let domainCells: SIMD3<Int>
    public let sphereCenterCells: SIMD3<Double>
    public let sphereRadiusCells: Double
    public let farFieldVelocityLattice: Double
    public let wallVelocityLattice: Double
    public let spongeWidthCells: Int
    public let spongeStrength: Double
    public let matchedBirdChordCells: Int
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let tauPlusMarginAboveHalf: Double
    public let requestedSteps: Int
    public let completedSteps: Int
    public let runtimeSeconds: Double
    public let initialMinimum: MetalStationaryWallPopulationMinimumSample
    public let firstNegative: MetalStationaryWallPopulationMinimumSample?
    public let firstNonFinite: MetalStationaryWallPopulationMinimumSample?
    public let firstNonFiniteLoadStep: Int?
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let topologyTransitionSteps: Int
    public let minimumHistory: [MetalStationaryWallPopulationMinimumSample]
    public let classification: String
    public let scientificVerdict: String
    public let diagnosticCompleted: Bool
}

public struct MetalStationaryWallTRTCollisionDirectionTerm:
    Codable, Sendable
{
    public let directionIndex: Int
    public let latticeDirection: SIMD3<Int>
    public let pullSourceCell: SIMD3<Int>
    public let pullSourceInsideDomain: Bool
    public let pullSourceIsSolid: Bool
    public let pulledPopulation: Double
    public let equilibriumPopulation: Double
    public let symmetricNonequilibrium: Double
    public let antisymmetricNonequilibrium: Double
    public let symmetricRelaxationIncrement: Double
    public let antisymmetricRelaxationIncrement: Double
    public let postWithoutSymmetricIncrement: Double
    public let postWithoutAntisymmetricIncrement: Double
    public let predictedPostCollision: Double
    public let actualPostCollision: Double
    public let predictionResidual: Double
}

public struct MetalStationaryWallTRTCollisionDecompositionReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let diagnosticKernel: String
    public let domainCells: SIMD3<Int>
    public let sphereCenterCells: SIMD3<Double>
    public let sphereRadiusCells: Double
    public let farFieldVelocityLattice: Double
    public let wallVelocityLattice: Double
    public let spongeWidthCells: Int
    public let spongeStrength: Double
    public let matchedBirdChordCells: Int
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let tauPlusMarginAboveHalf: Double
    public let captureStep: Int
    public let targetCell: SIMD3<Int>
    public let targetSignedDistanceToSphereSurfaceCells: Double
    public let targetAdjacentToSphere: Bool
    public let density: Double
    public let velocityLattice: SIMD3<Double>
    public let omegaPlus: Double
    public let omegaMinus: Double
    public let spongeFactor: Double
    public let targetIsSolid: Bool
    public let solidPullSourceCount: Int
    public let outsideDomainPullSourceCount: Int
    public let allPulledPopulationsPositive: Bool
    public let minimumPulledPopulation: Double
    public let minimumActualPostCollisionDirection: Int
    public let maximumAbsolutePredictionResidual: Double
    public let failingDirection: MetalStationaryWallTRTCollisionDirectionTerm
    public let failingBoundaryInterpolation:
        MetalStationaryWallBoundaryInterpolationComponent?
    public let maximumAbsoluteBoundaryWallCorrection: Double
    public let directionTerms: [MetalStationaryWallTRTCollisionDirectionTerm]
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let topologyTransitionSteps: Int
    public let dominantDestabilizingRelaxationMode: String
    public let classification: String
    public let scientificVerdict: String
    public let runtimeSeconds: Double
    public let diagnosticCompleted: Bool
}

public struct MetalStationaryWallSymmetricLimiterCaseReport:
    Codable, Sendable
{
    public let limiterEnabled: Bool
    public let requestedSteps: Int
    public let completedSteps: Int
    public let firstNegativePopulationStep: Int?
    public let firstNonFinitePopulationStep: Int?
    public let firstNonFiniteLoadStep: Int?
    public let initialPopulationMass: Double
    public let finalPopulationMass: Double?
    public let relativePopulationMassDrift: Double?
    public let minimumObservedPopulation: Double?
    public let finalMinimumPopulation: Double?
    public let maximumAbsolutePopulation: Double?
    public let populationsFinite: Bool
    public let fieldsFinite: Bool
    public let loadsFinite: Bool
    public let limiterActivationCellSteps: Int
    public let limiterActivationSteps: Int
    public let firstLimiterActivationStep: Int?
    public let firstZeroLimiterScaleStep: Int?
    public let maximumLimiterActivationsInOneStep: Int
    public let minimumLimiterScale: Double?
    public let newlyCoveredCellEvents: Int
    public let newlyUncoveredCellEvents: Int
    public let topologyTransitionSteps: Int
    public let conservativeRMSForceResidual: Double?
    public let maximumConservativeForceResidual: Double?
    public let conservativeRelativeRMSResidual: Double?
    public let rawBudgetRMSForceMagnitude: Double?
    public let maximumMeasuredForceMagnitude: Double?
    public let relativeResidualGateApplied: Bool
    public let stabilityPassed: Bool
    public let forceBudgetPassed: Bool
    public let fullAcceptancePassed: Bool
}

public struct MetalStationaryWallConservationContribution:
    Codable, Sendable
{
    public let mass: Double
    public let momentumLattice: SIMD3<Double>
}

public struct MetalStationaryWallConservationLedgerSample:
    Codable, Sendable
{
    public let step: Int
    public let activatedCellCount: Int
    public let boundaryLinkCount: Int
    public let farFieldLinkCount: Int
    public let spongeCellCount: Int
    public let activatedBoundaryLinkCount: Int
    public let activatedSpongeCellCount: Int
    public let controlVolumeSpongeCellCount: Int
    public let controlVolumeActivatedCellCount: Int
    public let observedGlobal: MetalStationaryWallConservationContribution
    public let boundaryGlobal: MetalStationaryWallConservationContribution
    public let farFieldGlobal: MetalStationaryWallConservationContribution
    public let collisionGlobal: MetalStationaryWallConservationContribution
    public let symmetricLimiterGlobal:
        MetalStationaryWallConservationContribution
    public let spongeGlobal: MetalStationaryWallConservationContribution
    public let globalClosureResidual:
        MetalStationaryWallConservationContribution
    public let controlVolumeCollision:
        MetalStationaryWallConservationContribution
    public let controlVolumeSymmetricLimiter:
        MetalStationaryWallConservationContribution
    public let controlVolumeSponge:
        MetalStationaryWallConservationContribution
    public let activatedCellBoundary:
        MetalStationaryWallConservationContribution
    public let activatedCellSponge:
        MetalStationaryWallConservationContribution
    public let measuredForceNewtons: SIMD3<Double>
    public let rawBudgetForceNewtons: SIMD3<Double>
    public let forceBudgetResidualNewtons: SIMD3<Double>
    public let attributedControlVolumeSourceForceNewtons: SIMD3<Double>
    public let unexplainedForceResidualNewtons: SIMD3<Double>
    public let boundaryLoadClosureResidualNewtons: SIMD3<Double>
}

public struct MetalStationaryWallConservationLedgerReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let definition: String
    public let samples: [MetalStationaryWallConservationLedgerSample]
    public let cumulativeObservedGlobal:
        MetalStationaryWallConservationContribution
    public let cumulativeBoundaryGlobal:
        MetalStationaryWallConservationContribution
    public let cumulativeFarFieldGlobal:
        MetalStationaryWallConservationContribution
    public let cumulativeCollisionGlobal:
        MetalStationaryWallConservationContribution
    public let cumulativeSymmetricLimiterGlobal:
        MetalStationaryWallConservationContribution
    public let cumulativeSpongeGlobal:
        MetalStationaryWallConservationContribution
    public let cumulativeControlVolumeCollision:
        MetalStationaryWallConservationContribution
    public let cumulativeControlVolumeSymmetricLimiter:
        MetalStationaryWallConservationContribution
    public let cumulativeControlVolumeSponge:
        MetalStationaryWallConservationContribution
    public let cumulativeGlobalClosureResidual:
        MetalStationaryWallConservationContribution
    public let finalMinusInitialPopulationMass: Double
    public let observedMassHistoryResidual: Double
    public let maximumPerStepGlobalMassClosureResidual: Double
    public let maximumPerStepGlobalMomentumClosureResidual: Double
    public let maximumPerStepLimiterMassContribution: Double
    public let maximumPerStepLimiterMomentumContribution: Double
    public let relativeCumulativeLimiterMassContribution: Double
    public let maximumForceBudgetResidualNewtons: Double
    public let maximumAttributedControlVolumeSourceForceNewtons: Double
    public let maximumUnexplainedForceResidualNewtons: Double
    public let maximumBoundaryLoadClosureResidualNewtons: Double
    public let RMSForceBudgetResidualNewtons: Double
    public let RMSAttributedControlVolumeSourceForceNewtons: Double
    public let RMSUnexplainedForceResidualNewtons: Double
    public let RMSControlVolumeCollisionForceNewtons: Double
    public let RMSControlVolumeSymmetricLimiterForceNewtons: Double
    public let RMSControlVolumeSpongeForceNewtons: Double
    public let relativeRMSUnexplainedForceResidual: Double
    public let maximumPeakUnexplainedForceResidualFraction: Double
    public let relativeRMSBoundaryLoadClosureResidual: Double
    public let maximumAllowedRelativeRMSUnexplainedForceResidual: Double
    public let maximumAllowedPeakUnexplainedForceResidualFraction: Double
    public let dominantGlobalMassContribution: String
    public let dominantControlVolumeMomentumContribution: String
    public let globalLedgerClosed: Bool
    public let forceResidualLedgerClosed: Bool
}

public struct MetalStationaryWallSymmetricLimiterABReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let limiterMode: String
    public let limiterPopulationFloorDefinition: String
    public let domainCells: SIMD3<Int>
    public let sphereCenterCells: SIMD3<Double>
    public let sphereRadiusCells: Double
    public let farFieldVelocityLattice: Double
    public let wallVelocityLattice: Double
    public let spongeWidthCells: Int
    public let spongeStrength: Double
    public let matchedBirdChordCells: Int
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let tauPlusMarginAboveHalf: Double
    public let requestedStepsPerCase: Int
    public let maximumAllowedRelativePopulationMassDrift: Double
    public let maximumAllowedAbsolutePopulation: Double
    public let maximumAllowedConservativeForceResidual: Double
    public let maximumAllowedConservativeRelativeRMSResidual: Double
    public let maximumPreActivationMeasuredForceDifference: Double
    public let maximumPreActivationBudgetForceDifference: Double
    public let control: MetalStationaryWallSymmetricLimiterCaseReport
    public let treatment: MetalStationaryWallSymmetricLimiterCaseReport
    public let treatmentConservationLedger:
        MetalStationaryWallConservationLedgerReport
    public let sourceAwareControlMinimumCells: SIMD3<Int>
    public let sourceAwareControlMaximumExclusiveCells: SIMD3<Int>
    public let sourceAwareTreatment:
        MetalStationaryWallSymmetricLimiterCaseReport
    public let sourceAwareTreatmentConservationLedger:
        MetalStationaryWallConservationLedgerReport
    public let sourceAwareMaximumSolidControlSurfaceCrossingLinkCount: Int
    public let sourceAwareControlVolumeOutsideSponge: Bool
    public let sourceAwareStabilityPassed: Bool
    public let sourceAwareForceBudgetPassed: Bool
    public let sourceAwareAcceptancePassed: Bool
    public let classification: String
    public let scientificVerdict: String
    public let runtimeSeconds: Double
    public let diagnosticCompleted: Bool
}

public struct MetalStationaryWallGeometricLimiterSample:
    Codable, Sendable
{
    public let step: Int
    public let convectiveTime: Double
    public let minimumPopulation: Double
    public let dragCoefficient: Double
    public let limiterActivationCount: Int
    public let limiterActivationFraction: Double
    public let controlVolumeLimiterActivationFraction: Double
    public let minimumLimiterScale: Double?
    public let relativeLimiterL1Correction: Double
    public let relativeLimiterL2Correction: Double
    public let relativeControlVolumeLimiterL1Correction: Double
    public let relativeControlVolumeLimiterL2Correction: Double
    public let forceBudgetResidualCoefficient: Double
    public let globalMassClosureResidual: Double
    public let controlVolumeSpongeCellCount: Int
    public let solidControlSurfaceCrossingLinkCount: Int
}

public struct MetalStationaryWallGeometricLimiterCaseReport:
    Codable, Sendable
{
    public let diameterCells: Int
    public let domainCells: SIMD3<Int>
    public let sphereCenterCells: SIMD3<Double>
    public let sphereRadiusCells: Double
    public let spongeWidthCells: Int
    public let controlMinimumCells: SIMD3<Int>
    public let controlMaximumExclusiveCells: SIMD3<Int>
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let requestedSteps: Int
    public let completedConvectiveTimes: Double
    public let minimumObservedPopulation: Double?
    public let limiterActivationCellSteps: Int
    public let limiterActivationSteps: Int
    public let limiterActivationFraction: Double
    public let controlVolumeLimiterActivationCellSteps: Int
    public let controlVolumeLimiterActivationFraction: Double
    public let spongeLimiterActivationCellSteps: Int
    public let activatedBoundaryLinkSteps: Int
    public let minimumLimiterScale: Double?
    public let cumulativeLimiterL1Correction: Double
    public let cumulativeLimiterL2Correction: Double
    public let cumulativeCollisionL1Increment: Double
    public let cumulativeCollisionL2Increment: Double
    public let relativeLimiterL1Correction: Double
    public let relativeLimiterL2Correction: Double
    public let cumulativeControlVolumeLimiterL1Correction: Double
    public let cumulativeControlVolumeLimiterL2Correction: Double
    public let cumulativeControlVolumeCollisionL1Increment: Double
    public let cumulativeControlVolumeCollisionL2Increment: Double
    public let relativeControlVolumeLimiterL1Correction: Double
    public let relativeControlVolumeLimiterL2Correction: Double
    public let relativeCumulativeLimiterMassContribution: Double
    public let meanDragCoefficientLastConvectiveTime: Double
    public let meanSideForceToDragRatioLastConvectiveTime: Double
    public let maximumForceBudgetResidualCoefficient: Double
    public let maximumForceBudgetResidualRatio: Double
    public let conservativeRelativeRMSResidual: Double
    public let maximumSolidControlSurfaceCrossingLinkCount: Int
    public let controlVolumeOutsideSponge: Bool
    public let globalLedgerClosed: Bool
    public let relativeRMSBoundaryLoadClosureResidual: Double
    public let sourceAwareStabilityPassed: Bool
    public let forceBudgetPassed: Bool
    public let limiterNonIntrusivePassed: Bool
    public let passed: Bool
    public let samples: [MetalStationaryWallGeometricLimiterSample]
}

public struct MetalStationaryWallGeometricLimiterLadderReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let ledgerCaptureKernel: String
    public let limiterMode: String
    public let classification: String
    public let reynoldsNumber: Double
    public let latticeFarFieldSpeed: Double
    public let latticeMachNumber: Double
    public let domainLengthDiameters: Double
    public let domainCrossflowDiameters: Double
    public let sphereCenterFromInletDiameters: Double
    public let spongeWidthDiameters: Double
    public let requestedConvectiveTimes: Double
    public let maximumAllowedRelativeRMSForceResidual: Double
    public let maximumAllowedPeakForceResidualRatio: Double
    public let maximumAllowedLimiterActivationFraction: Double
    public let maximumAllowedRelativeLimiterCorrection: Double
    public let maximumAllowedFinestTwoDragChange: Double
    public let relativeFinestTwoDragChange: Double
    public let limiterActivationNonIncreasing: Bool
    public let limiterCorrectionNonIncreasing: Bool
    public let observedDragConvergenceOrder: Double?
    public let richardsonExtrapolatedDragCoefficient: Double?
    public let fineGridConvergenceIndex: Double?
    public let convergenceMethod: String
    public let cases: [MetalStationaryWallGeometricLimiterCaseReport]
    public let scientificVerdict: String
    public let runtimeSeconds: Double
    public let passed: Bool
}

public struct MetalStationaryWallRecursiveDurationCaseReport:
    Codable, Sendable
{
    public let numericalCase: MetalStationaryWallGeometricLimiterCaseReport
    public let convectiveWindowMeanDragCoefficients: [Double]
    public let fourthToFifthRelativeDragChange: Double
    public let ninthToTenthRelativeDragChange: Double
    public let fifthToTenthRelativeDragChange: Double
    public let durationStabilityPassed: Bool
}

public struct MetalStationaryWallRecursiveDurationReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let ledgerCaptureKernel: String
    public let collisionMode: String
    public let classification: String
    public let baselineConvectiveTimes: Double
    public let requestedConvectiveTimes: Double
    public let maximumAllowedLateWindowChange: Double
    public let cases: [MetalStationaryWallRecursiveDurationCaseReport]
    public let allIndividualGatesPassed: Bool
    public let durationStabilityPassed: Bool
    public let baselineWindowBiasConfirmed: Bool
    public let scientificVerdict: String
    public let runtimeSeconds: Double
    public let diagnosticCompleted: Bool
    public let passed: Bool
}

public struct MetalStationaryWallRadialLimiterBin: Codable, Sendable {
    public let binIndex: Int
    public let minimumSurfaceDistanceDiameters: Double
    public let maximumSurfaceDistanceDiameters: Double?
    public let minimumSurfaceDistanceCells: Double
    public let maximumSurfaceDistanceCells: Double?
    public let fluidCellCount: Int
    public let activatedCellCount: Int
    public let activationFraction: Double
    public let fractionOfSnapshotActivatedCells: Double
    public let boundaryLinkCount: Int
    public let activatedBoundaryLinkCount: Int
    public let limiterL1Correction: Double
    public let limiterL2Correction: Double
    public let collisionL1Increment: Double
    public let collisionL2Increment: Double
    public let relativeLimiterL1Correction: Double
    public let relativeLimiterL2Correction: Double
    public let fractionOfSnapshotLimiterL1Correction: Double
}

public struct MetalStationaryWallRadialLimiterSnapshot:
    Codable, Sendable
{
    public let step: Int
    public let convectiveTime: Double
    public let minimumPopulation: Double
    public let dragCoefficient: Double
    public let controlVolumeActivatedCellCount: Int
    public let radialActivatedCellCount: Int
    public let nearSurfaceLimiterL1Fraction: Double
    public let farFieldLimiterL1Fraction: Double
    public let nearSurfaceActivationFraction: Double
    public let farFieldActivationFraction: Double
    public let relativeLimiterL1ClosureResidual: Double
    public let relativeLimiterL2SquaredClosureResidual: Double
    public let relativeCollisionL1ClosureResidual: Double
    public let relativeCollisionL2SquaredClosureResidual: Double
    public let bins: [MetalStationaryWallRadialLimiterBin]
}

public struct MetalStationaryWallRadialLimiterReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let ledgerCaptureKernel: String
    public let radialReductionKernel: String
    public let classification: String
    public let reynoldsNumber: Double
    public let latticeFarFieldSpeed: Double
    public let latticeMachNumber: Double
    public let diameterCells: Int
    public let domainCells: SIMD3<Int>
    public let sphereCenterCells: SIMD3<Double>
    public let sphereRadiusCells: Double
    public let spongeWidthCells: Int
    public let controlMinimumCells: SIMD3<Int>
    public let controlMaximumExclusiveCells: SIMD3<Int>
    public let requestedSteps: Int
    public let firstLimiterActivationStep: Int?
    public let captureSteps: [Int]
    public let radialUpperEdgesDiameters: [Double]
    public let nearSurfaceMaximumDistanceDiameters: Double
    public let farFieldMinimumDistanceDiameters: Double
    public let minimumBoundaryLocalizedLimiterL1Fraction: Double
    public let maximumBoundaryLocalizedFarFieldLimiterL1Fraction: Double
    public let maximumAllowedRadialClosureResidual: Double
    public let maximumObservedRadialClosureResidual: Double
    public let finalNearSurfaceLimiterL1Fraction: Double
    public let finalFarFieldLimiterL1Fraction: Double
    public let finalNearSurfaceActivationFraction: Double
    public let finalFarFieldActivationFraction: Double
    public let populationPositivityPassed: Bool
    public let controlVolumeIsolationPassed: Bool
    public let radialClosurePassed: Bool
    public let boundaryLocalized: Bool
    public let snapshots: [MetalStationaryWallRadialLimiterSnapshot]
    public let scientificVerdict: String
    public let runtimeSeconds: Double
    public let passed: Bool
}

public struct MetalStationaryWallBulkCollisionCaseReport:
    Codable, Sendable
{
    public let operatorName: String
    public let collisionModel: String
    public let positivityTreatment: String
    public let requestedSteps: Int
    public let completedSteps: Int
    public let completedConvectiveTimes: Double
    public let firstCorrectionStep: Int?
    public let minimumObservedPopulation: Double?
    public let minimumCorrectionScale: Double?
    public let controlVolumeCorrectionActivationCellSteps: Int
    public let controlVolumeCorrectionActivationFraction: Double
    public let cumulativeControlVolumeCorrectionL1: Double
    public let cumulativeControlVolumeCollisionL1: Double
    public let relativeControlVolumeCorrectionL1: Double
    public let relativeControlVolumeCorrectionL2: Double
    public let finalNearSurfaceCorrectionL1Fraction: Double
    public let finalFarFieldCorrectionL1Fraction: Double
    public let radialCaptureCompleted: Bool
    public let maximumObservedRadialClosureResidual: Double
    public let meanDragCoefficientLastConvectiveTime: Double
    public let conservativeRelativeRMSForceResidual: Double
    public let maximumForceBudgetResidualRatio: Double
    public let relativeCumulativeCorrectionMassContribution: Double
    public let relativeRMSBoundaryLoadClosureResidual: Double
    public let populationPositivityPassed: Bool
    public let controlVolumeIsolationPassed: Bool
    public let globalLedgerClosed: Bool
    public let forceBudgetPassed: Bool
    public let correctionNonIntrusivePassed: Bool
    public let eligibleForRefinement: Bool
    public let runtimeSeconds: Double
}

public struct MetalStationaryWallBulkCollisionABReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let ledgerCaptureKernel: String
    public let radialReductionKernel: String
    public let classification: String
    public let reynoldsNumber: Double
    public let latticeFarFieldSpeed: Double
    public let latticeMachNumber: Double
    public let diameterCells: Int
    public let domainCells: SIMD3<Int>
    public let sphereCenterCells: SIMD3<Double>
    public let sphereRadiusCells: Double
    public let spongeWidthCells: Int
    public let controlMinimumCells: SIMD3<Int>
    public let controlMaximumExclusiveCells: SIMD3<Int>
    public let requestedSteps: Int
    public let requestedConvectiveTimes: Double
    public let maximumAllowedRelativeRMSForceResidual: Double
    public let maximumAllowedPeakForceResidualRatio: Double
    public let maximumAllowedCorrectionActivationFraction: Double
    public let maximumAllowedRelativeCorrection: Double
    public let maximumAllowedRadialClosureResidual: Double
    public let control: MetalStationaryWallBulkCollisionCaseReport
    public let candidate: MetalStationaryWallBulkCollisionCaseReport
    public let candidateToControlActivationRatio: Double
    public let candidateToControlCorrectionL1Ratio: Double
    public let candidateEligibleForRefinement: Bool
    public let gridConvergenceStillRequired: Bool
    public let scientificVerdict: String
    public let diagnosticCompleted: Bool
    public let runtimeSeconds: Double
    public let passed: Bool
}

public struct MetalStationaryWallBoundaryInterpolationComponent:
    Codable, Sendable
{
    public let directionIndex: Int
    public let branch: String
    public let linkFraction: Double
    public let reflectedPopulation: Double
    public let auxiliaryPopulation: Double
    public let auxiliaryCell: SIMD3<Int>?
    public let auxiliaryRole: String
    public let wallCorrection: Double
    public let reflectedContribution: Double
    public let auxiliaryContribution: Double
    public let wallCorrectionContribution: Double
    public let reconstructedPopulation: Double
    public let contributionClosureResidual: Double
    public let dominantNegativeContribution: String
}

private struct MetalPopulationMinimumRecord {
    let rawValue: Float
    let linearIndex: UInt32
    let nonFinite: Bool
}

public enum MetalTranslatingBodyTopologyValidator {
    public static let gridResolution = 24
    public static let sphereRadiusCells = 3.25
    public static let translationSpeedLattice = 0.05
    public static let steps = 40
    public static let maximumConservativeForceResidual = 5.0e-4
    public static let maximumConservativeRelativeRMSResidual = 5.0e-3
    public static let minimumImprovementFactor = 5.0
    public static let maximumRawBudgetDifference = 1.0e-7

    private enum HighReSphereWallMode: Float {
        case uniform = 0
        case tangential = 1
        case normal = 2

        var name: String {
            switch self {
            case .uniform: return "uniform"
            case .tangential: return "tangential-only"
            case .normal: return "normal-only"
            }
        }
    }

    private enum BulkCollisionOperator: CaseIterable {
        case symmetricLimitedTRT
        case positivityPreservingRegularizedBGK
        case positivityPreservingRecursiveRegularizedBGK

        var name: String {
            switch self {
            case .symmetricLimitedTRT:
                return "symmetric-limited-trt"
            case .positivityPreservingRegularizedBGK:
                return "positivity-preserving-regularized-bgk"
            case .positivityPreservingRecursiveRegularizedBGK:
                return "positivity-preserving-recursive-regularized-bgk"
            }
        }

        var collisionModel: String {
            switch self {
            case .symmetricLimitedTRT:
                return "two-relaxation-time collision with a common scale on the symmetric increment"
            case .positivityPreservingRegularizedBGK:
                return "second-order Hermite projection of pre-collision nonequilibrium followed by omega-plus BGK relaxation"
            case .positivityPreservingRecursiveRegularizedBGK:
                return "second-order Hermite projection plus the six D3Q19-supported recursively reconstructed third-order nonequilibrium moments followed by omega-plus BGK relaxation"
            }
        }

        var positivityTreatment: String {
            switch self {
            case .symmetricLimitedTRT:
                return "cell-local common scale on the complete symmetric TRT increment"
            case .positivityPreservingRegularizedBGK:
                return "cell-local convex line search from equilibrium to the unbounded regularized post-collision state"
            case .positivityPreservingRecursiveRegularizedBGK:
                return "cell-local convex line search from equilibrium to the unbounded recursive-regularized post-collision state"
            }
        }
    }

    public static func runHighReStability(
        steps: Int = 500
    ) throws -> MetalHighReTranslatingBodyStabilityReport {
        try runHighReStability(
            steps: steps,
            topologyChanges: true,
            wallMode: .uniform
        )
    }

    public static func runHighReFixedOccupancyStability(
        steps: Int = 500
    ) throws -> MetalHighReTranslatingBodyStabilityReport {
        try runHighReStability(
            steps: steps,
            topologyChanges: false,
            wallMode: .uniform
        )
    }

    public static func runHighReStationaryWallSphereStability(
        steps: Int = 500
    ) throws -> MetalHighReTranslatingBodyStabilityReport {
        try runHighReStability(
            steps: steps,
            topologyChanges: false,
            wallMode: .uniform,
            wallSpeed: 0,
            farFieldSpeed: 0.08
        )
    }

    public static func runStationaryWallC16PopulationPositivity(
        steps: Int = 500
    ) throws -> MetalStationaryWallPopulationPositivityReport {
        guard steps == 500 else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "stationary-wall c16 population positivity uses a locked 500-step ceiling"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let domain = try GridSize(x: 56, y: 24, z: 24)
        let center = SIMD3<Float>(8, 12, 12)
        let radius = Float(sphereRadiusCells)
        let viscosity: Float = 8.782_491_2e-5
        let spongeWidth = 4
        let spongeStrength: Float = 0.04
        let configuration = MetalTranslatingBodyCaseConfiguration(
            grid: domain,
            sphereRadiusCells: radius,
            referenceSpeedLattice: 0.08,
            geometryTranslationSpeedLattice: 0,
            wallVelocityLattice: 0,
            wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
            initialFluidVelocityLattice: 0.08,
            periodicBoundaries: false,
            spongeStrength: spongeStrength,
            latticeKinematicViscosity: viscosity,
            initialCenter: center,
            controlMinimum: SIMD3<UInt32>(2, 2, 2),
            controlMaximumExclusive: SIMD3<UInt32>(54, 22, 22)
        )
        let simulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: configuration
        )
        let centerDouble = SIMD3<Double>(
            Double(center.x),
            Double(center.y),
            Double(center.z)
        )
        let initialMinimum = populationMinimumSample(
            try simulation.capturePopulationMinimum(),
            step: 0,
            domain: domain,
            sphereCenter: centerDouble,
            sphereRadius: Double(radius),
            spongeWidth: spongeWidth,
            spongeStrength: Double(spongeStrength)
        )
        let history = try simulation.run(
            steps: steps,
            capturePopulationMinimum: true,
            stopOneStepAfterFirstNonFinitePopulation: true
        )
        let samples = [initialMinimum] + history.enumerated().compactMap {
            index, state in
            state.populationMinimum.map {
                populationMinimumSample(
                    $0,
                    step: index + 1,
                    domain: domain,
                    sphereCenter: centerDouble,
                    sphereRadius: Double(radius),
                    spongeWidth: spongeWidth,
                    spongeStrength: Double(spongeStrength)
                )
            }
        }
        let firstNegative = samples.first {
            ($0.minimumPopulation ?? 0) < 0
        }
        let firstNonFinite = samples.first {
            $0.valueClassification != "finite"
        }
        let firstNonFiniteLoadStep = history.firstIndex {
            !vectorIsFinite($0.measuredForce)
                || !vectorIsFinite($0.rawBudgetForce)
        }.map { $0 + 1 }
        let coveredEvents = history.reduce(0) {
            $0 + $1.newlyCoveredCells
        }
        let uncoveredEvents = history.reduce(0) {
            $0 + $1.newlyUncoveredCells
        }
        let transitionSteps = history.reduce(0) {
            $0 + (($1.newlyCoveredCells > 0
                || $1.newlyUncoveredCells > 0) ? 1 : 0)
        }
        let firstLocation = firstNegative.map(populationLocation)
            ?? "not-observed"
        let nonFiniteLocation = firstNonFinite.map(populationLocation)
            ?? "not-observed"
        let diagnosticCompleted = initialMinimum.valueClassification == "finite"
            && (initialMinimum.minimumPopulation ?? -.infinity) > 0
            && firstNegative != nil
            && firstNonFinite != nil
            && samples.count == history.count + 1
            && coveredEvents == 0
            && uncoveredEvents == 0
            && transitionSteps == 0
        let classification = diagnosticCompleted
            ? "stationary-wall-c16-first-positivity-loss-\(firstLocation)"
            : "stationary-wall-c16-population-positivity-incomplete"
        let verdict: String
        if let firstNegative, let firstNonFinite {
            verdict = "The first negative c16 stationary-sphere population occurs at step \(firstNegative.step), q=\(firstNegative.directionIndex), cell=\(firstNegative.cell), signed sphere distance \(firstNegative.signedDistanceToSphereSurfaceCells) cells, classified as \(firstLocation), through \(firstNegative.populationUpdatePath). The first non-finite population occurs at step \(firstNonFinite.step), q=\(firstNonFinite.directionIndex), cell=\(firstNonFinite.cell), classified as \(nonFiniteLocation). This localizes the positivity defect before changing the bird solver."
        } else {
            verdict = "The locked c16 run did not capture both a first negative and first non-finite population within the requested ceiling."
        }
        return MetalStationaryWallPopulationPositivityReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            diagnosticKernel: "reducePopulationMinimum",
            domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
            sphereCenterCells: centerDouble,
            sphereRadiusCells: Double(radius),
            farFieldVelocityLattice: 0.08,
            wallVelocityLattice: 0,
            spongeWidthCells: spongeWidth,
            spongeStrength: Double(spongeStrength),
            matchedBirdChordCells: 16,
            latticeKinematicViscosity:
                Double(simulation.latticeKinematicViscosity),
            tauPlus: Double(simulation.tauPlus),
            tauPlusMarginAboveHalf: Double(simulation.tauPlus - 0.5),
            requestedSteps: steps,
            completedSteps: history.count,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            initialMinimum: initialMinimum,
            firstNegative: firstNegative,
            firstNonFinite: firstNonFinite,
            firstNonFiniteLoadStep: firstNonFiniteLoadStep,
            newlyCoveredCellEvents: coveredEvents,
            newlyUncoveredCellEvents: uncoveredEvents,
            topologyTransitionSteps: transitionSteps,
            minimumHistory: samples,
            classification: classification,
            scientificVerdict: verdict,
            diagnosticCompleted: diagnosticCompleted
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func runStationaryWallC16TRTCollisionDecomposition(
        captureStep: Int = 27
    ) throws -> MetalStationaryWallTRTCollisionDecompositionReport {
        guard captureStep == 27 else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "stationary-wall c16 TRT decomposition uses locked step 27"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let domain = try GridSize(x: 56, y: 24, z: 24)
        let center = SIMD3<Float>(8, 12, 12)
        let centerDouble = SIMD3<Double>(8, 12, 12)
        let radius = Float(sphereRadiusCells)
        let viscosity: Float = 8.782_491_2e-5
        let spongeWidth = 4
        let spongeStrength: Float = 0.04
        let target = SIMD3<UInt32>(5, 9, 12)
        let targetInt = SIMD3<Int>(5, 9, 12)
        let configuration = MetalTranslatingBodyCaseConfiguration(
            grid: domain,
            sphereRadiusCells: radius,
            referenceSpeedLattice: 0.08,
            geometryTranslationSpeedLattice: 0,
            wallVelocityLattice: 0,
            wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
            initialFluidVelocityLattice: 0.08,
            periodicBoundaries: false,
            spongeStrength: spongeStrength,
            latticeKinematicViscosity: viscosity,
            initialCenter: center,
            controlMinimum: SIMD3<UInt32>(2, 2, 2),
            controlMaximumExclusive: SIMD3<UInt32>(54, 22, 22)
        )
        let simulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: configuration
        )
        let (history, capture) = try simulation.runTRTCollisionDecomposition(
            steps: captureStep,
            targetCell: target
        )
        let terms = collisionTerms(capture, targetCell: targetInt)
        guard let failing = terms.min(by: {
            $0.actualPostCollision < $1.actualPostCollision
        }), let failingRaw = capture.terms.first(where: {
            Int($0.metadata.x) == failing.directionIndex
        }) else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "TRT decomposition returned no direction terms"
            )
        }
        let failingBoundary = failingRaw.boundaryMetadata.x != 0
            ? boundaryInterpolationComponent(failingRaw, domain: domain)
            : nil
        let maximumBoundaryWallCorrection = capture.terms
            .filter { $0.boundaryMetadata.x != 0 }
            .map { abs(Double($0.boundaryValues0.w)) }
            .max() ?? 0
        let allPulledPositive = terms.allSatisfy {
            $0.pulledPopulation.isFinite && $0.pulledPopulation > 0
        }
        let minimumPulled = terms.map(\.pulledPopulation).min()
            ?? -.infinity
        let coveredEvents = history.reduce(0) {
            $0 + $1.newlyCoveredCells
        }
        let uncoveredEvents = history.reduce(0) {
            $0 + $1.newlyUncoveredCells
        }
        let transitionSteps = history.reduce(0) {
            $0 + (($1.newlyCoveredCells > 0
                || $1.newlyUncoveredCells > 0) ? 1 : 0)
        }
        let targetDistance = signedSphereDistance(
            targetInt,
            center: centerDouble,
            radius: Double(radius)
        )
        let targetAdjacent = D3Q19.directions.dropFirst().contains { raw in
            let neighbor = SIMD3<Int>(
                targetInt.x - Int(raw.x),
                targetInt.y - Int(raw.y),
                targetInt.z - Int(raw.z)
            )
            return signedSphereDistance(
                neighbor,
                center: centerDouble,
                radius: Double(radius)
            ) <= 0
        }
        let symmetricNecessary =
            failing.postWithoutSymmetricIncrement >= 0
        let antisymmetricNecessary =
            failing.postWithoutAntisymmetricIncrement >= 0
        let dominantMode = failing.symmetricRelaxationIncrement
            < failing.antisymmetricRelaxationIncrement
            ? "symmetric"
            : "antisymmetric"
        let modeClassification: String
        switch (symmetricNecessary, antisymmetricNecessary) {
        case (true, false):
            modeClassification = "symmetric-relaxation-overshoot"
        case (false, true):
            modeClassification = "antisymmetric-relaxation-overshoot"
        case (true, true):
            modeClassification = "coupled-relaxation-overshoot"
        case (false, false):
            modeClassification = "both-modes-independently-destabilizing"
        }
        let maximumResidual = Double(capture.relaxation.w)
        let solidSourceCount = Int(capture.metadata.y)
        let outsideSourceCount = Int(capture.metadata.z)
        let targetIsSolid = capture.metadata.w != 0
        let diagnosticCompleted = history.count == captureStep
            && terms.count == D3Q19.count
            && capture.metadata.x
                == UInt32(
                    targetInt.x
                        + domain.x * (targetInt.y + domain.y * targetInt.z)
                )
            && allPulledPositive
            && outsideSourceCount == 0
            && !targetIsSolid
            && abs(Double(capture.relaxation.z)) <= 1.0e-12
            && maximumResidual <= 1.0e-7
            && maximumBoundaryWallCorrection <= 1.0e-12
            && failing.directionIndex == 10
            && failing.actualPostCollision < 0
            && coveredEvents == 0
            && uncoveredEvents == 0
            && transitionSteps == 0
        let classification = diagnosticCompleted
            ? "stationary-wall-c16-trt-\(modeClassification)"
            : "stationary-wall-c16-trt-decomposition-incomplete"
        let verdict = "At step \(captureStep), every reconstructed population entering cell \(targetInt) is positive. For q=\(failing.directionIndex), the pulled population \(failing.pulledPopulation), symmetric increment \(failing.symmetricRelaxationIncrement), and antisymmetric increment \(failing.antisymmetricRelaxationIncrement) produce \(failing.actualPostCollision). Removing the symmetric increment gives \(failing.postWithoutSymmetricIncrement); removing the antisymmetric increment gives \(failing.postWithoutAntisymmetricIncrement). The dominant destabilizing mode is \(dominantMode), classified as \(modeClassification)."
        return MetalStationaryWallTRTCollisionDecompositionReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            diagnosticKernel: "captureTRTCollisionDecomposition",
            domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
            sphereCenterCells: centerDouble,
            sphereRadiusCells: Double(radius),
            farFieldVelocityLattice: 0.08,
            wallVelocityLattice: 0,
            spongeWidthCells: spongeWidth,
            spongeStrength: Double(spongeStrength),
            matchedBirdChordCells: 16,
            latticeKinematicViscosity:
                Double(simulation.latticeKinematicViscosity),
            tauPlus: Double(simulation.tauPlus),
            tauPlusMarginAboveHalf: Double(simulation.tauPlus - 0.5),
            captureStep: captureStep,
            targetCell: targetInt,
            targetSignedDistanceToSphereSurfaceCells: targetDistance,
            targetAdjacentToSphere: targetAdjacent,
            density: Double(capture.macroscopic.x),
            velocityLattice: SIMD3<Double>(
                Double(capture.macroscopic.y),
                Double(capture.macroscopic.z),
                Double(capture.macroscopic.w)
            ),
            omegaPlus: Double(capture.relaxation.x),
            omegaMinus: Double(capture.relaxation.y),
            spongeFactor: Double(capture.relaxation.z),
            targetIsSolid: targetIsSolid,
            solidPullSourceCount: solidSourceCount,
            outsideDomainPullSourceCount: outsideSourceCount,
            allPulledPopulationsPositive: allPulledPositive,
            minimumPulledPopulation: minimumPulled,
            minimumActualPostCollisionDirection: failing.directionIndex,
            maximumAbsolutePredictionResidual: maximumResidual,
            failingDirection: failing,
            failingBoundaryInterpolation: failingBoundary,
            maximumAbsoluteBoundaryWallCorrection:
                maximumBoundaryWallCorrection,
            directionTerms: terms,
            newlyCoveredCellEvents: coveredEvents,
            newlyUncoveredCellEvents: uncoveredEvents,
            topologyTransitionSteps: transitionSteps,
            dominantDestabilizingRelaxationMode: dominantMode,
            classification: classification,
            scientificVerdict: verdict,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            diagnosticCompleted: diagnosticCompleted
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func runStationaryWallC16SymmetricLimiterAB(
        steps: Int = 500
    ) throws -> MetalStationaryWallSymmetricLimiterABReport {
        guard steps == 500 else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "stationary-wall c16 symmetric-limiter A/B uses a locked 500-step contract"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let domain = try GridSize(x: 56, y: 24, z: 24)
        let center = SIMD3<Float>(8, 12, 12)
        let radius = Float(sphereRadiusCells)
        let viscosity: Float = 8.782_491_2e-5
        let spongeStrength: Float = 0.04
        let maximumMassDrift = 1.0e-3
        let maximumAbsolutePopulation = 10.0
        let maximumForceResidual = 5.0e-4
        let maximumRelativeResidual = 5.0e-3
        let configuration = MetalTranslatingBodyCaseConfiguration(
            grid: domain,
            sphereRadiusCells: radius,
            referenceSpeedLattice: 0.08,
            geometryTranslationSpeedLattice: 0,
            wallVelocityLattice: 0,
            wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
            initialFluidVelocityLattice: 0.08,
            periodicBoundaries: false,
            spongeStrength: spongeStrength,
            latticeKinematicViscosity: viscosity,
            initialCenter: center,
            controlMinimum: SIMD3<UInt32>(2, 2, 2),
            controlMaximumExclusive: SIMD3<UInt32>(54, 22, 22)
        )
        let controlSimulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: configuration
        )
        let controlInitial = try controlSimulation.copyPopulations()
        let controlHistory = try controlSimulation.run(
            steps: steps,
            capturePopulationMinimum: true,
            stopOneStepAfterFirstNonFinitePopulation: true
        )
        let controlFinal = try controlSimulation.copyPopulations()
        let control = symmetricLimiterCaseReport(
            limiterEnabled: false,
            requestedSteps: steps,
            initialPopulations: controlInitial,
            finalPopulations: controlFinal,
            history: controlHistory,
            cellCount: domain.cellCount,
            maximumMassDrift: maximumMassDrift,
            maximumAbsolutePopulation: maximumAbsolutePopulation,
            maximumForceResidual: maximumForceResidual,
            maximumRelativeResidual: maximumRelativeResidual
        )

        let treatmentSimulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: configuration,
            symmetricPositivityLimiterEnabled: true,
            conservationLedgerEnabled: true
        )
        let treatmentInitial = try treatmentSimulation.copyPopulations()
        let treatmentHistory = try treatmentSimulation.run(
            steps: steps,
            capturePopulationMinimum: true,
            stopOneStepAfterFirstNonFinitePopulation: true,
            captureConservationLedger: true
        )
        let treatmentFinal = try treatmentSimulation.copyPopulations()
        let treatment = symmetricLimiterCaseReport(
            limiterEnabled: true,
            requestedSteps: steps,
            initialPopulations: treatmentInitial,
            finalPopulations: treatmentFinal,
            history: treatmentHistory,
            cellCount: domain.cellCount,
            maximumMassDrift: maximumMassDrift,
            maximumAbsolutePopulation: maximumAbsolutePopulation,
            maximumForceResidual: maximumForceResidual,
            maximumRelativeResidual: maximumRelativeResidual
        )
        let conservationLedger = conservationLedgerReport(
            history: treatmentHistory,
            initialPopulationMass: treatment.initialPopulationMass,
            finalPopulationMass: treatment.finalPopulationMass,
            forceToPhysical: Double(treatmentSimulation.forceToPhysical)
        )

        let sourceAwareControlMinimum = SIMD3<UInt32>(4, 4, 4)
        let sourceAwareControlMaximum = SIMD3<UInt32>(52, 20, 20)
        let sourceAwareConfiguration = MetalTranslatingBodyCaseConfiguration(
            grid: domain,
            sphereRadiusCells: radius,
            referenceSpeedLattice: 0.08,
            geometryTranslationSpeedLattice: 0,
            wallVelocityLattice: 0,
            wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
            initialFluidVelocityLattice: 0.08,
            periodicBoundaries: false,
            spongeStrength: spongeStrength,
            latticeKinematicViscosity: viscosity,
            initialCenter: center,
            controlMinimum: sourceAwareControlMinimum,
            controlMaximumExclusive: sourceAwareControlMaximum
        )
        let sourceAwareSimulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: sourceAwareConfiguration,
            symmetricPositivityLimiterEnabled: true,
            conservationLedgerEnabled: true
        )
        let sourceAwareInitial = try sourceAwareSimulation.copyPopulations()
        let sourceAwareHistory = try sourceAwareSimulation.run(
            steps: steps,
            capturePopulationMinimum: true,
            stopOneStepAfterFirstNonFinitePopulation: true,
            captureConservationLedger: true
        )
        let sourceAwareFinal = try sourceAwareSimulation.copyPopulations()
        let sourceAwareTreatment = symmetricLimiterCaseReport(
            limiterEnabled: true,
            requestedSteps: steps,
            initialPopulations: sourceAwareInitial,
            finalPopulations: sourceAwareFinal,
            history: sourceAwareHistory,
            cellCount: domain.cellCount,
            maximumMassDrift: maximumMassDrift,
            maximumAbsolutePopulation: maximumAbsolutePopulation,
            maximumForceResidual: maximumForceResidual,
            maximumRelativeResidual: maximumRelativeResidual
        )
        let sourceAwareLedger = conservationLedgerReport(
            history: sourceAwareHistory,
            initialPopulationMass: sourceAwareTreatment.initialPopulationMass,
            finalPopulationMass: sourceAwareTreatment.finalPopulationMass,
            forceToPhysical: Double(sourceAwareSimulation.forceToPhysical)
        )
        let sourceAwareMaximumCrossingLinks = sourceAwareHistory.map(
            \.solidControlSurfaceCrossingLinkCount
        ).max() ?? 0
        let sourceAwareControlVolumeOutsideSponge = sourceAwareLedger.samples
            .allSatisfy { $0.controlVolumeSpongeCellCount == 0 }
        let sourceAwareStabilityPassed =
            sourceAwareTreatment.completedSteps == steps
            && sourceAwareTreatment.firstNegativePopulationStep == nil
            && sourceAwareTreatment.firstNonFinitePopulationStep == nil
            && sourceAwareTreatment.firstNonFiniteLoadStep == nil
            && sourceAwareTreatment.populationsFinite
            && sourceAwareTreatment.fieldsFinite
            && sourceAwareTreatment.loadsFinite
            && (sourceAwareTreatment.maximumAbsolutePopulation ?? .infinity)
                <= maximumAbsolutePopulation
            && sourceAwareTreatment.newlyCoveredCellEvents == 0
            && sourceAwareTreatment.newlyUncoveredCellEvents == 0
            && sourceAwareTreatment.topologyTransitionSteps == 0
            && sourceAwareLedger.globalLedgerClosed
            && sourceAwareLedger.relativeCumulativeLimiterMassContribution
                <= 1.0e-6
        let sourceAwareForceBudgetPassed =
            sourceAwareMaximumCrossingLinks == 0
            && sourceAwareControlVolumeOutsideSponge
            && sourceAwareTreatment.forceBudgetPassed
            && sourceAwareLedger.relativeRMSBoundaryLoadClosureResidual
                <= 5.0e-5
        let sourceAwareAcceptancePassed = sourceAwareStabilityPassed
            && sourceAwareForceBudgetPassed

        let preActivationCount = max(
            0,
            (treatment.firstLimiterActivationStep ?? 1) - 1
        )
        let comparisonCount = min(
            preActivationCount,
            min(controlHistory.count, treatmentHistory.count)
        )
        var maximumPreActivationMeasuredDifference = 0.0
        var maximumPreActivationBudgetDifference = 0.0
        if comparisonCount > 0 {
            for index in 0..<comparisonCount {
                maximumPreActivationMeasuredDifference = max(
                    maximumPreActivationMeasuredDifference,
                    magnitude(
                        doubleVector(
                            controlHistory[index].measuredForce
                                - treatmentHistory[index].measuredForce
                        )
                    )
                )
                maximumPreActivationBudgetDifference = max(
                    maximumPreActivationBudgetDifference,
                    magnitude(
                        doubleVector(
                            controlHistory[index].rawBudgetForce
                                - treatmentHistory[index].rawBudgetForce
                        )
                    )
                )
            }
        }
        let diagnosticCompleted = control.firstNegativePopulationStep == 27
            && control.firstNonFinitePopulationStep == 105
            && control.firstNonFiniteLoadStep == 105
            && control.limiterActivationCellSteps == 0
            && treatment.limiterActivationCellSteps > 0
            && treatment.firstLimiterActivationStep == 27
            && maximumPreActivationMeasuredDifference <= 1.0e-12
            && maximumPreActivationBudgetDifference <= 1.0e-12
            && control.newlyCoveredCellEvents == 0
            && control.newlyUncoveredCellEvents == 0
            && control.topologyTransitionSteps == 0
            && treatment.newlyCoveredCellEvents == 0
            && treatment.newlyUncoveredCellEvents == 0
            && treatment.topologyTransitionSteps == 0
            && conservationLedger.samples.count == steps
            && conservationLedger.globalLedgerClosed
            && conservationLedger.forceResidualLedgerClosed
            && sourceAwareLedger.samples.count == steps
            && sourceAwareControlVolumeOutsideSponge
            && (treatment.completedSteps == steps
                || treatment.firstNonFinitePopulationStep != nil)
        let classification: String
        let verdict: String
        let treatmentPositivityCleared = treatment.completedSteps == steps
            && treatment.firstNegativePopulationStep == nil
            && treatment.firstNonFinitePopulationStep == nil
            && treatment.firstNonFiniteLoadStep == nil
            && treatment.populationsFinite
            && treatment.fieldsFinite
            && treatment.loadsFinite
        let conservationSourcesAttributed =
            conservationLedger.globalLedgerClosed
            && conservationLedger.forceResidualLedgerClosed
            && conservationLedger.relativeCumulativeLimiterMassContribution
                <= 1.0e-6
            && conservationLedger.dominantGlobalMassContribution
                == "open-far-field"
            && conservationLedger
                .dominantControlVolumeMomentumContribution == "sponge"
        if sourceAwareAcceptancePassed {
            classification = "stationary-wall-c16-symmetric-limiter-source-aware-accepted"
            verdict = "The conservative symmetric-mode limiter keeps the locked c16 stationary-sphere case finite and positive for 500 steps. The global source ledger replaces the invalid closed-domain mass-drift gate, and a control volume wholly outside the four-cell sponge closes the source-aware force budget with no solid link crossing its surface. The c16 treatment is accepted for the promoted c8/c12/c16 refinement ladder before bird replay."
        } else if treatment.fullAcceptancePassed {
            classification = "stationary-wall-c16-symmetric-limiter-clears-stability-and-budget"
            verdict = "The conservative symmetric-mode limiter keeps the locked c16 stationary-sphere case finite and positive for 500 steps while retaining the mass and momentum-budget gates. It may proceed to the c8/c12/c16 canonical ladder before any bird replay."
        } else if treatmentPositivityCleared && conservationSourcesAttributed {
            classification = "stationary-wall-c16-limiter-clears-positivity-open-flow-sources-attributed"
            verdict = "The symmetric-mode limiter keeps the corrected stationary-wall c16 case finite and positive for 500 steps. Its cumulative mass contribution is negligible, the global mass ledger closes to open-far-field and sponge terms, the boundary load closes independently, and sponge momentum explains the control-volume force residual. The existing raw mass and budget flags count expected open-flow sources as error; keep the limiter diagnostic-only until source-aware gates are added and rerun."
        } else if treatmentPositivityCleared {
            classification = "stationary-wall-c16-symmetric-limiter-clears-positivity-conservation-open"
            verdict = "The symmetric-mode limiter keeps the corrected stationary-wall c16 case finite and positive for 500 steps, but the source ledger does not yet close the mass and force-budget residuals. Keep it diagnostic-only."
        } else {
            classification = "stationary-wall-c16-symmetric-limiter-insufficient"
            verdict = "The symmetric-only positivity limiter does not keep the locked c16 stationary-sphere case finite and positive for 500 steps. Do not promote it to production bird physics."
        }
        return MetalStationaryWallSymmetricLimiterABReport(
            schemaVersion: 3,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            limiterMode:
                "cell-local common scale on complete symmetric TRT increment",
            limiterPopulationFloorDefinition:
                "max(1e-12, 1e-6 * max(feq_q, 0))",
            domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
            sphereCenterCells: SIMD3<Double>(8, 12, 12),
            sphereRadiusCells: Double(radius),
            farFieldVelocityLattice: 0.08,
            wallVelocityLattice: 0,
            spongeWidthCells: 4,
            spongeStrength: Double(spongeStrength),
            matchedBirdChordCells: 16,
            latticeKinematicViscosity:
                Double(treatmentSimulation.latticeKinematicViscosity),
            tauPlus: Double(treatmentSimulation.tauPlus),
            tauPlusMarginAboveHalf:
                Double(treatmentSimulation.tauPlus - 0.5),
            requestedStepsPerCase: steps,
            maximumAllowedRelativePopulationMassDrift: maximumMassDrift,
            maximumAllowedAbsolutePopulation: maximumAbsolutePopulation,
            maximumAllowedConservativeForceResidual: maximumForceResidual,
            maximumAllowedConservativeRelativeRMSResidual:
                maximumRelativeResidual,
            maximumPreActivationMeasuredForceDifference:
                maximumPreActivationMeasuredDifference,
            maximumPreActivationBudgetForceDifference:
                maximumPreActivationBudgetDifference,
            control: control,
            treatment: treatment,
            treatmentConservationLedger: conservationLedger,
            sourceAwareControlMinimumCells: SIMD3<Int>(4, 4, 4),
            sourceAwareControlMaximumExclusiveCells: SIMD3<Int>(52, 20, 20),
            sourceAwareTreatment: sourceAwareTreatment,
            sourceAwareTreatmentConservationLedger: sourceAwareLedger,
            sourceAwareMaximumSolidControlSurfaceCrossingLinkCount:
                sourceAwareMaximumCrossingLinks,
            sourceAwareControlVolumeOutsideSponge:
                sourceAwareControlVolumeOutsideSponge,
            sourceAwareStabilityPassed: sourceAwareStabilityPassed,
            sourceAwareForceBudgetPassed: sourceAwareForceBudgetPassed,
            sourceAwareAcceptancePassed: sourceAwareAcceptancePassed,
            classification: classification,
            scientificVerdict: verdict,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            diagnosticCompleted: diagnosticCompleted
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func runStationaryWallGeometricLimiterLadder()
        throws -> MetalStationaryWallGeometricLimiterLadderReport
    {
        try runStationaryWallGeometricCollisionLadder(
            collisionOperator: .symmetricLimitedTRT,
            limiterMode:
                "cell-local common scale on complete symmetric TRT increment",
            acceptedClassification:
                "stationary-wall-geometric-limiter-ladder-accepted",
            rejectedClassification:
                "stationary-wall-geometric-limiter-ladder-not-accepted",
            acceptedVerdict:
                "The source-aware symmetric limiter remains positive, conservative, non-intrusive, and grid-convergent across geometrically similar D=8/12/16 stationary spheres. It may proceed to the published five-cycle flapping-wing ladder.",
            rejectedVerdict:
                "At least one predeclared source-aware stability, force-budget, limiter-intervention, or grid-convergence gate failed. Keep the limiter out of coupled bird replay and use the archived resolution trend to isolate the remaining defect.",
            diameters: [8, 12, 16],
            requestedConvectiveTimes: 5
        )
    }

    public static func runStationaryWallRecursiveRegularizationLadder()
        throws -> MetalStationaryWallGeometricLimiterLadderReport
    {
        try runStationaryWallGeometricCollisionLadder(
            collisionOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            limiterMode:
                "recursive second-plus-supported-third-order D3Q19 Hermite reconstruction with a convex equilibrium-to-post-collision positivity scale",
            acceptedClassification:
                "stationary-wall-recursive-regularization-ladder-accepted",
            rejectedClassification:
                "stationary-wall-recursive-regularization-ladder-not-accepted",
            acceptedVerdict:
                "The recursive-regularized BGK candidate remains positive, conservative, non-intrusive, and grid-convergent across geometrically similar D=8/12/16 stationary spheres. It is eligible for production integration followed by the published five-cycle flapping-wing regression ladder.",
            rejectedVerdict:
                "At least one unchanged source-aware stability, force-budget, correction-intervention, trend, or drag-convergence gate failed. Keep recursive-regularized BGK out of coupled bird replay and use the archived resolution trend to isolate the remaining defect.",
            diameters: [8, 12, 16],
            requestedConvectiveTimes: 5
        )
    }

    public static func runStationaryWallRecursiveRegularizationDurationSensitivity()
        throws -> MetalStationaryWallRecursiveDurationReport
    {
        let startTime = Date()
        let raw = try runStationaryWallGeometricCollisionLadder(
            collisionOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            limiterMode:
                "recursive second-plus-supported-third-order D3Q19 Hermite reconstruction with a convex equilibrium-to-post-collision positivity scale",
            acceptedClassification: "internal-duration-run-accepted",
            rejectedClassification: "internal-duration-run-not-accepted",
            acceptedVerdict: "Internal duration run completed.",
            rejectedVerdict: "Internal duration run did not meet ladder gates.",
            diameters: [8, 12],
            requestedConvectiveTimes: 10
        )
        let baselineConvectiveTimes = 5.0
        let maximumLateWindowChange = 5.0e-2
        let cases = raw.cases.map { item in
            let windowMeans = (0..<10).map { windowIndex in
                let lower = Double(windowIndex)
                let upper = Double(windowIndex + 1)
                let samples = item.samples.filter {
                    $0.convectiveTime > lower && $0.convectiveTime <= upper
                }
                return samples.reduce(0) { $0 + $1.dragCoefficient }
                    / Double(max(samples.count, 1))
            }
            let fourthToFifth = relativeChange(
                from: windowMeans[3],
                to: windowMeans[4]
            )
            let ninthToTenth = relativeChange(
                from: windowMeans[8],
                to: windowMeans[9]
            )
            let fifthToTenth = relativeChange(
                from: windowMeans[4],
                to: windowMeans[9]
            )
            return MetalStationaryWallRecursiveDurationCaseReport(
                numericalCase: item,
                convectiveWindowMeanDragCoefficients: windowMeans,
                fourthToFifthRelativeDragChange: fourthToFifth,
                ninthToTenthRelativeDragChange: ninthToTenth,
                fifthToTenthRelativeDragChange: fifthToTenth,
                durationStabilityPassed:
                    ninthToTenth <= maximumLateWindowChange
            )
        }
        let allIndividualGatesPassed = cases.allSatisfy {
            $0.numericalCase.passed
        }
        let durationStabilityPassed = cases.allSatisfy {
            $0.durationStabilityPassed
        }
        let baselineWindowBiasConfirmed = durationStabilityPassed
            && cases.contains {
                $0.fifthToTenthRelativeDragChange > maximumLateWindowChange
            }
        let diagnosticCompleted = cases.count == 2
            && cases.map(\.numericalCase.diameterCells) == [8, 12]
            && cases.allSatisfy {
                $0.numericalCase.completedConvectiveTimes >= 10
                    && $0.convectiveWindowMeanDragCoefficients.count == 10
                    && $0.convectiveWindowMeanDragCoefficients.allSatisfy {
                        $0.isFinite
                    }
            }
            && allIndividualGatesPassed
        let classification: String
        let verdict: String
        if !diagnosticCompleted {
            classification =
                "stationary-wall-recursive-regularization-duration-invalid"
            verdict =
                "The controlled D=8/12 ten-convective-time diagnostic did not complete all unchanged positivity, conservation, force-budget, and correction gates. Do not interpret its duration trend."
        } else if !durationStabilityPassed {
            classification =
                "stationary-wall-recursive-regularization-duration-sensitivity-unresolved"
            verdict =
                "At least one D=8/12 drag history still changes by more than 5% between the ninth and tenth convective windows. Extend only that resolution before spending on D=20 or coupled bird replay."
        } else if baselineWindowBiasConfirmed {
            classification =
                "stationary-wall-recursive-regularization-duration-window-bias-confirmed"
            verdict =
                "Both coarse histories are late-window stable, while at least one fifth-window drag differs from its tenth-window value by more than 5%. The previous five-convective-time spatial comparison contained material transient-window bias and must be replaced before judging spatial convergence."
        } else {
            classification =
                "stationary-wall-recursive-regularization-duration-window-insensitive"
            verdict =
                "Both D=8/12 histories are late-window stable and their fifth-to-tenth drag changes remain within 5%. The prior five-convective-time nonconvergence is not explained by duration bias; D=20 is the next discriminating spatial test."
        }
        return MetalStationaryWallRecursiveDurationReport(
            schemaVersion: 1,
            deviceName: raw.deviceName,
            productionKernel: raw.productionKernel,
            ledgerCaptureKernel: raw.ledgerCaptureKernel,
            collisionMode: raw.limiterMode,
            classification: classification,
            baselineConvectiveTimes: baselineConvectiveTimes,
            requestedConvectiveTimes: 10,
            maximumAllowedLateWindowChange: maximumLateWindowChange,
            cases: cases,
            allIndividualGatesPassed: allIndividualGatesPassed,
            durationStabilityPassed: durationStabilityPassed,
            baselineWindowBiasConfirmed: baselineWindowBiasConfirmed,
            scientificVerdict: verdict,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            diagnosticCompleted: diagnosticCompleted,
            passed: diagnosticCompleted
        )
    }

    private static func relativeChange(from: Double, to: Double) -> Double {
        abs(to - from) / max(abs(to), 1.0e-30)
    }

    private static func runStationaryWallGeometricCollisionLadder(
        collisionOperator: BulkCollisionOperator,
        limiterMode: String,
        acceptedClassification: String,
        rejectedClassification: String,
        acceptedVerdict: String,
        rejectedVerdict: String,
        diameters: [Int],
        requestedConvectiveTimes: Double
    ) throws -> MetalStationaryWallGeometricLimiterLadderReport {
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let reynoldsNumber = 9_367.4
        let referenceSpeed = 0.08
        let domainLengthDiameters = 10
        let domainCrossflowDiameters = 6
        let sphereCenterFromInletDiameters = 3
        let spongeWidthDiameters = 0.5
        let spongeStrength = 0.04
        let maximumRelativeRMSForceResidual = 5.0e-3
        let maximumPeakForceResidualRatio = 1.0e-3
        let maximumLimiterActivationFraction = 5.0e-2
        let maximumRelativeLimiterCorrection = 1.0e-2
        let maximumFinestTwoDragChange = 5.0e-2
        var cases: [MetalStationaryWallGeometricLimiterCaseReport] = []

        for diameter in diameters {
            let domain = try GridSize(
                x: domainLengthDiameters * diameter,
                y: domainCrossflowDiameters * diameter,
                z: domainCrossflowDiameters * diameter
            )
            let radius = Float(diameter) * 0.5
            let center = SIMD3<Float>(
                Float(sphereCenterFromInletDiameters * diameter),
                Float(domain.y) * 0.5,
                Float(domain.z) * 0.5
            )
            let spongeWidth = Int(
                (Double(diameter) * spongeWidthDiameters).rounded()
            )
            let controlMinimum = SIMD3<UInt32>(
                repeating: UInt32(spongeWidth)
            )
            let controlMaximum = SIMD3<UInt32>(
                UInt32(domain.x - spongeWidth),
                UInt32(domain.y - spongeWidth),
                UInt32(domain.z - spongeWidth)
            )
            let viscosity = Float(
                referenceSpeed * Double(diameter) / reynoldsNumber
            )
            let steps = Int(
                (requestedConvectiveTimes
                    * Double(diameter) / referenceSpeed).rounded()
            )
            let configuration = MetalTranslatingBodyCaseConfiguration(
                grid: domain,
                sphereRadiusCells: radius,
                referenceSpeedLattice: Float(referenceSpeed),
                geometryTranslationSpeedLattice: 0,
                wallVelocityLattice: 0,
                wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
                initialFluidVelocityLattice: Float(referenceSpeed),
                periodicBoundaries: false,
                spongeStrength: Float(spongeStrength),
                latticeKinematicViscosity: viscosity,
                initialCenter: center,
                controlMinimum: controlMinimum,
                controlMaximumExclusive: controlMaximum,
                characteristicLengthCells: diameter,
                spongeWidthCells: spongeWidth
            )
            let simulation = try MetalTranslatingBodyTopologySimulation(
                backend: backend,
                linkForceMode: 6,
                caseConfiguration: configuration,
                symmetricPositivityLimiterEnabled:
                    collisionOperator == .symmetricLimitedTRT,
                positivityPreservingRegularizedCollisionEnabled:
                    collisionOperator
                        == .positivityPreservingRegularizedBGK,
                positivityPreservingRecursiveRegularizedCollisionEnabled:
                    collisionOperator
                        == .positivityPreservingRecursiveRegularizedBGK,
                conservationLedgerEnabled: true
            )
            let initial = try simulation.copyPopulations()
            let history = try simulation.run(
                steps: steps,
                capturePopulationMinimum: true,
                stopOneStepAfterFirstNonFinitePopulation: true,
                captureConservationLedger: true
            )
            let final = try simulation.copyPopulations()
            let base = symmetricLimiterCaseReport(
                limiterEnabled: true,
                requestedSteps: steps,
                initialPopulations: initial,
                finalPopulations: final,
                history: history,
                cellCount: domain.cellCount,
                maximumMassDrift: 1.0e-3,
                maximumAbsolutePopulation: 10,
                maximumForceResidual: 5.0e-4,
                maximumRelativeResidual: maximumRelativeRMSForceResidual
            )
            let ledger = conservationLedgerReport(
                history: history,
                initialPopulationMass: base.initialPopulationMass,
                finalPopulationMass: base.finalPopulationMass,
                forceToPhysical: Double(simulation.forceToPhysical)
            )
            let forceDenominator = 0.5 * referenceSpeed * referenceSpeed
                * Double.pi * pow(Double(radius), 2)
            let convectiveWindowSteps = max(
                1,
                Int((Double(diameter) / referenceSpeed).rounded())
            )
            let forceWindow = history.suffix(convectiveWindowSteps)
            let meanForce = forceWindow.reduce(SIMD3<Double>.zero) {
                $0 + doubleVector($1.measuredForce)
            } / Double(max(forceWindow.count, 1))
            let meanDragCoefficient = meanForce.x / forceDenominator
            let meanSideForceRatio = hypot(meanForce.y, meanForce.z)
                / max(abs(meanForce.x), 1.0e-30)
            let maximumCrossingLinks = history.map {
                $0.solidControlSurfaceCrossingLinkCount
            }.max() ?? 0
            let outsideSponge = ledger.samples.allSatisfy {
                $0.controlVolumeSpongeCellCount == 0
            }
            let totalCellSteps = Double(domain.cellCount * steps)
            let activationFraction = Double(
                base.limiterActivationCellSteps
            ) / max(totalCellSteps, 1)
            let controlExtent = controlMaximum &- controlMinimum
            let controlCellCount = Int(controlExtent.x)
                * Int(controlExtent.y) * Int(controlExtent.z)
            var controlActivationCellSteps = 0
            var spongeActivationCellSteps = 0
            var activatedBoundaryLinkSteps = 0
            var limiterL1 = 0.0
            var limiterL2Squared = 0.0
            var collisionL1 = 0.0
            var collisionL2Squared = 0.0
            var controlLimiterL1 = 0.0
            var controlLimiterL2Squared = 0.0
            var controlCollisionL1 = 0.0
            var controlCollisionL2Squared = 0.0
            var compactSamples: [MetalStationaryWallGeometricLimiterSample] = []
            compactSamples.reserveCapacity(history.count)
            for (index, step) in history.enumerated() {
                guard let raw = step.conservationLedger,
                      let populationMinimum = step.populationMinimum else {
                    continue
                }
                limiterL1 += raw.limiterNorms.x
                limiterL2Squared += raw.limiterNorms.y
                collisionL1 += raw.limiterNorms.z
                collisionL2Squared += raw.limiterNorms.w
                controlLimiterL1 += raw.limiterControlNorms.x
                controlLimiterL2Squared += raw.limiterControlNorms.y
                controlCollisionL1 += raw.limiterControlNorms.z
                controlCollisionL2Squared += raw.limiterControlNorms.w
                controlActivationCellSteps +=
                    raw.controlVolumeActivatedCellCount
                spongeActivationCellSteps += raw.activatedSpongeCellCount
                activatedBoundaryLinkSteps += raw.activatedBoundaryLinkCount
                let stepLimiterL1Ratio = raw.limiterNorms.x
                    / max(raw.limiterNorms.z, 1.0e-30)
                let stepLimiterL2Ratio = sqrt(
                    max(raw.limiterNorms.y, 0)
                        / max(raw.limiterNorms.w, 1.0e-30)
                )
                let stepControlLimiterL1Ratio =
                    raw.limiterControlNorms.x
                    / max(raw.limiterControlNorms.z, 1.0e-30)
                let stepControlLimiterL2Ratio = sqrt(
                    max(raw.limiterControlNorms.y, 0)
                        / max(raw.limiterControlNorms.w, 1.0e-30)
                )
                let boundaryAndFarField = raw.boundaryGlobal
                    + raw.farFieldGlobal
                let collisionAndLimiter = raw.collisionGlobal
                    + raw.limiterGlobal
                let accounted = boundaryAndFarField
                    + collisionAndLimiter
                    + raw.spongeGlobal
                let closure = raw.observedGlobal - accounted
                let residual = doubleVector(
                    step.measuredForce - step.rawBudgetForce
                )
                compactSamples.append(
                    MetalStationaryWallGeometricLimiterSample(
                        step: index + 1,
                        convectiveTime: Double(index + 1)
                            * referenceSpeed / Double(diameter),
                        minimumPopulation:
                            Double(populationMinimum.rawValue),
                        dragCoefficient:
                            Double(step.measuredForce.x) / forceDenominator,
                        limiterActivationCount:
                            step.symmetricLimiterActivationCount,
                        limiterActivationFraction:
                            Double(step.symmetricLimiterActivationCount)
                                / Double(domain.cellCount),
                        controlVolumeLimiterActivationFraction:
                            Double(raw.controlVolumeActivatedCellCount)
                                / Double(controlCellCount),
                        minimumLimiterScale:
                            step.symmetricLimiterMinimumScale.map(Double.init),
                        relativeLimiterL1Correction: stepLimiterL1Ratio,
                        relativeLimiterL2Correction: stepLimiterL2Ratio,
                        relativeControlVolumeLimiterL1Correction:
                            stepControlLimiterL1Ratio,
                        relativeControlVolumeLimiterL2Correction:
                            stepControlLimiterL2Ratio,
                        forceBudgetResidualCoefficient:
                            magnitude(residual) / forceDenominator,
                        globalMassClosureResidual: abs(closure.x),
                        controlVolumeSpongeCellCount:
                            raw.controlVolumeSpongeCellCount,
                        solidControlSurfaceCrossingLinkCount:
                            step.solidControlSurfaceCrossingLinkCount
                    )
                )
            }
            let limiterL2 = sqrt(max(limiterL2Squared, 0))
            let collisionL2 = sqrt(max(collisionL2Squared, 0))
            let relativeLimiterL1 = limiterL1 / max(collisionL1, 1.0e-30)
            let relativeLimiterL2 = limiterL2 / max(collisionL2, 1.0e-30)
            let controlLimiterL2 = sqrt(max(controlLimiterL2Squared, 0))
            let controlCollisionL2 = sqrt(max(controlCollisionL2Squared, 0))
            let relativeControlLimiterL1 = controlLimiterL1
                / max(controlCollisionL1, 1.0e-30)
            let relativeControlLimiterL2 = controlLimiterL2
                / max(controlCollisionL2, 1.0e-30)
            let controlActivationFraction = Double(
                controlActivationCellSteps
            ) / max(Double(controlCellCount * steps), 1)
            let maximumResidualRatio =
                (base.maximumConservativeForceResidual ?? .infinity)
                / max(base.maximumMeasuredForceMagnitude ?? 0, 1.0e-30)
            let sourceAwareStabilityPassed = history.count == steps
                && base.firstNegativePopulationStep == nil
                && base.firstNonFinitePopulationStep == nil
                && base.firstNonFiniteLoadStep == nil
                && base.populationsFinite
                && base.fieldsFinite
                && base.loadsFinite
                && base.newlyCoveredCellEvents == 0
                && base.newlyUncoveredCellEvents == 0
                && base.topologyTransitionSteps == 0
                && ledger.globalLedgerClosed
                && ledger.relativeCumulativeLimiterMassContribution
                    <= 1.0e-6
            let forceBudgetPassed = maximumCrossingLinks == 0
                && outsideSponge
                && (base.conservativeRelativeRMSResidual ?? .infinity)
                    <= maximumRelativeRMSForceResidual
                && maximumResidualRatio <= maximumPeakForceResidualRatio
                && ledger.relativeRMSBoundaryLoadClosureResidual <= 5.0e-5
            let limiterNonIntrusivePassed = controlActivationFraction
                    <= maximumLimiterActivationFraction
                && relativeControlLimiterL1
                    <= maximumRelativeLimiterCorrection
                && relativeControlLimiterL2
                    <= maximumRelativeLimiterCorrection
            let casePassed = sourceAwareStabilityPassed
                && forceBudgetPassed
                && limiterNonIntrusivePassed
            cases.append(MetalStationaryWallGeometricLimiterCaseReport(
                diameterCells: diameter,
                domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
                sphereCenterCells: SIMD3<Double>(
                    Double(center.x),
                    Double(center.y),
                    Double(center.z)
                ),
                sphereRadiusCells: Double(radius),
                spongeWidthCells: spongeWidth,
                controlMinimumCells: SIMD3<Int>(
                    Int(controlMinimum.x),
                    Int(controlMinimum.y),
                    Int(controlMinimum.z)
                ),
                controlMaximumExclusiveCells: SIMD3<Int>(
                    Int(controlMaximum.x),
                    Int(controlMaximum.y),
                    Int(controlMaximum.z)
                ),
                latticeKinematicViscosity: Double(viscosity),
                tauPlus: Double(simulation.tauPlus),
                requestedSteps: steps,
                completedConvectiveTimes:
                    Double(history.count) * referenceSpeed / Double(diameter),
                minimumObservedPopulation: base.minimumObservedPopulation,
                limiterActivationCellSteps: base.limiterActivationCellSteps,
                limiterActivationSteps: base.limiterActivationSteps,
                limiterActivationFraction: activationFraction,
                controlVolumeLimiterActivationCellSteps:
                    controlActivationCellSteps,
                controlVolumeLimiterActivationFraction:
                    controlActivationFraction,
                spongeLimiterActivationCellSteps: spongeActivationCellSteps,
                activatedBoundaryLinkSteps: activatedBoundaryLinkSteps,
                minimumLimiterScale: base.minimumLimiterScale,
                cumulativeLimiterL1Correction: limiterL1,
                cumulativeLimiterL2Correction: limiterL2,
                cumulativeCollisionL1Increment: collisionL1,
                cumulativeCollisionL2Increment: collisionL2,
                relativeLimiterL1Correction: relativeLimiterL1,
                relativeLimiterL2Correction: relativeLimiterL2,
                cumulativeControlVolumeLimiterL1Correction:
                    controlLimiterL1,
                cumulativeControlVolumeLimiterL2Correction:
                    controlLimiterL2,
                cumulativeControlVolumeCollisionL1Increment:
                    controlCollisionL1,
                cumulativeControlVolumeCollisionL2Increment:
                    controlCollisionL2,
                relativeControlVolumeLimiterL1Correction:
                    relativeControlLimiterL1,
                relativeControlVolumeLimiterL2Correction:
                    relativeControlLimiterL2,
                relativeCumulativeLimiterMassContribution:
                    ledger.relativeCumulativeLimiterMassContribution,
                meanDragCoefficientLastConvectiveTime: meanDragCoefficient,
                meanSideForceToDragRatioLastConvectiveTime:
                    meanSideForceRatio,
                maximumForceBudgetResidualCoefficient:
                    (base.maximumConservativeForceResidual ?? .infinity)
                        / forceDenominator,
                maximumForceBudgetResidualRatio: maximumResidualRatio,
                conservativeRelativeRMSResidual:
                    base.conservativeRelativeRMSResidual ?? .infinity,
                maximumSolidControlSurfaceCrossingLinkCount:
                    maximumCrossingLinks,
                controlVolumeOutsideSponge: outsideSponge,
                globalLedgerClosed: ledger.globalLedgerClosed,
                relativeRMSBoundaryLoadClosureResidual:
                    ledger.relativeRMSBoundaryLoadClosureResidual,
                sourceAwareStabilityPassed: sourceAwareStabilityPassed,
                forceBudgetPassed: forceBudgetPassed,
                limiterNonIntrusivePassed: limiterNonIntrusivePassed,
                passed: casePassed,
                samples: compactSamples
            ))
        }

        let finest = cases[cases.count - 1]
        let nextFinest = cases[cases.count - 2]
        let finestTwoDragChange = abs(
            finest.meanDragCoefficientLastConvectiveTime
                - nextFinest.meanDragCoefficientLastConvectiveTime
        ) / max(abs(finest.meanDragCoefficientLastConvectiveTime), 1.0e-30)
        let activationNonIncreasing = zip(cases, cases.dropFirst())
            .allSatisfy { coarse, fine in
                fine.controlVolumeLimiterActivationFraction
                    <= coarse.controlVolumeLimiterActivationFraction * 1.05
            }
        let correctionNonIncreasing = zip(cases, cases.dropFirst())
            .allSatisfy { coarse, fine in
                fine.relativeControlVolumeLimiterL1Correction
                    <= coarse.relativeControlVolumeLimiterL1Correction * 1.05
                    && fine.relativeControlVolumeLimiterL2Correction
                        <= coarse.relativeControlVolumeLimiterL2Correction * 1.05
            }
        let fit = generalizedRichardsonFit(
            diameters: cases.map(\.diameterCells),
            values: cases.map(\.meanDragCoefficientLastConvectiveTime)
        )
        let passed = cases.allSatisfy(\.passed)
            && finestTwoDragChange <= maximumFinestTwoDragChange
            && activationNonIncreasing
            && correctionNonIncreasing
            && fit != nil
        let classification = passed
            ? acceptedClassification
            : rejectedClassification
        let verdict = passed
            ? acceptedVerdict
            : rejectedVerdict
        return MetalStationaryWallGeometricLimiterLadderReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            ledgerCaptureKernel: "captureSymmetricLimiterLedger",
            limiterMode: limiterMode,
            classification: classification,
            reynoldsNumber: reynoldsNumber,
            latticeFarFieldSpeed: referenceSpeed,
            latticeMachNumber: referenceSpeed / sqrt(1.0 / 3.0),
            domainLengthDiameters: Double(domainLengthDiameters),
            domainCrossflowDiameters: Double(domainCrossflowDiameters),
            sphereCenterFromInletDiameters:
                Double(sphereCenterFromInletDiameters),
            spongeWidthDiameters: spongeWidthDiameters,
            requestedConvectiveTimes: requestedConvectiveTimes,
            maximumAllowedRelativeRMSForceResidual:
                maximumRelativeRMSForceResidual,
            maximumAllowedPeakForceResidualRatio:
                maximumPeakForceResidualRatio,
            maximumAllowedLimiterActivationFraction:
                maximumLimiterActivationFraction,
            maximumAllowedRelativeLimiterCorrection:
                maximumRelativeLimiterCorrection,
            maximumAllowedFinestTwoDragChange:
                maximumFinestTwoDragChange,
            relativeFinestTwoDragChange: finestTwoDragChange,
            limiterActivationNonIncreasing: activationNonIncreasing,
            limiterCorrectionNonIncreasing: correctionNonIncreasing,
            observedDragConvergenceOrder: fit?.order,
            richardsonExtrapolatedDragCoefficient: fit?.extrapolated,
            fineGridConvergenceIndex: fit?.fineGridConvergenceIndex,
            convergenceMethod:
                "three-grid nonlinear least-squares fit Cd(h)=Cd0+C*h^p over p in [0.05,8], with 1.25 fine-grid GCI safety factor",
            cases: cases,
            scientificVerdict: verdict,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            passed: passed
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func runStationaryWallRadialLimiterLocalization()
        throws -> MetalStationaryWallRadialLimiterReport
    {
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let diameter = 16
        let radius = Float(diameter) * 0.5
        let reynoldsNumber = 9_367.4
        let referenceSpeed = 0.08
        let domain = try GridSize(x: 160, y: 96, z: 96)
        let center = SIMD3<Float>(48, 48, 48)
        let spongeWidth = 8
        let controlMinimum = SIMD3<UInt32>(8, 8, 8)
        let controlMaximum = SIMD3<UInt32>(152, 88, 88)
        let requestedSteps = 1_000
        let captureSteps = [15, 100, 250, 500, 750, 1_000]
        let captureStepSet = Set(captureSteps)
        let radialEdges = [
            0.0625, 0.125, 0.25, 0.5, 1.0, 2.0, 3.0,
        ]
        let nearSurfaceMaximum = 0.25
        let farFieldMinimum = 1.0
        let minimumNearSurfaceFraction = 0.80
        let maximumFarFieldFraction = 0.05
        let maximumClosureResidual = 1.0e-4
        let viscosity = Float(
            referenceSpeed * Double(diameter) / reynoldsNumber
        )
        let configuration = MetalTranslatingBodyCaseConfiguration(
            grid: domain,
            sphereRadiusCells: radius,
            referenceSpeedLattice: Float(referenceSpeed),
            geometryTranslationSpeedLattice: 0,
            wallVelocityLattice: 0,
            wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
            initialFluidVelocityLattice: Float(referenceSpeed),
            periodicBoundaries: false,
            spongeStrength: 0.04,
            latticeKinematicViscosity: viscosity,
            initialCenter: center,
            controlMinimum: controlMinimum,
            controlMaximumExclusive: controlMaximum,
            characteristicLengthCells: diameter,
            spongeWidthCells: spongeWidth
        )
        let simulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: configuration,
            symmetricPositivityLimiterEnabled: true,
            conservationLedgerEnabled: true
        )
        let history = try simulation.run(
            steps: requestedSteps,
            capturePopulationMinimum: true,
            stopOneStepAfterFirstNonFinitePopulation: true,
            captureConservationLedger: true,
            radialCaptureSteps: captureStepSet
        )
        let forceDenominator = 0.5 * referenceSpeed * referenceSpeed
            * Double.pi * pow(Double(radius), 2)
        var snapshots: [MetalStationaryWallRadialLimiterSnapshot] = []
        snapshots.reserveCapacity(captureSteps.count)
        var maximumObservedClosure = 0.0
        var activationCountsClose = true

        for captureStep in captureSteps where captureStep <= history.count {
            let step = history[captureStep - 1]
            guard let raw = step.conservationLedger,
                  let rawBins = step.radialLimiterBins,
                  let populationMinimum = step.populationMinimum else {
                continue
            }
            let totalLimiterL1 = rawBins.reduce(0.0) { $0 + $1.norms.x }
            let totalLimiterL2Squared = rawBins.reduce(0.0) {
                $0 + $1.norms.y
            }
            let totalCollisionL1 = rawBins.reduce(0.0) { $0 + $1.norms.z }
            let totalCollisionL2Squared = rawBins.reduce(0.0) {
                $0 + $1.norms.w
            }
            let radialActivatedCount = rawBins.reduce(0) {
                $0 + $1.activatedCellCount
            }
            activationCountsClose = activationCountsClose
                && radialActivatedCount
                    == raw.controlVolumeActivatedCellCount
            func relativeResidual(_ actual: Double, _ expected: Double)
                -> Double
            {
                abs(actual - expected) / max(abs(expected), 1.0e-30)
            }
            let limiterL1Closure = relativeResidual(
                totalLimiterL1,
                raw.limiterControlNorms.x
            )
            let limiterL2Closure = relativeResidual(
                totalLimiterL2Squared,
                raw.limiterControlNorms.y
            )
            let collisionL1Closure = relativeResidual(
                totalCollisionL1,
                raw.limiterControlNorms.z
            )
            let collisionL2Closure = relativeResidual(
                totalCollisionL2Squared,
                raw.limiterControlNorms.w
            )
            maximumObservedClosure = max(
                maximumObservedClosure,
                limiterL1Closure,
                limiterL2Closure,
                collisionL1Closure,
                collisionL2Closure
            )
            let bins = rawBins.enumerated().map { index, bin in
                let minimumDistance = index == 0
                    ? 0
                    : radialEdges[index - 1]
                let maximumDistance = index < radialEdges.count
                    ? radialEdges[index]
                    : nil
                return MetalStationaryWallRadialLimiterBin(
                    binIndex: index,
                    minimumSurfaceDistanceDiameters: minimumDistance,
                    maximumSurfaceDistanceDiameters: maximumDistance,
                    minimumSurfaceDistanceCells:
                        minimumDistance * Double(diameter),
                    maximumSurfaceDistanceCells:
                        maximumDistance.map { $0 * Double(diameter) },
                    fluidCellCount: bin.fluidCellCount,
                    activatedCellCount: bin.activatedCellCount,
                    activationFraction: Double(bin.activatedCellCount)
                        / max(Double(bin.fluidCellCount), 1),
                    fractionOfSnapshotActivatedCells:
                        Double(bin.activatedCellCount)
                        / max(Double(radialActivatedCount), 1),
                    boundaryLinkCount: bin.boundaryLinkCount,
                    activatedBoundaryLinkCount:
                        bin.activatedBoundaryLinkCount,
                    limiterL1Correction: bin.norms.x,
                    limiterL2Correction: sqrt(max(bin.norms.y, 0)),
                    collisionL1Increment: bin.norms.z,
                    collisionL2Increment: sqrt(max(bin.norms.w, 0)),
                    relativeLimiterL1Correction:
                        bin.norms.x / max(bin.norms.z, 1.0e-30),
                    relativeLimiterL2Correction:
                        sqrt(max(bin.norms.y, 0))
                        / max(sqrt(max(bin.norms.w, 0)), 1.0e-30),
                    fractionOfSnapshotLimiterL1Correction:
                        bin.norms.x / max(totalLimiterL1, 1.0e-30)
                )
            }
            let nearBins = bins.filter {
                ($0.maximumSurfaceDistanceDiameters ?? .infinity)
                    <= nearSurfaceMaximum
            }
            let farBins = bins.filter {
                $0.minimumSurfaceDistanceDiameters >= farFieldMinimum
            }
            snapshots.append(MetalStationaryWallRadialLimiterSnapshot(
                step: captureStep,
                convectiveTime: Double(captureStep) * referenceSpeed
                    / Double(diameter),
                minimumPopulation: Double(populationMinimum.rawValue),
                dragCoefficient:
                    Double(step.measuredForce.x) / forceDenominator,
                controlVolumeActivatedCellCount:
                    raw.controlVolumeActivatedCellCount,
                radialActivatedCellCount: radialActivatedCount,
                nearSurfaceLimiterL1Fraction: nearBins.reduce(0) {
                    $0 + $1.fractionOfSnapshotLimiterL1Correction
                },
                farFieldLimiterL1Fraction: farBins.reduce(0) {
                    $0 + $1.fractionOfSnapshotLimiterL1Correction
                },
                nearSurfaceActivationFraction: nearBins.reduce(0) {
                    $0 + $1.fractionOfSnapshotActivatedCells
                },
                farFieldActivationFraction: farBins.reduce(0) {
                    $0 + $1.fractionOfSnapshotActivatedCells
                },
                relativeLimiterL1ClosureResidual: limiterL1Closure,
                relativeLimiterL2SquaredClosureResidual: limiterL2Closure,
                relativeCollisionL1ClosureResidual: collisionL1Closure,
                relativeCollisionL2SquaredClosureResidual:
                    collisionL2Closure,
                bins: bins
            ))
        }

        let firstActivationStep = history.firstIndex {
            $0.symmetricLimiterActivationCount > 0
        }.map { $0 + 1 }
        let populationPositivityPassed = history.count == requestedSteps
            && history.allSatisfy {
                guard let minimum = $0.populationMinimum else { return false }
                return !minimum.nonFinite
                    && minimum.rawValue.isFinite
                    && minimum.rawValue > 0
                    && $0.measuredForce.x.isFinite
                    && $0.measuredForce.y.isFinite
                    && $0.measuredForce.z.isFinite
            }
        let controlVolumeIsolationPassed = history.allSatisfy {
            $0.solidControlSurfaceCrossingLinkCount == 0
        } && snapshots.allSatisfy { snapshot in
            let raw = history[snapshot.step - 1].conservationLedger
            return raw?.controlVolumeSpongeCellCount == 0
        }
        let radialClosurePassed = activationCountsClose
            && maximumObservedClosure <= maximumClosureResidual
        let diagnosticPassed = snapshots.count == captureSteps.count
            && firstActivationStep == captureSteps.first
            && populationPositivityPassed
            && controlVolumeIsolationPassed
            && radialClosurePassed
        let finalSnapshot = snapshots.last
        let finalNearFraction = finalSnapshot?
            .nearSurfaceLimiterL1Fraction ?? 0
        let finalFarFraction = finalSnapshot?
            .farFieldLimiterL1Fraction ?? 1
        let finalNearActivation = finalSnapshot?
            .nearSurfaceActivationFraction ?? 0
        let finalFarActivation = finalSnapshot?
            .farFieldActivationFraction ?? 1
        let boundaryLocalized = diagnosticPassed
            && finalNearFraction >= minimumNearSurfaceFraction
            && finalFarFraction <= maximumFarFieldFraction
        let classification: String
        if !diagnosticPassed {
            classification = "stationary-wall-c16-radial-localization-invalid"
        }
        else if boundaryLocalized {
            classification =
                "stationary-wall-c16-limiter-curved-boundary-localized"
        }
        else if finalFarFraction > maximumFarFieldFraction {
            classification =
                "stationary-wall-c16-limiter-spreads-beyond-one-diameter"
        }
        else {
            classification =
                "stationary-wall-c16-limiter-not-near-surface-localized"
        }
        let verdict = boundaryLocalized
            ? "At the final snapshot at least 80% of limiter L1 correction remains within 0.25D of the sphere and no more than 5% lies beyond 1D. Prioritize a curved-boundary-specific correction before changing the bulk collision operator."
            : "The final limiter correction does not satisfy the predeclared curved-boundary localization contract. Use its radial spread to choose a collision-operator A/B before any flapping or measured-bird replay."
        return MetalStationaryWallRadialLimiterReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            ledgerCaptureKernel: "captureSymmetricLimiterLedger",
            radialReductionKernel: "reduceSymmetricLimiterRadialBins",
            classification: classification,
            reynoldsNumber: reynoldsNumber,
            latticeFarFieldSpeed: referenceSpeed,
            latticeMachNumber: referenceSpeed / sqrt(1.0 / 3.0),
            diameterCells: diameter,
            domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
            sphereCenterCells: SIMD3<Double>(
                Double(center.x), Double(center.y), Double(center.z)
            ),
            sphereRadiusCells: Double(radius),
            spongeWidthCells: spongeWidth,
            controlMinimumCells: SIMD3<Int>(
                Int(controlMinimum.x),
                Int(controlMinimum.y),
                Int(controlMinimum.z)
            ),
            controlMaximumExclusiveCells: SIMD3<Int>(
                Int(controlMaximum.x),
                Int(controlMaximum.y),
                Int(controlMaximum.z)
            ),
            requestedSteps: requestedSteps,
            firstLimiterActivationStep: firstActivationStep,
            captureSteps: captureSteps,
            radialUpperEdgesDiameters: radialEdges,
            nearSurfaceMaximumDistanceDiameters: nearSurfaceMaximum,
            farFieldMinimumDistanceDiameters: farFieldMinimum,
            minimumBoundaryLocalizedLimiterL1Fraction:
                minimumNearSurfaceFraction,
            maximumBoundaryLocalizedFarFieldLimiterL1Fraction:
                maximumFarFieldFraction,
            maximumAllowedRadialClosureResidual: maximumClosureResidual,
            maximumObservedRadialClosureResidual: maximumObservedClosure,
            finalNearSurfaceLimiterL1Fraction: finalNearFraction,
            finalFarFieldLimiterL1Fraction: finalFarFraction,
            finalNearSurfaceActivationFraction: finalNearActivation,
            finalFarFieldActivationFraction: finalFarActivation,
            populationPositivityPassed: populationPositivityPassed,
            controlVolumeIsolationPassed: controlVolumeIsolationPassed,
            radialClosurePassed: radialClosurePassed,
            boundaryLocalized: boundaryLocalized,
            snapshots: snapshots,
            scientificVerdict: verdict,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            passed: diagnosticPassed
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func runStationaryWallBulkCollisionOperatorAB()
        throws -> MetalStationaryWallBulkCollisionABReport
    {
        try runStationaryWallBulkCollisionOperatorAB(
            controlOperator: .symmetricLimitedTRT,
            candidateOperator: .positivityPreservingRegularizedBGK,
            invalidClassification:
                "stationary-wall-c16-bulk-collision-ab-invalid",
            eligibleClassification:
                "stationary-wall-c16-regularized-candidate-eligible-for-refinement",
            rejectedClassification:
                "stationary-wall-c16-regularized-candidate-rejected",
            eligibleVerdict:
                "The positivity-preserving regularized BGK candidate clears the unchanged D=16 positivity, source-ledger, force-budget, and correction-intrusion gates. It is eligible for the locked D=8/12/16 refinement ladder; grid convergence is not established by this A/B.",
            rejectedVerdict:
                "The positivity-preserving regularized BGK candidate fails at least one unchanged D=16 positivity, source-ledger, force-budget, or correction-intrusion gate. Reject it before spending a D=8/12/16 refinement ladder."
        )
    }

    public static func runStationaryWallRecursiveRegularizationAB()
        throws -> MetalStationaryWallBulkCollisionABReport
    {
        try runStationaryWallBulkCollisionOperatorAB(
            controlOperator: .positivityPreservingRegularizedBGK,
            candidateOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            invalidClassification:
                "stationary-wall-c16-recursive-regularization-ab-invalid",
            eligibleClassification:
                "stationary-wall-c16-recursive-regularized-candidate-eligible-for-refinement",
            rejectedClassification:
                "stationary-wall-c16-recursive-regularized-candidate-rejected",
            eligibleVerdict:
                "The positivity-preserving recursive-regularized BGK candidate clears the unchanged D=16 positivity, source-ledger, force-budget, and correction-intrusion gates against the second-order regularized control. It is eligible for the locked D=8/12/16 refinement ladder; grid convergence is not established by this A/B.",
            rejectedVerdict:
                "The positivity-preserving recursive-regularized BGK candidate fails at least one unchanged D=16 positivity, source-ledger, force-budget, or correction-intrusion gate against the second-order regularized control. Reject it before spending a D=8/12/16 refinement ladder."
        )
    }

    private static func runStationaryWallBulkCollisionOperatorAB(
        controlOperator: BulkCollisionOperator,
        candidateOperator: BulkCollisionOperator,
        invalidClassification: String,
        eligibleClassification: String,
        rejectedClassification: String,
        eligibleVerdict: String,
        rejectedVerdict: String
    ) throws -> MetalStationaryWallBulkCollisionABReport {
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let diameter = 16
        let radius = Float(diameter) * 0.5
        let reynoldsNumber = 9_367.4
        let referenceSpeed = 0.08
        let domain = try GridSize(x: 160, y: 96, z: 96)
        let center = SIMD3<Float>(48, 48, 48)
        let spongeWidth = 8
        let controlMinimum = SIMD3<UInt32>(8, 8, 8)
        let controlMaximum = SIMD3<UInt32>(152, 88, 88)
        let requestedSteps = 1_000
        let requestedConvectiveTimes = Double(requestedSteps)
            * referenceSpeed / Double(diameter)
        let maximumRelativeRMSForceResidual = 5.0e-3
        let maximumPeakForceResidualRatio = 1.0e-3
        let maximumCorrectionActivationFraction = 5.0e-2
        let maximumRelativeCorrection = 1.0e-2
        let maximumRadialClosureResidual = 1.0e-4
        let viscosity = Float(
            referenceSpeed * Double(diameter) / reynoldsNumber
        )
        let configuration = MetalTranslatingBodyCaseConfiguration(
            grid: domain,
            sphereRadiusCells: radius,
            referenceSpeedLattice: Float(referenceSpeed),
            geometryTranslationSpeedLattice: 0,
            wallVelocityLattice: 0,
            wallVelocityMode: HighReSphereWallMode.uniform.rawValue,
            initialFluidVelocityLattice: Float(referenceSpeed),
            periodicBoundaries: false,
            spongeStrength: 0.04,
            latticeKinematicViscosity: viscosity,
            initialCenter: center,
            controlMinimum: controlMinimum,
            controlMaximumExclusive: controlMaximum,
            characteristicLengthCells: diameter,
            spongeWidthCells: spongeWidth
        )
        let control = try runStationaryWallBulkCollisionCase(
            collisionOperator: controlOperator,
            backend: backend,
            configuration: configuration,
            diameter: diameter,
            radius: radius,
            referenceSpeed: referenceSpeed,
            requestedSteps: requestedSteps,
            maximumRelativeRMSForceResidual:
                maximumRelativeRMSForceResidual,
            maximumPeakForceResidualRatio:
                maximumPeakForceResidualRatio,
            maximumCorrectionActivationFraction:
                maximumCorrectionActivationFraction,
            maximumRelativeCorrection: maximumRelativeCorrection,
            maximumRadialClosureResidual:
                maximumRadialClosureResidual
        )
        let candidate = try runStationaryWallBulkCollisionCase(
            collisionOperator: candidateOperator,
            backend: backend,
            configuration: configuration,
            diameter: diameter,
            radius: radius,
            referenceSpeed: referenceSpeed,
            requestedSteps: requestedSteps,
            maximumRelativeRMSForceResidual:
                maximumRelativeRMSForceResidual,
            maximumPeakForceResidualRatio:
                maximumPeakForceResidualRatio,
            maximumCorrectionActivationFraction:
                maximumCorrectionActivationFraction,
            maximumRelativeCorrection: maximumRelativeCorrection,
            maximumRadialClosureResidual:
                maximumRadialClosureResidual
        )
        let activationRatio = candidate
            .controlVolumeCorrectionActivationFraction
            / max(
                control.controlVolumeCorrectionActivationFraction,
                1.0e-30
            )
        let correctionRatio = candidate
            .relativeControlVolumeCorrectionL1
            / max(control.relativeControlVolumeCorrectionL1, 1.0e-30)
        let diagnosticCompleted = control.populationPositivityPassed
            && control.controlVolumeIsolationPassed
            && control.globalLedgerClosed
            && control.radialCaptureCompleted
            && candidate.completedSteps > 0
            && candidate.globalLedgerClosed
        let candidateEligible = diagnosticCompleted
            && candidate.eligibleForRefinement
        let classification: String
        if !diagnosticCompleted {
            classification = invalidClassification
        }
        else if candidateEligible {
            classification = eligibleClassification
        }
        else {
            classification = rejectedClassification
        }
        let verdict = candidateEligible
            ? eligibleVerdict
            : rejectedVerdict
        return MetalStationaryWallBulkCollisionABReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            ledgerCaptureKernel: "captureSymmetricLimiterLedger",
            radialReductionKernel: "reduceSymmetricLimiterRadialBins",
            classification: classification,
            reynoldsNumber: reynoldsNumber,
            latticeFarFieldSpeed: referenceSpeed,
            latticeMachNumber: referenceSpeed / sqrt(1.0 / 3.0),
            diameterCells: diameter,
            domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
            sphereCenterCells: SIMD3<Double>(
                Double(center.x), Double(center.y), Double(center.z)
            ),
            sphereRadiusCells: Double(radius),
            spongeWidthCells: spongeWidth,
            controlMinimumCells: SIMD3<Int>(
                Int(controlMinimum.x),
                Int(controlMinimum.y),
                Int(controlMinimum.z)
            ),
            controlMaximumExclusiveCells: SIMD3<Int>(
                Int(controlMaximum.x),
                Int(controlMaximum.y),
                Int(controlMaximum.z)
            ),
            requestedSteps: requestedSteps,
            requestedConvectiveTimes: requestedConvectiveTimes,
            maximumAllowedRelativeRMSForceResidual:
                maximumRelativeRMSForceResidual,
            maximumAllowedPeakForceResidualRatio:
                maximumPeakForceResidualRatio,
            maximumAllowedCorrectionActivationFraction:
                maximumCorrectionActivationFraction,
            maximumAllowedRelativeCorrection:
                maximumRelativeCorrection,
            maximumAllowedRadialClosureResidual:
                maximumRadialClosureResidual,
            control: control,
            candidate: candidate,
            candidateToControlActivationRatio: activationRatio,
            candidateToControlCorrectionL1Ratio: correctionRatio,
            candidateEligibleForRefinement: candidateEligible,
            gridConvergenceStillRequired: true,
            scientificVerdict: verdict,
            diagnosticCompleted: diagnosticCompleted,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            passed: diagnosticCompleted
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

#if canImport(Metal)
    private static func runStationaryWallBulkCollisionCase(
        collisionOperator: BulkCollisionOperator,
        backend: MetalBackend,
        configuration: MetalTranslatingBodyCaseConfiguration,
        diameter: Int,
        radius: Float,
        referenceSpeed: Double,
        requestedSteps: Int,
        maximumRelativeRMSForceResidual: Double,
        maximumPeakForceResidualRatio: Double,
        maximumCorrectionActivationFraction: Double,
        maximumRelativeCorrection: Double,
        maximumRadialClosureResidual: Double
    ) throws -> MetalStationaryWallBulkCollisionCaseReport {
        let startTime = Date()
        let simulation = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: configuration,
            symmetricPositivityLimiterEnabled:
                collisionOperator == .symmetricLimitedTRT,
            positivityPreservingRegularizedCollisionEnabled:
                collisionOperator
                    == .positivityPreservingRegularizedBGK,
            positivityPreservingRecursiveRegularizedCollisionEnabled:
                collisionOperator
                    == .positivityPreservingRecursiveRegularizedBGK,
            conservationLedgerEnabled: true
        )
        let initial = try simulation.copyPopulations()
        let history = try simulation.run(
            steps: requestedSteps,
            capturePopulationMinimum: true,
            stopOneStepAfterFirstNonFinitePopulation: true,
            captureConservationLedger: true,
            radialCaptureSteps: [requestedSteps]
        )
        let final = try simulation.copyPopulations()
        let base = symmetricLimiterCaseReport(
            limiterEnabled: true,
            requestedSteps: requestedSteps,
            initialPopulations: initial,
            finalPopulations: final,
            history: history,
            cellCount: configuration.grid.cellCount,
            maximumMassDrift: 1.0e-3,
            maximumAbsolutePopulation: 10,
            maximumForceResidual: 5.0e-4,
            maximumRelativeResidual: maximumRelativeRMSForceResidual
        )
        let ledger = conservationLedgerReport(
            history: history,
            initialPopulationMass: base.initialPopulationMass,
            finalPopulationMass: base.finalPopulationMass,
            forceToPhysical: Double(simulation.forceToPhysical)
        )
        let controlExtent = configuration.controlMaximumExclusive
            &- configuration.controlMinimum
        let controlCellCount = Int(controlExtent.x)
            * Int(controlExtent.y) * Int(controlExtent.z)
        var controlActivationCellSteps = 0
        var controlCorrectionL1 = 0.0
        var controlCorrectionL2Squared = 0.0
        var controlCollisionL1 = 0.0
        var controlCollisionL2Squared = 0.0
        for step in history {
            guard let raw = step.conservationLedger else { continue }
            controlActivationCellSteps +=
                raw.controlVolumeActivatedCellCount
            controlCorrectionL1 += raw.limiterControlNorms.x
            controlCorrectionL2Squared += raw.limiterControlNorms.y
            controlCollisionL1 += raw.limiterControlNorms.z
            controlCollisionL2Squared += raw.limiterControlNorms.w
        }
        let controlActivationFraction = Double(
            controlActivationCellSteps
        ) / max(Double(controlCellCount * requestedSteps), 1)
        let relativeControlCorrectionL1 = controlCorrectionL1
            / max(controlCollisionL1, 1.0e-30)
        let relativeControlCorrectionL2 = sqrt(
            max(controlCorrectionL2Squared, 0)
                / max(controlCollisionL2Squared, 1.0e-30)
        )
        let forceDenominator = 0.5 * referenceSpeed * referenceSpeed
            * Double.pi * pow(Double(radius), 2)
        let convectiveWindowSteps = max(
            1,
            Int((Double(diameter) / referenceSpeed).rounded())
        )
        let forceWindow = history.suffix(convectiveWindowSteps)
        let meanForce = forceWindow.reduce(SIMD3<Double>.zero) {
            $0 + doubleVector($1.measuredForce)
        } / Double(max(forceWindow.count, 1))
        let maximumResidualRatio =
            (base.maximumConservativeForceResidual ?? 1)
            / max(base.maximumMeasuredForceMagnitude ?? 0, 1.0e-30)
        let maximumCrossingLinks = history.map {
            $0.solidControlSurfaceCrossingLinkCount
        }.max() ?? 0
        let outsideSponge = ledger.samples.allSatisfy {
            $0.controlVolumeSpongeCellCount == 0
        }

        var radialCaptureCompleted = false
        var maximumRadialClosure = 0.0
        var nearFraction = 0.0
        var farFraction = 0.0
        if history.count == requestedSteps,
           let raw = history.last?.conservationLedger,
           let bins = history.last?.radialLimiterBins
        {
            let radialNorms = bins.reduce(SIMD4<Double>.zero) {
                $0 + $1.norms
            }
            func relativeResidual(_ actual: Double, _ expected: Double)
                -> Double
            {
                abs(actual - expected) / max(abs(expected), 1.0e-30)
            }
            maximumRadialClosure = max(
                relativeResidual(
                    radialNorms.x, raw.limiterControlNorms.x
                ),
                relativeResidual(
                    radialNorms.y, raw.limiterControlNorms.y
                ),
                relativeResidual(
                    radialNorms.z, raw.limiterControlNorms.z
                ),
                relativeResidual(
                    radialNorms.w, raw.limiterControlNorms.w
                )
            )
            let radialActivatedCount = bins.reduce(0) {
                $0 + $1.activatedCellCount
            }
            let totalCorrectionL1 = radialNorms.x
            if totalCorrectionL1 > 0 {
                nearFraction = bins.prefix(3).reduce(0.0) {
                    $0 + $1.norms.x
                } / totalCorrectionL1
                farFraction = bins.dropFirst(5).reduce(0.0) {
                    $0 + $1.norms.x
                } / totalCorrectionL1
            }
            radialCaptureCompleted = bins.count == 8
                && radialActivatedCount
                    == raw.controlVolumeActivatedCellCount
                && maximumRadialClosure
                    <= maximumRadialClosureResidual
        }
        let populationPositivityPassed = history.count == requestedSteps
            && base.firstNegativePopulationStep == nil
            && base.firstNonFinitePopulationStep == nil
            && base.firstNonFiniteLoadStep == nil
            && (base.minimumObservedPopulation ?? -1) > 0
            && base.populationsFinite
            && base.fieldsFinite
            && base.loadsFinite
            && base.newlyCoveredCellEvents == 0
            && base.newlyUncoveredCellEvents == 0
            && base.topologyTransitionSteps == 0
        let controlVolumeIsolationPassed = maximumCrossingLinks == 0
            && outsideSponge
        let sourceClosurePassed = ledger.globalLedgerClosed
            && ledger.relativeCumulativeLimiterMassContribution
                <= 1.0e-6
        let forceBudgetPassed = controlVolumeIsolationPassed
            && (base.conservativeRelativeRMSResidual ?? 1)
                <= maximumRelativeRMSForceResidual
            && maximumResidualRatio <= maximumPeakForceResidualRatio
            && ledger.relativeRMSBoundaryLoadClosureResidual <= 5.0e-5
        let correctionNonIntrusivePassed = controlActivationFraction
                <= maximumCorrectionActivationFraction
            && relativeControlCorrectionL1 <= maximumRelativeCorrection
            && relativeControlCorrectionL2 <= maximumRelativeCorrection
        let eligible = populationPositivityPassed
            && sourceClosurePassed
            && forceBudgetPassed
            && correctionNonIntrusivePassed
            && radialCaptureCompleted
        return MetalStationaryWallBulkCollisionCaseReport(
            operatorName: collisionOperator.name,
            collisionModel: collisionOperator.collisionModel,
            positivityTreatment: collisionOperator.positivityTreatment,
            requestedSteps: requestedSteps,
            completedSteps: history.count,
            completedConvectiveTimes: Double(history.count)
                * referenceSpeed / Double(diameter),
            firstCorrectionStep: base.firstLimiterActivationStep,
            minimumObservedPopulation: base.minimumObservedPopulation,
            minimumCorrectionScale: base.minimumLimiterScale,
            controlVolumeCorrectionActivationCellSteps:
                controlActivationCellSteps,
            controlVolumeCorrectionActivationFraction:
                controlActivationFraction,
            cumulativeControlVolumeCorrectionL1: controlCorrectionL1,
            cumulativeControlVolumeCollisionL1: controlCollisionL1,
            relativeControlVolumeCorrectionL1:
                relativeControlCorrectionL1,
            relativeControlVolumeCorrectionL2:
                relativeControlCorrectionL2,
            finalNearSurfaceCorrectionL1Fraction: nearFraction,
            finalFarFieldCorrectionL1Fraction: farFraction,
            radialCaptureCompleted: radialCaptureCompleted,
            maximumObservedRadialClosureResidual: maximumRadialClosure,
            meanDragCoefficientLastConvectiveTime:
                meanForce.x / forceDenominator,
            conservativeRelativeRMSForceResidual:
                base.conservativeRelativeRMSResidual ?? 1,
            maximumForceBudgetResidualRatio: maximumResidualRatio,
            relativeCumulativeCorrectionMassContribution:
                ledger.relativeCumulativeLimiterMassContribution,
            relativeRMSBoundaryLoadClosureResidual:
                ledger.relativeRMSBoundaryLoadClosureResidual,
            populationPositivityPassed: populationPositivityPassed,
            controlVolumeIsolationPassed:
                controlVolumeIsolationPassed,
            globalLedgerClosed: ledger.globalLedgerClosed,
            forceBudgetPassed: forceBudgetPassed,
            correctionNonIntrusivePassed:
                correctionNonIntrusivePassed,
            eligibleForRefinement: eligible,
            runtimeSeconds: Date().timeIntervalSince(startTime)
        )
    }
#endif

    public static func runStationaryWallRelaxationSweep(
        steps: Int = 500
    ) throws -> MetalStationaryWallRelaxationSweepReport {
        let requestedMargins: [Float] = [
            0.00025,
            0.0005,
            0.001,
            0.002,
            0.005,
            0.01,
            0.0125,
            0.015,
            0.015625,
            0.01625,
            0.016875,
            0.0175,
            0.02,
            0.05,
        ]
        let raw = try runHighReStability(
            steps: steps,
            topologyChanges: false,
            wallMode: .uniform,
            wallSpeed: 0,
            farFieldSpeed: 0.08,
            caseDefinitions: requestedMargins.map { margin in
                // The chord field belongs to the published-condition ladder;
                // sweep reports map this internal placeholder to tau directly.
                (0, margin / 3)
            }
        )
        let points = zip(requestedMargins, raw.cases).map {
            requestedMargin, result in
            let stabilityPassed = result.populationsFinite
                && result.fieldsFinite
                && result.loadsFinite
                && result.finiteLoadSteps == steps
                && result.firstNonFiniteLoadStep == nil
                && result.newlyCoveredCellEvents == 0
                && result.newlyUncoveredCellEvents == 0
                && result.topologyTransitionSteps == 0
                && (result.relativePopulationMassDrift ?? .infinity)
                    <= raw.maximumAllowedRelativePopulationMassDrift
                && (result.maximumAbsolutePopulation ?? .infinity)
                    <= raw.maximumAllowedAbsolutePopulation
            return MetalStationaryWallRelaxationSweepPoint(
                requestedTauPlusMarginAboveHalf: Double(requestedMargin),
                latticeKinematicViscosity:
                    result.latticeKinematicViscosity,
                tauPlus: result.tauPlus,
                tauPlusMarginAboveHalf:
                    result.tauPlusMarginAboveHalf,
                requestedSteps: result.requestedSteps,
                finiteLoadSteps: result.finiteLoadSteps,
                firstNonFiniteLoadStep: result.firstNonFiniteLoadStep,
                relativePopulationMassDrift:
                    result.relativePopulationMassDrift,
                maximumAbsolutePopulation:
                    result.maximumAbsolutePopulation,
                maximumMeasuredForceMagnitude:
                    result.maximumMeasuredForceMagnitude,
                populationsFinite: result.populationsFinite,
                fieldsFinite: result.fieldsFinite,
                loadsFinite: result.loadsFinite,
                newlyCoveredCellEvents: result.newlyCoveredCellEvents,
                newlyUncoveredCellEvents: result.newlyUncoveredCellEvents,
                topologyTransitionSteps: result.topologyTransitionSteps,
                stabilityPassed: stabilityPassed,
                fullAcceptancePassed: result.passed
            )
        }
        let firstStableIndex = points.firstIndex(where: \.stabilityPassed)
        let firstUpperStable = firstStableIndex.map {
            points[$0].tauPlusMarginAboveHalf
        }
        let firstLowerUnstable = firstStableIndex.flatMap { index in
            index > 0 ? points[index - 1].tauPlusMarginAboveHalf : nil
        }
        let firstBracketWidth: Double?
        if let firstLowerUnstable, let firstUpperStable {
            firstBracketWidth = firstUpperStable - firstLowerUnstable
        } else {
            firstBracketWidth = nil
        }
        let firstTransitionBracketed = firstLowerUnstable != nil
            && firstUpperStable != nil
        let unstableAfterFirstStable = firstStableIndex.map { index in
            points.suffix(from: index + 1).filter {
                !$0.stabilityPassed
            }.map(\.tauPlusMarginAboveHalf)
        } ?? []
        let monotonic = unstableAfterFirstStable.isEmpty
        let thresholdBracketed = firstTransitionBracketed && monotonic
        let diagnosticCompleted = points.count == requestedMargins.count
            && points.allSatisfy { point in
                point.newlyCoveredCellEvents == 0
                    && point.newlyUncoveredCellEvents == 0
                    && point.topologyTransitionSteps == 0
                    && (point.stabilityPassed
                        ? point.finiteLoadSteps == steps
                        : point.firstNonFiniteLoadStep != nil)
            }
        let classification: String
        let verdict: String
        if !monotonic {
            classification = "stationary-wall-relaxation-stability-nonmonotonic"
            verdict = "The active stationary-sphere 500-step outcome is non-monotonic with relaxation margin. A stable point is followed by a reproducible unstable point, so viscosity-only tuning does not define a robust critical threshold."
        } else if thresholdBracketed {
            classification = "stationary-wall-relaxation-threshold-bracketed"
            verdict = "The active stationary-sphere 500-step stability threshold is bracketed between the first adjacent unstable and stable tauPlus margins."
        } else {
            classification = "stationary-wall-relaxation-threshold-not-bracketed"
            verdict = "The requested stationary-sphere relaxation sweep did not bracket a 500-step stability transition."
        }
        return MetalStationaryWallRelaxationSweepReport(
            schemaVersion: 1,
            deviceName: raw.deviceName,
            productionKernel: raw.productionKernel,
            topologyKernel: raw.topologyKernel,
            domainCells: raw.domainCells,
            sphereRadiusCells: raw.sphereRadiusCells,
            farFieldVelocityLattice: raw.farFieldVelocityLattice,
            wallVelocityLattice: raw.wallVelocityLattice,
            periodicBoundaries: raw.periodicBoundaries,
            spongeStrength: raw.spongeStrength,
            requestedStepsPerPoint: steps,
            runtimeSeconds: raw.runtimeSeconds,
            firstTransitionLowerUnstableTauPlusMarginAboveHalf:
                firstLowerUnstable,
            firstTransitionUpperStableTauPlusMarginAboveHalf:
                firstUpperStable,
            firstTransitionBracketWidth: firstBracketWidth,
            firstTransitionBracketed: firstTransitionBracketed,
            stabilityMonotonicWithMargin: monotonic,
            unstableTauPlusMarginsAfterFirstStable:
                unstableAfterFirstStable,
            thresholdBracketed: thresholdBracketed,
            classification: classification,
            scientificVerdict: verdict,
            points: points,
            diagnosticCompleted: diagnosticCompleted
        )
    }

    public static func runStationaryWallLongHorizonSurvival(
        steps: Int = 1_000
    ) throws -> MetalStationaryWallLongHorizonSurvivalReport {
        guard steps == 1_000 else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "stationary-wall long-horizon survival uses a locked 1000-step contract"
            )
        }
        let requestedMargins: [Float] = [0.015625, 0.016875, 0.02]
        let raw = try runHighReStability(
            steps: steps,
            topologyChanges: false,
            wallMode: .uniform,
            wallSpeed: 0,
            farFieldSpeed: 0.08,
            caseDefinitions: requestedMargins.map { margin in
                (0, margin / 3)
            }
        )
        let points = zip(requestedMargins, raw.cases).map {
            requestedMargin, result in
            let stabilityPassed = result.populationsFinite
                && result.fieldsFinite
                && result.loadsFinite
                && result.finiteLoadSteps == steps
                && result.firstNonFiniteLoadStep == nil
                && result.newlyCoveredCellEvents == 0
                && result.newlyUncoveredCellEvents == 0
                && result.topologyTransitionSteps == 0
                && (result.relativePopulationMassDrift ?? .infinity)
                    <= raw.maximumAllowedRelativePopulationMassDrift
                && (result.maximumAbsolutePopulation ?? .infinity)
                    <= raw.maximumAllowedAbsolutePopulation
            return MetalStationaryWallRelaxationSweepPoint(
                requestedTauPlusMarginAboveHalf: Double(requestedMargin),
                latticeKinematicViscosity:
                    result.latticeKinematicViscosity,
                tauPlus: result.tauPlus,
                tauPlusMarginAboveHalf:
                    result.tauPlusMarginAboveHalf,
                requestedSteps: result.requestedSteps,
                finiteLoadSteps: result.finiteLoadSteps,
                firstNonFiniteLoadStep: result.firstNonFiniteLoadStep,
                relativePopulationMassDrift:
                    result.relativePopulationMassDrift,
                maximumAbsolutePopulation:
                    result.maximumAbsolutePopulation,
                maximumMeasuredForceMagnitude:
                    result.maximumMeasuredForceMagnitude,
                populationsFinite: result.populationsFinite,
                fieldsFinite: result.fieldsFinite,
                loadsFinite: result.loadsFinite,
                newlyCoveredCellEvents: result.newlyCoveredCellEvents,
                newlyUncoveredCellEvents: result.newlyUncoveredCellEvents,
                topologyTransitionSteps: result.topologyTransitionSteps,
                stabilityPassed: stabilityPassed,
                fullAcceptancePassed: result.passed
            )
        }
        let survivingCount = points.filter(\.stabilityPassed).count
        let allSurvived = survivingCount == points.count
        let diagnosticCompleted = points.count == requestedMargins.count
            && points.allSatisfy { point in
                point.newlyCoveredCellEvents == 0
                    && point.newlyUncoveredCellEvents == 0
                    && point.topologyTransitionSteps == 0
                    && (point.stabilityPassed
                        ? point.finiteLoadSteps == steps
                        : point.firstNonFiniteLoadStep != nil)
            }
        let classification: String
        let verdict: String
        if allSurvived {
            classification = "stationary-wall-apparent-stability-survives-1000"
            verdict = "All selected points above the corrected 500-step monotonic stability threshold remain finite for 1000 steps. They still require force-budget acceptance before promotion."
        } else if survivingCount == 0 {
            classification = "stationary-wall-500-step-stability-horizon-censored"
            verdict = "Every apparent 500-step stability point becomes non-finite before 1000 steps. The earlier islands were delayed divergence censored by the shorter horizon."
        } else {
            classification = "stationary-wall-long-horizon-stability-mixed"
            verdict = "Only part of the apparent 500-step stability band survives to 1000 steps. Retain only the surviving margins as candidates for longer validation."
        }
        return MetalStationaryWallLongHorizonSurvivalReport(
            schemaVersion: 1,
            deviceName: raw.deviceName,
            productionKernel: raw.productionKernel,
            topologyKernel: raw.topologyKernel,
            domainCells: raw.domainCells,
            sphereRadiusCells: raw.sphereRadiusCells,
            farFieldVelocityLattice: raw.farFieldVelocityLattice,
            wallVelocityLattice: raw.wallVelocityLattice,
            periodicBoundaries: raw.periodicBoundaries,
            spongeStrength: raw.spongeStrength,
            requestedStepsPerPoint: steps,
            runtimeSeconds: raw.runtimeSeconds,
            survivingPointCount: survivingCount,
            allApparentStablePointsSurvived: allSurvived,
            classification: classification,
            scientificVerdict: verdict,
            points: points,
            diagnosticCompleted: diagnosticCompleted
        )
    }

    public static func runHighReFixedOccupancyWallDecomposition(
        steps: Int = 500
    ) throws -> MetalHighReFixedOccupancyWallDecompositionReport {
        let startTime = Date()
        let tangential = try runHighReStability(
            steps: steps,
            topologyChanges: false,
            wallMode: .tangential
        )
        let normal = try runHighReStability(
            steps: steps,
            topologyChanges: false,
            wallMode: .normal
        )
        let diagnosticCompleted = [tangential, normal].allSatisfy {
            !$0.topologyChanges
                && $0.cases.count == 3
                && $0.cases.allSatisfy { result in
                    result.newlyCoveredCellEvents == 0
                        && result.newlyUncoveredCellEvents == 0
                        && result.topologyTransitionSteps == 0
                        && (result.passed
                            ? result.finiteLoadSteps == result.requestedSteps
                            : result.firstNonFiniteLoadStep != nil)
                }
        }
        let classification: String
        let verdict: String
        switch (tangential.passed, normal.passed) {
        case (true, false):
            classification = "normal-moving-wall-instability-confirmed"
            verdict = "Tangential-only curved moving-wall exchange remains finite while normal-only exchange becomes non-finite. Stabilize the normal moving-boundary reconstruction before another bird replay."
        case (false, true):
            classification = "tangential-curved-link-instability-confirmed"
            verdict = "Normal-only exchange remains finite while tangential-only curved moving-wall exchange becomes non-finite. Stabilize curved tangential link exchange before another bird replay."
        case (false, false):
            classification = "general-curved-moving-link-instability-confirmed"
            verdict = "Both normal-only and tangential-only fixed-sphere cases become non-finite. The low-relaxation curved moving-link interaction is general rather than confined to one wall-velocity component."
        case (true, true):
            classification = "mixed-wall-component-coupling-suspect"
            verdict = "Normal-only and tangential-only cases remain finite separately, while the uniform combined case fails. Isolate mixed-component coupling in the moving-wall reconstruction."
        }
        return MetalHighReFixedOccupancyWallDecompositionReport(
            schemaVersion: 1,
            deviceName: tangential.deviceName,
            productionKernel: tangential.productionKernel,
            topologyKernel: tangential.topologyKernel,
            requestedStepsPerComponent: steps,
            maximumWallVelocityLattice: tangential.wallVelocityLattice,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            tangential: tangential,
            normal: normal,
            classification: classification,
            scientificVerdict: verdict,
            diagnosticCompleted: diagnosticCompleted
        )
    }

    private static func runHighReStability(
        steps: Int,
        topologyChanges: Bool,
        wallMode: HighReSphereWallMode,
        wallSpeed: Float = 0.08,
        farFieldSpeed: Float = 0,
        caseDefinitions: [(Int, Float)]? = nil
    ) throws -> MetalHighReTranslatingBodyStabilityReport {
        let isLockedLongHorizon = steps == 1_000
            && !topologyChanges
            && wallSpeed == 0
            && farFieldSpeed == 0.08
            && caseDefinitions != nil
        guard steps == 500 || isLockedLongHorizon else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "high-Re stability uses a locked 500-step contract except for the stationary-wall 1000-step survival audit"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let domain = try GridSize(x: 56, y: 24, z: 24)
        let referenceSpeed = max(wallSpeed, farFieldSpeed)
        let geometrySpeed: Float = topologyChanges ? wallSpeed : 0
        let maximumMassDrift = 1.0e-3
        let maximumAbsolutePopulation = 10.0
        let maximumForceResidual = 5.0e-4
        let maximumRelativeResidual = 5.0e-3
        let matchedViscosities = caseDefinitions ?? [
            (8, 4.382_427_9e-5),
            (12, 6.582_454_1e-5),
            (16, 8.782_491_2e-5),
        ]
        let cases = try matchedViscosities.map { chordCells, viscosity in
            let caseConfiguration = MetalTranslatingBodyCaseConfiguration(
                grid: domain,
                sphereRadiusCells: Float(sphereRadiusCells),
                referenceSpeedLattice: referenceSpeed,
                geometryTranslationSpeedLattice: geometrySpeed,
                wallVelocityLattice: wallSpeed,
                wallVelocityMode: wallMode.rawValue,
                initialFluidVelocityLattice: farFieldSpeed,
                periodicBoundaries: farFieldSpeed == 0,
                spongeStrength: farFieldSpeed > 0 ? 0.04 : 0,
                latticeKinematicViscosity: viscosity,
                initialCenter: SIMD3<Float>(8, 12, 12),
                controlMinimum: SIMD3<UInt32>(2, 2, 2),
                controlMaximumExclusive: SIMD3<UInt32>(54, 22, 22)
            )
            let simulation = try MetalTranslatingBodyTopologySimulation(
                backend: backend,
                linkForceMode: 6,
                caseConfiguration: caseConfiguration
            )
            let initialPopulations = try simulation.copyPopulations()
            let initialMass = initialPopulations.reduce(0.0) {
                $0 + Double($1)
            }
            let history = try simulation.run(steps: steps)
            let finalPopulations = try simulation.copyPopulations()
            let populationsFinite = finalPopulations.allSatisfy(\.isFinite)
            let fieldsFinite = populationsFinite
                && macroscopicFieldsAreFinite(
                    populations: finalPopulations,
                    cellCount: domain.cellCount
                )
            let firstInvalidIndex = history.firstIndex {
                !vectorIsFinite($0.measuredForce)
                    || !vectorIsFinite($0.rawBudgetForce)
            }
            let loadsFinite = firstInvalidIndex == nil
            let finiteLoadSteps = firstInvalidIndex ?? history.count
            let finalMassValue = finalPopulations.reduce(0.0) {
                $0 + Double($1)
            }
            let finalMass = populationsFinite ? finalMassValue : nil
            let massDrift = finalMass.map {
                abs($0 - initialMass) / max(abs(initialMass), 1.0e-30)
            }
            let minimum = populationsFinite
                ? finalPopulations.min().map(Double.init)
                : nil
            let maximum = populationsFinite
                ? finalPopulations.max().map(Double.init)
                : nil
            let maximumAbsolute = populationsFinite
                ? finalPopulations.lazy.map { abs(Double($0)) }.max()
                : nil
            let finiteHistory = history.prefix(finiteLoadSteps)
            let residuals = finiteHistory.map {
                doubleVector($0.measuredForce - $0.rawBudgetForce)
            }
            let rawForces = finiteHistory.map {
                doubleVector($0.rawBudgetForce)
            }
            let measuredForces = finiteHistory.map {
                doubleVector($0.measuredForce)
            }
            let residualSquared = residuals.reduce(0.0) {
                $0 + squaredMagnitude($1)
            }
            let budgetSquared = rawForces.reduce(0.0) {
                $0 + squaredMagnitude($1)
            }
            let rmsResidual = residuals.isEmpty
                ? nil
                : sqrt(residualSquared / Double(residuals.count))
            let maximumResidual = residuals.map(magnitude).max()
            let relativeResidual = residuals.isEmpty
                ? nil
                : sqrt(residualSquared / max(budgetSquared, 1.0e-30))
            let rawBudgetRMS = rawForces.isEmpty
                ? nil
                : sqrt(budgetSquared / Double(rawForces.count))
            let maximumMeasuredForce = measuredForces.map(magnitude).max()
            // A relative residual is undefined as a useful acceptance metric
            // when the independent budget signal is below the locked absolute
            // residual tolerance. In that regime, retain the absolute gate and
            // report that the relative gate was intentionally not applied.
            let relativeResidualGateApplied =
                (rawBudgetRMS ?? .infinity) > maximumForceResidual
            let coveredEvents = history.reduce(0) {
                $0 + $1.newlyCoveredCells
            }
            let uncoveredEvents = history.reduce(0) {
                $0 + $1.newlyUncoveredCells
            }
            let transitionSteps = history.reduce(0) {
                $0 + (($1.newlyCoveredCells > 0
                    || $1.newlyUncoveredCells > 0) ? 1 : 0)
            }
            let maximumSurfaceLinks = history.map(
                \.solidControlSurfaceCrossingLinkCount
            ).max() ?? 0
            let tauPlus = simulation.tauPlus
            let passed = loadsFinite
                && populationsFinite
                && fieldsFinite
                && (topologyChanges
                    ? coveredEvents > 0
                        && uncoveredEvents > 0
                        && transitionSteps > 0
                    : coveredEvents == 0
                        && uncoveredEvents == 0
                        && transitionSteps == 0)
                && maximumSurfaceLinks == 0
                && (massDrift ?? .infinity) <= maximumMassDrift
                && (maximumAbsolute ?? .infinity)
                    <= maximumAbsolutePopulation
                && (maximumResidual ?? .infinity) <= maximumForceResidual
                && (!relativeResidualGateApplied
                    || (relativeResidual ?? .infinity)
                        <= maximumRelativeResidual)

            return MetalHighReTranslatingBodyCaseResult(
                matchedBirdChordCells: chordCells,
                latticeKinematicViscosity:
                    Double(simulation.latticeKinematicViscosity),
                tauPlus: Double(tauPlus),
                tauPlusMarginAboveHalf: Double(tauPlus - 0.5),
                requestedSteps: steps,
                finiteLoadSteps: finiteLoadSteps,
                firstNonFiniteLoadStep: firstInvalidIndex.map { $0 + 1 },
                initialPopulationMass: initialMass,
                finalPopulationMass: finalMass,
                relativePopulationMassDrift: massDrift,
                minimumPopulation: minimum,
                maximumPopulation: maximum,
                maximumAbsolutePopulation: maximumAbsolute,
                populationsFinite: populationsFinite,
                fieldsFinite: fieldsFinite,
                loadsFinite: loadsFinite,
                newlyCoveredCellEvents: coveredEvents,
                newlyUncoveredCellEvents: uncoveredEvents,
                topologyTransitionSteps: transitionSteps,
                maximumSolidControlSurfaceCrossingLinkCount:
                    maximumSurfaceLinks,
                conservativeRMSForceResidual: rmsResidual,
                maximumConservativeForceResidual: maximumResidual,
                conservativeRelativeRMSResidual: relativeResidual,
                rawBudgetRMSForceMagnitude: rawBudgetRMS,
                maximumMeasuredForceMagnitude: maximumMeasuredForce,
                relativeResidualGateApplied: relativeResidualGateApplied,
                passed: passed
            )
        }
        let passed = cases.allSatisfy(\.passed)
        let classification: String
        let verdict: String
        if farFieldSpeed > 0, wallSpeed == 0 {
            classification = passed
                ? "high-re-stationary-wall-sphere-stable-moving-wall-correction-isolated"
                : "high-re-stationary-wall-sphere-unstable-general-curved-link-path-confirmed"
            verdict = passed
                ? "Matched high-Re TRT remains finite on a stationary curved sphere in uniform flow. The moving-wall population correction is the remaining destabilizing difference from the failed fixed-occupancy moving-wall cases."
                : "Matched high-Re TRT becomes non-finite on a stationary curved sphere in uniform flow. The instability is general to curved halfway-link bounce-back and low-relaxation collision rather than requiring the moving-wall population correction."
        } else if topologyChanges {
            classification = passed
                ? "high-re-cell-crossing-stable-deforming-interpolation-path-suspect"
                : "high-re-cell-crossing-unstable-moving-boundary-path-confirmed"
            verdict = passed
                ? "Matched high-Re TRT remains finite and momentum-consistent across cell cover and uncover transitions. Isolate deforming measured-surface interpolation before another bird replay."
                : "Matched high-Re TRT fails when a translating sphere and cell cover and uncover transitions are added to the fixed-wall case. Run a fixed-occupancy moving-wall sphere to separate curved-link reconstruction from topology refill before another bird replay."
        } else if wallMode == .uniform {
            classification = passed
                ? "high-re-fixed-occupancy-sphere-stable-topology-refill-path-confirmed"
                : "high-re-fixed-occupancy-sphere-unstable-curved-normal-wall-path-confirmed"
            verdict = passed
                ? "Matched high-Re TRT remains finite and momentum-consistent on a fixed-occupancy curved halfway-link sphere. Cell cover, uncover, and refill are isolated as the remaining difference from the failed translating sphere."
                : "Matched high-Re TRT fails on a fixed-occupancy curved halfway-link sphere under uniform translational wall velocity, which includes a normal component. This curved normal-wall stress is sufficient without cell cover, uncover, or refill."
        } else {
            classification = passed
                ? "high-re-fixed-occupancy-\(wallMode.name)-stable"
                : "high-re-fixed-occupancy-\(wallMode.name)-unstable"
            verdict = passed
                ? "The fixed-occupancy \(wallMode.name) curved-sphere case remains finite at all three matched relaxation margins."
                : "The fixed-occupancy \(wallMode.name) curved-sphere case becomes non-finite at one or more matched relaxation margins."
        }
        return MetalHighReTranslatingBodyStabilityReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            topologyKernel: "buildTranslatingSphereTopology",
            topologyChanges: topologyChanges,
            periodicBoundaries: farFieldSpeed == 0,
            spongeStrength: farFieldSpeed > 0 ? 0.04 : 0,
            domainCells: SIMD3<Int>(domain.x, domain.y, domain.z),
            sphereRadiusCells: sphereRadiusCells,
            translationSpeedLattice: Double(geometrySpeed),
            wallVelocityLattice: Double(wallSpeed),
            wallVelocityMode: wallSpeed == 0 ? "stationary" : wallMode.name,
            farFieldVelocityLattice: Double(farFieldSpeed),
            requestedSteps: steps,
            displacementCells: Double(geometrySpeed) * Double(steps),
            runtimeSeconds: Date().timeIntervalSince(startTime),
            maximumAllowedRelativePopulationMassDrift: maximumMassDrift,
            maximumAllowedAbsolutePopulation: maximumAbsolutePopulation,
            maximumAllowedConservativeForceResidual: maximumForceResidual,
            maximumAllowedConservativeRelativeRMSResidual:
                maximumRelativeResidual,
            classification: classification,
            scientificVerdict: verdict,
            cases: cases,
            passed: passed
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func run(
        captureMacroscopicFields: Bool = false
    ) throws
        -> MetalTranslatingBodyTopologyValidationReport
    {
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let caseConfiguration = try MetalTranslatingBodyCaseConfiguration
            .standard()
        let legacy = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 0,
            caseConfiguration: caseConfiguration,
            captureMacroscopicFields: captureMacroscopicFields
        ).run(steps: steps)
        let conservative = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: caseConfiguration,
            captureMacroscopicFields: captureMacroscopicFields
        ).run(steps: steps)
        guard legacy.count == conservative.count,
              conservative.count == steps else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "estimator histories did not contain the requested steps"
            )
        }

        var samples: [MetalTranslatingBodyTopologySample] = []
        samples.reserveCapacity(steps)
        var legacyResidualSquared = 0.0
        var conservativeResidualSquared = 0.0
        var budgetSquared = 0.0
        var maximumLegacyResidual = 0.0
        var maximumConservativeResidual = 0.0
        var maximumBudgetDifference = 0.0
        var rawBudgetMeanX = 0.0
        var legacyMeanX = 0.0
        var conservativeMeanX = 0.0
        var coveredEvents = 0
        var uncoveredEvents = 0
        var transitionSteps = 0
        var maximumSurfaceLinks = 0

        for index in 0..<steps {
            let legacyStep = legacy[index]
            let conservativeStep = conservative[index]
            let raw = doubleVector(conservativeStep.rawBudgetForce)
            let legacyForce = doubleVector(legacyStep.measuredForce)
            let conservativeForce = doubleVector(
                conservativeStep.measuredForce
            )
            let legacyResidual = legacyForce - raw
            let conservativeResidual = conservativeForce - raw
            let legacyMagnitude = magnitude(legacyResidual)
            let conservativeMagnitude = magnitude(conservativeResidual)
            let budgetDifference = magnitude(
                doubleVector(legacyStep.rawBudgetForce) - raw
            )

            legacyResidualSquared += squaredMagnitude(legacyResidual)
            conservativeResidualSquared += squaredMagnitude(
                conservativeResidual
            )
            budgetSquared += squaredMagnitude(raw)
            maximumLegacyResidual = max(
                maximumLegacyResidual,
                legacyMagnitude
            )
            maximumConservativeResidual = max(
                maximumConservativeResidual,
                conservativeMagnitude
            )
            maximumBudgetDifference = max(
                maximumBudgetDifference,
                budgetDifference
            )
            rawBudgetMeanX += raw.x
            legacyMeanX += legacyForce.x
            conservativeMeanX += conservativeForce.x
            coveredEvents += conservativeStep.newlyCoveredCells
            uncoveredEvents += conservativeStep.newlyUncoveredCells
            if conservativeStep.newlyCoveredCells > 0
                || conservativeStep.newlyUncoveredCells > 0 {
                transitionSteps += 1
            }
            maximumSurfaceLinks = max(
                maximumSurfaceLinks,
                conservativeStep.solidControlSurfaceCrossingLinkCount
            )

            samples.append(MetalTranslatingBodyTopologySample(
                step: index + 1,
                newlyCoveredCells: conservativeStep.newlyCoveredCells,
                newlyUncoveredCells: conservativeStep.newlyUncoveredCells,
                solidControlSurfaceCrossingLinkCount:
                    conservativeStep.solidControlSurfaceCrossingLinkCount,
                rawBudgetForceX: raw.x,
                rawBudgetForceY: raw.y,
                rawBudgetForceZ: raw.z,
                legacyForceX: legacyForce.x,
                legacyForceY: legacyForce.y,
                legacyForceZ: legacyForce.z,
                conservativeForceX: conservativeForce.x,
                conservativeForceY: conservativeForce.y,
                conservativeForceZ: conservativeForce.z,
                legacyResidualMagnitude: legacyMagnitude,
                conservativeResidualMagnitude: conservativeMagnitude
            ))
        }

        let divisor = Double(steps)
        let legacyRMS = sqrt(legacyResidualSquared / divisor)
        let conservativeRMS = sqrt(
            conservativeResidualSquared / divisor
        )
        let relativeRMS = sqrt(
            conservativeResidualSquared / max(budgetSquared, 1.0e-30)
        )
        let improvement = legacyRMS / max(conservativeRMS, 1.0e-30)
        let passed = coveredEvents > 0
            && uncoveredEvents > 0
            && transitionSteps > 0
            && maximumSurfaceLinks == 0
            && maximumConservativeResidual
                <= maximumConservativeForceResidual
            && relativeRMS <= maximumConservativeRelativeRMSResidual
            && improvement >= minimumImprovementFactor
            && maximumBudgetDifference <= maximumRawBudgetDifference

        return MetalTranslatingBodyTopologyValidationReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            topologyKernel: "buildTranslatingSphereTopology",
            passed: passed,
            gridResolution: gridResolution,
            sphereRadiusCells: sphereRadiusCells,
            translationSpeedLattice: translationSpeedLattice,
            steps: steps,
            displacementCells: translationSpeedLattice * Double(steps),
            newlyCoveredCellEvents: coveredEvents,
            newlyUncoveredCellEvents: uncoveredEvents,
            topologyTransitionSteps: transitionSteps,
            maximumSolidControlSurfaceCrossingLinkCount:
                maximumSurfaceLinks,
            rawBudgetMeanForceX: rawBudgetMeanX / divisor,
            legacyMeanForceX: legacyMeanX / divisor,
            conservativeMeanForceX: conservativeMeanX / divisor,
            legacyRMSForceResidual: legacyRMS,
            conservativeRMSForceResidual: conservativeRMS,
            maximumLegacyForceResidual: maximumLegacyResidual,
            maximumConservativeForceResidual:
                maximumConservativeResidual,
            conservativeRelativeRMSResidual: relativeRMS,
            conservativeImprovementFactor: improvement,
            maximumRawBudgetDifferenceBetweenRuns: maximumBudgetDifference,
            maximumAllowedConservativeForceResidual:
                maximumConservativeForceResidual,
            maximumAllowedConservativeRelativeRMSResidual:
                maximumConservativeRelativeRMSResidual,
            minimumRequiredImprovementFactor: minimumImprovementFactor,
            maximumAllowedRawBudgetDifferenceBetweenRuns:
                maximumRawBudgetDifference,
            samples: samples
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

#if canImport(Metal)
    private static func collisionTerms(
        _ capture: MetalTRTCollisionCapture,
        targetCell: SIMD3<Int>
    ) -> [MetalStationaryWallTRTCollisionDirectionTerm] {
        capture.terms.map { raw in
            let q = Int(raw.metadata.x)
            let lattice = D3Q19.directions[q]
            let direction = SIMD3<Int>(
                Int(lattice.x),
                Int(lattice.y),
                Int(lattice.z)
            )
            let source = SIMD3<Int>(
                targetCell.x - direction.x,
                targetCell.y - direction.y,
                targetCell.z - direction.z
            )
            let pulled = Double(raw.values0.x)
            let symmetricIncrement = Double(raw.values1.x)
            let antisymmetricIncrement = Double(raw.values1.y)
            let predicted = Double(raw.values1.z)
            let actual = Double(raw.values1.w)
            return MetalStationaryWallTRTCollisionDirectionTerm(
                directionIndex: q,
                latticeDirection: direction,
                pullSourceCell: source,
                pullSourceInsideDomain: raw.metadata.w == 0,
                pullSourceIsSolid: raw.metadata.z != 0,
                pulledPopulation: pulled,
                equilibriumPopulation: Double(raw.values0.y),
                symmetricNonequilibrium: Double(raw.values0.z),
                antisymmetricNonequilibrium: Double(raw.values0.w),
                symmetricRelaxationIncrement: symmetricIncrement,
                antisymmetricRelaxationIncrement:
                    antisymmetricIncrement,
                postWithoutSymmetricIncrement:
                    pulled + antisymmetricIncrement,
                postWithoutAntisymmetricIncrement:
                    pulled + symmetricIncrement,
                predictedPostCollision: predicted,
                actualPostCollision: actual,
                predictionResidual: actual - predicted
            )
        }.sorted { $0.directionIndex < $1.directionIndex }
    }

    private static func boundaryInterpolationComponent(
        _ raw: GPUTRTCollisionTerm,
        domain: GridSize
    ) -> MetalStationaryWallBoundaryInterpolationComponent {
        let branchCode = Int(raw.boundaryMetadata.y)
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
            branch = "not-a-boundary-link"
            auxiliaryRole = "none"
        }
        let auxiliaryCell: SIMD3<Int>?
        let auxiliaryIndex = raw.boundaryMetadata.z
        if auxiliaryIndex == UInt32.max {
            auxiliaryCell = nil
        } else {
            let index = Int(auxiliaryIndex)
            auxiliaryCell = SIMD3<Int>(
                index % domain.x,
                (index / domain.x) % domain.y,
                index / (domain.x * domain.y)
            )
        }
        let contributions = [
            ("reflected", Double(raw.boundaryContributions.x)),
            ("auxiliary", Double(raw.boundaryContributions.y)),
            ("wall-correction", Double(raw.boundaryContributions.z)),
        ]
        let dominantNegative = contributions.min {
            $0.1 < $1.1
        }.map { $0.1 < 0 ? $0.0 : "none" } ?? "none"
        let reconstructed = Double(raw.boundaryContributions.w)
        let contributionSum = contributions.reduce(0.0) {
            $0 + $1.1
        }
        return MetalStationaryWallBoundaryInterpolationComponent(
            directionIndex: Int(raw.metadata.x),
            branch: branch,
            linkFraction: Double(raw.boundaryValues0.y),
            reflectedPopulation: Double(raw.boundaryValues0.x),
            auxiliaryPopulation: Double(raw.boundaryValues0.z),
            auxiliaryCell: auxiliaryCell,
            auxiliaryRole: auxiliaryRole,
            wallCorrection: Double(raw.boundaryValues0.w),
            reflectedContribution: Double(raw.boundaryContributions.x),
            auxiliaryContribution: Double(raw.boundaryContributions.y),
            wallCorrectionContribution:
                Double(raw.boundaryContributions.z),
            reconstructedPopulation: reconstructed,
            contributionClosureResidual: reconstructed - contributionSum,
            dominantNegativeContribution: dominantNegative
        )
    }

    private static func conservationLedgerReport(
        history: [MetalTranslatingBodyTopologyStep],
        initialPopulationMass: Double,
        finalPopulationMass: Double?,
        forceToPhysical: Double
    ) -> MetalStationaryWallConservationLedgerReport {
        var samples: [MetalStationaryWallConservationLedgerSample] = []
        samples.reserveCapacity(history.count)
        var observed = SIMD4<Double>.zero
        var boundary = SIMD4<Double>.zero
        var farField = SIMD4<Double>.zero
        var collision = SIMD4<Double>.zero
        var limiter = SIMD4<Double>.zero
        var sponge = SIMD4<Double>.zero
        var collisionControl = SIMD4<Double>.zero
        var limiterControl = SIMD4<Double>.zero
        var spongeControl = SIMD4<Double>.zero
        var closure = SIMD4<Double>.zero
        var maximumMassClosure = 0.0
        var maximumMomentumClosure = 0.0
        var maximumLimiterMass = 0.0
        var maximumLimiterMomentum = 0.0
        var maximumForceResidual = 0.0
        var maximumAttributedSource = 0.0
        var maximumUnexplainedForce = 0.0
        var maximumBoundaryLoadClosure = 0.0
        var forceResidualSquared = 0.0
        var attributedSourceSquared = 0.0
        var unexplainedSquared = 0.0
        var boundaryLoadClosureSquared = 0.0
        var measuredForceSquared = 0.0
        var collisionControlSquared = 0.0
        var limiterControlSquared = 0.0
        var spongeControlSquared = 0.0

        for (index, step) in history.enumerated() {
            guard let raw = step.conservationLedger else { continue }
            let accounted = raw.boundaryGlobal
                + raw.farFieldGlobal
                + raw.collisionGlobal
                + raw.limiterGlobal
                + raw.spongeGlobal
            let stepClosure = raw.observedGlobal - accounted
            let forceResidual = doubleVector(
                step.measuredForce - step.rawBudgetForce
            )
            let controlSource = raw.collisionControl
                + raw.limiterControl
                + raw.spongeControl
            let attributedSourceForce = SIMD3<Double>(
                controlSource.y * forceToPhysical,
                controlSource.z * forceToPhysical,
                controlSource.w * forceToPhysical
            )
            let unexplainedForce = forceResidual - attributedSourceForce
            let boundaryFluidMomentumForce = SIMD3<Double>(
                raw.boundaryGlobal.y * forceToPhysical,
                raw.boundaryGlobal.z * forceToPhysical,
                raw.boundaryGlobal.w * forceToPhysical
            )
            let measuredForce = doubleVector(step.measuredForce)
            let boundaryLoadClosure = measuredForce
                + boundaryFluidMomentumForce
            let collisionControlForce = SIMD3<Double>(
                raw.collisionControl.y * forceToPhysical,
                raw.collisionControl.z * forceToPhysical,
                raw.collisionControl.w * forceToPhysical
            )
            let limiterControlForce = SIMD3<Double>(
                raw.limiterControl.y * forceToPhysical,
                raw.limiterControl.z * forceToPhysical,
                raw.limiterControl.w * forceToPhysical
            )
            let spongeControlForce = SIMD3<Double>(
                raw.spongeControl.y * forceToPhysical,
                raw.spongeControl.z * forceToPhysical,
                raw.spongeControl.w * forceToPhysical
            )

            observed += raw.observedGlobal
            boundary += raw.boundaryGlobal
            farField += raw.farFieldGlobal
            collision += raw.collisionGlobal
            limiter += raw.limiterGlobal
            sponge += raw.spongeGlobal
            collisionControl += raw.collisionControl
            limiterControl += raw.limiterControl
            spongeControl += raw.spongeControl
            closure += stepClosure
            maximumMassClosure = max(
                maximumMassClosure,
                abs(stepClosure.x)
            )
            maximumMomentumClosure = max(
                maximumMomentumClosure,
                magnitude(SIMD3<Double>(
                    stepClosure.y,
                    stepClosure.z,
                    stepClosure.w
                ))
            )
            maximumLimiterMass = max(
                maximumLimiterMass,
                abs(raw.limiterGlobal.x)
            )
            maximumLimiterMomentum = max(
                maximumLimiterMomentum,
                magnitude(SIMD3<Double>(
                    raw.limiterGlobal.y,
                    raw.limiterGlobal.z,
                    raw.limiterGlobal.w
                ))
            )
            maximumForceResidual = max(
                maximumForceResidual,
                magnitude(forceResidual)
            )
            maximumAttributedSource = max(
                maximumAttributedSource,
                magnitude(attributedSourceForce)
            )
            maximumUnexplainedForce = max(
                maximumUnexplainedForce,
                magnitude(unexplainedForce)
            )
            maximumBoundaryLoadClosure = max(
                maximumBoundaryLoadClosure,
                magnitude(boundaryLoadClosure)
            )
            forceResidualSquared += squaredMagnitude(forceResidual)
            attributedSourceSquared += squaredMagnitude(
                attributedSourceForce
            )
            unexplainedSquared += squaredMagnitude(unexplainedForce)
            boundaryLoadClosureSquared += squaredMagnitude(
                boundaryLoadClosure
            )
            measuredForceSquared += squaredMagnitude(measuredForce)
            collisionControlSquared += squaredMagnitude(
                collisionControlForce
            )
            limiterControlSquared += squaredMagnitude(limiterControlForce)
            spongeControlSquared += squaredMagnitude(spongeControlForce)

            samples.append(MetalStationaryWallConservationLedgerSample(
                step: index + 1,
                activatedCellCount: raw.activatedCellCount,
                boundaryLinkCount: raw.boundaryLinkCount,
                farFieldLinkCount: raw.farFieldLinkCount,
                spongeCellCount: raw.spongeCellCount,
                activatedBoundaryLinkCount:
                    raw.activatedBoundaryLinkCount,
                activatedSpongeCellCount: raw.activatedSpongeCellCount,
                controlVolumeSpongeCellCount:
                    raw.controlVolumeSpongeCellCount,
                controlVolumeActivatedCellCount:
                    raw.controlVolumeActivatedCellCount,
                observedGlobal: conservationContribution(raw.observedGlobal),
                boundaryGlobal: conservationContribution(raw.boundaryGlobal),
                farFieldGlobal: conservationContribution(raw.farFieldGlobal),
                collisionGlobal:
                    conservationContribution(raw.collisionGlobal),
                symmetricLimiterGlobal:
                    conservationContribution(raw.limiterGlobal),
                spongeGlobal: conservationContribution(raw.spongeGlobal),
                globalClosureResidual:
                    conservationContribution(stepClosure),
                controlVolumeCollision:
                    conservationContribution(raw.collisionControl),
                controlVolumeSymmetricLimiter:
                    conservationContribution(raw.limiterControl),
                controlVolumeSponge:
                    conservationContribution(raw.spongeControl),
                activatedCellBoundary:
                    conservationContribution(raw.boundaryActivated),
                activatedCellSponge:
                    conservationContribution(raw.spongeActivated),
                measuredForceNewtons: measuredForce,
                rawBudgetForceNewtons: doubleVector(step.rawBudgetForce),
                forceBudgetResidualNewtons: forceResidual,
                attributedControlVolumeSourceForceNewtons:
                    attributedSourceForce,
                unexplainedForceResidualNewtons: unexplainedForce,
                boundaryLoadClosureResidualNewtons: boundaryLoadClosure
            ))
        }

        let count = max(Double(samples.count), 1)
        let finalMinusInitial = (finalPopulationMass ?? .nan)
            - initialPopulationMass
        let observedMassHistoryResidual = observed.x - finalMinusInitial
        let globalLedgerClosed = samples.count == history.count
            && maximumMassClosure <= 5.0e-3
            && maximumMomentumClosure <= 5.0e-3
            && abs(observedMassHistoryResidual) <= 5.0e-2
        let relativeRMSUnexplained = sqrt(
            unexplainedSquared / max(forceResidualSquared, 1.0e-30)
        )
        let maximumPeakUnexplainedFraction = maximumUnexplainedForce
            / max(maximumForceResidual, 1.0e-30)
        let relativeRMSBoundaryLoadClosure = sqrt(
            boundaryLoadClosureSquared
                / max(measuredForceSquared, 1.0e-30)
        )
        let allowedRelativeRMSUnexplained = 5.0e-3
        let allowedPeakUnexplainedFraction = 1.0e-2
        let forceResidualLedgerClosed = relativeRMSUnexplained
                <= allowedRelativeRMSUnexplained
            && maximumPeakUnexplainedFraction
                <= allowedPeakUnexplainedFraction
            && relativeRMSBoundaryLoadClosure <= 5.0e-5
        let massCandidates: [(String, Double)] = [
            ("curved-boundary", abs(boundary.x)),
            ("open-far-field", abs(farField.x)),
            ("baseline-collision", abs(collision.x)),
            ("symmetric-limiter", abs(limiter.x)),
            ("sponge", abs(sponge.x)),
        ]
        let dominantMass = massCandidates.max { $0.1 < $1.1 }?.0
            ?? "none"
        let collisionRMS = sqrt(collisionControlSquared / count)
        let limiterRMS = sqrt(limiterControlSquared / count)
        let spongeRMS = sqrt(spongeControlSquared / count)
        let controlCandidates: [(String, Double)] = [
            ("baseline-collision", collisionRMS),
            ("symmetric-limiter", limiterRMS),
            ("sponge", spongeRMS),
        ]
        let dominantControl = controlCandidates.max { $0.1 < $1.1 }?.0
            ?? "none"

        return MetalStationaryWallConservationLedgerReport(
            schemaVersion: 1,
            definition: "global observed population change = curved-boundary replacement + open-far-field replacement + baseline TRT collision + symmetric-scale limiter + sponge; measured minus control-volume budget force = collision + limiter + sponge momentum sources inside the control volume",
            samples: samples,
            cumulativeObservedGlobal: conservationContribution(observed),
            cumulativeBoundaryGlobal: conservationContribution(boundary),
            cumulativeFarFieldGlobal: conservationContribution(farField),
            cumulativeCollisionGlobal: conservationContribution(collision),
            cumulativeSymmetricLimiterGlobal:
                conservationContribution(limiter),
            cumulativeSpongeGlobal: conservationContribution(sponge),
            cumulativeControlVolumeCollision:
                conservationContribution(collisionControl),
            cumulativeControlVolumeSymmetricLimiter:
                conservationContribution(limiterControl),
            cumulativeControlVolumeSponge:
                conservationContribution(spongeControl),
            cumulativeGlobalClosureResidual:
                conservationContribution(closure),
            finalMinusInitialPopulationMass: finalMinusInitial,
            observedMassHistoryResidual: observedMassHistoryResidual,
            maximumPerStepGlobalMassClosureResidual: maximumMassClosure,
            maximumPerStepGlobalMomentumClosureResidual:
                maximumMomentumClosure,
            maximumPerStepLimiterMassContribution: maximumLimiterMass,
            maximumPerStepLimiterMomentumContribution:
                maximumLimiterMomentum,
            relativeCumulativeLimiterMassContribution:
                abs(limiter.x) / max(abs(initialPopulationMass), 1.0e-30),
            maximumForceBudgetResidualNewtons: maximumForceResidual,
            maximumAttributedControlVolumeSourceForceNewtons:
                maximumAttributedSource,
            maximumUnexplainedForceResidualNewtons:
                maximumUnexplainedForce,
            maximumBoundaryLoadClosureResidualNewtons:
                maximumBoundaryLoadClosure,
            RMSForceBudgetResidualNewtons:
                sqrt(forceResidualSquared / count),
            RMSAttributedControlVolumeSourceForceNewtons:
                sqrt(attributedSourceSquared / count),
            RMSUnexplainedForceResidualNewtons:
                sqrt(unexplainedSquared / count),
            RMSControlVolumeCollisionForceNewtons: collisionRMS,
            RMSControlVolumeSymmetricLimiterForceNewtons: limiterRMS,
            RMSControlVolumeSpongeForceNewtons: spongeRMS,
            relativeRMSUnexplainedForceResidual:
                relativeRMSUnexplained,
            maximumPeakUnexplainedForceResidualFraction:
                maximumPeakUnexplainedFraction,
            relativeRMSBoundaryLoadClosureResidual:
                relativeRMSBoundaryLoadClosure,
            maximumAllowedRelativeRMSUnexplainedForceResidual:
                allowedRelativeRMSUnexplained,
            maximumAllowedPeakUnexplainedForceResidualFraction:
                allowedPeakUnexplainedFraction,
            dominantGlobalMassContribution: dominantMass,
            dominantControlVolumeMomentumContribution: dominantControl,
            globalLedgerClosed: globalLedgerClosed,
            forceResidualLedgerClosed: forceResidualLedgerClosed
        )
    }

    private static func conservationContribution(
        _ value: SIMD4<Double>
    ) -> MetalStationaryWallConservationContribution {
        MetalStationaryWallConservationContribution(
            mass: value.x,
            momentumLattice: SIMD3<Double>(value.y, value.z, value.w)
        )
    }

    private static func symmetricLimiterCaseReport(
        limiterEnabled: Bool,
        requestedSteps: Int,
        initialPopulations: [Float],
        finalPopulations: [Float],
        history: [MetalTranslatingBodyTopologyStep],
        cellCount: Int,
        maximumMassDrift: Double,
        maximumAbsolutePopulation: Double,
        maximumForceResidual: Double,
        maximumRelativeResidual: Double
    ) -> MetalStationaryWallSymmetricLimiterCaseReport {
        let initialMass = initialPopulations.reduce(0.0) {
            $0 + Double($1)
        }
        let populationsFinite = finalPopulations.allSatisfy(\.isFinite)
        let fieldsFinite = populationsFinite
            && macroscopicFieldsAreFinite(
                populations: finalPopulations,
                cellCount: cellCount
            )
        let finalMassValue = finalPopulations.reduce(0.0) {
            $0 + Double($1)
        }
        let finalMass = populationsFinite ? finalMassValue : nil
        let massDrift = finalMass.map {
            abs($0 - initialMass) / max(abs(initialMass), 1.0e-30)
        }
        let finalMinimum = populationsFinite
            ? finalPopulations.min().map(Double.init)
            : nil
        let maximumAbsolute = populationsFinite
            ? finalPopulations.lazy.map { abs(Double($0)) }.max()
            : nil
        let firstNegative = history.firstIndex { step in
            guard let minimum = step.populationMinimum,
                  !minimum.nonFinite else { return false }
            return minimum.rawValue < 0
        }.map { $0 + 1 }
        let firstNonFinitePopulation = history.firstIndex {
            $0.populationMinimum?.nonFinite == true
        }.map { $0 + 1 }
        let minimumObserved = history.compactMap { step -> Double? in
            guard let minimum = step.populationMinimum,
                  !minimum.nonFinite else { return nil }
            return Double(minimum.rawValue)
        }.min()
        let firstInvalidLoad = history.firstIndex {
            !vectorIsFinite($0.measuredForce)
                || !vectorIsFinite($0.rawBudgetForce)
        }
        let loadsFinite = firstInvalidLoad == nil
        let finiteHistory = history.prefix(firstInvalidLoad ?? history.count)
        let residuals = finiteHistory.map {
            doubleVector($0.measuredForce - $0.rawBudgetForce)
        }
        let budgets = finiteHistory.map {
            doubleVector($0.rawBudgetForce)
        }
        let measured = finiteHistory.map {
            doubleVector($0.measuredForce)
        }
        let residualSquared = residuals.reduce(0.0) {
            $0 + squaredMagnitude($1)
        }
        let budgetSquared = budgets.reduce(0.0) {
            $0 + squaredMagnitude($1)
        }
        let rmsResidual = residuals.isEmpty
            ? nil
            : sqrt(residualSquared / Double(residuals.count))
        let maximumResidual = residuals.map(magnitude).max()
        let relativeResidual = residuals.isEmpty
            ? nil
            : sqrt(residualSquared / max(budgetSquared, 1.0e-30))
        let rawBudgetRMS = budgets.isEmpty
            ? nil
            : sqrt(budgetSquared / Double(budgets.count))
        let maximumMeasured = measured.map(magnitude).max()
        let relativeGateApplied =
            (rawBudgetRMS ?? .infinity) > maximumForceResidual
        let activationCellSteps = history.reduce(0) {
            $0 + $1.symmetricLimiterActivationCount
        }
        let activationSteps = history.reduce(0) {
            $0 + ($1.symmetricLimiterActivationCount > 0 ? 1 : 0)
        }
        let firstActivation = history.firstIndex {
            $0.symmetricLimiterActivationCount > 0
        }.map { $0 + 1 }
        let firstZeroScale = history.firstIndex {
            $0.symmetricLimiterMinimumScale == 0
        }.map { $0 + 1 }
        let maximumActivationsInOneStep = history.map(
            \.symmetricLimiterActivationCount
        ).max() ?? 0
        let minimumScale = history.compactMap(
            \.symmetricLimiterMinimumScale
        ).map(Double.init).min()
        let coveredEvents = history.reduce(0) {
            $0 + $1.newlyCoveredCells
        }
        let uncoveredEvents = history.reduce(0) {
            $0 + $1.newlyUncoveredCells
        }
        let transitionSteps = history.reduce(0) {
            $0 + (($1.newlyCoveredCells > 0
                || $1.newlyUncoveredCells > 0) ? 1 : 0)
        }
        let stabilityPassed = history.count == requestedSteps
            && firstNegative == nil
            && firstNonFinitePopulation == nil
            && populationsFinite
            && fieldsFinite
            && loadsFinite
            && (massDrift ?? .infinity) <= maximumMassDrift
            && (maximumAbsolute ?? .infinity)
                <= maximumAbsolutePopulation
            && coveredEvents == 0
            && uncoveredEvents == 0
            && transitionSteps == 0
        let forceBudgetPassed = (maximumResidual ?? .infinity)
                <= maximumForceResidual
            && (!relativeGateApplied
                || (relativeResidual ?? .infinity)
                    <= maximumRelativeResidual)
        return MetalStationaryWallSymmetricLimiterCaseReport(
            limiterEnabled: limiterEnabled,
            requestedSteps: requestedSteps,
            completedSteps: history.count,
            firstNegativePopulationStep: firstNegative,
            firstNonFinitePopulationStep: firstNonFinitePopulation,
            firstNonFiniteLoadStep: firstInvalidLoad.map { $0 + 1 },
            initialPopulationMass: initialMass,
            finalPopulationMass: finalMass,
            relativePopulationMassDrift: massDrift,
            minimumObservedPopulation: minimumObserved,
            finalMinimumPopulation: finalMinimum,
            maximumAbsolutePopulation: maximumAbsolute,
            populationsFinite: populationsFinite,
            fieldsFinite: fieldsFinite,
            loadsFinite: loadsFinite,
            limiterActivationCellSteps: activationCellSteps,
            limiterActivationSteps: activationSteps,
            firstLimiterActivationStep: firstActivation,
            firstZeroLimiterScaleStep: firstZeroScale,
            maximumLimiterActivationsInOneStep:
                maximumActivationsInOneStep,
            minimumLimiterScale: minimumScale,
            newlyCoveredCellEvents: coveredEvents,
            newlyUncoveredCellEvents: uncoveredEvents,
            topologyTransitionSteps: transitionSteps,
            conservativeRMSForceResidual: rmsResidual,
            maximumConservativeForceResidual: maximumResidual,
            conservativeRelativeRMSResidual: relativeResidual,
            rawBudgetRMSForceMagnitude: rawBudgetRMS,
            maximumMeasuredForceMagnitude: maximumMeasured,
            relativeResidualGateApplied: relativeGateApplied,
            stabilityPassed: stabilityPassed,
            forceBudgetPassed: forceBudgetPassed,
            fullAcceptancePassed: stabilityPassed && forceBudgetPassed
        )
    }

    private static func generalizedRichardsonFit(
        diameters: [Int],
        values: [Double]
    ) -> (order: Double, extrapolated: Double,
        fineGridConvergenceIndex: Double)?
    {
        guard diameters.count == 3,
              values.count == 3,
              values.allSatisfy(\.isFinite),
              (values[0] - values[1]) * (values[1] - values[2]) > 0
        else { return nil }

        let h = diameters.map { 1.0 / Double($0) }
        var bestOrder = 0.0
        var bestIntercept = 0.0
        var bestError = Double.infinity
        for index in 0...7_950 {
            let order = 0.05 + Double(index) * 0.001
            let x = h.map { pow($0, order) }
            let meanX = x.reduce(0, +) / 3
            let meanY = values.reduce(0, +) / 3
            let denominator = x.reduce(0) {
                $0 + ($1 - meanX) * ($1 - meanX)
            }
            guard denominator > 1.0e-30 else { continue }
            let slope = zip(x, values).reduce(0.0) {
                $0 + ($1.0 - meanX) * ($1.1 - meanY)
            } / denominator
            let intercept = meanY - slope * meanX
            let error = zip(x, values).reduce(0.0) {
                let residual = $1.1 - (intercept + slope * $1.0)
                return $0 + residual * residual
            }
            if error < bestError {
                bestError = error
                bestOrder = order
                bestIntercept = intercept
            }
        }
        guard bestOrder > 0.051, bestOrder < 7.999 else { return nil }
        let fineRatio = Double(diameters[2]) / Double(diameters[1])
        let denominator = pow(fineRatio, bestOrder) - 1
        guard denominator > 1.0e-12 else { return nil }
        let fineGridConvergenceIndex = 1.25
            * abs(values[2] - values[1])
            / max(abs(values[2]), 1.0e-30)
            / denominator
        return (
            order: bestOrder,
            extrapolated: bestIntercept,
            fineGridConvergenceIndex: fineGridConvergenceIndex
        )
    }
#endif

    private static func populationMinimumSample(
        _ record: MetalPopulationMinimumRecord,
        step: Int,
        domain: GridSize,
        sphereCenter: SIMD3<Double>,
        sphereRadius: Double,
        spongeWidth: Int,
        spongeStrength: Double
    ) -> MetalStationaryWallPopulationMinimumSample {
        let cellCount = domain.cellCount
        let linearIndex = Int(record.linearIndex)
        let directionIndex = linearIndex / cellCount
        let cellIndex = linearIndex % cellCount
        let xy = domain.x * domain.y
        let z = cellIndex / xy
        let remainder = cellIndex - z * xy
        let y = remainder / domain.x
        let x = remainder - y * domain.x
        let cell = SIMD3<Int>(x, y, z)
        let rawDirection = D3Q19.directions[directionIndex]
        let direction = SIMD3<Int>(
            Int(rawDirection.x),
            Int(rawDirection.y),
            Int(rawDirection.z)
        )
        let pullSource = SIMD3<Int>(
            cell.x - direction.x,
            cell.y - direction.y,
            cell.z - direction.z
        )
        let pullSourceInside = populationCellIsInside(
            pullSource,
            domain: domain
        )
        let signedDistance = signedSphereDistance(
            cell,
            center: sphereCenter,
            radius: sphereRadius
        )
        let cellIsSolid = signedDistance <= 0
        let pullSourceIsSolid = pullSourceInside
            && signedSphereDistance(
                pullSource,
                center: sphereCenter,
                radius: sphereRadius
            ) <= 0
        let pullSourceSignedDistance = pullSourceInside
            ? signedSphereDistance(
                pullSource,
                center: sphereCenter,
                radius: sphereRadius
            )
            : nil
        let adjacentToSphere = !cellIsSolid
            && D3Q19.directions.dropFirst().contains { raw in
                let offset = SIMD3<Int>(
                    Int(raw.x),
                    Int(raw.y),
                    Int(raw.z)
                )
                let neighbor = SIMD3<Int>(
                    cell.x - offset.x,
                    cell.y - offset.y,
                    cell.z - offset.z
                )
                return populationCellIsInside(neighbor, domain: domain)
                    && signedSphereDistance(
                        neighbor,
                        center: sphereCenter,
                        radius: sphereRadius
                    ) <= 0
            }
        let boundaryDistance = min(
            min(x, domain.x - 1 - x),
            min(
                min(y, domain.y - 1 - y),
                min(z, domain.z - 1 - z)
            )
        )
        let insideSponge = boundaryDistance < spongeWidth
        let normalizedSpongeDistance = insideSponge
            ? min(
                max(
                    (Double(spongeWidth) - Double(boundaryDistance))
                        / max(Double(spongeWidth), 1),
                    0
                ),
                1
            )
            : 0
        let classification: String
        if !record.nonFinite {
            classification = "finite"
        } else if record.rawValue.isNaN {
            classification = "nan"
        } else if record.rawValue == .infinity {
            classification = "positive-infinity"
        } else if record.rawValue == -.infinity {
            classification = "negative-infinity"
        } else {
            classification = "non-finite"
        }
        let updatePath: String
        if cellIsSolid {
            updatePath = "solid-equilibrium-reset"
        } else if !pullSourceInside {
            updatePath = "far-field-input-trt-collision"
        } else if pullSourceIsSolid {
            updatePath = "curved-boundary-reconstruction-trt-collision"
        } else {
            updatePath = "ordinary-fluid-pull-trt-collision"
        }
        return MetalStationaryWallPopulationMinimumSample(
            step: step,
            minimumPopulation:
                record.nonFinite ? nil : Double(record.rawValue),
            valueClassification: classification,
            directionIndex: directionIndex,
            latticeDirection: direction,
            cell: cell,
            signedDistanceToSphereSurfaceCells: signedDistance,
            absoluteDistanceToSphereSurfaceCells: abs(signedDistance),
            cellIsSolid: cellIsSolid,
            cellAdjacentToSphere: adjacentToSphere,
            pullSourceCell: pullSource,
            pullSourceInsideDomain: pullSourceInside,
            pullSourceIsSolid: pullSourceIsSolid,
            pullSourceSignedDistanceToSphereSurfaceCells:
                pullSourceSignedDistance,
            populationUpdatePath: updatePath,
            distanceToNearestDomainBoundaryCells: boundaryDistance,
            insideSponge: insideSponge,
            spongeFactor: spongeStrength
                * normalizedSpongeDistance
                * normalizedSpongeDistance
        )
    }

    private static func populationLocation(
        _ sample: MetalStationaryWallPopulationMinimumSample
    ) -> String {
        if !sample.pullSourceInsideDomain {
            return "far-field-boundary"
        }
        if sample.pullSourceIsSolid {
            return "curved-boundary-reconstruction"
        }
        if sample.cellAdjacentToSphere {
            return "curved-boundary-adjacent-fluid-pull"
        }
        if sample.insideSponge {
            return "sponge"
        }
        return "fluid-interior"
    }

    private static func populationCellIsInside(
        _ cell: SIMD3<Int>,
        domain: GridSize
    ) -> Bool {
        cell.x >= 0 && cell.y >= 0 && cell.z >= 0
            && cell.x < domain.x
            && cell.y < domain.y
            && cell.z < domain.z
    }

    private static func signedSphereDistance(
        _ cell: SIMD3<Int>,
        center: SIMD3<Double>,
        radius: Double
    ) -> Double {
        let relative = SIMD3<Double>(
            Double(cell.x) + 0.5 - center.x,
            Double(cell.y) + 0.5 - center.y,
            Double(cell.z) + 0.5 - center.z
        )
        return sqrt(
            relative.x * relative.x
                + relative.y * relative.y
                + relative.z * relative.z
        ) - radius
    }

    private static func doubleVector(
        _ value: SIMD3<Float>
    ) -> SIMD3<Double> {
        SIMD3<Double>(
            Double(value.x),
            Double(value.y),
            Double(value.z)
        )
    }

    private static func squaredMagnitude(_ value: SIMD3<Double>) -> Double {
        value.x * value.x + value.y * value.y + value.z * value.z
    }

    private static func magnitude(_ value: SIMD3<Double>) -> Double {
        sqrt(squaredMagnitude(value))
    }

    private static func vectorIsFinite(_ value: SIMD3<Float>) -> Bool {
        value.x.isFinite && value.y.isFinite && value.z.isFinite
    }

    private static func macroscopicFieldsAreFinite(
        populations: [Float],
        cellCount: Int
    ) -> Bool {
        guard populations.count == D3Q19.count * cellCount else {
            return false
        }
        for cell in 0..<cellCount {
            var density: Float = 0
            var momentum = SIMD3<Float>.zero
            for q in 0..<D3Q19.count {
                let population = populations[q * cellCount + cell]
                let direction = D3Q19.directions[q]
                density += population
                momentum += SIMD3<Float>(
                    Float(direction.x),
                    Float(direction.y),
                    Float(direction.z)
                ) * population
            }
            guard density.isFinite, density != 0 else {
                return false
            }
            let velocity = momentum / density
            guard velocity.x.isFinite,
                  velocity.y.isFinite,
                  velocity.z.isFinite else {
                return false
            }
        }
        return true
    }
}

#if canImport(Metal)
import Metal

private struct MetalTranslatingBodyCaseConfiguration {
    let grid: GridSize
    let sphereRadiusCells: Float
    let referenceSpeedLattice: Float
    let geometryTranslationSpeedLattice: Float
    let wallVelocityLattice: Float
    let wallVelocityMode: Float
    let initialFluidVelocityLattice: Float
    let periodicBoundaries: Bool
    let spongeStrength: Float
    let latticeKinematicViscosity: Float
    let initialCenter: SIMD3<Float>
    let controlMinimum: SIMD3<UInt32>
    let controlMaximumExclusive: SIMD3<UInt32>
    let characteristicLengthCells: Int
    let spongeWidthCells: Int

    init(
        grid: GridSize,
        sphereRadiusCells: Float,
        referenceSpeedLattice: Float,
        geometryTranslationSpeedLattice: Float,
        wallVelocityLattice: Float,
        wallVelocityMode: Float,
        initialFluidVelocityLattice: Float,
        periodicBoundaries: Bool,
        spongeStrength: Float,
        latticeKinematicViscosity: Float,
        initialCenter: SIMD3<Float>,
        controlMinimum: SIMD3<UInt32>,
        controlMaximumExclusive: SIMD3<UInt32>,
        characteristicLengthCells: Int = 8,
        spongeWidthCells: Int = 4
    ) {
        self.grid = grid
        self.sphereRadiusCells = sphereRadiusCells
        self.referenceSpeedLattice = referenceSpeedLattice
        self.geometryTranslationSpeedLattice =
            geometryTranslationSpeedLattice
        self.wallVelocityLattice = wallVelocityLattice
        self.wallVelocityMode = wallVelocityMode
        self.initialFluidVelocityLattice = initialFluidVelocityLattice
        self.periodicBoundaries = periodicBoundaries
        self.spongeStrength = spongeStrength
        self.latticeKinematicViscosity = latticeKinematicViscosity
        self.initialCenter = initialCenter
        self.controlMinimum = controlMinimum
        self.controlMaximumExclusive = controlMaximumExclusive
        self.characteristicLengthCells = characteristicLengthCells
        self.spongeWidthCells = spongeWidthCells
    }

    static func standard() throws -> Self {
        Self(
            grid: try GridSize(
                x: MetalTranslatingBodyTopologyValidator.gridResolution,
                y: MetalTranslatingBodyTopologyValidator.gridResolution,
                z: MetalTranslatingBodyTopologyValidator.gridResolution
            ),
            sphereRadiusCells: Float(
                MetalTranslatingBodyTopologyValidator.sphereRadiusCells
            ),
            referenceSpeedLattice: Float(
                MetalTranslatingBodyTopologyValidator
                    .translationSpeedLattice
            ),
            geometryTranslationSpeedLattice: Float(
                MetalTranslatingBodyTopologyValidator
                    .translationSpeedLattice
            ),
            wallVelocityLattice: Float(
                MetalTranslatingBodyTopologyValidator
                    .translationSpeedLattice
            ),
            wallVelocityMode: 0,
            initialFluidVelocityLattice: 0,
            periodicBoundaries: true,
            spongeStrength: 0,
            latticeKinematicViscosity: 0.1,
            initialCenter: SIMD3<Float>(8, 12, 12),
            controlMinimum: SIMD3<UInt32>(2, 2, 2),
            controlMaximumExclusive: SIMD3<UInt32>(22, 22, 22)
        )
    }
}

private struct GPUTranslatingTopologyParameters {
    var initialCenterAndRadius: SIMD4<Float>
    var geometryVelocity: SIMD4<Float>
    var wallVelocity: SIMD4<Float>
}

private struct GPUTranslatingTopologyBounds {
    var minimum: SIMD4<UInt32>
    var maximumExclusive: SIMD4<UInt32>
}

private struct GPUTranslatingTopologyBudget {
    var oldFluidMomentum: SIMD4<Float>
    var newFluidMomentum: SIMD4<Float>
    var outwardMomentumFlux: SIMD4<Float>
    var topologyReservoirCorrection: SIMD4<Float>
}

private struct GPUPopulationMinimum {
    var comparisonValue: Float
    var rawValue: Float
    var linearIndex: UInt32
    var nonFinite: UInt32
}

private struct GPUTRTCollisionTerm {
    var values0: SIMD4<Float>
    var values1: SIMD4<Float>
    var boundaryValues0: SIMD4<Float>
    var boundaryContributions: SIMD4<Float>
    var metadata: SIMD4<UInt32>
    var boundaryMetadata: SIMD4<UInt32>
}

private struct GPUTRTCollisionSummary {
    var macroscopic: SIMD4<Float>
    var relaxation: SIMD4<Float>
    var limiter: SIMD4<Float>
    var metadata: SIMD4<UInt32>
}

private struct GPUSymmetricLimiterLedger {
    var observedGlobal: SIMD4<Float>
    var boundaryGlobal: SIMD4<Float>
    var farFieldGlobal: SIMD4<Float>
    var collisionGlobal: SIMD4<Float>
    var limiterGlobal: SIMD4<Float>
    var spongeGlobal: SIMD4<Float>
    var collisionControl: SIMD4<Float>
    var limiterControl: SIMD4<Float>
    var spongeControl: SIMD4<Float>
    var boundaryActivated: SIMD4<Float>
    var spongeActivated: SIMD4<Float>
    var limiterNorms: SIMD4<Float>
    var limiterControlNorms: SIMD4<Float>
    var counts: SIMD4<UInt32>
    var activatedCounts: SIMD4<UInt32>
}

private struct GPUSymmetricLimiterRadialBin {
    var norms: SIMD4<Float>
    var counts: SIMD4<UInt32>
}

private struct MetalSymmetricLimiterRadialBinRaw {
    let norms: SIMD4<Double>
    let fluidCellCount: Int
    let activatedCellCount: Int
    let boundaryLinkCount: Int
    let activatedBoundaryLinkCount: Int
}

private struct MetalSymmetricLimiterLedgerRaw {
    var observedGlobal = SIMD4<Double>.zero
    var boundaryGlobal = SIMD4<Double>.zero
    var farFieldGlobal = SIMD4<Double>.zero
    var collisionGlobal = SIMD4<Double>.zero
    var limiterGlobal = SIMD4<Double>.zero
    var spongeGlobal = SIMD4<Double>.zero
    var collisionControl = SIMD4<Double>.zero
    var limiterControl = SIMD4<Double>.zero
    var spongeControl = SIMD4<Double>.zero
    var boundaryActivated = SIMD4<Double>.zero
    var spongeActivated = SIMD4<Double>.zero
    var limiterNorms = SIMD4<Double>.zero
    var limiterControlNorms = SIMD4<Double>.zero
    var activatedCellCount = 0
    var boundaryLinkCount = 0
    var farFieldLinkCount = 0
    var spongeCellCount = 0
    var activatedBoundaryLinkCount = 0
    var activatedSpongeCellCount = 0
    var controlVolumeSpongeCellCount = 0
    var controlVolumeActivatedCellCount = 0

    mutating func add(_ value: GPUSymmetricLimiterLedger) {
        observedGlobal += doubleVector(value.observedGlobal)
        boundaryGlobal += doubleVector(value.boundaryGlobal)
        farFieldGlobal += doubleVector(value.farFieldGlobal)
        collisionGlobal += doubleVector(value.collisionGlobal)
        limiterGlobal += doubleVector(value.limiterGlobal)
        spongeGlobal += doubleVector(value.spongeGlobal)
        collisionControl += doubleVector(value.collisionControl)
        limiterControl += doubleVector(value.limiterControl)
        spongeControl += doubleVector(value.spongeControl)
        boundaryActivated += doubleVector(value.boundaryActivated)
        spongeActivated += doubleVector(value.spongeActivated)
        limiterNorms += doubleVector(value.limiterNorms)
        limiterControlNorms += doubleVector(value.limiterControlNorms)
        activatedCellCount += Int(value.counts.x)
        boundaryLinkCount += Int(value.counts.y)
        farFieldLinkCount += Int(value.counts.z)
        spongeCellCount += Int(value.counts.w)
        activatedBoundaryLinkCount += Int(value.activatedCounts.x)
        activatedSpongeCellCount += Int(value.activatedCounts.y)
        controlVolumeSpongeCellCount += Int(value.activatedCounts.z)
        controlVolumeActivatedCellCount += Int(value.activatedCounts.w)
    }

    private func doubleVector(_ value: SIMD4<Float>) -> SIMD4<Double> {
        SIMD4<Double>(
            Double(value.x),
            Double(value.y),
            Double(value.z),
            Double(value.w)
        )
    }
}

private struct MetalTRTCollisionCapture {
    let macroscopic: SIMD4<Float>
    let relaxation: SIMD4<Float>
    let limiter: SIMD4<Float>
    let metadata: SIMD4<UInt32>
    let terms: [GPUTRTCollisionTerm]
}

private struct MetalTranslatingBodyTopologyStep {
    let measuredForce: SIMD3<Float>
    let rawBudgetForce: SIMD3<Float>
    let newlyCoveredCells: Int
    let newlyUncoveredCells: Int
    let solidControlSurfaceCrossingLinkCount: Int
    let populationMinimum: MetalPopulationMinimumRecord?
    let symmetricLimiterActivationCount: Int
    let symmetricLimiterMinimumScale: Float?
    let conservationLedger: MetalSymmetricLimiterLedgerRaw?
    let radialLimiterBins: [MetalSymmetricLimiterRadialBinRaw]?
}

private final class MetalTranslatingBodyTopologySimulation {
    private let backend: MetalBackend
    private let configuration: SimulationConfiguration
    private let periodicBoundaries: Bool
    private let linkForceMode: UInt32
    private let symmetricPositivityLimiterEnabled: Bool
    private let positivityPreservingRegularizedCollisionEnabled: Bool
    private let positivityPreservingRecursiveRegularizedCollisionEnabled: Bool
    private let conservationLedgerEnabled: Bool
    private let captureMacroscopicFields: Bool
    private let characteristicLengthCells: Int
    private let parameters: MTLBuffer
    private let bodyState: MTLBuffer
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidA: MTLBuffer
    private let solidB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let loadReductionA: MTLBuffer
    private let loadReductionB: MTLBuffer
    private let budgetBeforeA: MTLBuffer
    private let budgetBeforeB: MTLBuffer
    private let budgetAfterA: MTLBuffer
    private let budgetAfterB: MTLBuffer
    private let populationMinimumPartials: MTLBuffer
    private let trtCollisionTerms: MTLBuffer
    private let trtCollisionSummary: MTLBuffer
    private let conservationLedgerCells: MTLBuffer?
    private let conservationLedgerPartials: MTLBuffer?
    private let radialLimiterBins: MTLBuffer?
    private let initializePipeline: MTLComputePipelineState
    private let geometryPipeline: MTLComputePipelineState
    private let fluidPipeline: MTLComputePipelineState
    private let loadReductionPipeline: MTLComputePipelineState
    private let budgetBeforePipeline: MTLComputePipelineState
    private let budgetAfterPipeline: MTLComputePipelineState
    private let budgetReductionPipeline: MTLComputePipelineState
    private let populationMinimumPipeline: MTLComputePipelineState
    private let trtCollisionDecompositionPipeline: MTLComputePipelineState
    private let conservationLedgerCapturePipeline: MTLComputePipelineState
    private let conservationLedgerReductionPipeline: MTLComputePipelineState
    private let radialLimiterReductionPipeline: MTLComputePipelineState
    private let partialCount: Int
    private let populationPartialCount: Int
    private let bounds: GPUTranslatingTopologyBounds
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var currentSolid: MTLBuffer
    private var nextSolid: MTLBuffer
    private var latestTRTCollisionCapture: MetalTRTCollisionCapture?

    init(
        backend: MetalBackend,
        linkForceMode: UInt32,
        caseConfiguration: MetalTranslatingBodyCaseConfiguration,
        symmetricPositivityLimiterEnabled: Bool = false,
        positivityPreservingRegularizedCollisionEnabled: Bool = false,
        positivityPreservingRecursiveRegularizedCollisionEnabled: Bool = false,
        conservationLedgerEnabled: Bool = false,
        captureMacroscopicFields: Bool = false
    ) throws {
        self.backend = backend
        self.linkForceMode = linkForceMode
        self.symmetricPositivityLimiterEnabled =
            symmetricPositivityLimiterEnabled
        self.positivityPreservingRegularizedCollisionEnabled =
            positivityPreservingRegularizedCollisionEnabled
        self.positivityPreservingRecursiveRegularizedCollisionEnabled =
            positivityPreservingRecursiveRegularizedCollisionEnabled
        self.conservationLedgerEnabled = conservationLedgerEnabled
        self.captureMacroscopicFields = captureMacroscopicFields
        let bulkCollisionTreatmentCount = [
            symmetricPositivityLimiterEnabled,
            positivityPreservingRegularizedCollisionEnabled,
            positivityPreservingRecursiveRegularizedCollisionEnabled,
        ].filter { $0 }.count
        if bulkCollisionTreatmentCount > 1 {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "bulk collision treatments are mutually exclusive"
            )
        }
        characteristicLengthCells =
            caseConfiguration.characteristicLengthCells
        periodicBoundaries = caseConfiguration.periodicBoundaries
        let grid = caseConfiguration.grid
        let referenceSpeed = caseConfiguration.referenceSpeedLattice
        let characteristicLengthCells =
            caseConfiguration.characteristicLengthCells
        let targetReynoldsNumber = referenceSpeed
            * Float(characteristicLengthCells)
            / caseConfiguration.latticeKinematicViscosity
        let scaling = try LatticeScaling(
            characteristicLengthMeters: Float(characteristicLengthCells),
            characteristicLengthCells: characteristicLengthCells,
            referenceSpeedMetersPerSecond: referenceSpeed,
            targetReynoldsNumber: targetReynoldsNumber,
            physicalAirDensity: 1,
            latticeReferenceSpeed: referenceSpeed
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: SIMD3<Float>(
                caseConfiguration.initialFluidVelocityLattice,
                0,
                0
            ),
            spongeWidthCells: caseConfiguration.spongeWidthCells,
            spongeStrength: caseConfiguration.spongeStrength,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        let center = caseConfiguration.initialCenter
        parameters = try backend.makeSharedBuffer(
            value: GPUTranslatingTopologyParameters(
                initialCenterAndRadius: SIMD4<Float>(
                    center,
                    caseConfiguration.sphereRadiusCells
                ),
                geometryVelocity: SIMD4<Float>(
                    caseConfiguration.geometryTranslationSpeedLattice,
                    0,
                    0,
                    0
                ),
                wallVelocity: SIMD4<Float>(
                    caseConfiguration.wallVelocityLattice,
                    0,
                    0,
                    caseConfiguration.wallVelocityMode
                )
            )
        )
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: center))
        )
        bounds = GPUTranslatingTopologyBounds(
            minimum: SIMD4<UInt32>(caseConfiguration.controlMinimum, 0),
            maximumExclusive: SIMD4<UInt32>(
                caseConfiguration.controlMaximumExclusive,
                0
            )
        )
        initializePipeline = try backend.pipeline(
            named: "initializeTranslatingSphereTopology"
        )
        geometryPipeline = try backend.pipeline(
            named: "buildTranslatingSphereTopology"
        )
        fluidPipeline = try backend.pipeline(named: "stepFluidTRT")
        loadReductionPipeline = try backend.pipeline(
            named: "reduceForceTorque"
        )
        budgetBeforePipeline = try backend.pipeline(
            named: "measureControlVolumeMomentumBeforeStep"
        )
        budgetAfterPipeline = try backend.pipeline(
            named: "measureControlVolumeMomentumAfterStep"
        )
        budgetReductionPipeline = try backend.pipeline(
            named: "reduceControlVolumeMomentumBudget"
        )
        populationMinimumPipeline = try backend.pipeline(
            named: "reducePopulationMinimum"
        )
        trtCollisionDecompositionPipeline = try backend.pipeline(
            named: "captureTRTCollisionDecomposition"
        )
        conservationLedgerCapturePipeline = try backend.pipeline(
            named: "captureSymmetricLimiterLedger"
        )
        conservationLedgerReductionPipeline = try backend.pipeline(
            named: "reduceSymmetricLimiterLedger"
        )
        radialLimiterReductionPipeline = try backend.pipeline(
            named: "reduceSymmetricLimiterRadialBins"
        )

        let cells = grid.cellCount
        let populationBytes = D3Q19.count * cells
            * MemoryLayout<Float>.stride
        let maskBytes = cells * MemoryLayout<UInt8>.stride
        let wallBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cells * MemoryLayout<Float>.stride
        let velocityBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        partialCount = max(1, (cells + 255) / 256)
        populationPartialCount = max(
            1,
            (D3Q19.count * cells + 255) / 256
        )
        let loadBytes = partialCount * MemoryLayout<GPUForceTorque>.stride
        let budgetBytes = partialCount
            * MemoryLayout<GPUTranslatingTopologyBudget>.stride
        let populationMinimumBytes = populationPartialCount
            * MemoryLayout<GPUPopulationMinimum>.stride
        let trtCollisionTermBytes = D3Q19.count
            * MemoryLayout<GPUTRTCollisionTerm>.stride
        let trtCollisionSummaryBytes =
            MemoryLayout<GPUTRTCollisionSummary>.stride
        let conservationLedgerCellBytes = cells
            * MemoryLayout<GPUSymmetricLimiterLedger>.stride
        let conservationLedgerPartialBytes = partialCount
            * MemoryLayout<GPUSymmetricLimiterLedger>.stride
        let radialLimiterBinBytes = partialCount * 8
            * MemoryLayout<GPUSymmetricLimiterRadialBin>.stride
        var allocationLengths = [
            MemoryLayout<GPUTranslatingTopologyParameters>.stride,
            MemoryLayout<GPUBirdBodyState>.stride,
            populationBytes, populationBytes,
            maskBytes, maskBytes, wallBytes,
            densityBytes, velocityBytes,
            loadBytes, loadBytes,
            budgetBytes, budgetBytes, budgetBytes, budgetBytes,
            populationMinimumBytes,
            trtCollisionTermBytes, trtCollisionSummaryBytes,
        ]
        if conservationLedgerEnabled {
            allocationLengths.append(conservationLedgerCellBytes)
            allocationLengths.append(conservationLedgerPartialBytes)
            allocationLengths.append(radialLimiterBinBytes)
        }
        try backend.validateAllocationPlan(bufferLengths: allocationLengths)
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidA = try backend.makePrivateBuffer(length: maskBytes)
        solidB = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(length: wallBytes)
        density = try backend.makeSharedBuffer(length: densityBytes)
        velocity = try backend.makeSharedBuffer(length: velocityBytes)
        loadReductionA = try backend.makeSharedBuffer(length: loadBytes)
        loadReductionB = try backend.makeSharedBuffer(length: loadBytes)
        budgetBeforeA = try backend.makeSharedBuffer(length: budgetBytes)
        budgetBeforeB = try backend.makeSharedBuffer(length: budgetBytes)
        budgetAfterA = try backend.makeSharedBuffer(length: budgetBytes)
        budgetAfterB = try backend.makeSharedBuffer(length: budgetBytes)
        populationMinimumPartials = try backend.makeSharedBuffer(
            length: populationMinimumBytes
        )
        trtCollisionTerms = try backend.makeSharedBuffer(
            length: trtCollisionTermBytes
        )
        trtCollisionSummary = try backend.makeSharedBuffer(
            length: trtCollisionSummaryBytes
        )
        if conservationLedgerEnabled {
            conservationLedgerCells = try backend.makePrivateBuffer(
                length: conservationLedgerCellBytes
            )
            conservationLedgerPartials = try backend.makeSharedBuffer(
                length: conservationLedgerPartialBytes
            )
            radialLimiterBins = try backend.makeSharedBuffer(
                length: radialLimiterBinBytes
            )
        }
        else {
            conservationLedgerCells = nil
            conservationLedgerPartials = nil
            radialLimiterBins = nil
        }
        currentPopulations = populationsA
        nextPopulations = populationsB
        currentSolid = solidA
        nextSolid = solidB
        try initializeTopologyCanonical()
    }

    var latticeKinematicViscosity: Float {
        configuration.scaling.latticeKinematicViscosity
    }

    var tauPlus: Float {
        configuration.scaling.tauPlus
    }

    var forceToPhysical: Float {
        configuration.scaling.forceToPhysical
    }

    func copyPopulations() throws -> [Float] {
        let staging = try backend.makeSharedBuffer(
            length: currentPopulations.length
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to read translating-body populations."
            )
        }
        blit.copy(
            from: currentPopulations,
            sourceOffset: 0,
            to: staging,
            destinationOffset: 0,
            size: currentPopulations.length
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
        let count = staging.length / MemoryLayout<Float>.stride
        let pointer = staging.contents().assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    func capturePopulationMinimum() throws -> MetalPopulationMinimumRecord {
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create population-minimum command buffer."
            )
        }
        try encodePopulationMinimum(
            commandBuffer: commandBuffer,
            populations: currentPopulations
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
        return readPopulationMinimum()
    }

    func runTRTCollisionDecomposition(
        steps: Int,
        targetCell: SIMD3<UInt32>
    ) throws -> ([MetalTranslatingBodyTopologyStep], MetalTRTCollisionCapture) {
        latestTRTCollisionCapture = nil
        let history = try run(
            steps: steps,
            collisionDecompositionStep: steps,
            collisionTargetCell: targetCell
        )
        guard let capture = latestTRTCollisionCapture else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "TRT collision decomposition was not captured"
            )
        }
        return (history, capture)
    }

    func run(
        steps: Int,
        capturePopulationMinimum: Bool = false,
        stopOneStepAfterFirstNonFinitePopulation: Bool = false,
        collisionDecompositionStep: Int? = nil,
        collisionTargetCell: SIMD3<UInt32>? = nil,
        captureConservationLedger: Bool = false,
        radialCaptureSteps: Set<Int> = []
    ) throws -> [MetalTranslatingBodyTopologyStep] {
        if captureConservationLedger && !conservationLedgerEnabled {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "conservation ledger capture was not enabled at allocation"
            )
        }
        if !radialCaptureSteps.isEmpty && !captureConservationLedger {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "radial limiter capture requires the conservation ledger"
            )
        }
        var history: [MetalTranslatingBodyTopologyStep] = []
        history.reserveCapacity(steps)
        var firstNonFinitePopulationStep: Int?
        for step in 1...steps {
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create translating-body command buffer."
                )
            }
            var uniforms = makeUniforms(time: Float(step))
            let before = try encodeTopologyBudgetBefore(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeTopologyGeometry(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeTopologyFluid(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            if captureConservationLedger {
                try encodeConservationLedgerCapture(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                try encodeConservationLedgerReduction(
                    commandBuffer: commandBuffer
                )
                if radialCaptureSteps.contains(step) {
                    try encodeRadialLimiterReduction(
                        commandBuffer: commandBuffer,
                        uniforms: &uniforms
                    )
                }
            }
            let captureCollision = collisionDecompositionStep == step
                && collisionTargetCell != nil
            if captureCollision, let collisionTargetCell {
                try encodeTRTCollisionDecomposition(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms,
                    targetCell: collisionTargetCell
                )
            }
            let load = try encodeTopologyLoadReduction(
                commandBuffer: commandBuffer
            )
            let after = try encodeTopologyBudgetAfter(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            if capturePopulationMinimum {
                try encodePopulationMinimum(
                    commandBuffer: commandBuffer,
                    populations: nextPopulations
                )
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)

            let rawBefore = before.contents()
                .assumingMemoryBound(
                    to: GPUTranslatingTopologyBudget.self
                ).pointee
            let rawAfter = after.contents()
                .assumingMemoryBound(
                    to: GPUTranslatingTopologyBudget.self
                ).pointee
            let rawLoad = load.contents()
                .assumingMemoryBound(to: GPUForceTorque.self).pointee
            let oldMomentum = vector(rawBefore.oldFluidMomentum)
            let newMomentum = vector(rawAfter.newFluidMomentum)
            let outwardFlux = vector(rawBefore.outwardMomentumFlux)
            let rawBudget = (oldMomentum - newMomentum - outwardFlux)
                * configuration.scaling.forceToPhysical
            let populationMinimum = capturePopulationMinimum
                ? readPopulationMinimum()
                : nil
            if captureCollision {
                latestTRTCollisionCapture = readTRTCollisionDecomposition()
            }
            let conservationLedger = captureConservationLedger
                ? try readConservationLedger()
                : nil
            let radialBins = radialCaptureSteps.contains(step)
                ? try readRadialLimiterBins()
                : nil
            history.append(MetalTranslatingBodyTopologyStep(
                measuredForce: vector(rawLoad.force),
                rawBudgetForce: rawBudget,
                newlyCoveredCells: Int(
                    rawAfter.topologyReservoirCorrection.w.rounded()
                ),
                newlyUncoveredCells: Int(
                    rawAfter.newFluidMomentum.w.rounded()
                ),
                solidControlSurfaceCrossingLinkCount: Int(
                    rawBefore.outwardMomentumFlux.w.rounded()
                ),
                populationMinimum: populationMinimum,
                symmetricLimiterActivationCount:
                    Int(rawLoad.force.w.rounded()),
                symmetricLimiterMinimumScale: rawLoad.force.w > 0
                    ? 1 - rawLoad.torque.w
                    : nil,
                conservationLedger: conservationLedger,
                radialLimiterBins: radialBins
            ))
            swap(&currentPopulations, &nextPopulations)
            swap(&currentSolid, &nextSolid)
            if stopOneStepAfterFirstNonFinitePopulation {
                if let firstNonFinitePopulationStep,
                   step > firstNonFinitePopulationStep {
                    break
                }
                if populationMinimum?.nonFinite == true {
                    firstNonFinitePopulationStep = step
                }
            }
        }
        return history
    }

    private func encodeConservationLedgerCapture(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let conservationLedgerCells,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode symmetric-limiter conservation capture."
            )
        }
        var ledgerBounds = bounds
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(nextSolid, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(conservationLedgerCells, offset: 0, index: 4)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
        )
        encoder.setBytes(
            &ledgerBounds,
            length: MemoryLayout<GPUTranslatingTopologyBounds>.stride,
            index: 6
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: conservationLedgerCapturePipeline,
            count: configuration.grid.cellCount
        )
        encoder.endEncoding()
    }

    private func encodeConservationLedgerReduction(
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let conservationLedgerCells,
              let conservationLedgerPartials,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to reduce symmetric-limiter conservation capture."
            )
        }
        var cellCount = UInt32(configuration.grid.cellCount)
        encoder.setBuffer(conservationLedgerCells, offset: 0, index: 0)
        encoder.setBuffer(conservationLedgerPartials, offset: 0, index: 1)
        encoder.setBytes(
            &cellCount,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: conservationLedgerReductionPipeline,
            count: partialCount
        )
        encoder.endEncoding()
    }

    private func readConservationLedger() throws
        -> MetalSymmetricLimiterLedgerRaw
    {
        guard let conservationLedgerPartials else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "conservation ledger partial buffer is unavailable"
            )
        }
        let pointer = conservationLedgerPartials.contents()
            .assumingMemoryBound(to: GPUSymmetricLimiterLedger.self)
        var total = MetalSymmetricLimiterLedgerRaw()
        for index in 0..<partialCount {
            total.add(pointer[index])
        }
        return total
    }

    private func encodeRadialLimiterReduction(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let conservationLedgerCells,
              let radialLimiterBins,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode radial limiter localization."
            )
        }
        var ledgerBounds = bounds
        var diameterCells = Float(characteristicLengthCells)
        encoder.setBuffer(conservationLedgerCells, offset: 0, index: 0)
        encoder.setBuffer(nextSolid, offset: 0, index: 1)
        encoder.setBuffer(radialLimiterBins, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        encoder.setBytes(
            &ledgerBounds,
            length: MemoryLayout<GPUTranslatingTopologyBounds>.stride,
            index: 4
        )
        encoder.setBuffer(parameters, offset: 0, index: 5)
        encoder.setBytes(
            &diameterCells,
            length: MemoryLayout<Float>.stride,
            index: 6
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: radialLimiterReductionPipeline,
            count: partialCount * 8
        )
        encoder.endEncoding()
    }

    private func readRadialLimiterBins() throws
        -> [MetalSymmetricLimiterRadialBinRaw]
    {
        guard let radialLimiterBins else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "radial limiter bin buffer is unavailable"
            )
        }
        let pointer = radialLimiterBins.contents()
            .assumingMemoryBound(to: GPUSymmetricLimiterRadialBin.self)
        var norms = Array(repeating: SIMD4<Double>.zero, count: 8)
        var counts = Array(repeating: SIMD4<UInt64>.zero, count: 8)
        for partial in 0..<partialCount {
            for bin in 0..<8 {
                let value = pointer[partial * 8 + bin]
                norms[bin] += doubleVector(value.norms)
                counts[bin] &+= SIMD4<UInt64>(
                    UInt64(value.counts.x),
                    UInt64(value.counts.y),
                    UInt64(value.counts.z),
                    UInt64(value.counts.w)
                )
            }
        }
        return (0..<8).map { index in
            return MetalSymmetricLimiterRadialBinRaw(
                norms: norms[index],
                fluidCellCount: Int(counts[index].x),
                activatedCellCount: Int(counts[index].y),
                boundaryLinkCount: Int(counts[index].z),
                activatedBoundaryLinkCount: Int(counts[index].w)
            )
        }
    }

    private func encodeTRTCollisionDecomposition(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        targetCell: SIMD3<UInt32>
    ) throws {
        guard targetCell.x < UInt32(configuration.grid.x),
              targetCell.y < UInt32(configuration.grid.y),
              targetCell.z < UInt32(configuration.grid.z) else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "TRT decomposition target lies outside the domain"
            )
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode the TRT collision decomposition."
            )
        }
        var targetGID = targetCell.x
            + UInt32(configuration.grid.x)
                * (targetCell.y
                    + UInt32(configuration.grid.y) * targetCell.z)
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(nextSolid, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(trtCollisionTerms, offset: 0, index: 4)
        encoder.setBuffer(trtCollisionSummary, offset: 0, index: 5)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 6
        )
        encoder.setBytes(
            &targetGID,
            length: MemoryLayout<UInt32>.stride,
            index: 7
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: trtCollisionDecompositionPipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func readTRTCollisionDecomposition()
        -> MetalTRTCollisionCapture
    {
        let summary = trtCollisionSummary.contents()
            .assumingMemoryBound(to: GPUTRTCollisionSummary.self).pointee
        let pointer = trtCollisionTerms.contents()
            .assumingMemoryBound(to: GPUTRTCollisionTerm.self)
        let terms = Array(
            UnsafeBufferPointer(start: pointer, count: D3Q19.count)
        )
        return MetalTRTCollisionCapture(
            macroscopic: summary.macroscopic,
            relaxation: summary.relaxation,
            limiter: summary.limiter,
            metadata: summary.metadata,
            terms: terms
        )
    }

    private func encodePopulationMinimum(
        commandBuffer: MTLCommandBuffer,
        populations: MTLBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode the population-minimum reduction."
            )
        }
        var populationCount = UInt32(
            D3Q19.count * configuration.grid.cellCount
        )
        encoder.setBuffer(populations, offset: 0, index: 0)
        encoder.setBuffer(populationMinimumPartials, offset: 0, index: 1)
        encoder.setBytes(
            &populationCount,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: populationMinimumPipeline,
            count: Int(populationCount),
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func readPopulationMinimum() -> MetalPopulationMinimumRecord {
        let pointer = populationMinimumPartials.contents()
            .assumingMemoryBound(to: GPUPopulationMinimum.self)
        var selected = pointer[0]
        if populationPartialCount > 1 {
            for index in 1..<populationPartialCount {
                let candidate = pointer[index]
                if candidate.comparisonValue < selected.comparisonValue
                    || (candidate.comparisonValue == selected.comparisonValue
                        && candidate.linearIndex < selected.linearIndex) {
                    selected = candidate
                }
            }
        }
        return MetalPopulationMinimumRecord(
            rawValue: selected.rawValue,
            linearIndex: selected.linearIndex,
            nonFinite: selected.nonFinite != 0
        )
    }

    private func makeUniforms(time: Float) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: time,
            // stepFluidTRT consumes geometry-preserved covered momentum before
            // publishing the solid-node wall state, so field capture must be
            // safe to combine with conservative topology accounting.
            captureMacroscopicFields: captureMacroscopicFields,
            accumulateLoads: true,
            hasPreviousGeometry: true,
            periodicBoundaries: periodicBoundaries,
            caseParameters: SIMD4<Float>(
                0,
                Float(linkForceMode),
                1,
                positivityPreservingRecursiveRegularizedCollisionEnabled
                    ? -4
                    : (positivityPreservingRegularizedCollisionEnabled
                        ? -3
                        : (symmetricPositivityLimiterEnabled ? -2 : -1))
            )
        )
    }

    private func initializeTopologyCanonical() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to initialize translating-body topology canonical."
            )
        }
        var uniforms = makeUniforms(time: 0)
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(solidA, offset: 0, index: 1)
        encoder.setBuffer(solidB, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(density, offset: 0, index: 4)
        encoder.setBuffer(velocity, offset: 0, index: 5)
        encoder.setBuffer(parameters, offset: 0, index: 6)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: initializePipeline,
            count: configuration.grid.cellCount
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
    }

    private func encodeTopologyGeometry(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode translating-body topology."
            )
        }
        encoder.setBuffer(nextSolid, offset: 0, index: 0)
        encoder.setBuffer(wallVelocity, offset: 0, index: 1)
        encoder.setBuffer(currentSolid, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        encoder.setBuffer(currentPopulations, offset: 0, index: 5)
        encoder.setBuffer(velocity, offset: 0, index: 6)
        backend.dispatch1D(
            encoder: encoder,
            pipeline: geometryPipeline,
            count: configuration.grid.cellCount
        )
        encoder.endEncoding()
    }

    private func encodeTopologyFluid(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode translating-body fluid step."
            )
        }
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(currentSolid, offset: 0, index: 2)
        encoder.setBuffer(nextSolid, offset: 0, index: 3)
        encoder.setBuffer(wallVelocity, offset: 0, index: 4)
        encoder.setBuffer(density, offset: 0, index: 5)
        encoder.setBuffer(velocity, offset: 0, index: 6)
        encoder.setBuffer(loadReductionA, offset: 0, index: 7)
        encoder.setBuffer(bodyState, offset: 0, index: 8)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 9
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: fluidPipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func encodeTopologyLoadReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        var input = loadReductionA
        var output = loadReductionB
        var count = partialCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to reduce translating-body load."
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
                pipeline: loadReductionPipeline,
                count: outputCount
            )
            encoder.endEncoding()
            count = outputCount
            input = output
            output = output === loadReductionA
                ? loadReductionB
                : loadReductionA
        }
        return input
    }

    private func encodeTopologyBudgetBefore(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws -> MTLBuffer {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to measure pre-step momentum."
            )
        }
        var localBounds = bounds
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(budgetBeforeA, offset: 0, index: 2)
        encoder.setBytes(
            &localBounds,
            length: MemoryLayout<GPUTranslatingTopologyBounds>.stride,
            index: 3
        )
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: budgetBeforePipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
        return try encodeTopologyBudgetReduction(
            commandBuffer: commandBuffer,
            input: budgetBeforeA,
            scratch: budgetBeforeB
        )
    }

    private func encodeTopologyBudgetAfter(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws -> MTLBuffer {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to measure post-step momentum."
            )
        }
        var localBounds = bounds
        encoder.setBuffer(nextPopulations, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(nextSolid, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(velocity, offset: 0, index: 4)
        encoder.setBuffer(budgetAfterA, offset: 0, index: 5)
        encoder.setBytes(
            &localBounds,
            length: MemoryLayout<GPUTranslatingTopologyBounds>.stride,
            index: 6
        )
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: budgetAfterPipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
        return try encodeTopologyBudgetReduction(
            commandBuffer: commandBuffer,
            input: budgetAfterA,
            scratch: budgetAfterB
        )
    }

    private func encodeTopologyBudgetReduction(
        commandBuffer: MTLCommandBuffer,
        input initialInput: MTLBuffer,
        scratch initialScratch: MTLBuffer
    ) throws -> MTLBuffer {
        var input = initialInput
        var output = initialScratch
        var count = partialCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to reduce translating-body momentum budget."
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
                pipeline: budgetReductionPipeline,
                count: outputCount
            )
            encoder.endEncoding()
            count = outputCount
            input = output
            output = output === initialInput
                ? initialScratch
                : initialInput
        }
        return input
    }

    private func vector(_ value: SIMD4<Float>) -> SIMD3<Float> {
        SIMD3<Float>(value.x, value.y, value.z)
    }

    private func doubleVector(_ value: SIMD4<Float>) -> SIMD4<Double> {
        SIMD4<Double>(
            Double(value.x),
            Double(value.y),
            Double(value.z),
            Double(value.w)
        )
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Unknown Metal translating-body error"
            )
        }
    }
}
#endif

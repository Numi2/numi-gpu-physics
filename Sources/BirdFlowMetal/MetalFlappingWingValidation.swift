import BirdFlowCore
import Foundation

public enum MetalFlappingWingValidationError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid prescribed flapping-wing request: \(message)"
        case .failed(let message):
            return "Prescribed flapping-wing validation failed: \(message)"
        }
    }
}

public struct PrescribedWingKinematicState: Codable, Sendable {
    public let phase: Double
    public let strokeAngleRadians: Double
    public let strokeRateRadiansPerCycle: Double
    public let pitchAngleRadians: Double
    public let pitchRateRadiansPerCycle: Double
}

public struct MetalFlappingWingPhaseSample: Codable, Sendable {
    public let phase: Double
    public let liftCoefficient: Double
    public let dragCoefficient: Double
    public let forceX: Double
    public let forceY: Double
    public let forceZ: Double
}

public struct MetalFlappingWingLoadComponentSummary: Codable, Sendable {
    public let meanLiftCoefficient: Double
    public let meanDragCoefficient: Double
    public let rmsLiftCoefficient: Double
    public let rmsDragCoefficient: Double
    public let maximumAbsoluteLiftCoefficient: Double
    public let maximumAbsoluteDragCoefficient: Double
    public let maximumAbsoluteLiftPhase: Double
    public let maximumAbsoluteDragPhase: Double
    public let phaseSamples: [MetalFlappingWingPhaseSample]
}

public struct MetalFlappingWingLoadDecompositionReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let chordCells: Int
    public let cycles: Int
    public let runtimeSeconds: Double
    public let total: MetalFlappingWingLoadComponentSummary
    public let linkExchange: MetalFlappingWingLoadComponentSummary
    public let coverUncoverImpulse: MetalFlappingWingLoadComponentSummary
    public let topologyMeanLiftFraction: Double
    public let topologyMeanDragFraction: Double
    public let topologyRMSLiftFraction: Double
    public let topologyRMSDragFraction: Double
    public let maximumLiftCoefficientClosureError: Double
    public let maximumDragCoefficientClosureError: Double
    public let maximumForceClosureError: Double
    public let maximumAllowedCoefficientClosureError: Double
    public let closurePassed: Bool
}

public struct MetalFlappingWingLinkForceComparisonReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let chordCells: Int
    public let cycles: Int
    public let runtimeSeconds: Double
    public let sourceDOI: String
    public let galileanInvariantEstimatorDOI: String
    public let galileanInvariantLinkExchange: MetalFlappingWingLoadComponentSummary
    public let interpolatedPopulationConventionalLinkExchange: MetalFlappingWingLoadComponentSummary
    public let coverUncoverImpulse: MetalFlappingWingLoadComponentSummary
    public let galileanInvariantTotal: MetalFlappingWingLoadComponentSummary
    public let conventionalMovingBodyTotal: MetalFlappingWingLoadComponentSummary
    public let conventionalToGalileanMeanLiftRatio: Double
    public let conventionalToGalileanMeanDragRatio: Double
    public let galileanInvariantRelativeMeanLiftError: Double
    public let galileanInvariantRelativeMeanDragError: Double
    public let conventionalRelativeMeanLiftError: Double
    public let conventionalRelativeMeanDragError: Double
    public let maximumLinkLiftCoefficientDifference: Double
    public let maximumLinkDragCoefficientDifference: Double
    public let maximumGalileanInvariantLiftClosureError: Double
    public let maximumGalileanInvariantDragClosureError: Double
    public let maximumGalileanInvariantForceClosureError: Double
    public let maximumAllowedCoefficientClosureError: Double
    public let closurePassed: Bool
}

public struct MetalFlappingWingLinkNumeratorComponent: Codable, Sendable {
    public let name: String
    public let equation: String
    public let load: MetalFlappingWingLoadComponentSummary
    public let meanLiftFractionOfGalileanInvariantLink: Double
    public let meanDragFractionOfGalileanInvariantLink: Double
    public let rmsLiftFractionOfGalileanInvariantLink: Double
    public let rmsDragFractionOfGalileanInvariantLink: Double
}

public struct MetalFlappingWingLinkNumeratorDecompositionReport:
    Codable, Sendable
{
    public let schemaVersion: Int
    public let deviceName: String
    public let chordCells: Int
    public let cycles: Int
    public let runtimeSeconds: Double
    public let galileanInvariantLinkExchange:
        MetalFlappingWingLoadComponentSummary
    public let conventionalLinkExchange:
        MetalFlappingWingLoadComponentSummary
    public let components: [MetalFlappingWingLinkNumeratorComponent]
    public let dominantMeanLiftComponent: String
    public let dominantMeanDragComponent: String
    public let maximumConventionalLiftClosureError: Double
    public let maximumConventionalDragClosureError: Double
    public let maximumConventionalForceClosureError: Double
    public let maximumGalileanInvariantLiftClosureError: Double
    public let maximumGalileanInvariantDragClosureError: Double
    public let maximumGalileanInvariantForceClosureError: Double
    public let maximumAllowedCoefficientClosureError: Double
    public let closurePassed: Bool
}

public struct MetalFlappingWingControlVolumeBounds: Codable, Sendable {
    public let minimumX: Int
    public let minimumY: Int
    public let minimumZ: Int
    public let maximumExclusiveX: Int
    public let maximumExclusiveY: Int
    public let maximumExclusiveZ: Int
}

public struct MetalFlappingWingMomentumBudgetReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let chordCells: Int
    public let cycles: Int
    public let runtimeSeconds: Double
    public let controlVolume: MetalFlappingWingControlVolumeBounds
    public let spongeWidthCells: Int
    public let minimumControlSurfaceDistanceFromDomainBoundaryCells: Int
    public let maximumSolidControlSurfaceCrossingLinkCount: Int
    public let galileanInvariantBoundaryLoad:
        MetalFlappingWingLoadComponentSummary
    public let conventionalBoundaryLoad:
        MetalFlappingWingLoadComponentSummary
    public let conservativeMovingDomainBoundaryLoad:
        MetalFlappingWingLoadComponentSummary
    public let conservativeCorrectionRelativeToConventionalBoundaryLoad:
        MetalFlappingWingLoadComponentSummary
    public let negativeFluidMomentumStorageRate:
        MetalFlappingWingLoadComponentSummary
    public let negativeControlSurfaceMomentumFlux:
        MetalFlappingWingLoadComponentSummary
    public let topologyReservoirCorrection:
        MetalFlappingWingLoadComponentSummary
    public let rawFluidMomentumBudget:
        MetalFlappingWingLoadComponentSummary
    public let independentFluidMomentumBudget:
        MetalFlappingWingLoadComponentSummary
    public let galileanInvariantResidual:
        MetalFlappingWingLoadComponentSummary
    public let conventionalResidual:
        MetalFlappingWingLoadComponentSummary
    public let conservativeMovingDomainResidual:
        MetalFlappingWingLoadComponentSummary
    public let maximumGalileanInvariantLiftCoefficientResidual: Double
    public let maximumGalileanInvariantDragCoefficientResidual: Double
    public let maximumGalileanInvariantForceResidual: Double
    public let maximumConventionalLiftCoefficientResidual: Double
    public let maximumConventionalDragCoefficientResidual: Double
    public let maximumConventionalForceResidual: Double
    public let maximumConservativeLiftCoefficientResidual: Double
    public let maximumConservativeDragCoefficientResidual: Double
    public let maximumConservativeForceResidual: Double
    public let galileanInvariantMeanLiftBiasFactor: Double
    public let galileanInvariantMeanDragBiasFactor: Double
    public let conventionalMeanLiftBiasFactor: Double
    public let conventionalMeanDragBiasFactor: Double
    public let maximumAllowedCoefficientResidual: Double
    public let controlSurfaceClearOfSolid: Bool
    public let controlSurfaceOutsideSponge: Bool
    public let conventionalClosurePassed: Bool
    public let conservativeMovingDomainClosurePassed: Bool
    public let boundaryLoadBiasDetected: Bool
    public let classification: String
}

private enum PrescribedWingLoadComponent: Float {
    case total = 0
    case linkExchange = 1
    case coverUncoverImpulse = 2
}

private enum PrescribedWingLinkForceEstimator: Float {
    case galileanInvariant = 0
    case conventional = 1
    case baseReflection = 2
    case movingWallPopulationCorrection = 3
    case interpolationResidual = 4
    case galileanWallFrameCorrection = 5
    case conservativeMovingDomain = 6
}

private struct GPUControlVolumeBounds {
    var minimum: SIMD4<UInt32>
    var maximumExclusive: SIMD4<UInt32>
}

private struct GPUControlVolumeBudget {
    var oldFluidMomentum: SIMD4<Float>
    var newFluidMomentum: SIMD4<Float>
    var outwardMomentumFlux: SIMD4<Float>
    var topologyReservoirCorrection: SIMD4<Float>

    static let zero = GPUControlVolumeBudget(
        oldFluidMomentum: .zero,
        newFluidMomentum: .zero,
        outwardMomentumFlux: .zero,
        topologyReservoirCorrection: .zero
    )
}

private struct PrescribedWingMomentumBudgetStep {
    let negativeStorage: ForceTorque
    let negativeSurfaceFlux: ForceTorque
    let topologyReservoirCorrection: ForceTorque
    let rawTotal: ForceTorque
    let total: ForceTorque
    let solidControlSurfaceCrossingLinkCount: Int
}

private struct PrescribedWingMomentumBudgetCaseResult {
    let boundaryLoad: [MetalFlappingWingPhaseSample]
    let negativeStorage: [MetalFlappingWingPhaseSample]
    let negativeSurfaceFlux: [MetalFlappingWingPhaseSample]
    let topologyReservoirCorrection: [MetalFlappingWingPhaseSample]
    let rawTotal: [MetalFlappingWingPhaseSample]
    let total: [MetalFlappingWingPhaseSample]
    let controlVolume: MetalFlappingWingControlVolumeBounds
    let spongeWidthCells: Int
    let minimumControlSurfaceDistanceFromDomainBoundaryCells: Int
    let maximumSolidControlSurfaceCrossingLinkCount: Int
}

public struct MetalFlappingWingVortexMetric: Codable, Sendable {
    public let phase: Double
    public let maximumPositiveQ: Double
    public let positiveQCellCount: Int
    public let maximumVorticityMagnitude: Double
}

public struct MetalFlappingWingCaseResult: Codable, Sendable {
    public let chordCells: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cycleSteps: Int
    public let cycles: Int
    public let steps: Int
    public let runtimeSeconds: Double
    public let effectiveThicknessToChord: Double
    public let actualRadiusOfGyrationSpeed: Double
    public let actualReynoldsNumber: Double
    public let meanLiftCoefficient: Double
    public let meanDragCoefficient: Double
    public let relativeMeanLiftError: Double
    public let relativeMeanDragError: Double
    public let firstHalfPeakLiftPhase: Double
    public let secondHalfPeakLiftPhase: Double
    public let meanMidstrokeLiftCoefficient: Double
    public let meanReversalLiftCoefficient: Double
    public let halfStrokeSymmetryError: Double
    public let previousCycleDifference: Double
    public let vortexTimingCoverageComplete: Bool
    public let phaseSamples: [MetalFlappingWingPhaseSample]
    public let vortexMetrics: [MetalFlappingWingVortexMetric]
}

public struct MetalMeasuredWingSurfacePhaseAudit: Codable, Sendable {
    public let phase: Double
    public let solidCellCount: Int
    public let minimumBoundaryLinkFraction: Double
    public let maximumBoundaryLinkFraction: Double
    public let maximumLatticeWallSpeed: Double
}

public struct MetalMeasuredWingSurfaceReplayReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let scientificTier: String
    public let sourceDatasetDOI: String
    public let sourceMD5: String
    public let inputSHA256: String
    public let completeBirdReplayReady: Bool
    public let chordCells: Int
    public let cycleSteps: Int
    public let runtimeSeconds: Double
    public let halfThicknessCells: Double
    public let maximumPhysicalPointSpeedMetersPerSecond: Double
    public let maximumLatticePointSpeed: Double
    public let diagnosticReynoldsNumber: Double
    public let diagnosticAirDensityKilogramsPerCubicMeter: Double
    public let maximumPreparedPositionErrorMeters: Double
    public let maximumPreparedVelocityErrorMetersPerSecond: Double
    public let geometryKernelSequence: [String]
    public let productionFluidKernel: String
    public let phaseAudits: [MetalMeasuredWingSurfacePhaseAudit]
    public let fluidCycleExecuted: Bool
    public let startupCycleMeanForceNewtons: [Double]?
    public let passed: Bool
}

public struct MetalMeasuredWingThicknessSensitivityReport: Codable, Sendable {
    public let schemaVersion: Int
    public let datasetIdentifier: String
    public let inputSHA256: String
    public let chordCells: Int
    public let runtimeSeconds: Double
    public let baselineHalfThicknessCells: Double
    public let maximumAllowedRelativeSensitivity: Double
    public let maximumPairwiseRelativeMeanForceVectorDifference: Double
    public let relativeMeanVerticalForceEnvelope: Double
    public let allCaseGeometryAndFluidPassed: Bool
    public let classification: String
    public let passed: Bool
    public let cases: [MetalMeasuredWingSurfaceReplayReport]
}

public struct MetalFlappingWingValidationReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let geometryKernel: String
    public let passed: Bool
    public let runtimeSeconds: Double
    public let sourceDOI: String
    public let sourceDescription: String
    public let reynoldsNumber: Double
    public let aspectRatio: Double
    public let radialCentroid: Double
    public let radiusOfGyration: Double
    public let strokeAmplitudeDegrees: Double
    public let pitchAmplitudeDegrees: Double
    public let referenceMeanLiftCoefficient: Double
    public let referenceMeanDragCoefficient: Double
    public let maximumAllowedMeanCoefficientError: Double
    public let maximumAllowedFinestTwoChange: Double
    public let maximumAllowedHalfStrokeSymmetryError: Double
    public let maximumAllowedPreviousCycleDifference: Double
    public let minimumAllowedMidstrokeLiftCoefficient: Double
    public let maximumBatchDensityDifference: Double
    public let maximumBatchVelocityDifference: Double
    public let maximumBatchForceDifference: Double
    public let maximumAllowedBatchDifference: Double
    public let relativeFinestTwoLiftChange: Double
    public let relativeFinestTwoDragChange: Double
    public let cases: [MetalFlappingWingCaseResult]
}

public struct MetalFlappingWingGeometryAudit: Codable, Sendable {
    public let phase: Double
    public let analyticSolidCellCount: Int
    public let metalSolidCellCount: Int
    public let mismatchedCellCount: Int
    public let mismatchedCellFraction: Double
    public let normalizedVoxelVolume: Double
    public let normalizedPublishedThicknessVoxelVolume: Double
    public let normalizedRadialCentroid: Double
    public let normalizedRadiusOfGyration: Double
    public let maximumSolidWallVelocityError: Double
    public let boundaryLinkCount: Int
    public let auditedBoundaryLinkCount: Int
    public let maximumLinkFractionError: Double
    public let meanLinkFractionError: Double
    public let maximumHalfwayWallPositionErrorCells: Double
    public let maximumInterpolatedWallPositionErrorCells: Double
}

public struct MetalFlappingWingInputAudit: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let sourceDOI: String
    public let chordCells: Int
    public let analyticInputsPassed: Bool
    public let metalGeometryPassed: Bool
    public let passed: Bool
    public let betaNormalizationFromGamma: Double
    public let normalizedPlanformArea: Double
    public let normalizedRadialCentroid: Double
    public let normalizedRadiusOfGyration: Double
    public let integratedStrokeTravelRadians: Double
    public let expectedStrokeTravelRadians: Double
    public let integratedPitchTravelRadians: Double
    public let expectedPitchTravelRadians: Double
    public let maximumStrokeDerivativeError: Double
    public let maximumPitchDerivativeError: Double
    public let cycleSteps: Int
    public let radiusOfGyrationSpeed: Double
    public let referenceArea: Double
    public let coefficientDenominator: Double
    public let geometry: [MetalFlappingWingGeometryAudit]
}

public struct MetalFlappingWingInputAuditReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let sourceDOI: String
    public let finestChordCells: Int
    public let passed: Bool
    public let cases: [MetalFlappingWingInputAudit]
}

/// Published rigid, prescribed hovering-wing benchmark from Li and Nabawy,
/// Insects 13 (2022) 459, baseline AR=3, r1/R=0.5, root offset zero.
public enum MetalFlappingWingValidator {
    public static let sourceDOI = "10.3390/insects13050459"
    public static let galileanInvariantEstimatorDOI =
        "10.1016/j.jcp.2014.02.018"
    public static let sourceDescription =
        "Li and Nabawy (2022), Re=100 beta-planform baseline: AR=3, r1/R=0.5, zero root offset; Table 2 gives fifth-cycle mean CL=1.460 and CD=2.046"
    public static let reynoldsNumber = 100.0
    public static let aspectRatio = 3.0
    public static let radialCentroid = 0.5
    public static let radiusOfGyration = 0.559_321_813_581_992_6
    public static let betaShape = 1.489_150_658_355_784_5
    public static let betaNormalization = 2.497_931_737_168_364
    public static let strokeAmplitudeDegrees = 160.0
    public static let strokeHalfAmplitudeRadians = 80.0 * Double.pi / 180
    public static let pitchAmplitudeDegrees = 90.0
    public static let accelerationDuration = 0.25
    public static let pitchDuration = 0.25
    public static let latticeRadiusOfGyrationSpeed = 0.035
    public static let referenceMeanLiftCoefficient = 1.460
    public static let referenceMeanDragCoefficient = 2.046
    public static let maximumMeanCoefficientError = 0.30
    public static let maximumFinestTwoChange = 0.05
    public static let maximumHalfStrokeSymmetryError = 0.15
    public static let maximumPreviousCycleDifference = 0.15
    public static let minimumMidstrokeLiftCoefficient = 1.0
    public static let maximumBatchDifference = 1.0e-7
    public static let domainHorizontalChords = 10
    public static let domainVerticalChords = 8
    public static let requiredVortexPhases = [0.55, 0.65, 0.75, 0.85, 0.95]

    public static var maximumStrokeRateRadiansPerCycle: Double {
        2 * strokeHalfAmplitudeRadians
            / (accelerationDuration + 2 * accelerationDuration / Double.pi)
    }

    public static var cycleTravelPerChord: Double {
        4 * strokeHalfAmplitudeRadians * radiusOfGyration * aspectRatio
    }

    public static func kinematicState(
        phase rawPhase: Double
    ) -> PrescribedWingKinematicState {
        let phase = rawPhase - floor(rawPhase)
        let duration = accelerationDuration
        let halfDuration = 0.5 * duration
        let maximumRate = maximumStrokeRateRadiansPerCycle
        let stroke: Double
        let strokeRate: Double
        if phase < halfDuration {
            let argument = Double.pi * (phase + halfDuration) / duration
            stroke = strokeHalfAmplitudeRadians
                + maximumRate * duration / Double.pi
                * (sin(argument) - 1)
            strokeRate = maximumRate * cos(argument)
        } else if phase < 0.5 - halfDuration {
            let transitionEnd = strokeHalfAmplitudeRadians
                - maximumRate * duration / Double.pi
            stroke = transitionEnd
                - maximumRate * (phase - halfDuration)
            strokeRate = -maximumRate
        } else if phase < 0.5 + halfDuration {
            let start = 0.5 - halfDuration
            let transitionStart = -strokeHalfAmplitudeRadians
                + maximumRate * duration / Double.pi
            let argument = Double.pi * (phase - start) / duration
            stroke = transitionStart
                - maximumRate * duration / Double.pi * sin(argument)
            strokeRate = -maximumRate * cos(argument)
        } else if phase < 1 - halfDuration {
            let transitionEnd = -strokeHalfAmplitudeRadians
                + maximumRate * duration / Double.pi
            stroke = transitionEnd
                + maximumRate * (phase - (0.5 + halfDuration))
            strokeRate = maximumRate
        } else {
            let start = 1 - halfDuration
            let transitionStart = strokeHalfAmplitudeRadians
                - maximumRate * duration / Double.pi
            let argument = Double.pi * (phase - start) / duration
            stroke = transitionStart
                + maximumRate * duration / Double.pi * sin(argument)
            strokeRate = maximumRate * cos(argument)
        }

        let low = 45.0 * Double.pi / 180
        let high = 135.0 * Double.pi / 180
        let pitchHalfDuration = 0.5 * pitchDuration
        let pitch: Double
        let pitchRate: Double
        if phase < pitchHalfDuration || phase >= 1 - pitchHalfDuration {
            let wrapped = phase < pitchHalfDuration ? phase + 1 : phase
            let x = (wrapped - (1 - pitchHalfDuration)) / pitchDuration
            let change = low - high
            pitch = high + change
                * (x - sin(2 * Double.pi * x) / (2 * Double.pi))
            pitchRate = change / pitchDuration
                * (1 - cos(2 * Double.pi * x))
        } else if phase >= 0.5 - pitchHalfDuration
                    && phase < 0.5 + pitchHalfDuration {
            let x = (phase - (0.5 - pitchHalfDuration)) / pitchDuration
            let change = high - low
            pitch = low + change
                * (x - sin(2 * Double.pi * x) / (2 * Double.pi))
            pitchRate = change / pitchDuration
                * (1 - cos(2 * Double.pi * x))
        } else {
            pitch = phase < 0.5 ? low : high
            pitchRate = 0
        }
        return PrescribedWingKinematicState(
            phase: phase,
            strokeAngleRadians: stroke,
            strokeRateRadiansPerCycle: strokeRate,
            pitchAngleRadians: pitch,
            pitchRateRadiansPerCycle: pitchRate
        )
    }

    /// Independently reconstructs the paper's analytic planform, kinematic
    /// integrals, coefficient scales, and CPU voxel mask before comparing the
    /// latter with the production Metal geometry kernel at four phases.
    public static func auditInputs(
        chordCells: Int = 16
    ) throws -> MetalFlappingWingInputAudit {
        guard chordCells >= 8 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "input-audit chord resolution must be at least 8"
            )
        }
#if canImport(Metal)
        return try runInputAudit(chordCells: chordCells)
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func auditInputLadder(
        finestChordCells: Int = 16
    ) throws -> MetalFlappingWingInputAuditReport {
        guard finestChordCells >= 16,
              finestChordCells.isMultiple(of: 8) else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "input-audit finest chord resolution must be a multiple of 8 and at least 16"
            )
        }
        let chords = [
            finestChordCells / 2,
            finestChordCells * 3 / 4,
            finestChordCells,
        ]
        let cases = try chords.map { try auditInputs(chordCells: $0) }
        return MetalFlappingWingInputAuditReport(
            schemaVersion: 1,
            deviceName: cases.first?.deviceName ?? "Unavailable",
            sourceDOI: sourceDOI,
            finestChordCells: finestChordCells,
            passed: cases.allSatisfy(\.passed),
            cases: cases
        )
    }

    /// One diagnostic grid. Five cycles reproduce the paper's sampling window;
    /// fewer cycles are intentionally labelled diagnostic by the CLI.
    public static func runSingleCase(
        chordCells: Int = 8,
        cycles: Int = 5,
        archiveDirectory: URL? = nil
    ) throws -> MetalFlappingWingCaseResult {
        guard chordCells >= 8, cycles >= 1 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "chord resolution must be at least 8 and cycles must be positive"
            )
        }
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        return try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: archiveDirectory
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    /// Runs identical prescribed-fluid histories with total, link-only, and
    /// cover/uncover-only load selection. Loads do not feed back into this
    /// fixed-kinematics case, so component selection cannot alter the flow.
    public static func diagnoseLoadDecomposition(
        chordCells: Int = 8,
        cycles: Int = 1
    ) throws -> MetalFlappingWingLoadDecompositionReport {
        guard chordCells >= 8, cycles >= 1 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "load decomposition requires at least 8 chord cells and one cycle"
            )
        }
#if canImport(Metal)
        let started = Date()
        let backend = try MetalBackend(fastMath: false)
        let total = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .total,
            captureVortexDiagnostics: false
        )
        let link = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .linkExchange,
            captureVortexDiagnostics: false
        )
        let topology = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .coverUncoverImpulse,
            captureVortexDiagnostics: false
        )
        return loadDecompositionReport(
            deviceName: backend.device.name,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: Date().timeIntervalSince(started),
            total: total.phaseSamples,
            link: link.phaseSamples,
            topology: topology.phaseSamples
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    /// Compares the two source-backed link momentum-exchange equations on
    /// identical prescribed flow histories. The conventional estimator uses
    /// the populations already reconstructed by the interpolated boundary;
    /// cover/uncover impulse is then added separately for its moving-body
    /// total. A fourth run preserves an independent algebraic closure check
    /// for the legacy Galilean-invariant total.
    public static func compareLinkForceEstimators(
        chordCells: Int = 8,
        cycles: Int = 1
    ) throws -> MetalFlappingWingLinkForceComparisonReport {
        guard chordCells >= 8, cycles >= 1 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "link-force comparison requires at least 8 chord cells and one cycle"
            )
        }
#if canImport(Metal)
        let started = Date()
        let backend = try MetalBackend(fastMath: false)
        let galileanInvariantTotal = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .total,
            linkForceEstimator: .galileanInvariant,
            captureVortexDiagnostics: false
        )
        let galileanInvariantLink = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .linkExchange,
            linkForceEstimator: .galileanInvariant,
            captureVortexDiagnostics: false
        )
        let conventionalLink = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .linkExchange,
            linkForceEstimator: .conventional,
            captureVortexDiagnostics: false
        )
        let topology = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .coverUncoverImpulse,
            linkForceEstimator: .galileanInvariant,
            captureVortexDiagnostics: false
        )
        return linkForceComparisonReport(
            deviceName: backend.device.name,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: Date().timeIntervalSince(started),
            galileanInvariantTotal: galileanInvariantTotal.phaseSamples,
            galileanInvariantLink: galileanInvariantLink.phaseSamples,
            conventionalLink: conventionalLink.phaseSamples,
            topology: topology.phaseSamples
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    /// Splits the link-force numerator into algebraically independent terms
    /// while replaying identical fixed-kinematics flow histories. Each run
    /// changes only a dispatch-uniform load selector, so populations and wall
    /// motion remain identical and no component-sized GPU buffers are added.
    public static func diagnoseLinkNumeratorDecomposition(
        chordCells: Int = 8,
        cycles: Int = 1
    ) throws -> MetalFlappingWingLinkNumeratorDecompositionReport {
        guard chordCells >= 8, cycles >= 1 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "link numerator decomposition requires at least 8 chord cells and one cycle"
            )
        }
#if canImport(Metal)
        let started = Date()
        let backend = try MetalBackend(fastMath: false)
        func linkRun(
            _ estimator: PrescribedWingLinkForceEstimator
        ) throws -> MetalFlappingWingCaseResult {
            try runCase(
                backend: backend,
                chordCells: chordCells,
                cycles: cycles,
                archiveDirectory: nil,
                loadComponent: .linkExchange,
                linkForceEstimator: estimator,
                captureVortexDiagnostics: false
            )
        }
        let galileanInvariant = try linkRun(.galileanInvariant)
        let conventional = try linkRun(.conventional)
        let baseReflection = try linkRun(.baseReflection)
        let movingWall = try linkRun(.movingWallPopulationCorrection)
        let interpolation = try linkRun(.interpolationResidual)
        let galileanWallFrame = try linkRun(.galileanWallFrameCorrection)
        return linkNumeratorDecompositionReport(
            deviceName: backend.device.name,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: Date().timeIntervalSince(started),
            galileanInvariant: galileanInvariant.phaseSamples,
            conventional: conventional.phaseSamples,
            baseReflection: baseReflection.phaseSamples,
            movingWallPopulationCorrection: movingWall.phaseSamples,
            interpolationResidual: interpolation.phaseSamples,
            galileanWallFrameCorrection: galileanWallFrame.phaseSamples
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    /// Closes the moving-boundary load against a fixed near-wing control
    /// volume. The independent budget uses fluid momentum storage and the
    /// post-collision population flux through a surface that is clear of both
    /// the swept wing and the sponge. A separate topology-reservoir term
    /// accounts for equilibrium momentum inserted or removed as lattice cells
    /// uncover or cover; it does not reuse the link-force accumulator.
    public static func diagnoseNearWingMomentumBudget(
        chordCells: Int = 8,
        cycles: Int = 1
    ) throws -> MetalFlappingWingMomentumBudgetReport {
        guard chordCells >= 8, cycles >= 1 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "momentum budget requires at least 8 chord cells and one cycle"
            )
        }
#if canImport(Metal)
        let started = Date()
        let backend = try MetalBackend(fastMath: false)
        let galilean = try runMomentumBudgetCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles
        )
        let conventional = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .total,
            linkForceEstimator: .conventional,
            captureVortexDiagnostics: false
        )
        let conservative = try runCase(
            backend: backend,
            chordCells: chordCells,
            cycles: cycles,
            archiveDirectory: nil,
            loadComponent: .total,
            linkForceEstimator: .conservativeMovingDomain,
            captureVortexDiagnostics: false
        )
        return momentumBudgetReport(
            deviceName: backend.device.name,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: Date().timeIntervalSince(started),
            galilean: galilean,
            conventionalBoundaryLoad: conventional.phaseSamples,
            conservativeBoundaryLoad: conservative.phaseSamples
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func run(
        finestChordCells: Int = 16,
        archiveDirectory: URL? = nil
    ) throws -> MetalFlappingWingValidationReport {
        guard finestChordCells >= 16,
              finestChordCells.isMultiple(of: 8) else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "finest chord resolution must be a multiple of 8 and at least 16"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let chords = [
            finestChordCells / 2,
            finestChordCells * 3 / 4,
            finestChordCells,
        ]
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
        }
        var results: [MetalFlappingWingCaseResult] = []
        for chord in chords {
            results.append(try runCase(
                backend: backend,
                chordCells: chord,
                cycles: 5,
                archiveDirectory: archiveDirectory?.appendingPathComponent(
                    "chord-\(chord)",
                    isDirectory: true
                )
            ))
        }
        let next = results[results.count - 2]
        let finest = results[results.count - 1]
        let liftChange = relativeChange(
            finest.meanLiftCoefficient,
            next.meanLiftCoefficient
        )
        let dragChange = relativeChange(
            finest.meanDragCoefficient,
            next.meanDragCoefficient
        )
        let batch = try batchDifference(backend: backend)
        let finite = results.allSatisfy {
            $0.meanLiftCoefficient.isFinite
                && $0.meanDragCoefficient.isFinite
                && $0.phaseSamples.allSatisfy {
                    $0.liftCoefficient.isFinite && $0.dragCoefficient.isFinite
                }
        }
        let phaseTimingPassed = (0.25...0.45).contains(
            finest.firstHalfPeakLiftPhase
        ) && (0.75...0.95).contains(finest.secondHalfPeakLiftPhase)
        let passed = finite
            && finest.relativeMeanLiftError <= maximumMeanCoefficientError
            && finest.relativeMeanDragError <= maximumMeanCoefficientError
            && liftChange <= maximumFinestTwoChange
            && dragChange <= maximumFinestTwoChange
            && finest.halfStrokeSymmetryError
                <= maximumHalfStrokeSymmetryError
            && finest.previousCycleDifference
                <= maximumPreviousCycleDifference
            && finest.meanMidstrokeLiftCoefficient
                >= minimumMidstrokeLiftCoefficient
            && phaseTimingPassed
            && results.allSatisfy(\.vortexTimingCoverageComplete)
            && batch.density <= maximumBatchDifference
            && batch.velocity <= maximumBatchDifference
            && batch.force <= maximumBatchDifference
        let report = MetalFlappingWingValidationReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            geometryKernel: "buildPrescribedFlappingWing",
            passed: passed,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            sourceDOI: sourceDOI,
            sourceDescription: sourceDescription,
            reynoldsNumber: reynoldsNumber,
            aspectRatio: aspectRatio,
            radialCentroid: radialCentroid,
            radiusOfGyration: radiusOfGyration,
            strokeAmplitudeDegrees: strokeAmplitudeDegrees,
            pitchAmplitudeDegrees: pitchAmplitudeDegrees,
            referenceMeanLiftCoefficient: referenceMeanLiftCoefficient,
            referenceMeanDragCoefficient: referenceMeanDragCoefficient,
            maximumAllowedMeanCoefficientError: maximumMeanCoefficientError,
            maximumAllowedFinestTwoChange: maximumFinestTwoChange,
            maximumAllowedHalfStrokeSymmetryError:
                maximumHalfStrokeSymmetryError,
            maximumAllowedPreviousCycleDifference:
                maximumPreviousCycleDifference,
            minimumAllowedMidstrokeLiftCoefficient:
                minimumMidstrokeLiftCoefficient,
            maximumBatchDensityDifference: batch.density,
            maximumBatchVelocityDifference: batch.velocity,
            maximumBatchForceDifference: batch.force,
            maximumAllowedBatchDifference: maximumBatchDifference,
            relativeFinestTwoLiftChange: liftChange,
            relativeFinestTwoDragChange: dragChange,
            cases: results
        )
        if let archiveDirectory {
            try archiveReport(report, directory: archiveDirectory)
        }
        return report
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

public extension MetalFlappingWingValidator {
    static func auditMeasuredSurface(
        _ dataset: MeasuredWingSurfaceDataset,
        chordCells: Int = 8,
        halfThicknessCells: Float = 0.75,
        runFluidCycle: Bool = false
    ) throws -> MetalMeasuredWingSurfaceReplayReport {
        guard chordCells >= 8 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "measured-surface chord resolution must be at least 8"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let maximumLatticeSpeed: Float = 0.08
        let referenceChordMeters: Float = 0.0195
        let rawCycleSteps = Int(ceil(
            dataset.maximumPointSpeedMetersPerSecond * Float(chordCells)
                / (referenceChordMeters * dataset.frequencyHz
                    * maximumLatticeSpeed)
        ))
        let cycleSteps = max(256, ((rawCycleSteps + 7) / 8) * 8)
        let radiusCells = Int(ceil(
            dataset.maximumRootRelativeRadiusMeters
                / (referenceChordMeters / Float(chordCells))
        ))
        // The near-wing momentum-control volume adds four cells beyond the
        // measured radius and must remain strictly outside the sponge. Scale
        // this margin with the resolution-dependent sponge instead of relying
        // on the eight-cell case's fixed ten-cell allowance.
        let spongeCells = max(4, chordCells / 2)
        let halfDomain = radiusCells + max(10, spongeCells + 5)
        let grid = try GridSize(
            x: 2 * halfDomain,
            y: 2 * halfDomain,
            z: 2 * halfDomain
        )
        let cellSize = referenceChordMeters / Float(chordCells)
        let root = SIMD3<Float>(repeating: Float(halfDomain) * cellSize)
        let backend = try MetalBackend(fastMath: false)
        let simulation = try MetalPrescribedWingSimulation(
            backend: backend,
            grid: grid,
            chordCells: chordCells,
            cycleSteps: cycleSteps,
            root: root,
            measuredSurface: dataset,
            measuredHalfThicknessCells: halfThicknessCells
        )

        var startupMean: [Double]?
        if runFluidCycle {
            _ = try simulation.advance(
                to: cycleSteps,
                batchSize: 8,
                captureFields: false,
                recordEveryStepLoad: true
            )
            let loads = simulation.copyRecordedLoads()
            let inverse = 1.0 / Double(loads.count)
            startupMean = [
                loads.reduce(0.0) { $0 + Double($1.forceNewtons.x) } * inverse,
                loads.reduce(0.0) { $0 + Double($1.forceNewtons.y) } * inverse,
                loads.reduce(0.0) { $0 + Double($1.forceNewtons.z) } * inverse,
            ]
        }

        var maximumPositionError = 0.0
        var maximumVelocityError = 0.0
        var phaseAudits: [MetalMeasuredWingSurfacePhaseAudit] = []
        for phase in dataset.phases {
            let prepared = try simulation.copyPreparedMeasuredPoints(
                phase: Double(phase)
            )
            for point in 0..<dataset.pointsPerFrame {
                let expected = dataset.state(phase: phase, pointIndex: point)
                let actual = prepared[point]
                let positionDelta = SIMD3<Float>(
                    actual.position.x,
                    actual.position.y,
                    actual.position.z
                )
                    - root - expected.positionMeters
                let velocityDelta = SIMD3<Float>(
                    actual.velocity.x,
                    actual.velocity.y,
                    actual.velocity.z
                )
                    / simulation.measuredVelocityToLattice
                    - expected.velocityMetersPerSecond
                maximumPositionError = max(
                    maximumPositionError,
                    Double(sqrt(
                        positionDelta.x * positionDelta.x
                            + positionDelta.y * positionDelta.y
                            + positionDelta.z * positionDelta.z
                    ))
                )
                maximumVelocityError = max(
                    maximumVelocityError,
                    Double(sqrt(
                        velocityDelta.x * velocityDelta.x
                            + velocityDelta.y * velocityDelta.y
                            + velocityDelta.z * velocityDelta.z
                    ))
                )
            }
            let geometry = try simulation.copyGeometry(phase: Double(phase))
            let links = geometry.boundaryLinkFractions
            let wallMaximum = geometry.wallVelocityAndImplicit.enumerated()
                .filter { geometry.solid[$0.offset] != 0 }
                .map { value -> Double in
                    let velocity = value.element
                    return Double(sqrt(
                        velocity.x * velocity.x
                            + velocity.y * velocity.y
                            + velocity.z * velocity.z
                    ))
                }
                .max() ?? 0
            phaseAudits.append(MetalMeasuredWingSurfacePhaseAudit(
                phase: Double(phase),
                solidCellCount: geometry.solid.reduce(0) {
                    $0 + ($1 == 0 ? 0 : 1)
                },
                minimumBoundaryLinkFraction: Double(links.min() ?? 0),
                maximumBoundaryLinkFraction: Double(links.max() ?? 0),
                maximumLatticeWallSpeed: wallMaximum
            ))
        }
        let finiteTopology = phaseAudits.allSatisfy {
            $0.solidCellCount > 0
                && $0.minimumBoundaryLinkFraction >= 0.999e-4
                && $0.maximumBoundaryLinkFraction <= 1
                && $0.maximumLatticeWallSpeed.isFinite
        }
        let finiteStartupForce = startupMean?.allSatisfy(\.isFinite)
            ?? !runFluidCycle
        let passed = finiteTopology
            && maximumPositionError <= 2.0e-6
            && maximumVelocityError <= 2.0e-3
            && finiteStartupForce
            && !dataset.completeBirdReplayReady
        return MetalMeasuredWingSurfaceReplayReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            datasetIdentifier: dataset.datasetIdentifier,
            scientificTier: dataset.scientificTier,
            sourceDatasetDOI: dataset.sourceDatasetDOI,
            sourceMD5: dataset.sourceMD5,
            inputSHA256: dataset.inputSHA256,
            completeBirdReplayReady: dataset.completeBirdReplayReady,
            chordCells: chordCells,
            cycleSteps: cycleSteps,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            halfThicknessCells: Double(halfThicknessCells),
            maximumPhysicalPointSpeedMetersPerSecond:
                Double(dataset.maximumPointSpeedMetersPerSecond),
            maximumLatticePointSpeed: Double(
                dataset.maximumPointSpeedMetersPerSecond
                    * simulation.measuredVelocityToLattice
            ),
            diagnosticReynoldsNumber: reynoldsNumber,
            diagnosticAirDensityKilogramsPerCubicMeter: 1,
            maximumPreparedPositionErrorMeters: maximumPositionError,
            maximumPreparedVelocityErrorMetersPerSecond: maximumVelocityError,
            geometryKernelSequence: [
                "prepareMeasuredWingSurface",
                "clearMeasuredWingSurface",
                "rasterizeMeasuredWingSurface",
                "resolveMeasuredWingSurface",
                "buildMeasuredWingSurfaceLinks",
            ],
            productionFluidKernel: "stepFluidTRT",
            phaseAudits: phaseAudits,
            fluidCycleExecuted: runFluidCycle,
            startupCycleMeanForceNewtons: startupMean,
            passed: passed
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    static func auditMeasuredSurfaceThicknessSensitivity(
        _ dataset: MeasuredWingSurfaceDataset,
        chordCells: Int = 8,
        maximumAllowedRelativeSensitivity: Double = 0.05
    ) throws -> MetalMeasuredWingThicknessSensitivityReport {
        guard maximumAllowedRelativeSensitivity > 0,
              maximumAllowedRelativeSensitivity < 1 else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "maximum thickness sensitivity must be in (0, 1)"
            )
        }
        let startTime = Date()
        let thicknesses: [Float] = [0.5, 0.75, 1.0]
        let reports = try thicknesses.map {
            try auditMeasuredSurface(
                dataset,
                chordCells: chordCells,
                halfThicknessCells: $0,
                runFluidCycle: true
            )
        }
        guard let baselineForce = reports[1].startupCycleMeanForceNewtons,
              baselineForce.count == 3,
              reports.allSatisfy({
                  $0.startupCycleMeanForceNewtons?.count == 3
              }) else {
            throw MetalFlappingWingValidationError.failed(
                "thickness ladder did not produce three-component mean forces"
            )
        }
        func magnitude(_ vector: [Double]) -> Double {
            sqrt(vector.reduce(0) { $0 + $1 * $1 })
        }
        let denominator = max(magnitude(baselineForce), 1.0e-30)
        var maximumPairwiseDifference = 0.0
        for first in 0..<reports.count {
            for second in (first + 1)..<reports.count {
                let firstForce = reports[first].startupCycleMeanForceNewtons!
                let secondForce = reports[second].startupCycleMeanForceNewtons!
                let delta = zip(firstForce, secondForce).map {
                    $0.0 - $0.1
                }
                maximumPairwiseDifference = max(
                    maximumPairwiseDifference,
                    magnitude(delta) / denominator
                )
            }
        }
        let verticalForces = reports.map {
            $0.startupCycleMeanForceNewtons![2]
        }
        let verticalEnvelope = (
            verticalForces.max()! - verticalForces.min()!
        ) / max(abs(baselineForce[2]), 1.0e-30)
        let allCasesPassed = reports.allSatisfy {
            $0.passed && $0.fluidCycleExecuted
        }
        let passed = allCasesPassed
            && maximumPairwiseDifference <= maximumAllowedRelativeSensitivity
            && verticalEnvelope <= maximumAllowedRelativeSensitivity
        return MetalMeasuredWingThicknessSensitivityReport(
            schemaVersion: 1,
            datasetIdentifier: dataset.datasetIdentifier,
            inputSHA256: dataset.inputSHA256,
            chordCells: chordCells,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            baselineHalfThicknessCells: 0.75,
            maximumAllowedRelativeSensitivity:
                maximumAllowedRelativeSensitivity,
            maximumPairwiseRelativeMeanForceVectorDifference:
                maximumPairwiseDifference,
            relativeMeanVerticalForceEnvelope: verticalEnvelope,
            allCaseGeometryAndFluidPassed: allCasesPassed,
            classification: passed
                ? "thickness-insensitive-at-this-grid"
                : "numerical-thickness-sensitive",
            passed: passed,
            cases: reports
        )
    }
}

#if canImport(Metal)
import Metal

private extension MetalFlappingWingValidator {
    struct BatchDifference {
        let density: Double
        let velocity: Double
        let force: Double
    }

    struct GeometrySnapshot {
        let solid: [UInt8]
        let wallVelocityAndImplicit: [SIMD4<Float>]
        let boundaryLinkFractions: [Float]
    }

    struct FieldDiagnostics {
        let metric: MetalFlappingWingVortexMetric
        let qCriterion: [Float]?
        let vorticity: [SIMD3<Float>]?
    }

    struct AnalyticWingFrame {
        let span: SIMD3<Double>
        let chord: SIMD3<Double>
        let normal: SIMD3<Double>
        let angularVelocity: SIMD3<Double>
    }

    static func runInputAudit(
        chordCells: Int
    ) throws -> MetalFlappingWingInputAudit {
        let p = betaShape
        let q = betaShape
        let betaFunction = tgamma(p) * tgamma(q) / tgamma(p + q)
        let independentNormalization = 1 / betaFunction
        let normalizedArea = betaNormalization * betaFunction
        let analyticCentroid = p / (p + q)
        let analyticRadiusOfGyration = sqrt(
            p * (p + 1) / ((p + q) * (p + q + 1))
        )

        let integrationSamples = 65_536
        var strokeTravel = 0.0
        var pitchTravel = 0.0
        for index in 0..<integrationSamples {
            let phase = (Double(index) + 0.5)
                / Double(integrationSamples)
            let state = kinematicState(phase: phase)
            strokeTravel += abs(state.strokeRateRadiansPerCycle)
            pitchTravel += abs(state.pitchRateRadiansPerCycle)
        }
        strokeTravel /= Double(integrationSamples)
        pitchTravel /= Double(integrationSamples)

        var maximumStrokeDerivativeError = 0.0
        var maximumPitchDerivativeError = 0.0
        let derivativeStep = 1.0e-6
        for index in 0..<1_024 {
            let phase = (Double(index) + 0.371)
                / 1_024.0
            let state = kinematicState(phase: phase)
            let before = kinematicState(phase: phase - derivativeStep)
            let after = kinematicState(phase: phase + derivativeStep)
            let strokeDerivative = (after.strokeAngleRadians
                - before.strokeAngleRadians) / (2 * derivativeStep)
            let pitchDerivative = (after.pitchAngleRadians
                - before.pitchAngleRadians) / (2 * derivativeStep)
            maximumStrokeDerivativeError = max(
                maximumStrokeDerivativeError,
                abs(strokeDerivative - state.strokeRateRadiansPerCycle)
            )
            maximumPitchDerivativeError = max(
                maximumPitchDerivativeError,
                abs(pitchDerivative - state.pitchRateRadiansPerCycle)
            )
        }

        let grid = try GridSize(
            x: domainHorizontalChords * chordCells,
            y: domainHorizontalChords * chordCells,
            z: domainVerticalChords * chordCells
        )
        let cycleSteps = Int((
            cycleTravelPerChord * Double(chordCells)
                / latticeRadiusOfGyrationSpeed
        ).rounded())
        let root = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.65 * Float(grid.z)
        )
        let backend = try MetalBackend(fastMath: false)
        let simulation = try MetalPrescribedWingSimulation(
            backend: backend,
            grid: grid,
            chordCells: chordCells,
            cycleSteps: cycleSteps,
            root: root
        )
        let phases = [0.0, 0.125, 0.25, 0.375]
        let geometry = try phases.map { phase in
            let snapshot = try simulation.copyGeometry(phase: phase)
            return geometryAudit(
                phase: phase,
                snapshot: snapshot,
                grid: grid,
                root: SIMD3<Double>(
                    Double(root.x), Double(root.y), Double(root.z)
                ),
                chordCells: chordCells,
                cycleSteps: cycleSteps
            )
        }

        let actualSpeed = cycleTravelPerChord * Double(chordCells)
            / Double(cycleSteps)
        let referenceArea = aspectRatio
            * Double(chordCells * chordCells)
        let coefficientDenominator = 0.5 * actualSpeed * actualSpeed
            * referenceArea
        let geometryPassed = geometry.allSatisfy {
            $0.mismatchedCellFraction <= 0.01
                && abs($0.normalizedRadialCentroid - radialCentroid) <= 0.04
                && abs($0.normalizedRadiusOfGyration
                    - radiusOfGyration) <= 0.04
                && $0.maximumSolidWallVelocityError <= 1.0e-5
                && $0.boundaryLinkCount > 0
                && $0.auditedBoundaryLinkCount > 0
                && $0.maximumInterpolatedWallPositionErrorCells <= 0.10
                && $0.maximumInterpolatedWallPositionErrorCells
                    < $0.maximumHalfwayWallPositionErrorCells
        }
        let analyticInputsPassed = abs(
            independentNormalization - betaNormalization
        )
                <= 1.0e-12
            && abs(normalizedArea - 1) <= 1.0e-12
            && abs(analyticCentroid - radialCentroid) <= 1.0e-12
            && abs(analyticRadiusOfGyration - radiusOfGyration)
                <= 1.0e-12
            && abs(strokeTravel - 4 * strokeHalfAmplitudeRadians)
                <= 1.0e-8
            && abs(pitchTravel - Double.pi) <= 1.0e-8
            && maximumStrokeDerivativeError <= 1.0e-5
            && maximumPitchDerivativeError <= 1.0e-5
        let passed = analyticInputsPassed && geometryPassed
        return MetalFlappingWingInputAudit(
            schemaVersion: 2,
            deviceName: backend.device.name,
            sourceDOI: sourceDOI,
            chordCells: chordCells,
            analyticInputsPassed: analyticInputsPassed,
            metalGeometryPassed: geometryPassed,
            passed: passed,
            betaNormalizationFromGamma: independentNormalization,
            normalizedPlanformArea: normalizedArea,
            normalizedRadialCentroid: analyticCentroid,
            normalizedRadiusOfGyration: analyticRadiusOfGyration,
            integratedStrokeTravelRadians: strokeTravel,
            expectedStrokeTravelRadians: 4 * strokeHalfAmplitudeRadians,
            integratedPitchTravelRadians: pitchTravel,
            expectedPitchTravelRadians: Double.pi,
            maximumStrokeDerivativeError: maximumStrokeDerivativeError,
            maximumPitchDerivativeError: maximumPitchDerivativeError,
            cycleSteps: cycleSteps,
            radiusOfGyrationSpeed: actualSpeed,
            referenceArea: referenceArea,
            coefficientDenominator: coefficientDenominator,
            geometry: geometry
        )
    }

    static func geometryAudit(
        phase: Double,
        snapshot: GeometrySnapshot,
        grid: GridSize,
        root: SIMD3<Double>,
        chordCells: Int,
        cycleSteps: Int
    ) -> MetalFlappingWingGeometryAudit {
        let frame = analyticWingFrame(
            phase: phase,
            cycleSteps: cycleSteps
        )
        let chord = Double(chordCells)
        let radius = aspectRatio * chord
        let thickness = max(0.05 * chord, 1)
        let expectedVolume = aspectRatio * chord * chord * thickness
        let publishedVolume = aspectRatio * chord * chord
            * (0.05 * chord)
        var analyticCount = 0
        var metalCount = 0
        var mismatchCount = 0
        var radialSum = 0.0
        var radialSquareSum = 0.0
        var maximumWallError = 0.0
        var boundaryLinkCount = 0
        var auditedBoundaryLinkCount = 0
        var maximumLinkFractionError = 0.0
        var linkFractionErrorSum = 0.0
        var maximumHalfwayPositionError = 0.0
        var maximumInterpolatedPositionError = 0.0
        let linkAuditStride = max(
            1,
            Int(ceil(
                Double(snapshot.boundaryLinkFractions.count) / 1_024.0
            ))
        )
        for z in 0..<grid.z {
            for y in 0..<grid.y {
                for x in 0..<grid.x {
                    let index = x + grid.x * (y + grid.y * z)
                    let world = SIMD3<Double>(
                        Double(x) + 0.5,
                        Double(y) + 0.5,
                        Double(z) + 0.5
                    )
                    let relative = world - root
                    let boundaryImplicit = analyticWingBoundaryImplicit(
                        world: world,
                        root: root,
                        frame: frame,
                        chordCells: chordCells
                    )
                    let radialCoordinate = dot(relative, frame.span)
                    let analyticSolid = boundaryImplicit <= 0
                    let metalSolid = snapshot.solid[index] != 0
                    analyticCount += analyticSolid ? 1 : 0
                    metalCount += metalSolid ? 1 : 0
                    mismatchCount += analyticSolid == metalSolid ? 0 : 1
                    if metalSolid {
                        radialSum += radialCoordinate
                        radialSquareSum += radialCoordinate * radialCoordinate
                        let expectedWall = cross(
                            frame.angularVelocity,
                            relative
                        )
                        let actual = snapshot.wallVelocityAndImplicit[index]
                        let difference = SIMD3<Double>(
                            Double(actual.x) - expectedWall.x,
                            Double(actual.y) - expectedWall.y,
                            Double(actual.z) - expectedWall.z
                        )
                        maximumWallError = max(
                            maximumWallError,
                            sqrt(dot(difference, difference))
                        )
                    }

                }
            }
        }

        // Enumerate outward from the sparse solid set. This is equivalent to
        // the fluid-source traversal in pull streaming but avoids testing all
        // 18 directions for nearly every domain-fluid cell in a debug audit.
        for sourceZ in 0..<grid.z {
            for sourceY in 0..<grid.y {
                for sourceX in 0..<grid.x {
                    let sourceIndex = sourceX
                        + grid.x * (sourceY + grid.y * sourceZ)
                    guard snapshot.solid[sourceIndex] != 0 else { continue }
                    let sourceWorld = SIMD3<Double>(
                        Double(sourceX) + 0.5,
                        Double(sourceY) + 0.5,
                        Double(sourceZ) + 0.5
                    )
                    for direction in D3Q19.directions.dropFirst() {
                        let fluidX = sourceX + Int(direction.x)
                        let fluidY = sourceY + Int(direction.y)
                        let fluidZ = sourceZ + Int(direction.z)
                        guard fluidX >= 0, fluidX < grid.x,
                              fluidY >= 0, fluidY < grid.y,
                              fluidZ >= 0, fluidZ < grid.z else {
                            continue
                        }
                        let fluidIndex = fluidX
                            + grid.x * (fluidY + grid.y * fluidZ)
                        guard snapshot.solid[fluidIndex] == 0 else { continue }
                        let linkIndex = boundaryLinkCount
                        boundaryLinkCount += 1
                        let shouldAuditLink = linkIndex % linkAuditStride == 0
                            || linkIndex + 1
                                == snapshot.boundaryLinkFractions.count
                        guard shouldAuditLink else { continue }
                        let metalFraction = Double(
                            snapshot.boundaryLinkFractions[linkIndex]
                        )
                        let fluidWorld = SIMD3<Double>(
                            Double(fluidX) + 0.5,
                            Double(fluidY) + 0.5,
                            Double(fluidZ) + 0.5
                        )
                        var lower = 0.0
                        var upper = 1.0
                        for _ in 0..<16 {
                            let fraction = 0.5 * (lower + upper)
                            let sample = fluidWorld
                                + fraction * (sourceWorld - fluidWorld)
                            if analyticWingBoundaryImplicit(
                                world: sample,
                                root: root,
                                frame: frame,
                                chordCells: chordCells
                            ) > 0 {
                                lower = fraction
                            } else {
                                upper = fraction
                            }
                        }
                        let exactFraction = 0.5 * (lower + upper)
                        let fractionError = abs(
                            metalFraction - exactFraction
                        )
                        let linkLength = sqrt(
                            Double(direction.x * direction.x
                                + direction.y * direction.y
                                + direction.z * direction.z)
                        )
                        auditedBoundaryLinkCount += 1
                        linkFractionErrorSum += fractionError
                        maximumLinkFractionError = max(
                            maximumLinkFractionError,
                            fractionError
                        )
                        maximumHalfwayPositionError = max(
                            maximumHalfwayPositionError,
                            abs(0.5 - exactFraction) * linkLength
                        )
                        maximumInterpolatedPositionError = max(
                            maximumInterpolatedPositionError,
                            fractionError * linkLength
                        )
                    }
                }
            }
        }
        let count = Double(max(metalCount, 1))
        return MetalFlappingWingGeometryAudit(
            phase: phase,
            analyticSolidCellCount: analyticCount,
            metalSolidCellCount: metalCount,
            mismatchedCellCount: mismatchCount,
            mismatchedCellFraction: Double(mismatchCount)
                / Double(max(max(analyticCount, metalCount), 1)),
            normalizedVoxelVolume: Double(metalCount) / expectedVolume,
            normalizedPublishedThicknessVoxelVolume: Double(metalCount)
                / publishedVolume,
            normalizedRadialCentroid: radialSum / count / radius,
            normalizedRadiusOfGyration: sqrt(radialSquareSum / count)
                / radius,
            maximumSolidWallVelocityError: maximumWallError,
            boundaryLinkCount: boundaryLinkCount,
            auditedBoundaryLinkCount: auditedBoundaryLinkCount,
            maximumLinkFractionError: maximumLinkFractionError,
            meanLinkFractionError: linkFractionErrorSum
                / Double(max(auditedBoundaryLinkCount, 1)),
            maximumHalfwayWallPositionErrorCells:
                maximumHalfwayPositionError,
            maximumInterpolatedWallPositionErrorCells:
                maximumInterpolatedPositionError
        )
    }

    static func analyticWingBoundaryImplicit(
        world: SIMD3<Double>,
        root: SIMD3<Double>,
        frame: AnalyticWingFrame,
        chordCells: Int
    ) -> Double {
        let relative = world - root
        let chord = Double(chordCells)
        let radius = aspectRatio * chord
        let thickness = max(0.05 * chord, 1)
        let chordCoordinate = dot(relative, frame.chord)
        let radialCoordinate = dot(relative, frame.span)
        let normalCoordinate = dot(relative, frame.normal)
        if radialCoordinate < 0 {
            return -radialCoordinate
        }
        if radialCoordinate > radius {
            return radialCoordinate - radius
        }
        if abs(normalCoordinate) > 0.5 * thickness {
            return abs(normalCoordinate) - 0.5 * thickness
        }
        let radialFraction = min(max(radialCoordinate / radius, 0), 1)
        let betaBase = max(radialFraction * (1 - radialFraction), 0)
        let localChord = chord * betaNormalization
            * pow(betaBase, betaShape - 1)
        let leadingEdge = -0.25 * chord
        let trailingEdge = leadingEdge + localChord
        return max(
            max(-radialCoordinate, radialCoordinate - radius),
            max(
                abs(normalCoordinate) - 0.5 * thickness,
                max(
                    leadingEdge - chordCoordinate,
                    chordCoordinate - trailingEdge
                )
            )
        )
    }

    static func analyticWingFrame(
        phase: Double,
        cycleSteps: Int
    ) -> AnalyticWingFrame {
        let state = kinematicState(phase: phase)
        let span = SIMD3<Double>(
            cos(state.strokeAngleRadians),
            sin(state.strokeAngleRadians),
            0
        )
        let tangent = cross(SIMD3<Double>(0, 0, 1), span)
        let chord = rotate(
            tangent,
            around: span,
            angle: -state.pitchAngleRadians
        )
        let normal = cross(span, chord)
        let inverseCycleSteps = 1 / Double(cycleSteps)
        let angularVelocity = SIMD3<Double>(0, 0, 1)
                * (state.strokeRateRadiansPerCycle * inverseCycleSteps)
            - span
                * (state.pitchRateRadiansPerCycle * inverseCycleSteps)
        return AnalyticWingFrame(
            span: span,
            chord: chord,
            normal: normal,
            angularVelocity: angularVelocity
        )
    }

    static func loadComponentSummary(
        _ samples: [MetalFlappingWingPhaseSample]
    ) -> MetalFlappingWingLoadComponentSummary {
        let count = Double(max(samples.count, 1))
        let meanLift = samples.reduce(0) { $0 + $1.liftCoefficient } / count
        let meanDrag = samples.reduce(0) { $0 + $1.dragCoefficient } / count
        let rmsLift = sqrt(
            samples.reduce(0) { $0 + $1.liftCoefficient * $1.liftCoefficient }
                / count
        )
        let rmsDrag = sqrt(
            samples.reduce(0) { $0 + $1.dragCoefficient * $1.dragCoefficient }
                / count
        )
        let peakLift = samples.max {
            abs($0.liftCoefficient) < abs($1.liftCoefficient)
        }
        let peakDrag = samples.max {
            abs($0.dragCoefficient) < abs($1.dragCoefficient)
        }
        return MetalFlappingWingLoadComponentSummary(
            meanLiftCoefficient: meanLift,
            meanDragCoefficient: meanDrag,
            rmsLiftCoefficient: rmsLift,
            rmsDragCoefficient: rmsDrag,
            maximumAbsoluteLiftCoefficient: abs(
                peakLift?.liftCoefficient ?? 0
            ),
            maximumAbsoluteDragCoefficient: abs(
                peakDrag?.dragCoefficient ?? 0
            ),
            maximumAbsoluteLiftPhase: peakLift?.phase ?? 0,
            maximumAbsoluteDragPhase: peakDrag?.phase ?? 0,
            phaseSamples: samples
        )
    }

    static func loadDecompositionReport(
        deviceName: String,
        chordCells: Int,
        cycles: Int,
        runtimeSeconds: Double,
        total totalSamples: [MetalFlappingWingPhaseSample],
        link linkSamples: [MetalFlappingWingPhaseSample],
        topology topologySamples: [MetalFlappingWingPhaseSample]
    ) -> MetalFlappingWingLoadDecompositionReport {
        precondition(totalSamples.count == linkSamples.count)
        precondition(totalSamples.count == topologySamples.count)
        let total = loadComponentSummary(totalSamples)
        let link = loadComponentSummary(linkSamples)
        let topology = loadComponentSummary(topologySamples)
        var maximumLiftClosure = 0.0
        var maximumDragClosure = 0.0
        var maximumForceClosure = 0.0
        for index in totalSamples.indices {
            let totalSample = totalSamples[index]
            let linkSample = linkSamples[index]
            let topologySample = topologySamples[index]
            maximumLiftClosure = max(
                maximumLiftClosure,
                abs(
                    totalSample.liftCoefficient
                        - linkSample.liftCoefficient
                        - topologySample.liftCoefficient
                )
            )
            maximumDragClosure = max(
                maximumDragClosure,
                abs(
                    totalSample.dragCoefficient
                        - linkSample.dragCoefficient
                        - topologySample.dragCoefficient
                )
            )
            let forceDifference = SIMD3<Double>(
                totalSample.forceX - linkSample.forceX
                    - topologySample.forceX,
                totalSample.forceY - linkSample.forceY
                    - topologySample.forceY,
                totalSample.forceZ - linkSample.forceZ
                    - topologySample.forceZ
            )
            maximumForceClosure = max(
                maximumForceClosure,
                sqrt(dot(forceDifference, forceDifference))
            )
        }
        let tolerance = 1.0e-4
        return MetalFlappingWingLoadDecompositionReport(
            schemaVersion: 1,
            deviceName: deviceName,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: runtimeSeconds,
            total: total,
            linkExchange: link,
            coverUncoverImpulse: topology,
            topologyMeanLiftFraction: abs(total.meanLiftCoefficient) > 1.0e-12
                ? topology.meanLiftCoefficient / total.meanLiftCoefficient
                : 0,
            topologyMeanDragFraction: abs(total.meanDragCoefficient) > 1.0e-12
                ? topology.meanDragCoefficient / total.meanDragCoefficient
                : 0,
            topologyRMSLiftFraction: total.rmsLiftCoefficient > 1.0e-12
                ? topology.rmsLiftCoefficient / total.rmsLiftCoefficient
                : 0,
            topologyRMSDragFraction: total.rmsDragCoefficient > 1.0e-12
                ? topology.rmsDragCoefficient / total.rmsDragCoefficient
                : 0,
            maximumLiftCoefficientClosureError: maximumLiftClosure,
            maximumDragCoefficientClosureError: maximumDragClosure,
            maximumForceClosureError: maximumForceClosure,
            maximumAllowedCoefficientClosureError: tolerance,
            closurePassed: maximumLiftClosure <= tolerance
                && maximumDragClosure <= tolerance
        )
    }

    static func addingLoadSamples(
        _ left: [MetalFlappingWingPhaseSample],
        _ right: [MetalFlappingWingPhaseSample]
    ) -> [MetalFlappingWingPhaseSample] {
        precondition(left.count == right.count)
        return left.indices.map { index in
            let lhs = left[index]
            let rhs = right[index]
            precondition(abs(lhs.phase - rhs.phase) < 1.0e-12)
            return MetalFlappingWingPhaseSample(
                phase: lhs.phase,
                liftCoefficient: lhs.liftCoefficient + rhs.liftCoefficient,
                dragCoefficient: lhs.dragCoefficient + rhs.dragCoefficient,
                forceX: lhs.forceX + rhs.forceX,
                forceY: lhs.forceY + rhs.forceY,
                forceZ: lhs.forceZ + rhs.forceZ
            )
        }
    }

    static func linkForceComparisonReport(
        deviceName: String,
        chordCells: Int,
        cycles: Int,
        runtimeSeconds: Double,
        galileanInvariantTotal totalSamples: [MetalFlappingWingPhaseSample],
        galileanInvariantLink linkSamples: [MetalFlappingWingPhaseSample],
        conventionalLink conventionalSamples: [MetalFlappingWingPhaseSample],
        topology topologySamples: [MetalFlappingWingPhaseSample]
    ) -> MetalFlappingWingLinkForceComparisonReport {
        precondition(totalSamples.count == linkSamples.count)
        precondition(totalSamples.count == conventionalSamples.count)
        precondition(totalSamples.count == topologySamples.count)

        let conventionalTotalSamples = addingLoadSamples(
            conventionalSamples,
            topologySamples
        )
        let galileanInvariantTotal = loadComponentSummary(totalSamples)
        let galileanInvariantLink = loadComponentSummary(linkSamples)
        let conventionalLink = loadComponentSummary(conventionalSamples)
        let topology = loadComponentSummary(topologySamples)
        let conventionalTotal = loadComponentSummary(conventionalTotalSamples)

        var maximumLinkLiftDifference = 0.0
        var maximumLinkDragDifference = 0.0
        var maximumLiftClosure = 0.0
        var maximumDragClosure = 0.0
        var maximumForceClosure = 0.0
        for index in totalSamples.indices {
            let total = totalSamples[index]
            let link = linkSamples[index]
            let conventional = conventionalSamples[index]
            let topology = topologySamples[index]
            maximumLinkLiftDifference = max(
                maximumLinkLiftDifference,
                abs(
                    conventional.liftCoefficient
                        - link.liftCoefficient
                )
            )
            maximumLinkDragDifference = max(
                maximumLinkDragDifference,
                abs(
                    conventional.dragCoefficient
                        - link.dragCoefficient
                )
            )
            maximumLiftClosure = max(
                maximumLiftClosure,
                abs(
                    total.liftCoefficient
                        - link.liftCoefficient
                        - topology.liftCoefficient
                )
            )
            maximumDragClosure = max(
                maximumDragClosure,
                abs(
                    total.dragCoefficient
                        - link.dragCoefficient
                        - topology.dragCoefficient
                )
            )
            let forceDifference = SIMD3<Double>(
                total.forceX - link.forceX - topology.forceX,
                total.forceY - link.forceY - topology.forceY,
                total.forceZ - link.forceZ - topology.forceZ
            )
            maximumForceClosure = max(
                maximumForceClosure,
                sqrt(dot(forceDifference, forceDifference))
            )
        }

        func ratio(_ numerator: Double, _ denominator: Double) -> Double {
            abs(denominator) > 1.0e-12 ? numerator / denominator : 0
        }
        func relativeError(_ value: Double, _ reference: Double) -> Double {
            abs(value - reference) / abs(reference)
        }

        let tolerance = 1.0e-4
        return MetalFlappingWingLinkForceComparisonReport(
            schemaVersion: 1,
            deviceName: deviceName,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: runtimeSeconds,
            sourceDOI: sourceDOI,
            galileanInvariantEstimatorDOI: galileanInvariantEstimatorDOI,
            galileanInvariantLinkExchange: galileanInvariantLink,
            interpolatedPopulationConventionalLinkExchange: conventionalLink,
            coverUncoverImpulse: topology,
            galileanInvariantTotal: galileanInvariantTotal,
            conventionalMovingBodyTotal: conventionalTotal,
            conventionalToGalileanMeanLiftRatio: ratio(
                conventionalTotal.meanLiftCoefficient,
                galileanInvariantTotal.meanLiftCoefficient
            ),
            conventionalToGalileanMeanDragRatio: ratio(
                conventionalTotal.meanDragCoefficient,
                galileanInvariantTotal.meanDragCoefficient
            ),
            galileanInvariantRelativeMeanLiftError: relativeError(
                galileanInvariantTotal.meanLiftCoefficient,
                referenceMeanLiftCoefficient
            ),
            galileanInvariantRelativeMeanDragError: relativeError(
                galileanInvariantTotal.meanDragCoefficient,
                referenceMeanDragCoefficient
            ),
            conventionalRelativeMeanLiftError: relativeError(
                conventionalTotal.meanLiftCoefficient,
                referenceMeanLiftCoefficient
            ),
            conventionalRelativeMeanDragError: relativeError(
                conventionalTotal.meanDragCoefficient,
                referenceMeanDragCoefficient
            ),
            maximumLinkLiftCoefficientDifference: maximumLinkLiftDifference,
            maximumLinkDragCoefficientDifference: maximumLinkDragDifference,
            maximumGalileanInvariantLiftClosureError: maximumLiftClosure,
            maximumGalileanInvariantDragClosureError: maximumDragClosure,
            maximumGalileanInvariantForceClosureError: maximumForceClosure,
            maximumAllowedCoefficientClosureError: tolerance,
            closurePassed: maximumLiftClosure <= tolerance
                && maximumDragClosure <= tolerance
        )
    }

    static func loadClosureErrors(
        total: [MetalFlappingWingPhaseSample],
        components: [[MetalFlappingWingPhaseSample]]
    ) -> (lift: Double, drag: Double, force: Double) {
        precondition(components.allSatisfy { $0.count == total.count })
        var maximumLift = 0.0
        var maximumDrag = 0.0
        var maximumForce = 0.0
        for index in total.indices {
            let sample = total[index]
            var lift = 0.0
            var drag = 0.0
            var force = SIMD3<Double>.zero
            for component in components {
                let value = component[index]
                precondition(abs(value.phase - sample.phase) < 1.0e-12)
                lift += value.liftCoefficient
                drag += value.dragCoefficient
                force += SIMD3<Double>(
                    value.forceX,
                    value.forceY,
                    value.forceZ
                )
            }
            maximumLift = max(
                maximumLift,
                abs(sample.liftCoefficient - lift)
            )
            maximumDrag = max(
                maximumDrag,
                abs(sample.dragCoefficient - drag)
            )
            let difference = SIMD3<Double>(
                sample.forceX,
                sample.forceY,
                sample.forceZ
            ) - force
            maximumForce = max(
                maximumForce,
                sqrt(dot(difference, difference))
            )
        }
        return (maximumLift, maximumDrag, maximumForce)
    }

    static func linkNumeratorDecompositionReport(
        deviceName: String,
        chordCells: Int,
        cycles: Int,
        runtimeSeconds: Double,
        galileanInvariant galileanSamples: [MetalFlappingWingPhaseSample],
        conventional conventionalSamples: [MetalFlappingWingPhaseSample],
        baseReflection baseSamples: [MetalFlappingWingPhaseSample],
        movingWallPopulationCorrection wallSamples:
            [MetalFlappingWingPhaseSample],
        interpolationResidual interpolationSamples:
            [MetalFlappingWingPhaseSample],
        galileanWallFrameCorrection wallFrameSamples:
            [MetalFlappingWingPhaseSample]
    ) -> MetalFlappingWingLinkNumeratorDecompositionReport {
        let galilean = loadComponentSummary(galileanSamples)
        let conventional = loadComponentSummary(conventionalSamples)

        func ratio(_ numerator: Double, _ denominator: Double) -> Double {
            abs(denominator) > 1.0e-12 ? numerator / denominator : 0
        }
        func component(
            name: String,
            equation: String,
            samples: [MetalFlappingWingPhaseSample]
        ) -> MetalFlappingWingLinkNumeratorComponent {
            let load = loadComponentSummary(samples)
            return MetalFlappingWingLinkNumeratorComponent(
                name: name,
                equation: equation,
                load: load,
                meanLiftFractionOfGalileanInvariantLink: ratio(
                    load.meanLiftCoefficient,
                    galilean.meanLiftCoefficient
                ),
                meanDragFractionOfGalileanInvariantLink: ratio(
                    load.meanDragCoefficient,
                    galilean.meanDragCoefficient
                ),
                rmsLiftFractionOfGalileanInvariantLink: ratio(
                    load.rmsLiftCoefficient,
                    galilean.rmsLiftCoefficient
                ),
                rmsDragFractionOfGalileanInvariantLink: ratio(
                    load.rmsDragCoefficient,
                    galilean.rmsDragCoefficient
                )
            )
        }

        let components = [
            component(
                name: "baseReflection",
                equation: "-(2*f_out)*c",
                samples: baseSamples
            ),
            component(
                name: "movingWallPopulationCorrection",
                equation: "-delta_f_wall*c",
                samples: wallSamples
            ),
            component(
                name: "interpolationResidual",
                equation: "-(f_in-f_out-delta_f_wall)*c",
                samples: interpolationSamples
            ),
            component(
                name: "galileanWallFrameCorrection",
                equation: "(f_in-f_out)*u_wall",
                samples: wallFrameSamples
            ),
        ]
        let conventionalClosure = loadClosureErrors(
            total: conventionalSamples,
            components: [baseSamples, wallSamples, interpolationSamples]
        )
        let galileanClosure = loadClosureErrors(
            total: galileanSamples,
            components: [
                baseSamples,
                wallSamples,
                interpolationSamples,
                wallFrameSamples,
            ]
        )
        let dominantLift = components.max {
            abs($0.load.meanLiftCoefficient)
                < abs($1.load.meanLiftCoefficient)
        }!.name
        let dominantDrag = components.max {
            abs($0.load.meanDragCoefficient)
                < abs($1.load.meanDragCoefficient)
        }!.name
        let tolerance = 1.0e-4
        return MetalFlappingWingLinkNumeratorDecompositionReport(
            schemaVersion: 1,
            deviceName: deviceName,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: runtimeSeconds,
            galileanInvariantLinkExchange: galilean,
            conventionalLinkExchange: conventional,
            components: components,
            dominantMeanLiftComponent: dominantLift,
            dominantMeanDragComponent: dominantDrag,
            maximumConventionalLiftClosureError: conventionalClosure.lift,
            maximumConventionalDragClosureError: conventionalClosure.drag,
            maximumConventionalForceClosureError: conventionalClosure.force,
            maximumGalileanInvariantLiftClosureError: galileanClosure.lift,
            maximumGalileanInvariantDragClosureError: galileanClosure.drag,
            maximumGalileanInvariantForceClosureError: galileanClosure.force,
            maximumAllowedCoefficientClosureError: tolerance,
            closurePassed: conventionalClosure.lift <= tolerance
                && conventionalClosure.drag <= tolerance
                && galileanClosure.lift <= tolerance
                && galileanClosure.drag <= tolerance
        )
    }

    static func momentumBudgetReport(
        deviceName: String,
        chordCells: Int,
        cycles: Int,
        runtimeSeconds: Double,
        galilean: PrescribedWingMomentumBudgetCaseResult,
        conventionalBoundaryLoad: [MetalFlappingWingPhaseSample],
        conservativeBoundaryLoad: [MetalFlappingWingPhaseSample]
    ) -> MetalFlappingWingMomentumBudgetReport {
        func residual(
            _ boundary: [MetalFlappingWingPhaseSample],
            _ budget: [MetalFlappingWingPhaseSample]
        ) -> [MetalFlappingWingPhaseSample] {
            precondition(boundary.count == budget.count)
            return boundary.indices.map { index in
                let lhs = boundary[index]
                let rhs = budget[index]
                precondition(abs(lhs.phase - rhs.phase) < 1.0e-12)
                return MetalFlappingWingPhaseSample(
                    phase: lhs.phase,
                    liftCoefficient: lhs.liftCoefficient
                        - rhs.liftCoefficient,
                    dragCoefficient: lhs.dragCoefficient
                        - rhs.dragCoefficient,
                    forceX: lhs.forceX - rhs.forceX,
                    forceY: lhs.forceY - rhs.forceY,
                    forceZ: lhs.forceZ - rhs.forceZ
                )
            }
        }
        func maxima(
            _ samples: [MetalFlappingWingPhaseSample]
        ) -> (lift: Double, drag: Double, force: Double) {
            var lift = 0.0
            var drag = 0.0
            var force = 0.0
            for sample in samples {
                lift = max(lift, abs(sample.liftCoefficient))
                drag = max(drag, abs(sample.dragCoefficient))
                force = max(
                    force,
                    sqrt(
                        sample.forceX * sample.forceX
                            + sample.forceY * sample.forceY
                            + sample.forceZ * sample.forceZ
                    )
                )
            }
            return (lift, drag, force)
        }

        let galileanResidual = residual(
            galilean.boundaryLoad,
            galilean.total
        )
        let conventionalResidual = residual(
            conventionalBoundaryLoad,
            galilean.total
        )
        let conservativeResidual = residual(
            conservativeBoundaryLoad,
            galilean.rawTotal
        )
        let conservativeCorrection = residual(
            conservativeBoundaryLoad,
            conventionalBoundaryLoad
        )
        let galileanMaximum = maxima(galileanResidual)
        let conventionalMaximum = maxima(conventionalResidual)
        let conservativeMaximum = maxima(conservativeResidual)
        let tolerance = 0.005
        let clear = galilean.maximumSolidControlSurfaceCrossingLinkCount == 0
        let outsideSponge = galilean
            .minimumControlSurfaceDistanceFromDomainBoundaryCells
            >= galilean.spongeWidthCells
        let passed = clear
            && outsideSponge
            && conventionalMaximum.lift <= tolerance
            && conventionalMaximum.drag <= tolerance
        let conservativePassed = clear
            && outsideSponge
            && conservativeMaximum.lift <= tolerance
            && conservativeMaximum.drag <= tolerance
        let validSurface = clear && outsideSponge
        let biasDetected = validSurface && !passed
        let galileanSummary = loadComponentSummary(galilean.boundaryLoad)
        let conventionalSummary = loadComponentSummary(
            conventionalBoundaryLoad
        )
        let conservativeSummary = loadComponentSummary(
            conservativeBoundaryLoad
        )
        let rawBudgetSummary = loadComponentSummary(galilean.rawTotal)
        let budgetSummary = loadComponentSummary(galilean.total)
        func ratio(_ numerator: Double, _ denominator: Double) -> Double {
            abs(denominator) > 1.0e-12 ? numerator / denominator : 0
        }
        return MetalFlappingWingMomentumBudgetReport(
            schemaVersion: 1,
            deviceName: deviceName,
            chordCells: chordCells,
            cycles: cycles,
            runtimeSeconds: runtimeSeconds,
            controlVolume: galilean.controlVolume,
            spongeWidthCells: galilean.spongeWidthCells,
            minimumControlSurfaceDistanceFromDomainBoundaryCells: galilean
                .minimumControlSurfaceDistanceFromDomainBoundaryCells,
            maximumSolidControlSurfaceCrossingLinkCount: galilean
                .maximumSolidControlSurfaceCrossingLinkCount,
            galileanInvariantBoundaryLoad: galileanSummary,
            conventionalBoundaryLoad: conventionalSummary,
            conservativeMovingDomainBoundaryLoad: conservativeSummary,
            conservativeCorrectionRelativeToConventionalBoundaryLoad:
                loadComponentSummary(conservativeCorrection),
            negativeFluidMomentumStorageRate: loadComponentSummary(
                galilean.negativeStorage
            ),
            negativeControlSurfaceMomentumFlux: loadComponentSummary(
                galilean.negativeSurfaceFlux
            ),
            topologyReservoirCorrection: loadComponentSummary(
                galilean.topologyReservoirCorrection
            ),
            rawFluidMomentumBudget: rawBudgetSummary,
            independentFluidMomentumBudget: budgetSummary,
            galileanInvariantResidual: loadComponentSummary(
                galileanResidual
            ),
            conventionalResidual: loadComponentSummary(
                conventionalResidual
            ),
            conservativeMovingDomainResidual: loadComponentSummary(
                conservativeResidual
            ),
            maximumGalileanInvariantLiftCoefficientResidual:
                galileanMaximum.lift,
            maximumGalileanInvariantDragCoefficientResidual:
                galileanMaximum.drag,
            maximumGalileanInvariantForceResidual: galileanMaximum.force,
            maximumConventionalLiftCoefficientResidual:
                conventionalMaximum.lift,
            maximumConventionalDragCoefficientResidual:
                conventionalMaximum.drag,
            maximumConventionalForceResidual: conventionalMaximum.force,
            maximumConservativeLiftCoefficientResidual:
                conservativeMaximum.lift,
            maximumConservativeDragCoefficientResidual:
                conservativeMaximum.drag,
            maximumConservativeForceResidual: conservativeMaximum.force,
            galileanInvariantMeanLiftBiasFactor: ratio(
                galileanSummary.meanLiftCoefficient,
                budgetSummary.meanLiftCoefficient
            ),
            galileanInvariantMeanDragBiasFactor: ratio(
                galileanSummary.meanDragCoefficient,
                budgetSummary.meanDragCoefficient
            ),
            conventionalMeanLiftBiasFactor: ratio(
                conventionalSummary.meanLiftCoefficient,
                budgetSummary.meanLiftCoefficient
            ),
            conventionalMeanDragBiasFactor: ratio(
                conventionalSummary.meanDragCoefficient,
                budgetSummary.meanDragCoefficient
            ),
            maximumAllowedCoefficientResidual: tolerance,
            controlSurfaceClearOfSolid: clear,
            controlSurfaceOutsideSponge: outsideSponge,
            conventionalClosurePassed: passed,
            conservativeMovingDomainClosurePassed: conservativePassed,
            boundaryLoadBiasDetected: biasDetected,
            classification: !validSurface
                ? "invalidControlSurface"
                : (conservativePassed
                    ? "conservativeMovingDomainEstimatorCloses"
                    : (passed
                        ? "boundaryLoadMatchesDiscreteFluidMomentum"
                        : "boundaryForceAccountingBiasDetected"))
        )
    }

    static func runMomentumBudgetCase(
        backend: MetalBackend,
        chordCells: Int,
        cycles: Int
    ) throws -> PrescribedWingMomentumBudgetCaseResult {
        let grid = try GridSize(
            x: domainHorizontalChords * chordCells,
            y: domainHorizontalChords * chordCells,
            z: domainVerticalChords * chordCells
        )
        let cycleSteps = Int((
            cycleTravelPerChord * Double(chordCells)
                / latticeRadiusOfGyrationSpeed
        ).rounded())
        let root = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.65 * Float(grid.z)
        )
        let simulation = try MetalPrescribedWingSimulation(
            backend: backend,
            grid: grid,
            chordCells: chordCells,
            cycleSteps: cycleSteps,
            root: root,
            loadComponent: .total,
            linkForceEstimator: .galileanInvariant
        )
        if cycles > 1 {
            _ = try simulation.advance(
                to: (cycles - 1) * cycleSteps,
                batchSize: 64,
                captureFields: false
            )
        }
        _ = try simulation.advance(
            to: cycles * cycleSteps,
            batchSize: 64,
            captureFields: false,
            recordEveryStepLoad: true,
            recordEveryStepMomentumBudget: true
        )
        let boundary = phaseBinnedSamples(
            loads: simulation.copyRecordedLoads(),
            chordCells: chordCells,
            cycleSteps: cycleSteps
        )
        let steps = simulation.copyRecordedMomentumBudgets()
        func samples(
            _ keyPath: KeyPath<PrescribedWingMomentumBudgetStep, ForceTorque>
        ) -> [MetalFlappingWingPhaseSample] {
            phaseBinnedSamples(
                loads: steps.map { $0[keyPath: keyPath] },
                chordCells: chordCells,
                cycleSteps: cycleSteps
            )
        }
        let metadata = simulation.controlVolumeMetadata
        return PrescribedWingMomentumBudgetCaseResult(
            boundaryLoad: boundary,
            negativeStorage: samples(\.negativeStorage),
            negativeSurfaceFlux: samples(\.negativeSurfaceFlux),
            topologyReservoirCorrection: samples(
                \.topologyReservoirCorrection
            ),
            rawTotal: samples(\.rawTotal),
            total: samples(\.total),
            controlVolume: metadata.bounds,
            spongeWidthCells: metadata.spongeWidthCells,
            minimumControlSurfaceDistanceFromDomainBoundaryCells:
                metadata.minimumDomainDistanceCells,
            maximumSolidControlSurfaceCrossingLinkCount: steps.map(
                \.solidControlSurfaceCrossingLinkCount
            ).max() ?? 0
        )
    }

    static func runCase(
        backend: MetalBackend,
        chordCells: Int,
        cycles: Int,
        archiveDirectory: URL?,
        loadComponent: PrescribedWingLoadComponent = .total,
        linkForceEstimator: PrescribedWingLinkForceEstimator =
            .conservativeMovingDomain,
        captureVortexDiagnostics: Bool = true
    ) throws -> MetalFlappingWingCaseResult {
        let startTime = Date()
        let grid = try GridSize(
            x: domainHorizontalChords * chordCells,
            y: domainHorizontalChords * chordCells,
            z: domainVerticalChords * chordCells
        )
        let cycleSteps = Int((
            cycleTravelPerChord * Double(chordCells)
                / latticeRadiusOfGyrationSpeed
        ).rounded())
        let root = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.65 * Float(grid.z)
        )
        let simulation = try MetalPrescribedWingSimulation(
            backend: backend,
            grid: grid,
            chordCells: chordCells,
            cycleSteps: cycleSteps,
            root: root,
            loadComponent: loadComponent,
            linkForceEstimator: linkForceEstimator
        )
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
        }

        let firstRecordedCycle = max(0, cycles - 2)
        var previous: [MetalFlappingWingPhaseSample] = []
        var current: [MetalFlappingWingPhaseSample] = []
        var vortexMetrics: [MetalFlappingWingVortexMetric] = []
        let vortexIndices = captureVortexDiagnostics
            ? Set(requiredVortexPhases.map { Int(($0 * 100).rounded()) })
            : Set<Int>()
        if firstRecordedCycle > 0 {
            _ = try simulation.advance(
                to: firstRecordedCycle * cycleSteps,
                batchSize: 64,
                captureFields: false
            )
        }
        for cycle in firstRecordedCycle..<cycles {
            if cycle == cycles - 1 && captureVortexDiagnostics {
                for sampleIndex in vortexIndices.sorted() {
                    let phase = Double(sampleIndex) / 100
                    let target = cycle * cycleSteps
                        + Int((phase * Double(cycleSteps)).rounded())
                    _ = try simulation.advance(
                        to: target,
                        batchSize: 64,
                        captureFields: true,
                        recordEveryStepLoad: true
                    )
                    let fields = simulation.copyFields()
                    let diagnostics = fieldDiagnostics(
                        phase: phase,
                        density: fields.density,
                        velocity: fields.velocity,
                        grid: grid,
                        retainFields: archiveDirectory != nil
                    )
                    vortexMetrics.append(diagnostics.metric)
                    if let archiveDirectory {
                        try archivePhase(
                            directory: archiveDirectory,
                            phaseIndex: sampleIndex,
                            density: fields.density,
                            velocity: fields.velocity,
                            diagnostics: diagnostics
                        )
                    }
                }
            }
            _ = try simulation.advance(
                to: (cycle + 1) * cycleSteps,
                batchSize: 64,
                captureFields: false,
                recordEveryStepLoad: true
            )
            let samples = phaseBinnedSamples(
                loads: simulation.copyRecordedLoads(),
                chordCells: chordCells,
                cycleSteps: cycleSteps
            )
            if cycle == cycles - 1 {
                current = samples
            } else {
                previous = samples
            }
        }
        if cycles == 1 {
            previous = current
        } else if previous.count > 100 {
            previous = Array(previous.suffix(100))
        }
        let meanLift = current.map(\.liftCoefficient).mean
        let meanDrag = current.map(\.dragCoefficient).mean
        let firstPeak = current[0..<50].max {
            $0.liftCoefficient < $1.liftCoefficient
        }!.phase
        let secondPeak = current[50..<100].max {
            $0.liftCoefficient < $1.liftCoefficient
        }!.phase
        let midstroke = [current[25].liftCoefficient, current[75].liftCoefficient].mean
        let reversal = [current[0].liftCoefficient, current[50].liftCoefficient].mean
        let halfSymmetry = normalizedCurveDifference(
            Array(current[0..<50]),
            Array(current[50..<100])
        )
        let periodicDifference = normalizedCurveDifference(previous, current)
        let actualSpeed = cycleTravelPerChord * Double(chordCells)
            / Double(cycleSteps)
        let result = MetalFlappingWingCaseResult(
            chordCells: chordCells,
            gridX: grid.x,
            gridY: grid.y,
            gridZ: grid.z,
            cycleSteps: cycleSteps,
            cycles: cycles,
            steps: cycles * cycleSteps,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            effectiveThicknessToChord: max(0.05, 1 / Double(chordCells)),
            actualRadiusOfGyrationSpeed: actualSpeed,
            actualReynoldsNumber: reynoldsNumber
                * actualSpeed / latticeRadiusOfGyrationSpeed,
            meanLiftCoefficient: meanLift,
            meanDragCoefficient: meanDrag,
            relativeMeanLiftError: relativeError(
                meanLift,
                referenceMeanLiftCoefficient
            ),
            relativeMeanDragError: relativeError(
                meanDrag,
                referenceMeanDragCoefficient
            ),
            firstHalfPeakLiftPhase: firstPeak,
            secondHalfPeakLiftPhase: secondPeak,
            meanMidstrokeLiftCoefficient: midstroke,
            meanReversalLiftCoefficient: reversal,
            halfStrokeSymmetryError: halfSymmetry,
            previousCycleDifference: periodicDifference,
            vortexTimingCoverageComplete: !captureVortexDiagnostics
                || (vortexMetrics.count == requiredVortexPhases.count
                && vortexMetrics.allSatisfy {
                    $0.maximumPositiveQ.isFinite
                        && $0.maximumPositiveQ > 0
                        && $0.positiveQCellCount > 0
                        && $0.maximumVorticityMagnitude.isFinite
                        && $0.maximumVorticityMagnitude > 0
                }),
            phaseSamples: current,
            vortexMetrics: vortexMetrics
        )
        if let archiveDirectory {
            try archiveCase(result, directory: archiveDirectory)
        }
        return result
    }

    static func phaseSample(
        phase: Double,
        load: ForceTorque,
        chordCells: Int,
        cycleSteps: Int
    ) -> MetalFlappingWingPhaseSample {
        let state = kinematicState(phase: phase)
        let tangent = SIMD3<Double>(
            -sin(state.strokeAngleRadians),
            cos(state.strokeAngleRadians),
            0
        )
        let force = SIMD3<Double>(
            Double(load.forceNewtons.x),
            Double(load.forceNewtons.y),
            Double(load.forceNewtons.z)
        )
        let actualSpeed = cycleTravelPerChord * Double(chordCells)
            / Double(cycleSteps)
        let denominator = 0.5 * actualSpeed * actualSpeed
            * aspectRatio * Double(chordCells * chordCells)
        let strokeDirection = phase < 0.5 ? -1.0 : 1.0
        return MetalFlappingWingPhaseSample(
            phase: phase,
            liftCoefficient: force.z / denominator,
            dragCoefficient: -strokeDirection * dot(force, tangent)
                / denominator,
            forceX: force.x,
            forceY: force.y,
            forceZ: force.z
        )
    }

    static func phaseBinnedSamples(
        loads: [ForceTorque],
        chordCells: Int,
        cycleSteps: Int
    ) -> [MetalFlappingWingPhaseSample] {
        var lift = [Double](repeating: 0, count: 100)
        var drag = [Double](repeating: 0, count: 100)
        var forceX = [Double](repeating: 0, count: 100)
        var forceY = [Double](repeating: 0, count: 100)
        var forceZ = [Double](repeating: 0, count: 100)
        var counts = [Int](repeating: 0, count: 100)
        for index in loads.indices {
            // The last stored step is phase 1 from the preceding half-stroke,
            // so keep it in bin 99 instead of wrapping its drag direction.
            let phase = min(
                (Double(index) + 1) / Double(cycleSteps),
                1 - Double.ulpOfOne
            )
            let bin = min(99, Int(floor(phase * 100)))
            let sample = phaseSample(
                phase: phase,
                load: loads[index],
                chordCells: chordCells,
                cycleSteps: cycleSteps
            )
            lift[bin] += sample.liftCoefficient
            drag[bin] += sample.dragCoefficient
            forceX[bin] += sample.forceX
            forceY[bin] += sample.forceY
            forceZ[bin] += sample.forceZ
            counts[bin] += 1
        }
        return (0..<100).map { bin in
            let divisor = Double(max(counts[bin], 1))
            return MetalFlappingWingPhaseSample(
                phase: (Double(bin) + 0.5) / 100,
                liftCoefficient: lift[bin] / divisor,
                dragCoefficient: drag[bin] / divisor,
                forceX: forceX[bin] / divisor,
                forceY: forceY[bin] / divisor,
                forceZ: forceZ[bin] / divisor
            )
        }
    }

    static func fieldDiagnostics(
        phase: Double,
        density: [Float],
        velocity: [SIMD3<Float>],
        grid: GridSize,
        retainFields: Bool
    ) -> FieldDiagnostics {
        let reference = FlowDiagnosticsReference.compute(
            velocity: velocity,
            grid: grid
        )
        var maximumQ = 0.0
        var maximumVorticity = 0.0
        var positiveCount = 0
        for i in reference.qCriterion.indices where reference.valid[i] != 0 {
            let q = Double(reference.qCriterion[i])
            let curl = reference.vorticity[i]
            let magnitude = Double(vectorLength(curl))
            if q > 0 {
                positiveCount += 1
                maximumQ = max(maximumQ, q)
            }
            maximumVorticity = max(maximumVorticity, magnitude)
        }
        return FieldDiagnostics(
            metric: MetalFlappingWingVortexMetric(
                phase: phase,
                maximumPositiveQ: maximumQ,
                positiveQCellCount: positiveCount,
                maximumVorticityMagnitude: maximumVorticity
            ),
            qCriterion: retainFields ? reference.qCriterion : nil,
            vorticity: retainFields ? reference.vorticity : nil
        )
    }

    static func normalizedCurveDifference(
        _ first: [MetalFlappingWingPhaseSample],
        _ second: [MetalFlappingWingPhaseSample]
    ) -> Double {
        guard first.count == second.count, !first.isEmpty else { return 1 }
        var squared = 0.0
        var reference = 0.0
        for index in first.indices {
            let dl = first[index].liftCoefficient
                - second[index].liftCoefficient
            let dd = first[index].dragCoefficient
                - second[index].dragCoefficient
            squared += dl * dl + dd * dd
            reference += second[index].liftCoefficient
                    * second[index].liftCoefficient
                + second[index].dragCoefficient
                    * second[index].dragCoefficient
        }
        return sqrt(squared / max(reference, 1.0e-30))
    }

    static func relativeError(_ value: Double, _ reference: Double) -> Double {
        abs(value - reference) / abs(reference)
    }

    static func relativeChange(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(abs(first), 1.0e-30)
    }

    static func batchDifference(backend: MetalBackend) throws -> BatchDifference {
        let chord = 8
        let grid = try GridSize(
            x: domainHorizontalChords * chord,
            y: domainHorizontalChords * chord,
            z: domainVerticalChords * chord
        )
        let cycleSteps = Int((cycleTravelPerChord * Double(chord)
            / latticeRadiusOfGyrationSpeed).rounded())
        let root = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.65 * Float(grid.z)
        )
        func makeSimulation() throws -> MetalPrescribedWingSimulation {
            try MetalPrescribedWingSimulation(
                backend: backend,
                grid: grid,
                chordCells: chord,
                cycleSteps: cycleSteps,
                root: root
            )
        }
        let single = try makeSimulation()
        let batched = try makeSimulation()
        let singleLoad = try single.advance(
            to: 96,
            batchSize: 1,
            captureFields: true
        )
        let batchedLoad = try batched.advance(
            to: 96,
            batchSize: 64,
            captureFields: true
        )
        let a = single.copyFields()
        let b = batched.copyFields()
        var densityDifference = 0.0
        var velocityDifference = 0.0
        for index in a.density.indices {
            densityDifference = max(
                densityDifference,
                abs(Double(a.density[index] - b.density[index]))
            )
            let difference = a.velocity[index] - b.velocity[index]
            velocityDifference = max(
                velocityDifference,
                Double(max(abs(difference.x), max(abs(difference.y), abs(difference.z))))
            )
        }
        let forceDifference = vectorLength(
            singleLoad.forceNewtons - batchedLoad.forceNewtons
        )
        return BatchDifference(
            density: densityDifference,
            velocity: velocityDifference,
            force: Double(forceDifference)
        )
    }

    static func archiveCase(
        _ result: MetalFlappingWingCaseResult,
        directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(
            to: directory.appendingPathComponent("case.json"),
            options: .atomic
        )
        let header = "phase,CL,CD,Fx,Fy,Fz\n"
        let rows = result.phaseSamples.map {
            "\($0.phase),\($0.liftCoefficient),\($0.dragCoefficient),\($0.forceX),\($0.forceY),\($0.forceZ)"
        }.joined(separator: "\n")
        try (header + rows + "\n").write(
            to: directory.appendingPathComponent("phase-history.csv"),
            atomically: true,
            encoding: .utf8
        )
        let format = """
        BirdFlowMetal prescribed flapping-wing archive schema 1
        case.json and phase-history.csv contain fifth-cycle loads.
        phase-XX-density.bin: little-endian Float32 density.
        phase-XX-velocity.bin: little-endian Float32 triples.
        phase-XX-qcriterion.bin: little-endian Float32 Q values.
        phase-XX-vorticity.bin: little-endian Float32 triples.
        Cell order is x + Nx * (y + Ny * z), x fastest.
        Q and vorticity use unit lattice spacing and central differences.
        """
        try format.write(
            to: directory.appendingPathComponent("FORMAT.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func archivePhase(
        directory: URL,
        phaseIndex: Int,
        density: [Float],
        velocity: [SIMD3<Float>],
        diagnostics: FieldDiagnostics
    ) throws {
        let prefix = String(format: "phase-%02d", phaseIndex)
        try littleEndianFloatData(density).write(
            to: directory.appendingPathComponent("\(prefix)-density.bin"),
            options: .atomic
        )
        try littleEndianVectorData(velocity).write(
            to: directory.appendingPathComponent("\(prefix)-velocity.bin"),
            options: .atomic
        )
        if let q = diagnostics.qCriterion {
            try littleEndianFloatData(q).write(
                to: directory.appendingPathComponent("\(prefix)-qcriterion.bin"),
                options: .atomic
            )
        }
        if let vorticity = diagnostics.vorticity {
            try littleEndianVectorData(vorticity).write(
                to: directory.appendingPathComponent("\(prefix)-vorticity.bin"),
                options: .atomic
            )
        }
    }

    static func archiveReport(
        _ report: MetalFlappingWingValidationReport,
        directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: directory.appendingPathComponent("report.json"),
            options: .atomic
        )
    }

    static func littleEndianFloatData(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for value in values {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        return data
    }

    static func littleEndianVectorData(_ values: [SIMD3<Float>]) -> Data {
        var flattened: [Float] = []
        flattened.reserveCapacity(values.count * 3)
        for value in values {
            flattened.append(value.x)
            flattened.append(value.y)
            flattened.append(value.z)
        }
        return littleEndianFloatData(flattened)
    }
}

private final class MetalPrescribedWingSimulation {
    private let backend: MetalBackend
    private let configuration: SimulationConfiguration
    private let parameters: MTLBuffer
    private let prepared: MTLBuffer
    private let measuredSourcePoints: MTLBuffer?
    private let measuredPhases: MTLBuffer?
    private let measuredDistanceKeys: MTLBuffer?
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidA: MTLBuffer
    private let solidB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let loadHistory: MTLBuffer
    private let momentumBudgetReductionA: MTLBuffer
    private let momentumBudgetReductionB: MTLBuffer
    private let momentumBudgetHistory: MTLBuffer
    private let bodyState: MTLBuffer
    private let preparePipeline: MTLComputePipelineState
    private let geometryPipeline: MTLComputePipelineState
    private let measuredLinkPipeline: MTLComputePipelineState?
    private let measuredClearPipeline: MTLComputePipelineState?
    private let measuredRasterPipeline: MTLComputePipelineState?
    private let measuredTriangleCount: Int
    private let initializePipeline: MTLComputePipelineState
    private let fluidPipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let gatherPipeline: MTLComputePipelineState
    private let storeLoadPipeline: MTLComputePipelineState
    private let momentumBudgetBeforePipeline: MTLComputePipelineState
    private let momentumBudgetAfterPipeline: MTLComputePipelineState
    private let momentumBudgetReductionPipeline: MTLComputePipelineState
    private let momentumBudgetStoreBeforePipeline: MTLComputePipelineState
    private let momentumBudgetStoreAfterPipeline: MTLComputePipelineState
    private let partialLoadCount: Int
    private let cycleSteps: Int
    private let loadComponent: PrescribedWingLoadComponent
    private let linkForceEstimator: PrescribedWingLinkForceEstimator
    private let momentumBudgetBounds: GPUControlVolumeBounds
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var currentSolid: MTLBuffer
    private var nextSolid: MTLBuffer
    private var lastLoad: MTLBuffer
    private var stepIndex = 0

    init(
        backend: MetalBackend,
        grid: GridSize,
        chordCells: Int,
        cycleSteps: Int,
        root: SIMD3<Float>,
        loadComponent: PrescribedWingLoadComponent = .total,
        linkForceEstimator: PrescribedWingLinkForceEstimator =
            .conservativeMovingDomain,
        measuredSurface: MeasuredWingSurfaceDataset? = nil,
        measuredHalfThicknessCells: Float = 0.75
    ) throws {
        self.backend = backend
        self.cycleSteps = cycleSteps
        self.loadComponent = loadComponent
        self.linkForceEstimator = linkForceEstimator
        let referenceSpeed = measuredSurface?.maximumPointSpeedMetersPerSecond
            ?? Float(MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed)
        let characteristicLength = measuredSurface == nil
            ? Float(chordCells)
            : Float(0.0195)
        let latticeReferenceSpeed = measuredSurface == nil
            ? referenceSpeed
            : referenceSpeed
                / (measuredSurface!.frequencyHz * Float(cycleSteps))
                / (characteristicLength / Float(chordCells))
        if measuredSurface != nil && latticeReferenceSpeed > 0.08 {
            throw MetalFlappingWingValidationError.invalidRequest(
                "measured surface requires more cycle steps: maximum lattice wall speed \(latticeReferenceSpeed) exceeds 0.08"
            )
        }
        let scaling = try LatticeScaling(
            characteristicLengthMeters: characteristicLength,
            characteristicLengthCells: chordCells,
            referenceSpeedMetersPerSecond: referenceSpeed,
            targetReynoldsNumber: Float(
                MetalFlappingWingValidator.reynoldsNumber
            ),
            physicalAirDensity: 1,
            latticeReferenceSpeed: latticeReferenceSpeed
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: max(4, chordCells / 2),
            spongeStrength: 0.04,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        if let measuredSurface {
            guard measuredHalfThicknessCells >= 0.5,
                  measuredHalfThicknessCells <= 2 else {
                throw MetalFlappingWingValidationError.invalidRequest(
                    "measured half thickness must be in [0.5, 2] cells"
                )
            }
            let gpuParameters = GPUMeasuredWingSurfaceParameters(
                counts: SIMD4<UInt32>(
                    UInt32(measuredSurface.chordCount),
                    UInt32(measuredSurface.spanCount),
                    UInt32(measuredSurface.frameCount),
                    0
                ),
                pointCounts: SIMD4<UInt32>(
                    UInt32(measuredSurface.verticesPerFrame),
                    UInt32(measuredSurface.pathsPerFrame),
                    UInt32(measuredSurface.pointsPerFrame),
                    0
                ),
                rootAndHalfThickness: SIMD4<Float>(
                    root,
                    measuredHalfThicknessCells * scaling.cellSizeMeters
                ),
                timingAndBounds: SIMD4<Float>(
                    Float(cycleSteps),
                    measuredSurface.frequencyHz,
                    measuredSurface.maximumRootRelativeRadiusMeters,
                    0
                )
            )
            parameters = try backend.makeSharedBuffer(value: gpuParameters)
            prepared = try backend.makePrivateBuffer(
                length: measuredSurface.pointsPerFrame
                    * MemoryLayout<GPUPreparedMeasuredWingPoint>.stride
            )
            let packed = measuredSurface.packedPoints()
            let pointsBuffer = try backend.makeSharedBuffer(
                length: packed.count * MemoryLayout<SIMD4<Float>>.stride
            )
            _ = packed.withUnsafeBytes { bytes in
                memcpy(pointsBuffer.contents(), bytes.baseAddress!, bytes.count)
            }
            measuredSourcePoints = pointsBuffer
            let phaseBuffer = try backend.makeSharedBuffer(
                length: measuredSurface.phases.count * MemoryLayout<Float>.stride
            )
            _ = measuredSurface.phases.withUnsafeBytes { bytes in
                memcpy(phaseBuffer.contents(), bytes.baseAddress!, bytes.count)
            }
            measuredPhases = phaseBuffer
            preparePipeline = try backend.pipeline(
                named: "prepareMeasuredWingSurface"
            )
            geometryPipeline = try backend.pipeline(
                named: "resolveMeasuredWingSurface"
            )
            measuredLinkPipeline = try backend.pipeline(
                named: "buildMeasuredWingSurfaceLinks"
            )
            measuredClearPipeline = try backend.pipeline(
                named: "clearMeasuredWingSurface"
            )
            measuredRasterPipeline = try backend.pipeline(
                named: "rasterizeMeasuredWingSurface"
            )
            measuredTriangleCount = 2
                * (measuredSurface.chordCount - 1)
                * (measuredSurface.spanCount - 1)
        } else {
            let gpuParameters = GPUFlappingWingParameters(
                rootAndChord: SIMD4<Float>(root, Float(chordCells)),
                geometry: SIMD4<Float>(
                    Float(MetalFlappingWingValidator.aspectRatio)
                        * Float(chordCells),
                    0.05 * Float(chordCells),
                    Float(MetalFlappingWingValidator.betaShape - 1),
                    Float(MetalFlappingWingValidator.betaNormalization)
                ),
                kinematics0: SIMD4<Float>(
                    Float(cycleSteps),
                    Float(MetalFlappingWingValidator.strokeHalfAmplitudeRadians),
                    Float(MetalFlappingWingValidator.accelerationDuration),
                    Float(MetalFlappingWingValidator.pitchDuration)
                ),
                kinematics1: SIMD4<Float>(
                    45 * .pi / 180,
                    135 * .pi / 180,
                    Float(MetalFlappingWingValidator.maximumStrokeRateRadiansPerCycle),
                    referenceSpeed
                )
            )
            parameters = try backend.makeSharedBuffer(value: gpuParameters)
            prepared = try backend.makePrivateBuffer(
                length: MemoryLayout<GPUPreparedFlappingWing>.stride
            )
            measuredSourcePoints = nil
            measuredPhases = nil
            preparePipeline = try backend.pipeline(
                named: "preparePrescribedFlappingWing"
            )
            geometryPipeline = try backend.pipeline(
                named: "buildPrescribedFlappingWing"
            )
            measuredLinkPipeline = nil
            measuredClearPipeline = nil
            measuredRasterPipeline = nil
            measuredTriangleCount = 0
        }
        initializePipeline = try backend.pipeline(named: "initializePopulations")
        fluidPipeline = try backend.pipeline(named: "stepFluidTRT")
        reductionPipeline = try backend.pipeline(named: "reduceForceTorque")
        gatherPipeline = try backend.pipeline(named: "gatherFloatValues")
        storeLoadPipeline = try backend.pipeline(named: "storeForceTorqueSample")
        momentumBudgetBeforePipeline = try backend.pipeline(
            named: "measureControlVolumeMomentumBeforeStep"
        )
        momentumBudgetAfterPipeline = try backend.pipeline(
            named: "measureControlVolumeMomentumAfterStep"
        )
        momentumBudgetReductionPipeline = try backend.pipeline(
            named: "reduceControlVolumeMomentumBudget"
        )
        momentumBudgetStoreBeforePipeline = try backend.pipeline(
            named: "storeControlVolumeMomentumBeforeSample"
        )
        momentumBudgetStoreAfterPipeline = try backend.pipeline(
            named: "storeControlVolumeMomentumAfterSample"
        )

        let cells = grid.cellCount
        let populationBytes = D3Q19.count * cells * MemoryLayout<Float>.stride
        let maskBytes = cells * MemoryLayout<UInt8>.stride
        let wallBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cells * MemoryLayout<Float>.stride
        let velocityBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        let measuredDistanceBytes = cells * MemoryLayout<UInt32>.stride
        partialLoadCount = max(1, (cells + 255) / 256)
        let reductionBytes = partialLoadCount
            * MemoryLayout<GPUForceTorque>.stride
        let historyBytes = cycleSteps * MemoryLayout<GPUForceTorque>.stride
        let momentumBudgetReductionBytes = partialLoadCount
            * MemoryLayout<GPUControlVolumeBudget>.stride
        let momentumBudgetHistoryBytes = cycleSteps
            * MemoryLayout<GPUControlVolumeBudget>.stride
        let horizontalHalfWidth = measuredSurface.map {
            Int(ceil(
                $0.maximumRootRelativeRadiusMeters / scaling.cellSizeMeters
            )) + 4
        } ?? (17 * chordCells + 3) / 4
        let verticalHalfWidth = measuredSurface == nil
            ? (3 * chordCells + 1) / 2
            : horizontalHalfWidth
        let rootCell = root / scaling.cellSizeMeters
        let minimumX = Int(rootCell.x) - horizontalHalfWidth
        let minimumY = Int(rootCell.y) - horizontalHalfWidth
        let minimumZ = Int(floor(rootCell.z - Float(verticalHalfWidth)))
        let maximumX = Int(rootCell.x) + horizontalHalfWidth
        let maximumY = Int(rootCell.y) + horizontalHalfWidth
        let maximumZ = Int(ceil(rootCell.z + Float(verticalHalfWidth)))
        guard
            minimumX > configuration.spongeWidthCells
                && minimumY > configuration.spongeWidthCells
                && minimumZ > configuration.spongeWidthCells
                && maximumX + configuration.spongeWidthCells < grid.x
                && maximumY + configuration.spongeWidthCells < grid.y
                && maximumZ + configuration.spongeWidthCells < grid.z
        else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "near-wing control volume overlaps the sponge or domain boundary"
            )
        }
        momentumBudgetBounds = GPUControlVolumeBounds(
            minimum: SIMD4<UInt32>(
                UInt32(minimumX),
                UInt32(minimumY),
                UInt32(minimumZ),
                0
            ),
            maximumExclusive: SIMD4<UInt32>(
                UInt32(maximumX),
                UInt32(maximumY),
                UInt32(maximumZ),
                0
            )
        )
        try backend.validateAllocationPlan(bufferLengths: [
            MemoryLayout<GPUFlappingWingParameters>.stride,
            MemoryLayout<GPUPreparedFlappingWing>.stride,
            populationBytes, populationBytes,
            maskBytes, maskBytes, wallBytes,
            densityBytes, velocityBytes,
            reductionBytes, reductionBytes, historyBytes,
            momentumBudgetReductionBytes, momentumBudgetReductionBytes,
            momentumBudgetHistoryBytes,
            MemoryLayout<GPUBirdBodyState>.stride,
            measuredSurface == nil ? 0 : measuredDistanceBytes,
        ])
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidA = try backend.makePrivateBuffer(length: maskBytes)
        solidB = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(length: wallBytes)
        density = try backend.makeSharedBuffer(length: densityBytes)
        velocity = try backend.makeSharedBuffer(length: velocityBytes)
        reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        loadHistory = try backend.makeSharedBuffer(length: historyBytes)
        momentumBudgetReductionA = try backend.makeSharedBuffer(
            length: momentumBudgetReductionBytes
        )
        momentumBudgetReductionB = try backend.makeSharedBuffer(
            length: momentumBudgetReductionBytes
        )
        momentumBudgetHistory = try backend.makeSharedBuffer(
            length: momentumBudgetHistoryBytes
        )
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: root))
        )
        measuredDistanceKeys = measuredSurface == nil
            ? nil
            : try backend.makePrivateBuffer(length: measuredDistanceBytes)
        currentPopulations = populationsA
        nextPopulations = populationsB
        currentSolid = solidA
        nextSolid = solidB
        lastLoad = reductionA
        try initialize()
    }

    func advance(
        to targetStep: Int,
        batchSize: Int,
        captureFields: Bool,
        recordEveryStepLoad: Bool = false,
        recordEveryStepMomentumBudget: Bool = false
    ) throws -> ForceTorque {
        guard targetStep >= stepIndex, batchSize > 0 else {
            throw BirdFlowError.invalidAdvanceRequest(
                steps: targetStep - stepIndex,
                batchSize: batchSize
            )
        }
        while stepIndex < targetStep {
            let count = min(batchSize, targetStep - stepIndex)
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create prescribed-wing command buffer."
                )
            }
            for localStep in 0..<count {
                let absoluteStep = stepIndex + localStep + 1
                let final = absoluteStep == targetStep
                var uniforms = makeUniforms(
                    time: Float(absoluteStep),
                    captureFields: final && captureFields,
                    accumulateLoads: final || recordEveryStepLoad,
                    hasPreviousGeometry: true
                )
                try encodePrescribedPreparation(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                if recordEveryStepMomentumBudget {
                    let before = try encodeMomentumBudgetBeforeStep(
                        commandBuffer: commandBuffer,
                        uniforms: &uniforms
                    )
                    try encodeMomentumBudgetStore(
                        commandBuffer: commandBuffer,
                        budget: before,
                        sampleIndex: (absoluteStep - 1) % cycleSteps,
                        beforeStep: true
                    )
                }
                try encodePrescribedGeometry(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms,
                    target: nextSolid
                )
                try encodePrescribedFluid(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                if recordEveryStepMomentumBudget {
                    let after = try encodeMomentumBudgetAfterStep(
                        commandBuffer: commandBuffer,
                        uniforms: &uniforms
                    )
                    try encodeMomentumBudgetStore(
                        commandBuffer: commandBuffer,
                        budget: after,
                        sampleIndex: (absoluteStep - 1) % cycleSteps,
                        beforeStep: false
                    )
                }
                if final || recordEveryStepLoad {
                    let reduced = try encodePrescribedReduction(
                        commandBuffer: commandBuffer
                    )
                    if final {
                        lastLoad = reduced
                    }
                    if recordEveryStepLoad {
                        try encodePrescribedLoadStore(
                            commandBuffer: commandBuffer,
                            load: reduced,
                            sampleIndex: (absoluteStep - 1) % cycleSteps
                        )
                    }
                }
                swap(&currentPopulations, &nextPopulations)
                swap(&currentSolid, &nextSolid)
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            stepIndex += count
        }
        return lastLoad.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
            .pointee
            .coreValue
    }

    func copyFields() -> (density: [Float], velocity: [SIMD3<Float>]) {
        let count = configuration.grid.cellCount
        let densityPointer = density.contents().assumingMemoryBound(to: Float.self)
        let velocityPointer = velocity.contents()
            .assumingMemoryBound(to: SIMD4<Float>.self)
        return (
            Array(UnsafeBufferPointer(start: densityPointer, count: count)),
            (0..<count).map {
                let value = velocityPointer[$0]
                return SIMD3<Float>(value.x, value.y, value.z)
            }
        )
    }

    var measuredVelocityToLattice: Float {
        configuration.scaling.velocityToLattice
    }

    func copyPreparedMeasuredPoints(
        phase: Double
    ) throws -> [GPUPreparedMeasuredWingPoint] {
        guard measuredSourcePoints != nil else {
            throw MetalFlappingWingValidationError.invalidRequest(
                "prepared measured points requested for an analytic wing"
            )
        }
        let staging = try backend.makeSharedBuffer(length: prepared.length)
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing prepared-point audit buffer."
            )
        }
        var uniforms = makeUniforms(
            time: Float(phase * Double(cycleSteps)),
            captureFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        try encodePrescribedPreparation(
            commandBuffer: commandBuffer,
            uniforms: &uniforms
        )
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing prepared-point audit blit."
            )
        }
        blit.copy(
            from: prepared,
            sourceOffset: 0,
            to: staging,
            destinationOffset: 0,
            size: prepared.length
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
        let count = prepared.length
            / MemoryLayout<GPUPreparedMeasuredWingPoint>.stride
        return Array(UnsafeBufferPointer(
            start: staging.contents().assumingMemoryBound(
                to: GPUPreparedMeasuredWingPoint.self
            ),
            count: count
        ))
    }

    func copyGeometry(
        phase: Double
    ) throws -> MetalFlappingWingValidator.GeometrySnapshot {
        let maskStaging = try backend.makeSharedBuffer(
            length: currentSolid.length
        )
        let wallStaging = try backend.makeSharedBuffer(
            length: wallVelocity.length
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing geometry-audit buffer."
            )
        }
        var uniforms = makeUniforms(
            time: Float(phase * Double(cycleSteps)),
            captureFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        try encodePrescribedPreparation(
            commandBuffer: commandBuffer,
            uniforms: &uniforms
        )
        try encodePrescribedGeometry(
            commandBuffer: commandBuffer,
            uniforms: &uniforms,
            target: nextSolid
        )
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing geometry-audit blit."
            )
        }
        blit.copy(
            from: nextSolid,
            sourceOffset: 0,
            to: maskStaging,
            destinationOffset: 0,
            size: nextSolid.length
        )
        blit.copy(
            from: wallVelocity,
            sourceOffset: 0,
            to: wallStaging,
            destinationOffset: 0,
            size: wallVelocity.length
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)

        let cellCount = configuration.grid.cellCount
        let maskPointer = maskStaging.contents()
            .assumingMemoryBound(to: UInt8.self)
        let wallPointer = wallStaging.contents()
            .assumingMemoryBound(to: SIMD4<Float>.self)
        let mask = Array(UnsafeBufferPointer(
            start: maskPointer,
            count: cellCount
        ))
        var linkPopulationIndices: [UInt32] = []
        linkPopulationIndices.reserveCapacity(cellCount / 16)
        let grid = configuration.grid
        for z in 0..<grid.z {
            for y in 0..<grid.y {
                for x in 0..<grid.x {
                    let sourceIndex = x + grid.x * (y + grid.y * z)
                    guard mask[sourceIndex] != 0 else { continue }
                    for (q, direction) in D3Q19.directions.enumerated()
                        where q > 0 {
                        let fluidX = x + Int(direction.x)
                        let fluidY = y + Int(direction.y)
                        let fluidZ = z + Int(direction.z)
                        guard fluidX >= 0, fluidX < grid.x,
                              fluidY >= 0, fluidY < grid.y,
                              fluidZ >= 0, fluidZ < grid.z else {
                            continue
                        }
                        let fluidIndex = fluidX
                            + grid.x * (fluidY + grid.y * fluidZ)
                        guard mask[fluidIndex] == 0 else { continue }
                        linkPopulationIndices.append(UInt32(
                            q * cellCount + sourceIndex
                        ))
                    }
                }
            }
        }

        let gathered: [Float]
        if linkPopulationIndices.isEmpty {
            gathered = []
        } else {
            let indexBytes = linkPopulationIndices.count
                * MemoryLayout<UInt32>.stride
            let valueBytes = linkPopulationIndices.count
                * MemoryLayout<Float>.stride
            let indices = try backend.makeSharedBuffer(length: indexBytes)
            let values = try backend.makeSharedBuffer(length: valueBytes)
            _ = linkPopulationIndices.withUnsafeBytes { source in
                memcpy(indices.contents(), source.baseAddress!, indexBytes)
            }
            guard let gatherCommand = backend.queue.makeCommandBuffer(),
                  let encoder = gatherCommand.makeComputeCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create prescribed-wing link-audit encoder."
                )
            }
            var linkCount = UInt32(linkPopulationIndices.count)
            encoder.setBuffer(currentPopulations, offset: 0, index: 0)
            encoder.setBuffer(indices, offset: 0, index: 1)
            encoder.setBuffer(values, offset: 0, index: 2)
            encoder.setBytes(
                &linkCount,
                length: MemoryLayout<UInt32>.stride,
                index: 3
            )
            backend.dispatch1D(
                encoder: encoder,
                pipeline: gatherPipeline,
                count: linkPopulationIndices.count
            )
            encoder.endEncoding()
            gatherCommand.commit()
            gatherCommand.waitUntilCompleted()
            try check(gatherCommand)
            gathered = Array(UnsafeBufferPointer(
                start: values.contents().assumingMemoryBound(to: Float.self),
                count: linkPopulationIndices.count
            ))
        }
        return MetalFlappingWingValidator.GeometrySnapshot(
            solid: mask,
            wallVelocityAndImplicit: Array(UnsafeBufferPointer(
                start: wallPointer,
                count: cellCount
            )),
            boundaryLinkFractions: gathered
        )
    }

    func copyRecordedLoads() -> [ForceTorque] {
        let pointer = loadHistory.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
        return (0..<cycleSteps).map { pointer[$0].coreValue }
    }

    func copyRecordedMomentumBudgets() ->
        [PrescribedWingMomentumBudgetStep]
    {
        let pointer = momentumBudgetHistory.contents()
            .assumingMemoryBound(to: GPUControlVolumeBudget.self)
        let scale = configuration.scaling.forceToPhysical
        func load(_ latticeForce: SIMD3<Float>) -> ForceTorque {
            ForceTorque(
                forceNewtons: latticeForce * scale,
                torqueNewtonMeters: .zero
            )
        }
        return (0..<cycleSteps).map { index in
            let raw = pointer[index]
            let oldMomentum = SIMD3<Float>(
                raw.oldFluidMomentum.x,
                raw.oldFluidMomentum.y,
                raw.oldFluidMomentum.z
            )
            let newMomentum = SIMD3<Float>(
                raw.newFluidMomentum.x,
                raw.newFluidMomentum.y,
                raw.newFluidMomentum.z
            )
            let outwardFlux = SIMD3<Float>(
                raw.outwardMomentumFlux.x,
                raw.outwardMomentumFlux.y,
                raw.outwardMomentumFlux.z
            )
            let topologyLattice = SIMD3<Float>(
                raw.topologyReservoirCorrection.x,
                raw.topologyReservoirCorrection.y,
                raw.topologyReservoirCorrection.z
            )
            let negativeStorageLattice = oldMomentum - newMomentum
            let negativeFluxLattice = -outwardFlux
            let rawTotalLattice = negativeStorageLattice
                + negativeFluxLattice
            return PrescribedWingMomentumBudgetStep(
                negativeStorage: load(negativeStorageLattice),
                negativeSurfaceFlux: load(negativeFluxLattice),
                topologyReservoirCorrection: load(topologyLattice),
                rawTotal: load(rawTotalLattice),
                total: load(
                    rawTotalLattice + topologyLattice
                ),
                solidControlSurfaceCrossingLinkCount: Int(
                    raw.outwardMomentumFlux.w.rounded()
                )
            )
        }
    }

    var controlVolumeMetadata: (
        bounds: MetalFlappingWingControlVolumeBounds,
        spongeWidthCells: Int,
        minimumDomainDistanceCells: Int
    ) {
        let minimum = momentumBudgetBounds.minimum
        let maximum = momentumBudgetBounds.maximumExclusive
        let bounds = MetalFlappingWingControlVolumeBounds(
            minimumX: Int(minimum.x),
            minimumY: Int(minimum.y),
            minimumZ: Int(minimum.z),
            maximumExclusiveX: Int(maximum.x),
            maximumExclusiveY: Int(maximum.y),
            maximumExclusiveZ: Int(maximum.z)
        )
        let grid = configuration.grid
        let minimumDistance = min(
            Int(minimum.x) - 1,
            Int(minimum.y) - 1,
            Int(minimum.z) - 1,
            grid.x - 1 - Int(maximum.x),
            grid.y - 1 - Int(maximum.y),
            grid.z - 1 - Int(maximum.z)
        )
        return (
            bounds,
            configuration.spongeWidthCells,
            minimumDistance
        )
    }

    private func makeUniforms(
        time: Float,
        captureFields: Bool,
        accumulateLoads: Bool,
        hasPreviousGeometry: Bool
    ) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: time,
            captureMacroscopicFields: captureFields,
            accumulateLoads: accumulateLoads,
            hasPreviousGeometry: hasPreviousGeometry,
            periodicBoundaries: false,
            // Negative w enables link-distance interpolation. The existing
            // planar oscillating-wall flag is positive, keeping its baseline
            // operator unchanged.
            caseParameters: SIMD4<Float>(
                loadComponent.rawValue,
                linkForceEstimator.rawValue,
                1,
                -1
            )
        )
    }

    private func initialize() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing initialization buffer."
            )
        }
        var uniforms = makeUniforms(
            time: 0,
            captureFields: true,
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        try encodePrescribedPreparation(
            commandBuffer: commandBuffer,
            uniforms: &uniforms
        )
        try encodePrescribedGeometry(
            commandBuffer: commandBuffer,
            uniforms: &uniforms,
            target: currentSolid
        )
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing mask-copy encoder."
            )
        }
        blit.copy(
            from: currentSolid,
            sourceOffset: 0,
            to: nextSolid,
            destinationOffset: 0,
            size: currentSolid.length
        )
        blit.endEncoding()
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing population encoder."
            )
        }
        encoder.label = "Initialize prescribed hovering wing"
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(wallVelocity, offset: 0, index: 2)
        encoder.setBuffer(density, offset: 0, index: 3)
        encoder.setBuffer(velocity, offset: 0, index: 4)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
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

    private func encodePrescribedPreparation(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        if measuredSourcePoints != nil {
            try encodeMeasuredPreparation(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            return
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing preparation encoder."
            )
        }
        encoder.setBuffer(prepared, offset: 0, index: 0)
        encoder.setBuffer(parameters, offset: 0, index: 1)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 2
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: preparePipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func encodeMeasuredPreparation(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let measuredSourcePoints, let measuredPhases,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing preparation encoder."
            )
        }
        encoder.setBuffer(measuredSourcePoints, offset: 0, index: 0)
        encoder.setBuffer(measuredPhases, offset: 0, index: 1)
        encoder.setBuffer(prepared, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: preparePipeline,
            count: prepared.length
                / MemoryLayout<GPUPreparedMeasuredWingPoint>.stride
        )
        encoder.endEncoding()
    }

    private func encodePrescribedGeometry(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        target: MTLBuffer
    ) throws {
        if measuredDistanceKeys != nil {
            try encodeMeasuredGeometry(
                commandBuffer: commandBuffer,
                uniforms: &uniforms,
                target: target
            )
            return
        }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing geometry encoder."
            )
        }
        encoder.setBuffer(target, offset: 0, index: 0)
        encoder.setBuffer(wallVelocity, offset: 0, index: 1)
        encoder.setBuffer(currentSolid, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        encoder.setBuffer(prepared, offset: 0, index: 4)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
        )
        // Solid-node distribution slots are dormant during streaming. Reuse
        // them for per-direction wall fractions instead of allocating and
        // reading another full-grid Metal buffer.
        encoder.setBuffer(currentPopulations, offset: 0, index: 6)
        // Newly covered nodes preserve their pre-geometry density/momentum in
        // this existing field allocation before their distribution slots are
        // repurposed as the link table.
        encoder.setBuffer(velocity, offset: 0, index: 7)
        backend.dispatch3D(
            encoder: encoder,
            pipeline: geometryPipeline,
            width: configuration.grid.x,
            height: configuration.grid.y,
            depth: configuration.grid.z
        )
        encoder.endEncoding()
    }

    private func encodeMeasuredGeometry(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        target: MTLBuffer
    ) throws {
        guard let measuredDistanceKeys,
              let measuredClearPipeline,
              let measuredRasterPipeline else {
            throw BirdFlowError.commandBufferFailed(
                "Measured-wing geometry resources are incomplete."
            )
        }
        guard let clearEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing clear encoder."
            )
        }
        clearEncoder.setBuffer(target, offset: 0, index: 0)
        clearEncoder.setBuffer(wallVelocity, offset: 0, index: 1)
        clearEncoder.setBuffer(measuredDistanceKeys, offset: 0, index: 2)
        clearEncoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: clearEncoder,
            pipeline: measuredClearPipeline,
            count: configuration.grid.cellCount
        )
        clearEncoder.endEncoding()

        guard let rasterEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing raster encoder."
            )
        }
        rasterEncoder.setBuffer(prepared, offset: 0, index: 0)
        rasterEncoder.setBuffer(measuredDistanceKeys, offset: 0, index: 1)
        rasterEncoder.setBuffer(parameters, offset: 0, index: 2)
        rasterEncoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: rasterEncoder,
            pipeline: measuredRasterPipeline,
            count: measuredTriangleCount
        )
        rasterEncoder.endEncoding()

        guard let resolveEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing resolve encoder."
            )
        }
        resolveEncoder.setBuffer(target, offset: 0, index: 0)
        resolveEncoder.setBuffer(wallVelocity, offset: 0, index: 1)
        resolveEncoder.setBuffer(currentSolid, offset: 0, index: 2)
        resolveEncoder.setBuffer(parameters, offset: 0, index: 3)
        resolveEncoder.setBuffer(prepared, offset: 0, index: 4)
        resolveEncoder.setBuffer(measuredDistanceKeys, offset: 0, index: 5)
        resolveEncoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 6
        )
        resolveEncoder.setBuffer(currentPopulations, offset: 0, index: 7)
        resolveEncoder.setBuffer(velocity, offset: 0, index: 8)
        backend.dispatch1D(
            encoder: resolveEncoder,
            pipeline: geometryPipeline,
            count: configuration.grid.cellCount
        )
        resolveEncoder.endEncoding()
        try encodeMeasuredLinks(
            commandBuffer: commandBuffer,
            uniforms: &uniforms,
            target: target
        )
    }

    private func encodeMeasuredLinks(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        target: MTLBuffer
    ) throws {
        guard let measuredLinkPipeline,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create measured-wing link encoder."
            )
        }
        encoder.setBuffer(target, offset: 0, index: 0)
        encoder.setBuffer(wallVelocity, offset: 0, index: 1)
        encoder.setBuffer(currentPopulations, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch3D(
            encoder: encoder,
            pipeline: measuredLinkPipeline,
            width: configuration.grid.x,
            height: configuration.grid.y,
            depth: configuration.grid.z
        )
        encoder.endEncoding()
    }

    private func encodePrescribedFluid(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing fluid encoder."
            )
        }
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(currentSolid, offset: 0, index: 2)
        encoder.setBuffer(nextSolid, offset: 0, index: 3)
        encoder.setBuffer(wallVelocity, offset: 0, index: 4)
        encoder.setBuffer(density, offset: 0, index: 5)
        encoder.setBuffer(velocity, offset: 0, index: 6)
        encoder.setBuffer(reductionA, offset: 0, index: 7)
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

    private func encodePrescribedReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        var input = reductionA
        var output = reductionB
        var count = partialLoadCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create prescribed-wing reduction encoder."
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
            output = output === reductionA ? reductionB : reductionA
        }
        return input
    }

    private func encodePrescribedLoadStore(
        commandBuffer: MTLCommandBuffer,
        load: MTLBuffer,
        sampleIndex: Int
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create prescribed-wing history encoder."
            )
        }
        var index32 = UInt32(sampleIndex)
        encoder.setBuffer(load, offset: 0, index: 0)
        encoder.setBuffer(loadHistory, offset: 0, index: 1)
        encoder.setBytes(
            &index32,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: storeLoadPipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func encodeMomentumBudgetBeforeStep(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws -> MTLBuffer {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create pre-step control-volume momentum encoder."
            )
        }
        var bounds = momentumBudgetBounds
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(momentumBudgetReductionA, offset: 0, index: 2)
        encoder.setBytes(
            &bounds,
            length: MemoryLayout<GPUControlVolumeBounds>.stride,
            index: 3
        )
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: momentumBudgetBeforePipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
        return try encodeMomentumBudgetReduction(commandBuffer: commandBuffer)
    }

    private func encodeMomentumBudgetAfterStep(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws -> MTLBuffer {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create post-step control-volume momentum encoder."
            )
        }
        var bounds = momentumBudgetBounds
        encoder.setBuffer(nextPopulations, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(nextSolid, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(velocity, offset: 0, index: 4)
        encoder.setBuffer(momentumBudgetReductionA, offset: 0, index: 5)
        encoder.setBytes(
            &bounds,
            length: MemoryLayout<GPUControlVolumeBounds>.stride,
            index: 6
        )
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: momentumBudgetAfterPipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
        return try encodeMomentumBudgetReduction(commandBuffer: commandBuffer)
    }

    private func encodeMomentumBudgetReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        var input = momentumBudgetReductionA
        var output = momentumBudgetReductionB
        var count = partialLoadCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let reductionEncoder = commandBuffer
                .makeComputeCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create control-volume reduction encoder."
                )
            }
            reductionEncoder.setBuffer(input, offset: 0, index: 0)
            reductionEncoder.setBuffer(output, offset: 0, index: 1)
            reductionEncoder.setBytes(
                &count32,
                length: MemoryLayout<UInt32>.stride,
                index: 2
            )
            backend.dispatch1D(
                encoder: reductionEncoder,
                pipeline: momentumBudgetReductionPipeline,
                count: outputCount
            )
            reductionEncoder.endEncoding()
            count = outputCount
            input = output
            output = output === momentumBudgetReductionA
                ? momentumBudgetReductionB
                : momentumBudgetReductionA
        }
        return input
    }

    private func encodeMomentumBudgetStore(
        commandBuffer: MTLCommandBuffer,
        budget: MTLBuffer,
        sampleIndex: Int,
        beforeStep: Bool
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create control-volume history encoder."
            )
        }
        var index32 = UInt32(sampleIndex)
        encoder.setBuffer(budget, offset: 0, index: 0)
        encoder.setBuffer(momentumBudgetHistory, offset: 0, index: 1)
        encoder.setBytes(
            &index32,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: beforeStep
                ? momentumBudgetStoreBeforePipeline
                : momentumBudgetStoreAfterPipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription ?? "Unknown Metal error"
            )
        }
    }
}

private extension Array where Element == Double {
    var mean: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
}

private func dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
    a.x * b.x + a.y * b.y + a.z * b.z
}

private func cross(
    _ a: SIMD3<Double>,
    _ b: SIMD3<Double>
) -> SIMD3<Double> {
    SIMD3<Double>(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
}

private func rotate(
    _ value: SIMD3<Double>,
    around axis: SIMD3<Double>,
    angle: Double
) -> SIMD3<Double> {
    let sine = sin(angle)
    let cosine = cos(angle)
    return value * cosine
        + cross(axis, value) * sine
        + axis * dot(axis, value) * (1 - cosine)
}
#endif

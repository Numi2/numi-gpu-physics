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
        farFieldSpeed: Float = 0
    ) throws -> MetalHighReTranslatingBodyStabilityReport {
        guard steps == 500 else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                "high-Re translating-body stability uses a locked 500-step contract"
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
        let matchedViscosities: [(Int, Float)] = [
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

    public static func run() throws
        -> MetalTranslatingBodyTopologyValidationReport
    {
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let caseConfiguration = try MetalTranslatingBodyCaseConfiguration
            .standard()
        let legacy = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 0,
            caseConfiguration: caseConfiguration
        ).run(steps: steps)
        let conservative = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6,
            caseConfiguration: caseConfiguration
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

private struct MetalTranslatingBodyTopologyStep {
    let measuredForce: SIMD3<Float>
    let rawBudgetForce: SIMD3<Float>
    let newlyCoveredCells: Int
    let newlyUncoveredCells: Int
    let solidControlSurfaceCrossingLinkCount: Int
}

private final class MetalTranslatingBodyTopologySimulation {
    private let backend: MetalBackend
    private let configuration: SimulationConfiguration
    private let periodicBoundaries: Bool
    private let linkForceMode: UInt32
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
    private let initializePipeline: MTLComputePipelineState
    private let geometryPipeline: MTLComputePipelineState
    private let fluidPipeline: MTLComputePipelineState
    private let loadReductionPipeline: MTLComputePipelineState
    private let budgetBeforePipeline: MTLComputePipelineState
    private let budgetAfterPipeline: MTLComputePipelineState
    private let budgetReductionPipeline: MTLComputePipelineState
    private let partialCount: Int
    private let bounds: GPUTranslatingTopologyBounds
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var currentSolid: MTLBuffer
    private var nextSolid: MTLBuffer

    init(
        backend: MetalBackend,
        linkForceMode: UInt32,
        caseConfiguration: MetalTranslatingBodyCaseConfiguration
    ) throws {
        self.backend = backend
        self.linkForceMode = linkForceMode
        periodicBoundaries = caseConfiguration.periodicBoundaries
        let grid = caseConfiguration.grid
        let referenceSpeed = caseConfiguration.referenceSpeedLattice
        let characteristicLengthCells = 8
        let targetReynoldsNumber = referenceSpeed
            * Float(characteristicLengthCells)
            / caseConfiguration.latticeKinematicViscosity
        let scaling = try LatticeScaling(
            characteristicLengthMeters: 8,
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
            spongeWidthCells: 4,
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
                    referenceSpeed,
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

        let cells = grid.cellCount
        let populationBytes = D3Q19.count * cells
            * MemoryLayout<Float>.stride
        let maskBytes = cells * MemoryLayout<UInt8>.stride
        let wallBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cells * MemoryLayout<Float>.stride
        let velocityBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        partialCount = max(1, (cells + 255) / 256)
        let loadBytes = partialCount * MemoryLayout<GPUForceTorque>.stride
        let budgetBytes = partialCount
            * MemoryLayout<GPUTranslatingTopologyBudget>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            MemoryLayout<GPUTranslatingTopologyParameters>.stride,
            MemoryLayout<GPUBirdBodyState>.stride,
            populationBytes, populationBytes,
            maskBytes, maskBytes, wallBytes,
            densityBytes, velocityBytes,
            loadBytes, loadBytes,
            budgetBytes, budgetBytes, budgetBytes, budgetBytes,
        ])
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

    func run(steps: Int) throws -> [MetalTranslatingBodyTopologyStep] {
        var history: [MetalTranslatingBodyTopologyStep] = []
        history.reserveCapacity(steps)
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
            let load = try encodeTopologyLoadReduction(
                commandBuffer: commandBuffer
            )
            let after = try encodeTopologyBudgetAfter(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
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
                )
            ))
            swap(&currentPopulations, &nextPopulations)
            swap(&currentSolid, &nextSolid)
        }
        return history
    }

    private func makeUniforms(time: Float) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: time,
            // The velocity buffer carries preserved newly covered momentum
            // from geometry into the fluid step; field capture would replace
            // that validation-only scratch value before the impulse is read.
            captureMacroscopicFields: false,
            accumulateLoads: true,
            hasPreviousGeometry: true,
            periodicBoundaries: periodicBoundaries,
            caseParameters: SIMD4<Float>(
                0,
                Float(linkForceMode),
                1,
                -1
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

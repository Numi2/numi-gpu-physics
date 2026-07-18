import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal
#endif

public enum FormationFlyerID: String, Codable, CaseIterable, Sendable {
    case leader
    case follower
}

public struct FormationFlightConfiguration: Codable, Sendable {
    public var chordCells: Int
    public var cycles: Int
    public var followerOffsetChords: SIMD3<Double>
    public var followerPhaseOffsetCycles: Double

    public init(
        chordCells: Int = 8,
        cycles: Int = 3,
        followerOffsetChords: SIMD3<Double> = SIMD3(0, 0, -4),
        followerPhaseOffsetCycles: Double = 0.25
    ) {
        self.chordCells = chordCells
        self.cycles = cycles
        self.followerOffsetChords = followerOffsetChords
        self.followerPhaseOffsetCycles = followerPhaseOffsetCycles
    }
}

public struct FormationFlyerPowerSummary: Codable, Sendable {
    public let flyer: FormationFlyerID
    public let meanSignedPowerWatts: Double
    public let meanPositivePowerWatts: Double
    public let rmsPowerWatts: Double
    public let maximumPositivePowerWatts: Double
    public let meanLiftCoefficient: Double
    public let meanDragCoefficient: Double
}

public struct FormationFlightPhaseSample: Codable, Sendable {
    public let leaderPhase: Double
    public let followerPhase: Double
    public let leaderLiftCoefficient: Double
    public let followerLiftCoefficient: Double
    public let leaderDragCoefficient: Double
    public let followerDragCoefficient: Double
    public let leaderSignedPowerWatts: Double
    public let followerSignedPowerWatts: Double
    public let leaderForceNewtons: SIMD3<Float>
    public let followerForceNewtons: SIMD3<Float>
}

public struct FormationFlightGateReport: Codable, Sendable {
    public let finite: Bool
    public let noGeometryOverlap: Bool
    public let ownerForceClosurePassed: Bool
    public let ownerTorqueClosurePassed: Bool
    public let isolatedOwnerClosurePassed: Bool
    public let periodicPowerPassed: Bool
    public let maximumRelativeForceClosureResidual: Double
    public let maximumRelativeTorqueClosureResidual: Double
    public let maximumIsolatedRelativeClosureResidual: Double
    public let maximumAllowedRelativeClosureResidual: Double
    public let maximumRelativePeriodicPowerDifference: Double
    public let maximumAllowedRelativePeriodicPowerDifference: Double
    public let passed: Bool
}

public struct FormationFlightReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let deviceName: String
    public let configuration: FormationFlightConfiguration
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cycleSteps: Int
    public let runtimeSeconds: Double
    public let coupledLeader: FormationFlyerPowerSummary
    public let coupledFollower: FormationFlyerPowerSummary
    public let isolatedLeader: FormationFlyerPowerSummary
    public let isolatedFollower: FormationFlyerPowerSummary
    public let leaderPositivePowerChangeFraction: Double
    public let followerPositivePowerChangeFraction: Double
    public let followerPositivePowerSavingFraction: Double
    public let systemPositivePowerChangeFraction: Double
    public let overlapVoxelSamples: Int
    public let phaseSamples: [FormationFlightPhaseSample]
    public let gates: FormationFlightGateReport
    public let scientificVerdict: String
}

public struct FormationFlightFlowSlice: Codable, Sendable {
    public let schemaVersion: Int
    public let plane: String
    public let planeIndex: Int
    public let width: Int
    public let height: Int
    public let chordCells: Int
    public let phase: Double
    public let velocityUnits: String
    public let vorticityUnits: String
    public let maximumVorticityMagnitudePerSecond: Float
    public let maximumAbsoluteVerticalVelocityMetersPerSecond: Float
    public let vorticityMagnitudePerSecond: [Float]
    public let verticalVelocityMetersPerSecond: [Float]
    public let ownerMask: [UInt8]
}

public struct FormationFlightFlowSliceIndexEntry: Codable, Sendable {
    public let leaderPhase: Double
    public let followerPhase: Double
    public let file: String
}

public struct FormationFlightFlowSliceIndex: Codable, Sendable {
    public let schemaVersion: Int
    public let plane: String
    public let entries: [FormationFlightFlowSliceIndexEntry]
}

public struct FormationFlightMechanismComponentSample: Codable, Sendable {
    public let load: ForceTorque
    public let actuatorPowerWatts: Double
}

public struct FormationFlightMechanismComponentBreakdown: Codable, Sendable {
    public let reflectedPopulation: FormationFlightMechanismComponentSample
    public let interpolationAuxiliary: FormationFlightMechanismComponentSample
    public let movingWall: FormationFlightMechanismComponentSample
    public let coverImpulse: FormationFlightMechanismComponentSample
    public let uncoverImpulse: FormationFlightMechanismComponentSample
}

public struct FormationFlightMechanismProbeSample: Codable, Sendable {
    public let leaderPhase: Double
    public let followerPhase: Double
    public let flyer: FormationFlyerID
    public let production: FormationFlightMechanismComponentSample
    public let reconstructed: FormationFlightMechanismComponentSample
    public let components: FormationFlightMechanismComponentBreakdown
    public let relativeForceClosureResidual: Double
    public let relativeTorqueClosureResidual: Double
    public let relativePowerClosureResidual: Double
}

public struct FormationFlightMechanismProbeReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let componentOrder: [String]
    public let samples: [FormationFlightMechanismProbeSample]
    public let maximumRelativeForceClosureResidual: Double
    public let maximumRelativeTorqueClosureResidual: Double
    public let maximumRelativePowerClosureResidual: Double
    public let maximumAllowedRelativeClosureResidual: Double
    public let finite: Bool
    public let closurePassed: Bool
    public let passed: Bool
    public let scientificVerdict: String
}

public struct FormationFlightBoundarySourceDirectionSample: Codable, Sendable {
    public let directionIndex: Int
    public let direction: SIMD3<Int32>
    public let linkCount: Int
    public let rawReflectedPopulationSum: Double
    public let reflectedIncomingPopulationSum: Double
    public let interpolationAuxiliaryPopulationSum: Double
    public let movingWallPopulationSum: Double
    public let reconstructedIncomingPopulationSum: Double
    public let absoluteIncomingPopulationSum: Double
    public let squaredIncomingPopulationSum: Double
    public let linkFractionSum: Double
    public let squaredLinkFractionSum: Double
    public let wallProjectionSum: Double
    public let absoluteWallProjectionSum: Double
    public let wallSpeedSum: Double
    public let nearInterpolationLinkCount: Int
    public let farInterpolationLinkCount: Int
    public let halfwayFallbackLinkCount: Int
}

public struct FormationFlightBoundarySourceCensusSample: Codable, Sendable {
    public let leaderPhase: Double
    public let followerPhase: Double
    public let flyer: FormationFlyerID
    public let wingChordAxis: SIMD3<Double>
    public let wingSpanAxis: SIMD3<Double>
    public let wingNormalAxis: SIMD3<Double>
    public let totalBoundaryLinkCount: Int
    public let relativeReconstructionClosureResidual: Double
    public let branchCountClosurePassed: Bool
    public let directions: [FormationFlightBoundarySourceDirectionSample]
}

public struct FormationFlightBoundarySourceCensusReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let samples: [FormationFlightBoundarySourceCensusSample]
    public let maximumRelativeReconstructionClosureResidual: Double
    public let maximumAllowedRelativeReconstructionClosureResidual: Double
    public let finite: Bool
    public let reconstructionClosurePassed: Bool
    public let branchCountClosurePassed: Bool
    public let passed: Bool
    public let scientificVerdict: String
}

public struct FormationFlightFieldReplayGateReport: Codable, Sendable {
    public let finite: Bool
    public let noGeometryOverlap: Bool
    public let ownerForceClosurePassed: Bool
    public let ownerTorqueClosurePassed: Bool
    public let periodicPowerPassed: Bool
    public let referenceCoupledHistoryPassed: Bool
    public let maximumRelativeForceClosureResidual: Double
    public let maximumRelativeTorqueClosureResidual: Double
    public let maximumRelativePeriodicPowerDifference: Double
    public let maximumRelativeReferenceCoupledHistoryDifference: Double
    public let maximumAllowedRelativeClosureResidual: Double
    public let maximumAllowedRelativePeriodicPowerDifference: Double
    public let maximumAllowedRelativeReferenceCoupledHistoryDifference: Double
    public let mechanismProbePassed: Bool?
    public let maximumRelativeMechanismForceClosureResidual: Double?
    public let maximumRelativeMechanismTorqueClosureResidual: Double?
    public let maximumRelativeMechanismPowerClosureResidual: Double?
    public let boundarySourceCensusPassed: Bool?
    public let maximumRelativeBoundarySourceReconstructionClosureResidual:
        Double?
    public let passed: Bool
}

public struct FormationFlightFieldReplayReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let deviceName: String
    public let referenceReportSHA256: String
    public let configuration: FormationFlightConfiguration
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cycleSteps: Int
    public let runtimeSeconds: Double
    public let coupledLeader: FormationFlyerPowerSummary
    public let coupledFollower: FormationFlyerPowerSummary
    public let overlapVoxelSamples: Int
    public let phaseSamples: [FormationFlightPhaseSample]
    public let capturedLeaderPhases: [Double]
    public let capturedFollowerPhases: [Double]
    public let capturedMechanismProbeSampleCount: Int?
    public let capturedBoundarySourceCensusSampleCount: Int?
    public let gates: FormationFlightFieldReplayGateReport
    public let scientificVerdict: String
}

public struct FormationFlightCollisionDiagnosticGateReport: Codable, Sendable {
    public let finite: Bool
    public let noGeometryOverlap: Bool
    public let ownerForceClosurePassed: Bool
    public let ownerTorqueClosurePassed: Bool
    public let periodicPowerPassed: Bool
    public let populationPositivityPassed: Bool
    public let collisionCorrectionNonIntrusivePassed: Bool
    public let maximumRelativeForceClosureResidual: Double
    public let maximumRelativeTorqueClosureResidual: Double
    public let maximumRelativePeriodicPowerDifference: Double
    public let minimumPopulation: Double
    public let collisionCorrectionActivationFraction: Double
    public let maximumStepCollisionCorrectionActivationFraction: Double
    public let maximumAllowedRelativeClosureResidual: Double
    public let maximumAllowedRelativePeriodicPowerDifference: Double
    public let maximumAllowedCollisionCorrectionActivationFraction: Double
    public let passed: Bool
}

/// A validation-only coupled replay in which the bulk collision operator is
/// the sole solver change. Production formation flight continues to use TRT.
public struct FormationFlightCollisionDiagnosticReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let deviceName: String
    public let collisionOperator: String
    public let configuration: FormationFlightConfiguration
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cycleSteps: Int
    public let runtimeSeconds: Double
    public let coupledLeader: FormationFlyerPowerSummary
    public let coupledFollower: FormationFlyerPowerSummary
    public let overlapVoxelSamples: Int
    public let phaseSamples: [FormationFlightPhaseSample]
    public let capturedLeaderPhases: [Double]
    public let capturedFollowerPhases: [Double]
    public let collisionCorrectionActivationCellSteps: Double
    public let observedCellSteps: Double
    public let gates: FormationFlightCollisionDiagnosticGateReport
    public let scientificVerdict: String
}

public enum FormationFlightValidationError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case unavailable(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid formation-flight request: \(message)"
        case .unavailable(let message):
            return "Formation-flight validation unavailable: \(message)"
        case .failed(let message):
            return "Formation-flight validation failed: \(message)"
        }
    }
}

public enum MetalFormationFlightValidator {
    public static let schemaVersion = 1
    public static let maximumRelativeClosureResidual = 2.0e-4
    public static let maximumRelativePeriodicPowerDifference = 0.20
    public static let maximumRelativeReferenceCoupledHistoryDifference = 1.0e-6
    public static let maximumCollisionCorrectionActivationFraction = 0.05
    public static let maximumBoundarySourceReconstructionClosureResidual =
        2.0e-6

    public static func run(
        configuration: FormationFlightConfiguration = .init(),
        archiveDirectory: URL? = nil,
        fieldCapturePhases: [Double] = []
    ) throws -> FormationFlightReport {
        #if canImport(Metal)
        try validate(configuration)
        guard fieldCapturePhases.allSatisfy(\.isFinite) else {
            throw FormationFlightValidationError.invalidRequest(
                "field-capture phases must be finite"
            )
        }
        guard fieldCapturePhases.isEmpty || archiveDirectory != nil else {
            throw FormationFlightValidationError.invalidRequest(
                "field-capture phases require an archive directory"
            )
        }
        let layout = try makeLayout(configuration)
        let captureTargets = try makeCaptureTargets(
            phases: archiveDirectory == nil
                ? []
                : [0] + fieldCapturePhases,
            configuration: configuration,
            layout: layout
        )
        let start = Date()
        let backend = try MetalBackend(fastMath: false)

        let coupled = try runCase(
            backend: backend,
            configuration: configuration,
            layout: layout,
            activeOwners: 3,
            captureTargets: captureTargets,
            captureMechanismProbes: false
        )
        let isolatedLeader = try runCase(
            backend: backend,
            configuration: configuration,
            layout: layout,
            activeOwners: 1,
            captureTargets: [],
            captureMechanismProbes: false
        )
        let isolatedFollower = try runCase(
            backend: backend,
            configuration: configuration,
            layout: layout,
            activeOwners: 2,
            captureTargets: [],
            captureMechanismProbes: false
        )

        let coupledLeader = summarize(
            flyer: .leader,
            loads: coupled.current.leader,
            phaseOffset: 0,
            layout: layout
        )
        let coupledFollower = summarize(
            flyer: .follower,
            loads: coupled.current.follower,
            phaseOffset: configuration.followerPhaseOffsetCycles,
            layout: layout
        )
        let baselineLeader = summarize(
            flyer: .leader,
            loads: isolatedLeader.current.leader,
            phaseOffset: 0,
            layout: layout
        )
        let baselineFollower = summarize(
            flyer: .follower,
            loads: isolatedFollower.current.follower,
            phaseOffset: configuration.followerPhaseOffsetCycles,
            layout: layout
        )

        let coupledClosure = closureMetrics(
            run: coupled.current,
            layout: layout
        )
        let isolatedLeaderClosure = closureMetrics(
            run: isolatedLeader.current,
            layout: layout
        )
        let isolatedFollowerClosure = closureMetrics(
            run: isolatedFollower.current,
            layout: layout
        )
        let isolatedClosureMaximum = max(
            isolatedLeaderClosure.force,
            isolatedLeaderClosure.torque,
            isolatedFollowerClosure.force,
            isolatedFollowerClosure.torque
        )

        let leaderPeriodic = periodicPowerDifference(
            current: coupled.current.leader,
            previous: coupled.previous.leader,
            phaseOffset: 0,
            layout: layout
        )
        let followerPeriodic = periodicPowerDifference(
            current: coupled.current.follower,
            previous: coupled.previous.follower,
            phaseOffset: configuration.followerPhaseOffsetCycles,
            layout: layout
        )
        let maximumPeriodic = max(leaderPeriodic, followerPeriodic)

        let allSummaries = [
            coupledLeader,
            coupledFollower,
            baselineLeader,
            baselineFollower,
        ]
        let finite = allSummaries.allSatisfy(summaryIsFinite)
            && coupledClosure.force.isFinite
            && coupledClosure.torque.isFinite
            && isolatedClosureMaximum.isFinite
            && maximumPeriodic.isFinite
        let noOverlap = coupled.overlapVoxelSamples == 0
            && isolatedLeader.overlapVoxelSamples == 0
            && isolatedFollower.overlapVoxelSamples == 0
        let forceClosure = coupledClosure.force
            <= maximumRelativeClosureResidual
        let torqueClosure = coupledClosure.torque
            <= maximumRelativeClosureResidual
        let isolatedClosure = isolatedClosureMaximum
            <= maximumRelativeClosureResidual
        let periodicPassed = maximumPeriodic
            <= maximumRelativePeriodicPowerDifference
        let passed = finite
            && noOverlap
            && forceClosure
            && torqueClosure
            && isolatedClosure
            && periodicPassed

        let leaderChange = relativeChange(
            coupledLeader.meanPositivePowerWatts,
            baselineLeader.meanPositivePowerWatts
        )
        let followerChange = relativeChange(
            coupledFollower.meanPositivePowerWatts,
            baselineFollower.meanPositivePowerWatts
        )
        let coupledSystem = coupledLeader.meanPositivePowerWatts
            + coupledFollower.meanPositivePowerWatts
        let isolatedSystem = baselineLeader.meanPositivePowerWatts
            + baselineFollower.meanPositivePowerWatts
        let systemChange = relativeChange(coupledSystem, isolatedSystem)

        let report = FormationFlightReport(
            schemaVersion: schemaVersion,
            scientificScope: "two prescribed Li-Nabawy hovering wings in one D3Q19 fluid; canonical interaction/accounting result, not yet a quantitative bird-formation claim",
            deviceName: backend.device.name,
            configuration: configuration,
            gridX: layout.grid.x,
            gridY: layout.grid.y,
            gridZ: layout.grid.z,
            cycleSteps: layout.cycleSteps,
            runtimeSeconds: Date().timeIntervalSince(start),
            coupledLeader: coupledLeader,
            coupledFollower: coupledFollower,
            isolatedLeader: baselineLeader,
            isolatedFollower: baselineFollower,
            leaderPositivePowerChangeFraction: leaderChange,
            followerPositivePowerChangeFraction: followerChange,
            followerPositivePowerSavingFraction: -followerChange,
            systemPositivePowerChangeFraction: systemChange,
            overlapVoxelSamples: coupled.overlapVoxelSamples,
            phaseSamples: phaseBinnedSamples(
                leader: coupled.current.leader,
                follower: coupled.current.follower,
                layout: layout,
                followerPhaseOffset: configuration.followerPhaseOffsetCycles
            ),
            gates: FormationFlightGateReport(
                finite: finite,
                noGeometryOverlap: noOverlap,
                ownerForceClosurePassed: forceClosure,
                ownerTorqueClosurePassed: torqueClosure,
                isolatedOwnerClosurePassed: isolatedClosure,
                periodicPowerPassed: periodicPassed,
                maximumRelativeForceClosureResidual: coupledClosure.force,
                maximumRelativeTorqueClosureResidual: coupledClosure.torque,
                maximumIsolatedRelativeClosureResidual:
                    isolatedClosureMaximum,
                maximumAllowedRelativeClosureResidual:
                    maximumRelativeClosureResidual,
                maximumRelativePeriodicPowerDifference: maximumPeriodic,
                maximumAllowedRelativePeriodicPowerDifference:
                    maximumRelativePeriodicPowerDifference,
                passed: passed
            ),
            scientificVerdict: passed
                ? "formation owner accounting, non-overlap, isolated controls, and cycle-repeatability gates passed"
                : "formation result remains diagnostic because one or more accounting, overlap, finiteness, or repeatability gates failed"
        )
        if let archiveDirectory {
            try archive(
                report,
                flowSlices: coupled.flowSlices,
                directory: archiveDirectory
            )
        }
        return report
        #else
        throw FormationFlightValidationError.unavailable(
            "Metal is unavailable on this host"
        )
        #endif
    }

    public static func replayFields(
        configuration: FormationFlightConfiguration,
        referenceReport: FormationFlightReport,
        referenceReportSHA256: String,
        archiveDirectory: URL,
        fieldCapturePhases: [Double],
        captureMechanismProbes: Bool = false,
        captureBoundarySourceCensus: Bool = false
    ) throws -> FormationFlightFieldReplayReport {
        #if canImport(Metal)
        try validate(configuration)
        guard !fieldCapturePhases.isEmpty,
              fieldCapturePhases.allSatisfy(\.isFinite) else {
            throw FormationFlightValidationError.invalidRequest(
                "field replay requires at least one finite capture phase"
            )
        }
        let lowercaseSHA = referenceReportSHA256.lowercased()
        guard lowercaseSHA.count == 64,
              lowercaseSHA.allSatisfy({ $0.isHexDigit }) else {
            throw FormationFlightValidationError.invalidRequest(
                "field replay requires the 64-digit SHA-256 of its reference report"
            )
        }
        guard referenceReport.schemaVersion == schemaVersion,
              referenceReport.gates.passed,
              referenceReport.phaseSamples.count == 100,
              referenceReport.configuration.chordCells
                == configuration.chordCells,
              referenceReport.configuration.cycles == configuration.cycles,
              referenceReport.configuration.followerOffsetChords
                == configuration.followerOffsetChords,
              referenceReport.configuration.followerPhaseOffsetCycles
                == configuration.followerPhaseOffsetCycles else {
            throw FormationFlightValidationError.invalidRequest(
                "field replay reference must be a passed report with the exact requested configuration and 100 phase bins"
            )
        }

        let layout = try makeLayout(configuration)
        guard referenceReport.gridX == layout.grid.x,
              referenceReport.gridY == layout.grid.y,
              referenceReport.gridZ == layout.grid.z,
              referenceReport.cycleSteps == layout.cycleSteps else {
            throw FormationFlightValidationError.invalidRequest(
                "field replay reference grid or cycle length does not match the current solver layout"
            )
        }
        let captureTargets = try makeCaptureTargets(
            phases: [0] + fieldCapturePhases,
            configuration: configuration,
            layout: layout
        )
        let start = Date()
        let backend = try MetalBackend(fastMath: false)
        let coupled = try runCase(
            backend: backend,
            configuration: configuration,
            layout: layout,
            activeOwners: 3,
            captureTargets: captureTargets,
            captureMechanismProbes: captureMechanismProbes,
            captureBoundarySourceCensus: captureBoundarySourceCensus
        )
        let coupledLeader = summarize(
            flyer: .leader,
            loads: coupled.current.leader,
            phaseOffset: 0,
            layout: layout
        )
        let coupledFollower = summarize(
            flyer: .follower,
            loads: coupled.current.follower,
            phaseOffset: configuration.followerPhaseOffsetCycles,
            layout: layout
        )
        let phaseSamples = phaseBinnedSamples(
            leader: coupled.current.leader,
            follower: coupled.current.follower,
            layout: layout,
            followerPhaseOffset: configuration.followerPhaseOffsetCycles
        )
        let closure = closureMetrics(run: coupled.current, layout: layout)
        let maximumPeriodic = max(
            periodicPowerDifference(
                current: coupled.current.leader,
                previous: coupled.previous.leader,
                phaseOffset: 0,
                layout: layout
            ),
            periodicPowerDifference(
                current: coupled.current.follower,
                previous: coupled.previous.follower,
                phaseOffset: configuration.followerPhaseOffsetCycles,
                layout: layout
            )
        )
        let referenceDifference = relativeReferenceDifference(
            leader: coupledLeader,
            follower: coupledFollower,
            phaseSamples: phaseSamples,
            reference: referenceReport
        )
        let mechanismReport = captureMechanismProbes
            ? mechanismProbeReport(
                rawSamples: coupled.mechanismProbeComponents,
                production: coupled.current,
                configuration: configuration,
                layout: layout
            )
            : nil
        let boundarySourceReport = captureBoundarySourceCensus
            ? boundarySourceCensusReport(
                rawSamples: coupled.boundarySourceCensusSamples,
                configuration: configuration,
                layout: layout
            )
            : nil
        let finite = summaryIsFinite(coupledLeader)
            && summaryIsFinite(coupledFollower)
            && phaseSamples.allSatisfy(phaseSampleIsFinite)
            && closure.force.isFinite
            && closure.torque.isFinite
            && maximumPeriodic.isFinite
            && referenceDifference.isFinite
            && (mechanismReport?.finite ?? true)
            && (boundarySourceReport?.finite ?? true)
        let noOverlap = coupled.overlapVoxelSamples == 0
        let forceClosure = closure.force <= maximumRelativeClosureResidual
        let torqueClosure = closure.torque <= maximumRelativeClosureResidual
        let periodicPassed = maximumPeriodic
            <= maximumRelativePeriodicPowerDifference
        let referencePassed = referenceDifference
            <= maximumRelativeReferenceCoupledHistoryDifference
        let mechanismPassed = mechanismReport?.passed ?? true
        let boundarySourcePassed = boundarySourceReport?.passed ?? true
        let passed = finite && noOverlap && forceClosure && torqueClosure
            && periodicPassed && referencePassed && mechanismPassed
            && boundarySourcePassed
        let leaderPhases = coupled.flowSlices.map(\.phase)
        let followerPhases = leaderPhases.map {
            unitPhase($0 + configuration.followerPhaseOffsetCycles)
        }
        let report = FormationFlightFieldReplayReport(
            schemaVersion: schemaVersion,
            scientificScope: "coupled-only sparse field replay locked to a previously passed complete formation report; diagnostic flow localization, not a new formation-benefit measurement",
            deviceName: backend.device.name,
            referenceReportSHA256: lowercaseSHA,
            configuration: configuration,
            gridX: layout.grid.x,
            gridY: layout.grid.y,
            gridZ: layout.grid.z,
            cycleSteps: layout.cycleSteps,
            runtimeSeconds: Date().timeIntervalSince(start),
            coupledLeader: coupledLeader,
            coupledFollower: coupledFollower,
            overlapVoxelSamples: coupled.overlapVoxelSamples,
            phaseSamples: phaseSamples,
            capturedLeaderPhases: leaderPhases,
            capturedFollowerPhases: followerPhases,
            capturedMechanismProbeSampleCount:
                mechanismReport?.samples.count,
            capturedBoundarySourceCensusSampleCount:
                boundarySourceReport?.samples.count,
            gates: FormationFlightFieldReplayGateReport(
                finite: finite,
                noGeometryOverlap: noOverlap,
                ownerForceClosurePassed: forceClosure,
                ownerTorqueClosurePassed: torqueClosure,
                periodicPowerPassed: periodicPassed,
                referenceCoupledHistoryPassed: referencePassed,
                maximumRelativeForceClosureResidual: closure.force,
                maximumRelativeTorqueClosureResidual: closure.torque,
                maximumRelativePeriodicPowerDifference: maximumPeriodic,
                maximumRelativeReferenceCoupledHistoryDifference:
                    referenceDifference,
                maximumAllowedRelativeClosureResidual:
                    maximumRelativeClosureResidual,
                maximumAllowedRelativePeriodicPowerDifference:
                    maximumRelativePeriodicPowerDifference,
                maximumAllowedRelativeReferenceCoupledHistoryDifference:
                    maximumRelativeReferenceCoupledHistoryDifference,
                mechanismProbePassed: mechanismReport?.passed,
                maximumRelativeMechanismForceClosureResidual:
                    mechanismReport?.maximumRelativeForceClosureResidual,
                maximumRelativeMechanismTorqueClosureResidual:
                    mechanismReport?.maximumRelativeTorqueClosureResidual,
                maximumRelativeMechanismPowerClosureResidual:
                    mechanismReport?.maximumRelativePowerClosureResidual,
                boundarySourceCensusPassed: boundarySourceReport?.passed,
                maximumRelativeBoundarySourceReconstructionClosureResidual:
                    boundarySourceReport?
                        .maximumRelativeReconstructionClosureResidual,
                passed: passed
            ),
            scientificVerdict: passed
                ? "coupled replay reproduces the archived load history and passes unchanged overlap, owner-closure, and repeatability gates; captured fields are diagnostic only"
                : "field replay is rejected because it failed reference reproduction or an unchanged solver gate"
        )
        try archiveFieldReplay(
            report,
            flowSlices: coupled.flowSlices,
            mechanismProbeReport: mechanismReport,
            boundarySourceCensusReport: boundarySourceReport,
            directory: archiveDirectory
        )
        return report
        #else
        throw FormationFlightValidationError.unavailable(
            "Metal is unavailable on this host"
        )
        #endif
    }

    public static func runCollisionDiagnostic(
        configuration: FormationFlightConfiguration,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator,
        archiveDirectory: URL,
        fieldCapturePhases: [Double]
    ) throws -> FormationFlightCollisionDiagnosticReport {
        #if canImport(Metal)
        try validate(configuration)
        guard collisionOperator != .productionTRT else {
            throw FormationFlightValidationError.invalidRequest(
                "collision diagnostic requires a non-production candidate; the locked TRT archive is the control"
            )
        }
        guard !fieldCapturePhases.isEmpty,
              fieldCapturePhases.allSatisfy(\.isFinite) else {
            throw FormationFlightValidationError.invalidRequest(
                "collision diagnostic requires at least one finite capture phase"
            )
        }
        let layout = try makeLayout(configuration)
        let captureTargets = try makeCaptureTargets(
            phases: [0] + fieldCapturePhases,
            configuration: configuration,
            layout: layout
        )
        let start = Date()
        let backend = try MetalBackend(fastMath: false)
        let coupled = try runCase(
            backend: backend,
            configuration: configuration,
            layout: layout,
            activeOwners: 3,
            captureTargets: captureTargets,
            captureMechanismProbes: false,
            collisionOperator: collisionOperator,
            captureCollisionDiagnostics: true
        )
        guard let collision = coupled.collisionDiagnostics else {
            throw FormationFlightValidationError.failed(
                "collision diagnostic history was not captured"
            )
        }
        let leader = summarize(
            flyer: .leader,
            loads: coupled.current.leader,
            phaseOffset: 0,
            layout: layout
        )
        let follower = summarize(
            flyer: .follower,
            loads: coupled.current.follower,
            phaseOffset: configuration.followerPhaseOffsetCycles,
            layout: layout
        )
        let phaseSamples = phaseBinnedSamples(
            leader: coupled.current.leader,
            follower: coupled.current.follower,
            layout: layout,
            followerPhaseOffset: configuration.followerPhaseOffsetCycles
        )
        let closure = closureMetrics(run: coupled.current, layout: layout)
        let maximumPeriodic = max(
            periodicPowerDifference(
                current: coupled.current.leader,
                previous: coupled.previous.leader,
                phaseOffset: 0,
                layout: layout
            ),
            periodicPowerDifference(
                current: coupled.current.follower,
                previous: coupled.previous.follower,
                phaseOffset: configuration.followerPhaseOffsetCycles,
                layout: layout
            )
        )
        let activationFraction = collision.observedCellSteps > 0
            ? collision.activationCellSteps / collision.observedCellSteps
            : .infinity
        let finite = summaryIsFinite(leader)
            && summaryIsFinite(follower)
            && phaseSamples.allSatisfy(phaseSampleIsFinite)
            && closure.force.isFinite
            && closure.torque.isFinite
            && maximumPeriodic.isFinite
            && collision.allFinite
            && collision.minimumPopulation.isFinite
            && activationFraction.isFinite
            && collision.maximumStepActivationFraction.isFinite
        let noOverlap = coupled.overlapVoxelSamples == 0
        let forceClosure = closure.force <= maximumRelativeClosureResidual
        let torqueClosure = closure.torque <= maximumRelativeClosureResidual
        let periodic = maximumPeriodic
            <= maximumRelativePeriodicPowerDifference
        let positive = collision.minimumPopulation > 0
        let nonIntrusive = activationFraction
            <= maximumCollisionCorrectionActivationFraction
        let passed = finite && noOverlap && forceClosure && torqueClosure
            && periodic && positive && nonIntrusive
        let leaderPhases = coupled.flowSlices.map(\.phase)
        let report = FormationFlightCollisionDiagnosticReport(
            schemaVersion: schemaVersion,
            scientificScope: "diagnostic-only coupled formation replay with geometry, kinematics, boundary treatment, load estimator, grid, and gates fixed while changing only the bulk collision operator; not a formation-benefit measurement or production-operator promotion",
            deviceName: backend.device.name,
            collisionOperator: collisionOperator.rawValue,
            configuration: configuration,
            gridX: layout.grid.x,
            gridY: layout.grid.y,
            gridZ: layout.grid.z,
            cycleSteps: layout.cycleSteps,
            runtimeSeconds: Date().timeIntervalSince(start),
            coupledLeader: leader,
            coupledFollower: follower,
            overlapVoxelSamples: coupled.overlapVoxelSamples,
            phaseSamples: phaseSamples,
            capturedLeaderPhases: leaderPhases,
            capturedFollowerPhases: leaderPhases.map {
                unitPhase($0 + configuration.followerPhaseOffsetCycles)
            },
            collisionCorrectionActivationCellSteps:
                collision.activationCellSteps,
            observedCellSteps: collision.observedCellSteps,
            gates: FormationFlightCollisionDiagnosticGateReport(
                finite: finite,
                noGeometryOverlap: noOverlap,
                ownerForceClosurePassed: forceClosure,
                ownerTorqueClosurePassed: torqueClosure,
                periodicPowerPassed: periodic,
                populationPositivityPassed: positive,
                collisionCorrectionNonIntrusivePassed: nonIntrusive,
                maximumRelativeForceClosureResidual: closure.force,
                maximumRelativeTorqueClosureResidual: closure.torque,
                maximumRelativePeriodicPowerDifference: maximumPeriodic,
                minimumPopulation: collision.minimumPopulation,
                collisionCorrectionActivationFraction: activationFraction,
                maximumStepCollisionCorrectionActivationFraction:
                    collision.maximumStepActivationFraction,
                maximumAllowedRelativeClosureResidual:
                    maximumRelativeClosureResidual,
                maximumAllowedRelativePeriodicPowerDifference:
                    maximumRelativePeriodicPowerDifference,
                maximumAllowedCollisionCorrectionActivationFraction:
                    maximumCollisionCorrectionActivationFraction,
                passed: passed
            ),
            scientificVerdict: passed
                ? "the collision candidate completed the coupled formation replay with positive populations and all unchanged numerical gates; model selection still requires the preregistered c16-to-locked-c20 discriminator"
                : "the collision candidate is rejected because positivity, correction intrusion, or an unchanged coupled-formation gate failed"
        )
        try archiveCollisionDiagnostic(
            report,
            flowSlices: coupled.flowSlices,
            directory: archiveDirectory
        )
        return report
        #else
        throw FormationFlightValidationError.unavailable(
            "Metal is unavailable on this host"
        )
        #endif
    }

    private static func validate(
        _ configuration: FormationFlightConfiguration
    ) throws {
        guard configuration.chordCells >= 8 else {
            throw FormationFlightValidationError.invalidRequest(
                "chordCells must be at least 8; the Metal device working-set check determines the feasible maximum"
            )
        }
        guard configuration.cycles >= 1 else {
            throw FormationFlightValidationError.invalidRequest(
                "cycles must be positive"
            )
        }
        let values = [
            configuration.followerOffsetChords.x,
            configuration.followerOffsetChords.y,
            configuration.followerOffsetChords.z,
            configuration.followerPhaseOffsetCycles,
        ]
        guard values.allSatisfy(\.isFinite) else {
            throw FormationFlightValidationError.invalidRequest(
                "offset and phase must be finite"
            )
        }
        guard vectorNorm(configuration.followerOffsetChords) >= 1.5 else {
            throw FormationFlightValidationError.invalidRequest(
                "follower roots must be separated by at least 1.5 chords"
            )
        }
    }

    private static func archive(
        _ report: FormationFlightReport,
        flowSlices: [FormationFlightFlowSlice],
        directory: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        try data.write(
            to: directory.appendingPathComponent(
                "formation-flight-report.json"
            ),
            options: .atomic
        )
        try archiveFlowSlices(
            flowSlices,
            followerPhaseOffsetCycles:
                report.configuration.followerPhaseOffsetCycles,
            directory: directory,
            encoder: encoder
        )
    }

    private static func archiveFieldReplay(
        _ report: FormationFlightFieldReplayReport,
        flowSlices: [FormationFlightFlowSlice],
        mechanismProbeReport: FormationFlightMechanismProbeReport?,
        boundarySourceCensusReport:
            FormationFlightBoundarySourceCensusReport?,
        directory: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: directory.appendingPathComponent(
                "formation-flight-field-replay-report.json"
            ),
            options: .atomic
        )
        if let mechanismProbeReport {
            try encoder.encode(mechanismProbeReport).write(
                to: directory.appendingPathComponent(
                    "formation-flight-mechanism-probes.json"
                ),
                options: .atomic
            )
        }
        if let boundarySourceCensusReport {
            try encoder.encode(boundarySourceCensusReport).write(
                to: directory.appendingPathComponent(
                    "formation-flight-boundary-source-census.json"
                ),
                options: .atomic
            )
        }
        try archiveFlowSlices(
            flowSlices,
            followerPhaseOffsetCycles:
                report.configuration.followerPhaseOffsetCycles,
            directory: directory,
            encoder: encoder
        )
    }

    private static func archiveCollisionDiagnostic(
        _ report: FormationFlightCollisionDiagnosticReport,
        flowSlices: [FormationFlightFlowSlice],
        directory: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: directory.appendingPathComponent(
                "formation-flight-collision-diagnostic-report.json"
            ),
            options: .atomic
        )
        try archiveFlowSlices(
            flowSlices,
            followerPhaseOffsetCycles:
                report.configuration.followerPhaseOffsetCycles,
            directory: directory,
            encoder: encoder
        )
    }

    private static func archiveFlowSlices(
        _ flowSlices: [FormationFlightFlowSlice],
        followerPhaseOffsetCycles: Double,
        directory: URL,
        encoder: JSONEncoder
    ) throws {
        if let finalSlice = flowSlices.first(where: { $0.phase == 0 }) {
            let sliceData = try encoder.encode(finalSlice)
            try sliceData.write(
                to: directory.appendingPathComponent(
                    "formation-flight-flow-slice.json"
                ),
                options: .atomic
            )
        }
        guard !flowSlices.isEmpty else { return }
        let sliceDirectory = directory.appendingPathComponent(
            "formation-flight-flow-slices",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sliceDirectory,
            withIntermediateDirectories: true
        )
        let entries = try flowSlices.map { slice in
            let phaseCode = Int((slice.phase * 1_000_000).rounded())
            let file = String(format: "phase-%06d.json", phaseCode)
            try encoder.encode(slice).write(
                to: sliceDirectory.appendingPathComponent(file),
                options: .atomic
            )
            return FormationFlightFlowSliceIndexEntry(
                leaderPhase: slice.phase,
                followerPhase: unitPhase(
                    slice.phase
                        + followerPhaseOffsetCycles
                ),
                file: file
            )
        }
        let index = FormationFlightFlowSliceIndex(
            schemaVersion: 1,
            plane: "y",
            entries: entries
        )
        try encoder.encode(index).write(
            to: sliceDirectory.appendingPathComponent("index.json"),
            options: .atomic
        )
    }
}

#if canImport(Metal)
private struct FormationLayout {
    let grid: GridSize
    let chordCells: Int
    let cycleSteps: Int
    let leaderRoot: SIMD3<Float>
    let followerRoot: SIMD3<Float>
    let scaling: LatticeScaling
}

private struct FormationCycleLoads {
    let total: [ForceTorque]
    let leader: [ForceTorque]
    let follower: [ForceTorque]
}

private struct FormationRawRun {
    let previous: FormationCycleLoads
    let current: FormationCycleLoads
    let overlapVoxelSamples: Int
    let flowSlices: [FormationFlightFlowSlice]
    let mechanismProbeComponents: [FormationRawMechanismProbeSample]
    let collisionDiagnostics: FormationRawCollisionDiagnostics?
    let boundarySourceCensusSamples: [FormationRawBoundarySourceCensusSample]
}

private struct FormationRawCollisionDiagnostics {
    let minimumPopulation: Double
    let activationCellSteps: Double
    let observedCellSteps: Double
    let maximumStepActivationFraction: Double
    let allFinite: Bool
}

private struct FormationCaptureTarget {
    let phase: Double
    let absoluteStep: Int
    let slot: Int
}

private struct FormationRawMechanismProbeSample {
    let target: FormationCaptureTarget
    let flyer: FormationFlyerID
    let components: [ForceTorque]
}

private struct FormationRawBoundarySourceCensusSample {
    let target: FormationCaptureTarget
    let flyer: FormationFlyerID
    let directions: [GPUFormationBoundarySourceCensus]
}

private extension MetalFormationFlightValidator {
    static func makeCaptureTargets(
        phases: [Double],
        configuration: FormationFlightConfiguration,
        layout: FormationLayout
    ) throws -> [FormationCaptureTarget] {
        let finalCycleStart = (configuration.cycles - 1)
            * layout.cycleSteps
        var stepPhases: [Int: Double] = [:]
        for requestedPhase in phases {
            let phase = unitPhase(requestedPhase)
            let stepWithinCycle: Int
            if phase == 0 {
                stepWithinCycle = layout.cycleSteps
            } else {
                stepWithinCycle = min(
                    layout.cycleSteps,
                    max(1, Int((phase * Double(layout.cycleSteps)).rounded()))
                )
            }
            let absoluteStep = finalCycleStart + stepWithinCycle
            let actualPhase = stepWithinCycle == layout.cycleSteps
                ? 0
                : Double(stepWithinCycle) / Double(layout.cycleSteps)
            stepPhases[absoluteStep] = actualPhase
        }
        return stepPhases.sorted { $0.key < $1.key }
            .enumerated()
            .map { slot, value in
                FormationCaptureTarget(
                    phase: value.value,
                    absoluteStep: value.key,
                    slot: slot
                )
            }
    }

    static func makeLayout(
        _ request: FormationFlightConfiguration
    ) throws -> FormationLayout {
        let chord = request.chordCells
        func dimension(base: Double, offset: Double) throws -> Int {
            let chordDimension = ceil(base + abs(offset))
            let cells = chordDimension * Double(chord)
            guard chordDimension.isFinite,
                  cells.isFinite,
                  cells >= 16,
                  cells <= Double(Int.max) else {
                throw FormationFlightValidationError.invalidRequest(
                    "formation offset and resolution produce an unrepresentable grid dimension"
                )
            }
            return Int(cells)
        }
        let grid = try GridSize(
            x: try dimension(base: 10, offset: request.followerOffsetChords.x),
            y: try dimension(base: 10, offset: request.followerOffsetChords.y),
            z: try dimension(base: 10, offset: request.followerOffsetChords.z)
        )
        let cycleStepsValue = (
            MetalFlappingWingValidator.cycleTravelPerChord * Double(chord)
                / MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
        ).rounded()
        guard cycleStepsValue.isFinite,
              cycleStepsValue >= 1,
              cycleStepsValue <= Double(UInt32.max) else {
            throw FormationFlightValidationError.invalidRequest(
                "resolution produces an unrepresentable wingbeat step count"
            )
        }
        let cycleSteps = Int(cycleStepsValue)
        let (totalSteps, totalOverflow) = request.cycles
            .multipliedReportingOverflow(by: cycleSteps)
        let (phaseSafeSteps, phaseOverflow) = totalSteps
            .addingReportingOverflow(cycleSteps)
        guard !totalOverflow,
              !phaseOverflow,
              phaseSafeSteps <= 1 << 24 else {
            throw FormationFlightValidationError.invalidRequest(
                "cycles and resolution exceed exact Float timestep representation; split the study or use a wider GPU time representation"
            )
        }
        let midpoint = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.5 * Float(grid.z)
        )
        let offset = SIMD3<Float>(request.followerOffsetChords)
            * Float(chord)
        let scaling = try LatticeScaling(
            characteristicLengthMeters: Float(chord),
            characteristicLengthCells: chord,
            referenceSpeedMetersPerSecond: Float(
                MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
            ),
            targetReynoldsNumber: Float(
                MetalFlappingWingValidator.reynoldsNumber
            ),
            physicalAirDensity: 1,
            latticeReferenceSpeed: Float(
                MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
            )
        )
        return FormationLayout(
            grid: grid,
            chordCells: chord,
            cycleSteps: cycleSteps,
            leaderRoot: midpoint - 0.5 * offset,
            followerRoot: midpoint + 0.5 * offset,
            scaling: scaling
        )
    }

    static func runCase(
        backend: MetalBackend,
        configuration: FormationFlightConfiguration,
        layout: FormationLayout,
        activeOwners: UInt32,
        captureTargets: [FormationCaptureTarget],
        captureMechanismProbes: Bool,
        captureBoundarySourceCensus: Bool = false,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator =
            .productionTRT,
        captureCollisionDiagnostics: Bool = false
    ) throws -> FormationRawRun {
        let simulation = try MetalFormationFlightSimulation(
            backend: backend,
            request: configuration,
            layout: layout,
            activeOwners: activeOwners,
            captureTargets: captureTargets,
            captureMechanismProbes: captureMechanismProbes,
            captureBoundarySourceCensus: captureBoundarySourceCensus,
            collisionOperator: collisionOperator,
            captureCollisionDiagnostics: captureCollisionDiagnostics
        )
        if configuration.cycles > 2 {
            try simulation.advance(
                to: (configuration.cycles - 2) * layout.cycleSteps,
                recordLoads: false
            )
        }
        try simulation.advance(
            to: max(1, configuration.cycles - 1) * layout.cycleSteps,
            recordLoads: true
        )
        let previous = simulation.copyRecordedLoads()
        if configuration.cycles > 1 {
            try simulation.advance(
                to: configuration.cycles * layout.cycleSteps,
                recordLoads: true
            )
        }
        return FormationRawRun(
            previous: previous,
            current: simulation.copyRecordedLoads(),
            overlapVoxelSamples: simulation.overlapVoxelSamples,
            flowSlices: try simulation.copyFlowSlices(),
            mechanismProbeComponents:
                simulation.copyMechanismProbeComponents(),
            collisionDiagnostics: simulation.copyCollisionDiagnostics(),
            boundarySourceCensusSamples:
                simulation.copyBoundarySourceCensusSamples()
        )
    }

    static func mechanismProbeReport(
        rawSamples: [FormationRawMechanismProbeSample],
        production: FormationCycleLoads,
        configuration: FormationFlightConfiguration,
        layout: FormationLayout
    ) -> FormationFlightMechanismProbeReport {
        func add(_ values: [ForceTorque]) -> ForceTorque {
            ForceTorque(
                forceNewtons: values.reduce(.zero) {
                    $0 + $1.forceNewtons
                },
                torqueNewtonMeters: values.reduce(.zero) {
                    $0 + $1.torqueNewtonMeters
                }
            )
        }
        func finite(_ load: ForceTorque) -> Bool {
            let values = [
                load.forceNewtons.x,
                load.forceNewtons.y,
                load.forceNewtons.z,
                load.torqueNewtonMeters.x,
                load.torqueNewtonMeters.y,
                load.torqueNewtonMeters.z,
            ]
            return values.allSatisfy(\.isFinite)
        }
        func component(
            load: ForceTorque,
            phase: Double
        ) -> FormationFlightMechanismComponentSample {
            let omega = angularVelocity(phase: phase, layout: layout)
            let torque = SIMD3<Double>(
                Double(load.torqueNewtonMeters.x),
                Double(load.torqueNewtonMeters.y),
                Double(load.torqueNewtonMeters.z)
            )
            return FormationFlightMechanismComponentSample(
                load: load,
                actuatorPowerWatts: scalarDot(-torque, omega)
            )
        }

        var maximumForce = 0.0
        var maximumTorque = 0.0
        var maximumPower = 0.0
        var allFinite = true
        let samples = rawSamples.map { raw in
            precondition(raw.components.count == 5)
            let leaderPhase = raw.target.phase
            let followerPhase = unitPhase(
                leaderPhase + configuration.followerPhaseOffsetCycles
            )
            let phase = raw.flyer == .leader
                ? leaderPhase
                : followerPhase
            let sampleIndex = (raw.target.absoluteStep - 1)
                % layout.cycleSteps
            let productionLoad = raw.flyer == .leader
                ? production.leader[sampleIndex]
                : production.follower[sampleIndex]
            let reconstructedLoad = add(raw.components)
            let productionSample = component(
                load: productionLoad,
                phase: phase
            )
            let reconstructedSample = component(
                load: reconstructedLoad,
                phase: phase
            )
            let componentSamples = raw.components.map {
                component(load: $0, phase: phase)
            }
            let forceResidual = vectorNorm(
                reconstructedLoad.forceNewtons
                    - productionLoad.forceNewtons
            )
            let forceScale = max(
                vectorNorm(productionLoad.forceNewtons),
                raw.components.reduce(0) {
                    $0 + vectorNorm($1.forceNewtons)
                },
                1.0e-12
            )
            let torqueResidual = vectorNorm(
                reconstructedLoad.torqueNewtonMeters
                    - productionLoad.torqueNewtonMeters
            )
            let torqueScale = max(
                vectorNorm(productionLoad.torqueNewtonMeters),
                raw.components.reduce(0) {
                    $0 + vectorNorm($1.torqueNewtonMeters)
                },
                1.0e-12
            )
            let powerResidual = abs(
                reconstructedSample.actuatorPowerWatts
                    - productionSample.actuatorPowerWatts
            )
            let powerScale = max(
                abs(productionSample.actuatorPowerWatts),
                componentSamples.reduce(0) {
                    $0 + abs($1.actuatorPowerWatts)
                },
                1.0e-12
            )
            let relativeForce = Double(forceResidual) / Double(forceScale)
            let relativeTorque = Double(torqueResidual)
                / Double(torqueScale)
            let relativePower = powerResidual / powerScale
            maximumForce = max(maximumForce, relativeForce)
            maximumTorque = max(maximumTorque, relativeTorque)
            maximumPower = max(maximumPower, relativePower)
            allFinite = allFinite
                && finite(productionLoad)
                && finite(reconstructedLoad)
                && raw.components.allSatisfy(finite)
                && productionSample.actuatorPowerWatts.isFinite
                && reconstructedSample.actuatorPowerWatts.isFinite
                && componentSamples.allSatisfy {
                    $0.actuatorPowerWatts.isFinite
                }
                && relativeForce.isFinite
                && relativeTorque.isFinite
                && relativePower.isFinite
            return FormationFlightMechanismProbeSample(
                leaderPhase: leaderPhase,
                followerPhase: followerPhase,
                flyer: raw.flyer,
                production: productionSample,
                reconstructed: reconstructedSample,
                components: FormationFlightMechanismComponentBreakdown(
                    reflectedPopulation: componentSamples[0],
                    interpolationAuxiliary: componentSamples[1],
                    movingWall: componentSamples[2],
                    coverImpulse: componentSamples[3],
                    uncoverImpulse: componentSamples[4]
                ),
                relativeForceClosureResidual: relativeForce,
                relativeTorqueClosureResidual: relativeTorque,
                relativePowerClosureResidual: relativePower
            )
        }
        let closurePassed = maximumForce <= maximumRelativeClosureResidual
            && maximumTorque <= maximumRelativeClosureResidual
            && maximumPower <= maximumRelativeClosureResidual
        let passed = !samples.isEmpty && allFinite && closurePassed
        return FormationFlightMechanismProbeReport(
            schemaVersion: 1,
            scientificScope: "read-only decomposition of the exact production formation-owner load at preregistered phases; numerical-mechanism localization, not a new biological or formation-benefit claim",
            componentOrder: [
                "reflectedPopulation",
                "interpolationAuxiliary",
                "movingWall",
                "coverImpulse",
                "uncoverImpulse",
            ],
            samples: samples,
            maximumRelativeForceClosureResidual: maximumForce,
            maximumRelativeTorqueClosureResidual: maximumTorque,
            maximumRelativePowerClosureResidual: maximumPower,
            maximumAllowedRelativeClosureResidual:
                maximumRelativeClosureResidual,
            finite: allFinite,
            closurePassed: closurePassed,
            passed: passed,
            scientificVerdict: passed
                ? "all five causal terms close linearly to the unchanged production owner load"
                : "mechanism attribution rejected because component closure or finiteness failed"
        )
    }

    static func boundarySourceCensusReport(
        rawSamples: [FormationRawBoundarySourceCensusSample],
        configuration: FormationFlightConfiguration,
        layout: FormationLayout
    ) -> FormationFlightBoundarySourceCensusReport {
        func cross(
            _ a: SIMD3<Double>,
            _ b: SIMD3<Double>
        ) -> SIMD3<Double> {
            SIMD3<Double>(
                a.y * b.z - a.z * b.y,
                a.z * b.x - a.x * b.z,
                a.x * b.y - a.y * b.x
            )
        }
        let samples: [FormationFlightBoundarySourceCensusSample] = rawSamples.map { raw in
            let flyerPhase = unitPhase(
                raw.target.phase
                    + (raw.flyer == .follower
                        ? configuration.followerPhaseOffsetCycles : 0)
            )
            let state = MetalFlappingWingValidator.kinematicState(
                phase: flyerPhase
            )
            let span = SIMD3<Double>(
                cos(state.strokeAngleRadians),
                sin(state.strokeAngleRadians),
                0
            )
            let tangent = cross(SIMD3<Double>(0, 0, 1), span)
            let pitch = -state.pitchAngleRadians
            let chord = tangent * cos(pitch)
                + cross(span, tangent) * sin(pitch)
            let normal = cross(span, chord)
            let directions = raw.directions.enumerated().map { index, value in
                FormationFlightBoundarySourceDirectionSample(
                    directionIndex: index,
                    direction: D3Q19.directions[index],
                    linkCount: Int(value.populations.x.rounded()),
                    rawReflectedPopulationSum:
                        Double(value.populations.y),
                    reflectedIncomingPopulationSum:
                        Double(value.populations.z),
                    interpolationAuxiliaryPopulationSum:
                        Double(value.populations.w),
                    movingWallPopulationSum:
                        Double(value.reconstruction.x),
                    reconstructedIncomingPopulationSum:
                        Double(value.reconstruction.y),
                    absoluteIncomingPopulationSum:
                        Double(value.branches.w),
                    squaredIncomingPopulationSum:
                        Double(value.wallKinematics.w),
                    linkFractionSum: Double(value.reconstruction.z),
                    squaredLinkFractionSum:
                        Double(value.reconstruction.w),
                    wallProjectionSum:
                        Double(value.wallKinematics.x),
                    absoluteWallProjectionSum:
                        Double(value.wallKinematics.y),
                    wallSpeedSum: Double(value.wallKinematics.z),
                    nearInterpolationLinkCount:
                        Int(value.branches.x.rounded()),
                    farInterpolationLinkCount:
                        Int(value.branches.y.rounded()),
                    halfwayFallbackLinkCount:
                        Int(value.branches.z.rounded())
                )
            }
            let numerator = sqrt(directions.reduce(0.0) { sum, value in
                let reconstructed = value.reflectedIncomingPopulationSum
                    + value.interpolationAuxiliaryPopulationSum
                    + value.movingWallPopulationSum
                let difference = value.reconstructedIncomingPopulationSum
                    - reconstructed
                return sum + difference * difference
            })
            let denominator = max(
                sqrt(directions.reduce(0.0) {
                    $0 + $1.reconstructedIncomingPopulationSum
                        * $1.reconstructedIncomingPopulationSum
                }),
                1.0e-12
            )
            let branchClosure = directions.allSatisfy {
                $0.linkCount == $0.nearInterpolationLinkCount
                    + $0.farInterpolationLinkCount
                    + $0.halfwayFallbackLinkCount
            }
            return FormationFlightBoundarySourceCensusSample(
                leaderPhase: raw.target.phase,
                followerPhase: unitPhase(
                    raw.target.phase
                        + configuration.followerPhaseOffsetCycles
                ),
                flyer: raw.flyer,
                wingChordAxis: chord,
                wingSpanAxis: span,
                wingNormalAxis: normal,
                totalBoundaryLinkCount: directions.reduce(0) {
                    $0 + $1.linkCount
                },
                relativeReconstructionClosureResidual:
                    numerator / denominator,
                branchCountClosurePassed: branchClosure,
                directions: directions
            )
        }
        let maximumClosure = samples.map {
            $0.relativeReconstructionClosureResidual
        }.max() ?? .infinity
        let finite = samples.allSatisfy { sample in
            let vectors: [SIMD3<Double>] = [
                sample.wingChordAxis,
                sample.wingSpanAxis,
                sample.wingNormalAxis,
            ]
            let axes = vectors.flatMap { [$0.x, $0.y, $0.z] }
            return sample.totalBoundaryLinkCount > 0
                && sample.relativeReconstructionClosureResidual.isFinite
                && axes.allSatisfy(\.isFinite)
                && sample.directions.allSatisfy { direction in
                    [
                        direction.rawReflectedPopulationSum,
                        direction.reflectedIncomingPopulationSum,
                        direction.interpolationAuxiliaryPopulationSum,
                        direction.movingWallPopulationSum,
                        direction.reconstructedIncomingPopulationSum,
                        direction.absoluteIncomingPopulationSum,
                        direction.squaredIncomingPopulationSum,
                        direction.linkFractionSum,
                        direction.squaredLinkFractionSum,
                        direction.wallProjectionSum,
                        direction.absoluteWallProjectionSum,
                        direction.wallSpeedSum,
                    ].allSatisfy(\.isFinite)
                }
        }
        let reconstructionPassed = maximumClosure
            <= maximumBoundarySourceReconstructionClosureResidual
        let branchPassed = samples.allSatisfy {
            $0.branchCountClosurePassed
        }
        let passed = finite && reconstructionPassed && branchPassed
        return FormationFlightBoundarySourceCensusReport(
            schemaVersion: schemaVersion,
            scientificScope: "read-only owner- and D3Q19-direction-resolved census of the exact interpolated formation boundary reconstruction; diagnostic source attribution, not a force or formation-benefit measurement",
            samples: samples,
            maximumRelativeReconstructionClosureResidual: maximumClosure,
            maximumAllowedRelativeReconstructionClosureResidual:
                maximumBoundarySourceReconstructionClosureResidual,
            finite: finite,
            reconstructionClosurePassed: reconstructionPassed,
            branchCountClosurePassed: branchPassed,
            passed: passed,
            scientificVerdict: passed
                ? "every direction closes reconstructed incoming population to reflected, interpolation, and moving-wall source terms with exact branch accounting"
                : "boundary source census is rejected because reconstruction, branch accounting, support, or finiteness failed"
        )
    }

    static func angularVelocity(
        phase: Double,
        layout: FormationLayout
    ) -> SIMD3<Double> {
        let state = MetalFlappingWingValidator.kinematicState(phase: phase)
        let span = SIMD3<Double>(
            cos(state.strokeAngleRadians),
            sin(state.strokeAngleRadians),
            0
        )
        let lattice = SIMD3<Double>(0, 0, 1)
                * (state.strokeRateRadiansPerCycle
                    / Double(layout.cycleSteps))
            - span * (state.pitchRateRadiansPerCycle
                / Double(layout.cycleSteps))
        return lattice / Double(layout.scaling.timeStepSeconds)
    }

    static func powers(
        loads: [ForceTorque],
        phaseOffset: Double,
        layout: FormationLayout
    ) -> [Double] {
        loads.indices.map { index in
            let phase = (Double(index) + 1) / Double(layout.cycleSteps)
                + phaseOffset
            let omega = angularVelocity(phase: phase, layout: layout)
            let torque = SIMD3<Double>(
                Double(loads[index].torqueNewtonMeters.x),
                Double(loads[index].torqueNewtonMeters.y),
                Double(loads[index].torqueNewtonMeters.z)
            )
            return scalarDot(-torque, omega)
        }
    }

    static func summarize(
        flyer: FormationFlyerID,
        loads: [ForceTorque],
        phaseOffset: Double,
        layout: FormationLayout
    ) -> FormationFlyerPowerSummary {
        let power = powers(
            loads: loads,
            phaseOffset: phaseOffset,
            layout: layout
        )
        let coefficients = loads.indices.map { index in
            let phase = (Double(index) + 1) / Double(layout.cycleSteps)
                + phaseOffset
            return coefficientSample(
                phase: phase - floor(phase),
                load: loads[index],
                layout: layout
            )
        }
        return FormationFlyerPowerSummary(
            flyer: flyer,
            meanSignedPowerWatts: average(power),
            meanPositivePowerWatts: average(power.map { max($0, 0) }),
            rmsPowerWatts: sqrt(average(power.map { $0 * $0 })),
            maximumPositivePowerWatts: power.max() ?? 0,
            meanLiftCoefficient: average(
                coefficients.map(\.liftCoefficient)
            ),
            meanDragCoefficient: average(
                coefficients.map(\.dragCoefficient)
            )
        )
    }

    static func closureMetrics(
        run: FormationCycleLoads,
        layout: FormationLayout
    ) -> (force: Double, torque: Double) {
        var maximumForceResidual: Float = 0
        var maximumTorqueResidual: Float = 0
        var forceScale: Float = 1.0e-12
        var torqueScale: Float = 1.0e-12
        for index in run.total.indices {
            let total = run.total[index]
            let leader = run.leader[index]
            let follower = run.follower[index]
            let ownerForce = leader.forceNewtons + follower.forceNewtons
            let forceResidual = ownerForce - total.forceNewtons
            let ownerTorque = leader.torqueNewtonMeters
                + cross(layout.leaderRoot, leader.forceNewtons)
                + follower.torqueNewtonMeters
                + cross(layout.followerRoot, follower.forceNewtons)
            let torqueResidual = ownerTorque - total.torqueNewtonMeters
            forceScale = max(
                forceScale,
                vectorNorm(total.forceNewtons),
                vectorNorm(leader.forceNewtons)
                    + vectorNorm(follower.forceNewtons),
            )
            torqueScale = max(
                torqueScale,
                vectorNorm(total.torqueNewtonMeters),
                vectorNorm(ownerTorque),
            )
            maximumForceResidual = max(
                maximumForceResidual,
                vectorNorm(forceResidual)
            )
            maximumTorqueResidual = max(
                maximumTorqueResidual,
                vectorNorm(torqueResidual)
            )
        }
        return (
            Double(maximumForceResidual / forceScale),
            Double(maximumTorqueResidual / torqueScale)
        )
    }

    static func periodicPowerDifference(
        current: [ForceTorque],
        previous: [ForceTorque],
        phaseOffset: Double,
        layout: FormationLayout
    ) -> Double {
        let a = powers(
            loads: current,
            phaseOffset: phaseOffset,
            layout: layout
        )
        let b = powers(
            loads: previous,
            phaseOffset: phaseOffset,
            layout: layout
        )
        let numerator = sqrt(average(zip(a, b).map { value in
            let difference = value.0 - value.1
            return difference * difference
        }))
        let denominator = max(
            sqrt(average(a.map { $0 * $0 })),
            sqrt(average(b.map { $0 * $0 })),
            1.0e-12
        )
        return numerator / denominator
    }

    static func phaseBinnedSamples(
        leader: [ForceTorque],
        follower: [ForceTorque],
        layout: FormationLayout,
        followerPhaseOffset: Double
    ) -> [FormationFlightPhaseSample] {
        let leaderPower = powers(
            loads: leader,
            phaseOffset: 0,
            layout: layout
        )
        let followerPower = powers(
            loads: follower,
            phaseOffset: followerPhaseOffset,
            layout: layout
        )
        return Array(0..<100).map { bin in
            let lower = bin * layout.cycleSteps / 100
            let upper = max(lower + 1, (bin + 1) * layout.cycleSteps / 100)
            let range = lower..<min(upper, layout.cycleSteps)
            let leaderLoad = meanLoad(leader, range: range)
            let followerLoad = meanLoad(follower, range: range)
            let leaderPhase = (Double(bin) + 0.5) / 100
            let followerPhase = unitPhase(
                leaderPhase + followerPhaseOffset
            )
            let leaderCoefficient = coefficientSample(
                phase: leaderPhase,
                load: leaderLoad,
                layout: layout
            )
            let followerCoefficient = coefficientSample(
                phase: followerPhase,
                load: followerLoad,
                layout: layout
            )
            return FormationFlightPhaseSample(
                leaderPhase: leaderPhase,
                followerPhase: followerPhase,
                leaderLiftCoefficient: leaderCoefficient.liftCoefficient,
                followerLiftCoefficient: followerCoefficient.liftCoefficient,
                leaderDragCoefficient: leaderCoefficient.dragCoefficient,
                followerDragCoefficient: followerCoefficient.dragCoefficient,
                leaderSignedPowerWatts: average(
                    range.map { leaderPower[$0] }
                ),
                followerSignedPowerWatts:
                    average(range.map { followerPower[$0] }),
                leaderForceNewtons: leaderLoad.forceNewtons,
                followerForceNewtons: followerLoad.forceNewtons
            )
        }
    }

    static func meanLoad(
        _ values: [ForceTorque],
        range: Range<Int>
    ) -> ForceTorque {
        let divisor = Float(max(range.count, 1))
        let force = range.reduce(SIMD3<Float>.zero) {
            $0 + values[$1].forceNewtons
        } / divisor
        let torque = range.reduce(SIMD3<Float>.zero) {
            $0 + values[$1].torqueNewtonMeters
        } / divisor
        return ForceTorque(
            forceNewtons: force,
            torqueNewtonMeters: torque
        )
    }

    static func unitPhase(_ value: Double) -> Double {
        value - floor(value)
    }

    static func relativeChange(_ value: Double, _ baseline: Double) -> Double {
        (value - baseline) / max(abs(baseline), 1.0e-12)
    }

    static func summaryIsFinite(_ value: FormationFlyerPowerSummary) -> Bool {
        [
            value.meanSignedPowerWatts,
            value.meanPositivePowerWatts,
            value.rmsPowerWatts,
            value.maximumPositivePowerWatts,
            value.meanLiftCoefficient,
            value.meanDragCoefficient,
        ].allSatisfy(\.isFinite)
    }

    static func phaseSampleIsFinite(
        _ value: FormationFlightPhaseSample
    ) -> Bool {
        [
            value.leaderPhase,
            value.followerPhase,
            value.leaderLiftCoefficient,
            value.followerLiftCoefficient,
            value.leaderDragCoefficient,
            value.followerDragCoefficient,
            value.leaderSignedPowerWatts,
            value.followerSignedPowerWatts,
            Double(value.leaderForceNewtons.x),
            Double(value.leaderForceNewtons.y),
            Double(value.leaderForceNewtons.z),
            Double(value.followerForceNewtons.x),
            Double(value.followerForceNewtons.y),
            Double(value.followerForceNewtons.z),
        ].allSatisfy(\.isFinite)
    }

    static func relativeReferenceDifference(
        leader: FormationFlyerPowerSummary,
        follower: FormationFlyerPowerSummary,
        phaseSamples: [FormationFlightPhaseSample],
        reference: FormationFlightReport
    ) -> Double {
        func summaryValues(_ value: FormationFlyerPowerSummary) -> [Double] {
            [
                value.meanSignedPowerWatts,
                value.meanPositivePowerWatts,
                value.rmsPowerWatts,
                value.maximumPositivePowerWatts,
                value.meanLiftCoefficient,
                value.meanDragCoefficient,
            ]
        }
        func phaseValues(_ values: [FormationFlightPhaseSample]) -> [Double] {
            values.flatMap { value in
                [
                    value.leaderLiftCoefficient,
                    value.followerLiftCoefficient,
                    value.leaderDragCoefficient,
                    value.followerDragCoefficient,
                    value.leaderSignedPowerWatts,
                    value.followerSignedPowerWatts,
                    Double(value.leaderForceNewtons.x),
                    Double(value.leaderForceNewtons.y),
                    Double(value.leaderForceNewtons.z),
                    Double(value.followerForceNewtons.x),
                    Double(value.followerForceNewtons.y),
                    Double(value.followerForceNewtons.z),
                ]
            }
        }
        func relativeRMS(_ values: [Double], _ baseline: [Double]) -> Double {
            guard values.count == baseline.count, !values.isEmpty else {
                return .infinity
            }
            let numerator = sqrt(average(zip(values, baseline).map {
                let difference = $0.0 - $0.1
                return difference * difference
            }))
            let denominator = max(
                sqrt(average(baseline.map { $0 * $0 })),
                1.0e-12
            )
            return numerator / denominator
        }
        return max(
            relativeRMS(summaryValues(leader), summaryValues(reference.coupledLeader)),
            relativeRMS(
                summaryValues(follower),
                summaryValues(reference.coupledFollower)
            ),
            relativeRMS(
                phaseValues(phaseSamples),
                phaseValues(reference.phaseSamples)
            )
        )
    }

    static func average(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    static func scalarDot(
        _ lhs: SIMD3<Double>,
        _ rhs: SIMD3<Double>
    ) -> Double {
        lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z
    }

    static func vectorNorm(_ value: SIMD3<Double>) -> Double {
        sqrt(scalarDot(value, value))
    }

    static func vectorNorm(_ value: SIMD3<Float>) -> Float {
        sqrt(value.x * value.x + value.y * value.y + value.z * value.z)
    }

    static func coefficientSample(
        phase: Double,
        load: ForceTorque,
        layout: FormationLayout
    ) -> (liftCoefficient: Double, dragCoefficient: Double) {
        let state = MetalFlappingWingValidator.kinematicState(phase: phase)
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
        let actualSpeed = MetalFlappingWingValidator.cycleTravelPerChord
            * Double(layout.chordCells) / Double(layout.cycleSteps)
        let denominator = 0.5 * actualSpeed * actualSpeed
            * MetalFlappingWingValidator.aspectRatio
            * Double(layout.chordCells * layout.chordCells)
        let strokeDirection = phase < 0.5 ? -1.0 : 1.0
        return (
            force.z / denominator,
            -strokeDirection * scalarDot(force, tangent) / denominator
        )
    }
}

private final class MetalFormationFlightSimulation {
    private let backend: MetalBackend
    private let request: FormationFlightConfiguration
    private let layout: FormationLayout
    private let configuration: SimulationConfiguration
    private let activeOwners: UInt32
    private let leaderParameters: MTLBuffer
    private let followerParameters: MTLBuffer
    private let leaderPrepared: MTLBuffer
    private let followerPrepared: MTLBuffer
    private let control: MTLBuffer
    private let overlapCounts: MTLBuffer
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidA: MTLBuffer
    private let solidB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let totalHistory: MTLBuffer
    private let leaderHistory: MTLBuffer
    private let followerHistory: MTLBuffer
    private let flowFieldHistory: MTLBuffer?
    private let flowOwnerHistory: MTLBuffer?
    private let mechanismProbeHistory: MTLBuffer?
    private let collisionDiagnosticHistory: MTLBuffer?
    private let boundarySourceReductionA: MTLBuffer?
    private let boundarySourceReductionB: MTLBuffer?
    private let boundarySourceCensusHistory: MTLBuffer?
    private let bodyState: MTLBuffer
    private let preparePipeline: MTLComputePipelineState
    private let geometryPipeline: MTLComputePipelineState
    private let initializePipeline: MTLComputePipelineState
    private let fluidPipeline: MTLComputePipelineState
    private let ownerLoadPipeline: MTLComputePipelineState
    private let mechanismComponentPipeline: MTLComputePipelineState?
    private let boundarySourceCensusPipeline: MTLComputePipelineState?
    private let boundarySourceReductionPipeline: MTLComputePipelineState?
    private let boundarySourceStorePipeline: MTLComputePipelineState?
    private let reductionPipeline: MTLComputePipelineState
    private let storePipeline: MTLComputePipelineState
    private let captureFlowSlicePipeline: MTLComputePipelineState?
    private let partialLoadCount: Int
    private let captureTargets: [FormationCaptureTarget]
    private let captureSlotsByStep: [Int: Int]
    private let boundarySourceCaptureSlots: Set<Int>
    private let captureMechanismProbes: Bool
    private let captureBoundarySourceCensus: Bool
    private let collisionOperator: MetalIndexedBirdSurfaceCollisionOperator
    private let captureCollisionDiagnostics: Bool
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var currentSolid: MTLBuffer
    private var nextSolid: MTLBuffer
    private var stepIndex = 0

    init(
        backend: MetalBackend,
        request: FormationFlightConfiguration,
        layout: FormationLayout,
        activeOwners: UInt32,
        captureTargets: [FormationCaptureTarget],
        captureMechanismProbes: Bool,
        captureBoundarySourceCensus: Bool,
        collisionOperator: MetalIndexedBirdSurfaceCollisionOperator,
        captureCollisionDiagnostics: Bool
    ) throws {
        self.backend = backend
        self.request = request
        self.layout = layout
        self.activeOwners = activeOwners
        self.captureTargets = captureTargets
        self.captureMechanismProbes = captureMechanismProbes
        self.captureBoundarySourceCensus = captureBoundarySourceCensus
        self.collisionOperator = collisionOperator
        self.captureCollisionDiagnostics = captureCollisionDiagnostics
        captureSlotsByStep = Dictionary(
            uniqueKeysWithValues: captureTargets.map {
                ($0.absoluteStep, $0.slot)
            }
        )
        boundarySourceCaptureSlots = Set(
            captureTargets.compactMap {
                abs($0.phase) > 1.0e-12 ? $0.slot : nil
            }
        )
        configuration = try SimulationConfiguration(
            grid: layout.grid,
            domainOriginMeters: .zero,
            scaling: layout.scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: max(4, request.chordCells / 2),
            spongeStrength: 0.04,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )

        func parameters(root: SIMD3<Float>) -> GPUFlappingWingParameters {
            GPUFlappingWingParameters(
                rootAndChord: SIMD4<Float>(root, Float(request.chordCells)),
                geometry: SIMD4<Float>(
                    Float(MetalFlappingWingValidator.aspectRatio)
                        * Float(request.chordCells),
                    0.05 * Float(request.chordCells),
                    Float(MetalFlappingWingValidator.betaShape - 1),
                    Float(MetalFlappingWingValidator.betaNormalization)
                ),
                kinematics0: SIMD4<Float>(
                    Float(layout.cycleSteps),
                    Float(MetalFlappingWingValidator.strokeHalfAmplitudeRadians),
                    Float(MetalFlappingWingValidator.accelerationDuration),
                    Float(MetalFlappingWingValidator.pitchDuration)
                ),
                kinematics1: SIMD4<Float>(
                    45 * .pi / 180,
                    135 * .pi / 180,
                    Float(MetalFlappingWingValidator.maximumStrokeRateRadiansPerCycle),
                    Float(MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed)
                )
            )
        }
        leaderParameters = try backend.makeSharedBuffer(
            value: parameters(root: layout.leaderRoot)
        )
        followerParameters = try backend.makeSharedBuffer(
            value: parameters(root: layout.followerRoot)
        )
        leaderPrepared = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedFlappingWing>.stride
        )
        followerPrepared = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedFlappingWing>.stride
        )
        control = try backend.makeSharedBuffer(
            value: GPUFormationFlightControl(
                activeOwnersAndCycleSteps: SIMD4<UInt32>(
                    activeOwners,
                    UInt32(layout.cycleSteps),
                    0,
                    0
                )
            )
        )
        overlapCounts = try backend.makeSharedBuffer(
            length: layout.cycleSteps * MemoryLayout<UInt32>.stride
        )

        preparePipeline = try backend.pipeline(
            named: "preparePrescribedFlappingWing"
        )
        geometryPipeline = try backend.pipeline(
            named: "buildPrescribedFormationWings"
        )
        initializePipeline = try backend.pipeline(
            named: "initializePopulations"
        )
        fluidPipeline = try backend.pipeline(named: "stepFluidTRT")
        ownerLoadPipeline = try backend.pipeline(
            named: "capturePrescribedFormationLoad"
        )
        mechanismComponentPipeline = captureMechanismProbes
            ? try backend.pipeline(
                named: "capturePrescribedFormationLoadComponent"
            )
            : nil
        boundarySourceCensusPipeline = captureBoundarySourceCensus
            ? try backend.pipeline(
                named: "capturePrescribedFormationBoundarySourceCensus"
            )
            : nil
        boundarySourceReductionPipeline = captureBoundarySourceCensus
            ? try backend.pipeline(
                named: "reduceFormationBoundarySourceCensus"
            )
            : nil
        boundarySourceStorePipeline = captureBoundarySourceCensus
            ? try backend.pipeline(
                named: "storeFormationBoundarySourceCensus"
            )
            : nil
        reductionPipeline = try backend.pipeline(named: "reduceForceTorque")
        storePipeline = try backend.pipeline(named: "storeForceTorqueSample")
        captureFlowSlicePipeline = captureTargets.isEmpty
            ? nil
            : try backend.pipeline(named: "captureFormationFlowSlice")

        let cells = layout.grid.cellCount
        let populationBytes = D3Q19.count * cells
            * MemoryLayout<Float>.stride
        let maskBytes = cells * MemoryLayout<UInt8>.stride
        let wallBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cells * MemoryLayout<Float>.stride
        let velocityBytes = cells * MemoryLayout<SIMD4<Float>>.stride
        partialLoadCount = max(1, (cells + 255) / 256)
        let reductionBytes = partialLoadCount
            * MemoryLayout<GPUForceTorque>.stride
        let historyBytes = layout.cycleSteps
            * MemoryLayout<GPUForceTorque>.stride
        let sliceCells = layout.grid.x * layout.grid.z
        let flowFieldHistoryBytes = captureTargets.count * sliceCells
            * MemoryLayout<SIMD2<Float>>.stride
        let flowOwnerHistoryBytes = captureTargets.count * sliceCells
            * MemoryLayout<UInt8>.stride
        let mechanismProbeHistoryBytes = captureTargets.count * 2 * 5
            * MemoryLayout<GPUForceTorque>.stride
        let collisionDiagnosticHistoryBytes = request.cycles
            * layout.cycleSteps * MemoryLayout<GPUForceTorque>.stride
        let boundarySourceReductionBytes = partialLoadCount
            * MemoryLayout<GPUFormationBoundarySourceCensus>.stride
        let boundarySourceCensusHistoryBytes = captureTargets.count * 2
            * (D3Q19.count - 1)
            * MemoryLayout<GPUFormationBoundarySourceCensus>.stride
        var allocationLengths = [
            leaderParameters.length,
            followerParameters.length,
            leaderPrepared.length,
            followerPrepared.length,
            control.length,
            overlapCounts.length,
            populationBytes,
            populationBytes,
            maskBytes,
            maskBytes,
            wallBytes,
            densityBytes,
            velocityBytes,
            reductionBytes,
            reductionBytes,
            historyBytes,
            historyBytes,
            historyBytes,
            MemoryLayout<GPUBirdBodyState>.stride,
        ]
        if !captureTargets.isEmpty {
            allocationLengths.append(flowFieldHistoryBytes)
            allocationLengths.append(flowOwnerHistoryBytes)
        }
        if captureMechanismProbes {
            allocationLengths.append(mechanismProbeHistoryBytes)
        }
        if captureCollisionDiagnostics {
            allocationLengths.append(collisionDiagnosticHistoryBytes)
        }
        if captureBoundarySourceCensus {
            allocationLengths.append(boundarySourceReductionBytes)
            allocationLengths.append(boundarySourceReductionBytes)
            allocationLengths.append(boundarySourceCensusHistoryBytes)
        }
        try backend.validateAllocationPlan(bufferLengths: allocationLengths)
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidA = try backend.makePrivateBuffer(length: maskBytes)
        solidB = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(length: wallBytes)
        density = try backend.makePrivateBuffer(length: densityBytes)
        velocity = try backend.makePrivateBuffer(length: velocityBytes)
        reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        totalHistory = try backend.makeSharedBuffer(length: historyBytes)
        leaderHistory = try backend.makeSharedBuffer(length: historyBytes)
        followerHistory = try backend.makeSharedBuffer(length: historyBytes)
        flowFieldHistory = captureTargets.isEmpty
            ? nil
            : try backend.makeSharedBuffer(length: flowFieldHistoryBytes)
        flowOwnerHistory = captureTargets.isEmpty
            ? nil
            : try backend.makeSharedBuffer(length: flowOwnerHistoryBytes)
        mechanismProbeHistory = captureMechanismProbes
            ? try backend.makeSharedBuffer(length: mechanismProbeHistoryBytes)
            : nil
        collisionDiagnosticHistory = captureCollisionDiagnostics
            ? try backend.makeSharedBuffer(
                length: collisionDiagnosticHistoryBytes
            )
            : nil
        boundarySourceReductionA = captureBoundarySourceCensus
            ? try backend.makeSharedBuffer(length: boundarySourceReductionBytes)
            : nil
        boundarySourceReductionB = captureBoundarySourceCensus
            ? try backend.makeSharedBuffer(length: boundarySourceReductionBytes)
            : nil
        boundarySourceCensusHistory = captureBoundarySourceCensus
            ? try backend.makeSharedBuffer(
                length: boundarySourceCensusHistoryBytes
            )
            : nil
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: .zero))
        )
        currentPopulations = populationsA
        nextPopulations = populationsB
        currentSolid = solidA
        nextSolid = solidB
        try initialize()
    }

    func advance(
        to targetStep: Int,
        recordLoads: Bool
    ) throws {
        guard targetStep >= stepIndex else {
            throw FormationFlightValidationError.invalidRequest(
                "target step precedes current formation step"
            )
        }
        while stepIndex < targetStep {
            let count = min(64, targetStep - stepIndex)
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create formation-flight command buffer."
                )
            }
            for localStep in 0..<count {
                let absoluteStep = stepIndex + localStep + 1
                let captureSlot = captureSlotsByStep[absoluteStep]
                var leaderUniforms = makeUniforms(
                    time: Float(absoluteStep),
                    accumulateLoads: recordLoads,
                    hasPreviousGeometry: true,
                    captureFields: captureSlot != nil
                )
                var followerUniforms = makeUniforms(
                    time: Float(absoluteStep)
                        + Float(MetalFormationFlightValidator.unitPhase(
                            request.followerPhaseOffsetCycles
                        ))
                            * Float(layout.cycleSteps),
                    accumulateLoads: recordLoads,
                    hasPreviousGeometry: true,
                    captureFields: false
                )
                try encodePreparation(
                    commandBuffer: commandBuffer,
                    prepared: leaderPrepared,
                    parameters: leaderParameters,
                    uniforms: &leaderUniforms
                )
                try encodePreparation(
                    commandBuffer: commandBuffer,
                    prepared: followerPrepared,
                    parameters: followerParameters,
                    uniforms: &followerUniforms
                )
                try encodeGeometry(
                    commandBuffer: commandBuffer,
                    uniforms: &leaderUniforms,
                    target: nextSolid
                )
                if recordLoads {
                    let sample = (absoluteStep - 1) % layout.cycleSteps
                    // Capture owners before the fluid step. Geometry has just
                    // preserved newly covered fluid momentum in `velocity`;
                    // a requested macroscopic-field capture is then free to
                    // overwrite that scratch value without biasing ownership.
                    try encodeOwnerLoad(
                        commandBuffer: commandBuffer,
                        uniforms: &leaderUniforms,
                        selectedOwner: 1
                    )
                    let leader = try encodeReduction(
                        commandBuffer: commandBuffer
                    )
                    try encodeStore(
                        commandBuffer: commandBuffer,
                        load: leader,
                        history: leaderHistory,
                        sampleIndex: sample
                    )
                    try encodeOwnerLoad(
                        commandBuffer: commandBuffer,
                        uniforms: &leaderUniforms,
                        selectedOwner: 2
                    )
                    let follower = try encodeReduction(
                        commandBuffer: commandBuffer
                    )
                    try encodeStore(
                        commandBuffer: commandBuffer,
                        load: follower,
                        history: followerHistory,
                        sampleIndex: sample
                    )
                    if let captureSlot, captureMechanismProbes {
                        try encodeMechanismProbe(
                            commandBuffer: commandBuffer,
                            uniforms: &leaderUniforms,
                            slot: captureSlot
                        )
                    }
                    if let captureSlot,
                       captureBoundarySourceCensus,
                       boundarySourceCaptureSlots.contains(captureSlot) {
                        try encodeBoundarySourceCensus(
                            commandBuffer: commandBuffer,
                            uniforms: &leaderUniforms,
                            slot: captureSlot
                        )
                    }
                }
                try encodeFluid(
                    commandBuffer: commandBuffer,
                    uniforms: &leaderUniforms
                )
                if let captureSlot {
                    try encodeFlowSlice(
                        commandBuffer: commandBuffer,
                        uniforms: &leaderUniforms,
                        solid: nextSolid,
                        slot: captureSlot
                    )
                }
                if recordLoads || captureCollisionDiagnostics {
                    let sample = (absoluteStep - 1) % layout.cycleSteps
                    let total = try encodeReduction(
                        commandBuffer: commandBuffer
                    )
                    if recordLoads {
                        try encodeStore(
                            commandBuffer: commandBuffer,
                            load: total,
                            history: totalHistory,
                            sampleIndex: sample
                        )
                    }
                    if let collisionDiagnosticHistory {
                        try encodeStore(
                            commandBuffer: commandBuffer,
                            load: total,
                            history: collisionDiagnosticHistory,
                            sampleIndex: absoluteStep - 1
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
    }

    func copyRecordedLoads() -> FormationCycleLoads {
        func copy(_ buffer: MTLBuffer) -> [ForceTorque] {
            let pointer = buffer.contents()
                .assumingMemoryBound(to: GPUForceTorque.self)
            return (0..<layout.cycleSteps).map { pointer[$0].coreValue }
        }
        return FormationCycleLoads(
            total: copy(totalHistory),
            leader: copy(leaderHistory),
            follower: copy(followerHistory)
        )
    }

    func copyMechanismProbeComponents()
        -> [FormationRawMechanismProbeSample] {
        guard captureMechanismProbes,
              let history = mechanismProbeHistory else { return [] }
        let pointer = history.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
        return captureTargets.flatMap { target in
            FormationFlyerID.allCases.enumerated().map { flyerIndex, flyer in
                let base = (target.slot * 2 + flyerIndex) * 5
                return FormationRawMechanismProbeSample(
                    target: target,
                    flyer: flyer,
                    components: (0..<5).map {
                        pointer[base + $0].coreValue
                    }
                )
            }
        }
    }

    func copyBoundarySourceCensusSamples()
        -> [FormationRawBoundarySourceCensusSample] {
        guard captureBoundarySourceCensus,
              let history = boundarySourceCensusHistory else { return [] }
        let pointer = history.contents()
            .assumingMemoryBound(
                to: GPUFormationBoundarySourceCensus.self
            )
        return captureTargets.filter {
            boundarySourceCaptureSlots.contains($0.slot)
        }.flatMap { target in
            FormationFlyerID.allCases.enumerated().map { ownerIndex, flyer in
                let base = (target.slot * 2 + ownerIndex)
                    * (D3Q19.count - 1)
                var directions = [GPUFormationBoundarySourceCensus.zero]
                directions.append(contentsOf: (1..<D3Q19.count).map {
                    pointer[base + $0 - 1]
                })
                return FormationRawBoundarySourceCensusSample(
                    target: target,
                    flyer: flyer,
                    directions: directions
                )
            }
        }
    }

    func copyCollisionDiagnostics() -> FormationRawCollisionDiagnostics? {
        guard captureCollisionDiagnostics,
              let history = collisionDiagnosticHistory else { return nil }
        let sampleCount = request.cycles * layout.cycleSteps
        let pointer = history.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
        let cellCount = Double(layout.grid.cellCount)
        var minimumPopulation = Double.infinity
        var activationCellSteps = 0.0
        var maximumStepActivationFraction = 0.0
        var finite = true
        for index in 0..<sampleCount {
            let minimum = 1 - Double(pointer[index].torque.w)
            let activations = Double(pointer[index].force.w)
            finite = finite && minimum.isFinite && activations.isFinite
            minimumPopulation = min(minimumPopulation, minimum)
            activationCellSteps += activations
            maximumStepActivationFraction = max(
                maximumStepActivationFraction,
                activations / cellCount
            )
        }
        return FormationRawCollisionDiagnostics(
            minimumPopulation: minimumPopulation,
            activationCellSteps: activationCellSteps,
            observedCellSteps: cellCount * Double(sampleCount),
            maximumStepActivationFraction: maximumStepActivationFraction,
            allFinite: finite
        )
    }

    func copyFlowSlices() throws -> [FormationFlightFlowSlice] {
        guard !captureTargets.isEmpty else { return [] }
        guard let fieldHistory = flowFieldHistory,
              let ownerHistory = flowOwnerHistory else {
            throw FormationFlightValidationError.failed(
                "formation flow-history buffers were not allocated"
            )
        }
        let grid = layout.grid
        let planeY = grid.y / 2
        let sliceCells = grid.x * grid.z
        let fieldPointer = fieldHistory.contents()
            .assumingMemoryBound(to: SIMD2<Float>.self)
        let ownerPointer = ownerHistory.contents()
            .assumingMemoryBound(to: UInt8.self)
        let velocityScale = layout.scaling.velocityToPhysical
        let vorticityScale = velocityScale / layout.scaling.cellSizeMeters
        return captureTargets.map { target in
            let start = target.slot * sliceCells
            var vorticity = [Float](repeating: 0, count: sliceCells)
            var vertical = vorticity
            var owners = [UInt8](repeating: 0, count: sliceCells)
            var maximumVorticity: Float = 0
            var maximumVertical: Float = 0
            for index in 0..<sliceCells {
                let field = fieldPointer[start + index]
                let physicalVertical = field.x * velocityScale
                let physicalVorticity = field.y * vorticityScale
                vertical[index] = physicalVertical
                vorticity[index] = physicalVorticity
                owners[index] = ownerPointer[start + index]
                maximumVertical = max(
                    maximumVertical,
                    abs(physicalVertical)
                )
                maximumVorticity = max(
                    maximumVorticity,
                    physicalVorticity
                )
            }
            return FormationFlightFlowSlice(
                schemaVersion: 1,
                plane: "y",
                planeIndex: planeY,
                width: grid.x,
                height: grid.z,
                chordCells: request.chordCells,
                phase: target.phase,
                velocityUnits:
                    "m/s under the canonical lattice-to-SI mapping",
                vorticityUnits:
                    "1/s under the canonical lattice-to-SI mapping",
                maximumVorticityMagnitudePerSecond: maximumVorticity,
                maximumAbsoluteVerticalVelocityMetersPerSecond:
                    maximumVertical,
                vorticityMagnitudePerSecond: vorticity,
                verticalVelocityMetersPerSecond: vertical,
                ownerMask: owners
            )
        }
    }

    var overlapVoxelSamples: Int {
        let pointer = overlapCounts.contents()
            .assumingMemoryBound(to: UInt32.self)
        return (0..<layout.cycleSteps).reduce(0) {
            $0 + Int(pointer[$1])
        }
    }

    private func makeUniforms(
        time: Float,
        accumulateLoads: Bool,
        hasPreviousGeometry: Bool,
        captureFields: Bool = false
    ) -> GPUUniforms {
        var uniforms = GPUUniforms(
            configuration: configuration,
            time: time,
            captureMacroscopicFields: captureFields,
            accumulateLoads:
                accumulateLoads || captureCollisionDiagnostics,
            hasPreviousGeometry: hasPreviousGeometry,
            periodicBoundaries: false,
            caseParameters: SIMD4<Float>(
                0,
                6,
                0,
                collisionOperator.caseParameterW
            )
        )
        uniforms.integration.z = captureCollisionDiagnostics ? 1 : 0
        return uniforms
    }

    private func initialize() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to initialize formation flight."
            )
        }
        var leaderUniforms = makeUniforms(
            time: 0,
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        var followerUniforms = makeUniforms(
            time: Float(MetalFormationFlightValidator.unitPhase(
                request.followerPhaseOffsetCycles
            ))
                * Float(layout.cycleSteps),
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        try encodePreparation(
            commandBuffer: commandBuffer,
            prepared: leaderPrepared,
            parameters: leaderParameters,
            uniforms: &leaderUniforms
        )
        try encodePreparation(
            commandBuffer: commandBuffer,
            prepared: followerPrepared,
            parameters: followerParameters,
            uniforms: &followerUniforms
        )
        try encodeGeometry(
            commandBuffer: commandBuffer,
            uniforms: &leaderUniforms,
            target: currentSolid
        )
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to copy the initial formation mask."
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
                "Unable to initialize formation populations."
            )
        }
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(wallVelocity, offset: 0, index: 2)
        encoder.setBuffer(density, offset: 0, index: 3)
        encoder.setBuffer(velocity, offset: 0, index: 4)
        encoder.setBytes(
            &leaderUniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: initializePipeline,
            count: layout.grid.cellCount
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
    }

    private func encodePreparation(
        commandBuffer: MTLCommandBuffer,
        prepared: MTLBuffer,
        parameters: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to prepare a formation wing."
            )
        }
        encoder.setBuffer(prepared, offset: 0, index: 0)
        encoder.setBuffer(parameters, offset: 0, index: 1)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 2
        )
        backend.dispatch1D(encoder: encoder, pipeline: preparePipeline, count: 1)
        encoder.endEncoding()
    }

    private func encodeGeometry(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        target: MTLBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to build formation geometry."
            )
        }
        encoder.setBuffer(target, offset: 0, index: 0)
        encoder.setBuffer(wallVelocity, offset: 0, index: 1)
        encoder.setBuffer(currentSolid, offset: 0, index: 2)
        encoder.setBuffer(leaderParameters, offset: 0, index: 3)
        encoder.setBuffer(leaderPrepared, offset: 0, index: 4)
        encoder.setBuffer(followerParameters, offset: 0, index: 5)
        encoder.setBuffer(followerPrepared, offset: 0, index: 6)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        encoder.setBuffer(currentPopulations, offset: 0, index: 8)
        encoder.setBuffer(velocity, offset: 0, index: 9)
        encoder.setBuffer(overlapCounts, offset: 0, index: 10)
        encoder.setBuffer(control, offset: 0, index: 11)
        backend.dispatch3D(
            encoder: encoder,
            pipeline: geometryPipeline,
            width: layout.grid.x,
            height: layout.grid.y,
            depth: layout.grid.z
        )
        encoder.endEncoding()
    }

    private func encodeFluid(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to advance formation fluid."
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
            count: layout.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func encodeFlowSlice(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        solid: MTLBuffer,
        slot: Int
    ) throws {
        guard let pipeline = captureFlowSlicePipeline,
              let fields = flowFieldHistory,
              let owners = flowOwnerHistory,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to capture the formation flow slice."
            )
        }
        var captureSlot = UInt32(slot)
        encoder.setBuffer(velocity, offset: 0, index: 0)
        encoder.setBuffer(solid, offset: 0, index: 1)
        encoder.setBuffer(fields, offset: 0, index: 2)
        encoder.setBuffer(owners, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        encoder.setBytes(
            &captureSlot,
            length: MemoryLayout<UInt32>.stride,
            index: 5
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: pipeline,
            count: layout.grid.x * layout.grid.z
        )
        encoder.endEncoding()
    }

    private func encodeBoundarySourceCensus(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        slot: Int
    ) throws {
        guard let pipeline = boundarySourceCensusPipeline,
              let partials = boundarySourceReductionA,
              let history = boundarySourceCensusHistory else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to capture a formation boundary-source census."
            )
        }
        for ownerIndex in 0..<2 {
            for direction in 1..<D3Q19.count {
                guard let encoder = commandBuffer.makeComputeCommandEncoder()
                else {
                    throw BirdFlowError.commandBufferFailed(
                        "Unable to encode a formation boundary-source direction."
                    )
                }
                var selection = SIMD2<UInt32>(
                    UInt32(ownerIndex + 1),
                    UInt32(direction)
                )
                encoder.setBuffer(currentPopulations, offset: 0, index: 0)
                encoder.setBuffer(nextSolid, offset: 0, index: 1)
                encoder.setBuffer(wallVelocity, offset: 0, index: 2)
                encoder.setBuffer(partials, offset: 0, index: 3)
                encoder.setBytes(
                    &uniforms,
                    length: MemoryLayout<GPUUniforms>.stride,
                    index: 4
                )
                encoder.setBytes(
                    &selection,
                    length: MemoryLayout<SIMD2<UInt32>>.stride,
                    index: 5
                )
                backend.dispatch1DPadded(
                    encoder: encoder,
                    pipeline: pipeline,
                    count: layout.grid.cellCount,
                    threadsPerThreadgroup: 256
                )
                encoder.endEncoding()
                let total = try encodeBoundarySourceReduction(
                    commandBuffer: commandBuffer
                )
                try encodeBoundarySourceStore(
                    commandBuffer: commandBuffer,
                    total: total,
                    history: history,
                    sampleIndex: (slot * 2 + ownerIndex)
                        * (D3Q19.count - 1) + direction - 1
                )
            }
        }
    }

    private func encodeBoundarySourceReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        guard let pipeline = boundarySourceReductionPipeline,
              let first = boundarySourceReductionA,
              let second = boundarySourceReductionB else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to reduce a formation boundary-source census."
            )
        }
        var input = first
        var output = second
        var count = partialLoadCount
        while count > 1 {
            let outputCount = (count + 255) / 256
            var count32 = UInt32(count)
            guard let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to encode formation boundary-source reduction."
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
            output = output === first ? second : first
        }
        return input
    }

    private func encodeBoundarySourceStore(
        commandBuffer: MTLCommandBuffer,
        total: MTLBuffer,
        history: MTLBuffer,
        sampleIndex: Int
    ) throws {
        guard let pipeline = boundarySourceStorePipeline,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to store a formation boundary-source census."
            )
        }
        var index = UInt32(sampleIndex)
        encoder.setBuffer(total, offset: 0, index: 0)
        encoder.setBuffer(history, offset: 0, index: 1)
        encoder.setBytes(
            &index,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1D(encoder: encoder, pipeline: pipeline, count: 1)
        encoder.endEncoding()
    }

    private func encodeMechanismProbe(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        slot: Int
    ) throws {
        guard let pipeline = mechanismComponentPipeline,
              let history = mechanismProbeHistory else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to capture a formation mechanism probe."
            )
        }
        for ownerIndex in 0..<2 {
            for component in 0..<5 {
                guard let encoder = commandBuffer.makeComputeCommandEncoder()
                else {
                    throw BirdFlowError.commandBufferFailed(
                        "Unable to encode a formation mechanism component."
                    )
                }
                var selection = SIMD2<UInt32>(
                    UInt32(ownerIndex + 1),
                    UInt32(component)
                )
                encoder.setBuffer(currentPopulations, offset: 0, index: 0)
                encoder.setBuffer(currentSolid, offset: 0, index: 1)
                encoder.setBuffer(nextSolid, offset: 0, index: 2)
                encoder.setBuffer(wallVelocity, offset: 0, index: 3)
                encoder.setBuffer(reductionA, offset: 0, index: 4)
                encoder.setBuffer(leaderPrepared, offset: 0, index: 5)
                encoder.setBuffer(followerPrepared, offset: 0, index: 6)
                encoder.setBytes(
                    &uniforms,
                    length: MemoryLayout<GPUUniforms>.stride,
                    index: 7
                )
                encoder.setBytes(
                    &selection,
                    length: MemoryLayout<SIMD2<UInt32>>.stride,
                    index: 8
                )
                encoder.setBuffer(velocity, offset: 0, index: 9)
                backend.dispatch1DPadded(
                    encoder: encoder,
                    pipeline: pipeline,
                    count: layout.grid.cellCount,
                    threadsPerThreadgroup: 256
                )
                encoder.endEncoding()
                let load = try encodeReduction(commandBuffer: commandBuffer)
                try encodeStore(
                    commandBuffer: commandBuffer,
                    load: load,
                    history: history,
                    sampleIndex: (slot * 2 + ownerIndex) * 5 + component
                )
            }
        }
    }

    private func encodeOwnerLoad(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        selectedOwner: UInt32
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to resolve a formation owner load."
            )
        }
        var owner = selectedOwner
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(currentSolid, offset: 0, index: 1)
        encoder.setBuffer(nextSolid, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(reductionA, offset: 0, index: 4)
        encoder.setBuffer(leaderPrepared, offset: 0, index: 5)
        encoder.setBuffer(followerPrepared, offset: 0, index: 6)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        encoder.setBytes(
            &owner,
            length: MemoryLayout<UInt32>.stride,
            index: 8
        )
        encoder.setBuffer(velocity, offset: 0, index: 9)
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: ownerLoadPipeline,
            count: layout.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func encodeReduction(
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
                    "Unable to reduce a formation load."
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

    private func encodeStore(
        commandBuffer: MTLCommandBuffer,
        load: MTLBuffer,
        history: MTLBuffer,
        sampleIndex: Int
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to store formation history."
            )
        }
        var index = UInt32(sampleIndex)
        encoder.setBuffer(load, offset: 0, index: 0)
        encoder.setBuffer(history, offset: 0, index: 1)
        encoder.setBytes(
            &index,
            length: MemoryLayout<UInt32>.stride,
            index: 2
        )
        backend.dispatch1D(encoder: encoder, pipeline: storePipeline, count: 1)
        encoder.endEncoding()
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw FormationFlightValidationError.failed(
                commandBuffer.error?.localizedDescription
                    ?? "unknown Metal command failure"
            )
        }
    }
}
#endif

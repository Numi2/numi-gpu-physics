import BirdFlowCore
import Foundation

@frozen
public struct MeasuredBirdFreeFlightConfirmationReport: Codable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var datasetIdentifier: String
    public var specimenIdentifier: String
    public var inputSHA256: String
    public var deviceName: String
    public var chordCells: Int
    public var mainCycles: Float
    public var mainSteps: Int
    public var bodySubsteps: Int
    public var ledgerCycles: Float
    public var bodyRefinementCycles: Float
    public var runtimeSeconds: Double
    public var runtimeSafety: RuntimeSafetyReport
    public var finalBody: BirdBodyState
    public var maximumPositionDriftChordFraction: Float
    public var maximumSpeedReferenceFraction: Float
    public var maximumAttitudeDeviationDegrees: Float
    public var maximumAngularVelocityCycleFraction: Float
    public var maximumAllowedPositionDriftChordFraction: Float
    public var maximumAllowedSpeedReferenceFraction: Float
    public var maximumAllowedAttitudeDeviationDegrees: Float
    public var maximumAllowedAngularVelocityCycleFraction: Float
    public var boundedTrajectoryPassed: Bool
    public var bodyRefinement: FreeFlightBodyRefinementReport
    public var coupledRuntimeSafety: RuntimeSafetyReport
    public var coupledMomentumLedger: CoupledMomentumLedgerReport
    public var aerodynamicPartLoads: AerodynamicPartLoadReport
    public var passed: Bool
    public var scientificVerdict: String
}

struct FreeFlightBoundednessMetrics {
    var maximumPositionDriftChordFraction: Float
    var maximumSpeedReferenceFraction: Float
    var maximumAttitudeDeviationDegrees: Float
    var maximumAngularVelocityCycleFraction: Float
}

func makeFreeFlightBoundednessMetrics(
    initial: BirdBodyState,
    samples: [MeasuredBirdReplayPhaseSample],
    chordMeters: Float,
    referenceSpeedMetersPerSecond: Float,
    frequencyHz: Float
) throws -> FreeFlightBoundednessMetrics {
    guard !samples.isEmpty,
          chordMeters.isFinite,
          chordMeters > 0,
          referenceSpeedMetersPerSecond.isFinite,
          referenceSpeedMetersPerSecond > 0,
          frequencyHz.isFinite,
          frequencyHz > 0 else {
        throw MeasuredBirdReplayError.invalidInput(
            "free-flight boundedness requires samples and positive physical scales"
        )
    }
    let angularScale = 2 * Float.pi * frequencyHz
    var maximumPosition: Float = 0
    var maximumSpeed: Float = 0
    var maximumAttitude: Float = 0
    var maximumAngularVelocity: Float = 0
    for sample in samples {
        let body = sample.body
        maximumPosition = max(
            maximumPosition,
            vectorLength(body.positionMeters - initial.positionMeters)
                / chordMeters
        )
        maximumSpeed = max(
            maximumSpeed,
            vectorLength(body.linearVelocityMetersPerSecond)
                / referenceSpeedMetersPerSecond
        )
        maximumAttitude = max(
            maximumAttitude,
            freeFlightQuaternionDifferenceRadians(
                body.orientationBodyToWorld,
                initial.orientationBodyToWorld
            ) * 180 / .pi
        )
        maximumAngularVelocity = max(
            maximumAngularVelocity,
            vectorLength(body.angularVelocityBodyRadiansPerSecond)
                / angularScale
        )
    }
    let values = [
        maximumPosition,
        maximumSpeed,
        maximumAttitude,
        maximumAngularVelocity
    ]
    guard values.allSatisfy(\.isFinite) else {
        throw MeasuredBirdReplayError.nonFiniteResult
    }
    return FreeFlightBoundednessMetrics(
        maximumPositionDriftChordFraction: maximumPosition,
        maximumSpeedReferenceFraction: maximumSpeed,
        maximumAttitudeDeviationDegrees: maximumAttitude,
        maximumAngularVelocityCycleFraction: maximumAngularVelocity
    )
}

private func freeFlightQuaternionDifferenceRadians(
    _ first: Quaternion,
    _ second: Quaternion
) -> Float {
    let normalizedFirst = first.normalized.simd4
    let normalizedSecond = second.normalized.simd4
    let magnitude = min(
        1,
        abs(
            normalizedFirst.x * normalizedSecond.x
                + normalizedFirst.y * normalizedSecond.y
                + normalizedFirst.z * normalizedSecond.z
                + normalizedFirst.w * normalizedSecond.w
        )
    )
    return 2 * acos(magnitude)
}

extension MeasuredBirdReplay {
    public static func runFreeFlightConfirmation(
        _ loaded: LoadedMeasuredBirdDataset,
        chordCells: Int = 8,
        cycles: Float = 5,
        ledgerCycles: Float = 1,
        bodyRefinementCycles: Float = 1,
        batchSize: Int = 32,
        archiveDirectory: URL? = nil
    ) throws -> MeasuredBirdFreeFlightConfirmationReport {
        guard loaded.dataset.schemaVersion >= 2,
              loaded.dataset.prescribedWingDynamics != nil else {
            throw MeasuredBirdReplayError.invalidInput(
                "bounded free-flight confirmation requires schema 2 same-specimen wing mass properties"
            )
        }
        guard chordCells >= 8,
              cycles.isFinite,
              cycles >= 5,
              ledgerCycles.isFinite,
              ledgerCycles >= 1,
              bodyRefinementCycles.isFinite,
              bodyRefinementCycles >= 1,
              batchSize > 0 else {
            throw MeasuredBirdReplayError.invalidInput(
                "free-flight confirmation requires chord cells >= 8, "
                    + "at least five main cycles, at least one "
                    + "ledger/refinement cycle, and positive batch size"
            )
        }

        let audit = try audit(loaded, chordCells: chordCells)
        let ledgerStepCount = ceil(
            Double(ledgerCycles) * Double(audit.stepsPerCycle)
        )
        let refinementStepCount = ceil(
            Double(bodyRefinementCycles) * Double(audit.stepsPerCycle)
        )
        guard ledgerStepCount.isFinite,
              refinementStepCount.isFinite,
              ledgerStepCount <= Double(UInt32.max),
              refinementStepCount <= Double(UInt32.max) else {
            throw MeasuredBirdReplayError.invalidInput(
                "free-flight confirmation diagnostic duration exceeds the supported step range"
            )
        }
        let ledgerSteps = Int(ledgerStepCount)
        let refinementSteps = Int(refinementStepCount)
        let bodySubsteps = 4
        let start = ProcessInfo.processInfo.systemUptime
        let main = try run(
            loaded,
            chordCells: chordCells,
            cycles: cycles,
            batchSize: batchSize,
            freeFlight: true,
            bodySubsteps: bodySubsteps
        )
        guard let runtimeSafety = main.runtimeSafety,
              let finalBody = main.samples.last?.body else {
            throw MeasuredBirdReplayError.nonFiniteResult
        }
        let initial = BirdBodyState(
            positionMeters: loaded.dataset.replay.bodyPositionMeters,
            orientationBodyToWorld:
                loaded.dataset.replay.bodyOrientationBodyToWorld.normalized
        )
        let metrics = try makeFreeFlightBoundednessMetrics(
            initial: initial,
            samples: main.samples,
            chordMeters: loaded.dataset.geometry.wingRootChordMeters,
            referenceSpeedMetersPerSecond:
                loaded.dataset.replay.referenceSpeedMetersPerSecond,
            frequencyHz: loaded.dataset.kinematics.frequencyHz
        )
        let bodyRefinement = try runFreeFlightBodyRefinement(
            loaded,
            chordCells: chordCells,
            steps: refinementSteps,
            batchSize: batchSize
        )
        let coupled = try run(
            loaded,
            chordCells: chordCells,
            steps: ledgerSteps,
            batchSize: 1,
            freeFlight: true,
            bodySubsteps: bodySubsteps,
            captureCoupledMomentumLedger: true
        )
        guard let coupledRuntimeSafety = coupled.runtimeSafety,
              let ledger = coupled.coupledMomentumLedger,
              let partLoads = coupled.aerodynamicPartLoads else {
            throw MeasuredBirdReplayError.nonFiniteResult
        }
        let runtime = ProcessInfo.processInfo.systemUptime - start
        let maximumPositionDrift: Float = 0.10
        let maximumSpeed: Float = 0.05
        let maximumAttitude: Float = 5
        let maximumAngularVelocity: Float = 0.05
        let bounded = runtimeSafety.passed
            && metrics.maximumPositionDriftChordFraction
                <= maximumPositionDrift
            && metrics.maximumSpeedReferenceFraction <= maximumSpeed
            && metrics.maximumAttitudeDeviationDegrees <= maximumAttitude
            && metrics.maximumAngularVelocityCycleFraction
                <= maximumAngularVelocity
        let passed = bounded
            && bodyRefinement.passed
            && ledger.passed
            && partLoads.passed
            && coupledRuntimeSafety.passed
        let report = MeasuredBirdFreeFlightConfirmationReport(
            schemaVersion:
                MeasuredBirdFreeFlightConfirmationReport.schemaVersion,
            datasetIdentifier: loaded.dataset.datasetIdentifier,
            specimenIdentifier:
                loaded.dataset.provenance.specimenIdentifier,
            inputSHA256: loaded.sourceSHA256,
            deviceName: main.deviceName,
            chordCells: chordCells,
            mainCycles: main.cycles,
            mainSteps: main.steps,
            bodySubsteps: bodySubsteps,
            ledgerCycles: Float(ledgerSteps)
                / Float(audit.stepsPerCycle),
            bodyRefinementCycles: Float(refinementSteps)
                / Float(audit.stepsPerCycle),
            runtimeSeconds: runtime,
            runtimeSafety: runtimeSafety,
            finalBody: finalBody,
            maximumPositionDriftChordFraction:
                metrics.maximumPositionDriftChordFraction,
            maximumSpeedReferenceFraction:
                metrics.maximumSpeedReferenceFraction,
            maximumAttitudeDeviationDegrees:
                metrics.maximumAttitudeDeviationDegrees,
            maximumAngularVelocityCycleFraction:
                metrics.maximumAngularVelocityCycleFraction,
            maximumAllowedPositionDriftChordFraction:
                maximumPositionDrift,
            maximumAllowedSpeedReferenceFraction: maximumSpeed,
            maximumAllowedAttitudeDeviationDegrees: maximumAttitude,
            maximumAllowedAngularVelocityCycleFraction:
                maximumAngularVelocity,
            boundedTrajectoryPassed: bounded,
            bodyRefinement: bodyRefinement,
            coupledRuntimeSafety: coupledRuntimeSafety,
            coupledMomentumLedger: ledger,
            aerodynamicPartLoads: partLoads,
            passed: passed,
            scientificVerdict: passed
                ? "bounded free flight, runtime safety, body-step refinement, "
                    + "coupled momentum, and per-part load closure passed for "
                    + "the supplied input; biological validity inherits its "
                    + "provenance"
                : "one or more bounded free-flight, runtime, refinement, "
                    + "momentum, or per-part gates failed; do not claim "
                    + "quantitative free flight"
        )
        if let archiveDirectory {
            try archiveFreeFlightConfirmation(
                report,
                input: loaded.sourceData,
                trajectory: main.samples,
                directory: archiveDirectory
            )
        }
        return report
    }

    private static func archiveFreeFlightConfirmation(
        _ report: MeasuredBirdFreeFlightConfirmationReport,
        input: Data,
        trajectory: [MeasuredBirdReplayPhaseSample],
        directory: URL
    ) throws {
        let manager = FileManager.default
        guard !manager.fileExists(atPath: directory.path) else {
            throw MeasuredBirdReplayError.archiveExists(directory.path)
        }
        let temporary = directory.deletingLastPathComponent()
            .appendingPathComponent(
                ".\(directory.lastPathComponent)-\(UUID().uuidString)",
                isDirectory: true
            )
        try manager.createDirectory(
            at: temporary,
            withIntermediateDirectories: true
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(
                to: temporary.appendingPathComponent(
                    "free-flight-confirmation.json"
                ),
                options: .atomic
            )
            try encoder.encode(report.bodyRefinement).write(
                to: temporary.appendingPathComponent(
                    "body-refinement.json"
                ),
                options: .atomic
            )
            try encoder.encode(report.coupledMomentumLedger).write(
                to: temporary.appendingPathComponent(
                    "coupled-momentum-ledger.json"
                ),
                options: .atomic
            )
            try encoder.encode(report.aerodynamicPartLoads).write(
                to: temporary.appendingPathComponent(
                    "aerodynamic-part-loads.json"
                ),
                options: .atomic
            )
            try input.write(
                to: temporary.appendingPathComponent("input.json"),
                options: .atomic
            )
            var csv = "step,time_s,phase,px_m,py_m,pz_m,"
                + "vx_mps,vy_mps,vz_mps,qx,qy,qz,qw,"
                + "omega_x_radps,omega_y_radps,omega_z_radps\n"
            for sample in trajectory {
                let body = sample.body
                let orientation = body.orientationBodyToWorld
                csv += [
                    String(sample.step),
                    String(sample.timeSeconds),
                    String(sample.cyclePhase),
                    String(body.positionMeters.x),
                    String(body.positionMeters.y),
                    String(body.positionMeters.z),
                    String(body.linearVelocityMetersPerSecond.x),
                    String(body.linearVelocityMetersPerSecond.y),
                    String(body.linearVelocityMetersPerSecond.z),
                    String(orientation.vector.x),
                    String(orientation.vector.y),
                    String(orientation.vector.z),
                    String(orientation.scalar),
                    String(body.angularVelocityBodyRadiansPerSecond.x),
                    String(body.angularVelocityBodyRadiansPerSecond.y),
                    String(body.angularVelocityBodyRadiansPerSecond.z)
                ].joined(separator: ",") + "\n"
            }
            try Data(csv.utf8).write(
                to: temporary.appendingPathComponent(
                    "free-flight-trajectory.csv"
                ),
                options: .atomic
            )
            let format = """
            BirdFlowMetal bounded free-flight confirmation archive.
            input.json is byte-identical to the supplied selected trim input and
            matches report.inputSHA256. The main trajectory is independently
            accompanied by one-cycle body-step refinement and coupled
            momentum/per-part load reports. Passing these solver gates does not
            upgrade synthetic or hybrid geometry into measured biological evidence.
            """
            try Data(format.utf8).write(
                to: temporary.appendingPathComponent("FORMAT.txt"),
                options: .atomic
            )
            try manager.moveItem(at: temporary, to: directory)
        } catch {
            try? manager.removeItem(at: temporary)
            throw error
        }
    }
}

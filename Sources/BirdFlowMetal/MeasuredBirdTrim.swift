import BirdFlowCore
import Foundation

@frozen
public struct MeasuredBirdTrimCandidateReport: Codable, Sendable {
    public var pitchOffsetDegrees: Float
    public var speedScale: Float
    public var candidateDatasetSHA256: String
    public var targetReynoldsNumber: Float
    public var steps: Int
    public var cycles: Float
    public var runtimeSeconds: Double
    public var finalCycleMeanAerodynamicForceNewtons: SIMD3<Float>
    public var finalCycleMeanNetForceNewtons: SIMD3<Float>
    public var finalCycleMeanAerodynamicTorqueNewtonMeters: SIMD3<Float>
    public var relativeNetForceResidual: Float
    public var relativeTorqueResidual: Float
    public var stationarityForceFraction: Float
    public var stationarityTorqueFraction: Float
    public var normalizedBalanceObjective: Double
}

@frozen
public struct MeasuredBirdTrimSearchReport: Codable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var datasetIdentifier: String
    public var specimenIdentifier: String
    public var baseInputSHA256: String
    public var deviceName: String
    public var chordCells: Int
    public var screeningCycles: Float
    public var confirmationCycles: Float
    public var requestedIterations: Int
    public var candidateDefinition: String
    public var pitchBoundsDegrees: SIMD2<Float>
    public var speedScaleBounds: SIMD2<Float>
    public var candidates: [MeasuredBirdTrimCandidateReport]
    public var bestCandidate: MeasuredBirdTrimCandidateReport
    public var maximumAllowedRelativeBalanceResidual: Float
    public var maximumAllowedStationarityFraction: Float
    public var passed: Bool
    public var scientificVerdict: String
}

struct MeasuredBirdTrimCoordinateEvaluation {
    var pitchOffsetRadians: Double
    var logSpeedScale: Double
    var normalizedResidual: [Double]

    var objective: Double {
        sqrt(normalizedResidual.reduce(0.0) { $0 + $1 * $1 })
    }
}

/// Small two-variable Gauss-Newton search used by the measured-bird trim
/// harness. Keeping the optimizer independent of Metal makes its bounds,
/// finite-difference algebra, and convergence behavior directly testable.
func solveMeasuredBirdTrimCoordinates(
    iterations: Int,
    pitchStepRadians: Double,
    logSpeedStep: Double,
    pitchBoundsRadians: ClosedRange<Double>,
    logSpeedBounds: ClosedRange<Double>,
    evaluate: (Double, Double) throws -> [Double]
) throws -> [MeasuredBirdTrimCoordinateEvaluation] {
    precondition(iterations > 0)
    precondition(pitchStepRadians > 0 && logSpeedStep > 0)

    var evaluations: [MeasuredBirdTrimCoordinateEvaluation] = []

    func cached(
        pitch: Double,
        logSpeed: Double
    ) -> MeasuredBirdTrimCoordinateEvaluation? {
        evaluations.first {
            abs($0.pitchOffsetRadians - pitch) <= 1.0e-12
                && abs($0.logSpeedScale - logSpeed) <= 1.0e-12
        }
    }

    func evaluated(
        pitch: Double,
        logSpeed: Double
    ) throws -> MeasuredBirdTrimCoordinateEvaluation {
        if let existing = cached(pitch: pitch, logSpeed: logSpeed) {
            return existing
        }
        let residual = try evaluate(pitch, logSpeed)
        guard !residual.isEmpty,
              residual.allSatisfy(\.isFinite) else {
            throw MeasuredBirdReplayError.nonFiniteResult
        }
        let result = MeasuredBirdTrimCoordinateEvaluation(
            pitchOffsetRadians: pitch,
            logSpeedScale: logSpeed,
            normalizedResidual: residual
        )
        evaluations.append(result)
        return result
    }

    var current = try evaluated(pitch: 0, logSpeed: 0)
    for _ in 0..<iterations {
        let pitchProbeValue = min(
            pitchBoundsRadians.upperBound,
            current.pitchOffsetRadians + pitchStepRadians
        )
        let speedProbeValue = min(
            logSpeedBounds.upperBound,
            current.logSpeedScale + logSpeedStep
        )
        guard pitchProbeValue > current.pitchOffsetRadians + 1.0e-12,
              speedProbeValue > current.logSpeedScale + 1.0e-12 else {
            break
        }
        let pitchProbe = try evaluated(
            pitch: pitchProbeValue,
            logSpeed: current.logSpeedScale
        )
        let speedProbe = try evaluated(
            pitch: current.pitchOffsetRadians,
            logSpeed: speedProbeValue
        )
        guard pitchProbe.normalizedResidual.count
                == current.normalizedResidual.count,
              speedProbe.normalizedResidual.count
                == current.normalizedResidual.count else {
            throw MeasuredBirdReplayError.invalidInput(
                "trim residual dimension changed between candidates"
            )
        }
        let inversePitchStep = 1 / (
            pitchProbeValue - current.pitchOffsetRadians
        )
        let inverseSpeedStep = 1 / (
            speedProbeValue - current.logSpeedScale
        )
        var normal00 = 1.0e-10
        var normal01 = 0.0
        var normal11 = 1.0e-10
        var right0 = 0.0
        var right1 = 0.0
        for index in current.normalizedResidual.indices {
            let column0 = (
                pitchProbe.normalizedResidual[index]
                    - current.normalizedResidual[index]
            ) * inversePitchStep
            let column1 = (
                speedProbe.normalizedResidual[index]
                    - current.normalizedResidual[index]
            ) * inverseSpeedStep
            let residual = current.normalizedResidual[index]
            normal00 += column0 * column0
            normal01 += column0 * column1
            normal11 += column1 * column1
            right0 -= column0 * residual
            right1 -= column1 * residual
        }
        let determinant = normal00 * normal11 - normal01 * normal01
        guard determinant.isFinite,
              determinant > 1.0e-18 else {
            break
        }
        var pitchDelta = (
            right0 * normal11 - normal01 * right1
        ) / determinant
        var speedDelta = (
            normal00 * right1 - normal01 * right0
        ) / determinant
        let maximumPitchUpdate = Double(radians(5))
        let maximumLogSpeedUpdate = log(1.1)
        pitchDelta = max(
            -maximumPitchUpdate,
            min(maximumPitchUpdate, pitchDelta)
        )
        speedDelta = max(
            -maximumLogSpeedUpdate,
            min(maximumLogSpeedUpdate, speedDelta)
        )
        let nextPitch = max(
            pitchBoundsRadians.lowerBound,
            min(
                pitchBoundsRadians.upperBound,
                current.pitchOffsetRadians + pitchDelta
            )
        )
        let nextLogSpeed = max(
            logSpeedBounds.lowerBound,
            min(
                logSpeedBounds.upperBound,
                current.logSpeedScale + speedDelta
            )
        )
        guard abs(nextPitch - current.pitchOffsetRadians) > 1.0e-10
                || abs(nextLogSpeed - current.logSpeedScale) > 1.0e-10
        else {
            break
        }
        current = try evaluated(
            pitch: nextPitch,
            logSpeed: nextLogSpeed
        )
    }
    return evaluations
}

func makeMeasuredBirdTrimCandidate(
    _ loaded: LoadedMeasuredBirdDataset,
    pitchOffsetRadians: Float,
    speedScale: Float
) throws -> LoadedMeasuredBirdDataset {
    guard pitchOffsetRadians.isFinite,
          speedScale.isFinite,
          speedScale > 0 else {
        throw MeasuredBirdReplayError.invalidInput(
            "trim pitch and speed scale must be finite and speed positive"
        )
    }
    var dataset = loaded.dataset
    let pitch = Quaternion.axisAngle(
        axis: SIMD3<Float>(0, 1, 0),
        angle: pitchOffsetRadians
    )
    dataset.replay.bodyOrientationBodyToWorld = (
        dataset.replay.bodyOrientationBodyToWorld.normalized * pitch
    ).normalized
    dataset.replay.farFieldVelocityMetersPerSecond *= speedScale
    dataset.replay.referenceSpeedMetersPerSecond *= speedScale
    dataset.replay.targetReynoldsNumber *= speedScale
    dataset.provenance.processingDescription +=
        "; BirdFlow forward-flight trim candidate: body-local pitch offset "
        + "\(pitchOffsetRadians) rad, speed/Re scale \(speedScale)"
    try dataset.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(dataset)
    return LoadedMeasuredBirdDataset(
        dataset: dataset,
        sourceURL: loaded.sourceURL,
        sourceSHA256: CheckpointArchive.sha256(data),
        sourceData: data
    )
}

extension MeasuredBirdReplay {
    public static func runTrimSearch(
        _ loaded: LoadedMeasuredBirdDataset,
        chordCells: Int = 8,
        screeningCycles: Float = 2,
        confirmationCycles: Float = 5,
        iterations: Int = 2,
        batchSize: Int = 32,
        archiveDirectory: URL? = nil
    ) throws -> MeasuredBirdTrimSearchReport {
        guard loaded.dataset.schemaVersion >= 2,
              loaded.dataset.prescribedWingDynamics != nil else {
            throw MeasuredBirdReplayError.invalidInput(
                "quantitative trim search requires schema 2 same-specimen wing mass properties"
            )
        }
        guard chordCells >= 8,
              screeningCycles.isFinite,
              screeningCycles >= 2,
              confirmationCycles.isFinite,
              confirmationCycles >= 5,
              (1...6).contains(iterations),
              batchSize > 0 else {
            throw MeasuredBirdReplayError.invalidInput(
                "trim search requires chord cells >= 8, at least two screening cycles, at least five confirmation cycles, 1...6 iterations, and positive batch size"
            )
        }
        guard vectorLength(
            loaded.dataset.replay.farFieldVelocityMetersPerSecond
        ) > 1.0e-6 else {
            throw MeasuredBirdReplayError.invalidInput(
                "forward-flight pitch/speed trim requires nonzero freestream; hover needs a declared aerodynamic control variable"
            )
        }

        let pitchBounds = Double(radians(-20))...Double(radians(20))
        let logSpeedBounds = log(0.6)...log(1.4)
        let maximumBalanceResidual: Float = 0.05
        let maximumStationarity: Float = 0.05
        var candidates: [MeasuredBirdTrimCandidateReport] = []
        var candidateData: [String: Data] = [:]
        var deviceName = ""

        let coordinateEvaluations = try solveMeasuredBirdTrimCoordinates(
            iterations: iterations,
            pitchStepRadians: Double(radians(2)),
            logSpeedStep: log(1.05),
            pitchBoundsRadians: pitchBounds,
            logSpeedBounds: logSpeedBounds
        ) { pitchOffset, logSpeed in
            let speedScale = Float(exp(logSpeed))
            let candidateLoaded = try makeMeasuredBirdTrimCandidate(
                loaded,
                pitchOffsetRadians: Float(pitchOffset),
                speedScale: speedScale
            )
            let replay = try run(
                candidateLoaded,
                chordCells: chordCells,
                cycles: screeningCycles,
                batchSize: batchSize
            )
            deviceName = replay.deviceName
            let result = try makeTrimCandidateReport(
                loaded: candidateLoaded,
                replay: replay,
                pitchOffsetRadians: Float(pitchOffset),
                speedScale: speedScale
            )
            candidates.append(result.report)
            candidateData[result.report.candidateDatasetSHA256] =
                candidateLoaded.sourceData
            return result.normalizedResidual
        }
        guard let bestCoordinate = coordinateEvaluations.min(by: {
            $0.objective < $1.objective
        }) else {
            throw MeasuredBirdReplayError.nonFiniteResult
        }
        let bestLoaded = try makeMeasuredBirdTrimCandidate(
            loaded,
            pitchOffsetRadians:
                Float(bestCoordinate.pitchOffsetRadians),
            speedScale: Float(exp(bestCoordinate.logSpeedScale))
        )
        let confirmationReplay = try run(
            bestLoaded,
            chordCells: chordCells,
            cycles: confirmationCycles,
            batchSize: batchSize
        )
        deviceName = confirmationReplay.deviceName
        let best = try makeTrimCandidateReport(
            loaded: bestLoaded,
            replay: confirmationReplay,
            pitchOffsetRadians:
                Float(bestCoordinate.pitchOffsetRadians),
            speedScale: Float(exp(bestCoordinate.logSpeedScale))
        ).report
        candidateData[best.candidateDatasetSHA256] = bestLoaded.sourceData
        let passed = best.relativeNetForceResidual
                <= maximumBalanceResidual
            && best.relativeTorqueResidual <= maximumBalanceResidual
            && best.stationarityForceFraction <= maximumStationarity
            && best.stationarityTorqueFraction <= maximumStationarity
        let report = MeasuredBirdTrimSearchReport(
            schemaVersion: MeasuredBirdTrimSearchReport.schemaVersion,
            datasetIdentifier: loaded.dataset.datasetIdentifier,
            specimenIdentifier:
                loaded.dataset.provenance.specimenIdentifier,
            baseInputSHA256: loaded.sourceSHA256,
            deviceName: deviceName,
            chordCells: chordCells,
            screeningCycles: screeningCycles,
            confirmationCycles: confirmationCycles,
            requestedIterations: iterations,
            candidateDefinition:
                "bounded Gauss-Newton over body-local pitch and freestream/reference-speed scale; Reynolds number scales with speed so physical viscosity is unchanged; measured geometry and wing kinematics are never altered",
            pitchBoundsDegrees: SIMD2<Float>(-20, 20),
            speedScaleBounds: SIMD2<Float>(0.6, 1.4),
            candidates: candidates,
            bestCandidate: best,
            maximumAllowedRelativeBalanceResidual:
                maximumBalanceResidual,
            maximumAllowedStationarityFraction: maximumStationarity,
            passed: passed,
            scientificVerdict: passed
                ? "prescribed forward-flight force/moment balance and five-cycle selected-point stationarity passed; free-flight boundedness and grid/body-step refinement remain separate gates"
                : "no acceptable trim was found inside the declared pitch/speed bounds; do not reinterpret the best candidate as trimmed flight"
        )
        if let archiveDirectory {
            guard let bestInput = candidateData[
                best.candidateDatasetSHA256
            ] else {
                throw MeasuredBirdReplayError.nonFiniteResult
            }
            try archiveTrimSearch(
                report,
                baseInput: loaded.sourceData,
                bestCandidateInput: bestInput,
                directory: archiveDirectory
            )
        }
        return report
    }

    private static func makeTrimCandidateReport(
        loaded: LoadedMeasuredBirdDataset,
        replay: MeasuredBirdReplayReport,
        pitchOffsetRadians: Float,
        speedScale: Float
    ) throws -> (
        report: MeasuredBirdTrimCandidateReport,
        normalizedResidual: [Double]
    ) {
        let completedCycles = max(
            1,
            Int(floor(replay.cycles + 1.0e-4))
        )
        let finalIndex = completedCycles - 1
        let previousIndex = max(0, finalIndex - 1)
        let frequency = loaded.dataset.kinematics.frequencyHz
        let previous = try trimCycleMean(
            replay.samples,
            cycleIndex: previousIndex,
            frequency: frequency
        )
        let final = try trimCycleMean(
            replay.samples,
            cycleIndex: finalIndex,
            frequency: frequency
        )
        let geometry = loaded.dataset.geometry
        let conditions = loaded.dataset.replay
        let wingArea = 2 * geometry.wingSpanMeters
            * 0.5 * (
                geometry.wingRootChordMeters
                    + geometry.wingTipChordMeters
            )
        let dynamicForce = 0.5 * conditions.physicalAirDensity
            * conditions.referenceSpeedMetersPerSecond
            * conditions.referenceSpeedMetersPerSecond
            * wingArea
        let gravityForce = geometry.massKilograms
            * conditions.gravityMetersPerSecondSquared
        let forceScale = max(
            dynamicForce,
            max(vectorLength(gravityForce), 1.0e-9)
        )
        let torqueScale = max(
            forceScale * geometry.wingRootChordMeters,
            1.0e-9
        )
        let netForce = final.forceNewtons + gravityForce
        let normalizedForce = netForce / forceScale
        let normalizedTorque = final.torqueNewtonMeters / torqueScale
        let normalizedResidual = [
            Double(normalizedForce.x),
            Double(normalizedForce.y),
            Double(normalizedForce.z),
            Double(normalizedTorque.x),
            Double(normalizedTorque.y),
            Double(normalizedTorque.z),
        ]
        return (
            MeasuredBirdTrimCandidateReport(
                pitchOffsetDegrees: pitchOffsetRadians * 180 / .pi,
                speedScale: speedScale,
                candidateDatasetSHA256: loaded.sourceSHA256,
                targetReynoldsNumber:
                    conditions.targetReynoldsNumber,
                steps: replay.steps,
                cycles: replay.cycles,
                runtimeSeconds: replay.runtimeSeconds,
                finalCycleMeanAerodynamicForceNewtons:
                    final.forceNewtons,
                finalCycleMeanNetForceNewtons: netForce,
                finalCycleMeanAerodynamicTorqueNewtonMeters:
                    final.torqueNewtonMeters,
                relativeNetForceResidual: vectorLength(normalizedForce),
                relativeTorqueResidual: vectorLength(normalizedTorque),
                stationarityForceFraction: vectorLength(
                    final.forceNewtons - previous.forceNewtons
                ) / forceScale,
                stationarityTorqueFraction: vectorLength(
                    final.torqueNewtonMeters
                        - previous.torqueNewtonMeters
                ) / torqueScale,
                normalizedBalanceObjective: sqrt(
                    normalizedResidual.reduce(0.0) {
                        $0 + $1 * $1
                    }
                )
            ),
            normalizedResidual
        )
    }

    private static func trimCycleMean(
        _ samples: [MeasuredBirdReplayPhaseSample],
        cycleIndex: Int,
        frequency: Float
    ) throws -> ForceTorque {
        let selected = samples.filter {
            Int(floor($0.timeSeconds * frequency + 1.0e-6))
                == cycleIndex
        }
        guard !selected.isEmpty else {
            throw MeasuredBirdReplayError.invalidInput(
                "trim replay did not contain samples for cycle \(cycleIndex)"
            )
        }
        let divisor = Float(max(1, selected.count))
        return ForceTorque(
            forceNewtons: selected.reduce(.zero) {
                $0 + $1.aerodynamicLoad.forceNewtons
            } / divisor,
            torqueNewtonMeters: selected.reduce(.zero) {
                $0 + $1.aerodynamicLoad.torqueNewtonMeters
            } / divisor
        )
    }

    static func archiveTrimSearch(
        _ report: MeasuredBirdTrimSearchReport,
        baseInput: Data,
        bestCandidateInput: Data,
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
                    "trim-search-report.json"
                ),
                options: .atomic
            )
            try baseInput.write(
                to: temporary.appendingPathComponent("base-input.json"),
                options: .atomic
            )
            try bestCandidateInput.write(
                to: temporary.appendingPathComponent(
                    "best-candidate-input.json"
                ),
                options: .atomic
            )
            let format = """
            BirdFlowMetal measured-bird forward-flight trim-search archive.
            base-input.json is byte-identical to the supplied specimen input and matches report.baseInputSHA256.
            best-candidate-input.json contains the exact deterministic pitch/speed override used by report.bestCandidate.
            The search preserves physical viscosity and measured wing kinematics. A passing balance search is not free-flight boundedness or grid/body-step acceptance.
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

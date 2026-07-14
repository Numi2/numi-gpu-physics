import BirdFlowCore
import Foundation

public enum MeasuredBirdReplayError: Error, CustomStringConvertible {
    case invalidInput(String)
    case nonFiniteResult
    case archiveExists(String)

    public var description: String {
        switch self {
        case .invalidInput(let message):
            return "Measured-bird replay input is invalid: \(message)"
        case .nonFiniteResult:
            return "Measured-bird replay produced a non-finite load or body state."
        case .archiveExists(let path):
            return "Measured-bird replay archive already exists: \(path)"
        }
    }
}

@frozen
public struct LoadedMeasuredBirdDataset: Sendable {
    public var dataset: MeasuredBirdDataset
    public var sourceURL: URL
    public var sourceSHA256: String
    public var sourceData: Data
}

public enum MeasuredBirdDatasetLoader {
    public static func load(from sourceURL: URL) throws
        -> LoadedMeasuredBirdDataset {
        let canonicalURL = sourceURL.standardizedFileURL
        let data = try Data(contentsOf: canonicalURL)
        try StrictMeasuredBirdJSON.rejectUnknownKeys(in: data)
        let decoder = JSONDecoder()
        let dataset: MeasuredBirdDataset
        do {
            dataset = try decoder.decode(MeasuredBirdDataset.self, from: data)
        } catch {
            throw MeasuredBirdReplayError.invalidInput(
                "JSON decoding failed: \(error.localizedDescription)"
            )
        }
        try dataset.validate()
        return LoadedMeasuredBirdDataset(
            dataset: dataset,
            sourceURL: canonicalURL,
            sourceSHA256: CheckpointArchive.sha256(data),
            sourceData: data
        )
    }
}

private enum StrictMeasuredBirdJSON {
    static func rejectUnknownKeys(in data: Data) throws {
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw MeasuredBirdReplayError.invalidInput(
                "JSON parsing failed: \(error.localizedDescription)"
            )
        }
        let top = try object(
            root,
            path: "$",
            allowed: [
                "schemaVersion", "datasetIdentifier", "provenance", "units",
                "coordinateFrame", "geometryRepresentation", "geometry",
                "kinematics", "replay",
            ]
        )
        try check(
            top["provenance"], path: "$.provenance",
            allowed: [
                "specimenIdentifier", "geometryCitation",
                "kinematicsCitation", "dataLicense", "processingDescription",
            ]
        )
        try check(
            top["units"], path: "$.units",
            allowed: ["length", "mass", "time", "angle", "angularRate"]
        )
        try check(
            top["coordinateFrame"], path: "$.coordinateFrame",
            allowed: ["handedness", "origin", "xAxis", "yAxis", "zAxis"]
        )
        try check(
            top["geometry"], path: "$.geometry",
            allowed: [
                "bodyRadiiMeters", "massKilograms",
                "principalInertiaKilogramMetersSquared", "wingSpanMeters",
                "wingRootChordMeters", "wingTipChordMeters",
                "wingThicknessMeters", "wingSweepMeters",
                "wingRootOffsetMeters", "tailLengthMeters",
                "tailHalfWidthMeters", "tailThicknessMeters",
            ]
        )
        let kinematics = try object(
            top["kinematics"],
            path: "$.kinematics",
            allowed: ["frequencyHz", "keyframes"]
        )
        guard let keyframes = kinematics["keyframes"] as? [Any] else {
            throw MeasuredBirdReplayError.invalidInput(
                "$.kinematics.keyframes must be an array"
            )
        }
        let wingKeys: Set<String> = [
            "strokeRadians", "deviationRadians", "pitchRadians",
            "tipTwistRadians", "strokeRateRadiansPerSecond",
            "deviationRateRadiansPerSecond", "pitchRateRadiansPerSecond",
            "tipTwistRateRadiansPerSecond",
        ]
        for (index, raw) in keyframes.enumerated() {
            let path = "$.kinematics.keyframes[\(index)]"
            let keyframe = try object(
                raw,
                path: path,
                allowed: ["phase", "left", "right"]
            )
            try check(
                keyframe["left"], path: "\(path).left", allowed: wingKeys
            )
            try check(
                keyframe["right"], path: "\(path).right", allowed: wingKeys
            )
        }
        let replay = try object(
            top["replay"],
            path: "$.replay",
            allowed: [
                "domainOriginMeters", "domainSizeMeters", "bodyPositionMeters",
                "bodyOrientationBodyToWorld",
                "farFieldVelocityMetersPerSecond",
                "gravityMetersPerSecondSquared", "referenceSpeedMetersPerSecond",
                "targetReynoldsNumber", "physicalAirDensity",
                "latticeReferenceSpeed", "spongeStrength",
            ]
        )
        try check(
            replay["bodyOrientationBodyToWorld"],
            path: "$.replay.bodyOrientationBodyToWorld",
            allowed: ["vector", "scalar"]
        )
    }

    private static func check(
        _ value: Any?,
        path: String,
        allowed: Set<String>
    ) throws {
        _ = try object(value, path: path, allowed: allowed)
    }

    private static func object(
        _ value: Any?,
        path: String,
        allowed: Set<String>
    ) throws -> [String: Any] {
        guard let dictionary = value as? [String: Any] else {
            throw MeasuredBirdReplayError.invalidInput(
                "\(path) must be an object"
            )
        }
        let unknown = Set(dictionary.keys).subtracting(allowed).sorted()
        guard unknown.isEmpty else {
            throw MeasuredBirdReplayError.invalidInput(
                "unknown key(s) at \(path): \(unknown.joined(separator: ", "))"
            )
        }
        return dictionary
    }
}

@frozen
public struct MeasuredBirdReplayAudit: Codable, Sendable {
    public var schemaVersion: Int
    public var datasetIdentifier: String
    public var specimenIdentifier: String
    public var sourcePath: String
    public var sourceSHA256: String
    public var geometryRepresentation: String
    public var kinematicKeyframeCount: Int
    public var frequencyHz: Float
    public var maximumAngularRateRadiansPerSecond: Float
    public var chordCells: Int
    public var grid: GridSize
    public var requestedDomainSizeMeters: SIMD3<Float>
    public var representedDomainSizeMeters: SIMD3<Float>
    public var cellSizeMeters: Float
    public var timeStepSeconds: Float
    public var stepsPerCycle: Int
    public var estimatedMaximumLatticeMach: Float
    public var passed: Bool
    public var scientificVerdict: String
}

@frozen
public struct MeasuredBirdReplayPhaseSample: Codable, Sendable {
    public var step: UInt64
    public var timeSeconds: Float
    public var cyclePhase: Float
    public var aerodynamicLoad: ForceTorque
}

@frozen
public struct MeasuredBirdReplayReport: Codable, Sendable {
    public var audit: MeasuredBirdReplayAudit
    public var deviceName: String
    public var steps: Int
    public var cycles: Float
    public var batchSize: Int
    public var runtimeSeconds: Double
    public var meanForceNewtons: SIMD3<Float>
    public var meanTorqueNewtonMeters: SIMD3<Float>
    public var samples: [MeasuredBirdReplayPhaseSample]
    public var passed: Bool
    public var scientificVerdict: String
}

public enum MeasuredBirdReplay {
    public static func audit(
        _ loaded: LoadedMeasuredBirdDataset,
        chordCells: Int
    ) throws -> MeasuredBirdReplayAudit {
        let plan = try makePlan(loaded.dataset, chordCells: chordCells)
        let speed = loaded.dataset.geometry
            .birdParameters(measuredKinematics: loaded.dataset.kinematics)
            .maximumPrescribedWingSpeedMetersPerSecond
            + vectorLength(
                loaded.dataset.replay.farFieldVelocityMetersPerSecond
            )
        let mach = speed
            * plan.configuration.scaling.velocityToLattice
            / D3Q19.soundSpeed
        return MeasuredBirdReplayAudit(
            schemaVersion: loaded.dataset.schemaVersion,
            datasetIdentifier: loaded.dataset.datasetIdentifier,
            specimenIdentifier:
                loaded.dataset.provenance.specimenIdentifier,
            sourcePath: loaded.sourceURL.path,
            sourceSHA256: loaded.sourceSHA256,
            geometryRepresentation:
                loaded.dataset.geometryRepresentation,
            kinematicKeyframeCount:
                loaded.dataset.kinematics.keyframes.count,
            frequencyHz: loaded.dataset.kinematics.frequencyHz,
            maximumAngularRateRadiansPerSecond:
                loaded.dataset.kinematics
                    .maximumAngularRateRadiansPerSecond,
            chordCells: chordCells,
            grid: plan.configuration.grid,
            requestedDomainSizeMeters:
                loaded.dataset.replay.domainSizeMeters,
            representedDomainSizeMeters:
                plan.configuration.domainSizeMeters,
            cellSizeMeters: plan.configuration.scaling.cellSizeMeters,
            timeStepSeconds: plan.configuration.scaling.timeStepSeconds,
            stepsPerCycle: plan.stepsPerCycle,
            estimatedMaximumLatticeMach: mach,
            passed: true,
            scientificVerdict:
                "input contract accepted; no quantitative bird-flight verdict"
        )
    }

    public static func run(
        _ loaded: LoadedMeasuredBirdDataset,
        chordCells: Int,
        cycles: Float = 1,
        steps explicitSteps: Int? = nil,
        batchSize: Int = 32,
        archiveDirectory: URL? = nil
    ) throws -> MeasuredBirdReplayReport {
        #if canImport(Metal)
        guard chordCells >= 8,
              cycles.isFinite,
              cycles > 0,
              explicitSteps.map({ $0 > 0 }) ?? true,
              batchSize > 0 else {
            throw MeasuredBirdReplayError.invalidInput(
                "chord cells must be >= 8, cycles and steps positive, and batch size positive"
            )
        }
        let plan = try makePlan(loaded.dataset, chordCells: chordCells)
        let audit = try audit(loaded, chordCells: chordCells)
        let requestedSteps = explicitSteps.map(Double.init)
            ?? ceil(Double(cycles) * Double(plan.stepsPerCycle))
        guard requestedSteps.isFinite,
              requestedSteps >= 1,
              requestedSteps <= Double(UInt32.max) else {
            throw MeasuredBirdReplayError.invalidInput(
                "requested replay duration exceeds the UInt32 sample-index limit"
            )
        }
        let steps = Int(requestedSteps)
        let simulation = try BirdFlowSimulation(
            configuration: plan.configuration,
            bird: plan.bird,
            initialBodyState: plan.initialBodyState
        )
        let start = ProcessInfo.processInfo.systemUptime
        let result = try simulation.advance(
            steps: steps,
            batchSize: min(batchSize, steps),
            fieldCapture: .disabled,
            recordRunSamples: true
        )
        let runtime = ProcessInfo.processInfo.systemUptime - start
        let frequency = loaded.dataset.kinematics.frequencyHz
        let samples = result.runSamples.map { sample in
            var phase = (sample.timeSeconds * frequency)
                .truncatingRemainder(dividingBy: 1)
            if phase < 0 { phase += 1 }
            return MeasuredBirdReplayPhaseSample(
                step: sample.step,
                timeSeconds: sample.timeSeconds,
                cyclePhase: phase,
                aerodynamicLoad: sample.aerodynamicLoad
            )
        }
        guard samples.count == steps,
              samples.allSatisfy(isFinite) else {
            throw MeasuredBirdReplayError.nonFiniteResult
        }
        let denominator = Float(max(1, samples.count))
        let meanForce = samples.reduce(SIMD3<Float>.zero) {
            $0 + $1.aerodynamicLoad.forceNewtons
        } / denominator
        let meanTorque = samples.reduce(SIMD3<Float>.zero) {
            $0 + $1.aerodynamicLoad.torqueNewtonMeters
        } / denominator
        let report = MeasuredBirdReplayReport(
            audit: audit,
            deviceName: simulation.metalDevice.name,
            steps: steps,
            cycles: Float(steps)
                * plan.configuration.scaling.timeStepSeconds
                * frequency,
            batchSize: min(batchSize, steps),
            runtimeSeconds: runtime,
            meanForceNewtons: meanForce,
            meanTorqueNewtonMeters: meanTorque,
            samples: samples,
            passed: true,
            scientificVerdict:
                "prescribed replay completed; grid convergence and force-balance acceptance were not evaluated"
        )
        if let archiveDirectory {
            try archive(
                report,
                loaded: loaded,
                directory: archiveDirectory
            )
        }
        return report
        #else
        throw BirdFlowError.metalUnavailable
        #endif
    }

    private struct Plan {
        var configuration: SimulationConfiguration
        var bird: BirdParameters
        var initialBodyState: BirdBodyState
        var stepsPerCycle: Int
    }

    private static func makePlan(
        _ dataset: MeasuredBirdDataset,
        chordCells: Int
    ) throws -> Plan {
        guard chordCells >= 8 else {
            throw MeasuredBirdReplayError.invalidInput(
                "chordCells must be at least 8"
            )
        }
        try dataset.validate()
        let scaling = try LatticeScaling(
            characteristicLengthMeters:
                dataset.geometry.wingRootChordMeters,
            characteristicLengthCells: chordCells,
            referenceSpeedMetersPerSecond:
                dataset.replay.referenceSpeedMetersPerSecond,
            targetReynoldsNumber:
                dataset.replay.targetReynoldsNumber,
            physicalAirDensity: dataset.replay.physicalAirDensity,
            latticeReferenceSpeed:
                dataset.replay.latticeReferenceSpeed
        )
        func cells(_ length: Float) throws -> Int {
            let requested = ceil(
                Double(length) / Double(scaling.cellSizeMeters)
            )
            guard requested.isFinite,
                  requested > 0,
                  requested <= Double(UInt32.max) else {
                throw MeasuredBirdReplayError.invalidInput(
                    "requested domain dimension cannot be represented"
                )
            }
            return max(16, Int(requested))
        }
        let grid = try GridSize(
            x: cells(dataset.replay.domainSizeMeters.x),
            y: cells(dataset.replay.domainSizeMeters.y),
            z: cells(dataset.replay.domainSizeMeters.z)
        )
        let minimumDimension = min(grid.x, min(grid.y, grid.z))
        let spongeWidth = max(4, Int(ceil(0.08 * Float(minimumDimension))))
        let configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: dataset.replay.domainOriginMeters,
            scaling: scaling,
            physicalAirDensity: dataset.replay.physicalAirDensity,
            farFieldVelocityMetersPerSecond:
                dataset.replay.farFieldVelocityMetersPerSecond,
            spongeWidthCells: spongeWidth,
            spongeStrength: dataset.replay.spongeStrength,
            freeFlight: false,
            gravityMetersPerSecondSquared:
                dataset.replay.gravityMetersPerSecondSquared,
            fastMath: false
        )
        let bird = dataset.geometry.birdParameters(
            measuredKinematics: dataset.kinematics
        )
        let initialBodyState = BirdBodyState(
            positionMeters: dataset.replay.bodyPositionMeters,
            orientationBodyToWorld:
                dataset.replay.bodyOrientationBodyToWorld.normalized
        )
        try bird.validate(
            initialBodyState: initialBodyState,
            for: configuration
        )
        let requestedCycleSteps = ceil(
            1 / Double(dataset.kinematics.frequencyHz)
                / Double(scaling.timeStepSeconds)
        )
        guard requestedCycleSteps.isFinite,
              requestedCycleSteps >= 1,
              requestedCycleSteps <= Double(UInt32.max) else {
            throw MeasuredBirdReplayError.invalidInput(
                "one measured cycle exceeds the UInt32 sample-index limit"
            )
        }
        let stepsPerCycle = Int(requestedCycleSteps)
        return Plan(
            configuration: configuration,
            bird: bird,
            initialBodyState: initialBodyState,
            stepsPerCycle: stepsPerCycle
        )
    }

    private static func isFinite(
        _ sample: MeasuredBirdReplayPhaseSample
    ) -> Bool {
        sample.timeSeconds.isFinite
            && sample.cyclePhase.isFinite
            && finite(sample.aerodynamicLoad.forceNewtons)
            && finite(sample.aerodynamicLoad.torqueNewtonMeters)
    }

    private static func finite(_ value: SIMD3<Float>) -> Bool {
        value.x.isFinite && value.y.isFinite && value.z.isFinite
    }

    private static func archive(
        _ report: MeasuredBirdReplayReport,
        loaded: LoadedMeasuredBirdDataset,
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
                to: temporary.appendingPathComponent("report.json"),
                options: .atomic
            )
            try loaded.sourceData.write(
                to: temporary.appendingPathComponent("input.json"),
                options: .atomic
            )
            var csv = "step,time_s,phase,fx_N,fy_N,fz_N,tx_Nm,ty_Nm,tz_Nm\n"
            for sample in report.samples {
                let force = sample.aerodynamicLoad.forceNewtons
                let torque = sample.aerodynamicLoad.torqueNewtonMeters
                csv += [
                    String(sample.step),
                    String(sample.timeSeconds),
                    String(sample.cyclePhase),
                    String(force.x), String(force.y), String(force.z),
                    String(torque.x), String(torque.y), String(torque.z),
                ].joined(separator: ",") + "\n"
            }
            try Data(csv.utf8).write(
                to: temporary.appendingPathComponent("phase-loads.csv"),
                options: .atomic
            )
            let format = """
            BirdFlowMetal measured-bird prescribed replay archive schema 1
            input.json is the exact byte-for-byte input; verify SHA-256 against report.json.
            phase-loads.csv records physical total aerodynamic force and torque.
            Geometry representation: \(report.audit.geometryRepresentation).
            This archive does not by itself establish grid convergence or quantitative bird-flight validity.
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

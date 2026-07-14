import BirdFlowCore
import Foundation

public enum MetalWingValidationError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid Metal wing validation request: \(message)"
        case .failed(let message):
            return "Metal wing validation failed: \(message)"
        }
    }
}

public struct MetalWingCaseResult: Codable, Sendable {
    public let resolution: Int
    public let verticalResolution: Int
    public let spanwiseResolution: Int
    public let chordCells: Int
    public let spanCells: Int
    public let voxelThicknessToChord: Double
    public let latticeViscosity: Double
    public let tauPlus: Double
    public let steps: Int
    public let convectiveTime: Double
    public let liftCoefficient: Double
    public let dragCoefficient: Double
    public let referenceLiftCoefficient: Double
    public let referenceDragCoefficient: Double
    public let relativeLiftError: Double
    public let relativeDragError: Double
    public let sideForceRatio: Double
    public let rollYawMomentCoefficient: Double
    public let pitchMomentCoefficient: Double
    public let normalizedSpanSymmetryError: Double
    public let forceX: Double
    public let forceY: Double
    public let forceZ: Double
    public let torqueX: Double
    public let torqueY: Double
    public let torqueZ: Double
}

public struct MetalWingValidationReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let passed: Bool
    public let reynoldsNumber: Double
    public let angleOfAttackDegrees: Double
    public let aspectRatio: Double
    public let targetConvectiveTime: Double
    public let latticeFarFieldSpeed: Double
    public let domainLengthChords: Double
    public let domainVerticalChords: Double
    public let domainSpanwiseChords: Double
    public let referenceLiftCoefficient: Double
    public let referenceDragCoefficient: Double
    public let referenceDescription: String
    public let relativeFinestTwoLiftChange: Double
    public let relativeFinestTwoDragChange: Double
    public let maximumBatchDensityDifference: Double
    public let maximumBatchVelocityDifference: Double
    public let maximumBatchForceDifference: Double
    public let maximumAllowedCoefficientError: Double
    public let maximumAllowedFinestTwoChange: Double
    public let maximumAllowedSideForceRatio: Double
    public let maximumAllowedRollYawMomentCoefficient: Double
    public let maximumAllowedSpanSymmetryError: Double
    public let maximumAllowedBatchDifference: Double
    public let cases: [MetalWingCaseResult]
}

/// Production-kernel finite-wing validation against the Re=100, AR=2,
/// alpha=30-degree rectangular flat-plate case in Taira & Colonius (2009).
public enum MetalWingValidator {
    public static let reynoldsNumber: Float = 100
    public static let latticeFarFieldSpeed: Float = 0.08
    public static let angleOfAttackDegrees = 30.0
    public static let aspectRatio = 2.0
    public static let targetConvectiveTime = 13.0
    public static let domainLengthChords = 10.0
    public static let domainVerticalChords = 10.0
    public static let domainSpanwiseChords = 6.0
    public static let referenceLiftCoefficient = 0.75
    public static let referenceDragCoefficient = 0.75
    public static let maximumCoefficientError = 0.20
    public static let maximumFinestTwoChange = 0.03
    public static let maximumSideForceRatio = 1.0e-3
    public static let maximumRollYawMomentCoefficient = 1.0e-3
    public static let maximumSpanSymmetryError = 1.0e-3
    public static let maximumBatchDifference = 1.0e-7
    public static let referenceDescription =
        "Taira and Colonius (JFM 2009), AR=2 rectangular plate at Re=100 and alpha=30 degrees: Figure 3 gives approximately CL=0.75 and CD=0.75 at U*t/c=13"

    /// Runs one diagnostic resolution without assigning a validation verdict.
    /// This avoids repeating an entire refinement ladder when extending an
    /// existing convergence study. Release evidence must still use `run`.
    public static func runSingleCase(
        resolution: Int,
        archiveDirectory: URL? = nil
    ) throws -> MetalWingCaseResult {
        guard resolution >= 80, resolution.isMultiple(of: 10) else {
            throw MetalWingValidationError.invalidRequest(
                "single-case streamwise resolution must be a multiple of 10 and at least 80"
            )
        }
        let chord = resolution / Int(domainLengthChords)
        do {
            _ = try GridSize(
                x: resolution,
                y: chord * Int(domainVerticalChords),
                z: chord * Int(domainSpanwiseChords)
            )
        } catch {
            throw MetalWingValidationError.invalidRequest(
                "single-case resolution exceeds the supported grid range"
            )
        }

#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let artifact = try runCase(backend: backend, resolution: resolution)
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
            try archiveFields(
                directory: archiveDirectory,
                result: artifact.result,
                density: artifact.density,
                velocity: artifact.velocity
            )
            try archiveSingleCaseMetadata(
                artifact.result,
                directory: archiveDirectory
            )
        }
        return artifact.result
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func run(
        finestResolution: Int = 400,
        archiveDirectory: URL? = nil
    ) throws -> MetalWingValidationReport {
        guard finestResolution >= 400,
              finestResolution.isMultiple(of: 200) else {
            throw MetalWingValidationError.invalidRequest(
                "finest streamwise resolution must be a multiple of 200 and at least 400 so the 10c x 10c x 6c refinement ladder retains at least 24 cells per chord"
            )
        }
        let finestChord = finestResolution / Int(domainLengthChords)
        let finestVertical = finestChord * Int(domainVerticalChords)
        let finestSpanwise = finestChord * Int(domainSpanwiseChords)
        do {
            _ = try GridSize(
                x: finestResolution,
                y: finestVertical,
                z: finestSpanwise
            )
        } catch {
            throw MetalWingValidationError.invalidRequest(
                "finest resolution exceeds the supported grid range"
            )
        }

#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let resolutions = [
            finestResolution * 3 / 5,
            finestResolution * 4 / 5,
            finestResolution,
        ]
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
        }

        var results: [MetalWingCaseResult] = []
        for resolution in resolutions {
            let artifact = try runCase(
                backend: backend,
                resolution: resolution
            )
            results.append(artifact.result)
            if let archiveDirectory {
                try archiveFields(
                    directory: archiveDirectory,
                    result: artifact.result,
                    density: artifact.density,
                    velocity: artifact.velocity
                )
            }
        }

        let batch = try batchDifference(backend: backend)
        let finest = results[results.count - 1]
        let nextFinest = results[results.count - 2]
        let liftChange = relativeChange(
            finest.liftCoefficient,
            nextFinest.liftCoefficient
        )
        let dragChange = relativeChange(
            finest.dragCoefficient,
            nextFinest.dragCoefficient
        )
        let finiteResults = results.allSatisfy {
            $0.liftCoefficient.isFinite
                && $0.dragCoefficient.isFinite
                && $0.sideForceRatio.isFinite
                && $0.rollYawMomentCoefficient.isFinite
                && $0.normalizedSpanSymmetryError.isFinite
        }
        let passed = finiteResults
            && finest.relativeLiftError <= maximumCoefficientError
            && finest.relativeDragError <= maximumCoefficientError
            && liftChange <= maximumFinestTwoChange
            && dragChange <= maximumFinestTwoChange
            && results.allSatisfy {
                $0.sideForceRatio <= maximumSideForceRatio
                    && $0.rollYawMomentCoefficient
                        <= maximumRollYawMomentCoefficient
                    && $0.normalizedSpanSymmetryError
                        <= maximumSpanSymmetryError
            }
            && batch.density <= maximumBatchDifference
            && batch.velocity <= maximumBatchDifference
            && batch.force <= maximumBatchDifference

        let report = MetalWingValidationReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            passed: passed,
            reynoldsNumber: Double(reynoldsNumber),
            angleOfAttackDegrees: angleOfAttackDegrees,
            aspectRatio: aspectRatio,
            targetConvectiveTime: targetConvectiveTime,
            latticeFarFieldSpeed: Double(latticeFarFieldSpeed),
            domainLengthChords: domainLengthChords,
            domainVerticalChords: domainVerticalChords,
            domainSpanwiseChords: domainSpanwiseChords,
            referenceLiftCoefficient: referenceLiftCoefficient,
            referenceDragCoefficient: referenceDragCoefficient,
            referenceDescription: referenceDescription,
            relativeFinestTwoLiftChange: liftChange,
            relativeFinestTwoDragChange: dragChange,
            maximumBatchDensityDifference: batch.density,
            maximumBatchVelocityDifference: batch.velocity,
            maximumBatchForceDifference: batch.force,
            maximumAllowedCoefficientError: maximumCoefficientError,
            maximumAllowedFinestTwoChange: maximumFinestTwoChange,
            maximumAllowedSideForceRatio: maximumSideForceRatio,
            maximumAllowedRollYawMomentCoefficient:
                maximumRollYawMomentCoefficient,
            maximumAllowedSpanSymmetryError: maximumSpanSymmetryError,
            maximumAllowedBatchDifference: maximumBatchDifference,
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

#if canImport(Metal)
import Metal

private extension MetalWingValidator {
    struct CaseArtifact {
        let result: MetalWingCaseResult
        let density: [Float]
        let velocity: [SIMD3<Float>]
    }

    struct BatchDifference {
        let density: Double
        let velocity: Double
        let force: Double
    }

    static func runCase(
        backend: MetalBackend,
        resolution: Int
    ) throws -> CaseArtifact {
        let chord = resolution / Int(domainLengthChords)
        let span = Int(aspectRatio) * chord
        let verticalResolution = chord * Int(domainVerticalChords)
        let spanwiseResolution = chord * Int(domainSpanwiseChords)
        let grid = try GridSize(
            x: resolution,
            y: verticalResolution,
            z: spanwiseResolution
        )
        let bodyCenter = SIMD3<Float>(
            0.3 * Float(resolution),
            0.5 * Float(verticalResolution) + 0.5,
            0.5 * Float(spanwiseResolution)
        )
        let alpha = Float(angleOfAttackDegrees * Double.pi / 180)
        let simulation = try MetalStaticCanonicalSimulation(
            backend: backend,
            grid: grid,
            characteristicLengthCells: chord,
            latticeReferenceSpeed: latticeFarFieldSpeed,
            targetReynoldsNumber: reynoldsNumber,
            farFieldVelocityMetersPerSecond: SIMD3<Float>(
                latticeFarFieldSpeed * cos(alpha),
                latticeFarFieldSpeed * sin(alpha),
                0
            ),
            spongeWidthCells: max(4, chord / 2),
            spongeStrength: 0.04,
            bodyPositionMeters: bodyCenter,
            caseParameters: SIMD4<Float>(
                0.5 * Float(chord),
                0.5 * Float(span),
                1,
                Float(angleOfAttackDegrees * Double.pi / 180)
            ),
            initializationPipeline: try backend.pipeline(
                named: "initializeFixedWingCase"
            ),
            initializationLabel: "Initialize fixed finite wing in uniform flow"
        )
        let totalSteps = Int(
            (targetConvectiveTime
                * Double(chord)
                / Double(latticeFarFieldSpeed)).rounded()
        )
        let finalLoad = try simulation.advance(
            steps: totalSteps,
            batchSize: 64
        )

        let coefficients = forceCoefficients(
            load: finalLoad,
            chord: Double(chord)
        )
        let fields = simulation.copyFields()
        let force = finalLoad.forceNewtons
        let torque = finalLoad.torqueNewtonMeters
        let dominantForce = max(
            hypot(Double(force.x), Double(force.y)),
            1.0e-30
        )
        let sideRatio = abs(Double(force.z)) / dominantForce
        let momentScale = dynamicPressure
            * aspectRatio * pow(Double(chord), 3)
        let rollYaw = hypot(Double(torque.x), Double(torque.y))
            / momentScale
        let pitch = Double(torque.z) / momentScale
        let symmetry = spanSymmetryError(
            velocity: fields.velocity,
            gridX: resolution,
            gridY: verticalResolution,
            gridZ: spanwiseResolution
        )
        let result = MetalWingCaseResult(
            resolution: resolution,
            verticalResolution: verticalResolution,
            spanwiseResolution: spanwiseResolution,
            chordCells: chord,
            spanCells: span,
            voxelThicknessToChord: 1 / Double(chord),
            latticeViscosity: Double(
                latticeFarFieldSpeed * Float(chord) / reynoldsNumber
            ),
            tauPlus: Double(
                0.5 + 3 * latticeFarFieldSpeed
                    * Float(chord) / reynoldsNumber
            ),
            steps: totalSteps,
            convectiveTime: Double(totalSteps) * Double(latticeFarFieldSpeed)
                / Double(chord),
            liftCoefficient: coefficients.lift,
            dragCoefficient: coefficients.drag,
            referenceLiftCoefficient: referenceLiftCoefficient,
            referenceDragCoefficient: referenceDragCoefficient,
            relativeLiftError: abs(
                coefficients.lift - referenceLiftCoefficient
            ) / referenceLiftCoefficient,
            relativeDragError: abs(
                coefficients.drag - referenceDragCoefficient
            ) / referenceDragCoefficient,
            sideForceRatio: sideRatio,
            rollYawMomentCoefficient: rollYaw,
            pitchMomentCoefficient: pitch,
            normalizedSpanSymmetryError: symmetry,
            forceX: Double(force.x),
            forceY: Double(force.y),
            forceZ: Double(force.z),
            torqueX: Double(torque.x),
            torqueY: Double(torque.y),
            torqueZ: Double(torque.z)
        )
        return CaseArtifact(
            result: result,
            density: fields.density,
            velocity: fields.velocity
        )
    }

    static var dynamicPressure: Double {
        0.5 * Double(latticeFarFieldSpeed) * Double(latticeFarFieldSpeed)
    }

    static func forceCoefficients(
        load: ForceTorque,
        chord: Double
    ) -> (lift: Double, drag: Double) {
        let area = aspectRatio * chord * chord
        let denominator = dynamicPressure * area
        let alpha = angleOfAttackDegrees * Double.pi / 180
        let cosine = cos(alpha)
        let sine = sin(alpha)
        let forceX = Double(load.forceNewtons.x)
        let forceY = Double(load.forceNewtons.y)
        return (
            (-forceX * sine + forceY * cosine) / denominator,
            (forceX * cosine + forceY * sine) / denominator
        )
    }

    static func relativeChange(_ first: Double, _ second: Double) -> Double {
        abs(first - second) / max(abs(first), 1.0e-30)
    }

    static func spanSymmetryError(
        velocity: [SIMD3<Float>],
        gridX: Int,
        gridY: Int,
        gridZ: Int
    ) -> Double {
        func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
            x + gridX * (y + gridY * z)
        }
        var squaredError = 0.0
        var componentCount = 0
        for z in 0..<gridZ {
            let mirrorZ = gridZ - 1 - z
            for y in 0..<gridY {
                for x in 0..<gridX {
                    let value = velocity[index(x, y, z)]
                    let mirrored = velocity[index(x, y, mirrorZ)]
                    let difference = SIMD3<Double>(
                        Double(value.x - mirrored.x),
                        Double(value.y - mirrored.y),
                        Double(value.z + mirrored.z)
                    )
                    squaredError += difference.x * difference.x
                        + difference.y * difference.y
                        + difference.z * difference.z
                    componentCount += 3
                }
            }
        }
        return sqrt(squaredError / Double(componentCount))
            / Double(latticeFarFieldSpeed)
    }

    static func batchDifference(backend: MetalBackend) throws -> BatchDifference {
        let chord = 8
        let span = Int(aspectRatio) * chord
        let resolution = chord * Int(domainLengthChords)
        let vertical = chord * Int(domainVerticalChords)
        let spanwise = chord * Int(domainSpanwiseChords)
        let grid = try GridSize(
            x: resolution,
            y: vertical,
            z: spanwise
        )
        let center = SIMD3<Float>(
            0.3 * Float(resolution),
            0.5 * Float(vertical) + 0.5,
            0.5 * Float(spanwise)
        )
        let alpha = Float(angleOfAttackDegrees * Double.pi / 180)
        let caseParameters = SIMD4<Float>(
            0.5 * Float(chord),
            0.5 * Float(span),
            1,
            Float(angleOfAttackDegrees * Double.pi / 180)
        )
        let initializationPipeline = try backend.pipeline(
            named: "initializeFixedWingCase"
        )
        func makeSimulation() throws -> MetalStaticCanonicalSimulation {
            try MetalStaticCanonicalSimulation(
                backend: backend,
                grid: grid,
                characteristicLengthCells: chord,
                latticeReferenceSpeed: latticeFarFieldSpeed,
                targetReynoldsNumber: reynoldsNumber,
                farFieldVelocityMetersPerSecond: SIMD3<Float>(
                    latticeFarFieldSpeed * cos(alpha),
                    latticeFarFieldSpeed * sin(alpha),
                    0
                ),
                spongeWidthCells: max(4, chord / 2),
                spongeStrength: 0.04,
                bodyPositionMeters: center,
                caseParameters: caseParameters,
                initializationPipeline: initializationPipeline,
                initializationLabel:
                    "Initialize fixed finite wing in uniform flow"
            )
        }
        let single = try makeSimulation()
        let batched = try makeSimulation()
        let singleLoad = try single.advance(steps: 32, batchSize: 1)
        let batchedLoad = try batched.advance(steps: 32, batchSize: 32)
        let singleFields = single.copyFields()
        let batchedFields = batched.copyFields()
        var densityDifference = 0.0
        var velocityDifference = 0.0
        for index in singleFields.density.indices {
            densityDifference = max(
                densityDifference,
                abs(Double(
                    singleFields.density[index]
                        - batchedFields.density[index]
                ))
            )
            let delta = singleFields.velocity[index]
                - batchedFields.velocity[index]
            velocityDifference = max(
                velocityDifference,
                Double(max(abs(delta.x), max(abs(delta.y), abs(delta.z))))
            )
        }
        let forceDelta = singleLoad.forceNewtons - batchedLoad.forceNewtons
        let torqueDelta = singleLoad.torqueNewtonMeters
            - batchedLoad.torqueNewtonMeters
        let loadDifference = Double(max(
            max(abs(forceDelta.x), max(abs(forceDelta.y), abs(forceDelta.z))),
            max(abs(torqueDelta.x), max(abs(torqueDelta.y), abs(torqueDelta.z)))
        ))
        return BatchDifference(
            density: densityDifference,
            velocity: velocityDifference,
            force: loadDifference
        )
    }

    static func archiveFields(
        directory: URL,
        result: MetalWingCaseResult,
        density: [Float],
        velocity: [SIMD3<Float>]
    ) throws {
        let stem = "wing-n\(result.resolution)-step\(result.steps)"
        try littleEndianFloatData(density).write(
            to: directory.appendingPathComponent("\(stem)-density.f32le"),
            options: .atomic
        )
        let interleaved = velocity.flatMap { [$0.x, $0.y, $0.z] }
        try littleEndianFloatData(interleaved).write(
            to: directory.appendingPathComponent("\(stem)-velocity.xyz.f32le"),
            options: .atomic
        )
    }

    static func archiveReport(
        _ report: MetalWingValidationReport,
        directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: directory.appendingPathComponent("report.json"),
            options: .atomic
        )
        let format = """
        BirdFlowMetal fixed-wing archive schema 1
        Density files: little-endian Float32, one value per cell.
        Velocity files: little-endian Float32 triples (x,y,z) per cell.
        Cell order: x + Nx * (y + Ny * z), with x varying fastest.
        Fields are captured at U*t/c=13. Metrics, source interpretation,
        voxel-surface thickness, compact-domain limitation, and gates are in report.json.
        """
        try format.write(
            to: directory.appendingPathComponent("FORMAT.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func archiveSingleCaseMetadata(
        _ result: MetalWingCaseResult,
        directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(result).write(
            to: directory.appendingPathComponent("case.json"),
            options: .atomic
        )
        let format = """
        BirdFlowMetal fixed-wing single-case diagnostic
        case.json contains grid, load, symmetry, and source-reference metrics.
        Density files: little-endian Float32, one value per cell.
        Velocity files: little-endian Float32 triples (x,y,z) per cell.
        Cell order: x + Nx * (y + Ny * z), with x varying fastest.
        A single case has no refinement verdict; use `validate wing` without
        `--single-resolution` for an accepted validation report.
        """
        try format.write(
            to: directory.appendingPathComponent("FORMAT.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func littleEndianFloatData(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * MemoryLayout<UInt32>.stride)
        for value in values {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        return data
    }
}
#endif

import BirdFlowCore
import Foundation

public enum MetalSphereValidationError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid Metal sphere validation request: \(message)"
        case .failed(let message):
            return "Metal sphere validation failed: \(message)"
        }
    }
}

public struct MetalSphereCaseResult: Codable, Sendable {
    public let resolution: Int
    public let crossflowResolution: Int
    public let diameterCells: Int
    public let latticeViscosity: Double
    public let tauPlus: Double
    public let steps: Int
    public let sphereConvectiveTimes: Double
    public let reachedSteadyState: Bool
    public let steadyWindowRelativeRange: Double
    public let dragCoefficient: Double
    public let referenceDragCoefficient: Double
    public let relativeDragError: Double
    public let sideForceToDragRatio: Double
    public let torqueToDragDiameterRatio: Double
    public let normalizedVelocitySymmetryError: Double
    public let forceX: Double
    public let forceY: Double
    public let forceZ: Double
    public let torqueX: Double
    public let torqueY: Double
    public let torqueZ: Double
}

public struct MetalSphereValidationReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let passed: Bool
    public let reynoldsNumber: Double
    public let latticeFarFieldSpeed: Double
    public let domainLengthDiameters: Double
    public let domainCrossflowDiameters: Double
    public let referenceDragCoefficient: Double
    public let referenceDescription: String
    public let relativeFinestTwoDragChange: Double
    public let maximumBatchDensityDifference: Double
    public let maximumBatchVelocityDifference: Double
    public let maximumBatchForceDifference: Double
    public let maximumAllowedFinestDragError: Double
    public let maximumAllowedFinestTwoDragChange: Double
    public let maximumAllowedSteadyWindowRange: Double
    public let maximumAllowedSideForceRatio: Double
    public let maximumAllowedTorqueRatio: Double
    public let maximumAllowedVelocitySymmetryError: Double
    public let maximumAllowedBatchDifference: Double
    public let cases: [MetalSphereCaseResult]
}

/// Compact production-kernel external-flow gate. The absolute drag reference
/// comes from a substantially wider and better resolved DNS, so this harness
/// is deliberately an engineering regression test rather than a claim of
/// publication-grade sphere-drag accuracy.
public enum MetalSphereValidator {
    public static let reynoldsNumber: Float = 100
    public static let latticeFarFieldSpeed: Float = 0.04
    public static let domainLengthDiameters = 10.0
    public static let domainCrossflowDiameters = 6.0
    public static let referenceDragCoefficient = 1.09
    public static let maximumFinestDragError = 0.15
    public static let maximumFinestTwoDragChange = 0.03
    public static let maximumSteadyWindowRange = 0.01
    public static let maximumSideForceRatio = 1.0e-3
    public static let maximumTorqueRatio = 1.0e-3
    public static let maximumVelocitySymmetryError = 1.0e-3
    public static let maximumBatchDifference = 1.0e-7
    public static let referenceDescription =
        "Bagchi and Balachandar (JFM 2002), uniform-flow sphere at Re=100: Cd=1.09; compact BirdFlow gate uses a 10D x 6D x 6D domain"

    public static func run(
        finestResolution: Int = 160,
        archiveDirectory: URL? = nil
    ) throws -> MetalSphereValidationReport {
        guard finestResolution >= 160,
              finestResolution.isMultiple(of: 40) else {
            throw MetalSphereValidationError.invalidRequest(
                "finest streamwise resolution must be a multiple of 40 and at least 160 so the 10D x 6D x 6D refinement ladder retains an integer sphere diameter of at least 8 cells"
            )
        }
        let finestDiameter = finestResolution / Int(domainLengthDiameters)
        let finestCrossflow = finestDiameter
            * Int(domainCrossflowDiameters)
        do {
            _ = try GridSize(
                x: finestResolution,
                y: finestCrossflow,
                z: finestCrossflow
            )
        } catch {
            throw MetalSphereValidationError.invalidRequest(
                "finest resolution exceeds the supported grid range"
            )
        }

#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let resolutions = [
            finestResolution / 2,
            finestResolution * 3 / 4,
            finestResolution,
        ]
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
        }

        var results: [MetalSphereCaseResult] = []
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
        let finestTwoChange = abs(
            finest.dragCoefficient - nextFinest.dragCoefficient
        ) / max(abs(finest.dragCoefficient), 1.0e-30)
        let finiteResults = results.allSatisfy {
            $0.dragCoefficient.isFinite
                && $0.steadyWindowRelativeRange.isFinite
                && $0.sideForceToDragRatio.isFinite
                && $0.torqueToDragDiameterRatio.isFinite
                && $0.normalizedVelocitySymmetryError.isFinite
        }
        let passed = finiteResults
            && results.allSatisfy {
                $0.reachedSteadyState
                    && $0.steadyWindowRelativeRange
                        <= maximumSteadyWindowRange
                    && $0.sideForceToDragRatio <= maximumSideForceRatio
                    && $0.torqueToDragDiameterRatio <= maximumTorqueRatio
                    && $0.normalizedVelocitySymmetryError
                        <= maximumVelocitySymmetryError
            }
            && finest.relativeDragError <= maximumFinestDragError
            && finestTwoChange <= maximumFinestTwoDragChange
            && batch.density <= maximumBatchDifference
            && batch.velocity <= maximumBatchDifference
            && batch.force <= maximumBatchDifference

        let report = MetalSphereValidationReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            passed: passed,
            reynoldsNumber: Double(reynoldsNumber),
            latticeFarFieldSpeed: Double(latticeFarFieldSpeed),
            domainLengthDiameters: domainLengthDiameters,
            domainCrossflowDiameters: domainCrossflowDiameters,
            referenceDragCoefficient: referenceDragCoefficient,
            referenceDescription: referenceDescription,
            relativeFinestTwoDragChange: finestTwoChange,
            maximumBatchDensityDifference: batch.density,
            maximumBatchVelocityDifference: batch.velocity,
            maximumBatchForceDifference: batch.force,
            maximumAllowedFinestDragError: maximumFinestDragError,
            maximumAllowedFinestTwoDragChange:
                maximumFinestTwoDragChange,
            maximumAllowedSteadyWindowRange: maximumSteadyWindowRange,
            maximumAllowedSideForceRatio: maximumSideForceRatio,
            maximumAllowedTorqueRatio: maximumTorqueRatio,
            maximumAllowedVelocitySymmetryError:
                maximumVelocitySymmetryError,
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

private extension MetalSphereValidator {
    struct CaseArtifact {
        let result: MetalSphereCaseResult
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
        let diameter = resolution / Int(domainLengthDiameters)
        let crossflowResolution = diameter * Int(domainCrossflowDiameters)
        let grid = try GridSize(
            x: resolution,
            y: crossflowResolution,
            z: crossflowResolution
        )
        let bodyCenter = SIMD3<Float>(
            0.3 * Float(resolution),
            0.5 * Float(crossflowResolution),
            0.5 * Float(crossflowResolution)
        )
        let simulation = try MetalStaticCanonicalSimulation(
            backend: backend,
            grid: grid,
            characteristicLengthCells: diameter,
            latticeReferenceSpeed: latticeFarFieldSpeed,
            targetReynoldsNumber: reynoldsNumber,
            farFieldVelocityMetersPerSecond: SIMD3<Float>(
                latticeFarFieldSpeed,
                0,
                0
            ),
            spongeWidthCells: max(4, diameter / 2),
            spongeStrength: 0.04,
            bodyPositionMeters: bodyCenter,
            caseParameters: SIMD4<Float>(0.5 * Float(diameter), 0.3, 1, 0),
            initializationPipeline: try backend.pipeline(
                named: "initializeSphereCase"
            ),
            initializationLabel: "Initialize fixed sphere in uniform flow"
        )
        // Four diameter-scaled lattice steps give a fixed 0.16 D/U sampling
        // interval at U=0.04 on every refinement level.
        let blockSteps = 4 * diameter
        let minimumSteps = alignedStepCount(
            3 * Double(diameter) / Double(latticeFarFieldSpeed),
            block: blockSteps
        )
        let maximumSteps = alignedStepCount(
            12 * Double(diameter) / Double(latticeFarFieldSpeed),
            block: blockSteps
        )
        let windowCount = 8
        var samples: [ForceTorque] = []
        var steps = 0
        var relativeRange = Double.infinity
        var steady = false

        while steps < maximumSteps {
            let load = try simulation.advance(
                steps: min(blockSteps, maximumSteps - steps),
                batchSize: blockSteps
            )
            steps += min(blockSteps, maximumSteps - steps)
            samples.append(load)
            if samples.count > windowCount {
                samples.removeFirst(samples.count - windowCount)
            }
            if steps >= minimumSteps, samples.count == windowCount {
                let coefficients = samples.map {
                    dragCoefficient(
                        forceX: Double($0.forceNewtons.x),
                        diameter: Double(diameter)
                    )
                }
                relativeRange = sampleRelativeRange(coefficients)
                if relativeRange <= maximumSteadyWindowRange {
                    steady = true
                    break
                }
            }
        }

        let averagedLoad = average(samples)
        let drag = dragCoefficient(
            forceX: Double(averagedLoad.forceNewtons.x),
            diameter: Double(diameter)
        )
        let fields = simulation.copyFields()
        let force = averagedLoad.forceNewtons
        let torque = averagedLoad.torqueNewtonMeters
        let dragForce = max(abs(Double(force.x)), 1.0e-30)
        let sideRatio = hypot(Double(force.y), Double(force.z)) / dragForce
        let torqueMagnitude = sqrt(
            Double(torque.x) * Double(torque.x)
                + Double(torque.y) * Double(torque.y)
                + Double(torque.z) * Double(torque.z)
        )
        let torqueRatio = torqueMagnitude
            / (dragForce * Double(diameter))
        let symmetry = velocitySymmetryError(
            velocity: fields.velocity,
            gridX: resolution,
            gridY: crossflowResolution,
            gridZ: crossflowResolution
        )
        let result = MetalSphereCaseResult(
            resolution: resolution,
            crossflowResolution: crossflowResolution,
            diameterCells: diameter,
            latticeViscosity: Double(
                latticeFarFieldSpeed * Float(diameter) / reynoldsNumber
            ),
            tauPlus: Double(
                0.5 + 3 * latticeFarFieldSpeed
                    * Float(diameter) / reynoldsNumber
            ),
            steps: steps,
            sphereConvectiveTimes: Double(steps)
                * Double(latticeFarFieldSpeed) / Double(diameter),
            reachedSteadyState: steady,
            steadyWindowRelativeRange: relativeRange,
            dragCoefficient: drag,
            referenceDragCoefficient: referenceDragCoefficient,
            relativeDragError: abs(drag - referenceDragCoefficient)
                / referenceDragCoefficient,
            sideForceToDragRatio: sideRatio,
            torqueToDragDiameterRatio: torqueRatio,
            normalizedVelocitySymmetryError: symmetry,
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

    static func alignedStepCount(_ value: Double, block: Int) -> Int {
        Int(ceil(value / Double(block))) * block
    }

    static func dragCoefficient(forceX: Double, diameter: Double) -> Double {
        let area = Double.pi * diameter * diameter / 4
        let dynamicPressure = 0.5
            * Double(latticeFarFieldSpeed)
            * Double(latticeFarFieldSpeed)
        return forceX / (dynamicPressure * area)
    }

    static func sampleRelativeRange(_ samples: [Double]) -> Double {
        guard let minimum = samples.min(), let maximum = samples.max() else {
            return .infinity
        }
        let mean = samples.reduce(0, +) / Double(samples.count)
        return (maximum - minimum) / max(abs(mean), 1.0e-30)
    }

    static func average(_ samples: [ForceTorque]) -> ForceTorque {
        guard !samples.isEmpty else { return ForceTorque() }
        var force = SIMD3<Float>.zero
        var torque = SIMD3<Float>.zero
        for sample in samples {
            force += sample.forceNewtons
            torque += sample.torqueNewtonMeters
        }
        let divisor = Float(samples.count)
        return ForceTorque(
            forceNewtons: force / divisor,
            torqueNewtonMeters: torque / divisor
        )
    }

    static func velocitySymmetryError(
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
                let mirrorY = gridY - 1 - y
                for x in 0..<gridX {
                    let value = velocity[index(x, y, z)]
                    let yValue = velocity[index(x, mirrorY, z)]
                    let zValue = velocity[index(x, y, mirrorZ)]
                    let yDifference = SIMD3<Double>(
                        Double(value.x - yValue.x),
                        Double(value.y + yValue.y),
                        Double(value.z - yValue.z)
                    )
                    let zDifference = SIMD3<Double>(
                        Double(value.x - zValue.x),
                        Double(value.y - zValue.y),
                        Double(value.z + zValue.z)
                    )
                    squaredError += yDifference.x * yDifference.x
                        + yDifference.y * yDifference.y
                        + yDifference.z * yDifference.z
                        + zDifference.x * zDifference.x
                        + zDifference.y * zDifference.y
                        + zDifference.z * zDifference.z
                    componentCount += 6
                }
            }
        }
        return sqrt(squaredError / Double(componentCount))
            / Double(latticeFarFieldSpeed)
    }

    static func batchDifference(backend: MetalBackend) throws -> BatchDifference {
        let diameter = 8
        let streamwiseResolution = diameter * Int(domainLengthDiameters)
        let crossflowResolution = diameter * Int(domainCrossflowDiameters)
        let grid = try GridSize(
            x: streamwiseResolution,
            y: crossflowResolution,
            z: crossflowResolution
        )
        let bodyCenter = SIMD3<Float>(
            0.3 * Float(streamwiseResolution),
            0.5 * Float(crossflowResolution),
            0.5 * Float(crossflowResolution)
        )
        let initializationPipeline = try backend.pipeline(
            named: "initializeSphereCase"
        )
        let single = try MetalStaticCanonicalSimulation(
            backend: backend,
            grid: grid,
            characteristicLengthCells: diameter,
            latticeReferenceSpeed: latticeFarFieldSpeed,
            targetReynoldsNumber: reynoldsNumber,
            farFieldVelocityMetersPerSecond: SIMD3<Float>(
                latticeFarFieldSpeed,
                0,
                0
            ),
            spongeWidthCells: max(4, diameter / 2),
            spongeStrength: 0.04,
            bodyPositionMeters: bodyCenter,
            caseParameters: SIMD4<Float>(0.5 * Float(diameter), 0.3, 1, 0),
            initializationPipeline: initializationPipeline,
            initializationLabel: "Initialize fixed sphere in uniform flow"
        )
        let batched = try MetalStaticCanonicalSimulation(
            backend: backend,
            grid: grid,
            characteristicLengthCells: diameter,
            latticeReferenceSpeed: latticeFarFieldSpeed,
            targetReynoldsNumber: reynoldsNumber,
            farFieldVelocityMetersPerSecond: SIMD3<Float>(
                latticeFarFieldSpeed,
                0,
                0
            ),
            spongeWidthCells: max(4, diameter / 2),
            spongeStrength: 0.04,
            bodyPositionMeters: bodyCenter,
            caseParameters: SIMD4<Float>(0.5 * Float(diameter), 0.3, 1, 0),
            initializationPipeline: initializationPipeline,
            initializationLabel: "Initialize fixed sphere in uniform flow"
        )
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
        result: MetalSphereCaseResult,
        density: [Float],
        velocity: [SIMD3<Float>]
    ) throws {
        let stem = "sphere-n\(result.resolution)-step\(result.steps)"
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
        _ report: MetalSphereValidationReport,
        directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: directory.appendingPathComponent("report.json"),
            options: .atomic
        )
        let format = """
        BirdFlowMetal fixed-sphere archive schema 1
        Density files: little-endian Float32, one value per cell.
        Velocity files: little-endian Float32 triples (x,y,z) per cell.
        Cell order: x + Nx * (y + Ny * z), with x varying fastest.
        Fields are captured at the final steady-window sample. Metrics, the
        published reference, compact-domain limitation, and gates are in report.json.
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

final class MetalStaticCanonicalSimulation {
    private let backend: MetalBackend
    private let configuration: SimulationConfiguration
    private let caseParameters: SIMD4<Float>
    private let initializationLabel: String
    private let initializationPipeline: MTLComputePipelineState
    private let fluidStepPipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidMaskA: MTLBuffer
    private let solidMaskB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let bodyState: MTLBuffer
    private let partialLoadCount: Int
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var lastLoadBuffer: MTLBuffer
    private var stepIndex = 0

    init(
        backend: MetalBackend,
        grid: GridSize,
        characteristicLengthCells: Int,
        latticeReferenceSpeed: Float,
        targetReynoldsNumber: Float,
        farFieldVelocityMetersPerSecond: SIMD3<Float>,
        spongeWidthCells: Int,
        spongeStrength: Float,
        bodyPositionMeters: SIMD3<Float>,
        caseParameters: SIMD4<Float>,
        initializationPipeline: MTLComputePipelineState,
        initializationLabel: String
    ) throws {
        self.backend = backend
        self.caseParameters = caseParameters
        self.initializationLabel = initializationLabel
        let scaling = try LatticeScaling(
            characteristicLengthMeters: Float(characteristicLengthCells),
            characteristicLengthCells: characteristicLengthCells,
            referenceSpeedMetersPerSecond: latticeReferenceSpeed,
            targetReynoldsNumber: targetReynoldsNumber,
            physicalAirDensity: 1,
            latticeReferenceSpeed: latticeReferenceSpeed
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: farFieldVelocityMetersPerSecond,
            spongeWidthCells: spongeWidthCells,
            spongeStrength: spongeStrength,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        self.initializationPipeline = initializationPipeline
        fluidStepPipeline = try backend.pipeline(named: "stepFluidTRT")
        reductionPipeline = try backend.pipeline(named: "reduceForceTorque")

        let cellCount = grid.cellCount
        let populationBytes = D3Q19.count
            * cellCount
            * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let wallBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        partialLoadCount = max(1, (cellCount + 255) / 256)
        let reductionBytes = partialLoadCount
            * MemoryLayout<GPUForceTorque>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            populationBytes, populationBytes,
            maskBytes, maskBytes, wallBytes,
            densityBytes, velocityBytes,
            reductionBytes, reductionBytes,
            MemoryLayout<GPUBirdBodyState>.stride,
        ])
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidMaskA = try backend.makePrivateBuffer(length: maskBytes)
        solidMaskB = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(length: wallBytes)
        density = try backend.makeSharedBuffer(length: densityBytes)
        velocity = try backend.makeSharedBuffer(length: velocityBytes)
        reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(
                BirdBodyState(positionMeters: bodyPositionMeters)
            )
        )
        currentPopulations = populationsA
        nextPopulations = populationsB
        lastLoadBuffer = reductionA

        try encodeCanonicalInitialization()
    }

    func advance(steps: Int, batchSize: Int) throws -> ForceTorque {
        guard steps >= 0, batchSize > 0 else {
            throw BirdFlowError.invalidAdvanceRequest(
                steps: steps,
                batchSize: batchSize
            )
        }
        var remaining = steps
        while remaining > 0 {
            let count = min(batchSize, remaining)
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create static-canonical command buffer."
                )
            }
            for localStep in 0..<count {
                var uniforms = makeUniforms(
                    time: Float(stepIndex + localStep + 1),
                    capture: remaining == count && localStep == count - 1
                )
                try encodeCanonicalFluidStep(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                swap(&currentPopulations, &nextPopulations)
                if remaining == count && localStep == count - 1 {
                    lastLoadBuffer = try encodeCanonicalReduction(
                        commandBuffer: commandBuffer
                    )
                }
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            stepIndex += count
            remaining -= count
        }
        return lastLoadBuffer.contents()
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

    private func makeUniforms(time: Float, capture: Bool) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: time,
            captureMacroscopicFields: capture,
            accumulateLoads: capture,
            periodicBoundaries: false,
            caseParameters: caseParameters
        )
    }

    private func encodeCanonicalInitialization() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create static-canonical initialization encoder."
            )
        }
        var uniforms = makeUniforms(time: 0, capture: true)
        encoder.label = initializationLabel
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(solidMaskA, offset: 0, index: 1)
        encoder.setBuffer(solidMaskB, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(density, offset: 0, index: 4)
        encoder.setBuffer(velocity, offset: 0, index: 5)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 6
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: initializationPipeline,
            count: configuration.grid.cellCount
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
    }

    private func encodeCanonicalFluidStep(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create static-canonical fluid encoder."
            )
        }
        encoder.label = "Production D3Q19 TRT static canonical body"
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(solidMaskA, offset: 0, index: 2)
        encoder.setBuffer(solidMaskB, offset: 0, index: 3)
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
            pipeline: fluidStepPipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func encodeCanonicalReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        var input = reductionA
        var output = reductionB
        var inputCount = partialLoadCount
        while inputCount > 1 {
            let outputCount = (inputCount + 255) / 256
            var count32 = UInt32(inputCount)
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create static-canonical load reduction encoder."
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
            inputCount = outputCount
            input = output
            output = output === reductionA ? reductionB : reductionA
        }
        return input
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Unknown Metal static-canonical error"
            )
        }
    }
}
#endif

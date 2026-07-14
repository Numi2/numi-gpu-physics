import BirdFlowCore
import Foundation

public enum MetalShearWaveValidationError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid Metal shear-wave validation request: \(message)"
        case .failed(let message):
            return "Metal shear-wave validation failed: \(message)"
        }
    }
}

public struct MetalShearWaveCaseResult: Codable, Sendable {
    public let resolution: Int
    public let steps: Int
    public let viscosity: Double
    public let tauPlus: Double
    public let tauMinus: Double
    public let initialAmplitude: Double
    public let measuredAmplitude: Double
    public let analyticAmplitude: Double
    public let relativeDecayError: Double
    public let relativeMassDrift: Double
}

public struct MetalShearWaveValidationReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let passed: Bool
    public let maximumAllowedDecayError: Double
    public let maximumAllowedMassDrift: Double
    public let minimumRequiredConvergenceOrder: Double
    public let maximumAllowedCPUReferenceDifference: Double
    public let maximumAllowedBatchDifference: Double
    public let estimatedOrder: Double
    public let maximumRelativeMassDrift: Double
    public let finestRelativeDecayError: Double
    public let referenceComparisonSteps: Int
    public let maximumPopulationDifferenceFromCPU: Double
    public let maximumBatchDensityDifference: Double
    public let maximumBatchVelocityDifference: Double
    public let cases: [MetalShearWaveCaseResult]
}

/// Canonical periodic shear-wave validation for the production Metal fluid
/// kernel. This is intentionally independent of the articulated geometry path:
/// all cells are fluid, sponge strength is zero, and `stepFluidTRT` performs
/// periodic pull streaming followed by the normal TRT collision.
public enum MetalShearWaveValidator {
    public static let maximumDecayError = 0.03
    // This measures the actual Float population field after 120 production
    // kernel steps. Five parts per million is a strict single-precision gate;
    // the independent Float64 reference retains its 1e-6 gate.
    public static let maximumMassDrift = 5.0e-6
    public static let minimumConvergenceOrder = 1.8
    public static let maximumCPUReferenceDifference = 5.0e-6
    public static let maximumBatchDifference = 1.0e-7

    public static func run(
        finestResolution: Int = 32,
        finestSteps: Int = 120,
        viscosity: Float = 0.03,
        initialAmplitude: Float = 0.01,
        archiveDirectory: URL? = nil
    ) throws -> MetalShearWaveValidationReport {
        guard finestResolution >= 32 else {
            throw MetalShearWaveValidationError.invalidRequest(
                "the finest resolution must be at least 32 cells"
            )
        }
        guard finestSteps >= 16 else {
            throw MetalShearWaveValidationError.invalidRequest(
                "the finest-grid step count must be at least 16"
            )
        }
        guard viscosity > 0, viscosity.isFinite else {
            throw MetalShearWaveValidationError.invalidRequest(
                "viscosity must be finite and positive"
            )
        }
        guard initialAmplitude > 0,
              initialAmplitude.isFinite,
              initialAmplitude / D3Q19.soundSpeed <= 0.15 else {
            throw MetalShearWaveValidationError.invalidRequest(
                "amplitude must be finite, positive, and at or below Mach 0.15"
            )
        }

#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let threeQuarterResolution = finestResolution
            - finestResolution / 4
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
        }
        let resolutions = Array(Set([
            finestResolution / 2,
            threeQuarterResolution,
            finestResolution,
        ].map { max(16, $0) })).sorted()
        guard resolutions.count >= 3 else {
            throw MetalShearWaveValidationError.invalidRequest(
                "the requested refinement ladder does not contain three grids"
            )
        }

        var cases: [MetalShearWaveCaseResult] = []
        for resolution in resolutions {
            let scale = Double(resolution) / Double(finestResolution)
            let steps = max(1, Int((Double(finestSteps) * scale * scale).rounded()))
            let run = try runCase(
                backend: backend,
                resolution: resolution,
                steps: steps,
                viscosity: viscosity,
                initialAmplitude: initialAmplitude
            )
            cases.append(run.result)
            if let archiveDirectory {
                try archiveFields(
                    directory: archiveDirectory,
                    result: run.result,
                    density: run.density,
                    velocity: run.velocity
                )
            }
        }

        let order = estimatedConvergenceOrder(cases)
        let observedMaximumMassDrift = cases.map(\.relativeMassDrift).max()
            ?? .infinity
        let finestDecayError = cases.last?.relativeDecayError ?? .infinity
        let comparison = try compareWithCPUAndBatchPartitions(
            backend: backend,
            resolution: resolutions[0],
            steps: 8,
            viscosity: viscosity,
            initialAmplitude: initialAmplitude
        )

        let finite = order.isFinite
            && observedMaximumMassDrift.isFinite
            && finestDecayError.isFinite
            && comparison.maximumPopulationDifference.isFinite
            && comparison.maximumBatchDensityDifference.isFinite
            && comparison.maximumBatchVelocityDifference.isFinite
        let passed = finite
            && finestDecayError < maximumDecayError
            && observedMaximumMassDrift < Self.maximumMassDrift
            && order >= minimumConvergenceOrder
            && comparison.maximumPopulationDifference
                < maximumCPUReferenceDifference
            && comparison.maximumBatchDensityDifference < maximumBatchDifference
            && comparison.maximumBatchVelocityDifference < maximumBatchDifference

        let report = MetalShearWaveValidationReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            passed: passed,
            maximumAllowedDecayError: maximumDecayError,
            maximumAllowedMassDrift: maximumMassDrift,
            minimumRequiredConvergenceOrder: minimumConvergenceOrder,
            maximumAllowedCPUReferenceDifference:
                maximumCPUReferenceDifference,
            maximumAllowedBatchDifference: maximumBatchDifference,
            estimatedOrder: order,
            maximumRelativeMassDrift: observedMaximumMassDrift,
            finestRelativeDecayError: finestDecayError,
            referenceComparisonSteps: 8,
            maximumPopulationDifferenceFromCPU:
                comparison.maximumPopulationDifference,
            maximumBatchDensityDifference:
                comparison.maximumBatchDensityDifference,
            maximumBatchVelocityDifference:
                comparison.maximumBatchVelocityDifference,
            cases: cases
        )
        if let archiveDirectory {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(report).write(
                to: archiveDirectory.appendingPathComponent("report.json"),
                options: .atomic
            )
            let format = """
            BirdFlowMetal shear-wave archive schema 1
            Density files: little-endian Float32, one value per cell.
            Velocity files: little-endian Float32 triples (x,y,z) per cell.
            Cell order: x + N * (y + N * z), with x varying fastest.
            Each field is the final post-collision production-kernel state.
            Case parameters, errors, gates, device, and pass/fail are in report.json.
            """
            try format.write(
                to: archiveDirectory.appendingPathComponent("FORMAT.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
        return report
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

#if canImport(Metal)
import Metal

private extension MetalShearWaveValidator {
    struct Comparison {
        let maximumPopulationDifference: Double
        let maximumBatchDensityDifference: Double
        let maximumBatchVelocityDifference: Double
    }

    static func runCase(
        backend: MetalBackend,
        resolution: Int,
        steps: Int,
        viscosity: Float,
        initialAmplitude: Float
    ) throws -> (
        result: MetalShearWaveCaseResult,
        density: [Float],
        velocity: [SIMD3<Float>]
    ) {
        let simulation = try MetalShearWaveSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            initialAmplitude: initialAmplitude
        )
        let initial = simulation.copyFields()
        let initialMass = try totalPopulationMass(simulation.copyPopulations())
        let measuredInitialAmplitude = modeAmplitude(
            velocity: initial.velocity,
            resolution: resolution
        )

        try simulation.advance(steps: steps, batchSize: min(32, steps))
        let final = simulation.copyFields()
        let finalMass = try totalPopulationMass(simulation.copyPopulations())
        let measuredAmplitude = modeAmplitude(
            velocity: final.velocity,
            resolution: resolution
        )
        let waveNumber = 2 * Double.pi / Double(resolution)
        let analyticAmplitude = measuredInitialAmplitude * exp(
            -Double(viscosity) * waveNumber * waveNumber * Double(steps)
        )
        let decayError = abs(measuredAmplitude - analyticAmplitude)
            / abs(analyticAmplitude)
        let massDrift = abs(finalMass - initialMass) / abs(initialMass)
        let tauPlus = 0.5 + 3 * Double(viscosity)
        let tauMinus = 0.5 + (3.0 / 16.0) / (tauPlus - 0.5)

        let result = MetalShearWaveCaseResult(
            resolution: resolution,
            steps: steps,
            viscosity: Double(viscosity),
            tauPlus: tauPlus,
            tauMinus: tauMinus,
            initialAmplitude: measuredInitialAmplitude,
            measuredAmplitude: measuredAmplitude,
            analyticAmplitude: analyticAmplitude,
            relativeDecayError: decayError,
            relativeMassDrift: massDrift
        )
        return (result, final.density, final.velocity)
    }

    static func compareWithCPUAndBatchPartitions(
        backend: MetalBackend,
        resolution: Int,
        steps: Int,
        viscosity: Float,
        initialAmplitude: Float
    ) throws -> Comparison {
        let stepwise = try MetalShearWaveSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            initialAmplitude: initialAmplitude
        )
        let batched = try MetalShearWaveSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            initialAmplitude: initialAmplitude
        )
        var cpu = CPUShearWaveReference(
            resolution: resolution,
            viscosity: viscosity,
            initialAmplitude: initialAmplitude
        )
        var maximumPopulationDifference = 0.0
        for _ in 0..<steps {
            cpu.advance()
            try stepwise.advance(steps: 1, batchSize: 1)
            let gpu = try stepwise.copyPopulations()
            for index in gpu.indices {
                maximumPopulationDifference = max(
                    maximumPopulationDifference,
                    Double(abs(gpu[index] - cpu.populations[index]))
                )
            }
        }

        try batched.advance(steps: steps, batchSize: steps)
        let stepwiseFields = stepwise.copyFields()
        let batchedFields = batched.copyFields()
        var maximumDensityDifference = 0.0
        var maximumVelocityDifference = 0.0
        for index in stepwiseFields.density.indices {
            maximumDensityDifference = max(
                maximumDensityDifference,
                Double(abs(
                    stepwiseFields.density[index]
                        - batchedFields.density[index]
                ))
            )
            let difference = stepwiseFields.velocity[index]
                - batchedFields.velocity[index]
            maximumVelocityDifference = max(
                maximumVelocityDifference,
                Double(vectorLength(difference))
            )
        }

        return Comparison(
            maximumPopulationDifference: maximumPopulationDifference,
            maximumBatchDensityDifference: maximumDensityDifference,
            maximumBatchVelocityDifference: maximumVelocityDifference
        )
    }

    static func totalPopulationMass(_ populations: [Float]) throws -> Double {
        let mass = populations.reduce(0) { $0 + Double($1) }
        guard mass.isFinite, mass > 0 else {
            throw MetalShearWaveValidationError.failed(
                "the production population field has invalid total mass"
            )
        }
        return mass
    }

    static func modeAmplitude(
        velocity: [SIMD3<Float>],
        resolution: Int
    ) -> Double {
        var projection = 0.0
        let plane = resolution * resolution
        for index in velocity.indices {
            let y = (index % plane) / resolution
            let sine = sin(2 * Double.pi * Double(y) / Double(resolution))
            projection += Double(velocity[index].x) * sine
        }
        return 2 * projection / Double(resolution * resolution * resolution)
    }

    static func estimatedConvergenceOrder(
        _ cases: [MetalShearWaveCaseResult]
    ) -> Double {
        let x = cases.map { log(1 / Double($0.resolution)) }
        let y = cases.map { log(max($0.relativeDecayError, 1.0e-30)) }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        var numerator = 0.0
        var denominator = 0.0
        for index in x.indices {
            numerator += (x[index] - meanX) * (y[index] - meanY)
            denominator += (x[index] - meanX) * (x[index] - meanX)
        }
        return numerator / denominator
    }

    static func archiveFields(
        directory: URL,
        result: MetalShearWaveCaseResult,
        density: [Float],
        velocity: [SIMD3<Float>]
    ) throws {
        let stem = "n\(result.resolution)-step\(result.steps)"
        try littleEndianFloatData(density).write(
            to: directory.appendingPathComponent("\(stem)-density.f32le"),
            options: .atomic
        )
        let interleavedVelocity = velocity.flatMap { [$0.x, $0.y, $0.z] }
        try littleEndianFloatData(interleavedVelocity).write(
            to: directory.appendingPathComponent("\(stem)-velocity.xyz.f32le"),
            options: .atomic
        )
    }

    static func littleEndianFloatData(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * MemoryLayout<UInt32>.stride)
        for value in values {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        return data
    }
}

private final class MetalShearWaveSimulation {
    private let backend: MetalBackend
    private let configuration: SimulationConfiguration
    private let initialAmplitude: Float
    private let initializationPipeline: MTLComputePipelineState
    private let fluidStepPipeline: MTLComputePipelineState
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidMaskA: MTLBuffer
    private let solidMaskB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let partialLoads: MTLBuffer
    private let bodyState: MTLBuffer
    private let populationReadback: MTLBuffer
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer

    init(
        backend: MetalBackend,
        resolution: Int,
        viscosity: Float,
        initialAmplitude: Float
    ) throws {
        self.backend = backend
        self.initialAmplitude = initialAmplitude
        let grid = try GridSize(x: resolution, y: resolution, z: resolution)
        let scaling = try LatticeScaling(
            characteristicLengthMeters: Float(resolution),
            characteristicLengthCells: resolution,
            referenceSpeedMetersPerSecond: initialAmplitude,
            targetReynoldsNumber:
                initialAmplitude * Float(resolution) / viscosity,
            physicalAirDensity: 1,
            latticeReferenceSpeed: initialAmplitude
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: 4,
            spongeStrength: 0,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        initializationPipeline = try backend.pipeline(named: "initializeShearWave")
        fluidStepPipeline = try backend.pipeline(named: "stepFluidTRT")

        let cellCount = grid.cellCount
        let populationBytes = D3Q19.count
            * cellCount
            * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let wallBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let partialCount = max(1, (cellCount + 255) / 256)
        let partialBytes = partialCount * MemoryLayout<GPUForceTorque>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            populationBytes, populationBytes,
            maskBytes, maskBytes, wallBytes,
            densityBytes, velocityBytes, partialBytes,
            MemoryLayout<GPUBirdBodyState>.stride,
            populationBytes,
        ])
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidMaskA = try backend.makePrivateBuffer(length: maskBytes)
        solidMaskB = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(length: wallBytes)
        density = try backend.makeSharedBuffer(length: densityBytes)
        velocity = try backend.makeSharedBuffer(length: velocityBytes)
        partialLoads = try backend.makePrivateBuffer(length: partialBytes)
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: .zero))
        )
        populationReadback = try backend.makeSharedBuffer(length: populationBytes)
        currentPopulations = populationsA
        nextPopulations = populationsB

        try encodeShearInitialization()
    }

    func advance(steps: Int, batchSize: Int) throws {
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
                    "Unable to create shear-wave command buffer."
                )
            }
            for localStep in 0..<count {
                var uniforms = GPUUniforms(
                    configuration: configuration,
                    time: 0,
                    captureMacroscopicFields:
                        remaining == count && localStep == count - 1,
                    periodicBoundaries: true,
                    shearWaveAmplitude: initialAmplitude
                )
                try encodeShearFluidStep(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                swap(&currentPopulations, &nextPopulations)
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            remaining -= count
        }
    }

    func copyFields() -> (density: [Float], velocity: [SIMD3<Float>]) {
        let count = configuration.grid.cellCount
        let densityPointer = density.contents().assumingMemoryBound(to: Float.self)
        let velocityPointer = velocity.contents()
            .assumingMemoryBound(to: SIMD4<Float>.self)
        let densities = Array(
            UnsafeBufferPointer(start: densityPointer, count: count)
        )
        let velocities = (0..<count).map { index in
            let value = velocityPointer[index]
            return SIMD3<Float>(value.x, value.y, value.z)
        }
        return (densities, velocities)
    }

    func copyPopulations() throws -> [Float] {
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create shear-wave population readback."
            )
        }
        encoder.copy(
            from: currentPopulations,
            sourceOffset: 0,
            to: populationReadback,
            destinationOffset: 0,
            size: populationReadback.length
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
        let count = D3Q19.count * configuration.grid.cellCount
        let pointer = populationReadback.contents()
            .assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    private func encodeShearInitialization() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create shear-wave initialization command buffer."
            )
        }
        blit.fill(buffer: solidMaskA, range: 0..<solidMaskA.length, value: 0)
        blit.fill(buffer: solidMaskB, range: 0..<solidMaskB.length, value: 0)
        blit.fill(buffer: wallVelocity, range: 0..<wallVelocity.length, value: 0)
        blit.endEncoding()

        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create shear-wave initialization encoder."
            )
        }
        var uniforms = GPUUniforms(
            configuration: configuration,
            time: 0,
            periodicBoundaries: true,
            shearWaveAmplitude: initialAmplitude
        )
        encoder.label = "Initialize periodic shear wave"
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(density, offset: 0, index: 1)
        encoder.setBuffer(velocity, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
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

    private func encodeShearFluidStep(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create shear-wave fluid encoder."
            )
        }
        encoder.label = "Production D3Q19 TRT periodic shear wave"
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(solidMaskA, offset: 0, index: 2)
        encoder.setBuffer(solidMaskB, offset: 0, index: 3)
        encoder.setBuffer(wallVelocity, offset: 0, index: 4)
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
            pipeline: fluidStepPipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Unknown Metal shear-wave error"
            )
        }
    }
}

private struct CPUShearWaveReference {
    let resolution: Int
    let omegaPlus: Float
    let omegaMinus: Float
    var populations: [Float]

    init(
        resolution: Int,
        viscosity: Float,
        initialAmplitude: Float
    ) {
        self.resolution = resolution
        let tauPlus = 0.5 + 3 * viscosity
        let tauMinus = 0.5 + Float(3.0 / 16.0) / (tauPlus - 0.5)
        omegaPlus = 1 / tauPlus
        omegaMinus = 1 / tauMinus
        let cellCount = resolution * resolution * resolution
        populations = Array(
            repeating: 0,
            count: D3Q19.count * cellCount
        )
        for gid in 0..<cellCount {
            let y = (gid % (resolution * resolution)) / resolution
            let phase = 2 * Float.pi * Float(y) / Float(resolution)
            let velocity = SIMD3<Float>(initialAmplitude * sin(phase), 0, 0)
            for q in 0..<D3Q19.count {
                populations[q * cellCount + gid] = D3Q19.equilibrium(
                    direction: q,
                    density: 1,
                    velocity: velocity
                )
            }
        }
    }

    mutating func advance() {
        let cellCount = resolution * resolution * resolution
        let plane = resolution * resolution
        var output = Array(repeating: Float.zero, count: populations.count)
        var streamed = Array(repeating: Float.zero, count: D3Q19.count)
        var equilibrium = Array(repeating: Float.zero, count: D3Q19.count)

        for gid in 0..<cellCount {
            let z = gid / plane
            let remainder = gid - z * plane
            let y = remainder / resolution
            let x = remainder - y * resolution
            var density: Float = 0
            var momentum = SIMD3<Float>.zero
            for q in 0..<D3Q19.count {
                let direction = D3Q19.directions[q]
                let sourceX = (x - Int(direction.x) + resolution) % resolution
                let sourceY = (y - Int(direction.y) + resolution) % resolution
                let sourceZ = (z - Int(direction.z) + resolution) % resolution
                let source = sourceX
                    + resolution * (sourceY + resolution * sourceZ)
                let value = populations[q * cellCount + source]
                streamed[q] = value
                density += value
                momentum += value * SIMD3<Float>(
                    Float(direction.x),
                    Float(direction.y),
                    Float(direction.z)
                )
            }
            density = max(density, 1.0e-8)
            let velocity = momentum / density
            for q in 0..<D3Q19.count {
                equilibrium[q] = D3Q19.equilibrium(
                    direction: q,
                    density: density,
                    velocity: velocity
                )
            }
            for q in 0..<D3Q19.count {
                let opposite = D3Q19.opposite[q]
                let symmetric = 0.5 * (streamed[q] + streamed[opposite])
                let antisymmetric = 0.5 * (streamed[q] - streamed[opposite])
                let equilibriumSymmetric = 0.5
                    * (equilibrium[q] + equilibrium[opposite])
                let equilibriumAntisymmetric = 0.5
                    * (equilibrium[q] - equilibrium[opposite])
                output[q * cellCount + gid] = streamed[q]
                    - omegaPlus * (symmetric - equilibriumSymmetric)
                    - omegaMinus * (antisymmetric - equilibriumAntisymmetric)
            }
        }
        populations = output
    }
}
#endif

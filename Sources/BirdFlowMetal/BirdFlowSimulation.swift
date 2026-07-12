import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal

public final class BirdFlowSimulation {
    public let configuration: SimulationConfiguration
    public let bird: BirdParameters

    private let backend: MetalBackend
    private let birdParametersBuffer: MTLBuffer
    private let bodyStateBuffer: MTLBuffer
    private let preparedGeometryBuffer: MTLBuffer
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidMaskA: MTLBuffer
    private let solidMaskB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let partialLoadCount: Int

    private let buildGeometryPipeline: MTLComputePipelineState
    private let prepareGeometryPipeline: MTLComputePipelineState
    private let initializePipeline: MTLComputePipelineState
    private let fluidStepPipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let integratePipeline: MTLComputePipelineState

    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var currentSolidMask: MTLBuffer
    private var nextSolidMask: MTLBuffer
    private var lastLoadBuffer: MTLBuffer
    private var lastCommandBuffer: MTLCommandBuffer?
    private var terminalFailure: BirdFlowError?

    public private(set) var stepIndex: UInt64 = 0
    public private(set) var timeSeconds: Float = 0

    public init(
        configuration: SimulationConfiguration,
        bird: BirdParameters,
        initialBodyState: BirdBodyState
    ) throws {
        try bird.validate(
            initialBodyState: initialBodyState,
            for: configuration
        )

        self.configuration = configuration
        self.bird = bird
        backend = try MetalBackend(fastMath: configuration.fastMath)

        buildGeometryPipeline = try backend.pipeline(named: "buildBirdGeometry")
        prepareGeometryPipeline = try backend.pipeline(named: "prepareBirdGeometry")
        initializePipeline = try backend.pipeline(named: "initializePopulations")
        fluidStepPipeline = try backend.pipeline(named: "stepFluidTRT")
        reductionPipeline = try backend.pipeline(named: "reduceForceTorque")
        integratePipeline = try backend.pipeline(named: "integrateBirdBody")

        let cellCount = configuration.grid.cellCount
        let populationBytes = D3Q19.count
            * cellCount
            * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let wallVelocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let firstReductionCount = max(1, (cellCount + 255) / 256)
        let reductionBytes = firstReductionCount
            * MemoryLayout<GPUForceTorque>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            MemoryLayout<GPUBirdParameters>.stride,
            MemoryLayout<GPUBirdBodyState>.stride,
            MemoryLayout<GPUPreparedBirdGeometry>.stride,
            populationBytes,
            populationBytes,
            maskBytes,
            maskBytes,
            wallVelocityBytes,
            densityBytes,
            velocityBytes,
            reductionBytes,
            reductionBytes,
        ])
        birdParametersBuffer = try backend.makeSharedBuffer(
            value: GPUBirdParameters(bird)
        )
        bodyStateBuffer = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(initialBodyState)
        )
        preparedGeometryBuffer = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedBirdGeometry>.stride
        )
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidMaskA = try backend.makePrivateBuffer(
            length: maskBytes
        )
        solidMaskB = try backend.makePrivateBuffer(
            length: maskBytes
        )
        wallVelocity = try backend.makePrivateBuffer(
            length: wallVelocityBytes
        )
        density = try backend.makeSharedBuffer(
            length: densityBytes
        )
        velocity = try backend.makeSharedBuffer(
            length: velocityBytes
        )
        partialLoadCount = firstReductionCount
        reductionA = try backend.makeSharedBuffer(
            length: reductionBytes
        )
        reductionB = try backend.makeSharedBuffer(
            length: reductionBytes
        )

        currentPopulations = populationsA
        nextPopulations = populationsB
        currentSolidMask = solidMaskA
        nextSolidMask = solidMaskB
        lastLoadBuffer = reductionA
        terminalFailure = nil

        try encodeInitialization()
    }

    public convenience init(
        configuration: SimulationConfiguration,
        bird: BirdParameters = .demonstration
    ) throws {
        let center = configuration.domainOriginMeters
            + configuration.domainSizeMeters * 0.5
        try self.init(
            configuration: configuration,
            bird: bird,
            initialBodyState: BirdBodyState(positionMeters: center)
        )
    }

    deinit {
        lastCommandBuffer?.waitUntilCompleted()
    }

    /// Advances the coupled GPU state. Geometry, fluid update, load reduction,
    /// and body integration remain on the GPU inside each command-buffer batch.
    public func advance(steps: Int, batchSize: Int = 32) throws {
        guard steps >= 0, batchSize > 0 else {
            throw BirdFlowError.invalidAdvanceRequest(
                steps: steps,
                batchSize: batchSize
            )
        }

        try waitForGPU()

        var remaining = steps
        var encodedSteps = 0
        var submitted: [MTLCommandBuffer] = []
        do {
            while remaining > 0 {
                let count = min(batchSize, remaining)
                let commandBuffer = try encodeBatch(
                    stepCount: count,
                    startStep: stepIndex + UInt64(encodedSteps),
                    captureMacroscopicFields: count == remaining
                )
                submitted.append(commandBuffer)
                encodedSteps += count
                remaining -= count
            }
        }
        catch {
            lastCommandBuffer?.waitUntilCompleted()
            lastCommandBuffer = nil
            throw invalidate(after: error)
        }

        guard let last = submitted.last else { return }
        last.waitUntilCompleted()
        do {
            for commandBuffer in submitted {
                try check(commandBuffer)
            }
        }
        catch {
            lastCommandBuffer = nil
            throw invalidate(after: error)
        }
        lastCommandBuffer = nil

        stepIndex += UInt64(steps)
        timeSeconds = Float(
            Double(stepIndex) * Double(configuration.scaling.timeStepSeconds)
        )
    }

    public func snapshot() throws -> SimulationSnapshot {
        try waitForGPU()

        let state = bodyStateBuffer.contents()
            .assumingMemoryBound(to: GPUBirdBodyState.self)
            .pointee
            .coreValue
        let load = lastLoadBuffer.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
            .pointee
            .coreValue

        return SimulationSnapshot(
            step: stepIndex,
            timeSeconds: timeSeconds,
            body: state,
            aerodynamicLoad: load
        )
    }

    /// Copies current density and velocity fields. This synchronizes the GPU and
    /// is intended for output frames rather than every simulation step.
    public func copyMacroscopicFields() throws -> (
        density: [Float],
        velocity: [SIMD3<Float>]
    ) {
        try waitForGPU()
        let count = configuration.grid.cellCount
        let densityPointer = density.contents().assumingMemoryBound(to: Float.self)
        let velocityPointer = velocity.contents().assumingMemoryBound(to: SIMD4<Float>.self)

        let densities = Array(
            UnsafeBufferPointer(start: densityPointer, count: count)
        )
        let velocities = (0..<count).map { index in
            let value = velocityPointer[index]
            return SIMD3<Float>(value.x, value.y, value.z)
                * configuration.scaling.velocityToPhysical
        }
        return (densities, velocities)
    }

    public func copyGaugePressureFieldPascals() throws -> [Float] {
        try waitForGPU()
        let count = configuration.grid.cellCount
        let pointer = density.contents().assumingMemoryBound(to: Float.self)
        return (0..<count).map { index in
            configuration.scaling.gaugePressurePascals(
                fromLatticeDensity: pointer[index]
            )
        }
    }

    private func encodeInitialization() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create initialization command buffer."
            )
        }

        var uniforms = GPUUniforms(configuration: configuration, time: 0)
        try encodeGeometryPreparation(
            commandBuffer: commandBuffer,
            uniforms: &uniforms
        )
        try encodeGeometry(
            commandBuffer: commandBuffer,
            uniforms: &uniforms,
            targetMask: currentSolidMask
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create initialization encoder."
            )
        }
        encoder.label = "Initialize D3Q19 equilibrium"
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(currentSolidMask, offset: 0, index: 1)
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

    private func encodeBatch(
        stepCount: Int,
        startStep: UInt64,
        captureMacroscopicFields: Bool
    ) throws -> MTLCommandBuffer {
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create simulation command buffer."
            )
        }
        commandBuffer.label = "BirdFlow coupled batch"

        for localStep in 0..<stepCount {
            // `currentSolidMask` represents t_n. Build the target geometry at
            // t_(n+1) so topology changes and wall velocity are synchronized
            // with the fluid step that advances into that state.
            let absoluteStep = startStep + UInt64(localStep + 1)
            let stepTime = Float(
                Double(absoluteStep)
                    * Double(configuration.scaling.timeStepSeconds)
            )
            var uniforms = GPUUniforms(
                configuration: configuration,
                time: stepTime,
                captureMacroscopicFields: captureMacroscopicFields
                    && localStep == stepCount - 1,
                hasPreviousGeometry: true
            )

            try encodeGeometryPreparation(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            try encodeGeometry(
                commandBuffer: commandBuffer,
                uniforms: &uniforms,
                targetMask: nextSolidMask
            )
            try encodeFluidStep(
                commandBuffer: commandBuffer,
                uniforms: &uniforms
            )
            lastLoadBuffer = try encodeReduction(commandBuffer: commandBuffer)
            if configuration.freeFlight {
                try encodeBodyIntegration(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms,
                    loadBuffer: lastLoadBuffer
                )
            }

            swap(&currentPopulations, &nextPopulations)
            swap(&currentSolidMask, &nextSolidMask)
        }

        commandBuffer.commit()
        lastCommandBuffer = commandBuffer
        return commandBuffer
    }

    private func encodeGeometryPreparation(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create geometry-preparation encoder."
            )
        }
        encoder.label = "Prepare articulated bird frame"
        encoder.setBuffer(preparedGeometryBuffer, offset: 0, index: 0)
        encoder.setBuffer(birdParametersBuffer, offset: 0, index: 1)
        encoder.setBuffer(bodyStateBuffer, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: prepareGeometryPipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func encodeGeometry(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        targetMask: MTLBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create geometry encoder."
            )
        }
        encoder.label = "Articulated bird signed-distance boundary"
        encoder.setBuffer(targetMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocity, offset: 0, index: 1)
        encoder.setBuffer(currentSolidMask, offset: 0, index: 2)
        encoder.setBuffer(birdParametersBuffer, offset: 0, index: 3)
        encoder.setBuffer(preparedGeometryBuffer, offset: 0, index: 4)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 5
        )
        backend.dispatch3D(
            encoder: encoder,
            pipeline: buildGeometryPipeline,
            width: configuration.grid.x,
            height: configuration.grid.y,
            depth: configuration.grid.z
        )
        encoder.endEncoding()
    }

    private func encodeFluidStep(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create fluid encoder."
            )
        }
        encoder.label = "D3Q19 TRT stream, boundary, collision"
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(currentSolidMask, offset: 0, index: 2)
        encoder.setBuffer(nextSolidMask, offset: 0, index: 3)
        encoder.setBuffer(wallVelocity, offset: 0, index: 4)
        encoder.setBuffer(density, offset: 0, index: 5)
        encoder.setBuffer(velocity, offset: 0, index: 6)
        encoder.setBuffer(reductionA, offset: 0, index: 7)
        encoder.setBuffer(bodyStateBuffer, offset: 0, index: 8)
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

    private func encodeReduction(
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
                    "Unable to create reduction encoder."
                )
            }
            encoder.label = "Aerodynamic load reduction"
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

    private func encodeBodyIntegration(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms,
        loadBuffer: MTLBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create body-integration encoder."
            )
        }
        encoder.label = "Six-degree-of-freedom bird body"
        encoder.setBuffer(bodyStateBuffer, offset: 0, index: 0)
        encoder.setBuffer(birdParametersBuffer, offset: 0, index: 1)
        encoder.setBuffer(loadBuffer, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: integratePipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func waitForGPU() throws {
        if let terminalFailure {
            throw terminalFailure
        }
        if let commandBuffer = lastCommandBuffer {
            commandBuffer.waitUntilCompleted()
            do {
                try check(commandBuffer)
                lastCommandBuffer = nil
            }
            catch {
                lastCommandBuffer = nil
                throw invalidate(after: error)
            }
        }
    }

    private func invalidate(after error: Error) -> BirdFlowError {
        let failure = BirdFlowError.simulationStateInvalidated(
            String(describing: error)
        )
        terminalFailure = failure
        return failure
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription ?? "Unknown Metal error"
            )
        }
    }
}

#else

public final class BirdFlowSimulation {
    public let configuration: SimulationConfiguration
    public let bird: BirdParameters
    public private(set) var stepIndex: UInt64 = 0
    public private(set) var timeSeconds: Float = 0

    public init(
        configuration: SimulationConfiguration,
        bird: BirdParameters,
        initialBodyState: BirdBodyState
    ) throws {
        try bird.validate(
            initialBodyState: initialBodyState,
            for: configuration
        )
        self.configuration = configuration
        self.bird = bird
        throw BirdFlowError.metalUnavailable
    }

    public convenience init(
        configuration: SimulationConfiguration,
        bird: BirdParameters = .demonstration
    ) throws {
        let center = configuration.domainOriginMeters
            + configuration.domainSizeMeters * 0.5
        try self.init(
            configuration: configuration,
            bird: bird,
            initialBodyState: BirdBodyState(positionMeters: center)
        )
    }

    public func advance(steps: Int, batchSize: Int = 32) throws {
        guard steps >= 0, batchSize > 0 else {
            throw BirdFlowError.invalidAdvanceRequest(
                steps: steps,
                batchSize: batchSize
            )
        }
        throw BirdFlowError.metalUnavailable
    }

    public func snapshot() throws -> SimulationSnapshot {
        throw BirdFlowError.metalUnavailable
    }

    public func copyMacroscopicFields() throws -> (
        density: [Float],
        velocity: [SIMD3<Float>]
    ) {
        throw BirdFlowError.metalUnavailable
    }

    public func copyGaugePressureFieldPascals() throws -> [Float] {
        throw BirdFlowError.metalUnavailable
    }
}
#endif

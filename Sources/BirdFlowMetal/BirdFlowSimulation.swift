import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal

private enum ObservationSlotState {
    case free
    case writing
    case published
    case leased
}

private final class ObservationSlot {
    let density: MTLBuffer
    let velocity: MTLBuffer
    let geometry: MTLBuffer
    var state: ObservationSlotState = .free
    var metadata: GPUFieldFrameMetadata?

    init(density: MTLBuffer, velocity: MTLBuffer, geometry: MTLBuffer) {
        self.density = density
        self.velocity = velocity
        self.geometry = geometry
    }
}

public final class BirdFlowSimulation: @unchecked Sendable {
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
    private let observationSlots: [ObservationSlot]
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let partialLoadCount: Int

    private let buildGeometryPipeline: MTLComputePipelineState
    private let prepareGeometryPipeline: MTLComputePipelineState
    private let initializePipeline: MTLComputePipelineState
    private let fluidStepPipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let integratePipeline: MTLComputePipelineState
    private let extractFieldsPipeline: MTLComputePipelineState
    private let storeRunSamplePipeline: MTLComputePipelineState

    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var currentSolidMask: MTLBuffer
    private var nextSolidMask: MTLBuffer
    private var lastLoadBuffer: MTLBuffer
    private var lastCommandBuffer: MTLCommandBuffer?
    private var terminalFailure: BirdFlowError?
    private var runSampleBuffer: MTLBuffer?
    private var runSampleCapacity = 0

    private let observationCondition = NSCondition()
    private var latestPublishedSlot: Int?
    private var droppedFieldFrames: UInt64 = 0
    private var fieldCaptureWaits: UInt64 = 0

    public private(set) var stepIndex: UInt64 = 0
    public private(set) var timeSeconds: Float = 0

    public var metalDevice: MTLDevice { backend.device }

    public var droppedFieldFrameCount: UInt64 {
        observationCondition.lock()
        defer { observationCondition.unlock() }
        return droppedFieldFrames
    }

    /// Required captures may wait for a lease, while viewer best-effort
    /// captures must leave this counter unchanged.
    public var fieldCaptureWaitCount: UInt64 {
        observationCondition.lock()
        defer { observationCondition.unlock() }
        return fieldCaptureWaits
    }

    public init(
        configuration: SimulationConfiguration,
        bird: BirdParameters,
        initialBodyState: BirdBodyState,
        observationBufferCount: Int = 1
    ) throws {
        guard (1...4).contains(observationBufferCount) else {
            throw BirdFlowError.invalidObservationBufferCount(
                observationBufferCount
            )
        }
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
        extractFieldsPipeline = try backend.pipeline(
            named: "extractMacroscopicFields"
        )
        storeRunSamplePipeline = try backend.pipeline(named: "storeRunSample")

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
        var allocationLengths = [
            MemoryLayout<GPUBirdParameters>.stride,
            MemoryLayout<GPUBirdBodyState>.stride,
            MemoryLayout<GPUPreparedBirdGeometry>.stride,
            populationBytes,
            populationBytes,
            maskBytes,
            maskBytes,
            wallVelocityBytes,
            reductionBytes,
            reductionBytes,
        ]
        for _ in 0..<observationBufferCount {
            allocationLengths.append(densityBytes)
            allocationLengths.append(velocityBytes)
            allocationLengths.append(
                MemoryLayout<GPUPreparedBirdGeometry>.stride
            )
        }
        try backend.validateAllocationPlan(bufferLengths: allocationLengths)
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
        let hazardMode: MTLHazardTrackingMode = observationBufferCount > 1
            ? .untracked
            : .default
        var slots: [ObservationSlot] = []
        slots.reserveCapacity(observationBufferCount)
        for index in 0..<observationBufferCount {
            let slot = ObservationSlot(
                density: try backend.makeSharedBuffer(
                    length: densityBytes,
                    hazardTrackingMode: hazardMode
                ),
                velocity: try backend.makeSharedBuffer(
                    length: velocityBytes,
                    hazardTrackingMode: hazardMode
                ),
                geometry: try backend.makeSharedBuffer(
                    length: MemoryLayout<GPUPreparedBirdGeometry>.stride,
                    hazardTrackingMode: hazardMode
                )
            )
            slot.density.label = "BirdFlow observed density \(index)"
            slot.velocity.label = "BirdFlow observed velocity \(index)"
            slots.append(slot)
        }
        observationSlots = slots
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
        runSampleBuffer = nil
        latestPublishedSlot = nil

        observationSlots[0].state = .writing
        try encodeInitialization()
        publishFieldSlot(
            0,
            step: 0,
            time: 0,
            loadBuffer: lastLoadBuffer
        )
    }

    public convenience init(
        configuration: SimulationConfiguration,
        bird: BirdParameters = .demonstration,
        observationBufferCount: Int = 1
    ) throws {
        let center = configuration.domainOriginMeters
            + configuration.domainSizeMeters * 0.5
        try self.init(
            configuration: configuration,
            bird: bird,
            initialBodyState: BirdBodyState(positionMeters: center),
            observationBufferCount: observationBufferCount
        )
    }

    public convenience init(
        checkpointURL: URL,
        observationBufferCount: Int = 1
    ) throws {
        let (manifest, populations, mask) = try CheckpointArchive.read(
            from: checkpointURL
        )
        try self.init(
            configuration: manifest.configuration,
            bird: manifest.bird,
            initialBodyState: manifest.body,
            observationBufferCount: observationBufferCount
        )
        try restoreCheckpointState(
            manifest: manifest,
            populations: populations,
            mask: mask
        )
    }

    deinit {
        lastCommandBuffer?.waitUntilCompleted()
    }

    /// Advances the coupled GPU state. Geometry, fluid update, load reduction,
    /// and body integration remain on the GPU inside each command-buffer batch.
    @discardableResult
    public func advance(
        steps: Int,
        batchSize: Int = 32,
        fieldCapture: FieldCaptureMode = .required,
        recordRunSamples: Bool = false
    ) throws -> AdvanceResult {
        guard steps >= 0, batchSize > 0 else {
            throw BirdFlowError.invalidAdvanceRequest(
                steps: steps,
                batchSize: batchSize
            )
        }

        try waitForGPU()
        guard steps > 0 else {
            return AdvanceResult(
                droppedFieldFrameCount: droppedFieldFrameCount
            )
        }

        let captureSlotIndex = selectCaptureSlot(for: fieldCapture)
        let boundSlotIndex = captureSlotIndex ?? 0
        if recordRunSamples {
            try ensureRunSampleCapacity(steps)
        }

        var remaining = steps
        var encodedSteps = 0
        var submitted: [MTLCommandBuffer] = []
        do {
            while remaining > 0 {
                let count = min(batchSize, remaining)
                let commandBuffer = try encodeBatch(
                    stepCount: count,
                    startStep: stepIndex + UInt64(encodedSteps),
                    fieldSlot: observationSlots[boundSlotIndex],
                    captureMacroscopicFields: captureSlotIndex != nil
                        && count == remaining,
                    runSampleBaseIndex: encodedSteps,
                    recordRunSamples: recordRunSamples
                )
                submitted.append(commandBuffer)
                encodedSteps += count
                remaining -= count
            }
        }
        catch {
            lastCommandBuffer?.waitUntilCompleted()
            lastCommandBuffer = nil
            if let captureSlotIndex {
                abandonFieldSlot(captureSlotIndex)
            }
            throw invalidate(after: error)
        }

        guard let last = submitted.last else {
            if let captureSlotIndex {
                abandonFieldSlot(captureSlotIndex)
            }
            return AdvanceResult(
                droppedFieldFrameCount: droppedFieldFrameCount
            )
        }
        last.waitUntilCompleted()
        do {
            for commandBuffer in submitted {
                try check(commandBuffer)
            }
        }
        catch {
            lastCommandBuffer = nil
            if let captureSlotIndex {
                abandonFieldSlot(captureSlotIndex)
            }
            throw invalidate(after: error)
        }
        lastCommandBuffer = nil

        stepIndex += UInt64(steps)
        timeSeconds = Float(
            Double(stepIndex) * Double(configuration.scaling.timeStepSeconds)
        )

        if let captureSlotIndex {
            publishFieldSlot(
                captureSlotIndex,
                step: stepIndex,
                time: timeSeconds,
                loadBuffer: lastLoadBuffer
            )
        }

        return AdvanceResult(
            runSamples: recordRunSamples ? readRunSamples(count: steps) : [],
            fieldFramePublished: captureSlotIndex != nil,
            droppedFieldFrameCount: droppedFieldFrameCount
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
        let fieldSlot = currentPublishedFieldSlot()
        let count = configuration.grid.cellCount
        let densityPointer = fieldSlot.density.contents()
            .assumingMemoryBound(to: Float.self)
        let velocityPointer = fieldSlot.velocity.contents()
            .assumingMemoryBound(to: SIMD4<Float>.self)

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
        let fieldSlot = currentPublishedFieldSlot()
        let count = configuration.grid.cellCount
        let pointer = fieldSlot.density.contents()
            .assumingMemoryBound(to: Float.self)
        return (0..<count).map { index in
            configuration.scaling.gaugePressurePascals(
                fromLatticeDensity: pointer[index]
            )
        }
    }

    /// Acquires the newest completed field without copying either volume. Only
    /// one consumer may lease a published slot; a later frame supersedes an
    /// unconsumed older frame.
    public func acquireLatestGPUFieldFrame(
        afterStep: UInt64? = nil
    ) -> GPUFieldFrameLease? {
        observationCondition.lock()
        guard let index = latestPublishedSlot,
              observationSlots[index].state == .published,
              let metadata = observationSlots[index].metadata,
              afterStep.map({ metadata.snapshot.step > $0 }) ?? true else {
            observationCondition.unlock()
            return nil
        }
        observationSlots[index].state = .leased
        latestPublishedSlot = nil
        let slot = observationSlots[index]
        observationCondition.unlock()

        return GPUFieldFrameLease(
            metadata: metadata,
            density: slot.density,
            velocity: slot.velocity
        ) { [weak self] in
            self?.releaseFieldSlot(index)
        }
    }

    /// Publishes the current numerical state without taking a solver step.
    /// This is useful for validation and explicit snapshots after an interval
    /// that ran with observation disabled.
    @discardableResult
    public func captureCurrentMacroscopicField(
        mode: FieldCaptureMode = .required
    ) throws -> Bool {
        try waitForGPU()
        guard let index = selectCaptureSlot(for: mode) else { return false }
        do {
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create field-capture command buffer."
                )
            }
            try encodeExtractedMacroscopicFields(
                commandBuffer: commandBuffer,
                fieldSlot: observationSlots[index]
            )
            try encodeGeometrySnapshot(
                commandBuffer: commandBuffer,
                destination: observationSlots[index].geometry
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            publishFieldSlot(
                index,
                step: stepIndex,
                time: timeSeconds,
                loadBuffer: lastLoadBuffer
            )
            return true
        } catch {
            abandonFieldSlot(index)
            throw error
        }
    }

    /// Writes a complete restart state at a completed solver boundary. The
    /// operation is intentionally explicit and may perform a rare GPU readback.
    public func saveCheckpoint(to destination: URL) throws {
        try waitForGPU()
        let populationStaging = try backend.makeSharedBuffer(
            length: currentPopulations.length
        )
        let maskStaging = try backend.makeSharedBuffer(
            length: currentSolidMask.length
        )
        let geometryStaging = try backend.makeSharedBuffer(
            length: MemoryLayout<GPUPreparedBirdGeometry>.stride
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create checkpoint readback encoder."
            )
        }
        encoder.label = "Read complete BirdFlow checkpoint state"
        encoder.copy(
            from: currentPopulations,
            sourceOffset: 0,
            to: populationStaging,
            destinationOffset: 0,
            size: currentPopulations.length
        )
        encoder.copy(
            from: currentSolidMask,
            sourceOffset: 0,
            to: maskStaging,
            destinationOffset: 0,
            size: currentSolidMask.length
        )
        encoder.copy(
            from: preparedGeometryBuffer,
            sourceOffset: 0,
            to: geometryStaging,
            destinationOffset: 0,
            size: MemoryLayout<GPUPreparedBirdGeometry>.stride
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)

        let populations = Data(
            bytes: populationStaging.contents(),
            count: populationStaging.length
        )
        let mask = Data(
            bytes: maskStaging.contents(),
            count: maskStaging.length
        )
        let body = bodyStateBuffer.contents()
            .assumingMemoryBound(to: GPUBirdBodyState.self)
            .pointee
            .coreValue
        let load = lastLoadBuffer.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
            .pointee
            .coreValue
        let geometry = geometryStaging.contents()
            .assumingMemoryBound(to: GPUPreparedBirdGeometry.self)
            .pointee
            .publicValue
        let manifest = BirdFlowCheckpointManifest(
            schema: BirdFlowCheckpointManifest.schemaVersion,
            configuration: configuration,
            bird: bird,
            step: stepIndex,
            timeSeconds: timeSeconds,
            body: body,
            load: load,
            geometry: geometry,
            populationBytes: populations.count,
            solidMaskBytes: mask.count,
            populationSHA256: CheckpointArchive.sha256(populations),
            solidMaskSHA256: CheckpointArchive.sha256(mask)
        )
        try CheckpointArchive.write(
            manifest: manifest,
            populations: populations,
            solidMask: mask,
            to: destination
        )
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
        let density = observationSlots[0].density
        let velocity = observationSlots[0].velocity
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

        try encodeGeometrySnapshot(
            commandBuffer: commandBuffer,
            destination: observationSlots[0].geometry
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
    }

    private func encodeBatch(
        stepCount: Int,
        startStep: UInt64,
        fieldSlot: ObservationSlot,
        captureMacroscopicFields: Bool,
        runSampleBaseIndex: Int,
        recordRunSamples: Bool
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
                uniforms: &uniforms,
                fieldSlot: fieldSlot
            )
            lastLoadBuffer = try encodeReduction(commandBuffer: commandBuffer)
            if configuration.freeFlight {
                try encodeBodyIntegration(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms,
                    loadBuffer: lastLoadBuffer
                )
            }
            if recordRunSamples {
                try encodeRunSample(
                    commandBuffer: commandBuffer,
                    sampleIndex: runSampleBaseIndex + localStep,
                    step: absoluteStep,
                    time: stepTime,
                    loadBuffer: lastLoadBuffer
                )
            }

            swap(&currentPopulations, &nextPopulations)
            swap(&currentSolidMask, &nextSolidMask)
        }

        if captureMacroscopicFields {
            try encodeGeometrySnapshot(
                commandBuffer: commandBuffer,
                destination: fieldSlot.geometry
            )
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
        uniforms: inout GPUUniforms,
        fieldSlot: ObservationSlot
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create fluid encoder."
            )
        }
        let density = fieldSlot.density
        let velocity = fieldSlot.velocity
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

    private func encodeRunSample(
        commandBuffer: MTLCommandBuffer,
        sampleIndex: Int,
        step: UInt64,
        time: Float,
        loadBuffer: MTLBuffer
    ) throws {
        guard let runSampleBuffer,
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create run-sample encoder."
            )
        }
        var indices = SIMD4<UInt32>(
            UInt32(sampleIndex),
            UInt32(truncatingIfNeeded: step),
            UInt32(truncatingIfNeeded: step >> 32),
            0
        )
        var sampleTime = time
        encoder.label = "Store force and pose sample"
        encoder.setBuffer(runSampleBuffer, offset: 0, index: 0)
        encoder.setBuffer(bodyStateBuffer, offset: 0, index: 1)
        encoder.setBuffer(loadBuffer, offset: 0, index: 2)
        encoder.setBytes(
            &indices,
            length: MemoryLayout<SIMD4<UInt32>>.stride,
            index: 3
        )
        encoder.setBytes(
            &sampleTime,
            length: MemoryLayout<Float>.stride,
            index: 4
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: storeRunSamplePipeline,
            count: 1
        )
        encoder.endEncoding()
    }

    private func encodeGeometrySnapshot(
        commandBuffer: MTLCommandBuffer,
        destination: MTLBuffer
    ) throws {
        guard let encoder = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create geometry-snapshot encoder."
            )
        }
        encoder.label = "Capture exact bird geometry frame"
        encoder.copy(
            from: preparedGeometryBuffer,
            sourceOffset: 0,
            to: destination,
            destinationOffset: 0,
            size: MemoryLayout<GPUPreparedBirdGeometry>.stride
        )
        encoder.endEncoding()
    }

    private func ensureRunSampleCapacity(_ count: Int) throws {
        guard count > runSampleCapacity else { return }
        let capacity = max(256, count.nextPowerOfTwo)
        let length = capacity * MemoryLayout<GPURunSample>.stride
        try backend.validateAllocationPlan(bufferLengths: [length])
        runSampleBuffer = try backend.makeSharedBuffer(length: length)
        runSampleBuffer?.label = "BirdFlow compact run samples"
        runSampleCapacity = capacity
    }

    private func readRunSamples(count: Int) -> [RunSample] {
        guard let runSampleBuffer else { return [] }
        let pointer = runSampleBuffer.contents()
            .assumingMemoryBound(to: GPURunSample.self)
        return (0..<count).map { pointer[$0].publicValue }
    }

    private func selectCaptureSlot(for mode: FieldCaptureMode) -> Int? {
        guard mode != .disabled else { return nil }
        observationCondition.lock()
        defer { observationCondition.unlock() }

        while true {
            let index = observationSlots.firstIndex { $0.state == .free }
                ?? observationSlots.firstIndex { $0.state == .published }
            if let index {
                if latestPublishedSlot == index {
                    latestPublishedSlot = nil
                }
                observationSlots[index].state = .writing
                observationSlots[index].metadata = nil
                return index
            }
            if mode == .bestEffort {
                droppedFieldFrames &+= 1
                return nil
            }
            fieldCaptureWaits &+= 1
            observationCondition.wait()
        }
    }

    private func publishFieldSlot(
        _ index: Int,
        step: UInt64,
        time: Float,
        loadBuffer: MTLBuffer
    ) {
        let body = bodyStateBuffer.contents()
            .assumingMemoryBound(to: GPUBirdBodyState.self)
            .pointee
            .coreValue
        let load = loadBuffer.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
            .pointee
            .coreValue
        let geometry = observationSlots[index].geometry.contents()
            .assumingMemoryBound(to: GPUPreparedBirdGeometry.self)
            .pointee
            .publicValue
        let snapshot = SimulationSnapshot(
            step: step,
            timeSeconds: time,
            body: body,
            aerodynamicLoad: load
        )
        let metadata = GPUFieldFrameMetadata(
            snapshot: snapshot,
            grid: configuration.grid,
            domainOriginMeters: configuration.domainOriginMeters,
            cellSizeMeters: configuration.scaling.cellSizeMeters,
            velocityToPhysical: configuration.scaling.velocityToPhysical,
            pressureScalePascals: configuration.scaling.pressureScalePascals,
            referenceDynamicPressurePascals: 0.5
                * configuration.physicalAirDensity
                * pow(
                    configuration.scaling.latticeReferenceSpeed
                        * configuration.scaling.velocityToPhysical,
                    2
                ),
            physicalAirDensity: configuration.physicalAirDensity,
            bird: bird,
            geometry: geometry
        )

        observationCondition.lock()
        if let previous = latestPublishedSlot,
           previous != index,
           observationSlots[previous].state == .published {
            observationSlots[previous].state = .free
            observationSlots[previous].metadata = nil
        }
        observationSlots[index].metadata = metadata
        observationSlots[index].state = .published
        latestPublishedSlot = index
        observationCondition.broadcast()
        observationCondition.unlock()
    }

    private func abandonFieldSlot(_ index: Int) {
        observationCondition.lock()
        if observationSlots[index].state == .writing {
            observationSlots[index].state = .free
            observationSlots[index].metadata = nil
        }
        observationCondition.broadcast()
        observationCondition.unlock()
    }

    private func releaseFieldSlot(_ index: Int) {
        observationCondition.lock()
        if observationSlots[index].state == .leased {
            observationSlots[index].state = .free
            observationSlots[index].metadata = nil
        }
        observationCondition.broadcast()
        observationCondition.unlock()
    }

    private func currentPublishedFieldSlot() -> ObservationSlot {
        observationCondition.lock()
        defer { observationCondition.unlock() }
        if let index = latestPublishedSlot {
            return observationSlots[index]
        }
        // This fallback is only reachable when a caller mixes copying with an
        // active lease. Legacy required-capture callers always have a published
        // slot and retain their historical semantics.
        return observationSlots[0]
    }

    private func restoreCheckpointState(
        manifest: BirdFlowCheckpointManifest,
        populations: Data,
        mask: Data
    ) throws {
        guard populations.count == currentPopulations.length,
              mask.count == currentSolidMask.length else {
            throw BirdFlowCheckpointError.invalidArchive(
                "grid dimensions do not match checkpoint buffer lengths"
            )
        }
        let populationStaging = try backend.makeSharedBuffer(
            length: populations.count
        )
        let maskStaging = try backend.makeSharedBuffer(length: mask.count)
        populations.copyBytes(
            to: populationStaging.contents()
                .assumingMemoryBound(to: UInt8.self),
            count: populations.count
        )
        mask.copyBytes(
            to: maskStaging.contents().assumingMemoryBound(to: UInt8.self),
            count: mask.count
        )
        bodyStateBuffer.contents()
            .assumingMemoryBound(to: GPUBirdBodyState.self)
            .pointee = GPUBirdBodyState(manifest.body)
        reductionA.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
            .pointee = GPUForceTorque(
                force: SIMD4<Float>(manifest.load.forceNewtons, 0),
                torque: SIMD4<Float>(manifest.load.torqueNewtonMeters, 0)
            )
        lastLoadBuffer = reductionA
        observationSlots[0].geometry.contents()
            .assumingMemoryBound(to: GPUPreparedBirdGeometry.self)
            .pointee = GPUPreparedBirdGeometry(manifest.geometry)

        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create checkpoint restore encoder."
            )
        }
        blit.label = "Restore complete BirdFlow numerical state"
        blit.copy(
            from: populationStaging,
            sourceOffset: 0,
            to: currentPopulations,
            destinationOffset: 0,
            size: populations.count
        )
        blit.copy(
            from: maskStaging,
            sourceOffset: 0,
            to: currentSolidMask,
            destinationOffset: 0,
            size: mask.count
        )
        blit.endEncoding()
        try encodeExtractedMacroscopicFields(
            commandBuffer: commandBuffer,
            fieldSlot: observationSlots[0]
        )
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)

        stepIndex = manifest.step
        timeSeconds = manifest.timeSeconds
        terminalFailure = nil
        observationCondition.lock()
        latestPublishedSlot = nil
        for slot in observationSlots {
            slot.state = .free
            slot.metadata = nil
        }
        observationSlots[0].state = .writing
        observationCondition.unlock()
        publishFieldSlot(
            0,
            step: stepIndex,
            time: timeSeconds,
            loadBuffer: lastLoadBuffer
        )
    }

    private func encodeExtractedMacroscopicFields(
        commandBuffer: MTLCommandBuffer,
        fieldSlot: ObservationSlot
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create checkpoint field extraction encoder."
            )
        }
        let populations = currentPopulations
        let density = fieldSlot.density
        let velocity = fieldSlot.velocity
        var uniforms = GPUUniforms(
            configuration: configuration,
            time: timeSeconds
        )
        encoder.label = "Extract restored macroscopic fields"
        encoder.setBuffer(populations, offset: 0, index: 0)
        encoder.setBuffer(density, offset: 0, index: 1)
        encoder.setBuffer(velocity, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: extractFieldsPipeline,
            count: configuration.grid.cellCount
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

private extension Int {
    var nextPowerOfTwo: Int {
        guard self > 1 else { return 1 }
        return 1 << (Int.bitWidth - (self - 1).leadingZeroBitCount)
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
        initialBodyState: BirdBodyState,
        observationBufferCount: Int = 1
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
        bird: BirdParameters = .demonstration,
        observationBufferCount: Int = 1
    ) throws {
        let center = configuration.domainOriginMeters
            + configuration.domainSizeMeters * 0.5
        try self.init(
            configuration: configuration,
            bird: bird,
            initialBodyState: BirdBodyState(positionMeters: center),
            observationBufferCount: observationBufferCount
        )
    }

    @discardableResult
    public func advance(
        steps: Int,
        batchSize: Int = 32,
        fieldCapture: FieldCaptureMode = .required,
        recordRunSamples: Bool = false
    ) throws -> AdvanceResult {
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

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

public enum MetalTranslatingBodyTopologyValidator {
    public static let gridResolution = 24
    public static let sphereRadiusCells = 3.25
    public static let translationSpeedLattice = 0.05
    public static let steps = 40
    public static let maximumConservativeForceResidual = 5.0e-4
    public static let maximumConservativeRelativeRMSResidual = 5.0e-3
    public static let minimumImprovementFactor = 5.0
    public static let maximumRawBudgetDifference = 1.0e-7

    public static func run() throws
        -> MetalTranslatingBodyTopologyValidationReport
    {
#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let legacy = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 0
        ).run(steps: steps)
        let conservative = try MetalTranslatingBodyTopologySimulation(
            backend: backend,
            linkForceMode: 6
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
}

#if canImport(Metal)
import Metal

private struct GPUTranslatingTopologyParameters {
    var initialCenterAndRadius: SIMD4<Float>
    var velocity: SIMD4<Float>
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

    init(backend: MetalBackend, linkForceMode: UInt32) throws {
        self.backend = backend
        self.linkForceMode = linkForceMode
        let grid = try GridSize(
            x: MetalTranslatingBodyTopologyValidator.gridResolution,
            y: MetalTranslatingBodyTopologyValidator.gridResolution,
            z: MetalTranslatingBodyTopologyValidator.gridResolution
        )
        let referenceSpeed = Float(
            MetalTranslatingBodyTopologyValidator.translationSpeedLattice
        )
        let scaling = try LatticeScaling(
            characteristicLengthMeters: 8,
            characteristicLengthCells: 8,
            referenceSpeedMetersPerSecond: referenceSpeed,
            targetReynoldsNumber: 4,
            physicalAirDensity: 1,
            latticeReferenceSpeed: referenceSpeed
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
        let center = SIMD3<Float>(8, 12, 12)
        parameters = try backend.makeSharedBuffer(
            value: GPUTranslatingTopologyParameters(
                initialCenterAndRadius: SIMD4<Float>(
                    center,
                    Float(MetalTranslatingBodyTopologyValidator
                        .sphereRadiusCells)
                ),
                velocity: SIMD4<Float>(referenceSpeed, 0, 0, 0)
            )
        )
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: center))
        )
        bounds = GPUTranslatingTopologyBounds(
            minimum: SIMD4<UInt32>(2, 2, 2, 0),
            maximumExclusive: SIMD4<UInt32>(22, 22, 22, 0)
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
            captureMacroscopicFields: false,
            accumulateLoads: true,
            hasPreviousGeometry: true,
            periodicBoundaries: true,
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

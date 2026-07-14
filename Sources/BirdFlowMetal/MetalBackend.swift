import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal

final class MetalBackend {
    let device: MTLDevice
    let queue: MTLCommandQueue

    private let library: MTLLibrary
    private var pipelines: [String: MTLComputePipelineState] = [:]

    init(fastMath: Bool) throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw BirdFlowError.deviceUnavailable
        }
        guard let queue = device.makeCommandQueue() else {
            throw BirdFlowError.commandQueueUnavailable
        }

        let sourceURL = Bundle.module.url(
            forResource: "BirdFlow",
            withExtension: "metal"
        ) ?? Bundle.module.url(
            forResource: "BirdFlow",
            withExtension: "metal",
            subdirectory: "Metal"
        )
        guard let sourceURL else {
            throw BirdFlowError.resourceMissing("Metal/BirdFlow.metal")
        }

        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let options = MTLCompileOptions()
        options.fastMathEnabled = fastMath

        do {
            library = try device.makeLibrary(source: source, options: options)
        } catch {
            throw BirdFlowError.shaderCompilationFailed(error.localizedDescription)
        }

        self.device = device
        self.queue = queue
    }

    func pipeline(named name: String) throws -> MTLComputePipelineState {
        if let cached = pipelines[name] {
            return cached
        }
        guard let function = library.makeFunction(name: name) else {
            throw BirdFlowError.pipelineCreationFailed(name)
        }

        do {
            let pipeline = try device.makeComputePipelineState(function: function)
            pipelines[name] = pipeline
            return pipeline
        } catch {
            throw BirdFlowError.pipelineCreationFailed(
                "\(name): \(error.localizedDescription)"
            )
        }
    }

    func makePrivateBuffer(length: Int) throws -> MTLBuffer {
        guard let buffer = device.makeBuffer(
            length: length,
            options: [.storageModePrivate]
        ) else {
            throw BirdFlowError.allocationFailed(bytes: length)
        }
        return buffer
    }

    func validateAllocationPlan(bufferLengths: [Int]) throws {
        let recommendedValue = device.recommendedMaxWorkingSetSize
        let recommended = recommendedValue > UInt64(Int.max)
            ? Int.max
            : Int(recommendedValue)
        for length in bufferLengths where length > device.maxBufferLength {
            throw BirdFlowError.bufferExceedsDeviceLimit(
                bytes: length,
                limit: device.maxBufferLength
            )
        }

        var total = 0
        for length in bufferLengths {
            let (sum, overflow) = total.addingReportingOverflow(length)
            if overflow {
                throw BirdFlowError.workingSetExceedsRecommendation(
                    bytes: Int.max,
                    recommended: recommended
                )
            }
            total = sum
        }
        if recommended > 0 && total > recommended {
            throw BirdFlowError.workingSetExceedsRecommendation(
                bytes: total,
                recommended: recommended
            )
        }
    }

    func makeSharedBuffer(
        length: Int,
        hazardTrackingMode: MTLHazardTrackingMode = .default
    ) throws -> MTLBuffer {
        var options: MTLResourceOptions = [.storageModeShared]
        if hazardTrackingMode == .untracked {
            options.insert(.hazardTrackingModeUntracked)
        } else if hazardTrackingMode == .tracked {
            options.insert(.hazardTrackingModeTracked)
        }
        guard let buffer = device.makeBuffer(
            length: length,
            options: options
        ) else {
            throw BirdFlowError.allocationFailed(bytes: length)
        }
        memset(buffer.contents(), 0, length)
        return buffer
    }

    func makeSharedBuffer<T>(value: T) throws -> MTLBuffer {
        let buffer = try makeSharedBuffer(length: MemoryLayout<T>.stride)
        buffer.contents().assumingMemoryBound(to: T.self).pointee = value
        return buffer
    }

    func dispatch1D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        count: Int
    ) {
        let groupWidth = min(256, pipeline.maxTotalThreadsPerThreadgroup)
        encoder.setComputePipelineState(pipeline)
        encoder.dispatchThreads(
            MTLSize(width: count, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: groupWidth, height: 1, depth: 1)
        )
    }

    /// Dispatches complete threadgroups and lets the kernel mask padded lanes.
    /// This is required by kernels that use threadgroup barriers or reductions.
    func dispatch1DPadded(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        count: Int,
        threadsPerThreadgroup width: Int
    ) {
        precondition(width > 0 && width <= pipeline.maxTotalThreadsPerThreadgroup)
        let groupCount = (count + width - 1) / width
        encoder.setComputePipelineState(pipeline)
        encoder.dispatchThreadgroups(
            MTLSize(width: groupCount, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
        )
    }

    func dispatch3D(
        encoder: MTLComputeCommandEncoder,
        pipeline: MTLComputePipelineState,
        width: Int,
        height: Int,
        depth: Int
    ) {
        let groupWidth = min(pipeline.threadExecutionWidth, width)
        let groupHeight = min(
            height,
            max(1, min(256, pipeline.maxTotalThreadsPerThreadgroup) / groupWidth)
        )
        encoder.setComputePipelineState(pipeline)
        encoder.dispatchThreads(
            MTLSize(width: width, height: height, depth: depth),
            threadsPerThreadgroup: MTLSize(
                width: groupWidth,
                height: groupHeight,
                depth: 1
            )
        )
    }
}
#endif

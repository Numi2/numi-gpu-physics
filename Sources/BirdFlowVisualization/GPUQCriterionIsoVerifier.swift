import BirdFlowMetal
import Foundation
import Metal

public struct QCriterionIsoVertex: Sendable, Equatable {
  public var position: SIMD3<Float>
  public var normal: SIMD3<Float>

  public init(position: SIMD3<Float>, normal: SIMD3<Float>) {
    self.position = position
    self.normal = normal
  }
}

public struct GPUQCriterionIsoResult: Sendable {
  public var vertices: [QCriterionIsoVertex]
  public var overflow: Bool

  public init(vertices: [QCriterionIsoVertex], overflow: Bool) {
    self.vertices = vertices
    self.overflow = overflow
  }
}

/// Explicit test utility for analytic marching-cubes fields. Production Q
/// surfaces remain entirely GPU-resident and use indirect drawing.
public enum GPUQCriterionIsoVerifier {
  public static func extract(
    qCriterion: [Float],
    valid: [UInt8],
    metadata: GPUFieldFrameMetadata,
    threshold: Float,
    triangleCapacity: Int,
    device: MTLDevice
  ) throws -> GPUQCriterionIsoResult {
    precondition(qCriterion.count == metadata.grid.cellCount)
    precondition(valid.count == metadata.grid.cellCount)
    precondition(triangleCapacity > 0)
    let backend = try VisualizationBackend(device: device)
    let classifyPipeline = try backend.compute("classifyQCriterionCubes")
    let scanPipeline = try backend.compute("scanTriangleBlocks")
    let blockPipeline = try backend.compute("scanBlockSums")
    let addPipeline = try backend.compute("addTriangleBlockOffsets")
    let preparePipeline = try backend.compute("prepareQCriterionIndirectDraw")
    let emitPipeline = try backend.compute("emitQCriterionCubes")
    let marchingCubesTable = try MarchingCubesLookup.makeBuffer(device: device)
    let grid = metadata.grid
    let cubeCount = (grid.x - 1) * (grid.y - 1) * (grid.z - 1)
    let blockCount = (cubeCount + 255) / 256

    let q = try backend.buffer(
      length: qCriterion.count * MemoryLayout<Float>.stride,
      shared: true
    )
    let mask = try backend.buffer(length: valid.count, shared: true)
    let vorticity = try backend.buffer(
      length: metadata.grid.cellCount * MemoryLayout<SIMD4<Float>>.stride,
      shared: true
    )
    qCriterion.withUnsafeBytes { bytes in
      _ = memcpy(q.contents(), bytes.baseAddress!, bytes.count)
    }
    valid.withUnsafeBytes { bytes in
      _ = memcpy(mask.contents(), bytes.baseAddress!, bytes.count)
    }
    let counts = try backend.buffer(length: cubeCount * 4)
    let offsets = try backend.buffer(length: cubeCount * 4)
    let blockSums = try backend.buffer(length: blockCount * 4)
    let blockOffsets = try backend.buffer(length: blockCount * 4)
    let vertices = try backend.buffer(
      length: triangleCapacity * 3 * MemoryLayout<IsoVertex>.stride,
      shared: true
    )
    let indirect = try backend.buffer(
      length: MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
      shared: true
    )
    let overflow = try backend.buffer(length: 16, shared: true)
    var settings = VisualizationSettings()
    settings.qThreshold = threshold
    settings.qTriangleCapacity = triangleCapacity
    var uniforms = VisualizationUniforms(
      metadata: metadata,
      settings: settings,
      sliceCenter: .zero,
      sliceU: SIMD3<Float>(1, 0, 0),
      sliceV: SIMD3<Float>(0, 1, 0),
      tracerDeltaTime: 0,
      resetTracers: true
    )
    var cubeCount32 = UInt32(cubeCount)
    var blockCount32 = UInt32(blockCount)
    var countAndCapacity = SIMD2<UInt32>(
      UInt32(cubeCount),
      UInt32(triangleCapacity)
    )

    guard let commandBuffer = backend.queue.makeCommandBuffer() else {
      throw VisualizationError.pipeline("analytic Q extraction command")
    }
    let classify = commandBuffer.makeComputeCommandEncoder()!
    classify.setBuffer(q, offset: 0, index: 0)
    classify.setBuffer(mask, offset: 0, index: 1)
    classify.setBuffer(counts, offset: 0, index: 2)
    classify.setBytes(&uniforms, length: MemoryLayout<VisualizationUniforms>.stride, index: 3)
    classify.setBuffer(marchingCubesTable, offset: 0, index: 4)
    backend.dispatch1D(classify, pipeline: classifyPipeline, count: cubeCount)
    classify.endEncoding()

    let scan = commandBuffer.makeComputeCommandEncoder()!
    scan.setComputePipelineState(scanPipeline)
    scan.setBuffer(counts, offset: 0, index: 0)
    scan.setBuffer(offsets, offset: 0, index: 1)
    scan.setBuffer(blockSums, offset: 0, index: 2)
    scan.setBytes(&cubeCount32, length: 4, index: 3)
    scan.dispatchThreadgroups(
      MTLSize(width: blockCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
    )
    scan.endEncoding()

    let scanBlocks = commandBuffer.makeComputeCommandEncoder()!
    scanBlocks.setBuffer(blockSums, offset: 0, index: 0)
    scanBlocks.setBuffer(blockOffsets, offset: 0, index: 1)
    scanBlocks.setBytes(&blockCount32, length: 4, index: 2)
    backend.dispatch1D(scanBlocks, pipeline: blockPipeline, count: 1)
    scanBlocks.endEncoding()

    let add = commandBuffer.makeComputeCommandEncoder()!
    add.setBuffer(offsets, offset: 0, index: 0)
    add.setBuffer(blockOffsets, offset: 0, index: 1)
    add.setBytes(&cubeCount32, length: 4, index: 2)
    backend.dispatch1D(add, pipeline: addPipeline, count: cubeCount)
    add.endEncoding()

    let prepare = commandBuffer.makeComputeCommandEncoder()!
    prepare.setBuffer(counts, offset: 0, index: 0)
    prepare.setBuffer(offsets, offset: 0, index: 1)
    prepare.setBuffer(indirect, offset: 0, index: 2)
    prepare.setBuffer(overflow, offset: 0, index: 3)
    prepare.setBytes(&countAndCapacity, length: 8, index: 4)
    backend.dispatch1D(prepare, pipeline: preparePipeline, count: 1)
    prepare.endEncoding()

    let emit = commandBuffer.makeComputeCommandEncoder()!
    emit.setBuffer(q, offset: 0, index: 0)
    emit.setBuffer(mask, offset: 0, index: 1)
    emit.setBuffer(counts, offset: 0, index: 2)
    emit.setBuffer(offsets, offset: 0, index: 3)
    emit.setBuffer(vertices, offset: 0, index: 4)
    emit.setBytes(&uniforms, length: MemoryLayout<VisualizationUniforms>.stride, index: 5)
    emit.setBuffer(vorticity, offset: 0, index: 6)
    emit.setBuffer(marchingCubesTable, offset: 0, index: 7)
    backend.dispatch1D(emit, pipeline: emitPipeline, count: cubeCount)
    emit.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw VisualizationError.shader(
        commandBuffer.error?.localizedDescription
          ?? "analytic Q extraction did not complete"
      )
    }

    let exceeded = overflow.contents().assumingMemoryBound(to: UInt32.self).pointee != 0
    let draw = indirect.contents()
      .assumingMemoryBound(to: DrawPrimitivesIndirectArguments.self)
      .pointee
    let vertexCount = Int(draw.vertexCount)
    let pointer = vertices.contents().assumingMemoryBound(to: IsoVertex.self)
    let result =
      exceeded
      ? []
      : (0..<vertexCount).map { index in
        QCriterionIsoVertex(
          position: pointer[index].position.xyz,
          normal: pointer[index].normal.xyz
        )
      }
    return GPUQCriterionIsoResult(vertices: result, overflow: exceeded)
  }
}

extension SIMD4<Float> {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

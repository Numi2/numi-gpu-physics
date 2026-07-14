import BirdFlowCore
import BirdFlowMetal
import Foundation
import Metal

public struct GPUFlowDiagnosticResult: Sendable {
  public var field: FlowDiagnosticField
  public var allOutputsFinite: Bool
  public var sourceFieldsBitwiseUnchanged: Bool

  public init(
    field: FlowDiagnosticField,
    allOutputsFinite: Bool,
    sourceFieldsBitwiseUnchanged: Bool
  ) {
    self.field = field
    self.allOutputsFinite = allOutputsFinite
    self.sourceFieldsBitwiseUnchanged = sourceFieldsBitwiseUnchanged
  }
}

/// Explicit readback utility for the diagnostic verification gate. The live
/// renderer does not call this path and continues to consume leased buffers
/// without CPU volume copies.
public enum GPUFlowDiagnosticVerifier {
  public static func compute(
    density: [Float],
    velocityLattice: [SIMD3<Float>],
    metadata: GPUFieldFrameMetadata,
    device: MTLDevice
  ) throws -> GPUFlowDiagnosticResult {
    let count = metadata.grid.cellCount
    precondition(density.count == count)
    precondition(velocityLattice.count == count)

    let backend = try VisualizationBackend(device: device)
    let pipeline = try backend.compute("deriveFlowDiagnostics")
    let densityBuffer = try backend.buffer(
      length: count * MemoryLayout<Float>.stride,
      shared: true
    )
    let velocityBuffer = try backend.buffer(
      length: count * MemoryLayout<SIMD4<Float>>.stride,
      shared: true
    )
    density.withUnsafeBytes { bytes in
      _ = memcpy(densityBuffer.contents(), bytes.baseAddress!, bytes.count)
    }
    let velocity4 = velocityLattice.map { SIMD4<Float>($0, 0) }
    velocity4.withUnsafeBytes { bytes in
      _ = memcpy(velocityBuffer.contents(), bytes.baseAddress!, bytes.count)
    }
    let densityBefore = Data(
      bytes: densityBuffer.contents(),
      count: densityBuffer.length
    )
    let velocityBefore = Data(
      bytes: velocityBuffer.contents(),
      count: velocityBuffer.length
    )

    let vorticityBuffer = try backend.buffer(
      length: count * MemoryLayout<SIMD4<Float>>.stride,
      shared: true
    )
    let qBuffer = try backend.buffer(
      length: count * MemoryLayout<Float>.stride,
      shared: true
    )
    let validBuffer = try backend.buffer(length: count, shared: true)
    var settings = VisualizationSettings()
    settings.showQCriterion = true
    var uniforms = VisualizationUniforms(
      metadata: metadata,
      settings: settings,
      sliceCenter: .zero,
      sliceU: SIMD3<Float>(1, 0, 0),
      sliceV: SIMD3<Float>(0, 1, 0),
      tracerDeltaTime: 0,
      resetTracers: true
    )

    guard let commandBuffer = backend.queue.makeCommandBuffer(),
      let encoder = commandBuffer.makeComputeCommandEncoder()
    else {
      throw VisualizationError.pipeline("diagnostic verification command")
    }
    encoder.setBuffer(densityBuffer, offset: 0, index: 0)
    encoder.setBuffer(velocityBuffer, offset: 0, index: 1)
    encoder.setBuffer(vorticityBuffer, offset: 0, index: 2)
    encoder.setBuffer(qBuffer, offset: 0, index: 3)
    encoder.setBuffer(validBuffer, offset: 0, index: 4)
    encoder.setBytes(
      &uniforms,
      length: MemoryLayout<VisualizationUniforms>.stride,
      index: 5
    )
    backend.dispatch1D(encoder, pipeline: pipeline, count: count)
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw VisualizationError.shader(
        commandBuffer.error?.localizedDescription
          ?? "diagnostic verification did not complete"
      )
    }

    let vorticityPointer = vorticityBuffer.contents()
      .assumingMemoryBound(to: SIMD4<Float>.self)
    let qPointer = qBuffer.contents().assumingMemoryBound(to: Float.self)
    let validPointer = validBuffer.contents().assumingMemoryBound(to: UInt8.self)
    var vorticity = [SIMD3<Float>](repeating: .zero, count: count)
    var q = [Float](repeating: 0, count: count)
    var valid = [UInt8](repeating: 0, count: count)
    var finite = true
    for index in 0..<count {
      let omega = vorticityPointer[index]
      vorticity[index] = omega.xyz
      q[index] = qPointer[index]
      valid[index] = validPointer[index]
      finite =
        finite
        && omega.x.isFinite && omega.y.isFinite
        && omega.z.isFinite && omega.w.isFinite
        && q[index].isFinite
    }
    let densityAfter = Data(
      bytes: densityBuffer.contents(),
      count: densityBuffer.length
    )
    let velocityAfter = Data(
      bytes: velocityBuffer.contents(),
      count: velocityBuffer.length
    )
    return GPUFlowDiagnosticResult(
      field: FlowDiagnosticField(
        vorticity: vorticity,
        qCriterion: q,
        valid: valid
      ),
      allOutputsFinite: finite,
      sourceFieldsBitwiseUnchanged: densityBefore == densityAfter
        && velocityBefore == velocityAfter
    )
  }
}

extension SIMD4<Float> {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

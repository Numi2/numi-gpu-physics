import Foundation
import Metal

enum VisualizationError: Error, CustomStringConvertible {
  case resourceMissing
  case shader(String)
  case pipeline(String)
  case allocation(Int)

  var description: String {
    switch self {
    case .resourceMissing:
      return "BirdFlow visualization Metal source is missing."
    case .shader(let message):
      return "BirdFlow visualization shader failed: \(message)"
    case .pipeline(let name):
      return "BirdFlow visualization pipeline failed: \(name)"
    case .allocation(let bytes):
      return "BirdFlow visualization could not allocate \(bytes) bytes."
    }
  }
}

final class VisualizationBackend {
  let device: MTLDevice
  let queue: MTLCommandQueue
  let library: MTLLibrary

  private var computePipelines: [String: MTLComputePipelineState] = [:]
  private var renderPipelines: [String: MTLRenderPipelineState] = [:]

  init(device: MTLDevice) throws {
    self.device = device
    guard let queue = device.makeCommandQueue() else {
      throw VisualizationError.pipeline("command queue")
    }
    self.queue = queue
    let url =
      Bundle.module.url(
        forResource: "Visualization",
        withExtension: "metal"
      )
      ?? Bundle.module.url(
        forResource: "Visualization",
        withExtension: "metal",
        subdirectory: "Metal"
      )
    guard let url else { throw VisualizationError.resourceMissing }
    do {
      library = try device.makeLibrary(
        source: String(contentsOf: url, encoding: .utf8),
        options: nil
      )
    } catch {
      throw VisualizationError.shader(error.localizedDescription)
    }
  }

  func compute(_ name: String) throws -> MTLComputePipelineState {
    if let existing = computePipelines[name] { return existing }
    guard let function = library.makeFunction(name: name) else {
      throw VisualizationError.pipeline(name)
    }
    let pipeline = try device.makeComputePipelineState(function: function)
    computePipelines[name] = pipeline
    return pipeline
  }

  func render(
    vertex: String,
    fragment: String,
    colorFormat: MTLPixelFormat,
    depthFormat: MTLPixelFormat = .depth32Float,
    blending: Bool = false
  ) throws -> MTLRenderPipelineState {
    let key = "\(vertex)|\(fragment)|\(colorFormat.rawValue)|\(blending)"
    if let existing = renderPipelines[key] { return existing }
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: vertex)
    descriptor.fragmentFunction = library.makeFunction(name: fragment)
    descriptor.colorAttachments[0].pixelFormat = colorFormat
    descriptor.depthAttachmentPixelFormat = depthFormat
    if blending {
      let attachment = descriptor.colorAttachments[0]!
      attachment.isBlendingEnabled = true
      attachment.sourceRGBBlendFactor = .sourceAlpha
      attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
      attachment.sourceAlphaBlendFactor = .one
      attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
    }
    let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    renderPipelines[key] = pipeline
    return pipeline
  }

  func buffer(length: Int, shared: Bool = false) throws -> MTLBuffer {
    let options: MTLResourceOptions =
      shared
      ? [.storageModeShared]
      : [.storageModePrivate]
    guard let buffer = device.makeBuffer(length: max(length, 16), options: options) else {
      throw VisualizationError.allocation(length)
    }
    if shared { memset(buffer.contents(), 0, buffer.length) }
    return buffer
  }

  func dispatch1D(
    _ encoder: MTLComputeCommandEncoder,
    pipeline: MTLComputePipelineState,
    count: Int
  ) {
    let width = min(256, pipeline.maxTotalThreadsPerThreadgroup)
    encoder.setComputePipelineState(pipeline)
    encoder.dispatchThreads(
      MTLSize(width: count, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: width, height: 1, depth: 1)
    )
  }
}

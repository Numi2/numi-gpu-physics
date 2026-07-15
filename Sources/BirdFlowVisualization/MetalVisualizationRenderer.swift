import BirdFlowCore
import BirdFlowMetal
import Foundation
@preconcurrency import Metal
import MetalKit
import simd

public struct VisualizationMetrics: Sendable {
  public var displayedStep: UInt64 = 0
  public var renderFPS: Double = 0
  public var rendererGPUTimeMilliseconds: Double = 0
  public var frameAgeMilliseconds: Double = 0
  public var pressureRangePascals: Float = 0
  public var pressureLegendRange: Float = 0
  public var qSuggestedThreshold: Float = 0
  public var qSurfaceOverflow = false
  public var sliceProbe: SliceProbe?

  public init() {}
}

public struct SliceProbe: Sendable, Equatable {
  public var worldMeters: SIMD3<Float>
  public var scalar: Float
  public var velocityMetersPerSecond: SIMD3<Float>
  public var vorticityPerSecond: SIMD3<Float>

  public init(
    worldMeters: SIMD3<Float>,
    scalar: Float,
    velocityMetersPerSecond: SIMD3<Float>,
    vorticityPerSecond: SIMD3<Float>
  ) {
    self.worldMeters = worldMeters
    self.scalar = scalar
    self.velocityMetersPerSecond = velocityMetersPerSecond
    self.vorticityPerSecond = vorticityPerSecond
  }
}

public struct OffscreenVisualizationDiagnostics: Sendable, Equatable {
  public var maximumAbsolutePressure: Float
  public var maximumQCriterion: Float
  public var qSurfaceOverflow: Bool

  public init(
    maximumAbsolutePressure: Float,
    maximumQCriterion: Float,
    qSurfaceOverflow: Bool
  ) {
    self.maximumAbsolutePressure = maximumAbsolutePressure
    self.maximumQCriterion = maximumQCriterion
    self.qSurfaceOverflow = qSurfaceOverflow
  }
}

private struct DiagnosticResources {
  let vorticity: MTLBuffer
  let q: MTLBuffer
  let valid: MTLBuffer
  let cellCount: Int
}

private struct IsoResources {
  let counts: MTLBuffer
  let offsets: MTLBuffer
  let blockSums: MTLBuffer
  let blockOffsets: MTLBuffer
  let vertices: MTLBuffer
  let indirect: MTLBuffer
  let overflow: MTLBuffer
  let cubeCount: Int
  let blockCount: Int
  let capacity: Int
}

public final class MetalVisualizationRenderer: NSObject, MTKViewDelegate, @unchecked Sendable {
  public let liveSimulation: LiveSimulation

  private let backend: VisualizationBackend
  private let inFlight = DispatchSemaphore(value: 1)
  private let stateLock = NSLock()
  private var settingsValue = VisualizationSettings()
  private var cameraValue = CameraState()
  private var metricsHandler: (@Sendable (VisualizationMetrics) -> Void)?
  private var errorHandler: (@Sendable (String) -> Void)?
  private var pendingDerivedURL: URL?
  private var probeUV = SIMD2<Float>(0.5, 0.5)

  private let pressurePipeline: MTLComputePipelineState
  private let slicePipeline: MTLComputePipelineState
  private let diagnosticsPipeline: MTLComputePipelineState
  private let qStatisticsPipeline: MTLComputePipelineState
  private let tracerPipeline: MTLComputePipelineState
  private let classifyPipeline: MTLComputePipelineState
  private let scanPipeline: MTLComputePipelineState
  private let scanBlocksPipeline: MTLComputePipelineState
  private let addOffsetsPipeline: MTLComputePipelineState
  private let prepareDrawPipeline: MTLComputePipelineState
  private let emitIsoPipeline: MTLComputePipelineState
  private let marchingCubesTable: MTLBuffer

  private var surfaceRenderPipeline: MTLRenderPipelineState?
  private var sliceRenderPipeline: MTLRenderPipelineState?
  private var ribbonRenderPipeline: MTLRenderPipelineState?
  private var isoRenderPipeline: MTLRenderPipelineState?
  private let depthWriteState: MTLDepthStencilState
  private let depthReadState: MTLDepthStencilState

  private var surfaceInput: MTLBuffer?
  private var surfaceOutput: MTLBuffer?
  private var surfaceVertexCount = 0
  private let pressureStats: MTLBuffer
  private let sliceProbe: MTLBuffer
  private let qStatistics: MTLBuffer
  private var sliceTexture: MTLTexture?
  private var tracerStates: MTLBuffer?
  private var tracerHistory: MTLBuffer?
  private var tracerShape = (count: 0, history: 0)
  private var diagnostics: DiagnosticResources?
  private var iso: IsoResources?
  private var lastDisplayedStep: UInt64?
  private var lastFieldTime: Float?
  private var lastPublicationUptimeSeconds: Double?
  private var lastFrameWallTime = Date()
  private var latestUniforms: VisualizationUniforms?
  private var lastMetadata: GPUFieldFrameMetadata?
  private var lastIsoThreshold: Float?
  private var lastIsoCapacity: Int?
  private var automaticPressureRange: Float = 120
  private var automaticPressureUnit: PressureUnit = .pascals

  public init(liveSimulation: LiveSimulation) throws {
    self.liveSimulation = liveSimulation
    backend = try VisualizationBackend(device: liveSimulation.simulation.metalDevice)
    pressurePipeline = try backend.compute("samplePressureSurface")
    slicePipeline = try backend.compute("renderFlowSlice")
    diagnosticsPipeline = try backend.compute("deriveFlowDiagnostics")
    qStatisticsPipeline = try backend.compute("summarizeQCriterion")
    tracerPipeline = try backend.compute("advectTracerRibbons")
    classifyPipeline = try backend.compute("classifyQCriterionCubes")
    scanPipeline = try backend.compute("scanTriangleBlocks")
    scanBlocksPipeline = try backend.compute("scanBlockSums")
    addOffsetsPipeline = try backend.compute("addTriangleBlockOffsets")
    prepareDrawPipeline = try backend.compute("prepareQCriterionIndirectDraw")
    emitIsoPipeline = try backend.compute("emitQCriterionCubes")
    marchingCubesTable = try MarchingCubesLookup.makeBuffer(device: backend.device)
    pressureStats = try backend.buffer(length: 257 * 4, shared: true)
    sliceProbe = try backend.buffer(
      length: MemoryLayout<SliceProbeOutput>.stride,
      shared: true
    )
    qStatistics = try backend.buffer(length: 257 * 4, shared: true)

    let writeDescriptor = MTLDepthStencilDescriptor()
    writeDescriptor.depthCompareFunction = .less
    writeDescriptor.isDepthWriteEnabled = true
    depthWriteState = backend.device.makeDepthStencilState(
      descriptor: writeDescriptor
    )!
    let readDescriptor = MTLDepthStencilDescriptor()
    readDescriptor.depthCompareFunction = .lessEqual
    readDescriptor.isDepthWriteEnabled = false
    depthReadState = backend.device.makeDepthStencilState(
      descriptor: readDescriptor
    )!
    super.init()
  }

  @MainActor
  public func configure(_ view: MTKView) throws {
    view.device = backend.device
    view.colorPixelFormat = .bgra8Unorm_srgb
    view.depthStencilPixelFormat = .depth32Float
    view.sampleCount = 1
    view.preferredFramesPerSecond = 60
    view.enableSetNeedsDisplay = false
    view.isPaused = false
    view.clearColor = MTLClearColorMake(0.012, 0.018, 0.032, 1)
    view.delegate = self
    try configureRenderPipelines(colorFormat: view.colorPixelFormat)
  }

  private func configureRenderPipelines(
    colorFormat: MTLPixelFormat
  ) throws {
    surfaceRenderPipeline = try backend.render(
      vertex: "coloredSurfaceVertex",
      fragment: "litFragment",
      colorFormat: colorFormat
    )
    sliceRenderPipeline = try backend.render(
      vertex: "sliceVertex",
      fragment: "sliceFragment",
      colorFormat: colorFormat,
      blending: true
    )
    ribbonRenderPipeline = try backend.render(
      vertex: "ribbonVertex",
      fragment: "unlitFragment",
      colorFormat: colorFormat,
      blending: true
    )
    isoRenderPipeline = try backend.render(
      vertex: "isoSurfaceVertex",
      fragment: "isoFragment",
      colorFormat: colorFormat,
      blending: true
    )
  }

  public func setHandlers(
    metrics: (@Sendable (VisualizationMetrics) -> Void)?,
    error: (@Sendable (String) -> Void)?
  ) {
    stateLock.lock()
    metricsHandler = metrics
    errorHandler = error
    stateLock.unlock()
  }

  public var settings: VisualizationSettings {
    get {
      stateLock.lock()
      defer { stateLock.unlock() }
      return settingsValue
    }
    set {
      stateLock.lock()
      settingsValue = newValue
      stateLock.unlock()
    }
  }

  public var camera: CameraState {
    get {
      stateLock.lock()
      defer { stateLock.unlock() }
      return cameraValue
    }
    set {
      stateLock.lock()
      cameraValue = newValue
      stateLock.unlock()
    }
  }

  public func orbit(deltaX: Float, deltaY: Float) {
    stateLock.lock()
    cameraValue.yaw -= deltaX * 0.008
    cameraValue.pitch = min(max(cameraValue.pitch + deltaY * 0.008, -1.45), 1.45)
    stateLock.unlock()
  }

  public func zoom(delta: Float) {
    stateLock.lock()
    cameraValue.distance = min(max(cameraValue.distance * exp(delta * 0.002), 0.05), 20)
    stateLock.unlock()
  }

  public func pan(deltaX: Float, deltaY: Float) {
    stateLock.lock()
    let eye = cameraValue.eye
    let forward = simd_normalize(cameraValue.target - eye)
    let right = simd_normalize(simd_cross(forward, SIMD3<Float>(0, 0, 1)))
    let up = simd_normalize(simd_cross(right, forward))
    let scale = cameraValue.distance * 0.0015
    cameraValue.target += (-deltaX * right + deltaY * up) * scale
    stateLock.unlock()
  }

  public func requestDerivedFieldKeyframe(to url: URL) {
    stateLock.lock()
    pendingDerivedURL = url
    stateLock.unlock()
  }

  public func setSliceProbe(normalized uv: SIMD2<Float>) {
    stateLock.lock()
    probeUV = SIMD2<Float>(
      min(max(uv.x, 0), 1),
      min(max(uv.y, 0), 1)
    )
    stateLock.unlock()
  }

  /// Renders a finite diagnostic frame without attaching a view or reading
  /// solver volumes back to the CPU. Consecutive calls retain GPU tracer
  /// history, making this path suitable for deterministic presentation
  /// capture as well as smoke tests and image verification tooling.
  public func renderOffscreen(width: Int = 640, height: Int = 480) throws -> MTLTexture {
    guard width > 0, height > 0 else {
      throw VisualizationError.allocation(0)
    }
    inFlight.wait()
    defer { inFlight.signal() }
    try configureRenderPipelines(colorFormat: .bgra8Unorm_srgb)

    let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm_srgb,
      width: width,
      height: height,
      mipmapped: false
    )
    colorDescriptor.storageMode = .shared
    colorDescriptor.usage = [.renderTarget, .shaderRead]
    let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .depth32Float,
      width: width,
      height: height,
      mipmapped: false
    )
    depthDescriptor.storageMode = .private
    depthDescriptor.usage = [.renderTarget]
    guard let color = backend.device.makeTexture(descriptor: colorDescriptor),
      let depth = backend.device.makeTexture(descriptor: depthDescriptor),
      let commandBuffer = backend.queue.makeCommandBuffer()
    else {
      throw VisualizationError.allocation(width * height * 8)
    }

    stateLock.lock()
    var settings = settingsValue
    let camera = cameraValue
    let probeUV = probeUV
    stateLock.unlock()
    applyAutomaticPressureRange(to: &settings)
    guard let lease = liveSimulation.acquireLatestField(afterStep: nil) else {
      throw RunBundleError.derivedFieldsUnavailable
    }
    do {
      let metadata = lease.metadata
      let (sliceCenter, sliceU, sliceV) = sliceFrame(
        metadata: metadata,
        settings: settings
      )
      let tracerDeltaTime = lastFieldTime.map {
        max(0, metadata.snapshot.timeSeconds - $0)
      } ?? 0
      let resetTracers = lastFieldTime == nil || tracerDeltaTime <= 0
      var uniforms = VisualizationUniforms(
        metadata: metadata,
        settings: settings,
        sliceCenter: sliceCenter,
        sliceU: sliceU,
        sliceV: sliceV,
        tracerDeltaTime: tracerDeltaTime,
        resetTracers: resetTracers,
        probeUV: probeUV
      )
      try encodeFieldUpdates(
        lease: lease,
        metadata: metadata,
        settings: settings,
        uniforms: &uniforms,
        derivedURL: nil,
        commandBuffer: commandBuffer
      )
      let pass = MTLRenderPassDescriptor()
      pass.colorAttachments[0].texture = color
      pass.colorAttachments[0].loadAction = .clear
      pass.colorAttachments[0].storeAction = .store
      pass.colorAttachments[0].clearColor = MTLClearColorMake(0.012, 0.018, 0.032, 1)
      pass.depthAttachment.texture = depth
      pass.depthAttachment.loadAction = .clear
      pass.depthAttachment.storeAction = .dontCare
      pass.depthAttachment.clearDepth = 1
      try encodeRender(
        drawableSize: CGSize(width: width, height: height),
        pass: pass,
        settings: settings,
        camera: camera,
        uniforms: uniforms,
        commandBuffer: commandBuffer
      )
      lease.releaseAfterCompletion(of: commandBuffer)
      commandBuffer.commit()
      commandBuffer.waitUntilCompleted()
      guard commandBuffer.status == .completed else {
        throw VisualizationError.shader(
          commandBuffer.error?.localizedDescription
            ?? "offscreen render did not complete"
        )
      }
      lastDisplayedStep = metadata.snapshot.step
      lastFieldTime = metadata.snapshot.timeSeconds
      lastPublicationUptimeSeconds = metadata.publicationUptimeSeconds
      latestUniforms = uniforms
      lastMetadata = metadata
      return color
    } catch {
      lease.releaseImmediately()
      throw error
    }
  }

  /// Compact readback from the most recently completed offscreen frame. This
  /// never reads a solver volume and is intended for capture verification.
  public func offscreenDiagnostics() -> OffscreenVisualizationDiagnostics {
    let pressureBits = pressureStats.contents()
      .assumingMemoryBound(to: UInt32.self).pointee
    let qBits = qStatistics.contents()
      .assumingMemoryBound(to: UInt32.self).pointee
    let overflow = iso?.overflow.contents()
      .assumingMemoryBound(to: UInt32.self).pointee == 1
    return OffscreenVisualizationDiagnostics(
      maximumAbsolutePressure: Float(bitPattern: pressureBits),
      maximumQCriterion: Float(bitPattern: qBits),
      qSurfaceOverflow: overflow
    )
  }

  public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    sliceTexture = nil
  }

  public func draw(in view: MTKView) {
    guard inFlight.wait(timeout: .now()) == .success else { return }
    guard let drawable = view.currentDrawable,
      let pass = view.currentRenderPassDescriptor,
      let commandBuffer = backend.queue.makeCommandBuffer()
    else {
      inFlight.signal()
      return
    }

    stateLock.lock()
    var settings = settingsValue
    let camera = cameraValue
    let probeUV = probeUV
    let derivedURL = pendingDerivedURL
    pendingDerivedURL = nil
    let metricsCallback = metricsHandler
    let errors = errorHandler
    stateLock.unlock()
    applyAutomaticPressureRange(to: &settings)

    let lease = liveSimulation.acquireLatestField(afterStep: lastDisplayedStep)
    do {
      if let lease {
        let metadata = lease.metadata
        let (sliceCenter, sliceU, sliceV) = sliceFrame(
          metadata: metadata,
          settings: settings
        )
        let delta =
          lastFieldTime.map {
            max(0, metadata.snapshot.timeSeconds - $0)
          } ?? 0
        let resetTracers = lastFieldTime == nil || delta <= 0
        var uniforms = VisualizationUniforms(
          metadata: metadata,
          settings: settings,
          sliceCenter: sliceCenter,
          sliceU: sliceU,
          sliceV: sliceV,
          tracerDeltaTime: delta,
          resetTracers: resetTracers,
          probeUV: probeUV
        )
        latestUniforms = uniforms
        lastMetadata = metadata
        try encodeFieldUpdates(
          lease: lease,
          metadata: metadata,
          settings: settings,
          uniforms: &uniforms,
          derivedURL: derivedURL,
          commandBuffer: commandBuffer
        )
        lastDisplayedStep = metadata.snapshot.step
        lastFieldTime = metadata.snapshot.timeSeconds
        lastPublicationUptimeSeconds = metadata.publicationUptimeSeconds
      } else if derivedURL != nil {
        errors?(RunBundleError.derivedFieldsUnavailable.description)
      }

      if lease == nil, let metadata = lastMetadata {
        let (sliceCenter, sliceU, sliceV) = sliceFrame(
          metadata: metadata,
          settings: settings
        )
        var updated = VisualizationUniforms(
          metadata: metadata,
          settings: settings,
          sliceCenter: sliceCenter,
          sliceU: sliceU,
          sliceV: sliceV,
          tracerDeltaTime: 0,
          resetTracers: false,
          probeUV: probeUV
        )
        latestUniforms = updated
        if settings.showQCriterion,
          diagnostics != nil,
          lastIsoThreshold != settings.qThreshold
            || lastIsoCapacity != settings.qTriangleCapacity
        {
          try ensureIsoResources(metadata: metadata, settings: settings)
          encodeIsoSurface(
            uniforms: &updated,
            commandBuffer: commandBuffer
          )
          lastIsoThreshold = settings.qThreshold
          lastIsoCapacity = settings.qTriangleCapacity
        }
      }

      guard let uniforms = latestUniforms else {
        commandBuffer.commit()
        inFlight.signal()
        return
      }
      try encodeRender(
        drawableSize: view.drawableSize,
        pass: pass,
        settings: settings,
        camera: camera,
        uniforms: uniforms,
        commandBuffer: commandBuffer
      )
      commandBuffer.present(drawable)
      lease?.releaseAfterCompletion(of: commandBuffer)
      let step = lastDisplayedStep ?? 0
      let publicationUptimeSeconds = lastPublicationUptimeSeconds
      let wallStart = Date()
      let renderSettings = settings
      commandBuffer.addCompletedHandler { [weak self] buffer in
        guard let self else { return }
        var metrics = VisualizationMetrics()
        metrics.displayedStep = step
        if let publicationUptimeSeconds {
          metrics.frameAgeMilliseconds = max(
            0,
            1_000
              * (ProcessInfo.processInfo.systemUptime - publicationUptimeSeconds)
          )
        }
        let elapsed = max(wallStart.timeIntervalSince(self.lastFrameWallTime), 1e-6)
        metrics.renderFPS = 1 / elapsed
        self.lastFrameWallTime = wallStart
        if buffer.gpuEndTime > buffer.gpuStartTime {
          metrics.rendererGPUTimeMilliseconds =
            1_000
            * (buffer.gpuEndTime - buffer.gpuStartTime)
        }
        let bits = self.pressureStats.contents()
          .assumingMemoryBound(to: UInt32.self).pointee
        metrics.pressureRangePascals = Float(bitPattern: bits)
        metrics.pressureLegendRange =
          renderSettings.pressureUnit == .pascals
          ? renderSettings.pressureRangePascals
          : renderSettings.pressureRangeCoefficient
        let histogram = self.pressureStats.contents()
          .assumingMemoryBound(to: UInt32.self)
        var total: UInt64 = 0
        for bin in 0..<256 { total += UInt64(histogram[bin + 1]) }
        if total > 0 {
          let target = UInt64(
            ceil(
              Double(total) * Double(renderSettings.pressureAutoscalePercentile)
            ))
          var cumulative: UInt64 = 0
          for bin in 0..<256 {
            cumulative += UInt64(histogram[bin + 1])
            if cumulative >= target {
              let minimum: Float =
                renderSettings.pressureUnit == .pascals ? 0.1 : 0.001
              let currentRange =
                renderSettings.pressureUnit == .pascals
                ? renderSettings.pressureRangePascals
                : renderSettings.pressureRangeCoefficient
              var percentileRange = currentRange * Float(bin + 1) / 256
              if bin == 255, metrics.pressureRangePascals > currentRange {
                percentileRange = min(
                  metrics.pressureRangePascals,
                  currentRange * 2
                )
              }
              self.automaticPressureRange = max(minimum, percentileRange)
              self.automaticPressureUnit = renderSettings.pressureUnit
              break
            }
          }
        }
        let probe = self.sliceProbe.contents()
          .assumingMemoryBound(to: SliceProbeOutput.self)
          .pointee
        metrics.sliceProbe = SliceProbe(
          worldMeters: probe.worldAndScalar.xyz,
          scalar: probe.worldAndScalar.w,
          velocityMetersPerSecond: probe.velocity.xyz,
          vorticityPerSecond: probe.vorticity.xyz
        )
        let qHistogram = self.qStatistics.contents()
          .assumingMemoryBound(to: UInt32.self)
        var qTotal: UInt64 = 0
        for bin in 0..<256 { qTotal += UInt64(qHistogram[bin + 1]) }
        if qTotal > 0 {
          let target = UInt64(ceil(Double(qTotal) * 0.90))
          var cumulative: UInt64 = 0
          for bin in 0..<256 {
            cumulative += UInt64(qHistogram[bin + 1])
            if cumulative >= target {
              metrics.qSuggestedThreshold =
                renderSettings.qThreshold
                * 10 * Float(bin + 1) / 256
              break
            }
          }
        }
        metrics.qSurfaceOverflow =
          self.iso?.overflow.contents()
          .assumingMemoryBound(to: UInt32.self).pointee == 1
        metricsCallback?(metrics)
        self.inFlight.signal()
      }
      commandBuffer.commit()
    } catch {
      lease?.releaseImmediately()
      inFlight.signal()
      errors?(String(describing: error))
    }
  }

  private func encodeFieldUpdates(
    lease: GPUFieldFrameLease,
    metadata: GPUFieldFrameMetadata,
    settings: VisualizationSettings,
    uniforms: inout VisualizationUniforms,
    derivedURL: URL?,
    commandBuffer: MTLCommandBuffer
  ) throws {
    if settings.showPressureSurface {
      let vertices = BirdSurfaceMesh.vertices(for: metadata)
      try ensureSurfaceCapacity(vertices.count)
      vertices.withUnsafeBytes { source in
        _ = memcpy(surfaceInput!.contents(), source.baseAddress!, source.count)
      }
      memset(pressureStats.contents(), 0, pressureStats.length)
      let encoder = commandBuffer.makeComputeCommandEncoder()!
      encoder.label = "Pressure-colored bird surface"
      lease.bindMacroscopicFields(to: encoder, densityIndex: 0, velocityIndex: 1)
      encoder.setBuffer(surfaceInput, offset: 0, index: 2)
      encoder.setBuffer(surfaceOutput, offset: 0, index: 3)
      encoder.setBuffer(pressureStats, offset: 0, index: 4)
      encoder.setBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 5
      )
      backend.dispatch1D(encoder, pipeline: pressurePipeline, count: vertices.count)
      encoder.endEncoding()
      surfaceVertexCount = vertices.count
    }

    if settings.showSlice {
      try ensureSliceTexture()
      let encoder = commandBuffer.makeComputeCommandEncoder()!
      encoder.label = "Interactive velocity and vorticity slice"
      lease.bindMacroscopicFields(to: encoder, densityIndex: 0, velocityIndex: 1)
      encoder.setBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 2
      )
      encoder.setTexture(sliceTexture, index: 0)
      encoder.setBuffer(sliceProbe, offset: 0, index: 3)
      encoder.setComputePipelineState(slicePipeline)
      encoder.dispatchThreads(
        MTLSize(width: sliceTexture!.width, height: sliceTexture!.height, depth: 1),
        threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1)
      )
      encoder.endEncoding()
    }

    if settings.showRibbons {
      try ensureTracerResources(settings: settings)
      let encoder = commandBuffer.makeComputeCommandEncoder()!
      encoder.label = "CFL-limited GPU tracer pathlines"
      lease.bindMacroscopicFields(to: encoder, densityIndex: 0, velocityIndex: 1)
      encoder.setBuffer(tracerStates, offset: 0, index: 2)
      encoder.setBuffer(tracerHistory, offset: 0, index: 3)
      encoder.setBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 4
      )
      backend.dispatch1D(
        encoder,
        pipeline: tracerPipeline,
        count: settings.tracerCount
      )
      encoder.endEncoding()
    }

    if settings.showQCriterion || derivedURL != nil {
      try ensureDiagnosticResources(cellCount: metadata.grid.cellCount)
      let encoder = commandBuffer.makeComputeCommandEncoder()!
      encoder.label = "Verified physical vorticity and Q fields"
      lease.bindMacroscopicFields(to: encoder, densityIndex: 0, velocityIndex: 1)
      encoder.setBuffer(diagnostics!.vorticity, offset: 0, index: 2)
      encoder.setBuffer(diagnostics!.q, offset: 0, index: 3)
      encoder.setBuffer(diagnostics!.valid, offset: 0, index: 4)
      encoder.setBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 5
      )
      backend.dispatch1D(
        encoder,
        pipeline: diagnosticsPipeline,
        count: metadata.grid.cellCount
      )
      encoder.endEncoding()

      memset(qStatistics.contents(), 0, qStatistics.length)
      let statistics = commandBuffer.makeComputeCommandEncoder()!
      statistics.label = "Positive Q percentile assistance"
      statistics.setBuffer(diagnostics!.q, offset: 0, index: 0)
      statistics.setBuffer(diagnostics!.valid, offset: 0, index: 1)
      statistics.setBuffer(qStatistics, offset: 0, index: 2)
      statistics.setBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 3
      )
      backend.dispatch1D(
        statistics,
        pipeline: qStatisticsPipeline,
        count: metadata.grid.cellCount
      )
      statistics.endEncoding()
    }

    if settings.showQCriterion {
      try ensureIsoResources(metadata: metadata, settings: settings)
      encodeIsoSurface(uniforms: &uniforms, commandBuffer: commandBuffer)
      lastIsoThreshold = settings.qThreshold
      lastIsoCapacity = settings.qTriangleCapacity
    }

    if let derivedURL, let diagnostics {
      let vorticityStaging = try backend.buffer(
        length: diagnostics.vorticity.length,
        shared: true
      )
      let qStaging = try backend.buffer(length: diagnostics.q.length, shared: true)
      let validStaging = try backend.buffer(
        length: diagnostics.valid.length,
        shared: true
      )
      let blit = commandBuffer.makeBlitCommandEncoder()!
      blit.label = "Explicit derived-field keyframe readback"
      blit.copy(
        from: diagnostics.vorticity, sourceOffset: 0,
        to: vorticityStaging, destinationOffset: 0,
        size: diagnostics.vorticity.length
      )
      blit.copy(
        from: diagnostics.q, sourceOffset: 0,
        to: qStaging, destinationOffset: 0,
        size: diagnostics.q.length
      )
      blit.copy(
        from: diagnostics.valid, sourceOffset: 0,
        to: validStaging, destinationOffset: 0,
        size: diagnostics.valid.length
      )
      blit.endEncoding()
      commandBuffer.addCompletedHandler { _ in
        let vorticity = Data(
          bytes: vorticityStaging.contents(),
          count: vorticityStaging.length
        )
        let qCriterion = Data(
          bytes: qStaging.contents(),
          count: qStaging.length
        )
        let validMask = Data(
          bytes: validStaging.contents(),
          count: validStaging.length
        )
        DispatchQueue.global(qos: .utility).async {
          do {
            try DerivedFieldArchive.write(
              vorticity: vorticity,
              qCriterion: qCriterion,
              validMask: validMask,
              metadata: metadata,
              to: derivedURL
            )
          } catch {
            self.stateLock.lock()
            let handler = self.errorHandler
            self.stateLock.unlock()
            handler?(String(describing: error))
          }
        }
      }
    }
  }

  private func encodeRender(
    drawableSize: CGSize,
    pass: MTLRenderPassDescriptor,
    settings: VisualizationSettings,
    camera: CameraState,
    uniforms: VisualizationUniforms,
    commandBuffer: MTLCommandBuffer
  ) throws {
    var cameraUniforms = camera.uniforms(
      aspect: Float(drawableSize.width / max(drawableSize.height, 1)),
      ribbonWidth: settings.ribbonWidthMeters
    )
    var uniforms = uniforms
    let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)!
    encoder.label = "BirdFlow scientific viewer"
    encoder.setCullMode(.none)
    if settings.showPressureSurface,
      let surfaceOutput,
      let surfaceRenderPipeline,
      surfaceVertexCount > 0
    {
      encoder.setDepthStencilState(depthWriteState)
      encoder.setRenderPipelineState(surfaceRenderPipeline)
      encoder.setVertexBuffer(surfaceOutput, offset: 0, index: 0)
      encoder.setVertexBytes(
        &cameraUniforms,
        length: MemoryLayout<CameraUniforms>.stride,
        index: 1
      )
      encoder.drawPrimitives(
        type: .triangle,
        vertexStart: 0,
        vertexCount: surfaceVertexCount
      )
    }
    if settings.showQCriterion,
      let iso,
      let isoRenderPipeline
    {
      encoder.setDepthStencilState(depthReadState)
      encoder.setRenderPipelineState(isoRenderPipeline)
      encoder.setVertexBuffer(iso.vertices, offset: 0, index: 0)
      encoder.setVertexBytes(
        &cameraUniforms,
        length: MemoryLayout<CameraUniforms>.stride,
        index: 1
      )
      encoder.setVertexBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 2
      )
      encoder.setFragmentBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 0
      )
      encoder.drawPrimitives(
        type: .triangle,
        indirectBuffer: iso.indirect,
        indirectBufferOffset: 0
      )
    }
    if settings.showSlice,
      let sliceTexture,
      let sliceRenderPipeline
    {
      encoder.setDepthStencilState(depthReadState)
      encoder.setRenderPipelineState(sliceRenderPipeline)
      encoder.setVertexBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 0
      )
      encoder.setVertexBytes(
        &cameraUniforms,
        length: MemoryLayout<CameraUniforms>.stride,
        index: 1
      )
      encoder.setFragmentTexture(sliceTexture, index: 0)
      encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    if settings.showRibbons,
      let tracerHistory,
      let ribbonRenderPipeline
    {
      encoder.setDepthStencilState(depthReadState)
      encoder.setRenderPipelineState(ribbonRenderPipeline)
      encoder.setVertexBuffer(tracerHistory, offset: 0, index: 0)
      encoder.setVertexBytes(
        &cameraUniforms,
        length: MemoryLayout<CameraUniforms>.stride,
        index: 1
      )
      var historyLength = UInt32(settings.tracerHistory)
      encoder.setVertexBytes(
        &historyLength,
        length: MemoryLayout<UInt32>.stride,
        index: 3
      )
      encoder.setVertexBytes(
        &uniforms,
        length: MemoryLayout<VisualizationUniforms>.stride,
        index: 4
      )
      for tracer in 0..<settings.tracerCount {
        var index = UInt32(tracer)
        encoder.setVertexBytes(
          &index,
          length: MemoryLayout<UInt32>.stride,
          index: 2
        )
        encoder.drawPrimitives(
          type: .triangleStrip,
          vertexStart: 0,
          vertexCount: settings.tracerHistory * 2
        )
      }
    }
    encoder.endEncoding()
  }

  private func encodeIsoSurface(
    uniforms: inout VisualizationUniforms,
    commandBuffer: MTLCommandBuffer
  ) {
    guard let diagnostics, let iso else { return }
    var cubeCount = UInt32(iso.cubeCount)
    var blockCount = UInt32(iso.blockCount)
    var countAndCapacity = SIMD2<UInt32>(
      cubeCount,
      UInt32(iso.capacity)
    )
    let classify = commandBuffer.makeComputeCommandEncoder()!
    classify.setBuffer(diagnostics.q, offset: 0, index: 0)
    classify.setBuffer(diagnostics.valid, offset: 0, index: 1)
    classify.setBuffer(iso.counts, offset: 0, index: 2)
    classify.setBytes(
      &uniforms,
      length: MemoryLayout<VisualizationUniforms>.stride,
      index: 3
    )
    classify.setBuffer(marchingCubesTable, offset: 0, index: 4)
    backend.dispatch1D(classify, pipeline: classifyPipeline, count: iso.cubeCount)
    classify.endEncoding()

    let scan = commandBuffer.makeComputeCommandEncoder()!
    scan.setComputePipelineState(scanPipeline)
    scan.setBuffer(iso.counts, offset: 0, index: 0)
    scan.setBuffer(iso.offsets, offset: 0, index: 1)
    scan.setBuffer(iso.blockSums, offset: 0, index: 2)
    scan.setBytes(&cubeCount, length: 4, index: 3)
    scan.dispatchThreadgroups(
      MTLSize(width: iso.blockCount, height: 1, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 256, height: 1, depth: 1)
    )
    scan.endEncoding()

    let blocks = commandBuffer.makeComputeCommandEncoder()!
    blocks.setBuffer(iso.blockSums, offset: 0, index: 0)
    blocks.setBuffer(iso.blockOffsets, offset: 0, index: 1)
    blocks.setBytes(&blockCount, length: 4, index: 2)
    backend.dispatch1D(blocks, pipeline: scanBlocksPipeline, count: 1)
    blocks.endEncoding()

    let add = commandBuffer.makeComputeCommandEncoder()!
    add.setBuffer(iso.offsets, offset: 0, index: 0)
    add.setBuffer(iso.blockOffsets, offset: 0, index: 1)
    add.setBytes(&cubeCount, length: 4, index: 2)
    backend.dispatch1D(add, pipeline: addOffsetsPipeline, count: iso.cubeCount)
    add.endEncoding()

    let prepare = commandBuffer.makeComputeCommandEncoder()!
    prepare.setBuffer(iso.counts, offset: 0, index: 0)
    prepare.setBuffer(iso.offsets, offset: 0, index: 1)
    prepare.setBuffer(iso.indirect, offset: 0, index: 2)
    prepare.setBuffer(iso.overflow, offset: 0, index: 3)
    prepare.setBytes(
      &countAndCapacity,
      length: MemoryLayout<SIMD2<UInt32>>.stride,
      index: 4
    )
    backend.dispatch1D(prepare, pipeline: prepareDrawPipeline, count: 1)
    prepare.endEncoding()

    let emit = commandBuffer.makeComputeCommandEncoder()!
    emit.setBuffer(diagnostics.q, offset: 0, index: 0)
    emit.setBuffer(diagnostics.valid, offset: 0, index: 1)
    emit.setBuffer(iso.counts, offset: 0, index: 2)
    emit.setBuffer(iso.offsets, offset: 0, index: 3)
    emit.setBuffer(iso.vertices, offset: 0, index: 4)
    emit.setBytes(
      &uniforms,
      length: MemoryLayout<VisualizationUniforms>.stride,
      index: 5
    )
    emit.setBuffer(diagnostics.vorticity, offset: 0, index: 6)
    emit.setBuffer(marchingCubesTable, offset: 0, index: 7)
    backend.dispatch1D(emit, pipeline: emitIsoPipeline, count: iso.cubeCount)
    emit.endEncoding()
  }

  private func ensureSurfaceCapacity(_ count: Int) throws {
    let inputBytes = count * MemoryLayout<SurfaceVertex>.stride
    let outputBytes = count * MemoryLayout<ColoredVertex>.stride
    if surfaceInput?.length ?? 0 < inputBytes {
      surfaceInput = try backend.buffer(length: inputBytes, shared: true)
    }
    if surfaceOutput?.length ?? 0 < outputBytes {
      surfaceOutput = try backend.buffer(length: outputBytes)
    }
  }

  private func ensureSliceTexture() throws {
    guard sliceTexture == nil else { return }
    let descriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba16Float,
      width: 768,
      height: 768,
      mipmapped: false
    )
    descriptor.usage = [.shaderRead, .shaderWrite]
    descriptor.storageMode = .private
    sliceTexture = backend.device.makeTexture(descriptor: descriptor)
    if sliceTexture == nil { throw VisualizationError.allocation(768 * 768 * 8) }
  }

  private func ensureTracerResources(settings: VisualizationSettings) throws {
    let shape = (settings.tracerCount, settings.tracerHistory)
    guard tracerStates == nil || tracerShape != shape else { return }
    tracerStates = try backend.buffer(
      length: settings.tracerCount * MemoryLayout<TracerState>.stride,
      shared: true
    )
    tracerHistory = try backend.buffer(
      length: settings.tracerCount * settings.tracerHistory
        * MemoryLayout<SIMD4<Float>>.stride
    )
    tracerShape = shape
    lastFieldTime = nil
  }

  private func ensureDiagnosticResources(cellCount: Int) throws {
    guard diagnostics?.cellCount != cellCount else { return }
    diagnostics = DiagnosticResources(
      vorticity: try backend.buffer(
        length: cellCount * MemoryLayout<SIMD4<Float>>.stride
      ),
      q: try backend.buffer(length: cellCount * MemoryLayout<Float>.stride),
      valid: try backend.buffer(length: cellCount),
      cellCount: cellCount
    )
    iso = nil
  }

  private func ensureIsoResources(
    metadata: GPUFieldFrameMetadata,
    settings: VisualizationSettings
  ) throws {
    let cubeCount =
      (metadata.grid.x - 1)
      * (metadata.grid.y - 1)
      * (metadata.grid.z - 1)
    let capacity = max(1, settings.qTriangleCapacity)
    if let iso, iso.cubeCount == cubeCount, iso.capacity == capacity { return }
    let blockCount = (cubeCount + 255) / 256
    iso = IsoResources(
      counts: try backend.buffer(length: cubeCount * 4),
      offsets: try backend.buffer(length: cubeCount * 4),
      blockSums: try backend.buffer(length: blockCount * 4),
      blockOffsets: try backend.buffer(length: blockCount * 4),
      vertices: try backend.buffer(
        length: capacity * 3 * MemoryLayout<IsoVertex>.stride
      ),
      indirect: try backend.buffer(
        length: MemoryLayout<DrawPrimitivesIndirectArguments>.stride,
        shared: true
      ),
      overflow: try backend.buffer(length: 16, shared: true),
      cubeCount: cubeCount,
      blockCount: blockCount,
      capacity: capacity
    )
  }

  private func sliceFrame(
    metadata: GPUFieldFrameMetadata,
    settings: VisualizationSettings
  ) -> (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) {
    let u: SIMD3<Float>
    let v: SIMD3<Float>
    switch settings.sliceSnap {
    case .x:
      u = SIMD3<Float>(0, 1, 0)
      v = SIMD3<Float>(0, 0, 1)
    case .y:
      u = SIMD3<Float>(0, 0, 1)
      v = SIMD3<Float>(1, 0, 0)
    case .z:
      u = SIMD3<Float>(1, 0, 0)
      v = SIMD3<Float>(0, 1, 0)
    case .oblique:
      let normal = SIMD3<Float>(
        cos(settings.slicePitchRadians) * cos(settings.sliceYawRadians),
        cos(settings.slicePitchRadians) * sin(settings.sliceYawRadians),
        sin(settings.slicePitchRadians)
      )
      let reference =
        abs(normal.z) < 0.9
        ? SIMD3<Float>(0, 0, 1)
        : SIMD3<Float>(0, 1, 0)
      u = simd_normalize(simd_cross(reference, normal))
      v = simd_normalize(simd_cross(normal, u))
    }
    let normal = simd_normalize(simd_cross(u, v))
    let domain =
      SIMD3<Float>(
        Float(metadata.grid.x),
        Float(metadata.grid.y),
        Float(metadata.grid.z)
      ) * metadata.cellSizeMeters
    let center = metadata.domainOriginMeters + 0.5 * domain
    let support = 0.5 * simd_dot(absolute(normal), domain)
    return (
      center + (2 * settings.slicePosition - 1) * support * normal,
      u,
      v
    )
  }

  private func applyAutomaticPressureRange(
    to settings: inout VisualizationSettings
  ) {
    guard !settings.pressureRangeLocked,
      automaticPressureUnit == settings.pressureUnit
    else { return }
    if settings.pressureUnit == .pascals {
      settings.pressureRangePascals = automaticPressureRange
    } else {
      settings.pressureRangeCoefficient = automaticPressureRange
    }
  }
}

private func absolute(_ value: SIMD3<Float>) -> SIMD3<Float> {
  SIMD3<Float>(abs(value.x), abs(value.y), abs(value.z))
}

extension SIMD4<Float> {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

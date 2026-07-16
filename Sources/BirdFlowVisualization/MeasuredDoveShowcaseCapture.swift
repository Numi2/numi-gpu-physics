import AppKit
import BirdFlowMetal
import CoreText
import Foundation
import Metal
import simd

enum MeasuredDoveShowcaseCapture {
  private struct PilotArtifact: Decodable {
    struct Candidate: Decodable {
      struct Report: Decodable {
        struct Sample: Decodable {
          let sourceTimeSeconds: Double
          let measuredForceZNewtons: Double
          let intervalMeanComputedForceNewtons: [Double]
        }

        let samples: [Sample]
      }

      let collisionOperator: String
      let report: Report
    }

    let requestedFluidSteps: Int
    let requestedComparisonSamples: Int
    let intervalMeanPairwiseNormalizedRMSDifference: Double
    let maximumCorrectionActivationFraction: Double
    let screeningGatePassed: Bool
    let experimentalAgreementGateApplied: Bool
    let cases: [Candidate]
  }

  private struct ForceHistory {
    let times: [Double]
    let measured: [Double]
    let regularized: [Double]
    let recursive: [Double]
    let pairwiseDifference: Double
  }

  static func run(
    arguments: ReadmeShowcaseCapture.Arguments,
    manifestURL: URL,
    pilotArtifactURL: URL
  ) throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
      manifestURL: manifestURL
    )
    let artifact = try JSONDecoder().decode(
      PilotArtifact.self,
      from: Data(contentsOf: pilotArtifactURL)
    )
    let forceHistory = try validateAndBuildHistory(
      dataset: dataset,
      artifact: artifact
    )
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "measured-dove showcase requires Metal"
      )
    }
    let renderer = try MeasuredDoveShowcaseRenderer(
      device: device,
      dataset: dataset
    )
    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )

    for frameIndex in 0..<arguments.frameCount {
      let progress = Float(frameIndex) / Float(arguments.frameCount - 1)
      let traversal = pow(sin(.pi * progress), 2)
      let sourceTime = dataset.frameTimesSeconds[0]
        + traversal
          * (dataset.frameTimesSeconds[dataset.frameCount - 1]
            - dataset.frameTimesSeconds[0])
      let direction: Float = progress < 0.5 ? 1 : -1
      let bounds = frameBounds(dataset: dataset, timeSeconds: sourceTime)
      let center = 0.5 * (bounds.minimum + bounds.maximum)
      var camera = CameraState()
      camera.distance = 0.56 * (1 + 0.025 * cos(2 * .pi * progress))
      camera.yaw = -1.02 + 0.13 * sin(2 * .pi * progress)
      camera.pitch = 0.34 + 0.045 * cos(2 * .pi * progress)
      camera.target = center
      let forward = simd_normalize(center - camera.eye)
      let right = simd_normalize(
        simd_cross(forward, SIMD3<Float>(0, 0, 1))
      )
      camera.target = center + 0.045 * right + SIMD3<Float>(0, 0, 0.005)

      let texture = try renderer.render(
        timeSeconds: sourceTime,
        direction: direction,
        progress: progress,
        camera: camera,
        width: arguments.width,
        height: arguments.height
      )
      let png = try ReadmeShowcaseCapture.pngData(
        texture: texture,
        width: arguments.width,
        height: arguments.height
      ) { graphics in
        drawOverlay(
          graphics: graphics,
          width: arguments.width,
          height: arguments.height,
          sourceTime: Double(sourceTime),
          forceHistory: forceHistory,
          artifact: artifact,
          frameCoordinate: traversal * Float(dataset.frameCount - 1)
        )
      }
      let output = arguments.outputDirectory.appendingPathComponent(
        String(format: "frame-%03d.png", frameIndex)
      )
      try png.write(to: output, options: .atomic)
      print(
        "captured dove \(frameIndex + 1)/\(arguments.frameCount) "
          + "source_frame=\(String(format: "%.2f", traversal * Float(dataset.frameCount - 1))) "
          + "source_time=\(String(format: "%.4f", sourceTime))"
      )
    }
  }

  private static func validateAndBuildHistory(
    dataset: MeasuredBirdSurfaceSequence,
    artifact: PilotArtifact
  ) throws -> ForceHistory {
    guard dataset.frameCount == 144,
      dataset.vertexCount == 2_157,
      dataset.triangleCount == 3_968,
      artifact.screeningGatePassed,
      !artifact.experimentalAgreementGateApplied,
      artifact.requestedFluidSteps == 3_776,
      artifact.requestedComparisonSamples == 187,
      abs(artifact.maximumCorrectionActivationFraction - 0.05) <= 1e-12,
      artifact.cases.count == 2,
      artifact.cases.map(\.collisionOperator) == [
        "positivity-preserving-regularized-bgk",
        "positivity-preserving-recursive-regularized-bgk"
      ],
      artifact.cases.allSatisfy({ $0.report.samples.count == 187 })
    else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "measured-dove showcase inputs do not match the locked full-window artifact"
      )
    }
    let regularized = artifact.cases[0].report.samples
    let recursive = artifact.cases[1].report.samples
    guard regularized.indices.allSatisfy({ index in
      regularized[index].intervalMeanComputedForceNewtons.count == 3
        && recursive[index].intervalMeanComputedForceNewtons.count == 3
        && abs(regularized[index].sourceTimeSeconds
          - recursive[index].sourceTimeSeconds) <= 1e-12
    }) else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "measured-dove force histories are malformed or misaligned"
      )
    }
    return ForceHistory(
      times: regularized.map(\.sourceTimeSeconds),
      measured: regularized.map(\.measuredForceZNewtons),
      regularized: regularized.map {
        $0.intervalMeanComputedForceNewtons[2]
      },
      recursive: recursive.map {
        $0.intervalMeanComputedForceNewtons[2]
      },
      pairwiseDifference: artifact.intervalMeanPairwiseNormalizedRMSDifference
    )
  }

  private static func frameBounds(
    dataset: MeasuredBirdSurfaceSequence,
    timeSeconds: Float
  ) -> (minimum: SIMD3<Float>, maximum: SIMD3<Float>) {
    var minimum = SIMD3<Float>(repeating: .infinity)
    var maximum = SIMD3<Float>(repeating: -.infinity)
    for index in 0..<dataset.vertexCount {
      let point = dataset.state(
        timeSeconds: timeSeconds,
        vertexIndex: index
      ).positionMeters
      minimum = simd_min(minimum, point)
      maximum = simd_max(maximum, point)
    }
    return (minimum, maximum)
  }

  private static func drawOverlay(
    graphics: CGContext,
    width: Int,
    height: Int,
    sourceTime: Double,
    forceHistory: ForceHistory,
    artifact: PilotArtifact,
    frameCoordinate: Float
  ) {
    graphics.saveGState()
    let scale = CGFloat(width) / 1_120
    let margin = 24 * scale
    let titlePanel = NSRect(
      x: margin,
      y: CGFloat(height) - 88 * scale,
      width: 570 * scale,
      height: 62 * scale
    )
    fillPanel(titlePanel, radius: 13 * scale, context: graphics)
    drawText(
      "BIRDFLOWMETAL · RECONSTRUCTED DOVE",
      font: systemFont(.emphasizedSystem, size: 20 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(
        x: titlePanel.minX + 16 * scale,
        y: titlePanel.minY + 34 * scale
      ),
      tracking: 0.45 * scale,
      context: graphics
    )
    drawText(
      "DEETJEN OB_F03  •  144 SOURCE-LOCKED FRAMES  •  NATIVE METAL",
      font: systemFont(.userFixedPitch, size: 10.5 * scale),
      color: NSColor(
        calibratedRed: 0.61,
        green: 0.84,
        blue: 1,
        alpha: 1
      ).cgColor,
      position: CGPoint(
        x: titlePanel.minX + 17 * scale,
        y: titlePanel.minY + 13 * scale
      ),
      context: graphics
    )

    let statusPanel = NSRect(
      x: CGFloat(width) - margin - 430 * scale,
      y: titlePanel.minY,
      width: 430 * scale,
      height: titlePanel.height
    )
    fillPanel(statusPanel, radius: 13 * scale, context: graphics)
    drawText(
      "FULL-WINDOW NUMERICAL GATE",
      font: systemFont(.emphasizedSystem, size: 13 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(
        x: statusPanel.minX + 16 * scale,
        y: statusPanel.minY + 35 * scale
      ),
      tracking: 0.35 * scale,
      context: graphics
    )
    drawText(
      "PASSED  •  2 × 3,776 STEPS  •  187 FORCE SAMPLES",
      font: systemFont(.userFixedPitch, size: 10.5 * scale),
      color: NSColor(
        calibratedRed: 0.35,
        green: 0.96,
        blue: 0.72,
        alpha: 1
      ).cgColor,
      position: CGPoint(
        x: statusPanel.minX + 16 * scale,
        y: statusPanel.minY + 13 * scale
      ),
      context: graphics
    )

    let chart = NSRect(
      x: CGFloat(width) - margin - 344 * scale,
      y: 108 * scale,
      width: 344 * scale,
      height: 190 * scale
    )
    drawForceHistory(
      in: chart,
      currentTime: sourceTime,
      history: forceHistory,
      context: graphics,
      scale: scale
    )

    var badgeX = margin
    badgeX = drawBadge(
      "POSITIVE POPULATIONS",
      color: NSColor(calibratedRed: 0.22, green: 0.94, blue: 0.75, alpha: 1),
      x: badgeX,
      y: margin,
      scale: scale,
      context: graphics
    )
    badgeX = drawBadge(
      "MOMENTUM < 0.12%",
      color: NSColor(calibratedRed: 0.21, green: 0.68, blue: 1, alpha: 1),
      x: badgeX + 7 * scale,
      y: margin,
      scale: scale,
      context: graphics
    )
    badgeX = drawBadge(
      "REG ↔ RR3 < 0.9%",
      color: NSColor(calibratedRed: 0.71, green: 0.44, blue: 1, alpha: 1),
      x: badgeX + 7 * scale,
      y: margin,
      scale: scale,
      context: graphics
    )
    _ = drawBadge(
      "KINEMATIC TRAILS",
      color: NSColor(calibratedRed: 1, green: 0.48, blue: 0.21, alpha: 1),
      x: badgeX + 7 * scale,
      y: margin,
      scale: scale,
      context: graphics
    )

    let boundary = NSRect(
      x: CGFloat(width) - margin - 344 * scale,
      y: margin,
      width: 344 * scale,
      height: 54 * scale
    )
    fillPanel(boundary, radius: 12 * scale, context: graphics)
    drawText(
      "SCIENCE BOUNDARY",
      font: systemFont(.emphasizedSystem, size: 10 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(
        x: boundary.minX + 14 * scale,
        y: boundary.minY + 31 * scale
      ),
      tracking: 0.45 * scale,
      context: graphics
    )
    drawText(
      "REFINEMENT OPEN  •  68.07× VISCOSITY  •  FRAME \(Int(frameCoordinate.rounded()))",
      font: systemFont(.userFixedPitch, size: 9.5 * scale),
      color: NSColor(
        calibratedRed: 1,
        green: 0.72,
        blue: 0.26,
        alpha: 1
      ).cgColor,
      position: CGPoint(
        x: boundary.minX + 14 * scale,
        y: boundary.minY + 12 * scale
      ),
      context: graphics
    )
    graphics.restoreGState()
    graphics.flush()
  }

  private static func drawForceHistory(
    in rect: NSRect,
    currentTime: Double,
    history: ForceHistory,
    context: CGContext,
    scale: CGFloat
  ) {
    fillPanel(rect, radius: 13 * scale, alpha: 0.82, context: context)
    drawText(
      "VERTICAL FORCE HISTORY · DESCRIPTIVE",
      font: systemFont(.emphasizedSystem, size: 10.5 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(x: rect.minX + 14 * scale, y: rect.maxY - 22 * scale),
      tracking: 0.28 * scale,
      context: context
    )
    let plot = NSRect(
      x: rect.minX + 14 * scale,
      y: rect.minY + 34 * scale,
      width: rect.width - 28 * scale,
      height: rect.height - 68 * scale
    )
    let values = history.measured + history.regularized + history.recursive
    guard let rawMinimum = values.min(), let rawMaximum = values.max() else {
      return
    }
    let padding = max(0.1, 0.08 * (rawMaximum - rawMinimum))
    let minimum = rawMinimum - padding
    let maximum = rawMaximum + padding
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.10).cgColor)
    context.setLineWidth(0.75 * scale)
    for index in 0...3 {
      let y = plot.minY + CGFloat(index) * plot.height / 3
      context.move(to: CGPoint(x: plot.minX, y: y))
      context.addLine(to: CGPoint(x: plot.maxX, y: y))
    }
    context.strokePath()

    func drawSeries(_ values: [Double], color: NSColor, width: CGFloat) {
      context.setStrokeColor(color.cgColor)
      context.setLineWidth(width * scale)
      context.setLineJoin(.round)
      context.setLineCap(.round)
      for index in values.indices {
        let x = plot.minX + CGFloat(index) / CGFloat(values.count - 1) * plot.width
        let y = plot.minY
          + CGFloat((values[index] - minimum) / (maximum - minimum))
            * plot.height
        if index == 0 {
          context.move(to: CGPoint(x: x, y: y))
        } else {
          context.addLine(to: CGPoint(x: x, y: y))
        }
      }
      context.strokePath()
    }
    drawSeries(
      history.measured,
      color: NSColor(calibratedWhite: 0.93, alpha: 0.82),
      width: 1
    )
    drawSeries(
      history.regularized,
      color: NSColor(calibratedRed: 0.18, green: 0.72, blue: 1, alpha: 0.95),
      width: 1.65
    )
    drawSeries(
      history.recursive,
      color: NSColor(calibratedRed: 0.45, green: 1, blue: 0.72, alpha: 0.92),
      width: 1.15
    )
    let start = history.times[0]
    let end = history.times[history.times.count - 1]
    let marker = min(max((currentTime - start) / (end - start), 0), 1)
    let markerX = plot.minX + CGFloat(marker) * plot.width
    context.setStrokeColor(
      NSColor(calibratedRed: 1, green: 0.63, blue: 0.22, alpha: 0.85).cgColor
    )
    context.setLineWidth(1 * scale)
    context.move(to: CGPoint(x: markerX, y: plot.minY))
    context.addLine(to: CGPoint(x: markerX, y: plot.maxY))
    context.strokePath()

    drawLegendDot(
      "MEASURED",
      color: NSColor(calibratedWhite: 0.93, alpha: 1),
      x: rect.minX + 15 * scale,
      y: rect.minY + 14 * scale,
      scale: scale,
      context: context
    )
    drawLegendDot(
      "REG",
      color: NSColor(calibratedRed: 0.18, green: 0.72, blue: 1, alpha: 1),
      x: rect.minX + 103 * scale,
      y: rect.minY + 14 * scale,
      scale: scale,
      context: context
    )
    drawLegendDot(
      "RR3",
      color: NSColor(calibratedRed: 0.45, green: 1, blue: 0.72, alpha: 1),
      x: rect.minX + 151 * scale,
      y: rect.minY + 14 * scale,
      scale: scale,
      context: context
    )
    drawText(
      String(format: "Δ RMS %.3f%%", 100 * history.pairwiseDifference),
      font: systemFont(.userFixedPitch, size: 8.8 * scale),
      color: NSColor(calibratedWhite: 0.78, alpha: 1).cgColor,
      position: CGPoint(x: rect.maxX - 91 * scale, y: rect.minY + 11 * scale),
      context: context
    )
  }

  private static func fillPanel(
    _ rect: NSRect,
    radius: CGFloat,
    alpha: CGFloat = 0.76,
    context: CGContext
  ) {
    context.setFillColor(NSColor(calibratedWhite: 0.01, alpha: alpha).cgColor)
    context.addPath(
      CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
      )
    )
    context.fillPath()
    context.setStrokeColor(NSColor(calibratedWhite: 1, alpha: 0.09).cgColor)
    context.setLineWidth(0.7)
    context.addPath(
      CGPath(
        roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
      )
    )
    context.strokePath()
  }

  @discardableResult
  private static func drawBadge(
    _ label: String,
    color: NSColor,
    x: CGFloat,
    y: CGFloat,
    scale: CGFloat,
    context: CGContext
  ) -> CGFloat {
    let font = systemFont(.userFixedPitch, size: 8.6 * scale)
    let line = textLine(label, font: font, color: NSColor.white.cgColor)
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let rect = NSRect(
      x: x,
      y: y,
      width: textWidth + 22 * scale,
      height: 25 * scale
    )
    fillPanel(rect, radius: 12.5 * scale, alpha: 0.77, context: context)
    context.setFillColor(color.cgColor)
    context.fillEllipse(
      in: NSRect(
        x: rect.minX + 7 * scale,
        y: rect.midY - 2.5 * scale,
        width: 5 * scale,
        height: 5 * scale
      )
    )
    context.textPosition = CGPoint(
      x: rect.minX + 15 * scale,
      y: rect.minY + 7.5 * scale
    )
    CTLineDraw(line, context)
    return rect.maxX
  }

  private static func drawLegendDot(
    _ label: String,
    color: NSColor,
    x: CGFloat,
    y: CGFloat,
    scale: CGFloat,
    context: CGContext
  ) {
    context.setFillColor(color.cgColor)
    context.fillEllipse(
      in: NSRect(x: x, y: y + 2 * scale, width: 5 * scale, height: 5 * scale)
    )
    drawText(
      label,
      font: systemFont(.userFixedPitch, size: 7.8 * scale),
      color: NSColor(calibratedWhite: 0.82, alpha: 1).cgColor,
      position: CGPoint(x: x + 9 * scale, y: y),
      context: context
    )
  }

  private static func systemFont(
    _ type: CTFontUIFontType,
    size: CGFloat
  ) -> CTFont {
    CTFontCreateUIFontForLanguage(type, size, nil)!
  }

  private static func drawText(
    _ text: String,
    font: CTFont,
    color: CGColor,
    position: CGPoint,
    tracking: CGFloat = 0,
    context: CGContext
  ) {
    context.textPosition = position
    CTLineDraw(
      textLine(text, font: font, color: color, tracking: tracking),
      context
    )
  }

  private static func textLine(
    _ text: String,
    font: CTFont,
    color: CGColor,
    tracking: CGFloat = 0
  ) -> CTLine {
    CTLineCreateWithAttributedString(
      NSAttributedString(
        string: text,
        attributes: [
          NSAttributedString.Key(kCTFontAttributeName as String): font,
          NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
          NSAttributedString.Key(kCTKernAttributeName as String): tracking
        ]
      )
    )
  }
}

private final class MeasuredDoveShowcaseRenderer {
  private let backend: VisualizationBackend
  private let dataset: MeasuredBirdSurfaceSequence
  private let surfacePipeline: MTLRenderPipelineState
  private let trailPipeline: MTLRenderPipelineState
  private let wirePipeline: MTLRenderPipelineState
  private let backgroundPipeline: MTLRenderPipelineState
  private let depthWriteState: MTLDepthStencilState
  private let depthReadState: MTLDepthStencilState
  private let wingtipIndices: [Int]

  init(device: MTLDevice, dataset: MeasuredBirdSurfaceSequence) throws {
    backend = try VisualizationBackend(device: device)
    self.dataset = dataset
    surfacePipeline = try backend.render(
      vertex: "coloredSurfaceVertex",
      fragment: "showcaseDoveFragment",
      colorFormat: .bgra8Unorm_srgb
    )
    trailPipeline = try backend.render(
      vertex: "coloredSurfaceVertex",
      fragment: "unlitFragment",
      colorFormat: .bgra8Unorm_srgb,
      blending: true
    )
    wirePipeline = try backend.render(
      vertex: "coloredSurfaceVertex",
      fragment: "showcaseWireFragment",
      colorFormat: .bgra8Unorm_srgb,
      blending: true
    )
    backgroundPipeline = try backend.render(
      vertex: "showcaseBackgroundVertex",
      fragment: "showcaseBackgroundFragment",
      colorFormat: .bgra8Unorm_srgb
    )
    let write = MTLDepthStencilDescriptor()
    write.depthCompareFunction = .less
    write.isDepthWriteEnabled = true
    guard let writeState = device.makeDepthStencilState(descriptor: write) else {
      throw VisualizationError.pipeline("dove depth-write state")
    }
    depthWriteState = writeState
    let read = MTLDepthStencilDescriptor()
    read.depthCompareFunction = .lessEqual
    read.isDepthWriteEnabled = false
    guard let readState = device.makeDepthStencilState(descriptor: read) else {
      throw VisualizationError.pipeline("dove depth-read state")
    }
    depthReadState = readState
    wingtipIndices = Self.findWingtipIndices(dataset: dataset)
  }

  func render(
    timeSeconds: Float,
    direction: Float,
    progress: Float,
    camera: CameraState,
    width: Int,
    height: Int
  ) throws -> MTLTexture {
    let motionEnvelope = abs(sin(2 * .pi * progress))
    let surface = surfaceVertices(timeSeconds: timeSeconds)
    let ghosts = ghostVertices(
      timeSeconds: timeSeconds,
      direction: direction,
      opacityScale: motionEnvelope
    )
    let trails = trailVertices(
      timeSeconds: timeSeconds,
      direction: direction,
      camera: camera,
      opacityScale: motionEnvelope
    )
    let surfaceBuffer = try sharedBuffer(surface)
    let ghostBuffer = try sharedBuffer(ghosts)
    let trailBuffers = try trails.map(sharedBuffer)
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
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = color
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.004, 0.008, 0.02, 1)
    pass.depthAttachment.texture = depth
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.storeAction = .dontCare
    pass.depthAttachment.clearDepth = 1
    var cameraUniforms = camera.uniforms(
      aspect: Float(width) / Float(height),
      ribbonWidth: 0.002
    )
    var backgroundOptions = SIMD4<Float>(
      progress,
      Float(width) / Float(height),
      0,
      0
    )
    let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)!
    encoder.label = "Measured dove README showcase"
    encoder.setCullMode(.none)
    encoder.setRenderPipelineState(backgroundPipeline)
    encoder.setFragmentBytes(
      &backgroundOptions,
      length: MemoryLayout<SIMD4<Float>>.stride,
      index: 0
    )
    encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)

    encoder.setDepthStencilState(depthReadState)
    encoder.setRenderPipelineState(trailPipeline)
    encoder.setVertexBytes(
      &cameraUniforms,
      length: MemoryLayout<CameraUniforms>.stride,
      index: 1
    )
    if !ghosts.isEmpty {
      encoder.setVertexBuffer(ghostBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(
        type: .triangle,
        vertexStart: 0,
        vertexCount: ghosts.count
      )
    }
    for (index, buffer) in trailBuffers.enumerated() {
      encoder.setVertexBuffer(buffer, offset: 0, index: 0)
      encoder.drawPrimitives(
        type: .triangleStrip,
        vertexStart: 0,
        vertexCount: trails[index].count
      )
    }

    encoder.setDepthStencilState(depthWriteState)
    encoder.setRenderPipelineState(surfacePipeline)
    encoder.setVertexBuffer(surfaceBuffer, offset: 0, index: 0)
    encoder.setVertexBytes(
      &cameraUniforms,
      length: MemoryLayout<CameraUniforms>.stride,
      index: 1
    )
    encoder.setFragmentBytes(
      &cameraUniforms,
      length: MemoryLayout<CameraUniforms>.stride,
      index: 0
    )
    encoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: surface.count
    )

    encoder.setDepthStencilState(depthReadState)
    encoder.setRenderPipelineState(wirePipeline)
    encoder.setTriangleFillMode(.lines)
    encoder.setVertexBuffer(surfaceBuffer, offset: 0, index: 0)
    encoder.setVertexBytes(
      &cameraUniforms,
      length: MemoryLayout<CameraUniforms>.stride,
      index: 1
    )
    encoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: surface.count
    )
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw VisualizationError.shader(
        commandBuffer.error?.localizedDescription
          ?? "measured dove offscreen render failed"
      )
    }
    return color
  }

  private func surfaceVertices(timeSeconds: Float) -> [ColoredVertex] {
    let states = (0..<dataset.vertexCount).map {
      dataset.state(timeSeconds: timeSeconds, vertexIndex: $0)
    }
    var result: [ColoredVertex] = []
    result.reserveCapacity(dataset.triangleCount * 3)
    for triangleIndex in 0..<dataset.triangleCount {
      let triangle = dataset.triangle(triangleIndex)
      let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
      let points = indices.map { states[$0].positionMeters }
      let rawNormal = simd_cross(points[1] - points[0], points[2] - points[0])
      let normal = simd_length_squared(rawNormal) > 1e-16
        ? simd_normalize(rawNormal)
        : SIMD3<Float>(0, 0, 1)
      let speed = indices.reduce(Float.zero) {
        $0 + simd_length(states[$1].velocityMetersPerSecond)
      } / 3
      let color = surfaceColor(
        partIdentifier: dataset.trianglePartIdentifiers[triangleIndex],
        normalizedSpeed: min(max(speed / 25.2305, 0), 1)
      )
      for point in points {
        result.append(
          ColoredVertex(
            position: SIMD4<Float>(point, 1),
            normal: SIMD4<Float>(normal, 0),
            color: color
          )
        )
      }
    }
    return result
  }

  private func ghostVertices(
    timeSeconds: Float,
    direction: Float,
    opacityScale: Float
  ) -> [ColoredVertex] {
    var result: [ColoredVertex] = []
    for ghostIndex in 1...3 {
      let ghostTime = min(
        max(
          timeSeconds - direction * Float(ghostIndex) * 0.006,
          dataset.frameTimesSeconds[0]
        ),
        dataset.frameTimesSeconds[dataset.frameCount - 1]
      )
      let alpha = opacityScale * Float(0.10 / Double(ghostIndex))
      for triangleIndex in 0..<dataset.triangleCount {
        let part = dataset.trianglePartIdentifiers[triangleIndex]
        guard part == 2 || part == 3 else { continue }
        let triangle = dataset.triangle(triangleIndex)
        let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
        let points = indices.map {
          dataset.state(timeSeconds: ghostTime, vertexIndex: $0).positionMeters
        }
        let rawNormal = simd_cross(points[1] - points[0], points[2] - points[0])
        let normal = simd_length_squared(rawNormal) > 1e-16
          ? simd_normalize(rawNormal)
          : SIMD3<Float>(0, 0, 1)
        let rgb = part == 2
          ? SIMD3<Float>(0.16, 0.72, 1)
          : SIMD3<Float>(1, 0.42, 0.16)
        for point in points {
          result.append(
            ColoredVertex(
              position: SIMD4<Float>(point, 1),
              normal: SIMD4<Float>(normal, 0),
              color: SIMD4<Float>(rgb, alpha)
            )
          )
        }
      }
    }
    return result
  }

  private func trailVertices(
    timeSeconds: Float,
    direction: Float,
    camera: CameraState,
    opacityScale: Float
  ) -> [[ColoredVertex]] {
    wingtipIndices.enumerated().map { trailIndex, vertexIndex in
      let sampleCount = 30
      var points: [SIMD3<Float>] = []
      for sample in stride(from: sampleCount - 1, through: 0, by: -1) {
        let sampleTime = min(
          max(
            timeSeconds - direction * Float(sample) * 0.0018,
            dataset.frameTimesSeconds[0]
          ),
          dataset.frameTimesSeconds[dataset.frameCount - 1]
        )
        points.append(
          dataset.state(
            timeSeconds: sampleTime,
            vertexIndex: vertexIndex
          ).positionMeters
        )
      }
      let rgb = trailIndex == 0
        ? SIMD3<Float>(0.12, 0.76, 1)
        : SIMD3<Float>(1, 0.39, 0.15)
      var vertices: [ColoredVertex] = []
      vertices.reserveCapacity(points.count * 2)
      for index in points.indices {
        let previous = points[max(index - 1, 0)]
        let next = points[min(index + 1, points.count - 1)]
        let tangent = simd_normalize(next - previous + SIMD3<Float>(1e-8, 0, 0))
        let view = simd_normalize(camera.eye - points[index])
        let rawLateral = simd_cross(view, tangent)
        let lateral = simd_length_squared(rawLateral) > 1e-12
          ? simd_normalize(rawLateral)
          : SIMD3<Float>(0, 0, 1)
        let age = Float(index) / Float(points.count - 1)
        let width = 0.00035 + 0.0018 * age
        let color = SIMD4<Float>(
          rgb,
          opacityScale * 0.68 * age * age
        )
        vertices.append(
          ColoredVertex(
            position: SIMD4<Float>(points[index] - width * lateral, 1),
            normal: SIMD4<Float>(view, 0),
            color: color
          )
        )
        vertices.append(
          ColoredVertex(
            position: SIMD4<Float>(points[index] + width * lateral, 1),
            normal: SIMD4<Float>(view, 0),
            color: color
          )
        )
      }
      return vertices
    }
  }

  private func sharedBuffer(_ vertices: [ColoredVertex]) throws -> MTLBuffer {
    let length = max(
      MemoryLayout<ColoredVertex>.stride * vertices.count,
      MemoryLayout<ColoredVertex>.stride
    )
    let buffer = try backend.buffer(length: length, shared: true)
    if !vertices.isEmpty {
      _ = vertices.withUnsafeBytes { bytes in
        memcpy(buffer.contents(), bytes.baseAddress!, bytes.count)
      }
    }
    return buffer
  }

  private func surfaceColor(
    partIdentifier: UInt8,
    normalizedSpeed: Float
  ) -> SIMD4<Float> {
    let low: SIMD3<Float>
    let high: SIMD3<Float>
    switch partIdentifier {
    case 1:
      low = SIMD3<Float>(0.22, 0.42, 0.64)
      high = SIMD3<Float>(0.72, 0.91, 1)
    case 2:
      low = SIMD3<Float>(0.08, 0.50, 0.88)
      high = SIMD3<Float>(0.20, 0.96, 0.87)
    case 3:
      low = SIMD3<Float>(0.78, 0.20, 0.48)
      high = SIMD3<Float>(1, 0.63, 0.18)
    default:
      low = SIMD3<Float>(0.43, 0.25, 0.72)
      high = SIMD3<Float>(0.91, 0.47, 1)
    }
    let blend = sqrt(normalizedSpeed)
    return SIMD4<Float>(low + blend * (high - low), 1)
  }

  private static func findWingtipIndices(
    dataset: MeasuredBirdSurfaceSequence
  ) -> [Int] {
    let referenceFrame = dataset.frameCount / 2
    guard let body = dataset.components.first(where: { $0.partIdentifier == 1 })
    else { return [] }
    var bodyCenter = SIMD3<Float>.zero
    for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      bodyCenter += dataset.vertex(frame: referenceFrame, index: index)
    }
    bodyCenter /= Float(body.vertexCount)
    return [UInt8(2), UInt8(3)].compactMap { identifier in
      guard let wing = dataset.components.first(where: {
        $0.partIdentifier == identifier
      }) else { return nil }
      return (wing.vertexOffset..<(wing.vertexOffset + wing.vertexCount)).max {
        simd_distance_squared(
          dataset.vertex(frame: referenceFrame, index: $0),
          bodyCenter
        ) < simd_distance_squared(
          dataset.vertex(frame: referenceFrame, index: $1),
          bodyCenter
        )
      }
    }
  }
}

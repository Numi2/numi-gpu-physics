import AppKit
import BirdFlowMetal
import CoreText
import CryptoKit
import Foundation
import Metal
import simd

struct MeasuredDoveThroughFlightTimeline: MeasuredDoveMotion {
  let dataset: MeasuredBirdSurfaceSequence

  var startTimeSeconds: Float { dataset.frameTimesSeconds[0] }
  var endTimeSeconds: Float { dataset.frameTimesSeconds[dataset.frameCount - 1] }
  var durationSeconds: Float { endTimeSeconds - startTimeSeconds }

  func sourceTime(progress: Float) -> Float {
    startTimeSeconds + min(max(progress, 0), 1) * durationSeconds
  }

  func sourceFrameCoordinate(progress: Float) -> Float {
    (sourceTime(progress: progress) - startTimeSeconds)
      * dataset.sampleRateHertz
  }

  func point(phase: Float, vertexIndex: Int) -> DoveLoopPoint {
    let state = dataset.state(
      timeSeconds: sourceTime(progress: phase),
      vertexIndex: vertexIndex
    )
    return DoveLoopPoint(
      position: state.positionMeters,
      velocity: state.velocityMetersPerSecond
    )
  }

  func phase(offsetBy seconds: Float, from phase: Float) -> Float {
    min(max(phase + seconds / durationSeconds, 0), 1)
  }
}

public struct DeetjenThroughFlightObservatoryAudit: Codable, Sendable {
  public let schemaVersion: Int
  public let datasetIdentifier: String
  public let manifestSHA256: String
  public let throughFlightReportSHA256: String
  public let throughFlightReportSchemaVersion: Int
  public let width: Int
  public let height: Int
  public let renderedFrameCount: Int
  public let sourceFrameCount: Int
  public let sourceStartTimeSeconds: Double
  public let sourceEndTimeSeconds: Double
  public let trajectorySampleCount: Int
  public let maximumTrajectoryCenterResidualMeters: Double
  public let rawLaboratoryFrameGeometry: Bool
  public let bodyFollowingCamera: Bool
  public let completedFluidSteps: Int
  public let plannedFluidSteps: Int
  public let registeredForceSampleCount: Int
  public let minimumSampledPopulation: Double
  public let scientificOverlayMode: String
  public let trajectoryRenderingMode: String
  public let prescribedMotion: Bool
  public let fullSourceTimelineCompleted: Bool
  public let passed: Bool
}

public enum DeetjenThroughFlightObservatoryCapture {
  public struct Arguments {
    let outputDirectory: URL
    let manifestURL: URL
    let reportURL: URL
    let width: Int
    let height: Int
    let frameCount: Int

    public init(commandLine: [String]) throws {
      func value(after flag: String) throws -> String {
        guard let index = commandLine.firstIndex(of: flag),
          index + 1 < commandLine.count
        else {
          throw CaptureError.invalidArguments("\(flag) requires a value")
        }
        return commandLine[index + 1]
      }
      func integer(after flag: String, default defaultValue: Int) throws -> Int {
        guard commandLine.contains(flag) else { return defaultValue }
        guard let result = Int(try value(after: flag)), result > 0 else {
          throw CaptureError.invalidArguments(
            "\(flag) requires a positive integer"
          )
        }
        return result
      }

      outputDirectory = URL(
        fileURLWithPath: try value(after: "--capture-deetjen-through-flight"),
        isDirectory: true
      )
      manifestURL = URL(
        fileURLWithPath: try value(after: "--capture-deetjen-manifest")
      )
      reportURL = URL(
        fileURLWithPath: try value(after: "--capture-deetjen-report")
      )
      width = try integer(after: "--capture-width", default: 1_120)
      height = try integer(after: "--capture-height", default: 630)
      frameCount = try integer(after: "--capture-frames", default: 48)
      guard width >= 640, height >= 360, frameCount >= 2 else {
        throw CaptureError.invalidArguments(
          "Deetjen observatory capture requires at least 640x360 and two frames"
        )
      }
    }
  }

  public enum CaptureError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case invalidEvidence(String)
    case metalUnavailable

    public var description: String {
      switch self {
      case .invalidArguments(let message): return message
      case .invalidEvidence(let message): return message
      case .metalUnavailable: return "Deetjen through-flight observatory requires Metal"
      }
    }
  }

  public static func run(_ arguments: Arguments) throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
      manifestURL: arguments.manifestURL
    )
    let reportData = try Data(contentsOf: arguments.reportURL)
    let report = try JSONDecoder().decode(
      DeetjenDoveThroughFlightReport.self,
      from: reportData
    )
    let reportSHA256 = sha256(reportData)
    let maximumResidual = try validate(dataset: dataset, report: report)
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw CaptureError.metalUnavailable
    }

    let timeline = MeasuredDoveThroughFlightTimeline(dataset: dataset)
    let renderer = try MeasuredDoveShowcaseRenderer(
      device: device,
      dataset: dataset
    )
    let trajectoryPoints = report.bodyTrajectorySamples.map {
      SIMD3<Float>(
        Float($0.bodyCenterMeters.x),
        Float($0.bodyCenterMeters.y),
        Float($0.bodyCenterMeters.z)
      )
    }
    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )

    for frameIndex in 0..<arguments.frameCount {
      let progress = Float(frameIndex) / Float(arguments.frameCount - 1)
      let sourceTime = timeline.sourceTime(progress: progress)
      let body = dataset.bodyState(timeSeconds: sourceTime)
      var camera = CameraState()
      camera.distance = 0.56 * (1 + 0.025 * sin(.pi * progress))
      camera.yaw = -1.04 + 0.08 * sin(.pi * progress)
      camera.pitch = 0.32 + 0.025 * cos(.pi * progress)
      let flightDirection = simd_normalize(
        trajectoryPoints.last! - trajectoryPoints.first!
      )
      camera.target = body.positionMeters + 0.035 * flightDirection

      let completedPointCount = min(
        dataset.frameCount,
        Int(floor(timeline.sourceFrameCoordinate(progress: progress))) + 1
      )
      let texture = try renderer.render(
        loop: timeline,
        phase: progress,
        camera: camera,
        width: arguments.width,
        height: arguments.height,
        trajectory: MeasuredDoveTrajectoryRendering(
          allPoints: trajectoryPoints,
          completedPointCount: completedPointCount
        )
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
          progress: Double(progress),
          sourceTimeSeconds: Double(sourceTime),
          sourceFrameCoordinate: Double(
            timeline.sourceFrameCoordinate(progress: progress)
          ),
          bodyState: body,
          report: report
        )
      }
      let output = arguments.outputDirectory.appendingPathComponent(
        String(format: "frame-%03d.png", frameIndex)
      )
      try png.write(to: output, options: .atomic)
      print(
        "captured Deetjen through-flight \(frameIndex + 1)/"
          + "\(arguments.frameCount) source_frame="
          + String(
            format: "%.2f",
            timeline.sourceFrameCoordinate(progress: progress)
          )
      )
    }

    let audit = DeetjenThroughFlightObservatoryAudit(
      schemaVersion: 1,
      datasetIdentifier: dataset.datasetIdentifier,
      manifestSHA256: dataset.manifestSHA256,
      throughFlightReportSHA256: reportSHA256,
      throughFlightReportSchemaVersion: report.schemaVersion,
      width: arguments.width,
      height: arguments.height,
      renderedFrameCount: arguments.frameCount,
      sourceFrameCount: dataset.frameCount,
      sourceStartTimeSeconds: report.sourceStartTimeSeconds,
      sourceEndTimeSeconds: report.sourceEndTimeSeconds,
      trajectorySampleCount: report.bodyTrajectorySamples.count,
      maximumTrajectoryCenterResidualMeters: maximumResidual,
      rawLaboratoryFrameGeometry: true,
      bodyFollowingCamera: true,
      completedFluidSteps: report.pilot.completedFluidSteps,
      plannedFluidSteps: report.pilot.plan.totalFluidSteps,
      registeredForceSampleCount: report.pilot.samples.count,
      minimumSampledPopulation: report.pilot.minimumSampledPopulation,
      scientificOverlayMode:
        "source-time+body-kinematics+D8-RR3-registered-force+positivity",
      trajectoryRenderingMode:
        "raw-body-centroid-path+measured-wingtip-kinematic-trails",
      prescribedMotion: report.prescribedMotion,
      fullSourceTimelineCompleted: report.fullSourceTimelineCompleted,
      passed: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(audit).write(
      to: arguments.outputDirectory.appendingPathComponent(
        "observatory-audit.json"
      ),
      options: .atomic
    )
  }

  private static func validate(
    dataset: MeasuredBirdSurfaceSequence,
    report: DeetjenDoveThroughFlightReport
  ) throws -> Double {
    guard report.schemaVersion >= 2,
      report.passed,
      report.fullSourceTimelineCompleted,
      report.sourceTranslationPreserved,
      report.prescribedMotion,
      report.datasetIdentifier == dataset.datasetIdentifier,
      report.manifestSHA256 == dataset.manifestSHA256,
      report.sourceFrameCount == dataset.frameCount,
      report.bodyTrajectorySamples.count == dataset.frameCount,
      report.pilot.completedFluidSteps == report.pilot.plan.totalFluidSteps,
      report.pilot.minimumSampledPopulation > 0,
      report.pilot.allLoadsFinite,
      report.pilot.sampledPopulationPositivityPassed
    else {
      throw CaptureError.invalidEvidence(
        "through-flight report does not satisfy the observatory evidence contract"
      )
    }

    var maximumResidual = 0.0
    var previousTime = -Double.infinity
    var previousTravel = -Double.infinity
    for sample in report.bodyTrajectorySamples {
      guard sample.sourceFrameIndex >= 0,
        sample.sourceFrameIndex < dataset.frameCount,
        sample.sourceTimeSeconds > previousTime,
        sample.cumulativeTravelMeters >= previousTravel
      else {
        throw CaptureError.invalidEvidence(
          "through-flight body trajectory is not ordered and monotone"
        )
      }
      let sourceTime = dataset.frameTimesSeconds[sample.sourceFrameIndex]
      guard abs(Double(sourceTime) - sample.sourceTimeSeconds) <= 1e-7 else {
        throw CaptureError.invalidEvidence(
          "through-flight body trajectory time does not match the source frame"
        )
      }
      let body = dataset.bodyState(timeSeconds: sourceTime).positionMeters
      let archived = SIMD3<Double>(
        sample.bodyCenterMeters.x,
        sample.bodyCenterMeters.y,
        sample.bodyCenterMeters.z
      )
      let residual = simd_distance(
        SIMD3<Double>(Double(body.x), Double(body.y), Double(body.z)),
        archived
      )
      maximumResidual = max(maximumResidual, residual)
      previousTime = sample.sourceTimeSeconds
      previousTravel = sample.cumulativeTravelMeters
    }
    guard maximumResidual <= 1e-7 else {
      throw CaptureError.invalidEvidence(
        "through-flight archived trajectory does not reproduce source geometry"
      )
    }
    return maximumResidual
  }

  private static func drawOverlay(
    graphics: CGContext,
    width: Int,
    height: Int,
    progress: Double,
    sourceTimeSeconds: Double,
    sourceFrameCoordinate: Double,
    bodyState: MeasuredBirdSurfaceComponentState,
    report: DeetjenDoveThroughFlightReport
  ) {
    graphics.saveGState()
    let scale = CGFloat(width) / 1_120
    let margin = 24 * scale

    let title = NSRect(
      x: margin,
      y: CGFloat(height) - 94 * scale,
      width: 590 * scale,
      height: 68 * scale
    )
    fillPanel(title, radius: 14 * scale, context: graphics)
    drawText(
      "DEETJEN DOVE · THROUGH-FLIGHT OBSERVATORY",
      font: systemFont(.emphasizedSystem, size: 19 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(x: title.minX + 16 * scale, y: title.minY + 39 * scale),
      tracking: 0.35 * scale,
      context: graphics
    )
    drawText(
      "RAW LAB-FRAME SURFACE  •  144 SOURCE FRAMES  •  BODY-TRACKING CAMERA",
      font: systemFont(.userFixedPitch, size: 9.8 * scale),
      color: NSColor(calibratedRed: 0.45, green: 0.88, blue: 1, alpha: 1).cgColor,
      position: CGPoint(x: title.minX + 17 * scale, y: title.minY + 16 * scale),
      context: graphics
    )

    let bodySpeed = simd_length(bodyState.velocityMetersPerSecond)
    let displacement = interpolatedDisplacement(
      report.bodyTrajectorySamples,
      sourceFrameCoordinate: sourceFrameCoordinate
    )
    let status = NSRect(
      x: CGFloat(width) - margin - 420 * scale,
      y: title.minY,
      width: 420 * scale,
      height: title.height
    )
    fillPanel(status, radius: 14 * scale, context: graphics)
    drawText(
      String(
        format: "t = %06.2f ms  •  SOURCE FRAME %06.2f", 1_000 * sourceTimeSeconds,
        sourceFrameCoordinate),
      font: systemFont(.emphasizedSystem, size: 12 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(x: status.minX + 15 * scale, y: status.minY + 40 * scale),
      context: graphics
    )
    drawText(
      String(
        format: "|v body| %.3f m/s  •  Δx [%.3f, %.3f, %.3f] m",
        bodySpeed,
        displacement.x,
        displacement.y,
        displacement.z
      ),
      font: systemFont(.userFixedPitch, size: 9.6 * scale),
      color: NSColor(calibratedRed: 0.52, green: 0.98, blue: 0.75, alpha: 1).cgColor,
      position: CGPoint(x: status.minX + 15 * scale, y: status.minY + 16 * scale),
      context: graphics
    )

    let science = NSRect(
      x: margin,
      y: 88 * scale,
      width: 420 * scale,
      height: 126 * scale
    )
    fillPanel(science, radius: 13 * scale, alpha: 0.84, context: graphics)
    drawText(
      "PRESCRIBED-MOTION CFD · ENGINEERING REGIME",
      font: systemFont(.emphasizedSystem, size: 11 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(x: science.minX + 15 * scale, y: science.minY + 97 * scale),
      tracking: 0.3 * scale,
      context: graphics
    )
    drawText(
      "D8  •  75×69×66  •  RR3  •  4,576/4,576 STEPS",
      font: systemFont(.userFixedPitch, size: 10 * scale),
      color: NSColor(calibratedRed: 0.48, green: 0.84, blue: 1, alpha: 1).cgColor,
      position: CGPoint(x: science.minX + 15 * scale, y: science.minY + 71 * scale),
      context: graphics
    )
    drawText(
      String(
        format: "FINITE LOADS  •  POPULATIONS POSITIVE  •  min f %.3e",
        report.pilot.minimumSampledPopulation
      ),
      font: systemFont(.userFixedPitch, size: 9.5 * scale),
      color: NSColor(calibratedRed: 0.39, green: 0.98, blue: 0.67, alpha: 1).cgColor,
      position: CGPoint(x: science.minX + 15 * scale, y: science.minY + 47 * scale),
      context: graphics
    )
    drawText(
      "TRAILS = KINEMATIC HISTORY  •  CFD WAKE FIELD NOT DISPLAYED",
      font: systemFont(.userFixedPitch, size: 8.8 * scale),
      color: NSColor(calibratedRed: 1, green: 0.72, blue: 0.30, alpha: 1).cgColor,
      position: CGPoint(x: science.minX + 15 * scale, y: science.minY + 22 * scale),
      context: graphics
    )

    drawForceChart(
      in: NSRect(
        x: CGFloat(width) - margin - 418 * scale,
        y: 88 * scale,
        width: 418 * scale,
        height: 190 * scale
      ),
      sourceTimeSeconds: sourceTimeSeconds,
      report: report,
      context: graphics,
      scale: scale
    )

    let rail = NSRect(
      x: margin,
      y: margin,
      width: CGFloat(width) - 2 * margin,
      height: 44 * scale
    )
    drawProgressRail(
      in: rail,
      progress: progress,
      sourceTimeSeconds: sourceTimeSeconds,
      report: report,
      context: graphics,
      scale: scale
    )
    graphics.restoreGState()
    graphics.flush()
  }

  private static func drawForceChart(
    in rect: NSRect,
    sourceTimeSeconds: Double,
    report: DeetjenDoveThroughFlightReport,
    context: CGContext,
    scale: CGFloat
  ) {
    fillPanel(rect, radius: 13 * scale, alpha: 0.84, context: context)
    drawText(
      "REGISTERED VERTICAL FORCE · 25–118 ms",
      font: systemFont(.emphasizedSystem, size: 10.5 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(x: rect.minX + 14 * scale, y: rect.maxY - 23 * scale),
      tracking: 0.25 * scale,
      context: context
    )
    let samples = report.pilot.samples
    guard let first = samples.first, let last = samples.last else { return }
    let measured = samples.map(\.measuredForceZNewtons)
    let computed = samples.map { $0.intervalMeanComputedForceNewtons.z }
    let minimum = min(0, measured.min() ?? 0, computed.min() ?? 0)
    let maximum = max(0, measured.max() ?? 0, computed.max() ?? 0)
    let span = max(maximum - minimum, 1e-9)
    let plot = rect.insetBy(dx: 14 * scale, dy: 38 * scale)
    context.setStrokeColor(NSColor(calibratedWhite: 0.45, alpha: 0.24).cgColor)
    context.setLineWidth(1)
    for fraction in [0.0, 0.5, 1.0] {
      let y = plot.minY + CGFloat(fraction) * plot.height
      context.move(to: CGPoint(x: plot.minX, y: y))
      context.addLine(to: CGPoint(x: plot.maxX, y: y))
    }
    context.strokePath()

    func chartPoint(_ index: Int, _ value: Double) -> CGPoint {
      let x = plot.minX + CGFloat(index) / CGFloat(samples.count - 1) * plot.width
      let y = plot.minY + CGFloat((value - minimum) / span) * plot.height
      return CGPoint(x: x, y: y)
    }
    func stroke(_ values: [Double], color: NSColor, width: CGFloat) {
      context.beginPath()
      for index in values.indices {
        let point = chartPoint(index, values[index])
        index == values.startIndex
          ? context.move(to: point)
          : context.addLine(to: point)
      }
      context.setStrokeColor(color.cgColor)
      context.setLineWidth(width * scale)
      context.strokePath()
    }
    stroke(
      measured,
      color: NSColor(calibratedRed: 0.32, green: 0.82, blue: 1, alpha: 0.92),
      width: 1.35
    )
    stroke(
      computed,
      color: NSColor(calibratedRed: 1, green: 0.47, blue: 0.22, alpha: 0.94),
      width: 1.55
    )
    let timeFraction = min(
      max(
        (sourceTimeSeconds - first.sourceTimeSeconds)
          / (last.sourceTimeSeconds - first.sourceTimeSeconds),
        0
      ),
      1
    )
    let cursorX = plot.minX + CGFloat(timeFraction) * plot.width
    context.setStrokeColor(NSColor.white.withAlphaComponent(0.72).cgColor)
    context.setLineWidth(1 * scale)
    context.move(to: CGPoint(x: cursorX, y: plot.minY))
    context.addLine(to: CGPoint(x: cursorX, y: plot.maxY))
    context.strokePath()
    drawText(
      "MEASURED",
      font: systemFont(.userFixedPitch, size: 8.5 * scale),
      color: NSColor(calibratedRed: 0.32, green: 0.82, blue: 1, alpha: 1).cgColor,
      position: CGPoint(x: plot.minX, y: rect.minY + 12 * scale),
      context: context
    )
    drawText(
      "D8 RR3 COMPUTED",
      font: systemFont(.userFixedPitch, size: 8.5 * scale),
      color: NSColor(calibratedRed: 1, green: 0.47, blue: 0.22, alpha: 1).cgColor,
      position: CGPoint(x: plot.minX + 82 * scale, y: rect.minY + 12 * scale),
      context: context
    )
  }

  private static func drawProgressRail(
    in rect: NSRect,
    progress: Double,
    sourceTimeSeconds: Double,
    report: DeetjenDoveThroughFlightReport,
    context: CGContext,
    scale: CGFloat
  ) {
    fillPanel(rect, radius: 11 * scale, alpha: 0.78, context: context)
    let line = NSRect(
      x: rect.minX + 15 * scale,
      y: rect.minY + 14 * scale,
      width: rect.width - 30 * scale,
      height: 4 * scale
    )
    context.setFillColor(NSColor(calibratedWhite: 0.25, alpha: 0.8).cgColor)
    context.fill(line)
    context.setFillColor(
      NSColor(calibratedRed: 0.15, green: 0.86, blue: 1, alpha: 1).cgColor
    )
    context.fill(
      NSRect(x: line.minX, y: line.minY, width: line.width * progress, height: line.height)
    )
    drawText(
      String(
        format:
          "LAB-FRAME TRAJECTORY  •  %.0f/143 ms  •  PATH %.3f m  •  NOT LOAD-RESPONSIVE FREE FLIGHT",
        1_000 * sourceTimeSeconds,
        report.measuredDerivedBodyTravelMeters
      ),
      font: systemFont(.userFixedPitch, size: 9.2 * scale),
      color: NSColor(calibratedWhite: 0.86, alpha: 1).cgColor,
      position: CGPoint(x: rect.minX + 15 * scale, y: rect.minY + 25 * scale),
      context: context
    )
  }

  private static func interpolatedDisplacement(
    _ samples: [DeetjenDoveBodyTrajectorySample],
    sourceFrameCoordinate: Double
  ) -> SIMD3<Double> {
    let lower = min(max(Int(floor(sourceFrameCoordinate)), 0), samples.count - 1)
    let upper = min(lower + 1, samples.count - 1)
    guard lower != upper else {
      return samples[lower].displacementFromStartMeters
    }
    let blend = sourceFrameCoordinate - Double(lower)
    let a = samples[lower]
    let b = samples[upper]
    return a.displacementFromStartMeters
      + blend * (b.displacementFromStartMeters - a.displacementFromStartMeters)
  }

  private static func fillPanel(
    _ rect: NSRect,
    radius: CGFloat,
    alpha: CGFloat = 0.78,
    context: CGContext
  ) {
    context.setFillColor(NSColor(calibratedWhite: 0.012, alpha: alpha).cgColor)
    context.addPath(
      CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
      )
    )
    context.fillPath()
    context.setStrokeColor(NSColor(calibratedWhite: 0.6, alpha: 0.16).cgColor)
    context.setLineWidth(1)
    context.addPath(
      CGPath(
        roundedRect: rect,
        cornerWidth: radius,
        cornerHeight: radius,
        transform: nil
      )
    )
    context.strokePath()
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
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(
        string: text,
        attributes: [
          NSAttributedString.Key(kCTFontAttributeName as String): font,
          NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
          NSAttributedString.Key(kCTKernAttributeName as String): tracking,
        ]
      )
    )
    CTLineDraw(line, context)
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }
}

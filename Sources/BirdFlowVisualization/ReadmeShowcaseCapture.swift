import AppKit
import BirdFlowCore
import BirdFlowMetal
import CoreText
import Foundation
import Metal

public enum ReadmeShowcaseCapture {
  public struct Arguments {
    let outputDirectory: URL
    let width: Int
    let height: Int
    let frameCount: Int
    let preRollSteps: Int
    let doveManifestURL: URL?
    let doveD32FullWindowArtifactURL: URL?
    let doveD32FullWindowAuditURL: URL?
    let doveD28D32RefinementURL: URL?
    let doveD28D32PhaseLocalizationURL: URL?
    let doveD28D32PhaseLocalizationAuditURL: URL?
    let doveTargetedBoundaryD28URL: URL?
    let doveTargetedBoundaryD32URL: URL?
    let doveTargetedBoundaryAttributionURL: URL?
    let doveTargetedBoundaryAuditURL: URL?
    let doveReflectedProvenancePreregistrationURL: URL?
    let doveReflectedProvenanceD28URL: URL?
    let doveReflectedProvenanceD32URL: URL?
    let doveReflectedProvenanceAttributionURL: URL?
    let doveReflectedProvenanceAuditURL: URL?
    let doveLinkCompositionPreregistrationURL: URL?
    let doveLinkCompositionAttributionURL: URL?
    let doveLinkCompositionAuditURL: URL?
    let doveDirectionCompositionPreregistrationURL: URL?
    let doveDirectionCompositionCanonicalURL: URL?
    let doveDirectionCompositionAuditURL: URL?
    let doveLinkGeometryReportURL: URL?
    let doveCurvedDirectionCompositionPreregistrationURL: URL?
    let doveCurvedDirectionCompositionCanonicalURL: URL?
    let doveCurvedDirectionCompositionAuditURL: URL?
    let doveFineDirectionCompositionPreregistrationURL: URL?
    let doveFineDirectionCompositionCensusURL: URL?
    let doveFineDirectionCompositionDiscriminatorURL: URL?
    let doveFineDirectionCompositionAuditURL: URL?
    let doveFineDirectionPhaseV1PreregistrationURL: URL?
    let doveFineDirectionPhaseV1FailureURL: URL?
    let doveFineDirectionPhasePreregistrationURL: URL?
    let doveFineDirectionPhaseCensusURL: URL?
    let doveFineDirectionPhaseDiscriminatorURL: URL?
    let doveFineDirectionPhaseAuditURL: URL?

    public init(commandLine: [String]) throws {
      guard
        let captureIndex = commandLine.firstIndex(
          of: "--capture-readme-frames"
        ), captureIndex + 1 < commandLine.count
      else {
        throw CaptureError.invalidArguments(
          "--capture-readme-frames requires an output directory"
        )
      }
      outputDirectory = URL(
        fileURLWithPath: commandLine[captureIndex + 1],
        isDirectory: true
      )

      func integer(after flag: String, default defaultValue: Int) throws -> Int {
        guard let index = commandLine.firstIndex(of: flag) else {
          return defaultValue
        }
        guard index + 1 < commandLine.count,
          let value = Int(commandLine[index + 1]), value > 0
        else {
          throw CaptureError.invalidArguments(
            "\(flag) requires a positive integer"
          )
        }
        return value
      }

      width = try integer(after: "--capture-width", default: 896)
      height = try integer(after: "--capture-height", default: 504)
      frameCount = try integer(after: "--capture-frames", default: 40)
      preRollSteps = try integer(after: "--capture-pre-roll", default: 384)
      func fileURL(after flag: String) throws -> URL? {
        guard let index = commandLine.firstIndex(of: flag) else { return nil }
        guard index + 1 < commandLine.count else {
          throw CaptureError.invalidArguments("\(flag) requires a file path")
        }
        return URL(fileURLWithPath: commandLine[index + 1])
      }
      doveManifestURL = try fileURL(after: "--capture-dove-manifest")
      doveD32FullWindowArtifactURL = try fileURL(
        after: "--capture-dove-d32-full-window"
      )
      doveD32FullWindowAuditURL = try fileURL(
        after: "--capture-dove-d32-full-window-audit"
      )
      doveD28D32RefinementURL = try fileURL(
        after: "--capture-dove-d28-d32-refinement"
      )
      doveD28D32PhaseLocalizationURL = try fileURL(
        after: "--capture-dove-d28-d32-phase-localization"
      )
      doveD28D32PhaseLocalizationAuditURL = try fileURL(
        after: "--capture-dove-d28-d32-phase-localization-audit"
      )
      doveTargetedBoundaryD28URL = try fileURL(
        after: "--capture-dove-targeted-boundary-d28"
      )
      doveTargetedBoundaryD32URL = try fileURL(
        after: "--capture-dove-targeted-boundary-d32"
      )
      doveTargetedBoundaryAttributionURL = try fileURL(
        after: "--capture-dove-targeted-boundary-attribution"
      )
      doveTargetedBoundaryAuditURL = try fileURL(
        after: "--capture-dove-targeted-boundary-audit"
      )
      doveReflectedProvenancePreregistrationURL = try fileURL(
        after: "--capture-dove-reflected-provenance-preregistration"
      )
      doveReflectedProvenanceD28URL = try fileURL(
        after: "--capture-dove-reflected-provenance-d28"
      )
      doveReflectedProvenanceD32URL = try fileURL(
        after: "--capture-dove-reflected-provenance-d32"
      )
      doveReflectedProvenanceAttributionURL = try fileURL(
        after: "--capture-dove-reflected-provenance-attribution"
      )
      doveReflectedProvenanceAuditURL = try fileURL(
        after: "--capture-dove-reflected-provenance-audit"
      )
      doveLinkCompositionPreregistrationURL = try fileURL(
        after: "--capture-dove-link-composition-preregistration"
      )
      doveLinkCompositionAttributionURL = try fileURL(
        after: "--capture-dove-link-composition-attribution"
      )
      doveLinkCompositionAuditURL = try fileURL(
        after: "--capture-dove-link-composition-audit"
      )
      doveDirectionCompositionPreregistrationURL = try fileURL(
        after: "--capture-dove-direction-composition-preregistration"
      )
      doveDirectionCompositionCanonicalURL = try fileURL(
        after: "--capture-dove-direction-composition-canonical"
      )
      doveDirectionCompositionAuditURL = try fileURL(
        after: "--capture-dove-direction-composition-audit"
      )
      doveLinkGeometryReportURL = try fileURL(
        after: "--capture-dove-link-geometry-report"
      )
      doveCurvedDirectionCompositionPreregistrationURL = try fileURL(
        after: "--capture-dove-curved-direction-composition-preregistration"
      )
      doveCurvedDirectionCompositionCanonicalURL = try fileURL(
        after: "--capture-dove-curved-direction-composition-canonical"
      )
      doveCurvedDirectionCompositionAuditURL = try fileURL(
        after: "--capture-dove-curved-direction-composition-audit"
      )
      doveFineDirectionCompositionPreregistrationURL = try fileURL(
        after: "--capture-dove-fine-direction-composition-preregistration"
      )
      doveFineDirectionCompositionCensusURL = try fileURL(
        after: "--capture-dove-fine-direction-composition-census"
      )
      doveFineDirectionCompositionDiscriminatorURL = try fileURL(
        after: "--capture-dove-fine-direction-composition-discriminator"
      )
      doveFineDirectionCompositionAuditURL = try fileURL(
        after: "--capture-dove-fine-direction-composition-audit"
      )
      doveFineDirectionPhaseV1PreregistrationURL = try fileURL(
        after: "--capture-dove-fine-direction-phase-v1-preregistration"
      )
      doveFineDirectionPhaseV1FailureURL = try fileURL(
        after: "--capture-dove-fine-direction-phase-v1-failure"
      )
      doveFineDirectionPhasePreregistrationURL = try fileURL(
        after: "--capture-dove-fine-direction-phase-preregistration"
      )
      doveFineDirectionPhaseCensusURL = try fileURL(
        after: "--capture-dove-fine-direction-phase-census"
      )
      doveFineDirectionPhaseDiscriminatorURL = try fileURL(
        after: "--capture-dove-fine-direction-phase-discriminator"
      )
      doveFineDirectionPhaseAuditURL = try fileURL(
        after: "--capture-dove-fine-direction-phase-audit"
      )
      let doveInputs = [
        doveManifestURL,
        doveD32FullWindowArtifactURL,
        doveD32FullWindowAuditURL,
        doveD28D32RefinementURL,
        doveD28D32PhaseLocalizationURL,
        doveD28D32PhaseLocalizationAuditURL,
        doveTargetedBoundaryD28URL,
        doveTargetedBoundaryD32URL,
        doveTargetedBoundaryAttributionURL,
        doveTargetedBoundaryAuditURL,
        doveReflectedProvenancePreregistrationURL,
        doveReflectedProvenanceD28URL,
        doveReflectedProvenanceD32URL,
        doveReflectedProvenanceAttributionURL,
        doveReflectedProvenanceAuditURL,
        doveLinkCompositionPreregistrationURL,
        doveLinkCompositionAttributionURL,
        doveLinkCompositionAuditURL,
        doveDirectionCompositionPreregistrationURL,
        doveDirectionCompositionCanonicalURL,
        doveDirectionCompositionAuditURL,
        doveLinkGeometryReportURL,
        doveCurvedDirectionCompositionPreregistrationURL,
        doveCurvedDirectionCompositionCanonicalURL,
        doveCurvedDirectionCompositionAuditURL,
        doveFineDirectionCompositionPreregistrationURL,
        doveFineDirectionCompositionCensusURL,
        doveFineDirectionCompositionDiscriminatorURL,
        doveFineDirectionCompositionAuditURL,
        doveFineDirectionPhaseV1PreregistrationURL,
        doveFineDirectionPhaseV1FailureURL,
        doveFineDirectionPhasePreregistrationURL,
        doveFineDirectionPhaseCensusURL,
        doveFineDirectionPhaseDiscriminatorURL,
        doveFineDirectionPhaseAuditURL,
      ]
      guard
        doveInputs.allSatisfy({ $0 == nil })
          || doveInputs.allSatisfy({ $0 != nil })
      else {
        throw CaptureError.invalidArguments(
          "dove capture requires --capture-dove-manifest, "
            + "--capture-dove-d32-full-window, its audit, the D28/D32 "
            + "refinement, and the phase-localization report and audit"
            + ", plus both targeted cases and their attribution/audit"
            + ", plus the reflected-provenance preregistration, both cases, "
            + "attribution, and audit"
            + ", plus the conditioned link-composition preregistration, "
            + "attribution, and audit"
            + ", plus the planar direction-composition preregistration, "
            + "canonical, and audit"
            + ", plus the source link-geometry report and curved "
            + "direction-composition preregistration, canonical, and audit"
            + ", plus the fine-pair direction-composition preregistration, "
            + "census, discriminator, and audit"
            + ", plus the phase-window V1 preregistration/failure and V2 "
            + "preregistration, census, discriminator, and audit"
        )
      }
      guard width >= 320, height >= 180, frameCount >= 2 else {
        throw CaptureError.invalidArguments(
          "capture requires at least 320x180 pixels and two frames"
        )
      }
    }
  }

  enum CaptureError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case invalidFrame(String)
    case imageAllocation
    case pngEncoding

    var description: String {
      switch self {
      case .invalidArguments(let message): return message
      case .invalidFrame(let message): return message
      case .imageAllocation: return "unable to allocate the capture bitmap"
      case .pngEncoding: return "unable to encode a captured Metal frame as PNG"
      }
    }
  }

  public static func run(_ arguments: Arguments) throws {
    if let manifestURL = arguments.doveManifestURL,
      let d32FullWindowURL = arguments.doveD32FullWindowArtifactURL,
      let d32FullWindowAuditURL = arguments.doveD32FullWindowAuditURL,
      let refinementURL = arguments.doveD28D32RefinementURL,
      let phaseLocalizationURL = arguments.doveD28D32PhaseLocalizationURL,
      let phaseLocalizationAuditURL =
        arguments.doveD28D32PhaseLocalizationAuditURL,
      let targetedD28URL = arguments.doveTargetedBoundaryD28URL,
      let targetedD32URL = arguments.doveTargetedBoundaryD32URL,
      let targetedAttributionURL =
        arguments.doveTargetedBoundaryAttributionURL,
      let targetedAuditURL = arguments.doveTargetedBoundaryAuditURL,
      let reflectedPreregistrationURL =
        arguments.doveReflectedProvenancePreregistrationURL,
      let reflectedD28URL = arguments.doveReflectedProvenanceD28URL,
      let reflectedD32URL = arguments.doveReflectedProvenanceD32URL,
      let reflectedAttributionURL =
        arguments.doveReflectedProvenanceAttributionURL,
      let reflectedAuditURL = arguments.doveReflectedProvenanceAuditURL,
      let linkCompositionPreregistrationURL =
        arguments.doveLinkCompositionPreregistrationURL,
      let linkCompositionAttributionURL =
        arguments.doveLinkCompositionAttributionURL,
      let linkCompositionAuditURL = arguments.doveLinkCompositionAuditURL,
      let directionCompositionPreregistrationURL =
        arguments.doveDirectionCompositionPreregistrationURL,
      let directionCompositionCanonicalURL =
        arguments.doveDirectionCompositionCanonicalURL,
      let directionCompositionAuditURL =
        arguments.doveDirectionCompositionAuditURL,
      let linkGeometryReportURL = arguments.doveLinkGeometryReportURL,
      let curvedDirectionCompositionPreregistrationURL =
        arguments.doveCurvedDirectionCompositionPreregistrationURL,
      let curvedDirectionCompositionCanonicalURL =
        arguments.doveCurvedDirectionCompositionCanonicalURL,
      let curvedDirectionCompositionAuditURL =
        arguments.doveCurvedDirectionCompositionAuditURL,
      let fineDirectionCompositionPreregistrationURL =
        arguments.doveFineDirectionCompositionPreregistrationURL,
      let fineDirectionCompositionCensusURL =
        arguments.doveFineDirectionCompositionCensusURL,
      let fineDirectionCompositionDiscriminatorURL =
        arguments.doveFineDirectionCompositionDiscriminatorURL,
      let fineDirectionCompositionAuditURL =
        arguments.doveFineDirectionCompositionAuditURL,
      let fineDirectionPhaseV1PreregistrationURL =
        arguments.doveFineDirectionPhaseV1PreregistrationURL,
      let fineDirectionPhaseV1FailureURL =
        arguments.doveFineDirectionPhaseV1FailureURL,
      let fineDirectionPhasePreregistrationURL =
        arguments.doveFineDirectionPhasePreregistrationURL,
      let fineDirectionPhaseCensusURL =
        arguments.doveFineDirectionPhaseCensusURL,
      let fineDirectionPhaseDiscriminatorURL =
        arguments.doveFineDirectionPhaseDiscriminatorURL,
      let fineDirectionPhaseAuditURL = arguments.doveFineDirectionPhaseAuditURL
    {
      try MeasuredDoveShowcaseCapture.run(
        arguments: arguments,
        manifestURL: manifestURL,
        d32FullWindowArtifactURL: d32FullWindowURL,
        d32FullWindowAuditURL: d32FullWindowAuditURL,
        refinementURL: refinementURL,
        phaseLocalizationURL: phaseLocalizationURL,
        phaseLocalizationAuditURL: phaseLocalizationAuditURL,
        targetedD28URL: targetedD28URL,
        targetedD32URL: targetedD32URL,
        targetedAttributionURL: targetedAttributionURL,
        targetedAuditURL: targetedAuditURL,
        reflectedPreregistrationURL: reflectedPreregistrationURL,
        reflectedD28URL: reflectedD28URL,
        reflectedD32URL: reflectedD32URL,
        reflectedAttributionURL: reflectedAttributionURL,
        reflectedAuditURL: reflectedAuditURL,
        linkCompositionPreregistrationURL:
          linkCompositionPreregistrationURL,
        linkCompositionAttributionURL: linkCompositionAttributionURL,
        linkCompositionAuditURL: linkCompositionAuditURL,
        directionCompositionPreregistrationURL:
          directionCompositionPreregistrationURL,
        directionCompositionCanonicalURL: directionCompositionCanonicalURL,
        directionCompositionAuditURL: directionCompositionAuditURL,
        linkGeometryReportURL: linkGeometryReportURL,
        curvedDirectionCompositionPreregistrationURL:
          curvedDirectionCompositionPreregistrationURL,
        curvedDirectionCompositionCanonicalURL:
          curvedDirectionCompositionCanonicalURL,
        curvedDirectionCompositionAuditURL: curvedDirectionCompositionAuditURL,
        fineDirectionCompositionPreregistrationURL:
          fineDirectionCompositionPreregistrationURL,
        fineDirectionCompositionCensusURL: fineDirectionCompositionCensusURL,
        fineDirectionCompositionDiscriminatorURL:
          fineDirectionCompositionDiscriminatorURL,
        fineDirectionCompositionAuditURL: fineDirectionCompositionAuditURL,
        fineDirectionPhaseV1PreregistrationURL:
          fineDirectionPhaseV1PreregistrationURL,
        fineDirectionPhaseV1FailureURL: fineDirectionPhaseV1FailureURL,
        fineDirectionPhasePreregistrationURL:
          fineDirectionPhasePreregistrationURL,
        fineDirectionPhaseCensusURL: fineDirectionPhaseCensusURL,
        fineDirectionPhaseDiscriminatorURL:
          fineDirectionPhaseDiscriminatorURL,
        fineDirectionPhaseAuditURL: fineDirectionPhaseAuditURL
      )
      return
    }
    let bird = BirdParameters.demonstration
    let grid = try GridSize(x: 80, y: 96, z: 80)
    let scaling = try LatticeScaling(
      characteristicLengthMeters: bird.wingRootChordMeters,
      characteristicLengthCells: 12,
      referenceSpeedMetersPerSecond: 8,
      targetReynoldsNumber: 100,
      physicalAirDensity: 1.225,
      latticeReferenceSpeed: 0.04
    )
    let configuration = try SimulationConfiguration(
      grid: grid,
      domainOriginMeters: .zero,
      scaling: scaling,
      physicalAirDensity: 1.225,
      farFieldVelocityMetersPerSecond: SIMD3<Float>(-8, 0, 0),
      spongeWidthCells: 4,
      spongeStrength: 0.06,
      freeFlight: false,
      fastMath: false
    )
    let center = configuration.domainSizeMeters * 0.5
    let live = try LiveSimulation(
      configuration: configuration,
      bird: bird,
      initialBodyState: BirdBodyState(positionMeters: center),
      batchSize: 32
    )
    defer { live.stop() }

    let renderer = try MetalVisualizationRenderer(liveSimulation: live)
    var settings = VisualizationSettings()
    settings.pressureUnit = .coefficient
    settings.pressureRangeCoefficient = 0.22
    settings.pressureRangeLocked = true
    settings.showSlice = true
    settings.sliceField = .vorticityMagnitude
    settings.sliceSnap = .z
    settings.slicePosition = 0.50
    settings.sliceOpacity = 0.46
    settings.sliceRange = 55
    settings.showVelocityGlyphs = false
    settings.showRibbons = true
    settings.ribbonColor = .vorticity
    settings.ribbonColorRange = 45
    settings.ribbonWidthMeters = 0.0022
    settings.tracerCount = 96
    settings.tracerHistory = 64
    settings.showQCriterion = true
    settings.qThreshold = 5_000
    settings.qOpacity = 0.34
    settings.qColor = .vorticity
    settings.qTriangleCapacity = 600_000
    renderer.settings = settings

    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )

    _ = try live.simulation.advance(
      steps: arguments.preRollSteps,
      batchSize: 32,
      fieldCapture: .disabled
    )
    _ = try live.simulation.captureCurrentMacroscopicField()

    let cycleSteps = max(
      1,
      Int(
        (1 / Double(bird.wingKinematics.frequencyHz)
          / Double(configuration.scaling.timeStepSeconds)).rounded()
      )
    )
    let stepsPerFrame = max(
      1,
      Int((Double(cycleSteps) / Double(arguments.frameCount - 1)).rounded())
    )
    let baseDistance =
      max(
        configuration.domainSizeMeters.x,
        max(configuration.domainSizeMeters.y, configuration.domainSizeMeters.z)
      ) * 0.86

    for frameIndex in 0..<arguments.frameCount {
      let progress = Float(frameIndex) / Float(arguments.frameCount - 1)
      let orbit = 2 * Float.pi * progress
      var camera = CameraState()
      camera.target = center + SIMD3<Float>(-0.035, 0, 0.005)
      camera.distance = baseDistance * (1 + 0.018 * sin(orbit))
      camera.yaw = -0.74 + 0.24 * sin(orbit)
      camera.pitch = 0.27 + 0.055 * cos(orbit)
      renderer.camera = camera

      let texture = try renderer.renderOffscreen(
        width: arguments.width,
        height: arguments.height
      )
      let diagnostics = renderer.offscreenDiagnostics()
      guard diagnostics.maximumAbsolutePressure.isFinite,
        diagnostics.maximumQCriterion.isFinite,
        !diagnostics.qSurfaceOverflow
      else {
        throw CaptureError.invalidFrame(
          "frame \(frameIndex) did not contain finite, complete viewer diagnostics"
        )
      }
      let snapshot = try live.simulation.snapshot()
      let phase = positiveFraction(
        snapshot.timeSeconds * bird.wingKinematics.frequencyHz
      )
      let data = try pngData(
        texture: texture,
        width: arguments.width,
        height: arguments.height,
        step: snapshot.step,
        phase: phase
      )
      let output = arguments.outputDirectory.appendingPathComponent(
        String(format: "frame-%03d.png", frameIndex)
      )
      try data.write(to: output, options: .atomic)
      print(
        "captured \(frameIndex + 1)/\(arguments.frameCount) "
          + "step=\(snapshot.step) phase=\(String(format: "%.3f", phase)) "
          + "qMax=\(String(format: "%.1f", diagnostics.maximumQCriterion)) "
          + "qOverflow=\(diagnostics.qSurfaceOverflow)"
      )

      if frameIndex + 1 < arguments.frameCount {
        _ = try live.simulation.advance(
          steps: stepsPerFrame,
          batchSize: 32,
          fieldCapture: .required
        )
      }
    }
  }

  private static func positiveFraction(_ value: Float) -> Float {
    let remainder = value.truncatingRemainder(dividingBy: 1)
    return remainder >= 0 ? remainder : remainder + 1
  }

  static func pngData(
    texture: MTLTexture,
    width: Int,
    height: Int,
    step: UInt64,
    phase: Float
  ) throws -> Data {
    try pngData(texture: texture, width: width, height: height) { graphics in
      drawPresentationOverlay(
        graphics: graphics,
        width: width,
        height: height,
        step: step,
        phase: phase
      )
    }
  }

  static func pngData(
    texture: MTLTexture,
    width: Int,
    height: Int,
    overlay: (CGContext) -> Void
  ) throws -> Data {
    var bgra = [UInt8](repeating: 0, count: width * height * 4)
    texture.getBytes(
      &bgra,
      bytesPerRow: width * 4,
      from: MTLRegionMake2D(0, 0, width, height),
      mipmapLevel: 0
    )
    var rgba = [UInt8](repeating: 0, count: bgra.count)
    for pixel in 0..<(width * height) {
      let offset = pixel * 4
      rgba[offset] = bgra[offset + 2]
      rgba[offset + 1] = bgra[offset + 1]
      rgba[offset + 2] = bgra[offset]
      rgba[offset + 3] = 255
    }
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let provider = CGDataProvider(data: Data(rgba) as CFData),
      let baseImage = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGBitmapInfo(
          rawValue: CGImageAlphaInfo.noneSkipLast.rawValue
            | CGBitmapInfo.byteOrder32Big.rawValue
        ),
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
      ),
      let graphics = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          | CGBitmapInfo.byteOrder32Big.rawValue
      )
    else { throw CaptureError.imageAllocation }
    graphics.draw(
      baseImage,
      in: CGRect(x: 0, y: 0, width: width, height: height)
    )
    overlay(graphics)
    guard let image = graphics.makeImage(),
      let encoded = NSBitmapImageRep(cgImage: image).representation(
        using: .png,
        properties: [:]
      )
    else {
      throw CaptureError.pngEncoding
    }
    return encoded
  }

  private static func drawPresentationOverlay(
    graphics: CGContext,
    width: Int,
    height: Int,
    step: UInt64,
    phase: Float
  ) {
    graphics.saveGState()

    let scale = CGFloat(width) / 896
    let margin = 24 * scale
    let panel = NSRect(
      x: margin,
      y: CGFloat(height) - 86 * scale,
      width: 440 * scale,
      height: 58 * scale
    )
    graphics.setFillColor(
      NSColor(calibratedWhite: 0.015, alpha: 0.76).cgColor
    )
    graphics.addPath(
      CGPath(
        roundedRect: panel,
        cornerWidth: 12 * scale,
        cornerHeight: 12 * scale,
        transform: nil
      )
    )
    graphics.fillPath()

    drawText(
      "BIRDFLOWMETAL · NATIVE GPU VIEW",
      font: CTFontCreateUIFontForLanguage(
        .emphasizedSystem,
        19 * scale,
        nil
      )!,
      color: NSColor.white.cgColor,
      position: CGPoint(x: panel.minX + 15 * scale, y: panel.minY + 31 * scale),
      tracking: 0.4 * scale,
      context: graphics
    )
    drawText(
      "D3Q19 TRT  •  DEV Re 100  •  STEP \(step)  •  PHASE \(String(format: "%.2f", phase))",
      font: CTFontCreateUIFontForLanguage(
        .userFixedPitch,
        10.5 * scale,
        nil
      )!,
      color: NSColor(
        calibratedRed: 0.58,
        green: 0.82,
        blue: 1,
        alpha: 1
      ).cgColor,
      position: CGPoint(x: panel.minX + 16 * scale, y: panel.minY + 12 * scale),
      context: graphics
    )

    let validationPanel = NSRect(
      x: CGFloat(width) - margin - 258 * scale,
      y: panel.minY,
      width: 258 * scale,
      height: panel.height
    )
    graphics.setFillColor(
      NSColor(calibratedWhite: 0.015, alpha: 0.76).cgColor
    )
    graphics.addPath(
      CGPath(
        roundedRect: validationPanel,
        cornerWidth: 12 * scale,
        cornerHeight: 12 * scale,
        transform: nil
      )
    )
    graphics.fillPath()
    drawText(
      "VALIDATION PROGRESS",
      font: CTFontCreateUIFontForLanguage(
        .emphasizedSystem,
        13 * scale,
        nil
      )!,
      color: NSColor.white.cgColor,
      position: CGPoint(
        x: validationPanel.minX + 15 * scale,
        y: validationPanel.minY + 31 * scale
      ),
      tracking: 0.35 * scale,
      context: graphics
    )
    drawText(
      "C16 SOURCE-AWARE  •  PASSED",
      font: CTFontCreateUIFontForLanguage(
        .userFixedPitch,
        10.5 * scale,
        nil
      )!,
      color: NSColor(
        calibratedRed: 0.34,
        green: 0.93,
        blue: 0.72,
        alpha: 1
      ).cgColor,
      position: CGPoint(
        x: validationPanel.minX + 15 * scale,
        y: validationPanel.minY + 12 * scale
      ),
      context: graphics
    )

    var badgeX = margin
    badgeX = drawBadge(
      "PRESSURE",
      color: NSColor(calibratedRed: 0.20, green: 0.62, blue: 1, alpha: 1),
      x: badgeX,
      y: margin,
      scale: scale,
      context: graphics
    )
    badgeX = drawBadge(
      "VORTICITY",
      color: NSColor(calibratedRed: 1, green: 0.38, blue: 0.25, alpha: 1),
      x: badgeX + 7 * scale,
      y: margin,
      scale: scale,
      context: graphics
    )
    _ = drawBadge(
      "Q STRUCTURES",
      color: NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.86, alpha: 1),
      x: badgeX + 7 * scale,
      y: margin,
      scale: scale,
      context: graphics
    )

    graphics.restoreGState()
    graphics.flush()
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
    let font = CTFontCreateUIFontForLanguage(
      .userFixedPitch,
      9 * scale,
      nil
    )!
    let line = textLine(
      label,
      font: font,
      color: NSColor.white.cgColor,
      tracking: 0.5 * scale
    )
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let rect = NSRect(
      x: x,
      y: y,
      width: textWidth + 20 * scale,
      height: 24 * scale
    )
    context.setFillColor(NSColor(calibratedWhite: 0.015, alpha: 0.74).cgColor)
    context.addPath(
      CGPath(
        roundedRect: rect,
        cornerWidth: 12 * scale,
        cornerHeight: 12 * scale,
        transform: nil
      )
    )
    context.fillPath()
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
      y: rect.minY + 7 * scale
    )
    CTLineDraw(line, context)
    return rect.maxX
  }

  private static func drawText(
    _ text: String,
    font: CTFont,
    color: CGColor,
    position: CGPoint,
    tracking: CGFloat = 0,
    context: CGContext
  ) {
    let line = textLine(
      text,
      font: font,
      color: color,
      tracking: tracking
    )
    context.textPosition = position
    CTLineDraw(line, context)
  }

  private static func textLine(
    _ text: String,
    font: CTFont,
    color: CGColor,
    tracking: CGFloat
  ) -> CTLine {
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
      NSAttributedString.Key(kCTKernAttributeName as String): tracking,
    ]
    return CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: attributes)
    )
  }
}

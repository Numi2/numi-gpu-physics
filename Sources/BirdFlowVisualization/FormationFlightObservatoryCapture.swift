import AppKit
import BirdFlowMetal
import CoreText
import Foundation
import Metal
import simd

public enum FormationFlightObservatoryCapture {
  private struct ScoutSummary: Decodable {
    struct Case: Decodable {
      let zChords: Double
      let phaseOffsetCycles: Double
      let followerPositivePowerSavingFraction: Double
      let passed: Bool
    }

    let caseCount: Int
    let allCasesPassed: Bool
    let cases: [Case]
  }

  private struct C20DiscriminatorSummary: Decodable {
    struct Stage1: Decodable {
      struct PhaseResolvedFinePair: Decodable {
        struct Residual: Decodable {
          let maximumAbsolute: Double
          let maximumPhase: Double
          let rms: Double
        }

        let normalizedPowerResidual: Residual
      }

      struct Gates: Decodable {
        let passed: Bool
      }

      let c16SavingFraction: Double
      let c20SavingFraction: Double
      let relativeFinePairChange: Double
      let passed: Bool
      let gates: Gates
      let phaseResolvedFinePair: PhaseResolvedFinePair
    }

    let status: String
    let continuationThreshold: Double
    let quantitativeFormationClaimAuthorized: Bool
    let stage1: Stage1
  }

  private struct FlowSliceIndex: Decodable {
    struct Entry: Decodable {
      let file: String
      let leaderPhase: Double
      let followerPhase: Double
    }

    let entries: [Entry]
  }

  private struct PhaseFlowSlice {
    let entry: FlowSliceIndex.Entry
    let slice: FormationFlightFlowSlice
  }

  public struct Arguments {
    let outputDirectory: URL
    let reportURL: URL
    let flowSliceURL: URL?
    let flowSliceDirectoryURL: URL?
    let summaryURL: URL?
    let discriminatorURL: URL?
    let width: Int
    let height: Int
    let frameCount: Int

    public init(commandLine: [String]) throws {
      func value(after flag: String) throws -> String {
        guard let index = commandLine.firstIndex(of: flag),
          index + 1 < commandLine.count
        else {
          throw ReadmeShowcaseCapture.CaptureError.invalidArguments(
            "\(flag) requires a value"
          )
        }
        return commandLine[index + 1]
      }
      func integer(after flag: String, default fallback: Int) throws -> Int {
        guard commandLine.contains(flag) else { return fallback }
        let raw = try value(after: flag)
        guard let result = Int(raw), result > 0 else {
          throw ReadmeShowcaseCapture.CaptureError.invalidArguments(
            "\(flag) requires a positive integer"
          )
        }
        return result
      }
      outputDirectory = URL(
        fileURLWithPath: try value(after: "--capture-formation-frames"),
        isDirectory: true
      )
      reportURL = URL(
        fileURLWithPath: try value(after: "--capture-formation-report")
      )
      if commandLine.contains("--capture-formation-slice") {
        flowSliceURL = URL(
          fileURLWithPath: try value(after: "--capture-formation-slice")
        )
      } else {
        flowSliceURL = nil
      }
      if commandLine.contains("--capture-formation-slice-directory") {
        flowSliceDirectoryURL = URL(
          fileURLWithPath: try value(
            after: "--capture-formation-slice-directory"
          ),
          isDirectory: true
        )
      } else {
        flowSliceDirectoryURL = nil
      }
      if commandLine.contains("--capture-formation-summary") {
        summaryURL = URL(
          fileURLWithPath: try value(after: "--capture-formation-summary")
        )
      } else {
        summaryURL = nil
      }
      if commandLine.contains("--capture-formation-discriminator") {
        discriminatorURL = URL(
          fileURLWithPath: try value(
            after: "--capture-formation-discriminator"
          )
        )
      } else {
        discriminatorURL = nil
      }
      width = try integer(after: "--capture-width", default: 1120)
      height = try integer(after: "--capture-height", default: 630)
      frameCount = try integer(after: "--capture-frames", default: 49)
      guard frameCount >= 2 else {
        throw ReadmeShowcaseCapture.CaptureError.invalidArguments(
          "formation capture requires at least two frames"
        )
      }
    }
  }

  public static func run(_ arguments: Arguments) throws {
    guard let device = MTLCreateSystemDefaultDevice() else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "formation showcase requires Metal"
      )
    }
    let report = try JSONDecoder().decode(
      FormationFlightReport.self,
      from: Data(contentsOf: arguments.reportURL)
    )
    let flowSlice = try arguments.flowSliceURL.map {
      try JSONDecoder().decode(
        FormationFlightFlowSlice.self,
        from: Data(contentsOf: $0)
      )
    }
    let phaseFlowSlices = try arguments.flowSliceDirectoryURL.map {
      try loadPhaseFlowSlices(directory: $0)
    } ?? []
    let scoutSummary = try arguments.summaryURL.map {
      try JSONDecoder().decode(
        ScoutSummary.self,
        from: Data(contentsOf: $0)
      )
    }
    let discriminator = try arguments.discriminatorURL.map {
      try JSONDecoder().decode(
        C20DiscriminatorSummary.self,
        from: Data(contentsOf: $0)
      )
    }
    guard report.gates.passed, report.phaseSamples.count == 100 else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "formation showcase requires a passed 100-bin report"
      )
    }
    if let scoutSummary {
      let keys = Set(scoutSummary.cases.map {
        String(format: "%.6f/%.6f", $0.zChords, $0.phaseOffsetCycles)
      })
      let expectedKeys = Set([-3.0, -4.0].flatMap { z in
        [0.0, 0.25, 0.5, 0.75].map { phase in
          String(format: "%.6f/%.6f", z, phase)
        }
      })
      let selected = scoutSummary.cases.max {
        $0.followerPositivePowerSavingFraction
          < $1.followerPositivePowerSavingFraction
      }
      guard scoutSummary.allCasesPassed,
        scoutSummary.caseCount == 8,
        scoutSummary.cases.count == 8,
        scoutSummary.cases.allSatisfy(\.passed),
        keys == expectedKeys,
        report.configuration.chordCells == 8,
        report.configuration.followerOffsetChords.x == 0,
        report.configuration.followerOffsetChords.y == 0,
        abs(report.configuration.followerOffsetChords.z - (selected?.zChords ?? 0))
          < 1e-12,
        abs(
          report.configuration.followerPhaseOffsetCycles
            - (selected?.phaseOffsetCycles ?? 0)
        ) < 1e-12,
        abs(
          report.followerPositivePowerSavingFraction
            - (selected?.followerPositivePowerSavingFraction ?? 0)
        ) < 1e-12
      else {
        throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
          "formation showcase requires the exact passed scout matrix and its selected maximum report"
        )
      }
    }
    if let discriminator {
      guard discriminator.status == "stage1_failed_stop",
        !discriminator.stage1.passed,
        discriminator.stage1.gates.passed,
        !discriminator.quantitativeFormationClaimAuthorized,
        abs(discriminator.continuationThreshold - 0.05) < 1e-12,
        report.configuration.chordCells == 20,
        report.configuration.cycles == 5,
        report.configuration.followerOffsetChords.x == 0,
        report.configuration.followerOffsetChords.y == 0,
        abs(report.configuration.followerOffsetChords.z + 3) < 1e-12,
        abs(report.configuration.followerPhaseOffsetCycles - 0.25) < 1e-12,
        abs(
          report.followerPositivePowerSavingFraction
            - discriminator.stage1.c20SavingFraction
        ) < 1e-12,
        phaseFlowSlices.count == 21
      else {
        throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
          "c20 formation showcase requires the stopped preregistered discriminator and its 21 archived fields"
        )
      }
    }
    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )
    let renderer = try FormationObservatoryRenderer(device: device)
    for frameIndex in 0..<arguments.frameCount {
      let phase = frameIndex + 1 == arguments.frameCount
        ? Float.zero
        : Float(frameIndex) / Float(arguments.frameCount - 1)
      let phaseFlow = nearestPhaseFlowSlice(
        phaseFlowSlices,
        leaderPhase: Double(phase)
      )
      let displayedFlowSlice = phaseFlow?.slice ?? flowSlice
      let texture = try renderer.render(
        phase: phase,
        phaseOffset: Float(
          report.configuration.followerPhaseOffsetCycles
        ),
        followerOffsetChords: SIMD3<Float>(
          report.configuration.followerOffsetChords
        ),
        flowSlice: displayedFlowSlice,
        flowOpacity: phaseFlowOpacity(
          phaseFlowSlices,
          leaderPhase: Double(phase)
        ),
        width: arguments.width,
        height: arguments.height
      )
      let sampleIndex = min(
        99,
        Int(floor(Double(phase) * 100)) % 100
      )
      let sample = report.phaseSamples[sampleIndex]
      let png = try ReadmeShowcaseCapture.pngData(
        texture: texture,
        width: arguments.width,
        height: arguments.height
      ) { context in
        drawOverlay(
          context: context,
          width: arguments.width,
          height: arguments.height,
          report: report,
          sample: sample,
          phase: phase,
          displayedFlowPhase: phaseFlow.map { ($0.entry.leaderPhase, $0.entry.followerPhase) },
          hasFlowSlice: displayedFlowSlice != nil,
          scoutSummary: scoutSummary,
          discriminator: discriminator
        )
      }
      try png.write(
        to: arguments.outputDirectory.appendingPathComponent(
          String(format: "frame-%03d.png", frameIndex)
        ),
        options: .atomic
      )
      print(
        "captured formation \(frameIndex + 1)/\(arguments.frameCount) "
          + "phase=\(String(format: "%.3f", phase))"
      )
    }
  }

  private static func loadPhaseFlowSlices(
    directory: URL
  ) throws -> [PhaseFlowSlice] {
    let indexURL = directory.appendingPathComponent("index.json")
    let index = try JSONDecoder().decode(
      FlowSliceIndex.self,
      from: Data(contentsOf: indexURL)
    )
    return try index.entries.map { entry in
      let slice = try JSONDecoder().decode(
        FormationFlightFlowSlice.self,
        from: Data(
          contentsOf: directory.appendingPathComponent(entry.file)
        )
      )
      guard slice.chordCells == 20,
        abs(slice.phase - entry.leaderPhase) < 1e-9
      else {
        throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
          "phase-flow index and slice disagree for \(entry.file)"
        )
      }
      return PhaseFlowSlice(entry: entry, slice: slice)
    }
  }

  private static func circularDistance(_ a: Double, _ b: Double) -> Double {
    let direct = abs(a - b)
    return min(direct, 1 - direct)
  }

  private static func nearestPhaseFlowSlice(
    _ slices: [PhaseFlowSlice],
    leaderPhase: Double
  ) -> PhaseFlowSlice? {
    // Reuse the real zero-phase capture on both sides of the encoded seam. The
    // displayed field phase remains explicit in the overlay; no CFD values are
    // synthesized or interpolated for presentation.
    if circularDistance(leaderPhase, 0) <= 1.0 / 47.0 + 1e-6,
      let seamAnchor = slices.first(where: {
        abs($0.entry.leaderPhase) < 1e-12
      })
    {
      return seamAnchor
    }
    guard let nearest = slices.min(by: {
      circularDistance($0.entry.leaderPhase, leaderPhase)
        < circularDistance($1.entry.leaderPhase, leaderPhase)
    }), circularDistance(nearest.entry.leaderPhase, leaderPhase) <= 0.055
    else { return nil }
    return nearest
  }

  private static func phaseFlowOpacity(
    _ slices: [PhaseFlowSlice],
    leaderPhase: Double
  ) -> Float {
    guard let nearest = nearestPhaseFlowSlice(slices, leaderPhase: leaderPhase)
    else { return slices.isEmpty ? 1 : 0 }
    let distance = circularDistance(nearest.entry.leaderPhase, leaderPhase)
    let edge = max(0, min(1, (0.055 - distance) / 0.012))
    return Float(edge * edge * (3 - 2 * edge))
  }

  private static func drawOverlay(
    context: CGContext,
    width: Int,
    height: Int,
    report: FormationFlightReport,
    sample: FormationFlightPhaseSample,
    phase: Float,
    displayedFlowPhase: (leader: Double, follower: Double)?,
    hasFlowSlice: Bool,
    scoutSummary: ScoutSummary?,
    discriminator: C20DiscriminatorSummary?
  ) {
    context.saveGState()
    let scale = CGFloat(width) / 1120
    let margin = 34 * scale
    let titleFont = CTFontCreateWithName(
      "SF Pro Display Bold" as CFString,
      25 * scale,
      nil
    )
    let labelFont = CTFontCreateUIFontForLanguage(
      .userFixedPitch,
      11 * scale,
      nil
    )!
    let valueFont = CTFontCreateWithName(
      "SF Pro Display Semibold" as CFString,
      15 * scale,
      nil
    )
    drawText(
      "FORMATION FLIGHT OBSERVATORY",
      font: titleFont,
      color: NSColor(calibratedRed: 0.84, green: 0.94, blue: 1, alpha: 1)
        .cgColor,
      at: CGPoint(x: margin, y: CGFloat(height) - 50 * scale),
      context: context
    )
    drawText(
      discriminator == nil
        ? "ONE FLUID  •  TWO OWNERS  •  MATCHED ISOLATED CONTROLS"
        : "c20  •  FIVE CYCLES  •  PHASE-RESOLVED GPU FIELDS  •  MATCHED CONTROLS",
      font: labelFont,
      color: NSColor(calibratedRed: 0.30, green: 0.72, blue: 0.94, alpha: 1)
        .cgColor,
      at: CGPoint(x: margin, y: CGFloat(height) - 72 * scale),
      context: context
    )

    let panel = CGRect(
      x: margin,
      y: 28 * scale,
      width: 470 * scale,
      height: 112 * scale
    )
    context.setFillColor(
      NSColor(calibratedRed: 0.006, green: 0.016, blue: 0.035, alpha: 0.82)
        .cgColor
    )
    context.addPath(
      CGPath(
        roundedRect: panel,
        cornerWidth: 15 * scale,
        cornerHeight: 15 * scale,
        transform: nil
      )
    )
    context.fillPath()
    let saving = 100 * report.followerPositivePowerSavingFraction
    drawText(
      discriminator == nil
        ? String(format: "FOLLOWER  %+0.2f%% POSITIVE POWER", saving)
        : String(format: "FOLLOWER  %0.2f%% LESS POSITIVE POWER AT c20", saving),
      font: valueFont,
      color: saving >= 0
        ? NSColor(calibratedRed: 0.36, green: 0.95, blue: 0.68, alpha: 1)
          .cgColor
        : NSColor(calibratedRed: 1, green: 0.48, blue: 0.32, alpha: 1)
          .cgColor,
      at: CGPoint(x: panel.minX + 18 * scale, y: panel.maxY - 30 * scale),
      context: context
    )
    drawText(
      String(
        format: "phase %.3f  Δφ %.3f  P_lead %.4f W  P_follow %.4f W",
        phase,
        report.configuration.followerPhaseOffsetCycles,
        sample.leaderSignedPowerWatts,
        sample.followerSignedPowerWatts
      ),
      font: labelFont,
      color: NSColor(calibratedWhite: 0.82, alpha: 1).cgColor,
      at: CGPoint(x: panel.minX + 18 * scale, y: panel.maxY - 56 * scale),
      context: context
    )
    drawText(
      String(
        format: "owner closure  F %.2e  τ %.2e  •  overlap %d",
        report.gates.maximumRelativeForceClosureResidual,
        report.gates.maximumRelativeTorqueClosureResidual,
        report.overlapVoxelSamples
      ),
      font: labelFont,
      color: NSColor(calibratedRed: 0.47, green: 0.83, blue: 1, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 18 * scale, y: panel.maxY - 81 * scale),
      context: context
    )
    drawText(
      discriminator.map {
        String(
          format: "STOP  c16→c20 %.2f%% > %.1f%%  •  QUANTITATIVE CLAIM OPEN",
          100 * $0.stage1.relativeFinePairChange,
          100 * $0.continuationThreshold
        )
      } ?? "c8 three-cycle screen • interaction hypothesis, refinement open",
      font: labelFont,
      color: discriminator == nil
        ? NSColor(calibratedWhite: 0.58, alpha: 1).cgColor
        : NSColor(calibratedRed: 1, green: 0.43, blue: 0.38, alpha: 1)
          .cgColor,
      at: CGPoint(x: panel.minX + 18 * scale, y: panel.maxY - 104 * scale),
      context: context
    )

    drawText(
      displayedFlowPhase.map {
        String(
          format: "actual c20 CFD  •  L %.3f  F %.3f",
          $0.leader,
          $0.follower
        )
      } ?? (hasFlowSlice
        ? "archived CFD slice + wake-history guides"
        : "kinematic wake guides  •  CFD observed only in gold windows"),
      font: labelFont,
      color: NSColor(calibratedWhite: 0.48, alpha: 1).cgColor,
      at: CGPoint(
        x: CGFloat(width) - 314 * scale,
        y: 34 * scale
      ),
      context: context
    )
    if hasFlowSlice {
      drawText(
        "blue: down w  •  orange: up w  •  opacity: |ω|",
        font: labelFont,
        color: NSColor(calibratedWhite: 0.62, alpha: 1).cgColor,
        at: CGPoint(
          x: CGFloat(width) - 314 * scale,
          y: 54 * scale
        ),
        context: context
      )
    }
    drawText(
      "LEADER",
      font: valueFont,
      color: NSColor(calibratedRed: 0.18, green: 0.78, blue: 1, alpha: 1)
        .cgColor,
      at: CGPoint(x: CGFloat(width) - 214 * scale, y: 420 * scale),
      context: context
    )
    drawText(
      "FOLLOWER",
      font: valueFont,
      color: NSColor(calibratedRed: 1, green: 0.44, blue: 0.20, alpha: 1)
        .cgColor,
      at: CGPoint(x: CGFloat(width) - 214 * scale, y: 250 * scale),
      context: context
    )
    if let scoutSummary {
      drawScoutMap(
        scoutSummary,
        width: width,
        scale: scale,
        labelFont: labelFont,
        context: context
      )
    }
    if let discriminator {
      drawC20Decision(
        discriminator,
        phase: phase,
        width: width,
        scale: scale,
        labelFont: labelFont,
        valueFont: valueFont,
        context: context
      )
    }
    context.restoreGState()
  }

  private static func drawC20Decision(
    _ summary: C20DiscriminatorSummary,
    phase: Float,
    width: Int,
    scale: CGFloat,
    labelFont: CTFont,
    valueFont: CTFont,
    context: CGContext
  ) {
    let panel = CGRect(
      x: CGFloat(width) - 330 * scale,
      y: 449 * scale,
      width: 296 * scale,
      height: 134 * scale
    )
    context.setFillColor(
      NSColor(calibratedRed: 0.006, green: 0.016, blue: 0.035, alpha: 0.82)
        .cgColor
    )
    context.addPath(
      CGPath(
        roundedRect: panel,
        cornerWidth: 13 * scale,
        cornerHeight: 13 * scale,
        transform: nil
      )
    )
    context.fillPath()
    context.setStrokeColor(
      NSColor(calibratedRed: 1, green: 0.34, blue: 0.30, alpha: 0.62)
        .cgColor
    )
    context.setLineWidth(1.1 * scale)
    context.stroke(panel.insetBy(dx: 0.6 * scale, dy: 0.6 * scale))

    drawText(
      "PREREGISTERED c20 DECISION",
      font: valueFont,
      color: NSColor(calibratedRed: 0.86, green: 0.96, blue: 1, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 14 * scale, y: panel.maxY - 25 * scale),
      context: context
    )
    drawText(
      String(
        format: "c16 %.2f%%  →  c20 %.2f%%",
        100 * summary.stage1.c16SavingFraction,
        100 * summary.stage1.c20SavingFraction
      ),
      font: labelFont,
      color: NSColor(calibratedRed: 0.44, green: 0.88, blue: 1, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 14 * scale, y: panel.maxY - 48 * scale),
      context: context
    )
    drawText(
      String(
        format: "fine pair %.2f%% > %.2f%% limit",
        100 * summary.stage1.relativeFinePairChange,
        100 * summary.continuationThreshold
      ),
      font: labelFont,
      color: NSColor(calibratedRed: 1, green: 0.47, blue: 0.40, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 14 * scale, y: panel.maxY - 68 * scale),
      context: context
    )
    let residual = summary.stage1.phaseResolvedFinePair.normalizedPowerResidual
    drawText(
      String(
        format: "waveform RMS %.3f  •  L∞ %.3f @ %.3f",
        residual.rms,
        residual.maximumAbsolute,
        residual.maximumPhase
      ),
      font: labelFont,
      color: NSColor(calibratedWhite: 0.72, alpha: 1).cgColor,
      at: CGPoint(x: panel.minX + 14 * scale, y: panel.maxY - 88 * scale),
      context: context
    )

    let railX = panel.minX + 14 * scale
    let railY = panel.minY + 22 * scale
    let railWidth = panel.width - 28 * scale
    context.setStrokeColor(NSColor(calibratedWhite: 0.35, alpha: 1).cgColor)
    context.setLineWidth(1 * scale)
    context.move(to: CGPoint(x: railX, y: railY))
    context.addLine(to: CGPoint(x: railX + railWidth, y: railY))
    context.strokePath()
    for (start, end) in [(0.0, 0.05), (0.45, 0.55), (0.95, 1.0)] {
      context.setFillColor(
        NSColor(calibratedRed: 0.98, green: 0.76, blue: 0.30, alpha: 0.48)
          .cgColor
      )
      context.fill(
        CGRect(
          x: railX + CGFloat(start) * railWidth,
          y: railY - 3 * scale,
          width: CGFloat(end - start) * railWidth,
          height: 6 * scale
        )
      )
    }
    let phaseX = railX + CGFloat(phase) * railWidth
    context.setFillColor(
      NSColor(calibratedRed: 0.38, green: 0.94, blue: 1, alpha: 1).cgColor
    )
    context.fillEllipse(
      in: CGRect(
        x: phaseX - 3.5 * scale,
        y: railY - 3.5 * scale,
        width: 7 * scale,
        height: 7 * scale
      )
    )
    drawText(
      "20 archived CFD phases  •  gates pass",
      font: labelFont,
      color: NSColor(calibratedWhite: 0.52, alpha: 1).cgColor,
      at: CGPoint(x: railX, y: panel.minY + 6 * scale),
      context: context
    )
  }

  private static func drawScoutMap(
    _ summary: ScoutSummary,
    width: Int,
    scale: CGFloat,
    labelFont: CTFont,
    context: CGContext
  ) {
    let phases = [0.0, 0.25, 0.5, 0.75]
    let separations = [-3.0, -4.0]
    let cellWidth = 59 * scale
    let cellHeight = 29 * scale
    let gap = 4 * scale
    let originX = CGFloat(width) - 282 * scale
    let originY = 493 * scale
    let values = summary.cases.map(
      \.followerPositivePowerSavingFraction
    )
    let minimum = values.min() ?? 0
    let maximum = values.max() ?? 1
    let span = max(maximum - minimum, 1e-12)

    drawText(
      "PREREGISTERED c8 MAP  •  SAVING VS ISOLATED",
      font: labelFont,
      color: NSColor(calibratedWhite: 0.72, alpha: 1).cgColor,
      at: CGPoint(x: originX, y: originY + 74 * scale),
      context: context
    )
    for (column, phase) in phases.enumerated() {
      drawText(
        String(format: "Δφ %.2g", phase),
        font: labelFont,
        color: NSColor(calibratedWhite: 0.52, alpha: 1).cgColor,
        at: CGPoint(
          x: originX + CGFloat(column) * (cellWidth + gap) + 7 * scale,
          y: originY + 53 * scale
        ),
        context: context
      )
    }
    for (row, separation) in separations.enumerated() {
      let y = originY - CGFloat(row) * (cellHeight + gap)
      drawText(
        String(format: "z %.0f", separation),
        font: labelFont,
        color: NSColor(calibratedWhite: 0.62, alpha: 1).cgColor,
        at: CGPoint(x: originX - 35 * scale, y: y + 9 * scale),
        context: context
      )
      for (column, phase) in phases.enumerated() {
        guard let result = summary.cases.first(where: {
          abs($0.zChords - separation) < 1e-9
            && abs($0.phaseOffsetCycles - phase) < 1e-9
        }) else { continue }
        let normalized = CGFloat(
          (result.followerPositivePowerSavingFraction - minimum) / span
        )
        let x = originX + CGFloat(column) * (cellWidth + gap)
        let rect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
        context.setFillColor(
          NSColor(
            calibratedRed: 0.04 + 0.10 * normalized,
            green: 0.22 + 0.48 * normalized,
            blue: 0.30 + 0.34 * normalized,
            alpha: 0.90
          ).cgColor
        )
        context.addPath(
          CGPath(
            roundedRect: rect,
            cornerWidth: 5 * scale,
            cornerHeight: 5 * scale,
            transform: nil
          )
        )
        context.fillPath()
        if result.followerPositivePowerSavingFraction == maximum {
          context.setStrokeColor(
            NSColor(calibratedRed: 0.28, green: 0.92, blue: 1, alpha: 1)
              .cgColor
          )
          context.setLineWidth(1.5 * scale)
          context.stroke(rect.insetBy(dx: 1 * scale, dy: 1 * scale))
        }
        drawText(
          String(
            format: "%.2f%%",
            100 * result.followerPositivePowerSavingFraction
          ),
          font: labelFont,
          color: NSColor(calibratedWhite: 0.94, alpha: 1).cgColor,
          at: CGPoint(x: x + 9 * scale, y: y + 9 * scale),
          context: context
        )
      }
    }
  }

  private static func drawText(
    _ text: String,
    font: CTFont,
    color: CGColor,
    at point: CGPoint,
    context: CGContext
  ) {
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(
        string: text,
        attributes: [
          NSAttributedString.Key(kCTFontAttributeName as String): font,
          NSAttributedString.Key(kCTForegroundColorAttributeName as String):
            color,
        ]
      )
    )
    context.textPosition = point
    CTLineDraw(line, context)
  }
}

private final class FormationObservatoryRenderer {
  private let backend: VisualizationBackend
  private let surfacePipeline: MTLRenderPipelineState
  private let trailPipeline: MTLRenderPipelineState
  private let wirePipeline: MTLRenderPipelineState
  private let backgroundPipeline: MTLRenderPipelineState
  private let depthWriteState: MTLDepthStencilState
  private let depthReadState: MTLDepthStencilState

  init(device: MTLDevice) throws {
    backend = try VisualizationBackend(device: device)
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
    depthWriteState = device.makeDepthStencilState(descriptor: write)!
    let read = MTLDepthStencilDescriptor()
    read.depthCompareFunction = .lessEqual
    read.isDepthWriteEnabled = false
    depthReadState = device.makeDepthStencilState(descriptor: read)!
  }

  func render(
    phase: Float,
    phaseOffset: Float,
    followerOffsetChords: SIMD3<Float>,
    flowSlice: FormationFlightFlowSlice?,
    flowOpacity: Float,
    width: Int,
    height: Int
  ) throws -> MTLTexture {
    let leaderRoot = -0.5 * followerOffsetChords
    let followerRoot = 0.5 * followerOffsetChords
    let leader = wingVertices(
      root: leaderRoot,
      phase: phase,
      color: SIMD3<Float>(0.08, 0.68, 1)
    )
    let follower = wingVertices(
      root: followerRoot,
      phase: phase + phaseOffset,
      color: SIMD3<Float>(1, 0.34, 0.12)
    )
    let surfaces = leader + follower
    let orbit = 2 * Float.pi * phase
    var camera = CameraState()
    camera.target = SIMD3<Float>(0.6, 0, -1.0)
    camera.distance = 12.6 + 0.25 * sin(orbit)
    camera.yaw = -0.76 + 0.10 * sin(orbit)
    camera.pitch = 0.22 + 0.035 * cos(orbit)
    let trails = wakeTrails(
      root: leaderRoot,
      phase: phase,
      color: SIMD3<Float>(0.08, 0.68, 1),
      camera: camera
    ) + wakeTrails(
      root: followerRoot,
      phase: phase + phaseOffset,
      color: SIMD3<Float>(1, 0.34, 0.12),
      camera: camera
    )
    let slice = flowSlice.map {
      flowSliceVertices($0, opacity: flowOpacity)
    } ?? []
    let surfaceBuffer = try sharedBuffer(surfaces)
    let trailBuffers = try trails.map(sharedBuffer)
    let sliceBuffer = slice.isEmpty ? nil : try sharedBuffer(slice)

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
    else { throw VisualizationError.allocation(width * height * 8) }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = color
    pass.colorAttachments[0].loadAction = .clear
    pass.colorAttachments[0].storeAction = .store
    pass.colorAttachments[0].clearColor = MTLClearColorMake(0.002, 0.006, 0.016, 1)
    pass.depthAttachment.texture = depth
    pass.depthAttachment.loadAction = .clear
    pass.depthAttachment.storeAction = .dontCare
    pass.depthAttachment.clearDepth = 1
    var cameraUniforms = camera.uniforms(
      aspect: Float(width) / Float(height),
      ribbonWidth: 0.02
    )
    var background = SIMD4<Float>(
      phase,
      Float(width) / Float(height),
      0,
      0
    )
    let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)!
    encoder.setCullMode(.none)
    encoder.setRenderPipelineState(backgroundPipeline)
    encoder.setFragmentBytes(
      &background,
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
    if let sliceBuffer {
      encoder.setVertexBuffer(sliceBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(
        type: .triangle,
        vertexStart: 0,
        vertexCount: slice.count
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
      vertexCount: surfaces.count
    )
    encoder.setDepthStencilState(depthReadState)
    encoder.setRenderPipelineState(wirePipeline)
    encoder.setTriangleFillMode(.lines)
    encoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: surfaces.count
    )
    encoder.endEncoding()
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()
    guard commandBuffer.status == .completed else {
      throw VisualizationError.shader(
        commandBuffer.error?.localizedDescription
          ?? "formation showcase render failed"
      )
    }
    return color
  }

  private func wingVertices(
    root: SIMD3<Float>,
    phase: Float,
    color: SIMD3<Float>
  ) -> [ColoredVertex] {
    let state = MetalFlappingWingValidator.kinematicState(
      phase: Double(wrapped(phase))
    )
    let stroke = Float(state.strokeAngleRadians)
    let pitch = Float(state.pitchAngleRadians)
    let span = SIMD3<Float>(cos(stroke), sin(stroke), 0)
    let tangent = SIMD3<Float>(-sin(stroke), cos(stroke), 0)
    let chord = rotate(tangent, axis: span, angle: -pitch)
    let normal = simd_normalize(simd_cross(span, chord))
    let radius: Float = 3
    let segments = 32
    let halfThickness: Float = 0.035
    var result: [ColoredVertex] = []
    result.reserveCapacity(segments * 24)
    func edges(_ index: Int) -> (SIMD3<Float>, SIMD3<Float>) {
      let fraction = Float(index) / Float(segments)
      let beta = max(fraction * (1 - fraction), 0)
      let localChord = Float(MetalFlappingWingValidator.betaNormalization)
        * pow(
          beta,
          Float(MetalFlappingWingValidator.betaShape - 1)
        )
      let radial = radius * fraction
      let leading = root + radial * span - 0.25 * chord
      return (leading, leading + localChord * chord)
    }
    let surfaceColor = SIMD4<Float>(color, 0.98)
    for index in 0..<segments {
      let a = edges(index)
      let b = edges(index + 1)
      appendQuad(
        a.0 + halfThickness * normal,
        a.1 + halfThickness * normal,
        b.1 + halfThickness * normal,
        b.0 + halfThickness * normal,
        normal: normal,
        color: surfaceColor,
        to: &result
      )
      appendQuad(
        a.1 - halfThickness * normal,
        a.0 - halfThickness * normal,
        b.0 - halfThickness * normal,
        b.1 - halfThickness * normal,
        normal: -normal,
        color: surfaceColor,
        to: &result
      )
    }
    return result
  }

  private func flowSliceVertices(
    _ slice: FormationFlightFlowSlice,
    opacity: Float
  ) -> [ColoredVertex] {
    guard slice.plane == "y",
      slice.width > 2,
      slice.height > 2,
      slice.vorticityMagnitudePerSecond.count == slice.width * slice.height,
      slice.verticalVelocityMetersPerSecond.count == slice.width * slice.height,
      slice.ownerMask.count == slice.width * slice.height
    else { return [] }
    let chord = Float(slice.chordCells)
    let maximumVorticity = max(
      slice.maximumVorticityMagnitudePerSecond,
      1e-8
    )
    let maximumVertical = max(
      slice.maximumAbsoluteVerticalVelocityMetersPerSecond,
      1e-8
    )
    var result: [ColoredVertex] = []
    result.reserveCapacity(slice.width * slice.height * 6)
    for z in 0..<(slice.height - 1) {
      for x in 0..<(slice.width - 1) {
        let index = x + slice.width * z
        guard slice.ownerMask[index] == 0 else { continue }
        let vorticity = slice.vorticityMagnitudePerSecond[index]
        let normalizedVorticity = min(
          sqrt(max(vorticity, 0) / (0.35 * maximumVorticity)),
          1
        )
        guard normalizedVorticity > 0.025 else { continue }
        let vertical = slice.verticalVelocityMetersPerSecond[index]
        let normalizedVertical = min(abs(vertical) / maximumVertical, 1)
        let down = SIMD3<Float>(0.04, 0.66, 1.0)
        let up = SIMD3<Float>(1.0, 0.24, 0.10)
        let neutral = SIMD3<Float>(0.22, 0.36, 0.48)
        let signedColor = vertical <= 0 ? down : up
        let rgb = simd_mix(
          neutral,
          signedColor,
          SIMD3<Float>(repeating: 0.32 + 0.68 * normalizedVertical)
        )
        let color = SIMD4<Float>(
          rgb,
          max(0, min(opacity, 1))
            * (0.035 + 0.24 * normalizedVorticity)
        )
        let x0 = (Float(x) - 0.5 * Float(slice.width)) / chord
        let x1 = (Float(x + 1) - 0.5 * Float(slice.width)) / chord
        let z0 = (Float(z) - 0.5 * Float(slice.height)) / chord
        let z1 = (Float(z + 1) - 0.5 * Float(slice.height)) / chord
        appendQuad(
          SIMD3<Float>(x0, 0.04, z0),
          SIMD3<Float>(x1, 0.04, z0),
          SIMD3<Float>(x1, 0.04, z1),
          SIMD3<Float>(x0, 0.04, z1),
          normal: SIMD3<Float>(0, 1, 0),
          color: color,
          to: &result
        )
      }
    }
    return result
  }

  private func wakeTrails(
    root: SIMD3<Float>,
    phase: Float,
    color: SIMD3<Float>,
    camera: CameraState
  ) -> [[ColoredVertex]] {
    (0..<5).flatMap { ribbon in
      let radial = 0.65 + 0.52 * Float(ribbon)
      var points: [SIMD3<Float>] = []
      for sample in 0..<42 {
        let age = Float(sample) / 41
        let history = phase - 0.32 * age
        let state = MetalFlappingWingValidator.kinematicState(
          phase: Double(wrapped(history))
        )
        let stroke = Float(state.strokeAngleRadians)
        let swirl = stroke + 2.4 * age + 0.45 * Float(ribbon)
        points.append(
          root
            + SIMD3<Float>(radial * cos(swirl), radial * sin(swirl), 0)
            + SIMD3<Float>(0.28 * age, 0, -5.2 * age)
        )
      }
      return [
        trailVertices(
          points: points,
          color: color,
          camera: camera,
          width: 0.035,
          alpha: 0.24
        ),
        trailVertices(
          points: points,
          color: min(color + SIMD3<Float>(0.28, 0.28, 0.28), 1),
          camera: camera,
          width: 0.012,
          alpha: 0.72
        ),
      ]
    }
  }

  private func trailVertices(
    points: [SIMD3<Float>],
    color: SIMD3<Float>,
    camera: CameraState,
    width: Float,
    alpha: Float
  ) -> [ColoredVertex] {
    points.indices.flatMap { index -> [ColoredVertex] in
      let previous = points[max(0, index - 1)]
      let next = points[min(points.count - 1, index + 1)]
      let tangent = simd_normalize(next - previous + SIMD3<Float>(1e-8, 0, 0))
      let view = simd_normalize(camera.eye - points[index])
      let lateral = simd_normalize(
        simd_cross(view, tangent) + SIMD3<Float>(1e-8, 0, 0)
      )
      let age = Float(index) / Float(points.count - 1)
      let value = ColoredVertex(
        position: SIMD4<Float>(points[index] - width * lateral, 1),
        normal: SIMD4<Float>(view, 0),
        color: SIMD4<Float>(color, alpha * (1 - 0.76 * age))
      )
      let opposite = ColoredVertex(
        position: SIMD4<Float>(points[index] + width * lateral, 1),
        normal: SIMD4<Float>(view, 0),
        color: value.color
      )
      return [value, opposite]
    }
  }

  private func appendQuad(
    _ a: SIMD3<Float>,
    _ b: SIMD3<Float>,
    _ c: SIMD3<Float>,
    _ d: SIMD3<Float>,
    normal: SIMD3<Float>,
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    for point in [a, b, c, a, c, d] {
      result.append(
        ColoredVertex(
          position: SIMD4<Float>(point, 1),
          normal: SIMD4<Float>(normal, 0),
          color: color
        )
      )
    }
  }

  private func rotate(
    _ vector: SIMD3<Float>,
    axis: SIMD3<Float>,
    angle: Float
  ) -> SIMD3<Float> {
    vector * cos(angle)
      + simd_cross(axis, vector) * sin(angle)
      + axis * simd_dot(axis, vector) * (1 - cos(angle))
  }

  private func wrapped(_ phase: Float) -> Float {
    let value = phase.truncatingRemainder(dividingBy: 1)
    return value >= 0 ? value : value + 1
  }

  private func sharedBuffer(_ vertices: [ColoredVertex]) throws -> MTLBuffer {
    let length = max(16, vertices.count * MemoryLayout<ColoredVertex>.stride)
    guard let buffer = backend.device.makeBuffer(
      length: length,
      options: [.storageModeShared]
    ) else { throw VisualizationError.allocation(length) }
    if !vertices.isEmpty {
      _ = vertices.withUnsafeBytes { bytes in
        memcpy(buffer.contents(), bytes.baseAddress!, bytes.count)
      }
    }
    return buffer
  }
}

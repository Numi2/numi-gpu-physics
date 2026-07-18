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

  private struct GeometrySubcellSummary: Decodable {
    struct DecisionMetrics: Decodable {
      let meanDensityBetweenEndpoints: Bool
      let normalizedMeanDensityMidpointCurvature: Double
      let normalizedMeanDirectionMidpointCurvature: Double
      let normalizedMeanArealProfileMidpointCurvature: Double
    }

    struct Gates: Decodable {
      let exactBaselineBridgeParity: Bool
      let completeTensorGrid: Bool
      let noFluidTimesteps: Bool
      let positiveLinkSupport: Bool
      let zeroOverlap: Bool
      let allFinite: Bool
    }

    let caseCount: Int
    let offsetCountPerResolution: Int
    let noFluidTimesteps: Bool
    let classification: String
    let decisionMetrics: DecisionMetrics
    let gates: Gates
    let passed: Bool
  }

  private struct FormationSourceSummary: Decodable {
    struct DecisionMetrics: Decodable {
      let normalizedArealLinkProfileCurvature: Double
      let normalizedConditionalPopulationCurvature: Double
      let normalizedPopulationWeightedSourceCurvature: Double
      let selectedGeometryDensityCurvature: Double
      let smoothRefinementMaximumCurvature: Double
      let persistentBiasMinimumCurvature: Double
    }

    struct Gates: Decodable {
      let allFinite: Bool
      let allSourceCensusesPassed: Bool
      let allThreeRunsPassed: Bool
      let commonSubcellOffset: Bool
      let deterministicSelectionPassed: Bool
      let geometryPhaseSmooth: Bool
      let oneLeaderAndFollowerSamplePerGrid: Bool
      let preregisteredBeforeTranslatedCFD: Bool
    }

    let classification: String
    let decisionMetrics: DecisionMetrics
    let gates: Gates
    let passed: Bool
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
    let geometrySubcellSummaryURL: URL?
    let formationSourceSummaryURL: URL?
    let doveManifestURL: URL?
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
      if commandLine.contains("--capture-formation-subcell-summary") {
        geometrySubcellSummaryURL = URL(
          fileURLWithPath: try value(
            after: "--capture-formation-subcell-summary"
          )
        )
      } else {
        geometrySubcellSummaryURL = nil
      }
      if commandLine.contains("--capture-formation-source-summary") {
        formationSourceSummaryURL = URL(
          fileURLWithPath: try value(
            after: "--capture-formation-source-summary"
          )
        )
      } else {
        formationSourceSummaryURL = nil
      }
      if commandLine.contains("--capture-formation-dove-manifest") {
        doveManifestURL = URL(
          fileURLWithPath: try value(
            after: "--capture-formation-dove-manifest"
          )
        )
      } else {
        doveManifestURL = nil
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
    let geometrySubcellSummary = try arguments.geometrySubcellSummaryURL.map {
      try JSONDecoder().decode(
        GeometrySubcellSummary.self,
        from: Data(contentsOf: $0)
      )
    }
    let formationSourceSummary = try arguments.formationSourceSummaryURL.map {
      try JSONDecoder().decode(
        FormationSourceSummary.self,
        from: Data(contentsOf: $0)
      )
    }
    let doveDataset = try arguments.doveManifestURL.map {
      try MeasuredBirdSurfaceSequenceLoader.load(manifestURL: $0)
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
    if let summary = geometrySubcellSummary {
      let metrics = summary.decisionMetrics
      let gates = summary.gates
      guard summary.passed,
        summary.caseCount == 192,
        summary.offsetCountPerResolution == 64,
        summary.noFluidTimesteps,
        summary.classification == "aliasingAveragedOut",
        metrics.meanDensityBetweenEndpoints,
        metrics.normalizedMeanDensityMidpointCurvature <= 0.5,
        metrics.normalizedMeanDirectionMidpointCurvature <= 0.5,
        metrics.normalizedMeanArealProfileMidpointCurvature <= 0.5,
        gates.exactBaselineBridgeParity,
        gates.completeTensorGrid,
        gates.noFluidTimesteps,
        gates.positiveLinkSupport,
        gates.zeroOverlap,
        gates.allFinite
      else {
        throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
          "formation showcase requires the accepted 192-pose subcell geometry ensemble"
        )
      }
    }
    if let summary = formationSourceSummary {
      let metrics = summary.decisionMetrics
      let gates = summary.gates
      guard summary.passed,
        summary.classification == "mixedPopulationWeightedSource",
        metrics.selectedGeometryDensityCurvature
          <= metrics.smoothRefinementMaximumCurvature,
        metrics.normalizedPopulationWeightedSourceCurvature
          > metrics.smoothRefinementMaximumCurvature,
        metrics.normalizedPopulationWeightedSourceCurvature
          < metrics.persistentBiasMinimumCurvature,
        gates.allFinite,
        gates.allSourceCensusesPassed,
        gates.allThreeRunsPassed,
        gates.commonSubcellOffset,
        gates.deterministicSelectionPassed,
        gates.geometryPhaseSmooth,
        gates.oneLeaderAndFollowerSamplePerGrid,
        gates.preregisteredBeforeTranslatedCFD
      else {
        throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
          "formation showcase requires the passed common-offset source discriminator"
        )
      }
    }
    guard let doveDataset,
      doveDataset.datasetIdentifier
        == "deetjen-ob-2018-12-11-f03-complete-surface-v1",
      doveDataset.scientificTier == "derived-measured-complete-surface",
      doveDataset.sourceDatasetDOI == "10.5061/dryad.wwpzgmsqs",
      doveDataset.sourceArticleDOI == "10.7554/eLife.89968",
      doveDataset.sourceLicense == "CC0-1.0",
      doveDataset.frameCount == 144,
      doveDataset.vertexCount == 2_157,
      doveDataset.triangleCount == 3_968,
      doveDataset.components.map(\.partIdentifier) == [1, 2, 3, 4],
      doveDataset.completeBirdSurfaceReady,
      !doveDataset.quantitativeForceAcceptanceReady
    else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "formation showcase requires the locked presentation-only Deetjen dove surface sequence"
      )
    }
    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )
    let renderer = try FormationObservatoryRenderer(
      device: device,
      doveDataset: doveDataset
    )
    let uniqueCapturePhases = (0..<(arguments.frameCount - 1)).map {
      Double($0) / Double(arguments.frameCount - 1)
    }
    let visibleFlowPhases = uniqueCapturePhases.filter {
      nearestPhaseFlowSlice(phaseFlowSlices, leaderPhase: $0) != nil
        && phaseFlowOpacity(phaseFlowSlices, leaderPhase: $0) > 0
    }
    let minimumFlowOpacity = uniqueCapturePhases.map {
      phaseFlowOpacity(phaseFlowSlices, leaderPhase: $0)
    }.min() ?? 0
    let presentationAudit = renderer.dovePresentationAudit(
      flyerPairPhaseOffsetCycles: Float(
        report.configuration.followerPhaseOffsetCycles
      ),
      archivedFlowSliceCount: phaseFlowSlices.count,
      capturePhaseCount: uniqueCapturePhases.count,
      capturePhasesWithVisibleFlow: visibleFlowPhases.count,
      minimumFlowOpacity: minimumFlowOpacity
    )
    guard presentationAudit.passed else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "formation presentation failed the measured-dove provenance and loop contract"
      )
    }
    let auditEncoder = JSONEncoder()
    auditEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try auditEncoder.encode(presentationAudit).write(
      to: arguments.outputDirectory.appendingPathComponent(
        "presentation-geometry-audit.json"
      ),
      options: .atomic
    )
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
          discriminator: discriminator,
          geometrySubcellSummary: geometrySubcellSummary,
          formationSourceSummary: formationSourceSummary
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
    })
    else { return nil }
    return nearest
  }

  private static func phaseFlowOpacity(
    _ slices: [PhaseFlowSlice],
    leaderPhase: Double
  ) -> Float {
    nearestPhaseFlowSlice(slices, leaderPhase: leaderPhase) == nil
      ? (slices.isEmpty ? 1 : 0)
      : 1
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
    discriminator: C20DiscriminatorSummary?,
    geometrySubcellSummary: GeometrySubcellSummary?,
    formationSourceSummary: FormationSourceSummary?
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
        : String(
          format: "DEETJEN DOVE SHELLS  •  FLYER PAIR Δφ %.2f  •  CFD + LOADS: PRESCRIBED-WING CANONICAL",
          report.configuration.followerPhaseOffsetCycles
        ),
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
          format: "nearest archived c20 CFD (phase hold)  •  L %.3f  F %.3f",
          $0.leader,
          $0.follower
        )
      } ?? (hasFlowSlice
        ? "archived CFD slice + wake-history guides"
        : "dove wingtip guides  •  no archived CFD available"),
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
      "LEADER  •  DOVE REPLAY",
      font: valueFont,
      color: NSColor(calibratedRed: 0.18, green: 0.78, blue: 1, alpha: 1)
        .cgColor,
      at: CGPoint(x: CGFloat(width) - 214 * scale, y: 420 * scale),
      context: context
    )
    drawText(
      "FOLLOWER  •  DOVE REPLAY",
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
    if let formationSourceSummary {
      drawFormationSourceDecision(
        formationSourceSummary,
        scale: scale,
        labelFont: labelFont,
        valueFont: valueFont,
        context: context
      )
    } else if let geometrySubcellSummary {
      drawGeometrySubcellDecision(
        geometrySubcellSummary,
        scale: scale,
        labelFont: labelFont,
        valueFont: valueFont,
        context: context
      )
    }
    context.restoreGState()
  }

  private static func drawFormationSourceDecision(
    _ summary: FormationSourceSummary,
    scale: CGFloat,
    labelFont: CTFont,
    valueFont: CTFont,
    context: CGContext
  ) {
    let panel = CGRect(
      x: 520 * scale,
      y: 28 * scale,
      width: 278 * scale,
      height: 112 * scale
    )
    context.setFillColor(
      NSColor(calibratedRed: 0.006, green: 0.016, blue: 0.035, alpha: 0.88)
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
    context.setStrokeColor(
      NSColor(calibratedRed: 0.98, green: 0.73, blue: 0.29, alpha: 0.78)
        .cgColor
    )
    context.setLineWidth(1.2 * scale)
    context.stroke(panel.insetBy(dx: 0.6 * scale, dy: 0.6 * scale))
    let metrics = summary.decisionMetrics
    drawText(
      "c16/c18/c20 SOURCE CONVERGENCE",
      font: valueFont,
      color: NSColor(calibratedRed: 1, green: 0.91, blue: 0.70, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 28 * scale),
      context: context
    )
    drawText(
      String(
        format: "geometry C %.3f  •  source C %.3f",
        metrics.selectedGeometryDensityCurvature,
        metrics.normalizedPopulationWeightedSourceCurvature
      ),
      font: labelFont,
      color: NSColor(calibratedWhite: 0.82, alpha: 1).cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 54 * scale),
      context: context
    )
    drawText(
      "MIXED SOURCE  •  0.5 < C < 1.0",
      font: labelFont,
      color: NSColor(calibratedRed: 1, green: 0.74, blue: 0.31, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 78 * scale),
      context: context
    )
    drawText(
      "gates pass  •  power convergence open",
      font: labelFont,
      color: NSColor(calibratedWhite: 0.56, alpha: 1).cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 100 * scale),
      context: context
    )
  }

  private static func drawGeometrySubcellDecision(
    _ summary: GeometrySubcellSummary,
    scale: CGFloat,
    labelFont: CTFont,
    valueFont: CTFont,
    context: CGContext
  ) {
    let panel = CGRect(
      x: 520 * scale,
      y: 28 * scale,
      width: 278 * scale,
      height: 112 * scale
    )
    context.setFillColor(
      NSColor(calibratedRed: 0.006, green: 0.016, blue: 0.035, alpha: 0.84)
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
    context.setStrokeColor(
      NSColor(calibratedRed: 0.31, green: 0.92, blue: 0.78, alpha: 0.65)
        .cgColor
    )
    context.setLineWidth(1.1 * scale)
    context.stroke(panel.insetBy(dx: 0.6 * scale, dy: 0.6 * scale))
    drawText(
      "192-POSE GEOMETRY ENSEMBLE",
      font: valueFont,
      color: NSColor(calibratedRed: 0.82, green: 1, blue: 0.94, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 28 * scale),
      context: context
    )
    let metrics = summary.decisionMetrics
    drawText(
      String(
        format: "mean curvature  D %.3f  p %.3f  a %.3f",
        metrics.normalizedMeanDensityMidpointCurvature,
        metrics.normalizedMeanDirectionMidpointCurvature,
        metrics.normalizedMeanArealProfileMidpointCurvature
      ),
      font: labelFont,
      color: NSColor(calibratedWhite: 0.78, alpha: 1).cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 54 * scale),
      context: context
    )
    drawText(
      "SUBCELL AVERAGING RESTORES SMOOTH GEOMETRY",
      font: labelFont,
      color: NSColor(calibratedRed: 0.33, green: 0.96, blue: 0.72, alpha: 1)
        .cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 78 * scale),
      context: context
    )
    drawText(
      "zero CFD steps  •  force convergence remains open",
      font: labelFont,
      color: NSColor(calibratedWhite: 0.53, alpha: 1).cgColor,
      at: CGPoint(x: panel.minX + 15 * scale, y: panel.maxY - 100 * scale),
      context: context
    )
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

struct FormationPresentationBilateralAudit: Codable, Sendable {
  let schemaVersion: Int
  let phaseCountPerFlyer: Int
  let flyerCount: Int
  let vertexPairsCompared: Int
  let maximumPositionReflectionResidual: Float
  let maximumNormalReflectionResidual: Float
  let maximumWithinFlyerPhaseDifferenceCycles: Float
  let flyerPairPhaseOffsetCycles: Float
  let passed: Bool
}

struct FormationDovePresentationAudit: Codable, Sendable {
  let schemaVersion: Int
  let datasetIdentifier: String
  let scientificTier: String
  let sourceDatasetDOI: String
  let sourceArticleDOI: String
  let sourceLicense: String
  let manifestSHA256: String
  let frameCount: Int
  let vertexCountPerFlyer: Int
  let triangleCountPerFlyer: Int
  let flyerCount: Int
  let componentNames: [String]
  let componentEvidenceClasses: [String]
  let measuredLoopStartFrame: Int
  let measuredLoopEndFrame: Int
  let closureDurationSeconds: Float
  let flyerPairPhaseOffsetCycles: Float
  let endpointMaximumPositionResidual: Float
  let flowDisplayMode: String
  let archivedFlowSliceCount: Int
  let capturePhaseCount: Int
  let capturePhasesWithVisibleFlow: Int
  let minimumFlowOpacity: Float
  let bodyAndWingScale: [Float]
  let tailScale: [Float]
  let completeBirdSurfaceReady: Bool
  let quantitativeForceAcceptanceReady: Bool
  let presentationOnly: Bool
  let passed: Bool
}

final class FormationObservatoryRenderer {
  private static let doveBodyAndWingScale = SIMD3<Float>(16, 16, 7)
  private static let doveTailScale = SIMD3<Float>(14, 6, 6)
  private let backend: VisualizationBackend
  private let doveDataset: MeasuredBirdSurfaceSequence?
  private let doveLoop: MeasuredDovePresentationLoop?
  private let doveReferenceBodyCenter: SIMD3<Float>
  private let doveWingtipIndices: [Int]
  private let surfacePipeline: MTLRenderPipelineState
  private let trailPipeline: MTLRenderPipelineState
  private let wirePipeline: MTLRenderPipelineState
  private let backgroundPipeline: MTLRenderPipelineState
  private let depthWriteState: MTLDepthStencilState
  private let depthReadState: MTLDepthStencilState

  init(
    device: MTLDevice,
    doveDataset: MeasuredBirdSurfaceSequence? = nil
  ) throws {
    backend = try VisualizationBackend(device: device)
    self.doveDataset = doveDataset
    if let doveDataset {
      doveLoop = MeasuredDovePresentationLoop(dataset: doveDataset)
      doveReferenceBodyCenter = Self.bodyCenter(
        dataset: doveDataset,
        frame: MeasuredDovePresentationLoop.startFrame
      )
      doveWingtipIndices = Self.findDoveWingtipIndices(dataset: doveDataset)
    } else {
      doveLoop = nil
      doveReferenceBodyCenter = .zero
      doveWingtipIndices = []
    }
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
    let leader = birdVertices(
      root: leaderRoot,
      phase: phase,
      color: SIMD3<Float>(0.08, 0.68, 1)
    )
    let follower = birdVertices(
      root: followerRoot,
      phase: phase + phaseOffset,
      color: SIMD3<Float>(1, 0.34, 0.12)
    )
    let surfaces = leader + follower
    let orbit = 2 * Float.pi * phase
    var camera = CameraState()
    camera.target = SIMD3<Float>(0, 0, -0.15)
    camera.distance = 11.9 + 0.12 * sin(orbit)
    camera.yaw = -1.02 + 0.035 * sin(orbit)
    camera.pitch = 0.36 + 0.018 * cos(orbit)
    let trails: [[ColoredVertex]]
    if doveLoop != nil {
      trails = doveWakeTrails(
        root: leaderRoot,
        phase: phase,
        color: SIMD3<Float>(0.08, 0.68, 1),
        camera: camera
      ) + doveWakeTrails(
        root: followerRoot,
        phase: phase + phaseOffset,
        color: SIMD3<Float>(1, 0.34, 0.12),
        camera: camera
      )
    } else {
      trails = wakeTrails(
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
    }
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

  private func birdVertices(
    root: SIMD3<Float>,
    phase: Float,
    color: SIMD3<Float>
  ) -> [ColoredVertex] {
    if let doveDataset, let doveLoop {
      return doveVertices(
        dataset: doveDataset,
        loop: doveLoop,
        root: root,
        phase: phase,
        tint: color
      )
    }
    let canonicalWing = wingVertices(
      root: root,
      phase: phase,
      color: color
    )
    let shellColor = SIMD3<Float>(
      0.24 + 0.64 * color.x,
      0.26 + 0.62 * color.y,
      0.30 + 0.58 * color.z
    )
    let mirroredWing = mirrored(
      canonicalWing,
      root: root,
      color: SIMD4<Float>(shellColor, 0.96)
    )
    let canonicalFeathers = wingFeatherVertices(
      root: root,
      phase: phase,
      color: SIMD4<Float>(0.82 * shellColor, 0.98)
    )
    let mirroredFeathers = mirrored(
      canonicalFeathers,
      root: root,
      color: SIMD4<Float>(0.82 * shellColor, 0.98)
    )
    var result = canonicalWing + mirroredWing
      + canonicalFeathers + mirroredFeathers
    appendEllipsoid(
      center: root + SIMD3<Float>(0, 0.02, 0.02),
      radii: SIMD3<Float>(0.43, 0.92, 0.39),
      color: SIMD4<Float>(shellColor, 0.99),
      latitudeCount: 14,
      longitudeCount: 24,
      to: &result
    )
    appendEllipsoid(
      center: root + SIMD3<Float>(0, 0.39, 0.08),
      radii: SIMD3<Float>(0.35, 0.46, 0.33),
      color: SIMD4<Float>(min(shellColor + 0.045, 1), 0.99),
      latitudeCount: 11,
      longitudeCount: 20,
      to: &result
    )
    for side in [Float(-1), Float(1)] {
      appendEllipsoid(
        center: root + SIMD3<Float>(0.27 * side, 0.05, 0.07),
        radii: SIMD3<Float>(0.22, 0.31, 0.18),
        color: SIMD4<Float>(0.93 * shellColor, 0.99),
        latitudeCount: 8,
        longitudeCount: 14,
        to: &result
      )
    }
    appendEllipsoid(
      center: root + SIMD3<Float>(0, 0.69, 0.14),
      radii: SIMD3<Float>(0.28, 0.34, 0.28),
      color: SIMD4<Float>(min(shellColor + 0.08, 1), 0.99),
      latitudeCount: 10,
      longitudeCount: 18,
      to: &result
    )
    appendEllipsoid(
      center: root + SIMD3<Float>(-0.21, 0.78, 0.19),
      radii: SIMD3<Float>(0.035, 0.035, 0.041),
      color: SIMD4<Float>(0.012, 0.018, 0.026, 1),
      latitudeCount: 6,
      longitudeCount: 10,
      to: &result
    )
    appendEllipsoid(
      center: root + SIMD3<Float>(0.21, 0.78, 0.19),
      radii: SIMD3<Float>(0.035, 0.035, 0.041),
      color: SIMD4<Float>(0.012, 0.018, 0.026, 1),
      latitudeCount: 6,
      longitudeCount: 10,
      to: &result
    )
    appendCone(
      baseCenter: root + SIMD3<Float>(0, 0.91, 0.12),
      tip: root + SIMD3<Float>(0, 1.25, 0.09),
      radius: 0.085,
      color: SIMD4<Float>(0.98, 0.69, 0.20, 1),
      segments: 16,
      to: &result
    )
    appendTailFan(
      root: root,
      color: SIMD4<Float>(0.86 * shellColor, 0.98),
      to: &result
    )
    return result
  }

  private func doveVertices(
    dataset: MeasuredBirdSurfaceSequence,
    loop: MeasuredDovePresentationLoop,
    root: SIMD3<Float>,
    phase: Float,
    tint: SIMD3<Float>
  ) -> [ColoredVertex] {
    let states = (0..<dataset.vertexCount).map {
      loop.point(phase: phase, vertexIndex: $0)
    }
    var result: [ColoredVertex] = []
    result.reserveCapacity(dataset.triangleCount * 3)
    for triangleIndex in 0..<dataset.triangleCount {
      let triangle = dataset.triangle(triangleIndex)
      let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
      let part = dataset.trianglePartIdentifiers[triangleIndex]
      let points = indices.map {
        formationDovePoint(
          states[$0].position,
          root: root,
          partIdentifier: part
        )
      }
      let rawNormal = simd_cross(points[1] - points[0], points[2] - points[0])
      let normal =
        simd_length_squared(rawNormal) > 1e-12
        ? simd_normalize(rawNormal)
        : SIMD3<Float>(0, 0, 1)
      let speed = indices.reduce(Float.zero) {
        $0 + simd_length(states[$1].velocity)
      } / 3
      let surfaceColor = doveSurfaceColor(
        partIdentifier: part,
        tint: tint,
        normalizedSpeed: min(max(speed / 25.2305, 0), 1)
      )
      for point in points {
        result.append(
          ColoredVertex(
            position: SIMD4<Float>(point, 1),
            normal: SIMD4<Float>(normal, 0),
            color: surfaceColor
          )
        )
      }
    }
    return result
  }

  private func formationDovePoint(
    _ point: SIMD3<Float>,
    root: SIMD3<Float>,
    partIdentifier: UInt8? = nil
  ) -> SIMD3<Float> {
    let local = point - doveReferenceBodyCenter
    let scale = partIdentifier == 4
      ? Self.doveTailScale
      : Self.doveBodyAndWingScale
    return root + scale * local
  }

  private func doveSurfaceColor(
    partIdentifier: UInt8,
    tint: SIMD3<Float>,
    normalizedSpeed: Float
  ) -> SIMD4<Float> {
    let white = SIMD3<Float>(0.92, 0.96, 1)
    let base: SIMD3<Float>
    switch partIdentifier {
    case 1:
      base = 0.42 * tint + 0.58 * white
    case 2:
      base = tint
    case 3:
      base = 0.82 * tint + 0.18 * white
    default:
      base = 0.58 * tint + 0.24 * white
    }
    let brightness = 0.80 + 0.20 * sqrt(normalizedSpeed)
    return SIMD4<Float>(min(brightness * base, 1), 0.99)
  }

  private func wingFeatherVertices(
    root: SIMD3<Float>,
    phase: Float,
    color: SIMD4<Float>
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
    var result: [ColoredVertex] = []
    for index in 0..<9 {
      let fraction = 0.22 + 0.083 * Float(index)
      let beta = max(fraction * (1 - fraction), 0)
      let localChord = Float(MetalFlappingWingValidator.betaNormalization)
        * pow(beta, Float(MetalFlappingWingValidator.betaShape - 1))
      let radial = 3 * fraction
      let trailing = root + radial * span + (localChord - 0.25) * chord
      let featherDirection = simd_normalize(
        (0.45 + 0.22 * fraction) * chord
          + (0.13 + 0.30 * fraction) * span
      )
      let lateral = simd_normalize(simd_cross(normal, featherDirection))
      let halfWidth = 0.075 + 0.025 * (1 - fraction)
      let base = trailing - 0.18 * featherDirection
      let tip = trailing
        + (0.38 + 0.42 * fraction) * featherDirection
      let featherShade = 0.78 + 0.18 * fraction
      let featherColor = SIMD4<Float>(
        color.x * featherShade,
        color.y * featherShade,
        color.z * featherShade,
        color.w
      )
      appendQuad(
        base - halfWidth * lateral + 0.018 * normal,
        base + halfWidth * lateral + 0.018 * normal,
        tip + 0.22 * halfWidth * lateral + 0.018 * normal,
        tip - 0.22 * halfWidth * lateral + 0.018 * normal,
        normal: normal,
        color: featherColor,
        to: &result
      )
      appendQuad(
        base + halfWidth * lateral - 0.018 * normal,
        base - halfWidth * lateral - 0.018 * normal,
        tip - 0.22 * halfWidth * lateral - 0.018 * normal,
        tip + 0.22 * halfWidth * lateral - 0.018 * normal,
        normal: -normal,
        color: 0.88 * featherColor,
        to: &result
      )
    }
    return result
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

  private func appendEllipsoid(
    center: SIMD3<Float>,
    radii: SIMD3<Float>,
    color: SIMD4<Float>,
    latitudeCount: Int,
    longitudeCount: Int,
    to result: inout [ColoredVertex]
  ) {
    func sample(_ latitude: Int, _ longitude: Int) -> ColoredVertex {
      let v = Float(latitude) / Float(latitudeCount)
      let u = Float(longitude) / Float(longitudeCount)
      let phi = (v - 0.5) * Float.pi
      let theta = u * 2 * Float.pi
      let unit = SIMD3<Float>(
        cos(phi) * cos(theta),
        cos(phi) * sin(theta),
        sin(phi)
      )
      return ColoredVertex(
        position: SIMD4<Float>(center + unit * radii, 1),
        normal: SIMD4<Float>(simd_normalize(unit / radii), 0),
        color: color
      )
    }
    for latitude in 0..<latitudeCount {
      for longitude in 0..<longitudeCount {
        let a = sample(latitude, longitude)
        let b = sample(latitude, longitude + 1)
        let c = sample(latitude + 1, longitude + 1)
        let d = sample(latitude + 1, longitude)
        result.append(contentsOf: [a, b, c, a, c, d])
      }
    }
  }

  private func appendCone(
    baseCenter: SIMD3<Float>,
    tip: SIMD3<Float>,
    radius: Float,
    color: SIMD4<Float>,
    segments: Int,
    to result: inout [ColoredVertex]
  ) {
    for index in 0..<segments {
      let a = 2 * Float.pi * Float(index) / Float(segments)
      let b = 2 * Float.pi * Float(index + 1) / Float(segments)
      let pa = baseCenter + SIMD3<Float>(radius * cos(a), 0, radius * sin(a))
      let pb = baseCenter + SIMD3<Float>(radius * cos(b), 0, radius * sin(b))
      appendTriangle(pa, pb, tip, color: color, to: &result)
    }
  }

  private func appendTailFan(
    root: SIMD3<Float>,
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    for index in -3...3 {
      let fraction = Float(index) / 3
      let baseX = 0.11 * fraction
      let tipX = 0.62 * fraction
      let base = root + SIMD3<Float>(baseX, -0.53, -0.06)
      let tip = root + SIMD3<Float>(tipX, -1.55 + 0.10 * abs(fraction), -0.10)
      let width: Float = 0.13
      let direction = simd_normalize(tip - base)
      let lateral = simd_normalize(
        simd_cross(SIMD3<Float>(0, 0, 1), direction)
      ) * width
      appendQuad(
        base - lateral,
        base + lateral,
        tip + 0.42 * lateral,
        tip - 0.42 * lateral,
        normal: SIMD3<Float>(0, 0, 1),
        color: color,
        to: &result
      )
      appendQuad(
        base + lateral - SIMD3<Float>(0, 0, 0.035),
        base - lateral - SIMD3<Float>(0, 0, 0.035),
        tip - 0.42 * lateral - SIMD3<Float>(0, 0, 0.035),
        tip + 0.42 * lateral - SIMD3<Float>(0, 0, 0.035),
        normal: SIMD3<Float>(0, 0, -1),
        color: 0.86 * color,
        to: &result
      )
    }
  }

  private func appendTriangle(
    _ a: SIMD3<Float>,
    _ b: SIMD3<Float>,
    _ c: SIMD3<Float>,
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    let normal = simd_normalize(simd_cross(b - a, c - a))
    for point in [a, b, c] {
      result.append(
        ColoredVertex(
          position: SIMD4<Float>(point, 1),
          normal: SIMD4<Float>(normal, 0),
          color: color
        )
      )
    }
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

  private func doveWakeTrails(
    root: SIMD3<Float>,
    phase: Float,
    color: SIMD3<Float>,
    camera: CameraState
  ) -> [[ColoredVertex]] {
    guard let doveLoop else { return [] }
    return doveWingtipIndices.flatMap { vertexIndex in
      let sampleCount = 34
      var points: [SIMD3<Float>] = []
      for sample in stride(from: sampleCount - 1, through: 0, by: -1) {
        let samplePhase = doveLoop.phase(
          offsetBy: -Float(sample) * 0.0017,
          from: phase
        )
        let position = doveLoop.point(
          phase: samplePhase,
          vertexIndex: vertexIndex
        ).position
        points.append(formationDovePoint(position, root: root))
      }
      return [
        trailVertices(
          points: points,
          color: color,
          camera: camera,
          width: 0.026,
          alpha: 0.16
        ),
        trailVertices(
          points: points,
          color: min(color + SIMD3<Float>(0.30, 0.30, 0.30), 1),
          camera: camera,
          width: 0.008,
          alpha: 0.58
        ),
      ]
    }
  }

  private func wakeTrails(
    root: SIMD3<Float>,
    phase: Float,
    color: SIMD3<Float>,
    camera: CameraState
  ) -> [[ColoredVertex]] {
    (0..<4).flatMap { ribbon in
      let radial = 0.72 + 0.59 * Float(ribbon)
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
      let mirroredPoints = points.map {
        root + Self.bilateralReflection($0 - root)
      }
      return [points, mirroredPoints].flatMap { sidePoints in
        [
          trailVertices(
            points: sidePoints,
            color: color,
            camera: camera,
            width: 0.032,
            alpha: 0.16
          ),
          trailVertices(
            points: sidePoints,
            color: min(color + SIMD3<Float>(0.28, 0.28, 0.28), 1),
            camera: camera,
            width: 0.010,
            alpha: 0.54
          ),
        ]
      }
    }
  }

  static func bilateralReflection(
    _ relative: SIMD3<Float>
  ) -> SIMD3<Float> {
    SIMD3<Float>(-relative.x, relative.y, relative.z)
  }

  func dovePresentationAudit(
    flyerPairPhaseOffsetCycles: Float,
    archivedFlowSliceCount: Int,
    capturePhaseCount: Int,
    capturePhasesWithVisibleFlow: Int,
    minimumFlowOpacity: Float
  ) -> FormationDovePresentationAudit {
    guard let dataset = doveDataset, let loop = doveLoop else {
      return FormationDovePresentationAudit(
        schemaVersion: 1,
        datasetIdentifier: "missing",
        scientificTier: "missing",
        sourceDatasetDOI: "missing",
        sourceArticleDOI: "missing",
        sourceLicense: "missing",
        manifestSHA256: "missing",
        frameCount: 0,
        vertexCountPerFlyer: 0,
        triangleCountPerFlyer: 0,
        flyerCount: 0,
        componentNames: [],
        componentEvidenceClasses: [],
        measuredLoopStartFrame: 0,
        measuredLoopEndFrame: 0,
        closureDurationSeconds: 0,
        flyerPairPhaseOffsetCycles: flyerPairPhaseOffsetCycles,
        endpointMaximumPositionResidual: .infinity,
        flowDisplayMode: "nearest-archived-phase-hold",
        archivedFlowSliceCount: archivedFlowSliceCount,
        capturePhaseCount: capturePhaseCount,
        capturePhasesWithVisibleFlow: capturePhasesWithVisibleFlow,
        minimumFlowOpacity: minimumFlowOpacity,
        bodyAndWingScale: [],
        tailScale: [],
        completeBirdSurfaceReady: false,
        quantitativeForceAcceptanceReady: false,
        presentationOnly: true,
        passed: false
      )
    }
    var endpointResidual: Float = 0
    for vertexIndex in 0..<dataset.vertexCount {
      endpointResidual = max(
        endpointResidual,
        simd_distance(
          loop.point(phase: 0, vertexIndex: vertexIndex).position,
          loop.point(phase: 1, vertexIndex: vertexIndex).position
        )
      )
    }
    let names = dataset.components.map(\.name)
    let evidence = dataset.components.map(\.evidenceClass)
    let passed = dataset.datasetIdentifier
      == "deetjen-ob-2018-12-11-f03-complete-surface-v1"
      && dataset.scientificTier == "derived-measured-complete-surface"
      && dataset.sourceDatasetDOI == "10.5061/dryad.wwpzgmsqs"
      && dataset.sourceArticleDOI == "10.7554/eLife.89968"
      && dataset.sourceLicense == "CC0-1.0"
      && dataset.frameCount == 144
      && dataset.vertexCount == 2_157
      && dataset.triangleCount == 3_968
      && names == ["body", "leftWing", "rightWing", "tail"]
      && evidence == [
        "measured-processed-surface",
        "measured-outline-derived-gap-filled-surface",
        "bilateral-reflection-assumption",
        "measured-processed-surface-derived-fixed-parameterization",
      ]
      && dataset.completeBirdSurfaceReady
      && !dataset.quantitativeForceAcceptanceReady
      && endpointResidual <= 1e-7
      && abs(flyerPairPhaseOffsetCycles - 0.25) <= 1e-7
      && archivedFlowSliceCount == 21
      && capturePhaseCount == 48
      && capturePhasesWithVisibleFlow == capturePhaseCount
      && minimumFlowOpacity == 1
      && Self.doveTailScale.y < 0.5 * Self.doveBodyAndWingScale.y
    return FormationDovePresentationAudit(
      schemaVersion: 1,
      datasetIdentifier: dataset.datasetIdentifier,
      scientificTier: dataset.scientificTier,
      sourceDatasetDOI: dataset.sourceDatasetDOI,
      sourceArticleDOI: dataset.sourceArticleDOI,
      sourceLicense: dataset.sourceLicense,
      manifestSHA256: dataset.manifestSHA256,
      frameCount: dataset.frameCount,
      vertexCountPerFlyer: dataset.vertexCount,
      triangleCountPerFlyer: dataset.triangleCount,
      flyerCount: 2,
      componentNames: names,
      componentEvidenceClasses: evidence,
      measuredLoopStartFrame: MeasuredDovePresentationLoop.startFrame,
      measuredLoopEndFrame: MeasuredDovePresentationLoop.endFrame,
      closureDurationSeconds:
        MeasuredDovePresentationLoop.closureDurationSeconds,
      flyerPairPhaseOffsetCycles: flyerPairPhaseOffsetCycles,
      endpointMaximumPositionResidual: endpointResidual,
      flowDisplayMode: "nearest-archived-phase-hold",
      archivedFlowSliceCount: archivedFlowSliceCount,
      capturePhaseCount: capturePhaseCount,
      capturePhasesWithVisibleFlow: capturePhasesWithVisibleFlow,
      minimumFlowOpacity: minimumFlowOpacity,
      bodyAndWingScale: [
        Self.doveBodyAndWingScale.x,
        Self.doveBodyAndWingScale.y,
        Self.doveBodyAndWingScale.z,
      ],
      tailScale: [
        Self.doveTailScale.x,
        Self.doveTailScale.y,
        Self.doveTailScale.z,
      ],
      completeBirdSurfaceReady: dataset.completeBirdSurfaceReady,
      quantitativeForceAcceptanceReady:
        dataset.quantitativeForceAcceptanceReady,
      presentationOnly: true,
      passed: passed
    )
  }

  private static func bodyCenter(
    dataset: MeasuredBirdSurfaceSequence,
    frame: Int
  ) -> SIMD3<Float> {
    guard
      let body = dataset.components.first(where: {
        $0.partIdentifier == 1
      })
    else { return .zero }
    var center = SIMD3<Float>.zero
    for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      center += dataset.vertex(frame: frame, index: index)
    }
    return center / Float(body.vertexCount)
  }

  private static func findDoveWingtipIndices(
    dataset: MeasuredBirdSurfaceSequence
  ) -> [Int] {
    let frame = MeasuredDovePresentationLoop.startFrame
    let center = bodyCenter(dataset: dataset, frame: frame)
    return [UInt8(2), UInt8(3)].compactMap { identifier in
      guard
        let wing = dataset.components.first(where: {
          $0.partIdentifier == identifier
        })
      else { return nil }
      return (wing.vertexOffset..<(wing.vertexOffset + wing.vertexCount)).max {
        simd_distance_squared(
          dataset.vertex(frame: frame, index: $0),
          center
        )
          < simd_distance_squared(
            dataset.vertex(frame: frame, index: $1),
            center
          )
      }
    }
  }

  private func mirrored(
    _ vertices: [ColoredVertex],
    root: SIMD3<Float>,
    color: SIMD4<Float>
  ) -> [ColoredVertex] {
    vertices.map { vertex in
      let position = SIMD3<Float>(
        vertex.position.x,
        vertex.position.y,
        vertex.position.z
      )
      let normal = SIMD3<Float>(
        vertex.normal.x,
        vertex.normal.y,
        vertex.normal.z
      )
      let relative = position - root
      let reflectedNormal = Self.bilateralReflection(normal)
      return ColoredVertex(
        position: SIMD4<Float>(
          root + Self.bilateralReflection(relative),
          1
        ),
        normal: SIMD4<Float>(reflectedNormal, 0),
        color: color
      )
    }
  }

  func bilateralPresentationAudit(
    phases: [Float],
    flyerPairPhaseOffsetCycles: Float
  ) -> FormationPresentationBilateralAudit {
    let root = SIMD3<Float>.zero
    var maximumPositionResidual: Float = 0
    var maximumNormalResidual: Float = 0
    var pairs = 0
    for flyerOffset in [Float.zero, flyerPairPhaseOffsetCycles] {
      for phase in phases {
        let canonical = wingVertices(
          root: root,
          phase: phase + flyerOffset,
          color: SIMD3<Float>(0.08, 0.68, 1)
        )
        let partner = mirrored(
          canonical,
          root: root,
          color: SIMD4<Float>(0.62, 0.82, 0.94, 1)
        )
        for (right, left) in zip(canonical, partner) {
          let rightPosition = SIMD3<Float>(
            right.position.x,
            right.position.y,
            right.position.z
          )
          let leftPosition = SIMD3<Float>(
            left.position.x,
            left.position.y,
            left.position.z
          )
          let positionResidual = max(
            abs(leftPosition.x + rightPosition.x),
            max(
              abs(leftPosition.y - rightPosition.y),
              abs(leftPosition.z - rightPosition.z)
            )
          )
          maximumPositionResidual = max(
            maximumPositionResidual,
            positionResidual
          )
          let rightNormal = SIMD3<Float>(
            right.normal.x,
            right.normal.y,
            right.normal.z
          )
          let leftNormal = SIMD3<Float>(
            left.normal.x,
            left.normal.y,
            left.normal.z
          )
          let normalResidual = max(
            abs(leftNormal.x + rightNormal.x),
            max(
              abs(leftNormal.y - rightNormal.y),
              abs(leftNormal.z - rightNormal.z)
            )
          )
          maximumNormalResidual = max(
            maximumNormalResidual,
            normalResidual
          )
          pairs += 1
        }
      }
    }
    let passed = !phases.isEmpty
      && pairs > 0
      && maximumPositionResidual <= 1e-6
      && maximumNormalResidual <= 1e-6
      && flyerPairPhaseOffsetCycles.isFinite
    return FormationPresentationBilateralAudit(
      schemaVersion: 1,
      phaseCountPerFlyer: phases.count,
      flyerCount: 2,
      vertexPairsCompared: pairs,
      maximumPositionReflectionResidual: maximumPositionResidual,
      maximumNormalReflectionResidual: maximumNormalResidual,
      maximumWithinFlyerPhaseDifferenceCycles: 0,
      flyerPairPhaseOffsetCycles: flyerPairPhaseOffsetCycles,
      passed: passed
    )
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

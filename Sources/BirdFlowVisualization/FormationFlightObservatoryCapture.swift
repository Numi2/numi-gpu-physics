import AppKit
import BirdFlowCore
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

  private struct FocusedSourceDisplaySample {
    let leaderPhase: Double
    let reflectedMomentumExchange: Double
    let normalizedIntensity: Float
    let nearFraction: Double
    let farFraction: Double
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
    let focusedSourceTraceURL: URL?
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
      if commandLine.contains("--capture-formation-focused-source-trace") {
        focusedSourceTraceURL = URL(
          fileURLWithPath: try value(
            after: "--capture-formation-focused-source-trace"
          )
        )
      } else {
        focusedSourceTraceURL = nil
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
    let focusedSourceTrace = try arguments.focusedSourceTraceURL.map {
      try JSONDecoder().decode(
        FormationFlightFocusedBoundarySourceTraceReport.self,
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
    if let trace = focusedSourceTrace {
      guard trace.gates.passed,
        trace.configuration.chordCells == 18,
        trace.configuration.cycles == 5,
        trace.configuration.followerOffsetChords == SIMD3<Double>(0, 0, -3),
        abs(trace.configuration.followerPhaseOffsetCycles - 0.25) < 1e-12,
        trace.subcellOffsetCells == SIMD3<Double>(0.25, 0.25, 0.75),
        trace.flyer == .leader,
        trace.directionIndex == 5,
        trace.direction == SIMD3<Int32>(0, 0, 1),
        trace.cycleSteps == 4_820,
        trace.samples.count == trace.cycleSteps,
        trace.samples.allSatisfy({
          $0.source.directionIndex == 5
            && $0.source.direction == SIMD3<Int32>(0, 0, 1)
            && $0.branchCountClosurePassed
        })
      else {
        throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
          "formation wake bridge requires the passed complete c18 leader-q5 source trace"
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
      interpolatedPhaseFlowSlice(phaseFlowSlices, leaderPhase: $0) != nil
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
      minimumFlowOpacity: minimumFlowOpacity,
      focusedSourceTraceSampleCount:
        focusedSourceTrace?.samples.count ?? 0,
      focusedSourceTraceDirectionIndex:
        focusedSourceTrace?.directionIndex ?? -1,
      wakeBridgePhaseCount: uniqueCapturePhases.filter { capturePhase in
        interpolatedPhaseFlowSlice(
          phaseFlowSlices,
          leaderPhase: capturePhase
        ) != nil
          && (focusedSourceTrace.map { trace in
            focusedSourceDisplaySample(
              trace,
              leaderPhase: capturePhase
            ) != nil
          } ?? false)
      }.count
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
      let phaseFlow = interpolatedPhaseFlowSlice(
        phaseFlowSlices,
        leaderPhase: Double(phase)
      )
      let displayedFlowSlice = phaseFlow?.slice ?? flowSlice
      let focusedSourceSample = focusedSourceTrace.flatMap {
        focusedSourceDisplaySample(
          $0,
          leaderPhase: Double(phase)
        )
      }
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
        focusedSourceIntensity:
          focusedSourceSample?.normalizedIntensity ?? 0,
        width: arguments.width,
        height: arguments.height
      )
      let png = try ReadmeShowcaseCapture.pngData(
        texture: texture,
        width: arguments.width,
        height: arguments.height
      ) { _ in }
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

  private static func interpolatedPhaseFlowSlice(
    _ slices: [PhaseFlowSlice],
    leaderPhase: Double
  ) -> PhaseFlowSlice? {
    guard let slice = interpolatedFlowSlice(
      slices.map(\.slice),
      leaderPhase: leaderPhase
    ) else { return nil }
    let phase = leaderPhase - floor(leaderPhase)
    return PhaseFlowSlice(
      entry: FlowSliceIndex.Entry(
        file: "presentation-interpolation",
        leaderPhase: phase,
        followerPhase: (phase + 0.25).truncatingRemainder(dividingBy: 1)
      ),
      slice: slice
    )
  }

  static func interpolatedFlowSlice(
    _ slices: [FormationFlightFlowSlice],
    leaderPhase: Double
  ) -> FormationFlightFlowSlice? {
    guard !slices.isEmpty else { return nil }
    let phase = leaderPhase - floor(leaderPhase)
    let ordered = slices.sorted { lhs, rhs in
      lhs.phase < rhs.phase
    }
    if phase <= 1e-12,
      let seam = ordered.first(where: {
        abs($0.phase) <= 1e-12
      })
    {
      return seam
    }
    let upperIndex = ordered.firstIndex {
      $0.phase > phase
    } ?? 0
    let lowerIndex = upperIndex == 0 ? ordered.count - 1 : upperIndex - 1
    let lower = ordered[lowerIndex]
    let upper = ordered[upperIndex]
    let lowerPhase = lower.phase
    let upperPhase = upper.phase
      + (upperIndex < lowerIndex ? 1 : 0)
    let span = max(upperPhase - lowerPhase, 1e-12)
    let fraction = Float(
      min(max((phase - lowerPhase) / span, 0), 1)
    )
    if fraction <= 1e-7 { return lower }
    if fraction >= 1 - 1e-7 { return upper }
    let a = lower
    let b = upper
    guard a.schemaVersion == b.schemaVersion,
      a.plane == b.plane,
      a.planeIndex == b.planeIndex,
      a.width == b.width,
      a.height == b.height,
      a.chordCells == b.chordCells,
      a.velocityUnits == b.velocityUnits,
      a.vorticityUnits == b.vorticityUnits,
      a.vorticityMagnitudePerSecond.count
        == b.vorticityMagnitudePerSecond.count,
      a.verticalVelocityMetersPerSecond.count
        == b.verticalVelocityMetersPerSecond.count,
      a.ownerMask.count == b.ownerMask.count
    else { return nil }
    let vorticity = zip(
      a.vorticityMagnitudePerSecond,
      b.vorticityMagnitudePerSecond
    ).map { (1 - fraction) * $0 + fraction * $1 }
    let vertical = zip(
      a.verticalVelocityMetersPerSecond,
      b.verticalVelocityMetersPerSecond
    ).map { (1 - fraction) * $0 + fraction * $1 }
    let ownerMask = fraction < 0.5 ? a.ownerMask : b.ownerMask
    return FormationFlightFlowSlice(
      schemaVersion: a.schemaVersion,
      plane: a.plane,
      planeIndex: a.planeIndex,
      width: a.width,
      height: a.height,
      chordCells: a.chordCells,
      phase: phase,
      velocityUnits: a.velocityUnits,
      vorticityUnits: a.vorticityUnits,
      maximumVorticityMagnitudePerSecond: vorticity.max() ?? 0,
      maximumAbsoluteVerticalVelocityMetersPerSecond:
        vertical.map(abs).max() ?? 0,
      vorticityMagnitudePerSecond: vorticity,
      verticalVelocityMetersPerSecond: vertical,
      ownerMask: ownerMask
    )
  }

  private static func phaseFlowOpacity(
    _ slices: [PhaseFlowSlice],
    leaderPhase: Double
  ) -> Float {
    interpolatedPhaseFlowSlice(slices, leaderPhase: leaderPhase) == nil
      ? (slices.isEmpty ? 1 : 0)
      : 1
  }

  static func focusedSourceIntensity(
    _ report: FormationFlightFocusedBoundarySourceTraceReport,
    leaderPhase: Double
  ) -> Float {
    guard !report.samples.isEmpty else { return 0 }
    let values = report.samples.map {
      $0.source.rawReflectedPopulationSum
        + $0.source.reflectedIncomingPopulationSum
    }
    let minimum = values.min() ?? 0
    let maximum = values.max() ?? minimum
    let nearest = report.samples.min {
      circularDistance($0.leaderPhase, leaderPhase)
        < circularDistance($1.leaderPhase, leaderPhase)
    }!
    let value = nearest.source.rawReflectedPopulationSum
      + nearest.source.reflectedIncomingPopulationSum
    return Float((value - minimum) / max(maximum - minimum, 1e-12))
  }

  private static func focusedSourceDisplaySample(
    _ report: FormationFlightFocusedBoundarySourceTraceReport,
    leaderPhase: Double
  ) -> FocusedSourceDisplaySample? {
    guard let nearest = report.samples.min(by: {
      circularDistance($0.leaderPhase, leaderPhase)
        < circularDistance($1.leaderPhase, leaderPhase)
    }) else { return nil }
    let source = nearest.source
    let links = max(source.linkCount, 1)
    return FocusedSourceDisplaySample(
      leaderPhase: nearest.leaderPhase,
      reflectedMomentumExchange:
        source.rawReflectedPopulationSum
          + source.reflectedIncomingPopulationSum,
      normalizedIntensity: focusedSourceIntensity(
        report,
        leaderPhase: leaderPhase
      ),
      nearFraction: Double(source.nearInterpolationLinkCount)
        / Double(links),
      farFraction: Double(source.farInterpolationLinkCount)
        / Double(links)
    )
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
    formationSourceSummary: FormationSourceSummary?,
    focusedSourceSample: FocusedSourceDisplaySample?
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
          format: "held c20 CFD  •  |ω| ridge  •  L %.3f  F %.3f",
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
        focusedSourceSample.map {
          String(
            format: "age: cyan→violet  •  q5 luminance %.1f",
            $0.reflectedMomentumExchange
          )
        } ?? "blue: down w  •  orange: up w  •  opacity: |ω|",
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
    if let focusedSourceSample {
      drawText(
        String(
          format: "WAKE CROSSING  •  q5 φ %.3f  •  N/F %.0f/%.0f%%",
          focusedSourceSample.leaderPhase,
          100 * focusedSourceSample.nearFraction,
          100 * focusedSourceSample.farFraction
        ),
        font: labelFont,
        color: NSColor(
          calibratedRed: 0.72,
          green: 0.60,
          blue: 1,
          alpha: 1
        ).cgColor,
        at: CGPoint(x: CGFloat(width) - 314 * scale, y: 226 * scale),
        context: context
      )
    }
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
  let flowSpatialFilterMode: String
  let flowOpacityMode: String
  let minimumDisplayedSignalOpacity: Float
  let wakeBridgeMode: String
  let wakeIntersectionMarkerMode: String
  let latticeBoltzmannDisplayMode: String
  let latticeDirectionCount: Int
  let latticeRestPopulationCount: Int
  let latticeAxisDirectionCount: Int
  let latticeFaceDiagonalDirectionCount: Int
  let collisionPulseMode: String
  let streamingPulseMode: String
  let movingBoundaryExchangeMode: String
  let focusedMomentumExchangeDirectionIndex: Int
  let focusedMomentumExchangeDirection: [Int]
  let trailDrawCallMode: String
  let postProcessingMode: String
  let focusedSourceTraceSampleCount: Int
  let focusedSourceTraceDirectionIndex: Int
  let wakeBridgePhaseCount: Int
  let overlayMode: String
  let cameraCompositionMode: String
  let cameraYawAmplitudeRadians: Float
  let cameraPitchAmplitudeRadians: Float
  let cameraDistanceAmplitudeChords: Float
  let cameraEndpointParameterResidual: Float
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
  private let bloomPipeline: MTLRenderPipelineState
  private let compositePipeline: MTLRenderPipelineState
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
      colorFormat: .rgba16Float
    )
    trailPipeline = try backend.render(
      vertex: "coloredSurfaceVertex",
      fragment: "unlitFragment",
      colorFormat: .rgba16Float,
      blending: true
    )
    wirePipeline = try backend.render(
      vertex: "coloredSurfaceVertex",
      fragment: "showcaseWireFragment",
      colorFormat: .rgba16Float,
      blending: true
    )
    backgroundPipeline = try backend.render(
      vertex: "showcaseBackgroundVertex",
      fragment: "showcaseBackgroundFragment",
      colorFormat: .rgba16Float
    )
    bloomPipeline = try backend.render(
      vertex: "showcasePostVertex",
      fragment: "showcaseBloomFragment",
      colorFormat: .rgba16Float,
      depthFormat: .invalid
    )
    compositePipeline = try backend.render(
      vertex: "showcasePostVertex",
      fragment: "showcaseCompositeFragment",
      colorFormat: .bgra8Unorm_srgb,
      depthFormat: .invalid
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
    focusedSourceIntensity: Float,
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
    let cameraParameters = Self.figureEightCameraParameters(phase: phase)
    var camera = CameraState()
    camera.target = SIMD3<Float>(0, 0, -0.15)
    camera.yaw = cameraParameters.x
    camera.pitch = cameraParameters.y
    camera.distance = cameraParameters.z
    let wingtipTrails: [[ColoredVertex]]
    if doveLoop != nil {
      wingtipTrails = doveWakeTrails(
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
      wingtipTrails = wakeTrails(
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
    let wakeBridge = flowSlice.map {
      wakeBridgeTrails(
        slice: $0,
        leaderRoot: leaderRoot,
        followerRoot: followerRoot,
        phase: phase,
        focusedSourceIntensity: focusedSourceIntensity,
        camera: camera
      )
    } ?? []
    let trails = wakeBridge + wingtipTrails
    let batchedTrails = Self.batchedTriangleStripVertices(trails)
    let slice = flowSlice.map {
      flowSliceVertices($0, opacity: flowOpacity)
    } ?? []
    let latticeCenter = flowSlice.flatMap {
      Self.latticeLensCenter(
        slice: $0,
        leaderRoot: leaderRoot,
        followerRoot: followerRoot
      )
    } ?? (simd_mix(
      leaderRoot,
      followerRoot,
      SIMD3<Float>(repeating: 0.58)
    ) + SIMD3<Float>(1.45, 0.24, 0))
    let latticeLens = latticeBoltzmannLensVertices(
      center: latticeCenter,
      phase: phase,
      focusedSourceIntensity: focusedSourceIntensity,
      camera: camera
    )
    let surfaceBuffer = try sharedBuffer(surfaces)
    let trailBuffer = batchedTrails.isEmpty
      ? nil
      : try sharedBuffer(batchedTrails)
    let sliceBuffer = slice.isEmpty ? nil : try sharedBuffer(slice)
    let latticeBuffer = try sharedBuffer(latticeLens)

    let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .bgra8Unorm_srgb,
      width: width,
      height: height,
      mipmapped: false
    )
    colorDescriptor.storageMode = .shared
    colorDescriptor.usage = [.renderTarget, .shaderRead]
    let sceneDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba16Float,
      width: width,
      height: height,
      mipmapped: false
    )
    sceneDescriptor.storageMode = .private
    sceneDescriptor.usage = [.renderTarget, .shaderRead]
    let bloomDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .rgba16Float,
      width: max(1, width / 2),
      height: max(1, height / 2),
      mipmapped: false
    )
    bloomDescriptor.storageMode = .private
    bloomDescriptor.usage = [.renderTarget, .shaderRead]
    let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(
      pixelFormat: .depth32Float,
      width: width,
      height: height,
      mipmapped: false
    )
    depthDescriptor.storageMode = .private
    depthDescriptor.usage = [.renderTarget]
    guard let color = backend.device.makeTexture(descriptor: colorDescriptor),
      let scene = backend.device.makeTexture(descriptor: sceneDescriptor),
      let bloom = backend.device.makeTexture(descriptor: bloomDescriptor),
      let depth = backend.device.makeTexture(descriptor: depthDescriptor),
      let commandBuffer = backend.queue.makeCommandBuffer()
    else { throw VisualizationError.allocation(width * height * 8) }
    let pass = MTLRenderPassDescriptor()
    pass.colorAttachments[0].texture = scene
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
    if let trailBuffer {
      encoder.setVertexBuffer(trailBuffer, offset: 0, index: 0)
      encoder.drawPrimitives(
        type: .triangleStrip,
        vertexStart: 0,
        vertexCount: batchedTrails.count
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
    encoder.setTriangleFillMode(.fill)
    encoder.setRenderPipelineState(trailPipeline)
    encoder.setVertexBuffer(latticeBuffer, offset: 0, index: 0)
    encoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: latticeLens.count
    )
    encoder.setDepthStencilState(depthReadState)
    encoder.setRenderPipelineState(wirePipeline)
    encoder.setTriangleFillMode(.lines)
    encoder.setVertexBuffer(surfaceBuffer, offset: 0, index: 0)
    encoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: surfaces.count
    )
    encoder.endEncoding()

    let bloomPass = MTLRenderPassDescriptor()
    bloomPass.colorAttachments[0].texture = bloom
    bloomPass.colorAttachments[0].loadAction = .dontCare
    bloomPass.colorAttachments[0].storeAction = .store
    let bloomEncoder = commandBuffer.makeRenderCommandEncoder(
      descriptor: bloomPass
    )!
    bloomEncoder.setRenderPipelineState(bloomPipeline)
    bloomEncoder.setFragmentTexture(scene, index: 0)
    bloomEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    bloomEncoder.endEncoding()

    let compositePass = MTLRenderPassDescriptor()
    compositePass.colorAttachments[0].texture = color
    compositePass.colorAttachments[0].loadAction = .dontCare
    compositePass.colorAttachments[0].storeAction = .store
    var finishing = SIMD4<Float>(0.22, 1.00, phase, 0)
    let compositeEncoder = commandBuffer.makeRenderCommandEncoder(
      descriptor: compositePass
    )!
    compositeEncoder.setRenderPipelineState(compositePipeline)
    compositeEncoder.setFragmentTexture(scene, index: 0)
    compositeEncoder.setFragmentTexture(bloom, index: 1)
    compositeEncoder.setFragmentBytes(
      &finishing,
      length: MemoryLayout<SIMD4<Float>>.stride,
      index: 0
    )
    compositeEncoder.drawPrimitives(
      type: .triangle,
      vertexStart: 0,
      vertexCount: 3
    )
    compositeEncoder.endEncoding()
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
    guard let presentationValues = Self.presentationSmoothedFlowValues(slice)
    else { return [] }
    let chord = Float(slice.chordCells)
    let maximumVorticity = max(
      presentationValues.vorticity.max() ?? 0,
      1e-8
    )
    let maximumVertical = max(
      presentationValues.verticalVelocity.map(abs).max() ?? 0,
      1e-8
    )
    var result: [ColoredVertex] = []
    result.reserveCapacity(slice.width * slice.height * 6)
    for z in 0..<(slice.height - 1) {
      for x in 0..<(slice.width - 1) {
        let index = x + slice.width * z
        let vorticity = presentationValues.vorticity[index]
        let normalizedVorticity = min(
          sqrt(max(vorticity, 0) / (0.35 * maximumVorticity)),
          1
        )
        let vertical = presentationValues.verticalVelocity[index]
        let normalizedVertical = min(abs(vertical) / maximumVertical, 1)
        guard normalizedVorticity > 0.015 || normalizedVertical > 0.035
        else { continue }
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
            * Self.flowPresentationOpacity(
              normalizedVorticity: normalizedVorticity,
              normalizedVerticalVelocity: normalizedVertical
            )
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

  static func flowPresentationOpacity(
    normalizedVorticity: Float,
    normalizedVerticalVelocity: Float
  ) -> Float {
    0.025
      + 0.18 * min(max(normalizedVorticity, 0), 1)
      + 0.10 * min(max(normalizedVerticalVelocity, 0), 1)
  }

  static func presentationSmoothedFlowValues(
    _ slice: FormationFlightFlowSlice
  ) -> (vorticity: [Float], verticalVelocity: [Float])? {
    let cellCount = slice.width * slice.height
    guard slice.width > 0,
      slice.height > 0,
      slice.vorticityMagnitudePerSecond.count == cellCount,
      slice.verticalVelocityMetersPerSecond.count == cellCount,
      slice.ownerMask.count == cellCount
    else { return nil }
    let radius = 4
    let sigma: Float = 2
    let kernel = (-radius...radius).map { offset in
      exp(-0.5 * Float(offset * offset) / (sigma * sigma))
    }
    func smooth(_ source: [Float]) -> [Float] {
      var horizontal = source
      for z in 0..<slice.height {
        for x in 0..<slice.width {
          let index = x + slice.width * z
          guard slice.ownerMask[index] == 0 else { continue }
          var sum: Float = 0
          var weightSum: Float = 0
          for offset in -radius...radius {
            let sampleX = x + offset
            guard sampleX >= 0, sampleX < slice.width else { continue }
            let sampleIndex = sampleX + slice.width * z
            guard slice.ownerMask[sampleIndex] == 0 else { continue }
            let weight = kernel[offset + radius]
            sum += weight * source[sampleIndex]
            weightSum += weight
          }
          horizontal[index] = sum / max(weightSum, 1e-8)
        }
      }
      var vertical = horizontal
      for z in 0..<slice.height {
        for x in 0..<slice.width {
          let index = x + slice.width * z
          guard slice.ownerMask[index] == 0 else { continue }
          var sum: Float = 0
          var weightSum: Float = 0
          for offset in -radius...radius {
            let sampleZ = z + offset
            guard sampleZ >= 0, sampleZ < slice.height else { continue }
            let sampleIndex = x + slice.width * sampleZ
            guard slice.ownerMask[sampleIndex] == 0 else { continue }
            let weight = kernel[offset + radius]
            sum += weight * horizontal[sampleIndex]
            weightSum += weight
          }
          vertical[index] = sum / max(weightSum, 1e-8)
        }
      }
      var filled = vertical
      for z in 0..<slice.height {
        for x in 0..<slice.width {
          let index = x + slice.width * z
          guard slice.ownerMask[index] != 0 else { continue }
          var sum: Float = 0
          var weightSum: Float = 0
          for offsetZ in -radius...radius {
            let sampleZ = z + offsetZ
            guard sampleZ >= 0, sampleZ < slice.height else { continue }
            for offsetX in -radius...radius {
              let sampleX = x + offsetX
              guard sampleX >= 0, sampleX < slice.width else { continue }
              let sampleIndex = sampleX + slice.width * sampleZ
              guard slice.ownerMask[sampleIndex] == 0 else { continue }
              let weight = kernel[offsetX + radius]
                * kernel[offsetZ + radius]
              sum += weight * vertical[sampleIndex]
              weightSum += weight
            }
          }
          filled[index] = sum / max(weightSum, 1e-8)
        }
      }
      return filled
    }
    return (
      smooth(slice.vorticityMagnitudePerSecond),
      smooth(slice.verticalVelocityMetersPerSecond)
    )
  }

  private func wakeBridgeTrails(
    slice: FormationFlightFlowSlice,
    leaderRoot: SIMD3<Float>,
    followerRoot: SIMD3<Float>,
    phase: Float,
    focusedSourceIntensity: Float,
    camera: CameraState
  ) -> [[ColoredVertex]] {
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
    let sampleCount = 56
    let laneTargets: [Float] = [-1.45, 0, 1.45]
    let sigma: Float = 0.82
    var lanePoints: [[SIMD3<Float>]] = []
    var laneStrengths: [[Float]] = []
    for (laneIndex, targetX) in laneTargets.enumerated() {
      var points: [SIMD3<Float>] = []
      var strengths: [Float] = []
      points.reserveCapacity(sampleCount)
      strengths.reserveCapacity(sampleCount)
      for sample in 0..<sampleCount {
        let age = Float(sample) / Float(sampleCount - 1)
        let startZ = leaderRoot.z - 0.16
        let endZ = followerRoot.z + 0.08
        let z = (1 - age) * startZ + age * endZ
        let zIndex = min(
          slice.height - 2,
          max(1, Int((z * chord + 0.5 * Float(slice.height)).rounded()))
        )
        var weightedX: Float = 0
        var weightedVertical: Float = 0
        var ridgeWeight: Float = 0
        var gaussianWeight: Float = 0
        var vorticityWeight: Float = 0
        for xIndex in 1..<(slice.width - 1) {
          let index = xIndex + slice.width * zIndex
          guard slice.ownerMask[index] == 0 else { continue }
          let x = (Float(xIndex) - 0.5 * Float(slice.width)) / chord
          let distance = x - targetX
          let gaussian = exp(
            -0.5 * distance * distance / (sigma * sigma)
          )
          let normalizedVorticity = min(
            sqrt(
              max(slice.vorticityMagnitudePerSecond[index], 0)
                / maximumVorticity
            ),
            1
          )
          let weight = gaussian * (0.025 + normalizedVorticity * normalizedVorticity)
          weightedX += weight * x
          weightedVertical += weight
            * slice.verticalVelocityMetersPerSecond[index]
          ridgeWeight += weight
          gaussianWeight += gaussian
          vorticityWeight += gaussian * normalizedVorticity
        }
        let x = ridgeWeight > 1e-8
          ? weightedX / ridgeWeight
          : targetX
        let vertical = ridgeWeight > 1e-8
          ? weightedVertical / ridgeWeight
          : 0
        let strength = min(
          max(vorticityWeight / max(gaussianWeight, 1e-8), 0),
          1
        )
        let laneHeight = 0.065 * Float(laneIndex - 1)
        points.append(
          SIMD3<Float>(
            x,
            0.08 + laneHeight + 0.22 * vertical / maximumVertical,
            z
          )
        )
        strengths.append(strength)
      }
      lanePoints.append(points)
      laneStrengths.append(strengths)
    }

    var ribbons: [[ColoredVertex]] = []
    for laneIndex in lanePoints.indices {
      ribbons.append(
        gradientWakeTrailVertices(
          points: lanePoints[laneIndex],
          strengths: laneStrengths[laneIndex],
          focusedSourceIntensity: focusedSourceIntensity,
          camera: camera,
          width: 0.082,
          alpha: 0.17
        )
      )
      ribbons.append(
        gradientWakeTrailVertices(
          points: lanePoints[laneIndex],
          strengths: laneStrengths[laneIndex],
          focusedSourceIntensity: focusedSourceIntensity,
          camera: camera,
          width: 0.021,
          alpha: 0.66
        )
      )
    }
    let center = lanePoints.map { $0.last! }.reduce(.zero, +)
      / Float(lanePoints.count)
    ribbons.append(
      wakeIntersectionRing(
        center: center,
        phase: phase,
        focusedSourceIntensity: focusedSourceIntensity,
        camera: camera
      )
    )
    return ribbons
  }

  private func gradientWakeTrailVertices(
    points: [SIMD3<Float>],
    strengths: [Float],
    focusedSourceIntensity: Float,
    camera: CameraState,
    width: Float,
    alpha: Float
  ) -> [ColoredVertex] {
    let young = SIMD3<Float>(0.04, 0.88, 1)
    let old = SIMD3<Float>(0.70, 0.34, 1)
    let sourceLuminance = 0.56
      + 0.44 * sqrt(min(max(focusedSourceIntensity, 0), 1))
    return points.indices.flatMap { index -> [ColoredVertex] in
      let previous = points[max(0, index - 1)]
      let next = points[min(points.count - 1, index + 1)]
      let tangent = simd_normalize(
        next - previous + SIMD3<Float>(1e-8, 0, 0)
      )
      let view = simd_normalize(camera.eye - points[index])
      let lateral = simd_normalize(
        simd_cross(view, tangent) + SIMD3<Float>(1e-8, 0, 0)
      )
      let age = Float(index) / Float(points.count - 1)
      let color = ((1 - age) * young + age * old) * sourceLuminance
      let vorticityOpacity = 0.48 + 0.52 * strengths[index]
      let value = ColoredVertex(
        position: SIMD4<Float>(points[index] - width * lateral, 1),
        normal: SIMD4<Float>(view, 0),
        color: SIMD4<Float>(min(color, 1), alpha * vorticityOpacity)
      )
      let opposite = ColoredVertex(
        position: SIMD4<Float>(points[index] + width * lateral, 1),
        normal: SIMD4<Float>(view, 0),
        color: value.color
      )
      return [value, opposite]
    }
  }

  private func wakeIntersectionRing(
    center: SIMD3<Float>,
    phase: Float,
    focusedSourceIntensity: Float,
    camera: CameraState
  ) -> [ColoredVertex] {
    let view = simd_normalize(camera.eye - center)
    var right = simd_cross(view, SIMD3<Float>(0, 1, 0))
    if simd_length_squared(right) < 1e-8 {
      right = SIMD3<Float>(1, 0, 0)
    } else {
      right = simd_normalize(right)
    }
    let up = simd_normalize(simd_cross(right, view))
    let pulse = 0.5 + 0.5 * sin(2 * Float.pi * phase)
    let radius = 0.17 + 0.025 * pulse
    let points = (0...32).map { index in
      let angle = 2 * Float.pi * Float(index) / 32
      return center + radius * (cos(angle) * right + sin(angle) * up)
    }
    let intensity = 0.68
      + 0.32 * sqrt(min(max(focusedSourceIntensity, 0), 1))
    return trailVertices(
      points: points,
      color: intensity * SIMD3<Float>(0.76, 0.52, 1),
      camera: camera,
      width: 0.014,
      alpha: 0.88
    )
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

  static func latticeBoltzmannDirectionSummary() -> (
    total: Int,
    rest: Int,
    axis: Int,
    faceDiagonal: Int,
    focusedDirection: SIMD3<Int32>
  ) {
    var rest = 0
    var axis = 0
    var faceDiagonal = 0
    for direction in D3Q19.directions {
      let nonzero = [direction.x, direction.y, direction.z].filter { $0 != 0 }
        .count
      if nonzero == 0 {
        rest += 1
      } else if nonzero == 1 {
        axis += 1
      } else if nonzero == 2 {
        faceDiagonal += 1
      }
    }
    return (
      D3Q19.directions.count,
      rest,
      axis,
      faceDiagonal,
      D3Q19.directions[5]
    )
  }

  static func latticeLensCenter(
    slice: FormationFlightFlowSlice,
    leaderRoot: SIMD3<Float>,
    followerRoot: SIMD3<Float>
  ) -> SIMD3<Float>? {
    guard slice.plane == "y",
      slice.width > 2,
      slice.height > 2,
      slice.vorticityMagnitudePerSecond.count == slice.width * slice.height,
      slice.verticalVelocityMetersPerSecond.count == slice.width * slice.height,
      slice.ownerMask.count == slice.width * slice.height
    else { return nil }
    let chord = Float(slice.chordCells)
    let z = (1 - 0.58) * leaderRoot.z + 0.58 * followerRoot.z
    let zIndex = min(
      slice.height - 2,
      max(1, Int((z * chord + 0.5 * Float(slice.height)).rounded()))
    )
    var bestX: Float = 1.45
    var bestScore: Float = -.infinity
    let maximumVorticity = max(slice.maximumVorticityMagnitudePerSecond, 1e-8)
    let maximumVertical = max(
      slice.maximumAbsoluteVerticalVelocityMetersPerSecond,
      1e-8
    )
    var bestVertical: Float = 0
    for xIndex in 1..<(slice.width - 1) {
      let x = (Float(xIndex) - 0.5 * Float(slice.width)) / chord
      guard x >= 0.72, x <= 2.35 else { continue }
      let index = xIndex + slice.width * zIndex
      guard slice.ownerMask[index] == 0 else { continue }
      let vorticity = max(slice.vorticityMagnitudePerSecond[index], 0)
        / maximumVorticity
      let vertical = abs(slice.verticalVelocityMetersPerSecond[index])
        / maximumVertical
      let score = vorticity + 0.24 * vertical
      if score > bestScore {
        bestScore = score
        bestX = x
        bestVertical = slice.verticalVelocityMetersPerSecond[index]
      }
    }
    return SIMD3<Float>(
      bestX,
      0.24 + 0.12 * bestVertical / maximumVertical,
      z
    )
  }

  static func batchedTriangleStripVertices(
    _ strips: [[ColoredVertex]]
  ) -> [ColoredVertex] {
    var result: [ColoredVertex] = []
    for strip in strips where !strip.isEmpty {
      if let last = result.last, let first = strip.first {
        result.append(last)
        result.append(first)
        result.append(first)
      }
      result.append(contentsOf: strip)
    }
    return result
  }

  private func latticeBoltzmannLensVertices(
    center: SIMD3<Float>,
    phase: Float,
    focusedSourceIntensity: Float,
    camera: CameraState
  ) -> [ColoredVertex] {
    let spacing: Float = 0.47
    let wrappedPhase = wrapped(phase)
    let source = sqrt(min(max(focusedSourceIntensity, 0), 1))
    let collision = exp(-52 * pow(sin(Float.pi * wrappedPhase), 2))
    var result: [ColoredVertex] = []
    result.reserveCapacity(1_100)

    let corners = [Float(-1), Float(1)].flatMap { x in
      [Float(-1), Float(1)].flatMap { y in
        [Float(-1), Float(1)].map { z in
          center + spacing * SIMD3<Float>(x, y, z)
        }
      }
    }
    for a in corners.indices {
      for b in (a + 1)..<corners.count {
        let delta = abs(corners[a] - corners[b])
        let changedAxes = [delta.x, delta.y, delta.z].filter { $0 > 1e-6 }
          .count
        guard changedAxes == 1 else { continue }
        appendBillboardSegment(
          from: corners[a],
          to: corners[b],
          width: 0.006,
          color: SIMD4<Float>(0.16, 0.58, 0.82, 0.13),
          camera: camera,
          to: &result
        )
      }
    }

    appendOctahedron(
      center: center,
      radius: 0.098 + 0.026 * collision,
      color: SIMD4<Float>(
        SIMD3<Float>(0.44, 0.92, 1.00) * (0.76 + 0.52 * collision),
        0.88
      ),
      to: &result
    )

    for q in 1..<D3Q19.count {
      let raw = D3Q19.directions[q]
      let direction = SIMD3<Float>(Float(raw.x), Float(raw.y), Float(raw.z))
      let endpoint = center + spacing * direction
      let isAxis = abs(raw.x) + abs(raw.y) + abs(raw.z) == 1
      let isFocused = q == 5
      let baseColor: SIMD3<Float>
      if isFocused {
        baseColor = simd_mix(
          SIMD3<Float>(0.92, 0.50, 0.16),
          SIMD3<Float>(1.00, 0.88, 0.38),
          SIMD3<Float>(repeating: source)
        )
      } else if isAxis {
        baseColor = SIMD3<Float>(0.11, 0.78, 1.00)
      } else {
        baseColor = SIMD3<Float>(0.55, 0.32, 1.00)
      }
      appendBillboardSegment(
        from: center,
        to: endpoint,
        width: isFocused ? 0.022 : 0.013,
        color: SIMD4<Float>(baseColor, isFocused ? 0.46 : 0.22),
        camera: camera,
        to: &result
      )

      let pulseCenter = 0.10 + 0.80 * wrappedPhase
      let halfLength: Float = isFocused ? 0.105 : 0.075
      let start = max(0.025, pulseCenter - halfLength)
      let end = min(0.985, pulseCenter + halfLength)
      appendBillboardSegment(
        from: simd_mix(center, endpoint, SIMD3<Float>(repeating: start)),
        to: simd_mix(center, endpoint, SIMD3<Float>(repeating: end)),
        width: isFocused ? 0.046 : 0.030,
        color: SIMD4<Float>(
          min(baseColor * (isFocused ? 1.42 : 1.16), 1.35),
          isFocused ? 0.94 : 0.72
        ),
        camera: camera,
        to: &result
      )

      let nodeRadius: Float = isAxis ? 0.056 : 0.046
      appendOctahedron(
        center: endpoint,
        radius: nodeRadius + (isFocused ? 0.010 * source : 0),
        color: SIMD4<Float>(
          min(baseColor * (isFocused ? 1.20 : 0.88), 1.20),
          isFocused ? 0.88 : 0.58
        ),
        to: &result
      )
    }
    return result
  }

  private func appendBillboardSegment(
    from start: SIMD3<Float>,
    to end: SIMD3<Float>,
    width: Float,
    color: SIMD4<Float>,
    camera: CameraState,
    to result: inout [ColoredVertex]
  ) {
    let tangent = simd_normalize(end - start + SIMD3<Float>(1e-8, 0, 0))
    let midpoint = 0.5 * (start + end)
    let view = simd_normalize(camera.eye - midpoint)
    var lateral = simd_cross(view, tangent)
    if simd_length_squared(lateral) < 1e-8 {
      lateral = simd_cross(SIMD3<Float>(0, 0, 1), tangent)
    }
    lateral = simd_normalize(lateral + SIMD3<Float>(1e-8, 0, 0))
    appendQuad(
      start - width * lateral,
      start + width * lateral,
      end + width * lateral,
      end - width * lateral,
      normal: view,
      color: color,
      to: &result
    )
  }

  private func appendOctahedron(
    center: SIMD3<Float>,
    radius: Float,
    color: SIMD4<Float>,
    to result: inout [ColoredVertex]
  ) {
    let x = SIMD3<Float>(radius, 0, 0)
    let y = SIMD3<Float>(0, radius, 0)
    let z = SIMD3<Float>(0, 0, radius)
    for (a, b, c) in [
      (x, y, z), (y, -x, z), (-x, -y, z), (-y, x, z),
      (y, x, -z), (-x, y, -z), (-y, -x, -z), (x, -y, -z),
    ] {
      appendTriangle(
        center + a,
        center + b,
        center + c,
        color: color,
        to: &result
      )
    }
  }

  static func figureEightCameraParameters(
    phase: Float
  ) -> SIMD3<Float> {
    let wrappedPhase = phase - floor(phase)
    let angle = 2 * Float.pi * wrappedPhase
    return SIMD3<Float>(
      -1.02 + 0.34 * sin(angle),
      0.38 + 0.10 * sin(2 * angle),
      10.75 + 0.10 * cos(angle)
    )
  }

  func dovePresentationAudit(
    flyerPairPhaseOffsetCycles: Float,
    archivedFlowSliceCount: Int,
    capturePhaseCount: Int,
    capturePhasesWithVisibleFlow: Int,
    minimumFlowOpacity: Float,
    focusedSourceTraceSampleCount: Int,
    focusedSourceTraceDirectionIndex: Int,
    wakeBridgePhaseCount: Int
  ) -> FormationDovePresentationAudit {
    guard let dataset = doveDataset, let loop = doveLoop else {
      return FormationDovePresentationAudit(
        schemaVersion: 6,
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
        flowDisplayMode:
          "cyclic-linear-interpolation-of-archived-c20-phases",
        archivedFlowSliceCount: archivedFlowSliceCount,
        capturePhaseCount: capturePhaseCount,
        capturePhasesWithVisibleFlow: capturePhasesWithVisibleFlow,
        minimumFlowOpacity: minimumFlowOpacity,
        flowSpatialFilterMode:
          "gaussian-radius4-sigma2-with-solid-gap-fill-presentation-only",
        flowOpacityMode:
          "joint-vorticity-and-vertical-velocity-signal",
        minimumDisplayedSignalOpacity: 0.025,
        wakeBridgeMode:
          "archived-c20-vorticity-ridge+c18-q5-luminance",
        wakeIntersectionMarkerMode:
          "presentation-phase-ring-at-follower-plane",
        latticeBoltzmannDisplayMode:
          "presentation-only-d3q19-collision-streaming-lens",
        latticeDirectionCount: D3Q19.count,
        latticeRestPopulationCount: 1,
        latticeAxisDirectionCount: 6,
        latticeFaceDiagonalDirectionCount: 12,
        collisionPulseMode: "phase-locked-central-rest-node",
        streamingPulseMode: "outward-pulse-on-all-18-moving-links",
        movingBoundaryExchangeMode:
          "focused-leader-q5-source-modulates-positive-z-link",
        focusedMomentumExchangeDirectionIndex: 5,
        focusedMomentumExchangeDirection: [0, 0, 1],
        trailDrawCallMode: "single-degenerate-strip-batch",
        postProcessingMode:
          "rgba16f-half-resolution-25-tap-bloom-highlight-rolloff",
        focusedSourceTraceSampleCount: focusedSourceTraceSampleCount,
        focusedSourceTraceDirectionIndex: focusedSourceTraceDirectionIndex,
        wakeBridgePhaseCount: wakeBridgePhaseCount,
        overlayMode: "none-cinematic",
        cameraCompositionMode:
          "spherical-figure-eight-dual-dove-wake-bridge",
        cameraYawAmplitudeRadians: 0.34,
        cameraPitchAmplitudeRadians: 0.10,
        cameraDistanceAmplitudeChords: 0.10,
        cameraEndpointParameterResidual: 0,
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
    let cameraEndpointResidual = simd_distance(
      Self.figureEightCameraParameters(phase: 0),
      Self.figureEightCameraParameters(phase: 1)
    )
    let lattice = Self.latticeBoltzmannDirectionSummary()
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
      && focusedSourceTraceSampleCount == 4_820
      && focusedSourceTraceDirectionIndex == 5
      && lattice.total == 19
      && lattice.rest == 1
      && lattice.axis == 6
      && lattice.faceDiagonal == 12
      && lattice.focusedDirection == SIMD3<Int32>(0, 0, 1)
      && wakeBridgePhaseCount == capturePhaseCount
      && cameraEndpointResidual <= 1e-7
      && Self.doveTailScale.y < 0.5 * Self.doveBodyAndWingScale.y
    return FormationDovePresentationAudit(
      schemaVersion: 6,
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
      flowDisplayMode:
        "cyclic-linear-interpolation-of-archived-c20-phases",
      archivedFlowSliceCount: archivedFlowSliceCount,
      capturePhaseCount: capturePhaseCount,
      capturePhasesWithVisibleFlow: capturePhasesWithVisibleFlow,
      minimumFlowOpacity: minimumFlowOpacity,
      flowSpatialFilterMode:
        "gaussian-radius4-sigma2-with-solid-gap-fill-presentation-only",
      flowOpacityMode:
        "joint-vorticity-and-vertical-velocity-signal",
      minimumDisplayedSignalOpacity: 0.025,
      wakeBridgeMode:
        "archived-c20-vorticity-ridge+c18-q5-luminance",
      wakeIntersectionMarkerMode:
        "presentation-phase-ring-at-follower-plane",
      latticeBoltzmannDisplayMode:
        "presentation-only-d3q19-collision-streaming-lens",
      latticeDirectionCount: lattice.total,
      latticeRestPopulationCount: lattice.rest,
      latticeAxisDirectionCount: lattice.axis,
      latticeFaceDiagonalDirectionCount: lattice.faceDiagonal,
      collisionPulseMode: "phase-locked-central-rest-node",
      streamingPulseMode: "outward-pulse-on-all-18-moving-links",
      movingBoundaryExchangeMode:
        "focused-leader-q5-source-modulates-positive-z-link",
      focusedMomentumExchangeDirectionIndex: 5,
      focusedMomentumExchangeDirection: [0, 0, 1],
      trailDrawCallMode: "single-degenerate-strip-batch",
      postProcessingMode:
        "rgba16f-half-resolution-25-tap-bloom-highlight-rolloff",
      focusedSourceTraceSampleCount: focusedSourceTraceSampleCount,
      focusedSourceTraceDirectionIndex: focusedSourceTraceDirectionIndex,
      wakeBridgePhaseCount: wakeBridgePhaseCount,
      overlayMode: "none-cinematic",
      cameraCompositionMode:
        "spherical-figure-eight-dual-dove-wake-bridge",
      cameraYawAmplitudeRadians: 0.34,
      cameraPitchAmplitudeRadians: 0.10,
      cameraDistanceAmplitudeChords: 0.10,
      cameraEndpointParameterResidual: cameraEndpointResidual,
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

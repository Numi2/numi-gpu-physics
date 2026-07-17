import AppKit
import BirdFlowMetal
import CoreText
import CryptoKit
import Foundation
import Metal
import simd

struct DoveLoopPoint {
  let position: SIMD3<Float>
  let velocity: SIMD3<Float>
}

struct MeasuredDovePresentationLoop {
  static let startFrame = 27
  static let endFrame = 121
  static let closureDurationSeconds: Float = 0.014

  let dataset: MeasuredBirdSurfaceSequence
  private let bodyCenters: [SIMD3<Float>]
  private let referenceBodyCenter: SIMD3<Float>

  init(dataset: MeasuredBirdSurfaceSequence) {
    self.dataset = dataset
    let body = dataset.components.first { $0.partIdentifier == 1 }!
    bodyCenters = (0..<dataset.frameCount).map { frame in
      var center = SIMD3<Float>.zero
      for index in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
        center += dataset.vertex(frame: frame, index: index)
      }
      return center / Float(body.vertexCount)
    }
    referenceBodyCenter = bodyCenters[Self.startFrame]
  }

  var measuredDurationSeconds: Float {
    dataset.frameTimesSeconds[Self.endFrame]
      - dataset.frameTimesSeconds[Self.startFrame]
  }

  var periodSeconds: Float {
    measuredDurationSeconds + Self.closureDurationSeconds
  }

  func point(phase: Float, vertexIndex: Int) -> DoveLoopPoint {
    let time = equivalentTime(phase: phase)
    if time < measuredDurationSeconds {
      return sourcePoint(
        timeSeconds: dataset.frameTimesSeconds[Self.startFrame] + time,
        vertexIndex: vertexIndex
      )
    }
    let closureTime = time - measuredDurationSeconds
    let blend = closureTime / Self.closureDurationSeconds
    let startTime = dataset.frameTimesSeconds[Self.startFrame]
    let endTime = dataset.frameTimesSeconds[Self.endFrame]
    let halfStep = 0.5 / dataset.sampleRateHertz
    let start = sourcePoint(timeSeconds: startTime, vertexIndex: vertexIndex)
    let end = sourcePoint(timeSeconds: endTime, vertexIndex: vertexIndex)
    let startVelocity = sourcePoint(
      timeSeconds: startTime + halfStep,
      vertexIndex: vertexIndex
    ).velocity
    let endVelocity = sourcePoint(
      timeSeconds: endTime - halfStep,
      vertexIndex: vertexIndex
    ).velocity
    let blendSquared = blend * blend
    let blendCubed = blendSquared * blend
    let h00 = 2 * blendCubed - 3 * blendSquared + 1
    let h10 = blendCubed - 2 * blendSquared + blend
    let h01 = -2 * blendCubed + 3 * blendSquared
    let h11 = blendCubed - blendSquared
    let duration = Self.closureDurationSeconds
    let position =
      h00 * end.position
      + h10 * duration * endVelocity
      + h01 * start.position
      + h11 * duration * startVelocity
    let dh00 = 6 * blendSquared - 6 * blend
    let dh10 = 3 * blendSquared - 4 * blend + 1
    let dh01 = -6 * blendSquared + 6 * blend
    let dh11 = 3 * blendSquared - 2 * blend
    let velocity =
      (dh00 * end.position
        + dh10 * duration * endVelocity
        + dh01 * start.position
        + dh11 * duration * startVelocity) / duration
    return DoveLoopPoint(position: position, velocity: velocity)
  }

  func sourceTime(phase: Float) -> Float? {
    let time = equivalentTime(phase: phase)
    guard time < measuredDurationSeconds else { return nil }
    return dataset.frameTimesSeconds[Self.startFrame] + time
  }

  func sourceFrameCoordinate(phase: Float) -> Float? {
    guard let time = sourceTime(phase: phase) else { return nil }
    return Float(Self.startFrame)
      + (time - dataset.frameTimesSeconds[Self.startFrame])
      * dataset.sampleRateHertz
  }

  func phase(offsetBy seconds: Float, from phase: Float) -> Float {
    wrappedPhase(phase + seconds / periodSeconds)
  }

  private func equivalentTime(phase: Float) -> Float {
    wrappedPhase(phase) * periodSeconds
  }

  private func wrappedPhase(_ phase: Float) -> Float {
    let remainder = phase.truncatingRemainder(dividingBy: 1)
    return remainder >= 0 ? remainder : remainder + 1
  }

  private func sourcePoint(
    timeSeconds: Float,
    vertexIndex: Int
  ) -> DoveLoopPoint {
    let state = dataset.state(
      timeSeconds: timeSeconds,
      vertexIndex: vertexIndex
    )
    let center = bodyCenter(timeSeconds: timeSeconds)
    return DoveLoopPoint(
      position: state.positionMeters - center.position + referenceBodyCenter,
      velocity: state.velocityMetersPerSecond - center.velocity
    )
  }

  private func bodyCenter(timeSeconds: Float) -> DoveLoopPoint {
    let first = dataset.frameTimesSeconds[0]
    let lastIndex = dataset.frameCount - 1
    if timeSeconds <= first {
      let duration = dataset.frameTimesSeconds[1] - first
      return DoveLoopPoint(
        position: bodyCenters[0],
        velocity: (bodyCenters[1] - bodyCenters[0]) / duration
      )
    }
    if timeSeconds >= dataset.frameTimesSeconds[lastIndex] {
      let duration =
        dataset.frameTimesSeconds[lastIndex]
        - dataset.frameTimesSeconds[lastIndex - 1]
      return DoveLoopPoint(
        position: bodyCenters[lastIndex],
        velocity: (bodyCenters[lastIndex] - bodyCenters[lastIndex - 1]) / duration
      )
    }
    var lower = 0
    var upper = lastIndex
    while lower + 1 < upper {
      let middle = lower + (upper - lower) / 2
      if timeSeconds < dataset.frameTimesSeconds[middle] {
        upper = middle
      } else {
        lower = middle
      }
    }
    let duration =
      dataset.frameTimesSeconds[upper]
      - dataset.frameTimesSeconds[lower]
    let blend = (timeSeconds - dataset.frameTimesSeconds[lower]) / duration
    let delta = bodyCenters[upper] - bodyCenters[lower]
    return DoveLoopPoint(
      position: bodyCenters[lower] + blend * delta,
      velocity: delta / duration
    )
  }
}

enum MeasuredDoveShowcaseCapture {
  private struct D32FullWindowArtifact: Decodable {
    struct ForceSample: Decodable {
      let sourceTimeSeconds: Double
      let measuredForceZNewtons: Double
      let intervalMeanComputedForceNewtons: [Double]
    }

    struct LedgerResult: Decodable {
      let allValuesFinite: Bool
      let collisionLimiterActivationFractionOfCellSteps: Double
      let collisionOperator: String
      let completedSteps: Int
      let minimumPopulation: Double
      let momentumClosurePassed: Bool
      let sampledPopulationPositivityPassed: Bool
    }

    let schemaVersion: Int
    let selectedCollisionOperator: String
    let referenceLengthCells: Int
    let gridX: Int
    let gridY: Int
    let gridZ: Int
    let actualTauPlus: Double
    let requestedSteps: Int
    let requestedComparisonSamples: Int
    let registeredForceSamples: [ForceSample]
    let registeredComparisonSampleCount: Int
    let normalizedRMSError: Double?
    let productionTauMarginPassed: Bool
    let workingSetPreflightPassed: Bool
    let allStepsCompleted: Bool
    let populationPositivityPassed: Bool
    let forceAndMomentumAccountingPassed: Bool
    let collisionCorrectionIntrusionPassed: Bool
    let registeredWindowComplete: Bool
    let fullWindowGatePassed: Bool
    let experimentalAgreementGateApplied: Bool
    let gridConvergenceGateApplied: Bool
    let productionModificationAuthorized: Bool
    let ledgerResult: LedgerResult
  }

  private struct D32FullWindowAudit: Decodable {
    let checkCount: Int
    let reportSHA256: String
    let allChecksPassed: Bool
    let d32ForceHistoryAcceptedAsRefinementInput: Bool
  }

  private struct D28D32Refinement: Decodable {
    struct Metrics: Decodable {
      let horizontalForceNormalizedRMSDifference: Double
      let verticalForceNormalizedRMSDifference: Double
    }

    let sourceD32ReportSHA256: String
    let sourceD32AuditSHA256: String
    let metrics: Metrics
    let gridTrendScore: Double
    let maximumFinePairDifference: Double
    let finePairStabilizationPassed: Bool
    let gridConvergenceAccepted: Bool
    let productionModificationAuthorized: Bool
    let classification: String
  }

  private struct D28D32PhaseLocalization: Decodable {
    struct DominantBand: Decodable {
      let startTimeSeconds: Double
      let endTimeSeconds: Double
      let vectorSquaredDifferenceFraction: Double
    }

    struct TargetedReplay: Decodable {
      let startTimeSeconds: Double
      let endTimeSeconds: Double
      let d36RunAuthorized: Bool
    }

    let sourceRefinementReportSHA256: String
    let exploratoryPostHocAnalysis: Bool
    let fluidEvolutionExecuted: Bool
    let dominantPhaseBand: DominantBand
    let targetedReplayRecommendation: TargetedReplay
    let classification: String
  }

  private struct D28D32PhaseLocalizationAudit: Decodable {
    let reportSHA256: String
    let allChecksPassed: Bool
    let targetedD28D32ReplaySupported: Bool
    let d36RunAuthorized: Bool
  }

  private struct TargetedBoundaryAttribution: Decodable {
    struct Attribution: Decodable {
      let classification: String
      let dominantContributionAvailable: Bool
      let leadingContributionName: String
      let leadingContributionKind: String
      let leadingAbsoluteLedgerFraction: Double
      let sameLeaderInBothTemporalHalves: Bool
    }

    let sourceD28CaseSHA256: String
    let sourceD32CaseSHA256: String
    let componentDifferenceClosureRelativeRMS: Double
    let squaredDifferenceEnergyClosureRelativeError: Double
    let attribution: Attribution
    let bothTargetedCasesPassed: Bool
    let productionModificationAuthorized: Bool
    let experimentalAgreementGateApplied: Bool
    let gridConvergenceGateApplied: Bool
  }

  private struct TargetedBoundaryAudit: Decodable {
    let reportSHA256: String
    let d28CaseSHA256: String
    let d32CaseSHA256: String
    let checkCount: Int
    let allChecksPassed: Bool
    let productionModificationAuthorized: Bool
  }

  private struct ReflectedProvenanceAttribution: Decodable {
    struct Attribution: Decodable {
      let classification: String
      let dominantContributionAvailable: Bool
      let leadingContributionName: String
      let leadingContributionKind: String
      let leadingAbsoluteLedgerFraction: Double
      let sameLeaderInBothTemporalHalves: Bool
    }

    let preregistrationSHA256: String
    let sourceD28CaseSHA256: String
    let sourceD32CaseSHA256: String
    let populationCompositionClosureRelativeRMS: Double
    let rawFloatForceConsistencyRelativeRMS: Double
    let attribution: Attribution
    let bothProvenanceCasesPassed: Bool
    let populationCompositionClosurePassed: Bool
    let productionModificationAuthorized: Bool
    let experimentalAgreementGateApplied: Bool
    let gridConvergenceGateApplied: Bool
  }

  private struct ReflectedProvenanceAudit: Decodable {
    let preregistrationSHA256: String
    let d28CaseSHA256: String
    let d32CaseSHA256: String
    let reportSHA256: String
    let checkCount: Int
    let allChecksPassed: Bool
    let productionModificationAuthorized: Bool
  }

  private struct LinkCompositionPreregistration: Decodable {
    let schemaVersion: Int
    let passed: Bool
    let sourceD28ProvenanceSHA256: String
    let sourceD32ProvenanceSHA256: String
    let sourceProvenanceAttributionSHA256: String
    let fluidEvolutionAuthorized: Bool
    let productionModificationAuthorized: Bool
    let d36RunAuthorized: Bool
  }

  private struct LinkCompositionAttribution: Decodable {
    struct Attribution: Decodable {
      let classification: String
      let dominantFactorAvailable: Bool
      let leadingFactor: String
      let earlyLeader: String
      let lateLeader: String
      let leadingAbsoluteLedgerFraction: Double
      let sameLeaderInBothTemporalHalves: Bool
    }

    let schemaVersion: Int
    let analysisPassed: Bool
    let fluidEvolutionExecuted: Bool
    let preregistrationSHA256: String
    let sourceD28ProvenanceSHA256: String
    let sourceD32ProvenanceSHA256: String
    let sourceProvenanceAttributionSHA256: String
    let maximumPooledFallbackProbabilityMass: Double
    let attribution: Attribution
    let minimalCanonicalAuthorized: Bool
    let productionModificationAuthorized: Bool
    let experimentalAgreementGateApplied: Bool
    let gridConvergenceGateApplied: Bool
    let d36RunAuthorized: Bool
  }

  private struct LinkCompositionAudit: Decodable {
    let schemaVersion: Int
    let preregistrationSHA256: String
    let d28ProvenanceSHA256: String
    let d32ProvenanceSHA256: String
    let sourceAttributionSHA256: String
    let reportSHA256: String
    let checkCount: Int
    let allChecksPassed: Bool
    let fluidEvolutionExecuted: Bool
    let productionModificationAuthorized: Bool
  }

  private struct ForceHistory {
    let times: [Double]
    let measured: [Double]
    let computed: [Double]
    let normalizedRMSError: Double
  }

  static func run(
    arguments: ReadmeShowcaseCapture.Arguments,
    manifestURL: URL,
    d32FullWindowArtifactURL: URL,
    d32FullWindowAuditURL: URL,
    refinementURL: URL,
    phaseLocalizationURL: URL,
    phaseLocalizationAuditURL: URL,
    targetedD28URL: URL,
    targetedD32URL: URL,
    targetedAttributionURL: URL,
    targetedAuditURL: URL,
    reflectedPreregistrationURL: URL,
    reflectedD28URL: URL,
    reflectedD32URL: URL,
    reflectedAttributionURL: URL,
    reflectedAuditURL: URL,
    linkCompositionPreregistrationURL: URL,
    linkCompositionAttributionURL: URL,
    linkCompositionAuditURL: URL
  ) throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
      manifestURL: manifestURL
    )
    let artifactData = try Data(contentsOf: d32FullWindowArtifactURL)
    let artifact = try JSONDecoder().decode(
      D32FullWindowArtifact.self,
      from: artifactData
    )
    let auditData = try Data(contentsOf: d32FullWindowAuditURL)
    let audit = try JSONDecoder().decode(
      D32FullWindowAudit.self,
      from: auditData
    )
    let refinementData = try Data(contentsOf: refinementURL)
    let refinement = try JSONDecoder().decode(
      D28D32Refinement.self,
      from: refinementData
    )
    let phaseLocalizationData = try Data(contentsOf: phaseLocalizationURL)
    let phaseLocalization = try JSONDecoder().decode(
      D28D32PhaseLocalization.self,
      from: phaseLocalizationData
    )
    let phaseLocalizationAudit = try JSONDecoder().decode(
      D28D32PhaseLocalizationAudit.self,
      from: Data(contentsOf: phaseLocalizationAuditURL)
    )
    let targetedD28Data = try Data(contentsOf: targetedD28URL)
    let targetedD28 = try JSONDecoder().decode(
      MetalIndexedBirdSurfaceTargetedBoundaryCaseReport.self,
      from: targetedD28Data
    )
    let targetedD32Data = try Data(contentsOf: targetedD32URL)
    let targetedD32 = try JSONDecoder().decode(
      MetalIndexedBirdSurfaceTargetedBoundaryCaseReport.self,
      from: targetedD32Data
    )
    let targetedAttributionData = try Data(
      contentsOf: targetedAttributionURL
    )
    let targetedAttribution = try JSONDecoder().decode(
      TargetedBoundaryAttribution.self,
      from: targetedAttributionData
    )
    let targetedAudit = try JSONDecoder().decode(
      TargetedBoundaryAudit.self,
      from: Data(contentsOf: targetedAuditURL)
    )
    let reflectedPreregistrationData = try Data(
      contentsOf: reflectedPreregistrationURL
    )
    let reflectedPreregistration = try JSONDecoder().decode(
      MetalIndexedBirdSurfaceReflectedProvenancePreregistration.self,
      from: reflectedPreregistrationData
    )
    let reflectedD28Data = try Data(contentsOf: reflectedD28URL)
    let reflectedD28 = try JSONDecoder().decode(
      MetalIndexedBirdSurfaceReflectedProvenanceCaseReport.self,
      from: reflectedD28Data
    )
    let reflectedD32Data = try Data(contentsOf: reflectedD32URL)
    let reflectedD32 = try JSONDecoder().decode(
      MetalIndexedBirdSurfaceReflectedProvenanceCaseReport.self,
      from: reflectedD32Data
    )
    let reflectedAttributionData = try Data(
      contentsOf: reflectedAttributionURL
    )
    let reflectedAttribution = try JSONDecoder().decode(
      ReflectedProvenanceAttribution.self,
      from: reflectedAttributionData
    )
    let reflectedAudit = try JSONDecoder().decode(
      ReflectedProvenanceAudit.self,
      from: Data(contentsOf: reflectedAuditURL)
    )
    let linkCompositionPreregistrationData = try Data(
      contentsOf: linkCompositionPreregistrationURL
    )
    let linkCompositionPreregistration = try JSONDecoder().decode(
      LinkCompositionPreregistration.self,
      from: linkCompositionPreregistrationData
    )
    let linkCompositionAttributionData = try Data(
      contentsOf: linkCompositionAttributionURL
    )
    let linkCompositionAttribution = try JSONDecoder().decode(
      LinkCompositionAttribution.self,
      from: linkCompositionAttributionData
    )
    let linkCompositionAuditData = try Data(
      contentsOf: linkCompositionAuditURL
    )
    let linkCompositionAudit = try JSONDecoder().decode(
      LinkCompositionAudit.self,
      from: linkCompositionAuditData
    )
    let forceHistory = try validateAndBuildHistory(
      dataset: dataset,
      artifact: artifact,
      audit: audit,
      artifactSHA256: sha256(artifactData),
      auditSHA256: sha256(auditData),
      refinement: refinement,
      refinementSHA256: sha256(refinementData),
      phaseLocalization: phaseLocalization,
      phaseLocalizationSHA256: sha256(phaseLocalizationData),
      phaseLocalizationAudit: phaseLocalizationAudit,
      targetedD28: targetedD28,
      targetedD28SHA256: sha256(targetedD28Data),
      targetedD32: targetedD32,
      targetedD32SHA256: sha256(targetedD32Data),
      targetedAttribution: targetedAttribution,
      targetedAttributionSHA256: sha256(targetedAttributionData),
      targetedAudit: targetedAudit,
      reflectedPreregistration: reflectedPreregistration,
      reflectedPreregistrationSHA256: sha256(reflectedPreregistrationData),
      reflectedD28: reflectedD28,
      reflectedD28SHA256: sha256(reflectedD28Data),
      reflectedD32: reflectedD32,
      reflectedD32SHA256: sha256(reflectedD32Data),
      reflectedAttribution: reflectedAttribution,
      reflectedAttributionSHA256: sha256(reflectedAttributionData),
      reflectedAudit: reflectedAudit,
      linkCompositionPreregistration: linkCompositionPreregistration,
      linkCompositionPreregistrationSHA256:
        sha256(linkCompositionPreregistrationData),
      linkCompositionAttribution: linkCompositionAttribution,
      linkCompositionAttributionSHA256:
        sha256(linkCompositionAttributionData),
      linkCompositionAudit: linkCompositionAudit
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
    let loop = MeasuredDovePresentationLoop(dataset: dataset)
    try FileManager.default.createDirectory(
      at: arguments.outputDirectory,
      withIntermediateDirectories: true
    )

    for frameIndex in 0..<arguments.frameCount {
      let progress = Float(frameIndex) / Float(arguments.frameCount - 1)
      let bounds = frameBounds(loop: loop, phase: progress)
      let center = 0.5 * (bounds.minimum + bounds.maximum)
      var camera = CameraState()
      camera.distance = 0.515 * (1 + 0.012 * cos(2 * .pi * progress))
      camera.yaw = -1.02 + 0.045 * sin(2 * .pi * progress)
      camera.pitch = 0.34 + 0.018 * cos(2 * .pi * progress)
      camera.target = center
      let forward = simd_normalize(center - camera.eye)
      let right = simd_normalize(
        simd_cross(forward, SIMD3<Float>(0, 0, 1))
      )
      camera.target = center + 0.052 * right + SIMD3<Float>(0, 0, 0.005)

      let texture = try renderer.render(
        loop: loop,
        phase: progress,
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
          sourceTime: loop.sourceTime(phase: progress).map(Double.init),
          forceHistory: forceHistory,
          d32FullWindow: artifact,
          refinement: refinement,
          phaseLocalization: phaseLocalization,
          linkCompositionAttribution: linkCompositionAttribution,
          frameCoordinate: loop.sourceFrameCoordinate(phase: progress)
        )
      }
      let output = arguments.outputDirectory.appendingPathComponent(
        String(format: "frame-%03d.png", frameIndex)
      )
      try png.write(to: output, options: .atomic)
      print(
        "captured dove \(frameIndex + 1)/\(arguments.frameCount) "
          + (loop.sourceFrameCoordinate(phase: progress).map {
            "source_frame=\(String(format: "%.2f", $0))"
          } ?? "presentation_closure=true")
      )
    }
  }

  private static func validateAndBuildHistory(
    dataset: MeasuredBirdSurfaceSequence,
    artifact: D32FullWindowArtifact,
    audit: D32FullWindowAudit,
    artifactSHA256: String,
    auditSHA256: String,
    refinement: D28D32Refinement,
    refinementSHA256: String,
    phaseLocalization: D28D32PhaseLocalization,
    phaseLocalizationSHA256: String,
    phaseLocalizationAudit: D28D32PhaseLocalizationAudit,
    targetedD28: MetalIndexedBirdSurfaceTargetedBoundaryCaseReport,
    targetedD28SHA256: String,
    targetedD32: MetalIndexedBirdSurfaceTargetedBoundaryCaseReport,
    targetedD32SHA256: String,
    targetedAttribution: TargetedBoundaryAttribution,
    targetedAttributionSHA256: String,
    targetedAudit: TargetedBoundaryAudit,
    reflectedPreregistration:
      MetalIndexedBirdSurfaceReflectedProvenancePreregistration,
    reflectedPreregistrationSHA256: String,
    reflectedD28: MetalIndexedBirdSurfaceReflectedProvenanceCaseReport,
    reflectedD28SHA256: String,
    reflectedD32: MetalIndexedBirdSurfaceReflectedProvenanceCaseReport,
    reflectedD32SHA256: String,
    reflectedAttribution: ReflectedProvenanceAttribution,
    reflectedAttributionSHA256: String,
    reflectedAudit: ReflectedProvenanceAudit,
    linkCompositionPreregistration: LinkCompositionPreregistration,
    linkCompositionPreregistrationSHA256: String,
    linkCompositionAttribution: LinkCompositionAttribution,
    linkCompositionAttributionSHA256: String,
    linkCompositionAudit: LinkCompositionAudit
  ) throws -> ForceHistory {
    let expectedOperator = "positivity-preserving-recursive-regularized-bgk"
    guard dataset.frameCount == 144,
      dataset.vertexCount == 2_157,
      dataset.triangleCount == 3_968,
      artifact.schemaVersion == 1,
      artifact.selectedCollisionOperator == expectedOperator,
      artifact.referenceLengthCells == 32,
      artifact.gridX == 296,
      artifact.gridY == 271,
      artifact.gridZ == 261,
      artifact.actualTauPlus >= 0.500_05,
      artifact.requestedSteps == 15_104,
      !artifact.experimentalAgreementGateApplied,
      !artifact.gridConvergenceGateApplied,
      !artifact.productionModificationAuthorized,
      artifact.requestedComparisonSamples == 187,
      artifact.registeredComparisonSampleCount == 187,
      artifact.registeredForceSamples.count == 187,
      artifact.productionTauMarginPassed,
      artifact.workingSetPreflightPassed,
      artifact.allStepsCompleted,
      artifact.populationPositivityPassed,
      artifact.forceAndMomentumAccountingPassed,
      artifact.collisionCorrectionIntrusionPassed,
      artifact.registeredWindowComplete,
      artifact.fullWindowGatePassed,
      artifact.ledgerResult.collisionOperator == expectedOperator,
      artifact.ledgerResult.completedSteps == 15_104,
      artifact.ledgerResult.allValuesFinite,
      artifact.ledgerResult.sampledPopulationPositivityPassed,
      artifact.ledgerResult.momentumClosurePassed,
      artifact.ledgerResult.minimumPopulation > 0,
      artifact.ledgerResult.collisionLimiterActivationFractionOfCellSteps
        <= 0.05,
      audit.checkCount >= 17,
      audit.reportSHA256 == artifactSHA256,
      audit.allChecksPassed,
      audit.d32ForceHistoryAcceptedAsRefinementInput,
      refinement.sourceD32ReportSHA256 == artifactSHA256,
      refinement.sourceD32AuditSHA256 == auditSHA256,
      refinement.gridTrendScore > refinement.maximumFinePairDifference,
      abs(refinement.gridTrendScore - 0.056_321_598_232_749_01) < 1e-12,
      abs(refinement.metrics.horizontalForceNormalizedRMSDifference
        - 0.073_756_565_155_349_02) < 1e-12,
      abs(refinement.metrics.verticalForceNormalizedRMSDifference
        - 0.046_610_471_350_922_694) < 1e-12,
      !refinement.finePairStabilizationPassed,
      !refinement.gridConvergenceAccepted,
      !refinement.productionModificationAuthorized,
      refinement.classification == "d28-d32-fine-pair-not-stabilized",
      phaseLocalization.sourceRefinementReportSHA256 == refinementSHA256,
      phaseLocalization.exploratoryPostHocAnalysis,
      !phaseLocalization.fluidEvolutionExecuted,
      phaseLocalization.classification
        == "early-window-phase-localized-two-component-grid-sensitivity",
      abs(phaseLocalization.targetedReplayRecommendation.startTimeSeconds
        - 0.025) < 1e-12,
      abs(phaseLocalization.targetedReplayRecommendation.endTimeSeconds
        - 0.030) < 1e-12,
      !phaseLocalization.targetedReplayRecommendation.d36RunAuthorized,
      phaseLocalizationAudit.reportSHA256 == phaseLocalizationSHA256,
      phaseLocalizationAudit.allChecksPassed,
      phaseLocalizationAudit.targetedD28D32ReplaySupported,
      !phaseLocalizationAudit.d36RunAuthorized,
      targetedD28.referenceLengthCells == 28,
      targetedD28.targetedCasePassed,
      targetedD28.componentBins.count == 11,
      targetedD32.referenceLengthCells == 32,
      targetedD32.targetedCasePassed,
      targetedD32.componentBins.count == 11,
      targetedD28.sourcePreregistrationSHA256
        == targetedD32.sourcePreregistrationSHA256,
      targetedAttribution.sourceD28CaseSHA256 == targetedD28SHA256,
      targetedAttribution.sourceD32CaseSHA256 == targetedD32SHA256,
      targetedAttribution.bothTargetedCasesPassed,
      targetedAttribution.componentDifferenceClosureRelativeRMS <= 1e-4,
      targetedAttribution.squaredDifferenceEnergyClosureRelativeError <= 1e-4,
      !targetedAttribution.productionModificationAuthorized,
      !targetedAttribution.experimentalAgreementGateApplied,
      !targetedAttribution.gridConvergenceGateApplied,
      targetedAudit.reportSHA256 == targetedAttributionSHA256,
      targetedAudit.d28CaseSHA256 == targetedD28SHA256,
      targetedAudit.d32CaseSHA256 == targetedD32SHA256,
      targetedAudit.checkCount >= 15,
      targetedAudit.allChecksPassed,
      !targetedAudit.productionModificationAuthorized,
      reflectedPreregistration.schemaVersion == 2,
      reflectedPreregistration.passed,
      reflectedPreregistration.referenceLengthCells == [28, 32],
      reflectedPreregistration.targetSampleIndices == Array(50...60),
      reflectedPreregistration.candidateCapacity == 262_144,
      reflectedPreregistration.selectedLinksPerEndpoint == 131_072,
      reflectedD28.schemaVersion == 2,
      reflectedD28.referenceLengthCells == 28,
      reflectedD28.provenanceCasePassed,
      reflectedD28.candidateOverflowCount == 0,
      reflectedD28.candidateDetailMismatchCount == 0,
      reflectedD28.minimumSelectedAbsoluteScoreCoverage >= 0.5,
      reflectedD32.schemaVersion == 2,
      reflectedD32.referenceLengthCells == 32,
      reflectedD32.provenanceCasePassed,
      reflectedD32.candidateOverflowCount == 0,
      reflectedD32.candidateDetailMismatchCount == 0,
      reflectedD32.minimumSelectedAbsoluteScoreCoverage >= 0.5,
      reflectedD28.sourcePreregistrationSHA256
        == reflectedPreregistrationSHA256,
      reflectedD32.sourcePreregistrationSHA256
        == reflectedPreregistrationSHA256,
      reflectedAttribution.preregistrationSHA256
        == reflectedPreregistrationSHA256,
      reflectedAttribution.sourceD28CaseSHA256 == reflectedD28SHA256,
      reflectedAttribution.sourceD32CaseSHA256 == reflectedD32SHA256,
      reflectedAttribution.bothProvenanceCasesPassed,
      reflectedAttribution.populationCompositionClosurePassed,
      reflectedAttribution.populationCompositionClosureRelativeRMS <= 1e-10,
      reflectedAttribution.rawFloatForceConsistencyRelativeRMS <= 1e-6,
      reflectedAttribution.attribution.dominantContributionAvailable,
      reflectedAttribution.attribution.leadingContributionName
        == "linkComposition",
      reflectedAttribution.attribution.leadingContributionKind == "self",
      reflectedAttribution.attribution.leadingAbsoluteLedgerFraction >= 0.5,
      reflectedAttribution.attribution.sameLeaderInBothTemporalHalves,
      !reflectedAttribution.productionModificationAuthorized,
      !reflectedAttribution.experimentalAgreementGateApplied,
      !reflectedAttribution.gridConvergenceGateApplied,
      reflectedAudit.preregistrationSHA256 == reflectedPreregistrationSHA256,
      reflectedAudit.d28CaseSHA256 == reflectedD28SHA256,
      reflectedAudit.d32CaseSHA256 == reflectedD32SHA256,
      reflectedAudit.reportSHA256 == reflectedAttributionSHA256,
      reflectedAudit.checkCount >= 16,
      reflectedAudit.allChecksPassed,
      !reflectedAudit.productionModificationAuthorized,
      linkCompositionPreregistration.schemaVersion == 1,
      linkCompositionPreregistration.passed,
      linkCompositionPreregistration.sourceD28ProvenanceSHA256
        == reflectedD28SHA256,
      linkCompositionPreregistration.sourceD32ProvenanceSHA256
        == reflectedD32SHA256,
      linkCompositionPreregistration.sourceProvenanceAttributionSHA256
        == reflectedAttributionSHA256,
      !linkCompositionPreregistration.fluidEvolutionAuthorized,
      !linkCompositionPreregistration.productionModificationAuthorized,
      !linkCompositionPreregistration.d36RunAuthorized,
      linkCompositionAttribution.schemaVersion == 1,
      linkCompositionAttribution.analysisPassed,
      !linkCompositionAttribution.fluidEvolutionExecuted,
      linkCompositionAttribution.preregistrationSHA256
        == linkCompositionPreregistrationSHA256,
      linkCompositionAttribution.sourceD28ProvenanceSHA256
        == reflectedD28SHA256,
      linkCompositionAttribution.sourceD32ProvenanceSHA256
        == reflectedD32SHA256,
      linkCompositionAttribution.sourceProvenanceAttributionSHA256
        == reflectedAttributionSHA256,
      linkCompositionAttribution.maximumPooledFallbackProbabilityMass < 0.05,
      linkCompositionAttribution.attribution.dominantFactorAvailable,
      linkCompositionAttribution.attribution.classification
        == "dominant-conditioned-factor:directionComposition",
      linkCompositionAttribution.attribution.leadingFactor
        == "directionComposition",
      linkCompositionAttribution.attribution.earlyLeader
        == "directionComposition",
      linkCompositionAttribution.attribution.lateLeader
        == "directionComposition",
      linkCompositionAttribution.attribution.leadingAbsoluteLedgerFraction
        >= 0.5,
      linkCompositionAttribution.attribution.sameLeaderInBothTemporalHalves,
      linkCompositionAttribution.minimalCanonicalAuthorized,
      !linkCompositionAttribution.productionModificationAuthorized,
      !linkCompositionAttribution.experimentalAgreementGateApplied,
      !linkCompositionAttribution.gridConvergenceGateApplied,
      !linkCompositionAttribution.d36RunAuthorized,
      linkCompositionAudit.schemaVersion == 1,
      linkCompositionAudit.preregistrationSHA256
        == linkCompositionPreregistrationSHA256,
      linkCompositionAudit.d28ProvenanceSHA256 == reflectedD28SHA256,
      linkCompositionAudit.d32ProvenanceSHA256 == reflectedD32SHA256,
      linkCompositionAudit.sourceAttributionSHA256
        == reflectedAttributionSHA256,
      linkCompositionAudit.reportSHA256
        == linkCompositionAttributionSHA256,
      linkCompositionAudit.checkCount >= 18,
      linkCompositionAudit.allChecksPassed,
      !linkCompositionAudit.fluidEvolutionExecuted,
      !linkCompositionAudit.productionModificationAuthorized,
      let normalizedRMSError = artifact.normalizedRMSError,
      normalizedRMSError.isFinite
    else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "measured-dove showcase inputs do not match the audited D32 frontier"
      )
    }
    guard artifact.registeredForceSamples.allSatisfy({
      $0.intervalMeanComputedForceNewtons.count == 3
        && $0.sourceTimeSeconds.isFinite
        && $0.measuredForceZNewtons.isFinite
        && $0.intervalMeanComputedForceNewtons.allSatisfy(\.isFinite)
    }) else {
      throw ReadmeShowcaseCapture.CaptureError.invalidFrame(
        "audited D32 force history is malformed"
      )
    }
    return ForceHistory(
      times: artifact.registeredForceSamples.map(\.sourceTimeSeconds),
      measured: artifact.registeredForceSamples.map(\.measuredForceZNewtons),
      computed: artifact.registeredForceSamples.map {
        $0.intervalMeanComputedForceNewtons[2]
      },
      normalizedRMSError: normalizedRMSError
    )
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func frameBounds(
    loop: MeasuredDovePresentationLoop,
    phase: Float
  ) -> (minimum: SIMD3<Float>, maximum: SIMD3<Float>) {
    var minimum = SIMD3<Float>(repeating: .infinity)
    var maximum = SIMD3<Float>(repeating: -.infinity)
    for index in 0..<loop.dataset.vertexCount {
      let point = loop.point(phase: phase, vertexIndex: index).position
      minimum = simd_min(minimum, point)
      maximum = simd_max(maximum, point)
    }
    return (minimum, maximum)
  }

  private static func drawOverlay(
    graphics: CGContext,
    width: Int,
    height: Int,
    sourceTime: Double?,
    forceHistory: ForceHistory,
    d32FullWindow: D32FullWindowArtifact,
    refinement: D28D32Refinement,
    phaseLocalization: D28D32PhaseLocalization,
    linkCompositionAttribution: LinkCompositionAttribution,
    frameCoordinate: Float?
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
      "MEASURED DOVE · NATIVE METAL REPLAY",
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
      "OB_F03  •  SOURCE-LOCKED 27–121 MS  •  BODY-FOLLOWING",
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
      "D28/D32 CONDITIONED LINK COMPOSITION",
      font: systemFont(.emphasizedSystem, size: 12.5 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(
        x: statusPanel.minX + 16 * scale,
        y: statusPanel.minY + 35 * scale
      ),
      tracking: 0.35 * scale,
      context: graphics
    )
    let attributionStatus = String(
      format: "AUDITED  •  DIRECTION COMPOSITION  •  %.1f%% OF |LEDGER|",
      100 * linkCompositionAttribution.attribution
        .leadingAbsoluteLedgerFraction
    )
    drawText(
      attributionStatus,
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
      sensitiveStartTime: phaseLocalization.targetedReplayRecommendation
        .startTimeSeconds,
      sensitiveEndTime: phaseLocalization.targetedReplayRecommendation
        .endTimeSeconds,
      context: graphics,
      scale: scale
    )

    let progress = NSRect(
      x: margin,
      y: margin,
      width: CGFloat(width) - 2 * margin - 360 * scale,
      height: 58 * scale
    )
    drawProgressRail(in: progress, context: graphics, scale: scale)

    let boundary = NSRect(
      x: CGFloat(width) - margin - 344 * scale,
      y: margin,
      width: 344 * scale,
      height: 58 * scale
    )
    fillPanel(boundary, radius: 12 * scale, context: graphics)
    drawText(
      frameCoordinate.map {
        "SCIENTIFIC BOUNDARY  ·  SOURCE t=\(Int($0.rounded())) ms"
      } ?? "SCIENTIFIC BOUNDARY  ·  14 ms LOOP CLOSURE",
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
      String(
        format: "D28/D32 %.3f%% > %.1f%%  •  CONVERGENCE OPEN",
        100 * refinement.gridTrendScore,
        100 * refinement.maximumFinePairDifference
      ),
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
    currentTime: Double?,
    history: ForceHistory,
    sensitiveStartTime: Double,
    sensitiveEndTime: Double,
    context: CGContext,
    scale: CGFloat
  ) {
    fillPanel(rect, radius: 13 * scale, alpha: 0.82, context: context)
    drawText(
      "D32 FORCE HISTORY · DESCRIPTIVE",
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
    let values = history.measured + history.computed
    guard let rawMinimum = values.min(), let rawMaximum = values.max() else {
      return
    }
    let padding = max(0.1, 0.08 * (rawMaximum - rawMinimum))
    let minimum = rawMinimum - padding
    let maximum = rawMaximum + padding
    let startTime = history.times[0]
    let endTime = history.times[history.times.count - 1]
    let sensitiveStart = min(
      max((sensitiveStartTime - startTime) / (endTime - startTime), 0),
      1
    )
    let sensitiveEnd = min(
      max((sensitiveEndTime - startTime) / (endTime - startTime), 0),
      1
    )
    let sensitiveRect = NSRect(
      x: plot.minX + CGFloat(sensitiveStart) * plot.width,
      y: plot.minY,
      width: CGFloat(sensitiveEnd - sensitiveStart) * plot.width,
      height: plot.height
    )
    context.setFillColor(
      NSColor(calibratedRed: 1, green: 0.55, blue: 0.16, alpha: 0.13).cgColor
    )
    context.fill(sensitiveRect)
    context.setStrokeColor(
      NSColor(calibratedRed: 1, green: 0.64, blue: 0.22, alpha: 0.60).cgColor
    )
    context.setLineWidth(0.8 * scale)
    context.stroke(sensitiveRect)
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
        let y =
          plot.minY
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
      history.computed,
      color: NSColor(calibratedRed: 0.45, green: 1, blue: 0.72, alpha: 0.92),
      width: 1.65
    )
    if let currentTime {
      let marker = min(
        max((currentTime - startTime) / (endTime - startTime), 0),
        1
      )
      let markerX = plot.minX + CGFloat(marker) * plot.width
      context.setStrokeColor(
        NSColor(calibratedRed: 1, green: 0.63, blue: 0.22, alpha: 0.85).cgColor
      )
      context.setLineWidth(1 * scale)
      context.move(to: CGPoint(x: markerX, y: plot.minY))
      context.addLine(to: CGPoint(x: markerX, y: plot.maxY))
      context.strokePath()
    }

    drawLegendDot(
      "MEASURED",
      color: NSColor(calibratedWhite: 0.93, alpha: 1),
      x: rect.minX + 15 * scale,
      y: rect.minY + 14 * scale,
      scale: scale,
      context: context
    )
    drawLegendDot(
      "D32 RR3",
      color: NSColor(calibratedRed: 0.45, green: 1, blue: 0.72, alpha: 1),
      x: rect.minX + 103 * scale,
      y: rect.minY + 14 * scale,
      scale: scale,
      context: context
    )
    drawText(
      String(format: "NRMS %.3f", history.normalizedRMSError),
      font: systemFont(.userFixedPitch, size: 8.8 * scale),
      color: NSColor(calibratedWhite: 0.78, alpha: 1).cgColor,
      position: CGPoint(x: rect.maxX - 84 * scale, y: rect.minY + 11 * scale),
      context: context
    )
    drawText(
      "25–30 ms TARGET",
      font: systemFont(.userFixedPitch, size: 7.4 * scale),
      color: NSColor(
        calibratedRed: 1,
        green: 0.70,
        blue: 0.30,
        alpha: 1
      ).cgColor,
      position: CGPoint(x: rect.maxX - 89 * scale, y: rect.maxY - 23 * scale),
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

  private static func drawProgressRail(
    in rect: NSRect,
    context: CGContext,
    scale: CGFloat
  ) {
    fillPanel(rect, radius: 12 * scale, context: context)
    drawText(
      "VALIDATION PROGRESS",
      font: systemFont(.emphasizedSystem, size: 10 * scale),
      color: NSColor.white.cgColor,
      position: CGPoint(x: rect.minX + 14 * scale, y: rect.minY + 32 * scale),
      tracking: 0.38 * scale,
      context: context
    )
    drawText(
      "SOURCE-VISCOSITY LADDER",
      font: systemFont(.userFixedPitch, size: 7.8 * scale),
      color: NSColor(calibratedWhite: 0.60, alpha: 1).cgColor,
      position: CGPoint(x: rect.minX + 14 * scale, y: rect.minY + 13 * scale),
      context: context
    )

    let labels = [
      "SOURCE", "D16 A/B", "D28", "D32", "TARGET", "DIRECTION", "PAIR OPEN",
    ]
    let colors = [
      NSColor(calibratedRed: 0.28, green: 0.90, blue: 0.78, alpha: 1),
      NSColor(calibratedRed: 0.24, green: 0.70, blue: 1, alpha: 1),
      NSColor(calibratedRed: 0.64, green: 0.55, blue: 1, alpha: 1),
      NSColor(calibratedRed: 0.43, green: 1, blue: 0.72, alpha: 1),
      NSColor(calibratedRed: 0.20, green: 0.88, blue: 0.92, alpha: 1),
      NSColor(calibratedRed: 0.35, green: 0.96, blue: 0.72, alpha: 1),
      NSColor(calibratedRed: 1, green: 0.65, blue: 0.24, alpha: 1),
    ]
    let startX = rect.minX + 174 * scale
    let endX = rect.maxX - 38 * scale
    let nodeY = rect.minY + 34 * scale
    context.setStrokeColor(
      NSColor(calibratedRed: 0.28, green: 0.70, blue: 0.82, alpha: 0.30).cgColor
    )
    context.setLineWidth(1.2 * scale)
    context.move(to: CGPoint(x: startX, y: nodeY))
    context.addLine(to: CGPoint(x: endX, y: nodeY))
    context.strokePath()
    for index in labels.indices {
      let fraction = CGFloat(index) / CGFloat(labels.count - 1)
      let x = startX + fraction * (endX - startX)
      context.setFillColor(colors[index].cgColor)
      context.fillEllipse(
        in: NSRect(
          x: x - 4 * scale,
          y: nodeY - 4 * scale,
          width: 8 * scale,
          height: 8 * scale
        )
      )
      context.setStrokeColor(
        NSColor(calibratedWhite: 1, alpha: 0.34).cgColor
      )
      context.setLineWidth(1 * scale)
      context.strokeEllipse(
        in: NSRect(
          x: x - 6.5 * scale,
          y: nodeY - 6.5 * scale,
          width: 13 * scale,
          height: 13 * scale
        )
      )
      let labelLine = textLine(
        labels[index],
        font: systemFont(.userFixedPitch, size: 7.5 * scale),
        color: NSColor(calibratedWhite: 0.82, alpha: 1).cgColor
      )
      let labelWidth = CGFloat(
        CTLineGetTypographicBounds(labelLine, nil, nil, nil)
      )
      context.textPosition = CGPoint(
        x: x - 0.5 * labelWidth,
        y: rect.minY + 10 * scale
      )
      CTLineDraw(labelLine, context)
    }
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
          NSAttributedString.Key(kCTKernAttributeName as String): tracking,
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
    loop: MeasuredDovePresentationLoop,
    phase: Float,
    camera: CameraState,
    width: Int,
    height: Int
  ) throws -> MTLTexture {
    let surface = surfaceVertices(loop: loop, phase: phase)
    let ghosts = ghostVertices(
      loop: loop,
      phase: phase
    )
    let trails = trailVertices(
      loop: loop,
      phase: phase,
      camera: camera
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
      phase,
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

  private func surfaceVertices(
    loop: MeasuredDovePresentationLoop,
    phase: Float
  ) -> [ColoredVertex] {
    let states = (0..<dataset.vertexCount).map {
      loop.point(phase: phase, vertexIndex: $0)
    }
    var result: [ColoredVertex] = []
    result.reserveCapacity(dataset.triangleCount * 3)
    for triangleIndex in 0..<dataset.triangleCount {
      let triangle = dataset.triangle(triangleIndex)
      let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
      let points = indices.map { states[$0].position }
      let rawNormal = simd_cross(points[1] - points[0], points[2] - points[0])
      let normal =
        simd_length_squared(rawNormal) > 1e-16
        ? simd_normalize(rawNormal)
        : SIMD3<Float>(0, 0, 1)
      let speed =
        indices.reduce(Float.zero) {
          $0 + simd_length(states[$1].velocity)
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
    loop: MeasuredDovePresentationLoop,
    phase: Float
  ) -> [ColoredVertex] {
    var result: [ColoredVertex] = []
    for ghostIndex in 1...2 {
      let ghostPhase = loop.phase(
        offsetBy: -Float(ghostIndex) * 0.006,
        from: phase
      )
      let alpha = Float(0.075 / Double(ghostIndex))
      for triangleIndex in 0..<dataset.triangleCount {
        let part = dataset.trianglePartIdentifiers[triangleIndex]
        guard part == 2 || part == 3 else { continue }
        let triangle = dataset.triangle(triangleIndex)
        let indices = [Int(triangle.x), Int(triangle.y), Int(triangle.z)]
        let points = indices.map {
          loop.point(phase: ghostPhase, vertexIndex: $0).position
        }
        let rawNormal = simd_cross(points[1] - points[0], points[2] - points[0])
        let normal =
          simd_length_squared(rawNormal) > 1e-16
          ? simd_normalize(rawNormal)
          : SIMD3<Float>(0, 0, 1)
        let rgb =
          part == 2
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
    loop: MeasuredDovePresentationLoop,
    phase: Float,
    camera: CameraState
  ) -> [[ColoredVertex]] {
    wingtipIndices.enumerated().flatMap { trailIndex, vertexIndex in
      let sampleCount = 24
      var points: [SIMD3<Float>] = []
      for sample in stride(from: sampleCount - 1, through: 0, by: -1) {
        let samplePhase = loop.phase(
          offsetBy: -Float(sample) * 0.0014,
          from: phase
        )
        points.append(
          loop.point(phase: samplePhase, vertexIndex: vertexIndex).position
        )
      }
      let rgb =
        trailIndex == 0
        ? SIMD3<Float>(0.12, 0.76, 1)
        : SIMD3<Float>(1, 0.39, 0.15)
      return [
        makeTrailVertices(
          points: points,
          rgb: rgb,
          camera: camera,
          baseWidth: 0.00045,
          tipWidth: 0.0024,
          peakAlpha: 0.14
        ),
        makeTrailVertices(
          points: points,
          rgb: rgb,
          camera: camera,
          baseWidth: 0.00016,
          tipWidth: 0.00072,
          peakAlpha: 0.82
        ),
      ]
    }
  }

  private func makeTrailVertices(
    points: [SIMD3<Float>],
    rgb: SIMD3<Float>,
    camera: CameraState,
    baseWidth: Float,
    tipWidth: Float,
    peakAlpha: Float
  ) -> [ColoredVertex] {
    var vertices: [ColoredVertex] = []
    vertices.reserveCapacity(points.count * 2)
    for index in points.indices {
      let previous = points[max(index - 1, 0)]
      let next = points[min(index + 1, points.count - 1)]
      let tangent = simd_normalize(next - previous + SIMD3<Float>(1e-8, 0, 0))
      let view = simd_normalize(camera.eye - points[index])
      let rawLateral = simd_cross(view, tangent)
      let lateral =
        simd_length_squared(rawLateral) > 1e-12
        ? simd_normalize(rawLateral)
        : SIMD3<Float>(0, 0, 1)
      let age = Float(index) / Float(points.count - 1)
      let width = baseWidth + tipWidth * age
      let color = SIMD4<Float>(rgb, peakAlpha * age * age)
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
      guard
        let wing = dataset.components.first(where: {
          $0.partIdentifier == identifier
        })
      else { return nil }
      return (wing.vertexOffset..<(wing.vertexOffset + wing.vertexCount)).max {
        simd_distance_squared(
          dataset.vertex(frame: referenceFrame, index: $0),
          bodyCenter
        )
          < simd_distance_squared(
            dataset.vertex(frame: referenceFrame, index: $1),
            bodyCenter
          )
      }
    }
  }
}

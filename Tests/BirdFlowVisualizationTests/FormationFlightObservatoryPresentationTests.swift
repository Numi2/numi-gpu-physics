import BirdFlowMetal
import Foundation
import Metal
import Testing

@testable import BirdFlowVisualization

@Test("formation presentation uses sagittal bilateral reflection")
func formationPresentationUsesSagittalReflection() throws {
  let value = SIMD3<Float>(2, 3, 4)
  #expect(
    FormationObservatoryRenderer.bilateralReflection(value)
      == SIMD3<Float>(-2, 3, 4)
  )
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let renderer = try FormationObservatoryRenderer(device: device)
  let audit = renderer.bilateralPresentationAudit(
    phases: (0..<48).map { Float($0) / 48 },
    flyerPairPhaseOffsetCycles: 0.25
  )
  #expect(audit.passed)
  #expect(audit.phaseCountPerFlyer == 48)
  #expect(audit.flyerCount == 2)
  #expect(audit.vertexPairsCompared > 30_000)
  #expect(audit.maximumPositionReflectionResidual <= 1e-6)
  #expect(audit.maximumNormalReflectionResidual <= 1e-6)
  #expect(audit.maximumWithinFlyerPhaseDifferenceCycles == 0)
  #expect(audit.flyerPairPhaseOffsetCycles == 0.25)
}

@Test("formation presentation uses the locked dual-dove surface loop")
func formationPresentationUsesLockedDualDove() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let manifest = repository.appendingPathComponent(
    "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
  )
  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: manifest
  )
  let renderer = try FormationObservatoryRenderer(
    device: device,
    doveDataset: dataset
  )
  let audit = renderer.dovePresentationAudit(
    flyerPairPhaseOffsetCycles: 0.25,
    archivedFlowSliceCount: 21,
    capturePhaseCount: 48,
    capturePhasesWithVisibleFlow: 48,
    minimumFlowOpacity: 1,
    focusedSourceTraceSampleCount: 4_820,
    focusedSourceTraceDirectionIndex: 5,
    wakeBridgePhaseCount: 48
  )
  #expect(audit.passed)
  #expect(audit.schemaVersion == 5)
  #expect(audit.flyerCount == 2)
  #expect(audit.vertexCountPerFlyer == 2_157)
  #expect(audit.triangleCountPerFlyer == 3_968)
  #expect(audit.componentNames == ["body", "leftWing", "rightWing", "tail"])
  #expect(audit.endpointMaximumPositionResidual == 0)
  #expect(
    audit.flowDisplayMode
      == "cyclic-linear-interpolation-of-archived-c20-phases"
  )
  #expect(audit.capturePhasesWithVisibleFlow == audit.capturePhaseCount)
  #expect(audit.minimumFlowOpacity == 1)
  #expect(
    audit.flowSpatialFilterMode
      == "gaussian-radius4-sigma2-with-solid-gap-fill-presentation-only"
  )
  #expect(
    audit.flowOpacityMode
      == "joint-vorticity-and-vertical-velocity-signal"
  )
  #expect(audit.minimumDisplayedSignalOpacity == 0.025)
  #expect(
    audit.wakeBridgeMode
      == "archived-c20-vorticity-ridge+c18-q5-luminance"
  )
  #expect(
    audit.wakeIntersectionMarkerMode
      == "presentation-phase-ring-at-follower-plane"
  )
  #expect(audit.focusedSourceTraceSampleCount == 4_820)
  #expect(audit.focusedSourceTraceDirectionIndex == 5)
  #expect(audit.wakeBridgePhaseCount == audit.capturePhaseCount)
  #expect(audit.overlayMode == "none-cinematic")
  #expect(
    audit.cameraCompositionMode
      == "spherical-figure-eight-dual-dove-wake-bridge"
  )
  #expect(audit.cameraYawAmplitudeRadians == 0.34)
  #expect(audit.cameraPitchAmplitudeRadians == 0.10)
  #expect(audit.cameraDistanceAmplitudeChords == 0.10)
  #expect(audit.cameraEndpointParameterResidual == 0)
  #expect(audit.tailScale[1] < 0.5 * audit.bodyAndWingScale[1])
  #expect(audit.presentationOnly)
  #expect(!audit.quantitativeForceAcceptanceReady)
}

@Test("formation flow opacity preserves a low-vorticity velocity jet")
func formationFlowOpacityPreservesVelocityJet() {
  let velocityOnly = FormationObservatoryRenderer.flowPresentationOpacity(
    normalizedVorticity: 0,
    normalizedVerticalVelocity: 1
  )
  let vorticityOnly = FormationObservatoryRenderer.flowPresentationOpacity(
    normalizedVorticity: 1,
    normalizedVerticalVelocity: 0
  )
  let combined = FormationObservatoryRenderer.flowPresentationOpacity(
    normalizedVorticity: 1,
    normalizedVerticalVelocity: 1
  )
  #expect(abs(velocityOnly - 0.125) < 1e-6)
  #expect(abs(vorticityOnly - 0.205) < 1e-6)
  #expect(abs(combined - 0.305) < 1e-6)
}

@Test("formation flow presentation closes narrow low-signal display seams")
func formationFlowPresentationClosesNarrowDisplaySeams() throws {
  let width = 9
  let height = 9
  var vorticity = [Float](repeating: 1, count: width * height)
  var ownerMask = [UInt8](repeating: 0, count: width * height)
  for z in 0..<height {
    vorticity[4 + width * z] = 0
    ownerMask[4 + width * z] = 1
  }
  let slice = FormationFlightFlowSlice(
    schemaVersion: 1,
    plane: "y",
    planeIndex: 0,
    width: width,
    height: height,
    chordCells: 20,
    phase: 0,
    velocityUnits: "m/s",
    vorticityUnits: "1/s",
    maximumVorticityMagnitudePerSecond: 1,
    maximumAbsoluteVerticalVelocityMetersPerSecond: 1,
    vorticityMagnitudePerSecond: vorticity,
    verticalVelocityMetersPerSecond: [Float](
      repeating: -1,
      count: width * height
    ),
    ownerMask: ownerMask
  )
  let smoothed = try #require(
    FormationObservatoryRenderer.presentationSmoothedFlowValues(slice)
  )
  #expect(vorticity[4 + width * 4] == 0)
  #expect(smoothed.vorticity[4 + width * 4] > 0.75)
  #expect(smoothed.verticalVelocity[4 + width * 4] == -1)
}

@Test("formation camera follows a seamless two-lobe figure eight")
func formationCameraFollowsFigureEight() {
  let seamStart = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0)
  let seamEnd = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 1)
  let firstUpperLobe = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.125)
  let firstLowerLobe = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.375)
  let secondUpperLobe = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.625)
  let secondLowerLobe = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.875)
  let rightExtreme = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.25)
  let leftExtreme = FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.75)
  #expect(seamStart == seamEnd)
  #expect(rightExtreme.x - leftExtreme.x > 0.67)
  #expect(firstUpperLobe.y > seamStart.y)
  #expect(firstLowerLobe.y < seamStart.y)
  #expect(secondUpperLobe.y > seamStart.y)
  #expect(secondLowerLobe.y < seamStart.y)
  #expect(seamStart.z > FormationObservatoryRenderer
    .figureEightCameraParameters(phase: 0.5).z)
}

@Test("formation wake bridge luminance follows the locked q5 trace")
func formationWakeBridgeUsesFocusedQ5Trace() throws {
  let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let reportURL = repository.appendingPathComponent(
    "ValidationArtifacts/formation-flight-focused-source-trace/formation-flight-focused-source-trace-report.json"
  )
  let report = try JSONDecoder().decode(
    FormationFlightFocusedBoundarySourceTraceReport.self,
    from: Data(contentsOf: reportURL)
  )
  let seam = FormationFlightObservatoryCapture.focusedSourceIntensity(
    report,
    leaderPhase: 0
  )
  let repeatedSeam = FormationFlightObservatoryCapture
    .focusedSourceIntensity(report, leaderPhase: 1)
  let quarter = FormationFlightObservatoryCapture.focusedSourceIntensity(
    report,
    leaderPhase: 0.25
  )
  #expect(report.gates.passed)
  #expect(report.directionIndex == 5)
  #expect(report.samples.count == 4_820)
  #expect(seam == repeatedSeam)
  #expect(seam >= 0 && seam < 0.01)
  #expect(quarter > 0.80 && quarter <= 1)
}

@Test("formation CFD presentation interpolates cyclically without a seam")
func formationCFDPresentationInterpolatesCyclically() throws {
  func slice(
    phase: Double,
    vorticity: Float,
    verticalVelocity: Float,
    owner: UInt8
  ) -> FormationFlightFlowSlice {
    FormationFlightFlowSlice(
      schemaVersion: 1,
      plane: "y",
      planeIndex: 0,
      width: 1,
      height: 1,
      chordCells: 20,
      phase: phase,
      velocityUnits: "m/s",
      vorticityUnits: "1/s",
      maximumVorticityMagnitudePerSecond: vorticity,
      maximumAbsoluteVerticalVelocityMetersPerSecond: abs(verticalVelocity),
      vorticityMagnitudePerSecond: [vorticity],
      verticalVelocityMetersPerSecond: [verticalVelocity],
      ownerMask: [owner]
    )
  }
  let phaseZero = slice(
    phase: 0,
    vorticity: 2,
    verticalVelocity: -2,
    owner: 0
  )
  let phaseHalf = slice(
    phase: 0.5,
    vorticity: 6,
    verticalVelocity: 2,
    owner: 1
  )
  let slices = [phaseHalf, phaseZero]
  let firstMidpoint = try #require(
    FormationFlightObservatoryCapture.interpolatedFlowSlice(
      slices,
      leaderPhase: 0.25
    )
  )
  let wrapMidpoint = try #require(
    FormationFlightObservatoryCapture.interpolatedFlowSlice(
      slices,
      leaderPhase: 0.75
    )
  )
  let seam = try #require(
    FormationFlightObservatoryCapture.interpolatedFlowSlice(
      slices,
      leaderPhase: 1
    )
  )
  #expect(firstMidpoint.vorticityMagnitudePerSecond == [4])
  #expect(firstMidpoint.verticalVelocityMetersPerSecond == [0])
  #expect(firstMidpoint.ownerMask == [1])
  #expect(wrapMidpoint.vorticityMagnitudePerSecond == [4])
  #expect(wrapMidpoint.verticalVelocityMetersPerSecond == [0])
  #expect(wrapMidpoint.ownerMask == [0])
  #expect(seam.phase == 0)
  #expect(seam.vorticityMagnitudePerSecond == [2])
}

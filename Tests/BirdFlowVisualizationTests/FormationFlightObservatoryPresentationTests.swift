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
    minimumFlowOpacity: 1
  )
  #expect(audit.passed)
  #expect(audit.flyerCount == 2)
  #expect(audit.vertexCountPerFlyer == 2_157)
  #expect(audit.triangleCountPerFlyer == 3_968)
  #expect(audit.componentNames == ["body", "leftWing", "rightWing", "tail"])
  #expect(audit.endpointMaximumPositionResidual == 0)
  #expect(audit.flowDisplayMode == "nearest-archived-phase-hold")
  #expect(audit.capturePhasesWithVisibleFlow == audit.capturePhaseCount)
  #expect(audit.minimumFlowOpacity == 1)
  #expect(audit.tailScale[1] < 0.5 * audit.bodyAndWingScale[1])
  #expect(audit.presentationOnly)
  #expect(!audit.quantitativeForceAcceptanceReady)
}

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

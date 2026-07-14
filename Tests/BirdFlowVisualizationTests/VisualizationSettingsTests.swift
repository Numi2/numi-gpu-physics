import Foundation
import Testing

@testable import BirdFlowVisualization

@Test("visualization settings round trip")
func visualizationSettingsRoundTrip() throws {
  var source = VisualizationSettings()
  source.sliceSnap = .oblique
  source.sliceYawRadians = 0.37
  source.showQCriterion = true
  source.camera.distance = 2.25

  let data = try JSONEncoder().encode(source)
  let decoded = try JSONDecoder().decode(
    VisualizationSettings.self,
    from: data
  )
  #expect(decoded == source)
}

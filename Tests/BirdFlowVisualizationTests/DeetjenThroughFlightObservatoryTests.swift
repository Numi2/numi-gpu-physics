import AppKit
import BirdFlowMetal
import Foundation
import Testing
import simd

@testable import BirdFlowVisualization

private var deetjenRepositoryRoot: URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
}

@Test("through-flight timeline preserves raw laboratory translation")
func throughFlightTimelinePreservesRawTranslation() throws {
  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: deetjenRepositoryRoot.appendingPathComponent(
      "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
    )
  )
  let timeline = MeasuredDoveThroughFlightTimeline(dataset: dataset)
  #expect(abs(timeline.durationSeconds - 0.143) <= 1e-7)
  #expect(timeline.sourceFrameCoordinate(progress: 0) == 0)
  #expect(abs(timeline.sourceFrameCoordinate(progress: 1) - 143) <= 1e-4)
  #expect(timeline.phase(offsetBy: -1, from: 0.5) == 0)
  #expect(timeline.phase(offsetBy: 1, from: 0.5) == 1)

  let body = dataset.components.first { $0.partIdentifier == 1 }!
  func bodyCenter(progress: Float) -> SIMD3<Float> {
    var center = SIMD3<Float>.zero
    for vertex in body.vertexOffset..<(body.vertexOffset + body.vertexCount) {
      center += timeline.point(phase: progress, vertexIndex: vertex).position
    }
    return center / Float(body.vertexCount)
  }
  let displacement = bodyCenter(progress: 1) - bodyCenter(progress: 0)
  #expect(abs(displacement.x - 0.187_064) <= 2e-6)
  #expect(abs(displacement.y - 0.044_940_2) <= 2e-6)
  #expect(abs(displacement.z + 0.008_276_66) <= 2e-6)
}

@Test("through-flight observatory renders artifact-locked distinct endpoints")
func throughFlightObservatoryRendersEvidenceLockedFrames() throws {
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "birdflow-deetjen-observatory-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: output) }
  let arguments = try DeetjenThroughFlightObservatoryCapture.Arguments(
    commandLine: [
      "birdflow-viewer",
      "--capture-deetjen-through-flight", output.path,
      "--capture-deetjen-manifest",
      deetjenRepositoryRoot.appendingPathComponent(
        "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
      ).path,
      "--capture-deetjen-report",
      deetjenRepositoryRoot.appendingPathComponent(
        "ValidationArtifacts/deetjen-dove-through-flight-v1.json"
      ).path,
      "--capture-width", "640",
      "--capture-height", "360",
      "--capture-frames", "2",
    ]
  )
  try DeetjenThroughFlightObservatoryCapture.run(arguments)

  let firstData = try Data(
    contentsOf: output.appendingPathComponent("frame-000.png")
  )
  let lastData = try Data(
    contentsOf: output.appendingPathComponent("frame-001.png")
  )
  #expect(firstData != lastData)
  #expect(NSBitmapImageRep(data: firstData)?.pixelsWide == 640)
  #expect(NSBitmapImageRep(data: lastData)?.pixelsHigh == 360)

  let audit = try JSONDecoder().decode(
    DeetjenThroughFlightObservatoryAudit.self,
    from: Data(
      contentsOf: output.appendingPathComponent("observatory-audit.json")
    )
  )
  #expect(audit.passed)
  #expect(audit.rawLaboratoryFrameGeometry)
  #expect(audit.trajectorySampleCount == 144)
  #expect(audit.maximumTrajectoryCenterResidualMeters <= 1e-7)
  #expect(audit.wakeFieldArchivePassed)
  #expect(audit.wakeSliceCount == 26)
  #expect(audit.wakeRenderedFrameCount == 1)
  #expect(audit.wakeVorticityDisplayScalePerSecond > 0)
  #expect(audit.wakePositiveQDisplayScalePerSecondSquared > 0)
  #expect(audit.completedFluidSteps == audit.plannedFluidSteps)
  #expect(audit.minimumSampledPopulation > 0)
}

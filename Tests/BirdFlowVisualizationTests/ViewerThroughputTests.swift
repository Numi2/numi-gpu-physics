import BirdFlowCore
import BirdFlowMetal
import Foundation
import Metal
import Testing

@testable import BirdFlowVisualization

@Test("document baseline versus active-viewer throughput without solver waits")
func viewerThroughputBenchmark() throws {
  guard MTLCreateSystemDefaultDevice() != nil else { return }
  let bird = BirdParameters(
    bodyRadiiMeters: SIMD3<Float>(0.015, 0.011, 0.012),
    massKilograms: 0.025,
    principalInertiaKilogramMetersSquared: SIMD3<Float>(4e-6, 7e-6, 8e-6),
    wingSpanMeters: 0.025,
    wingRootChordMeters: 0.020,
    wingTipChordMeters: 0.012,
    wingThicknessMeters: 0.008,
    wingSweepMeters: 0.004,
    wingRootOffsetMeters: SIMD3<Float>(0, 0.010, 0.003),
    tailLengthMeters: 0.020,
    tailHalfWidthMeters: 0.014,
    tailThicknessMeters: 0.008,
    wingKinematics: WingKinematics(
      frequencyHz: 3,
      strokeAmplitudeRadians: 0.25,
      pitchMeanRadians: 0,
      pitchAmplitudeRadians: 0.15,
      pitchPhaseRadians: 0.4
    )
  )
  let grid = try GridSize(x: 48, y: 48, z: 48)
  let scaling = try LatticeScaling(
    characteristicLengthMeters: bird.wingRootChordMeters,
    characteristicLengthCells: 8,
    referenceSpeedMetersPerSecond: 1,
    targetReynoldsNumber: 100,
    physicalAirDensity: 1.225,
    latticeReferenceSpeed: 0.03
  )
  let configuration = try SimulationConfiguration(
    grid: grid,
    domainOriginMeters: .zero,
    scaling: scaling,
    farFieldVelocityMetersPerSecond: SIMD3<Float>(-1, 0, 0),
    spongeWidthCells: 4,
    spongeStrength: 0.04
  )
  let state = BirdBodyState(positionMeters: configuration.domainSizeMeters * 0.5)
  let steps = 24
  let batch = 4

  let baseline = try BirdFlowSimulation(
    configuration: configuration,
    bird: bird,
    initialBodyState: state
  )
  let baselineStart = Date()
  try baseline.advance(
    steps: steps,
    batchSize: batch,
    fieldCapture: .disabled
  )
  let baselineSeconds = Date().timeIntervalSince(baselineStart)

  let live = try LiveSimulation(
    configuration: configuration,
    bird: bird,
    initialBodyState: state,
    batchSize: batch
  )
  defer { live.stop() }
  let renderer = try MetalVisualizationRenderer(liveSimulation: live)
  var camera = CameraState()
  camera.target = configuration.domainSizeMeters * 0.5
  camera.distance = 0.18
  renderer.camera = camera
  _ = try renderer.renderOffscreen(width: 320, height: 240)
  let viewerStart = Date()
  for _ in stride(from: 0, to: steps, by: batch) {
    try live.simulation.advance(
      steps: batch,
      batchSize: batch,
      fieldCapture: .bestEffort
    )
    _ = try renderer.renderOffscreen(width: 320, height: 240)
  }
  let viewerSeconds = Date().timeIntervalSince(viewerStart)
  let baselineRate = Double(steps) / max(baselineSeconds, 1e-9)
  let viewerRate = Double(steps) / max(viewerSeconds, 1e-9)
  print(
    String(
      format:
        "viewer-throughput: baseline=%.1f step/s active-viewer=%.1f step/s contention=%.1f%% waits=%llu drops=%llu",
      baselineRate,
      viewerRate,
      100 * (1 - viewerRate / baselineRate),
      live.simulation.fieldCaptureWaitCount,
      live.simulation.droppedFieldFrameCount
    ))
  #expect(live.simulation.fieldCaptureWaitCount == 0)
  #expect(live.simulation.stepIndex == UInt64(steps))
  #expect(baseline.stepIndex == UInt64(steps))
}

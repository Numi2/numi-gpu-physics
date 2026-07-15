import BirdFlowCore
import BirdFlowMetal
import Metal
import Testing

@testable import BirdFlowVisualization

@Test("offscreen pressure and slice render is finite and nonempty")
func offscreenViewerProducesPixels() throws {
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
  let live = try LiveSimulation(
    configuration: configuration,
    bird: bird,
    initialBodyState: BirdBodyState(
      positionMeters: configuration.domainSizeMeters * 0.5
    ),
    batchSize: 1
  )
  defer { live.stop() }
  let renderer = try MetalVisualizationRenderer(liveSimulation: live)
  var settings = VisualizationSettings()
  settings.showRibbons = false
  settings.showQCriterion = false
  renderer.settings = settings
  var camera = CameraState()
  camera.target = configuration.domainSizeMeters * 0.5
  camera.distance = 0.18
  camera.yaw = -0.7
  camera.pitch = 0.32
  renderer.camera = camera

  let texture = try renderer.renderOffscreen(width: 256, height: 192)
  var pixels = [UInt8](repeating: 0, count: 256 * 192 * 4)
  texture.getBytes(
    &pixels,
    bytesPerRow: 256 * 4,
    from: MTLRegionMake2D(0, 0, 256, 192),
    mipmapLevel: 0
  )
  let first = Array(pixels[0..<4])
  var changed = 0
  for index in stride(from: 0, to: pixels.count, by: 4) {
    if Array(pixels[index..<(index + 4)]) != first { changed += 1 }
  }
  #expect(changed > 200)

  _ = try live.simulation.advance(
    steps: 40,
    batchSize: 20,
    fieldCapture: .required
  )
  let laterTexture = try renderer.renderOffscreen(width: 256, height: 192)
  var laterPixels = [UInt8](repeating: 0, count: pixels.count)
  laterTexture.getBytes(
    &laterPixels,
    bytesPerRow: 256 * 4,
    from: MTLRegionMake2D(0, 0, 256, 192),
    mipmapLevel: 0
  )
  let changedBetweenFrames = zip(pixels, laterPixels).filter {
    $0.0 != $0.1
  }.count
  let diagnostics = renderer.offscreenDiagnostics()
  #expect(changedBetweenFrames > 200)
  #expect(diagnostics.maximumAbsolutePressure.isFinite)
  #expect(diagnostics.maximumQCriterion.isFinite)
  #expect(!diagnostics.qSurfaceOverflow)
}

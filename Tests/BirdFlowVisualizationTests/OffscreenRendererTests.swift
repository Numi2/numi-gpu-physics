import AppKit
import BirdFlowCore
import BirdFlowMetal
import Metal
import Testing
import simd

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

@Test("measured dove README capture is artifact-locked and seamless")
func measuredDoveShowcaseCaptureClosesLoop() throws {
  guard MTLCreateSystemDefaultDevice() != nil else { return }
  let testFile = URL(fileURLWithPath: #filePath)
  let root = testFile.deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let output = FileManager.default.temporaryDirectory.appendingPathComponent(
    "birdflow-dove-showcase-\(UUID().uuidString)",
    isDirectory: true
  )
  defer { try? FileManager.default.removeItem(at: output) }
  let arguments = try ReadmeShowcaseCapture.Arguments(commandLine: [
    "birdflow-viewer",
    "--capture-readme-frames", output.path,
    "--capture-width", "320",
    "--capture-height", "180",
    "--capture-frames", "2",
    "--capture-dove-manifest",
    root.appendingPathComponent(
      "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
    ).path,
    "--capture-dove-d32-full-window",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window.json"
    ).path,
    "--capture-dove-d32-full-window-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window-audit.json"
    ).path,
    "--capture-dove-d28-d32-refinement",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d28-d32-refinement.json"
    ).path,
    "--capture-dove-d28-d32-phase-localization",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d28-d32-phase-localization.json"
    ).path,
    "--capture-dove-d28-d32-phase-localization-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-d28-d32-phase-localization-audit.json"
    ).path,
    "--capture-dove-targeted-boundary-d28",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-d28.json"
    ).path,
    "--capture-dove-targeted-boundary-d32",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-d32.json"
    ).path,
    "--capture-dove-targeted-boundary-attribution",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary.json"
    ).path,
    "--capture-dove-targeted-boundary-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-audit.json"
    ).path,
    "--capture-dove-reflected-provenance-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-preregistration.json"
    ).path,
    "--capture-dove-reflected-provenance-d28",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-d28.json"
    ).path,
    "--capture-dove-reflected-provenance-d32",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-d32.json"
    ).path,
    "--capture-dove-reflected-provenance-attribution",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance.json"
    ).path,
    "--capture-dove-reflected-provenance-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-source-viscosity-reflected-provenance-audit.json"
    ).path,
    "--capture-dove-link-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-link-composition-discriminator-preregistration.json"
    ).path,
    "--capture-dove-link-composition-attribution",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-link-composition-discriminator.json"
    ).path,
    "--capture-dove-link-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-link-composition-discriminator-audit.json"
    ).path,
    "--capture-dove-direction-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-direction-composition-canonical-preregistration.json"
    ).path,
    "--capture-dove-direction-composition-canonical",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-direction-composition-canonical.json"
    ).path,
    "--capture-dove-direction-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-direction-composition-canonical-audit.json"
    ).path,
    "--capture-dove-link-geometry-report",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json"
    ).path,
    "--capture-dove-curved-direction-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-curved-direction-composition-canonical-preregistration.json"
    ).path,
    "--capture-dove-curved-direction-composition-canonical",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-curved-direction-composition-canonical.json"
    ).path,
    "--capture-dove-curved-direction-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-curved-direction-composition-canonical-audit.json"
    ).path,
    "--capture-dove-fine-direction-composition-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-preregistration.json"
    ).path,
    "--capture-dove-fine-direction-composition-census",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-census.json"
    ).path,
    "--capture-dove-fine-direction-composition-discriminator",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-discriminator.json"
    ).path,
    "--capture-dove-fine-direction-composition-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-composition-audit.json"
    ).path,
    "--capture-dove-fine-direction-phase-v1-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json"
    ).path,
    "--capture-dove-fine-direction-phase-v1-failure",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json"
    ).path,
    "--capture-dove-fine-direction-phase-preregistration",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-preregistration.json"
    ).path,
    "--capture-dove-fine-direction-phase-census",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-census.json"
    ).path,
    "--capture-dove-fine-direction-phase-discriminator",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-discriminator.json"
    ).path,
    "--capture-dove-fine-direction-phase-audit",
    root.appendingPathComponent(
      "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-audit.json"
    ).path,
  ])
  try ReadmeShowcaseCapture.run(arguments)
  let firstData = try Data(
    contentsOf: output.appendingPathComponent("frame-000.png")
  )
  let lastData = try Data(
    contentsOf: output.appendingPathComponent("frame-001.png")
  )
  guard let image = NSBitmapImageRep(data: firstData) else {
    Issue.record("captured measured-dove frame is not a decodable PNG")
    return
  }
  #expect(image.pixelsWide == 320)
  #expect(image.pixelsHigh == 180)
  #expect(firstData == lastData)

  let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
    manifestURL: root.appendingPathComponent(
      "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
    )
  )
  let loop = MeasuredDovePresentationLoop(dataset: dataset)
  #expect(abs(loop.measuredDurationSeconds - 0.094) < 1e-6)
  #expect(abs(loop.periodSeconds - 0.108) < 1e-6)
  let measuredFrames = (0..<100).compactMap { index in
    loop.sourceFrameCoordinate(phase: Float(index) / 100)
  }
  #expect(measuredFrames.first == 27)
  #expect(measuredFrames.allSatisfy { $0 >= 27 && $0 <= 121 })
  #expect(
    zip(measuredFrames, measuredFrames.dropFirst()).allSatisfy {
      $0.0 <= $0.1
    }
  )
  #expect(loop.sourceFrameCoordinate(phase: 0.95) == nil)
  for vertexIndex in [0, 1_443, 1_740, 2_037] {
    let first = loop.point(phase: 0, vertexIndex: vertexIndex)
    let wrapped = loop.point(phase: 1, vertexIndex: vertexIndex)
    #expect(simd_distance(first.position, wrapped.position) < 1e-7)
    #expect(simd_distance(first.velocity, wrapped.velocity) < 1e-5)
  }
  let displayFrameCount = 72
  let stepRMS = (0..<displayFrameCount).map { frame -> Float in
    let phase = Float(frame) / Float(displayFrameCount)
    let nextPhase = Float(frame + 1) / Float(displayFrameCount)
    var squaredDisplacement: Float = 0
    for vertexIndex in 0..<dataset.vertexCount {
      let point = loop.point(phase: phase, vertexIndex: vertexIndex).position
      let next = loop.point(
        phase: nextPhase,
        vertexIndex: vertexIndex
      ).position
      squaredDisplacement += simd_distance_squared(point, next)
    }
    return sqrt(squaredDisplacement / Float(dataset.vertexCount))
  }
  let medianStep = stepRMS.sorted()[displayFrameCount / 2]
  #expect(stepRMS.last! < 1.5 * medianStep)
  #expect(stepRMS.last! <= stepRMS.dropLast().max()!)
}

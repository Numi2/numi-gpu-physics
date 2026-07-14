import BirdFlowCore
import BirdFlowMetal
import Foundation
import Testing

@testable import BirdFlowVisualization

@Test("run samples and visualization settings round trip without gaps")
func runBundleRoundTrip() throws {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("BirdFlow-run-\(UUID().uuidString).birdflowrun")
  defer { try? FileManager.default.removeItem(at: root) }
  let grid = try GridSize(x: 16, y: 16, z: 16)
  let scaling = try LatticeScaling(
    characteristicLengthMeters: 0.02,
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
    spongeWidthCells: 4
  )
  let recorder = try RunBundleRecorder(
    directory: root,
    configuration: configuration,
    bird: .demonstration,
    deviceName: "test-device"
  )
  let samples = (1...7).map { index in
    RunSample(
      step: UInt64(index),
      timeSeconds: Float(index) * 0.001,
      body: BirdBodyState(
        positionMeters: SIMD3<Float>(Float(index), 2, 3),
        orientationBodyToWorld: .identity,
        linearVelocityMetersPerSecond: SIMD3<Float>(1, 0, 0),
        angularVelocityBodyRadiansPerSecond: SIMD3<Float>(0, 0, 0.1)
      ),
      aerodynamicLoad: ForceTorque(
        forceNewtons: SIMD3<Float>(0.1, 0.2, Float(index)),
        torqueNewtonMeters: SIMD3<Float>(0, 0.01, 0)
      )
    )
  }
  #expect(recorder.append(Array(samples[0..<3])))
  #expect(recorder.append(Array(samples[3...])))
  var settings = VisualizationSettings()
  settings.sliceSnap = .oblique
  settings.camera.distance = 2.7
  settings.qColor = .qCriterion
  try recorder.save(settings: settings)
  try recorder.finish()

  #expect(try RunBundleReader.samples(from: root) == samples)
  #expect(try RunBundleReader.settings(from: root) == settings)

  let sampleURL = root.appendingPathComponent("samples.bin")
  var corrupt = try Data(contentsOf: sampleURL)
  corrupt.append(0xff)
  try corrupt.write(to: sampleURL)
  #expect(throws: RunBundleError.self) {
    _ = try RunBundleReader.samples(from: root)
  }
}

@Test("verified derived keyframes round trip and reject corruption")
func derivedKeyframeRoundTripAndCorruption() throws {
  let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("BirdFlow-derived-\(UUID().uuidString).bfdf")
  defer { try? FileManager.default.removeItem(at: root) }
  let grid = try GridSize(x: 16, y: 16, z: 16)
  let metadata = analyticMetadata(grid: grid, dx: 0.01)
  let vorticity = Data(repeating: 0x2a, count: grid.cellCount * 16)
  let q = Data(repeating: 0x11, count: grid.cellCount * 4)
  let valid = Data(repeating: 1, count: grid.cellCount)
  try DerivedFieldArchive.write(
    vorticity: vorticity,
    qCriterion: q,
    validMask: valid,
    metadata: metadata,
    to: root
  )
  let decoded = try RunBundleReader.derivedField(from: root)
  #expect(decoded.step == metadata.snapshot.step)
  #expect(decoded.grid == grid)
  #expect(decoded.vorticity == vorticity)
  #expect(decoded.qCriterion == q)
  #expect(decoded.validMask == valid)

  try Data([0, 1, 2, 3]).write(
    to: root.appendingPathComponent("q-float.lzfse")
  )
  #expect(throws: RunBundleError.self) {
    _ = try RunBundleReader.derivedField(from: root)
  }
}

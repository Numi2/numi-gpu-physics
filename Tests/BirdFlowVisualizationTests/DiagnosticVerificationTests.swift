import BirdFlowCore
import BirdFlowMetal
import Metal
import Testing

@testable import BirdFlowVisualization

private enum AnalyticFlow {
  case solidBodyRotation(Float)
  case simpleShear(Float)
  case pureStrain(Float)

  func velocity(at p: SIMD3<Float>) -> SIMD3<Float> {
    switch self {
    case .solidBodyRotation(let omega):
      return SIMD3<Float>(-omega * p.y, omega * p.x, 0)
    case .simpleShear(let rate):
      return SIMD3<Float>(rate * p.y, 0, 0)
    case .pureStrain(let rate):
      return SIMD3<Float>(rate * p.x, -rate * p.y, 0)
    }
  }
}

func analyticMetadata(grid: GridSize, dx: Float) -> GPUFieldFrameMetadata {
  let outside = SIMD4<Float>(-100, -100, -100, 0)
  let geometry = BirdGeometryFrame(
    bodyPosition: outside,
    orientation: Quaternion.identity.simd4,
    linearVelocity: .zero,
    omegaBodyWorld: SIMD4<Float>(0, 0, 0, 1),
    leftRoot: outside,
    leftChord: SIMD4<Float>(1, 0, 0, 0),
    leftSpan: SIMD4<Float>(0, 1, 0, 0),
    leftNormal: SIMD4<Float>(0, 0, 1, 0),
    leftAngularVelocity: .zero,
    rightRoot: outside,
    rightChord: SIMD4<Float>(1, 0, 0, 0),
    rightSpan: SIMD4<Float>(0, -1, 0, 0),
    rightNormal: SIMD4<Float>(0, 0, 1, 0),
    rightAngularVelocity: .zero
  )
  return GPUFieldFrameMetadata(
    snapshot: SimulationSnapshot(
      step: 0,
      timeSeconds: 0,
      body: BirdBodyState(positionMeters: SIMD3<Float>(-100, -100, -100)),
      aerodynamicLoad: ForceTorque()
    ),
    grid: grid,
    domainOriginMeters: .zero,
    cellSizeMeters: dx,
    velocityToPhysical: 3.25,
    pressureScalePascals: 1,
    physicalAirDensity: 1.225,
    bird: .demonstration,
    geometry: geometry
  )
}

@Test(
  "GPU diagnostic convention matches analytic velocity gradients",
  arguments: [
    AnalyticFlow.solidBodyRotation(17),
    AnalyticFlow.simpleShear(11),
    AnalyticFlow.pureStrain(7),
  ])
private func gpuDiagnosticsMatchAnalyticFields(flow: AnalyticFlow) throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let grid = try GridSize(x: 16, y: 17, z: 18)
  let dx: Float = 0.0125
  let metadata = analyticMetadata(grid: grid, dx: dx)
  var physical = [SIMD3<Float>](repeating: .zero, count: grid.cellCount)
  for z in 0..<grid.z {
    for y in 0..<grid.y {
      for x in 0..<grid.x {
        let index = x + grid.x * (y + grid.y * z)
        let p = (SIMD3<Float>(Float(x), Float(y), Float(z)) + 0.5) * dx
        physical[index] = flow.velocity(at: p)
      }
    }
  }
  let lattice = physical.map { $0 / metadata.velocityToPhysical }
  let cpu = FlowDiagnosticsReference.compute(
    velocity: lattice,
    grid: grid,
    cellSizeMeters: dx,
    velocityToPhysical: metadata.velocityToPhysical
  )
  let gpu = try GPUFlowDiagnosticVerifier.compute(
    density: [Float](repeating: 1, count: grid.cellCount),
    velocityLattice: lattice,
    metadata: metadata,
    device: device
  )

  var maximumVorticityError: Float = 0
  var maximumQError: Float = 0
  for index in 0..<grid.cellCount {
    #expect(gpu.field.valid[index] == cpu.valid[index])
    if cpu.valid[index] != 0 {
      maximumVorticityError = max(
        maximumVorticityError,
        vectorLength(gpu.field.vorticity[index] - cpu.vorticity[index])
      )
      maximumQError = max(
        maximumQError,
        abs(gpu.field.qCriterion[index] - cpu.qCriterion[index])
      )
    }
  }
  let vorticityScale = max(1, cpu.vorticity.map(vectorLength).max() ?? 1)
  let qScale = max(1, cpu.qCriterion.map(abs).max() ?? 1)
  #expect(maximumVorticityError / vorticityScale < 5e-5)
  #expect(maximumQError / qScale < 1e-4)
  #expect(gpu.allOutputsFinite)
  #expect(gpu.sourceFieldsBitwiseUnchanged)
}

@Test("captured flapping bird field matches the shared CPU diagnostic convention")
func capturedBirdDiagnosticsMatchCellByCell() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
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
  let simulation = try BirdFlowSimulation(
    configuration: configuration,
    bird: bird,
    initialBodyState: BirdBodyState(
      positionMeters: configuration.domainSizeMeters * 0.5
    )
  )
  try simulation.advance(steps: 3, batchSize: 3)
  let fields = try simulation.copyMacroscopicFields()
  let lease = try #require(simulation.acquireLatestGPUFieldFrame())
  let metadata = lease.metadata
  lease.releaseImmediately()

  let cpu = FlowDiagnosticsReference.compute(
    velocity: fields.velocity,
    grid: grid,
    cellSizeMeters: metadata.cellSizeMeters,
    velocityToPhysical: metadata.velocityToPhysical
  ) { x, y, z in
    let world =
      metadata.domainOriginMeters
      + (SIMD3<Float>(Float(x), Float(y), Float(z)) + 0.5)
      * metadata.cellSizeMeters
    return BirdAnalyticSurface.signedDistance(
      from: world,
      metadata: metadata
    ) > metadata.cellSizeMeters
  }
  let gpu = try GPUFlowDiagnosticVerifier.compute(
    density: fields.density,
    velocityLattice: fields.velocity,
    metadata: metadata,
    device: device
  )

  var maximumVorticityError: Float = 0
  var maximumQError: Float = 0
  var validCount = 0
  for index in 0..<grid.cellCount {
    #expect(gpu.field.valid[index] == cpu.valid[index])
    guard cpu.valid[index] != 0 else { continue }
    validCount += 1
    maximumVorticityError = max(
      maximumVorticityError,
      vectorLength(gpu.field.vorticity[index] - cpu.vorticity[index])
    )
    maximumQError = max(
      maximumQError,
      abs(gpu.field.qCriterion[index] - cpu.qCriterion[index])
    )
  }
  let vorticityScale = max(1, cpu.vorticity.map(vectorLength).max() ?? 1)
  let qScale = max(1, cpu.qCriterion.map(abs).max() ?? 1)
  #expect(validCount > grid.cellCount / 2)
  #expect(maximumVorticityError / vorticityScale < 5e-5)
  #expect(maximumQError / qScale < 1e-4)
  #expect(gpu.allOutputsFinite)
  #expect(gpu.sourceFieldsBitwiseUnchanged)
}

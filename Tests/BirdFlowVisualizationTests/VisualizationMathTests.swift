import BirdFlowCore
import Testing

@testable import BirdFlowVisualization

@Test("surface pressure sampling and oblique interpolation preserve linear fields")
func trilinearPressureSamplingIsExactForLinearField() throws {
  let grid = try GridSize(x: 16, y: 17, z: 18)
  var density = [Float](repeating: 0, count: grid.cellCount)
  for z in 0..<grid.z {
    for y in 0..<grid.y {
      for x in 0..<grid.x {
        density[x + grid.x * (y + grid.y * z)] =
          1
          + 0.001 * Float(x) - 0.002 * Float(y) + 0.0005 * Float(z)
      }
    }
  }
  let coordinate = SIMD3<Float>(4.25, 7.5, 10.75)
  let sampled = VisualizationMath.trilinear(
    density,
    grid: grid,
    coordinate: coordinate
  )
  let expected =
    1 + 0.001 * coordinate.x
    - 0.002 * coordinate.y + 0.0005 * coordinate.z
  #expect(abs(sampled - expected) < 2e-7)

  let scaling = try LatticeScaling(
    characteristicLengthMeters: 0.1,
    characteristicLengthCells: 16,
    referenceSpeedMetersPerSecond: 4,
    targetReynoldsNumber: 1_000,
    physicalAirDensity: 1.225,
    latticeReferenceSpeed: 0.04
  )
  let pressure = scaling.gaugePressurePascals(fromLatticeDensity: sampled)
  #expect(pressure.isFinite)
  #expect(VisualizationSettings().pressureProbeOffsetCells == 1.5)
}

@Test("oblique glyph projection removes the slice-normal component")
func glyphProjectionUsesSliceBasis() {
  let normal = normalizedVector(SIMD3<Float>(0.4, -0.3, 0.8))
  let u = normalizedVector(cross(SIMD3<Float>(0, 0, 1), normal))
  let v = normalizedVector(cross(normal, u))
  let velocity = 2 * u - 3 * v + 11 * normal
  let projected = VisualizationMath.inPlaneComponents(
    velocity: velocity,
    u: u,
    v: v
  )
  #expect(abs(projected.x - 2) < 1e-5)
  #expect(abs(projected.y + 3) < 1e-5)
}

@Test("pathline CFL subdivision resets discontinuous skipped intervals")
func pathlineCFLSubdivisionAndReset() {
  #expect(
    VisualizationMath.cflSubsteps(
      speedMetersPerSecond: 2,
      elapsedSeconds: 0.002,
      cellSizeMeters: 0.001
    ) == 8)
  #expect(
    !VisualizationMath.mustResetPathline(
      speedMetersPerSecond: 2,
      elapsedSeconds: 0.002,
      cellSizeMeters: 0.001
    ))
  #expect(
    VisualizationMath.mustResetPathline(
      speedMetersPerSecond: 2,
      elapsedSeconds: 0.0021,
      cellSizeMeters: 0.001
    ))
}

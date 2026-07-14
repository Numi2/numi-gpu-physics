import BirdFlowCore
import Foundation

/// Small CPU references for the sampling and integration conventions used by
/// visualization kernels. They are validation aids, not part of the live path.
public enum VisualizationMath {
  public static func trilinear(
    _ values: [Float],
    grid: GridSize,
    coordinate: SIMD3<Float>
  ) -> Float {
    precondition(values.count == grid.cellCount)
    let upper = SIMD3<Float>(
      Float(grid.x - 1), Float(grid.y - 1), Float(grid.z - 1)
    )
    let p = SIMD3<Float>(
      min(max(coordinate.x, 0), upper.x),
      min(max(coordinate.y, 0), upper.y),
      min(max(coordinate.z, 0), upper.z)
    )
    let a = SIMD3<Int>(Int(floor(p.x)), Int(floor(p.y)), Int(floor(p.z)))
    let b = SIMD3<Int>(
      min(a.x + 1, grid.x - 1),
      min(a.y + 1, grid.y - 1),
      min(a.z + 1, grid.z - 1)
    )
    let t = p - SIMD3<Float>(Float(a.x), Float(a.y), Float(a.z))
    func value(_ x: Int, _ y: Int, _ z: Int) -> Float {
      values[x + grid.x * (y + grid.y * z)]
    }
    let z0 = mix(
      mix(value(a.x, a.y, a.z), value(b.x, a.y, a.z), t.x),
      mix(value(a.x, b.y, a.z), value(b.x, b.y, a.z), t.x),
      t.y
    )
    let z1 = mix(
      mix(value(a.x, a.y, b.z), value(b.x, a.y, b.z), t.x),
      mix(value(a.x, b.y, b.z), value(b.x, b.y, b.z), t.x),
      t.y
    )
    return mix(z0, z1, t.z)
  }

  public static func inPlaneComponents(
    velocity: SIMD3<Float>,
    u: SIMD3<Float>,
    v: SIMD3<Float>
  ) -> SIMD2<Float> {
    SIMD2<Float>(dot(velocity, u), dot(velocity, v))
  }

  public static func cflSubsteps(
    speedMetersPerSecond: Float,
    elapsedSeconds: Float,
    cellSizeMeters: Float
  ) -> Int {
    max(
      1,
      Int(
        ceil(
          max(speedMetersPerSecond, 0) * max(elapsedSeconds, 0)
            / max(0.5 * cellSizeMeters, 1e-8)
        )))
  }

  public static func mustResetPathline(
    speedMetersPerSecond: Float,
    elapsedSeconds: Float,
    cellSizeMeters: Float,
    maximumSubsteps: Int = 8
  ) -> Bool {
    cflSubsteps(
      speedMetersPerSecond: speedMetersPerSecond,
      elapsedSeconds: elapsedSeconds,
      cellSizeMeters: cellSizeMeters
    ) > maximumSubsteps
  }

  private static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + t * (b - a)
  }
}

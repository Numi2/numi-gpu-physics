import Foundation

@frozen
public struct FlowDiagnosticField: Sendable, Equatable {
  public var vorticity: [SIMD3<Float>]
  public var qCriterion: [Float]
  public var valid: [UInt8]

  public init(
    vorticity: [SIMD3<Float>],
    qCriterion: [Float],
    valid: [UInt8]
  ) {
    self.vorticity = vorticity
    self.qCriterion = qCriterion
    self.valid = valid
  }
}

/// Shared central-difference convention used by validation and visualization.
/// Q is `0.5 * (||Omega||^2 - ||S||^2)`, equivalently
/// `-0.5 * trace(gradientVelocity * gradientVelocity)`.
public enum FlowDiagnosticsReference {
  public static func compute(
    velocity: [SIMD3<Float>],
    grid: GridSize,
    cellSizeMeters: Float = 1,
    velocityToPhysical: Float = 1,
    isValidInteriorCell: ((_ x: Int, _ y: Int, _ z: Int) -> Bool)? = nil
  ) -> FlowDiagnosticField {
    precondition(velocity.count == grid.cellCount)
    precondition(cellSizeMeters > 0)
    func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
      x + grid.x * (y + grid.y * z)
    }

    var result = FlowDiagnosticField(
      vorticity: [SIMD3<Float>](repeating: .zero, count: velocity.count),
      qCriterion: [Float](repeating: 0, count: velocity.count),
      valid: [UInt8](repeating: 0, count: velocity.count)
    )
    let derivativeScale = 0.5 * velocityToPhysical / cellSizeMeters
    guard grid.x > 2, grid.y > 2, grid.z > 2 else { return result }

    for z in 1..<(grid.z - 1) {
      for y in 1..<(grid.y - 1) {
        for x in 1..<(grid.x - 1) {
          guard isValidInteriorCell?(x, y, z) ?? true else { continue }
          let i = index(x, y, z)
          let dx =
            derivativeScale
            * (velocity[index(x + 1, y, z)]
              - velocity[index(x - 1, y, z)])
          let dy =
            derivativeScale
            * (velocity[index(x, y + 1, z)]
              - velocity[index(x, y - 1, z)])
          let dz =
            derivativeScale
            * (velocity[index(x, y, z + 1)]
              - velocity[index(x, y, z - 1)])

          // Columns are derivatives with respect to x, y, and z.
          let traceSquare =
            dx.x * dx.x + dy.y * dy.y + dz.z * dz.z
            + 2 * (dx.y * dy.x + dx.z * dz.x + dy.z * dz.y)
          result.qCriterion[i] = -0.5 * traceSquare
          result.vorticity[i] = SIMD3<Float>(
            dy.z - dz.y,
            dz.x - dx.z,
            dx.y - dy.x
          )
          result.valid[i] = 1
        }
      }
    }
    return result
  }
}

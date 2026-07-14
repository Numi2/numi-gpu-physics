import BirdFlowCore
import Metal
import Testing

@testable import BirdFlowVisualization

@Test("GPU Q extraction resolves analytic sphere and overflow is all-or-nothing")
func qIsoSurfaceMatchesSphere() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let grid = try GridSize(x: 20, y: 20, z: 20)
  let dx: Float = 0.04
  let metadata = analyticMetadata(grid: grid, dx: dx)
  let center = SIMD3<Float>(repeating: Float(grid.x) * dx * 0.5)
  let radius: Float = 0.22
  var q = [Float](repeating: 0, count: grid.cellCount)
  for z in 0..<grid.z {
    for y in 0..<grid.y {
      for x in 0..<grid.x {
        let index = x + grid.x * (y + grid.y * z)
        let point = (SIMD3<Float>(Float(x), Float(y), Float(z)) + 0.5) * dx
        q[index] = radius - vectorLength(point - center)
      }
    }
  }
  let valid = [UInt8](repeating: 1, count: grid.cellCount)
  let surface = try GPUQCriterionIsoVerifier.extract(
    qCriterion: q,
    valid: valid,
    metadata: metadata,
    threshold: 0,
    triangleCapacity: 100_000,
    device: device
  )
  #expect(!surface.overflow)
  #expect(!surface.vertices.isEmpty)
  #expect(surface.vertices.count.isMultiple(of: 3))
  for vertex in surface.vertices {
    #expect(vertex.position.x.isFinite)
    #expect(vertex.position.y.isFinite)
    #expect(vertex.position.z.isFinite)
    #expect(vertex.normal.x.isFinite)
    #expect(abs(vectorLength(vertex.position - center) - radius) < dx)
    #expect(
      dot(
        normalizedVector(vertex.position - center),
        normalizedVector(vertex.normal)
      ) < -0.5)
  }

  let overflow = try GPUQCriterionIsoVerifier.extract(
    qCriterion: q,
    valid: valid,
    metadata: metadata,
    threshold: 0,
    triangleCapacity: 1,
    device: device
  )
  #expect(overflow.overflow)
  #expect(overflow.vertices.isEmpty)
}

@Test("GPU Q extraction resolves an analytic plane within one cell")
func qIsoSurfaceMatchesPlane() throws {
  guard let device = MTLCreateSystemDefaultDevice() else { return }
  let grid = try GridSize(x: 18, y: 17, z: 16)
  let dx: Float = 0.03
  let metadata = analyticMetadata(grid: grid, dx: dx)
  let planeX = Float(grid.x) * dx * 0.5
  var q = [Float](repeating: 0, count: grid.cellCount)
  for z in 0..<grid.z {
    for y in 0..<grid.y {
      for x in 0..<grid.x {
        let index = x + grid.x * (y + grid.y * z)
        q[index] = (Float(x) + 0.5) * dx - planeX
      }
    }
  }
  let surface = try GPUQCriterionIsoVerifier.extract(
    qCriterion: q,
    valid: [UInt8](repeating: 1, count: grid.cellCount),
    metadata: metadata,
    threshold: 0,
    triangleCapacity: 100_000,
    device: device
  )
  #expect(!surface.overflow)
  #expect(!surface.vertices.isEmpty)
  for vertex in surface.vertices {
    #expect(abs(vertex.position.x - planeX) < dx)
    #expect(normalizedVector(vertex.normal).x > 0.99)
    #expect(vertex.position.y >= 0 && vertex.position.y <= Float(grid.y) * dx)
    #expect(vertex.position.z >= 0 && vertex.position.z <= Float(grid.z) * dx)
  }
}

@Test("classic marching-cubes lookup covers all 256 sign cases")
func qIsoLookupCasesAreComplete() {
  #expect(MarchingCubesLookup.tableData.count == 256 * 16)
  let table = MarchingCubesLookup.triangleTable
  for mask in 0..<256 {
    let row = Array(table[(mask * 16)..<(mask * 16 + 16)])
    let active = row.prefix { $0 >= 0 }
    #expect(active.count.isMultiple(of: 3))
    #expect(active.allSatisfy { $0 < 12 })
    #expect(row.dropFirst(active.count).allSatisfy { $0 == -1 })
    let count = MarchingCubesLookup.triangleCount(mask: mask)
    #expect(count >= 0 && count <= 5)
    if mask == 0 || mask == 255 {
      #expect(count == 0)
    } else {
      #expect(count > 0)
    }
  }
}

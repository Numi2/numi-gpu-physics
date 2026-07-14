import BirdFlowCore
import BirdFlowMetal
import Foundation
import simd

struct SurfaceVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
}

struct ColoredVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
  var color: SIMD4<Float>
}

enum BirdSurfaceMesh {
  static func vertices(for metadata: GPUFieldFrameMetadata) -> [SurfaceVertex] {
    var result: [SurfaceVertex] = []
    result.reserveCapacity(14_000)
    appendBody(metadata, to: &result)
    appendWing(metadata, left: true, to: &result)
    appendWing(metadata, left: false, to: &result)
    appendTail(metadata, to: &result)
    return result
  }

  private static func appendBody(
    _ metadata: GPUFieldFrameMetadata,
    to vertices: inout [SurfaceVertex]
  ) {
    let radii = metadata.bird.bodyRadiiMeters
    let position = metadata.geometry.bodyPosition.xyz
    let orientation = Quaternion(simd4: metadata.geometry.orientation).normalized
    let latitudeCount = 20
    let longitudeCount = 40
    func sample(_ latitude: Int, _ longitude: Int) -> SurfaceVertex {
      let v = Float(latitude) / Float(latitudeCount)
      let u = Float(longitude) / Float(longitudeCount)
      let phi = (v - 0.5) * Float.pi
      let theta = u * 2 * Float.pi
      let unit = SIMD3<Float>(
        cos(phi) * cos(theta),
        cos(phi) * sin(theta),
        sin(phi)
      )
      let local = unit * radii
      let normalLocal = simd_normalize(unit / radii)
      return SurfaceVertex(
        position: SIMD4<Float>(position + orientation.rotate(local), 1),
        normal: SIMD4<Float>(orientation.rotate(normalLocal), 0)
      )
    }
    for latitude in 0..<latitudeCount {
      for longitude in 0..<longitudeCount {
        let nextLongitude = longitude + 1
        appendQuad(
          sample(latitude, longitude),
          sample(latitude, nextLongitude),
          sample(latitude + 1, nextLongitude),
          sample(latitude + 1, longitude),
          to: &vertices
        )
      }
    }
  }

  private static func appendWing(
    _ metadata: GPUFieldFrameMetadata,
    left: Bool,
    to vertices: inout [SurfaceVertex]
  ) {
    let geometry = metadata.geometry
    let root = (left ? geometry.leftRoot : geometry.rightRoot).xyz
    let chordAxis = (left ? geometry.leftChord : geometry.rightChord).xyz
    let spanAxis = (left ? geometry.leftSpan : geometry.rightSpan).xyz
    let normalAxis = (left ? geometry.leftNormal : geometry.rightNormal).xyz
    let bird = metadata.bird
    let spanDivisions = 28
    let chordDivisions = 6

    func point(_ spanIndex: Int, _ chordIndex: Int, side: Float) -> SurfaceVertex {
      let t = Float(spanIndex) / Float(spanDivisions)
      let c = Float(chordIndex) / Float(chordDivisions)
      let chord = mix(bird.wingRootChordMeters, bird.wingTipChordMeters, t)
      let center = -bird.wingSweepMeters * t
      let x = center + (c - 0.5) * chord
      let world =
        root
        + spanAxis * (t * bird.wingSpanMeters)
        + chordAxis * x
        + normalAxis * (side * 0.5 * bird.wingThicknessMeters)
      return SurfaceVertex(
        position: SIMD4<Float>(world, 1),
        normal: SIMD4<Float>(side * normalAxis, 0)
      )
    }
    for side: Float in [-1, 1] {
      for span in 0..<spanDivisions {
        for chord in 0..<chordDivisions {
          let a = point(span, chord, side: side)
          let b = point(span + 1, chord, side: side)
          let c = point(span + 1, chord + 1, side: side)
          let d = point(span, chord + 1, side: side)
          if side > 0 {
            appendQuad(a, b, c, d, to: &vertices)
          } else {
            appendQuad(d, c, b, a, to: &vertices)
          }
        }
      }
    }
    // Close root, tip, leading, and trailing edges. These narrow faces make
    // the rendered mesh match the finite-thickness solver boundary.
    for span in [0, spanDivisions] {
      for chord in 0..<chordDivisions {
        appendQuad(
          point(span, chord, side: -1),
          point(span, chord + 1, side: -1),
          point(span, chord + 1, side: 1),
          point(span, chord, side: 1),
          to: &vertices
        )
      }
    }
    for chord in [0, chordDivisions] {
      for span in 0..<spanDivisions {
        appendQuad(
          point(span, chord, side: -1),
          point(span + 1, chord, side: -1),
          point(span + 1, chord, side: 1),
          point(span, chord, side: 1),
          to: &vertices
        )
      }
    }
  }

  private static func appendTail(
    _ metadata: GPUFieldFrameMetadata,
    to vertices: inout [SurfaceVertex]
  ) {
    let bird = metadata.bird
    let geometry = metadata.geometry
    let position = geometry.bodyPosition.xyz
    let orientation = Quaternion(simd4: geometry.orientation).normalized
    let zCenter = -0.15 * bird.bodyRadiiMeters.z
    func point(_ fraction: Float, _ side: Float, _ top: Float) -> SurfaceVertex {
      let halfWidth = mix(0.35 * bird.tailHalfWidthMeters, bird.tailHalfWidthMeters, fraction)
      let local = SIMD3<Float>(
        -bird.bodyRadiiMeters.x - fraction * bird.tailLengthMeters,
        side * halfWidth,
        zCenter + top * 0.5 * bird.tailThicknessMeters
      )
      let normalLocal = SIMD3<Float>(0, 0, top)
      return SurfaceVertex(
        position: SIMD4<Float>(position + orientation.rotate(local), 1),
        normal: SIMD4<Float>(orientation.rotate(normalLocal), 0)
      )
    }
    appendQuad(
      point(0, -1, 1), point(1, -1, 1),
      point(1, 1, 1), point(0, 1, 1),
      to: &vertices
    )
    appendQuad(
      point(0, 1, -1), point(1, 1, -1),
      point(1, -1, -1), point(0, -1, -1),
      to: &vertices
    )
    for side: Float in [-1, 1] {
      appendQuad(
        point(0, side, -1), point(1, side, -1),
        point(1, side, 1), point(0, side, 1),
        to: &vertices
      )
    }
  }

  private static func appendQuad(
    _ a: SurfaceVertex,
    _ b: SurfaceVertex,
    _ c: SurfaceVertex,
    _ d: SurfaceVertex,
    to vertices: inout [SurfaceVertex]
  ) {
    vertices.append(contentsOf: [a, b, c, a, c, d])
  }

  private static func mix(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + (b - a) * t
  }
}

extension SIMD4 where Scalar == Float {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

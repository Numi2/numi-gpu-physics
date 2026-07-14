import BirdFlowCore
import BirdFlowMetal
import Foundation

/// CPU counterpart of the visualization shader's captured analytic surface.
/// It is used by the diagnostic gate to require identical valid-cell masks.
public enum BirdAnalyticSurface {
  public static func signedDistance(
    from world: SIMD3<Float>,
    metadata: GPUFieldFrameMetadata
  ) -> Float {
    let bird = metadata.bird
    let geometry = metadata.geometry
    let orientation = Quaternion(simd4: geometry.orientation)
    let local = orientation.unrotate(world - geometry.bodyPosition.xyz)
    var distance = ellipsoid(local, radii: bird.bodyRadiiMeters)
    distance = min(distance, tail(local, bird: bird))
    distance = min(
      distance,
      wing(
        world,
        root: geometry.leftRoot.xyz,
        chordAxis: geometry.leftChord.xyz,
        spanAxis: geometry.leftSpan.xyz,
        normalAxis: geometry.leftNormal.xyz,
        bird: bird
      ))
    distance = min(
      distance,
      wing(
        world,
        root: geometry.rightRoot.xyz,
        chordAxis: geometry.rightChord.xyz,
        spanAxis: geometry.rightSpan.xyz,
        normalAxis: geometry.rightNormal.xyz,
        bird: bird
      ))
    return distance
  }

  private static func ellipsoid(
    _ p: SIMD3<Float>,
    radii: SIMD3<Float>
  ) -> Float {
    let k0 = vectorLength(p / radii)
    let k1 = vectorLength(p / (radii * radii))
    return k1 > 1e-12
      ? k0 * (k0 - 1) / k1
      : -min(radii.x, min(radii.y, radii.z))
  }

  private static func wing(
    _ world: SIMD3<Float>,
    root: SIMD3<Float>,
    chordAxis: SIMD3<Float>,
    spanAxis: SIMD3<Float>,
    normalAxis: SIMD3<Float>,
    bird: BirdParameters
  ) -> Float {
    let relative = world - root
    let local = SIMD3<Float>(
      dot(relative, chordAxis),
      dot(relative, spanAxis),
      dot(relative, normalAxis)
    )
    let t = min(max(local.y / max(bird.wingSpanMeters, 1e-6), 0), 1)
    let chord =
      bird.wingRootChordMeters
      + t * (bird.wingTipChordMeters - bird.wingRootChordMeters)
    let center = -bird.wingSweepMeters * t
    let q = SIMD3<Float>(
      abs(local.x - center) - 0.5 * chord,
      max(-local.y, local.y - bird.wingSpanMeters),
      abs(local.z) - 0.5 * bird.wingThicknessMeters
    )
    let outside = SIMD3<Float>(max(q.x, 0), max(q.y, 0), max(q.z, 0))
    return vectorLength(outside) + min(max(q.x, max(q.y, q.z)), 0)
  }

  private static func tail(
    _ local: SIMD3<Float>,
    bird: BirdParameters
  ) -> Float {
    let x = -(local.x + bird.bodyRadiiMeters.x)
    let t = min(max(x / max(bird.tailLengthMeters, 1e-6), 0), 1)
    let halfWidth =
      0.35 * bird.tailHalfWidthMeters
      + t * 0.65 * bird.tailHalfWidthMeters
    let q = SIMD3<Float>(
      max(-x, x - bird.tailLengthMeters),
      abs(local.y) - halfWidth,
      abs(local.z + 0.15 * bird.bodyRadiiMeters.z)
        - 0.5 * bird.tailThicknessMeters
    )
    let outside = SIMD3<Float>(max(q.x, 0), max(q.y, 0), max(q.z, 0))
    return vectorLength(outside) + min(max(q.x, max(q.y, q.z)), 0)
  }
}

extension SIMD4<Float> {
  fileprivate var xyz: SIMD3<Float> { SIMD3<Float>(x, y, z) }
}

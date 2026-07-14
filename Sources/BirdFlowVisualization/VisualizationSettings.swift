import Foundation
import simd

public enum SliceField: Int, Codable, CaseIterable, Sendable {
  case speed
  case normalVelocity
  case vorticityMagnitude

  public var title: String {
    switch self {
    case .speed: return "Velocity magnitude"
    case .normalVelocity: return "Normal velocity"
    case .vorticityMagnitude: return "Vorticity magnitude"
    }
  }
}

public enum SliceSnap: String, Codable, CaseIterable, Sendable {
  case x = "X"
  case y = "Y"
  case z = "Z"
  case oblique = "Oblique"
}

public enum PressureUnit: String, Codable, CaseIterable, Sendable {
  case pascals = "Pa"
  case coefficient = "Cp"
}

public enum RibbonColorField: String, Codable, CaseIterable, Sendable {
  case speed = "Speed"
  case vorticity = "Vorticity"
}

public enum QSurfaceColorField: String, Codable, CaseIterable, Sendable {
  case qCriterion = "Q"
  case vorticity = "Vorticity"
}

public struct VisualizationSettings: Codable, Sendable, Equatable {
  public var camera = CameraState()

  public var showPressureSurface = true
  public var pressureUnit: PressureUnit = .pascals
  public var pressureProbeOffsetCells: Float = 1.5
  public var pressureRangePascals: Float = 120
  public var pressureRangeCoefficient: Float = 0.8
  public var pressureAutoscalePercentile: Float = 0.99
  public var pressureRangeLocked = false

  public var showSlice = true
  public var sliceField: SliceField = .vorticityMagnitude
  public var sliceSnap: SliceSnap = .z
  public var slicePosition: Float = 0.5
  public var sliceYawRadians: Float = 0
  public var slicePitchRadians: Float = 0
  public var sliceOpacity: Float = 0.82
  public var sliceRange: Float = 25
  public var showVelocityGlyphs = true

  public var showRibbons = true
  public var ribbonWidthMeters: Float = 0.0025
  public var ribbonColor: RibbonColorField = .speed
  public var ribbonColorRange: Float = 20
  public var tracerCount = 128
  public var tracerHistory = 64

  public var showQCriterion = false
  public var qThreshold: Float = 25
  public var qOpacity: Float = 0.42
  public var qColor: QSurfaceColorField = .vorticity
  public var clipQBySlicePlane = false
  public var qTriangleCapacity = 2_000_000

  public init() {}
}

public struct CameraState: Codable, Sendable, Equatable {
  public var target: SIMD3<Float> = SIMD3<Float>(0.56, 0.65, 0.56)
  public var distance: Float = 1.65
  public var yaw: Float = -0.72
  public var pitch: Float = 0.28

  public init() {}
}

struct CameraUniforms {
  var viewProjection: simd_float4x4
  var eyeAndWidth: SIMD4<Float>
}

extension CameraState {
  var eye: SIMD3<Float> {
    let cp = cos(pitch)
    return target + distance
      * SIMD3<Float>(
        cp * cos(yaw),
        cp * sin(yaw),
        sin(pitch)
      )
  }

  func uniforms(aspect: Float, ribbonWidth: Float) -> CameraUniforms {
    let eye = eye
    let view = simd_float4x4.lookAt(
      eye: eye,
      center: target,
      up: SIMD3<Float>(0, 0, 1)
    )
    let projection = simd_float4x4.perspective(
      verticalFOV: 48 * .pi / 180,
      aspect: max(aspect, 0.01),
      near: 0.005,
      far: 50
    )
    return CameraUniforms(
      viewProjection: projection * view,
      eyeAndWidth: SIMD4<Float>(eye, ribbonWidth)
    )
  }
}

extension simd_float4x4 {
  fileprivate static func lookAt(
    eye: SIMD3<Float>,
    center: SIMD3<Float>,
    up: SIMD3<Float>
  ) -> simd_float4x4 {
    let forward = simd_normalize(center - eye)
    let side = simd_normalize(simd_cross(forward, up))
    let correctedUp = simd_cross(side, forward)
    return simd_float4x4(
      columns: (
        SIMD4<Float>(side.x, correctedUp.x, -forward.x, 0),
        SIMD4<Float>(side.y, correctedUp.y, -forward.y, 0),
        SIMD4<Float>(side.z, correctedUp.z, -forward.z, 0),
        SIMD4<Float>(
          -simd_dot(side, eye),
          -simd_dot(correctedUp, eye),
          simd_dot(forward, eye),
          1
        )
      ))
  }

  fileprivate static func perspective(
    verticalFOV: Float,
    aspect: Float,
    near: Float,
    far: Float
  ) -> simd_float4x4 {
    let ys = 1 / tan(verticalFOV * 0.5)
    let xs = ys / aspect
    let zs = far / (near - far)
    return simd_float4x4(
      columns: (
        SIMD4<Float>(xs, 0, 0, 0),
        SIMD4<Float>(0, ys, 0, 0),
        SIMD4<Float>(0, 0, zs, -1),
        SIMD4<Float>(0, 0, near * zs, 0)
      ))
  }
}

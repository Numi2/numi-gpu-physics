import BirdFlowMetal
import Foundation
import simd

struct VisualizationUniforms {
  var grid: SIMD4<UInt32>
  var flags: SIMD4<UInt32>
  var originAndCellSize: SIMD4<Float>
  var scalesAndRanges: SIMD4<Float>
  var sliceCenterAndOpacity: SIMD4<Float>
  var sliceUAndHalfWidth: SIMD4<Float>
  var sliceVAndHalfHeight: SIMD4<Float>
  var sliceNormalAndRange: SIMD4<Float>
  var tracerAndIso: SIMD4<Float>
  var displayOptions: SIMD4<Float>
  var probeUVAndPadding: SIMD4<Float>
  var bodyPosition: SIMD4<Float>
  var orientation: SIMD4<Float>
  var bodyRadiiAndTail: SIMD4<Float>
  var wingGeometry0: SIMD4<Float>
  var wingGeometry1: SIMD4<Float>
  var leftRoot: SIMD4<Float>
  var leftChord: SIMD4<Float>
  var leftSpan: SIMD4<Float>
  var leftNormal: SIMD4<Float>
  var rightRoot: SIMD4<Float>
  var rightChord: SIMD4<Float>
  var rightSpan: SIMD4<Float>
  var rightNormal: SIMD4<Float>

  init(
    metadata: GPUFieldFrameMetadata,
    settings: VisualizationSettings,
    sliceCenter: SIMD3<Float>,
    sliceU: SIMD3<Float>,
    sliceV: SIMD3<Float>,
    tracerDeltaTime: Float,
    resetTracers: Bool,
    probeUV: SIMD2<Float> = SIMD2<Float>(0.5, 0.5)
  ) {
    let gridSize = metadata.grid
    grid = SIMD4<UInt32>(
      UInt32(gridSize.x), UInt32(gridSize.y), UInt32(gridSize.z),
      UInt32(gridSize.cellCount)
    )
    var displayFlags: UInt32 = resetTracers ? 1 : 0
    if settings.showVelocityGlyphs { displayFlags |= 1 << 1 }
    if settings.pressureUnit == .coefficient,
      metadata.referenceDynamicPressurePascals != nil
    {
      displayFlags |= 1 << 2
    }
    if settings.ribbonColor == .vorticity { displayFlags |= 1 << 3 }
    if settings.clipQBySlicePlane { displayFlags |= 1 << 4 }
    if settings.qColor == .vorticity { displayFlags |= 1 << 5 }
    flags = SIMD4<UInt32>(
      UInt32(settings.sliceField.rawValue),
      displayFlags,
      UInt32(settings.tracerCount),
      UInt32(settings.tracerHistory)
    )
    originAndCellSize = SIMD4<Float>(
      metadata.domainOriginMeters,
      metadata.cellSizeMeters
    )
    let pressureRange =
      settings.pressureUnit == .coefficient
      ? settings.pressureRangeCoefficient
      : settings.pressureRangePascals
    scalesAndRanges = SIMD4<Float>(
      metadata.velocityToPhysical,
      metadata.pressureScalePascals,
      settings.pressureProbeOffsetCells,
      max(pressureRange, 1e-6)
    )
    sliceCenterAndOpacity = SIMD4<Float>(sliceCenter, settings.sliceOpacity)
    let domain =
      SIMD3<Float>(
        Float(gridSize.x), Float(gridSize.y), Float(gridSize.z)
      ) * metadata.cellSizeMeters
    sliceUAndHalfWidth = SIMD4<Float>(sliceU, 0.5 * simd_length(domain))
    sliceVAndHalfHeight = SIMD4<Float>(sliceV, 0.5 * simd_length(domain))
    sliceNormalAndRange = SIMD4<Float>(
      simd_normalize(simd_cross(sliceU, sliceV)),
      max(settings.sliceRange, 1e-6)
    )
    tracerAndIso = SIMD4<Float>(
      max(tracerDeltaTime, 0),
      settings.qThreshold,
      settings.qOpacity,
      Float(settings.qTriangleCapacity)
    )
    displayOptions = SIMD4<Float>(
      metadata.referenceDynamicPressurePascals ?? 0,
      min(max(settings.pressureAutoscalePercentile, 0.5), 1),
      max(settings.ribbonColorRange, 1e-6),
      max(settings.qThreshold * 10, 1e-6)
    )
    probeUVAndPadding = SIMD4<Float>(
      min(max(probeUV.x, 0), 1),
      min(max(probeUV.y, 0), 1),
      0,
      0
    )
    let geometry = metadata.geometry
    bodyPosition = geometry.bodyPosition
    orientation = geometry.orientation
    bodyRadiiAndTail = SIMD4<Float>(
      metadata.bird.bodyRadiiMeters,
      metadata.bird.tailLengthMeters
    )
    wingGeometry0 = SIMD4<Float>(
      metadata.bird.wingSpanMeters,
      metadata.bird.wingRootChordMeters,
      metadata.bird.wingTipChordMeters,
      metadata.bird.wingThicknessMeters
    )
    wingGeometry1 = SIMD4<Float>(
      metadata.bird.wingSweepMeters,
      metadata.bird.tailHalfWidthMeters,
      metadata.bird.tailThicknessMeters,
      metadata.physicalAirDensity
    )
    leftRoot = geometry.leftRoot
    leftChord = geometry.leftChord
    leftSpan = geometry.leftSpan
    leftNormal = geometry.leftNormal
    rightRoot = geometry.rightRoot
    rightChord = geometry.rightChord
    rightSpan = geometry.rightSpan
    rightNormal = geometry.rightNormal
  }
}

struct TracerState {
  var positionAndAge: SIMD4<Float>
  var velocityAndSpeed: SIMD4<Float>
}

struct IsoVertex {
  var position: SIMD4<Float>
  var normal: SIMD4<Float>
}

struct SliceProbeOutput {
  var worldAndScalar: SIMD4<Float>
  var velocity: SIMD4<Float>
  var vorticity: SIMD4<Float>
}

struct DrawPrimitivesIndirectArguments {
  var vertexCount: UInt32
  var instanceCount: UInt32
  var vertexStart: UInt32
  var baseInstance: UInt32
}

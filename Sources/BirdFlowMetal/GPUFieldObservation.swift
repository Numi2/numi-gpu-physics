import BirdFlowCore
import Foundation

public enum FieldCaptureMode: Sendable, Equatable {
  /// Preserve the historical API contract: a current macroscopic field must
  /// be captured before `advance` returns.
  case required
  /// Publish a field only when an observation slot is immediately available.
  /// Numerical advancement never waits for an observer in this mode.
  case bestEffort
  /// Advance without publishing macroscopic fields.
  case disabled
}

@frozen
public struct RunSample: Sendable, Equatable, Codable {
  public var step: UInt64
  public var timeSeconds: Float
  public var body: BirdBodyState
  public var aerodynamicLoad: ForceTorque

  public init(
    step: UInt64,
    timeSeconds: Float,
    body: BirdBodyState,
    aerodynamicLoad: ForceTorque
  ) {
    self.step = step
    self.timeSeconds = timeSeconds
    self.body = body
    self.aerodynamicLoad = aerodynamicLoad
  }
}

@frozen
public struct AdvanceResult: Sendable {
  public var runSamples: [RunSample]
  public var fieldFramePublished: Bool
  public var droppedFieldFrameCount: UInt64

  public init(
    runSamples: [RunSample] = [],
    fieldFramePublished: Bool = false,
    droppedFieldFrameCount: UInt64 = 0
  ) {
    self.runSamples = runSamples
    self.fieldFramePublished = fieldFramePublished
    self.droppedFieldFrameCount = droppedFieldFrameCount
  }
}

/// Exact articulated frame used by the geometry and fluid kernels for a
/// published macroscopic field. It is intentionally independent of rendering.
@frozen
public struct BirdGeometryFrame: Sendable, Equatable, Codable {
  public var bodyPosition: SIMD4<Float>
  public var orientation: SIMD4<Float>
  public var linearVelocity: SIMD4<Float>
  /// XYZ is rigid-body angular velocity in world coordinates. W is the
  /// conservative geometry radius used by the solver broad phase.
  public var omegaBodyWorld: SIMD4<Float>
  public var leftRoot: SIMD4<Float>
  public var leftChord: SIMD4<Float>
  public var leftSpan: SIMD4<Float>
  public var leftNormal: SIMD4<Float>
  public var leftAngularVelocity: SIMD4<Float>
  public var rightRoot: SIMD4<Float>
  public var rightChord: SIMD4<Float>
  public var rightSpan: SIMD4<Float>
  public var rightNormal: SIMD4<Float>
  public var rightAngularVelocity: SIMD4<Float>

  public init(
    bodyPosition: SIMD4<Float>,
    orientation: SIMD4<Float>,
    linearVelocity: SIMD4<Float>,
    omegaBodyWorld: SIMD4<Float>,
    leftRoot: SIMD4<Float>,
    leftChord: SIMD4<Float>,
    leftSpan: SIMD4<Float>,
    leftNormal: SIMD4<Float>,
    leftAngularVelocity: SIMD4<Float>,
    rightRoot: SIMD4<Float>,
    rightChord: SIMD4<Float>,
    rightSpan: SIMD4<Float>,
    rightNormal: SIMD4<Float>,
    rightAngularVelocity: SIMD4<Float>
  ) {
    self.bodyPosition = bodyPosition
    self.orientation = orientation
    self.linearVelocity = linearVelocity
    self.omegaBodyWorld = omegaBodyWorld
    self.leftRoot = leftRoot
    self.leftChord = leftChord
    self.leftSpan = leftSpan
    self.leftNormal = leftNormal
    self.leftAngularVelocity = leftAngularVelocity
    self.rightRoot = rightRoot
    self.rightChord = rightChord
    self.rightSpan = rightSpan
    self.rightNormal = rightNormal
    self.rightAngularVelocity = rightAngularVelocity
  }
}

@frozen
public struct GPUFieldFrameMetadata: Sendable, Equatable {
  public var snapshot: SimulationSnapshot
  public var grid: GridSize
  public var domainOriginMeters: SIMD3<Float>
  public var cellSizeMeters: Float
  public var velocityToPhysical: Float
  public var pressureScalePascals: Float
  public var referenceDynamicPressurePascals: Float?
  public var physicalAirDensity: Float
  public var bird: BirdParameters
  public var geometry: BirdGeometryFrame
  public var publicationUptimeSeconds: Double

  public init(
    snapshot: SimulationSnapshot,
    grid: GridSize,
    domainOriginMeters: SIMD3<Float>,
    cellSizeMeters: Float,
    velocityToPhysical: Float,
    pressureScalePascals: Float,
    referenceDynamicPressurePascals: Float? = nil,
    physicalAirDensity: Float,
    bird: BirdParameters,
    geometry: BirdGeometryFrame,
    publicationUptimeSeconds: Double = ProcessInfo.processInfo.systemUptime
  ) {
    self.snapshot = snapshot
    self.grid = grid
    self.domainOriginMeters = domainOriginMeters
    self.cellSizeMeters = cellSizeMeters
    self.velocityToPhysical = velocityToPhysical
    self.pressureScalePascals = pressureScalePascals
    self.referenceDynamicPressurePascals = referenceDynamicPressurePascals
    self.physicalAirDensity = physicalAirDensity
    self.bird = bird
    self.geometry = geometry
    self.publicationUptimeSeconds = publicationUptimeSeconds
  }
}

#if canImport(Metal)
  import Metal

  /// A time-bounded, read-only view of macroscopic buffers owned by the solver.
  /// The underlying buffers are never exposed, preventing visualization code
  /// from encoding writes into numerical state.
  public final class GPUFieldFrameLease: @unchecked Sendable {
    public let metadata: GPUFieldFrameMetadata

    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let lock = NSLock()
    private var releaseAction: (@Sendable () -> Void)?

    init(
      metadata: GPUFieldFrameMetadata,
      density: MTLBuffer,
      velocity: MTLBuffer,
      release: @escaping @Sendable () -> Void
    ) {
      self.metadata = metadata
      self.density = density
      self.velocity = velocity
      releaseAction = release
    }

    /// Binds the solver-owned buffers directly. The visualization shader must
    /// declare both arguments `device const`.
    public func bindMacroscopicFields(
      to encoder: MTLComputeCommandEncoder,
      densityIndex: Int,
      velocityIndex: Int
    ) {
      encoder.setBuffer(density, offset: 0, index: densityIndex)
      encoder.setBuffer(velocity, offset: 0, index: velocityIndex)
    }

    /// Keeps the slot leased until all GPU reads in `commandBuffer` finish.
    public func releaseAfterCompletion(of commandBuffer: MTLCommandBuffer) {
      let action = takeReleaseAction()
      commandBuffer.addCompletedHandler { _ in action?() }
    }

    public func releaseImmediately() {
      takeReleaseAction()?()
    }

    deinit {
      releaseImmediately()
    }

    private func takeReleaseAction() -> (@Sendable () -> Void)? {
      lock.lock()
      defer { lock.unlock() }
      let action = releaseAction
      releaseAction = nil
      return action
    }
  }
#endif

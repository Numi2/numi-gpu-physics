import BirdFlowCore
import BirdFlowMetal
import Foundation

public struct LiveSimulationMetrics: Sendable {
  public var step: UInt64 = 0
  public var timeSeconds: Float = 0
  public var solverStepsPerSecond: Double = 0
  public var droppedFieldFrames: UInt64 = 0
  public var running = false

  public init() {}
}

public final class LiveSimulation: @unchecked Sendable {
  public let simulation: BirdFlowSimulation
  public let batchSize: Int

  private let queue = DispatchQueue(
    label: "BirdFlow live solver",
    qos: .userInitiated
  )
  private let condition = NSCondition()
  private var running = false
  private var stopped = false
  private var stepRequests = 0
  private var checkpointRequest: URL?
  private var recorder: RunBundleRecorder?
  private var retainedSamples: [RunSample] = []
  private var metricsHandler: (@Sendable (LiveSimulationMetrics) -> Void)?
  private var errorHandler: (@Sendable (String) -> Void)?

  public init(
    configuration: SimulationConfiguration,
    bird: BirdParameters,
    initialBodyState: BirdBodyState,
    batchSize: Int = 32
  ) throws {
    self.batchSize = max(1, batchSize)
    simulation = try BirdFlowSimulation(
      configuration: configuration,
      bird: bird,
      initialBodyState: initialBodyState,
      observationBufferCount: 3
    )
    queue.async { [weak self] in self?.runLoop() }
  }

  public init(checkpointURL: URL, batchSize: Int = 32) throws {
    self.batchSize = max(1, batchSize)
    simulation = try BirdFlowSimulation(
      checkpointURL: checkpointURL,
      observationBufferCount: 3
    )
    queue.async { [weak self] in self?.runLoop() }
  }

  deinit {
    stop()
  }

  public func setHandlers(
    metrics: (@Sendable (LiveSimulationMetrics) -> Void)?,
    error: (@Sendable (String) -> Void)?
  ) {
    condition.lock()
    metricsHandler = metrics
    errorHandler = error
    condition.unlock()
  }

  public func start() {
    condition.lock()
    running = true
    condition.broadcast()
    condition.unlock()
  }

  public func pause() {
    condition.lock()
    running = false
    condition.unlock()
  }

  public func advanceOneBatch() {
    condition.lock()
    stepRequests += 1
    condition.broadcast()
    condition.unlock()
  }

  public func stop() {
    condition.lock()
    stopped = true
    running = false
    condition.broadcast()
    condition.unlock()
  }

  public func setRecorder(_ recorder: RunBundleRecorder?) {
    condition.lock()
    self.recorder = recorder
    condition.unlock()
  }

  public func requestCheckpoint(to url: URL) {
    condition.lock()
    checkpointRequest = url
    condition.broadcast()
    condition.unlock()
  }

  public func acquireLatestField(afterStep: UInt64?) -> GPUFieldFrameLease? {
    simulation.acquireLatestGPUFieldFrame(afterStep: afterStep)
  }

  private func runLoop() {
    while true {
      condition.lock()
      while !stopped && !running && stepRequests == 0
        && checkpointRequest == nil
      {
        condition.wait()
      }
      if stopped {
        condition.unlock()
        return
      }
      let shouldAdvance = running || stepRequests > 0
      if !running && stepRequests > 0 { stepRequests -= 1 }
      let checkpoint = checkpointRequest
      checkpointRequest = nil
      let activeRecorder = recorder
      let metricsCallback = metricsHandler
      let errors = errorHandler
      condition.unlock()

      if let checkpoint {
        do {
          try simulation.saveCheckpoint(to: checkpoint)
        } catch {
          errors?(String(describing: error))
        }
      }
      guard shouldAdvance else { continue }

      if let recordingError = activeRecorder?.recordingError {
        pause()
        errors?(recordingError.description)
        continue
      }

      if !retainedSamples.isEmpty, let activeRecorder {
        guard activeRecorder.append(retainedSamples) else {
          pause()
          errors?(RunBundleError.writerBackpressure.description)
          continue
        }
        retainedSamples.removeAll(keepingCapacity: true)
      }

      let start = Date()
      do {
        let result = try simulation.advance(
          steps: batchSize,
          batchSize: batchSize,
          fieldCapture: .bestEffort,
          recordRunSamples: activeRecorder != nil
        )
        if let activeRecorder, !activeRecorder.append(result.runSamples) {
          retainedSamples = result.runSamples
          pause()
          errors?(RunBundleError.writerBackpressure.description)
        }
        let elapsed = max(Date().timeIntervalSince(start), 1e-9)
        var metrics = LiveSimulationMetrics()
        metrics.step = simulation.stepIndex
        metrics.timeSeconds = simulation.timeSeconds
        metrics.solverStepsPerSecond = Double(batchSize) / elapsed
        metrics.droppedFieldFrames = result.droppedFieldFrameCount
        condition.lock()
        metrics.running = running
        condition.unlock()
        metricsCallback?(metrics)
      } catch {
        pause()
        errors?(String(describing: error))
      }
    }
  }
}

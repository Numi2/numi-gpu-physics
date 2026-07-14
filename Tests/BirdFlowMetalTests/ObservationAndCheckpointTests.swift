import BirdFlowCore
import Foundation
import Metal
import Testing

@testable import BirdFlowMetal

#if canImport(Metal)
  @Test
  func observationModesDoNotChangeNumericalState() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let disabled = try BirdFlowSimulation(
      configuration: testCase.configuration,
      bird: testCase.bird,
      initialBodyState: testCase.state,
      observationBufferCount: 1
    )
    let observed = try BirdFlowSimulation(
      configuration: testCase.configuration,
      bird: testCase.bird,
      initialBodyState: testCase.state,
      observationBufferCount: 3
    )

    try disabled.advance(
      steps: 6,
      batchSize: 3,
      fieldCapture: .disabled
    )
    try observed.advance(
      steps: 6,
      batchSize: 3,
      fieldCapture: .bestEffort
    )
    try disabled.captureCurrentMacroscopicField()

    let a = try disabled.snapshot()
    let b = try observed.snapshot()
    #expect(a.step == b.step)
    #expect(a.timeSeconds == b.timeSeconds)
    #expect(a.body == b.body)
    #expect(a.aerodynamicLoad == b.aerodynamicLoad)
    let af = try disabled.copyMacroscopicFields()
    let bf = try observed.copyMacroscopicFields()
    var densityDifference: Float = 0
    var velocityDifference: Float = 0
    for index in af.density.indices {
      densityDifference = max(
        densityDifference,
        abs(af.density[index] - bf.density[index])
      )
      velocityDifference = max(
        velocityDifference,
        vectorLength(af.velocity[index] - bf.velocity[index])
      )
    }
    #expect(densityDifference < 1e-6)
    #expect(velocityDifference < 1e-6)
  }

  @Test
  func exhaustedViewerSlotsDropWithoutWaiting() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase()
    let simulation = try BirdFlowSimulation(
      configuration: testCase.configuration,
      bird: testCase.bird,
      initialBodyState: testCase.state,
      observationBufferCount: 3
    )

    let first = try #require(simulation.acquireLatestGPUFieldFrame())
    try simulation.advance(steps: 1, fieldCapture: .bestEffort)
    let second = try #require(simulation.acquireLatestGPUFieldFrame())
    try simulation.advance(steps: 1, fieldCapture: .bestEffort)
    let third = try #require(simulation.acquireLatestGPUFieldFrame())
    let result = try simulation.advance(steps: 1, fieldCapture: .bestEffort)

    #expect(!result.fieldFramePublished)
    #expect(result.droppedFieldFrameCount == 1)
    #expect(simulation.fieldCaptureWaitCount == 0)
    #expect(simulation.stepIndex == 3)
    first.releaseImmediately()
    second.releaseImmediately()
    third.releaseImmediately()
  }

  @Test
  func everyStepRunSamplesRemainContiguous() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let simulation = try BirdFlowSimulation(
      configuration: testCase.configuration,
      bird: testCase.bird,
      initialBodyState: testCase.state
    )
    let result = try simulation.advance(
      steps: 9,
      batchSize: 4,
      fieldCapture: .disabled,
      recordRunSamples: true
    )
    #expect(result.runSamples.count == 9)
    for (offset, sample) in result.runSamples.enumerated() {
      #expect(sample.step == UInt64(offset + 1))
      #expect(
        sample.timeSeconds == Float(offset + 1)
          * testCase.configuration.scaling.timeStepSeconds)
      #expect(sample.aerodynamicLoad.forceNewtons.x.isFinite)
      #expect(sample.body.positionMeters.x.isFinite)
    }
  }

  @Test
  func checkpointRestoresExactPopulationBytesAndContinuation() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase(freeFlight: true)
    let original = try BirdFlowSimulation(
      configuration: testCase.configuration,
      bird: testCase.bird,
      initialBodyState: testCase.state
    )
    try original.advance(steps: 4, batchSize: 2)

    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("BirdFlow-checkpoint-\(UUID().uuidString)")
    let firstURL = root.appendingPathComponent("first.bfcp")
    let secondURL = root.appendingPathComponent("second.bfcp")
    defer { try? FileManager.default.removeItem(at: root) }
    try original.saveCheckpoint(to: firstURL)
    let restored = try BirdFlowSimulation(checkpointURL: firstURL)
    try restored.saveCheckpoint(to: secondURL)

    #expect(try original.snapshot() == restored.snapshot())
    #expect(
      try Data(contentsOf: firstURL.appendingPathComponent("populations.lzfse"))
        == Data(contentsOf: secondURL.appendingPathComponent("populations.lzfse"))
    )
    #expect(
      try Data(contentsOf: firstURL.appendingPathComponent("solid-mask.lzfse"))
        == Data(contentsOf: secondURL.appendingPathComponent("solid-mask.lzfse"))
    )

    try original.advance(steps: 3, batchSize: 3)
    try restored.advance(steps: 3, batchSize: 1)
    let a = try original.snapshot()
    let b = try restored.snapshot()
    #expect(vectorLength(a.body.positionMeters - b.body.positionMeters) < 1e-6)
    #expect(
      vectorLength(
        a.aerodynamicLoad.forceNewtons - b.aerodynamicLoad.forceNewtons
      ) < 1e-5)
    let af = try original.copyMacroscopicFields()
    let bf = try restored.copyMacroscopicFields()
    #expect(af.density == bf.density)
    #expect(af.velocity == bf.velocity)
  }

  @Test
  func corruptedCheckpointFailsClearly() throws {
    guard MTLCreateSystemDefaultDevice() != nil else { return }
    let testCase = try compactMetalTestCase()
    let simulation = try BirdFlowSimulation(
      configuration: testCase.configuration,
      bird: testCase.bird,
      initialBodyState: testCase.state
    )
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("BirdFlow-corrupt-\(UUID().uuidString).bfcp")
    defer { try? FileManager.default.removeItem(at: root) }
    try simulation.saveCheckpoint(to: root)
    try Data([0, 1, 2, 3]).write(
      to: root.appendingPathComponent("populations.lzfse")
    )
    #expect(throws: BirdFlowCheckpointError.self) {
      _ = try BirdFlowSimulation(checkpointURL: root)
    }
  }
#endif

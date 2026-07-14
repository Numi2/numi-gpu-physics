@testable import BirdFlowMetal
import Foundation
import Testing

private var measuredWingSurfaceURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent(
            "ValidationInputs/maeda-hovering-right-wing-surface-v1.json"
        )
}

@Test
func measuredWingSurfaceLoaderLocksPeriodicMeasuredGeometry() throws {
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: measuredWingSurfaceURL
    )
    #expect(dataset.datasetIdentifier == "maeda-2017-hovering-right-wing-surface-v1")
    #expect(dataset.scientificTier == "measured-wing-only")
    #expect(dataset.frameCount == 17)
    #expect(dataset.chordCount == 21)
    #expect(dataset.spanCount == 41)
    #expect(dataset.verticesPerFrame == 861)
    #expect(!dataset.completeBirdReplayReady)
    #expect(
        dataset.inputSHA256
            == "5de3e1d9377ad652ab88d2f460287affd6055c69691e32f120d74cdf79628887"
    )
    #expect(abs(dataset.maximumPointSpeedMetersPerSecond - 11.151_796) < 1e-5)

    let point = dataset.verticesPerFrame - 1
    let first = dataset.state(phase: dataset.phases[0], pointIndex: point)
    let wrapped = dataset.state(
        phase: dataset.phases[0] + 1,
        pointIndex: point
    )
    let source = dataset.vertex(
        frame: 0,
        chord: dataset.chordCount - 1,
        span: dataset.spanCount - 1
    )
    for component in 0..<3 {
        #expect(abs(first.positionMeters[component] - source[component]) < 1e-7)
        #expect(
            abs(first.positionMeters[component] - wrapped.positionMeters[component])
                < 1e-7
        )
        #expect(
            abs(
                first.velocityMetersPerSecond[component]
                    - wrapped.velocityMetersPerSecond[component]
            ) < 1e-5
        )
    }
}

@Test
func measuredWingPublishedFluidConditionLocksPaperConvention() throws {
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: measuredWingSurfaceURL
    )
    let condition = MetalMeasuredWingFluidCondition.dong2022Published
    #expect(condition.sourceDOI == "10.1155/2022/5433184")
    #expect(abs(condition.reynoldsNumber - 9_367.4) < 1.0e-3)
    #expect(
        abs(condition.physicalAirDensityKilogramsPerCubicMeter - 1.205)
            < 1.0e-6
    )
    #expect(
        abs(condition.referenceSpeedMetersPerSecond(for: dataset) - 7.1758)
            < 1.0e-6
    )
}

#if canImport(Metal)
@Test
func measuredWingSurfaceMetalPhasesMatchCPUAndCloseTopology() throws {
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: measuredWingSurfaceURL
    )
    let report = try MetalFlappingWingValidator.auditMeasuredSurface(dataset)
    #expect(report.passed)
    #expect(report.phaseAudits.count == 17)
    #expect(report.maximumLatticePointSpeed <= 0.08)
    #expect(report.maximumPreparedPositionErrorMeters <= 2e-6)
    #expect(report.maximumPreparedVelocityErrorMetersPerSecond <= 2e-3)
    #expect(report.phaseAudits.allSatisfy { $0.solidCellCount > 0 })
    #expect(report.phaseAudits.allSatisfy {
        $0.minimumBoundaryLinkFraction >= 0.999e-4
            && $0.maximumBoundaryLinkFraction <= 1
    })
    #expect(!report.fluidCycleExecuted)
    #expect(!report.completeBirdReplayReady)
}

@Test
func measuredWingSurfaceTwelveCellDomainClearsControlVolumeAndSponge() throws {
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: measuredWingSurfaceURL
    )
    let report = try MetalFlappingWingValidator.auditMeasuredSurface(
        dataset,
        chordCells: 12
    )
    #expect(report.passed)
    #expect(report.chordCells == 12)
    #expect(report.phaseAudits.allSatisfy { $0.solidCellCount > 0 })
}

@Test
func measuredWingSurfaceThicknessEnvelopeIsReportedWithoutHidingEndpoints() throws {
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: measuredWingSurfaceURL
    )
    let report = try MetalFlappingWingValidator
        .auditMeasuredSurfaceThicknessSensitivity(dataset)
    #expect(report.cases.map(\.halfThicknessCells) == [0.5, 0.75, 1.0])
    #expect(report.allCaseGeometryAndFluidPassed)
    #expect(
        abs(
            report.maximumPairwiseRelativeMeanForceVectorDifference
                - 0.067_416_4
        ) < 5e-4
    )
    #expect(
        abs(report.relativeMeanVerticalForceEnvelope - 0.051_81) < 5e-4
    )
    #expect(report.classification == "numerical-thickness-sensitive")
    #expect(!report.passed)
}

@Test
func measuredWingStationarityKeepsIndependentCycleHistories() throws {
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: measuredWingSurfaceURL
    )
    let report = try MetalFlappingWingValidator.runMeasuredSurfaceStationarity(
        dataset,
        chordCells: 8,
        cycles: 2
    )
    #expect(report.cycles == 2)
    #expect(report.cycleSteps == 1_992)
    #expect(report.phaseSamples.count == 100)
    #expect(report.penultimateCycleMeanForceNewtons.count == 3)
    #expect(report.finalCycleMeanForceNewtons.count == 3)
    #expect(report.relativeMeanForceVectorDifference.isFinite)
    #expect(report.relativeMeanVerticalForceDifference.isFinite)
    #expect(report.normalizedPhaseResolvedForceDifference.isFinite)
    #expect(report.phaseSamples.allSatisfy {
        $0.penultimateCycleForceNewtons.allSatisfy(\.isFinite)
            && $0.finalCycleForceNewtons.allSatisfy(\.isFinite)
    })
}
#endif

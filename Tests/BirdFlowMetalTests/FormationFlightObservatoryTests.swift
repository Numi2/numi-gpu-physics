@testable import BirdFlowMetal
import Foundation
import Testing

@Test
func formationFlightMetalPipelinesCompile() throws {
    #if canImport(Metal)
    let backend = try MetalBackend(fastMath: false)
    #expect(
        try backend.pipeline(named: "buildPrescribedFormationWings")
            .maxTotalThreadsPerThreadgroup > 0
    )
    #expect(
        try backend.pipeline(named: "capturePrescribedFormationLoad")
            .maxTotalThreadsPerThreadgroup >= 256
    )
    #expect(
        try backend.pipeline(
            named: "capturePrescribedFormationLoadComponent"
        ).maxTotalThreadsPerThreadgroup >= 256
    )
    #expect(
        try backend.pipeline(
            named: "capturePrescribedFormationBoundarySourceCensus"
        ).maxTotalThreadsPerThreadgroup >= 256
    )
    #expect(
        try backend.pipeline(
            named: "reduceFormationBoundarySourceCensus"
        ).maxTotalThreadsPerThreadgroup > 0
    )
    #expect(
        try backend.pipeline(
            named: "storeFormationBoundarySourceCensus"
        ).maxTotalThreadsPerThreadgroup > 0
    )
    #expect(
        try backend.pipeline(named: "captureFormationFlowSlice")
            .maxTotalThreadsPerThreadgroup > 0
    )
    #endif
}

@Test
func formationFlightFieldPhasesRequireAnArchive() {
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.run(
            configuration: FormationFlightConfiguration(),
            fieldCapturePhases: [0.25]
        )
    }
}

@Test
func formationFlightConfigurationRoundTrips() throws {
    let source = FormationFlightConfiguration(
        chordCells: 8,
        cycles: 3,
        followerOffsetChords: SIMD3(1.5, -0.5, -4),
        followerPhaseOffsetCycles: 0.375
    )
    let decoded = try JSONDecoder().decode(
        FormationFlightConfiguration.self,
        from: JSONEncoder().encode(source)
    )
    #expect(decoded.chordCells == source.chordCells)
    #expect(decoded.cycles == source.cycles)
    #expect(decoded.followerOffsetChords == source.followerOffsetChords)
    #expect(
        decoded.followerPhaseOffsetCycles
            == source.followerPhaseOffsetCycles
    )
}

@Test
func formationFlightRejectsUnderresolvedOrOverlappingRoots() {
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.run(
            configuration: FormationFlightConfiguration(
                chordCells: 4,
                cycles: 1,
                followerOffsetChords: SIMD3(0, 0, -4)
            )
        )
    }
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.run(
            configuration: FormationFlightConfiguration(
                chordCells: 8,
                cycles: 1,
                followerOffsetChords: SIMD3(0, 0, -0.5)
            )
        )
    }
}

@Test
func formationFlightUsesNumericalInsteadOfArbitraryQualityCeilings() {
    #if canImport(Metal)
    do {
        _ = try MetalFormationFlightValidator.run(
            configuration: FormationFlightConfiguration(
                chordCells: 25,
                cycles: 10_000,
                followerOffsetChords: SIMD3(0, 0, -4)
            )
        )
        Issue.record("expected exact-timestep representability rejection")
    } catch let error as FormationFlightValidationError {
        #expect(error.description.contains("exact Float timestep representation"))
        #expect(!error.description.contains("24"))
        #expect(!error.description.contains("20 cycles"))
    } catch {
        Issue.record("unexpected error: \(error)")
    }
    #endif
}

@Test
func formationFieldReplayFailsClosedBeforeAllocatingMetal() {
    let configuration = FormationFlightConfiguration()
    let leader = FormationFlyerPowerSummary(
        flyer: .leader,
        meanSignedPowerWatts: 1,
        meanPositivePowerWatts: 1,
        rmsPowerWatts: 1,
        maximumPositivePowerWatts: 1,
        meanLiftCoefficient: 1,
        meanDragCoefficient: 1
    )
    let follower = FormationFlyerPowerSummary(
        flyer: .follower,
        meanSignedPowerWatts: 1,
        meanPositivePowerWatts: 1,
        rmsPowerWatts: 1,
        maximumPositivePowerWatts: 1,
        meanLiftCoefficient: 1,
        meanDragCoefficient: 1
    )
    let sample = FormationFlightPhaseSample(
        leaderPhase: 0.005,
        followerPhase: 0.255,
        leaderLiftCoefficient: 1,
        followerLiftCoefficient: 1,
        leaderDragCoefficient: 1,
        followerDragCoefficient: 1,
        leaderSignedPowerWatts: 1,
        followerSignedPowerWatts: 1,
        leaderForceNewtons: .zero,
        followerForceNewtons: .zero
    )
    let gates = FormationFlightGateReport(
        finite: true,
        noGeometryOverlap: true,
        ownerForceClosurePassed: true,
        ownerTorqueClosurePassed: true,
        isolatedOwnerClosurePassed: true,
        periodicPowerPassed: true,
        maximumRelativeForceClosureResidual: 0,
        maximumRelativeTorqueClosureResidual: 0,
        maximumIsolatedRelativeClosureResidual: 0,
        maximumAllowedRelativeClosureResidual: 2e-4,
        maximumRelativePeriodicPowerDifference: 0,
        maximumAllowedRelativePeriodicPowerDifference: 0.2,
        passed: true
    )
    let reference = FormationFlightReport(
        schemaVersion: 1,
        scientificScope: "test fixture",
        deviceName: "test",
        configuration: configuration,
        gridX: 80,
        gridY: 80,
        gridZ: 112,
        cycleSteps: 2_142,
        runtimeSeconds: 0,
        coupledLeader: leader,
        coupledFollower: follower,
        isolatedLeader: leader,
        isolatedFollower: follower,
        leaderPositivePowerChangeFraction: 0,
        followerPositivePowerChangeFraction: 0,
        followerPositivePowerSavingFraction: 0,
        systemPositivePowerChangeFraction: 0,
        overlapVoxelSamples: 0,
        phaseSamples: Array(repeating: sample, count: 100),
        gates: gates,
        scientificVerdict: "test fixture"
    )
    let archive = URL(
        fileURLWithPath: NSTemporaryDirectory(),
        isDirectory: true
    )
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.replayFields(
            configuration: configuration,
            referenceReport: reference,
            referenceReportSHA256: String(repeating: "0", count: 64),
            archiveDirectory: archive,
            fieldCapturePhases: []
        )
    }
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.replayFields(
            configuration: configuration,
            referenceReport: reference,
            referenceReportSHA256: "not-a-sha",
            archiveDirectory: archive,
            fieldCapturePhases: [0.805],
            captureMechanismProbes: true,
            captureBoundarySourceCensus: true
        )
    }
}

@Test
func formationCollisionDiagnosticFailsClosedBeforeAllocatingMetal() {
    let archive = URL(
        fileURLWithPath: NSTemporaryDirectory(),
        isDirectory: true
    )
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.runCollisionDiagnostic(
            configuration: FormationFlightConfiguration(),
            collisionOperator: .productionTRT,
            archiveDirectory: archive,
            fieldCapturePhases: [0.805]
        )
    }
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.runCollisionDiagnostic(
            configuration: FormationFlightConfiguration(),
            collisionOperator:
                .positivityPreservingRecursiveRegularizedBGK,
            archiveDirectory: archive,
            fieldCapturePhases: []
        )
    }
}

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

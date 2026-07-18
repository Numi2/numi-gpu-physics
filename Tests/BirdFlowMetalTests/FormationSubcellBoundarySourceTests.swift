import BirdFlowMetal
import Foundation
import Testing

@Test("formation subcell source census rejects offsets outside one lattice cell")
func formationSubcellSourceRejectsInvalidOffset() throws {
    let archive = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    #expect(throws: FormationFlightValidationError.self) {
        try MetalFormationFlightValidator.runSubcellBoundarySourceCensus(
            configuration: FormationFlightConfiguration(),
            subcellOffsetCells: SIMD3(0.25, 1.0, 0.75),
            leaderPhase: 0.785,
            archiveDirectory: archive
        )
    }
}

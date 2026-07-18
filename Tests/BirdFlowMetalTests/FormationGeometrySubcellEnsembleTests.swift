import BirdFlowMetal
import Testing

@Test("formation subcell ensemble decision thresholds are frozen")
func formationSubcellDecisionThresholds() {
    #expect(
        FormationGeometrySubcellDecision.classify(
            meanDensityBetweenEndpoints: true,
            meanDensityCurvature: 0.5,
            meanDirectionCurvature: 0.3,
            meanArealProfileCurvature: 0.4
        ) == .aliasingAveragedOut
    )
    #expect(
        FormationGeometrySubcellDecision.classify(
            meanDensityBetweenEndpoints: false,
            meanDensityCurvature: 0.2,
            meanDirectionCurvature: 0.2,
            meanArealProfileCurvature: 0.2
        ) == .persistentResolutionBias
    )
    #expect(
        FormationGeometrySubcellDecision.classify(
            meanDensityBetweenEndpoints: true,
            meanDensityCurvature: 0.7,
            meanDirectionCurvature: 0.6,
            meanArealProfileCurvature: 0.8
        ) == .mixedSubcellSensitivity
    )
}

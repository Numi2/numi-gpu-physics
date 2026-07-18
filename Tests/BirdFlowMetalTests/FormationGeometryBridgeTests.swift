import BirdFlowMetal
import Testing

@Test("formation geometry bridge decision thresholds are frozen")
func formationGeometryBridgeDecisionThresholds() {
    #expect(
        FormationGeometryBridgeDecision.classify(
            densityBetweenEndpoints: true,
            densityCurvature: 0.5,
            directionCurvature: 0.49,
            arealProfileCurvature: 0.1
        ) == .monotonicGeometryBridge
    )
    #expect(
        FormationGeometryBridgeDecision.classify(
            densityBetweenEndpoints: false,
            densityCurvature: 0.1,
            directionCurvature: 0.1,
            arealProfileCurvature: 0.1
        ) == .latticePhaseAliasingSuspected
    )
    #expect(
        FormationGeometryBridgeDecision.classify(
            densityBetweenEndpoints: true,
            densityCurvature: 0.75,
            directionCurvature: 0.75,
            arealProfileCurvature: 0.75
        ) == .mixedGeometryBridge
    )
}

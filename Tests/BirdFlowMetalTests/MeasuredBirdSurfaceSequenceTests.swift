@testable import BirdFlowMetal
import Foundation
import Testing

private var repositoryRootURL: URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private var measuredBirdSurfaceManifestURL: URL {
    repositoryRootURL
        .appendingPathComponent(
            "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
        )
}

private var measuredBirdForceTargetURL: URL {
    repositoryRootURL
        .appendingPathComponent(
            "ValidationInputs/deetjen-ob-f03-force-v1.json"
        )
}

@Test
func measuredBirdSurfaceLoaderLocksIndexedNonperiodicContract() throws {
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    #expect(
        dataset.datasetIdentifier
            == "deetjen-ob-2018-12-11-f03-complete-surface-v1"
    )
    #expect(dataset.scientificTier == "derived-measured-complete-surface")
    #expect(dataset.sourceLicense == "CC0-1.0")
    #expect(dataset.frameCount == 144)
    #expect(dataset.vertexCount == 2_157)
    #expect(dataset.triangleCount == 3_968)
    #expect(
        dataset.components.map(\.name) == [
            "body", "leftWing", "rightWing", "tail",
        ])
    #expect(dataset.components.map(\.partIdentifier) == [1, 2, 3, 4])
    #expect(dataset.trianglePartIdentifiers.count == 3_968)
    #expect(dataset.completeBirdSurfaceReady)
    #expect(!dataset.quantitativeForceAcceptanceReady)
    #expect(
        dataset.manifestSHA256
            == "ad42148aa9ee72d994d668ba16f8b6572cb8b192b77539fe66d97586ed9e1a13"
    )
    #expect(
        abs(dataset.maximumPointSpeedMetersPerSecond - 25.230_47) < 1e-4
    )

    for frame in [0, 33, 89, 126, 143] {
        let vertex = dataset.components[frame == 143 ? 3 : 1].vertexOffset
        let state = dataset.state(
            timeSeconds: dataset.frameTimesSeconds[frame],
            vertexIndex: vertex
        )
        let source = dataset.vertex(frame: frame, index: vertex)
        #expect(vectorError(state.positionMeters, source) < 1e-7)
        #expect(state.velocityMetersPerSecond.x.isFinite)
        #expect(state.velocityMetersPerSecond.y.isFinite)
        #expect(state.velocityMetersPerSecond.z.isFinite)
    }
}

@Test
func measuredBirdSurfaceLoaderRejectsBinaryDrift() throws {
    let sourceDirectory =
        measuredBirdSurfaceManifestURL
        .deletingLastPathComponent()
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: temporaryDirectory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    for name in ["manifest.json", "positions.f32le", "triangles.u16le"] {
        try FileManager.default.copyItem(
            at: sourceDirectory.appendingPathComponent(name),
            to: temporaryDirectory.appendingPathComponent(name)
        )
    }
    let positionsURL = temporaryDirectory.appendingPathComponent(
        "positions.f32le"
    )
    var positions = try Data(contentsOf: positionsURL)
    positions[0] ^= 0x1
    try positions.write(to: positionsURL)
    #expect(throws: MeasuredBirdSurfaceSequenceError.self) {
        _ = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: temporaryDirectory.appendingPathComponent(
                "manifest.json"
            )
        )
    }
}

@Test
func measuredBirdForceTargetLocksAxesTimingAndCoreWindow() throws {
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    #expect(target.sampleCount == 287)
    #expect(target.comparisonSampleCount == 187)
    #expect(target.comparisonFirstSourceFrame == -1_918)
    #expect(target.comparisonLastSourceFrame == -1_825)
    #expect(target.comparisonFirstSampleIndex == 50)
    #expect(target.comparisonLastSampleIndex == 236)
    #expect(abs(target.comparisonFirstTimeSeconds - 0.025) <= 1e-12)
    #expect(abs(target.comparisonLastTimeSeconds - 0.118) <= 1e-12)
    #expect(target.forceXNewtons.count == target.sampleCount)
    #expect(target.forceZNewtons.count == target.sampleCount)
    #expect(
        target.targetSHA256
            == "0ec3caf21e4b22c2f7dd81e9d5b129fec2d0535dac147d486446975144d6b12c"
    )
}

@Test
func deetjenThroughFlightPlanPreservesMeasuredBodyTranslation() throws {
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let plan = try MetalIndexedBirdSurfacePilotValidator
        .deetjenThroughFlightPlan(surface: surface, target: target)
    #expect(plan.totalFluidSteps == 4_576)
    #expect(plan.fluidStepsPerForceSample == 16)
    #expect(
        plan.totalFluidSteps / plan.fluidStepsPerForceSample
            == target.sampleCount - 1
    )
    #expect(
        abs(
            Double(plan.totalFluidSteps) * plan.fluidTimeStepSeconds
                - 0.143
        ) <= 1e-12
    )

    let start = surface.bodyState(
        timeSeconds: surface.frameTimesSeconds.first!
    )
    let end = surface.bodyState(
        timeSeconds: surface.frameTimesSeconds.last!
    )
    let displacement = end.positionMeters - start.positionMeters
    #expect(abs(displacement.x - 0.187_064) <= 2e-6)
    #expect(abs(displacement.y - 0.044_940_2) <= 2e-6)
    #expect(abs(displacement.z + 0.008_276_66) <= 2e-6)
    #expect(displacement.x > 0)
    #expect(start.velocityMetersPerSecond.x.isFinite)
    #expect(end.velocityMetersPerSecond.x.isFinite)

    var bodyTravel: Float = 0
    var previousBodyPosition = start.positionMeters
    for frameTime in surface.frameTimesSeconds.dropFirst() {
        let bodyPosition = surface.bodyState(
            timeSeconds: frameTime
        ).positionMeters
        let segment = bodyPosition - previousBodyPosition
        bodyTravel += sqrt(
            segment.x * segment.x
                + segment.y * segment.y
                + segment.z * segment.z
        )
        previousBodyPosition = bodyPosition
    }
    let endpointDistance = sqrt(
        displacement.x * displacement.x
            + displacement.y * displacement.y
            + displacement.z * displacement.z
    )
    #expect(abs(bodyTravel - 0.241_865) <= 2e-6)
    #expect(bodyTravel > endpointDistance)
}

@Test
func measuredBirdCoarsePilotPlanLocksCostAndClaimBoundary() throws {
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let plan = try MetalIndexedBirdSurfacePilotValidator.plan(
        surface: surface,
        target: target
    )
    #expect(plan.fluidStepsPerForceSample == 16)
    #expect(abs(plan.fluidTimeStepSeconds - 0.000_031_25) <= 1e-12)
    #expect(plan.preRollFluidSteps == 800)
    #expect(plan.totalFluidSteps == 3_776)
    #expect(plan.comparisonForceSamples == 187)
    #expect(plan.maximumWallMach <= 0.15)
    #expect(!plan.sourceViscosityRepresentableAtPilotGrid)
    #expect(plan.sourceConditionTauPlusAtPilotGrid < plan.minimumAllowedTauPlus)
    #expect(plan.pilotToSourceViscosityRatio > 1)
    #expect(!plan.experimentalAgreementGateApplied)
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionPreRollPopulationDiagnosticStride == 1
    )
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionPreRollMaximumActivationFraction == 0.05
    )
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionMomentumMaximumRelativeRMSResidual == 0.005
    )
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionExtendedPilotPopulationDiagnosticStride == 1
    )
    let operators = MetalIndexedBirdSurfacePilotValidator
        .collisionPreRollOperators
    #expect(
        operators.map(\.rawValue) == [
            "production-trt",
            "positivity-preserving-regularized-bgk",
            "positivity-preserving-recursive-regularized-bgk",
        ])
    #expect(operators.map(\.caseParameterW) == [-1, -3, -4])
    #expect(
        MetalIndexedBirdSurfacePilotValidator
            .collisionMomentumCandidateOperators.map(\.rawValue) == [
                "positivity-preserving-regularized-bgk",
                "positivity-preserving-recursive-regularized-bgk",
            ]
    )

    let refinement = try [8, 12, 16].map {
        try MetalIndexedBirdSurfacePilotValidator.refinementPlan(
            surface: surface,
            target: target,
            referenceLengthCells: $0
        )
    }
    #expect(refinement.map(\.fluidStepsPerForceSample) == [16, 24, 32])
    #expect(refinement.map(\.preRollFluidSteps) == [800, 1_200, 1_600])
    #expect(refinement.map(\.totalFluidSteps) == [3_776, 5_664, 7_552])
    #expect(refinement.map(\.paddingCells) == [12, 18, 24])
    #expect(refinement.map(\.spongeWidthCells) == [6, 9, 12])
    #expect(abs(refinement[0].halfThicknessCells - 0.75) < 1e-6)
    #expect(abs(refinement[1].halfThicknessCells - 1.125) < 1e-6)
    #expect(abs(refinement[2].halfThicknessCells - 1.5) < 1e-6)
    #expect(abs(refinement[0].pilotTauPlus - 0.501) < 1e-6)
    #expect(abs(refinement[1].pilotTauPlus - 0.5015) < 1e-6)
    #expect(abs(refinement[2].pilotTauPlus - 0.502) < 1e-6)
    #expect(
        refinement.allSatisfy {
            abs($0.maximumWallMach - refinement[0].maximumWallMach) < 1e-6
                && abs(
                    $0.pilotToSourceViscosityRatio
                        - refinement[0].pilotToSourceViscosityRatio) < 1e-4
                && !$0.experimentalAgreementGateApplied
        }
    )
    let preregistration =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridPreregistration(surface: surface, target: target)
    #expect(preregistration.passed)
    #expect(preregistration.discriminatorReferenceLengthCells == [8, 12])
    #expect(preregistration.completionReferenceLengthCells == 16)
    #expect(
        preregistration.crossCanonicalEvidence.map(
            \.crossCanonicalGatePassed
        ) == [false, true]
    )
    #expect(!preregistration.experimentalAgreementGateApplied)
}

@Test
func measuredBirdCollisionGridArtifactsRetainAuthorizedD16Failure() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let preregistration = try decode(
        "deetjen-dove-collision-grid-preregistration.json",
        as: MetalIndexedBirdSurfaceCollisionGridPreregistration.self
    )
    let discriminator = try decode(
        "deetjen-dove-collision-grid-discriminator.json",
        as: MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self
    )
    let completion = try decode(
        "deetjen-dove-collision-grid-completion.json",
        as: MetalIndexedBirdSurfaceCollisionGridCompletionReport.self
    )
    let recursive = "positivity-preserving-recursive-regularized-bgk"
    #expect(preregistration.passed)
    #expect(discriminator.preregistration == preregistration)
    #expect(discriminator.cases.count == 4)
    #expect(Set(discriminator.cases.map(\.referenceLengthCells)) == [8, 12])
    #expect(discriminator.cases.allSatisfy { $0.eligibleForSelection })
    #expect(discriminator.selectedCollisionOperator == recursive)
    #expect(discriminator.d16CompletionAuthorized)
    #expect(discriminator.screeningGatePassed)
    #expect(
        discriminator.d12OperatorPairwiseNormalizedRMSDifference!
            < discriminator.d8OperatorPairwiseNormalizedRMSDifference!
    )
    #expect(completion.selectedCollisionOperator == recursive)
    #expect(completion.d16Case.collisionOperator == recursive)
    #expect(completion.d16Case.referenceLengthCells == 16)
    #expect(completion.d16Case.report.plan.totalFluidSteps == 7_552)
    #expect(completion.d16Case.report.completedFluidSteps == 751)
    #expect(completion.d16Case.report.firstNegativePopulationStep == 751)
    #expect(completion.d16Case.report.firstNegativePopulationDirection == 0)
    #expect(completion.d16Case.report.allLoadsFinite)
    #expect(completion.d16Case.report.allSampledPopulationsFinite)
    #expect(!completion.d16Case.report.sampledPopulationPositivityPassed)
    #expect(!completion.d16Case.completionAndPositivityGatePassed)
    #expect(completion.d16Case.correctionIntrusionGatePassed)
    #expect(!completion.completionGatePassed)
    #expect(!completion.fineGridForceConvergencePassed)
    #expect(completion.d12ToD16IntervalForceNormalizedRMSDifference == nil)
    #expect(!completion.experimentalAgreementGateApplied)
}

@Test
func measuredBirdD16PopulationProvenanceRetainsFirstWriter() throws {
    let report = try JSONDecoder().decode(
        MetalIndexedBirdSurfacePopulationStageProvenanceReport.self,
        from: Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json"
            ))
    )
    #expect(
        report.selectedCollisionOperator
            == "positivity-preserving-recursive-regularized-bgk")
    #expect(report.referenceLengthCells == 16)
    #expect(report.targetCellCoordinate == SIMD3(64, 63, 68))
    #expect(report.targetDirection == 0)
    #expect(report.capturedSteps == [747, 748, 749, 750, 751])
    #expect(!report.productionStateModifiedByDiagnostic)
    #expect(report.maximumPredictionAbsoluteError == 0)
    #expect(report.firstNegativeCapturedStage == "post-collision")
    #expect(report.firstNegativeCapturedStep == 751)
    #expect(
        report.selectedDirectionRemainedPositiveThroughReconstructionAtFailure
    )
    #expect(
        report.negativeReconstructedDirectionsAtFailure
            == [2, 8, 12, 13, 16])
    #expect(
        report.negativeMovingBoundaryReconstructedDirectionsAtFailure
            == [2, 8, 12, 13, 16])
    #expect(report.upstreamMovingBoundaryReconstructionPresentAtFailure)
    #expect(!report.targetDirectionMovingBoundaryReconstructedAtFailure)
    #expect(!report.topologyRefillAtFailure)
    #expect(!report.farFieldUsedAtFailure)
    #expect(!report.spongeUsedAtFailure)
    #expect(!report.equilibriumReferencePositiveAtFailure)
    #expect(report.provenanceGatePassed)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(report.samples.count == 5)
    let failure = try #require(report.samples.last)
    #expect(failure.preStepPopulation > 0)
    #expect(failure.reconstructedDirectionPopulation > 0)
    #expect(
        failure.reconstructedSpeedLattice
            > failure.restEquilibriumPositivitySpeedLimit)
    #expect(failure.equilibriumDirectionPopulation < 0)
    #expect(failure.positivityScale == 0)
    #expect(failure.postCollisionDirectionPopulation < 0)
    #expect(
        failure.actualOutputDirectionPopulation
            == failure.postCollisionDirectionPopulation)
    #expect(failure.predictionAbsoluteError == 0)
}

@Test
func measuredBirdD16BoundaryTermsRetainWallCorrectionDiscriminator() throws {
    let report = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self,
        from: Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-d16-boundary-term-decomposition.json"
            ))
    )
    let failureDirections = [2, 8, 12, 13, 16]
    #expect(
        report.selectedCollisionOperator
            == "positivity-preserving-recursive-regularized-bgk")
    #expect(report.referenceLengthCells == 16)
    #expect(report.targetCellCoordinate == SIMD3(64, 63, 68))
    #expect(report.capturedSteps == [750, 751])
    #expect(!report.productionStateModifiedByDiagnostic)
    #expect(report.maximumContributionClosureResidual < 1e-9)
    #expect(report.maximumReconstructionDifferenceFromStageArtifact < 1e-9)
    #expect(report.negativeMovingBoundaryDirectionsPreviousStep == [2, 3, 10])
    #expect(
        report.negativeMovingBoundaryDirectionsAtFailure
            == failureDirections)
    #expect(report.directionsWithNegativeReflectedPopulation.isEmpty)
    #expect(report.directionsWithNegativeAuxiliaryContribution.isEmpty)
    #expect(
        report.directionsWithNegativeWallContribution
            == failureDirections)
    #expect(report.directionsMadeNonnegativeByHalfwayMovingWall.isEmpty)
    #expect(
        report.directionsMadeNonnegativeByInterpolatedZeroWall
            == failureDirections)
    #expect(
        report.directionsMadeNonnegativeByHalfwayZeroWall
            == failureDirections)
    #expect(report.directionsMadeNonnegativeByRemovingAuxiliary.isEmpty)
    #expect(report.directionsRemainingNegativeUnderHalfwayZeroWall.isEmpty)
    #expect(report.dominantRepairTarget == "moving-wall-correction")
    #expect(report.boundaryTermGatePassed)
    #expect(!report.experimentalAgreementGateApplied)
    let failure = report.samples.filter {
        $0.step == 751 && $0.productionPopulationNegative
    }
    #expect(failure.map(\.direction) == failureDirections)
    #expect(
        failure.allSatisfy {
            $0.reflectedPopulation > 0
                && $0.auxiliaryContribution >= 0
                && $0.wallCorrectionContribution < 0
                && $0.productionReconstructedPopulation < 0
                && $0.interpolatedZeroWallPopulation > 0
                && $0.halfwayZeroWallPopulation > 0
                && $0.halfwayMovingWallPopulation < 0
                && $0.dominantNegativeContribution == "wall-correction"
        })
    #expect(failure.filter { $0.branch == "halfway-fallback" }.count == 4)
    #expect(
        failure.filter { $0.branch == "interpolated-far-wall" }
            .map(\.direction) == [12])
}

@Test
func measuredBirdD16MovingWallAdmissibilityRetainsLedgerBoundary() throws {
    let report = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport.self,
        from: Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-d16-moving-wall-admissibility-ab.json"
            ))
    )
    let failureDirections = [2, 8, 12, 13, 16]
    #expect(report.referenceLengthCells == 16)
    #expect(report.targetCellCoordinate == SIMD3(64, 63, 68))
    #expect(report.failureStep == 751)
    #expect(report.sourceBoundaryTermGatePassed)
    #expect(report.sourcePopulationProvenanceGatePassed)
    #expect(!report.productionStateModifiedByDiagnostic)
    #expect(!report.fluidSimulationRerun)
    #expect(report.preStepPopulationCoverageDirections == Array(0..<19))
    #expect(abs(report.preStepLocalDensity - 0.030_192_742_6) < 1e-10)
    #expect(abs(report.selfConsistentLocalDensity - 0.034_896_398_1) < 1e-10)
    #expect(
        report.referenceDensityBaseline.negativePopulationDirections
            == failureDirections)
    #expect(!report.referenceDensityBaseline.populationGatePassed)
    #expect(!report.referenceDensityBaseline.equilibriumGatePassed)
    #expect(
        report.candidateA.identifier
            == "pre-step-local-density-normalization")
    #expect(
        report.candidateA.correctionScaleRelativeToReferenceDensity
            == report.preStepLocalDensity)
    #expect(!report.candidateA.positivityInterventionActive)
    #expect(report.candidateA.negativePopulationDirections.isEmpty)
    #expect(report.candidateA.populationFloorViolationDirections.isEmpty)
    #expect(report.candidateA.minimumPopulation > 5.5e-5)
    #expect(report.candidateA.populationGatePassed)
    #expect(report.candidateA.equilibriumGatePassed)
    #expect(report.candidateB.positivityInterventionActive)
    #expect(report.candidateB.populationGatePassed)
    #expect(report.candidateB.equilibriumGatePassed)
    #expect(
        report.candidateA.correctionScaleRelativeToReferenceDensity
            < report.globalPositivityAdmissibilityScale)
    #expect(report.selfConsistentDensityCrosscheck.populationGatePassed)
    #expect(report.selfConsistentDensityCrosscheck.equilibriumGatePassed)
    #expect(
        report.candidateAuthorizedForProductionLedger
            == report.candidateA.identifier)
    #expect(report.admissibilityABGatePassed)
    #expect(!report.experimentalAgreementGateApplied)
}

@Test
func measuredBirdD16MovingWallAdmissibilityReconstructsFromArchives() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let report =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallAdmissibilityAB(
            surface: surface,
            target: target,
            preregistration: try decode(
                "deetjen-dove-collision-grid-preregistration.json",
                as: MetalIndexedBirdSurfaceCollisionGridPreregistration.self
            ),
            discriminator: try decode(
                "deetjen-dove-collision-grid-discriminator.json",
                as: MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self
            ),
            completion: try decode(
                "deetjen-dove-collision-grid-completion.json",
                as: MetalIndexedBirdSurfaceCollisionGridCompletionReport.self
            ),
            provenance: try decode(
                "deetjen-dove-d16-population-stage-provenance.json",
                as: MetalIndexedBirdSurfacePopulationStageProvenanceReport.self
            ),
            boundaryTerms: try decode(
                "deetjen-dove-d16-boundary-term-decomposition.json",
                as: MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self
            )
        )
    #expect(report.admissibilityABGatePassed)
    #expect(
        report.referenceDensityBaseline.negativePopulationDirections
            == [2, 8, 12, 13, 16])
    #expect(report.candidateA.negativePopulationDirections.isEmpty)
    #expect(report.candidateB.negativePopulationDirections.isEmpty)
    #expect(
        report.candidateAuthorizedForProductionLedger
            == "pre-step-local-density-normalization")
}

@Test
func measuredBirdD16MovingWallLedgerRetainsPromotionBoundary() throws {
    let report = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceMovingWallLedgerReport.self,
        from: Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-d16-moving-wall-ledger.json"
            ))
    )
    #expect(report.schemaVersion == 1)
    #expect(
        report.selectedCollisionOperator
            == "positivity-preserving-recursive-regularized-bgk")
    #expect(
        report.sourceAdmissibilityCandidateIdentifier
            == "pre-step-local-density-normalization")
    #expect(report.movingWallNormalization == "pre-step-local-density")
    #expect(report.referenceLengthCells == 16)
    #expect(report.requestedSteps == 751)
    #expect(report.result.completedSteps == 751)
    #expect(report.result.samples.count == 751)
    #expect(report.result.minimumPopulation > 0)
    #expect(report.result.maximumSolidControlSurfaceCrossingLinkCount == 0)
    #expect(report.result.relativeRMSRawControlVolumeClosureResidual <= 0.005)
    #expect(report.result.relativeRMSGlobalFluidClosureResidual <= 0.005)
    #expect(!report.movingWallPositivityLimiterImplemented)
    #expect(report.movingWallPositivityLimiterActivationCount == 0)
    #expect(!report.productionDefaultModified)
    #expect(report.allStepsCompleted)
    #expect(report.populationPositivityPassed)
    #expect(report.forceAndMomentumAccountingPassed)
    #expect(report.collisionCorrectionIntrusionPassed)
    #expect(report.ledgerGatePassed)
    #expect(!report.experimentalAgreementGateApplied)
}

@Test
func measuredBirdD16MovingWallFullWindowRetainsClaimBoundary() throws {
    let report = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceMovingWallFullWindowReport.self,
        from: Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-d16-moving-wall-full-window.json"
            ))
    )
    #expect(report.schemaVersion == 1)
    #expect(report.sourceRetainedLedgerGatePassed)
    #expect(report.sourceRetainedLedgerSteps == 751)
    #expect(
        report.sourceCandidateIdentifier
            == "pre-step-local-density-normalization")
    #expect(
        report.selectedCollisionOperator
            == "positivity-preserving-recursive-regularized-bgk")
    #expect(report.movingWallNormalization == "pre-step-local-density")
    #expect(report.referenceLengthCells == 16)
    #expect(report.requestedSteps == 7_552)
    #expect(report.ledgerResult.completedSteps == 7_552)
    #expect(report.ledgerResult.samples.count == 7_552)
    #expect(report.registeredComparisonSampleCount == 187)
    #expect(report.registeredForceSamples.count == 187)
    #expect(report.ledgerResult.minimumPopulation > 0)
    #expect(report.ledgerResult.maximumSolidControlSurfaceCrossingLinkCount == 0)
    #expect(report.ledgerResult.relativeRMSRawControlVolumeClosureResidual <= 0.005)
    #expect(report.ledgerResult.relativeRMSGlobalFluidClosureResidual <= 0.005)
    #expect(report.normalizedRMSError != nil)
    #expect(!report.movingWallPositivityLimiterImplemented)
    #expect(report.movingWallPositivityLimiterActivationCount == 0)
    #expect(!report.productionDefaultModified)
    #expect(report.allStepsCompleted)
    #expect(report.populationPositivityPassed)
    #expect(report.forceAndMomentumAccountingPassed)
    #expect(report.collisionCorrectionIntrusionPassed)
    #expect(report.registeredWindowComplete)
    #expect(report.fullWindowGatePassed)
    #expect(!report.experimentalAgreementGateApplied)
}

@Test
func measuredBirdMovingWallSpatialArtifactsRetainLockedRejection() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let preregistration = try decode(
        "deetjen-dove-moving-wall-spatial-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallSpatialPreregistration.self
    )
    let d8 = try decode(
        "deetjen-dove-d8-moving-wall-full-window.json",
        as: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport.self
    )
    let d12 = try decode(
        "deetjen-dove-d12-moving-wall-full-window.json",
        as: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport.self
    )
    let report = try decode(
        "deetjen-dove-moving-wall-spatial-discriminator.json",
        as: MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport.self
    )
    #expect(preregistration.passed)
    #expect(preregistration.caseReferenceLengthCells == [8, 12])
    #expect(preregistration.reusedReferenceLengthCells == 16)
    #expect(preregistration.maximumAllowedFineGridRelativeDifference == 0.05)
    #expect(preregistration.requireMonotonicTrendReduction)
    #expect(d8.caseGatePassed)
    #expect(d8.referenceLengthCells == 8)
    #expect(d8.fullWindowReport.ledgerResult.completedSteps == 3_776)
    #expect(d8.fullWindowReport.registeredComparisonSampleCount == 187)
    #expect(d12.caseGatePassed)
    #expect(d12.referenceLengthCells == 12)
    #expect(d12.fullWindowReport.ledgerResult.completedSteps == 5_664)
    #expect(d12.fullWindowReport.registeredComparisonSampleCount == 187)
    #expect(report.allCaseGatesPassed)
    #expect(report.monotonicTrendReductionPassed)
    #expect(!report.fineGridForceConvergencePassed)
    #expect(!report.spatialRefinementGatePassed)
    #expect(!report.productionPromotionAuthorized)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(report.d8ToD12.intervalForceNormalizedRMSDifference > 0.12)
    #expect(report.d12ToD16.intervalForceNormalizedRMSDifference > 0.05)
    #expect(report.d12ToD16.intervalForceNormalizedRMSDifference < 0.07)
    #expect(report.d12ToD16.meanForceRelativeDifference < 0.05)
    #expect(report.d12ToD16.impulseRelativeDifference < 0.05)

    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-spatial-discriminator-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallSpatialDiscriminatorReconstructsFromArchives() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallSpatialDiscriminator(
            surface: surface,
            target: target,
            spatialPreregistration: try decode(
                "deetjen-dove-moving-wall-spatial-preregistration.json",
                as: MetalIndexedBirdSurfaceMovingWallSpatialPreregistration.self
            ),
            sourceSpatialPreregistrationSHA256:
                "741d586251f012c59387479be98234af85a62c1d41c5b92c6cf8accba5bd359a",
            d8Case: try decode(
                "deetjen-dove-d8-moving-wall-full-window.json",
                as: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport.self
            ),
            sourceD8CaseSHA256:
                "aee0fae01f48e48e0af14bc3eec4dc44d6cb5e6500d93f7f04680dc9804863b5",
            d12Case: try decode(
                "deetjen-dove-d12-moving-wall-full-window.json",
                as: MetalIndexedBirdSurfaceMovingWallSpatialCaseReport.self
            ),
            sourceD12CaseSHA256:
                "09975b9619ebfb0b77d3e87a2cca9a907604038320c4579bd41b4ed129d16270",
            d16FullWindow: try decode(
                "deetjen-dove-d16-moving-wall-full-window.json",
                as: MetalIndexedBirdSurfaceMovingWallFullWindowReport.self
            ),
            sourceD16FullWindowSHA256:
                "dfd326dea59fc1c6e87aebb3474e5af6f53e9acb8914a4de4d7a67173820e84c"
        )
    #expect(rebuilt.allCaseGatesPassed)
    #expect(rebuilt.monotonicTrendReductionPassed)
    #expect(!rebuilt.fineGridForceConvergencePassed)
    #expect(!rebuilt.spatialRefinementGatePassed)
    #expect(
        abs(
            rebuilt.d8ToD12.intervalForceNormalizedRMSDifference
                - 0.127_045_351_751_702_2) < 1e-14)
    #expect(
        abs(
            rebuilt.d12ToD16.intervalForceNormalizedRMSDifference
                - 0.062_683_388_119_109_34) < 1e-14)
}

@Test
func measuredBirdMovingWallSpatialLocalizationRetainsD20Rejection() throws {
    func object(_ name: String) throws -> [String: Any] {
        let data = try Data(
            contentsOf:
                repositoryRootURL
                .appendingPathComponent("ValidationArtifacts/\(name)"))
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }
    let report = try object(
        "deetjen-dove-moving-wall-spatial-localization.json"
    )
    let audit = try object(
        "deetjen-dove-moving-wall-spatial-localization-audit.json"
    )
    let force = try #require(report["forceHistory"] as? [String: Any])
    let concentration = try #require(
        report["concentration"] as? [String: Any]
    )
    let smoothness = try #require(
        report["smoothness"] as? [String: Any]
    )
    let topology = try #require(
        report["topologyAssociation"] as? [String: Any]
    )
    let accounting = try #require(
        report["accountingAssociation"] as? [String: Any]
    )
    #expect(report["registeredComparisonBinCount"] as? Int == 187)
    #expect(concentration["classification"] as? String == "mixed")
    #expect(concentration["binsRequiredFor50Percent"] as? Int == 27)
    #expect(report["d20DiagnosticAuthorized"] as? Bool == false)
    #expect(report["productionPromotionAuthorized"] as? Bool == false)
    #expect(report["experimentalAgreementGateApplied"] as? Bool == false)
    #expect(
        abs(
            try #require(
                force["pairwiseNormalizedRMSDifference"] as? Double
            ) - 0.062_683_388_119_109_34) < 1e-14)
    #expect(
        try #require(
            smoothness["normalizedFirstDifferenceRoughness"] as? Double
        ) > 1)
    #expect(
        try #require(
            smoothness["highFrequencyEnergyFraction"] as? Double
        ) > 0.5)
    #expect(topology["topologyEventLikely"] as? Bool == false)
    #expect(accounting["accountingContaminationLikely"] as? Bool == false)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallSpatialLagBandRetainsRawRejection() throws {
    func object(_ name: String) throws -> [String: Any] {
        let data = try Data(
            contentsOf:
                repositoryRootURL
                .appendingPathComponent("ValidationArtifacts/\(name)"))
        return try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }
    let report = try object(
        "deetjen-dove-moving-wall-spatial-lag-band.json"
    )
    let audit = try object(
        "deetjen-dove-moving-wall-spatial-lag-band-audit.json"
    )
    let lag = try #require(report["lagDiscriminator"] as? [String: Any])
    let band = try #require(report["bandDiscriminator"] as? [String: Any])
    let bands = try #require(band["bands"] as? [[String: Any]])
    let decisionBand = try #require(
        bands.first {
            ($0["requestedCutoffHertz"] as? Double) == 200
        })

    #expect(report["registeredComparisonBinCount"] as? Int == 187)
    #expect(report["classification"] as? String == "mixed-unresolved")
    #expect(report["rawLockedGatePassed"] as? Bool == false)
    #expect(report["rawSpatialGateModified"] as? Bool == false)
    #expect(report["d20DiagnosticAuthorized"] as? Bool == false)
    #expect(report["productionPromotionAuthorized"] as? Bool == false)
    #expect(report["experimentalAgreementGateApplied"] as? Bool == false)
    #expect(
        abs(
            try #require(
                report["rawPairwiseNormalizedRMSDifference"] as? Double
            ) - 0.062_683_388_119_109_34) < 1e-14)
    #expect(lag["subBinRegistrationSensitivityLikely"] as? Bool == false)
    #expect(
        try #require(
            lag["crossValidatedImprovementFraction"] as? Double
        ) < 0.02)
    #expect(band["broadbandForceEstimatorNoiseLikely"] as? Bool == false)
    #expect(band["coherentLowBandGridBiasLikely"] as? Bool == false)
    #expect(
        try #require(
            decisionBand["combinedSignalEnergyRetentionFraction"] as? Double
        ) < 0.75)
    #expect(
        try #require(
            decisionBand["pairwiseNormalizedRMSDifference"] as? Double
        ) < 0.05)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallTemporalSamplingLocksMixedResult() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let spatial = try decode(
        "deetjen-dove-moving-wall-spatial-discriminator.json",
        as: MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-temporal-sampling-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallTemporalSamplingPreregistration(
            surface: surface,
            target: target,
            spatialDiscriminator: spatial,
            sourceSpatialDiscriminatorSHA256:
                "e81d99c5fe495434e2aab9e3cb0bfc51ea5bc56ba6ff2cb7506c5c98c824c803",
            sourceLagBandSHA256:
                "f4b7a6db0ff46f1d33c69d1db6d17a0992a164a976557fe29d55bf0694087e6f"
        )
    #expect(preregistration == rebuilt)

    let report = try decode(
        "deetjen-dove-moving-wall-temporal-sampling.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.d12.numericalCaseGatePassed)
    #expect(report.d16.numericalCaseGatePassed)
    #expect(report.d12.maximumTopologyCorrectionNewtons == 0)
    #expect(report.d16.maximumTopologyCorrectionNewtons == 0)
    #expect(report.classification == "mixed-unresolved")
    #expect(!report.temporalAggregationSensitivityLikely)
    #expect(!report.fixedGeometryGridResponseCleared)
    #expect(!report.aggregationInvariantGridDisagreementLikely)
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.productionPromotionAuthorized)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(
        abs(
            report.metrics.endpointPairwiseNormalizedRMSDifference
                - 0.195_868_452_776_605_56
        ) < 1e-14)
    #expect(
        abs(
            report.metrics.impulsePreservingPairwiseNormalizedRMSDifference
                - 0.094_871_223_471_399_73
        ) < 1e-14)
    #expect(report.metrics.endpointToImpulseImprovementFraction > 0.5)
    #expect(report.metrics.directTotalImpulseRelativeDifference < 0.01)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallTemporalDurationLocksPersistentGridResult() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let temporalPreregistration = try decode(
        "deetjen-dove-moving-wall-temporal-sampling-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration.self
    )
    let temporalSampling = try decode(
        "deetjen-dove-moving-wall-temporal-sampling.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-temporal-duration-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallTemporalDurationPreregistration(
            surface: surface,
            target: target,
            temporalPreregistration: temporalPreregistration,
            sourceTemporalPreregistrationSHA256:
                "57e1f231217bf06395cdd1d4f913e73314209327c0892a0938c5481f0bd61c70",
            temporalSampling: temporalSampling,
            sourceTemporalSamplingSHA256:
                "eb5af26e21ad139363c81185ee227cfcc88dc6fd58ff884aa718329dfd11a7ad"
        )
    #expect(preregistration == rebuilt)

    let report = try decode(
        "deetjen-dove-moving-wall-temporal-duration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.baselinePrefixMaximumRelativeError == 0)
    #expect(report.baselinePrefixReproduced)
    #expect(!report.durationCleared)
    #expect(!report.startupRelaxationLikely)
    #expect(report.persistentFixedWallGridDisagreementLikely)
    #expect(
        report.classification
            == "persistent-fixed-wall-grid-disagreement"
    )
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.productionPromotionAuthorized)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(report.prefixWindows.map(\.endBinExclusive) == [8, 16, 24])
    #expect(
        abs(
            report.prefixWindows.last!.metrics
                .impulsePreservingPairwiseNormalizedRMSDifference
                - 0.099_611_216_131_344_9
        ) < 1e-14)
    #expect(
        abs(
            report.blockWindows.last!.metrics
                .impulsePreservingPairwiseNormalizedRMSDifference
                - 0.123_790_709_621_362_95
        ) < 1e-14)
    #expect(report.lateBlockImprovementFraction < 0)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallLinkGeometryLocksVelocityDepositionBias() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let durationPreregistration = try decode(
        "deetjen-dove-moving-wall-temporal-duration-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self
    )
    let duration = try decode(
        "deetjen-dove-moving-wall-temporal-duration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-link-geometry-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkGeometryPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkGeometryPreregistration(
            surface: surface,
            target: target,
            durationPreregistration: durationPreregistration,
            sourceDurationPreregistrationSHA256:
                "8a15ee4877ada2b5b20badf70e2de894832afe11bcd6e95384786076541e3a85",
            durationReport: duration,
            sourceDurationReportSHA256:
                "1257ddad7d5c78fbaf40876074fd847b9b1d410ac4d2ab04a947e6d0240842ae"
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.schemaVersion == 2)
    #expect(preregistration.interpolationFractionBinCount == 20)

    let report = try decode(
        "deetjen-dove-moving-wall-link-geometry.json",
        as: MetalIndexedBirdSurfaceLinkGeometryReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.d12.parityGatePassed)
    #expect(report.d16.parityGatePassed)
    #expect(report.d12.metalCPUMaskMismatchCellCount == 0)
    #expect(report.d16.metalCPUMaskMismatchCellCount == 0)
    #expect(report.d12.metalCPUExactLinkCountMatch)
    #expect(report.d16.metalCPUExactLinkCountMatch)
    #expect(report.metrics.totalLinkMeasureRelativeDifference < 0.02)
    #expect(report.metrics.maximumComponentLinkMeasureRelativeDifference < 0.03)
    #expect(report.metrics.interpolationHistogramTotalVariation < 0.04)
    #expect(
        report.metrics.maximumGridMeanVelocityDifferenceRelativeToQuadratureRMS
            < 0.005
    )
    #expect(
        report.metrics.maximumLinkToQuadratureMeanVelocityError
            > preregistration.maximumAllowedLinkToQuadratureMeanVelocityError
    )
    #expect(!report.wallRepresentationCleared)
    #expect(!report.linkMeasureBiasLikely)
    #expect(!report.interpolationBiasLikely)
    #expect(report.wallVelocityDepositionBiasLikely)
    #expect(report.classification == "wall-velocity-deposition-bias")
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.productionPromotionAuthorized)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallLinkVelocityLocksIntersectionPlacementBias() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let geometryPreregistration = try decode(
        "deetjen-dove-moving-wall-link-geometry-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkGeometryPreregistration.self
    )
    let geometry = try decode(
        "deetjen-dove-moving-wall-link-geometry.json",
        as: MetalIndexedBirdSurfaceLinkGeometryReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-link-velocity-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkVelocityPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkVelocityPreregistration(
            surface: surface,
            target: target,
            linkGeometryPreregistration: geometryPreregistration,
            sourceLinkGeometryPreregistrationSHA256:
                "022ad277bc571bc28f7979d67a66de9c8af8bde2e84429854a4c6b1690295624",
            linkGeometryReport: geometry,
            sourceLinkGeometryReportSHA256:
                "39237cc559c086e3a4f06d36560f17192fa9d5737d2163bc82c2b1a7785dcacf"
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.maximumAllowedOffsetSurfaceMaximumResidualCells == 0.75)

    let report = try decode(
        "deetjen-dove-moving-wall-link-velocity.json",
        as: MetalIndexedBirdSurfaceLinkVelocityReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-link-velocity-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.d12.sourceReproductionPassed)
    #expect(report.d16.sourceReproductionPassed)
    #expect(report.d12.bins.count == 72)
    #expect(report.d16.bins.count == 72)
    #expect(report.metrics.maximumSourceProductionRelativeDifference == 0)
    #expect(report.metrics.maximumOffsetSurfaceRMSResidualCells < 0.10)
    #expect(report.metrics.maximumOffsetSurfaceResidualCells > 0.75)
    #expect(report.metrics.minimumLeftWingExactImprovementFraction < 0)
    #expect(report.metrics.minimumLeftWingEndpointImprovementFraction < 0)
    #expect(!report.intersectionPlacementPassed)
    #expect(!report.exactIntersectionClearsBias)
    #expect(!report.solidNodeSamplingCausal)
    #expect(!report.endpointInterpolationQualified)
    #expect(
        report.classification == "signed-distance-intersection-placement-bias"
    )
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallLinkIntersectionLocksJunctionAssociation() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let velocityPreregistration = try decode(
        "deetjen-dove-moving-wall-link-velocity-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkVelocityPreregistration.self
    )
    let velocity = try decode(
        "deetjen-dove-moving-wall-link-velocity.json",
        as: MetalIndexedBirdSurfaceLinkVelocityReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-link-intersection-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkIntersectionPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkIntersectionPreregistration(
            surface: surface,
            target: target,
            linkVelocityPreregistration: velocityPreregistration,
            sourceLinkVelocityPreregistrationSHA256:
                "d1f98853798601555f009d5073c263172f21f4d86d5d0e64d47d47713c306024",
            linkVelocityReport: velocity,
            sourceLinkVelocityReportSHA256:
                "caac9cc578b3f4c4600fe0059984c519992ef24e4d49f246a2db520f1b528cf4"
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.outlierResidualThresholdCells == 0.75)
    #expect(preregistration.minimumEdgeOrJunctionAssociationFraction == 0.80)

    let report = try decode(
        "deetjen-dove-moving-wall-link-intersection.json",
        as: MetalIndexedBirdSurfaceLinkIntersectionReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-link-intersection-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.sourceReproductionPassed)
    #expect(report.d12.sourceLinkCountMatched)
    #expect(report.d16.sourceLinkCountMatched)
    #expect(report.d12.sourceMaximumResidualDifferenceCells == 0)
    #expect(report.d16.sourceMaximumResidualDifferenceCells == 0)
    #expect(report.d12.outlierCount == 8)
    #expect(report.d16.outlierCount == 7)
    #expect(report.d12.outlierLinkMeasureFraction < 0.0003)
    #expect(report.d16.outlierLinkMeasureFraction < 0.0002)
    #expect(report.d12.meshBoundaryAssociatedOutlierCount == 0)
    #expect(report.d16.meshBoundaryAssociatedOutlierCount == 0)
    #expect(report.d12.componentJunctionCandidateOutlierCount == 7)
    #expect(report.d16.componentJunctionCandidateOutlierCount == 7)
    #expect(report.d12.edgeOrJunctionAssociatedMeasureFraction == 0.875)
    #expect(report.d16.edgeOrJunctionAssociatedMeasureFraction == 1)
    #expect(report.d12.allOutliersArchived)
    #expect(report.d16.allOutliersArchived)
    #expect(
        report.d12.outliers.allSatisfy {
            $0.offsetSurfaceResidualCells > 0.75
        })
    #expect(
        report.d16.outliers.allSatisfy {
            $0.offsetSurfaceResidualCells > 0.75
        })
    #expect(!report.metrics.sameDominantDirectionAcrossGrids)
    #expect(report.metrics.minimumDominantDirectionMeasureFraction == 0.25)
    #expect(report.edgeOrJunctionAssociated)
    #expect(!report.directionAssociated)
    #expect(!report.interiorAssociated)
    #expect(
        report.classification
            == "mesh-edge-or-component-junction-associated"
    )
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.fluidEvolutionExecuted)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallLinkRayRootLocksCrossComponentBias() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let intersectionPreregistration = try decode(
        "deetjen-dove-moving-wall-link-intersection-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkIntersectionPreregistration.self
    )
    let intersection = try decode(
        "deetjen-dove-moving-wall-link-intersection.json",
        as: MetalIndexedBirdSurfaceLinkIntersectionReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-link-ray-root-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkRayRootPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkRayRootPreregistration(
            surface: surface,
            target: target,
            linkIntersectionPreregistration: intersectionPreregistration,
            sourceLinkIntersectionPreregistrationSHA256:
                "71186ed91522fd29f29f2a07fb03ac75e531974bf36b5171cd78936fd23209d5",
            linkIntersectionReport: intersection,
            sourceLinkIntersectionReportSHA256:
                "7576ab4377864830a58ec41b54d01f489f5a37eaa5e9b44501b43a1890d9300b"
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.reverseScanSubdivisions == 256)
    #expect(preregistration.bisectionIterations == 48)
    #expect(preregistration.maximumAllowedGlobalRootRMSShiftCells == 0.10)
    #expect(preregistration.maximumAllowedGlobalRootMaximumShiftCells == 0.75)

    let report = try decode(
        "deetjen-dove-moving-wall-link-ray-root.json",
        as: MetalIndexedBirdSurfaceLinkRayRootReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.sourceReproductionPassed)
    #expect(report.rootClosurePassed)
    #expect(report.d12.sampleCount == 8)
    #expect(report.d16.sampleCount == 7)
    #expect(report.d12.endpointNearestComponentChangeCount == 8)
    #expect(report.d16.endpointNearestComponentChangeCount == 7)
    #expect(
        report.d12.samples.allSatisfy {
            $0.endpointNearestComponentChanged
                && $0.fluidEndpointUsesRecordedAlternateComponent
        })
    #expect(
        report.d16.samples.allSatisfy {
            $0.endpointNearestComponentChanged
                && $0.fluidEndpointUsesRecordedAlternateComponent
        })
    #expect(report.metrics.totalEndpointNearestComponentChangeCount == 15)
    #expect(report.metrics.totalGlobalRootComponentSwitchCount == 5)
    #expect(report.metrics.maximumRootClosureResidualCells < 1e-5)
    #expect(report.metrics.maximumJunctionGlobalRootRMSShiftCells > 0.90)
    #expect(report.metrics.maximumJunctionGlobalRootMaximumShiftCells > 1.1)
    #expect(report.metrics.minimumJunctionOwnerToGlobalRMSReductionFraction == 0)
    #expect(!report.junctionGlobalUnionPlacementPassed)
    #expect(!report.allGlobalUnionPlacementPassed)
    #expect(!report.ownerToGlobalReductionPassed)
    #expect(
        report.classification == "junction-global-root-linearization-bias"
    )
    #expect(!report.priorPlacementClassificationSuperseded)
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.fluidEvolutionExecuted)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallLinkCoefficientLocksBranchSensitivity() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let rayPreregistration = try decode(
        "deetjen-dove-moving-wall-link-ray-root-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkRayRootPreregistration.self
    )
    let rayRoot = try decode(
        "deetjen-dove-moving-wall-link-ray-root.json",
        as: MetalIndexedBirdSurfaceLinkRayRootReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-link-coefficient-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkCoefficientPreregistration.self
    )
    let rebuiltPreregistration =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkCoefficientPreregistration(
            surface: surface,
            target: target,
            linkRayRootPreregistration: rayPreregistration,
            sourceLinkRayRootPreregistrationSHA256:
                "41cb2f566b01c3686a087103632b4717cc4a4a8d10ad5bd50f07bd41bf08cc81",
            linkRayRootReport: rayRoot,
            sourceLinkRayRootReportSHA256:
                "79f823e08498233ca507da6126b8867c7e1ca12f52daa14d3183bdd8acf37985"
        )
    #expect(preregistration == rebuiltPreregistration)
    #expect(preregistration.branchThreshold == 0.5)
    #expect(
        preregistration.maximumAllowedWeightedRMSCoefficientL1Difference
            == 0.10
    )
    #expect(preregistration.maximumAllowedCoefficientL1Difference == 0.25)
    #expect(preregistration.maximumAllowedSymmetricOperatorNormRatio == 1.10)

    let archived = try decode(
        "deetjen-dove-moving-wall-link-coefficient.json",
        as: MetalIndexedBirdSurfaceLinkCoefficientReport.self
    )
    let report =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkCoefficient(
            surface: surface,
            target: target,
            linkRayRootPreregistration: rayPreregistration,
            sourceLinkRayRootPreregistrationSHA256:
                "41cb2f566b01c3686a087103632b4717cc4a4a8d10ad5bd50f07bd41bf08cc81",
            linkRayRootReport: rayRoot,
            sourceLinkRayRootReportSHA256:
                "79f823e08498233ca507da6126b8867c7e1ca12f52daa14d3183bdd8acf37985",
            preregistration: preregistration,
            sourcePreregistrationSHA256:
                "568550ab587a9d9d27fbabdf3a94950143a0c43693364c31b1b230112117d0a2"
        )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.sourceReproductionPassed)
    #expect(report.d12.branchChangeCount == 3)
    #expect(report.d16.branchChangeCount == 7)
    #expect(report.d12.nearToFarBranchChangeCount == 3)
    #expect(report.d16.nearToFarBranchChangeCount == 7)
    #expect(report.d12.farToNearBranchChangeCount == 0)
    #expect(report.d16.farToNearBranchChangeCount == 0)
    #expect(report.d16.branchChangeLinkMeasureFraction == 1)
    #expect(report.metrics.totalBranchChangeCount == 10)
    #expect(report.metrics.maximumFractionDifference > 0.80)
    #expect(
        report.metrics.maximumWeightedRMSCoefficientL1Difference > 2.78
    )
    #expect(report.metrics.maximumCoefficientL1Difference > 3.18)
    #expect(report.metrics.maximumAbsoluteCoefficientDifference > 0.95)
    #expect(report.metrics.maximumSymmetricOperatorNormRatio > 1.29)
    #expect(
        report.classification == "branch-changing-coefficient-sensitive"
    )
    #expect(!report.coefficientInsensitiveGatePassed)
    #expect(report.validationOnlyPopulationReplayAuthorized)
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.fluidEvolutionExecuted)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(
        report.metrics.maximumCoefficientL1Difference
            == archived.metrics.maximumCoefficientL1Difference
    )
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdMovingWallLinkPopulationRejectsSparseQAsDominant() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let coefficientPreregistration = try decode(
        "deetjen-dove-moving-wall-link-coefficient-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkCoefficientPreregistration.self
    )
    let coefficient = try decode(
        "deetjen-dove-moving-wall-link-coefficient.json",
        as: MetalIndexedBirdSurfaceLinkCoefficientReport.self
    )
    let durationPreregistration = try decode(
        "deetjen-dove-moving-wall-temporal-duration-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self
    )
    let duration = try decode(
        "deetjen-dove-moving-wall-temporal-duration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-link-population-fallback-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkPopulationPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallLinkPopulationPreregistration(
            surface: surface,
            target: target,
            linkCoefficientPreregistration: coefficientPreregistration,
            sourceLinkCoefficientPreregistrationSHA256:
                "568550ab587a9d9d27fbabdf3a94950143a0c43693364c31b1b230112117d0a2",
            linkCoefficientReport: coefficient,
            sourceLinkCoefficientReportSHA256:
                "99e140b648852cd05a082ff3f055572d31bc313270f64cdf8f2e6109cdbc5442",
            temporalDurationPreregistration: durationPreregistration,
            sourceTemporalDurationPreregistrationSHA256:
                "8a15ee4877ada2b5b20badf70e2de894832afe11bcd6e95384786076541e3a85",
            temporalDurationReport: duration,
            sourceTemporalDurationReportSHA256:
                "1257ddad7d5c78fbaf40876074fd847b9b1d410ac4d2ab04a947e6d0240842ae"
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.contractRevision == 2)
    #expect(preregistration.expectedProductionFallbackLinkCount == 4)
    #expect(preregistration.expectedExactGlobalFallbackLinkCount == 1)

    let report = try decode(
        "deetjen-dove-moving-wall-link-population-fallback.json",
        as: MetalIndexedBirdSurfaceLinkPopulationReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.schemaVersion == 2)
    #expect(report.sourceReproductionPassed)
    #expect(report.momentumClosurePassed)
    #expect(report.sampledPopulationPositivityPassed)
    #expect(report.allValuesFinite)
    #expect(report.metrics.capturedSampleCount == 4_608)
    #expect(report.metrics.productionFallbackLinkCount == 4)
    #expect(report.metrics.exactGlobalFallbackLinkCount == 1)
    #expect(report.metrics.uniqueBranchChangeCount == 3)
    #expect(report.metrics.sourceRecordMismatchCount == 0)
    #expect(report.metrics.maximumProductionFractionDifference < 1e-6)
    #expect(report.metrics.maximumProductionReconstructionDifference < 1e-6)
    #expect(report.metrics.populationRelativeRMSDifference < 0.10)
    #expect(report.metrics.outlierForceRelativeRMSDifference < 0.10)
    #expect(
        report.metrics.deltaForceToGlobalAerodynamicForceRMSRatio < 0.01
    )
    #expect(report.metrics.deltaImpulseToGlobalAerodynamicImpulseRatio < 0.01)
    #expect(report.classification == "realized-population-insensitive")
    #expect(!report.validationOnlyBoundaryABAuthorized)
    #expect(!report.d16CaptureAuthorized)
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdDistributedForceRejectsSingleTermAttribution() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let geometryPreregistration = try decode(
        "deetjen-dove-moving-wall-link-geometry-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkGeometryPreregistration.self
    )
    let geometry = try decode(
        "deetjen-dove-moving-wall-link-geometry.json",
        as: MetalIndexedBirdSurfaceLinkGeometryReport.self
    )
    let durationPreregistration = try decode(
        "deetjen-dove-moving-wall-temporal-duration-preregistration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self
    )
    let duration = try decode(
        "deetjen-dove-moving-wall-temporal-duration.json",
        as: MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self
    )
    let populationPreregistration = try decode(
        "deetjen-dove-moving-wall-link-population-fallback-preregistration.json",
        as: MetalIndexedBirdSurfaceLinkPopulationPreregistration.self
    )
    let population = try decode(
        "deetjen-dove-moving-wall-link-population-fallback.json",
        as: MetalIndexedBirdSurfaceLinkPopulationReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-distributed-force-preregistration.json",
        as: MetalIndexedBirdSurfaceDistributedForcePreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallDistributedForcePreregistration(
            surface: surface,
            target: target,
            linkGeometryPreregistration: geometryPreregistration,
            sourceLinkGeometryPreregistrationSHA256:
                "022ad277bc571bc28f7979d67a66de9c8af8bde2e84429854a4c6b1690295624",
            linkGeometryReport: geometry,
            sourceLinkGeometryReportSHA256:
                "39237cc559c086e3a4f06d36560f17192fa9d5737d2163bc82c2b1a7785dcacf",
            temporalDurationPreregistration: durationPreregistration,
            sourceTemporalDurationPreregistrationSHA256:
                "8a15ee4877ada2b5b20badf70e2de894832afe11bcd6e95384786076541e3a85",
            temporalDurationReport: duration,
            sourceTemporalDurationReportSHA256:
                "1257ddad7d5c78fbaf40876074fd847b9b1d410ac4d2ab04a947e6d0240842ae",
            linkPopulationPreregistration: populationPreregistration,
            sourceLinkPopulationPreregistrationSHA256:
                "5c86f4445349f83aec032c23df1e9fe1900b0f4106c20b30465ec33af477a016",
            linkPopulationReport: population,
            sourceLinkPopulationReportSHA256:
                "2313f6dd15766584abe4fb3b4b23854df08c38d0c1890d31f5655fac80802ef4",
            sourceLinkPopulationAuditSHA256:
                "033ab8a966d95d8e97a32df2434efd5f498533ed4e7e17804b9c767dd3d4f95d",
            linkPopulationAuditPassed: true
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.expectedLinkCounts == [25_262, 45_514])
    #expect(preregistration.expectedStepCounts == [576, 768])
    #expect(preregistration.temporalBinCount == 24)

    let report = try decode(
        "deetjen-dove-moving-wall-distributed-force.json",
        as: MetalIndexedBirdSurfaceDistributedForceReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.sourceReproductionPassed)
    #expect(report.d12.capturedLinkCount == 25_262)
    #expect(report.d16.capturedLinkCount == 45_514)
    #expect(report.d12.relativeRMSSourceForceClosure < 1e-5)
    #expect(report.d16.relativeRMSSourceForceClosure < 1e-5)
    #expect(report.metrics.totalForcePairwiseNormalizedRMSDifference < 0.10)
    #expect(report.metrics.dominantTerm == "base-reflection")
    #expect(!report.metrics.dominantTermConsistentAcrossBlocks)
    #expect(!report.metrics.dominantTermGatePassed)
    #expect(report.metrics.dominantComponent == nil)
    #expect(report.metrics.dominantDirection == nil)
    #expect(report.metrics.dominantInterpolationFractionBin == nil)
    #expect(report.metrics.minimumJointBinsForTargetAbsoluteAlignedContribution == 518)
    #expect(report.metrics.activeJointBinCount == 1_440)
    #expect(report.classification == "mixed-term-distributed-grid-bias")
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdForceCovarianceLocksMeanOffsetCancellation() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let distributedPreregistration = try decode(
        "deetjen-dove-moving-wall-distributed-force-preregistration.json",
        as: MetalIndexedBirdSurfaceDistributedForcePreregistration.self
    )
    let distributed = try decode(
        "deetjen-dove-moving-wall-distributed-force.json",
        as: MetalIndexedBirdSurfaceDistributedForceReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-force-covariance-preregistration.json",
        as: MetalIndexedBirdSurfaceForceCovariancePreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallForceCovariancePreregistration(
            surface: surface,
            target: target,
            distributedForcePreregistration:
                distributedPreregistration,
            sourceDistributedForcePreregistrationSHA256:
                "d3f6a70c9bd40992c56ab7fc041206d94a553fd9d86bbac7b232761541e871b5",
            distributedForceReport: distributed,
            sourceDistributedForceReportSHA256:
                "11d92030bad9d57d6ecce6de81c343c2838d7b2174fd049b8741993e0eb58f1f",
            sourceDistributedForceAuditSHA256:
                "c13bed0a6e59963c748b4ecf38cd6a5b657e5870c619ef601115b694f64ea4dd",
            distributedForceAuditPassed: true
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.temporalBinCount == 24)
    #expect(preregistration.blockCount == 3)
    #expect(preregistration.binsPerBlock == 8)

    let report = try decode(
        "deetjen-dove-moving-wall-force-covariance.json",
        as: MetalIndexedBirdSurfaceForceCovarianceReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.sourceReproductionPassed)
    #expect(
        report.metrics.maximumTermDeltaReconstructionErrorNewtons < 2e-6
    )
    #expect(report.metrics.rawEnergyClosureRelativeError < 2e-7)
    #expect(
        report.metrics.dominantPairIdentifier
            == "base-reflection+moving-wall"
    )
    #expect(report.metrics.dominantPairSign == "canceling")
    #expect(report.metrics.dominantPairConsistentAcrossBlocks)
    #expect(report.metrics.dominantPairGatePassed)
    #expect(report.metrics.dominantPairMechanism == "mean-offset-dominated")
    let dominant = try #require(
        report.metrics.pairs.first {
            $0.pairIdentifier == report.metrics.dominantPairIdentifier
        })
    #expect(dominant.rawInteractionEnergyFraction < -9.40)
    #expect(dominant.blockSigns == ["canceling", "canceling", "canceling"])
    #expect(dominant.meanShareOfAbsoluteDecomposition > 0.983)
    #expect(
        report.classification
            == "robust-canceling-mean-offset-dominated-pair-covariance"
    )
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.fluidEvolutionExecuted)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func measuredBirdSpatialInteractionRejectsTargetedCapture() throws {
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(
            type,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/\(name)"
                ))
        )
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let distributed = try decode(
        "deetjen-dove-moving-wall-distributed-force.json",
        as: MetalIndexedBirdSurfaceDistributedForceReport.self
    )
    let covariancePreregistration = try decode(
        "deetjen-dove-moving-wall-force-covariance-preregistration.json",
        as: MetalIndexedBirdSurfaceForceCovariancePreregistration.self
    )
    let covariance = try decode(
        "deetjen-dove-moving-wall-force-covariance.json",
        as: MetalIndexedBirdSurfaceForceCovarianceReport.self
    )
    let preregistration = try decode(
        "deetjen-dove-moving-wall-spatial-interaction-preregistration.json",
        as: MetalIndexedBirdSurfaceSpatialInteractionPreregistration.self
    )
    let rebuilt =
        try MetalIndexedBirdSurfacePilotValidator
        .collisionGridMovingWallSpatialInteractionPreregistration(
            surface: surface,
            target: target,
            distributedForceReport: distributed,
            sourceDistributedForceReportSHA256:
                "11d92030bad9d57d6ecce6de81c343c2838d7b2174fd049b8741993e0eb58f1f",
            forceCovariancePreregistration:
                covariancePreregistration,
            sourceForceCovariancePreregistrationSHA256:
                "6e1a58f25fa722996367bc818db32187987a67532ddae099971ae8aa172376fe",
            forceCovarianceReport: covariance,
            sourceForceCovarianceReportSHA256:
                "20ef161771c1cb6146c8b65a70dae9e2d11d1d822b8c43b836c8ebcb8ee59145",
            sourceForceCovarianceAuditSHA256:
                "ac10134edd1c5f1326cd18f0f39000b9b1ea8e5a5b68721687d251696fe630a2",
            forceCovarianceAuditPassed: true
        )
    #expect(preregistration == rebuilt)
    #expect(preregistration.expectedSpatialBinCounts == [1_438, 1_440])
    #expect(preregistration.expectedUnionSpatialBinCount == 1_440)

    let report = try decode(
        "deetjen-dove-moving-wall-spatial-interaction.json",
        as: MetalIndexedBirdSurfaceSpatialInteractionReport.self
    )
    let auditData = try Data(
        contentsOf:
            repositoryRootURL
            .appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-moving-wall-spatial-interaction-audit.json"
            ))
    let audit = try #require(
        JSONSerialization.jsonObject(with: auditData) as? [String: Any]
    )
    #expect(report.sourceReproductionPassed)
    #expect(report.metrics.maximumTermMeanReconstructionErrorNewtons < 1e-12)
    #expect(report.metrics.relativeInteractionClosureError < 1e-12)
    #expect(report.metrics.dominantComponent == nil)
    #expect(report.metrics.dominantDirection == nil)
    #expect(report.metrics.dominantInterpolationFractionBin == nil)
    let topComponent = try #require(
        report.metrics.componentAssessments.first
    )
    let topDirection = try #require(
        report.metrics.directionAssessments.first
    )
    let topQBin = try #require(
        report.metrics.interpolationFractionAssessments.first
    )
    #expect(topComponent.identifier == "part-2-leftWing")
    #expect(
        topComponent.absoluteInteractionContributionFraction < 0.45
    )
    #expect(
        topDirection.absoluteInteractionContributionFraction < 0.11
    )
    #expect(
        topQBin.absoluteInteractionContributionFraction < 0.11
    )
    #expect(
        report.metrics.minimumJointBinsForTargetAbsoluteContribution == 591
    )
    #expect(report.metrics.activeJointBinCount == 1_440)
    #expect(
        report.metrics.cancellationSupportingAbsoluteContributionFraction
            > 0.501
    )
    #expect(
        report.metrics.cancellationSupportingAbsoluteContributionFraction
            < 0.502
    )
    #expect(report.classification == "distributed-spatial-mean-cancellation")
    #expect(!report.targetedPrimitiveCaptureAuthorized)
    #expect(!report.d20DiagnosticAuthorized)
    #expect(!report.productionModificationAuthorized)
    #expect(!report.fluidEvolutionExecuted)
    #expect(!report.rawSpatialGateModified)
    #expect(!report.experimentalAgreementGateApplied)
    #expect(audit["allChecksPassed"] as? Bool == true)
}

@Test
func sourceViscosityArtifactsRetainLockedD16AndD28Boundaries() throws {
    func data(_ name: String) throws -> Data {
        try Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/\(name)"
            ))
    }
    func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: data(name))
    }
    let surface = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: measuredBirdSurfaceManifestURL
    )
    let target = try MeasuredBirdForceTargetLoader.load(
        targetURL: measuredBirdForceTargetURL,
        surface: surface
    )
    let scalingData = try data("deetjen-dove-source-scaling.json")
    let scalingAuditData = try data("deetjen-dove-source-scaling-audit.json")
    let scaling = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceScalingEvidence.self,
        from: scalingData
    )
    let scalingAudit = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceScalingAuditEvidence.self,
        from: scalingAuditData
    )
    let d16Preregistration = try decode(
        "deetjen-dove-source-viscosity-d16-preregistration.json",
        as: MetalIndexedBirdSurfaceSourceViscosityPreregistration.self
    )
    let rebuiltD16 =
        try MetalIndexedBirdSurfacePilotValidator
        .sourceViscosityD16Preregistration(
            surface: surface,
            target: target,
            sourceScaling: scaling,
            sourceScalingReportSHA256:
                CheckpointArchive.sha256(scalingData),
            sourceScalingAudit: scalingAudit,
            sourceScalingAuditSHA256:
                CheckpointArchive.sha256(scalingAuditData)
        )
    #expect(rebuiltD16 == d16Preregistration)
    #expect(d16Preregistration.referenceLengthCells == 16)
    #expect(d16Preregistration.requestedSteps == 1_600)
    #expect(d16Preregistration.sourceTauPlus < 0.500_05)

    let d16ReportData = try data(
        "deetjen-dove-source-viscosity-d16-ab.json"
    )
    let d16AuditData = try data(
        "deetjen-dove-source-viscosity-d16-audit.json"
    )
    let d16Report = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityReport.self,
        from: d16ReportData
    )
    let d16Audit = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityAuditEvidence.self,
        from: d16AuditData
    )
    #expect(d16Report.screeningGatePassed)
    #expect(d16Report.d28PlanningAuthorized)
    #expect(!d16Report.d28RunAuthorized)
    #expect(d16Audit.allChecksPassed)

    let d16PreregistrationData = try data(
        "deetjen-dove-source-viscosity-d16-preregistration.json"
    )
    let d28Preregistration = try decode(
        "deetjen-dove-source-viscosity-d28-preregistration.json",
        as: MetalIndexedBirdSurfaceSourceViscosityD28Preregistration.self
    )
    let rebuiltD28 =
        try MetalIndexedBirdSurfacePilotValidator
        .sourceViscosityD28Preregistration(
            surface: surface,
            target: target,
            d16Preregistration: d16Preregistration,
            sourceD16PreregistrationSHA256:
                CheckpointArchive.sha256(d16PreregistrationData),
            d16Report: d16Report,
            sourceD16ReportSHA256:
                CheckpointArchive.sha256(d16ReportData),
            d16Audit: d16Audit,
            sourceD16AuditSHA256:
                CheckpointArchive.sha256(d16AuditData)
        )
    #expect(rebuiltD28 == d28Preregistration)
    #expect(
        d28Preregistration.selectedCollisionOperator
            == "positivity-preserving-recursive-regularized-bgk"
    )
    #expect(d28Preregistration.expectedTauPlus >= 0.500_05)
    #expect(d28Preregistration.requestedPreRollSteps == 2_800)
    #expect(d28Preregistration.expectedCellCount == 14_116_018)

    let d28Report = try decode(
        "deetjen-dove-source-viscosity-d28-pre-roll.json",
        as: MetalIndexedBirdSurfaceSourceViscosityD28Report.self
    )
    let d28AuditData = try data(
        "deetjen-dove-source-viscosity-d28-audit.json"
    )
    let d28Audit = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD28AuditEvidence.self,
        from: d28AuditData
    )
    #expect(d28Report.productionTauMarginPassed)
    #expect(d28Report.preRollGatePassed)
    #expect(d28Report.d28FullWindowRunAuthorized)
    #expect(!d28Report.productionModificationAuthorized)
    #expect(!d28Report.experimentalAgreementGateApplied)
    #expect(d28Audit.allChecksPassed)
    #expect(d28Audit.d28FullWindowRunGatePassed)

    let d28PreregistrationData = try data(
        "deetjen-dove-source-viscosity-d28-preregistration.json"
    )
    let d28PreRollData = try data(
        "deetjen-dove-source-viscosity-d28-pre-roll.json"
    )
    let fullWindowPreregistration = try decode(
        "deetjen-dove-source-viscosity-d28-full-window-preregistration.json",
        as: MetalIndexedBirdSurfaceSourceViscosityD28FullWindowPreregistration.self
    )
    let rebuiltFullWindowPreregistration =
        try MetalIndexedBirdSurfacePilotValidator
        .sourceViscosityD28FullWindowPreregistration(
            surface: surface,
            target: target,
            d28Preregistration: d28Preregistration,
            sourceD28PreregistrationSHA256:
                CheckpointArchive.sha256(d28PreregistrationData),
            d28PreRoll: d28Report,
            sourceD28PreRollSHA256:
                CheckpointArchive.sha256(d28PreRollData),
            d28Audit: d28Audit,
            sourceD28AuditSHA256:
                CheckpointArchive.sha256(d28AuditData)
        )
    #expect(rebuiltFullWindowPreregistration == fullWindowPreregistration)
    #expect(fullWindowPreregistration.requestedFullWindowSteps == 13_216)
    #expect(fullWindowPreregistration.requestedComparisonSamples == 187)
    #expect(!fullWindowPreregistration.experimentalAgreementGateApplied)
    #expect(!fullWindowPreregistration.gridConvergenceGateApplied)

    let fullWindowPreregistrationData = try data(
        "deetjen-dove-source-viscosity-d28-full-window-preregistration.json"
    )
    let fullWindowReportData = try data(
        "deetjen-dove-source-viscosity-d28-full-window.json"
    )
    let fullWindowReport = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD28FullWindowReport.self,
        from: fullWindowReportData
    )
    #expect(
        fullWindowReport.sourcePreregistrationSHA256
            == CheckpointArchive.sha256(fullWindowPreregistrationData)
    )
    #expect(fullWindowReport.fullWindowGatePassed)
    #expect(fullWindowReport.registeredComparisonSampleCount == 187)
    #expect(fullWindowReport.ledgerResult.completedSteps == 13_216)
    #expect(fullWindowReport.ledgerResult.minimumPopulation > 0)
    #expect(!fullWindowReport.experimentalAgreementGateApplied)
    #expect(!fullWindowReport.gridConvergenceGateApplied)
    #expect(!fullWindowReport.productionModificationAuthorized)

    let fullWindowAuditData = try data(
        "deetjen-dove-source-viscosity-d28-full-window-audit.json"
    )
    let fullWindowAudit = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD28FullWindowAuditEvidence.self,
        from: fullWindowAuditData
    )
    #expect(fullWindowAudit.allChecksPassed)
    #expect(fullWindowAudit.d28ForceHistoryAcceptedAsRefinementInput)
    #expect(
        fullWindowAudit.preregistrationSHA256
            == CheckpointArchive.sha256(fullWindowPreregistrationData)
    )
    #expect(
        fullWindowAudit.reportSHA256
            == CheckpointArchive.sha256(fullWindowReportData)
    )

    let d32Preregistration = try decode(
        "deetjen-dove-source-viscosity-d32-preregistration.json",
        as: MetalIndexedBirdSurfaceSourceViscosityD32Preregistration.self
    )
    let rebuiltD32Preregistration =
        try MetalIndexedBirdSurfacePilotValidator
        .sourceViscosityD32Preregistration(
            surface: surface,
            target: target,
            d28Preregistration: d28Preregistration,
            sourceD28PreregistrationSHA256:
                CheckpointArchive.sha256(d28PreregistrationData),
            d28FullWindowPreregistration: fullWindowPreregistration,
            sourceD28FullWindowPreregistrationSHA256:
                CheckpointArchive.sha256(fullWindowPreregistrationData),
            d28FullWindowReport: fullWindowReport,
            sourceD28FullWindowReportSHA256:
                CheckpointArchive.sha256(fullWindowReportData),
            d28FullWindowAudit: fullWindowAudit,
            sourceD28FullWindowAuditSHA256:
                CheckpointArchive.sha256(fullWindowAuditData)
        )
    #expect(rebuiltD32Preregistration == d32Preregistration)
    #expect(d32Preregistration.referenceLengthCells == 32)
    #expect(d32Preregistration.requestedPreRollSteps == 3_200)
    #expect(d32Preregistration.expectedCellCount == 20_936_376)
    #expect(d32Preregistration.expectedTauPlus >= 0.500_05)
    #expect(!d32Preregistration.experimentalAgreementGateApplied)
    #expect(!d32Preregistration.gridConvergenceGateApplied)

    let d32PreregistrationData = try data(
        "deetjen-dove-source-viscosity-d32-preregistration.json"
    )
    let d32PreRollData = try data(
        "deetjen-dove-source-viscosity-d32-pre-roll.json"
    )
    let d32AuditData = try data(
        "deetjen-dove-source-viscosity-d32-audit.json"
    )
    let d32PreRoll = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD32Report.self,
        from: d32PreRollData
    )
    let d32Audit = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD32AuditEvidence.self,
        from: d32AuditData
    )
    #expect(d32PreRoll.preRollGatePassed)
    #expect(d32PreRoll.d32FullWindowRunAuthorized)
    #expect(d32PreRoll.caseReport.completedSteps == 3_200)
    #expect(d32Audit.allChecksPassed)
    #expect(d32Audit.d32FullWindowRunGatePassed)
    #expect(
        d32Audit.preregistrationSHA256
            == CheckpointArchive.sha256(d32PreregistrationData)
    )
    #expect(
        d32Audit.reportSHA256
            == CheckpointArchive.sha256(d32PreRollData)
    )

    let d32FullWindowPreregistration = try decode(
        "deetjen-dove-source-viscosity-d32-full-window-preregistration.json",
        as: MetalIndexedBirdSurfaceSourceViscosityD32FullWindowPreregistration.self
    )
    let rebuiltD32FullWindowPreregistration =
        try MetalIndexedBirdSurfacePilotValidator
        .sourceViscosityD32FullWindowPreregistration(
            surface: surface,
            target: target,
            d32Preregistration: d32Preregistration,
            sourceD32PreregistrationSHA256:
                CheckpointArchive.sha256(d32PreregistrationData),
            d32PreRoll: d32PreRoll,
            sourceD32PreRollSHA256:
                CheckpointArchive.sha256(d32PreRollData),
            d32Audit: d32Audit,
            sourceD32AuditSHA256:
                CheckpointArchive.sha256(d32AuditData)
        )
    #expect(
        rebuiltD32FullWindowPreregistration
            == d32FullWindowPreregistration
    )
    #expect(
        d32FullWindowPreregistration.requestedFullWindowSteps == 15_104
    )
    #expect(d32FullWindowPreregistration.fluidStepsPerForceSample == 64)
    #expect(d32FullWindowPreregistration.requestedComparisonSamples == 187)
    #expect(!d32FullWindowPreregistration.experimentalAgreementGateApplied)
    #expect(!d32FullWindowPreregistration.gridConvergenceGateApplied)

    let d32FullWindowPreregistrationData = try data(
        "deetjen-dove-source-viscosity-d32-full-window-preregistration.json"
    )
    let d32FullWindowReportData = try data(
        "deetjen-dove-source-viscosity-d32-full-window.json"
    )
    let d32FullWindowReport = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD32FullWindowReport.self,
        from: d32FullWindowReportData
    )
    #expect(
        d32FullWindowReport.sourcePreregistrationSHA256
            == CheckpointArchive.sha256(d32FullWindowPreregistrationData)
    )
    #expect(d32FullWindowReport.referenceLengthCells == 32)
    #expect(d32FullWindowReport.fullWindowGatePassed)
    #expect(d32FullWindowReport.registeredComparisonSampleCount == 187)
    #expect(d32FullWindowReport.ledgerResult.completedSteps == 15_104)
    #expect(d32FullWindowReport.ledgerResult.minimumPopulation > 0)
    #expect(!d32FullWindowReport.experimentalAgreementGateApplied)
    #expect(!d32FullWindowReport.gridConvergenceGateApplied)
    #expect(!d32FullWindowReport.productionModificationAuthorized)

    let d32FullWindowAuditData = try data(
        "deetjen-dove-source-viscosity-d32-full-window-audit.json"
    )
    let d32FullWindowAudit = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceSourceViscosityD32FullWindowAuditEvidence.self,
        from: d32FullWindowAuditData
    )
    #expect(d32FullWindowAudit.allChecksPassed)
    #expect(d32FullWindowAudit.d32ForceHistoryAcceptedAsRefinementInput)
    #expect(
        d32FullWindowAudit.preregistrationSHA256
            == CheckpointArchive.sha256(d32FullWindowPreregistrationData)
    )
    #expect(
        d32FullWindowAudit.reportSHA256
            == CheckpointArchive.sha256(d32FullWindowReportData)
    )

    let refinementPreregistrationData = try data(
        "deetjen-dove-source-viscosity-d28-d32-refinement-preregistration.json"
    )
    let refinementReportData = try data(
        "deetjen-dove-source-viscosity-d28-d32-refinement.json"
    )
    let refinementAuditData = try data(
        "deetjen-dove-source-viscosity-d28-d32-refinement-audit.json"
    )
    let refinementPreregistration = try #require(
        JSONSerialization.jsonObject(with: refinementPreregistrationData)
            as? [String: Any]
    )
    let refinementReport = try #require(
        JSONSerialization.jsonObject(with: refinementReportData)
            as? [String: Any]
    )
    let refinementAudit = try #require(
        JSONSerialization.jsonObject(with: refinementAuditData)
            as? [String: Any]
    )
    let refinementMetrics = try #require(
        refinementReport["metrics"] as? [String: Any]
    )
    #expect(refinementPreregistration["maximumFinePairDifference"] as? Double == 0.05)
    #expect(
        refinementReport["preregistrationSHA256"] as? String
            == CheckpointArchive.sha256(refinementPreregistrationData)
    )
    #expect(
        refinementReport["sourceD32ReportSHA256"] as? String
            == CheckpointArchive.sha256(d32FullWindowReportData)
    )
    #expect(
        refinementReport["sourceD32AuditSHA256"] as? String
            == CheckpointArchive.sha256(d32FullWindowAuditData)
    )
    #expect(
        refinementReport["classification"] as? String
            == "d28-d32-fine-pair-not-stabilized"
    )
    #expect(refinementReport["finePairStabilizationPassed"] as? Bool == false)
    #expect(refinementReport["gridConvergenceAccepted"] as? Bool == false)
    let refinementScore = try #require(
        refinementReport["gridTrendScore"] as? Double
    )
    let horizontalDifference = try #require(
        refinementMetrics["horizontalForceNormalizedRMSDifference"] as? Double
    )
    let verticalDifference = try #require(
        refinementMetrics["verticalForceNormalizedRMSDifference"] as? Double
    )
    #expect(abs(refinementScore - 0.056_321_598_232_749_01) < 1e-14)
    #expect(abs(horizontalDifference - 0.073_756_565_155_349_02) < 1e-14)
    #expect(abs(verticalDifference - 0.046_610_471_350_922_694) < 1e-14)
    #expect(refinementAudit["allChecksPassed"] as? Bool == true)
    #expect(refinementAudit["d36RunAuthorized"] as? Bool == false)
    #expect(
        refinementAudit["preregistrationSHA256"] as? String
            == CheckpointArchive.sha256(refinementPreregistrationData)
    )
    #expect(
        refinementAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(refinementReportData)
    )

    let phaseLocalizationData = try data(
        "deetjen-dove-source-viscosity-d28-d32-phase-localization.json"
    )
    let phaseLocalizationAuditData = try data(
        "deetjen-dove-source-viscosity-d28-d32-phase-localization-audit.json"
    )
    let phaseLocalization = try #require(
        JSONSerialization.jsonObject(with: phaseLocalizationData)
            as? [String: Any]
    )
    let phaseLocalizationAudit = try #require(
        JSONSerialization.jsonObject(with: phaseLocalizationAuditData)
            as? [String: Any]
    )
    let dominantPhaseBand = try #require(
        phaseLocalization["dominantPhaseBand"] as? [String: Any]
    )
    let targetedReplay = try #require(
        phaseLocalization["targetedReplayRecommendation"] as? [String: Any]
    )
    #expect(phaseLocalization["exploratoryPostHocAnalysis"] as? Bool == true)
    #expect(phaseLocalization["fluidEvolutionExecuted"] as? Bool == false)
    #expect(
        phaseLocalization["sourceRefinementReportSHA256"] as? String
            == CheckpointArchive.sha256(refinementReportData)
    )
    #expect(
        phaseLocalization["sourceRefinementAuditSHA256"] as? String
            == CheckpointArchive.sha256(refinementAuditData)
    )
    #expect(dominantPhaseBand["bandIndex"] as? Int == 0)
    #expect(targetedReplay["startTimeSeconds"] as? Double == 0.025)
    #expect(targetedReplay["endTimeSeconds"] as? Double == 0.03)
    #expect(targetedReplay["d36RunAuthorized"] as? Bool == false)
    #expect(phaseLocalizationAudit["allChecksPassed"] as? Bool == true)
    #expect(
        phaseLocalizationAudit["targetedD28D32ReplaySupported"] as? Bool
            == true
    )
    #expect(phaseLocalizationAudit["d36RunAuthorized"] as? Bool == false)
    #expect(
        phaseLocalizationAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(phaseLocalizationData)
    )

    let targetedPreregistrationData = try data(
        "deetjen-dove-source-viscosity-targeted-boundary-preregistration.json"
    )
    let targetedPreregistration = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceTargetedBoundaryPreregistration.self,
        from: targetedPreregistrationData
    )
    #expect(targetedPreregistration.schemaVersion == 2)
    #expect(targetedPreregistration.firstTargetSampleIndex == 50)
    #expect(targetedPreregistration.lastTargetSampleIndex == 60)
    #expect(targetedPreregistration.d28RequestedSteps == 3_360)
    #expect(targetedPreregistration.d32RequestedSteps == 3_840)
    #expect(
        targetedPreregistration.sourcePropertyReynoldsNumber
            == d32Preregistration.sourcePropertyReynoldsNumber
    )
    #expect(
        targetedPreregistration.expectedD28TauPlus
            == fullWindowReport.actualTauPlus
    )
    #expect(
        targetedPreregistration.expectedD32TauPlus
            == d32FullWindowReport.actualTauPlus
    )
    #expect(
        targetedPreregistration.maximumComponentReconstructionRelativeRMS
            == 1e-4
    )
    #expect(
        targetedPreregistration.minimumDominantContributionFraction == 0.5
    )
    #expect(!targetedPreregistration.experimentalAgreementGateApplied)
    #expect(!targetedPreregistration.gridConvergenceGateApplied)

    let targetedD28Data = try data(
        "deetjen-dove-source-viscosity-targeted-boundary-d28.json"
    )
    let targetedD32Data = try data(
        "deetjen-dove-source-viscosity-targeted-boundary-d32.json"
    )
    let targetedD28 = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceTargetedBoundaryCaseReport.self,
        from: targetedD28Data
    )
    let targetedD32 = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceTargetedBoundaryCaseReport.self,
        from: targetedD32Data
    )
    for targeted in [targetedD28, targetedD32] {
        #expect(targeted.targetedCasePassed)
        #expect(targeted.numericalLedgerPassed)
        #expect(targeted.componentReconstructionPassed)
        #expect(targeted.archivedForceReproductionPassed)
        #expect(targeted.componentBins.count == 11)
        #expect(
            targeted.sourcePreregistrationSHA256
                == CheckpointArchive.sha256(targetedPreregistrationData)
        )
        #expect(!targeted.productionModificationAuthorized)
        #expect(!targeted.experimentalAgreementGateApplied)
        #expect(!targeted.gridConvergenceGateApplied)
    }
    #expect(targetedD28.referenceLengthCells == 28)
    #expect(targetedD28.capturedStepCount == 616)
    #expect(targetedD28.archivedForceReproductionRelativeRMS == 0)
    #expect(targetedD32.referenceLengthCells == 32)
    #expect(targetedD32.capturedStepCount == 704)

    let targetedReportData = try data(
        "deetjen-dove-source-viscosity-targeted-boundary.json"
    )
    let targetedAuditData = try data(
        "deetjen-dove-source-viscosity-targeted-boundary-audit.json"
    )
    let targetedReport = try #require(
        JSONSerialization.jsonObject(with: targetedReportData)
            as? [String: Any]
    )
    let targetedAudit = try #require(
        JSONSerialization.jsonObject(with: targetedAuditData)
            as? [String: Any]
    )
    #expect(
        targetedReport["preregistrationSHA256"] as? String
            == CheckpointArchive.sha256(targetedPreregistrationData)
    )
    #expect(
        targetedReport["sourceD28CaseSHA256"] as? String
            == CheckpointArchive.sha256(targetedD28Data)
    )
    #expect(
        targetedReport["sourceD32CaseSHA256"] as? String
            == CheckpointArchive.sha256(targetedD32Data)
    )
    #expect(
        targetedReport["productionModificationAuthorized"] as? Bool == false
    )
    #expect(targetedAudit["allChecksPassed"] as? Bool == true)
    #expect(
        targetedAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(targetedReportData)
    )

    let provenancePreregistrationData = try data(
        "deetjen-dove-source-viscosity-reflected-provenance-preregistration.json"
    )
    let provenancePreregistration = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceReflectedProvenancePreregistration.self,
        from: provenancePreregistrationData
    )
    #expect(provenancePreregistration.schemaVersion == 2)
    #expect(provenancePreregistration.referenceLengthCells == [28, 32])
    #expect(provenancePreregistration.targetSampleIndices == Array(50...60))
    #expect(provenancePreregistration.candidateLinksPerThreadgroup == 0)
    #expect(provenancePreregistration.candidateCapacity == 262_144)
    #expect(provenancePreregistration.selectedLinksPerEndpoint == 131_072)
    #expect(
        provenancePreregistration.minimumSelectedAbsoluteScoreCoverage == 0.5
    )
    #expect(
        provenancePreregistration.maximumPopulationCompositionClosureRelativeRMS
            == 1e-10
    )

    let provenanceV1PreregistrationData = try data(
        "deetjen-dove-source-viscosity-reflected-provenance-preregistration-v1-insufficient-coverage.json"
    )
    let provenanceV1D28Data = try data(
        "deetjen-dove-source-viscosity-reflected-provenance-d28-v1-insufficient-coverage.json"
    )
    let provenanceV1D28 = try #require(
        JSONSerialization.jsonObject(with: provenanceV1D28Data)
            as? [String: Any]
    )
    #expect(
        provenancePreregistration.sourceV1PreregistrationSHA256
            == CheckpointArchive.sha256(provenanceV1PreregistrationData)
    )
    #expect(
        provenancePreregistration.sourceV1D28CaseSHA256
            == CheckpointArchive.sha256(provenanceV1D28Data)
    )
    #expect(provenanceV1D28["provenanceCasePassed"] as? Bool == false)
    #expect(provenanceV1D28["selectionCoveragePassed"] as? Bool == false)
    #expect(provenanceV1D28["numericalLedgerPassed"] as? Bool == true)
    #expect(
        provenanceV1D28["sourceReflectedForceReproductionPassed"] as? Bool
            == true
    )
    #expect(provenanceV1D28["candidateDetailPassed"] as? Bool == true)

    let provenanceD28Data = try data(
        "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
    )
    let provenanceD32Data = try data(
        "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
    )
    let provenanceD28 = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceReflectedProvenanceCaseReport.self,
        from: provenanceD28Data
    )
    let provenanceD32 = try JSONDecoder().decode(
        MetalIndexedBirdSurfaceReflectedProvenanceCaseReport.self,
        from: provenanceD32Data
    )
    for provenance in [provenanceD28, provenanceD32] {
        #expect(provenance.schemaVersion == 2)
        #expect(provenance.endpointCount == 11)
        #expect(provenance.provenanceCasePassed)
        #expect(provenance.numericalLedgerPassed)
        #expect(provenance.selectionCoveragePassed)
        #expect(provenance.sourceReflectedForceReproductionPassed)
        #expect(provenance.candidateDetailPassed)
        #expect(provenance.candidateDetailMismatchCount == 0)
        #expect(provenance.candidateOverflowCount == 0)
        #expect(provenance.minimumSelectedAbsoluteScoreCoverage >= 0.5)
        #expect(
            provenance.sourcePreregistrationSHA256
                == CheckpointArchive.sha256(provenancePreregistrationData)
        )
        #expect(!provenance.productionModificationAuthorized)
        #expect(!provenance.experimentalAgreementGateApplied)
        #expect(!provenance.gridConvergenceGateApplied)
    }
    #expect(provenanceD28.referenceLengthCells == 28)
    #expect(provenanceD32.referenceLengthCells == 32)

    let provenanceReportData = try data(
        "deetjen-dove-source-viscosity-reflected-provenance.json"
    )
    let provenanceAuditData = try data(
        "deetjen-dove-source-viscosity-reflected-provenance-audit.json"
    )
    let provenanceReport = try #require(
        JSONSerialization.jsonObject(with: provenanceReportData)
            as? [String: Any]
    )
    let provenanceAudit = try #require(
        JSONSerialization.jsonObject(with: provenanceAuditData)
            as? [String: Any]
    )
    #expect(provenanceReport["bothProvenanceCasesPassed"] as? Bool == true)
    #expect(
        provenanceReport["populationCompositionClosurePassed"] as? Bool
            == true
    )
    #expect(
        provenanceReport["preregistrationSHA256"] as? String
            == CheckpointArchive.sha256(provenancePreregistrationData)
    )
    #expect(
        provenanceReport["sourceD28CaseSHA256"] as? String
            == CheckpointArchive.sha256(provenanceD28Data)
    )
    #expect(
        provenanceReport["sourceD32CaseSHA256"] as? String
            == CheckpointArchive.sha256(provenanceD32Data)
    )
    #expect(provenanceAudit["allChecksPassed"] as? Bool == true)
    #expect(provenanceAudit["checkCount"] as? Int == 16)
    #expect(
        provenanceAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(provenanceReportData)
    )

    let compositionPreregistrationData = try data(
        "deetjen-dove-link-composition-discriminator-preregistration.json"
    )
    let compositionReportData = try data(
        "deetjen-dove-link-composition-discriminator.json"
    )
    let compositionAuditData = try data(
        "deetjen-dove-link-composition-discriminator-audit.json"
    )
    let compositionPreregistration = try #require(
        JSONSerialization.jsonObject(with: compositionPreregistrationData)
            as? [String: Any]
    )
    let compositionReport = try #require(
        JSONSerialization.jsonObject(with: compositionReportData)
            as? [String: Any]
    )
    let compositionAudit = try #require(
        JSONSerialization.jsonObject(with: compositionAuditData)
            as? [String: Any]
    )
    let compositionAttribution = try #require(
        compositionReport["attribution"] as? [String: Any]
    )
    #expect(compositionPreregistration["schemaVersion"] as? Int == 1)
    #expect(compositionPreregistration["passed"] as? Bool == true)
    #expect(
        compositionPreregistration["sourceD28ProvenanceSHA256"] as? String
            == CheckpointArchive.sha256(provenanceD28Data)
    )
    #expect(
        compositionPreregistration["sourceD32ProvenanceSHA256"] as? String
            == CheckpointArchive.sha256(provenanceD32Data)
    )
    #expect(
        compositionPreregistration["sourceProvenanceAttributionSHA256"]
            as? String == CheckpointArchive.sha256(provenanceReportData)
    )
    #expect(compositionReport["analysisPassed"] as? Bool == true)
    #expect(compositionReport["fluidEvolutionExecuted"] as? Bool == false)
    #expect(
        compositionReport["preregistrationSHA256"] as? String
            == CheckpointArchive.sha256(compositionPreregistrationData)
    )
    #expect(
        compositionAttribution["classification"] as? String
            == "dominant-conditioned-factor:directionComposition"
    )
    #expect(
        compositionAttribution["leadingFactor"] as? String
            == "directionComposition"
    )
    #expect(
        compositionAttribution["sameLeaderInBothTemporalHalves"] as? Bool
            == true
    )
    #expect(
        (compositionAttribution["leadingAbsoluteLedgerFraction"]
            as? Double ?? 0) > 0.876
    )
    #expect(
        (compositionReport["maximumPooledFallbackProbabilityMass"]
            as? Double ?? 1) < 0.001
    )
    #expect(compositionReport["productionModificationAuthorized"] as? Bool == false)
    #expect(compositionReport["d36RunAuthorized"] as? Bool == false)
    #expect(compositionAudit["allChecksPassed"] as? Bool == true)
    #expect(compositionAudit["checkCount"] as? Int == 18)
    #expect(
        compositionAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(compositionReportData)
    )

    let directionV1PreregistrationData = try data(
        "deetjen-dove-direction-composition-canonical-preregistration-v1-float-degenerate.json"
    )
    let directionV1ReportData = try data(
        "deetjen-dove-direction-composition-canonical-v1-float-degenerate.json"
    )
    let directionPreregistrationData = try data(
        "deetjen-dove-direction-composition-canonical-preregistration.json"
    )
    let directionReportData = try data(
        "deetjen-dove-direction-composition-canonical.json"
    )
    let directionAuditData = try data(
        "deetjen-dove-direction-composition-canonical-audit.json"
    )
    let directionV1Report = try #require(
        JSONSerialization.jsonObject(with: directionV1ReportData)
            as? [String: Any]
    )
    let directionPreregistration = try JSONDecoder().decode(
        MetalDirectionCompositionPreregistration.self,
        from: directionPreregistrationData
    )
    let directionReport = try JSONDecoder().decode(
        MetalDirectionCompositionCanonicalReport.self,
        from: directionReportData
    )
    let directionAudit = try #require(
        JSONSerialization.jsonObject(with: directionAuditData)
            as? [String: Any]
    )
    #expect(directionV1Report["canonicalPassed"] as? Bool == false)
    #expect(
        (directionV1Report["gates"] as? [String: Bool])?[
            "metalCPUPerDirectionCounts"
        ] == false
    )
    #expect(
        (directionV1Report["gates"] as? [String: Bool])?[
            "fineProfileVectorResponse"
        ] == true
    )
    #expect(directionPreregistration.schemaVersion == 2)
    #expect(
        directionPreregistration.revisionHistory.v1PreregistrationSHA256
            == CheckpointArchive.sha256(directionV1PreregistrationData)
    )
    #expect(
        directionPreregistration.revisionHistory.v1FailedReportSHA256
            == CheckpointArchive.sha256(directionV1ReportData)
    )
    #expect(directionReport.cases.count == 40)
    #expect(directionReport.canonicalPassed)
    #expect(directionReport.basicPlanarDirectionWeightingCleared)
    #expect(directionReport.maximumMetalCPUPerDirectionCountMismatch == 0)
    #expect(directionReport.maximumFineProfileVectorRelativeError < 0.013)
    #expect(
        directionReport.sourcePreregistrationSHA256
            == CheckpointArchive.sha256(directionPreregistrationData)
    )
    #expect(!directionReport.fluidEvolutionExecuted)
    #expect(!directionReport.productionModificationAuthorized)
    #expect(directionAudit["allChecksPassed"] as? Bool == true)
    #expect(directionAudit["checkCount"] as? Int == 14)
    #expect(
        directionAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(directionReportData)
    )

    let curvedDirectionPreregistrationData = try data(
        "deetjen-dove-curved-direction-composition-canonical-preregistration.json"
    )
    let curvedDirectionReportData = try data(
        "deetjen-dove-curved-direction-composition-canonical.json"
    )
    let curvedDirectionAuditData = try data(
        "deetjen-dove-curved-direction-composition-canonical-audit.json"
    )
    let curvedDirectionPreregistration = try #require(
        JSONSerialization.jsonObject(with: curvedDirectionPreregistrationData)
            as? [String: Any]
    )
    let curvedDirectionReport = try #require(
        JSONSerialization.jsonObject(with: curvedDirectionReportData)
            as? [String: Any]
    )
    let curvedDirectionAudit = try #require(
        JSONSerialization.jsonObject(with: curvedDirectionAuditData)
            as? [String: Any]
    )
    #expect(curvedDirectionPreregistration["schemaVersion"] as? Int == 1)
    #expect(curvedDirectionPreregistration["passed"] as? Bool == true)
    #expect(
        curvedDirectionPreregistration["sourcePlanarReportSHA256"] as? String
            == CheckpointArchive.sha256(directionReportData)
    )
    #expect(curvedDirectionReport["canonicalPassed"] as? Bool == true)
    #expect(
        curvedDirectionReport["classification"] as? String
            == "curved-direction-redistribution-cleared-at-d12-d16"
    )
    #expect(
        curvedDirectionReport["sourcePreregistrationSHA256"] as? String
            == CheckpointArchive.sha256(curvedDirectionPreregistrationData)
    )
    #expect(
        curvedDirectionReport[
            "maximumWholeSurfaceOppositeDirectionCountMismatch"
        ] as? Int == 0
    )
    #expect(
        (curvedDirectionReport[
            "wholeSurfaceDirectionHistogramTotalVariation"
        ] as? Double ?? 1) < 0.0014
    )
    #expect(
        (curvedDirectionReport[
            "maximumWholeSurfaceProfileResponseLedgerDifference"
        ] as? Double ?? 1) < 0.0001
    )
    #expect(curvedDirectionReport["fluidEvolutionExecuted"] as? Bool == false)
    #expect(
        curvedDirectionReport["productionModificationAuthorized"] as? Bool
            == false
    )
    #expect(curvedDirectionAudit["allChecksPassed"] as? Bool == true)
    #expect(curvedDirectionAudit["checkCount"] as? Int == 14)
    #expect(
        curvedDirectionAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(curvedDirectionReportData)
    )

    let fineDirectionPreregistrationData = try data(
        "deetjen-dove-fine-direction-composition-preregistration.json"
    )
    let fineDirectionCensusData = try data(
        "deetjen-dove-fine-direction-composition-census.json"
    )
    let fineDirectionReportData = try data(
        "deetjen-dove-fine-direction-composition-discriminator.json"
    )
    let fineDirectionAuditData = try data(
        "deetjen-dove-fine-direction-composition-audit.json"
    )
    let fineDirectionPreregistration = try #require(
        JSONSerialization.jsonObject(with: fineDirectionPreregistrationData)
            as? [String: Any]
    )
    let fineDirectionCensus = try #require(
        JSONSerialization.jsonObject(with: fineDirectionCensusData)
            as? [String: Any]
    )
    let fineDirectionReport = try #require(
        JSONSerialization.jsonObject(with: fineDirectionReportData)
            as? [String: Any]
    )
    let fineDirectionAudit = try #require(
        JSONSerialization.jsonObject(with: fineDirectionAuditData)
            as? [String: Any]
    )
    #expect(fineDirectionPreregistration["schemaVersion"] as? Int == 1)
    #expect(fineDirectionPreregistration["passed"] as? Bool == true)
    #expect(
        fineDirectionPreregistration["sourceCurvedReportSHA256"] as? String
            == CheckpointArchive.sha256(curvedDirectionReportData)
    )
    #expect(fineDirectionCensus["censusPassed"] as? Bool == true)
    #expect(
        fineDirectionCensus["sourcePreregistrationSHA256"] as? String
            == CheckpointArchive.sha256(fineDirectionPreregistrationData)
    )
    #expect(
        fineDirectionCensus["maximumMetalCPUMaskMismatchCellCount"] as? Int
            == 0
    )
    #expect(
        fineDirectionCensus["maximumMetalCPUPerDirectionCountMismatch"] as? Int
            == 0
    )
    #expect(fineDirectionReport["analysisPassed"] as? Bool == true)
    #expect(
        fineDirectionReport["classification"] as? String
            == "fine-direction-redistribution-cleared-at-d28-d32"
    )
    #expect(
        fineDirectionReport["sourceCensusSHA256"] as? String
            == CheckpointArchive.sha256(fineDirectionCensusData)
    )
    #expect(
        (fineDirectionReport[
            "wholeSurfaceDirectionHistogramTotalVariation"
        ] as? Double ?? 1) < 0.0007
    )
    #expect(
        (fineDirectionReport[
            "maximumWholeSurfaceProfileResponseLedgerDifference"
        ] as? Double ?? 1) < 0.000_012
    )
    #expect(fineDirectionReport["fluidEvolutionExecuted"] as? Bool == false)
    #expect(
        fineDirectionReport["productionModificationAuthorized"] as? Bool
            == false
    )
    #expect(fineDirectionAudit["allChecksPassed"] as? Bool == true)
    #expect(fineDirectionAudit["checkCount"] as? Int == 16)
    #expect(
        fineDirectionAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(fineDirectionReportData)
    )

    let phasePreregistrationData = try data(
        "deetjen-dove-fine-direction-phase-window-preregistration.json"
    )
    let phaseCensusData = try data(
        "deetjen-dove-fine-direction-phase-window-census.json"
    )
    let phaseReportData = try data(
        "deetjen-dove-fine-direction-phase-window-discriminator.json"
    )
    let phaseAuditData = try data(
        "deetjen-dove-fine-direction-phase-window-audit.json"
    )
    let phasePreregistration = try #require(
        JSONSerialization.jsonObject(with: phasePreregistrationData)
            as? [String: Any]
    )
    let phaseCensus = try #require(
        JSONSerialization.jsonObject(with: phaseCensusData) as? [String: Any]
    )
    let phaseReport = try #require(
        JSONSerialization.jsonObject(with: phaseReportData) as? [String: Any]
    )
    let phaseAudit = try #require(
        JSONSerialization.jsonObject(with: phaseAuditData) as? [String: Any]
    )
    #expect(phasePreregistration["schemaVersion"] as? Int == 2)
    #expect(phasePreregistration["arithmeticOnlyRevision"] as? Bool == true)
    #expect(phaseCensus["censusPassed"] as? Bool == true)
    #expect(phaseCensus["qualifiedTieCellCount"] as? Int == 4)
    #expect(
        phaseCensus["sourcePreregistrationSHA256"] as? String
            == CheckpointArchive.sha256(phasePreregistrationData)
    )
    #expect(phaseReport["analysisPassed"] as? Bool == true)
    #expect(phaseReport["passedPhaseCount"] as? Int == 11)
    #expect(
        phaseReport["classification"] as? String
            == "fine-direction-phase-window-cleared-at-d28-d32"
    )
    #expect(
        (phaseReport[
            "maximumWholeSurfaceDirectionHistogramTotalVariation"
        ] as? Double ?? 1) < 0.000_8
    )
    #expect(
        (phaseReport[
            "maximumWholeSurfaceProfileResponseLedgerDifference"
        ] as? Double ?? 1) < 0.000_033
    )
    #expect(phaseAudit["allChecksPassed"] as? Bool == true)
    #expect(phaseAudit["checkCount"] as? Int == 18)
    #expect(
        phaseAudit["reportSHA256"] as? String
            == CheckpointArchive.sha256(phaseReportData)
    )

    let invalidRunnerPreregistration = try #require(
        JSONSerialization.jsonObject(
            with: data(
                "deetjen-dove-source-viscosity-targeted-boundary-preregistration-v1-invalid-runner.json"
            )) as? [String: Any]
    )
    let invalidScalingCase = try #require(
        JSONSerialization.jsonObject(
            with: data(
                "deetjen-dove-source-viscosity-targeted-boundary-d28-invalid-scaling.json"
            )) as? [String: Any]
    )
    #expect(invalidRunnerPreregistration["schemaVersion"] as? Int == 1)
    #expect(invalidScalingCase["targetedCasePassed"] as? Bool == false)
    #expect(
        (invalidScalingCase["archivedForceReproductionRelativeRMS"]
            as? Double ?? 0) > 0.09
    )

    let diagnosisData = try data(
        "deetjen-dove-source-viscosity-d28-force-diagnosis.json"
    )
    let diagnosis = try #require(
        JSONSerialization.jsonObject(with: diagnosisData) as? [String: Any]
    )
    #expect(diagnosis["exploratoryPostHocAnalysis"] as? Bool == true)
    #expect(
        diagnosis["classification"] as? String
            == "vertical-shape-correlated-but-amplitude-biased-with-horizontal-force-mismatch"
    )
    #expect(
        diagnosis["sourceD28FullWindowSHA256"] as? String
            == CheckpointArchive.sha256(fullWindowReportData)
    )
    #expect(
        diagnosis["sourceD28FullWindowAuditSHA256"] as? String
            == CheckpointArchive.sha256(fullWindowAuditData)
    )
}

#if canImport(Metal)
    @Test
    func productionMetalFineDirectionCensusReproducesArchive() throws {
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let preregistrationData = try Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-fine-direction-composition-preregistration.json"
            )
        )
        let expected = try JSONDecoder().decode(
            MetalFineDirectionCensusReport.self,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/deetjen-dove-fine-direction-composition-census.json"
                )
            )
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridFineDirectionCensus(
                surface: surface,
                target: target,
                preregistration: try JSONDecoder().decode(
                    MetalFineDirectionCompositionPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    CheckpointArchive.sha256(preregistrationData)
            )
        #expect(report.censusPassed)
        #expect(!report.fluidEvolutionExecuted)
        #expect(!report.populationAllocationPerformed)
        #expect(!report.newPhysicsKernelExecuted)
        #expect(report.maximumMetalCPUMaskMismatchCellCount == 0)
        #expect(report.maximumMetalCPUPerDirectionCountMismatch == 0)
        #expect(report.cases.count == expected.cases.count)
        for (actual, archived) in zip(report.cases, expected.cases) {
            #expect(actual.referenceLengthCells == archived.referenceLengthCells)
            #expect(actual.gridCells == archived.gridCells)
            #expect(actual.metalBins == archived.metalBins)
            #expect(actual.cpuBins == archived.cpuBins)
            #expect(actual.totalMetalLinkCount == archived.totalMetalLinkCount)
            #expect(actual.totalCPULinkCount == archived.totalCPULinkCount)
            #expect(actual.parityGatePassed)
            #expect(actual.productionLinkSetConsistencyGatePassed)
        }
    }

    @Test
    func productionMetalFineDirectionPhaseWindowReproducesV1Archive() throws {
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let preregistrationData = try Data(
            contentsOf: repositoryRootURL.appendingPathComponent(
                "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json"
            )
        )
        let expected = try JSONDecoder().decode(
            MetalFineDirectionPhaseCensusReport.self,
            from: Data(
                contentsOf: repositoryRootURL.appendingPathComponent(
                    "ValidationArtifacts/deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json"
                )
            )
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridFineDirectionPhaseWindowCensus(
                surface: surface,
                target: target,
                preregistration: try JSONDecoder().decode(
                    MetalFineDirectionPhaseWindowPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    CheckpointArchive.sha256(preregistrationData)
            )
        #expect(!report.censusPassed)
        #expect(report.classification == "invalid-census-parity")
        #expect(!report.fluidEvolutionExecuted)
        #expect(!report.populationAllocationPerformed)
        #expect(!report.newPhysicsKernelExecuted)
        #expect(report.cases.count == expected.cases.count)
        for (actual, archived) in zip(report.cases, expected.cases) {
            #expect(actual.sourceSampleIndex == archived.sourceSampleIndex)
            #expect(actual.referenceLengthCells == archived.referenceLengthCells)
            #expect(actual.gridCells == archived.gridCells)
            #expect(actual.metalBins == archived.metalBins)
            #expect(actual.cpuBins == archived.cpuBins)
            #expect(actual.totalMetalLinkCount == archived.totalMetalLinkCount)
            #expect(actual.totalCPULinkCount == archived.totalCPULinkCount)
            #expect(
                actual.metalCPUMaskMismatchCellCount
                    == archived.metalCPUMaskMismatchCellCount
            )
            #expect(
                actual.maximumMetalCPUPerDirectionCountMismatch
                    == archived.maximumMetalCPUPerDirectionCountMismatch
            )
            #expect(
                actual.productionLinkSetConsistencyGatePassed
                    == archived.productionLinkSetConsistencyGatePassed
            )
        }
    }

    @Test
    func productionMetalD16PopulationProvenanceCloses() throws {
        func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            try JSONDecoder().decode(
                type,
                from: Data(
                    contentsOf: repositoryRootURL.appendingPathComponent(
                        "ValidationArtifacts/\(name)"
                    ))
            )
        }
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let report =
            try MetalIndexedBirdSurfacePilotValidator
            .collisionGridPopulationStageProvenance(
                surface: surface,
                target: target,
                preregistration: try decode(
                    "deetjen-dove-collision-grid-preregistration.json",
                    as: MetalIndexedBirdSurfaceCollisionGridPreregistration.self
                ),
                discriminator: try decode(
                    "deetjen-dove-collision-grid-discriminator.json",
                    as: MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self
                ),
                completion: try decode(
                    "deetjen-dove-collision-grid-completion.json",
                    as: MetalIndexedBirdSurfaceCollisionGridCompletionReport.self
                )
            )
        #expect(report.provenanceGatePassed)
        #expect(report.maximumPredictionAbsoluteError == 0)
        #expect(report.firstNegativeCapturedStage == "post-collision")
        #expect(
            report.negativeMovingBoundaryReconstructedDirectionsAtFailure
                == [2, 8, 12, 13, 16])
    }

    @Test
    func productionMetalD16BoundaryTermDecompositionCloses() throws {
        func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            try JSONDecoder().decode(
                type,
                from: Data(
                    contentsOf: repositoryRootURL.appendingPathComponent(
                        "ValidationArtifacts/\(name)"
                    ))
            )
        }
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let report =
            try MetalIndexedBirdSurfacePilotValidator
            .collisionGridBoundaryTermDecomposition(
                surface: surface,
                target: target,
                preregistration: try decode(
                    "deetjen-dove-collision-grid-preregistration.json",
                    as: MetalIndexedBirdSurfaceCollisionGridPreregistration.self
                ),
                discriminator: try decode(
                    "deetjen-dove-collision-grid-discriminator.json",
                    as: MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self
                ),
                completion: try decode(
                    "deetjen-dove-collision-grid-completion.json",
                    as: MetalIndexedBirdSurfaceCollisionGridCompletionReport.self
                ),
                provenance: try decode(
                    "deetjen-dove-d16-population-stage-provenance.json",
                    as: MetalIndexedBirdSurfacePopulationStageProvenanceReport.self
                )
            )
        #expect(report.boundaryTermGatePassed)
        #expect(report.maximumContributionClosureResidual < 1e-9)
        #expect(report.maximumReconstructionDifferenceFromStageArtifact < 1e-9)
        #expect(
            report.negativeMovingBoundaryDirectionsAtFailure
                == [2, 8, 12, 13, 16])
        #expect(report.dominantRepairTarget == "moving-wall-correction")
    }

    @Test
    func productionMetalD16MovingWallCandidateClosesForceMomentumLedgers() throws {
        func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            try JSONDecoder().decode(
                type,
                from: Data(
                    contentsOf: repositoryRootURL.appendingPathComponent(
                        "ValidationArtifacts/\(name)"
                    ))
            )
        }
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let report =
            try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLedger(
                surface: surface,
                target: target,
                preregistration: try decode(
                    "deetjen-dove-collision-grid-preregistration.json",
                    as: MetalIndexedBirdSurfaceCollisionGridPreregistration.self
                ),
                discriminator: try decode(
                    "deetjen-dove-collision-grid-discriminator.json",
                    as: MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self
                ),
                completion: try decode(
                    "deetjen-dove-collision-grid-completion.json",
                    as: MetalIndexedBirdSurfaceCollisionGridCompletionReport.self
                ),
                provenance: try decode(
                    "deetjen-dove-d16-population-stage-provenance.json",
                    as: MetalIndexedBirdSurfacePopulationStageProvenanceReport.self
                ),
                boundaryTerms: try decode(
                    "deetjen-dove-d16-boundary-term-decomposition.json",
                    as: MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self
                ),
                admissibility: try decode(
                    "deetjen-dove-d16-moving-wall-admissibility-ab.json",
                    as: MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport.self
                )
            )
        #expect(report.ledgerGatePassed)
        #expect(report.result.completedSteps == 751)
        #expect(report.result.minimumPopulation > 0)
        #expect(report.result.relativeRMSRawControlVolumeClosureResidual <= 0.005)
        #expect(report.result.relativeRMSGlobalFluidClosureResidual <= 0.005)
        #expect(!report.productionDefaultModified)
    }

    @Test
    func productionMetalD16MovingWallCandidateCompletesRegisteredWindow() throws {
        func decode<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
            try JSONDecoder().decode(
                type,
                from: Data(
                    contentsOf: repositoryRootURL.appendingPathComponent(
                        "ValidationArtifacts/\(name)"
                    ))
            )
        }
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let report =
            try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallFullWindow(
                surface: surface,
                target: target,
                preregistration: try decode(
                    "deetjen-dove-collision-grid-preregistration.json",
                    as: MetalIndexedBirdSurfaceCollisionGridPreregistration.self
                ),
                discriminator: try decode(
                    "deetjen-dove-collision-grid-discriminator.json",
                    as: MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self
                ),
                completion: try decode(
                    "deetjen-dove-collision-grid-completion.json",
                    as: MetalIndexedBirdSurfaceCollisionGridCompletionReport.self
                ),
                provenance: try decode(
                    "deetjen-dove-d16-population-stage-provenance.json",
                    as: MetalIndexedBirdSurfacePopulationStageProvenanceReport.self
                ),
                boundaryTerms: try decode(
                    "deetjen-dove-d16-boundary-term-decomposition.json",
                    as: MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self
                ),
                admissibility: try decode(
                    "deetjen-dove-d16-moving-wall-admissibility-ab.json",
                    as: MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport.self
                ),
                retainedLedger: try decode(
                    "deetjen-dove-d16-moving-wall-ledger.json",
                    as: MetalIndexedBirdSurfaceMovingWallLedgerReport.self
                )
            )
        #expect(report.fullWindowGatePassed)
        #expect(report.ledgerResult.completedSteps == 7_552)
        #expect(report.registeredComparisonSampleCount == 187)
        #expect(report.ledgerResult.minimumPopulation > 0)
        #expect(report.ledgerResult.relativeRMSRawControlVolumeClosureResidual <= 0.005)
        #expect(report.ledgerResult.relativeRMSGlobalFluidClosureResidual <= 0.005)
        #expect(!report.productionDefaultModified)
        #expect(!report.experimentalAgreementGateApplied)
    }

    @Test
    func measuredBirdCollisionCandidatesCloseIndependentMomentumBudgets() throws {
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let report =
            try MetalIndexedBirdSurfacePilotValidator
            .collisionMomentumClosure(surface: surface, target: target)
        #expect(report.screeningGatePassed)
        #expect(report.allCandidateRunsCompleted)
        #expect(report.cases.count == 2)
        #expect(
            report.eligibleCollisionOperators == [
                "positivity-preserving-regularized-bgk",
                "positivity-preserving-recursive-regularized-bgk",
            ])
        #expect(report.minimumControlSurfaceDistanceFromSweptSurfaceCells >= 5)
        #expect(
            report.minimumControlSurfaceDistanceFromDomainBoundaryCells
                >= report.spongeWidthCells
        )
        for result in report.cases {
            #expect(result.completedSteps == 800)
            #expect(result.samples.count == 800)
            #expect(result.maximumSolidControlSurfaceCrossingLinkCount == 0)
            #expect(result.sampledPopulationPositivityPassed)
            #expect(result.momentumClosurePassed)
            #expect(
                result.relativeRMSRawControlVolumeClosureResidual <= 0.005
            )
            #expect(result.relativeRMSGlobalFluidClosureResidual <= 0.005)
        }
    }

    @Test
    func measuredBirdCollisionCandidatesCompleteExtendedPilot() throws {
        let surface = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: measuredBirdForceTargetURL,
            surface: surface
        )
        let report =
            try MetalIndexedBirdSurfacePilotValidator
            .collisionExtendedPilot(surface: surface, target: target)
        #expect(report.screeningGatePassed)
        #expect(report.allCandidateRunsCompleted)
        #expect(report.requestedFluidSteps == 3_776)
        #expect(report.requestedComparisonSamples == 187)
        #expect(report.populationDiagnosticStride == 1)
        #expect(report.cases.count == 2)
        #expect(
            report.eligibleCollisionOperators == [
                "positivity-preserving-regularized-bgk",
                "positivity-preserving-recursive-regularized-bgk",
            ])
        #expect(report.endpointPairwiseNormalizedRMSDifference != nil)
        #expect(report.intervalMeanPairwiseNormalizedRMSDifference != nil)
        for result in report.cases {
            #expect(result.completionAndPositivityGatePassed)
            #expect(result.correctionIntrusionGatePassed)
            #expect(result.eligibleForRefinementDiscrimination)
            #expect(result.report.completedFluidSteps == 3_776)
            #expect(result.report.recordedComparisonSamples == 187)
            #expect(result.report.recordedPopulationDiagnosticSamples == 3_776)
            #expect(result.report.allComponentsPresentAtComparisonSamples)
            #expect(result.report.allLoadsFinite)
            #expect(result.report.allSampledPopulationsFinite)
            #expect(result.report.sampledPopulationPositivityPassed)
            #expect(result.report.integrationGatePassed)
            #expect(
                result.report.collisionLimiterActivationFractionOfCellSteps
                    <= report.maximumCorrectionActivationFraction
            )
        }
    }

    @Test
    func indexedBirdSurfaceMetalGeometryClosesAllFramesAndCPUMilestones() throws {
        let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let report = try MetalIndexedBirdSurfaceValidator.audit(dataset)
        #expect(report.passed)
        #expect(report.frameAudits.count == 144)
        #expect(report.cpuRasterMilestoneFrames == [0, 33, 89, 126, 143])
        #expect(report.fractionalInterpolationProbeTimesSeconds.count == 5)
        #expect(report.maximumPreparedPositionErrorMeters <= 2e-7)
        #expect(report.maximumPreparedVelocityErrorMetersPerSecond <= 5e-3)
        #expect(report.maximumCPUMaskMismatchCellCount == 0)
        #expect(report.maximumCPUWallVelocityDifferenceLattice <= 2.5e-5)
        #expect(report.maximumCPUSignedDistanceDifferenceCells <= 2e-5)
        #expect(report.allComponentsPresentEveryFrame)
        #expect(report.allValuesFinite)
        #expect(!report.fluidCollisionExecuted)
        #expect(!report.forceAccumulationExecuted)
        #expect(
            report.frameAudits.allSatisfy {
                $0.componentSolidCellCounts.count == 4
                    && $0.componentSolidCellCounts.allSatisfy { $0 > 0 }
            })
    }

    @Test
    func indexedBirdSurfaceClosesProductionMovingBoundaryImpulse() throws {
        let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
            manifestURL: measuredBirdSurfaceManifestURL
        )
        let report = try MetalIndexedBirdSurfaceCouplingValidator.audit(dataset)
        #expect(report.passed)
        #expect(report.steps >= 8)
        #expect(report.newlyCoveredCellEvents > 0)
        #expect(report.newlyUncoveredCellEvents > 0)
        #expect(report.persistentBoundaryLinkEvents > 0)
        #expect(report.maximumTopologyCounterMismatchCells == 0)
        #expect(report.componentSolidCellCounts.count == 4)
        #expect(report.componentSolidCellCounts.allSatisfy { $0 > 0 })
        #expect(report.periodicBoundaries)
        #expect(report.spongeStrength == 0)
        #expect(report.maximumWallMach <= 0.15)
        #expect(report.relativeRMSBoundaryClosureResidual <= 0.005)
        #expect(report.allValuesFinite)
        #expect(report.fluidKernel == "stepFluidTRT")
        #expect(report.forceEstimator == "conservative-moving-domain-mode-6")
        #expect(
            report.samples.allSatisfy {
                $0.sourceLedgerTransitionCellCount
                    == $0.newlyCoveredCellCount + $0.newlyUncoveredCellCount
                    && $0.farFieldImpulseToFluid == .zero
                    && $0.spongeImpulseToFluid == .zero
            })
    }
#endif

private func vectorError(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>
) -> Float {
    let delta = first - second
    return sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
}

#!/usr/bin/env python3
"""Verify the locked Maeda/Dong physical-condition arithmetic.

This is a source-contract gate, not a CFD run. It deliberately verifies both
the published numerical target and the small non-closure caused by the rounded
values printed alongside it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


DEFAULT_AUDIT = Path(
    "ValidationArtifacts/measured-wing-physical-condition-audit.json"
)


def close(actual: float, expected: float, tolerance: float, label: str) -> None:
    relative = abs(actual - expected) / max(abs(expected), 1.0e-30)
    if relative > tolerance:
        raise SystemExit(
            f"{label} mismatch: actual={actual:.17g}, "
            f"expected={expected:.17g}, relative={relative:.3e}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify the measured-wing physical-condition audit"
    )
    parser.add_argument("audit", nargs="?", type=Path, default=DEFAULT_AUDIT)
    arguments = parser.parse_args()

    audit_bytes = arguments.audit.read_bytes()
    audit = json.loads(audit_bytes)
    measured = audit["measuredKinematics"]
    published = audit["publishedNumericalConvention"]
    reconstructed = audit["independentReconstruction"]

    amplitude = math.radians(measured["strokeAmplitudePeakToPeakDegrees"])
    speed = (
        2.0
        * amplitude
        * measured["frequencyHertz"]
        * measured["meanWingLengthMeters"]
    )
    reynolds = (
        published["airDensityKilogramsPerCubicMeter"]
        * published["referenceLengthMeters"]
        * speed
        / published["dynamicViscosityPascalSeconds"]
    )
    denominator = (
        0.5
        * published["airDensityKilogramsPerCubicMeter"]
        * published["referenceSpeedMetersPerSecond"] ** 2
        * published["referenceAreaSquareMeters"]
    )
    reynolds_gap = abs(
        published["targetReynoldsNumber"] - reynolds
    ) / published["targetReynoldsNumber"]

    close(
        speed,
        reconstructed["referenceSpeedFromRoundedInputsMetersPerSecond"],
        1.0e-14,
        "reference speed",
    )
    close(
        reynolds,
        reconstructed["reynoldsFromRoundedEquation8Inputs"],
        1.0e-14,
        "rounded-input Reynolds number",
    )
    close(
        denominator,
        published["forceCoefficientDenominatorNewtons"],
        1.0e-14,
        "force-coefficient denominator",
    )
    close(
        reynolds_gap,
        reconstructed["relativeDifferenceFromPublishedReynolds"],
        1.0e-14,
        "published Reynolds closure gap",
    )
    if audit["originalExperiment"]["reynoldsNumber"] is not None:
        raise SystemExit(
            "original experiment must not claim a reported Reynolds number"
        )
    if (
        audit["originalExperiment"]["airDensityKilogramsPerCubicMeter"]
        is not None
    ):
        raise SystemExit(
            "original experiment must not claim a measured air density"
        )
    if audit["replayDecision"]["existingLoadsCanBeRelabelledAsPublishedCondition"]:
        raise SystemExit(
            "Re=100 loads must not be relabelled as the published condition"
        )
    decision = audit["replayDecision"]
    if decision["sourceBackedNumericalReplayReady"]:
        raise SystemExit(
            "published-condition replay must remain blocked after the failed gate"
        )
    if decision["eightCellOneCycleFeasibilityPassed"]:
        raise SystemExit("eight-cell feasibility result must remain failed")
    if decision["twelveCellOneCycleFeasibilityPassed"]:
        raise SystemExit("twelve-cell feasibility result must remain failed")
    if decision["sixteenCellOneCycleFeasibilityPassed"]:
        raise SystemExit("sixteen-cell feasibility result must remain failed")
    if not decision["fixedMovingWallHighReStabilityPassed"]:
        raise SystemExit("fixed moving-wall high-Re stability gate must pass")
    if decision["collisionOnlyStabilitySuspect"]:
        raise SystemExit(
            "collision-only stability must be cleared by the fixed-wall gate"
        )
    if not decision["movingTopologyPathSuspect"]:
        raise SystemExit(
            "moving-topology path must remain suspect after the fixed-wall gate"
        )
    if decision["highReTranslatingBodyStabilityPassed"]:
        raise SystemExit(
            "high-Re translating-body gate must retain its failed verdict"
        )
    if not decision["cellCrossingMovingBoundaryPathConfirmed"]:
        raise SystemExit(
            "cell-crossing moving-boundary path must remain confirmed"
        )
    if decision["fixedOccupancyCurvedSphereStabilityPassed"]:
        raise SystemExit(
            "fixed-occupancy curved-sphere gate must retain its failed verdict"
        )
    if decision["coverUncoverRefillRequiredForInstability"]:
        raise SystemExit(
            "cover/uncover refill must not be required after the fixed-sphere failure"
        )
    if not decision["curvedNormalMovingLinkPathConfirmed"]:
        raise SystemExit(
            "curved normal moving-link path must remain confirmed"
        )
    if not decision["fixedOccupancyWallDecompositionCompleted"]:
        raise SystemExit(
            "fixed-occupancy wall decomposition must remain complete"
        )
    if decision["tangentialOnlyCurvedSphereStabilityPassed"]:
        raise SystemExit(
            "tangential-only curved-sphere gate must retain its failed verdict"
        )
    if decision["normalOnlyCurvedSphereStabilityPassed"]:
        raise SystemExit(
            "normal-only curved-sphere gate must retain its failed verdict"
        )
    if not decision["generalCurvedMovingLinkInstabilityConfirmed"]:
        raise SystemExit(
            "general curved moving-link instability must remain confirmed"
        )
    if decision["stationaryWallSphereStabilityPassed"]:
        raise SystemExit(
            "stationary-wall sphere stability gate must retain its failed verdict"
        )
    if not decision["stationaryWallSphereRelativeResidualGateApplied"]:
        raise SystemExit(
            "stationary-wall relative residual gate must remain active"
        )
    if decision["movingWallPopulationCorrectionInstabilityIsolated"]:
        raise SystemExit(
            "moving-wall population correction must not remain isolated as required"
        )
    if not decision[
        "generalCurvedHalfwayBounceBackLowRelaxationInstabilityConfirmed"
    ]:
        raise SystemExit(
            "general curved halfway-bounce-back instability must remain confirmed"
        )
    if not decision["stationaryWallRelaxationSweepCompleted"]:
        raise SystemExit("stationary-wall relaxation sweep must remain complete")
    if not decision["stationaryWallRelaxationStabilityMonotonic"]:
        raise SystemExit("corrected stationary-wall relaxation stability must remain monotonic")
    if not decision["stationaryWallRelaxationThresholdBracketed"]:
        raise SystemExit("corrected stationary-wall sweep must retain its threshold bracket")
    if not decision["viscosityOnlyStabilizationIsRobust"]:
        raise SystemExit("corrected stationary-wall viscosity stabilization must remain robust")
    if not decision["stationaryWallLongHorizonSurvivalCompleted"]:
        raise SystemExit("stationary-wall long-horizon audit must remain complete")
    if not decision["stationaryWallLongHorizonAllPointsSurvived"]:
        raise SystemExit("corrected long-horizon points must remain finite")
    if decision["stationaryWallLongHorizonFirstNonFiniteLoadSteps"] != [
        None,
        None,
        None,
    ]:
        raise SystemExit("corrected long-horizon finite history has changed")
    if decision["stationaryWallFiveHundredStepStabilityWasHorizonCensored"]:
        raise SystemExit("corrected 500-step threshold must not remain horizon-censored")
    if decision["apparentNonMonotonicStabilityBandIsGenuine"]:
        raise SystemExit("apparent non-monotonic stability band must remain rejected")
    if not decision["stationaryWallC16PopulationPositivityDiagnosticCompleted"]:
        raise SystemExit("c16 population positivity diagnostic must remain complete")
    if not decision["stationaryWallC16PopulationPositivityRepeatMatched"]:
        raise SystemExit("c16 population positivity events must remain repeatable")
    if decision["stationaryWallC16FirstNegativeStep"] != 27:
        raise SystemExit("c16 first-negative step has changed")
    if decision["stationaryWallC16FirstNegativeDirection"] != 10:
        raise SystemExit("c16 first-negative direction has changed")
    if decision["stationaryWallC16FirstNegativeCell"] != [5, 9, 12]:
        raise SystemExit("c16 first-negative cell has changed")
    if decision["stationaryWallC16FirstNegativeUpdatePath"] != (
        "ordinary-fluid-pull-trt-collision"
    ):
        raise SystemExit("c16 first-negative update path has changed")
    if decision["stationaryWallC16FirstNonFinitePopulationStep"] != 105:
        raise SystemExit("c16 first non-finite population step has changed")
    if decision["stationaryWallC16FirstNonFiniteLoadStep"] != 105:
        raise SystemExit("c16 first non-finite load step has changed")
    if not decision["stationaryWallC16FirstPositivityLossAtCurvedBoundary"]:
        raise SystemExit("c16 first positivity loss must remain boundary-adjacent")
    if decision["stationaryWallC16FirstPositivityLossAtFarField"]:
        raise SystemExit("c16 first positivity loss must remain away from the far field")
    if decision["stationaryWallC16FirstPositivityLossInsideSponge"]:
        raise SystemExit("c16 first positivity loss must remain outside the sponge")
    if not decision["stationaryWallC16FirstPositivityLossBornInTRTCollision"]:
        raise SystemExit("c16 first positivity loss must remain collision-born")
    if not decision["stationaryWallC16TRTCollisionDecompositionCompleted"]:
        raise SystemExit("c16 TRT collision decomposition must remain complete")
    if not decision["stationaryWallC16TRTCollisionDecompositionRepeatMatched"]:
        raise SystemExit("c16 TRT collision decomposition must remain repeatable")
    if decision["stationaryWallC16TRTCollisionCaptureStep"] != 27:
        raise SystemExit("c16 TRT collision capture step has changed")
    if decision["stationaryWallC16TRTCollisionTargetCell"] != [5, 9, 12]:
        raise SystemExit("c16 TRT collision target has changed")
    if decision["stationaryWallC16TRTFailingDirection"] != 10:
        raise SystemExit("c16 TRT failing direction has changed")
    if not decision["stationaryWallC16TRTSymmetricRelaxationOvershootIsolated"]:
        raise SystemExit("c16 symmetric TRT overshoot must remain isolated")
    if not decision["stationaryWallC16SymmetricLimiterABCompleted"]:
        raise SystemExit("c16 symmetric-limiter A/B must remain complete")
    if not decision["stationaryWallC16SymmetricLimiterABRepeatMatched"]:
        raise SystemExit("c16 symmetric-limiter A/B must remain repeatable")
    if not decision["stationaryWallC16SymmetricLimiterPositivityCleared"]:
        raise SystemExit("c16 symmetric-only limiter must retain cleared positivity")
    if decision["stationaryWallC16SymmetricLimiterStabilityPassed"]:
        raise SystemExit("c16 symmetric-only limiter must retain failed stability")
    if decision["stationaryWallC16SymmetricLimiterForceBudgetPassed"]:
        raise SystemExit("c16 symmetric-only limiter must retain failed budget")
    if decision["stationaryWallC16SymmetricLimiterPromoted"]:
        raise SystemExit("c16 symmetric-only limiter must not be promoted")
    if not decision["stationaryWallC16ConservationLedgerCompleted"]:
        raise SystemExit("c16 conservation ledger must remain complete")
    if not decision["stationaryWallC16ConservationLedgerRepeatMatched"]:
        raise SystemExit("c16 conservation ledger must remain repeatable")
    if not decision["stationaryWallC16ConservationGlobalLedgerClosed"]:
        raise SystemExit("c16 global conservation ledger must remain closed")
    if not decision["stationaryWallC16ConservationForceResidualLedgerClosed"]:
        raise SystemExit("c16 force-source ledger must remain closed")
    for key in (
        "stationaryWallC16LimiterArithmeticConservationCleared",
        "stationaryWallC16OpenFarFieldMassSourceDominates",
        "stationaryWallC16SpongeMomentumSourceDominates",
        "stationaryWallC16BoundaryLoadAccountingCleared",
    ):
        if not decision[key]:
            raise SystemExit(f"c16 source attribution lost {key}")
    for key in (
        "stationaryWallC16SourceAwareAcceptanceCompleted",
        "stationaryWallC16SourceAwareAcceptanceRepeatMatched",
        "stationaryWallC16SourceAwareControlVolumeOutsideSponge",
        "stationaryWallC16SourceAwareGlobalLedgerClosed",
        "stationaryWallC16SourceAwareStabilityPassed",
        "stationaryWallC16SourceAwareForceBudgetPassed",
        "stationaryWallC16SourceAwareAcceptancePassed",
    ):
        if not decision[key]:
            raise SystemExit(f"c16 source-aware acceptance lost {key}")
    for key in (
        "stationaryWallGeometricLimiterLadderCompleted",
        "stationaryWallGeometricLimiterLadderRepeatMatched",
        "stationaryWallGeometricLimiterControlVolumeFailureConfirmed",
    ):
        if not decision[key]:
            raise SystemExit(f"geometric limiter ladder lost {key}")
    if decision["stationaryWallGeometricLimiterLadderPassed"]:
        raise SystemExit("geometric limiter ladder must retain its failed verdict")
    if decision["stationaryWallGeometricLimiterPromoted"]:
        raise SystemExit("geometric limiter must remain excluded from bird replay")
    for key in (
        "stationaryWallC16RadialLimiterLocalizationCompleted",
        "stationaryWallC16RadialLimiterLocalizationRepeatMatched",
        "stationaryWallC16RadialLimiterLocalizationPassed",
        "stationaryWallC16RadialLimiterBulkCollisionPathConfirmed",
    ):
        if not decision[key]:
            raise SystemExit(f"radial limiter localization lost {key}")
    if decision["stationaryWallC16RadialLimiterBoundaryLocalized"]:
        raise SystemExit("radial limiter must remain classified as non-local")
    for key in (
        "stationaryWallC16BulkCollisionABCompleted",
        "stationaryWallC16BulkCollisionABPassed",
        "stationaryWallC16BulkCollisionABCandidatePositivityPassed",
        "stationaryWallC16BulkCollisionABCandidateGlobalLedgerClosed",
        "stationaryWallC16BulkCollisionABCandidateForceBudgetPassed",
        "stationaryWallC16BulkCollisionABCandidateRejectedBeforeLadder",
    ):
        if not decision[key]:
            raise SystemExit(f"bulk collision A/B lost {key}")
    if decision["stationaryWallC16BulkCollisionABCandidateNonIntrusivePassed"]:
        raise SystemExit("regularized candidate must retain failed intrusion gate")
    if decision["stationaryWallC16BulkCollisionABCandidateEligibleForRefinement"]:
        raise SystemExit("regularized candidate must remain excluded from refinement")
    for key in (
        "stationaryWallC16RecursiveRegularizationABCompleted",
        "stationaryWallC16RecursiveRegularizationABPassed",
        "stationaryWallC16RecursiveRegularizationCandidatePositivityPassed",
        "stationaryWallC16RecursiveRegularizationCandidateGlobalLedgerClosed",
        "stationaryWallC16RecursiveRegularizationCandidateForceBudgetPassed",
        "stationaryWallC16RecursiveRegularizationCandidateNonIntrusivePassed",
        "stationaryWallC16RecursiveRegularizationCandidateEligibleForRefinement",
    ):
        if not decision[key]:
            raise SystemExit(f"recursive regularization A/B lost {key}")
    for key in (
        "stationaryWallRecursiveRegularizationLadderCompleted",
        "stationaryWallRecursiveRegularizationLadderActivationNonIncreasing",
        "stationaryWallRecursiveRegularizationLadderCorrectionNonIncreasing",
        "stationaryWallRecursiveRegularizationLadderForceConvergenceFailureConfirmed",
    ):
        if not decision[key]:
            raise SystemExit(f"recursive regularization ladder lost {key}")
    if decision["stationaryWallRecursiveRegularizationLadderPassed"]:
        raise SystemExit("recursive regularization ladder must retain its failed verdict")
    if decision["stationaryWallRecursiveRegularizationLadderPromoted"]:
        raise SystemExit("recursive regularization must remain excluded from bird replay")
    if not decision["stationaryWallGPUVelocityUsesConfiguredWallSpeed"]:
        raise SystemExit("GPU wall velocity must remain sourced from the configured wall speed")
    actual_audit_hash = hashlib.sha256(audit_bytes).hexdigest()
    feasibilities = []
    for key in (
        "eightCellFeasibilityArtifact",
        "twelveCellFeasibilityArtifact",
        "sixteenCellFeasibilityArtifact",
    ):
        feasibility_path = Path(decision[key])
        feasibility = json.loads(feasibility_path.read_text(encoding="utf-8"))
        locked_audit_hash = feasibility["sourceLocks"][
            "physicalConditionAudit"
        ]["sha256"]
        if locked_audit_hash != actual_audit_hash:
            raise SystemExit(
                f"{feasibility_path} has a stale physical-condition audit hash"
            )
        if feasibility["stabilityGate"]["passed"]:
            raise SystemExit(
                f"{feasibility_path} must retain its failed stability verdict"
            )
        feasibilities.append(feasibility)

    fixed_wall_path = Path(decision["fixedMovingWallHighReStabilityArtifact"])
    fixed_wall = json.loads(fixed_wall_path.read_text(encoding="utf-8"))
    fixed_wall_audit_hash = fixed_wall["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if fixed_wall_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{fixed_wall_path} has a stale physical-condition audit hash"
        )
    if not fixed_wall["passed"]:
        raise SystemExit(f"{fixed_wall_path} must retain its passing verdict")
    if fixed_wall["topologyChanges"]:
        raise SystemExit(f"{fixed_wall_path} must isolate fixed topology")
    fixed_wall_cases = fixed_wall["cases"]
    if [case["matchedBirdChordCells"] for case in fixed_wall_cases] != [
        8,
        12,
        16,
    ]:
        raise SystemExit(f"{fixed_wall_path} has unexpected matched cases")
    for case in fixed_wall_cases:
        if not case["passed"]:
            raise SystemExit(f"{fixed_wall_path} contains a failed case")
        if case["finiteSteps"] != case["requestedSteps"]:
            raise SystemExit(f"{fixed_wall_path} contains an incomplete case")
        if case["firstNonFiniteStep"] is not None:
            raise SystemExit(f"{fixed_wall_path} contains a non-finite step")
        if (
            case["relativePopulationMassDrift"]
            > fixed_wall["maximumAllowedRelativePopulationMassDrift"]
        ):
            raise SystemExit(f"{fixed_wall_path} exceeds its mass-drift gate")
        if (
            case["maximumAbsolutePopulation"]
            > fixed_wall["maximumAllowedAbsolutePopulation"]
        ):
            raise SystemExit(f"{fixed_wall_path} exceeds its population gate")

    translating_path = Path(
        decision["highReTranslatingBodyStabilityArtifact"]
    )
    translating = json.loads(translating_path.read_text(encoding="utf-8"))
    translating_audit_hash = translating["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if translating_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{translating_path} has a stale physical-condition audit hash"
        )
    fixed_wall_hash = hashlib.sha256(fixed_wall_path.read_bytes()).hexdigest()
    locked_fixed_wall_hash = translating["sourceLocks"][
        "fixedMovingWallArtifact"
    ]["sha256"]
    if locked_fixed_wall_hash != fixed_wall_hash:
        raise SystemExit(
            f"{translating_path} has a stale fixed-wall artifact hash"
        )
    if translating["passed"]:
        raise SystemExit(f"{translating_path} must retain its failed verdict")
    if not translating["topologyChanges"]:
        raise SystemExit(f"{translating_path} must exercise topology changes")
    translating_cases = translating["cases"]
    if [case["matchedBirdChordCells"] for case in translating_cases] != [
        8,
        12,
        16,
    ]:
        raise SystemExit(f"{translating_path} has unexpected matched cases")
    if [case["firstNonFiniteLoadStep"] for case in translating_cases] != [
        276,
        282,
        287,
    ]:
        raise SystemExit(
            f"{translating_path} has changed non-finite load steps"
        )
    for case in translating_cases:
        if case["passed"]:
            raise SystemExit(f"{translating_path} contains a passing case")
        if case["loadsFinite"] or case["populationsFinite"]:
            raise SystemExit(
                f"{translating_path} must retain its non-finite diagnosis"
            )
        if case["newlyCoveredCellEvents"] <= 0:
            raise SystemExit(f"{translating_path} has no cover events")
        if case["newlyUncoveredCellEvents"] <= 0:
            raise SystemExit(f"{translating_path} has no uncover events")
        if case["maximumSolidControlSurfaceCrossingLinkCount"] != 0:
            raise SystemExit(
                f"{translating_path} has a contaminated control surface"
            )

    fixed_sphere_path = Path(
        decision["fixedOccupancyCurvedSphereStabilityArtifact"]
    )
    fixed_sphere = json.loads(
        fixed_sphere_path.read_text(encoding="utf-8")
    )
    fixed_sphere_audit_hash = fixed_sphere["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if fixed_sphere_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{fixed_sphere_path} has a stale physical-condition audit hash"
        )
    locked_planar_hash = fixed_sphere["sourceLocks"][
        "fixedPlanarWallArtifact"
    ]["sha256"]
    if locked_planar_hash != fixed_wall_hash:
        raise SystemExit(
            f"{fixed_sphere_path} has a stale fixed-wall artifact hash"
        )
    translating_hash = hashlib.sha256(
        translating_path.read_bytes()
    ).hexdigest()
    locked_translating_hash = fixed_sphere["sourceLocks"][
        "translatingSphereArtifact"
    ]["sha256"]
    if locked_translating_hash != translating_hash:
        raise SystemExit(
            f"{fixed_sphere_path} has a stale translating artifact hash"
        )
    if fixed_sphere["passed"]:
        raise SystemExit(f"{fixed_sphere_path} must retain its failed verdict")
    if fixed_sphere["topologyChanges"]:
        raise SystemExit(f"{fixed_sphere_path} must retain fixed occupancy")
    fixed_sphere_cases = fixed_sphere["cases"]
    if [case["matchedBirdChordCells"] for case in fixed_sphere_cases] != [
        8,
        12,
        16,
    ]:
        raise SystemExit(f"{fixed_sphere_path} has unexpected matched cases")
    if [case["firstNonFiniteLoadStep"] for case in fixed_sphere_cases] != [
        71,
        71,
        72,
    ]:
        raise SystemExit(
            f"{fixed_sphere_path} has changed non-finite load steps"
        )
    for case in fixed_sphere_cases:
        if case["passed"]:
            raise SystemExit(f"{fixed_sphere_path} contains a passing case")
        if case["loadsFinite"] or case["populationsFinite"]:
            raise SystemExit(
                f"{fixed_sphere_path} must retain its non-finite diagnosis"
            )
        if case["newlyCoveredCellEvents"] != 0:
            raise SystemExit(f"{fixed_sphere_path} contains cover events")
        if case["newlyUncoveredCellEvents"] != 0:
            raise SystemExit(f"{fixed_sphere_path} contains uncover events")
        if case["topologyTransitionSteps"] != 0:
            raise SystemExit(
                f"{fixed_sphere_path} contains topology transitions"
            )

    decomposition_path = Path(
        decision["fixedOccupancyWallDecompositionArtifact"]
    )
    decomposition = json.loads(
        decomposition_path.read_text(encoding="utf-8")
    )
    decomposition_audit_hash = decomposition["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if decomposition_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{decomposition_path} has a stale physical-condition audit hash"
        )
    fixed_sphere_hash = hashlib.sha256(
        fixed_sphere_path.read_bytes()
    ).hexdigest()
    locked_fixed_sphere_hash = decomposition["sourceLocks"][
        "uniformFixedOccupancySphereArtifact"
    ]["sha256"]
    if locked_fixed_sphere_hash != fixed_sphere_hash:
        raise SystemExit(
            f"{decomposition_path} has a stale fixed-sphere artifact hash"
        )
    if not decomposition["diagnosticCompleted"]:
        raise SystemExit(f"{decomposition_path} must remain complete")
    if (
        decomposition["classification"]
        != "general-curved-moving-link-instability-confirmed"
    ):
        raise SystemExit(f"{decomposition_path} has changed classification")
    components = {
        result["wallVelocityMode"]: result
        for result in decomposition["componentResults"]
    }
    expected_component_steps = {
        "normal-only": [86, 86, 86],
        "tangential-only": [186, 187, 189],
    }
    if set(components) != set(expected_component_steps):
        raise SystemExit(f"{decomposition_path} has unexpected components")
    for mode, expected_steps in expected_component_steps.items():
        component = components[mode]
        if component["firstNonFiniteLoadSteps"] != expected_steps:
            raise SystemExit(
                f"{decomposition_path} has changed {mode} failure steps"
            )
        if component["passed"]:
            raise SystemExit(
                f"{decomposition_path} contains a passing {mode} case"
            )
        if component["newlyCoveredCellEvents"] != 0:
            raise SystemExit(f"{decomposition_path} contains cover events")
        if component["newlyUncoveredCellEvents"] != 0:
            raise SystemExit(f"{decomposition_path} contains uncover events")

    stationary_path = Path(
        decision["stationaryWallSphereStabilityArtifact"]
    )
    stationary = json.loads(
        stationary_path.read_text(encoding="utf-8")
    )
    stationary_audit_hash = stationary["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if stationary_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{stationary_path} has a stale physical-condition audit hash"
        )
    decomposition_hash = hashlib.sha256(
        decomposition_path.read_bytes()
    ).hexdigest()
    locked_decomposition_hash = stationary["sourceLocks"][
        "wallDecompositionArtifact"
    ]["sha256"]
    if locked_decomposition_hash != decomposition_hash:
        raise SystemExit(
            f"{stationary_path} has a stale wall-decomposition artifact hash"
        )
    if stationary["passed"]:
        raise SystemExit(f"{stationary_path} must retain its failed verdict")
    if (
        stationary["classification"]
        != "high-re-stationary-wall-sphere-unstable-general-curved-link-path-confirmed"
    ):
        raise SystemExit(f"{stationary_path} has changed classification")
    if stationary["topologyChanges"]:
        raise SystemExit(f"{stationary_path} must retain fixed occupancy")
    if stationary["translationSpeedLattice"] != 0:
        raise SystemExit(f"{stationary_path} must retain fixed geometry")
    if stationary["wallVelocityLattice"] != 0:
        raise SystemExit(f"{stationary_path} must retain a stationary wall")
    if stationary["periodicBoundaries"]:
        raise SystemExit(f"{stationary_path} must retain maintained far-field boundaries")
    close(stationary["spongeStrength"], 0.04, 1.0e-14, "stationary sphere sponge")
    if stationary["farFieldVelocityLattice"] <= 0:
        raise SystemExit(f"{stationary_path} must retain uniform external flow")
    stationary_cases = stationary["cases"]
    if [case["matchedBirdChordCells"] for case in stationary_cases] != [
        8,
        12,
        16,
    ]:
        raise SystemExit(f"{stationary_path} has unexpected matched cases")
    for case in stationary_cases:
        if case["passed"]:
            raise SystemExit(f"{stationary_path} contains a passing case")
        if case["finiteLoadSteps"] != 104:
            raise SystemExit(f"{stationary_path} has changed finite history length")
        if case["firstNonFiniteLoadStep"] != 105:
            raise SystemExit(f"{stationary_path} has changed failure step")
        if any(
            case[key]
            for key in ("populationsFinite", "fieldsFinite", "loadsFinite")
        ):
            raise SystemExit(f"{stationary_path} must retain non-finite state")
        if not case["relativeResidualGateApplied"]:
            raise SystemExit(f"{stationary_path} must retain an active relative gate")
        if case["maximumMeasuredForceMagnitude"] <= 0.01:
            raise SystemExit(f"{stationary_path} did not measure an active load")
        if case["newlyCoveredCellEvents"] != 0:
            raise SystemExit(f"{stationary_path} contains cover events")
        if case["newlyUncoveredCellEvents"] != 0:
            raise SystemExit(f"{stationary_path} contains uncover events")
        if case["topologyTransitionSteps"] != 0:
            raise SystemExit(f"{stationary_path} contains topology transitions")

    sweep_path = Path(decision["stationaryWallRelaxationSweepArtifact"])
    sweep = json.loads(sweep_path.read_text(encoding="utf-8"))
    sweep_audit_hash = sweep["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if sweep_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{sweep_path} has a stale physical-condition audit hash"
        )
    stationary_hash = hashlib.sha256(stationary_path.read_bytes()).hexdigest()
    locked_stationary_hash = sweep["sourceLocks"][
        "stationaryWallSphereArtifact"
    ]["sha256"]
    if locked_stationary_hash != stationary_hash:
        raise SystemExit(
            f"{sweep_path} has a stale stationary-wall artifact hash"
        )
    if not sweep["diagnosticCompleted"]:
        raise SystemExit(f"{sweep_path} must remain complete")
    if (
        sweep["classification"]
        != "stationary-wall-relaxation-threshold-bracketed"
    ):
        raise SystemExit(f"{sweep_path} has changed classification")
    if not sweep["stabilityMonotonicWithMargin"]:
        raise SystemExit(f"{sweep_path} must retain monotonic stability")
    if not sweep["thresholdBracketed"]:
        raise SystemExit(f"{sweep_path} must retain its robust threshold")
    if not sweep["firstTransitionBracketed"]:
        raise SystemExit(f"{sweep_path} must retain its first transition")
    close(
        sweep["firstTransitionLowerUnstableTauPlusMarginAboveHalf"],
        decision["stationaryWallFirstTransitionLowerUnstableMargin"],
        1.0e-14,
        "first relaxation transition lower margin",
    )
    close(
        sweep["firstTransitionUpperStableTauPlusMarginAboveHalf"],
        decision["stationaryWallFirstTransitionUpperStableMargin"],
        1.0e-14,
        "first relaxation transition upper margin",
    )
    if sweep["unstableTauPlusMarginsAfterFirstStable"]:
        raise SystemExit(f"{sweep_path} has regained a post-stable relapse")
    if sweep["newlyCoveredCellEventsAcrossSweep"] != 0:
        raise SystemExit(f"{sweep_path} contains cover events")
    if sweep["newlyUncoveredCellEventsAcrossSweep"] != 0:
        raise SystemExit(f"{sweep_path} contains uncover events")
    if sweep["maximumTopologyTransitionSteps"] != 0:
        raise SystemExit(f"{sweep_path} contains topology transitions")
    sweep_points = sweep["points"]
    expected_requested_margins = [
        0.00025,
        0.0005,
        0.001,
        0.002,
        0.005,
        0.01,
        0.0125,
        0.015,
        0.015625,
        0.01625,
        0.016875,
        0.0175,
        0.02,
        0.05,
    ]
    if len(sweep_points) != len(expected_requested_margins):
        raise SystemExit(f"{sweep_path} has changed point count")
    for point, expected_margin in zip(sweep_points, expected_requested_margins):
        close(
            point["requestedTauPlusMarginAboveHalf"],
            expected_margin,
            1.0e-6,
            "relaxation sweep requested margin",
        )
    expected_stability = [
        False,
        False,
        False,
        False,
        False,
        False,
        True,
        True,
        True,
        True,
        True,
        True,
        True,
        True,
    ]
    expected_failure_steps = [
        105,
        107,
        112,
        123,
        208,
        454,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
        None,
    ]
    if [point["stabilityPassed"] for point in sweep_points] != expected_stability:
        raise SystemExit(f"{sweep_path} has changed stability outcomes")
    if [
        point.get("firstNonFiniteLoadStep") for point in sweep_points
    ] != expected_failure_steps:
        raise SystemExit(f"{sweep_path} has changed failure steps")
    if any(point["fullAcceptancePassed"] for point in sweep_points):
        raise SystemExit(f"{sweep_path} must retain failed full acceptance")
    for point in sweep_points:
        if point["stabilityPassed"]:
            if point["relativePopulationMassDrift"] > 1.0e-3:
                raise SystemExit(f"{sweep_path} exceeds stable mass drift")
            if point["maximumAbsolutePopulation"] > 10.0:
                raise SystemExit(f"{sweep_path} exceeds stable population bound")

    long_horizon_path = Path(
        decision["stationaryWallLongHorizonSurvivalArtifact"]
    )
    long_horizon = json.loads(
        long_horizon_path.read_text(encoding="utf-8")
    )
    long_horizon_audit_hash = long_horizon["sourceLocks"][
        "physicalConditionAudit"
    ]["sha256"]
    if long_horizon_audit_hash != actual_audit_hash:
        raise SystemExit(
            f"{long_horizon_path} has a stale physical-condition audit hash"
        )
    sweep_hash = hashlib.sha256(sweep_path.read_bytes()).hexdigest()
    locked_sweep_hash = long_horizon["sourceLocks"][
        "relaxationSweepArtifact"
    ]["sha256"]
    if locked_sweep_hash != sweep_hash:
        raise SystemExit(
            f"{long_horizon_path} has a stale relaxation-sweep artifact hash"
        )
    if not long_horizon["diagnosticCompleted"]:
        raise SystemExit(f"{long_horizon_path} must remain complete")
    if (
        long_horizon["classification"]
        != "stationary-wall-apparent-stability-survives-1000"
    ):
        raise SystemExit(f"{long_horizon_path} has changed classification")
    if long_horizon["survivingPointCount"] != 3:
        raise SystemExit(f"{long_horizon_path} must retain three survivors")
    if not long_horizon["allApparentStablePointsSurvived"]:
        raise SystemExit(f"{long_horizon_path} must retain complete survival")
    if not long_horizon["repeatRunMatchedFailureSteps"]:
        raise SystemExit(f"{long_horizon_path} must retain repeatability")
    if long_horizon["requestedStepsPerPoint"] != 1_000:
        raise SystemExit(f"{long_horizon_path} has changed its horizon")
    if long_horizon["newlyCoveredCellEventsAcrossAudit"] != 0:
        raise SystemExit(f"{long_horizon_path} contains cover events")
    if long_horizon["newlyUncoveredCellEventsAcrossAudit"] != 0:
        raise SystemExit(f"{long_horizon_path} contains uncover events")
    if long_horizon["maximumTopologyTransitionSteps"] != 0:
        raise SystemExit(f"{long_horizon_path} contains topology transitions")
    long_horizon_points = long_horizon["points"]
    if len(long_horizon_points) != 3:
        raise SystemExit(f"{long_horizon_path} has changed point count")
    for point, expected_margin in zip(
        long_horizon_points,
        [0.015625, 0.016875, 0.02],
    ):
        close(
            point["requestedTauPlusMarginAboveHalf"],
            expected_margin,
            1.0e-6,
            "long-horizon requested margin",
        )
    long_horizon_failure_steps = [
        point.get("firstNonFiniteLoadStep")
        for point in long_horizon_points
    ]
    if long_horizon_failure_steps != [None, None, None]:
        raise SystemExit(f"{long_horizon_path} has changed failure steps")
    for point in long_horizon_points:
        if point["finiteLoadSteps"] != 1_000:
            raise SystemExit(f"{long_horizon_path} has inconsistent finite steps")
        if not point["stabilityPassed"] or point["fullAcceptancePassed"]:
            raise SystemExit(f"{long_horizon_path} changed stability or acceptance")
        if not all(
            point[key]
            for key in ("populationsFinite", "fieldsFinite", "loadsFinite")
        ):
            raise SystemExit(f"{long_horizon_path} must retain finite state")
        if point["relativePopulationMassDrift"] > 1.1e-4:
            raise SystemExit(f"{long_horizon_path} exceeds corrected mass drift")
        if point["maximumAbsolutePopulation"] > 1.0:
            raise SystemExit(f"{long_horizon_path} exceeds corrected population bound")

    positivity_path = Path(
        decision["stationaryWallC16PopulationPositivityArtifact"]
    )
    positivity_bytes = positivity_path.read_bytes()
    positivity_hash = hashlib.sha256(positivity_bytes).hexdigest()
    if positivity_hash != decision[
        "stationaryWallC16PopulationPositivityArtifactSHA256"
    ]:
        raise SystemExit(f"{positivity_path} has changed artifact hash")
    positivity = json.loads(positivity_bytes)
    if not positivity["diagnosticCompleted"]:
        raise SystemExit(f"{positivity_path} must remain complete")
    if positivity["diagnosticKernel"] != "reducePopulationMinimum":
        raise SystemExit(f"{positivity_path} has changed diagnostic kernel")
    if positivity["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{positivity_path} has changed production kernel")
    if positivity["classification"] != (
        "stationary-wall-c16-first-positivity-loss-"
        "curved-boundary-adjacent-fluid-pull"
    ):
        raise SystemExit(f"{positivity_path} has changed classification")
    if positivity["domainCells"] != [56, 24, 24]:
        raise SystemExit(f"{positivity_path} has changed domain")
    if positivity["sphereCenterCells"] != [8, 12, 12]:
        raise SystemExit(f"{positivity_path} has changed sphere center")
    close(positivity["sphereRadiusCells"], 3.25, 1.0e-14, "positivity sphere radius")
    close(positivity["farFieldVelocityLattice"], 0.08, 1.0e-14, "positivity far field")
    if positivity["wallVelocityLattice"] != 0:
        raise SystemExit(f"{positivity_path} must retain a stationary wall")
    if positivity["spongeWidthCells"] != 4:
        raise SystemExit(f"{positivity_path} has changed sponge width")
    close(positivity["spongeStrength"], 0.04, 1.0e-7, "positivity sponge strength")
    if positivity["matchedBirdChordCells"] != 16:
        raise SystemExit(f"{positivity_path} must remain the c16 case")
    if positivity["requestedSteps"] != 500 or positivity["completedSteps"] != 106:
        raise SystemExit(f"{positivity_path} has changed its run horizon")
    if positivity["firstNonFiniteLoadStep"] != 105:
        raise SystemExit(f"{positivity_path} has changed load failure step")
    if any(
        positivity[key]
        for key in (
            "newlyCoveredCellEvents",
            "newlyUncoveredCellEvents",
            "topologyTransitionSteps",
        )
    ):
        raise SystemExit(f"{positivity_path} contains topology changes")
    initial = positivity["initialMinimum"]
    if initial["valueClassification"] != "finite":
        raise SystemExit(f"{positivity_path} has a non-finite initial state")
    if initial["minimumPopulation"] <= 0:
        raise SystemExit(f"{positivity_path} must start population-positive")
    history = positivity["minimumHistory"]
    if len(history) != positivity["completedSteps"] + 1:
        raise SystemExit(f"{positivity_path} has incomplete minimum history")
    if [sample["step"] for sample in history] != list(range(107)):
        raise SystemExit(f"{positivity_path} has non-contiguous history")
    negative = positivity["firstNegative"]
    if negative != history[27]:
        raise SystemExit(f"{positivity_path} first negative is not history step 27")
    if negative["directionIndex"] != 10 or negative["cell"] != [5, 9, 12]:
        raise SystemExit(f"{positivity_path} has changed first-negative location")
    if negative["latticeDirection"] != [-1, 1, 0]:
        raise SystemExit(f"{positivity_path} has changed first-negative direction")
    if negative["pullSourceCell"] != [6, 8, 12]:
        raise SystemExit(f"{positivity_path} has changed first-negative pull source")
    if not negative["pullSourceInsideDomain"] or negative["pullSourceIsSolid"]:
        raise SystemExit(f"{positivity_path} first-negative source is not ordinary fluid")
    if negative["cellIsSolid"] or not negative["cellAdjacentToSphere"]:
        raise SystemExit(f"{positivity_path} first-negative cell lost boundary adjacency")
    if negative["insideSponge"] or negative["spongeFactor"] != 0:
        raise SystemExit(f"{positivity_path} first-negative cell reached the sponge")
    if negative["populationUpdatePath"] != "ordinary-fluid-pull-trt-collision":
        raise SystemExit(f"{positivity_path} has changed first-negative update path")
    close(
        negative["signedDistanceToSphereSurfaceCells"],
        decision["stationaryWallC16FirstNegativeSphereDistanceCells"],
        1.0e-14,
        "first-negative sphere distance",
    )
    non_finite = positivity["firstNonFinite"]
    if non_finite != history[105]:
        raise SystemExit(f"{positivity_path} first non-finite is not history step 105")
    if non_finite["directionIndex"] != 0 or non_finite["cell"] != [2, 10, 9]:
        raise SystemExit(f"{positivity_path} has changed first non-finite location")
    if non_finite["valueClassification"] != "nan":
        raise SystemExit(f"{positivity_path} must retain a NaN first failure")
    if not non_finite["insideSponge"]:
        raise SystemExit(f"{positivity_path} first non-finite left the sponge")

    trt_path = Path(
        decision["stationaryWallC16TRTCollisionDecompositionArtifact"]
    )
    trt_bytes = trt_path.read_bytes()
    trt_hash = hashlib.sha256(trt_bytes).hexdigest()
    if trt_hash != decision[
        "stationaryWallC16TRTCollisionDecompositionArtifactSHA256"
    ]:
        raise SystemExit(f"{trt_path} has changed artifact hash")
    trt = json.loads(trt_bytes)
    if not trt["diagnosticCompleted"]:
        raise SystemExit(f"{trt_path} must remain complete")
    if trt["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{trt_path} has changed production kernel")
    if trt["diagnosticKernel"] != "captureTRTCollisionDecomposition":
        raise SystemExit(f"{trt_path} has changed diagnostic kernel")
    if trt["classification"] != (
        "stationary-wall-c16-trt-symmetric-relaxation-overshoot"
    ):
        raise SystemExit(f"{trt_path} has changed classification")
    if trt["captureStep"] != 27 or trt["targetCell"] != [5, 9, 12]:
        raise SystemExit(f"{trt_path} has changed capture location")
    if not trt["targetAdjacentToSphere"] or trt["targetIsSolid"]:
        raise SystemExit(f"{trt_path} target must remain boundary-adjacent fluid")
    if trt["solidPullSourceCount"] != 5:
        raise SystemExit(f"{trt_path} has changed solid pull-source count")
    if trt["outsideDomainPullSourceCount"] != 0:
        raise SystemExit(f"{trt_path} contains outside-domain pull sources")
    if trt["spongeFactor"] != 0:
        raise SystemExit(f"{trt_path} target must remain outside the sponge")
    if not trt["allPulledPopulationsPositive"]:
        raise SystemExit(f"{trt_path} must retain positive pulled populations")
    if trt["minimumPulledPopulation"] <= 0:
        raise SystemExit(f"{trt_path} has a non-positive pulled population")
    if trt["minimumActualPostCollisionDirection"] != 10:
        raise SystemExit(f"{trt_path} has changed minimum output direction")
    if trt["dominantDestabilizingRelaxationMode"] != "symmetric":
        raise SystemExit(f"{trt_path} has changed dominant relaxation mode")
    close(
        trt["omegaPlus"],
        decision["stationaryWallC16TRTOmegaPlus"],
        1.0e-14,
        "c16 TRT omega plus",
    )
    close(
        trt["omegaMinus"],
        decision["stationaryWallC16TRTOmegaMinus"],
        1.0e-14,
        "c16 TRT omega minus",
    )
    close(
        trt["maximumAbsolutePredictionResidual"],
        decision["stationaryWallC16TRTMaximumPredictionResidual"],
        1.0e-14,
        "c16 TRT prediction residual",
    )
    if trt["maximumAbsolutePredictionResidual"] > 1.0e-7:
        raise SystemExit(f"{trt_path} no longer closes against production")
    close(
        trt["maximumAbsoluteBoundaryWallCorrection"],
        decision["stationaryWallC16TRTMaximumBoundaryWallCorrection"],
        1.0e-14,
        "c16 TRT boundary wall correction",
    )
    if trt.get("failingBoundaryInterpolation") is not None:
        raise SystemExit(f"{trt_path} failing q=10 must remain a fluid pull")
    terms = trt["directionTerms"]
    if len(terms) != 19:
        raise SystemExit(f"{trt_path} must retain all D3Q19 directions")
    if [term["directionIndex"] for term in terms] != list(range(19)):
        raise SystemExit(f"{trt_path} direction terms are incomplete")
    failing_trt = trt["failingDirection"]
    if failing_trt != terms[10]:
        raise SystemExit(f"{trt_path} failing direction is not q=10")
    if failing_trt["latticeDirection"] != [-1, 1, 0]:
        raise SystemExit(f"{trt_path} has changed q=10 direction")
    if failing_trt["pullSourceCell"] != [6, 8, 12]:
        raise SystemExit(f"{trt_path} has changed q=10 pull source")
    if not failing_trt["pullSourceInsideDomain"] or failing_trt["pullSourceIsSolid"]:
        raise SystemExit(f"{trt_path} q=10 source is not ordinary fluid")
    for key, decision_key in (
        ("pulledPopulation", "stationaryWallC16TRTPulledPopulation"),
        ("symmetricRelaxationIncrement", "stationaryWallC16TRTSymmetricIncrement"),
        ("antisymmetricRelaxationIncrement", "stationaryWallC16TRTAntisymmetricIncrement"),
        ("postWithoutSymmetricIncrement", "stationaryWallC16TRTPostWithoutSymmetricIncrement"),
        ("postWithoutAntisymmetricIncrement", "stationaryWallC16TRTPostWithoutAntisymmetricIncrement"),
        ("actualPostCollision", "stationaryWallC16TRTActualPostCollision"),
    ):
        close(failing_trt[key], decision[decision_key], 1.0e-14, f"c16 TRT {key}")
    if failing_trt["postWithoutSymmetricIncrement"] <= 0:
        raise SystemExit(f"{trt_path} no longer isolates the symmetric increment")
    if failing_trt["postWithoutAntisymmetricIncrement"] >= 0:
        raise SystemExit(f"{trt_path} no longer rejects antisymmetric causation")
    if any(
        trt[key]
        for key in (
            "newlyCoveredCellEvents",
            "newlyUncoveredCellEvents",
            "topologyTransitionSteps",
        )
    ):
        raise SystemExit(f"{trt_path} contains topology changes")

    limiter_path = Path(
        decision["stationaryWallC16SymmetricLimiterABArtifact"]
    )
    limiter_bytes = limiter_path.read_bytes()
    limiter_hash = hashlib.sha256(limiter_bytes).hexdigest()
    if limiter_hash != decision[
        "stationaryWallC16SymmetricLimiterABArtifactSHA256"
    ]:
        raise SystemExit(f"{limiter_path} has changed artifact hash")
    limiter = json.loads(limiter_bytes)
    if not limiter["diagnosticCompleted"]:
        raise SystemExit(f"{limiter_path} must remain complete")
    if limiter["classification"] != (
        "stationary-wall-c16-symmetric-limiter-source-aware-accepted"
    ):
        raise SystemExit(f"{limiter_path} has changed classification")
    if limiter["schemaVersion"] != 3:
        raise SystemExit(f"{limiter_path} has changed schema")
    if limiter["requestedStepsPerCase"] != 500:
        raise SystemExit(f"{limiter_path} has changed its horizon")
    if limiter["maximumPreActivationMeasuredForceDifference"] != 0:
        raise SystemExit(f"{limiter_path} changes pre-activation loads")
    if limiter["maximumPreActivationBudgetForceDifference"] != 0:
        raise SystemExit(f"{limiter_path} changes pre-activation budget")
    limiter_control = limiter["control"]
    if limiter_control["firstNegativePopulationStep"] != 27:
        raise SystemExit(f"{limiter_path} has changed control negativity")
    if limiter_control["firstNonFinitePopulationStep"] != 105:
        raise SystemExit(f"{limiter_path} has changed control population failure")
    if limiter_control["firstNonFiniteLoadStep"] != 105:
        raise SystemExit(f"{limiter_path} has changed control load failure")
    if limiter_control["limiterActivationCellSteps"] != 0:
        raise SystemExit(f"{limiter_path} control activated the limiter")
    limiter_treatment = limiter["treatment"]
    if limiter_treatment["completedSteps"] != 500:
        raise SystemExit(f"{limiter_path} treatment did not finish")
    if limiter_treatment["firstLimiterActivationStep"] != 27:
        raise SystemExit(f"{limiter_path} has changed first activation")
    if limiter_treatment.get("firstNegativePopulationStep") is not None:
        raise SystemExit(f"{limiter_path} treatment must remain population-positive")
    if limiter_treatment.get("firstNonFinitePopulationStep") is not None:
        raise SystemExit(f"{limiter_path} treatment must remain finite")
    if limiter_treatment.get("firstNonFiniteLoadStep") is not None:
        raise SystemExit(f"{limiter_path} treated loads must remain finite")
    if not all(
        limiter_treatment[key]
        for key in ("populationsFinite", "fieldsFinite", "loadsFinite")
    ):
        raise SystemExit(f"{limiter_path} treatment must remain finite")
    for key, decision_key in (
        ("limiterActivationCellSteps", "stationaryWallC16SymmetricLimiterActivationCellSteps"),
        ("limiterActivationSteps", "stationaryWallC16SymmetricLimiterActivationSteps"),
        ("firstZeroLimiterScaleStep", "stationaryWallC16SymmetricLimiterFirstZeroScaleStep"),
        ("maximumLimiterActivationsInOneStep", "stationaryWallC16SymmetricLimiterMaximumActivationsInOneStep"),
    ):
        if limiter_treatment.get(key) != decision[decision_key]:
            raise SystemExit(f"{limiter_path} has changed {key}")
    for key, decision_key in (
        ("minimumLimiterScale", "stationaryWallC16SymmetricLimiterMinimumScale"),
        ("relativePopulationMassDrift", "stationaryWallC16SymmetricLimiterRelativeMassDrift"),
        ("minimumObservedPopulation", "stationaryWallC16SymmetricLimiterMinimumObservedPopulation"),
        ("maximumConservativeForceResidual", "stationaryWallC16SymmetricLimiterMaximumForceResidual"),
        ("conservativeRelativeRMSResidual", "stationaryWallC16SymmetricLimiterRelativeRMSResidual"),
    ):
        close(limiter_treatment[key], decision[decision_key], 1.0e-14, key)
    if limiter_treatment["stabilityPassed"]:
        raise SystemExit(f"{limiter_path} must retain failed treated stability")
    if limiter_treatment["forceBudgetPassed"]:
        raise SystemExit(f"{limiter_path} must retain failed treated budget")
    if limiter_treatment["fullAcceptancePassed"]:
        raise SystemExit(f"{limiter_path} must not be accepted")
    if limiter_treatment["relativePopulationMassDrift"] <= limiter[
        "maximumAllowedRelativePopulationMassDrift"
    ]:
        raise SystemExit(f"{limiter_path} mass drift unexpectedly passes")
    if limiter_treatment["maximumConservativeForceResidual"] <= limiter[
        "maximumAllowedConservativeForceResidual"
    ]:
        raise SystemExit(f"{limiter_path} force residual unexpectedly passes")
    if limiter_treatment["conservativeRelativeRMSResidual"] <= limiter[
        "maximumAllowedConservativeRelativeRMSResidual"
    ]:
        raise SystemExit(f"{limiter_path} relative RMS residual unexpectedly passes")
    if limiter_treatment["minimumObservedPopulation"] <= 0:
        raise SystemExit(f"{limiter_path} treatment lost population positivity")
    if limiter_treatment["finalMinimumPopulation"] <= 0:
        raise SystemExit(f"{limiter_path} treatment ended population-negative")
    if limiter_treatment["maximumAbsolutePopulation"] > limiter[
        "maximumAllowedAbsolutePopulation"
    ]:
        raise SystemExit(f"{limiter_path} treatment exceeded its population bound")

    ledger = limiter["treatmentConservationLedger"]
    if not ledger["globalLedgerClosed"]:
        raise SystemExit(f"{limiter_path} global ledger no longer closes")
    if not ledger["forceResidualLedgerClosed"]:
        raise SystemExit(f"{limiter_path} force-source ledger no longer closes")
    if ledger["dominantGlobalMassContribution"] != "open-far-field":
        raise SystemExit(f"{limiter_path} changed dominant mass source")
    if ledger["dominantControlVolumeMomentumContribution"] != "sponge":
        raise SystemExit(f"{limiter_path} changed dominant momentum source")
    ledger_samples = ledger["samples"]
    if len(ledger_samples) != decision[
        "stationaryWallC16ConservationLedgerSamples"
    ]:
        raise SystemExit(f"{limiter_path} has changed ledger history length")
    if [sample["step"] for sample in ledger_samples] != list(range(1, 501)):
        raise SystemExit(f"{limiter_path} ledger history is not contiguous")
    if sum(sample["activatedCellCount"] for sample in ledger_samples) != (
        limiter_treatment["limiterActivationCellSteps"]
    ):
        raise SystemExit(f"{limiter_path} ledger activation sum changed")
    if sum(sample["activatedCellCount"] > 0 for sample in ledger_samples) != (
        limiter_treatment["limiterActivationSteps"]
    ):
        raise SystemExit(f"{limiter_path} ledger activation history changed")
    if max(sample["activatedCellCount"] for sample in ledger_samples) != (
        limiter_treatment["maximumLimiterActivationsInOneStep"]
    ):
        raise SystemExit(f"{limiter_path} ledger maximum activation changed")
    for key, decision_key in (
        ("cumulativeObservedGlobal", "stationaryWallC16ConservationObservedMassChange"),
        ("cumulativeFarFieldGlobal", "stationaryWallC16ConservationFarFieldMassContribution"),
        ("cumulativeSpongeGlobal", "stationaryWallC16ConservationSpongeMassContribution"),
        ("cumulativeSymmetricLimiterGlobal", "stationaryWallC16ConservationLimiterMassContribution"),
    ):
        close(
            ledger[key]["mass"],
            decision[decision_key],
            1.0e-14,
            f"c16 ledger {key} mass",
        )
    for key, decision_key in (
        ("relativeCumulativeLimiterMassContribution", "stationaryWallC16ConservationRelativeLimiterMassContribution"),
        ("RMSControlVolumeSpongeForceNewtons", "stationaryWallC16ConservationSpongeRMSForceNewtons"),
        ("RMSControlVolumeSymmetricLimiterForceNewtons", "stationaryWallC16ConservationLimiterRMSForceNewtons"),
        ("relativeRMSUnexplainedForceResidual", "stationaryWallC16ConservationRelativeRMSUnexplainedForceResidual"),
        ("maximumPeakUnexplainedForceResidualFraction", "stationaryWallC16ConservationPeakUnexplainedForceResidualFraction"),
        ("relativeRMSBoundaryLoadClosureResidual", "stationaryWallC16BoundaryLoadRelativeRMSClosureResidual"),
    ):
        close(ledger[key], decision[decision_key], 1.0e-14, f"c16 ledger {key}")
    if ledger["maximumPerStepGlobalMassClosureResidual"] > 1.0e-5:
        raise SystemExit(f"{limiter_path} global mass ledger lost closure")
    if abs(ledger["observedMassHistoryResidual"]) > 1.0e-5:
        raise SystemExit(f"{limiter_path} observed mass history lost closure")
    if ledger["relativeCumulativeLimiterMassContribution"] > 1.0e-6:
        raise SystemExit(f"{limiter_path} limiter mass source is no longer negligible")
    if ledger["relativeRMSUnexplainedForceResidual"] > 5.0e-3:
        raise SystemExit(f"{limiter_path} force-source RMS no longer closes")
    if ledger["maximumPeakUnexplainedForceResidualFraction"] > 1.0e-2:
        raise SystemExit(f"{limiter_path} force-source peak no longer closes")
    if ledger["relativeRMSBoundaryLoadClosureResidual"] > 1.0e-6:
        raise SystemExit(f"{limiter_path} boundary load no longer closes")

    if limiter["sourceAwareControlMinimumCells"] != decision[
        "stationaryWallC16SourceAwareControlMinimumCells"
    ]:
        raise SystemExit(f"{limiter_path} changed source-aware control minimum")
    if limiter["sourceAwareControlMaximumExclusiveCells"] != decision[
        "stationaryWallC16SourceAwareControlMaximumExclusiveCells"
    ]:
        raise SystemExit(f"{limiter_path} changed source-aware control maximum")
    if limiter["sourceAwareMaximumSolidControlSurfaceCrossingLinkCount"] != decision[
        "stationaryWallC16SourceAwareMaximumSolidControlSurfaceCrossingLinkCount"
    ]:
        raise SystemExit(f"{limiter_path} changed source-aware crossing links")
    for key in (
        "sourceAwareControlVolumeOutsideSponge",
        "sourceAwareStabilityPassed",
        "sourceAwareForceBudgetPassed",
        "sourceAwareAcceptancePassed",
    ):
        if not limiter[key]:
            raise SystemExit(f"{limiter_path} lost {key}")
    source_aware = limiter["sourceAwareTreatment"]
    if source_aware["completedSteps"] != 500:
        raise SystemExit(f"{limiter_path} source-aware treatment did not finish")
    if any(
        source_aware.get(key) is not None
        for key in (
            "firstNegativePopulationStep",
            "firstNonFinitePopulationStep",
            "firstNonFiniteLoadStep",
        )
    ):
        raise SystemExit(f"{limiter_path} source-aware treatment is not finite-positive")
    if not source_aware["forceBudgetPassed"]:
        raise SystemExit(f"{limiter_path} source-aware raw force budget failed")
    if source_aware["stabilityPassed"] or source_aware["fullAcceptancePassed"]:
        raise SystemExit(f"{limiter_path} must preserve the superseded mass-drift flags")
    close(
        source_aware["maximumConservativeForceResidual"],
        decision["stationaryWallC16SourceAwareMaximumForceResidual"],
        1.0e-14,
        "c16 source-aware maximum force residual",
    )
    close(
        source_aware["conservativeRelativeRMSResidual"],
        decision["stationaryWallC16SourceAwareRelativeRMSResidual"],
        1.0e-14,
        "c16 source-aware relative RMS residual",
    )
    source_aware_ledger = limiter["sourceAwareTreatmentConservationLedger"]
    if not source_aware_ledger["globalLedgerClosed"]:
        raise SystemExit(f"{limiter_path} source-aware global ledger failed")
    if any(
        sample["controlVolumeSpongeCellCount"] != 0
        for sample in source_aware_ledger["samples"]
    ):
        raise SystemExit(f"{limiter_path} source-aware control contains sponge cells")
    close(
        source_aware_ledger["RMSControlVolumeSpongeForceNewtons"],
        decision["stationaryWallC16SourceAwareSpongeRMSForceNewtons"],
        1.0e-14,
        "c16 source-aware sponge RMS force",
    )
    close(
        source_aware_ledger["relativeRMSBoundaryLoadClosureResidual"],
        decision["stationaryWallC16SourceAwareBoundaryLoadRelativeRMSClosureResidual"],
        1.0e-14,
        "c16 source-aware boundary load closure",
    )

    geometric_path = Path(
        decision["stationaryWallGeometricLimiterLadderArtifact"]
    )
    geometric_bytes = geometric_path.read_bytes()
    geometric_hash = hashlib.sha256(geometric_bytes).hexdigest()
    if geometric_hash != decision[
        "stationaryWallGeometricLimiterLadderArtifactSHA256"
    ]:
        raise SystemExit(f"{geometric_path} has changed artifact hash")
    geometric = json.loads(geometric_bytes)
    if geometric["schemaVersion"] != 1:
        raise SystemExit(f"{geometric_path} has changed schema")
    if geometric["classification"] != (
        "stationary-wall-geometric-limiter-ladder-not-accepted"
    ):
        raise SystemExit(f"{geometric_path} has changed classification")
    if geometric["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{geometric_path} no longer uses production Metal")
    if geometric["passed"]:
        raise SystemExit(f"{geometric_path} must retain its blocked promotion")
    if geometric["limiterActivationNonIncreasing"]:
        raise SystemExit(f"{geometric_path} activation trend unexpectedly passes")
    if geometric["limiterCorrectionNonIncreasing"]:
        raise SystemExit(f"{geometric_path} correction trend unexpectedly passes")
    for key in (
        "observedDragConvergenceOrder",
        "richardsonExtrapolatedDragCoefficient",
        "fineGridConvergenceIndex",
    ):
        if geometric.get(key) is not None:
            raise SystemExit(f"{geometric_path} must not report {key} for non-monotonic drag")
    for key, expected in (
        ("domainLengthDiameters", 10.0),
        ("domainCrossflowDiameters", 6.0),
        ("sphereCenterFromInletDiameters", 3.0),
        ("spongeWidthDiameters", 0.5),
        ("requestedConvectiveTimes", 5.0),
        ("reynoldsNumber", 9367.4),
        ("latticeFarFieldSpeed", 0.08),
        ("maximumAllowedLimiterActivationFraction", 0.05),
        ("maximumAllowedRelativeLimiterCorrection", 0.01),
        ("maximumAllowedRelativeRMSForceResidual", 0.005),
        ("maximumAllowedPeakForceResidualRatio", 0.001),
        ("maximumAllowedFinestTwoDragChange", 0.05),
    ):
        close(geometric[key], expected, 1.0e-14, f"geometric {key}")
    geometric_cases = geometric["cases"]
    expected_case_values = {
        "diameterCells": decision["stationaryWallGeometricLimiterDiameterCells"],
        "domainCells": decision["stationaryWallGeometricLimiterDomainCells"],
        "requestedSteps": decision["stationaryWallGeometricLimiterRequestedSteps"],
        "sourceAwareStabilityPassed": decision[
            "stationaryWallGeometricLimiterSourceAwareStabilityPassed"
        ],
        "forceBudgetPassed": decision[
            "stationaryWallGeometricLimiterForceBudgetPassed"
        ],
        "limiterNonIntrusivePassed": decision[
            "stationaryWallGeometricLimiterNonIntrusivePassed"
        ],
    }
    for key, expected in expected_case_values.items():
        if [case[key] for case in geometric_cases] != expected:
            raise SystemExit(f"{geometric_path} has changed {key}")
    for case in geometric_cases:
        if case["minimumObservedPopulation"] <= 0:
            raise SystemExit(f"{geometric_path} lost population positivity")
        if case["passed"]:
            raise SystemExit(f"{geometric_path} case unexpectedly passes")
        if not case["globalLedgerClosed"]:
            raise SystemExit(f"{geometric_path} global ledger no longer closes")
        if not case["controlVolumeOutsideSponge"]:
            raise SystemExit(f"{geometric_path} control volume entered sponge")
        if case["maximumSolidControlSurfaceCrossingLinkCount"] != 0:
            raise SystemExit(f"{geometric_path} control surface crosses solid links")
        if any(
            sample["controlVolumeSpongeCellCount"] != 0
            or sample["solidControlSurfaceCrossingLinkCount"] != 0
            for sample in case["samples"]
        ):
            raise SystemExit(f"{geometric_path} phase history lost control isolation")
        if [sample["step"] for sample in case["samples"]] != list(
            range(1, case["requestedSteps"] + 1)
        ):
            raise SystemExit(f"{geometric_path} phase history is not contiguous")
    for key, decision_key in (
        ("limiterActivationFraction", "stationaryWallGeometricLimiterActivationFractions"),
        ("controlVolumeLimiterActivationFraction", "stationaryWallGeometricLimiterControlActivationFractions"),
        ("relativeControlVolumeLimiterL1Correction", "stationaryWallGeometricLimiterControlRelativeL1Corrections"),
        ("relativeControlVolumeLimiterL2Correction", "stationaryWallGeometricLimiterControlRelativeL2Corrections"),
        ("meanDragCoefficientLastConvectiveTime", "stationaryWallGeometricLimiterMeanDragCoefficients"),
    ):
        for actual, expected in zip(
            [case[key] for case in geometric_cases], decision[decision_key]
        ):
            close(actual, expected, 1.0e-14, f"geometric {key}")
    close(
        geometric["relativeFinestTwoDragChange"],
        decision["stationaryWallGeometricLimiterRelativeFinestTwoDragChange"],
        1.0e-14,
        "geometric finest-two drag change",
    )
    if decision["stationaryWallGeometricLimiterObservedDragConvergenceOrder"] is not None:
        raise SystemExit("geometric audit must retain null observed order")
    for path_key, hash_key in (
        ("stationaryWallGeometricLimiterLadderFigurePNG", "stationaryWallGeometricLimiterLadderFigurePNGSHA256"),
        ("stationaryWallGeometricLimiterLadderFigureSVG", "stationaryWallGeometricLimiterLadderFigureSVGSHA256"),
    ):
        figure_path = Path(decision[path_key])
        if hashlib.sha256(figure_path.read_bytes()).hexdigest() != decision[hash_key]:
            raise SystemExit(f"{figure_path} has changed figure hash")

    radial_path = Path(
        decision["stationaryWallC16RadialLimiterLocalizationArtifact"]
    )
    radial_bytes = radial_path.read_bytes()
    if hashlib.sha256(radial_bytes).hexdigest() != decision[
        "stationaryWallC16RadialLimiterLocalizationArtifactSHA256"
    ]:
        raise SystemExit(f"{radial_path} has changed artifact hash")
    radial = json.loads(radial_bytes)
    if radial["schemaVersion"] != 1:
        raise SystemExit(f"{radial_path} has changed schema")
    if radial["classification"] != decision[
        "stationaryWallC16RadialLimiterLocalizationClassification"
    ]:
        raise SystemExit(f"{radial_path} has changed classification")
    if radial["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{radial_path} no longer uses production Metal")
    if radial["radialReductionKernel"] != "reduceSymmetricLimiterRadialBins":
        raise SystemExit(f"{radial_path} has changed radial reduction")
    if radial["diameterCells"] != 16 or radial["domainCells"] != [160, 96, 96]:
        raise SystemExit(f"{radial_path} has changed geometry")
    if radial["requestedSteps"] != 1000:
        raise SystemExit(f"{radial_path} has changed horizon")
    if radial["firstLimiterActivationStep"] != decision[
        "stationaryWallC16RadialLimiterFirstActivationStep"
    ]:
        raise SystemExit(f"{radial_path} has changed first activation")
    if radial["captureSteps"] != decision[
        "stationaryWallC16RadialLimiterCaptureSteps"
    ]:
        raise SystemExit(f"{radial_path} has changed capture steps")
    if not all(
        radial[key]
        for key in (
            "populationPositivityPassed",
            "controlVolumeIsolationPassed",
            "radialClosurePassed",
            "passed",
        )
    ):
        raise SystemExit(f"{radial_path} lost a diagnostic acceptance gate")
    if radial["boundaryLocalized"]:
        raise SystemExit(f"{radial_path} must retain bulk-flow spread")
    close(
        radial["maximumObservedRadialClosureResidual"],
        decision["stationaryWallC16RadialLimiterMaximumClosureResidual"],
        1.0e-14,
        "radial maximum closure residual",
    )
    if radial["maximumObservedRadialClosureResidual"] > radial[
        "maximumAllowedRadialClosureResidual"
    ]:
        raise SystemExit(f"{radial_path} no longer closes")
    for key, decision_key in (
        ("finalNearSurfaceLimiterL1Fraction", "stationaryWallC16RadialLimiterFinalNearSurfaceL1Fraction"),
        ("finalFarFieldLimiterL1Fraction", "stationaryWallC16RadialLimiterFinalFarFieldL1Fraction"),
        ("finalNearSurfaceActivationFraction", "stationaryWallC16RadialLimiterFinalNearSurfaceActivationFraction"),
        ("finalFarFieldActivationFraction", "stationaryWallC16RadialLimiterFinalFarFieldActivationFraction"),
    ):
        close(radial[key], decision[decision_key], 1.0e-14, f"radial {key}")
    radial_snapshots = radial["snapshots"]
    if [snapshot["step"] for snapshot in radial_snapshots] != radial["captureSteps"]:
        raise SystemExit(f"{radial_path} has non-contiguous captures")
    for snapshot in radial_snapshots:
        bins = snapshot["bins"]
        if [bin_["binIndex"] for bin_ in bins] != list(range(8)):
            raise SystemExit(f"{radial_path} has changed radial bins")
        if snapshot["controlVolumeActivatedCellCount"] != snapshot[
            "radialActivatedCellCount"
        ]:
            raise SystemExit(f"{radial_path} activation bins do not close")
        close(
            sum(bin_["fractionOfSnapshotLimiterL1Correction"] for bin_ in bins),
            1.0,
            1.0e-12,
            "radial limiter L1 allocation",
        )
        close(
            sum(bin_["fractionOfSnapshotActivatedCells"] for bin_ in bins),
            1.0,
            1.0e-12,
            "radial activation allocation",
        )
    if [bin_["boundaryLinkCount"] for bin_ in radial_snapshots[-1]["bins"]] != [
        4416, 288, 0, 0, 0, 0, 0, 0,
    ]:
        raise SystemExit(f"{radial_path} changed boundary-shell placement")
    for path_key, hash_key in (
        ("stationaryWallC16RadialLimiterLocalizationFigurePNG", "stationaryWallC16RadialLimiterLocalizationFigurePNGSHA256"),
        ("stationaryWallC16RadialLimiterLocalizationFigureSVG", "stationaryWallC16RadialLimiterLocalizationFigureSVGSHA256"),
    ):
        figure_path = Path(decision[path_key])
        if hashlib.sha256(figure_path.read_bytes()).hexdigest() != decision[hash_key]:
            raise SystemExit(f"{figure_path} has changed figure hash")

    collision_ab_path = Path(
        decision["stationaryWallC16BulkCollisionABArtifact"]
    )
    collision_ab_bytes = collision_ab_path.read_bytes()
    if hashlib.sha256(collision_ab_bytes).hexdigest() != decision[
        "stationaryWallC16BulkCollisionABArtifactSHA256"
    ]:
        raise SystemExit(f"{collision_ab_path} has changed artifact hash")
    collision_ab = json.loads(collision_ab_bytes)
    if collision_ab["schemaVersion"] != 1:
        raise SystemExit(f"{collision_ab_path} has changed schema")
    if collision_ab["classification"] != decision[
        "stationaryWallC16BulkCollisionABClassification"
    ]:
        raise SystemExit(f"{collision_ab_path} has changed classification")
    if not collision_ab["diagnosticCompleted"] or not collision_ab["passed"]:
        raise SystemExit(f"{collision_ab_path} did not complete")
    if collision_ab["candidateEligibleForRefinement"]:
        raise SystemExit(f"{collision_ab_path} candidate cannot be promoted")
    if not collision_ab["gridConvergenceStillRequired"]:
        raise SystemExit(f"{collision_ab_path} hides the required grid ladder")
    if collision_ab["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{collision_ab_path} no longer uses production Metal")
    if collision_ab["ledgerCaptureKernel"] != "captureSymmetricLimiterLedger":
        raise SystemExit(f"{collision_ab_path} changed ledger capture")
    if collision_ab["radialReductionKernel"] != "reduceSymmetricLimiterRadialBins":
        raise SystemExit(f"{collision_ab_path} changed radial reduction")
    if collision_ab["diameterCells"] != 16 or collision_ab["domainCells"] != [160, 96, 96]:
        raise SystemExit(f"{collision_ab_path} changed geometry")
    if collision_ab["requestedSteps"] != 1000:
        raise SystemExit(f"{collision_ab_path} changed horizon")
    for key, expected in (
        ("maximumAllowedRelativeRMSForceResidual", 5.0e-3),
        ("maximumAllowedPeakForceResidualRatio", 1.0e-3),
        ("maximumAllowedCorrectionActivationFraction", 5.0e-2),
        ("maximumAllowedRelativeCorrection", 1.0e-2),
        ("maximumAllowedRadialClosureResidual", 1.0e-4),
    ):
        close(collision_ab[key], expected, 1.0e-15, f"collision A/B {key}")
    control = collision_ab["control"]
    candidate = collision_ab["candidate"]
    if control["operatorName"] != decision[
        "stationaryWallC16BulkCollisionABControlOperator"
    ]:
        raise SystemExit(f"{collision_ab_path} changed control operator")
    if candidate["operatorName"] != decision[
        "stationaryWallC16BulkCollisionABCandidateOperator"
    ]:
        raise SystemExit(f"{collision_ab_path} changed candidate operator")
    for case in (control, candidate):
        if case["completedSteps"] != 1000:
            raise SystemExit(f"{collision_ab_path} case did not complete")
        if not all(
            case[key]
            for key in (
                "populationPositivityPassed",
                "controlVolumeIsolationPassed",
                "globalLedgerClosed",
                "forceBudgetPassed",
                "radialCaptureCompleted",
            )
        ):
            raise SystemExit(f"{collision_ab_path} lost a mandatory closure gate")
        if case["maximumObservedRadialClosureResidual"] > collision_ab[
            "maximumAllowedRadialClosureResidual"
        ]:
            raise SystemExit(f"{collision_ab_path} radial ledger no longer closes")
    for case_key, field, decision_key in (
        ("control", "controlVolumeCorrectionActivationFraction", "stationaryWallC16BulkCollisionABControlActivationFraction"),
        ("candidate", "controlVolumeCorrectionActivationFraction", "stationaryWallC16BulkCollisionABCandidateActivationFraction"),
        ("control", "relativeControlVolumeCorrectionL1", "stationaryWallC16BulkCollisionABControlRelativeL1Correction"),
        ("candidate", "relativeControlVolumeCorrectionL1", "stationaryWallC16BulkCollisionABCandidateRelativeL1Correction"),
        ("control", "relativeControlVolumeCorrectionL2", "stationaryWallC16BulkCollisionABControlRelativeL2Correction"),
        ("candidate", "relativeControlVolumeCorrectionL2", "stationaryWallC16BulkCollisionABCandidateRelativeL2Correction"),
    ):
        close(
            collision_ab[case_key][field],
            decision[decision_key],
            1.0e-14,
            f"collision A/B {case_key} {field}",
        )
    if candidate["controlVolumeCorrectionActivationFraction"] > collision_ab[
        "maximumAllowedCorrectionActivationFraction"
    ]:
        raise SystemExit(f"{collision_ab_path} candidate activation regressed")
    if candidate["relativeControlVolumeCorrectionL1"] > collision_ab[
        "maximumAllowedRelativeCorrection"
    ]:
        raise SystemExit(f"{collision_ab_path} candidate L1 correction regressed")
    if candidate["relativeControlVolumeCorrectionL2"] <= collision_ab[
        "maximumAllowedRelativeCorrection"
    ]:
        raise SystemExit(f"{collision_ab_path} candidate must retain the L2 miss")
    if candidate["correctionNonIntrusivePassed"] or candidate[
        "eligibleForRefinement"
    ]:
        raise SystemExit(f"{collision_ab_path} candidate was incorrectly promoted")
    for path_key, hash_key in (
        ("stationaryWallC16BulkCollisionABFigurePNG", "stationaryWallC16BulkCollisionABFigurePNGSHA256"),
        ("stationaryWallC16BulkCollisionABFigureSVG", "stationaryWallC16BulkCollisionABFigureSVGSHA256"),
    ):
        figure_path = Path(decision[path_key])
        if hashlib.sha256(figure_path.read_bytes()).hexdigest() != decision[hash_key]:
            raise SystemExit(f"{figure_path} has changed figure hash")

    recursive_ab_path = Path(
        decision["stationaryWallC16RecursiveRegularizationABArtifact"]
    )
    recursive_ab_bytes = recursive_ab_path.read_bytes()
    if hashlib.sha256(recursive_ab_bytes).hexdigest() != decision[
        "stationaryWallC16RecursiveRegularizationABArtifactSHA256"
    ]:
        raise SystemExit(f"{recursive_ab_path} has changed artifact hash")
    recursive_ab = json.loads(recursive_ab_bytes)
    if recursive_ab["schemaVersion"] != 1:
        raise SystemExit(f"{recursive_ab_path} has changed schema")
    if recursive_ab["classification"] != decision[
        "stationaryWallC16RecursiveRegularizationABClassification"
    ]:
        raise SystemExit(f"{recursive_ab_path} has changed classification")
    if not recursive_ab["diagnosticCompleted"] or not recursive_ab["passed"]:
        raise SystemExit(f"{recursive_ab_path} did not complete")
    if not recursive_ab["candidateEligibleForRefinement"]:
        raise SystemExit(f"{recursive_ab_path} candidate lost promotion eligibility")
    if not recursive_ab["gridConvergenceStillRequired"]:
        raise SystemExit(f"{recursive_ab_path} hides the required grid ladder")
    if recursive_ab["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{recursive_ab_path} no longer uses production Metal")
    if recursive_ab["ledgerCaptureKernel"] != "captureSymmetricLimiterLedger":
        raise SystemExit(f"{recursive_ab_path} changed ledger capture")
    if recursive_ab["radialReductionKernel"] != "reduceSymmetricLimiterRadialBins":
        raise SystemExit(f"{recursive_ab_path} changed radial reduction")
    if recursive_ab["diameterCells"] != 16 or recursive_ab["domainCells"] != [
        160,
        96,
        96,
    ]:
        raise SystemExit(f"{recursive_ab_path} changed geometry")
    if recursive_ab["requestedSteps"] != 1000:
        raise SystemExit(f"{recursive_ab_path} changed horizon")
    for key, expected in (
        ("maximumAllowedRelativeRMSForceResidual", 5.0e-3),
        ("maximumAllowedPeakForceResidualRatio", 1.0e-3),
        ("maximumAllowedCorrectionActivationFraction", 5.0e-2),
        ("maximumAllowedRelativeCorrection", 1.0e-2),
        ("maximumAllowedRadialClosureResidual", 1.0e-4),
    ):
        close(recursive_ab[key], expected, 1.0e-15, f"recursive A/B {key}")
    recursive_control = recursive_ab["control"]
    recursive_candidate = recursive_ab["candidate"]
    if recursive_control["operatorName"] != decision[
        "stationaryWallC16RecursiveRegularizationControlOperator"
    ]:
        raise SystemExit(f"{recursive_ab_path} changed control operator")
    if recursive_candidate["operatorName"] != decision[
        "stationaryWallC16RecursiveRegularizationCandidateOperator"
    ]:
        raise SystemExit(f"{recursive_ab_path} changed candidate operator")
    for case in (recursive_control, recursive_candidate):
        if case["completedSteps"] != 1000:
            raise SystemExit(f"{recursive_ab_path} case did not complete")
        if not all(
            case[key]
            for key in (
                "populationPositivityPassed",
                "controlVolumeIsolationPassed",
                "globalLedgerClosed",
                "forceBudgetPassed",
                "radialCaptureCompleted",
            )
        ):
            raise SystemExit(f"{recursive_ab_path} lost a mandatory closure gate")
    for case_key, field, decision_key in (
        ("control", "controlVolumeCorrectionActivationFraction", "stationaryWallC16RecursiveRegularizationControlActivationFraction"),
        ("candidate", "controlVolumeCorrectionActivationFraction", "stationaryWallC16RecursiveRegularizationCandidateActivationFraction"),
        ("control", "relativeControlVolumeCorrectionL1", "stationaryWallC16RecursiveRegularizationControlRelativeL1Correction"),
        ("candidate", "relativeControlVolumeCorrectionL1", "stationaryWallC16RecursiveRegularizationCandidateRelativeL1Correction"),
        ("control", "relativeControlVolumeCorrectionL2", "stationaryWallC16RecursiveRegularizationControlRelativeL2Correction"),
        ("candidate", "relativeControlVolumeCorrectionL2", "stationaryWallC16RecursiveRegularizationCandidateRelativeL2Correction"),
    ):
        close(
            recursive_ab[case_key][field],
            decision[decision_key],
            1.0e-14,
            f"recursive A/B {case_key} {field}",
        )
    if recursive_candidate["controlVolumeCorrectionActivationFraction"] > recursive_ab[
        "maximumAllowedCorrectionActivationFraction"
    ]:
        raise SystemExit(f"{recursive_ab_path} candidate activation regressed")
    if recursive_candidate["relativeControlVolumeCorrectionL1"] > recursive_ab[
        "maximumAllowedRelativeCorrection"
    ]:
        raise SystemExit(f"{recursive_ab_path} candidate L1 correction regressed")
    if recursive_candidate["relativeControlVolumeCorrectionL2"] > recursive_ab[
        "maximumAllowedRelativeCorrection"
    ]:
        raise SystemExit(f"{recursive_ab_path} candidate L2 correction regressed")
    if not recursive_candidate["correctionNonIntrusivePassed"] or not recursive_candidate[
        "eligibleForRefinement"
    ]:
        raise SystemExit(f"{recursive_ab_path} candidate lost eligibility")
    for path_key, hash_key in (
        ("stationaryWallC16RecursiveRegularizationFigurePNG", "stationaryWallC16RecursiveRegularizationFigurePNGSHA256"),
        ("stationaryWallC16RecursiveRegularizationFigureSVG", "stationaryWallC16RecursiveRegularizationFigureSVGSHA256"),
    ):
        figure_path = Path(decision[path_key])
        if hashlib.sha256(figure_path.read_bytes()).hexdigest() != decision[hash_key]:
            raise SystemExit(f"{figure_path} has changed figure hash")

    recursive_ladder_path = Path(
        decision["stationaryWallRecursiveRegularizationLadderArtifact"]
    )
    recursive_ladder_bytes = recursive_ladder_path.read_bytes()
    if hashlib.sha256(recursive_ladder_bytes).hexdigest() != decision[
        "stationaryWallRecursiveRegularizationLadderArtifactSHA256"
    ]:
        raise SystemExit(f"{recursive_ladder_path} has changed artifact hash")
    recursive_ladder = json.loads(recursive_ladder_bytes)
    if recursive_ladder["schemaVersion"] != 1:
        raise SystemExit(f"{recursive_ladder_path} has changed schema")
    if recursive_ladder["classification"] != decision[
        "stationaryWallRecursiveRegularizationLadderClassification"
    ]:
        raise SystemExit(f"{recursive_ladder_path} has changed classification")
    if recursive_ladder["limiterMode"] != decision[
        "stationaryWallRecursiveRegularizationLadderMode"
    ]:
        raise SystemExit(f"{recursive_ladder_path} has changed collision mode")
    if recursive_ladder["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{recursive_ladder_path} no longer uses production Metal")
    if recursive_ladder["passed"]:
        raise SystemExit(f"{recursive_ladder_path} must retain blocked promotion")
    if not recursive_ladder["limiterActivationNonIncreasing"]:
        raise SystemExit(f"{recursive_ladder_path} lost activation improvement")
    if not recursive_ladder["limiterCorrectionNonIncreasing"]:
        raise SystemExit(f"{recursive_ladder_path} lost correction improvement")
    for key in (
        "observedDragConvergenceOrder",
        "richardsonExtrapolatedDragCoefficient",
        "fineGridConvergenceIndex",
    ):
        if recursive_ladder.get(key) is not None:
            raise SystemExit(
                f"{recursive_ladder_path} must not report {key} for non-monotonic drag"
            )
    for key, expected in (
        ("domainLengthDiameters", 10.0),
        ("domainCrossflowDiameters", 6.0),
        ("sphereCenterFromInletDiameters", 3.0),
        ("spongeWidthDiameters", 0.5),
        ("requestedConvectiveTimes", 5.0),
        ("reynoldsNumber", 9367.4),
        ("latticeFarFieldSpeed", 0.08),
        ("maximumAllowedLimiterActivationFraction", 0.05),
        ("maximumAllowedRelativeLimiterCorrection", 0.01),
        ("maximumAllowedRelativeRMSForceResidual", 0.005),
        ("maximumAllowedPeakForceResidualRatio", 0.001),
        ("maximumAllowedFinestTwoDragChange", 0.05),
    ):
        close(recursive_ladder[key], expected, 1.0e-14, f"recursive ladder {key}")
    recursive_ladder_cases = recursive_ladder["cases"]
    recursive_expected_case_values = {
        "diameterCells": decision[
            "stationaryWallRecursiveRegularizationLadderDiameterCells"
        ],
        "domainCells": decision[
            "stationaryWallRecursiveRegularizationLadderDomainCells"
        ],
        "requestedSteps": decision[
            "stationaryWallRecursiveRegularizationLadderRequestedSteps"
        ],
        "sourceAwareStabilityPassed": decision[
            "stationaryWallRecursiveRegularizationLadderSourceAwareStabilityPassed"
        ],
        "forceBudgetPassed": decision[
            "stationaryWallRecursiveRegularizationLadderForceBudgetPassed"
        ],
        "limiterNonIntrusivePassed": decision[
            "stationaryWallRecursiveRegularizationLadderNonIntrusivePassed"
        ],
    }
    for key, expected in recursive_expected_case_values.items():
        if [case[key] for case in recursive_ladder_cases] != expected:
            raise SystemExit(f"{recursive_ladder_path} has changed {key}")
    for case in recursive_ladder_cases:
        if case["minimumObservedPopulation"] <= 0:
            raise SystemExit(f"{recursive_ladder_path} lost population positivity")
        if not case["passed"]:
            raise SystemExit(f"{recursive_ladder_path} case lost individual gates")
        if not case["globalLedgerClosed"]:
            raise SystemExit(f"{recursive_ladder_path} global ledger no longer closes")
        if not case["controlVolumeOutsideSponge"]:
            raise SystemExit(f"{recursive_ladder_path} control volume entered sponge")
        if case["maximumSolidControlSurfaceCrossingLinkCount"] != 0:
            raise SystemExit(
                f"{recursive_ladder_path} control surface crosses solid links"
            )
        if any(
            sample["controlVolumeSpongeCellCount"] != 0
            or sample["solidControlSurfaceCrossingLinkCount"] != 0
            for sample in case["samples"]
        ):
            raise SystemExit(
                f"{recursive_ladder_path} phase history lost control isolation"
            )
        if [sample["step"] for sample in case["samples"]] != list(
            range(1, case["requestedSteps"] + 1)
        ):
            raise SystemExit(
                f"{recursive_ladder_path} phase history is not contiguous"
            )
    for key, decision_key in (
        ("controlVolumeLimiterActivationFraction", "stationaryWallRecursiveRegularizationLadderControlActivationFractions"),
        ("relativeControlVolumeLimiterL1Correction", "stationaryWallRecursiveRegularizationLadderControlRelativeL1Corrections"),
        ("relativeControlVolumeLimiterL2Correction", "stationaryWallRecursiveRegularizationLadderControlRelativeL2Corrections"),
        ("meanDragCoefficientLastConvectiveTime", "stationaryWallRecursiveRegularizationLadderMeanDragCoefficients"),
    ):
        for actual, expected in zip(
            [case[key] for case in recursive_ladder_cases],
            decision[decision_key],
        ):
            close(actual, expected, 1.0e-14, f"recursive ladder {key}")
    close(
        recursive_ladder["relativeFinestTwoDragChange"],
        decision[
            "stationaryWallRecursiveRegularizationLadderRelativeFinestTwoDragChange"
        ],
        1.0e-14,
        "recursive ladder finest-two drag change",
    )
    if recursive_ladder["relativeFinestTwoDragChange"] <= recursive_ladder[
        "maximumAllowedFinestTwoDragChange"
    ]:
        raise SystemExit(f"{recursive_ladder_path} must retain force failure")
    for case_index, case in enumerate(recursive_ladder_cases):
        window_means = []
        for window_index in range(5):
            values = [
                sample["dragCoefficient"]
                for sample in case["samples"]
                if window_index < sample["convectiveTime"] <= window_index + 1
            ]
            if not values:
                raise SystemExit(
                    f"{recursive_ladder_path} lost convective window {window_index + 1}"
                )
            window_means.append(sum(values) / len(values))
        for actual, expected in zip(
            window_means,
            decision[
                "stationaryWallRecursiveRegularizationLadderConvectiveWindowMeanDragCoefficients"
            ][case_index],
        ):
            close(actual, expected, 1.0e-14, "recursive ladder window mean")
        fourth_to_fifth = abs(window_means[4] - window_means[3]) / max(
            abs(window_means[4]), 1.0e-30
        )
        close(
            fourth_to_fifth,
            decision[
                "stationaryWallRecursiveRegularizationLadderFourthToFifthRelativeDragChanges"
            ][case_index],
            1.0e-14,
            "recursive ladder duration sensitivity",
        )
    for path_key, hash_key in (
        ("stationaryWallRecursiveRegularizationLadderFigurePNG", "stationaryWallRecursiveRegularizationLadderFigurePNGSHA256"),
        ("stationaryWallRecursiveRegularizationLadderFigureSVG", "stationaryWallRecursiveRegularizationLadderFigureSVGSHA256"),
    ):
        figure_path = Path(decision[path_key])
        if hashlib.sha256(figure_path.read_bytes()).hexdigest() != decision[hash_key]:
            raise SystemExit(f"{figure_path} has changed figure hash")

    duration_path = Path(
        decision["stationaryWallRecursiveRegularizationDurationArtifact"]
    )
    duration_bytes = duration_path.read_bytes()
    if hashlib.sha256(duration_bytes).hexdigest() != decision[
        "stationaryWallRecursiveRegularizationDurationArtifactSHA256"
    ]:
        raise SystemExit(f"{duration_path} has changed artifact hash")
    duration = json.loads(duration_bytes)
    if duration["schemaVersion"] != 1:
        raise SystemExit(f"{duration_path} has changed schema")
    if duration["classification"] != decision[
        "stationaryWallRecursiveRegularizationDurationClassification"
    ]:
        raise SystemExit(f"{duration_path} has changed classification")
    if duration["productionKernel"] != "stepFluidTRT":
        raise SystemExit(f"{duration_path} no longer uses production Metal")
    if duration["collisionMode"] != recursive_ladder["limiterMode"]:
        raise SystemExit(f"{duration_path} has changed collision mode")
    for key, expected in (
        ("baselineConvectiveTimes", 5.0),
        ("requestedConvectiveTimes", 10.0),
        ("maximumAllowedLateWindowChange", 0.05),
    ):
        close(duration[key], expected, 1.0e-14, f"duration {key}")
    if not duration["diagnosticCompleted"] or not duration["passed"]:
        raise SystemExit(f"{duration_path} did not complete")
    if not duration["allIndividualGatesPassed"]:
        raise SystemExit(f"{duration_path} lost an individual numerical gate")
    if duration["durationStabilityPassed"]:
        raise SystemExit(f"{duration_path} must retain unresolved D=8 duration")
    if duration["baselineWindowBiasConfirmed"]:
        raise SystemExit(
            f"{duration_path} must not claim bias before both cases are stable"
        )
    duration_cases = duration["cases"]
    numerical_cases = [item["numericalCase"] for item in duration_cases]
    if [case["diameterCells"] for case in numerical_cases] != decision[
        "stationaryWallRecursiveRegularizationDurationDiameterCells"
    ]:
        raise SystemExit(f"{duration_path} has changed diameters")
    if [case["requestedSteps"] for case in numerical_cases] != decision[
        "stationaryWallRecursiveRegularizationDurationRequestedSteps"
    ]:
        raise SystemExit(f"{duration_path} has changed durations")
    if [item["durationStabilityPassed"] for item in duration_cases] != decision[
        "stationaryWallRecursiveRegularizationDurationCaseStabilityPassed"
    ]:
        raise SystemExit(f"{duration_path} has changed per-case stability")
    for case_index, item in enumerate(duration_cases):
        case = item["numericalCase"]
        if case["minimumObservedPopulation"] <= 0:
            raise SystemExit(f"{duration_path} lost population positivity")
        if not all(
            case[key]
            for key in (
                "sourceAwareStabilityPassed",
                "forceBudgetPassed",
                "limiterNonIntrusivePassed",
                "globalLedgerClosed",
                "controlVolumeOutsideSponge",
                "passed",
            )
        ):
            raise SystemExit(f"{duration_path} lost a numerical gate")
        if case["maximumSolidControlSurfaceCrossingLinkCount"] != 0:
            raise SystemExit(f"{duration_path} control surface crosses solid links")
        if [sample["step"] for sample in case["samples"]] != list(
            range(1, case["requestedSteps"] + 1)
        ):
            raise SystemExit(f"{duration_path} phase history is not contiguous")
        window_means = []
        for window_index in range(10):
            values = [
                sample["dragCoefficient"]
                for sample in case["samples"]
                if window_index < sample["convectiveTime"] <= window_index + 1
            ]
            if not values:
                raise SystemExit(
                    f"{duration_path} lost convective window {window_index + 1}"
                )
            window_means.append(sum(values) / len(values))
        expected_windows = decision[
            "stationaryWallRecursiveRegularizationDurationConvectiveWindowMeanDragCoefficients"
        ][case_index]
        for actual, embedded, expected in zip(
            window_means,
            item["convectiveWindowMeanDragCoefficients"],
            expected_windows,
        ):
            close(actual, embedded, 1.0e-14, "duration embedded window mean")
            close(actual, expected, 1.0e-14, "duration locked window mean")
        derived_changes = (
            abs(window_means[4] - window_means[3])
            / max(abs(window_means[4]), 1.0e-30),
            abs(window_means[9] - window_means[8])
            / max(abs(window_means[9]), 1.0e-30),
            abs(window_means[9] - window_means[4])
            / max(abs(window_means[9]), 1.0e-30),
        )
        change_fields = (
            "fourthToFifthRelativeDragChange",
            "ninthToTenthRelativeDragChange",
            "fifthToTenthRelativeDragChange",
        )
        decision_fields = (
            "stationaryWallRecursiveRegularizationDurationFourthToFifthRelativeDragChanges",
            "stationaryWallRecursiveRegularizationDurationNinthToTenthRelativeDragChanges",
            "stationaryWallRecursiveRegularizationDurationFifthToTenthRelativeDragChanges",
        )
        for actual, item_field, decision_field in zip(
            derived_changes, change_fields, decision_fields
        ):
            close(actual, item[item_field], 1.0e-14, f"duration {item_field}")
            close(
                actual,
                decision[decision_field][case_index],
                1.0e-14,
                f"duration locked {item_field}",
            )
    for path_key, hash_key in (
        (
            "stationaryWallRecursiveRegularizationDurationFigurePNG",
            "stationaryWallRecursiveRegularizationDurationFigurePNGSHA256",
        ),
        (
            "stationaryWallRecursiveRegularizationDurationFigureSVG",
            "stationaryWallRecursiveRegularizationDurationFigureSVGSHA256",
        ),
    ):
        figure_path = Path(decision[path_key])
        if hashlib.sha256(figure_path.read_bytes()).hexdigest() != decision[hash_key]:
            raise SystemExit(f"{figure_path} has changed figure hash")

    print(f"audit: {arguments.audit}")
    print(f"reference_speed_mps: {speed:.12f}")
    print(f"rounded_input_reynolds: {reynolds:.9f}")
    print(f"published_reynolds: {published['targetReynoldsNumber']:.4f}")
    print(f"reynolds_closure_gap_percent: {100.0 * reynolds_gap:.6f}")
    print(f"force_coefficient_denominator_N: {denominator:.12f}")
    for feasibility in feasibilities:
        chord_cells = feasibility["numericalSetup"]["chordCells"]
        failure_step = feasibility["stabilityGate"][
            "firstNonFiniteLoadStep"
        ]
        print(
            f"c{chord_cells}_first_non_finite_load_step: {failure_step}"
        )
    print(f"fixed_wall_classification: {fixed_wall['classification']}")
    print(
        "fixed_wall_maximum_mass_drift: "
        f"{max(case['relativePopulationMassDrift'] for case in fixed_wall_cases):.12g}"
    )
    print(
        "translating_body_first_non_finite_steps: "
        + ",".join(
            str(case["firstNonFiniteLoadStep"])
            for case in translating_cases
        )
    )
    print(f"translating_body_classification: {translating['classification']}")
    print(
        "fixed_occupancy_sphere_first_non_finite_steps: "
        + ",".join(
            str(case["firstNonFiniteLoadStep"])
            for case in fixed_sphere_cases
        )
    )
    print(
        "fixed_occupancy_sphere_classification: "
        f"{fixed_sphere['classification']}"
    )
    print(
        "wall_component_first_non_finite_steps: "
        + ";".join(
            f"{mode}="
            + ",".join(str(step) for step in expected_component_steps[mode])
            for mode in ("normal-only", "tangential-only")
        )
    )
    print(f"wall_decomposition_classification: {decomposition['classification']}")
    print(f"stationary_wall_classification: {stationary['classification']}")
    print(
        "stationary_wall_first_non_finite_steps: "
        + ",".join(
            str(case["firstNonFiniteLoadStep"])
            for case in stationary_cases
        )
    )
    print(f"relaxation_sweep_classification: {sweep['classification']}")
    print(
        "relaxation_sweep_stability_pattern: "
        + ",".join("stable" if value else "unstable" for value in expected_stability)
    )
    print(f"long_horizon_classification: {long_horizon['classification']}")
    print(
        "long_horizon_first_non_finite_steps: "
        + ",".join(str(step) for step in long_horizon_failure_steps)
    )
    print(f"population_positivity_classification: {positivity['classification']}")
    print(
        "population_first_negative: "
        f"step={negative['step']},q={negative['directionIndex']},"
        f"cell={negative['cell']},path={negative['populationUpdatePath']}"
    )
    print(
        "population_first_non_finite: "
        f"step={non_finite['step']},q={non_finite['directionIndex']},"
        f"cell={non_finite['cell']}"
    )
    print(f"trt_decomposition_classification: {trt['classification']}")
    print(
        "trt_failing_direction: "
        f"q={failing_trt['directionIndex']},"
        f"symmetric={failing_trt['symmetricRelaxationIncrement']},"
        f"antisymmetric={failing_trt['antisymmetricRelaxationIncrement']},"
        f"post={failing_trt['actualPostCollision']}"
    )
    print(f"symmetric_limiter_classification: {limiter['classification']}")
    print(
        "symmetric_limiter_treatment: "
        f"first_negative={limiter_treatment.get('firstNegativePopulationStep')},"
        f"activations={limiter_treatment['limiterActivationCellSteps']},"
        f"minimum_scale={limiter_treatment['minimumLimiterScale']},"
        f"budget_passed={limiter_treatment['forceBudgetPassed']}"
    )
    print(
        "symmetric_limiter_conservation_ledger: "
        f"global_closed={ledger['globalLedgerClosed']},"
        f"force_source_closed={ledger['forceResidualLedgerClosed']},"
        f"mass_source={ledger['dominantGlobalMassContribution']},"
        f"momentum_source={ledger['dominantControlVolumeMomentumContribution']}"
    )
    print(f"geometric_limiter_classification: {geometric['classification']}")
    print(
        "geometric_limiter_control_activation_percent: "
        + ",".join(
            f"{100.0 * case['controlVolumeLimiterActivationFraction']:.6f}"
            for case in geometric_cases
        )
    )
    print(
        "geometric_limiter_finest_drag_change_percent: "
        f"{100.0 * geometric['relativeFinestTwoDragChange']:.6f}"
    )
    print(f"radial_limiter_classification: {radial['classification']}")
    print(
        "radial_limiter_final_near_far_percent: "
        f"{100.0 * radial['finalNearSurfaceLimiterL1Fraction']:.6f},"
        f"{100.0 * radial['finalFarFieldLimiterL1Fraction']:.6f}"
    )
    print(f"bulk_collision_ab_classification: {collision_ab['classification']}")
    print(
        "bulk_collision_ab_control_candidate_activation_percent: "
        f"{100.0 * control['controlVolumeCorrectionActivationFraction']:.6f},"
        f"{100.0 * candidate['controlVolumeCorrectionActivationFraction']:.6f}"
    )
    print(
        "bulk_collision_ab_candidate_l1_l2_percent: "
        f"{100.0 * candidate['relativeControlVolumeCorrectionL1']:.6f},"
        f"{100.0 * candidate['relativeControlVolumeCorrectionL2']:.6f}"
    )
    print(
        "recursive_regularization_ab_classification: "
        f"{recursive_ab['classification']}"
    )
    print(
        "recursive_regularization_control_candidate_activation_percent: "
        f"{100.0 * recursive_control['controlVolumeCorrectionActivationFraction']:.6f},"
        f"{100.0 * recursive_candidate['controlVolumeCorrectionActivationFraction']:.6f}"
    )
    print(
        "recursive_regularization_candidate_l1_l2_percent: "
        f"{100.0 * recursive_candidate['relativeControlVolumeCorrectionL1']:.6f},"
        f"{100.0 * recursive_candidate['relativeControlVolumeCorrectionL2']:.6f}"
    )
    print(
        "recursive_regularization_ladder_classification: "
        f"{recursive_ladder['classification']}"
    )
    print(
        "recursive_regularization_ladder_drag_coefficients: "
        + ",".join(
            f"{case['meanDragCoefficientLastConvectiveTime']:.9f}"
            for case in recursive_ladder_cases
        )
    )
    print(
        "recursive_regularization_ladder_finest_drag_change_percent: "
        f"{100.0 * recursive_ladder['relativeFinestTwoDragChange']:.6f}"
    )
    print(
        "recursive_regularization_ladder_fourth_to_fifth_change_percent: "
        + ",".join(
            f"{100.0 * value:.6f}"
            for value in decision[
                "stationaryWallRecursiveRegularizationLadderFourthToFifthRelativeDragChanges"
            ]
        )
    )
    print(
        "recursive_regularization_duration_classification: "
        f"{duration['classification']}"
    )
    print(
        "recursive_regularization_duration_ninth_to_tenth_change_percent: "
        + ",".join(
            f"{100.0 * item['ninthToTenthRelativeDragChange']:.6f}"
            for item in duration_cases
        )
    )
    print(
        "recursive_regularization_duration_fifth_to_tenth_change_percent: "
        + ",".join(
            f"{100.0 * item['fifthToTenthRelativeDragChange']:.6f}"
            for item in duration_cases
        )
    )
    print("passed: true")


if __name__ == "__main__":
    main()

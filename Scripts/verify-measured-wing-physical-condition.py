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
    if decision["stationaryWallRelaxationStabilityMonotonic"]:
        raise SystemExit("stationary-wall relaxation stability must remain non-monotonic")
    if decision["stationaryWallRelaxationThresholdBracketed"]:
        raise SystemExit("non-monotonic sweep must not claim a robust threshold")
    if decision["viscosityOnlyStabilizationIsRobust"]:
        raise SystemExit("viscosity-only stabilization must remain non-robust")
    if not decision["stationaryWallLongHorizonSurvivalCompleted"]:
        raise SystemExit("stationary-wall long-horizon audit must remain complete")
    if decision["stationaryWallLongHorizonAllPointsSurvived"]:
        raise SystemExit("long-horizon apparent stability must remain failed")
    if decision["stationaryWallLongHorizonFirstNonFiniteLoadSteps"] != [
        519,
        566,
        588,
    ]:
        raise SystemExit("long-horizon failure steps have changed")
    if not decision["stationaryWallFiveHundredStepStabilityWasHorizonCensored"]:
        raise SystemExit("500-step stability must remain horizon-censored")
    if decision["apparentNonMonotonicStabilityBandIsGenuine"]:
        raise SystemExit("apparent non-monotonic stability band must remain rejected")
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
        if case["finiteLoadSteps"] != 266:
            raise SystemExit(f"{stationary_path} has changed finite history length")
        if case["firstNonFiniteLoadStep"] != 267:
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
        != "stationary-wall-relaxation-stability-nonmonotonic"
    ):
        raise SystemExit(f"{sweep_path} has changed classification")
    if sweep["stabilityMonotonicWithMargin"]:
        raise SystemExit(f"{sweep_path} must retain non-monotonic stability")
    if sweep["thresholdBracketed"]:
        raise SystemExit(f"{sweep_path} must not claim a robust threshold")
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
    if sweep["unstableTauPlusMarginsAfterFirstStable"] != [
        decision["stationaryWallUnstableMarginAfterFirstStable"]
    ]:
        raise SystemExit(f"{sweep_path} has changed its post-stable relapse")
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
    if [
        point["requestedTauPlusMarginAboveHalf"]
        for point in sweep_points
    ] != expected_requested_margins:
        raise SystemExit(f"{sweep_path} has changed requested margins")
    expected_stability = [
        False,
        False,
        False,
        False,
        False,
        False,
        False,
        False,
        True,
        False,
        True,
        True,
        True,
        True,
    ]
    expected_failure_steps = [
        267,
        268,
        273,
        280,
        324,
        451,
        472,
        488,
        None,
        496,
        None,
        None,
        None,
        None,
    ]
    if [point["stabilityPassed"] for point in sweep_points] != expected_stability:
        raise SystemExit(f"{sweep_path} has changed stability outcomes")
    if [
        point["firstNonFiniteLoadStep"] for point in sweep_points
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
        != "stationary-wall-500-step-stability-horizon-censored"
    ):
        raise SystemExit(f"{long_horizon_path} has changed classification")
    if long_horizon["survivingPointCount"] != 0:
        raise SystemExit(f"{long_horizon_path} must retain zero survivors")
    if long_horizon["allApparentStablePointsSurvived"]:
        raise SystemExit(f"{long_horizon_path} must retain failed survival")
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
    if [
        point["requestedTauPlusMarginAboveHalf"]
        for point in long_horizon_points
    ] != [0.015625, 0.016875, 0.02]:
        raise SystemExit(f"{long_horizon_path} has changed requested margins")
    long_horizon_failure_steps = [
        point["firstNonFiniteLoadStep"]
        for point in long_horizon_points
    ]
    if long_horizon_failure_steps != [519, 566, 588]:
        raise SystemExit(f"{long_horizon_path} has changed failure steps")
    for point in long_horizon_points:
        if point["finiteLoadSteps"] != point["firstNonFiniteLoadStep"] - 1:
            raise SystemExit(f"{long_horizon_path} has inconsistent finite steps")
        if point["stabilityPassed"] or point["fullAcceptancePassed"]:
            raise SystemExit(f"{long_horizon_path} contains a passing point")
        if any(
            point[key]
            for key in ("populationsFinite", "fieldsFinite", "loadsFinite")
        ):
            raise SystemExit(f"{long_horizon_path} must retain non-finite state")

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
    print("passed: true")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Independently audit the preregistered dove collision-grid workflow."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PREREGISTRATION = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-collision-grid-preregistration.json"
)
DEFAULT_DISCRIMINATOR = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-collision-grid-discriminator.json"
)
DEFAULT_COMPLETION = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-collision-grid-completion.json"
)
DEFAULT_OUTPUT = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-collision-grid-workflow-audit.json"
)
REGULARIZED = "positivity-preserving-regularized-bgk"
RECURSIVE = "positivity-preserving-recursive-regularized-bgk"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 1e-10) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def magnitude(vector: list[float]) -> float:
    return math.sqrt(sum(component * component for component in vector))


def subtract(first: list[float], second: list[float]) -> list[float]:
    return [a - b for a, b in zip(first, second, strict=True)]


def pairwise_normalized_rms(
    first: list[list[float]], second: list[list[float]]
) -> float:
    assert len(first) == len(second) and first
    numerator = sum(
        sum(value * value for value in subtract(a, b))
        for a, b in zip(first, second, strict=True)
    )
    first_energy = sum(sum(value * value for value in row) for row in first)
    second_energy = sum(sum(value * value for value in row) for row in second)
    return math.sqrt(numerator / max(0.5 * (first_energy + second_energy), 1e-30))


def mean(vectors: list[list[float]]) -> list[float]:
    return [
        sum(row[component] for row in vectors) / len(vectors)
        for component in range(3)
    ]


def impulse(vectors: list[list[float]], force_rate: float) -> list[float]:
    return [
        sum(row[component] for row in vectors) / force_rate
        for component in range(3)
    ]


def relative_difference(first: list[float], second: list[float]) -> float:
    return magnitude(subtract(first, second)) / max(
        magnitude(first), magnitude(second), 1e-30
    )


def trend(coarse: dict, fine: dict) -> dict[str, float]:
    coarse_forces = [
        sample["intervalMeanComputedForceNewtons"]
        for sample in coarse["samples"]
    ]
    fine_forces = [
        sample["intervalMeanComputedForceNewtons"]
        for sample in fine["samples"]
    ]
    if not coarse_forces or len(coarse_forces) != len(fine_forces):
        raise ValueError("force histories are unavailable or misaligned")
    history = pairwise_normalized_rms(coarse_forces, fine_forces)
    mean_difference = relative_difference(mean(coarse_forces), mean(fine_forces))
    impulse_difference = relative_difference(
        impulse(coarse_forces, coarse["plan"]["forceSamplesPerSecond"]),
        impulse(fine_forces, fine["plan"]["forceSamplesPerSecond"]),
    )
    peak = abs(
        coarse["intervalMeanPeakTimeSeconds"]
        - fine["intervalMeanPeakTimeSeconds"]
    )
    window = (
        coarse["samples"][-1]["sourceTimeSeconds"]
        - coarse["samples"][0]["sourceTimeSeconds"]
    )
    score = max(history, mean_difference, impulse_difference, peak / window)
    return {
        "intervalForceNormalizedRMSDifference": history,
        "meanForceRelativeDifference": mean_difference,
        "impulseRelativeDifference": impulse_difference,
        "peakTimeDifferenceSeconds": peak,
        "score": score,
    }


def case_eligible(case: dict, maximum_activation: float) -> bool:
    report = case["report"]
    plan = report["plan"]
    completion = (
        report["completedFluidSteps"] == plan["totalFluidSteps"]
        and report["recordedComparisonSamples"] == plan["comparisonForceSamples"]
        and report["recordedPopulationDiagnosticSamples"] == plan["totalFluidSteps"]
        and report["allComponentsPresentAtComparisonSamples"]
        and report["allLoadsFinite"]
        and report["allSampledPopulationsFinite"]
        and report["sampledPopulationPositivityPassed"]
        and report.get("firstNonFiniteLoadStep") is None
        and report.get("firstNonFinitePopulationStep") is None
        and report.get("firstNegativePopulationStep") is None
        and report["integrationGatePassed"]
    )
    correction = (
        report["collisionLimiterActivationFractionOfCellSteps"]
        <= maximum_activation
        and math.isfinite(report["maximumCollisionRestriction"])
    )
    return (
        case["completionAndPositivityGatePassed"] == completion
        and case["correctionIntrusionGatePassed"] == correction
        and case["eligibleForSelection"] == (completion and correction)
        and completion
        and correction
    )


def audit(args: argparse.Namespace) -> dict:
    preregistration = load(args.preregistration)
    discriminator = load(args.discriminator)
    completion = load(args.completion)
    checks: dict[str, bool] = {}

    checks["preregistrationSchema"] = preregistration["schemaVersion"] == 1
    checks["candidateOrder"] = preregistration["candidateOperators"] == [
        REGULARIZED,
        RECURSIVE,
    ]
    checks["allocationOrder"] = (
        preregistration["discriminatorReferenceLengthCells"] == [8, 12]
        and preregistration["completionReferenceLengthCells"] == 16
    )
    grids = preregistration["gridContracts"]
    checks["fixedPhysicalGridContract"] = len(grids) == 3 and all(
        grid["referenceLengthCells"] == cells
        and close(grid["cellSizeMeters"] * cells, 0.08, 1e-6)
        and close(
            grid["halfThicknessCells"] * grid["cellSizeMeters"], 0.0075, 1e-6
        )
        and close(grid["paddingCells"] * grid["cellSizeMeters"], 0.12, 1e-6)
        and close(
            grid["spongeWidthCells"] * grid["cellSizeMeters"], 0.06, 1e-6
        )
        and grid["fluidStepsPerForceSample"] == 2 * cells
        and grid["preRollFluidSteps"] == 100 * cells
        and grid["totalFluidSteps"] == 472 * cells
        for grid, cells in zip(grids, [8, 12, 16], strict=True)
    )
    checks["constantMach"] = all(
        close(grid["maximumWallMach"], grids[0]["maximumWallMach"], 1e-7)
        and grid["maximumWallMach"] <= 0.15
        for grid in grids
    )
    checks["constantViscosityFloor"] = all(
        close(
            grid["pilotToSourceViscosityRatio"],
            grids[0]["pilotToSourceViscosityRatio"],
        )
        for grid in grids
    )
    checks["experimentalGateDisabled"] = not preregistration[
        "experimentalAgreementGateApplied"
    ]

    evidence = {
        item["collisionOperator"]: item
        for item in preregistration["crossCanonicalEvidence"]
    }
    regularized_artifact = load(ROOT / evidence[REGULARIZED]["artifactPath"])
    recursive_artifact = load(ROOT / evidence[RECURSIVE]["artifactPath"])
    regularized_l2 = regularized_artifact["candidate"][
        "relativeControlVolumeCorrectionL2"
    ]
    recursive_l2 = recursive_artifact["candidate"][
        "relativeControlVolumeCorrectionL2"
    ]
    limit = evidence[REGULARIZED]["maximumAllowedRelativeCorrectionL2"]
    checks["crossCanonicalEvidence"] = (
        close(evidence[REGULARIZED]["relativeCorrectionL2"], regularized_l2)
        and close(evidence[RECURSIVE]["relativeCorrectionL2"], recursive_l2)
        and not evidence[REGULARIZED]["crossCanonicalGatePassed"]
        and evidence[RECURSIVE]["crossCanonicalGatePassed"]
        and regularized_l2 > limit
        and recursive_l2 <= limit
        and not regularized_artifact["candidateEligibleForRefinement"]
        and recursive_artifact["candidateEligibleForRefinement"]
    )

    checks["embeddedPreregistrationExact"] = (
        discriminator["preregistration"] == preregistration
    )
    cases = discriminator["cases"]
    case_map = {
        (case["referenceLengthCells"], case["collisionOperator"]): case
        for case in cases
    }
    checks["discriminatorMatrix"] = len(cases) == 4 and set(case_map) == {
        (8, REGULARIZED),
        (8, RECURSIVE),
        (12, REGULARIZED),
        (12, RECURSIVE),
    }
    checks["allDiscriminatorNumericalGates"] = all(
        case_eligible(
            case, preregistration["maximumCorrectionActivationFraction"]
        )
        for case in cases
    )

    metrics: dict[str, dict[str, float]] = {}
    for operator in [REGULARIZED, RECURSIVE]:
        metrics[operator] = trend(
            case_map[(8, operator)]["report"],
            case_map[(12, operator)]["report"],
        )
    best_score = min(item["score"] for item in metrics.values())
    expected_selection: list[str] = []
    assessments = {
        item["collisionOperator"]: item
        for item in discriminator["assessments"]
    }
    assessment_checks = []
    for operator in [REGULARIZED, RECURSIVE]:
        item = assessments[operator]
        measured = metrics[operator]
        penalty = max(0.0, measured["score"] / best_score - 1.0)
        cross_canonical = evidence[operator]["crossCanonicalGatePassed"]
        selectable = (
            cross_canonical
            and penalty
            <= preregistration["maximumCrossCanonicalTrendPenalty"]
        )
        if selectable:
            expected_selection.append(operator)
        assessment_checks.extend(
            [
                close(
                    item["d8ToD12IntervalForceNormalizedRMSDifference"],
                    measured["intervalForceNormalizedRMSDifference"],
                ),
                close(
                    item["d8ToD12MeanForceRelativeDifference"],
                    measured["meanForceRelativeDifference"],
                ),
                close(
                    item["d8ToD12ImpulseRelativeDifference"],
                    measured["impulseRelativeDifference"],
                ),
                close(
                    item["d8ToD12PeakTimeDifferenceSeconds"],
                    measured["peakTimeDifferenceSeconds"],
                ),
                close(item["gridTrendScore"], measured["score"]),
                close(item["crossCanonicalTrendPenalty"], penalty),
                item["crossCanonicalGatePassed"] == cross_canonical,
                item["selectionEligible"] == selectable,
            ]
        )
    checks["assessmentArithmetic"] = all(assessment_checks)
    selected = expected_selection[0] if len(expected_selection) == 1 else None
    checks["selectionRule"] = (
        selected == RECURSIVE
        and discriminator["selectedCollisionOperator"] == selected
        and discriminator["d16CompletionAuthorized"]
        and discriminator["screeningGatePassed"]
    )
    for cells, field in [
        (8, "d8OperatorPairwiseNormalizedRMSDifference"),
        (12, "d12OperatorPairwiseNormalizedRMSDifference"),
    ]:
        expected = pairwise_normalized_rms(
            [
                sample["intervalMeanComputedForceNewtons"]
                for sample in case_map[(cells, REGULARIZED)]["report"]["samples"]
            ],
            [
                sample["intervalMeanComputedForceNewtons"]
                for sample in case_map[(cells, RECURSIVE)]["report"]["samples"]
            ],
        )
        checks[f"operatorDifferenceD{cells}"] = close(discriminator[field], expected)

    d16 = completion["d16Case"]
    d16_report = d16["report"]
    checks["singleAuthorizedD16Allocation"] = (
        completion["selectedCollisionOperator"] == selected
        and d16["collisionOperator"] == selected
        and d16["referenceLengthCells"] == 16
        and all(case["referenceLengthCells"] != 16 for case in cases)
    )
    d16_eligible = case_eligible(
        d16, preregistration["maximumCorrectionActivationFraction"]
    )
    checks["negativeD16Retained"] = (
        not d16_eligible
        and not completion["completionGatePassed"]
        and not completion["fineGridForceConvergencePassed"]
        and d16_report["completedFluidSteps"] < d16_report["plan"]["totalFluidSteps"]
        and d16_report["firstNegativePopulationStep"]
        == d16_report["completedFluidSteps"]
        and d16_report.get("firstNonFinitePopulationStep") is None
        and d16_report.get("firstNonFiniteLoadStep") is None
        and d16_report["allLoadsFinite"]
        and d16_report["allSampledPopulationsFinite"]
        and not d16_report["sampledPopulationPositivityPassed"]
        and completion.get("d12ToD16IntervalForceNormalizedRMSDifference") is None
        and completion.get("d12ToD16MeanForceRelativeDifference") is None
        and completion.get("d12ToD16ImpulseRelativeDifference") is None
        and completion.get("d12ToD16PeakTimeDifferenceSeconds") is None
    )
    checks["completionExperimentalGateDisabled"] = not completion[
        "experimentalAgreementGateApplied"
    ]

    audit_passed = all(checks.values())
    return {
        "schemaVersion": 1,
        "artifactSHA256": {
            "preregistration": sha256(args.preregistration),
            "discriminator": sha256(args.discriminator),
            "completion": sha256(args.completion),
        },
        "checks": checks,
        "auditPassed": audit_passed,
        "selectedCollisionOperator": selected,
        "discriminatorMetrics": metrics,
        "d8OperatorPairwiseNormalizedRMSDifference": discriminator[
            "d8OperatorPairwiseNormalizedRMSDifference"
        ],
        "d12OperatorPairwiseNormalizedRMSDifference": discriminator[
            "d12OperatorPairwiseNormalizedRMSDifference"
        ],
        "d16Outcome": {
            "requestedSteps": d16_report["plan"]["totalFluidSteps"],
            "completedSteps": d16_report["completedFluidSteps"],
            "firstNegativePopulationStep": d16_report[
                "firstNegativePopulationStep"
            ],
            "firstNegativePopulationDirection": d16_report[
                "firstNegativePopulationDirection"
            ],
            "firstNegativePopulationCellCoordinate": d16_report[
                "firstNegativePopulationCellCoordinate"
            ],
            "firstNegativePopulationDistanceFromSurfaceCells": d16_report[
                "firstNegativePopulationDistanceFromSurfaceCells"
            ],
            "loadsFiniteAtStop": d16_report["allLoadsFinite"],
            "completionGatePassed": completion["completionGatePassed"],
            "fineGridForceConvergencePassed": completion[
                "fineGridForceConvergencePassed"
            ],
        },
        "claimBoundary": (
            "This audit reconstructs the preregistered D8/D12 selection and "
            "verifies that only RR3 reached D16. It retains the D16 positivity "
            "failure without inventing unavailable force convergence or "
            "experimental-agreement values."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--preregistration", type=Path, default=DEFAULT_PREREGISTRATION)
    parser.add_argument("--discriminator", type=Path, default=DEFAULT_DISCRIMINATOR)
    parser.add_argument("--completion", type=Path, default=DEFAULT_COMPLETION)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = audit(args)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    if not result["auditPassed"]:
        failed = [name for name, passed in result["checks"].items() if not passed]
        raise SystemExit("collision-grid audit failed: " + ", ".join(failed))
    print(
        "collision-grid audit passed: selected="
        + result["selectedCollisionOperator"]
        + " d16="
        + str(result["d16Outcome"]["completedSteps"])
        + "/"
        + str(result["d16Outcome"]["requestedSteps"])
    )


if __name__ == "__main__":
    main()

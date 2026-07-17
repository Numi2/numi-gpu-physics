#!/usr/bin/env python3
"""Freeze and evaluate the same-physics D28/D32 source-viscosity pair."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
D28_REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window.json"
D28_AUDIT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window-audit.json"
)
D32_REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d32-full-window.json"
D32_AUDIT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d32-full-window-audit.json"
)
PREREGISTRATION = (
    ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-refinement-preregistration.json"
)
REPORT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-d32-refinement.json"
)

PAIR_LIMIT = 0.05
EXPECTED_SAMPLES = 187
EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def vector(sample: dict) -> tuple[float, float]:
    force = sample["intervalMeanComputedForceNewtons"]
    return float(force[0]), float(force[2])


def magnitude(value: tuple[float, float]) -> float:
    return math.hypot(value[0], value[1])


def subtract(
    first: tuple[float, float], second: tuple[float, float]
) -> tuple[float, float]:
    return first[0] - second[0], first[1] - second[1]


def mean(values: list[tuple[float, float]]) -> tuple[float, float]:
    return (
        sum(value[0] for value in values) / len(values),
        sum(value[1] for value in values) / len(values),
    )


def relative_difference(
    first: tuple[float, float], second: tuple[float, float]
) -> float:
    return magnitude(subtract(first, second)) / max(
        magnitude(first), magnitude(second), 1.0e-30
    )


def symmetric_history_difference(
    first: list[tuple[float, float]], second: list[tuple[float, float]]
) -> float:
    numerator = sum(
        component * component
        for index in range(len(first))
        for component in subtract(first[index], second[index])
    )
    first_energy = sum(component * component for value in first for component in value)
    second_energy = sum(
        component * component for value in second for component in value
    )
    return math.sqrt(numerator / max(0.5 * (first_energy + second_energy), 1e-30))


def component_history_difference(
    first: list[tuple[float, float]],
    second: list[tuple[float, float]],
    axis: int,
) -> float:
    numerator = sum((second[i][axis] - first[i][axis]) ** 2 for i in range(len(first)))
    denominator = 0.5 * (
        sum(value[axis] ** 2 for value in first)
        + sum(value[axis] ** 2 for value in second)
    )
    return math.sqrt(numerator / max(denominator, 1.0e-30))


def impulse(
    values: list[tuple[float, float]], rate: float
) -> tuple[float, float]:
    result = [0.0, 0.0]
    for previous, current in zip(values, values[1:]):
        result[0] += 0.5 * (previous[0] + current[0]) / rate
        result[1] += 0.5 * (previous[1] + current[1]) / rate
    return result[0], result[1]


def preregister() -> None:
    d28_audit = load(D28_AUDIT)
    d32_audit = load(D32_AUDIT)
    if not (
        d28_audit["allChecksPassed"]
        and d28_audit["d28ForceHistoryAcceptedAsRefinementInput"]
        and d32_audit["allChecksPassed"]
        and d32_audit["d32ForceHistoryAcceptedAsRefinementInput"]
    ):
        raise SystemExit("both independently audited force histories are required")
    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-source-viscosity-d28-d32-refinement-preregistration-v1"
        ),
        "sourceD28ReportSHA256": sha256(D28_REPORT),
        "sourceD28AuditSHA256": sha256(D28_AUDIT),
        "sourceD32ReportSHA256": sha256(D32_REPORT),
        "sourceD32AuditSHA256": sha256(D32_AUDIT),
        "coarseReferenceLengthCells": 28,
        "fineReferenceLengthCells": 32,
        "expectedForceSamples": EXPECTED_SAMPLES,
        "maximumFinePairDifference": PAIR_LIMIT,
        "primaryMetric": "symmetric normalized RMS difference of registered X/Z interval-mean force history",
        "supportingMetrics": [
            "relative difference of X/Z mean-force vector",
            "relative difference of X/Z trapezoidal-impulse vector",
            "peak-time difference normalized by registered window duration",
        ],
        "selectionRule": (
            "Require both independently audited numerical windows, identical RR3 "
            "operator and source-condition inputs, 187 aligned bins, and each of "
            "the force-history, mean, impulse, and normalized peak-time differences "
            "to be at most 5%. A pass is fine-pair stabilization only because two "
            "grids cannot establish observed order or a Richardson uncertainty. "
            "Measured-force error is descriptive and cannot pass this numerical gate."
        ),
        "passed": True,
        "experimentalAgreementGateApplied": False,
        "gridConvergenceGateApplied": False,
        "claimBoundary": (
            "This contract was frozen after the D32 numerical report existed but "
            "before the D28/D32 force histories were compared. Its 5% limits and "
            "metrics are inherited from the repository's earlier fine-pair spatial "
            "gate. A pass does not establish observed-order grid convergence, "
            "experimental agreement, production promotion, or free flight."
        ),
    }
    PREREGISTRATION.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


def evaluate() -> None:
    preregistration = load(PREREGISTRATION)
    d28 = load(D28_REPORT)
    d28_audit = load(D28_AUDIT)
    d32 = load(D32_REPORT)
    d32_audit = load(D32_AUDIT)
    source_hashes_match = (
        preregistration["sourceD28ReportSHA256"] == sha256(D28_REPORT)
        and preregistration["sourceD28AuditSHA256"] == sha256(D28_AUDIT)
        and preregistration["sourceD32ReportSHA256"] == sha256(D32_REPORT)
        and preregistration["sourceD32AuditSHA256"] == sha256(D32_AUDIT)
    )
    if not source_hashes_match:
        raise SystemExit("refinement source hash drift")
    if not (
        d28["fullWindowGatePassed"]
        and d32["fullWindowGatePassed"]
        and d28_audit["allChecksPassed"]
        and d32_audit["allChecksPassed"]
        and d28["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and d32["selectedCollisionOperator"] == EXPECTED_OPERATOR
    ):
        raise SystemExit("refinement inputs are not numerically accepted RR3 windows")
    samples28 = d28["registeredForceSamples"]
    samples32 = d32["registeredForceSamples"]
    if len(samples28) != EXPECTED_SAMPLES or len(samples32) != EXPECTED_SAMPLES:
        raise SystemExit("wrong force-history length")
    if any(
        first["targetSampleIndex"] != second["targetSampleIndex"]
        or first["sourceTimeSeconds"] != second["sourceTimeSeconds"]
        for first, second in zip(samples28, samples32)
    ):
        raise SystemExit("D28/D32 force histories are not aligned")
    force28 = [vector(sample) for sample in samples28]
    force32 = [vector(sample) for sample in samples32]
    mean28 = mean(force28)
    mean32 = mean(force32)
    impulse28 = impulse(force28, 2_000.0)
    impulse32 = impulse(force32, 2_000.0)
    duration = float(samples28[-1]["sourceTimeSeconds"]) - float(
        samples28[0]["sourceTimeSeconds"]
    )
    metrics = {
        "intervalForceNormalizedRMSDifference": symmetric_history_difference(
            force28, force32
        ),
        "horizontalForceNormalizedRMSDifference": component_history_difference(
            force28, force32, 0
        ),
        "verticalForceNormalizedRMSDifference": component_history_difference(
            force28, force32, 1
        ),
        "meanForceRelativeDifference": relative_difference(mean28, mean32),
        "impulseRelativeDifference": relative_difference(impulse28, impulse32),
        "peakTimeDifferenceSeconds": abs(
            float(d28["computedPeakTimeSeconds"])
            - float(d32["computedPeakTimeSeconds"])
        ),
    }
    metrics["normalizedPeakTimeDifference"] = metrics[
        "peakTimeDifferenceSeconds"
    ] / max(duration, 1.0e-30)
    gate_metrics = [
        metrics["intervalForceNormalizedRMSDifference"],
        metrics["meanForceRelativeDifference"],
        metrics["impulseRelativeDifference"],
        metrics["normalizedPeakTimeDifference"],
    ]
    score = max(gate_metrics)
    passed = score <= float(preregistration["maximumFinePairDifference"])
    experimental_improvement = (
        float(d28["normalizedRMSError"]) - float(d32["normalizedRMSError"])
    ) / max(float(d28["normalizedRMSError"]), 1.0e-30)
    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": (
            "deetjen-ob-f03-source-viscosity-d28-d32-refinement-v1"
        ),
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "sourceD28ReportSHA256": sha256(D28_REPORT),
        "sourceD28AuditSHA256": sha256(D28_AUDIT),
        "sourceD32ReportSHA256": sha256(D32_REPORT),
        "sourceD32AuditSHA256": sha256(D32_AUDIT),
        "operator": EXPECTED_OPERATOR,
        "coarseReferenceLengthCells": 28,
        "fineReferenceLengthCells": 32,
        "registeredForceSampleCount": EXPECTED_SAMPLES,
        "metrics": metrics,
        "gridTrendScore": score,
        "maximumFinePairDifference": PAIR_LIMIT,
        "finePairStabilizationPassed": passed,
        "observedOrderAvailable": False,
        "richardsonUncertaintyAvailable": False,
        "gridConvergenceAccepted": False,
        "experimentalComparison": {
            "d28NormalizedRMSError": d28["normalizedRMSError"],
            "d32NormalizedRMSError": d32["normalizedRMSError"],
            "relativeErrorImprovement": experimental_improvement,
            "experimentalAgreementAccepted": False,
        },
        "numericalSafety": {
            "d28MinimumPopulation": d28["ledgerResult"]["minimumPopulation"],
            "d32MinimumPopulation": d32["ledgerResult"]["minimumPopulation"],
            "d28NearWingRelativeRMSResidual": d28["ledgerResult"][
                "relativeRMSRawControlVolumeClosureResidual"
            ],
            "d32NearWingRelativeRMSResidual": d32["ledgerResult"][
                "relativeRMSRawControlVolumeClosureResidual"
            ],
            "d28GlobalRelativeRMSResidual": d28["ledgerResult"][
                "relativeRMSGlobalFluidClosureResidual"
            ],
            "d32GlobalRelativeRMSResidual": d32["ledgerResult"][
                "relativeRMSGlobalFluidClosureResidual"
            ],
            "d28CorrectionActivationFraction": d28["ledgerResult"][
                "collisionLimiterActivationFractionOfCellSteps"
            ],
            "d32CorrectionActivationFraction": d32["ledgerResult"][
                "collisionLimiterActivationFractionOfCellSteps"
            ],
        },
        "classification": (
            "d28-d32-fine-pair-stabilized-experimental-mismatch-persists"
            if passed
            else "d28-d32-fine-pair-not-stabilized"
        ),
        "nextAction": (
            "Treat additional blind refinement as low ROI; preregister a source-"
            "input/model discrepancy analysis while retaining the two-grid limit "
            "on formal convergence claims."
            if passed
            else "Do not claim force-history stabilization; quantify whether a "
            "D36 allocation has sufficient expected information gain before running it."
        ),
        "productionModificationAuthorized": False,
        "claimBoundary": preregistration["claimBoundary"],
    }
    REPORT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


def main() -> None:
    parser = argparse.ArgumentParser()
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preregister", action="store_true")
    mode.add_argument("--evaluate", action="store_true")
    arguments = parser.parse_args()
    if arguments.preregister:
        preregister()
    else:
        evaluate()


if __name__ == "__main__":
    main()

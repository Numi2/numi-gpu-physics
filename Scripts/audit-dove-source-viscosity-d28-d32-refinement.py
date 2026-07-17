#!/usr/bin/env python3
"""Independently audit the D28/D32 source-viscosity refinement verdict."""

from __future__ import annotations

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
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d28-d32-refinement.json"
OUTPUT = (
    ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-refinement-audit.json"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def close(first: float, second: float, tolerance: float = 1.0e-10) -> bool:
    return math.isclose(first, second, rel_tol=tolerance, abs_tol=tolerance)


def vector(sample: dict) -> tuple[float, float]:
    force = sample["intervalMeanComputedForceNewtons"]
    return float(force[0]), float(force[2])


def norm(value: tuple[float, float]) -> float:
    return math.hypot(*value)


def mean(values: list[tuple[float, float]]) -> tuple[float, float]:
    return (
        sum(value[0] for value in values) / len(values),
        sum(value[1] for value in values) / len(values),
    )


def difference(
    first: tuple[float, float], second: tuple[float, float]
) -> tuple[float, float]:
    return first[0] - second[0], first[1] - second[1]


def relative(first: tuple[float, float], second: tuple[float, float]) -> float:
    return norm(difference(first, second)) / max(norm(first), norm(second), 1e-30)


def history(
    first: list[tuple[float, float]], second: list[tuple[float, float]]
) -> float:
    numerator = sum(
        component * component
        for index in range(len(first))
        for component in difference(first[index], second[index])
    )
    denominator = 0.5 * sum(
        component * component
        for values in (first, second)
        for value in values
        for component in value
    )
    return math.sqrt(numerator / max(denominator, 1e-30))


def component_history(
    first: list[tuple[float, float]],
    second: list[tuple[float, float]],
    axis: int,
) -> float:
    numerator = sum((second[i][axis] - first[i][axis]) ** 2 for i in range(len(first)))
    denominator = 0.5 * sum(
        value[axis] * value[axis] for values in (first, second) for value in values
    )
    return math.sqrt(numerator / max(denominator, 1e-30))


def impulse(values: list[tuple[float, float]]) -> tuple[float, float]:
    result = [0.0, 0.0]
    for previous, current in zip(values, values[1:]):
        result[0] += 0.5 * (previous[0] + current[0]) / 2_000.0
        result[1] += 0.5 * (previous[1] + current[1]) / 2_000.0
    return result[0], result[1]


def main() -> None:
    preregistration = load(PREREGISTRATION)
    report = load(REPORT)
    d28 = load(D28_REPORT)
    d28_audit = load(D28_AUDIT)
    d32 = load(D32_REPORT)
    d32_audit = load(D32_AUDIT)
    samples28 = d28["registeredForceSamples"]
    samples32 = d32["registeredForceSamples"]
    forces28 = [vector(sample) for sample in samples28]
    forces32 = [vector(sample) for sample in samples32]
    duration = float(samples28[-1]["sourceTimeSeconds"]) - float(
        samples28[0]["sourceTimeSeconds"]
    )
    metrics = {
        "intervalForceNormalizedRMSDifference": history(forces28, forces32),
        "horizontalForceNormalizedRMSDifference": component_history(
            forces28, forces32, 0
        ),
        "verticalForceNormalizedRMSDifference": component_history(
            forces28, forces32, 1
        ),
        "meanForceRelativeDifference": relative(mean(forces28), mean(forces32)),
        "impulseRelativeDifference": relative(
            impulse(forces28), impulse(forces32)
        ),
        "peakTimeDifferenceSeconds": abs(
            float(d28["computedPeakTimeSeconds"])
            - float(d32["computedPeakTimeSeconds"])
        ),
    }
    metrics["normalizedPeakTimeDifference"] = metrics[
        "peakTimeDifferenceSeconds"
    ] / max(duration, 1e-30)
    score = max(
        metrics["intervalForceNormalizedRMSDifference"],
        metrics["meanForceRelativeDifference"],
        metrics["impulseRelativeDifference"],
        metrics["normalizedPeakTimeDifference"],
    )
    limit = float(preregistration["maximumFinePairDifference"])
    passed = score <= limit
    archived_metrics = report["metrics"]
    metrics_match = archived_metrics.keys() == metrics.keys() and all(
        close(float(archived_metrics[key]), value) for key, value in metrics.items()
    )
    checks = {
        "preregistrationHash": report["preregistrationSHA256"]
        == sha256(PREREGISTRATION),
        "sourceHashes": preregistration["sourceD28ReportSHA256"]
        == sha256(D28_REPORT)
        and preregistration["sourceD28AuditSHA256"] == sha256(D28_AUDIT)
        and preregistration["sourceD32ReportSHA256"] == sha256(D32_REPORT)
        and preregistration["sourceD32AuditSHA256"] == sha256(D32_AUDIT)
        and report["sourceD28ReportSHA256"] == sha256(D28_REPORT)
        and report["sourceD28AuditSHA256"] == sha256(D28_AUDIT)
        and report["sourceD32ReportSHA256"] == sha256(D32_REPORT)
        and report["sourceD32AuditSHA256"] == sha256(D32_AUDIT),
        "sourceAudits": d28_audit["allChecksPassed"]
        and d28_audit["d28ForceHistoryAcceptedAsRefinementInput"]
        and d32_audit["allChecksPassed"]
        and d32_audit["d32ForceHistoryAcceptedAsRefinementInput"],
        "alignedSamples": len(samples28) == len(samples32) == 187
        and all(
            first["targetSampleIndex"] == second["targetSampleIndex"]
            and first["sourceTimeSeconds"] == second["sourceTimeSeconds"]
            for first, second in zip(samples28, samples32)
        ),
        "independentMetrics": metrics_match,
        "independentScore": close(float(report["gridTrendScore"]), score),
        "frozenLimit": close(limit, 0.05)
        and close(float(report["maximumFinePairDifference"]), limit),
        "verdict": report["finePairStabilizationPassed"] == passed
        and not passed,
        "classification": report["classification"]
        == "d28-d32-fine-pair-not-stabilized",
        "experimentalBoundary": not report["experimentalComparison"][
            "experimentalAgreementAccepted"
        ],
        "convergenceBoundary": not report["observedOrderAvailable"]
        and not report["richardsonUncertaintyAvailable"]
        and not report["gridConvergenceAccepted"],
        "productionBoundary": not report["productionModificationAuthorized"],
    }
    failed = [name for name, passed_check in checks.items() if not passed_check]
    if failed:
        raise SystemExit("D28/D32 refinement audit failed: " + ", ".join(failed))
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": (
            "deetjen-ob-f03-source-viscosity-d28-d32-refinement-audit-v1"
        ),
        "generatedBy": (
            "Scripts/audit-dove-source-viscosity-d28-d32-refinement.py"
        ),
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "reportSHA256": sha256(REPORT),
        "independentReconstruction": {
            "metrics": metrics,
            "gridTrendScore": score,
            "maximumFinePairDifference": limit,
            "finePairStabilizationPassed": passed,
        },
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": True,
        "d36RunAuthorized": False,
        "claimBoundary": (
            "The independently reconstructed D28/D32 history misses the frozen "
            "5% fine-pair limit. This rejects force-history stabilization and "
            "does not authorize D36, grid convergence, experimental agreement, "
            "production promotion, or free flight."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

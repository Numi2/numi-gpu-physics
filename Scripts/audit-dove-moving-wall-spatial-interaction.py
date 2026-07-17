#!/usr/bin/env python3
"""Independently rebuild the exact spatial mean-interaction allocation."""

from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
DISTRIBUTED_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force.json"
COVARIANCE_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-force-covariance-preregistration.json"
COVARIANCE_PATH = ARTIFACTS / "deetjen-dove-moving-wall-force-covariance.json"
COVARIANCE_AUDIT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-force-covariance-audit.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-interaction-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-interaction.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-interaction-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def add(first: list[float], second: list[float]) -> list[float]:
    return [a + b for a, b in zip(first, second)]


def sub(first: list[float], second: list[float]) -> list[float]:
    return [a - b for a, b in zip(first, second)]


def dot(first: list[float], second: list[float]) -> float:
    return sum(a * b for a, b in zip(first, second))


def magnitude(value: list[float]) -> float:
    return math.sqrt(dot(value, value))


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(float(first) - float(second)) <= tolerance * max(
        abs(float(first)), abs(float(second)), 1.0
    )


def vclose(first: list[float], second: list[float], tolerance: float = 2e-9) -> bool:
    return len(first) == len(second) and all(close(a, b, tolerance) for a, b in zip(first, second))


def key(item: dict) -> tuple[int, str, int, int]:
    return (
        int(item["partIdentifier"]), item["componentName"],
        int(item["directionIndex"]), int(item["interpolationFractionBinIndex"]),
    )


def axis_assessments(
    contributions: dict[tuple[int, str, int, int], float],
    total_interaction: float,
    axis: int,
) -> list[dict]:
    grouped: dict[str, float] = defaultdict(float)
    for spatial_key, contribution in contributions.items():
        part, name, direction, q_bin = spatial_key
        identifier = (
            f"part-{part}-{name}" if axis == 0 else
            f"direction-{direction}" if axis == 1 else
            f"q-bin-{q_bin}"
        )
        grouped[identifier] += contribution
    absolute_total = sum(abs(value) for value in grouped.values())
    return sorted(
        [
            {
                "identifier": identifier,
                "interactionNewtonsSquared": value,
                "signedInteractionFraction": value / total_interaction,
                "absoluteInteractionContributionFraction": abs(value) / max(absolute_total, 1e-30),
            }
            for identifier, value in grouped.items()
        ],
        key=lambda item: (-item["absoluteInteractionContributionFraction"], item["identifier"]),
    )


def assessment_close(first: list[dict], second: list[dict]) -> bool:
    expected = {item["identifier"]: item for item in first}
    actual = {item["identifier"]: item for item in second}
    return expected.keys() == actual.keys() and all(
        all(close(expected[name][field], actual[name][field]) for field in (
            "interactionNewtonsSquared", "signedInteractionFraction",
            "absoluteInteractionContributionFraction",
        ))
        for name in expected
    )


def main() -> None:
    distributed = load(DISTRIBUTED_PATH)
    covariance_prereg = load(COVARIANCE_PREREG_PATH)
    covariance = load(COVARIANCE_PATH)
    covariance_audit = load(COVARIANCE_AUDIT_PATH)
    prereg = load(PREREG_PATH)
    report = load(REPORT_PATH)
    metrics = report["metrics"]
    checks: dict[str, bool] = {}

    hashes = {
        "sourceDistributedForceReportSHA256": sha256(DISTRIBUTED_PATH),
        "sourceForceCovariancePreregistrationSHA256": sha256(COVARIANCE_PREREG_PATH),
        "sourceForceCovarianceReportSHA256": sha256(COVARIANCE_PATH),
        "sourceForceCovarianceAuditSHA256": sha256(COVARIANCE_AUDIT_PATH),
    }
    checks["sourceHashesMatch"] = all(
        prereg[field] == digest and report[field] == digest
        for field, digest in hashes.items()
    ) and report["sourcePreregistrationSHA256"] == sha256(PREREG_PATH)
    checks["sourceEvidencePassed"] = all([
        distributed["sourceReproductionPassed"],
        covariance_prereg["passed"],
        covariance["sourceReproductionPassed"],
        covariance["metrics"]["dominantPairIdentifier"] == "base-reflection+moving-wall",
        covariance["metrics"]["dominantPairSign"] == "canceling",
        covariance["metrics"]["dominantPairGatePassed"],
        covariance["metrics"]["dominantPairMechanism"] == "mean-offset-dominated",
        covariance_audit["allChecksPassed"],
    ])
    checks["preregisteredContractMatches"] = all([
        prereg["schemaVersion"] == 1,
        prereg["dominantPairIdentifier"] == "base-reflection+moving-wall",
        prereg["expectedSpatialBinCounts"] == [1438, 1440],
        prereg["expectedUnionSpatialBinCount"] == 1440,
        prereg["maximumAllowedTermMeanReconstructionErrorNewtons"] == 5e-6,
        prereg["maximumAllowedRelativeInteractionClosureError"] == 1e-5,
        prereg["minimumDominantAxisAbsoluteContributionFraction"] == 0.6,
        prereg["targetJointBinAbsoluteContributionFraction"] == 0.8,
        prereg["maximumJointBinFractionForTargetedCapture"] == 0.2,
        prereg["passed"], not prereg["experimentalAgreementGateApplied"],
    ])

    maps: dict[str, dict[tuple[int, str, int, int], tuple[list[float], list[float]]]] = {}
    for case in ("d12", "d16"):
        maps[case] = {
            key(item): (
                [float(value) for value in item["reflectedMeanForceNewtons"]],
                [float(value) for value in item["movingWallMeanForceNewtons"]],
            )
            for item in distributed[case]["spatialBins"]
        }
    union = set(maps["d12"]) | set(maps["d16"])
    ordered_union = sorted(union)
    zero = [0.0, 0.0, 0.0]
    deltas: dict[tuple[int, str, int, int], tuple[list[float], list[float]]] = {}
    for spatial_key in ordered_union:
        first = maps["d12"].get(spatial_key, (zero, zero))
        second = maps["d16"].get(spatial_key, (zero, zero))
        deltas[spatial_key] = (sub(second[0], first[0]), sub(second[1], first[1]))
    reflection_total = [0.0, 0.0, 0.0]
    wall_total = [0.0, 0.0, 0.0]
    for reflection, wall in deltas.values():
        reflection_total = add(reflection_total, reflection)
        wall_total = add(wall_total, wall)
    covariance_terms = {
        item["termIdentifier"]: item for item in covariance["metrics"]["terms"]
    }
    covariance_pair = next(
        item for item in covariance["metrics"]["pairs"]
        if item["pairIdentifier"] == "base-reflection+moving-wall"
    )
    maximum_term_error = max(
        magnitude(sub(reflection_total, covariance_terms["base-reflection"]["meanDeltaForceNewtons"])),
        magnitude(sub(wall_total, covariance_terms["moving-wall"]["meanDeltaForceNewtons"])),
    )
    interaction = 2 * dot(reflection_total, wall_total)
    source_interaction = 2 * covariance_pair["meanDotNewtonsSquared"]
    source_closure = abs(interaction - source_interaction) / max(abs(interaction), abs(source_interaction), 1e-30)
    contributions = {
        spatial_key: dot(reflection, wall_total) + dot(wall, reflection_total)
        for spatial_key, (reflection, wall) in deltas.items()
    }
    allocation_sum = sum(contributions.values())
    allocation_closure = abs(allocation_sum - interaction) / max(abs(allocation_sum), abs(interaction), 1e-30)
    checks["spatialSourceAndAllocationClose"] = all([
        len(maps["d12"]) == 1438,
        len(maps["d16"]) == 1440,
        len(union) == 1440,
        maximum_term_error <= prereg["maximumAllowedTermMeanReconstructionErrorNewtons"],
        source_closure <= prereg["maximumAllowedRelativeInteractionClosureError"],
        allocation_closure <= prereg["maximumAllowedRelativeInteractionClosureError"],
        close(maximum_term_error, metrics["maximumTermMeanReconstructionErrorNewtons"]),
        close(interaction, metrics["symmetricInteractionNewtonsSquared"]),
        close(source_interaction, metrics["sourcePairMeanInteractionNewtonsSquared"]),
        close(max(source_closure, allocation_closure), metrics["relativeInteractionClosureError"]),
    ])

    components = axis_assessments(contributions, interaction, 0)
    directions = axis_assessments(contributions, interaction, 1)
    q_bins = axis_assessments(contributions, interaction, 2)
    checks["axisMetricsReproduce"] = all([
        assessment_close(components, metrics["componentAssessments"]),
        assessment_close(directions, metrics["directionAssessments"]),
        assessment_close(q_bins, metrics["interpolationFractionAssessments"]),
    ])
    threshold = prereg["minimumDominantAxisAbsoluteContributionFraction"]
    dominant = lambda values: values[0]["identifier"] if values[0]["absoluteInteractionContributionFraction"] >= threshold else None
    checks["axisDominanceGatesReproduce"] = all([
        metrics.get("dominantComponent") == dominant(components),
        metrics.get("dominantDirection") == dominant(directions),
        metrics.get("dominantInterpolationFractionBin") == dominant(q_bins),
    ])

    absolute_total = sum(abs(value) for value in contributions.values())
    rebuilt_joint = []
    for spatial_key, contribution in contributions.items():
        part, name, direction, q_bin = spatial_key
        reflection, wall = deltas[spatial_key]
        rebuilt_joint.append({
            "partIdentifier": part,
            "componentName": name,
            "directionIndex": direction,
            "interpolationFractionBinIndex": q_bin,
            "reflectionMeanDeltaForceNewtons": reflection,
            "movingWallMeanDeltaForceNewtons": wall,
            "symmetricInteractionNewtonsSquared": contribution,
            "signedInteractionFraction": contribution / interaction,
            "absoluteInteractionContributionFraction": abs(contribution) / max(absolute_total, 1e-30),
            "supportsDominantCancellation": contribution * interaction > 0,
        })
    rebuilt_joint.sort(key=lambda item: (
        -item["absoluteInteractionContributionFraction"], item["partIdentifier"],
        item["directionIndex"], item["interpolationFractionBinIndex"],
    ))
    reported_joint = metrics["jointBins"]
    checks["jointBinMetricsReproduce"] = len(rebuilt_joint) == len(reported_joint) and all(
        all(first[field] == second[field] for field in (
            "partIdentifier", "componentName", "directionIndex",
            "interpolationFractionBinIndex", "supportsDominantCancellation",
        ))
        and vclose(first["reflectionMeanDeltaForceNewtons"], second["reflectionMeanDeltaForceNewtons"])
        and vclose(first["movingWallMeanDeltaForceNewtons"], second["movingWallMeanDeltaForceNewtons"])
        and all(close(first[field], second[field]) for field in (
            "symmetricInteractionNewtonsSquared", "signedInteractionFraction",
            "absoluteInteractionContributionFraction",
        ))
        for first, second in zip(rebuilt_joint, reported_joint)
    )
    active = [item for item in rebuilt_joint if item["absoluteInteractionContributionFraction"] > 0]
    accumulated = 0.0
    required = 0
    while required < len(active) and accumulated < prereg["targetJointBinAbsoluteContributionFraction"]:
        accumulated += active[required]["absoluteInteractionContributionFraction"]
        required += 1
    supporting = [item for item in active if item["supportsDominantCancellation"]]
    opposing = [item for item in active if not item["supportsDominantCancellation"]]
    supporting_fraction = sum(item["absoluteInteractionContributionFraction"] for item in supporting)
    checks["jointConcentrationReproduces"] = all([
        metrics["minimumJointBinsForTargetAbsoluteContribution"] == required,
        metrics["activeJointBinCount"] == len(active),
        close(metrics["achievedJointBinAbsoluteContributionFraction"], accumulated),
        metrics["cancellationSupportingJointBinCount"] == len(supporting),
        metrics["cancellationOpposingJointBinCount"] == len(opposing),
        close(metrics["cancellationSupportingAbsoluteContributionFraction"], supporting_fraction),
    ])
    dominant_axes = sum(value is not None for value in (
        dominant(components), dominant(directions), dominant(q_bins),
    ))
    concentrated = required / max(len(active), 1) <= prereg["maximumJointBinFractionForTargetedCapture"]
    targeted = dominant_axes >= 2 and concentrated
    source_reproduced = checks["spatialSourceAndAllocationClose"]
    classification = (
        "invalid-spatial-mean-interaction-allocation" if not source_reproduced else
        "targetable-spatial-mean-cancellation" if targeted else
        "partially-localized-spatial-mean-cancellation" if dominant_axes > 0 else
        "distributed-spatial-mean-cancellation"
    )
    checks["classificationAndSafetyBoundaryReproduce"] = all([
        report["sourceReproductionPassed"] == source_reproduced,
        report["classification"] == classification,
        report["targetedPrimitiveCaptureAuthorized"] == targeted,
        not report["d20DiagnosticAuthorized"],
        not report["productionModificationAuthorized"],
        not report["fluidEvolutionExecuted"],
        not report["rawSpatialGateModified"],
        not report["experimentalAgreementGateApplied"],
    ])

    audit = {
        "schemaVersion": 1,
        "auditor": "independent Python symmetric spatial interaction allocation",
        "sourceSHA256": {
            "distributedForceReport": hashes["sourceDistributedForceReportSHA256"],
            "forceCovariancePreregistration": hashes["sourceForceCovariancePreregistrationSHA256"],
            "forceCovarianceReport": hashes["sourceForceCovarianceReportSHA256"],
            "forceCovarianceAudit": hashes["sourceForceCovarianceAuditSHA256"],
            "spatialInteractionPreregistration": sha256(PREREG_PATH),
            "spatialInteractionReport": sha256(REPORT_PATH),
        },
        "checks": checks,
        "independentMetrics": {
            "maximumTermMeanReconstructionErrorNewtons": maximum_term_error,
            "relativeInteractionClosureError": max(source_closure, allocation_closure),
            "topComponent": components[0],
            "topDirection": directions[0],
            "topInterpolationFractionBin": q_bins[0],
            "minimumJointBinsFor80Percent": required,
            "activeJointBinCount": len(active),
            "cancellationSupportingAbsoluteContributionFraction": supporting_fraction,
            "targetedPrimitiveCaptureAuthorized": targeted,
        },
        "classification": classification,
        "allChecksPassed": all(checks.values()),
        "claimBoundary": (
            "This audit reconstructs the exact archive-only interaction allocation. "
            "It does not establish boundary causality or authorize production changes."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))
    if not audit["allChecksPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Independently rebuild the D12/D16 distributed force attribution archive."""

from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
GEOMETRY_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-preregistration.json"
GEOMETRY_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry.json"
DURATION_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration-preregistration.json"
DURATION_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration.json"
POPULATION_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-fallback-preregistration.json"
POPULATION_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-fallback.json"
POPULATION_AUDIT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-fallback-audit.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def add(a: list[float], b: list[float]) -> list[float]:
    return [x + y for x, y in zip(a, b)]


def sub(a: list[float], b: list[float]) -> list[float]:
    return [x - y for x, y in zip(a, b)]


def dot(a: list[float], b: list[float]) -> float:
    return sum(x * y for x, y in zip(a, b))


def squared(value: list[float]) -> float:
    return dot(value, value)


def magnitude(value: list[float]) -> float:
    return math.sqrt(squared(value))


def vector_rms(values: list[list[float]]) -> float:
    return math.sqrt(sum(squared(value) for value in values) / len(values))


def pairwise(first: list[list[float]], second: list[list[float]]) -> float:
    numerator = sum(squared(sub(a, b)) for a, b in zip(first, second))
    denominator = 0.5 * sum(
        squared(a) + squared(b) for a, b in zip(first, second)
    )
    return math.sqrt(numerator / max(denominator, 1e-30))


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(float(first) - float(second)) <= tolerance * max(
        abs(float(first)), abs(float(second)), 1.0
    )


def vclose(first: list[float], second: list[float], tolerance: float = 2e-9) -> bool:
    return len(first) == len(second) and all(
        close(a, b, tolerance) for a, b in zip(first, second)
    )


def alignment(delta: list[list[float]], total: list[list[float]], start: int, end: int) -> float:
    numerator = sum(dot(delta[index], total[index]) for index in range(start, end))
    denominator = sum(squared(total[index]) for index in range(start, end))
    return numerator / max(denominator, 1e-30)


def axis_assessments(joint: dict[tuple[int, str, int, int], list[float]], axis: int) -> list[dict]:
    grouped: dict[str, list[float]] = defaultdict(lambda: [0.0, 0.0, 0.0])
    for key, delta in joint.items():
        part, name, direction, q_bin = key
        identifier = (
            f"part-{part}-{name}" if axis == 0 else
            f"direction-{direction}" if axis == 1 else
            f"q-bin-{q_bin}"
        )
        grouped[identifier] = add(grouped[identifier], delta)
    total = [0.0, 0.0, 0.0]
    for delta in joint.values():
        total = add(total, delta)
    projection = max(squared(total), 1e-30)
    absolute = sum(abs(dot(delta, total)) for delta in grouped.values())
    result = [
        {
            "identifier": identifier,
            "deltaMeanForceNewtons": delta,
            "signedAlignmentContributionFraction": dot(delta, total) / projection,
            "absoluteAlignedContributionFraction": abs(dot(delta, total)) / max(absolute, 1e-30),
        }
        for identifier, delta in grouped.items()
    ]
    return sorted(result, key=lambda item: item["absoluteAlignedContributionFraction"], reverse=True)


def assessment_close(first: list[dict], second: list[dict]) -> bool:
    expected = {item["identifier"]: item for item in first}
    actual = {item["identifier"]: item for item in second}
    if expected.keys() != actual.keys():
        return False
    return all(
        vclose(expected[key]["deltaMeanForceNewtons"], actual[key]["deltaMeanForceNewtons"])
        and close(expected[key]["signedAlignmentContributionFraction"], actual[key]["signedAlignmentContributionFraction"])
        and close(expected[key]["absoluteAlignedContributionFraction"], actual[key]["absoluteAlignedContributionFraction"])
        for key in expected
    )


def main() -> None:
    geometry_prereg = load(GEOMETRY_PREREG_PATH)
    geometry = load(GEOMETRY_PATH)
    duration_prereg = load(DURATION_PREREG_PATH)
    duration = load(DURATION_PATH)
    population_prereg = load(POPULATION_PREREG_PATH)
    population = load(POPULATION_PATH)
    population_audit = load(POPULATION_AUDIT_PATH)
    prereg = load(PREREG_PATH)
    report = load(REPORT_PATH)

    source_paths = [
        GEOMETRY_PREREG_PATH, GEOMETRY_PATH,
        DURATION_PREREG_PATH, DURATION_PATH,
        POPULATION_PREREG_PATH, POPULATION_PATH, POPULATION_AUDIT_PATH,
    ]
    source_hash_fields = [
        "sourceLinkGeometryPreregistrationSHA256",
        "sourceLinkGeometryReportSHA256",
        "sourceTemporalDurationPreregistrationSHA256",
        "sourceTemporalDurationReportSHA256",
        "sourceLinkPopulationPreregistrationSHA256",
        "sourceLinkPopulationReportSHA256",
        "sourceLinkPopulationAuditSHA256",
    ]
    hashes = [sha256(path) for path in source_paths]
    checks: dict[str, bool] = {}
    checks["sourceHashesMatch"] = all(
        prereg[field] == digest and report[field] == digest
        for field, digest in zip(source_hash_fields, hashes)
    ) and report["sourcePreregistrationSHA256"] == sha256(PREREG_PATH)
    checks["sourceEvidencePassed"] = all([
        geometry_prereg["passed"], geometry["d12"]["parityGatePassed"],
        geometry["d16"]["parityGatePassed"], duration_prereg["passed"],
        duration["extendedSampling"]["d12"]["numericalCaseGatePassed"],
        duration["extendedSampling"]["d16"]["numericalCaseGatePassed"],
        population_prereg["passed"], population["sourceReproductionPassed"],
        population_audit["allChecksPassed"],
    ])
    geometry_counts = [
        sum(item["linkCount"] for item in geometry[key]["metalBins"])
        for key in ("d12", "d16")
    ]
    duration_steps = [
        duration["extendedSampling"][key]["requestedSteps"]
        for key in ("d12", "d16")
    ]
    checks["preregisteredContractMatches"] = all([
        prereg["schemaVersion"] == 1,
        prereg["referenceLengthCells"] == [12, 16],
        prereg["expectedLinkCounts"] == geometry_counts == [25262, 45514],
        prereg["expectedStepCounts"] == duration_steps == [576, 768],
        prereg["temporalBinCount"] == 24,
        prereg["interpolationFractionBinCount"] == 20,
        prereg["forceTerms"] == ["base-reflection", "moving-wall", "interpolation-residual"],
        prereg["passed"], not prereg["experimentalAgreementGateApplied"],
    ])

    case_checks = []
    duration_checks = []
    term_closure_checks = []
    spatial_checks = []
    aggregate_term_closures: dict[str, dict[str, float]] = {}
    histories: dict[str, dict[str, list[list[float]]]] = {}
    spatial_maps: dict[str, dict[tuple[int, str, int, int], list[float]]] = {}
    term_fields = {
        "base-reflection": "reflectedMeanForceNewtons",
        "moving-wall": "movingWallMeanForceNewtons",
        "interpolation-residual": "interpolationResidualMeanForceNewtons",
    }
    for offset, key in enumerate(("d12", "d16")):
        case = report[key]
        duration_case = duration["extendedSampling"][key]
        temporal = case["temporalBins"]
        spatial = case["spatialBins"]
        case_checks.append(all([
            case["referenceLengthCells"] == [12, 16][offset],
            case["expectedLinkCount"] == prereg["expectedLinkCounts"][offset],
            case["capturedLinkCount"] == case["expectedLinkCount"],
            sum(item["linkCount"] for item in spatial) == case["capturedLinkCount"],
            sum(item["fallbackLinkCount"] for item in spatial) == case["fallbackLinkCount"],
            case["requestedSteps"] == prereg["expectedStepCounts"][offset],
            case["completedSteps"] == case["requestedSteps"],
            case["fluidStepsPerTemporalBin"] * case["temporalBinCount"] == case["requestedSteps"],
            case["metadataMismatchCount"] <= prereg["maximumAllowedMetadataMismatchCount"],
            case["maximumLinkClassificationMismatchCountPerStep"] == 0,
            case["maximumAbsoluteTermClosureNewtons"] <= prereg["maximumAllowedAbsoluteTermClosureNewtons"],
            case["relativeRMSSourceForceClosure"] <= prereg["maximumAllowedRelativeRMSSourceForceClosure"],
            case["maximumDurationBinRelativeDifference"] <= prereg["maximumAllowedDurationBinRelativeDifference"],
            case["momentumClosurePassed"], case["sampledPopulationPositivityPassed"],
            case["allValuesFinite"], case["sourceReproductionPassed"],
        ]))
        temporal_term_closure = max(
            magnitude(sub(
                add(add(item["reflectedMeanForceNewtons"], item["movingWallMeanForceNewtons"]), item["interpolationResidualMeanForceNewtons"]),
                item["reconstructedTotalMeanForceNewtons"],
            ))
            for item in temporal
        )
        spatial_term_closure = max(
            magnitude(sub(
                add(add(item["reflectedMeanForceNewtons"], item["movingWallMeanForceNewtons"]), item["interpolationResidualMeanForceNewtons"]),
                item["reconstructedTotalMeanForceNewtons"],
            ))
            for item in spatial
        )
        term_closure_checks.append(
            temporal_term_closure <= 2e-6 and spatial_term_closure <= 1e-7
        )
        aggregate_term_closures[key] = {
            "maximumTemporalBinClosureNewtons": temporal_term_closure,
            "maximumSpatialBinClosureNewtons": spatial_term_closure,
        }
        duration_relative = [
            magnitude(sub(item["reconstructedTotalMeanForceNewtons"], source["impulsePreservingMeanForceNewtons"]))
            / max(magnitude(item["reconstructedTotalMeanForceNewtons"]), magnitude(source["impulsePreservingMeanForceNewtons"]), 1e-30)
            for item, source in zip(temporal, duration_case["bins"])
        ]
        duration_checks.append(
            close(max(duration_relative), case["maximumDurationBinRelativeDifference"], 2e-8)
            and max(duration_relative) <= prereg["maximumAllowedDurationBinRelativeDifference"]
        )
        histories[key] = {
            identifier: [item[field] for item in temporal]
            for identifier, field in term_fields.items()
        }
        histories[key]["total"] = [item["reconstructedTotalMeanForceNewtons"] for item in temporal]
        spatial_maps[key] = {
            (item["partIdentifier"], item["componentName"], item["directionIndex"], item["interpolationFractionBinIndex"]): item["reconstructedTotalMeanForceNewtons"]
            for item in spatial
        }
        spatial_checks.append(len(spatial_maps[key]) == len(spatial))

    checks["caseContractsAndNumericalGatesPass"] = all(case_checks)
    checks["temporalAndSpatialTermAlgebraCloses"] = all(term_closure_checks)
    checks["archivedDurationHistoriesReproduce"] = all(duration_checks)
    checks["spatialKeysAreUnique"] = all(spatial_checks)

    total_delta = [
        sub(b, a) for a, b in zip(histories["d12"]["total"], histories["d16"]["total"])
    ]
    total_delta_rms = vector_rms(total_delta)
    rebuilt_terms = []
    block_ranges = [(0, 8), (8, 16), (16, 24)]
    for identifier in prereg["forceTerms"]:
        first = histories["d12"][identifier]
        second = histories["d16"][identifier]
        delta = [sub(b, a) for a, b in zip(first, second)]
        rebuilt_terms.append({
            "termIdentifier": identifier,
            "crossGridNormalizedRMSDifference": pairwise(first, second),
            "deltaRMSNewtons": vector_rms(delta),
            "deltaToTotalDeltaRMSRatio": vector_rms(delta) / max(total_delta_rms, 1e-30),
            "alignmentContributionFraction": alignment(delta, total_delta, 0, 24),
            "blockAlignmentContributionFractions": [alignment(delta, total_delta, start, end) for start, end in block_ranges],
        })
    reported_terms = {item["termIdentifier"]: item for item in report["metrics"]["termAssessments"]}
    checks["termMetricsReproduce"] = all(
        close(item[field], reported_terms[item["termIdentifier"]][field])
        for item in rebuilt_terms
        for field in (
            "crossGridNormalizedRMSDifference", "deltaRMSNewtons",
            "deltaToTotalDeltaRMSRatio", "alignmentContributionFraction",
        )
    ) and all(
        all(close(a, b) for a, b in zip(item["blockAlignmentContributionFractions"], reported_terms[item["termIdentifier"]]["blockAlignmentContributionFractions"]))
        for item in rebuilt_terms
    )
    metrics = report["metrics"]
    checks["totalForceMetricsReproduce"] = (
        close(pairwise(histories["d12"]["total"], histories["d16"]["total"]), metrics["totalForcePairwiseNormalizedRMSDifference"])
        and close(total_delta_rms, metrics["totalDeltaRMSNewtons"])
    )
    dominant = max(rebuilt_terms, key=lambda item: item["alignmentContributionFraction"])
    winners = [max(rebuilt_terms, key=lambda item: item["blockAlignmentContributionFractions"][index]) for index in range(3)]
    consistent = all(item["termIdentifier"] == dominant["termIdentifier"] for item in winners)
    term_gate = (
        consistent
        and dominant["alignmentContributionFraction"] >= prereg["minimumDominantTermAlignmentFraction"]
        and all(item["blockAlignmentContributionFractions"][index] >= prereg["minimumDominantTermAlignmentFraction"] for index, item in enumerate(winners))
    )
    checks["dominanceGateReproduces"] = all([
        metrics["dominantTerm"] == dominant["termIdentifier"],
        metrics["dominantTermConsistentAcrossBlocks"] == consistent,
        metrics["dominantTermGatePassed"] == term_gate,
    ])

    all_keys = set(spatial_maps["d12"]) | set(spatial_maps["d16"])
    zero = [0.0, 0.0, 0.0]
    joint = {
        key: sub(spatial_maps["d16"].get(key, zero), spatial_maps["d12"].get(key, zero))
        for key in all_keys
    }
    components = axis_assessments(joint, 0)
    directions = axis_assessments(joint, 1)
    q_bins = axis_assessments(joint, 2)
    checks["spatialAxisMetricsReproduce"] = all([
        assessment_close(components, metrics["componentAssessments"]),
        assessment_close(directions, metrics["directionAssessments"]),
        assessment_close(q_bins, metrics["interpolationFractionAssessments"]),
    ])
    threshold = prereg["minimumDominantAxisAbsoluteContributionFraction"]
    dominant_axis = lambda items: items[0]["identifier"] if items and items[0]["absoluteAlignedContributionFraction"] >= threshold else None
    checks["spatialDominanceGateReproduces"] = all([
        metrics.get("dominantComponent") == dominant_axis(components),
        metrics.get("dominantDirection") == dominant_axis(directions),
        metrics.get("dominantInterpolationFractionBin") == dominant_axis(q_bins),
    ])
    total_mean_delta = [0.0, 0.0, 0.0]
    for delta in joint.values():
        total_mean_delta = add(total_mean_delta, delta)
    scores = sorted((abs(dot(delta, total_mean_delta)) for delta in joint.values() if abs(dot(delta, total_mean_delta)) > 0), reverse=True)
    target = prereg["targetJointBinAbsoluteContributionFraction"] * sum(scores)
    achieved = 0.0
    count = 0
    while count < len(scores) and achieved < target:
        achieved += scores[count]
        count += 1
    checks["jointBinConcentrationReproduces"] = all([
        metrics["activeJointBinCount"] == len(scores),
        metrics["minimumJointBinsForTargetAbsoluteAlignedContribution"] == count,
        close(metrics["achievedJointBinAbsoluteAlignedContributionFraction"], achieved / max(sum(scores), 1e-30)),
    ])
    source_reproduced = report["d12"]["sourceReproductionPassed"] and report["d16"]["sourceReproductionPassed"]
    classification = (
        "invalid-distributed-force-decomposition" if not source_reproduced else
        f"{dominant['termIdentifier']}-distributed-grid-bias" if term_gate else
        "mixed-term-distributed-grid-bias"
    )
    checks["classificationAndSafetyBoundaryReproduce"] = all([
        report["sourceReproductionPassed"] == source_reproduced,
        report["classification"] == classification,
        not report["d20DiagnosticAuthorized"],
        not report["productionModificationAuthorized"],
        not report["rawSpatialGateModified"],
        not report["experimentalAgreementGateApplied"],
    ])

    independent_metrics = {
        "totalForcePairwiseNormalizedRMSDifference": pairwise(histories["d12"]["total"], histories["d16"]["total"]),
        "totalDeltaRMSNewtons": total_delta_rms,
        "dominantTerm": dominant["termIdentifier"],
        "dominantTermAlignmentFraction": dominant["alignmentContributionFraction"],
        "blockWinners": [item["termIdentifier"] for item in winners],
        "dominantTermGatePassed": term_gate,
        "minimumJointBinsFor80Percent": count,
        "activeJointBinCount": len(scores),
        "aggregateTermClosures": aggregate_term_closures,
    }
    audit = {
        "schemaVersion": 1,
        "auditor": "independent Python reconstruction from archived temporal and spatial aggregates",
        "sourceSHA256": {
            "preregistration": sha256(PREREG_PATH),
            "report": sha256(REPORT_PATH),
        },
        "checks": checks,
        "independentMetrics": independent_metrics,
        "classification": classification,
        "allChecksPassed": all(checks.values()),
        "claimBoundary": (
            "This audit independently reconstructs archived aggregate algebra, source locks, "
            "cross-grid attribution, spatial concentration, classification, and safety gates. "
            "It does not recreate unarchived per-link GPU values or authorize production changes."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))
    if not audit["allChecksPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

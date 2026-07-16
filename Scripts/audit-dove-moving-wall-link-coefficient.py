#!/usr/bin/env python3
"""Independently reconstruct the 15-link q-dependent operator bound."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
RAY_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-ray-root-preregistration.json"
RAY_REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-ray-root.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-coefficient-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-coefficient.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-coefficient-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 1e-12) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def coefficients(q: float, threshold: float) -> tuple[str, list[float]]:
    assert 0.0 < q <= 1.0
    if q <= threshold:
        return "near-q-le-half", [2 * q, 1 - 2 * q, 0.0, 1 - q, q]
    return "far-q-gt-half", [
        1 / (2 * q),
        0.0,
        (2 * q - 1) / (2 * q),
        (1 - q) / (2 * q),
        0.5,
    ]


def weighted_rms(samples: list[dict], key: str) -> float:
    measure = sum(float(sample["linkMeasureSquareMeters"]) for sample in samples)
    return math.sqrt(sum(
        float(sample["linkMeasureSquareMeters"]) * float(sample[key]) ** 2
        for sample in samples
    ) / measure)


def audit_case(actual: dict, source: dict, threshold: float) -> tuple[dict, dict]:
    rebuilt: list[dict] = []
    identities = len(actual["samples"]) == len(source["samples"])
    coefficients_valid = identities
    for observed, ray in zip(actual["samples"], source["samples"]):
        identities &= all([
            int(observed["sourceOutlierIndex"]) == int(ray["sourceOutlierIndex"]),
            int(observed["partIdentifier"]) == int(ray["partIdentifier"]),
            observed["componentName"] == ray["componentName"],
            int(observed["directionIndex"]) == int(ray["directionIndex"]),
            observed["cellCoordinate"] == ray["cellCoordinate"],
            bool(observed["componentJunctionCandidate"])
                == bool(ray["componentJunctionCandidate"]),
            close(observed["linkMeasureSquareMeters"], ray["linkMeasureSquareMeters"]),
        ])
        production_q = float(ray["productionFluidToIntersectionFraction"])
        exact_q = float(ray["exactGlobalFluidToIntersectionFraction"])
        production_branch, production = coefficients(production_q, threshold)
        exact_branch, exact = coefficients(exact_q, threshold)
        differences = [abs(a - b) for a, b in zip(production, exact)]
        production_norm = sum(abs(value) for value in production)
        exact_norm = sum(abs(value) for value in exact)
        rebuilt_sample = {
            "absoluteFractionDifference": abs(production_q - exact_q),
            "branchChanged": production_branch != exact_branch,
            "coefficientL1Difference": sum(differences),
            "exactGlobalBranch": exact_branch,
            "exactGlobalCoefficients": exact,
            "exactGlobalOperatorL1Norm": exact_norm,
            "linkMeasureSquareMeters": float(ray["linkMeasureSquareMeters"]),
            "maximumAbsoluteCoefficientDifference": max(differences),
            "productionBranch": production_branch,
            "productionCoefficients": production,
            "productionOperatorL1Norm": production_norm,
            "symmetricOperatorNormRatio": max(
                production_norm / exact_norm, exact_norm / production_norm
            ),
            "wallProjectionCoefficientL1Difference": differences[3] + differences[4],
        }
        coefficient_keys = [
            "reflected", "fartherOutgoing", "previousIncoming",
            "fluidEndpointWallProjection", "solidEndpointWallProjection",
        ]
        coefficients_valid &= all([
            close(observed["productionFluidToIntersectionFraction"], production_q),
            close(observed["exactGlobalFluidToIntersectionFraction"], exact_q),
            observed["productionBranch"] == production_branch,
            observed["exactGlobalBranch"] == exact_branch,
            bool(observed["branchChanged"]) == rebuilt_sample["branchChanged"],
            all(close(observed["productionCoefficients"][key], value)
                for key, value in zip(coefficient_keys, production)),
            all(close(observed["exactGlobalCoefficients"][key], value)
                for key, value in zip(coefficient_keys, exact)),
            all(close(observed[key], rebuilt_sample[key]) for key in (
                "absoluteFractionDifference",
                "coefficientL1Difference",
                "maximumAbsoluteCoefficientDifference",
                "wallProjectionCoefficientL1Difference",
                "productionOperatorL1Norm",
                "exactGlobalOperatorL1Norm",
                "symmetricOperatorNormRatio",
            )),
        ])
        rebuilt.append(rebuilt_sample)

    changes = [sample for sample in rebuilt if sample["branchChanged"]]
    total_measure = sum(sample["linkMeasureSquareMeters"] for sample in rebuilt)
    summary = {
        "sampleCount": len(rebuilt),
        "productionNearBranchCount": sum(
            sample["productionBranch"] == "near-q-le-half" for sample in rebuilt
        ),
        "exactGlobalNearBranchCount": sum(
            sample["exactGlobalBranch"] == "near-q-le-half" for sample in rebuilt
        ),
        "nearToFarBranchChangeCount": sum(
            sample["branchChanged"]
            and sample["productionBranch"] == "near-q-le-half"
            for sample in rebuilt
        ),
        "farToNearBranchChangeCount": sum(
            sample["branchChanged"]
            and sample["productionBranch"] == "far-q-gt-half"
            for sample in rebuilt
        ),
        "branchChangeCount": len(changes),
        "branchChangeLinkMeasureFraction": sum(
            sample["linkMeasureSquareMeters"] for sample in changes
        ) / total_measure,
        "weightedRMSFractionDifference": weighted_rms(
            rebuilt, "absoluteFractionDifference"
        ),
        "maximumFractionDifference": max(
            sample["absoluteFractionDifference"] for sample in rebuilt
        ),
        "weightedRMSCoefficientL1Difference": weighted_rms(
            rebuilt, "coefficientL1Difference"
        ),
        "maximumCoefficientL1Difference": max(
            sample["coefficientL1Difference"] for sample in rebuilt
        ),
        "maximumAbsoluteCoefficientDifference": max(
            sample["maximumAbsoluteCoefficientDifference"] for sample in rebuilt
        ),
        "weightedRMSWallProjectionCoefficientL1Difference": weighted_rms(
            rebuilt, "wallProjectionCoefficientL1Difference"
        ),
        "maximumSymmetricOperatorNormRatio": max(
            sample["symmetricOperatorNormRatio"] for sample in rebuilt
        ),
    }
    summary_valid = int(actual["referenceLengthCells"]) == int(
        source["referenceLengthCells"]
    ) and all(
        int(actual[key]) == int(value) if isinstance(value, int)
        else close(actual[key], value)
        for key, value in summary.items()
    )
    return summary, {
        "identities": identities,
        "coefficients": coefficients_valid,
        "summary": summary_valid,
    }


def main() -> None:
    ray_prereg = load(RAY_PREREG_PATH)
    ray = load(RAY_REPORT_PATH)
    prereg = load(PREREG_PATH)
    report = load(REPORT_PATH)
    threshold = float(prereg["branchThreshold"])

    d12, d12_checks = audit_case(report["d12"], ray["d12"], threshold)
    d16, d16_checks = audit_case(report["d16"], ray["d16"], threshold)
    metrics = {
        "totalBranchChangeCount": d12["branchChangeCount"] + d16["branchChangeCount"],
        "maximumBranchChangeLinkMeasureFraction": max(
            d12["branchChangeLinkMeasureFraction"],
            d16["branchChangeLinkMeasureFraction"],
        ),
        "maximumWeightedRMSFractionDifference": max(
            d12["weightedRMSFractionDifference"], d16["weightedRMSFractionDifference"]
        ),
        "maximumFractionDifference": max(
            d12["maximumFractionDifference"], d16["maximumFractionDifference"]
        ),
        "maximumWeightedRMSCoefficientL1Difference": max(
            d12["weightedRMSCoefficientL1Difference"],
            d16["weightedRMSCoefficientL1Difference"],
        ),
        "maximumCoefficientL1Difference": max(
            d12["maximumCoefficientL1Difference"],
            d16["maximumCoefficientL1Difference"],
        ),
        "maximumAbsoluteCoefficientDifference": max(
            d12["maximumAbsoluteCoefficientDifference"],
            d16["maximumAbsoluteCoefficientDifference"],
        ),
        "maximumWeightedRMSWallProjectionCoefficientL1Difference": max(
            d12["weightedRMSWallProjectionCoefficientL1Difference"],
            d16["weightedRMSWallProjectionCoefficientL1Difference"],
        ),
        "maximumSymmetricOperatorNormRatio": max(
            d12["maximumSymmetricOperatorNormRatio"],
            d16["maximumSymmetricOperatorNormRatio"],
        ),
    }
    metrics_valid = all(
        int(report["metrics"][key]) == int(value) if isinstance(value, int)
        else close(report["metrics"][key], value)
        for key, value in metrics.items()
    )
    insensitive = (
        metrics["totalBranchChangeCount"] == 0
        and metrics["maximumWeightedRMSCoefficientL1Difference"]
            <= float(prereg["maximumAllowedWeightedRMSCoefficientL1Difference"])
        and metrics["maximumCoefficientL1Difference"]
            <= float(prereg["maximumAllowedCoefficientL1Difference"])
        and metrics["maximumSymmetricOperatorNormRatio"]
            <= float(prereg["maximumAllowedSymmetricOperatorNormRatio"])
    )
    classification = (
        "branch-changing-coefficient-sensitive"
        if metrics["totalBranchChangeCount"] > 0
        else "coefficient-insensitive-linear-q-bias"
        if insensitive
        else "same-branch-coefficient-sensitive"
    )
    checks = {
        "sourceHashes": all([
            prereg["sourceLinkRayRootPreregistrationSHA256"] == sha256(RAY_PREREG_PATH),
            prereg["sourceLinkRayRootReportSHA256"] == sha256(RAY_REPORT_PATH),
            report["sourceLinkCoefficientPreregistrationSHA256"] == sha256(PREREG_PATH),
            report["sourceLinkRayRootPreregistrationSHA256"] == sha256(RAY_PREREG_PATH),
            report["sourceLinkRayRootReportSHA256"] == sha256(RAY_REPORT_PATH),
        ]),
        "sourceRayRootPrecondition": all([
            ray["classification"] == "junction-global-root-linearization-bias",
            ray["sourceReproductionPassed"], ray["rootClosurePassed"],
            not ray["productionModificationAuthorized"],
            not ray["fluidEvolutionExecuted"],
        ]),
        "fixedContract": all([
            prereg["referenceLengthCells"] == [12, 16],
            prereg["expectedSampleCounts"] == [8, 7],
            close(threshold, 0.5),
            close(prereg["maximumAllowedWeightedRMSCoefficientL1Difference"], 0.10),
            close(prereg["maximumAllowedCoefficientL1Difference"], 0.25),
            close(prereg["maximumAllowedSymmetricOperatorNormRatio"], 1.10),
            prereg["passed"], not prereg["experimentalAgreementGateApplied"],
        ]),
        "d12SourceIdentity": d12_checks["identities"],
        "d12IndependentCoefficients": d12_checks["coefficients"],
        "d12Summary": d12_checks["summary"],
        "d16SourceIdentity": d16_checks["identities"],
        "d16IndependentCoefficients": d16_checks["coefficients"],
        "d16Summary": d16_checks["summary"],
        "crossGridMetrics": metrics_valid,
        "classification": all([
            report["classification"] == classification,
            bool(report["coefficientInsensitiveGatePassed"]) == insensitive,
            bool(report["validationOnlyPopulationReplayAuthorized"]) == (not insensitive),
        ]),
        "safetyBoundary": all([
            not report["d20DiagnosticAuthorized"],
            not report["productionModificationAuthorized"],
            not report["fluidEvolutionExecuted"],
            not report["rawSpatialGateModified"],
            not report["experimentalAgreementGateApplied"],
        ]),
    }
    output = {
        "schemaVersion": 1,
        "auditor": "independent-python-coefficient-reconstruction",
        "sourceSHA256": {
            "rayRootPreregistration": sha256(RAY_PREREG_PATH),
            "rayRootReport": sha256(RAY_REPORT_PATH),
            "coefficientPreregistration": sha256(PREREG_PATH),
            "coefficientReport": sha256(REPORT_PATH),
        },
        "independentMetrics": metrics,
        "classification": classification,
        "checks": checks,
        "allChecksPassed": all(checks.values()),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps(output, indent=2, sort_keys=True))
    if not output["allChecksPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

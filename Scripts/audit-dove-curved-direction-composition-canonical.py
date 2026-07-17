#!/usr/bin/env python3
"""Independently audit the source-locked curved direction canonical."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
MANIFEST = ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
LINK_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-moving-wall-link-geometry-preregistration.json"
)
LINK_REPORT = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry.json"
LINK_AUDIT = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-audit.json"
PLANAR_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-preregistration.json"
)
PLANAR_REPORT = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical.json"
)
PLANAR_AUDIT = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-audit.json"
)
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-preregistration.json"
)
REPORT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical.json"
)
OUTPUT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-audit.json"
)

DIRECTIONS = np.asarray([
    [0, 0, 0],
    [1, 0, 0], [-1, 0, 0],
    [0, 1, 0], [0, -1, 0],
    [0, 0, 1], [0, 0, -1],
    [1, 1, 0], [-1, -1, 0],
    [1, -1, 0], [-1, 1, 0],
    [1, 0, 1], [-1, 0, -1],
    [1, 0, -1], [-1, 0, 1],
    [0, 1, 1], [0, -1, -1],
    [0, 1, -1], [0, -1, 1],
], dtype=np.float64)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(left, right, *, atol: float = 2e-15, rtol: float = 2e-13) -> bool:
    """Compare nested JSON values while keeping booleans and strings exact."""
    if isinstance(left, bool) or isinstance(right, bool):
        return type(left) is type(right) and left == right
    if isinstance(left, (int, float)) and isinstance(right, (int, float)):
        return bool(np.isclose(left, right, atol=atol, rtol=rtol))
    if isinstance(left, list) and isinstance(right, list):
        return len(left) == len(right) and all(
            close(a, b, atol=atol, rtol=rtol) for a, b in zip(left, right)
        )
    if isinstance(left, dict) and isinstance(right, dict):
        return left.keys() == right.keys() and all(
            close(left[key], right[key], atol=atol, rtol=rtol)
            for key in left
        )
    return left == right


def profile_response(counts: np.ndarray, dx: float,
                     populations: np.ndarray) -> dict:
    terms = (
        2.0
        * populations[:, np.newaxis]
        * counts[:, np.newaxis]
        * dx * dx
        * DIRECTIONS
    )
    vector = np.sum(terms, axis=0)
    ledger = float(np.sum(np.linalg.norm(terms, axis=1)))
    return {
        "responseVector": vector.tolist(),
        "absoluteDirectionLedger": ledger,
        "netLedgerFraction": float(np.linalg.norm(vector) / max(ledger, 1e-300)),
    }


def direction_histogram(counts: np.ndarray, dx: float) -> np.ndarray:
    measure = counts.astype(np.float64) * dx * dx
    return measure / np.sum(measure)


def total_variation(first: np.ndarray, second: np.ndarray) -> float:
    return float(0.5 * np.sum(np.abs(first - second)))


def normalized_response_difference(first: dict, second: dict) -> float:
    delta = np.asarray(second["responseVector"]) - np.asarray(
        first["responseVector"]
    )
    denominator = 0.5 * (
        first["absoluteDirectionLedger"]
        + second["absoluteDirectionLedger"]
    )
    return float(np.linalg.norm(delta) / max(denominator, 1e-300))


def main() -> None:
    prereg = load(PREREGISTRATION)
    report = load(REPORT)
    source = load(LINK_REPORT)
    source_audit = load(LINK_AUDIT)
    planar_report = load(PLANAR_REPORT)
    planar_audit = load(PLANAR_AUDIT)

    profiles = {
        item["identifier"]: np.asarray(
            item["directionPopulations"], dtype=np.float64
        )
        for item in prereg["fixedPopulationProfiles"]
    }
    components = {
        item["partIdentifier"]: item["componentName"]
        for item in prereg["components"]
    }
    expected_cases = []
    expected_by_grid = {}
    metal_cpu_counts_match = True
    maximum_opposite_mismatch = 0
    maximum_equilibrium_fraction = 0.0

    for grid in prereg["referenceLengthCells"]:
        source_case = source[f"d{grid}"]
        metal = {
            (item["partIdentifier"], item["directionIndex"]):
                int(item["linkCount"])
            for item in source_case["metalBins"]
        }
        cpu = {
            (item["partIdentifier"], item["directionIndex"]):
                int(item["linkCount"])
            for item in source_case["cpuBins"]
        }
        metal_cpu_counts_match = metal_cpu_counts_match and metal == cpu
        dx = float(source_case["cellSizeMeters"])
        whole_counts = np.zeros(19, dtype=np.int64)
        component_rows = []
        for part, name in components.items():
            counts = np.zeros(19, dtype=np.int64)
            for direction in prereg["directionIndices"]:
                counts[direction] = metal[(part, direction)]
            whole_counts += counts
            responses = []
            for identifier, populations in profiles.items():
                responses.append({
                    "profileIdentifier": identifier,
                    **profile_response(counts, dx, populations),
                })
            component_rows.append({
                "partIdentifier": part,
                "componentName": name,
                "directionLinkCounts": counts.tolist(),
                "directionHistogram": direction_histogram(counts, dx).tolist(),
                "profileResponses": responses,
            })

        mismatches = [
            abs(int(whole_counts[first]) - int(whole_counts[second]))
            for first, second in prereg["oppositeDirectionPairs"]
        ]
        maximum_opposite_mismatch = max(
            maximum_opposite_mismatch, max(mismatches)
        )
        whole_responses = []
        for identifier, populations in profiles.items():
            whole_responses.append({
                "profileIdentifier": identifier,
                **profile_response(whole_counts, dx, populations),
            })
        equilibrium = next(
            item for item in whole_responses
            if item["profileIdentifier"] == "rest-equilibrium"
        )
        maximum_equilibrium_fraction = max(
            maximum_equilibrium_fraction,
            equilibrium["netLedgerFraction"],
        )
        case = {
            "referenceLengthCells": grid,
            "gridCells": [
                source_case["gridX"],
                source_case["gridY"],
                source_case["gridZ"],
            ],
            "cellSizeMeters": dx,
            "frozenSourceTimeSeconds": source_case["frozenSourceTimeSeconds"],
            "sourceMetalCPUParityPassed": source_case["parityGatePassed"],
            "wholeSurfaceDirectionLinkCounts": whole_counts.tolist(),
            "wholeSurfaceOppositeDirectionCountMismatches": mismatches,
            "wholeSurfaceDirectionHistogram": direction_histogram(
                whole_counts, dx
            ).tolist(),
            "wholeSurfaceProfileResponses": whole_responses,
            "components": component_rows,
        }
        expected_cases.append(case)
        expected_by_grid[grid] = case

    coarse = expected_by_grid[12]
    fine = expected_by_grid[16]
    whole_histogram_tv = total_variation(
        np.asarray(coarse["wholeSurfaceDirectionHistogram"]),
        np.asarray(fine["wholeSurfaceDirectionHistogram"]),
    )
    component_summaries = []
    maximum_component_histogram_tv = 0.0
    maximum_component_response_difference = 0.0
    for part, name in components.items():
        coarse_component = next(
            item for item in coarse["components"]
            if item["partIdentifier"] == part
        )
        fine_component = next(
            item for item in fine["components"]
            if item["partIdentifier"] == part
        )
        histogram_tv = total_variation(
            np.asarray(coarse_component["directionHistogram"]),
            np.asarray(fine_component["directionHistogram"]),
        )
        maximum_component_histogram_tv = max(
            maximum_component_histogram_tv, histogram_tv
        )
        response_differences = []
        for identifier in profiles:
            coarse_response = next(
                item for item in coarse_component["profileResponses"]
                if item["profileIdentifier"] == identifier
            )
            fine_response = next(
                item for item in fine_component["profileResponses"]
                if item["profileIdentifier"] == identifier
            )
            difference = normalized_response_difference(
                coarse_response, fine_response
            )
            maximum_component_response_difference = max(
                maximum_component_response_difference, difference
            )
            response_differences.append({
                "profileIdentifier": identifier,
                "responseLedgerDifference": difference,
            })
        component_summaries.append({
            "partIdentifier": part,
            "componentName": name,
            "directionHistogramTotalVariation": histogram_tv,
            "profileResponseDifferences": response_differences,
        })

    profile_summaries = []
    maximum_whole_response_difference = 0.0
    for identifier in profiles:
        coarse_response = next(
            item for item in coarse["wholeSurfaceProfileResponses"]
            if item["profileIdentifier"] == identifier
        )
        fine_response = next(
            item for item in fine["wholeSurfaceProfileResponses"]
            if item["profileIdentifier"] == identifier
        )
        difference = normalized_response_difference(
            coarse_response, fine_response
        )
        maximum_whole_response_difference = max(
            maximum_whole_response_difference, difference
        )
        profile_summaries.append({
            "profileIdentifier": identifier,
            "wholeSurfaceResponseLedgerDifference": difference,
        })

    maxima = {
        "maximumWholeSurfaceOppositeDirectionCountMismatch":
            maximum_opposite_mismatch,
        "maximumEquilibriumWholeSurfaceNetLedgerFraction":
            maximum_equilibrium_fraction,
        "wholeSurfaceDirectionHistogramTotalVariation": whole_histogram_tv,
        "maximumComponentDirectionHistogramTotalVariation":
            maximum_component_histogram_tv,
        "maximumWholeSurfaceProfileResponseLedgerDifference":
            maximum_whole_response_difference,
        "maximumComponentProfileResponseLedgerDifference":
            maximum_component_response_difference,
    }
    expected_gates = {
        "sourceMetalCPUParity": metal_cpu_counts_match and all(
            source[f"d{grid}"]["parityGatePassed"]
            and source[f"d{grid}"]["metalCPUExactLinkCountMatch"]
            for grid in prereg["referenceLengthCells"]
        ),
        "wholeSurfaceOppositeDirectionBalance": (
            maximum_opposite_mismatch
            <= prereg["maximumWholeSurfaceOppositeDirectionCountMismatch"]
        ),
        "equilibriumWholeSurfaceCancellation": (
            maximum_equilibrium_fraction
            <= prereg["maximumEquilibriumWholeSurfaceNetLedgerFraction"]
        ),
        "wholeSurfaceDirectionHistogram": (
            whole_histogram_tv
            <= prereg["maximumWholeSurfaceDirectionHistogramTotalVariation"]
        ),
        "componentDirectionHistograms": (
            maximum_component_histogram_tv
            <= prereg["maximumComponentDirectionHistogramTotalVariation"]
        ),
        "wholeSurfaceProfileResponses": (
            maximum_whole_response_difference
            <= prereg["maximumWholeSurfaceProfileResponseLedgerDifference"]
        ),
        "componentProfileResponses": (
            maximum_component_response_difference
            <= prereg["maximumComponentProfileResponseLedgerDifference"]
        ),
    }

    checks = {
        "sourceIdentities": (
            prereg["sourceSurfaceManifestSHA256"] == sha256(MANIFEST)
            and prereg["sourceLinkGeometryPreregistrationSHA256"]
            == sha256(LINK_PREREGISTRATION)
            and prereg["sourceLinkGeometryReportSHA256"]
            == sha256(LINK_REPORT)
            and prereg["sourceLinkGeometryAuditSHA256"] == sha256(LINK_AUDIT)
            and prereg["sourcePlanarPreregistrationSHA256"]
            == sha256(PLANAR_PREREGISTRATION)
            and prereg["sourcePlanarReportSHA256"] == sha256(PLANAR_REPORT)
            and prereg["sourcePlanarAuditSHA256"] == sha256(PLANAR_AUDIT)
            and report["sourcePreregistrationSHA256"]
            == sha256(PREREGISTRATION)
            and report["sourceLinkGeometryReportSHA256"] == sha256(LINK_REPORT)
        ),
        "frozenContract": (
            prereg["schemaVersion"] == 1
            and prereg["passed"]
            and prereg["referenceLengthCells"] == [12, 16]
            and prereg["frozenSourceSampleIndex"] == 53
            and np.isclose(prereg["frozenSourceTimeSeconds"], 0.0265)
            and prereg["directionIndices"] == list(range(1, 19))
            and len(prereg["fixedPopulationProfiles"]) == 2
        ),
        "auditedInputs": (
            source_audit["allChecksPassed"]
            and source_audit["checkCount"] == 13
            and planar_report["canonicalPassed"]
            and planar_report["basicPlanarDirectionWeightingCleared"]
            and planar_audit["allChecksPassed"]
            and planar_audit["checkCount"] == 14
        ),
        "fieldIsolation": (
            report["sourceFieldsConsumed"] == [
                "referenceLengthCells",
                "cellSizeMeters",
                "partIdentifier",
                "directionIndex",
                "linkCount",
                "Metal/CPU count parity",
            ]
            and report["sourceWallVelocityClassificationIgnored"]
            == source["classification"]
            and source["classification"] == "wall-velocity-deposition-bias"
            and not report["fluidEvolutionExecuted"]
            and not report["newMetalExecutionPerformed"]
        ),
        "caseCoverageAndMetadata": (
            len(report["cases"]) == 2
            and [item["referenceLengthCells"] for item in report["cases"]]
            == [12, 16]
            and all(len(item["components"]) == 4 for item in report["cases"])
            and all(
                np.isclose(item["frozenSourceTimeSeconds"], 0.0265)
                for item in report["cases"]
            )
        ),
        "independentMetalCPUCounts": metal_cpu_counts_match,
        "wholeSurfaceOppositeBalance": maximum_opposite_mismatch == 0,
        "independentCaseReconstruction": close(report["cases"], expected_cases),
        "independentComponentSummaries": close(
            report["componentSummaries"], component_summaries
        ),
        "independentProfileSummaries": close(
            report["profileSummaries"], profile_summaries
        ),
        "independentMaximumMetrics": all(
            close(report[key], value) for key, value in maxima.items()
        ),
        "frozenGates": report["gates"] == expected_gates,
        "classificationAndProfiles": (
            all(expected_gates.values())
            and report["canonicalPassed"]
            and report["equilibriumProfilePassed"]
            and report["sourceMidpointProfilePassed"]
            and report["classification"]
            == "curved-direction-redistribution-cleared-at-d12-d16"
        ),
        "claimBoundaryAndNoAuthorization": (
            report["claimBoundary"] == prereg["claimBoundary"]
            and not prereg["fluidEvolutionAuthorized"]
            and not prereg["newMetalExecutionAuthorized"]
            and not prereg["productionModificationAuthorized"]
            and not report["productionModificationAuthorized"]
            and not report["d20RunAuthorized"]
            and not report["d28D32FluidRunAuthorized"]
            and not report["gridConvergenceGateApplied"]
            and not report["experimentalAgreementGateApplied"]
        ),
    }
    checks = {name: bool(value) for name, value in checks.items()}
    passed = all(checks.values())
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": (
            "deetjen-ob-f03-curved-direction-composition-canonical-audit-v1"
        ),
        "generatedBy": (
            "Scripts/audit-dove-curved-direction-composition-canonical.py"
        ),
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "reportSHA256": sha256(REPORT),
        "sourceLinkGeometryReportSHA256": sha256(LINK_REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": passed,
        "independentReconstruction": maxima,
        "classification": report["classification"],
        "fluidEvolutionExecuted": False,
        "productionModificationAuthorized": False,
        "claimBoundary": (
            "This independent NumPy audit reconstructs both complete-dove "
            "curved grids, all four component and whole-surface direction "
            "histograms, two fixed-population responses, frozen gates, source "
            "isolation, and safety boundary. It does not validate wall velocity, "
            "authorize a production edit or fluid run, or establish quantitative "
            "bird flight."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("curved direction audit failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

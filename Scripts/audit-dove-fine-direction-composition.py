#!/usr/bin/env python3
"""Independently audit the D28/D32 complete-link direction discriminator."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
MANIFEST = ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
FORCE_TARGET = ROOT / "ValidationInputs/deetjen-ob-f03-force-v1.json"
CURVED_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-preregistration.json"
)
CURVED_REPORT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical.json"
)
CURVED_AUDIT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-audit.json"
)
D28_PROVENANCE = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
)
D32_PROVENANCE = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
)
PROVENANCE_AUDIT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-audit.json"
)
REFINEMENT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-d28-d32-refinement.json"
)
REFINEMENT_AUDIT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-d28-d32-refinement-audit.json"
)
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-fine-direction-composition-preregistration.json"
)
CENSUS = ARTIFACTS / "deetjen-dove-fine-direction-composition-census.json"
REPORT = ARTIFACTS / (
    "deetjen-dove-fine-direction-composition-discriminator.json"
)
OUTPUT = ARTIFACTS / (
    "deetjen-dove-fine-direction-composition-audit.json"
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
        2.0 * populations[:, np.newaxis] * counts[:, np.newaxis]
        * dx * dx * DIRECTIONS
    )
    vector = np.sum(terms, axis=0)
    ledger = float(np.sum(np.linalg.norm(terms, axis=1)))
    return {
        "responseVector": vector.tolist(),
        "absoluteDirectionLedger": ledger,
        "netLedgerFraction": float(np.linalg.norm(vector) / max(ledger, 1e-300)),
    }


def histogram(counts: np.ndarray, dx: float) -> np.ndarray:
    measures = counts.astype(np.float64) * dx * dx
    return measures / np.sum(measures)


def total_variation(first: np.ndarray, second: np.ndarray) -> float:
    return float(0.5 * np.sum(np.abs(first - second)))


def response_difference(first: dict, second: dict) -> float:
    vector = np.asarray(second["responseVector"]) - np.asarray(
        first["responseVector"]
    )
    ledger = 0.5 * (
        first["absoluteDirectionLedger"]
        + second["absoluteDirectionLedger"]
    )
    return float(np.linalg.norm(vector) / max(ledger, 1e-300))


def main() -> None:
    prereg = load(PREREGISTRATION)
    census = load(CENSUS)
    report = load(REPORT)
    curved_report = load(CURVED_REPORT)
    curved_audit = load(CURVED_AUDIT)
    d28 = load(D28_PROVENANCE)
    d32 = load(D32_PROVENANCE)
    provenance_audit = load(PROVENANCE_AUDIT)
    refinement = load(REFINEMENT)
    refinement_audit = load(REFINEMENT_AUDIT)

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
    metal_cpu_bins_match = True
    totals_match = True
    maximum_opposite_mismatch = 0
    maximum_equilibrium_fraction = 0.0

    for source_case in census["cases"]:
        grid = source_case["referenceLengthCells"]
        dx = float(source_case["cellSizeMeters"])
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
        metal_cpu_bins_match = metal_cpu_bins_match and metal == cpu
        totals_match = totals_match and (
            sum(metal.values()) == source_case["totalMetalLinkCount"]
            and sum(cpu.values()) == source_case["totalCPULinkCount"]
        )
        whole_counts = np.zeros(19, dtype=np.int64)
        component_rows = []
        for part, name in components.items():
            counts = np.zeros(19, dtype=np.int64)
            for direction in prereg["directionIndices"]:
                counts[direction] = metal[(part, direction)]
            whole_counts += counts
            responses = [
                {
                    "profileIdentifier": identifier,
                    **profile_response(counts, dx, populations),
                }
                for identifier, populations in profiles.items()
            ]
            component_rows.append({
                "partIdentifier": part,
                "componentName": name,
                "directionLinkCounts": counts.tolist(),
                "directionHistogram": histogram(counts, dx).tolist(),
                "profileResponses": responses,
            })
        mismatches = [
            abs(int(whole_counts[first]) - int(whole_counts[second]))
            for first, second in prereg["oppositeDirectionPairs"]
        ]
        maximum_opposite_mismatch = max(
            maximum_opposite_mismatch, max(mismatches)
        )
        whole_responses = [
            {
                "profileIdentifier": identifier,
                **profile_response(whole_counts, dx, populations),
            }
            for identifier, populations in profiles.items()
        ]
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
            "gridCells": source_case["gridCells"],
            "cellSizeMeters": dx,
            "frozenSourceTimeSeconds": source_case["frozenSourceTimeSeconds"],
            "totalLinkCount": source_case["totalMetalLinkCount"],
            "productionActiveLinkReference": source_case[
                "productionActiveLinkReference"
            ],
            "censusToProductionActiveLinkRelativeDifference": source_case[
                "censusToProductionActiveLinkRelativeDifference"
            ],
            "wholeSurfaceDirectionLinkCounts": whole_counts.tolist(),
            "wholeSurfaceOppositeDirectionCountMismatches": mismatches,
            "wholeSurfaceDirectionHistogram": histogram(
                whole_counts, dx
            ).tolist(),
            "wholeSurfaceProfileResponses": whole_responses,
            "components": component_rows,
        }
        expected_cases.append(case)
        expected_by_grid[grid] = case

    coarse = expected_by_grid[28]
    fine = expected_by_grid[32]
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
            difference = response_difference(coarse_response, fine_response)
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
        difference = response_difference(coarse_response, fine_response)
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
    production_consistency = all(
        item["censusToProductionActiveLinkRelativeDifference"]
        <= prereg["maximumCensusToProductionActiveLinkRelativeDifference"]
        for item in census["cases"]
    )
    expected_gates = {
        "metalCPUExactCensusParity": (
            metal_cpu_bins_match
            and census["maximumMetalCPUMaskMismatchCellCount"] == 0
            and census["maximumMetalCPUPerDirectionCountMismatch"] == 0
        ),
        "productionActiveLinkSetConsistency": production_consistency,
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
            prereg["manifestSHA256"] == sha256(MANIFEST)
            and prereg["forceTargetSHA256"] == sha256(FORCE_TARGET)
            and prereg["sourceCurvedPreregistrationSHA256"]
            == sha256(CURVED_PREREGISTRATION)
            and prereg["sourceCurvedReportSHA256"] == sha256(CURVED_REPORT)
            and prereg["sourceCurvedAuditSHA256"] == sha256(CURVED_AUDIT)
            and prereg["sourceD28ProvenanceSHA256"] == sha256(D28_PROVENANCE)
            and prereg["sourceD32ProvenanceSHA256"] == sha256(D32_PROVENANCE)
            and prereg["sourceProvenanceAuditSHA256"]
            == sha256(PROVENANCE_AUDIT)
            and prereg["sourceRefinementSHA256"] == sha256(REFINEMENT)
            and prereg["sourceRefinementAuditSHA256"]
            == sha256(REFINEMENT_AUDIT)
            and census["sourcePreregistrationSHA256"] == sha256(PREREGISTRATION)
            and report["sourceCensusSHA256"] == sha256(CENSUS)
        ),
        "frozenContract": (
            prereg["schemaVersion"] == 1
            and prereg["passed"]
            and prereg["referenceLengthCells"] == [28, 32]
            and prereg["frozenSourceSampleIndex"] == 53
            and np.isclose(prereg["frozenSourceTimeSeconds"], 0.0265)
            and prereg["directionIndices"] == list(range(1, 19))
            and len(prereg["fixedPopulationProfiles"]) == 2
        ),
        "auditedInputs": (
            curved_report["canonicalPassed"]
            and curved_audit["allChecksPassed"]
            and d28["provenanceCasePassed"]
            and d32["provenanceCasePassed"]
            and provenance_audit["allChecksPassed"]
            and refinement["classification"]
            == "d28-d32-fine-pair-not-stabilized"
            and refinement_audit["allChecksPassed"]
        ),
        "captureIsolation": (
            not census["fluidEvolutionExecuted"]
            and not census["populationAllocationPerformed"]
            and not census["newPhysicsKernelExecuted"]
            and not report["fluidEvolutionExecuted"]
            and not report["populationAllocationPerformed"]
            and not report["newPhysicsKernelExecuted"]
        ),
        "caseCoverageAndMetadata": (
            len(census["cases"]) == 2
            and [item["referenceLengthCells"] for item in census["cases"]]
            == [28, 32]
            and [item["gridCells"] for item in census["cases"]]
            == [[259, 238, 229], [296, 271, 261]]
            and all(len(item["metalBins"]) == 72 for item in census["cases"])
            and all(len(item["cpuBins"]) == 72 for item in census["cases"])
        ),
        "independentMetalCPUCounts": metal_cpu_bins_match,
        "independentTotals": totals_match,
        "productionLinkSetConsistency": production_consistency,
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
        "classification": (
            all(expected_gates.values())
            and report["analysisPassed"]
            and report["classification"]
            == "fine-direction-redistribution-cleared-at-d28-d32"
        ),
        "claimBoundaryAndNoAuthorization": (
            report["claimBoundary"] == prereg["claimBoundary"]
            and not prereg["productionModificationAuthorized"]
            and not prereg["d36RunAuthorized"]
            and not report["productionModificationAuthorized"]
            and not report["d36RunAuthorized"]
            and not report["gridConvergenceGateApplied"]
            and not report["experimentalAgreementGateApplied"]
        ),
    }
    checks = {name: bool(value) for name, value in checks.items()}
    passed = all(checks.values())
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": (
            "deetjen-ob-f03-fine-direction-composition-audit-v1"
        ),
        "generatedBy": "Scripts/audit-dove-fine-direction-composition.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "censusSHA256": sha256(CENSUS),
        "reportSHA256": sha256(REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": passed,
        "independentReconstruction": maxima,
        "classification": report["classification"],
        "fluidEvolutionExecuted": False,
        "productionModificationAuthorized": False,
        "claimBoundary": (
            "This independent NumPy audit reconstructs both fine-grid censuses, "
            "all 144 Metal/CPU component-direction counts, whole and component "
            "histograms, two fixed-profile responses, source identities, frozen "
            "gates, classification, and safety boundary. It does not establish "
            "force convergence or authorize D36 or a production edit."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("fine direction audit failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

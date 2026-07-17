#!/usr/bin/env python3
"""Evaluate the preregistered D28/D32 complete-link direction census."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-fine-direction-composition-preregistration.json"
)
CENSUS = ARTIFACTS / "deetjen-dove-fine-direction-composition-census.json"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-fine-direction-composition-discriminator.json"
)

DIRECTIONS = [
    (0, 0, 0),
    (1, 0, 0), (-1, 0, 0),
    (0, 1, 0), (0, -1, 0),
    (0, 0, 1), (0, 0, -1),
    (1, 1, 0), (-1, -1, 0),
    (1, -1, 0), (-1, 1, 0),
    (1, 0, 1), (-1, 0, -1),
    (1, 0, -1), (-1, 0, 1),
    (0, 1, 1), (0, -1, -1),
    (0, 1, -1), (0, -1, 1),
]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def norm(vector: list[float]) -> float:
    return math.sqrt(math.fsum(value * value for value in vector))


def response(counts: list[int], dx: float, populations: list[float]) -> dict:
    terms = []
    for direction, lattice_vector in enumerate(DIRECTIONS):
        coefficient = (
            2.0 * populations[direction] * counts[direction] * dx * dx
        )
        terms.append([
            coefficient * lattice_vector[axis] for axis in range(3)
        ])
    vector = [
        math.fsum(term[axis] for term in terms) for axis in range(3)
    ]
    ledger = math.fsum(norm(term) for term in terms)
    return {
        "responseVector": vector,
        "absoluteDirectionLedger": ledger,
        "netLedgerFraction": norm(vector) / max(ledger, 1e-300),
    }


def histogram(counts: list[int], dx: float) -> list[float]:
    measures = [count * dx * dx for count in counts]
    total = math.fsum(measures)
    return [measure / total for measure in measures]


def total_variation(first: list[float], second: list[float]) -> float:
    return 0.5 * math.fsum(
        abs(left - right) for left, right in zip(first, second)
    )


def response_difference(first: dict, second: dict) -> float:
    delta = [
        right - left for left, right in zip(
            first["responseVector"], second["responseVector"]
        )
    ]
    ledger = 0.5 * (
        first["absoluteDirectionLedger"]
        + second["absoluteDirectionLedger"]
    )
    return norm(delta) / max(ledger, 1e-300)


def main() -> None:
    prereg = load(PREREGISTRATION)
    census = load(CENSUS)
    if not (
        prereg["schemaVersion"] == 1
        and prereg["passed"]
        and prereg["referenceLengthCells"] == [28, 32]
        and census["schemaVersion"] == 1
        and census["sourcePreregistrationSHA256"] == sha256(PREREGISTRATION)
        and census["manifestSHA256"] == prereg["manifestSHA256"]
        and census["forceTargetSHA256"] == prereg["forceTargetSHA256"]
        and not census["fluidEvolutionExecuted"]
        and not census["populationAllocationPerformed"]
        and not census["newPhysicsKernelExecuted"]
    ):
        raise SystemExit("fine direction census does not match its contract")

    profiles = prereg["fixedPopulationProfiles"]
    cases = []
    cases_by_grid = {}
    source_parity = census["censusPassed"] and all(
        case["parityGatePassed"] for case in census["cases"]
    )
    production_consistency = all(
        case["productionLinkSetConsistencyGatePassed"]
        for case in census["cases"]
    )
    maximum_opposite_mismatch = 0
    maximum_equilibrium_fraction = 0.0
    for source_case in census["cases"]:
        resolution = source_case["referenceLengthCells"]
        dx = source_case["cellSizeMeters"]
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
        source_parity = source_parity and metal == cpu
        whole_counts = [0] * 19
        component_reports = []
        for component in prereg["components"]:
            part = component["partIdentifier"]
            counts = [0] + [
                metal[(part, direction)]
                for direction in prereg["directionIndices"]
            ]
            whole_counts = [
                total + count for total, count in zip(whole_counts, counts)
            ]
            component_reports.append({
                "partIdentifier": part,
                "componentName": component["componentName"],
                "directionLinkCounts": counts,
                "directionHistogram": histogram(counts, dx),
                "profileResponses": [
                    {
                        "profileIdentifier": profile["identifier"],
                        **response(
                            counts,
                            dx,
                            profile["directionPopulations"],
                        ),
                    }
                    for profile in profiles
                ],
            })
        mismatches = [
            abs(whole_counts[first] - whole_counts[second])
            for first, second in prereg["oppositeDirectionPairs"]
        ]
        maximum_opposite_mismatch = max(
            maximum_opposite_mismatch, max(mismatches)
        )
        whole_responses = [
            {
                "profileIdentifier": profile["identifier"],
                **response(
                    whole_counts,
                    dx,
                    profile["directionPopulations"],
                ),
            }
            for profile in profiles
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
            "referenceLengthCells": resolution,
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
            "wholeSurfaceDirectionLinkCounts": whole_counts,
            "wholeSurfaceOppositeDirectionCountMismatches": mismatches,
            "wholeSurfaceDirectionHistogram": histogram(whole_counts, dx),
            "wholeSurfaceProfileResponses": whole_responses,
            "components": component_reports,
        }
        cases.append(case)
        cases_by_grid[resolution] = case

    coarse = cases_by_grid[28]
    fine = cases_by_grid[32]
    whole_histogram_tv = total_variation(
        coarse["wholeSurfaceDirectionHistogram"],
        fine["wholeSurfaceDirectionHistogram"],
    )
    component_summaries = []
    maximum_component_histogram_tv = 0.0
    maximum_component_response_difference = 0.0
    for component in prereg["components"]:
        part = component["partIdentifier"]
        coarse_component = next(
            item for item in coarse["components"]
            if item["partIdentifier"] == part
        )
        fine_component = next(
            item for item in fine["components"]
            if item["partIdentifier"] == part
        )
        histogram_tv = total_variation(
            coarse_component["directionHistogram"],
            fine_component["directionHistogram"],
        )
        maximum_component_histogram_tv = max(
            maximum_component_histogram_tv, histogram_tv
        )
        response_differences = []
        for profile in profiles:
            identifier = profile["identifier"]
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
            "componentName": component["componentName"],
            "directionHistogramTotalVariation": histogram_tv,
            "profileResponseDifferences": response_differences,
        })

    profile_summaries = []
    maximum_whole_response_difference = 0.0
    for profile in profiles:
        identifier = profile["identifier"]
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

    gates = {
        "metalCPUExactCensusParity": source_parity,
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
    passed = all(gates.values())
    if not source_parity:
        classification = "invalid-census-parity"
    elif not production_consistency:
        classification = "production-link-set-mismatch"
    elif gates["wholeSurfaceOppositeDirectionBalance"] is False \
            or gates["equilibriumWholeSurfaceCancellation"] is False:
        classification = "fine-grid-closed-surface-counting-bias"
    elif gates["wholeSurfaceDirectionHistogram"] is False \
            or gates["componentDirectionHistograms"] is False:
        classification = "fine-grid-direction-redistribution"
    elif gates["wholeSurfaceProfileResponses"] is False \
            or gates["componentProfileResponses"] is False:
        classification = "fine-grid-population-weighted-direction-redistribution"
    else:
        classification = "fine-direction-redistribution-cleared-at-d28-d32"

    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": (
            "deetjen-ob-f03-fine-direction-composition-discriminator-v1"
        ),
        "sourcePreregistrationSHA256": sha256(PREREGISTRATION),
        "sourceCensusSHA256": sha256(CENSUS),
        "fluidEvolutionExecuted": False,
        "populationAllocationPerformed": False,
        "newPhysicsKernelExecuted": False,
        "cases": cases,
        "componentSummaries": component_summaries,
        "profileSummaries": profile_summaries,
        "maximumMetalCPUMaskMismatchCellCount": census[
            "maximumMetalCPUMaskMismatchCellCount"
        ],
        "maximumMetalCPUPerDirectionCountMismatch": census[
            "maximumMetalCPUPerDirectionCountMismatch"
        ],
        "maximumCensusToProductionActiveLinkRelativeDifference": census[
            "maximumCensusToProductionActiveLinkRelativeDifference"
        ],
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
        "gates": gates,
        "analysisPassed": passed,
        "classification": classification,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "scientificVerdict": (
            "The source-locked D28/D32 complete-link direction discriminator "
            f"is {classification}."
        ),
        "nextAction": (
            "Do not modify direction weighting. Extend this counts-only census "
            "across the already localized source samples 50 through 60 before "
            "any force-bearing moving-wall/interpolation experiment; no D36 "
            "allocation is authorized."
            if passed else
            "Localize the failed fine-direction gate before any D36 run, "
            "production edit, or new fluid evolution."
        ),
        "claimBoundary": prereg["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        failed = [name for name, value in gates.items() if not value]
        raise SystemExit("fine direction discriminator failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

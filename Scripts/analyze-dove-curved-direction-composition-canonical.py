#!/usr/bin/env python3
"""Evaluate the preregistered source-locked curved direction canonical."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-preregistration.json"
)
LINK_REPORT = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry.json"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical.json"
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


def vector_norm(value: list[float]) -> float:
    return math.sqrt(math.fsum(component * component for component in value))


def response(counts: list[int], dx: float, populations: list[float]) -> dict:
    terms = []
    scale = dx * dx
    for direction in range(19):
        c = DIRECTIONS[direction]
        coefficient = 2 * populations[direction] * counts[direction] * scale
        terms.append([coefficient * c[axis] for axis in range(3)])
    value = [math.fsum(term[axis] for term in terms) for axis in range(3)]
    ledger = math.fsum(vector_norm(term) for term in terms)
    return {
        "responseVector": value,
        "absoluteDirectionLedger": ledger,
        "netLedgerFraction": vector_norm(value) / max(ledger, 1e-300),
    }


def histogram(counts: list[int], dx: float) -> list[float]:
    measures = [count * dx * dx for count in counts]
    total = math.fsum(measures)
    return [measure / total for measure in measures]


def histogram_tv(first: list[float], second: list[float]) -> float:
    return 0.5 * math.fsum(abs(left - right) for left, right in zip(
        first, second
    ))


def response_difference(first: dict, second: dict) -> float:
    difference = [
        right - left for left, right in zip(
            first["responseVector"], second["responseVector"]
        )
    ]
    ledger = 0.5 * (
        first["absoluteDirectionLedger"]
        + second["absoluteDirectionLedger"]
    )
    return vector_norm(difference) / max(ledger, 1e-300)


def main() -> None:
    preregistration = load(PREREGISTRATION)
    source = load(LINK_REPORT)
    if not (
        preregistration["schemaVersion"] == 1
        and preregistration["passed"]
        and preregistration["sourceLinkGeometryReportSHA256"]
        == sha256(LINK_REPORT)
        and preregistration["referenceLengthCells"] == [12, 16]
        and not preregistration["fluidEvolutionAuthorized"]
        and not preregistration["newMetalExecutionAuthorized"]
        and not preregistration["productionModificationAuthorized"]
    ):
        raise SystemExit("curved direction-composition contract is invalid")

    source_cases = {12: source["d12"], 16: source["d16"]}
    components = preregistration["components"]
    profiles = preregistration["fixedPopulationProfiles"]
    cases = []
    case_by_resolution = {}
    source_parity = True
    maximum_opposite_mismatch = 0
    maximum_equilibrium_net_fraction = 0.0
    for resolution in preregistration["referenceLengthCells"]:
        source_case = source_cases[resolution]
        metal = {
            (item["partIdentifier"], item["directionIndex"]): item
            for item in source_case["metalBins"]
        }
        cpu = {
            (item["partIdentifier"], item["directionIndex"]): item
            for item in source_case["cpuBins"]
        }
        source_parity = source_parity and (
            source_case["parityGatePassed"]
            and source_case["metalCPUExactLinkCountMatch"]
            and all(
                metal[key]["linkCount"] == cpu[key]["linkCount"]
                for key in metal
            )
        )
        component_reports = []
        whole_counts = [0] * 19
        for component in components:
            part = component["partIdentifier"]
            counts = [0] + [
                int(metal[(part, direction)]["linkCount"])
                for direction in preregistration["directionIndices"]
            ]
            whole_counts = [
                total + count for total, count in zip(whole_counts, counts)
            ]
            profile_responses = [
                {
                    "profileIdentifier": profile["identifier"],
                    **response(
                        counts,
                        source_case["cellSizeMeters"],
                        profile["directionPopulations"],
                    ),
                }
                for profile in profiles
            ]
            component_reports.append({
                "partIdentifier": part,
                "componentName": component["componentName"],
                "directionLinkCounts": counts,
                "directionHistogram": histogram(
                    counts, source_case["cellSizeMeters"]
                ),
                "profileResponses": profile_responses,
            })
        opposite_mismatches = [
            abs(whole_counts[first] - whole_counts[second])
            for first, second in preregistration["oppositeDirectionPairs"]
        ]
        maximum_opposite_mismatch = max(
            maximum_opposite_mismatch, max(opposite_mismatches)
        )
        whole_responses = [
            {
                "profileIdentifier": profile["identifier"],
                **response(
                    whole_counts,
                    source_case["cellSizeMeters"],
                    profile["directionPopulations"],
                ),
            }
            for profile in profiles
        ]
        equilibrium = next(
            item for item in whole_responses
            if item["profileIdentifier"] == "rest-equilibrium"
        )
        maximum_equilibrium_net_fraction = max(
            maximum_equilibrium_net_fraction,
            equilibrium["netLedgerFraction"],
        )
        case = {
            "referenceLengthCells": resolution,
            "gridCells": [
                source_case["gridX"],
                source_case["gridY"],
                source_case["gridZ"],
            ],
            "cellSizeMeters": source_case["cellSizeMeters"],
            "frozenSourceTimeSeconds": source_case[
                "frozenSourceTimeSeconds"
            ],
            "sourceMetalCPUParityPassed": source_case["parityGatePassed"],
            "wholeSurfaceDirectionLinkCounts": whole_counts,
            "wholeSurfaceOppositeDirectionCountMismatches":
                opposite_mismatches,
            "wholeSurfaceDirectionHistogram": histogram(
                whole_counts, source_case["cellSizeMeters"]
            ),
            "wholeSurfaceProfileResponses": whole_responses,
            "components": component_reports,
        }
        cases.append(case)
        case_by_resolution[resolution] = case

    coarse = case_by_resolution[12]
    fine = case_by_resolution[16]
    whole_histogram_tv = histogram_tv(
        coarse["wholeSurfaceDirectionHistogram"],
        fine["wholeSurfaceDirectionHistogram"],
    )
    component_summaries = []
    profile_summaries = []
    maximum_component_histogram_tv = 0.0
    maximum_whole_profile_difference = 0.0
    maximum_component_profile_difference = 0.0
    for profile in profiles:
        identifier = profile["identifier"]
        first = next(
            item for item in coarse["wholeSurfaceProfileResponses"]
            if item["profileIdentifier"] == identifier
        )
        second = next(
            item for item in fine["wholeSurfaceProfileResponses"]
            if item["profileIdentifier"] == identifier
        )
        difference = response_difference(first, second)
        maximum_whole_profile_difference = max(
            maximum_whole_profile_difference, difference
        )
        profile_summaries.append({
            "profileIdentifier": identifier,
            "wholeSurfaceResponseLedgerDifference": difference,
        })
    for component in components:
        part = component["partIdentifier"]
        first = next(
            item for item in coarse["components"]
            if item["partIdentifier"] == part
        )
        second = next(
            item for item in fine["components"]
            if item["partIdentifier"] == part
        )
        direction_tv = histogram_tv(
            first["directionHistogram"], second["directionHistogram"]
        )
        maximum_component_histogram_tv = max(
            maximum_component_histogram_tv, direction_tv
        )
        response_differences = []
        for profile in profiles:
            identifier = profile["identifier"]
            coarse_response = next(
                item for item in first["profileResponses"]
                if item["profileIdentifier"] == identifier
            )
            fine_response = next(
                item for item in second["profileResponses"]
                if item["profileIdentifier"] == identifier
            )
            difference = response_difference(
                coarse_response, fine_response
            )
            maximum_component_profile_difference = max(
                maximum_component_profile_difference, difference
            )
            response_differences.append({
                "profileIdentifier": identifier,
                "responseLedgerDifference": difference,
            })
        component_summaries.append({
            "partIdentifier": part,
            "componentName": component["componentName"],
            "directionHistogramTotalVariation": direction_tv,
            "profileResponseDifferences": response_differences,
        })

    gates = {
        "sourceMetalCPUParity": source_parity,
        "wholeSurfaceOppositeDirectionBalance": (
            maximum_opposite_mismatch
            <= preregistration[
                "maximumWholeSurfaceOppositeDirectionCountMismatch"
            ]
        ),
        "equilibriumWholeSurfaceCancellation": (
            maximum_equilibrium_net_fraction
            <= preregistration[
                "maximumEquilibriumWholeSurfaceNetLedgerFraction"
            ]
        ),
        "wholeSurfaceDirectionHistogram": (
            whole_histogram_tv
            <= preregistration[
                "maximumWholeSurfaceDirectionHistogramTotalVariation"
            ]
        ),
        "componentDirectionHistograms": (
            maximum_component_histogram_tv
            <= preregistration[
                "maximumComponentDirectionHistogramTotalVariation"
            ]
        ),
        "wholeSurfaceProfileResponses": (
            maximum_whole_profile_difference
            <= preregistration[
                "maximumWholeSurfaceProfileResponseLedgerDifference"
            ]
        ),
        "componentProfileResponses": (
            maximum_component_profile_difference
            <= preregistration[
                "maximumComponentProfileResponseLedgerDifference"
            ]
        ),
    }
    passed = all(gates.values())
    equilibrium_summary = next(
        item for item in profile_summaries
        if item["profileIdentifier"] == "rest-equilibrium"
    )
    source_summary = next(
        item for item in profile_summaries
        if item["profileIdentifier"] == "deetjen-midpoint-pooled"
    )
    equilibrium_components_pass = all(
        next(
            item for item in component["profileResponseDifferences"]
            if item["profileIdentifier"] == "rest-equilibrium"
        )["responseLedgerDifference"]
        <= preregistration["maximumComponentProfileResponseLedgerDifference"]
        for component in component_summaries
    )
    source_components_pass = all(
        next(
            item for item in component["profileResponseDifferences"]
            if item["profileIdentifier"] == "deetjen-midpoint-pooled"
        )["responseLedgerDifference"]
        <= preregistration["maximumComponentProfileResponseLedgerDifference"]
        for component in component_summaries
    )
    equilibrium_profile_passed = (
        equilibrium_summary["wholeSurfaceResponseLedgerDifference"]
        <= preregistration["maximumWholeSurfaceProfileResponseLedgerDifference"]
        and equilibrium_components_pass
    )
    source_profile_passed = (
        source_summary["wholeSurfaceResponseLedgerDifference"]
        <= preregistration["maximumWholeSurfaceProfileResponseLedgerDifference"]
        and source_components_pass
    )
    if passed:
        classification = "curved-direction-redistribution-cleared-at-d12-d16"
    elif not (
        gates["sourceMetalCPUParity"]
        and gates["wholeSurfaceOppositeDirectionBalance"]
        and gates["equilibriumWholeSurfaceCancellation"]
    ):
        classification = "invalid-curved-geometry-direction-accounting"
    elif equilibrium_profile_passed and not source_profile_passed:
        classification = "source-profile-curvature-redistribution"
    else:
        classification = "curved-geometry-direction-redistribution"

    artifact = {
        "schemaVersion": 1,
        "canonicalIdentifier": preregistration[
            "preregistrationIdentifier"
        ],
        "sourcePreregistrationSHA256": sha256(PREREGISTRATION),
        "sourceLinkGeometryReportSHA256": sha256(LINK_REPORT),
        "fluidEvolutionExecuted": False,
        "newMetalExecutionPerformed": False,
        "sourceWallVelocityClassificationIgnored": source["classification"],
        "sourceFieldsConsumed": [
            "referenceLengthCells", "cellSizeMeters", "partIdentifier",
            "directionIndex", "linkCount", "Metal/CPU count parity",
        ],
        "cases": cases,
        "wholeSurfaceDirectionHistogramTotalVariation": whole_histogram_tv,
        "componentSummaries": component_summaries,
        "profileSummaries": profile_summaries,
        "maximumWholeSurfaceOppositeDirectionCountMismatch":
            maximum_opposite_mismatch,
        "maximumEquilibriumWholeSurfaceNetLedgerFraction":
            maximum_equilibrium_net_fraction,
        "maximumComponentDirectionHistogramTotalVariation":
            maximum_component_histogram_tv,
        "maximumWholeSurfaceProfileResponseLedgerDifference":
            maximum_whole_profile_difference,
        "maximumComponentProfileResponseLedgerDifference":
            maximum_component_profile_difference,
        "gates": gates,
        "equilibriumProfilePassed": equilibrium_profile_passed,
        "sourceMidpointProfilePassed": source_profile_passed,
        "canonicalPassed": passed,
        "classification": classification,
        "productionModificationAuthorized": False,
        "d20RunAuthorized": False,
        "d28D32FluidRunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "scientificVerdict": (
            "The source-locked 26.5 ms curved complete-dove direction-only "
            f"canonical is {classification}."
        ),
        "nextAction": (
            "Do not modify direction weighting. Preregister one archive-only "
            "D28/D32 full-link direction-count capture at the same 26.5 ms "
            "phase before any new fluid evolution."
            if passed else
            "Localize the failing component, direction pair, and population "
            "profile before any new geometry capture, fluid run, or production edit."
        ),
        "claimBoundary": preregistration["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        failed = [name for name, value in gates.items() if not value]
        raise SystemExit("curved direction canonical failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

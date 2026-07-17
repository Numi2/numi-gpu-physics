#!/usr/bin/env python3
"""Evaluate all eleven preregistered D28/D32 direction-composition pairs."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREG = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-preregistration.json"
CENSUS = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-census.json"
OUTPUT = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-discriminator.json"

DIRECTIONS = [
    (0, 0, 0), (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0),
    (0, 0, 1), (0, 0, -1), (1, 1, 0), (-1, -1, 0),
    (1, -1, 0), (-1, 1, 0), (1, 0, 1), (-1, 0, -1),
    (1, 0, -1), (-1, 0, 1), (0, 1, 1), (0, -1, -1),
    (0, 1, -1), (0, -1, 1),
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def norm(vector: list[float]) -> float:
    return math.sqrt(math.fsum(value * value for value in vector))


def response(counts: list[int], dx: float, populations: list[float]) -> dict:
    terms = []
    for direction, lattice_vector in enumerate(DIRECTIONS):
        coefficient = 2.0 * populations[direction] * counts[direction] * dx * dx
        terms.append([coefficient * lattice_vector[axis] for axis in range(3)])
    vector = [math.fsum(term[axis] for term in terms) for axis in range(3)]
    ledger = math.fsum(norm(term) for term in terms)
    return {"vector": vector, "ledger": ledger, "fraction": norm(vector) / max(ledger, 1e-300)}


def histogram(counts: list[int], dx: float) -> list[float]:
    measures = [count * dx * dx for count in counts]
    total = math.fsum(measures)
    return [measure / total for measure in measures]


def total_variation(first: list[float], second: list[float]) -> float:
    return 0.5 * math.fsum(abs(a - b) for a, b in zip(first, second))


def response_difference(first: dict, second: dict) -> float:
    delta = [b - a for a, b in zip(first["vector"], second["vector"])]
    return norm(delta) / max(0.5 * (first["ledger"] + second["ledger"]), 1e-300)


def reconstruct(source: dict, prereg: dict) -> dict:
    metal = {
        (item["partIdentifier"], item["directionIndex"]): int(item["linkCount"])
        for item in source["metalBins"]
    }
    dx = source["cellSizeMeters"]
    whole = [0] * 19
    components = {}
    for component in prereg["components"]:
        part = component["partIdentifier"]
        counts = [0] + [metal[(part, direction)] for direction in range(1, 19)]
        whole = [a + b for a, b in zip(whole, counts)]
        components[part] = {
            "histogram": histogram(counts, dx),
            "responses": {
                profile["identifier"]: response(
                    counts, dx, profile["directionPopulations"]
                )
                for profile in prereg["fixedPopulationProfiles"]
            },
        }
    opposite = [
        abs(whole[a] - whole[b]) for a, b in prereg["oppositeDirectionPairs"]
    ]
    responses = {
        profile["identifier"]: response(
            whole, dx, profile["directionPopulations"]
        )
        for profile in prereg["fixedPopulationProfiles"]
    }
    return {
        "source": source,
        "wholeHistogram": histogram(whole, dx),
        "components": components,
        "responses": responses,
        "oppositeMaximum": max(opposite),
        "equilibriumFraction": responses["rest-equilibrium"]["fraction"],
    }


def main() -> None:
    prereg = json.loads(PREREG.read_text())
    census = json.loads(CENSUS.read_text())
    if not (
        prereg["schemaVersion"] == 2
        and prereg["arithmeticOnlyRevision"]
        and census["schemaVersion"] == 2
        and census["sourcePreregistrationSHA256"] == sha256(PREREG)
        and census["censusPassed"]
        and len(census["cases"]) == 22
        and not census["fluidEvolutionExecuted"]
        and not census["newMetalExecutionPerformed"]
    ):
        raise SystemExit("qualified phase-window census does not match V2")

    source_cases = {
        (case["sourceSampleIndex"], case["referenceLengthCells"]): case
        for case in census["cases"]
    }
    phase_summaries = []
    maxima = {
        "opposite": 0,
        "equilibrium": 0.0,
        "wholeHistogram": 0.0,
        "componentHistogram": 0.0,
        "wholeResponse": 0.0,
        "componentResponse": 0.0,
    }
    aggregate_gates = {
        "arithmeticQualifiedCensusParity": True,
        "productionActiveLinkSetConsistency": True,
        "wholeSurfaceOppositeDirectionBalance": True,
        "equilibriumWholeSurfaceCancellation": True,
        "wholeSurfaceDirectionHistogram": True,
        "componentDirectionHistograms": True,
        "wholeSurfaceProfileResponses": True,
        "componentProfileResponses": True,
    }

    for sample_index, source_time in zip(
        prereg["sourceSampleIndices"], prereg["sourceTimesSeconds"]
    ):
        coarse = reconstruct(source_cases[(sample_index, 28)], prereg)
        fine = reconstruct(source_cases[(sample_index, 32)], prereg)
        opposite = max(coarse["oppositeMaximum"], fine["oppositeMaximum"])
        equilibrium = max(
            coarse["equilibriumFraction"], fine["equilibriumFraction"]
        )
        whole_histogram = total_variation(
            coarse["wholeHistogram"], fine["wholeHistogram"]
        )
        component_histograms = []
        component_responses = []
        for component in prereg["components"]:
            part = component["partIdentifier"]
            component_histograms.append(
                total_variation(
                    coarse["components"][part]["histogram"],
                    fine["components"][part]["histogram"],
                )
            )
            for profile in prereg["fixedPopulationProfiles"]:
                identifier = profile["identifier"]
                component_responses.append(
                    response_difference(
                        coarse["components"][part]["responses"][identifier],
                        fine["components"][part]["responses"][identifier],
                    )
                )
        whole_responses = [
            response_difference(
                coarse["responses"][profile["identifier"]],
                fine["responses"][profile["identifier"]],
            )
            for profile in prereg["fixedPopulationProfiles"]
        ]
        component_histogram = max(component_histograms)
        component_response = max(component_responses)
        whole_response = max(whole_responses)
        qualified = all(
            source_cases[(sample_index, resolution)]["qualifiedParityGatePassed"]
            for resolution in (28, 32)
        )
        production = all(
            source_cases[(sample_index, resolution)][
                "productionLinkSetConsistencyGatePassed"
            ]
            for resolution in (28, 32)
        )
        gates = {
            "arithmeticQualifiedCensusParity": qualified,
            "productionActiveLinkSetConsistency": production,
            "wholeSurfaceOppositeDirectionBalance": opposite
            <= prereg["maximumWholeSurfaceOppositeDirectionCountMismatch"],
            "equilibriumWholeSurfaceCancellation": equilibrium
            <= prereg["maximumEquilibriumWholeSurfaceNetLedgerFraction"],
            "wholeSurfaceDirectionHistogram": whole_histogram
            <= prereg["maximumWholeSurfaceDirectionHistogramTotalVariation"],
            "componentDirectionHistograms": component_histogram
            <= prereg["maximumComponentDirectionHistogramTotalVariation"],
            "wholeSurfaceProfileResponses": whole_response
            <= prereg["maximumWholeSurfaceProfileResponseLedgerDifference"],
            "componentProfileResponses": component_response
            <= prereg["maximumComponentProfileResponseLedgerDifference"],
        }
        for name, value in gates.items():
            aggregate_gates[name] = aggregate_gates[name] and value
        maxima["opposite"] = max(maxima["opposite"], opposite)
        maxima["equilibrium"] = max(maxima["equilibrium"], equilibrium)
        maxima["wholeHistogram"] = max(maxima["wholeHistogram"], whole_histogram)
        maxima["componentHistogram"] = max(
            maxima["componentHistogram"], component_histogram
        )
        maxima["wholeResponse"] = max(maxima["wholeResponse"], whole_response)
        maxima["componentResponse"] = max(
            maxima["componentResponse"], component_response
        )
        phase_summaries.append(
            {
                "sourceSampleIndex": sample_index,
                "sourceTimeSeconds": source_time,
                "wholeSurfaceDirectionHistogramTotalVariation": whole_histogram,
                "maximumComponentDirectionHistogramTotalVariation": component_histogram,
                "maximumWholeSurfaceProfileResponseLedgerDifference": whole_response,
                "maximumComponentProfileResponseLedgerDifference": component_response,
                "maximumWholeSurfaceOppositeDirectionCountMismatch": opposite,
                "maximumEquilibriumWholeSurfaceNetLedgerFraction": equilibrium,
                "gates": gates,
                "passed": all(gates.values()),
            }
        )

    passed = all(aggregate_gates.values())
    if not aggregate_gates["arithmeticQualifiedCensusParity"]:
        classification = "unqualified-arithmetic-mismatch"
    elif not aggregate_gates["productionActiveLinkSetConsistency"]:
        classification = "production-link-set-mismatch"
    elif not (
        aggregate_gates["wholeSurfaceOppositeDirectionBalance"]
        and aggregate_gates["equilibriumWholeSurfaceCancellation"]
    ):
        classification = "phase-resolved-closed-surface-counting-bias"
    elif not (
        aggregate_gates["wholeSurfaceDirectionHistogram"]
        and aggregate_gates["componentDirectionHistograms"]
    ):
        classification = "phase-resolved-direction-redistribution"
    elif not (
        aggregate_gates["wholeSurfaceProfileResponses"]
        and aggregate_gates["componentProfileResponses"]
    ):
        classification = "phase-resolved-profile-response-redistribution"
    else:
        classification = "fine-direction-phase-window-cleared-at-d28-d32"

    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": "deetjen-ob-f03-fine-direction-phase-window-discriminator-v1",
        "sourcePreregistrationSHA256": sha256(PREREG),
        "sourceCensusSHA256": sha256(CENSUS),
        "sourceSampleIndices": prereg["sourceSampleIndices"],
        "sourceTimesSeconds": prereg["sourceTimesSeconds"],
        "fluidEvolutionExecuted": False,
        "populationAllocationPerformed": False,
        "newPhysicsKernelExecuted": False,
        "newMetalExecutionPerformed": False,
        "phaseSummaries": phase_summaries,
        "maximumMetalCPUMaskMismatchCellCount": census["maximumMetalCPUMaskMismatchCellCount"],
        "maximumMetalCPUPerDirectionCountMismatch": census["maximumMetalCPUPerDirectionCountMismatch"],
        "maximumMetalCPUWholeDirectionCountMismatch": census["maximumMetalCPUWholeDirectionCountMismatch"],
        "qualifiedTieCellCount": census["qualifiedTieCellCount"],
        "maximumCensusToProductionActiveLinkRelativeDifference": census["maximumCensusToProductionActiveLinkRelativeDifference"],
        "maximumWholeSurfaceOppositeDirectionCountMismatch": maxima["opposite"],
        "maximumEquilibriumWholeSurfaceNetLedgerFraction": maxima["equilibrium"],
        "maximumWholeSurfaceDirectionHistogramTotalVariation": maxima["wholeHistogram"],
        "maximumComponentDirectionHistogramTotalVariation": maxima["componentHistogram"],
        "maximumWholeSurfaceProfileResponseLedgerDifference": maxima["wholeResponse"],
        "maximumComponentProfileResponseLedgerDifference": maxima["componentResponse"],
        "gates": aggregate_gates,
        "passedPhaseCount": sum(item["passed"] for item in phase_summaries),
        "phaseCount": len(phase_summaries),
        "analysisPassed": passed,
        "classification": classification,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "scientificVerdict": f"The 25-30 ms D28/D32 complete-link discriminator is {classification}.",
        "nextAction": (
            "Do not modify direction weighting. Preregister a zero-fluid force-bearing replay that separates moving-wall velocity, interpolation branch, and reflected-population effects across the same samples before D36."
            if passed
            else "Localize the failed phase and gate before D36, production edits, or fluid evolution."
        ),
        "claimBoundary": prereg["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        raise SystemExit("phase-window discriminator failed")


if __name__ == "__main__":
    main()

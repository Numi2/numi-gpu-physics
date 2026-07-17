#!/usr/bin/env python3
"""Decompose D28/D32 reflected force into population and composition terms."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-preregistration.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
OUTPUT = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key(stratum: dict) -> tuple:
    return (
        stratum["partIdentifier"],
        stratum["directionIndex"],
        stratum["branch"],
        stratum["topologyClass"],
        stratum["linkFractionBin"],
    )


def xz(vector: list[float]) -> tuple[float, float]:
    return float(vector[0]), float(vector[2])


def add(left: tuple[float, float], right: tuple[float, float]) -> tuple[float, float]:
    return left[0] + right[0], left[1] + right[1]


def subtract(
    right: tuple[float, float], left: tuple[float, float]
) -> tuple[float, float]:
    return right[0] - left[0], right[1] - left[1]


def scale(value: float, vector: tuple[float, float]) -> tuple[float, float]:
    return value * vector[0], value * vector[1]


def dot(left: tuple[float, float], right: tuple[float, float]) -> float:
    return left[0] * right[0] + left[1] * right[1]


def energy(values: list[tuple[float, float]]) -> float:
    return sum(dot(value, value) for value in values)


def relative_rms(
    residuals: list[tuple[float, float]],
    references: list[tuple[float, float]],
) -> float:
    return math.sqrt(energy(residuals) / max(energy(references), 1.0e-30))


def ledger(
    population: list[tuple[float, float]],
    composition: list[tuple[float, float]],
    indices: range,
) -> tuple[list[dict], float, float]:
    entries = [
        {
            "name": "populationHistory",
            "kind": "self",
            "signedSquaredDifferenceContribution": sum(
                dot(population[index], population[index]) for index in indices
            ),
        },
        {
            "name": "linkComposition",
            "kind": "self",
            "signedSquaredDifferenceContribution": sum(
                dot(composition[index], composition[index]) for index in indices
            ),
        },
        {
            "name": "populationHistory x linkComposition",
            "kind": "interaction",
            "signedSquaredDifferenceContribution": 2.0
            * sum(
                dot(population[index], composition[index]) for index in indices
            ),
        },
    ]
    signed_total = sum(
        entry["signedSquaredDifferenceContribution"] for entry in entries
    )
    absolute_total = sum(
        abs(entry["signedSquaredDifferenceContribution"]) for entry in entries
    )
    for entry in entries:
        value = entry["signedSquaredDifferenceContribution"]
        entry["fractionOfSignedTotal"] = value / max(signed_total, 1.0e-30)
        entry["fractionOfAbsoluteLedger"] = abs(value) / max(
            absolute_total, 1.0e-30
        )
    entries.sort(key=lambda item: item["fractionOfAbsoluteLedger"], reverse=True)
    return entries, signed_total, absolute_total


def main() -> None:
    prereg = load(PREREGISTRATION)
    d28 = load(D28)
    d32 = load(D32)
    prereg_sha = sha256(PREREGISTRATION)
    if not (
        prereg["schemaVersion"] == 2
        and prereg["passed"]
        and d28["provenanceCasePassed"]
        and d32["provenanceCasePassed"]
        and d28["sourcePreregistrationSHA256"] == prereg_sha
        and d32["sourcePreregistrationSHA256"] == prereg_sha
        and d28["referenceLengthCells"] == 28
        and d32["referenceLengthCells"] == 32
    ):
        raise SystemExit("both preregistered provenance cases must pass")

    endpoints28 = d28["endpoints"]
    endpoints32 = d32["endpoints"]
    if len(endpoints28) != len(endpoints32) or any(
        left["targetSampleIndex"] != right["targetSampleIndex"]
        or left["sourceTimeSeconds"] != right["sourceTimeSeconds"]
        for left, right in zip(endpoints28, endpoints32)
    ):
        raise SystemExit("D28/D32 provenance endpoints are not aligned")

    population_deltas: list[tuple[float, float]] = []
    composition_deltas: list[tuple[float, float]] = []
    reconstructed_deltas: list[tuple[float, float]] = []
    raw_selected_deltas: list[tuple[float, float]] = []
    endpoint_reports = []
    for endpoint28, endpoint32 in zip(endpoints28, endpoints32):
        strata28 = {key(item): item for item in endpoint28["strata"]}
        strata32 = {key(item): item for item in endpoint32["strata"]}
        population_total = (0.0, 0.0)
        composition_total = (0.0, 0.0)
        stratum_reports = []
        for stratum_key in sorted(set(strata28) | set(strata32)):
            left = strata28.get(stratum_key)
            right = strata32.get(stratum_key)
            mean28 = float(left["reflectedPopulationMean"]) if left else 0.0
            mean32 = float(right["reflectedPopulationMean"]) if right else 0.0
            coefficient28 = xz(left["coefficientVectorNewtonsPerPopulation"]) if left else (0.0, 0.0)
            coefficient32 = xz(right["coefficientVectorNewtonsPerPopulation"]) if right else (0.0, 0.0)
            population_term = scale(
                0.5 * (mean32 - mean28),
                add(coefficient32, coefficient28),
            )
            composition_term = scale(
                0.5 * (mean32 + mean28),
                subtract(coefficient32, coefficient28),
            )
            population_total = add(population_total, population_term)
            composition_total = add(composition_total, composition_term)
            stratum_reports.append(
                {
                    "partIdentifier": stratum_key[0],
                    "directionIndex": stratum_key[1],
                    "branch": stratum_key[2],
                    "topologyClass": stratum_key[3],
                    "linkFractionBin": stratum_key[4],
                    "d28SelectedLinkCount": left["selectedLinkCount"] if left else 0,
                    "d32SelectedLinkCount": right["selectedLinkCount"] if right else 0,
                    "d28ReflectedPopulationMean": mean28,
                    "d32ReflectedPopulationMean": mean32,
                    "populationHistoryD32MinusD28": list(population_term),
                    "linkCompositionD32MinusD28": list(composition_term),
                }
            )
        reconstructed = add(population_total, composition_total)
        raw_selected = subtract(
            xz(endpoint32["selectedReflectedForceNewtons"]),
            xz(endpoint28["selectedReflectedForceNewtons"]),
        )
        population_deltas.append(population_total)
        composition_deltas.append(composition_total)
        reconstructed_deltas.append(reconstructed)
        raw_selected_deltas.append(raw_selected)
        endpoint_reports.append(
            {
                "targetSampleIndex": endpoint28["targetSampleIndex"],
                "sourceTimeSeconds": endpoint28["sourceTimeSeconds"],
                "populationHistoryD32MinusD28": list(population_total),
                "linkCompositionD32MinusD28": list(composition_total),
                "reconstructedSelectedD32MinusD28": list(reconstructed),
                "rawSelectedD32MinusD28": list(raw_selected),
                "strata": stratum_reports,
            }
        )

    # Reconstruct the exact K*m delta independently of the midpoint split.
    direct_deltas = []
    for endpoint28, endpoint32 in zip(endpoints28, endpoints32):
        direct = (0.0, 0.0)
        for sign, endpoint in ((-1.0, endpoint28), (1.0, endpoint32)):
            for stratum in endpoint["strata"]:
                direct = add(
                    direct,
                    scale(
                        sign * float(stratum["reflectedPopulationMean"]),
                        xz(stratum["coefficientVectorNewtonsPerPopulation"]),
                    ),
                )
        direct_deltas.append(direct)
    algebra_residuals = [
        subtract(reconstructed, direct)
        for reconstructed, direct in zip(reconstructed_deltas, direct_deltas)
    ]
    raw_residuals = [
        subtract(reconstructed, raw)
        for reconstructed, raw in zip(reconstructed_deltas, raw_selected_deltas)
    ]
    algebra_closure = relative_rms(algebra_residuals, direct_deltas)
    raw_consistency = relative_rms(raw_residuals, raw_selected_deltas)

    split = len(endpoints28) // 2
    full, signed_total, absolute_total = ledger(
        population_deltas, composition_deltas, range(len(endpoints28))
    )
    early, _, _ = ledger(population_deltas, composition_deltas, range(split))
    late, _, _ = ledger(
        population_deltas, composition_deltas, range(split, len(endpoints28))
    )
    difference_energy = energy(reconstructed_deltas)
    energy_closure = abs(signed_total - difference_energy) / max(
        abs(signed_total), difference_energy, 1.0e-30
    )
    leading = full[0]
    stable = early[0]["name"] == leading["name"] == late[0]["name"]
    dominant = (
        leading["kind"] == "self"
        and leading["fractionOfAbsoluteLedger"]
        >= prereg["minimumDominantContributionFraction"]
        and stable
    )
    if dominant and leading["name"] == "populationHistory":
        classification = "dominant-population-history"
        mechanism = "bulk collision/transport population history"
    elif dominant and leading["name"] == "linkComposition":
        classification = "dominant-near-wall-link-composition"
        mechanism = "near-wall link composition"
    else:
        classification = "mixed-population-composition"
        mechanism = "mixed population-history and link-composition sensitivity"

    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": "deetjen-ob-f03-reflected-population-provenance-attribution-v1",
        "generatedBy": "Scripts/analyze-dove-reflected-population-provenance.py",
        "preregistrationSHA256": prereg_sha,
        "sourceD28CaseSHA256": sha256(D28),
        "sourceD32CaseSHA256": sha256(D32),
        "targetSampleIndices": [item["targetSampleIndex"] for item in endpoints28],
        "targetTimesSeconds": [item["sourceTimeSeconds"] for item in endpoints28],
        "endpoints": endpoint_reports,
        "populationHistoryD32MinusD28": [list(value) for value in population_deltas],
        "linkCompositionD32MinusD28": [list(value) for value in composition_deltas],
        "reconstructedSelectedD32MinusD28": [list(value) for value in reconstructed_deltas],
        "rawSelectedD32MinusD28": [list(value) for value in raw_selected_deltas],
        "populationCompositionClosureRelativeRMS": algebra_closure,
        "rawFloatForceConsistencyRelativeRMS": raw_consistency,
        "squaredDifferenceEnergy": difference_energy,
        "signedLedgerTotal": signed_total,
        "absoluteLedgerTotal": absolute_total,
        "squaredDifferenceEnergyClosureRelativeError": energy_closure,
        "contributionLedger": full,
        "earlyContributionLedger": early,
        "lateContributionLedger": late,
        "attribution": {
            "classification": classification,
            "identifiedMechanism": mechanism,
            "dominantContributionAvailable": dominant,
            "leadingContributionName": leading["name"],
            "leadingContributionKind": leading["kind"],
            "leadingAbsoluteLedgerFraction": leading["fractionOfAbsoluteLedger"],
            "minimumDominantContributionFraction": prereg["minimumDominantContributionFraction"],
            "sameLeaderInBothTemporalHalves": stable,
            "earlyLeader": early[0]["name"],
            "lateLeader": late[0]["name"],
        },
        "bothProvenanceCasesPassed": True,
        "populationCompositionClosurePassed": algebra_closure
        <= prereg["maximumPopulationCompositionClosureRelativeRMS"],
        "productionModificationAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "gridConvergenceGateApplied": False,
        "scientificVerdict": (
            f"The frozen ledger identifies {mechanism} as a temporally stable "
            f">=50% self contribution."
            if dominant
            else (
                "No self term reaches the frozen >=50% threshold while leading "
                "both temporal halves; the D28/D32 reflected-force difference "
                "is mixed."
            )
        ),
        "nextAction": (
            "Run one minimal canonical that isolates the identified mechanism "
            "before changing production physics."
            if dominant
            else (
                "Use the interaction sign and endpoint strata to preregister one "
                "narrow discriminator; do not tune production physics from a "
                "mixed attribution."
            )
        ),
        "claimBoundary": prereg["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not artifact["populationCompositionClosurePassed"]:
        raise SystemExit("population/composition algebra did not close")


if __name__ == "__main__":
    main()

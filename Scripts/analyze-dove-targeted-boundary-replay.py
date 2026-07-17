#!/usr/bin/env python3
"""Attribute the targeted D28/D32 force difference to boundary mechanisms."""

from __future__ import annotations

import hashlib
import itertools
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-source-viscosity-targeted-boundary-preregistration.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-targeted-boundary-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-targeted-boundary-d32.json"
OUTPUT = ARTIFACTS / "deetjen-dove-source-viscosity-targeted-boundary.json"

COMPONENTS = {
    "reflectedPopulation": "reflectedPopulationMeanForceNewtons",
    "movingWall": "movingWallMeanForceNewtons",
    "interpolationResidual": "interpolationResidualMeanForceNewtons",
    "topologyImpulse": "topologyImpulseMeanForceNewtons",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def xz(value: list[float]) -> tuple[float, float]:
    return float(value[0]), float(value[2])


def subtract(
    right: tuple[float, float], left: tuple[float, float]
) -> tuple[float, float]:
    return right[0] - left[0], right[1] - left[1]


def dot(left: tuple[float, float], right: tuple[float, float]) -> float:
    return left[0] * right[0] + left[1] * right[1]


def energy(values: list[tuple[float, float]]) -> float:
    return sum(dot(value, value) for value in values)


def normalized_rms(
    left: list[tuple[float, float]], right: list[tuple[float, float]]
) -> float:
    numerator = energy([subtract(r, l) for l, r in zip(left, right)])
    denominator = 0.5 * (energy(left) + energy(right))
    return math.sqrt(numerator / max(denominator, 1.0e-30))


def ledger(
    component_deltas: dict[str, list[tuple[float, float]]],
    indices: range,
) -> tuple[list[dict], float, float]:
    entries: list[dict] = []
    for name, values in component_deltas.items():
        value = sum(dot(values[index], values[index]) for index in indices)
        entries.append(
            {
                "name": name,
                "kind": "self",
                "signedSquaredDifferenceContribution": value,
            }
        )
    for first, second in itertools.combinations(component_deltas, 2):
        value = 2.0 * sum(
            dot(component_deltas[first][index], component_deltas[second][index])
            for index in indices
        )
        entries.append(
            {
                "name": f"{first} x {second}",
                "kind": "interaction",
                "signedSquaredDifferenceContribution": value,
            }
        )
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
    preregistration = load(PREREGISTRATION)
    d28 = load(D28)
    d32 = load(D32)
    if not (
        preregistration["passed"]
        and preregistration["schemaVersion"] == 2
        and d28["targetedCasePassed"]
        and d32["targetedCasePassed"]
        and d28["sourcePreregistrationSHA256"] == sha256(PREREGISTRATION)
        and d32["sourcePreregistrationSHA256"] == sha256(PREREGISTRATION)
        and d28["referenceLengthCells"]
        == preregistration["coarseReferenceLengthCells"]
        and d32["referenceLengthCells"]
        == preregistration["fineReferenceLengthCells"]
    ):
        raise SystemExit("both preregistered targeted cases must pass")

    bins28 = d28["componentBins"]
    bins32 = d32["componentBins"]
    if len(bins28) != len(bins32) or any(
        left["targetSampleIndex"] != right["targetSampleIndex"]
        or left["sourceTimeSeconds"] != right["sourceTimeSeconds"]
        for left, right in zip(bins28, bins32)
    ):
        raise SystemExit("D28/D32 targeted bins are not aligned")

    component_deltas: dict[str, list[tuple[float, float]]] = {}
    component_metrics = {}
    for name, key in COMPONENTS.items():
        force28 = [xz(item[key]) for item in bins28]
        force32 = [xz(item[key]) for item in bins32]
        component_deltas[name] = [
            subtract(right, left) for left, right in zip(force28, force32)
        ]
        component_metrics[name] = {
            "normalizedRMSDifference": normalized_rms(force28, force32),
            "squaredDifferenceEnergy": energy(component_deltas[name]),
        }

    production_delta = [
        subtract(
            xz(right["productionMeanForceNewtons"]),
            xz(left["productionMeanForceNewtons"]),
        )
        for left, right in zip(bins28, bins32)
    ]
    reconstructed_delta = []
    for index in range(len(bins28)):
        reconstructed_delta.append(
            (
                sum(values[index][0] for values in component_deltas.values()),
                sum(values[index][1] for values in component_deltas.values()),
            )
        )
    delta_closure = [
        subtract(reconstructed, production)
        for reconstructed, production in zip(reconstructed_delta, production_delta)
    ]
    total_energy = energy(production_delta)
    delta_closure_relative = math.sqrt(
        energy(delta_closure) / max(total_energy, energy(reconstructed_delta), 1e-30)
    )

    full_indices = range(len(bins28))
    split = len(bins28) // 2
    full_ledger, signed_total, absolute_total = ledger(
        component_deltas, full_indices
    )
    early_ledger, _, _ = ledger(component_deltas, range(0, split))
    late_ledger, _, _ = ledger(component_deltas, range(split, len(bins28)))
    energy_closure_relative = abs(signed_total - total_energy) / max(
        total_energy, abs(signed_total), 1e-30
    )
    leading = full_ledger[0]
    temporally_stable = (
        early_ledger[0]["name"] == leading["name"]
        and late_ledger[0]["name"] == leading["name"]
    )
    dominant = (
        leading["fractionOfAbsoluteLedger"]
        >= preregistration["minimumDominantContributionFraction"]
        and temporally_stable
    )
    attribution = {
        "classification": (
            f"dominant-{leading['kind']}:{leading['name']}"
            if dominant
            else "mixed-component-interaction"
        ),
        "dominantContributionAvailable": dominant,
        "leadingContributionName": leading["name"],
        "leadingContributionKind": leading["kind"],
        "leadingAbsoluteLedgerFraction": leading[
            "fractionOfAbsoluteLedger"
        ],
        "minimumDominantContributionFraction": preregistration[
            "minimumDominantContributionFraction"
        ],
        "sameLeaderInBothTemporalHalves": temporally_stable,
        "earlyLeader": early_ledger[0]["name"],
        "lateLeader": late_ledger[0]["name"],
    }

    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": (
            "deetjen-ob-f03-source-viscosity-targeted-boundary-attribution-v1"
        ),
        "generatedBy": "Scripts/analyze-dove-targeted-boundary-replay.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "sourceD28CaseSHA256": sha256(D28),
        "sourceD32CaseSHA256": sha256(D32),
        "targetSampleIndices": [
            item["targetSampleIndex"] for item in bins28
        ],
        "targetTimesSeconds": [item["sourceTimeSeconds"] for item in bins28],
        "componentMetrics": component_metrics,
        "productionD32MinusD28": [list(value) for value in production_delta],
        "componentD32MinusD28": {
            key: [list(value) for value in values]
            for key, values in component_deltas.items()
        },
        "squaredDifferenceEnergy": total_energy,
        "signedLedgerTotal": signed_total,
        "absoluteLedgerTotal": absolute_total,
        "componentDifferenceClosureRelativeRMS": delta_closure_relative,
        "squaredDifferenceEnergyClosureRelativeError": energy_closure_relative,
        "contributionLedger": full_ledger,
        "earlyContributionLedger": early_ledger,
        "lateContributionLedger": late_ledger,
        "attribution": attribution,
        "bothTargetedCasesPassed": True,
        "productionModificationAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "gridConvergenceGateApplied": False,
        "scientificVerdict": (
            f"The preregistered targeted replay identifies {leading['name']} "
            f"as a temporally stable >=50% {leading['kind']} contribution."
            if dominant
            else (
                "No single self or interaction contribution reaches the frozen "
                ">=50% threshold while remaining largest in both temporal halves; "
                "the localized D28/D32 load difference is mixed."
            )
        ),
        "nextAction": (
            "Design one narrowly isolated canonical for the identified mechanism "
            "before modifying production physics."
            if dominant
            else (
                "Use the signed interaction ledger to choose one minimal spatial "
                "or topology-conditioned discriminator; do not tune production "
                "physics from a mixed attribution."
            )
        ),
        "claimBoundary": preregistration["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

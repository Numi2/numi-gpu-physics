#!/usr/bin/env python3
"""Cross-apply conditioned D28/D32 reflected-link composition factors."""

from __future__ import annotations

import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-link-composition-discriminator-preregistration.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
SOURCE_ATTRIBUTION = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance.json"
)
OUTPUT = ARTIFACTS / "deetjen-dove-link-composition-discriminator.json"

FIELDS = (
    "partIdentifier",
    "directionIndex",
    "branch",
    "topologyClass",
    "linkFractionBin",
)
DIRECTIONS = (
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
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key(item: dict) -> tuple:
    return tuple(item[field] for field in FIELDS)


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
    return math.fsum(dot(value, value) for value in values)


def relative_rms(
    residuals: list[tuple[float, float]], references: list[tuple[float, float]]
) -> float:
    return math.sqrt(energy(residuals) / max(energy(references), 1e-30))


def infer_force_scale(strata: list[dict]) -> tuple[float, float]:
    values = []
    for item in strata:
        count = int(item["selectedLinkCount"])
        direction = DIRECTIONS[int(item["directionIndex"])]
        coefficient = item["coefficientVectorNewtonsPerPopulation"]
        if direction[0] != 0:
            values.append(-float(coefficient[0]) / (2.0 * count * direction[0]))
        elif direction[2] != 0:
            values.append(-float(coefficient[2]) / (2.0 * count * direction[2]))
    mean = math.fsum(values) / len(values)
    spread = max(abs(value - mean) for value in values) / max(abs(mean), 1e-30)
    return mean, spread


def conditional_tables(
    counts28: dict[tuple, int], counts32: dict[tuple, int]
) -> tuple[dict[int, dict[tuple[int, tuple], tuple[dict, bool, float]]], dict]:
    pooled = {
        item: counts28.get(item, 0) + counts32.get(item, 0)
        for item in set(counts28) | set(counts32)
    }
    tables = {28: {}, 32: {}}
    for depth in range(len(FIELDS)):
        pooled_children: dict[tuple, dict[object, int]] = defaultdict(
            lambda: defaultdict(int)
        )
        source_children = {
            28: defaultdict(lambda: defaultdict(int)),
            32: defaultdict(lambda: defaultdict(int)),
        }
        for item, count in pooled.items():
            pooled_children[item[:depth]][item[depth]] += count
        for label, counts in ((28, counts28), (32, counts32)):
            for item, count in counts.items():
                source_children[label][item[:depth]][item[depth]] += count
        for prefix, pooled_counts in pooled_children.items():
            for label in (28, 32):
                chosen = source_children[label].get(prefix)
                fallback = not chosen or sum(chosen.values()) == 0
                selected = pooled_counts if fallback else chosen
                denominator = math.fsum(selected.values())
                probabilities = {
                    child: count / denominator
                    for child, count in selected.items()
                    if count > 0
                }
                error = abs(math.fsum(probabilities.values()) - 1.0)
                tables[label][(depth, prefix)] = (
                    probabilities,
                    fallback,
                    error,
                )
    return tables, pooled


def hybrid_distribution(
    mask: int,
    tables: dict[int, dict[tuple[int, tuple], tuple[dict, bool, float]]],
) -> tuple[dict[tuple, float], float, float]:
    paths: dict[tuple, tuple[float, bool]] = {(): (1.0, False)}
    maximum_normalization_error = 0.0
    for depth in range(len(FIELDS)):
        label = 32 if mask & (1 << (depth + 1)) else 28
        next_paths: dict[tuple, tuple[float, bool]] = {}
        for prefix, (parent_probability, prior_fallback) in paths.items():
            probabilities, fallback, normalization_error = tables[label][
                (depth, prefix)
            ]
            maximum_normalization_error = max(
                maximum_normalization_error, normalization_error
            )
            for child, probability in sorted(
                probabilities.items(), key=lambda item: str(item[0])
            ):
                if probability > 0:
                    next_paths[prefix + (child,)] = (
                        parent_probability * probability,
                        prior_fallback or fallback,
                    )
        paths = next_paths
    distribution = {item: value[0] for item, value in paths.items()}
    total = math.fsum(distribution.values())
    maximum_normalization_error = max(
        maximum_normalization_error, abs(total - 1.0)
    )
    fallback_mass = math.fsum(
        probability
        for item, probability in distribution.items()
        if paths[item][1]
    )
    return distribution, fallback_mass, maximum_normalization_error


def state_force(
    mask: int,
    counts28: dict[tuple, int],
    counts32: dict[tuple, int],
    means28: dict[tuple, float],
    means32: dict[tuple, float],
    force_scale28: float,
    force_scale32: float,
    tables: dict[int, dict[tuple[int, tuple], tuple[dict, bool, float]]],
) -> tuple[tuple[float, float], float, float]:
    distribution, fallback_mass, normalization_error = hybrid_distribution(mask, tables)
    use32 = bool(mask & 1)
    count = math.fsum((counts32 if use32 else counts28).values())
    force_scale = force_scale32 if use32 else force_scale28
    measure_scale = -2.0 * force_scale * count
    total = (0.0, 0.0)
    for item, probability in distribution.items():
        mean = 0.5 * (means28.get(item, 0.0) + means32.get(item, 0.0))
        direction = DIRECTIONS[int(item[1])]
        total = add(
            total,
            scale(
                measure_scale * probability * mean,
                (float(direction[0]), float(direction[2])),
            ),
        )
    return total, fallback_mass, normalization_error


def direct_state(strata: list[dict], means_other: dict[tuple, float]) -> tuple[float, float]:
    total = (0.0, 0.0)
    for item in strata:
        item_key = key(item)
        mean = 0.5 * (
            float(item["reflectedPopulationMean"])
            + means_other.get(item_key, 0.0)
        )
        coefficient = item["coefficientVectorNewtonsPerPopulation"]
        total = add(total, scale(mean, (float(coefficient[0]), float(coefficient[2]))))
    return total


def shapley_values(states: dict[int, tuple[float, float]]) -> list[tuple[float, float]]:
    count = 6
    denominator = math.factorial(count)
    result = []
    for factor in range(count):
        value = (0.0, 0.0)
        for mask in range(1 << count):
            if mask & (1 << factor):
                continue
            size = mask.bit_count()
            weight = (
                math.factorial(size)
                * math.factorial(count - size - 1)
                / denominator
            )
            increment = subtract(
                states[mask | (1 << factor)], states[mask]
            )
            value = add(value, scale(weight, increment))
        result.append(value)
    return result


def ledger(
    factor_vectors: dict[str, list[tuple[float, float]]],
    deltas: list[tuple[float, float]],
    indices: range,
) -> tuple[list[dict], float, float]:
    entries = []
    for name, values in factor_vectors.items():
        contribution = math.fsum(dot(values[index], deltas[index]) for index in indices)
        entries.append(
            {
                "name": name,
                "signedSquaredDifferenceContribution": contribution,
            }
        )
    signed_total = math.fsum(item["signedSquaredDifferenceContribution"] for item in entries)
    absolute_total = math.fsum(abs(item["signedSquaredDifferenceContribution"]) for item in entries)
    for item in entries:
        contribution = item["signedSquaredDifferenceContribution"]
        item["fractionOfSignedTotal"] = contribution / max(signed_total, 1e-30)
        item["fractionOfAbsoluteLedger"] = abs(contribution) / max(absolute_total, 1e-30)
    entries.sort(key=lambda item: item["fractionOfAbsoluteLedger"], reverse=True)
    return entries, signed_total, absolute_total


def main() -> None:
    prereg = load(PREREGISTRATION)
    d28 = load(D28)
    d32 = load(D32)
    source = load(SOURCE_ATTRIBUTION)
    prereg_sha = sha256(PREREGISTRATION)
    if not (
        prereg["schemaVersion"] == 1
        and prereg["passed"]
        and prereg["sourceD28ProvenanceSHA256"] == sha256(D28)
        and prereg["sourceD32ProvenanceSHA256"] == sha256(D32)
        and prereg["sourceProvenanceAttributionSHA256"] == sha256(SOURCE_ATTRIBUTION)
        and d28["provenanceCasePassed"]
        and d32["provenanceCasePassed"]
        and source["populationCompositionClosurePassed"]
    ):
        raise SystemExit("locked provenance inputs are invalid")

    endpoints28 = d28["endpoints"]
    endpoints32 = d32["endpoints"]
    source_endpoints = source["endpoints"]
    if not (
        len(endpoints28) == len(endpoints32) == len(source_endpoints) == 11
        and all(
            left["targetSampleIndex"] == right["targetSampleIndex"]
            == prior["targetSampleIndex"]
            for left, right, prior in zip(endpoints28, endpoints32, source_endpoints)
        )
    ):
        raise SystemExit("composition endpoints are not aligned")

    factor_names = prereg["factorOrder"]
    factor_vectors = {name: [] for name in factor_names}
    deltas = []
    reconstruction_residuals = []
    reconstruction_references = []
    source_residuals = []
    shapley_residuals = []
    maximum_fallback_mass = 0.0
    maximum_normalization_error = 0.0
    maximum_force_scale_spread = 0.0
    endpoint_reports = []
    for endpoint28, endpoint32, prior in zip(
        endpoints28, endpoints32, source_endpoints
    ):
        strata28 = endpoint28["strata"]
        strata32 = endpoint32["strata"]
        counts28 = {key(item): int(item["selectedLinkCount"]) for item in strata28}
        counts32 = {key(item): int(item["selectedLinkCount"]) for item in strata32}
        means28 = {key(item): float(item["reflectedPopulationMean"]) for item in strata28}
        means32 = {key(item): float(item["reflectedPopulationMean"]) for item in strata32}
        force_scale28, spread28 = infer_force_scale(strata28)
        force_scale32, spread32 = infer_force_scale(strata32)
        tables, _ = conditional_tables(counts28, counts32)
        maximum_force_scale_spread = max(
            maximum_force_scale_spread, spread28, spread32
        )
        states = {}
        fallback_by_mask = {}
        for mask in range(64):
            value, fallback_mass, normalization_error = state_force(
                mask,
                counts28,
                counts32,
                means28,
                means32,
                force_scale28,
                force_scale32,
                tables,
            )
            states[mask] = value
            fallback_by_mask[mask] = fallback_mass
            maximum_fallback_mass = max(maximum_fallback_mass, fallback_mass)
            maximum_normalization_error = max(
                maximum_normalization_error, normalization_error
            )
        direct28 = direct_state(strata28, means32)
        direct32 = direct_state(strata32, means28)
        reconstruction_residuals.extend(
            [subtract(states[0], direct28), subtract(states[63], direct32)]
        )
        reconstruction_references.extend([direct28, direct32])
        delta = subtract(states[63], states[0])
        deltas.append(delta)
        prior_delta = tuple(float(value) for value in prior["linkCompositionD32MinusD28"])
        source_residuals.append(subtract(delta, prior_delta))
        phi = shapley_values(states)
        reconstructed_delta = (0.0, 0.0)
        for name, value in zip(factor_names, phi):
            factor_vectors[name].append(value)
            reconstructed_delta = add(reconstructed_delta, value)
        shapley_residuals.append(subtract(reconstructed_delta, delta))
        one_factor = {
            factor_names[index]: list(subtract(states[1 << index], states[0]))
            for index in range(6)
        }
        endpoint_reports.append(
            {
                "targetSampleIndex": endpoint28["targetSampleIndex"],
                "sourceTimeSeconds": endpoint28["sourceTimeSeconds"],
                "d28SelectedLinkCount": sum(counts28.values()),
                "d32SelectedLinkCount": sum(counts32.values()),
                "d28PhysicalPerLinkForceScale": force_scale28,
                "d32PhysicalPerLinkForceScale": force_scale32,
                "d28CompositionStateNewtons": list(states[0]),
                "d32CompositionStateNewtons": list(states[63]),
                "compositionD32MinusD28Newtons": list(delta),
                "factorShapleyD32MinusD28Newtons": {
                    name: list(value) for name, value in zip(factor_names, phi)
                },
                "oneFactorFromD28CounterfactualNewtons": one_factor,
                "maximumPooledFallbackProbabilityMass": max(
                    fallback_by_mask.values()
                ),
            }
        )

    state_reconstruction = relative_rms(
        reconstruction_residuals, reconstruction_references
    )
    source_reproduction = relative_rms(source_residuals, deltas)
    shapley_closure = relative_rms(shapley_residuals, deltas)
    full, signed_total, absolute_total = ledger(
        factor_vectors, deltas, range(len(deltas))
    )
    split = len(deltas) // 2
    early, _, _ = ledger(factor_vectors, deltas, range(split))
    late, _, _ = ledger(factor_vectors, deltas, range(split, len(deltas)))
    total_energy = energy(deltas)
    energy_closure = abs(signed_total - total_energy) / max(
        abs(signed_total), total_energy, 1e-30
    )
    leading = full[0]
    stable = early[0]["name"] == leading["name"] == late[0]["name"]
    dominant = (
        leading["fractionOfAbsoluteLedger"]
        >= prereg["minimumDominantContributionFraction"]
        and stable
    )
    gates = {
        "endpointStateReconstruction": state_reconstruction
        <= prereg["maximumEndpointStateReconstructionRelativeRMS"],
        "sourceCompositionDifferenceReproduction": source_reproduction
        <= prereg["maximumEndpointStateReconstructionRelativeRMS"],
        "shapleyForceClosure": shapley_closure
        <= prereg["maximumShapleyForceClosureRelativeRMS"],
        "energyClosure": energy_closure
        <= prereg["maximumEnergyClosureRelativeError"],
        "conditionalNormalization": maximum_normalization_error
        <= prereg["maximumConditionalNormalizationError"],
        "pooledFallbackBound": maximum_fallback_mass
        <= prereg["maximumPooledFallbackProbabilityMass"],
        "forceScaleConsistency": maximum_force_scale_spread <= 1e-12,
    }
    passed = all(gates.values())
    classification = (
        f"dominant-conditioned-factor:{leading['name']}"
        if passed and dominant
        else "mixed-conditioned-link-composition"
    )
    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": "deetjen-ob-f03-link-composition-shapley-discriminator-v1",
        "generatedBy": "Scripts/analyze-dove-link-composition-discriminator.py",
        "preregistrationSHA256": prereg_sha,
        "sourceD28ProvenanceSHA256": sha256(D28),
        "sourceD32ProvenanceSHA256": sha256(D32),
        "sourceProvenanceAttributionSHA256": sha256(SOURCE_ATTRIBUTION),
        "factorOrder": factor_names,
        "targetSampleIndices": [item["targetSampleIndex"] for item in endpoints28],
        "endpoints": endpoint_reports,
        "factorShapleyD32MinusD28Newtons": {
            name: [list(value) for value in values]
            for name, values in factor_vectors.items()
        },
        "compositionD32MinusD28Newtons": [list(value) for value in deltas],
        "endpointStateReconstructionRelativeRMS": state_reconstruction,
        "sourceCompositionDifferenceReproductionRelativeRMS": source_reproduction,
        "shapleyForceClosureRelativeRMS": shapley_closure,
        "squaredDifferenceEnergy": total_energy,
        "signedLedgerTotal": signed_total,
        "absoluteLedgerTotal": absolute_total,
        "energyClosureRelativeError": energy_closure,
        "maximumConditionalNormalizationError": maximum_normalization_error,
        "maximumPooledFallbackProbabilityMass": maximum_fallback_mass,
        "maximumForceScaleRelativeSpread": maximum_force_scale_spread,
        "contributionLedger": full,
        "earlyContributionLedger": early,
        "lateContributionLedger": late,
        "attribution": {
            "classification": classification,
            "dominantFactorAvailable": passed and dominant,
            "leadingFactor": leading["name"],
            "leadingAbsoluteLedgerFraction": leading["fractionOfAbsoluteLedger"],
            "minimumDominantContributionFraction": prereg["minimumDominantContributionFraction"],
            "sameLeaderInBothTemporalHalves": stable,
            "earlyLeader": early[0]["name"],
            "lateLeader": late[0]["name"],
        },
        "gates": gates,
        "analysisPassed": passed,
        "fluidEvolutionExecuted": False,
        "minimalCanonicalAuthorized": passed and dominant,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "scientificVerdict": (
            f"The frozen conditional Shapley ledger identifies {leading['name']} "
            f"as a temporally stable >=50% link-composition factor."
            if passed and dominant
            else (
                "No conditioned factor reaches the frozen >=50% threshold while "
                "leading both temporal halves, or a numerical/fallback gate failed."
            )
        ),
        "nextAction": (
            f"Preregister one minimal canonical that isolates {leading['name']}; "
            "do not modify production physics."
            if passed and dominant
            else (
                "Do not build a mechanism-specific canonical; inspect the failed "
                "gate or retain a mixed composition classification."
            )
        ),
        "claimBoundary": prereg["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        failed = [name for name, value in gates.items() if not value]
        raise SystemExit("link-composition discriminator failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

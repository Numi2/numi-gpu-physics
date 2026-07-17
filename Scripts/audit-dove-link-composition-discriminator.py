#!/usr/bin/env python3
"""Independently reconstruct the conditioned link-composition discriminator."""

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
SOURCE = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance.json"
REPORT = ARTIFACTS / "deetjen-dove-link-composition-discriminator.json"
OUTPUT = ARTIFACTS / "deetjen-dove-link-composition-discriminator-audit.json"

FIELDS = (
    "partIdentifier",
    "directionIndex",
    "branch",
    "topologyClass",
    "linkFractionBin",
)
DIRECTIONS = (
    (0, 0, 0), (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0),
    (0, 0, 1), (0, 0, -1), (1, 1, 0), (-1, -1, 0),
    (1, -1, 0), (-1, 1, 0), (1, 0, 1), (-1, 0, -1),
    (1, 0, -1), (-1, 0, 1), (0, 1, 1), (0, -1, -1),
    (0, 1, -1), (0, -1, 1),
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def item_key(item: dict) -> tuple:
    return tuple(item[field] for field in FIELDS)


def close(left: float, right: float, tolerance: float = 1e-10) -> bool:
    return abs(left - right) <= tolerance * max(abs(left), abs(right), 1.0)


def vector_close(left: tuple, right: list, tolerance: float = 1e-10) -> bool:
    return all(close(float(a), float(b), tolerance) for a, b in zip(left, right))


def infer_scale(strata: list[dict]) -> tuple[float, float]:
    scales = []
    for item in strata:
        count = int(item["selectedLinkCount"])
        direction = DIRECTIONS[int(item["directionIndex"])]
        coefficient = item["coefficientVectorNewtonsPerPopulation"]
        component = 0 if direction[0] else 2
        scales.append(
            -float(coefficient[component])
            / (2.0 * count * direction[component])
        )
    mean = math.fsum(scales) / len(scales)
    spread = max(abs(value - mean) for value in scales) / abs(mean)
    return mean, spread


def make_tables(counts28: dict, counts32: dict) -> dict:
    pooled = {
        key: counts28.get(key, 0) + counts32.get(key, 0)
        for key in set(counts28) | set(counts32)
    }
    tables = {28: {}, 32: {}}
    for depth in range(5):
        for label, counts in ((28, counts28), (32, counts32)):
            source = defaultdict(lambda: defaultdict(int))
            pooled_source = defaultdict(lambda: defaultdict(int))
            for key, count in counts.items():
                source[key[:depth]][key[depth]] += count
            for key, count in pooled.items():
                pooled_source[key[:depth]][key[depth]] += count
            for prefix, pooled_children in pooled_source.items():
                selected = source[prefix]
                fallback = not selected or sum(selected.values()) == 0
                children = pooled_children if fallback else selected
                total = math.fsum(children.values())
                probabilities = {
                    child: count / total for child, count in children.items()
                }
                tables[label][(depth, prefix)] = (
                    probabilities,
                    fallback,
                    abs(math.fsum(probabilities.values()) - 1.0),
                )
    return tables


def distribution(mask: int, tables: dict) -> tuple[dict, float, float]:
    states = {(): (1.0, False)}
    normalization = 0.0
    for depth in range(5):
        label = 32 if mask & (1 << (depth + 1)) else 28
        updated = {}
        for prefix, (parent, used_fallback) in states.items():
            probabilities, fallback, error = tables[label][(depth, prefix)]
            normalization = max(normalization, error)
            for child, probability in probabilities.items():
                updated[prefix + (child,)] = (
                    parent * probability,
                    used_fallback or fallback,
                )
        states = updated
    probabilities = {key: value[0] for key, value in states.items()}
    normalization = max(
        normalization, abs(math.fsum(probabilities.values()) - 1.0)
    )
    fallback_mass = math.fsum(
        probability
        for key, probability in probabilities.items()
        if states[key][1]
    )
    return probabilities, fallback_mass, normalization


def force(
    mask: int,
    counts28: dict,
    counts32: dict,
    means28: dict,
    means32: dict,
    scale28: float,
    scale32: float,
    tables: dict,
) -> tuple[tuple[float, float], float, float]:
    probabilities, fallback, normalization = distribution(mask, tables)
    selected32 = bool(mask & 1)
    counts = counts32 if selected32 else counts28
    coefficient = -2.0 * (scale32 if selected32 else scale28) * sum(counts.values())
    x_terms = []
    z_terms = []
    for key, probability in probabilities.items():
        mean = 0.5 * (means28.get(key, 0.0) + means32.get(key, 0.0))
        direction = DIRECTIONS[int(key[1])]
        x_terms.append(coefficient * probability * mean * direction[0])
        z_terms.append(coefficient * probability * mean * direction[2])
    return (math.fsum(x_terms), math.fsum(z_terms)), fallback, normalization


def shapley(states: dict[int, tuple[float, float]]) -> list[tuple[float, float]]:
    values = []
    for factor in range(6):
        x_terms = []
        z_terms = []
        for mask in range(64):
            if mask & (1 << factor):
                continue
            size = mask.bit_count()
            weight = math.factorial(size) * math.factorial(5 - size) / math.factorial(6)
            before = states[mask]
            after = states[mask | (1 << factor)]
            x_terms.append(weight * (after[0] - before[0]))
            z_terms.append(weight * (after[1] - before[1]))
        values.append((math.fsum(x_terms), math.fsum(z_terms)))
    return values


def contribution_ledger(
    factor_names: list[str],
    vectors: list[list[tuple[float, float]]],
    deltas: list[tuple[float, float]],
    indices: range,
) -> list[tuple[str, float]]:
    result = []
    for name, values in zip(factor_names, vectors):
        value = math.fsum(
            values[index][0] * deltas[index][0]
            + values[index][1] * deltas[index][1]
            for index in indices
        )
        result.append((name, value))
    result.sort(key=lambda item: abs(item[1]), reverse=True)
    return result


def main() -> None:
    prereg = load(PREREGISTRATION)
    d28 = load(D28)
    d32 = load(D32)
    source = load(SOURCE)
    report = load(REPORT)
    factor_names = prereg["factorOrder"]
    endpoint_vectors = [[] for _ in factor_names]
    deltas = []
    reconstruction_residual = []
    reconstruction_reference = []
    source_residual = []
    closure_residual = []
    maximum_fallback = 0.0
    maximum_normalization = 0.0
    maximum_scale_spread = 0.0
    endpoint_match = True

    for endpoint28, endpoint32, source_endpoint, report_endpoint in zip(
        d28["endpoints"], d32["endpoints"], source["endpoints"], report["endpoints"]
    ):
        strata28 = endpoint28["strata"]
        strata32 = endpoint32["strata"]
        counts28 = {item_key(item): int(item["selectedLinkCount"]) for item in strata28}
        counts32 = {item_key(item): int(item["selectedLinkCount"]) for item in strata32}
        means28 = {item_key(item): float(item["reflectedPopulationMean"]) for item in strata28}
        means32 = {item_key(item): float(item["reflectedPopulationMean"]) for item in strata32}
        scale28, spread28 = infer_scale(strata28)
        scale32, spread32 = infer_scale(strata32)
        maximum_scale_spread = max(maximum_scale_spread, spread28, spread32)
        tables = make_tables(counts28, counts32)
        states = {}
        for mask in range(64):
            states[mask], fallback, normalization = force(
                mask, counts28, counts32, means28, means32, scale28, scale32, tables
            )
            maximum_fallback = max(maximum_fallback, fallback)
            maximum_normalization = max(maximum_normalization, normalization)
        direct = []
        for strata, other_means in ((strata28, means32), (strata32, means28)):
            x_terms = []
            z_terms = []
            for item in strata:
                mean = 0.5 * (
                    float(item["reflectedPopulationMean"])
                    + other_means.get(item_key(item), 0.0)
                )
                coefficient = item["coefficientVectorNewtonsPerPopulation"]
                x_terms.append(mean * float(coefficient[0]))
                z_terms.append(mean * float(coefficient[2]))
            direct.append((math.fsum(x_terms), math.fsum(z_terms)))
        reconstruction_residual.extend(
            [
                (states[0][0] - direct[0][0], states[0][1] - direct[0][1]),
                (states[63][0] - direct[1][0], states[63][1] - direct[1][1]),
            ]
        )
        reconstruction_reference.extend(direct)
        delta = (states[63][0] - states[0][0], states[63][1] - states[0][1])
        deltas.append(delta)
        prior = source_endpoint["linkCompositionD32MinusD28"]
        source_residual.append((delta[0] - prior[0], delta[1] - prior[1]))
        values = shapley(states)
        for index, value in enumerate(values):
            endpoint_vectors[index].append(value)
        summed = (
            math.fsum(value[0] for value in values),
            math.fsum(value[1] for value in values),
        )
        closure_residual.append((summed[0] - delta[0], summed[1] - delta[1]))
        endpoint_match = endpoint_match and (
            report_endpoint["targetSampleIndex"] == endpoint28["targetSampleIndex"]
            and vector_close(report_endpoint["compositionD32MinusD28Newtons"], delta)
            and all(
                vector_close(
                    report_endpoint["factorShapleyD32MinusD28Newtons"][name],
                    value,
                )
                for name, value in zip(factor_names, values)
            )
        )

    def rms(residuals: list[tuple], references: list[tuple]) -> float:
        numerator = math.fsum(a * a + b * b for a, b in residuals)
        denominator = math.fsum(a * a + b * b for a, b in references)
        return math.sqrt(numerator / max(denominator, 1e-30))

    reconstruction = rms(reconstruction_residual, reconstruction_reference)
    source_reproduction = rms(source_residual, deltas)
    shapley_closure = rms(closure_residual, deltas)
    full = contribution_ledger(factor_names, endpoint_vectors, deltas, range(11))
    early = contribution_ledger(factor_names, endpoint_vectors, deltas, range(5))
    late = contribution_ledger(factor_names, endpoint_vectors, deltas, range(5, 11))
    total_energy = math.fsum(x * x + z * z for x, z in deltas)
    signed_total = math.fsum(value for _, value in full)
    absolute_total = math.fsum(abs(value) for _, value in full)
    energy_closure = abs(signed_total - total_energy) / max(total_energy, abs(signed_total), 1e-30)
    leading_fraction = abs(full[0][1]) / max(absolute_total, 1e-30)
    stable = full[0][0] == early[0][0] == late[0][0]
    dominant = (
        leading_fraction >= prereg["minimumDominantContributionFraction"] and stable
    )
    report_ledger = {item["name"]: item for item in report["contributionLedger"]}

    checks = {
        "sourceHashes": (
            report["preregistrationSHA256"] == sha256(PREREGISTRATION)
            and report["sourceD28ProvenanceSHA256"] == sha256(D28)
            and report["sourceD32ProvenanceSHA256"] == sha256(D32)
            and report["sourceProvenanceAttributionSHA256"] == sha256(SOURCE)
        ),
        "sourceCaseGates": d28["provenanceCasePassed"] and d32["provenanceCasePassed"],
        "sourceCompositionGate": source["populationCompositionClosurePassed"],
        "endpointAlignment": report["targetSampleIndices"] == list(range(50, 61)),
        "d3q19ScaleConsistency": maximum_scale_spread <= 1e-12,
        "endpointStateReconstruction": close(
            reconstruction, report["endpointStateReconstructionRelativeRMS"]
        ) and reconstruction <= prereg["maximumEndpointStateReconstructionRelativeRMS"],
        "sourceDifferenceReproduction": close(
            source_reproduction, report["sourceCompositionDifferenceReproductionRelativeRMS"]
        ) and source_reproduction <= prereg["maximumEndpointStateReconstructionRelativeRMS"],
        "conditionalNormalization": close(
            maximum_normalization, report["maximumConditionalNormalizationError"]
        ) and maximum_normalization <= prereg["maximumConditionalNormalizationError"],
        "pooledFallbackBound": close(
            maximum_fallback, report["maximumPooledFallbackProbabilityMass"]
        ) and maximum_fallback <= prereg["maximumPooledFallbackProbabilityMass"],
        "shapleyForceClosure": close(
            shapley_closure, report["shapleyForceClosureRelativeRMS"]
        ) and shapley_closure <= prereg["maximumShapleyForceClosureRelativeRMS"],
        "endpointFactorVectors": endpoint_match,
        "energyClosure": close(energy_closure, report["energyClosureRelativeError"])
        and energy_closure <= prereg["maximumEnergyClosureRelativeError"],
        "sixFactorLedger": len(full) == len(report_ledger) == 6
        and all(
            name in report_ledger
            and close(value, report_ledger[name]["signedSquaredDifferenceContribution"])
            for name, value in full
        ),
        "leadingFactor": (
            report["attribution"]["leadingFactor"] == full[0][0]
            and close(
                report["attribution"]["leadingAbsoluteLedgerFraction"],
                leading_fraction,
            )
        ),
        "temporalHalves": (
            report["attribution"]["earlyLeader"] == early[0][0]
            and report["attribution"]["lateLeader"] == late[0][0]
            and report["attribution"]["sameLeaderInBothTemporalHalves"] == stable
        ),
        "frozenDominanceRule": (
            report["attribution"]["dominantFactorAvailable"] == dominant
            and report["attribution"]["classification"]
            == (f"dominant-conditioned-factor:{full[0][0]}" if dominant else "mixed-conditioned-link-composition")
        ),
        "analysisGate": report["analysisPassed"] and all(report["gates"].values()),
        "claimBoundary": (
            not report["fluidEvolutionExecuted"]
            and not report["productionModificationAuthorized"]
            and not report["d36RunAuthorized"]
            and not report["gridConvergenceGateApplied"]
            and not report["experimentalAgreementGateApplied"]
            and report["claimBoundary"] == prereg["claimBoundary"]
        ),
    }
    all_passed = all(checks.values())
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-link-composition-shapley-audit-v1",
        "generatedBy": "Scripts/audit-dove-link-composition-discriminator.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "d28ProvenanceSHA256": sha256(D28),
        "d32ProvenanceSHA256": sha256(D32),
        "sourceAttributionSHA256": sha256(SOURCE),
        "reportSHA256": sha256(REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": all_passed,
        "independentReconstruction": {
            "endpointStateReconstructionRelativeRMS": reconstruction,
            "sourceCompositionDifferenceReproductionRelativeRMS": source_reproduction,
            "shapleyForceClosureRelativeRMS": shapley_closure,
            "energyClosureRelativeError": energy_closure,
            "maximumConditionalNormalizationError": maximum_normalization,
            "maximumPooledFallbackProbabilityMass": maximum_fallback,
            "leadingFactor": full[0][0],
            "leadingAbsoluteLedgerFraction": leading_fraction,
            "earlyLeader": early[0][0],
            "lateLeader": late[0][0],
            "dominantFactorAvailable": dominant,
        },
        "fluidEvolutionExecuted": False,
        "productionModificationAuthorized": False,
        "claimBoundary": (
            "This independent audit reconstructs the 64 hybrid states, six "
            "force Shapley vectors, energy allocation, temporal leaders, source "
            "hashes, fallback bound, and safety boundary. It does not establish "
            "a boundary defect or authorize production changes."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not all_passed:
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("link-composition audit failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

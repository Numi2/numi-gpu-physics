#!/usr/bin/env python3
"""Independently rebuild the archive-only D12/D16 force covariance result."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
SOURCE_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force-preregistration.json"
SOURCE_REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force.json"
SOURCE_AUDIT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-distributed-force-audit.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-force-covariance-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-force-covariance.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-force-covariance-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def add(first: list[float], second: list[float]) -> list[float]:
    return [a + b for a, b in zip(first, second)]


def sub(first: list[float], second: list[float]) -> list[float]:
    return [a - b for a, b in zip(first, second)]


def dot(first: list[float], second: list[float]) -> float:
    return sum(a * b for a, b in zip(first, second))


def squared(value: list[float]) -> float:
    return dot(value, value)


def magnitude(value: list[float]) -> float:
    return math.sqrt(squared(value))


def mean_vector(values: list[list[float]]) -> list[float]:
    return [sum(value[index] for value in values) / len(values) for index in range(3)]


def mean_squared(values: list[list[float]]) -> float:
    return sum(squared(value) for value in values) / len(values)


def mean_dot(first: list[list[float]], second: list[list[float]], start: int, end: int) -> float:
    return sum(dot(first[index], second[index]) for index in range(start, end)) / (end - start)


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(float(first) - float(second)) <= tolerance * max(
        abs(float(first)), abs(float(second)), 1.0
    )


def vclose(first: list[float], second: list[float], tolerance: float = 2e-9) -> bool:
    return len(first) == len(second) and all(close(a, b, tolerance) for a, b in zip(first, second))


def sign(value: float) -> str:
    return "canceling" if value < 0 else "coherent" if value > 0 else "neutral"


def main() -> None:
    source_prereg = load(SOURCE_PREREG_PATH)
    source = load(SOURCE_REPORT_PATH)
    source_audit = load(SOURCE_AUDIT_PATH)
    prereg = load(PREREG_PATH)
    report = load(REPORT_PATH)
    metrics = report["metrics"]
    checks: dict[str, bool] = {}

    source_hashes = [
        sha256(SOURCE_PREREG_PATH),
        sha256(SOURCE_REPORT_PATH),
        sha256(SOURCE_AUDIT_PATH),
    ]
    source_hash_fields = [
        "sourceDistributedForcePreregistrationSHA256",
        "sourceDistributedForceReportSHA256",
        "sourceDistributedForceAuditSHA256",
    ]
    checks["sourceHashesMatch"] = all(
        prereg[field] == digest and report[field] == digest
        for field, digest in zip(source_hash_fields, source_hashes)
    ) and report["sourcePreregistrationSHA256"] == sha256(PREREG_PATH)
    checks["sourceEvidencePassed"] = all([
        source_prereg["passed"], source["sourceReproductionPassed"],
        source["classification"] == "mixed-term-distributed-grid-bias",
        not source["metrics"]["dominantTermGatePassed"],
        source_audit["allChecksPassed"],
    ])
    terms = ["base-reflection", "moving-wall", "interpolation-residual"]
    checks["preregisteredContractMatches"] = all([
        prereg["schemaVersion"] == 1,
        prereg["temporalBinCount"] == 24,
        prereg["blockCount"] == 3,
        prereg["binsPerBlock"] == 8,
        prereg["termIdentifiers"] == terms,
        prereg["maximumAllowedTermDeltaReconstructionErrorNewtons"] == 5e-6,
        prereg["maximumAllowedRelativeEnergyClosureError"] == 1e-5,
        prereg["minimumDominantPairFullEnergyFraction"] == 0.5,
        prereg["minimumDominantPairBlockEnergyFraction"] == 0.3,
        prereg["minimumMechanismDecompositionFraction"] == 0.6,
        prereg["passed"], not prereg["experimentalAgreementGateApplied"],
    ])

    d12 = source["d12"]["temporalBins"]
    d16 = source["d16"]["temporalBins"]
    field = {
        "base-reflection": "reflectedMeanForceNewtons",
        "moving-wall": "movingWallMeanForceNewtons",
        "interpolation-residual": "interpolationResidualMeanForceNewtons",
    }
    deltas = {
        identifier: [sub(second[name], first[name]) for first, second in zip(d12, d16)]
        for identifier, name in field.items()
    }
    total = [
        sub(second["reconstructedTotalMeanForceNewtons"], first["reconstructedTotalMeanForceNewtons"])
        for first, second in zip(d12, d16)
    ]
    reconstructed = [
        add(add(deltas[terms[0]][index], deltas[terms[1]][index]), deltas[terms[2]][index])
        for index in range(24)
    ]
    maximum_reconstruction = max(magnitude(sub(a, b)) for a, b in zip(reconstructed, total))
    total_mean = mean_vector(total)
    total_centered = [sub(value, total_mean) for value in total]
    total_energy = mean_squared(total)
    total_variance = mean_squared(total_centered)
    total_mean_energy = squared(total_mean)
    term_means = {identifier: mean_vector(deltas[identifier]) for identifier in terms}
    centered = {
        identifier: [sub(value, term_means[identifier]) for value in deltas[identifier]]
        for identifier in terms
    }
    raw_self = {identifier: mean_squared(deltas[identifier]) for identifier in terms}
    centered_self = {identifier: mean_squared(centered[identifier]) for identifier in terms}

    rebuilt_terms = []
    for identifier in terms:
        rebuilt_terms.append({
            "termIdentifier": identifier,
            "meanDeltaForceNewtons": term_means[identifier],
            "deltaRMSNewtons": math.sqrt(raw_self[identifier]),
            "centeredDeltaRMSNewtons": math.sqrt(centered_self[identifier]),
            "rawSelfEnergyFraction": raw_self[identifier] / max(total_energy, 1e-30),
        })
    reported_terms = {item["termIdentifier"]: item for item in metrics["terms"]}
    checks["termMetricsReproduce"] = all(
        vclose(item["meanDeltaForceNewtons"], reported_terms[item["termIdentifier"]]["meanDeltaForceNewtons"])
        and all(close(item[name], reported_terms[item["termIdentifier"]][name]) for name in (
            "deltaRMSNewtons", "centeredDeltaRMSNewtons", "rawSelfEnergyFraction",
        ))
        for item in rebuilt_terms
    )

    blocks = [(0, 8), (8, 16), (16, 24)]
    rebuilt_pairs = []
    raw_dots = []
    centered_dots = []
    mean_dots = []
    for first_index in range(2):
        for second_index in range(first_index + 1, 3):
            first = terms[first_index]
            second = terms[second_index]
            raw = mean_dot(deltas[first], deltas[second], 0, 24)
            covariance = mean_dot(centered[first], centered[second], 0, 24)
            mean_contribution = dot(term_means[first], term_means[second])
            block_fractions = []
            for start, end in blocks:
                block_total_energy = sum(squared(total[index]) for index in range(start, end)) / (end - start)
                block_fractions.append(
                    2 * mean_dot(deltas[first], deltas[second], start, end)
                    / max(block_total_energy, 1e-30)
                )
            absolute_decomposition = abs(covariance) + abs(mean_contribution)
            raw_dots.append(raw)
            centered_dots.append(covariance)
            mean_dots.append(mean_contribution)
            rebuilt_pairs.append({
                "pairIdentifier": f"{first}+{second}",
                "firstTermIdentifier": first,
                "secondTermIdentifier": second,
                "rawDotMeanNewtonsSquared": raw,
                "rawInteractionEnergyFraction": 2 * raw / max(total_energy, 1e-30),
                "centeredCovarianceTraceNewtonsSquared": covariance,
                "centeredInteractionEnergyFraction": 2 * covariance / max(total_energy, 1e-30),
                "meanDotNewtonsSquared": mean_contribution,
                "meanInteractionEnergyFraction": 2 * mean_contribution / max(total_energy, 1e-30),
                "maximumAbsoluteInteractionDecompositionErrorNewtonsSquared": abs(raw - covariance - mean_contribution),
                "blockRawInteractionEnergyFractions": block_fractions,
                "blockSigns": [sign(value) for value in block_fractions],
                "signConsistentAcrossBlocks": len(set(sign(value) for value in block_fractions)) == 1,
                "centeredShareOfAbsoluteDecomposition": abs(covariance) / max(absolute_decomposition, 1e-30),
                "meanShareOfAbsoluteDecomposition": abs(mean_contribution) / max(absolute_decomposition, 1e-30),
            })
    reported_pairs = {item["pairIdentifier"]: item for item in metrics["pairs"]}
    scalar_pair_fields = (
        "rawDotMeanNewtonsSquared", "rawInteractionEnergyFraction",
        "centeredCovarianceTraceNewtonsSquared", "centeredInteractionEnergyFraction",
        "meanDotNewtonsSquared", "meanInteractionEnergyFraction",
        "maximumAbsoluteInteractionDecompositionErrorNewtonsSquared",
        "centeredShareOfAbsoluteDecomposition", "meanShareOfAbsoluteDecomposition",
    )
    checks["pairMetricsReproduce"] = all(
        all(close(item[name], reported_pairs[item["pairIdentifier"]][name]) for name in scalar_pair_fields)
        and all(close(a, b) for a, b in zip(item["blockRawInteractionEnergyFractions"], reported_pairs[item["pairIdentifier"]]["blockRawInteractionEnergyFractions"]))
        and item["blockSigns"] == reported_pairs[item["pairIdentifier"]]["blockSigns"]
        and item["signConsistentAcrossBlocks"] == reported_pairs[item["pairIdentifier"]]["signConsistentAcrossBlocks"]
        for item in rebuilt_pairs
    )

    raw_rebuilt = sum(raw_self.values()) + 2 * sum(raw_dots)
    centered_rebuilt = sum(centered_self.values()) + 2 * sum(centered_dots)
    mean_rebuilt = sum(squared(value) for value in term_means.values()) + 2 * sum(mean_dots)
    raw_closure = abs(raw_rebuilt - total_energy) / max(total_energy, 1e-30)
    centered_closure = abs(centered_rebuilt - total_variance) / max(total_variance, 1e-30)
    mean_closure = abs(mean_rebuilt - total_mean_energy) / max(total_mean_energy, 1e-30)
    checks["energyIdentitiesReproduce"] = all([
        close(maximum_reconstruction, metrics["maximumTermDeltaReconstructionErrorNewtons"]),
        close(total_energy, metrics["totalDeltaMeanSquaredNewtonsSquared"]),
        close(total_variance, metrics["totalDeltaVarianceNewtonsSquared"]),
        close(total_mean_energy, metrics["totalMeanDeltaSquaredNewtonsSquared"]),
        close(raw_closure, metrics["rawEnergyClosureRelativeError"]),
        close(centered_closure, metrics["centeredEnergyClosureRelativeError"]),
        close(mean_closure, metrics["meanEnergyClosureRelativeError"]),
    ])
    checks["closureGatesPass"] = all([
        maximum_reconstruction <= prereg["maximumAllowedTermDeltaReconstructionErrorNewtons"],
        raw_closure <= prereg["maximumAllowedRelativeEnergyClosureError"],
        centered_closure <= prereg["maximumAllowedRelativeEnergyClosureError"],
        mean_closure <= prereg["maximumAllowedRelativeEnergyClosureError"],
        max(item["maximumAbsoluteInteractionDecompositionErrorNewtonsSquared"] for item in rebuilt_pairs) <= 1e-10,
    ])

    dominant = max(rebuilt_pairs, key=lambda item: abs(item["rawInteractionEnergyFraction"]))
    block_winners = [
        max(rebuilt_pairs, key=lambda item: abs(item["blockRawInteractionEnergyFractions"][index]))
        for index in range(3)
    ]
    dominant_sign = sign(dominant["rawInteractionEnergyFraction"])
    consistent = (
        all(item["pairIdentifier"] == dominant["pairIdentifier"] for item in block_winners)
        and all(value == dominant_sign and value != "neutral" for value in dominant["blockSigns"])
    )
    gate = (
        consistent
        and abs(dominant["rawInteractionEnergyFraction"]) >= prereg["minimumDominantPairFullEnergyFraction"]
        and all(abs(value) >= prereg["minimumDominantPairBlockEnergyFraction"] for value in dominant["blockRawInteractionEnergyFractions"])
    )
    if dominant["centeredShareOfAbsoluteDecomposition"] >= prereg["minimumMechanismDecompositionFraction"]:
        mechanism = "phase-fluctuation-dominated"
    elif dominant["meanShareOfAbsoluteDecomposition"] >= prereg["minimumMechanismDecompositionFraction"]:
        mechanism = "mean-offset-dominated"
    else:
        mechanism = "mixed-mean-and-phase"
    checks["dominantPairGateReproduces"] = all([
        metrics["dominantPairIdentifier"] == dominant["pairIdentifier"],
        metrics["dominantPairSign"] == dominant_sign,
        metrics["dominantPairConsistentAcrossBlocks"] == consistent,
        metrics["dominantPairGatePassed"] == gate,
        metrics["dominantPairMechanism"] == mechanism,
    ])
    source_reproduced = checks["closureGatesPass"]
    classification = (
        "invalid-force-covariance-decomposition" if not source_reproduced else
        f"robust-{dominant_sign}-{mechanism}-pair-covariance" if gate else
        "phase-dependent-term-pair-covariance"
    )
    checks["classificationAndSafetyBoundaryReproduce"] = all([
        report["sourceReproductionPassed"] == source_reproduced,
        report["classification"] == classification,
        not report["d20DiagnosticAuthorized"],
        not report["productionModificationAuthorized"],
        not report["fluidEvolutionExecuted"],
        not report["rawSpatialGateModified"],
        not report["experimentalAgreementGateApplied"],
    ])

    audit = {
        "schemaVersion": 1,
        "auditor": "independent Python reconstruction from archived D12/D16 term histories",
        "sourceSHA256": {
            "distributedForcePreregistration": source_hashes[0],
            "distributedForceReport": source_hashes[1],
            "distributedForceAudit": source_hashes[2],
            "covariancePreregistration": sha256(PREREG_PATH),
            "covarianceReport": sha256(REPORT_PATH),
        },
        "checks": checks,
        "independentMetrics": {
            "maximumTermDeltaReconstructionErrorNewtons": maximum_reconstruction,
            "rawEnergyClosureRelativeError": raw_closure,
            "dominantPairIdentifier": dominant["pairIdentifier"],
            "dominantPairInteractionEnergyFraction": dominant["rawInteractionEnergyFraction"],
            "blockWinners": [item["pairIdentifier"] for item in block_winners],
            "blockInteractionEnergyFractions": dominant["blockRawInteractionEnergyFractions"],
            "dominantPairSign": dominant_sign,
            "dominantPairMechanism": mechanism,
            "meanShareOfAbsoluteDecomposition": dominant["meanShareOfAbsoluteDecomposition"],
            "dominantPairGatePassed": gate,
        },
        "classification": classification,
        "allChecksPassed": all(checks.values()),
        "claimBoundary": (
            "This audit independently reconstructs aggregate covariance and energy identities. "
            "It does not establish causal boundary physics or authorize production changes."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))
    if not audit["allChecksPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

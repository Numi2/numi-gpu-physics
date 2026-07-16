#!/usr/bin/env python3
"""Independently audit the D12-to-D16 phase-localization artifact."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-preregistration.json"
D8_PATH = ARTIFACTS / "deetjen-dove-d8-moving-wall-full-window.json"
D12_PATH = ARTIFACTS / "deetjen-dove-d12-moving-wall-full-window.json"
D16_PATH = ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window.json"
DISCRIMINATOR_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-discriminator.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-localization.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-localization-audit.json"

Vector = tuple[float, float, float]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    return tuple(float(value) for value in raw)  # type: ignore[return-value]


def subtract(first: Vector, second: Vector) -> Vector:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def scale(value: Vector, factor: float) -> Vector:
    return tuple(component * factor for component in value)  # type: ignore[return-value]


def dot(first: Vector, second: Vector) -> float:
    return sum(a * b for a, b in zip(first, second))


def energy(value: Vector) -> float:
    return dot(value, value)


def magnitude(value: Vector) -> float:
    return math.sqrt(energy(value))


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector) -> bool:
    return all(close(a, b, 2e-8) for a, b in zip(first, second))


def mean_vector(values: list[Vector]) -> Vector:
    return tuple(
        sum(value[axis] for value in values) / len(values) for axis in range(3)
    )  # type: ignore[return-value]


def vector_rms(values: list[Vector]) -> float:
    return math.sqrt(sum(energy(value) for value in values) / len(values))


def interval_means(samples: list[dict], steps: int, indices: list[int], key: str) -> list[Vector]:
    result: list[Vector] = []
    for target_index in indices:
        end = target_index * steps
        result.append(mean_vector([vector(item[key]) for item in samples[end - steps : end]]))
    return result


def pearson(first: list[float], second: list[float]) -> float:
    first_mean = sum(first) / len(first)
    second_mean = sum(second) / len(second)
    numerator = sum((a - first_mean) * (b - second_mean) for a, b in zip(first, second))
    denominator = math.sqrt(
        sum((value - first_mean) ** 2 for value in first)
        * sum((value - second_mean) ** 2 for value in second)
    )
    return numerator / denominator if denominator > 1e-30 else 0.0


def high_frequency_fraction(values: list[Vector]) -> float:
    count = len(values)
    total = 0.0
    high = 0.0
    for frequency in range(1, count // 2 + 1):
        frequency_energy = 0.0
        for axis in range(3):
            real = sum(
                value[axis] * math.cos(2 * math.pi * frequency * index / count)
                for index, value in enumerate(values)
            )
            imaginary = -sum(
                value[axis] * math.sin(2 * math.pi * frequency * index / count)
                for index, value in enumerate(values)
            )
            frequency_energy += real * real + imaginary * imaginary
        total += frequency_energy
        if frequency >= math.ceil(count / 4):
            high += frequency_energy
    return high / max(total, 1e-30)


def main() -> None:
    report = load(REPORT_PATH)
    preregistration = load(PREREG_PATH)
    discriminator = load(DISCRIMINATOR_PATH)
    d12 = load(D12_PATH)["fullWindowReport"]
    d16 = load(D16_PATH)
    d12_samples = d12["registeredForceSamples"]
    d16_samples = d16["registeredForceSamples"]
    count = len(d12_samples)
    target_indices = [int(item["targetSampleIndex"]) for item in d12_samples]
    times = [float(item["sourceTimeSeconds"]) for item in d12_samples]
    axes_match = count == len(d16_samples) == report["registeredComparisonBinCount"]
    d12_force = [vector(item["intervalMeanComputedForceNewtons"]) for item in d12_samples]
    d16_force = [vector(item["intervalMeanComputedForceNewtons"]) for item in d16_samples]
    differences = [subtract(fine, coarse) for coarse, fine in zip(d12_force, d16_force)]
    squared = [energy(value) for value in differences]
    numerator = sum(squared)
    denominator = 0.5 * (
        sum(energy(value) for value in d12_force)
        + sum(energy(value) for value in d16_force)
    )
    normalized = math.sqrt(numerator / denominator)
    contributions = [value / numerator for value in squared]
    ranked = sorted(range(count), key=contributions.__getitem__, reverse=True)
    ordered = [contributions[index] for index in ranked]
    top_count = math.ceil(0.10 * count)
    effective = 1.0 / sum(value * value for value in contributions)

    def bins_required(fraction: float) -> int:
        total = 0.0
        for index, value in enumerate(ordered, start=1):
            total += value
            if total >= fraction:
                return index
        return count

    def best_window(bin_count: int) -> tuple[int, float]:
        start, value = max(
            (
                (offset, sum(contributions[offset : offset + bin_count]))
                for offset in range(count - bin_count + 1)
            ),
            key=lambda item: item[1],
        )
        return start, value

    best_ten_start, best_ten = best_window(10)
    concentration = report["concentration"]
    concentration_arithmetic = (
        close(float(concentration["effectiveBinCount"]), effective)
        and close(float(concentration["topOneBinContributionFraction"]), ordered[0])
        and close(float(concentration["topFiveBinsContributionFraction"]), sum(ordered[:5]))
        and close(float(concentration["topTenBinsContributionFraction"]), sum(ordered[:10]))
        and close(float(concentration["topTenPercentContributionFraction"]), sum(ordered[:top_count]))
        and int(concentration["binsRequiredFor50Percent"]) == bins_required(0.50)
        and int(concentration["binsRequiredFor80Percent"]) == bins_required(0.80)
        and int(concentration["binsRequiredFor90Percent"]) == bins_required(0.90)
        and close(
            float(concentration["maximumContiguousWindows"][2]["squaredDifferenceContributionFraction"]),
            best_ten,
        )
        and int(concentration["maximumContiguousWindows"][2]["startBinOffset"]) == best_ten_start
    )

    d12_steps = d12["ledgerResult"]["samples"]
    d16_steps = d16["ledgerResult"]["samples"]
    d12_step_count = int(d12["plan"]["fluidStepsPerForceSample"])
    d16_step_count = int(d16["plan"]["fluidStepsPerForceSample"])
    fields = (
        "topologyReservoirCorrectionNewtons",
        "rawControlVolumeClosureResidualNewtons",
        "globalFluidClosureResidualNewtons",
    )
    reconstructed: dict[str, list[Vector]] = {}
    for field in fields:
        coarse = interval_means(d12_steps, d12_step_count, target_indices, field)
        fine = interval_means(d16_steps, d16_step_count, target_indices, field)
        reconstructed[field] = [subtract(a, b) for b, a in zip(coarse, fine)]
    topology = reconstructed[fields[0]]
    near = reconstructed[fields[1]]
    global_residual = reconstructed[fields[2]]
    force_rms = vector_rms(differences)
    near_ratio = vector_rms(near) / force_rms
    global_ratio = vector_rms(global_residual) / force_rms
    topology_correlation = pearson(
        [magnitude(value) for value in differences],
        [magnitude(value) for value in topology],
    )
    topology_energy = sum(energy(value) for value in topology)
    coefficient = sum(dot(a, b) for a, b in zip(differences, topology)) / max(topology_energy, 1e-30)
    residual_energy = sum(
        energy(subtract(force, scale(topology_value, coefficient)))
        for force, topology_value in zip(differences, topology)
    )
    explained = max(0.0, 1.0 - residual_energy / sum(squared))
    topology_ranked = sorted(range(count), key=lambda index: magnitude(topology[index]), reverse=True)
    overlap = len(set(ranked[:top_count]) & set(topology_ranked[:top_count])) / top_count

    consecutive = [subtract(differences[index], differences[index - 1]) for index in range(1, count)]
    roughness = vector_rms(consecutive) / force_rms
    high_frequency = high_frequency_fraction(differences)
    thresholds = report["fixedDecisionThresholds"]
    localized = (
        sum(ordered[:top_count]) >= thresholds["localizedTopTenPercentMinimumContribution"]
        or best_ten >= thresholds["localizedFiveMillisecondMinimumContribution"]
        or effective / count <= thresholds["localizedMaximumEffectiveBinFraction"]
    )
    distributed = (
        effective / count >= thresholds["distributedMinimumEffectiveBinFraction"]
        and bins_required(0.50) / count >= thresholds["distributedMinimumHalfEnergyBinFraction"]
        and best_ten <= thresholds["distributedMaximumFiveMillisecondContribution"]
    )
    classification = "localized" if localized else "distributed" if distributed else "mixed"
    smooth = (
        roughness <= thresholds["smoothMaximumFirstDifferenceRoughness"]
        and high_frequency <= thresholds["smoothMaximumHighFrequencyEnergyFraction"]
    )
    topology_likely = (
        explained >= thresholds["topologyMinimumProjectionExplainedFraction"]
        or (
            topology_correlation >= thresholds["topologyMinimumMagnitudeCorrelation"]
            and overlap >= thresholds["topologyMinimumTopTenPercentOverlap"]
        )
    )
    accounting_likely = max(near_ratio, global_ratio) > thresholds["accountingMaximumResidualToForceDifference"]
    miss_ratio = normalized / float(preregistration["maximumAllowedFineGridRelativeDifference"])
    d20 = (
        classification == "distributed"
        and smooth
        and not topology_likely
        and not accounting_likely
        and discriminator["allCaseGatesPassed"] is True
        and discriminator["monotonicTrendReductionPassed"] is True
        and discriminator["fineGridForceConvergencePassed"] is False
        and miss_ratio <= thresholds["maximumFineGridMissRatioForD20"]
    )

    bins_match = len(report["bins"]) == count
    for index, item in enumerate(report["bins"]):
        bins_match &= int(item["targetSampleIndex"]) == target_indices[index]
        bins_match &= close(float(item["sourceTimeSeconds"]), times[index])
        bins_match &= vector_close(vector(item["d16MinusD12ForceNewtons"]), differences[index])
        bins_match &= close(float(item["squaredDifferenceContributionFraction"]), contributions[index])
        bins_match &= vector_close(vector(item["d16MinusD12TopologyReservoirCorrectionNewtons"]), topology[index])
        bins_match &= vector_close(vector(item["d16MinusD12NearWingClosureResidualNewtons"]), near[index])
        bins_match &= vector_close(vector(item["d16MinusD12GlobalClosureResidualNewtons"]), global_residual[index])

    source_hashes = {
        "spatialPreregistration": sha256(PREREG_PATH),
        "d8Case": sha256(D8_PATH),
        "d12Case": sha256(D12_PATH),
        "d16FullWindow": sha256(D16_PATH),
        "spatialDiscriminator": sha256(DISCRIMINATOR_PATH),
    }
    checks = {
        "sourceHashes": report["sourceSHA256"] == source_hashes,
        "registeredAxes": axes_match,
        "forceArithmetic": close(report["forceHistory"]["squaredDifferenceNumerator"], numerator)
        and close(report["forceHistory"]["symmetricForceEnergyDenominator"], denominator)
        and close(report["forceHistory"]["pairwiseNormalizedRMSDifference"], normalized),
        "concentrationArithmetic": concentration_arithmetic,
        "binArithmetic": bins_match,
        "smoothnessArithmetic": close(report["smoothness"]["normalizedFirstDifferenceRoughness"], roughness)
        and close(report["smoothness"]["highFrequencyEnergyFraction"], high_frequency)
        and report["smoothness"]["smoothDifferencePassed"] is smooth,
        "topologyArithmetic": close(report["topologyAssociation"]["forceTopologyMagnitudeCorrelation"], topology_correlation)
        and close(report["topologyAssociation"]["leastSquaresTopologyCoefficient"], coefficient)
        and close(report["topologyAssociation"]["leastSquaresTopologyExplainedFraction"], explained)
        and close(report["topologyAssociation"]["topTenPercentRankOverlapFraction"], overlap)
        and report["topologyAssociation"]["topologyEventLikely"] is topology_likely,
        "accountingArithmetic": close(report["accountingAssociation"]["nearWingResidualToForceDifferenceRatio"], near_ratio)
        and close(report["accountingAssociation"]["globalResidualToForceDifferenceRatio"], global_ratio)
        and report["accountingAssociation"]["accountingContaminationLikely"] is accounting_likely,
        "classification": report["concentration"]["classification"] == classification,
        "d20Decision": report["d20DiagnosticAuthorized"] is d20 and not d20,
        "claimBoundary": report["experimentalAgreementGateApplied"] is False
        and report["productionPromotionAuthorized"] is False,
    }
    passed = all(checks.values())
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-spatial-localization.py",
        "reportSHA256": sha256(REPORT_PATH),
        "checks": checks,
        "reconstructed": {
            "pairwiseNormalizedRMSDifference": normalized,
            "effectiveBinCount": effective,
            "binsRequiredFor50Percent": bins_required(0.50),
            "maximumFiveMillisecondContribution": best_ten,
            "normalizedFirstDifferenceRoughness": roughness,
            "highFrequencyEnergyFraction": high_frequency,
            "topologyExplainedFraction": explained,
            "nearWingResidualToForceDifferenceRatio": near_ratio,
            "globalResidualToForceDifferenceRatio": global_ratio,
            "classification": classification,
            "d20DiagnosticAuthorized": d20,
        },
        "allChecksPassed": passed,
        "claimBoundary": (
            "Independent source-hash, bin, concentration, spectral, topology, "
            "accounting, classification, and allocation-decision audit. A pass "
            "authenticates the D20 rejection; it does not establish convergence."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("localization audit failed: " + ", ".join(failed))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

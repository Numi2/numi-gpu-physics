#!/usr/bin/env python3
"""Localize the archived D12-to-D16 candidate-A force-history difference."""

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
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-localization.json"

LOCALIZED_TOP_TEN_PERCENT_MINIMUM = 0.50
LOCALIZED_FIVE_MILLISECOND_MINIMUM = 0.50
LOCALIZED_MAXIMUM_EFFECTIVE_BIN_FRACTION = 0.20
DISTRIBUTED_MINIMUM_EFFECTIVE_BIN_FRACTION = 0.40
DISTRIBUTED_MINIMUM_HALF_ENERGY_BIN_FRACTION = 0.25
DISTRIBUTED_MAXIMUM_FIVE_MILLISECOND_CONTRIBUTION = 0.25
SMOOTH_MAXIMUM_FIRST_DIFFERENCE_ROUGHNESS = 0.50
SMOOTH_MAXIMUM_HIGH_FREQUENCY_ENERGY_FRACTION = 0.15
ACCOUNTING_MAXIMUM_RESIDUAL_TO_FORCE_DIFFERENCE = 0.25
TOPOLOGY_MINIMUM_PROJECTION_EXPLAINED_FRACTION = 0.50
TOPOLOGY_MINIMUM_MAGNITUDE_CORRELATION = 0.70
TOPOLOGY_MINIMUM_TOP_TEN_PERCENT_OVERLAP = 0.50
MAXIMUM_FINE_GRID_MISS_RATIO_FOR_D20 = 1.50

Vector = tuple[float, float, float]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    value = tuple(float(component) for component in raw)
    if not all(math.isfinite(component) for component in value):
        raise ValueError("nonfinite vector")
    return value  # type: ignore[return-value]


def add(first: Vector, second: Vector) -> Vector:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def subtract(first: Vector, second: Vector) -> Vector:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def scale(value: Vector, factor: float) -> Vector:
    return tuple(component * factor for component in value)  # type: ignore[return-value]


def dot(first: Vector, second: Vector) -> float:
    return sum(a * b for a, b in zip(first, second))


def norm_squared(value: Vector) -> float:
    return dot(value, value)


def magnitude(value: Vector) -> float:
    return math.sqrt(norm_squared(value))


def mean_vector(values: list[Vector]) -> Vector:
    return scale(
        tuple(sum(value[axis] for value in values) for axis in range(3)),
        1.0 / len(values),
    )  # type: ignore[arg-type]


def vector_rms(values: list[Vector]) -> float:
    return math.sqrt(sum(norm_squared(value) for value in values) / len(values))


def interval_means(samples: list[dict], steps_per_sample: int, indices: list[int], key: str) -> list[Vector]:
    result: list[Vector] = []
    for target_index in indices:
        end = target_index * steps_per_sample
        start = end - steps_per_sample
        result.append(mean_vector([vector(sample[key]) for sample in samples[start:end]]))
    return result


def bins_for_fraction(sorted_contributions: list[float], fraction: float) -> int:
    cumulative = 0.0
    for index, contribution in enumerate(sorted_contributions, start=1):
        cumulative += contribution
        if cumulative >= fraction:
            return index
    return len(sorted_contributions)


def maximum_window(contributions: list[float], count: int, times: list[float]) -> dict:
    best_start = 0
    best = -1.0
    for start in range(0, len(contributions) - count + 1):
        value = sum(contributions[start : start + count])
        if value > best:
            best = value
            best_start = start
    end = best_start + count - 1
    return {
        "binCount": count,
        "durationSeconds": count / 2_000.0,
        "startBinOffset": best_start,
        "endBinOffset": end,
        "startTimeSeconds": times[best_start],
        "endTimeSeconds": times[end],
        "squaredDifferenceContributionFraction": best,
    }


def pearson(first: list[float], second: list[float]) -> float:
    first_mean = sum(first) / len(first)
    second_mean = sum(second) / len(second)
    numerator = sum(
        (a - first_mean) * (b - second_mean) for a, b in zip(first, second)
    )
    first_energy = sum((value - first_mean) ** 2 for value in first)
    second_energy = sum((value - second_mean) ** 2 for value in second)
    denominator = math.sqrt(first_energy * second_energy)
    return numerator / denominator if denominator > 1e-30 else 0.0


def projection_explained_fraction(force: list[Vector], topology: list[Vector]) -> tuple[float, float]:
    numerator = sum(dot(force_value, topology_value) for force_value, topology_value in zip(force, topology))
    topology_energy = sum(norm_squared(value) for value in topology)
    coefficient = numerator / topology_energy if topology_energy > 1e-30 else 0.0
    residual_energy = sum(
        norm_squared(subtract(force_value, scale(topology_value, coefficient)))
        for force_value, topology_value in zip(force, topology)
    )
    force_energy = sum(norm_squared(value) for value in force)
    explained = 1.0 - residual_energy / max(force_energy, 1e-30)
    return coefficient, max(0.0, min(1.0, explained))


def high_frequency_energy_fraction(values: list[Vector]) -> float:
    count = len(values)
    total = 0.0
    high = 0.0
    for frequency in range(1, count // 2 + 1):
        energy = 0.0
        for axis in range(3):
            real = 0.0
            imaginary = 0.0
            for index, value in enumerate(values):
                angle = 2.0 * math.pi * frequency * index / count
                real += value[axis] * math.cos(angle)
                imaginary -= value[axis] * math.sin(angle)
            energy += real * real + imaginary * imaginary
        total += energy
        if frequency >= math.ceil(count / 4):
            high += energy
    return high / max(total, 1e-30)


def main() -> None:
    preregistration = load(PREREG_PATH)
    d8 = load(D8_PATH)
    d12_wrapper = load(D12_PATH)
    d12 = d12_wrapper["fullWindowReport"]
    d16 = load(D16_PATH)
    discriminator = load(DISCRIMINATOR_PATH)
    d12_force_samples = d12["registeredForceSamples"]
    d16_force_samples = d16["registeredForceSamples"]
    if len(d12_force_samples) != len(d16_force_samples) or not d12_force_samples:
        raise SystemExit("D12/D16 registered force histories are incomplete")

    target_indices = [int(sample["targetSampleIndex"]) for sample in d12_force_samples]
    times = [float(sample["sourceTimeSeconds"]) for sample in d12_force_samples]
    for d12_sample, d16_sample in zip(d12_force_samples, d16_force_samples):
        if (
            int(d12_sample["targetSampleIndex"]) != int(d16_sample["targetSampleIndex"])
            or abs(float(d12_sample["sourceTimeSeconds"]) - float(d16_sample["sourceTimeSeconds"])) > 1e-12
        ):
            raise SystemExit("D12/D16 force axes do not match")

    d12_forces = [vector(sample["intervalMeanComputedForceNewtons"]) for sample in d12_force_samples]
    d16_forces = [vector(sample["intervalMeanComputedForceNewtons"]) for sample in d16_force_samples]
    differences = [subtract(fine, coarse) for coarse, fine in zip(d12_forces, d16_forces)]
    squared_differences = [norm_squared(value) for value in differences]
    numerator = sum(squared_differences)
    denominator = 0.5 * (
        sum(norm_squared(value) for value in d12_forces)
        + sum(norm_squared(value) for value in d16_forces)
    )
    normalized_rms_difference = math.sqrt(numerator / denominator)
    contributions = [value / numerator for value in squared_differences]
    ranked_offsets = sorted(range(len(contributions)), key=contributions.__getitem__, reverse=True)
    sorted_contributions = [contributions[index] for index in ranked_offsets]
    top_ten_count = math.ceil(0.10 * len(contributions))
    effective_bin_count = 1.0 / sum(value * value for value in contributions)

    d12_steps = d12["ledgerResult"]["samples"]
    d16_steps = d16["ledgerResult"]["samples"]
    d12_steps_per_bin = int(d12["plan"]["fluidStepsPerForceSample"])
    d16_steps_per_bin = int(d16["plan"]["fluidStepsPerForceSample"])
    d12_topology = interval_means(d12_steps, d12_steps_per_bin, target_indices, "topologyReservoirCorrectionNewtons")
    d16_topology = interval_means(d16_steps, d16_steps_per_bin, target_indices, "topologyReservoirCorrectionNewtons")
    topology_differences = [subtract(fine, coarse) for coarse, fine in zip(d12_topology, d16_topology)]
    d12_near_residual = interval_means(d12_steps, d12_steps_per_bin, target_indices, "rawControlVolumeClosureResidualNewtons")
    d16_near_residual = interval_means(d16_steps, d16_steps_per_bin, target_indices, "rawControlVolumeClosureResidualNewtons")
    near_residual_differences = [subtract(fine, coarse) for coarse, fine in zip(d12_near_residual, d16_near_residual)]
    d12_global_residual = interval_means(d12_steps, d12_steps_per_bin, target_indices, "globalFluidClosureResidualNewtons")
    d16_global_residual = interval_means(d16_steps, d16_steps_per_bin, target_indices, "globalFluidClosureResidualNewtons")
    global_residual_differences = [subtract(fine, coarse) for coarse, fine in zip(d12_global_residual, d16_global_residual)]

    force_difference_rms = vector_rms(differences)
    near_residual_difference_rms = vector_rms(near_residual_differences)
    global_residual_difference_rms = vector_rms(global_residual_differences)
    near_accounting_ratio = near_residual_difference_rms / max(force_difference_rms, 1e-30)
    global_accounting_ratio = global_residual_difference_rms / max(force_difference_rms, 1e-30)
    accounting_contamination = max(near_accounting_ratio, global_accounting_ratio) > ACCOUNTING_MAXIMUM_RESIDUAL_TO_FORCE_DIFFERENCE

    topology_magnitudes = [magnitude(value) for value in topology_differences]
    force_magnitudes = [magnitude(value) for value in differences]
    topology_correlation = pearson(force_magnitudes, topology_magnitudes)
    topology_coefficient, topology_explained = projection_explained_fraction(differences, topology_differences)
    topology_ranked = sorted(range(len(topology_magnitudes)), key=topology_magnitudes.__getitem__, reverse=True)
    overlap = len(set(ranked_offsets[:top_ten_count]) & set(topology_ranked[:top_ten_count])) / top_ten_count
    topology_event_likely = topology_explained >= TOPOLOGY_MINIMUM_PROJECTION_EXPLAINED_FRACTION or (
        topology_correlation >= TOPOLOGY_MINIMUM_MAGNITUDE_CORRELATION
        and overlap >= TOPOLOGY_MINIMUM_TOP_TEN_PERCENT_OVERLAP
    )

    consecutive_differences = [subtract(differences[index], differences[index - 1]) for index in range(1, len(differences))]
    first_difference_roughness = vector_rms(consecutive_differences) / max(force_difference_rms, 1e-30)
    high_frequency_fraction = high_frequency_energy_fraction(differences)
    smooth = (
        first_difference_roughness <= SMOOTH_MAXIMUM_FIRST_DIFFERENCE_ROUGHNESS
        and high_frequency_fraction <= SMOOTH_MAXIMUM_HIGH_FREQUENCY_ENERGY_FRACTION
    )

    windows = [maximum_window(contributions, count, times) for count in (1, 5, 10, 20)]
    five_ms_contribution = next(item for item in windows if item["binCount"] == 10)["squaredDifferenceContributionFraction"]
    bins_half = bins_for_fraction(sorted_contributions, 0.50)
    effective_fraction = effective_bin_count / len(contributions)
    top_ten_fraction = sum(sorted_contributions[:top_ten_count])
    localized = (
        top_ten_fraction >= LOCALIZED_TOP_TEN_PERCENT_MINIMUM
        or five_ms_contribution >= LOCALIZED_FIVE_MILLISECOND_MINIMUM
        or effective_fraction <= LOCALIZED_MAXIMUM_EFFECTIVE_BIN_FRACTION
    )
    distributed = (
        effective_fraction >= DISTRIBUTED_MINIMUM_EFFECTIVE_BIN_FRACTION
        and bins_half / len(contributions) >= DISTRIBUTED_MINIMUM_HALF_ENERGY_BIN_FRACTION
        and five_ms_contribution <= DISTRIBUTED_MAXIMUM_FIVE_MILLISECOND_CONTRIBUTION
    )
    classification = "localized" if localized else "distributed" if distributed else "mixed"

    fine_limit = float(preregistration["maximumAllowedFineGridRelativeDifference"])
    miss_ratio = normalized_rms_difference / fine_limit
    d20_authorized = (
        classification == "distributed"
        and smooth
        and not topology_event_likely
        and not accounting_contamination
        and discriminator["allCaseGatesPassed"] is True
        and discriminator["monotonicTrendReductionPassed"] is True
        and discriminator["fineGridForceConvergencePassed"] is False
        and miss_ratio <= MAXIMUM_FINE_GRID_MISS_RATIO_FOR_D20
    )

    component_numerators = [sum(value[axis] ** 2 for value in differences) for axis in range(3)]
    component_denominators = [
        0.5 * (
            sum(value[axis] ** 2 for value in d12_forces)
            + sum(value[axis] ** 2 for value in d16_forces)
        )
        for axis in range(3)
    ]
    component_shares = scale(tuple(component / numerator for component in component_numerators), 1.0)
    component_normalized = tuple(
        math.sqrt(component_numerators[axis] / max(component_denominators[axis], 1e-30))
        for axis in range(3)
    )
    ranks = [0] * len(contributions)
    for rank, offset in enumerate(ranked_offsets, start=1):
        ranks[offset] = rank
    first_time = times[0]
    duration = times[-1] - first_time
    bins = []
    for index in range(len(contributions)):
        bins.append({
            "targetSampleIndex": target_indices[index],
            "sourceTimeSeconds": times[index],
            "comparisonPhase": (times[index] - first_time) / duration,
            "d12ForceNewtons": d12_forces[index],
            "d16ForceNewtons": d16_forces[index],
            "d16MinusD12ForceNewtons": differences[index],
            "forceDifferenceMagnitudeNewtons": force_magnitudes[index],
            "squaredDifferenceContributionFraction": contributions[index],
            "squaredDifferenceContributionRank": ranks[index],
            "d12TopologyReservoirCorrectionNewtons": d12_topology[index],
            "d16TopologyReservoirCorrectionNewtons": d16_topology[index],
            "d16MinusD12TopologyReservoirCorrectionNewtons": topology_differences[index],
            "d16MinusD12NearWingClosureResidualNewtons": near_residual_differences[index],
            "d16MinusD12GlobalClosureResidualNewtons": global_residual_differences[index],
        })

    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/analyze-dove-moving-wall-spatial-localization.py",
        "datasetIdentifier": d16["datasetIdentifier"],
        "forceTargetIdentifier": d16["forceTargetIdentifier"],
        "sourceSHA256": {
            "spatialPreregistration": sha256(PREREG_PATH),
            "d8Case": sha256(D8_PATH),
            "d12Case": sha256(D12_PATH),
            "d16FullWindow": sha256(D16_PATH),
            "spatialDiscriminator": sha256(DISCRIMINATOR_PATH),
        },
        "fixedDecisionThresholds": {
            "localizedTopTenPercentMinimumContribution": LOCALIZED_TOP_TEN_PERCENT_MINIMUM,
            "localizedFiveMillisecondMinimumContribution": LOCALIZED_FIVE_MILLISECOND_MINIMUM,
            "localizedMaximumEffectiveBinFraction": LOCALIZED_MAXIMUM_EFFECTIVE_BIN_FRACTION,
            "distributedMinimumEffectiveBinFraction": DISTRIBUTED_MINIMUM_EFFECTIVE_BIN_FRACTION,
            "distributedMinimumHalfEnergyBinFraction": DISTRIBUTED_MINIMUM_HALF_ENERGY_BIN_FRACTION,
            "distributedMaximumFiveMillisecondContribution": DISTRIBUTED_MAXIMUM_FIVE_MILLISECOND_CONTRIBUTION,
            "smoothMaximumFirstDifferenceRoughness": SMOOTH_MAXIMUM_FIRST_DIFFERENCE_ROUGHNESS,
            "smoothMaximumHighFrequencyEnergyFraction": SMOOTH_MAXIMUM_HIGH_FREQUENCY_ENERGY_FRACTION,
            "accountingMaximumResidualToForceDifference": ACCOUNTING_MAXIMUM_RESIDUAL_TO_FORCE_DIFFERENCE,
            "topologyMinimumProjectionExplainedFraction": TOPOLOGY_MINIMUM_PROJECTION_EXPLAINED_FRACTION,
            "topologyMinimumMagnitudeCorrelation": TOPOLOGY_MINIMUM_MAGNITUDE_CORRELATION,
            "topologyMinimumTopTenPercentOverlap": TOPOLOGY_MINIMUM_TOP_TEN_PERCENT_OVERLAP,
            "maximumFineGridMissRatioForD20": MAXIMUM_FINE_GRID_MISS_RATIO_FOR_D20,
        },
        "registeredComparisonBinCount": len(contributions),
        "forceHistory": {
            "pairwiseNormalizedRMSDifference": normalized_rms_difference,
            "lockedMaximumDifference": fine_limit,
            "lockedLimitMissRatio": miss_ratio,
            "squaredDifferenceNumerator": numerator,
            "symmetricForceEnergyDenominator": denominator,
            "forceDifferenceRMSNewtons": force_difference_rms,
            "componentSquaredDifferenceContributionFractionXYZ": component_shares,
            "componentPairwiseNormalizedRMSDifferenceXYZ": component_normalized,
        },
        "concentration": {
            "effectiveBinCount": effective_bin_count,
            "effectiveBinFraction": effective_fraction,
            "topOneBinContributionFraction": sorted_contributions[0],
            "topFiveBinsContributionFraction": sum(sorted_contributions[:5]),
            "topTenBinsContributionFraction": sum(sorted_contributions[:10]),
            "topTenPercentBinCount": top_ten_count,
            "topTenPercentContributionFraction": top_ten_fraction,
            "binsRequiredFor50Percent": bins_half,
            "binsRequiredFor80Percent": bins_for_fraction(sorted_contributions, 0.80),
            "binsRequiredFor90Percent": bins_for_fraction(sorted_contributions, 0.90),
            "maximumContiguousWindows": windows,
            "classification": classification,
        },
        "smoothness": {
            "normalizedFirstDifferenceRoughness": first_difference_roughness,
            "highFrequencyEnergyFraction": high_frequency_fraction,
            "smoothDifferencePassed": smooth,
        },
        "topologyAssociation": {
            "topologyDifferenceRMSNewtons": vector_rms(topology_differences),
            "forceTopologyMagnitudeCorrelation": topology_correlation,
            "leastSquaresTopologyCoefficient": topology_coefficient,
            "leastSquaresTopologyExplainedFraction": topology_explained,
            "topTenPercentRankOverlapFraction": overlap,
            "topologyEventLikely": topology_event_likely,
        },
        "accountingAssociation": {
            "nearWingClosureResidualDifferenceRMSNewtons": near_residual_difference_rms,
            "globalClosureResidualDifferenceRMSNewtons": global_residual_difference_rms,
            "nearWingResidualToForceDifferenceRatio": near_accounting_ratio,
            "globalResidualToForceDifferenceRatio": global_accounting_ratio,
            "accountingContaminationLikely": accounting_contamination,
        },
        "d20DiagnosticAuthorized": d20_authorized,
        "experimentalAgreementGateApplied": False,
        "productionPromotionAuthorized": False,
        "scientificVerdict": (
            "The D12-to-D16 miss is smooth, distributed, not topology-aligned, "
            "and too large to be explained by ledger residual differences. One "
            "source-locked D=20 case is authorized to test the next fine pair."
            if d20_authorized
            else "The archive-only localization does not justify D=20 under the "
            "fixed concentration, smoothness, topology, accounting, and miss-ratio rules."
        ),
        "claimBoundary": (
            "This archive-only diagnostic uses computed D12/D16 force and ledger "
            "histories; measured-force error cannot influence classification. "
            "D20 authorization is a compute-allocation decision, not spatial, "
            "production, experimental-agreement, or free-flight clearance."
        ),
        "bins": bins,
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps({key: value for key, value in output.items() if key != "bins"}, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Discriminate lag sensitivity from broadband D12/D16 force noise."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
D12_PATH = ARTIFACTS / "deetjen-dove-d12-moving-wall-full-window.json"
D16_PATH = ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window.json"
DISCRIMINATOR_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-discriminator.json"
LOCALIZATION_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-localization.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-lag-band.json"

SAMPLE_RATE_HERTZ = 2_000.0
LAG_MINIMUM_BINS = -0.5
LAG_MAXIMUM_BINS = 0.5
LAG_INCREMENT_BINS = 0.01
LAG_CROSS_VALIDATION_FOLDS = 5
MINIMUM_REGISTRATION_LAG_BINS = 0.05
MINIMUM_REGISTRATION_IMPROVEMENT_FRACTION = 0.20
MAXIMUM_REGISTRATION_LAG_STANDARD_DEVIATION_BINS = 0.15
MINIMUM_REGISTRATION_SIGN_CONSISTENCY = 0.80
BAND_CUTOFFS_HERTZ = (50.0, 100.0, 200.0, 400.0, 1_000.0)
DECISION_BAND_CUTOFF_HERTZ = 200.0
MINIMUM_DECISION_BAND_SIGNAL_ENERGY_RETENTION = 0.99
MAXIMUM_DECISION_BAND_PAIRWISE_DIFFERENCE = 0.05
MINIMUM_BAND_IMPROVEMENT_FRACTION = 0.20
MINIMUM_REMOVED_DIFFERENCE_ENERGY_FRACTION = 0.25
MAXIMUM_COHERENT_LOW_BAND_ROUGHNESS = 0.50
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


def energy(value: Vector) -> float:
    return sum(component * component for component in value)


def interpolate(values: list[Vector], coordinate: float) -> Vector:
    lower = math.floor(coordinate)
    fraction = coordinate - lower
    if lower < 0 or lower + 1 >= len(values):
        raise ValueError("lag interpolation escaped the common support")
    return add(scale(values[lower], 1.0 - fraction), scale(values[lower + 1], fraction))


def pairwise_terms(first: list[Vector], second: list[Vector]) -> tuple[float, float]:
    numerator = sum(energy(subtract(a, b)) for a, b in zip(first, second))
    denominator = 0.5 * (
        sum(energy(value) for value in first)
        + sum(energy(value) for value in second)
    )
    return numerator, denominator


def pairwise_difference(first: list[Vector], second: list[Vector]) -> float:
    numerator, denominator = pairwise_terms(first, second)
    return math.sqrt(numerator / max(denominator, 1e-30))


def lagged_terms(
    coarse: list[Vector], fine: list[Vector], indices: list[int], lag_bins: float
) -> tuple[float, float]:
    shifted = [interpolate(fine, index + lag_bins) for index in indices]
    selected = [coarse[index] for index in indices]
    return pairwise_terms(selected, shifted)


def lagged_difference(
    coarse: list[Vector], fine: list[Vector], indices: list[int], lag_bins: float
) -> float:
    numerator, denominator = lagged_terms(coarse, fine, indices, lag_bins)
    return math.sqrt(numerator / max(denominator, 1e-30))


def lag_candidates() -> list[float]:
    count = round((LAG_MAXIMUM_BINS - LAG_MINIMUM_BINS) / LAG_INCREMENT_BINS)
    return [round(LAG_MINIMUM_BINS + index * LAG_INCREMENT_BINS, 10) for index in range(count + 1)]


def select_lag(coarse: list[Vector], fine: list[Vector], indices: list[int]) -> tuple[float, float]:
    candidates = [
        (lagged_difference(coarse, fine, indices, lag), abs(lag), lag)
        for lag in lag_candidates()
    ]
    difference, _, lag = min(candidates)
    return lag, difference


def dct_coefficients(values: list[Vector]) -> list[Vector]:
    count = len(values)
    coefficients: list[Vector] = []
    coefficients.append(
        tuple(sum(value[axis] for value in values) / count for axis in range(3))  # type: ignore[arg-type]
    )
    for mode in range(1, count):
        coefficients.append(
            tuple(
                2.0
                / count
                * sum(
                    value[axis]
                    * math.cos(math.pi / count * (index + 0.5) * mode)
                    for index, value in enumerate(values)
                )
                for axis in range(3)
            )  # type: ignore[arg-type]
        )
    return coefficients


def reconstruct_low_pass(coefficients: list[Vector], cutoff_hertz: float) -> tuple[list[Vector], int, float]:
    count = len(coefficients)
    maximum_mode = min(
        count - 1,
        math.floor(2.0 * count * cutoff_hertz / SAMPLE_RATE_HERTZ + 1e-12),
    )
    actual_cutoff = maximum_mode * SAMPLE_RATE_HERTZ / (2.0 * count)
    reconstructed: list[Vector] = []
    for index in range(count):
        value = coefficients[0]
        for mode in range(1, maximum_mode + 1):
            value = add(
                value,
                scale(
                    coefficients[mode],
                    math.cos(math.pi / count * (index + 0.5) * mode),
                ),
            )
        reconstructed.append(value)
    return reconstructed, maximum_mode, actual_cutoff


def roughness(values: list[Vector]) -> float:
    base = math.sqrt(sum(energy(value) for value in values) / len(values))
    changes = [subtract(values[index], values[index - 1]) for index in range(1, len(values))]
    change_rms = math.sqrt(sum(energy(value) for value in changes) / len(changes))
    return change_rms / max(base, 1e-30)


def main() -> None:
    d12 = load(D12_PATH)["fullWindowReport"]
    d16 = load(D16_PATH)
    discriminator = load(DISCRIMINATOR_PATH)
    localization = load(LOCALIZATION_PATH)
    d12_samples = d12["registeredForceSamples"]
    d16_samples = d16["registeredForceSamples"]
    if len(d12_samples) != len(d16_samples) or len(d12_samples) < 10:
        raise SystemExit("D12/D16 force histories are incomplete")
    times = [float(item["sourceTimeSeconds"]) for item in d12_samples]
    target_indices = [int(item["targetSampleIndex"]) for item in d12_samples]
    for coarse, fine in zip(d12_samples, d16_samples):
        if (
            int(coarse["targetSampleIndex"]) != int(fine["targetSampleIndex"])
            or abs(float(coarse["sourceTimeSeconds"]) - float(fine["sourceTimeSeconds"])) > 1e-12
        ):
            raise SystemExit("D12/D16 registered axes do not match")
    coarse = [vector(item["intervalMeanComputedForceNewtons"]) for item in d12_samples]
    fine = [vector(item["intervalMeanComputedForceNewtons"]) for item in d16_samples]
    raw_difference = pairwise_difference(coarse, fine)
    common_indices = list(range(1, len(coarse) - 1))
    baseline_common = lagged_difference(coarse, fine, common_indices, 0.0)
    global_lag, global_aligned = select_lag(coarse, fine, common_indices)
    global_improvement = 1.0 - global_aligned / baseline_common

    fold_size = math.ceil(len(common_indices) / LAG_CROSS_VALIDATION_FOLDS)
    fold_reports = []
    aggregate_baseline_numerator = 0.0
    aggregate_baseline_denominator = 0.0
    aggregate_aligned_numerator = 0.0
    aggregate_aligned_denominator = 0.0
    fold_lags: list[float] = []
    for fold in range(LAG_CROSS_VALIDATION_FOLDS):
        start = fold * fold_size
        stop = min(len(common_indices), start + fold_size)
        test_indices = common_indices[start:stop]
        if not test_indices:
            continue
        test_set = set(test_indices)
        training_indices = [index for index in common_indices if index not in test_set]
        selected_lag, training_difference = select_lag(coarse, fine, training_indices)
        baseline_numerator, baseline_denominator = lagged_terms(coarse, fine, test_indices, 0.0)
        aligned_numerator, aligned_denominator = lagged_terms(coarse, fine, test_indices, selected_lag)
        baseline_difference = math.sqrt(baseline_numerator / baseline_denominator)
        aligned_difference = math.sqrt(aligned_numerator / aligned_denominator)
        fold_lags.append(selected_lag)
        aggregate_baseline_numerator += baseline_numerator
        aggregate_baseline_denominator += baseline_denominator
        aggregate_aligned_numerator += aligned_numerator
        aggregate_aligned_denominator += aligned_denominator
        fold_reports.append(
            {
                "fold": fold,
                "testStartBinOffset": test_indices[0],
                "testEndBinOffset": test_indices[-1],
                "testStartTimeSeconds": times[test_indices[0]],
                "testEndTimeSeconds": times[test_indices[-1]],
                "selectedTrainingLagBins": selected_lag,
                "selectedTrainingLagSeconds": selected_lag / SAMPLE_RATE_HERTZ,
                "trainingPairwiseDifference": training_difference,
                "testBaselinePairwiseDifference": baseline_difference,
                "testAlignedPairwiseDifference": aligned_difference,
                "testImprovementFraction": 1.0 - aligned_difference / baseline_difference,
            }
        )
    cross_validated_baseline = math.sqrt(
        aggregate_baseline_numerator / aggregate_baseline_denominator
    )
    cross_validated_aligned = math.sqrt(
        aggregate_aligned_numerator / aggregate_aligned_denominator
    )
    cross_validated_improvement = 1.0 - cross_validated_aligned / cross_validated_baseline
    lag_mean = sum(fold_lags) / len(fold_lags)
    lag_standard_deviation = math.sqrt(
        sum((lag - lag_mean) ** 2 for lag in fold_lags) / len(fold_lags)
    )
    global_sign = 1 if global_lag > 0 else -1 if global_lag < 0 else 0
    sign_consistency = (
        sum(
            1
            for lag in fold_lags
            if (1 if lag > 0 else -1 if lag < 0 else 0) == global_sign
        )
        / len(fold_lags)
    )
    registration_likely = (
        abs(global_lag) >= MINIMUM_REGISTRATION_LAG_BINS
        and cross_validated_improvement >= MINIMUM_REGISTRATION_IMPROVEMENT_FRACTION
        and lag_standard_deviation <= MAXIMUM_REGISTRATION_LAG_STANDARD_DEVIATION_BINS
        and sign_consistency >= MINIMUM_REGISTRATION_SIGN_CONSISTENCY
    )

    coarse_coefficients = dct_coefficients(coarse)
    fine_coefficients = dct_coefficients(fine)
    raw_signal_energy = sum(energy(value) for value in coarse) + sum(
        energy(value) for value in fine
    )
    raw_difference_energy = sum(
        energy(subtract(fine_value, coarse_value))
        for coarse_value, fine_value in zip(coarse, fine)
    )
    bands = []
    decision_coarse: list[Vector] | None = None
    decision_fine: list[Vector] | None = None
    for requested_cutoff in BAND_CUTOFFS_HERTZ:
        filtered_coarse, maximum_mode, actual_cutoff = reconstruct_low_pass(
            coarse_coefficients, requested_cutoff
        )
        filtered_fine, _, _ = reconstruct_low_pass(
            fine_coefficients, requested_cutoff
        )
        filtered_difference = [
            subtract(fine_value, coarse_value)
            for coarse_value, fine_value in zip(filtered_coarse, filtered_fine)
        ]
        filtered_difference_energy = sum(energy(value) for value in filtered_difference)
        difference = pairwise_difference(filtered_coarse, filtered_fine)
        signal_retention = (
            sum(energy(value) for value in filtered_coarse)
            + sum(energy(value) for value in filtered_fine)
        ) / raw_signal_energy
        band = {
            "requestedCutoffHertz": requested_cutoff,
            "maximumRetainedDCTMode": maximum_mode,
            "actualMaximumRetainedFrequencyHertz": actual_cutoff,
            "combinedSignalEnergyRetentionFraction": signal_retention,
            "pairwiseNormalizedRMSDifference": difference,
            "improvementFromRawFraction": 1.0 - difference / raw_difference,
            "removedDifferenceEnergyFraction": 1.0
            - filtered_difference_energy / raw_difference_energy,
            "filteredDifferenceRoughness": roughness(filtered_difference),
        }
        bands.append(band)
        if requested_cutoff == DECISION_BAND_CUTOFF_HERTZ:
            decision_coarse = filtered_coarse
            decision_fine = filtered_fine
    decision_band = next(
        band for band in bands if band["requestedCutoffHertz"] == DECISION_BAND_CUTOFF_HERTZ
    )
    broadband_noise_likely = (
        not registration_likely
        and decision_band["combinedSignalEnergyRetentionFraction"]
        >= MINIMUM_DECISION_BAND_SIGNAL_ENERGY_RETENTION
        and decision_band["pairwiseNormalizedRMSDifference"]
        <= MAXIMUM_DECISION_BAND_PAIRWISE_DIFFERENCE
        and decision_band["improvementFromRawFraction"]
        >= MINIMUM_BAND_IMPROVEMENT_FRACTION
        and decision_band["removedDifferenceEnergyFraction"]
        >= MINIMUM_REMOVED_DIFFERENCE_ENERGY_FRACTION
    )
    coherent_grid_bias_likely = (
        not registration_likely
        and not broadband_noise_likely
        and decision_band["combinedSignalEnergyRetentionFraction"]
        >= MINIMUM_DECISION_BAND_SIGNAL_ENERGY_RETENTION
        and decision_band["pairwiseNormalizedRMSDifference"]
        > MAXIMUM_DECISION_BAND_PAIRWISE_DIFFERENCE
        and decision_band["filteredDifferenceRoughness"]
        <= MAXIMUM_COHERENT_LOW_BAND_ROUGHNESS
    )
    classification = (
        "sub-bin-registration-sensitive"
        if registration_likely
        else "broadband-force-estimator-noise"
        if broadband_noise_likely
        else "coherent-low-band-grid-bias"
        if coherent_grid_bias_likely
        else "mixed-unresolved"
    )
    raw_limit = float(discriminator["maximumAllowedFineGridRelativeDifference"])
    raw_miss_ratio = raw_difference / raw_limit
    d20_authorized = (
        coherent_grid_bias_likely
        and localization["topologyAssociation"]["topologyEventLikely"] is False
        and localization["accountingAssociation"]["accountingContaminationLikely"] is False
        and discriminator["allCaseGatesPassed"] is True
        and discriminator["monotonicTrendReductionPassed"] is True
        and discriminator["fineGridForceConvergencePassed"] is False
        and raw_miss_ratio <= MAXIMUM_FINE_GRID_MISS_RATIO_FOR_D20
    )
    if decision_coarse is None or decision_fine is None:
        raise SystemExit("decision band was not generated")
    decision_bins = []
    for index, (coarse_value, fine_value) in enumerate(
        zip(decision_coarse, decision_fine)
    ):
        decision_bins.append(
            {
                "targetSampleIndex": target_indices[index],
                "sourceTimeSeconds": times[index],
                "d12LowPassForceNewtons": coarse_value,
                "d16LowPassForceNewtons": fine_value,
                "d16MinusD12LowPassForceNewtons": subtract(
                    fine_value, coarse_value
                ),
            }
        )

    next_action = {
        "sub-bin-registration-sensitive": (
            "Audit and correct registered force-bin timestamp/endpoint semantics "
            "before any new grid run."
        ),
        "broadband-force-estimator-noise": (
            "Build a phase-consistent force-estimator temporal-aggregation canonical "
            "and require raw-impulse preservation before reconsidering refinement."
        ),
        "coherent-low-band-grid-bias": (
            "One preregistered D=20 case is authorized as an allocation test only."
        ),
        "mixed-unresolved": (
            "Keep D=20 blocked and isolate force-estimator sampling at fixed geometry."
        ),
    }[classification]
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/analyze-dove-moving-wall-spatial-lag-band.py",
        "datasetIdentifier": d16["datasetIdentifier"],
        "forceTargetIdentifier": d16["forceTargetIdentifier"],
        "sourceSHA256": {
            "d12Case": sha256(D12_PATH),
            "d16FullWindow": sha256(D16_PATH),
            "spatialDiscriminator": sha256(DISCRIMINATOR_PATH),
            "spatialLocalization": sha256(LOCALIZATION_PATH),
        },
        "fixedDecisionThresholds": {
            "sampleRateHertz": SAMPLE_RATE_HERTZ,
            "lagMinimumBins": LAG_MINIMUM_BINS,
            "lagMaximumBins": LAG_MAXIMUM_BINS,
            "lagIncrementBins": LAG_INCREMENT_BINS,
            "lagCrossValidationFolds": LAG_CROSS_VALIDATION_FOLDS,
            "minimumRegistrationLagBins": MINIMUM_REGISTRATION_LAG_BINS,
            "minimumRegistrationImprovementFraction": MINIMUM_REGISTRATION_IMPROVEMENT_FRACTION,
            "maximumRegistrationLagStandardDeviationBins": MAXIMUM_REGISTRATION_LAG_STANDARD_DEVIATION_BINS,
            "minimumRegistrationSignConsistency": MINIMUM_REGISTRATION_SIGN_CONSISTENCY,
            "bandCutoffsHertz": BAND_CUTOFFS_HERTZ,
            "decisionBandCutoffHertz": DECISION_BAND_CUTOFF_HERTZ,
            "minimumDecisionBandSignalEnergyRetention": MINIMUM_DECISION_BAND_SIGNAL_ENERGY_RETENTION,
            "maximumDecisionBandPairwiseDifference": MAXIMUM_DECISION_BAND_PAIRWISE_DIFFERENCE,
            "minimumBandImprovementFraction": MINIMUM_BAND_IMPROVEMENT_FRACTION,
            "minimumRemovedDifferenceEnergyFraction": MINIMUM_REMOVED_DIFFERENCE_ENERGY_FRACTION,
            "maximumCoherentLowBandRoughness": MAXIMUM_COHERENT_LOW_BAND_ROUGHNESS,
            "maximumFineGridMissRatioForD20": MAXIMUM_FINE_GRID_MISS_RATIO_FOR_D20,
        },
        "registeredComparisonBinCount": len(coarse),
        "rawPairwiseNormalizedRMSDifference": raw_difference,
        "rawLockedLimit": raw_limit,
        "rawLockedGatePassed": False,
        "lagDiscriminator": {
            "commonSupportBinCount": len(common_indices),
            "commonSupportBaselinePairwiseDifference": baseline_common,
            "globalBestLagBins": global_lag,
            "globalBestLagSeconds": global_lag / SAMPLE_RATE_HERTZ,
            "globalAlignedPairwiseDifference": global_aligned,
            "globalImprovementFraction": global_improvement,
            "crossValidatedBaselinePairwiseDifference": cross_validated_baseline,
            "crossValidatedAlignedPairwiseDifference": cross_validated_aligned,
            "crossValidatedImprovementFraction": cross_validated_improvement,
            "foldLagMeanBins": lag_mean,
            "foldLagStandardDeviationBins": lag_standard_deviation,
            "foldLagSignConsistency": sign_consistency,
            "subBinRegistrationSensitivityLikely": registration_likely,
            "folds": fold_reports,
        },
        "bandDiscriminator": {
            "bands": bands,
            "decisionBandCutoffHertz": DECISION_BAND_CUTOFF_HERTZ,
            "broadbandForceEstimatorNoiseLikely": broadband_noise_likely,
            "coherentLowBandGridBiasLikely": coherent_grid_bias_likely,
        },
        "classification": classification,
        "d20DiagnosticAuthorized": d20_authorized,
        "rawSpatialGateModified": False,
        "productionPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "nextAction": next_action,
        "scientificVerdict": (
            "The raw 6.268% gate remains failed. " + next_action
        ),
        "claimBoundary": (
            "This computed-history diagnostic cannot replace or retroactively "
            "pass the raw preregistered spatial metric. Low-pass results are "
            "mechanism evidence only, never experimental agreement or production "
            "promotion."
        ),
        "decisionBandBins": decision_bins,
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(
        json.dumps(
            {key: value for key, value in output.items() if key != "decisionBandBins"},
            indent=2,
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()

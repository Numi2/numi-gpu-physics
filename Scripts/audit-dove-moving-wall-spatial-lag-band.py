#!/usr/bin/env python3
"""Independently audit the D12/D16 lag and DCT-band discriminator."""

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
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-lag-band.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-lag-band-audit.json"

SAMPLE_RATE_HERTZ = 2_000.0
LAG_MINIMUM_BINS = -0.5
LAG_MAXIMUM_BINS = 0.5
LAG_INCREMENT_BINS = 0.01
FOLD_COUNT = 5
BAND_CUTOFFS_HERTZ = (50.0, 100.0, 200.0, 400.0, 1_000.0)
DECISION_CUTOFF_HERTZ = 200.0

Vector = tuple[float, float, float]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    return tuple(float(value) for value in raw)  # type: ignore[return-value]


def add(first: Vector, second: Vector) -> Vector:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def subtract(first: Vector, second: Vector) -> Vector:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def scale(value: Vector, factor: float) -> Vector:
    return tuple(component * factor for component in value)  # type: ignore[return-value]


def squared_norm(value: Vector) -> float:
    return sum(component * component for component in value)


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector) -> bool:
    return all(close(a, b, 2e-8) for a, b in zip(first, second))


def normalized_difference(first: list[Vector], second: list[Vector]) -> float:
    numerator = sum(squared_norm(subtract(a, b)) for a, b in zip(first, second))
    denominator = 0.5 * (
        sum(squared_norm(value) for value in first)
        + sum(squared_norm(value) for value in second)
    )
    return math.sqrt(numerator / max(denominator, 1e-30))


def interpolate(values: list[Vector], coordinate: float) -> Vector:
    lower = math.floor(coordinate)
    fraction = coordinate - lower
    if lower < 0 or lower + 1 >= len(values):
        raise ValueError("lag interpolation escaped common support")
    return add(scale(values[lower], 1.0 - fraction), scale(values[lower + 1], fraction))


def lag_terms(
    coarse: list[Vector], fine: list[Vector], indices: list[int], lag: float
) -> tuple[float, float]:
    selected_coarse = [coarse[index] for index in indices]
    selected_fine = [interpolate(fine, index + lag) for index in indices]
    numerator = sum(
        squared_norm(subtract(a, b)) for a, b in zip(selected_coarse, selected_fine)
    )
    denominator = 0.5 * (
        sum(squared_norm(value) for value in selected_coarse)
        + sum(squared_norm(value) for value in selected_fine)
    )
    return numerator, denominator


def choose_lag(
    coarse: list[Vector], fine: list[Vector], indices: list[int]
) -> tuple[float, float]:
    candidates = []
    count = round((LAG_MAXIMUM_BINS - LAG_MINIMUM_BINS) / LAG_INCREMENT_BINS)
    for offset in range(count + 1):
        lag = round(LAG_MINIMUM_BINS + offset * LAG_INCREMENT_BINS, 10)
        numerator, denominator = lag_terms(coarse, fine, indices, lag)
        difference = math.sqrt(numerator / max(denominator, 1e-30))
        candidates.append((difference, abs(lag), lag))
    difference, _, lag = min(candidates)
    return lag, difference


def dct(values: list[Vector]) -> list[Vector]:
    count = len(values)
    result: list[Vector] = [
        tuple(sum(value[axis] for value in values) / count for axis in range(3))  # type: ignore[arg-type]
    ]
    for mode in range(1, count):
        result.append(
            tuple(
                2.0
                / count
                * sum(
                    value[axis]
                    * math.cos(math.pi * (index + 0.5) * mode / count)
                    for index, value in enumerate(values)
                )
                for axis in range(3)
            )  # type: ignore[arg-type]
        )
    return result


def low_pass(coefficients: list[Vector], cutoff_hertz: float) -> tuple[list[Vector], int, float]:
    count = len(coefficients)
    maximum_mode = min(
        count - 1,
        math.floor(2.0 * count * cutoff_hertz / SAMPLE_RATE_HERTZ + 1e-12),
    )
    result: list[Vector] = []
    for index in range(count):
        value = coefficients[0]
        for mode in range(1, maximum_mode + 1):
            value = add(
                value,
                scale(
                    coefficients[mode],
                    math.cos(math.pi * (index + 0.5) * mode / count),
                ),
            )
        result.append(value)
    return result, maximum_mode, maximum_mode * SAMPLE_RATE_HERTZ / (2.0 * count)


def roughness(values: list[Vector]) -> float:
    signal_rms = math.sqrt(sum(squared_norm(value) for value in values) / len(values))
    changes = [subtract(values[index], values[index - 1]) for index in range(1, len(values))]
    change_rms = math.sqrt(sum(squared_norm(value) for value in changes) / len(changes))
    return change_rms / max(signal_rms, 1e-30)


def main() -> None:
    report = load(REPORT_PATH)
    d12 = load(D12_PATH)["fullWindowReport"]
    d16 = load(D16_PATH)
    discriminator = load(DISCRIMINATOR_PATH)
    localization = load(LOCALIZATION_PATH)
    d12_samples = d12["registeredForceSamples"]
    d16_samples = d16["registeredForceSamples"]
    coarse = [vector(item["intervalMeanComputedForceNewtons"]) for item in d12_samples]
    fine = [vector(item["intervalMeanComputedForceNewtons"]) for item in d16_samples]
    times = [float(item["sourceTimeSeconds"]) for item in d12_samples]
    target_indices = [int(item["targetSampleIndex"]) for item in d12_samples]
    axes_match = len(coarse) == len(fine) == int(report["registeredComparisonBinCount"])
    for coarse_item, fine_item in zip(d12_samples, d16_samples):
        axes_match &= int(coarse_item["targetSampleIndex"]) == int(fine_item["targetSampleIndex"])
        axes_match &= close(
            float(coarse_item["sourceTimeSeconds"]),
            float(fine_item["sourceTimeSeconds"]),
            1e-12,
        )

    raw_difference = normalized_difference(coarse, fine)
    common_indices = list(range(1, len(coarse) - 1))
    baseline_numerator, baseline_denominator = lag_terms(coarse, fine, common_indices, 0.0)
    common_baseline = math.sqrt(baseline_numerator / baseline_denominator)
    global_lag, global_aligned = choose_lag(coarse, fine, common_indices)
    global_improvement = 1.0 - global_aligned / common_baseline

    fold_size = math.ceil(len(common_indices) / FOLD_COUNT)
    fold_lags: list[float] = []
    fold_reports: list[dict] = []
    aggregate_baseline = [0.0, 0.0]
    aggregate_aligned = [0.0, 0.0]
    for fold in range(FOLD_COUNT):
        start = fold * fold_size
        stop = min(len(common_indices), start + fold_size)
        test_indices = common_indices[start:stop]
        if not test_indices:
            continue
        test_set = set(test_indices)
        training_indices = [index for index in common_indices if index not in test_set]
        selected_lag, training_difference = choose_lag(coarse, fine, training_indices)
        baseline_terms = lag_terms(coarse, fine, test_indices, 0.0)
        aligned_terms = lag_terms(coarse, fine, test_indices, selected_lag)
        baseline_difference = math.sqrt(baseline_terms[0] / baseline_terms[1])
        aligned_difference = math.sqrt(aligned_terms[0] / aligned_terms[1])
        fold_lags.append(selected_lag)
        aggregate_baseline[0] += baseline_terms[0]
        aggregate_baseline[1] += baseline_terms[1]
        aggregate_aligned[0] += aligned_terms[0]
        aggregate_aligned[1] += aligned_terms[1]
        fold_reports.append(
            {
                "fold": fold,
                "selectedTrainingLagBins": selected_lag,
                "trainingPairwiseDifference": training_difference,
                "testBaselinePairwiseDifference": baseline_difference,
                "testAlignedPairwiseDifference": aligned_difference,
            }
        )
    cv_baseline = math.sqrt(aggregate_baseline[0] / aggregate_baseline[1])
    cv_aligned = math.sqrt(aggregate_aligned[0] / aggregate_aligned[1])
    cv_improvement = 1.0 - cv_aligned / cv_baseline
    lag_mean = sum(fold_lags) / len(fold_lags)
    lag_sd = math.sqrt(sum((lag - lag_mean) ** 2 for lag in fold_lags) / len(fold_lags))
    global_sign = 1 if global_lag > 0 else -1 if global_lag < 0 else 0
    sign_consistency = sum(
        (1 if lag > 0 else -1 if lag < 0 else 0) == global_sign for lag in fold_lags
    ) / len(fold_lags)

    thresholds = report["fixedDecisionThresholds"]
    expected_thresholds = {
        "sampleRateHertz": 2_000.0,
        "lagMinimumBins": -0.5,
        "lagMaximumBins": 0.5,
        "lagIncrementBins": 0.01,
        "lagCrossValidationFolds": 5,
        "minimumRegistrationLagBins": 0.05,
        "minimumRegistrationImprovementFraction": 0.20,
        "maximumRegistrationLagStandardDeviationBins": 0.15,
        "minimumRegistrationSignConsistency": 0.80,
        "bandCutoffsHertz": list(BAND_CUTOFFS_HERTZ),
        "decisionBandCutoffHertz": 200.0,
        "minimumDecisionBandSignalEnergyRetention": 0.99,
        "maximumDecisionBandPairwiseDifference": 0.05,
        "minimumBandImprovementFraction": 0.20,
        "minimumRemovedDifferenceEnergyFraction": 0.25,
        "maximumCoherentLowBandRoughness": 0.50,
        "maximumFineGridMissRatioForD20": 1.50,
    }
    registration_likely = (
        abs(global_lag) >= thresholds["minimumRegistrationLagBins"]
        and cv_improvement >= thresholds["minimumRegistrationImprovementFraction"]
        and lag_sd <= thresholds["maximumRegistrationLagStandardDeviationBins"]
        and sign_consistency >= thresholds["minimumRegistrationSignConsistency"]
    )

    coarse_coefficients = dct(coarse)
    fine_coefficients = dct(fine)
    raw_signal_energy = sum(squared_norm(value) for value in coarse + fine)
    raw_difference_energy = sum(
        squared_norm(subtract(a, b)) for a, b in zip(coarse, fine)
    )
    reconstructed_bands: list[dict] = []
    decision_coarse: list[Vector] = []
    decision_fine: list[Vector] = []
    for cutoff in BAND_CUTOFFS_HERTZ:
        filtered_coarse, maximum_mode, actual_cutoff = low_pass(coarse_coefficients, cutoff)
        filtered_fine, _, _ = low_pass(fine_coefficients, cutoff)
        filtered_difference = [subtract(a, b) for a, b in zip(filtered_fine, filtered_coarse)]
        difference = normalized_difference(filtered_coarse, filtered_fine)
        retention = sum(
            squared_norm(value) for value in filtered_coarse + filtered_fine
        ) / raw_signal_energy
        reconstructed_bands.append(
            {
                "requestedCutoffHertz": cutoff,
                "maximumRetainedDCTMode": maximum_mode,
                "actualMaximumRetainedFrequencyHertz": actual_cutoff,
                "combinedSignalEnergyRetentionFraction": retention,
                "pairwiseNormalizedRMSDifference": difference,
                "improvementFromRawFraction": 1.0 - difference / raw_difference,
                "removedDifferenceEnergyFraction": 1.0
                - sum(squared_norm(value) for value in filtered_difference)
                / raw_difference_energy,
                "filteredDifferenceRoughness": roughness(filtered_difference),
            }
        )
        if cutoff == DECISION_CUTOFF_HERTZ:
            decision_coarse = filtered_coarse
            decision_fine = filtered_fine
    decision_band = next(
        band for band in reconstructed_bands if band["requestedCutoffHertz"] == DECISION_CUTOFF_HERTZ
    )
    broadband_likely = (
        not registration_likely
        and decision_band["combinedSignalEnergyRetentionFraction"]
        >= thresholds["minimumDecisionBandSignalEnergyRetention"]
        and decision_band["pairwiseNormalizedRMSDifference"]
        <= thresholds["maximumDecisionBandPairwiseDifference"]
        and decision_band["improvementFromRawFraction"]
        >= thresholds["minimumBandImprovementFraction"]
        and decision_band["removedDifferenceEnergyFraction"]
        >= thresholds["minimumRemovedDifferenceEnergyFraction"]
    )
    coherent_likely = (
        not registration_likely
        and not broadband_likely
        and decision_band["combinedSignalEnergyRetentionFraction"]
        >= thresholds["minimumDecisionBandSignalEnergyRetention"]
        and decision_band["pairwiseNormalizedRMSDifference"]
        > thresholds["maximumDecisionBandPairwiseDifference"]
        and decision_band["filteredDifferenceRoughness"]
        <= thresholds["maximumCoherentLowBandRoughness"]
    )
    classification = (
        "sub-bin-registration-sensitive"
        if registration_likely
        else "broadband-force-estimator-noise"
        if broadband_likely
        else "coherent-low-band-grid-bias"
        if coherent_likely
        else "mixed-unresolved"
    )
    miss_ratio = raw_difference / float(discriminator["maximumAllowedFineGridRelativeDifference"])
    d20_authorized = (
        coherent_likely
        and localization["topologyAssociation"]["topologyEventLikely"] is False
        and localization["accountingAssociation"]["accountingContaminationLikely"] is False
        and discriminator["allCaseGatesPassed"] is True
        and discriminator["monotonicTrendReductionPassed"] is True
        and discriminator["fineGridForceConvergencePassed"] is False
        and miss_ratio <= thresholds["maximumFineGridMissRatioForD20"]
    )

    lag = report["lagDiscriminator"]
    lag_arithmetic = (
        int(lag["commonSupportBinCount"]) == len(common_indices)
        and close(lag["commonSupportBaselinePairwiseDifference"], common_baseline)
        and close(lag["globalBestLagBins"], global_lag)
        and close(lag["globalAlignedPairwiseDifference"], global_aligned)
        and close(lag["globalImprovementFraction"], global_improvement)
        and close(lag["crossValidatedBaselinePairwiseDifference"], cv_baseline)
        and close(lag["crossValidatedAlignedPairwiseDifference"], cv_aligned)
        and close(lag["crossValidatedImprovementFraction"], cv_improvement)
        and close(lag["foldLagMeanBins"], lag_mean)
        and close(lag["foldLagStandardDeviationBins"], lag_sd)
        and close(lag["foldLagSignConsistency"], sign_consistency)
        and lag["subBinRegistrationSensitivityLikely"] is registration_likely
    )
    folds_match = len(lag["folds"]) == len(fold_reports)
    for expected, actual in zip(fold_reports, lag["folds"]):
        folds_match &= int(actual["fold"]) == expected["fold"]
        folds_match &= close(actual["selectedTrainingLagBins"], expected["selectedTrainingLagBins"])
        folds_match &= close(actual["trainingPairwiseDifference"], expected["trainingPairwiseDifference"])
        folds_match &= close(actual["testBaselinePairwiseDifference"], expected["testBaselinePairwiseDifference"])
        folds_match &= close(actual["testAlignedPairwiseDifference"], expected["testAlignedPairwiseDifference"])

    bands_match = len(report["bandDiscriminator"]["bands"]) == len(reconstructed_bands)
    for expected, actual in zip(reconstructed_bands, report["bandDiscriminator"]["bands"]):
        for key, expected_value in expected.items():
            if isinstance(expected_value, int):
                bands_match &= int(actual[key]) == expected_value
            else:
                bands_match &= close(float(actual[key]), float(expected_value))

    bins_match = len(report["decisionBandBins"]) == len(coarse)
    for index, actual in enumerate(report["decisionBandBins"]):
        bins_match &= int(actual["targetSampleIndex"]) == target_indices[index]
        bins_match &= close(float(actual["sourceTimeSeconds"]), times[index])
        bins_match &= vector_close(vector(actual["d12LowPassForceNewtons"]), decision_coarse[index])
        bins_match &= vector_close(vector(actual["d16LowPassForceNewtons"]), decision_fine[index])
        bins_match &= vector_close(
            vector(actual["d16MinusD12LowPassForceNewtons"]),
            subtract(decision_fine[index], decision_coarse[index]),
        )

    expected_hashes = {
        "d12Case": sha256(D12_PATH),
        "d16FullWindow": sha256(D16_PATH),
        "spatialDiscriminator": sha256(DISCRIMINATOR_PATH),
        "spatialLocalization": sha256(LOCALIZATION_PATH),
    }
    checks = {
        "sourceHashes": report["sourceSHA256"] == expected_hashes,
        "fixedThresholds": thresholds == expected_thresholds,
        "registeredAxes": axes_match,
        "rawArithmetic": close(report["rawPairwiseNormalizedRMSDifference"], raw_difference)
        and close(report["rawLockedLimit"], discriminator["maximumAllowedFineGridRelativeDifference"])
        and report["rawLockedGatePassed"] is False,
        "lagArithmetic": lag_arithmetic,
        "crossValidationFolds": folds_match,
        "bandArithmetic": bands_match,
        "decisionBandBins": bins_match,
        "classification": report["classification"] == classification
        and report["bandDiscriminator"]["broadbandForceEstimatorNoiseLikely"] is broadband_likely
        and report["bandDiscriminator"]["coherentLowBandGridBiasLikely"] is coherent_likely,
        "d20Decision": report["d20DiagnosticAuthorized"] is d20_authorized and not d20_authorized,
        "claimBoundary": report["rawSpatialGateModified"] is False
        and report["productionPromotionAuthorized"] is False
        and report["experimentalAgreementGateApplied"] is False,
    }
    passed = all(checks.values())
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-spatial-lag-band.py",
        "reportSHA256": sha256(REPORT_PATH),
        "checks": checks,
        "reconstructed": {
            "rawPairwiseNormalizedRMSDifference": raw_difference,
            "globalBestLagBins": global_lag,
            "crossValidatedImprovementFraction": cv_improvement,
            "foldLagsBins": fold_lags,
            "decisionBandSignalEnergyRetentionFraction": decision_band[
                "combinedSignalEnergyRetentionFraction"
            ],
            "decisionBandPairwiseNormalizedRMSDifference": decision_band[
                "pairwiseNormalizedRMSDifference"
            ],
            "classification": classification,
            "d20DiagnosticAuthorized": d20_authorized,
        },
        "allChecksPassed": passed,
        "claimBoundary": (
            "Independent source-hash, raw-history, lag, cross-validation, DCT-band, "
            "per-bin, classification, and allocation-decision audit. A pass authenticates "
            "the unresolved rejection; it does not establish convergence or permit filtering "
            "the preregistered raw metric."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("lag/band audit failed: " + ", ".join(failed))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

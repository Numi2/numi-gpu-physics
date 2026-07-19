#!/usr/bin/env python3
"""Analyze the preregistered D=8 RR3 shedding period and block mean."""

from __future__ import annotations

import argparse
import cmath
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
SOURCE = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-duration.json"
)
PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-preregistration.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period.json"
)

T_975 = {
    1: 12.706,
    2: 4.303,
    3: 3.182,
    4: 2.776,
    5: 2.571,
    6: 2.447,
    7: 2.365,
    8: 2.306,
    9: 2.262,
    10: 2.228,
    11: 2.201,
    12: 2.179,
    13: 2.160,
    14: 2.145,
    15: 2.131,
    16: 2.120,
    17: 2.110,
    18: 2.101,
    19: 2.093,
    20: 2.086,
    21: 2.080,
    22: 2.074,
    23: 2.069,
    24: 2.064,
    25: 2.060,
    26: 2.056,
    27: 2.052,
    28: 2.048,
    29: 2.045,
    30: 2.042,
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative_difference(first: float, second: float) -> float:
    return abs(first - second) / max(abs(first), abs(second), 1e-300)


def detrend(times: list[float], values: list[float]) -> list[float]:
    mean_t = math.fsum(times) / len(times)
    mean_y = math.fsum(values) / len(values)
    denominator = math.fsum((time - mean_t) ** 2 for time in times)
    slope = math.fsum(
        (time - mean_t) * (value - mean_y)
        for time, value in zip(times, values)
    ) / denominator
    return [
        value - (mean_y + slope * (time - mean_t))
        for time, value in zip(times, values)
    ]


def fourier_period(
    times: list[float],
    values: list[float],
    minimum_frequency: float,
    maximum_frequency: float,
    exclusion_bins: int,
) -> dict[str, float | int]:
    residual = detrend(times, values)
    dt = math.fsum(
        times[index + 1] - times[index]
        for index in range(len(times) - 1)
    ) / (len(times) - 1)
    frequencies = [index / (len(times) * dt) for index in range(len(times) // 2 + 1)]
    selected = [
        index
        for index, frequency in enumerate(frequencies)
        if minimum_frequency <= frequency <= maximum_frequency
    ]
    powers: dict[int, float] = {}
    origin = times[0]
    for index in selected:
        frequency = frequencies[index]
        terms = [
            value * cmath.exp(-2j * math.pi * frequency * (time - origin))
            for time, value in zip(times, residual)
        ]
        amplitude = complex(
            math.fsum(term.real for term in terms),
            math.fsum(term.imag for term in terms),
        )
        powers[index] = abs(amplitude) ** 2
    peak_index = max(selected, key=powers.__getitem__)
    runner_indices = [
        index
        for index in selected
        if abs(index - peak_index) > exclusion_bins
    ]
    runner_power = max((powers[index] for index in runner_indices), default=0.0)
    peak_power = powers[peak_index]

    refined_index = float(peak_index)
    if peak_index - 1 in powers and peak_index + 1 in powers:
        left = math.log(max(powers[peak_index - 1], 1e-300))
        center = math.log(max(peak_power, 1e-300))
        right = math.log(max(powers[peak_index + 1], 1e-300))
        denominator = left - 2 * center + right
        if abs(denominator) > 1e-15:
            refined_index += 0.5 * (left - right) / denominator
    frequency = refined_index / (len(times) * dt)
    return {
        "sampleCount": len(times),
        "sampleSpacingConvectiveTime": dt,
        "peakBinIndex": peak_index,
        "frequencyCyclesPerConvectiveTime": frequency,
        "periodConvectiveTimes": 1 / frequency,
        "peakPower": peak_power,
        "runnerUpPower": runner_power,
        "dominantToRunnerUpPowerRatio": peak_power / max(runner_power, 1e-300),
    }


def autocorrelation_period(
    times: list[float],
    values: list[float],
    minimum_period: float,
    maximum_period: float,
) -> dict[str, float | int]:
    residual = detrend(times, values)
    denominator = math.fsum(value * value for value in residual)
    dt = math.fsum(
        times[index + 1] - times[index]
        for index in range(len(times) - 1)
    ) / (len(times) - 1)
    minimum_lag = max(1, math.ceil(minimum_period / dt))
    maximum_lag = min(len(times) - 2, math.floor(maximum_period / dt))
    correlations = {
        lag: math.fsum(
            residual[index] * residual[index + lag]
            for index in range(len(residual) - lag)
        ) / max(denominator, 1e-300)
        for lag in range(minimum_lag, maximum_lag + 1)
    }
    local_maxima = [
        lag
        for lag in range(minimum_lag + 1, maximum_lag)
        if correlations[lag] > 0
        and correlations[lag] >= correlations[lag - 1]
        and correlations[lag] > correlations[lag + 1]
    ]
    if not local_maxima:
        raise SystemExit("no positive in-band autocorrelation maximum")
    peak_lag = max(local_maxima, key=correlations.__getitem__)
    refined_lag = float(peak_lag)
    left = correlations[peak_lag - 1]
    center = correlations[peak_lag]
    right = correlations[peak_lag + 1]
    curvature = left - 2 * center + right
    if abs(curvature) > 1e-15:
        refined_lag += 0.5 * (left - right) / curvature
    return {
        "peakLagSamples": peak_lag,
        "peakCorrelation": center,
        "periodConvectiveTimes": refined_lag * dt,
    }


def interpolate(times: list[float], values: list[float], target: float) -> float:
    if target <= times[0]:
        return values[0]
    if target >= times[-1]:
        return values[-1]
    low = 0
    high = len(times) - 1
    while high - low > 1:
        middle = (low + high) // 2
        if times[middle] <= target:
            low = middle
        else:
            high = middle
    fraction = (target - times[low]) / (times[high] - times[low])
    return values[low] + fraction * (values[high] - values[low])


def interval_mean(
    times: list[float], values: list[float], start: float, end: float
) -> float:
    points = [(start, interpolate(times, values, start))]
    points.extend(
        (time, value)
        for time, value in zip(times, values)
        if start < time < end
    )
    points.append((end, interpolate(times, values, end)))
    integral = math.fsum(
        0.5 * (first[1] + second[1]) * (second[0] - first[0])
        for first, second in zip(points, points[1:])
    )
    return integral / (end - start)


def block_statistics(
    times: list[float],
    values: list[float],
    start: float,
    end: float,
    period: float,
) -> dict[str, object]:
    count = int(math.floor((end - start + 1e-12) / period))
    blocks = []
    for index in range(count):
        block_start = start + index * period
        block_end = block_start + period
        blocks.append(
            {
                "index": index,
                "startConvectiveTime": block_start,
                "endConvectiveTime": block_end,
                "meanDragCoefficient": interval_mean(
                    times, values, block_start, block_end
                ),
            }
        )
    means = [block["meanDragCoefficient"] for block in blocks]
    mean = math.fsum(means) / max(len(means), 1)
    variance = (
        math.fsum((value - mean) ** 2 for value in means) / (len(means) - 1)
        if len(means) >= 2
        else math.inf
    )
    standard_error = math.sqrt(variance / len(means)) if means else math.inf
    t_value = T_975.get(len(means) - 1, 1.96)
    confidence_half_width = t_value * standard_error
    split = max(1, len(means) // 2)
    first_mean = math.fsum(means[:split]) / max(split, 1)
    second_count = len(means) - split
    second_mean = (
        math.fsum(means[split:]) / second_count if second_count else math.nan
    )
    return {
        "blocks": blocks,
        "blockCount": len(blocks),
        "meanDragCoefficient": mean,
        "sampleStandardDeviation": math.sqrt(variance),
        "standardError": standard_error,
        "studentT975": t_value,
        "confidence95HalfWidth": confidence_half_width,
        "relativeConfidence95HalfWidth": confidence_half_width / max(abs(mean), 1e-300),
        "firstHalfMeanDragCoefficient": first_mean,
        "secondHalfMeanDragCoefficient": second_mean,
        "firstHalfSecondHalfRelativeDifference": relative_difference(
            first_mean, second_mean
        ),
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=SOURCE)
    parser.add_argument("--preregistration", type=Path, default=PREREGISTRATION)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    source_path = arguments.source.resolve()
    preregistration_path = arguments.preregistration.resolve()
    output_path = arguments.output.resolve()
    source = json.loads(source_path.read_text(encoding="utf-8"))
    prereg = json.loads(preregistration_path.read_text(encoding="utf-8"))
    preregistration_identifier = prereg.get("preregistrationIdentifier")
    if preregistration_identifier == "stationary-wall-rr3-d8-period-v1":
        source_hash_field = "sourceDurationReportSHA256"
        cases = {
            item["numericalCase"]["diameterCells"]: item["numericalCase"]
            for item in source.get("cases", [])
        }
    elif preregistration_identifier == "stationary-wall-rr3-d8-period-v2":
        source_hash_field = "sourceExtensionReportSHA256"
        numerical_case = source.get("numericalCase", {})
        cases = {numerical_case.get("diameterCells"): numerical_case}
    else:
        raise SystemExit("unsupported period-analysis preregistration")
    if not (
        prereg.get("schemaVersion") == 1
        and prereg.get("passed")
        and prereg.get(source_hash_field) == digest(source_path)
        and source.get("passed")
        and source.get("allIndividualGatesPassed")
    ):
        raise SystemExit("period analysis inputs do not match preregistration")
    case = cases[prereg["selectedDiameterCells"]]
    selected = [
        sample
        for sample in case["samples"]
        if prereg["analysisStartConvectiveTimeInclusive"] - 1e-12
        <= sample["convectiveTime"]
        <= prereg["analysisEndConvectiveTimeInclusive"] + 1e-12
    ]
    times = [sample["convectiveTime"] for sample in selected]
    values = [sample["dragCoefficient"] for sample in selected]
    minimum_frequency = prereg["minimumFrequencyCyclesPerConvectiveTime"]
    maximum_frequency = prereg["maximumFrequencyCyclesPerConvectiveTime"]
    spectrum = fourier_period(
        times,
        values,
        minimum_frequency,
        maximum_frequency,
        prereg["runnerUpExclusionBinsAroundPeak"],
    )
    autocorrelation = autocorrelation_period(
        times,
        values,
        1 / maximum_frequency,
        1 / minimum_frequency,
    )
    middle = len(times) // 2
    first_half = fourier_period(
        times[: middle + 1],
        values[: middle + 1],
        minimum_frequency,
        maximum_frequency,
        prereg["runnerUpExclusionBinsAroundPeak"],
    )
    second_half = fourier_period(
        times[middle:],
        values[middle:],
        minimum_frequency,
        maximum_frequency,
        prereg["runnerUpExclusionBinsAroundPeak"],
    )
    fourier_autocorrelation_difference = relative_difference(
        spectrum["periodConvectiveTimes"],
        autocorrelation["periodConvectiveTimes"],
    )
    split_half_difference = relative_difference(
        first_half["periodConvectiveTimes"],
        second_half["periodConvectiveTimes"],
    )
    period_identification_passed = (
        spectrum["dominantToRunnerUpPowerRatio"]
        >= prereg["minimumDominantToRunnerUpPowerRatio"]
        and fourier_autocorrelation_difference
        <= prereg["maximumFourierAutocorrelationPeriodRelativeDifference"]
        and split_half_difference
        <= prereg["maximumSplitHalfPeriodRelativeDifference"]
    )
    statistics = block_statistics(
        times,
        values,
        prereg["analysisStartConvectiveTimeInclusive"],
        prereg["analysisEndConvectiveTimeInclusive"],
        spectrum["periodConvectiveTimes"],
    )
    period_complete_statistic_passed = (
        period_identification_passed
        and statistics["blockCount"]
        >= prereg["minimumCompletePeriodBlockCount"]
        and statistics["relativeConfidence95HalfWidth"]
        <= prereg["maximumRelative95ConfidenceHalfWidth"]
        and statistics["firstHalfSecondHalfRelativeDifference"]
        <= prereg["maximumFirstHalfSecondHalfBlockMeanRelativeDifference"]
    )
    if period_complete_statistic_passed:
        classification = "period-complete-drag-statistic-accepted"
        verdict = (
            "The D=8 RR3 wake has a reproducible in-band shedding period and a "
            "stable complete-period drag estimate under the frozen uncertainty gates."
        )
        next_action = (
            "D20 planning is authorized under a new preregistration; RR3 remains "
            "excluded from bird replay until the spatial ladder itself converges."
        )
    elif period_identification_passed:
        classification = "period-identified-drag-statistic-unresolved"
        verdict = (
            "The D=8 shedding period is identified, but the existing archive is too "
            "short or nonstationary for the frozen complete-period uncertainty gate."
        )
        next_action = (
            "Extend only D=8 by enough complete shedding periods to pass the frozen "
            "block-count, confidence-width, and early/late-mean gates."
        )
    else:
        classification = "d8-shedding-period-unresolved"
        verdict = (
            "The D=8 archive does not identify one stable dominant shedding period "
            "under the frozen Fourier, autocorrelation, and split-half gates."
        )
        next_action = (
            "Extend only D=8 before D20 and repeat this unchanged period contract."
        )
    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": preregistration_identifier,
        source_hash_field: digest(source_path),
        "sourcePreregistrationSHA256": digest(preregistration_path),
        "diameterCells": case["diameterCells"],
        "analysisStartConvectiveTime": times[0],
        "analysisEndConvectiveTime": times[-1],
        "analysisSampleCount": len(times),
        "fourier": spectrum,
        "autocorrelation": autocorrelation,
        "firstHalfFourier": first_half,
        "secondHalfFourier": second_half,
        "fourierAutocorrelationPeriodRelativeDifference": fourier_autocorrelation_difference,
        "splitHalfPeriodRelativeDifference": split_half_difference,
        "periodIdentificationPassed": period_identification_passed,
        "periodCompleteBlocks": statistics,
        "periodCompleteStatisticPassed": period_complete_statistic_passed,
        "d20PlanningAuthorized": (
            period_complete_statistic_passed
            and prereg["d20PlanningAuthorizedOnPass"]
        ),
        "fluidEvolutionExecuted": False,
        "productionModificationAuthorized": False,
        "rr3BirdReplayPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "classification": classification,
        "scientificVerdict": verdict,
        "nextAction": next_action,
        "claimBoundary": prereg["claimBoundary"],
        "passed": True,
    }
    output_path.write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

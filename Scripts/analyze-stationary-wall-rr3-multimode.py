#!/usr/bin/env python3
"""Apply the preregistered D=8 RR3 full-force multimode discriminator."""

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
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode.json"
)
PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-preregistration.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-analysis.json"
)
ORIGINAL_CAPTURE = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode.json"
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


def band_spectrum(
    times: list[float],
    signals: list[list[float]],
    minimum_frequency: float,
    maximum_frequency: float,
    exclusion_bins: int,
) -> dict[str, float | int]:
    residuals = [detrend(times, signal) for signal in signals]
    dt = math.fsum(
        times[index + 1] - times[index]
        for index in range(len(times) - 1)
    ) / (len(times) - 1)
    frequencies = [
        index / (len(times) * dt) for index in range(len(times) // 2 + 1)
    ]
    selected = [
        index
        for index, frequency in enumerate(frequencies)
        if minimum_frequency <= frequency <= maximum_frequency
    ]
    if not selected:
        raise SystemExit("frequency band has no native Fourier bin")
    powers: dict[int, float] = {}
    origin = times[0]
    for index in selected:
        frequency = frequencies[index]
        combined_power = 0.0
        for residual in residuals:
            terms = [
                value * cmath.exp(-2j * math.pi * frequency * (time - origin))
                for time, value in zip(times, residual)
            ]
            amplitude = complex(
                math.fsum(term.real for term in terms),
                math.fsum(term.imag for term in terms),
            )
            combined_power += abs(amplitude) ** 2
        powers[index] = combined_power
    peak_index = max(selected, key=powers.__getitem__)
    runner_indices = [
        index for index in selected if abs(index - peak_index) > exclusion_bins
    ]
    peak_power = powers[peak_index]
    runner_power = max((powers[index] for index in runner_indices), default=0.0)

    refined_index = float(peak_index)
    if peak_index - 1 in powers and peak_index + 1 in powers:
        left = math.log(max(powers[peak_index - 1], 1e-300))
        center = math.log(max(peak_power, 1e-300))
        right = math.log(max(powers[peak_index + 1], 1e-300))
        curvature = left - 2 * center + right
        if abs(curvature) > 1e-15:
            refined_index += 0.5 * (left - right) / curvature
    frequency = refined_index / (len(times) * dt)
    return {
        "sampleCount": len(times),
        "sampleSpacingConvectiveTime": dt,
        "signalComponentCount": len(signals),
        "minimumFrequencyCyclesPerConvectiveTime": minimum_frequency,
        "maximumFrequencyCyclesPerConvectiveTime": maximum_frequency,
        "peakBinIndex": peak_index,
        "frequencyCyclesPerConvectiveTime": frequency,
        "periodConvectiveTimes": 1 / frequency,
        "peakPower": peak_power,
        "runnerUpPower": runner_power,
        "dominantToRunnerUpPowerRatio": peak_power / max(runner_power, 1e-300),
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
        "relativeConfidence95HalfWidth": confidence_half_width
        / max(abs(mean), 1e-300),
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
    case = source.get("numericalCase", {})
    identifier = prereg.get("preregistrationIdentifier")
    if identifier == "stationary-wall-rr3-d8-multimode-v1":
        provenance_passed = bool(prereg.get("sourceExtensionReportSHA256"))
    elif identifier == "stationary-wall-rr3-d8-multimode-duration-v2":
        original_capture = json.loads(ORIGINAL_CAPTURE.read_text(encoding="utf-8"))
        original_samples = original_capture["numericalCase"]["samples"]
        provenance_passed = (
            prereg.get("sourceMultimodeCaptureSHA256")
            == digest(ORIGINAL_CAPTURE)
            and case.get("samples", [])[: len(original_samples)] == original_samples
        )
    else:
        raise SystemExit("unsupported multimode preregistration")
    if not (
        prereg.get("schemaVersion") == 1
        and prereg.get("passed")
        and provenance_passed
        and source.get("passed")
        and source.get("allIndividualGatesPassed")
        and source.get("forceVectorSamplesArchived")
        and source.get("requestedConvectiveTimes")
        == prereg.get("requestedConvectiveTimes")
        and case.get("diameterCells") == prereg.get("selectedDiameterCells")
        and len(case.get("samples", [])) == prereg.get("requestedSteps")
    ):
        raise SystemExit("passing preregistered multimode force capture required")

    start = prereg["analysisStartConvectiveTimeInclusive"]
    end = prereg["analysisEndConvectiveTimeInclusive"]
    selected = [
        sample
        for sample in case["samples"]
        if start - 1e-12 <= sample["convectiveTime"] <= end + 1e-12
    ]
    times = [sample["convectiveTime"] for sample in selected]
    drag = [sample["dragCoefficient"] for sample in selected]
    transverse_y = [sample["transverseForceCoefficientY"] for sample in selected]
    transverse_z = [sample["transverseForceCoefficientZ"] for sample in selected]
    bands = {
        "low": prereg["lowModeFrequencyBandCyclesPerConvectiveTimeInclusive"],
        "drag": prereg[
            "dragHarmonicFrequencyBandCyclesPerConvectiveTimeInclusive"
        ],
        "shear": prereg[
            "shearLayerFrequencyBandCyclesPerConvectiveTimeInclusive"
        ],
    }
    exclusion = prereg["runnerUpExclusionBinsAroundPeak"]
    low_mode = band_spectrum(
        times, [transverse_y, transverse_z], *bands["low"], exclusion
    )
    drag_harmonic = band_spectrum(times, [drag], *bands["drag"], exclusion)
    shear_layer = band_spectrum(
        times, [transverse_y, transverse_z], *bands["shear"], exclusion
    )
    middle = len(times) // 2
    first_half = band_spectrum(
        times[: middle + 1],
        [transverse_y[: middle + 1], transverse_z[: middle + 1]],
        *bands["low"],
        exclusion,
    )
    second_half = band_spectrum(
        times[middle:],
        [transverse_y[middle:], transverse_z[middle:]],
        *bands["low"],
        exclusion,
    )
    split_difference = relative_difference(
        first_half["frequencyCyclesPerConvectiveTime"],
        second_half["frequencyCyclesPerConvectiveTime"],
    )
    harmonic_difference = relative_difference(
        drag_harmonic["frequencyCyclesPerConvectiveTime"],
        2 * low_mode["frequencyCyclesPerConvectiveTime"],
    )
    low_mode_identified = (
        low_mode["dominantToRunnerUpPowerRatio"]
        >= prereg["minimumLowModeDominantToRunnerUpPowerRatio"]
        and split_difference
        <= prereg["maximumLowModeSplitHalfFrequencyRelativeDifference"]
        and harmonic_difference
        <= prereg["maximumDragToTwiceLowModeFrequencyRelativeDifference"]
    )
    statistics = block_statistics(
        times, drag, start, end, low_mode["periodConvectiveTimes"]
    )
    period_complete_statistic_passed = (
        low_mode_identified
        and statistics["blockCount"]
        >= prereg["minimumCompleteLowModeBlockCount"]
        and statistics["relativeConfidence95HalfWidth"]
        <= prereg["maximumRelative95ConfidenceHalfWidth"]
        and statistics["firstHalfSecondHalfRelativeDifference"]
        <= prereg["maximumFirstHalfSecondHalfBlockMeanRelativeDifference"]
    )
    if period_complete_statistic_passed:
        classification = "d8-low-wake-mode-and-period-complete-drag-accepted"
        verdict = (
            "The D=8 vector force resolves a stable literature-bounded low wake "
            "mode separately from its drag harmonic, and complete low-mode periods "
            "produce a stable mean-drag statistic under the frozen uncertainty gates."
        )
        next_action = (
            "D20 planning is authorized under a new spatial-refinement "
            "preregistration; no D20 result or RR3 bird-replay promotion is implied."
        )
    elif low_mode_identified:
        classification = "d8-low-wake-mode-identified-drag-statistic-unresolved"
        verdict = (
            "The D=8 vector force resolves the low wake mode and drag harmonic, but "
            "the complete-period mean-drag uncertainty gates remain unresolved."
        )
        next_action = (
            "Keep D20 blocked and extend only the D=8 vector-force history by enough "
            "complete low-mode periods to repeat the unchanged block statistic."
        )
    else:
        classification = "d8-multimode-force-history-unresolved"
        verdict = (
            "The D=8 vector-force history does not resolve a stable low wake mode "
            "and its drag harmonic under the literature-bounded frozen gates."
        )
        next_action = (
            "Keep D20 blocked; test D=8 grid-orientation sensitivity before spending "
            "on a finer spatial ladder."
        )

    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": identifier,
        "sourceCaptureReportSHA256": digest(source_path),
        "sourcePreregistrationSHA256": digest(preregistration_path),
        "diameterCells": case["diameterCells"],
        "analysisStartConvectiveTime": times[0],
        "analysisEndConvectiveTime": times[-1],
        "analysisSampleCount": len(times),
        "lowTransverseMode": low_mode,
        "dragHarmonic": drag_harmonic,
        "shearLayerBand": shear_layer,
        "firstHalfLowTransverseMode": first_half,
        "secondHalfLowTransverseMode": second_half,
        "lowModeSplitHalfFrequencyRelativeDifference": split_difference,
        "dragToTwiceLowModeFrequencyRelativeDifference": harmonic_difference,
        "lowModeIdentified": low_mode_identified,
        "completeLowModePeriodDrag": statistics,
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

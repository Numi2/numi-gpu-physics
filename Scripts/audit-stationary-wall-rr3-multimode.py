#!/usr/bin/env python3
"""Independently reconstruct both preregistered D=8 RR3 multimode decisions."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-audit.json"
)
CASES = [
    {
        "name": "thirty-time-v1",
        "source": ARTIFACTS
        / "measured-wing-stationary-wall-recursive-regularization-d8-multimode.json",
        "preregistration": ARTIFACTS
        / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-preregistration.json",
        "analysis": ARTIFACTS
        / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-analysis.json",
    },
    {
        "name": "sixty-time-v2",
        "source": ARTIFACTS
        / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-duration.json",
        "preregistration": ARTIFACTS
        / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-duration-preregistration.json",
        "analysis": ARTIFACTS
        / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-duration-analysis.json",
    },
]

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


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def relative_difference(first: float, second: float) -> float:
    return abs(first - second) / max(abs(first), abs(second), 1e-300)


def residual(times: list[float], values: list[float]) -> list[float]:
    count = len(times)
    sum_t = math.fsum(times)
    sum_y = math.fsum(values)
    sum_tt = math.fsum(value * value for value in times)
    sum_ty = math.fsum(time * value for time, value in zip(times, values))
    denominator = count * sum_tt - sum_t * sum_t
    slope = (count * sum_ty - sum_t * sum_y) / denominator
    intercept = (sum_y - slope * sum_t) / count
    return [value - intercept - slope * time for time, value in zip(times, values)]


def band(
    times: list[float],
    signals: list[list[float]],
    limits: list[float],
    excluded_neighbors: int,
) -> dict[str, float]:
    step = math.fsum(
        right - left for left, right in zip(times, times[1:])
    ) / (len(times) - 1)
    duration = len(times) * step
    spectra = [residual(times, signal) for signal in signals]
    indices = [
        index
        for index in range(len(times) // 2 + 1)
        if limits[0] <= index / duration <= limits[1]
    ]
    powers = {}
    for index in indices:
        frequency = index / duration
        total = 0.0
        for values in spectra:
            real = math.fsum(
                value * math.cos(2 * math.pi * frequency * (time - times[0]))
                for time, value in zip(times, values)
            )
            imaginary = -math.fsum(
                value * math.sin(2 * math.pi * frequency * (time - times[0]))
                for time, value in zip(times, values)
            )
            total += real * real + imaginary * imaginary
        powers[index] = total
    peak = max(indices, key=powers.__getitem__)
    runner = max(
        (
            powers[index]
            for index in indices
            if abs(index - peak) > excluded_neighbors
        ),
        default=0.0,
    )
    refined = float(peak)
    if peak - 1 in powers and peak + 1 in powers:
        left = math.log(max(powers[peak - 1], 1e-300))
        center = math.log(max(powers[peak], 1e-300))
        right = math.log(max(powers[peak + 1], 1e-300))
        curvature = left - 2 * center + right
        if abs(curvature) > 1e-15:
            refined += 0.5 * (left - right) / curvature
    frequency = refined / duration
    return {
        "frequency": frequency,
        "powerRatio": powers[peak] / max(runner, 1e-300),
    }


def interpolate(times: list[float], values: list[float], target: float) -> float:
    low = 0
    high = len(times) - 1
    while high - low > 1:
        middle = (low + high) // 2
        if times[middle] <= target:
            low = middle
        else:
            high = middle
    if target <= times[0]:
        return values[0]
    if target >= times[-1]:
        return values[-1]
    fraction = (target - times[low]) / (times[high] - times[low])
    return values[low] + fraction * (values[high] - values[low])


def average_between(
    times: list[float], values: list[float], start: float, end: float
) -> float:
    points = [(start, interpolate(times, values, start))]
    points += [
        pair
        for pair in zip(times, values)
        if start < pair[0] < end
    ]
    points.append((end, interpolate(times, values, end)))
    area = math.fsum(
        (right[0] - left[0]) * (left[1] + right[1]) / 2
        for left, right in zip(points, points[1:])
    )
    return area / (end - start)


def blocks(
    times: list[float],
    drag: list[float],
    start: float,
    end: float,
    frequency: float,
) -> dict[str, float | int]:
    period = 1 / frequency
    count = math.floor((end - start + 1e-12) / period)
    means = [
        average_between(
            times,
            drag,
            start + index * period,
            start + (index + 1) * period,
        )
        for index in range(count)
    ]
    mean = math.fsum(means) / count
    variance = (
        math.fsum((value - mean) ** 2 for value in means) / (count - 1)
        if count >= 2
        else math.inf
    )
    half_width = T_975.get(count - 1, 1.96) * math.sqrt(variance / count)
    split = max(1, count // 2)
    first = math.fsum(means[:split]) / split
    second = math.fsum(means[split:]) / (count - split) if count > split else math.nan
    return {
        "count": count,
        "mean": mean,
        "relativeCI": half_width / max(abs(mean), 1e-300),
        "earlyLate": relative_difference(first, second),
    }


def close(first: float, second: float) -> bool:
    return math.isclose(first, second, rel_tol=2e-11, abs_tol=2e-12)


def audit_case(configuration: dict[str, object]) -> dict[str, object]:
    source_path = configuration["source"]
    prereg_path = configuration["preregistration"]
    analysis_path = configuration["analysis"]
    source = json.loads(source_path.read_text(encoding="utf-8"))
    prereg = json.loads(prereg_path.read_text(encoding="utf-8"))
    analysis = json.loads(analysis_path.read_text(encoding="utf-8"))
    start = prereg["analysisStartConvectiveTimeInclusive"]
    end = prereg["analysisEndConvectiveTimeInclusive"]
    samples = [
        sample
        for sample in source["numericalCase"]["samples"]
        if start - 1e-12 <= sample["convectiveTime"] <= end + 1e-12
    ]
    times = [sample["convectiveTime"] for sample in samples]
    drag = [sample["dragCoefficient"] for sample in samples]
    y_force = [sample["transverseForceCoefficientY"] for sample in samples]
    z_force = [sample["transverseForceCoefficientZ"] for sample in samples]
    excluded = prereg["runnerUpExclusionBinsAroundPeak"]
    low = band(
        times,
        [y_force, z_force],
        prereg["lowModeFrequencyBandCyclesPerConvectiveTimeInclusive"],
        excluded,
    )
    drag_mode = band(
        times,
        [drag],
        prereg["dragHarmonicFrequencyBandCyclesPerConvectiveTimeInclusive"],
        excluded,
    )
    shear = band(
        times,
        [y_force, z_force],
        prereg["shearLayerFrequencyBandCyclesPerConvectiveTimeInclusive"],
        excluded,
    )
    middle = len(times) // 2
    early = band(
        times[: middle + 1],
        [y_force[: middle + 1], z_force[: middle + 1]],
        prereg["lowModeFrequencyBandCyclesPerConvectiveTimeInclusive"],
        excluded,
    )
    late = band(
        times[middle:],
        [y_force[middle:], z_force[middle:]],
        prereg["lowModeFrequencyBandCyclesPerConvectiveTimeInclusive"],
        excluded,
    )
    split_difference = relative_difference(early["frequency"], late["frequency"])
    harmonic_difference = relative_difference(
        drag_mode["frequency"], 2 * low["frequency"]
    )
    low_identified = (
        low["powerRatio"] >= prereg["minimumLowModeDominantToRunnerUpPowerRatio"]
        and split_difference
        <= prereg["maximumLowModeSplitHalfFrequencyRelativeDifference"]
        and harmonic_difference
        <= prereg["maximumDragToTwiceLowModeFrequencyRelativeDifference"]
    )
    statistic = blocks(times, drag, start, end, low["frequency"])
    statistic_passed = (
        low_identified
        and statistic["count"] >= prereg["minimumCompleteLowModeBlockCount"]
        and statistic["relativeCI"]
        <= prereg["maximumRelative95ConfidenceHalfWidth"]
        and statistic["earlyLate"]
        <= prereg["maximumFirstHalfSecondHalfBlockMeanRelativeDifference"]
    )
    if statistic_passed:
        classification = "d8-low-wake-mode-and-period-complete-drag-accepted"
    elif low_identified:
        classification = "d8-low-wake-mode-identified-drag-statistic-unresolved"
    else:
        classification = "d8-multimode-force-history-unresolved"

    checks = {
        "sourceHash": analysis["sourceCaptureReportSHA256"] == sha256(source_path),
        "preregistrationHash": analysis["sourcePreregistrationSHA256"]
        == sha256(prereg_path),
        "sampleCount": analysis["analysisSampleCount"] == len(samples),
        "lowFrequency": close(
            analysis["lowTransverseMode"]["frequencyCyclesPerConvectiveTime"],
            low["frequency"],
        ),
        "lowPowerRatio": close(
            analysis["lowTransverseMode"]["dominantToRunnerUpPowerRatio"],
            low["powerRatio"],
        ),
        "earlyLowFrequency": close(
            analysis["firstHalfLowTransverseMode"]["frequencyCyclesPerConvectiveTime"],
            early["frequency"],
        ),
        "lateLowFrequency": close(
            analysis["secondHalfLowTransverseMode"]["frequencyCyclesPerConvectiveTime"],
            late["frequency"],
        ),
        "dragFrequency": close(
            analysis["dragHarmonic"]["frequencyCyclesPerConvectiveTime"],
            drag_mode["frequency"],
        ),
        "shearFrequency": close(
            analysis["shearLayerBand"]["frequencyCyclesPerConvectiveTime"],
            shear["frequency"],
        ),
        "splitDifference": close(
            analysis["lowModeSplitHalfFrequencyRelativeDifference"],
            split_difference,
        ),
        "harmonicDifference": close(
            analysis["dragToTwiceLowModeFrequencyRelativeDifference"],
            harmonic_difference,
        ),
        "blockCount": analysis["completeLowModePeriodDrag"]["blockCount"]
        == statistic["count"],
        "blockMean": close(
            analysis["completeLowModePeriodDrag"]["meanDragCoefficient"],
            statistic["mean"],
        ),
        "confidence": close(
            analysis["completeLowModePeriodDrag"]["relativeConfidence95HalfWidth"],
            statistic["relativeCI"],
        ),
        "earlyLate": close(
            analysis["completeLowModePeriodDrag"]["firstHalfSecondHalfRelativeDifference"],
            statistic["earlyLate"],
        ),
        "lowDecision": analysis["lowModeIdentified"] == low_identified,
        "statisticDecision": analysis["periodCompleteStatisticPassed"]
        == statistic_passed,
        "classification": analysis["classification"] == classification,
        "d20Decision": analysis["d20PlanningAuthorized"]
        == (statistic_passed and prereg["d20PlanningAuthorizedOnPass"]),
    }
    return {
        "name": configuration["name"],
        "sourceSHA256": sha256(source_path),
        "preregistrationSHA256": sha256(prereg_path),
        "analysisSHA256": sha256(analysis_path),
        "checks": checks,
        "passed": all(checks.values()),
    }


def main() -> None:
    results = [audit_case(configuration) for configuration in CASES]
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": "stationary-wall-rr3-d8-multimode-independent-v1",
        "implementation": (
            "standalone scalar OLS, trigonometric DFT, trapezoidal block integration, "
            "Student-t uncertainty, and decision reconstruction"
        ),
        "results": results,
        "passed": all(result["passed"] for result in results),
    }
    OUTPUT.write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not artifact["passed"]:
        raise SystemExit("multimode audit failed")


if __name__ == "__main__":
    main()

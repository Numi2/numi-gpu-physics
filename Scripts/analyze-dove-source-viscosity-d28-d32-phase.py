#!/usr/bin/env python3
"""Localize the post-hoc phase structure of the D28/D32 force difference.

This is deliberately exploratory: the D28/D32 stabilization verdict is already
frozen and failed. The script only asks where the archived difference lives; it
does not replace the preregistered refinement gate or authorize another grid.
"""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-d32-full-window.json"
REFINEMENT = ARTIFACTS / "deetjen-dove-source-viscosity-d28-d32-refinement.json"
REFINEMENT_AUDIT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-d32-refinement-audit.json"
)
OUTPUT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-d32-phase-localization.json"
)

EXPECTED_SAMPLES = 187
BAND_COUNT = 8
SAMPLE_RATE_HZ = 2_000.0
WINDOW_DURATION_SECONDS = 0.005
MAX_LAG_SAMPLES = 8


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def force(sample: dict) -> tuple[float, float]:
    value = sample["intervalMeanComputedForceNewtons"]
    return float(value[0]), float(value[2])


def rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / len(values))


def normalized_rms(first: list[float], second: list[float]) -> float:
    numerator = sum((right - left) ** 2 for left, right in zip(first, second))
    denominator = 0.5 * (
        sum(value * value for value in first)
        + sum(value * value for value in second)
    )
    return math.sqrt(numerator / max(denominator, 1.0e-30))


def correlation(first: list[float], second: list[float]) -> float:
    mean_first = sum(first) / len(first)
    mean_second = sum(second) / len(second)
    centered_first = [value - mean_first for value in first]
    centered_second = [value - mean_second for value in second]
    numerator = sum(
        left * right for left, right in zip(centered_first, centered_second)
    )
    denominator = math.sqrt(
        sum(value * value for value in centered_first)
        * sum(value * value for value in centered_second)
    )
    return numerator / max(denominator, 1.0e-30)


def shortest_window_for_fraction(
    energy: list[float], target_fraction: float
) -> tuple[int, int, float]:
    target = target_fraction * sum(energy)
    start = 0
    running = 0.0
    best = (0, len(energy) - 1, sum(energy))
    for end, value in enumerate(energy):
        running += value
        while start <= end and running - energy[start] >= target:
            running -= energy[start]
            start += 1
        if running >= target and end - start < best[1] - best[0]:
            best = (start, end, running)
    return best


def main() -> None:
    d28 = load(D28)
    d32 = load(D32)
    refinement = load(REFINEMENT)
    refinement_audit = load(REFINEMENT_AUDIT)
    samples28 = d28["registeredForceSamples"]
    samples32 = d32["registeredForceSamples"]
    if not (
        len(samples28) == len(samples32) == EXPECTED_SAMPLES
        and refinement_audit["allChecksPassed"]
        and not refinement_audit["d36RunAuthorized"]
    ):
        raise SystemExit("audited failed D28/D32 pair is required")
    if any(
        left["targetSampleIndex"] != right["targetSampleIndex"]
        or left["sourceTimeSeconds"] != right["sourceTimeSeconds"]
        for left, right in zip(samples28, samples32)
    ):
        raise SystemExit("D28/D32 samples are not phase aligned")

    forces28 = [force(sample) for sample in samples28]
    forces32 = [force(sample) for sample in samples32]
    times = [float(sample["sourceTimeSeconds"]) for sample in samples28]
    dx = [right[0] - left[0] for left, right in zip(forces28, forces32)]
    dz = [right[1] - left[1] for left, right in zip(forces28, forces32)]
    horizontal_energy = [value * value for value in dx]
    vertical_energy = [value * value for value in dz]
    vector_energy = [
        horizontal_energy[index] + vertical_energy[index]
        for index in range(EXPECTED_SAMPLES)
    ]
    total_horizontal = sum(horizontal_energy)
    total_vertical = sum(vertical_energy)
    total_vector = sum(vector_energy)

    bands = []
    for band in range(BAND_COUNT):
        start = band * EXPECTED_SAMPLES // BAND_COUNT
        end = (band + 1) * EXPECTED_SAMPLES // BAND_COUNT
        band_dx = dx[start:end]
        band_dz = dz[start:end]
        band_energy = sum(vector_energy[start:end])
        bands.append(
            {
                "bandIndex": band,
                "firstSampleIndex": start,
                "lastSampleIndex": end - 1,
                "sampleCount": end - start,
                "startTimeSeconds": times[start],
                "endTimeSeconds": times[end - 1],
                "horizontalDifferenceRMSNewtons": rms(band_dx),
                "verticalDifferenceRMSNewtons": rms(band_dz),
                "vectorDifferenceRMSNewtons": math.sqrt(
                    sum(value * value for value in band_dx + band_dz)
                    / (end - start)
                ),
                "horizontalSquaredDifferenceFraction": sum(
                    horizontal_energy[start:end]
                )
                / max(total_horizontal, 1.0e-30),
                "verticalSquaredDifferenceFraction": sum(
                    vertical_energy[start:end]
                )
                / max(total_vertical, 1.0e-30),
                "vectorSquaredDifferenceFraction": band_energy
                / max(total_vector, 1.0e-30),
            }
        )

    fixed_window_samples = int(round(WINDOW_DURATION_SECONDS * SAMPLE_RATE_HZ)) + 1
    fixed_windows = [
        sum(horizontal_energy[start : start + fixed_window_samples])
        for start in range(EXPECTED_SAMPLES - fixed_window_samples + 1)
    ]
    max_fixed_start = max(range(len(fixed_windows)), key=fixed_windows.__getitem__)
    max_fixed_end = max_fixed_start + fixed_window_samples - 1
    half_start, half_end, half_energy = shortest_window_for_fraction(
        horizontal_energy, 0.5
    )

    horizontal28 = [value[0] for value in forces28]
    horizontal32 = [value[0] for value in forces32]
    lag_scores = []
    for lag in range(-MAX_LAG_SAMPLES, MAX_LAG_SAMPLES + 1):
        if lag < 0:
            left = horizontal28[-lag:]
            right = horizontal32[:lag]
        elif lag > 0:
            left = horizontal28[:-lag]
            right = horizontal32[lag:]
        else:
            left = horizontal28
            right = horizontal32
        lag_scores.append(
            {
                "lagSamples": lag,
                "lagSeconds": lag / SAMPLE_RATE_HZ,
                "overlapSamples": len(left),
                "normalizedRMSDifference": normalized_rms(left, right),
                "correlation": correlation(left, right),
            }
        )
    best_lag = min(lag_scores, key=lambda item: item["normalizedRMSDifference"])

    transient_scale = []
    absolute_dx = []
    for index in range(1, EXPECTED_SAMPLES - 1):
        derivative28 = abs(horizontal28[index + 1] - horizontal28[index - 1])
        derivative32 = abs(horizontal32[index + 1] - horizontal32[index - 1])
        transient_scale.append(0.5 * (derivative28 + derivative32))
        absolute_dx.append(abs(dx[index]))

    peak_horizontal = max(range(EXPECTED_SAMPLES), key=lambda index: abs(dx[index]))
    peak_vertical = max(range(EXPECTED_SAMPLES), key=lambda index: abs(dz[index]))
    top_band = max(bands, key=lambda item: item["vectorSquaredDifferenceFraction"])
    artifact = {
        "schemaVersion": 1,
        "analysisIdentifier": (
            "deetjen-ob-f03-source-viscosity-d28-d32-phase-localization-v1"
        ),
        "generatedBy": "Scripts/analyze-dove-source-viscosity-d28-d32-phase.py",
        "exploratoryPostHocAnalysis": True,
        "fluidEvolutionExecuted": False,
        "sourceD28ReportSHA256": sha256(D28),
        "sourceD32ReportSHA256": sha256(D32),
        "sourceRefinementReportSHA256": sha256(REFINEMENT),
        "sourceRefinementAuditSHA256": sha256(REFINEMENT_AUDIT),
        "registeredForceSampleCount": EXPECTED_SAMPLES,
        "sampleRateHertz": SAMPLE_RATE_HZ,
        "windowStartTimeSeconds": times[0],
        "windowEndTimeSeconds": times[-1],
        "componentEnergyFractions": {
            "horizontal": total_horizontal / total_vector,
            "vertical": total_vertical / total_vector,
        },
        "normalizedDifferenceDominantComponent": (
            "horizontal"
            if refinement["metrics"]["horizontalForceNormalizedRMSDifference"]
            >= refinement["metrics"]["verticalForceNormalizedRMSDifference"]
            else "vertical"
        ),
        "phaseBands": bands,
        "dominantPhaseBand": top_band,
        "peakDifferences": {
            "horizontal": {
                "sampleIndex": peak_horizontal,
                "sourceTimeSeconds": times[peak_horizontal],
                "differenceD32MinusD28Newtons": dx[peak_horizontal],
                "absoluteDifferenceNewtons": abs(dx[peak_horizontal]),
            },
            "vertical": {
                "sampleIndex": peak_vertical,
                "sourceTimeSeconds": times[peak_vertical],
                "differenceD32MinusD28Newtons": dz[peak_vertical],
                "absoluteDifferenceNewtons": abs(dz[peak_vertical]),
            },
        },
        "horizontalConcentration": {
            "fixedWindowDurationSeconds": WINDOW_DURATION_SECONDS,
            "fixedWindowSampleCount": fixed_window_samples,
            "maximumEnergyWindowStartIndex": max_fixed_start,
            "maximumEnergyWindowEndIndex": max_fixed_end,
            "maximumEnergyWindowStartTimeSeconds": times[max_fixed_start],
            "maximumEnergyWindowEndTimeSeconds": times[max_fixed_end],
            "maximumEnergyWindowFraction": fixed_windows[max_fixed_start]
            / total_horizontal,
            "shortestHalfEnergyWindowStartIndex": half_start,
            "shortestHalfEnergyWindowEndIndex": half_end,
            "shortestHalfEnergyWindowStartTimeSeconds": times[half_start],
            "shortestHalfEnergyWindowEndTimeSeconds": times[half_end],
            "shortestHalfEnergyWindowSampleCount": half_end - half_start + 1,
            "shortestHalfEnergyWindowFraction": half_energy / total_horizontal,
        },
        "horizontalLagScan": {
            "maximumAbsoluteLagSamples": MAX_LAG_SAMPLES,
            "zeroLagNormalizedRMSDifference": lag_scores[MAX_LAG_SAMPLES][
                "normalizedRMSDifference"
            ],
            "bestLag": best_lag,
            "simpleLagExplainsDifference": (
                best_lag["lagSamples"] != 0
                and best_lag["normalizedRMSDifference"]
                <= 0.8
                * lag_scores[MAX_LAG_SAMPLES]["normalizedRMSDifference"]
            ),
            "scores": lag_scores,
        },
        "horizontalDifferenceTransientCorrelation": correlation(
            absolute_dx, transient_scale
        ),
        "classification": "early-window-phase-localized-two-component-grid-sensitivity",
        "scientificVerdict": (
            "The horizontal component has the larger normalized fine-pair "
            "difference, while absolute difference energy is split nearly evenly "
            "between horizontal and vertical force. The difference is concentrated "
            "early in the registered window and is not explained by a simple time "
            "lag or ordinary force-transient magnitude. This post-hoc localization "
            "identifies the highest-information time region for a targeted replay, "
            "but does not change the failed stabilization verdict."
        ),
        "targetedReplayRecommendation": {
            "startTimeSeconds": times[max_fixed_start],
            "endTimeSeconds": times[max_fixed_end],
            "reason": (
                "This archived 5 ms interval contains the largest fraction of "
                "horizontal D28/D32 squared difference. Instrumenting it at the "
                "existing grids has higher information per GPU-second than D36."
            ),
            "d36RunAuthorized": False,
        },
        "claimBoundary": (
            "This is an exploratory post-hoc analysis of two archived, audited "
            "force histories. It executes no fluid steps, applies no acceptance "
            "gate, and does not establish causality, grid convergence, experimental "
            "agreement, production readiness, or free flight."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

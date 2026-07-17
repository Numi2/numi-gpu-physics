#!/usr/bin/env python3
"""Independently audit the post-hoc D28/D32 phase localization."""

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
REPORT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-d32-phase-localization.json"
)
OUTPUT = (
    ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-phase-localization-audit.json"
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 1.0e-12) -> bool:
    return math.isclose(first, second, rel_tol=tolerance, abs_tol=tolerance)


def force(sample: dict) -> tuple[float, float]:
    value = sample["intervalMeanComputedForceNewtons"]
    return float(value[0]), float(value[2])


def normalized_rms(first: list[float], second: list[float]) -> float:
    numerator = sum((right - left) ** 2 for left, right in zip(first, second))
    denominator = 0.5 * (
        sum(value * value for value in first)
        + sum(value * value for value in second)
    )
    return math.sqrt(numerator / max(denominator, 1.0e-30))


def main() -> None:
    d28 = load(D28)
    d32 = load(D32)
    refinement = load(REFINEMENT)
    refinement_audit = load(REFINEMENT_AUDIT)
    report = load(REPORT)
    samples28 = d28["registeredForceSamples"]
    samples32 = d32["registeredForceSamples"]
    times = [float(sample["sourceTimeSeconds"]) for sample in samples28]
    forces28 = [force(sample) for sample in samples28]
    forces32 = [force(sample) for sample in samples32]
    dx = [right[0] - left[0] for left, right in zip(forces28, forces32)]
    dz = [right[1] - left[1] for left, right in zip(forces28, forces32)]
    horizontal_energy = [value * value for value in dx]
    vertical_energy = [value * value for value in dz]
    vector_energy = [
        horizontal_energy[index] + vertical_energy[index]
        for index in range(len(dx))
    ]
    total_horizontal = sum(horizontal_energy)
    total_vertical = sum(vertical_energy)
    total_vector = sum(vector_energy)

    band_count = 8
    band_vector_fractions = []
    for band in range(band_count):
        start = band * len(dx) // band_count
        end = (band + 1) * len(dx) // band_count
        band_vector_fractions.append(sum(vector_energy[start:end]) / total_vector)
    dominant_band = max(
        range(band_count), key=band_vector_fractions.__getitem__
    )

    fixed_samples = 11
    fixed_energies = [
        sum(horizontal_energy[start : start + fixed_samples])
        for start in range(len(dx) - fixed_samples + 1)
    ]
    fixed_start = max(range(len(fixed_energies)), key=fixed_energies.__getitem__)
    peak_horizontal = max(range(len(dx)), key=lambda index: abs(dx[index]))
    peak_vertical = max(range(len(dz)), key=lambda index: abs(dz[index]))

    horizontal28 = [value[0] for value in forces28]
    horizontal32 = [value[0] for value in forces32]
    lag_scores = {}
    for lag in range(-8, 9):
        if lag < 0:
            left = horizontal28[-lag:]
            right = horizontal32[:lag]
        elif lag > 0:
            left = horizontal28[:-lag]
            right = horizontal32[lag:]
        else:
            left = horizontal28
            right = horizontal32
        lag_scores[lag] = normalized_rms(left, right)
    best_lag = min(lag_scores, key=lag_scores.__getitem__)

    archived_components = report["componentEnergyFractions"]
    archived_band = report["dominantPhaseBand"]
    archived_concentration = report["horizontalConcentration"]
    archived_peaks = report["peakDifferences"]
    archived_lag = report["horizontalLagScan"]
    checks = {
        "sourceHashes": report["sourceD28ReportSHA256"] == sha256(D28)
        and report["sourceD32ReportSHA256"] == sha256(D32)
        and report["sourceRefinementReportSHA256"] == sha256(REFINEMENT)
        and report["sourceRefinementAuditSHA256"] == sha256(REFINEMENT_AUDIT),
        "sourceVerdict": not refinement["finePairStabilizationPassed"]
        and not refinement_audit["d36RunAuthorized"],
        "alignedSamples": len(samples28) == len(samples32) == 187
        and all(
            left["targetSampleIndex"] == right["targetSampleIndex"]
            and left["sourceTimeSeconds"] == right["sourceTimeSeconds"]
            for left, right in zip(samples28, samples32)
        ),
        "componentFractions": close(
            archived_components["horizontal"], total_horizontal / total_vector
        )
        and close(archived_components["vertical"], total_vertical / total_vector),
        "normalizedDominantComponent": report[
            "normalizedDifferenceDominantComponent"
        ]
        == (
            "horizontal"
            if refinement["metrics"]["horizontalForceNormalizedRMSDifference"]
            >= refinement["metrics"]["verticalForceNormalizedRMSDifference"]
            else "vertical"
        ),
        "dominantBand": archived_band["bandIndex"] == dominant_band == 0
        and close(
            archived_band["vectorSquaredDifferenceFraction"],
            band_vector_fractions[dominant_band],
        ),
        "fixedWindow": archived_concentration["fixedWindowSampleCount"]
        == fixed_samples
        and archived_concentration["maximumEnergyWindowStartIndex"]
        == fixed_start
        and close(
            archived_concentration["maximumEnergyWindowFraction"],
            fixed_energies[fixed_start] / total_horizontal,
        ),
        "peakHorizontal": archived_peaks["horizontal"]["sampleIndex"]
        == peak_horizontal
        and close(
            archived_peaks["horizontal"]["absoluteDifferenceNewtons"],
            abs(dx[peak_horizontal]),
        ),
        "peakVertical": archived_peaks["vertical"]["sampleIndex"]
        == peak_vertical
        and close(
            archived_peaks["vertical"]["absoluteDifferenceNewtons"],
            abs(dz[peak_vertical]),
        ),
        "lagScan": archived_lag["bestLag"]["lagSamples"] == best_lag == 0
        and close(
            archived_lag["zeroLagNormalizedRMSDifference"], lag_scores[0]
        )
        and not archived_lag["simpleLagExplainsDifference"],
        "targetedInterval": close(
            report["targetedReplayRecommendation"]["startTimeSeconds"],
            times[fixed_start],
        )
        and close(
            report["targetedReplayRecommendation"]["endTimeSeconds"],
            times[fixed_start + fixed_samples - 1],
        ),
        "exploratoryBoundary": report["exploratoryPostHocAnalysis"]
        and not report["fluidEvolutionExecuted"]
        and not report["targetedReplayRecommendation"]["d36RunAuthorized"],
        "classification": report["classification"]
        == "early-window-phase-localized-two-component-grid-sensitivity",
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise SystemExit("phase-localization audit failed: " + ", ".join(failed))
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": (
            "deetjen-ob-f03-source-viscosity-d28-d32-phase-localization-audit-v1"
        ),
        "generatedBy": "Scripts/audit-dove-source-viscosity-d28-d32-phase.py",
        "reportSHA256": sha256(REPORT),
        "independentReconstruction": {
            "horizontalEnergyFraction": total_horizontal / total_vector,
            "verticalEnergyFraction": total_vertical / total_vector,
            "dominantBandIndex": dominant_band,
            "dominantBandVectorDifferenceFraction": band_vector_fractions[
                dominant_band
            ],
            "maximumFiveMillisecondHorizontalDifferenceFraction": fixed_energies[
                fixed_start
            ]
            / total_horizontal,
            "maximumFiveMillisecondWindowStartTimeSeconds": times[fixed_start],
            "maximumFiveMillisecondWindowEndTimeSeconds": times[
                fixed_start + fixed_samples - 1
            ],
            "bestHorizontalLagSamples": best_lag,
        },
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": True,
        "targetedD28D32ReplaySupported": True,
        "d36RunAuthorized": False,
        "claimBoundary": (
            "This independent audit reproduces the location, component split, "
            "peaks, and zero-lag result from archived force histories only. It "
            "does not establish cause, convergence, agreement, or production use."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

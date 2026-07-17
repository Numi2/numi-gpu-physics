#!/usr/bin/env python3
"""Exploratory force-shape diagnosis after the preregistered D28 run."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
D16 = ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window.json"
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window.json"
D28_AUDIT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window-audit.json"
)
OUTPUT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-force-diagnosis.json"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def histories(report: dict) -> tuple[np.ndarray, np.ndarray]:
    samples = report["registeredForceSamples"]
    measured = np.asarray(
        [
            [sample["measuredForceXNewtons"], sample["measuredForceZNewtons"]]
            for sample in samples
        ],
        dtype=np.float64,
    )
    computed = np.asarray(
        [
            [
                sample["intervalMeanComputedForceNewtons"][0],
                sample["intervalMeanComputedForceNewtons"][2],
            ]
            for sample in samples
        ],
        dtype=np.float64,
    )
    return measured, computed


def normalized_rms(reference: np.ndarray, candidate: np.ndarray) -> float:
    return float(
        np.sqrt(
            np.sum(np.square(candidate - reference))
            / max(float(np.sum(np.square(reference))), 1.0e-30)
        )
    )


def symmetric_difference(first: np.ndarray, second: np.ndarray) -> float:
    denominator = 0.5 * (
        float(np.sum(np.square(first))) + float(np.sum(np.square(second)))
    )
    return float(
        np.sqrt(np.sum(np.square(second - first)) / max(denominator, 1.0e-30))
    )


def overlap(
    measured: np.ndarray, computed: np.ndarray, lag: int
) -> tuple[np.ndarray, np.ndarray]:
    if lag >= 0:
        return measured[lag:], computed[: len(measured) - lag]
    return measured[: len(measured) + lag], computed[-lag:]


def component_metrics(measured: np.ndarray, computed: np.ndarray) -> dict:
    best_raw = None
    best_correlation = None
    for lag in range(-50, 51):
        reference, candidate = overlap(measured, computed, lag)
        raw_error = normalized_rms(reference, candidate)
        correlation = float(np.corrcoef(reference, candidate)[0, 1])
        raw_record = (raw_error, lag, len(reference), correlation)
        correlation_record = (correlation, lag, len(reference), raw_error)
        if best_raw is None or raw_record[0] < best_raw[0]:
            best_raw = raw_record
        if best_correlation is None or correlation_record[0] > best_correlation[0]:
            best_correlation = correlation_record
    return {
        "normalizedRMSError": normalized_rms(measured, computed),
        "pearsonCorrelation": float(np.corrcoef(measured, computed)[0, 1]),
        "meanMeasuredNewtons": float(np.mean(measured)),
        "meanComputedNewtons": float(np.mean(computed)),
        "meanBiasNewtons": float(np.mean(computed - measured)),
        "meanComputedToMeasuredRatio": float(np.mean(computed) / np.mean(measured)),
        "bestRawErrorLagSamples": int(best_raw[1]),
        "bestRawErrorLagMilliseconds": 0.5 * int(best_raw[1]),
        "bestRawLagNormalizedRMSError": float(best_raw[0]),
        "bestCorrelationLagSamples": int(best_correlation[1]),
        "bestCorrelationLagMilliseconds": 0.5 * int(best_correlation[1]),
        "bestLagPearsonCorrelation": float(best_correlation[0]),
    }


def main() -> None:
    d16 = json.loads(D16.read_text())
    d28 = json.loads(D28.read_text())
    audit = json.loads(D28_AUDIT.read_text())
    if not d28["fullWindowGatePassed"] or not audit["allChecksPassed"]:
        raise SystemExit("D28 force diagnosis requires the audited full-window pass")
    measured, computed_d28 = histories(d28)
    measured_d16, computed_d16 = histories(d16)
    if not np.array_equal(measured, measured_d16):
        raise SystemExit("D16 and D28 force targets are not sample-aligned")

    d16_error = normalized_rms(measured, computed_d16)
    d28_error = normalized_rms(measured, computed_d28)
    report = {
        "schemaVersion": 1,
        "analysisIdentifier": "deetjen-ob-f03-source-viscosity-d28-force-diagnosis-v1",
        "generatedBy": "Scripts/analyze-dove-source-viscosity-d28-force.py",
        "sourceD16FullWindowSHA256": sha256(D16),
        "sourceD28FullWindowSHA256": sha256(D28),
        "sourceD28FullWindowAuditSHA256": sha256(D28_AUDIT),
        "exploratoryPostHocAnalysis": True,
        "sampleCount": int(len(measured)),
        "jointForceMetrics": {
            "d16OverViscousNormalizedRMSError": d16_error,
            "d28SourceViscosityNormalizedRMSError": d28_error,
            "relativeNormalizedRMSErrorImprovementFromD16Percent": float(
                100.0 * (d16_error - d28_error) / d16_error
            ),
            "d16ToD28SymmetricNormalizedDifference": symmetric_difference(
                computed_d16, computed_d28
            ),
        },
        "horizontalForceMetrics": component_metrics(
            measured[:, 0], computed_d28[:, 0]
        ),
        "verticalForceMetrics": component_metrics(
            measured[:, 1], computed_d28[:, 1]
        ),
        "classification": (
            "vertical-shape-correlated-but-amplitude-biased-with-"
            "horizontal-force-mismatch"
        ),
        "scientificInterpretation": (
            "The D28 source-viscosity result retains a recognizable vertical-"
            "force shape but overpredicts its mean, while horizontal force has "
            "weak shape agreement and a large mean deficit. The modest change "
            "from the older D16 over-viscous result does not isolate grid from "
            "viscosity effects and does not support experimental agreement."
        ),
        "nextAction": (
            "Preregister a single RR3 D32 source-viscosity pre-roll. Advance to "
            "a D32 full window only if positivity, both momentum ledgers, tau "
            "margin, working set, and correction intrusion pass unchanged; use "
            "D28/D32 only for same-physics force refinement, not as a promise "
            "that refinement will resolve the measured-force mismatch."
        ),
        "claimBoundary": (
            "This is explicitly post-hoc exploratory decomposition of an "
            "already accepted numerical artifact. Lag searches and component "
            "metrics were not preregistered and cannot promote experimental "
            "agreement, grid convergence, production physics, or free flight."
        ),
    }
    OUTPUT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

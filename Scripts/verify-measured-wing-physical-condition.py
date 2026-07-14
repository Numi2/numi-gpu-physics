#!/usr/bin/env python3
"""Verify the locked Maeda/Dong physical-condition arithmetic.

This is a source-contract gate, not a CFD run. It deliberately verifies both
the published numerical target and the small non-closure caused by the rounded
values printed alongside it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


DEFAULT_AUDIT = Path(
    "ValidationArtifacts/measured-wing-physical-condition-audit.json"
)


def close(actual: float, expected: float, tolerance: float, label: str) -> None:
    relative = abs(actual - expected) / max(abs(expected), 1.0e-30)
    if relative > tolerance:
        raise SystemExit(
            f"{label} mismatch: actual={actual:.17g}, "
            f"expected={expected:.17g}, relative={relative:.3e}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Verify the measured-wing physical-condition audit"
    )
    parser.add_argument("audit", nargs="?", type=Path, default=DEFAULT_AUDIT)
    arguments = parser.parse_args()

    audit_bytes = arguments.audit.read_bytes()
    audit = json.loads(audit_bytes)
    measured = audit["measuredKinematics"]
    published = audit["publishedNumericalConvention"]
    reconstructed = audit["independentReconstruction"]

    amplitude = math.radians(measured["strokeAmplitudePeakToPeakDegrees"])
    speed = (
        2.0
        * amplitude
        * measured["frequencyHertz"]
        * measured["meanWingLengthMeters"]
    )
    reynolds = (
        published["airDensityKilogramsPerCubicMeter"]
        * published["referenceLengthMeters"]
        * speed
        / published["dynamicViscosityPascalSeconds"]
    )
    denominator = (
        0.5
        * published["airDensityKilogramsPerCubicMeter"]
        * published["referenceSpeedMetersPerSecond"] ** 2
        * published["referenceAreaSquareMeters"]
    )
    reynolds_gap = abs(
        published["targetReynoldsNumber"] - reynolds
    ) / published["targetReynoldsNumber"]

    close(
        speed,
        reconstructed["referenceSpeedFromRoundedInputsMetersPerSecond"],
        1.0e-14,
        "reference speed",
    )
    close(
        reynolds,
        reconstructed["reynoldsFromRoundedEquation8Inputs"],
        1.0e-14,
        "rounded-input Reynolds number",
    )
    close(
        denominator,
        published["forceCoefficientDenominatorNewtons"],
        1.0e-14,
        "force-coefficient denominator",
    )
    close(
        reynolds_gap,
        reconstructed["relativeDifferenceFromPublishedReynolds"],
        1.0e-14,
        "published Reynolds closure gap",
    )
    if audit["originalExperiment"]["reynoldsNumber"] is not None:
        raise SystemExit(
            "original experiment must not claim a reported Reynolds number"
        )
    if (
        audit["originalExperiment"]["airDensityKilogramsPerCubicMeter"]
        is not None
    ):
        raise SystemExit(
            "original experiment must not claim a measured air density"
        )
    if audit["replayDecision"]["existingLoadsCanBeRelabelledAsPublishedCondition"]:
        raise SystemExit(
            "Re=100 loads must not be relabelled as the published condition"
        )
    decision = audit["replayDecision"]
    if decision["sourceBackedNumericalReplayReady"]:
        raise SystemExit(
            "published-condition replay must remain blocked after the failed gate"
        )
    if decision["eightCellOneCycleFeasibilityPassed"]:
        raise SystemExit("eight-cell feasibility result must remain failed")
    if decision["twelveCellOneCycleFeasibilityPassed"]:
        raise SystemExit("twelve-cell feasibility result must remain failed")
    actual_audit_hash = hashlib.sha256(audit_bytes).hexdigest()
    feasibilities = []
    for key in (
        "eightCellFeasibilityArtifact",
        "twelveCellFeasibilityArtifact",
    ):
        feasibility_path = Path(decision[key])
        feasibility = json.loads(feasibility_path.read_text(encoding="utf-8"))
        locked_audit_hash = feasibility["sourceLocks"][
            "physicalConditionAudit"
        ]["sha256"]
        if locked_audit_hash != actual_audit_hash:
            raise SystemExit(
                f"{feasibility_path} has a stale physical-condition audit hash"
            )
        if feasibility["stabilityGate"]["passed"]:
            raise SystemExit(
                f"{feasibility_path} must retain its failed stability verdict"
            )
        feasibilities.append(feasibility)

    print(f"audit: {arguments.audit}")
    print(f"reference_speed_mps: {speed:.12f}")
    print(f"rounded_input_reynolds: {reynolds:.9f}")
    print(f"published_reynolds: {published['targetReynoldsNumber']:.4f}")
    print(f"reynolds_closure_gap_percent: {100.0 * reynolds_gap:.6f}")
    print(f"force_coefficient_denominator_N: {denominator:.12f}")
    for feasibility in feasibilities:
        chord_cells = feasibility["numericalSetup"]["chordCells"]
        failure_step = feasibility["stabilityGate"][
            "firstNonFiniteLoadStep"
        ]
        print(
            f"c{chord_cells}_first_non_finite_load_step: {failure_step}"
        )
    print("passed: true")


if __name__ == "__main__":
    main()

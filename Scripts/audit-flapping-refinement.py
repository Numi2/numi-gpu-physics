#!/usr/bin/env python3
"""Reconstruct the fixed-thickness flapping-wing acceptance verdict.

This consumes archived single-grid cases, their independent input audits, and
the production ladder's batch-invariance report. It applies the same numerical
limits and relative-change convention as MetalFlappingWingValidator without
rerunning the fluid simulation.
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
from typing import Any


SOURCE_DOI = "10.3390/insects13050459"
REFERENCE_MEAN_LIFT = 1.460
REFERENCE_MEAN_DRAG = 2.046
MAXIMUM_MEAN_ERROR = 0.30
MAXIMUM_REFINEMENT_CHANGE = 0.05
MAXIMUM_SYMMETRY_ERROR = 0.15
MAXIMUM_PERIODIC_DIFFERENCE = 0.15
MINIMUM_MIDSTROKE_LIFT = 1.0
MAXIMUM_BATCH_DIFFERENCE = 1.0e-7
PUBLISHED_THICKNESS_TO_CHORD = 0.05


def load(path: pathlib.Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def relative_error(value: float, reference: float) -> float:
    return abs(value - reference) / abs(reference)


def relative_change(fine: float, coarse: float) -> float:
    return abs(fine - coarse) / max(abs(fine), 1.0e-30)


def phase_comparison(
    coarse_samples: list[dict[str, Any]],
    fine_samples: list[dict[str, Any]],
) -> dict[str, float]:
    if len(coarse_samples) != 100 or len(fine_samples) != 100:
        raise ValueError("expected 100 phase bins in both archived cases")

    squared = 0.0
    reference = 0.0
    lift_squared = 0.0
    drag_squared = 0.0
    maximum_lift = (0.0, 0.0)
    maximum_drag = (0.0, 0.0)
    for coarse, fine in zip(coarse_samples, fine_samples, strict=True):
        coarse_phase = float(coarse["phase"])
        fine_phase = float(fine["phase"])
        if abs(coarse_phase - fine_phase) > 1.0e-12:
            raise ValueError("archived phase bins do not align")
        lift_delta = float(fine["liftCoefficient"]) - float(
            coarse["liftCoefficient"]
        )
        drag_delta = float(fine["dragCoefficient"]) - float(
            coarse["dragCoefficient"]
        )
        squared += lift_delta * lift_delta + drag_delta * drag_delta
        reference += float(coarse["liftCoefficient"]) ** 2
        reference += float(coarse["dragCoefficient"]) ** 2
        lift_squared += lift_delta * lift_delta
        drag_squared += drag_delta * drag_delta
        if abs(lift_delta) > abs(maximum_lift[0]):
            maximum_lift = (lift_delta, fine_phase)
        if abs(drag_delta) > abs(maximum_drag[0]):
            maximum_drag = (drag_delta, fine_phase)

    return {
        "normalizedCurveDifference": math.sqrt(
            squared / max(reference, 1.0e-30)
        ),
        "liftRMSDelta": math.sqrt(lift_squared / 100.0),
        "dragRMSDelta": math.sqrt(drag_squared / 100.0),
        "maximumAbsoluteLiftDelta": abs(maximum_lift[0]),
        "maximumAbsoluteLiftDeltaPhase": maximum_lift[1],
        "maximumAbsoluteDragDelta": abs(maximum_drag[0]),
        "maximumAbsoluteDragDeltaPhase": maximum_drag[1],
    }


def audit(
    coarse: dict[str, Any],
    fine: dict[str, Any],
    coarse_input: dict[str, Any],
    fine_input: dict[str, Any],
    batch: dict[str, Any],
) -> dict[str, Any]:
    coarse_chord = int(coarse["chordCells"])
    fine_chord = int(fine["chordCells"])
    coarse_lift = float(coarse["meanLiftCoefficient"])
    fine_lift = float(fine["meanLiftCoefficient"])
    coarse_drag = float(coarse["meanDragCoefficient"])
    fine_drag = float(fine["meanDragCoefficient"])
    lift_change = relative_change(fine_lift, coarse_lift)
    drag_change = relative_change(fine_drag, coarse_drag)
    lift_error = relative_error(fine_lift, REFERENCE_MEAN_LIFT)
    drag_error = relative_error(fine_drag, REFERENCE_MEAN_DRAG)
    batch_density = float(batch["maximumBatchDensityDifference"])
    batch_velocity = float(batch["maximumBatchVelocityDifference"])
    batch_force = float(batch["maximumBatchForceDifference"])

    gates = {
        "sourceMatches": (
            coarse_input.get("sourceDOI") == SOURCE_DOI
            and fine_input.get("sourceDOI") == SOURCE_DOI
        ),
        "resolutionOrdering": coarse_chord < fine_chord,
        "fixedPublishedThickness": (
            abs(
                float(coarse["effectiveThicknessToChord"])
                - PUBLISHED_THICKNESS_TO_CHORD
            )
            <= 1.0e-12
            and abs(
                float(fine["effectiveThicknessToChord"])
                - PUBLISHED_THICKNESS_TO_CHORD
            )
            <= 1.0e-12
        ),
        "fiveCycles": int(coarse["cycles"]) == 5 and int(fine["cycles"]) == 5,
        "phaseSamplesComplete": (
            len(coarse["phaseSamples"]) == 100
            and len(fine["phaseSamples"]) == 100
        ),
        "inputAuditsPassed": (
            bool(coarse_input["passed"]) and bool(fine_input["passed"])
        ),
        "inputAuditResolutionsMatch": (
            int(coarse_input["chordCells"]) == coarse_chord
            and int(fine_input["chordCells"]) == fine_chord
        ),
        "finestMeanLift": lift_error <= MAXIMUM_MEAN_ERROR,
        "finestMeanDrag": drag_error <= MAXIMUM_MEAN_ERROR,
        "finestTwoLiftChange": lift_change <= MAXIMUM_REFINEMENT_CHANGE,
        "finestTwoDragChange": drag_change <= MAXIMUM_REFINEMENT_CHANGE,
        "halfStrokeSymmetry": (
            float(fine["halfStrokeSymmetryError"])
            <= MAXIMUM_SYMMETRY_ERROR
        ),
        "previousCycleDifference": (
            float(fine["previousCycleDifference"])
            <= MAXIMUM_PERIODIC_DIFFERENCE
        ),
        "midstrokeLift": (
            float(fine["meanMidstrokeLiftCoefficient"])
            >= MINIMUM_MIDSTROKE_LIFT
        ),
        "phaseTiming": (
            0.25 <= float(fine["firstHalfPeakLiftPhase"]) <= 0.45
            and 0.75 <= float(fine["secondHalfPeakLiftPhase"]) <= 0.95
        ),
        "vortexCoverage": (
            bool(coarse["vortexTimingCoverageComplete"])
            and bool(fine["vortexTimingCoverageComplete"])
        ),
        "batchInvariance": (
            batch_density <= MAXIMUM_BATCH_DIFFERENCE
            and batch_velocity <= MAXIMUM_BATCH_DIFFERENCE
            and batch_force <= MAXIMUM_BATCH_DIFFERENCE
        ),
    }
    return {
        "schemaVersion": 1,
        "sourceDOI": SOURCE_DOI,
        "deviceName": str(fine_input["deviceName"]),
        "passed": all(gates.values()),
        "coarseChordCells": coarse_chord,
        "fineChordCells": fine_chord,
        "coarseGrid": [
            int(coarse["gridX"]),
            int(coarse["gridY"]),
            int(coarse["gridZ"]),
        ],
        "fineGrid": [
            int(fine["gridX"]),
            int(fine["gridY"]),
            int(fine["gridZ"]),
        ],
        "coarseRuntimeSeconds": float(coarse["runtimeSeconds"]),
        "fineRuntimeSeconds": float(fine["runtimeSeconds"]),
        "referenceMeanLiftCoefficient": REFERENCE_MEAN_LIFT,
        "referenceMeanDragCoefficient": REFERENCE_MEAN_DRAG,
        "maximumAllowedMeanCoefficientError": MAXIMUM_MEAN_ERROR,
        "maximumAllowedFinestTwoChange": MAXIMUM_REFINEMENT_CHANGE,
        "maximumAllowedHalfStrokeSymmetryError": MAXIMUM_SYMMETRY_ERROR,
        "maximumAllowedPreviousCycleDifference": (
            MAXIMUM_PERIODIC_DIFFERENCE
        ),
        "minimumAllowedMidstrokeLiftCoefficient": MINIMUM_MIDSTROKE_LIFT,
        "maximumAllowedBatchDifference": MAXIMUM_BATCH_DIFFERENCE,
        "coarseMeanLiftCoefficient": coarse_lift,
        "coarseMeanDragCoefficient": coarse_drag,
        "fineMeanLiftCoefficient": fine_lift,
        "fineMeanDragCoefficient": fine_drag,
        "fineRelativeMeanLiftError": lift_error,
        "fineRelativeMeanDragError": drag_error,
        "relativeFinestTwoLiftChange": lift_change,
        "relativeFinestTwoDragChange": drag_change,
        "fineFirstHalfPeakLiftPhase": float(
            fine["firstHalfPeakLiftPhase"]
        ),
        "fineSecondHalfPeakLiftPhase": float(
            fine["secondHalfPeakLiftPhase"]
        ),
        "fineMeanMidstrokeLiftCoefficient": float(
            fine["meanMidstrokeLiftCoefficient"]
        ),
        "fineHalfStrokeSymmetryError": float(
            fine["halfStrokeSymmetryError"]
        ),
        "finePreviousCycleDifference": float(
            fine["previousCycleDifference"]
        ),
        "maximumBatchDensityDifference": batch_density,
        "maximumBatchVelocityDifference": batch_velocity,
        "maximumBatchForceDifference": batch_force,
        "phaseComparison": phase_comparison(
            coarse["phaseSamples"], fine["phaseSamples"]
        ),
        "gates": gates,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("coarse_case", type=pathlib.Path)
    parser.add_argument("fine_case", type=pathlib.Path)
    parser.add_argument("batch_report", type=pathlib.Path)
    parser.add_argument("--coarse-audit", required=True, type=pathlib.Path)
    parser.add_argument("--fine-audit", required=True, type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    arguments = parser.parse_args()

    report = audit(
        load(arguments.coarse_case),
        load(arguments.fine_case),
        load(arguments.coarse_audit),
        load(arguments.fine_audit),
        load(arguments.batch_report),
    )
    report["inputFiles"] = {
        "coarseCase": str(arguments.coarse_case),
        "fineCase": str(arguments.fine_case),
        "coarseInputAudit": str(arguments.coarse_audit),
        "fineInputAudit": str(arguments.fine_audit),
        "batchReport": str(arguments.batch_report),
    }
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if arguments.output is None:
        print(encoded, end="")
    else:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(encoded, encoding="utf-8")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

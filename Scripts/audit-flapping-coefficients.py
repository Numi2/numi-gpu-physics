#!/usr/bin/env python3
"""Reconstruct Li--Nabawy force coefficients from captured raw forces.

This deliberately does not import or parse the Swift implementation. It encodes
the paper's equations (8), (11), and (12), derives the baseline wing geometry,
and checks the resulting denominator against phase-binned force vectors.
"""

from __future__ import annotations

import argparse
import json
import math
import pathlib
import statistics
from typing import Any


SOURCE_DOI = "10.3390/insects13050459"
SOURCE_URL = "https://doi.org/10.3390/insects13050459"
PUBLISHED_MEAN_LIFT = 1.460
PUBLISHED_MEAN_DRAG = 2.046


def positive_round(value: float) -> int:
    """Match Swift's default rounding for the positive cycle-step count."""

    return math.floor(value + 0.5)


def stroke_angle(phase: float) -> float:
    """Independent transcription of the paper's semi-triangular stroke."""

    half_amplitude = math.radians(80.0)
    duration = 0.25
    half_duration = 0.5 * duration
    maximum_rate = 2.0 * half_amplitude / (
        duration + 2.0 * duration / math.pi
    )
    if phase < half_duration:
        argument = math.pi * (phase + half_duration) / duration
        return half_amplitude + maximum_rate * duration / math.pi * (
            math.sin(argument) - 1.0
        )
    if phase < 0.5 - half_duration:
        transition_end = half_amplitude - maximum_rate * duration / math.pi
        return transition_end - maximum_rate * (phase - half_duration)
    if phase < 0.5 + half_duration:
        start = 0.5 - half_duration
        transition_start = (
            -half_amplitude + maximum_rate * duration / math.pi
        )
        argument = math.pi * (phase - start) / duration
        return transition_start - maximum_rate * duration / math.pi * math.sin(
            argument
        )
    if phase < 1.0 - half_duration:
        transition_end = (
            -half_amplitude + maximum_rate * duration / math.pi
        )
        return transition_end + maximum_rate * (
            phase - (0.5 + half_duration)
        )
    start = 1.0 - half_duration
    transition_start = half_amplitude - maximum_rate * duration / math.pi
    argument = math.pi * (phase - start) / duration
    return transition_start + maximum_rate * duration / math.pi * math.sin(
        argument
    )


def mean(values: list[float]) -> float:
    return sum(values) / len(values)


def relative_error(value: float, reference: float) -> float:
    return abs(value - reference) / abs(reference)


def estimator_ledger(
    summary: dict[str, Any],
    denominator: float,
) -> dict[str, Any]:
    samples = summary["phaseSamples"]
    if len(samples) != 100:
        raise ValueError(
            f"expected 100 phase bins, found {len(samples)}"
        )

    recomputed_lift: list[float] = []
    recomputed_drag: list[float] = []
    lift_residuals: list[float] = []
    drag_residuals: list[float] = []
    inferred_lift_denominators: list[float] = []
    for sample in samples:
        phase = float(sample["phase"])
        lift = float(sample["forceZ"]) / denominator
        angle = stroke_angle(phase)
        tangent_x = -math.sin(angle)
        tangent_y = math.cos(angle)
        stroke_direction = -1.0 if phase < 0.5 else 1.0
        drag_force = -stroke_direction * (
            float(sample["forceX"]) * tangent_x
            + float(sample["forceY"]) * tangent_y
        )
        drag = drag_force / denominator
        recomputed_lift.append(lift)
        recomputed_drag.append(drag)
        lift_residuals.append(lift - float(sample["liftCoefficient"]))
        drag_residuals.append(drag - float(sample["dragCoefficient"]))
        stored_lift = float(sample["liftCoefficient"])
        if abs(stored_lift) > 1.0e-12:
            inferred_lift_denominators.append(
                float(sample["forceZ"]) / stored_lift
            )

    inferred_median = statistics.median(inferred_lift_denominators)
    recomputed_mean_lift = mean(recomputed_lift)
    recomputed_mean_drag = mean(recomputed_drag)
    stored_mean_lift = float(summary["meanLiftCoefficient"])
    stored_mean_drag = float(summary["meanDragCoefficient"])
    required_lift_denominator = (
        denominator * recomputed_mean_lift / PUBLISHED_MEAN_LIFT
    )
    required_drag_denominator = (
        denominator * recomputed_mean_drag / PUBLISHED_MEAN_DRAG
    )
    return {
        "storedMeanLiftCoefficient": stored_mean_lift,
        "recomputedMeanLiftCoefficient": recomputed_mean_lift,
        "storedMeanDragCoefficient": stored_mean_drag,
        "recomputedMeanDragCoefficientFromBinCenterProjection": (
            recomputed_mean_drag
        ),
        "maximumAbsoluteLiftCoefficientResidual": max(
            abs(value) for value in lift_residuals
        ),
        "maximumAbsoluteDragCoefficientResidualFromBinCenterProjection": max(
            abs(value) for value in drag_residuals
        ),
        "meanDragCoefficientResidualFromBinCenterProjection": (
            recomputed_mean_drag - stored_mean_drag
        ),
        "inferredDenominatorFromRawLiftMedian": inferred_median,
        "inferredDenominatorFromRawLiftMinimum": min(
            inferred_lift_denominators
        ),
        "inferredDenominatorFromRawLiftMaximum": max(
            inferred_lift_denominators
        ),
        "relativeDenominatorDifference": relative_error(
            inferred_median,
            denominator,
        ),
        "publishedMeanLiftError": relative_error(
            recomputed_mean_lift,
            PUBLISHED_MEAN_LIFT,
        ),
        "publishedMeanDragError": relative_error(
            recomputed_mean_drag,
            PUBLISHED_MEAN_DRAG,
        ),
        "requiredDenominatorToMatchPublishedLift": (
            required_lift_denominator
        ),
        "requiredDenominatorToMatchPublishedDrag": (
            required_drag_denominator
        ),
        "requiredLiftToDragDenominatorRatio": (
            required_lift_denominator / required_drag_denominator
        ),
    }


def audit(input_report: dict[str, Any]) -> dict[str, Any]:
    if input_report.get("sourceDOI") != SOURCE_DOI:
        raise ValueError(
            "input report does not identify the Li--Nabawy benchmark"
        )

    chord_cells = int(input_report["chordCells"])
    density = 1.0
    aspect_ratio = 3.0
    radial_centroid_fraction = 0.5
    radius_of_gyration_fraction = (
        0.929 * radial_centroid_fraction**0.732
    )
    total_stroke_amplitude_radians = math.radians(160.0)
    full_cycle_angular_travel = 2.0 * total_stroke_amplitude_radians
    span = aspect_ratio * chord_cells
    radius_of_gyration = radius_of_gyration_fraction * span
    cycle_path_at_radius_of_gyration = (
        full_cycle_angular_travel * radius_of_gyration
    )
    target_lattice_speed = 0.035
    cycle_steps = positive_round(
        cycle_path_at_radius_of_gyration / target_lattice_speed
    )
    average_radius_of_gyration_speed = (
        cycle_path_at_radius_of_gyration / cycle_steps
    )
    planform_area = aspect_ratio * chord_cells * chord_cells
    denominator = (
        0.5
        * density
        * average_radius_of_gyration_speed**2
        * planform_area
    )

    estimators = {
        "galileanInvariantTotal": estimator_ledger(
            input_report["galileanInvariantTotal"],
            denominator,
        ),
        "conventionalMovingBodyTotal": estimator_ledger(
            input_report["conventionalMovingBodyTotal"],
            denominator,
        ),
    }
    maximum_relative_denominator_difference = max(
        value["relativeDenominatorDifference"]
        for value in estimators.values()
    )
    maximum_lift_residual = max(
        value["maximumAbsoluteLiftCoefficientResidual"]
        for value in estimators.values()
    )
    maximum_mean_drag_residual = max(
        abs(value["meanDragCoefficientResidualFromBinCenterProjection"])
        for value in estimators.values()
    )
    normalization_matches = (
        maximum_relative_denominator_difference <= 1.0e-12
        and maximum_lift_residual <= 1.0e-12
        and maximum_mean_drag_residual <= 1.0e-3
    )
    single_scalar_matches_published_means = all(
        abs(value["requiredLiftToDragDenominatorRatio"] - 1.0) <= 0.01
        for value in estimators.values()
    )

    return {
        "schemaVersion": 1,
        "source": {
            "doi": SOURCE_DOI,
            "url": SOURCE_URL,
            "equation8": "Re = U2 * meanChord / kinematicViscosity",
            "equation11": "CL = 2 * lift / (density * U2^2 * S)",
            "equation12": "CD = 2 * drag / (density * U2^2 * S)",
            "table2MeanLiftCoefficient": PUBLISHED_MEAN_LIFT,
            "table2MeanDragCoefficient": PUBLISHED_MEAN_DRAG,
        },
        "input": {
            "capturedWithoutNewFluidSimulation": True,
            "chordCells": chord_cells,
            "density": density,
            "aspectRatio": aspect_ratio,
            "radialCentroidFraction": radial_centroid_fraction,
            "totalStrokeAmplitudeDegrees": 160.0,
            "targetLatticeRadiusOfGyrationSpeed": target_lattice_speed,
        },
        "derived": {
            "radiusOfGyrationFraction": radius_of_gyration_fraction,
            "spanCells": span,
            "singleWingPlanformAreaCellsSquared": planform_area,
            "fullCycleAngularTravelRadians": full_cycle_angular_travel,
            "cyclePathAtRadiusOfGyrationCells": (
                cycle_path_at_radius_of_gyration
            ),
            "cycleSteps": cycle_steps,
            "actualAverageRadiusOfGyrationSpeed": (
                average_radius_of_gyration_speed
            ),
            "paperCoefficientDenominator": denominator,
        },
        "estimators": estimators,
        "checks": {
            "maximumRelativeDenominatorDifference": (
                maximum_relative_denominator_difference
            ),
            "maximumAbsoluteLiftCoefficientResidual": maximum_lift_residual,
            "maximumMeanDragCoefficientResidualFromBinCenterProjection": (
                maximum_mean_drag_residual
            ),
            "normalizationMatchesPaper": normalization_matches,
            "singleScalarCanMatchBothPublishedMeansWithinOnePercent": (
                single_scalar_matches_published_means
            ),
        },
        "verdict": (
            "coefficient normalization is cleared; the remaining bias is in "
            "the shared link-population or momentum-transfer numerator"
            if normalization_matches
            else "coefficient normalization did not match the paper"
        ),
        "dragProjectionNote": (
            "Raw forces are stored as 100 bin averages, while stored drag was "
            "projected before binning. Reprojection at each bin center is "
            "therefore an approximation; lift and its shared denominator "
            "reconstruct exactly."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=pathlib.Path)
    parser.add_argument("--output", type=pathlib.Path)
    arguments = parser.parse_args()

    report = audit(json.loads(arguments.input.read_text(encoding="utf-8")))
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if arguments.output is None:
        print(encoded, end="")
    else:
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(encoded, encoding="utf-8")
    if not report["checks"]["normalizationMatchesPaper"]:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

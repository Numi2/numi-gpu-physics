#!/usr/bin/env python3
"""Independently rebuild the fallback-aware D12 link-population replay."""

from __future__ import annotations

import hashlib
import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
COEFFICIENT_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-coefficient-preregistration.json"
COEFFICIENT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-coefficient.json"
DURATION_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration-preregistration.json"
DURATION_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration.json"
INITIAL_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-preregistration.json"
INITIAL_REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-fallback-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-fallback.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-population-fallback-audit.json"

DIRECTIONS = [
    (0, 0, 0),
    (1, 0, 0), (-1, 0, 0),
    (0, 1, 0), (0, -1, 0),
    (0, 0, 1), (0, 0, -1),
    (1, 1, 0), (-1, -1, 0),
    (1, -1, 0), (-1, 1, 0),
    (1, 0, 1), (-1, 0, -1),
    (1, 0, -1), (-1, 0, 1),
    (0, 1, 1), (0, -1, -1),
    (0, 1, -1), (0, -1, 1),
]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(float(first) - float(second)) <= tolerance * max(
        abs(float(first)), abs(float(second)), 1.0
    )


def vclose(first: list[float], second: list[float], tolerance: float = 2e-9) -> bool:
    return len(first) == len(second) and all(
        close(a, b, tolerance) for a, b in zip(first, second)
    )


def add(first: list[float], second: list[float]) -> list[float]:
    return [a + b for a, b in zip(first, second)]


def sub(first: list[float], second: list[float]) -> list[float]:
    return [a - b for a, b in zip(first, second)]


def scale(value: list[float], factor: float) -> list[float]:
    return [component * factor for component in value]


def magnitude_squared(value: list[float]) -> float:
    return sum(component * component for component in value)


def magnitude(value: list[float]) -> float:
    return math.sqrt(magnitude_squared(value))


def cross(first: list[float], second: list[float]) -> list[float]:
    return [
        first[1] * second[2] - first[2] * second[1],
        first[2] * second[0] - first[0] * second[2],
        first[0] * second[1] - first[1] * second[0],
    ]


def vector_rms(values: list[list[float]]) -> float:
    return math.sqrt(sum(magnitude_squared(value) for value in values) / len(values))


def relative_rms(first: list[list[float]], second: list[list[float]]) -> float:
    difference = sum(
        magnitude_squared(sub(b, a)) for a, b in zip(first, second)
    )
    reference = sum(
        0.5 * (magnitude_squared(a) + magnitude_squared(b))
        for a, b in zip(first, second)
    )
    return math.sqrt(difference / max(reference, 1e-30))


def reconstruct(
    q: float,
    reflected: float,
    farther: float,
    previous: float,
    wall_correction: float,
    threshold: float,
) -> float:
    if q <= threshold:
        return 2 * q * reflected + (1 - 2 * q) * farther + wall_correction
    return (
        (reflected + wall_correction) / (2 * q)
        + (2 * q - 1) * previous / (2 * q)
    )


def audit_sample(sample: dict, report: dict, prereg: dict) -> tuple[dict, dict]:
    threshold = float(prereg["branchThreshold"])
    direction_index = int(sample["directionIndex"])
    direction = [float(value) for value in DIRECTIONS[direction_index]]
    production_fallback = int(sample["capturedBranchCode"]) == 1
    exact_q = float(sample["exactGlobalFluidToIntersectionFraction"])
    exact_fallback = production_fallback and exact_q <= threshold
    production_q = float(sample["productionFluidToIntersectionFraction"])
    raster_q = float(sample["rasterFluidToIntersectionFraction"])
    production_branch = "halfway-fallback" if production_fallback else "near-q-le-half"
    exact_branch = (
        "halfway-fallback" if exact_fallback
        else "near-q-le-half" if exact_q <= threshold
        else "far-q-gt-half"
    )
    reflected = float(sample["reflectedPopulation"])
    farther = float(sample["fartherOutgoingPopulation"])
    previous = float(sample["previousIncomingPopulation"])
    density = float(sample["preStepLocalDensity"])
    fluid_projection = float(sample["fluidEndpointWallProjectionLattice"])
    solid_projection = float(sample["solidEndpointWallProjectionLattice"])
    production_projection = (
        solid_projection if production_fallback
        else (1 - raster_q) * fluid_projection + raster_q * solid_projection
    )
    exact_projection = (
        production_projection if exact_fallback
        else (1 - exact_q) * fluid_projection + exact_q * solid_projection
    )
    weight = f32(1 / 18) if direction_index <= 6 else f32(1 / 36)
    sound_speed_squared = f32(1 / 3)
    production_wall = float(sample["productionRawWallCorrection"])
    rebuilt_production_wall = (
        2 * weight * density * production_projection / sound_speed_squared
    )
    exact_wall = (
        production_wall if exact_fallback
        else 2 * weight * density * exact_projection / sound_speed_squared
    )
    production_population = reconstruct(
        production_q, reflected, farther, previous, production_wall, threshold
    )
    exact_population = (
        float(sample["productionReconstructedPopulation"]) if exact_fallback
        else reconstruct(
            exact_q, reflected, farther, previous, exact_wall, threshold
        )
    )
    force_scale = float(report["forceToPhysical"])
    production_force = scale(
        direction,
        -(float(sample["productionReconstructedPopulation"]) + reflected)
        * force_scale,
    )
    exact_force = scale(direction, -(exact_population + reflected) * force_scale)
    force_difference = sub(exact_force, production_force)
    fluid = [float(value) for value in sample["fluidCellCoordinate"]]
    origin = [float(value) for value in report["domainOriginMeters"]]
    body_center = [float(value) for value in report["bodyCenterMeters"]]
    dx = float(report["cellSizeMeters"])
    fluid_world = add(origin, scale(fluid, dx))
    production_point = sub(fluid_world, scale(direction, production_q * dx))
    exact_point = sub(
        fluid_world,
        scale(direction, (production_q if exact_fallback else exact_q) * dx),
    )
    production_torque = cross(sub(production_point, body_center), production_force)
    exact_torque = cross(sub(exact_point, body_center), exact_force)
    torque_difference = sub(exact_torque, production_torque)
    grid_x, grid_y = int(report["gridX"]), int(report["gridY"])
    solid = [int(value) for value in sample["solidCellCoordinate"]]
    expected_source = solid[0] + grid_x * (solid[1] + grid_y * solid[2])
    expected_fluid = [solid[i] + int(direction[i]) for i in range(3)]
    branch_code = int(sample["capturedBranchCode"])
    provenance = all([
        int(sample["capturedDirectionIndex"]) == direction_index,
        int(sample["capturedSourceLinearIndex"]) == expected_source,
        int(sample["capturedPartIdentifier"]) == int(sample["partIdentifier"]),
        branch_code == (1 if production_fallback else 2),
        bool(sample["capturedSourceIsSolid"]),
        bool(sample["capturedInterpolatedBoundary"]) == (not production_fallback),
        not bool(sample["capturedOutsideDomain"]),
        sample["fluidCellCoordinate"] == expected_fluid,
        bool(sample["captureRecordMatched"]),
    ])
    values = all([
        close(production_q, threshold if production_fallback else raster_q, 1e-7),
        bool(sample["productionFallbackApplied"]) == production_fallback,
        bool(sample["exactGlobalFallbackApplied"]) == exact_fallback,
        sample["productionBranch"] == production_branch,
        sample["exactGlobalBranch"] == exact_branch,
        bool(sample["branchChanged"]) == (production_branch != exact_branch),
        close(sample["productionWallProjectionLattice"], production_projection, 1e-7),
        close(sample["exactGlobalWallProjectionLattice"], exact_projection),
        close(production_wall, rebuilt_production_wall, 1e-7),
        close(sample["exactGlobalRawWallCorrection"], exact_wall),
        close(sample["independentlyReconstructedProductionPopulation"], production_population),
        close(sample["exactGlobalReconstructedPopulation"], exact_population),
        close(
            sample["populationDifference"],
            exact_population - float(sample["productionReconstructedPopulation"]),
        ),
        close(
            sample["productionReconstructionDifference"],
            abs(production_population - float(sample["productionReconstructedPopulation"])),
        ),
        vclose(sample["productionLinkForceNewtons"], production_force),
        vclose(sample["exactGlobalLinkForceNewtons"], exact_force),
        vclose(sample["linkForceDifferenceNewtons"], force_difference),
        vclose(sample["productionLinkTorqueNewtonMeters"], production_torque),
        vclose(sample["exactGlobalLinkTorqueNewtonMeters"], exact_torque),
        vclose(sample["linkTorqueDifferenceNewtonMeters"], torque_difference),
    ])
    rebuilt = {
        "step": int(sample["step"]),
        "productionPopulation": float(sample["productionReconstructedPopulation"]),
        "exactPopulation": exact_population,
        "productionForce": production_force,
        "exactForce": exact_force,
        "productionTorque": production_torque,
        "exactTorque": exact_torque,
        "productionFallback": production_fallback,
        "exactFallback": exact_fallback,
        "branchChanged": production_branch != exact_branch,
        "fractionDifference": abs(
            production_q - (threshold if production_fallback else raster_q)
        ),
        "reconstructionDifference": abs(
            production_population - float(sample["productionReconstructedPopulation"])
        ),
        "density": density,
    }
    return rebuilt, {"provenance": provenance, "values": values}


def main() -> None:
    coefficient_prereg = load(COEFFICIENT_PREREG_PATH)
    coefficient = load(COEFFICIENT_PATH)
    duration_prereg = load(DURATION_PREREG_PATH)
    duration = load(DURATION_PATH)
    initial_prereg = load(INITIAL_PREREG_PATH)
    initial_report = load(INITIAL_REPORT_PATH)
    prereg = load(PREREG_PATH)
    report = load(REPORT_PATH)

    rebuilt: list[dict] = []
    provenance_valid = True
    sample_values_valid = True
    for sample in report["samples"]:
        result, checks = audit_sample(sample, report, prereg)
        rebuilt.append(result)
        provenance_valid &= checks["provenance"]
        sample_values_valid &= checks["values"]

    grouped: dict[int, list[dict]] = {}
    for sample in rebuilt:
        grouped.setdefault(sample["step"], []).append(sample)
    rebuilt_steps: list[dict] = []
    step_values_valid = len(grouped) == len(report["steps"])
    for observed in report["steps"]:
        step = int(observed["step"])
        values = grouped.get(step, [])
        production_force = [sum(value["productionForce"][i] for value in values) for i in range(3)]
        exact_force = [sum(value["exactForce"][i] for value in values) for i in range(3)]
        production_torque = [sum(value["productionTorque"][i] for value in values) for i in range(3)]
        exact_torque = [sum(value["exactTorque"][i] for value in values) for i in range(3)]
        delta_force = sub(exact_force, production_force)
        delta_torque = sub(exact_torque, production_torque)
        step_values_valid &= len(values) == int(prereg["expectedLinkCount"])
        step_values_valid &= all([
            vclose(observed["productionOutlierForceNewtons"], production_force),
            vclose(observed["exactGlobalOutlierForceNewtons"], exact_force),
            vclose(observed["outlierForceDifferenceNewtons"], delta_force),
            vclose(observed["productionOutlierTorqueNewtonMeters"], production_torque),
            vclose(observed["exactGlobalOutlierTorqueNewtonMeters"], exact_torque),
            vclose(observed["outlierTorqueDifferenceNewtonMeters"], delta_torque),
        ])
        rebuilt_steps.append({
            "aerodynamic": [float(value) for value in observed["aerodynamicForceNewtons"]],
            "productionForce": production_force,
            "exactForce": exact_force,
            "deltaForce": delta_force,
            "productionTorque": production_torque,
            "exactTorque": exact_torque,
            "deltaTorque": delta_torque,
        })

    population_difference_energy = sum(
        (value["exactPopulation"] - value["productionPopulation"]) ** 2
        for value in rebuilt
    )
    population_reference_energy = sum(
        0.5 * (value["productionPopulation"] ** 2 + value["exactPopulation"] ** 2)
        for value in rebuilt
    )
    production_forces = [value["productionForce"] for value in rebuilt_steps]
    exact_forces = [value["exactForce"] for value in rebuilt_steps]
    delta_forces = [value["deltaForce"] for value in rebuilt_steps]
    production_torques = [value["productionTorque"] for value in rebuilt_steps]
    exact_torques = [value["exactTorque"] for value in rebuilt_steps]
    delta_torques = [value["deltaTorque"] for value in rebuilt_steps]
    aerodynamic = [value["aerodynamic"] for value in rebuilt_steps]
    dt = float(report["fluidTimeStepSeconds"])
    delta_impulse = scale(
        [sum(value[i] for value in delta_forces) for i in range(3)], dt
    )
    aerodynamic_impulse = scale(
        [sum(value[i] for value in aerodynamic) for i in range(3)], dt
    )
    first_step = grouped[int(prereg["captureStartStep"])]
    metrics = {
        "uniqueBranchChangeCount": sum(value["branchChanged"] for value in first_step),
        "productionFallbackLinkCount": sum(value["productionFallback"] for value in first_step),
        "exactGlobalFallbackLinkCount": sum(value["exactFallback"] for value in first_step),
        "sourceRecordMismatchCount": sum(not bool(sample["captureRecordMatched"]) for sample in report["samples"]),
        "capturedSampleCount": len(rebuilt),
        "populationRelativeRMSDifference": math.sqrt(
            population_difference_energy / max(population_reference_energy, 1e-30)
        ),
        "outlierForceRelativeRMSDifference": relative_rms(production_forces, exact_forces),
        "outlierTorqueRelativeRMSDifference": relative_rms(production_torques, exact_torques),
        "deltaForceRMSNewtons": vector_rms(delta_forces),
        "deltaTorqueRMSNewtonMeters": vector_rms(delta_torques),
        "globalAerodynamicForceRMSNewtons": vector_rms(aerodynamic),
        "deltaForceToGlobalAerodynamicForceRMSRatio": vector_rms(delta_forces) / max(vector_rms(aerodynamic), 1e-30),
        "deltaForceImpulseNewtonSeconds": delta_impulse,
        "globalAerodynamicForceImpulseNewtonSeconds": aerodynamic_impulse,
        "deltaImpulseToGlobalAerodynamicImpulseRatio": magnitude(delta_impulse) / max(magnitude(aerodynamic_impulse), 1e-30),
        "maximumStepDeltaForceToAerodynamicForceRatio": max(
            magnitude(delta) / max(magnitude(force), 1e-30)
            for delta, force in zip(delta_forces, aerodynamic)
        ),
        "maximumProductionFractionDifference": max(value["fractionDifference"] for value in rebuilt),
        "maximumProductionReconstructionDifference": max(value["reconstructionDifference"] for value in rebuilt),
        "minimumPreStepLocalDensity": min(value["density"] for value in rebuilt),
    }
    metrics_valid = all(
        vclose(report["metrics"][key], value)
        if isinstance(value, list)
        else int(report["metrics"][key]) == int(value)
        if isinstance(value, int)
        else close(report["metrics"][key], value)
        for key, value in metrics.items()
    )
    source_reproduced = all([
        provenance_valid,
        metrics["capturedSampleCount"] == 576 * 8,
        metrics["uniqueBranchChangeCount"] == int(prereg["expectedUniqueBranchChangeCount"]),
        metrics["productionFallbackLinkCount"] == int(prereg["expectedProductionFallbackLinkCount"]),
        metrics["exactGlobalFallbackLinkCount"] == int(prereg["expectedExactGlobalFallbackLinkCount"]),
        metrics["sourceRecordMismatchCount"] == 0,
        metrics["maximumProductionFractionDifference"] <= float(prereg["maximumAllowedProductionFractionDifference"]),
        metrics["maximumProductionReconstructionDifference"] <= float(prereg["maximumAllowedProductionReconstructionDifference"]),
        metrics["minimumPreStepLocalDensity"] > 0,
        bool(report["momentumClosurePassed"]),
        bool(report["sampledPopulationPositivityPassed"]),
        bool(report["allValuesFinite"]),
    ])
    population_material = source_reproduced and metrics["populationRelativeRMSDifference"] >= float(prereg["minimumMaterialPopulationRelativeRMSDifference"])
    force_material = source_reproduced and metrics["outlierForceRelativeRMSDifference"] >= float(prereg["minimumMaterialOutlierForceRelativeRMSDifference"])
    global_force = source_reproduced and metrics["deltaForceToGlobalAerodynamicForceRMSRatio"] >= float(prereg["minimumPotentialGlobalForceRMSContribution"])
    global_impulse = source_reproduced and metrics["deltaImpulseToGlobalAerodynamicImpulseRatio"] >= float(prereg["minimumPotentialGlobalImpulseContribution"])
    local_material = population_material and force_material
    classification = (
        "invalid-realized-population-replay" if not source_reproduced
        else "realized-population-insensitive" if not local_material
        else "realized-force-significant" if global_force or global_impulse
        else "realized-link-sensitive-globally-small"
    )
    checks = {
        "sourceHashes": all([
            prereg["sourceLinkCoefficientPreregistrationSHA256"] == sha256(COEFFICIENT_PREREG_PATH),
            prereg["sourceLinkCoefficientReportSHA256"] == sha256(COEFFICIENT_PATH),
            prereg["sourceTemporalDurationPreregistrationSHA256"] == sha256(DURATION_PREREG_PATH),
            prereg["sourceTemporalDurationReportSHA256"] == sha256(DURATION_PATH),
            report["sourceLinkPopulationPreregistrationSHA256"] == sha256(PREREG_PATH),
        ]),
        "sourcePreconditions": all([
            coefficient["classification"] == "branch-changing-coefficient-sensitive",
            coefficient["validationOnlyPopulationReplayAuthorized"],
            duration["classification"] == "persistent-fixed-wall-grid-disagreement",
            duration["extendedSampling"]["d12"]["numericalCaseGatePassed"],
            not coefficient["productionModificationAuthorized"],
            not duration["productionPromotionAuthorized"],
        ]),
        "transparentRevision": all([
            int(initial_prereg["schemaVersion"]) == 1,
            not initial_report["sourceReproductionPassed"],
            initial_report["classification"] == "invalid-realized-population-replay",
            float(initial_report["metrics"]["maximumProductionFractionDifference"]) > float(initial_prereg["maximumAllowedProductionFractionDifference"]),
            float(initial_report["metrics"]["maximumProductionReconstructionDifference"]) <= float(initial_prereg["maximumAllowedProductionReconstructionDifference"]),
            int(prereg["contractRevision"]) == 2,
        ]),
        "fixedContract": all([
            int(prereg["referenceLengthCells"]) == 12,
            int(prereg["captureStartStep"]) == 1,
            int(prereg["captureEndStep"]) == 576,
            int(prereg["captureStride"]) == 1,
            int(prereg["expectedLinkCount"]) == 8,
            int(prereg["expectedProductionFallbackLinkCount"]) == 4,
            int(prereg["expectedExactGlobalFallbackLinkCount"]) == 1,
            close(prereg["minimumMaterialPopulationRelativeRMSDifference"], 0.10),
            close(prereg["minimumMaterialOutlierForceRelativeRMSDifference"], 0.10),
            close(prereg["minimumPotentialGlobalForceRMSContribution"], 0.01),
            close(prereg["minimumPotentialGlobalImpulseContribution"], 0.01),
            prereg["passed"],
        ]),
        "captureProvenance": provenance_valid,
        "sampleReconstruction": sample_values_valid,
        "stepReduction": step_values_valid,
        "aggregateMetrics": metrics_valid,
        "numericalLedger": all([
            report["momentumClosurePassed"],
            report["sampledPopulationPositivityPassed"],
            report["allValuesFinite"],
            float(report["relativeRMSRawControlVolumeClosureResidual"]) <= 0.005,
            float(report["relativeRMSGlobalFluidClosureResidual"]) <= 0.005,
            float(report["collisionLimiterActivationFractionOfCellSteps"]) <= 0.05,
            float(report["minimumPopulation"]) > 0,
        ]),
        "sourceReproduction": bool(report["sourceReproductionPassed"]) == source_reproduced,
        "classification": all([
            report["classification"] == classification,
            bool(report["populationMaterialityPassed"]) == population_material,
            bool(report["outlierForceMaterialityPassed"]) == force_material,
            bool(report["potentialGlobalForceContributionPassed"]) == global_force,
            bool(report["potentialGlobalImpulseContributionPassed"]) == global_impulse,
        ]),
        "safetyBoundary": all([
            not report["validationOnlyBoundaryABAuthorized"],
            not report["d16CaptureAuthorized"],
            not report["d20DiagnosticAuthorized"],
            not report["productionModificationAuthorized"],
            not report["rawSpatialGateModified"],
            not report["experimentalAgreementGateApplied"],
        ]),
    }
    output = {
        "schemaVersion": 1,
        "auditor": "independent-python-fallback-aware-link-population-reconstruction",
        "sourceSHA256": {
            "coefficientPreregistration": sha256(COEFFICIENT_PREREG_PATH),
            "coefficientReport": sha256(COEFFICIENT_PATH),
            "durationPreregistration": sha256(DURATION_PREREG_PATH),
            "durationReport": sha256(DURATION_PATH),
            "initialPopulationPreregistration": sha256(INITIAL_PREREG_PATH),
            "initialPopulationReport": sha256(INITIAL_REPORT_PATH),
            "fallbackPreregistration": sha256(PREREG_PATH),
            "fallbackReport": sha256(REPORT_PATH),
        },
        "independentMetrics": metrics,
        "classification": classification,
        "checks": checks,
        "allChecksPassed": all(checks.values()),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps(output, indent=2, sort_keys=True))
    if not output["allChecksPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Independently audit the locked candidate-A D=8/12/16 spatial ladder."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-preregistration.json"
D8_PATH = ARTIFACTS / "deetjen-dove-d8-moving-wall-full-window.json"
D12_PATH = ARTIFACTS / "deetjen-dove-d12-moving-wall-full-window.json"
D16_PATH = ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window.json"
D16_AUDIT_PATH = ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window-audit.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-discriminator.json"
TARGET_PATH = ROOT / "ValidationInputs/deetjen-ob-f03-force-v1.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-discriminator-audit.json"

EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_NORMALIZATION = "pre-step-local-density"
EXPECTED_FORCE_SAMPLES = 187


Vector = tuple[float, float, float]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    value = tuple(float(component) for component in raw)
    if not all(math.isfinite(component) for component in value):
        raise ValueError("nonfinite vector")
    return value  # type: ignore[return-value]


def add(first: Vector, second: Vector) -> Vector:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def subtract(first: Vector, second: Vector) -> Vector:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def scale(value: Vector, factor: float) -> Vector:
    return tuple(component * factor for component in value)  # type: ignore[return-value]


def magnitude(value: Vector) -> float:
    return math.sqrt(sum(component * component for component in value))


def rms(values: list[Vector]) -> float:
    return math.sqrt(
        sum(component * component for value in values for component in value)
        / len(values)
    )


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector) -> bool:
    return all(close(a, b, 2e-8) for a, b in zip(first, second))


def average(values: list[Vector]) -> Vector:
    return scale(
        tuple(sum(value[axis] for value in values) for axis in range(3)),
        1.0 / len(values),
    )  # type: ignore[arg-type]


def relative_difference(first: Vector, second: Vector) -> float:
    return magnitude(subtract(first, second)) / max(
        magnitude(first), magnitude(second), 1e-30
    )


def pairwise_normalized_rms(first: list[Vector], second: list[Vector]) -> float:
    numerator = sum(
        component * component
        for index in range(len(first))
        for component in subtract(first[index], second[index])
    )
    first_energy = sum(component * component for value in first for component in value)
    second_energy = sum(
        component * component for value in second for component in value
    )
    return math.sqrt(numerator / max(0.5 * (first_energy + second_energy), 1e-30))


def trapezoidal_impulse(
    values: list[tuple[float, float]], rate: float
) -> tuple[float, float]:
    result = [0.0, 0.0]
    for index in range(1, len(values)):
        result[0] += 0.5 * (values[index - 1][0] + values[index][0]) / rate
        result[1] += 0.5 * (values[index - 1][1] + values[index][1]) / rate
    return result[0], result[1]


def normalized_rms(
    measured: list[tuple[float, float]],
    computed: list[tuple[float, float]],
) -> float:
    numerator = sum(
        (computed[index][0] - measured[index][0]) ** 2
        + (computed[index][1] - measured[index][1]) ** 2
        for index in range(len(measured))
    )
    denominator = sum(x * x + z * z for x, z in measured)
    return math.sqrt(numerator / denominator)


def peak_time(times: list[float], values: list[tuple[float, float]]) -> float:
    index = max(
        range(len(values)),
        key=lambda item: values[item][0] ** 2 + values[item][1] ** 2,
    )
    return times[index]


def audit_case(wrapper: dict, expected_d: int, target: dict) -> tuple[dict, list[Vector]]:
    report = wrapper["fullWindowReport"]
    result = report["ledgerResult"]
    samples = result["samples"]
    expected_steps = int(report["plan"]["totalFluidSteps"])
    dt = float(report["plan"]["fluidTimeStepSeconds"])
    arithmetic = True
    times_contiguous = len(samples) == expected_steps
    aerodynamic: list[Vector] = []
    near_budgets: list[Vector] = []
    near_residuals: list[Vector] = []
    global_budgets: list[Vector] = []
    global_residuals: list[Vector] = []
    minimum_population = math.inf
    maximum_crossings = 0
    for expected_step, sample in enumerate(samples, start=1):
        times_contiguous &= int(sample["step"]) == expected_step
        times_contiguous &= close(
            float(sample["sourceTimeSeconds"]), expected_step * dt, 2e-7
        )
        aero = vector(sample["aerodynamicForceNewtons"])
        storage = vector(sample["negativeFluidMomentumStorageRateNewtons"])
        flux = vector(sample["negativeControlSurfaceMomentumFluxNewtons"])
        near_budget = vector(sample["rawControlVolumeBudgetForceNewtons"])
        near_residual = vector(sample["rawControlVolumeClosureResidualNewtons"])
        global_change = vector(sample["globalFluidMomentumChangeRateNewtons"])
        far_field = vector(sample["globalFarFieldMomentumSourceRateNewtons"])
        sponge = vector(sample["globalSpongeMomentumSourceRateNewtons"])
        global_budget = vector(sample["globalFluidBudgetForceNewtons"])
        global_residual = vector(sample["globalFluidClosureResidualNewtons"])
        arithmetic &= vector_close(near_budget, add(storage, flux))
        arithmetic &= vector_close(near_residual, subtract(aero, near_budget))
        arithmetic &= vector_close(
            global_budget, add(subtract(far_field, global_change), sponge)
        )
        arithmetic &= vector_close(global_residual, subtract(aero, global_budget))
        minimum_population = min(
            minimum_population, float(sample["minimumPopulation"])
        )
        maximum_crossings = max(
            maximum_crossings,
            int(sample["solidControlSurfaceCrossingLinkCount"]),
        )
        aerodynamic.append(aero)
        near_budgets.append(near_budget)
        near_residuals.append(near_residual)
        global_budgets.append(global_budget)
        global_residuals.append(global_residual)

    aerodynamic_rms = rms(aerodynamic)
    near_budget_rms = rms(near_budgets)
    near_residual_rms = rms(near_residuals)
    global_budget_rms = rms(global_budgets)
    global_residual_rms = rms(global_residuals)
    near_relative = near_residual_rms / max(aerodynamic_rms, near_budget_rms)
    global_relative = global_residual_rms / max(aerodynamic_rms, global_budget_rms)
    reconstructed = {
        "RMSAerodynamicForceNewtons": aerodynamic_rms,
        "RMSRawControlVolumeBudgetForceNewtons": near_budget_rms,
        "RMSRawControlVolumeClosureResidualNewtons": near_residual_rms,
        "relativeRMSRawControlVolumeClosureResidual": near_relative,
        "maximumRawControlVolumeClosureResidualNewtons": max(
            map(magnitude, near_residuals)
        ),
        "RMSGlobalFluidBudgetForceNewtons": global_budget_rms,
        "RMSGlobalFluidClosureResidualNewtons": global_residual_rms,
        "relativeRMSGlobalFluidClosureResidual": global_relative,
        "maximumGlobalFluidClosureResidualNewtons": max(
            map(magnitude, global_residuals)
        ),
    }
    summary_matches = all(
        close(float(result[key]), value) for key, value in reconstructed.items()
    )
    summary_matches &= close(float(result["minimumPopulation"]), minimum_population)
    grid_cells = int(report["gridX"]) * int(report["gridY"]) * int(report["gridZ"])
    activation_fraction = float(result["collisionLimiterActivationCount"]) / (
        grid_cells * expected_steps
    )
    summary_matches &= close(
        float(result["collisionLimiterActivationFractionOfCellSteps"]),
        activation_fraction,
    )

    first = int(target["comparisonWindow"]["firstTargetSampleIndex"])
    last = int(target["comparisonWindow"]["lastTargetSampleIndex"])
    steps_per_sample = int(report["plan"]["fluidStepsPerForceSample"])
    target_x = target["samples"]["forceXNewtons"]
    target_z = target["samples"]["forceZNewtons"]
    target_times = target["samples"]["timesSeconds"]
    recorded = report["registeredForceSamples"]
    force_bins_match = len(recorded) == EXPECTED_FORCE_SAMPLES
    forces: list[Vector] = []
    measured: list[tuple[float, float]] = []
    computed: list[tuple[float, float]] = []
    times: list[float] = []
    for offset, target_index in enumerate(range(first, last + 1)):
        end_step = target_index * steps_per_sample
        interval = aerodynamic[end_step - steps_per_sample : end_step]
        force = average(interval)
        measured_pair = (float(target_x[target_index]), float(target_z[target_index]))
        computed_pair = (force[0], force[2])
        time = float(target_times[target_index])
        item = recorded[offset]
        force_bins_match &= int(item["targetSampleIndex"]) == target_index
        force_bins_match &= close(float(item["sourceTimeSeconds"]), time)
        force_bins_match &= vector_close(
            vector(item["intervalMeanComputedForceNewtons"]), force
        )
        force_bins_match &= close(
            float(item["residualXNewtons"]), computed_pair[0] - measured_pair[0]
        )
        force_bins_match &= close(
            float(item["residualZNewtons"]), computed_pair[1] - measured_pair[1]
        )
        forces.append(force)
        measured.append(measured_pair)
        computed.append(computed_pair)
        times.append(time)

    rate = float(report["plan"]["forceSamplesPerSecond"])
    measured_impulse = trapezoidal_impulse(measured, rate)
    computed_impulse = trapezoidal_impulse(computed, rate)
    force_summary = {
        "registeredComparisonSampleCount": len(forces),
        "measuredMeanForceXNewtons": sum(value[0] for value in measured) / len(measured),
        "measuredMeanForceZNewtons": sum(value[1] for value in measured) / len(measured),
        "computedMeanForceXNewtons": sum(value[0] for value in computed) / len(computed),
        "computedMeanForceZNewtons": sum(value[1] for value in computed) / len(computed),
        "normalizedRMSError": normalized_rms(measured, computed),
        "measuredImpulseXNewtonSeconds": measured_impulse[0],
        "measuredImpulseZNewtonSeconds": measured_impulse[1],
        "computedImpulseXNewtonSeconds": computed_impulse[0],
        "computedImpulseZNewtonSeconds": computed_impulse[1],
        "measuredPeakTimeSeconds": peak_time(times, measured),
        "computedPeakTimeSeconds": peak_time(times, computed),
    }
    force_summary_matches = all(
        int(report[key]) == value
        if key == "registeredComparisonSampleCount"
        else close(float(report[key]), float(value))
        for key, value in force_summary.items()
    )
    relative_limit = float(report["maximumAllowedRelativeRMSClosureResidual"])
    activation_limit = float(
        report["maximumAllowedCollisionCorrectionActivationFraction"]
    )
    gate = (
        minimum_population > 0
        and maximum_crossings == 0
        and near_relative <= relative_limit
        and global_relative <= relative_limit
        and activation_fraction <= activation_limit
        and len(forces) == EXPECTED_FORCE_SAMPLES
    )
    checks = {
        "fixedGrid": wrapper["referenceLengthCells"] == expected_d
        and report["referenceLengthCells"] == expected_d
        and expected_steps == {8: 3_776, 12: 5_664}[expected_d],
        "validationIsolation": report["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and report["movingWallNormalization"] == EXPECTED_NORMALIZATION
        and report["productionDefaultModified"] is False
        and report["movingWallPositivityLimiterImplemented"] is False
        and report["movingWallPositivityLimiterActivationCount"] == 0
        and report["experimentalAgreementGateApplied"] is False,
        "contiguousTimes": times_contiguous,
        "sampleArithmetic": arithmetic,
        "ledgerSummaryArithmetic": summary_matches,
        "registeredForceBins": force_bins_match,
        "forceSummaryArithmetic": force_summary_matches,
        "controlVolumeClearance": maximum_crossings == 0
        and report["minimumControlSurfaceDistanceFromDomainBoundaryCells"]
        >= report["spongeWidthCells"]
        and report["minimumControlSurfaceDistanceFromSweptSurfaceCells"] > 0,
        "gateReconstruction": gate
        and result["completedSteps"] == expected_steps
        and result["allValuesFinite"] is True
        and result["sampledPopulationPositivityPassed"] is True
        and result["momentumClosurePassed"] is True
        and report["fullWindowGatePassed"] is True
        and wrapper["caseGatePassed"] is True,
    }
    return {
        "checks": checks,
        "reconstructedLedger": {
            **reconstructed,
            "minimumPopulation": minimum_population,
            "maximumSolidControlSurfaceCrossingLinkCount": maximum_crossings,
            "collisionLimiterActivationFractionOfCellSteps": activation_fraction,
        },
        "reconstructedForceSummary": force_summary,
    }, forces


def trend(coarse_d: int, fine_d: int, coarse: list[Vector], fine: list[Vector], coarse_report: dict, fine_report: dict) -> dict:
    history = pairwise_normalized_rms(coarse, fine)
    mean_difference = relative_difference(average(coarse), average(fine))
    coarse_impulse = scale(
        tuple(sum(value[axis] for value in coarse) for axis in range(3)),
        1.0 / float(coarse_report["plan"]["forceSamplesPerSecond"]),
    )
    fine_impulse = scale(
        tuple(sum(value[axis] for value in fine) for axis in range(3)),
        1.0 / float(fine_report["plan"]["forceSamplesPerSecond"]),
    )
    impulse_difference = relative_difference(coarse_impulse, fine_impulse)
    peak_difference = abs(
        float(coarse_report["computedPeakTimeSeconds"])
        - float(fine_report["computedPeakTimeSeconds"])
    )
    duration = (
        float(coarse_report["registeredForceSamples"][-1]["sourceTimeSeconds"])
        - float(coarse_report["registeredForceSamples"][0]["sourceTimeSeconds"])
    )
    normalized_peak = peak_difference / max(duration, 1e-30)
    return {
        "coarseReferenceLengthCells": coarse_d,
        "fineReferenceLengthCells": fine_d,
        "intervalForceNormalizedRMSDifference": history,
        "meanForceRelativeDifference": mean_difference,
        "impulseRelativeDifference": impulse_difference,
        "peakTimeDifferenceSeconds": peak_difference,
        "normalizedPeakTimeDifference": normalized_peak,
        "gridTrendScore": max(
            history, mean_difference, impulse_difference, normalized_peak
        ),
    }


def dictionaries_close(first: dict, second: dict) -> bool:
    return first.keys() == second.keys() and all(
        first[key] == second[key]
        if isinstance(first[key], int)
        else close(float(first[key]), float(second[key]))
        for key in first
    )


def main() -> None:
    prereg = load(PREREG_PATH)
    d8 = load(D8_PATH)
    d12 = load(D12_PATH)
    d16 = load(D16_PATH)
    d16_audit = load(D16_AUDIT_PATH)
    report = load(REPORT_PATH)
    target = load(TARGET_PATH)
    d8_audit, d8_forces = audit_case(d8, 8, target)
    d12_audit, d12_forces = audit_case(d12, 12, target)
    d16_forces = [
        vector(item["intervalMeanComputedForceNewtons"])
        for item in d16["registeredForceSamples"]
    ]
    d8_to_d12 = trend(
        8, 12, d8_forces, d12_forces,
        d8["fullWindowReport"], d12["fullWindowReport"],
    )
    d12_to_d16 = trend(
        12, 16, d12_forces, d16_forces,
        d12["fullWindowReport"], d16,
    )
    monotonic = all(
        d12_to_d16[key] <= d8_to_d12[key]
        for key in (
            "intervalForceNormalizedRMSDifference",
            "meanForceRelativeDifference",
            "impulseRelativeDifference",
        )
    )
    limit = float(prereg["maximumAllowedFineGridRelativeDifference"])
    fine_passed = all(
        d12_to_d16[key] <= limit
        for key in (
            "intervalForceNormalizedRMSDifference",
            "meanForceRelativeDifference",
            "impulseRelativeDifference",
        )
    )
    all_cases = (
        all(d8_audit["checks"].values())
        and all(d12_audit["checks"].values())
        and d16["fullWindowGatePassed"] is True
        and d16_audit["allChecksPassed"] is True
    )
    spatial_passed = all_cases and monotonic and fine_passed
    prereg_sha = sha256(PREREG_PATH)
    d8_sha = sha256(D8_PATH)
    d12_sha = sha256(D12_PATH)
    d16_sha = sha256(D16_PATH)
    checks = {
        "sourceHashes": prereg["sourceD16FullWindowSHA256"] == d16_sha
        and d8["sourceSpatialPreregistrationSHA256"] == prereg_sha
        and d12["sourceSpatialPreregistrationSHA256"] == prereg_sha
        and d8["sourceD16FullWindowSHA256"] == d16_sha
        and d12["sourceD16FullWindowSHA256"] == d16_sha
        and report["sourceSpatialPreregistrationSHA256"] == prereg_sha
        and report["sourceD8CaseSHA256"] == d8_sha
        and report["sourceD12CaseSHA256"] == d12_sha
        and report["sourceD16FullWindowSHA256"] == d16_sha,
        "preregistrationLocked": prereg["passed"] is True
        and prereg["caseReferenceLengthCells"] == [8, 12]
        and prereg["reusedReferenceLengthCells"] == 16
        and close(limit, 0.05)
        and prereg["requireMonotonicTrendReduction"] is True
        and prereg["experimentalAgreementGateApplied"] is False,
        "d8Case": all(d8_audit["checks"].values()),
        "d12Case": all(d12_audit["checks"].values()),
        "d16IndependentAudit": d16_audit["allChecksPassed"] is True
        and d16_audit["reportSHA256"] == d16_sha,
        "trendArithmetic": dictionaries_close(report["d8ToD12"], d8_to_d12)
        and dictionaries_close(report["d12ToD16"], d12_to_d16)
        and close(
            float(report["intervalForceTrendReductionRatio"]),
            d8_to_d12["intervalForceNormalizedRMSDifference"]
            / d12_to_d16["intervalForceNormalizedRMSDifference"],
        )
        and close(
            float(report["meanForceTrendReductionRatio"]),
            d8_to_d12["meanForceRelativeDifference"]
            / d12_to_d16["meanForceRelativeDifference"],
        )
        and close(
            float(report["impulseTrendReductionRatio"]),
            d8_to_d12["impulseRelativeDifference"]
            / d12_to_d16["impulseRelativeDifference"],
        ),
        "gateReconstruction": report["allCaseGatesPassed"] is all_cases
        and report["monotonicTrendReductionPassed"] is monotonic
        and report["fineGridForceConvergencePassed"] is fine_passed
        and report["spatialRefinementGatePassed"] is spatial_passed
        and report["productionPromotionAuthorized"] is False
        and report["experimentalAgreementGateApplied"] is False,
        "honestLockedRejection": all_cases
        and monotonic
        and not fine_passed
        and not spatial_passed
        and d12_to_d16["intervalForceNormalizedRMSDifference"] > limit
        and d12_to_d16["meanForceRelativeDifference"] <= limit
        and d12_to_d16["impulseRelativeDifference"] <= limit,
    }
    passed = all(checks.values())
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-spatial-refinement.py",
        "sourceSHA256": {
            "preregistration": prereg_sha,
            "d8Case": d8_sha,
            "d12Case": d12_sha,
            "d16FullWindow": d16_sha,
            "discriminator": sha256(REPORT_PATH),
        },
        "checks": checks,
        "d8Audit": d8_audit,
        "d12Audit": d12_audit,
        "reconstructedD8ToD12": d8_to_d12,
        "reconstructedD12ToD16": d12_to_d16,
        "reconstructedGate": {
            "allCaseGatesPassed": all_cases,
            "monotonicTrendReductionPassed": monotonic,
            "fineGridForceConvergencePassed": fine_passed,
            "spatialRefinementGatePassed": spatial_passed,
        },
        "allChecksPassed": passed,
        "claimBoundary": (
            "Independent ledger, registered-bin, source-hash, trend, and gate "
            "reconstruction. A green audit authenticates the locked rejection; "
            "it does not turn the failed 5% force-history gate into a pass."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("spatial audit failed: " + ", ".join(failed))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

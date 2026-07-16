#!/usr/bin/env python3
"""Independently audit the full D=16 candidate-A ledger and force bins."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
REPORT_PATH = ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window.json"
RETAINED_PATH = ARTIFACTS / "deetjen-dove-d16-moving-wall-ledger.json"
ADMISSIBILITY_PATH = (
    ARTIFACTS / "deetjen-dove-d16-moving-wall-admissibility-ab.json"
)
MANIFEST_PATH = ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
FORCE_TARGET_PATH = ROOT / "ValidationInputs/deetjen-ob-f03-force-v1.json"
OUTPUT_PATH = (
    ARTIFACTS / "deetjen-dove-d16-moving-wall-full-window-audit.json"
)

EXPECTED_MANIFEST_SHA256 = (
    "ad42148aa9ee72d994d668ba16f8b6572cb8b192b77539fe66d97586ed9e1a13"
)
EXPECTED_FORCE_TARGET_SHA256 = (
    "0ec3caf21e4b22c2f7dd81e9d5b129fec2d0535dac147d486446975144d6b12c"
)
EXPECTED_ADMISSIBILITY_SHA256 = (
    "a53f110740385fed87fd7802d2483eaa9dce46bfcc6951b62eb729725edd08b8"
)
EXPECTED_RETAINED_SHA256 = (
    "41b6fe6ace35579f67af9df8234c35e23eeed82acc2d9d088c073f9aa81a7a01"
)
EXPECTED_CANDIDATE = "pre-step-local-density-normalization"
EXPECTED_NORMALIZATION = "pre-step-local-density"
EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_STEPS = 7_552
EXPECTED_FORCE_SAMPLES = 187


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> tuple[float, float, float]:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    result = tuple(float(value) for value in raw)
    if not all(math.isfinite(value) for value in result):
        raise ValueError("nonfinite vector")
    return result  # type: ignore[return-value]


def add(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> tuple[float, float, float]:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def subtract(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> tuple[float, float, float]:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def magnitude(value: tuple[float, float, float]) -> float:
    return math.sqrt(sum(component * component for component in value))


def rms(values: list[tuple[float, float, float]]) -> float:
    return math.sqrt(
        sum(component * component for value in values for component in value)
        / len(values)
    )


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> bool:
    return all(close(a, b, 2e-8) for a, b in zip(first, second))


def mean(values: list[float]) -> float:
    return sum(values) / len(values)


def impulse(values: list[tuple[float, float]], rate: float) -> tuple[float, float]:
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


def peak_time(
    times: list[float], values: list[tuple[float, float]]
) -> float:
    index = max(
        range(len(values)),
        key=lambda item: values[item][0] ** 2 + values[item][1] ** 2,
    )
    return times[index]


def main() -> None:
    report = json.loads(REPORT_PATH.read_text())
    retained = json.loads(RETAINED_PATH.read_text())
    admissibility = json.loads(ADMISSIBILITY_PATH.read_text())
    target = json.loads(FORCE_TARGET_PATH.read_text())
    result = report["ledgerResult"]
    samples = result["samples"]
    if not isinstance(samples, list) or len(samples) != EXPECTED_STEPS:
        raise SystemExit("full-window ledger has the wrong sample count")

    aerodynamic: list[tuple[float, float, float]] = []
    near_budgets: list[tuple[float, float, float]] = []
    near_residuals: list[tuple[float, float, float]] = []
    global_budgets: list[tuple[float, float, float]] = []
    global_residuals: list[tuple[float, float, float]] = []
    minimum_population = math.inf
    maximum_crossings = 0
    sample_arithmetic = True
    contiguous_times = True
    dt = float(report["plan"]["fluidTimeStepSeconds"])

    for expected_step, sample in enumerate(samples, start=1):
        contiguous_times &= int(sample["step"]) == expected_step
        contiguous_times &= close(
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
        sample_arithmetic &= vector_close(near_budget, add(storage, flux))
        sample_arithmetic &= vector_close(
            near_residual, subtract(aero, near_budget)
        )
        reconstructed_global = add(subtract(far_field, global_change), sponge)
        sample_arithmetic &= vector_close(global_budget, reconstructed_global)
        sample_arithmetic &= vector_close(
            global_residual, subtract(aero, global_budget)
        )
        population = float(sample["minimumPopulation"])
        minimum_population = min(minimum_population, population)
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
    global_relative = global_residual_rms / max(
        aerodynamic_rms, global_budget_rms
    )
    reconstructed_ledger = {
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
    summary_arithmetic = all(
        close(float(result[key]), value)
        for key, value in reconstructed_ledger.items()
    )
    summary_arithmetic &= close(
        float(result["minimumPopulation"]), minimum_population
    )
    grid_cells = (
        int(report["gridX"]) * int(report["gridY"]) * int(report["gridZ"])
    )
    activation_fraction = float(result["collisionLimiterActivationCount"]) / (
        grid_cells * EXPECTED_STEPS
    )
    summary_arithmetic &= close(
        float(result["collisionLimiterActivationFractionOfCellSteps"]),
        activation_fraction,
    )

    first = int(target["comparisonWindow"]["firstTargetSampleIndex"])
    last = int(target["comparisonWindow"]["lastTargetSampleIndex"])
    steps_per_sample = int(report["plan"]["fluidStepsPerForceSample"])
    target_x = target["samples"]["forceXNewtons"]
    target_z = target["samples"]["forceZNewtons"]
    target_times = target["samples"]["timesSeconds"]
    recorded_force_samples = report["registeredForceSamples"]
    force_samples_match = len(recorded_force_samples) == EXPECTED_FORCE_SAMPLES
    reconstructed_force: list[tuple[float, float]] = []
    measured_force: list[tuple[float, float]] = []
    force_times: list[float] = []
    for offset, target_index in enumerate(range(first, last + 1)):
        end_step = target_index * steps_per_sample
        interval = aerodynamic[end_step - steps_per_sample : end_step]
        computed = tuple(
            sum(value[axis] for value in interval) / steps_per_sample
            for axis in range(3)
        )
        measured = (float(target_x[target_index]), float(target_z[target_index]))
        time = float(target_times[target_index])
        reconstructed_force.append((computed[0], computed[2]))
        measured_force.append(measured)
        force_times.append(time)
        recorded = recorded_force_samples[offset]
        force_samples_match &= int(recorded["targetSampleIndex"]) == target_index
        force_samples_match &= close(float(recorded["sourceTimeSeconds"]), time)
        force_samples_match &= close(
            float(recorded["measuredForceXNewtons"]), measured[0]
        )
        force_samples_match &= close(
            float(recorded["measuredForceZNewtons"]), measured[1]
        )
        force_samples_match &= vector_close(
            vector(recorded["intervalMeanComputedForceNewtons"]), computed
        )

    measured_impulse = impulse(measured_force, 2_000.0)
    computed_impulse = impulse(reconstructed_force, 2_000.0)
    force_summary = {
        "registeredComparisonSampleCount": len(reconstructed_force),
        "measuredMeanForceXNewtons": mean([value[0] for value in measured_force]),
        "measuredMeanForceZNewtons": mean([value[1] for value in measured_force]),
        "computedMeanForceXNewtons": mean(
            [value[0] for value in reconstructed_force]
        ),
        "computedMeanForceZNewtons": mean(
            [value[1] for value in reconstructed_force]
        ),
        "normalizedRMSError": normalized_rms(measured_force, reconstructed_force),
        "measuredImpulseXNewtonSeconds": measured_impulse[0],
        "measuredImpulseZNewtonSeconds": measured_impulse[1],
        "computedImpulseXNewtonSeconds": computed_impulse[0],
        "computedImpulseZNewtonSeconds": computed_impulse[1],
        "measuredPeakTimeSeconds": peak_time(force_times, measured_force),
        "computedPeakTimeSeconds": peak_time(force_times, reconstructed_force),
    }
    force_summary_match = all(
        int(report[key]) == value
        if key == "registeredComparisonSampleCount"
        else close(float(report[key]), float(value))
        for key, value in force_summary.items()
    )

    relative_limit = float(report["maximumAllowedRelativeRMSClosureResidual"])
    activation_limit = float(
        report["maximumAllowedCollisionCorrectionActivationFraction"]
    )
    reconstructed_gate = (
        minimum_population > 0
        and maximum_crossings == 0
        and near_relative <= relative_limit
        and global_relative <= relative_limit
        and activation_fraction <= activation_limit
        and len(reconstructed_force) == EXPECTED_FORCE_SAMPLES
    )
    checks = {
        "sourceHashes": report["manifestSHA256"]
        == sha256(MANIFEST_PATH)
        == EXPECTED_MANIFEST_SHA256
        and report["forceTargetSHA256"]
        == sha256(FORCE_TARGET_PATH)
        == EXPECTED_FORCE_TARGET_SHA256
        and sha256(ADMISSIBILITY_PATH) == EXPECTED_ADMISSIBILITY_SHA256
        and sha256(RETAINED_PATH) == EXPECTED_RETAINED_SHA256,
        "promotionChain": report["sourceRetainedLedgerGatePassed"] is True
        and report["sourceRetainedLedgerSteps"] == 751
        and retained["ledgerGatePassed"] is True
        and admissibility["candidateAuthorizedForProductionLedger"]
        == EXPECTED_CANDIDATE,
        "fixedExperiment": report["schemaVersion"] == 1
        and report["sourceCandidateIdentifier"] == EXPECTED_CANDIDATE
        and report["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and report["movingWallNormalization"] == EXPECTED_NORMALIZATION
        and report["referenceLengthCells"] == 16
        and report["requestedSteps"] == EXPECTED_STEPS,
        "validationIsolation": report["productionDefaultModified"] is False
        and report["movingWallPositivityLimiterImplemented"] is False
        and report["movingWallPositivityLimiterActivationCount"] == 0
        and report["experimentalAgreementGateApplied"] is False,
        "contiguousTimes": contiguous_times,
        "sampleArithmetic": sample_arithmetic,
        "ledgerSummaryArithmetic": summary_arithmetic,
        "registeredForceBins": force_samples_match,
        "forceSummaryArithmetic": force_summary_match,
        "controlVolumeClearance": maximum_crossings == 0
        and report["minimumControlSurfaceDistanceFromDomainBoundaryCells"]
        >= report["spongeWidthCells"]
        and report["minimumControlSurfaceDistanceFromSweptSurfaceCells"] > 0,
        "gateReconstruction": reconstructed_gate
        and result["completedSteps"] == EXPECTED_STEPS
        and result["allValuesFinite"] is True
        and result["sampledPopulationPositivityPassed"] is True
        and result["momentumClosurePassed"] is True
        and report["registeredWindowComplete"] is True
        and report["fullWindowGatePassed"] is True,
    }
    passed = all(checks.values())
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-d16-moving-wall-full-window.py",
        "reportSHA256": sha256(REPORT_PATH),
        "sourceRetainedLedgerSHA256": sha256(RETAINED_PATH),
        "checks": checks,
        "reconstructedLedger": {
            **reconstructed_ledger,
            "minimumPopulation": minimum_population,
            "maximumSolidControlSurfaceCrossingLinkCount": maximum_crossings,
            "collisionLimiterActivationFractionOfCellSteps": activation_fraction,
        },
        "reconstructedForceSummary": force_summary,
        "allChecksPassed": passed,
        "claimBoundary": (
            "Independent archive arithmetic and registered-force bin audit. "
            "Passing confirms the full D=16 engineering window, not spatial "
            "refinement, source-viscosity agreement, production promotion, "
            "experimental agreement, or free flight."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("full-window audit failed: " + ", ".join(failed))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

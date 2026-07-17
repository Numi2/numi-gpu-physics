#!/usr/bin/env python3
"""Independently audit the D16 source-viscosity collision A/B archive."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
INPUTS = ROOT / "ValidationInputs"
SURFACE = INPUTS / "deetjen-ob-f03-surface-v1" / "manifest.json"
FORCE = INPUTS / "deetjen-ob-f03-force-v1.json"
SCALING = ARTIFACTS / "deetjen-dove-source-scaling.json"
SCALING_AUDIT = ARTIFACTS / "deetjen-dove-source-scaling-audit.json"
PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d16-preregistration.json"
)
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d16-ab.json"
OUTPUT = ARTIFACTS / "deetjen-dove-source-viscosity-d16-audit.json"

EXPECTED_OPERATORS = [
    "positivity-preserving-regularized-bgk",
    "positivity-preserving-recursive-regularized-bgk",
]
EXPECTED_GRID = (149, 136, 131)
EXPECTED_STEPS = 1_600
REFERENCE_CELLS = 16
MOMENTUM_LIMIT = 0.005
CORRECTION_LIMIT = 0.05


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 2.0e-10) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector(value: object) -> tuple[float, float, float]:
    if not isinstance(value, list) or len(value) != 3:
        raise ValueError("expected a three-component vector")
    result = tuple(float(component) for component in value)
    if not all(math.isfinite(component) for component in result):
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


def vector_close(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
    tolerance: float = 2.0e-8,
) -> bool:
    return all(
        abs(a - b) <= tolerance * max(abs(a), abs(b), 1.0)
        for a, b in zip(first, second)
    )


def magnitude(value: tuple[float, float, float]) -> float:
    return math.sqrt(sum(component * component for component in value))


def rms(values: list[tuple[float, float, float]]) -> float:
    return math.sqrt(
        sum(sum(component * component for component in value) for value in values)
        / len(values)
    )


def audit_case(
    case: dict[str, object],
    dt: float,
    execution_floor: float,
    production_floor: float,
) -> dict[str, object]:
    operator = str(case["collisionOperator"])
    result = case.get("report")
    if not isinstance(result, dict):
        raise ValueError(f"{operator}: missing momentum report")
    samples = result.get("samples")
    if not isinstance(samples, list) or len(samples) != EXPECTED_STEPS:
        raise ValueError(f"{operator}: wrong sample count")

    aerodynamic: list[tuple[float, float, float]] = []
    raw_budgets: list[tuple[float, float, float]] = []
    raw_residuals: list[tuple[float, float, float]] = []
    global_budgets: list[tuple[float, float, float]] = []
    global_residuals: list[tuple[float, float, float]] = []
    minimum_population = math.inf
    maximum_crossings = 0

    for expected_step, sample in enumerate(samples, start=1):
        if not isinstance(sample, dict):
            raise ValueError(f"{operator}: malformed sample")
        if int(sample["step"]) != expected_step:
            raise ValueError(f"{operator}: noncontiguous step history")
        if not close(
            float(sample["sourceTimeSeconds"]), expected_step * dt, 2.0e-7
        ):
            raise ValueError(f"{operator}: source-time drift")

        aero = vector(sample["aerodynamicForceNewtons"])
        storage = vector(sample["negativeFluidMomentumStorageRateNewtons"])
        flux = vector(sample["negativeControlSurfaceMomentumFluxNewtons"])
        raw_budget = vector(sample["rawControlVolumeBudgetForceNewtons"])
        raw_residual = vector(sample["rawControlVolumeClosureResidualNewtons"])
        global_change = vector(sample["globalFluidMomentumChangeRateNewtons"])
        far_field = vector(sample["globalFarFieldMomentumSourceRateNewtons"])
        sponge = vector(sample["globalSpongeMomentumSourceRateNewtons"])
        global_budget = vector(sample["globalFluidBudgetForceNewtons"])
        global_residual = vector(sample["globalFluidClosureResidualNewtons"])
        if not vector_close(raw_budget, add(storage, flux)):
            raise ValueError(f"{operator}: near-wing budget arithmetic drift")
        if not vector_close(raw_residual, subtract(aero, raw_budget)):
            raise ValueError(f"{operator}: near-wing residual arithmetic drift")
        reconstructed_global = subtract(add(far_field, sponge), global_change)
        if not vector_close(global_budget, reconstructed_global):
            raise ValueError(f"{operator}: global budget arithmetic drift")
        if not vector_close(global_residual, subtract(aero, global_budget)):
            raise ValueError(f"{operator}: global residual arithmetic drift")

        population = float(sample["minimumPopulation"])
        if not math.isfinite(population) or population <= 0:
            raise ValueError(f"{operator}: nonpositive population")
        minimum_population = min(minimum_population, population)
        maximum_crossings = max(
            maximum_crossings,
            int(sample["solidControlSurfaceCrossingLinkCount"]),
        )
        aerodynamic.append(aero)
        raw_budgets.append(raw_budget)
        raw_residuals.append(raw_residual)
        global_budgets.append(global_budget)
        global_residuals.append(global_residual)

    aerodynamic_rms = rms(aerodynamic)
    raw_budget_rms = rms(raw_budgets)
    raw_residual_rms = rms(raw_residuals)
    global_budget_rms = rms(global_budgets)
    global_residual_rms = rms(global_residuals)
    relative_raw = raw_residual_rms / max(aerodynamic_rms, raw_budget_rms)
    relative_global = global_residual_rms / max(
        aerodynamic_rms, global_budget_rms
    )
    reconstructed = {
        "RMSAerodynamicForceNewtons": aerodynamic_rms,
        "RMSRawControlVolumeBudgetForceNewtons": raw_budget_rms,
        "RMSRawControlVolumeClosureResidualNewtons": raw_residual_rms,
        "relativeRMSRawControlVolumeClosureResidual": relative_raw,
        "maximumRawControlVolumeClosureResidualNewtons": max(
            map(magnitude, raw_residuals)
        ),
        "RMSGlobalFluidBudgetForceNewtons": global_budget_rms,
        "RMSGlobalFluidClosureResidualNewtons": global_residual_rms,
        "relativeRMSGlobalFluidClosureResidual": relative_global,
        "maximumGlobalFluidClosureResidualNewtons": max(
            map(magnitude, global_residuals)
        ),
    }
    if not all(
        close(float(result[key]), value) for key, value in reconstructed.items()
    ):
        raise ValueError(f"{operator}: summary arithmetic drift")
    if not close(float(result["minimumPopulation"]), minimum_population):
        raise ValueError(f"{operator}: minimum population drift")

    activation_count = float(result["collisionLimiterActivationCount"])
    activation_fraction = activation_count / (
        math.prod(EXPECTED_GRID) * EXPECTED_STEPS
    )
    if not close(
        activation_fraction,
        float(result["collisionLimiterActivationFractionOfCellSteps"]),
    ):
        raise ValueError(f"{operator}: correction fraction arithmetic drift")
    completion = (
        int(result["requestedSteps"]) == EXPECTED_STEPS
        and int(result["completedSteps"]) == EXPECTED_STEPS
        and bool(result["allValuesFinite"])
        and bool(result["sampledPopulationPositivityPassed"])
        and minimum_population > 0
        and maximum_crossings == 0
    )
    ledger = relative_raw <= MOMENTUM_LIMIT and relative_global <= MOMENTUM_LIMIT
    correction = activation_fraction <= CORRECTION_LIMIT and math.isfinite(
        float(result["maximumCollisionRestriction"])
    )
    actual_tau = float(case["actualTauPlus"])
    execution = actual_tau >= execution_floor
    production = actual_tau >= production_floor
    eligible = completion and ledger and correction and execution
    verdicts_match = (
        bool(result["momentumClosurePassed"]) == eligible
        and bool(result["eligibleForExtendedPilot"]) == eligible
        and bool(case["completionAndPositivityPassed"]) == completion
        and bool(case["momentumLedgerPassed"]) == ledger
        and bool(case["correctionIntrusionPassed"]) == correction
        and bool(case["executionFloorPassed"]) == execution
        and bool(case["productionMarginPassed"]) == production
        and bool(case["eligibleForD28Planning"]) == eligible
    )
    if not verdicts_match:
        raise ValueError(f"{operator}: recorded verdict drift")
    return {
        "operator": operator,
        "completedSteps": EXPECTED_STEPS,
        "minimumPopulation": minimum_population,
        "relativeRMSRawControlVolumeClosureResidual": relative_raw,
        "relativeRMSGlobalFluidClosureResidual": relative_global,
        "collisionLimiterActivationCount": activation_count,
        "collisionLimiterActivationFractionOfCellSteps": activation_fraction,
        "actualTauPlus": actual_tau,
        "executionFloorPassed": execution,
        "productionMarginPassed": production,
        "eligibleForD28Planning": eligible,
    }


def main() -> None:
    surface = json.loads(SURFACE.read_text())
    force = json.loads(FORCE.read_text())
    scaling = json.loads(SCALING.read_text())
    scaling_audit = json.loads(SCALING_AUDIT.read_text())
    preregistration = json.loads(PREREGISTRATION.read_text())
    report = json.loads(REPORT.read_text())
    d16 = next(
        item
        for item in scaling["gridReconstruction"]
        if item["referenceLengthCells"] == REFERENCE_CELLS
    )
    rho = float(scaling["sourceFluidProperties"]["airDensityKilogramsPerCubicMeter"])
    mu = float(scaling["sourceFluidProperties"]["dynamicViscosityPascalSeconds"])
    nu = mu / rho
    speed = float(
        scaling["reynoldsDefinitions"]["convertedMaximumSurfaceSpeedMetersPerSecond"]
    )
    length = float(
        scaling["reynoldsDefinitions"]["registeredReferenceLengthMeters"]
    )
    reynolds = speed * length / nu
    dx = float(d16["cellSizeMeters"])
    dt = float(d16["fluidTimeStepSeconds"])
    source_tau = 0.5 + 3.0 * nu * dt / (dx * dx)

    checks = {
        "primaryInputHashes": report["manifestSHA256"] == sha256(SURFACE)
        and report["forceTargetSHA256"] == sha256(FORCE)
        and report["datasetIdentifier"] == surface["datasetIdentifier"]
        and report["forceTargetIdentifier"] == force["datasetIdentifier"],
        "sourceEvidenceHashes": report["sourceScalingReportSHA256"]
        == sha256(SCALING)
        and report["sourceScalingAuditSHA256"] == sha256(SCALING_AUDIT)
        and scaling_audit["reportSHA256"] == sha256(SCALING)
        and scaling_audit["allChecksPassed"],
        "preregistrationHash": report["sourcePreregistrationSHA256"]
        == sha256(PREREGISTRATION),
        "sourceReynoldsReconstruction": close(
            reynolds, float(preregistration["sourcePropertyReynoldsNumber"])
        ),
        "sourceTauReconstruction": close(
            source_tau, float(preregistration["sourceTauPlus"]), 2.0e-7
        ),
        "fixedD16Contract": preregistration["referenceLengthCells"]
        == REFERENCE_CELLS
        and preregistration["requestedSteps"] == EXPECTED_STEPS
        and preregistration["candidateOperators"] == EXPECTED_OPERATORS
        and preregistration["movingWallNormalization"]
        == "pre-step-local-density"
        and close(
            float(preregistration["maximumRelativeRMSClosureResidual"]),
            MOMENTUM_LIMIT,
        )
        and close(
            float(preregistration["maximumCorrectionActivationFraction"]),
            CORRECTION_LIMIT,
        ),
        "runtimeGrid": tuple(report[key] for key in ("gridX", "gridY", "gridZ"))
        == EXPECTED_GRID
        and report["referenceLengthCells"] == REFERENCE_CELLS
        and report["requestedSteps"] == EXPECTED_STEPS,
        "candidateOrder": [
            case["collisionOperator"] for case in report["cases"]
        ]
        == EXPECTED_OPERATORS,
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("source-viscosity contract failed: " + ", ".join(failed))

    case_results = [
        audit_case(
            case,
            dt,
            float(preregistration["executionMinimumTauPlus"]),
            float(preregistration["productionMinimumTauPlus"]),
        )
        for case in report["cases"]
    ]
    eligible = [
        case["operator"]
        for case in case_results
        if case["eligibleForD28Planning"]
    ]
    checks.update(
        {
            "perStepPositivityAndCompletion": all(
                case["completedSteps"] == EXPECTED_STEPS
                and case["minimumPopulation"] > 0
                for case in case_results
            ),
            "independentNearWingMomentumClosure": all(
                case["relativeRMSRawControlVolumeClosureResidual"]
                <= MOMENTUM_LIMIT
                for case in case_results
            ),
            "independentGlobalMomentumClosure": all(
                case["relativeRMSGlobalFluidClosureResidual"] <= MOMENTUM_LIMIT
                for case in case_results
            ),
            "independentCorrectionGate": all(
                case["collisionLimiterActivationFractionOfCellSteps"]
                <= CORRECTION_LIMIT
                for case in case_results
            ),
            "parentVerdict": eligible == EXPECTED_OPERATORS
            and report["eligibleCollisionOperators"] == EXPECTED_OPERATORS
            and report["allCandidateRunsCompleted"]
            and report["screeningGatePassed"]
            and report["d28PlanningAuthorized"],
            "safetyBoundary": not report["d20RunAuthorized"]
            and not report["d28RunAuthorized"]
            and report["fluidEvolutionExecuted"]
            and not report["productionModificationAuthorized"]
            and not report["experimentalAgreementGateApplied"]
            and all(not case["productionMarginPassed"] for case in case_results),
            "classification": report["classification"]
            == "both-source-viscosity-operators-survive-and-close-at-d16",
        }
    )
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("source-viscosity audit failed: " + ", ".join(failed))

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-source-viscosity-d16-audit-v1",
        "generatedBy": "Scripts/audit-dove-source-viscosity-d16.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "reportSHA256": sha256(REPORT),
        "sourceScalingReportSHA256": sha256(SCALING),
        "sourceScalingAuditSHA256": sha256(SCALING_AUDIT),
        "independentReconstruction": {
            "sourcePropertyReynoldsNumber": reynolds,
            "sourceTauPlus": source_tau,
            "cases": case_results,
        },
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": True,
        "eligibleCollisionOperators": eligible,
        "d28PlanningGatePassed": True,
        "claimBoundary": (
            "This audit independently reconstructs all per-step D16 source-"
            "viscosity positivity and momentum arithmetic. It authorizes D28 "
            "planning only; it does not authorize D20, D28 execution, a "
            "production change, or experimental-force agreement."
        ),
    }
    OUTPUT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

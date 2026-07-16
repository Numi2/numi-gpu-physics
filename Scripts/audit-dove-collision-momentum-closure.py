#!/usr/bin/env python3
"""Independently audit the committed measured-dove momentum-closure report."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = (
    ROOT / "ValidationArtifacts/deetjen-dove-collision-momentum-closure.json"
)
AUDIT_PATH = (
    ROOT
    / "ValidationArtifacts/deetjen-dove-collision-momentum-closure-audit.json"
)
SURFACE_MANIFEST_PATH = (
    ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
)
FORCE_TARGET_PATH = ROOT / "ValidationInputs/deetjen-ob-f03-force-v1.json"

EXPECTED_SURFACE_HASH = (
    "ad42148aa9ee72d994d668ba16f8b6572cb8b192b77539fe66d97586ed9e1a13"
)
EXPECTED_FORCE_HASH = (
    "0ec3caf21e4b22c2f7dd81e9d5b129fec2d0535dac147d486446975144d6b12c"
)
EXPECTED_OPERATORS = [
    "positivity-preserving-regularized-bgk",
    "positivity-preserving-recursive-regularized-bgk",
]
EXPECTED_ACTIVATIONS = {
    "positivity-preserving-regularized-bgk": 55,
    "positivity-preserving-recursive-regularized-bgk": 28,
}
EXPECTED_STEPS = 800
EXPECTED_DT = 0.000_031_25
EXPECTED_GRID = (75, 69, 66)
EXPECTED_BOUNDS = {
    "minimumX": 7,
    "minimumY": 7,
    "minimumZ": 7,
    "maximumExclusiveX": 68,
    "maximumExclusiveY": 62,
    "maximumExclusiveZ": 59,
}
RELATIVE_TOLERANCE = 0.005
ACTIVATION_TOLERANCE = 0.05


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(values: object) -> tuple[float, float, float]:
    if not isinstance(values, list) or len(values) != 3:
        raise ValueError("expected a three-component vector")
    result = tuple(float(value) for value in values)
    if not all(math.isfinite(value) for value in result):
        raise ValueError("nonfinite vector component")
    return result  # type: ignore[return-value]


def subtract(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> tuple[float, float, float]:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def add(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
) -> tuple[float, float, float]:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def magnitude(values: tuple[float, float, float]) -> float:
    return math.sqrt(sum(value * value for value in values))


def rms(vectors: list[tuple[float, float, float]]) -> float:
    return math.sqrt(
        sum(sum(value * value for value in item) for item in vectors)
        / len(vectors)
    )


def close(first: float, second: float, tolerance: float = 2.0e-10) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
    tolerance: float = 2.0e-8,
) -> bool:
    return all(
        abs(a - b) <= tolerance * max(abs(a), abs(b), 1.0)
        for a, b in zip(first, second)
    )


def audit_case(case: dict[str, object]) -> dict[str, object]:
    operator = str(case["collisionOperator"])
    samples = case["samples"]
    if not isinstance(samples, list):
        raise ValueError(f"{operator}: samples are missing")
    if len(samples) != EXPECTED_STEPS:
        raise ValueError(f"{operator}: wrong sample count")

    aerodynamic: list[tuple[float, float, float]] = []
    raw_budgets: list[tuple[float, float, float]] = []
    raw_residuals: list[tuple[float, float, float]] = []
    global_budgets: list[tuple[float, float, float]] = []
    global_residuals: list[tuple[float, float, float]] = []
    minimum_population = math.inf
    maximum_crossings = 0

    for expected_step, raw_sample in enumerate(samples, start=1):
        if not isinstance(raw_sample, dict):
            raise ValueError(f"{operator}: malformed sample")
        if int(raw_sample["step"]) != expected_step:
            raise ValueError(f"{operator}: noncontiguous steps")
        expected_time = expected_step * EXPECTED_DT
        if not close(float(raw_sample["sourceTimeSeconds"]), expected_time, 2e-7):
            raise ValueError(f"{operator}: source-time drift")

        aero = vector(raw_sample["aerodynamicForceNewtons"])
        storage = vector(raw_sample["negativeFluidMomentumStorageRateNewtons"])
        flux = vector(raw_sample["negativeControlSurfaceMomentumFluxNewtons"])
        raw_budget = vector(raw_sample["rawControlVolumeBudgetForceNewtons"])
        raw_residual = vector(
            raw_sample["rawControlVolumeClosureResidualNewtons"]
        )
        global_budget = vector(raw_sample["globalFluidBudgetForceNewtons"])
        global_change = vector(
            raw_sample["globalFluidMomentumChangeRateNewtons"]
        )
        far_field = vector(
            raw_sample["globalFarFieldMomentumSourceRateNewtons"]
        )
        sponge = vector(raw_sample["globalSpongeMomentumSourceRateNewtons"])
        global_residual = vector(
            raw_sample["globalFluidClosureResidualNewtons"]
        )
        if not vector_close(raw_budget, add(storage, flux)):
            raise ValueError(f"{operator}: control budget arithmetic failed")
        if not vector_close(raw_residual, subtract(aero, raw_budget)):
            raise ValueError(f"{operator}: control residual arithmetic failed")
        reconstructed_global_budget = subtract(
            add(far_field, sponge), global_change
        )
        if not vector_close(global_budget, reconstructed_global_budget):
            raise ValueError(f"{operator}: global budget arithmetic failed")
        if not vector_close(global_residual, subtract(aero, global_budget)):
            raise ValueError(f"{operator}: global residual arithmetic failed")

        population = float(raw_sample["minimumPopulation"])
        if not math.isfinite(population) or population <= 0:
            raise ValueError(f"{operator}: nonpositive population")
        minimum_population = min(minimum_population, population)
        crossings = int(raw_sample["solidControlSurfaceCrossingLinkCount"])
        maximum_crossings = max(maximum_crossings, crossings)
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
    maximum_raw = max(map(magnitude, raw_residuals))
    maximum_global = max(map(magnitude, global_residuals))

    recorded = {
        "aerodynamic": float(case["RMSAerodynamicForceNewtons"]),
        "raw_budget": float(case["RMSRawControlVolumeBudgetForceNewtons"]),
        "raw_residual": float(case["RMSRawControlVolumeClosureResidualNewtons"]),
        "relative_raw": float(case["relativeRMSRawControlVolumeClosureResidual"]),
        "maximum_raw": float(case["maximumRawControlVolumeClosureResidualNewtons"]),
        "global_budget": float(case["RMSGlobalFluidBudgetForceNewtons"]),
        "global_residual": float(case["RMSGlobalFluidClosureResidualNewtons"]),
        "relative_global": float(case["relativeRMSGlobalFluidClosureResidual"]),
        "maximum_global": float(case["maximumGlobalFluidClosureResidualNewtons"]),
    }
    reconstructed = {
        "aerodynamic": aerodynamic_rms,
        "raw_budget": raw_budget_rms,
        "raw_residual": raw_residual_rms,
        "relative_raw": relative_raw,
        "maximum_raw": maximum_raw,
        "global_budget": global_budget_rms,
        "global_residual": global_residual_rms,
        "relative_global": relative_global,
        "maximum_global": maximum_global,
    }
    if not all(close(recorded[key], value) for key, value in reconstructed.items()):
        raise ValueError(f"{operator}: summary arithmetic drift")
    if not close(float(case["minimumPopulation"]), minimum_population):
        raise ValueError(f"{operator}: minimum-population drift")
    if int(case["maximumSolidControlSurfaceCrossingLinkCount"]) != maximum_crossings:
        raise ValueError(f"{operator}: crossing-count drift")
    if int(float(case["collisionLimiterActivationCount"])) != EXPECTED_ACTIVATIONS[operator]:
        raise ValueError(f"{operator}: activation-count drift")
    expected_fraction = EXPECTED_ACTIVATIONS[operator] / (
        EXPECTED_STEPS * math.prod(EXPECTED_GRID)
    )
    if not close(
        float(case["collisionLimiterActivationFractionOfCellSteps"]),
        expected_fraction,
    ):
        raise ValueError(f"{operator}: activation-fraction drift")
    passed = (
        int(case["requestedSteps"]) == EXPECTED_STEPS
        and int(case["completedSteps"]) == EXPECTED_STEPS
        and bool(case["allValuesFinite"])
        and bool(case["sampledPopulationPositivityPassed"])
        and maximum_crossings == 0
        and relative_raw <= RELATIVE_TOLERANCE
        and relative_global <= RELATIVE_TOLERANCE
        and expected_fraction <= ACTIVATION_TOLERANCE
    )
    if bool(case["momentumClosurePassed"]) != passed:
        raise ValueError(f"{operator}: closure verdict drift")
    if bool(case["eligibleForExtendedPilot"]) != passed:
        raise ValueError(f"{operator}: eligibility drift")
    return {
        "operator": operator,
        "minimumPopulation": minimum_population,
        "collisionLimiterActivationCount": EXPECTED_ACTIVATIONS[operator],
        "relativeRMSRawControlVolumeClosureResidual": relative_raw,
        "relativeRMSGlobalFluidClosureResidual": relative_global,
        "maximumRawControlVolumeClosureResidualNewtons": maximum_raw,
        "maximumGlobalFluidClosureResidualNewtons": maximum_global,
        "passed": passed,
    }


def main() -> None:
    report = json.loads(REPORT_PATH.read_text())
    manifest = json.loads(SURFACE_MANIFEST_PATH.read_text())
    force_target = json.loads(FORCE_TARGET_PATH.read_text())
    cases = report.get("cases")
    if not isinstance(cases, list):
        raise SystemExit("momentum report has no cases")
    operators = [str(case["collisionOperator"]) for case in cases]
    checks = {
        "schemaAndHashes": report.get("schemaVersion") == 1
        and report.get("manifestSHA256") == EXPECTED_SURFACE_HASH
        and report.get("forceTargetSHA256") == EXPECTED_FORCE_HASH
        and sha256(SURFACE_MANIFEST_PATH) == EXPECTED_SURFACE_HASH
        and sha256(FORCE_TARGET_PATH) == EXPECTED_FORCE_HASH
        and report.get("datasetIdentifier")
        == manifest.get("datasetIdentifier")
        and report.get("forceTargetIdentifier")
        == force_target.get("datasetIdentifier"),
        "fixedScreenContract": report.get("requestedSteps") == EXPECTED_STEPS
        and tuple(report.get(key) for key in ("gridX", "gridY", "gridZ"))
        == EXPECTED_GRID
        and report.get("controlVolume") == EXPECTED_BOUNDS
        and report.get("spongeWidthCells") == 6
        and report.get("minimumControlSurfaceDistanceFromDomainBoundaryCells")
        == 6
        and close(
            float(report.get("minimumControlSurfaceDistanceFromSweptSurfaceCells")),
            5.0,
        )
        and close(
            float(report.get("maximumAllowedRelativeRMSClosureResidual")),
            RELATIVE_TOLERANCE,
        )
        and close(
            float(report.get("maximumCorrectionActivationFraction")),
            ACTIVATION_TOLERANCE,
        ),
        "candidateOrder": operators == EXPECTED_OPERATORS,
        "nonAcceptanceBoundary": not report.get("experimentalAgreementGateApplied")
        and "does not select a production collision operator"
        in str(report.get("claimBoundary")),
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("report contract failed: " + ", ".join(failed))

    case_results = [audit_case(case) for case in cases]
    all_cases_passed = all(bool(case["passed"]) for case in case_results)
    checks.update(
        {
            "allCandidateRunsCompleted": bool(
                report.get("allCandidateRunsCompleted")
            ),
            "bothControlVolumeClosures": all(
                float(case["relativeRMSRawControlVolumeClosureResidual"])
                <= RELATIVE_TOLERANCE
                for case in case_results
            ),
            "bothGlobalClosures": all(
                float(case["relativeRMSGlobalFluidClosureResidual"])
                <= RELATIVE_TOLERANCE
                for case in case_results
            ),
            "bothCandidatesEligible": report.get("eligibleCollisionOperators")
            == EXPECTED_OPERATORS,
            "parentVerdict": bool(report.get("screeningGatePassed"))
            and all_cases_passed,
        }
    )
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("momentum closure failed: " + ", ".join(failed))

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-collision-momentum-closure-audit-v1",
        "generatedBy": "Scripts/audit-dove-collision-momentum-closure.py",
        "reportSHA256": sha256(REPORT_PATH),
        "surfaceManifestSHA256": EXPECTED_SURFACE_HASH,
        "forceTargetSHA256": EXPECTED_FORCE_HASH,
        "checks": checks,
        "cases": case_results,
        "momentumClosureGatePassed": True,
        "eligibleCollisionOperators": EXPECTED_OPERATORS,
        "claimBoundary": (
            "This audit independently reconstructs the committed near-wing and "
            "global momentum-closure arithmetic. It advances both candidates to "
            "the extended pilot only; it does not select a production operator "
            "or establish experimental-force agreement."
        ),
    }
    AUDIT_PATH.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

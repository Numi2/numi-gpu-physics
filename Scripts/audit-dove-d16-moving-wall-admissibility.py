#!/usr/bin/env python3
"""Independently audit the D=16 one-cell moving-wall admissibility A/B."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
DEFAULT_REPORT = ARTIFACTS / "deetjen-dove-d16-moving-wall-admissibility-ab.json"
DEFAULT_BOUNDARY = ARTIFACTS / "deetjen-dove-d16-boundary-term-decomposition.json"
DEFAULT_PROVENANCE = ARTIFACTS / "deetjen-dove-d16-population-stage-provenance.json"
DEFAULT_COMPLETION = ARTIFACTS / "deetjen-dove-collision-grid-completion.json"
DEFAULT_OUTPUT = ARTIFACTS / "deetjen-dove-d16-moving-wall-admissibility-ab-audit.json"

C = [
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
OPPOSITE = [0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15, 18, 17]


def f32(value: float) -> float:
    return struct.unpack("f", struct.pack("f", value))[0]


W = [f32(1.0 / 3.0)] + [f32(1.0 / 18.0)] * 6 + [f32(1.0 / 36.0)] * 12
CS = f32(math.sqrt(f32(1.0 / 3.0)))


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 2e-10) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: list[float], second: list[float]) -> bool:
    return len(first) == len(second) and all(
        close(a, b) for a, b in zip(first, second)
    )


def candidate_summary(
    identifier: str,
    scale: float,
    base: list[float],
    wall: list[float],
    floor: float,
    speed_limit: float,
    intervention: bool,
) -> tuple[list[float], dict]:
    values = [base[q] + scale * wall[q] for q in range(19)]
    density = sum(values)
    momentum = [
        sum(C[q][axis] * values[q] for q in range(19))
        for axis in range(3)
    ]
    velocity = [component / density for component in momentum]
    speed_squared = sum(component * component for component in velocity)
    speed = math.sqrt(speed_squared)
    equilibrium = []
    for q in range(19):
        projection = sum(C[q][axis] * velocity[axis] for axis in range(3))
        equilibrium.append(
            W[q]
            * density
            * (1.0 + 3.0 * projection + 4.5 * projection**2 - 1.5 * speed_squared)
        )
    wall_momentum = [
        sum(C[q][axis] * scale * wall[q] for q in range(19))
        for axis in range(3)
    ]
    floor_violations = [q for q, value in enumerate(values) if value < floor - 1e-12]
    finite = all(math.isfinite(value) for value in values + equilibrium)
    summary = {
        "identifier": identifier,
        "correctionScaleRelativeToReferenceDensity": scale,
        "positivityInterventionActive": intervention,
        "reconstructedDensity": density,
        "reconstructedMomentum": momentum,
        "reconstructedVelocity": velocity,
        "reconstructedSpeed": speed,
        "reconstructedLatticeMach": speed / CS,
        "minimumPopulation": min(values),
        "minimumEquilibriumPopulation": min(equilibrium),
        "negativePopulationDirections": [q for q, value in enumerate(values) if value < 0],
        "populationFloorViolationDirections": floor_violations,
        "wallMassContribution": scale * sum(wall),
        "wallMomentumContribution": wall_momentum,
        "populationGatePassed": finite and not floor_violations,
        "equilibriumGatePassed": finite and min(equilibrium) >= -1e-12 and speed <= speed_limit,
    }
    return values, summary


def summary_close(actual: dict, expected: dict) -> bool:
    scalar_keys = [
        "correctionScaleRelativeToReferenceDensity",
        "reconstructedDensity",
        "reconstructedSpeed",
        "reconstructedLatticeMach",
        "minimumPopulation",
        "minimumEquilibriumPopulation",
        "wallMassContribution",
    ]
    vector_keys = [
        "reconstructedMomentum",
        "reconstructedVelocity",
        "wallMomentumContribution",
    ]
    exact_keys = [
        "identifier",
        "positivityInterventionActive",
        "negativePopulationDirections",
        "populationFloorViolationDirections",
        "populationGatePassed",
        "equilibriumGatePassed",
    ]
    return (
        all(close(actual[key], expected[key]) for key in scalar_keys)
        and all(vector_close(actual[key], expected[key]) for key in vector_keys)
        and all(actual[key] == expected[key] for key in exact_keys)
    )


def audit(args: argparse.Namespace) -> dict:
    report = load(args.report)
    boundary = load(args.boundary)
    provenance = load(args.provenance)
    completion = load(args.completion)
    completion_report = completion["d16Case"]["report"]
    failure_step = completion_report["firstNegativePopulationStep"]
    stage = next(sample for sample in provenance["samples"] if sample["step"] == failure_step)
    boundary_samples = [
        sample for sample in boundary["samples"] if sample["step"] == failure_step
    ]
    checks: dict[str, bool] = {}
    checks["schema"] = report["schemaVersion"] == 1
    checks["lockedInputs"] = (
        report["selectedCollisionOperator"]
        == boundary["selectedCollisionOperator"]
        == provenance["selectedCollisionOperator"]
        == completion["selectedCollisionOperator"]
        and report["referenceLengthCells"] == 16
        and report["failureStep"] == failure_step == 751
        and report["targetCellCoordinate"]
        == boundary["targetCellCoordinate"]
        == provenance["targetCellCoordinate"]
    )
    checks["diagnosticIsolation"] = (
        report["productionStateModifiedByDiagnostic"] is False
        and report["fluidSimulationRerun"] is False
        and report["sourceBoundaryTermGatePassed"] is True
        and report["sourcePopulationProvenanceGatePassed"] is True
    )

    pre_step: list[float | None] = [None] * 19
    pre_step[provenance["targetDirection"]] = stage["preStepPopulation"]
    for sample in boundary_samples:
        pre_step[OPPOSITE[sample["direction"]]] = sample["reflectedPopulation"]
        if sample["auxiliaryRole"] == "previous-target-incoming":
            pre_step[sample["direction"]] = sample["auxiliaryPopulation"]
    coverage = [q for q, value in enumerate(pre_step) if value is not None]
    checks["preStepPopulationCoverage"] = (
        coverage == list(range(19))
        and coverage == report["preStepPopulationCoverageDirections"]
    )
    pre_step_density = sum(value for value in pre_step if value is not None)
    checks["preStepDensity"] = close(pre_step_density, report["preStepLocalDensity"])

    reference = stage["reconstructedPopulations"]
    wall = [0.0] * 19
    for sample in boundary_samples:
        wall[sample["direction"]] = sample["wallCorrectionContribution"]
    base = [reference[q] - wall[q] for q in range(19)]
    base_density = sum(base)
    denominator = 1.0 - sum(wall)
    self_consistent_density = base_density / denominator
    positivity_scale = min(
        [1.0]
        + [
            (base[q] - stage["populationFloor"]) / -wall[q]
            for q in range(19)
            if wall[q] < 0
        ]
    )
    checks["derivedScalars"] = all(
        [
            close(report["referenceDensity"], 1.0),
            close(report["populationFloor"], stage["populationFloor"]),
            close(report["baseDensityWithoutWallCorrection"], base_density),
            close(report["selfConsistentDensityDenominator"], denominator),
            close(report["selfConsistentLocalDensity"], self_consistent_density),
            close(report["globalPositivityAdmissibilityScale"], positivity_scale),
        ]
    )

    a_values, candidate_a = candidate_summary(
        "pre-step-local-density-normalization",
        pre_step_density,
        base,
        wall,
        stage["populationFloor"],
        stage["restEquilibriumPositivitySpeedLimit"],
        False,
    )
    b_values, candidate_b = candidate_summary(
        "reference-density-global-positivity-scale",
        positivity_scale,
        base,
        wall,
        stage["populationFloor"],
        stage["restEquilibriumPositivitySpeedLimit"],
        True,
    )
    self_values, self_consistent = candidate_summary(
        "self-consistent-local-density-crosscheck",
        self_consistent_density,
        base,
        wall,
        stage["populationFloor"],
        stage["restEquilibriumPositivitySpeedLimit"],
        False,
    )
    reference_values, reference_summary = candidate_summary(
        "reference-density-production-baseline",
        1.0,
        base,
        wall,
        stage["populationFloor"],
        stage["restEquilibriumPositivitySpeedLimit"],
        False,
    )
    checks["referenceParity"] = (
        all(close(a, b) for a, b in zip(reference_values, reference))
        and summary_close(report["referenceDensityBaseline"], reference_summary)
    )
    checks["candidateA"] = summary_close(report["candidateA"], candidate_a)
    checks["candidateB"] = summary_close(report["candidateB"], candidate_b)
    checks["selfConsistentCrosscheck"] = summary_close(
        report["selfConsistentDensityCrosscheck"], self_consistent
    )
    checks["directionSamples"] = all(
        sample["direction"] == q
        and close(sample["basePopulationWithoutWallCorrection"], base[q])
        and close(sample["referenceDensityPopulation"], reference_values[q])
        and close(sample["preStepLocalDensityPopulation"], a_values[q])
        and close(sample["selfConsistentLocalDensityPopulation"], self_values[q])
        and close(sample["positivityAdmissiblePopulation"], b_values[q])
        and close(sample["referenceDensityWallContribution"], wall[q])
        for q, sample in enumerate(report["directionSamples"])
    )
    checks["discriminator"] = (
        not reference_summary["populationGatePassed"]
        and not reference_summary["equilibriumGatePassed"]
        and candidate_a["populationGatePassed"]
        and candidate_a["equilibriumGatePassed"]
        and candidate_b["populationGatePassed"]
        and candidate_b["equilibriumGatePassed"]
        and self_consistent["populationGatePassed"]
        and self_consistent["equilibriumGatePassed"]
        and pre_step_density <= positivity_scale < 1.0
    )
    checks["promotionBoundary"] = (
        report["candidateAuthorizedForProductionLedger"]
        == "pre-step-local-density-normalization"
        and report["admissibilityABGatePassed"] is True
        and report["experimentalAgreementGateApplied"] is False
        and "must close the force and fluid-momentum ledgers"
        in report["claimBoundary"]
    )
    passed = all(checks.values())
    return {
        "schemaVersion": 1,
        "reportSHA256": sha256(args.report),
        "boundaryTermSHA256": sha256(args.boundary),
        "populationProvenanceSHA256": sha256(args.provenance),
        "completionSHA256": sha256(args.completion),
        "checks": checks,
        "reconstructed": {
            "preStepLocalDensity": pre_step_density,
            "baseDensityWithoutWallCorrection": base_density,
            "selfConsistentLocalDensity": self_consistent_density,
            "globalPositivityAdmissibilityScale": positivity_scale,
            "candidateAMinimumPopulation": min(a_values),
            "candidateBMinimumPopulation": min(b_values),
        },
        "candidateAuthorizedForProductionLedger": (
            "pre-step-local-density-normalization" if passed else None
        ),
        "passed": passed,
        "claimBoundary": (
            "Independent archive algebra only. Passing authorizes candidate A "
            "for a controlled force and momentum ledger, not production use."
        ),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--boundary", type=Path, default=DEFAULT_BOUNDARY)
    parser.add_argument("--provenance", type=Path, default=DEFAULT_PROVENANCE)
    parser.add_argument("--completion", type=Path, default=DEFAULT_COMPLETION)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    result = audit(args)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    if not result["passed"]:
        failed = [name for name, passed in result["checks"].items() if not passed]
        raise SystemExit("moving-wall admissibility audit failed: " + ", ".join(failed))
    print(
        "moving-wall admissibility audit passed: candidate="
        + result["candidateAuthorizedForProductionLedger"]
    )


if __name__ == "__main__":
    main()

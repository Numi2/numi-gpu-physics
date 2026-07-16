#!/usr/bin/env python3
"""Independently audit the D=16 moving-boundary term decomposition."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DECOMPOSITION = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-d16-boundary-term-decomposition.json"
)
DEFAULT_PROVENANCE = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-d16-population-stage-provenance.json"
)
DEFAULT_COMPLETION = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-collision-grid-completion.json"
)
DEFAULT_OUTPUT = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-d16-boundary-term-decomposition-audit.json"
)

W = [1.0 / 3.0] + [1.0 / 18.0] * 6 + [1.0 / 36.0] * 12
CS2 = 1.0 / 3.0


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 2e-7) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def wall_correction(direction: int, projection: float) -> float:
    return 2.0 * W[direction] * projection / CS2


def expected_terms(sample: dict) -> dict[str, float]:
    direction = sample["direction"]
    branch = sample["branch"]
    fraction = sample["linkFraction"]
    reflected = sample["reflectedPopulation"]
    auxiliary = sample["auxiliaryPopulation"]
    raw_wall = wall_correction(
        direction, sample["productionWallDirectionProjectionLattice"]
    )
    halfway_wall = wall_correction(
        direction, sample["sourceWallDirectionProjectionLattice"]
    )
    if branch == "halfway-fallback":
        reflected_contribution = reflected
        auxiliary_contribution = 0.0
        wall_contribution = raw_wall
    elif branch == "interpolated-near-wall":
        reflected_contribution = 2.0 * fraction * reflected
        auxiliary_contribution = (1.0 - 2.0 * fraction) * auxiliary
        wall_contribution = raw_wall
    elif branch == "interpolated-far-wall":
        denominator = 2.0 * fraction
        reflected_contribution = reflected / denominator
        auxiliary_contribution = (
            (2.0 * fraction - 1.0) * auxiliary / denominator
        )
        wall_contribution = raw_wall / denominator
    else:
        raise ValueError(f"unexpected boundary branch: {branch}")
    production = (
        reflected_contribution + auxiliary_contribution + wall_contribution
    )
    return {
        "rawWallCorrection": raw_wall,
        "halfwayWallCorrection": halfway_wall,
        "reflectedContribution": reflected_contribution,
        "auxiliaryContribution": auxiliary_contribution,
        "wallCorrectionContribution": wall_contribution,
        "productionReconstructedPopulation": production,
        "halfwayMovingWallPopulation": reflected + halfway_wall,
        "interpolatedZeroWallPopulation": (
            reflected_contribution + auxiliary_contribution
        ),
        "halfwayZeroWallPopulation": reflected,
        "interpolatedNoAuxiliaryPopulation": (
            reflected_contribution + wall_contribution
        ),
    }


def audit(args: argparse.Namespace) -> dict:
    decomposition = load(args.decomposition)
    provenance = load(args.provenance)
    completion = load(args.completion)
    completion_report = completion["d16Case"]["report"]
    checks: dict[str, bool] = {}

    checks["schema"] = decomposition["schemaVersion"] == 1
    checks["lockedInputs"] = (
        decomposition["selectedCollisionOperator"]
        == provenance["selectedCollisionOperator"]
        == completion["selectedCollisionOperator"]
        and decomposition["referenceLengthCells"] == 16
        and decomposition["targetCellCoordinate"]
        == provenance["targetCellCoordinate"]
        == completion_report["firstNegativePopulationCellCoordinate"]
    )
    failure_step = completion_report["firstNegativePopulationStep"]
    checks["captureWindow"] = decomposition["capturedSteps"] == [
        failure_step - 1,
        failure_step,
    ]
    checks["diagnosticIsolation"] = (
        decomposition["productionStateModifiedByDiagnostic"] is False
        and decomposition["diagnosticKernel"]
        == "captureIndexedBoundaryTermDecomposition"
    )

    stage_by_step = {sample["step"]: sample for sample in provenance["samples"]}
    samples_by_step: dict[int, list[dict]] = {}
    for sample in decomposition["samples"]:
        samples_by_step.setdefault(sample["step"], []).append(sample)
    checks["boundaryDirectionCoverage"] = all(
        sorted(sample["direction"] for sample in samples_by_step[step])
        == sorted(stage_by_step[step]["movingBoundaryDirections"])
        for step in decomposition["capturedSteps"]
    )

    reconstructed_differences = []
    closure_residuals = []
    independent_term_checks = []
    for sample in decomposition["samples"]:
        step = sample["step"]
        direction = sample["direction"]
        reconstructed_differences.append(
            abs(
                sample["productionReconstructedPopulation"]
                - stage_by_step[step]["reconstructedPopulations"][direction]
            )
        )
        terms = expected_terms(sample)
        independent_term_checks.append(
            all(close(sample[name], value) for name, value in terms.items())
        )
        closure = sample["productionReconstructedPopulation"] - (
            sample["reflectedContribution"]
            + sample["auxiliaryContribution"]
            + sample["wallCorrectionContribution"]
        )
        closure_residuals.append(abs(closure))
        independent_term_checks.append(
            close(closure, sample["contributionClosureResidual"], 1e-9)
        )
    tolerance = decomposition["maximumAllowedAbsoluteResidual"]
    maximum_reconstruction = max(reconstructed_differences)
    maximum_closure = max(closure_residuals)
    checks["stageArtifactReconstructionParity"] = (
        maximum_reconstruction <= tolerance
        and close(
            maximum_reconstruction,
            decomposition["maximumReconstructionDifferenceFromStageArtifact"],
            1e-9,
        )
    )
    checks["contributionClosure"] = (
        maximum_closure <= tolerance
        and close(
            maximum_closure,
            decomposition["maximumContributionClosureResidual"],
            1e-9,
        )
    )
    checks["independentBoundaryAlgebra"] = all(independent_term_checks)

    previous = samples_by_step[failure_step - 1]
    failure = samples_by_step[failure_step]
    previous_negative = sorted(
        sample["direction"]
        for sample in previous
        if sample["productionReconstructedPopulation"] < 0
    )
    failure_negative_samples = [
        sample
        for sample in failure
        if sample["productionReconstructedPopulation"] < 0
    ]
    failure_negative = sorted(
        sample["direction"] for sample in failure_negative_samples
    )
    checks["negativeDirectionTransition"] = (
        previous_negative
        == decomposition["negativeMovingBoundaryDirectionsPreviousStep"]
        and failure_negative
        == decomposition["negativeMovingBoundaryDirectionsAtFailure"]
        == provenance["negativeMovingBoundaryReconstructedDirectionsAtFailure"]
        and previous_negative != failure_negative
    )

    negative_reflected = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["reflectedPopulation"] < 0
    )
    negative_auxiliary = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["auxiliaryContribution"] < 0
    )
    negative_wall = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["wallCorrectionContribution"] < 0
    )
    fixed_halfway_moving = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["halfwayMovingWallPopulation"] >= 0
    )
    fixed_zero_wall = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["interpolatedZeroWallPopulation"] >= 0
    )
    fixed_halfway_zero = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["halfwayZeroWallPopulation"] >= 0
    )
    fixed_no_auxiliary = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["interpolatedNoAuxiliaryPopulation"] >= 0
    )
    remaining_halfway_zero = sorted(
        sample["direction"]
        for sample in failure_negative_samples
        if sample["halfwayZeroWallPopulation"] < 0
    )
    checks["reportedCounterfactualSets"] = (
        negative_reflected
        == decomposition["directionsWithNegativeReflectedPopulation"]
        and negative_auxiliary
        == decomposition["directionsWithNegativeAuxiliaryContribution"]
        and negative_wall
        == decomposition["directionsWithNegativeWallContribution"]
        and fixed_halfway_moving
        == decomposition["directionsMadeNonnegativeByHalfwayMovingWall"]
        and fixed_zero_wall
        == decomposition["directionsMadeNonnegativeByInterpolatedZeroWall"]
        and fixed_halfway_zero
        == decomposition["directionsMadeNonnegativeByHalfwayZeroWall"]
        and fixed_no_auxiliary
        == decomposition["directionsMadeNonnegativeByRemovingAuxiliary"]
        and remaining_halfway_zero
        == decomposition["directionsRemainingNegativeUnderHalfwayZeroWall"]
    )
    checks["movingWallCorrectionDiscriminator"] = (
        negative_reflected == []
        and negative_auxiliary == []
        and negative_wall == failure_negative
        and fixed_halfway_moving == []
        and fixed_zero_wall == failure_negative
        and fixed_halfway_zero == failure_negative
        and fixed_no_auxiliary == []
        and remaining_halfway_zero == []
        and all(
            sample["dominantNegativeContribution"] == "wall-correction"
            for sample in failure_negative_samples
        )
        and decomposition["dominantRepairTarget"] == "moving-wall-correction"
    )
    checks["claimBoundary"] = (
        decomposition["boundaryTermGatePassed"]
        and decomposition["experimentalAgreementGateApplied"] is False
    )

    passed = all(checks.values())
    return {
        "schemaVersion": 1,
        "decompositionSHA256": sha256(args.decomposition),
        "provenanceSHA256": sha256(args.provenance),
        "completionSHA256": sha256(args.completion),
        "checks": checks,
        "auditPassed": passed,
        "previousNegativeMovingBoundaryDirections": previous_negative,
        "failureNegativeMovingBoundaryDirections": failure_negative,
        "dominantRepairTarget": decomposition["dominantRepairTarget"],
        "failureDirections": [
            {
                "direction": sample["direction"],
                "branch": sample["branch"],
                "reflectedPopulation": sample["reflectedPopulation"],
                "auxiliaryContribution": sample["auxiliaryContribution"],
                "wallCorrectionContribution": sample[
                    "wallCorrectionContribution"
                ],
                "productionPopulation": sample[
                    "productionReconstructedPopulation"
                ],
                "interpolatedZeroWallPopulation": sample[
                    "interpolatedZeroWallPopulation"
                ],
                "halfwayMovingWallPopulation": sample[
                    "halfwayMovingWallPopulation"
                ],
            }
            for sample in failure_negative_samples
        ],
        "claimBoundary": (
            "This audit independently reconstructs the boundary branches, "
            "wall corrections, contribution sums, and four counterfactuals. "
            "It identifies the first repair surface but does not promote a "
            "counterfactual law or modify production physics."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--decomposition", type=Path, default=DEFAULT_DECOMPOSITION)
    parser.add_argument("--provenance", type=Path, default=DEFAULT_PROVENANCE)
    parser.add_argument("--completion", type=Path, default=DEFAULT_COMPLETION)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = audit(args)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    if not result["auditPassed"]:
        failed = [name for name, passed in result["checks"].items() if not passed]
        raise SystemExit("boundary-term audit failed: " + ", ".join(failed))
    print(
        "boundary-term audit passed: target="
        + result["dominantRepairTarget"]
        + " directions="
        + str(result["failureNegativeMovingBoundaryDirections"])
    )


if __name__ == "__main__":
    main()

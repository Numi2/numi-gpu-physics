#!/usr/bin/env python3
"""Independently reconstruct the D=16 direction-0 failure provenance."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PROVENANCE = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-d16-population-stage-provenance.json"
)
DEFAULT_COMPLETION = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-collision-grid-completion.json"
)
DEFAULT_OUTPUT = ROOT / "ValidationArtifacts" / (
    "deetjen-dove-d16-population-stage-provenance-audit.json"
)

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
W = [1.0 / 3.0] + [1.0 / 18.0] * 6 + [1.0 / 36.0] * 12
CS2 = 1.0 / 3.0
REST_POSITIVITY_SPEED_LIMIT = math.sqrt(2.0 / 3.0)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 2e-6) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def dot(first: tuple[float, ...], second: tuple[float, ...]) -> float:
    return sum(a * b for a, b in zip(first, second, strict=True))


def equilibrium(direction: int, rho: float, velocity: tuple[float, float, float]) -> float:
    cu = dot(C[direction], velocity)
    speed_squared = dot(velocity, velocity)
    return W[direction] * rho * (
        1.0 + 3.0 * cu + 4.5 * cu * cu - 1.5 * speed_squared
    )


def reconstruct_rr3(sample: dict, omega_plus: float) -> dict:
    populations = sample["reconstructedPopulations"]
    assert len(populations) == 19
    rho = max(sum(populations), 1e-8)
    momentum = tuple(
        sum(population * C[q][axis] for q, population in enumerate(populations))
        for axis in range(3)
    )
    velocity = tuple(component / rho for component in momentum)
    equilibria = [equilibrium(q, rho, velocity) for q in range(19)]

    diagonal = [0.0, 0.0, 0.0]
    off_diagonal = [0.0, 0.0, 0.0]
    for q, direction in enumerate(C):
        nonequilibrium = populations[q] - equilibria[q]
        diagonal[0] += nonequilibrium * (direction[0] * direction[0] - CS2)
        diagonal[1] += nonequilibrium * (direction[1] * direction[1] - CS2)
        diagonal[2] += nonequilibrium * (direction[2] * direction[2] - CS2)
        off_diagonal[0] += nonequilibrium * direction[0] * direction[1]
        off_diagonal[1] += nonequilibrium * direction[0] * direction[2]
        off_diagonal[2] += nonequilibrium * direction[1] * direction[2]

    ux, uy, uz = velocity
    a_xxy = 2.0 * ux * off_diagonal[0] + uy * diagonal[0]
    a_xxz = 2.0 * ux * off_diagonal[1] + uz * diagonal[0]
    a_xyy = ux * diagonal[1] + 2.0 * uy * off_diagonal[0]
    a_xzz = ux * diagonal[2] + 2.0 * uz * off_diagonal[1]
    a_yyz = 2.0 * uy * off_diagonal[2] + uz * diagonal[1]
    a_yzz = uy * diagonal[2] + 2.0 * uz * off_diagonal[2]

    regularized = []
    unbounded = []
    positivity_scale = 1.0
    for q, direction in enumerate(C):
        cx, cy, cz = direction
        contraction = (
            (cx * cx - CS2) * diagonal[0]
            + (cy * cy - CS2) * diagonal[1]
            + (cz * cz - CS2) * diagonal[2]
            + 2.0
            * (
                cx * cy * off_diagonal[0]
                + cx * cz * off_diagonal[1]
                + cy * cz * off_diagonal[2]
            )
        )
        third_order = (
            cy * (cx * cx - CS2) * a_xxy
            + cz * (cx * cx - CS2) * a_xxz
            + cx * (cy * cy - CS2) * a_xyy
            + cx * (cz * cz - CS2) * a_xzz
            + cz * (cy * cy - CS2) * a_yyz
            + cy * (cz * cz - CS2) * a_yzz
        )
        projected = W[q] * 4.5 * contraction + W[q] * 13.5 * third_order
        candidate = equilibria[q] + (1.0 - omega_plus) * projected
        regularized.append(projected)
        unbounded.append(candidate)
        floor = max(1e-12, 1e-6 * max(equilibria[q], 0.0))
        if candidate < floor:
            denominator = max(equilibria[q] - candidate, 1e-30)
            admissible = min(max((equilibria[q] - floor) / denominator, 0.0), 1.0)
            positivity_scale = min(positivity_scale, admissible)

    selected = sample["direction"]
    post_collision = equilibria[selected] + positivity_scale * (
        unbounded[selected] - equilibria[selected]
    )
    sponge = sample["spongeFactor"]
    far = equilibrium(selected, 1.0, (0.0, 0.0, 0.0))
    post_sponge = (1.0 - sponge) * post_collision + sponge * far
    return {
        "density": rho,
        "velocity": list(velocity),
        "speed": math.sqrt(dot(velocity, velocity)),
        "equilibriumDirectionPopulation": equilibria[selected],
        "regularizedNonequilibriumDirectionPopulation": regularized[selected],
        "unboundedPostCollisionDirectionPopulation": unbounded[selected],
        "positivityScale": positivity_scale,
        "postCollisionDirectionPopulation": post_collision,
        "postSpongeDirectionPopulation": post_sponge,
        "minimumReconstructedPopulation": min(populations),
        "minimumEquilibriumPopulation": min(equilibria),
        "minimumUnboundedPostCollisionPopulation": min(unbounded),
    }


def audit(args: argparse.Namespace) -> dict:
    provenance = load(args.provenance)
    completion = load(args.completion)
    completion_report = completion["d16Case"]["report"]
    checks: dict[str, bool] = {}

    checks["schema"] = provenance["schemaVersion"] == 1
    checks["lockedFailureTarget"] = (
        provenance["selectedCollisionOperator"]
        == completion["selectedCollisionOperator"]
        and provenance["referenceLengthCells"]
        == completion["completionReferenceLengthCells"] == 16
        and provenance["targetCellCoordinate"]
        == completion_report["firstNegativePopulationCellCoordinate"]
        and provenance["targetDirection"]
        == completion_report["firstNegativePopulationDirection"] == 0
    )
    failure_step = completion_report["firstNegativePopulationStep"]
    checks["captureWindow"] = provenance["capturedSteps"] == list(
        range(failure_step - 4, failure_step + 1)
    )
    checks["diagnosticDoesNotModifyProduction"] = (
        provenance["productionStateModifiedByDiagnostic"] is False
        and provenance["diagnosticKernelSequence"][1]
        == "stepFluidTRT (production, unmodified)"
    )

    samples = provenance["samples"]
    omega_plus = 1.0 / completion_report["plan"]["pilotTauPlus"]
    cpu = [reconstruct_rr3(sample, omega_plus) for sample in samples]
    cpu_checks = []
    for sample, reconstructed in zip(samples, cpu, strict=True):
        cpu_checks.append(
            close(sample["reconstructedDensity"], reconstructed["density"])
            and all(
                close(actual, expected)
                for actual, expected in zip(
                    sample["reconstructedVelocityLattice"],
                    reconstructed["velocity"],
                    strict=True,
                )
            )
            and close(sample["reconstructedSpeedLattice"], reconstructed["speed"])
            and close(
                sample["equilibriumDirectionPopulation"],
                reconstructed["equilibriumDirectionPopulation"],
            )
            and close(
                sample["regularizedNonequilibriumDirectionPopulation"],
                reconstructed["regularizedNonequilibriumDirectionPopulation"],
            )
            and close(
                sample["unboundedPostCollisionDirectionPopulation"],
                reconstructed["unboundedPostCollisionDirectionPopulation"],
            )
            and close(sample["positivityScale"], reconstructed["positivityScale"])
            and close(
                sample["postCollisionDirectionPopulation"],
                reconstructed["postCollisionDirectionPopulation"],
            )
            and close(
                sample["predictedPostSpongeDirectionPopulation"],
                reconstructed["postSpongeDirectionPopulation"],
            )
            and close(
                sample["minimumReconstructedPopulation"],
                reconstructed["minimumReconstructedPopulation"],
            )
        )
    checks["independentRR3Reconstruction"] = all(cpu_checks)

    allowed_error = provenance["maximumAllowedPredictionAbsoluteError"]
    errors = [
        abs(
            sample["predictedPostSpongeDirectionPopulation"]
            - sample["actualOutputDirectionPopulation"]
        )
        for sample in samples
    ]
    checks["productionPredictionClosure"] = (
        max(errors) <= allowed_error
        and close(max(errors), provenance["maximumPredictionAbsoluteError"], 1e-12)
        and all(
            close(error, sample["predictionAbsoluteError"], 1e-12)
            for error, sample in zip(errors, samples, strict=True)
        )
    )

    failure = samples[-1]
    negative_directions = [
        direction
        for direction, value in enumerate(failure["reconstructedPopulations"])
        if value < 0
    ]
    negative_boundary_directions = [
        direction
        for direction in negative_directions
        if direction in failure["movingBoundaryDirections"]
    ]
    checks["upstreamBoundaryNegativity"] = (
        negative_directions == provenance["negativeReconstructedDirectionsAtFailure"]
        and negative_boundary_directions
        == provenance["negativeMovingBoundaryReconstructedDirectionsAtFailure"]
        and negative_directions
        and negative_directions == negative_boundary_directions
        and provenance["upstreamMovingBoundaryReconstructionPresentAtFailure"]
    )
    checks["selectedDirectionFirstWrittenNegativeByCollision"] = (
        failure["preStepPopulation"] > 0
        and failure["reconstructedDirectionPopulation"] > 0
        and failure["postCollisionDirectionPopulation"] < 0
        and failure["actualOutputDirectionPopulation"] < 0
        and provenance[
            "selectedDirectionRemainedPositiveThroughReconstructionAtFailure"
        ]
        and provenance["firstNegativeCapturedStage"] == "post-collision"
        and provenance["firstNegativeCapturedStep"] == failure_step
    )
    checks["inadmissibleEquilibriumReference"] = (
        failure["reconstructedSpeedLattice"] > REST_POSITIVITY_SPEED_LIMIT
        and close(
            failure["restEquilibriumPositivitySpeedLimit"],
            REST_POSITIVITY_SPEED_LIMIT,
        )
        and failure["equilibriumDirectionPopulation"] < 0
        and failure["positivityScale"] == 0
        and close(
            failure["postCollisionDirectionPopulation"],
            failure["equilibriumDirectionPopulation"],
        )
        and provenance["equilibriumReferencePositiveAtFailure"] is False
    )
    checks["otherWritersExcludedForDirectionZero"] = (
        provenance["targetDirectionMovingBoundaryReconstructedAtFailure"] is False
        and provenance["topologyRefillAtFailure"] is False
        and provenance["farFieldUsedAtFailure"] is False
        and provenance["spongeUsedAtFailure"] is False
        and failure["topologyBranch"] == "persistent-fluid-reconstruction"
        and failure["spongeFactor"] == 0
        and failure["selectedSourcePartIdentifier"] == 0
    )
    checks["priorCapturedOutputsPositive"] = all(
        sample["actualOutputDirectionPopulation"] > 0 for sample in samples[:-1]
    )
    checks["failureMatchesCompletion"] = (
        close(
            failure["actualOutputDirectionPopulation"],
            completion_report["minimumSampledPopulation"],
        )
        and provenance["replayFirstNegativePopulationStep"] == failure_step
        and provenance["replayFirstNegativePopulationDirection"] == 0
        and provenance["replayFirstNegativePopulationCellCoordinate"]
        == provenance["targetCellCoordinate"]
    )
    checks["claimBoundary"] = (
        provenance["experimentalAgreementGateApplied"] is False
        and provenance["provenanceGatePassed"]
    )

    passed = all(checks.values())
    return {
        "schemaVersion": 1,
        "provenanceSHA256": sha256(args.provenance),
        "completionSHA256": sha256(args.completion),
        "checks": checks,
        "auditPassed": passed,
        "selectedDirectionFirstNegativeStage": provenance[
            "firstNegativeCapturedStage"
        ],
        "failureStep": failure_step,
        "negativeMovingBoundaryReconstructedDirections": (
            negative_boundary_directions
        ),
        "failureReconstruction": {
            "density": cpu[-1]["density"],
            "velocityLattice": cpu[-1]["velocity"],
            "speedLattice": cpu[-1]["speed"],
            "latticeMach": failure["reconstructedLatticeMach"],
            "restEquilibriumPositivitySpeedLimit": REST_POSITIVITY_SPEED_LIMIT,
            "equilibriumDirectionZero": cpu[-1][
                "equilibriumDirectionPopulation"
            ],
            "positivityScale": cpu[-1]["positivityScale"],
            "postCollisionDirectionZero": cpu[-1][
                "postCollisionDirectionPopulation"
            ],
            "actualDirectionZero": failure["actualOutputDirectionPopulation"],
        },
        "claimBoundary": (
            "This audit independently reconstructs moments, equilibrium, RR3 "
            "regularization, positivity scaling, and the selected population. "
            "It identifies the retained numerical failure but does not repair "
            "or validate the upstream moving-boundary reconstruction."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--provenance", type=Path, default=DEFAULT_PROVENANCE)
    parser.add_argument("--completion", type=Path, default=DEFAULT_COMPLETION)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    result = audit(args)
    args.output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    if not result["auditPassed"]:
        failed = [name for name, passed in result["checks"].items() if not passed]
        raise SystemExit("population provenance audit failed: " + ", ".join(failed))
    print(
        "population provenance audit passed: stage="
        + result["selectedDirectionFirstNegativeStage"]
        + " step="
        + str(result["failureStep"])
    )


if __name__ == "__main__":
    main()

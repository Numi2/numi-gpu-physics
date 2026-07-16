#!/usr/bin/env python3
"""Independently audit the fixed-input Deetjen collision pre-roll screen."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


DEFAULT_REPORT = Path(
    "ValidationArtifacts/deetjen-dove-collision-pre-roll-ab.json"
)
DEFAULT_TARGET = Path("ValidationInputs/deetjen-ob-f03-force-v1.json")
DEFAULT_SURFACE = Path(
    "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
)
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/deetjen-dove-collision-pre-roll-ab-audit.json"
)


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def close(actual: float, expected: float, tolerance: float = 2.0e-7) -> bool:
    return math.isclose(
        actual,
        expected,
        rel_tol=tolerance,
        abs_tol=tolerance,
    )


def absent(record: dict, name: str) -> bool:
    return record.get(name) is None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit the fixed-input Deetjen collision pre-roll A/B/C"
    )
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--surface", type=Path, default=DEFAULT_SURFACE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    report = json.loads(arguments.report.read_bytes())
    target = json.loads(arguments.target.read_bytes())
    surface = json.loads(arguments.surface.read_bytes())
    cases = report["cases"]
    operators = [case["collisionOperator"] for case in cases]
    expected_operators = [
        "production-trt",
        "positivity-preserving-regularized-bgk",
        "positivity-preserving-recursive-regularized-bgk",
    ]
    by_operator = {case["collisionOperator"]: case for case in cases}
    control = by_operator[expected_operators[0]]
    regularized = by_operator[expected_operators[1]]
    recursive = by_operator[expected_operators[2]]
    target_comparison = target["comparisonWindow"]
    requested_steps = report["requestedPreRollSteps"]
    grid = [
        control["report"]["gridX"],
        control["report"]["gridY"],
        control["report"]["gridZ"],
    ]
    cell_count = math.prod(grid)
    time_step = control["report"]["plan"]["fluidTimeStepSeconds"]

    def fixed_child_contract(case: dict) -> bool:
        child = case["report"]
        return (
            child["manifestSHA256"] == report["manifestSHA256"]
            and child["forceTargetSHA256"] == report["forceTargetSHA256"]
            and child["collisionOperator"] == case["collisionOperator"]
            and child["forceEstimator"]
            == "conservative-moving-domain-mode-6"
            and not child["periodicBoundaries"]
            and child["populationDiagnosticStride"] == 1
            and not child["experimentalAgreementGateApplied"]
            and not child["integrationGatePassed"]
            and [child["gridX"], child["gridY"], child["gridZ"]] == grid
            and child["plan"] == control["report"]["plan"]
        )

    def activation_arithmetic(case: dict) -> bool:
        child = case["report"]
        expected = child["collisionLimiterActivationCount"] / (
            cell_count * child["completedFluidSteps"]
        )
        return close(
            child["collisionLimiterActivationFractionOfCellSteps"],
            expected,
            1.0e-15,
        )

    def candidate_contract(case: dict, expected_activations: int) -> bool:
        child = case["report"]
        sample = child["samples"][0]
        return (
            case["requestedPreRollSteps"] == requested_steps
            and case["completedPreRollSteps"] == requested_steps
            and case["perStepPopulationDiagnostics"]
            and case["positivityAndFiniteLoadGatePassed"]
            and case["correctionIntrusionGatePassed"]
            and case["eligibleForExtendedPilot"]
            and child["completedFluidSteps"] == requested_steps
            and child["recordedPopulationDiagnosticSamples"] == requested_steps
            and child["recordedComparisonSamples"] == 1
            and child["allComponentsPresentAtComparisonSamples"]
            and child["allLoadsFinite"]
            and child["allSampledPopulationsFinite"]
            and child["sampledPopulationPositivityPassed"]
            and child["minimumSampledPopulation"] > 0.0
            and absent(child, "firstNegativePopulationStep")
            and absent(child, "firstNonFinitePopulationStep")
            and absent(child, "firstNonFiniteLoadStep")
            and child["collisionLimiterActivationCount"]
            == expected_activations
            and 0.0 <= child["maximumCollisionRestriction"] <= 1.0
            and child["collisionLimiterActivationFractionOfCellSteps"]
            <= report["maximumCorrectionActivationFraction"]
            and sample["targetSampleIndex"]
            == target_comparison["firstTargetSampleIndex"]
            and close(
                sample["measuredForceXNewtons"],
                target["samples"]["forceXNewtons"][
                    target_comparison["firstTargetSampleIndex"]
                ],
                1.0e-15,
            )
            and close(
                sample["measuredForceZNewtons"],
                target["samples"]["forceZNewtons"][
                    target_comparison["firstTargetSampleIndex"]
                ],
                1.0e-15,
            )
            and activation_arithmetic(case)
        )

    control_child = control["report"]
    first_negative_linear = control_child[
        "firstNegativePopulationLinearIndex"
    ]
    first_negative_cell = first_negative_linear % cell_count
    expected_coordinate = [
        first_negative_cell % grid[0],
        (first_negative_cell // grid[0]) % grid[1],
        first_negative_cell // (grid[0] * grid[1]),
    ]
    checks = {
        "schemaAndHashes": report["schemaVersion"] == 1
        and sha256(arguments.surface) == report["manifestSHA256"]
        and sha256(arguments.target) == report["forceTargetSHA256"],
        "datasetLocks": report["datasetIdentifier"]
        == surface["datasetIdentifier"]
        and report["forceTargetIdentifier"] == target["datasetIdentifier"],
        "fixedScreenContract": requested_steps == 800
        and report["populationDiagnosticStride"] == 1
        and report["maximumCorrectionActivationFraction"] == 0.05
        and grid == [75, 69, 66]
        and target_comparison["firstTargetSampleIndex"] == 50
        and target_comparison["firstTimeSeconds"] == 0.025
        and "geometry, kinematics, grid, time step" in report["fixedInputs"],
        "operatorOrder": operators == expected_operators,
        "childFixedInputs": all(fixed_child_contract(case) for case in cases),
        "controlFailureReproduced": report["controlFailureReproduced"]
        and control["completedPreRollSteps"] == 150
        and not control["positivityAndFiniteLoadGatePassed"]
        and not control["eligibleForExtendedPilot"]
        and control_child["completedFluidSteps"] == 150
        and control_child["recordedPopulationDiagnosticSamples"] == 150
        and control_child["recordedComparisonSamples"] == 0
        and control_child["allLoadsFinite"]
        and control_child["allSampledPopulationsFinite"]
        and not control_child["sampledPopulationPositivityPassed"]
        and control_child["minimumSampledPopulation"] < 0.0
        and control_child["firstNegativePopulationStep"] == 150
        and close(
            control_child["firstNegativePopulationTimeSeconds"],
            150 * time_step,
        )
        and control_child["firstNegativePopulationDirection"] == 7
        and control_child["firstNegativePopulationCellCoordinate"]
        == expected_coordinate
        and abs(
            control_child[
                "firstNegativePopulationDistanceFromSurfaceCells"
            ]
        )
        < 0.5
        and control_child["firstNegativePopulationPartIdentifier"] == 0
        and absent(control_child, "firstNonFinitePopulationStep")
        and absent(control_child, "firstNonFiniteLoadStep")
        and control_child["collisionLimiterActivationCount"] == 0
        and activation_arithmetic(control),
        "regularizedCandidate": candidate_contract(regularized, 55),
        "recursiveCandidate": candidate_contract(recursive, 28),
        "eligibleSet": report["eligibleCollisionOperators"]
        == expected_operators[1:]
        and report["screeningGatePassed"],
        "candidateInterventionOrdering": recursive["report"][
            "collisionLimiterActivationCount"
        ]
        < regularized["report"]["collisionLimiterActivationCount"]
        and recursive["report"]["maximumCollisionRestriction"]
        < regularized["report"]["maximumCollisionRestriction"],
        "nonAcceptanceBoundary": not report[
            "experimentalAgreementGateApplied"
        ]
        and "does not promote" in report["claimBoundary"]
        and "extended pilot" in report["claimBoundary"],
    }
    audit_passed = all(checks.values())
    result = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-collision-pre-roll-ab-audit-v1",
        "generatedBy": "Scripts/audit-dove-collision-pre-roll-ab.py",
        "reportSHA256": sha256(arguments.report),
        "forceTargetSHA256": sha256(arguments.target),
        "surfaceManifestSHA256": sha256(arguments.surface),
        "checks": checks,
        "artifactAuditPassed": audit_passed,
        "screeningGatePassed": bool(report["screeningGatePassed"]),
        "eligibleCollisionOperators": report["eligibleCollisionOperators"],
        "metrics": {
            "controlFirstNegativeStep": control_child[
                "firstNegativePopulationStep"
            ],
            "regularizedMinimumPopulation": regularized["report"][
                "minimumSampledPopulation"
            ],
            "regularizedActivationFraction": regularized["report"][
                "collisionLimiterActivationFractionOfCellSteps"
            ],
            "recursiveMinimumPopulation": recursive["report"][
                "minimumSampledPopulation"
            ],
            "recursiveActivationFraction": recursive["report"][
                "collisionLimiterActivationFractionOfCellSteps"
            ],
        },
        "claimBoundary": (
            "This audit verifies the fixed-input stability screen and its "
            "arithmetic. Candidate eligibility requires a separate momentum "
            "closure and extended pilot before any production or experimental "
            "claim."
        ),
    }
    if not audit_passed:
        failed = [name for name, passed in checks.items() if not passed]
        fail("collision pre-roll artifact audit failed: " + ", ".join(failed))
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = arguments.output.with_name(arguments.output.name + ".tmp")
    temporary.write_text(rendered)
    temporary.replace(arguments.output)
    print(rendered, end="")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Independently audit the bounded Deetjen coarse-fluid pilot archive."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


DEFAULT_PILOT = Path(
    "ValidationArtifacts/deetjen-dove-coarse-force-pilot.json"
)
DEFAULT_TARGET = Path("ValidationInputs/deetjen-ob-f03-force-v1.json")
DEFAULT_SURFACE = Path(
    "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
)
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/deetjen-dove-coarse-force-pilot-audit.json"
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


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit the committed Deetjen viscosity-floor pilot"
    )
    parser.add_argument("--pilot", type=Path, default=DEFAULT_PILOT)
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--surface", type=Path, default=DEFAULT_SURFACE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    pilot = json.loads(arguments.pilot.read_bytes())
    target = json.loads(arguments.target.read_bytes())
    surface = json.loads(arguments.surface.read_bytes())
    plan = pilot["plan"]
    comparison = target["comparisonWindow"]
    samples = pilot["samples"]

    dx = plan["cellSizeMeters"]
    dt = plan["fluidTimeStepSeconds"]
    tau = plan["pilotTauPlus"]
    density = plan["sourceAirDensityKilogramsPerCubicMeter"]
    source_mu = plan["sourceDynamicViscosityPascalSeconds"]
    maximum_speed = plan["maximumSurfaceSpeedMetersPerSecond"]
    lattice_speed = maximum_speed * dt / dx
    lattice_nu = (tau - 0.5) / 3.0
    source_tau = 0.5 + 3.0 * (source_mu / density) * dt / (dx * dx)
    pilot_mu = density * lattice_nu * dx * dx / dt
    expected_reynolds = lattice_speed * 8.0 / lattice_nu
    expected_total_steps = round(comparison["lastTimeSeconds"] / dt)
    expected_pre_roll_steps = round(comparison["firstTimeSeconds"] / dt)

    grid = [pilot["gridX"], pilot["gridY"], pilot["gridZ"]]
    cell_count = math.prod(grid)
    first_negative_step = pilot["firstNegativePopulationStep"]
    first_negative_linear = pilot["firstNegativePopulationLinearIndex"]
    first_negative_direction = pilot["firstNegativePopulationDirection"]
    first_negative_coordinate = pilot[
        "firstNegativePopulationCellCoordinate"
    ]
    first_negative_cell = first_negative_linear % cell_count
    expected_coordinate = [
        first_negative_cell % grid[0],
        (first_negative_cell // grid[0]) % grid[1],
        first_negative_cell // (grid[0] * grid[1]),
    ]

    aggregate_names = [
        "measuredMeanForceXNewtons",
        "measuredMeanForceZNewtons",
        "endpointMeanForceXNewtons",
        "endpointMeanForceZNewtons",
        "intervalMeanForceXNewtons",
        "intervalMeanForceZNewtons",
        "endpointNormalizedRMSError",
        "intervalMeanNormalizedRMSError",
        "measuredImpulseXNewtonSeconds",
        "measuredImpulseZNewtonSeconds",
        "endpointImpulseXNewtonSeconds",
        "endpointImpulseZNewtonSeconds",
        "intervalMeanImpulseXNewtonSeconds",
        "intervalMeanImpulseZNewtonSeconds",
        "measuredPeakTimeSeconds",
        "endpointPeakTimeSeconds",
        "intervalMeanPeakTimeSeconds",
    ]
    checks = {
        "schemas": pilot["schemaVersion"] == 1
        and target["schemaVersion"] == 1,
        "surfaceHash": sha256(arguments.surface)
        == pilot["manifestSHA256"]
        == target["source"]["surfaceManifestSHA256"],
        "forceTargetHash": sha256(arguments.target)
        == pilot["forceTargetSHA256"],
        "datasetLocks": pilot["datasetIdentifier"]
        == surface["datasetIdentifier"]
        and pilot["forceTargetIdentifier"] == target["datasetIdentifier"],
        "fixedPilotGrid": grid == [75, 69, 66]
        and close(dx, 0.01)
        and plan["paddingCells"] == 12
        and close(plan["halfThicknessCells"], 0.75),
        "timeContract": plan["fluidStepsPerForceSample"] == 16
        and close(dt, 1.0 / (2000.0 * 16.0), 1.0e-12)
        and plan["preRollFluidSteps"] == expected_pre_roll_steps == 800
        and plan["totalFluidSteps"] == expected_total_steps == 3776
        and plan["comparisonForceSamples"]
        == comparison["sampleCount"]
        == 187,
        "scalingReconstruction": close(
            plan["latticeReferenceSpeed"], lattice_speed
        )
        and close(
            plan["maximumWallMach"], lattice_speed / math.sqrt(1.0 / 3.0)
        )
        and close(plan["sourceConditionTauPlusAtPilotGrid"], source_tau)
        and close(plan["pilotDynamicViscosityPascalSeconds"], pilot_mu)
        and close(plan["pilotReynoldsNumber"], expected_reynolds)
        and close(plan["pilotToSourceViscosityRatio"], pilot_mu / source_mu),
        "viscosityClaimBoundary": not plan[
            "sourceViscosityRepresentableAtPilotGrid"
        ]
        and source_tau < plan["minimumAllowedTauPlus"]
        and plan["pilotToSourceViscosityRatio"] > 60.0
        and not plan["experimentalAgreementGateApplied"]
        and not pilot["experimentalAgreementGateApplied"],
        "negativePreRollOutcome": pilot["completedFluidSteps"] == 331
        and pilot["completedFluidSteps"] < plan["preRollFluidSteps"]
        and pilot["firstNonFiniteLoadStep"] == pilot["completedFluidSteps"]
        and not pilot["allLoadsFinite"]
        and not pilot["integrationGatePassed"],
        "populationDiagnosticCadence": pilot[
            "recordedPopulationDiagnosticSamples"
        ]
        == pilot["completedFluidSteps"] // plan["fluidStepsPerForceSample"]
        == 20
        and first_negative_step == 176
        and first_negative_step % plan["fluidStepsPerForceSample"] == 0
        and close(
            pilot["firstNegativePopulationTimeSeconds"],
            first_negative_step * dt,
        ),
        "negativePopulationLocalization": pilot[
            "minimumSampledPopulation"
        ]
        < 0.0
        and not pilot["sampledPopulationPositivityPassed"]
        and pilot["allSampledPopulationsFinite"]
        and pilot.get("firstNonFinitePopulationStep") is None
        and first_negative_direction == first_negative_linear // cell_count
        and 0 <= first_negative_direction < 19
        and first_negative_coordinate == expected_coordinate
        and pilot["firstNegativePopulationPartIdentifier"] == 0
        and abs(
            pilot["firstNegativePopulationDistanceFromSurfaceCells"]
        ) < 0.5,
        "comparisonNotReached": pilot["recordedComparisonSamples"] == 0
        and samples == []
        and not pilot["allComponentsPresentAtComparisonSamples"]
        and all(pilot.get(name) is None for name in aggregate_names),
        "forceCoveragePreserved": target["componentCoverage"]["measured"]
        == ["forceXNewtons", "forceZNewtons"]
        and "forceYNewtons" in target["componentCoverage"]["unavailable"]
        and "forceYNewtons" not in target["samples"],
        "verdictIsNonAcceptance": "failure" in pilot[
            "scientificVerdict"
        ].lower()
        and "cannot establish experimental agreement" in pilot[
            "claimBoundary"
        ],
    }
    gate_passed = all(checks.values())
    result = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-coarse-force-pilot-audit-v1",
        "generatedBy": "Scripts/audit-dove-coarse-force-pilot.py",
        "pilotSHA256": sha256(arguments.pilot),
        "forceTargetSHA256": sha256(arguments.target),
        "surfaceManifestSHA256": sha256(arguments.surface),
        "checks": checks,
        "artifactAuditPassed": gate_passed,
        "pilotIntegrationPassed": bool(pilot["integrationGatePassed"]),
        "outcome": "negative-pre-roll-population-stability-localization",
        "metrics": {
            "completedFluidSteps": pilot["completedFluidSteps"],
            "preRollFluidSteps": plan["preRollFluidSteps"],
            "firstSampledNegativePopulationStep": first_negative_step,
            "firstNonFiniteLoadStep": pilot["firstNonFiniteLoadStep"],
            "minimumSampledPopulation": pilot["minimumSampledPopulation"],
            "pilotToSourceViscosityRatio": plan[
                "pilotToSourceViscosityRatio"
            ],
        },
        "claimBoundary": (
            "This audit verifies that the committed archive accurately records "
            "a negative engineering-pilot outcome. It does not convert that "
            "outcome into experimental-force or quantitative-flight acceptance."
        ),
    }
    if not gate_passed:
        failed = [name for name, passed in checks.items() if not passed]
        fail("coarse-pilot artifact audit failed: " + ", ".join(failed))
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = arguments.output.with_name(arguments.output.name + ".tmp")
    temporary.write_text(rendered)
    temporary.replace(arguments.output)
    print(rendered, end="")


if __name__ == "__main__":
    main()

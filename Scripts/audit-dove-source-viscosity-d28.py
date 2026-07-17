#!/usr/bin/env python3
"""Independently audit the first production-margin D28 source-viscosity run."""

from __future__ import annotations

import hashlib
import importlib.util
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
INPUTS = ROOT / "ValidationInputs"
SURFACE = INPUTS / "deetjen-ob-f03-surface-v1" / "manifest.json"
FORCE = INPUTS / "deetjen-ob-f03-force-v1.json"
SCALING = ARTIFACTS / "deetjen-dove-source-scaling.json"
D16_PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d16-preregistration.json"
)
D16_REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d16-ab.json"
D16_AUDIT = ARTIFACTS / "deetjen-dove-source-viscosity-d16-audit.json"
PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-preregistration.json"
)
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d28-pre-roll.json"
OUTPUT = ARTIFACTS / "deetjen-dove-source-viscosity-d28-audit.json"
HELPERS = Path(__file__).with_name("audit-dove-source-viscosity-d16.py")

EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_GRID = (259, 238, 229)
EXPECTED_STEPS = 2_800
MOMENTUM_LIMIT = 0.005
CORRECTION_LIMIT = 0.05


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_helpers():
    specification = importlib.util.spec_from_file_location(
        "source_viscosity_d16_audit_helpers", HELPERS
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("unable to load D16 audit arithmetic")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    module.EXPECTED_GRID = EXPECTED_GRID
    module.EXPECTED_STEPS = EXPECTED_STEPS
    module.MOMENTUM_LIMIT = MOMENTUM_LIMIT
    module.CORRECTION_LIMIT = CORRECTION_LIMIT
    return module


def main() -> None:
    helpers = load_helpers()
    surface = json.loads(SURFACE.read_text())
    force = json.loads(FORCE.read_text())
    scaling = json.loads(SCALING.read_text())
    d16_preregistration = json.loads(D16_PREREGISTRATION.read_text())
    d16_report = json.loads(D16_REPORT.read_text())
    d16_audit = json.loads(D16_AUDIT.read_text())
    preregistration = json.loads(PREREGISTRATION.read_text())
    report = json.loads(REPORT.read_text())

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
    dx = float(preregistration["cellSizeMeters"])
    dt = float(preregistration["fluidTimeStepSeconds"])
    source_tau = 0.5 + 3.0 * nu * dt / (dx * dx)

    eligible_d16 = [
        case for case in d16_report["cases"] if case["eligibleForD28Planning"]
    ]
    selected_d16 = min(
        eligible_d16,
        key=lambda case: (
            max(
                case["report"]["relativeRMSRawControlVolumeClosureResidual"],
                case["report"]["relativeRMSGlobalFluidClosureResidual"],
            ),
            case["report"]["collisionLimiterActivationFractionOfCellSteps"],
            -case["report"]["minimumPopulation"],
            case["collisionOperator"],
        ),
    )
    selected_worst = max(
        selected_d16["report"]["relativeRMSRawControlVolumeClosureResidual"],
        selected_d16["report"]["relativeRMSGlobalFluidClosureResidual"],
    )
    expected_cell_count = math.prod(EXPECTED_GRID)
    expected_working_set = expected_cell_count * 256
    production_floor = float(preregistration["productionMinimumTauPlus"])
    wrapper = {
        "collisionOperator": report["selectedCollisionOperator"],
        "actualTauPlus": report["actualTauPlus"],
        "executionFloorPassed": report["productionTauMarginPassed"],
        "productionMarginPassed": report["productionTauMarginPassed"],
        "completionAndPositivityPassed": report[
            "completionAndPositivityPassed"
        ],
        "momentumLedgerPassed": report["momentumLedgerPassed"],
        "correctionIntrusionPassed": report["correctionIntrusionPassed"],
        "eligibleForD28Planning": report["preRollGatePassed"],
        "report": report["caseReport"],
    }
    case_result = helpers.audit_case(
        wrapper, dt, production_floor, production_floor
    )

    checks = {
        "primaryInputHashes": preregistration["manifestSHA256"]
        == sha256(SURFACE)
        and preregistration["forceTargetSHA256"] == sha256(FORCE)
        and preregistration["datasetIdentifier"] == surface["datasetIdentifier"]
        and preregistration["forceTargetIdentifier"]
        == force["datasetIdentifier"],
        "d16EvidenceHashes": preregistration["sourceD16PreregistrationSHA256"]
        == sha256(D16_PREREGISTRATION)
        and preregistration["sourceD16ReportSHA256"] == sha256(D16_REPORT)
        and preregistration["sourceD16AuditSHA256"] == sha256(D16_AUDIT)
        and d16_audit["allChecksPassed"]
        and d16_audit["d28PlanningGatePassed"],
        "preregistrationHash": report["sourcePreregistrationSHA256"]
        == sha256(PREREGISTRATION),
        "deterministicOperatorSelection": selected_d16["collisionOperator"]
        == EXPECTED_OPERATOR
        and preregistration["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and report["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and helpers.close(
            selected_worst,
            preregistration["selectionWorstRelativeRMSMomentumResidual"],
        )
        and helpers.close(
            selected_d16["report"][
                "collisionLimiterActivationFractionOfCellSteps"
            ],
            preregistration["selectionCorrectionActivationFraction"],
        )
        and helpers.close(
            selected_d16["report"]["minimumPopulation"],
            preregistration["selectionMinimumPopulation"],
        ),
        "sourceReynoldsReconstruction": helpers.close(
            reynolds, preregistration["sourcePropertyReynoldsNumber"]
        ),
        "sourceTauReconstruction": helpers.close(
            source_tau, preregistration["expectedTauPlus"], 2.0e-7
        )
        and helpers.close(
            report["actualTauPlus"], preregistration["expectedTauPlus"], 2.0e-7
        ),
        "productionTauMargin": source_tau >= production_floor
        and report["actualTauPlus"] >= production_floor
        and report["productionTauMarginPassed"],
        "fixedD28Contract": preregistration["referenceLengthCells"] == 28
        and preregistration["requestedPreRollSteps"] == EXPECTED_STEPS
        and helpers.close(
            preregistration["maximumRelativeRMSClosureResidual"],
            MOMENTUM_LIMIT,
        )
        and helpers.close(
            preregistration["maximumCorrectionActivationFraction"],
            CORRECTION_LIMIT,
        )
        and preregistration["movingWallNormalization"]
        == "pre-step-local-density",
        "runtimeGrid": tuple(report[key] for key in ("gridX", "gridY", "gridZ"))
        == EXPECTED_GRID
        and tuple(
            preregistration[key]
            for key in ("expectedGridX", "expectedGridY", "expectedGridZ")
        )
        == EXPECTED_GRID
        and preregistration["expectedCellCount"] == expected_cell_count,
        "workingSetPreflight": preregistration[
            "conservativeWorkingSetEstimateBytes"
        ]
        == expected_working_set
        and expected_working_set <= report["recommendedMaximumWorkingSetBytes"]
        and report["workingSetPreflightPassed"],
        "independentPerStepCompletionAndPositivity": case_result[
            "completedSteps"
        ]
        == EXPECTED_STEPS
        and case_result["minimumPopulation"] > 0,
        "independentNearWingMomentumClosure": case_result[
            "relativeRMSRawControlVolumeClosureResidual"
        ]
        <= MOMENTUM_LIMIT,
        "independentGlobalMomentumClosure": case_result[
            "relativeRMSGlobalFluidClosureResidual"
        ]
        <= MOMENTUM_LIMIT,
        "independentCorrectionGate": case_result[
            "collisionLimiterActivationFractionOfCellSteps"
        ]
        <= CORRECTION_LIMIT,
        "parentVerdict": case_result["eligibleForD28Planning"]
        and report["preRollGatePassed"]
        and report["d28FullWindowRunAuthorized"],
        "safetyBoundary": not report["d20RunAuthorized"]
        and report["fluidEvolutionExecuted"]
        and not report["productionModificationAuthorized"]
        and not report["experimentalAgreementGateApplied"],
        "classification": report["classification"]
        == "rr3-source-viscosity-production-margin-pre-roll-passed-at-d28",
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("D28 source-viscosity audit failed: " + ", ".join(failed))

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-source-viscosity-d28-audit-v1",
        "generatedBy": "Scripts/audit-dove-source-viscosity-d28.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "reportSHA256": sha256(REPORT),
        "sourceD16PreregistrationSHA256": sha256(D16_PREREGISTRATION),
        "sourceD16ReportSHA256": sha256(D16_REPORT),
        "sourceD16AuditSHA256": sha256(D16_AUDIT),
        "independentReconstruction": {
            "sourcePropertyReynoldsNumber": reynolds,
            "sourceTauPlus": source_tau,
            "expectedCellCount": expected_cell_count,
            "conservativeWorkingSetEstimateBytes": expected_working_set,
            "selectedD16Operator": selected_d16["collisionOperator"],
            "case": case_result,
        },
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": True,
        "d28FullWindowRunGatePassed": True,
        "claimBoundary": (
            "This audit independently reconstructs the D28 source-viscosity "
            "pre-roll and authorizes only a preregistered RR3 full-window run. "
            "It does not establish force agreement, grid convergence, a "
            "published Reynolds number, or a production change."
        ),
    }
    OUTPUT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Independently audit the preregistered D32 source-viscosity pre-roll."""

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
D28_PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-preregistration.json"
)
D28_FULL_PREREGISTRATION = (
    ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-full-window-preregistration.json"
)
D28_FULL_REPORT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window.json"
)
D28_FULL_AUDIT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d28-full-window-audit.json"
)
PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d32-preregistration.json"
)
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d32-pre-roll.json"
OUTPUT = ARTIFACTS / "deetjen-dove-source-viscosity-d32-audit.json"
HELPERS = Path(__file__).with_name("audit-dove-source-viscosity-d16.py")

EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_GRID = (296, 271, 261)
EXPECTED_STEPS = 3_200
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
    d28_preregistration = json.loads(D28_PREREGISTRATION.read_text())
    d28_full_preregistration = json.loads(D28_FULL_PREREGISTRATION.read_text())
    d28_full_report = json.loads(D28_FULL_REPORT.read_text())
    d28_full_audit = json.loads(D28_FULL_AUDIT.read_text())
    preregistration = json.loads(PREREGISTRATION.read_text())
    report = json.loads(REPORT.read_text())

    rho = float(
        scaling["sourceFluidProperties"]["airDensityKilogramsPerCubicMeter"]
    )
    mu = float(
        scaling["sourceFluidProperties"]["dynamicViscosityPascalSeconds"]
    )
    nu = mu / rho
    speed = float(
        scaling["reynoldsDefinitions"][
            "convertedMaximumSurfaceSpeedMetersPerSecond"
        ]
    )
    length = float(
        scaling["reynoldsDefinitions"]["registeredReferenceLengthMeters"]
    )
    reynolds = speed * length / nu
    dx = float(preregistration["cellSizeMeters"])
    dt = float(preregistration["fluidTimeStepSeconds"])
    source_tau = 0.5 + 3.0 * nu * dt / (dx * dx)
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
        "d28ParentHashChain": d28_full_preregistration[
            "sourceD28PreregistrationSHA256"
        ]
        == sha256(D28_PREREGISTRATION)
        and preregistration["sourceD28FullWindowPreregistrationSHA256"]
        == sha256(D28_FULL_PREREGISTRATION)
        and preregistration["sourceD28FullWindowReportSHA256"]
        == sha256(D28_FULL_REPORT)
        and preregistration["sourceD28FullWindowAuditSHA256"]
        == sha256(D28_FULL_AUDIT),
        "d28ParentVerdict": d28_preregistration["passed"]
        and d28_full_preregistration["passed"]
        and d28_full_report["fullWindowGatePassed"]
        and d28_full_audit["allChecksPassed"]
        and d28_full_audit["d28ForceHistoryAcceptedAsRefinementInput"],
        "preregistrationHash": report["sourcePreregistrationSHA256"]
        == sha256(PREREGISTRATION),
        "fixedOperator": preregistration["selectedCollisionOperator"]
        == EXPECTED_OPERATOR
        and report["selectedCollisionOperator"] == EXPECTED_OPERATOR,
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
        "fixedD32Contract": preregistration["referenceLengthCells"] == 32
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
        and report["d32FullWindowRunAuthorized"],
        "safetyBoundary": report["fluidEvolutionExecuted"]
        and not report["productionModificationAuthorized"]
        and not report["experimentalAgreementGateApplied"]
        and not report["gridConvergenceGateApplied"],
        "classification": report["classification"]
        == "rr3-source-viscosity-pre-roll-passed-at-d32",
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("D32 source-viscosity audit failed: " + ", ".join(failed))

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-source-viscosity-d32-audit-v1",
        "generatedBy": "Scripts/audit-dove-source-viscosity-d32.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "reportSHA256": sha256(REPORT),
        "sourceD28FullWindowPreregistrationSHA256": sha256(
            D28_FULL_PREREGISTRATION
        ),
        "sourceD28FullWindowReportSHA256": sha256(D28_FULL_REPORT),
        "sourceD28FullWindowAuditSHA256": sha256(D28_FULL_AUDIT),
        "independentReconstruction": {
            "sourcePropertyReynoldsNumber": reynolds,
            "sourceTauPlus": source_tau,
            "expectedCellCount": expected_cell_count,
            "conservativeWorkingSetEstimateBytes": expected_working_set,
            "case": case_result,
        },
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": True,
        "d32FullWindowRunGatePassed": True,
        "claimBoundary": (
            "This audit independently reconstructs the D32 source-viscosity "
            "pre-roll and authorizes only a separately preregistered RR3 D32 "
            "full-window run. It does not establish D28/D32 convergence, "
            "experimental agreement, production promotion, or free flight."
        ),
    }
    OUTPUT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

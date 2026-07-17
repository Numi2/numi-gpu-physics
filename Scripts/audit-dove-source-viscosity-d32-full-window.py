#!/usr/bin/env python3
"""Independently audit the preregistered D32 source-viscosity force window."""

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
D32_PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d32-preregistration.json"
)
D32_PRE_ROLL = ARTIFACTS / "deetjen-dove-source-viscosity-d32-pre-roll.json"
D32_AUDIT = ARTIFACTS / "deetjen-dove-source-viscosity-d32-audit.json"
PREREGISTRATION = (
    ARTIFACTS
    / "deetjen-dove-source-viscosity-d32-full-window-preregistration.json"
)
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-d32-full-window.json"
OUTPUT = (
    ARTIFACTS / "deetjen-dove-source-viscosity-d32-full-window-audit.json"
)
FULL_HELPERS = Path(__file__).with_name(
    "audit-dove-source-viscosity-d28-full-window.py"
)

EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_GRID = (296, 271, 261)
EXPECTED_STEPS = 15_104
EXPECTED_STEPS_PER_FORCE_SAMPLE = 64
EXPECTED_FORCE_SAMPLES = 187
MOMENTUM_LIMIT = 0.005
CORRECTION_LIMIT = 0.05


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_helpers():
    specification = importlib.util.spec_from_file_location(
        "source_viscosity_d28_full_audit_helpers", FULL_HELPERS
    )
    if specification is None or specification.loader is None:
        raise RuntimeError("unable to load full-window audit arithmetic")
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    module.EXPECTED_GRID = EXPECTED_GRID
    module.EXPECTED_STEPS = EXPECTED_STEPS
    module.EXPECTED_STEPS_PER_FORCE_SAMPLE = EXPECTED_STEPS_PER_FORCE_SAMPLE
    module.EXPECTED_FORCE_SAMPLES = EXPECTED_FORCE_SAMPLES
    module.MOMENTUM_LIMIT = MOMENTUM_LIMIT
    module.CORRECTION_LIMIT = CORRECTION_LIMIT
    case_helpers = module.load_helpers()
    return module, case_helpers


def main() -> None:
    full, case_helpers = load_helpers()
    surface = json.loads(SURFACE.read_text())
    force = json.loads(FORCE.read_text())
    d32_preregistration = json.loads(D32_PREREGISTRATION.read_text())
    d32_pre_roll = json.loads(D32_PRE_ROLL.read_text())
    d32_audit = json.loads(D32_AUDIT.read_text())
    preregistration = json.loads(PREREGISTRATION.read_text())
    report = json.loads(REPORT.read_text())

    target_window = force["comparisonWindow"]
    first_target = int(target_window["firstTargetSampleIndex"])
    last_target = int(target_window["lastTargetSampleIndex"])
    rate = 2_000.0
    dt = 1.0 / (rate * EXPECTED_STEPS_PER_FORCE_SAMPLE)
    source_tau = 0.5 + 3.0 * (1.849e-5 / 1.18) * dt / ((0.08 / 32.0) ** 2)
    expected_working_set = math.prod(EXPECTED_GRID) * 256

    wrapper = {
        "collisionOperator": report["selectedCollisionOperator"],
        "actualTauPlus": report["actualTauPlus"],
        "executionFloorPassed": report["productionTauMarginPassed"],
        "productionMarginPassed": report["productionTauMarginPassed"],
        "completionAndPositivityPassed": report["allStepsCompleted"]
        and report["populationPositivityPassed"],
        "momentumLedgerPassed": report["forceAndMomentumAccountingPassed"],
        "correctionIntrusionPassed": report[
            "collisionCorrectionIntrusionPassed"
        ],
        "eligibleForD28Planning": report["fullWindowGatePassed"],
        "report": report["ledgerResult"],
    }
    case_result = case_helpers.audit_case(
        wrapper,
        dt,
        float(preregistration["productionMinimumTauPlus"]),
        float(preregistration["productionMinimumTauPlus"]),
    )

    ledger_samples = report["ledgerResult"]["samples"]
    reconstructed = []
    for target_index in range(first_target, last_target + 1):
        end = target_index * EXPECTED_STEPS_PER_FORCE_SAMPLE
        start = end - EXPECTED_STEPS_PER_FORCE_SAMPLE
        interval = ledger_samples[start:end]
        interval_mean = [
            full.mean(
                [sample["aerodynamicForceNewtons"][axis] for sample in interval]
            )
            for axis in range(3)
        ]
        measured_x = force["samples"]["forceXNewtons"][target_index]
        measured_z = force["samples"]["forceZNewtons"][target_index]
        reconstructed.append(
            {
                "targetSampleIndex": target_index,
                "sourceTimeSeconds": force["samples"]["timesSeconds"][target_index],
                "measuredForceXNewtons": measured_x,
                "measuredForceZNewtons": measured_z,
                "intervalMeanComputedForceNewtons": interval_mean,
                "residualXNewtons": interval_mean[0] - measured_x,
                "residualZNewtons": interval_mean[2] - measured_z,
            }
        )

    archived_samples = report["registeredForceSamples"]
    force_samples_match = len(archived_samples) == len(reconstructed) and all(
        archived["targetSampleIndex"] == rebuilt["targetSampleIndex"]
        and full.close(
            archived["sourceTimeSeconds"], rebuilt["sourceTimeSeconds"]
        )
        and full.close(
            archived["measuredForceXNewtons"], rebuilt["measuredForceXNewtons"]
        )
        and full.close(
            archived["measuredForceZNewtons"], rebuilt["measuredForceZNewtons"]
        )
        and full.vector_close(
            archived["intervalMeanComputedForceNewtons"],
            rebuilt["intervalMeanComputedForceNewtons"],
        )
        and full.close(archived["residualXNewtons"], rebuilt["residualXNewtons"])
        and full.close(archived["residualZNewtons"], rebuilt["residualZNewtons"])
        for archived, rebuilt in zip(archived_samples, reconstructed)
    )
    measured = [
        [sample["measuredForceXNewtons"], sample["measuredForceZNewtons"]]
        for sample in reconstructed
    ]
    computed = [
        [
            sample["intervalMeanComputedForceNewtons"][0],
            sample["intervalMeanComputedForceNewtons"][2],
        ]
        for sample in reconstructed
    ]
    measured_impulse = full.impulse(measured, rate)
    computed_impulse = full.impulse(computed, rate)
    aggregate = {
        "measuredMeanForceXNewtons": full.mean([value[0] for value in measured]),
        "measuredMeanForceZNewtons": full.mean([value[1] for value in measured]),
        "computedMeanForceXNewtons": full.mean([value[0] for value in computed]),
        "computedMeanForceZNewtons": full.mean([value[1] for value in computed]),
        "normalizedRMSError": full.normalized_rms(measured, computed),
        "measuredImpulseXNewtonSeconds": measured_impulse[0],
        "measuredImpulseZNewtonSeconds": measured_impulse[1],
        "computedImpulseXNewtonSeconds": computed_impulse[0],
        "computedImpulseZNewtonSeconds": computed_impulse[1],
        "measuredPeakTimeSeconds": full.peak_time(reconstructed, False),
        "computedPeakTimeSeconds": full.peak_time(reconstructed, True),
    }
    aggregate_match = all(
        full.close(report[key], value) for key, value in aggregate.items()
    )

    checks = {
        "primaryInputHashes": preregistration["manifestSHA256"] == sha256(SURFACE)
        and preregistration["forceTargetSHA256"] == sha256(FORCE)
        and preregistration["datasetIdentifier"] == surface["datasetIdentifier"]
        and preregistration["forceTargetIdentifier"] == force["datasetIdentifier"],
        "sourceEvidenceHashes": preregistration[
            "sourceD32PreregistrationSHA256"
        ]
        == sha256(D32_PREREGISTRATION)
        and preregistration["sourceD32PreRollSHA256"] == sha256(D32_PRE_ROLL)
        and preregistration["sourceD32AuditSHA256"] == sha256(D32_AUDIT)
        and d32_pre_roll["d32FullWindowRunAuthorized"]
        and d32_audit["allChecksPassed"]
        and d32_audit["d32FullWindowRunGatePassed"],
        "preregistrationHash": report["sourcePreregistrationSHA256"]
        == sha256(PREREGISTRATION),
        "fixedOperator": preregistration["selectedCollisionOperator"]
        == EXPECTED_OPERATOR
        and report["selectedCollisionOperator"] == EXPECTED_OPERATOR,
        "fixedGrid": tuple(
            preregistration[key]
            for key in ("expectedGridX", "expectedGridY", "expectedGridZ")
        )
        == EXPECTED_GRID
        and tuple(report[key] for key in ("gridX", "gridY", "gridZ"))
        == EXPECTED_GRID,
        "fixedTiming": preregistration["requestedFullWindowSteps"]
        == EXPECTED_STEPS
        and preregistration["fluidStepsPerForceSample"]
        == EXPECTED_STEPS_PER_FORCE_SAMPLE
        and preregistration["requestedComparisonSamples"]
        == EXPECTED_FORCE_SAMPLES
        and report["requestedSteps"] == EXPECTED_STEPS,
        "sourceTau": full.close(
            source_tau, preregistration["expectedTauPlus"], 2.0e-7
        )
        and full.close(report["actualTauPlus"], source_tau, 2.0e-7),
        "workingSet": preregistration["conservativeWorkingSetEstimateBytes"]
        == expected_working_set
        and report["workingSetPreflightPassed"],
        "independentCompletionAndPositivity": case_result["completedSteps"]
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
        "forceSamples": force_samples_match
        and len(reconstructed) == EXPECTED_FORCE_SAMPLES,
        "forceAggregates": aggregate_match,
        "parentVerdict": report["fullWindowGatePassed"]
        and report["registeredWindowComplete"]
        and report["registeredComparisonSampleCount"] == EXPECTED_FORCE_SAMPLES,
        "safetyBoundary": not report["experimentalAgreementGateApplied"]
        and not report["gridConvergenceGateApplied"]
        and not report["productionModificationAuthorized"],
        "classification": report["classification"]
        == "rr3-source-viscosity-d32-full-window-numerically-passed",
    }
    failed = [name for name, passed in checks.items() if not passed]
    if failed:
        raise SystemExit("D32 full-window audit failed: " + ", ".join(failed))

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-source-viscosity-d32-full-window-audit-v1",
        "generatedBy": "Scripts/audit-dove-source-viscosity-d32-full-window.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "reportSHA256": sha256(REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "independentReconstruction": {
            "sourceTauPlus": source_tau,
            "expectedWorkingSetBytes": expected_working_set,
            "case": case_result,
            "registeredForceSampleCount": len(reconstructed),
            "forceAggregates": aggregate,
        },
        "allChecksPassed": True,
        "d32ForceHistoryAcceptedAsRefinementInput": True,
        "claimBoundary": (
            "This audit accepts the D32 force history only as the fine member "
            "of a separately evaluated same-source-viscosity D28/D32 pair. "
            "It does not itself establish grid convergence, experimental "
            "agreement, production promotion, or free flight."
        ),
    }
    OUTPUT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

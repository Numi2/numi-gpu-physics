#!/usr/bin/env python3
"""Freeze the D28/D32 25--30 ms moving-boundary component replay."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-targeted-boundary-preregistration.json"
)

PATHS = {
    "d28_preregistration": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-preregistration.json",
    "d28_report": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-full-window.json",
    "d28_audit": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-full-window-audit.json",
    "d32_report": ARTIFACTS
    / "deetjen-dove-source-viscosity-d32-full-window.json",
    "d32_preregistration": ARTIFACTS
    / "deetjen-dove-source-viscosity-d32-preregistration.json",
    "d32_audit": ARTIFACTS
    / "deetjen-dove-source-viscosity-d32-full-window-audit.json",
    "refinement_preregistration": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-refinement-preregistration.json",
    "refinement_report": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-refinement.json",
    "refinement_audit": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-refinement-audit.json",
    "phase_report": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-phase-localization.json",
    "phase_audit": ARTIFACTS
    / "deetjen-dove-source-viscosity-d28-d32-phase-localization-audit.json",
}

EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_NORMALIZATION = "pre-step-local-density"
FIRST_TARGET_INDEX = 50
LAST_TARGET_INDEX = 60
START_TIME_SECONDS = 0.025
END_TIME_SECONDS = 0.030


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    d28 = load(PATHS["d28_report"])
    d32 = load(PATHS["d32_report"])
    d28_preregistration = load(PATHS["d28_preregistration"])
    d32_preregistration = load(PATHS["d32_preregistration"])
    d28_audit = load(PATHS["d28_audit"])
    d32_audit = load(PATHS["d32_audit"])
    refinement = load(PATHS["refinement_report"])
    refinement_audit = load(PATHS["refinement_audit"])
    phase = load(PATHS["phase_report"])
    phase_audit = load(PATHS["phase_audit"])

    recommendation = phase["targetedReplayRecommendation"]
    if not (
        d28["fullWindowGatePassed"]
        and d32["fullWindowGatePassed"]
        and d28_audit["allChecksPassed"]
        and d28_audit["d28ForceHistoryAcceptedAsRefinementInput"]
        and d32_audit["allChecksPassed"]
        and d32_audit["d32ForceHistoryAcceptedAsRefinementInput"]
        and refinement_audit["allChecksPassed"]
        and not refinement["finePairStabilizationPassed"]
        and not refinement_audit["d36RunAuthorized"]
        and phase_audit["allChecksPassed"]
        and phase_audit["targetedD28D32ReplaySupported"]
        and not recommendation["d36RunAuthorized"]
        and recommendation["startTimeSeconds"] == START_TIME_SECONDS
        and recommendation["endTimeSeconds"] == END_TIME_SECONDS
        and d28["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and d32["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and d28["movingWallNormalization"] == EXPECTED_NORMALIZATION
        and d32["movingWallNormalization"] == EXPECTED_NORMALIZATION
        and d28_preregistration["sourcePropertyReynoldsNumber"]
        == d32_preregistration["sourcePropertyReynoldsNumber"]
    ):
        raise SystemExit("audited failed D28/D32 pair and targeted phase are required")

    first28 = d28["registeredForceSamples"][0]
    target60 = next(
        sample
        for sample in d28["registeredForceSamples"]
        if sample["targetSampleIndex"] == LAST_TARGET_INDEX
    )
    if not (
        first28["targetSampleIndex"] == FIRST_TARGET_INDEX
        and first28["sourceTimeSeconds"] == START_TIME_SECONDS
        and target60["sourceTimeSeconds"] == END_TIME_SECONDS
        and d28["plan"]["fluidStepsPerForceSample"] == 56
        and d32["plan"]["fluidStepsPerForceSample"] == 64
    ):
        raise SystemExit("targeted phase no longer maps to the locked fluid steps")

    artifact = {
        "schemaVersion": 2,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-source-viscosity-targeted-boundary-v2"
        ),
        "datasetIdentifier": d28["datasetIdentifier"],
        "manifestSHA256": d28["manifestSHA256"],
        "forceTargetIdentifier": d28["forceTargetIdentifier"],
        "forceTargetSHA256": d28["forceTargetSHA256"],
        "sourceD28PreregistrationSHA256": sha256(
            PATHS["d28_preregistration"]
        ),
        "sourceD32PreregistrationSHA256": sha256(
            PATHS["d32_preregistration"]
        ),
        "sourceD28FullWindowReportSHA256": sha256(PATHS["d28_report"]),
        "sourceD28FullWindowAuditSHA256": sha256(PATHS["d28_audit"]),
        "sourceD32FullWindowReportSHA256": sha256(PATHS["d32_report"]),
        "sourceD32FullWindowAuditSHA256": sha256(PATHS["d32_audit"]),
        "sourceRefinementPreregistrationSHA256": sha256(
            PATHS["refinement_preregistration"]
        ),
        "sourceRefinementReportSHA256": sha256(PATHS["refinement_report"]),
        "sourceRefinementAuditSHA256": sha256(PATHS["refinement_audit"]),
        "sourcePhaseLocalizationReportSHA256": sha256(PATHS["phase_report"]),
        "sourcePhaseLocalizationAuditSHA256": sha256(PATHS["phase_audit"]),
        "selectedCollisionOperator": EXPECTED_OPERATOR,
        "movingWallNormalization": EXPECTED_NORMALIZATION,
        "sourcePropertyReynoldsNumber": d28_preregistration[
            "sourcePropertyReynoldsNumber"
        ],
        "expectedD28TauPlus": d28["actualTauPlus"],
        "expectedD32TauPlus": d32["actualTauPlus"],
        "coarseReferenceLengthCells": 28,
        "fineReferenceLengthCells": 32,
        "firstTargetSampleIndex": FIRST_TARGET_INDEX,
        "lastTargetSampleIndex": LAST_TARGET_INDEX,
        "targetStartTimeSeconds": START_TIME_SECONDS,
        "targetEndTimeSeconds": END_TIME_SECONDS,
        "d28FluidStepsPerForceSample": 56,
        "d32FluidStepsPerForceSample": 64,
        "d28RequestedSteps": LAST_TARGET_INDEX * 56,
        "d32RequestedSteps": LAST_TARGET_INDEX * 64,
        "maximumRelativeRMSClosureResidual": 0.005,
        "maximumCorrectionActivationFraction": 0.05,
        "maximumComponentReconstructionRelativeRMS": 0.0001,
        "maximumArchivedForceReproductionRelativeRMS": 0.001,
        "minimumDominantContributionFraction": 0.50,
        "selectionRule": (
            "Run RR3 at D28 and D32 only through 30 ms. On every fluid step "
            "contributing to force samples 50...60, replay the unmodified "
            "production collision kernel from the same pre-step populations and "
            "moving geometry with the existing force selectors for reflected "
            "population, moving-wall correction, interpolation residual, and "
            "cover/uncover topology impulse. Require each numerical ledger, "
            "component reconstruction relative RMS <=1e-4, and reproduction of "
            "the SHA-locked archived interval means within relative RMS <=1e-3. "
            "For D32-minus-D28 attribution, expand squared X/Z difference energy "
            "into four self terms and six signed pair interactions. Name a "
            "dominant mechanism only if one term supplies >=50% of the sum of "
            "absolute ledger contributions and is also largest in both temporal "
            "halves; otherwise classify the result as mixed."
        ),
        "fixedInputs": (
            "SHA-locked D28/D32 full-window reports and audits, failed refinement "
            "report and audit, phase-localization report and audit; RR3; source "
            "rho/mu engineering Reynolds; measured Deetjen geometry, kinematics, "
            "and force timing; pre-step local-density moving wall; unchanged "
            "geometry, boundary, collision, sponge, far-field, and force physics"
        ),
        "passed": True,
        "experimentalAgreementGateApplied": False,
        "gridConvergenceGateApplied": False,
        "claimBoundary": (
            "Version 2 corrects the first runner's implementation-only Reynolds "
            "mismatch while preserving every pre-observation interval, metric, "
            "threshold, and attribution rule; the invalid V1 contract and D28 "
            "output remain archived. This diagnostic can identify which production "
            "force-accounting mechanism explains the localized D28/D32 difference, "
            "but it cannot establish observed-"
            "order grid convergence, experimental agreement, production "
            "promotion, quantitative bird-load acceptance, or free flight."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

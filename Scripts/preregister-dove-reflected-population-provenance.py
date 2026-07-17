#!/usr/bin/env python3
"""Freeze the D28/D32 selected-link reflected-population provenance test."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-preregistration.json"
)

PATHS = {
    "targeted_preregistration": ARTIFACTS
    / "deetjen-dove-source-viscosity-targeted-boundary-preregistration.json",
    "d28_case": ARTIFACTS
    / "deetjen-dove-source-viscosity-targeted-boundary-d28.json",
    "d32_case": ARTIFACTS
    / "deetjen-dove-source-viscosity-targeted-boundary-d32.json",
    "targeted_report": ARTIFACTS
    / "deetjen-dove-source-viscosity-targeted-boundary.json",
    "targeted_audit": ARTIFACTS
    / "deetjen-dove-source-viscosity-targeted-boundary-audit.json",
    "v1_preregistration": ARTIFACTS
    / (
        "deetjen-dove-source-viscosity-reflected-provenance-"
        "preregistration-v1-insufficient-coverage.json"
    ),
    "v1_d28_case": ARTIFACTS
    / (
        "deetjen-dove-source-viscosity-reflected-provenance-"
        "d28-v1-insufficient-coverage.json"
    ),
}

EXPECTED_OPERATOR = "positivity-preserving-recursive-regularized-bgk"
EXPECTED_NORMALIZATION = "pre-step-local-density"
FIRST_TARGET_INDEX = 50
LAST_TARGET_INDEX = 60
THREADGROUP_WIDTH = 256
CANDIDATE_CAPACITY = 262_144
SELECTED_LINKS_PER_ENDPOINT = 131_072
STORED_EXEMPLARS_PER_ENDPOINT = 32
LINK_FRACTION_BIN_COUNT = 4


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    source = load(PATHS["targeted_preregistration"])
    d28 = load(PATHS["d28_case"])
    d32 = load(PATHS["d32_case"])
    report = load(PATHS["targeted_report"])
    audit = load(PATHS["targeted_audit"])
    v1_preregistration = load(PATHS["v1_preregistration"])
    v1_d28 = load(PATHS["v1_d28_case"])
    attribution = report["attribution"]

    if not (
        source["passed"]
        and source["schemaVersion"] == 2
        and d28["targetedCasePassed"]
        and d32["targetedCasePassed"]
        and report["bothTargetedCasesPassed"]
        and audit["allChecksPassed"]
        and audit["checkCount"] == 15
        and attribution["dominantContributionAvailable"]
        and attribution["leadingContributionName"] == "reflectedPopulation"
        and attribution["leadingContributionKind"] == "self"
        and attribution["sameLeaderInBothTemporalHalves"]
        and attribution["leadingAbsoluteLedgerFraction"] >= 0.50
        and d28["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and d32["selectedCollisionOperator"] == EXPECTED_OPERATOR
        and d28["movingWallNormalization"] == EXPECTED_NORMALIZATION
        and d32["movingWallNormalization"] == EXPECTED_NORMALIZATION
        and d28["referenceLengthCells"] == 28
        and d32["referenceLengthCells"] == 32
        and d28["firstCapturedStep"] == 2745
        and d28["lastCapturedStep"] == 3360
        and d32["firstCapturedStep"] == 3137
        and d32["lastCapturedStep"] == 3840
        and not report["productionModificationAuthorized"]
        and not report["gridConvergenceGateApplied"]
        and not report["experimentalAgreementGateApplied"]
        and v1_preregistration["schemaVersion"] == 1
        and v1_preregistration["passed"]
        and not v1_d28["provenanceCasePassed"]
        and not v1_d28["selectionCoveragePassed"]
        and v1_d28["numericalLedgerPassed"]
        and v1_d28["sourceReflectedForceReproductionPassed"]
        and v1_d28["candidateDetailPassed"]
        and v1_d28["minimumSelectedAbsoluteScoreCoverage"] < 0.50
        and v1_d28["sourceReflectedForceReproductionRelativeRMS"] <= 0.0001
        and v1_d28["candidateDetailMismatchCount"] == 0
    ):
        raise SystemExit("audited reflected-population attribution is required")

    endpoints = {
        "28": [index * 56 for index in range(FIRST_TARGET_INDEX, LAST_TARGET_INDEX + 1)],
        "32": [index * 64 for index in range(FIRST_TARGET_INDEX, LAST_TARGET_INDEX + 1)],
    }
    artifact = {
        "schemaVersion": 2,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-source-viscosity-reflected-provenance-v2"
        ),
        "datasetIdentifier": d28["datasetIdentifier"],
        "manifestSHA256": d28["manifestSHA256"],
        "forceTargetIdentifier": d28["forceTargetIdentifier"],
        "forceTargetSHA256": d28["forceTargetSHA256"],
        "sourceTargetedPreregistrationSHA256": sha256(
            PATHS["targeted_preregistration"]
        ),
        "sourceD28TargetedCaseSHA256": sha256(PATHS["d28_case"]),
        "sourceD32TargetedCaseSHA256": sha256(PATHS["d32_case"]),
        "sourceTargetedAttributionSHA256": sha256(PATHS["targeted_report"]),
        "sourceTargetedAuditSHA256": sha256(PATHS["targeted_audit"]),
        "sourceV1PreregistrationSHA256": sha256(
            PATHS["v1_preregistration"]
        ),
        "sourceV1D28CaseSHA256": sha256(PATHS["v1_d28_case"]),
        "selectedCollisionOperator": EXPECTED_OPERATOR,
        "movingWallNormalization": EXPECTED_NORMALIZATION,
        "sourcePropertyReynoldsNumber": source["sourcePropertyReynoldsNumber"],
        "expectedD28TauPlus": source["expectedD28TauPlus"],
        "expectedD32TauPlus": source["expectedD32TauPlus"],
        "referenceLengthCells": [28, 32],
        "targetSampleIndices": list(
            range(FIRST_TARGET_INDEX, LAST_TARGET_INDEX + 1)
        ),
        "targetStartTimeSeconds": source["targetStartTimeSeconds"],
        "targetEndTimeSeconds": source["targetEndTimeSeconds"],
        "d28FluidStepsPerForceSample": source["d28FluidStepsPerForceSample"],
        "d32FluidStepsPerForceSample": source["d32FluidStepsPerForceSample"],
        "d28RequestedSteps": source["d28RequestedSteps"],
        "d32RequestedSteps": source["d32RequestedSteps"],
        "d28CaptureEndpointSteps": endpoints["28"],
        "d32CaptureEndpointSteps": endpoints["32"],
        "threadgroupWidth": THREADGROUP_WIDTH,
        "candidateLinksPerThreadgroup": 0,
        "candidateCapacity": CANDIDATE_CAPACITY,
        "selectedLinksPerEndpoint": SELECTED_LINKS_PER_ENDPOINT,
        "storedExemplarsPerEndpoint": STORED_EXEMPLARS_PER_ENDPOINT,
        "linkFractionBinCount": LINK_FRACTION_BIN_COUNT,
        "selectionScore": (
            "absolute X/Z Euclidean norm of the production mode-2 reflected "
            "link-force contribution"
        ),
        "minimumSelectedAbsoluteScoreCoverage": 0.50,
        "maximumSourceReflectedForceReproductionRelativeRMS": 0.0001,
        "maximumCandidateDetailScoreDifference": 0.000001,
        "maximumPopulationCompositionClosureRelativeRMS": 0.0000000001,
        "minimumDominantContributionFraction": 0.50,
        "selectionRule": (
            "At force-bin endpoints 50...60, dispatch an observation-only "
            "selector after production link fractions are built and before the "
            "authoritative fluid update. Visit every production-active curved "
            "link, accumulate the full reflected mode-2 force and absolute X/Z "
            "score, append every positive-score link to a 262144-entry capture "
            "buffer, require zero append overflow, then retain the strongest "
            "131072 globally by deterministic score, target index, and "
            "direction ordering. Require at least 50% of the full "
            "absolute score at every endpoint and reproduce the source reflected "
            "force within relative RMS 1e-4. Capture the selected pre-step "
            "post-collision outgoing population, local equilibrium and "
            "nonequilibrium, density, q, branch, part, previous/current topology, "
            "wall projection, and force. Bin by part, direction, q quartile, "
            "branch, and topology. Decompose D32-minus-D28 selected reflected "
            "force exactly into within-stratum mean-population history and "
            "stratum coefficient/composition terms. Name a mechanism only when "
            "its self term supplies at least 50% of the absolute signed-energy "
            "ledger and remains the leader in both temporal halves; otherwise "
            "classify mixed."
        ),
        "fixedInputs": (
            "SHA-locked valid D28/D32 target-window component cases and their "
            "15-check attribution audit; 25...30 ms endpoints only; RR3; source "
            "rho/mu engineering Reynolds; pre-step local-density moving wall; "
            "unchanged measured geometry, kinematics, boundary reconstruction, "
            "collision, sponge, far field, topology impulse, and force physics"
        ),
        "revisionRationale": (
            "V1 is preserved under its SHA locks and failed only its frozen "
            "coverage gate: 8192 selected links covered 10.028376% at D28, "
            "while the numerical ledger, source-force reproduction, and exact "
            "candidate-detail identity passed. V2 changes observation capacity "
            "only; physical inputs, endpoints, score, 50% threshold, and "
            "population-versus-composition attribution remain unchanged."
        ),
        "passed": True,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This diagnostic can distinguish population-history sensitivity from "
            "near-wall link-composition sensitivity among the majority-coverage "
            "high-influence reflected links. It cannot establish whole-boundary "
            "causality, grid convergence, experimental agreement, quantitative "
            "bird-load acceptance, production promotion, or free flight, and it "
            "does not authorize a collision or boundary modification."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

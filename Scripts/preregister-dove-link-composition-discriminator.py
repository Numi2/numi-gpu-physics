#!/usr/bin/env python3
"""Freeze the zero-fluid D28/D32 reflected-link composition discriminator."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-link-composition-discriminator-preregistration.json"
)
PATHS = {
    "provenance_preregistration": ARTIFACTS
    / "deetjen-dove-source-viscosity-reflected-provenance-preregistration.json",
    "d28": ARTIFACTS
    / "deetjen-dove-source-viscosity-reflected-provenance-d28.json",
    "d32": ARTIFACTS
    / "deetjen-dove-source-viscosity-reflected-provenance-d32.json",
    "attribution": ARTIFACTS
    / "deetjen-dove-source-viscosity-reflected-provenance.json",
    "audit": ARTIFACTS
    / "deetjen-dove-source-viscosity-reflected-provenance-audit.json",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    provenance = load(PATHS["provenance_preregistration"])
    d28 = load(PATHS["d28"])
    d32 = load(PATHS["d32"])
    attribution = load(PATHS["attribution"])
    audit = load(PATHS["audit"])
    if not (
        provenance["schemaVersion"] == 2
        and provenance["passed"]
        and d28["provenanceCasePassed"]
        and d32["provenanceCasePassed"]
        and d28["candidateOverflowCount"] == 0
        and d32["candidateOverflowCount"] == 0
        and d28["candidateDetailMismatchCount"] == 0
        and d32["candidateDetailMismatchCount"] == 0
        and attribution["bothProvenanceCasesPassed"]
        and attribution["populationCompositionClosurePassed"]
        and attribution["attribution"]["classification"]
        == "dominant-near-wall-link-composition"
        and attribution["attribution"]["leadingAbsoluteLedgerFraction"] >= 0.5
        and attribution["attribution"]["sameLeaderInBothTemporalHalves"]
        and audit["allChecksPassed"]
        and audit["checkCount"] == 16
        and not attribution["productionModificationAuthorized"]
        and not attribution["gridConvergenceGateApplied"]
        and not attribution["experimentalAgreementGateApplied"]
    ):
        raise SystemExit("audited dominant link composition is required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-link-composition-shapley-discriminator-v1"
        ),
        "sourceProvenancePreregistrationSHA256": sha256(
            PATHS["provenance_preregistration"]
        ),
        "sourceD28ProvenanceSHA256": sha256(PATHS["d28"]),
        "sourceD32ProvenanceSHA256": sha256(PATHS["d32"]),
        "sourceProvenanceAttributionSHA256": sha256(PATHS["attribution"]),
        "sourceProvenanceAuditSHA256": sha256(PATHS["audit"]),
        "referenceLengthCells": [28, 32],
        "targetSampleIndices": list(range(50, 61)),
        "populationField": (
            "Freeze every union-stratum reflected-population mean to the "
            "D28/D32 midpoint; an absent-grid mean is zero, exactly matching "
            "the accepted population-versus-composition midpoint identity."
        ),
        "factorOrder": [
            "linkMeasureScale",
            "partOccupancy",
            "directionComposition",
            "interpolationBranch",
            "topologyClass",
            "linkFractionBin",
        ],
        "conditionalFactorization": [
            "total selected link count times physical per-link force scale",
            "P(part)",
            "P(direction | part)",
            "P(branch | part, direction)",
            "P(topology | part, direction, branch)",
            "P(q-bin | part, direction, branch, topology)",
        ],
        "crossApplicationRule": (
            "For every endpoint and each of the 64 factor subsets, use the D32 "
            "total-scale or conditional table for selected factors and D28 for "
            "unselected factors. If a chosen source has zero parent-context "
            "count, use the frozen pooled D28+D32 conditional and record its "
            "hybrid probability mass. Reconstruct X/Z force from the fixed "
            "midpoint population, D3Q19 direction, hybrid probability, and "
            "hybrid total link-measure scale. Empty/all subsets must reproduce "
            "the direct D28/D32 composition states."
        ),
        "shapleyRule": (
            "Average every factor's force increment over all subset orders with "
            "the exact |S|!(6-|S|-1)!/6! weight. The six endpoint vectors must "
            "sum to the full D32-minus-D28 link-composition vector. Allocate "
            "squared-difference energy by dot(phi_factor, total_delta); these "
            "six signed contributions must sum exactly to total energy."
        ),
        "maximumEndpointStateReconstructionRelativeRMS": 1e-10,
        "maximumShapleyForceClosureRelativeRMS": 1e-12,
        "maximumEnergyClosureRelativeError": 1e-12,
        "maximumConditionalNormalizationError": 1e-12,
        "maximumPooledFallbackProbabilityMass": 0.05,
        "minimumDominantContributionFraction": 0.5,
        "dominanceRule": (
            "Name one factor only when its absolute signed-energy contribution "
            "is at least 50% of the total absolute six-factor ledger and it is "
            "also the largest factor in both temporal halves; otherwise classify "
            "the result as mixed."
        ),
        "fixedInputs": (
            "SHA-locked V2 D28/D32 selected-link provenance endpoints 50...60, "
            "their exact population/composition attribution and 16-check audit, "
            "the published D3Q19 direction table, no fluid evolution, no new "
            "geometry, and no production parameter or physics change"
        ),
        "passed": True,
        "fluidEvolutionAuthorized": False,
        "minimalCanonicalAuthorizedOnlyAfterDominantFactor": True,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This zero-fluid diagnostic can identify which conditioned selected-"
            "link composition factor explains the accepted majority-coverage "
            "D28/D32 reflected-force composition term. It cannot establish a "
            "boundary defect, whole-boundary causality, grid convergence, "
            "experimental agreement, production promotion, quantitative bird "
            "loads, or free flight. A dominant factor authorizes only one frozen "
            "minimal canonical for that factor."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Freeze the D28/D32 complete-link direction-composition discriminator."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
MANIFEST = ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
FORCE_TARGET = ROOT / "ValidationInputs/deetjen-ob-f03-force-v1.json"
CURVED_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-preregistration.json"
)
CURVED_REPORT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical.json"
)
CURVED_AUDIT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-audit.json"
)
D28_PROVENANCE = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
)
D32_PROVENANCE = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
)
PROVENANCE_AUDIT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-audit.json"
)
REFINEMENT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-d28-d32-refinement.json"
)
REFINEMENT_AUDIT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-d28-d32-refinement-audit.json"
)
OUTPUT = ARTIFACTS / (
    "deetjen-dove-fine-direction-composition-preregistration.json"
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def endpoint(report: dict, sample: int) -> dict:
    matches = [
        item for item in report["endpoints"]
        if item["targetSampleIndex"] == sample
    ]
    if len(matches) != 1:
        raise SystemExit(f"provenance must contain exactly one sample {sample}")
    return matches[0]


def main() -> None:
    manifest = load(MANIFEST)
    force_target = load(FORCE_TARGET)
    curved_prereg = load(CURVED_PREREGISTRATION)
    curved_report = load(CURVED_REPORT)
    curved_audit = load(CURVED_AUDIT)
    d28 = load(D28_PROVENANCE)
    d32 = load(D32_PROVENANCE)
    provenance_audit = load(PROVENANCE_AUDIT)
    refinement = load(REFINEMENT)
    refinement_audit = load(REFINEMENT_AUDIT)
    d28_endpoint = endpoint(d28, 53)
    d32_endpoint = endpoint(d32, 53)

    if not (
        curved_prereg["schemaVersion"] == 1
        and curved_prereg["passed"]
        and curved_report["canonicalPassed"]
        and curved_report["classification"]
        == "curved-direction-redistribution-cleared-at-d12-d16"
        and curved_report["sourcePreregistrationSHA256"]
        == sha256(CURVED_PREREGISTRATION)
        and curved_audit["allChecksPassed"]
        and curved_audit["checkCount"] == 14
        and curved_audit["reportSHA256"] == sha256(CURVED_REPORT)
        and d28["schemaVersion"] == 2
        and d32["schemaVersion"] == 2
        and d28["referenceLengthCells"] == 28
        and d32["referenceLengthCells"] == 32
        and [d28["gridX"], d28["gridY"], d28["gridZ"]]
        == [259, 238, 229]
        and [d32["gridX"], d32["gridY"], d32["gridZ"]]
        == [296, 271, 261]
        and d28["provenanceCasePassed"]
        and d32["provenanceCasePassed"]
        and d28_endpoint["sourceTimeSeconds"] == 0.0265
        and d32_endpoint["sourceTimeSeconds"] == 0.0265
        and d28_endpoint["productionActiveLinkCount"] == 139_963
        and d32_endpoint["productionActiveLinkCount"] == 183_370
        and provenance_audit["allChecksPassed"]
        and provenance_audit["checkCount"] >= 16
        and refinement["classification"]
        == "d28-d32-fine-pair-not-stabilized"
        and not refinement["finePairStabilizationPassed"]
        and refinement_audit["allChecksPassed"]
        and refinement_audit["checkCount"] == 12
        and manifest["datasetIdentifier"] == d28["datasetIdentifier"]
        and force_target["datasetIdentifier"] == d28["forceTargetIdentifier"]
    ):
        raise SystemExit("audited curved and D28/D32 provenance sources required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-fine-direction-composition-v1"
        ),
        "datasetIdentifier": manifest["datasetIdentifier"],
        "manifestSHA256": sha256(MANIFEST),
        "forceTargetIdentifier": force_target["datasetIdentifier"],
        "forceTargetSHA256": sha256(FORCE_TARGET),
        "sourceCurvedPreregistrationSHA256": sha256(CURVED_PREREGISTRATION),
        "sourceCurvedReportSHA256": sha256(CURVED_REPORT),
        "sourceCurvedAuditSHA256": sha256(CURVED_AUDIT),
        "sourceD28ProvenanceSHA256": sha256(D28_PROVENANCE),
        "sourceD32ProvenanceSHA256": sha256(D32_PROVENANCE),
        "sourceProvenanceAuditSHA256": sha256(PROVENANCE_AUDIT),
        "sourceRefinementSHA256": sha256(REFINEMENT),
        "sourceRefinementAuditSHA256": sha256(REFINEMENT_AUDIT),
        "referenceLengthCells": [28, 32],
        "expectedGridCells": {
            "28": [259, 238, 229],
            "32": [296, 271, 261],
        },
        "frozenSourceSampleIndex": 53,
        "frozenSourceTimeSeconds": 0.0265,
        "halfThicknessMeters": 0.0075,
        "components": curved_prereg["components"],
        "directionIndices": curved_prereg["directionIndices"],
        "oppositeDirectionPairs": curved_prereg["oppositeDirectionPairs"],
        "fixedPopulationProfiles": curved_prereg["fixedPopulationProfiles"],
        "productionActiveLinkReference": [
            {
                "referenceLengthCells": 28,
                "activeLinkCount": d28_endpoint["productionActiveLinkCount"],
            },
            {
                "referenceLengthCells": 32,
                "activeLinkCount": d32_endpoint["productionActiveLinkCount"],
            },
        ],
        "maximumMetalCPUMaskMismatchCellCount": 0,
        "maximumMetalCPUPerDirectionCountMismatch": 0,
        "maximumCensusToProductionActiveLinkRelativeDifference": 0.05,
        "maximumWholeSurfaceOppositeDirectionCountMismatch": 0,
        "maximumEquilibriumWholeSurfaceNetLedgerFraction": 1e-12,
        "maximumWholeSurfaceDirectionHistogramTotalVariation": 0.05,
        "maximumComponentDirectionHistogramTotalVariation": 0.10,
        "maximumWholeSurfaceProfileResponseLedgerDifference": 0.05,
        "maximumComponentProfileResponseLedgerDifference": 0.10,
        "responseDefinition": curved_prereg["responseDefinition"],
        "normalizationDefinition": (
            curved_prereg["normalizationDefinition"]
            .replace("D12/D16", "D28/D32")
            .replace("term_D12", "term_D28")
            .replace("term_D16", "term_D32")
        ),
        "selectionRule": (
            "At source sample 53 (26.5 ms), raster the complete measured-dove "
            "surface independently through the production Metal indexed-surface "
            "path and CPU reference at D28 and D32. Enumerate every current "
            "solid-to-fluid D3Q19 link by component and direction. Execute no "
            "population allocation, collision, streaming, force estimator, or "
            "topology evolution. Require exact Metal/CPU masks and direction "
            "counts; compare total counts with the already archived production "
            "active-link totals; then apply the inherited curved-canonical "
            "histogram and fixed-population response ledgers without changing "
            "their thresholds."
        ),
        "classificationRule": (
            "Classify invalid-census-parity if Metal and CPU masks or any "
            "component/direction count differ. Classify production-link-set-"
            "mismatch if either total differs from its archived moving-run "
            "active-link reference by more than 5%. Otherwise clear fine-pair "
            "direction redistribution only if exact opposite balance, closed-"
            "surface equilibrium cancellation, whole/component histograms, and "
            "both inherited fixed-profile response gates pass."
        ),
        "fluidEvolutionAuthorized": False,
        "populationAllocationAuthorized": False,
        "newPhysicsKernelAuthorized": False,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This geometry-only D28/D32 census can clear or localize fine-pair "
            "direction support at one source phase. It cannot validate wall "
            "velocity, interpolation, force magnitude, phase history, bird-load "
            "grid convergence, experimental agreement, quantitative bird flight, "
            "or free flight, and it authorizes no production edit or D36 run."
        ),
        "passed": True,
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

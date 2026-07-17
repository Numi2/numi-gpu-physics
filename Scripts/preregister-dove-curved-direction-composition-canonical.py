#!/usr/bin/env python3
"""Freeze the source-locked curved-surface direction-only canonical."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
MANIFEST = ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
LINK_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-moving-wall-link-geometry-preregistration.json"
)
LINK_REPORT = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry.json"
LINK_AUDIT = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-audit.json"
PLANAR_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-preregistration.json"
)
PLANAR_REPORT = ARTIFACTS / "deetjen-dove-direction-composition-canonical.json"
PLANAR_AUDIT = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-audit.json"
)
OUTPUT = ARTIFACTS / (
    "deetjen-dove-curved-direction-composition-canonical-preregistration.json"
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    manifest = load(MANIFEST)
    link_preregistration = load(LINK_PREREGISTRATION)
    link_report = load(LINK_REPORT)
    link_audit = load(LINK_AUDIT)
    planar_preregistration = load(PLANAR_PREREGISTRATION)
    planar_report = load(PLANAR_REPORT)
    planar_audit = load(PLANAR_AUDIT)
    source_cases = [link_report["d12"], link_report["d16"]]
    if not (
        link_preregistration["schemaVersion"] == 2
        and link_preregistration["referenceLengthCells"] == [12, 16]
        and link_preregistration["frozenSourceSampleIndex"] == 53
        and abs(
            link_preregistration["frozenSourceTimeSeconds"] - 0.0265
        ) <= 1e-12
        and link_report["manifestSHA256"] == sha256(MANIFEST)
        and link_report["sourceLinkGeometryPreregistrationSHA256"]
        == sha256(LINK_PREREGISTRATION)
        and all(case["parityGatePassed"] for case in source_cases)
        and all(case["metalCPUExactLinkCountMatch"] for case in source_cases)
        and all(len(case["metalBins"]) == 72 for case in source_cases)
        and all(len(case["cpuBins"]) == 72 for case in source_cases)
        and link_audit["allChecksPassed"]
        and link_audit["checkCount"] == 13
        and planar_preregistration["schemaVersion"] == 2
        and planar_preregistration["passed"]
        and planar_report["canonicalPassed"]
        and planar_report["basicPlanarDirectionWeightingCleared"]
        and planar_report["sourcePreregistrationSHA256"]
        == sha256(PLANAR_PREREGISTRATION)
        and planar_audit["allChecksPassed"]
        and planar_audit["reportSHA256"] == sha256(PLANAR_REPORT)
    ):
        raise SystemExit("audited planar and curved link-count sources are required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-curved-direction-composition-canonical-v1"
        ),
        "datasetIdentifier": link_report["datasetIdentifier"],
        "sourceSurfaceManifestSHA256": sha256(MANIFEST),
        "sourceLinkGeometryPreregistrationSHA256": sha256(
            LINK_PREREGISTRATION
        ),
        "sourceLinkGeometryReportSHA256": sha256(LINK_REPORT),
        "sourceLinkGeometryAuditSHA256": sha256(LINK_AUDIT),
        "sourcePlanarPreregistrationSHA256": sha256(PLANAR_PREREGISTRATION),
        "sourcePlanarReportSHA256": sha256(PLANAR_REPORT),
        "sourcePlanarAuditSHA256": sha256(PLANAR_AUDIT),
        "referenceLengthCells": [12, 16],
        "frozenSourceSampleIndex": 53,
        "frozenSourceTimeSeconds": 0.0265,
        "components": [
            {"partIdentifier": 1, "componentName": "body"},
            {"partIdentifier": 2, "componentName": "leftWing"},
            {"partIdentifier": 3, "componentName": "rightWing"},
            {"partIdentifier": 4, "componentName": "tail"},
        ],
        "directionIndices": list(range(1, 19)),
        "oppositeDirectionPairs": [
            [1, 2], [3, 4], [5, 6], [7, 8], [9, 10],
            [11, 12], [13, 14], [15, 16], [17, 18],
        ],
        "fixedPopulationProfiles": planar_preregistration[
            "fixedPopulationProfiles"
        ],
        "responseDefinition": (
            "For grid g, component p, and fixed profile k, reconstruct the "
            "outward solid-to-fluid link response R_gpk = sum_q "
            "2*f_kq*c_q*N_gpq*dx_g^2 from the archived Metal link counts. "
            "Whole-bird response is the exact sum over the four components."
        ),
        "normalizationDefinition": (
            "Normalize a D12/D16 response-vector change by the mean absolute "
            "direction ledger: 0.5*(sum_q ||term_D12,q|| + sum_q "
            "||term_D16,q||). This remains finite when the closed-surface net "
            "response cancels. Direction histograms normalize N_q*dx^2 by "
            "their total over q."
        ),
        "maximumWholeSurfaceOppositeDirectionCountMismatch": 0,
        "maximumEquilibriumWholeSurfaceNetLedgerFraction": 1e-12,
        "maximumWholeSurfaceDirectionHistogramTotalVariation": 0.05,
        "maximumComponentDirectionHistogramTotalVariation": 0.10,
        "maximumWholeSurfaceProfileResponseLedgerDifference": 0.05,
        "maximumComponentProfileResponseLedgerDifference": 0.10,
        "classificationRule": (
            "First require the source Metal/CPU parity gates, exact whole-mask "
            "opposite-direction balance, and closed-surface equilibrium "
            "cancellation. Clear curved direction redistribution at D12/D16 "
            "only if whole/component direction histograms and both frozen "
            "profile responses remain within their preregistered limits. A "
            "source-profile-only failure localizes population-weighted curved "
            "direction redistribution; a histogram or equilibrium failure "
            "localizes geometry/counting redistribution."
        ),
        "fixedInputs": (
            "Hashed Deetjen OB_F03 complete-surface manifest; source sample 53 "
            "at 26.5 ms; audited production D12/D16 indexed-surface Metal and "
            "CPU link bins; production D3Q19 directions; and the exact planar "
            "equilibrium and Deetjen midpoint population profiles. Consume "
            "only component, direction, link count, and cell size. Ignore wall "
            "velocity, interpolation fraction, populations, force histories, "
            "and the source report's separate wall-velocity classification."
        ),
        "fluidEvolutionAuthorized": False,
        "newMetalExecutionAuthorized": False,
        "productionModificationAuthorized": False,
        "d20RunAuthorized": False,
        "d28D32FluidRunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This archive-only canonical tests fixed-population D3Q19 direction "
            "redistribution on one source-locked curved complete-dove surface "
            "at D12/D16. It cannot establish the D28/D32 bird-load grid limit, "
            "validate wall velocity or interpolation, authorize a production "
            "edit or new fluid run, establish experimental agreement, or claim "
            "quantitative bird flight or free flight."
        ),
        "passed": True,
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

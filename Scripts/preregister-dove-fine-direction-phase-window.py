#!/usr/bin/env python3
"""Freeze the zero-fluid D28/D32 complete-link census over 25--30 ms."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
SINGLE_PREREG = ARTIFACTS / "deetjen-dove-fine-direction-composition-preregistration.json"
SINGLE_CENSUS = ARTIFACTS / "deetjen-dove-fine-direction-composition-census.json"
SINGLE_REPORT = ARTIFACTS / "deetjen-dove-fine-direction-composition-discriminator.json"
SINGLE_AUDIT = ARTIFACTS / "deetjen-dove-fine-direction-composition-audit.json"
D28_PROVENANCE = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
D32_PROVENANCE = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json"
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    single = load(SINGLE_PREREG)
    census = load(SINGLE_CENSUS)
    report = load(SINGLE_REPORT)
    audit = load(SINGLE_AUDIT)
    provenance = {
        28: load(D28_PROVENANCE),
        32: load(D32_PROVENANCE),
    }
    if not (
        single["passed"]
        and census["censusPassed"]
        and report["analysisPassed"]
        and audit["allChecksPassed"]
        and audit["reportSHA256"] == sha256(SINGLE_REPORT)
        and census["sourcePreregistrationSHA256"] == sha256(SINGLE_PREREG)
        and report["sourceCensusSHA256"] == sha256(SINGLE_CENSUS)
        and report["classification"]
        == "fine-direction-redistribution-cleared-at-d28-d32"
    ):
        raise SystemExit("accepted single-phase fine-direction chain required")

    sample_indices = list(range(50, 61))
    source_times = [index / 2000.0 for index in sample_indices]
    production_references: list[dict] = []
    for resolution in (28, 32):
        endpoints = {
            item["targetSampleIndex"]: item
            for item in provenance[resolution]["endpoints"]
        }
        if sorted(endpoints) != sample_indices:
            raise SystemExit(f"D{resolution} provenance endpoint coverage changed")
        for sample_index, source_time in zip(sample_indices, source_times):
            endpoint = endpoints[sample_index]
            if abs(endpoint["sourceTimeSeconds"] - source_time) > 1e-12:
                raise SystemExit("provenance source time changed")
            production_references.append(
                {
                    "sourceSampleIndex": sample_index,
                    "sourceTimeSeconds": source_time,
                    "referenceLengthCells": resolution,
                    "activeLinkCount": endpoint["productionActiveLinkCount"],
                }
            )

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-fine-direction-phase-window-v1"
        ),
        "datasetIdentifier": single["datasetIdentifier"],
        "manifestSHA256": single["manifestSHA256"],
        "forceTargetIdentifier": single["forceTargetIdentifier"],
        "forceTargetSHA256": single["forceTargetSHA256"],
        "sourceSinglePhasePreregistrationSHA256": sha256(SINGLE_PREREG),
        "sourceSinglePhaseCensusSHA256": sha256(SINGLE_CENSUS),
        "sourceSinglePhaseDiscriminatorSHA256": sha256(SINGLE_REPORT),
        "sourceSinglePhaseAuditSHA256": sha256(SINGLE_AUDIT),
        "sourceD28ProvenanceSHA256": sha256(D28_PROVENANCE),
        "sourceD32ProvenanceSHA256": sha256(D32_PROVENANCE),
        "referenceLengthCells": [28, 32],
        "expectedGridCells": single["expectedGridCells"],
        "sourceSampleIndices": sample_indices,
        "sourceTimesSeconds": source_times,
        "halfThicknessMeters": single["halfThicknessMeters"],
        "components": single["components"],
        "directionIndices": single["directionIndices"],
        "oppositeDirectionPairs": single["oppositeDirectionPairs"],
        "fixedPopulationProfiles": single["fixedPopulationProfiles"],
        "productionActiveLinkReferences": production_references,
        "maximumMetalCPUMaskMismatchCellCount": 0,
        "maximumMetalCPUPerDirectionCountMismatch": 0,
        "maximumCensusToProductionActiveLinkRelativeDifference": 0.05,
        "maximumWholeSurfaceOppositeDirectionCountMismatch": 0,
        "maximumEquilibriumWholeSurfaceNetLedgerFraction": 1e-12,
        "maximumWholeSurfaceDirectionHistogramTotalVariation": 0.05,
        "maximumComponentDirectionHistogramTotalVariation": 0.10,
        "maximumWholeSurfaceProfileResponseLedgerDifference": 0.05,
        "maximumComponentProfileResponseLedgerDifference": 0.10,
        "responseDefinition": single["responseDefinition"],
        "normalizationDefinition": single["normalizationDefinition"],
        "selectionRule": (
            "For each source sample 50 through 60 inclusive (25 through 30 ms), "
            "raster the complete measured-dove surface through production Metal "
            "and the independent CPU reference at D28 and D32. Count every current "
            "solid-to-fluid D3Q19 link by component and direction. Allocate no "
            "populations and execute no collision, streaming, force, or topology "
            "evolution. Apply the unchanged single-phase parity, production-link, "
            "opposite-balance, histogram, and fixed-profile response gates at every "
            "sample; the window passes only when all eleven samples pass."
        ),
        "classificationRule": (
            "Classify invalid-census-parity if any Metal/CPU mask or direction "
            "count differs. Classify production-link-set-mismatch if any total is "
            "more than 5% from its same-grid same-sample archived active-link "
            "reference. Otherwise clear phase-resolved fine direction redistribution "
            "only if all eight inherited gates pass independently at all eleven "
            "samples."
        ),
        "fluidEvolutionAuthorized": False,
        "populationAllocationAuthorized": False,
        "newPhysicsKernelAuthorized": False,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This geometry-only D28/D32 window can clear static direction support "
            "over 25-30 ms. It cannot validate moving-wall velocity, interpolation, "
            "realized populations, force magnitude, bird-load grid convergence, "
            "experimental agreement, quantitative bird flight, or free flight, and "
            "it authorizes no production edit or D36 run."
        ),
        "passed": True,
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

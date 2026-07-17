#!/usr/bin/env python3
"""Freeze the arithmetic-tie-only V2 qualification after the retained V1 stop."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
V1_PREREG = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json"
V1_FAILURE = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json"
OUTPUT = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-preregistration.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    prereg = json.loads(V1_PREREG.read_text())
    failure = json.loads(V1_FAILURE.read_text())
    if not (
        prereg["passed"]
        and failure["sourcePreregistrationSHA256"] == sha256(V1_PREREG)
        and failure["classification"] == "invalid-census-parity"
        and not failure["censusPassed"]
        and len(failure["cases"]) == 22
    ):
        raise SystemExit("retained exact-parity V1 failure required")

    artifact = dict(prereg)
    artifact.update(
        {
            "schemaVersion": 2,
            "preregistrationIdentifier": (
                "deetjen-ob-f03-fine-direction-phase-window-v2"
            ),
            "sourceV1PreregistrationSHA256": sha256(V1_PREREG),
            "sourceV1ExactParityFailureSHA256": sha256(V1_FAILURE),
            "arithmeticOnlyRevision": True,
            "maximumMetalCPUMaskMismatchCellCount": 1,
            "maximumMetalCPUPerDirectionCountMismatch": 1,
            "maximumMetalCPUWholeDirectionCountMismatch": 0,
            "maximumQualifiedTieCellsPerCase": 1,
            "solidFluidTieAbsoluteDistanceToleranceCells": 1e-5,
            "componentOwnershipTieDistanceDifferenceToleranceCells": 1e-5,
            "selectionRule": (
                prereg["selectionRule"]
                + " V2 consumes the already captured V1 counts without a new "
                "Metal run. A single Metal/CPU mask disagreement is equivalent "
                "only when it is either a solid/fluid sign tie with both absolute "
                "signed distances no larger than 1e-5 cells, or a nonzero/nonzero "
                "component-ownership tie whose signed-distance difference is no "
                "larger than 1e-5 cells. Whole-surface direction counts must remain "
                "exact in every case and per-component/direction differences may "
                "not exceed one link."
            ),
            "classificationRule": (
                "Classify unqualified-arithmetic-mismatch if any V1 disagreement "
                "falls outside the frozen tie definitions, if a case has more than "
                "one tie cell, if any whole-surface direction count differs, or if "
                "a component/direction count differs by more than one link. "
                "Otherwise apply the unchanged production-link, opposite-balance, "
                "histogram, equilibrium, and fixed-profile gates independently at "
                "all eleven samples."
            ),
            "claimBoundary": (
                "This V2 is an arithmetic-equivalence qualification of the retained "
                "V1 one-cell raster ties. It requires exact whole-surface direction "
                "counts and does not relax any histogram or response threshold. It "
                "can clear static D28/D32 direction support over 25-30 ms, but cannot "
                "validate moving-wall velocity, interpolation, realized populations, "
                "force magnitude, bird-load convergence, experimental agreement, "
                "quantitative bird flight, or free flight, and authorizes no "
                "production edit or D36 run."
            ),
        }
    )
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

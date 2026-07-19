#!/usr/bin/env python3
"""Freeze the D=8-only RR3 extension after the V1 period-identification stop."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
DURATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-duration.json"
)
PERIOD_PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-preregistration.json"
)
PERIOD_RESULT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-extension-preregistration.json"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    duration = json.loads(DURATION.read_text(encoding="utf-8"))
    period = json.loads(PERIOD_RESULT.read_text(encoding="utf-8"))
    if not (
        duration.get("passed")
        and duration.get("allIndividualGatesPassed")
        and period.get("passed")
        and not period.get("periodIdentificationPassed")
        and period.get("classification") == "d8-shedding-period-unresolved"
        and period.get("sourceDurationReportSHA256") == sha256(DURATION)
        and period.get("sourcePreregistrationSHA256")
        == sha256(PERIOD_PREREGISTRATION)
    ):
        raise SystemExit("retained V1 D=8 period-identification stop required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": "stationary-wall-rr3-d8-extension-v1",
        "sourceDurationReportSHA256": sha256(DURATION),
        "sourcePeriodPreregistrationSHA256": sha256(PERIOD_PREREGISTRATION),
        "sourcePeriodResultSHA256": sha256(PERIOD_RESULT),
        "selectedDiameterCells": 8,
        "requestedConvectiveTimes": 30,
        "requestedSteps": 3000,
        "reynoldsNumber": 9367.4,
        "latticeFarFieldSpeed": 0.08,
        "collisionOperator": (
            "recursive second-plus-supported-third-order D3Q19 Hermite "
            "reconstruction with a convex equilibrium-to-post-collision "
            "positivity scale"
        ),
        "unchangedGates": {
            "maximumRelativeRMSForceResidual": 0.005,
            "maximumPeakForceResidualRatio": 0.001,
            "maximumControlVolumeCorrectionActivationFraction": 0.05,
            "maximumRelativeControlVolumeCorrectionL1": 0.01,
            "maximumRelativeControlVolumeCorrectionL2": 0.01,
            "maximumRelativeRMSBoundaryLoadClosureResidual": 0.00005,
            "maximumRelativeCumulativeLimiterMassContribution": 0.000001,
            "minimumPopulationExclusive": 0,
            "maximumSolidControlSurfaceCrossingLinkCount": 0,
            "requireControlVolumeOutsideSponge": True,
            "requireNoTopologyTransitions": True,
        },
        "selectionRule": (
            "Run only D=8 from rest through 30 convective times with the same "
            "domain, Reynolds number, stationary voxel sphere, RR3 collision, "
            "source ledger, force budget, and non-intrusive correction limits as "
            "the retained ten-time source. Archive every native drag sample."
        ),
        "nextAnalysisRule": (
            "After and only after this numerical case passes, freeze a V2 period "
            "analysis that retains the V1 frequency band, detrending, spectral, "
            "autocorrelation, split-stability, complete-block, and uncertainty "
            "thresholds while replacing the analysis interval with 10 through 30 "
            "convective times."
        ),
        "d20RunAuthorized": False,
        "productionModificationAuthorized": False,
        "rr3BirdReplayPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This controlled extension can supply a longer D=8 RR3 stationary-"
            "sphere force history for period-complete statistics. It cannot establish "
            "spatial convergence, authorize D20 by itself, promote RR3 into bird "
            "replay, establish experimental agreement, or support a biological claim."
        ),
        "passed": True,
    }
    OUTPUT.write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

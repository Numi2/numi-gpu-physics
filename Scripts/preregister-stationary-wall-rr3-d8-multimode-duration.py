#!/usr/bin/env python3
"""Freeze the D=8 vector-force duration extension after low-mode identification."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
MULTIMODE_PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-preregistration.json"
)
MULTIMODE_CAPTURE = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode.json"
)
MULTIMODE_ANALYSIS = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-analysis.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-duration-preregistration.json"
)

LOCKED_ANALYSIS_FIELDS = [
    "detrendingMethod",
    "spectralMethod",
    "lowModeFrequencyBandCyclesPerConvectiveTimeInclusive",
    "dragHarmonicFrequencyBandCyclesPerConvectiveTimeInclusive",
    "shearLayerFrequencyBandCyclesPerConvectiveTimeInclusive",
    "minimumLowModeDominantToRunnerUpPowerRatio",
    "runnerUpExclusionBinsAroundPeak",
    "maximumLowModeSplitHalfFrequencyRelativeDifference",
    "maximumDragToTwiceLowModeFrequencyRelativeDifference",
    "minimumCompleteLowModeBlockCount",
    "blockConstruction",
    "uncertaintyMethod",
    "maximumRelative95ConfidenceHalfWidth",
    "maximumFirstHalfSecondHalfBlockMeanRelativeDifference",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    original_prereg = json.loads(
        MULTIMODE_PREREGISTRATION.read_text(encoding="utf-8")
    )
    capture = json.loads(MULTIMODE_CAPTURE.read_text(encoding="utf-8"))
    analysis = json.loads(MULTIMODE_ANALYSIS.read_text(encoding="utf-8"))
    if not (
        original_prereg.get("passed")
        and capture.get("passed")
        and capture.get("forceVectorSamplesArchived")
        and analysis.get("passed")
        and analysis.get("lowModeIdentified")
        and not analysis.get("periodCompleteStatisticPassed")
        and analysis.get("sourceCaptureReportSHA256") == sha256(MULTIMODE_CAPTURE)
        and analysis.get("sourcePreregistrationSHA256")
        == sha256(MULTIMODE_PREREGISTRATION)
    ):
        raise SystemExit("retained low-mode-identified D=8 multimode stop required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": "stationary-wall-rr3-d8-multimode-duration-v2",
        "sourceMultimodePreregistrationSHA256": sha256(
            MULTIMODE_PREREGISTRATION
        ),
        "sourceMultimodeCaptureSHA256": sha256(MULTIMODE_CAPTURE),
        "sourceMultimodeAnalysisSHA256": sha256(MULTIMODE_ANALYSIS),
        "selectedDiameterCells": 8,
        "requestedConvectiveTimes": 60,
        "requestedSteps": 6000,
        "analysisStartConvectiveTimeInclusive": 10.0,
        "analysisEndConvectiveTimeInclusive": 60.0,
        "requiredCapture": original_prereg["requiredCapture"],
        "numericalSelectionRule": (
            "Run only D=8 from rest through 60 convective times with the same "
            "domain, Reynolds number, stationary voxel sphere, RR3 collision, "
            "source ledger, force budget, and non-intrusive correction limits. "
            "The first 3000 force-vector samples must reproduce the retained "
            "thirty-time capture exactly."
        ),
        "classificationRule": (
            "Apply the unchanged multimode V1 low-mode, drag-harmonic, split-half, "
            "complete-block, confidence, and early/late gates to convective times "
            "10 through 60. A complete pass authorizes D20 planning only. Failure "
            "does not change any method, collision, correction, or refinement gate."
        ),
        "d20PlanningAuthorizedOnPass": True,
        "productionModificationAuthorized": False,
        "rr3BirdReplayPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This duration extension can determine whether the identified D=8 low "
            "wake mode yields a stable complete-period mean-drag statistic. It "
            "cannot establish spatial convergence, validate D20, promote RR3 into "
            "bird replay, establish experimental agreement, or support a biological "
            "claim."
        ),
        "passed": True,
    }
    for field in LOCKED_ANALYSIS_FIELDS:
        artifact[field] = original_prereg[field]

    OUTPUT.write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

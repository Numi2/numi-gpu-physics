#!/usr/bin/env python3
"""Freeze the extended D=8 RR3 period analysis before inspecting its spectrum."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
V1_PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-preregistration.json"
)
V1_RESULT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period.json"
)
EXTENSION_PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-extension-preregistration.json"
)
EXTENSION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-extension.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-v2-preregistration.json"
)

LOCKED_METHOD_FIELDS = [
    "detrendingMethod",
    "minimumFrequencyCyclesPerConvectiveTime",
    "maximumFrequencyCyclesPerConvectiveTime",
    "spectralMethod",
    "autocorrelationMethod",
    "splitHalfMethod",
    "minimumDominantToRunnerUpPowerRatio",
    "runnerUpExclusionBinsAroundPeak",
    "maximumFourierAutocorrelationPeriodRelativeDifference",
    "maximumSplitHalfPeriodRelativeDifference",
    "minimumCompletePeriodBlockCount",
    "blockConstruction",
    "uncertaintyMethod",
    "maximumRelative95ConfidenceHalfWidth",
    "maximumFirstHalfSecondHalfBlockMeanRelativeDifference",
]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    v1_prereg = json.loads(V1_PREREGISTRATION.read_text(encoding="utf-8"))
    v1_result = json.loads(V1_RESULT.read_text(encoding="utf-8"))
    extension_prereg = json.loads(
        EXTENSION_PREREGISTRATION.read_text(encoding="utf-8")
    )
    extension = json.loads(EXTENSION.read_text(encoding="utf-8"))
    case = extension.get("numericalCase", {})
    if not (
        v1_prereg.get("passed")
        and v1_result.get("passed")
        and not v1_result.get("periodIdentificationPassed")
        and extension_prereg.get("passed")
        and extension_prereg.get("sourcePeriodResultSHA256") == sha256(V1_RESULT)
        and extension.get("passed")
        and extension.get("allIndividualGatesPassed")
        and extension.get("requestedConvectiveTimes") == 30
        and case.get("diameterCells") == 8
        and case.get("requestedSteps") == 3000
        and case.get("completedConvectiveTimes") == 30
        and len(case.get("samples", [])) == 3000
    ):
        raise SystemExit("passing preregistered D=8 thirty-time extension required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": "stationary-wall-rr3-d8-period-v2",
        "sourceV1PreregistrationSHA256": sha256(V1_PREREGISTRATION),
        "sourceV1ResultSHA256": sha256(V1_RESULT),
        "sourceExtensionPreregistrationSHA256": sha256(
            EXTENSION_PREREGISTRATION
        ),
        "sourceExtensionReportSHA256": sha256(EXTENSION),
        "sourceExtensionClassification": extension["classification"],
        "selectedDiameterCells": 8,
        "analysisStartConvectiveTimeInclusive": 10.0,
        "analysisEndConvectiveTimeInclusive": 30.0,
        "classificationRule": (
            "Apply the unchanged V1 period-identification and period-complete "
            "drag-statistic gates to the preregistered 10-through-30 convective-time "
            "interval. A complete pass authorizes D20 planning only. Failure does "
            "not change any method, collision, correction, or refinement threshold."
        ),
        "d20PlanningAuthorizedOnPass": True,
        "productionModificationAuthorized": False,
        "rr3BirdReplayPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This archive-only gate can identify the dominant D=8 stationary-sphere "
            "RR3 shedding period and estimate its mean drag from complete-period "
            "blocks over convective times 10 through 30. It cannot establish spatial "
            "convergence, validate D20, promote RR3 into flapping or measured-bird "
            "replay, establish experimental agreement, or support a biological claim."
        ),
        "passed": True,
    }
    for field in LOCKED_METHOD_FIELDS:
        artifact[field] = v1_prereg[field]

    OUTPUT.write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

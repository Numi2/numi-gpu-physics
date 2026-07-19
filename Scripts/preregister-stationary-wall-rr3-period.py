#!/usr/bin/env python3
"""Freeze the D=8 RR3 shedding-period and block-mean decision contract."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
SOURCE = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-duration.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-preregistration.json"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    source = json.loads(SOURCE.read_text(encoding="utf-8"))
    cases = source.get("cases", [])
    diameters = [case["numericalCase"]["diameterCells"] for case in cases]
    if not (
        source.get("schemaVersion") == 1
        and source.get("passed")
        and source.get("allIndividualGatesPassed")
        and source.get("classification")
        == "stationary-wall-recursive-regularization-duration-sensitivity-unresolved"
        and diameters == [8, 12]
        and len(cases[0]["numericalCase"]["samples"]) == 1000
    ):
        raise SystemExit("locked passing D=8/12 RR3 duration source required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": "stationary-wall-rr3-d8-period-v1",
        "sourceDurationReportSHA256": sha256(SOURCE),
        "sourceDurationClassification": source["classification"],
        "selectedDiameterCells": 8,
        "analysisStartConvectiveTimeInclusive": 2.0,
        "analysisEndConvectiveTimeInclusive": 10.0,
        "detrendingMethod": "ordinary-least-squares constant-plus-linear trend",
        "minimumFrequencyCyclesPerConvectiveTime": 0.25,
        "maximumFrequencyCyclesPerConvectiveTime": 4.0,
        "spectralMethod": (
            "direct real-signal Fourier power on the native uniform sample grid; "
            "refine the largest in-band bin by a three-point parabola in log power"
        ),
        "autocorrelationMethod": (
            "normalized biased autocorrelation of the same detrended samples; "
            "select the strongest positive local maximum inside the frozen period band"
        ),
        "splitHalfMethod": (
            "repeat the identical detrend and in-band Fourier estimator on the first "
            "and second halves of the frozen analysis interval"
        ),
        "minimumDominantToRunnerUpPowerRatio": 1.5,
        "runnerUpExclusionBinsAroundPeak": 1,
        "maximumFourierAutocorrelationPeriodRelativeDifference": 0.20,
        "maximumSplitHalfPeriodRelativeDifference": 0.30,
        "minimumCompletePeriodBlockCount": 3,
        "blockConstruction": (
            "start at the analysis interval lower bound and retain consecutive full "
            "Fourier-period blocks whose upper edge does not exceed the analysis end; "
            "compute time-weighted drag means by piecewise-linear trapezoidal integration"
        ),
        "uncertaintyMethod": (
            "Student-t 95% confidence interval of the complete-period block means"
        ),
        "maximumRelative95ConfidenceHalfWidth": 0.15,
        "maximumFirstHalfSecondHalfBlockMeanRelativeDifference": 0.15,
        "classificationRule": (
            "period-identification passes only when the dominant/runner-up power, "
            "Fourier/autocorrelation agreement, and split-half agreement gates pass. "
            "The period-complete drag statistic additionally requires at least three "
            "full blocks, a relative 95% confidence half-width no larger than 15%, "
            "and first-half/second-half block means within 15%. A complete pass "
            "authorizes D20 planning only. Failure requests a longer D8 archive and "
            "does not change any collision, correction, or refinement threshold."
        ),
        "d20PlanningAuthorizedOnPass": True,
        "productionModificationAuthorized": False,
        "rr3BirdReplayPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This archive-only gate can identify the dominant D=8 stationary-sphere "
            "RR3 shedding period and estimate its mean drag from complete-period "
            "blocks over convective times 2 through 10. It cannot establish spatial "
            "convergence, validate D20, promote RR3 into flapping or measured-bird "
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

#!/usr/bin/env python3
"""Freeze the D=8 full-force multimode discriminator after both period stops."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
EXTENSION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-extension.json"
)
V2_PREREGISTRATION = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-v2-preregistration.json"
)
V2_RESULT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-period-v2.json"
)
OUTPUT = (
    ARTIFACTS
    / "measured-wing-stationary-wall-recursive-regularization-d8-multimode-preregistration.json"
)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    extension = json.loads(EXTENSION.read_text(encoding="utf-8"))
    v2 = json.loads(V2_RESULT.read_text(encoding="utf-8"))
    if not (
        extension.get("passed")
        and extension.get("allIndividualGatesPassed")
        and v2.get("passed")
        and not v2.get("periodIdentificationPassed")
        and v2.get("classification") == "d8-shedding-period-unresolved"
        and v2.get("sourceExtensionReportSHA256") == sha256(EXTENSION)
        and v2.get("sourcePreregistrationSHA256")
        == sha256(V2_PREREGISTRATION)
    ):
        raise SystemExit("retained V2 D=8 period-identification stop required")

    artifact = {
        "schemaVersion": 1,
        "preregistrationIdentifier": "stationary-wall-rr3-d8-multimode-v1",
        "sourceExtensionReportSHA256": sha256(EXTENSION),
        "sourcePeriodV2PreregistrationSHA256": sha256(V2_PREREGISTRATION),
        "sourcePeriodV2ResultSHA256": sha256(V2_RESULT),
        "literatureBasis": [
            {
                "citation": "Sakamoto and Haniu, Journal of Fluids Engineering 112 (1990) 386-392",
                "doi": "10.1115/1.2909415",
                "lockedObservation": (
                    "higher and lower sphere-wake frequency modes coexist for "
                    "Reynolds numbers from 800 through 15000"
                ),
            },
            {
                "citation": "Rodriguez et al., Computers and Fluids 80 (2013) 233-243",
                "doi": "10.1016/j.compfluid.2012.03.009",
                "lockedObservation": (
                    "Re=10000 references place the low vortex-shedding mode near "
                    "St=0.195 and the separated-shear-layer mode near St=1.7 to 2.3"
                ),
            },
        ],
        "selectedDiameterCells": 8,
        "requestedConvectiveTimes": 30,
        "requestedSteps": 3000,
        "analysisStartConvectiveTimeInclusive": 10.0,
        "analysisEndConvectiveTimeInclusive": 30.0,
        "requiredCapture": (
            "archive native drag, y-force, and z-force coefficients at every step; "
            "retain every unchanged numerical and accounting gate"
        ),
        "detrendingMethod": "ordinary-least-squares constant-plus-linear trend",
        "spectralMethod": (
            "direct real-signal Fourier power on the native uniform sample grid; "
            "sum y-force and z-force powers to form a rotation-invariant transverse "
            "spectrum; refine each band maximum by a three-point parabola in log power"
        ),
        "lowModeFrequencyBandCyclesPerConvectiveTimeInclusive": [0.12, 0.28],
        "dragHarmonicFrequencyBandCyclesPerConvectiveTimeInclusive": [0.24, 0.56],
        "shearLayerFrequencyBandCyclesPerConvectiveTimeInclusive": [1.4, 2.6],
        "minimumLowModeDominantToRunnerUpPowerRatio": 1.5,
        "runnerUpExclusionBinsAroundPeak": 1,
        "maximumLowModeSplitHalfFrequencyRelativeDifference": 0.30,
        "maximumDragToTwiceLowModeFrequencyRelativeDifference": 0.30,
        "minimumCompleteLowModeBlockCount": 3,
        "blockConstruction": (
            "start at convective time 10 and retain consecutive full low-mode periods "
            "whose upper edge does not exceed 30; compute time-weighted drag means by "
            "piecewise-linear trapezoidal integration"
        ),
        "uncertaintyMethod": (
            "Student-t 95% confidence interval of complete low-mode-period drag means"
        ),
        "maximumRelative95ConfidenceHalfWidth": 0.15,
        "maximumFirstHalfSecondHalfBlockMeanRelativeDifference": 0.15,
        "classificationRule": (
            "Accept the low wake mode only if the rotation-invariant transverse "
            "spectrum clears dominance and split-half gates and the drag-band maximum "
            "is consistent with twice its frequency. Accept the period-complete drag "
            "statistic only if at least three low-mode blocks also clear the unchanged "
            "15% confidence and early/late gates. Report shear-layer-band power as a "
            "separate observed or unresolved mode; never force the multimode trace "
            "through the failed V1 autocorrelation rule. A complete pass authorizes "
            "D20 planning only."
        ),
        "d20PlanningAuthorizedOnPass": True,
        "productionModificationAuthorized": False,
        "rr3BirdReplayPromotionAuthorized": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This test can determine whether the D=8 force history resolves the "
            "documented low sphere-wake mode separately from a drag harmonic and a "
            "higher-frequency band, and can estimate mean drag in complete low-mode "
            "blocks. It cannot establish spatial convergence, validate D20, promote "
            "RR3 into bird replay, establish experimental agreement, or support a "
            "biological claim."
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

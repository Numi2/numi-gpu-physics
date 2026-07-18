#!/usr/bin/env python3
"""Independent audit for the streamwise formation-wake localizer."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-streamwise-attenuation-localizer-v1.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-streamwise-attenuation/formation-flight-streamwise-attenuation-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-streamwise-attenuation/formation-flight-streamwise-attenuation-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(lhs: float, rhs: float) -> bool:
    return math.isclose(lhs, rhs, rel_tol=1e-10, abs_tol=1e-10)


def main() -> int:
    prereg, summary = load(PREREG), load(SUMMARY)
    checks: list[dict] = []

    def check(name: str, passed: bool, evidence: object) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    check("preregistered before analysis", prereg["preregisteredBeforeAnalysis"] is True, prereg["preregisteredBeforeAnalysis"])
    for locked in prereg["lockedInputs"]:
        actual = digest(ROOT / locked["path"])
        check(f"locked input hash: {locked['path']}", actual == locked["sha256"], actual)
    check("preregistration hash parity", summary["preregistration"]["sha256"] == digest(PREREG), digest(PREREG))
    check("five exact phases", [item["targetFollowerPhase"] for item in summary["phaseResults"]] == prereg["followerLocalPhases"], [item["targetFollowerPhase"] for item in summary["phaseResults"]])
    check("three exact bands", [item["band"] for item in summary["aggregateBands"]] == [item["name"] for item in prereg["streamwiseBands"]], [item["band"] for item in summary["aggregateBands"]])

    for phase in summary["phaseResults"]:
        for prefix in ("trt16", "rr316", "trt20"):
            path = ROOT / phase[f"{prefix}SlicePath"]
            actual = digest(path)
            check(f"slice hash {prefix} phase {phase['targetFollowerPhase']}", actual == phase[f"{prefix}SliceSHA256"], actual)
        check(f"band order phase {phase['targetFollowerPhase']}", [item["band"] for item in phase["bands"]] == [item["name"] for item in prereg["streamwiseBands"]], [item["band"] for item in phase["bands"]])
        for band in phase["bands"]:
            check(f"positive support {phase['targetFollowerPhase']} {band['band']}", band["validCellCount"] > 0, band["validCellCount"])
            check(f"TRT density arithmetic {phase['targetFollowerPhase']} {band['band']}", close(band["trtResidualDensity"], band["trtResidualEnergy"] / band["validCellCount"]), band["trtResidualDensity"])
            check(f"RR3 density arithmetic {phase['targetFollowerPhase']} {band['band']}", close(band["rr3ResidualDensity"], band["rr3ResidualEnergy"] / band["validCellCount"]), band["rr3ResidualDensity"])

    for index, aggregate in enumerate(summary["aggregateBands"]):
        phases = [item["bands"][index] for item in summary["phaseResults"]]
        cells = sum(item["validCellCount"] for item in phases)
        trt = sum(item["trtResidualEnergy"] for item in phases)
        rr3 = sum(item["rr3ResidualEnergy"] for item in phases)
        check(f"aggregate cells {aggregate['band']}", aggregate["validCellSamples"] == cells, cells)
        check(f"aggregate TRT energy {aggregate['band']}", close(aggregate["trtResidualEnergy"], trt), trt)
        check(f"aggregate RR3 energy {aggregate['band']}", close(aggregate["rr3ResidualEnergy"], rr3), rr3)
        check(f"aggregate TRT density {aggregate['band']}", close(aggregate["trtResidualDensity"], trt / cells), trt / cells)
        check(f"aggregate RR3 density {aggregate['band']}", close(aggregate["rr3ResidualDensity"], rr3 / cells), rr3 / cells)

    ratio = summary["aggregateBands"][2]["trtResidualDensity"] / summary["aggregateBands"][0]["trtResidualDensity"]
    check("downstream ratio arithmetic", close(summary["downstreamToUpstreamTRTResidualDensityRatio"], ratio), ratio)
    rule = prereg["decisionRule"]
    if ratio >= rule["downstreamToUpstreamResidualDensityRatioAtLeastForTransportDominated"]:
        expected, action = "downstreamAttenuationDominated", rule["ifTransportDominated"]
    elif ratio <= rule["downstreamToUpstreamResidualDensityRatioAtMostForSourceDominated"]:
        expected, action = "sourceAmplitudeDominated", rule["ifSourceDominated"]
    else:
        expected, action = "mixedSourceTransport", rule["ifMixed"]
    check("classification arithmetic", summary["classification"] == expected, expected)
    check("next action arithmetic", summary["nextAction"] == action, action)
    check("no new CFD", summary["newFluidSimulationRequired"] is False, summary["newFluidSimulationRequired"])
    check("production unchanged", summary["productionSolverChanged"] is False, summary["productionSolverChanged"])
    check("quantitative claim closed", summary["quantitativeFormationClaimAuthorized"] is False, summary["quantitativeFormationClaimAuthorized"])

    passed = all(item["passed"] for item in checks)
    result = {
        "schemaVersion": 1,
        "summaryPath": str(SUMMARY.relative_to(ROOT)),
        "summarySHA256": digest(SUMMARY),
        "preregistrationPath": str(PREREG.relative_to(ROOT)),
        "preregistrationSHA256": digest(PREREG),
        "checksPassed": sum(item["passed"] for item in checks),
        "checkCount": len(checks),
        "checks": checks,
        "passed": passed,
    }
    AUDIT.parent.mkdir(parents=True, exist_ok=True)
    AUDIT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(f"formation streamwise attenuation audit: {result['checksPassed']}/{result['checkCount']} checks passed")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

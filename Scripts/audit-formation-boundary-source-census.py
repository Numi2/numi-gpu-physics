#!/usr/bin/env python3
"""Independent arithmetic and provenance audit for the boundary-source census."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-boundary-source-census-v1.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-boundary-source-census/formation-flight-boundary-source-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-boundary-source-census/formation-flight-boundary-source-audit.json"
COMPONENTS = ("reflectedMomentumExchange", "interpolationAuxiliary", "movingWall")


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(lhs: float, rhs: float, tolerance: float = 1e-10) -> bool:
    return math.isclose(lhs, rhs, rel_tol=tolerance, abs_tol=tolerance)


def weighted_l1(values: np.ndarray, directions: np.ndarray) -> float:
    return float(np.sum(np.abs(values) * np.linalg.norm(directions, axis=1)))


def expected_classification(sampling: float, amplitude: float, shares: dict[str, float], threshold: float) -> str:
    if sampling >= threshold:
        return "directionalLinkSamplingDominated"
    if amplitude < threshold:
        return "mixedLinkSamplingAndPopulationAmplitude"
    dominant = max(COMPONENTS, key=shares.get)
    if shares[dominant] < threshold:
        return "mixedPerLinkPopulationAmplitude"
    return {
        "reflectedMomentumExchange": "reflectedPopulationAmplitudeDominated",
        "interpolationAuxiliary": "interpolationAuxiliaryAmplitudeDominated",
        "movingWall": "movingWallAmplitudeDominated",
    }[dominant]


def main() -> int:
    prereg, summary = load(PREREG), load(SUMMARY)
    checks: list[dict] = []

    def check(name: str, passed: bool, evidence: object) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    check("preregistered before CFD execution", prereg["preregisteredBeforeBoundarySourceReplayExecution"] is True, prereg["preregisteredBeforeBoundarySourceReplayExecution"])
    for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
        for item in prereg[group]:
            actual = digest(ROOT / item["path"])
            check(f"{group} hash {item['path']}", actual == item["sha256"], actual)
    amendment = prereg["qualificationAmendment"]
    check("amendment precedes discriminating runs", amendment["amendedBeforeC16OrC20DiscriminatingReplay"] is True, amendment["amendedBeforeC16OrC20DiscriminatingReplay"])
    check("failed smoke excluded", amendment["failedSmokeExcludedFromDecision"] is True, amendment["failedSmokeExcludedFromDecision"])
    for item in amendment["failedSmokeArtifacts"]:
        actual = digest(ROOT / item["path"])
        check(f"failed smoke evidence hash {item['path']}", actual == item["sha256"], actual)
    check("summary preregistration hash", summary["preregistration"]["sha256"] == digest(PREREG), digest(PREREG))
    check("four preregistered probes", len(summary["probeResults"]) == 4, len(summary["probeResults"]))

    cases: dict[int, dict] = {}
    for resolution in (16, 20):
        inputs = summary["inputs"][f"c{resolution}"]
        for kind in ("replay", "census", "reference"):
            path = ROOT / inputs[f"{kind}Path"]
            actual = digest(path)
            check(f"c{resolution} {kind} hash", actual == inputs[f"{kind}SHA256"], actual)
        replay = load(ROOT / inputs["replayPath"])
        census = load(ROOT / inputs["censusPath"])
        cases[resolution] = {"replay": replay, "census": census}
        check(f"c{resolution} replay passed", replay["gates"]["passed"] is True, replay["gates"]["passed"])
        check(f"c{resolution} census passed", census["passed"] is True, census["passed"])
        check(f"c{resolution} census finite", census["finite"] is True, census["finite"])
        check(f"c{resolution} branch closure", census["branchCountClosurePassed"] is True, census["branchCountClosurePassed"])
        check(f"c{resolution} sample count", len(census["samples"]) == 4 == replay["capturedBoundarySourceCensusSampleCount"], len(census["samples"]))
        check(f"c{resolution} exact history", replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] <= prereg["gates"]["maximumRelativeReferenceCoupledHistoryDifference"], replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"])
        check(f"c{resolution} source closure", census["maximumRelativeReconstructionClosureResidual"] <= prereg["gates"]["maximumRelativePopulationReconstructionClosureResidual"], census["maximumRelativeReconstructionClosureResidual"])

    probes = [prereg["selectedProbes"]["primary"], *prereg["selectedProbes"]["secondary"]]
    threshold = prereg["decisionRule"]["dominanceThreshold"]
    recomputed_classifications = []
    for probe_index, (probe, result) in enumerate(zip(probes, summary["probeResults"])):
        label = f"probe {probe_index} {probe['flyer']} phase {probe['followerPhase']}"
        check(f"{label} identity", result["flyer"] == probe["flyer"] and close(result["targetLeaderPhase"], probe["leaderPhase"]) and close(result["targetFollowerPhase"], probe["followerPhase"]), result["flyer"])
        raw: dict[int, dict] = {}
        for resolution in (16, 20):
            tolerance = 0.51 / cases[resolution]["replay"]["cycleSteps"]
            matches = [sample for sample in cases[resolution]["census"]["samples"] if sample["flyer"] == probe["flyer"] and abs(sample["leaderPhase"] - probe["leaderPhase"]) <= tolerance]
            check(f"{label} unique c{resolution} sample", len(matches) == 1, len(matches))
            if len(matches) != 1:
                continue
            sample = matches[0]
            records = sorted(sample["directions"], key=lambda row: row["directionIndex"])
            check(f"{label} c{resolution} complete D3Q19", [row["directionIndex"] for row in records] == list(range(19)), len(records))
            directions = np.asarray([row["direction"] for row in records], dtype=float)
            counts = np.asarray([row["linkCount"] for row in records], dtype=float)
            raw_reflected = np.asarray([row["rawReflectedPopulationSum"] for row in records])
            reflected_in = np.asarray([row["reflectedIncomingPopulationSum"] for row in records])
            interpolation = np.asarray([row["interpolationAuxiliaryPopulationSum"] for row in records])
            wall = np.asarray([row["movingWallPopulationSum"] for row in records])
            incoming = np.asarray([row["reconstructedIncomingPopulationSum"] for row in records])
            reconstruction = reflected_in + interpolation + wall
            check(f"{label} c{resolution} incoming reconstruction", bool(np.allclose(incoming, reconstruction, rtol=2e-6, atol=2e-6)), float(np.max(np.abs(incoming - reconstruction))))
            branch = np.asarray([row["nearInterpolationLinkCount"] + row["farInterpolationLinkCount"] + row["halfwayFallbackLinkCount"] for row in records])
            check(f"{label} c{resolution} direction branch counts", bool(np.array_equal(counts.astype(int), branch)), int(np.max(np.abs(counts - branch))))
            components = {
                "reflectedMomentumExchange": raw_reflected + reflected_in,
                "interpolationAuxiliary": interpolation,
                "movingWall": wall,
            }
            total = raw_reflected + incoming
            check(f"{label} c{resolution} momentum component sum", bool(np.allclose(total, sum(components.values()), rtol=2e-6, atol=2e-6)), float(np.max(np.abs(total - sum(components.values())))))
            support = counts > 0
            means = np.divide(total, counts, out=np.zeros(19), where=support)
            areal = counts / float(resolution * resolution)
            probability = counts / np.sum(counts)
            raw[resolution] = {
                "directions": directions,
                "counts": counts,
                "means": means,
                "areal": areal,
                "probability": probability,
                "profile": areal * means,
                "componentMeans": {name: np.divide(values, counts, out=np.zeros(19), where=support) for name, values in components.items()},
            }
            check(f"{label} c{resolution} total links", result["totalBoundaryLinks"][f"c{resolution}"] == int(np.sum(counts)), int(np.sum(counts)))
            check(f"{label} c{resolution} link density", close(result["boundaryLinkDensityPerChordSquared"][f"c{resolution}"], float(np.sum(areal))), float(np.sum(areal)))
        if len(raw) != 2:
            continue
        directions = raw[16]["directions"]
        a16, a20 = raw[16]["areal"], raw[20]["areal"]
        m16, m20 = raw[16]["means"], raw[20]["means"]
        delta = raw[20]["profile"] - raw[16]["profile"]
        sampling = 0.5 * (a20 - a16) * (m20 + m16)
        amplitude = 0.5 * (m20 - m16) * (a20 + a16)
        residual = delta - sampling - amplitude
        check(f"{label} exact symmetric identity", close(result["maximumAbsoluteSymmetricIdentityResidual"], float(np.max(np.abs(residual)))), float(np.max(np.abs(residual))))
        component_amplitude = {name: 0.5 * (raw[20]["componentMeans"][name] - raw[16]["componentMeans"][name]) * (a20 + a16) for name in COMPONENTS}
        component_residual = amplitude - sum(component_amplitude.values())
        check(f"{label} amplitude component identity", close(result["maximumAbsoluteAmplitudeComponentResidual"], float(np.max(np.abs(component_residual)))), float(np.max(np.abs(component_residual))))
        sampling_l1, amplitude_l1 = weighted_l1(sampling, directions), weighted_l1(amplitude, directions)
        denominator = sampling_l1 + amplitude_l1
        sampling_share = sampling_l1 / denominator if denominator > 0 else 0.0
        amplitude_share = amplitude_l1 / denominator if denominator > 0 else 0.0
        check(f"{label} sampling L1", close(result["topLevelWeightedL1"]["linkSampling"], sampling_l1), sampling_l1)
        check(f"{label} amplitude L1", close(result["topLevelWeightedL1"]["conditionalAmplitude"], amplitude_l1), amplitude_l1)
        check(f"{label} sampling share", close(result["topLevelAttributionFraction"]["linkSampling"], sampling_share), sampling_share)
        check(f"{label} amplitude share", close(result["topLevelAttributionFraction"]["conditionalAmplitude"], amplitude_share), amplitude_share)
        component_l1 = {name: weighted_l1(values, directions) for name, values in component_amplitude.items()}
        component_total = sum(component_l1.values())
        component_shares = {name: value / component_total if component_total > 0 else 0.0 for name, value in component_l1.items()}
        for name in COMPONENTS:
            check(f"{label} {name} L1", close(result["conditionalAmplitudeComponentWeightedL1"][name], component_l1[name]), component_l1[name])
            check(f"{label} {name} share", close(result["conditionalAmplitudeComponentAttributionFraction"][name], component_shares[name]), component_shares[name])
        tv = 0.5 * float(np.sum(np.abs(raw[20]["probability"] - raw[16]["probability"])))
        check(f"{label} direction TV", close(result["directionDistributionTotalVariation"], tv), tv)
        expected = expected_classification(sampling_share, amplitude_share, component_shares, threshold)
        recomputed_classifications.append(expected)
        check(f"{label} classification", result["classification"] == expected, expected)
        for q, row in enumerate(result["directions"]):
            check(f"{label} q{q} delta", close(row["profileDifferenceC20MinusC16"], float(delta[q])), float(delta[q]))
            check(f"{label} q{q} identity", close(row["identityResidual"], float(residual[q])), float(residual[q]))

    check("primary classification", bool(recomputed_classifications) and summary["primaryClassification"] == recomputed_classifications[0], recomputed_classifications[0] if recomputed_classifications else None)
    next_key = {
        "directionalLinkSamplingDominated": "nextIfDirectionalLinkSamplingDominated",
        "reflectedPopulationAmplitudeDominated": "nextIfReflectedPopulationDominated",
        "interpolationAuxiliaryAmplitudeDominated": "nextIfInterpolationAuxiliaryDominated",
        "movingWallAmplitudeDominated": "nextIfMovingWallAmplitudeDominated",
        "mixedPerLinkPopulationAmplitude": "nextIfMixedPerLinkPopulationAmplitude",
        "mixedLinkSamplingAndPopulationAmplitude": "nextIfMixedLinkSamplingAndPopulationAmplitude",
    }.get(summary["primaryClassification"])
    check("next action follows frozen rule", next_key is not None and summary["nextAction"] == prereg["decisionRule"][next_key], summary["nextAction"])
    check("production unchanged", summary["productionSolverChanged"] is False, summary["productionSolverChanged"])
    check("quantitative claim closed", summary["quantitativeFormationClaimAuthorized"] is False, summary["quantitativeFormationClaimAuthorized"])
    check("new CFD disclosed", summary["newFluidSimulationRequired"] is True, summary["newFluidSimulationRequired"])
    check("analysis passed", summary["passed"] is True, summary["passed"])
    for relative in [summary["csvPath"], *summary["figurePaths"]]:
        path = ROOT / relative
        check(f"artifact exists {relative}", path.exists() and path.stat().st_size > 0, path.stat().st_size if path.exists() else 0)

    passed = all(item["passed"] for item in checks)
    output = {
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
    AUDIT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(f"formation boundary-source audit: {output['checksPassed']}/{output['checkCount']} checks passed")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

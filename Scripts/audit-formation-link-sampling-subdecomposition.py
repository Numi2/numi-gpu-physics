#!/usr/bin/env python3
"""Independent audit of the link-density versus direction subdecomposition."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-link-sampling-subdecomposition-v1.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-link-sampling-subdecomposition/formation-flight-link-sampling-subdecomposition-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-link-sampling-subdecomposition/formation-flight-link-sampling-subdecomposition-audit.json"
RAW = {
    16: ROOT / "ValidationArtifacts/formation-flight-boundary-source-census/c16-best-z3-phase025/formation-flight-boundary-source-census.json",
    20: ROOT / "ValidationArtifacts/formation-flight-boundary-source-census/c20-best-z3-phase025/formation-flight-boundary-source-census.json",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(lhs: float, rhs: float) -> bool:
    return math.isclose(lhs, rhs, rel_tol=1e-10, abs_tol=1e-10)


def weighted_l1(values: np.ndarray, directions: np.ndarray) -> float:
    return float(np.sum(np.abs(values) * np.linalg.norm(directions, axis=1)))


def classify(density: float, direction: float, threshold: float) -> str:
    if density >= threshold:
        return "arealLinkDensityDominated"
    if direction >= threshold:
        return "directionRedistributionDominated"
    return "mixedDensityAndDirection"


def main() -> int:
    prereg, summary = load(PREREG), load(SUMMARY)
    raw = {resolution: load(path) for resolution, path in RAW.items()}
    checks: list[dict] = []

    def check(name: str, passed: bool, evidence: object) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    check("preregistered before execution", prereg["preregisteredBeforeSubdecompositionExecution"] is True, prereg["preregisteredBeforeSubdecompositionExecution"])
    for group in ("lockedInputs", "lockedAnalysis"):
        for item in prereg[group]:
            actual = digest(ROOT / item["path"])
            check(f"{group} hash {item['path']}", actual == item["sha256"], actual)
    check("summary preregistration hash", summary["preregistration"]["sha256"] == digest(PREREG), digest(PREREG))
    check("parent audit passed", load(ROOT / summary["parentAudit"]["path"])["passed"] is True, summary["parentAudit"]["path"])
    check("four probe results", len(summary["probeResults"]) == 4, len(summary["probeResults"]))

    threshold = prereg["decisionRule"]["dominanceThreshold"]
    classifications = []
    for result_index, result in enumerate(summary["probeResults"]):
        label = f"probe {result_index} {result['flyer']} phase {result['targetFollowerPhase']}"
        samples = {}
        for resolution in (16, 20):
            matches = [sample for sample in raw[resolution]["samples"] if sample["flyer"] == result["flyer"] and abs(sample["leaderPhase"] - result["targetLeaderPhase"]) < 0.001]
            check(f"{label} unique c{resolution} sample", len(matches) == 1, len(matches))
            if len(matches) == 1:
                samples[resolution] = matches[0]
        if len(samples) != 2:
            continue
        arrays = {}
        for resolution in (16, 20):
            records = sorted(samples[resolution]["directions"], key=lambda row: row["directionIndex"])
            directions = np.asarray([row["direction"] for row in records], dtype=float)
            counts = np.asarray([row["linkCount"] for row in records], dtype=float)
            population = np.asarray([row["rawReflectedPopulationSum"] + row["reconstructedIncomingPopulationSum"] for row in records])
            support = counts > 0
            means = np.divide(population, counts, out=np.zeros(19), where=support)
            density = float(np.sum(counts)) / (resolution * resolution)
            probability = counts / np.sum(counts)
            areal = counts / (resolution * resolution)
            arrays[resolution] = {"directions": directions, "means": means, "density": density, "probability": probability, "areal": areal}
            check(f"{label} c{resolution} density", close(result["arealLinkDensityPerChordSquared"][f"c{resolution}"], density), density)
        directions = arrays[16]["directions"]
        d16, d20 = arrays[16]["density"], arrays[20]["density"]
        p16, p20 = arrays[16]["probability"], arrays[20]["probability"]
        m16, m20 = arrays[16]["means"], arrays[20]["means"]
        parent = 0.5 * (arrays[20]["areal"] - arrays[16]["areal"]) * (m20 + m16)
        density_term = 0.25 * (d20 - d16) * (p20 + p16) * (m20 + m16)
        direction_term = 0.25 * (p20 - p16) * (d20 + d16) * (m20 + m16)
        residual = parent - density_term - direction_term
        maximum = float(np.max(np.abs(residual)))
        check(f"{label} exact identity residual", close(result["maximumAbsoluteIdentityResidual"], maximum), maximum)
        density_l1 = weighted_l1(density_term, directions)
        direction_l1 = weighted_l1(direction_term, directions)
        denominator = density_l1 + direction_l1
        density_share = density_l1 / denominator if denominator else 0.0
        direction_share = direction_l1 / denominator if denominator else 0.0
        check(f"{label} density L1", close(result["weightedL1"]["arealLinkDensity"], density_l1), density_l1)
        check(f"{label} direction L1", close(result["weightedL1"]["directionRedistribution"], direction_l1), direction_l1)
        check(f"{label} density share", close(result["attributionFraction"]["arealLinkDensity"], density_share), density_share)
        check(f"{label} direction share", close(result["attributionFraction"]["directionRedistribution"], direction_share), direction_share)
        relative_density = d20 / d16 - 1
        check(f"{label} relative density change", close(result["relativeArealLinkDensityChangeC20FromC16"], relative_density), relative_density)
        expected = classify(density_share, direction_share, threshold)
        classifications.append(expected)
        check(f"{label} classification", result["classification"] == expected, expected)
        for q, row in enumerate(result["directions"]):
            check(f"{label} q{q} probability c16", close(row["c16DirectionProbability"], float(p16[q])), float(p16[q]))
            check(f"{label} q{q} probability c20", close(row["c20DirectionProbability"], float(p20[q])), float(p20[q]))
            check(f"{label} q{q} parent", close(row["parentLinkSamplingTerm"], float(parent[q])), float(parent[q]))
            check(f"{label} q{q} density", close(row["arealLinkDensityTerm"], float(density_term[q])), float(density_term[q]))
            check(f"{label} q{q} direction", close(row["directionRedistributionTerm"], float(direction_term[q])), float(direction_term[q]))
            check(f"{label} q{q} residual", close(row["identityResidual"], float(residual[q])), float(residual[q]))

    check("primary classification", bool(classifications) and summary["primaryClassification"] == classifications[0], classifications[0] if classifications else None)
    next_key = {
        "arealLinkDensityDominated": "nextIfArealLinkDensityDominated",
        "directionRedistributionDominated": "nextIfDirectionRedistributionDominated",
        "mixedDensityAndDirection": "nextIfMixedDensityAndDirection",
    }.get(summary["primaryClassification"])
    check("next action follows preregistration", next_key is not None and summary["nextAction"] == prereg["decisionRule"][next_key], summary["nextAction"])
    check("no new CFD", summary["newFluidSimulationRequired"] is False, summary["newFluidSimulationRequired"])
    check("production unchanged", summary["productionSolverChanged"] is False, summary["productionSolverChanged"])
    check("quantitative claim closed", summary["quantitativeFormationClaimAuthorized"] is False, summary["quantitativeFormationClaimAuthorized"])
    check("summary passed", summary["passed"] is True, summary["passed"])
    for relative in [summary["csvPath"], *summary["figurePaths"]]:
        path = ROOT / relative
        check(f"artifact exists {relative}", path.exists() and path.stat().st_size > 0, path.stat().st_size if path.exists() else 0)

    passed = all(row["passed"] for row in checks)
    output = {
        "schemaVersion": 1,
        "summaryPath": str(SUMMARY.relative_to(ROOT)),
        "summarySHA256": digest(SUMMARY),
        "preregistrationPath": str(PREREG.relative_to(ROOT)),
        "preregistrationSHA256": digest(PREREG),
        "checksPassed": sum(row["passed"] for row in checks),
        "checkCount": len(checks),
        "checks": checks,
        "passed": passed,
    }
    AUDIT.parent.mkdir(parents=True, exist_ok=True)
    AUDIT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(f"formation link-sampling subdecomposition audit: {output['checksPassed']}/{output['checkCount']} checks passed")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
"""Independent arithmetic and provenance audit for alternate source phase 2."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-subcell-source-offset2-v1.json"
SELECTION = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset2/formation-flight-subcell-source-offset2-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset2/formation-flight-subcell-source-offset2-audit.json"
PARENT_SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-summary.json"
PARENT_AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-audit.json"
RESOLUTIONS = (16, 18, 20)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(a: float, b: float, tolerance: float = 1e-10) -> bool:
    return math.isclose(a, b, rel_tol=tolerance, abs_tol=tolerance)


prereg, selection, summary = load(PREREG), load(SELECTION), load(SUMMARY)
parent_summary, parent_audit = load(PARENT_SUMMARY), load(PARENT_AUDIT)
checks: list[dict] = []


def check(name: str, passed: bool, evidence: object) -> None:
    checks.append({"name": name, "passed": bool(passed), "evidence": evidence})


check("preregistered before alternate CFD", prereg["preregisteredBeforeTranslatedCFD"] is True, prereg["preregisteredAtUTC"])
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"{group} hash {item['path']}", actual == item["sha256"], actual)
check("parent summary passed", parent_summary["passed"] is True, parent_summary["classification"])
check("parent audit passed", parent_audit["passed"] is True, f"{parent_audit['checksPassed']}/{parent_audit['checkCount']}")

rank = int(prereg["selectionRule"]["zeroBasedRank"])
candidate = selection["topEightCandidates"][rank]
offset = candidate["offsetCells"]
check("candidate rank is second", rank == 1, rank)
check("candidate offset frozen", offset == prereg["lockedConfiguration"]["subcellOffsetCells"], offset)
check("candidate score preserved", close(candidate["selectionScore"], summary["selection"]["selectionScore"]), candidate["selectionScore"])


def profiles_for(summary_inputs: dict, expected_offset: list[float]) -> tuple[dict, dict, np.ndarray]:
    profiles = {name: {} for name in ("areal", "conditional", "source")}
    components = {name: {} for name in ("reflectedMomentumExchange", "interpolationAuxiliary", "movingWall")}
    weights = np.zeros(19)
    for resolution in RESOLUTIONS:
        inputs = summary_inputs[f"c{resolution}"]
        for kind in ("report", "census"):
            path = ROOT / inputs[f"{kind}Path"]
            actual = digest(path)
            check(f"c{resolution} {kind} hash", actual == inputs[f"{kind}SHA256"], actual)
        report = load(ROOT / inputs["reportPath"])
        census = load(ROOT / inputs["censusPath"])
        check(f"c{resolution} report passed", report["gates"]["passed"] is True, report["gates"])
        check(f"c{resolution} census passed", census["passed"] is True, census["maximumRelativeReconstructionClosureResidual"])
        check(f"c{resolution} common offset", report["subcellOffsetCells"] == expected_offset, report["subcellOffsetCells"])
        phase_tolerance = 0.51 / report["cycleSteps"]
        check(f"c{resolution} phase lock", abs(report["actualLeaderPhase"] - prereg["lockedConfiguration"]["leaderPhase"]) <= phase_tolerance, report["actualLeaderPhase"])
        check(f"c{resolution} two owners", sorted(sample["flyer"] for sample in census["samples"]) == ["follower", "leader"], len(census["samples"]))
        sample = next(sample for sample in census["samples"] if sample["flyer"] == "leader")
        records = sorted(sample["directions"], key=lambda row: row["directionIndex"])
        check(f"c{resolution} complete D3Q19", [row["directionIndex"] for row in records] == list(range(19)), len(records))
        directions = np.asarray([row["direction"] for row in records], dtype=float)
        weights = np.linalg.norm(directions, axis=1)
        counts = np.asarray([row["linkCount"] for row in records], dtype=float)
        branch = np.asarray([row["nearInterpolationLinkCount"] + row["farInterpolationLinkCount"] + row["halfwayFallbackLinkCount"] for row in records], dtype=float)
        check(f"c{resolution} branch closure", bool(np.array_equal(counts, branch)), float(np.max(np.abs(counts - branch))))
        raw_reflected = np.asarray([row["rawReflectedPopulationSum"] for row in records])
        reflected_in = np.asarray([row["reflectedIncomingPopulationSum"] for row in records])
        interpolation = np.asarray([row["interpolationAuxiliaryPopulationSum"] for row in records])
        wall = np.asarray([row["movingWallPopulationSum"] for row in records])
        incoming = np.asarray([row["reconstructedIncomingPopulationSum"] for row in records])
        relative = np.linalg.norm(incoming - reflected_in - interpolation - wall) / max(np.linalg.norm(incoming), 1e-12)
        check(f"c{resolution} independent source reconstruction", relative <= prereg["gates"]["maximumRelativePopulationReconstructionClosureResidual"], relative)
        population = raw_reflected + incoming
        reconstructed = raw_reflected + reflected_in + interpolation + wall
        check(f"c{resolution} component identity", bool(np.allclose(population, reconstructed, rtol=2e-6, atol=2e-6)), float(np.max(np.abs(population - reconstructed))))
        profiles["areal"][resolution] = counts / resolution**2
        profiles["conditional"][resolution] = np.divide(population, counts, out=np.zeros(19), where=counts > 0)
        profiles["source"][resolution] = population / resolution**2
        components["reflectedMomentumExchange"][resolution] = (raw_reflected + reflected_in) / resolution**2
        components["interpolationAuxiliary"][resolution] = interpolation / resolution**2
        components["movingWall"][resolution] = wall / resolution**2
    return profiles, components, weights


profiles, components, weights = profiles_for(summary["inputs"], offset)
parent_profiles, _, parent_weights = profiles_for(parent_summary["inputs"], selection["selected"]["offsetCells"])
check("D3Q19 weights agree across offsets", bool(np.array_equal(weights, parent_weights)), weights.tolist())
t = ((1 / 18) - (1 / 16)) / ((1 / 20) - (1 / 16))
check("interpolation fraction", close(t, summary["c18EndpointInterpolationFraction"]), t)
floor = float(prereg["decisionRule"]["denominatorFloor"])


def curvature(values: dict[int, np.ndarray]) -> float:
    expected = values[16] + t * (values[20] - values[16])
    numerator = float(np.sum(np.abs(values[18] - expected) * weights))
    denominator = max(float(np.sum(np.abs(values[20] - values[16]) * weights)), floor)
    return numerator / denominator


metric_names = {
    "areal": "normalizedArealLinkProfileCurvature",
    "conditional": "normalizedConditionalPopulationCurvature",
    "source": "normalizedPopulationWeightedSourceCurvature",
}
recomputed: dict[str, object] = {}
for profile, metric in metric_names.items():
    value = curvature(profiles[profile])
    recomputed[metric] = value
    check(metric, close(value, summary["decisionMetrics"][metric]), value)
for component, values in components.items():
    value = curvature(values)
    recomputed[component] = value
    check(f"component curvature {component}", close(value, summary["decisionMetrics"]["normalizedComponentCurvatures"][component]), value)

parent_curvatures = {name: curvature(parent_profiles[name]) for name in profiles}
two_offset_curvatures = {
    name: curvature({r: 0.5 * (profiles[name][r] + parent_profiles[name][r]) for r in RESOLUTIONS})
    for name in profiles
}
for name, value in parent_curvatures.items():
    check(f"parent curvature {name}", close(value, summary["decisionMetrics"]["parentCurvatures"][name]), value)
for name, value in two_offset_curvatures.items():
    check(f"two-offset mean curvature {name}", close(value, summary["decisionMetrics"]["twoOffsetMeanCurvatures"][name]), value)

geometry_values = {
    r: np.asarray([candidate["resolutionContributions"][f"c{r}"]["leaderArealLinkDensity"]])
    for r in RESOLUTIONS
}
old_weights = weights
weights = np.ones(1)
geometry_curvature = curvature(geometry_values)
weights = old_weights
check("candidate geometry curvature", close(geometry_curvature, summary["decisionMetrics"]["candidateGeometryDensityCurvature"]), geometry_curvature)

source_curvature = float(recomputed["normalizedPopulationWeightedSourceCurvature"])
if source_curvature <= prereg["decisionRule"]["smoothRefinementMaximumCurvature"]:
    classification = "smoothPopulationWeightedSource"
elif source_curvature >= prereg["decisionRule"]["persistentBiasMinimumCurvature"]:
    classification = "populationWeightedSourceNonAsymptotic"
else:
    classification = "mixedPopulationWeightedSource"
interpretation = "phaseLocalSensitivityDetected" if classification == "smoothPopulationWeightedSource" else "nonsmoothAtBothTestedOffsets"
check("classification", classification == summary["classification"], classification)
check("cross-offset interpretation", interpretation == summary["crossOffsetInterpretation"], interpretation)
check("summary passed", summary["passed"] is True, summary["gates"])
check("figure PNG exists", (ROOT / summary["figurePaths"][0]).is_file(), summary["figurePaths"][0])
check("figure SVG exists", (ROOT / summary["figurePaths"][1]).is_file(), summary["figurePaths"][1])
check("GitHub Actions absent", not (ROOT / ".github").exists(), (ROOT / ".github").exists())

output = {
    "schemaVersion": 1,
    "title": "Formation source alternate-offset independent audit",
    "checks": checks,
    "checkCount": len(checks),
    "checksPassed": sum(item["passed"] for item in checks),
    "recomputedMetrics": recomputed,
    "recomputedParentCurvatures": parent_curvatures,
    "recomputedTwoOffsetMeanCurvatures": two_offset_curvatures,
    "recomputedGeometryCurvature": geometry_curvature,
    "recomputedClassification": classification,
    "recomputedCrossOffsetInterpretation": interpretation,
    "passed": all(item["passed"] for item in checks),
}
AUDIT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
print(f"formation source alternate-offset audit: {output['checksPassed']}/{output['checkCount']} checks passed")
if not output["passed"]:
    for item in checks:
        if not item["passed"]:
            print(f"FAILED: {item['name']}: {item['evidence']}")
    raise SystemExit(1)

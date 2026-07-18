#!/usr/bin/env python3
"""Independent audit of the final source phase and three-offset decision."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-subcell-source-offset3-v1.json"
SELECTION = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset3/formation-flight-subcell-source-three-offset-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset3/formation-flight-subcell-source-three-offset-audit.json"
RESOLUTIONS = (16, 18, 20)
PROFILE_NAMES = ("areal", "conditional", "source")
COMPONENT_NAMES = ("reflectedMomentumExchange", "interpolationAuxiliary", "movingWall")


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(a: float, b: float, tolerance: float = 1e-10) -> bool:
    return math.isclose(a, b, rel_tol=tolerance, abs_tol=tolerance)


prereg, selection, summary = load(PREREG), load(SELECTION), load(SUMMARY)
checks: list[dict] = []


def check(name: str, passed: bool, evidence: object) -> None:
    checks.append({"name": name, "passed": bool(passed), "evidence": evidence})


check("preregistered before final-offset CFD", prereg["preregisteredBeforeTranslatedCFD"] is True, prereg["preregisteredAtUTC"])
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"{group} hash {item['path']}", actual == item["sha256"], actual)

rank = int(prereg["selectionRule"]["zeroBasedRank"])
candidates = [selection["selected"], selection["topEightCandidates"][1], selection["topEightCandidates"][rank]]
check("final candidate rank", rank == 2, rank)
check("final candidate offset", candidates[2]["offsetCells"] == prereg["lockedConfiguration"]["subcellOffsetCells"], candidates[2]["offsetCells"])
check("final candidate score", close(candidates[2]["selectionScore"], prereg["selectionRule"]["expectedSelectionScore"]), candidates[2]["selectionScore"])

for key, item in summary["parentEvidence"].items():
    path = ROOT / item["path"]
    actual = digest(path)
    check(f"parent evidence hash {key}", actual == item["sha256"], actual)
    check(f"parent evidence passed {key}", load(path)["passed"] is True, load(path).get("classification", load(path).get("checksPassed")))

phase_profiles: dict[str, dict] = {}
phase_components: dict[str, dict] = {}
weights = np.zeros(19)
for phase_index, phase_name in enumerate(("offset1", "offset2", "offset3")):
    phase_profiles[phase_name] = {name: {} for name in PROFILE_NAMES}
    phase_components[phase_name] = {name: {} for name in COMPONENT_NAMES}
    expected_offset = candidates[phase_index]["offsetCells"]
    for resolution in RESOLUTIONS:
        inputs = summary["phaseInputs"][phase_name][f"c{resolution}"]
        for kind in ("report", "census"):
            path = ROOT / inputs[f"{kind}Path"]
            actual = digest(path)
            check(f"{phase_name} c{resolution} {kind} hash", actual == inputs[f"{kind}SHA256"], actual)
        report = load(ROOT / inputs["reportPath"])
        census = load(ROOT / inputs["censusPath"])
        check(f"{phase_name} c{resolution} report passed", report["gates"]["passed"] is True, report["gates"])
        check(f"{phase_name} c{resolution} census passed", census["passed"] is True, census["maximumRelativeReconstructionClosureResidual"])
        check(f"{phase_name} c{resolution} offset", report["subcellOffsetCells"] == expected_offset, report["subcellOffsetCells"])
        phase_tolerance = 0.51 / report["cycleSteps"]
        check(f"{phase_name} c{resolution} phase lock", abs(report["actualLeaderPhase"] - prereg["lockedConfiguration"]["leaderPhase"]) <= phase_tolerance, report["actualLeaderPhase"])
        check(f"{phase_name} c{resolution} owners", sorted(sample["flyer"] for sample in census["samples"]) == ["follower", "leader"], len(census["samples"]))
        sample = next(sample for sample in census["samples"] if sample["flyer"] == "leader")
        records = sorted(sample["directions"], key=lambda row: row["directionIndex"])
        check(f"{phase_name} c{resolution} complete D3Q19", [row["directionIndex"] for row in records] == list(range(19)), len(records))
        directions = np.asarray([row["direction"] for row in records], dtype=float)
        weights = np.linalg.norm(directions, axis=1)
        counts = np.asarray([row["linkCount"] for row in records], dtype=float)
        branches = np.asarray([row["nearInterpolationLinkCount"] + row["farInterpolationLinkCount"] + row["halfwayFallbackLinkCount"] for row in records], dtype=float)
        check(f"{phase_name} c{resolution} branch closure", bool(np.array_equal(counts, branches)), float(np.max(np.abs(counts - branches))))
        raw_reflected = np.asarray([row["rawReflectedPopulationSum"] for row in records])
        incoming = np.asarray([row["reconstructedIncomingPopulationSum"] for row in records])
        reflected_in = np.asarray([row["reflectedIncomingPopulationSum"] for row in records])
        interpolation = np.asarray([row["interpolationAuxiliaryPopulationSum"] for row in records])
        wall = np.asarray([row["movingWallPopulationSum"] for row in records])
        closure = reflected_in + interpolation + wall
        relative = np.linalg.norm(incoming - closure) / max(np.linalg.norm(incoming), 1e-12)
        check(f"{phase_name} c{resolution} source reconstruction", relative <= prereg["gates"]["maximumRelativePopulationReconstructionClosureResidual"], relative)
        population = raw_reflected + incoming
        components = raw_reflected + closure
        check(f"{phase_name} c{resolution} component identity", bool(np.allclose(population, components, rtol=2e-6, atol=2e-6)), float(np.max(np.abs(population - components))))
        phase_profiles[phase_name]["areal"][resolution] = counts / resolution**2
        phase_profiles[phase_name]["conditional"][resolution] = np.divide(population, counts, out=np.zeros(19), where=counts > 0)
        phase_profiles[phase_name]["source"][resolution] = population / resolution**2
        phase_components[phase_name]["reflectedMomentumExchange"][resolution] = (raw_reflected + reflected_in) / resolution**2
        phase_components[phase_name]["interpolationAuxiliary"][resolution] = interpolation / resolution**2
        phase_components[phase_name]["movingWall"][resolution] = wall / resolution**2

t = ((1 / 18) - (1 / 16)) / ((1 / 20) - (1 / 16))
check("interpolation fraction", close(t, summary["c18EndpointInterpolationFraction"]), t)
floor = float(prereg["decisionRule"]["denominatorFloor"])


def weighted_l1(values: np.ndarray) -> float:
    return float(np.sum(np.abs(values) * weights))


def curvature(values: dict[int, np.ndarray]) -> float:
    expected = values[16] + t * (values[20] - values[16])
    return weighted_l1(values[18] - expected) / max(weighted_l1(values[20] - values[16]), floor)


phase_curvatures = {phase: {profile: curvature(phase_profiles[phase][profile]) for profile in PROFILE_NAMES} for phase in phase_profiles}
mean_profiles = {profile: {r: np.mean([phase_profiles[phase][profile][r] for phase in phase_profiles], axis=0) for r in RESOLUTIONS} for profile in PROFILE_NAMES}
mean_components = {component: {r: np.mean([phase_components[phase][component][r] for phase in phase_components], axis=0) for r in RESOLUTIONS} for component in COMPONENT_NAMES}
mean_curvatures = {profile: curvature(mean_profiles[profile]) for profile in PROFILE_NAMES}
mean_component_curvatures = {component: curvature(mean_components[component]) for component in COMPONENT_NAMES}

for phase in phase_curvatures:
    for profile, value in phase_curvatures[phase].items():
        check(f"{phase} curvature {profile}", close(value, summary["decisionMetrics"]["individualOffsetCurvatures"][phase][profile]), value)
for profile, value in mean_curvatures.items():
    check(f"three-offset mean curvature {profile}", close(value, summary["decisionMetrics"]["threeOffsetMeanCurvatures"][profile]), value)
for component, value in mean_component_curvatures.items():
    check(f"three-offset mean component {component}", close(value, summary["decisionMetrics"]["threeOffsetMeanComponentCurvatures"][component]), value)


def spread_for(profile: str) -> dict:
    by_resolution = {}
    for resolution in RESOLUTIONS:
        values = [phase_profiles[phase][profile][resolution] for phase in phase_profiles]
        mean = np.mean(values, axis=0)
        denominator = max(weighted_l1(mean), floor)
        deviations = [weighted_l1(value - mean) / denominator for value in values]
        pairs = [weighted_l1(values[i] - values[j]) / denominator for i in range(3) for j in range(i + 1, 3)]
        by_resolution[f"c{resolution}"] = {
            "maximumRelativeDeviationFromMean": max(deviations),
            "maximumRelativePairwiseDifference": max(pairs),
        }
    return {
        "byResolution": by_resolution,
        "maximumRelativeDeviationFromMean": max(v["maximumRelativeDeviationFromMean"] for v in by_resolution.values()),
        "maximumRelativePairwiseDifference": max(v["maximumRelativePairwiseDifference"] for v in by_resolution.values()),
    }


spread = {profile: spread_for(profile) for profile in PROFILE_NAMES}
for profile in PROFILE_NAMES:
    expected = summary["decisionMetrics"]["phaseSpread"][profile]
    check(f"{profile} max phase deviation", close(spread[profile]["maximumRelativeDeviationFromMean"], expected["maximumRelativeDeviationFromMean"]), spread[profile]["maximumRelativeDeviationFromMean"])
    check(f"{profile} max pairwise phase spread", close(spread[profile]["maximumRelativePairwiseDifference"], expected["maximumRelativePairwiseDifference"]), spread[profile]["maximumRelativePairwiseDifference"])
    for resolution in RESOLUTIONS:
        for metric, value in spread[profile]["byResolution"][f"c{resolution}"].items():
            check(f"{profile} c{resolution} {metric}", close(value, expected["byResolution"][f"c{resolution}"][metric]), value)

component_spread = {}
for component in COMPONENT_NAMES:
    by_resolution = {}
    for resolution in RESOLUTIONS:
        values = [phase_components[phase][component][resolution] for phase in phase_components]
        mean = np.mean(values, axis=0)
        denominator = max(weighted_l1(mean), floor)
        by_resolution[f"c{resolution}"] = max(weighted_l1(values[i] - values[j]) / denominator for i in range(3) for j in range(i + 1, 3))
    component_spread[component] = max(by_resolution.values())
    expected = summary["decisionMetrics"]["componentPhaseSpread"][component]
    check(f"component max phase spread {component}", close(component_spread[component], expected["maximumRelativePairwiseDifference"]), component_spread[component])
    for resolution in RESOLUTIONS:
        check(f"component c{resolution} phase spread {component}", close(by_resolution[f"c{resolution}"], expected["maximumRelativePairwiseDifferenceByResolution"][f"c{resolution}"]), by_resolution[f"c{resolution}"])

geometry_by_phase = {}
for index, candidate in enumerate(candidates, start=1):
    values = {r: np.asarray([candidate["resolutionContributions"][f"c{r}"]["leaderArealLinkDensity"]]) for r in RESOLUTIONS}
    old_weights = weights
    weights = np.ones(1)
    value = curvature(values)
    weights = old_weights
    geometry_by_phase[f"offset{index}"] = value
    check(f"offset{index} geometry curvature", close(value, summary["decisionMetrics"]["geometryByPhase"][f"offset{index}"]["curvature"]), value)
mean_geometry = {r: np.asarray([np.mean([candidate["resolutionContributions"][f"c{r}"]["leaderArealLinkDensity"] for candidate in candidates])]) for r in RESOLUTIONS}
old_weights = weights
weights = np.ones(1)
mean_geometry_curvature = curvature(mean_geometry)
weights = old_weights
check("three-offset mean geometry curvature", close(mean_geometry_curvature, summary["decisionMetrics"]["threeOffsetMeanGeometryDensityCurvature"]), mean_geometry_curvature)

primary = mean_curvatures["source"]
source_spread = spread["source"]["maximumRelativePairwiseDifference"]
smooth = primary <= prereg["decisionRule"]["smoothRefinementMaximumCurvature"]
spread_passed = source_spread <= prereg["decisionRule"]["maximumRelativePairwiseSourcePhaseSpread"]
if smooth and spread_passed:
    classification = "robustSmoothPopulationWeightedSource"
elif smooth:
    classification = "meanSmoothButPhaseSensitive"
elif primary >= prereg["decisionRule"]["persistentBiasMinimumCurvature"]:
    classification = "populationWeightedSourceMeanNonAsymptotic"
else:
    classification = "mixedPopulationWeightedSourceMean"
check("classification", classification == summary["classification"], classification)
check("power gate", (smooth and spread_passed) == summary["quantitativePowerGatePassed"], {"smooth": smooth, "spreadPassed": spread_passed})
check("summary evidence passed", summary["passed"] is True, summary["gates"])
check("figure PNG exists", (ROOT / summary["figurePaths"][0]).is_file(), summary["figurePaths"][0])
check("figure SVG exists", (ROOT / summary["figurePaths"][1]).is_file(), summary["figurePaths"][1])
check("GitHub Actions absent", not (ROOT / ".github").exists(), (ROOT / ".github").exists())

output = {
    "schemaVersion": 1,
    "title": "Formation source three-offset independent audit",
    "checks": checks,
    "checkCount": len(checks),
    "checksPassed": sum(item["passed"] for item in checks),
    "recomputedIndividualOffsetCurvatures": phase_curvatures,
    "recomputedThreeOffsetMeanCurvatures": mean_curvatures,
    "recomputedThreeOffsetMeanComponentCurvatures": mean_component_curvatures,
    "recomputedPhaseSpread": spread,
    "recomputedComponentMaximumPhaseSpread": component_spread,
    "recomputedGeometryCurvatures": geometry_by_phase,
    "recomputedThreeOffsetMeanGeometryCurvature": mean_geometry_curvature,
    "recomputedClassification": classification,
    "recomputedQuantitativePowerGatePassed": smooth and spread_passed,
    "passed": all(item["passed"] for item in checks),
}
AUDIT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
print(f"formation source three-offset audit: {output['checksPassed']}/{output['checkCount']} checks passed")
if not output["passed"]:
    for item in checks:
        if not item["passed"]:
            print(f"FAILED: {item['name']}: {item['evidence']}")
    raise SystemExit(1)

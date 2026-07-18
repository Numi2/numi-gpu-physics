#!/usr/bin/env python3
"""Independent provenance and arithmetic audit for the subcell source census."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-subcell-source-census-v1.json"
SELECTION = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-audit.json"
RESOLUTIONS = (16, 18, 20)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(a: float, b: float, tolerance: float = 1e-10) -> bool:
    return math.isclose(a, b, rel_tol=tolerance, abs_tol=tolerance)


prereg, selection, summary = load(PREREG), load(SELECTION), load(SUMMARY)
checks = []


def check(name: str, passed: bool, evidence: object) -> None:
    checks.append({"name": name, "passed": bool(passed), "evidence": evidence})


check("preregistered before translated CFD", prereg["preregisteredBeforeTranslatedCFD"] is True, prereg["preregisteredBeforeTranslatedCFD"])
correction = prereg["postRunAnalysisCorrection"]
check("analysis correction preserves decision rule", correction["decisionRuleChanged"] is False, correction)
check("failed audit preserved", digest(ROOT / correction["failedAuditPath"]) == correction["failedAuditSHA256"], digest(ROOT / correction["failedAuditPath"]))
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"{group} hash {item['path']}", actual == item["sha256"], actual)
check("selection hash", digest(SELECTION) == summary["selection"]["sha256"], digest(SELECTION))
check("selected offset", selection["selected"]["offsetCells"] == prereg["lockedConfiguration"]["subcellOffsetCells"], selection["selected"]["offsetCells"])
check("selected beats zero", selection["selected"]["selectionScore"] < selection["legacyZeroOffset"]["selectionScore"], selection["selectedToLegacyScoreRatio"])

profiles = {name: {} for name in ("areal", "conditional", "source")}
component_profiles = {name: {} for name in ("reflectedMomentumExchange", "interpolationAuxiliary", "movingWall")}
weights = None
for resolution in RESOLUTIONS:
    inputs = summary["inputs"][f"c{resolution}"]
    for kind in ("report", "census"):
        path = ROOT / inputs[f"{kind}Path"]
        actual = digest(path)
        check(f"c{resolution} {kind} hash", actual == inputs[f"{kind}SHA256"], actual)
    report = load(ROOT / inputs["reportPath"])
    census = load(ROOT / inputs["censusPath"])
    check(f"c{resolution} report passed", report["gates"]["passed"] is True, report["gates"])
    check(f"c{resolution} census passed", census["passed"] is True, census["maximumRelativeReconstructionClosureResidual"])
    check(f"c{resolution} common offset", report["subcellOffsetCells"] == prereg["lockedConfiguration"]["subcellOffsetCells"], report["subcellOffsetCells"])
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
    closure = reflected_in + interpolation + wall
    relative = np.linalg.norm(incoming - closure) / max(np.linalg.norm(incoming), 1e-12)
    check(f"c{resolution} independent source reconstruction", relative <= prereg["gates"]["maximumRelativePopulationReconstructionClosureResidual"], relative)
    population = raw_reflected + incoming
    components = raw_reflected + reflected_in + interpolation + wall
    check(f"c{resolution} component identity", bool(np.allclose(population, components, rtol=2e-6, atol=2e-6)), float(np.max(np.abs(population - components))))
    profiles["areal"][resolution] = counts / resolution**2
    profiles["conditional"][resolution] = np.divide(population, counts, out=np.zeros(19), where=counts > 0)
    profiles["source"][resolution] = population / resolution**2
    component_profiles["reflectedMomentumExchange"][resolution] = (raw_reflected + reflected_in) / resolution**2
    component_profiles["interpolationAuxiliary"][resolution] = interpolation / resolution**2
    component_profiles["movingWall"][resolution] = wall / resolution**2

t = ((1 / 18) - (1 / 16)) / ((1 / 20) - (1 / 16))
check("interpolation fraction", close(t, summary["c18EndpointInterpolationFraction"]), t)
floor = prereg["decisionRule"]["denominatorFloor"]


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
recomputed = {}
for profile, metric in metric_names.items():
    value = curvature(profiles[profile])
    recomputed[metric] = value
    check(metric, close(value, summary["decisionMetrics"][metric]), value)
for component, values in component_profiles.items():
    value = curvature(values)
    recomputed[component] = value
    check(f"component curvature {component}", close(value, summary["decisionMetrics"]["normalizedComponentCurvatures"][component]), value)

source_curvature = recomputed["normalizedPopulationWeightedSourceCurvature"]
if source_curvature <= prereg["decisionRule"]["smoothRefinementMaximumCurvature"]:
    classification = "smoothPopulationWeightedSource"
elif source_curvature >= prereg["decisionRule"]["persistentBiasMinimumCurvature"]:
    classification = "populationWeightedSourceNonAsymptotic"
else:
    classification = "mixedPopulationWeightedSource"
check("classification", classification == summary["classification"], classification)
check("summary passed", summary["passed"] is True, summary["gates"])
check("figure PNG exists", (ROOT / summary["figurePaths"][0]).is_file(), summary["figurePaths"][0])
check("figure SVG exists", (ROOT / summary["figurePaths"][1]).is_file(), summary["figurePaths"][1])
check("GitHub Actions absent", not (ROOT / ".github").exists(), (ROOT / ".github").exists())

output = {
    "schemaVersion": 1,
    "title": "Formation subcell source census independent audit",
    "checks": checks,
    "checkCount": len(checks),
    "checksPassed": sum(item["passed"] for item in checks),
    "recomputedMetrics": recomputed,
    "recomputedClassification": classification,
    "passed": all(item["passed"] for item in checks),
}
AUDIT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
print(f"formation subcell source audit: {output['checksPassed']}/{output['checkCount']} checks passed")
if not output["passed"]:
    for item in checks:
        if not item["passed"]:
            print(f"FAILED: {item['name']}: {item['evidence']}")
    raise SystemExit(1)

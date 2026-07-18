#!/usr/bin/env python3
"""Analyze the final formation source phase and the frozen three-offset mean."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-subcell-source-offset3-v1.json"
SELECTION = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
OFFSET1_SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-summary.json"
OFFSET1_AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-audit.json"
OFFSET2_SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset2/formation-flight-subcell-source-offset2-summary.json"
OFFSET2_AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset2/formation-flight-subcell-source-offset2-audit.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset3"
SUMMARY = ARCHIVE / "formation-flight-subcell-source-three-offset-summary.json"
CSV = ARCHIVE / "formation-flight-subcell-source-three-offset-directions.csv"
PNG = ROOT / "Docs/Media/formation-flight-subcell-source-three-offset-convergence.png"
SVG = ROOT / "Docs/Media/formation-flight-subcell-source-three-offset-convergence.svg"
RESOLUTIONS = (16, 18, 20)
PROFILE_NAMES = ("areal", "conditional", "source")
COMPONENT_NAMES = (
    "reflectedMomentumExchange",
    "interpolationAuxiliary",
    "movingWall",
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def weighted_l1(values: np.ndarray, weights: np.ndarray) -> float:
    return float(np.sum(np.abs(values) * weights))


def interpolation_fraction() -> float:
    return ((1 / 18) - (1 / 16)) / ((1 / 20) - (1 / 16))


def curvature(values: dict[int, np.ndarray], weights: np.ndarray, floor: float) -> tuple[float, np.ndarray]:
    t = interpolation_fraction()
    expected = values[16] + t * (values[20] - values[16])
    numerator = weighted_l1(values[18] - expected, weights)
    denominator = max(weighted_l1(values[20] - values[16], weights), floor)
    return numerator / denominator, expected


def read_phase(root: Path, suffix: str, expected_offset: list[float]) -> tuple[dict, dict]:
    inputs: dict[str, dict] = {}
    raw: dict[int, dict] = {}
    for resolution in RESOLUTIONS:
        directory = root / f"c{resolution}-{suffix}"
        report_path = directory / "formation-flight-subcell-source-report.json"
        census_path = directory / "formation-flight-boundary-source-census.json"
        report, census = load(report_path), load(census_path)
        if not report["gates"]["passed"] or not census["passed"]:
            raise SystemExit(f"c{resolution} {suffix} source census failed")
        if report["subcellOffsetCells"] != expected_offset:
            raise SystemExit(f"c{resolution} {suffix} used the wrong offset")
        samples = [sample for sample in census["samples"] if sample["flyer"] == "leader"]
        if len(samples) != 1:
            raise SystemExit(f"c{resolution} {suffix} lacks exactly one leader sample")
        records = sorted(samples[0]["directions"], key=lambda row: row["directionIndex"])
        if [row["directionIndex"] for row in records] != list(range(19)):
            raise SystemExit(f"c{resolution} {suffix} is not complete D3Q19")
        directions = np.asarray([row["direction"] for row in records], dtype=float)
        counts = np.asarray([row["linkCount"] for row in records], dtype=float)
        raw_reflected = np.asarray([row["rawReflectedPopulationSum"] for row in records])
        incoming = np.asarray([row["reconstructedIncomingPopulationSum"] for row in records])
        reflected_in = np.asarray([row["reflectedIncomingPopulationSum"] for row in records])
        interpolation = np.asarray([row["interpolationAuxiliaryPopulationSum"] for row in records])
        wall = np.asarray([row["movingWallPopulationSum"] for row in records])
        population = raw_reflected + incoming
        raw[resolution] = {
            "report": report,
            "census": census,
            "records": records,
            "directions": directions,
            "counts": counts,
            "areal": counts / resolution**2,
            "conditional": np.divide(population, counts, out=np.zeros_like(population), where=counts > 0),
            "source": population / resolution**2,
            "components": {
                "reflectedMomentumExchange": (raw_reflected + reflected_in) / resolution**2,
                "interpolationAuxiliary": interpolation / resolution**2,
                "movingWall": wall / resolution**2,
            },
            "incomingDecompositionResidual": float(
                np.linalg.norm(incoming - reflected_in - interpolation - wall)
                / max(np.linalg.norm(incoming), 1e-12)
            ),
        }
        inputs[f"c{resolution}"] = {
            "reportPath": str(report_path.relative_to(ROOT)),
            "reportSHA256": digest(report_path),
            "censusPath": str(census_path.relative_to(ROOT)),
            "censusSHA256": digest(census_path),
            "deviceName": report["deviceName"],
            "runtimeSeconds": report["runtimeSeconds"],
            "actualLeaderPhase": report["actualLeaderPhase"],
            "actualFollowerPhase": report["actualFollowerPhase"],
        }
    return inputs, raw


prereg = load(PREREG)
selection = load(SELECTION)
offset1_summary, offset1_audit = load(OFFSET1_SUMMARY), load(OFFSET1_AUDIT)
offset2_summary, offset2_audit = load(OFFSET2_SUMMARY), load(OFFSET2_AUDIT)
rank = int(prereg["selectionRule"]["zeroBasedRank"])
candidates = [selection["selected"], selection["topEightCandidates"][1], selection["topEightCandidates"][rank]]
phase_specs = (
    ("offset1", ROOT / "ValidationArtifacts/formation-flight-subcell-source-census", "median-phase", candidates[0]["offsetCells"]),
    ("offset2", ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset2", "offset2", candidates[1]["offsetCells"]),
    ("offset3", ARCHIVE, "offset3", candidates[2]["offsetCells"]),
)
if candidates[2]["offsetCells"] != prereg["lockedConfiguration"]["subcellOffsetCells"]:
    raise SystemExit("final candidate rank does not match the preregistered offset")

phase_inputs: dict[str, dict] = {}
phase_raw: dict[str, dict] = {}
for name, root, suffix, offset in phase_specs:
    phase_inputs[name], phase_raw[name] = read_phase(root, suffix, offset)

weights = np.linalg.norm(phase_raw["offset1"][16]["directions"], axis=1)
floor = float(prereg["decisionRule"]["denominatorFloor"])
phase_curvatures: dict[str, dict] = {}
for name in phase_raw:
    phase_curvatures[name] = {}
    for profile in PROFILE_NAMES:
        phase_curvatures[name][profile], _ = curvature(
            {r: phase_raw[name][r][profile] for r in RESOLUTIONS}, weights, floor
        )

mean_profiles = {
    profile: {
        r: np.mean([phase_raw[name][r][profile] for name in phase_raw], axis=0)
        for r in RESOLUTIONS
    }
    for profile in PROFILE_NAMES
}
mean_components = {
    component: {
        r: np.mean([phase_raw[name][r]["components"][component] for name in phase_raw], axis=0)
        for r in RESOLUTIONS
    }
    for component in COMPONENT_NAMES
}
mean_curvatures = {profile: curvature(mean_profiles[profile], weights, floor)[0] for profile in PROFILE_NAMES}
mean_component_curvatures = {component: curvature(mean_components[component], weights, floor)[0] for component in COMPONENT_NAMES}


def phase_spread(profile: str) -> dict:
    by_resolution = {}
    for resolution in RESOLUTIONS:
        values = [phase_raw[name][resolution][profile] for name in phase_raw]
        mean = np.mean(values, axis=0)
        denominator = max(weighted_l1(mean, weights), floor)
        deviations = [weighted_l1(value - mean, weights) / denominator for value in values]
        pairwise = [
            weighted_l1(values[i] - values[j], weights) / denominator
            for i in range(len(values)) for j in range(i + 1, len(values))
        ]
        by_resolution[f"c{resolution}"] = {
            "maximumRelativeDeviationFromMean": max(deviations),
            "maximumRelativePairwiseDifference": max(pairwise),
        }
    return {
        "byResolution": by_resolution,
        "maximumRelativeDeviationFromMean": max(v["maximumRelativeDeviationFromMean"] for v in by_resolution.values()),
        "maximumRelativePairwiseDifference": max(v["maximumRelativePairwiseDifference"] for v in by_resolution.values()),
    }


spread = {profile: phase_spread(profile) for profile in PROFILE_NAMES}
component_spread = {}
for component in COMPONENT_NAMES:
    synthetic = {}
    for name in phase_raw:
        synthetic[name] = {r: {"component": phase_raw[name][r]["components"][component]} for r in RESOLUTIONS}
    by_resolution = {}
    for resolution in RESOLUTIONS:
        values = [phase_raw[name][resolution]["components"][component] for name in phase_raw]
        mean = np.mean(values, axis=0)
        denominator = max(weighted_l1(mean, weights), floor)
        pairwise = [weighted_l1(values[i] - values[j], weights) / denominator for i in range(3) for j in range(i + 1, 3)]
        by_resolution[f"c{resolution}"] = max(pairwise)
    component_spread[component] = {
        "maximumRelativePairwiseDifferenceByResolution": by_resolution,
        "maximumRelativePairwiseDifference": max(by_resolution.values()),
    }

geometry_by_phase = {}
for index, candidate in enumerate(candidates, start=1):
    values = {r: np.asarray([candidate["resolutionContributions"][f"c{r}"]["leaderArealLinkDensity"]]) for r in RESOLUTIONS}
    geometry_by_phase[f"offset{index}"] = {
        "curvature": curvature(values, np.ones(1), floor)[0],
        "densityByResolution": {f"c{r}": float(values[r][0]) for r in RESOLUTIONS},
    }
mean_geometry = {r: np.asarray([np.mean([geometry_by_phase[name]["densityByResolution"][f"c{r}"] for name in geometry_by_phase])]) for r in RESOLUTIONS}
mean_geometry_curvature = curvature(mean_geometry, np.ones(1), floor)[0]

smooth_limit = float(prereg["decisionRule"]["smoothRefinementMaximumCurvature"])
persistent_limit = float(prereg["decisionRule"]["persistentBiasMinimumCurvature"])
spread_limit = float(prereg["decisionRule"]["maximumRelativePairwiseSourcePhaseSpread"])
primary = mean_curvatures["source"]
source_spread = spread["source"]["maximumRelativePairwiseDifference"]
if primary <= smooth_limit and source_spread <= spread_limit:
    classification = "robustSmoothPopulationWeightedSource"
elif primary <= smooth_limit:
    classification = "meanSmoothButPhaseSensitive"
elif primary >= persistent_limit:
    classification = "populationWeightedSourceMeanNonAsymptotic"
else:
    classification = "mixedPopulationWeightedSourceMean"

rows = []
for name in phase_raw:
    for resolution in RESOLUTIONS:
        for record, source in zip(phase_raw[name][resolution]["records"], phase_raw[name][resolution]["source"]):
            rows.append({
                "offsetName": name,
                "offsetCells": candidates[int(name[-1]) - 1]["offsetCells"],
                "chordCells": resolution,
                "directionIndex": record["directionIndex"],
                "directionX": record["direction"][0],
                "directionY": record["direction"][1],
                "directionZ": record["direction"][2],
                "linkCount": record["linkCount"],
                "populationWeightedSource": source,
            })
ARCHIVE.mkdir(parents=True, exist_ok=True)
with CSV.open("w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

gates = {
    "preregisteredBeforeTranslatedCFD": prereg["preregisteredBeforeTranslatedCFD"],
    "parentResultsPassed": offset1_summary["passed"] and offset1_audit["passed"] and offset2_summary["passed"] and offset2_audit["passed"],
    "deterministicFinalCandidateRank": rank == 2 and candidates[2]["offsetCells"] == [0.25, 0.0, 0.5],
    "allNineRunsPassed": all(phase_raw[name][r]["report"]["gates"]["passed"] for name in phase_raw for r in RESOLUTIONS),
    "allNineSourceCensusesPassed": all(phase_raw[name][r]["census"]["passed"] for name in phase_raw for r in RESOLUTIONS),
    "allOffsetsMatch": all(phase_raw[name][r]["report"]["subcellOffsetCells"] == candidates[int(name[-1]) - 1]["offsetCells"] for name in phase_raw for r in RESOLUTIONS),
    "allOwnersAndDirectionsComplete": all(len(phase_raw[name][r]["census"]["samples"]) == 2 and len(phase_raw[name][r]["records"]) == 19 for name in phase_raw for r in RESOLUTIONS),
    "incomingDecompositionClosure": all(phase_raw[name][r]["incomingDecompositionResidual"] <= prereg["gates"]["maximumRelativePopulationReconstructionClosureResidual"] for name in phase_raw for r in RESOLUTIONS),
    "allFinite": all(math.isfinite(value) for value in (
        *[v for values in phase_curvatures.values() for v in values.values()],
        *mean_curvatures.values(), *mean_component_curvatures.values(),
        *[spread[p]["maximumRelativePairwiseDifference"] for p in spread],
        *[spread[p]["maximumRelativeDeviationFromMean"] for p in spread],
        *[component_spread[c]["maximumRelativePairwiseDifference"] for c in component_spread],
        mean_geometry_curvature,
    )),
    "threeOffsetMeanSourceSmooth": primary <= smooth_limit,
    "sourceProfilePhaseSpreadPassed": source_spread <= spread_limit,
}

summary = {
    "schemaVersion": 1,
    "title": "Formation Flight three-offset source robustness decision",
    "scientificQuestion": prereg["scientificQuestion"],
    "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
    "selection": {
        "path": str(SELECTION.relative_to(ROOT)),
        "sha256": digest(SELECTION),
        "offsets": [
            {"name": f"offset{i + 1}", "zeroBasedRank": i, "offsetCells": candidate["offsetCells"], "selectionScore": candidate["selectionScore"]}
            for i, candidate in enumerate(candidates)
        ],
    },
    "parentEvidence": {
        "offset1Summary": {"path": str(OFFSET1_SUMMARY.relative_to(ROOT)), "sha256": digest(OFFSET1_SUMMARY)},
        "offset1Audit": {"path": str(OFFSET1_AUDIT.relative_to(ROOT)), "sha256": digest(OFFSET1_AUDIT)},
        "offset2Summary": {"path": str(OFFSET2_SUMMARY.relative_to(ROOT)), "sha256": digest(OFFSET2_SUMMARY)},
        "offset2Audit": {"path": str(OFFSET2_AUDIT.relative_to(ROOT)), "sha256": digest(OFFSET2_AUDIT)},
    },
    "phaseInputs": phase_inputs,
    "c18EndpointInterpolationFraction": interpolation_fraction(),
    "decisionMetrics": {
        "individualOffsetCurvatures": phase_curvatures,
        "threeOffsetMeanCurvatures": mean_curvatures,
        "threeOffsetMeanComponentCurvatures": mean_component_curvatures,
        "phaseSpread": spread,
        "componentPhaseSpread": component_spread,
        "geometryByPhase": geometry_by_phase,
        "threeOffsetMeanGeometryDensityCurvature": mean_geometry_curvature,
        "smoothRefinementMaximumCurvature": smooth_limit,
        "persistentBiasMinimumCurvature": persistent_limit,
        "maximumRelativePairwiseSourcePhaseSpread": spread_limit,
    },
    "primaryMetric": "threeOffsetMeanCurvatures.source",
    "classification": classification,
    "gates": gates,
    "passed": all(value for key, value in gates.items() if key not in ("threeOffsetMeanSourceSmooth", "sourceProfilePhaseSpreadPassed")),
    "quantitativePowerGatePassed": gates["threeOffsetMeanSourceSmooth"] and gates["sourceProfilePhaseSpreadPassed"],
    "nextAction": prereg["decisionRule"]["nextActions"][classification],
    "csvPath": str(CSV.relative_to(ROOT)),
    "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
    "newCFDRuntimeSeconds": sum(phase_raw["offset3"][r]["report"]["runtimeSeconds"] for r in RESOLUTIONS),
    "allThreeOffsetRuntimeSeconds": sum(phase_raw[name][r]["report"]["runtimeSeconds"] for name in phase_raw for r in RESOLUTIONS),
    "claimBoundary": prereg["claimBoundary"],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.titleweight": "bold", "svg.hashsalt": "birdflow-source-three-offset-v1"})
fig, axes = plt.subplots(1, 3, figsize=(16, 5.8), facecolor="#06101c")
for axis in axes:
    axis.set_facecolor("#0b1b2d")
    axis.tick_params(colors="#cbd8e5")
    axis.grid(color="#27415d", alpha=0.45, linewidth=0.6)
    for spine in axis.spines.values():
        spine.set_color("#35516d")
    axis.xaxis.label.set_color("#cbd8e5")
    axis.yaxis.label.set_color("#cbd8e5")
    axis.title.set_color("#f4f8fc")

labels = ["phase 1", "phase 2", "phase 3", "three-phase mean"]
values = [phase_curvatures[f"offset{i}"]["source"] for i in (1, 2, 3)] + [primary]
colors = ["#36d7ff" if v <= smooth_limit else "#ffd166" if v < persistent_limit else "#ff6b9d" for v in values]
axes[0].barh(labels, values, color=colors)
axes[0].axvline(smooth_limit, color="#36d7ff", linestyle="--", linewidth=1.3, label="smooth limit")
axes[0].axvline(persistent_limit, color="#ff6b9d", linestyle=":", linewidth=1.3, label="persistent-bias limit")
axes[0].invert_yaxis()
axes[0].set_title(f"SOURCE CURVATURE  MEAN={primary:.3f}")
axes[0].set_xlabel("normalized h-linear c18 curvature")
axes[0].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

indices = np.arange(19)
grid_colors = {16: "#36d7ff", 18: "#ffd166", 20: "#ff6b9d"}
for resolution in RESOLUTIONS:
    axes[1].plot(indices, mean_profiles["source"][resolution], marker="o", markersize=3.5, linewidth=1.7, color=grid_colors[resolution], label=f"c{resolution}")
axes[1].set_title("THREE-PHASE MEAN SOURCE")
axes[1].set_xlabel("D3Q19 direction")
axes[1].set_ylabel("momentum-exchange population / chord-cells²")
axes[1].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

spread_values = [spread["source"]["byResolution"][f"c{r}"]["maximumRelativePairwiseDifference"] * 100 for r in RESOLUTIONS]
axes[2].bar([str(r) for r in RESOLUTIONS], spread_values, color=[grid_colors[r] for r in RESOLUTIONS])
axes[2].axhline(spread_limit * 100, color="#ff6b9d", linestyle="--", linewidth=1.3, label="5% phase-spread limit")
axes[2].set_title(f"MAX PHASE SPREAD  {source_spread * 100:.2f}%")
axes[2].set_xlabel("chord cells")
axes[2].set_ylabel("pairwise source difference / mean (%)")
axes[2].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

verdict = "POWER SCOUT AUTHORIZED" if summary["quantitativePowerGatePassed"] else "POWER STUDY REMAINS BLOCKED"
fig.suptitle(f"BIRDFLOW METAL  /  THREE-PHASE SOURCE ROBUSTNESS  /  {verdict}", color="#f4f8fc", fontsize=16, fontweight="bold", y=0.99)
fig.text(0.5, 0.015, "offsets [0.25,0.25,0.75] • [0.5,0.75,0.5] • [0.25,0,0.5]  /  five-cycle production TRT", ha="center", color="#90a9c1", fontsize=9)
fig.tight_layout(rect=(0, 0.045, 1, 0.95))
fig.savefig(PNG, dpi=180, facecolor=fig.get_facecolor())
fig.savefig(SVG, facecolor=fig.get_facecolor())
print(f"three-offset source classification: {classification}")
print(f"three-offset mean source curvature: {primary:.9f}")
print(f"maximum pairwise source phase spread: {source_spread:.9%}")
print(f"quantitative power gate passed: {summary['quantitativePowerGatePassed']}")
print(f"summary: {SUMMARY.relative_to(ROOT)}")

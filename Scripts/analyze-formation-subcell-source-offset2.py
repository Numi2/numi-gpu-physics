#!/usr/bin/env python3
"""Analyze the preregistered second-ranked formation source lattice phase."""

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
PREREG = ROOT / "ValidationInputs/formation-flight-subcell-source-offset2-v1.json"
SELECTION = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
PARENT_SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-summary.json"
PARENT_AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/formation-flight-subcell-source-audit.json"
PARENT_ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset2"
SUMMARY = ARCHIVE / "formation-flight-subcell-source-offset2-summary.json"
CSV = ARCHIVE / "formation-flight-subcell-source-offset2-directions.csv"
PNG = ROOT / "Docs/Media/formation-flight-subcell-source-offset2-convergence.png"
SVG = ROOT / "Docs/Media/formation-flight-subcell-source-offset2-convergence.svg"
RESOLUTIONS = (16, 18, 20)
COMPONENT_FIELDS = {
    "reflectedMomentumExchange": (
        "rawReflectedPopulationSum",
        "reflectedIncomingPopulationSum",
    ),
    "interpolationAuxiliary": ("interpolationAuxiliaryPopulationSum",),
    "movingWall": ("movingWallPopulationSum",),
}


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


def read_profiles(base: Path, suffix: str, expected_offset: list[float]) -> tuple[dict, dict]:
    inputs: dict[str, dict] = {}
    raw: dict[int, dict] = {}
    for resolution in RESOLUTIONS:
        directory = base / f"c{resolution}-{suffix}"
        report_path = directory / "formation-flight-subcell-source-report.json"
        census_path = directory / "formation-flight-boundary-source-census.json"
        report, census = load(report_path), load(census_path)
        if not report["gates"]["passed"] or not census["passed"]:
            raise SystemExit(f"c{resolution} {suffix} source census failed")
        if report["subcellOffsetCells"] != expected_offset:
            raise SystemExit(f"c{resolution} {suffix} used the wrong subcell offset")
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
            "sample": samples[0],
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
            "incomingDecompositionResidual": float(np.linalg.norm(incoming - reflected_in - interpolation - wall) / max(np.linalg.norm(incoming), 1e-12)),
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
parent_summary = load(PARENT_SUMMARY)
parent_audit = load(PARENT_AUDIT)
candidate_rank = int(prereg["selectionRule"]["zeroBasedRank"])
candidate = selection["topEightCandidates"][candidate_rank]
selected_offset = candidate["offsetCells"]
if selected_offset != prereg["lockedConfiguration"]["subcellOffsetCells"]:
    raise SystemExit("selection rank does not match the preregistered offset")

inputs, raw = read_profiles(ARCHIVE, "offset2", selected_offset)
_, parent_raw = read_profiles(PARENT_ARCHIVE, "median-phase", selection["selected"]["offsetCells"])
weights = np.linalg.norm(raw[16]["directions"], axis=1)
floor = float(prereg["decisionRule"]["denominatorFloor"])

profiles = {
    name: {resolution: raw[resolution][name] for resolution in RESOLUTIONS}
    for name in ("areal", "conditional", "source")
}
parent_profiles = {
    name: {resolution: parent_raw[resolution][name] for resolution in RESOLUTIONS}
    for name in ("areal", "conditional", "source")
}
two_offset_profiles = {
    name: {
        resolution: 0.5 * (profiles[name][resolution] + parent_profiles[name][resolution])
        for resolution in RESOLUTIONS
    }
    for name in profiles
}

curvatures: dict[str, float] = {}
expected_profiles: dict[str, np.ndarray] = {}
parent_curvatures: dict[str, float] = {}
two_offset_curvatures: dict[str, float] = {}
for name in profiles:
    curvatures[name], expected_profiles[name] = curvature(profiles[name], weights, floor)
    parent_curvatures[name], _ = curvature(parent_profiles[name], weights, floor)
    two_offset_curvatures[name], _ = curvature(two_offset_profiles[name], weights, floor)

component_curvatures = {}
for component in COMPONENT_FIELDS:
    component_curvatures[component], _ = curvature(
        {resolution: raw[resolution]["components"][component] for resolution in RESOLUTIONS},
        weights,
        floor,
    )

geometry = {
    resolution: np.asarray([candidate["resolutionContributions"][f"c{resolution}"]["leaderArealLinkDensity"]])
    for resolution in RESOLUTIONS
}
geometry_curvature, geometry_expected = curvature(geometry, np.ones(1), floor)
source_norms = {resolution: weighted_l1(raw[resolution]["source"], weights) for resolution in RESOLUTIONS}
smooth_limit = float(prereg["decisionRule"]["smoothRefinementMaximumCurvature"])
persistent_limit = float(prereg["decisionRule"]["persistentBiasMinimumCurvature"])
if curvatures["source"] <= smooth_limit:
    classification = "smoothPopulationWeightedSource"
elif curvatures["source"] >= persistent_limit:
    classification = "populationWeightedSourceNonAsymptotic"
else:
    classification = "mixedPopulationWeightedSource"
cross_offset_interpretation = (
    "phaseLocalSensitivityDetected"
    if classification == "smoothPopulationWeightedSource"
    else "nonsmoothAtBothTestedOffsets"
)

rows = []
for resolution in RESOLUTIONS:
    for record, areal, conditional, source in zip(
        raw[resolution]["records"],
        raw[resolution]["areal"],
        raw[resolution]["conditional"],
        raw[resolution]["source"],
    ):
        rows.append({
            "chordCells": resolution,
            "directionIndex": record["directionIndex"],
            "directionX": record["direction"][0],
            "directionY": record["direction"][1],
            "directionZ": record["direction"][2],
            "linkCount": record["linkCount"],
            "arealLinkMeasure": areal,
            "conditionalMomentumExchangePopulation": conditional,
            "populationWeightedSource": source,
        })
ARCHIVE.mkdir(parents=True, exist_ok=True)
with CSV.open("w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

gates = {
    "preregisteredBeforeTranslatedCFD": prereg["preregisteredBeforeTranslatedCFD"],
    "parentResultPassed": parent_summary["passed"] and parent_audit["passed"],
    "deterministicCandidateRank": candidate_rank == 1 and selected_offset == [0.5, 0.75, 0.5],
    "allThreeRunsPassed": all(raw[r]["report"]["gates"]["passed"] for r in RESOLUTIONS),
    "allSourceCensusesPassed": all(raw[r]["census"]["passed"] for r in RESOLUTIONS),
    "commonSubcellOffset": all(raw[r]["report"]["subcellOffsetCells"] == selected_offset for r in RESOLUTIONS),
    "oneLeaderAndFollowerSamplePerGrid": all(len(raw[r]["census"]["samples"]) == 2 for r in RESOLUTIONS),
    "incomingDecompositionClosure": all(raw[r]["incomingDecompositionResidual"] <= prereg["gates"]["maximumRelativePopulationReconstructionClosureResidual"] for r in RESOLUTIONS),
    "allFinite": all(math.isfinite(value) for value in (
        *curvatures.values(), *parent_curvatures.values(), *two_offset_curvatures.values(),
        *component_curvatures.values(), *source_norms.values(), geometry_curvature,
    )),
}

summary = {
    "schemaVersion": 1,
    "title": "Formation Flight second-ranked lattice-phase source discriminator",
    "scientificQuestion": prereg["scientificQuestion"],
    "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
    "selection": {
        "path": str(SELECTION.relative_to(ROOT)),
        "sha256": digest(SELECTION),
        "zeroBasedRank": candidate_rank,
        "subcellOffsetCells": selected_offset,
        "selectionScore": candidate["selectionScore"],
        "selectedMedianScore": selection["selected"]["selectionScore"],
    },
    "parentEvidence": {
        "summaryPath": str(PARENT_SUMMARY.relative_to(ROOT)),
        "summarySHA256": digest(PARENT_SUMMARY),
        "auditPath": str(PARENT_AUDIT.relative_to(ROOT)),
        "auditSHA256": digest(PARENT_AUDIT),
        "classification": parent_summary["classification"],
    },
    "inputs": inputs,
    "c18EndpointInterpolationFraction": interpolation_fraction(),
    "decisionMetrics": {
        "normalizedArealLinkProfileCurvature": curvatures["areal"],
        "normalizedConditionalPopulationCurvature": curvatures["conditional"],
        "normalizedPopulationWeightedSourceCurvature": curvatures["source"],
        "normalizedComponentCurvatures": component_curvatures,
        "candidateGeometryDensityCurvature": geometry_curvature,
        "parentCurvatures": parent_curvatures,
        "twoOffsetMeanCurvatures": two_offset_curvatures,
        "sourceWeightedL1NormByResolution": {f"c{r}": source_norms[r] for r in RESOLUTIONS},
        "smoothRefinementMaximumCurvature": smooth_limit,
        "persistentBiasMinimumCurvature": persistent_limit,
    },
    "classification": classification,
    "crossOffsetInterpretation": cross_offset_interpretation,
    "gates": gates,
    "passed": all(gates.values()),
    "nextAction": prereg["decisionRule"]["nextActions"][classification],
    "csvPath": str(CSV.relative_to(ROOT)),
    "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
    "totalRecordedRuntimeSeconds": sum(raw[r]["report"]["runtimeSeconds"] for r in RESOLUTIONS),
    "claimBoundary": prereg["claimBoundary"],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.titleweight": "bold", "svg.hashsalt": "birdflow-source-offset2-v1"})
fig, axes = plt.subplots(1, 3, figsize=(16, 5.8), facecolor="#06101c")
colors = {16: "#36d7ff", 18: "#ffd166", 20: "#ff6b9d"}
for axis in axes:
    axis.set_facecolor("#0b1b2d")
    axis.tick_params(colors="#cbd8e5")
    axis.grid(color="#27415d", alpha=0.45, linewidth=0.6)
    for spine in axis.spines.values():
        spine.set_color("#35516d")
    axis.xaxis.label.set_color("#cbd8e5")
    axis.yaxis.label.set_color("#cbd8e5")
    axis.title.set_color("#f4f8fc")

axes[0].plot(RESOLUTIONS, [geometry[r][0] for r in RESOLUTIONS], marker="o", linewidth=2.6, color="#36d7ff")
axes[0].scatter([18], [float(geometry_expected[0])], marker="x", s=95, color="#ff6b9d", label="h-linear expectation")
axes[0].set_title(f"ALTERNATE GEOMETRY  C={geometry_curvature:.3f}")
axes[0].set_xlabel("chord cells")
axes[0].set_ylabel("leader links / chord-cells²")
axes[0].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

indices = np.arange(19)
for resolution in RESOLUTIONS:
    axes[1].plot(indices, raw[resolution]["source"], marker="o", markersize=3.5, linewidth=1.7, color=colors[resolution], label=f"c{resolution}")
axes[1].set_title(f"POPULATION-WEIGHTED SOURCE  C={curvatures['source']:.3f}")
axes[1].set_xlabel("D3Q19 direction")
axes[1].set_ylabel("momentum-exchange population / chord-cells²")
axes[1].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

labels = ["parent phase", "alternate phase", "two-phase mean"]
values = [parent_curvatures["source"], curvatures["source"], two_offset_curvatures["source"]]
bar_colors = ["#36d7ff" if v <= smooth_limit else "#ffd166" if v < persistent_limit else "#ff6b9d" for v in values]
axes[2].barh(labels, values, color=bar_colors)
axes[2].axvline(smooth_limit, color="#36d7ff", linestyle="--", linewidth=1.3, label="smooth limit")
axes[2].axvline(persistent_limit, color="#ff6b9d", linestyle=":", linewidth=1.3, label="persistent-bias limit")
axes[2].invert_yaxis()
axes[2].set_title(cross_offset_interpretation)
axes[2].set_xlabel("normalized h-linear c18 curvature")
axes[2].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

fig.suptitle("BIRDFLOW METAL  /  FORMATION SOURCE PHASE ROBUSTNESS", color="#f4f8fc", fontsize=17, fontweight="bold", y=0.99)
fig.text(0.5, 0.015, f"second-ranked common offset {selected_offset}  •  leader phase {prereg['lockedConfiguration']['leaderPhase']}  •  five-cycle production TRT", ha="center", color="#90a9c1", fontsize=9)
fig.tight_layout(rect=(0, 0.045, 1, 0.95))
fig.savefig(PNG, dpi=180, facecolor=fig.get_facecolor())
fig.savefig(SVG, facecolor=fig.get_facecolor())
print(f"alternate-offset source classification: {classification}")
print(f"source curvature: {curvatures['source']:.9f}")
print(f"two-offset mean source curvature: {two_offset_curvatures['source']:.9f}")
print(f"summary: {SUMMARY.relative_to(ROOT)}")

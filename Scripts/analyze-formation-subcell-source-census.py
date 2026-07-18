#!/usr/bin/env python3
"""Analyze the preregistered median-phase c16/c18/c20 source census."""

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
PREREG = ROOT / "ValidationInputs/formation-flight-subcell-source-census-v1.json"
SELECTION = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census"
SUMMARY = ARCHIVE / "formation-flight-subcell-source-summary.json"
CSV = ARCHIVE / "formation-flight-subcell-source-directions.csv"
PNG = ROOT / "Docs/Media/formation-flight-subcell-source-convergence.png"
SVG = ROOT / "Docs/Media/formation-flight-subcell-source-convergence.svg"
RESOLUTIONS = (16, 18, 20)
COMPONENTS = {
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
    h16, h18, h20 = 1 / 16, 1 / 18, 1 / 20
    return (h18 - h16) / (h20 - h16)


def curvature(
    values: dict[int, np.ndarray],
    weights: np.ndarray,
    floor: float,
) -> tuple[float, np.ndarray]:
    t = interpolation_fraction()
    expected = values[16] + t * (values[20] - values[16])
    numerator = weighted_l1(values[18] - expected, weights)
    denominator = max(
        weighted_l1(values[20] - values[16], weights), floor
    )
    return numerator / denominator, expected


prereg = load(PREREG)
selection = load(SELECTION)
selected_offset = selection["selected"]["offsetCells"]
floor = float(prereg["decisionRule"]["denominatorFloor"])
inputs = {}
raw = {}
rows = []
for resolution in RESOLUTIONS:
    directory = ARCHIVE / f"c{resolution}-median-phase"
    report_path = directory / "formation-flight-subcell-source-report.json"
    census_path = directory / "formation-flight-boundary-source-census.json"
    report, census = load(report_path), load(census_path)
    if not report["gates"]["passed"] or not census["passed"]:
        raise SystemExit(f"c{resolution} source census failed")
    if report["subcellOffsetCells"] != selected_offset:
        raise SystemExit(f"c{resolution} used the wrong subcell offset")
    samples = [sample for sample in census["samples"] if sample["flyer"] == "leader"]
    if len(samples) != 1:
        raise SystemExit(f"c{resolution} does not contain one leader sample")
    records = sorted(samples[0]["directions"], key=lambda row: row["directionIndex"])
    if [row["directionIndex"] for row in records] != list(range(19)):
        raise SystemExit(f"c{resolution} source census is not complete D3Q19")
    directions = np.asarray([row["direction"] for row in records], dtype=float)
    counts = np.asarray([row["linkCount"] for row in records], dtype=float)
    raw_reflected = np.asarray([
        row["rawReflectedPopulationSum"] for row in records
    ])
    reflected_incoming = np.asarray([
        row["reflectedIncomingPopulationSum"] for row in records
    ])
    reflected = raw_reflected + reflected_incoming
    incoming = np.asarray([
        row["reconstructedIncomingPopulationSum"] for row in records
    ])
    decomposed_incoming = np.asarray([
        row["reflectedIncomingPopulationSum"]
        + row["interpolationAuxiliaryPopulationSum"]
        + row["movingWallPopulationSum"]
        for row in records
    ])
    interpolation = np.asarray([
        row["interpolationAuxiliaryPopulationSum"] for row in records
    ])
    wall = np.asarray([row["movingWallPopulationSum"] for row in records])
    # The preregistered primary signal is the exact production pair. Keep the
    # decomposed reconstruction only as a closure check/component attribution.
    population = raw_reflected + incoming
    areal = counts / resolution**2
    conditional = np.divide(
        population,
        counts,
        out=np.zeros_like(population),
        where=counts > 0,
    )
    source = population / resolution**2
    raw[resolution] = {
        "report": report,
        "census": census,
        "sample": samples[0],
        "directions": directions,
        "counts": counts,
        "areal": areal,
        "conditional": conditional,
        "source": source,
        "components": {
            "reflectedMomentumExchange": reflected / resolution**2,
            "interpolationAuxiliary": interpolation / resolution**2,
            "movingWall": wall / resolution**2,
        },
        "maximumIncomingDecompositionDifference": float(
            np.max(np.abs(incoming - decomposed_incoming))
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
    for record, a, m, s in zip(records, areal, conditional, source):
        rows.append({
            "chordCells": resolution,
            "directionIndex": record["directionIndex"],
            "directionX": record["direction"][0],
            "directionY": record["direction"][1],
            "directionZ": record["direction"][2],
            "linkCount": record["linkCount"],
            "arealLinkMeasure": a,
            "conditionalMomentumExchangePopulation": m,
            "populationWeightedSource": s,
            "reflectedSource": (
                record["rawReflectedPopulationSum"]
                + record["reflectedIncomingPopulationSum"]
            ) / resolution**2,
            "interpolationSource": (
                record["interpolationAuxiliaryPopulationSum"]
                / resolution**2
            ),
            "movingWallSource": (
                record["movingWallPopulationSum"] / resolution**2
            ),
        })

with CSV.open("w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

weights = np.linalg.norm(raw[16]["directions"], axis=1)
profiles = {
    name: {resolution: raw[resolution][name] for resolution in RESOLUTIONS}
    for name in ("areal", "conditional", "source")
}
curvatures = {}
expected_profiles = {}
for name, values in profiles.items():
    curvatures[name], expected_profiles[name] = curvature(
        values, weights, floor
    )
component_curvatures = {}
for component in COMPONENTS:
    values = {
        resolution: raw[resolution]["components"][component]
        for resolution in RESOLUTIONS
    }
    component_curvatures[component], _ = curvature(values, weights, floor)

source_norms = {
    resolution: weighted_l1(raw[resolution]["source"], weights)
    for resolution in RESOLUTIONS
}
smooth_limit = float(
    prereg["decisionRule"]["smoothRefinementMaximumCurvature"]
)
persistent_limit = float(
    prereg["decisionRule"]["persistentBiasMinimumCurvature"]
)
if curvatures["source"] <= smooth_limit:
    classification = "smoothPopulationWeightedSource"
elif curvatures["source"] >= persistent_limit:
    classification = "populationWeightedSourceNonAsymptotic"
else:
    classification = "mixedPopulationWeightedSource"

geometry = {}
for resolution in RESOLUTIONS:
    contribution = selection["selected"]["resolutionContributions"][f"c{resolution}"]
    geometry[resolution] = np.asarray([
        contribution["leaderArealLinkDensity"]
    ])
geometry_curvature, geometry_expected = curvature(
    geometry, np.ones(1), floor
)
gates = {
    "preregisteredBeforeTranslatedCFD": prereg[
        "preregisteredBeforeTranslatedCFD"
    ],
    "deterministicSelectionPassed": selection["passed"],
    "allThreeRunsPassed": all(raw[r]["report"]["gates"]["passed"] for r in RESOLUTIONS),
    "allSourceCensusesPassed": all(raw[r]["census"]["passed"] for r in RESOLUTIONS),
    "commonSubcellOffset": all(
        raw[r]["report"]["subcellOffsetCells"] == selected_offset
        for r in RESOLUTIONS
    ),
    "oneLeaderAndFollowerSamplePerGrid": all(
        len(raw[r]["census"]["samples"]) == 2 for r in RESOLUTIONS
    ),
    "geometryPhaseSmooth": geometry_curvature <= smooth_limit,
    "allFinite": all(math.isfinite(value) for value in (
        *curvatures.values(),
        *component_curvatures.values(),
        *source_norms.values(),
        geometry_curvature,
    )),
}
passed = all(gates.values())
summary = {
    "schemaVersion": 1,
    "title": "Formation Flight median-phase boundary population source convergence",
    "scientificQuestion": prereg["scientificQuestion"],
    "preregistration": {
        "path": str(PREREG.relative_to(ROOT)),
        "sha256": digest(PREREG),
        "preregisteredBeforeTranslatedCFD": prereg[
            "preregisteredBeforeTranslatedCFD"
        ],
    },
    "postRunAnalysisCorrection": prereg["postRunAnalysisCorrection"],
    "selection": {
        "path": str(SELECTION.relative_to(ROOT)),
        "sha256": digest(SELECTION),
        "subcellOffsetCells": selected_offset,
        "selectionScore": selection["selected"]["selectionScore"],
        "legacyZeroOffsetScore": selection["legacyZeroOffset"]["selectionScore"],
    },
    "inputs": inputs,
    "interpolationCoordinate": "h = 1 / chordCells",
    "c18EndpointInterpolationFraction": interpolation_fraction(),
    "decisionMetrics": {
        "normalizedArealLinkProfileCurvature": curvatures["areal"],
        "normalizedConditionalPopulationCurvature": curvatures["conditional"],
        "normalizedPopulationWeightedSourceCurvature": curvatures["source"],
        "normalizedComponentCurvatures": component_curvatures,
        "selectedGeometryDensityCurvature": geometry_curvature,
        "sourceWeightedL1NormByResolution": {
            f"c{resolution}": source_norms[resolution]
            for resolution in RESOLUTIONS
        },
        "smoothRefinementMaximumCurvature": smooth_limit,
        "persistentBiasMinimumCurvature": persistent_limit,
    },
    "classification": classification,
    "gates": gates,
    "passed": passed,
    "nextAction": prereg["decisionRule"]["nextActions"][classification],
    "csvPath": str(CSV.relative_to(ROOT)),
    "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
    "totalRecordedRuntimeSeconds": sum(
        raw[r]["report"]["runtimeSeconds"] for r in RESOLUTIONS
    ),
    "claimBoundary": prereg["claimBoundary"],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 10,
    "axes.titleweight": "bold",
    "svg.hashsalt": "birdflow-subcell-source-v1",
})
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

axes[0].plot(
    RESOLUTIONS,
    [selection["selected"]["resolutionContributions"][f"c{r}"]["leaderArealLinkDensity"] for r in RESOLUTIONS],
    marker="o", linewidth=2.6, color="#36d7ff",
)
axes[0].scatter([18], [float(geometry_expected[0])], marker="x", s=95, color="#ff6b9d", label="h-linear expectation")
axes[0].set_title(f"GEOMETRY PHASE  C={geometry_curvature:.3f}")
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

labels = ["geometry", "areal links", "conditional", "full source", "reflected", "interpolation", "moving wall"]
values = [geometry_curvature, curvatures["areal"], curvatures["conditional"], curvatures["source"], component_curvatures["reflectedMomentumExchange"], component_curvatures["interpolationAuxiliary"], component_curvatures["movingWall"]]
bar_colors = ["#36d7ff" if value <= smooth_limit else "#ffd166" if value < persistent_limit else "#ff6b9d" for value in values]
axes[2].barh(labels, values, color=bar_colors)
axes[2].axvline(smooth_limit, color="#36d7ff", linestyle="--", linewidth=1.3, label="smooth limit")
axes[2].axvline(persistent_limit, color="#ff6b9d", linestyle=":", linewidth=1.3, label="persistent-bias limit")
axes[2].invert_yaxis()
axes[2].set_title(classification.replace("Population", " Population"))
axes[2].set_xlabel("normalized h-linear c18 curvature")
axes[2].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

fig.suptitle("BIRDFLOW METAL  /  FORMATION SOURCE CONVERGENCE", color="#f4f8fc", fontsize=17, fontweight="bold", y=0.99)
fig.text(0.5, 0.015, f"common lattice offset {selected_offset}  •  leader phase {prereg['lockedConfiguration']['leaderPhase']}  •  coupled-only five-cycle production TRT", ha="center", color="#90a9c1", fontsize=9)
fig.tight_layout(rect=(0, 0.045, 1, 0.95))
fig.savefig(PNG, dpi=180, facecolor=fig.get_facecolor())
fig.savefig(SVG, facecolor=fig.get_facecolor())
print(f"formation subcell source classification: {classification}")
print(f"source curvature: {curvatures['source']:.9f}")
print(f"summary: {SUMMARY.relative_to(ROOT)}")

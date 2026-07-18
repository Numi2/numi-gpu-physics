#!/usr/bin/env python3
"""Analyze the preregistered no-fluid c18 Formation Flight geometry bridge."""

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
PREREG = ROOT / "ValidationInputs/formation-flight-geometry-c18-bridge-v1.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-geometry-c18-bridge"
REPORT = ARCHIVE / "formation-flight-geometry-census.json"
SUMMARY = ARCHIVE / "formation-flight-geometry-c18-bridge-summary.json"
CSV = ARCHIVE / "formation-flight-geometry-c18-bridge-directions.csv"
PNG = ROOT / "Docs/Media/formation-flight-geometry-c18-bridge.png"
SVG = ROOT / "Docs/Media/formation-flight-geometry-c18-bridge.svg"


def load(path: Path):
    with path.open() as handle:
        return json.load(handle)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def raw_sample(path: Path, flyer: str, target: float):
    samples = [value for value in load(path)["samples"] if value["flyer"] == flyer]
    return min(samples, key=lambda value: abs(value["leaderPhase"] - target))


def report_counts(sample, flyer: str):
    key = "leaderLinkCount" if flyer == "leader" else "followerLinkCount"
    return [int(value[key]) for value in sample["directions"]]


def raw_counts(sample):
    return [int(value["linkCount"]) for value in sample["directions"]]


def weighted_l1(values, weights):
    return float(sum(abs(value) * weight for value, weight in zip(values, weights)))


def classify(between, density, direction, areal):
    if between and max(density, direction, areal) <= 0.5:
        return "monotonicGeometryBridge"
    if (not between) or max(density, direction, areal) >= 1.0:
        return "latticePhaseAliasingSuspected"
    return "mixedGeometryBridge"


prereg = load(PREREG)
report = load(REPORT)
samples = {int(value["chordCells"]): value for value in report["samples"]}
config = prereg["lockedConfiguration"]
resolutions = config["chordCells"]
if sorted(samples) != sorted(resolutions):
    raise SystemExit("geometry report does not contain exactly the locked resolutions")

source_paths = {
    16: ROOT / config["endpointArchives"]["c16"],
    20: ROOT / config["endpointArchives"]["c20"],
}
parity = []
for resolution in (16, 20):
    for flyer in ("leader", "follower"):
        expected = raw_counts(
            raw_sample(source_paths[resolution], flyer, config["leaderPhase"])
        )
        observed = report_counts(samples[resolution], flyer)
        mismatches = [
            q for q, (left, right) in enumerate(zip(observed, expected))
            if left != right
        ]
        parity.append({
            "chordCells": resolution,
            "flyer": flyer,
            "exactDirectionCountParity": not mismatches,
            "mismatchedDirections": mismatches,
            "expectedTotalBoundaryLinkCount": sum(expected),
            "observedTotalBoundaryLinkCount": sum(observed),
        })

directions = samples[16]["directions"]
weights = [
    math.sqrt(sum(component * component for component in value["direction"]))
    for value in directions
]
counts = {
    resolution: np.asarray(report_counts(samples[resolution], "leader"), dtype=float)
    for resolution in resolutions
}
density = {
    resolution: float(counts[resolution].sum() / resolution**2)
    for resolution in resolutions
}
probability = {
    resolution: counts[resolution] / counts[resolution].sum()
    for resolution in resolutions
}
areal = {
    resolution: counts[resolution] / resolution**2
    for resolution in resolutions
}

epsilon = float(prereg["decisionRule"]["denominatorFloor"])
density_midpoint = 0.5 * (density[16] + density[20])
probability_midpoint = 0.5 * (probability[16] + probability[20])
areal_midpoint = 0.5 * (areal[16] + areal[20])
density_curvature = abs(density[18] - density_midpoint) / max(
    abs(density[20] - density[16]), epsilon
)
direction_curvature = (
    0.5 * float(np.abs(probability[18] - probability_midpoint).sum())
) / max(
    0.5 * float(np.abs(probability[20] - probability[16]).sum()), epsilon
)
areal_curvature = weighted_l1(
    areal[18] - areal_midpoint, weights
) / max(weighted_l1(areal[20] - areal[16], weights), epsilon)
density_between = min(density[16], density[20]) <= density[18] <= max(
    density[16], density[20]
)
verdict = classify(
    density_between, density_curvature, direction_curvature, areal_curvature
)

gates = {
    "preregisteredBeforeC18Execution": bool(
        prereg["preregisteredBeforeC18Execution"]
    ),
    "exactC16C20OwnerDirectionParity": all(
        value["exactDirectionCountParity"] for value in parity
    ),
    "noFluidTimesteps": bool(report["gates"]["noFluidTimesteps"]),
    "positiveLinkSupport": bool(report["gates"]["positiveLinkSupport"]),
    "zeroOverlap": bool(report["gates"]["zeroOverlap"]),
    "allFinite": bool(report["gates"]["allFinite"])
        and all(
            math.isfinite(value)
            for value in (density_curvature, direction_curvature, areal_curvature)
        ),
    "reportPassed": bool(report["passed"]),
}
passed = all(gates.values())

rows = []
for resolution in resolutions:
    for q, direction in enumerate(directions):
        rows.append({
            "chordCells": resolution,
            "directionIndex": q,
            "directionX": direction["direction"][0],
            "directionY": direction["direction"][1],
            "directionZ": direction["direction"][2],
            "linkCount": int(counts[resolution][q]),
            "arealLinkMeasure": float(areal[resolution][q]),
            "directionProbability": float(probability[resolution][q]),
            "directionLength": weights[q],
        })
ARCHIVE.mkdir(parents=True, exist_ok=True)
with CSV.open("w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

summary = {
    "schemaVersion": 1,
    "title": "Formation Flight geometry-only c18 bridge",
    "scientificQuestion": prereg["scientificQuestion"],
    "preregistration": {
        "path": str(PREREG.relative_to(ROOT)),
        "sha256": sha256(PREREG),
        "preregisteredBeforeC18Execution": prereg[
            "preregisteredBeforeC18Execution"
        ],
    },
    "rawGeometryReport": str(REPORT.relative_to(ROOT)),
    "deviceName": report["deviceName"],
    "noFluidTimesteps": True,
    "primaryProbe": config["selectedPrimaryProbe"],
    "endpointParity": parity,
    "leaderArealLinkDensity": {f"c{key}": value for key, value in density.items()},
    "decisionMetrics": {
        "densityBetweenEndpoints": density_between,
        "normalizedDensityMidpointCurvature": density_curvature,
        "normalizedDirectionMidpointCurvature": direction_curvature,
        "normalizedArealProfileMidpointCurvature": areal_curvature,
        "smoothRefinementMaximumCurvature": prereg["decisionRule"][
            "smoothRefinementMaximumCurvature"
        ],
        "aliasingMinimumCurvature": prereg["decisionRule"][
            "aliasingMinimumCurvature"
        ],
    },
    "classification": verdict,
    "gates": gates,
    "passed": passed,
    "nextAction": prereg["decisionRule"]["nextActions"][verdict],
    "claimBoundary": prereg["claimBoundary"],
    "csvPath": str(CSV.relative_to(ROOT)),
    "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 10,
    "axes.titleweight": "bold",
})
fig = plt.figure(figsize=(15.5, 8.7), facecolor="#07111f")
grid = fig.add_gridspec(2, 2, height_ratios=[1, 1.13], hspace=0.34, wspace=0.25)
axes = [fig.add_subplot(grid[0, 0]), fig.add_subplot(grid[0, 1]), fig.add_subplot(grid[1, :])]
for axis in axes:
    axis.set_facecolor("#0c1b2d")
    axis.grid(True, color="#8da2b8", alpha=0.16, linewidth=0.8)
    axis.tick_params(colors="#cfdae6")
    for spine in axis.spines.values():
        spine.set_color("#39516b")
    axis.xaxis.label.set_color("#cfdae6")
    axis.yaxis.label.set_color("#cfdae6")
    axis.title.set_color("#f5f8fb")

ax = axes[0]
x = np.asarray(resolutions)
y = np.asarray([density[value] for value in resolutions])
ax.plot([16, 20], [density[16], density[20]], "--", color="#7f91a5", linewidth=1.5, label="endpoint chord")
ax.plot(x, y, color="#4bd6c7", linewidth=2.4, marker="o", markersize=8, label="Metal voxelization")
ax.scatter([18], [density[18]], s=150, facecolor="#ffca5c", edgecolor="#07111f", linewidth=1.5, zorder=5)
ax.set_xticks(resolutions)
ax.set_xlabel("Chord resolution (cells)")
ax.set_ylabel(r"Areal link density  $D_r = N_r/r^2$")
ax.set_title("A. AREAL LINK DENSITY")
ax.legend(frameon=False, labelcolor="#dbe5ef", loc="best")
ax.text(0.03, 0.04, f"midpoint curvature = {density_curvature:.3f}\nbetween endpoints = {str(density_between).lower()}", transform=ax.transAxes, color="#dbe5ef", va="bottom")

ax = axes[1]
q = np.arange(1, 19)
for resolution, color, marker in ((16, "#7498ff", "o"), (18, "#ffca5c", "s"), (20, "#4bd6c7", "^")):
    ax.plot(q, probability[resolution][1:], color=color, marker=marker, markersize=4, linewidth=1.7, label=f"c{resolution}")
ax.set_xticks(q)
ax.set_xlabel("D3Q19 moving direction q")
ax.set_ylabel("Direction probability p(q)")
ax.set_title("B. DIRECTION REDISTRIBUTION")
ax.legend(frameon=False, labelcolor="#dbe5ef", ncol=3)
ax.text(0.03, 0.04, f"normalized TV midpoint curvature = {direction_curvature:.3f}", transform=ax.transAxes, color="#dbe5ef", va="bottom")

ax = axes[2]
width = 0.25
for index, (resolution, color) in enumerate(((16, "#7498ff"), (18, "#ffca5c"), (20, "#4bd6c7"))):
    ax.bar(q + (index - 1) * width, areal[resolution][1:], width=width, color=color, alpha=0.92, label=f"c{resolution}")
ax.set_xticks(q)
ax.set_xlabel("D3Q19 moving direction q")
ax.set_ylabel(r"Areal directional measure  $a_r(q)=N_r(q)/r^2$")
ax.set_title("C. JOINT DENSITY × DIRECTION PROFILE")
ax.legend(frameon=False, labelcolor="#dbe5ef", ncol=3)
ax.text(0.01, 0.96, f"weighted-L1 midpoint curvature = {areal_curvature:.3f}", transform=ax.transAxes, color="#dbe5ef", va="top")

verdict_label = {
    "monotonicGeometryBridge": "MONOTONIC REFINEMENT",
    "latticePhaseAliasingSuspected": "LATTICE-PHASE ALIASING SUSPECTED",
    "mixedGeometryBridge": "MIXED GEOMETRY RESPONSE",
}[verdict]
fig.suptitle("FORMATION FLIGHT • GEOMETRY-ONLY c18 BRIDGE", color="#ffffff", fontsize=20, fontweight="bold", y=0.985)
fig.text(0.5, 0.945, f"{verdict_label}  •  zero fluid timesteps  •  exact c16/c20 archive parity", ha="center", color="#ffca5c", fontsize=12, fontweight="bold")
fig.text(0.5, 0.012, "Prescribed primary pose: leader φ≈0.785, follower φ≈0.035 • Geometry discriminator only — no force or biological claim", ha="center", color="#aab9c8", fontsize=9)
PNG.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(PNG, dpi=220, facecolor=fig.get_facecolor(), bbox_inches="tight")
fig.savefig(SVG, facecolor=fig.get_facecolor(), bbox_inches="tight")
plt.close(fig)

print(json.dumps({
    "passed": passed,
    "classification": verdict,
    "metrics": summary["decisionMetrics"],
    "summary": str(SUMMARY.relative_to(ROOT)),
}, indent=2))
if not passed:
    raise SystemExit("geometry bridge analysis gates failed")

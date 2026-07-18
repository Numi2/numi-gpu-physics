#!/usr/bin/env python3
"""Analyze the preregistered Formation Flight subcell translation ensemble."""

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
PREREG = ROOT / "ValidationInputs/formation-flight-geometry-subcell-ensemble-v1.json"
BRIDGE = ROOT / "ValidationArtifacts/formation-flight-geometry-c18-bridge/formation-flight-geometry-census.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-geometry-subcell-ensemble"
REPORT = ARCHIVE / "formation-flight-geometry-subcell-ensemble.json"
SUMMARY = ARCHIVE / "formation-flight-geometry-subcell-ensemble-summary.json"
CSV = ARCHIVE / "formation-flight-geometry-subcell-ensemble-cases.csv"
PNG = ROOT / "Docs/Media/formation-flight-geometry-subcell-ensemble.png"
SVG = ROOT / "Docs/Media/formation-flight-geometry-subcell-ensemble.svg"


def load(path):
    with path.open() as handle:
        return json.load(handle)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def key(value):
    offset = value["offsetCells"]
    return (int(value["chordCells"]), float(offset[0]), float(offset[1]), float(offset[2]))


def counts(value, flyer="leader"):
    field = "leaderLinkCount" if flyer == "leader" else "followerLinkCount"
    return np.asarray([int(item[field]) for item in value["directions"]], dtype=float)


def classify(between, density, direction, areal):
    if between and max(density, direction, areal) <= 0.5:
        return "aliasingAveragedOut"
    if (not between) or max(density, direction, areal) >= 1.0:
        return "persistentResolutionBias"
    return "mixedSubcellSensitivity"


prereg = load(PREREG)
report = load(REPORT)
bridge = load(BRIDGE)
cases = {key(value): value for value in report["cases"]}
resolutions = prereg["lockedConfiguration"]["chordCells"]
divisions = prereg["lockedConfiguration"]["offsetDivisionsPerAxis"]
offset_values = [index / divisions for index in range(divisions)]
offsets = [
    (x, y, z)
    for z in offset_values
    for y in offset_values
    for x in offset_values
]
expected_keys = {
    (resolution, x, y, z)
    for resolution in resolutions
    for x, y, z in offsets
}
if set(cases) != expected_keys:
    raise SystemExit("subcell report does not contain the exact tensor grid")

baseline_parity = []
bridge_samples = {int(value["chordCells"]): value for value in bridge["samples"]}
for resolution in resolutions:
    observed = cases[(resolution, 0.0, 0.0, 0.0)]
    expected = bridge_samples[resolution]
    for flyer in ("leader", "follower"):
        observed_counts = counts(observed, flyer)
        field = "leaderLinkCount" if flyer == "leader" else "followerLinkCount"
        expected_counts = np.asarray(
            [int(value[field]) for value in expected["directions"]],
            dtype=float,
        )
        mismatches = np.flatnonzero(observed_counts != expected_counts).tolist()
        baseline_parity.append({
            "chordCells": resolution,
            "flyer": flyer,
            "exactDirectionCountParity": not mismatches,
            "mismatchedDirections": mismatches,
            "observedTotal": int(observed_counts.sum()),
            "expectedTotal": int(expected_counts.sum()),
        })

direction_records = report["cases"][0]["directions"]
weights = np.asarray([
    math.sqrt(sum(component * component for component in value["direction"]))
    for value in direction_records
])
density = {resolution: [] for resolution in resolutions}
probability = {resolution: [] for resolution in resolutions}
areal = {resolution: [] for resolution in resolutions}
rows = []
for resolution in resolutions:
    for offset in offsets:
        value = cases[(resolution, *offset)]
        vector = counts(value)
        total = float(vector.sum())
        d = total / resolution**2
        p = vector / total
        a = vector / resolution**2
        density[resolution].append(d)
        probability[resolution].append(p)
        areal[resolution].append(a)
        rows.append({
            "chordCells": resolution,
            "offsetXCells": offset[0],
            "offsetYCells": offset[1],
            "offsetZCells": offset[2],
            "leaderBoundaryLinkCount": int(total),
            "followerBoundaryLinkCount": value["totalFollowerBoundaryLinkCount"],
            "leaderArealLinkDensity": d,
            "overlapVoxelCount": value["overlapVoxelCount"],
            "runtimeSeconds": value["runtimeSeconds"],
        })
    density[resolution] = np.asarray(density[resolution])
    probability[resolution] = np.asarray(probability[resolution])
    areal[resolution] = np.asarray(areal[resolution])

with CSV.open("w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

mean_density = {resolution: float(density[resolution].mean()) for resolution in resolutions}
mean_probability = {resolution: probability[resolution].mean(axis=0) for resolution in resolutions}
mean_areal = {resolution: areal[resolution].mean(axis=0) for resolution in resolutions}
floor = float(prereg["decisionRule"]["denominatorFloor"])
density_midpoint = 0.5 * (mean_density[16] + mean_density[20])
density_curvature = abs(mean_density[18] - density_midpoint) / max(
    abs(mean_density[20] - mean_density[16]), floor
)
probability_midpoint = 0.5 * (mean_probability[16] + mean_probability[20])
direction_curvature = (
    0.5 * np.abs(mean_probability[18] - probability_midpoint).sum()
) / max(0.5 * np.abs(mean_probability[20] - mean_probability[16]).sum(), floor)
areal_midpoint = 0.5 * (mean_areal[16] + mean_areal[20])
areal_curvature = float(
    (weights * np.abs(mean_areal[18] - areal_midpoint)).sum()
) / max(float((weights * np.abs(mean_areal[20] - mean_areal[16])).sum()), floor)
between = min(mean_density[16], mean_density[20]) <= mean_density[18] <= max(
    mean_density[16], mean_density[20]
)
classification = classify(
    between, density_curvature, direction_curvature, areal_curvature
)
matched_residual = density[18] - 0.5 * (density[16] + density[20])
baseline_residual = float(matched_residual[0])

def statistics(values):
    return {
        "minimum": float(values.min()),
        "percentile2_5": float(np.percentile(values, 2.5)),
        "mean": float(values.mean()),
        "standardDeviation": float(values.std(ddof=1)),
        "percentile97_5": float(np.percentile(values, 97.5)),
        "maximum": float(values.max()),
        "relativeStandardDeviationToMeanMagnitude": float(
            values.std(ddof=1) / max(abs(values.mean()), 1e-12)
        ),
    }


statistics_by_resolution = {
    f"c{resolution}": statistics(density[resolution])
    for resolution in resolutions
}
gates = {
    "preregisteredBeforeEnsembleExecution": prereg[
        "preregisteredBeforeEnsembleExecution"
    ],
    "exactBaselineBridgeParity": all(
        value["exactDirectionCountParity"] for value in baseline_parity
    ),
    "completeTensorGrid": report["gates"]["completeTensorGrid"]
        and len(cases) == 192,
    "noFluidTimesteps": report["gates"]["noFluidTimesteps"],
    "positiveLinkSupport": report["gates"]["positiveLinkSupport"],
    "zeroOverlap": report["gates"]["zeroOverlap"],
    "allFinite": report["gates"]["allFinite"]
        and all(math.isfinite(value) for value in (
            density_curvature,
            direction_curvature,
            areal_curvature,
            baseline_residual,
        )),
    "reportPassed": report["passed"],
}
passed = all(gates.values())
summary = {
    "schemaVersion": 1,
    "title": "Formation Flight geometry-only subcell-offset ensemble",
    "scientificQuestion": prereg["scientificQuestion"],
    "preregistration": {
        "path": str(PREREG.relative_to(ROOT)),
        "sha256": digest(PREREG),
        "preregisteredBeforeEnsembleExecution": prereg[
            "preregisteredBeforeEnsembleExecution"
        ],
    },
    "rawReport": str(REPORT.relative_to(ROOT)),
    "deviceName": report["deviceName"],
    "caseCount": len(cases),
    "offsetCountPerResolution": len(offsets),
    "noFluidTimesteps": True,
    "baselineParity": baseline_parity,
    "leaderDensityStatistics": statistics_by_resolution,
    "matchedMidpointResidualStatistics": statistics(matched_residual),
    "baselineMatchedMidpointResidual": baseline_residual,
    "decisionMetrics": {
        "meanDensityBetweenEndpoints": between,
        "normalizedMeanDensityMidpointCurvature": float(density_curvature),
        "normalizedMeanDirectionMidpointCurvature": float(direction_curvature),
        "normalizedMeanArealProfileMidpointCurvature": float(areal_curvature),
        "smoothRefinementMaximumCurvature": prereg["decisionRule"][
            "smoothRefinementMaximumCurvature"
        ],
        "persistentBiasMinimumCurvature": prereg["decisionRule"][
            "persistentBiasMinimumCurvature"
        ],
    },
    "classification": classification,
    "gates": gates,
    "passed": passed,
    "nextAction": prereg["decisionRule"]["nextActions"][classification],
    "claimBoundary": prereg["claimBoundary"],
    "csvPath": str(CSV.relative_to(ROOT)),
    "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 9, "axes.titleweight": "bold"})
fig = plt.figure(figsize=(16, 9), facecolor="#06101c")
gs = fig.add_gridspec(2, 3, height_ratios=[1, 1.05], hspace=0.34, wspace=0.28)
axes = [fig.add_subplot(gs[0, 0]), fig.add_subplot(gs[0, 1:]), fig.add_subplot(gs[1, 0:2])]
heat_gs = gs[1, 2].subgridspec(2, 2, hspace=0.18, wspace=0.12)
heat_axes = [fig.add_subplot(heat_gs[index // 2, index % 2]) for index in range(4)]
for axis in axes + heat_axes:
    axis.set_facecolor("#0b1b2d")
    axis.tick_params(colors="#cbd8e5")
    for spine in axis.spines.values():
        spine.set_color("#35516d")
    axis.xaxis.label.set_color("#cbd8e5")
    axis.yaxis.label.set_color("#cbd8e5")
    axis.title.set_color("#f4f8fc")

ax = axes[0]
colors = ["#7198ff", "#ffca5c", "#48d1c2"]
positions = np.arange(3)
parts = ax.violinplot([density[r] for r in resolutions], positions=positions, showextrema=False, widths=0.76)
for body, color in zip(parts["bodies"], colors):
    body.set_facecolor(color)
    body.set_edgecolor(color)
    body.set_alpha(0.34)
for index, resolution in enumerate(resolutions):
    jitter = np.linspace(-0.18, 0.18, len(offsets))
    ax.scatter(index + jitter, np.sort(density[resolution]), s=8, color=colors[index], alpha=0.58)
    ax.scatter(index, density[resolution][0], marker="D", s=65, color="#ffffff", edgecolor=colors[index], linewidth=1.6, zorder=5)
ax.set_xticks(positions, [f"c{value}" for value in resolutions])
ax.set_ylabel(r"Areal link density $D=N/r^2$")
ax.set_title("A. 64 GLOBAL SUBCELL PHASES PER GRID")
ax.grid(True, axis="y", alpha=0.14)
ax.text(0.04, 0.04, "white diamond = original lattice phase", transform=ax.transAxes, color="#b8c8d8")

ax = axes[1]
q = np.arange(1, 19)
for resolution, color in zip(resolutions, colors):
    profiles = probability[resolution][:, 1:]
    lo = np.percentile(profiles, 2.5, axis=0)
    hi = np.percentile(profiles, 97.5, axis=0)
    mean = profiles.mean(axis=0)
    ax.fill_between(q, lo, hi, color=color, alpha=0.16)
    ax.plot(q, mean, color=color, marker="o", markersize=3, linewidth=1.8, label=f"c{resolution} mean + 95% band")
ax.set_xticks(q)
ax.set_xlabel("D3Q19 moving direction q")
ax.set_ylabel("Direction probability p(q)")
ax.set_title("B. DIRECTION DISTRIBUTION UNDER LATTICE PHASE")
ax.grid(True, alpha=0.14)
ax.legend(frameon=False, labelcolor="#dce6ef", ncol=3, loc="upper left")

ax = axes[2]
ax.hist(matched_residual, bins=15, color="#ffca5c", alpha=0.78, edgecolor="#0b1b2d")
ax.axvline(0, color="#48d1c2", linewidth=1.5)
ax.axvline(baseline_residual, color="#ffffff", linewidth=1.5, linestyle="--", label=f"original phase {baseline_residual:+.4f}")
ax.axvline(matched_residual.mean(), color="#ff7a59", linewidth=2, label=f"ensemble mean {matched_residual.mean():+.4f}")
ax.set_xlabel(r"Matched density residual $D_{18}-(D_{16}+D_{20})/2$")
ax.set_ylabel("Subcell offsets")
ax.set_title("C. DOES SUBCELL AVERAGING REMOVE THE c18 EXCURSION?")
ax.grid(True, axis="y", alpha=0.14)
ax.legend(frameon=False, labelcolor="#dce6ef")

residual_cube = matched_residual.reshape(divisions, divisions, divisions)
limit = max(abs(residual_cube.min()), abs(residual_cube.max()))
for index, (axis, z) in enumerate(zip(heat_axes, offset_values)):
    image = axis.imshow(residual_cube[index], origin="lower", cmap="coolwarm", vmin=-limit, vmax=limit)
    axis.set_xticks(range(divisions), [f"{value:.2g}" for value in offset_values], fontsize=6)
    axis.set_yticks(range(divisions), [f"{value:.2g}" for value in offset_values], fontsize=6)
    axis.set_title(f"z={z:.2g}", fontsize=8)
    if index >= 2: axis.set_xlabel("x offset", fontsize=7)
    if index % 2 == 0: axis.set_ylabel("y offset", fontsize=7)
fig.colorbar(image, ax=heat_axes, shrink=0.68, pad=0.03, label="matched residual")

label = {
    "aliasingAveragedOut": "SUBCELL AVERAGING RESTORES SMOOTH REFINEMENT",
    "persistentResolutionBias": "RESOLUTION BIAS PERSISTS AFTER SUBCELL AVERAGING",
    "mixedSubcellSensitivity": "MIXED SUBCELL SENSITIVITY",
}[classification]
fig.suptitle("FORMATION FLIGHT • 192-POSE SUBCELL OBSERVATORY", color="#ffffff", fontsize=20, fontweight="bold", y=0.985)
fig.text(0.5, 0.947, f"{label}  •  zero fluid timesteps  •  exact original-phase replay", ha="center", color="#ffca5c", fontsize=11, fontweight="bold")
fig.text(0.5, 0.012, "4 × 4 × 4 global translations at each of c16/c18/c20 • geometry uncertainty only — no force or biological claim", ha="center", color="#aab9c8", fontsize=9)
PNG.parent.mkdir(parents=True, exist_ok=True)
fig.savefig(PNG, dpi=220, facecolor=fig.get_facecolor(), bbox_inches="tight")
fig.savefig(SVG, facecolor=fig.get_facecolor(), bbox_inches="tight")
plt.close(fig)

print(json.dumps({
    "passed": passed,
    "classification": classification,
    "decisionMetrics": summary["decisionMetrics"],
    "summary": str(SUMMARY.relative_to(ROOT)),
}, indent=2))
if not passed:
    raise SystemExit("formation subcell ensemble analysis failed")

#!/usr/bin/env python3
"""Analyze the preregistered leader/q5 c18 final-cycle source trace."""

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
PREREG = ROOT / "ValidationInputs/formation-flight-focused-source-trace-v1.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-focused-source-trace"
REPORT = ARCHIVE / "formation-flight-focused-source-trace-report.json"
SUMMARY = ARCHIVE / "formation-flight-focused-source-trace-summary.json"
CSV = ARCHIVE / "formation-flight-focused-source-trace.csv"
PNG = ROOT / "Docs/Media/formation-flight-focused-source-trace.png"
SVG = ROOT / "Docs/Media/formation-flight-focused-source-trace.svg"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def correlation(lhs: np.ndarray, rhs: np.ndarray) -> float:
    if lhs.size < 2 or np.std(lhs) <= 1e-20 or np.std(rhs) <= 1e-20:
        return 0.0
    return float(np.corrcoef(lhs, rhs)[0, 1])


def circular_energy_window(energy: np.ndarray, target: float) -> dict:
    count = len(energy)
    total = float(np.sum(energy))
    if count == 0 or total <= 0:
        return {
            "startBin": 0,
            "endBinExclusive": 0,
            "wraps": False,
            "binCount": 0,
            "widthCycles": 0.0,
            "capturedEnergyShare": 0.0,
        }
    doubled = np.concatenate([energy, energy])
    best: tuple[int, int, float] | None = None
    for start in range(count):
        accumulated = 0.0
        for width in range(1, count + 1):
            accumulated += float(doubled[start + width - 1])
            if accumulated / total >= target:
                candidate = (width, start, accumulated)
                if best is None or candidate[:2] < best[:2]:
                    best = candidate
                break
    assert best is not None
    width, start, accumulated = best
    end = start + width
    return {
        "startBin": start,
        "endBinExclusive": end % count,
        "wraps": end > count,
        "binCount": width,
        "widthCycles": width / count,
        "capturedEnergyShare": accumulated / total,
    }


prereg = load(PREREG)
report = load(REPORT)
samples = report["samples"]
phase = np.asarray([row["leaderPhase"] for row in samples], dtype=float)
step = np.asarray([row["stepWithinCycle"] for row in samples], dtype=int)
absolute_step = np.asarray([row["absoluteStep"] for row in samples], dtype=int)
source_rows = [row["source"] for row in samples]
raw = np.asarray([row["rawReflectedPopulationSum"] for row in source_rows])
reflected_in = np.asarray([
    row["reflectedIncomingPopulationSum"] for row in source_rows
])
auxiliary = np.asarray([
    row["interpolationAuxiliaryPopulationSum"] for row in source_rows
])
wall = np.asarray([row["movingWallPopulationSum"] for row in source_rows])
incoming = np.asarray([
    row["reconstructedIncomingPopulationSum"] for row in source_rows
])
links = np.asarray([row["linkCount"] for row in source_rows], dtype=float)
near = np.asarray([
    row["nearInterpolationLinkCount"] for row in source_rows
], dtype=float)
far = np.asarray([
    row["farInterpolationLinkCount"] for row in source_rows
], dtype=float)
fallback = np.asarray([
    row["halfwayFallbackLinkCount"] for row in source_rows
], dtype=float)
reflected = raw + reflected_in
exact_source = raw + incoming
reconstructed_source = reflected + auxiliary + wall
safe_links = np.maximum(links, 1.0)
reflected_per_link = reflected / safe_links
near_fraction = near / safe_links
far_fraction = far / safe_links
fallback_fraction = fallback / safe_links

bins = int(prereg["temporalAnalysis"]["phaseBinCount"])
bin_index = np.minimum((phase * bins).astype(int), bins - 1)
bin_index[phase == 0] = bins - 1
bin_phase = (np.arange(bins) + 0.5) / bins


def binned_mean(values: np.ndarray) -> np.ndarray:
    return np.asarray([
        float(np.mean(values[bin_index == index]))
        if np.any(bin_index == index) else math.nan
        for index in range(bins)
    ])


bin_reflected = binned_mean(reflected)
bin_reflected_per_link = binned_mean(reflected_per_link)
bin_exact = binned_mean(exact_source)
bin_links = binned_mean(links)
bin_near_fraction = binned_mean(near_fraction)
bin_far_fraction = binned_mean(far_fraction)

centered = bin_reflected - float(np.mean(bin_reflected))
energy = centered * centered
window = circular_energy_window(
    energy,
    float(prereg["temporalAnalysis"]["centeredEnergyTargetShare"]),
)
window["startPhase"] = window["startBin"] / bins
window["endPhase"] = window["endBinExclusive"] / bins
window["targetEnergyShare"] = float(
    prereg["temporalAnalysis"]["centeredEnergyTargetShare"]
)

topology_turnover = np.zeros_like(links)
topology_turnover[1:] = (
    np.abs(near_fraction[1:] - near_fraction[:-1])
    + np.abs(far_fraction[1:] - far_fraction[:-1])
    + np.abs(links[1:] - links[:-1]) / np.maximum(links[1:], 1.0)
)
topology_turnover[0] = (
    abs(near_fraction[0] - near_fraction[-1])
    + abs(far_fraction[0] - far_fraction[-1])
    + abs(links[0] - links[-1]) / max(links[0], 1.0)
)

peak_index = int(np.argmax(reflected))
peak_per_link_index = int(np.argmax(reflected_per_link))
turnover_index = int(np.argmax(topology_turnover))
anchor_index = min(
    range(len(samples)),
    key=lambda index: min(
        abs(phase[index] - report["referenceLeaderPhaseAnchor"]),
        1 - abs(phase[index] - report["referenceLeaderPhaseAnchor"]),
    ),
)

centered_step_reflected = reflected - float(np.mean(reflected))
correlations = {
    "reflectedMomentumExchangeVsLinkCount": correlation(reflected, links),
    "reflectedMomentumExchangePerLinkVsNearFraction": correlation(
        reflected_per_link, near_fraction
    ),
    "reflectedMomentumExchangePerLinkVsFarFraction": correlation(
        reflected_per_link, far_fraction
    ),
    "centeredReflectedMomentumExchangeVsTopologyTurnover": correlation(
        centered_step_reflected, topology_turnover
    ),
}
maximum_branch_association = max(
    abs(correlations["reflectedMomentumExchangePerLinkVsNearFraction"]),
    abs(correlations["reflectedMomentumExchangePerLinkVsFarFraction"]),
)
localized = window["widthCycles"] <= float(
    prereg["decisionRule"]["maximumLocalizedWindowWidthCycles"]
)
branch_associated = maximum_branch_association >= float(
    prereg["decisionRule"]["minimumAbsoluteBranchAssociation"]
)
if localized and branch_associated:
    classification = "temporallyLocalizedBranchAssociated"
elif localized:
    classification = "temporallyLocalizedMixedBranches"
elif branch_associated:
    classification = "cycleDistributedBranchAssociated"
else:
    classification = "cycleDistributedMixedBranches"

phase_order = np.argsort(phase)
with CSV.open("w", newline="") as handle:
    writer = csv.writer(handle)
    writer.writerow([
        "stepWithinCycle",
        "absoluteStep",
        "leaderPhase",
        "reflectedMomentumExchange",
        "exactSource",
        "interpolationAuxiliary",
        "movingWall",
        "linkCount",
        "nearLinkCount",
        "farLinkCount",
        "fallbackLinkCount",
        "nearFraction",
        "farFraction",
        "topologyTurnover",
    ])
    for index in range(len(samples)):
        writer.writerow([
            int(step[index]),
            int(absolute_step[index]),
            float(phase[index]),
            float(reflected[index]),
            float(exact_source[index]),
            float(auxiliary[index]),
            float(wall[index]),
            int(links[index]),
            int(near[index]),
            int(far[index]),
            int(fallback[index]),
            float(near_fraction[index]),
            float(far_fraction[index]),
            float(topology_turnover[index]),
        ])

summary = {
    "schemaVersion": 1,
    "title": "Formation c18 focused boundary-source temporal trace",
    "scientificScope": report["scientificScope"],
    "classification": classification,
    "selection": {
        "flyer": report["flyer"],
        "component": prereg["lockedSelection"]["component"],
        "directionIndex": report["directionIndex"],
        "direction": report["direction"],
        "subcellOffsetCells": report["subcellOffsetCells"],
        "chordCells": report["configuration"]["chordCells"],
        "cycleSteps": report["cycleSteps"],
        "capturedFinalCycleSampleCount": len(samples),
    },
    "integrity": {
        "reportPassed": report["gates"]["passed"],
        "maximumRelativeReconstructionClosureResidual": report["gates"][
            "maximumRelativeReconstructionClosureResidual"
        ],
        "relativeReferenceLoadSummaryDifference": report["gates"][
            "relativeReferenceLoadSummaryDifference"
        ],
        "maximumRelativeReferenceAnchorSourceDifference": report["gates"][
            "maximumRelativeReferenceAnchorSourceDifference"
        ],
        "maximumAbsoluteAdditiveSourceClosure": float(
            np.max(np.abs(exact_source - reconstructed_source))
        ),
        "referenceReportSHA256": report["referenceReportSHA256"],
        "traceReportSHA256": digest(REPORT),
    },
    "temporalLocalization": {
        "phaseBinCount": bins,
        "centeredEnergyWindow": window,
        "localized": localized,
        "peakReflectedMomentumExchange": {
            "stepWithinCycle": int(step[peak_index]),
            "leaderPhase": float(phase[peak_index]),
            "value": float(reflected[peak_index]),
            "linkCount": int(links[peak_index]),
        },
        "peakPerLinkReflectedMomentumExchange": {
            "stepWithinCycle": int(step[peak_per_link_index]),
            "leaderPhase": float(phase[peak_per_link_index]),
            "value": float(reflected_per_link[peak_per_link_index]),
            "nearFraction": float(near_fraction[peak_per_link_index]),
            "farFraction": float(far_fraction[peak_per_link_index]),
        },
        "peakTopologyTurnover": {
            "stepWithinCycle": int(step[turnover_index]),
            "leaderPhase": float(phase[turnover_index]),
            "value": float(topology_turnover[turnover_index]),
        },
        "anchor": {
            "stepWithinCycle": int(step[anchor_index]),
            "leaderPhase": float(phase[anchor_index]),
            "reflectedMomentumExchange": float(reflected[anchor_index]),
            "nearFraction": float(near_fraction[anchor_index]),
            "farFraction": float(far_fraction[anchor_index]),
        },
    },
    "branchAssociation": {
        "correlations": correlations,
        "maximumAbsoluteNearOrFarAssociation": maximum_branch_association,
        "branchAssociated": branch_associated,
        "meanNearFraction": float(np.mean(near_fraction)),
        "meanFarFraction": float(np.mean(far_fraction)),
        "meanFallbackFraction": float(np.mean(fallback_fraction)),
        "maximumFallbackLinkCount": int(np.max(fallback)),
        "interpretationBoundary": "branch counts identify topology occupancy and association; they do not assign population contribution independently to each branch",
    },
    "runtimeSeconds": report["runtimeSeconds"],
    "outputs": {
        "csv": str(CSV.relative_to(ROOT)),
        "figurePNG": str(PNG.relative_to(ROOT)),
        "figureSVG": str(SVG.relative_to(ROOT)),
    },
    "nextAction": prereg["decisionRule"]["nextActions"][classification],
    "claimBoundary": prereg["claimBoundary"],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "axes.facecolor": "#0b1422",
    "figure.facecolor": "#07101c",
    "axes.edgecolor": "#6b7f99",
    "axes.labelcolor": "#dbe9f7",
    "xtick.color": "#b8cadb",
    "ytick.color": "#b8cadb",
    "text.color": "#eef7ff",
    "grid.color": "#32445a",
})
figure, axes = plt.subplots(3, 1, figsize=(13.5, 11.5), sharex=True)
ordered_phase = phase[phase_order]
axes[0].plot(
    ordered_phase,
    reflected[phase_order],
    color="#31d6ff",
    linewidth=1.6,
    label="reflected momentum exchange",
)
axes[0].plot(
    ordered_phase,
    exact_source[phase_order],
    color="#ffcc66",
    linewidth=1.15,
    alpha=0.9,
    label="exact q5 source",
)
axes[0].axvline(
    report["referenceLeaderPhaseAnchor"],
    color="#ff6fae",
    linewidth=1.5,
    linestyle="--",
    label="locked anchor",
)
axes[0].set_ylabel("population sum")
axes[0].set_title(
    "Formation Flight Observatory — leader q5 final-cycle source trace",
    fontsize=16,
    fontweight="bold",
    loc="left",
)
axes[0].legend(ncol=3, frameon=False, loc="upper right")

axes[1].fill_between(
    ordered_phase,
    0,
    near[phase_order],
    color="#5df0a5",
    alpha=0.82,
    label="near interpolation links",
)
axes[1].fill_between(
    ordered_phase,
    near[phase_order],
    near[phase_order] + far[phase_order],
    color="#9f7cff",
    alpha=0.82,
    label="far interpolation links",
)
if np.max(fallback) > 0:
    axes[1].fill_between(
        ordered_phase,
        near[phase_order] + far[phase_order],
        links[phase_order],
        color="#ff7b72",
        alpha=0.82,
        label="halfway fallback links",
    )
axes[1].set_ylabel("q5 boundary links")
axes[1].legend(ncol=3, frameon=False, loc="upper right")

axes[2].plot(
    bin_phase,
    bin_reflected_per_link,
    color="#31d6ff",
    linewidth=2.4,
    marker="o",
    markersize=3.5,
    label="reflected exchange / link",
)
turnover_scale = float(np.max(bin_reflected_per_link)) / max(
    float(np.max(topology_turnover)), 1e-12
)
axes[2].plot(
    ordered_phase,
    topology_turnover[phase_order] * turnover_scale,
    color="#ff6fae",
    linewidth=0.9,
    alpha=0.72,
    label="topology turnover (scaled)",
)
start = window["startPhase"]
end = window["endPhase"]
if window["wraps"]:
    axes[2].axvspan(start, 1, color="#ffcc66", alpha=0.15)
    axes[2].axvspan(0, end, color="#ffcc66", alpha=0.15)
else:
    axes[2].axvspan(start, end, color="#ffcc66", alpha=0.15)
axes[2].set_ylabel("per-link source")
axes[2].set_xlabel("leader wingbeat phase")
axes[2].legend(ncol=2, frameon=False, loc="upper right")
axes[2].text(
    0.01,
    0.04,
    f"50% centered-energy window: {window['widthCycles']:.3f} cycles   |   "
    f"near/far association: {maximum_branch_association:.3f}   |   "
    f"audit gate: {'PASS' if report['gates']['passed'] else 'FAIL'}",
    transform=axes[2].transAxes,
    fontsize=10.5,
    color="#dbe9f7",
)
for axis in axes:
    axis.grid(True, linewidth=0.55, alpha=0.42)
    axis.set_xlim(0, 1)
figure.tight_layout(pad=2.2)
PNG.parent.mkdir(parents=True, exist_ok=True)
figure.savefig(PNG, dpi=180, bbox_inches="tight")
figure.savefig(SVG, bbox_inches="tight")
plt.close(figure)

print(json.dumps({
    "classification": classification,
    "traceReportPassed": report["gates"]["passed"],
    "windowWidthCycles": window["widthCycles"],
    "maximumBranchAssociation": maximum_branch_association,
    "summary": str(SUMMARY.relative_to(ROOT)),
}, indent=2, sort_keys=True))

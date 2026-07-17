#!/usr/bin/env python3
"""Render a publication plate from the archived c20 Formation Observatory fields.

The plate uses four real GPU-resident field captures.  It does not interpolate
between CFD phases; the phase rail makes the two observed midstroke windows
explicit.
"""

from __future__ import annotations

import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-c20-cfd-phase-plate-v1"
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PROMOTION = ROOT / "ValidationArtifacts/formation-flight-promotion"
CASE = PROMOTION / "c20-best-z3-phase025"
SLICES = CASE / "formation-flight-flow-slices"
SUMMARY = PROMOTION / "formation-flight-c20-discriminator-summary.json"
PNG = ROOT / "Docs/Media/formation-flight-c20-cfd-phase-plate.png"
SVG = ROOT / "Docs/Media/formation-flight-c20-cfd-phase-plate.svg"
TARGET_FOLLOWER_PHASES = (0.205, 0.255, 0.705, 0.755)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def select_slices() -> list[tuple[dict, dict]]:
    index = load(SLICES / "index.json")
    candidates = [
        entry
        for entry in index["entries"]
        if entry["leaderPhase"] != 0
        and (
            0.20 <= entry["followerPhase"] < 0.30
            or 0.70 <= entry["followerPhase"] < 0.80
        )
    ]
    if len(candidates) != 20:
        raise SystemExit(f"expected 20 archived midstroke fields, found {len(candidates)}")
    selected = []
    for target in TARGET_FOLLOWER_PHASES:
        entry = min(candidates, key=lambda item: abs(item["followerPhase"] - target))
        selected.append((entry, load(SLICES / entry["file"])))
    if len({entry["file"] for entry, _ in selected}) != len(selected):
        raise SystemExit("phase selection did not produce four unique fields")
    return selected


def field_arrays(slice_data: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    shape = (slice_data["height"], slice_data["width"])
    vertical = np.asarray(
        slice_data["verticalVelocityMetersPerSecond"], dtype=float
    ).reshape(shape)
    vorticity = np.asarray(
        slice_data["vorticityMagnitudePerSecond"], dtype=float
    ).reshape(shape)
    owner = np.asarray(slice_data["ownerMask"], dtype=int).reshape(shape)
    return vertical, vorticity, owner


def main() -> int:
    summary = load(SUMMARY)
    selected = select_slices()
    if summary["stage1"]["flowCapture"]["sliceCount"] != 21:
        raise SystemExit("c20 summary is not locked to the 21-slice archive")
    if summary["stage1"]["passed"] or summary["quantitativeFormationClaimAuthorized"]:
        raise SystemExit("plate contract expects the stopped, non-converged c20 result")

    arrays = [field_arrays(slice_data) for _, slice_data in selected]
    fluid_vertical = np.concatenate(
        [vertical[owner == 0] for vertical, _, owner in arrays]
    )
    fluid_vorticity = np.concatenate(
        [vorticity[owner == 0] for _, vorticity, owner in arrays]
    )
    velocity_limit = max(float(np.quantile(np.abs(fluid_vertical), 0.995)), 1e-8)
    vorticity_levels = np.quantile(fluid_vorticity, [0.90, 0.97, 0.995])
    if not np.all(np.diff(vorticity_levels) > 0):
        raise SystemExit("archived vorticity does not support three distinct contours")

    cmap = LinearSegmentedColormap.from_list(
        "birdflow_signed_vertical",
        [
            (0.00, "#075fb8"),
            (0.22, "#16b9f2"),
            (0.48, "#071521"),
            (0.52, "#071521"),
            (0.78, "#ff9f43"),
            (1.00, "#ff4d3d"),
        ],
    )

    figure, axes = plt.subplots(2, 2, figsize=(16, 9), constrained_layout=False)
    figure.patch.set_facecolor("#06131e")
    figure.subplots_adjust(left=0.065, right=0.91, top=0.80, bottom=0.145, hspace=0.25, wspace=0.12)

    image = None
    panel_letters = "ABCD"
    for panel_index, (axis, (entry, slice_data), array_set) in enumerate(
        zip(axes.flat, selected, arrays)
    ):
        vertical, vorticity, owner = array_set
        chord = slice_data["chordCells"]
        extent = (
            -0.5 * slice_data["width"] / chord,
            0.5 * slice_data["width"] / chord,
            -0.5 * slice_data["height"] / chord,
            0.5 * slice_data["height"] / chord,
        )
        fluid = np.ma.masked_where(owner != 0, vertical)
        image = axis.imshow(
            fluid,
            origin="lower",
            extent=extent,
            cmap=cmap,
            norm=Normalize(-velocity_limit, velocity_limit),
            interpolation="bilinear",
            rasterized=True,
        )
        x = np.linspace(extent[0], extent[1], slice_data["width"])
        z = np.linspace(extent[2], extent[3], slice_data["height"])
        axis.contour(
            x,
            z,
            np.ma.masked_where(owner != 0, vorticity),
            levels=vorticity_levels,
            colors=("#a0e9ff", "#f7d774", "#ffffff"),
            linewidths=(0.40, 0.62, 0.92),
            alpha=(0.38, 0.62, 0.92),
        )
        axis.contourf(
            x,
            z,
            np.where(owner == 1, 1.0, np.nan),
            levels=(0.5, 1.5),
            colors=("#18c5f4",),
            alpha=0.95,
        )
        axis.contourf(
            x,
            z,
            np.where(owner == 2, 1.0, np.nan),
            levels=(0.5, 1.5),
            colors=("#ff793d",),
            alpha=0.95,
        )
        axis.contour(x, z, owner == 1, levels=(0.5,), colors=("#d9f8ff",), linewidths=0.7)
        axis.contour(x, z, owner == 2, levels=(0.5,), colors=("#ffe0cb",), linewidths=0.7)
        axis.set_facecolor("#06131e")
        axis.set_aspect("equal")
        axis.set_xlim(-4.8, 4.8)
        axis.set_ylim(-5.7, 5.7)
        axis.set_xticks((-4, -2, 0, 2, 4))
        axis.set_yticks((-4, -2, 0, 2, 4))
        axis.tick_params(colors="#7395a9", labelsize=7, length=2)
        axis.grid(color="#4c7083", alpha=0.13, linewidth=0.5)
        for spine in axis.spines.values():
            spine.set_color("#24465a")
        axis.set_xlabel("x / chord", fontsize=8, color="#8baaba", labelpad=2)
        axis.set_ylabel("z / chord", fontsize=8, color="#8baaba", labelpad=3)
        axis.text(
            0.017,
            0.965,
            panel_letters[panel_index],
            transform=axis.transAxes,
            va="top",
            ha="left",
            color="#e6f8ff",
            fontsize=13,
            fontweight="bold",
            bbox={"boxstyle": "round,pad=0.25", "facecolor": "#06131e", "edgecolor": "#3d6579", "alpha": 0.88},
        )
        axis.text(
            0.985,
            0.965,
            f"follower phase {entry['followerPhase']:.3f}\nleader phase {entry['leaderPhase']:.3f}",
            transform=axis.transAxes,
            va="top",
            ha="right",
            color="#d8eef8",
            fontsize=8.5,
            linespacing=1.35,
            bbox={"boxstyle": "round,pad=0.35", "facecolor": "#06131e", "edgecolor": "#24465a", "alpha": 0.82},
        )

    assert image is not None
    color_axis = figure.add_axes((0.93, 0.205, 0.015, 0.50))
    colorbar = figure.colorbar(image, cax=color_axis)
    colorbar.set_label("vertical velocity w (m/s)", color="#afcad8", fontsize=8)
    colorbar.ax.tick_params(colors="#89aabb", labelsize=7)
    colorbar.outline.set_edgecolor("#365a6d")

    stage1 = summary["stage1"]
    residual = stage1["phaseResolvedFinePair"]["normalizedPowerResidual"]
    figure.text(
        0.065,
        0.955,
        "FORMATION FLIGHT OBSERVATORY",
        color="#dff7ff",
        fontsize=21,
        fontweight="bold",
        ha="left",
    )
    figure.text(
        0.065,
        0.920,
        "c20 phase-resolved wake interaction • actual archived GPU fields",
        color="#67c9ed",
        fontsize=11,
        ha="left",
    )
    badges = [
        ("FOLLOWER SAVING", f"{100 * stage1['c20SavingFraction']:.2f}%", "#54e6a2"),
        ("FINE-PAIR CHANGE", f"{100 * stage1['relativeFinePairChange']:.2f}%", "#ffbf5b"),
        ("LIMIT", f"{100 * summary['continuationThreshold']:.1f}%", "#8fcbe6"),
        ("DECISION", "STOP — NOT CONVERGED", "#ff6b65"),
    ]
    for index, (label, value, color) in enumerate(badges):
        x = 0.065 + index * 0.195
        figure.text(x, 0.865, label, color="#7498aa", fontsize=7.5, fontweight="bold")
        figure.text(x, 0.835, value, color=color, fontsize=12.5, fontweight="bold")

    rail = figure.add_axes((0.065, 0.065, 0.845, 0.038))
    rail.set_facecolor("#06131e")
    rail.set_xlim(0, 1)
    rail.set_ylim(0, 1)
    rail.axvspan(0.20, 0.30, color="#f7d774", alpha=0.14)
    rail.axvspan(0.70, 0.80, color="#f7d774", alpha=0.14)
    rail.hlines(0.5, 0, 1, color="#31566a", linewidth=1.2)
    all_entries = load(SLICES / "index.json")["entries"]
    observed = [
        entry["followerPhase"]
        for entry in all_entries
        if entry["leaderPhase"] != 0
        and (0.20 <= entry["followerPhase"] < 0.30 or 0.70 <= entry["followerPhase"] < 0.80)
    ]
    rail.scatter(observed, np.full(len(observed), 0.5), s=9, color="#75d9f8", zorder=3)
    rail.scatter(
        [entry["followerPhase"] for entry, _ in selected],
        np.full(len(selected), 0.5),
        s=36,
        facecolor="#ffb757",
        edgecolor="#fff1cd",
        linewidth=0.7,
        zorder=4,
    )
    rail.set_xticks((0, 0.2, 0.3, 0.5, 0.7, 0.8, 1))
    rail.set_xticklabels(("0", ".20", ".30", ".50", ".70", ".80", "1"), color="#7899aa", fontsize=7)
    rail.set_yticks(())
    rail.set_xlabel("follower-local phase • 20 captured midstroke states • four enlarged above", color="#8baaba", fontsize=8, labelpad=-1)
    for spine in rail.spines.values():
        spine.set_visible(False)

    figure.text(
        0.91,
        0.113,
        f"waveform L∞ {residual['maximumAbsolute']:.3f}\nat phase {residual['maximumPhase']:.3f}",
        ha="right",
        va="bottom",
        color="#ff8e84",
        fontsize=8,
        linespacing=1.35,
    )
    figure.text(
        0.065,
        0.018,
        "NO TEMPORAL INTERPOLATION  •  common velocity and vorticity scales  •  cyan leader / orange follower  •  contours show |ω|",
        color="#7fa4b6",
        fontsize=8,
        ha="left",
    )

    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(
        PNG,
        dpi=180,
        facecolor=figure.get_facecolor(),
        metadata={"Software": "BirdFlowMetal c20 CFD phase plate v1"},
    )
    figure.savefig(
        SVG,
        facecolor=figure.get_facecolor(),
        metadata={"Creator": "BirdFlowMetal c20 CFD phase plate v1", "Date": None},
    )
    plt.close(figure)
    print(
        json.dumps(
            {
                "png": str(PNG.relative_to(ROOT)),
                "svg": str(SVG.relative_to(ROOT)),
                "selected": [entry["file"] for entry, _ in selected],
                "velocityLimitMetersPerSecond": velocity_limit,
                "vorticityContourLevelsPerSecond": vorticity_levels.tolist(),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

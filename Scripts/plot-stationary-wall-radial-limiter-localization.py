#!/usr/bin/env python3
"""Render the locked D=16 radial limiter-localization figure."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


DEFAULT_REPORT = Path(
    "ValidationArtifacts/"
    "measured-wing-stationary-wall-c16-radial-limiter-localization.json"
)
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/Figures/stationary-wall-radial-limiter-localization"
)


def annotated_heatmap(axis, values, row_labels, column_labels, title, label):
    image = axis.imshow(values, aspect="auto", vmin=0, vmax=1, cmap="viridis")
    for row in range(values.shape[0]):
        for column in range(values.shape[1]):
            value = values[row, column]
            axis.text(
                column,
                row,
                f"{100 * value:.0f}",
                ha="center",
                va="center",
                color="white" if value < 0.28 or value > 0.68 else "black",
                fontsize=7,
            )
    axis.set_xticks(range(len(column_labels)), column_labels, rotation=35, ha="right")
    axis.set_yticks(range(len(row_labels)), row_labels)
    axis.set_xlabel("Distance from sphere surface")
    axis.set_ylabel("Convective time tU/D")
    axis.set_title(title)
    colorbar = axis.figure.colorbar(image, ax=axis, fraction=0.046, pad=0.03)
    colorbar.set_label(label)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Plot the D=16 radial symmetric-limiter localization"
    )
    parser.add_argument("report", nargs="?", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output-prefix", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    report = json.loads(arguments.report.read_text(encoding="utf-8"))
    if report["schemaVersion"] != 1 or report["diameterCells"] != 16:
        raise SystemExit("report is not the locked D=16 radial localization")
    snapshots = report["snapshots"]
    if report["captureSteps"] != [15, 100, 250, 500, 750, 1000]:
        raise SystemExit("radial localization capture steps have changed")

    times = [snapshot["convectiveTime"] for snapshot in snapshots]
    time_labels = [f"{value:g}" for value in times]
    shell_labels = [
        "0–1 cell",
        "1–2",
        "2–4",
        "4–8",
        "8–16",
        "16–32",
        "32–48",
        ">48",
    ]
    correction_share = np.array(
        [
            [bin_["fractionOfSnapshotLimiterL1Correction"] for bin_ in snapshot["bins"]]
            for snapshot in snapshots
        ]
    )
    activation_share = np.array(
        [
            [bin_["fractionOfSnapshotActivatedCells"] for bin_ in snapshot["bins"]]
            for snapshot in snapshots
        ]
    )

    plt.rcParams.update(
        {
            "font.family": "DejaVu Sans",
            "font.size": 9,
            "axes.titlesize": 10,
            "axes.labelsize": 9,
            "legend.fontsize": 8,
            "axes.spines.top": False,
            "axes.spines.right": False,
        }
    )
    figure, axes = plt.subplots(2, 2, figsize=(10.2, 7.1), constrained_layout=True)
    figure.suptitle(
        "D=16 limiter correction propagates into the physical flow region",
        fontsize=13,
        fontweight="semibold",
    )

    annotated_heatmap(
        axes[0, 0],
        correction_share,
        time_labels,
        shell_labels,
        "a  Limiter L1 allocation by radial shell",
        "Snapshot limiter L1 share",
    )
    annotated_heatmap(
        axes[0, 1],
        activation_share,
        time_labels,
        shell_labels,
        "b  Activated-cell allocation by radial shell",
        "Snapshot activated-cell share",
    )

    axis = axes[1, 0]
    near = [snapshot["nearSurfaceLimiterL1Fraction"] for snapshot in snapshots]
    far = [snapshot["farFieldLimiterL1Fraction"] for snapshot in snapshots]
    axis.plot(times, near, "o-", linewidth=1.8, label="within 0.25D")
    axis.plot(times, far, "s-", linewidth=1.8, label="beyond 1D")
    axis.axhline(
        report["minimumBoundaryLocalizedLimiterL1Fraction"],
        color="#555555",
        linestyle="--",
        linewidth=1,
        label="80% near-surface contract",
    )
    axis.axhline(
        report["maximumBoundaryLocalizedFarFieldLimiterL1Fraction"],
        color="#777777",
        linestyle=":",
        linewidth=1,
        label="5% far-field contract",
    )
    axis.set_title("c  Correction migrates away from the sphere")
    axis.set_xlabel("Convective time tU/D")
    axis.set_ylabel("Limiter L1 share")
    axis.set_ylim(-0.03, 1.03)
    axis.grid(alpha=0.22)
    axis.legend(frameon=False, ncols=2, loc="center right")

    axis = axes[1, 1]
    final_bins = snapshots[-1]["bins"]
    x = np.arange(len(shell_labels))
    width = 0.38
    axis.bar(
        x - width / 2,
        [100 * bin_["activationFraction"] for bin_ in final_bins],
        width,
        label="active fluid cells",
    )
    axis.bar(
        x + width / 2,
        [100 * bin_["relativeLimiterL1Correction"] for bin_ in final_bins],
        width,
        label="limiter / collision L1",
    )
    axis.set_title("d  Final intervention remains large through 3D")
    axis.set_xlabel("Distance from sphere surface")
    axis.set_ylabel("Fraction at tU/D=5 (%)")
    axis.set_xticks(x, shell_labels, rotation=35, ha="right")
    axis.grid(axis="y", alpha=0.22)
    axis.legend(frameon=False, loc="upper right")

    arguments.output_prefix.parent.mkdir(parents=True, exist_ok=True)
    png = arguments.output_prefix.with_suffix(".png")
    svg = arguments.output_prefix.with_suffix(".svg")
    figure.savefig(png, dpi=180, metadata={"Software": "BirdFlowMetal"})
    figure.savefig(svg, metadata={"Creator": "BirdFlowMetal"})
    plt.close(figure)
    svg.write_text(
        "\n".join(
            line.rstrip() for line in svg.read_text(encoding="utf-8").splitlines()
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"wrote {png}")
    print(f"wrote {svg}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Render the locked RR3 D=8/12 duration-sensitivity figure."""

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
    "measured-wing-stationary-wall-recursive-regularization-duration.json"
)
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/Figures/"
    "stationary-wall-recursive-regularization-duration"
)


def rolling_mean(values: list[float], window: int) -> list[float]:
    result: list[float] = []
    total = 0.0
    for index, value in enumerate(values):
        total += value
        if index >= window:
            total -= values[index - window]
        result.append(total / min(index + 1, window))
    return result


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Plot RR3 coarse-grid duration sensitivity"
    )
    parser.add_argument("report", nargs="?", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output-prefix", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    report = json.loads(arguments.report.read_text(encoding="utf-8"))
    if report["schemaVersion"] != 1:
        raise SystemExit("unsupported duration report schema")
    cases = report["cases"]
    if [case["numericalCase"]["diameterCells"] for case in cases] != [8, 12]:
        raise SystemExit("report is not the locked RR3 D=8/12 duration diagnostic")

    colors = ["#D55E00", "#0072B2"]
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
    figure, axes = plt.subplots(2, 2, figsize=(10.2, 6.8), constrained_layout=True)
    figure.suptitle(
        "RR3 duration sensitivity — unresolved only at D=8",
        fontsize=13,
        fontweight="semibold",
    )

    axis = axes[0, 0]
    windows = np.arange(1, 11)
    for item, color in zip(cases, colors):
        diameter = item["numericalCase"]["diameterCells"]
        axis.plot(
            windows,
            item["convectiveWindowMeanDragCoefficients"],
            "o-",
            color=color,
            linewidth=1.7,
            markersize=4,
            label=f"D={diameter}",
        )
    axis.axvline(5.5, color="#555555", linestyle="--", linewidth=1)
    axis.text(5.35, 2.32, "previous endpoint", rotation=90, ha="right", va="top")
    axis.set_title("a  One-convective-time drag means")
    axis.set_xlabel("Convective window")
    axis.set_ylabel("Mean drag coefficient")
    axis.set_xticks(windows)
    axis.grid(axis="y", alpha=0.22)
    axis.legend(frameon=False)

    axis = axes[0, 1]
    positions = np.arange(3)
    width = 0.34
    labels = ["4→5", "9→10", "5→10"]
    keys = [
        "fourthToFifthRelativeDragChange",
        "ninthToTenthRelativeDragChange",
        "fifthToTenthRelativeDragChange",
    ]
    for index, (item, color) in enumerate(zip(cases, colors)):
        values = [100 * item[key] for key in keys]
        axis.bar(
            positions + (index - 0.5) * width,
            values,
            width,
            color=color,
            label=f"D={item['numericalCase']['diameterCells']}",
        )
        for position, value in zip(positions + (index - 0.5) * width, values):
            axis.text(position, value + 1, f"{value:.1f}%", ha="center", fontsize=7.5)
    axis.axhline(
        100 * report["maximumAllowedLateWindowChange"],
        color="#333333",
        linestyle="--",
        linewidth=1,
        label="5% gate",
    )
    axis.set_title("b  Late-window stability isolates D=8")
    axis.set_ylabel("Relative drag change (%)")
    axis.set_xticks(positions, labels)
    axis.set_ylim(0, 53)
    axis.grid(axis="y", alpha=0.22)
    axis.legend(frameon=False, ncols=3, loc="upper center")

    axis = axes[1, 0]
    for item, color in zip(cases, colors):
        case = item["numericalCase"]
        samples = case["samples"]
        window = max(1, round(0.1 * case["diameterCells"] / 0.08))
        axis.plot(
            [sample["convectiveTime"] for sample in samples],
            rolling_mean([sample["dragCoefficient"] for sample in samples], window),
            color=color,
            linewidth=0.9,
            label=f"D={case['diameterCells']}",
        )
    axis.axvline(5, color="#555555", linestyle="--", linewidth=1)
    axis.set_title("c  Phase history reveals coarse-grid oscillation")
    axis.set_xlabel("Convective time tU/D")
    axis.set_ylabel("Drag coefficient (0.1 tU/D mean)")
    axis.set_xlim(0.5, 10)
    axis.set_ylim(-0.2, 2.2)
    axis.grid(alpha=0.22)
    axis.legend(frameon=False)

    axis = axes[1, 1]
    for item, color in zip(cases, colors):
        case = item["numericalCase"]
        samples = case["samples"]
        axis.plot(
            [sample["convectiveTime"] for sample in samples],
            [
                100 * sample["controlVolumeLimiterActivationFraction"]
                for sample in samples
            ],
            color=color,
            linewidth=0.8,
            label=f"D={case['diameterCells']}",
        )
    axis.axhline(5, color="#333333", linestyle="--", linewidth=1, label="5% gate")
    axis.set_title("d  Positivity correction remains non-intrusive")
    axis.set_xlabel("Convective time tU/D")
    axis.set_ylabel("Active control-volume cells per step (%)")
    axis.set_xlim(0, 10)
    axis.set_yscale("symlog", linthresh=1.0e-3)
    axis.set_ylim(-2.0e-4, 8)
    axis.grid(alpha=0.22)
    axis.legend(frameon=False, ncols=3, loc="upper left")

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

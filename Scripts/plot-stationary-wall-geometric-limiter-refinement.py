#!/usr/bin/env python3
"""Render the locked source-aware geometric limiter refinement figure."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


DEFAULT_REPORT = Path(
    "ValidationArtifacts/"
    "measured-wing-stationary-wall-geometric-limiter-refinement.json"
)
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/Figures/stationary-wall-geometric-limiter-refinement"
)


def rolling_mean(values: list[float], window: int) -> list[float]:
    window = max(window, 1)
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
        description="Plot the stationary-sphere geometric limiter ladder"
    )
    parser.add_argument("report", nargs="?", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output-prefix", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    report = json.loads(arguments.report.read_text(encoding="utf-8"))
    if report["schemaVersion"] != 1:
        raise SystemExit("unsupported geometric limiter report schema")
    cases = report["cases"]
    if [case["diameterCells"] for case in cases] != [8, 12, 16]:
        raise SystemExit("report is not the locked D=8/12/16 ladder")

    diameters = [case["diameterCells"] for case in cases]
    drag = [case["meanDragCoefficientLastConvectiveTime"] for case in cases]
    activation = [
        100 * case["controlVolumeLimiterActivationFraction"] for case in cases
    ]
    limiter_l1 = [
        100 * case["relativeControlVolumeLimiterL1Correction"] for case in cases
    ]
    limiter_l2 = [
        100 * case["relativeControlVolumeLimiterL2Correction"] for case in cases
    ]

    colors = ["#0072B2", "#D55E00", "#009E73"]
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
        "Source-aware geometric limiter ladder — promotion blocked",
        fontsize=13,
        fontweight="semibold",
    )

    axis = axes[0, 0]
    axis.plot(diameters, drag, "o-", color=colors[0], linewidth=1.8)
    for diameter, value in zip(diameters, drag):
        axis.annotate(
            f"{value:.3f}",
            (diameter, value),
            xytext=(0, 7),
            textcoords="offset points",
            ha="center",
        )
    axis.set_title("a  Mean drag over final convective time")
    axis.set_xlabel("Sphere diameter D (cells)")
    axis.set_ylabel("Drag coefficient")
    axis.set_xticks(diameters)
    axis.grid(axis="y", alpha=0.22)
    axis.text(
        0.55,
        0.05,
        f"D12→D16 change = {100 * report['relativeFinestTwoDragChange']:.1f}%\n"
        f"gate = {100 * report['maximumAllowedFinestTwoDragChange']:.0f}%",
        transform=axis.transAxes,
        va="bottom",
    )

    axis = axes[0, 1]
    axis.plot(diameters, activation, "o-", color=colors[0], label="active cell-steps")
    axis.plot(
        diameters, limiter_l1, "s-", color=colors[1], label="limiter / collision L1"
    )
    axis.plot(
        diameters, limiter_l2, "^-", color=colors[2], label="limiter / collision L2"
    )
    axis.axhline(
        100 * report["maximumAllowedLimiterActivationFraction"],
        color=colors[0],
        linestyle=":",
        linewidth=1,
    )
    axis.axhline(
        100 * report["maximumAllowedRelativeLimiterCorrection"],
        color=colors[1],
        linestyle="--",
        linewidth=1,
    )
    axis.set_title("b  Interior limiter intervention grows")
    axis.set_xlabel("Sphere diameter D (cells)")
    axis.set_ylabel("Fraction (%)")
    axis.set_xticks(diameters)
    axis.grid(axis="y", alpha=0.22)
    axis.legend(frameon=False, loc="lower right")

    axis = axes[1, 0]
    for case, color in zip(cases, colors):
        samples = case["samples"]
        drag_history = [sample["dragCoefficient"] for sample in samples]
        smoothing_window = max(
            1,
            round(0.1 * case["diameterCells"] / report["latticeFarFieldSpeed"]),
        )
        axis.plot(
            [sample["convectiveTime"] for sample in samples],
            rolling_mean(drag_history, smoothing_window),
            color=color,
            linewidth=1.0,
            label=f"D={case['diameterCells']}",
        )
    axis.set_title("c  Transient drag histories do not collapse")
    axis.set_xlabel("Convective time tU/D")
    axis.set_ylabel("Drag coefficient (0.1 tU/D mean)")
    axis.grid(alpha=0.22)
    axis.legend(frameon=False, ncols=3, loc="upper right")

    axis = axes[1, 1]
    for case, color in zip(cases, colors):
        samples = case["samples"]
        axis.plot(
            [sample["convectiveTime"] for sample in samples],
            [
                100 * sample["controlVolumeLimiterActivationFraction"]
                for sample in samples
            ],
            color=color,
            linewidth=1.0,
            label=f"D={case['diameterCells']}",
        )
    axis.axhline(
        100 * report["maximumAllowedLimiterActivationFraction"],
        color="#333333",
        linestyle="--",
        linewidth=1,
        label="5% gate",
    )
    axis.set_title("d  Interior activation remains sustained")
    axis.set_xlabel("Convective time tU/D")
    axis.set_ylabel("Active control-volume cells per step (%)")
    axis.grid(alpha=0.22)
    axis.legend(frameon=False, ncols=2, loc="upper left")

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

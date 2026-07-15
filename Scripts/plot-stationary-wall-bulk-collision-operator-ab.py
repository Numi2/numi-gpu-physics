#!/usr/bin/env python3
"""Render the locked D=16 bulk collision-operator A/B figure."""

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
    "measured-wing-stationary-wall-c16-bulk-collision-operator-ab.json"
)
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/Figures/stationary-wall-bulk-collision-operator-ab"
)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Plot the locked D=16 bulk collision-operator A/B"
    )
    parser.add_argument("report", nargs="?", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output-prefix", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    report = json.loads(arguments.report.read_text(encoding="utf-8"))
    if report["schemaVersion"] != 1 or report["diameterCells"] != 16:
        raise SystemExit("report is not the locked D=16 collision-operator A/B")
    if report["requestedSteps"] != 1000:
        raise SystemExit("collision-operator A/B duration has changed")

    control = report["control"]
    candidate = report["candidate"]
    recursive_ab = (
        candidate["operatorName"] == "positivity-preserving-recursive-regularized-bgk"
    )
    cases = [control, candidate]
    labels = (
        [
            "Second-order\nregularized control",
            "Recursive third-order\nregularized candidate",
        ]
        if recursive_ab
        else ["Limited TRT\ncontrol", "Regularized positive\nBGK candidate"]
    )
    colors = ["#65758b", "#1f9d8a"]

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
        (
            "Recursive regularization clears every locked D=16 promotion gate"
            if recursive_ab
            else "Regularization removes >99% of L1 correction but narrowly misses the locked L2 gate"
        ),
        fontsize=13,
        fontweight="semibold",
    )

    axis = axes[0, 0]
    activation = [
        100 * case["controlVolumeCorrectionActivationFraction"] for case in cases
    ]
    bars = axis.bar(labels, activation, color=colors, width=0.58)
    axis.axhline(
        100 * report["maximumAllowedCorrectionActivationFraction"],
        color="#b33a3a",
        linestyle="--",
        linewidth=1.2,
        label="locked 5% gate",
    )
    axis.bar_label(bars, labels=[f"{value:.3f}%" for value in activation], padding=3)
    axis.set_title("a  Control-volume correction activation")
    axis.set_ylabel("Activated cell-steps (%)")
    if recursive_ab:
        axis.set_yscale("log")
        axis.set_ylim(min(activation) * 0.45, 10)
    else:
        axis.set_ylim(0, max(activation) * 1.22)
    axis.grid(axis="y", alpha=0.22)
    axis.legend(frameon=False)

    axis = axes[0, 1]
    x = np.arange(2)
    width = 0.34
    l1 = [100 * case["relativeControlVolumeCorrectionL1"] for case in cases]
    l2 = [100 * case["relativeControlVolumeCorrectionL2"] for case in cases]
    bars_l1 = axis.bar(x - width / 2, l1, width, label="L1 correction", color="#4f78a8")
    bars_l2 = axis.bar(x + width / 2, l2, width, label="L2 correction", color="#e07a5f")
    axis.axhline(
        100 * report["maximumAllowedRelativeCorrection"],
        color="#b33a3a",
        linestyle="--",
        linewidth=1.2,
        label="locked 1% gate",
    )
    axis.set_yscale("log")
    axis.set_xticks(x, labels)
    axis.set_ylabel("Correction / collision increment (%)")
    axis.set_title(
        "b  Recursive retention clears the L2 gate"
        if recursive_ab
        else "b  Candidate misses only the L2 gate"
    )
    axis.grid(axis="y", which="both", alpha=0.22)
    axis.legend(frameon=False, ncols=2, loc="upper right")
    axis.bar_label(bars_l1, labels=[f"{value:.3f}%" for value in l1], padding=2)
    axis.bar_label(bars_l2, labels=[f"{value:.3f}%" for value in l2], padding=2)

    axis = axes[1, 0]
    near = [100 * case["finalNearSurfaceCorrectionL1Fraction"] for case in cases]
    far = [100 * case["finalFarFieldCorrectionL1Fraction"] for case in cases]
    middle = [max(0, 100 - near[index] - far[index]) for index in range(2)]
    axis.bar(labels, near, color="#3b82a0", label="within 0.25D")
    axis.bar(labels, middle, bottom=near, color="#9cc4b2", label="0.25D–1D")
    axis.bar(
        labels,
        far,
        bottom=np.array(near) + np.array(middle),
        color="#d28b5b",
        label="beyond 1D",
    )
    axis.set_ylim(0, 100)
    axis.set_ylabel("Final correction L1 allocation (%)")
    axis.set_title("c  Residual correction contracts inside one diameter")
    axis.grid(axis="y", alpha=0.22)
    axis.legend(frameon=False, ncols=3, loc="lower center")
    axis.text(
        1,
        44,
        (
            f"L1 correction is\n{100 * report['candidateToControlCorrectionL1Ratio']:.1f}% of PR2"
            if recursive_ab
            else "absolute L1 correction\nis 0.86% of control"
        ),
        ha="center",
        va="center",
        fontsize=8,
        fontweight="semibold",
    )

    axis = axes[1, 1]
    gate_names = ["positive", "ledger", "force", "non-intrusive"]
    gate_values = np.array(
        [
            [
                case["populationPositivityPassed"],
                case["globalLedgerClosed"],
                case["forceBudgetPassed"],
                case["correctionNonIntrusivePassed"],
            ]
            for case in cases
        ],
        dtype=int,
    )
    axis.imshow(gate_values, vmin=0, vmax=1, cmap="RdYlGn", aspect="auto")
    for row in range(2):
        for column in range(4):
            axis.text(
                column,
                row,
                "PASS" if gate_values[row, column] else "FAIL",
                ha="center",
                va="center",
                color="white",
                fontsize=8,
                fontweight="bold",
            )
    axis.set_xticks(range(4), gate_names, rotation=25, ha="right")
    axis.set_yticks(range(2), labels)
    axis.set_title("d  Unchanged promotion gates")
    for spine in axis.spines.values():
        spine.set_visible(False)
    axis.text(
        1.5,
        1.32,
        (
            f"candidate L2: {100 * candidate['relativeControlVolumeCorrectionL2']:.4f}% < 1.0000%"
            if recursive_ab
            else "candidate L2: 1.0968% > 1.0000%"
        ),
        ha="center",
        va="center",
        color="white" if recursive_ab else "#8f2525",
        fontsize=8,
        fontweight="semibold",
    )

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

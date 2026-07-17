#!/usr/bin/env python3
"""Render the preregistered c20 maximum-selector discriminator."""

from __future__ import annotations

import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-c20-stage1-atlas-v1"
import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parent.parent
PROMOTION = ROOT / "ValidationArtifacts/formation-flight-promotion"
REPORTS = {
    8: ROOT
    / "ValidationArtifacts/formation-flight-scout-v1/y0-z3-phase0p25/formation-flight-report.json",
    12: PROMOTION / "c12-best-z3-phase025/formation-flight-report.json",
    16: PROMOTION / "c16-best-z3-phase025/formation-flight-report.json",
    20: PROMOTION / "c20-best-z3-phase025/formation-flight-report.json",
}
SUMMARY = PROMOTION / "formation-flight-c20-discriminator-summary.json"
PNG = ROOT / "Docs/Media/formation-flight-c20-stage1-atlas.png"
SVG = ROOT / "Docs/Media/formation-flight-c20-stage1-atlas.svg"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def phase_curve(report: dict) -> tuple[list[float], list[float]]:
    denominator = report["isolatedFollower"]["meanPositivePowerWatts"]
    ordered = sorted(report["phaseSamples"], key=lambda sample: sample["followerPhase"])
    return (
        [sample["followerPhase"] for sample in ordered],
        [sample["followerSignedPowerWatts"] / denominator for sample in ordered],
    )


def field_envelope(report_path: Path) -> tuple[list[float], list[float], list[float]]:
    directory = report_path.parent / "formation-flight-flow-slices"
    index = load(directory / "index.json")
    records = []
    for entry in index["entries"]:
        phase = entry["followerPhase"]
        if entry["leaderPhase"] == 0:
            continue
        if not (0.20 <= phase < 0.30 or 0.70 <= phase < 0.80):
            continue
        slice_data = load(directory / entry["file"])
        records.append(
            (
                phase,
                slice_data["maximumVorticityMagnitudePerSecond"],
                slice_data["maximumAbsoluteVerticalVelocityMetersPerSecond"],
            )
        )
    records.sort()
    if len(records) != 20:
        raise SystemExit(f"expected 20 midstroke slices, found {len(records)}")
    vorticity_scale = max(record[1] for record in records)
    vertical_scale = max(record[2] for record in records)
    if vorticity_scale <= 0 or vertical_scale <= 0:
        raise SystemExit("invalid c20 field envelope")
    return (
        [record[0] for record in records],
        [record[1] / vorticity_scale for record in records],
        [record[2] / vertical_scale for record in records],
    )


def main() -> int:
    reports = {resolution: load(path) for resolution, path in REPORTS.items()}
    summary = load(SUMMARY)
    if summary["status"] not in (
        "stage1_failed_stop",
        "stage1_passed_stage2_required",
        "both_stages_passed",
        "stage2_failed",
    ):
        raise SystemExit("c20 stage 1 is not complete")
    phase16, power16 = phase_curve(reports[16])
    phase20, power20 = phase_curve(reports[20])
    if len(phase16) != len(phase20) or any(
        not math.isclose(a, b, abs_tol=1e-6)
        for a, b in zip(phase16, phase20)
    ):
        raise SystemExit("c16/c20 follower-local phase grids do not align")
    power_residual = [fine - coarse for coarse, fine in zip(power16, power20)]
    field_phase, vorticity, vertical = field_envelope(REPORTS[20])

    plt.style.use("dark_background")
    figure, axes = plt.subplots(2, 2, figsize=(13.5, 8.2))
    figure.patch.set_facecolor("#071521")
    for axis in axes.flat:
        axis.set_facecolor("#0b2130")
        axis.grid(color="#36566a", alpha=0.28, linewidth=0.7)

    resolutions = sorted(reports)
    savings = [
        100 * reports[resolution]["followerPositivePowerSavingFraction"]
        for resolution in resolutions
    ]
    axes[0, 0].plot(
        resolutions,
        savings,
        color="#ff9f43",
        marker="o",
        linewidth=2.1,
    )
    axes[0, 0].set_xticks(resolutions)
    axes[0, 0].set_xlabel("cells per chord")
    axes[0, 0].set_ylabel("maximum-selector saving (%)")
    axes[0, 0].set_title("A  Maximum-selector refinement")

    axes[0, 1].plot(phase16, power16, color="#43c6f5", label="c16", linewidth=1.7)
    axes[0, 1].plot(phase20, power20, color="#ff9f43", label="c20", linewidth=1.7)
    axes[0, 1].set_ylabel("follower signed power / isolated mean positive power")
    axes[0, 1].set_title("B  Phase-aligned follower power")
    axes[0, 1].legend(frameon=False)

    axes[1, 0].plot(phase20, power_residual, color="#ff5d73", linewidth=1.6)
    axes[1, 0].fill_between(phase20, power_residual, 0, color="#ff5d73", alpha=0.20)
    phase_metrics = summary["stage1"]["phaseResolvedFinePair"][
        "normalizedPowerResidual"
    ]
    axes[1, 0].scatter(
        [phase_metrics["maximumPhase"]],
        [phase_metrics["maximumSigned"]],
        color="#ffe08a",
        s=34,
        zorder=5,
    )
    axes[1, 0].axhline(0, color="#9db7c7", alpha=0.35, linewidth=0.8)
    axes[1, 0].set_xlabel("follower-local wingbeat phase")
    axes[1, 0].set_ylabel("c20 − c16 normalized signed power")
    axes[1, 0].set_title("C  Fine-pair waveform residual")

    for band_index, indices in enumerate(
        (
            [index for index, phase in enumerate(field_phase) if phase < 0.5],
            [index for index, phase in enumerate(field_phase) if phase > 0.5],
        )
    ):
        phases = [field_phase[index] for index in indices]
        axes[1, 1].plot(
            phases,
            [vorticity[index] for index in indices],
            color="#f6c85f",
            marker="o",
            markersize=3,
            label="max |vorticity|" if band_index == 0 else None,
        )
        axes[1, 1].plot(
            phases,
            [vertical[index] for index in indices],
            color="#43c6f5",
            marker="o",
            markersize=3,
            label="max |vertical velocity|" if band_index == 0 else None,
        )
    axes[1, 1].set_xlabel("follower-local captured phase")
    axes[1, 1].set_ylabel("normalized c20 field maximum")
    axes[1, 1].set_title("D  GPU-resident midstroke field envelope")
    axes[1, 1].legend(frameon=False, fontsize=8)

    for axis in (axes[0, 1], axes[1, 0]):
        axis.set_xlim(0, 1)
        axis.set_xticks([0, 0.25, 0.5, 0.75, 1])
        axis.axvspan(0.20, 0.30, color="#f6c85f", alpha=0.05)
        axis.axvspan(0.70, 0.80, color="#f6c85f", alpha=0.05)

    stage1 = summary["stage1"]
    decision = "CONTINUE" if stage1["passed"] else "STOP — NOT CONVERGED"
    figure.suptitle(
        "FORMATION FLIGHT — PREREGISTERED c20 STAGE 1",
        fontsize=16,
        fontweight="bold",
        color="#d9f4ff",
        y=0.985,
    )
    figure.text(
        0.5,
        0.945,
        "Maximum selector only • unchanged conservation/repeatability gates • dense midstroke observation",
        ha="center",
        color="#83cbe7",
        fontsize=9.5,
    )
    figure.text(
        0.5,
        0.018,
        (
            f"c16→c20 saving change {stage1['relativeFinePairChange']:.2%} "
            f"against frozen 5% continuation criterion  •  {decision}  •  "
            f"waveform L∞ {phase_metrics['maximumAbsolute']:.3f} at phase "
            f"{phase_metrics['maximumPhase']:.3f}"
        ),
        ha="center",
        color="#a9c3d2",
        fontsize=9,
    )
    figure.subplots_adjust(
        left=0.09,
        right=0.98,
        top=0.90,
        bottom=0.10,
        hspace=0.28,
        wspace=0.22,
    )
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(
        PNG,
        dpi=180,
        facecolor=figure.get_facecolor(),
        metadata={"Software": "BirdFlowMetal c20 stage1 atlas v1"},
    )
    figure.savefig(
        SVG,
        facecolor=figure.get_facecolor(),
        metadata={
            "Creator": "BirdFlowMetal c20 stage1 atlas v1",
            "Date": None,
        },
    )
    plt.close(figure)
    print(
        json.dumps(
            {
                "png": str(PNG.relative_to(ROOT)),
                "svg": str(SVG.relative_to(ROOT)),
                "decision": decision,
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

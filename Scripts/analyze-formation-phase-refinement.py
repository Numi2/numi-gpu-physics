#!/usr/bin/env python3
"""Localize c12/c16 formation-flight phase refinement without new CFD."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-refinement-atlas-v1"
import matplotlib.pyplot as plt


ROOT = Path(__file__).resolve().parent.parent
PROMOTION = ROOT / "ValidationArtifacts/formation-flight-promotion"
REPORTS = {
    (12, "maximum"): PROMOTION
    / "c12-best-z3-phase025/formation-flight-report.json",
    (12, "minimum"): PROMOTION
    / "c12-minimum-z3-phase075/formation-flight-report.json",
    (16, "maximum"): PROMOTION
    / "c16-best-z3-phase025/formation-flight-report.json",
    (16, "minimum"): PROMOTION
    / "c16-minimum-z3-phase075/formation-flight-report.json",
}
JSON_OUTPUT = PROMOTION / "formation-flight-phase-refinement-atlas.json"
CSV_OUTPUT = PROMOTION / "formation-flight-phase-refinement-atlas.csv"
PNG_OUTPUT = ROOT / "Docs/Media/formation-flight-phase-refinement-atlas.png"
SVG_OUTPUT = ROOT / "Docs/Media/formation-flight-phase-refinement-atlas.svg"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_report(resolution: int, selection: str, path: Path) -> dict:
    report = json.loads(path.read_text())
    expected_phase = 0.25 if selection == "maximum" else 0.75
    configuration = report["configuration"]
    if configuration["chordCells"] != resolution:
        raise SystemExit(f"wrong resolution in {path}")
    if configuration["followerOffsetChords"] != [0, 0, -3]:
        raise SystemExit(f"wrong offset in {path}")
    if abs(configuration["followerPhaseOffsetCycles"] - expected_phase) > 1e-12:
        raise SystemExit(f"wrong phase selection in {path}")
    if not report["gates"]["passed"]:
        raise SystemExit(f"failed input report: {path}")
    if len(report["phaseSamples"]) != 100:
        raise SystemExit(f"expected 100 phase bins in {path}")
    return report


def align_follower_phase(report: dict) -> dict[float, dict]:
    aligned: dict[float, dict] = {}
    denominator = report["isolatedFollower"]["meanPositivePowerWatts"]
    if not math.isfinite(denominator) or denominator <= 0:
        raise SystemExit("isolated mean-positive-power denominator is invalid")
    for sample in report["phaseSamples"]:
        phase = round(float(sample["followerPhase"]), 6)
        if phase in aligned:
            raise SystemExit(f"duplicate follower-local phase {phase}")
        aligned[phase] = {
            "normalizedSignedPower": sample["followerSignedPowerWatts"]
            / denominator,
            "liftCoefficient": sample["followerLiftCoefficient"],
            "dragCoefficient": sample["followerDragCoefficient"],
        }
    return aligned


def rms(values: list[float]) -> float:
    return math.sqrt(sum(value * value for value in values) / len(values))


def pearson_absolute(lhs: list[float], rhs: list[float]) -> float:
    x = [abs(value) for value in lhs]
    y = [abs(value) for value in rhs]
    mean_x = sum(x) / len(x)
    mean_y = sum(y) / len(y)
    numerator = sum((a - mean_x) * (b - mean_y) for a, b in zip(x, y))
    denominator = math.sqrt(
        sum((a - mean_x) ** 2 for a in x)
        * sum((b - mean_y) ** 2 for b in y)
    )
    return numerator / denominator if denominator > 0 else 0.0


def gate_headroom() -> dict:
    paths = sorted(
        (ROOT / "ValidationArtifacts/formation-flight-scout-v1").glob(
            "*/formation-flight-report.json"
        )
    ) + sorted(PROMOTION.glob("c1*/formation-flight-report.json"))
    reports = [json.loads(path.read_text()) for path in paths]
    if len(reports) != 12:
        raise SystemExit(f"expected 12 unique scout/promoted reports, found {len(reports)}")
    if not all(report["gates"]["passed"] for report in reports):
        raise SystemExit("gate audit includes a failed report")
    def closure_values(selected: list[dict]) -> list[float]:
        return [
            value
            for report in selected
            for value in (
                report["gates"]["maximumRelativeForceClosureResidual"],
                report["gates"]["maximumRelativeTorqueClosureResidual"],
                report["gates"]["maximumIsolatedRelativeClosureResidual"],
            )
        ]

    all_closure_values = closure_values(reports)
    periodic_values = [
        report["gates"]["maximumRelativePeriodicPowerDifference"]
        for report in reports
    ]
    scout_reports = [
        report
        for report in reports
        if report["configuration"]["chordCells"] == 8
    ]
    promoted_reports = [
        report
        for report in reports
        if report["configuration"]["chordCells"] > 8
    ]
    if len(scout_reports) != 8 or len(promoted_reports) != 4:
        raise SystemExit("expected eight scout and four promoted reports")
    scout_periodic_values = [
        report["gates"]["maximumRelativePeriodicPowerDifference"]
        for report in scout_reports
    ]
    promoted_periodic_values = [
        report["gates"]["maximumRelativePeriodicPowerDifference"]
        for report in promoted_reports
    ]
    closure_limit = reports[0]["gates"]["maximumAllowedRelativeClosureResidual"]
    periodic_limit = reports[0]["gates"][
        "maximumAllowedRelativePeriodicPowerDifference"
    ]
    worst_closure = max(all_closure_values)
    worst_periodic = max(periodic_values)
    worst_scout_periodic = max(scout_periodic_values)
    worst_promoted_closure = max(closure_values(promoted_reports))
    worst_promoted_periodic = max(promoted_periodic_values)
    return {
        "reportCount": len(reports),
        "allReportsPassed": True,
        "maximumOverlapVoxelSamples": max(
            report["overlapVoxelSamples"] for report in reports
        ),
        "worstRelativeOwnerOrIsolatedClosure": worst_closure,
        "closureAcceptanceLimit": closure_limit,
        "closureHeadroomFactor": closure_limit / worst_closure,
        "worstRelativePeriodicPowerDifference": worst_periodic,
        "periodicAcceptanceLimit": periodic_limit,
        "periodicHeadroomFactor": periodic_limit / worst_periodic,
        "coarseScout": {
            "reportCount": len(scout_reports),
            "worstRelativePeriodicPowerDifference": worst_scout_periodic,
            "periodicHeadroomFactor": periodic_limit / worst_scout_periodic,
        },
        "promotedFinePair": {
            "reportCount": len(promoted_reports),
            "worstRelativeOwnerOrIsolatedClosure": worst_promoted_closure,
            "closureHeadroomFactor": closure_limit / worst_promoted_closure,
            "worstRelativePeriodicPowerDifference": worst_promoted_periodic,
            "periodicHeadroomFactor": periodic_limit / worst_promoted_periodic,
        },
        "acceptanceGatesMutateOrClampSolverOutput": False,
        "qualityLimitedByAcceptanceGates": False,
        "configurationCeilings": {
            "maximumChordCells": "none; Metal buffer and recommended working-set checks apply",
            "maximumCycles": "none arbitrary; checked arithmetic and exact Float timestep representation apply",
            "maximumOffsetChords": "none arbitrary; finite/grid/device checks apply",
        },
    }


def render(rows: list[dict], metrics: dict) -> None:
    phase = [row["followerPhase"] for row in rows]
    power12 = [row["normalizedPowerContrastC12"] for row in rows]
    power16 = [row["normalizedPowerContrastC16"] for row in rows]
    power_residual = [row["normalizedPowerContrastResidualC16MinusC12"] for row in rows]
    lift12 = [row["liftContrastC12"] for row in rows]
    lift16 = [row["liftContrastC16"] for row in rows]
    drag12 = [row["dragContrastC12"] for row in rows]
    drag16 = [row["dragContrastC16"] for row in rows]

    plt.style.use("dark_background")
    figure, axes = plt.subplots(2, 2, figsize=(13.5, 8.2), sharex=True)
    figure.patch.set_facecolor("#071521")
    for axis in axes.flat:
        axis.set_facecolor("#0b2130")
        axis.grid(color="#36566a", alpha=0.28, linewidth=0.7)
        axis.axhline(0, color="#9db7c7", alpha=0.35, linewidth=0.8)
        axis.set_xlim(0, 1)
        axis.set_xticks([0, 0.25, 0.5, 0.75, 1])
        axis.axvspan(0.20, 0.30, color="#f6c85f", alpha=0.045)
        axis.axvspan(0.70, 0.80, color="#f6c85f", alpha=0.045)

    axes[0, 0].plot(phase, power12, color="#43c6f5", linewidth=1.8, label="c12")
    axes[0, 0].plot(phase, power16, color="#ff9f43", linewidth=1.8, label="c16")
    axes[0, 0].set_title("A  Phase-aligned power discrimination")
    axes[0, 0].set_ylabel("Δ normalized signed power\n(Δφ=.25 minus .75)")
    axes[0, 0].legend(frameon=False, ncol=2)

    axes[0, 1].plot(phase, power_residual, color="#ff5d73", linewidth=1.6)
    axes[0, 1].fill_between(phase, power_residual, 0, color="#ff5d73", alpha=0.20)
    maximum = metrics["normalizedPowerContrastResidual"]["maximumAbsolute"]
    maximum_phase = metrics["normalizedPowerContrastResidual"]["maximumPhase"]
    axes[0, 1].scatter([maximum_phase], [maximum["signedValue"]], color="#ffe08a", s=34, zorder=5)
    axes[0, 1].set_title("B  Fine-pair residual")
    axes[0, 1].set_ylabel("c16 − c12 power discrimination")

    axes[1, 0].plot(phase, lift12, color="#43c6f5", linewidth=1.6, label="c12")
    axes[1, 0].plot(phase, lift16, color="#ff9f43", linewidth=1.6, label="c16")
    axes[1, 0].set_title("C  Lift-coefficient discrimination")
    axes[1, 0].set_ylabel("ΔCL (Δφ=.25 minus .75)")
    axes[1, 0].set_xlabel("follower-local wingbeat phase")

    axes[1, 1].plot(phase, drag12, color="#43c6f5", linewidth=1.6, label="c12")
    axes[1, 1].plot(phase, drag16, color="#ff9f43", linewidth=1.6, label="c16")
    axes[1, 1].set_title("D  Drag-coefficient discrimination")
    axes[1, 1].set_ylabel("ΔCD (Δφ=.25 minus .75)")
    axes[1, 1].set_xlabel("follower-local wingbeat phase")

    figure.suptitle(
        "FORMATION FLIGHT — PHASE-RESOLVED c12/c16 REFINEMENT ATLAS",
        fontsize=16,
        fontweight="bold",
        color="#d9f4ff",
        y=0.985,
    )
    figure.text(
        0.5,
        0.945,
        "Exploratory localization from archived 100-bin histories • no acceptance threshold • no new CFD",
        ha="center",
        color="#83cbe7",
        fontsize=9.5,
    )
    figure.text(
        0.5,
        0.018,
        (
            f"Power residual RMS {metrics['normalizedPowerContrastResidual']['rms']:.3f}  •  "
            f"L∞ {maximum['absoluteValue']:.3f} at phase {maximum_phase:.3f}  •  "
            f"midstroke-band share "
            f"{metrics['normalizedPowerContrastResidual']['pairedMidstrokeBandAbsoluteFraction']:.1%}  •  "
            f"|power residual| correlation with |ΔCL residual| "
            f"{metrics['crossSignalCorrelation']['powerVsLiftAbsolute']:.3f}"
        ),
        ha="center",
        color="#a9c3d2",
        fontsize=9,
    )
    figure.subplots_adjust(left=0.09, right=0.98, top=0.90, bottom=0.10, hspace=0.27, wspace=0.20)
    PNG_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(
        PNG_OUTPUT,
        dpi=180,
        facecolor=figure.get_facecolor(),
        metadata={"Software": "BirdFlowMetal phase-refinement atlas v1"},
    )
    figure.savefig(
        SVG_OUTPUT,
        facecolor=figure.get_facecolor(),
        metadata={
            "Creator": "BirdFlowMetal phase-refinement atlas v1",
            "Date": None,
        },
    )
    plt.close(figure)


def main() -> int:
    reports = {
        key: load_report(*key, path)
        for key, path in REPORTS.items()
    }
    curves = {key: align_follower_phase(report) for key, report in reports.items()}
    phases = sorted(curves[(12, "maximum")])
    if len(phases) != 100 or any(set(curve) != set(phases) for curve in curves.values()):
        raise SystemExit("follower-local phase grids do not close across reports")

    rows: list[dict] = []
    for phase in phases:
        values = {key: curve[phase] for key, curve in curves.items()}
        row = {"followerPhase": phase}
        for resolution in (12, 16):
            maximum = values[(resolution, "maximum")]
            minimum = values[(resolution, "minimum")]
            row[f"normalizedPowerContrastC{resolution}"] = (
                maximum["normalizedSignedPower"]
                - minimum["normalizedSignedPower"]
            )
            row[f"liftContrastC{resolution}"] = (
                maximum["liftCoefficient"] - minimum["liftCoefficient"]
            )
            row[f"dragContrastC{resolution}"] = (
                maximum["dragCoefficient"] - minimum["dragCoefficient"]
            )
        row["normalizedPowerContrastResidualC16MinusC12"] = (
            row["normalizedPowerContrastC16"]
            - row["normalizedPowerContrastC12"]
        )
        row["liftContrastResidualC16MinusC12"] = (
            row["liftContrastC16"] - row["liftContrastC12"]
        )
        row["dragContrastResidualC16MinusC12"] = (
            row["dragContrastC16"] - row["dragContrastC12"]
        )
        rows.append(row)

    power_residual = [
        row["normalizedPowerContrastResidualC16MinusC12"] for row in rows
    ]
    lift_residual = [row["liftContrastResidualC16MinusC12"] for row in rows]
    drag_residual = [row["dragContrastResidualC16MinusC12"] for row in rows]

    def signal_metrics(values: list[float]) -> dict:
        maximum_index = max(range(len(values)), key=lambda index: abs(values[index]))
        absolute_total = sum(abs(value) for value in values)
        ranked = sorted(
            range(len(values)), key=lambda index: abs(values[index]), reverse=True
        )
        paired_midstroke_indices = [
            index
            for index, phase in enumerate(phases)
            if 0.20 <= phase < 0.30 or 0.70 <= phase < 0.80
        ]
        return {
            "rms": rms(values),
            "maximumAbsolute": {
                "absoluteValue": abs(values[maximum_index]),
                "signedValue": values[maximum_index],
            },
            "maximumPhase": phases[maximum_index],
            "topTenBins": [
                {
                    "followerPhase": phases[index],
                    "signedResidual": values[index],
                    "absoluteResidualFraction": (
                        abs(values[index]) / absolute_total
                        if absolute_total > 0
                        else 0
                    ),
                }
                for index in ranked[:10]
            ],
            "binsRequiredForHalfAbsoluteResidual": next(
                (
                    rank
                    for rank in range(1, len(ranked) + 1)
                    if sum(abs(values[index]) for index in ranked[:rank])
                    >= 0.5 * absolute_total
                ),
                0,
            ),
            "pairedMidstrokeBandDefinition": "0.20 <= follower phase < 0.30 or 0.70 <= follower phase < 0.80",
            "pairedMidstrokeBandAbsoluteFraction": (
                sum(abs(values[index]) for index in paired_midstroke_indices)
                / absolute_total
                if absolute_total > 0
                else 0
            ),
        }

    metrics = {
        "normalizedPowerContrastResidual": signal_metrics(power_residual),
        "liftContrastResidual": signal_metrics(lift_residual),
        "dragContrastResidual": signal_metrics(drag_residual),
        "crossSignalCorrelation": {
            "powerVsLiftAbsolute": pearson_absolute(power_residual, lift_residual),
            "powerVsDragAbsolute": pearson_absolute(power_residual, drag_residual),
        },
    }
    artifact = {
        "schemaVersion": 1,
        "analysisType": "exploratory post-result phase localization; not an acceptance gate",
        "scientificQuestion": "Which follower-local wingbeat phases produce the c12/c16 change in maximum-minus-minimum formation discrimination?",
        "alignment": "100 archived samples sorted by follower-local phase so both phase-offset cases compare identical local kinematics",
        "powerNormalization": "each coupled follower signed-power trace divided by its own matched isolated mean-positive-power scalar",
        "limitation": "schema-1 reports do not retain phase-resolved isolated histories; this localizes coupled waveform refinement but is not a phase-resolved saving curve",
        "inputs": [
            {
                "chordCells": key[0],
                "selection": key[1],
                "report": str(REPORTS[key].relative_to(ROOT)),
                "sha256": sha256(REPORTS[key]),
            }
            for key in sorted(REPORTS)
        ],
        "metrics": metrics,
        "qualityGateAudit": gate_headroom(),
        "phaseBins": rows,
        "classification": "fine-pair divergence is phase-localized descriptively; no threshold is applied and quantitative formation benefit remains unauthorized",
    }
    JSON_OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    with CSV_OUTPUT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    render(rows, metrics)
    print(
        json.dumps(
            {
                "json": str(JSON_OUTPUT.relative_to(ROOT)),
                "csv": str(CSV_OUTPUT.relative_to(ROOT)),
                "png": str(PNG_OUTPUT.relative_to(ROOT)),
                "powerResidualRMS": metrics["normalizedPowerContrastResidual"]["rms"],
                "powerResidualMaximumPhase": metrics["normalizedPowerContrastResidual"]["maximumPhase"],
                "qualityLimitedByAcceptanceGates": artifact["qualityGateAudit"]["qualityLimitedByAcceptanceGates"],
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

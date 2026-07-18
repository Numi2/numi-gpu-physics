#!/usr/bin/env python3
"""Apply the preregistered c16/c20 early-cycle field discriminator."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-early-cycle-fields-v1"
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
import numpy as np
from scipy.ndimage import distance_transform_edt


ROOT = Path(__file__).resolve().parent.parent
PREREGISTRATION = (
    ROOT / "ValidationInputs/formation-flight-early-cycle-field-replay-v1.json"
)
REPLAY_ROOT = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
CASES = {
    16: REPLAY_ROOT / "c16-best-z3-phase025",
    20: REPLAY_ROOT / "c20-best-z3-phase025",
}
SUMMARY = REPLAY_ROOT / "formation-flight-early-cycle-field-summary.json"
CSV = REPLAY_ROOT / "formation-flight-early-cycle-field-metrics.csv"
PNG = ROOT / "Docs/Media/formation-flight-early-cycle-field-discriminator.png"
SVG = ROOT / "Docs/Media/formation-flight-early-cycle-field-discriminator.svg"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bilinear_to_shape(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_height, source_width = values.shape
    target_height, target_width = shape
    source_z = (np.arange(target_height) + 0.5) * source_height / target_height - 0.5
    source_x = (np.arange(target_width) + 0.5) * source_width / target_width - 0.5
    z0 = np.floor(source_z).astype(int)
    x0 = np.floor(source_x).astype(int)
    z1 = np.clip(z0 + 1, 0, source_height - 1)
    x1 = np.clip(x0 + 1, 0, source_width - 1)
    z0 = np.clip(z0, 0, source_height - 1)
    x0 = np.clip(x0, 0, source_width - 1)
    wz = (source_z - z0)[:, None]
    wx = (source_x - x0)[None, :]
    return (
        (1 - wz) * (1 - wx) * values[z0[:, None], x0[None, :]]
        + (1 - wz) * wx * values[z0[:, None], x1[None, :]]
        + wz * (1 - wx) * values[z1[:, None], x0[None, :]]
        + wz * wx * values[z1[:, None], x1[None, :]]
    )


def nearest_to_shape(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_height, source_width = values.shape
    target_height, target_width = shape
    z = np.clip(
        np.floor((np.arange(target_height) + 0.5) * source_height / target_height).astype(int),
        0,
        source_height - 1,
    )
    x = np.clip(
        np.floor((np.arange(target_width) + 0.5) * source_width / target_width).astype(int),
        0,
        source_width - 1,
    )
    return values[z[:, None], x[None, :]]


def dilate_one(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    result = np.zeros_like(mask, dtype=bool)
    for dz in range(3):
        for dx in range(3):
            result |= padded[dz : dz + mask.shape[0], dx : dx + mask.shape[1]]
    return result


def arrays(slice_data: dict) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    shape = (slice_data["height"], slice_data["width"])
    vertical = np.asarray(slice_data["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape)
    vorticity = np.asarray(slice_data["vorticityMagnitudePerSecond"], dtype=float).reshape(shape)
    owner = np.asarray(slice_data["ownerMask"], dtype=np.uint8).reshape(shape)
    return vertical, vorticity, owner


def load_replay(resolution: int, preregistration: dict) -> dict:
    directory = CASES[resolution]
    report_path = directory / "formation-flight-field-replay-report.json"
    index_path = directory / "formation-flight-flow-slices/index.json"
    report = load(report_path)
    index = load(index_path)
    locked = {
        entry["path"]: entry["sha256"]
        for entry in preregistration["lockedInputs"]
    }
    reference_path = (
        f"ValidationArtifacts/formation-flight-promotion/c{resolution}-best-z3-phase025/formation-flight-report.json"
    )
    if report["referenceReportSHA256"] != locked[reference_path]:
        raise SystemExit(f"c{resolution} replay is not locked to the preregistered reference")
    configuration = report["configuration"]
    expected = preregistration["lockedConfiguration"]
    if configuration["chordCells"] != resolution:
        raise SystemExit(f"wrong resolution in c{resolution} replay")
    if configuration["cycles"] != expected["cycles"]:
        raise SystemExit(f"wrong cycle count in c{resolution} replay")
    if configuration["followerOffsetChords"] != expected["followerOffsetChords"]:
        raise SystemExit(f"wrong offset in c{resolution} replay")
    if not math.isclose(
        configuration["followerPhaseOffsetCycles"],
        expected["followerPhaseOffsetCycles"],
        abs_tol=1e-12,
    ):
        raise SystemExit(f"wrong phase offset in c{resolution} replay")
    if not report["gates"]["passed"]:
        raise SystemExit(f"c{resolution} field replay failed")
    if report["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > 1e-6:
        raise SystemExit(f"c{resolution} field replay did not reproduce its reference")

    targets = preregistration["fieldCapture"]["followerLocalTargetPhases"]
    tolerance = 0.51 / report["cycleSteps"]
    selected: dict[float, dict] = {}
    for target in targets:
        matches = [
            entry
            for entry in index["entries"]
            if abs(entry["followerPhase"] - target) <= tolerance
        ]
        if len(matches) != 1:
            raise SystemExit(
                f"c{resolution} expected exactly one field near follower phase {target}"
            )
        entry = matches[0]
        slice_path = directory / "formation-flight-flow-slices" / entry["file"]
        slice_data = load(slice_path)
        if slice_data["chordCells"] != resolution:
            raise SystemExit(f"wrong chordCells in {slice_path}")
        if not math.isclose(slice_data["phase"], entry["leaderPhase"], abs_tol=1e-12):
            raise SystemExit(f"index/slice phase mismatch in {slice_path}")
        selected[target] = {
            "entry": entry,
            "path": slice_path,
            "sha256": sha256(slice_path),
            "data": slice_data,
        }
    return {
        "report": report,
        "reportPath": report_path,
        "reportSHA256": sha256(report_path),
        "indexPath": index_path,
        "indexSHA256": sha256(index_path),
        "slices": selected,
    }


def rms(values: np.ndarray) -> float:
    return float(np.sqrt(np.mean(values * values))) if values.size else 0.0


def correlation(lhs: np.ndarray, rhs: np.ndarray) -> float:
    if lhs.size < 2 or rhs.size != lhs.size:
        return 0.0
    centered_lhs = lhs - np.mean(lhs)
    centered_rhs = rhs - np.mean(rhs)
    denominator = float(np.sqrt(np.sum(centered_lhs**2) * np.sum(centered_rhs**2)))
    return float(np.sum(centered_lhs * centered_rhs) / denominator) if denominator > 0 else 0.0


def compare_phase(coarse: dict, fine: dict) -> dict:
    w16, omega16, owner16 = arrays(coarse)
    w20, omega20, owner20 = arrays(fine)
    shape = w20.shape
    w16_common = bilinear_to_shape(w16, shape)
    omega16_common = bilinear_to_shape(omega16, shape)
    owner16_common = nearest_to_shape(owner16, shape)
    owner_union = (owner16_common > 0) | (owner20 > 0)
    valid = ~dilate_one(owner_union)
    if int(np.count_nonzero(valid)) < 1000:
        raise SystemExit("cross-grid common-fluid mask is unexpectedly small")
    near_boundary = (distance_transform_edt(~owner_union) <= 0.5 * fine["chordCells"]) & valid
    delta_w = w20 - w16_common
    delta_omega = omega20 - omega16_common
    w_scale = max(rms(w20[valid]), rms(w16_common[valid]), 1e-12)
    omega_scale = max(rms(omega20[valid]), rms(omega16_common[valid]), 1e-12)
    energy = (delta_w / w_scale) ** 2 + (delta_omega / omega_scale) ** 2
    total_energy = float(np.sum(energy[valid]))
    near_energy = float(np.sum(energy[near_boundary]))
    x_coordinates = (np.arange(shape[1]) + 0.5) / fine["chordCells"] - 0.5 * shape[1] / fine["chordCells"]
    z_coordinates = (np.arange(shape[0]) + 0.5) / fine["chordCells"] - 0.5 * shape[0] / fine["chordCells"]
    x_grid, z_grid = np.meshgrid(x_coordinates, z_coordinates)

    def location(mask: np.ndarray) -> dict:
        weights = np.where(mask, energy, 0)
        total = float(np.sum(weights))
        if total <= 0:
            return {
                "centroidXChords": 0.0,
                "centroidZChords": 0.0,
                "peakXChords": 0.0,
                "peakZChords": 0.0,
            }
        peak_index = np.unravel_index(int(np.argmax(weights)), weights.shape)
        return {
            "centroidXChords": float(np.sum(weights * x_grid) / total),
            "centroidZChords": float(np.sum(weights * z_grid) / total),
            "peakXChords": float(x_grid[peak_index]),
            "peakZChords": float(z_grid[peak_index]),
        }

    wake = valid & ~near_boundary
    return {
        "verticalVelocityNormalizedRMSDifference": rms(delta_w[valid]) / w_scale,
        "vorticityNormalizedRMSDifference": rms(delta_omega[valid]) / omega_scale,
        "verticalVelocitySpatialCorrelation": correlation(w16_common[valid], w20[valid]),
        "vorticitySpatialCorrelation": correlation(omega16_common[valid], omega20[valid]),
        "nearBoundaryResidualEnergyFraction": near_energy / total_energy if total_energy > 0 else 0.0,
        "commonFluidCellCount": int(np.count_nonzero(valid)),
        "nearBoundaryFluidCellCount": int(np.count_nonzero(near_boundary)),
        "normalizedResidualEnergy": total_energy,
        "nearBoundaryNormalizedResidualEnergy": near_energy,
        "nearBoundaryResidualLocation": location(near_boundary),
        "wakeResidualLocation": location(wake),
        "fields": {
            "w16": w16_common,
            "w20": w20,
            "deltaW": delta_w,
            "omega16": omega16_common,
            "omega20": omega20,
            "owner16": owner16_common,
            "owner20": owner20,
            "valid": valid,
            "nearBoundary": near_boundary,
        },
    }


def render_atlas(phase_results: list[dict], classification: str) -> None:
    selected_targets = (0.025, 0.055, 0.085)
    selected = [
        min(phase_results, key=lambda result: abs(result["targetFollowerPhase"] - target))
        for target in selected_targets
    ]
    velocity_values = np.concatenate(
        [
            result["fields"][field][result["fields"]["valid"]]
            for result in selected
            for field in ("w16", "w20")
        ]
    )
    difference_values = np.concatenate(
        [result["fields"]["deltaW"][result["fields"]["valid"]] for result in selected]
    )
    velocity_limit = max(float(np.quantile(np.abs(velocity_values), 0.995)), 1e-8)
    difference_limit = max(float(np.quantile(np.abs(difference_values), 0.995)), 1e-8)
    cmap = LinearSegmentedColormap.from_list(
        "birdflow_signed_vertical",
        [(0, "#0969c7"), (0.25, "#1ac8f4"), (0.5, "#071521"), (0.75, "#ffab42"), (1, "#ff493d")],
    )

    figure = plt.figure(figsize=(16, 11), facecolor="#06131e")
    grid = figure.add_gridspec(4, 3, height_ratios=(1, 1, 1, 0.72), left=0.055, right=0.96, top=0.79, bottom=0.09, hspace=0.16, wspace=0.08)
    column_titles = (
        f"c16 signed w  •  ±{velocity_limit:.3f} m/s",
        f"c20 signed w  •  ±{velocity_limit:.3f} m/s",
        f"c20 − c16 signed-w residual  •  ±{difference_limit:.3f} m/s",
    )
    for row, result in enumerate(selected):
        fields = result["fields"]
        extent = (-5, 5, -6.5, 6.5)
        for column, (field, limit) in enumerate(
            (("w16", velocity_limit), ("w20", velocity_limit), ("deltaW", difference_limit))
        ):
            axis = figure.add_subplot(grid[row, column])
            image_values = np.ma.masked_where(~fields["valid"], fields[field])
            axis.imshow(
                image_values,
                origin="lower",
                extent=extent,
                cmap=cmap,
                norm=Normalize(-limit, limit),
                interpolation="bilinear",
                rasterized=True,
            )
            owner = fields["owner16"] if column == 0 else fields["owner20"]
            x = np.linspace(extent[0], extent[1], owner.shape[1])
            z = np.linspace(extent[2], extent[3], owner.shape[0])
            if column < 2:
                omega = fields["omega16"] if column == 0 else fields["omega20"]
                omega_levels = np.quantile(
                    np.concatenate(
                        (fields["omega16"][fields["valid"]], fields["omega20"][fields["valid"]])
                    ),
                    (0.97, 0.992),
                )
                if omega_levels[1] > omega_levels[0] > 0:
                    axis.contour(
                        x,
                        z,
                        np.ma.masked_where(~fields["valid"], omega),
                        levels=omega_levels,
                        colors=("#f4d46b", "#ffffff"),
                        linewidths=(0.42, 0.75),
                        alpha=(0.55, 0.88),
                    )
            else:
                axis.contour(
                    x,
                    z,
                    fields["nearBoundary"],
                    levels=(0.5,),
                    colors=("#ff8d79",),
                    linewidths=0.65,
                    linestyles="dashed",
                    alpha=0.75,
                )
            axis.contour(x, z, owner == 1, levels=(0.5,), colors=("#c9f6ff",), linewidths=0.65)
            axis.contour(x, z, owner == 2, levels=(0.5,), colors=("#ffe0cb",), linewidths=0.65)
            axis.set_facecolor("#06131e")
            axis.set_aspect("equal")
            axis.set_xlim(-5, 5)
            axis.set_ylim(-5.7, 5.7)
            axis.set_xticks((-4, -2, 0, 2, 4))
            axis.set_yticks((-4, -2, 0, 2, 4) if column == 0 else ())
            axis.tick_params(colors="#7597a9", labelsize=7, length=2)
            for spine in axis.spines.values():
                spine.set_color("#24495c")
            if row == 0:
                axis.set_title(column_titles[column], color="#cceef9", fontsize=10, pad=8)
            if column == 0:
                axis.set_ylabel(
                    f"follower phase {result['targetFollowerPhase']:.3f}\nz / chord",
                    color="#9bb8c7",
                    fontsize=8,
                )
            if row == 2:
                axis.set_xlabel("x / chord", color="#9bb8c7", fontsize=8)

    metric_axis = figure.add_subplot(grid[3, :])
    phases = [result["actualFollowerPhase20"] for result in phase_results]
    metric_axis.plot(
        phases,
        [result["verticalVelocityNormalizedRMSDifference"] for result in phase_results],
        color="#43c6f5",
        marker="o",
        markersize=3.5,
        linewidth=1.7,
        label="normalized RMS Δw",
    )
    metric_axis.plot(
        phases,
        [result["vorticityNormalizedRMSDifference"] for result in phase_results],
        color="#f5c45a",
        marker="o",
        markersize=3.5,
        linewidth=1.7,
        label="normalized RMS Δ|ω|",
    )
    metric_axis.plot(
        phases,
        [result["nearBoundaryResidualEnergyFraction"] for result in phase_results],
        color="#ff7468",
        marker="o",
        markersize=3.5,
        linewidth=1.7,
        label="near-boundary residual fraction",
    )
    metric_axis.axvline(0.055, color="#e8f7ff", alpha=0.45, linestyle="--", linewidth=0.9)
    metric_axis.set_facecolor("#0a1c29")
    metric_axis.grid(color="#496b7d", alpha=0.20, linewidth=0.6)
    metric_axis.set_xlim(0, 0.1)
    metric_axis.set_xlabel("follower-local phase", color="#9bb8c7", fontsize=9)
    metric_axis.set_ylabel("dimensionless metric", color="#9bb8c7", fontsize=9)
    metric_axis.tick_params(colors="#7597a9", labelsize=8)
    metric_axis.legend(frameon=False, ncol=3, loc="upper right", fontsize=8, labelcolor="#b8d1dc")
    for spine in metric_axis.spines.values():
        spine.set_color("#24495c")

    figure.text(0.055, 0.958, "FORMATION FLIGHT OBSERVATORY", color="#dff7ff", fontsize=21, fontweight="bold")
    figure.text(0.055, 0.922, "early-cycle c16/c20 spatial discriminator • coupled-only replay locked to complete reports", color="#62c7eb", fontsize=11)
    aggregate_fraction = sum(result["nearBoundaryNormalizedResidualEnergy"] for result in phase_results) / max(
        sum(result["normalizedResidualEnergy"] for result in phase_results), 1e-12
    )
    figure.text(0.055, 0.866, "MECHANISM", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.055, 0.838, classification.upper(), color="#ffb858" if classification == "mixed" else "#67e5aa", fontsize=14, fontweight="bold")
    figure.text(0.25, 0.866, "NEAR-BOUNDARY ENERGY", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.25, 0.838, f"{100 * aggregate_fraction:.1f}%", color="#ff786c", fontsize=14, fontweight="bold")
    figure.text(0.46, 0.866, "REFERENCE REPLAY", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.46, 0.838, "EXACT / GATES PASS", color="#61e3a4", fontsize=14, fontweight="bold")
    figure.text(0.055, 0.025, "actual archived GPU fields • common scales • gold/white: 97th/99.2nd percentile |ω| • dashed: 0.5-chord boundary band • no quantitative claim authorization", color="#789dad", fontsize=8)

    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=180, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal early-cycle field discriminator v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal early-cycle field discriminator v1", "Date": None})
    plt.close(figure)


def main() -> int:
    preregistration = load(PREREGISTRATION)
    if not preregistration["preregisteredBeforeReplayExecution"]:
        raise SystemExit("field discriminator is not preregistered")
    for locked in preregistration["lockedInputs"]:
        path = ROOT / locked["path"]
        if sha256(path) != locked["sha256"]:
            raise SystemExit(f"locked input changed: {locked['path']}")

    replays = {resolution: load_replay(resolution, preregistration) for resolution in (16, 20)}
    phase_results = []
    for target in preregistration["fieldCapture"]["followerLocalTargetPhases"]:
        coarse_record = replays[16]["slices"][target]
        fine_record = replays[20]["slices"][target]
        result = compare_phase(coarse_record["data"], fine_record["data"])
        result.update(
            {
                "targetFollowerPhase": target,
                "actualFollowerPhase16": coarse_record["entry"]["followerPhase"],
                "actualFollowerPhase20": fine_record["entry"]["followerPhase"],
                "leaderPhase16": coarse_record["entry"]["leaderPhase"],
                "leaderPhase20": fine_record["entry"]["leaderPhase"],
                "c16SlicePath": str(coarse_record["path"].relative_to(ROOT)),
                "c16SliceSHA256": coarse_record["sha256"],
                "c20SlicePath": str(fine_record["path"].relative_to(ROOT)),
                "c20SliceSHA256": fine_record["sha256"],
            }
        )
        phase_results.append(result)

    total_energy = sum(result["normalizedResidualEnergy"] for result in phase_results)
    near_energy = sum(result["nearBoundaryNormalizedResidualEnergy"] for result in phase_results)
    near_fraction = near_energy / total_energy if total_energy > 0 else 0.0
    if near_fraction >= 0.60:
        classification = "nearBoundary"
        next_action = preregistration["decisionRule"]["nextRunIfNearBoundary"]
    elif near_fraction <= 0.40:
        classification = "wakeTransport"
        next_action = preregistration["decisionRule"]["nextRunIfWakeTransport"]
    else:
        classification = "mixed"
        next_action = preregistration["decisionRule"]["nextRunIfMixed"]

    near_probe = max(
        phase_results,
        key=lambda result: result["nearBoundaryNormalizedResidualEnergy"],
    )
    wake_probe = max(
        phase_results,
        key=lambda result: result["normalizedResidualEnergy"]
        - result["nearBoundaryNormalizedResidualEnergy"],
    )

    serializable_results = [
        {key: value for key, value in result.items() if key != "fields"}
        for result in phase_results
    ]
    artifact = {
        "schemaVersion": 1,
        "preregistration": {
            "path": str(PREREGISTRATION.relative_to(ROOT)),
            "sha256": sha256(PREREGISTRATION),
            "preregisteredBeforeReplayExecution": True,
        },
        "replays": {
            f"c{resolution}": {
                "reportPath": str(replay["reportPath"].relative_to(ROOT)),
                "reportSHA256": replay["reportSHA256"],
                "indexPath": str(replay["indexPath"].relative_to(ROOT)),
                "indexSHA256": replay["indexSHA256"],
                "runtimeSeconds": replay["report"]["runtimeSeconds"],
                "referenceCoupledHistoryRelativeDifference": replay["report"]["gates"]["maximumRelativeReferenceCoupledHistoryDifference"],
                "gatesPassed": replay["report"]["gates"]["passed"],
            }
            for resolution, replay in replays.items()
        },
        "phaseResults": serializable_results,
        "aggregate": {
            "nearBoundaryResidualEnergyFraction": near_fraction,
            "classification": classification,
        },
        "selectedProbes": {
            "nearBoundary": {
                "selectionRule": "maximum absolute near-boundary normalized residual energy across preregistered phases",
                "targetFollowerPhase": near_probe["targetFollowerPhase"],
                "actualFollowerPhase16": near_probe["actualFollowerPhase16"],
                "actualFollowerPhase20": near_probe["actualFollowerPhase20"],
                "normalizedResidualEnergy": near_probe[
                    "nearBoundaryNormalizedResidualEnergy"
                ],
                "location": near_probe["nearBoundaryResidualLocation"],
            },
            "wake": {
                "selectionRule": "maximum absolute outside-band normalized residual energy across preregistered phases",
                "targetFollowerPhase": wake_probe["targetFollowerPhase"],
                "actualFollowerPhase16": wake_probe["actualFollowerPhase16"],
                "actualFollowerPhase20": wake_probe["actualFollowerPhase20"],
                "normalizedResidualEnergy": wake_probe["normalizedResidualEnergy"]
                - wake_probe["nearBoundaryNormalizedResidualEnergy"],
                "location": wake_probe["wakeResidualLocation"],
            },
        },
        "quantitativeFormationClaimAuthorized": False,
        "nextAction": next_action,
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    with CSV.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=[
            "targetFollowerPhase",
            "actualFollowerPhase16",
            "actualFollowerPhase20",
            "verticalVelocityNormalizedRMSDifference",
            "vorticityNormalizedRMSDifference",
            "verticalVelocitySpatialCorrelation",
            "vorticitySpatialCorrelation",
            "nearBoundaryResidualEnergyFraction",
        ])
        writer.writeheader()
        for result in serializable_results:
            writer.writerow({key: result[key] for key in writer.fieldnames})
    render_atlas(phase_results, classification)
    print(json.dumps({
        "summary": str(SUMMARY.relative_to(ROOT)),
        "classification": classification,
        "nearBoundaryResidualEnergyFraction": near_fraction,
        "png": str(PNG.relative_to(ROOT)),
        "svg": str(SVG.relative_to(ROOT)),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

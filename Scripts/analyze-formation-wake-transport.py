#!/usr/bin/env python3
"""Preregistered wake displacement versus amplitude/diffusion discriminator."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-wake-transport-v1"
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
import numpy as np
from scipy.ndimage import shift as nd_shift


ROOT = Path(__file__).resolve().parent.parent
PREREGISTRATION = ROOT / "ValidationInputs/formation-flight-wake-transport-discriminator-v1.json"
EARLY_ROOT = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
OUTPUT_ROOT = ROOT / "ValidationArtifacts/formation-flight-wake-transport"
SUMMARY = OUTPUT_ROOT / "formation-flight-wake-transport-summary.json"
CSV = OUTPUT_ROOT / "formation-flight-wake-transport-metrics.csv"
PNG = ROOT / "Docs/Media/formation-flight-wake-transport-atlas.png"
SVG = ROOT / "Docs/Media/formation-flight-wake-transport-atlas.svg"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bilinear_to_shape(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_height, source_width = values.shape
    target_height, target_width = shape
    source_z = (np.arange(target_height) + 0.5) * source_height / target_height - 0.5
    source_x = (np.arange(target_width) + 0.5) * source_width / target_width - 0.5
    z0 = np.clip(np.floor(source_z).astype(int), 0, source_height - 1)
    x0 = np.clip(np.floor(source_x).astype(int), 0, source_width - 1)
    z1 = np.clip(z0 + 1, 0, source_height - 1)
    x1 = np.clip(x0 + 1, 0, source_width - 1)
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
    z = np.clip(np.floor((np.arange(target_height) + 0.5) * source_height / target_height).astype(int), 0, source_height - 1)
    x = np.clip(np.floor((np.arange(target_width) + 0.5) * source_width / target_width).astype(int), 0, source_width - 1)
    return values[z[:, None], x[None, :]]


def dilate_one(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    result = np.zeros_like(mask, dtype=bool)
    for dz in range(3):
        for dx in range(3):
            result |= padded[dz : dz + mask.shape[0], dx : dx + mask.shape[1]]
    return result


def rms(values: np.ndarray) -> float:
    return float(np.sqrt(np.mean(values * values))) if values.size else 0.0


def correlation(lhs: np.ndarray, rhs: np.ndarray) -> float:
    a = lhs - np.mean(lhs)
    b = rhs - np.mean(rhs)
    denominator = float(np.sqrt(np.sum(a * a) * np.sum(b * b)))
    return float(np.sum(a * b) / denominator) if denominator > 0 else 0.0


def load_phase(resolution: int, target: float) -> dict:
    directory = EARLY_ROOT / f"c{resolution}-best-z3-phase025"
    replay = load(directory / "formation-flight-field-replay-report.json")
    index = load(directory / "formation-flight-flow-slices/index.json")
    tolerance = 0.51 / replay["cycleSteps"]
    matches = [entry for entry in index["entries"] if abs(entry["followerPhase"] - target) <= tolerance]
    if len(matches) != 1:
        raise SystemExit(f"expected one c{resolution} field at follower phase {target}")
    entry = matches[0]
    path = directory / "formation-flight-flow-slices" / entry["file"]
    data = load(path)
    shape = (data["height"], data["width"])
    return {
        "vertical": np.asarray(data["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape),
        "vorticity": np.asarray(data["vorticityMagnitudePerSecond"], dtype=float).reshape(shape),
        "owner": np.asarray(data["ownerMask"], dtype=np.uint8).reshape(shape),
        "entry": entry,
        "path": path,
        "sha256": sha256(path),
    }


def shifted(values: np.ndarray, dz: int, dx: int, order: int = 1, cval: float = np.nan) -> np.ndarray:
    return nd_shift(values, shift=(dz, dx), order=order, mode="constant", cval=cval, prefilter=False)


def compare_phase(target: float, prereg: dict) -> dict:
    coarse = load_phase(16, target)
    fine = load_phase(20, target)
    shape = fine["vertical"].shape
    w16 = bilinear_to_shape(coarse["vertical"], shape)
    omega16 = bilinear_to_shape(coarse["vorticity"], shape)
    owner16 = nearest_to_shape(coarse["owner"], shape)
    w20 = fine["vertical"]
    omega20 = fine["vorticity"]
    owner20 = fine["owner"]
    chord_cells = 20
    x = (np.arange(shape[1]) + 0.5) / chord_cells - 0.5 * shape[1] / chord_cells
    z = (np.arange(shape[0]) + 0.5) / chord_cells - 0.5 * shape[0] / chord_cells
    x_grid, z_grid = np.meshgrid(x, z)
    region = prereg["wakeRegionChords"]
    roi = (
        (np.abs(x_grid - region["centerX"]) <= region["halfWidthX"])
        & (np.abs(z_grid - region["centerZ"]) <= region["halfWidthZ"])
    )
    valid16 = ~dilate_one(owner16 > 0)
    valid20 = ~dilate_one(owner20 > 0)
    maximum_cells = int(round(prereg["alignmentSearch"]["maximumAbsoluteShiftChords"] * chord_cells))
    increment_cells = int(round(prereg["alignmentSearch"]["shiftIncrementChords"] * chord_cells))
    candidates = list(range(-maximum_cells, maximum_cells + 1, increment_cells))
    fixed_valid = roi & valid20
    for dz in candidates:
        for dx in candidates:
            fixed_valid &= shifted(valid16.astype(np.uint8), dz, dx, order=0, cval=0) > 0
    if int(np.count_nonzero(fixed_valid)) < 500:
        raise SystemExit("locked wake region has too few common fluid cells")
    w_scale = max(rms(w16[fixed_valid]), rms(w20[fixed_valid]), 1e-12)
    omega_scale = max(rms(omega16[fixed_valid]), rms(omega20[fixed_valid]), 1e-12)

    def objective(dz: int, dx: int) -> tuple[float, np.ndarray, np.ndarray]:
        shifted_w = shifted(w16, dz, dx)
        shifted_omega = shifted(omega16, dz, dx)
        energy = ((w20 - shifted_w) / w_scale) ** 2 + ((omega20 - shifted_omega) / omega_scale) ** 2
        return float(np.sum(energy[fixed_valid])), shifted_w, shifted_omega

    base_energy, base_w, base_omega = objective(0, 0)
    best = (base_energy, 0, 0, base_w, base_omega)
    for dz in candidates:
        for dx in candidates:
            energy, candidate_w, candidate_omega = objective(dz, dx)
            key = (energy, abs(dz) + abs(dx), abs(dz), abs(dx), dz, dx)
            best_key = (best[0], abs(best[1]) + abs(best[2]), abs(best[1]), abs(best[2]), best[1], best[2])
            if key < best_key:
                best = (energy, dz, dx, candidate_w, candidate_omega)
    best_energy, best_dz, best_dx, aligned_w, aligned_omega = best
    reduction = (base_energy - best_energy) / base_energy if base_energy > 0 else 0.0
    return {
        "targetFollowerPhase": target,
        "actualFollowerPhase16": coarse["entry"]["followerPhase"],
        "actualFollowerPhase20": fine["entry"]["followerPhase"],
        "c16SlicePath": str(coarse["path"].relative_to(ROOT)),
        "c16SliceSHA256": coarse["sha256"],
        "c20SlicePath": str(fine["path"].relative_to(ROOT)),
        "c20SliceSHA256": fine["sha256"],
        "commonWakeCellCount": int(np.count_nonzero(fixed_valid)),
        "verticalVelocityScaleMetersPerSecond": w_scale,
        "vorticityScalePerSecond": omega_scale,
        "unshiftedNormalizedResidualEnergy": base_energy,
        "alignedNormalizedResidualEnergy": best_energy,
        "residualEnergyReductionFraction": reduction,
        "bestShiftXCells": best_dx,
        "bestShiftZCells": best_dz,
        "bestShiftXChords": best_dx / chord_cells,
        "bestShiftZChords": best_dz / chord_cells,
        "unshiftedVerticalVelocityCorrelation": correlation(w16[fixed_valid], w20[fixed_valid]),
        "alignedVerticalVelocityCorrelation": correlation(aligned_w[fixed_valid], w20[fixed_valid]),
        "unshiftedVorticityCorrelation": correlation(omega16[fixed_valid], omega20[fixed_valid]),
        "alignedVorticityCorrelation": correlation(aligned_omega[fixed_valid], omega20[fixed_valid]),
        "fields": {
            "baseDeltaW": w20 - w16,
            "alignedDeltaW": w20 - aligned_w,
            "valid": fixed_valid,
            "owner20": owner20,
        },
    }


def render(results: list[dict], classification: str, reduction: float) -> None:
    selected = [results[0], results[2], results[4]]
    values = np.concatenate([
        result["fields"][key][result["fields"]["valid"]]
        for result in selected for key in ("baseDeltaW", "alignedDeltaW")
    ])
    limit = max(float(np.quantile(np.abs(values), 0.995)), 1e-9)
    cmap = LinearSegmentedColormap.from_list(
        "wake_transport", [(0, "#0969c7"), (0.5, "#071521"), (1, "#ff493d")]
    )
    figure = plt.figure(figsize=(16, 10.5), facecolor="#06131e")
    grid = figure.add_gridspec(2, 3, left=0.055, right=0.965, top=0.79, bottom=0.09, hspace=0.18, wspace=0.12)
    extent = (-5, 5, -6.5, 6.5)
    for column, result in enumerate(selected):
        for row, key in enumerate(("baseDeltaW", "alignedDeltaW")):
            axis = figure.add_subplot(grid[row, column])
            axis.imshow(np.ma.masked_where(~result["fields"]["valid"], result["fields"][key]), origin="lower", extent=extent, cmap=cmap, norm=Normalize(-limit, limit), interpolation="bilinear", rasterized=True)
            axis.contour(np.linspace(-5, 5, result["fields"]["valid"].shape[1]), np.linspace(-6.5, 6.5, result["fields"]["valid"].shape[0]), result["fields"]["owner20"] > 0, levels=(0.5,), colors=("#eefbff",), linewidths=0.65)
            region = load(PREREGISTRATION)["wakeRegionChords"]
            rectangle = plt.Rectangle((region["centerX"] - region["halfWidthX"], region["centerZ"] - region["halfWidthZ"]), 2 * region["halfWidthX"], 2 * region["halfWidthZ"], fill=False, edgecolor="#74e0a7", linewidth=0.8, linestyle="--")
            axis.add_patch(rectangle)
            axis.set_xlim(-1, 4.6)
            axis.set_ylim(-4.2, 2.2)
            axis.set_aspect("equal")
            axis.set_xlabel("x / chord")
            if column == 0:
                axis.set_ylabel("z / chord")
            axis.set_title(
                f"{'UNSHIFTED' if row == 0 else 'ALIGNED'} • phase {result['targetFollowerPhase']:.3f}"
                + ("" if row == 0 else f" • Δ=({result['bestShiftXChords']:+.2f},{result['bestShiftZChords']:+.2f})c")
            )
            axis.set_facecolor("#0a1c29")
            axis.tick_params(colors="#86a8b9", labelsize=8)
            axis.xaxis.label.set_color("#a9c4d0")
            axis.yaxis.label.set_color("#a9c4d0")
            axis.title.set_color("#dff7ff")
            for spine in axis.spines.values():
                spine.set_color("#24495c")
    label = {
        "displacementDominated": "DISPLACEMENT DOMINATED",
        "amplitudeDiffusionDominated": "AMPLITUDE / DIFFUSION DOMINATED",
        "mixedTransportAmplitude": "MIXED TRANSPORT / AMPLITUDE",
    }[classification]
    mean_dx = float(np.mean([result["bestShiftXChords"] for result in results]))
    mean_dz = float(np.mean([result["bestShiftZChords"] for result in results]))
    figure.text(0.055, 0.955, "FORMATION WAKE TRANSPORT DISCRIMINATOR", color="#dff7ff", fontsize=22, fontweight="bold")
    figure.text(0.055, 0.918, "bounded common-grid alignment • five locked late phases • no new CFD", color="#62c7eb", fontsize=11)
    figure.text(0.055, 0.861, "MECHANISM", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.055, 0.832, label, color="#ffb858", fontsize=13, fontweight="bold")
    figure.text(0.38, 0.861, "RESIDUAL REMOVED", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.38, 0.832, f"{100 * reduction:.1f}%", color="#74e0a7", fontsize=15, fontweight="bold")
    figure.text(0.56, 0.861, "MEAN C16 SHIFT (x,z)", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.56, 0.832, f"({mean_dx:+.2f}, {mean_dz:+.2f}) chord", color="#b58cff", fontsize=14, fontweight="bold")
    figure.text(0.055, 0.025, f"common signed-w scale ±{limit:.3f} m/s • green dashed box: locked wake ROI • c16 shifted on the c20 cell-center grid • diagnostic only", color="#789dad", fontsize=8)
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=180, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal wake transport v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal wake transport v1", "Date": None})
    plt.close(figure)


def main() -> int:
    prereg = load(PREREGISTRATION)
    if not prereg["preregisteredBeforeAnalysis"]:
        raise SystemExit("wake transport discriminator was not preregistered")
    for locked in prereg["lockedInputs"]:
        if sha256(ROOT / locked["path"]) != locked["sha256"]:
            raise SystemExit(f"locked input changed: {locked['path']}")
    mechanism = load(ROOT / prereg["lockedInputs"][0]["path"])
    audit = load(ROOT / prereg["lockedInputs"][1]["path"])
    if mechanism["classification"] != prereg["sourceClassificationRequired"] or not audit["allChecksPassed"]:
        raise SystemExit("source mechanism classification or audit is not eligible")
    results = [compare_phase(phase, prereg) for phase in prereg["followerLocalPhases"]]
    unshifted = sum(result["unshiftedNormalizedResidualEnergy"] for result in results)
    aligned = sum(result["alignedNormalizedResidualEnergy"] for result in results)
    reduction = (unshifted - aligned) / unshifted if unshifted > 0 else 0.0
    decision = prereg["decisionRule"]
    if reduction >= decision["displacementDominatedMinimumReductionFraction"]:
        classification = "displacementDominated"
        next_action = decision["ifDisplacementDominated"]
    elif reduction <= decision["amplitudeDiffusionDominatedMaximumReductionFraction"]:
        classification = "amplitudeDiffusionDominated"
        next_action = decision["ifAmplitudeDiffusionDominated"]
    else:
        classification = "mixedTransportAmplitude"
        next_action = decision["ifMixed"]
    serializable = [{key: value for key, value in result.items() if key != "fields"} for result in results]
    artifact = {
        "schemaVersion": 1,
        "preregistration": {"path": str(PREREGISTRATION.relative_to(ROOT)), "sha256": sha256(PREREGISTRATION)},
        "phaseResults": serializable,
        "aggregate": {
            "unshiftedNormalizedResidualEnergy": unshifted,
            "alignedNormalizedResidualEnergy": aligned,
            "residualEnergyReductionFraction": reduction,
            "meanShiftXChords": float(np.mean([result["bestShiftXChords"] for result in results])),
            "meanShiftZChords": float(np.mean([result["bestShiftZChords"] for result in results])),
            "maximumShiftMagnitudeChords": max(math.hypot(result["bestShiftXChords"], result["bestShiftZChords"]) for result in results),
        },
        "classification": classification,
        "nextAction": next_action,
        "quantitativeFormationClaimAuthorized": False,
        "claimBoundary": prereg["claimBoundary"],
    }
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    with CSV.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=[key for key in serializable[0] if not key.endswith("Path") and not key.endswith("SHA256")])
        writer.writeheader()
        for result in serializable:
            writer.writerow({key: result[key] for key in writer.fieldnames})
    render(results, classification, reduction)
    print(json.dumps({"classification": classification, "residualEnergyReductionFraction": reduction, "meanShiftXChords": artifact["aggregate"]["meanShiftXChords"], "meanShiftZChords": artifact["aggregate"]["meanShiftZChords"], "summary": str(SUMMARY.relative_to(ROOT)), "png": str(PNG.relative_to(ROOT))}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

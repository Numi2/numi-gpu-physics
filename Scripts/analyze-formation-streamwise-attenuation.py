#!/usr/bin/env python3
"""Localize formation wake discrepancy along the locked streamwise ROI."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-streamwise-attenuation-v1"
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-streamwise-attenuation-localizer-v1.json"
BASE = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
COLLISION = ROOT / "ValidationArtifacts/formation-flight-collision-dissipation"
OUT = ROOT / "ValidationArtifacts/formation-flight-streamwise-attenuation"
SUMMARY = OUT / "formation-flight-streamwise-attenuation-summary.json"
CSV = OUT / "formation-flight-streamwise-attenuation-metrics.csv"
PNG = ROOT / "Docs/Media/formation-flight-streamwise-attenuation-atlas.png"
SVG = ROOT / "Docs/Media/formation-flight-streamwise-attenuation-atlas.svg"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rms(values: np.ndarray) -> float:
    return float(np.sqrt(np.mean(values * values))) if values.size else 0.0


def bilinear(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    sh, sw = values.shape
    th, tw = shape
    z = (np.arange(th) + 0.5) * sh / th - 0.5
    x = (np.arange(tw) + 0.5) * sw / tw - 0.5
    z0 = np.clip(np.floor(z).astype(int), 0, sh - 1)
    x0 = np.clip(np.floor(x).astype(int), 0, sw - 1)
    z1 = np.clip(z0 + 1, 0, sh - 1)
    x1 = np.clip(x0 + 1, 0, sw - 1)
    wz, wx = (z - z0)[:, None], (x - x0)[None, :]
    return ((1 - wz) * (1 - wx) * values[z0[:, None], x0[None, :]] + (1 - wz) * wx * values[z0[:, None], x1[None, :]] + wz * (1 - wx) * values[z1[:, None], x0[None, :]] + wz * wx * values[z1[:, None], x1[None, :]])


def nearest(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    sh, sw = values.shape
    th, tw = shape
    z = np.clip(np.floor((np.arange(th) + 0.5) * sh / th).astype(int), 0, sh - 1)
    x = np.clip(np.floor((np.arange(tw) + 0.5) * sw / tw).astype(int), 0, sw - 1)
    return values[z[:, None], x[None, :]]


def dilate(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    result = np.zeros_like(mask, dtype=bool)
    for dz in range(3):
        for dx in range(3):
            result |= padded[dz : dz + mask.shape[0], dx : dx + mask.shape[1]]
    return result


def case(kind: str) -> tuple[Path, str]:
    if kind == "trt16":
        return BASE / "c16-best-z3-phase025", "formation-flight-field-replay-report.json"
    if kind == "rr316":
        return COLLISION / "c16-rr3", "formation-flight-collision-diagnostic-report.json"
    return BASE / "c20-best-z3-phase025", "formation-flight-field-replay-report.json"


def phase(kind: str, target: float) -> dict:
    directory, report_name = case(kind)
    report = load(directory / report_name)
    index = load(directory / "formation-flight-flow-slices/index.json")
    tolerance = 0.51 / report["cycleSteps"]
    matches = [entry for entry in index["entries"] if abs(entry["followerPhase"] - target) <= tolerance]
    if len(matches) != 1:
        raise SystemExit(f"expected one {kind} slice at {target}")
    path = directory / "formation-flight-flow-slices" / matches[0]["file"]
    raw = load(path)
    shape = (raw["height"], raw["width"])
    return {
        "w": np.asarray(raw["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape),
        "o": np.asarray(raw["vorticityMagnitudePerSecond"], dtype=float).reshape(shape),
        "owner": np.asarray(raw["ownerMask"], dtype=np.uint8).reshape(shape),
        "path": str(path.relative_to(ROOT)),
        "sha256": digest(path),
    }


def analyze_phase(target: float, prereg: dict) -> dict:
    trt16, rr316, trt20 = phase("trt16", target), phase("rr316", target), phase("trt20", target)
    shape = trt20["w"].shape
    w16, o16 = bilinear(trt16["w"], shape), bilinear(trt16["o"], shape)
    wr, orr = bilinear(rr316["w"], shape), bilinear(rr316["o"], shape)
    w20, o20 = trt20["w"], trt20["o"]
    owners = (nearest(trt16["owner"], shape) > 0) | (nearest(rr316["owner"], shape) > 0) | (trt20["owner"] > 0)
    x = (np.arange(shape[1]) + 0.5) / 20 - 0.5 * shape[1] / 20
    z = (np.arange(shape[0]) + 0.5) / 20 - 0.5 * shape[0] / 20
    xx, zz = np.meshgrid(x, z)
    region = prereg["lockedWakeRegionChords"]
    roi = (xx >= region["minimumX"]) & (xx <= region["maximumX"]) & (zz >= region["minimumZ"]) & (zz <= region["maximumZ"]) & ~dilate(owners)
    w_scale = max(rms(w16[roi]), rms(w20[roi]), 1e-12)
    o_scale = max(rms(o16[roi]), rms(o20[roi]), 1e-12)
    trt_residual = ((w20 - w16) / w_scale) ** 2 + ((o20 - o16) / o_scale) ** 2
    rr3_residual = ((w20 - wr) / w_scale) ** 2 + ((o20 - orr) / o_scale) ** 2
    bands = []
    for band in prereg["streamwiseBands"]:
        mask = roi & (xx >= band["minimumX"]) & (xx < band["maximumX"] if band["name"] != "downstream" else xx <= band["maximumX"])
        count = int(np.count_nonzero(mask))
        bands.append({
            "band": band["name"],
            "validCellCount": count,
            "trtResidualEnergy": float(np.sum(trt_residual[mask])),
            "rr3ResidualEnergy": float(np.sum(rr3_residual[mask])),
            "trtResidualDensity": float(np.mean(trt_residual[mask])),
            "rr3ResidualDensity": float(np.mean(rr3_residual[mask])),
            "verticalVelocityTRT16RMS": rms(w16[mask]),
            "verticalVelocityTRT20RMS": rms(w20[mask]),
            "vorticityTRT16RMS": rms(o16[mask]),
            "vorticityTRT20RMS": rms(o20[mask]),
        })
    return {
        "targetFollowerPhase": target,
        "verticalVelocityScaleMetersPerSecond": w_scale,
        "vorticityScalePerSecond": o_scale,
        "trt16SlicePath": trt16["path"],
        "trt16SliceSHA256": trt16["sha256"],
        "rr316SlicePath": rr316["path"],
        "rr316SliceSHA256": rr316["sha256"],
        "trt20SlicePath": trt20["path"],
        "trt20SliceSHA256": trt20["sha256"],
        "bands": bands,
        "map": {"residual": trt_residual, "roi": roi, "owner": trt20["owner"]},
    }


def render(results: list[dict], summary: dict, prereg: dict) -> None:
    selected = [results[0], results[2], results[4]]
    values = np.concatenate([item["map"]["residual"][item["map"]["roi"]] for item in selected])
    limit = max(float(np.quantile(values, 0.995)), 1e-12)
    cmap = LinearSegmentedColormap.from_list("attenuation", ["#071521", "#0e6796", "#52d7b2", "#ffd166", "#ff4f4a"])
    cmap.set_bad("#071521")
    figure = plt.figure(figsize=(16, 10.2), facecolor="#06131e")
    grid = figure.add_gridspec(2, 3, left=0.055, right=0.96, top=0.78, bottom=0.09, height_ratios=(1.25, 0.9), hspace=0.25, wspace=0.15)
    for column, item in enumerate(selected):
        axis = figure.add_subplot(grid[0, column])
        field = np.ma.masked_where(~item["map"]["roi"], item["map"]["residual"])
        axis.imshow(field, origin="lower", extent=(-5, 5, -6.5, 6.5), cmap=cmap, norm=Normalize(0, limit), interpolation="bilinear", rasterized=True)
        axis.set_facecolor("#071521")
        for band in prereg["streamwiseBands"][1:]:
            axis.axvline(band["minimumX"], color="#dff7ff", linewidth=0.8, linestyle="--", alpha=0.8)
        axis.set_xlim(0.65, 4.0)
        axis.set_ylim(-3.55, 1.3)
        axis.set_aspect("equal")
        axis.set_title(f"TRT c16→c20 residual • phase {item['targetFollowerPhase']:.3f}", color="#dff7ff", fontsize=10)
        axis.set_xlabel("x / chord", color="#a9c4d0")
        if column == 0:
            axis.set_ylabel("z / chord", color="#a9c4d0")
        axis.tick_params(colors="#86a8b9", labelsize=8)
        for spine in axis.spines.values():
            spine.set_color("#24495c")
    axis = figure.add_subplot(grid[1, :2])
    names = [band["band"].upper() for band in summary["aggregateBands"]]
    x = np.arange(len(names))
    trt = [band["trtResidualDensity"] for band in summary["aggregateBands"]]
    rr3 = [band["rr3ResidualDensity"] for band in summary["aggregateBands"]]
    axis.plot(x, trt, marker="o", linewidth=2.5, color="#62c7eb", label="TRT c16 → TRT c20")
    axis.plot(x, rr3, marker="o", linewidth=2.0, color="#ffb858", label="RR3 c16 → TRT c20")
    axis.set_xticks(x, names)
    axis.set_ylabel("normalized residual energy / cell", color="#a9c4d0")
    axis.set_facecolor("#0a1c29")
    axis.tick_params(colors="#9bb9c8")
    axis.grid(axis="y", color="#24495c", alpha=0.55)
    axis.legend(frameon=False, labelcolor="#dff7ff", loc="upper left")
    for spine in axis.spines.values():
        spine.set_color("#24495c")
    card = figure.add_subplot(grid[1, 2])
    card.set_facecolor("#0a1c29")
    card.set_xticks([]); card.set_yticks([])
    for spine in card.spines.values():
        spine.set_color("#24495c")
    ratio = summary["downstreamToUpstreamTRTResidualDensityRatio"]
    card.text(0.08, 0.82, "DOWNSTREAM / UPSTREAM", color="#718f9f", fontsize=9, fontweight="bold", transform=card.transAxes)
    card.text(0.08, 0.64, f"{ratio:.3f}×", color="#74e0a7", fontsize=24, fontweight="bold", transform=card.transAxes)
    card.text(0.08, 0.44, "MECHANISM", color="#718f9f", fontsize=9, fontweight="bold", transform=card.transAxes)
    label = {
        "sourceAmplitudeDominated": "SOURCE AMPLITUDE\nDOMINATED",
        "downstreamAttenuationDominated": "DOWNSTREAM ATTENUATION\nDOMINATED",
        "mixedSourceTransport": "MIXED SOURCE /\nTRANSPORT",
    }[summary["classification"]]
    card.text(0.08, 0.27, label, color="#ffb858", fontsize=12, fontweight="bold", transform=card.transAxes, wrap=True)
    card.text(0.08, 0.08, "center-plane selector\nnot a 3-D energy budget", color="#789dad", fontsize=8, transform=card.transAxes)
    figure.text(0.055, 0.95, "FORMATION WAKE: SOURCE OR DOWNSTREAM ATTENUATION?", color="#dff7ff", fontsize=22, fontweight="bold")
    figure.text(0.055, 0.912, "five locked phases • three one-chord streamwise bands • no new CFD", color="#62c7eb", fontsize=11)
    figure.text(0.055, 0.835, "UPSTREAM", color="#74e0a7", fontsize=10, fontweight="bold")
    figure.text(0.18, 0.835, "→", color="#718f9f", fontsize=11)
    figure.text(0.22, 0.835, "MIDDLE", color="#ffd166", fontsize=10, fontweight="bold")
    figure.text(0.33, 0.835, "→", color="#718f9f", fontsize=11)
    figure.text(0.37, 0.835, "DOWNSTREAM", color="#ff7a68", fontsize=10, fontweight="bold")
    figure.text(0.055, 0.025, "normalized signed-w + vorticity residual • dashed lines separate preregistered bands • production remains TRT", color="#789dad", fontsize=8)
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=180, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal streamwise attenuation v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal streamwise attenuation v1", "Date": None})
    plt.close(figure)


def main() -> int:
    prereg = load(PREREG)
    if not prereg["preregisteredBeforeAnalysis"]:
        raise SystemExit("attenuation localizer was not preregistered")
    for locked in prereg["lockedInputs"]:
        if digest(ROOT / locked["path"]) != locked["sha256"]:
            raise SystemExit(f"locked input changed: {locked['path']}")
    collision = load(ROOT / prereg["lockedInputs"][0]["path"])
    if collision["classification"] != prereg["requiredCollisionClassification"]:
        raise SystemExit("collision result does not authorize attenuation localization")
    results = [analyze_phase(value, prereg) for value in prereg["followerLocalPhases"]]
    aggregate = []
    for index, band in enumerate(prereg["streamwiseBands"]):
        cells = sum(item["bands"][index]["validCellCount"] for item in results)
        trt_energy = sum(item["bands"][index]["trtResidualEnergy"] for item in results)
        rr3_energy = sum(item["bands"][index]["rr3ResidualEnergy"] for item in results)
        aggregate.append({"band": band["name"], "validCellSamples": cells, "trtResidualEnergy": trt_energy, "rr3ResidualEnergy": rr3_energy, "trtResidualDensity": trt_energy / cells, "rr3ResidualDensity": rr3_energy / cells})
    ratio = aggregate[2]["trtResidualDensity"] / aggregate[0]["trtResidualDensity"]
    rule = prereg["decisionRule"]
    if ratio >= rule["downstreamToUpstreamResidualDensityRatioAtLeastForTransportDominated"]:
        classification = "downstreamAttenuationDominated"
        next_action = rule["ifTransportDominated"]
    elif ratio <= rule["downstreamToUpstreamResidualDensityRatioAtMostForSourceDominated"]:
        classification = "sourceAmplitudeDominated"
        next_action = rule["ifSourceDominated"]
    else:
        classification = "mixedSourceTransport"
        next_action = rule["ifMixed"]
    summary = {
        "schemaVersion": 1,
        "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
        "aggregateBands": aggregate,
        "downstreamToUpstreamTRTResidualDensityRatio": ratio,
        "classification": classification,
        "nextAction": next_action,
        "phaseResults": [{key: value for key, value in item.items() if key != "map"} for item in results],
        "newFluidSimulationRequired": False,
        "productionSolverChanged": False,
        "quantitativeFormationClaimAuthorized": False,
        "claimBoundary": prereg["claimBoundary"],
    }
    OUT.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    with CSV.open("w", newline="") as handle:
        fields = ["targetFollowerPhase", "band", "validCellCount", "trtResidualEnergy", "rr3ResidualEnergy", "trtResidualDensity", "rr3ResidualDensity", "verticalVelocityTRT16RMS", "verticalVelocityTRT20RMS", "vorticityTRT16RMS", "vorticityTRT20RMS"]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for item in results:
            for band in item["bands"]:
                writer.writerow({"targetFollowerPhase": item["targetFollowerPhase"], **band})
    render(results, summary, prereg)
    print(json.dumps({"classification": classification, "downstreamToUpstreamResidualDensityRatio": ratio, "nextAction": next_action}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

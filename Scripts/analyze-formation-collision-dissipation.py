#!/usr/bin/env python3
"""Analyze the preregistered sequential formation collision discriminator."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-collision-dissipation-v1"
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-collision-dissipation-discriminator-v1.json"
WAKE_PREREG = ROOT / "ValidationInputs/formation-flight-wake-transport-discriminator-v1.json"
BASE = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
OUT = ROOT / "ValidationArtifacts/formation-flight-collision-dissipation"
C16 = OUT / "c16-rr3"
C20 = OUT / "c20-rr3"
SUMMARY = OUT / "formation-flight-collision-dissipation-summary.json"
CSV = OUT / "formation-flight-collision-dissipation-metrics.csv"
PNG = ROOT / "Docs/Media/formation-flight-collision-dissipation-atlas.png"
SVG = ROOT / "Docs/Media/formation-flight-collision-dissipation-atlas.svg"
REPORT_NAME = "formation-flight-collision-diagnostic-report.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rms(values: np.ndarray) -> float:
    return float(np.sqrt(np.mean(values * values))) if values.size else 0.0


def corr(lhs: np.ndarray, rhs: np.ndarray) -> float:
    a = lhs - np.mean(lhs)
    b = rhs - np.mean(rhs)
    denominator = float(np.sqrt(np.sum(a * a) * np.sum(b * b)))
    return float(np.sum(a * b) / denominator) if denominator > 0 else 0.0


def bilinear(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_h, source_w = values.shape
    target_h, target_w = shape
    z = (np.arange(target_h) + 0.5) * source_h / target_h - 0.5
    x = (np.arange(target_w) + 0.5) * source_w / target_w - 0.5
    z0 = np.clip(np.floor(z).astype(int), 0, source_h - 1)
    x0 = np.clip(np.floor(x).astype(int), 0, source_w - 1)
    z1 = np.clip(z0 + 1, 0, source_h - 1)
    x1 = np.clip(x0 + 1, 0, source_w - 1)
    wz = (z - z0)[:, None]
    wx = (x - x0)[None, :]
    return (
        (1 - wz) * (1 - wx) * values[z0[:, None], x0[None, :]]
        + (1 - wz) * wx * values[z0[:, None], x1[None, :]]
        + wz * (1 - wx) * values[z1[:, None], x0[None, :]]
        + wz * wx * values[z1[:, None], x1[None, :]]
    )


def nearest(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_h, source_w = values.shape
    target_h, target_w = shape
    z = np.clip(np.floor((np.arange(target_h) + 0.5) * source_h / target_h).astype(int), 0, source_h - 1)
    x = np.clip(np.floor((np.arange(target_w) + 0.5) * source_w / target_w).astype(int), 0, source_w - 1)
    return values[z[:, None], x[None, :]]


def dilate(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant", constant_values=False)
    result = np.zeros_like(mask, dtype=bool)
    for dz in range(3):
        for dx in range(3):
            result |= padded[dz : dz + mask.shape[0], dx : dx + mask.shape[1]]
    return result


def case_root(kind: str, resolution: int) -> Path:
    if kind == "trt":
        return BASE / f"c{resolution}-best-z3-phase025"
    return OUT / f"c{resolution}-rr3"


def report(kind: str, resolution: int) -> dict:
    name = "formation-flight-field-replay-report.json" if kind == "trt" else REPORT_NAME
    return load(case_root(kind, resolution) / name)


def phase_slice(kind: str, resolution: int, follower_phase: float) -> dict:
    directory = case_root(kind, resolution)
    rep = report(kind, resolution)
    index = load(directory / "formation-flight-flow-slices/index.json")
    tolerance = 0.51 / rep["cycleSteps"]
    matches = [entry for entry in index["entries"] if abs(entry["followerPhase"] - follower_phase) <= tolerance]
    if len(matches) != 1:
        raise SystemExit(f"expected one {kind} c{resolution} slice at follower phase {follower_phase}")
    path = directory / "formation-flight-flow-slices" / matches[0]["file"]
    data = load(path)
    shape = (data["height"], data["width"])
    return {
        "vertical": np.asarray(data["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape),
        "vorticity": np.asarray(data["vorticityMagnitudePerSecond"], dtype=float).reshape(shape),
        "owner": np.asarray(data["ownerMask"], dtype=np.uint8).reshape(shape),
        "path": path,
        "sha256": digest(path),
        "actual": matches[0]["followerPhase"],
    }


def field_phase(target: float, wake: dict) -> dict:
    base16 = phase_slice("trt", 16, target)
    candidate = phase_slice("rr3", 16, target)
    base20 = phase_slice("trt", 20, target)
    shape = base20["vertical"].shape
    w16 = bilinear(base16["vertical"], shape)
    o16 = bilinear(base16["vorticity"], shape)
    wc = bilinear(candidate["vertical"], shape)
    oc = bilinear(candidate["vorticity"], shape)
    w20 = base20["vertical"]
    o20 = base20["vorticity"]
    owner16 = nearest(base16["owner"], shape)
    ownerc = nearest(candidate["owner"], shape)
    owner20 = base20["owner"]
    chord = 20
    x = (np.arange(shape[1]) + 0.5) / chord - 0.5 * shape[1] / chord
    z = (np.arange(shape[0]) + 0.5) / chord - 0.5 * shape[0] / chord
    xx, zz = np.meshgrid(x, z)
    region = wake["wakeRegionChords"]
    roi = (
        (np.abs(xx - region["centerX"]) <= region["halfWidthX"])
        & (np.abs(zz - region["centerZ"]) <= region["halfWidthZ"])
    )
    valid = roi & ~dilate((owner16 > 0) | (ownerc > 0) | (owner20 > 0))
    if np.count_nonzero(valid) < 500:
        raise SystemExit("collision discriminator wake ROI has too few common cells")
    w_scale = max(rms(w16[valid]), rms(w20[valid]), 1e-12)
    o_scale = max(rms(o16[valid]), rms(o20[valid]), 1e-12)
    baseline_energy = float(np.sum(((w20 - w16) / w_scale) ** 2 + ((o20 - o16) / o_scale) ** 2, where=valid))
    candidate_energy = float(np.sum(((w20 - wc) / w_scale) ** 2 + ((o20 - oc) / o_scale) ** 2, where=valid))
    reduction = (baseline_energy - candidate_energy) / baseline_energy if baseline_energy > 0 else 0.0
    return {
        "targetFollowerPhase": target,
        "actualCandidateFollowerPhase": candidate["actual"],
        "commonWakeCellCount": int(np.count_nonzero(valid)),
        "verticalVelocityScaleMetersPerSecond": w_scale,
        "vorticityScalePerSecond": o_scale,
        "baselineTRTNormalizedResidualEnergy": baseline_energy,
        "candidateRR3NormalizedResidualEnergy": candidate_energy,
        "candidateResidualEnergyReductionFraction": reduction,
        "baselineVerticalVelocityCorrelation": corr(w16[valid], w20[valid]),
        "candidateVerticalVelocityCorrelation": corr(wc[valid], w20[valid]),
        "baselineVorticityCorrelation": corr(o16[valid], o20[valid]),
        "candidateVorticityCorrelation": corr(oc[valid], o20[valid]),
        "candidateSlicePath": str(candidate["path"].relative_to(ROOT)),
        "candidateSliceSHA256": candidate["sha256"],
        "fields": {
            "baseline": w20 - w16,
            "candidate": w20 - wc,
            "valid": valid,
            "owner": owner20,
        },
    }


def force_residual(lhs: dict, reference: dict, signals: list[str]) -> tuple[float, dict[str, float]]:
    energies: dict[str, float] = {}
    total = 0.0
    for signal in signals:
        a = np.asarray([sample[signal] for sample in lhs["phaseSamples"]], dtype=float)
        b = np.asarray([sample[signal] for sample in reference["phaseSamples"]], dtype=float)
        scale = max(rms(b), 1e-12)
        energy = float(np.sum(((a - b) / scale) ** 2))
        energies[signal] = energy
        total += energy
    return total, energies


def relative_force_difference(lhs: dict, rhs: dict, signals: list[str]) -> float:
    numerator = 0.0
    denominator = 0.0
    for signal in signals:
        a = np.asarray([sample[signal] for sample in lhs["phaseSamples"]], dtype=float)
        b = np.asarray([sample[signal] for sample in rhs["phaseSamples"]], dtype=float)
        numerator += float(np.sum((a - b) ** 2))
        denominator += float(np.sum(0.5 * (a * a + b * b)))
    return math.sqrt(numerator / denominator) if denominator > 0 else math.inf


def render(phases: list[dict], summary: dict) -> None:
    selected = [phases[0], phases[2], phases[4]]
    values = np.concatenate([
        result["fields"][key][result["fields"]["valid"]]
        for result in selected for key in ("baseline", "candidate")
    ])
    limit = max(float(np.quantile(np.abs(values), 0.995)), 1e-9)
    cmap = LinearSegmentedColormap.from_list("collision", [(0, "#0879d1"), (0.5, "#071521"), (1, "#ff4f4a")])
    figure = plt.figure(figsize=(16, 10.5), facecolor="#06131e")
    grid = figure.add_gridspec(2, 3, left=0.055, right=0.965, top=0.79, bottom=0.09, hspace=0.18, wspace=0.12)
    for column, result in enumerate(selected):
        for row, key in enumerate(("baseline", "candidate")):
            axis = figure.add_subplot(grid[row, column])
            field = np.ma.masked_where(~result["fields"]["valid"], result["fields"][key])
            axis.imshow(field, origin="lower", extent=(-5, 5, -6.5, 6.5), cmap=cmap, norm=Normalize(-limit, limit), interpolation="bilinear", rasterized=True)
            axis.contour(np.linspace(-5, 5, field.shape[1]), np.linspace(-6.5, 6.5, field.shape[0]), result["fields"]["owner"] > 0, levels=(0.5,), colors=("#edfaff",), linewidths=0.65)
            axis.set_xlim(-1, 4.6)
            axis.set_ylim(-4.2, 2.2)
            axis.set_aspect("equal")
            axis.set_title(f"{'TRT c16 → c20' if row == 0 else 'RR3 c16 → TRT c20'} • phase {result['targetFollowerPhase']:.3f}")
            axis.set_facecolor("#0a1c29")
            axis.tick_params(colors="#86a8b9", labelsize=8)
            axis.set_xlabel("x / chord", color="#a9c4d0")
            if column == 0:
                axis.set_ylabel("z / chord", color="#a9c4d0")
            axis.title.set_color("#dff7ff")
            for spine in axis.spines.values():
                spine.set_color("#24495c")
    promotion = summary["promotion"]["c20CandidateAuthorized"]
    color = "#74e0a7" if promotion else "#ffb858"
    figure.text(0.055, 0.955, "FORMATION COLLISION / DISSIPATION DISCRIMINATOR", color="#dff7ff", fontsize=21, fontweight="bold")
    figure.text(0.055, 0.918, "one-variable RR3 screen • every population, every step • locked wake ROI", color="#62c7eb", fontsize=11)
    figure.text(0.055, 0.861, "WAKE RESIDUAL CHANGE", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.055, 0.832, f"{100 * summary['screen']['aggregateWakeResidualEnergyReductionFraction']:+.1f}%", color=color, fontsize=16, fontweight="bold")
    figure.text(0.30, 0.861, "FORCE RESIDUAL CHANGE", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.30, 0.832, f"{100 * summary['screen']['dimensionlessForceResidualEnergyReductionFraction']:+.1f}%", color=color, fontsize=16, fontweight="bold")
    figure.text(0.56, 0.861, "C16 RR3 NUMERICS", color="#718f9f", fontsize=8, fontweight="bold")
    gate = summary["screen"]["candidateNumericalGatesPassed"]
    figure.text(0.56, 0.832, "PASS" if gate else "FAIL", color="#74e0a7" if gate else "#ff5f57", fontsize=16, fontweight="bold")
    figure.text(0.75, 0.861, "C20 DECISION", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.75, 0.832, "AUTHORIZED" if promotion else "STOPPED", color=color, fontsize=16, fontweight="bold")
    figure.text(0.055, 0.025, f"signed vertical-velocity residual, common scale ±{limit:.3g} m/s • c20 TRT is a discriminator reference, not truth • production remains TRT", color="#789dad", fontsize=8)
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=180, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal collision discriminator v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal collision discriminator v1", "Date": None})
    plt.close(figure)


def main() -> int:
    prereg = load(PREREG)
    wake = load(WAKE_PREREG)
    if not prereg["preregisteredBeforeCandidateExecution"]:
        raise SystemExit("collision discriminator was not preregistered")
    for locked in prereg["lockedInputs"]:
        if digest(ROOT / locked["path"]) != locked["sha256"]:
            raise SystemExit(f"locked input changed: {locked['path']}")
    source = load(ROOT / prereg["lockedInputs"][0]["path"])
    if source["classification"] != prereg["requiredSourceClassification"]:
        raise SystemExit("locked source classification does not authorize this discriminator")
    candidate = report("rr3", 16)
    if candidate["collisionOperator"] != prereg["candidateOperator"]:
        raise SystemExit("c16 candidate used the wrong collision operator")
    expected = prereg["fixedFormationConfiguration"]
    configuration = candidate["configuration"]
    if configuration["chordCells"] != 16 or configuration["cycles"] != expected["cycles"] or configuration["followerOffsetChords"] != expected["followerOffsetChords"] or configuration["followerPhaseOffsetCycles"] != expected["followerPhaseOffsetCycles"]:
        raise SystemExit("c16 candidate configuration is not the preregistered case")

    phases = [field_phase(value, wake) for value in prereg["screen"]["followerLocalPhases"]]
    baseline_wake = sum(item["baselineTRTNormalizedResidualEnergy"] for item in phases)
    candidate_wake = sum(item["candidateRR3NormalizedResidualEnergy"] for item in phases)
    wake_reduction = (baseline_wake - candidate_wake) / baseline_wake
    signals = prereg["screen"]["forceSignals"]
    baseline16 = report("trt", 16)
    baseline20 = report("trt", 20)
    baseline_force, baseline_force_signals = force_residual(baseline16, baseline20, signals)
    candidate_force, candidate_force_signals = force_residual(candidate, baseline20, signals)
    force_reduction = (baseline_force - candidate_force) / baseline_force
    numerical = bool(candidate["gates"]["passed"])
    rule = prereg["promotionRule"]
    promote = numerical and wake_reduction >= rule["minimumAggregateWakeResidualEnergyReductionFraction"] and force_reduction >= rule["minimumDimensionlessForceResidualEnergyReductionFraction"]

    fine = None
    if (C20 / REPORT_NAME).is_file():
        candidate20 = report("rr3", 20)
        if candidate20["collisionOperator"] != prereg["candidateOperator"]:
            raise SystemExit("c20 candidate used the wrong collision operator")
        same_operator = relative_force_difference(candidate, candidate20, signals)
        fine_sensitivity = relative_force_difference(baseline20, candidate20, signals)
        fine_rule = prereg["fineRunInterpretation"]
        fine_passed = bool(candidate20["gates"]["passed"]) and same_operator <= fine_rule["maximumAcceptableSameOperatorC16ToC20ForceHistoryRelativeDifference"] and fine_sensitivity <= fine_rule["maximumAcceptableC20TRTToRR3ForceHistoryRelativeDifference"]
        fine = {
            "candidateNumericalGatesPassed": bool(candidate20["gates"]["passed"]),
            "sameOperatorC16ToC20ForceHistoryRelativeDifference": same_operator,
            "c20TRTToRR3ForceHistoryRelativeDifference": fine_sensitivity,
            "fineRunQualified": fine_passed,
            "reportPath": str((C20 / REPORT_NAME).relative_to(ROOT)),
            "reportSHA256": digest(C20 / REPORT_NAME),
        }

    if not numerical:
        classification = "candidateRejectedNumerically"
    elif promote and fine is None:
        classification = "c20RR3RunAuthorized"
    elif promote and fine["fineRunQualified"]:
        classification = "rr3FormationRefinementAuthorized"
    elif promote:
        classification = "fineGridCollisionBiasUnresolved"
    elif wake_reduction <= 0 or force_reduction <= 0:
        classification = "collisionChangeAdverseOrUnsupported"
    else:
        classification = "mixedCollisionSensitivityBelowPromotion"

    summary = {
        "schemaVersion": 1,
        "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
        "controlOperator": prereg["controlOperator"],
        "candidateOperator": prereg["candidateOperator"],
        "screen": {
            "candidateNumericalGatesPassed": numerical,
            "minimumPopulation": candidate["gates"]["minimumPopulation"],
            "collisionCorrectionActivationFraction": candidate["gates"]["collisionCorrectionActivationFraction"],
            "aggregateBaselineWakeResidualEnergy": baseline_wake,
            "aggregateCandidateWakeResidualEnergy": candidate_wake,
            "aggregateWakeResidualEnergyReductionFraction": wake_reduction,
            "baselineDimensionlessForceResidualEnergy": baseline_force,
            "candidateDimensionlessForceResidualEnergy": candidate_force,
            "dimensionlessForceResidualEnergyReductionFraction": force_reduction,
            "baselineForceSignalEnergies": baseline_force_signals,
            "candidateForceSignalEnergies": candidate_force_signals,
            "candidateReportPath": str((C16 / REPORT_NAME).relative_to(ROOT)),
            "candidateReportSHA256": digest(C16 / REPORT_NAME),
        },
        "phaseResults": [{key: value for key, value in item.items() if key != "fields"} for item in phases],
        "promotion": {
            "minimumWakeReductionFraction": rule["minimumAggregateWakeResidualEnergyReductionFraction"],
            "minimumForceReductionFraction": rule["minimumDimensionlessForceResidualEnergyReductionFraction"],
            "c20CandidateAuthorized": promote,
            "c20CandidateExecuted": fine is not None,
        },
        "fineRun": fine,
        "classification": classification,
        "productionCollisionOperatorChanged": False,
        "quantitativeFormationClaimAuthorized": False,
        "claimBoundary": prereg["claimBoundary"],
    }
    OUT.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    with CSV.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=[key for key in phases[0] if key != "fields"])
        writer.writeheader()
        writer.writerows({key: value for key, value in item.items() if key != "fields"} for item in phases)
    render(phases, summary)
    print(json.dumps({"classification": classification, "wakeReduction": wake_reduction, "forceReduction": force_reduction, "c20Authorized": promote, "c20Executed": fine is not None}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

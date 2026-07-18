#!/usr/bin/env python3
"""Apply the preregistered formation-flight causal mechanism discriminator."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-mechanism-v1"
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap, Normalize
import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREGISTRATION = ROOT / "ValidationInputs/formation-flight-mechanism-probe-v1.json"
ARCHIVE_ROOT = ROOT / "ValidationArtifacts/formation-flight-mechanism-probe"
EARLY_ROOT = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
EARLY_SUMMARY = EARLY_ROOT / "formation-flight-early-cycle-field-summary.json"
SUMMARY = ARCHIVE_ROOT / "formation-flight-mechanism-summary.json"
CSV = ARCHIVE_ROOT / "formation-flight-mechanism-components.csv"
PNG = ROOT / "Docs/Media/formation-flight-causal-mechanism-atlas.png"
SVG = ROOT / "Docs/Media/formation-flight-causal-mechanism-atlas.svg"
COMPONENTS = (
    "reflectedPopulation",
    "interpolationAuxiliary",
    "movingWall",
    "coverImpulse",
    "uncoverImpulse",
)
COLORS = {
    "reflectedPopulation": "#43c6f5",
    "interpolationAuxiliary": "#f5c45a",
    "movingWall": "#ff7468",
    "coverImpulse": "#74e0a7",
    "uncoverImpulse": "#b58cff",
}
DISPLAY = {
    "reflectedPopulation": "reflected-population",
    "interpolationAuxiliary": "interpolation-auxiliary",
    "movingWall": "moving-wall",
    "coverImpulse": "cover-impulse",
    "uncoverImpulse": "uncover-impulse",
    "wakeTransportDominated": "WAKE-TRANSPORT DOMINATED",
    "boundaryOperatorDominated": "BOUNDARY-OPERATOR DOMINATED",
    "resolvedPopulationDominated": "REFLECTED-POPULATION DOMINATED",
    "mixed": "MIXED",
}


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


def select_mechanism_sample(report: dict, target: float, flyer: str, cycle_steps: int) -> dict:
    matches = [
        sample
        for sample in report["samples"]
        if sample["flyer"] == flyer
        and abs(sample["followerPhase"] - target) <= 0.5 / cycle_steps + 1e-12
    ]
    if len(matches) != 1:
        raise SystemExit(f"expected one {flyer} mechanism sample near follower phase {target}")
    return matches[0]


def select_field_slice(resolution: int, target: float) -> dict:
    directory = EARLY_ROOT / f"c{resolution}-best-z3-phase025"
    replay = load(directory / "formation-flight-field-replay-report.json")
    index = load(directory / "formation-flight-flow-slices/index.json")
    tolerance = 0.51 / replay["cycleSteps"]
    matches = [entry for entry in index["entries"] if abs(entry["followerPhase"] - target) <= tolerance]
    if len(matches) != 1:
        raise SystemExit(f"expected one c{resolution} field slice near {target}")
    entry = matches[0]
    data = load(directory / "formation-flight-flow-slices" / entry["file"])
    shape = (data["height"], data["width"])
    return {
        "vertical": np.asarray(data["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape),
        "owner": np.asarray(data["ownerMask"], dtype=np.uint8).reshape(shape),
        "entry": entry,
    }


def load_resolution(resolution: int, preregistration: dict) -> dict:
    directory = ARCHIVE_ROOT / f"c{resolution}-best-z3-phase025"
    replay_path = directory / "formation-flight-field-replay-report.json"
    mechanism_path = directory / "formation-flight-mechanism-probes.json"
    replay = load(replay_path)
    mechanism = load(mechanism_path)
    reference_path = ROOT / (
        f"ValidationArtifacts/formation-flight-promotion/c{resolution}-best-z3-phase025/formation-flight-report.json"
    )
    reference = load(reference_path)
    if not replay["gates"]["passed"] or not mechanism["passed"]:
        raise SystemExit(f"c{resolution} mechanism replay failed")
    if replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > preregistration["gates"]["maximumRelativeReferenceCoupledHistoryDifference"]:
        raise SystemExit(f"c{resolution} replay does not reproduce its reference")
    if mechanism["componentOrder"] != list(COMPONENTS) or len(mechanism["samples"]) != 6:
        raise SystemExit(f"c{resolution} mechanism schema is incomplete")
    closure_limit = preregistration["gates"]["maximumRelativeComponentForceClosureResidual"]
    for key in (
        "maximumRelativeForceClosureResidual",
        "maximumRelativeTorqueClosureResidual",
        "maximumRelativePowerClosureResidual",
    ):
        if mechanism[key] > closure_limit:
            raise SystemExit(f"c{resolution} mechanism closure failed: {key}")
    denominator = reference["isolatedFollower"]["meanPositivePowerWatts"]
    if not math.isfinite(denominator) or denominator <= 0:
        raise SystemExit(f"c{resolution} normalization denominator is invalid")
    return {
        "replay": replay,
        "mechanism": mechanism,
        "reference": reference,
        "denominator": denominator,
        "replayPath": replay_path,
        "mechanismPath": mechanism_path,
    }


def phase_result(cases: dict[int, dict], target: float, label: str, early: dict) -> dict:
    per_resolution = {}
    for resolution in (16, 20):
        case = cases[resolution]
        sample = select_mechanism_sample(
            case["mechanism"], target, "follower", case["replay"]["cycleSteps"]
        )
        denominator = case["denominator"]
        component_powers = {
            name: sample["components"][name]["actuatorPowerWatts"] / denominator
            for name in COMPONENTS
        }
        component_l1 = sum(abs(value) for value in component_powers.values())
        production_normalized = sample["production"]["actuatorPowerWatts"] / denominator
        per_resolution[resolution] = {
            "actualLeaderPhase": sample["leaderPhase"],
            "actualFollowerPhase": sample["followerPhase"],
            "normalizationWatts": denominator,
            "productionNormalizedPower": production_normalized,
            "reconstructedNormalizedPower": sample["reconstructed"]["actuatorPowerWatts"] / denominator,
            "componentNormalizedPower": component_powers,
            "componentPowerL1": component_l1,
            "componentCancellationConditionNumber": component_l1 / max(abs(production_normalized), 1e-12),
            "relativeForceClosureResidual": sample["relativeForceClosureResidual"],
            "relativeTorqueClosureResidual": sample["relativeTorqueClosureResidual"],
            "relativePowerClosureResidual": sample["relativePowerClosureResidual"],
        }
    differences = {
        name: per_resolution[20]["componentNormalizedPower"][name]
        - per_resolution[16]["componentNormalizedPower"][name]
        for name in COMPONENTS
    }
    l1 = sum(abs(value) for value in differences.values())
    shares = {name: abs(value) / l1 if l1 > 0 else 0.0 for name, value in differences.items()}
    dominant = max(COMPONENTS, key=shares.get)
    production_difference = (
        per_resolution[20]["productionNormalizedPower"]
        - per_resolution[16]["productionNormalizedPower"]
    )
    component_difference = sum(differences.values())
    field_result = min(early["phaseResults"], key=lambda row: abs(row["targetFollowerPhase"] - target))
    return {
        "label": label,
        "targetFollowerPhase": target,
        "resolutions": {f"c{key}": value for key, value in per_resolution.items()},
        "normalizedComponentPowerDifferenceC20MinusC16": differences,
        "normalizedProductionPowerDifferenceC20MinusC16": production_difference,
        "normalizedReconstructedPowerDifferenceC20MinusC16": component_difference,
        "differenceClosureAbsolute": abs(component_difference - production_difference),
        "componentDifferenceL1": l1,
        "componentDifferenceCancellationConditionNumber": l1 / max(abs(production_difference), 1e-12),
        "componentAttributionFraction": shares,
        "dominantComponent": dominant,
        "dominantComponentAttributionFraction": shares[dominant],
        "nearBoundaryResidualEnergyFraction": field_result["nearBoundaryResidualEnergyFraction"],
        "outsideBoundaryResidualEnergyFraction": 1 - field_result["nearBoundaryResidualEnergyFraction"],
        "verticalVelocityNormalizedRMSDifference": field_result["verticalVelocityNormalizedRMSDifference"],
        "vorticityNormalizedRMSDifference": field_result["vorticityNormalizedRMSDifference"],
    }


def render(results: list[dict], classification: str, cases: dict[int, dict]) -> None:
    figure = plt.figure(figsize=(16, 10.5), facecolor="#06131e")
    grid = figure.add_gridspec(2, 3, left=0.055, right=0.965, top=0.79, bottom=0.10, hspace=0.25, wspace=0.20)
    cmap = LinearSegmentedColormap.from_list(
        "mechanism_delta", [(0, "#0969c7"), (0.5, "#071521"), (1, "#ff493d")]
    )
    for row, result in enumerate(results):
        axis = figure.add_subplot(grid[row, 0])
        x = np.arange(len(COMPONENTS))
        width = 0.36
        for offset, resolution in ((-width / 2, 16), (width / 2, 20)):
            values = [result["resolutions"][f"c{resolution}"]["componentNormalizedPower"][name] for name in COMPONENTS]
            axis.bar(x + offset, values, width, color=[COLORS[name] for name in COMPONENTS], alpha=0.62 if resolution == 16 else 0.98, edgecolor="#dff7ff" if resolution == 20 else "none", linewidth=0.4, label=f"c{resolution}")
        axis.axhline(0, color="#789dad", linewidth=0.7)
        axis.set_xticks(x, ("reflected", "interp", "wall", "cover", "uncover"), rotation=18)
        axis.set_ylabel("component actuator power\n/ isolated positive power")
        axis.set_title(f"{chr(65 + row * 3)}  follower phase {result['targetFollowerPhase']:.3f} • normalized terms")
        axis.legend(frameon=False, ncol=2, fontsize=8)

        delta_axis = figure.add_subplot(grid[row, 1])
        deltas = [result["normalizedComponentPowerDifferenceC20MinusC16"][name] for name in COMPONENTS]
        delta_axis.bar(x, deltas, color=[COLORS[name] for name in COMPONENTS], width=0.68)
        delta_axis.axhline(0, color="#789dad", linewidth=0.7)
        delta_axis.set_xticks(x, ("reflected", "interp", "wall", "cover", "uncover"), rotation=18)
        delta_axis.set_ylabel("normalized c20 − c16 power")
        delta_axis.set_title(f"{chr(66 + row * 3)}  grid-change attribution • {100 * result['dominantComponentAttributionFraction']:.1f}% {DISPLAY[result['dominantComponent']]}")

        field_axis = figure.add_subplot(grid[row, 2])
        slice16 = select_field_slice(16, result["targetFollowerPhase"])
        slice20 = select_field_slice(20, result["targetFollowerPhase"])
        mapped16 = bilinear_to_shape(slice16["vertical"], slice20["vertical"].shape)
        owner16 = nearest_to_shape(slice16["owner"], slice20["owner"].shape)
        delta = slice20["vertical"] - mapped16
        valid = (owner16 == 0) & (slice20["owner"] == 0)
        limit = max(float(np.quantile(np.abs(delta[valid]), 0.995)), 1e-9)
        extent = (-5, 5, -6.5, 6.5)
        field_axis.imshow(np.ma.masked_where(~valid, delta), origin="lower", extent=extent, cmap=cmap, norm=Normalize(-limit, limit), interpolation="bilinear", rasterized=True)
        field_axis.contour(np.linspace(-5, 5, valid.shape[1]), np.linspace(-6.5, 6.5, valid.shape[0]), slice20["owner"] > 0, levels=(0.5,), colors=("#f3fbff",), linewidths=0.65)
        field_axis.set_xlim(-5, 5)
        field_axis.set_ylim(-5.6, 5.6)
        field_axis.set_aspect("equal")
        field_axis.set_xlabel("x / chord")
        field_axis.set_ylabel("z / chord")
        field_axis.set_title(f"{chr(67 + row * 3)}  signed-w residual • ±{limit:.3f} m/s")

    for axis in figure.axes:
        axis.set_facecolor("#0a1c29")
        axis.tick_params(colors="#86a8b9", labelsize=8)
        axis.xaxis.label.set_color("#a9c4d0")
        axis.yaxis.label.set_color("#a9c4d0")
        axis.title.set_color("#dff7ff")
        for spine in axis.spines.values():
            spine.set_color("#24495c")

    near = results[0]
    wake = results[1]
    figure.text(0.055, 0.955, "FORMATION FLIGHT CAUSAL OBSERVATORY", color="#dff7ff", fontsize=22, fontweight="bold")
    figure.text(0.055, 0.918, "exact momentum-exchange decomposition • c16/c20 reference-locked replay • boundary versus wake discriminator", color="#62c7eb", fontsize=11)
    figure.text(0.055, 0.861, "MECHANISM", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.055, 0.832, DISPLAY[classification], color="#ffb858", fontsize=11.5, fontweight="bold")
    figure.text(0.34, 0.861, "NEAR-PHASE ATTRIBUTION", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.34, 0.832, f"{100 * near['dominantComponentAttributionFraction']:.1f}% {DISPLAY[near['dominantComponent']]}", color=COLORS[near["dominantComponent"]], fontsize=12, fontweight="bold")
    figure.text(0.60, 0.861, "WAKE OUTSIDE 0.5c", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.60, 0.832, f"{100 * wake['outsideBoundaryResidualEnergyFraction']:.1f}%", color="#74e0a7", fontsize=14, fontweight="bold")
    figure.text(0.78, 0.861, "DELTA CONDITIONING", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.78, 0.832, f"{near['componentDifferenceCancellationConditionNumber']:.1f}x / {wake['componentDifferenceCancellationConditionNumber']:.1f}x", color="#b58cff", fontsize=14, fontweight="bold")
    figure.text(0.055, 0.025, "bars are exact root-torque work terms normalized by each grid's matched isolated-follower positive power • fields are actual archived GPU states • diagnostic classification only", color="#789dad", fontsize=8)
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=180, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal formation mechanism v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal formation mechanism v1", "Date": None})
    plt.close(figure)


def main() -> int:
    preregistration = load(PREREGISTRATION)
    if not preregistration["preregisteredBeforeMechanismReplayExecution"]:
        raise SystemExit("mechanism experiment was not preregistered")
    for locked in preregistration["lockedInputs"]:
        if sha256(ROOT / locked["path"]) != locked["sha256"]:
            raise SystemExit(f"locked input changed: {locked['path']}")
    cases = {resolution: load_resolution(resolution, preregistration) for resolution in (16, 20)}
    early = load(EARLY_SUMMARY)
    probes = preregistration["selectedProbes"]
    results = [
        phase_result(cases, probes["nearBoundary"]["followerPhase"], "nearBoundary", early),
        phase_result(cases, probes["wake"]["followerPhase"], "wake", early),
    ]
    near = results[0]
    wake = results[1]
    threshold = preregistration["decisionRule"]["dominantComponentThreshold"]
    dominant = near["dominantComponent"]
    dominant_share = near["dominantComponentAttributionFraction"]
    if dominant_share >= threshold and dominant in {
        "interpolationAuxiliary", "movingWall", "coverImpulse", "uncoverImpulse"
    }:
        classification = "boundaryOperatorDominated"
        next_action = preregistration["decisionRule"]["nextIfBoundaryOperatorDominated"]
    elif dominant_share >= threshold and dominant == "reflectedPopulation":
        classification = "resolvedPopulationDominated"
        next_action = preregistration["decisionRule"]["nextIfResolvedPopulationDominated"]
    elif wake["outsideBoundaryResidualEnergyFraction"] >= threshold:
        classification = "wakeTransportDominated"
        next_action = preregistration["decisionRule"]["nextIfWakeTransportDominated"]
    else:
        classification = "mixed"
        next_action = preregistration["decisionRule"]["nextIfMixed"]
    artifact = {
        "schemaVersion": 1,
        "preregistration": {"path": str(PREREGISTRATION.relative_to(ROOT)), "sha256": sha256(PREREGISTRATION)},
        "cases": {
            f"c{resolution}": {
                "replayPath": str(case["replayPath"].relative_to(ROOT)),
                "replaySHA256": sha256(case["replayPath"]),
                "mechanismPath": str(case["mechanismPath"].relative_to(ROOT)),
                "mechanismSHA256": sha256(case["mechanismPath"]),
                "runtimeSeconds": case["replay"]["runtimeSeconds"],
                "referenceHistoryRelativeDifference": case["replay"]["gates"]["maximumRelativeReferenceCoupledHistoryDifference"],
                "mechanismClosure": {
                    "force": case["mechanism"]["maximumRelativeForceClosureResidual"],
                    "torque": case["mechanism"]["maximumRelativeTorqueClosureResidual"],
                    "power": case["mechanism"]["maximumRelativePowerClosureResidual"],
                },
            }
            for resolution, case in cases.items()
        },
        "phaseResults": results,
        "classification": classification,
        "nextAction": next_action,
        "quantitativeFormationClaimAuthorized": False,
        "claimBoundary": preregistration["claimBoundary"],
    }
    SUMMARY.parent.mkdir(parents=True, exist_ok=True)
    SUMMARY.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    with CSV.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("probe", "targetFollowerPhase", "component", "c16NormalizedPower", "c20NormalizedPower", "difference", "attributionFraction"))
        for result in results:
            for component in COMPONENTS:
                writer.writerow((
                    result["label"], result["targetFollowerPhase"], component,
                    result["resolutions"]["c16"]["componentNormalizedPower"][component],
                    result["resolutions"]["c20"]["componentNormalizedPower"][component],
                    result["normalizedComponentPowerDifferenceC20MinusC16"][component],
                    result["componentAttributionFraction"][component],
                ))
    render(results, classification, cases)
    print(json.dumps({
        "classification": classification,
        "nearDominantComponent": dominant,
        "nearDominantAttributionFraction": dominant_share,
        "wakeOutsideBoundaryFraction": wake["outsideBoundaryResidualEnergyFraction"],
        "summary": str(SUMMARY.relative_to(ROOT)),
        "png": str(PNG.relative_to(ROOT)),
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

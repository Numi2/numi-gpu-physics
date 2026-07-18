#!/usr/bin/env python3
"""Apply the preregistered c16/c20 formation boundary-source discriminator."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-formation-boundary-source-v1"
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-boundary-source-census-v1.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-boundary-source-census"
SUMMARY = ARCHIVE / "formation-flight-boundary-source-summary.json"
CSV = ARCHIVE / "formation-flight-boundary-source-directions.csv"
PNG = ROOT / "Docs/Media/formation-flight-boundary-source-atlas.png"
SVG = ROOT / "Docs/Media/formation-flight-boundary-source-atlas.svg"
COMPONENTS = (
    "reflectedMomentumExchange",
    "interpolationAuxiliary",
    "movingWall",
)
COLORS = {
    "sampling": "#42c7f4",
    "amplitude": "#ffb65a",
    "reflectedMomentumExchange": "#8f7cff",
    "interpolationAuxiliary": "#55e0ad",
    "movingWall": "#ff6f78",
    "c16": "#4d9fff",
    "c20": "#ffbf5a",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def unit(vector: np.ndarray) -> np.ndarray:
    norm = float(np.linalg.norm(vector))
    return vector / norm if norm > 0 else vector


def weighted_l1(values: np.ndarray, directions: np.ndarray) -> float:
    return float(np.sum(np.abs(values) * np.linalg.norm(directions, axis=1)))


def select_sample(report: dict, flyer: str, leader_phase: float, cycle_steps: int) -> dict:
    tolerance = 0.51 / cycle_steps
    matches = [
        sample for sample in report["samples"]
        if sample["flyer"] == flyer
        and abs(sample["leaderPhase"] - leader_phase) <= tolerance
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"expected one {flyer} census sample near leader phase {leader_phase}, got {len(matches)}"
        )
    return matches[0]


def load_case(resolution: int, prereg: dict) -> dict:
    directory = ARCHIVE / f"c{resolution}-best-z3-phase025"
    replay_path = directory / "formation-flight-field-replay-report.json"
    census_path = directory / "formation-flight-boundary-source-census.json"
    reference_path = ROOT / (
        f"ValidationArtifacts/formation-flight-promotion/c{resolution}-best-z3-phase025/"
        "formation-flight-report.json"
    )
    replay, census = load(replay_path), load(census_path)
    gates = prereg["gates"]
    if not replay["gates"]["passed"] or not census["passed"]:
        raise SystemExit(f"c{resolution} boundary-source replay failed")
    if replay["capturedBoundarySourceCensusSampleCount"] != prereg["lockedConfiguration"]["expectedSamplesPerResolution"]:
        raise SystemExit(f"c{resolution} boundary-source sample count differs from preregistration")
    if len(census["samples"]) != prereg["lockedConfiguration"]["expectedSamplesPerResolution"]:
        raise SystemExit(f"c{resolution} boundary-source report is incomplete")
    if replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] > gates["maximumRelativeReferenceCoupledHistoryDifference"]:
        raise SystemExit(f"c{resolution} replay perturbed its locked history")
    if census["maximumRelativeReconstructionClosureResidual"] > gates["maximumRelativePopulationReconstructionClosureResidual"]:
        raise SystemExit(f"c{resolution} population reconstruction does not close")
    if not census["branchCountClosurePassed"] or not census["finite"]:
        raise SystemExit(f"c{resolution} census branch/finiteness gate failed")
    return {
        "replay": replay,
        "census": census,
        "replayPath": replay_path,
        "censusPath": census_path,
        "referencePath": reference_path,
    }


def direction_arrays(sample: dict, resolution: int) -> dict[str, np.ndarray | float]:
    records = sorted(sample["directions"], key=lambda item: item["directionIndex"])
    if [item["directionIndex"] for item in records] != list(range(19)):
        raise SystemExit("D3Q19 direction order is incomplete")
    directions = np.asarray([item["direction"] for item in records], dtype=float)
    counts = np.asarray([item["linkCount"] for item in records], dtype=float)
    raw = np.asarray([item["rawReflectedPopulationSum"] for item in records], dtype=float)
    reflected_in = np.asarray([item["reflectedIncomingPopulationSum"] for item in records], dtype=float)
    interpolation = np.asarray([item["interpolationAuxiliaryPopulationSum"] for item in records], dtype=float)
    wall = np.asarray([item["movingWallPopulationSum"] for item in records], dtype=float)
    incoming = np.asarray([item["reconstructedIncomingPopulationSum"] for item in records], dtype=float)
    components = {
        "reflectedMomentumExchange": raw + reflected_in,
        "interpolationAuxiliary": interpolation,
        "movingWall": wall,
    }
    total = raw + incoming
    component_total = sum(components.values())
    if not np.allclose(total, component_total, rtol=2e-6, atol=2e-6):
        raise SystemExit("momentum-exchange component reconstruction failed")
    support = counts > 0
    means = np.zeros(19)
    means[support] = total[support] / counts[support]
    component_means = {name: np.divide(value, counts, out=np.zeros(19), where=support) for name, value in components.items()}
    areal = counts / float(resolution * resolution)
    probability = counts / max(float(np.sum(counts)), 1.0)
    profile = areal * means
    axes = {
        "chord": np.asarray(sample["wingChordAxis"], dtype=float),
        "span": np.asarray(sample["wingSpanAxis"], dtype=float),
        "normal": np.asarray(sample["wingNormalAxis"], dtype=float),
    }
    branch_counts = {
        "near": int(sum(item["nearInterpolationLinkCount"] for item in records)),
        "far": int(sum(item["farInterpolationLinkCount"] for item in records)),
        "halfwayFallback": int(sum(item["halfwayFallbackLinkCount"] for item in records)),
    }
    return {
        "directions": directions,
        "counts": counts,
        "areal": areal,
        "probability": probability,
        "means": means,
        "componentMeans": component_means,
        "profile": profile,
        "components": components,
        "total": total,
        "axes": axes,
        "branchCounts": branch_counts,
        "totalLinks": float(np.sum(counts)),
        "linkDensity": float(np.sum(areal)),
    }


def classify(sampling_share: float, amplitude_share: float, component_shares: dict[str, float], threshold: float) -> str:
    if sampling_share >= threshold:
        return "directionalLinkSamplingDominated"
    if amplitude_share < threshold:
        return "mixedLinkSamplingAndPopulationAmplitude"
    dominant = max(COMPONENTS, key=component_shares.get)
    if component_shares[dominant] < threshold:
        return "mixedPerLinkPopulationAmplitude"
    return {
        "reflectedMomentumExchange": "reflectedPopulationAmplitudeDominated",
        "interpolationAuxiliary": "interpolationAuxiliaryAmplitudeDominated",
        "movingWall": "movingWallAmplitudeDominated",
    }[dominant]


def analyze_probe(cases: dict[int, dict], probe: dict, threshold: float) -> dict:
    flyer = probe["flyer"]
    leader_phase = probe["leaderPhase"]
    samples = {
        resolution: select_sample(
            cases[resolution]["census"], flyer, leader_phase,
            cases[resolution]["replay"]["cycleSteps"],
        )
        for resolution in (16, 20)
    }
    arrays = {resolution: direction_arrays(samples[resolution], resolution) for resolution in (16, 20)}
    if not np.array_equal(arrays[16]["directions"], arrays[20]["directions"]):
        raise SystemExit("D3Q19 directions differ between grids")
    directions = arrays[16]["directions"]
    a16, a20 = arrays[16]["areal"], arrays[20]["areal"]
    m16, m20 = arrays[16]["means"], arrays[20]["means"]
    profile16, profile20 = arrays[16]["profile"], arrays[20]["profile"]
    sampling = 0.5 * (a20 - a16) * (m20 + m16)
    amplitude = 0.5 * (m20 - m16) * (a20 + a16)
    delta = profile20 - profile16
    identity_residual = delta - sampling - amplitude
    component_amplitude = {
        name: 0.5
        * (arrays[20]["componentMeans"][name] - arrays[16]["componentMeans"][name])
        * (a20 + a16)
        for name in COMPONENTS
    }
    amplitude_component_residual = amplitude - sum(component_amplitude.values())
    sampling_l1 = weighted_l1(sampling, directions)
    amplitude_l1 = weighted_l1(amplitude, directions)
    top_l1 = sampling_l1 + amplitude_l1
    sampling_share = sampling_l1 / top_l1 if top_l1 > 0 else 0.0
    amplitude_share = amplitude_l1 / top_l1 if top_l1 > 0 else 0.0
    component_l1 = {name: weighted_l1(value, directions) for name, value in component_amplitude.items()}
    component_denominator = sum(component_l1.values())
    component_shares = {
        name: value / component_denominator if component_denominator > 0 else 0.0
        for name, value in component_l1.items()
    }
    classification = classify(sampling_share, amplitude_share, component_shares, threshold)

    vectors = {
        "c16": np.sum(profile16[:, None] * directions, axis=0),
        "c20": np.sum(profile20[:, None] * directions, axis=0),
        "delta": np.sum(delta[:, None] * directions, axis=0),
        "linkSampling": np.sum(sampling[:, None] * directions, axis=0),
        "conditionalAmplitude": np.sum(amplitude[:, None] * directions, axis=0),
    }
    average_axes = {
        name: unit(arrays[16]["axes"][name] + arrays[20]["axes"][name])
        for name in ("chord", "span", "normal")
    }
    wing_frame = {
        vector_name: {
            axis_name: float(np.dot(vector, axis))
            for axis_name, axis in average_axes.items()
        }
        for vector_name, vector in vectors.items()
    }
    direction_rows = []
    for q in range(19):
        direction_rows.append({
            "directionIndex": q,
            "direction": directions[q].astype(int).tolist(),
            "c16LinkCount": int(arrays[16]["counts"][q]),
            "c20LinkCount": int(arrays[20]["counts"][q]),
            "c16ArealLinkMeasure": float(a16[q]),
            "c20ArealLinkMeasure": float(a20[q]),
            "c16ConditionalMean": float(m16[q]),
            "c20ConditionalMean": float(m20[q]),
            "c16MomentumExchangeProfile": float(profile16[q]),
            "c20MomentumExchangeProfile": float(profile20[q]),
            "profileDifferenceC20MinusC16": float(delta[q]),
            "linkSamplingTerm": float(sampling[q]),
            "conditionalAmplitudeTerm": float(amplitude[q]),
            "reflectedAmplitudeTerm": float(component_amplitude["reflectedMomentumExchange"][q]),
            "interpolationAmplitudeTerm": float(component_amplitude["interpolationAuxiliary"][q]),
            "movingWallAmplitudeTerm": float(component_amplitude["movingWall"][q]),
            "identityResidual": float(identity_residual[q]),
            "amplitudeComponentResidual": float(amplitude_component_residual[q]),
        })
    return {
        "flyer": flyer,
        "targetLeaderPhase": leader_phase,
        "targetFollowerPhase": probe["followerPhase"],
        "actualPhases": {
            f"c{resolution}": {
                "leader": samples[resolution]["leaderPhase"],
                "follower": samples[resolution]["followerPhase"],
            }
            for resolution in (16, 20)
        },
        "totalBoundaryLinks": {f"c{r}": int(arrays[r]["totalLinks"]) for r in (16, 20)},
        "boundaryLinkDensityPerChordSquared": {f"c{r}": arrays[r]["linkDensity"] for r in (16, 20)},
        "directionDistributionTotalVariation": float(0.5 * np.sum(np.abs(arrays[20]["probability"] - arrays[16]["probability"]))),
        "branchCounts": {f"c{r}": arrays[r]["branchCounts"] for r in (16, 20)},
        "topLevelWeightedL1": {"linkSampling": sampling_l1, "conditionalAmplitude": amplitude_l1},
        "topLevelAttributionFraction": {"linkSampling": sampling_share, "conditionalAmplitude": amplitude_share},
        "conditionalAmplitudeComponentWeightedL1": component_l1,
        "conditionalAmplitudeComponentAttributionFraction": component_shares,
        "maximumAbsoluteSymmetricIdentityResidual": float(np.max(np.abs(identity_residual))),
        "maximumAbsoluteAmplitudeComponentResidual": float(np.max(np.abs(amplitude_component_residual))),
        "populationMomentumVector": {name: value.tolist() for name, value in vectors.items()},
        "wingFramePopulationMomentum": wing_frame,
        "classification": classification,
        "directions": direction_rows,
    }


def render(results: list[dict], primary: dict) -> None:
    plt.rcParams.update({"font.family": "DejaVu Sans", "axes.titleweight": "bold"})
    figure = plt.figure(figsize=(16, 9), facecolor="#04111b")
    grid = figure.add_gridspec(2, 3, left=0.055, right=0.97, top=0.78, bottom=0.10, hspace=0.34, wspace=0.27)
    q = np.arange(1, 19)
    rows = primary["directions"][1:]

    axis = figure.add_subplot(grid[0, 0:2])
    c16 = np.asarray([row["c16MomentumExchangeProfile"] for row in rows])
    c20 = np.asarray([row["c20MomentumExchangeProfile"] for row in rows])
    axis.plot(q, c16, "o-", color=COLORS["c16"], linewidth=1.8, markersize=4, label="c16")
    axis.plot(q, c20, "o-", color=COLORS["c20"], linewidth=1.8, markersize=4, label="c20")
    axis.fill_between(q, c16, c20, color="#9b87ff", alpha=0.12)
    axis.axhline(0, color="#7895a5", linewidth=0.7)
    axis.set_xticks(q)
    axis.set_xlabel("D3Q19 direction index")
    axis.set_ylabel("areal momentum-exchange population")
    axis.set_title("A  PRIMARY SOURCE SPECTRUM • LEADER / FOLLOWER PHASE 0.035")
    axis.legend(frameon=False, ncol=2)

    axis = figure.add_subplot(grid[0, 2])
    sampling = np.asarray([row["linkSamplingTerm"] for row in rows])
    amplitude = np.asarray([row["conditionalAmplitudeTerm"] for row in rows])
    axis.bar(q - 0.18, sampling, 0.36, color=COLORS["sampling"], label="link sampling")
    axis.bar(q + 0.18, amplitude, 0.36, color=COLORS["amplitude"], label="conditional amplitude")
    axis.axhline(0, color="#7895a5", linewidth=0.7)
    axis.set_xticks(q[::2])
    axis.set_xlabel("direction index")
    axis.set_ylabel("exact c20 − c16 term")
    axis.set_title("B  EXACT PRODUCT DECOMPOSITION")
    axis.legend(frameon=False, fontsize=8)

    axis = figure.add_subplot(grid[1, 0])
    labels = ["link sampling", "conditional amplitude", "reflected", "interpolation", "moving wall"]
    values = [
        primary["topLevelAttributionFraction"]["linkSampling"],
        primary["topLevelAttributionFraction"]["conditionalAmplitude"],
        primary["conditionalAmplitudeComponentAttributionFraction"]["reflectedMomentumExchange"],
        primary["conditionalAmplitudeComponentAttributionFraction"]["interpolationAuxiliary"],
        primary["conditionalAmplitudeComponentAttributionFraction"]["movingWall"],
    ]
    colors = [COLORS["sampling"], COLORS["amplitude"], COLORS["reflectedMomentumExchange"], COLORS["interpolationAuxiliary"], COLORS["movingWall"]]
    axis.barh(np.arange(5), values, color=colors)
    axis.set_yticks(np.arange(5), labels)
    axis.invert_yaxis()
    axis.set_xlim(0, 1)
    axis.set_xlabel("weighted-L1 attribution")
    axis.axvline(0.6, color="#eaf8ff", linewidth=0.8, linestyle="--")
    axis.set_title("C  FROZEN 60% DOMINANCE TEST")
    for index, value in enumerate(values):
        axis.text(min(value + 0.025, 0.92), index, f"{100 * value:.1f}%", va="center", color="#e7f8ff", fontsize=8)

    axis = figure.add_subplot(grid[1, 1])
    frame_labels = ("chord", "span", "normal")
    x = np.arange(3)
    for offset, name, color in ((-0.24, "c16", COLORS["c16"]), (0, "c20", COLORS["c20"]), (0.24, "delta", "#ef70ff")):
        values = [primary["wingFramePopulationMomentum"][name][label] for label in frame_labels]
        axis.bar(x + offset, values, 0.23, color=color, label=name)
    axis.axhline(0, color="#7895a5", linewidth=0.7)
    axis.set_xticks(x, frame_labels)
    axis.set_ylabel("wing-frame population momentum")
    axis.set_title("D  WING-FRAME SOURCE VECTOR")
    axis.legend(frameon=False, fontsize=8, ncol=3)

    axis = figure.add_subplot(grid[1, 2])
    y = np.arange(len(results))
    sampling_shares = [item["topLevelAttributionFraction"]["linkSampling"] for item in results]
    amplitude_shares = [item["topLevelAttributionFraction"]["conditionalAmplitude"] for item in results]
    labels = [f"{item['flyer'][0].upper()} • φf={item['targetFollowerPhase']:.3f}" for item in results]
    axis.barh(y, sampling_shares, color=COLORS["sampling"], label="sampling")
    axis.barh(y, amplitude_shares, left=sampling_shares, color=COLORS["amplitude"], label="amplitude")
    axis.axvline(0.6, color="#eaf8ff", linewidth=0.8, linestyle="--")
    axis.set_yticks(y, labels)
    axis.invert_yaxis()
    axis.set_xlim(0, 1)
    axis.set_xlabel("top-level attribution")
    axis.set_title("E  BOTH PHASES • BOTH OWNERS")
    axis.legend(frameon=False, fontsize=8, ncol=2)

    for axis in figure.axes:
        axis.set_facecolor("#091d2a")
        axis.tick_params(colors="#91adbb", labelsize=8)
        axis.xaxis.label.set_color("#b5cbd5")
        axis.yaxis.label.set_color("#b5cbd5")
        axis.title.set_color("#e7f8ff")
        for spine in axis.spines.values():
            spine.set_color("#24485a")
        legend = axis.get_legend()
        if legend:
            for text in legend.get_texts():
                text.set_color("#cde6ef")

    top = primary["topLevelAttributionFraction"]
    figure.text(0.055, 0.952, "FORMATION FLIGHT • BOUNDARY SOURCE OBSERVATORY", color="#e7f8ff", fontsize=22, fontweight="bold")
    figure.text(0.055, 0.913, "owner × phase × D3Q19 census • exact link-sampling versus conditional-population identity • production TRT", color="#63cdf2", fontsize=11)
    figure.text(0.055, 0.855, "PRIMARY CLASSIFICATION", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.055, 0.820, primary["classification"].replace("Dominated", " DOMINATED").upper(), color="#ffbd62", fontsize=13, fontweight="bold")
    figure.text(0.45, 0.855, "LINK SAMPLING", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.45, 0.820, f"{100 * top['linkSampling']:.1f}%", color=COLORS["sampling"], fontsize=16, fontweight="bold")
    figure.text(0.60, 0.855, "CONDITIONAL AMPLITUDE", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.60, 0.820, f"{100 * top['conditionalAmplitude']:.1f}%", color=COLORS["amplitude"], fontsize=16, fontweight="bold")
    figure.text(0.82, 0.855, "IDENTITY RESIDUAL", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.82, 0.820, f"{primary['maximumAbsoluteSymmetricIdentityResidual']:.1e}", color="#71e2af", fontsize=14, fontweight="bold")
    figure.text(0.055, 0.025, "population source is normalized by chord-cells²; attribution uses |cᵢ|-weighted L1 • read-only diagnostic • no quantitative formation-benefit claim", color="#7899a9", fontsize=8)
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=190, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal boundary source census v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal boundary source census v1", "Date": None})
    plt.close(figure)


def main() -> int:
    prereg = load(PREREG)
    if not prereg["preregisteredBeforeBoundarySourceReplayExecution"]:
        raise SystemExit("boundary-source experiment was not preregistered")
    for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
        for item in prereg[group]:
            if digest(ROOT / item["path"]) != item["sha256"]:
                raise SystemExit(f"locked artifact changed: {item['path']}")
    for item in prereg["qualificationAmendment"]["failedSmokeArtifacts"]:
        if digest(ROOT / item["path"]) != item["sha256"]:
            raise SystemExit(f"qualification evidence changed: {item['path']}")
    cases = {resolution: load_case(resolution, prereg) for resolution in (16, 20)}
    probes = [prereg["selectedProbes"]["primary"], *prereg["selectedProbes"]["secondary"]]
    threshold = prereg["decisionRule"]["dominanceThreshold"]
    results = [analyze_probe(cases, probe, threshold) for probe in probes]
    primary = results[0]
    classification = primary["classification"]
    rule = prereg["decisionRule"]
    next_key = {
        "directionalLinkSamplingDominated": "nextIfDirectionalLinkSamplingDominated",
        "reflectedPopulationAmplitudeDominated": "nextIfReflectedPopulationDominated",
        "interpolationAuxiliaryAmplitudeDominated": "nextIfInterpolationAuxiliaryDominated",
        "movingWallAmplitudeDominated": "nextIfMovingWallAmplitudeDominated",
        "mixedPerLinkPopulationAmplitude": "nextIfMixedPerLinkPopulationAmplitude",
        "mixedLinkSamplingAndPopulationAmplitude": "nextIfMixedLinkSamplingAndPopulationAmplitude",
    }[classification]

    ARCHIVE.mkdir(parents=True, exist_ok=True)
    with CSV.open("w", newline="") as handle:
        fieldnames = ["flyer", "targetLeaderPhase", "targetFollowerPhase", *results[0]["directions"][0].keys()]
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        for result in results:
            for row in result["directions"]:
                writer.writerow({
                    "flyer": result["flyer"],
                    "targetLeaderPhase": result["targetLeaderPhase"],
                    "targetFollowerPhase": result["targetFollowerPhase"],
                    **row,
                })
    render(results, primary)
    summary = {
        "schemaVersion": 1,
        "title": "Formation Flight boundary population source discriminator",
        "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
        "qualificationAmendment": prereg["qualificationAmendment"],
        "inputs": {
            f"c{resolution}": {
                "replayPath": str(cases[resolution]["replayPath"].relative_to(ROOT)),
                "replaySHA256": digest(cases[resolution]["replayPath"]),
                "censusPath": str(cases[resolution]["censusPath"].relative_to(ROOT)),
                "censusSHA256": digest(cases[resolution]["censusPath"]),
                "referencePath": str(cases[resolution]["referencePath"].relative_to(ROOT)),
                "referenceSHA256": digest(cases[resolution]["referencePath"]),
            }
            for resolution in (16, 20)
        },
        "probeResults": results,
        "primaryClassification": classification,
        "nextAction": rule[next_key],
        "csvPath": str(CSV.relative_to(ROOT)),
        "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
        "newFluidSimulationRequired": True,
        "productionSolverChanged": False,
        "quantitativeFormationClaimAuthorized": False,
        "scientificVerdict": f"the preregistered primary near-wing source is classified as {classification}; this selects the next numerical discriminator without validating formation benefit",
        "passed": True,
    }
    SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"formation boundary-source classification: {classification}")
    print(f"link-sampling share: {primary['topLevelAttributionFraction']['linkSampling']:.6f}")
    print(f"conditional-amplitude share: {primary['topLevelAttributionFraction']['conditionalAmplitude']:.6f}")
    print(f"wrote {SUMMARY.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

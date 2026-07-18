#!/usr/bin/env python3
"""Split the audited formation link-sampling term into density and direction."""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
matplotlib.rcParams["svg.hashsalt"] = "birdflow-link-sampling-subdecomposition-v1"
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-link-sampling-subdecomposition-v1.json"
PARENT = ROOT / "ValidationArtifacts/formation-flight-boundary-source-census/formation-flight-boundary-source-summary.json"
PARENT_AUDIT = ROOT / "ValidationArtifacts/formation-flight-boundary-source-census/formation-flight-boundary-source-audit.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-link-sampling-subdecomposition"
SUMMARY = ARCHIVE / "formation-flight-link-sampling-subdecomposition-summary.json"
CSV = ARCHIVE / "formation-flight-link-sampling-subdecomposition-directions.csv"
PNG = ROOT / "Docs/Media/formation-flight-link-sampling-subdecomposition.png"
SVG = ROOT / "Docs/Media/formation-flight-link-sampling-subdecomposition.svg"
COLORS = {"density": "#48c8f2", "direction": "#ffb95b", "c16": "#579fff", "c20": "#ffcb69"}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def weighted_l1(values: np.ndarray, directions: np.ndarray) -> float:
    return float(np.sum(np.abs(values) * np.linalg.norm(directions, axis=1)))


def human_classification(value: str) -> str:
    return {
        "arealLinkDensityDominated": "AREAL LINK DENSITY DOMINATED",
        "directionRedistributionDominated": "DIRECTION REDISTRIBUTION DOMINATED",
        "mixedDensityAndDirection": "MIXED DENSITY + DIRECTION",
    }[value]


def classify(density_share: float, direction_share: float, threshold: float) -> str:
    if density_share >= threshold:
        return "arealLinkDensityDominated"
    if direction_share >= threshold:
        return "directionRedistributionDominated"
    return "mixedDensityAndDirection"


def analyze(parent: dict, threshold: float) -> list[dict]:
    output = []
    for probe in parent["probeResults"]:
        rows = probe["directions"]
        directions = np.asarray([row["direction"] for row in rows], dtype=float)
        a16 = np.asarray([row["c16ArealLinkMeasure"] for row in rows])
        a20 = np.asarray([row["c20ArealLinkMeasure"] for row in rows])
        m16 = np.asarray([row["c16ConditionalMean"] for row in rows])
        m20 = np.asarray([row["c20ConditionalMean"] for row in rows])
        parent_term = np.asarray([row["linkSamplingTerm"] for row in rows])
        density16 = probe["boundaryLinkDensityPerChordSquared"]["c16"]
        density20 = probe["boundaryLinkDensityPerChordSquared"]["c20"]
        p16 = a16 / density16
        p20 = a20 / density20
        mean_sum = m20 + m16
        density_term = 0.25 * (density20 - density16) * (p20 + p16) * mean_sum
        direction_term = 0.25 * (p20 - p16) * (density20 + density16) * mean_sum
        residual = parent_term - density_term - direction_term
        density_l1 = weighted_l1(density_term, directions)
        direction_l1 = weighted_l1(direction_term, directions)
        denominator = density_l1 + direction_l1
        density_share = density_l1 / denominator if denominator > 0 else 0.0
        direction_share = direction_l1 / denominator if denominator > 0 else 0.0
        classification = classify(density_share, direction_share, threshold)
        direction_rows = []
        for q in range(19):
            direction_rows.append({
                "directionIndex": q,
                "direction": directions[q].astype(int).tolist(),
                "c16DirectionProbability": float(p16[q]),
                "c20DirectionProbability": float(p20[q]),
                "parentLinkSamplingTerm": float(parent_term[q]),
                "arealLinkDensityTerm": float(density_term[q]),
                "directionRedistributionTerm": float(direction_term[q]),
                "identityResidual": float(residual[q]),
            })
        output.append({
            "flyer": probe["flyer"],
            "targetLeaderPhase": probe["targetLeaderPhase"],
            "targetFollowerPhase": probe["targetFollowerPhase"],
            "arealLinkDensityPerChordSquared": {"c16": density16, "c20": density20},
            "relativeArealLinkDensityChangeC20FromC16": density20 / density16 - 1,
            "directionDistributionTotalVariation": probe["directionDistributionTotalVariation"],
            "weightedL1": {"arealLinkDensity": density_l1, "directionRedistribution": direction_l1},
            "attributionFraction": {"arealLinkDensity": density_share, "directionRedistribution": direction_share},
            "maximumAbsoluteIdentityResidual": float(np.max(np.abs(residual))),
            "classification": classification,
            "directions": direction_rows,
        })
    return output


def render(results: list[dict], primary: dict) -> None:
    figure = plt.figure(figsize=(15.5, 8.5), facecolor="#04111b")
    grid = figure.add_gridspec(2, 3, left=0.06, right=0.97, top=0.76, bottom=0.11, hspace=0.34, wspace=0.28)
    q = np.arange(1, 19)
    rows = primary["directions"][1:]

    axis = figure.add_subplot(grid[0, 0:2])
    density = np.asarray([row["arealLinkDensityTerm"] for row in rows])
    direction = np.asarray([row["directionRedistributionTerm"] for row in rows])
    parent = np.asarray([row["parentLinkSamplingTerm"] for row in rows])
    axis.bar(q - 0.2, density, 0.4, color=COLORS["density"], label="areal link density")
    axis.bar(q + 0.2, direction, 0.4, color=COLORS["direction"], label="direction redistribution")
    axis.plot(q, parent, color="#e9f8ff", marker="o", markersize=3.5, linewidth=1.0, label="parent sampling term")
    axis.axhline(0, color="#7895a5", linewidth=0.7)
    axis.set_xticks(q)
    axis.set_xlabel("D3Q19 direction index")
    axis.set_ylabel("exact c20 − c16 sampling term")
    axis.set_title("A  EXACT SECOND-LEVEL PRODUCT IDENTITY")
    axis.legend(frameon=False, ncol=3, fontsize=8)

    axis = figure.add_subplot(grid[0, 2])
    labels = ["areal link density", "direction redistribution"]
    values = [primary["attributionFraction"]["arealLinkDensity"], primary["attributionFraction"]["directionRedistribution"]]
    axis.barh([0, 1], values, color=[COLORS["density"], COLORS["direction"]])
    axis.set_yticks([0, 1], labels)
    axis.invert_yaxis()
    axis.set_xlim(0, 1)
    axis.axvline(0.6, color="#e9f8ff", linestyle="--", linewidth=0.8)
    axis.set_xlabel("|cᵢ|-weighted L1 attribution")
    axis.set_title("B  FROZEN 60% PRIMARY DECISION")
    for index, value in enumerate(values):
        axis.text(min(value + 0.025, 0.9), index, f"{100 * value:.1f}%", va="center", color="#e9f8ff", fontsize=9)

    axis = figure.add_subplot(grid[1, 0])
    x = np.arange(len(results))
    width = 0.34
    c16 = [row["arealLinkDensityPerChordSquared"]["c16"] for row in results]
    c20 = [row["arealLinkDensityPerChordSquared"]["c20"] for row in results]
    labels = [f"{row['flyer'][0].upper()} • φf={row['targetFollowerPhase']:.3f}" for row in results]
    axis.bar(x - width / 2, c16, width, color=COLORS["c16"], label="c16")
    axis.bar(x + width / 2, c20, width, color=COLORS["c20"], label="c20")
    axis.set_xticks(x, labels, rotation=18)
    axis.set_ylabel("links / chord-cells²")
    axis.set_title("C  GRID-NORMALIZED LINK DENSITY")
    axis.legend(frameon=False, fontsize=8, ncol=2)

    axis = figure.add_subplot(grid[1, 1:3])
    y = np.arange(len(results))
    density_share = [row["attributionFraction"]["arealLinkDensity"] for row in results]
    direction_share = [row["attributionFraction"]["directionRedistribution"] for row in results]
    axis.barh(y, density_share, color=COLORS["density"], label="areal density")
    axis.barh(y, direction_share, left=density_share, color=COLORS["direction"], label="direction redistribution")
    axis.set_yticks(y, labels)
    axis.invert_yaxis()
    axis.set_xlim(0, 1)
    axis.axvline(0.6, color="#e9f8ff", linestyle="--", linewidth=0.8)
    axis.set_xlabel("sampling-subterm attribution")
    axis.set_title("D  BOTH PHASES • BOTH OWNERS")
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

    figure.text(0.06, 0.95, "FORMATION FLIGHT • LINK-SAMPLING MICROSCOPE", color="#e7f8ff", fontsize=22, fontweight="bold")
    figure.text(0.06, 0.91, "archive-only exact identity • areal boundary-link density versus D3Q19 direction redistribution", color="#63cdf2", fontsize=11)
    figure.text(0.06, 0.837, "PRIMARY CLASSIFICATION", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.06, 0.798, human_classification(primary["classification"]), color="#ffbd62", fontsize=14, fontweight="bold")
    figure.text(0.55, 0.837, "DENSITY SHARE", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.55, 0.798, f"{100 * primary['attributionFraction']['arealLinkDensity']:.1f}%", color=COLORS["density"], fontsize=16, fontweight="bold")
    figure.text(0.70, 0.837, "DIRECTION SHARE", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.70, 0.798, f"{100 * primary['attributionFraction']['directionRedistribution']:.1f}%", color=COLORS["direction"], fontsize=16, fontweight="bold")
    figure.text(0.86, 0.837, "IDENTITY", color="#718f9f", fontsize=8, fontweight="bold")
    figure.text(0.86, 0.798, f"{primary['maximumAbsoluteIdentityResidual']:.1e}", color="#72e2ae", fontsize=14, fontweight="bold")
    figure.text(0.06, 0.028, "uses the audited 98.25% parent link-sampling term • no new CFD • diagnostic selector only • quantitative formation benefit remains unauthorized", color="#7899a9", fontsize=8)
    PNG.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(PNG, dpi=190, facecolor=figure.get_facecolor(), metadata={"Software": "BirdFlowMetal link-sampling microscope v1"})
    figure.savefig(SVG, facecolor=figure.get_facecolor(), metadata={"Creator": "BirdFlowMetal link-sampling microscope v1", "Date": None})
    plt.close(figure)


def main() -> int:
    prereg = load(PREREG)
    if not prereg["preregisteredBeforeSubdecompositionExecution"]:
        raise SystemExit("link-sampling subdecomposition was not preregistered")
    for group in ("lockedInputs", "lockedAnalysis"):
        for item in prereg[group]:
            if digest(ROOT / item["path"]) != item["sha256"]:
                raise SystemExit(f"locked file changed: {item['path']}")
    parent, audit = load(PARENT), load(PARENT_AUDIT)
    if not audit["passed"] or parent["primaryClassification"] != prereg["gates"]["requireParentPrimaryClassification"]:
        raise SystemExit("parent source classification or audit is not qualified")
    results = analyze(parent, prereg["decisionRule"]["dominanceThreshold"])
    maximum_residual = max(row["maximumAbsoluteIdentityResidual"] for row in results)
    if maximum_residual > prereg["gates"]["maximumAbsoluteDirectionIdentityResidual"]:
        raise SystemExit("density/direction identity failed")
    primary = results[0]
    classification = primary["classification"]
    next_key = {
        "arealLinkDensityDominated": "nextIfArealLinkDensityDominated",
        "directionRedistributionDominated": "nextIfDirectionRedistributionDominated",
        "mixedDensityAndDirection": "nextIfMixedDensityAndDirection",
    }[classification]
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    with CSV.open("w", newline="") as handle:
        fields = ["flyer", "targetLeaderPhase", "targetFollowerPhase", *results[0]["directions"][0].keys()]
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for result in results:
            for row in result["directions"]:
                writer.writerow({"flyer": result["flyer"], "targetLeaderPhase": result["targetLeaderPhase"], "targetFollowerPhase": result["targetFollowerPhase"], **row})
    render(results, primary)
    output = {
        "schemaVersion": 1,
        "title": "Formation Flight link-sampling density/direction subdecomposition",
        "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
        "parentSummary": {"path": str(PARENT.relative_to(ROOT)), "sha256": digest(PARENT)},
        "parentAudit": {"path": str(PARENT_AUDIT.relative_to(ROOT)), "sha256": digest(PARENT_AUDIT)},
        "probeResults": results,
        "primaryClassification": classification,
        "maximumAbsoluteIdentityResidual": maximum_residual,
        "nextAction": prereg["decisionRule"][next_key],
        "csvPath": str(CSV.relative_to(ROOT)),
        "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
        "newFluidSimulationRequired": False,
        "productionSolverChanged": False,
        "quantitativeFormationClaimAuthorized": False,
        "scientificVerdict": f"the dominant parent link-sampling discrepancy is {classification}; this selects a geometry-only follow-up without changing production physics",
        "passed": True,
    }
    SUMMARY.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(f"formation link-sampling subdecomposition: {classification}")
    print(f"density share: {primary['attributionFraction']['arealLinkDensity']:.6f}")
    print(f"direction share: {primary['attributionFraction']['directionRedistribution']:.6f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

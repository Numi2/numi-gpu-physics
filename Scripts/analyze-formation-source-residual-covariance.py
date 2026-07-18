#!/usr/bin/env python3
"""Select one focused c18 source trace from archived three-offset residuals."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-source-residual-covariance-v1.json"
PARENT_SUMMARY = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset3/formation-flight-subcell-source-three-offset-summary.json"
PARENT_AUDIT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-offset3/formation-flight-subcell-source-three-offset-audit.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-source-residual-covariance"
SUMMARY = ARCHIVE / "formation-flight-source-residual-covariance-summary.json"
CSV = ARCHIVE / "formation-flight-source-residual-covariance.csv"
PNG = ROOT / "Docs/Media/formation-flight-source-residual-covariance.png"
SVG = ROOT / "Docs/Media/formation-flight-source-residual-covariance.svg"
RESOLUTIONS = (16, 18, 20)
PHASES = (
    ("offset1", [0.25, 0.25, 0.75]),
    ("offset2", [0.5, 0.75, 0.5]),
    ("offset3", [0.25, 0.0, 0.5]),
)
COMPONENTS = (
    "reflectedMomentumExchange",
    "interpolationAuxiliary",
    "movingWall",
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def census_path(parent: dict, phase: str, resolution: int) -> Path:
    return ROOT / parent["phaseInputs"][phase][f"c{resolution}"]["censusPath"]


def read_profiles(path: Path) -> tuple[np.ndarray, dict[str, np.ndarray], np.ndarray, list[dict]]:
    census = load(path)
    sample = next(item for item in census["samples"] if item["flyer"] == "leader")
    records = sorted(sample["directions"], key=lambda row: row["directionIndex"])
    directions = np.asarray([row["direction"] for row in records], dtype=float)
    raw_reflected = np.asarray([row["rawReflectedPopulationSum"] for row in records])
    incoming = np.asarray([row["reconstructedIncomingPopulationSum"] for row in records])
    reflected_in = np.asarray([row["reflectedIncomingPopulationSum"] for row in records])
    interpolation = np.asarray([row["interpolationAuxiliaryPopulationSum"] for row in records])
    wall = np.asarray([row["movingWallPopulationSum"] for row in records])
    source = raw_reflected + incoming
    components = {
        "reflectedMomentumExchange": raw_reflected + reflected_in,
        "interpolationAuxiliary": interpolation,
        "movingWall": wall,
    }
    return source, components, directions, records


prereg = load(PREREG)
parent, parent_audit = load(PARENT_SUMMARY), load(PARENT_AUDIT)
floor = float(prereg["selectionRule"]["denominatorFloor"])
t = ((1 / 18) - (1 / 16)) / ((1 / 20) - (1 / 16))
inputs: dict[str, dict] = {}
profiles: dict[str, dict] = {}
for phase, offset in PHASES:
    profiles[phase] = {}
    inputs[phase] = {}
    for resolution in RESOLUTIONS:
        path = census_path(parent, phase, resolution)
        source, components, directions, records = read_profiles(path)
        scale = resolution**2
        profiles[phase][resolution] = {
            "source": source / scale,
            "components": {name: value / scale for name, value in components.items()},
            "directions": directions,
            "records": records,
        }
        inputs[phase][f"c{resolution}"] = {
            "path": str(path.relative_to(ROOT)),
            "sha256": digest(path),
            "offsetCells": offset,
        }

weights = np.linalg.norm(profiles["offset1"][16]["directions"], axis=1)
source_residuals: dict[str, np.ndarray] = {}
component_residuals: dict[str, dict[str, np.ndarray]] = {}
closure_maximum = 0.0
for phase, _ in PHASES:
    source_residuals[phase] = (
        profiles[phase][18]["source"]
        - profiles[phase][16]["source"]
        - t * (profiles[phase][20]["source"] - profiles[phase][16]["source"])
    )
    component_residuals[phase] = {}
    for component in COMPONENTS:
        component_residuals[phase][component] = (
            profiles[phase][18]["components"][component]
            - profiles[phase][16]["components"][component]
            - t * (
                profiles[phase][20]["components"][component]
                - profiles[phase][16]["components"][component]
            )
        )
    reconstructed = sum(component_residuals[phase].values())
    closure_maximum = max(
        closure_maximum,
        float(np.max(np.abs(source_residuals[phase] - reconstructed))),
    )

source_matrix = np.stack([source_residuals[phase] for phase, _ in PHASES])
mean_source = np.mean(source_matrix, axis=0)
rows = []
candidate_rows = []
for component_index, component in enumerate(COMPONENTS):
    component_matrix = np.stack([
        component_residuals[phase][component] for phase, _ in PHASES
    ])
    mean_component = np.mean(component_matrix, axis=0)
    for direction_index in range(19):
        systematic_alignment = float(
            weights[direction_index]
            * mean_component[direction_index]
            * mean_source[direction_index]
        )
        positive_alignment = max(systematic_alignment, 0.0)
        centered_covariance = float(
            weights[direction_index]
            * np.mean(
                (component_matrix[:, direction_index] - mean_component[direction_index])
                * (source_matrix[:, direction_index] - mean_source[direction_index])
            )
        )
        products = component_matrix[:, direction_index] * source_matrix[:, direction_index]
        sign_agreement_count = int(np.count_nonzero(products > 0.0))
        row = {
            "component": component,
            "componentOrder": component_index,
            "directionIndex": direction_index,
            "direction": profiles["offset1"][16]["directions"][direction_index].astype(int).tolist(),
            "directionWeight": float(weights[direction_index]),
            "meanSourceResidual": float(mean_source[direction_index]),
            "meanComponentResidual": float(mean_component[direction_index]),
            "systematicAlignment": systematic_alignment,
            "positiveSystematicAlignment": positive_alignment,
            "centeredPhaseCovariance": centered_covariance,
            "signAgreementCount": sign_agreement_count,
            "signAgreementFraction": sign_agreement_count / 3,
            "sourceResidualByOffset": {
                phase: float(source_residuals[phase][direction_index])
                for phase, _ in PHASES
            },
            "componentResidualByOffset": {
                phase: float(component_residuals[phase][component][direction_index])
                for phase, _ in PHASES
            },
        }
        candidate_rows.append(row)

positive_total = sum(row["positiveSystematicAlignment"] for row in candidate_rows)
for row in candidate_rows:
    row["positiveAlignmentShare"] = (
        row["positiveSystematicAlignment"] / max(positive_total, floor)
    )
candidate_rows.sort(
    key=lambda row: (
        -row["positiveSystematicAlignment"],
        -row["signAgreementCount"],
        row["componentOrder"],
        row["directionIndex"],
    )
)
selected = candidate_rows[0]
selected_component = selected["component"]
selected_direction = selected["directionIndex"]
phase_alignment = []
for phase_index, (phase, offset) in enumerate(PHASES):
    alignment = float(
        weights[selected_direction]
        * component_residuals[phase][selected_component][selected_direction]
        * source_residuals[phase][selected_direction]
    )
    phase_alignment.append({
        "phase": phase,
        "phaseOrder": phase_index,
        "offsetCells": offset,
        "localAlignment": alignment,
    })
phase_alignment.sort(key=lambda row: (-row["localAlignment"], row["phaseOrder"]))
trace_phase = phase_alignment[0]

dominance_limit = float(prereg["selectionRule"]["minimumPositiveAlignmentShare"])
agreement_limit = int(prereg["selectionRule"]["minimumSignAgreementCount"])
dominance_passed = selected["positiveAlignmentShare"] >= dominance_limit
agreement_passed = selected["signAgreementCount"] >= agreement_limit
direction_passed = selected_direction != 0 and selected["directionWeight"] > 0
if dominance_passed and agreement_passed and direction_passed:
    classification = "concentratedStableTraceSelected"
elif dominance_passed and direction_passed:
    classification = "concentratedPhaseFragile"
else:
    classification = "diffuseResidualNoSingleTrace"
trace_authorized = classification == "concentratedStableTraceSelected"

for row in candidate_rows:
    for phase, _ in PHASES:
        rows.append({
            "component": row["component"],
            "directionIndex": row["directionIndex"],
            "direction": row["direction"],
            "offsetName": phase,
            "sourceResidual": row["sourceResidualByOffset"][phase],
            "componentResidual": row["componentResidualByOffset"][phase],
            "positiveAlignmentShare": row["positiveAlignmentShare"],
            "centeredPhaseCovariance": row["centeredPhaseCovariance"],
        })
ARCHIVE.mkdir(parents=True, exist_ok=True)
with CSV.open("w", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
    writer.writeheader()
    writer.writerows(rows)

gates = {
    "registeredBeforeResidualSelection": prereg["registeredBeforeResidualSelection"],
    "parentEvidencePassed": parent["passed"] and parent_audit["passed"],
    "parentPowerGateFailed": parent["quantitativePowerGatePassed"] is False,
    "allNineInputHashesMatchParent": all(
        inputs[phase][f"c{resolution}"]["sha256"]
        == parent["phaseInputs"][phase][f"c{resolution}"]["censusSHA256"]
        for phase, _ in PHASES for resolution in RESOLUTIONS
    ),
    "completeD3Q19": all(
        len(profiles[phase][resolution]["records"]) == 19
        for phase, _ in PHASES for resolution in RESOLUTIONS
    ),
    "residualComponentClosure": closure_maximum
        <= prereg["gates"]["maximumAbsoluteResidualComponentClosure"],
    "allFinite": all(
        math.isfinite(value)
        for row in candidate_rows
        for value in (
            row["systematicAlignment"],
            row["positiveAlignmentShare"],
            row["centeredPhaseCovariance"],
        )
    ),
    "selectedMovingDirection": direction_passed,
}
selection_gates = {
    "minimumPositiveAlignmentShare": dominance_passed,
    "minimumSignAgreementCount": agreement_passed,
}
summary = {
    "schemaVersion": 1,
    "title": "Formation source c18 residual covariance selector",
    "scientificQuestion": prereg["scientificQuestion"],
    "preregistration": {"path": str(PREREG.relative_to(ROOT)), "sha256": digest(PREREG)},
    "parentEvidence": {
        "summaryPath": str(PARENT_SUMMARY.relative_to(ROOT)),
        "summarySHA256": digest(PARENT_SUMMARY),
        "auditPath": str(PARENT_AUDIT.relative_to(ROOT)),
        "auditSHA256": digest(PARENT_AUDIT),
        "classification": parent["classification"],
    },
    "inputs": inputs,
    "interpolationFraction": t,
    "residualComponentClosureMaximumAbsolute": closure_maximum,
    "positiveSystematicAlignmentTotal": positive_total,
    "ranking": candidate_rows,
    "selectedTrace": {
        "chordCells": 18,
        "owner": "leader",
        "leaderPhaseAnchor": prereg["lockedConfiguration"]["leaderPhaseAnchor"],
        "component": selected_component,
        "directionIndex": selected_direction,
        "direction": selected["direction"],
        "positiveAlignmentShare": selected["positiveAlignmentShare"],
        "signAgreementCount": selected["signAgreementCount"],
        "signAgreementFraction": selected["signAgreementFraction"],
        "systematicAlignment": selected["systematicAlignment"],
        "centeredPhaseCovariance": selected["centeredPhaseCovariance"],
        "offsetName": trace_phase["phase"],
        "subcellOffsetCells": trace_phase["offsetCells"],
        "localAlignment": trace_phase["localAlignment"],
    },
    "phaseAlignmentForSelectedTrace": phase_alignment,
    "classification": classification,
    "traceAuthorized": trace_authorized,
    "gates": gates,
    "selectionGates": selection_gates,
    "passed": all(gates.values()),
    "nextAction": prereg["decisionRule"]["nextActions"][classification],
    "csvPath": str(CSV.relative_to(ROOT)),
    "figurePaths": [str(PNG.relative_to(ROOT)), str(SVG.relative_to(ROOT))],
    "fluidTimestepsExecuted": 0,
    "claimBoundary": prereg["claimBoundary"],
}
SUMMARY.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")

plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 10, "axes.titleweight": "bold", "svg.hashsalt": "birdflow-residual-covariance-v1"})
fig, axes = plt.subplots(1, 3, figsize=(16, 5.8), facecolor="#06101c")
for axis in axes:
    axis.set_facecolor("#0b1b2d")
    axis.tick_params(colors="#cbd8e5")
    axis.grid(color="#27415d", alpha=0.45, linewidth=0.6)
    for spine in axis.spines.values():
        spine.set_color("#35516d")
    axis.xaxis.label.set_color("#cbd8e5")
    axis.yaxis.label.set_color("#cbd8e5")
    axis.title.set_color("#f4f8fc")

heat = np.zeros((3, 19))
for row in candidate_rows:
    heat[row["componentOrder"], row["directionIndex"]] = row["positiveAlignmentShare"] * 100
image = axes[0].imshow(heat, aspect="auto", cmap="magma", interpolation="nearest")
axes[0].scatter([selected_direction], [selected["componentOrder"]], marker="s", s=120, facecolors="none", edgecolors="#36d7ff", linewidths=2)
axes[0].set_yticks(range(3), ["reflected", "interpolation", "moving wall"])
axes[0].set_xlabel("D3Q19 direction")
axes[0].set_title("POSITIVE SYSTEMATIC ALIGNMENT (%)")
fig.colorbar(image, ax=axes[0], fraction=0.046, pad=0.04)

phase_colors = {"offset1": "#36d7ff", "offset2": "#ffd166", "offset3": "#ff6b9d"}
indices = np.arange(19)
for phase, _ in PHASES:
    axes[1].plot(indices, source_residuals[phase], marker="o", markersize=3.5, linewidth=1.5, color=phase_colors[phase], label=phase)
axes[1].plot(indices, mean_source, color="#f4f8fc", linewidth=2.4, label="phase mean")
axes[1].axvline(selected_direction, color="#36d7ff", linestyle="--", linewidth=1.2)
axes[1].set_title("C18 EXACT-SOURCE H-LINEAR RESIDUAL")
axes[1].set_xlabel("D3Q19 direction")
axes[1].set_ylabel("source residual")
axes[1].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

source_values = [source_residuals[phase][selected_direction] for phase, _ in PHASES]
component_values = [component_residuals[phase][selected_component][selected_direction] for phase, _ in PHASES]
x = np.arange(3)
axes[2].bar(x - 0.18, source_values, width=0.36, color="#36d7ff", label="exact source")
axes[2].bar(x + 0.18, component_values, width=0.36, color="#ff6b9d", label=selected_component)
axes[2].axhline(0, color="#90a9c1", linewidth=0.8)
axes[2].set_xticks(x, [name for name, _ in PHASES])
axes[2].set_title(f"SELECTED q={selected_direction}  SHARE={selected['positiveAlignmentShare'] * 100:.1f}%")
axes[2].set_xlabel("lattice offset")
axes[2].set_ylabel("c18 h-linear residual")
axes[2].legend(facecolor="#0b1b2d", edgecolor="#35516d", labelcolor="#cbd8e5")

verdict = "ONE TRACE AUTHORIZED" if trace_authorized else "NO SINGLE TRACE AUTHORIZED"
fig.suptitle(f"BIRDFLOW METAL  /  SOURCE RESIDUAL SELECTOR  /  {verdict}", color="#f4f8fc", fontsize=16, fontweight="bold", y=0.99)
fig.text(0.5, 0.015, "archive-only • leader • c18 residual against h-linear c16/c20 endpoints • zero fluid timesteps", ha="center", color="#90a9c1", fontsize=9)
fig.tight_layout(rect=(0, 0.045, 1, 0.95))
fig.savefig(PNG, dpi=180, facecolor=fig.get_facecolor())
fig.savefig(SVG, facecolor=fig.get_facecolor())
print(f"residual selector classification: {classification}")
print(f"selected: {selected_component}, q={selected_direction}, offset={trace_phase['offsetCells']}")
print(f"positive alignment share: {selected['positiveAlignmentShare']:.9%}")
print(f"sign agreement: {selected['signAgreementCount']}/3")
print(f"trace authorized: {trace_authorized}")
print(f"summary: {SUMMARY.relative_to(ROOT)}")

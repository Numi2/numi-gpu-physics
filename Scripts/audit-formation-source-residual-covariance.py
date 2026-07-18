#!/usr/bin/env python3
"""Independent arithmetic/provenance audit for the residual trace selector."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-source-residual-covariance-v1.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-source-residual-covariance/formation-flight-source-residual-covariance-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-source-residual-covariance/formation-flight-source-residual-covariance-audit.json"
PHASES = ("offset1", "offset2", "offset3")
RESOLUTIONS = (16, 18, 20)
COMPONENTS = ("reflectedMomentumExchange", "interpolationAuxiliary", "movingWall")


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(a: float, b: float, tolerance: float = 1e-11) -> bool:
    return math.isclose(a, b, rel_tol=tolerance, abs_tol=tolerance)


prereg, summary = load(PREREG), load(SUMMARY)
checks: list[dict] = []


def check(name: str, passed: bool, evidence: object) -> None:
    checks.append({"name": name, "passed": bool(passed), "evidence": evidence})


check("registered before residual selection", prereg["registeredBeforeResidualSelection"] is True, prereg["registeredAtUTC"])
for group in ("lockedInputs", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"{group} hash {item['path']}", actual == item["sha256"], actual)
for key in ("summary", "audit"):
    path = ROOT / summary["parentEvidence"][f"{key}Path"]
    actual = digest(path)
    check(f"parent {key} hash", actual == summary["parentEvidence"][f"{key}SHA256"], actual)
    check(f"parent {key} passed", load(path)["passed"] is True, load(path).get("classification", load(path).get("checksPassed")))

profiles: dict[str, dict] = {}
weights = np.zeros(19)
for phase in PHASES:
    profiles[phase] = {}
    for resolution in RESOLUTIONS:
        item = summary["inputs"][phase][f"c{resolution}"]
        path = ROOT / item["path"]
        actual = digest(path)
        check(f"{phase} c{resolution} hash", actual == item["sha256"], actual)
        census = load(path)
        check(f"{phase} c{resolution} census passed", census["passed"] is True, census["maximumRelativeReconstructionClosureResidual"])
        sample = next(row for row in census["samples"] if row["flyer"] == "leader")
        records = sorted(sample["directions"], key=lambda row: row["directionIndex"])
        check(f"{phase} c{resolution} complete D3Q19", [row["directionIndex"] for row in records] == list(range(19)), len(records))
        directions = np.asarray([row["direction"] for row in records], dtype=float)
        weights = np.linalg.norm(directions, axis=1)
        raw_reflected = np.asarray([row["rawReflectedPopulationSum"] for row in records])
        incoming = np.asarray([row["reconstructedIncomingPopulationSum"] for row in records])
        reflected_in = np.asarray([row["reflectedIncomingPopulationSum"] for row in records])
        interpolation = np.asarray([row["interpolationAuxiliaryPopulationSum"] for row in records])
        wall = np.asarray([row["movingWallPopulationSum"] for row in records])
        scale = resolution**2
        profiles[phase][resolution] = {
            "source": (raw_reflected + incoming) / scale,
            "components": {
                "reflectedMomentumExchange": (raw_reflected + reflected_in) / scale,
                "interpolationAuxiliary": interpolation / scale,
                "movingWall": wall / scale,
            },
            "directions": directions,
        }

t = ((1 / 18) - (1 / 16)) / ((1 / 20) - (1 / 16))
check("interpolation fraction", close(t, summary["interpolationFraction"]), t)
source_residuals = {}
component_residuals = {}
closure_maximum = 0.0
for phase in PHASES:
    source_residuals[phase] = profiles[phase][18]["source"] - profiles[phase][16]["source"] - t * (profiles[phase][20]["source"] - profiles[phase][16]["source"])
    component_residuals[phase] = {}
    for component in COMPONENTS:
        values = profiles[phase]
        component_residuals[phase][component] = values[18]["components"][component] - values[16]["components"][component] - t * (values[20]["components"][component] - values[16]["components"][component])
    closure_maximum = max(closure_maximum, float(np.max(np.abs(source_residuals[phase] - sum(component_residuals[phase].values())))))
check("residual component closure", close(closure_maximum, summary["residualComponentClosureMaximumAbsolute"]), closure_maximum)
check("residual component closure gate", closure_maximum <= prereg["gates"]["maximumAbsoluteResidualComponentClosure"], closure_maximum)

source_matrix = np.stack([source_residuals[phase] for phase in PHASES])
mean_source = np.mean(source_matrix, axis=0)
rows = []
for component_order, component in enumerate(COMPONENTS):
    component_matrix = np.stack([component_residuals[phase][component] for phase in PHASES])
    mean_component = np.mean(component_matrix, axis=0)
    for direction_index in range(19):
        alignment = float(weights[direction_index] * mean_component[direction_index] * mean_source[direction_index])
        covariance = float(weights[direction_index] * np.mean((component_matrix[:, direction_index] - mean_component[direction_index]) * (source_matrix[:, direction_index] - mean_source[direction_index])))
        products = component_matrix[:, direction_index] * source_matrix[:, direction_index]
        rows.append({
            "component": component,
            "componentOrder": component_order,
            "directionIndex": direction_index,
            "systematicAlignment": alignment,
            "positiveSystematicAlignment": max(alignment, 0.0),
            "centeredPhaseCovariance": covariance,
            "signAgreementCount": int(np.count_nonzero(products > 0.0)),
        })
positive_total = sum(row["positiveSystematicAlignment"] for row in rows)
check("positive alignment total", close(positive_total, summary["positiveSystematicAlignmentTotal"]), positive_total)
for row in rows:
    row["positiveAlignmentShare"] = row["positiveSystematicAlignment"] / max(positive_total, prereg["selectionRule"]["denominatorFloor"])
rows.sort(key=lambda row: (-row["positiveSystematicAlignment"], -row["signAgreementCount"], row["componentOrder"], row["directionIndex"]))
selected = rows[0]
stored = summary["selectedTrace"]
check("selected component", selected["component"] == stored["component"], selected["component"])
check("selected direction", selected["directionIndex"] == stored["directionIndex"], selected["directionIndex"])
check("selected share", close(selected["positiveAlignmentShare"], stored["positiveAlignmentShare"]), selected["positiveAlignmentShare"])
check("selected systematic alignment", close(selected["systematicAlignment"], stored["systematicAlignment"]), selected["systematicAlignment"])
check("selected centered covariance", close(selected["centeredPhaseCovariance"], stored["centeredPhaseCovariance"]), selected["centeredPhaseCovariance"])
check("selected sign agreement", selected["signAgreementCount"] == stored["signAgreementCount"], selected["signAgreementCount"])

direction_index = selected["directionIndex"]
phase_alignment = []
offsets = prereg["lockedConfiguration"]["offsets"]
for phase_order, phase in enumerate(PHASES):
    alignment = float(weights[direction_index] * component_residuals[phase][selected["component"]][direction_index] * source_residuals[phase][direction_index])
    phase_alignment.append({"phase": phase, "phaseOrder": phase_order, "offsetCells": offsets[phase_order], "localAlignment": alignment})
phase_alignment.sort(key=lambda row: (-row["localAlignment"], row["phaseOrder"]))
check("selected trace offset", phase_alignment[0]["offsetCells"] == stored["subcellOffsetCells"], phase_alignment[0])
check("selected local alignment", close(phase_alignment[0]["localAlignment"], stored["localAlignment"]), phase_alignment[0]["localAlignment"])

dominance = selected["positiveAlignmentShare"] >= prereg["selectionRule"]["minimumPositiveAlignmentShare"]
agreement = selected["signAgreementCount"] >= prereg["selectionRule"]["minimumSignAgreementCount"]
moving = selected["directionIndex"] != 0 and weights[selected["directionIndex"]] > 0
if dominance and agreement and moving:
    classification = "concentratedStableTraceSelected"
elif dominance and moving:
    classification = "concentratedPhaseFragile"
else:
    classification = "diffuseResidualNoSingleTrace"
check("classification", classification == summary["classification"], classification)
check("trace authorization", (classification == "concentratedStableTraceSelected") == summary["traceAuthorized"], classification)
check("summary evidence passed", summary["passed"] is True, summary["gates"])
check("zero fluid timesteps", summary["fluidTimestepsExecuted"] == 0, summary["fluidTimestepsExecuted"])
check("figure PNG exists", (ROOT / summary["figurePaths"][0]).is_file(), summary["figurePaths"][0])
check("figure SVG exists", (ROOT / summary["figurePaths"][1]).is_file(), summary["figurePaths"][1])
check("GitHub Actions absent", not (ROOT / ".github").exists(), (ROOT / ".github").exists())

output = {
    "schemaVersion": 1,
    "title": "Formation source residual covariance independent audit",
    "checks": checks,
    "checkCount": len(checks),
    "checksPassed": sum(item["passed"] for item in checks),
    "recomputedResidualComponentClosureMaximumAbsolute": closure_maximum,
    "recomputedPositiveSystematicAlignmentTotal": positive_total,
    "recomputedSelection": {
        "component": selected["component"],
        "directionIndex": selected["directionIndex"],
        "positiveAlignmentShare": selected["positiveAlignmentShare"],
        "signAgreementCount": selected["signAgreementCount"],
        "offsetCells": phase_alignment[0]["offsetCells"],
    },
    "recomputedClassification": classification,
    "recomputedTraceAuthorized": classification == "concentratedStableTraceSelected",
    "passed": all(item["passed"] for item in checks),
}
AUDIT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
print(f"formation source residual covariance audit: {output['checksPassed']}/{output['checkCount']} checks passed")
if not output["passed"]:
    for item in checks:
        if not item["passed"]:
            print(f"FAILED: {item['name']}: {item['evidence']}")
    raise SystemExit(1)

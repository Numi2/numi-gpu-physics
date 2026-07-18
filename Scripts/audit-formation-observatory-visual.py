#!/usr/bin/env python3
"""Fail-closed audit for the seamless-field Formation Observatory."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ValidationArtifacts/formation-flight-observatory-visual-v9.json"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def combined_digest(directory: Path, entries: list[dict]) -> str:
    value = hashlib.sha256()
    for entry in entries:
        path = directory / entry["file"]
        value.update(entry["file"].encode())
        value.update(b"\0")
        value.update(path.read_bytes())
    return value.hexdigest()


manifest = json.loads(MANIFEST.read_text())
checks = []


def check(name: str, condition: bool, detail=None):
    checks.append({"name": name, "passed": bool(condition), "detail": detail})


for item in manifest["lockedInputs"] + manifest["lockedImplementation"]:
    actual = digest(ROOT / item["path"])
    check(f"locked hash {item['path']}", actual == item["sha256"], actual)

index_path = ROOT / manifest["flowSliceArchive"]["indexPath"]
index = json.loads(index_path.read_text())
directory = index_path.parent
check("exact flow slice count", len(index["entries"]) == 21, len(index["entries"]))
actual_combined = combined_digest(directory, index["entries"])
check(
    "combined flow slice archive hash",
    actual_combined == manifest["flowSliceArchive"]["combinedSHA256"],
    actual_combined,
)

output = ROOT / manifest["output"]["path"]
check("GIF hash", digest(output) == manifest["output"]["sha256"], digest(output))
check("GIF byte budget", output.stat().st_size == manifest["output"]["bytes"] and output.stat().st_size < 10_000_000, output.stat().st_size)
image = Image.open(output)
frames = [
    np.asarray(frame.convert("RGB"), dtype=np.float32)
    for frame in ImageSequence.Iterator(image)
]
check("GIF dimensions", image.size == tuple(manifest["output"]["dimensions"]), image.size)
check("GIF frame count", len(frames) == manifest["output"]["frameCount"], len(frames))
adjacent = [
    float(np.sqrt(np.mean((left - right) ** 2)))
    for left, right in zip(frames, frames[1:])
]
median = float(np.median(adjacent))
seam = float(np.sqrt(np.mean((frames[-1] - frames[0]) ** 2)))
ratio = seam / max(median, 1e-12)
check(
    "encoded seam remains ordinary motion",
    ratio <= manifest["output"]["maximumSeamToMedianAdjacentRMSRatio"],
    ratio,
)
check(
    "recorded seam ratio",
    math.isclose(ratio, manifest["output"]["seamToMedianAdjacentRMSRatio"], rel_tol=1e-12, abs_tol=1e-12),
    ratio,
)

subcell = json.loads(
    (ROOT / manifest["scientificStatus"]["subcellSummaryPath"]).read_text()
)
check("subcell ensemble passed", subcell["passed"])
check("subcell classification", subcell["classification"] == "aliasingAveragedOut", subcell["classification"])
check("subcell case count", subcell["caseCount"] == 192, subcell["caseCount"])
check("subcell no-fluid boundary", subcell["noFluidTimesteps"])

source = json.loads(
    (ROOT / manifest["scientificStatus"]["sourceSummaryPath"]).read_text()
)
source_metrics = source["decisionMetrics"]
check("source discriminator passed", source["passed"])
check(
    "mixed population-weighted source classification",
    source["classification"] == "mixedPopulationWeightedSource",
    source["classification"],
)
check("all source gates pass", all(source["gates"].values()), source["gates"])
check(
    "geometry curvature remains smooth",
    source_metrics["selectedGeometryDensityCurvature"]
    <= source_metrics["smoothRefinementMaximumCurvature"],
    source_metrics["selectedGeometryDensityCurvature"],
)
check(
    "population-weighted source curvature is mixed",
    source_metrics["smoothRefinementMaximumCurvature"]
    < source_metrics["normalizedPopulationWeightedSourceCurvature"]
    < source_metrics["persistentBiasMinimumCurvature"],
    source_metrics["normalizedPopulationWeightedSourceCurvature"],
)
source_audit = json.loads(
    (ROOT / manifest["scientificStatus"]["sourceAuditPath"]).read_text()
)
check(
    "independent source audit",
    source_audit["passed"]
    and source_audit["checkCount"] == source_audit["checksPassed"],
    f"{source_audit['checksPassed']}/{source_audit['checkCount']}",
)

focused = json.loads(
    (ROOT / manifest["scientificStatus"]["focusedSourceTracePath"]).read_text()
)
check("focused source trace passed", focused["gates"]["passed"])
check(
    "focused source trace identity",
    focused["configuration"]["chordCells"] == 18
    and focused["configuration"]["cycles"] == 5
    and focused["configuration"]["followerOffsetChords"] == [0, 0, -3]
    and math.isclose(
        focused["configuration"]["followerPhaseOffsetCycles"],
        0.25,
        abs_tol=1e-12,
    )
    and focused["subcellOffsetCells"] == [0.25, 0.25, 0.75]
    and focused["flyer"] == "leader"
    and focused["directionIndex"] == 5
    and focused["direction"] == [0, 0, 1],
)
check(
    "focused source trace complete",
    focused["cycleSteps"] == 4_820
    and len(focused["samples"]) == 4_820
    and all(sample["branchCountClosurePassed"] for sample in focused["samples"]),
    len(focused["samples"]),
)
focused_audit = json.loads(
    (ROOT / manifest["scientificStatus"]["focusedSourceTraceAuditPath"]).read_text()
)
check(
    "independent focused source audit",
    focused_audit["passed"]
    and focused_audit["checkCount"] == focused_audit["passedCheckCount"],
    f"{focused_audit['passedCheckCount']}/{focused_audit['checkCount']}",
)

dove = json.loads(
    (ROOT / manifest["presentationGeometry"]["doveAuditPath"]).read_text()
)
check("dual-dove presentation audit passed", dove["passed"])
check(
    "locked dove identity and topology",
    dove["datasetIdentifier"]
    == "deetjen-ob-2018-12-11-f03-complete-surface-v1"
    and dove["flyerCount"] == 2
    and dove["vertexCountPerFlyer"] == 2_157
    and dove["triangleCountPerFlyer"] == 3_968,
    f"{dove['flyerCount']} x {dove['vertexCountPerFlyer']} vertices",
)
check(
    "dove component evidence disclosed",
    dove["componentNames"] == ["body", "leftWing", "rightWing", "tail"]
    and dove["componentEvidenceClasses"][2]
    == "bilateral-reflection-assumption",
    dove["componentEvidenceClasses"],
)
check(
    "measured loop and Hermite closure locked",
    dove["measuredLoopStartFrame"] == 27
    and dove["measuredLoopEndFrame"] == 121
    and math.isclose(dove["closureDurationSeconds"], 0.014, abs_tol=1e-9)
    and dove["endpointMaximumPositionResidual"] <= 1e-7,
    dove["endpointMaximumPositionResidual"],
)
check(
    "intentional flyer-pair phase offset",
    math.isclose(
        dove["flyerPairPhaseOffsetCycles"],
        manifest["presentationGeometry"]["flyerPairPhaseOffsetCycles"],
        abs_tol=1e-12,
    ),
    dove["flyerPairPhaseOffsetCycles"],
)
check(
    "tail presentation scale bounded",
    dove["tailScale"][1] < 0.5 * dove["bodyAndWingScale"][1],
    {"bodyAndWing": dove["bodyAndWingScale"], "tail": dove["tailScale"]},
)
check(
    "dove surface remains presentation-only",
    dove["presentationOnly"]
    and dove["completeBirdSurfaceReady"]
    and not dove["quantitativeForceAcceptanceReady"],
)
check(
    "cyclic archived CFD interpolation visible at every phase",
    dove["flowDisplayMode"]
    == "cyclic-linear-interpolation-of-archived-c20-phases"
    and dove["archivedFlowSliceCount"] == 21
    and dove["capturePhaseCount"] == 48
    and dove["capturePhasesWithVisibleFlow"] == dove["capturePhaseCount"]
    and dove["minimumFlowOpacity"] == 1,
    {
        "visible": dove["capturePhasesWithVisibleFlow"],
        "phases": dove["capturePhaseCount"],
        "minimumOpacity": dove["minimumFlowOpacity"],
    },
)
check(
    "presentation field seam suppression lock",
    dove["flowSpatialFilterMode"]
    == "gaussian-radius4-sigma2-with-solid-gap-fill-presentation-only"
    and dove["flowOpacityMode"]
    == "joint-vorticity-and-vertical-velocity-signal"
    and math.isclose(dove["minimumDisplayedSignalOpacity"], 0.025, abs_tol=1e-9),
)
check(
    "wake bridge evidence lock",
    dove["wakeBridgeMode"]
    == "archived-c20-vorticity-ridge+c18-q5-luminance"
    and dove["focusedSourceTraceSampleCount"] == 4_820
    and dove["focusedSourceTraceDirectionIndex"] == 5
    and dove["wakeBridgePhaseCount"] == dove["capturePhaseCount"],
)
check(
    "cinematic overlay lock",
    dove["overlayMode"] == "none-cinematic",
)
check(
    "seamless spherical figure-eight camera lock",
    dove["cameraCompositionMode"]
    == "spherical-figure-eight-dual-dove-wake-bridge"
    and math.isclose(dove["cameraYawAmplitudeRadians"], 0.34, abs_tol=1e-9)
    and math.isclose(dove["cameraPitchAmplitudeRadians"], 0.10, abs_tol=1e-9)
    and math.isclose(dove["cameraDistanceAmplitudeChords"], 0.10, abs_tol=1e-9)
    and dove["cameraEndpointParameterResidual"] <= 1e-7,
)
check(
    "quantitative force claim remains open",
    "force convergence" in manifest["claimBoundary"].lower()
    and "presentation" in manifest["claimBoundary"].lower(),
)
check(
    "archived procedural predecessor hash",
    digest(ROOT / manifest["predecessor"]["path"])
    == manifest["predecessor"]["sha256"],
)
check("GitHub Actions remain absent", not (ROOT / ".github").exists())

passed = all(item["passed"] for item in checks)
result = {
    "schemaVersion": 7,
    "title": "Seamless-field Formation Observatory visual audit",
    "passed": passed,
    "checkCount": len(checks),
    "passedCheckCount": sum(item["passed"] for item in checks),
    "encodedMedianAdjacentRMS": median,
    "encodedSeamRMS": seam,
    "encodedSeamToMedianAdjacentRMSRatio": ratio,
    "checks": checks,
    "claimBoundary": manifest["claimBoundary"],
}
audit_path = ROOT / manifest["auditPath"]
audit_path.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
print(json.dumps({
    "passed": passed,
    "checks": len(checks),
    "seamRatio": ratio,
    "audit": str(audit_path.relative_to(ROOT)),
}, indent=2))
if not passed:
    raise SystemExit("formation observatory visual audit failed")

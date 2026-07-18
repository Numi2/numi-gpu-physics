#!/usr/bin/env python3
"""Fail-closed audit for the synchronized native Metal Formation Observatory GIF."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageSequence

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "ValidationArtifacts/formation-flight-observatory-visual-v4.json"


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

bilateral = json.loads(
    (ROOT / manifest["presentationGeometry"]["bilateralAuditPath"]).read_text()
)
max_residual = manifest["presentationGeometry"]["maximumReflectionResidual"]
check("bilateral presentation audit passed", bilateral["passed"])
check(
    "bilateral audit phase coverage",
    bilateral["flyerCount"] == 2
    and bilateral["phaseCountPerFlyer"] == 48
    and bilateral["vertexPairsCompared"] >= 30_000,
    bilateral["vertexPairsCompared"],
)
check(
    "sagittal position reflection",
    bilateral["maximumPositionReflectionResidual"] <= max_residual,
    bilateral["maximumPositionReflectionResidual"],
)
check(
    "sagittal normal reflection",
    bilateral["maximumNormalReflectionResidual"] <= max_residual,
    bilateral["maximumNormalReflectionResidual"],
)
check(
    "within-flyer wing phase synchronization",
    bilateral["maximumWithinFlyerPhaseDifferenceCycles"] == 0,
    bilateral["maximumWithinFlyerPhaseDifferenceCycles"],
)
check(
    "intentional flyer-pair phase offset",
    math.isclose(
        bilateral["flyerPairPhaseOffsetCycles"],
        manifest["presentationGeometry"]["flyerPairPhaseOffsetCycles"],
        abs_tol=1e-12,
    ),
    bilateral["flyerPairPhaseOffsetCycles"],
)
check(
    "quantitative force claim remains open",
    "force convergence" in manifest["claimBoundary"].lower()
    and "presentation" in manifest["claimBoundary"].lower(),
)
check(
    "known-invalid predecessor archived",
    digest(ROOT / manifest["predecessor"]["path"])
    == manifest["predecessor"]["sha256"]
    and "invalid" in manifest["predecessor"]["description"].lower(),
)
check("GitHub Actions remain absent", not (ROOT / ".github").exists())

passed = all(item["passed"] for item in checks)
result = {
    "schemaVersion": 2,
    "title": "Synchronized native Metal Formation Observatory visual audit",
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

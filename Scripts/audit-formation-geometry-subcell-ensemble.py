#!/usr/bin/env python3
"""Independent audit of the Formation Flight subcell geometry ensemble."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-geometry-subcell-ensemble-v1.json"
BRIDGE = ROOT / "ValidationArtifacts/formation-flight-geometry-c18-bridge/formation-flight-geometry-census.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-geometry-subcell-ensemble"
REPORT = ARCHIVE / "formation-flight-geometry-subcell-ensemble.json"
SUMMARY = ARCHIVE / "formation-flight-geometry-subcell-ensemble-summary.json"
AUDIT = ARCHIVE / "formation-flight-geometry-subcell-ensemble-audit.json"


def load(path):
    with path.open() as handle:
        return json.load(handle)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


checks = []


def check(name, condition, detail=None):
    checks.append({"name": name, "passed": bool(condition), "detail": detail})


prereg = load(PREREG)
report = load(REPORT)
summary = load(SUMMARY)
bridge = load(BRIDGE)
check("preregistered before ensemble execution", prereg["preregisteredBeforeEnsembleExecution"])
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"locked hash {item['path']}", actual == item["sha256"], actual)

def case_key(value):
    offset = value["offsetCells"]
    return (int(value["chordCells"]), float(offset[0]), float(offset[1]), float(offset[2]))


cases = {case_key(value): value for value in report["cases"]}
values = [0, 0.25, 0.5, 0.75]
expected = {(r, x, y, z) for r in (16, 18, 20) for z in values for y in values for x in values}
check("exact 192-case tensor grid", set(cases) == expected, len(cases))
check("raw report passed", report["passed"])
for gate in ("noFluidTimesteps", "completeTensorGrid", "positiveLinkSupport", "zeroOverlap", "allFinite"):
    check(f"raw gate {gate}", report["gates"][gate])

bridge_samples = {int(value["chordCells"]): value for value in bridge["samples"]}
for resolution in (16, 18, 20):
    observed = cases[(resolution, 0.0, 0.0, 0.0)]
    source = bridge_samples[resolution]
    for flyer, field in (("leader", "leaderLinkCount"), ("follower", "followerLinkCount")):
        for q, (left, right) in enumerate(zip(observed["directions"], source["directions"])):
            check(
                f"c{resolution} {flyer} q{q} bridge parity",
                int(left[field]) == int(right[field]),
                {"ensemble": int(left[field]), "bridge": int(right[field])},
            )

density = {resolution: [] for resolution in (16, 18, 20)}
probability = {resolution: [] for resolution in (16, 18, 20)}
areal = {resolution: [] for resolution in (16, 18, 20)}
weights = np.asarray([
    math.sqrt(sum(component * component for component in item["direction"]))
    for item in report["cases"][0]["directions"]
])
offsets = [(x, y, z) for z in values for y in values for x in values]
for resolution in (16, 18, 20):
    for offset in offsets:
        value = cases[(resolution, *offset)]
        vector = np.asarray([item["leaderLinkCount"] for item in value["directions"]], dtype=float)
        check(
            f"c{resolution} offset {offset} leader total closure",
            int(vector.sum()) == int(value["totalLeaderBoundaryLinkCount"]),
        )
        density[resolution].append(float(vector.sum() / resolution**2))
        probability[resolution].append(vector / vector.sum())
        areal[resolution].append(vector / resolution**2)
    density[resolution] = np.asarray(density[resolution])
    probability[resolution] = np.asarray(probability[resolution])
    areal[resolution] = np.asarray(areal[resolution])

mean_d = {r: float(density[r].mean()) for r in (16, 18, 20)}
mean_p = {r: probability[r].mean(axis=0) for r in (16, 18, 20)}
mean_a = {r: areal[r].mean(axis=0) for r in (16, 18, 20)}
floor = prereg["decisionRule"]["denominatorFloor"]
d_curve = abs(mean_d[18] - 0.5 * (mean_d[16] + mean_d[20])) / max(abs(mean_d[20] - mean_d[16]), floor)
p_curve = (0.5 * np.abs(mean_p[18] - 0.5 * (mean_p[16] + mean_p[20])).sum()) / max(0.5 * np.abs(mean_p[20] - mean_p[16]).sum(), floor)
a_curve = float((weights * np.abs(mean_a[18] - 0.5 * (mean_a[16] + mean_a[20]))).sum()) / max(float((weights * np.abs(mean_a[20] - mean_a[16])).sum()), floor)
between = min(mean_d[16], mean_d[20]) <= mean_d[18] <= max(mean_d[16], mean_d[20])
if between and max(d_curve, p_curve, a_curve) <= 0.5:
    verdict = "aliasingAveragedOut"
elif (not between) or max(d_curve, p_curve, a_curve) >= 1:
    verdict = "persistentResolutionBias"
else:
    verdict = "mixedSubcellSensitivity"
matched = density[18] - 0.5 * (density[16] + density[20])
metrics = summary["decisionMetrics"]
for name, actual in (
    ("normalizedMeanDensityMidpointCurvature", d_curve),
    ("normalizedMeanDirectionMidpointCurvature", p_curve),
    ("normalizedMeanArealProfileMidpointCurvature", a_curve),
):
    check(name, math.isclose(actual, metrics[name], rel_tol=1e-13, abs_tol=1e-13), {"audit": actual, "summary": metrics[name]})
check("mean density interval", between == metrics["meanDensityBetweenEndpoints"])
check("classification", verdict == summary["classification"], {"audit": verdict, "summary": summary["classification"]})
check("baseline matched residual", math.isclose(float(matched[0]), summary["baselineMatchedMidpointResidual"], rel_tol=1e-13, abs_tol=1e-13))
for path in (
    ARCHIVE / "formation-flight-geometry-subcell-ensemble-cases.csv",
    ROOT / "Docs/Media/formation-flight-geometry-subcell-ensemble.png",
    ROOT / "Docs/Media/formation-flight-geometry-subcell-ensemble.svg",
):
    check(f"artifact exists {path.relative_to(ROOT)}", path.is_file() and path.stat().st_size > 0)

passed = all(value["passed"] for value in checks) and summary["passed"]
audit = {
    "schemaVersion": 1,
    "title": "Independent Formation Flight subcell geometry ensemble audit",
    "passed": passed,
    "checkCount": len(checks),
    "passedCheckCount": sum(value["passed"] for value in checks),
    "classification": verdict,
    "independentMetrics": {
        "meanDensityBetweenEndpoints": between,
        "normalizedMeanDensityMidpointCurvature": float(d_curve),
        "normalizedMeanDirectionMidpointCurvature": float(p_curve),
        "normalizedMeanArealProfileMidpointCurvature": float(a_curve),
        "baselineMatchedMidpointResidual": float(matched[0]),
    },
    "checks": checks,
    "claimBoundary": prereg["claimBoundary"],
}
AUDIT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
print(json.dumps({"passed": passed, "checks": len(checks), "classification": verdict, "audit": str(AUDIT.relative_to(ROOT))}, indent=2))
if not passed:
    raise SystemExit("independent subcell ensemble audit failed")

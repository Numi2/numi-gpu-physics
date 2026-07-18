#!/usr/bin/env python3
"""Independent recomputation audit for the geometry-only c18 bridge."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-geometry-c18-bridge-v1.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-geometry-c18-bridge"
REPORT = ARCHIVE / "formation-flight-geometry-census.json"
SUMMARY = ARCHIVE / "formation-flight-geometry-c18-bridge-summary.json"
AUDIT = ARCHIVE / "formation-flight-geometry-c18-bridge-audit.json"


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
check("preregistered before c18 execution", prereg["preregisteredBeforeC18Execution"])
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"locked hash {item['path']}", actual == item["sha256"], actual)

samples = {int(value["chordCells"]): value for value in report["samples"]}
check("exact locked resolution set", sorted(samples) == [16, 18, 20], sorted(samples))
check("raw report passed", report["passed"])
check("no fluid timesteps", report["gates"]["noFluidTimesteps"])
check("positive link support", report["gates"]["positiveLinkSupport"])
check("zero overlap", report["gates"]["zeroOverlap"])
check("raw values finite", report["gates"]["allFinite"])

endpoint_paths = prereg["lockedConfiguration"]["endpointArchives"]
for resolution, endpoint_key in ((16, "c16"), (20, "c20")):
    endpoint = load(ROOT / endpoint_paths[endpoint_key])
    for flyer, count_key in (
        ("leader", "leaderLinkCount"),
        ("follower", "followerLinkCount"),
    ):
        candidates = [value for value in endpoint["samples"] if value["flyer"] == flyer]
        raw = min(candidates, key=lambda value: abs(value["leaderPhase"] - 0.785))
        expected = [int(value["linkCount"]) for value in raw["directions"]]
        observed = [int(value[count_key]) for value in samples[resolution]["directions"]]
        for q, (left, right) in enumerate(zip(observed, expected)):
            check(f"c{resolution} {flyer} q{q} archive parity", left == right, {"observed": left, "expected": right})

counts = {}
weights = []
for value in samples[16]["directions"]:
    weights.append(math.sqrt(sum(component * component for component in value["direction"])))
for resolution in (16, 18, 20):
    counts[resolution] = [
        float(value["leaderLinkCount"])
        for value in samples[resolution]["directions"]
    ]
    check(
        f"c{resolution} leader total closure",
        sum(counts[resolution]) == samples[resolution]["totalLeaderBoundaryLinkCount"],
    )

density = {resolution: sum(values) / resolution**2 for resolution, values in counts.items()}
probability = {
    resolution: [value / sum(values) for value in values]
    for resolution, values in counts.items()
}
areal = {
    resolution: [value / resolution**2 for value in values]
    for resolution, values in counts.items()
}
floor = prereg["decisionRule"]["denominatorFloor"]
d_mid = 0.5 * (density[16] + density[20])
d_curve = abs(density[18] - d_mid) / max(abs(density[20] - density[16]), floor)
p_mid = [0.5 * (left + right) for left, right in zip(probability[16], probability[20])]
p_numerator = 0.5 * sum(abs(value - midpoint) for value, midpoint in zip(probability[18], p_mid))
p_denominator = 0.5 * sum(abs(right - left) for left, right in zip(probability[16], probability[20]))
p_curve = p_numerator / max(p_denominator, floor)
a_mid = [0.5 * (left + right) for left, right in zip(areal[16], areal[20])]
a_numerator = sum(weight * abs(value - midpoint) for weight, value, midpoint in zip(weights, areal[18], a_mid))
a_denominator = sum(weight * abs(right - left) for weight, left, right in zip(weights, areal[16], areal[20]))
a_curve = a_numerator / max(a_denominator, floor)
between = min(density[16], density[20]) <= density[18] <= max(density[16], density[20])
if between and max(d_curve, p_curve, a_curve) <= 0.5:
    verdict = "monotonicGeometryBridge"
elif (not between) or max(d_curve, p_curve, a_curve) >= 1.0:
    verdict = "latticePhaseAliasingSuspected"
else:
    verdict = "mixedGeometryBridge"

observed_metrics = summary["decisionMetrics"]
for name, actual in (
    ("normalizedDensityMidpointCurvature", d_curve),
    ("normalizedDirectionMidpointCurvature", p_curve),
    ("normalizedArealProfileMidpointCurvature", a_curve),
):
    check(f"independent metric {name}", math.isclose(actual, observed_metrics[name], rel_tol=1e-13, abs_tol=1e-13), {"audit": actual, "summary": observed_metrics[name]})
check("independent density interval decision", between == observed_metrics["densityBetweenEndpoints"])
check("independent classification", verdict == summary["classification"], {"audit": verdict, "summary": summary["classification"]})
for artifact in (
    ARCHIVE / "formation-flight-geometry-c18-bridge-directions.csv",
    ROOT / "Docs/Media/formation-flight-geometry-c18-bridge.png",
    ROOT / "Docs/Media/formation-flight-geometry-c18-bridge.svg",
):
    check(f"artifact exists {artifact.relative_to(ROOT)}", artifact.is_file() and artifact.stat().st_size > 0)

passed = all(value["passed"] for value in checks) and summary["passed"]
audit = {
    "schemaVersion": 1,
    "title": "Independent Formation Flight geometry-only c18 bridge audit",
    "passed": passed,
    "checkCount": len(checks),
    "passedCheckCount": sum(value["passed"] for value in checks),
    "classification": verdict,
    "independentMetrics": {
        "densityBetweenEndpoints": between,
        "normalizedDensityMidpointCurvature": d_curve,
        "normalizedDirectionMidpointCurvature": p_curve,
        "normalizedArealProfileMidpointCurvature": a_curve,
    },
    "checks": checks,
    "claimBoundary": prereg["claimBoundary"],
}
AUDIT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
print(json.dumps({
    "passed": passed,
    "checks": len(checks),
    "classification": verdict,
    "audit": str(AUDIT.relative_to(ROOT)),
}, indent=2))
if not passed:
    raise SystemExit("independent geometry bridge audit failed")

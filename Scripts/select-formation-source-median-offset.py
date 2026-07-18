#!/usr/bin/env python3
"""Select one common subcell offset nearest the c16/c18/c20 density medians."""

from __future__ import annotations

import hashlib
import json
import statistics
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ENSEMBLE = ROOT / "ValidationArtifacts/formation-flight-geometry-subcell-ensemble/formation-flight-geometry-subcell-ensemble.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-geometry-subcell-ensemble/formation-flight-geometry-subcell-ensemble-summary.json"
OUTPUT = ROOT / "ValidationArtifacts/formation-flight-subcell-source-census/median-offset-selection.json"
RESOLUTIONS = (16, 18, 20)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


report = json.loads(ENSEMBLE.read_text())
cases: dict[int, dict[tuple[float, float, float], float]] = {
    resolution: {} for resolution in RESOLUTIONS
}
for case in report["cases"]:
    resolution = int(case["chordCells"])
    if resolution not in cases:
        continue
    offset = tuple(float(value) for value in case["offsetCells"])
    cases[resolution][offset] = (
        float(case["totalLeaderBoundaryLinkCount"]) / resolution**2
    )

common_offsets = set.intersection(*(set(cases[r]) for r in RESOLUTIONS))
if len(common_offsets) != 64 or any(len(cases[r]) != 64 for r in RESOLUTIONS):
    raise SystemExit("expected the complete common 4x4x4 offset tensor")

stats = {}
for resolution in RESOLUTIONS:
    values = list(cases[resolution].values())
    stats[resolution] = {
        "mean": statistics.mean(values),
        "median": statistics.median(values),
        "sampleStandardDeviation": statistics.stdev(values),
    }

ranking = []
for offset in sorted(common_offsets):
    contributions = {}
    score = 0.0
    for resolution in RESOLUTIONS:
        density = cases[resolution][offset]
        standardized = (
            density - stats[resolution]["median"]
        ) / stats[resolution]["sampleStandardDeviation"]
        contributions[f"c{resolution}"] = {
            "leaderArealLinkDensity": density,
            "standardizedMedianDistance": standardized,
            "squaredScoreContribution": standardized**2,
        }
        score += standardized**2
    ranking.append({
        "offsetCells": list(offset),
        "selectionScore": score,
        "resolutionContributions": contributions,
    })
ranking.sort(key=lambda row: (row["selectionScore"], *row["offsetCells"]))
selected = ranking[0]
zero = next(row for row in ranking if row["offsetCells"] == [0.0, 0.0, 0.0])

output = {
    "schemaVersion": 1,
    "title": "Common median-density subcell phase selection",
    "selectionRule": "Minimize the sum over c16/c18/c20 of squared sample-SD-normalized distance from each resolution's leader areal-link-density median; break exact ties lexicographically by x, y, z.",
    "inputEnsemble": {
        "path": str(ENSEMBLE.relative_to(ROOT)),
        "sha256": digest(ENSEMBLE),
    },
    "inputSummary": {
        "path": str(SUMMARY.relative_to(ROOT)),
        "sha256": digest(SUMMARY),
    },
    "resolutionStatistics": {
        f"c{resolution}": stats[resolution]
        for resolution in RESOLUTIONS
    },
    "selected": selected,
    "legacyZeroOffset": zero,
    "selectedToLegacyScoreRatio": (
        selected["selectionScore"] / zero["selectionScore"]
    ),
    "topEightCandidates": ranking[:8],
    "candidateCount": len(ranking),
    "passed": (
        len(ranking) == 64
        and selected["selectionScore"] < zero["selectionScore"]
    ),
    "claimBoundary": "This deterministic geometry-derived selection fixes one representative common lattice phase before any translated fluid run. It does not measure aerodynamic convergence or formation benefit.",
}
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
OUTPUT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
print(json.dumps(output, indent=2, sort_keys=True))

#!/usr/bin/env python3
"""Summarize the frozen formation extrema across promoted grids."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-scout-v1.json"
REPORTS = {
    (8, "maximum"): ROOT
    / "ValidationArtifacts/formation-flight-scout-v1/y0-z3-phase0p25/formation-flight-report.json",
    (8, "minimum"): ROOT
    / "ValidationArtifacts/formation-flight-scout-v1/y0-z3-phase0p75/formation-flight-report.json",
    (12, "maximum"): ROOT
    / "ValidationArtifacts/formation-flight-promotion/c12-best-z3-phase025/formation-flight-report.json",
    (12, "minimum"): ROOT
    / "ValidationArtifacts/formation-flight-promotion/c12-minimum-z3-phase075/formation-flight-report.json",
    (16, "maximum"): ROOT
    / "ValidationArtifacts/formation-flight-promotion/c16-best-z3-phase025/formation-flight-report.json",
    (16, "minimum"): ROOT
    / "ValidationArtifacts/formation-flight-promotion/c16-minimum-z3-phase075/formation-flight-report.json",
}
OUTPUT = (
    ROOT
    / "ValidationArtifacts/formation-flight-promotion/formation-flight-refinement-summary.json"
)


def load_case(resolution: int, selection: str, path: Path) -> dict | None:
    if not path.exists():
        return None
    report_bytes = path.read_bytes()
    report = json.loads(report_bytes)
    expected_phase = 0.25 if selection == "maximum" else 0.75
    config = report["configuration"]
    if config["chordCells"] != resolution:
        raise SystemExit(f"wrong resolution in {path}")
    if config["followerOffsetChords"] != [0, 0, -3]:
        raise SystemExit(f"wrong offset in {path}")
    if abs(config["followerPhaseOffsetCycles"] - expected_phase) > 1e-12:
        raise SystemExit(f"wrong phase in {path}")
    if not report["gates"]["passed"]:
        raise SystemExit(f"failed promoted case: {path}")
    return {
        "chordCells": resolution,
        "selection": selection,
        "phaseOffsetCycles": expected_phase,
        "followerPositivePowerSavingFraction": report[
            "followerPositivePowerSavingFraction"
        ],
        "systemPositivePowerChangeFraction": report[
            "systemPositivePowerChangeFraction"
        ],
        "periodicPowerDifference": report["gates"][
            "maximumRelativePeriodicPowerDifference"
        ],
        "forceClosure": report["gates"][
            "maximumRelativeForceClosureResidual"
        ],
        "torqueClosure": report["gates"][
            "maximumRelativeTorqueClosureResidual"
        ],
        "runtimeSeconds": report["runtimeSeconds"],
        "reportSHA256": hashlib.sha256(report_bytes).hexdigest(),
        "report": str(path.relative_to(ROOT)),
    }


def main() -> int:
    cases = [
        case
        for key, path in REPORTS.items()
        if (case := load_case(*key, path)) is not None
    ]
    by_key = {(case["chordCells"], case["selection"]): case for case in cases}
    contrasts = []
    for resolution in (8, 12, 16):
        maximum = by_key.get((resolution, "maximum"))
        minimum = by_key.get((resolution, "minimum"))
        if maximum and minimum:
            contrasts.append(
                {
                    "chordCells": resolution,
                    "bestMinusMinimumPercentagePoints": 100
                    * (
                        maximum["followerPositivePowerSavingFraction"]
                        - minimum["followerPositivePowerSavingFraction"]
                    ),
                }
            )
    contrast_changes = []
    contrasts_by_grid = {
        item["chordCells"]: item["bestMinusMinimumPercentagePoints"]
        for item in contrasts
    }
    for coarse, fine in ((8, 12), (12, 16)):
        if coarse in contrasts_by_grid and fine in contrasts_by_grid:
            delta = contrasts_by_grid[fine] - contrasts_by_grid[coarse]
            contrast_changes.append(
                {
                    "coarseChordCells": coarse,
                    "fineChordCells": fine,
                    "absoluteChangePercentagePoints": delta,
                    "relativeChange": abs(delta)
                    / max(abs(contrasts_by_grid[fine]), 1e-12),
                }
            )
    best_changes = []
    for coarse, fine in ((8, 12), (12, 16)):
        a = by_key.get((coarse, "maximum"))
        b = by_key.get((fine, "maximum"))
        if a and b:
            delta = (
                b["followerPositivePowerSavingFraction"]
                - a["followerPositivePowerSavingFraction"]
            )
            best_changes.append(
                {
                    "coarseChordCells": coarse,
                    "fineChordCells": fine,
                    "absoluteChangePercentagePoints": 100 * delta,
                    "relativeChange": abs(delta)
                    / max(
                        abs(b["followerPositivePowerSavingFraction"]),
                        1e-12,
                    ),
                }
            )

    prereg_bytes = PREREG.read_bytes()
    c16_complete = all((16, selection) in by_key for selection in ("maximum", "minimum"))
    output = {
        "schemaVersion": 1,
        "preregistrationSHA256": hashlib.sha256(prereg_bytes).hexdigest(),
        "cases": cases,
        "phaseContrasts": contrasts,
        "phaseContrastGridChanges": contrast_changes,
        "bestCellGridChanges": best_changes,
        "allAvailableCasesPassed": True,
        "c16ExtremaComplete": c16_complete,
        "quantitativeFormationClaimAuthorized": False,
        "classification": (
            "extrema runs complete; absolute saving and phase contrast remain grid-dependent, so no quantitative formation claim is authorized"
            if c16_complete
            else "best-cell refinement advanced; c16 minimum remains open"
        ),
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps(output, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

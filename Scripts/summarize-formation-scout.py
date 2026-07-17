#!/usr/bin/env python3
"""Fail-closed aggregation for the preregistered formation position/phase map."""

from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
from pathlib import Path


def canonical(value: float) -> float:
    return round(float(value), 12)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("root", type=Path)
    parser.add_argument("--mode", choices=("quick", "full"), default="quick")
    parser.add_argument(
        "--preregistration",
        type=Path,
        default=Path("ValidationInputs/formation-flight-scout-v1.json"),
    )
    args = parser.parse_args()

    prereg_bytes = args.preregistration.read_bytes()
    prereg = json.loads(prereg_bytes)
    matrix = prereg["quickScreen" if args.mode == "quick" else "fullScreen"]
    expected = {
        (canonical(x), canonical(y), canonical(z), canonical(phase))
        for x, y, z, phase in itertools.product(
            matrix["xOffsetsChords"],
            matrix["yOffsetsChords"],
            matrix["zOffsetsChords"],
            matrix["phaseOffsetsCycles"],
        )
    }

    rows: list[dict[str, object]] = []
    seen: set[tuple[float, float, float, float]] = set()
    for path in sorted(args.root.glob("*/formation-flight-report.json")):
        report = json.loads(path.read_text())
        config = report["configuration"]
        offset = config["followerOffsetChords"]
        key = tuple(
            canonical(value)
            for value in (*offset, config["followerPhaseOffsetCycles"])
        )
        if key not in expected:
            continue
        if key in seen:
            raise SystemExit(f"duplicate formation cell: {key}")
        seen.add(key)
        gates = report["gates"]
        rows.append(
            {
                "xChords": key[0],
                "yChords": key[1],
                "zChords": key[2],
                "phaseOffsetCycles": key[3],
                "followerPositivePowerSavingFraction": report[
                    "followerPositivePowerSavingFraction"
                ],
                "leaderPositivePowerChangeFraction": report[
                    "leaderPositivePowerChangeFraction"
                ],
                "systemPositivePowerChangeFraction": report[
                    "systemPositivePowerChangeFraction"
                ],
                "forceClosure": gates["maximumRelativeForceClosureResidual"],
                "torqueClosure": gates["maximumRelativeTorqueClosureResidual"],
                "periodicPowerDifference": gates[
                    "maximumRelativePeriodicPowerDifference"
                ],
                "overlapVoxelSamples": report["overlapVoxelSamples"],
                "passed": gates["passed"],
                "report": str(path),
            }
        )

    missing = expected - seen
    if missing:
        raise SystemExit(
            f"formation scout incomplete: {len(missing)} preregistered cells missing"
        )
    failed = [row for row in rows if not row["passed"]]
    if failed:
        raise SystemExit(f"formation scout has {len(failed)} failed cells")

    saving_key = lambda row: float(row["followerPositivePowerSavingFraction"])
    largest_saving = max(rows, key=saving_key)
    largest_penalty = min(rows, key=saving_key)
    nearest_neutral = min(rows, key=lambda row: abs(saving_key(row)))
    summary = {
        "schemaVersion": 1,
        "mode": args.mode,
        "preregistrationSHA256": hashlib.sha256(prereg_bytes).hexdigest(),
        "caseCount": len(rows),
        "allCasesPassed": True,
        "promotionCandidates": {
            "largestSaving": largest_saving,
            "nearestNeutral": nearest_neutral,
            "largestPenalty": largest_penalty,
        },
        "cases": rows,
        "claimBoundary": prereg["claimBoundary"],
    }
    args.root.mkdir(parents=True, exist_ok=True)
    (args.root / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n"
    )
    with (args.root / "summary.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    print(
        json.dumps(
            {
                "caseCount": len(rows),
                "largestSaving": saving_key(largest_saving),
                "nearestNeutral": saving_key(nearest_neutral),
                "largestPenalty": saving_key(largest_penalty),
            },
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

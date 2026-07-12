#!/usr/bin/env python3
"""Grid-convergence check for the independent D3Q19 TRT reference."""

from __future__ import annotations

import json
import math
import sys

import numpy as np

from shear_wave_reference import run_case


def main() -> int:
    resolutions = (12, 16, 24, 32)
    base_resolution = 32
    base_steps = 120
    rows: list[dict[str, float | int]] = []

    for resolution in resolutions:
        # Keep nu * t / N^2 approximately fixed so all grids represent the
        # same nondimensional decay time for the one-period shear mode.
        steps = max(1, round(base_steps * (resolution / base_resolution) ** 2))
        result = run_case(resolution=resolution, steps=steps)
        rows.append(
            {
                "resolution": resolution,
                "steps": steps,
                "relative_decay_error": result.relative_decay_error,
                "relative_mass_drift": result.relative_mass_drift,
            }
        )

    spacing = np.asarray([1.0 / row["resolution"] for row in rows])
    errors = np.asarray([row["relative_decay_error"] for row in rows])
    order = float(np.polyfit(np.log(spacing), np.log(errors), 1)[0])
    max_mass_drift = max(float(row["relative_mass_drift"]) for row in rows)

    payload = {
        "estimated_order": order,
        "max_relative_mass_drift": max_mass_drift,
        "cases": rows,
    }
    print(json.dumps(payload, indent=2, sort_keys=True))

    passed = order >= 1.8 and max_mass_drift < 1.0e-6
    if not passed:
        print("shear-wave convergence validation failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

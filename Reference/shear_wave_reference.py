#!/usr/bin/env python3
"""Independent D3Q19 TRT shear-wave decay reference.

This program intentionally does not import or execute Swift/Metal code. It
checks the same equilibrium and TRT equations with NumPy on a periodic grid.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
from dataclasses import dataclass

import numpy as np

C = np.asarray(
    [
        (0, 0, 0),
        (1, 0, 0), (-1, 0, 0),
        (0, 1, 0), (0, -1, 0),
        (0, 0, 1), (0, 0, -1),
        (1, 1, 0), (-1, -1, 0),
        (1, -1, 0), (-1, 1, 0),
        (1, 0, 1), (-1, 0, -1),
        (1, 0, -1), (-1, 0, 1),
        (0, 1, 1), (0, -1, -1),
        (0, 1, -1), (0, -1, 1),
    ],
    dtype=np.int32,
)
W = np.asarray(
    [
        1 / 3,
        1 / 18, 1 / 18,
        1 / 18, 1 / 18,
        1 / 18, 1 / 18,
        1 / 36, 1 / 36,
        1 / 36, 1 / 36,
        1 / 36, 1 / 36,
        1 / 36, 1 / 36,
        1 / 36, 1 / 36,
        1 / 36, 1 / 36,
    ],
    dtype=np.float64,
)
OPPOSITE = np.asarray(
    [0, 2, 1, 4, 3, 6, 5, 8, 7, 10, 9, 12, 11, 14, 13, 16, 15, 18, 17],
    dtype=np.int32,
)


@dataclass(frozen=True)
class Result:
    resolution: int
    steps: int
    viscosity: float
    tau_plus: float
    tau_minus: float
    initial_amplitude: float
    measured_amplitude: float
    analytic_amplitude: float
    relative_decay_error: float
    relative_mass_drift: float


def equilibrium(rho: np.ndarray, velocity: np.ndarray) -> np.ndarray:
    cu = np.einsum("qd,dxyz->qxyz", C.astype(np.float64), velocity)
    u2 = np.einsum("dxyz,dxyz->xyz", velocity, velocity)
    return W[:, None, None, None] * rho[None, ...] * (
        1.0 + 3.0 * cu + 4.5 * cu * cu - 1.5 * u2[None, ...]
    )


def moments(populations: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    rho = populations.sum(axis=0)
    momentum = np.einsum("qd,qxyz->dxyz", C.astype(np.float64), populations)
    return rho, momentum / rho[None, ...]


def stream(populations: np.ndarray) -> np.ndarray:
    streamed = np.empty_like(populations)
    for q, direction in enumerate(C):
        streamed[q] = np.roll(
            populations[q],
            shift=tuple(int(value) for value in direction),
            axis=(0, 1, 2),
        )
    return streamed


def collide_trt(
    populations: np.ndarray,
    rho: np.ndarray,
    velocity: np.ndarray,
    omega_plus: float,
    omega_minus: float,
) -> np.ndarray:
    eq = equilibrium(rho, velocity)
    opposite_f = populations[OPPOSITE]
    opposite_eq = eq[OPPOSITE]
    symmetric = 0.5 * (populations + opposite_f)
    antisymmetric = 0.5 * (populations - opposite_f)
    eq_symmetric = 0.5 * (eq + opposite_eq)
    eq_antisymmetric = 0.5 * (eq - opposite_eq)
    return (
        populations
        - omega_plus * (symmetric - eq_symmetric)
        - omega_minus * (antisymmetric - eq_antisymmetric)
    )


def mode_amplitude(velocity_x: np.ndarray) -> float:
    resolution = velocity_x.shape[1]
    y = np.arange(resolution, dtype=np.float64)
    sine = np.sin(2.0 * np.pi * y / resolution)
    profile = velocity_x.mean(axis=(0, 2))
    return float(2.0 * np.dot(profile, sine) / resolution)


def run_case(
    resolution: int = 32,
    steps: int = 120,
    viscosity: float = 0.03,
    initial_amplitude: float = 0.01,
    magic_parameter: float = 3.0 / 16.0,
) -> Result:
    if resolution < 8 or steps < 1 or viscosity <= 0 or initial_amplitude <= 0:
        raise ValueError("Invalid reference-case parameters")

    tau_plus = 0.5 + 3.0 * viscosity
    tau_minus = 0.5 + magic_parameter / (tau_plus - 0.5)
    omega_plus = 1.0 / tau_plus
    omega_minus = 1.0 / tau_minus

    rho = np.ones((resolution, resolution, resolution), dtype=np.float64)
    velocity = np.zeros((3, resolution, resolution, resolution), dtype=np.float64)
    y = np.arange(resolution, dtype=np.float64)
    velocity[0, :, :, :] = initial_amplitude * np.sin(
        2.0 * np.pi * y / resolution
    )[None, :, None]

    populations = equilibrium(rho, velocity)
    mass_initial = float(populations.sum())
    amplitude_initial_measured = mode_amplitude(velocity[0])

    for _ in range(steps):
        streamed = stream(populations)
        rho, velocity = moments(streamed)
        populations = collide_trt(
            streamed,
            rho,
            velocity,
            omega_plus,
            omega_minus,
        )

    rho, velocity = moments(populations)
    mass_final = float(rho.sum())
    measured = mode_amplitude(velocity[0])
    wave_number = 2.0 * math.pi / resolution
    analytic = amplitude_initial_measured * math.exp(
        -viscosity * wave_number**2 * steps
    )
    relative_error = abs(measured - analytic) / abs(analytic)
    mass_drift = abs(mass_final - mass_initial) / abs(mass_initial)

    return Result(
        resolution=resolution,
        steps=steps,
        viscosity=viscosity,
        tau_plus=tau_plus,
        tau_minus=tau_minus,
        initial_amplitude=amplitude_initial_measured,
        measured_amplitude=measured,
        analytic_amplitude=analytic,
        relative_decay_error=relative_error,
        relative_mass_drift=mass_drift,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--resolution", type=int, default=32)
    parser.add_argument("--steps", type=int, default=120)
    parser.add_argument("--viscosity", type=float, default=0.03)
    parser.add_argument("--amplitude", type=float, default=0.01)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    result = run_case(
        resolution=args.resolution,
        steps=args.steps,
        viscosity=args.viscosity,
        initial_amplitude=args.amplitude,
    )
    payload = result.__dict__

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        for key, value in payload.items():
            print(f"{key}: {value}")

    passed = (
        result.relative_mass_drift < 1.0e-6
        and result.relative_decay_error < 0.03
    )
    if not passed:
        print("reference validation failed", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

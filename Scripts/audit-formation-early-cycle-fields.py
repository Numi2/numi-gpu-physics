#!/usr/bin/env python3
"""Independently audit the early-cycle field discriminator from raw slices."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np
from scipy.ndimage import binary_dilation, distance_transform_edt, map_coordinates


ROOT = Path(__file__).resolve().parent.parent
REPLAY_ROOT = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
SUMMARY = REPLAY_ROOT / "formation-flight-early-cycle-field-summary.json"
OUTPUT = REPLAY_ROOT / "formation-flight-early-cycle-field-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def arrays(path: Path) -> tuple[dict, np.ndarray, np.ndarray, np.ndarray]:
    data = load(path)
    shape = (data["height"], data["width"])
    vertical = np.asarray(data["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape)
    vorticity = np.asarray(data["vorticityMagnitudePerSecond"], dtype=float).reshape(shape)
    owner = np.asarray(data["ownerMask"], dtype=np.uint8).reshape(shape)
    return data, vertical, vorticity, owner


def resample(values: np.ndarray, shape: tuple[int, int], order: int) -> np.ndarray:
    source_height, source_width = values.shape
    target_height, target_width = shape
    z = (np.arange(target_height) + 0.5) * source_height / target_height - 0.5
    x = (np.arange(target_width) + 0.5) * source_width / target_width - 0.5
    zz, xx = np.meshgrid(z, x, indexing="ij")
    return map_coordinates(
        values,
        (zz, xx),
        order=order,
        mode="nearest",
        prefilter=False,
    )


def rms(values: np.ndarray) -> float:
    return float(np.sqrt(np.mean(values * values)))


def correlation(lhs: np.ndarray, rhs: np.ndarray) -> float:
    lhs = lhs - np.mean(lhs)
    rhs = rhs - np.mean(rhs)
    denominator = float(np.sqrt(np.sum(lhs * lhs) * np.sum(rhs * rhs)))
    return float(np.sum(lhs * rhs) / denominator) if denominator > 0 else 0.0


def main() -> int:
    summary = load(SUMMARY)
    checks: list[dict] = []

    def check(name: str, passed: bool, detail: str) -> None:
        checks.append({"name": name, "passed": bool(passed), "detail": detail})

    preregistration_path = ROOT / summary["preregistration"]["path"]
    check(
        "preregistration SHA",
        sha256(preregistration_path) == summary["preregistration"]["sha256"],
        summary["preregistration"]["sha256"],
    )
    for resolution in (16, 20):
        replay = summary["replays"][f"c{resolution}"]
        report_path = ROOT / replay["reportPath"]
        index_path = ROOT / replay["indexPath"]
        check(
            f"c{resolution} replay report SHA",
            sha256(report_path) == replay["reportSHA256"],
            replay["reportSHA256"],
        )
        check(
            f"c{resolution} field index SHA",
            sha256(index_path) == replay["indexSHA256"],
            replay["indexSHA256"],
        )
        report = load(report_path)
        check(
            f"c{resolution} replay gates",
            report["gates"]["passed"]
            and report["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] <= 1e-6,
            str(report["gates"]),
        )

    aggregate_total = 0.0
    aggregate_near = 0.0
    independent_phase_results: list[dict] = []
    metric_names = (
        "verticalVelocityNormalizedRMSDifference",
        "vorticityNormalizedRMSDifference",
        "verticalVelocitySpatialCorrelation",
        "vorticitySpatialCorrelation",
        "nearBoundaryResidualEnergyFraction",
    )
    for phase in summary["phaseResults"]:
        coarse_path = ROOT / phase["c16SlicePath"]
        fine_path = ROOT / phase["c20SlicePath"]
        check(
            f"phase {phase['targetFollowerPhase']:.3f} c16 slice SHA",
            sha256(coarse_path) == phase["c16SliceSHA256"],
            phase["c16SliceSHA256"],
        )
        check(
            f"phase {phase['targetFollowerPhase']:.3f} c20 slice SHA",
            sha256(fine_path) == phase["c20SliceSHA256"],
            phase["c20SliceSHA256"],
        )
        coarse_data, w16, omega16, owner16 = arrays(coarse_path)
        fine_data, w20, omega20, owner20 = arrays(fine_path)
        check(
            f"phase {phase['targetFollowerPhase']:.3f} finite fields",
            bool(
                np.all(np.isfinite(w16))
                and np.all(np.isfinite(omega16))
                and np.all(np.isfinite(w20))
                and np.all(np.isfinite(omega20))
            ),
            f"c{coarse_data['chordCells']}/c{fine_data['chordCells']}",
        )
        shape = w20.shape
        w16_common = resample(w16, shape, order=1)
        omega16_common = resample(omega16, shape, order=1)
        owner16_common = resample(owner16.astype(float), shape, order=0) > 0.5
        owner_union = owner16_common | (owner20 > 0)
        valid = ~binary_dilation(owner_union, structure=np.ones((3, 3), dtype=bool))
        near = (distance_transform_edt(~owner_union) <= 0.5 * fine_data["chordCells"]) & valid
        delta_w = w20 - w16_common
        delta_omega = omega20 - omega16_common
        w_scale = max(rms(w20[valid]), rms(w16_common[valid]), 1e-12)
        omega_scale = max(rms(omega20[valid]), rms(omega16_common[valid]), 1e-12)
        energy = (delta_w / w_scale) ** 2 + (delta_omega / omega_scale) ** 2
        total = float(np.sum(energy[valid]))
        near_total = float(np.sum(energy[near]))
        x_coordinates = (np.arange(shape[1]) + 0.5) / fine_data["chordCells"] - 0.5 * shape[1] / fine_data["chordCells"]
        z_coordinates = (np.arange(shape[0]) + 0.5) / fine_data["chordCells"] - 0.5 * shape[0] / fine_data["chordCells"]
        x_grid, z_grid = np.meshgrid(x_coordinates, z_coordinates)

        def location(mask: np.ndarray) -> dict:
            weights = np.where(mask, energy, 0)
            weight_total = float(np.sum(weights))
            peak = np.unravel_index(int(np.argmax(weights)), weights.shape)
            return {
                "centroidXChords": float(np.sum(weights * x_grid) / weight_total),
                "centroidZChords": float(np.sum(weights * z_grid) / weight_total),
                "peakXChords": float(x_grid[peak]),
                "peakZChords": float(z_grid[peak]),
            }
        independent = {
            "verticalVelocityNormalizedRMSDifference": rms(delta_w[valid]) / w_scale,
            "vorticityNormalizedRMSDifference": rms(delta_omega[valid]) / omega_scale,
            "verticalVelocitySpatialCorrelation": correlation(w16_common[valid], w20[valid]),
            "vorticitySpatialCorrelation": correlation(omega16_common[valid], omega20[valid]),
            "nearBoundaryResidualEnergyFraction": near_total / total if total > 0 else 0.0,
        }
        for name in metric_names:
            difference = abs(independent[name] - phase[name])
            check(
                f"phase {phase['targetFollowerPhase']:.3f} {name}",
                math.isclose(independent[name], phase[name], rel_tol=1e-10, abs_tol=1e-12),
                f"independent={independent[name]:.16g} reported={phase[name]:.16g} difference={difference:.3e}",
            )
        aggregate_total += total
        aggregate_near += near_total
        independent_phase_results.append(
            {
                "targetFollowerPhase": phase["targetFollowerPhase"],
                "nearEnergy": near_total,
                "wakeEnergy": total - near_total,
                "nearLocation": location(near),
                "wakeLocation": location(valid & ~near),
            }
        )

    near_fraction = aggregate_near / aggregate_total if aggregate_total > 0 else 0.0
    classification = (
        "nearBoundary"
        if near_fraction >= 0.60
        else "wakeTransport"
        if near_fraction <= 0.40
        else "mixed"
    )
    check(
        "aggregate near-boundary fraction",
        math.isclose(
            near_fraction,
            summary["aggregate"]["nearBoundaryResidualEnergyFraction"],
            rel_tol=1e-10,
            abs_tol=1e-12,
        ),
        f"independent={near_fraction:.16g}",
    )
    check(
        "mechanism classification",
        classification == summary["aggregate"]["classification"],
        classification,
    )
    for probe_name, energy_key, location_key in (
        ("nearBoundary", "nearEnergy", "nearLocation"),
        ("wake", "wakeEnergy", "wakeLocation"),
    ):
        independent_probe = max(
            independent_phase_results,
            key=lambda result: result[energy_key],
        )
        reported_probe = summary["selectedProbes"][probe_name]
        check(
            f"{probe_name} probe phase",
            independent_probe["targetFollowerPhase"]
            == reported_probe["targetFollowerPhase"],
            str(independent_probe["targetFollowerPhase"]),
        )
        for coordinate, value in independent_probe[location_key].items():
            check(
                f"{probe_name} probe {coordinate}",
                math.isclose(
                    value,
                    reported_probe["location"][coordinate],
                    rel_tol=1e-10,
                    abs_tol=1e-12,
                ),
                f"independent={value:.16g}",
            )
    passed = all(item["passed"] for item in checks)
    artifact = {
        "schemaVersion": 1,
        "method": "independent scipy map_coordinates and binary_dilation reconstruction from raw c16/c20 slice JSON",
        "sourceSummaryPath": str(SUMMARY.relative_to(ROOT)),
        "sourceSummarySHA256": sha256(SUMMARY),
        "checkCount": len(checks),
        "checks": checks,
        "independentNearBoundaryResidualEnergyFraction": near_fraction,
        "independentClassification": classification,
        "passed": passed,
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({
        "audit": str(OUTPUT.relative_to(ROOT)),
        "checkCount": len(checks),
        "classification": classification,
        "passed": passed,
    }, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

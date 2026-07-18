#!/usr/bin/env python3
"""Independent integer-slice audit of the wake transport discriminator."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREGISTRATION = ROOT / "ValidationInputs/formation-flight-wake-transport-discriminator-v1.json"
EARLY_ROOT = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-wake-transport/formation-flight-wake-transport-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-wake-transport/formation-flight-wake-transport-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bilinear(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_height, source_width = values.shape
    target_height, target_width = shape
    z = (np.arange(target_height) + 0.5) * source_height / target_height - 0.5
    x = (np.arange(target_width) + 0.5) * source_width / target_width - 0.5
    z0 = np.clip(np.floor(z).astype(int), 0, source_height - 1)
    x0 = np.clip(np.floor(x).astype(int), 0, source_width - 1)
    z1 = np.clip(z0 + 1, 0, source_height - 1)
    x1 = np.clip(x0 + 1, 0, source_width - 1)
    wz = (z - z0)[:, None]
    wx = (x - x0)[None, :]
    return (1 - wz) * (1 - wx) * values[z0[:, None], x0[None, :]] + (1 - wz) * wx * values[z0[:, None], x1[None, :]] + wz * (1 - wx) * values[z1[:, None], x0[None, :]] + wz * wx * values[z1[:, None], x1[None, :]]


def nearest(values: np.ndarray, shape: tuple[int, int]) -> np.ndarray:
    source_height, source_width = values.shape
    target_height, target_width = shape
    z = np.clip(np.floor((np.arange(target_height) + 0.5) * source_height / target_height).astype(int), 0, source_height - 1)
    x = np.clip(np.floor((np.arange(target_width) + 0.5) * source_width / target_width).astype(int), 0, source_width - 1)
    return values[z[:, None], x[None, :]]


def dilate(mask: np.ndarray) -> np.ndarray:
    padded = np.pad(mask, 1, mode="constant")
    result = np.zeros_like(mask, dtype=bool)
    for dz in range(3):
        for dx in range(3):
            result |= padded[dz : dz + mask.shape[0], dx : dx + mask.shape[1]]
    return result


def integer_shift(values: np.ndarray, dz: int, dx: int, fill: float) -> np.ndarray:
    output = np.full(values.shape, fill, dtype=values.dtype)
    source_z = slice(max(0, -dz), min(values.shape[0], values.shape[0] - dz))
    target_z = slice(max(0, dz), min(values.shape[0], values.shape[0] + dz))
    source_x = slice(max(0, -dx), min(values.shape[1], values.shape[1] - dx))
    target_x = slice(max(0, dx), min(values.shape[1], values.shape[1] + dx))
    output[target_z, target_x] = values[source_z, source_x]
    return output


def phase_data(resolution: int, target: float) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    directory = EARLY_ROOT / f"c{resolution}-best-z3-phase025"
    replay = load(directory / "formation-flight-field-replay-report.json")
    index = load(directory / "formation-flight-flow-slices/index.json")
    matches = [entry for entry in index["entries"] if abs(entry["followerPhase"] - target) <= 0.51 / replay["cycleSteps"]]
    if len(matches) != 1:
        raise AssertionError(f"missing c{resolution} phase {target}")
    data = load(directory / "formation-flight-flow-slices" / matches[0]["file"])
    shape = (data["height"], data["width"])
    return (
        np.asarray(data["verticalVelocityMetersPerSecond"], dtype=float).reshape(shape),
        np.asarray(data["vorticityMagnitudePerSecond"], dtype=float).reshape(shape),
        np.asarray(data["ownerMask"], dtype=np.uint8).reshape(shape),
    )


def main() -> int:
    prereg = load(PREREGISTRATION)
    summary = load(SUMMARY)
    checks = []

    def check(name: str, passed: bool, evidence: object) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    check("preregistered", prereg["preregisteredBeforeAnalysis"], True)
    check("summary preregistration SHA", summary["preregistration"]["sha256"] == sha256(PREREGISTRATION), summary["preregistration"]["sha256"])
    for locked in prereg["lockedInputs"]:
        actual = sha256(ROOT / locked["path"])
        check(f"locked input {locked['path']}", actual == locked["sha256"], actual)

    reconstructed = []
    chord_cells = 20
    maximum = int(round(prereg["alignmentSearch"]["maximumAbsoluteShiftChords"] * chord_cells))
    increment = int(round(prereg["alignmentSearch"]["shiftIncrementChords"] * chord_cells))
    candidates = list(range(-maximum, maximum + 1, increment))
    for target in prereg["followerLocalPhases"]:
        w16_raw, omega16_raw, owner16_raw = phase_data(16, target)
        w20, omega20, owner20 = phase_data(20, target)
        shape = w20.shape
        w16 = bilinear(w16_raw, shape)
        omega16 = bilinear(omega16_raw, shape)
        owner16 = nearest(owner16_raw, shape)
        x = (np.arange(shape[1]) + 0.5) / chord_cells - 0.5 * shape[1] / chord_cells
        z = (np.arange(shape[0]) + 0.5) / chord_cells - 0.5 * shape[0] / chord_cells
        x_grid, z_grid = np.meshgrid(x, z)
        region = prereg["wakeRegionChords"]
        fixed = (np.abs(x_grid - region["centerX"]) <= region["halfWidthX"]) & (np.abs(z_grid - region["centerZ"]) <= region["halfWidthZ"]) & ~dilate(owner20 > 0)
        valid16 = ~dilate(owner16 > 0)
        for dz in candidates:
            for dx in candidates:
                fixed &= integer_shift(valid16.astype(np.uint8), dz, dx, 0) > 0
        w_scale = max(float(np.sqrt(np.mean(w16[fixed] ** 2))), float(np.sqrt(np.mean(w20[fixed] ** 2))), 1e-12)
        omega_scale = max(float(np.sqrt(np.mean(omega16[fixed] ** 2))), float(np.sqrt(np.mean(omega20[fixed] ** 2))), 1e-12)
        scored = []
        for dz in candidates:
            for dx in candidates:
                sw = integer_shift(w16, dz, dx, np.nan)
                so = integer_shift(omega16, dz, dx, np.nan)
                energy = float(np.sum(((w20[fixed] - sw[fixed]) / w_scale) ** 2 + ((omega20[fixed] - so[fixed]) / omega_scale) ** 2))
                scored.append((energy, abs(dz) + abs(dx), abs(dz), abs(dx), dz, dx))
        scored.sort()
        best = scored[0]
        base = next(item[0] for item in scored if item[4] == 0 and item[5] == 0)
        reduction = (base - best[0]) / base if base > 0 else 0.0
        reported = min(summary["phaseResults"], key=lambda row: abs(row["targetFollowerPhase"] - target))
        check(f"phase {target} common cells", int(np.count_nonzero(fixed)) == reported["commonWakeCellCount"], int(np.count_nonzero(fixed)))
        check(f"phase {target} base energy", math.isclose(base, reported["unshiftedNormalizedResidualEnergy"], rel_tol=2e-10, abs_tol=2e-10), base)
        check(f"phase {target} aligned energy", math.isclose(best[0], reported["alignedNormalizedResidualEnergy"], rel_tol=2e-10, abs_tol=2e-10), best[0])
        check(f"phase {target} x shift", best[5] == reported["bestShiftXCells"], best[5])
        check(f"phase {target} z shift", best[4] == reported["bestShiftZCells"], best[4])
        check(f"phase {target} reduction", math.isclose(reduction, reported["residualEnergyReductionFraction"], rel_tol=2e-10, abs_tol=2e-10), reduction)
        reconstructed.append((base, best[0], best[5] / chord_cells, best[4] / chord_cells))

    unshifted = sum(item[0] for item in reconstructed)
    aligned = sum(item[1] for item in reconstructed)
    reduction = (unshifted - aligned) / unshifted
    aggregate = summary["aggregate"]
    check("aggregate unshifted", math.isclose(unshifted, aggregate["unshiftedNormalizedResidualEnergy"], rel_tol=2e-10), unshifted)
    check("aggregate aligned", math.isclose(aligned, aggregate["alignedNormalizedResidualEnergy"], rel_tol=2e-10), aligned)
    check("aggregate reduction", math.isclose(reduction, aggregate["residualEnergyReductionFraction"], rel_tol=2e-10), reduction)
    high = prereg["decisionRule"]["displacementDominatedMinimumReductionFraction"]
    low = prereg["decisionRule"]["amplitudeDiffusionDominatedMaximumReductionFraction"]
    classification = "displacementDominated" if reduction >= high else ("amplitudeDiffusionDominated" if reduction <= low else "mixedTransportAmplitude")
    check("classification", classification == summary["classification"], classification)
    check("quantitative claim unauthorized", summary["quantitativeFormationClaimAuthorized"] is False, summary["quantitativeFormationClaimAuthorized"])
    passed = all(item["passed"] for item in checks)
    artifact = {
        "schemaVersion": 1,
        "summaryPath": str(SUMMARY.relative_to(ROOT)),
        "summarySHA256": sha256(SUMMARY),
        "checkCount": len(checks),
        "checks": checks,
        "classification": classification,
        "allChecksPassed": passed,
    }
    AUDIT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"audit": str(AUDIT.relative_to(ROOT)), "checkCount": len(checks), "classification": classification, "passed": passed}, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

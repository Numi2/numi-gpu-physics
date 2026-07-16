#!/usr/bin/env python3
"""Inspect a selectively acquired Deetjen dove flight.

This is an independent conversion preflight. It verifies the extracted member
locks, inventories MATLAB variables, reconstructs kinematics/force timing, and
summarizes the processed surface without generating a BirdFlow input.

SciPy and NumPy are required because the published source uses MATLAB v5 files.
"""

from __future__ import annotations

import argparse
import binascii
import hashlib
import json
import math
from pathlib import Path

try:
    import numpy as np
    from scipy.io import loadmat, whosmat
except ImportError as error:
    raise SystemExit(
        "inspect-dove-benchmark.py requires NumPy and SciPy: " + str(error)
    ) from error


DEFAULT_AUDIT = Path("ValidationArtifacts/deetjen-dove-source-qualification.json")
CHUNK_BYTES = 4 * 1024 * 1024


def fail(message: str) -> None:
    raise SystemExit(message)


def extracted_path(root: Path, archive_path: str) -> Path:
    path = Path(archive_path)
    if path.parts[0] != "DoveMuscles_DataCode" or ".." in path.parts:
        fail(f"unsafe archive member path: {archive_path}")
    return root.joinpath(*path.parts[1:])


def file_digests(path: Path) -> tuple[int, str, str]:
    crc = 0
    sha256 = hashlib.sha256()
    size = 0
    with path.open("rb") as source:
        while True:
            chunk = source.read(CHUNK_BYTES)
            if not chunk:
                break
            size += len(chunk)
            crc = binascii.crc32(chunk, crc)
            sha256.update(chunk)
    return size, f"{crc & 0xFFFFFFFF:08x}", sha256.hexdigest()


def variable_inventory(path: Path) -> dict[str, list[int]]:
    return {name: list(shape) for name, shape, _ in whosmat(path)}


def require_shapes(path: Path, expected: dict[str, list[int]]) -> dict:
    inventory = variable_inventory(path)
    for name, shape in expected.items():
        if name not in inventory:
            fail(f"missing MATLAB variable {name} in {path}")
        if inventory[name] != shape:
            fail(
                f"MATLAB shape changed for {name} in {path}: "
                f"expected {shape}, found {inventory[name]}"
            )
    return inventory


def nearest_indices(samples: np.ndarray, targets: np.ndarray) -> np.ndarray:
    upper = np.searchsorted(samples, targets, side="left")
    upper = np.clip(upper, 0, len(samples) - 1)
    lower = np.clip(upper - 1, 0, len(samples) - 1)
    choose_upper = np.abs(samples[upper] - targets) < np.abs(samples[lower] - targets)
    return np.where(choose_upper, upper, lower)


def finite_bounds(array: np.ndarray) -> list[float]:
    finite = np.asarray(array)[np.isfinite(array)]
    if not finite.size:
        fail("surface array unexpectedly contains no finite values")
    return [float(finite.min()), float(finite.max())]


def rms(array: np.ndarray) -> float:
    return float(np.sqrt(np.mean(np.square(array))))


def force_summary(values: np.ndarray, dt: float) -> dict:
    return {
        "minimumNewtons": float(np.min(values)),
        "maximumNewtons": float(np.max(values)),
        "meanNewtons": float(np.mean(values)),
        "rmsNewtons": rms(values),
        "trapezoidalImpulseNewtonSeconds": float(np.trapezoid(values, dx=dt)),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Inspect a CRC-locked Deetjen dove benchmark subset"
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--audit", type=Path, default=DEFAULT_AUDIT)
    parser.add_argument(
        "--include-surface",
        action="store_true",
        help="require and summarize the large SurfFits member",
    )
    arguments = parser.parse_args()

    audit_bytes = arguments.audit.read_bytes()
    audit = json.loads(audit_bytes)
    selected = audit["selectedBenchmark"]
    members = selected["requiredArchiveMembers"]
    member_by_role = {member["role"]: member for member in members}
    verified_members = []
    for member in members:
        if not member["includeByDefault"] and not arguments.include_surface:
            continue
        path = extracted_path(arguments.input, member["path"])
        if not path.is_file():
            fail(f"missing extracted source member: {path}")
        size, crc32, sha256 = file_digests(path)
        if size != member["bytes"] or crc32 != member["crc32"]:
            fail(f"extracted source lock mismatch: {path}")
        expected_variables = member.get("expectedVariables")
        variables = None
        if expected_variables:
            variables = require_shapes(path, expected_variables)
        record = {
            "archivePath": member["path"],
            "bytes": size,
            "crc32": crc32,
            "sha256": sha256,
            "evidenceClass": member["evidenceClass"],
        }
        if variables is not None:
            record["matlabVariables"] = variables
        verified_members.append(record)

    def path_for_role(role: str) -> Path:
        return extracted_path(arguments.input, member_by_role[role]["path"])

    force_path = path_for_role(
        "processed aerodynamic-force-platform and muscle channels"
    )
    force = loadmat(
        force_path,
        variable_names=["AFP_t", "BodyWeight", "FxWings", "FzWings"],
        squeeze_me=True,
    )
    afp_time = np.asarray(force["AFP_t"], dtype=np.float64)
    fx_raw = np.asarray(force["FxWings"], dtype=np.float64)
    fz_raw = np.asarray(force["FzWings"], dtype=np.float64)
    force_dt = float(np.median(np.diff(afp_time)))
    reconstructed_rate = 1.0 / force_dt
    if not math.isclose(
        reconstructed_rate,
        selected["aerodynamicForceSampleRateHertz"],
        rel_tol=1.0e-9,
    ):
        fail("aerodynamic-force sample rate changed")

    first_frame = selected["analysisFrameStart"] - selected["bufferFramesPerSide"]
    last_frame = selected["analysisFrameEnd"] + selected["bufferFramesPerSide"]
    frame_numbers = np.arange(first_frame, last_frame + 1, dtype=np.int64)
    if len(frame_numbers) != selected["bufferedKinematicsFrames"]:
        fail("buffered kinematics frame count changed")
    frame_times = frame_numbers / selected["kinematicsSampleRateHertz"]
    aligned_indices = nearest_indices(afp_time, frame_times)
    timing_residuals = afp_time[aligned_indices] - frame_times
    if np.unique(aligned_indices).size != len(frame_numbers):
        fail("kinematics-to-force mapping is not one-to-one")

    high_rate_start = int(aligned_indices[0])
    high_rate_end = int(aligned_indices[-1])
    high_rate_time = afp_time[high_rate_start : high_rate_end + 1]
    high_rate_fx = fx_raw[high_rate_start : high_rate_end + 1]
    high_rate_fz = fz_raw[high_rate_start : high_rate_end + 1]
    expected_high_rate_count = (
        int(round((frame_times[-1] - frame_times[0]) / force_dt)) + 1
    )
    if len(high_rate_time) != expected_high_rate_count:
        fail("high-rate force window length changed")

    final_mass_path = path_for_role(
        "four-bird final body-mass vector used by the authors"
    )
    final_masses = np.asarray(
        loadmat(final_mass_path, variable_names=["BW"], squeeze_me=True)["BW"],
        dtype=np.float64,
    )
    bird_index = audit["remoteArchiveInventory"]["birds"].index(
        selected["birdIdentifier"]
    )

    analysis_path = path_for_role(
        "authors' synchronized derived blade-element, force, inertial, and muscle analysis product"
    )
    analysis = loadmat(
        analysis_path,
        variable_names=["PM_MassesB", "BE0", "BE_LE", "BE_TE"],
        squeeze_me=True,
    )
    modeled_point_masses = np.asarray(analysis["PM_MassesB"], dtype=np.float64)

    surface_summary = None
    if arguments.include_surface:
        surface_path = path_for_role(
            "processed structured-light surface fits for the selected flight"
        )
        surface_inventory = variable_inventory(surface_path)
        expected_surface_variables = {
            "BodySurf_f": [1, 1],
            "BodySurf_w": [1, 1],
            "RefFrame": [1, 1],
            "TailSurf_Tri": [144, 1],
            "TailSurf_w": [144, 1],
            "WingSurf_TouchBodyPts_f": [144, 20, 3],
            "WingSurf_g": [1, 1],
            "WingSurf_w": [1, 1],
        }
        for name, shape in expected_surface_variables.items():
            if surface_inventory.get(name) != shape:
                fail(
                    f"surface variable {name} changed: "
                    f"expected {shape}, found {surface_inventory.get(name)}"
                )
        surface = loadmat(
            surface_path,
            variable_names=[
                "BodySurf_f",
                "BodySurf_w",
                "Down2Up2",
                "RefFrame",
                "TailSurf_Tri",
                "TailSurf_w",
                "Up1Down2",
                "Up2Down3",
                "WingSurf_TouchBodyPts_f",
                "WingSurf_g",
                "WingSurf_w",
            ],
            squeeze_me=True,
            struct_as_record=False,
        )
        body_frame = surface["BodySurf_f"]
        body_world = surface["BodySurf_w"]
        wing_grid = surface["WingSurf_g"]
        wing_world = surface["WingSurf_w"]
        tail_world = surface["TailSurf_w"]
        tail_triangles = surface["TailSurf_Tri"]
        frame_indices = [0, len(wing_world.x) // 2, len(wing_world.x) - 1]
        wing_finite_counts = [
            int(np.count_nonzero(np.isfinite(frame))) for frame in wing_world.z
        ]
        tail_vertex_counts = [int(np.asarray(frame).shape[0]) for frame in tail_world]
        tail_triangle_counts = [
            int(np.asarray(frame).shape[0]) for frame in tail_triangles
        ]
        surface_summary = {
            "matlabVariables": surface_inventory,
            "sourceCoordinateUnits": "millimeters",
            "metersPerSourceUnit": 0.001,
            "coordinateFrames": {
                "n": "reconstruction frame",
                "w": "world frame",
                "f": "body frame",
                "g": "wing-fitted frame",
            },
            "referenceFrameFields": list(surface["RefFrame"]._fieldnames),
            "strokeTransitionIndicesMatlabOneBased": {
                "Up1Down2": int(surface["Up1Down2"]),
                "Down2Up2": int(surface["Down2Up2"]),
                "Up2Down3": int(surface["Up2Down3"]),
            },
            "strokeTransitionIndicesZeroBased": {
                "Up1Down2": int(surface["Up1Down2"]) - 1,
                "Down2Up2": int(surface["Down2Up2"]) - 1,
                "Up2Down3": int(surface["Up2Down3"]) - 1,
            },
            "bodyGridShape": list(np.asarray(body_frame.x).shape),
            "bodyFrameBoundsMillimeters": {
                "x": finite_bounds(body_frame.x),
                "y": finite_bounds(body_frame.y),
                "z": finite_bounds(body_frame.z),
            },
            "bodyWorldFrameCount": len(body_world.x),
            "wingGridShape": list(np.asarray(wing_grid.x).shape),
            "wingFinitePointsPerFrame": {
                "minimum": min(wing_finite_counts),
                "maximum": max(wing_finite_counts),
                "samples": {
                    str(index): wing_finite_counts[index] for index in frame_indices
                },
            },
            "tailVerticesPerFrame": {
                "minimum": min(tail_vertex_counts),
                "maximum": max(tail_vertex_counts),
            },
            "tailTrianglesPerFrame": {
                "minimum": min(tail_triangle_counts),
                "maximum": max(tail_triangle_counts),
            },
            "wingBodyContactShape": list(
                np.asarray(surface["WingSurf_TouchBodyPts_f"]).shape
            ),
        }

    result = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-engineering-ingestion-2026-07-16",
        "generatedBy": "Scripts/inspect-dove-benchmark.py",
        "sourceQualification": {
            "auditIdentifier": audit["auditIdentifier"],
            "sha256": hashlib.sha256(audit_bytes).hexdigest(),
        },
        "selectedFlight": {
            "birdIdentifier": selected["birdIdentifier"],
            "flightIdentifier": selected["flightIdentifier"],
            "verifiedMemberCount": len(verified_members),
            "surfaceIncluded": arguments.include_surface,
        },
        "sourceMemberVerification": verified_members,
        "synchronization": {
            "kinematicsRateHertz": selected["kinematicsSampleRateHertz"],
            "forceRateHertzReconstructed": reconstructed_rate,
            "firstBufferedSourceFrame": int(first_frame),
            "lastBufferedSourceFrame": int(last_frame),
            "kinematicsFrameCount": int(len(frame_numbers)),
            "firstForceSampleIndexZeroBased": high_rate_start,
            "lastForceSampleIndexZeroBased": high_rate_end,
            "highRateForceSampleCount": int(len(high_rate_time)),
            "maximumAbsoluteNearestSampleResidualSeconds": float(
                np.max(np.abs(timing_residuals))
            ),
            "forceSamplesPerKinematicsInterval": int(
                round(
                    selected["aerodynamicForceSampleRateHertz"]
                    / selected["kinematicsSampleRateHertz"]
                )
            ),
        },
        "measuredForceWindow": {
            "storedChannelInterpretation": "force-platform reaction after source processing",
            "sourcePlotAndImpulseMultiplier": -1,
            "signAndAxisPromotionStatus": "source convention reconstructed; independent BirdFlow frame registration still required",
            "rawFxWings": force_summary(high_rate_fx, force_dt),
            "rawFzWings": force_summary(high_rate_fz, force_dt),
            "sourceConventionExternalFx": force_summary(-high_rate_fx, force_dt),
            "sourceConventionExternalFz": force_summary(-high_rate_fz, force_dt),
        },
        "massEvidence": {
            "selectedFlightPlatformBodyWeightNewtons": float(force["BodyWeight"]),
            "selectedFlightPlatformEquivalentMassKilograms": float(
                force["BodyWeight"] / 9.81
            ),
            "authorsFinalFourBirdMassesKilograms": final_masses.tolist(),
            "selectedAuthorsFinalMassKilograms": float(final_masses[bird_index]),
            "modeledSingleWingPointMassCount": int(modeled_point_masses.size),
            "modeledSingleWingMassKilograms": float(np.sum(modeled_point_masses)),
            "modelStatus": "cross-source scaled distribution; not measured schema-2 inertia",
        },
        "surface": surface_summary,
        "readiness": {
            "memberIntegrityPassed": True,
            "matlabInventoryPassed": True,
            "timingReconstructionPassed": True,
            "processedSurfaceDecoded": arguments.include_surface,
            "birdFlowCoordinateRegistrationPassed": False,
            "surfaceTopologyConversionPassed": False,
            "measuredForceComparisonReady": False,
            "nextAction": "convert the 144 processed body, tail, and left-wing surface frames into a compact provenance-locked BirdFlow surface sequence and close its coordinates, topology, and wall velocity against this audit",
        },
    }
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

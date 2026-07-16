#!/usr/bin/env python3
"""Independently audit a compact Deetjen complete-surface sequence.

This script does not import the converter.  It decodes the committed binary
contract, reconstructs source areas and bounds from the deposited MATLAB file,
and recomputes wall-speed continuity from adjacent fixed-topology frames.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

try:
    import numpy as np
    from scipy.io import loadmat
except ImportError as error:
    raise SystemExit(
        "audit-dove-surface-sequence.py requires NumPy and SciPy: " + str(error)
    ) from error


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def safe_sibling(manifest_path: Path, name: str) -> Path:
    relative = Path(name)
    if relative.is_absolute() or ".." in relative.parts or len(relative.parts) != 1:
        fail(f"unsafe binary member path: {name}")
    return manifest_path.parent / relative


def mesh_area(vertices: np.ndarray, triangles: np.ndarray) -> float:
    first = vertices[triangles[:, 0]]
    second = vertices[triangles[:, 1]]
    third = vertices[triangles[:, 2]]
    return float(
        0.5
        * np.linalg.norm(
            np.cross(second - first, third - first), axis=1
        ).sum()
    )


def mesh_triangle_areas(vertices: np.ndarray, triangles: np.ndarray) -> np.ndarray:
    first = vertices[triangles[:, 0]]
    second = vertices[triangles[:, 1]]
    third = vertices[triangles[:, 2]]
    return 0.5 * np.linalg.norm(
        np.cross(second - first, third - first), axis=1
    )


def grid_area(vertices: np.ndarray, mask: np.ndarray | None = None) -> float:
    if mask is None:
        mask = np.ones(vertices.shape[:2], dtype=bool)
    quads = (
        mask[:-1, :-1]
        & mask[1:, :-1]
        & mask[:-1, 1:]
        & mask[1:, 1:]
    )
    first = vertices[:-1, :-1][quads]
    second = vertices[1:, :-1][quads]
    third = vertices[:-1, 1:][quads]
    fourth = vertices[1:, 1:][quads]
    return float(
        0.5
        * (
            np.linalg.norm(np.cross(second - first, third - first), axis=1).sum()
            + np.linalg.norm(
                np.cross(fourth - second, third - second), axis=1
            ).sum()
        )
    )


def vector_struct(structure: dict) -> np.ndarray:
    return np.stack([structure[key] for key in "xyz"], axis=-1).astype(np.float64)


def source_world(
    body_points: np.ndarray, reference: dict, frame: int
) -> np.ndarray:
    rotation = np.asarray(reference["R_fw"][frame], dtype=np.float64)
    translation = np.asarray(reference["T_fw_F"][frame], dtype=np.float64)
    return np.einsum("...j,jk->...k", body_points - translation, rotation)


def birdflow_points(source_points: np.ndarray, origin: np.ndarray) -> np.ndarray:
    relative = source_points - origin
    return 0.001 * np.stack(
        (relative[..., 1], -relative[..., 0], relative[..., 2]), axis=-1
    )


def bound_error(source: np.ndarray, compact: np.ndarray) -> float:
    differences = np.concatenate(
        (
            np.min(compact, axis=0) - np.min(source, axis=0),
            np.max(compact, axis=0) - np.max(source, axis=0),
        )
    )
    return float(np.max(np.abs(differences)))


def summarize(values: list[float]) -> dict:
    array = np.asarray(values, dtype=np.float64)
    return {
        "minimum": float(np.min(array)),
        "median": float(np.median(array)),
        "maximum": float(np.max(array)),
        "maximumAbsolute": float(np.max(np.abs(array))),
        "rms": float(np.sqrt(np.mean(np.square(array)))),
    }


def close(first: float, second: float, tolerance: float = 2.0e-6) -> bool:
    return abs(first - second) <= tolerance * max(1.0, abs(first), abs(second))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit a fixed-topology Deetjen surface independently"
    )
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--surface-mat", required=True, type=Path)
    parser.add_argument("--muscle-model-mat", required=True, type=Path)
    parser.add_argument("--conversion-audit", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()

    manifest = json.loads(arguments.manifest.read_text())
    conversion = json.loads(arguments.conversion_audit.read_text())
    if manifest["schemaVersion"] != 1:
        fail("manifest schemaVersion must be 1")
    if manifest["scientificTier"] != "derived-measured-complete-surface":
        fail("unexpected scientific tier")
    if sha256(arguments.surface_mat) != manifest["source"]["surfaceSHA256"]:
        fail("source surface SHA-256 does not match manifest")
    if sha256(arguments.muscle_model_mat) != manifest["source"]["muscleModelSHA256"]:
        fail("source muscle-model SHA-256 does not match manifest")

    positions_record = manifest["binary"]["positions"]
    triangles_record = manifest["binary"]["triangles"]
    positions_path = safe_sibling(arguments.manifest, positions_record["file"])
    triangles_path = safe_sibling(arguments.manifest, triangles_record["file"])
    binary_checks = {
        "positionsByteCount": positions_path.stat().st_size == positions_record["bytes"],
        "positionsSHA256": sha256(positions_path) == positions_record["sha256"],
        "trianglesByteCount": triangles_path.stat().st_size == triangles_record["bytes"],
        "trianglesSHA256": sha256(triangles_path) == triangles_record["sha256"],
    }

    frame_count = int(manifest["frames"]["count"])
    vertex_count = int(manifest["topology"]["vertexCount"])
    triangle_count = int(manifest["topology"]["triangleCount"])
    positions_raw = np.fromfile(positions_path, dtype="<f4")
    triangles_raw = np.fromfile(triangles_path, dtype="<u2")
    if positions_raw.size != frame_count * vertex_count * 3:
        fail("position scalar count does not match manifest")
    if triangles_raw.size != triangle_count * 3:
        fail("triangle scalar count does not match manifest")
    positions = positions_raw.reshape(frame_count, vertex_count, 3).astype(np.float64)
    triangles = triangles_raw.reshape(triangle_count, 3).astype(np.int64)

    times = np.asarray(manifest["frames"]["timesSeconds"], dtype=np.float64)
    frame_numbers = manifest["frames"]["frameNumbers"]
    components = manifest["topology"]["components"]
    structure_checks = {
        "finitePositions": bool(np.isfinite(positions).all()),
        "strictlyIncreasingTimes": bool(
            len(times) == frame_count and np.all(np.diff(times) > 0)
        ),
        "frameNumberCount": len(frame_numbers) == frame_count,
        "nonperiodic": manifest["frames"]["periodic"] is False,
        "triangleBudget": triangle_count
        <= manifest["topology"]["metalTriangleIdentifierLimit"],
        "globalIndicesInRange": bool(
            np.min(triangles) >= 0 and np.max(triangles) < vertex_count
        ),
    }
    component_ranges_pass = True
    for component in components:
        triangle_start = component["triangleOffset"]
        triangle_end = triangle_start + component["triangleCount"]
        vertex_start = component["vertexOffset"]
        vertex_end = vertex_start + component["vertexCount"]
        selected = triangles[triangle_start:triangle_end]
        component_ranges_pass &= bool(
            len(selected) == component["triangleCount"]
            and np.min(selected) >= vertex_start
            and np.max(selected) < vertex_end
        )
    structure_checks["componentIndicesInRange"] = component_ranges_pass

    matlab = loadmat(arguments.surface_mat, simplify_cells=True)
    muscle = loadmat(
        arguments.muscle_model_mat,
        simplify_cells=True,
        variable_names=["BE_Vel1_w"],
    )
    reference = matlab["RefFrame"]
    body = vector_struct(matlab["BodySurf_f"])
    body_area_square_meters = grid_area(body) * 1.0e-6
    origin = np.asarray(
        manifest["coordinateFrame"]["sourceWorldOriginMillimeters"],
        dtype=np.float64,
    )
    names = [component["name"] for component in components]
    expected_names = ["body", "leftWing", "rightWing", "tail"]
    if names != expected_names:
        fail(f"component order changed: {names}")

    area_errors = {name: [] for name in names}
    bounds_errors = {name: [] for name in names}
    minimum_triangle_area = float("inf")
    for frame in range(frame_count):
        wing_g = matlab["WingSurf_g"]
        wing_grid = np.stack(
            (wing_g["x"], wing_g["y"], wing_g["zAll"][frame]), axis=-1
        ).astype(np.float64)
        wing_filled = np.einsum(
            "...j,jk->...k",
            wing_grid,
            np.asarray(reference["R_gf"][frame], dtype=np.float64),
        ) + np.asarray(reference["T_fg_F"][frame], dtype=np.float64)
        observed = np.isfinite(matlab["WingSurf_f"]["z"][frame])
        outline = np.zeros(observed.shape, dtype=bool)
        for column in range(observed.shape[1]):
            rows = np.flatnonzero(observed[:, column])
            if len(rows) >= 2:
                outline[rows[0] : rows[-1] + 1, column] = True
        left_source = wing_filled[outline]
        right_source = left_source.copy()
        right_source[:, 0] *= -1.0
        tail_source = np.asarray(matlab["TailSurf_f"][frame], dtype=np.float64)
        tail_source_triangles = (
            np.asarray(matlab["TailSurf_Tri"][frame], dtype=np.int64) - 1
        )
        source_areas = [
            body_area_square_meters,
            grid_area(wing_filled, outline) * 1.0e-6,
            grid_area(wing_filled, outline) * 1.0e-6,
            mesh_area(tail_source, tail_source_triangles) * 1.0e-6,
        ]
        source_body_points = [
            body.reshape(-1, 3), left_source, right_source, tail_source
        ]
        for index, component in enumerate(components):
            triangle_start = component["triangleOffset"]
            triangle_end = triangle_start + component["triangleCount"]
            selected_triangles = triangles[triangle_start:triangle_end]
            compact_area = mesh_area(positions[frame], selected_triangles)
            area_errors[component["name"]].append(
                compact_area / source_areas[index] - 1.0
            )
            minimum_triangle_area = min(
                minimum_triangle_area,
                float(
                    np.min(
                        mesh_triangle_areas(
                            positions[frame], selected_triangles
                        )
                    )
                ),
            )
            vertex_start = component["vertexOffset"]
            vertex_end = vertex_start + component["vertexCount"]
            source_birdflow = birdflow_points(
                source_world(source_body_points[index], reference, frame), origin
            )
            bounds_errors[component["name"]].append(
                bound_error(
                    source_birdflow,
                    positions[frame, vertex_start:vertex_end],
                )
            )

    closure = {
        name: {
            "areaRelativeError": summarize(area_errors[name]),
            "maximumAbsoluteBoundsErrorMeters": float(max(bounds_errors[name])),
        }
        for name in names
    }
    time_steps = np.diff(times)[:, None]
    adjacent_speeds = np.linalg.norm(np.diff(positions, axis=0), axis=2) / time_steps
    maximum_speed = float(np.max(adjacent_speeds))
    blade_speeds = np.linalg.norm(
        np.asarray(muscle["BE_Vel1_w"], dtype=np.float64), axis=2
    )
    deposited_maximum_speed = float(np.nanmax(blade_speeds))
    speed_ratio = maximum_speed / deposited_maximum_speed
    thresholds = conversion["thresholds"]

    closure_checks = {
        "bodyArea": closure["body"]["areaRelativeError"]["maximumAbsolute"]
        <= thresholds["maximumBodyAreaAbsoluteRelativeError"],
        "leftWingArea": closure["leftWing"]["areaRelativeError"]["maximumAbsolute"]
        <= thresholds["maximumWingAreaAbsoluteRelativeError"],
        "rightWingArea": closure["rightWing"]["areaRelativeError"]["maximumAbsolute"]
        <= thresholds["maximumWingAreaAbsoluteRelativeError"],
        "tailArea": closure["tail"]["areaRelativeError"]["maximumAbsolute"]
        <= thresholds["maximumTailAreaAbsoluteRelativeError"],
        "bounds": max(
            record["maximumAbsoluteBoundsErrorMeters"] for record in closure.values()
        ) <= thresholds["maximumBoundsErrorMeters"],
        "wallVelocityContinuity": speed_ratio
        <= thresholds["maximumSpeedToDepositedBladeSpeedRatio"],
        "nondegenerateTriangles": minimum_triangle_area > 1.0e-14,
    }

    parity_checks = {
        "manifestSHA256": sha256(arguments.manifest)
        == conversion["manifestSHA256"],
        "frameCount": frame_count == conversion["counts"]["frames"],
        "vertexCount": vertex_count == conversion["counts"]["verticesPerFrame"],
        "triangleCount": triangle_count == conversion["counts"]["triangles"],
        "maximumSpeed": close(
            maximum_speed, conversion["maximumAdjacentPointSpeedMetersPerSecond"]
        ),
        "depositedMaximumSpeed": close(
            deposited_maximum_speed,
            conversion["depositedMaximumBladeElementSpeedMetersPerSecond"],
        ),
    }
    for name in names:
        parity_checks[f"{name}Area"] = close(
            closure[name]["areaRelativeError"]["maximumAbsolute"],
            conversion["closure"][name]["areaRelativeError"]["maximumAbsolute"],
        )
        parity_checks[f"{name}Bounds"] = close(
            closure[name]["maximumAbsoluteBoundsErrorMeters"],
            conversion["closure"][name]["maximumAbsoluteBoundsErrorMeters"],
        )

    all_checks = {
        **binary_checks,
        **structure_checks,
        **closure_checks,
        **parity_checks,
    }
    report = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-surface-cpu-parity-v1",
        "generatedBy": "Scripts/audit-dove-surface-sequence.py",
        "sourceSurfaceSHA256": sha256(arguments.surface_mat),
        "sourceMuscleModelSHA256": sha256(arguments.muscle_model_mat),
        "manifestSHA256": sha256(arguments.manifest),
        "counts": {
            "frames": frame_count,
            "verticesPerFrame": vertex_count,
            "triangles": triangle_count,
        },
        "closure": closure,
        "minimumTriangleAreaSquareMeters": minimum_triangle_area,
        "maximumAdjacentPointSpeedMetersPerSecond": maximum_speed,
        "depositedMaximumBladeElementSpeedMetersPerSecond": deposited_maximum_speed,
        "maximumSpeedToDepositedBladeSpeedRatio": speed_ratio,
        "checks": all_checks,
        "cpuParityPassed": all(all_checks.values()),
        "claimBoundary": (
            "Independent CPU decoding closes binary identity, topology, source area, "
            "bounds, and adjacent-frame wall speed. No fluid or force result is implied."
        ),
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    if not report["cpuParityPassed"]:
        failed = [name for name, passed in all_checks.items() if not passed]
        fail("CPU parity gate failed: " + ", ".join(failed))
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Convert the qualified Deetjen dove surface into a compact fixed topology.

The output is deliberately non-periodic.  It preserves the deposited laboratory
motion over the 144-frame force window and uses one indexed topology for every
frame so position and wall velocity can share the same interpolation segment.

NumPy and SciPy are required to decode the published MATLAB v5 surface file.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

try:
    import numpy as np
    from scipy.interpolate import LinearNDInterpolator
    from scipy.io import loadmat
    from scipy.signal import savgol_filter
    from scipy.spatial import ConvexHull
except ImportError as error:
    raise SystemExit(
        "convert-dove-surface-sequence.py requires NumPy and SciPy: "
        + str(error)
    ) from error


SCHEMA_VERSION = 1
FRAME_COUNT = 144
SAMPLE_RATE_HZ = 1000.0
FIRST_FRAME_NUMBER = -1943
BODY_CIRCUMFERENCE_COUNT = 37
BODY_LONGITUDINAL_COUNT = 39
WING_CHORD_COUNT = 9
WING_SPAN_COUNT = 33
TAIL_RADIAL_COUNT = 7
TAIL_ANGULAR_COUNT = 17
METAL_TRIANGLE_LIMIT = 4096
WING_TEMPORAL_FILTER_FRAMES = 15
WING_TEMPORAL_FILTER_POLYNOMIAL_ORDER = 3


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def vectors(structure: dict, frame: int | None = None) -> np.ndarray:
    if frame is None:
        return np.stack([structure[key] for key in "xyz"], axis=-1).astype(
            np.float64
        )
    return np.stack(
        [structure[key][frame] for key in "xyz"], axis=-1
    ).astype(np.float64)


def grid_triangles(first_count: int, second_count: int) -> np.ndarray:
    triangles: list[tuple[int, int, int]] = []
    for second in range(second_count - 1):
        for first in range(first_count - 1):
            lower_left = second * first_count + first
            lower_right = lower_left + 1
            upper_left = lower_left + first_count
            upper_right = upper_left + 1
            triangles.append((lower_left, lower_right, upper_left))
            triangles.append((lower_right, upper_right, upper_left))
    return np.asarray(triangles, dtype=np.uint16)


def triangle_area(vertices: np.ndarray, triangles: np.ndarray) -> float:
    a = vertices[triangles[:, 0]]
    b = vertices[triangles[:, 1]]
    c = vertices[triangles[:, 2]]
    return float(0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1).sum())


def structured_area(vertices: np.ndarray, mask: np.ndarray | None = None) -> float:
    if mask is None:
        mask = np.ones(vertices.shape[:2], dtype=bool)
    quads = (
        mask[:-1, :-1]
        & mask[1:, :-1]
        & mask[:-1, 1:]
        & mask[1:, 1:]
    )
    a = vertices[:-1, :-1][quads]
    b = vertices[1:, :-1][quads]
    c = vertices[:-1, 1:][quads]
    d = vertices[1:, 1:][quads]
    return float(
        0.5
        * (
            np.linalg.norm(np.cross(b - a, c - a), axis=1).sum()
            + np.linalg.norm(np.cross(d - b, c - b), axis=1).sum()
        )
    )


def weighted_indices(edge_weights: np.ndarray, count: int) -> np.ndarray:
    cumulative = np.concatenate(([0.0], np.cumsum(edge_weights)))
    targets = np.linspace(0.0, cumulative[-1], count)
    indices = np.searchsorted(cumulative, targets, side="left")
    indices = np.clip(indices, 0, len(cumulative) - 1)
    indices[0] = 0
    indices[-1] = len(cumulative) - 1
    for index in range(1, len(indices)):
        indices[index] = max(indices[index], indices[index - 1] + 1)
    for index in range(len(indices) - 2, -1, -1):
        indices[index] = min(indices[index], indices[index + 1] - 1)
    if len(np.unique(indices)) != count:
        fail("body importance sampling produced duplicate indices")
    return indices


def compact_body(body: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    circumference_edges = np.linalg.norm(np.diff(body, axis=0), axis=2)
    longitudinal_edges = np.linalg.norm(np.diff(body, axis=1), axis=2)
    circumference = weighted_indices(
        np.sqrt(np.mean(np.square(circumference_edges), axis=1)),
        BODY_CIRCUMFERENCE_COUNT,
    )
    longitudinal = weighted_indices(
        np.sqrt(np.mean(np.square(longitudinal_edges), axis=0)),
        BODY_LONGITUDINAL_COUNT,
    )
    compact = body[np.ix_(circumference, longitudinal)].reshape(-1, 3)
    triangles = grid_triangles(
        BODY_LONGITUDINAL_COUNT, BODY_CIRCUMFERENCE_COUNT
    )
    return compact, triangles


def longest_consecutive(values: np.ndarray) -> np.ndarray:
    groups = np.split(values, np.flatnonzero(np.diff(values) > 1) + 1)
    return max(groups, key=len)


def wing_filled_surface(
    matlab: dict, frame: int
) -> tuple[np.ndarray, np.ndarray]:
    wing_g = matlab["WingSurf_g"]
    reference = matlab["RefFrame"]
    grid = np.stack(
        (wing_g["x"], wing_g["y"], wing_g["zAll"][frame]), axis=-1
    ).astype(np.float64)
    rotation = np.asarray(reference["R_gf"][frame], dtype=np.float64)
    translation = np.asarray(reference["T_fg_F"][frame], dtype=np.float64)
    filled_body_frame = np.einsum("...j,jk->...k", grid, rotation) + translation

    observed = np.isfinite(matlab["WingSurf_f"]["z"][frame])
    outline = np.zeros(observed.shape, dtype=bool)
    for column in range(observed.shape[1]):
        rows = np.flatnonzero(observed[:, column])
        if len(rows) >= 2:
            outline[rows[0] : rows[-1] + 1, column] = True
    return filled_body_frame, outline


def compact_wing(
    filled: np.ndarray, outline: np.ndarray
) -> tuple[np.ndarray, tuple[int, int]]:
    sections = []
    midpoints = []
    columns = []
    for column in range(filled.shape[1]):
        rows = np.flatnonzero(outline[:, column])
        if len(rows) < 4:
            continue
        rows = longest_consecutive(rows)
        points = filled[rows, column]
        distance = np.concatenate(
            ([0.0], np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1)))
        )
        if distance[-1] <= 0:
            continue
        targets = np.linspace(0.0, distance[-1], WING_CHORD_COUNT)
        section = np.stack(
            [np.interp(targets, distance, points[:, axis]) for axis in range(3)],
            axis=1,
        )
        sections.append(section)
        midpoints.append(np.mean(section, axis=0))
        columns.append(column)

    columns_array = np.asarray(columns, dtype=np.int64)
    # The deposited flight contains one observed wing strip.  Select its
    # longest consecutive column range without inferring across missing tips.
    groups = np.split(
        np.arange(len(columns_array)),
        np.flatnonzero(np.diff(columns_array) > 1) + 1,
    )
    selected = max(groups, key=len)
    sections_array = np.asarray(sections)[selected]
    midpoints_array = np.asarray(midpoints)[selected]
    selected_columns = columns_array[selected]

    span_distance = np.concatenate(
        (
            [0.0],
            np.cumsum(
                np.linalg.norm(np.diff(midpoints_array, axis=0), axis=1)
            ),
        )
    )
    if span_distance[-1] <= 0:
        fail("wing span has zero length")
    span_targets = np.linspace(0.0, span_distance[-1], WING_SPAN_COUNT)
    compact = np.empty((WING_SPAN_COUNT, WING_CHORD_COUNT, 3))
    for chord in range(WING_CHORD_COUNT):
        for axis in range(3):
            compact[:, chord, axis] = np.interp(
                span_targets,
                span_distance,
                sections_array[:, chord, axis],
            )
    return compact.reshape(-1, 3), (
        int(selected_columns[0]),
        int(selected_columns[-1]),
    )


def ray_polygon_radius(polygon: np.ndarray, angle: float) -> float:
    direction = np.asarray([math.sin(angle), math.cos(angle)])
    intersections = []
    for first, second in zip(polygon, np.roll(polygon, -1, axis=0)):
        edge = second - first
        matrix = np.column_stack((direction, -edge))
        determinant = float(np.linalg.det(matrix))
        if abs(determinant) < 1.0e-12:
            continue
        radius, fraction = np.linalg.solve(matrix, first)
        if radius >= -1.0e-8 and -1.0e-8 <= fraction <= 1.0 + 1.0e-8:
            intersections.append(float(radius))
    if not intersections:
        fail("tail outline ray did not intersect its convex hull")
    return max(intersections)


def tail_topology() -> np.ndarray:
    triangles: list[tuple[int, int, int]] = []
    for angle in range(TAIL_ANGULAR_COUNT - 1):
        triangles.append((0, 1 + angle, 2 + angle))
    for radial in range(TAIL_RADIAL_COUNT - 1):
        lower = 1 + radial * TAIL_ANGULAR_COUNT
        upper = lower + TAIL_ANGULAR_COUNT
        for angle in range(TAIL_ANGULAR_COUNT - 1):
            triangles.append((lower + angle, upper + angle, lower + angle + 1))
            triangles.append(
                (lower + angle + 1, upper + angle, upper + angle + 1)
            )
    return np.asarray(triangles, dtype=np.uint16)


def compact_tail(vertices: np.ndarray, root: np.ndarray) -> np.ndarray:
    displacement = vertices - root
    _, _, right_vectors = np.linalg.svd(displacement, full_matrices=False)
    normal = right_vectors[-1]
    lateral = np.asarray([1.0, 0.0, 0.0])
    lateral -= normal * np.dot(lateral, normal)
    lateral /= np.linalg.norm(lateral)
    aft = np.cross(normal, lateral)
    if np.dot(aft, np.mean(displacement, axis=0)) < 0:
        aft = -aft
    plane = np.stack(
        (
            np.einsum("ij,j->i", displacement, lateral),
            np.einsum("ij,j->i", displacement, aft),
        ),
        axis=1,
    )
    hull = ConvexHull(plane)
    polygon = plane[hull.vertices]
    angles = np.arctan2(polygon[:, 0], polygon[:, 1])
    target_angles = np.linspace(
        float(np.min(angles)), float(np.max(angles)), TAIL_ANGULAR_COUNT
    )
    radii = np.asarray(
        [ray_polygon_radius(polygon, angle) for angle in target_angles]
    )
    interpolator = LinearNDInterpolator(plane, vertices, fill_value=np.nan)
    compact = [root]
    for radial in range(1, TAIL_RADIAL_COUNT + 1):
        fraction = radial / TAIL_RADIAL_COUNT
        # A tiny contraction keeps the outer ring inside the interpolation
        # hull despite floating-point edge classification.
        x = fraction * 0.999 * radii * np.sin(target_angles)
        y = fraction * 0.999 * radii * np.cos(target_angles)
        points_2d = np.stack((x, y), axis=1)
        points_3d = np.asarray(interpolator(points_2d))
        missing = ~np.isfinite(points_3d).all(axis=1)
        points_3d[missing] = (
            root
            + points_2d[missing, :1] * lateral
            + points_2d[missing, 1:] * aft
        )
        compact.extend(points_3d)
    return np.asarray(compact, dtype=np.float64)


def to_source_world(
    points_body: np.ndarray, reference: dict, frame: int
) -> np.ndarray:
    rotation = np.asarray(reference["R_fw"][frame], dtype=np.float64)
    translation = np.asarray(reference["T_fw_F"][frame], dtype=np.float64)
    return np.einsum("...j,jk->...k", points_body - translation, rotation)


def to_birdflow(
    source_world: np.ndarray, source_origin: np.ndarray
) -> np.ndarray:
    relative = source_world - source_origin
    return np.stack((relative[..., 1], -relative[..., 0], relative[..., 2]), axis=-1)


def bounds_error(source: np.ndarray, compact: np.ndarray) -> float:
    error = np.concatenate(
        (np.min(compact, axis=0) - np.min(source, axis=0),
         np.max(compact, axis=0) - np.max(source, axis=0))
    )
    return float(np.max(np.abs(error)))


def summarize_errors(values: list[float]) -> dict:
    array = np.asarray(values, dtype=np.float64)
    return {
        "minimum": float(np.min(array)),
        "median": float(np.median(array)),
        "maximum": float(np.max(array)),
        "maximumAbsolute": float(np.max(np.abs(array))),
        "rms": float(np.sqrt(np.mean(np.square(array)))),
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert the qualified Deetjen dove into a fixed mesh sequence"
    )
    parser.add_argument("--surface-mat", required=True, type=Path)
    parser.add_argument("--muscle-model-mat", required=True, type=Path)
    parser.add_argument("--ingestion", type=Path, default=Path(
        "ValidationArtifacts/deetjen-dove-engineering-ingestion.json"
    ))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--audit", required=True, type=Path)
    arguments = parser.parse_args()

    ingestion = json.loads(arguments.ingestion.read_text())
    surface_lock = next(
        member
        for member in ingestion["sourceMemberVerification"]
        if member["archivePath"].endswith("/SurfFits.mat")
    )
    actual_source_sha = sha256(arguments.surface_mat)
    if actual_source_sha != surface_lock["sha256"]:
        fail(
            "SurfFits.mat SHA-256 mismatch: expected "
            f"{surface_lock['sha256']}, found {actual_source_sha}"
        )

    muscle_lock = next(
        member
        for member in ingestion["sourceMemberVerification"]
        if member["archivePath"].endswith(
            "/9 MuscleModel/2TestRuns/OB/2018_12_11_OB_F03.mat"
        )
    )
    actual_muscle_sha = sha256(arguments.muscle_model_mat)
    if actual_muscle_sha != muscle_lock["sha256"]:
        fail(
            "muscle-model MAT SHA-256 mismatch: expected "
            f"{muscle_lock['sha256']}, found {actual_muscle_sha}"
        )
    muscle = loadmat(
        arguments.muscle_model_mat,
        simplify_cells=True,
        variable_names=["BE_Vel1_w"],
    )
    deposited_blade_velocity = np.asarray(
        muscle["BE_Vel1_w"], dtype=np.float64
    )
    deposited_maximum_blade_speed = float(
        np.nanmax(np.linalg.norm(deposited_blade_velocity, axis=2))
    )

    matlab = loadmat(arguments.surface_mat, simplify_cells=True)
    body_source = vectors(matlab["BodySurf_f"])
    if body_source.shape != (200, 200, 3):
        fail(f"unexpected BodySurf_f shape: {body_source.shape}")
    reference = matlab["RefFrame"]
    if len(reference["R_fw"]) != FRAME_COUNT:
        fail("unexpected RefFrame frame count")

    body_compact, body_triangles = compact_body(body_source)
    wing_triangles = grid_triangles(WING_CHORD_COUNT, WING_SPAN_COUNT)
    tail_triangles = tail_topology()
    tail_root = np.asarray(matlab["TailSurf_Geo"]["xyz0"], dtype=np.float64)

    vertex_counts = [
        len(body_compact),
        WING_CHORD_COUNT * WING_SPAN_COUNT,
        WING_CHORD_COUNT * WING_SPAN_COUNT,
        1 + TAIL_RADIAL_COUNT * TAIL_ANGULAR_COUNT,
    ]
    local_triangles = [
        body_triangles,
        wing_triangles,
        wing_triangles[:, [0, 2, 1]],
        tail_triangles,
    ]
    vertex_offsets = np.cumsum([0] + vertex_counts[:-1]).astype(int)
    triangle_counts = [len(value) for value in local_triangles]
    triangle_offsets = np.cumsum([0] + triangle_counts[:-1]).astype(int)
    global_triangles = np.concatenate(
        [value.astype(np.uint32) + offset
         for value, offset in zip(local_triangles, vertex_offsets)],
        axis=0,
    )
    if int(np.max(global_triangles)) > np.iinfo(np.uint16).max:
        fail("surface topology exceeds uint16 vertex addressing")
    if len(global_triangles) > METAL_TRIANGLE_LIMIT:
        fail(
            f"surface has {len(global_triangles)} triangles; Metal limit is "
            f"{METAL_TRIANGLE_LIMIT}"
        )

    frame_zero_rotation = np.asarray(reference["R_fw"][0], dtype=np.float64)
    frame_zero_translation = np.asarray(
        reference["T_fw_F"][0], dtype=np.float64
    )
    source_origin = np.einsum(
        "j,jk->k", -frame_zero_translation, frame_zero_rotation
    )

    body_source_area = structured_area(body_source)
    body_compact_area = triangle_area(body_compact, body_triangles)
    area_errors = {"body": [], "leftWing": [], "rightWing": [], "tail": []}
    bound_errors = {"body": [], "leftWing": [], "rightWing": [], "tail": []}
    observed_column_ranges = []
    frames = []
    transform_parity_max_mm = 0.0

    # The observed outline can add or remove a low-visibility tip/chord row in
    # one millisecond.  Remeshing those raw extents directly produced a false
    # 91.9 m/s wall speed.  Regularize material-point coordinates in the body
    # frame, then derive position and velocity from that same sequence.  The
    # deposited filtered blade-element speed supplies the independent bound.
    wing_frames = []
    wing_filled_frames = []
    wing_outline_frames = []
    for frame in range(FRAME_COUNT):
        wing_filled, wing_outline = wing_filled_surface(matlab, frame)
        left_compact, column_range = compact_wing(wing_filled, wing_outline)
        wing_frames.append(left_compact)
        wing_filled_frames.append(wing_filled)
        wing_outline_frames.append(wing_outline)
        observed_column_ranges.append(list(column_range))
    regularized_wing_frames = savgol_filter(
        np.asarray(wing_frames),
        WING_TEMPORAL_FILTER_FRAMES,
        WING_TEMPORAL_FILTER_POLYNOMIAL_ORDER,
        axis=0,
        mode="interp",
    )

    for frame in range(FRAME_COUNT):
        wing_filled = wing_filled_frames[frame]
        wing_outline = wing_outline_frames[frame]
        left_compact = regularized_wing_frames[frame]
        right_compact = left_compact.copy()
        right_compact[:, 0] *= -1.0
        tail_source = np.asarray(matlab["TailSurf_f"][frame], dtype=np.float64)
        tail_source_triangles = (
            np.asarray(matlab["TailSurf_Tri"][frame], dtype=np.int64) - 1
        )
        tail_compact = compact_tail(tail_source, tail_root)

        components_body = [body_compact, left_compact, right_compact, tail_compact]
        components_world = [
            to_source_world(component, reference, frame)
            for component in components_body
        ]
        frame_birdflow_mm = np.concatenate(
            [to_birdflow(component, source_origin) for component in components_world]
        )
        frames.append(frame_birdflow_mm * 0.001)

        source_left = wing_filled[wing_outline]
        source_right = source_left.copy()
        source_right[:, 0] *= -1.0
        source_components = [body_source.reshape(-1, 3), source_left,
                             source_right, tail_source]
        names = ["body", "leftWing", "rightWing", "tail"]
        source_areas = [
            body_source_area,
            structured_area(wing_filled, wing_outline),
            structured_area(wing_filled, wing_outline),
            triangle_area(tail_source, tail_source_triangles),
        ]
        compact_areas = [
            body_compact_area,
            triangle_area(left_compact, wing_triangles),
            triangle_area(right_compact, wing_triangles),
            triangle_area(tail_compact, tail_triangles),
        ]
        for component_index, (
            name, source_area, compact_area, source_points, compact_points
        ) in enumerate(zip(
            names, source_areas, compact_areas, source_components, components_body
        )):
            area_errors[name].append(compact_area / source_area - 1.0)
            source_registered = 0.001 * to_birdflow(
                to_source_world(source_points, reference, frame), source_origin
            )
            compact_registered = 0.001 * to_birdflow(
                components_world[component_index], source_origin
            )
            bound_errors[name].append(
                bounds_error(source_registered, compact_registered)
            )

        original_f = vectors(matlab["WingSurf_f"], frame)
        original_w = vectors(matlab["WingSurf_w"], frame)
        finite = np.isfinite(original_f).all(axis=2) & np.isfinite(original_w).all(axis=2)
        reconstructed = to_source_world(original_f[finite], reference, frame)
        transform_parity_max_mm = max(
            transform_parity_max_mm,
            float(np.max(np.abs(reconstructed - original_w[finite]))),
        )

    positions64 = np.asarray(frames, dtype=np.float64)
    positions32 = positions64.astype("<f4")
    quantization_error = float(np.max(np.abs(positions64 - positions32.astype(np.float64))))
    if not np.isfinite(positions32).all():
        fail("converted positions contain a nonfinite value")

    arguments.output.mkdir(parents=True, exist_ok=True)
    positions_path = arguments.output / "positions.f32le"
    triangles_path = arguments.output / "triangles.u16le"
    manifest_path = arguments.output / "manifest.json"
    positions_path.write_bytes(positions32.tobytes(order="C"))
    triangles_path.write_bytes(global_triangles.astype("<u2").tobytes(order="C"))

    components = []
    component_specs = [
        ("body", "measured-processed-surface", {
            "kind": "structured-grid", "firstCount": BODY_LONGITUDINAL_COUNT,
            "secondCount": BODY_CIRCUMFERENCE_COUNT,
            "sampling": "RMS-edge-length importance sampling",
        }),
        ("leftWing", "measured-outline-derived-gap-filled-surface", {
            "kind": "structured-grid", "firstCount": WING_CHORD_COUNT,
            "secondCount": WING_SPAN_COUNT,
            "sampling": "normalized chord and mid-chord arc length",
        }),
        ("rightWing", "bilateral-reflection-assumption", {
            "kind": "structured-grid", "firstCount": WING_CHORD_COUNT,
            "secondCount": WING_SPAN_COUNT,
            "sampling": "body-frame x reflection of leftWing",
        }),
        ("tail", "measured-processed-surface-derived-fixed-parameterization", {
            "kind": "polar-grid", "radialCount": TAIL_RADIAL_COUNT,
            "angularCount": TAIL_ANGULAR_COUNT,
            "sampling": "PCA-plane convex-outline radial interpolation",
        }),
    ]
    for index, (name, evidence, topology) in enumerate(component_specs):
        components.append({
            "name": name,
            "evidenceClass": evidence,
            "vertexOffset": int(vertex_offsets[index]),
            "vertexCount": vertex_counts[index],
            "triangleOffset": int(triangle_offsets[index]),
            "triangleCount": triangle_counts[index],
            "topology": topology,
        })

    manifest = {
        "schemaVersion": SCHEMA_VERSION,
        "datasetIdentifier": "deetjen-ob-2018-12-11-f03-complete-surface-v1",
        "scientificTier": "derived-measured-complete-surface",
        "source": {
            "datasetDOI": "10.5061/dryad.wwpzgmsqs",
            "articleDOI": "10.7554/eLife.89968",
            "surfaceArchivePath": surface_lock["archivePath"],
            "surfaceSHA256": actual_source_sha,
            "muscleModelArchivePath": muscle_lock["archivePath"],
            "muscleModelSHA256": actual_muscle_sha,
            "license": "CC0-1.0",
        },
        "frames": {
            "count": FRAME_COUNT,
            "sampleRateHertz": SAMPLE_RATE_HZ,
            "frameNumbers": list(range(FIRST_FRAME_NUMBER, FIRST_FRAME_NUMBER + FRAME_COUNT)),
            "timesSeconds": [frame / SAMPLE_RATE_HZ for frame in range(FRAME_COUNT)],
            "interpolation": "piecewise-linear-nonperiodic",
            "endpointVelocity": "one-sided-adjacent-frame",
            "periodic": False,
        },
        "coordinateFrame": {
            "name": "BirdFlow laboratory frame relative to frame-zero body origin",
            "units": "meters",
            "sourceAxes": {"x": "right", "y": "forward", "z": "up"},
            "birdFlowAxes": {"x": "forward", "y": "left", "z": "up"},
            "mapping": "[birdFlowX,birdFlowY,birdFlowZ]=[sourceY,-sourceX,sourceZ]",
            "sourceWorldOriginMillimeters": source_origin.tolist(),
            "sourceBodyToWorld": "xyz_w = R_fw' * (xyz_f - T_fw_F)",
        },
        "topology": {
            "vertexCount": int(sum(vertex_counts)),
            "triangleCount": int(len(global_triangles)),
            "indexType": "uint16-little-endian",
            "metalTriangleIdentifierLimit": METAL_TRIANGLE_LIMIT,
            "fixedAcrossFrames": True,
            "temporalRegularization": {
                "scope": "left-wing body-frame material coordinates before bilateral reflection",
                "method": "Savitzky-Golay",
                "windowFrames": WING_TEMPORAL_FILTER_FRAMES,
                "polynomialOrder": WING_TEMPORAL_FILTER_POLYNOMIAL_ORDER,
                "reason": "suppress visibility-outline changes that are not material motion",
            },
            "components": components,
        },
        "binary": {
            "positions": {
                "file": positions_path.name,
                "format": "float32-little-endian",
                "layout": "frame-major, vertex-major, xyz",
                "bytes": positions_path.stat().st_size,
                "sha256": sha256(positions_path),
            },
            "triangles": {
                "file": triangles_path.name,
                "format": "uint16-little-endian",
                "layout": "triangle-major, three global vertex indices",
                "bytes": triangles_path.stat().st_size,
                "sha256": sha256(triangles_path),
            },
        },
        "provenanceBoundary": {
            "measured": ["processed body", "left-wing observed outline", "processed tail", "laboratory motion"],
            "derived": ["body decimation", "zAll wing gap fill inside observed outline", "fixed wing/tail parameterization", "15-frame cubic wing material-coordinate regularization", "coordinate registration"],
            "assumed": ["right wing is a body-sagittal reflection of the measured left wing"],
            "notPresent": ["right-wing measurement", "per-wing force", "lateral force", "same-specimen inertial tensor"],
        },
        "readiness": {
            "completeBirdSurfaceReady": True,
            "cpuParityRequired": True,
            "metalReplayReady": False,
            "quantitativeForceAcceptanceReady": False,
        },
    }
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")

    dt = 1.0 / SAMPLE_RATE_HZ
    adjacent_speed = np.linalg.norm(np.diff(positions64, axis=0), axis=2) / dt
    maximum_adjacent_speed = float(np.max(adjacent_speed))
    closure = {
        name: {
            "areaRelativeError": summarize_errors(area_errors[name]),
            "maximumAbsoluteBoundsErrorMeters": float(max(bound_errors[name])),
        }
        for name in area_errors
    }
    thresholds = {
        "maximumTriangleCount": METAL_TRIANGLE_LIMIT,
        "maximumBodyAreaAbsoluteRelativeError": 0.05,
        "maximumWingAreaAbsoluteRelativeError": 0.10,
        "maximumTailAreaAbsoluteRelativeError": 0.01,
        "maximumBoundsErrorMeters": 0.02,
        "maximumFloat32QuantizationErrorMeters": 1.0e-7,
        "maximumSourceTransformParityErrorMillimeters": 1.0e-9,
        "maximumSpeedToDepositedBladeSpeedRatio": 1.25,
    }
    checks = {
        "triangleBudget": len(global_triangles) <= thresholds["maximumTriangleCount"],
        "bodyArea": closure["body"]["areaRelativeError"]["maximumAbsolute"] <= thresholds["maximumBodyAreaAbsoluteRelativeError"],
        "leftWingArea": closure["leftWing"]["areaRelativeError"]["maximumAbsolute"] <= thresholds["maximumWingAreaAbsoluteRelativeError"],
        "rightWingArea": closure["rightWing"]["areaRelativeError"]["maximumAbsolute"] <= thresholds["maximumWingAreaAbsoluteRelativeError"],
        "tailArea": closure["tail"]["areaRelativeError"]["maximumAbsolute"] <= thresholds["maximumTailAreaAbsoluteRelativeError"],
        "bounds": max(value["maximumAbsoluteBoundsErrorMeters"] for value in closure.values()) <= thresholds["maximumBoundsErrorMeters"],
        "float32Quantization": quantization_error <= thresholds["maximumFloat32QuantizationErrorMeters"],
        "sourceFrameTransformParity": transform_parity_max_mm <= thresholds["maximumSourceTransformParityErrorMillimeters"],
        "wallVelocityContinuity": maximum_adjacent_speed <= deposited_maximum_blade_speed * thresholds["maximumSpeedToDepositedBladeSpeedRatio"],
        "fixedFiniteTopology": bool(np.isfinite(positions32).all()),
        "nonperiodicTimeContract": manifest["frames"]["periodic"] is False,
    }
    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-fixed-surface-conversion-v1",
        "generatedBy": "Scripts/convert-dove-surface-sequence.py",
        "manifestSHA256": sha256(manifest_path),
        "sourceSurfaceSHA256": actual_source_sha,
        "sourceMuscleModelSHA256": actual_muscle_sha,
        "counts": {
            "frames": FRAME_COUNT,
            "verticesPerFrame": int(sum(vertex_counts)),
            "triangles": int(len(global_triangles)),
            "positionBytes": positions_path.stat().st_size,
            "triangleBytes": triangles_path.stat().st_size,
        },
        "closure": closure,
        "observedLeftWingColumnRange": {
            "minimumStart": min(value[0] for value in observed_column_ranges),
            "maximumEnd": max(value[1] for value in observed_column_ranges),
        },
        "maximumFloat32QuantizationErrorMeters": quantization_error,
        "maximumSourceTransformParityErrorMillimeters": transform_parity_max_mm,
        "maximumAdjacentPointSpeedMetersPerSecond": maximum_adjacent_speed,
        "depositedMaximumBladeElementSpeedMetersPerSecond": deposited_maximum_blade_speed,
        "maximumSpeedToDepositedBladeSpeedRatio": maximum_adjacent_speed / deposited_maximum_blade_speed,
        "maximumEndToStartPointJumpMeters": float(
            np.max(np.linalg.norm(positions64[-1] - positions64[0], axis=1))
        ),
        "thresholds": thresholds,
        "checks": checks,
        "gatePassed": all(checks.values()),
        "claimBoundary": (
            "This gate establishes a compact, fixed, finite, non-periodic complete-surface "
            "sequence with independently auditable geometry. It does not establish a Metal "
            "replay, fluid-force agreement, right-wing measurement, or free-flight closure."
        ),
    }
    arguments.audit.parent.mkdir(parents=True, exist_ok=True)
    arguments.audit.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    if not audit["gatePassed"]:
        failed = [name for name, passed in checks.items() if not passed]
        fail("surface conversion gate failed: " + ", ".join(failed))
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

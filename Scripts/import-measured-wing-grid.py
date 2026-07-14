#!/usr/bin/env python3
"""Audit a published PLOT3D hummingbird wing grid for BirdFlow replay.

This importer intentionally emits a source-audit artifact, not a schema-1 bird
input.  The Maeda et al. deposit contains a measured right-wing surface and
motion, but it does not contain the body, tail, mass, or inertia required by the
complete coupled-bird schema.  Keeping that distinction executable prevents a
partial wing dataset from being promoted as a measured whole-bird replay.

The optional Song et al. Dryad TAR is checked as an independent candidate.  It
contains numeric MATLAB figure sources, but not the reconstructed wing/body
meshes described in the paper.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
import tarfile
import zipfile
from pathlib import Path

try:
    import numpy as np
except ImportError as error:  # pragma: no cover - exercised on minimal hosts
    raise SystemExit(
        "import-measured-wing-grid.py requires numpy for PLOT3D geometry audits"
    ) from error


MAEDA_DATASET_DOI = "10.6084/m9.figshare.5406124.v1"
MAEDA_ARTICLE_DOI = "10.1098/rsos.170307"
MAEDA_EXPECTED_MD5 = "805a482f5a6e6f8395f74e0706629190"
SONG_DATASET_DOI = "10.5061/dryad.8ch1b"
SONG_ARTICLE_DOI = "10.1098/rsos.160230"
SONG_EXPECTED_MD5 = "3f6e0ba062ac3cb110abec98d8e828b0"

FRAME_COUNT = 17
SOURCE_PHASE_START = 0.019
SOURCE_PHASE_INTERVAL = 0.0575
PUBLISHED_FREQUENCY_HZ = 28.8
PUBLISHED_MEAN_SHORTEST_PATH_METERS = 0.0700
PUBLISHED_MEAN_AREA_SQUARE_METERS = 0.001365
PUBLISHED_SPATIAL_RMS_METERS = 0.00014
SPAN_FRACTIONS = np.asarray([0.10, 0.20, 0.40, 0.60, 0.80])


def digest(path: Path, algorithm: str) -> str:
    value = hashlib.new(algorithm)
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def finite(value: float) -> float:
    result = float(value)
    if not math.isfinite(result):
        raise ValueError("non-finite value produced during source audit")
    return result


def vector(values: np.ndarray) -> list[float]:
    return [finite(value) for value in values]


def source_to_birdflow(values: np.ndarray) -> np.ndarray:
    """Maeda global backward/right/up -> BirdFlow forward/left/up."""
    result = np.array(values, dtype=np.float64, copy=True)
    result[..., 0] *= -1
    result[..., 1] *= -1
    return result


def normalize(value: np.ndarray) -> np.ndarray:
    length = np.linalg.norm(value)
    if not math.isfinite(float(length)) or length <= 1e-12:
        raise ValueError("degenerate vector in measured grid")
    return value / length


def rotate(value: np.ndarray, axis: np.ndarray, angle: float) -> np.ndarray:
    axis = normalize(axis)
    return (
        value * math.cos(angle)
        + np.cross(axis, value) * math.sin(angle)
        + axis * np.dot(axis, value) * (1 - math.cos(angle))
    )


def parse_plot3d(payload: bytes) -> list[np.ndarray]:
    values = np.fromstring(payload.decode("ascii"), sep=" ")
    if values.size < 7:
        raise ValueError("PLOT3D file is truncated")
    block_count = int(values[0])
    if block_count != 2:
        raise ValueError(f"expected 2 PLOT3D blocks, found {block_count}")
    cursor = 1
    dimensions: list[tuple[int, int, int]] = []
    for _ in range(block_count):
        dimensions.append(tuple(int(v) for v in values[cursor : cursor + 3]))
        cursor += 3
    if dimensions != [(201, 401, 1), (1, 51, 1)]:
        raise ValueError(f"unexpected PLOT3D dimensions: {dimensions}")

    blocks: list[np.ndarray] = []
    for dimensions_for_block in dimensions:
        count = math.prod(dimensions_for_block)
        end = cursor + 3 * count
        if end > values.size:
            raise ValueError("PLOT3D coordinate payload is truncated")
        components = values[cursor:end].reshape(3, count)
        cursor = end
        block = np.stack(
            [
                components[component].reshape(
                    dimensions_for_block, order="F"
                )
                for component in range(3)
            ]
        )
        blocks.append(block)
    if cursor != values.size:
        raise ValueError(
            f"PLOT3D file has {values.size - cursor} unexpected trailing values"
        )
    return blocks


def surface_area(surface: np.ndarray) -> float:
    points = surface[:, :, :, 0].transpose(1, 2, 0)
    lower_left = points[:-1, :-1]
    lower_right = points[1:, :-1]
    upper_left = points[:-1, 1:]
    upper_right = points[1:, 1:]
    first = 0.5 * np.linalg.norm(
        np.cross(lower_right - lower_left, upper_left - lower_left), axis=2
    ).sum()
    second = 0.5 * np.linalg.norm(
        np.cross(upper_left - upper_right, lower_right - upper_right), axis=2
    ).sum()
    return finite(first + second)


def shortest_path(block: np.ndarray) -> np.ndarray:
    return block[:, 0, :, 0].transpose(1, 0)


def path_length(points: np.ndarray) -> float:
    return finite(np.linalg.norm(np.diff(points, axis=0), axis=1).sum())


def right_wing_proxy_fit(
    surface_source: np.ndarray,
    path_source: np.ndarray,
) -> dict[str, object]:
    surface = source_to_birdflow(
        surface_source[:, :, :, 0].transpose(1, 2, 0)
    )
    path = source_to_birdflow(path_source)
    span = normalize(path[-1] - path[0])

    # Invert makeWingFrame for side=-1.  Deviation rotates the neutral -Y
    # span toward -X; stroke rotates the span in the body Y/Z plane.
    stroke = math.atan2(float(span[2]), float(-span[1]))
    deviation = math.atan2(
        float(-span[0]), math.hypot(float(span[1]), float(span[2]))
    )
    body_x = np.asarray([1.0, 0.0, 0.0])
    body_z = np.asarray([0.0, 0.0, 1.0])
    normal_after_stroke = rotate(-body_z, body_x, -stroke)
    chord_before_pitch = rotate(body_x, normal_after_stroke, deviation)

    chord_angles: list[float] = []
    for fraction in SPAN_FRACTIONS:
        span_index = int(round(float(fraction) * 400))
        # The PLOT3D chordwise ordering runs from i=0 to i=200.  Projecting
        # that vector removes local spanwise bending before measuring pitch.
        chord = surface[200, span_index] - surface[0, span_index]
        chord -= span * np.dot(chord, span)
        chord = normalize(chord)
        angle = math.atan2(
            float(np.dot(span, np.cross(chord_before_pitch, chord))),
            float(np.dot(chord_before_pitch, chord)),
        )
        chord_angles.append(angle)

    unwrapped = np.unwrap(np.asarray(chord_angles))
    design = np.column_stack([np.ones(SPAN_FRACTIONS.size), SPAN_FRACTIONS])
    coefficients, _, _, _ = np.linalg.lstsq(design, unwrapped, rcond=None)
    fitted = design @ coefficients
    residual = unwrapped - fitted
    return {
        "strokeRadians": finite(stroke),
        "deviationRadians": finite(deviation),
        "pitchAtWingRootRadians": finite(coefficients[0]),
        "tipTwistRadians": finite(coefficients[1]),
        "spanwisePitchFitRMSRadians": finite(
            math.sqrt(float(np.mean(residual * residual)))
        ),
        "spanwisePitchFitMaximumRadians": finite(
            np.max(np.abs(residual))
        ),
        "sampledPitchRadians": vector(unwrapped),
    }


def dryad_audit(path: Path | None) -> dict[str, object]:
    if path is None:
        return {
            "provided": False,
            "datasetDOI": SONG_DATASET_DOI,
            "articleDOI": SONG_ARTICLE_DOI,
        }
    if not path.is_file():
        raise ValueError(f"Dryad TAR does not exist: {path}")
    with tarfile.open(path, "r") as archive:
        members = sorted(
            member.name for member in archive.getmembers() if member.isfile()
        )
    md5 = digest(path, "md5")
    return {
        "provided": True,
        "sourceFile": path.name,
        "datasetDOI": SONG_DATASET_DOI,
        "articleDOI": SONG_ARTICLE_DOI,
        "license": "CC0-1.0",
        "md5": md5,
        "sha256": digest(path, "sha256"),
        "expectedMD5": SONG_EXPECTED_MD5,
        "digestVerified": md5 == SONG_EXPECTED_MD5,
        "fileCount": len(members),
        "members": members,
        "containsRawReconstructedGeometry": False,
        "qualification": "reference-curves-only",
        "reason": (
            "The deposit contains MATLAB figure sources for phase curves and "
            "loads, but no reconstructed wing/body coordinate or mesh files."
        ),
    }


def build_audit(wing_grid_zip: Path, song_tar: Path | None) -> dict[str, object]:
    if not wing_grid_zip.is_file():
        raise ValueError(f"wing-grid ZIP does not exist: {wing_grid_zip}")
    archive_md5 = digest(wing_grid_zip, "md5")
    expected_names = [f"wing_grid/grid{index:02d}.xyz" for index in range(1, 18)]

    raw_frames: list[tuple[np.ndarray, np.ndarray]] = []
    with zipfile.ZipFile(wing_grid_zip) as archive:
        names = set(archive.namelist())
        missing = [name for name in expected_names if name not in names]
        if missing:
            raise ValueError(
                "wing-grid ZIP is missing: " + ", ".join(missing)
            )
        readme = archive.read("wing_grid/readme.txt").decode("utf-8")
        for name in expected_names:
            surface, line = parse_plot3d(archive.read(name))
            raw_frames.append((surface, shortest_path(line)))

    raw_path_lengths = np.asarray(
        [path_length(line) for _, line in raw_frames]
    )
    raw_areas = np.asarray([surface_area(surface) for surface, _ in raw_frames])
    meters_per_source_unit = (
        PUBLISHED_MEAN_SHORTEST_PATH_METERS / float(raw_path_lengths.mean())
    )
    areas = raw_areas * meters_per_source_unit * meters_per_source_unit
    path_lengths = raw_path_lengths * meters_per_source_unit
    roots = np.stack([line[0] for _, line in raw_frames])
    root_mean = roots.mean(axis=0)
    root_drift = np.linalg.norm(roots - root_mean, axis=1)

    frames: list[dict[str, object]] = []
    maximum_pitch_fit_rms = 0.0
    maximum_pitch_fit_maximum = 0.0
    for index, ((surface, line), area, length) in enumerate(
        zip(raw_frames, areas, path_lengths), start=1
    ):
        fit = right_wing_proxy_fit(surface, line)
        maximum_pitch_fit_rms = max(
            maximum_pitch_fit_rms,
            float(fit["spanwisePitchFitRMSRadians"]),
        )
        maximum_pitch_fit_maximum = max(
            maximum_pitch_fit_maximum,
            float(fit["spanwisePitchFitMaximumRadians"]),
        )
        tip_relative = source_to_birdflow(line[-1] - line[0])
        frames.append(
            {
                "grid": expected_names[index - 1],
                "sourcePhase": finite(
                    SOURCE_PHASE_START + (index - 1) * SOURCE_PHASE_INTERVAL
                ),
                "surfaceAreaSquareMeters": finite(area),
                "shortestPathLengthMeters": finite(length),
                "wingTipBirdFlowRootRelativeMeters": vector(
                    tip_relative * meters_per_source_unit
                ),
                "proxyKinematics": fit,
            }
        )

    mean_area = finite(areas.mean())
    area_error = finite(
        (mean_area - PUBLISHED_MEAN_AREA_SQUARE_METERS)
        / PUBLISHED_MEAN_AREA_SQUARE_METERS
    )
    dryad = dryad_audit(song_tar)
    digest_passed = archive_md5 == MAEDA_EXPECTED_MD5
    dryad_digest_passed = (
        not dryad.get("provided", False) or dryad.get("digestVerified") is True
    )
    source_integrity_passed = digest_passed and dryad_digest_passed

    return {
        "schemaVersion": 1,
        "auditIdentifier": "maeda-2017-hovering-wing-source-audit-v1",
        "generatedBy": "Scripts/import-measured-wing-grid.py",
        "sources": {
            "measuredWingGrid": {
                "sourceFile": wing_grid_zip.name,
                "datasetDOI": MAEDA_DATASET_DOI,
                "articleDOI": MAEDA_ARTICLE_DOI,
                "license": "CC-BY-4.0",
                "md5": archive_md5,
                "sha256": digest(wing_grid_zip, "sha256"),
                "expectedMD5": MAEDA_EXPECTED_MD5,
                "digestVerified": digest_passed,
                "description": (
                    "Measured right-wing surface over one hovering wingbeat "
                    "for one Amazilia amazilia individual."
                ),
            },
            "songDryadCandidate": dryad,
        },
        "publishedMeasurements": {
            "species": "Amazilia amazilia",
            "specimenIdentifier": (
                "single zoo individual; sex and exact age unreported; at least 10 years old"
            ),
            "frequencyHz": PUBLISHED_FREQUENCY_HZ,
            "wingbeatPeriodSeconds": 0.0348,
            "frameCount": FRAME_COUNT,
            "sourcePhaseStart": SOURCE_PHASE_START,
            "sourcePhaseInterval": SOURCE_PHASE_INTERVAL,
            "meanShortestPathLengthMeters": PUBLISHED_MEAN_SHORTEST_PATH_METERS,
            "meanWingLengthMeters": 0.0693,
            "meanSurfaceAreaSquareMeters": PUBLISHED_MEAN_AREA_SQUARE_METERS,
            "meanChordMeters": 0.0195,
            "strokeAmplitudeRadians": math.radians(103.0),
            "strokePlaneAngleRadians": math.radians(11.7),
            "spatialReconstructionRMSMeters": PUBLISHED_SPATIAL_RMS_METERS,
        },
        "coordinateRegistration": {
            "sourceAxes": {
                "x": "backward",
                "y": "right",
                "z": "up",
            },
            "birdFlowAxes": {
                "x": "forward",
                "y": "left",
                "z": "up",
            },
            "sourceToBirdFlow": [
                [-1.0, 0.0, 0.0],
                [0.0, -1.0, 0.0],
                [0.0, 0.0, 1.0],
            ],
            "originForDerivedMotion": "measured wing base",
            "metersPerSourceUnit": finite(meters_per_source_unit),
            "scaleMethod": (
                "The PLOT3D README omits length units. Scale is locked by "
                "matching the deposited shortest-path block cycle mean to "
                "the article's measured 70.0 mm mean shortest-path length."
            ),
        },
        "gridAudit": {
            "surfaceDimensions": [201, 401, 1],
            "shortestPathDimensions": [1, 51, 1],
            "frameCount": len(frames),
            "meanShortestPathLengthMeters": finite(path_lengths.mean()),
            "minimumShortestPathLengthMeters": finite(path_lengths.min()),
            "maximumShortestPathLengthMeters": finite(path_lengths.max()),
            "meanSurfaceAreaSquareMeters": mean_area,
            "minimumSurfaceAreaSquareMeters": finite(areas.min()),
            "maximumSurfaceAreaSquareMeters": finite(areas.max()),
            "publishedMeanAreaRelativeError": area_error,
            "maximumWingBaseDriftMeters": finite(
                root_drift.max() * meters_per_source_unit
            ),
            "maximumSpanwisePitchFitRMSRadians": finite(maximum_pitch_fit_rms),
            "maximumSpanwisePitchFitMaximumRadians": finite(
                maximum_pitch_fit_maximum
            ),
            "readme": readme.strip(),
        },
        "frames": frames,
        "schema1Readiness": {
            "sourceIntegrityPassed": source_integrity_passed,
            "measuredRightWingSurfaceAndMotionAvailable": True,
            "analyticProxyKinematicsDerived": True,
            "readyForCompleteCoupledBirdReplay": False,
            "blockingFields": [
                "geometry.bodyRadiiMeters",
                "geometry.massKilograms",
                "geometry.principalInertiaKilogramMetersSquared",
                "geometry.wingRootOffsetMeters relative to body COM",
                "geometry.tailLengthMeters",
                "geometry.tailHalfWidthMeters",
                "geometry.tailThicknessMeters",
                "measured left-wing surface/kinematics",
                "measured or explicitly regularized wing thickness",
            ],
            "nonBlockingTransformWork": [
                "fit a fixed tapered planform and report surface-distance residuals",
                "differentiate the periodic proxy angles into physical angular rates",
                "choose a phase-zero interpolation policy for the unobserved 0.94T-to-0.019T gap",
            ],
            "scientificVerdict": (
                "Measured right-wing ingestion is qualified, but whole-bird "
                "schema-1 replay is blocked. Do not substitute another specimen's "
                "body or estimated inertia without an explicit derived-input tier."
            ),
        },
    }


def resample_polyline(points: np.ndarray, count: int) -> np.ndarray:
    """Resample a polyline at uniform normalized arc-length positions."""
    if count < 2:
        raise ValueError("surface sample counts must be at least 2")
    lengths = np.concatenate(
        [np.asarray([0.0]), np.cumsum(np.linalg.norm(np.diff(points, axis=0), axis=1))]
    )
    if lengths[-1] <= 1e-12:
        raise ValueError("degenerate shortest-path block")
    targets = np.linspace(0.0, lengths[-1], count)
    result = np.empty((count, 3), dtype=np.float64)
    for component in range(3):
        result[:, component] = np.interp(targets, lengths, points[:, component])
    return result


def build_surface_dataset(
    wing_grid_zip: Path,
    chord_count: int,
    span_count: int,
) -> dict[str, object]:
    """Create the compact, periodic, wing-only replay representation."""
    if chord_count < 2 or span_count < 2:
        raise ValueError("surface sample counts must be at least 2")
    names = [f"wing_grid/grid{index:02d}.xyz" for index in range(1, 18)]
    frames: list[tuple[np.ndarray, np.ndarray]] = []
    with zipfile.ZipFile(wing_grid_zip) as archive:
        for name in names:
            surface, line = parse_plot3d(archive.read(name))
            frames.append((surface, shortest_path(line)))

    mean_path = np.mean([path_length(line) for _, line in frames])
    scale = PUBLISHED_MEAN_SHORTEST_PATH_METERS / mean_path
    chord_indices = np.rint(np.linspace(0, 200, chord_count)).astype(int)
    span_indices = np.rint(np.linspace(0, 400, span_count)).astype(int)
    phases: list[float] = []
    vertices: list[float] = []
    paths: list[float] = []
    maximum_radius = 0.0

    for frame_index, (surface_block, path_source) in enumerate(frames):
        root_source = path_source[0]
        surface_source = surface_block[:, :, :, 0].transpose(1, 2, 0)
        sampled_surface = surface_source[np.ix_(chord_indices, span_indices)]
        sampled_path = resample_polyline(path_source, span_count)
        surface_meters = source_to_birdflow(
            sampled_surface - root_source
        ) * scale
        path_meters = source_to_birdflow(sampled_path - root_source) * scale
        phases.append(
            finite(SOURCE_PHASE_START + frame_index * SOURCE_PHASE_INTERVAL)
        )
        # Frame-major, then span-major, then chord-major matches the Metal
        # index chord + chordCount * span.
        vertices.extend(
            finite(value)
            for value in surface_meters.transpose(1, 0, 2).reshape(-1)
        )
        paths.extend(finite(value) for value in path_meters.reshape(-1))
        maximum_radius = max(
            maximum_radius,
            float(np.linalg.norm(surface_meters, axis=2).max()),
        )

    return {
        "schemaVersion": 1,
        "datasetIdentifier": "maeda-2017-hovering-right-wing-surface-v1",
        "scientificTier": "measured-wing-only",
        "source": {
            "sourceFile": wing_grid_zip.name,
            "datasetDOI": MAEDA_DATASET_DOI,
            "articleDOI": MAEDA_ARTICLE_DOI,
            "license": "CC-BY-4.0",
            "md5": digest(wing_grid_zip, "md5"),
            "sha256": digest(wing_grid_zip, "sha256"),
        },
        "frequencyHz": PUBLISHED_FREQUENCY_HZ,
        "phases": phases,
        "chordCount": chord_count,
        "spanCount": span_count,
        "verticesMeters": vertices,
        "shortestPathMeters": paths,
        "maximumRootRelativeRadiusMeters": finite(maximum_radius),
        "regularization": {
            "wingThickness": "not measured; supplied by replay request in lattice cells",
            "periodicInterpolation": "piecewise-linear with last-to-first phase wrap",
            "velocity": "analytic derivative of the same piecewise-linear interpolation",
            "downsampling": (
                f"deterministic endpoint-inclusive {chord_count}x{span_count} "
                "structured samples from each 201x401 measured surface"
            ),
        },
        "coordinateRegistration": {
            "axes": "BirdFlow forward/left/up",
            "origin": "measured right-wing base independently in every frame",
            "metersPerSourceUnit": finite(scale),
        },
        "completeBirdReplayReady": False,
    }


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit a measured hummingbird wing-grid deposit"
    )
    parser.add_argument(
        "--input",
        required=True,
        type=Path,
        help="Maeda et al. rsos170307_si_008.zip",
    )
    parser.add_argument(
        "--song-dryad-tar",
        type=Path,
        help="Optional Song et al. Dryad Data.tar candidate",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="Write JSON to this path instead of stdout",
    )
    parser.add_argument(
        "--surface-output",
        type=Path,
        help="Write compact measured-wing-only surface JSON to this path",
    )
    parser.add_argument(
        "--surface-chord-count",
        type=int,
        default=21,
        help="Endpoint-inclusive compact chordwise sample count (default: 21)",
    )
    parser.add_argument(
        "--surface-span-count",
        type=int,
        default=41,
        help="Endpoint-inclusive compact spanwise sample count (default: 41)",
    )
    parser.add_argument(
        "--require-complete-bird",
        action="store_true",
        help="Exit 2 unless the source is ready for complete coupled-bird replay",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        report = build_audit(arguments.input, arguments.song_dryad_tar)
    except (OSError, ValueError, tarfile.TarError, zipfile.BadZipFile) as error:
        print(f"measured-wing import failed: {error}", file=sys.stderr)
        return 1
    encoded = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if arguments.output:
        arguments.output.write_text(encoded, encoding="utf-8")
    else:
        sys.stdout.write(encoded)
    if arguments.surface_output:
        try:
            surface = build_surface_dataset(
                arguments.input,
                arguments.surface_chord_count,
                arguments.surface_span_count,
            )
            arguments.surface_output.write_text(
                json.dumps(surface, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
        except (OSError, ValueError, zipfile.BadZipFile) as error:
            print(f"measured-wing surface conversion failed: {error}", file=sys.stderr)
            return 1
    if not report["schema1Readiness"]["sourceIntegrityPassed"]:
        print("measured source digest does not match its published lock", file=sys.stderr)
        return 3
    if (
        arguments.require_complete_bird
        and not report["schema1Readiness"]["readyForCompleteCoupledBirdReplay"]
    ):
        print(
            "complete coupled-bird replay blocked by missing measured fields",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

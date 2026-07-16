#!/usr/bin/env python3
"""Register the Deetjen OB-F03 measured-force window to BirdFlow.

The converter reads the deposited force arrays and two independently locked
MATLAB scripts.  It reconstructs the camera/force timing in two ways, proves
the platform-to-world component mapping from the authors' analysis code, and
writes only the two experimentally measured BirdFlow components.  It never
fills the unavailable lateral component with zero.
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
    from scipy.io import loadmat
except ImportError as error:
    raise SystemExit(
        "register-dove-force-window.py requires NumPy and SciPy: " + str(error)
    ) from error


DEFAULT_QUALIFICATION = Path(
    "ValidationArtifacts/deetjen-dove-source-qualification.json"
)
DEFAULT_INGESTION = Path(
    "ValidationArtifacts/deetjen-dove-engineering-ingestion.json"
)
DEFAULT_SURFACE = Path("ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json")
DEFAULT_TARGET = Path("ValidationInputs/deetjen-ob-f03-force-v1.json")
DEFAULT_AUDIT = Path("ValidationArtifacts/deetjen-dove-force-registration.json")
CHUNK_BYTES = 4 * 1024 * 1024


def fail(message: str) -> None:
    raise SystemExit(message)


def extracted_path(root: Path, archive_path: str) -> Path:
    relative = Path(archive_path)
    if relative.parts[0] != "DoveMuscles_DataCode" or ".." in relative.parts:
        fail(f"unsafe archive member path: {archive_path}")
    return root.joinpath(*relative.parts[1:])


def file_digests(path: Path) -> tuple[int, str, str]:
    size = 0
    crc = 0
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(CHUNK_BYTES):
            size += len(chunk)
            crc = binascii.crc32(chunk, crc)
            digest.update(chunk)
    return size, f"{crc & 0xFFFFFFFF:08x}", digest.hexdigest()


def sha256(path: Path) -> str:
    return file_digests(path)[2]


def nearest_indices(samples: np.ndarray, targets: np.ndarray) -> np.ndarray:
    upper = np.searchsorted(samples, targets, side="left")
    upper = np.clip(upper, 0, len(samples) - 1)
    lower = np.clip(upper - 1, 0, len(samples) - 1)
    choose_upper = np.abs(samples[upper] - targets) < np.abs(samples[lower] - targets)
    return np.where(choose_upper, upper, lower)


def source_line(path: Path, fragment: str) -> dict:
    lines = path.read_text(errors="strict").splitlines()
    matches = [(index + 1, line.strip()) for index, line in enumerate(lines) if fragment in line]
    if len(matches) != 1:
        fail(
            f"expected one occurrence of {fragment!r} in {path}, found {len(matches)}"
        )
    line_number, text = matches[0]
    return {"line": line_number, "text": text}


def force_summary(values: np.ndarray, dt: float) -> dict:
    impulse = float(np.trapezoid(values, dx=dt))
    return {
        "minimumNewtons": float(np.min(values)),
        "maximumNewtons": float(np.max(values)),
        "meanNewtons": float(np.mean(values)),
        "rmsNewtons": float(np.sqrt(np.mean(np.square(values)))),
        "trapezoidalImpulseNewtonSeconds": impulse,
    }


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
    temporary.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Register the measured Deetjen force window to BirdFlow axes and time"
    )
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--qualification", type=Path, default=DEFAULT_QUALIFICATION)
    parser.add_argument("--ingestion", type=Path, default=DEFAULT_INGESTION)
    parser.add_argument("--surface", type=Path, default=DEFAULT_SURFACE)
    parser.add_argument("--output", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--audit", type=Path, default=DEFAULT_AUDIT)
    arguments = parser.parse_args()

    qualification_bytes = arguments.qualification.read_bytes()
    qualification = json.loads(qualification_bytes)
    ingestion = json.loads(arguments.ingestion.read_bytes())
    surface = json.loads(arguments.surface.read_bytes())
    selected = qualification["selectedBenchmark"]
    if selected["flightIdentifier"] != "2018_12_11_OB_F03":
        fail("unexpected selected Deetjen flight")

    required_by_role = {
        member["role"]: member for member in selected["requiredArchiveMembers"]
    }
    force_lock = required_by_role[
        "processed aerodynamic-force-platform and muscle channels"
    ]
    analysis_lock = required_by_role[
        "authors' synchronized derived blade-element, force, inertial, and muscle analysis product"
    ]
    force_path = extracted_path(arguments.input, force_lock["path"])
    analysis_path = extracted_path(arguments.input, analysis_lock["path"])

    verified_data = {}
    ingestion_locks = {
        member["archivePath"]: member
        for member in ingestion["sourceMemberVerification"]
    }
    for name, lock, path in (
        ("forceChannels", force_lock, force_path),
        ("derivedAnalysis", analysis_lock, analysis_path),
    ):
        if not path.is_file():
            fail(f"missing extracted source member: {path}")
        size, crc32, digest = file_digests(path)
        if size != lock["bytes"] or crc32 != lock["crc32"]:
            fail(f"qualified source lock mismatch: {path}")
        ingestion_lock = ingestion_locks.get(lock["path"])
        if ingestion_lock is None or ingestion_lock["sha256"] != digest:
            fail(f"engineering-ingestion SHA-256 mismatch: {path}")
        verified_data[name] = {
            "archivePath": lock["path"],
            "bytes": size,
            "crc32": crc32,
            "sha256": digest,
        }

    code_paths = {}
    code_locks = {}
    for lock in selected["forceRegistrationCodeMembers"]:
        path = extracted_path(arguments.input, lock["path"])
        if not path.is_file():
            fail(
                f"missing force-registration source: {path}; acquire with "
                "--include-force-code"
            )
        size, crc32, digest = file_digests(path)
        if (
            size != lock["bytes"]
            or crc32 != lock["crc32"]
            or digest != lock["sha256"]
        ):
            fail(f"force-registration code lock mismatch: {path}")
        code_paths[lock["role"]] = path
        code_locks[lock["role"]] = {
            "archivePath": lock["path"],
            "bytes": size,
            "crc32": crc32,
            "sha256": digest,
        }

    processing_path = code_paths[
        "force-platform processing, sign convention, and camera-time synchronization source"
    ]
    model_path = code_paths[
        "mapping from platform horizontal force into the reconstructed world frame"
    ]
    source_evidence = {
        "cameraFrameZero": source_line(
            processing_path, "Camera frame 0 corresponds to time = 0s"
        ),
        "forceRate": source_line(processing_path, "AFP_Hz = 2000;"),
        "kinematicsRate": source_line(processing_path, "SLS_Hz = 1000;"),
        "cameraTimeEquation": source_line(
            processing_path, "AFP_t = (0:AFP_dt:AFP_dt*(AFP_n-1))"
        ),
        "cameraFrameTimeEquation": source_line(
            processing_path, "SLS_t=(frame#)/1000"
        ),
        "externalVerticalSign": source_line(
            processing_path, "trapz(-FzWings(TOend:LDstart)"
        ),
        "externalHorizontalSign": source_line(
            processing_path, "trapz(-FxWings(TOend:LDstart)"
        ),
        "nearestFrameEquation": source_line(
            model_path, "find(abs(AFP_t-(StartFrame+f2-1)/FPS)"
        ),
        "horizontalChannelToWorldY": source_line(
            model_path, "AeroFy = FxWings(AeroF2)/2;"
        ),
        "verticalChannelToWorldZ": source_line(
            model_path, "AeroFz = FzWings(AeroF2)/2;"
        ),
        "externalVerticalAnalysisSign": source_line(
            model_path, "AeroF1_w(f2,3) = -AeroFz(f2);"
        ),
    }

    force = loadmat(
        force_path,
        variable_names=["AFP_t", "BodyWeight", "FxWings", "FzWings"],
        squeeze_me=True,
    )
    analysis = loadmat(
        analysis_path,
        variable_names=["AeroF1S_w", "BodyPos_w"],
        squeeze_me=True,
    )
    afp_time = np.asarray(force["AFP_t"], dtype=np.float64).reshape(-1)
    fx_stored = np.asarray(force["FxWings"], dtype=np.float64).reshape(-1)
    fz_stored = np.asarray(force["FzWings"], dtype=np.float64).reshape(-1)
    if not (len(afp_time) == len(fx_stored) == len(fz_stored)):
        fail("force-channel lengths differ")

    frame_numbers = np.asarray(surface["frames"]["frameNumbers"], dtype=np.int64)
    surface_times = np.asarray(surface["frames"]["timesSeconds"], dtype=np.float64)
    kinematics_rate = float(surface["frames"]["sampleRateHertz"])
    if len(frame_numbers) != len(surface_times):
        fail("surface frame-number and time arrays differ")
    if surface["frames"]["periodic"]:
        fail("the deposited dove window must remain non-periodic")
    source_frame_times = frame_numbers.astype(np.float64) / kinematics_rate
    nearest = nearest_indices(afp_time, source_frame_times)

    zero_samples = np.flatnonzero(afp_time == 0.0)
    if len(zero_samples) != 1:
        fail("deposited AFP time must contain exactly one camera-zero sample")
    force_dt = float(np.median(np.diff(afp_time)))
    reconstructed_force_rate = 1.0 / force_dt
    force_rate = float(selected["aerodynamicForceSampleRateHertz"])
    samples_per_frame = int(round(force_rate / kinematics_rate))
    arithmetic = int(zero_samples[0]) + frame_numbers * samples_per_frame
    high_rate_start = int(arithmetic[0])
    high_rate_end = int(arithmetic[-1])
    high_rate_indices = np.arange(high_rate_start, high_rate_end + 1, dtype=np.int64)
    target_times = np.arange(len(high_rate_indices), dtype=np.float64) / force_rate
    surface_coordinates = np.arange(len(high_rate_indices), dtype=np.float64) / samples_per_frame
    target_fx = -fx_stored[high_rate_indices]
    target_fz = -fz_stored[high_rate_indices]
    analysis_frame_start = int(selected["analysisFrameStart"])
    analysis_frame_end = int(selected["analysisFrameEnd"])
    comparison_first = (
        analysis_frame_start - int(frame_numbers[0])
    ) * samples_per_frame
    comparison_last = (
        analysis_frame_end - int(frame_numbers[0])
    ) * samples_per_frame

    source_world_to_birdflow = np.asarray(
        [[0.0, 1.0, 0.0], [-1.0, 0.0, 0.0], [0.0, 0.0, 1.0]],
        dtype=np.float64,
    )
    coordinate = surface["coordinateFrame"]
    if coordinate["mapping"] != "[birdFlowX,birdFlowY,birdFlowZ]=[sourceY,-sourceX,sourceZ]":
        fail("surface coordinate mapping changed")

    aero_force = np.asarray(analysis["AeroF1S_w"], dtype=np.float64)
    body_position = np.asarray(analysis["BodyPos_w"], dtype=np.float64)
    if aero_force.shape != (len(frame_numbers), 3):
        fail("derived force cross-check shape changed")
    if body_position.shape != (len(frame_numbers), 3):
        fail("body trajectory cross-check shape changed")
    vertical_crosscheck = aero_force[:, 2] - (-fz_stored[nearest] / 2.0)
    trajectory_displacement = body_position[-1] - body_position[0]
    trajectory_norm = float(np.linalg.norm(trajectory_displacement))
    forward_dominance = float(abs(trajectory_displacement[1]) / trajectory_norm)

    nearest_residual = afp_time[nearest] - source_frame_times
    normalized_source_times = afp_time[high_rate_indices] - afp_time[high_rate_start]
    checks = {
        "qualifiedDataLocks": len(verified_data) == 2,
        "qualifiedCodeLocks": len(code_locks) == 2,
        "sourceEvidenceLocated": len(source_evidence) == 11,
        "forceRate": math.isclose(
            reconstructed_force_rate, force_rate, rel_tol=1.0e-9
        ),
        "samplesPerKinematicsInterval": samples_per_frame == 2,
        "nearestAndArithmeticIndicesAgree": bool(np.array_equal(nearest, arithmetic)),
        "firstForceIndex": high_rate_start == 191878,
        "lastForceIndex": high_rate_end == 192164,
        "forceSampleCount": len(high_rate_indices) == 287,
        "comparisonWindowInsideTarget": (
            0 < comparison_first < comparison_last < len(high_rate_indices) - 1
            and comparison_first == 50
            and comparison_last == 236
        ),
        "nearestTimingResidual": float(np.max(np.abs(nearest_residual))) <= 1.0e-12,
        "sourceTimeNormalization": float(
            np.max(np.abs(normalized_source_times - target_times))
        ) <= 1.0e-12,
        "surfaceHalfStepRegistration": float(
            np.max(np.abs(target_times[::samples_per_frame] - surface_times))
        ) <= 1.0e-15,
        "rightHandedFrameTransform": math.isclose(
            float(np.linalg.det(source_world_to_birdflow)), 1.0, abs_tol=1.0e-15
        ),
        "derivedVerticalSignAndTiming": float(
            np.max(np.abs(vertical_crosscheck))
        ) <= 1.0e-12,
        "trajectoryEstablishesPositiveWorldYAsForward": (
            trajectory_displacement[1] > 0.0 and forward_dominance >= 0.9
        ),
        "finiteMeasuredTargets": bool(
            np.isfinite(target_fx).all() and np.isfinite(target_fz).all()
        ),
    }

    target = {
        "schemaVersion": 1,
        "datasetIdentifier": "deetjen-ob-2018-12-11-f03-measured-force-v1",
        "scientificTier": "source-processed-measured-two-component-force",
        "source": {
            "datasetDOI": "10.5061/dryad.wwpzgmsqs",
            "articleDOI": "10.7554/eLife.89968",
            "flightIdentifier": selected["flightIdentifier"],
            "license": "CC0-1.0",
            "qualificationSHA256": hashlib.sha256(qualification_bytes).hexdigest(),
            "surfaceManifestSHA256": sha256(arguments.surface),
            "members": list(verified_data.values()) + list(code_locks.values()),
        },
        "coordinateFrame": {
            "name": "BirdFlow laboratory frame relative to frame-zero body origin",
            "axes": {"x": "forward", "y": "left", "z": "up"},
            "sourceWorldAxes": coordinate["sourceAxes"],
            "sourceWorldToBirdFlow": source_world_to_birdflow.tolist(),
            "storedReactionToExternalMultiplier": -1,
            "measuredComponentMapping": {
                "forceXNewtons": "-FxWings (platform horizontal -> source world +y -> BirdFlow +x)",
                "forceZNewtons": "-FzWings (platform vertical -> source world +z -> BirdFlow +z)",
            },
        },
        "componentCoverage": {
            "measured": ["forceXNewtons", "forceZNewtons"],
            "unavailable": [
                "forceYNewtons",
                "aerodynamic torque",
                "per-wing force split",
            ],
            "unavailableComponentsAreNotZeroFilled": True,
        },
        "synchronization": {
            "forceSampleRateHertz": force_rate,
            "sourceForceSampleRateHertzReconstructed": reconstructed_force_rate,
            "kinematicsSampleRateHertz": kinematics_rate,
            "samplesPerKinematicsInterval": samples_per_frame,
            "sourceCameraZeroForceIndexZeroBased": int(zero_samples[0]),
            "firstSourceFrame": int(frame_numbers[0]),
            "lastSourceFrame": int(frame_numbers[-1]),
            "firstForceSampleIndexZeroBased": high_rate_start,
            "lastForceSampleIndexZeroBased": high_rate_end,
            "sampleCount": int(len(high_rate_indices)),
            "durationSeconds": float(target_times[-1]),
            "surfaceSampling": (
                "even force samples coincide with stored surface frames; odd samples "
                "use the manifest's piecewise-linear interpolation at alpha=0.5"
            ),
        },
        "comparisonWindow": {
            "sourceDefinition": "selected flight analysisFrameStart...analysisFrameEnd",
            "firstSourceFrame": analysis_frame_start,
            "lastSourceFrame": analysis_frame_end,
            "firstTargetSampleIndex": int(comparison_first),
            "lastTargetSampleIndex": int(comparison_last),
            "sampleCount": int(comparison_last - comparison_first + 1),
            "firstTimeSeconds": float(target_times[comparison_first]),
            "lastTimeSeconds": float(target_times[comparison_last]),
            "preRollSeconds": float(target_times[comparison_first]),
            "postRollSeconds": float(target_times[-1] - target_times[comparison_last]),
            "comparisonRule": (
                "advance through pre-roll before scoring; compare only this inclusive "
                "window; retain post-roll for nonperiodic endpoint kinematics"
            ),
        },
        "samples": {
            "timesSeconds": target_times.tolist(),
            "surfaceFrameCoordinates": surface_coordinates.tolist(),
            "forceXNewtons": target_fx.tolist(),
            "forceZNewtons": target_fz.tolist(),
        },
        "summary": {
            "bodyWeightNewtons": float(force["BodyWeight"]),
            "forceX": force_summary(target_fx, 1.0 / force_rate),
            "forceZ": force_summary(target_fz, 1.0 / force_rate),
        },
        "claimBoundary": (
            "This target contains only the deposited, source-processed horizontal and "
            "vertical external force on the bird. It does not supply lateral force, "
            "torque, per-wing loads, raw sensor uncertainty, or a CFD result."
        ),
    }
    write_json(arguments.output, target)

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-force-registration-v1",
        "generatedBy": "Scripts/register-dove-force-window.py",
        "target": str(arguments.output),
        "targetSHA256": sha256(arguments.output),
        "sourceLocks": {
            "qualificationSHA256": hashlib.sha256(qualification_bytes).hexdigest(),
            "surfaceManifestSHA256": sha256(arguments.surface),
            "data": verified_data,
            "code": code_locks,
        },
        "sourceCodeEvidence": source_evidence,
        "registration": {
            "storedPlatformVector": "[FxWings,FzWings]",
            "externalSourceWorldVector": "[unmeasured,-FxWings,-FzWings]",
            "sourceWorldToBirdFlow": source_world_to_birdflow.tolist(),
            "birdFlowMeasuredVector": "[-FxWings,unmeasured,-FzWings]",
            "determinant": float(np.linalg.det(source_world_to_birdflow)),
        },
        "timing": {
            "forceRateHertz": force_rate,
            "sourceForceRateHertzReconstructed": reconstructed_force_rate,
            "kinematicsRateHertz": kinematics_rate,
            "cameraZeroIndexZeroBased": int(zero_samples[0]),
            "firstIndexZeroBased": high_rate_start,
            "lastIndexZeroBased": high_rate_end,
            "sampleCount": int(len(high_rate_indices)),
            "comparisonFirstTargetSampleIndex": int(comparison_first),
            "comparisonLastTargetSampleIndex": int(comparison_last),
            "comparisonSampleCount": int(comparison_last - comparison_first + 1),
            "maximumNearestSampleResidualSeconds": float(
                np.max(np.abs(nearest_residual))
            ),
            "maximumNormalizedSourceTimeResidualSeconds": float(
                np.max(np.abs(normalized_source_times - target_times))
            ),
            "maximumSurfaceHalfStepResidualSeconds": float(
                np.max(np.abs(target_times[::samples_per_frame] - surface_times))
            ),
            "nearestArithmeticIndexMismatchCount": int(
                np.count_nonzero(nearest != arithmetic)
            ),
        },
        "independentCrossChecks": {
            "maximumDerivedPerWingVerticalResidualNewtons": float(
                np.max(np.abs(vertical_crosscheck))
            ),
            "bodyTrajectorySourceWorldDisplacementMillimeters": trajectory_displacement.tolist(),
            "positiveWorldYFractionOfTrajectoryDisplacement": forward_dominance,
        },
        "targetSummary": target["summary"],
        "checks": checks,
        "gatePassed": all(checks.values()),
        "readiness": {
            "coarsePrescribedMotionPilotReady": all(checks.values()),
            "experimentalForceAcceptanceReady": False,
            "remainingBeforeAcceptance": [
                "one coarse prescribed-motion fluid pilot",
                "five-flight OB repeatability and force-platform uncertainty",
                "time-step refinement",
                "8/12/16 spatial refinement",
            ],
        },
        "claimBoundary": target["claimBoundary"],
    }
    write_json(arguments.audit, audit)
    if not audit["gatePassed"]:
        failed = [name for name, passed in checks.items() if not passed]
        fail("force registration gate failed: " + ", ".join(failed))
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

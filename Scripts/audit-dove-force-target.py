#!/usr/bin/env python3
"""Independently audit the committed two-component Deetjen force target."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path


DEFAULT_TARGET = Path("ValidationInputs/deetjen-ob-f03-force-v1.json")
DEFAULT_AUDIT = Path("ValidationArtifacts/deetjen-dove-force-registration.json")
DEFAULT_OUTPUT = Path(
    "ValidationArtifacts/deetjen-dove-force-target-cpu-parity.json"
)
DEFAULT_SURFACE = Path("ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json")
DEFAULT_QUALIFICATION = Path(
    "ValidationArtifacts/deetjen-dove-source-qualification.json"
)


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def determinant3(matrix: list[list[float]]) -> float:
    return (
        matrix[0][0] * (matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])
        - matrix[0][1] * (matrix[1][0] * matrix[2][2] - matrix[1][2] * matrix[2][0])
        + matrix[0][2] * (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])
    )


def summarize(values: list[float], dt: float) -> dict:
    impulse = sum(
        0.5 * (values[index] + values[index + 1]) * dt
        for index in range(len(values) - 1)
    )
    return {
        "minimumNewtons": min(values),
        "maximumNewtons": max(values),
        "meanNewtons": sum(values) / len(values),
        "rmsNewtons": math.sqrt(sum(value * value for value in values) / len(values)),
        "trapezoidalImpulseNewtonSeconds": impulse,
    }


def close_summary(actual: dict, expected: dict, tolerance: float = 2.0e-15) -> bool:
    return all(
        math.isclose(actual[key], expected[key], rel_tol=tolerance, abs_tol=tolerance)
        for key in expected
    )


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit the committed Deetjen two-component force target"
    )
    parser.add_argument("--target", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--audit", type=Path, default=DEFAULT_AUDIT)
    parser.add_argument("--surface", type=Path, default=DEFAULT_SURFACE)
    parser.add_argument("--qualification", type=Path, default=DEFAULT_QUALIFICATION)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    target = json.loads(arguments.target.read_bytes())
    audit = json.loads(arguments.audit.read_bytes())
    surface = json.loads(arguments.surface.read_bytes())
    qualification = json.loads(arguments.qualification.read_bytes())
    if target.get("schemaVersion") != 1 or audit.get("schemaVersion") != 1:
        fail("unsupported force target or audit schema")

    synchronization = target["synchronization"]
    samples = target["samples"]
    times = samples["timesSeconds"]
    coordinates = samples["surfaceFrameCoordinates"]
    force_x = samples["forceXNewtons"]
    force_z = samples["forceZNewtons"]
    count = synchronization["sampleCount"]
    rate = synchronization["forceSampleRateHertz"]
    surface_times = surface["frames"]["timesSeconds"]
    matrix = target["coordinateFrame"]["sourceWorldToBirdFlow"]
    comparison = target["comparisonWindow"]

    qualification_code = {
        member["archivePath"]: member["sha256"]
        for member in target["source"]["members"]
        if member["archivePath"].endswith(".m")
    }
    expected_code = {
        member["path"]: member["sha256"]
        for member in qualification["selectedBenchmark"][
            "forceRegistrationCodeMembers"
        ]
    }
    expected_times = [index / rate for index in range(count)]
    expected_coordinates = [index / 2.0 for index in range(count)]
    checks = {
        "targetHash": sha256(arguments.target) == audit["targetSHA256"],
        "qualificationHash": (
            sha256(arguments.qualification)
            == target["source"]["qualificationSHA256"]
            == audit["sourceLocks"]["qualificationSHA256"]
        ),
        "surfaceHash": (
            sha256(arguments.surface)
            == target["source"]["surfaceManifestSHA256"]
            == audit["sourceLocks"]["surfaceManifestSHA256"]
        ),
        "codeLocks": qualification_code == expected_code,
        "sampleArrayLengths": len({len(times), len(coordinates), len(force_x), len(force_z), count}) == 1,
        "forceRate": math.isclose(rate, 2000.0, rel_tol=1.0e-12),
        "sampleCount": count == 287,
        "comparisonWindow": (
            comparison["firstSourceFrame"] == -1918
            and comparison["lastSourceFrame"] == -1825
            and comparison["firstTargetSampleIndex"] == 50
            and comparison["lastTargetSampleIndex"] == 236
            and comparison["sampleCount"] == 187
            and math.isclose(comparison["firstTimeSeconds"], 0.025)
            and math.isclose(comparison["lastTimeSeconds"], 0.118)
            and comparison["firstTimeSeconds"] == times[50]
            and comparison["lastTimeSeconds"] == times[236]
        ),
        "contiguousTime": max(abs(a - b) for a, b in zip(times, expected_times)) <= 1.0e-15,
        "surfaceCoordinates": max(
            abs(a - b) for a, b in zip(coordinates, expected_coordinates)
        ) <= 1.0e-15,
        "storedFrameRegistration": max(
            abs(a - b) for a, b in zip(times[::2], surface_times)
        ) <= 1.0e-15,
        "rightHandedTransform": math.isclose(
            determinant3(matrix), 1.0, abs_tol=1.0e-15
        ),
        "componentCoverage": (
            target["componentCoverage"]["measured"]
            == ["forceXNewtons", "forceZNewtons"]
            and "forceYNewtons" in target["componentCoverage"]["unavailable"]
            and target["componentCoverage"]["unavailableComponentsAreNotZeroFilled"]
            and "forceYNewtons" not in samples
        ),
        "finiteForces": all(math.isfinite(value) for value in force_x + force_z),
        "forceXSummary": close_summary(
            target["summary"]["forceX"], summarize(force_x, 1.0 / rate)
        ),
        "forceZSummary": close_summary(
            target["summary"]["forceZ"], summarize(force_z, 1.0 / rate)
        ),
        "registrationGate": bool(audit["gatePassed"] and all(audit["checks"].values())),
        "acceptanceStillOpen": not audit["readiness"]["experimentalForceAcceptanceReady"],
    }
    result = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-force-target-independent-audit-v1",
        "generatedBy": "Scripts/audit-dove-force-target.py",
        "targetSHA256": sha256(arguments.target),
        "checks": checks,
        "gatePassed": all(checks.values()),
        "metrics": {
            "sampleCount": count,
            "durationSeconds": times[-1],
            "storedSurfaceFrames": len(surface_times),
            "interpolatedHalfFrames": count - len(surface_times),
            "comparisonSamples": comparison["sampleCount"],
            "preRollSeconds": comparison["preRollSeconds"],
            "postRollSeconds": comparison["postRollSeconds"],
            "forceXImpulseNewtonSeconds": summarize(force_x, 1.0 / rate)[
                "trapezoidalImpulseNewtonSeconds"
            ],
            "forceZImpulseNewtonSeconds": summarize(force_z, 1.0 / rate)[
                "trapezoidalImpulseNewtonSeconds"
            ],
        },
        "claimBoundary": target["claimBoundary"],
    }
    if not result["gatePassed"]:
        failed = [name for name, passed in checks.items() if not passed]
        fail("independent force-target audit failed: " + ", ".join(failed))
    rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = arguments.output.with_name(arguments.output.name + ".tmp")
    temporary.write_text(rendered)
    temporary.replace(arguments.output)
    print(rendered, end="")


if __name__ == "__main__":
    main()

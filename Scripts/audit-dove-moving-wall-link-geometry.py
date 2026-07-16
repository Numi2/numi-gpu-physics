#!/usr/bin/env python3
"""Independently audit the frozen-phase D12/D16 production-link geometry result."""

from __future__ import annotations

from array import array
import hashlib
import json
import math
from pathlib import Path
import sys


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
INPUTS = ROOT / "ValidationInputs"
MANIFEST_PATH = INPUTS / "deetjen-ob-f03-surface-v1" / "manifest.json"
DURATION_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration-preregistration.json"
DURATION_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-audit.json"

Vector = tuple[float, float, float]
DIRECTIONS = (
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
)
WEIGHTS = (1 / 3,) + (1 / 18,) * 6 + (1 / 36,) * 12


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    return tuple(float(value) for value in raw)  # type: ignore[return-value]


def add(first: Vector, second: Vector) -> Vector:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def subtract(first: Vector, second: Vector) -> Vector:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def scale(value: Vector, factor: float) -> Vector:
    return tuple(component * factor for component in value)  # type: ignore[return-value]


def dot(first: Vector, second: Vector) -> float:
    return sum(a * b for a, b in zip(first, second))


def cross(first: Vector, second: Vector) -> Vector:
    return (
        first[1] * second[2] - first[2] * second[1],
        first[2] * second[0] - first[0] * second[2],
        first[0] * second[1] - first[1] * second[0],
    )


def magnitude(value: Vector) -> float:
    return math.sqrt(dot(value, value))


def close(first: float, second: float, tolerance: float = 2e-6) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector, tolerance: float = 2e-6) -> bool:
    return all(close(a, b, tolerance) for a, b in zip(first, second))


def relative_difference(first: float, second: float) -> float:
    return abs(first - second) / max(abs(first), abs(second), 1e-30)


def vector_relative_difference(first: Vector, second: Vector) -> float:
    return magnitude(subtract(first, second)) / max(
        magnitude(first), magnitude(second), 1e-30
    )


def histogram_tv(first: list[float], second: list[float]) -> float:
    first_total = sum(first)
    second_total = sum(second)
    return 0.5 * sum(
        abs(a / first_total - b / second_total) for a, b in zip(first, second)
    )


def read_array(path: Path, typecode: str) -> array:
    result = array(typecode)
    with path.open("rb") as handle:
        result.fromfile(handle, path.stat().st_size // result.itemsize)
    if sys.byteorder != "little":
        result.byteswap()
    return result


def d3q19_factor(normal: Vector) -> float:
    return sum(
        6.0 * WEIGHTS[index] * abs(dot(DIRECTIONS[index], normal))
        for index in range(1, 18, 2)
    )


def triangle_quadrature(manifest: dict, time_seconds: float) -> list[dict]:
    base = MANIFEST_PATH.parent
    positions_raw = read_array(base / manifest["binary"]["positions"]["file"], "f")
    triangles = read_array(base / manifest["binary"]["triangles"]["file"], "H")
    frame_count = int(manifest["frames"]["count"])
    vertex_count = len(positions_raw) // (3 * frame_count)
    times = [float(value) for value in manifest["frames"]["timesSeconds"]]
    first = max(index for index, value in enumerate(times[:-1]) if value <= time_seconds)
    second = first + 1
    duration = times[second] - times[first]
    blend = (time_seconds - times[first]) / duration

    def raw_point(frame: int, vertex: int) -> Vector:
        offset = 3 * (frame * vertex_count + vertex)
        return tuple(float(positions_raw[offset + axis]) for axis in range(3))  # type: ignore[return-value]

    positions = []
    velocities = []
    for vertex_index in range(vertex_count):
        a = raw_point(first, vertex_index)
        b = raw_point(second, vertex_index)
        delta = subtract(b, a)
        positions.append(add(a, scale(delta, blend)))
        velocities.append(scale(delta, 1.0 / duration))

    half_thickness = 0.0075
    result = []
    for component in manifest["topology"]["components"]:
        area_sum = 0.0
        measure = 0.0
        velocity_integral: Vector = (0.0, 0.0, 0.0)
        speed_squared_integral = 0.0
        edges: dict[tuple[int, int], list[object]] = {}
        start = int(component["triangleOffset"])
        end = start + int(component["triangleCount"])
        for triangle_index in range(start, end):
            indices = tuple(int(triangles[3 * triangle_index + axis]) for axis in range(3))
            a, b, c = (positions[index] for index in indices)
            raw_normal = cross(subtract(b, a), subtract(c, a))
            twice_area = magnitude(raw_normal)
            if twice_area == 0:
                continue
            normal = scale(raw_normal, 1.0 / twice_area)
            area = 0.5 * twice_area
            contribution = 2.0 * area * d3q19_factor(normal)
            velocity = scale(
                add(add(velocities[indices[0]], velocities[indices[1]]), velocities[indices[2]]),
                1.0 / 3.0,
            )
            area_sum += area
            measure += contribution
            velocity_integral = add(velocity_integral, scale(velocity, contribution))
            speed_squared_integral += contribution * dot(velocity, velocity)
            for first_index, second_index in (
                (indices[0], indices[1]),
                (indices[1], indices[2]),
                (indices[2], indices[0]),
            ):
                key = tuple(sorted((first_index, second_index)))
                if key in edges:
                    edges[key][0] = int(edges[key][0]) + 1
                else:
                    edges[key] = [1, first_index, second_index, normal]
        boundary_edges = [record for record in edges.values() if int(record[0]) == 1]
        for _, first_index, second_index, adjacent_normal in boundary_edges:
            first_index = int(first_index)
            second_index = int(second_index)
            edge = subtract(positions[second_index], positions[first_index])
            edge_length = magnitude(edge)
            raw_cap_normal = cross(edge, adjacent_normal)  # type: ignore[arg-type]
            cap_length = magnitude(raw_cap_normal)
            if edge_length == 0 or cap_length == 0:
                continue
            cap_normal = scale(raw_cap_normal, 1.0 / cap_length)
            contribution = 2.0 * half_thickness * edge_length * d3q19_factor(cap_normal)
            velocity = scale(add(velocities[first_index], velocities[second_index]), 0.5)
            measure += contribution
            velocity_integral = add(velocity_integral, scale(velocity, contribution))
            speed_squared_integral += contribution * dot(velocity, velocity)
        result.append(
            {
                "partIdentifier": int(component["partIdentifier"]),
                "componentName": component["name"],
                "triangleCount": int(component["triangleCount"]),
                "boundaryEdgeCount": len(boundary_edges),
                "midSurfaceAreaSquareMeters": area_sum,
                "thickenedD3Q19MeasureSquareMeters": measure,
                "meanWallVelocityMetersPerSecond": scale(velocity_integral, 1.0 / measure),
                "rmsWallSpeedMetersPerSecond": math.sqrt(speed_squared_integral / measure),
            }
        )
    return result


def aggregate_case(case: dict, preregistration: dict) -> tuple[list[dict], bool, float]:
    histogram_count = int(preregistration["interpolationFractionBinCount"])
    metal_bins = case["metalBins"]
    cpu_bins = case["cpuBins"]
    bins_valid = len(metal_bins) == len(cpu_bins) == 72
    maximum_cpu_difference = 0.0
    for index, (metal, cpu) in enumerate(zip(metal_bins, cpu_bins)):
        expected_part = index // 18 + 1
        expected_direction = index % 18 + 1
        bins_valid &= int(metal["partIdentifier"]) == expected_part
        bins_valid &= int(metal["directionIndex"]) == expected_direction
        bins_valid &= len(metal["interpolationFractionMeasureHistogram"]) == histogram_count
        bins_valid &= int(metal["linkCount"]) == int(cpu["linkCount"])
        bins_valid &= close(
            float(metal["linkMeasureSquareMeters"]),
            float(cpu["linkMeasureSquareMeters"]),
            1e-12,
        )
        for key in (
            "interpolationFractionIntegralSquareMeters",
            "interpolationFractionSquaredIntegralSquareMeters",
            "wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared",
        ):
            maximum_cpu_difference = max(
                maximum_cpu_difference,
                relative_difference(float(metal[key]), float(cpu[key])),
            )
        maximum_cpu_difference = max(
            maximum_cpu_difference,
            vector_relative_difference(
                vector(metal["wallVelocityIntegralSquareMeterMetersPerSecond"]),
                vector(cpu["wallVelocityIntegralSquareMeterMetersPerSecond"]),
            ),
        )
        measure = max(
            float(metal["linkMeasureSquareMeters"]),
            float(cpu["linkMeasureSquareMeters"]),
            1e-30,
        )
        maximum_cpu_difference = max(
            maximum_cpu_difference,
            max(
                abs(float(a) - float(b)) / measure
                for a, b in zip(
                    metal["interpolationFractionMeasureHistogram"],
                    cpu["interpolationFractionMeasureHistogram"],
                )
            ),
        )

    components = []
    for part in range(1, 5):
        selected = [item for item in metal_bins if int(item["partIdentifier"]) == part]
        measure = sum(float(item["linkMeasureSquareMeters"]) for item in selected)
        q_integral = sum(
            float(item["interpolationFractionIntegralSquareMeters"]) for item in selected
        )
        q2_integral = sum(
            float(item["interpolationFractionSquaredIntegralSquareMeters"]) for item in selected
        )
        histogram = [
            sum(float(item["interpolationFractionMeasureHistogram"][index]) for item in selected)
            for index in range(histogram_count)
        ]
        velocity_integral: Vector = (0.0, 0.0, 0.0)
        for item in selected:
            velocity_integral = add(
                velocity_integral,
                vector(item["wallVelocityIntegralSquareMeterMetersPerSecond"]),
            )
        speed2 = sum(
            float(item["wallSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared"])
            for item in selected
        )
        q_mean = q_integral / measure
        components.append(
            {
                "partIdentifier": part,
                "linkCount": sum(int(item["linkCount"]) for item in selected),
                "linkMeasureSquareMeters": measure,
                "interpolationFractionMean": q_mean,
                "interpolationFractionStandardDeviation": math.sqrt(
                    max(0.0, q2_integral / measure - q_mean * q_mean)
                ),
                "interpolationFractionMeasureHistogram": histogram,
                "meanWallVelocityMetersPerSecond": scale(velocity_integral, 1.0 / measure),
                "rmsWallSpeedMetersPerSecond": math.sqrt(speed2 / measure),
            }
        )
    return components, bins_valid, maximum_cpu_difference


def component_match(actual: dict, rebuilt: dict, quadrature: dict) -> bool:
    reference_rms = float(quadrature["rmsWallSpeedMetersPerSecond"])
    mean_velocity = rebuilt["meanWallVelocityMetersPerSecond"]
    rms_speed = rebuilt["rmsWallSpeedMetersPerSecond"]
    expected_mean_error = magnitude(
        subtract(mean_velocity, quadrature["meanWallVelocityMetersPerSecond"])
    ) / reference_rms
    expected_rms_error = abs(rms_speed - reference_rms) / reference_rms
    return (
        int(actual["partIdentifier"]) == int(rebuilt["partIdentifier"])
        and int(actual["linkCount"]) == int(rebuilt["linkCount"])
        and close(actual["linkMeasureSquareMeters"], rebuilt["linkMeasureSquareMeters"])
        and close(actual["interpolationFractionMean"], rebuilt["interpolationFractionMean"])
        and close(
            actual["interpolationFractionStandardDeviation"],
            rebuilt["interpolationFractionStandardDeviation"],
        )
        and all(
            close(float(a), float(b))
            for a, b in zip(
                actual["interpolationFractionMeasureHistogram"],
                rebuilt["interpolationFractionMeasureHistogram"],
            )
        )
        and vector_close(vector(actual["meanWallVelocityMetersPerSecond"]), mean_velocity)
        and close(actual["rmsWallSpeedMetersPerSecond"], rms_speed)
        and close(
            actual["linkToQuadratureMeasureRatio"],
            rebuilt["linkMeasureSquareMeters"]
            / quadrature["thickenedD3Q19MeasureSquareMeters"],
        )
        and close(actual["meanVelocityErrorRelativeToQuadratureRMS"], expected_mean_error)
        and close(actual["rmsSpeedRelativeError"], expected_rms_error)
    )


def main() -> None:
    manifest = load(MANIFEST_PATH)
    duration_preregistration = load(DURATION_PREREG_PATH)
    duration = load(DURATION_PATH)
    preregistration = load(PREREG_PATH)
    report = load(REPORT_PATH)
    quadrature = triangle_quadrature(
        manifest, float(preregistration["frozenSourceTimeSeconds"])
    )
    d12_components, d12_bins_valid, d12_cpu_difference = aggregate_case(
        report["d12"], preregistration
    )
    d16_components, d16_bins_valid, d16_cpu_difference = aggregate_case(
        report["d16"], preregistration
    )

    quadrature_valid = True
    component_summaries_valid = True
    for grid, rebuilt in (("d12", d12_components), ("d16", d16_components)):
        for index, actual in enumerate(report[grid]["components"]):
            stored_quadrature = actual["triangleQuadrature"]
            reference = quadrature[index]
            quadrature_valid &= int(stored_quadrature["partIdentifier"]) == int(
                reference["partIdentifier"]
            )
            quadrature_valid &= int(stored_quadrature["boundaryEdgeCount"]) == int(
                reference["boundaryEdgeCount"]
            )
            quadrature_valid &= close(
                stored_quadrature["midSurfaceAreaSquareMeters"],
                reference["midSurfaceAreaSquareMeters"],
            )
            quadrature_valid &= close(
                stored_quadrature["thickenedD3Q19MeasureSquareMeters"],
                reference["thickenedD3Q19MeasureSquareMeters"],
            )
            quadrature_valid &= vector_close(
                vector(stored_quadrature["meanWallVelocityMetersPerSecond"]),
                reference["meanWallVelocityMetersPerSecond"],
            )
            quadrature_valid &= close(
                stored_quadrature["rmsWallSpeedMetersPerSecond"],
                reference["rmsWallSpeedMetersPerSecond"],
            )
            component_summaries_valid &= component_match(actual, rebuilt[index], reference)

    total_measure_difference = relative_difference(
        sum(item["linkMeasureSquareMeters"] for item in d12_components),
        sum(item["linkMeasureSquareMeters"] for item in d16_components),
    )
    maximum_component_measure_difference = max(
        relative_difference(a["linkMeasureSquareMeters"], b["linkMeasureSquareMeters"])
        for a, b in zip(d12_components, d16_components)
    )
    total_histogram_12 = [
        sum(item["interpolationFractionMeasureHistogram"][index] for item in d12_components)
        for index in range(int(preregistration["interpolationFractionBinCount"]))
    ]
    total_histogram_16 = [
        sum(item["interpolationFractionMeasureHistogram"][index] for item in d16_components)
        for index in range(int(preregistration["interpolationFractionBinCount"]))
    ]
    histogram_difference = histogram_tv(total_histogram_12, total_histogram_16)
    maximum_component_histogram_difference = max(
        histogram_tv(
            a["interpolationFractionMeasureHistogram"],
            b["interpolationFractionMeasureHistogram"],
        )
        for a, b in zip(d12_components, d16_components)
    )
    maximum_grid_mean_difference = max(
        magnitude(
            subtract(
                a["meanWallVelocityMetersPerSecond"],
                b["meanWallVelocityMetersPerSecond"],
            )
        )
        / quadrature[index]["rmsWallSpeedMetersPerSecond"]
        for index, (a, b) in enumerate(zip(d12_components, d16_components))
    )
    maximum_grid_rms_difference = max(
        relative_difference(a["rmsWallSpeedMetersPerSecond"], b["rmsWallSpeedMetersPerSecond"])
        for a, b in zip(d12_components, d16_components)
    )
    maximum_quadrature_mean_error = max(
        magnitude(
            subtract(item["meanWallVelocityMetersPerSecond"], quadrature[index]["meanWallVelocityMetersPerSecond"])
        )
        / quadrature[index]["rmsWallSpeedMetersPerSecond"]
        for components in (d12_components, d16_components)
        for index, item in enumerate(components)
    )
    maximum_quadrature_rms_error = max(
        abs(item["rmsWallSpeedMetersPerSecond"] - quadrature[index]["rmsWallSpeedMetersPerSecond"])
        / quadrature[index]["rmsWallSpeedMetersPerSecond"]
        for components in (d12_components, d16_components)
        for index, item in enumerate(components)
    )
    rebuilt_metrics = {
        "totalLinkMeasureRelativeDifference": total_measure_difference,
        "maximumComponentLinkMeasureRelativeDifference": maximum_component_measure_difference,
        "interpolationHistogramTotalVariation": histogram_difference,
        "maximumComponentInterpolationHistogramTotalVariation": maximum_component_histogram_difference,
        "maximumGridMeanVelocityDifferenceRelativeToQuadratureRMS": maximum_grid_mean_difference,
        "maximumGridRMSSpeedRelativeDifference": maximum_grid_rms_difference,
        "maximumLinkToQuadratureMeanVelocityError": maximum_quadrature_mean_error,
        "maximumLinkToQuadratureRMSSpeedRelativeError": maximum_quadrature_rms_error,
    }
    metrics_valid = all(
        close(float(report["metrics"][key]), value) for key, value in rebuilt_metrics.items()
    )
    measure_bias = (
        total_measure_difference
        > preregistration["maximumAllowedTotalLinkMeasureRelativeDifference"]
        or maximum_component_measure_difference
        > preregistration["maximumAllowedComponentLinkMeasureRelativeDifference"]
    )
    interpolation_bias = (
        histogram_difference
        > preregistration["maximumAllowedInterpolationHistogramTotalVariation"]
        or maximum_component_histogram_difference
        > preregistration["maximumAllowedComponentInterpolationHistogramTotalVariation"]
    )
    velocity_bias = (
        maximum_grid_mean_difference
        > preregistration["maximumAllowedGridMeanVelocityDifferenceRelativeToQuadratureRMS"]
        or maximum_grid_rms_difference
        > preregistration["maximumAllowedGridRMSSpeedRelativeDifference"]
        or maximum_quadrature_mean_error
        > preregistration["maximumAllowedLinkToQuadratureMeanVelocityError"]
        or maximum_quadrature_rms_error
        > preregistration["maximumAllowedLinkToQuadratureRMSSpeedRelativeError"]
    )
    parity = report["d12"]["parityGatePassed"] and report["d16"]["parityGatePassed"]
    bias_count = sum((measure_bias, interpolation_bias, velocity_bias))
    classification = (
        "invalid-metal-cpu-geometry-parity"
        if not parity
        else "wall-representation-cleared"
        if not bias_count
        else "mixed-wall-representation-bias"
        if bias_count > 1
        else "link-measure-bias"
        if measure_bias
        else "interpolation-fraction-bias"
        if interpolation_bias
        else "wall-velocity-deposition-bias"
    )
    checks = {
        "sourceHashes": (
            preregistration["sourceDurationPreregistrationSHA256"] == sha256(DURATION_PREREG_PATH)
            and preregistration["sourceDurationReportSHA256"] == sha256(DURATION_PATH)
            and report["sourceLinkGeometryPreregistrationSHA256"] == sha256(PREREG_PATH)
            and report["sourceDurationPreregistrationSHA256"] == sha256(DURATION_PREREG_PATH)
            and report["sourceDurationReportSHA256"] == sha256(DURATION_PATH)
        ),
        "contractRevisionAndThresholds": (
            preregistration["schemaVersion"] == 2
            and preregistration["maximumAllowedMetalCPUWallVelocityDifferenceLattice"] == 5e-5
            and preregistration["maximumAllowedMetalCPUAggregateRelativeDifference"] == 0.005
            and preregistration["maximumAllowedTotalLinkMeasureRelativeDifference"] == 0.05
            and preregistration["maximumAllowedLinkToQuadratureMeanVelocityError"] == 0.10
            and "Revision 2" in preregistration["contractRevisionRationale"]
        ),
        "durationPrecondition": (
            duration_preregistration["frozenSourceSampleIndex"] == 53
            and duration["persistentFixedWallGridDisagreementLikely"] is True
            and duration["classification"] == "persistent-fixed-wall-grid-disagreement"
        ),
        "d12CompleteBins": d12_bins_valid,
        "d12MetalCPUParity": (
            report["d12"]["metalCPUMaskMismatchCellCount"] == 0
            and report["d12"]["metalCPUExactLinkCountMatch"] is True
            and close(report["d12"]["maximumMetalCPUAggregateRelativeDifference"], d12_cpu_difference)
            and d12_cpu_difference <= preregistration["maximumAllowedMetalCPUAggregateRelativeDifference"]
            and report["d12"]["parityGatePassed"] is True
        ),
        "d16CompleteBins": d16_bins_valid,
        "d16MetalCPUParity": (
            report["d16"]["metalCPUMaskMismatchCellCount"] == 0
            and report["d16"]["metalCPUExactLinkCountMatch"] is True
            and close(report["d16"]["maximumMetalCPUAggregateRelativeDifference"], d16_cpu_difference)
            and d16_cpu_difference <= preregistration["maximumAllowedMetalCPUAggregateRelativeDifference"]
            and report["d16"]["parityGatePassed"] is True
        ),
        "independentTriangleQuadrature": quadrature_valid,
        "componentAggregation": component_summaries_valid,
        "crossGridMetrics": metrics_valid,
        "classification": (
            classification == report["classification"] == "wall-velocity-deposition-bias"
            and report["wallRepresentationCleared"] is False
            and report["linkMeasureBiasLikely"] is False
            and report["interpolationBiasLikely"] is False
            and report["wallVelocityDepositionBiasLikely"] is True
        ),
        "claimBoundary": report["claimBoundary"] == preregistration["claimBoundary"],
        "safetyBoundary": (
            report["d20DiagnosticAuthorized"] is False
            and report["rawSpatialGateModified"] is False
            and report["productionPromotionAuthorized"] is False
            and report["experimentalAgreementGateApplied"] is False
        ),
    }
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-link-geometry.py",
        "sourceArtifacts": {
            "durationPreregistration": str(DURATION_PREREG_PATH.relative_to(ROOT)),
            "durationReport": str(DURATION_PATH.relative_to(ROOT)),
            "linkGeometryPreregistration": str(PREREG_PATH.relative_to(ROOT)),
            "linkGeometryReport": str(REPORT_PATH.relative_to(ROOT)),
            "surfaceManifest": str(MANIFEST_PATH.relative_to(ROOT)),
        },
        "reconstructedMetrics": rebuilt_metrics,
        "reconstructedMetalCPUMaximumAggregateRelativeDifference": {
            "d12": d12_cpu_difference,
            "d16": d16_cpu_difference,
        },
        "failingVelocityComponent": {
            "componentName": "leftWing",
            "d12MeanVelocityErrorRelativeToQuadratureRMS": report["d12"]["components"][1]["meanVelocityErrorRelativeToQuadratureRMS"],
            "d16MeanVelocityErrorRelativeToQuadratureRMS": report["d16"]["components"][1]["meanVelocityErrorRelativeToQuadratureRMS"],
            "frozenLimit": preregistration["maximumAllowedLinkToQuadratureMeanVelocityError"],
        },
        "checks": checks,
        "checkCount": len(checks),
        "allChecksPassed": all(checks.values()),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    print(json.dumps(output, indent=2, sort_keys=True))
    if not output["allChecksPassed"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()

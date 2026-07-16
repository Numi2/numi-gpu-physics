#!/usr/bin/env python3
"""Independently audit the frozen D12/D16 link-intersection outlier archive."""

from __future__ import annotations

import array
import hashlib
import json
import math
import struct
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
INPUTS = ROOT / "ValidationInputs" / "deetjen-ob-f03-surface-v1"
MANIFEST_PATH = INPUTS / "manifest.json"
VELOCITY_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-velocity-preregistration.json"
VELOCITY_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-velocity.json"
VELOCITY_AUDIT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-velocity-audit.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-intersection-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-intersection.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-intersection-audit.json"

DIRECTIONS = [
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
]
WEIGHTS = [1.0 / 3.0] + [1.0 / 18.0] * 6 + [1.0 / 36.0] * 12

Vector = tuple[float, float, float]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


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


def magnitude(value: Vector) -> float:
    return math.sqrt(dot(value, value))


def close(first: float, second: float, tolerance: float = 2e-7) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector, tolerance: float = 2e-7) -> bool:
    return all(close(a, b, tolerance) for a, b in zip(first, second))


def closest_point(point: Vector, a: Vector, b: Vector, c: Vector) -> tuple[Vector, Vector]:
    ab = subtract(b, a)
    ac = subtract(c, a)
    ap = subtract(point, a)
    d1 = dot(ab, ap)
    d2 = dot(ac, ap)
    if d1 <= 0 and d2 <= 0:
        return a, (1.0, 0.0, 0.0)
    bp = subtract(point, b)
    d3 = dot(ab, bp)
    d4 = dot(ac, bp)
    if d3 >= 0 and d4 <= d3:
        return b, (0.0, 1.0, 0.0)
    vc = d1 * d4 - d3 * d2
    if vc <= 0 and d1 >= 0 and d3 <= 0:
        value = d1 / (d1 - d3)
        return add(a, scale(ab, value)), (1.0 - value, value, 0.0)
    cp = subtract(point, c)
    d5 = dot(ab, cp)
    d6 = dot(ac, cp)
    if d6 >= 0 and d5 <= d6:
        return c, (0.0, 0.0, 1.0)
    vb = d5 * d2 - d1 * d6
    if vb <= 0 and d2 >= 0 and d6 <= 0:
        value = d2 / (d2 - d6)
        return add(a, scale(ac, value)), (1.0 - value, 0.0, value)
    va = d3 * d6 - d5 * d4
    if va <= 0 and d4 - d3 >= 0 and d5 - d6 >= 0:
        value = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return add(b, scale(subtract(c, b), value)), (0.0, 1.0 - value, value)
    inverse = 1.0 / max(va + vb + vc, 1e-20)
    v = vb * inverse
    w = vc * inverse
    return add(add(a, scale(ab, v)), scale(ac, w)), (1.0 - v - w, v, w)


def read_mesh(manifest: dict, time_seconds: float) -> tuple[list[Vector], list[tuple[int, int, int]]]:
    vertex_count = int(manifest["topology"]["vertexCount"])
    frame_count = int(manifest["frames"]["count"])
    position_values = array.array("f")
    position_values.frombytes((INPUTS / manifest["binary"]["positions"]["file"]).read_bytes())
    triangles_values = array.array("H")
    triangles_values.frombytes((INPUTS / manifest["binary"]["triangles"]["file"]).read_bytes())
    if sys.byteorder != "little":
        position_values.byteswap()
        triangles_values.byteswap()
    assert len(position_values) == frame_count * vertex_count * 3
    assert len(triangles_values) == int(manifest["topology"]["triangleCount"]) * 3
    times = [f32(value) for value in manifest["frames"]["timesSeconds"]]
    target = f32(time_seconds)
    upper = next(index for index, value in enumerate(times) if value > target)
    lower = upper - 1
    duration = f32(times[upper] - times[lower])
    blend = f32(f32(target - times[lower]) / duration)
    positions: list[Vector] = []
    first_base = lower * vertex_count * 3
    second_base = upper * vertex_count * 3
    for vertex_index in range(vertex_count):
        point = []
        for axis in range(3):
            offset = vertex_index * 3 + axis
            first = float(position_values[first_base + offset])
            second = float(position_values[second_base + offset])
            delta = f32(second - first)
            point.append(f32(first + f32(blend * delta)))
        positions.append(tuple(point))  # type: ignore[arg-type]
    triangles = [
        tuple(int(value) for value in triangles_values[index:index + 3])
        for index in range(0, len(triangles_values), 3)
    ]
    return positions, triangles  # type: ignore[return-value]


def component_maps(manifest: dict, triangles: list[tuple[int, int, int]]) -> tuple[dict, dict, dict]:
    by_part = {int(item["partIdentifier"]): item for item in manifest["topology"]["components"]}
    edge_counts: dict[int, Counter] = {}
    boundary_vertices: dict[int, set[int]] = {}
    for part, component in by_part.items():
        start = int(component["triangleOffset"])
        end = start + int(component["triangleCount"])
        counts: Counter = Counter()
        for triangle in triangles[start:end]:
            for first, second in ((triangle[0], triangle[1]), (triangle[1], triangle[2]), (triangle[2], triangle[0])):
                counts[tuple(sorted((first, second)))] += 1
        edge_counts[part] = counts
        boundary_vertices[part] = {
            vertex
            for edge, count in counts.items()
            if count == 1
            for vertex in edge
        }
    return by_part, edge_counts, boundary_vertices


def feature_for_record(record: dict, edge_counts: dict, boundary_vertices: dict, tolerance: float) -> tuple[str, bool]:
    part = int(record["partIdentifier"])
    vertices = tuple(int(value) for value in record["nearestTriangleVertexIndices"])
    barycentric = vector(record["nearestTriangleBarycentric"])
    zeros = [index for index, value in enumerate(barycentric) if value <= tolerance]
    if not zeros:
        return "face-interior", False
    if len(zeros) == 1:
        edge = (
            (vertices[1], vertices[2]) if zeros[0] == 0
            else (vertices[0], vertices[2]) if zeros[0] == 1
            else (vertices[0], vertices[1])
        )
        boundary = edge_counts[part][tuple(sorted(edge))] == 1
        return ("boundary-edge" if boundary else "interior-edge"), boundary
    vertex_index = max(range(3), key=lambda index: barycentric[index])
    boundary = vertices[vertex_index] in boundary_vertices[part]
    return ("boundary-vertex" if boundary else "interior-vertex"), boundary


def nearest_triangle(
    point: Vector,
    positions: list[Vector],
    triangles: list[tuple[int, int, int]],
    component: dict,
) -> tuple[int, Vector, Vector, float]:
    start = int(component["triangleOffset"])
    end = start + int(component["triangleCount"])
    best = (start, (0.0, 0.0, 0.0), (0.0, 0.0, 0.0), math.inf)
    for triangle_index in range(start, end):
        vertices = triangles[triangle_index]
        point_on_triangle, barycentric = closest_point(
            point,
            positions[vertices[0]],
            positions[vertices[1]],
            positions[vertices[2]],
        )
        distance = magnitude(subtract(point, point_on_triangle))
        if distance < best[3]:
            best = (triangle_index, point_on_triangle, barycentric, distance)
    return best


def audit_case(
    case: dict,
    source_case: dict,
    preregistration: dict,
    positions: list[Vector],
    triangles: list[tuple[int, int, int]],
    by_part: dict,
    edge_counts: dict,
    boundary_vertices: dict,
) -> tuple[dict, bool, bool]:
    cells = int(case["referenceLengthCells"])
    dx = f32(0.08 / cells)
    half_thickness_cells = 0.0075 / dx
    threshold = float(preregistration["outlierResidualThresholdCells"])
    feature_tolerance = float(preregistration["barycentricFeatureTolerance"])
    junction_limit = float(preregistration["maximumJunctionAlternateSurfaceResidualCells"])
    records_valid = True
    geometry_valid = True
    direction_measure = [0.0] * 19
    boundary_count = 0
    junction_count = 0
    edge_or_junction_count = 0
    edge_or_junction_measure = 0.0
    interior_count = 0
    interior_measure = 0.0
    outlier_measure = 0.0
    for record in case["outliers"]:
        part = int(record["partIdentifier"])
        direction = int(record["directionIndex"])
        component = by_part[part]
        cell = tuple(int(value) for value in record["cellCoordinate"])
        neighbor = tuple(int(value) for value in record["neighborCellCoordinate"])
        records_valid &= tuple(b - a for a, b in zip(cell, neighbor)) == DIRECTIONS[direction]
        records_valid &= record["componentName"] == component["name"]
        solid = float(record["solidSignedDistanceCells"])
        fluid = float(record["fluidSignedDistanceCells"])
        expected_q = min(1.0, max(1e-4, fluid / max(fluid - solid, 1e-6)))
        records_valid &= close(float(record["fluidToIntersectionFraction"]), expected_q, 2e-8)
        expected_measure = 6.0 * f32(WEIGHTS[direction]) * float(f32(dx * dx))
        measure = float(record["linkMeasureSquareMeters"])
        records_valid &= close(measure, expected_measure, 2e-10)
        residual = float(record["offsetSurfaceResidualCells"])
        records_valid &= residual > threshold
        records_valid &= close(residual, abs(float(record["signedOffsetSurfaceResidualCells"])), 2e-8)
        triangle_index = int(record["nearestTriangleIndex"])
        triangle_start = int(component["triangleOffset"])
        triangle_end = triangle_start + int(component["triangleCount"])
        records_valid &= triangle_start <= triangle_index < triangle_end
        records_valid &= tuple(int(value) for value in record["nearestTriangleVertexIndices"]) == triangles[triangle_index]
        barycentric = vector(record["nearestTriangleBarycentric"])
        records_valid &= all(value >= -2e-7 for value in barycentric)
        records_valid &= close(sum(barycentric), 1.0, 2e-7)
        feature, boundary = feature_for_record(
            record, edge_counts, boundary_vertices, feature_tolerance
        )
        records_valid &= feature == record["nearestTriangleFeature"]
        records_valid &= boundary is bool(record["meshBoundaryAssociated"])

        intersection = vector(record["intersectionMeters"])
        rebuilt_point = (0.0, 0.0, 0.0)
        for weight, vertex_index in zip(barycentric, triangles[triangle_index]):
            rebuilt_point = add(rebuilt_point, scale(positions[vertex_index], weight))
        geometry_valid &= vector_close(rebuilt_point, vector(record["nearestPointMeters"]), 1e-6)
        nearest = nearest_triangle(intersection, positions, triangles, component)
        geometry_valid &= nearest[0] == triangle_index or close(nearest[3], magnitude(subtract(intersection, rebuilt_point)), 1e-6)
        mid_cells = nearest[3] / dx
        geometry_valid &= close(mid_cells, float(record["midSurfaceDistanceCells"]), 1e-6)
        geometry_valid &= close(
            abs(mid_cells - half_thickness_cells), residual, 1e-6
        )

        alternate_best = None
        for alternate_part, alternate_component in by_part.items():
            if alternate_part == part:
                continue
            candidate = nearest_triangle(intersection, positions, triangles, alternate_component)
            if alternate_best is None or candidate[3] < alternate_best[3]:
                alternate_best = (*candidate, alternate_part, alternate_component["name"])
        assert alternate_best is not None
        alternate_mid_cells = alternate_best[3] / dx
        alternate_residual = abs(
            alternate_mid_cells - half_thickness_cells
        )
        geometry_valid &= int(record["nearestAlternatePartIdentifier"]) == alternate_best[4]
        geometry_valid &= record["nearestAlternateComponentName"] == alternate_best[5]
        geometry_valid &= int(record["nearestAlternateTriangleIndex"]) == alternate_best[0] or close(
            alternate_mid_cells,
            float(record["nearestAlternateMidSurfaceDistanceCells"]),
            1e-6,
        )
        geometry_valid &= close(
            alternate_mid_cells,
            float(record["nearestAlternateMidSurfaceDistanceCells"]),
            1e-6,
        )
        geometry_valid &= close(
            alternate_residual,
            float(record["nearestAlternateOffsetSurfaceResidualCells"]),
            1e-6,
        )
        junction = alternate_residual <= junction_limit
        geometry_valid &= junction is bool(record["componentJunctionCandidate"])

        outlier_measure += measure
        direction_measure[direction] += measure
        boundary_count += int(boundary)
        junction_count += int(junction)
        if boundary or junction:
            edge_or_junction_count += 1
            edge_or_junction_measure += measure
        else:
            interior_count += 1
            interior_measure += measure

    total_count = sum(int(item["linkCount"]) for item in source_case["bins"])
    total_measure = sum(float(item["linkMeasureSquareMeters"]) for item in source_case["bins"])
    dominant_direction = max(range(1, 19), key=lambda direction: direction_measure[direction])
    rebuilt = {
        "totalLinkCount": total_count,
        "totalLinkMeasureSquareMeters": total_measure,
        "outlierCount": len(case["outliers"]),
        "outlierLinkMeasureSquareMeters": outlier_measure,
        "outlierCountFraction": len(case["outliers"]) / total_count,
        "outlierLinkMeasureFraction": outlier_measure / total_measure,
        "meshBoundaryAssociatedOutlierCount": boundary_count,
        "componentJunctionCandidateOutlierCount": junction_count,
        "edgeOrJunctionAssociatedOutlierCount": edge_or_junction_count,
        "interiorAssociatedOutlierCount": interior_count,
        "edgeOrJunctionAssociatedMeasureFraction": edge_or_junction_measure / outlier_measure,
        "interiorAssociatedMeasureFraction": interior_measure / outlier_measure,
        "dominantDirectionIndex": dominant_direction,
        "dominantDirectionMeasureFraction": direction_measure[dominant_direction] / outlier_measure,
        "maximumOffsetSurfaceResidualCells": max(
            float(item["offsetSurfaceResidualCells"]) for item in case["outliers"]
        ),
    }
    aggregate_valid = all(
        close(float(case[key]), float(value), 3e-9)
        if isinstance(value, float)
        else case[key] == value
        for key, value in rebuilt.items()
    )
    source_maximum = max(
        float(item["offsetSurfaceMaximumResidualCells"])
        for item in source_case["components"]
    )
    aggregate_valid &= case["sourceLinkCountMatched"] is True
    aggregate_valid &= case["allOutliersArchived"] is True
    aggregate_valid &= case["allValuesFinite"] is True
    aggregate_valid &= float(case["sourceMaximumResidualDifferenceCells"]) == 0
    aggregate_valid &= close(
        float(case["maximumOffsetSurfaceResidualCells"]), source_maximum, 2e-9
    )
    return rebuilt, records_valid, geometry_valid and aggregate_valid


def main() -> None:
    manifest = load(MANIFEST_PATH)
    velocity_preregistration = load(VELOCITY_PREREG_PATH)
    velocity = load(VELOCITY_PATH)
    velocity_audit = load(VELOCITY_AUDIT_PATH)
    preregistration = load(PREREG_PATH)
    report = load(REPORT_PATH)
    positions, triangles = read_mesh(
        manifest, float(preregistration["frozenSourceTimeSeconds"])
    )
    by_part, edge_counts, boundary_vertices = component_maps(manifest, triangles)
    d12, d12_records, d12_geometry = audit_case(
        report["d12"], velocity["d12"], preregistration,
        positions, triangles, by_part, edge_counts, boundary_vertices,
    )
    d16, d16_records, d16_geometry = audit_case(
        report["d16"], velocity["d16"], preregistration,
        positions, triangles, by_part, edge_counts, boundary_vertices,
    )
    same_direction = d12["dominantDirectionIndex"] == d16["dominantDirectionIndex"]
    rebuilt_metrics = {
        "maximumSourceMaximumResidualDifferenceCells": max(
            float(report["d12"]["sourceMaximumResidualDifferenceCells"]),
            float(report["d16"]["sourceMaximumResidualDifferenceCells"]),
        ),
        "d12OutlierCount": d12["outlierCount"],
        "d16OutlierCount": d16["outlierCount"],
        "d12OutlierLinkMeasureFraction": d12["outlierLinkMeasureFraction"],
        "d16OutlierLinkMeasureFraction": d16["outlierLinkMeasureFraction"],
        "minimumEdgeOrJunctionAssociatedMeasureFraction": min(
            d12["edgeOrJunctionAssociatedMeasureFraction"],
            d16["edgeOrJunctionAssociatedMeasureFraction"],
        ),
        "minimumInteriorAssociatedMeasureFraction": min(
            d12["interiorAssociatedMeasureFraction"],
            d16["interiorAssociatedMeasureFraction"],
        ),
        "minimumDominantDirectionMeasureFraction": min(
            d12["dominantDirectionMeasureFraction"],
            d16["dominantDirectionMeasureFraction"],
        ),
        "sameDominantDirectionAcrossGrids": same_direction,
        "maximumOffsetSurfaceResidualCells": max(
            d12["maximumOffsetSurfaceResidualCells"],
            d16["maximumOffsetSurfaceResidualCells"],
        ),
    }
    metrics_valid = all(
        close(float(report["metrics"][key]), float(value), 3e-9)
        if isinstance(value, float)
        else report["metrics"][key] == value
        for key, value in rebuilt_metrics.items()
    )
    source_reproduced = (
        rebuilt_metrics["maximumSourceMaximumResidualDifferenceCells"]
        <= preregistration["maximumAllowedSourceMaximumResidualDifferenceCells"]
        and report["d12"]["sourceLinkCountMatched"] is True
        and report["d16"]["sourceLinkCountMatched"] is True
        and d12["outlierCount"] > 0
        and d16["outlierCount"] > 0
    )
    edge_associated = source_reproduced and (
        rebuilt_metrics["minimumEdgeOrJunctionAssociatedMeasureFraction"]
        >= preregistration["minimumEdgeOrJunctionAssociationFraction"]
    )
    direction_associated = source_reproduced and same_direction and (
        rebuilt_metrics["minimumDominantDirectionMeasureFraction"]
        >= preregistration["minimumDirectionConcentrationFraction"]
    )
    interior_associated = source_reproduced and (
        rebuilt_metrics["minimumInteriorAssociatedMeasureFraction"]
        >= preregistration["minimumInteriorAssociationFraction"]
    )
    classification = (
        "invalid-outlier-reproduction" if not source_reproduced
        else "mesh-edge-or-component-junction-associated" if edge_associated
        else "stencil-direction-associated" if direction_associated
        else "interior-link-placement-outliers" if interior_associated
        else "mixed-sparse-placement-outliers"
    )
    checks = {
        "sourceHashes": (
            preregistration["sourceLinkVelocityPreregistrationSHA256"]
            == sha256(VELOCITY_PREREG_PATH)
            and preregistration["sourceLinkVelocityReportSHA256"] == sha256(VELOCITY_PATH)
            and report["sourceLinkIntersectionPreregistrationSHA256"] == sha256(PREREG_PATH)
            and report["sourceLinkVelocityPreregistrationSHA256"] == sha256(VELOCITY_PREREG_PATH)
            and report["sourceLinkVelocityReportSHA256"] == sha256(VELOCITY_PATH)
            and report["manifestSHA256"] == sha256(MANIFEST_PATH)
        ),
        "fixedContract": (
            preregistration["referenceLengthCells"] == [12, 16]
            and preregistration["outlierResidualThresholdCells"] == 0.75
            and preregistration["barycentricFeatureTolerance"] == 1e-5
            and preregistration["maximumJunctionAlternateSurfaceResidualCells"] == 0.25
            and preregistration["minimumEdgeOrJunctionAssociationFraction"] == 0.80
            and preregistration["minimumDirectionConcentrationFraction"] == 0.50
            and preregistration["minimumInteriorAssociationFraction"] == 0.50
            and preregistration["maximumAllowedSourceMaximumResidualDifferenceCells"] == 1e-10
        ),
        "sourceVelocityPrecondition": (
            velocity_audit["allChecksPassed"] is True
            and velocity["classification"] == "signed-distance-intersection-placement-bias"
            and velocity["intersectionPlacementPassed"] is False
            and velocity["solidNodeSamplingCausal"] is False
        ),
        "binaryMeshIdentity": (
            sha256(INPUTS / manifest["binary"]["positions"]["file"])
            == manifest["binary"]["positions"]["sha256"]
            and sha256(INPUTS / manifest["binary"]["triangles"]["file"])
            == manifest["binary"]["triangles"]["sha256"]
            and len(positions) == manifest["topology"]["vertexCount"]
            and len(triangles) == manifest["topology"]["triangleCount"]
        ),
        "d12RecordContract": d12_records,
        "d12IndependentGeometry": d12_geometry,
        "d16RecordContract": d16_records,
        "d16IndependentGeometry": d16_geometry,
        "crossGridMetrics": metrics_valid,
        "classification": (
            classification
            == report["classification"]
            == "mesh-edge-or-component-junction-associated"
            and report["sourceReproductionPassed"] is True
            and report["edgeOrJunctionAssociated"] is True
            and report["directionAssociated"] is False
            and report["interiorAssociated"] is False
        ),
        "componentJunctionLocalization": (
            d12["meshBoundaryAssociatedOutlierCount"] == 0
            and d16["meshBoundaryAssociatedOutlierCount"] == 0
            and d12["componentJunctionCandidateOutlierCount"] == 7
            and d16["componentJunctionCandidateOutlierCount"] == 7
        ),
        "claimBoundary": report["claimBoundary"] == preregistration["claimBoundary"],
        "safetyBoundary": (
            report["d20DiagnosticAuthorized"] is False
            and report["productionModificationAuthorized"] is False
            and report["fluidEvolutionExecuted"] is False
            and report["rawSpatialGateModified"] is False
            and report["experimentalAgreementGateApplied"] is False
        ),
    }
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-link-intersection.py",
        "sourceArtifacts": {
            "manifest": str(MANIFEST_PATH.relative_to(ROOT)),
            "linkVelocityPreregistration": str(VELOCITY_PREREG_PATH.relative_to(ROOT)),
            "linkVelocityReport": str(VELOCITY_PATH.relative_to(ROOT)),
            "linkVelocityAudit": str(VELOCITY_AUDIT_PATH.relative_to(ROOT)),
            "linkIntersectionPreregistration": str(PREREG_PATH.relative_to(ROOT)),
            "linkIntersectionReport": str(REPORT_PATH.relative_to(ROOT)),
        },
        "reconstructedMetrics": rebuilt_metrics,
        "localization": {
            "d12Outliers": d12["outlierCount"],
            "d16Outliers": d16["outlierCount"],
            "d12ComponentJunctionCandidates": d12["componentJunctionCandidateOutlierCount"],
            "d16ComponentJunctionCandidates": d16["componentJunctionCandidateOutlierCount"],
            "trueMeshBoundaryOutliers": (
                d12["meshBoundaryAssociatedOutlierCount"]
                + d16["meshBoundaryAssociatedOutlierCount"]
            ),
            "classification": classification,
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

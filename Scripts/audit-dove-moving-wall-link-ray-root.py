#!/usr/bin/env python3
"""Independently reconstruct the 15-link owner/global exact ray-root A/B."""

from __future__ import annotations

import hashlib
import json
import math
import struct
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
INPUTS = ROOT / "ValidationInputs" / "deetjen-ob-f03-surface-v1"
MANIFEST_PATH = INPUTS / "manifest.json"
INTERSECTION_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-intersection-preregistration.json"
INTERSECTION_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-intersection.json"
INTERSECTION_AUDIT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-intersection-audit.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-ray-root-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-ray-root.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-ray-root-audit.json"

DIRECTIONS = np.asarray([
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
], dtype=np.float64)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def f32(value: float) -> float:
    return struct.unpack("<f", struct.pack("<f", value))[0]


def close(first: float, second: float, tolerance: float = 2e-5) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


class SurfaceDistance:
    def __init__(self, manifest: dict, time_seconds: float):
        vertex_count = int(manifest["topology"]["vertexCount"])
        frame_count = int(manifest["frames"]["count"])
        raw_positions = np.fromfile(
            INPUTS / manifest["binary"]["positions"]["file"],
            dtype="<f4",
        ).reshape(frame_count, vertex_count, 3)
        self.triangles = np.fromfile(
            INPUTS / manifest["binary"]["triangles"]["file"],
            dtype="<u2",
        ).reshape(-1, 3).astype(np.int64)
        times = np.asarray(manifest["frames"]["timesSeconds"], dtype=np.float32)
        target = np.float32(time_seconds)
        upper = int(np.searchsorted(times, target, side="right"))
        lower = upper - 1
        blend = np.float32(
            (target - times[lower]) / (times[upper] - times[lower])
        )
        self.positions = (
            raw_positions[lower]
            + blend * (raw_positions[upper] - raw_positions[lower])
        ).astype(np.float32).astype(np.float64)
        self.a = self.positions[self.triangles[:, 0]]
        self.b = self.positions[self.triangles[:, 1]]
        self.c = self.positions[self.triangles[:, 2]]
        self.ab = self.b - self.a
        self.ac = self.c - self.a
        self.bc = self.c - self.b
        self.normal = np.cross(self.ab, self.ac)
        self.normal_squared = np.einsum("ij,ij->i", self.normal, self.normal)
        self.ab_squared = np.einsum("ij,ij->i", self.ab, self.ab)
        self.ac_squared = np.einsum("ij,ij->i", self.ac, self.ac)
        self.bc_squared = np.einsum("ij,ij->i", self.bc, self.bc)
        self.part_by_triangle = np.zeros(len(self.triangles), dtype=np.int64)
        self.indices_by_part: dict[int, np.ndarray] = {}
        for component in manifest["topology"]["components"]:
            part = int(component["partIdentifier"])
            start = int(component["triangleOffset"])
            end = start + int(component["triangleCount"])
            self.part_by_triangle[start:end] = part
            self.indices_by_part[part] = np.arange(start, end, dtype=np.int64)

    def distance(self, point: np.ndarray, part: int | None) -> tuple[float, int, int]:
        indices = (
            self.indices_by_part[part]
            if part is not None
            else np.arange(len(self.triangles), dtype=np.int64)
        )
        a = self.a[indices]
        b = self.b[indices]
        c = self.c[indices]
        ab = self.ab[indices]
        ac = self.ac[indices]
        bc = self.bc[indices]
        ap = point - a
        projection_scale = np.einsum(
            "ij,ij->i", ap, self.normal[indices]
        ) / self.normal_squared[indices]
        projection = point - projection_scale[:, None] * self.normal[indices]
        projected_ap = projection - a
        d00 = self.ab_squared[indices]
        d01 = np.einsum("ij,ij->i", ab, ac)
        d11 = self.ac_squared[indices]
        d20 = np.einsum("ij,ij->i", projected_ap, ab)
        d21 = np.einsum("ij,ij->i", projected_ap, ac)
        denominator = d00 * d11 - d01 * d01
        v = (d11 * d20 - d01 * d21) / denominator
        w = (d00 * d21 - d01 * d20) / denominator
        u = 1.0 - v - w
        inside = (u >= 0) & (v >= 0) & (w >= 0)
        plane_squared = np.einsum(
            "ij,ij->i", point - projection, point - projection
        )

        def segment_squared(
            start: np.ndarray,
            edge: np.ndarray,
            edge_squared: np.ndarray,
        ) -> np.ndarray:
            t = np.clip(
                np.einsum("ij,ij->i", point - start, edge) / edge_squared,
                0.0,
                1.0,
            )
            delta = point - (start + t[:, None] * edge)
            return np.einsum("ij,ij->i", delta, delta)

        edge_squared = np.minimum(
            segment_squared(a, ab, self.ab_squared[indices]),
            np.minimum(
                segment_squared(a, ac, self.ac_squared[indices]),
                segment_squared(b, bc, self.bc_squared[indices]),
            ),
        )
        distances_squared = np.where(inside, plane_squared, edge_squared)
        local = int(np.argmin(distances_squared))
        triangle = int(indices[local])
        return (
            math.sqrt(max(0.0, float(distances_squared[local]))),
            int(self.part_by_triangle[triangle]),
            triangle,
        )


def root(
    surface: SurfaceDistance,
    solid: np.ndarray,
    fluid: np.ndarray,
    part: int | None,
    preregistration: dict,
    dx: float,
) -> tuple[float, float, int, int]:
    half_thickness = 0.0075

    def value(fraction: float) -> tuple[float, int, int]:
        distance, resolved_part, triangle = surface.distance(
            solid + fraction * (fluid - solid), part
        )
        return distance - half_thickness, resolved_part, triangle

    assert value(0.0)[0] <= 2e-7
    assert value(1.0)[0] > -2e-7
    outside = 1.0
    inside = None
    subdivisions = int(preregistration["reverseScanSubdivisions"])
    for step in range(subdivisions - 1, -1, -1):
        fraction = step / subdivisions
        if value(fraction)[0] <= 0:
            inside = fraction
            break
        outside = fraction
    assert inside is not None
    for _ in range(int(preregistration["bisectionIterations"])):
        middle = 0.5 * (inside + outside)
        if value(middle)[0] <= 0:
            inside = middle
        else:
            outside = middle
    fraction = 0.5 * (inside + outside)
    closure, resolved_part, triangle = value(fraction)
    return fraction, abs(closure) / dx, resolved_part, triangle


def weighted_rms(samples: list[dict], key: str) -> float:
    measure = sum(float(sample["linkMeasureSquareMeters"]) for sample in samples)
    return math.sqrt(
        sum(
            float(sample["linkMeasureSquareMeters"]) * float(sample[key]) ** 2
            for sample in samples
        )
        / measure
    )


def audit_case(
    case: dict,
    source_case: dict,
    preregistration: dict,
    surface: SurfaceDistance,
) -> tuple[dict, bool, bool]:
    cells = int(case["referenceLengthCells"])
    dx = 0.08 / cells
    rebuilt_samples: list[dict] = []
    identity_valid = len(case["samples"]) == len(source_case["outliers"])
    roots_valid = True
    for actual, source in zip(case["samples"], source_case["outliers"]):
        index = int(actual["sourceOutlierIndex"])
        identity_valid &= source is source_case["outliers"][index]
        identity_valid &= int(actual["partIdentifier"]) == int(source["partIdentifier"])
        identity_valid &= int(actual["directionIndex"]) == int(source["directionIndex"])
        identity_valid &= actual["cellCoordinate"] == source["cellCoordinate"]
        identity_valid &= bool(actual["componentJunctionCandidate"]) == bool(
            source["componentJunctionCandidate"]
        )
        direction = DIRECTIONS[int(source["directionIndex"])]
        q = float(source["fluidToIntersectionFraction"])
        production_t = 1.0 - q
        intersection = np.asarray(source["intersectionMeters"], dtype=np.float64)
        solid = intersection - production_t * direction * dx
        fluid = solid + direction * dx
        owner = root(
            surface, solid, fluid, int(source["partIdentifier"]),
            preregistration, dx,
        )
        global_root = root(
            surface, solid, fluid, None, preregistration, dx,
        )
        production_global = surface.distance(intersection, None)
        solid_global = surface.distance(solid, None)
        fluid_global = surface.distance(fluid, None)
        link_length = float(np.linalg.norm(direction))
        owner_shift = abs(owner[0] - production_t) * link_length
        global_shift = abs(global_root[0] - production_t) * link_length
        rebuilt = {
            "productionSolidToFluidFraction": production_t,
            "productionGlobalOffsetResidualCells": abs(production_global[0] - 0.0075) / dx,
            "productionNearestGlobalPartIdentifier": production_global[1],
            "exactSolidEndpointSignedDistanceCells": (solid_global[0] - 0.0075) / dx,
            "exactFluidEndpointSignedDistanceCells": (fluid_global[0] - 0.0075) / dx,
            "exactSolidEndpointGlobalPartIdentifier": solid_global[1],
            "exactFluidEndpointGlobalPartIdentifier": fluid_global[1],
            "endpointNearestComponentChanged": solid_global[1] != fluid_global[1],
            "fluidEndpointUsesRecordedAlternateComponent": fluid_global[1]
            == source["nearestAlternatePartIdentifier"],
            "exactOwnerSolidToFluidFraction": owner[0],
            "exactOwnerRootClosureResidualCells": owner[1],
            "exactGlobalSolidToFluidFraction": global_root[0],
            "exactGlobalRootClosureResidualCells": global_root[1],
            "productionToOwnerRootShiftCells": owner_shift,
            "productionToGlobalRootShiftCells": global_shift,
            "globalRootUsesOwnerComponent": global_root[2]
            == int(source["partIdentifier"]),
            "globalRootUsesRecordedAlternateComponent": global_root[2]
            == source["nearestAlternatePartIdentifier"],
            "exactGlobalRootPartIdentifier": global_root[2],
            "linkMeasureSquareMeters": float(source["linkMeasureSquareMeters"]),
            "componentJunctionCandidate": bool(source["componentJunctionCandidate"]),
        }
        for key, value in rebuilt.items():
            if key in {"linkMeasureSquareMeters", "componentJunctionCandidate"}:
                continue
            if isinstance(value, bool) or isinstance(value, int):
                roots_valid &= actual[key] == value
            else:
                roots_valid &= close(float(actual[key]), float(value), 8e-5)
        rebuilt_samples.append(rebuilt)

    junction = [sample for sample in rebuilt_samples if sample["componentJunctionCandidate"]]
    interior = [sample for sample in rebuilt_samples if not sample["componentJunctionCandidate"]]
    junction_owner = weighted_rms(junction, "productionToOwnerRootShiftCells")
    junction_global = weighted_rms(junction, "productionToGlobalRootShiftCells")
    all_owner = weighted_rms(rebuilt_samples, "productionToOwnerRootShiftCells")
    all_global = weighted_rms(rebuilt_samples, "productionToGlobalRootShiftCells")
    rebuilt_case = {
        "sampleCount": len(rebuilt_samples),
        "junctionCandidateCount": len(junction),
        "interiorOutlierCount": len(interior),
        "globalRootComponentSwitchCount": sum(
            not sample["globalRootUsesOwnerComponent"] for sample in rebuilt_samples
        ),
        "endpointNearestComponentChangeCount": sum(
            sample["endpointNearestComponentChanged"] for sample in rebuilt_samples
        ),
        "junctionOwnerRootRMSShiftCells": junction_owner,
        "junctionGlobalRootRMSShiftCells": junction_global,
        "junctionGlobalRootMaximumShiftCells": max(
            sample["productionToGlobalRootShiftCells"] for sample in junction
        ),
        "junctionOwnerToGlobalRMSReductionFraction": 1.0
        - junction_global / junction_owner,
        "allOwnerRootRMSShiftCells": all_owner,
        "allGlobalRootRMSShiftCells": all_global,
        "allGlobalRootMaximumShiftCells": max(
            sample["productionToGlobalRootShiftCells"] for sample in rebuilt_samples
        ),
        "allOwnerToGlobalRMSReductionFraction": 1.0 - all_global / all_owner,
        "interiorGlobalRootMaximumShiftCells": max(
            (sample["productionToGlobalRootShiftCells"] for sample in interior),
            default=None,
        ),
        "maximumRootClosureResidualCells": max(
            max(
                sample["exactOwnerRootClosureResidualCells"],
                sample["exactGlobalRootClosureResidualCells"],
            )
            for sample in rebuilt_samples
        ),
    }
    summary_valid = all(
        (case.get(key) is None and value is None)
        or (
            case.get(key) is not None
            and value is not None
            and (
                case.get(key) == value
                if isinstance(value, int)
                else close(float(case[key]), float(value), 8e-5)
            )
        )
        for key, value in rebuilt_case.items()
    )
    summary_valid &= case["sourceRecordsMatched"] is True
    summary_valid &= case["allRootsBracketed"] is True
    summary_valid &= case["allValuesFinite"] is True
    return rebuilt_case, identity_valid, roots_valid and summary_valid


def main() -> None:
    manifest = load(MANIFEST_PATH)
    intersection_preregistration = load(INTERSECTION_PREREG_PATH)
    intersection = load(INTERSECTION_PATH)
    intersection_audit = load(INTERSECTION_AUDIT_PATH)
    preregistration = load(PREREG_PATH)
    report = load(REPORT_PATH)
    surface = SurfaceDistance(
        manifest, float(preregistration["frozenSourceTimeSeconds"])
    )
    d12, d12_identity, d12_roots = audit_case(
        report["d12"], intersection["d12"], preregistration, surface
    )
    d16, d16_identity, d16_roots = audit_case(
        report["d16"], intersection["d16"], preregistration, surface
    )
    interior = [
        value for value in (
            d12["interiorGlobalRootMaximumShiftCells"],
            d16["interiorGlobalRootMaximumShiftCells"],
        )
        if value is not None
    ]
    rebuilt_metrics = {
        "maximumJunctionGlobalRootRMSShiftCells": max(
            d12["junctionGlobalRootRMSShiftCells"],
            d16["junctionGlobalRootRMSShiftCells"],
        ),
        "maximumJunctionGlobalRootMaximumShiftCells": max(
            d12["junctionGlobalRootMaximumShiftCells"],
            d16["junctionGlobalRootMaximumShiftCells"],
        ),
        "minimumJunctionOwnerToGlobalRMSReductionFraction": min(
            d12["junctionOwnerToGlobalRMSReductionFraction"],
            d16["junctionOwnerToGlobalRMSReductionFraction"],
        ),
        "maximumAllGlobalRootRMSShiftCells": max(
            d12["allGlobalRootRMSShiftCells"],
            d16["allGlobalRootRMSShiftCells"],
        ),
        "maximumAllGlobalRootMaximumShiftCells": max(
            d12["allGlobalRootMaximumShiftCells"],
            d16["allGlobalRootMaximumShiftCells"],
        ),
        "minimumAllOwnerToGlobalRMSReductionFraction": min(
            d12["allOwnerToGlobalRMSReductionFraction"],
            d16["allOwnerToGlobalRMSReductionFraction"],
        ),
        "maximumInteriorGlobalRootShiftCells": max(interior),
        "maximumRootClosureResidualCells": max(
            d12["maximumRootClosureResidualCells"],
            d16["maximumRootClosureResidualCells"],
        ),
        "totalGlobalRootComponentSwitchCount": (
            d12["globalRootComponentSwitchCount"]
            + d16["globalRootComponentSwitchCount"]
        ),
        "totalEndpointNearestComponentChangeCount": (
            d12["endpointNearestComponentChangeCount"]
            + d16["endpointNearestComponentChangeCount"]
        ),
    }
    metrics_valid = all(
        report["metrics"][key] == value
        if isinstance(value, int)
        else close(float(report["metrics"][key]), float(value), 8e-5)
        for key, value in rebuilt_metrics.items()
    )
    source_reproduced = (
        d12_identity and d16_identity
        and d12["sampleCount"] == preregistration["expectedOutlierCounts"][0]
        and d16["sampleCount"] == preregistration["expectedOutlierCounts"][1]
        and d12["junctionCandidateCount"]
        == preregistration["expectedJunctionCandidateCounts"][0]
        and d16["junctionCandidateCount"]
        == preregistration["expectedJunctionCandidateCounts"][1]
    )
    closure_passed = (
        source_reproduced
        and report["metrics"]["maximumRootClosureResidualCells"]
        <= preregistration["maximumAllowedRootClosureResidualCells"]
    )
    junction_passed = (
        closure_passed
        and rebuilt_metrics["maximumJunctionGlobalRootRMSShiftCells"]
        <= preregistration["maximumAllowedGlobalRootRMSShiftCells"]
        and rebuilt_metrics["maximumJunctionGlobalRootMaximumShiftCells"]
        <= preregistration["maximumAllowedGlobalRootMaximumShiftCells"]
    )
    all_passed = (
        closure_passed
        and rebuilt_metrics["maximumAllGlobalRootRMSShiftCells"]
        <= preregistration["maximumAllowedGlobalRootRMSShiftCells"]
        and rebuilt_metrics["maximumAllGlobalRootMaximumShiftCells"]
        <= preregistration["maximumAllowedGlobalRootMaximumShiftCells"]
    )
    reduction_passed = (
        closure_passed
        and rebuilt_metrics["minimumJunctionOwnerToGlobalRMSReductionFraction"]
        >= preregistration["minimumRequiredOwnerToGlobalRMSReductionFraction"]
    )
    classification = (
        "invalid-ray-root-reconstruction" if not source_reproduced or not closure_passed
        else "global-union-root-clears-owner-surface-outliers"
        if all_passed and reduction_passed
        else "component-junction-owner-surface-diagnostic-artifact"
        if junction_passed and reduction_passed
        else "junction-global-root-linearization-bias"
        if not junction_passed
        else "owner-versus-global-union-root-mixed"
    )
    checks = {
        "sourceHashes": (
            preregistration["sourceLinkIntersectionPreregistrationSHA256"]
            == sha256(INTERSECTION_PREREG_PATH)
            and preregistration["sourceLinkIntersectionReportSHA256"]
            == sha256(INTERSECTION_PATH)
            and report["sourceLinkRayRootPreregistrationSHA256"] == sha256(PREREG_PATH)
            and report["sourceLinkIntersectionPreregistrationSHA256"]
            == sha256(INTERSECTION_PREREG_PATH)
            and report["sourceLinkIntersectionReportSHA256"] == sha256(INTERSECTION_PATH)
        ),
        "fixedContract": (
            preregistration["expectedOutlierCounts"] == [8, 7]
            and preregistration["expectedJunctionCandidateCounts"] == [7, 7]
            and preregistration["reverseScanSubdivisions"] == 256
            and preregistration["bisectionIterations"] == 48
            and preregistration["maximumAllowedRootClosureResidualCells"] == 1e-5
            and preregistration["maximumAllowedGlobalRootRMSShiftCells"] == 0.10
            and preregistration["maximumAllowedGlobalRootMaximumShiftCells"] == 0.75
            and preregistration["minimumRequiredOwnerToGlobalRMSReductionFraction"] == 0.80
        ),
        "sourceLocalizationPrecondition": (
            intersection_audit["allChecksPassed"] is True
            and intersection["classification"]
            == "mesh-edge-or-component-junction-associated"
            and intersection["sourceReproductionPassed"] is True
        ),
        "binarySurfaceIdentity": (
            sha256(INPUTS / manifest["binary"]["positions"]["file"])
            == manifest["binary"]["positions"]["sha256"]
            and sha256(INPUTS / manifest["binary"]["triangles"]["file"])
            == manifest["binary"]["triangles"]["sha256"]
        ),
        "d12SourceIdentity": d12_identity,
        "d12IndependentRoots": d12_roots,
        "d16SourceIdentity": d16_identity,
        "d16IndependentRoots": d16_roots,
        "crossGridMetrics": metrics_valid,
        "endpointComponentSwitchMechanism": (
            rebuilt_metrics["totalEndpointNearestComponentChangeCount"] == 15
            and all(
                sample["fluidEndpointUsesRecordedAlternateComponent"] is True
                for case in (report["d12"], report["d16"])
                for sample in case["samples"]
            )
        ),
        "classification": (
            classification
            == report["classification"]
            == "junction-global-root-linearization-bias"
            and report["junctionGlobalUnionPlacementPassed"] is False
            and report["allGlobalUnionPlacementPassed"] is False
            and report["ownerToGlobalReductionPassed"] is False
            and report["priorPlacementClassificationSuperseded"] is False
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
        "generatedBy": "Scripts/audit-dove-moving-wall-link-ray-root.py",
        "sourceArtifacts": {
            "manifest": str(MANIFEST_PATH.relative_to(ROOT)),
            "linkIntersectionPreregistration": str(INTERSECTION_PREREG_PATH.relative_to(ROOT)),
            "linkIntersectionReport": str(INTERSECTION_PATH.relative_to(ROOT)),
            "linkIntersectionAudit": str(INTERSECTION_AUDIT_PATH.relative_to(ROOT)),
            "linkRayRootPreregistration": str(PREREG_PATH.relative_to(ROOT)),
            "linkRayRootReport": str(REPORT_PATH.relative_to(ROOT)),
        },
        "reconstructedMetrics": rebuilt_metrics,
        "mechanism": {
            "endpointNearestComponentChanges": rebuilt_metrics[
                "totalEndpointNearestComponentChangeCount"
            ],
            "globalRootComponentSwitches": rebuilt_metrics[
                "totalGlobalRootComponentSwitchCount"
            ],
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

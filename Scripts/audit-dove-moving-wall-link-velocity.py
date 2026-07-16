#!/usr/bin/env python3
"""Audit the frozen D12/D16 solid-node versus link-intersection velocity A/B."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
GEOMETRY_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-preregistration.json"
GEOMETRY_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry.json"
GEOMETRY_AUDIT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-geometry-audit.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-velocity-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-velocity.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-link-velocity-audit.json"

Vector = tuple[float, float, float]


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


def magnitude(value: Vector) -> float:
    return math.sqrt(sum(component * component for component in value))


def close(first: float, second: float, tolerance: float = 3e-9) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector) -> bool:
    return all(close(a, b, 2e-8) for a, b in zip(first, second))


def relative_difference(first: float, second: float) -> float:
    return abs(first - second) / max(abs(first), abs(second), 1e-30)


def candidate(
    identifier: str,
    velocity_integral: Vector,
    speed_squared_integral: float,
    measure: float,
    quadrature: dict,
) -> dict:
    mean = scale(velocity_integral, 1.0 / measure)
    rms = math.sqrt(speed_squared_integral / measure)
    reference_mean = vector(quadrature["meanWallVelocityMetersPerSecond"])
    reference_rms = float(quadrature["rmsWallSpeedMetersPerSecond"])
    return {
        "identifier": identifier,
        "meanWallVelocityMetersPerSecond": mean,
        "rmsWallSpeedMetersPerSecond": rms,
        "meanVelocityErrorRelativeToQuadratureRMS": magnitude(
            subtract(mean, reference_mean)
        )
        / reference_rms,
        "rmsSpeedRelativeError": abs(rms - reference_rms) / reference_rms,
    }


def candidate_matches(actual: dict, rebuilt: dict) -> bool:
    return (
        actual["identifier"] == rebuilt["identifier"]
        and vector_close(
            vector(actual["meanWallVelocityMetersPerSecond"]),
            rebuilt["meanWallVelocityMetersPerSecond"],
        )
        and close(actual["rmsWallSpeedMetersPerSecond"], rebuilt["rmsWallSpeedMetersPerSecond"])
        and close(
            actual["meanVelocityErrorRelativeToQuadratureRMS"],
            rebuilt["meanVelocityErrorRelativeToQuadratureRMS"],
        )
        and close(actual["rmsSpeedRelativeError"], rebuilt["rmsSpeedRelativeError"])
    )


def reconstruct_case(case: dict, geometry_case: dict) -> tuple[list[dict], bool, bool]:
    bins = case["bins"]
    bins_valid = len(bins) == 72
    components = []
    summaries_valid = len(case["components"]) == 4
    production_valid = True
    for part in range(1, 5):
        selected = []
        for direction in range(1, 19):
            index = (part - 1) * 18 + direction - 1
            item = bins[index]
            bins_valid &= int(item["partIdentifier"]) == part
            bins_valid &= int(item["directionIndex"]) == direction
            bins_valid &= int(item["linkCount"]) >= 0
            bins_valid &= float(item["linkMeasureSquareMeters"]) >= 0
            selected.append(item)
        measure = sum(float(item["linkMeasureSquareMeters"]) for item in selected)
        count = sum(int(item["linkCount"]) for item in selected)
        endpoint_velocity: Vector = (0.0, 0.0, 0.0)
        exact_velocity: Vector = (0.0, 0.0, 0.0)
        endpoint_speed = 0.0
        exact_speed = 0.0
        residual_squared = 0.0
        residual_maximum = 0.0
        for item in selected:
            endpoint_velocity = add(
                endpoint_velocity,
                vector(item["endpointVelocityIntegralSquareMeterMetersPerSecond"]),
            )
            exact_velocity = add(
                exact_velocity,
                vector(item["exactVelocityIntegralSquareMeterMetersPerSecond"]),
            )
            endpoint_speed += float(
                item[
                    "endpointSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared"
                ]
            )
            exact_speed += float(
                item["exactSpeedSquaredIntegralSquareMeterMetersSquaredPerSecondSquared"]
            )
            residual_squared += float(
                item["offsetSurfaceResidualSquaredIntegralSquareMeterCellsSquared"]
            )
            residual_maximum = max(
                residual_maximum,
                float(item["offsetSurfaceMaximumResidualCells"]),
            )
        geometry_component = geometry_case["components"][part - 1]
        quadrature = geometry_component["triangleQuadrature"]
        production = {
            "identifier": "production-solid-node",
            "meanWallVelocityMetersPerSecond": vector(
                geometry_component["meanWallVelocityMetersPerSecond"]
            ),
            "rmsWallSpeedMetersPerSecond": float(
                geometry_component["rmsWallSpeedMetersPerSecond"]
            ),
            "meanVelocityErrorRelativeToQuadratureRMS": float(
                geometry_component["meanVelocityErrorRelativeToQuadratureRMS"]
            ),
            "rmsSpeedRelativeError": float(geometry_component["rmsSpeedRelativeError"]),
        }
        endpoint = candidate(
            "endpoint-interpolated", endpoint_velocity, endpoint_speed, measure, quadrature
        )
        exact = candidate(
            "exact-link-intersection-barycentric",
            exact_velocity,
            exact_speed,
            measure,
            quadrature,
        )
        rebuilt = {
            "partIdentifier": part,
            "componentName": geometry_component["componentName"],
            "linkCount": count,
            "linkMeasureSquareMeters": measure,
            "productionSolidNode": production,
            "endpointInterpolated": endpoint,
            "exactLinkIntersection": exact,
            "offsetSurfaceRMSResidualCells": math.sqrt(residual_squared / measure),
            "offsetSurfaceMaximumResidualCells": residual_maximum,
        }
        actual = case["components"][part - 1]
        summaries_valid &= int(actual["partIdentifier"]) == part
        summaries_valid &= int(actual["linkCount"]) == count
        summaries_valid &= close(actual["linkMeasureSquareMeters"], measure)
        summaries_valid &= candidate_matches(actual["endpointInterpolated"], endpoint)
        summaries_valid &= candidate_matches(actual["exactLinkIntersection"], exact)
        summaries_valid &= close(
            actual["offsetSurfaceRMSResidualCells"],
            rebuilt["offsetSurfaceRMSResidualCells"],
        )
        summaries_valid &= close(
            actual["offsetSurfaceMaximumResidualCells"], residual_maximum
        )
        production_valid &= candidate_matches(actual["productionSolidNode"], production)
        production_valid &= count == int(geometry_component["linkCount"])
        components.append(rebuilt)
    return components, bins_valid, summaries_valid and production_valid


def maximum_error(components: list[dict], candidate_key: str, value_key: str) -> float:
    return max(float(item[candidate_key][value_key]) for item in components)


def main() -> None:
    geometry_preregistration = load(GEOMETRY_PREREG_PATH)
    geometry = load(GEOMETRY_PATH)
    geometry_audit = load(GEOMETRY_AUDIT_PATH)
    preregistration = load(PREREG_PATH)
    report = load(REPORT_PATH)
    d12, d12_bins, d12_summaries = reconstruct_case(report["d12"], geometry["d12"])
    d16, d16_bins, d16_summaries = reconstruct_case(report["d16"], geometry["d16"])
    all_components = d12 + d16

    def grid_difference(candidate_key: str) -> float:
        values = []
        for index, (first, second) in enumerate(zip(d12, d16)):
            reference_rms = float(
                geometry["d12"]["components"][index]["triangleQuadrature"][
                    "rmsWallSpeedMetersPerSecond"
                ]
            )
            values.append(
                magnitude(
                    subtract(
                        first[candidate_key]["meanWallVelocityMetersPerSecond"],
                        second[candidate_key]["meanWallVelocityMetersPerSecond"],
                    )
                )
                / reference_rms
            )
        return max(values)

    left_pairs = [
        (
            grid[1]["productionSolidNode"]["meanVelocityErrorRelativeToQuadratureRMS"],
            grid[1]["endpointInterpolated"]["meanVelocityErrorRelativeToQuadratureRMS"],
            grid[1]["exactLinkIntersection"]["meanVelocityErrorRelativeToQuadratureRMS"],
        )
        for grid in (d12, d16)
    ]
    exact_improvements = [1.0 - exact / production for production, _, exact in left_pairs]
    endpoint_improvements = [
        1.0 - endpoint / production for production, endpoint, _ in left_pairs
    ]
    endpoint_capture = []
    for production, endpoint, exact in left_pairs:
        exact_improvement = production - exact
        endpoint_capture.append(
            (production - endpoint) / exact_improvement if exact_improvement > 0 else 0.0
        )
    rebuilt_metrics = {
        "maximumSourceProductionRelativeDifference": 0.0,
        "maximumProductionMeanVelocityError": maximum_error(
            all_components,
            "productionSolidNode",
            "meanVelocityErrorRelativeToQuadratureRMS",
        ),
        "maximumEndpointMeanVelocityError": maximum_error(
            all_components,
            "endpointInterpolated",
            "meanVelocityErrorRelativeToQuadratureRMS",
        ),
        "maximumExactMeanVelocityError": maximum_error(
            all_components,
            "exactLinkIntersection",
            "meanVelocityErrorRelativeToQuadratureRMS",
        ),
        "maximumProductionRMSSpeedRelativeError": maximum_error(
            all_components, "productionSolidNode", "rmsSpeedRelativeError"
        ),
        "maximumEndpointRMSSpeedRelativeError": maximum_error(
            all_components, "endpointInterpolated", "rmsSpeedRelativeError"
        ),
        "maximumExactRMSSpeedRelativeError": maximum_error(
            all_components, "exactLinkIntersection", "rmsSpeedRelativeError"
        ),
        "maximumEndpointD12D16MeanVelocityDifference": grid_difference(
            "endpointInterpolated"
        ),
        "maximumExactD12D16MeanVelocityDifference": grid_difference(
            "exactLinkIntersection"
        ),
        "maximumOffsetSurfaceRMSResidualCells": max(
            item["offsetSurfaceRMSResidualCells"] for item in all_components
        ),
        "maximumOffsetSurfaceResidualCells": max(
            item["offsetSurfaceMaximumResidualCells"] for item in all_components
        ),
        "minimumLeftWingExactImprovementFraction": min(exact_improvements),
        "minimumLeftWingEndpointImprovementFraction": min(endpoint_improvements),
        "minimumEndpointCaptureOfExactImprovementFraction": min(endpoint_capture),
    }
    metrics_valid = all(
        close(float(report["metrics"][key]), value)
        for key, value in rebuilt_metrics.items()
    )
    source_reproduced = (
        rebuilt_metrics["maximumSourceProductionRelativeDifference"]
        <= preregistration["maximumAllowedSourceReproductionRelativeError"]
        and report["d12"]["sourceReproductionPassed"] is True
        and report["d16"]["sourceReproductionPassed"] is True
    )
    placement = (
        rebuilt_metrics["maximumOffsetSurfaceRMSResidualCells"]
        <= preregistration["maximumAllowedOffsetSurfaceRMSResidualCells"]
        and rebuilt_metrics["maximumOffsetSurfaceResidualCells"]
        <= preregistration["maximumAllowedOffsetSurfaceMaximumResidualCells"]
    )
    exact_clears = (
        rebuilt_metrics["maximumExactMeanVelocityError"]
        <= preregistration["maximumAllowedExactMeanVelocityError"]
        and rebuilt_metrics["maximumExactRMSSpeedRelativeError"]
        <= preregistration["maximumAllowedExactRMSSpeedRelativeError"]
        and rebuilt_metrics["maximumExactD12D16MeanVelocityDifference"]
        <= preregistration["maximumAllowedD12D16MeanVelocityDifference"]
    )
    causal = (
        source_reproduced
        and placement
        and exact_clears
        and rebuilt_metrics["minimumLeftWingExactImprovementFraction"]
        >= preregistration["minimumCausalImprovementFraction"]
    )
    endpoint_qualified = (
        causal
        and rebuilt_metrics["maximumEndpointMeanVelocityError"]
        <= preregistration["maximumAllowedEndpointMeanVelocityError"]
        and rebuilt_metrics["maximumEndpointRMSSpeedRelativeError"]
        <= preregistration["maximumAllowedEndpointRMSSpeedRelativeError"]
        and rebuilt_metrics["maximumEndpointD12D16MeanVelocityDifference"]
        <= preregistration["maximumAllowedD12D16MeanVelocityDifference"]
        and rebuilt_metrics["minimumEndpointCaptureOfExactImprovementFraction"]
        >= preregistration["minimumEndpointCaptureOfExactImprovementFraction"]
    )
    classification = (
        "invalid-source-production-reproduction"
        if not source_reproduced
        else "signed-distance-intersection-placement-bias"
        if not placement
        else "endpoint-interpolation-repair-qualified"
        if causal and endpoint_qualified
        else "exact-intersection-velocity-sampling-causal"
        if causal
        else "solid-node-velocity-sampling-contributes"
        if rebuilt_metrics["minimumLeftWingExactImprovementFraction"]
        >= preregistration["minimumContributionImprovementFraction"]
        else "link-weighting-dominant"
    )
    checks = {
        "sourceHashes": (
            preregistration["sourceLinkGeometryPreregistrationSHA256"]
            == sha256(GEOMETRY_PREREG_PATH)
            and preregistration["sourceLinkGeometryReportSHA256"]
            == sha256(GEOMETRY_PATH)
            and report["sourceLinkVelocityPreregistrationSHA256"] == sha256(PREREG_PATH)
            and report["sourceLinkGeometryPreregistrationSHA256"]
            == sha256(GEOMETRY_PREREG_PATH)
            and report["sourceLinkGeometryReportSHA256"] == sha256(GEOMETRY_PATH)
        ),
        "fixedContract": (
            preregistration["maximumAllowedSourceReproductionRelativeError"] == 1e-10
            and preregistration["maximumAllowedOffsetSurfaceRMSResidualCells"] == 0.10
            and preregistration["maximumAllowedOffsetSurfaceMaximumResidualCells"] == 0.75
            and preregistration["minimumCausalImprovementFraction"] == 0.50
            and preregistration["minimumEndpointCaptureOfExactImprovementFraction"] == 0.80
        ),
        "sourceGeometryPrecondition": (
            geometry_audit["allChecksPassed"] is True
            and geometry["classification"] == "wall-velocity-deposition-bias"
            and geometry["linkMeasureBiasLikely"] is False
            and geometry["interpolationBiasLikely"] is False
            and geometry["wallVelocityDepositionBiasLikely"] is True
        ),
        "d12DirectionBins": d12_bins,
        "d12ComponentAggregation": d12_summaries,
        "d12ProductionReproduction": report["d12"]["sourceProductionMaximumRelativeDifference"] == 0,
        "d16DirectionBins": d16_bins,
        "d16ComponentAggregation": d16_summaries,
        "d16ProductionReproduction": report["d16"]["sourceProductionMaximumRelativeDifference"] == 0,
        "crossGridMetrics": metrics_valid,
        "classification": (
            classification
            == report["classification"]
            == "signed-distance-intersection-placement-bias"
            and report["intersectionPlacementPassed"] is False
            and report["exactIntersectionClearsBias"] is False
            and report["solidNodeSamplingCausal"] is False
            and report["endpointInterpolationQualified"] is False
        ),
        "claimBoundary": report["claimBoundary"] == preregistration["claimBoundary"],
        "safetyBoundary": (
            report["d20DiagnosticAuthorized"] is False
            and report["productionModificationAuthorized"] is False
            and report["rawSpatialGateModified"] is False
            and report["experimentalAgreementGateApplied"] is False
        ),
    }
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-link-velocity.py",
        "sourceArtifacts": {
            "linkGeometryPreregistration": str(GEOMETRY_PREREG_PATH.relative_to(ROOT)),
            "linkGeometryReport": str(GEOMETRY_PATH.relative_to(ROOT)),
            "linkGeometryAudit": str(GEOMETRY_AUDIT_PATH.relative_to(ROOT)),
            "linkVelocityPreregistration": str(PREREG_PATH.relative_to(ROOT)),
            "linkVelocityReport": str(REPORT_PATH.relative_to(ROOT)),
        },
        "reconstructedMetrics": rebuilt_metrics,
        "placementGate": {
            "rmsResidualCells": rebuilt_metrics["maximumOffsetSurfaceRMSResidualCells"],
            "rmsLimitCells": preregistration["maximumAllowedOffsetSurfaceRMSResidualCells"],
            "maximumResidualCells": rebuilt_metrics["maximumOffsetSurfaceResidualCells"],
            "maximumLimitCells": preregistration[
                "maximumAllowedOffsetSurfaceMaximumResidualCells"
            ],
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

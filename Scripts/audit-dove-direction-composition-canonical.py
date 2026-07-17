#!/usr/bin/env python3
"""Independently audit the static direction-composition planar canonical."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-preregistration.json"
)
V1_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-preregistration-v1-float-degenerate.json"
)
V1_REPORT = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-v1-float-degenerate.json"
)
DISCRIMINATOR = ARTIFACTS / "deetjen-dove-link-composition-discriminator.json"
DISCRIMINATOR_AUDIT = ARTIFACTS / (
    "deetjen-dove-link-composition-discriminator-audit.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
REPORT = ARTIFACTS / "deetjen-dove-direction-composition-canonical.json"
OUTPUT = ARTIFACTS / "deetjen-dove-direction-composition-canonical-audit.json"

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


def close(left: float, right: float, tolerance: float = 2e-10) -> bool:
    return abs(left - right) <= tolerance * max(abs(left), abs(right), 1.0)


def vector_close(left: list, right: list, tolerance: float = 2e-10) -> bool:
    return all(close(float(a), float(b), tolerance) for a, b in zip(left, right))


def frame(integer_normal: list[int]) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    raw = np.asarray(integer_normal, dtype=np.float32)
    normal = raw / np.sqrt(np.sum(raw * raw), dtype=np.float32)
    reference = np.asarray([0, 1, 0], dtype=np.float32)
    tangent_u = np.cross(reference, normal)
    tangent_u /= np.sqrt(np.sum(tangent_u * tangent_u), dtype=np.float32)
    tangent_v = np.cross(normal, tangent_u)
    return normal.astype(np.float64), tangent_u.astype(np.float64), tangent_v.astype(np.float64)


def direction_counts(
    grid_side: int,
    dx: float,
    phase: float,
    integer_normal: list[int],
    tangent_u: np.ndarray,
) -> list[int]:
    raw = np.asarray(integer_normal, dtype=np.float64)
    raw_length = np.linalg.norm(raw)
    centered = np.arange(grid_side, dtype=np.float64) + 0.5 - 0.5 * grid_side
    x, z = np.meshgrid(centered, centered, indexing="ij")
    base = raw[0] * x + raw[2] * z - (phase - 0.5) * raw_length
    signed = base / raw_length
    counts = [0] * 19
    tolerance_cells = 1e-5
    half_extent_cells = 0.5 / dx
    y_centers = centered
    for direction in range(1, 19):
        c = DIRECTIONS[direction]
        source_signed = (
            base - raw[0] * c[0] - raw[2] * c[2]
        ) / raw_length
        crossing = (signed >= 0) & (signed <= 1.415) & (source_signed < 0)
        if not np.any(crossing):
            continue
        fraction = signed[crossing] / (
            signed[crossing] - source_signed[crossing]
        )
        crossing_x = x[crossing] - fraction * c[0]
        crossing_z = z[crossing] - fraction * c[2]
        tangent_coordinate = (
            crossing_x * tangent_u[0] + crossing_z * tangent_u[2]
        )
        in_tangent = np.abs(tangent_coordinate) <= (
            half_extent_cells + tolerance_cells
        )
        if not np.any(in_tangent):
            continue
        fraction = fraction[in_tangent]
        y_coordinate = y_centers[None, :] - fraction[:, None] * c[1]
        in_y = np.abs(y_coordinate) <= half_extent_cells + tolerance_cells
        counts[direction] = int(np.count_nonzero(in_y))
    return counts


def analytic_response(normal: np.ndarray, populations: list[float]) -> np.ndarray:
    result = np.zeros(3, dtype=np.float64)
    for direction in range(1, 19):
        projection = float(np.dot(DIRECTIONS[direction], normal))
        if projection > 0:
            result += 2 * populations[direction] * projection * DIRECTIONS[direction]
    return result


def lattice_response(
    counts: list[int], dx: float, populations: list[float]
) -> np.ndarray:
    result = np.zeros(3, dtype=np.float64)
    for direction in range(1, 19):
        result += (
            2 * dx * dx * counts[direction] * populations[direction]
            * DIRECTIONS[direction]
        )
    return result


def mean(values: list[np.ndarray]) -> np.ndarray:
    return np.mean(np.asarray(values, dtype=np.float64), axis=0)


def main() -> None:
    prereg = load(PREREGISTRATION)
    v1_prereg = load(V1_PREREGISTRATION)
    v1_report = load(V1_REPORT)
    report = load(REPORT)
    cases_by_key = {
        (
            item["referenceLengthCells"],
            item["orientationIdentifier"],
            item["subcellPhaseOffset"],
        ): item
        for item in report["cases"]
    }
    reconstructed_cases = {}
    counts_match = True
    case_geometry_match = True
    response_metrics_match = True
    maximum_count_mismatch = 0
    maximum_count_relative = 0.0
    for resolution in prereg["referenceLengthCells"]:
        # The production canonical intentionally freezes the geometry scale as
        # Float before promoting it to Double for response accumulation. Mirror
        # that published arithmetic here; using an ideal 1/N Double dx changes
        # coarse/fine summaries at O(1e-7) without changing any link count.
        dx = float(np.float32(
            prereg["patchSideLengthMeters"] / resolution
        ))
        grid_side = math.ceil(prereg["domainSideLengthMeters"] / dx)
        for orientation in prereg["orientations"]:
            normal, tangent_u, tangent_v = frame(orientation["integerNormal"])
            for phase in prereg["subcellPhaseOffsets"]:
                key = (resolution, orientation["identifier"], phase)
                item = cases_by_key[key]
                counts = direction_counts(
                    grid_side, dx, phase, orientation["integerNormal"], tangent_u
                )
                reconstructed_cases[key] = {
                    "counts": counts,
                    "normal": normal,
                    "tangent_u": tangent_u,
                    "tangent_v": tangent_v,
                }
                counts_match = counts_match and (
                    counts == item["metalDirectionLinkCounts"]
                    == item["cpuDirectionLinkCounts"]
                )
                differences = [
                    abs(a - b)
                    for a, b in zip(
                        item["metalDirectionLinkCounts"],
                        item["cpuDirectionLinkCounts"],
                    )
                ]
                mismatch = max(differences)
                relative = sum(differences) / max(item["totalCPULinkCount"], 1)
                maximum_count_mismatch = max(maximum_count_mismatch, mismatch)
                maximum_count_relative = max(maximum_count_relative, relative)
                total = sum(counts)
                histogram = [count / total for count in counts]
                case_geometry_match = case_geometry_match and (
                    item["gridSideCells"] == grid_side
                    and close(item["cellSizeMeters"], dx)
                    and vector_close(item["normal"], normal.tolist())
                    and vector_close(item["tangentU"], tangent_u.tolist())
                    and vector_close(item["tangentV"], tangent_v.tolist())
                    and item["totalMetalLinkCount"] == total
                    and item["totalCPULinkCount"] == total
                    and item["maximumPerDirectionCountMismatch"] == mismatch
                    and close(item["countRelativeDifference"], relative)
                    and vector_close(item["directionHistogram"], histogram)
                )
                responses = {
                    value["profileIdentifier"]: value
                    for value in item["profileResponses"]
                }
                for profile in prereg["fixedPopulationProfiles"]:
                    populations = profile["directionPopulations"]
                    analytic = analytic_response(normal, populations)
                    lattice = lattice_response(counts, dx, populations)
                    error = np.linalg.norm(lattice - analytic) / max(
                        np.linalg.norm(analytic), 1e-30
                    )
                    archived = responses[profile["identifier"]]
                    response_metrics_match = response_metrics_match and (
                        vector_close(archived["analyticResponse"], analytic.tolist())
                        and vector_close(archived["metalResponse"], lattice.tolist())
                        and vector_close(archived["cpuResponse"], lattice.tolist())
                        and close(archived["metalVectorRelativeError"], error)
                        and close(archived["cpuVectorRelativeError"], error)
                    )

    summary_match = True
    reconstructed_summaries = []
    for orientation in prereg["orientations"]:
        identifier = orientation["identifier"]
        normal, _, _ = frame(orientation["integerNormal"])
        archived = next(
            item for item in report["orientationSummaries"]
            if item["orientationIdentifier"] == identifier
        )
        histograms = {}
        for resolution in prereg["referenceLengthCells"]:
            values = []
            for phase in prereg["subcellPhaseOffsets"]:
                counts = reconstructed_cases[(resolution, identifier, phase)]["counts"]
                total = sum(counts)
                values.append(np.asarray(counts, dtype=np.float64) / total)
            histograms[resolution] = mean(values)
        histogram_tv = 0.5 * np.sum(np.abs(
            histograms[48] - histograms[64]
        ))
        profile_summaries = []
        for profile in prereg["fixedPopulationProfiles"]:
            profile_identifier = profile["identifier"]
            populations = profile["directionPopulations"]
            analytic = analytic_response(normal, populations)
            responses = {}
            errors = {}
            for resolution in prereg["referenceLengthCells"]:
                responses[resolution] = []
                errors[resolution] = []
                dx = float(np.float32(
                    prereg["patchSideLengthMeters"] / resolution
                ))
                for phase in prereg["subcellPhaseOffsets"]:
                    counts = reconstructed_cases[
                        (resolution, identifier, phase)
                    ]["counts"]
                    value = lattice_response(counts, dx, populations)
                    responses[resolution].append(value)
                    errors[resolution].append(
                        np.linalg.norm(value - analytic)
                        / max(np.linalg.norm(analytic), 1e-30)
                    )
            coarse_mean = mean(responses[48])
            fine_mean = mean(responses[64])
            scale = max(np.linalg.norm(analytic), 1e-30)
            coarse_fine = np.linalg.norm(fine_mean - coarse_mean) / scale
            fine_spread = max(
                np.linalg.norm(value - fine_mean) / scale
                for value in responses[64]
            )
            summary = {
                "profileIdentifier": profile_identifier,
                "coarsePhaseMeanResponse": coarse_mean.tolist(),
                "finePhaseMeanResponse": fine_mean.tolist(),
                "analyticResponse": analytic.tolist(),
                "maximumFineVectorRelativeError": max(errors[64]),
                "coarseFinePhaseMeanRelativeDifference": coarse_fine,
                "maximumFinePhaseRelativeSpread": fine_spread,
            }
            profile_summaries.append(summary)
            archived_profile = next(
                item for item in archived["profiles"]
                if item["profileIdentifier"] == profile_identifier
            )
            summary_match = summary_match and all([
                vector_close(
                    archived_profile["coarsePhaseMeanResponse"], coarse_mean.tolist()
                ),
                vector_close(
                    archived_profile["finePhaseMeanResponse"], fine_mean.tolist()
                ),
                vector_close(archived_profile["analyticResponse"], analytic.tolist()),
                close(
                    archived_profile["maximumFineVectorRelativeError"],
                    max(errors[64]),
                ),
                close(
                    archived_profile["coarseFinePhaseMeanRelativeDifference"],
                    coarse_fine,
                ),
                close(
                    archived_profile["maximumFinePhaseRelativeSpread"], fine_spread
                ),
            ])
        equilibrium = next(
            item for item in profile_summaries
            if item["profileIdentifier"] == "rest-equilibrium"
        )
        # D3Q19.soundSpeedSquared is a Float in BirdFlowCore and is explicitly
        # promoted to Double by the production summary.
        normalized = np.asarray(equilibrium["finePhaseMeanResponse"]) / float(
            np.float32(1 / 3)
        )
        normal_response = float(np.dot(normalized, normal))
        tangent = normalized - normal_response * normal
        normal_error = abs(normal_response - 1)
        tangential = float(np.linalg.norm(tangent))
        summary_match = summary_match and all([
            vector_close(archived["normal"], normal.tolist()),
            close(
                archived["coarseFineDirectionHistogramTotalVariation"],
                histogram_tv,
            ),
            close(archived["equilibriumFineNormalResponseError"], normal_error),
            close(archived["equilibriumFineTangentialLeakage"], tangential),
        ])
        reconstructed_summaries.append({
            "orientationIdentifier": identifier,
            "histogramTV": histogram_tv,
            "equilibriumNormalError": normal_error,
            "equilibriumTangentialLeakage": tangential,
            "profiles": profile_summaries,
        })

    all_profiles = [
        profile
        for summary in reconstructed_summaries
        for profile in summary["profiles"]
    ]
    maxima = {
        "maximumMetalCPUPerDirectionCountMismatch": maximum_count_mismatch,
        "maximumMetalCPUCountRelativeDifference": maximum_count_relative,
        "maximumFineProfileVectorRelativeError": max(
            item["maximumFineVectorRelativeError"] for item in all_profiles
        ),
        "maximumCoarseFinePhaseMeanProfileRelativeDifference": max(
            item["coarseFinePhaseMeanRelativeDifference"] for item in all_profiles
        ),
        "maximumFinePhaseProfileRelativeSpread": max(
            item["maximumFinePhaseRelativeSpread"] for item in all_profiles
        ),
        "maximumCoarseFineDirectionHistogramTotalVariation": max(
            item["histogramTV"] for item in reconstructed_summaries
        ),
        "maximumEquilibriumFineNormalResponseError": max(
            item["equilibriumNormalError"] for item in reconstructed_summaries
        ),
        "maximumEquilibriumFineTangentialLeakage": max(
            item["equilibriumTangentialLeakage"]
            for item in reconstructed_summaries
        ),
    }
    maxima_match = all(close(report[key], value) for key, value in maxima.items())
    expected_gates = {
        "metalCPUPerDirectionCounts": maxima[
            "maximumMetalCPUPerDirectionCountMismatch"
        ] <= prereg["maximumMetalCPUPerDirectionCountMismatch"],
        "metalCPUCountRelativeDifference": maxima[
            "maximumMetalCPUCountRelativeDifference"
        ] <= prereg["maximumMetalCPUCountRelativeDifference"],
        "fineProfileVectorResponse": maxima[
            "maximumFineProfileVectorRelativeError"
        ] <= prereg["maximumFineProfileVectorRelativeError"],
        "coarseFinePhaseMeanResponse": maxima[
            "maximumCoarseFinePhaseMeanProfileRelativeDifference"
        ] <= prereg["maximumCoarseFinePhaseMeanProfileRelativeDifference"],
        "finePhaseResponseStability": maxima[
            "maximumFinePhaseProfileRelativeSpread"
        ] <= prereg["maximumFinePhaseProfileRelativeSpread"],
        "coarseFineDirectionHistogram": maxima[
            "maximumCoarseFineDirectionHistogramTotalVariation"
        ] <= prereg["maximumCoarseFineDirectionHistogramTotalVariation"],
        "equilibriumFineNormalResponse": maxima[
            "maximumEquilibriumFineNormalResponseError"
        ] <= prereg["maximumEquilibriumFineNormalResponseError"],
        "equilibriumFineTangentialLeakage": maxima[
            "maximumEquilibriumFineTangentialLeakage"
        ] <= prereg["maximumEquilibriumFineTangentialLeakage"],
    }
    checks = {
        "sourceHashes": (
            prereg["sourceDiscriminatorSHA256"] == sha256(DISCRIMINATOR)
            and prereg["sourceDiscriminatorAuditSHA256"]
            == sha256(DISCRIMINATOR_AUDIT)
            and prereg["sourceD28ProvenanceSHA256"] == sha256(D28)
            and prereg["sourceD32ProvenanceSHA256"] == sha256(D32)
            and report["sourcePreregistrationSHA256"] == sha256(PREREGISTRATION)
        ),
        "transparentV1Retention": (
            prereg["revisionHistory"]["v1PreregistrationSHA256"]
            == sha256(V1_PREREGISTRATION)
            and prereg["revisionHistory"]["v1FailedReportSHA256"]
            == sha256(V1_REPORT)
            and v1_prereg["schemaVersion"] == 1
            and not v1_report["canonicalPassed"]
            and v1_report["gates"]["fineProfileVectorResponse"]
            and not v1_report["gates"]["metalCPUPerDirectionCounts"]
        ),
        "v2ArithmeticOnlyRevision": (
            prereg["schemaVersion"] == 2
            and prereg["referenceLengthCells"] == v1_prereg["referenceLengthCells"]
            and prereg["subcellPhaseOffsets"] == v1_prereg["subcellPhaseOffsets"]
            and prereg["orientations"] == v1_prereg["orientations"]
            and all(
                current["identifier"] == prior["identifier"]
                and current["source"] == prior["source"]
                and current["directionPopulations"]
                == prior["directionPopulations"]
                for current, prior in zip(
                    prereg["fixedPopulationProfiles"],
                    v1_prereg["fixedPopulationProfiles"],
                )
            )
            and prereg["maximumFineProfileVectorRelativeError"]
            == v1_prereg["maximumFineProfileVectorRelativeError"]
        ),
        "caseCoverage": len(report["cases"]) == 2 * 4 * 5,
        "noFluidOrTopology": (
            not report["fluidEvolutionExecuted"]
            and report["fixedInterpolationFraction"] == 0.5
            and report["kernel"] == "measureObliquePlaneDirectionComposition"
        ),
        "independentDirectionCounts": counts_match,
        "caseGeometryAndMetrics": case_geometry_match,
        "analyticProfileResponses": response_metrics_match,
        "orientationSummaries": summary_match,
        "maximumMetrics": maxima_match,
        "frozenGates": report["gates"] == expected_gates,
        "bothProfilesPass": (
            report["equilibriumProfilePassed"]
            and report["sourceMidpointProfilePassed"]
        ),
        "classification": (
            report["classification"]
            == "direction-weighting-cleared-in-planar-canonical"
            and report["basicPlanarDirectionWeightingCleared"]
            and report["canonicalPassed"]
        ),
        "claimBoundary": (
            not report["productionModificationAuthorized"]
            and not report["d36RunAuthorized"]
            and not report["gridConvergenceGateApplied"]
            and not report["experimentalAgreementGateApplied"]
            and report["claimBoundary"] == prereg["claimBoundary"]
        ),
    }
    # NumPy comparisons return np.bool_; normalize the public archive to plain
    # JSON booleans instead of depending on a permissive encoder.
    checks = {name: bool(value) for name, value in checks.items()}
    passed = all(checks.values())
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-direction-composition-planar-audit-v1",
        "generatedBy": "Scripts/audit-dove-direction-composition-canonical.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "v1PreregistrationSHA256": sha256(V1_PREREGISTRATION),
        "v1FailedReportSHA256": sha256(V1_REPORT),
        "reportSHA256": sha256(REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": passed,
        "independentReconstruction": maxima,
        "classification": report["classification"],
        "fluidEvolutionExecuted": False,
        "productionModificationAuthorized": False,
        "claimBoundary": (
            "This independent NumPy audit reconstructs all 40 analytic plane "
            "cases, direction counts, two fixed-population vector responses, "
            "phase/grid metrics, V1 failure provenance, V2 gates, and safety "
            "boundary. It does not authorize a production edit or bird claim."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("direction-composition audit failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

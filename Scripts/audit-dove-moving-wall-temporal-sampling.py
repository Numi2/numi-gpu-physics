#!/usr/bin/env python3
"""Independently audit the fixed-geometry D12/D16 sampling canonical."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
SPATIAL_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-discriminator.json"
LAG_BAND_PATH = ARTIFACTS / "deetjen-dove-moving-wall-spatial-lag-band.json"
PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-sampling-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-sampling.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-sampling-audit.json"

Vector = tuple[float, float, float]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected a three-component vector")
    value = tuple(float(component) for component in raw)
    if not all(math.isfinite(component) for component in value):
        raise ValueError("nonfinite vector")
    return value  # type: ignore[return-value]


def add(first: Vector, second: Vector) -> Vector:
    return tuple(a + b for a, b in zip(first, second))  # type: ignore[return-value]


def subtract(first: Vector, second: Vector) -> Vector:
    return tuple(a - b for a, b in zip(first, second))  # type: ignore[return-value]


def scale(value: Vector, factor: float) -> Vector:
    return tuple(component * factor for component in value)  # type: ignore[return-value]


def energy(value: Vector) -> float:
    return sum(component * component for component in value)


def magnitude(value: Vector) -> float:
    return math.sqrt(energy(value))


def close(first: float, second: float, tolerance: float = 2e-9) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector_close(first: Vector, second: Vector) -> bool:
    return all(close(a, b, 2e-8) for a, b in zip(first, second))


def vector_sum(values: list[Vector]) -> Vector:
    result: Vector = (0.0, 0.0, 0.0)
    for value in values:
        result = add(result, value)
    return result


def vector_rms(values: list[Vector]) -> float:
    return math.sqrt(sum(energy(value) for value in values) / len(values))


def pairwise_difference(first: list[Vector], second: list[Vector]) -> float:
    numerator = sum(energy(subtract(a, b)) for a, b in zip(first, second))
    denominator = 0.5 * (
        sum(energy(value) for value in first)
        + sum(energy(value) for value in second)
    )
    return math.sqrt(numerator / max(denominator, 1e-30))


def relative_difference(first: Vector, second: Vector) -> float:
    return magnitude(subtract(first, second)) / max(
        magnitude(first), magnitude(second), 1e-30
    )


def audit_case(case: dict, preregistration: dict, reference_cells: int) -> tuple[dict, dict]:
    ledger = case["ledgerResult"]
    samples = ledger["samples"]
    bin_count = int(preregistration["forceBinCount"])
    bin_duration = float(preregistration["forceBinDurationSeconds"])
    substep_count = int(case["fluidStepsPerForceBin"])
    dt = bin_duration / substep_count
    requested_steps = bin_count * substep_count
    axes_match = (
        int(case["referenceLengthCells"]) == reference_cells
        and int(case["requestedSteps"]) == requested_steps
        and int(ledger["requestedSteps"]) == requested_steps
        and int(ledger["completedSteps"]) == requested_steps
        and len(samples) == requested_steps
        and all(int(item["step"]) == index for index, item in enumerate(samples, start=1))
        and all(
            abs(float(item["sourceTimeSeconds"]) - float(preregistration["frozenSourceTimeSeconds"]))
            <= 1e-8
            for item in samples
        )
    )
    forces = [vector(item["aerodynamicForceNewtons"]) for item in samples]
    reconstructed_bins = []
    bins_match = len(case["bins"]) == bin_count
    maximum_identity = 0.0
    for bin_index in range(bin_count):
        start = bin_index * substep_count
        end = start + substep_count
        values = forces[start:end]
        total = vector_sum(values)
        direct_impulse = scale(total, dt)
        impulse_mean = scale(direct_impulse, 1.0 / bin_duration)
        trapezoidal_total = add(scale(values[0], 0.5), scale(values[-1], 0.5))
        trapezoidal_total = add(trapezoidal_total, vector_sum(values[1:-1]))
        trapezoidal_mean = scale(trapezoidal_total, 1.0 / (len(values) - 1))
        reconstructed_impulse = scale(impulse_mean, bin_duration)
        identity = relative_difference(reconstructed_impulse, direct_impulse)
        maximum_identity = max(maximum_identity, identity)
        reconstructed = {
            "endpoint": values[-1],
            "trapezoidal": trapezoidal_mean,
            "impulseMean": impulse_mean,
            "impulse": direct_impulse,
        }
        reconstructed_bins.append(reconstructed)
        actual = case["bins"][bin_index]
        bins_match &= int(actual["binIndex"]) == bin_index
        bins_match &= int(actual["substepCount"]) == substep_count
        bins_match &= close(float(actual["elapsedStartSeconds"]), bin_index * bin_duration)
        bins_match &= close(float(actual["elapsedEndSeconds"]), (bin_index + 1) * bin_duration)
        bins_match &= vector_close(vector(actual["endpointForceNewtons"]), values[-1])
        bins_match &= vector_close(
            vector(actual["sampleTrapezoidalMeanForceNewtons"]), trapezoidal_mean
        )
        bins_match &= vector_close(
            vector(actual["impulsePreservingMeanForceNewtons"]), impulse_mean
        )
        bins_match &= vector_close(
            vector(actual["directForceImpulseNewtonSeconds"]), direct_impulse
        )
        bins_match &= close(float(actual["impulseIdentityRelativeError"]), identity)

    direct_total = scale(vector_sum(forces), dt)
    binned_total = vector_sum([item["impulse"] for item in reconstructed_bins])
    topology = [vector(item["topologyReservoirCorrectionNewtons"]) for item in samples]
    maximum_topology = max(magnitude(value) for value in topology)
    aerodynamic_rms = vector_rms(forces)
    raw_budget_rms = vector_rms(
        [vector(item["rawControlVolumeBudgetForceNewtons"]) for item in samples]
    )
    raw_residual_rms = vector_rms(
        [vector(item["rawControlVolumeClosureResidualNewtons"]) for item in samples]
    )
    global_budget_rms = vector_rms(
        [vector(item["globalFluidBudgetForceNewtons"]) for item in samples]
    )
    global_residual_rms = vector_rms(
        [vector(item["globalFluidClosureResidualNewtons"]) for item in samples]
    )
    relative_raw = raw_residual_rms / max(aerodynamic_rms, raw_budget_rms, 1e-30)
    relative_global = global_residual_rms / max(
        aerodynamic_rms, global_budget_rms, 1e-30
    )
    minimum_population = min(float(item["minimumPopulation"]) for item in samples)
    topology_passed = maximum_topology <= float(
        preregistration["maximumAllowedTopologyCorrectionNewtons"]
    )
    identity_passed = maximum_identity <= float(
        preregistration["maximumAllowedImpulseIdentityRelativeError"]
    ) and relative_difference(direct_total, binned_total) <= float(
        preregistration["maximumAllowedImpulseIdentityRelativeError"]
    )
    numerical_passed = (
        bool(ledger["momentumClosurePassed"])
        and relative_raw
        <= float(preregistration["maximumAllowedRelativeRMSClosureResidual"])
        and relative_global
        <= float(preregistration["maximumAllowedRelativeRMSClosureResidual"])
        and minimum_population > 0
        and int(ledger["maximumSolidControlSurfaceCrossingLinkCount"]) == 0
        and topology_passed
        and identity_passed
    )
    checks = {
        "axes": axes_match,
        "binArithmetic": bins_match,
        "impulseTotals": vector_close(
            vector(case["directTotalForceImpulseNewtonSeconds"]), direct_total
        )
        and vector_close(
            vector(case["binnedTotalForceImpulseNewtonSeconds"]), binned_total
        ),
        "impulseIdentity": close(
            float(case["maximumImpulseIdentityRelativeError"]), maximum_identity
        )
        and case["impulseIdentityGatePassed"] is identity_passed,
        "fixedTopology": close(
            float(case["maximumTopologyCorrectionNewtons"]), maximum_topology
        )
        and case["fixedGeometryTopologyGatePassed"] is topology_passed,
        "ledgerArithmetic": close(ledger["RMSAerodynamicForceNewtons"], aerodynamic_rms)
        and close(ledger["relativeRMSRawControlVolumeClosureResidual"], relative_raw)
        and close(ledger["relativeRMSGlobalFluidClosureResidual"], relative_global)
        and close(ledger["minimumPopulation"], minimum_population),
        "caseDecision": case["numericalCaseGatePassed"] is numerical_passed
        and case["productionDefaultModified"] is False
        and case["experimentalAgreementGateApplied"] is False,
    }
    reconstructed = {
        "bins": reconstructed_bins,
        "directTotalImpulse": direct_total,
        "maximumImpulseIdentityRelativeError": maximum_identity,
        "maximumTopologyCorrectionNewtons": maximum_topology,
        "relativeRMSRawControlVolumeClosureResidual": relative_raw,
        "relativeRMSGlobalFluidClosureResidual": relative_global,
        "minimumPopulation": minimum_population,
        "numericalCaseGatePassed": numerical_passed,
    }
    return checks, reconstructed


def main() -> None:
    spatial = load(SPATIAL_PATH)
    lag_band = load(LAG_BAND_PATH)
    preregistration = load(PREREG_PATH)
    report = load(REPORT_PATH)
    expected_thresholds = {
        "referenceLengthCells": [12, 16],
        "frozenSourceSampleIndex": 53,
        "frozenSourceTimeSeconds": 0.0265,
        "forceBinDurationSeconds": 0.0005,
        "forceBinCount": 8,
        "maximumAllowedRelativeRMSClosureResidual": 0.005,
        "maximumAllowedCollisionCorrectionActivationFraction": 0.05,
        "maximumAllowedTopologyCorrectionNewtons": 1e-10,
        "maximumAllowedImpulseIdentityRelativeError": 1e-12,
        "maximumAllowedFineGridRelativeDifference": 0.05,
        "minimumAggregationImprovementFraction": 0.20,
        "maximumAggregationRelativeSpreadFraction": 0.10,
    }
    thresholds_match = all(
        preregistration[key] == value for key, value in expected_thresholds.items()
    )
    source_match = (
        preregistration["sourceSpatialDiscriminatorSHA256"] == sha256(SPATIAL_PATH)
        and preregistration["sourceLagBandSHA256"] == sha256(LAG_BAND_PATH)
        and report["sourceTemporalPreregistrationSHA256"] == sha256(PREREG_PATH)
        and report["sourceSpatialDiscriminatorSHA256"] == sha256(SPATIAL_PATH)
        and report["sourceLagBandSHA256"] == sha256(LAG_BAND_PATH)
        and spatial["fineGridForceConvergencePassed"] is False
        and lag_band["classification"] == "mixed-unresolved"
        and lag_band["d20DiagnosticAuthorized"] is False
    )
    d12_checks, d12 = audit_case(report["d12"], preregistration, 12)
    d16_checks, d16 = audit_case(report["d16"], preregistration, 16)
    endpoint = pairwise_difference(
        [item["endpoint"] for item in d12["bins"]],
        [item["endpoint"] for item in d16["bins"]],
    )
    trapezoidal = pairwise_difference(
        [item["trapezoidal"] for item in d12["bins"]],
        [item["trapezoidal"] for item in d16["bins"]],
    )
    impulse = pairwise_difference(
        [item["impulseMean"] for item in d12["bins"]],
        [item["impulseMean"] for item in d16["bins"]],
    )
    values = [endpoint, trapezoidal, impulse]
    spread = (max(values) - min(values)) / max(max(values), 1e-30)
    improvement = 1.0 - impulse / max(endpoint, 1e-30)
    total_impulse_difference = relative_difference(
        d12["directTotalImpulse"], d16["directTotalImpulse"]
    )
    limit = float(preregistration["maximumAllowedFineGridRelativeDifference"])
    aggregation_sensitive = (
        impulse <= limit
        and endpoint > limit
        and improvement
        >= float(preregistration["minimumAggregationImprovementFraction"])
    )
    fixed_cleared = all(value <= limit for value in values)
    invariant_disagreement = all(value > limit for value in values) and spread <= float(
        preregistration["maximumAggregationRelativeSpreadFraction"]
    )
    classification = (
        "temporal-aggregation-sensitive"
        if aggregation_sensitive
        else "fixed-geometry-grid-cleared"
        if fixed_cleared
        else "aggregation-invariant-grid-disagreement"
        if invariant_disagreement
        else "mixed-unresolved"
    )
    metrics = report["metrics"]
    metric_arithmetic = (
        close(metrics["endpointPairwiseNormalizedRMSDifference"], endpoint)
        and close(
            metrics["sampleTrapezoidalPairwiseNormalizedRMSDifference"],
            trapezoidal,
        )
        and close(
            metrics["impulsePreservingPairwiseNormalizedRMSDifference"], impulse
        )
        and close(metrics["endpointToImpulseImprovementFraction"], improvement)
        and close(metrics["aggregationRelativeSpreadFraction"], spread)
        and close(metrics["directTotalImpulseRelativeDifference"], total_impulse_difference)
    )
    checks = {
        "sourceHashes": source_match,
        "fixedThresholds": thresholds_match and preregistration["passed"] is True,
        "d12Axes": d12_checks["axes"],
        "d12BinArithmetic": d12_checks["binArithmetic"],
        "d12ImpulseAndTopology": all(
            d12_checks[key]
            for key in ("impulseTotals", "impulseIdentity", "fixedTopology")
        ),
        "d12LedgerAndDecision": d12_checks["ledgerArithmetic"]
        and d12_checks["caseDecision"],
        "d16Axes": d16_checks["axes"],
        "d16BinArithmetic": d16_checks["binArithmetic"],
        "d16ImpulseAndTopology": all(
            d16_checks[key]
            for key in ("impulseTotals", "impulseIdentity", "fixedTopology")
        ),
        "d16LedgerAndDecision": d16_checks["ledgerArithmetic"]
        and d16_checks["caseDecision"],
        "metricArithmetic": metric_arithmetic,
        "classification": report["classification"] == classification
        and report["temporalAggregationSensitivityLikely"] is aggregation_sensitive
        and report["fixedGeometryGridResponseCleared"] is fixed_cleared
        and report["aggregationInvariantGridDisagreementLikely"] is invariant_disagreement,
        "claimBoundary": report["d20DiagnosticAuthorized"] is False
        and report["rawSpatialGateModified"] is False
        and report["productionPromotionAuthorized"] is False
        and report["experimentalAgreementGateApplied"] is False,
    }
    passed = all(checks.values())
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-temporal-sampling.py",
        "preregistrationSHA256": sha256(PREREG_PATH),
        "reportSHA256": sha256(REPORT_PATH),
        "checks": checks,
        "reconstructed": {
            "endpointPairwiseNormalizedRMSDifference": endpoint,
            "sampleTrapezoidalPairwiseNormalizedRMSDifference": trapezoidal,
            "impulsePreservingPairwiseNormalizedRMSDifference": impulse,
            "endpointToImpulseImprovementFraction": improvement,
            "aggregationRelativeSpreadFraction": spread,
            "directTotalImpulseRelativeDifference": total_impulse_difference,
            "d12MaximumTopologyCorrectionNewtons": d12[
                "maximumTopologyCorrectionNewtons"
            ],
            "d16MaximumTopologyCorrectionNewtons": d16[
                "maximumTopologyCorrectionNewtons"
            ],
            "classification": classification,
            "d20DiagnosticAuthorized": False,
        },
        "allChecksPassed": passed,
        "claimBoundary": (
            "Independent source-hash, preregistration, per-step ledger, per-bin "
            "quadrature, impulse, fixed-topology, metric, classification, and "
            "allocation audit. A pass authenticates the diagnostic result only."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("temporal-sampling audit failed: " + ", ".join(failed))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

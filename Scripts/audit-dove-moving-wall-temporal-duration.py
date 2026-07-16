#!/usr/bin/env python3
"""Independently audit the 24-bin fixed-wall duration discriminator."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
TEMPORAL_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-sampling-preregistration.json"
BASELINE_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-sampling.json"
DURATION_PREREG_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration-preregistration.json"
REPORT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration.json"
OUTPUT_PATH = ARTIFACTS / "deetjen-dove-moving-wall-temporal-duration-audit.json"

Vector = tuple[float, float, float]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def vector(raw: object) -> Vector:
    if not isinstance(raw, list) or len(raw) != 3:
        raise ValueError("expected three-component vector")
    return tuple(float(value) for value in raw)  # type: ignore[return-value]


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


def relative_difference(first: Vector, second: Vector) -> float:
    return magnitude(subtract(first, second)) / max(
        magnitude(first), magnitude(second), 1e-30
    )


def pairwise_difference(first: list[Vector], second: list[Vector]) -> float:
    numerator = sum(energy(subtract(a, b)) for a, b in zip(first, second))
    denominator = 0.5 * (
        sum(energy(value) for value in first)
        + sum(energy(value) for value in second)
    )
    return math.sqrt(numerator / max(denominator, 1e-30))


def reconstruct_case(case: dict, preregistration: dict) -> tuple[list[dict], dict]:
    ledger = case["ledgerResult"]
    samples = ledger["samples"]
    bin_count = int(case["forceBinCount"])
    substeps = int(case["fluidStepsPerForceBin"])
    duration = float(case["forceBinDurationSeconds"])
    dt = duration / substeps
    forces = [vector(item["aerodynamicForceNewtons"]) for item in samples]
    bins = []
    bin_arithmetic = len(case["bins"]) == bin_count
    maximum_identity = 0.0
    for index in range(bin_count):
        values = forces[index * substeps : (index + 1) * substeps]
        impulse = scale(vector_sum(values), dt)
        impulse_mean = scale(impulse, 1.0 / duration)
        trapezoidal = add(scale(values[0], 0.5), scale(values[-1], 0.5))
        trapezoidal = scale(add(trapezoidal, vector_sum(values[1:-1])), 1.0 / (substeps - 1))
        identity = relative_difference(scale(impulse_mean, duration), impulse)
        maximum_identity = max(maximum_identity, identity)
        rebuilt = {
            "endpoint": values[-1],
            "trapezoidal": trapezoidal,
            "impulseMean": impulse_mean,
            "impulse": impulse,
        }
        bins.append(rebuilt)
        actual = case["bins"][index]
        bin_arithmetic &= int(actual["binIndex"]) == index
        bin_arithmetic &= int(actual["substepCount"]) == substeps
        bin_arithmetic &= vector_close(vector(actual["endpointForceNewtons"]), rebuilt["endpoint"])
        bin_arithmetic &= vector_close(
            vector(actual["sampleTrapezoidalMeanForceNewtons"]), rebuilt["trapezoidal"]
        )
        bin_arithmetic &= vector_close(
            vector(actual["impulsePreservingMeanForceNewtons"]), rebuilt["impulseMean"]
        )
        bin_arithmetic &= vector_close(
            vector(actual["directForceImpulseNewtonSeconds"]), rebuilt["impulse"]
        )
    raw_residual = [vector(item["rawControlVolumeClosureResidualNewtons"]) for item in samples]
    raw_budget = [vector(item["rawControlVolumeBudgetForceNewtons"]) for item in samples]
    global_residual = [vector(item["globalFluidClosureResidualNewtons"]) for item in samples]
    global_budget = [vector(item["globalFluidBudgetForceNewtons"]) for item in samples]
    aerodynamic_rms = vector_rms(forces)
    near = vector_rms(raw_residual) / max(aerodynamic_rms, vector_rms(raw_budget), 1e-30)
    global_value = vector_rms(global_residual) / max(
        aerodynamic_rms, vector_rms(global_budget), 1e-30
    )
    topology = max(
        magnitude(vector(item["topologyReservoirCorrectionNewtons"])) for item in samples
    )
    axes = (
        len(samples) == bin_count * substeps
        and int(ledger["completedSteps"]) == len(samples)
        and all(int(item["step"]) == index for index, item in enumerate(samples, start=1))
        and all(
            abs(float(item["sourceTimeSeconds"]) - float(preregistration["frozenSourceTimeSeconds"]))
            <= 1e-8
            for item in samples
        )
    )
    case_checks = {
        "axes": axes,
        "bins": bin_arithmetic,
        "impulseIdentity": close(case["maximumImpulseIdentityRelativeError"], maximum_identity)
        and maximum_identity
        <= float(preregistration["maximumAllowedImpulseIdentityRelativeError"]),
        "fixedTopology": close(case["maximumTopologyCorrectionNewtons"], topology)
        and topology <= float(preregistration["maximumAllowedTopologyCorrectionNewtons"]),
        "ledgers": close(ledger["relativeRMSRawControlVolumeClosureResidual"], near)
        and close(ledger["relativeRMSGlobalFluidClosureResidual"], global_value)
        and ledger["momentumClosurePassed"] is True
        and case["numericalCaseGatePassed"] is True,
    }
    return bins, case_checks


def metrics(d12: list[dict], d16: list[dict]) -> dict:
    endpoint = pairwise_difference(
        [item["endpoint"] for item in d12], [item["endpoint"] for item in d16]
    )
    trapezoidal = pairwise_difference(
        [item["trapezoidal"] for item in d12],
        [item["trapezoidal"] for item in d16],
    )
    impulse_history = pairwise_difference(
        [item["impulseMean"] for item in d12],
        [item["impulseMean"] for item in d16],
    )
    values = [endpoint, trapezoidal, impulse_history]
    return {
        "endpointPairwiseNormalizedRMSDifference": endpoint,
        "sampleTrapezoidalPairwiseNormalizedRMSDifference": trapezoidal,
        "impulsePreservingPairwiseNormalizedRMSDifference": impulse_history,
        "endpointToImpulseImprovementFraction": 1.0
        - impulse_history / max(endpoint, 1e-30),
        "aggregationRelativeSpreadFraction": (max(values) - min(values))
        / max(max(values), 1e-30),
        "directTotalImpulseRelativeDifference": relative_difference(
            vector_sum([item["impulse"] for item in d12]),
            vector_sum([item["impulse"] for item in d16]),
        ),
    }


def metrics_match(actual: dict, rebuilt: dict) -> bool:
    return all(close(float(actual[key]), value) for key, value in rebuilt.items())


def main() -> None:
    temporal_preregistration = load(TEMPORAL_PREREG_PATH)
    baseline = load(BASELINE_PATH)
    duration_preregistration = load(DURATION_PREREG_PATH)
    report = load(REPORT_PATH)
    extended = report["extendedSampling"]
    thresholds = {
        "baselineForceBinCount": 8,
        "extendedForceBinCount": 24,
        "nestedPrefixBinCounts": [8, 16, 24],
        "blockBinCount": 8,
        "maximumAllowedPrefixReproductionRelativeError": 1e-12,
        "maximumAllowedFineGridRelativeDifference": 0.05,
        "minimumLateBlockImprovementFraction": 0.20,
    }
    sources = (
        duration_preregistration["sourceTemporalPreregistrationSHA256"]
        == sha256(TEMPORAL_PREREG_PATH)
        and duration_preregistration["sourceTemporalSamplingSHA256"]
        == sha256(BASELINE_PATH)
        and report["sourceDurationPreregistrationSHA256"]
        == sha256(DURATION_PREREG_PATH)
        and report["sourceTemporalSamplingSHA256"] == sha256(BASELINE_PATH)
    )
    d12, d12_checks = reconstruct_case(extended["d12"], temporal_preregistration)
    d16, d16_checks = reconstruct_case(extended["d16"], temporal_preregistration)
    prefix_windows = []
    prefix_arithmetic = len(report["prefixWindows"]) == 3
    for index, count in enumerate(thresholds["nestedPrefixBinCounts"]):
        rebuilt = metrics(d12[:count], d16[:count])
        prefix_windows.append(rebuilt)
        actual = report["prefixWindows"][index]
        prefix_arithmetic &= actual["identifier"] == f"prefix-{count}"
        prefix_arithmetic &= int(actual["startBin"]) == 0
        prefix_arithmetic &= int(actual["endBinExclusive"]) == count
        prefix_arithmetic &= metrics_match(actual["metrics"], rebuilt)
    block_windows = []
    block_arithmetic = len(report["blockWindows"]) == 3
    for index, start in enumerate((0, 8, 16)):
        end = start + 8
        rebuilt = metrics(d12[start:end], d16[start:end])
        block_windows.append(rebuilt)
        actual = report["blockWindows"][index]
        block_arithmetic &= actual["identifier"] == f"block-{start}-{end}"
        block_arithmetic &= int(actual["startBin"]) == start
        block_arithmetic &= int(actual["endBinExclusive"]) == end
        block_arithmetic &= metrics_match(actual["metrics"], rebuilt)

    reproduction_error = 0.0
    for grid in ("d12", "d16"):
        for index in range(8):
            old = baseline[grid]["bins"][index]
            new = extended[grid]["bins"][index]
            for key in (
                "endpointForceNewtons",
                "sampleTrapezoidalMeanForceNewtons",
                "impulsePreservingMeanForceNewtons",
                "directForceImpulseNewtonSeconds",
            ):
                reproduction_error = max(
                    reproduction_error,
                    relative_difference(vector(old[key]), vector(new[key])),
                )
    prefix_reproduced = reproduction_error <= float(
        duration_preregistration["maximumAllowedPrefixReproductionRelativeError"]
    )
    first = block_windows[0]["impulsePreservingPairwiseNormalizedRMSDifference"]
    late = block_windows[-1]["impulsePreservingPairwiseNormalizedRMSDifference"]
    late_improvement = 1.0 - late / max(first, 1e-30)
    final = prefix_windows[-1]
    limit = float(duration_preregistration["maximumAllowedFineGridRelativeDifference"])
    duration_cleared = (
        prefix_reproduced
        and final["impulsePreservingPairwiseNormalizedRMSDifference"] <= limit
        and final["directTotalImpulseRelativeDifference"] <= limit
    )
    startup = (
        prefix_reproduced
        and not duration_cleared
        and first > limit
        and late <= limit
        and late_improvement
        >= float(duration_preregistration["minimumLateBlockImprovementFraction"])
        and final["directTotalImpulseRelativeDifference"] <= limit
    )
    persistent = (
        prefix_reproduced
        and not duration_cleared
        and not startup
        and all(
            item["impulsePreservingPairwiseNormalizedRMSDifference"] > limit
            for item in block_windows
        )
        and late_improvement
        < float(duration_preregistration["minimumLateBlockImprovementFraction"])
    )
    classification = (
        "invalid-prefix-reproduction"
        if not prefix_reproduced
        else "duration-cleared"
        if duration_cleared
        else "startup-relaxation"
        if startup
        else "persistent-fixed-wall-grid-disagreement"
        if persistent
        else "mixed-unresolved"
    )
    checks = {
        "sourceHashes": sources,
        "fixedThresholds": all(
            duration_preregistration[key] == value for key, value in thresholds.items()
        )
        and duration_preregistration["passed"] is True,
        "d12AxesAndBins": d12_checks["axes"] and d12_checks["bins"],
        "d12ImpulseTopologyLedgers": all(
            d12_checks[key] for key in ("impulseIdentity", "fixedTopology", "ledgers")
        ),
        "d16AxesAndBins": d16_checks["axes"] and d16_checks["bins"],
        "d16ImpulseTopologyLedgers": all(
            d16_checks[key] for key in ("impulseIdentity", "fixedTopology", "ledgers")
        ),
        "prefixArithmetic": prefix_arithmetic,
        "blockArithmetic": block_arithmetic,
        "baselinePrefixReproduction": close(
            report["baselinePrefixMaximumRelativeError"], reproduction_error
        )
        and report["baselinePrefixReproduced"] is prefix_reproduced,
        "durationDecision": report["durationCleared"] is duration_cleared,
        "mechanismDecision": report["startupRelaxationLikely"] is startup
        and report["persistentFixedWallGridDisagreementLikely"] is persistent,
        "classification": report["classification"] == classification
        and close(report["lateBlockImprovementFraction"], late_improvement),
        "claimBoundary": report["d20DiagnosticAuthorized"] is False
        and report["rawSpatialGateModified"] is False
        and report["productionPromotionAuthorized"] is False
        and report["experimentalAgreementGateApplied"] is False,
    }
    passed = all(checks.values())
    output = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-moving-wall-temporal-duration.py",
        "durationPreregistrationSHA256": sha256(DURATION_PREREG_PATH),
        "reportSHA256": sha256(REPORT_PATH),
        "checks": checks,
        "reconstructed": {
            "baselinePrefixMaximumRelativeError": reproduction_error,
            "prefixImpulseHistoryDifferences": [
                item["impulsePreservingPairwiseNormalizedRMSDifference"]
                for item in prefix_windows
            ],
            "blockImpulseHistoryDifferences": [
                item["impulsePreservingPairwiseNormalizedRMSDifference"]
                for item in block_windows
            ],
            "prefixTotalImpulseDifferences": [
                item["directTotalImpulseRelativeDifference"] for item in prefix_windows
            ],
            "lateBlockImprovementFraction": late_improvement,
            "classification": classification,
            "d20DiagnosticAuthorized": False,
        },
        "allChecksPassed": passed,
        "claimBoundary": (
            "Independent source-hash, 1,344-step force, 48-bin quadrature, "
            "baseline reproduction, nested-window, ledger, classification, and "
            "allocation audit. A pass authenticates the duration result only."
        ),
    }
    OUTPUT_PATH.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n")
    if not passed:
        failed = [name for name, value in checks.items() if not value]
        raise SystemExit("temporal-duration audit failed: " + ", ".join(failed))
    print(json.dumps(output, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

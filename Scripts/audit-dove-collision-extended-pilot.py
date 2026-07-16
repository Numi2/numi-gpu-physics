#!/usr/bin/env python3
"""Independently audit the committed full-window dove collision pilot."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_PATH = (
    ROOT / "ValidationArtifacts/deetjen-dove-collision-extended-pilot.json"
)
AUDIT_PATH = (
    ROOT
    / "ValidationArtifacts/deetjen-dove-collision-extended-pilot-audit.json"
)
SURFACE_PATH = ROOT / "ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json"
TARGET_PATH = ROOT / "ValidationInputs/deetjen-ob-f03-force-v1.json"

SURFACE_SHA256 = (
    "ad42148aa9ee72d994d668ba16f8b6572cb8b192b77539fe66d97586ed9e1a13"
)
TARGET_SHA256 = (
    "0ec3caf21e4b22c2f7dd81e9d5b129fec2d0535dac147d486446975144d6b12c"
)
OPERATORS = [
    "positivity-preserving-regularized-bgk",
    "positivity-preserving-recursive-regularized-bgk",
]
EXPECTED_ACTIVATIONS = {
    "positivity-preserving-regularized-bgk": 55,
    "positivity-preserving-recursive-regularized-bgk": 28,
}
TOTAL_STEPS = 3_776
PRE_ROLL_STEPS = 800
COMPARISON_SAMPLES = 187
FIRST_TARGET_INDEX = 50
LAST_TARGET_INDEX = 236
SAMPLE_RATE_HERTZ = 2_000.0
GRID = (75, 69, 66)
ACTIVATION_LIMIT = 0.05


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(first: float, second: float, tolerance: float = 2.0e-10) -> bool:
    return abs(first - second) <= tolerance * max(abs(first), abs(second), 1.0)


def vector3(value: object) -> tuple[float, float, float]:
    if not isinstance(value, list) or len(value) != 3:
        raise ValueError("expected three-component vector")
    result = tuple(float(component) for component in value)
    if not all(math.isfinite(component) for component in result):
        raise ValueError("nonfinite vector")
    return result  # type: ignore[return-value]


def mean(values: list[float]) -> float:
    return sum(values) / len(values)


def trapezoidal_impulse(values: list[float]) -> float:
    return sum(
        0.5 * (values[index - 1] + values[index]) / SAMPLE_RATE_HERTZ
        for index in range(1, len(values))
    )


def normalized_rms_error(
    measured: list[tuple[float, float]],
    computed: list[tuple[float, float]],
) -> float:
    numerator = sum(
        (actual[0] - target[0]) ** 2 + (actual[1] - target[1]) ** 2
        for target, actual in zip(measured, computed)
    )
    denominator = sum(x * x + z * z for x, z in measured)
    return math.sqrt(numerator / max(denominator, 1.0e-30))


def pairwise_normalized_rms_difference(
    first: list[tuple[float, float, float]],
    second: list[tuple[float, float, float]],
) -> float:
    numerator = sum(
        sum((a - b) ** 2 for a, b in zip(lhs, rhs))
        for lhs, rhs in zip(first, second)
    )
    first_energy = sum(sum(value * value for value in item) for item in first)
    second_energy = sum(sum(value * value for value in item) for item in second)
    return math.sqrt(
        numerator / max(0.5 * (first_energy + second_energy), 1.0e-30)
    )


def peak_time(
    times: list[float],
    values: list[tuple[float, float]],
) -> float:
    index = max(
        range(len(values)),
        key=lambda item: values[item][0] ** 2 + values[item][1] ** 2,
    )
    return times[index]


def audit_case(
    case: dict[str, object],
    target: dict[str, object],
) -> tuple[dict[str, object], list[tuple[float, float, float]], list[tuple[float, float, float]]]:
    operator = str(case["collisionOperator"])
    report = case["report"]
    if not isinstance(report, dict):
        raise ValueError(f"{operator}: child report missing")
    samples = report.get("samples")
    if not isinstance(samples, list) or len(samples) != COMPARISON_SAMPLES:
        raise ValueError(f"{operator}: comparison sample count drift")
    target_samples = target["samples"]
    if not isinstance(target_samples, dict):
        raise ValueError("target samples missing")
    target_times = target_samples["timesSeconds"]
    target_x = target_samples["forceXNewtons"]
    target_z = target_samples["forceZNewtons"]
    if not all(isinstance(values, list) for values in (target_times, target_x, target_z)):
        raise ValueError("malformed target arrays")

    measured: list[tuple[float, float]] = []
    endpoint_xz: list[tuple[float, float]] = []
    interval_xz: list[tuple[float, float]] = []
    endpoint_xyz: list[tuple[float, float, float]] = []
    interval_xyz: list[tuple[float, float, float]] = []
    times: list[float] = []
    sample_minimum = math.inf
    for offset, raw_sample in enumerate(samples):
        if not isinstance(raw_sample, dict):
            raise ValueError(f"{operator}: malformed sample")
        target_index = FIRST_TARGET_INDEX + offset
        if int(raw_sample["targetSampleIndex"]) != target_index:
            raise ValueError(f"{operator}: noncontiguous target indices")
        time = float(raw_sample["sourceTimeSeconds"])
        expected_time = float(target_times[target_index])
        x = float(target_x[target_index])
        z = float(target_z[target_index])
        if not close(time, expected_time) or not close(
            float(raw_sample["measuredForceXNewtons"]), x
        ) or not close(float(raw_sample["measuredForceZNewtons"]), z):
            raise ValueError(f"{operator}: registered target mismatch")
        endpoint = vector3(raw_sample["endpointComputedForceNewtons"])
        interval = vector3(raw_sample["intervalMeanComputedForceNewtons"])
        if not close(float(raw_sample["endpointResidualXNewtons"]), endpoint[0] - x):
            raise ValueError(f"{operator}: endpoint x residual drift")
        if not close(float(raw_sample["endpointResidualZNewtons"]), endpoint[2] - z):
            raise ValueError(f"{operator}: endpoint z residual drift")
        if not close(float(raw_sample["intervalMeanResidualXNewtons"]), interval[0] - x):
            raise ValueError(f"{operator}: interval x residual drift")
        if not close(float(raw_sample["intervalMeanResidualZNewtons"]), interval[2] - z):
            raise ValueError(f"{operator}: interval z residual drift")
        counts = raw_sample.get("componentSolidCellCounts")
        if not isinstance(counts, list) or len(counts) != 4 or min(map(int, counts)) <= 0:
            raise ValueError(f"{operator}: component coverage drift")
        minimum = float(raw_sample["minimumPopulation"])
        if not math.isfinite(minimum) or minimum <= 0:
            raise ValueError(f"{operator}: nonpositive comparison population")
        sample_minimum = min(sample_minimum, minimum)
        measured.append((x, z))
        endpoint_xz.append((endpoint[0], endpoint[2]))
        interval_xz.append((interval[0], interval[2]))
        endpoint_xyz.append(endpoint)
        interval_xyz.append(interval)
        times.append(time)

    endpoint_error = normalized_rms_error(measured, endpoint_xz)
    interval_error = normalized_rms_error(measured, interval_xz)
    activation_count = int(float(report["collisionLimiterActivationCount"]))
    expected_fraction = activation_count / (TOTAL_STEPS * math.prod(GRID))
    summaries = {
        "measuredMeanForceXNewtons": mean([value[0] for value in measured]),
        "measuredMeanForceZNewtons": mean([value[1] for value in measured]),
        "endpointMeanForceXNewtons": mean([value[0] for value in endpoint_xz]),
        "endpointMeanForceZNewtons": mean([value[1] for value in endpoint_xz]),
        "intervalMeanForceXNewtons": mean([value[0] for value in interval_xz]),
        "intervalMeanForceZNewtons": mean([value[1] for value in interval_xz]),
        "measuredImpulseXNewtonSeconds": trapezoidal_impulse([value[0] for value in measured]),
        "measuredImpulseZNewtonSeconds": trapezoidal_impulse([value[1] for value in measured]),
        "endpointImpulseXNewtonSeconds": trapezoidal_impulse([value[0] for value in endpoint_xz]),
        "endpointImpulseZNewtonSeconds": trapezoidal_impulse([value[1] for value in endpoint_xz]),
        "intervalMeanImpulseXNewtonSeconds": trapezoidal_impulse([value[0] for value in interval_xz]),
        "intervalMeanImpulseZNewtonSeconds": trapezoidal_impulse([value[1] for value in interval_xz]),
        "endpointNormalizedRMSError": endpoint_error,
        "intervalMeanNormalizedRMSError": interval_error,
        "measuredPeakTimeSeconds": peak_time(times, measured),
        "endpointPeakTimeSeconds": peak_time(times, endpoint_xz),
        "intervalMeanPeakTimeSeconds": peak_time(times, interval_xz),
    }
    if not all(close(float(report[key]), value, 2.0e-9) for key, value in summaries.items()):
        raise ValueError(f"{operator}: reconstructed summary drift")
    if activation_count != EXPECTED_ACTIVATIONS[operator]:
        raise ValueError(f"{operator}: activation count drift")
    if not close(
        float(report["collisionLimiterActivationFractionOfCellSteps"]),
        expected_fraction,
    ):
        raise ValueError(f"{operator}: activation fraction drift")
    failure_keys = [
        key
        for key in report
        if key.startswith("firstNonFinite") or key.startswith("firstNegative")
    ]
    fixed_run_passed = (
        int(report["completedFluidSteps"]) == TOTAL_STEPS
        and int(report["recordedComparisonSamples"]) == COMPARISON_SAMPLES
        and int(report["recordedPopulationDiagnosticSamples"]) == TOTAL_STEPS
        and int(report["populationDiagnosticStride"]) == 1
        and tuple(int(report[key]) for key in ("gridX", "gridY", "gridZ")) == GRID
        and bool(report["allComponentsPresentAtComparisonSamples"])
        and bool(report["allLoadsFinite"])
        and bool(report["allSampledPopulationsFinite"])
        and bool(report["sampledPopulationPositivityPassed"])
        and bool(report["integrationGatePassed"])
        and float(report["minimumSampledPopulation"]) > 0
        and sample_minimum >= float(report["minimumSampledPopulation"])
        and expected_fraction <= ACTIVATION_LIMIT
        and not failure_keys
    )
    if any(
        bool(case[key]) != fixed_run_passed
        for key in (
            "completionAndPositivityGatePassed",
            "correctionIntrusionGatePassed",
            "eligibleForRefinementDiscrimination",
        )
    ):
        raise ValueError(f"{operator}: case verdict drift")
    return (
        {
            "operator": operator,
            "completedFluidSteps": int(report["completedFluidSteps"]),
            "minimumSampledPopulation": float(report["minimumSampledPopulation"]),
            "collisionLimiterActivationCount": activation_count,
            "collisionLimiterActivationFractionOfCellSteps": expected_fraction,
            "endpointNormalizedRMSError": endpoint_error,
            "intervalMeanNormalizedRMSError": interval_error,
            "registeredForceErrorsUsedAsGate": False,
            "passed": fixed_run_passed,
        },
        endpoint_xyz,
        interval_xyz,
    )


def main() -> None:
    report = json.loads(REPORT_PATH.read_text())
    target = json.loads(TARGET_PATH.read_text())
    manifest = json.loads(SURFACE_PATH.read_text())
    cases = report.get("cases")
    if not isinstance(cases, list):
        raise SystemExit("extended-pilot report has no cases")
    operators = [str(case["collisionOperator"]) for case in cases]
    plans = [case["report"]["plan"] for case in cases]
    plan = plans[0]
    checks = {
        "schemaAndHashes": report.get("schemaVersion") == 1
        and sha256(SURFACE_PATH) == SURFACE_SHA256
        and sha256(TARGET_PATH) == TARGET_SHA256
        and report.get("manifestSHA256") == SURFACE_SHA256
        and report.get("forceTargetSHA256") == TARGET_SHA256
        and report.get("datasetIdentifier") == manifest.get("datasetIdentifier")
        and report.get("forceTargetIdentifier") == target.get("datasetIdentifier"),
        "candidateOrder": operators == OPERATORS,
        "identicalPlans": plans[1:] == plans[:-1],
        "fixedRunContract": report.get("requestedFluidSteps") == TOTAL_STEPS
        and report.get("requestedComparisonSamples") == COMPARISON_SAMPLES
        and report.get("populationDiagnosticStride") == 1
        and close(float(report.get("maximumCorrectionActivationFraction")), ACTIVATION_LIMIT)
        and plan.get("totalFluidSteps") == TOTAL_STEPS
        and plan.get("preRollFluidSteps") == PRE_ROLL_STEPS
        and plan.get("comparisonForceSamples") == COMPARISON_SAMPLES
        and plan.get("fluidStepsPerForceSample") == 16,
        "registeredWindow": target["comparisonWindow"]["firstTargetSampleIndex"]
        == FIRST_TARGET_INDEX
        and target["comparisonWindow"]["lastTargetSampleIndex"]
        == LAST_TARGET_INDEX
        and target["comparisonWindow"]["sampleCount"] == COMPARISON_SAMPLES,
        "nonAcceptanceBoundary": not report.get("experimentalAgreementGateApplied")
        and "descriptive only" in str(report.get("claimBoundary"))
        and "does not select a production operator" in str(report.get("claimBoundary")),
    }
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("extended-pilot contract failed: " + ", ".join(failed))

    audited = [audit_case(case, target) for case in cases]
    case_results = [item[0] for item in audited]
    endpoint_difference = pairwise_normalized_rms_difference(
        audited[0][1], audited[1][1]
    )
    interval_difference = pairwise_normalized_rms_difference(
        audited[0][2], audited[1][2]
    )
    checks.update(
        {
            "bothCandidatesCompleted": all(bool(item["passed"]) for item in case_results),
            "endpointPairwiseDifference": close(
                float(report["endpointPairwiseNormalizedRMSDifference"]),
                endpoint_difference,
            ),
            "intervalPairwiseDifference": close(
                float(report["intervalMeanPairwiseNormalizedRMSDifference"]),
                interval_difference,
            ),
            "bothCandidatesEligible": report.get("eligibleCollisionOperators") == OPERATORS,
            "parentVerdict": bool(report.get("allCandidateRunsCompleted"))
            and bool(report.get("screeningGatePassed")),
            "measuredErrorsAreDescriptive": all(
                not bool(item["registeredForceErrorsUsedAsGate"])
                for item in case_results
            ),
        }
    )
    if not all(checks.values()):
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("extended-pilot audit failed: " + ", ".join(failed))

    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-collision-extended-pilot-audit-v1",
        "generatedBy": "Scripts/audit-dove-collision-extended-pilot.py",
        "reportSHA256": sha256(REPORT_PATH),
        "surfaceManifestSHA256": SURFACE_SHA256,
        "forceTargetSHA256": TARGET_SHA256,
        "checks": checks,
        "cases": case_results,
        "endpointPairwiseNormalizedRMSDifference": endpoint_difference,
        "intervalMeanPairwiseNormalizedRMSDifference": interval_difference,
        "extendedPilotGatePassed": True,
        "eligibleCollisionOperators": OPERATORS,
        "claimBoundary": (
            "This audit independently reconstructs registered samples, force "
            "statistics, correction fractions, and candidate differences. It "
            "clears both candidates only for controlled collision discrimination; "
            "coarse-grid measured-force errors remain descriptive and cannot "
            "establish experimental agreement or select a production operator."
        ),
    }
    AUDIT_PATH.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

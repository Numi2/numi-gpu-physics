#!/usr/bin/env python3
"""Independent artifact audit for the formation collision discriminator."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PREREG = ROOT / "ValidationInputs/formation-flight-collision-dissipation-discriminator-v1.json"
SUMMARY = ROOT / "ValidationArtifacts/formation-flight-collision-dissipation/formation-flight-collision-dissipation-summary.json"
AUDIT = ROOT / "ValidationArtifacts/formation-flight-collision-dissipation/formation-flight-collision-dissipation-audit.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(lhs: float, rhs: float, tolerance: float = 1e-10) -> bool:
    return math.isclose(lhs, rhs, rel_tol=tolerance, abs_tol=tolerance)


def main() -> int:
    prereg = load(PREREG)
    summary = load(SUMMARY)
    checks: list[dict] = []

    def check(name: str, passed: bool, evidence: object) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    check("preregistered before execution", prereg.get("preregisteredBeforeCandidateExecution") is True, prereg.get("preregisteredBeforeCandidateExecution"))
    for locked in prereg["lockedInputs"]:
        actual = digest(ROOT / locked["path"])
        check(f"locked input hash: {locked['path']}", actual == locked["sha256"], actual)

    candidate_path = ROOT / summary["screen"]["candidateReportPath"]
    candidate = load(candidate_path)
    check("candidate report hash", digest(candidate_path) == summary["screen"]["candidateReportSHA256"], digest(candidate_path))
    check("candidate operator exact", candidate["collisionOperator"] == prereg["candidateOperator"], candidate["collisionOperator"])
    fixed = prereg["fixedFormationConfiguration"]
    config = candidate["configuration"]
    check("candidate resolution exact", config["chordCells"] == prereg["screen"]["resolution"], config["chordCells"])
    check("candidate cycles exact", config["cycles"] == fixed["cycles"], config["cycles"])
    check("candidate offset exact", config["followerOffsetChords"] == fixed["followerOffsetChords"], config["followerOffsetChords"])
    check("candidate phase exact", config["followerPhaseOffsetCycles"] == fixed["followerPhaseOffsetCycles"], config["followerPhaseOffsetCycles"])
    check("candidate numerical gate parity", summary["screen"]["candidateNumericalGatesPassed"] == candidate["gates"]["passed"], candidate["gates"])
    check("strict population positivity", candidate["gates"]["minimumPopulation"] > 0 and candidate["gates"]["populationPositivityPassed"], candidate["gates"]["minimumPopulation"])
    check("all-population minimum parity", close(summary["screen"]["minimumPopulation"], candidate["gates"]["minimumPopulation"]), summary["screen"]["minimumPopulation"])
    check("correction fraction parity", close(summary["screen"]["collisionCorrectionActivationFraction"], candidate["gates"]["collisionCorrectionActivationFraction"]), summary["screen"]["collisionCorrectionActivationFraction"])
    check("correction non-intrusive", candidate["gates"]["collisionCorrectionActivationFraction"] <= prereg["unchangedNumericalGates"]["maximumCollisionCorrectionActivationFraction"], candidate["gates"]["collisionCorrectionActivationFraction"])
    check("owner force closure unchanged", candidate["gates"]["maximumRelativeForceClosureResidual"] <= prereg["unchangedNumericalGates"]["maximumRelativeOwnerClosureResidual"], candidate["gates"]["maximumRelativeForceClosureResidual"])
    check("owner torque closure unchanged", candidate["gates"]["maximumRelativeTorqueClosureResidual"] <= prereg["unchangedNumericalGates"]["maximumRelativeOwnerClosureResidual"], candidate["gates"]["maximumRelativeTorqueClosureResidual"])
    check("periodicity unchanged", candidate["gates"]["maximumRelativePeriodicPowerDifference"] <= prereg["unchangedNumericalGates"]["maximumRelativePeriodicPowerDifference"], candidate["gates"]["maximumRelativePeriodicPowerDifference"])
    check("zero geometry overlap", candidate["overlapVoxelSamples"] == 0 and candidate["gates"]["noGeometryOverlap"], candidate["overlapVoxelSamples"])

    phases = summary["phaseResults"]
    check("five locked phases", [item["targetFollowerPhase"] for item in phases] == prereg["screen"]["followerLocalPhases"], [item["targetFollowerPhase"] for item in phases])
    for item in phases:
        path = ROOT / item["candidateSlicePath"]
        check(f"candidate slice hash phase {item['targetFollowerPhase']}", path.is_file() and digest(path) == item["candidateSliceSHA256"], item["candidateSliceSHA256"])
        check(f"common wake support phase {item['targetFollowerPhase']}", item["commonWakeCellCount"] >= 500, item["commonWakeCellCount"])
        expected = (item["baselineTRTNormalizedResidualEnergy"] - item["candidateRR3NormalizedResidualEnergy"]) / item["baselineTRTNormalizedResidualEnergy"]
        check(f"phase reduction arithmetic {item['targetFollowerPhase']}", close(expected, item["candidateResidualEnergyReductionFraction"]), expected)

    baseline_wake = sum(item["baselineTRTNormalizedResidualEnergy"] for item in phases)
    candidate_wake = sum(item["candidateRR3NormalizedResidualEnergy"] for item in phases)
    wake_reduction = (baseline_wake - candidate_wake) / baseline_wake
    screen = summary["screen"]
    check("aggregate baseline wake arithmetic", close(baseline_wake, screen["aggregateBaselineWakeResidualEnergy"]), baseline_wake)
    check("aggregate candidate wake arithmetic", close(candidate_wake, screen["aggregateCandidateWakeResidualEnergy"]), candidate_wake)
    check("aggregate wake reduction arithmetic", close(wake_reduction, screen["aggregateWakeResidualEnergyReductionFraction"]), wake_reduction)
    baseline_force = sum(screen["baselineForceSignalEnergies"].values())
    candidate_force = sum(screen["candidateForceSignalEnergies"].values())
    force_reduction = (baseline_force - candidate_force) / baseline_force
    check("baseline force energy arithmetic", close(baseline_force, screen["baselineDimensionlessForceResidualEnergy"]), baseline_force)
    check("candidate force energy arithmetic", close(candidate_force, screen["candidateDimensionlessForceResidualEnergy"]), candidate_force)
    check("force reduction arithmetic", close(force_reduction, screen["dimensionlessForceResidualEnergyReductionFraction"]), force_reduction)

    rule = prereg["promotionRule"]
    expected_promotion = bool(candidate["gates"]["passed"]) and wake_reduction >= rule["minimumAggregateWakeResidualEnergyReductionFraction"] and force_reduction >= rule["minimumDimensionlessForceResidualEnergyReductionFraction"]
    promotion = summary["promotion"]
    check("promotion arithmetic", promotion["c20CandidateAuthorized"] == expected_promotion, expected_promotion)
    c20_path = ROOT / "ValidationArtifacts/formation-flight-collision-dissipation/c20-rr3/formation-flight-collision-diagnostic-report.json"
    check("c20 allocation parity", promotion["c20CandidateExecuted"] == c20_path.is_file(), c20_path.is_file())
    check("no unauthorized c20 allocation", expected_promotion or not c20_path.exists(), str(c20_path))
    check("production default unchanged", summary["productionCollisionOperatorChanged"] is False, summary["productionCollisionOperatorChanged"])
    check("quantitative claim remains closed", summary["quantitativeFormationClaimAuthorized"] is False, summary["quantitativeFormationClaimAuthorized"])

    fine = summary.get("fineRun")
    if fine is not None:
        fine_path = ROOT / fine["reportPath"]
        fine_report = load(fine_path)
        thresholds = prereg["fineRunInterpretation"]
        expected_fine = fine_report["gates"]["passed"] and fine["sameOperatorC16ToC20ForceHistoryRelativeDifference"] <= thresholds["maximumAcceptableSameOperatorC16ToC20ForceHistoryRelativeDifference"] and fine["c20TRTToRR3ForceHistoryRelativeDifference"] <= thresholds["maximumAcceptableC20TRTToRR3ForceHistoryRelativeDifference"]
        check("fine report hash", digest(fine_path) == fine["reportSHA256"], digest(fine_path))
        check("fine operator exact", fine_report["collisionOperator"] == prereg["candidateOperator"], fine_report["collisionOperator"])
        check("fine decision arithmetic", fine["fineRunQualified"] == expected_fine, expected_fine)

    passed = all(item["passed"] for item in checks)
    result = {
        "schemaVersion": 1,
        "summaryPath": str(SUMMARY.relative_to(ROOT)),
        "summarySHA256": digest(SUMMARY),
        "preregistrationPath": str(PREREG.relative_to(ROOT)),
        "preregistrationSHA256": digest(PREREG),
        "checksPassed": sum(item["passed"] for item in checks),
        "checkCount": len(checks),
        "checks": checks,
        "passed": passed,
    }
    AUDIT.parent.mkdir(parents=True, exist_ok=True)
    AUDIT.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n")
    print(f"formation collision audit: {result['checksPassed']}/{result['checkCount']} checks passed")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

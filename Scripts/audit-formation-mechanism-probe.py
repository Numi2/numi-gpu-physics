#!/usr/bin/env python3
"""Independent reconstruction of the Formation Observatory mechanism result."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parent.parent
PREREGISTRATION = ROOT / "ValidationInputs/formation-flight-mechanism-probe-v1.json"
ARCHIVE_ROOT = ROOT / "ValidationArtifacts/formation-flight-mechanism-probe"
SUMMARY = ARCHIVE_ROOT / "formation-flight-mechanism-summary.json"
AUDIT = ARCHIVE_ROOT / "formation-flight-mechanism-audit.json"
EARLY_SUMMARY = ROOT / "ValidationArtifacts/formation-flight-early-cycle-replay/formation-flight-early-cycle-field-summary.json"
COMPONENTS = (
    "reflectedPopulation",
    "interpolationAuxiliary",
    "movingWall",
    "coverImpulse",
    "uncoverImpulse",
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(lhs: float, rhs: float, tolerance: float = 2e-9) -> bool:
    return math.isclose(lhs, rhs, rel_tol=tolerance, abs_tol=tolerance)


def select_sample(mechanism: dict, flyer: str, target: float, cycle_steps: int) -> dict:
    matches = [
        sample for sample in mechanism["samples"]
        if sample["flyer"] == flyer
        and abs(sample["followerPhase"] - target) <= 0.5 / cycle_steps + 1e-12
    ]
    if len(matches) != 1:
        raise AssertionError(f"expected one {flyer} sample at {target}")
    return matches[0]


def main() -> int:
    prereg = load(PREREGISTRATION)
    summary = load(SUMMARY)
    early = load(EARLY_SUMMARY)
    checks: list[dict] = []

    def check(name: str, passed: bool, evidence: object) -> None:
        checks.append({"name": name, "passed": bool(passed), "evidence": evidence})

    check("preregistered before execution", prereg["preregisteredBeforeMechanismReplayExecution"], True)
    check("summary locks preregistration", summary["preregistration"]["sha256"] == sha256(PREREGISTRATION), summary["preregistration"]["sha256"])
    for locked in prereg["lockedInputs"]:
        actual = sha256(ROOT / locked["path"])
        check(f"locked input {locked['path']}", actual == locked["sha256"], actual)

    cases = {}
    for resolution in (16, 20):
        directory = ARCHIVE_ROOT / f"c{resolution}-best-z3-phase025"
        replay_path = directory / "formation-flight-field-replay-report.json"
        mechanism_path = directory / "formation-flight-mechanism-probes.json"
        reference_path = ROOT / f"ValidationArtifacts/formation-flight-promotion/c{resolution}-best-z3-phase025/formation-flight-report.json"
        replay = load(replay_path)
        mechanism = load(mechanism_path)
        reference = load(reference_path)
        cases[resolution] = (replay, mechanism, reference)
        reported = summary["cases"][f"c{resolution}"]
        check(f"c{resolution} replay SHA", sha256(replay_path) == reported["replaySHA256"], sha256(replay_path))
        check(f"c{resolution} mechanism SHA", sha256(mechanism_path) == reported["mechanismSHA256"], sha256(mechanism_path))
        check(f"c{resolution} replay gate", replay["gates"]["passed"], replay["gates"])
        check(f"c{resolution} exact history", replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"] <= prereg["gates"]["maximumRelativeReferenceCoupledHistoryDifference"], replay["gates"]["maximumRelativeReferenceCoupledHistoryDifference"])
        check(f"c{resolution} mechanism gate", mechanism["passed"], mechanism["scientificVerdict"])
        check(f"c{resolution} component order", mechanism["componentOrder"] == list(COMPONENTS), mechanism["componentOrder"])
        check(f"c{resolution} sample count", len(mechanism["samples"]) == 6, len(mechanism["samples"]))
        maximum_force = maximum_torque = maximum_power = 0.0
        for index, sample in enumerate(mechanism["samples"]):
            component_loads = [sample["components"][name] for name in COMPONENTS]
            force = np.sum(
                np.asarray(
                    [entry["load"]["forceNewtons"] for entry in component_loads],
                    dtype=np.float32,
                ),
                axis=0,
                dtype=np.float32,
            )
            torque = np.sum(
                np.asarray(
                    [entry["load"]["torqueNewtonMeters"] for entry in component_loads],
                    dtype=np.float32,
                ),
                axis=0,
                dtype=np.float32,
            )
            power = sum(entry["actuatorPowerWatts"] for entry in component_loads)
            reconstructed = sample["reconstructed"]
            check(f"c{resolution} sample {index} force reconstruction", np.allclose(force, reconstructed["load"]["forceNewtons"], rtol=2e-6, atol=2e-6), force.tolist())
            check(f"c{resolution} sample {index} torque reconstruction", np.allclose(torque, reconstructed["load"]["torqueNewtonMeters"], rtol=2e-6, atol=2e-6), torque.tolist())
            check(f"c{resolution} sample {index} power reconstruction", close(power, reconstructed["actuatorPowerWatts"], 2e-6), power)
            maximum_force = max(maximum_force, sample["relativeForceClosureResidual"])
            maximum_torque = max(maximum_torque, sample["relativeTorqueClosureResidual"])
            maximum_power = max(maximum_power, sample["relativePowerClosureResidual"])
        check(f"c{resolution} maximum force closure", close(maximum_force, mechanism["maximumRelativeForceClosureResidual"]), maximum_force)
        check(f"c{resolution} maximum torque closure", close(maximum_torque, mechanism["maximumRelativeTorqueClosureResidual"]), maximum_torque)
        check(f"c{resolution} maximum power closure", close(maximum_power, mechanism["maximumRelativePowerClosureResidual"]), maximum_power)
        limit = prereg["gates"]["maximumRelativeComponentForceClosureResidual"]
        check(f"c{resolution} closure within gate", max(maximum_force, maximum_torque, maximum_power) <= limit, max(maximum_force, maximum_torque, maximum_power))

    reconstructed_results = []
    for probe_key in ("nearBoundary", "wake"):
        target = prereg["selectedProbes"][probe_key]["followerPhase"]
        powers = {}
        production = {}
        for resolution in (16, 20):
            replay, mechanism, reference = cases[resolution]
            sample = select_sample(mechanism, "follower", target, replay["cycleSteps"])
            denominator = reference["isolatedFollower"]["meanPositivePowerWatts"]
            check(f"{probe_key} c{resolution} positive denominator", math.isfinite(denominator) and denominator > 0, denominator)
            check(f"{probe_key} c{resolution} half-step phase", abs(sample["followerPhase"] - target) <= 0.5 / replay["cycleSteps"] + 1e-12, sample["followerPhase"])
            powers[resolution] = {name: sample["components"][name]["actuatorPowerWatts"] / denominator for name in COMPONENTS}
            production[resolution] = sample["production"]["actuatorPowerWatts"] / denominator
        differences = {name: powers[20][name] - powers[16][name] for name in COMPONENTS}
        l1 = sum(abs(value) for value in differences.values())
        shares = {name: abs(value) / l1 if l1 else 0 for name, value in differences.items()}
        dominant = max(COMPONENTS, key=shares.get)
        reported = next(row for row in summary["phaseResults"] if row["label"] == probe_key)
        for component in COMPONENTS:
            check(f"{probe_key} {component} difference", close(differences[component], reported["normalizedComponentPowerDifferenceC20MinusC16"][component]), differences[component])
            check(f"{probe_key} {component} attribution", close(shares[component], reported["componentAttributionFraction"][component]), shares[component])
        check(f"{probe_key} dominant component", dominant == reported["dominantComponent"], dominant)
        check(f"{probe_key} production difference", close(production[20] - production[16], reported["normalizedProductionPowerDifferenceC20MinusC16"]), production[20] - production[16])
        difference_condition = l1 / max(abs(production[20] - production[16]), 1e-12)
        check(f"{probe_key} difference conditioning", close(difference_condition, reported["componentDifferenceCancellationConditionNumber"]), difference_condition)
        for resolution in (16, 20):
            component_l1 = sum(abs(value) for value in powers[resolution].values())
            condition = component_l1 / max(abs(production[resolution]), 1e-12)
            check(f"{probe_key} c{resolution} component conditioning", close(condition, reported["resolutions"][f"c{resolution}"]["componentCancellationConditionNumber"]), condition)
        field = min(early["phaseResults"], key=lambda row: abs(row["targetFollowerPhase"] - target))
        check(f"{probe_key} field fraction", close(field["nearBoundaryResidualEnergyFraction"], reported["nearBoundaryResidualEnergyFraction"]), field["nearBoundaryResidualEnergyFraction"])
        reconstructed_results.append((probe_key, shares, dominant, 1 - field["nearBoundaryResidualEnergyFraction"]))

    near = reconstructed_results[0]
    wake = reconstructed_results[1]
    threshold = prereg["decisionRule"]["dominantComponentThreshold"]
    dominant_share = near[1][near[2]]
    if dominant_share >= threshold and near[2] in {"interpolationAuxiliary", "movingWall", "coverImpulse", "uncoverImpulse"}:
        classification = "boundaryOperatorDominated"
    elif dominant_share >= threshold and near[2] == "reflectedPopulation":
        classification = "resolvedPopulationDominated"
    elif wake[3] >= threshold:
        classification = "wakeTransportDominated"
    else:
        classification = "mixed"
    check("classification", classification == summary["classification"], classification)
    check("quantitative claim remains unauthorized", summary["quantitativeFormationClaimAuthorized"] is False, summary["quantitativeFormationClaimAuthorized"])
    passed = all(item["passed"] for item in checks)
    artifact = {
        "schemaVersion": 1,
        "summaryPath": str(SUMMARY.relative_to(ROOT)),
        "summarySHA256": sha256(SUMMARY),
        "checkCount": len(checks),
        "checks": checks,
        "classification": classification,
        "allChecksPassed": passed,
    }
    AUDIT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps({"audit": str(AUDIT.relative_to(ROOT)), "checkCount": len(checks), "classification": classification, "passed": passed}, sort_keys=True))
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

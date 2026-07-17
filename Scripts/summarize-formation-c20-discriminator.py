#!/usr/bin/env python3
"""Apply the preregistered sequential c20 formation-flight decision."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PROMOTION = ROOT / "ValidationArtifacts/formation-flight-promotion"
PREREGISTRATION = (
    ROOT / "ValidationInputs/formation-flight-c20-sequential-discriminator-v1.json"
)
C16_MAXIMUM = PROMOTION / "c16-best-z3-phase025/formation-flight-report.json"
C16_MINIMUM = PROMOTION / "c16-minimum-z3-phase075/formation-flight-report.json"
C20_MAXIMUM = PROMOTION / "c20-best-z3-phase025/formation-flight-report.json"
C20_MINIMUM = PROMOTION / "c20-minimum-z3-phase075/formation-flight-report.json"
OUTPUT = PROMOTION / "formation-flight-c20-discriminator-summary.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def validate_report(path: Path, chord: int, phase: float) -> dict:
    report = load(path)
    configuration = report["configuration"]
    if configuration["chordCells"] != chord:
        raise SystemExit(f"unexpected chordCells in {path}")
    if configuration["cycles"] != 5:
        raise SystemExit(f"unexpected cycle count in {path}")
    if configuration["followerOffsetChords"] != [0, 0, -3]:
        raise SystemExit(f"unexpected formation offset in {path}")
    if not math.isclose(
        configuration["followerPhaseOffsetCycles"], phase, abs_tol=1e-12
    ):
        raise SystemExit(f"unexpected phase offset in {path}")
    return report


def validate_capture_archive(report_path: Path, expected_phases: list[float]) -> dict:
    directory = report_path.parent / "formation-flight-flow-slices"
    index_path = directory / "index.json"
    index = load(index_path)
    if index["schemaVersion"] != 1 or index["plane"] != "y":
        raise SystemExit(f"invalid flow-slice index in {directory}")
    entries = index["entries"]
    if len(entries) != len(expected_phases) + 1:
        raise SystemExit(
            f"expected {len(expected_phases) + 1} field slices in {directory}"
        )
    cycle_steps = load(report_path)["cycleSteps"]
    tolerance = 0.51 / cycle_steps
    unmatched = list(expected_phases)
    files = []
    for entry in entries:
        path = directory / entry["file"]
        slice_data = load(path)
        if slice_data["phase"] != entry["leaderPhase"]:
            raise SystemExit(f"slice/index leader phase mismatch in {path}")
        count = slice_data["width"] * slice_data["height"]
        for field in (
            "vorticityMagnitudePerSecond",
            "verticalVelocityMetersPerSecond",
            "ownerMask",
        ):
            if len(slice_data[field]) != count:
                raise SystemExit(f"truncated {field} in {path}")
        if not all(
            math.isfinite(value)
            for field in (
                "vorticityMagnitudePerSecond",
                "verticalVelocityMetersPerSecond",
            )
            for value in slice_data[field]
        ):
            raise SystemExit(f"nonfinite flow slice in {path}")
        match = next(
            (
                phase
                for phase in unmatched
                if abs(entry["followerPhase"] - phase) <= tolerance
            ),
            None,
        )
        if match is not None:
            unmatched.remove(match)
        files.append(
            {
                "path": str(path.relative_to(ROOT)),
                "sha256": sha256(path),
                "leaderPhase": entry["leaderPhase"],
                "followerPhase": entry["followerPhase"],
            }
        )
    if unmatched:
        raise SystemExit(f"missing follower-local capture phases: {unmatched}")
    return {
        "indexPath": str(index_path.relative_to(ROOT)),
        "indexSHA256": sha256(index_path),
        "sliceCount": len(entries),
        "allRequestedFollowerLocalPhasesPresent": True,
        "files": files,
    }


def gate_summary(report: dict) -> dict:
    gates = report["gates"]
    return {
        "passed": gates["passed"],
        "overlapVoxelSamples": report["overlapVoxelSamples"],
        "maximumRelativeForceClosureResidual": gates[
            "maximumRelativeForceClosureResidual"
        ],
        "maximumRelativeTorqueClosureResidual": gates[
            "maximumRelativeTorqueClosureResidual"
        ],
        "maximumIsolatedRelativeClosureResidual": gates[
            "maximumIsolatedRelativeClosureResidual"
        ],
        "maximumRelativePeriodicPowerDifference": gates[
            "maximumRelativePeriodicPowerDifference"
        ],
    }


def phase_residual_diagnostics(coarse: dict, fine: dict) -> dict:
    def aligned(report: dict) -> dict[float, dict]:
        denominator = report["isolatedFollower"]["meanPositivePowerWatts"]
        return {
            round(sample["followerPhase"], 6): {
                "power": sample["followerSignedPowerWatts"] / denominator,
                "lift": sample["followerLiftCoefficient"],
                "drag": sample["followerDragCoefficient"],
            }
            for sample in report["phaseSamples"]
        }

    coarse_curve = aligned(coarse)
    fine_curve = aligned(fine)
    phases = sorted(coarse_curve)
    if len(phases) != 100 or set(phases) != set(fine_curve):
        raise SystemExit("c16/c20 phase histories do not align")

    residuals = {
        field: [
            fine_curve[phase][field] - coarse_curve[phase][field]
            for phase in phases
        ]
        for field in ("power", "lift", "drag")
    }

    def metrics(values: list[float]) -> dict:
        maximum_index = max(range(len(values)), key=lambda index: abs(values[index]))
        absolute_total = sum(abs(value) for value in values)
        midstroke = [
            index
            for index, phase in enumerate(phases)
            if 0.20 <= phase < 0.30 or 0.70 <= phase < 0.80
        ]
        return {
            "rms": math.sqrt(sum(value * value for value in values) / len(values)),
            "maximumAbsolute": abs(values[maximum_index]),
            "maximumSigned": values[maximum_index],
            "maximumPhase": phases[maximum_index],
            "pairedMidstrokeBandAbsoluteFraction": (
                sum(abs(values[index]) for index in midstroke) / absolute_total
                if absolute_total > 0
                else 0
            ),
        }

    def correlation(lhs: list[float], rhs: list[float]) -> float:
        x = [abs(value) for value in lhs]
        y = [abs(value) for value in rhs]
        mean_x = sum(x) / len(x)
        mean_y = sum(y) / len(y)
        numerator = sum((a - mean_x) * (b - mean_y) for a, b in zip(x, y))
        denominator = math.sqrt(
            sum((a - mean_x) ** 2 for a in x)
            * sum((b - mean_y) ** 2 for b in y)
        )
        return numerator / denominator if denominator > 0 else 0

    return {
        "alignment": "100 bins by follower-local phase",
        "powerNormalization": "each grid divided by its matched isolated follower mean-positive-power scalar",
        "normalizedPowerResidual": metrics(residuals["power"]),
        "liftCoefficientResidual": metrics(residuals["lift"]),
        "dragCoefficientResidual": metrics(residuals["drag"]),
        "absoluteResidualCorrelations": {
            "powerVsLift": correlation(residuals["power"], residuals["lift"]),
            "powerVsDrag": correlation(residuals["power"], residuals["drag"]),
        },
    }


def main() -> int:
    preregistration = load(PREREGISTRATION)
    locked = {entry["path"]: entry["sha256"] for entry in preregistration["lockedInputs"]}
    for path in (C16_MAXIMUM, C16_MINIMUM):
        relative = str(path.relative_to(ROOT))
        if locked.get(relative) != sha256(path):
            raise SystemExit(f"locked c16 input changed: {relative}")

    c16_maximum = validate_report(C16_MAXIMUM, 16, 0.25)
    c16_minimum = validate_report(C16_MINIMUM, 16, 0.75)
    expected_phases = preregistration["fieldCapture"]["followerLocalTargetPhases"]
    threshold = 0.05

    artifact = {
        "schemaVersion": 1,
        "preregistration": {
            "path": str(PREREGISTRATION.relative_to(ROOT)),
            "sha256": sha256(PREREGISTRATION),
            "preregisteredBeforeC20Execution": preregistration[
                "preregisteredBeforeC20Execution"
            ],
        },
        "thresholdsUnchanged": True,
        "continuationThreshold": threshold,
        "quantitativeFormationClaimAuthorized": False,
    }

    if not C20_MAXIMUM.exists():
        artifact["status"] = "stage1_pending"
    else:
        c20_maximum = validate_report(C20_MAXIMUM, 20, 0.25)
        c16_saving = c16_maximum["followerPositivePowerSavingFraction"]
        c20_saving = c20_maximum["followerPositivePowerSavingFraction"]
        relative_change = abs(c20_saving - c16_saving) / max(
            abs(c20_saving), 1e-12
        )
        stage1_passed = c20_maximum["gates"]["passed"] and relative_change <= threshold
        artifact["stage1"] = {
            "selector": "maximum",
            "c16SavingFraction": c16_saving,
            "c20SavingFraction": c20_saving,
            "absoluteSavingPointChange": abs(c20_saving - c16_saving),
            "relativeFinePairChange": relative_change,
            "gates": gate_summary(c20_maximum),
            "flowCapture": validate_capture_archive(C20_MAXIMUM, expected_phases),
            "phaseResolvedFinePair": phase_residual_diagnostics(
                c16_maximum, c20_maximum
            ),
            "passed": stage1_passed,
            "reportPath": str(C20_MAXIMUM.relative_to(ROOT)),
            "reportSHA256": sha256(C20_MAXIMUM),
        }
        if not stage1_passed:
            artifact["status"] = "stage1_failed_stop"
            artifact["nextAction"] = (
                "retain the negative convergence result; do not execute the c20 minimum selector"
            )
        elif not C20_MINIMUM.exists():
            artifact["status"] = "stage1_passed_stage2_required"
            artifact["nextAction"] = "execute the preregistered c20 minimum selector"
        else:
            c20_minimum = validate_report(C20_MINIMUM, 20, 0.75)
            contrast16 = c16_saving - c16_minimum[
                "followerPositivePowerSavingFraction"
            ]
            contrast20 = c20_saving - c20_minimum[
                "followerPositivePowerSavingFraction"
            ]
            contrast_change = abs(contrast20 - contrast16) / max(
                abs(contrast20), 1e-12
            )
            stage2_passed = (
                c20_minimum["gates"]["passed"]
                and contrast_change <= threshold
            )
            artifact["stage2"] = {
                "selector": "minimum",
                "c16ContrastFraction": contrast16,
                "c20ContrastFraction": contrast20,
                "relativeFinePairContrastChange": contrast_change,
                "gates": gate_summary(c20_minimum),
                "flowCapture": validate_capture_archive(
                    C20_MINIMUM, expected_phases
                ),
                "passed": stage2_passed,
                "reportPath": str(C20_MINIMUM.relative_to(ROOT)),
                "reportSHA256": sha256(C20_MINIMUM),
            }
            artifact["quantitativeFormationClaimAuthorized"] = (
                stage1_passed and stage2_passed
            )
            artifact["status"] = (
                "both_stages_passed"
                if artifact["quantitativeFormationClaimAuthorized"]
                else "stage2_failed"
            )
            artifact["nextAction"] = (
                "formation-effect grid criterion cleared"
                if artifact["quantitativeFormationClaimAuthorized"]
                else "retain the negative convergence result"
            )

    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

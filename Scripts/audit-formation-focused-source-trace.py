#!/usr/bin/env python3
"""Independent audit of the preregistered focused boundary-source trace."""

from __future__ import annotations

import csv
import hashlib
import json
import math
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
PREREG = ROOT / "ValidationInputs/formation-flight-focused-source-trace-v1.json"
ARCHIVE = ROOT / "ValidationArtifacts/formation-flight-focused-source-trace"
REPORT = ARCHIVE / "formation-flight-focused-source-trace-report.json"
CLI_REPORT = ARCHIVE / "formation-flight-focused-source-trace-cli.json"
SUMMARY = ARCHIVE / "formation-flight-focused-source-trace-summary.json"
CSV_PATH = ARCHIVE / "formation-flight-focused-source-trace.csv"
AUDIT = ARCHIVE / "formation-flight-focused-source-trace-audit.json"
SELECTOR = ROOT / "ValidationArtifacts/formation-flight-source-residual-covariance/formation-flight-source-residual-covariance-summary.json"


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def finite_tree(value) -> bool:
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return True
    if isinstance(value, int):
        return True
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, list):
        return all(finite_tree(item) for item in value)
    if isinstance(value, dict):
        return all(finite_tree(item) for item in value.values())
    return False


checks: list[dict] = []


def check(name: str, passed: bool, evidence) -> None:
    checks.append({"name": name, "passed": bool(passed), "evidence": evidence})


prereg = load(PREREG)
report = load(REPORT)
cli_report = load(CLI_REPORT)
summary = load(SUMMARY)
selector = load(SELECTOR)
reference_path = ROOT / prereg["lockedReference"]["path"]
reference = load(reference_path)

check(
    "registered before temporal trace",
    prereg["registeredBeforeTemporalTrace"] is True,
    prereg["registeredAtUTC"],
)
for group in ("lockedInputs", "lockedImplementation", "lockedAnalysis"):
    for item in prereg[group]:
        actual = digest(ROOT / item["path"])
        check(f"{group} hash {item['path']}", actual == item["sha256"], actual)

check(
    "locked reference hash",
    digest(reference_path) == prereg["lockedReference"]["sha256"],
    digest(reference_path),
)
selected = selector["selectedTrace"]
for field in ("owner", "component", "directionIndex", "direction", "subcellOffsetCells"):
    check(
        f"selector preserves {field}",
        selected[field] == prereg["lockedSelection"][field],
        selected[field],
    )
check(
    "selector authorized one stable trace",
    selector["classification"] == "concentratedStableTraceSelected"
    and selected["positiveAlignmentShare"]
        >= prereg["selectorEvidence"]["minimumPositiveAlignmentShare"]
    and selected["signAgreementCount"]
        >= prereg["selectorEvidence"]["minimumSignAgreementCount"],
    {
        "classification": selector["classification"],
        "share": selected["positiveAlignmentShare"],
        "agreement": selected["signAgreementCount"],
    },
)

check("CLI and archived reports agree", cli_report == report, digest(CLI_REPORT))
check("report is finite", finite_tree(report), report["runtimeSeconds"])
check("report schema", report["schemaVersion"] == 1, report["schemaVersion"])
check(
    "reference identity",
    report["referenceReportSHA256"] == digest(reference_path),
    report["referenceReportSHA256"],
)
check(
    "configuration identity",
    report["configuration"] == prereg["lockedConfiguration"],
    report["configuration"],
)
check(
    "subcell identity",
    report["subcellOffsetCells"]
        == prereg["lockedSelection"]["subcellOffsetCells"],
    report["subcellOffsetCells"],
)
check(
    "owner direction identity",
    report["flyer"] == prereg["lockedSelection"]["owner"]
    and report["directionIndex"] == prereg["lockedSelection"]["directionIndex"]
    and report["direction"] == prereg["lockedSelection"]["direction"],
    {
        "flyer": report["flyer"],
        "directionIndex": report["directionIndex"],
        "direction": report["direction"],
    },
)
check(
    "grid identity",
    [report["gridX"], report["gridY"], report["gridZ"]]
        == prereg["lockedGrid"]["dimensions"]
    and report["cycleSteps"] == prereg["lockedGrid"]["cycleSteps"],
    [report["gridX"], report["gridY"], report["gridZ"], report["cycleSteps"]],
)

samples = report["samples"]
cycle_steps = report["cycleSteps"]
first_absolute = (report["configuration"]["cycles"] - 1) * cycle_steps + 1
check("exact final-cycle sample count", len(samples) == cycle_steps, len(samples))
check(
    "step sequence complete",
    [row["stepWithinCycle"] for row in samples] == list(range(1, cycle_steps + 1)),
    [samples[0]["stepWithinCycle"], samples[-1]["stepWithinCycle"]],
)
check(
    "absolute-step sequence complete",
    [row["absoluteStep"] for row in samples]
        == list(range(first_absolute, first_absolute + cycle_steps)),
    [samples[0]["absoluteStep"], samples[-1]["absoluteStep"]],
)
phase_errors = []
for row in samples:
    expected = (
        0.0 if row["stepWithinCycle"] == cycle_steps
        else row["stepWithinCycle"] / cycle_steps
    )
    phase_errors.append(abs(row["leaderPhase"] - expected))
check("phase timing exact", max(phase_errors) <= 1e-15, max(phase_errors))
check(
    "every record preserves q5",
    all(
        row["source"]["directionIndex"] == report["directionIndex"]
        and row["source"]["direction"] == report["direction"]
        for row in samples
    ),
    len(samples),
)

absolute_closure = []
relative_closure = []
branch_closure = []
for row in samples:
    source = row["source"]
    reconstructed = (
        source["reflectedIncomingPopulationSum"]
        + source["interpolationAuxiliaryPopulationSum"]
        + source["movingWallPopulationSum"]
    )
    difference = source["reconstructedIncomingPopulationSum"] - reconstructed
    absolute_closure.append(abs(difference))
    relative_closure.append(
        abs(difference) / max(abs(source["reconstructedIncomingPopulationSum"]), 1e-12)
    )
    branch_closure.append(
        source["linkCount"]
        == source["nearInterpolationLinkCount"]
            + source["farInterpolationLinkCount"]
            + source["halfwayFallbackLinkCount"]
    )
max_relative_closure = max(relative_closure)
check(
    "independent reconstruction closure",
    max_relative_closure
        <= prereg["gates"]["maximumRelativeReconstructionClosureResidual"],
    max_relative_closure,
)
check("independent branch-count closure", all(branch_closure), sum(branch_closure))
check(
    "stored reconstruction closure agrees",
    abs(
        max_relative_closure
        - report["gates"]["maximumRelativeReconstructionClosureResidual"]
    ) <= 1e-15,
    max_relative_closure,
)


def summary_values(item: dict) -> np.ndarray:
    return np.asarray([
        item["meanSignedPowerWatts"],
        item["meanPositivePowerWatts"],
        item["rmsPowerWatts"],
        item["maximumPositivePowerWatts"],
        item["meanLiftCoefficient"],
        item["meanDragCoefficient"],
    ])


def relative_rms(lhs: np.ndarray, rhs: np.ndarray) -> float:
    return float(
        np.sqrt(np.mean((lhs - rhs) ** 2))
        / max(float(np.sqrt(np.mean(rhs**2))), 1e-12)
    )


load_difference = max(
    relative_rms(summary_values(report["coupledLeader"]), summary_values(reference["coupledLeader"])),
    relative_rms(summary_values(report["coupledFollower"]), summary_values(reference["coupledFollower"])),
)
check(
    "independent load non-intrusion",
    load_difference <= prereg["gates"]["maximumRelativeReferenceDifference"],
    load_difference,
)
check(
    "stored load non-intrusion agrees",
    abs(load_difference - report["gates"]["relativeReferenceLoadSummaryDifference"])
        <= 1e-15,
    report["gates"]["relativeReferenceLoadSummaryDifference"],
)

reference_flyer = next(
    row for row in reference["boundarySourceCensus"]["samples"]
    if row["flyer"] == report["flyer"]
)
reference_source = next(
    row for row in reference_flyer["directions"]
    if row["directionIndex"] == report["directionIndex"]
)
anchor_index = min(
    range(len(samples)),
    key=lambda index: min(
        abs(samples[index]["leaderPhase"] - reference_flyer["leaderPhase"]),
        1 - abs(samples[index]["leaderPhase"] - reference_flyer["leaderPhase"]),
    ),
)
anchor_source = samples[anchor_index]["source"]
numeric_fields = [
    "rawReflectedPopulationSum",
    "reflectedIncomingPopulationSum",
    "interpolationAuxiliaryPopulationSum",
    "movingWallPopulationSum",
    "reconstructedIncomingPopulationSum",
    "absoluteIncomingPopulationSum",
    "squaredIncomingPopulationSum",
    "linkFractionSum",
    "squaredLinkFractionSum",
    "wallProjectionSum",
    "absoluteWallProjectionSum",
    "wallSpeedSum",
]
scale = max(max(abs(reference_source[field]) for field in numeric_fields), 1e-12)
anchor_difference = max(
    abs(anchor_source[field] - reference_source[field]) for field in numeric_fields
) / scale
count_fields = [
    "linkCount",
    "nearInterpolationLinkCount",
    "farInterpolationLinkCount",
    "halfwayFallbackLinkCount",
]
anchor_counts_equal = all(
    anchor_source[field] == reference_source[field] for field in count_fields
)
check(
    "independent anchor source reproduction",
    anchor_difference <= prereg["gates"]["maximumRelativeReferenceDifference"],
    anchor_difference,
)
check("independent anchor branch reproduction", anchor_counts_equal, anchor_source)
check(
    "stored anchor difference agrees",
    abs(
        anchor_difference
        - report["gates"]["maximumRelativeReferenceAnchorSourceDifference"]
    ) <= 1e-15,
    report["gates"]["maximumRelativeReferenceAnchorSourceDifference"],
)

gate_names = [
    "finite",
    "noGeometryOverlap",
    "ownerForceClosurePassed",
    "ownerTorqueClosurePassed",
    "periodicPowerPassed",
    "finalCycleCompletenessPassed",
    "selectionIdentityPassed",
    "reconstructionClosurePassed",
    "branchCountClosurePassed",
    "referenceLoadNonIntrusionPassed",
    "referenceAnchorReproductionPassed",
    "referenceAnchorBranchCountPassed",
]
for name in gate_names:
    check(f"report gate {name}", report["gates"][name] is True, report["gates"][name])
check("overall report gate", report["gates"]["passed"] is True, report["scientificVerdict"])

check(
    "summary binds trace report",
    summary["integrity"]["traceReportSHA256"] == digest(REPORT),
    summary["integrity"]["traceReportSHA256"],
)
check(
    "summary preserves selection",
    summary["selection"]["flyer"] == prereg["lockedSelection"]["owner"]
    and summary["selection"]["component"] == prereg["lockedSelection"]["component"]
    and summary["selection"]["directionIndex"]
        == prereg["lockedSelection"]["directionIndex"],
    summary["selection"],
)
classification = summary["classification"]
check(
    "classification is preregistered",
    classification in prereg["decisionRule"]["nextActions"],
    classification,
)
window = summary["temporalLocalization"]["centeredEnergyWindow"]
localized = window["widthCycles"] <= prereg["decisionRule"][
    "maximumLocalizedWindowWidthCycles"
]
associated = summary["branchAssociation"]["maximumAbsoluteNearOrFarAssociation"] >= prereg[
    "decisionRule"
]["minimumAbsoluteBranchAssociation"]
expected_classification = (
    "temporallyLocalizedBranchAssociated" if localized and associated
    else "temporallyLocalizedMixedBranches" if localized
    else "cycleDistributedBranchAssociated" if associated
    else "cycleDistributedMixedBranches"
)
check(
    "classification independently follows rule",
    classification == expected_classification,
    expected_classification,
)
with CSV_PATH.open(newline="") as handle:
    csv_rows = list(csv.reader(handle))
check("CSV contains one header plus every step", len(csv_rows) == cycle_steps + 1, len(csv_rows))
for figure in ("Docs/Media/formation-flight-focused-source-trace.png", "Docs/Media/formation-flight-focused-source-trace.svg"):
    path = ROOT / figure
    check(f"figure exists {figure}", path.exists() and path.stat().st_size > 1000, path.stat().st_size if path.exists() else 0)

passed = all(item["passed"] for item in checks)
audit = {
    "schemaVersion": 1,
    "title": "Formation focused boundary-source temporal trace audit",
    "checkCount": len(checks),
    "passedCheckCount": sum(item["passed"] for item in checks),
    "passed": passed,
    "checks": checks,
    "independentMetrics": {
        "maximumAbsoluteAdditiveClosure": max(absolute_closure),
        "maximumRelativeReconstructionClosureResidual": max_relative_closure,
        "relativeReferenceLoadSummaryDifference": load_difference,
        "maximumRelativeReferenceAnchorSourceDifference": anchor_difference,
        "anchorBranchCountsEqual": anchor_counts_equal,
    },
    "classification": classification,
    "claimBoundary": prereg["claimBoundary"],
}
AUDIT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
print(json.dumps({
    "passed": passed,
    "checks": f"{audit['passedCheckCount']}/{audit['checkCount']}",
    "classification": classification,
    "audit": str(AUDIT.relative_to(ROOT)),
}, indent=2, sort_keys=True))
if not passed:
    raise SystemExit(2)

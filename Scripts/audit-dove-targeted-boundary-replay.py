#!/usr/bin/env python3
"""Independently audit the targeted moving-boundary attribution artifact."""

from __future__ import annotations

import hashlib
import itertools
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-source-viscosity-targeted-boundary-preregistration.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-targeted-boundary-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-targeted-boundary-d32.json"
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-targeted-boundary.json"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-targeted-boundary-audit.json"
)

COMPONENTS = {
    "reflectedPopulation": "reflectedPopulationMeanForceNewtons",
    "movingWall": "movingWallMeanForceNewtons",
    "interpolationResidual": "interpolationResidualMeanForceNewtons",
    "topologyImpulse": "topologyImpulseMeanForceNewtons",
}


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def xz(vector: list[float]) -> tuple[float, float]:
    return float(vector[0]), float(vector[2])


def close(left: float, right: float, tolerance: float = 1.0e-10) -> bool:
    return abs(left - right) <= tolerance * max(abs(left), abs(right), 1.0)


def main() -> None:
    prereg = load(PREREGISTRATION)
    d28 = load(D28)
    d32 = load(D32)
    report = load(REPORT)
    bins28 = d28["componentBins"]
    bins32 = d32["componentBins"]

    deltas: dict[str, list[tuple[float, float]]] = {}
    for name, key in COMPONENTS.items():
        deltas[name] = [
            (
                xz(right[key])[0] - xz(left[key])[0],
                xz(right[key])[1] - xz(left[key])[1],
            )
            for left, right in zip(bins28, bins32)
        ]
    production = [
        (
            xz(right["productionMeanForceNewtons"])[0]
            - xz(left["productionMeanForceNewtons"])[0],
            xz(right["productionMeanForceNewtons"])[1]
            - xz(left["productionMeanForceNewtons"])[1],
        )
        for left, right in zip(bins28, bins32)
    ]

    def dot(left: tuple[float, float], right: tuple[float, float]) -> float:
        return left[0] * right[0] + left[1] * right[1]

    def make_ledger(indices: range) -> list[tuple[str, str, float]]:
        result = []
        for name, values in deltas.items():
            result.append(
                (name, "self", sum(dot(values[i], values[i]) for i in indices))
            )
        for first, second in itertools.combinations(deltas, 2):
            result.append(
                (
                    f"{first} x {second}",
                    "interaction",
                    2.0
                    * sum(dot(deltas[first][i], deltas[second][i]) for i in indices),
                )
            )
        result.sort(key=lambda item: abs(item[2]), reverse=True)
        return result

    full = make_ledger(range(len(bins28)))
    split = len(bins28) // 2
    early = make_ledger(range(split))
    late = make_ledger(range(split, len(bins28)))
    signed_total = sum(item[2] for item in full)
    absolute_total = sum(abs(item[2]) for item in full)
    production_energy = sum(dot(value, value) for value in production)
    reconstructed = [
        (
            sum(values[i][0] for values in deltas.values()),
            sum(values[i][1] for values in deltas.values()),
        )
        for i in range(len(bins28))
    ]
    residual_energy = sum(
        (reconstructed[i][0] - production[i][0]) ** 2
        + (reconstructed[i][1] - production[i][1]) ** 2
        for i in range(len(bins28))
    )
    reconstructed_energy = sum(dot(value, value) for value in reconstructed)
    relative_delta_closure = math.sqrt(
        residual_energy
        / max(production_energy, reconstructed_energy, 1.0e-30)
    )
    relative_energy_closure = abs(signed_total - production_energy) / max(
        production_energy, abs(signed_total), 1.0e-30
    )
    leading_fraction = abs(full[0][2]) / max(absolute_total, 1.0e-30)
    stable = full[0][0] == early[0][0] == late[0][0]
    dominant = (
        leading_fraction >= prereg["minimumDominantContributionFraction"]
        and stable
    )

    report_ledger = {
        item["name"]: item for item in report["contributionLedger"]
    }
    checks = {
        "sourceHashes": (
            report["preregistrationSHA256"] == sha256(PREREGISTRATION)
            and report["sourceD28CaseSHA256"] == sha256(D28)
            and report["sourceD32CaseSHA256"] == sha256(D32)
        ),
        "caseGates": d28["targetedCasePassed"] and d32["targetedCasePassed"],
        "caseComponentClosure": (
            d28["componentReconstructionRelativeRMS"]
            <= prereg["maximumComponentReconstructionRelativeRMS"]
            and d32["componentReconstructionRelativeRMS"]
            <= prereg["maximumComponentReconstructionRelativeRMS"]
        ),
        "archivedReproduction": (
            d28["archivedForceReproductionRelativeRMS"]
            <= prereg["maximumArchivedForceReproductionRelativeRMS"]
            and d32["archivedForceReproductionRelativeRMS"]
            <= prereg["maximumArchivedForceReproductionRelativeRMS"]
        ),
        "targetInterval": (
            report["targetSampleIndices"]
            == list(
                range(
                    prereg["firstTargetSampleIndex"],
                    prereg["lastTargetSampleIndex"] + 1,
                )
            )
            and report["targetTimesSeconds"][0]
            == prereg["targetStartTimeSeconds"]
            and report["targetTimesSeconds"][-1]
            == prereg["targetEndTimeSeconds"]
        ),
        "alignedBins": len(bins28) == len(bins32) == 11
        and all(
            left["targetSampleIndex"] == right["targetSampleIndex"]
            for left, right in zip(bins28, bins32)
        ),
        "componentDeltaClosure": close(
            relative_delta_closure,
            report["componentDifferenceClosureRelativeRMS"],
        )
        and relative_delta_closure
        <= prereg["maximumComponentReconstructionRelativeRMS"],
        "energyClosure": (
            close(signed_total, report["signedLedgerTotal"])
            and close(production_energy, report["squaredDifferenceEnergy"])
            and close(
                relative_energy_closure,
                report["squaredDifferenceEnergyClosureRelativeError"],
            )
            and relative_energy_closure
            <= prereg["maximumComponentReconstructionRelativeRMS"]
        ),
        "absoluteLedger": close(
            absolute_total, report["absoluteLedgerTotal"]
        ),
        "ledgerEntries": len(full) == len(report_ledger) == 10
        and all(
            name in report_ledger
            and report_ledger[name]["kind"] == kind
            and close(
                value,
                report_ledger[name]["signedSquaredDifferenceContribution"],
            )
            for name, kind, value in full
        ),
        "leadingContribution": (
            report["attribution"]["leadingContributionName"] == full[0][0]
            and report["attribution"]["leadingContributionKind"] == full[0][1]
            and close(
                report["attribution"]["leadingAbsoluteLedgerFraction"],
                leading_fraction,
            )
        ),
        "temporalHalves": (
            report["attribution"]["earlyLeader"] == early[0][0]
            and report["attribution"]["lateLeader"] == late[0][0]
            and report["attribution"]["sameLeaderInBothTemporalHalves"]
            == stable
        ),
        "frozenDominanceRule": (
            report["attribution"]["dominantContributionAvailable"] == dominant
            and report["attribution"]["minimumDominantContributionFraction"]
            == prereg["minimumDominantContributionFraction"]
        ),
        "classification": report["attribution"]["classification"]
        == (
            f"dominant-{full[0][1]}:{full[0][0]}"
            if dominant
            else "mixed-component-interaction"
        ),
        "claimBoundary": (
            not report["productionModificationAuthorized"]
            and not report["experimentalAgreementGateApplied"]
            and not report["gridConvergenceGateApplied"]
            and report["claimBoundary"] == prereg["claimBoundary"]
        ),
    }
    all_passed = all(checks.values())
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": (
            "deetjen-ob-f03-source-viscosity-targeted-boundary-audit-v1"
        ),
        "generatedBy": "Scripts/audit-dove-targeted-boundary-replay.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "d28CaseSHA256": sha256(D28),
        "d32CaseSHA256": sha256(D32),
        "reportSHA256": sha256(REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": all_passed,
        "independentReconstruction": {
            "productionSquaredDifferenceEnergy": production_energy,
            "signedLedgerTotal": signed_total,
            "absoluteLedgerTotal": absolute_total,
            "componentDifferenceClosureRelativeRMS": relative_delta_closure,
            "squaredDifferenceEnergyClosureRelativeError":
                relative_energy_closure,
            "leadingContributionName": full[0][0],
            "leadingContributionKind": full[0][1],
            "leadingAbsoluteLedgerFraction": leading_fraction,
            "earlyLeader": early[0][0],
            "lateLeader": late[0][0],
            "dominantContributionAvailable": dominant,
        },
        "productionModificationAuthorized": False,
        "claimBoundary": (
            "This independent audit reconstructs the X/Z component difference, "
            "ten-term signed energy ledger, and temporal dominance rule from the "
            "two targeted case artifacts. It does not establish convergence, "
            "experimental agreement, or authority to modify production physics."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not all_passed:
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("targeted boundary audit failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

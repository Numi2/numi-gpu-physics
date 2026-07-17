#!/usr/bin/env python3
"""Independently audit the reflected population/composition attribution."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-preregistration.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
REPORT = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance.json"
V1_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-"
    "preregistration-v1-insufficient-coverage.json"
)
V1_D28 = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-"
    "d28-v1-insufficient-coverage.json"
)
OUTPUT = ARTIFACTS / (
    "deetjen-dove-source-viscosity-reflected-provenance-audit.json"
)


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def close(left: float, right: float, tolerance: float = 1.0e-10) -> bool:
    return abs(left - right) <= tolerance * max(abs(left), abs(right), 1.0)


def stratum_key(item: dict) -> tuple:
    return (
        item["partIdentifier"],
        item["directionIndex"],
        item["branch"],
        item["topologyClass"],
        item["linkFractionBin"],
    )


def xz(vector: list[float]) -> tuple[float, float]:
    return float(vector[0]), float(vector[2])


def main() -> None:
    prereg = load(PREREGISTRATION)
    d28 = load(D28)
    d32 = load(D32)
    report = load(REPORT)
    v1_prereg = load(V1_PREREGISTRATION)
    v1_d28 = load(V1_D28)
    endpoints28 = d28["endpoints"]
    endpoints32 = d32["endpoints"]

    population = []
    composition = []
    reconstructed = []
    raw = []
    for endpoint28, endpoint32 in zip(endpoints28, endpoints32):
        left = {stratum_key(item): item for item in endpoint28["strata"]}
        right = {stratum_key(item): item for item in endpoint32["strata"]}
        pop_x = []
        pop_z = []
        comp_x = []
        comp_z = []
        for item_key in sorted(set(left) | set(right)):
            a = left.get(item_key)
            b = right.get(item_key)
            m28 = float(a["reflectedPopulationMean"]) if a else 0.0
            m32 = float(b["reflectedPopulationMean"]) if b else 0.0
            k28 = xz(a["coefficientVectorNewtonsPerPopulation"]) if a else (0.0, 0.0)
            k32 = xz(b["coefficientVectorNewtonsPerPopulation"]) if b else (0.0, 0.0)
            pop_x.append(0.5 * (k32[0] + k28[0]) * (m32 - m28))
            pop_z.append(0.5 * (k32[1] + k28[1]) * (m32 - m28))
            comp_x.append(0.5 * (m32 + m28) * (k32[0] - k28[0]))
            comp_z.append(0.5 * (m32 + m28) * (k32[1] - k28[1]))
        pop_value = (math.fsum(pop_x), math.fsum(pop_z))
        comp_value = (math.fsum(comp_x), math.fsum(comp_z))
        population.append(pop_value)
        composition.append(comp_value)
        reconstructed.append(
            (pop_value[0] + comp_value[0], pop_value[1] + comp_value[1])
        )
        selected28 = xz(endpoint28["selectedReflectedForceNewtons"])
        selected32 = xz(endpoint32["selectedReflectedForceNewtons"])
        raw.append(
            (selected32[0] - selected28[0], selected32[1] - selected28[1])
        )

    def dot(left: tuple[float, float], right: tuple[float, float]) -> float:
        return left[0] * right[0] + left[1] * right[1]

    def make_ledger(indices: range) -> list[tuple[str, str, float]]:
        result = [
            (
                "populationHistory",
                "self",
                math.fsum(dot(population[i], population[i]) for i in indices),
            ),
            (
                "linkComposition",
                "self",
                math.fsum(dot(composition[i], composition[i]) for i in indices),
            ),
            (
                "populationHistory x linkComposition",
                "interaction",
                2.0
                * math.fsum(
                    dot(population[i], composition[i]) for i in indices
                ),
            ),
        ]
        result.sort(key=lambda item: abs(item[2]), reverse=True)
        return result

    full = make_ledger(range(len(population)))
    split = len(population) // 2
    early = make_ledger(range(split))
    late = make_ledger(range(split, len(population)))
    signed_total = math.fsum(item[2] for item in full)
    absolute_total = math.fsum(abs(item[2]) for item in full)
    difference_energy = math.fsum(dot(item, item) for item in reconstructed)
    energy_closure = abs(signed_total - difference_energy) / max(
        abs(signed_total), difference_energy, 1.0e-30
    )
    raw_residual_energy = math.fsum(
        (model[0] - measured[0]) ** 2 + (model[1] - measured[1]) ** 2
        for model, measured in zip(reconstructed, raw)
    )
    raw_energy = math.fsum(dot(item, item) for item in raw)
    raw_consistency = math.sqrt(raw_residual_energy / max(raw_energy, 1.0e-30))
    leading_fraction = abs(full[0][2]) / max(absolute_total, 1.0e-30)
    stable = full[0][0] == early[0][0] == late[0][0]
    dominant = (
        full[0][1] == "self"
        and leading_fraction >= prereg["minimumDominantContributionFraction"]
        and stable
    )
    if dominant and full[0][0] == "populationHistory":
        classification = "dominant-population-history"
    elif dominant and full[0][0] == "linkComposition":
        classification = "dominant-near-wall-link-composition"
    else:
        classification = "mixed-population-composition"
    report_ledger = {
        item["name"]: item for item in report["contributionLedger"]
    }

    checks = {
        "sourceHashes": (
            report["preregistrationSHA256"] == sha256(PREREGISTRATION)
            and report["sourceD28CaseSHA256"] == sha256(D28)
            and report["sourceD32CaseSHA256"] == sha256(D32)
        ),
        "preservedV1Evidence": (
            prereg["sourceV1PreregistrationSHA256"]
            == sha256(V1_PREREGISTRATION)
            and prereg["sourceV1D28CaseSHA256"] == sha256(V1_D28)
            and v1_prereg["schemaVersion"] == 1
            and not v1_d28["selectionCoveragePassed"]
            and v1_d28["numericalLedgerPassed"]
            and v1_d28["sourceReflectedForceReproductionPassed"]
            and v1_d28["candidateDetailPassed"]
        ),
        "caseGates": d28["provenanceCasePassed"] and d32["provenanceCasePassed"],
        "numericalLedgers": d28["numericalLedgerPassed"] and d32["numericalLedgerPassed"],
        "selectionCoverage": (
            d28["selectionCoveragePassed"]
            and d32["selectionCoveragePassed"]
            and d28["minimumSelectedAbsoluteScoreCoverage"]
            >= prereg["minimumSelectedAbsoluteScoreCoverage"]
            and d32["minimumSelectedAbsoluteScoreCoverage"]
            >= prereg["minimumSelectedAbsoluteScoreCoverage"]
        ),
        "sourceForceReproduction": (
            d28["sourceReflectedForceReproductionPassed"]
            and d32["sourceReflectedForceReproductionPassed"]
            and d28["sourceReflectedForceReproductionRelativeRMS"]
            <= prereg["maximumSourceReflectedForceReproductionRelativeRMS"]
            and d32["sourceReflectedForceReproductionRelativeRMS"]
            <= prereg["maximumSourceReflectedForceReproductionRelativeRMS"]
        ),
        "detailIdentityAndCapacity": (
            d28["candidateDetailPassed"]
            and d32["candidateDetailPassed"]
            and d28["candidateDetailMismatchCount"] == 0
            and d32["candidateDetailMismatchCount"] == 0
            and d28["candidateOverflowCount"] == 0
            and d32["candidateOverflowCount"] == 0
        ),
        "alignedEndpoints": (
            len(endpoints28) == len(endpoints32) == 11
            and report["targetSampleIndices"] == list(range(50, 61))
            and all(
                left["targetSampleIndex"] == right["targetSampleIndex"]
                and left["sourceTimeSeconds"] == right["sourceTimeSeconds"]
                for left, right in zip(endpoints28, endpoints32)
            )
        ),
        "populationCompositionClosure": (
            report["populationCompositionClosurePassed"]
            and report["populationCompositionClosureRelativeRMS"]
            <= prereg["maximumPopulationCompositionClosureRelativeRMS"]
        ),
        "rawFloatForceConsistency": (
            raw_consistency <= 1.0e-6
            and close(
                raw_consistency,
                report["rawFloatForceConsistencyRelativeRMS"],
                tolerance=1.0e-8,
            )
        ),
        "energyClosure": (
            energy_closure
            <= prereg["maximumPopulationCompositionClosureRelativeRMS"]
            and close(signed_total, report["signedLedgerTotal"])
            and close(difference_energy, report["squaredDifferenceEnergy"])
        ),
        "threeTermLedger": len(full) == len(report_ledger) == 3
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
            and report["attribution"]["sameLeaderInBothTemporalHalves"] == stable
        ),
        "frozenDominanceRule": (
            report["attribution"]["dominantContributionAvailable"] == dominant
            and report["attribution"]["classification"] == classification
            and report["attribution"]["minimumDominantContributionFraction"]
            == prereg["minimumDominantContributionFraction"]
        ),
        "claimBoundary": (
            report["bothProvenanceCasesPassed"]
            and not report["productionModificationAuthorized"]
            and not report["experimentalAgreementGateApplied"]
            and not report["gridConvergenceGateApplied"]
            and report["claimBoundary"] == prereg["claimBoundary"]
        ),
    }
    all_passed = all(checks.values())
    artifact = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-reflected-population-provenance-audit-v1",
        "generatedBy": "Scripts/audit-dove-reflected-population-provenance.py",
        "preregistrationSHA256": sha256(PREREGISTRATION),
        "d28CaseSHA256": sha256(D28),
        "d32CaseSHA256": sha256(D32),
        "reportSHA256": sha256(REPORT),
        "checkCount": len(checks),
        "checks": checks,
        "allChecksPassed": all_passed,
        "independentReconstruction": {
            "squaredDifferenceEnergy": difference_energy,
            "signedLedgerTotal": signed_total,
            "absoluteLedgerTotal": absolute_total,
            "squaredDifferenceEnergyClosureRelativeError": energy_closure,
            "rawFloatForceConsistencyRelativeRMS": raw_consistency,
            "leadingContributionName": full[0][0],
            "leadingContributionKind": full[0][1],
            "leadingAbsoluteLedgerFraction": leading_fraction,
            "earlyLeader": early[0][0],
            "lateLeader": late[0][0],
            "dominantContributionAvailable": dominant,
        },
        "productionModificationAuthorized": False,
        "claimBoundary": (
            "This independent audit reconstructs the selected X/Z population/"
            "composition split, three-term signed energy ledger, temporal "
            "dominance rule, preserved V1 negative control, and raw float-force "
            "consistency. It does not establish whole-boundary causality, grid "
            "convergence, experimental agreement, or production authority."
        ),
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))
    if not all_passed:
        failed = [name for name, passed in checks.items() if not passed]
        raise SystemExit("reflected provenance audit failed: " + ", ".join(failed))


if __name__ == "__main__":
    main()

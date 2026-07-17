#!/usr/bin/env python3
"""Independent reconstruction of the D28/D32 25--30 ms direction window."""

from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
A = ROOT / "ValidationArtifacts"
V1_PREREG = A / "deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json"
V1_FAILURE = A / "deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json"
PREREG = A / "deetjen-dove-fine-direction-phase-window-preregistration.json"
CENSUS = A / "deetjen-dove-fine-direction-phase-window-census.json"
REPORT = A / "deetjen-dove-fine-direction-phase-window-discriminator.json"
OUTPUT = A / "deetjen-dove-fine-direction-phase-window-audit.json"

VECTORS = [
    (0, 0, 0), (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0),
    (0, 0, 1), (0, 0, -1), (1, 1, 0), (-1, -1, 0),
    (1, -1, 0), (-1, 1, 0), (1, 0, 1), (-1, 0, -1),
    (1, 0, -1), (-1, 0, 1), (0, 1, 1), (0, -1, -1),
    (0, 1, -1), (0, -1, 1),
]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def length(vector: list[float]) -> float:
    return math.sqrt(math.fsum(value * value for value in vector))


def distribution(counts: list[int]) -> list[float]:
    total = sum(counts)
    return [value / total for value in counts]


def tv(first: list[float], second: list[float]) -> float:
    return math.fsum(abs(a - b) for a, b in zip(first, second)) / 2


def profile(counts: list[int], dx: float, populations: list[float]) -> tuple[list[float], float, float]:
    terms = [
        [
            2 * populations[q] * counts[q] * dx * dx * VECTORS[q][axis]
            for axis in range(3)
        ]
        for q in range(19)
    ]
    vector = [math.fsum(term[axis] for term in terms) for axis in range(3)]
    ledger = math.fsum(length(term) for term in terms)
    return vector, ledger, length(vector) / max(ledger, 1e-300)


def delta(first: tuple, second: tuple) -> float:
    vector = [b - a for a, b in zip(first[0], second[0])]
    return length(vector) / max((first[1] + second[1]) / 2, 1e-300)


def main() -> None:
    v1_prereg = json.loads(V1_PREREG.read_text())
    raw = json.loads(V1_FAILURE.read_text())
    prereg = json.loads(PREREG.read_text())
    census = json.loads(CENSUS.read_text())
    report = json.loads(REPORT.read_text())
    checks: dict[str, bool] = {}
    checks["retainedV1SourceIdentities"] = (
        raw["sourcePreregistrationSHA256"] == digest(V1_PREREG)
        and prereg["sourceV1PreregistrationSHA256"] == digest(V1_PREREG)
        and prereg["sourceV1ExactParityFailureSHA256"] == digest(V1_FAILURE)
    )
    checks["retainedV1Failure"] = (
        raw["classification"] == "invalid-census-parity"
        and not raw["censusPassed"]
    )
    checks["v2FrozenCoverage"] = (
        prereg["schemaVersion"] == 2
        and prereg["arithmeticOnlyRevision"]
        and prereg["sourceSampleIndices"] == list(range(50, 61))
        and prereg["referenceLengthCells"] == [28, 32]
        and len(prereg["productionActiveLinkReferences"]) == 22
    )
    checks["qualifiedSourceIdentities"] = (
        census["sourcePreregistrationSHA256"] == digest(PREREG)
        and census["sourceV1ExactParityFailureSHA256"] == digest(V1_FAILURE)
        and report["sourcePreregistrationSHA256"] == digest(PREREG)
        and report["sourceCensusSHA256"] == digest(CENSUS)
    )

    raw_cases = {
        (item["sourceSampleIndex"], item["referenceLengthCells"]): item
        for item in raw["cases"]
    }
    qualified_cases = {
        (item["sourceSampleIndex"], item["referenceLengthCells"]): item
        for item in census["cases"]
    }
    checks["completeCaseCoverage"] = (
        len(raw_cases) == 22 and set(raw_cases) == set(qualified_cases)
    )
    tie_ok = True
    whole_parity = True
    component_parity = True
    production = True
    tie_count = 0
    for key, case in raw_cases.items():
        metal = {(b["partIdentifier"], b["directionIndex"]): b["linkCount"] for b in case["metalBins"]}
        cpu = {(b["partIdentifier"], b["directionIndex"]): b["linkCount"] for b in case["cpuBins"]}
        component_max = max(abs(metal[k] - cpu[k]) for k in metal)
        whole_max = max(
            abs(
                sum(metal[(part, q)] for part in range(1, 5))
                - sum(cpu[(part, q)] for part in range(1, 5))
            )
            for q in range(1, 19)
        )
        local_ties = case["maskMismatches"]
        tie_count += len(local_ties)
        local_ok = len(local_ties) <= prereg["maximumQualifiedTieCellsPerCase"]
        for item in local_ties:
            mp, cp = item["metalPartIdentifier"], item["cpuPartIdentifier"]
            md, cd = item["metalSignedDistanceCells"], item["cpuSignedDistanceCells"]
            if (mp == 0) != (cp == 0):
                local_ok &= max(abs(md), abs(cd)) <= prereg["solidFluidTieAbsoluteDistanceToleranceCells"]
            else:
                local_ok &= mp != 0 and cp != 0 and mp != cp
                local_ok &= abs(md - cd) <= prereg["componentOwnershipTieDistanceDifferenceToleranceCells"]
        tie_ok &= local_ok
        whole_parity &= whole_max == 0
        component_parity &= component_max <= 1
        production &= case["productionLinkSetConsistencyGatePassed"]
        qualified = qualified_cases[key]
        tie_ok &= qualified["arithmeticTieQualificationPassed"] == local_ok
        whole_parity &= qualified["maximumMetalCPUWholeDirectionCountMismatch"] == whole_max
    checks["independentTieQualification"] = tie_ok and tie_count == 4
    checks["independentWholeDirectionParity"] = whole_parity
    checks["independentComponentQualification"] = component_parity
    checks["productionLinkConsistency"] = production
    checks["qualifiedCensusDecision"] = census["censusPassed"] and census["qualifiedCaseCount"] == 22

    profiles = prereg["fixedPopulationProfiles"]
    phase_results = []
    max_values = [0.0, 0.0, 0.0, 0.0]
    max_opposite = 0
    max_equilibrium = 0.0
    all_phase_gates = True
    for sample in range(50, 61):
        reconstructed = {}
        for resolution in (28, 32):
            case = raw_cases[(sample, resolution)]
            mapping = {(b["partIdentifier"], b["directionIndex"]): b["linkCount"] for b in case["metalBins"]}
            components = {}
            whole = [0] * 19
            for part in range(1, 5):
                counts = [0] + [mapping[(part, q)] for q in range(1, 19)]
                whole = [a + b for a, b in zip(whole, counts)]
                components[part] = (
                    distribution(counts),
                    [profile(counts, case["cellSizeMeters"], p["directionPopulations"]) for p in profiles],
                )
            whole_profiles = [profile(whole, case["cellSizeMeters"], p["directionPopulations"]) for p in profiles]
            reconstructed[resolution] = {
                "whole": distribution(whole),
                "components": components,
                "profiles": whole_profiles,
                "opposite": max(abs(whole[a] - whole[b]) for a, b in prereg["oppositeDirectionPairs"]),
                "equilibrium": whole_profiles[0][2],
            }
        d28, d32 = reconstructed[28], reconstructed[32]
        values = [
            tv(d28["whole"], d32["whole"]),
            max(tv(d28["components"][p][0], d32["components"][p][0]) for p in range(1, 5)),
            max(delta(a, b) for a, b in zip(d28["profiles"], d32["profiles"])),
            max(
                delta(d28["components"][p][1][k], d32["components"][p][1][k])
                for p in range(1, 5) for k in range(len(profiles))
            ),
        ]
        max_values = [max(a, b) for a, b in zip(max_values, values)]
        max_opposite = max(max_opposite, d28["opposite"], d32["opposite"])
        max_equilibrium = max(max_equilibrium, d28["equilibrium"], d32["equilibrium"])
        archived = next(item for item in report["phaseSummaries"] if item["sourceSampleIndex"] == sample)
        phase_match = all(
            abs(a - b) <= 1e-15
            for a, b in zip(
                values,
                [
                    archived["wholeSurfaceDirectionHistogramTotalVariation"],
                    archived["maximumComponentDirectionHistogramTotalVariation"],
                    archived["maximumWholeSurfaceProfileResponseLedgerDifference"],
                    archived["maximumComponentProfileResponseLedgerDifference"],
                ],
            )
        )
        all_phase_gates &= archived["passed"] and phase_match
        phase_results.append({"sourceSampleIndex": sample, "metricsMatch": phase_match})
    checks["independentPhaseMetrics"] = all(item["metricsMatch"] for item in phase_results)
    checks["independentMaximumMetrics"] = all(
        abs(a - b) <= 1e-15
        for a, b in zip(
            max_values,
            [
                report["maximumWholeSurfaceDirectionHistogramTotalVariation"],
                report["maximumComponentDirectionHistogramTotalVariation"],
                report["maximumWholeSurfaceProfileResponseLedgerDifference"],
                report["maximumComponentProfileResponseLedgerDifference"],
            ],
        )
    )
    checks["oppositeAndEquilibriumClosure"] = (
        max_opposite == report["maximumWholeSurfaceOppositeDirectionCountMismatch"] == 0
        and abs(max_equilibrium - report["maximumEquilibriumWholeSurfaceNetLedgerFraction"]) <= 1e-15
    )
    checks["allElevenPhasesPass"] = all_phase_gates and report["passedPhaseCount"] == 11
    checks["aggregateGates"] = len(report["gates"]) == 8 and all(report["gates"].values())
    checks["classification"] = (
        report["analysisPassed"]
        and report["classification"] == "fine-direction-phase-window-cleared-at-d28-d32"
    )
    checks["captureIsolation"] = (
        not census["fluidEvolutionExecuted"]
        and not census["populationAllocationPerformed"]
        and not census["newPhysicsKernelExecuted"]
        and not census["newMetalExecutionPerformed"]
    )
    checks["claimBoundaryAndNoAuthorization"] = (
        "cannot validate moving-wall velocity" in report["claimBoundary"]
        and not report["productionModificationAuthorized"]
        and not report["d36RunAuthorized"]
    )
    all_passed = all(checks.values())
    audit = {
        "schemaVersion": 1,
        "auditIdentifier": "deetjen-ob-f03-fine-direction-phase-window-audit-v1",
        "generatedBy": "Scripts/audit-dove-fine-direction-phase-window.py",
        "preregistrationSHA256": digest(PREREG),
        "censusSHA256": digest(CENSUS),
        "reportSHA256": digest(REPORT),
        "retainedV1PreregistrationSHA256": digest(V1_PREREG),
        "retainedV1FailureSHA256": digest(V1_FAILURE),
        "checks": checks,
        "checkCount": len(checks),
        "allChecksPassed": all_passed,
        "classification": report["classification"],
        "independentMaximumMetrics": {
            "wholeDirectionHistogramTotalVariation": max_values[0],
            "componentDirectionHistogramTotalVariation": max_values[1],
            "wholeProfileResponseLedgerDifference": max_values[2],
            "componentProfileResponseLedgerDifference": max_values[3],
        },
        "fluidEvolutionExecuted": False,
        "productionModificationAuthorized": False,
        "claimBoundary": "Independent reconstruction of all 22 raw cases, four arithmetic ties, eleven D28/D32 phase pairs, eight gates, and the safety boundary; no force or convergence claim is made.",
    }
    OUTPUT.write_text(json.dumps(audit, indent=2, sort_keys=True) + "\n")
    print(json.dumps(audit, indent=2, sort_keys=True))
    if not all_passed:
        raise SystemExit("phase-window independent audit failed")


if __name__ == "__main__":
    main()

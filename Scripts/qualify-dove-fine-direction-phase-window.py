#!/usr/bin/env python3
"""Apply the preregistered V2 arithmetic-tie qualification to the V1 census."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
PREREG = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-preregistration.json"
V1_FAILURE = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json"
OUTPUT = ARTIFACTS / "deetjen-dove-fine-direction-phase-window-census.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def bins(case: dict, key: str) -> dict[tuple[int, int], int]:
    return {
        (item["partIdentifier"], item["directionIndex"]): item["linkCount"]
        for item in case[key]
    }


def main() -> None:
    prereg = json.loads(PREREG.read_text())
    source = json.loads(V1_FAILURE.read_text())
    if not (
        prereg["schemaVersion"] == 2
        and prereg["arithmeticOnlyRevision"]
        and prereg["sourceV1ExactParityFailureSHA256"] == sha256(V1_FAILURE)
        and source["classification"] == "invalid-census-parity"
        and len(source["cases"]) == 22
    ):
        raise SystemExit("frozen V2 contract and retained V1 failure required")

    qualified_cases = []
    for case in source["cases"]:
        metal = bins(case, "metalBins")
        cpu = bins(case, "cpuBins")
        component_maximum = max(abs(metal[key] - cpu[key]) for key in metal)
        whole_differences = {
            direction: sum(metal[(part, direction)] for part in range(1, 5))
            - sum(cpu[(part, direction)] for part in range(1, 5))
            for direction in range(1, 19)
        }
        whole_maximum = max(abs(value) for value in whole_differences.values())
        ties = []
        for mismatch in case["maskMismatches"]:
            metal_part = mismatch["metalPartIdentifier"]
            cpu_part = mismatch["cpuPartIdentifier"]
            metal_distance = mismatch["metalSignedDistanceCells"]
            cpu_distance = mismatch["cpuSignedDistanceCells"]
            if (metal_part == 0) != (cpu_part == 0):
                category = "solid-fluid-sign-tie"
                passed = max(abs(metal_distance), abs(cpu_distance)) <= prereg[
                    "solidFluidTieAbsoluteDistanceToleranceCells"
                ]
            else:
                category = "component-ownership-tie"
                passed = (
                    metal_part != 0
                    and cpu_part != 0
                    and metal_part != cpu_part
                    and abs(metal_distance - cpu_distance)
                    <= prereg[
                        "componentOwnershipTieDistanceDifferenceToleranceCells"
                    ]
                )
            ties.append({**mismatch, "category": category, "qualified": passed})

        tie_gate = (
            len(ties) <= prereg["maximumQualifiedTieCellsPerCase"]
            and all(item["qualified"] for item in ties)
        )
        whole_gate = (
            whole_maximum
            <= prereg["maximumMetalCPUWholeDirectionCountMismatch"]
        )
        component_gate = (
            component_maximum
            <= prereg["maximumMetalCPUPerDirectionCountMismatch"]
        )
        production_gate = case["productionLinkSetConsistencyGatePassed"]
        qualified = tie_gate and whole_gate and component_gate and production_gate
        qualified_cases.append(
            {
                **case,
                "qualifiedMaskMismatches": ties,
                "maximumMetalCPUWholeDirectionCountMismatch": whole_maximum,
                "wholeDirectionCountDifferences": whole_differences,
                "arithmeticTieQualificationPassed": tie_gate,
                "wholeDirectionParityPassed": whole_gate,
                "componentDirectionQualificationPassed": component_gate,
                "qualifiedParityGatePassed": qualified,
            }
        )

    passed = all(case["qualifiedParityGatePassed"] for case in qualified_cases)
    classification = (
        "fine-direction-phase-window-census-qualified"
        if passed
        else "unqualified-arithmetic-mismatch"
    )
    report = {
        "schemaVersion": 2,
        "censusIdentifier": (
            "deetjen-ob-f03-fine-direction-phase-window-census-v2"
        ),
        "sourcePreregistrationSHA256": sha256(PREREG),
        "sourceV1ExactParityFailureSHA256": sha256(V1_FAILURE),
        "deviceName": source["deviceName"],
        "sourceRuntimeSeconds": source["runtimeSeconds"],
        "fluidEvolutionExecuted": False,
        "populationAllocationPerformed": False,
        "newPhysicsKernelExecuted": False,
        "newMetalExecutionPerformed": False,
        "cases": qualified_cases,
        "maximumMetalCPUMaskMismatchCellCount": max(
            case["metalCPUMaskMismatchCellCount"] for case in qualified_cases
        ),
        "maximumMetalCPUPerDirectionCountMismatch": max(
            case["maximumMetalCPUPerDirectionCountMismatch"]
            for case in qualified_cases
        ),
        "maximumMetalCPUWholeDirectionCountMismatch": max(
            case["maximumMetalCPUWholeDirectionCountMismatch"]
            for case in qualified_cases
        ),
        "qualifiedTieCellCount": sum(
            len(case["qualifiedMaskMismatches"]) for case in qualified_cases
        ),
        "qualifiedCaseCount": sum(
            case["qualifiedParityGatePassed"] for case in qualified_cases
        ),
        "maximumCensusToProductionActiveLinkRelativeDifference": max(
            case["censusToProductionActiveLinkRelativeDifference"]
            for case in qualified_cases
        ),
        "censusPassed": passed,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "classification": classification,
        "nextAction": (
            "Apply the frozen histogram and fixed-profile response gates to all eleven pairs."
            if passed
            else "Stop and localize the unqualified arithmetic mismatch."
        ),
        "claimBoundary": prereg["claimBoundary"],
    }
    OUTPUT.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(json.dumps(report, indent=2, sort_keys=True))
    if not passed:
        raise SystemExit("V2 arithmetic-tie qualification failed")


if __name__ == "__main__":
    main()

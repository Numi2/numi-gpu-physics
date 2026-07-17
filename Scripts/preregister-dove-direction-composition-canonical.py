#!/usr/bin/env python3
"""Freeze the minimal direction-composition planar canonical."""

from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
DISCRIMINATOR = ARTIFACTS / "deetjen-dove-link-composition-discriminator.json"
DISCRIMINATOR_AUDIT = ARTIFACTS / (
    "deetjen-dove-link-composition-discriminator-audit.json"
)
D28 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d28.json"
D32 = ARTIFACTS / "deetjen-dove-source-viscosity-reflected-provenance-d32.json"
OUTPUT = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-preregistration.json"
)
V1_PREREGISTRATION = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-preregistration-v1-float-degenerate.json"
)
V1_REPORT = ARTIFACTS / (
    "deetjen-dove-direction-composition-canonical-v1-float-degenerate.json"
)

D3Q19_WEIGHTS = [
    1.0 / 3.0,
    1.0 / 18.0, 1.0 / 18.0,
    1.0 / 18.0, 1.0 / 18.0,
    1.0 / 18.0, 1.0 / 18.0,
    1.0 / 36.0, 1.0 / 36.0,
    1.0 / 36.0, 1.0 / 36.0,
    1.0 / 36.0, 1.0 / 36.0,
    1.0 / 36.0, 1.0 / 36.0,
    1.0 / 36.0, 1.0 / 36.0,
    1.0 / 36.0, 1.0 / 36.0,
]


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stratum_key(item: dict) -> tuple:
    return (
        item["partIdentifier"],
        item["directionIndex"],
        item["branch"],
        item["topologyClass"],
        item["linkFractionBin"],
    )


def source_midpoint_profile(d28: dict, d32: dict) -> list[float]:
    weighted_sum = defaultdict(float)
    pooled_count = defaultdict(int)
    for endpoint28, endpoint32 in zip(d28["endpoints"], d32["endpoints"]):
        strata28 = {stratum_key(item): item for item in endpoint28["strata"]}
        strata32 = {stratum_key(item): item for item in endpoint32["strata"]}
        # The accumulated population means are source evidence. Keep their
        # addition order deterministic across Python hash seeds.
        for key in sorted(set(strata28) | set(strata32)):
            item28 = strata28.get(key)
            item32 = strata32.get(key)
            count = int(item28["selectedLinkCount"] if item28 else 0)
            count += int(item32["selectedLinkCount"] if item32 else 0)
            mean = 0.5 * (
                float(item28["reflectedPopulationMean"] if item28 else 0.0)
                + float(item32["reflectedPopulationMean"] if item32 else 0.0)
            )
            direction = int(key[1])
            weighted_sum[direction] += count * mean
            pooled_count[direction] += count
    profile = [0.0] * 19
    for direction in range(1, 19):
        if pooled_count[direction] > 0:
            profile[direction] = weighted_sum[direction] / pooled_count[direction]
    return profile


def main() -> None:
    discriminator = load(DISCRIMINATOR)
    audit = load(DISCRIMINATOR_AUDIT)
    d28 = load(D28)
    d32 = load(D32)
    v1_preregistration = load(V1_PREREGISTRATION)
    frozen_profiles = v1_preregistration["fixedPopulationProfiles"]
    reconstructed_source_profile = source_midpoint_profile(d28, d32)
    if not (
        discriminator["analysisPassed"]
        and not discriminator["fluidEvolutionExecuted"]
        and discriminator["attribution"]["leadingFactor"]
        == "directionComposition"
        and discriminator["attribution"]["sameLeaderInBothTemporalHalves"]
        and discriminator["attribution"]["leadingAbsoluteLedgerFraction"] >= 0.5
        and discriminator["minimalCanonicalAuthorized"]
        and not discriminator["productionModificationAuthorized"]
        and not discriminator["d36RunAuthorized"]
        and audit["allChecksPassed"]
        and audit["checkCount"] == 18
        and audit["reportSHA256"] == sha256(DISCRIMINATOR)
        and d28["provenanceCasePassed"]
        and d32["provenanceCasePassed"]
        and [profile["identifier"] for profile in frozen_profiles]
        == ["rest-equilibrium", "deetjen-midpoint-pooled"]
        and frozen_profiles[0]["directionPopulations"] == D3Q19_WEIGHTS
        and max(
            abs(left - right)
            for left, right in zip(
                frozen_profiles[1]["directionPopulations"],
                reconstructed_source_profile,
            )
        ) <= 1e-15
    ):
        raise SystemExit("audited direction-composition leader is required")

    artifact = {
        "schemaVersion": 2,
        "preregistrationIdentifier": (
            "deetjen-ob-f03-direction-composition-planar-canonical-v2"
        ),
        "revisionHistory": {
            "v1PreregistrationSHA256": sha256(V1_PREREGISTRATION),
            "v1FailedReportSHA256": sha256(V1_REPORT),
            "v1Failure": (
                "All response, refinement, phase, and histogram gates passed, "
                "but world-coordinate Float signed-distance evaluation assigned "
                "exact phase-0.5 lattice-center ties differently on Metal and CPU."
            ),
            "v2OnlyChange": (
                "Evaluate the identical half-space in centered cell coordinates "
                "using the frozen integer normal before normalization. No grid, "
                "orientation, phase, population, threshold, analytic reference, "
                "or scientific classification rule changed."
            ),
        },
        "sourceDiscriminatorSHA256": sha256(DISCRIMINATOR),
        "sourceDiscriminatorAuditSHA256": sha256(DISCRIMINATOR_AUDIT),
        "sourceD28ProvenanceSHA256": sha256(D28),
        "sourceD32ProvenanceSHA256": sha256(D32),
        "referenceLengthCells": [48, 64],
        "patchSideLengthMeters": 1.0,
        "domainSideLengthMeters": 1.8125,
        "subcellPhaseOffsets": [0.1, 0.3, 0.5, 0.7, 0.9],
        "planeOffsetRule": "plane offset from domain center is (phase - 0.5) * dx",
        "evaluationArithmetic": (
            "Compute signed distance in cell units as "
            "(dot(integerNormal, cell + 0.5 - grid/2) - "
            "(phase - 0.5) * length(integerNormal)) / "
            "length(integerNormal), then multiply by dx only for the reported "
            "physical intersection. This makes exact lattice-center ties "
            "deterministic across Metal and CPU."
        ),
        "orientations": [
            {"identifier": "axis-x", "integerNormal": [1, 0, 0]},
            {"identifier": "face-diagonal-xz", "integerNormal": [1, 0, 1]},
            {"identifier": "mixed-201", "integerNormal": [2, 0, 1]},
            {"identifier": "oblique-302", "integerNormal": [3, 0, 2]},
        ],
        # V2 is an arithmetic-only revision. Reuse the exact V1 population
        # decimals after independently reconstructing them above.
        "fixedPopulationProfiles": frozen_profiles,
        "analyticReference": (
            "For fixed direction populations f_q and unit patch area, the exact "
            "one-sided planar response is sum_{c_q dot n > 0} "
            "2 f_q c_q (c_q dot n). The lattice estimator replaces the crossing "
            "density (c_q dot n)/dx^2 with the counted production-convention "
            "solid-to-fluid links. Compare vectors, not only normal magnitude."
        ),
        "fixedInputs": (
            "Static analytic half-space; one square plane patch of fixed physical "
            "area; production D3Q19 directions; zero wall velocity; no topology "
            "change; fixed halfway q=0.5 branch; no collision, streaming, fluid "
            "state, cover/uncover impulse, or force-law modification. Only plane "
            "orientation, grid resolution, and normal subcell phase vary."
        ),
        "maximumMetalCPUPerDirectionCountMismatch": 2,
        "maximumMetalCPUCountRelativeDifference": 0.0005,
        "maximumFineProfileVectorRelativeError": 0.05,
        "maximumCoarseFinePhaseMeanProfileRelativeDifference": 0.05,
        "maximumFinePhaseProfileRelativeSpread": 0.05,
        "maximumCoarseFineDirectionHistogramTotalVariation": 0.05,
        "maximumEquilibriumFineNormalResponseError": 0.05,
        "maximumEquilibriumFineTangentialLeakage": 0.05,
        "classificationRule": (
            "Clear basic direction weighting only if Metal/CPU counts, both fixed-"
            "population analytic vector responses, fine-grid phase stability, "
            "coarse/fine phase means, direction-histogram variation, and the "
            "equilibrium normal/tangential gates all pass for every orientation. "
            "If only the bird-like profile fails, classify source-like direction "
            "aliasing; if equilibrium also fails, classify general direction "
            "weighting/geometry aliasing."
        ),
        "fluidEvolutionAuthorized": False,
        "productionModificationAuthorized": False,
        "d36RunAuthorized": False,
        "gridConvergenceGateApplied": False,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This tiny static planar canonical can test production-convention "
            "D3Q19 direction counting and fixed-population response against an "
            "analytic crossing-density reference. A pass clears only basic planar "
            "direction weighting; a failure localizes aliasing. It cannot establish "
            "whole-bird grid convergence, a production boundary defect, experimental "
            "agreement, quantitative bird loads, or free flight, and it never "
            "authorizes D36 or a production edit."
        ),
        "passed": True,
    }
    OUTPUT.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(json.dumps(artifact, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

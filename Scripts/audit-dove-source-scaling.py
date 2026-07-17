#!/usr/bin/env python3
"""Independently reconstruct the Deetjen source-property/Reynolds report."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path

import numpy as np
from scipy.io import loadmat


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "ValidationArtifacts"
DEFAULT_PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-scaling-preregistration.json"
)
DEFAULT_REPORT = ARTIFACTS / "deetjen-dove-source-scaling.json"
DEFAULT_OUTPUT = ARTIFACTS / "deetjen-dove-source-scaling-audit.json"


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def deposited_path(root: Path, archive_path: str) -> Path:
    parts = Path(archive_path).parts
    if not parts or parts[0] != "DoveMuscles_DataCode" or ".." in parts:
        fail(f"unsafe deposited path: {archive_path}")
    return root.joinpath(*parts[1:])


def close(actual: float, expected: float, tolerance: float = 2e-10) -> bool:
    return math.isclose(actual, expected, rel_tol=tolerance, abs_tol=tolerance)


def invert_sutherland(viscosity_target: float) -> float:
    # Independent bisection using the conventional air constants frozen by the
    # report. This inference is a plausibility check, never a measurement.
    low, high = 200.0, 400.0
    for _ in range(120):
        temperature = (low + high) / 2.0
        viscosity = (
            1.716e-5
            * (temperature / 273.15) ** 1.5
            * (273.15 + 110.4)
            / (temperature + 110.4)
        )
        if viscosity < viscosity_target:
            low = temperature
        else:
            high = temperature
    return (low + high) / 2.0


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Independently audit the Deetjen source scaling report"
    )
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--article-pdf", required=True, type=Path)
    parser.add_argument("--article-text", required=True, type=Path)
    parser.add_argument(
        "--preregistration", type=Path, default=DEFAULT_PREREGISTRATION
    )
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    arguments = parser.parse_args()

    prereg = json.loads(arguments.preregistration.read_bytes())
    report = json.loads(arguments.report.read_bytes())
    locks = prereg["depositedSourceLocks"]
    code_path = deposited_path(
        arguments.source_root, locks["muscleModelArchivePath"]
    )
    span_path = deposited_path(
        arguments.source_root, locks["wingSpanArchivePath"]
    )
    area_path = deposited_path(
        arguments.source_root, locks["wingAreaArchivePath"]
    )
    analysis_path = deposited_path(
        arguments.source_root, locks["derivedAnalysisArchivePath"]
    )

    code = code_path.read_text(encoding="utf-8")
    rho_match = re.search(r"\bRho\s*=\s*([0-9.]+)\s*;", code)
    mu_match = re.search(
        r"\bVisc\s*=\s*([0-9.]+)\s*\*\s*10\s*\^\s*\(\s*(-?\d+)\s*\)",
        code,
    )
    if rho_match is None or mu_match is None:
        fail("independent parser could not recover Rho/Visc")
    rho = float(rho_match.group(1))
    mu = float(mu_match.group(1)) * 10.0 ** int(mu_match.group(2))
    nu = mu / rho

    span = loadmat(span_path, squeeze_me=True)
    area = loadmat(area_path, squeeze_me=True, struct_as_record=False)
    analysis = loadmat(analysis_path, squeeze_me=True)
    ob_index = 1
    radius = float(np.asarray(span["WingRad0"])[ob_index]) * 1e-3
    wing_area = float(np.asarray(area["LWing"].Areas)[ob_index]) * 1e-6
    chord = wing_area / radius
    blade_speed = float(
        np.nanmax(
            np.sqrt(
                np.sum(
                    np.asarray(analysis["BE_Vel1_w"], dtype=np.float64) ** 2,
                    axis=2,
                )
            )
        )
    )
    body_speed = float(
        np.mean(
            np.sqrt(
                np.sum(
                    np.asarray(analysis["BodyVel_w"], dtype=np.float64) ** 2,
                    axis=1,
                )
            )
        )
    )

    reynolds = report["reynoldsDefinitions"]
    registered_speed = reynolds["convertedMaximumSurfaceSpeedMetersPerSecond"]
    registered_length = reynolds["registeredReferenceLengthMeters"]
    author_re = blade_speed * chord / nu
    body_re = body_speed * chord / nu
    registered_source_re = registered_speed * registered_length / nu
    velocity_difference = abs(registered_speed / blade_speed - 1.0)
    length_difference = abs(registered_length / chord - 1.0)
    reynolds_difference = abs(registered_source_re / author_re - 1.0)

    grid_rows = report["gridReconstruction"]
    reconstructed_grid = []
    for row in grid_rows:
        dx = row["cellSizeMeters"]
        dt = row["fluidTimeStepSeconds"]
        source_tau = 0.5 + 3.0 * nu * dt / (dx * dx)
        effective_nu = (
            (row["floorTauPlus"] - 0.5) / 3.0 * dx * dx / dt
        )
        reconstructed_grid.append(
            {
                "referenceLengthCells": row["referenceLengthCells"],
                "sourceTauPlus": source_tau,
                "sourceTauMarginAboveHalf": source_tau - 0.5,
                "effectiveDynamicViscosityPascalSeconds": rho * effective_nu,
                "effectiveToSourceViscosityRatio": effective_nu / nu,
                "registeredEffectiveReynoldsNumber": (
                    registered_speed * registered_length / effective_nu
                ),
            }
        )

    minimum_cells = None
    for cells in range(8, 65):
        dx = registered_length / cells
        dt = 1.0 / (2000.0 * 2.0 * cells)
        if 0.5 + 3.0 * nu * dt / (dx * dx) >= 0.50005:
            minimum_cells = cells
            break

    article_text = arguments.article_text.read_text(
        encoding="utf-8", errors="replace"
    )
    normalized_article = " ".join(article_text.split())
    sutherland_temperature = invert_sutherland(mu)
    ideal_temperature = 101325.0 / (rho * 287.05)
    implied_pressure = rho * 287.05 * sutherland_temperature
    atmosphere = report["atmosphericPlausibilityOnly"]

    grid_exact = len(grid_rows) == 3
    if grid_exact:
        for row, rebuilt in zip(grid_rows, reconstructed_grid):
            grid_exact = grid_exact and all(
                close(row[key], value, 2e-10)
                for key, value in rebuilt.items()
                if key != "referenceLengthCells"
            ) and row["referenceLengthCells"] == rebuilt["referenceLengthCells"]

    source_hashes = {
        "muscleModel": sha256(code_path),
        "wingSpan": sha256(span_path),
        "wingArea": sha256(area_path),
        "derivedAnalysis": sha256(analysis_path),
    }
    checks = {
        "schemasAndPreregistration": prereg["schemaVersion"] == 1
        and report["schemaVersion"] == 1
        and prereg["passed"]
        and report["sourcePreregistrationSHA256"]
        == sha256(arguments.preregistration),
        "primarySourceHashes": source_hashes["muscleModel"]
        == locks["muscleModelSHA256"]
        and source_hashes["wingSpan"] == locks["wingSpanSHA256"]
        and source_hashes["wingArea"] == locks["wingAreaSHA256"]
        and source_hashes["derivedAnalysis"]
        == locks["derivedAnalysisSHA256"],
        "articleEvidence": sha256(arguments.article_pdf)
        == prereg["article"]["pdfSHA256"]
        and sha256(arguments.article_text)
        == prereg["article"]["extractedTextSHA256"]
        and "10.7554/eLife.89968" in article_text
        and re.search(
            r"Flight speed \(m/s\)\s+1\.23 ± 0\.13", normalized_article
        )
        is not None
        and prereg["article"]["pdfPageNumber"] == 15
        and prereg["article"]["tableNumber"] == 2
        and prereg["article"]["populationScope"]
        == "N=4 doves; n=5 flights each"
        and len(re.findall(r"Reynolds", article_text, re.IGNORECASE)) == 0,
        "authorCodeConstants": close(
            report["authorCode"]["airDensityKilogramsPerCubicMeter"], rho
        )
        and close(
            report["authorCode"]["dynamicViscosityPascalSeconds"], mu
        )
        and close(
            report["sourceFluidProperties"][
                "kinematicViscositySquareMetersPerSecond"
            ],
            nu,
        )
        and report["sourceFluidProperties"]["provenanceClass"]
        == "deposited-author-code-convention"
        and not report["sourceFluidProperties"][
            "sameFlightAtmosphericMeasurement"
        ],
        "morphologyAndVelocity": close(
            reynolds["singleWingRadiusMeters"], radius
        )
        and close(reynolds["singleWingAreaSquareMeters"], wing_area)
        and close(reynolds["authorDataMeanChordMeters"], chord)
        and close(
            reynolds["depositedMaximumBladeElementSpeedMetersPerSecond"],
            blade_speed,
        )
        and close(
            reynolds["selectedFlightMeanBodySpeedMetersPerSecond"], body_speed
        ),
        "reynoldsReconstruction": close(
            reynolds["authorDataBladeSpeedMeanChordReynoldsNumber"], author_re
        )
        and close(
            reynolds["selectedBodySpeedMeanChordReynoldsNumber"], body_re
        )
        and close(
            reynolds["registeredSourcePropertyReynoldsNumber"],
            registered_source_re,
        )
        and close(
            reynolds["relativeVelocityConventionDifference"],
            velocity_difference,
        )
        and close(
            reynolds["relativeReferenceLengthConventionDifference"],
            length_difference,
        )
        and close(
            reynolds["relativeReynoldsConventionDifference"],
            reynolds_difference,
        ),
        "gridByGridViscosityAndTau": grid_exact
        and all(
            not row["sourceViscosityMeetsFloatMargin"] for row in grid_rows
        )
        and max(
            abs(
                row["effectiveToSourceViscosityRatio"]
                / 68.07194967379765
                - 1.0
            )
            for row in grid_rows
        )
        < 2e-7,
        "minimumEligibleGrid": minimum_cells == 28
        and report[
            "minimumIntegerReferenceLengthCellsForSourceViscosityMargin"
        ]
        == 28,
        "atmosphericInferenceBoundary": close(
            atmosphere["idealDryAirTemperatureAt101325PascalsKelvin"],
            ideal_temperature,
        )
        and close(
            atmosphere["sutherlandTemperatureForDepositedViscosityKelvin"],
            sutherland_temperature,
        )
        and close(
            atmosphere["idealDryAirPressureAtSutherlandTemperaturePascals"],
            implied_pressure,
        )
        and not atmosphere["measurementClaimAuthorized"],
        "classificationAndSafety": report["classification"]
        == "source-fluid-properties-confirmed-engineering-reynolds-not-published"
        and report["sourceCodeFluidPropertyConventionConfirmed"]
        and report["engineeringReynoldsProxyConfirmed"]
        and not report["checks"]["publishedReynoldsClaimAuthorized"]
        and not report["checks"]["velocityWithinThreshold"]
        and not report["checks"]["reynoldsConventionWithinThreshold"]
        and report["checks"]["referenceLengthWithinThreshold"]
        and not report["sourceViscosityRunAuthorized"]
        and not report["d20DiagnosticAuthorized"]
        and not report["productionModificationAuthorized"]
        and not report["fluidEvolutionExecuted"]
        and not report["experimentalAgreementGateApplied"],
    }
    all_passed = all(checks.values())
    audit = {
        "schemaVersion": 1,
        "generatedBy": "Scripts/audit-dove-source-scaling.py",
        "preregistrationSHA256": sha256(arguments.preregistration),
        "reportSHA256": sha256(arguments.report),
        "sourceSHA256": source_hashes,
        "independentReconstruction": {
            "airDensityKilogramsPerCubicMeter": rho,
            "dynamicViscosityPascalSeconds": mu,
            "kinematicViscositySquareMetersPerSecond": nu,
            "meanChordMeters": chord,
            "depositedMaximumBladeElementSpeedMetersPerSecond": blade_speed,
            "selectedFlightMeanBodySpeedMetersPerSecond": body_speed,
            "authorDataBladeSpeedMeanChordReynoldsNumber": author_re,
            "registeredSourcePropertyReynoldsNumber": registered_source_re,
            "relativeReynoldsConventionDifference": reynolds_difference,
            "minimumIntegerReferenceLengthCellsForSourceViscosityMargin": (
                minimum_cells
            ),
            "grid": reconstructed_grid,
        },
        "checks": checks,
        "checkCount": len(checks),
        "allChecksPassed": all_passed,
        "claimBoundary": (
            "This independent source/data/equation reconstruction confirms "
            "the report mechanics. It does not supply missing same-flight "
            "atmospheric measurements or authorize a simulation or force claim."
        ),
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    temporary = arguments.output.with_name(arguments.output.name + ".part")
    temporary.write_text(
        json.dumps(audit, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temporary.replace(arguments.output)
    print(json.dumps(audit, indent=2, sort_keys=True))
    if not all_passed:
        fail("source scaling audit failed")


if __name__ == "__main__":
    main()

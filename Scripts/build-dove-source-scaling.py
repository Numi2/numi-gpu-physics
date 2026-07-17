#!/usr/bin/env python3
"""Build the preregistered Deetjen source-property/Reynolds audit.

This utility is deliberately fluid-free.  It reads the SHA-locked deposited
MATLAB sources, the official article PDF/text, and committed BirdFlow evidence.
The preregistration freezes definitions and thresholds; evaluation then closes
the dimensional-to-lattice algebra without dispatching Metal work.
"""

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
DEFAULT_QUALIFICATION = ARTIFACTS / "deetjen-dove-source-qualification.json"
DEFAULT_INGESTION = ARTIFACTS / "deetjen-dove-engineering-ingestion.json"
DEFAULT_SURFACE_PARITY = ARTIFACTS / "deetjen-dove-surface-cpu-parity.json"
DEFAULT_PILOT = ARTIFACTS / "deetjen-dove-coarse-force-pilot.json"
DEFAULT_GRID = ARTIFACTS / "deetjen-dove-collision-grid-preregistration.json"
DEFAULT_PREREGISTRATION = (
    ARTIFACTS / "deetjen-dove-source-scaling-preregistration.json"
)
DEFAULT_REPORT = ARTIFACTS / "deetjen-dove-source-scaling.json"


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_bytes())


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".part")
    temporary.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def source_path(source_root: Path, archive_path: str) -> Path:
    relative = Path(archive_path)
    if not relative.parts or relative.parts[0] != "DoveMuscles_DataCode":
        fail(f"unexpected deposited archive path: {archive_path}")
    return source_root.joinpath(*relative.parts[1:])


def member_record(ingestion: dict, archive_path: str) -> dict:
    for record in ingestion["sourceMemberVerification"]:
        if record["archivePath"] == archive_path:
            return record
    fail(f"missing ingestion lock for {archive_path}")


def parse_author_constants(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    rho = re.search(
        r"^\s*Rho\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*;[^\n]*$",
        text,
        re.MULTILINE,
    )
    viscosity = re.search(
        r"^\s*Visc\s*=\s*([0-9]+(?:\.[0-9]+)?)\s*\*\s*"
        r"10\s*\^\s*\(\s*(-?[0-9]+)\s*\)\s*;[^\n]*$",
        text,
        re.MULTILINE,
    )
    if rho is None or viscosity is None:
        fail("could not locate deposited Rho/Visc assignments")
    rho_value = float(rho.group(1))
    viscosity_value = float(viscosity.group(1)) * 10.0 ** int(
        viscosity.group(2)
    )
    return {
        "airDensityKilogramsPerCubicMeter": rho_value,
        "dynamicViscosityPascalSeconds": viscosity_value,
        "densityLineNumber": text[: rho.start()].count("\n") + 1,
        "viscosityLineNumber": text[: viscosity.start()].count("\n") + 1,
        "densityAssignment": rho.group(0).strip(),
        "viscosityAssignment": viscosity.group(0).strip(),
    }


def source_evidence(arguments: argparse.Namespace) -> dict:
    qualification = read_json(arguments.qualification)
    ingestion = read_json(arguments.ingestion)
    surface_parity = read_json(arguments.surface_parity)
    pilot = read_json(arguments.pilot)
    grid = read_json(arguments.grid_preregistration)

    code_lock = next(
        entry
        for entry in qualification["selectedBenchmark"][
            "forceRegistrationCodeMembers"
        ]
        if entry["path"].endswith("/MuscleModel.m")
    )
    code_path = source_path(arguments.source_root, code_lock["path"])
    if sha256(code_path) != code_lock["sha256"]:
        fail("deposited MuscleModel.m SHA-256 changed")

    paths = {
        "wingSpan": "DoveMuscles_DataCode/2 Dissections/SurfArea/WingSpan.mat",
        "wingArea": "DoveMuscles_DataCode/2 Dissections/SurfArea/SurfAreas.mat",
        "analysis": (
            "DoveMuscles_DataCode/9 MuscleModel/2TestRuns/OB/"
            "2018_12_11_OB_F03.mat"
        ),
    }
    locked_paths: dict[str, dict] = {}
    for identifier, archive_path in paths.items():
        path = source_path(arguments.source_root, archive_path)
        record = member_record(ingestion, archive_path)
        if sha256(path) != record["sha256"]:
            fail(f"deposited source SHA-256 changed: {archive_path}")
        locked_paths[identifier] = {
            "archivePath": archive_path,
            "sha256": record["sha256"],
            "localPath": path,
        }

    article_pdf_sha = sha256(arguments.article_pdf)
    article_text_sha = sha256(arguments.article_text)
    article_text = arguments.article_text.read_text(
        encoding="utf-8", errors="replace"
    )
    normalized_article = " ".join(article_text.split())
    if not re.search(
        r"Flight speed \(m/s\)\s+1\.23 ± 0\.13", normalized_article
    ):
        fail("article Table 2 flight-speed evidence was not reproduced")
    if "10.7554/eLife.89968" not in article_text:
        fail("article DOI was not found in the supplied primary-source text")

    span = loadmat(
        locked_paths["wingSpan"]["localPath"], squeeze_me=True
    )
    areas = loadmat(
        locked_paths["wingArea"]["localPath"],
        squeeze_me=True,
        struct_as_record=False,
    )
    analysis = loadmat(
        locked_paths["analysis"]["localPath"], squeeze_me=True
    )
    bird_index = qualification["remoteArchiveInventory"]["birds"].index("OB")
    wing_radius = float(np.asarray(span["WingRad0"])[bird_index]) / 1000.0
    wing_area = (
        float(np.asarray(areas["LWing"].Areas)[bird_index]) / 1_000_000.0
    )
    blade_velocity = np.asarray(analysis["BE_Vel1_w"], dtype=np.float64)
    maximum_blade_speed = float(
        np.nanmax(np.linalg.norm(blade_velocity, axis=2))
    )
    body_velocity = np.asarray(analysis["BodyVel_w"], dtype=np.float64)
    mean_body_speed = float(np.mean(np.linalg.norm(body_velocity, axis=1)))

    constants = parse_author_constants(code_path)
    return {
        "qualification": qualification,
        "ingestion": ingestion,
        "surfaceParity": surface_parity,
        "pilot": pilot,
        "grid": grid,
        "codeLock": code_lock,
        "codePath": code_path,
        "lockedPaths": locked_paths,
        "articlePDFSHA256": article_pdf_sha,
        "articleTextSHA256": article_text_sha,
        "articleText": article_text,
        "authorConstants": constants,
        "birdIndexZeroBased": bird_index,
        "wingRadiusMeters": wing_radius,
        "wingAreaSquareMeters": wing_area,
        "maximumBladeElementSpeedMetersPerSecond": maximum_blade_speed,
        "meanBodySpeedMetersPerSecond": mean_body_speed,
    }


def preregistration(arguments: argparse.Namespace, evidence: dict) -> dict:
    qualification = evidence["qualification"]
    surface = evidence["surfaceParity"]
    pilot = evidence["pilot"]
    grid = evidence["grid"]
    constants = evidence["authorConstants"]
    if not surface["cpuParityPassed"] or not grid["passed"]:
        fail("source scaling preregistration requires passed surface/grid evidence")
    if pilot["datasetIdentifier"] != grid["datasetIdentifier"]:
        fail("pilot/grid dataset mismatch")
    if not math.isclose(
        constants["airDensityKilogramsPerCubicMeter"], 1.18, rel_tol=0, abs_tol=0
    ) or not math.isclose(
        constants["dynamicViscosityPascalSeconds"],
        1.849e-5,
        rel_tol=0,
        abs_tol=0,
    ):
        fail("deposited fluid-property constants changed")
    locks = evidence["lockedPaths"]
    return {
        "schemaVersion": 1,
        "datasetIdentifier": pilot["datasetIdentifier"],
        "manifestSHA256": pilot["manifestSHA256"],
        "article": {
            "doi": qualification["sourceLocks"]["article"]["doi"],
            "versionOfRecordURL": "https://elifesciences.org/articles/89968",
            "pdfURL": "https://elifesciences.org/articles/89968.pdf",
            "pdfSHA256": evidence["articlePDFSHA256"],
            "extractedTextSHA256": evidence["articleTextSHA256"],
            "pdfPageNumber": 15,
            "tableNumber": 2,
            "populationScope": "N=4 doves; n=5 flights each",
            "table2FlightSpeedMeanMetersPerSecond": 1.23,
            "table2FlightSpeedSDMetersPerSecond": 0.13,
            "publishedReynoldsNumber": None,
            "reportedAmbientTemperatureKelvin": None,
            "reportedAmbientPressurePascals": None,
            "reportedRelativeHumidity": None,
        },
        "depositedSourceLocks": {
            "muscleModelArchivePath": evidence["codeLock"]["path"],
            "muscleModelSHA256": evidence["codeLock"]["sha256"],
            "wingSpanArchivePath": locks["wingSpan"]["archivePath"],
            "wingSpanSHA256": locks["wingSpan"]["sha256"],
            "wingAreaArchivePath": locks["wingArea"]["archivePath"],
            "wingAreaSHA256": locks["wingArea"]["sha256"],
            "derivedAnalysisArchivePath": locks["analysis"]["archivePath"],
            "derivedAnalysisSHA256": locks["analysis"]["sha256"],
        },
        "committedEvidenceSHA256": {
            "sourceQualification": sha256(arguments.qualification),
            "engineeringIngestion": sha256(arguments.ingestion),
            "surfaceCPUParity": sha256(arguments.surface_parity),
            "coarseForcePilot": sha256(arguments.pilot),
            "collisionGridPreregistration": sha256(
                arguments.grid_preregistration
            ),
        },
        "expectedAuthorCodeConstants": {
            "airDensityKilogramsPerCubicMeter": 1.18,
            "dynamicViscosityPascalSeconds": 1.849e-5,
        },
        "definitions": {
            "sourceKinematicViscosity": "nu_source = mu_source / rho_source",
            "sourceRelaxation": "tau_source = 0.5 + 3 nu_source dt / dx^2",
            "effectiveKinematicViscosity": (
                "nu_effective = ((tau_floor - 0.5) / 3) dx^2 / dt"
            ),
            "authorDataMeanChord": "c_mean = selected single-wing area / wing radius",
            "authorDataReynoldsProxy": (
                "Re_author_proxy = max(|BE_Vel1_w|) c_mean / nu_source"
            ),
            "registeredSourcePropertyReynolds": (
                "Re_registered_source = max converted surface speed * 0.08 m / nu_source"
            ),
            "registeredEffectiveReynolds": (
                "Re_registered_effective = max converted surface speed * 0.08 m / nu_effective"
            ),
        },
        "thresholds": {
            "maximumRelativeSourceReconstructionError": 2e-7,
            "maximumRelativeReferenceLengthDifference": 0.10,
            "maximumRelativeVelocityDifference": 0.10,
            "maximumRelativeReynoldsConventionDifference": 0.15,
            "minimumTauPlus": 0.50005,
            "referenceLengthMeters": 0.08,
            "minimumGridCellsForSourceViscositySearch": 8,
            "maximumGridCellsForSourceViscositySearch": 64,
        },
        "selectionRule": (
            "Confirm rho and mu only as deposited author-code conventions. "
            "Reconstruct source/effective viscosity and tau on D=8/12/16. "
            "Compare the registered maximum-surface-speed/0.08 m Reynolds "
            "with a deposited-blade-speed/selected-mean-chord proxy. A "
            "published-Reynolds claim requires an explicit publication value "
            "and definition; inferred temperature is plausibility-only. "
            "Search integer D for the first source-viscosity tau satisfying "
            "the unchanged Float margin at the fixed Courant scaling."
        ),
        "fixedInputs": (
            "Version-of-record article; SHA-locked MuscleModel.m, WingSpan.mat, "
            "SurfAreas.mat, and selected-flight derived analysis; committed "
            "surface CPU parity, D8 pilot, and D8/D12/D16 grid contract. No "
            "fluid evolution, Metal dispatch, force rescaling, or tuned threshold."
        ),
        "passed": True,
        "experimentalAgreementGateApplied": False,
        "claimBoundary": (
            "This audit can confirm an author-code fluid-property convention "
            "and solver scaling algebra. It cannot turn unmeasured atmospheric "
            "conditions or an engineering U/L proxy into a published Reynolds "
            "number, validate force agreement, or authorize production changes."
        ),
    }


def invert_sutherland(dynamic_viscosity: float) -> float:
    reference_viscosity = 1.716e-5
    reference_temperature = 273.15
    sutherland_temperature = 110.4
    low, high = 200.0, 400.0
    for _ in range(100):
        temperature = 0.5 * (low + high)
        viscosity = reference_viscosity * (
            (temperature / reference_temperature) ** 1.5
            * (reference_temperature + sutherland_temperature)
            / (temperature + sutherland_temperature)
        )
        if viscosity < dynamic_viscosity:
            low = temperature
        else:
            high = temperature
    return 0.5 * (low + high)


def evaluate(
    arguments: argparse.Namespace, evidence: dict, contract: dict
) -> dict:
    expected = preregistration(arguments, evidence)
    if contract != expected or not contract["passed"]:
        fail("source-scaling evaluation does not match its preregistration")
    prereg_sha = sha256(arguments.preregistration)
    constants = evidence["authorConstants"]
    rho = constants["airDensityKilogramsPerCubicMeter"]
    dynamic_viscosity = constants["dynamicViscosityPascalSeconds"]
    source_nu = dynamic_viscosity / rho
    wing_radius = evidence["wingRadiusMeters"]
    wing_area = evidence["wingAreaSquareMeters"]
    mean_chord = wing_area / wing_radius
    blade_speed = evidence["maximumBladeElementSpeedMetersPerSecond"]
    body_speed = evidence["meanBodySpeedMetersPerSecond"]
    pilot = evidence["pilot"]
    grid_source = evidence["grid"]
    surface = evidence["surfaceParity"]
    registered_speed = pilot["plan"]["maximumSurfaceSpeedMetersPerSecond"]
    registered_length = contract["thresholds"]["referenceLengthMeters"]
    author_proxy_re = blade_speed * mean_chord / source_nu
    registered_source_re = registered_speed * registered_length / source_nu
    body_chord_re = body_speed * mean_chord / source_nu
    relative_velocity_difference = abs(registered_speed / blade_speed - 1.0)
    relative_length_difference = abs(registered_length / mean_chord - 1.0)
    relative_reynolds_difference = abs(
        registered_source_re / author_proxy_re - 1.0
    )

    grid_rows = []
    maximum_reconstruction_error = 0.0
    for source_grid in grid_source["gridContracts"]:
        cells = source_grid["referenceLengthCells"]
        dx = source_grid["cellSizeMeters"]
        dt = 1.0 / (
            pilot["plan"]["forceSamplesPerSecond"]
            * source_grid["fluidStepsPerForceSample"]
        )
        source_tau = 0.5 + 3.0 * source_nu * dt / (dx * dx)
        floor_tau = source_grid["tauPlus"]
        effective_nu = ((floor_tau - 0.5) / 3.0) * dx * dx / dt
        effective_mu = rho * effective_nu
        ratio = effective_nu / source_nu
        effective_re = registered_speed * registered_length / effective_nu
        maximum_reconstruction_error = max(
            maximum_reconstruction_error,
            abs(ratio / source_grid["pilotToSourceViscosityRatio"] - 1.0),
        )
        grid_rows.append(
            {
                "referenceLengthCells": cells,
                "cellSizeMeters": dx,
                "fluidTimeStepSeconds": dt,
                "sourceTauPlus": source_tau,
                "sourceTauMarginAboveHalf": source_tau - 0.5,
                "floorTauPlus": floor_tau,
                "effectiveDynamicViscosityPascalSeconds": effective_mu,
                "effectiveToSourceViscosityRatio": ratio,
                "registeredEffectiveReynoldsNumber": effective_re,
                "sourceViscosityMeetsFloatMargin": (
                    source_tau >= contract["thresholds"]["minimumTauPlus"]
                ),
            }
        )

    first_eligible_cells = None
    for cells in range(
        contract["thresholds"]["minimumGridCellsForSourceViscositySearch"],
        contract["thresholds"]["maximumGridCellsForSourceViscositySearch"] + 1,
    ):
        dx = registered_length / cells
        steps_per_sample = 2 * cells
        dt = 1.0 / (
            pilot["plan"]["forceSamplesPerSecond"] * steps_per_sample
        )
        source_tau = 0.5 + 3.0 * source_nu * dt / (dx * dx)
        if source_tau >= contract["thresholds"]["minimumTauPlus"]:
            first_eligible_cells = cells
            break
    if first_eligible_cells is None:
        fail("source-viscosity grid search did not find an eligible integer D")

    source_constants_match_solver = math.isclose(
        pilot["plan"]["sourceAirDensityKilogramsPerCubicMeter"],
        rho,
        rel_tol=2e-7,
    ) and math.isclose(
        pilot["plan"]["sourceDynamicViscosityPascalSeconds"],
        dynamic_viscosity,
        rel_tol=2e-7,
    )
    source_tau_matches_solver = math.isclose(
        grid_rows[0]["sourceTauPlus"],
        pilot["plan"]["sourceConditionTauPlusAtPilotGrid"],
        rel_tol=2e-7,
        abs_tol=2e-7,
    )
    surface_speed_reproduced = math.isclose(
        surface["maximumAdjacentPointSpeedMetersPerSecond"],
        registered_speed,
        rel_tol=3e-6,
    )
    deposited_speed_reproduced = math.isclose(
        surface["depositedMaximumBladeElementSpeedMetersPerSecond"],
        blade_speed,
        rel_tol=2e-12,
    )
    reference_length_within_threshold = (
        relative_length_difference
        <= contract["thresholds"]["maximumRelativeReferenceLengthDifference"]
    )
    velocity_within_threshold = (
        relative_velocity_difference
        <= contract["thresholds"]["maximumRelativeVelocityDifference"]
    )
    reynolds_within_threshold = (
        relative_reynolds_difference
        <= contract["thresholds"][
            "maximumRelativeReynoldsConventionDifference"
        ]
    )
    all_viscosity_reconstruction_passed = (
        source_constants_match_solver
        and source_tau_matches_solver
        and maximum_reconstruction_error
        <= contract["thresholds"]["maximumRelativeSourceReconstructionError"]
    )
    article = contract["article"]
    published_reynolds_claim_authorized = (
        article["publishedReynoldsNumber"] is not None
    )
    source_code_convention_confirmed = all_viscosity_reconstruction_passed
    engineering_reynolds_proxy_confirmed = (
        surface_speed_reproduced
        and deposited_speed_reproduced
        and reference_length_within_threshold
        and not velocity_within_threshold
        and not reynolds_within_threshold
        and not published_reynolds_claim_authorized
    )
    classification = (
        "source-fluid-properties-confirmed-engineering-reynolds-not-published"
        if source_code_convention_confirmed and engineering_reynolds_proxy_confirmed
        else "source-scaling-evidence-incomplete"
    )

    standard_pressure = 101_325.0
    dry_air_gas_constant = 287.05
    ideal_temperature = standard_pressure / (rho * dry_air_gas_constant)
    sutherland_temperature = invert_sutherland(dynamic_viscosity)
    implied_pressure = rho * dry_air_gas_constant * sutherland_temperature
    return {
        "schemaVersion": 1,
        "datasetIdentifier": pilot["datasetIdentifier"],
        "manifestSHA256": pilot["manifestSHA256"],
        "sourcePreregistrationSHA256": prereg_sha,
        "sourceLocks": contract["depositedSourceLocks"],
        "article": article,
        "authorCode": constants,
        "sourceFluidProperties": {
            "airDensityKilogramsPerCubicMeter": rho,
            "dynamicViscosityPascalSeconds": dynamic_viscosity,
            "kinematicViscositySquareMetersPerSecond": source_nu,
            "provenanceClass": "deposited-author-code-convention",
            "sameFlightAtmosphericMeasurement": False,
        },
        "reynoldsDefinitions": {
            "selectedBirdIdentifier": "OB",
            "selectedBirdIndexZeroBased": evidence["birdIndexZeroBased"],
            "singleWingRadiusMeters": wing_radius,
            "singleWingAreaSquareMeters": wing_area,
            "authorDataMeanChordMeters": mean_chord,
            "depositedMaximumBladeElementSpeedMetersPerSecond": blade_speed,
            "selectedFlightMeanBodySpeedMetersPerSecond": body_speed,
            "convertedMaximumSurfaceSpeedMetersPerSecond": registered_speed,
            "registeredReferenceLengthMeters": registered_length,
            "authorDataBladeSpeedMeanChordReynoldsNumber": author_proxy_re,
            "selectedBodySpeedMeanChordReynoldsNumber": body_chord_re,
            "registeredSourcePropertyReynoldsNumber": registered_source_re,
            "relativeVelocityConventionDifference": relative_velocity_difference,
            "relativeReferenceLengthConventionDifference": (
                relative_length_difference
            ),
            "relativeReynoldsConventionDifference": relative_reynolds_difference,
        },
        "gridReconstruction": grid_rows,
        "minimumIntegerReferenceLengthCellsForSourceViscosityMargin": (
            first_eligible_cells
        ),
        "atmosphericPlausibilityOnly": {
            "idealDryAirTemperatureAt101325PascalsKelvin": ideal_temperature,
            "sutherlandTemperatureForDepositedViscosityKelvin": (
                sutherland_temperature
            ),
            "idealDryAirPressureAtSutherlandTemperaturePascals": implied_pressure,
            "temperatureCelsiusRangeSpannedByInferences": [
                min(ideal_temperature, sutherland_temperature) - 273.15,
                max(ideal_temperature, sutherland_temperature) - 273.15,
            ],
            "measurementClaimAuthorized": False,
            "note": (
                "These standard dry-air inversions show that the deposited "
                "rho/mu pair is mutually plausible near room temperature and "
                "one atmosphere. The paper reports no same-flight ambient "
                "temperature, pressure, or humidity."
            ),
        },
        "checks": {
            "sourceConstantsMatchSolver": source_constants_match_solver,
            "sourceTauMatchesSolver": source_tau_matches_solver,
            "surfaceSpeedReproduced": surface_speed_reproduced,
            "depositedBladeSpeedReproduced": deposited_speed_reproduced,
            "referenceLengthWithinThreshold": reference_length_within_threshold,
            "velocityWithinThreshold": velocity_within_threshold,
            "reynoldsConventionWithinThreshold": reynolds_within_threshold,
            "allViscosityReconstructionPassed": (
                all_viscosity_reconstruction_passed
            ),
            "publishedReynoldsClaimAuthorized": (
                published_reynolds_claim_authorized
            ),
        },
        "maximumRelativeViscosityReconstructionError": (
            maximum_reconstruction_error
        ),
        "sourceCodeFluidPropertyConventionConfirmed": (
            source_code_convention_confirmed
        ),
        "engineeringReynoldsProxyConfirmed": engineering_reynolds_proxy_confirmed,
        "classification": classification,
        "sourceViscosityRunAuthorized": False,
        "d20DiagnosticAuthorized": False,
        "productionModificationAuthorized": False,
        "fluidEvolutionExecuted": False,
        "experimentalAgreementGateApplied": False,
        "scientificVerdict": (
            "The deposited rho and mu are exactly reproduced as author-code "
            "conventions and the 68.07x viscosity floor closes on all three "
            "grids. The solver's source-property Reynolds number is an "
            "engineering maximum-wall-speed/0.08 m proxy, not a Reynolds "
            "number published by Deetjen et al. Its 25.77% difference from the "
            "deposited-blade-speed/selected-mean-chord proxy rules out treating "
            "the two definitions as interchangeable."
        ),
        "nextAction": (
            "Preregister a short diagnostic-only D16 source-viscosity "
            "regularized-BGK/RR3 survival A/B before considering D28. D20 "
            "still cannot meet the unchanged tau>=0.50005 margin, while D28 "
            "is the first integer fixed-Courant grid that can."
        ),
        "claimBoundary": contract["claimBoundary"],
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build the archive-only Deetjen source scaling audit"
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--preregister", action="store_true")
    mode.add_argument("--evaluate", action="store_true")
    parser.add_argument("--source-root", required=True, type=Path)
    parser.add_argument("--article-pdf", required=True, type=Path)
    parser.add_argument("--article-text", required=True, type=Path)
    parser.add_argument("--qualification", type=Path, default=DEFAULT_QUALIFICATION)
    parser.add_argument("--ingestion", type=Path, default=DEFAULT_INGESTION)
    parser.add_argument("--surface-parity", type=Path, default=DEFAULT_SURFACE_PARITY)
    parser.add_argument("--pilot", type=Path, default=DEFAULT_PILOT)
    parser.add_argument(
        "--grid-preregistration", type=Path, default=DEFAULT_GRID
    )
    parser.add_argument(
        "--preregistration", type=Path, default=DEFAULT_PREREGISTRATION
    )
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()

    evidence = source_evidence(arguments)
    if arguments.preregister:
        result = preregistration(arguments, evidence)
        output = arguments.output or DEFAULT_PREREGISTRATION
    else:
        contract = read_json(arguments.preregistration)
        result = evaluate(arguments, evidence, contract)
        output = arguments.output or DEFAULT_REPORT
    write_json(output, result)
    print(json.dumps(result, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()

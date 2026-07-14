import BirdFlowCore
import BirdFlowMetal
import Foundation

private struct Arguments {
    var steps = 256
    var reportEvery = 32
    var freeFlight = false
    var reynolds: Float = 2_000
    var referenceSpeed: Float = 8
    var latticeSpeed: Float = 0.04
    var resolutionScale = 1

    init(_ values: [String]) throws {
        var index = 1
        while index < values.count {
            switch values[index] {
            case "--steps":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 0 else {
                    throw CLIError.invalidArgument(
                        "--steps requires a non-negative integer"
                    )
                }
                steps = value
            case "--report-every":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--report-every requires a positive integer"
                    )
                }
                reportEvery = value
            case "--free-flight":
                freeFlight = true
            case "--reynolds":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--reynolds requires a positive number"
                    )
                }
                reynolds = value
            case "--reference-speed":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--reference-speed requires a positive number"
                    )
                }
                referenceSpeed = value
            case "--lattice-speed":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--lattice-speed requires a positive number"
                    )
                }
                latticeSpeed = value
            case "--resolution-scale":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--resolution-scale requires a positive integer"
                    )
                }
                resolutionScale = value
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown option: \(values[index])"
                )
            }
            index += 1
        }
    }

    static let help = """
    birdflow [options]

      --steps N              Coupled fluid/body steps (default: 256)
      --report-every N       CSV reporting interval (default: 32)
      --free-flight          Integrate the bird's six-degree-of-freedom body
      --reynolds VALUE       Demonstration Reynolds number (default: 2000)
      --reference-speed MPS  Physical reference speed (default: 8)
      --lattice-speed VALUE  Lattice reference velocity (default: 0.04)
      --resolution-scale N   Scale grid, chord cells, and sponge together
      --help                 Show this help

    Canonical GPU validation:
      birdflow validate shear-wave [--resolution N] [--json]
      birdflow validate moving-wall [--resolution N] [--json]
      birdflow validate sphere [--resolution N] [--json]
      birdflow validate wing [--resolution N] [--json]
      birdflow validate flapping-wing [--chord-cells N] [--json]
    """
}

private struct ShearWaveArguments {
    var finestResolution = 32
    var finestSteps = 120
    var viscosity: Float = 0.03
    var amplitude: Float = 0.01
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--resolution":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 32 else {
                    throw CLIError.invalidArgument(
                        "--resolution requires an integer of at least 32"
                    )
                }
                finestResolution = value
            case "--steps":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 16 else {
                    throw CLIError.invalidArgument(
                        "--steps requires an integer of at least 16"
                    )
                }
                finestSteps = value
            case "--viscosity":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--viscosity requires a positive number"
                    )
                }
                viscosity = value
            case "--amplitude":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--amplitude requires a positive number"
                    )
                }
                amplitude = value
            case "--json":
                json = true
            case "--archive":
                index += 1
                guard index < values.count, !values[index].isEmpty else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output directory"
                    )
                }
                archivePath = values[index]
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown shear-wave option: \(values[index])"
                )
            }
            index += 1
        }
    }

    static let help = """
    birdflow validate shear-wave [options]

      --resolution N       Finest cubic grid (default: 32, minimum: 32)
      --steps N            Finest-grid steps (default: 120, minimum: 16)
      --viscosity VALUE    Lattice kinematic viscosity (default: 0.03)
      --amplitude VALUE    Initial lattice velocity amplitude (default: 0.01)
      --json               Emit the machine-readable validation report
      --archive DIRECTORY  Save report.json and final Float32 fields
      --help               Show this help

    The command runs a three-grid refinement ladder, an eight-step
    cell-by-cell CPU comparison, and a command-buffer batch-invariance check
    against the production stepFluidTRT Metal kernel.
    """
}

private struct MovingWallArguments {
    var finestResolution = 32
    var viscosity: Float = 0.1
    var amplitude: Float = 0.01
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--resolution":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 32 else {
                    throw CLIError.invalidArgument(
                        "--resolution requires an integer of at least 32"
                    )
                }
                finestResolution = value
            case "--viscosity":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--viscosity requires a positive number"
                    )
                }
                viscosity = value
            case "--amplitude":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--amplitude requires a positive number"
                    )
                }
                amplitude = value
            case "--json":
                json = true
            case "--archive":
                index += 1
                guard index < values.count, !values[index].isEmpty else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output directory"
                    )
                }
                archivePath = values[index]
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown moving-wall option: \(values[index])"
                )
            }
            index += 1
        }
    }

    static let help = """
    birdflow validate moving-wall [options]

      --resolution N       Finest cubic grid (default: 32, minimum: 32)
      --viscosity VALUE    Lattice kinematic viscosity (default: 0.1)
      --amplitude VALUE    Wall lattice velocity amplitude (default: 0.01)
      --json               Emit the machine-readable validation report
      --archive DIRECTORY  Save report.json and final Float32 fields
      --help               Show this help

    The command runs transient translating-wall Couette flow and a finite-gap
    oscillating Stokes layer on three grids. It checks profiles, no-penetration,
    isolated top-wall momentum-exchange force, force phase, convergence, and
    dynamic-wall command-buffer batch invariance.
    """
}

private struct SphereArguments {
    var finestResolution = 160
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--resolution":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 160,
                      value.isMultiple(of: 40) else {
                    throw CLIError.invalidArgument(
                        "--resolution requires a multiple of 40 of at least 160"
                    )
                }
                finestResolution = value
            case "--json":
                json = true
            case "--archive":
                index += 1
                guard index < values.count, !values[index].isEmpty else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output directory"
                    )
                }
                archivePath = values[index]
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown sphere option: \(values[index])"
                )
            }
            index += 1
        }
    }

    static let help = """
    birdflow validate sphere [options]

      --resolution N       Finest streamwise grid (default: 160; multiple of 40)
      --json               Emit the machine-readable validation report
      --archive DIRECTORY  Save report.json and final Float32 fields
      --help               Show this help

    The command runs Re=100 flow around a fixed voxelized sphere on a
    geometrically similar 80/120/160 streamwise grid ladder in 10D x 6D x 6D
    domains. It checks steady drag against
    the published Cd=1.09 reference, refinement change, force/field symmetry,
    torque leakage, and command-buffer batch invariance. The compact box is an
    engineering gate, not a publication-grade drag calculation.
    """
}

private struct WingArguments {
    var finestResolution = 400
    var singleResolution: Int?
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--resolution":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 400,
                      value.isMultiple(of: 200) else {
                    throw CLIError.invalidArgument(
                        "--resolution requires a multiple of 200 of at least 400"
                    )
                }
                finestResolution = value
            case "--single-resolution":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 80,
                      value.isMultiple(of: 10) else {
                    throw CLIError.invalidArgument(
                        "--single-resolution requires a multiple of 10 of at least 80"
                    )
                }
                singleResolution = value
            case "--json":
                json = true
            case "--archive":
                index += 1
                guard index < values.count, !values[index].isEmpty else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output directory"
                    )
                }
                archivePath = values[index]
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown wing option: \(values[index])"
                )
            }
            index += 1
        }
    }

    static let help = """
    birdflow validate wing [options]

      --resolution N       Finest streamwise grid (default: 400; multiple of 200)
      --single-resolution N
                           Run one diagnostic grid without a pass/fail verdict
      --json               Emit machine-readable JSON
      --archive DIRECTORY  Save JSON metadata and final Float32 fields
      --help               Show this help

    The command runs an AR=2 rectangular plate at Re=100 and alpha=30 degrees
    through U*t/c=13 on a 240/320/400 streamwise grid ladder. It checks lift,
    drag, span symmetry, side force, roll/yaw moment leakage,
    refinement, and command-buffer batch invariance against the production
    fluid and momentum-exchange kernels.
    """
}

private struct FlappingWingArguments {
    var finestChordCells = 16
    var singleChordCells: Int?
    var cycles = 5
    var auditInputs = false
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--chord-cells":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 16,
                      value.isMultiple(of: 8) else {
                    throw CLIError.invalidArgument(
                        "--chord-cells requires a multiple of 8 of at least 16"
                    )
                }
                finestChordCells = value
            case "--single-chord-cells":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 8 else {
                    throw CLIError.invalidArgument(
                        "--single-chord-cells requires an integer of at least 8"
                    )
                }
                singleChordCells = value
            case "--cycles":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 1 else {
                    throw CLIError.invalidArgument(
                        "--cycles requires a positive integer"
                    )
                }
                cycles = value
            case "--audit-inputs":
                auditInputs = true
            case "--json":
                json = true
            case "--archive":
                index += 1
                guard index < values.count, !values[index].isEmpty else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output directory"
                    )
                }
                archivePath = values[index]
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown flapping-wing option: \(values[index])"
                )
            }
            index += 1
        }
    }

    static let help = """
    birdflow validate flapping-wing [options]

      --chord-cells N          Finest chord grid (default: 16; multiple of 8)
      --single-chord-cells N   Run one diagnostic grid without a verdict
      --cycles N               Diagnostic cycles (default: 5)
      --audit-inputs           Compare analytic inputs with Metal voxelization
      --json                   Emit machine-readable JSON
      --archive DIRECTORY      Save loads and phase Q/vorticity fields
      --help                   Show this help

    The release command reproduces the published Li--Nabawy Re=100, AR=3
    prescribed hovering-wing baseline on 8/12/16 cells per chord. It checks
    fifth-cycle mean and phase-resolved loads, half-stroke symmetry,
    cycle periodicity, refinement, batch invariance, and vortex-phase archive
    coverage against the production moving-boundary and fluid kernels.
    """
}

private enum CLIError: Error, CustomStringConvertible {
    case invalidArgument(String)

    var description: String {
        switch self {
        case .invalidArgument(let message): return message
        }
    }
}

private func makeConfiguration(
    arguments: Arguments
) throws -> SimulationConfiguration {
    let scale = arguments.resolutionScale
    let (gridX, overflowX) = 96.multipliedReportingOverflow(by: scale)
    let (gridY, overflowY) = 112.multipliedReportingOverflow(by: scale)
    let (gridZ, overflowZ) = 96.multipliedReportingOverflow(by: scale)
    let (chordCells, overflowChord) = 12.multipliedReportingOverflow(by: scale)
    let (spongeCells, overflowSponge) = 8.multipliedReportingOverflow(by: scale)
    guard !overflowX,
          !overflowY,
          !overflowZ,
          !overflowChord,
          !overflowSponge else {
        throw CLIError.invalidArgument("--resolution-scale is too large")
    }

    let grid = try GridSize(x: gridX, y: gridY, z: gridZ)
    let scaling = try LatticeScaling(
        characteristicLengthMeters: BirdParameters.demonstration.wingRootChordMeters,
        characteristicLengthCells: chordCells,
        referenceSpeedMetersPerSecond: arguments.referenceSpeed,
        targetReynoldsNumber: arguments.reynolds,
        physicalAirDensity: 1.225,
        latticeReferenceSpeed: arguments.latticeSpeed
    )

    let farField = arguments.freeFlight
        ? SIMD3<Float>.zero
        : SIMD3<Float>(-arguments.referenceSpeed, 0, 0)

    return try SimulationConfiguration(
        grid: grid,
        domainOriginMeters: .zero,
        scaling: scaling,
        physicalAirDensity: 1.225,
        farFieldVelocityMetersPerSecond: farField,
        spongeWidthCells: spongeCells,
        spongeStrength: 0.06,
        freeFlight: arguments.freeFlight,
        fastMath: false
    )
}

private func csv(_ snapshot: SimulationSnapshot) -> String {
    let p = snapshot.body.positionMeters
    let v = snapshot.body.linearVelocityMetersPerSecond
    let f = snapshot.aerodynamicLoad.forceNewtons
    let t = snapshot.aerodynamicLoad.torqueNewtonMeters
    return [
        String(snapshot.step), String(snapshot.timeSeconds),
        String(p.x), String(p.y), String(p.z),
        String(v.x), String(v.y), String(v.z),
        String(f.x), String(f.y), String(f.z),
        String(t.x), String(t.y), String(t.z)
    ].joined(separator: ",")
}

private func runBirdSimulation(_ values: [String]) throws {
    let arguments = try Arguments(values)
    let configuration = try makeConfiguration(arguments: arguments)
    let bird = BirdParameters.demonstration
    let center = configuration.domainOriginMeters
        + configuration.domainSizeMeters * 0.5
    let initialState = BirdBodyState(
        positionMeters: center,
        linearVelocityMetersPerSecond: arguments.freeFlight
            ? SIMD3<Float>(arguments.referenceSpeed, 0, 0)
            : .zero
    )

    let simulation = try BirdFlowSimulation(
        configuration: configuration,
        bird: bird,
        initialBodyState: initialState
    )

    print("step,time_s,px_m,py_m,pz_m,vx_mps,vy_mps,vz_mps,fx_N,fy_N,fz_N,tx_Nm,ty_Nm,tz_Nm")
    print(csv(try simulation.snapshot()))

    var remaining = arguments.steps
    while remaining > 0 {
        let count = min(arguments.reportEvery, remaining)
        try simulation.advance(steps: count, batchSize: min(32, count))
        print(csv(try simulation.snapshot()))
        remaining -= count
    }
}

private func printShearWaveReport(
    _ report: MetalShearWaveValidationReport
) {
    print("production_kernel: \(report.productionKernel)")
    print("device: \(report.deviceName)")
    for result in report.cases {
        print(
            "resolution=\(result.resolution) steps=\(result.steps) "
                + "decay_error=\(result.relativeDecayError) "
                + "mass_drift=\(result.relativeMassDrift)"
        )
    }
    print("estimated_order: \(report.estimatedOrder)")
    print(
        "maximum_population_difference_from_cpu: "
            + String(report.maximumPopulationDifferenceFromCPU)
    )
    print(
        "maximum_batch_density_difference: "
            + String(report.maximumBatchDensityDifference)
    )
    print(
        "maximum_batch_velocity_difference: "
            + String(report.maximumBatchVelocityDifference)
    )
    print("passed: \(report.passed)")
}

private func runShearWaveValidation(_ values: [String]) throws {
    let arguments = try ShearWaveArguments(values)
    let report = try MetalShearWaveValidator.run(
        finestResolution: arguments.finestResolution,
        finestSteps: arguments.finestSteps,
        viscosity: arguments.viscosity,
        initialAmplitude: arguments.amplitude,
        archiveDirectory: arguments.archivePath.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )
    if arguments.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        printShearWaveReport(report)
    }
    guard report.passed else {
        throw MetalShearWaveValidationError.failed(
            "one or more numerical acceptance gates were exceeded"
        )
    }
}

private func runMovingWallValidation(_ values: [String]) throws {
    let arguments = try MovingWallArguments(values)
    let report = try MetalMovingWallValidator.run(
        finestResolution: arguments.finestResolution,
        viscosity: arguments.viscosity,
        wallVelocityAmplitude: arguments.amplitude,
        archiveDirectory: arguments.archivePath.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )
    if arguments.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        print("production_kernel: \(report.productionKernel)")
        print("device: \(report.deviceName)")
        print(
            "couette_profile_order: "
                + String(report.couetteProfileConvergenceOrder)
        )
        print(
            "couette_force_order: "
                + String(report.couetteForceConvergenceOrder)
        )
        print(
            "oscillating_profile_order: "
                + String(report.oscillatingProfileConvergenceOrder)
        )
        print(
            "oscillating_force_order: "
                + String(report.oscillatingForceConvergenceOrder)
        )
        print("passed: \(report.passed)")
    }
    guard report.passed else {
        throw MetalMovingWallValidationError.failed(
            "one or more moving-wall acceptance gates were exceeded"
        )
    }
}

private func runSphereValidation(_ values: [String]) throws {
    let arguments = try SphereArguments(values)
    let report = try MetalSphereValidator.run(
        finestResolution: arguments.finestResolution,
        archiveDirectory: arguments.archivePath.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )
    if arguments.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        print("production_kernel: \(report.productionKernel)")
        print("device: \(report.deviceName)")
        for result in report.cases {
            print(
                "resolution=\(result.resolution) "
                    + "diameter=\(result.diameterCells) "
                    + "steps=\(result.steps) "
                    + "Cd=\(result.dragCoefficient) "
                    + "drag_error=\(result.relativeDragError) "
                    + "steady_range=\(result.steadyWindowRelativeRange)"
            )
        }
        print(
            "finest_two_drag_change: "
                + String(report.relativeFinestTwoDragChange)
        )
        print("passed: \(report.passed)")
    }
    guard report.passed else {
        throw MetalSphereValidationError.failed(
            "one or more fixed-sphere acceptance gates were exceeded"
        )
    }
}

private func runWingValidation(_ values: [String]) throws {
    let arguments = try WingArguments(values)
    if let resolution = arguments.singleResolution {
        let result = try MetalWingValidator.runSingleCase(
            resolution: resolution,
            archiveDirectory: arguments.archivePath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
        )
        if arguments.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(result), as: UTF8.self))
        } else {
            print("diagnostic_only: true")
            print(
                "resolution=\(result.resolution) "
                    + "chord=\(result.chordCells) "
                    + "steps=\(result.steps) "
                    + "CL=\(result.liftCoefficient) "
                    + "CD=\(result.dragCoefficient)"
            )
        }
        return
    }
    let report = try MetalWingValidator.run(
        finestResolution: arguments.finestResolution,
        archiveDirectory: arguments.archivePath.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )
    if arguments.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        print("production_kernel: \(report.productionKernel)")
        print("device: \(report.deviceName)")
        for result in report.cases {
            print(
                "resolution=\(result.resolution) "
                    + "chord=\(result.chordCells) "
                    + "steps=\(result.steps) "
                    + "CL=\(result.liftCoefficient) "
                    + "CD=\(result.dragCoefficient)"
            )
        }
        print(
            "finest_two_lift_change: "
                + String(report.relativeFinestTwoLiftChange)
        )
        print(
            "finest_two_drag_change: "
                + String(report.relativeFinestTwoDragChange)
        )
        print("passed: \(report.passed)")
    }
    guard report.passed else {
        throw MetalWingValidationError.failed(
            "one or more fixed-wing acceptance gates were exceeded"
        )
    }
}

private func printFlappingWingInputAudit(
    _ audit: MetalFlappingWingInputAudit
) {
    print("chord_cells: \(audit.chordCells)")
    print("analytic_inputs_passed: \(audit.analyticInputsPassed)")
    for result in audit.geometry {
        print(
            "phase=\(result.phase) "
                + "cpu_cells=\(result.analyticSolidCellCount) "
                + "metal_cells=\(result.metalSolidCellCount) "
                + "regularized_volume_ratio="
                + String(result.normalizedVoxelVolume) + " "
                + "published_volume_ratio="
                + String(result.normalizedPublishedThicknessVoxelVolume)
                + " mismatch=\(result.mismatchedCellFraction)"
        )
    }
    print("metal_geometry_passed: \(audit.metalGeometryPassed)")
    print("passed: \(audit.passed)")
}

private func runFlappingWingValidation(_ values: [String]) throws {
    let arguments = try FlappingWingArguments(values)
    let archive = arguments.archivePath.map {
        URL(fileURLWithPath: $0, isDirectory: true)
    }
    if arguments.auditInputs {
        if let chord = arguments.singleChordCells {
            let audit = try MetalFlappingWingValidator.auditInputs(
                chordCells: chord
            )
            if arguments.json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(audit), as: UTF8.self))
            } else {
                print("device: \(audit.deviceName)")
                printFlappingWingInputAudit(audit)
            }
            guard audit.passed else {
                throw MetalFlappingWingValidationError.failed(
                    "analytic-to-Metal input preflight exceeded its locked gates"
                )
            }
        } else {
            let report = try MetalFlappingWingValidator.auditInputLadder(
                finestChordCells: arguments.finestChordCells
            )
            if arguments.json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(report), as: UTF8.self))
            } else {
                print("device: \(report.deviceName)")
                for audit in report.cases {
                    printFlappingWingInputAudit(audit)
                }
                print("ladder_passed: \(report.passed)")
            }
            guard report.passed else {
                throw MetalFlappingWingValidationError.failed(
                    "analytic-to-Metal input ladder exceeded its locked gates"
                )
            }
        }
        return
    }
    if let chord = arguments.singleChordCells {
        let result = try MetalFlappingWingValidator.runSingleCase(
            chordCells: chord,
            cycles: arguments.cycles,
            archiveDirectory: archive
        )
        if arguments.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(result), as: UTF8.self))
        } else {
            print("diagnostic_only: true")
            print("source_doi: \(MetalFlappingWingValidator.sourceDOI)")
            print(
                "chord=\(result.chordCells) cycles=\(result.cycles) "
                    + "steps=\(result.steps) "
                    + "mean_CL=\(result.meanLiftCoefficient) "
                    + "mean_CD=\(result.meanDragCoefficient) "
                    + "cycle_difference=\(result.previousCycleDifference)"
            )
        }
        return
    }
    let report = try MetalFlappingWingValidator.run(
        finestChordCells: arguments.finestChordCells,
        archiveDirectory: archive
    )
    if arguments.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        print("production_kernel: \(report.productionKernel)")
        print("geometry_kernel: \(report.geometryKernel)")
        print("device: \(report.deviceName)")
        for result in report.cases {
            print(
                "chord=\(result.chordCells) steps=\(result.steps) "
                    + "mean_CL=\(result.meanLiftCoefficient) "
                    + "mean_CD=\(result.meanDragCoefficient) "
                    + "symmetry=\(result.halfStrokeSymmetryError)"
            )
        }
        print("passed: \(report.passed)")
    }
    guard report.passed else {
        throw MetalFlappingWingValidationError.failed(
            "one or more published flapping-wing gates were exceeded"
        )
    }
}

private func run(_ values: [String]) throws {
    if values.count > 1, values[1] == "validate" {
        guard values.count > 2 else {
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall|sphere|wing|flapping-wing> [options]"
            )
        }
        switch values[2] {
        case "shear-wave":
            try runShearWaveValidation(values)
        case "moving-wall":
            try runMovingWallValidation(values)
        case "sphere":
            try runSphereValidation(values)
        case "wing":
            try runWingValidation(values)
        case "flapping-wing":
            try runFlappingWingValidation(values)
        default:
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall|sphere|wing|flapping-wing> [options]"
            )
        }
    } else {
        try runBirdSimulation(values)
    }
}

do {
    try run(CommandLine.arguments)
} catch {
    let message = "birdflow: \(error)\n"
    FileHandle.standardError.write(Data(message.utf8))
    Foundation.exit(EXIT_FAILURE)
}

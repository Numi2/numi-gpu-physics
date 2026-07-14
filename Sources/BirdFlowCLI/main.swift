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

private func run(_ values: [String]) throws {
    if values.count > 1, values[1] == "validate" {
        guard values.count > 2 else {
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall> [options]"
            )
        }
        switch values[2] {
        case "shear-wave":
            try runShearWaveValidation(values)
        case "moving-wall":
            try runMovingWallValidation(values)
        default:
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall> [options]"
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

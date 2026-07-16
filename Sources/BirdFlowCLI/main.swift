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
    var bodySubsteps = 1

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
            case "--body-substeps":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      (1...64).contains(value) else {
                    throw CLIError.invalidArgument(
                        "--body-substeps requires an integer in 1...64"
                    )
                }
                bodySubsteps = value
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
      --body-substeps N      Refine only the six-DOF integrator (1...64)
      --help                 Show this help

    Canonical GPU validation:
      birdflow validate shear-wave [--resolution N] [--json]
      birdflow validate moving-wall [--resolution N] [--json]
      birdflow validate translating-body [--high-re-stability] [--fixed-occupancy] [--decompose-wall-velocity | --stationary-wall [--relaxation-sweep | --long-horizon-survival | --population-positivity | --trt-collision-decomposition | --symmetric-limiter-ab]] [--archive FILE] [--json]
      birdflow validate sphere [--resolution N] [--json]
      birdflow validate wing [--resolution N] [--json]
      birdflow validate flapping-wing [--chord-cells N] [--json]
      birdflow validate flapping-wing --decompose-loads [--json]
      birdflow validate flapping-wing --compare-link-forces [--json]
      birdflow validate flapping-wing --decompose-link-numerator [--json]
      birdflow validate flapping-wing --momentum-budget [--json]

    Measured prescribed replay:
      birdflow replay measured-bird --input DATASET.json [--audit-only] [--json]
      birdflow replay measured-wing --input SURFACE.json [--fluid-cycle] [--json]
      birdflow replay measured-bird-surface --input MANIFEST.json [--coupling-gate] [--archive FILE] [--json]
    """
}

private struct MeasuredBirdSurfaceReplayArguments {
    var inputPath: String?
    var archivePath: String?
    var cellSizeMeters: Float = 0.01
    var halfThicknessCells: Float = 0.75
    var couplingGate = false
    var json = false

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--input":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--input requires an indexed surface manifest path"
                    )
                }
                inputPath = values[index]
            case "--archive":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output JSON path"
                    )
                }
                archivePath = values[index]
            case "--cell-size-meters":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value.isFinite,
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--cell-size-meters requires a positive finite value"
                    )
                }
                cellSizeMeters = value
            case "--half-thickness-cells":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      (0.5...2).contains(value) else {
                    throw CLIError.invalidArgument(
                        "--half-thickness-cells requires a value in [0.5, 2]"
                    )
                }
                halfThicknessCells = value
            case "--coupling-gate":
                couplingGate = true
            case "--json":
                json = true
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown measured-bird-surface replay option: \(values[index])"
                )
            }
            index += 1
        }
        guard inputPath != nil else {
            throw CLIError.invalidArgument(
                "measured-bird-surface replay requires --input MANIFEST.json"
            )
        }
    }

    static let help = """
    birdflow replay measured-bird-surface --input MANIFEST.json [options]

      --cell-size-meters V      Geometry-audit cell size (default: 0.01)
      --half-thickness-cells V  Sheet half-thickness (default: 0.75)
      --coupling-gate            Run the short production fluid/impulse gate
      --archive FILE            Atomically archive the parity report as JSON
      --json                    Emit the machine-readable parity report
    """
}

private struct MeasuredWingReplayArguments {
    var inputPath: String?
    var chordCells = 8
    var halfThicknessCells: Float = 0.75
    var fluidCycle = false
    var thicknessLadder = false
    var stationarity = false
    var publishedCondition = false
    var json = false

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--input":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--input requires a measured-wing surface JSON path"
                    )
                }
                inputPath = values[index]
            case "--chord-cells":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]), value >= 8 else {
                    throw CLIError.invalidArgument(
                        "--chord-cells requires an integer of at least 8"
                    )
                }
                chordCells = value
            case "--half-thickness-cells":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      (0.5...2).contains(value) else {
                    throw CLIError.invalidArgument(
                        "--half-thickness-cells requires a value in [0.5, 2]"
                    )
                }
                halfThicknessCells = value
            case "--fluid-cycle":
                fluidCycle = true
            case "--thickness-ladder":
                thicknessLadder = true
            case "--stationarity":
                stationarity = true
            case "--published-condition":
                publishedCondition = true
            case "--json":
                json = true
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown measured-wing replay option: \(values[index])"
                )
            }
            index += 1
        }
        guard inputPath != nil else {
            throw CLIError.invalidArgument(
                "measured-wing replay requires --input SURFACE.json"
            )
        }
        if thicknessLadder && fluidCycle {
            throw CLIError.invalidArgument(
                "--thickness-ladder already runs fluid cycles and cannot be combined with --fluid-cycle"
            )
        }
        if stationarity && (fluidCycle || thicknessLadder) {
            throw CLIError.invalidArgument(
                "--stationarity cannot be combined with --fluid-cycle or --thickness-ladder"
            )
        }
        if thicknessLadder && halfThicknessCells != 0.75 {
            throw CLIError.invalidArgument(
                "--thickness-ladder uses fixed 0.5/0.75/1.0 cases and cannot be combined with --half-thickness-cells"
            )
        }
        if publishedCondition && (thicknessLadder || stationarity) {
            throw CLIError.invalidArgument(
                "--published-condition is a one-cycle feasibility gate and cannot be combined with --thickness-ladder or --stationarity"
            )
        }
        if publishedCondition {
            fluidCycle = true
        }
    }

    static let help = """
    birdflow replay measured-wing --input SURFACE.json [options]

      --chord-cells N          Mean-chord resolution (default: 8; minimum: 8)
      --half-thickness-cells V Numerical sheet half-thickness (default: 0.75)
      --fluid-cycle            Also run one startup cycle through stepFluidTRT
      --thickness-ladder       Run 0.5/0.75/1.0-cell fluid sensitivity gate
      --stationarity           Run five cycles and compare cycles four/five
      --published-condition    Run one cycle at Dong et al. Re=9367.4,
                               rho=1.205 kg/m^3 instead of diagnostic Re=100
      --json                   Emit the machine-readable replay report
      --help                   Show this help

    Geometry-only mode audits every measured source phase. --fluid-cycle is a
    transient engineering diagnostic, not complete-bird or quantitative force
    acceptance. --published-condition is a local numerical-stability gate, not
    a measured greenhouse condition. The thickness ladder applies a 5% full-
    envelope criterion.
    """
}

private struct MeasuredBirdReplayArguments {
    var inputPath: String?
    var chordCells = 12
    var cycles: Float = 1
    var steps: Int?
    var batchSize = 32
    var archivePath: String?
    var auditOnly = false
    var freeFlight = false
    var bodySubsteps = 1
    var bodyRefinement = false
    var loadRefinement = false
    var trimSearch = false
    var trimIterations = 2
    var trimScreeningCycles: Float = 2
    var trimConfirmationCycles: Float = 5
    var freeFlightConfirmation = false
    var confirmationMainCycles: Float = 5
    var confirmationLedgerCycles: Float = 1
    var confirmationRefinementCycles: Float = 1
    var momentumLedger = false
    var partLoads = false
    var expectBilateralSymmetry = false
    var json = false
    var cyclesCustomized = false
    var trimOptionsCustomized = false
    var confirmationOptionsCustomized = false

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--input":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--input requires a measured-bird JSON path"
                    )
                }
                inputPath = values[index]
            case "--chord-cells":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value >= 8 else {
                    throw CLIError.invalidArgument(
                        "--chord-cells requires an integer of at least 8"
                    )
                }
                chordCells = value
            case "--cycles":
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--cycles requires a positive number"
                    )
                }
                cycles = value
                cyclesCustomized = true
            case "--steps":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--steps requires a positive integer"
                    )
                }
                steps = value
            case "--batch-size":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      value > 0 else {
                    throw CLIError.invalidArgument(
                        "--batch-size requires a positive integer"
                    )
                }
                batchSize = value
            case "--archive":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output directory"
                    )
                }
                archivePath = values[index]
            case "--audit-only":
                auditOnly = true
            case "--free-flight":
                freeFlight = true
            case "--body-substeps":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      (1...64).contains(value) else {
                    throw CLIError.invalidArgument(
                        "--body-substeps requires an integer in 1...64"
                    )
                }
                bodySubsteps = value
            case "--body-refinement":
                bodyRefinement = true
                freeFlight = true
            case "--load-refinement":
                loadRefinement = true
            case "--trim-search":
                trimSearch = true
            case "--trim-iterations":
                trimOptionsCustomized = true
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      (1...6).contains(value) else {
                    throw CLIError.invalidArgument(
                        "--trim-iterations requires an integer in 1...6"
                    )
                }
                trimIterations = value
            case "--trim-screening-cycles":
                trimOptionsCustomized = true
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value >= 2 else {
                    throw CLIError.invalidArgument(
                        "--trim-screening-cycles requires a value of at least 2"
                    )
                }
                trimScreeningCycles = value
            case "--trim-confirmation-cycles":
                trimOptionsCustomized = true
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value >= 5 else {
                    throw CLIError.invalidArgument(
                        "--trim-confirmation-cycles requires a value of at least 5"
                    )
                }
                trimConfirmationCycles = value
            case "--free-flight-confirmation":
                freeFlightConfirmation = true
            case "--confirmation-main-cycles":
                confirmationOptionsCustomized = true
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value >= 5 else {
                    throw CLIError.invalidArgument(
                        "--confirmation-main-cycles requires a value of at least 5"
                    )
                }
                confirmationMainCycles = value
            case "--confirmation-ledger-cycles":
                confirmationOptionsCustomized = true
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value >= 1 else {
                    throw CLIError.invalidArgument(
                        "--confirmation-ledger-cycles requires a value of at least 1"
                    )
                }
                confirmationLedgerCycles = value
            case "--confirmation-refinement-cycles":
                confirmationOptionsCustomized = true
                index += 1
                guard index < values.count,
                      let value = Float(values[index]),
                      value >= 1 else {
                    throw CLIError.invalidArgument(
                        "--confirmation-refinement-cycles requires a value of at least 1"
                    )
                }
                confirmationRefinementCycles = value
            case "--momentum-ledger":
                momentumLedger = true
                freeFlight = true
            case "--part-loads":
                partLoads = true
                momentumLedger = true
                freeFlight = true
            case "--expect-bilateral-symmetry":
                expectBilateralSymmetry = true
                partLoads = true
                momentumLedger = true
                freeFlight = true
            case "--json":
                json = true
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown measured-bird replay option: \(values[index])"
                )
            }
            index += 1
        }
        guard inputPath != nil else {
            throw CLIError.invalidArgument(
                "measured-bird replay requires --input DATASET.json"
            )
        }
        if auditOnly, archivePath != nil {
            throw CLIError.invalidArgument(
                "--audit-only cannot be combined with --archive"
            )
        }
        if bodyRefinement && steps == nil {
            throw CLIError.invalidArgument(
                "--body-refinement requires --steps N so all substep cases have identical duration"
            )
        }
        if bodyRefinement && loadRefinement {
            throw CLIError.invalidArgument(
                "--body-refinement and --load-refinement are separate controlled experiments"
            )
        }
        if trimSearch
            && (freeFlight || freeFlightConfirmation || bodyRefinement
                || loadRefinement
                || momentumLedger || steps != nil || bodySubsteps != 1
                || cycles != 1) {
            throw CLIError.invalidArgument(
                "--trim-search controls its own duration and is incompatible with --cycles, --steps, --body-substeps, free-flight, refinement, or momentum-ledger modes"
            )
        }
        if confirmationOptionsCustomized && !freeFlightConfirmation {
            throw CLIError.invalidArgument(
                "--confirmation-*-cycles options require --free-flight-confirmation"
            )
        }
        if freeFlightConfirmation
            && (auditOnly || freeFlight || bodyRefinement || loadRefinement
                || trimSearch || trimOptionsCustomized || momentumLedger
                || partLoads || expectBilateralSymmetry || steps != nil
                || bodySubsteps != 1 || cyclesCustomized) {
            throw CLIError.invalidArgument(
                "--free-flight-confirmation controls its own independent "
                    + "main, refinement, and ledger runs and cannot be "
                    + "combined with another execution mode or duration"
            )
        }
        if momentumLedger && (bodyRefinement || loadRefinement) {
            throw CLIError.invalidArgument(
                "--momentum-ledger is a single-run gate and cannot be combined with refinement ladders"
            )
        }
        if (bodyRefinement || loadRefinement), archivePath != nil {
            throw CLIError.invalidArgument(
                "refinement reports cannot use the single-run --archive path"
            )
        }
        if auditOnly
            && (freeFlight || bodyRefinement || loadRefinement
                || trimSearch) {
            throw CLIError.invalidArgument(
                "--audit-only cannot be combined with execution modes"
            )
        }
    }

    static let help = """
    birdflow replay measured-bird --input DATASET.json [options]

      --audit-only       Validate schema, provenance, units, frame, grid, and Mach without starting Metal
      --chord-cells N    Root-chord resolution (default: 12; minimum: 8)
      --cycles VALUE     Prescribed cycles when --steps is absent (default: 1)
      --steps N          Explicit fluid-step count
      --batch-size N     Command-buffer batch size (default: 32)
      --free-flight      Enable six-DOF motion; requires schema 2 wing inertia
      --body-substeps N  Rigid-body-only substeps per fluid step (1...64)
      --body-refinement  Run locked 1/2/4 body-substep ladder; requires --steps
      --load-refinement  Run five-cycle prescribed 8/12/16 load ladder
      --trim-search      Search bounded body pitch/airspeed for prescribed force/moment balance
      --trim-iterations N
                         Gauss-Newton updates for trim search (default: 2; range: 1...6)
      --trim-screening-cycles VALUE
                         Cycles per trim candidate (default/minimum: 2)
      --trim-confirmation-cycles VALUE
                         Cycles for the selected candidate (default/minimum: 5)
      --free-flight-confirmation
                         Run independent bounded-flight, 1/2/4 body-step,
                         and coupled momentum/load closure gates
      --confirmation-main-cycles VALUE
                         Bounded free-flight cycles (default/minimum: 5)
      --confirmation-ledger-cycles VALUE
                         Coupled momentum/load audit cycles (default/minimum: 1)
      --confirmation-refinement-cycles VALUE
                         Body-step refinement cycles (default/minimum: 1)
      --momentum-ledger  Record direct fluid/body/wing external impulse closure; implies --free-flight
      --part-loads       Record conservative body/wing/tail loads and wing actuator effort; implies --momentum-ledger
      --expect-bilateral-symmetry
                         Gate mirrored wing force, hinge torque, and actuator power; use only for symmetric inputs
      --archive DIR      Save exact input, SHA-linked report, and phase loads
      --json             Emit machine-readable audit or replay report
      --help             Show this help

    Schema 1 supports prescribed replay. Quantitative free flight requires
    schema 2 measured bilateral wing mass properties. Both use SI units, the COM-centered BirdFlow principal
    axes, registeredAnalyticProxyV1 geometry, and periodic left/right stroke,
    deviation, pitch, and tip-twist angles plus physical angular rates.
    """
}

private struct TranslatingBodyArguments {
    var highReStability = false
    var fixedOccupancy = false
    var decomposeWallVelocity = false
    var stationaryWall = false
    var relaxationSweep = false
    var longHorizonSurvival = false
    var populationPositivity = false
    var trtCollisionDecomposition = false
    var symmetricLimiterAB = false
    var geometricLimiterLadder = false
    var recursiveRegularizationLadder = false
    var recursiveRegularizationDuration = false
    var radialLimiterLocalization = false
    var bulkCollisionOperatorAB = false
    var recursiveRegularizationAB = false
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--high-re-stability":
                highReStability = true
            case "--fixed-occupancy":
                fixedOccupancy = true
            case "--decompose-wall-velocity":
                decomposeWallVelocity = true
            case "--stationary-wall":
                stationaryWall = true
            case "--relaxation-sweep":
                relaxationSweep = true
            case "--long-horizon-survival":
                longHorizonSurvival = true
            case "--population-positivity":
                populationPositivity = true
            case "--trt-collision-decomposition":
                trtCollisionDecomposition = true
            case "--symmetric-limiter-ab":
                symmetricLimiterAB = true
            case "--geometric-limiter-ladder":
                geometricLimiterLadder = true
            case "--recursive-regularization-ladder":
                recursiveRegularizationLadder = true
            case "--recursive-regularization-duration":
                recursiveRegularizationDuration = true
            case "--radial-limiter-localization":
                radialLimiterLocalization = true
            case "--bulk-collision-operator-ab":
                bulkCollisionOperatorAB = true
            case "--recursive-regularization-ab":
                recursiveRegularizationAB = true
            case "--archive":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output JSON file"
                    )
                }
                archivePath = values[index]
            case "--json":
                json = true
            case "--help", "-h":
                print(Self.help)
                Foundation.exit(EXIT_SUCCESS)
            default:
                throw CLIError.invalidArgument(
                    "Unknown translating-body option: \(values[index])"
                )
            }
            index += 1
        }
        if fixedOccupancy && !highReStability {
            throw CLIError.invalidArgument(
                "--fixed-occupancy requires --high-re-stability"
            )
        }
        if decomposeWallVelocity
            && (!highReStability || !fixedOccupancy) {
            throw CLIError.invalidArgument(
                "--decompose-wall-velocity requires --high-re-stability and --fixed-occupancy"
            )
        }
        if stationaryWall && (!highReStability || !fixedOccupancy) {
            throw CLIError.invalidArgument(
                "--stationary-wall requires --high-re-stability and --fixed-occupancy"
            )
        }
        if stationaryWall && decomposeWallVelocity {
            throw CLIError.invalidArgument(
                "--stationary-wall cannot be combined with --decompose-wall-velocity"
            )
        }
        if relaxationSweep && !stationaryWall {
            throw CLIError.invalidArgument(
                "--relaxation-sweep requires --stationary-wall"
            )
        }
        if longHorizonSurvival && !stationaryWall {
            throw CLIError.invalidArgument(
                "--long-horizon-survival requires --stationary-wall"
            )
        }
        if populationPositivity && !stationaryWall {
            throw CLIError.invalidArgument(
                "--population-positivity requires --stationary-wall"
            )
        }
        if trtCollisionDecomposition && !stationaryWall {
            throw CLIError.invalidArgument(
                "--trt-collision-decomposition requires --stationary-wall"
            )
        }
        if symmetricLimiterAB && !stationaryWall {
            throw CLIError.invalidArgument(
                "--symmetric-limiter-ab requires --stationary-wall"
            )
        }
        if geometricLimiterLadder && !stationaryWall {
            throw CLIError.invalidArgument(
                "--geometric-limiter-ladder requires --stationary-wall"
            )
        }
        if recursiveRegularizationLadder && !stationaryWall {
            throw CLIError.invalidArgument(
                "--recursive-regularization-ladder requires --stationary-wall"
            )
        }
        if recursiveRegularizationDuration && !stationaryWall {
            throw CLIError.invalidArgument(
                "--recursive-regularization-duration requires --stationary-wall"
            )
        }
        if radialLimiterLocalization && !stationaryWall {
            throw CLIError.invalidArgument(
                "--radial-limiter-localization requires --stationary-wall"
            )
        }
        if bulkCollisionOperatorAB && !stationaryWall {
            throw CLIError.invalidArgument(
                "--bulk-collision-operator-ab requires --stationary-wall"
            )
        }
        if recursiveRegularizationAB && !stationaryWall {
            throw CLIError.invalidArgument(
                "--recursive-regularization-ab requires --stationary-wall"
            )
        }
        let stationaryDiagnostics = [
            relaxationSweep,
            longHorizonSurvival,
            populationPositivity,
            trtCollisionDecomposition,
            symmetricLimiterAB,
            geometricLimiterLadder,
            recursiveRegularizationLadder,
            recursiveRegularizationDuration,
            radialLimiterLocalization,
            bulkCollisionOperatorAB,
            recursiveRegularizationAB,
        ].filter { $0 }.count
        if stationaryDiagnostics > 1 {
            throw CLIError.invalidArgument(
                "stationary-wall diagnostics cannot be combined"
            )
        }
        if archivePath != nil
            && !populationPositivity
            && !trtCollisionDecomposition
            && !symmetricLimiterAB
            && !geometricLimiterLadder
            && !recursiveRegularizationLadder
            && !recursiveRegularizationDuration
            && !radialLimiterLocalization
            && !bulkCollisionOperatorAB
            && !recursiveRegularizationAB {
            throw CLIError.invalidArgument(
                "--archive requires an archive-capable stationary-wall diagnostic"
            )
        }
    }

    static let help = """
    birdflow validate translating-body [options]

      --high-re-stability  Run locked 500-step c8/c12/c16 cell-crossing cases
      --fixed-occupancy    Hold the curved sphere fixed while retaining wall speed
      --decompose-wall-velocity
                           Compare tangential-only and normal-only wall forcing
      --stationary-wall    Hold the sphere and wall fixed in uniform 0.08 flow
      --relaxation-sweep   Sweep wider tauPlus margins on the stationary sphere
      --long-horizon-survival
                           Extend apparent stable margins to 1000 steps
      --population-positivity
                           Locate the first negative/non-finite c16 population
      --trt-collision-decomposition
                           Decompose the locked step-27 c16 collision
      --symmetric-limiter-ab
                           Compare the locked c16 control and symmetric limiter
      --geometric-limiter-ladder
                           Run true D=8/12/16 source-aware sphere refinement
      --recursive-regularization-ladder
                           Run RR3 through the unchanged D=8/12/16 sphere refinement
      --recursive-regularization-duration
                           Extend only RR3 D=8/12 to ten convective times
      --radial-limiter-localization
                           Localize D=16 limiter intervention by sphere distance
      --bulk-collision-operator-ab
                           Compare limited TRT with regularized positive BGK at D=16
      --recursive-regularization-ab
                           Compare second- and recursive-third-order regularized BGK at D=16
      --archive FILE       Write the selected diagnostic to an exact JSON file
      --json               Emit the machine-readable validation report
      --help               Show this help

    The command translates a compact voxel sphere through two lattice cells
    in a periodic quiescent domain. It requires cover and uncover events, then
    closes the production boundary load against an independent fluid-momentum
    budget while comparing the legacy and conservative estimators. The high-Re
    gate uses the published-condition relaxation margins and a longer domain.
    Fixed occupancy removes only cover, uncover, and refill from that case.
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
    var highReStability = false
    var json = false
    var archivePath: String?

    init(_ values: [String]) throws {
        var index = 3
        var customizedStandardCase = false
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
                customizedStandardCase = true
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
                customizedStandardCase = true
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
                customizedStandardCase = true
            case "--high-re-stability":
                highReStability = true
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
        if highReStability && (customizedStandardCase || archivePath != nil) {
            throw CLIError.invalidArgument(
                "--high-re-stability uses a locked 16^3, 500-step contract and cannot be combined with resolution, viscosity, amplitude, or archive options"
            )
        }
    }

    static let help = """
    birdflow validate moving-wall [options]

      --resolution N       Finest cubic grid (default: 32, minimum: 32)
      --viscosity VALUE    Lattice kinematic viscosity (default: 0.1)
      --amplitude VALUE    Wall lattice velocity amplitude (default: 0.01)
      --high-re-stability  Run the locked 500-step fixed-wall cases matching
                           measured-wing c8/c12/c16 TRT relaxation margins
      --json               Emit the machine-readable validation report
      --archive DIRECTORY  Save report.json and final Float32 fields
      --help               Show this help

    The command runs transient translating-wall Couette flow and a finite-gap
    oscillating Stokes layer on three grids. It checks profiles, no-penetration,
    isolated top-wall momentum-exchange force, force phase, convergence, and
    dynamic-wall command-buffer batch invariance. The high-Re gate removes all
    cover/uncover topology changes to isolate collision stability.
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
    var decomposeLoads = false
    var compareLinkForces = false
    var decomposeLinkNumerator = false
    var diagnoseMomentumBudget = false
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
            case "--decompose-loads":
                decomposeLoads = true
            case "--compare-link-forces":
                compareLinkForces = true
            case "--decompose-link-numerator":
                decomposeLinkNumerator = true
            case "--momentum-budget":
                diagnoseMomentumBudget = true
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
      --decompose-loads        Split link and cover/uncover loads by phase
      --compare-link-forces    Compare GI and conventional link estimators
      --decompose-link-numerator
                                Split common link-force numerator terms
      --momentum-budget        Close loads against a near-wing fluid budget
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
    case acceptanceFailed(String)

    var description: String {
        switch self {
        case .invalidArgument(let message): return message
        case .acceptanceFailed(let message): return message
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
        bodySubsteps: arguments.bodySubsteps,
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

private func printJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(value), as: UTF8.self))
}

private func writeJSON<T: Encodable>(_ value: T, to path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let destination = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(
        at: destination.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try encoder.encode(value).write(to: destination, options: .atomic)
}

private func runMeasuredBirdReplay(_ values: [String]) throws {
    let arguments = try MeasuredBirdReplayArguments(values)
    let input = URL(fileURLWithPath: arguments.inputPath!)
    let loaded = try MeasuredBirdDatasetLoader.load(from: input)
    if arguments.auditOnly {
        let audit = try MeasuredBirdReplay.audit(
            loaded,
            chordCells: arguments.chordCells
        )
        if arguments.json {
            try printJSON(audit)
        } else {
            print("dataset: \(audit.datasetIdentifier)")
            print("source_sha256: \(audit.sourceSHA256)")
            print("geometry: \(audit.geometryRepresentation)")
            print("keyframes: \(audit.kinematicKeyframeCount)")
            print(
                "grid: \(audit.grid.x)x\(audit.grid.y)x\(audit.grid.z)"
            )
            print("estimated_maximum_mach: \(audit.estimatedMaximumLatticeMach)")
            print("wing_inertial_treatment: \(audit.wingInertialTreatment)")
            print(
                "quantitative_free_flight_contract_passed: "
                    + String(audit.quantitativeFreeFlightContractPassed)
            )
            print("passed: \(audit.passed)")
            print("scientific_verdict: \(audit.scientificVerdict)")
        }
        return
    }
    if arguments.freeFlightConfirmation {
        let report = try MeasuredBirdReplay.runFreeFlightConfirmation(
            loaded,
            chordCells: arguments.chordCells,
            cycles: arguments.confirmationMainCycles,
            ledgerCycles: arguments.confirmationLedgerCycles,
            bodyRefinementCycles:
                arguments.confirmationRefinementCycles,
            batchSize: arguments.batchSize,
            archiveDirectory: arguments.archivePath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
        )
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print("specimen: \(report.specimenIdentifier)")
            print("input_sha256: \(report.inputSHA256)")
            print("device: \(report.deviceName)")
            print("main_cycles: \(report.mainCycles)")
            print(
                "maximum_position_drift_chord_fraction: "
                    + String(
                        report.maximumPositionDriftChordFraction
                    )
            )
            print(
                "maximum_speed_reference_fraction: "
                    + String(report.maximumSpeedReferenceFraction)
            )
            print(
                "maximum_attitude_deviation_degrees: "
                    + String(report.maximumAttitudeDeviationDegrees)
            )
            print(
                "maximum_angular_velocity_cycle_fraction: "
                    + String(
                        report.maximumAngularVelocityCycleFraction
                    )
            )
            print(
                "body_refinement_passed: "
                    + String(report.bodyRefinement.passed)
            )
            print(
                "momentum_ledger_passed: "
                    + String(report.coupledMomentumLedger.passed)
            )
            print(
                "part_load_closure_passed: "
                    + String(report.aerodynamicPartLoads.passed)
            )
            print("passed: \(report.passed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.passed else {
            throw CLIError.acceptanceFailed(
                "bounded free-flight confirmation failed; inspect the "
                    + "archived report before making a quantitative claim"
            )
        }
        return
    }
    if arguments.bodyRefinement {
        let report = try MeasuredBirdReplay.runFreeFlightBodyRefinement(
            loaded,
            chordCells: arguments.chordCells,
            steps: arguments.steps!,
            batchSize: arguments.batchSize
        )
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print("steps: \(report.steps)")
            print(
                "fine_position_chord_fraction: "
                    + String(report.finePairPositionDifferenceChordFraction)
            )
            print(
                "fine_velocity_reference_fraction: "
                    + String(report.finePairVelocityDifferenceReferenceFraction)
            )
            print(
                "fine_orientation_difference_degrees: "
                    + String(report.finePairOrientationDifferenceDegrees)
            )
            print("passed: \(report.passed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        return
    }
    if arguments.loadRefinement {
        let report = try MeasuredBirdReplay.runLoadRefinement(
            loaded,
            cycles: max(5, arguments.cycles),
            batchSize: arguments.batchSize
        )
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print(
                "fine_force_difference_fraction: "
                    + String(report.finePairForceDifferenceFraction)
            )
            print(
                "fine_torque_difference_fraction: "
                    + String(report.finePairTorqueDifferenceFraction)
            )
            print("passed: \(report.passed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        return
    }
    if arguments.trimSearch {
        let report = try MeasuredBirdReplay.runTrimSearch(
            loaded,
            chordCells: arguments.chordCells,
            screeningCycles: arguments.trimScreeningCycles,
            confirmationCycles: arguments.trimConfirmationCycles,
            iterations: arguments.trimIterations,
            batchSize: arguments.batchSize,
            archiveDirectory: arguments.archivePath.map {
                URL(fileURLWithPath: $0, isDirectory: true)
            }
        )
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print("candidates: \(report.candidates.count)")
            print(
                "best_pitch_offset_deg: "
                    + String(report.bestCandidate.pitchOffsetDegrees)
            )
            print(
                "best_speed_scale: "
                    + String(report.bestCandidate.speedScale)
            )
            print(
                "relative_net_force_residual: "
                    + String(report.bestCandidate.relativeNetForceResidual)
            )
            print(
                "relative_torque_residual: "
                    + String(report.bestCandidate.relativeTorqueResidual)
            )
            print("passed: \(report.passed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        return
    }
    let report = try MeasuredBirdReplay.run(
        loaded,
        chordCells: arguments.chordCells,
        cycles: arguments.cycles,
        steps: arguments.steps,
        batchSize: arguments.batchSize,
        freeFlight: arguments.freeFlight,
        bodySubsteps: arguments.bodySubsteps,
        captureCoupledMomentumLedger: arguments.momentumLedger,
        expectBilateralSymmetry: arguments.expectBilateralSymmetry,
        archiveDirectory: arguments.archivePath.map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    )
    if arguments.json {
        try printJSON(report)
    } else {
        print("dataset: \(report.audit.datasetIdentifier)")
        print("device: \(report.deviceName)")
        print("steps: \(report.steps)")
        print("cycles: \(report.cycles)")
        print("mean_force_N: \(report.meanForceNewtons)")
        print("mean_torque_Nm: \(report.meanTorqueNewtonMeters)")
        print(
            "mean_wing_hinge_reaction_force_N: "
                + String(describing: report.meanWingHingeReactionForceNewtons)
        )
        print(
            "mean_wing_hinge_reaction_torque_Nm: "
                + String(
                    describing: report.meanWingHingeReactionTorqueNewtonMeters
                )
        )
        if let safety = report.runtimeSafety {
            print("maximum_runtime_mach: \(safety.maximumLatticeMach)")
            print(
                "minimum_sponge_clearance_m: "
                    + String(safety.minimumSpongeClearanceMeters)
            )
        }
        if let ledger = report.coupledMomentumLedger {
            print(
                "relative_boundary_momentum_residual: "
                    + String(ledger.relativeRMSBoundaryClosureResidual)
            )
            print(
                "relative_external_system_momentum_residual: "
                    + String(
                        ledger.relativeRMSExternalSystemClosureResidual
                    )
            )
            print("momentum_ledger_passed: \(ledger.passed)")
        }
        if arguments.partLoads,
           let partLoads = report.aerodynamicPartLoads {
            print(
                "relative_part_force_closure_residual: "
                    + String(partLoads.relativeRMSForceClosureResidual)
            )
            print(
                "relative_part_torque_closure_residual: "
                    + String(partLoads.relativeRMSTorqueClosureResidual)
            )
            if let symmetry = partLoads.bilateralSymmetryPassed {
                print("bilateral_part_symmetry_passed: \(symmetry)")
            }
            print("aerodynamic_part_loads_passed: \(partLoads.passed)")
        }
        print("runtime_s: \(report.runtimeSeconds)")
        print("passed: \(report.passed)")
        print("scientific_verdict: \(report.scientificVerdict)")
    }
}

private func runMeasuredWingReplay(_ values: [String]) throws {
    let arguments = try MeasuredWingReplayArguments(values)
    let dataset = try MeasuredWingSurfaceDatasetLoader.load(
        from: URL(fileURLWithPath: arguments.inputPath!)
    )
    if arguments.stationarity {
        let report = try MetalFlappingWingValidator
            .runMeasuredSurfaceStationarity(
                dataset,
                chordCells: arguments.chordCells,
                halfThicknessCells: arguments.halfThicknessCells
            )
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print("input_sha256: \(report.inputSHA256)")
            print("chord_cells: \(report.chordCells)")
            print("cycles: \(report.cycles)")
            print("cycle_steps: \(report.cycleSteps)")
            print("runtime_s: \(report.runtimeSeconds)")
            print(
                "relative_mean_force_vector_difference: "
                    + String(report.relativeMeanForceVectorDifference)
            )
            print(
                "relative_vertical_force_difference: "
                    + String(report.relativeMeanVerticalForceDifference)
            )
            print(
                "normalized_phase_force_difference: "
                    + String(report.normalizedPhaseResolvedForceDifference)
            )
            print("classification: \(report.classification)")
            print("passed: \(report.passed)")
        }
        return
    }
    if arguments.thicknessLadder {
        let report = try MetalFlappingWingValidator
            .auditMeasuredSurfaceThicknessSensitivity(
                dataset,
                chordCells: arguments.chordCells
            )
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print("input_sha256: \(report.inputSHA256)")
            print("chord_cells: \(report.chordCells)")
            print("runtime_s: \(report.runtimeSeconds)")
            print(
                "maximum_pairwise_force_vector_difference: "
                    + String(
                        report.maximumPairwiseRelativeMeanForceVectorDifference
                    )
            )
            print(
                "vertical_force_envelope: "
                    + String(report.relativeMeanVerticalForceEnvelope)
            )
            print("classification: \(report.classification)")
            print("passed: \(report.passed)")
        }
        return
    }
    let report = try MetalFlappingWingValidator.auditMeasuredSurface(
        dataset,
        chordCells: arguments.chordCells,
        halfThicknessCells: arguments.halfThicknessCells,
        runFluidCycle: arguments.fluidCycle,
        fluidCondition: arguments.publishedCondition
            ? .dong2022Published
            : .diagnosticRe100
    )
    if arguments.json {
        try printJSON(report)
    } else {
        print("dataset: \(report.datasetIdentifier)")
        print("scientific_tier: \(report.scientificTier)")
        print("input_sha256: \(report.inputSHA256)")
        print("device: \(report.deviceName)")
        print("cycle_steps: \(report.cycleSteps)")
        print("runtime_s: \(report.runtimeSeconds)")
        print("maximum_lattice_point_speed: \(report.maximumLatticePointSpeed)")
        print("fluid_condition: \(report.fluidConditionIdentifier)")
        print("reynolds: \(report.reynoldsNumber)")
        print("air_density_kg_m3: \(report.physicalAirDensityKilogramsPerCubicMeter)")
        print("reference_speed_mps: \(report.referenceSpeedMetersPerSecond)")
        print("tau_plus: \(report.tauPlus)")
        print("tau_plus_margin_above_half: \(report.tauPlusMarginAboveHalf)")
        print("prepared_position_error_m: \(report.maximumPreparedPositionErrorMeters)")
        print("prepared_velocity_error_mps: \(report.maximumPreparedVelocityErrorMetersPerSecond)")
        print("fluid_cycle_executed: \(report.fluidCycleExecuted)")
        if let mean = report.startupCycleMeanForceNewtons {
            print("startup_cycle_mean_force_N: \(mean)")
        }
        if let drift = report.relativePopulationMassDrift {
            print("relative_population_mass_drift: \(drift)")
        }
        if let maximum = report.maximumAbsolutePopulation {
            print("maximum_absolute_population: \(maximum)")
        }
        if let stability = report.fluidStabilityPassed {
            print("fluid_stability_passed: \(stability)")
        }
        if let step = report.firstNonFiniteLoadStep {
            print("first_non_finite_load_step: \(step)")
        }
        if let verdict = report.fluidStabilityVerdict {
            print("fluid_stability_verdict: \(verdict)")
        }
        print("passed: \(report.passed)")
        print("complete_bird_replay_ready: \(report.completeBirdReplayReady)")
    }
}

private func runMeasuredBirdSurfaceReplay(_ values: [String]) throws {
    let arguments = try MeasuredBirdSurfaceReplayArguments(values)
    let dataset = try MeasuredBirdSurfaceSequenceLoader.load(
        manifestURL: URL(fileURLWithPath: arguments.inputPath!)
    )
    if arguments.couplingGate {
        let report = try MetalIndexedBirdSurfaceCouplingValidator.audit(
            dataset,
            cellSizeMeters: arguments.cellSizeMeters,
            halfThicknessCells: arguments.halfThicknessCells
        )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            print("device: \(report.deviceName)")
            print("steps: \(report.steps)")
            print("runtime_s: \(report.runtimeSeconds)")
            print("covered_cells: \(report.newlyCoveredCellEvents)")
            print("uncovered_cells: \(report.newlyUncoveredCellEvents)")
            print(
                "persistent_boundary_links: "
                    + String(report.persistentBoundaryLinkEvents)
            )
            print(
                "relative_rms_boundary_residual: "
                    + String(report.relativeRMSBoundaryClosureResidual)
            )
            print("passed: \(report.passed)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed Metal production coupling gate failed"
            )
        }
        return
    }
    let report = try MetalIndexedBirdSurfaceValidator.audit(
        dataset,
        cellSizeMeters: arguments.cellSizeMeters,
        halfThicknessCells: arguments.halfThicknessCells
    )
    if let archivePath = arguments.archivePath {
        try writeJSON(report, to: archivePath)
    }
    if arguments.json {
        try printJSON(report)
    } else {
        print("dataset: \(report.datasetIdentifier)")
        print("device: \(report.deviceName)")
        print("frames: \(report.frameCount)")
        print("vertices_per_frame: \(report.vertexCount)")
        print("triangles: \(report.triangleCount)")
        print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
        print("runtime_s: \(report.runtimeSeconds)")
        print(
            "maximum_prepared_position_error_m: "
                + String(report.maximumPreparedPositionErrorMeters)
        )
        print(
            "maximum_prepared_velocity_error_mps: "
                + String(report.maximumPreparedVelocityErrorMetersPerSecond)
        )
        print(
            "maximum_cpu_mask_mismatch_cells: "
                + String(report.maximumCPUMaskMismatchCellCount)
        )
        print("all_components_present: \(report.allComponentsPresentEveryFrame)")
        print("fluid_collision_executed: \(report.fluidCollisionExecuted)")
        print("force_accumulation_executed: \(report.forceAccumulationExecuted)")
        print("passed: \(report.passed)")
    }
    guard report.passed else {
        throw MeasuredBirdSurfaceSequenceError.invalidDataset(
            "indexed Metal geometry parity gate failed"
        )
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
    if arguments.highReStability {
        let report = try MetalMovingWallValidator.runHighReStability()
        if arguments.json {
            try printJSON(report)
        } else {
            print("production_kernel: \(report.productionKernel)")
            print("device: \(report.deviceName)")
            print("classification: \(report.classification)")
            for result in report.cases {
                print(
                    "matched_c=\(result.matchedBirdChordCells) "
                        + "tau_margin=\(result.tauPlusMarginAboveHalf) "
                        + "finite_steps=\(result.finiteSteps)/\(result.requestedSteps) "
                        + "passed=\(result.passed)"
                )
            }
            print("passed: \(report.passed)")
        }
        guard report.passed else {
            throw MetalMovingWallValidationError.failed(
                "matched high-Re fixed-wall stability gate failed"
            )
        }
        return
    }
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

private func runTranslatingBodyValidation(_ values: [String]) throws {
    let arguments = try TranslatingBodyArguments(values)
    if arguments.highReStability {
        if arguments.stationaryWall {
            if arguments.bulkCollisionOperatorAB
                || arguments.recursiveRegularizationAB
            {
                let report = try arguments.recursiveRegularizationAB
                    ? MetalTranslatingBodyTopologyValidator
                        .runStationaryWallRecursiveRegularizationAB()
                    : MetalTranslatingBodyTopologyValidator
                        .runStationaryWallBulkCollisionOperatorAB()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    for item in [report.control, report.candidate] {
                        print(
                            "operator=\(item.operatorName): "
                                + "steps=\(item.completedSteps) "
                                + "Cd=\(item.meanDragCoefficientLastConvectiveTime) "
                                + "control_activation=\(item.controlVolumeCorrectionActivationFraction) "
                                + "control_correction_L1=\(item.relativeControlVolumeCorrectionL1) "
                                + "force_RMS=\(item.conservativeRelativeRMSForceResidual) "
                                + "eligible=\(item.eligibleForRefinement)"
                        )
                    }
                    print(
                        "candidate_to_control_activation: "
                            + String(
                                report.candidateToControlActivationRatio
                            )
                    )
                    print(
                        "candidate_to_control_correction_L1: "
                            + String(
                                report.candidateToControlCorrectionL1Ratio
                            )
                    )
                    print(
                        "candidate_eligible_for_refinement: "
                            + String(
                                report.candidateEligibleForRefinement
                            )
                    )
                    print("passed: \(report.passed)")
                }
                guard report.passed else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "bulk collision-operator diagnostic did not complete"
                    )
                }
                return
            }
            if arguments.radialLimiterLocalization {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallRadialLimiterLocalization()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    print(
                        "first_activation_step: "
                            + String(describing:
                                report.firstLimiterActivationStep)
                    )
                    for snapshot in report.snapshots {
                        print(
                            "tU/D=\(snapshot.convectiveTime): "
                                + "near_L1=\(snapshot.nearSurfaceLimiterL1Fraction) "
                                + "far_L1=\(snapshot.farFieldLimiterL1Fraction) "
                                + "near_active=\(snapshot.nearSurfaceActivationFraction) "
                                + "far_active=\(snapshot.farFieldActivationFraction)"
                        )
                    }
                    print("boundary_localized: \(report.boundaryLocalized)")
                    print("passed: \(report.passed)")
                }
                guard report.passed else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "radial limiter localization did not close"
                    )
                }
                return
            }
            if arguments.recursiveRegularizationDuration {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallRecursiveRegularizationDurationSensitivity()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    for item in report.cases {
                        print(
                            "D=\(item.numericalCase.diameterCells): "
                                + "steps=\(item.numericalCase.requestedSteps) "
                                + "window_Cd=\(item.convectiveWindowMeanDragCoefficients) "
                                + "fourth_to_fifth=\(item.fourthToFifthRelativeDragChange) "
                                + "ninth_to_tenth=\(item.ninthToTenthRelativeDragChange) "
                                + "fifth_to_tenth=\(item.fifthToTenthRelativeDragChange) "
                                + "stable=\(item.durationStabilityPassed)"
                        )
                    }
                    print(
                        "baseline_window_bias_confirmed: "
                            + String(report.baselineWindowBiasConfirmed)
                    )
                    print("passed: \(report.passed)")
                }
                guard report.passed else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "recursive-regularization duration diagnostic did not complete"
                    )
                }
                return
            }
            if arguments.geometricLimiterLadder
                || arguments.recursiveRegularizationLadder
            {
                let report = try arguments.recursiveRegularizationLadder
                    ? MetalTranslatingBodyTopologyValidator
                        .runStationaryWallRecursiveRegularizationLadder()
                    : MetalTranslatingBodyTopologyValidator
                        .runStationaryWallGeometricLimiterLadder()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    for item in report.cases {
                        print(
                            "D=\(item.diameterCells): "
                                + "steps=\(item.requestedSteps) "
                                + "Cd=\(item.meanDragCoefficientLastConvectiveTime) "
                                + "global_activation=\(item.limiterActivationFraction) "
                                + "control_activation=\(item.controlVolumeLimiterActivationFraction) "
                                + "control_limiter_L1=\(item.relativeControlVolumeLimiterL1Correction) "
                                + "control_limiter_L2=\(item.relativeControlVolumeLimiterL2Correction) "
                                + "force_RMS=\(item.conservativeRelativeRMSResidual) "
                                + "passed=\(item.passed)"
                        )
                    }
                    print(
                        "finest_two_drag_change: "
                            + String(report.relativeFinestTwoDragChange)
                    )
                    print(
                        "observed_order: "
                            + String(describing:
                                report.observedDragConvergenceOrder)
                    )
                    print("passed: \(report.passed)")
                }
                guard report.passed else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "geometric collision-operator ladder did not pass"
                    )
                }
                return
            }
            if arguments.symmetricLimiterAB {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallC16SymmetricLimiterAB()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    print(
                        "control_failure: negative=\(String(describing: report.control.firstNegativePopulationStep)) "
                            + "non_finite=\(String(describing: report.control.firstNonFinitePopulationStep))"
                    )
                    print(
                        "treatment: completed=\(report.treatment.completedSteps) "
                            + "activations=\(report.treatment.limiterActivationCellSteps) "
                            + "minimum_scale=\(String(describing: report.treatment.minimumLimiterScale)) "
                            + "stability_passed=\(report.treatment.stabilityPassed) "
                            + "budget_passed=\(report.treatment.forceBudgetPassed)"
                    )
                    let ledger = report.treatmentConservationLedger
                    print(
                        "conservation_ledger: global_closed=\(ledger.globalLedgerClosed) "
                            + "force_source_closed=\(ledger.forceResidualLedgerClosed) "
                            + "mass_source=\(ledger.dominantGlobalMassContribution) "
                            + "momentum_source=\(ledger.dominantControlVolumeMomentumContribution)"
                    )
                    print(
                        "source_aware_acceptance: outside_sponge=\(report.sourceAwareControlVolumeOutsideSponge) "
                            + "crossing_links=\(report.sourceAwareMaximumSolidControlSurfaceCrossingLinkCount) "
                            + "stability=\(report.sourceAwareStabilityPassed) "
                            + "force_budget=\(report.sourceAwareForceBudgetPassed) "
                            + "accepted=\(report.sourceAwareAcceptancePassed)"
                    )
                    print("diagnostic_completed: \(report.diagnosticCompleted)")
                }
                guard report.diagnosticCompleted else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "stationary-wall c16 symmetric-limiter A/B did not complete"
                    )
                }
                return
            }
            if arguments.trtCollisionDecomposition {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallC16TRTCollisionDecomposition()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    let failing = report.failingDirection
                    print("production_kernel: \(report.productionKernel)")
                    print("diagnostic_kernel: \(report.diagnosticKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    print(
                        "failing_direction: q=\(failing.directionIndex) "
                            + "pulled=\(failing.pulledPopulation) "
                            + "symmetric_increment=\(failing.symmetricRelaxationIncrement) "
                            + "antisymmetric_increment=\(failing.antisymmetricRelaxationIncrement) "
                            + "post=\(failing.actualPostCollision)"
                    )
                    print(
                        "dominant_mode: "
                            + report.dominantDestabilizingRelaxationMode
                    )
                    print("diagnostic_completed: \(report.diagnosticCompleted)")
                }
                guard report.diagnosticCompleted else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "stationary-wall c16 TRT decomposition did not complete"
                    )
                }
                return
            }
            if arguments.populationPositivity {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallC16PopulationPositivity()
                if let archivePath = arguments.archivePath {
                    try writeJSON(report, to: archivePath)
                }
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("diagnostic_kernel: \(report.diagnosticKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    if let first = report.firstNegative {
                        print(
                            "first_negative: step=\(first.step) "
                                + "q=\(first.directionIndex) "
                                + "cell=\(first.cell) "
                                + "sphere_distance=\(first.signedDistanceToSphereSurfaceCells)"
                        )
                    }
                    if let first = report.firstNonFinite {
                        print(
                            "first_non_finite: step=\(first.step) "
                                + "q=\(first.directionIndex) "
                                + "cell=\(first.cell) "
                                + "sphere_distance=\(first.signedDistanceToSphereSurfaceCells)"
                        )
                    }
                    print("diagnostic_completed: \(report.diagnosticCompleted)")
                }
                guard report.diagnosticCompleted else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "stationary-wall c16 population diagnostic did not complete"
                    )
                }
                return
            }
            if arguments.longHorizonSurvival {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallLongHorizonSurvival()
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    print("surviving_points: \(report.survivingPointCount)")
                    print("diagnostic_completed: \(report.diagnosticCompleted)")
                }
                guard report.diagnosticCompleted else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "stationary-wall long-horizon survival did not complete"
                    )
                }
                return
            }
            if arguments.relaxationSweep {
                let report = try MetalTranslatingBodyTopologyValidator
                    .runStationaryWallRelaxationSweep()
                if arguments.json {
                    try printJSON(report)
                } else {
                    print("production_kernel: \(report.productionKernel)")
                    print("device: \(report.deviceName)")
                    print("classification: \(report.classification)")
                    print("threshold_bracketed: \(report.thresholdBracketed)")
                    print("diagnostic_completed: \(report.diagnosticCompleted)")
                }
                guard report.diagnosticCompleted else {
                    throw MetalTranslatingBodyTopologyValidationError.failed(
                        "stationary-wall relaxation sweep did not complete"
                    )
                }
                return
            }
            let report = try MetalTranslatingBodyTopologyValidator
                .runHighReStationaryWallSphereStability()
            if arguments.json {
                try printJSON(report)
            } else {
                print("production_kernel: \(report.productionKernel)")
                print("device: \(report.deviceName)")
                print("classification: \(report.classification)")
                print("stationary_wall_stable: \(report.passed)")
            }
            return
        }
        if arguments.decomposeWallVelocity {
            let report = try MetalTranslatingBodyTopologyValidator
                .runHighReFixedOccupancyWallDecomposition()
            if arguments.json {
                try printJSON(report)
            } else {
                print("production_kernel: \(report.productionKernel)")
                print("device: \(report.deviceName)")
                print("classification: \(report.classification)")
                print("tangential_stable: \(report.tangential.passed)")
                print("normal_stable: \(report.normal.passed)")
                print("diagnostic_completed: \(report.diagnosticCompleted)")
            }
            guard report.diagnosticCompleted else {
                throw MetalTranslatingBodyTopologyValidationError.failed(
                    "normal/tangential fixed-sphere decomposition did not complete"
                )
            }
            return
        }
        let report = try arguments.fixedOccupancy
            ? MetalTranslatingBodyTopologyValidator
                .runHighReFixedOccupancyStability()
            : MetalTranslatingBodyTopologyValidator.runHighReStability()
        if arguments.json {
            try printJSON(report)
        } else {
            print("production_kernel: \(report.productionKernel)")
            print("topology_kernel: \(report.topologyKernel)")
            print("device: \(report.deviceName)")
            print("classification: \(report.classification)")
            for result in report.cases {
                print(
                    "matched_c=\(result.matchedBirdChordCells) "
                        + "finite_steps=\(result.finiteLoadSteps)/\(result.requestedSteps) "
                        + "transition_steps=\(result.topologyTransitionSteps) "
                        + "passed=\(result.passed)"
                )
            }
            print("passed: \(report.passed)")
        }
        guard report.passed else {
            throw MetalTranslatingBodyTopologyValidationError.failed(
                arguments.fixedOccupancy
                    ? "matched high-Re fixed-occupancy sphere gate failed"
                    : "matched high-Re cell-crossing stability gate failed"
            )
        }
        return
    }
    let report = try MetalTranslatingBodyTopologyValidator.run()
    if arguments.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(report), as: UTF8.self))
    } else {
        print("production_kernel: \(report.productionKernel)")
        print("topology_kernel: \(report.topologyKernel)")
        print("device: \(report.deviceName)")
        print(
            "cell_events: covered=\(report.newlyCoveredCellEvents) "
                + "uncovered=\(report.newlyUncoveredCellEvents) "
                + "transition_steps=\(report.topologyTransitionSteps)"
        )
        print(
            "legacy_rms_residual: \(report.legacyRMSForceResidual)"
        )
        print(
            "conservative_rms_residual: "
                + String(report.conservativeRMSForceResidual)
        )
        print(
            "conservative_improvement_factor: "
                + String(report.conservativeImprovementFactor)
        )
        print("passed: \(report.passed)")
    }
    guard report.passed else {
        throw MetalTranslatingBodyTopologyValidationError.failed(
            "force did not close against fluid momentum across topology changes"
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
                + " mismatch=\(result.mismatchedCellFraction) "
                + "links=\(result.boundaryLinkCount) "
                + "audited_links=\(result.auditedBoundaryLinkCount) "
                + "max_link_error="
                + String(result.maximumLinkFractionError) + " "
                + "max_wall_position_error_cells="
                + String(
                    result.maximumInterpolatedWallPositionErrorCells
                )
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
    if arguments.diagnoseMomentumBudget {
        guard !arguments.auditInputs,
              !arguments.decomposeLoads,
              !arguments.compareLinkForces,
              !arguments.decomposeLinkNumerator,
              archive == nil else {
            throw CLIError.invalidArgument(
                "--momentum-budget cannot be combined with another diagnostic or --archive"
            )
        }
        let report = try MetalFlappingWingValidator
            .diagnoseNearWingMomentumBudget(
                chordCells: arguments.singleChordCells ?? 8,
                cycles: arguments.cycles
            )
        if arguments.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        } else {
            print("diagnostic_only: true")
            print("device: \(report.deviceName)")
            print(
                "budget_mean_CL="
                    + String(
                        report.independentFluidMomentumBudget
                            .meanLiftCoefficient
                    )
                    + " budget_mean_CD="
                    + String(
                        report.independentFluidMomentumBudget
                            .meanDragCoefficient
                    )
            )
            print(
                "conventional_max_CL_residual="
                    + String(
                        report.maximumConventionalLiftCoefficientResidual
                    )
                    + " conventional_max_CD_residual="
                    + String(
                        report.maximumConventionalDragCoefficientResidual
                    )
            )
            print(
                "conventional_mean_lift_bias_factor="
                    + String(report.conventionalMeanLiftBiasFactor)
                    + " conventional_mean_drag_bias_factor="
                    + String(report.conventionalMeanDragBiasFactor)
            )
            print(
                "conservative_mean_CL="
                    + String(
                        report.conservativeMovingDomainBoundaryLoad
                            .meanLiftCoefficient
                    )
                    + " conservative_mean_CD="
                    + String(
                        report.conservativeMovingDomainBoundaryLoad
                            .meanDragCoefficient
                    )
            )
            print(
                "conservative_max_CL_residual="
                    + String(
                        report.maximumConservativeLiftCoefficientResidual
                    )
                    + " conservative_max_CD_residual="
                    + String(
                        report.maximumConservativeDragCoefficientResidual
                    )
            )
            print("classification: \(report.classification)")
            print(
                "conventional_closure_passed: "
                    + String(report.conventionalClosurePassed)
            )
            print(
                "conservative_closure_passed: "
                    + String(report.conservativeMovingDomainClosurePassed)
            )
        }
        return
    }
    if arguments.decomposeLinkNumerator {
        guard !arguments.auditInputs,
              !arguments.decomposeLoads,
              !arguments.compareLinkForces,
              archive == nil else {
            throw CLIError.invalidArgument(
                "--decompose-link-numerator cannot be combined with another diagnostic or --archive"
            )
        }
        let report = try MetalFlappingWingValidator
            .diagnoseLinkNumeratorDecomposition(
                chordCells: arguments.singleChordCells ?? 8,
                cycles: arguments.cycles
            )
        if arguments.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        } else {
            print("diagnostic_only: true")
            print("device: \(report.deviceName)")
            for component in report.components {
                print(
                    "component=\(component.name) "
                        + "mean_CL=\(component.load.meanLiftCoefficient) "
                        + "mean_CD=\(component.load.meanDragCoefficient)"
                )
            }
            print(
                "dominant_mean_lift_component: "
                    + report.dominantMeanLiftComponent
            )
            print(
                "dominant_mean_drag_component: "
                    + report.dominantMeanDragComponent
            )
            print("closure_passed: \(report.closurePassed)")
        }
        return
    }
    if arguments.compareLinkForces {
        guard !arguments.auditInputs,
              !arguments.decomposeLoads,
              !arguments.decomposeLinkNumerator,
              archive == nil else {
            throw CLIError.invalidArgument(
                "--compare-link-forces cannot be combined with --audit-inputs, --decompose-loads, or --archive"
            )
        }
        let report = try MetalFlappingWingValidator
            .compareLinkForceEstimators(
                chordCells: arguments.singleChordCells ?? 8,
                cycles: arguments.cycles
            )
        if arguments.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        } else {
            print("diagnostic_only: true")
            print("device: \(report.deviceName)")
            print(
                "galilean_invariant_total_CL="
                    + String(
                        report.galileanInvariantTotal.meanLiftCoefficient
                    )
                    + " conventional_total_CL="
                    + String(
                        report.conventionalMovingBodyTotal
                            .meanLiftCoefficient
                    )
            )
            print(
                "galilean_invariant_total_CD="
                    + String(
                        report.galileanInvariantTotal.meanDragCoefficient
                    )
                    + " conventional_total_CD="
                    + String(
                        report.conventionalMovingBodyTotal
                            .meanDragCoefficient
                    )
            )
            print(
                "conventional_to_galilean_lift_ratio="
                    + String(
                        report.conventionalToGalileanMeanLiftRatio
                    )
                    + " conventional_to_galilean_drag_ratio="
                    + String(
                        report.conventionalToGalileanMeanDragRatio
                    )
            )
            print("closure_passed: \(report.closurePassed)")
        }
        return
    }
    if arguments.decomposeLoads {
        guard !arguments.auditInputs, archive == nil else {
            throw CLIError.invalidArgument(
                "--decompose-loads cannot be combined with --audit-inputs or --archive"
            )
        }
        let report = try MetalFlappingWingValidator.diagnoseLoadDecomposition(
            chordCells: arguments.singleChordCells ?? 8,
            cycles: arguments.cycles
        )
        if arguments.json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            print(String(decoding: try encoder.encode(report), as: UTF8.self))
        } else {
            print("diagnostic_only: true")
            print("device: \(report.deviceName)")
            print(
                "total_CL=\(report.total.meanLiftCoefficient) "
                    + "link_CL=\(report.linkExchange.meanLiftCoefficient) "
                    + "topology_CL="
                    + String(report.coverUncoverImpulse.meanLiftCoefficient)
            )
            print(
                "total_CD=\(report.total.meanDragCoefficient) "
                    + "link_CD=\(report.linkExchange.meanDragCoefficient) "
                    + "topology_CD="
                    + String(report.coverUncoverImpulse.meanDragCoefficient)
            )
            print(
                "topology_rms_lift_fraction="
                    + String(report.topologyRMSLiftFraction) + " "
                    + "topology_rms_drag_fraction="
                    + String(report.topologyRMSDragFraction)
            )
            print("closure_passed: \(report.closurePassed)")
        }
        return
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
                "Use: birdflow validate <shear-wave|moving-wall|translating-body|sphere|wing|flapping-wing> [options]"
            )
        }
        switch values[2] {
        case "shear-wave":
            try runShearWaveValidation(values)
        case "moving-wall":
            try runMovingWallValidation(values)
        case "translating-body":
            try runTranslatingBodyValidation(values)
        case "sphere":
            try runSphereValidation(values)
        case "wing":
            try runWingValidation(values)
        case "flapping-wing":
            try runFlappingWingValidation(values)
        default:
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall|translating-body|sphere|wing|flapping-wing> [options]"
            )
        }
    } else if values.count > 1, values[1] == "replay" {
        guard values.count > 2 else {
            throw CLIError.invalidArgument(
                "Use: birdflow replay <measured-bird|measured-wing|measured-bird-surface> --input DATASET.json [options]"
            )
        }
        switch values[2] {
        case "measured-bird":
            try runMeasuredBirdReplay(values)
        case "measured-wing":
            try runMeasuredWingReplay(values)
        case "measured-bird-surface":
            try runMeasuredBirdSurfaceReplay(values)
        default:
            throw CLIError.invalidArgument(
                "Use: birdflow replay <measured-bird|measured-wing|measured-bird-surface> --input DATASET.json [options]"
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

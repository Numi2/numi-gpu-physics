import BirdFlowCore
import BirdFlowMetal
import CryptoKit
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
      birdflow validate direction-composition --preregistration FILE \
        [--archive FILE] [--json]

    Measured prescribed replay:
      birdflow replay measured-bird --input DATASET.json [--audit-only] [--json]
      birdflow replay measured-wing --input SURFACE.json [--fluid-cycle] [--json]
      birdflow replay measured-bird-surface --input MANIFEST.json \
        [--coupling-gate | --coarse-fluid-pilot | --collision-pre-roll-ab | \
         --collision-momentum-closure | --collision-extended-pilot | \
         --collision-grid-provenance | \
         --collision-grid-boundary-decomposition | \
         --collision-grid-moving-wall-ab | \
         --collision-grid-moving-wall-ledger | \
         --collision-grid-moving-wall-full-window | \
         --collision-grid-moving-wall-spatial-preregister | \
         --collision-grid-moving-wall-spatial-case | \
         --collision-grid-moving-wall-spatial-discriminator | \
         --collision-grid-moving-wall-temporal-preregister | \
         --collision-grid-moving-wall-temporal-sampling | \
         --collision-grid-moving-wall-temporal-duration-preregister | \
         --collision-grid-moving-wall-temporal-duration | \
         --collision-grid-moving-wall-link-geometry-preregister | \
         --collision-grid-moving-wall-link-geometry | \
         --collision-grid-moving-wall-link-velocity-preregister | \
         --collision-grid-moving-wall-link-velocity | \
         --collision-grid-moving-wall-link-intersection-preregister | \
         --collision-grid-moving-wall-link-intersection | \
         --collision-grid-moving-wall-link-ray-root-preregister | \
         --collision-grid-moving-wall-link-ray-root | \
         --collision-grid-moving-wall-link-coefficient-preregister | \
         --collision-grid-moving-wall-link-coefficient | \
         --collision-grid-moving-wall-link-population-preregister | \
         --collision-grid-moving-wall-link-population | \
         --collision-grid-moving-wall-distributed-force-preregister | \
         --collision-grid-moving-wall-distributed-force | \
         --collision-grid-moving-wall-force-covariance-preregister | \
         --collision-grid-moving-wall-force-covariance | \
         --collision-grid-moving-wall-spatial-interaction-preregister | \
         --collision-grid-moving-wall-spatial-interaction | \
         --source-viscosity-d16-preregister | \
         --source-viscosity-d16-ab | \
         --source-viscosity-d28-preregister | \
         --source-viscosity-d28-pre-roll] \
        [--force-target TARGET.json] \
        [--archive FILE] [--json]

      Targeted D28/D32 moving-boundary component replay:
        birdflow replay measured-bird-surface --input MANIFEST.json \
          --force-target TARGET.json \
          --source-viscosity-targeted-boundary-case \
          --preregistration TARGETED_PREREGISTRATION.json \
          --source-targeted-full-window-report D28_OR_D32_REPORT.json \
          --targeted-reference-length-cells 28|32 \
          [--archive FILE] [--json]

      Selected-link reflected-population provenance:
        birdflow replay measured-bird-surface --input MANIFEST.json \
          --force-target TARGET.json \
          --source-viscosity-reflected-provenance-case \
          --preregistration REFLECTED_PREREGISTRATION.json \
          --source-targeted-boundary-case D28_OR_D32_TARGETED_CASE.json \
          --targeted-reference-length-cells 28|32 \
          [--archive FILE] [--json]
    """
}

private struct MeasuredBirdSurfaceReplayArguments {
    var inputPath: String?
    var forceTargetPath: String?
    var archivePath: String?
    var preregistrationPath: String?
    var discriminatorPath: String?
    var completionPath: String?
    var provenancePath: String?
    var boundaryTermsPath: String?
    var movingWallABPath: String?
    var movingWallLedgerPath: String?
    var movingWallFullWindowPath: String?
    var spatialPreregistrationPath: String?
    var spatialD8Path: String?
    var spatialD12Path: String?
    var spatialDiscriminatorPath: String?
    var lagBandPath: String?
    var temporalPreregistrationPath: String?
    var temporalSamplingPath: String?
    var temporalDurationPreregistrationPath: String?
    var temporalDurationPath: String?
    var linkGeometryPreregistrationPath: String?
    var linkGeometryPath: String?
    var linkVelocityPreregistrationPath: String?
    var linkVelocityPath: String?
    var linkIntersectionPreregistrationPath: String?
    var linkIntersectionPath: String?
    var linkRayRootPreregistrationPath: String?
    var linkRayRootPath: String?
    var linkCoefficientPreregistrationPath: String?
    var linkCoefficientPath: String?
    var linkPopulationPreregistrationPath: String?
    var linkPopulationPath: String?
    var linkPopulationAuditPath: String?
    var distributedForcePreregistrationPath: String?
    var distributedForcePath: String?
    var distributedForceAuditPath: String?
    var forceCovariancePreregistrationPath: String?
    var forceCovariancePath: String?
    var forceCovarianceAuditPath: String?
    var spatialInteractionPreregistrationPath: String?
    var sourceScalingPath: String?
    var sourceScalingAuditPath: String?
    var sourceD16PreregistrationPath: String?
    var sourceD16ReportPath: String?
    var sourceD16AuditPath: String?
    var sourceD28PreregistrationPath: String?
    var sourceD28PreRollPath: String?
    var sourceD28AuditPath: String?
    var sourceD28FullWindowPreregistrationPath: String?
    var sourceD28FullWindowReportPath: String?
    var sourceD28FullWindowAuditPath: String?
    var sourceD32PreregistrationPath: String?
    var sourceD32PreRollPath: String?
    var sourceD32AuditPath: String?
    var sourceTargetedFullWindowReportPath: String?
    var sourceTargetedBoundaryCasePath: String?
    var targetedReferenceLengthCells: Int?
    var spatialReferenceLengthCells: Int?
    var cellSizeMeters: Float = 0.01
    var halfThicknessCells: Float = 0.75
    var couplingGate = false
    var coarseFluidPilot = false
    var collisionPreRollAB = false
    var collisionMomentumClosure = false
    var collisionExtendedPilot = false
    var collisionGridPreregister = false
    var collisionGridDiscriminator = false
    var collisionGridCompletion = false
    var collisionGridProvenance = false
    var collisionGridBoundaryDecomposition = false
    var collisionGridMovingWallAB = false
    var collisionGridMovingWallLedger = false
    var collisionGridMovingWallFullWindow = false
    var collisionGridMovingWallSpatialPreregister = false
    var collisionGridMovingWallSpatialCase = false
    var collisionGridMovingWallSpatialDiscriminator = false
    var collisionGridMovingWallTemporalPreregister = false
    var collisionGridMovingWallTemporalSampling = false
    var collisionGridMovingWallTemporalDurationPreregister = false
    var collisionGridMovingWallTemporalDuration = false
    var collisionGridMovingWallLinkGeometryPreregister = false
    var collisionGridMovingWallLinkGeometry = false
    var collisionGridMovingWallLinkVelocityPreregister = false
    var collisionGridMovingWallLinkVelocity = false
    var collisionGridMovingWallLinkIntersectionPreregister = false
    var collisionGridMovingWallLinkIntersection = false
    var collisionGridMovingWallLinkRayRootPreregister = false
    var collisionGridMovingWallLinkRayRoot = false
    var collisionGridMovingWallLinkCoefficientPreregister = false
    var collisionGridMovingWallLinkCoefficient = false
    var collisionGridMovingWallLinkPopulationPreregister = false
    var collisionGridMovingWallLinkPopulation = false
    var collisionGridMovingWallDistributedForcePreregister = false
    var collisionGridMovingWallDistributedForce = false
    var collisionGridMovingWallForceCovariancePreregister = false
    var collisionGridMovingWallForceCovariance = false
    var collisionGridMovingWallSpatialInteractionPreregister = false
    var collisionGridMovingWallSpatialInteraction = false
    var sourceViscosityD16Preregister = false
    var sourceViscosityD16AB = false
    var sourceViscosityD28Preregister = false
    var sourceViscosityD28PreRoll = false
    var sourceViscosityD28FullWindowPreregister = false
    var sourceViscosityD28FullWindow = false
    var sourceViscosityD32Preregister = false
    var sourceViscosityD32PreRoll = false
    var sourceViscosityD32FullWindowPreregister = false
    var sourceViscosityD32FullWindow = false
    var sourceViscosityTargetedBoundaryCase = false
    var sourceViscosityReflectedProvenanceCase = false
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
            case "--force-target":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--force-target requires a measured-force target path"
                    )
                }
                forceTargetPath = values[index]
            case "--preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--preregistration requires a locked JSON path"
                    )
                }
                preregistrationPath = values[index]
            case "--discriminator":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--discriminator requires a completed JSON path"
                    )
                }
                discriminatorPath = values[index]
            case "--completion":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--completion requires a failed D=16 JSON path"
                    )
                }
                completionPath = values[index]
            case "--provenance":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--provenance requires a D=16 stage JSON path"
                    )
                }
                provenancePath = values[index]
            case "--boundary-terms":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--boundary-terms requires a D=16 boundary report"
                    )
                }
                boundaryTermsPath = values[index]
            case "--moving-wall-ab":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--moving-wall-ab requires a passed D=16 A/B report"
                    )
                }
                movingWallABPath = values[index]
            case "--moving-wall-ledger":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--moving-wall-ledger requires the passed retained-horizon report"
                    )
                }
                movingWallLedgerPath = values[index]
            case "--moving-wall-full-window":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--moving-wall-full-window requires the passed D=16 full-window report"
                    )
                }
                movingWallFullWindowPath = values[index]
            case "--spatial-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--spatial-preregistration requires a locked JSON path"
                    )
                }
                spatialPreregistrationPath = values[index]
            case "--spatial-d8":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--spatial-d8 requires the completed D=8 case report"
                    )
                }
                spatialD8Path = values[index]
            case "--spatial-d12":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--spatial-d12 requires the completed D=12 case report"
                    )
                }
                spatialD12Path = values[index]
            case "--spatial-discriminator":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--spatial-discriminator requires the completed spatial report"
                    )
                }
                spatialDiscriminatorPath = values[index]
            case "--lag-band":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--lag-band requires the completed lag/band artifact"
                    )
                }
                lagBandPath = values[index]
            case "--temporal-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--temporal-preregistration requires the locked JSON path"
                    )
                }
                temporalPreregistrationPath = values[index]
            case "--temporal-sampling":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--temporal-sampling requires the completed eight-bin report"
                    )
                }
                temporalSamplingPath = values[index]
            case "--temporal-duration-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--temporal-duration-preregistration requires the locked JSON path"
                    )
                }
                temporalDurationPreregistrationPath = values[index]
            case "--temporal-duration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--temporal-duration requires the completed 24-bin report"
                    )
                }
                temporalDurationPath = values[index]
            case "--link-geometry-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-geometry-preregistration requires a locked JSON path"
                    )
                }
                linkGeometryPreregistrationPath = values[index]
            case "--link-geometry":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-geometry requires the completed geometry-only report"
                    )
                }
                linkGeometryPath = values[index]
            case "--link-velocity-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-velocity-preregistration requires a locked JSON path"
                    )
                }
                linkVelocityPreregistrationPath = values[index]
            case "--link-velocity":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-velocity requires the completed velocity A/B report"
                    )
                }
                linkVelocityPath = values[index]
            case "--link-intersection-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-intersection-preregistration requires a locked JSON path"
                    )
                }
                linkIntersectionPreregistrationPath = values[index]
            case "--link-intersection":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-intersection requires the completed outlier report"
                    )
                }
                linkIntersectionPath = values[index]
            case "--link-ray-root-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-ray-root-preregistration requires a locked JSON path"
                    )
                }
                linkRayRootPreregistrationPath = values[index]
            case "--link-ray-root":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-ray-root requires the completed exact-root report"
                    )
                }
                linkRayRootPath = values[index]
            case "--link-coefficient-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-coefficient-preregistration requires a locked JSON path"
                    )
                }
                linkCoefficientPreregistrationPath = values[index]
            case "--link-coefficient":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-coefficient requires the completed coefficient report"
                    )
                }
                linkCoefficientPath = values[index]
            case "--link-population-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-population-preregistration requires a locked JSON path"
                    )
                }
                linkPopulationPreregistrationPath = values[index]
            case "--link-population":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-population requires the completed realized-population report"
                    )
                }
                linkPopulationPath = values[index]
            case "--link-population-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--link-population-audit requires the independent audit JSON path"
                    )
                }
                linkPopulationAuditPath = values[index]
            case "--distributed-force-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--distributed-force-preregistration requires a locked JSON path"
                    )
                }
                distributedForcePreregistrationPath = values[index]
            case "--distributed-force":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--distributed-force requires the completed D12/D16 report"
                    )
                }
                distributedForcePath = values[index]
            case "--distributed-force-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--distributed-force-audit requires the independent audit JSON path"
                    )
                }
                distributedForceAuditPath = values[index]
            case "--force-covariance-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--force-covariance-preregistration requires a locked JSON path"
                    )
                }
                forceCovariancePreregistrationPath = values[index]
            case "--force-covariance":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--force-covariance requires the completed covariance report"
                    )
                }
                forceCovariancePath = values[index]
            case "--force-covariance-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--force-covariance-audit requires the independent audit JSON path"
                    )
                }
                forceCovarianceAuditPath = values[index]
            case "--spatial-interaction-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--spatial-interaction-preregistration requires a locked JSON path"
                    )
                }
                spatialInteractionPreregistrationPath = values[index]
            case "--source-scaling":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-scaling requires the locked source-scaling report"
                    )
                }
                sourceScalingPath = values[index]
            case "--source-scaling-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-scaling-audit requires its independent audit report"
                    )
                }
                sourceScalingAuditPath = values[index]
            case "--source-d16-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d16-preregistration requires the locked D16 JSON"
                    )
                }
                sourceD16PreregistrationPath = values[index]
            case "--source-d16-report":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d16-report requires the completed D16 A/B JSON"
                    )
                }
                sourceD16ReportPath = values[index]
            case "--source-d16-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d16-audit requires the independent D16 audit JSON"
                    )
                }
                sourceD16AuditPath = values[index]
            case "--source-d28-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d28-preregistration requires the locked D28 JSON"
                    )
                }
                sourceD28PreregistrationPath = values[index]
            case "--source-d28-pre-roll":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d28-pre-roll requires the completed D28 pre-roll JSON"
                    )
                }
                sourceD28PreRollPath = values[index]
            case "--source-d28-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d28-audit requires the independent D28 audit JSON"
                    )
                }
                sourceD28AuditPath = values[index]
            case "--source-d28-full-window-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d28-full-window-preregistration requires the locked D28 full-window contract"
                    )
                }
                sourceD28FullWindowPreregistrationPath = values[index]
            case "--source-d28-full-window-report":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d28-full-window-report requires the completed D28 full-window JSON"
                    )
                }
                sourceD28FullWindowReportPath = values[index]
            case "--source-d28-full-window-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d28-full-window-audit requires the independent D28 full-window audit"
                    )
                }
                sourceD28FullWindowAuditPath = values[index]
            case "--source-d32-preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d32-preregistration requires the locked D32 JSON"
                    )
                }
                sourceD32PreregistrationPath = values[index]
            case "--source-d32-pre-roll":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d32-pre-roll requires the completed D32 pre-roll JSON"
                    )
                }
                sourceD32PreRollPath = values[index]
            case "--source-d32-audit":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-d32-audit requires the independent D32 audit JSON"
                    )
                }
                sourceD32AuditPath = values[index]
            case "--source-targeted-full-window-report":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-targeted-full-window-report requires the matching D28 or D32 full-window JSON"
                    )
                }
                sourceTargetedFullWindowReportPath = values[index]
            case "--source-targeted-boundary-case":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--source-targeted-boundary-case requires the matching D28 or D32 targeted component JSON"
                    )
                }
                sourceTargetedBoundaryCasePath = values[index]
            case "--targeted-reference-length-cells":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      [28, 32].contains(value) else {
                    throw CLIError.invalidArgument(
                        "--targeted-reference-length-cells requires 28 or 32"
                    )
                }
                targetedReferenceLengthCells = value
            case "--reference-length-cells":
                index += 1
                guard index < values.count,
                      let value = Int(values[index]),
                      [8, 12].contains(value) else {
                    throw CLIError.invalidArgument(
                        "--reference-length-cells requires 8 or 12"
                    )
                }
                spatialReferenceLengthCells = value
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
            case "--coarse-fluid-pilot":
                coarseFluidPilot = true
            case "--collision-pre-roll-ab":
                collisionPreRollAB = true
            case "--collision-momentum-closure":
                collisionMomentumClosure = true
            case "--collision-extended-pilot":
                collisionExtendedPilot = true
            case "--collision-grid-preregister":
                collisionGridPreregister = true
            case "--collision-grid-discriminator":
                collisionGridDiscriminator = true
            case "--collision-grid-completion":
                collisionGridCompletion = true
            case "--collision-grid-provenance":
                collisionGridProvenance = true
            case "--collision-grid-boundary-decomposition":
                collisionGridBoundaryDecomposition = true
            case "--collision-grid-moving-wall-ab":
                collisionGridMovingWallAB = true
            case "--collision-grid-moving-wall-ledger":
                collisionGridMovingWallLedger = true
            case "--collision-grid-moving-wall-full-window":
                collisionGridMovingWallFullWindow = true
            case "--collision-grid-moving-wall-spatial-preregister":
                collisionGridMovingWallSpatialPreregister = true
            case "--collision-grid-moving-wall-spatial-case":
                collisionGridMovingWallSpatialCase = true
            case "--collision-grid-moving-wall-spatial-discriminator":
                collisionGridMovingWallSpatialDiscriminator = true
            case "--collision-grid-moving-wall-temporal-preregister":
                collisionGridMovingWallTemporalPreregister = true
            case "--collision-grid-moving-wall-temporal-sampling":
                collisionGridMovingWallTemporalSampling = true
            case "--collision-grid-moving-wall-temporal-duration-preregister":
                collisionGridMovingWallTemporalDurationPreregister = true
            case "--collision-grid-moving-wall-temporal-duration":
                collisionGridMovingWallTemporalDuration = true
            case "--collision-grid-moving-wall-link-geometry-preregister":
                collisionGridMovingWallLinkGeometryPreregister = true
            case "--collision-grid-moving-wall-link-geometry":
                collisionGridMovingWallLinkGeometry = true
            case "--collision-grid-moving-wall-link-velocity-preregister":
                collisionGridMovingWallLinkVelocityPreregister = true
            case "--collision-grid-moving-wall-link-velocity":
                collisionGridMovingWallLinkVelocity = true
            case "--collision-grid-moving-wall-link-intersection-preregister":
                collisionGridMovingWallLinkIntersectionPreregister = true
            case "--collision-grid-moving-wall-link-intersection":
                collisionGridMovingWallLinkIntersection = true
            case "--collision-grid-moving-wall-link-ray-root-preregister":
                collisionGridMovingWallLinkRayRootPreregister = true
            case "--collision-grid-moving-wall-link-ray-root":
                collisionGridMovingWallLinkRayRoot = true
            case "--collision-grid-moving-wall-link-coefficient-preregister":
                collisionGridMovingWallLinkCoefficientPreregister = true
            case "--collision-grid-moving-wall-link-coefficient":
                collisionGridMovingWallLinkCoefficient = true
            case "--collision-grid-moving-wall-link-population-preregister":
                collisionGridMovingWallLinkPopulationPreregister = true
            case "--collision-grid-moving-wall-link-population":
                collisionGridMovingWallLinkPopulation = true
            case "--collision-grid-moving-wall-distributed-force-preregister":
                collisionGridMovingWallDistributedForcePreregister = true
            case "--collision-grid-moving-wall-distributed-force":
                collisionGridMovingWallDistributedForce = true
            case "--collision-grid-moving-wall-force-covariance-preregister":
                collisionGridMovingWallForceCovariancePreregister = true
            case "--collision-grid-moving-wall-force-covariance":
                collisionGridMovingWallForceCovariance = true
            case "--collision-grid-moving-wall-spatial-interaction-preregister":
                collisionGridMovingWallSpatialInteractionPreregister = true
            case "--collision-grid-moving-wall-spatial-interaction":
                collisionGridMovingWallSpatialInteraction = true
            case "--source-viscosity-d16-preregister":
                sourceViscosityD16Preregister = true
            case "--source-viscosity-d16-ab":
                sourceViscosityD16AB = true
            case "--source-viscosity-d28-preregister":
                sourceViscosityD28Preregister = true
            case "--source-viscosity-d28-pre-roll":
                sourceViscosityD28PreRoll = true
            case "--source-viscosity-d28-full-window-preregister":
                sourceViscosityD28FullWindowPreregister = true
            case "--source-viscosity-d28-full-window":
                sourceViscosityD28FullWindow = true
            case "--source-viscosity-d32-preregister":
                sourceViscosityD32Preregister = true
            case "--source-viscosity-d32-pre-roll":
                sourceViscosityD32PreRoll = true
            case "--source-viscosity-d32-full-window-preregister":
                sourceViscosityD32FullWindowPreregister = true
            case "--source-viscosity-d32-full-window":
                sourceViscosityD32FullWindow = true
            case "--source-viscosity-targeted-boundary-case":
                sourceViscosityTargetedBoundaryCase = true
            case "--source-viscosity-reflected-provenance-case":
                sourceViscosityReflectedProvenanceCase = true
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
        let selectedModes = [
            couplingGate, coarseFluidPilot, collisionPreRollAB,
            collisionMomentumClosure, collisionExtendedPilot,
            collisionGridPreregister, collisionGridDiscriminator,
            collisionGridCompletion, collisionGridProvenance,
            collisionGridBoundaryDecomposition, collisionGridMovingWallAB,
            collisionGridMovingWallLedger, collisionGridMovingWallFullWindow,
            collisionGridMovingWallSpatialPreregister,
            collisionGridMovingWallSpatialCase,
            collisionGridMovingWallSpatialDiscriminator,
            collisionGridMovingWallTemporalPreregister,
            collisionGridMovingWallTemporalSampling,
            collisionGridMovingWallTemporalDurationPreregister,
            collisionGridMovingWallTemporalDuration,
            collisionGridMovingWallLinkGeometryPreregister,
            collisionGridMovingWallLinkGeometry,
            collisionGridMovingWallLinkVelocityPreregister,
            collisionGridMovingWallLinkVelocity,
            collisionGridMovingWallLinkIntersectionPreregister,
            collisionGridMovingWallLinkIntersection,
            collisionGridMovingWallLinkRayRootPreregister,
            collisionGridMovingWallLinkRayRoot,
            collisionGridMovingWallLinkCoefficientPreregister,
            collisionGridMovingWallLinkCoefficient,
            collisionGridMovingWallLinkPopulationPreregister,
            collisionGridMovingWallLinkPopulation,
            collisionGridMovingWallDistributedForcePreregister,
            collisionGridMovingWallDistributedForce,
            collisionGridMovingWallForceCovariancePreregister,
            collisionGridMovingWallForceCovariance,
            collisionGridMovingWallSpatialInteractionPreregister,
            collisionGridMovingWallSpatialInteraction,
            sourceViscosityD16Preregister,
            sourceViscosityD16AB,
            sourceViscosityD28Preregister,
            sourceViscosityD28PreRoll,
            sourceViscosityD28FullWindowPreregister,
            sourceViscosityD28FullWindow,
            sourceViscosityD32Preregister,
            sourceViscosityD32PreRoll,
            sourceViscosityD32FullWindowPreregister,
            sourceViscosityD32FullWindow,
            sourceViscosityTargetedBoundaryCase,
            sourceViscosityReflectedProvenanceCase
        ].filter { $0 }.count
        guard selectedModes <= 1 else {
            throw CLIError.invalidArgument(
                "choose only one measured-surface fluid validation mode"
            )
        }
        let needsForceTarget = coarseFluidPilot || collisionPreRollAB
            || collisionMomentumClosure || collisionExtendedPilot
            || collisionGridPreregister || collisionGridDiscriminator
            || collisionGridCompletion || collisionGridProvenance
            || collisionGridBoundaryDecomposition || collisionGridMovingWallAB
            || collisionGridMovingWallLedger
            || collisionGridMovingWallFullWindow
            || collisionGridMovingWallSpatialPreregister
            || collisionGridMovingWallSpatialCase
            || collisionGridMovingWallSpatialDiscriminator
            || collisionGridMovingWallTemporalPreregister
            || collisionGridMovingWallTemporalSampling
            || collisionGridMovingWallTemporalDurationPreregister
            || collisionGridMovingWallTemporalDuration
            || collisionGridMovingWallLinkGeometryPreregister
            || collisionGridMovingWallLinkGeometry
            || collisionGridMovingWallLinkVelocityPreregister
            || collisionGridMovingWallLinkVelocity
            || collisionGridMovingWallLinkIntersectionPreregister
            || collisionGridMovingWallLinkIntersection
            || collisionGridMovingWallLinkRayRootPreregister
            || collisionGridMovingWallLinkRayRoot
            || collisionGridMovingWallLinkCoefficientPreregister
            || collisionGridMovingWallLinkCoefficient
            || collisionGridMovingWallLinkPopulationPreregister
            || collisionGridMovingWallLinkPopulation
            || collisionGridMovingWallDistributedForcePreregister
            || collisionGridMovingWallDistributedForce
            || collisionGridMovingWallForceCovariancePreregister
            || collisionGridMovingWallForceCovariance
            || collisionGridMovingWallSpatialInteractionPreregister
            || collisionGridMovingWallSpatialInteraction
            || sourceViscosityD16Preregister
            || sourceViscosityD16AB
            || sourceViscosityD28Preregister
            || sourceViscosityD28PreRoll
            || sourceViscosityD28FullWindowPreregister
            || sourceViscosityD28FullWindow
            || sourceViscosityD32Preregister
            || sourceViscosityD32PreRoll
            || sourceViscosityD32FullWindowPreregister
            || sourceViscosityD32FullWindow
            || sourceViscosityTargetedBoundaryCase
            || sourceViscosityReflectedProvenanceCase
        guard needsForceTarget == (forceTargetPath != nil) else {
            throw CLIError.invalidArgument(
                "the coarse pilot and collision diagnostics require --force-target; other modes reject it"
            )
        }
        let contractPathsValid = sourceViscosityTargetedBoundaryCase
                || sourceViscosityReflectedProvenanceCase
            ? preregistrationPath != nil
                && discriminatorPath == nil && completionPath == nil
                && provenancePath == nil && boundaryTermsPath == nil
                && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD32FullWindowPreregister
            ? preregistrationPath == nil
                && discriminatorPath == nil && completionPath == nil
                && provenancePath == nil && boundaryTermsPath == nil
                && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD32FullWindow
                ? preregistrationPath != nil
                    && discriminatorPath == nil && completionPath == nil
                    && provenancePath == nil && boundaryTermsPath == nil
                    && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD32Preregister
            ? preregistrationPath == nil
                && discriminatorPath == nil && completionPath == nil
                && provenancePath == nil && boundaryTermsPath == nil
                && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD32PreRoll
                ? preregistrationPath != nil
                    && discriminatorPath == nil && completionPath == nil
                    && provenancePath == nil && boundaryTermsPath == nil
                    && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD28FullWindowPreregister
            ? preregistrationPath == nil
                && discriminatorPath == nil && completionPath == nil
                && provenancePath == nil && boundaryTermsPath == nil
                && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD28FullWindow
                ? preregistrationPath != nil
                    && discriminatorPath == nil && completionPath == nil
                    && provenancePath == nil && boundaryTermsPath == nil
                    && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD16Preregister
                    || sourceViscosityD28Preregister
            ? preregistrationPath == nil
                && discriminatorPath == nil && completionPath == nil
                && provenancePath == nil && boundaryTermsPath == nil
                && movingWallABPath == nil && movingWallLedgerPath == nil
            : sourceViscosityD16AB || sourceViscosityD28PreRoll
                ? preregistrationPath != nil
                    && discriminatorPath == nil && completionPath == nil
                    && provenancePath == nil && boundaryTermsPath == nil
                    && movingWallABPath == nil && movingWallLedgerPath == nil
            : collisionGridDiscriminator
            ? preregistrationPath != nil
                && discriminatorPath == nil && completionPath == nil
                && provenancePath == nil && boundaryTermsPath == nil
            : collisionGridCompletion
                ? preregistrationPath != nil
                    && discriminatorPath != nil && completionPath == nil
                    && provenancePath == nil && boundaryTermsPath == nil
                : collisionGridProvenance
                    ? preregistrationPath != nil
                        && discriminatorPath != nil && completionPath != nil
                        && provenancePath == nil && boundaryTermsPath == nil
                    : collisionGridBoundaryDecomposition
                        ? preregistrationPath != nil
                            && discriminatorPath != nil
                            && completionPath != nil && provenancePath != nil
                            && boundaryTermsPath == nil
                    : collisionGridMovingWallAB
                        ? preregistrationPath != nil
                            && discriminatorPath != nil
                            && completionPath != nil && provenancePath != nil
                            && boundaryTermsPath != nil
                            && movingWallABPath == nil
                    : collisionGridMovingWallLedger
                        ? preregistrationPath != nil
                            && discriminatorPath != nil
                            && completionPath != nil && provenancePath != nil
                            && boundaryTermsPath != nil
                            && movingWallABPath != nil
                            && movingWallLedgerPath == nil
                    : collisionGridMovingWallFullWindow
                        ? preregistrationPath != nil
                            && discriminatorPath != nil
                            && completionPath != nil && provenancePath != nil
                            && boundaryTermsPath != nil
                            && movingWallABPath != nil
                            && movingWallLedgerPath != nil
                    : collisionGridMovingWallSpatialCase
                        ? preregistrationPath != nil
                            && discriminatorPath != nil
                            && completionPath != nil && provenancePath != nil
                            && boundaryTermsPath != nil
                            && movingWallABPath != nil
                            && movingWallLedgerPath != nil
                    : collisionGridMovingWallSpatialPreregister
                            || collisionGridMovingWallSpatialDiscriminator
                        ? preregistrationPath == nil
                            && discriminatorPath == nil
                            && completionPath == nil && provenancePath == nil
                            && boundaryTermsPath == nil
                            && movingWallABPath == nil
                            && movingWallLedgerPath == nil
                    : preregistrationPath == nil
                        && discriminatorPath == nil && completionPath == nil
                        && provenancePath == nil && boundaryTermsPath == nil
                        && movingWallABPath == nil
                        && movingWallLedgerPath == nil
        guard contractPathsValid else {
            throw CLIError.invalidArgument(
                "the grid discriminator requires --preregistration; completion requires --discriminator; stage provenance requires --completion; boundary decomposition requires --provenance; moving-wall A/B also requires --boundary-terms; the candidate-A ledger additionally requires --moving-wall-ab; the full window additionally requires --moving-wall-ledger"
            )
        }
        let sourceScalingPathsValid = sourceViscosityD16Preregister
                || sourceViscosityD16AB
            ? sourceScalingPath != nil && sourceScalingAuditPath != nil
            : sourceScalingPath == nil && sourceScalingAuditPath == nil
        guard sourceScalingPathsValid else {
            throw CLIError.invalidArgument(
                "source-viscosity D16 modes require --source-scaling and --source-scaling-audit; all other modes reject them"
            )
        }
        let sourceD16PathsValid = sourceViscosityD28Preregister
                || sourceViscosityD28PreRoll
            ? sourceD16PreregistrationPath != nil
                && sourceD16ReportPath != nil
                && sourceD16AuditPath != nil
            : sourceD16PreregistrationPath == nil
                && sourceD16ReportPath == nil
                && sourceD16AuditPath == nil
        guard sourceD16PathsValid else {
            throw CLIError.invalidArgument(
                "source-viscosity D28 modes require --source-d16-preregistration, --source-d16-report, and --source-d16-audit; all other modes reject them"
            )
        }
        let sourceD28PathsValid = sourceViscosityD28FullWindowPreregister
                || sourceViscosityD28FullWindow
            ? sourceD28PreregistrationPath != nil
                && sourceD28PreRollPath != nil
                && sourceD28AuditPath != nil
            : sourceViscosityD32Preregister || sourceViscosityD32PreRoll
                ? sourceD28PreregistrationPath != nil
                    && sourceD28PreRollPath == nil
                    && sourceD28AuditPath == nil
                : sourceD28PreregistrationPath == nil
                    && sourceD28PreRollPath == nil
                    && sourceD28AuditPath == nil
        guard sourceD28PathsValid else {
            throw CLIError.invalidArgument(
                "source-viscosity D28 full-window modes require --source-d28-preregistration, --source-d28-pre-roll, and --source-d28-audit; all other modes reject them"
            )
        }
        let sourceD28FullWindowPathsValid = sourceViscosityD32Preregister
                || sourceViscosityD32PreRoll
            ? sourceD28FullWindowPreregistrationPath != nil
                && sourceD28FullWindowReportPath != nil
                && sourceD28FullWindowAuditPath != nil
            : sourceD28FullWindowPreregistrationPath == nil
                && sourceD28FullWindowReportPath == nil
                && sourceD28FullWindowAuditPath == nil
        guard sourceD28FullWindowPathsValid else {
            throw CLIError.invalidArgument(
                "source-viscosity D32 modes require the D28 full-window preregistration, report, and audit paths; all other modes reject them"
            )
        }
        let sourceD32PathsValid = sourceViscosityD32FullWindowPreregister
                || sourceViscosityD32FullWindow
            ? sourceD32PreregistrationPath != nil
                && sourceD32PreRollPath != nil
                && sourceD32AuditPath != nil
            : sourceD32PreregistrationPath == nil
                && sourceD32PreRollPath == nil
                && sourceD32AuditPath == nil
        guard sourceD32PathsValid else {
            throw CLIError.invalidArgument(
                "source-viscosity D32 full-window modes require --source-d32-preregistration, --source-d32-pre-roll, and --source-d32-audit; all other modes reject them"
            )
        }
        let targetedBoundaryPathsValid = sourceViscosityTargetedBoundaryCase
            ? sourceTargetedFullWindowReportPath != nil
                && sourceTargetedBoundaryCasePath == nil
                && targetedReferenceLengthCells != nil
            : sourceViscosityReflectedProvenanceCase
                ? sourceTargetedFullWindowReportPath == nil
                    && sourceTargetedBoundaryCasePath != nil
                    && targetedReferenceLengthCells != nil
                : sourceTargetedFullWindowReportPath == nil
                    && sourceTargetedBoundaryCasePath == nil
                    && targetedReferenceLengthCells == nil
        guard targetedBoundaryPathsValid else {
            throw CLIError.invalidArgument(
                "targeted boundary replay requires --source-targeted-full-window-report; reflected provenance requires --source-targeted-boundary-case; both require --targeted-reference-length-cells and other modes reject these paths"
            )
        }
        guard (collisionGridMovingWallLedger
                || collisionGridMovingWallFullWindow
                || collisionGridMovingWallSpatialCase)
                == (movingWallABPath != nil),
              (collisionGridMovingWallFullWindow
                || collisionGridMovingWallSpatialCase)
                == (movingWallLedgerPath != nil) else {
            throw CLIError.invalidArgument(
                "moving-wall evidence paths are accepted only by their candidate-A ledger modes"
            )
        }
        let spatialPathsValid = collisionGridMovingWallSpatialPreregister
            ? movingWallFullWindowPath != nil
                && spatialPreregistrationPath == nil
                && spatialD8Path == nil && spatialD12Path == nil
                && spatialReferenceLengthCells == nil
            : collisionGridMovingWallSpatialCase
                ? movingWallFullWindowPath != nil
                    && spatialPreregistrationPath != nil
                    && spatialD8Path == nil && spatialD12Path == nil
                    && spatialReferenceLengthCells != nil
                : collisionGridMovingWallSpatialDiscriminator
                    ? movingWallFullWindowPath != nil
                        && spatialPreregistrationPath != nil
                        && spatialD8Path != nil && spatialD12Path != nil
                        && spatialReferenceLengthCells == nil
                    : movingWallFullWindowPath == nil
                        && spatialPreregistrationPath == nil
                        && spatialD8Path == nil && spatialD12Path == nil
                        && spatialReferenceLengthCells == nil
        guard spatialPathsValid else {
            throw CLIError.invalidArgument(
                "spatial preregistration requires --moving-wall-full-window; a spatial case additionally requires --spatial-preregistration and --reference-length-cells; the discriminator requires --spatial-preregistration, --spatial-d8, and --spatial-d12"
            )
        }
        let distributedForceMode =
            collisionGridMovingWallDistributedForcePreregister
                || collisionGridMovingWallDistributedForce
        let temporalPathsValid = distributedForceMode
            ? spatialDiscriminatorPath == nil && lagBandPath == nil
                && temporalPreregistrationPath == nil
                && temporalSamplingPath == nil
                && temporalDurationPreregistrationPath != nil
                && temporalDurationPath != nil
                && linkGeometryPreregistrationPath != nil
                && linkGeometryPath != nil
                && linkVelocityPreregistrationPath == nil
                && linkVelocityPath == nil
                && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallLinkPopulationPreregister
                || collisionGridMovingWallLinkPopulation
            ? spatialDiscriminatorPath == nil && lagBandPath == nil
                && temporalPreregistrationPath == nil
                && temporalSamplingPath == nil
                && temporalDurationPreregistrationPath != nil
                && temporalDurationPath != nil
                && linkGeometryPreregistrationPath == nil
                && linkGeometryPath == nil
                && linkVelocityPreregistrationPath == nil
                && linkVelocityPath == nil
                && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallLinkRayRootPreregister
            ? spatialDiscriminatorPath == nil && lagBandPath == nil
                && temporalPreregistrationPath == nil
                && temporalSamplingPath == nil
                && temporalDurationPreregistrationPath == nil
                && temporalDurationPath == nil
                && linkGeometryPreregistrationPath == nil
                && linkGeometryPath == nil
                && linkVelocityPreregistrationPath == nil
                && linkVelocityPath == nil
                && linkIntersectionPreregistrationPath != nil
                && linkIntersectionPath != nil
                && linkRayRootPreregistrationPath == nil
            : collisionGridMovingWallLinkRayRoot
                ? spatialDiscriminatorPath == nil && lagBandPath == nil
                    && temporalPreregistrationPath == nil
                    && temporalSamplingPath == nil
                    && temporalDurationPreregistrationPath == nil
                    && temporalDurationPath == nil
                    && linkGeometryPreregistrationPath == nil
                    && linkGeometryPath == nil
                    && linkVelocityPreregistrationPath == nil
                    && linkVelocityPath == nil
                    && linkIntersectionPreregistrationPath != nil
                    && linkIntersectionPath != nil
                    && linkRayRootPreregistrationPath != nil
            : collisionGridMovingWallLinkIntersectionPreregister
            ? spatialDiscriminatorPath == nil && lagBandPath == nil
                && temporalPreregistrationPath == nil
                && temporalSamplingPath == nil
                && temporalDurationPreregistrationPath == nil
                && temporalDurationPath == nil
                && linkGeometryPreregistrationPath == nil
                && linkGeometryPath == nil
                && linkVelocityPreregistrationPath != nil
                && linkVelocityPath != nil
                && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallLinkIntersection
                ? spatialDiscriminatorPath == nil && lagBandPath == nil
                    && temporalPreregistrationPath == nil
                    && temporalSamplingPath == nil
                    && temporalDurationPreregistrationPath == nil
                    && temporalDurationPath == nil
                    && linkGeometryPreregistrationPath == nil
                    && linkGeometryPath == nil
                    && linkVelocityPreregistrationPath != nil
                    && linkVelocityPath != nil
                    && linkIntersectionPreregistrationPath != nil
            : collisionGridMovingWallLinkVelocityPreregister
            ? spatialDiscriminatorPath == nil && lagBandPath == nil
                && temporalPreregistrationPath == nil
                && temporalSamplingPath == nil
                && temporalDurationPreregistrationPath == nil
                && temporalDurationPath == nil
                && linkGeometryPreregistrationPath != nil
                && linkGeometryPath != nil
                && linkVelocityPreregistrationPath == nil
                && linkVelocityPath == nil
                && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallLinkVelocity
                ? spatialDiscriminatorPath == nil && lagBandPath == nil
                    && temporalPreregistrationPath == nil
                    && temporalSamplingPath == nil
                    && temporalDurationPreregistrationPath == nil
                    && temporalDurationPath == nil
                    && linkGeometryPreregistrationPath != nil
                    && linkGeometryPath != nil
                    && linkVelocityPreregistrationPath != nil
                    && linkVelocityPath == nil
                    && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallLinkGeometryPreregister
            ? spatialDiscriminatorPath == nil && lagBandPath == nil
                && temporalPreregistrationPath == nil
                && temporalSamplingPath == nil
                && temporalDurationPreregistrationPath != nil
                && temporalDurationPath != nil
                && linkGeometryPreregistrationPath == nil
                && linkGeometryPath == nil
                && linkVelocityPreregistrationPath == nil
                && linkVelocityPath == nil
                && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallLinkGeometry
                ? spatialDiscriminatorPath == nil && lagBandPath == nil
                    && temporalPreregistrationPath == nil
                    && temporalSamplingPath == nil
                    && temporalDurationPreregistrationPath != nil
                    && temporalDurationPath != nil
                    && linkGeometryPreregistrationPath != nil
                    && linkGeometryPath == nil
                    && linkVelocityPreregistrationPath == nil
                    && linkVelocityPath == nil
                    && linkIntersectionPreregistrationPath == nil
            : collisionGridMovingWallTemporalPreregister
                ? spatialDiscriminatorPath != nil && lagBandPath != nil
                    && temporalPreregistrationPath == nil
                    && temporalSamplingPath == nil
                    && temporalDurationPreregistrationPath == nil
                    && temporalDurationPath == nil
                    && linkGeometryPreregistrationPath == nil
                    && linkGeometryPath == nil
                    && linkVelocityPreregistrationPath == nil
                    && linkVelocityPath == nil
                    && linkIntersectionPreregistrationPath == nil
                : collisionGridMovingWallTemporalSampling
                    ? spatialDiscriminatorPath != nil && lagBandPath != nil
                        && temporalPreregistrationPath != nil
                        && temporalSamplingPath == nil
                        && temporalDurationPreregistrationPath == nil
                        && temporalDurationPath == nil
                        && linkGeometryPreregistrationPath == nil
                        && linkGeometryPath == nil
                        && linkVelocityPreregistrationPath == nil
                        && linkVelocityPath == nil
                        && linkIntersectionPreregistrationPath == nil
                    : collisionGridMovingWallTemporalDurationPreregister
                        ? spatialDiscriminatorPath == nil && lagBandPath == nil
                            && temporalPreregistrationPath != nil
                            && temporalSamplingPath != nil
                            && temporalDurationPreregistrationPath == nil
                            && temporalDurationPath == nil
                            && linkGeometryPreregistrationPath == nil
                            && linkGeometryPath == nil
                            && linkVelocityPreregistrationPath == nil
                            && linkVelocityPath == nil
                            && linkIntersectionPreregistrationPath == nil
                        : collisionGridMovingWallTemporalDuration
                            ? spatialDiscriminatorPath != nil && lagBandPath != nil
                                && temporalPreregistrationPath != nil
                                && temporalSamplingPath != nil
                                && temporalDurationPreregistrationPath != nil
                                && temporalDurationPath == nil
                                && linkGeometryPreregistrationPath == nil
                                && linkGeometryPath == nil
                                && linkVelocityPreregistrationPath == nil
                                && linkVelocityPath == nil
                                && linkIntersectionPreregistrationPath == nil
                            : spatialDiscriminatorPath == nil && lagBandPath == nil
                                && temporalPreregistrationPath == nil
                                && temporalSamplingPath == nil
                                && temporalDurationPreregistrationPath == nil
                                && temporalDurationPath == nil
                                && linkGeometryPreregistrationPath == nil
                                && linkGeometryPath == nil
                                && linkVelocityPreregistrationPath == nil
                                && linkVelocityPath == nil
                                && linkIntersectionPreregistrationPath == nil
        guard temporalPathsValid else {
            throw CLIError.invalidArgument(
                "temporal and link diagnostic evidence paths do not match the selected mode"
            )
        }
        let rayPathsValid = distributedForceMode
            ? linkIntersectionPath == nil
                && linkRayRootPreregistrationPath == nil
                && linkRayRootPath == nil
                && linkCoefficientPreregistrationPath == nil
                && linkCoefficientPath == nil
            : collisionGridMovingWallLinkRayRootPreregister
            ? linkIntersectionPath != nil
                && linkRayRootPreregistrationPath == nil
                && linkRayRootPath == nil
                && linkCoefficientPreregistrationPath == nil
            : collisionGridMovingWallLinkRayRoot
                ? linkIntersectionPath != nil
                    && linkRayRootPreregistrationPath != nil
                    && linkRayRootPath == nil
                    && linkCoefficientPreregistrationPath == nil
                : collisionGridMovingWallLinkCoefficientPreregister
                    ? linkIntersectionPath == nil
                        && linkRayRootPreregistrationPath != nil
                        && linkRayRootPath != nil
                        && linkCoefficientPreregistrationPath == nil
                : collisionGridMovingWallLinkCoefficient
                        ? linkIntersectionPath == nil
                            && linkRayRootPreregistrationPath != nil
                            && linkRayRootPath != nil
                            && linkCoefficientPreregistrationPath != nil
                    : collisionGridMovingWallLinkPopulationPreregister
                        ? linkIntersectionPath == nil
                            && linkRayRootPreregistrationPath == nil
                            && linkRayRootPath == nil
                            && linkCoefficientPreregistrationPath != nil
                            && linkCoefficientPath != nil
                            && linkPopulationPreregistrationPath == nil
                        : collisionGridMovingWallLinkPopulation
                            ? linkIntersectionPath == nil
                                && linkRayRootPreregistrationPath == nil
                                && linkRayRootPath == nil
                                && linkCoefficientPreregistrationPath != nil
                                && linkCoefficientPath != nil
                                && linkPopulationPreregistrationPath != nil
                            : linkIntersectionPath == nil
                                && linkRayRootPreregistrationPath == nil
                                && linkRayRootPath == nil
                                && linkCoefficientPreregistrationPath == nil
                                && linkCoefficientPath == nil
                                && linkPopulationPreregistrationPath == nil
        guard rayPathsValid else {
            throw CLIError.invalidArgument(
                "ray-root and coefficient evidence paths do not match the selected mode"
            )
        }
        let forceCovarianceMode =
            collisionGridMovingWallForceCovariancePreregister
                || collisionGridMovingWallForceCovariance
        let spatialInteractionMode =
            collisionGridMovingWallSpatialInteractionPreregister
                || collisionGridMovingWallSpatialInteraction
        let distributedForcePathsValid = spatialInteractionMode
            ? linkPopulationPreregistrationPath == nil
                && linkPopulationPath == nil
                && linkPopulationAuditPath == nil
                && distributedForcePreregistrationPath == nil
                && distributedForcePath != nil
                && distributedForceAuditPath == nil
            : forceCovarianceMode
            ? linkPopulationPreregistrationPath == nil
                && linkPopulationPath == nil
                && linkPopulationAuditPath == nil
                && distributedForcePreregistrationPath != nil
                && distributedForcePath != nil
                && distributedForceAuditPath != nil
            : collisionGridMovingWallDistributedForcePreregister
            ? linkPopulationPreregistrationPath != nil
                && linkPopulationPath != nil
                && linkPopulationAuditPath != nil
                && distributedForcePreregistrationPath == nil
                && distributedForcePath == nil
                && distributedForceAuditPath == nil
            : collisionGridMovingWallDistributedForce
                ? linkPopulationPreregistrationPath != nil
                    && linkPopulationPath != nil
                    && linkPopulationAuditPath != nil
                    && distributedForcePreregistrationPath != nil
                    && distributedForcePath == nil
                    && distributedForceAuditPath == nil
                : linkPopulationPath == nil
                    && linkPopulationAuditPath == nil
                    && distributedForcePreregistrationPath == nil
                    && distributedForcePath == nil
                    && distributedForceAuditPath == nil
        guard distributedForcePathsValid else {
            throw CLIError.invalidArgument(
                "distributed-force modes require the geometry, duration, population report/audit, and locked distributed-force evidence paths"
            )
        }
        let covariancePathsValid =
            collisionGridMovingWallForceCovariancePreregister
            ? forceCovariancePreregistrationPath == nil
                && forceCovariancePath == nil
                && forceCovarianceAuditPath == nil
                && spatialInteractionPreregistrationPath == nil
            : collisionGridMovingWallForceCovariance
                ? forceCovariancePreregistrationPath != nil
                    && forceCovariancePath == nil
                    && forceCovarianceAuditPath == nil
                    && spatialInteractionPreregistrationPath == nil
                : collisionGridMovingWallSpatialInteractionPreregister
                    ? forceCovariancePreregistrationPath != nil
                        && forceCovariancePath != nil
                        && forceCovarianceAuditPath != nil
                        && spatialInteractionPreregistrationPath == nil
                    : collisionGridMovingWallSpatialInteraction
                        ? forceCovariancePreregistrationPath != nil
                            && forceCovariancePath != nil
                            && forceCovarianceAuditPath != nil
                            && spatialInteractionPreregistrationPath != nil
                        : forceCovariancePreregistrationPath == nil
                            && forceCovariancePath == nil
                            && forceCovarianceAuditPath == nil
                            && spatialInteractionPreregistrationPath == nil
        guard covariancePathsValid else {
            throw CLIError.invalidArgument(
                "force-covariance execution requires its locked preregistration; other modes reject it"
            )
        }
        if collisionGridPreregister || collisionGridDiscriminator
            || collisionGridCompletion || collisionGridProvenance
            || collisionGridBoundaryDecomposition || collisionGridMovingWallAB
            || collisionGridMovingWallLedger
            || collisionGridMovingWallFullWindow
            || collisionGridMovingWallSpatialPreregister
            || collisionGridMovingWallSpatialCase
            || collisionGridMovingWallSpatialDiscriminator
            || collisionGridMovingWallTemporalPreregister
            || collisionGridMovingWallTemporalSampling
            || collisionGridMovingWallTemporalDurationPreregister
            || collisionGridMovingWallTemporalDuration
            || collisionGridMovingWallLinkGeometryPreregister
            || collisionGridMovingWallLinkGeometry
            || collisionGridMovingWallLinkVelocityPreregister
            || collisionGridMovingWallLinkVelocity
            || collisionGridMovingWallLinkIntersectionPreregister
            || collisionGridMovingWallLinkIntersection
            || collisionGridMovingWallLinkRayRootPreregister
            || collisionGridMovingWallLinkRayRoot
            || collisionGridMovingWallLinkCoefficientPreregister
            || collisionGridMovingWallLinkCoefficient
            || collisionGridMovingWallLinkPopulationPreregister
            || collisionGridMovingWallLinkPopulation
            || collisionGridMovingWallDistributedForcePreregister
            || collisionGridMovingWallDistributedForce
            || collisionGridMovingWallForceCovariancePreregister
            || collisionGridMovingWallForceCovariance
            || collisionGridMovingWallSpatialInteractionPreregister
            || collisionGridMovingWallSpatialInteraction
            || sourceViscosityD16Preregister
            || sourceViscosityD16AB
            || sourceViscosityD28Preregister
            || sourceViscosityD28PreRoll
            || sourceViscosityD28FullWindowPreregister
            || sourceViscosityD28FullWindow
            || sourceViscosityD32Preregister
            || sourceViscosityD32PreRoll
            || sourceViscosityD32FullWindowPreregister
            || sourceViscosityD32FullWindow
            || sourceViscosityTargetedBoundaryCase
            || sourceViscosityReflectedProvenanceCase {
            guard cellSizeMeters == 0.01,
                  halfThicknessCells == 0.75 else {
                throw CLIError.invalidArgument(
                    "grid workflow resolution and thickness are preregistered and reject manual overrides"
                )
            }
        }
    }

    static let help = """
    birdflow replay measured-bird-surface --input MANIFEST.json [options]

      --cell-size-meters V      Geometry-audit cell size (default: 0.01)
      --half-thickness-cells V  Sheet half-thickness (default: 0.75)
      --coupling-gate            Run the short production fluid/impulse gate
      --coarse-fluid-pilot       Run the preregistered viscosity-floor fluid pilot
      --collision-pre-roll-ab    Screen TRT/regularized/RR3 for 800 fixed steps
      --collision-momentum-closure
                                 Close both surviving candidates against near-wing and global momentum
      --collision-extended-pilot Run both momentum-closed candidates through all 3,776 fixed steps
      --collision-grid-preregister
                                 Freeze the fixed-physics D=8/12 discriminator and single-winner D=16 contract
      --collision-grid-discriminator
                                 Run both candidates at D=8/12 under --preregistration
      --collision-grid-completion
                                 Run only the authorized winner at D=16
      --collision-grid-provenance
                                 Replay the failed D=16 winner with sparse stage-resolved population capture
      --collision-grid-boundary-decomposition
                                 Decompose the failed cell's reflected, wall, interpolation, and counterfactual terms
      --collision-grid-moving-wall-ab
                                 Compare local-density normalization with a global positivity-admissible wall scale
      --collision-grid-moving-wall-ledger
                                 Run candidate A at D=16 through the retained failure step with near-wing/global ledgers
      --collision-grid-moving-wall-full-window
                                 Extend the retained candidate A through all 7,552 registered D=16 steps
      --collision-grid-moving-wall-spatial-preregister
                                 Freeze the candidate-A D=8/12 cases and D=16 reuse convergence contract
      --collision-grid-moving-wall-spatial-case
                                 Run one locked full-window D=8 or D=12 candidate-A case
      --collision-grid-moving-wall-spatial-discriminator
                                 Combine the D=8/12 cases with the hashed D=16 archive
      --collision-grid-moving-wall-temporal-preregister
                                 Freeze the fixed-geometry D12/D16 temporal-sampling contract
      --collision-grid-moving-wall-temporal-sampling
                                 Run the locked fixed-geometry D12/D16 aggregation discriminator
      --collision-grid-moving-wall-temporal-duration-preregister
                                 Freeze the same-phase 24-bin duration extension
      --collision-grid-moving-wall-temporal-duration
                                 Run the locked 8/16/24-bin duration discriminator
      --collision-grid-moving-wall-link-geometry-preregister
                                 Freeze the same-phase D12/D16 production-link audit
      --collision-grid-moving-wall-link-geometry
                                 Run the geometry-only link/q/wall-moment discriminator
      --collision-grid-moving-wall-link-velocity-preregister
                                 Freeze the solid-node/link-intersection velocity A/B
      --collision-grid-moving-wall-link-velocity
                                 Run the no-fluid link-velocity sampling discriminator
      --collision-grid-moving-wall-link-intersection-preregister
                                 Freeze sparse intersection-outlier localization
      --collision-grid-moving-wall-link-intersection
                                 Archive and classify every >0.75-cell link outlier
      --collision-grid-moving-wall-link-ray-root-preregister
                                 Freeze owner-component versus global-union exact roots
      --collision-grid-moving-wall-link-ray-root
                                 Run the archive-only 15-link exact ray-root A/B
      --collision-grid-moving-wall-link-coefficient-preregister
                                 Freeze the 15-link q-dependent operator bound
      --collision-grid-moving-wall-link-coefficient
                                 Reconstruct linear-q versus exact-q coefficients
      --collision-grid-moving-wall-link-population-preregister
                                 Freeze the 576-step D12 production-primitive replay
      --collision-grid-moving-wall-link-population
                                 Replay realized production-q versus exact-q loads
      --collision-grid-moving-wall-distributed-force-preregister
                                 Freeze the full-link D12/D16 force-term discriminator
      --collision-grid-moving-wall-distributed-force
                                 Attribute distributed grid bias across reflection, wall, and interpolation terms
      --collision-grid-moving-wall-force-covariance-preregister
                                 Freeze the archive-only three-term covariance discriminator
      --collision-grid-moving-wall-force-covariance
                                 Decompose coherent and canceling D12/D16 term pairs
      --collision-grid-moving-wall-spatial-interaction-preregister
                                 Freeze exact spatial allocation of the dominant mean interaction
      --collision-grid-moving-wall-spatial-interaction
                                 Map reflection-wall cancellation across component, direction, and q
      --source-viscosity-d16-preregister
                                 Freeze the diagnostic-only D16 source-viscosity two-operator contract
      --source-viscosity-d16-ab  Run both locked source-viscosity operators with per-step momentum and positivity gates
      --source-viscosity-d28-preregister
                                 Select one D16-cleared operator and freeze the first production-margin pre-roll
      --source-viscosity-d28-pre-roll
                                 Run the locked single-operator 2,800-step D28 gate
      --source-viscosity-d28-full-window-preregister
                                 Freeze the RR3-only 13,216-step D28 force-window contract
      --source-viscosity-d28-full-window
                                 Run the locked D28 source-viscosity force window
      --source-viscosity-d32-preregister
                                 Freeze one RR3 3,200-step D32 pre-roll from audited D28 evidence
      --source-viscosity-d32-pre-roll
                                 Run the locked D32 survival and momentum discriminator
      --source-viscosity-d32-full-window-preregister
                                 Freeze the RR3-only 15,104-step D32 force-window contract
      --source-viscosity-d32-full-window
                                 Run the locked D32 source-viscosity force window
      --source-viscosity-targeted-boundary-case
                                 Replay D28 or D32 boundary-force components in the locked 25--30 ms band
      --source-viscosity-reflected-provenance-case
                                 Capture high-influence reflected-link population/q/topology provenance
      --source-scaling FILE      SHA-locked source fluid/scaling reconstruction JSON
      --source-scaling-audit FILE
                                 Independent source-scaling audit JSON
      --source-d16-preregistration FILE
                                 Locked D16 source-viscosity preregistration JSON
      --source-d16-report FILE   Completed D16 source-viscosity A/B JSON
      --source-d16-audit FILE    Independent D16 source-viscosity audit JSON
      --source-d28-preregistration FILE
                                 Locked D28 production-margin preregistration JSON
      --source-d28-pre-roll FILE Completed D28 production-margin pre-roll JSON
      --source-d28-audit FILE    Independent D28 pre-roll audit JSON
      --source-d28-full-window-preregistration FILE
                                 Locked D28 full-window preregistration JSON
      --source-d28-full-window-report FILE
                                 Completed D28 full-window report JSON
      --source-d28-full-window-audit FILE
                                 Independent D28 full-window audit JSON
      --source-d32-preregistration FILE
                                 Locked D32 source-viscosity preregistration JSON
      --source-d32-pre-roll FILE Completed D32 pre-roll JSON
      --source-d32-audit FILE    Independent D32 pre-roll audit JSON
      --source-targeted-full-window-report FILE
                                 Matching D28 or D32 full-window source JSON for component replay
      --source-targeted-boundary-case FILE
                                 Matching D28 or D32 targeted component case for reflected provenance
      --targeted-reference-length-cells 28|32
                                 Select the locked D28 or D32 targeted grid
      --preregistration FILE     Locked grid preregistration JSON
      --discriminator FILE       Completed D=8/12 discriminator JSON
      --completion FILE          Failed selected-operator D=16 completion JSON
      --provenance FILE          Passed D=16 population-stage provenance JSON
      --boundary-terms FILE      Passed D=16 moving-boundary decomposition JSON
      --moving-wall-ab FILE      Passed D=16 moving-wall admissibility A/B JSON
      --moving-wall-ledger FILE  Passed 751-step candidate-A ledger JSON
      --moving-wall-full-window FILE
                                 Passed 7,552-step candidate-A D=16 full-window JSON
      --spatial-preregistration FILE
                                 Locked candidate-A spatial preregistration JSON
      --spatial-d8 FILE          Completed candidate-A D=8 full-window case JSON
      --spatial-d12 FILE         Completed candidate-A D=12 full-window case JSON
      --spatial-discriminator FILE
                                 Completed candidate-A D=8/12/16 spatial discriminator JSON
      --lag-band FILE            Completed source-locked D12/D16 lag/band artifact
      --temporal-preregistration FILE
                                 Locked fixed-geometry temporal-sampling preregistration JSON
      --temporal-sampling FILE   Completed eight-bin fixed-geometry report
      --temporal-duration-preregistration FILE
                                 Locked same-phase 24-bin duration preregistration JSON
      --temporal-duration FILE   Completed same-phase 24-bin duration report
      --link-geometry-preregistration FILE
                                 Locked geometry-only link audit preregistration JSON
      --link-geometry FILE       Completed geometry-only link audit report
      --link-velocity-preregistration FILE
                                 Locked link-velocity A/B preregistration JSON
      --link-velocity FILE       Completed link-velocity A/B report
      --link-intersection-preregistration FILE
                                 Locked sparse intersection localization JSON
      --link-intersection FILE   Completed sparse intersection localization report
      --link-ray-root-preregistration FILE
                                 Locked exact ray-root A/B preregistration JSON
      --link-ray-root FILE       Completed exact ray-root A/B report
      --link-coefficient-preregistration FILE
                                 Locked coefficient-sensitivity preregistration JSON
      --link-coefficient FILE    Completed coefficient-sensitivity report
      --link-population-preregistration FILE
                                 Locked realized-population replay preregistration JSON
      --link-population FILE     Completed realized-population replay report
      --link-population-audit FILE
                                 Passed independent realized-population audit JSON
      --distributed-force-preregistration FILE
                                 Locked full-link force-term preregistration JSON
      --distributed-force FILE  Completed full-link D12/D16 force report
      --distributed-force-audit FILE
                                 Passed independent distributed-force audit JSON
      --force-covariance-preregistration FILE
                                 Locked archive-only covariance preregistration JSON
      --force-covariance FILE   Completed force covariance report
      --force-covariance-audit FILE
                                 Passed independent force covariance audit JSON
      --spatial-interaction-preregistration FILE
                                 Locked spatial interaction preregistration JSON
      --reference-length-cells N Spatial case grid; exactly 8 or 12
      --force-target FILE        Registered measured two-component force target
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

private struct DirectionCompositionArguments {
    let preregistrationPath: String
    let archivePath: String?
    let json: Bool

    init(_ values: [String]) throws {
        var preregistrationPath: String?
        var archivePath: String?
        var json = false
        var index = 3
        while index < values.count {
            switch values[index] {
            case "--preregistration":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--preregistration requires a JSON path"
                    )
                }
                preregistrationPath = values[index]
            case "--archive":
                index += 1
                guard index < values.count else {
                    throw CLIError.invalidArgument(
                        "--archive requires an output JSON path"
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
                    "Unknown direction-composition option: \(values[index])"
                )
            }
            index += 1
        }
        guard let preregistrationPath else {
            throw CLIError.invalidArgument(
                "direction-composition requires --preregistration FILE"
            )
        }
        self.preregistrationPath = preregistrationPath
        self.archivePath = archivePath
        self.json = json
    }

    static let help = """
    birdflow validate direction-composition --preregistration FILE [options]

      --archive FILE          Atomically write the canonical report
      --json                  Emit the machine-readable report
      --help                  Show this help

    Runs the preregistered static, no-fluid Metal/CPU oblique-plane direction
    counting canonical at two grids and five subcell phases.
    """
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

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data)
        .map { String(format: "%02x", $0) }
        .joined()
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
    func artifactData(_ path: String) throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: path))
    }
    func decodeArtifact<T: Decodable>(
        _ type: T.Type,
        path: String
    ) throws -> T {
        try JSONDecoder().decode(type, from: artifactData(path))
    }
    func distributedForceEvidence() throws -> (
        geometryPreregistrationData: Data,
        geometryPreregistration:
            MetalIndexedBirdSurfaceLinkGeometryPreregistration,
        geometryReportData: Data,
        geometryReport: MetalIndexedBirdSurfaceLinkGeometryReport,
        durationPreregistrationData: Data,
        durationPreregistration:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration,
        durationReportData: Data,
        durationReport:
            MetalIndexedBirdSurfaceMovingWallTemporalDurationReport,
        populationPreregistrationData: Data,
        populationPreregistration:
            MetalIndexedBirdSurfaceLinkPopulationPreregistration,
        populationReportData: Data,
        populationReport: MetalIndexedBirdSurfaceLinkPopulationReport,
        populationAuditData: Data,
        populationAuditPassed: Bool
    ) {
        let geometryPreregistrationData = try artifactData(
            arguments.linkGeometryPreregistrationPath!
        )
        let geometryReportData = try artifactData(arguments.linkGeometryPath!)
        let durationPreregistrationData = try artifactData(
            arguments.temporalDurationPreregistrationPath!
        )
        let durationReportData = try artifactData(arguments.temporalDurationPath!)
        let populationPreregistrationData = try artifactData(
            arguments.linkPopulationPreregistrationPath!
        )
        let populationReportData = try artifactData(
            arguments.linkPopulationPath!
        )
        let populationAuditData = try artifactData(
            arguments.linkPopulationAuditPath!
        )
        let populationAuditObject = try JSONSerialization.jsonObject(
            with: populationAuditData
        )
        let populationAuditPassed = (
            populationAuditObject as? [String: Any]
        )?["allChecksPassed"] as? Bool ?? false
        return (
            geometryPreregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceLinkGeometryPreregistration.self,
                from: geometryPreregistrationData
            ),
            geometryReportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceLinkGeometryReport.self,
                from: geometryReportData
            ),
            durationPreregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self,
                from: durationPreregistrationData
            ),
            durationReportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self,
                from: durationReportData
            ),
            populationPreregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceLinkPopulationPreregistration.self,
                from: populationPreregistrationData
            ),
            populationReportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceLinkPopulationReport.self,
                from: populationReportData
            ),
            populationAuditData,
            populationAuditPassed
        )
    }
    func forceCovarianceEvidence() throws -> (
        preregistrationData: Data,
        preregistration:
            MetalIndexedBirdSurfaceDistributedForcePreregistration,
        reportData: Data,
        report: MetalIndexedBirdSurfaceDistributedForceReport,
        auditData: Data,
        auditPassed: Bool
    ) {
        let preregistrationData = try artifactData(
            arguments.distributedForcePreregistrationPath!
        )
        let reportData = try artifactData(arguments.distributedForcePath!)
        let auditData = try artifactData(arguments.distributedForceAuditPath!)
        let auditObject = try JSONSerialization.jsonObject(with: auditData)
        let auditPassed = (
            auditObject as? [String: Any]
        )?["allChecksPassed"] as? Bool ?? false
        return (
            preregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceDistributedForcePreregistration.self,
                from: preregistrationData
            ),
            reportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceDistributedForceReport.self,
                from: reportData
            ),
            auditData,
            auditPassed
        )
    }
    func spatialInteractionEvidence() throws -> (
        distributedReportData: Data,
        distributedReport: MetalIndexedBirdSurfaceDistributedForceReport,
        covariancePreregistrationData: Data,
        covariancePreregistration:
            MetalIndexedBirdSurfaceForceCovariancePreregistration,
        covarianceReportData: Data,
        covarianceReport: MetalIndexedBirdSurfaceForceCovarianceReport,
        covarianceAuditData: Data,
        covarianceAuditPassed: Bool
    ) {
        let distributedReportData = try artifactData(
            arguments.distributedForcePath!
        )
        let covariancePreregistrationData = try artifactData(
            arguments.forceCovariancePreregistrationPath!
        )
        let covarianceReportData = try artifactData(
            arguments.forceCovariancePath!
        )
        let covarianceAuditData = try artifactData(
            arguments.forceCovarianceAuditPath!
        )
        let auditObject = try JSONSerialization.jsonObject(
            with: covarianceAuditData
        )
        let auditPassed = (
            auditObject as? [String: Any]
        )?["allChecksPassed"] as? Bool ?? false
        return (
            distributedReportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceDistributedForceReport.self,
                from: distributedReportData
            ),
            covariancePreregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceForceCovariancePreregistration.self,
                from: covariancePreregistrationData
            ),
            covarianceReportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceForceCovarianceReport.self,
                from: covarianceReportData
            ),
            covarianceAuditData,
            auditPassed
        )
    }
    func sourceScalingEvidence() throws -> (
        reportData: Data,
        report: MetalIndexedBirdSurfaceSourceScalingEvidence,
        auditData: Data,
        audit: MetalIndexedBirdSurfaceSourceScalingAuditEvidence
    ) {
        let reportData = try artifactData(arguments.sourceScalingPath!)
        let auditData = try artifactData(arguments.sourceScalingAuditPath!)
        return (
            reportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceScalingEvidence.self,
                from: reportData
            ),
            auditData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceScalingAuditEvidence.self,
                from: auditData
            )
        )
    }
    func sourceD16Evidence() throws -> (
        preregistrationData: Data,
        preregistration:
            MetalIndexedBirdSurfaceSourceViscosityPreregistration,
        reportData: Data,
        report: MetalIndexedBirdSurfaceSourceViscosityReport,
        auditData: Data,
        audit: MetalIndexedBirdSurfaceSourceViscosityAuditEvidence
    ) {
        let preregistrationData = try artifactData(
            arguments.sourceD16PreregistrationPath!
        )
        let reportData = try artifactData(arguments.sourceD16ReportPath!)
        let auditData = try artifactData(arguments.sourceD16AuditPath!)
        return (
            preregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityPreregistration.self,
                from: preregistrationData
            ),
            reportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityReport.self,
                from: reportData
            ),
            auditData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityAuditEvidence.self,
                from: auditData
            )
        )
    }
    func sourceD28Evidence() throws -> (
        preregistrationData: Data,
        preregistration:
            MetalIndexedBirdSurfaceSourceViscosityD28Preregistration,
        preRollData: Data,
        preRoll: MetalIndexedBirdSurfaceSourceViscosityD28Report,
        auditData: Data,
        audit: MetalIndexedBirdSurfaceSourceViscosityD28AuditEvidence
    ) {
        let preregistrationData = try artifactData(
            arguments.sourceD28PreregistrationPath!
        )
        let preRollData = try artifactData(arguments.sourceD28PreRollPath!)
        let auditData = try artifactData(arguments.sourceD28AuditPath!)
        return (
            preregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28Preregistration.self,
                from: preregistrationData
            ),
            preRollData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28Report.self,
                from: preRollData
            ),
            auditData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28AuditEvidence.self,
                from: auditData
            )
        )
    }
    func sourceD28FullWindowEvidence() throws -> (
        d28PreregistrationData: Data,
        d28Preregistration:
            MetalIndexedBirdSurfaceSourceViscosityD28Preregistration,
        fullPreregistrationData: Data,
        fullPreregistration:
            MetalIndexedBirdSurfaceSourceViscosityD28FullWindowPreregistration,
        fullReportData: Data,
        fullReport: MetalIndexedBirdSurfaceSourceViscosityD28FullWindowReport,
        fullAuditData: Data,
        fullAudit:
            MetalIndexedBirdSurfaceSourceViscosityD28FullWindowAuditEvidence
    ) {
        let d28PreregistrationData = try artifactData(
            arguments.sourceD28PreregistrationPath!
        )
        let fullPreregistrationData = try artifactData(
            arguments.sourceD28FullWindowPreregistrationPath!
        )
        let fullReportData = try artifactData(
            arguments.sourceD28FullWindowReportPath!
        )
        let fullAuditData = try artifactData(
            arguments.sourceD28FullWindowAuditPath!
        )
        return (
            d28PreregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28Preregistration.self,
                from: d28PreregistrationData
            ),
            fullPreregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28FullWindowPreregistration.self,
                from: fullPreregistrationData
            ),
            fullReportData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28FullWindowReport.self,
                from: fullReportData
            ),
            fullAuditData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD28FullWindowAuditEvidence.self,
                from: fullAuditData
            )
        )
    }
    func sourceD32Evidence() throws -> (
        preregistrationData: Data,
        preregistration:
            MetalIndexedBirdSurfaceSourceViscosityD32Preregistration,
        preRollData: Data,
        preRoll: MetalIndexedBirdSurfaceSourceViscosityD32Report,
        auditData: Data,
        audit: MetalIndexedBirdSurfaceSourceViscosityD32AuditEvidence
    ) {
        let preregistrationData = try artifactData(
            arguments.sourceD32PreregistrationPath!
        )
        let preRollData = try artifactData(arguments.sourceD32PreRollPath!)
        let auditData = try artifactData(arguments.sourceD32AuditPath!)
        return (
            preregistrationData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD32Preregistration.self,
                from: preregistrationData
            ),
            preRollData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD32Report.self,
                from: preRollData
            ),
            auditData,
            try JSONDecoder().decode(
                MetalIndexedBirdSurfaceSourceViscosityD32AuditEvidence.self,
                from: auditData
            )
        )
    }
    if arguments.sourceViscosityD16Preregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceScalingEvidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD16Preregistration(
                surface: dataset,
                target: target,
                sourceScaling: evidence.report,
                sourceScalingReportSHA256: sha256Hex(evidence.reportData),
                sourceScalingAudit: evidence.audit,
                sourceScalingAuditSHA256: sha256Hex(evidence.auditData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("reference_length_cells: \(report.referenceLengthCells)")
            print("requested_steps: \(report.requestedSteps)")
            print("source_reynolds: \(report.sourcePropertyReynoldsNumber)")
            print("source_tau_plus: \(report.sourceTauPlus)")
            print("execution_tau_floor: \(report.executionMinimumTauPlus)")
            print("production_tau_floor: \(report.productionMinimumTauPlus)")
            print("candidate_operators: \(report.candidateOperators)")
            print("preregistration_passed: \(report.passed)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D16 source-viscosity preregistration failed"
            )
        }
        return
    }
    if arguments.sourceViscosityD16AB {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceScalingEvidence()
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD16Discriminator(
                surface: dataset,
                target: target,
                sourceScaling: evidence.report,
                sourceScalingReportSHA256: sha256Hex(evidence.reportData),
                sourceScalingAudit: evidence.audit,
                sourceScalingAuditSHA256: sha256Hex(evidence.auditData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSourceViscosityPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("requested_steps: \(report.requestedSteps)")
            for candidate in report.cases {
                print(
                    "candidate: \(candidate.collisionOperator), "
                        + "completed=\(candidate.report.completedSteps), "
                        + "min_population=\(candidate.report.minimumPopulation), "
                        + "near_ledger=\(candidate.report.relativeRMSRawControlVolumeClosureResidual), "
                        + "global_ledger=\(candidate.report.relativeRMSGlobalFluidClosureResidual), "
                        + "correction_fraction=\(candidate.report.collisionLimiterActivationFractionOfCellSteps), "
                        + "eligible=\(candidate.eligibleForD28Planning)"
                )
            }
            print("classification: \(report.classification)")
            print("screening_gate_passed: \(report.screeningGatePassed)")
            print("d28_planning_authorized: \(report.d28PlanningAuthorized)")
            print("d28_run_authorized: \(report.d28RunAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.sourceViscosityD28Preregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD16Evidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD28Preregistration(
                surface: dataset,
                target: target,
                d16Preregistration: evidence.preregistration,
                sourceD16PreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                d16Report: evidence.report,
                sourceD16ReportSHA256: sha256Hex(evidence.reportData),
                d16Audit: evidence.audit,
                sourceD16AuditSHA256: sha256Hex(evidence.auditData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("selected_operator: \(report.selectedCollisionOperator)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "grid: \(report.expectedGridX)x\(report.expectedGridY)x\(report.expectedGridZ)"
            )
            print("cell_count: \(report.expectedCellCount)")
            print("requested_steps: \(report.requestedPreRollSteps)")
            print("expected_tau_plus: \(report.expectedTauPlus)")
            print(
                "working_set_estimate_bytes: \(report.conservativeWorkingSetEstimateBytes)"
            )
            print("preregistration_passed: \(report.passed)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D28 source-viscosity preregistration failed"
            )
        }
        return
    }
    if arguments.sourceViscosityD28PreRoll {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD16Evidence()
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD28PreRoll(
                surface: dataset,
                target: target,
                d16Preregistration: evidence.preregistration,
                sourceD16PreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                d16Report: evidence.report,
                sourceD16ReportSHA256: sha256Hex(evidence.reportData),
                d16Audit: evidence.audit,
                sourceD16AuditSHA256: sha256Hex(evidence.auditData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSourceViscosityD28Preregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("operator: \(report.selectedCollisionOperator)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("actual_tau_plus: \(report.actualTauPlus)")
            print("completed_steps: \(report.caseReport.completedSteps)")
            print("minimum_population: \(report.caseReport.minimumPopulation)")
            print(
                "near_ledger: \(report.caseReport.relativeRMSRawControlVolumeClosureResidual)"
            )
            print(
                "global_ledger: \(report.caseReport.relativeRMSGlobalFluidClosureResidual)"
            )
            print(
                "correction_fraction: \(report.caseReport.collisionLimiterActivationFractionOfCellSteps)"
            )
            print("pre_roll_gate_passed: \(report.preRollGatePassed)")
            print(
                "full_window_authorized: \(report.d28FullWindowRunAuthorized)"
            )
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.sourceViscosityD28FullWindowPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD28Evidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD28FullWindowPreregistration(
                surface: dataset,
                target: target,
                d28Preregistration: evidence.preregistration,
                sourceD28PreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                d28PreRoll: evidence.preRoll,
                sourceD28PreRollSHA256: sha256Hex(evidence.preRollData),
                d28Audit: evidence.audit,
                sourceD28AuditSHA256: sha256Hex(evidence.auditData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("operator: \(report.selectedCollisionOperator)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "grid: \(report.expectedGridX)x\(report.expectedGridY)x\(report.expectedGridZ)"
            )
            print("requested_steps: \(report.requestedFullWindowSteps)")
            print(
                "comparison_samples: \(report.requestedComparisonSamples)"
            )
            print("expected_tau_plus: \(report.expectedTauPlus)")
            print("preregistration_passed: \(report.passed)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D28 source-viscosity full-window preregistration failed"
            )
        }
        return
    }
    if arguments.sourceViscosityD28FullWindow {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD28Evidence()
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD28FullWindow(
                surface: dataset,
                target: target,
                d28Preregistration: evidence.preregistration,
                sourceD28PreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                d28PreRoll: evidence.preRoll,
                sourceD28PreRollSHA256: sha256Hex(evidence.preRollData),
                d28Audit: evidence.audit,
                sourceD28AuditSHA256: sha256Hex(evidence.auditData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSourceViscosityD28FullWindowPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("operator: \(report.selectedCollisionOperator)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("actual_tau_plus: \(report.actualTauPlus)")
            print("completed_steps: \(report.ledgerResult.completedSteps)")
            print(
                "minimum_population: \(report.ledgerResult.minimumPopulation)"
            )
            print(
                "near_ledger: \(report.ledgerResult.relativeRMSRawControlVolumeClosureResidual)"
            )
            print(
                "global_ledger: \(report.ledgerResult.relativeRMSGlobalFluidClosureResidual)"
            )
            print(
                "correction_fraction: \(report.ledgerResult.collisionLimiterActivationFractionOfCellSteps)"
            )
            print("force_samples: \(report.registeredComparisonSampleCount)")
            print("normalized_rms_error: \(report.normalizedRMSError ?? .nan)")
            print("full_window_gate_passed: \(report.fullWindowGatePassed)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.sourceViscosityD32Preregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD28FullWindowEvidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD32Preregistration(
                surface: dataset,
                target: target,
                d28Preregistration: evidence.d28Preregistration,
                sourceD28PreregistrationSHA256:
                    sha256Hex(evidence.d28PreregistrationData),
                d28FullWindowPreregistration:
                    evidence.fullPreregistration,
                sourceD28FullWindowPreregistrationSHA256:
                    sha256Hex(evidence.fullPreregistrationData),
                d28FullWindowReport: evidence.fullReport,
                sourceD28FullWindowReportSHA256:
                    sha256Hex(evidence.fullReportData),
                d28FullWindowAudit: evidence.fullAudit,
                sourceD28FullWindowAuditSHA256:
                    sha256Hex(evidence.fullAuditData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("operator: \(report.selectedCollisionOperator)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "grid: \(report.expectedGridX)x\(report.expectedGridY)x\(report.expectedGridZ)"
            )
            print("requested_steps: \(report.requestedPreRollSteps)")
            print("expected_tau_plus: \(report.expectedTauPlus)")
            print(
                "working_set_estimate_bytes: \(report.conservativeWorkingSetEstimateBytes)"
            )
            print("preregistration_passed: \(report.passed)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D32 source-viscosity preregistration failed"
            )
        }
        return
    }
    if arguments.sourceViscosityD32PreRoll {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD28FullWindowEvidence()
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD32PreRoll(
                surface: dataset,
                target: target,
                d28Preregistration: evidence.d28Preregistration,
                sourceD28PreregistrationSHA256:
                    sha256Hex(evidence.d28PreregistrationData),
                d28FullWindowPreregistration:
                    evidence.fullPreregistration,
                sourceD28FullWindowPreregistrationSHA256:
                    sha256Hex(evidence.fullPreregistrationData),
                d28FullWindowReport: evidence.fullReport,
                sourceD28FullWindowReportSHA256:
                    sha256Hex(evidence.fullReportData),
                d28FullWindowAudit: evidence.fullAudit,
                sourceD28FullWindowAuditSHA256:
                    sha256Hex(evidence.fullAuditData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSourceViscosityD32Preregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("operator: \(report.selectedCollisionOperator)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("actual_tau_plus: \(report.actualTauPlus)")
            print("completed_steps: \(report.caseReport.completedSteps)")
            print("minimum_population: \(report.caseReport.minimumPopulation)")
            print(
                "near_ledger: \(report.caseReport.relativeRMSRawControlVolumeClosureResidual)"
            )
            print(
                "global_ledger: \(report.caseReport.relativeRMSGlobalFluidClosureResidual)"
            )
            print(
                "correction_fraction: \(report.caseReport.collisionLimiterActivationFractionOfCellSteps)"
            )
            print("pre_roll_gate_passed: \(report.preRollGatePassed)")
            print(
                "full_window_authorized: \(report.d32FullWindowRunAuthorized)"
            )
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.sourceViscosityD32FullWindowPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD32Evidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD32FullWindowPreregistration(
                surface: dataset,
                target: target,
                d32Preregistration: evidence.preregistration,
                sourceD32PreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                d32PreRoll: evidence.preRoll,
                sourceD32PreRollSHA256: sha256Hex(evidence.preRollData),
                d32Audit: evidence.audit,
                sourceD32AuditSHA256: sha256Hex(evidence.auditData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("operator: \(report.selectedCollisionOperator)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "grid: \(report.expectedGridX)x\(report.expectedGridY)x\(report.expectedGridZ)"
            )
            print("requested_steps: \(report.requestedFullWindowSteps)")
            print("comparison_samples: \(report.requestedComparisonSamples)")
            print("expected_tau_plus: \(report.expectedTauPlus)")
            print("preregistration_passed: \(report.passed)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D32 source-viscosity full-window preregistration failed"
            )
        }
        return
    }
    if arguments.sourceViscosityD32FullWindow {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try sourceD32Evidence()
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityD32FullWindow(
                surface: dataset,
                target: target,
                d32Preregistration: evidence.preregistration,
                sourceD32PreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                d32PreRoll: evidence.preRoll,
                sourceD32PreRollSHA256: sha256Hex(evidence.preRollData),
                d32Audit: evidence.audit,
                sourceD32AuditSHA256: sha256Hex(evidence.auditData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSourceViscosityD32FullWindowPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("operator: \(report.selectedCollisionOperator)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("actual_tau_plus: \(report.actualTauPlus)")
            print("completed_steps: \(report.ledgerResult.completedSteps)")
            print(
                "minimum_population: \(report.ledgerResult.minimumPopulation)"
            )
            print(
                "near_ledger: \(report.ledgerResult.relativeRMSRawControlVolumeClosureResidual)"
            )
            print(
                "global_ledger: \(report.ledgerResult.relativeRMSGlobalFluidClosureResidual)"
            )
            print(
                "correction_fraction: \(report.ledgerResult.collisionLimiterActivationFractionOfCellSteps)"
            )
            print("force_samples: \(report.registeredComparisonSampleCount)")
            print("normalized_rms_error: \(report.normalizedRMSError ?? .nan)")
            print("full_window_gate_passed: \(report.fullWindowGatePassed)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.sourceViscosityTargetedBoundaryCase {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let sourceReportData = try artifactData(
            arguments.sourceTargetedFullWindowReportPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityTargetedBoundaryCase(
                surface: dataset,
                target: target,
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceTargetedBoundaryPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData),
                sourceFullWindowReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSourceViscosityD28FullWindowReport.self,
                    from: sourceReportData
                ),
                sourceFullWindowReportSHA256:
                    sha256Hex(sourceReportData),
                referenceLengthCells:
                    arguments.targetedReferenceLengthCells!
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("requested_steps: \(report.requestedSteps)")
            print("captured_steps: \(report.capturedStepCount)")
            print(
                "component_reconstruction_relative_rms: "
                    + "\(report.componentReconstructionRelativeRMS)"
            )
            print(
                "archived_force_reproduction_relative_rms: "
                    + "\(report.archivedForceReproductionRelativeRMS)"
            )
            print("near_ledger: \(report.ledgerResult.relativeRMSRawControlVolumeClosureResidual)")
            print("global_ledger: \(report.ledgerResult.relativeRMSGlobalFluidClosureResidual)")
            print("targeted_case_passed: \(report.targetedCasePassed)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.sourceViscosityReflectedProvenanceCase {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistrationData = try artifactData(
            arguments.preregistrationPath!
        )
        let sourceCaseData = try artifactData(
            arguments.sourceTargetedBoundaryCasePath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .sourceViscosityReflectedPopulationProvenanceCase(
                surface: dataset,
                target: target,
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceReflectedProvenancePreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData),
                sourceTargetedCase: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceTargetedBoundaryCaseReport.self,
                    from: sourceCaseData
                ),
                sourceTargetedCaseSHA256: sha256Hex(sourceCaseData),
                referenceLengthCells:
                    arguments.targetedReferenceLengthCells!
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("requested_steps: \(report.requestedSteps)")
            print("captured_endpoints: \(report.endpointCount)")
            print(
                "minimum_selected_score_coverage: "
                    + "\(report.minimumSelectedAbsoluteScoreCoverage)"
            )
            print(
                "source_reflected_force_reproduction_relative_rms: "
                    + "\(report.sourceReflectedForceReproductionRelativeRMS)"
            )
            print(
                "candidate_detail_score_difference: "
                    + "\(report.maximumCandidateDetailScoreDifferenceNewtons)"
            )
            print("provenance_case_passed: \(report.provenanceCasePassed)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallSpatialInteractionPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try spatialInteractionEvidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallSpatialInteractionPreregistration(
                surface: dataset,
                target: target,
                distributedForceReport: evidence.distributedReport,
                sourceDistributedForceReportSHA256:
                    sha256Hex(evidence.distributedReportData),
                forceCovariancePreregistration:
                    evidence.covariancePreregistration,
                sourceForceCovariancePreregistrationSHA256:
                    sha256Hex(evidence.covariancePreregistrationData),
                forceCovarianceReport: evidence.covarianceReport,
                sourceForceCovarianceReportSHA256:
                    sha256Hex(evidence.covarianceReportData),
                sourceForceCovarianceAuditSHA256:
                    sha256Hex(evidence.covarianceAuditData),
                forceCovarianceAuditPassed:
                    evidence.covarianceAuditPassed
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("spatial_bin_counts: \(report.expectedSpatialBinCounts)")
            print("union_spatial_bins: \(report.expectedUnionSpatialBinCount)")
            print(
                "dominant_axis_threshold: "
                    + String(report
                        .minimumDominantAxisAbsoluteContributionFraction)
            )
            print(
                "maximum_joint_fraction_for_capture: "
                    + String(report
                        .maximumJointBinFractionForTargetedCapture)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "spatial-interaction preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallSpatialInteraction {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try spatialInteractionEvidence()
        let preregistrationData = try artifactData(
            arguments.spatialInteractionPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallSpatialInteraction(
                surface: dataset,
                target: target,
                distributedForceReport: evidence.distributedReport,
                sourceDistributedForceReportSHA256:
                    sha256Hex(evidence.distributedReportData),
                forceCovariancePreregistration:
                    evidence.covariancePreregistration,
                sourceForceCovariancePreregistrationSHA256:
                    sha256Hex(evidence.covariancePreregistrationData),
                forceCovarianceReport: evidence.covarianceReport,
                sourceForceCovarianceReportSHA256:
                    sha256Hex(evidence.covarianceReportData),
                sourceForceCovarianceAuditSHA256:
                    sha256Hex(evidence.covarianceAuditData),
                forceCovarianceAuditPassed:
                    evidence.covarianceAuditPassed,
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceSpatialInteractionPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print(
                "maximum_term_mean_reconstruction_error_N: "
                    + String(report.metrics
                        .maximumTermMeanReconstructionErrorNewtons)
            )
            print(
                "interaction_closure_relative_error: "
                    + String(report.metrics
                        .relativeInteractionClosureError)
            )
            print(
                "dominant_component: "
                    + (report.metrics.dominantComponent ?? "none")
            )
            print(
                "dominant_direction: "
                    + (report.metrics.dominantDirection ?? "none")
            )
            print(
                "dominant_q_bin: "
                    + (report.metrics
                        .dominantInterpolationFractionBin ?? "none")
            )
            print(
                "joint_bins_for_target: "
                    + String(report.metrics
                        .minimumJointBinsForTargetAbsoluteContribution)
            )
            print(
                "targeted_capture_authorized: "
                    + String(report.targetedPrimitiveCaptureAuthorized)
            )
            print("classification: \(report.classification)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallForceCovariancePreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try forceCovarianceEvidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallForceCovariancePreregistration(
                surface: dataset,
                target: target,
                distributedForcePreregistration:
                    evidence.preregistration,
                sourceDistributedForcePreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                distributedForceReport: evidence.report,
                sourceDistributedForceReportSHA256:
                    sha256Hex(evidence.reportData),
                sourceDistributedForceAuditSHA256:
                    sha256Hex(evidence.auditData),
                distributedForceAuditPassed: evidence.auditPassed
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("temporal_bins: \(report.temporalBinCount)")
            print("blocks: \(report.blockCount) x \(report.binsPerBlock)")
            print("terms: \(report.termIdentifiers)")
            print(
                "dominant_pair_full_energy_threshold: "
                    + String(report.minimumDominantPairFullEnergyFraction)
            )
            print(
                "dominant_pair_block_energy_threshold: "
                    + String(report.minimumDominantPairBlockEnergyFraction)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "force-covariance preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallForceCovariance {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try forceCovarianceEvidence()
        let preregistrationData = try artifactData(
            arguments.forceCovariancePreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallForceCovariance(
                surface: dataset,
                target: target,
                distributedForcePreregistration:
                    evidence.preregistration,
                sourceDistributedForcePreregistrationSHA256:
                    sha256Hex(evidence.preregistrationData),
                distributedForceReport: evidence.report,
                sourceDistributedForceReportSHA256:
                    sha256Hex(evidence.reportData),
                sourceDistributedForceAuditSHA256:
                    sha256Hex(evidence.auditData),
                distributedForceAuditPassed: evidence.auditPassed,
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceForceCovariancePreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print(
                "maximum_term_delta_reconstruction_error_N: "
                    + String(report.metrics
                        .maximumTermDeltaReconstructionErrorNewtons)
            )
            print(
                "raw_energy_closure_relative_error: "
                    + String(report.metrics.rawEnergyClosureRelativeError)
            )
            print(
                "dominant_pair: "
                    + report.metrics.dominantPairIdentifier
            )
            print("dominant_pair_sign: \(report.metrics.dominantPairSign)")
            print(
                "dominant_pair_mechanism: "
                    + report.metrics.dominantPairMechanism
            )
            print(
                "dominant_pair_gate_passed: "
                    + String(report.metrics.dominantPairGatePassed)
            )
            print("classification: \(report.classification)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallDistributedForcePreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try distributedForceEvidence()
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallDistributedForcePreregistration(
                surface: dataset,
                target: target,
                linkGeometryPreregistration:
                    evidence.geometryPreregistration,
                sourceLinkGeometryPreregistrationSHA256:
                    sha256Hex(evidence.geometryPreregistrationData),
                linkGeometryReport: evidence.geometryReport,
                sourceLinkGeometryReportSHA256:
                    sha256Hex(evidence.geometryReportData),
                temporalDurationPreregistration:
                    evidence.durationPreregistration,
                sourceTemporalDurationPreregistrationSHA256:
                    sha256Hex(evidence.durationPreregistrationData),
                temporalDurationReport: evidence.durationReport,
                sourceTemporalDurationReportSHA256:
                    sha256Hex(evidence.durationReportData),
                linkPopulationPreregistration:
                    evidence.populationPreregistration,
                sourceLinkPopulationPreregistrationSHA256:
                    sha256Hex(evidence.populationPreregistrationData),
                linkPopulationReport: evidence.populationReport,
                sourceLinkPopulationReportSHA256:
                    sha256Hex(evidence.populationReportData),
                sourceLinkPopulationAuditSHA256:
                    sha256Hex(evidence.populationAuditData),
                linkPopulationAuditPassed: evidence.populationAuditPassed
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("reference_length_cells: \(report.referenceLengthCells)")
            print("expected_link_counts: \(report.expectedLinkCounts)")
            print("expected_step_counts: \(report.expectedStepCounts)")
            print("temporal_bins: \(report.temporalBinCount)")
            print("force_terms: \(report.forceTerms)")
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "distributed-force preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallDistributedForce {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let evidence = try distributedForceEvidence()
        let preregistrationData = try artifactData(
            arguments.distributedForcePreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallDistributedForce(
                surface: dataset,
                target: target,
                linkGeometryPreregistration:
                    evidence.geometryPreregistration,
                sourceLinkGeometryPreregistrationSHA256:
                    sha256Hex(evidence.geometryPreregistrationData),
                linkGeometryReport: evidence.geometryReport,
                sourceLinkGeometryReportSHA256:
                    sha256Hex(evidence.geometryReportData),
                temporalDurationPreregistration:
                    evidence.durationPreregistration,
                sourceTemporalDurationPreregistrationSHA256:
                    sha256Hex(evidence.durationPreregistrationData),
                temporalDurationReport: evidence.durationReport,
                sourceTemporalDurationReportSHA256:
                    sha256Hex(evidence.durationReportData),
                linkPopulationPreregistration:
                    evidence.populationPreregistration,
                sourceLinkPopulationPreregistrationSHA256:
                    sha256Hex(evidence.populationPreregistrationData),
                linkPopulationReport: evidence.populationReport,
                sourceLinkPopulationReportSHA256:
                    sha256Hex(evidence.populationReportData),
                sourceLinkPopulationAuditSHA256:
                    sha256Hex(evidence.populationAuditData),
                linkPopulationAuditPassed: evidence.populationAuditPassed,
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceDistributedForcePreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256:
                    sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("d12_runtime_seconds: \(report.d12.runtimeSeconds)")
            print("d16_runtime_seconds: \(report.d16.runtimeSeconds)")
            print(
                "total_force_pairwise_normalized_rms_difference: "
                    + String(report.metrics
                        .totalForcePairwiseNormalizedRMSDifference)
            )
            print("dominant_term: " + (report.metrics.dominantTerm ?? "none"))
            print(
                "dominant_term_gate_passed: "
                    + String(report.metrics.dominantTermGatePassed)
            )
            print(
                "dominant_component: "
                    + (report.metrics.dominantComponent ?? "none")
            )
            print(
                "dominant_direction: "
                    + (report.metrics.dominantDirection ?? "none")
            )
            print(
                "dominant_q_bin: "
                    + (report.metrics.dominantInterpolationFractionBin ?? "none")
            )
            print("source_reproduction_passed: \(report.sourceReproductionPassed)")
            print("classification: \(report.classification)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallLinkPopulationPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let coefficientPreregistrationData = try artifactData(
            arguments.linkCoefficientPreregistrationPath!
        )
        let coefficientData = try artifactData(arguments.linkCoefficientPath!)
        let durationPreregistrationData = try artifactData(
            arguments.temporalDurationPreregistrationPath!
        )
        let durationData = try artifactData(arguments.temporalDurationPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkPopulationPreregistration(
                surface: dataset,
                target: target,
                linkCoefficientPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkCoefficientPreregistration.self,
                    from: coefficientPreregistrationData
                ),
                sourceLinkCoefficientPreregistrationSHA256:
                    sha256Hex(coefficientPreregistrationData),
                linkCoefficientReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkCoefficientReport.self,
                    from: coefficientData
                ),
                sourceLinkCoefficientReportSHA256:
                    sha256Hex(coefficientData),
                temporalDurationPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self,
                    from: durationPreregistrationData
                ),
                sourceTemporalDurationPreregistrationSHA256:
                    sha256Hex(durationPreregistrationData),
                temporalDurationReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self,
                    from: durationData
                ),
                sourceTemporalDurationReportSHA256: sha256Hex(durationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "capture_steps: \(report.captureStartStep)...\(report.captureEndStep)"
            )
            print("expected_link_count: \(report.expectedLinkCount)")
            print(
                "minimum_global_force_contribution: "
                    + String(report
                        .minimumPotentialGlobalForceRMSContribution)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-population preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLinkPopulation {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let coefficientPreregistrationData = try artifactData(
            arguments.linkCoefficientPreregistrationPath!
        )
        let coefficientData = try artifactData(arguments.linkCoefficientPath!)
        let durationPreregistrationData = try artifactData(
            arguments.temporalDurationPreregistrationPath!
        )
        let durationData = try artifactData(arguments.temporalDurationPath!)
        let preregistrationData = try artifactData(
            arguments.linkPopulationPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkPopulation(
                surface: dataset,
                target: target,
                linkCoefficientPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkCoefficientPreregistration.self,
                    from: coefficientPreregistrationData
                ),
                sourceLinkCoefficientPreregistrationSHA256:
                    sha256Hex(coefficientPreregistrationData),
                linkCoefficientReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkCoefficientReport.self,
                    from: coefficientData
                ),
                sourceLinkCoefficientReportSHA256:
                    sha256Hex(coefficientData),
                temporalDurationPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self,
                    from: durationPreregistrationData
                ),
                sourceTemporalDurationPreregistrationSHA256:
                    sha256Hex(durationPreregistrationData),
                temporalDurationReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self,
                    from: durationData
                ),
                sourceTemporalDurationReportSHA256: sha256Hex(durationData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkPopulationPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256: sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("runtime_seconds: \(report.runtimeSeconds)")
            print("captured_samples: \(report.metrics.capturedSampleCount)")
            print(
                "production_fallback_links: "
                    + String(report.metrics.productionFallbackLinkCount)
            )
            print(
                "exact_global_fallback_links: "
                    + String(report.metrics.exactGlobalFallbackLinkCount)
            )
            print(
                "source_record_mismatches: "
                    + String(report.metrics.sourceRecordMismatchCount)
            )
            print(
                "population_relative_rms_difference: "
                    + String(report.metrics.populationRelativeRMSDifference)
            )
            print(
                "outlier_force_relative_rms_difference: "
                    + String(report.metrics
                        .outlierForceRelativeRMSDifference)
            )
            print(
                "delta_force_to_global_rms: "
                    + String(report.metrics
                        .deltaForceToGlobalAerodynamicForceRMSRatio)
            )
            print(
                "delta_impulse_to_global_impulse: "
                    + String(report.metrics
                        .deltaImpulseToGlobalAerodynamicImpulseRatio)
            )
            print("classification: \(report.classification)")
            print(
                "source_reproduction_passed: "
                    + String(report.sourceReproductionPassed)
            )
            print(
                "boundary_ab_authorized: "
                    + String(report.validationOnlyBoundaryABAuthorized)
            )
            print("d16_capture_authorized: \(report.d16CaptureAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallLinkCoefficientPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let rayPreregistrationData = try artifactData(
            arguments.linkRayRootPreregistrationPath!
        )
        let rayRootData = try artifactData(arguments.linkRayRootPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkCoefficientPreregistration(
                surface: dataset,
                target: target,
                linkRayRootPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkRayRootPreregistration.self,
                    from: rayPreregistrationData
                ),
                sourceLinkRayRootPreregistrationSHA256:
                    sha256Hex(rayPreregistrationData),
                linkRayRootReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkRayRootReport.self,
                    from: rayRootData
                ),
                sourceLinkRayRootReportSHA256: sha256Hex(rayRootData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("expected_sample_counts: \(report.expectedSampleCounts)")
            print("branch_threshold: \(report.branchThreshold)")
            print(
                "maximum_allowed_rms_l1_change: "
                    + String(report
                        .maximumAllowedWeightedRMSCoefficientL1Difference)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-coefficient preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLinkCoefficient {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let rayPreregistrationData = try artifactData(
            arguments.linkRayRootPreregistrationPath!
        )
        let rayRootData = try artifactData(arguments.linkRayRootPath!)
        let preregistrationData = try artifactData(
            arguments.linkCoefficientPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkCoefficient(
                surface: dataset,
                target: target,
                linkRayRootPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkRayRootPreregistration.self,
                    from: rayPreregistrationData
                ),
                sourceLinkRayRootPreregistrationSHA256:
                    sha256Hex(rayPreregistrationData),
                linkRayRootReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkRayRootReport.self,
                    from: rayRootData
                ),
                sourceLinkRayRootReportSHA256: sha256Hex(rayRootData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkCoefficientPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256: sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print(
                "branch_changes: \(report.metrics.totalBranchChangeCount)"
            )
            print(
                "maximum_rms_coefficient_l1_change: "
                    + String(report.metrics
                        .maximumWeightedRMSCoefficientL1Difference)
            )
            print(
                "maximum_coefficient_l1_change: "
                    + String(report.metrics.maximumCoefficientL1Difference)
            )
            print(
                "maximum_operator_norm_ratio: "
                    + String(report.metrics
                        .maximumSymmetricOperatorNormRatio)
            )
            print("classification: \(report.classification)")
            print(
                "population_replay_authorized: "
                    + String(report
                        .validationOnlyPopulationReplayAuthorized)
            )
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallLinkRayRootPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let intersectionPreregistrationData = try artifactData(
            arguments.linkIntersectionPreregistrationPath!
        )
        let intersectionData = try artifactData(
            arguments.linkIntersectionPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkRayRootPreregistration(
                surface: dataset,
                target: target,
                linkIntersectionPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkIntersectionPreregistration.self,
                    from: intersectionPreregistrationData
                ),
                sourceLinkIntersectionPreregistrationSHA256:
                    sha256Hex(intersectionPreregistrationData),
                linkIntersectionReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkIntersectionReport.self,
                    from: intersectionData
                ),
                sourceLinkIntersectionReportSHA256:
                    sha256Hex(intersectionData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("source_sample_index: \(report.frozenSourceSampleIndex)")
            print("source_time_seconds: \(report.frozenSourceTimeSeconds)")
            print("expected_outlier_counts: \(report.expectedOutlierCounts)")
            print("reverse_scan_subdivisions: \(report.reverseScanSubdivisions)")
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-ray-root preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLinkRayRoot {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let intersectionPreregistrationData = try artifactData(
            arguments.linkIntersectionPreregistrationPath!
        )
        let intersectionData = try artifactData(
            arguments.linkIntersectionPath!
        )
        let preregistrationData = try artifactData(
            arguments.linkRayRootPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkRayRoot(
                surface: dataset,
                target: target,
                linkIntersectionPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkIntersectionPreregistration.self,
                    from: intersectionPreregistrationData
                ),
                sourceLinkIntersectionPreregistrationSHA256:
                    sha256Hex(intersectionPreregistrationData),
                linkIntersectionReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkIntersectionReport.self,
                    from: intersectionData
                ),
                sourceLinkIntersectionReportSHA256:
                    sha256Hex(intersectionData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkRayRootPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256: sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("d12_runtime_seconds: \(report.d12.runtimeSeconds)")
            print("d16_runtime_seconds: \(report.d16.runtimeSeconds)")
            print(
                "junction_global_root_rms_shift_cells: "
                    + String(report.metrics
                        .maximumJunctionGlobalRootRMSShiftCells)
            )
            print(
                "junction_global_root_maximum_shift_cells: "
                    + String(report.metrics
                        .maximumJunctionGlobalRootMaximumShiftCells)
            )
            print(
                "owner_to_global_rms_reduction: "
                    + String(report.metrics
                        .minimumJunctionOwnerToGlobalRMSReductionFraction)
            )
            print(
                "global_root_component_switches: "
                    + String(report.metrics
                        .totalGlobalRootComponentSwitchCount)
            )
            print("classification: \(report.classification)")
            print("d20_authorized: \(report.d20DiagnosticAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallLinkIntersectionPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let velocityPreregistrationData = try artifactData(
            arguments.linkVelocityPreregistrationPath!
        )
        let velocityData = try artifactData(arguments.linkVelocityPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkIntersectionPreregistration(
                surface: dataset,
                target: target,
                linkVelocityPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkVelocityPreregistration.self,
                    from: velocityPreregistrationData
                ),
                sourceLinkVelocityPreregistrationSHA256:
                    sha256Hex(velocityPreregistrationData),
                linkVelocityReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkVelocityReport.self,
                    from: velocityData
                ),
                sourceLinkVelocityReportSHA256: sha256Hex(velocityData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("source_sample_index: \(report.frozenSourceSampleIndex)")
            print("source_time_seconds: \(report.frozenSourceTimeSeconds)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "outlier_residual_threshold_cells: "
                    + String(report.outlierResidualThresholdCells)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-intersection preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLinkIntersection {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let velocityPreregistrationData = try artifactData(
            arguments.linkVelocityPreregistrationPath!
        )
        let velocityData = try artifactData(arguments.linkVelocityPath!)
        let preregistrationData = try artifactData(
            arguments.linkIntersectionPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkIntersection(
                surface: dataset,
                target: target,
                linkVelocityPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkVelocityPreregistration.self,
                    from: velocityPreregistrationData
                ),
                sourceLinkVelocityPreregistrationSHA256:
                    sha256Hex(velocityPreregistrationData),
                linkVelocityReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkVelocityReport.self,
                    from: velocityData
                ),
                sourceLinkVelocityReportSHA256: sha256Hex(velocityData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkIntersectionPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256: sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.d16.deviceName)")
            print("d12_runtime_seconds: \(report.d12.runtimeSeconds)")
            print("d16_runtime_seconds: \(report.d16.runtimeSeconds)")
            print("d12_outlier_count: \(report.d12.outlierCount)")
            print("d16_outlier_count: \(report.d16.outlierCount)")
            print(
                "edge_or_junction_minimum_measure_fraction: "
                    + String(report.metrics
                        .minimumEdgeOrJunctionAssociatedMeasureFraction)
            )
            print(
                "dominant_direction_minimum_measure_fraction: "
                    + String(report.metrics
                        .minimumDominantDirectionMeasureFraction)
            )
            print("classification: \(report.classification)")
            print("d20_authorized: \(report.d20DiagnosticAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallLinkVelocityPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let geometryPreregistrationData = try artifactData(
            arguments.linkGeometryPreregistrationPath!
        )
        let geometryData = try artifactData(arguments.linkGeometryPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkVelocityPreregistration(
                surface: dataset,
                target: target,
                linkGeometryPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkGeometryPreregistration.self,
                    from: geometryPreregistrationData
                ),
                sourceLinkGeometryPreregistrationSHA256:
                    sha256Hex(geometryPreregistrationData),
                linkGeometryReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkGeometryReport.self,
                    from: geometryData
                ),
                sourceLinkGeometryReportSHA256: sha256Hex(geometryData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("source_sample_index: \(report.frozenSourceSampleIndex)")
            print("source_time_seconds: \(report.frozenSourceTimeSeconds)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-velocity preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLinkVelocity {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let geometryPreregistrationData = try artifactData(
            arguments.linkGeometryPreregistrationPath!
        )
        let geometryData = try artifactData(arguments.linkGeometryPath!)
        let preregistrationData = try artifactData(
            arguments.linkVelocityPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkVelocity(
                surface: dataset,
                target: target,
                linkGeometryPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkGeometryPreregistration.self,
                    from: geometryPreregistrationData
                ),
                sourceLinkGeometryPreregistrationSHA256:
                    sha256Hex(geometryPreregistrationData),
                linkGeometryReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkGeometryReport.self,
                    from: geometryData
                ),
                sourceLinkGeometryReportSHA256: sha256Hex(geometryData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkVelocityPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256: sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.d16.deviceName)")
            print("d12_runtime_seconds: \(report.d12.runtimeSeconds)")
            print("d16_runtime_seconds: \(report.d16.runtimeSeconds)")
            print(
                "production_maximum_mean_error: "
                    + String(report.metrics.maximumProductionMeanVelocityError)
            )
            print(
                "endpoint_maximum_mean_error: "
                    + String(report.metrics.maximumEndpointMeanVelocityError)
            )
            print(
                "exact_maximum_mean_error: "
                    + String(report.metrics.maximumExactMeanVelocityError)
            )
            print(
                "left_wing_exact_improvement: "
                    + String(report.metrics
                        .minimumLeftWingExactImprovementFraction)
            )
            print("classification: \(report.classification)")
            print(
                "endpoint_interpolation_qualified: "
                    + String(report.endpointInterpolationQualified)
            )
            print("d20_authorized: \(report.d20DiagnosticAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallLinkGeometryPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let durationPreregistrationData = try artifactData(
            arguments.temporalDurationPreregistrationPath!
        )
        let durationData = try artifactData(arguments.temporalDurationPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkGeometryPreregistration(
                surface: dataset,
                target: target,
                durationPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self,
                    from: durationPreregistrationData
                ),
                sourceDurationPreregistrationSHA256:
                    sha256Hex(durationPreregistrationData),
                durationReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self,
                    from: durationData
                ),
                sourceDurationReportSHA256: sha256Hex(durationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("source_sample_index: \(report.frozenSourceSampleIndex)")
            print("source_time_seconds: \(report.frozenSourceTimeSeconds)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print(
                "interpolation_fraction_bins: "
                    + String(report.interpolationFractionBinCount)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "link-geometry preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLinkGeometry {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let durationPreregistrationData = try artifactData(
            arguments.temporalDurationPreregistrationPath!
        )
        let durationData = try artifactData(arguments.temporalDurationPath!)
        let preregistrationData = try artifactData(
            arguments.linkGeometryPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLinkGeometry(
                surface: dataset,
                target: target,
                durationPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self,
                    from: durationPreregistrationData
                ),
                sourceDurationPreregistrationSHA256:
                    sha256Hex(durationPreregistrationData),
                durationReport: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationReport.self,
                    from: durationData
                ),
                sourceDurationReportSHA256: sha256Hex(durationData),
                preregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceLinkGeometryPreregistration.self,
                    from: preregistrationData
                ),
                sourcePreregistrationSHA256: sha256Hex(preregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.d16.deviceName)")
            print("d12_runtime_seconds: \(report.d12.runtimeSeconds)")
            print("d16_runtime_seconds: \(report.d16.runtimeSeconds)")
            print(
                "total_link_measure_difference: "
                    + String(report.metrics.totalLinkMeasureRelativeDifference)
            )
            print(
                "maximum_component_link_measure_difference: "
                    + String(report.metrics
                        .maximumComponentLinkMeasureRelativeDifference)
            )
            print(
                "interpolation_histogram_tv: "
                    + String(report.metrics
                        .interpolationHistogramTotalVariation)
            )
            print(
                "maximum_wall_mean_grid_difference: "
                    + String(report.metrics
                        .maximumGridMeanVelocityDifferenceRelativeToQuadratureRMS)
            )
            print("classification: \(report.classification)")
            print("d20_authorized: \(report.d20DiagnosticAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridPreregistration(
                surface: dataset,
                target: target
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("dataset: \(report.datasetIdentifier)")
            for grid in report.gridContracts {
                print(
                    "D=\(grid.referenceLengthCells): dx="
                        + String(grid.cellSizeMeters)
                        + " steps_per_sample="
                        + String(grid.fluidStepsPerForceSample)
                        + " tau_plus=" + String(grid.tauPlus)
                        + " viscosity_ratio="
                        + String(grid.pilotToSourceViscosityRatio)
                )
            }
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "collision-grid preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridDiscriminator {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridDiscriminator(
                surface: dataset,
                target: target,
                preregistration: preregistration
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            for assessment in report.assessments {
                print(
                    assessment.collisionOperator
                        + ": trend_score="
                        + String(assessment.gridTrendScore)
                        + " cross_canonical="
                        + String(assessment.crossCanonicalGatePassed)
                        + " penalty="
                        + String(assessment.crossCanonicalTrendPenalty)
                        + " selectable="
                        + String(assessment.selectionEligible)
                )
            }
            print(
                "selected_collision_operator: "
                    + (report.selectedCollisionOperator ?? "none")
            )
            print(
                "d16_completion_authorized: "
                    + String(report.d16CompletionAuthorized)
            )
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.screeningGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "collision-grid discriminator did not authorize D=16"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallTemporalPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let spatialData = try artifactData(
            arguments.spatialDiscriminatorPath!
        )
        let lagBandData = try artifactData(arguments.lagBandPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallTemporalSamplingPreregistration(
                surface: dataset,
                target: target,
                spatialDiscriminator: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport.self,
                    from: spatialData
                ),
                sourceSpatialDiscriminatorSHA256: sha256Hex(spatialData),
                sourceLagBandSHA256: sha256Hex(lagBandData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("source_sample_index: \(report.frozenSourceSampleIndex)")
            print("source_time_seconds: \(report.frozenSourceTimeSeconds)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print("force_bin_count: \(report.forceBinCount)")
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "fixed-geometry temporal-sampling preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallTemporalSampling {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let spatialData = try artifactData(
            arguments.spatialDiscriminatorPath!
        )
        let lagBandData = try artifactData(arguments.lagBandPath!)
        let temporalData = try artifactData(
            arguments.temporalPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallTemporalSampling(
                surface: dataset,
                target: target,
                spatialDiscriminator: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport.self,
                    from: spatialData
                ),
                sourceSpatialDiscriminatorSHA256: sha256Hex(spatialData),
                sourceLagBandSHA256: sha256Hex(lagBandData),
                temporalPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration.self,
                    from: temporalData
                ),
                sourceTemporalPreregistrationSHA256:
                    sha256Hex(temporalData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.d16.deviceName)")
            print("d12_steps: \(report.d12.ledgerResult.completedSteps)")
            print("d16_steps: \(report.d16.ledgerResult.completedSteps)")
            print(
                "endpoint_pairwise_difference: "
                    + String(report.metrics
                        .endpointPairwiseNormalizedRMSDifference)
            )
            print(
                "trapezoidal_pairwise_difference: "
                    + String(report.metrics
                        .sampleTrapezoidalPairwiseNormalizedRMSDifference)
            )
            print(
                "impulse_pairwise_difference: "
                    + String(report.metrics
                        .impulsePreservingPairwiseNormalizedRMSDifference)
            )
            print("classification: \(report.classification)")
            print("d20_authorized: \(report.d20DiagnosticAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallTemporalDurationPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let temporalPreregistrationData = try artifactData(
            arguments.temporalPreregistrationPath!
        )
        let temporalSamplingData = try artifactData(
            arguments.temporalSamplingPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallTemporalDurationPreregistration(
                surface: dataset,
                target: target,
                temporalPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration.self,
                    from: temporalPreregistrationData
                ),
                sourceTemporalPreregistrationSHA256:
                    sha256Hex(temporalPreregistrationData),
                temporalSampling: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport.self,
                    from: temporalSamplingData
                ),
                sourceTemporalSamplingSHA256:
                    sha256Hex(temporalSamplingData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("nested_prefix_bins: \(report.nestedPrefixBinCounts)")
            print("block_bin_count: \(report.blockBinCount)")
            print("extended_bin_count: \(report.extendedForceBinCount)")
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "fixed-geometry duration preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallTemporalDuration {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let spatialData = try artifactData(
            arguments.spatialDiscriminatorPath!
        )
        let lagBandData = try artifactData(arguments.lagBandPath!)
        let temporalPreregistrationData = try artifactData(
            arguments.temporalPreregistrationPath!
        )
        let temporalSamplingData = try artifactData(
            arguments.temporalSamplingPath!
        )
        let durationPreregistrationData = try artifactData(
            arguments.temporalDurationPreregistrationPath!
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallTemporalDuration(
                surface: dataset,
                target: target,
                spatialDiscriminator: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallSpatialDiscriminatorReport.self,
                    from: spatialData
                ),
                sourceSpatialDiscriminatorSHA256: sha256Hex(spatialData),
                sourceLagBandSHA256: sha256Hex(lagBandData),
                temporalPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalSamplingPreregistration.self,
                    from: temporalPreregistrationData
                ),
                sourceTemporalPreregistrationSHA256:
                    sha256Hex(temporalPreregistrationData),
                temporalSampling: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalSamplingReport.self,
                    from: temporalSamplingData
                ),
                sourceTemporalSamplingSHA256:
                    sha256Hex(temporalSamplingData),
                durationPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallTemporalDurationPreregistration.self,
                    from: durationPreregistrationData
                ),
                sourceDurationPreregistrationSHA256:
                    sha256Hex(durationPreregistrationData)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.extendedSampling.d16.deviceName)")
            print(
                "prefix_reproduction_error: "
                    + String(report.baselinePrefixMaximumRelativeError)
            )
            for window in report.prefixWindows + report.blockWindows {
                print(
                    window.identifier + "_impulse_history_difference: "
                        + String(window.metrics
                            .impulsePreservingPairwiseNormalizedRMSDifference)
                )
                print(
                    window.identifier + "_total_impulse_difference: "
                        + String(window.metrics
                            .directTotalImpulseRelativeDifference)
                )
            }
            print("classification: \(report.classification)")
            print("d20_authorized: \(report.d20DiagnosticAuthorized)")
            print("next_action: \(report.nextAction)")
        }
        return
    }
    if arguments.collisionGridMovingWallSpatialPreregister {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let d16Data = try artifactData(arguments.movingWallFullWindowPath!)
        let d16 = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceMovingWallFullWindowReport.self,
            from: d16Data
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallSpatialPreregistration(
                surface: dataset,
                target: target,
                sourceD16FullWindow: d16,
                sourceD16FullWindowSHA256: sha256Hex(d16Data)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("source_d16_sha256: \(report.sourceD16FullWindowSHA256)")
            print("case_grids: \(report.caseReferenceLengthCells)")
            print(
                "fine_grid_relative_difference_limit: "
                    + String(report.maximumAllowedFineGridRelativeDifference)
            )
            print("preregistration_passed: \(report.passed)")
            print("selection_rule: \(report.selectionRule)")
        }
        guard report.passed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "candidate-A spatial preregistration failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallSpatialCase {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let spatialData = try artifactData(
            arguments.spatialPreregistrationPath!
        )
        let spatial = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceMovingWallSpatialPreregistration.self,
            from: spatialData
        )
        let d16Data = try artifactData(arguments.movingWallFullWindowPath!)
        let d16 = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceMovingWallFullWindowReport.self,
            from: d16Data
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallSpatialCase(
                surface: dataset,
                target: target,
                preregistration: try decodeArtifact(
                    MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
                    path: arguments.preregistrationPath!
                ),
                discriminator: try decodeArtifact(
                    MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
                    path: arguments.discriminatorPath!
                ),
                completion: try decodeArtifact(
                    MetalIndexedBirdSurfaceCollisionGridCompletionReport.self,
                    path: arguments.completionPath!
                ),
                provenance: try decodeArtifact(
                    MetalIndexedBirdSurfacePopulationStageProvenanceReport.self,
                    path: arguments.provenancePath!
                ),
                boundaryTerms: try decodeArtifact(
                    MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self,
                    path: arguments.boundaryTermsPath!
                ),
                admissibility: try decodeArtifact(
                    MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport.self,
                    path: arguments.movingWallABPath!
                ),
                retainedLedger: try decodeArtifact(
                    MetalIndexedBirdSurfaceMovingWallLedgerReport.self,
                    path: arguments.movingWallLedgerPath!
                ),
                spatialPreregistration: spatial,
                sourceSpatialPreregistrationSHA256: sha256Hex(spatialData),
                sourceD16FullWindow: d16,
                sourceD16FullWindowSHA256: sha256Hex(d16Data),
                referenceLengthCells:
                    arguments.spatialReferenceLengthCells!
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            let full = report.fullWindowReport
            print("device: \(full.deviceName)")
            print("reference_length_cells: \(report.referenceLengthCells)")
            print("completed_steps: \(full.ledgerResult.completedSteps)")
            print("minimum_population: \(full.ledgerResult.minimumPopulation)")
            print(
                "near_wing_relative_rms_residual: "
                    + String(full.ledgerResult
                        .relativeRMSRawControlVolumeClosureResidual)
            )
            print(
                "global_relative_rms_residual: "
                    + String(full.ledgerResult
                        .relativeRMSGlobalFluidClosureResidual)
            )
            print("case_gate_passed: \(report.caseGatePassed)")
        }
        guard report.caseGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "candidate-A spatial case failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallSpatialDiscriminator {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let spatialData = try artifactData(
            arguments.spatialPreregistrationPath!
        )
        let d8Data = try artifactData(arguments.spatialD8Path!)
        let d12Data = try artifactData(arguments.spatialD12Path!)
        let d16Data = try artifactData(arguments.movingWallFullWindowPath!)
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallSpatialDiscriminator(
                surface: dataset,
                target: target,
                spatialPreregistration: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallSpatialPreregistration.self,
                    from: spatialData
                ),
                sourceSpatialPreregistrationSHA256: sha256Hex(spatialData),
                d8Case: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallSpatialCaseReport.self,
                    from: d8Data
                ),
                sourceD8CaseSHA256: sha256Hex(d8Data),
                d12Case: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallSpatialCaseReport.self,
                    from: d12Data
                ),
                sourceD12CaseSHA256: sha256Hex(d12Data),
                d16FullWindow: try JSONDecoder().decode(
                    MetalIndexedBirdSurfaceMovingWallFullWindowReport.self,
                    from: d16Data
                ),
                sourceD16FullWindowSHA256: sha256Hex(d16Data)
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print(
                "d8_to_d12_history_difference: "
                    + String(report.d8ToD12
                        .intervalForceNormalizedRMSDifference)
            )
            print(
                "d12_to_d16_history_difference: "
                    + String(report.d12ToD16
                        .intervalForceNormalizedRMSDifference)
            )
            print(
                "d12_to_d16_mean_difference: "
                    + String(report.d12ToD16.meanForceRelativeDifference)
            )
            print(
                "d12_to_d16_impulse_difference: "
                    + String(report.d12ToD16.impulseRelativeDifference)
            )
            print(
                "monotonic_trend_passed: "
                    + String(report.monotonicTrendReductionPassed)
            )
            print(
                "fine_grid_convergence_passed: "
                    + String(report.fineGridForceConvergencePassed)
            )
            print(
                "spatial_refinement_gate_passed: "
                    + String(report.spatialRefinementGatePassed)
            )
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.spatialRefinementGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "candidate-A spatial refinement discriminator failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallFullWindow {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let discriminator = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.discriminatorPath!
            ))
        )
        let completion = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridCompletionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.completionPath!
            ))
        )
        let provenance = try JSONDecoder().decode(
            MetalIndexedBirdSurfacePopulationStageProvenanceReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.provenancePath!
            ))
        )
        let boundaryTerms = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.boundaryTermsPath!
            ))
        )
        let admissibility = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.movingWallABPath!
            ))
        )
        let retainedLedger = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceMovingWallLedgerReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.movingWallLedgerPath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallFullWindow(
                surface: dataset,
                target: target,
                preregistration: preregistration,
                discriminator: discriminator,
                completion: completion,
                provenance: provenance,
                boundaryTerms: boundaryTerms,
                admissibility: admissibility,
                retainedLedger: retainedLedger
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("candidate: \(report.sourceCandidateIdentifier)")
            print("d16_completed_steps: \(report.ledgerResult.completedSteps)")
            print("minimum_population: \(report.ledgerResult.minimumPopulation)")
            print(
                "near_wing_relative_rms_residual: "
                    + String(
                        report.ledgerResult
                            .relativeRMSRawControlVolumeClosureResidual
                    )
            )
            print(
                "global_relative_rms_residual: "
                    + String(
                        report.ledgerResult
                            .relativeRMSGlobalFluidClosureResidual
                    )
            )
            print(
                "registered_force_samples: "
                    + String(report.registeredComparisonSampleCount)
            )
            print(
                "descriptive_normalized_rms_error: "
                    + (report.normalizedRMSError.map { String($0) }
                        ?? "unavailable")
            )
            print("full_window_gate_passed: \(report.fullWindowGatePassed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.fullWindowGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D=16 candidate-A full registered window failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallLedger {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let discriminator = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.discriminatorPath!
            ))
        )
        let completion = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridCompletionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.completionPath!
            ))
        )
        let provenance = try JSONDecoder().decode(
            MetalIndexedBirdSurfacePopulationStageProvenanceReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.provenancePath!
            ))
        )
        let boundaryTerms = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.boundaryTermsPath!
            ))
        )
        let admissibility = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceMovingWallAdmissibilityABReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.movingWallABPath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallLedger(
                surface: dataset,
                target: target,
                preregistration: preregistration,
                discriminator: discriminator,
                completion: completion,
                provenance: provenance,
                boundaryTerms: boundaryTerms,
                admissibility: admissibility
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print("candidate: \(report.sourceAdmissibilityCandidateIdentifier)")
            print("d16_completed_steps: \(report.result.completedSteps)")
            print("minimum_population: \(report.result.minimumPopulation)")
            print(
                "near_wing_relative_rms_residual: "
                    + String(
                        report.result
                            .relativeRMSRawControlVolumeClosureResidual
                    )
            )
            print(
                "global_relative_rms_residual: "
                    + String(
                        report.result.relativeRMSGlobalFluidClosureResidual
                    )
            )
            print("ledger_gate_passed: \(report.ledgerGatePassed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.ledgerGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D=16 candidate-A force/momentum ledger failed"
            )
        }
        return
    }
    if arguments.collisionGridMovingWallAB {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let discriminator = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.discriminatorPath!
            ))
        )
        let completion = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridCompletionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.completionPath!
            ))
        )
        let provenance = try JSONDecoder().decode(
            MetalIndexedBirdSurfacePopulationStageProvenanceReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.provenancePath!
            ))
        )
        let boundaryTerms = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceBoundaryTermDecompositionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.boundaryTermsPath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridMovingWallAdmissibilityAB(
                surface: dataset,
                target: target,
                preregistration: preregistration,
                discriminator: discriminator,
                completion: completion,
                provenance: provenance,
                boundaryTerms: boundaryTerms
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print(
                "pre_step_local_density: "
                    + String(report.preStepLocalDensity)
            )
            print(
                "candidate_a_min_population: "
                    + String(report.candidateA.minimumPopulation)
            )
            print(
                "candidate_b_global_scale: "
                    + String(report.globalPositivityAdmissibilityScale)
            )
            print(
                "authorized_for_ledger: "
                    + (report.candidateAuthorizedForProductionLedger
                        ?? "none")
            )
            print(
                "admissibility_ab_gate_passed: "
                    + String(report.admissibilityABGatePassed)
            )
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.admissibilityABGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D=16 moving-wall admissibility A/B did not close"
            )
        }
        return
    }
    if arguments.collisionGridBoundaryDecomposition {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let discriminator = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.discriminatorPath!
            ))
        )
        let completion = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridCompletionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.completionPath!
            ))
        )
        let provenance = try JSONDecoder().decode(
            MetalIndexedBirdSurfacePopulationStageProvenanceReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.provenancePath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridBoundaryTermDecomposition(
                surface: dataset,
                target: target,
                preregistration: preregistration,
                discriminator: discriminator,
                completion: completion,
                provenance: provenance
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print(
                "negative_boundary_directions: "
                    + String(describing:
                        report.negativeMovingBoundaryDirectionsAtFailure)
            )
            print(
                "halfway_moving_wall_nonnegative: "
                    + String(describing:
                        report
                            .directionsMadeNonnegativeByHalfwayMovingWall)
            )
            print(
                "halfway_zero_wall_still_negative: "
                    + String(describing:
                        report
                            .directionsRemainingNegativeUnderHalfwayZeroWall)
            )
            print("dominant_repair_target: \(report.dominantRepairTarget)")
            print(
                "boundary_term_gate_passed: "
                    + String(report.boundaryTermGatePassed)
            )
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.boundaryTermGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D=16 moving-boundary term decomposition did not close"
            )
        }
        return
    }
    if arguments.collisionGridProvenance {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let discriminator = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.discriminatorPath!
            ))
        )
        let completion = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridCompletionReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.completionPath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridPopulationStageProvenance(
                surface: dataset,
                target: target,
                preregistration: preregistration,
                discriminator: discriminator,
                completion: completion
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print(
                "target: cell=\(report.targetCellCoordinate) direction="
                    + String(report.targetDirection)
            )
            print(
                "first_negative_stage: "
                    + (report.firstNegativeCapturedStage ?? "unresolved")
            )
            print(
                "first_negative_step: "
                    + (report.firstNegativeCapturedStep.map(String.init)
                        ?? "unresolved")
            )
            print(
                "maximum_prediction_error: "
                    + String(report.maximumPredictionAbsoluteError)
            )
            print(
                "provenance_gate_passed: "
                    + String(report.provenanceGatePassed)
            )
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.provenanceGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "D=16 population-stage provenance did not close"
            )
        }
        return
    }
    if arguments.collisionGridCompletion {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let preregistration = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridPreregistration.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.preregistrationPath!
            ))
        )
        let discriminator = try JSONDecoder().decode(
            MetalIndexedBirdSurfaceCollisionGridDiscriminatorReport.self,
            from: Data(contentsOf: URL(
                fileURLWithPath: arguments.discriminatorPath!
            ))
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionGridCompletion(
                surface: dataset,
                target: target,
                preregistration: preregistration,
                discriminator: discriminator
            )
        if let archivePath = arguments.archivePath {
            try writeJSON(report, to: archivePath)
        }
        if arguments.json {
            try printJSON(report)
        } else {
            print("device: \(report.deviceName)")
            print(
                "selected_collision_operator: "
                    + report.selectedCollisionOperator
            )
            print(
                "d16_completed_steps: "
                    + String(report.d16Case.report.completedFluidSteps)
            )
            print(
                "d12_to_d16_interval_force_difference: "
                    + (
                        report
                            .d12ToD16IntervalForceNormalizedRMSDifference
                            .map { String($0) } ?? "unavailable"
                    )
            )
            print(
                "fine_grid_force_convergence_passed: "
                    + String(report.fineGridForceConvergencePassed)
            )
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.completionGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "authorized D=16 collision completion failed"
            )
        }
        return
    }
    if arguments.collisionExtendedPilot {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionExtendedPilot(
                surface: dataset,
                target: target,
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
            print("extended_pilot_steps: \(report.requestedFluidSteps)")
            print(
                "comparison_samples: \(report.requestedComparisonSamples)"
            )
            for result in report.cases {
                print(
                    "\(result.collisionOperator): steps="
                        + String(result.report.completedFluidSteps)
                        + " minimum_population="
                        + String(result.report.minimumSampledPopulation)
                        + " activation_fraction="
                        + String(
                            result.report
                                .collisionLimiterActivationFractionOfCellSteps
                        )
                        + " endpoint_normalized_rms_error="
                        + (result.report.endpointNormalizedRMSError.map {
                            String($0)
                        } ?? "unavailable")
                        + " interval_normalized_rms_error="
                        + (result.report.intervalMeanNormalizedRMSError.map {
                            String($0)
                        } ?? "unavailable")
                        + " eligible="
                        + String(
                            result.eligibleForRefinementDiscrimination
                        )
                )
            }
            print(
                "endpoint_pairwise_normalized_rms_difference: "
                    + (report.endpointPairwiseNormalizedRMSDifference.map {
                        String($0)
                    } ?? "unavailable")
            )
            print(
                "interval_pairwise_normalized_rms_difference: "
                    + (report.intervalMeanPairwiseNormalizedRMSDifference.map {
                        String($0)
                    } ?? "unavailable")
            )
            print(
                "eligible_collision_operators: "
                    + report.eligibleCollisionOperators.joined(separator: ",")
            )
            print("screening_gate_passed: \(report.screeningGatePassed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.screeningGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed Metal collision extended-pilot gate failed"
            )
        }
        return
    }
    if arguments.collisionMomentumClosure {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionMomentumClosure(
                surface: dataset,
                target: target,
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
            print("momentum_steps: \(report.requestedSteps)")
            for result in report.cases {
                print(
                    "\(result.collisionOperator): control_relative_rms="
                        + String(
                            result
                                .relativeRMSRawControlVolumeClosureResidual
                        )
                        + " global_relative_rms="
                        + String(
                            result.relativeRMSGlobalFluidClosureResidual
                        )
                        + " eligible="
                        + String(result.eligibleForExtendedPilot)
                )
            }
            print(
                "eligible_collision_operators: "
                    + report.eligibleCollisionOperators.joined(separator: ",")
            )
            print("screening_gate_passed: \(report.screeningGatePassed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.screeningGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed Metal collision momentum-closure gate failed"
            )
        }
        return
    }
    if arguments.collisionPreRollAB {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let report = try MetalIndexedBirdSurfacePilotValidator
            .collisionPreRollAB(
                surface: dataset,
                target: target,
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
            print("pre_roll_steps: \(report.requestedPreRollSteps)")
            for result in report.cases {
                print(
                    "\(result.collisionOperator): steps="
                        + String(result.completedPreRollSteps)
                        + " minimum_population="
                        + String(result.report.minimumSampledPopulation)
                        + " activation_fraction="
                        + String(
                            result.report
                                .collisionLimiterActivationFractionOfCellSteps
                        )
                        + " eligible="
                        + String(result.eligibleForExtendedPilot)
                )
            }
            print(
                "eligible_collision_operators: "
                    + report.eligibleCollisionOperators.joined(separator: ",")
            )
            print("screening_gate_passed: \(report.screeningGatePassed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.screeningGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed Metal collision pre-roll A/B screening gate failed"
            )
        }
        return
    }
    if arguments.coarseFluidPilot {
        let target = try MeasuredBirdForceTargetLoader.load(
            targetURL: URL(fileURLWithPath: arguments.forceTargetPath!),
            surface: dataset
        )
        let report = try MetalIndexedBirdSurfacePilotValidator.audit(
            surface: dataset,
            target: target,
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
            print("force_target: \(report.forceTargetIdentifier)")
            print("device: \(report.deviceName)")
            print("grid: \(report.gridX)x\(report.gridY)x\(report.gridZ)")
            print("completed_fluid_steps: \(report.completedFluidSteps)")
            print(
                "comparison_samples: "
                    + String(report.recordedComparisonSamples)
            )
            print("runtime_s: \(report.runtimeSeconds)")
            print(
                "pilot_to_source_viscosity_ratio: "
                    + String(report.plan.pilotToSourceViscosityRatio)
            )
            print(
                "minimum_sampled_population: "
                    + String(report.minimumSampledPopulation)
            )
            print(
                "endpoint_normalized_rms_error: "
                    + (report.endpointNormalizedRMSError.map { String($0) }
                        ?? "unavailable")
            )
            print(
                "interval_mean_normalized_rms_error: "
                    + (report.intervalMeanNormalizedRMSError.map { String($0) }
                        ?? "unavailable")
            )
            print(
                "experimental_agreement_gate_applied: "
                    + String(report.experimentalAgreementGateApplied)
            )
            print("integration_gate_passed: \(report.integrationGatePassed)")
            print("scientific_verdict: \(report.scientificVerdict)")
        }
        guard report.integrationGatePassed else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "indexed Metal coarse fluid pilot integration gate failed"
            )
        }
        return
    }
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

private func runDirectionCompositionValidation(_ values: [String]) throws {
    let arguments = try DirectionCompositionArguments(values)
    let preregistrationData = try Data(contentsOf: URL(
        fileURLWithPath: arguments.preregistrationPath
    ))
    let preregistration = try JSONDecoder().decode(
        MetalDirectionCompositionPreregistration.self,
        from: preregistrationData
    )
    let report = try MetalDirectionCompositionValidator.run(
        preregistration: preregistration,
        sourcePreregistrationSHA256: sha256Hex(preregistrationData)
    )
    if let archivePath = arguments.archivePath {
        try writeJSON(report, to: archivePath)
    }
    if arguments.json {
        try printJSON(report)
    } else {
        print("device: \(report.deviceName)")
        print("runtime_seconds: \(report.runtimeSeconds)")
        print("classification: \(report.classification)")
        print(
            "maximum_fine_profile_vector_error: "
                + String(report.maximumFineProfileVectorRelativeError)
        )
        print(
            "maximum_coarse_fine_mean_difference: "
                + String(
                    report
                        .maximumCoarseFinePhaseMeanProfileRelativeDifference
                )
        )
        print("canonical_passed: \(report.canonicalPassed)")
        print("next_action: \(report.nextAction)")
    }
    guard report.canonicalPassed else {
        throw CLIError.acceptanceFailed(
            "direction-composition canonical exceeded a frozen gate"
        )
    }
}

private func run(_ values: [String]) throws {
    if values.count > 1, values[1] == "validate" {
        guard values.count > 2 else {
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall|translating-body|sphere|wing|flapping-wing|direction-composition> [options]"
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
        case "direction-composition":
            try runDirectionCompositionValidation(values)
        default:
            throw CLIError.invalidArgument(
                "Use: birdflow validate <shear-wave|moving-wall|translating-body|sphere|wing|flapping-wing|direction-composition> [options]"
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

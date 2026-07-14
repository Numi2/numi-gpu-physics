import BirdFlowCore
import Foundation

public enum MetalMovingWallValidationError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid Metal moving-wall validation request: \(message)"
        case .failed(let message):
            return "Metal moving-wall validation failed: \(message)"
        }
    }
}

public struct MetalTransientCouetteCaseResult: Codable, Sendable {
    public let resolution: Int
    public let steps: Int
    public let normalizedTime: Double
    public let normalizedProfileL2Error: Double
    public let maximumCrossFlowSpeed: Double
    public let measuredTopWallForce: Double
    public let analyticTopWallForce: Double
    public let relativeTopWallForceError: Double
}

public struct MetalOscillatingWallCaseResult: Codable, Sendable {
    public let resolution: Int
    public let angularFrequency: Double
    public let warmupCycles: Int
    public let sampleCount: Int
    public let normalizedProfileL2Error: Double
    public let maximumCrossFlowSpeed: Double
    public let normalizedForceRMSError: Double
    public let relativeForcePhasorError: Double
    public let relativeForceAmplitudeError: Double
    public let forcePhaseErrorRadians: Double
}

public struct MetalMovingWallValidationReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let passed: Bool
    public let viscosity: Double
    public let wallVelocityAmplitude: Double
    public let dimensionlessAngularFrequency: Double
    public let couetteProfileConvergenceOrder: Double
    public let couetteForceConvergenceOrder: Double
    public let oscillatingProfileConvergenceOrder: Double
    public let oscillatingForceConvergenceOrder: Double
    public let maximumBatchDensityDifference: Double
    public let maximumBatchVelocityDifference: Double
    public let maximumBatchForceDifference: Double
    public let maximumAllowedProfileError: Double
    public let maximumAllowedCouetteForceError: Double
    public let maximumAllowedOscillatingForceError: Double
    public let maximumAllowedForcePhaseErrorRadians: Double
    public let maximumAllowedCrossFlowSpeed: Double
    public let minimumRequiredProfileConvergenceOrder: Double
    public let minimumRequiredForceConvergenceOrder: Double
    public let maximumAllowedBatchDifference: Double
    public let couetteCases: [MetalTransientCouetteCaseResult]
    public let oscillatingCases: [MetalOscillatingWallCaseResult]
}

public struct MetalHighReMovingWallCaseResult: Codable, Sendable {
    public let matchedBirdChordCells: Int
    public let latticeKinematicViscosity: Double
    public let tauPlus: Double
    public let tauPlusMarginAboveHalf: Double
    public let requestedSteps: Int
    public let finiteSteps: Int
    public let firstNonFiniteStep: Int?
    public let initialPopulationMass: Double
    public let finalPopulationMass: Double?
    public let relativePopulationMassDrift: Double?
    public let minimumPopulation: Double?
    public let maximumPopulation: Double?
    public let maximumAbsolutePopulation: Double?
    public let maximumDensityDeviation: Double
    public let maximumVelocityMagnitude: Double
    public let fieldsFinite: Bool
    public let loadsFinite: Bool
    public let passed: Bool
}

public struct MetalHighReMovingWallStabilityReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let productionKernel: String
    public let topologyChanges: Bool
    public let domainResolution: Int
    public let wallLatticeVelocity: Double
    public let requestedSteps: Int
    public let runtimeSeconds: Double
    public let maximumAllowedRelativePopulationMassDrift: Double
    public let maximumAllowedAbsolutePopulation: Double
    public let classification: String
    public let scientificVerdict: String
    public let cases: [MetalHighReMovingWallCaseResult]
    public let passed: Bool
}

public enum MetalMovingWallValidator {
    public static let maximumProfileError = 0.01
    public static let maximumCouetteForceError = 0.01
    public static let maximumOscillatingForceError = 0.01
    public static let maximumForcePhaseErrorRadians = 0.01
    public static let maximumCrossFlowSpeed = 2.0e-6
    public static let minimumProfileConvergenceOrder = 1.5
    public static let minimumForceConvergenceOrder = 1.0
    public static let maximumBatchDifference = 1.0e-7

    public static func runHighReStability(
        steps: Int = 500
    ) throws -> MetalHighReMovingWallStabilityReport {
        guard steps >= 100 else {
            throw MetalMovingWallValidationError.invalidRequest(
                "high-Re moving-wall stability requires at least 100 steps"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let resolution = 16
        let wallVelocity: Float = 0.08
        let maximumMassDrift = 5.0e-5
        let maximumAbsolutePopulation = 10.0
        let matchedViscosities: [(Int, Float)] = [
            (8, 4.382_427_9e-5),
            (12, 6.582_454_1e-5),
            (16, 8.782_491_2e-5),
        ]
        let cases = try matchedViscosities.map { chordCells, viscosity in
            try runHighReFixedWallCase(
                backend: backend,
                resolution: resolution,
                matchedBirdChordCells: chordCells,
                viscosity: viscosity,
                wallVelocity: wallVelocity,
                steps: steps,
                maximumMassDrift: maximumMassDrift,
                maximumAbsolutePopulation: maximumAbsolutePopulation
            )
        }
        let passed = cases.allSatisfy(\.passed)
        let classification = passed
            ? "fixed-wall-trt-stable-moving-topology-path-suspect"
            : "fixed-wall-trt-unstable-collision-path-suspect"
        let verdict = passed
            ? "Matched high-Re TRT remains finite without cover/uncover topology. Isolate interpolated moving-boundary and topology forcing before changing collision physics."
            : "Matched high-Re TRT becomes non-finite with a fixed wall and no topology changes. Qualify a stabilized collision operator on this canonical before another bird replay."
        return MetalHighReMovingWallStabilityReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            topologyChanges: false,
            domainResolution: resolution,
            wallLatticeVelocity: Double(wallVelocity),
            requestedSteps: steps,
            runtimeSeconds: Date().timeIntervalSince(startTime),
            maximumAllowedRelativePopulationMassDrift: maximumMassDrift,
            maximumAllowedAbsolutePopulation: maximumAbsolutePopulation,
            classification: classification,
            scientificVerdict: verdict,
            cases: cases,
            passed: passed
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }

    public static func run(
        finestResolution: Int = 32,
        viscosity: Float = 0.1,
        wallVelocityAmplitude: Float = 0.01,
        archiveDirectory: URL? = nil
    ) throws -> MetalMovingWallValidationReport {
        guard finestResolution >= 32 else {
            throw MetalMovingWallValidationError.invalidRequest(
                "moving-wall finest resolution must be at least 32 cells"
            )
        }
        guard viscosity > 0,
              viscosity.isFinite,
              0.5 + 3 * viscosity >= 0.500_05 else {
            throw MetalMovingWallValidationError.invalidRequest(
                "moving-wall viscosity must be finite and retain the production TRT relaxation margin"
            )
        }
        guard wallVelocityAmplitude > 0,
              wallVelocityAmplitude.isFinite,
              wallVelocityAmplitude / D3Q19.soundSpeed <= 0.15 else {
            throw MetalMovingWallValidationError.invalidRequest(
                "moving-wall amplitude must be finite, positive, and at or below Mach 0.15"
            )
        }
        do {
            _ = try GridSize(
                x: finestResolution,
                y: finestResolution,
                z: finestResolution
            )
        } catch {
            throw MetalMovingWallValidationError.invalidRequest(
                "moving-wall finest resolution exceeds the supported grid range"
            )
        }

#if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let resolutions = Array(Set([
            finestResolution / 2,
            finestResolution - finestResolution / 4,
            finestResolution,
        ].map { max(16, $0) })).sorted()
        guard resolutions.count == 3 else {
            throw MetalMovingWallValidationError.invalidRequest(
                "moving-wall refinement requires three distinct grids"
            )
        }
        if let archiveDirectory {
            try FileManager.default.createDirectory(
                at: archiveDirectory,
                withIntermediateDirectories: true
            )
        }

        let dimensionlessFrequency = 30.0
        var couetteCases: [MetalTransientCouetteCaseResult] = []
        var oscillatingCases: [MetalOscillatingWallCaseResult] = []
        for resolution in resolutions {
            let couette = try runTransientCouette(
                backend: backend,
                resolution: resolution,
                viscosity: viscosity,
                amplitude: wallVelocityAmplitude
            )
            couetteCases.append(couette.result)
            if let archiveDirectory {
                try archiveFields(
                    directory: archiveDirectory,
                    stem: "couette-n\(resolution)-step\(couette.result.steps)",
                    density: couette.density,
                    velocity: couette.velocity
                )
            }

            let oscillating = try runOscillatingWall(
                backend: backend,
                resolution: resolution,
                viscosity: viscosity,
                amplitude: wallVelocityAmplitude,
                dimensionlessFrequency: dimensionlessFrequency,
                warmupCycles: 6,
                sampleCount: 16
            )
            oscillatingCases.append(oscillating.result)
            if let archiveDirectory {
                try archiveFields(
                    directory: archiveDirectory,
                    stem: "stokes-n\(resolution)-final-phase",
                    density: oscillating.density,
                    velocity: oscillating.velocity
                )
            }
        }

        let couetteProfileOrder = convergenceOrder(
            resolutions: resolutions,
            errors: couetteCases.map(\.normalizedProfileL2Error)
        )
        let couetteForceOrder = convergenceOrder(
            resolutions: resolutions,
            errors: couetteCases.map(\.relativeTopWallForceError)
        )
        let oscillatingProfileOrder = convergenceOrder(
            resolutions: resolutions,
            errors: oscillatingCases.map(\.normalizedProfileL2Error)
        )
        let oscillatingForceOrder = convergenceOrder(
            resolutions: resolutions,
            errors: oscillatingCases.map(\.relativeForcePhasorError)
        )
        let batch = try compareBatchPartitions(
            backend: backend,
            viscosity: viscosity,
            amplitude: wallVelocityAmplitude,
            dimensionlessFrequency: dimensionlessFrequency
        )
        let maximumCrossFlow = max(
            couetteCases.map(\.maximumCrossFlowSpeed).max() ?? .infinity,
            oscillatingCases.map(\.maximumCrossFlowSpeed).max() ?? .infinity
        )
        let finite = [
            couetteProfileOrder,
            couetteForceOrder,
            oscillatingProfileOrder,
            oscillatingForceOrder,
            maximumCrossFlow,
            batch.density,
            batch.velocity,
            batch.force,
        ].allSatisfy(\.isFinite)
        let passed = finite
            && couetteCases.allSatisfy {
                $0.normalizedProfileL2Error < maximumProfileError
                    && $0.relativeTopWallForceError
                        < maximumCouetteForceError
            }
            && oscillatingCases.allSatisfy {
                $0.normalizedProfileL2Error < maximumProfileError
                    && $0.relativeForcePhasorError
                        < maximumOscillatingForceError
                    && $0.relativeForceAmplitudeError
                        < maximumOscillatingForceError
                    && abs($0.forcePhaseErrorRadians)
                        < maximumForcePhaseErrorRadians
            }
            && maximumCrossFlow < maximumCrossFlowSpeed
            && oscillatingProfileOrder >= minimumProfileConvergenceOrder
            && couetteForceOrder >= minimumForceConvergenceOrder
            && oscillatingForceOrder >= minimumForceConvergenceOrder
            && batch.density < maximumBatchDifference
            && batch.velocity < maximumBatchDifference
            && batch.force < maximumBatchDifference

        let report = MetalMovingWallValidationReport(
            schemaVersion: 1,
            deviceName: backend.device.name,
            productionKernel: "stepFluidTRT",
            passed: passed,
            viscosity: Double(viscosity),
            wallVelocityAmplitude: Double(wallVelocityAmplitude),
            dimensionlessAngularFrequency: dimensionlessFrequency,
            couetteProfileConvergenceOrder: couetteProfileOrder,
            couetteForceConvergenceOrder: couetteForceOrder,
            oscillatingProfileConvergenceOrder: oscillatingProfileOrder,
            oscillatingForceConvergenceOrder: oscillatingForceOrder,
            maximumBatchDensityDifference: batch.density,
            maximumBatchVelocityDifference: batch.velocity,
            maximumBatchForceDifference: batch.force,
            maximumAllowedProfileError: maximumProfileError,
            maximumAllowedCouetteForceError: maximumCouetteForceError,
            maximumAllowedOscillatingForceError:
                maximumOscillatingForceError,
            maximumAllowedForcePhaseErrorRadians:
                maximumForcePhaseErrorRadians,
            maximumAllowedCrossFlowSpeed: maximumCrossFlowSpeed,
            minimumRequiredProfileConvergenceOrder:
                minimumProfileConvergenceOrder,
            minimumRequiredForceConvergenceOrder:
                minimumForceConvergenceOrder,
            maximumAllowedBatchDifference: maximumBatchDifference,
            couetteCases: couetteCases,
            oscillatingCases: oscillatingCases
        )
        if let archiveDirectory {
            try archiveReport(report, directory: archiveDirectory)
        }
        return report
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

#if canImport(Metal)
import Metal

private extension MetalMovingWallValidator {
    struct CaseArtifact<Result> {
        let result: Result
        let density: [Float]
        let velocity: [SIMD3<Float>]
    }

    struct BatchDifference {
        let density: Double
        let velocity: Double
        let force: Double
    }

    static func runHighReFixedWallCase(
        backend: MetalBackend,
        resolution: Int,
        matchedBirdChordCells: Int,
        viscosity: Float,
        wallVelocity: Float,
        steps: Int,
        maximumMassDrift: Double,
        maximumAbsolutePopulation: Double
    ) throws -> MetalHighReMovingWallCaseResult {
        let simulation = try MetalPlanarWallSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            amplitude: wallVelocity,
            angularFrequency: 0,
            oscillating: false
        )
        let initialPopulations = try simulation.copyPopulations()
        let initialMass = initialPopulations.reduce(0.0) {
            $0 + Double($1)
        }
        var finiteSteps = 0
        var firstNonFiniteStep: Int?
        var fieldsFinite = true
        var loadsFinite = true
        var maximumDensityDeviation = 0.0
        var maximumVelocityMagnitude = 0.0

        for step in 1...steps {
            let load = try simulation.advance(steps: 1, batchSize: 1)
            let fields = simulation.copyFields()
            let loadFinite = load.forceNewtons.x.isFinite
                && load.forceNewtons.y.isFinite
                && load.forceNewtons.z.isFinite
                && load.torqueNewtonMeters.x.isFinite
                && load.torqueNewtonMeters.y.isFinite
                && load.torqueNewtonMeters.z.isFinite
            let fieldFinite = fields.density.allSatisfy(\.isFinite)
                && fields.velocity.allSatisfy {
                    $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
                }
            loadsFinite = loadsFinite && loadFinite
            fieldsFinite = fieldsFinite && fieldFinite
            guard loadFinite, fieldFinite else {
                firstNonFiniteStep = step
                break
            }
            finiteSteps = step
            maximumDensityDeviation = max(
                maximumDensityDeviation,
                fields.density.lazy.map {
                    abs(Double($0) - 1)
                }.max() ?? 0
            )
            maximumVelocityMagnitude = max(
                maximumVelocityMagnitude,
                fields.velocity.lazy.map {
                    hypot(hypot(Double($0.x), Double($0.y)), Double($0.z))
                }.max() ?? 0
            )
        }

        let finalPopulations = try simulation.copyPopulations()
        let populationsFinite = finalPopulations.allSatisfy(\.isFinite)
        let finalMassValue = finalPopulations.reduce(0.0) {
            $0 + Double($1)
        }
        let finalMass = populationsFinite ? finalMassValue : nil
        let massDrift = finalMass.map {
            abs($0 - initialMass) / max(abs(initialMass), 1.0e-30)
        }
        let minimum = populationsFinite
            ? finalPopulations.min().map(Double.init)
            : nil
        let maximum = populationsFinite
            ? finalPopulations.max().map(Double.init)
            : nil
        let maximumAbsolute = populationsFinite
            ? finalPopulations.lazy.map { abs(Double($0)) }.max()
            : nil
        let passed = finiteSteps == steps
            && firstNonFiniteStep == nil
            && fieldsFinite
            && loadsFinite
            && populationsFinite
            && (massDrift ?? .infinity) <= maximumMassDrift
            && (maximumAbsolute ?? .infinity) <= maximumAbsolutePopulation
        let tauPlus = Float(0.5) + 3 * viscosity
        return MetalHighReMovingWallCaseResult(
            matchedBirdChordCells: matchedBirdChordCells,
            latticeKinematicViscosity: Double(viscosity),
            tauPlus: Double(tauPlus),
            tauPlusMarginAboveHalf: Double(tauPlus - 0.5),
            requestedSteps: steps,
            finiteSteps: finiteSteps,
            firstNonFiniteStep: firstNonFiniteStep,
            initialPopulationMass: initialMass,
            finalPopulationMass: finalMass,
            relativePopulationMassDrift: massDrift,
            minimumPopulation: minimum,
            maximumPopulation: maximum,
            maximumAbsolutePopulation: maximumAbsolute,
            maximumDensityDeviation: maximumDensityDeviation,
            maximumVelocityMagnitude: maximumVelocityMagnitude,
            fieldsFinite: fieldsFinite,
            loadsFinite: loadsFinite,
            passed: passed
        )
    }

    static func runTransientCouette(
        backend: MetalBackend,
        resolution: Int,
        viscosity: Float,
        amplitude: Float
    ) throws -> CaseArtifact<MetalTransientCouetteCaseResult> {
        let gap = Double(resolution - 2)
        let targetNormalizedTime = 0.2
        let steps = max(
            1,
            Int((targetNormalizedTime * gap * gap / Double(viscosity)).rounded())
        )
        let simulation = try MetalPlanarWallSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            amplitude: amplitude,
            angularFrequency: 0,
            oscillating: false
        )
        let load = try simulation.advance(steps: steps, batchSize: 64)
        let fields = simulation.copyFields()
        let measured = profile(
            velocity: fields.velocity,
            resolution: resolution
        )
        let time = Double(steps)
        var numerator = 0.0
        var denominator = 0.0
        for y in 1..<(resolution - 1) {
            let eta = (Double(y) - 0.5) / gap
            let exact = transientCouetteVelocity(
                eta: eta,
                time: time,
                gap: gap,
                viscosity: Double(viscosity),
                amplitude: Double(amplitude)
            )
            let difference = measured.tangential[y] - exact
            numerator += difference * difference
            denominator += exact * exact
        }
        let normalizedError = sqrt(numerator / max(denominator, 1.0e-30))
        let derivative = transientCouetteTopDerivative(
            time: time,
            gap: gap,
            viscosity: Double(viscosity),
            amplitude: Double(amplitude)
        )
        let analyticForce = -Double(viscosity)
            * Double(resolution * resolution)
            * derivative
        let measuredForce = Double(load.forceNewtons.x)
        let forceError = abs(measuredForce - analyticForce)
            / max(abs(analyticForce), 1.0e-30)

        return CaseArtifact(
            result: MetalTransientCouetteCaseResult(
                resolution: resolution,
                steps: steps,
                normalizedTime:
                    Double(viscosity) * time / (gap * gap),
                normalizedProfileL2Error: normalizedError,
                maximumCrossFlowSpeed: measured.maximumCrossFlow,
                measuredTopWallForce: measuredForce,
                analyticTopWallForce: analyticForce,
                relativeTopWallForceError: forceError
            ),
            density: fields.density,
            velocity: fields.velocity
        )
    }

    static func runOscillatingWall(
        backend: MetalBackend,
        resolution: Int,
        viscosity: Float,
        amplitude: Float,
        dimensionlessFrequency: Double,
        warmupCycles: Int,
        sampleCount: Int
    ) throws -> CaseArtifact<MetalOscillatingWallCaseResult> {
        let gap = Double(resolution - 2)
        let omega = dimensionlessFrequency
            * Double(viscosity)
            / (gap * gap)
        let period = 2 * Double.pi / omega
        let warmupSteps = Int((Double(warmupCycles) * period).rounded())
        let simulation = try MetalPlanarWallSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            amplitude: amplitude,
            angularFrequency: Float(omega),
            oscillating: true
        )
        var load = try simulation.advance(steps: warmupSteps, batchSize: 64)
        var currentStep = warmupSteps
        var profileNumerator = 0.0
        var profileDenominator = 0.0
        var forceNumerator = 0.0
        var forceDenominator = 0.0
        var phases: [Double] = []
        var measuredForces: [Double] = []
        var maximumCrossFlow = 0.0
        var finalFields = simulation.copyFields()
        let analyticForcePhasor = oscillatingTopForcePhasor(
            gap: gap,
            omega: omega,
            viscosity: Double(viscosity),
            amplitude: Double(amplitude),
            area: Double(resolution * resolution)
        )

        for sample in 0..<sampleCount {
            let target = warmupSteps
                + Int((Double(sample) * period / Double(sampleCount)).rounded())
            if target > currentStep {
                load = try simulation.advance(
                    steps: target - currentStep,
                    batchSize: 64
                )
                currentStep = target
            }
            let fields = simulation.copyFields()
            finalFields = fields
            let measured = profile(
                velocity: fields.velocity,
                resolution: resolution
            )
            maximumCrossFlow = max(
                maximumCrossFlow,
                measured.maximumCrossFlow
            )
            let phase = omega * Double(currentStep)
            phases.append(phase)
            let measuredForce = Double(load.forceNewtons.x)
            measuredForces.append(measuredForce)
            let exactForce = analyticForcePhasor.value(at: phase)
            let forceDifference = measuredForce - exactForce
            forceNumerator += forceDifference * forceDifference
            forceDenominator += exactForce * exactForce

            for y in 1..<(resolution - 1) {
                let distance = Double(y) - 0.5
                let exact = oscillatingVelocityPhasor(
                    distance: distance,
                    gap: gap,
                    omega: omega,
                    viscosity: Double(viscosity),
                    amplitude: Double(amplitude)
                ).value(at: phase)
                let difference = measured.tangential[y] - exact
                profileNumerator += difference * difference
                profileDenominator += exact * exact
            }
        }

        let measuredForcePhasor = fitPhasor(
            phases: phases,
            values: measuredForces
        )
        let phasorError = (measuredForcePhasor - analyticForcePhasor).magnitude
            / max(analyticForcePhasor.magnitude, 1.0e-30)
        let amplitudeError = abs(
            measuredForcePhasor.magnitude - analyticForcePhasor.magnitude
        ) / max(analyticForcePhasor.magnitude, 1.0e-30)
        let phaseError = wrappedAngle(
            measuredForcePhasor.phase - analyticForcePhasor.phase
        )

        return CaseArtifact(
            result: MetalOscillatingWallCaseResult(
                resolution: resolution,
                angularFrequency: omega,
                warmupCycles: warmupCycles,
                sampleCount: sampleCount,
                normalizedProfileL2Error: sqrt(
                    profileNumerator / max(profileDenominator, 1.0e-30)
                ),
                maximumCrossFlowSpeed: maximumCrossFlow,
                normalizedForceRMSError: sqrt(
                    forceNumerator / max(forceDenominator, 1.0e-30)
                ),
                relativeForcePhasorError: phasorError,
                relativeForceAmplitudeError: amplitudeError,
                forcePhaseErrorRadians: phaseError
            ),
            density: finalFields.density,
            velocity: finalFields.velocity
        )
    }

    static func compareBatchPartitions(
        backend: MetalBackend,
        viscosity: Float,
        amplitude: Float,
        dimensionlessFrequency: Double
    ) throws -> BatchDifference {
        let resolution = 16
        let gap = Double(resolution - 2)
        let omega = Float(
            dimensionlessFrequency * Double(viscosity) / (gap * gap)
        )
        let batched = try MetalPlanarWallSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            amplitude: amplitude,
            angularFrequency: omega,
            oscillating: true
        )
        let stepwise = try MetalPlanarWallSimulation(
            backend: backend,
            resolution: resolution,
            viscosity: viscosity,
            amplitude: amplitude,
            angularFrequency: omega,
            oscillating: true
        )
        let batchedLoad = try batched.advance(steps: 32, batchSize: 32)
        var stepwiseLoad = ForceTorque()
        for _ in 0..<32 {
            stepwiseLoad = try stepwise.advance(steps: 1, batchSize: 1)
        }
        let batchedFields = batched.copyFields()
        let stepwiseFields = stepwise.copyFields()
        var densityDifference = 0.0
        var velocityDifference = 0.0
        for index in batchedFields.density.indices {
            densityDifference = max(
                densityDifference,
                Double(abs(
                    batchedFields.density[index]
                        - stepwiseFields.density[index]
                ))
            )
            velocityDifference = max(
                velocityDifference,
                Double(vectorLength(
                    batchedFields.velocity[index]
                        - stepwiseFields.velocity[index]
                ))
            )
        }
        return BatchDifference(
            density: densityDifference,
            velocity: velocityDifference,
            force: Double(vectorLength(
                batchedLoad.forceNewtons - stepwiseLoad.forceNewtons
            ))
        )
    }

    static func profile(
        velocity: [SIMD3<Float>],
        resolution: Int
    ) -> (tangential: [Double], maximumCrossFlow: Double) {
        var tangential = Array(repeating: 0.0, count: resolution)
        var counts = Array(repeating: 0, count: resolution)
        var maximumCrossFlow = 0.0
        let plane = resolution * resolution
        for index in velocity.indices {
            let y = (index % plane) / resolution
            guard y > 0, y + 1 < resolution else { continue }
            let value = velocity[index]
            tangential[y] += Double(value.x)
            counts[y] += 1
            maximumCrossFlow = max(
                maximumCrossFlow,
                hypot(Double(value.y), Double(value.z))
            )
        }
        for y in tangential.indices where counts[y] > 0 {
            tangential[y] /= Double(counts[y])
        }
        return (tangential, maximumCrossFlow)
    }

    static func transientCouetteVelocity(
        eta: Double,
        time: Double,
        gap: Double,
        viscosity: Double,
        amplitude: Double
    ) -> Double {
        var value = eta
        for n in 1...200 {
            let mode = Double(n)
            let decay = exp(
                -mode * mode * Double.pi * Double.pi
                    * viscosity * time / (gap * gap)
            )
            let sign = n.isMultiple(of: 2) ? 1.0 : -1.0
            value += 2 * sign / (mode * Double.pi)
                * sin(mode * Double.pi * eta)
                * decay
            if decay < 1.0e-15 { break }
        }
        return amplitude * value
    }

    static func transientCouetteTopDerivative(
        time: Double,
        gap: Double,
        viscosity: Double,
        amplitude: Double
    ) -> Double {
        var sum = 0.0
        for n in 1...200 {
            let mode = Double(n)
            let decay = exp(
                -mode * mode * Double.pi * Double.pi
                    * viscosity * time / (gap * gap)
            )
            sum += decay
            if decay < 1.0e-15 { break }
        }
        return amplitude / gap * (1 + 2 * sum)
    }

    static func oscillatingVelocityPhasor(
        distance: Double,
        gap: Double,
        omega: Double,
        viscosity: Double,
        amplitude: Double
    ) -> ValidationComplex {
        let scale = sqrt(omega / (2 * viscosity))
        let wave = ValidationComplex(real: scale, imaginary: scale)
        return amplitude * (wave * distance).sinh
            / (wave * gap).sinh
    }

    static func oscillatingTopForcePhasor(
        gap: Double,
        omega: Double,
        viscosity: Double,
        amplitude: Double,
        area: Double
    ) -> ValidationComplex {
        let scale = sqrt(omega / (2 * viscosity))
        let wave = ValidationComplex(real: scale, imaginary: scale)
        let argument = wave * gap
        return -viscosity * area * amplitude
            * wave * argument.cosh / argument.sinh
    }

    static func fitPhasor(
        phases: [Double],
        values: [Double]
    ) -> ValidationComplex {
        var cc = 0.0
        var ss = 0.0
        var cs = 0.0
        var cy = 0.0
        var sy = 0.0
        for (phase, value) in zip(phases, values) {
            let cosine = cos(phase)
            let sine = sin(phase)
            cc += cosine * cosine
            ss += sine * sine
            cs += cosine * sine
            cy += cosine * value
            sy += sine * value
        }
        let determinant = cc * ss - cs * cs
        let cosineCoefficient = (cy * ss - sy * cs) / determinant
        let sineCoefficient = (sy * cc - cy * cs) / determinant
        return ValidationComplex(
            real: cosineCoefficient,
            imaginary: -sineCoefficient
        )
    }

    static func wrappedAngle(_ value: Double) -> Double {
        atan2(sin(value), cos(value))
    }

    static func convergenceOrder(
        resolutions: [Int],
        errors: [Double]
    ) -> Double {
        let x = resolutions.map { log(1 / Double($0 - 2)) }
        let y = errors.map { log(max($0, 1.0e-30)) }
        let meanX = x.reduce(0, +) / Double(x.count)
        let meanY = y.reduce(0, +) / Double(y.count)
        var numerator = 0.0
        var denominator = 0.0
        for index in x.indices {
            numerator += (x[index] - meanX) * (y[index] - meanY)
            denominator += (x[index] - meanX) * (x[index] - meanX)
        }
        return numerator / denominator
    }

    static func archiveFields(
        directory: URL,
        stem: String,
        density: [Float],
        velocity: [SIMD3<Float>]
    ) throws {
        try littleEndianFloatData(density).write(
            to: directory.appendingPathComponent("\(stem)-density.f32le"),
            options: .atomic
        )
        let interleaved = velocity.flatMap { [$0.x, $0.y, $0.z] }
        try littleEndianFloatData(interleaved).write(
            to: directory.appendingPathComponent("\(stem)-velocity.xyz.f32le"),
            options: .atomic
        )
    }

    static func archiveReport(
        _ report: MetalMovingWallValidationReport,
        directory: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(
            to: directory.appendingPathComponent("report.json"),
            options: .atomic
        )
        let format = """
        BirdFlowMetal moving-wall archive schema 1
        Density files: little-endian Float32, one value per cell.
        Velocity files: little-endian Float32 triples (x,y,z) per cell.
        Cell order: x + N * (y + N * z), with x varying fastest.
        Couette fields are captured at the comparison time. Stokes fields are
        captured at the final sampled phase. Metrics and gates are in report.json.
        """
        try format.write(
            to: directory.appendingPathComponent("FORMAT.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func littleEndianFloatData(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * MemoryLayout<UInt32>.stride)
        for value in values {
            var bits = value.bitPattern.littleEndian
            withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
        }
        return data
    }
}

private struct ValidationComplex {
    var real: Double
    var imaginary: Double

    var magnitude: Double { hypot(real, imaginary) }
    var phase: Double { atan2(imaginary, real) }
    var sinh: Self {
        Self(
            real: Foundation.sinh(real) * cos(imaginary),
            imaginary: Foundation.cosh(real) * sin(imaginary)
        )
    }
    var cosh: Self {
        Self(
            real: Foundation.cosh(real) * cos(imaginary),
            imaginary: Foundation.sinh(real) * sin(imaginary)
        )
    }
    func value(at phase: Double) -> Double {
        real * cos(phase) - imaginary * sin(phase)
    }

    static func + (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real + rhs.real, imaginary: lhs.imaginary + rhs.imaginary)
    }
    static func - (lhs: Self, rhs: Self) -> Self {
        Self(real: lhs.real - rhs.real, imaginary: lhs.imaginary - rhs.imaginary)
    }
    static prefix func - (value: Self) -> Self {
        Self(real: -value.real, imaginary: -value.imaginary)
    }
    static func * (lhs: Self, rhs: Self) -> Self {
        Self(
            real: lhs.real * rhs.real - lhs.imaginary * rhs.imaginary,
            imaginary: lhs.real * rhs.imaginary + lhs.imaginary * rhs.real
        )
    }
    static func * (lhs: Self, rhs: Double) -> Self {
        Self(real: lhs.real * rhs, imaginary: lhs.imaginary * rhs)
    }
    static func * (lhs: Double, rhs: Self) -> Self { rhs * lhs }
    static func / (lhs: Self, rhs: Self) -> Self {
        let denominator = rhs.real * rhs.real + rhs.imaginary * rhs.imaginary
        return Self(
            real: (lhs.real * rhs.real + lhs.imaginary * rhs.imaginary)
                / denominator,
            imaginary: (lhs.imaginary * rhs.real - lhs.real * rhs.imaginary)
                / denominator
        )
    }
}

private final class MetalPlanarWallSimulation {
    private let backend: MetalBackend
    private let configuration: SimulationConfiguration
    private let amplitude: Float
    private let angularFrequency: Float
    private let oscillating: Bool
    private let initializationPipeline: MTLComputePipelineState
    private let wallUpdatePipeline: MTLComputePipelineState
    private let fluidStepPipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let populationsA: MTLBuffer
    private let populationsB: MTLBuffer
    private let solidMaskA: MTLBuffer
    private let solidMaskB: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let density: MTLBuffer
    private let velocity: MTLBuffer
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let bodyState: MTLBuffer
    private let partialLoadCount: Int
    private var currentPopulations: MTLBuffer
    private var nextPopulations: MTLBuffer
    private var lastLoadBuffer: MTLBuffer
    private var stepIndex = 0

    init(
        backend: MetalBackend,
        resolution: Int,
        viscosity: Float,
        amplitude: Float,
        angularFrequency: Float,
        oscillating: Bool
    ) throws {
        self.backend = backend
        self.amplitude = amplitude
        self.angularFrequency = angularFrequency
        self.oscillating = oscillating
        let grid = try GridSize(x: resolution, y: resolution, z: resolution)
        let scaling = try LatticeScaling(
            characteristicLengthMeters: Float(resolution),
            characteristicLengthCells: resolution,
            referenceSpeedMetersPerSecond: amplitude,
            targetReynoldsNumber: amplitude * Float(resolution) / viscosity,
            physicalAirDensity: 1,
            latticeReferenceSpeed: amplitude
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: 4,
            spongeStrength: 0,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        initializationPipeline = try backend.pipeline(
            named: "initializePlanarChannel"
        )
        wallUpdatePipeline = try backend.pipeline(
            named: "updatePlanarWallVelocity"
        )
        fluidStepPipeline = try backend.pipeline(named: "stepFluidTRT")
        reductionPipeline = try backend.pipeline(named: "reduceForceTorque")

        let cellCount = grid.cellCount
        let populationBytes = D3Q19.count
            * cellCount
            * MemoryLayout<Float>.stride
        let maskBytes = cellCount * MemoryLayout<UInt8>.stride
        let wallBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        let densityBytes = cellCount * MemoryLayout<Float>.stride
        let velocityBytes = cellCount * MemoryLayout<SIMD4<Float>>.stride
        partialLoadCount = max(1, (cellCount + 255) / 256)
        let reductionBytes = partialLoadCount
            * MemoryLayout<GPUForceTorque>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            populationBytes, populationBytes,
            maskBytes, maskBytes, wallBytes,
            densityBytes, velocityBytes,
            reductionBytes, reductionBytes,
            MemoryLayout<GPUBirdBodyState>.stride,
        ])
        populationsA = try backend.makePrivateBuffer(length: populationBytes)
        populationsB = try backend.makePrivateBuffer(length: populationBytes)
        solidMaskA = try backend.makePrivateBuffer(length: maskBytes)
        solidMaskB = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(length: wallBytes)
        density = try backend.makeSharedBuffer(length: densityBytes)
        velocity = try backend.makeSharedBuffer(length: velocityBytes)
        reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        bodyState = try backend.makeSharedBuffer(
            value: GPUBirdBodyState(BirdBodyState(positionMeters: .zero))
        )
        currentPopulations = populationsA
        nextPopulations = populationsB
        lastLoadBuffer = reductionA

        try encodePlanarInitialization()
    }

    func advance(steps: Int, batchSize: Int) throws -> ForceTorque {
        guard steps >= 0, batchSize > 0 else {
            throw BirdFlowError.invalidAdvanceRequest(
                steps: steps,
                batchSize: batchSize
            )
        }
        var remaining = steps
        while remaining > 0 {
            let count = min(batchSize, remaining)
            guard let commandBuffer = backend.queue.makeCommandBuffer() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create planar-wall command buffer."
                )
            }
            for localStep in 0..<count {
                let absoluteStep = stepIndex + localStep + 1
                var uniforms = makeUniforms(
                    time: Float(absoluteStep),
                    capture: remaining == count && localStep == count - 1
                )
                try encodePlanarWallUpdate(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                try encodePlanarFluidStep(
                    commandBuffer: commandBuffer,
                    uniforms: &uniforms
                )
                swap(&currentPopulations, &nextPopulations)
                if remaining == count && localStep == count - 1 {
                    lastLoadBuffer = try encodePlanarReduction(
                        commandBuffer: commandBuffer
                    )
                }
            }
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            try check(commandBuffer)
            stepIndex += count
            remaining -= count
        }
        return lastLoadBuffer.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
            .pointee
            .coreValue
    }

    func copyFields() -> (density: [Float], velocity: [SIMD3<Float>]) {
        let count = configuration.grid.cellCount
        let densityPointer = density.contents().assumingMemoryBound(to: Float.self)
        let velocityPointer = velocity.contents()
            .assumingMemoryBound(to: SIMD4<Float>.self)
        return (
            Array(UnsafeBufferPointer(start: densityPointer, count: count)),
            (0..<count).map {
                let value = velocityPointer[$0]
                return SIMD3<Float>(value.x, value.y, value.z)
            }
        )
    }

    func copyPopulations() throws -> [Float] {
        let staging = try backend.makeSharedBuffer(
            length: currentPopulations.length
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create planar-wall population readback."
            )
        }
        blit.copy(
            from: currentPopulations,
            sourceOffset: 0,
            to: staging,
            destinationOffset: 0,
            size: currentPopulations.length
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
        let count = staging.length / MemoryLayout<Float>.stride
        let pointer = staging.contents().assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    private func makeUniforms(time: Float, capture: Bool) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: time,
            captureMacroscopicFields: capture,
            periodicBoundaries: true,
            caseParameters: SIMD4<Float>(
                amplitude,
                angularFrequency,
                2,
                oscillating ? 1 : 0
            )
        )
    }

    private func encodePlanarInitialization() throws {
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create planar-wall initialization encoder."
            )
        }
        var uniforms = makeUniforms(time: 0, capture: true)
        encoder.label = "Initialize planar moving-wall channel"
        encoder.setBuffer(populationsA, offset: 0, index: 0)
        encoder.setBuffer(solidMaskA, offset: 0, index: 1)
        encoder.setBuffer(solidMaskB, offset: 0, index: 2)
        encoder.setBuffer(wallVelocity, offset: 0, index: 3)
        encoder.setBuffer(density, offset: 0, index: 4)
        encoder.setBuffer(velocity, offset: 0, index: 5)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 6
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: initializationPipeline,
            count: configuration.grid.cellCount
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)
    }

    private func encodePlanarWallUpdate(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create planar-wall update encoder."
            )
        }
        encoder.label = "Update planar wall velocity"
        encoder.setBuffer(wallVelocity, offset: 0, index: 0)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 1
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: wallUpdatePipeline,
            count: configuration.grid.x * configuration.grid.z
        )
        encoder.endEncoding()
    }

    private func encodePlanarFluidStep(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create planar-wall fluid encoder."
            )
        }
        encoder.label = "Production D3Q19 TRT planar moving wall"
        encoder.setBuffer(currentPopulations, offset: 0, index: 0)
        encoder.setBuffer(nextPopulations, offset: 0, index: 1)
        encoder.setBuffer(solidMaskA, offset: 0, index: 2)
        encoder.setBuffer(solidMaskB, offset: 0, index: 3)
        encoder.setBuffer(wallVelocity, offset: 0, index: 4)
        encoder.setBuffer(density, offset: 0, index: 5)
        encoder.setBuffer(velocity, offset: 0, index: 6)
        encoder.setBuffer(reductionA, offset: 0, index: 7)
        encoder.setBuffer(bodyState, offset: 0, index: 8)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 9
        )
        backend.dispatch1DPadded(
            encoder: encoder,
            pipeline: fluidStepPipeline,
            count: configuration.grid.cellCount,
            threadsPerThreadgroup: 256
        )
        encoder.endEncoding()
    }

    private func encodePlanarReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        var input = reductionA
        var output = reductionB
        var inputCount = partialLoadCount
        while inputCount > 1 {
            let outputCount = (inputCount + 255) / 256
            var count32 = UInt32(inputCount)
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to create planar-wall load reduction encoder."
                )
            }
            encoder.setBuffer(input, offset: 0, index: 0)
            encoder.setBuffer(output, offset: 0, index: 1)
            encoder.setBytes(
                &count32,
                length: MemoryLayout<UInt32>.stride,
                index: 2
            )
            backend.dispatch1D(
                encoder: encoder,
                pipeline: reductionPipeline,
                count: outputCount
            )
            encoder.endEncoding()
            inputCount = outputCount
            input = output
            output = output === reductionA ? reductionB : reductionA
        }
        return input
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Unknown Metal planar-wall error"
            )
        }
    }
}
#endif

import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal
#endif

public struct MetalDirectionCompositionOrientation: Codable, Sendable {
    public let identifier: String
    public let integerNormal: [Int]
}

public struct MetalDirectionCompositionPopulationProfile: Codable, Sendable {
    public let identifier: String
    public let directionPopulations: [Double]
    public let source: String
}

public struct MetalDirectionCompositionRevisionHistory: Codable, Sendable {
    public let v1PreregistrationSHA256: String
    public let v1FailedReportSHA256: String
    public let v1Failure: String
    public let v2OnlyChange: String
}

public struct MetalDirectionCompositionPreregistration: Codable, Sendable {
    public let schemaVersion: Int
    public let preregistrationIdentifier: String
    public let revisionHistory: MetalDirectionCompositionRevisionHistory
    public let sourceDiscriminatorSHA256: String
    public let sourceDiscriminatorAuditSHA256: String
    public let sourceD28ProvenanceSHA256: String
    public let sourceD32ProvenanceSHA256: String
    public let referenceLengthCells: [Int]
    public let patchSideLengthMeters: Double
    public let domainSideLengthMeters: Double
    public let subcellPhaseOffsets: [Double]
    public let planeOffsetRule: String
    public let evaluationArithmetic: String
    public let orientations: [MetalDirectionCompositionOrientation]
    public let fixedPopulationProfiles: [
        MetalDirectionCompositionPopulationProfile
    ]
    public let analyticReference: String
    public let fixedInputs: String
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let maximumMetalCPUCountRelativeDifference: Double
    public let maximumFineProfileVectorRelativeError: Double
    public let maximumCoarseFinePhaseMeanProfileRelativeDifference: Double
    public let maximumFinePhaseProfileRelativeSpread: Double
    public let maximumCoarseFineDirectionHistogramTotalVariation: Double
    public let maximumEquilibriumFineNormalResponseError: Double
    public let maximumEquilibriumFineTangentialLeakage: Double
    public let classificationRule: String
    public let fluidEvolutionAuthorized: Bool
    public let productionModificationAuthorized: Bool
    public let d36RunAuthorized: Bool
    public let gridConvergenceGateApplied: Bool
    public let experimentalAgreementGateApplied: Bool
    public let claimBoundary: String
    public let passed: Bool
}

public struct MetalDirectionCompositionProfileResponse: Codable, Sendable {
    public let profileIdentifier: String
    public let analyticResponse: SIMD3<Double>
    public let metalResponse: SIMD3<Double>
    public let cpuResponse: SIMD3<Double>
    public let metalVectorRelativeError: Double
    public let cpuVectorRelativeError: Double
}

public struct MetalDirectionCompositionCaseReport: Codable, Sendable {
    public let referenceLengthCells: Int
    public let gridSideCells: Int
    public let cellSizeMeters: Double
    public let orientationIdentifier: String
    public let normal: SIMD3<Double>
    public let tangentU: SIMD3<Double>
    public let tangentV: SIMD3<Double>
    public let subcellPhaseOffset: Double
    public let planeOffsetMeters: Double
    public let metalDirectionLinkCounts: [Int]
    public let cpuDirectionLinkCounts: [Int]
    public let totalMetalLinkCount: Int
    public let totalCPULinkCount: Int
    public let maximumPerDirectionCountMismatch: Int
    public let countRelativeDifference: Double
    public let directionHistogram: [Double]
    public let profileResponses: [MetalDirectionCompositionProfileResponse]
}

public struct MetalDirectionCompositionProfileSummary: Codable, Sendable {
    public let profileIdentifier: String
    public let coarsePhaseMeanResponse: SIMD3<Double>
    public let finePhaseMeanResponse: SIMD3<Double>
    public let analyticResponse: SIMD3<Double>
    public let maximumFineVectorRelativeError: Double
    public let coarseFinePhaseMeanRelativeDifference: Double
    public let maximumFinePhaseRelativeSpread: Double
}

public struct MetalDirectionCompositionOrientationSummary: Codable, Sendable {
    public let orientationIdentifier: String
    public let normal: SIMD3<Double>
    public let coarseFineDirectionHistogramTotalVariation: Double
    public let equilibriumFineNormalResponseError: Double
    public let equilibriumFineTangentialLeakage: Double
    public let profiles: [MetalDirectionCompositionProfileSummary]
}

public struct MetalDirectionCompositionCanonicalReport: Codable, Sendable {
    public let schemaVersion: Int
    public let canonicalIdentifier: String
    public let deviceName: String
    public let sourcePreregistrationSHA256: String
    public let runtimeSeconds: Double
    public let kernel: String
    public let fixedInterpolationFraction: Double
    public let fluidEvolutionExecuted: Bool
    public let cases: [MetalDirectionCompositionCaseReport]
    public let orientationSummaries: [
        MetalDirectionCompositionOrientationSummary
    ]
    public let maximumMetalCPUPerDirectionCountMismatch: Int
    public let maximumMetalCPUCountRelativeDifference: Double
    public let maximumFineProfileVectorRelativeError: Double
    public let maximumCoarseFinePhaseMeanProfileRelativeDifference: Double
    public let maximumFinePhaseProfileRelativeSpread: Double
    public let maximumCoarseFineDirectionHistogramTotalVariation: Double
    public let maximumEquilibriumFineNormalResponseError: Double
    public let maximumEquilibriumFineTangentialLeakage: Double
    public let gates: [String: Bool]
    public let equilibriumProfilePassed: Bool
    public let sourceMidpointProfilePassed: Bool
    public let basicPlanarDirectionWeightingCleared: Bool
    public let classification: String
    public let productionModificationAuthorized: Bool
    public let d36RunAuthorized: Bool
    public let gridConvergenceGateApplied: Bool
    public let experimentalAgreementGateApplied: Bool
    public let canonicalPassed: Bool
    public let scientificVerdict: String
    public let nextAction: String
    public let claimBoundary: String
}

public enum MetalDirectionCompositionValidationError: Error,
    CustomStringConvertible
{
    case invalidPreregistration(String)
    case executionFailed(String)

    public var description: String {
        switch self {
        case .invalidPreregistration(let message): return message
        case .executionFailed(let message): return message
        }
    }
}

public enum MetalDirectionCompositionValidator {
    public static func run(
        preregistration: MetalDirectionCompositionPreregistration,
        sourcePreregistrationSHA256: String
    ) throws -> MetalDirectionCompositionCanonicalReport {
#if canImport(Metal)
        try validate(preregistration, sha256: sourcePreregistrationSHA256)
        let start = Date()
        let backend = try MetalBackend(fastMath: false)
        let pipeline = try backend.pipeline(
            named: "measureObliquePlaneDirectionComposition"
        )
        var cases = [MetalDirectionCompositionCaseReport]()
        for resolution in preregistration.referenceLengthCells {
            let dx = Float(
                preregistration.patchSideLengthMeters / Double(resolution)
            )
            let gridSide = Int(ceil(
                preregistration.domainSideLengthMeters / Double(dx)
            ))
            let actualDomainSide = Float(gridSide) * dx
            let origin = SIMD3<Float>(repeating: -0.5 * actualDomainSide)
            for orientation in preregistration.orientations {
                let frame = try orientationFrame(orientation)
                for phase in preregistration.subcellPhaseOffsets {
                    let offset = Float(phase - 0.5) * dx
                    let parameters = GPUDirectionCompositionParameters(
                        grid: SIMD4<UInt32>(
                            UInt32(gridSide), UInt32(gridSide),
                            UInt32(gridSide), UInt32(gridSide * gridSide * gridSide)
                        ),
                        originAndCellSize: SIMD4<Float>(
                            origin.x, origin.y, origin.z, dx
                        ),
                        normalAndOffset: SIMD4<Float>(
                            frame.normal.x, frame.normal.y, frame.normal.z, offset
                        ),
                        tangentUAndHalfExtent: SIMD4<Float>(
                            frame.tangentU.x, frame.tangentU.y, frame.tangentU.z,
                            0.5 * Float(preregistration.patchSideLengthMeters)
                        ),
                        tangentVAndHalfExtent: SIMD4<Float>(
                            frame.tangentV.x, frame.tangentV.y, frame.tangentV.z,
                            0.5 * Float(preregistration.patchSideLengthMeters)
                        ),
                        integerNormalAndPhase: SIMD4<Float>(
                            Float(orientation.integerNormal[0]),
                            Float(orientation.integerNormal[1]),
                            Float(orientation.integerNormal[2]),
                            Float(phase)
                        )
                    )
                    let metalCounts = try metalCounts(
                        backend: backend,
                        pipeline: pipeline,
                        parameters: parameters
                    )
                    let cpuCounts = cpuCounts(parameters: parameters)
                    cases.append(makeCase(
                        preregistration: preregistration,
                        resolution: resolution,
                        gridSide: gridSide,
                        dx: dx,
                        orientation: orientation,
                        frame: frame,
                        phase: phase,
                        offset: offset,
                        metalCounts: metalCounts,
                        cpuCounts: cpuCounts
                    ))
                }
            }
        }
        let summaries = try makeSummaries(
            preregistration: preregistration,
            cases: cases
        )
        let maximumCountMismatch = cases.map(
            \.maximumPerDirectionCountMismatch
        ).max() ?? .max
        let maximumCountRelativeDifference = cases.map(
            \.countRelativeDifference
        ).max() ?? .infinity
        let profileSummaries = summaries.flatMap(\.profiles)
        let maximumFineError = profileSummaries.map(
            \.maximumFineVectorRelativeError
        ).max() ?? .infinity
        let maximumCoarseFine = profileSummaries.map(
            \.coarseFinePhaseMeanRelativeDifference
        ).max() ?? .infinity
        let maximumFinePhaseSpread = profileSummaries.map(
            \.maximumFinePhaseRelativeSpread
        ).max() ?? .infinity
        let maximumHistogramTV = summaries.map(
            \.coarseFineDirectionHistogramTotalVariation
        ).max() ?? .infinity
        let maximumNormalError = summaries.map(
            \.equilibriumFineNormalResponseError
        ).max() ?? .infinity
        let maximumTangentialLeakage = summaries.map(
            \.equilibriumFineTangentialLeakage
        ).max() ?? .infinity
        let gates = [
            "metalCPUPerDirectionCounts": maximumCountMismatch
                <= preregistration.maximumMetalCPUPerDirectionCountMismatch,
            "metalCPUCountRelativeDifference": maximumCountRelativeDifference
                <= preregistration.maximumMetalCPUCountRelativeDifference,
            "fineProfileVectorResponse": maximumFineError
                <= preregistration.maximumFineProfileVectorRelativeError,
            "coarseFinePhaseMeanResponse": maximumCoarseFine
                <= preregistration
                    .maximumCoarseFinePhaseMeanProfileRelativeDifference,
            "finePhaseResponseStability": maximumFinePhaseSpread
                <= preregistration.maximumFinePhaseProfileRelativeSpread,
            "coarseFineDirectionHistogram": maximumHistogramTV
                <= preregistration
                    .maximumCoarseFineDirectionHistogramTotalVariation,
            "equilibriumFineNormalResponse": maximumNormalError
                <= preregistration.maximumEquilibriumFineNormalResponseError,
            "equilibriumFineTangentialLeakage": maximumTangentialLeakage
                <= preregistration.maximumEquilibriumFineTangentialLeakage,
        ]
        func profilePassed(_ identifier: String) -> Bool {
            profileSummaries.filter { $0.profileIdentifier == identifier }
                .allSatisfy {
                    $0.maximumFineVectorRelativeError
                        <= preregistration.maximumFineProfileVectorRelativeError
                        && $0.coarseFinePhaseMeanRelativeDifference
                            <= preregistration
                                .maximumCoarseFinePhaseMeanProfileRelativeDifference
                        && $0.maximumFinePhaseRelativeSpread
                            <= preregistration.maximumFinePhaseProfileRelativeSpread
                }
        }
        let equilibriumPassed = profilePassed("rest-equilibrium")
            && gates["equilibriumFineNormalResponse"] == true
            && gates["equilibriumFineTangentialLeakage"] == true
        let sourcePassed = profilePassed("deetjen-midpoint-pooled")
        let passed = gates.values.allSatisfy { $0 }
        let classification = passed
            ? "direction-weighting-cleared-in-planar-canonical"
            : equilibriumPassed && !sourcePassed
                ? "bird-like-direction-composition-aliasing"
                : !equilibriumPassed && sourcePassed
                    ? "equilibrium-direction-weighting-failure"
                    : "general-direction-composition-aliasing"
        let verdict = passed
            ? "The static two-grid, five-phase Metal/CPU planar canonical clears basic D3Q19 direction counting and fixed-population response under both equilibrium and source-locked bird-like populations."
            : "The static planar canonical exposes a direction-composition response outside at least one preregistered Metal/CPU, analytic, phase, or grid gate."
        let nextAction = passed
            ? "Do not modify production direction weighting. Use one source-locked curved-surface direction-only canonical before attributing the measured-bird grid trend to complex boundary geometry."
            : "Localize the failing orientation, direction, profile, and phase before any production edit or fluid run."
        return MetalDirectionCompositionCanonicalReport(
            schemaVersion: 1,
            canonicalIdentifier: preregistration.preregistrationIdentifier,
            deviceName: backend.device.name,
            sourcePreregistrationSHA256: sourcePreregistrationSHA256.lowercased(),
            runtimeSeconds: Date().timeIntervalSince(start),
            kernel: "measureObliquePlaneDirectionComposition",
            fixedInterpolationFraction: 0.5,
            fluidEvolutionExecuted: false,
            cases: cases,
            orientationSummaries: summaries,
            maximumMetalCPUPerDirectionCountMismatch: maximumCountMismatch,
            maximumMetalCPUCountRelativeDifference:
                maximumCountRelativeDifference,
            maximumFineProfileVectorRelativeError: maximumFineError,
            maximumCoarseFinePhaseMeanProfileRelativeDifference:
                maximumCoarseFine,
            maximumFinePhaseProfileRelativeSpread: maximumFinePhaseSpread,
            maximumCoarseFineDirectionHistogramTotalVariation:
                maximumHistogramTV,
            maximumEquilibriumFineNormalResponseError: maximumNormalError,
            maximumEquilibriumFineTangentialLeakage:
                maximumTangentialLeakage,
            gates: gates,
            equilibriumProfilePassed: equilibriumPassed,
            sourceMidpointProfilePassed: sourcePassed,
            basicPlanarDirectionWeightingCleared: passed,
            classification: classification,
            productionModificationAuthorized: false,
            d36RunAuthorized: false,
            gridConvergenceGateApplied: false,
            experimentalAgreementGateApplied: false,
            canonicalPassed: passed,
            scientificVerdict: verdict,
            nextAction: nextAction,
            claimBoundary: preregistration.claimBoundary
        )
#else
        throw MetalDirectionCompositionValidationError.executionFailed(
            "direction-composition canonical requires Metal"
        )
#endif
    }
}

#if canImport(Metal)
private struct GPUDirectionCompositionParameters {
    var grid: SIMD4<UInt32>
    var originAndCellSize: SIMD4<Float>
    var normalAndOffset: SIMD4<Float>
    var tangentUAndHalfExtent: SIMD4<Float>
    var tangentVAndHalfExtent: SIMD4<Float>
    var integerNormalAndPhase: SIMD4<Float>
}

private struct DirectionCompositionFrame {
    let normal: SIMD3<Float>
    let tangentU: SIMD3<Float>
    let tangentV: SIMD3<Float>
}

extension MetalDirectionCompositionValidator {
    private static func validate(
        _ preregistration: MetalDirectionCompositionPreregistration,
        sha256: String
    ) throws {
        let hashes = [
            sha256,
            preregistration.sourceDiscriminatorSHA256,
            preregistration.sourceDiscriminatorAuditSHA256,
            preregistration.sourceD28ProvenanceSHA256,
            preregistration.sourceD32ProvenanceSHA256,
        ]
        guard preregistration.schemaVersion == 2,
              preregistration.passed,
              hashes.allSatisfy({
                  $0.count == 64 && $0.allSatisfy(\.isHexDigit)
              }),
              preregistration.referenceLengthCells == [48, 64],
              preregistration.patchSideLengthMeters == 1,
              preregistration.domainSideLengthMeters > 1.8,
              preregistration.subcellPhaseOffsets
                == [0.1, 0.3, 0.5, 0.7, 0.9],
              preregistration.orientations.count == 4,
              preregistration.orientations.allSatisfy({
                  $0.integerNormal.count == 3
                      && $0.integerNormal[1] == 0
                      && $0.integerNormal[0] > 0
              }),
              preregistration.fixedPopulationProfiles.count == 2,
              preregistration.fixedPopulationProfiles.allSatisfy({
                  $0.directionPopulations.count == D3Q19.count
                      && $0.directionPopulations.dropFirst().allSatisfy {
                          $0.isFinite && $0 >= 0
                      }
              }),
              !preregistration.fluidEvolutionAuthorized,
              !preregistration.productionModificationAuthorized,
              !preregistration.d36RunAuthorized,
              !preregistration.gridConvergenceGateApplied,
              !preregistration.experimentalAgreementGateApplied else {
            throw MetalDirectionCompositionValidationError
                .invalidPreregistration(
                    "direction-composition preregistration is malformed or unsafe"
                )
        }
    }

    private static func orientationFrame(
        _ orientation: MetalDirectionCompositionOrientation
    ) throws -> DirectionCompositionFrame {
        let raw = SIMD3<Float>(
            Float(orientation.integerNormal[0]),
            Float(orientation.integerNormal[1]),
            Float(orientation.integerNormal[2])
        )
        let length = magnitude(raw)
        guard length > 0 else {
            throw MetalDirectionCompositionValidationError
                .invalidPreregistration("plane normal must be nonzero")
        }
        let normal = raw / length
        let reference = SIMD3<Float>(0, 1, 0)
        let tangentU = cross(reference, normal) / magnitude(
            cross(reference, normal)
        )
        let tangentV = cross(normal, tangentU)
        return DirectionCompositionFrame(
            normal: normal,
            tangentU: tangentU,
            tangentV: tangentV
        )
    }

    private static func metalCounts(
        backend: MetalBackend,
        pipeline: MTLComputePipelineState,
        parameters: GPUDirectionCompositionParameters
    ) throws -> [Int] {
        let countBuffer = try backend.makeSharedBuffer(
            length: D3Q19.count * MemoryLayout<UInt32>.stride
        )
        var localParameters = parameters
        guard let commandBuffer = backend.queue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw MetalDirectionCompositionValidationError.executionFailed(
                "unable to create direction-composition command encoder"
            )
        }
        encoder.setBuffer(countBuffer, offset: 0, index: 0)
        encoder.setBytes(
            &localParameters,
            length: MemoryLayout<GPUDirectionCompositionParameters>.stride,
            index: 1
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: pipeline,
            count: Int(parameters.grid.w)
        )
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            throw MetalDirectionCompositionValidationError.executionFailed(
                commandBuffer.error?.localizedDescription
                    ?? "direction-composition kernel failed"
            )
        }
        let pointer = countBuffer.contents().bindMemory(
            to: UInt32.self,
            capacity: D3Q19.count
        )
        return (0..<D3Q19.count).map { Int(pointer[$0]) }
    }

    private static func cpuCounts(
        parameters: GPUDirectionCompositionParameters
    ) -> [Int] {
        let grid = SIMD3<Int>(
            Int(parameters.grid.x),
            Int(parameters.grid.y),
            Int(parameters.grid.z)
        )
        let origin = SIMD3<Float>(
            parameters.originAndCellSize.x,
            parameters.originAndCellSize.y,
            parameters.originAndCellSize.z
        )
        let dx = parameters.originAndCellSize.w
        let rawNormal = SIMD3<Float>(
            parameters.integerNormalAndPhase.x,
            parameters.integerNormalAndPhase.y,
            parameters.integerNormalAndPhase.z
        )
        let rawNormalLength = magnitude(rawNormal)
        let phase = parameters.integerNormalAndPhase.w
        let tangentU = SIMD3<Float>(
            parameters.tangentUAndHalfExtent.x,
            parameters.tangentUAndHalfExtent.y,
            parameters.tangentUAndHalfExtent.z
        )
        let tangentV = SIMD3<Float>(
            parameters.tangentVAndHalfExtent.x,
            parameters.tangentVAndHalfExtent.y,
            parameters.tangentVAndHalfExtent.z
        )
        let halfExtent = parameters.tangentUAndHalfExtent.w
        let tolerance = 1e-5 as Float * dx
        var counts = [Int](repeating: 0, count: D3Q19.count)
        for z in 0..<grid.z {
            for y in 0..<grid.y {
                for x in 0..<grid.x {
                    let position = origin + dx * SIMD3<Float>(
                        Float(x) + 0.5, Float(y) + 0.5, Float(z) + 0.5
                    )
                    let centeredCell = SIMD3<Float>(
                        Float(x) + 0.5 - 0.5 * Float(grid.x),
                        Float(y) + 0.5 - 0.5 * Float(grid.y),
                        Float(z) + 0.5 - 0.5 * Float(grid.z)
                    )
                    let signedDistance = dx * (
                        dot(centeredCell, rawNormal)
                            - (phase - 0.5) * rawNormalLength
                    ) / rawNormalLength
                    guard signedDistance >= 0,
                          signedDistance <= 1.415 * dx else { continue }
                    for direction in 1..<D3Q19.count {
                        let raw = D3Q19.directions[direction]
                        let source = SIMD3<Int>(
                            x - Int(raw.x),
                            y - Int(raw.y),
                            z - Int(raw.z)
                        )
                        guard source.x >= 0, source.x < grid.x,
                              source.y >= 0, source.y < grid.y,
                              source.z >= 0, source.z < grid.z else { continue }
                        let c = SIMD3<Float>(
                            Float(raw.x), Float(raw.y), Float(raw.z)
                        )
                        let sourceDistance = dx * (
                            dot(centeredCell - c, rawNormal)
                                - (phase - 0.5) * rawNormalLength
                        ) / rawNormalLength
                        guard sourceDistance < 0 else { continue }
                        let fraction = signedDistance
                            / (signedDistance - sourceDistance)
                        let intersection = position - fraction * dx * c
                        guard abs(dot(intersection, tangentU))
                                <= halfExtent + tolerance,
                              abs(dot(intersection, tangentV))
                                <= halfExtent + tolerance else { continue }
                        counts[direction] += 1
                    }
                }
            }
        }
        return counts
    }

    private static func makeCase(
        preregistration: MetalDirectionCompositionPreregistration,
        resolution: Int,
        gridSide: Int,
        dx: Float,
        orientation: MetalDirectionCompositionOrientation,
        frame: DirectionCompositionFrame,
        phase: Double,
        offset: Float,
        metalCounts: [Int],
        cpuCounts: [Int]
    ) -> MetalDirectionCompositionCaseReport {
        let totalMetal = metalCounts.reduce(0, +)
        let totalCPU = cpuCounts.reduce(0, +)
        let differences = zip(metalCounts, cpuCounts).map {
            abs($0.0 - $0.1)
        }
        let totalDifference = differences.reduce(0, +)
        let histogram = metalCounts.map {
            Double($0) / Double(max(totalMetal, 1))
        }
        let normal = SIMD3<Double>(frame.normal)
        let area = preregistration.patchSideLengthMeters
            * preregistration.patchSideLengthMeters
        let responses = preregistration.fixedPopulationProfiles.map { profile in
            let analytic = analyticResponse(
                normal: normal,
                area: area,
                populations: profile.directionPopulations
            )
            let metal = latticeResponse(
                counts: metalCounts,
                dx: Double(dx),
                populations: profile.directionPopulations
            )
            let cpu = latticeResponse(
                counts: cpuCounts,
                dx: Double(dx),
                populations: profile.directionPopulations
            )
            let scale = max(magnitude(analytic), 1e-30)
            return MetalDirectionCompositionProfileResponse(
                profileIdentifier: profile.identifier,
                analyticResponse: analytic,
                metalResponse: metal,
                cpuResponse: cpu,
                metalVectorRelativeError: magnitude(metal - analytic) / scale,
                cpuVectorRelativeError: magnitude(cpu - analytic) / scale
            )
        }
        return MetalDirectionCompositionCaseReport(
            referenceLengthCells: resolution,
            gridSideCells: gridSide,
            cellSizeMeters: Double(dx),
            orientationIdentifier: orientation.identifier,
            normal: normal,
            tangentU: SIMD3<Double>(frame.tangentU),
            tangentV: SIMD3<Double>(frame.tangentV),
            subcellPhaseOffset: phase,
            planeOffsetMeters: Double(offset),
            metalDirectionLinkCounts: metalCounts,
            cpuDirectionLinkCounts: cpuCounts,
            totalMetalLinkCount: totalMetal,
            totalCPULinkCount: totalCPU,
            maximumPerDirectionCountMismatch: differences.max() ?? .max,
            countRelativeDifference: Double(totalDifference)
                / Double(max(totalCPU, 1)),
            directionHistogram: histogram,
            profileResponses: responses
        )
    }

    private static func makeSummaries(
        preregistration: MetalDirectionCompositionPreregistration,
        cases: [MetalDirectionCompositionCaseReport]
    ) throws -> [MetalDirectionCompositionOrientationSummary] {
        let coarse = preregistration.referenceLengthCells[0]
        let fine = preregistration.referenceLengthCells[1]
        return try preregistration.orientations.map { orientation in
            let orientationCases = cases.filter {
                $0.orientationIdentifier == orientation.identifier
            }
            guard let normal = orientationCases.first?.normal else {
                throw MetalDirectionCompositionValidationError.executionFailed(
                    "missing orientation cases"
                )
            }
            func selected(_ resolution: Int) -> [
                MetalDirectionCompositionCaseReport
            ] {
                orientationCases.filter {
                    $0.referenceLengthCells == resolution
                }
            }
            let coarseCases = selected(coarse)
            let fineCases = selected(fine)
            let coarseHistogram = meanVectors(
                coarseCases.map(\.directionHistogram)
            )
            let fineHistogram = meanVectors(
                fineCases.map(\.directionHistogram)
            )
            let histogramTV = 0.5 * zip(coarseHistogram, fineHistogram)
                .reduce(0.0) { $0 + abs($1.0 - $1.1) }
            let profiles = try preregistration.fixedPopulationProfiles.map {
                profile in
                let coarseResponses = try coarseCases.map {
                    try response($0, profile: profile.identifier)
                }
                let fineResponses = try fineCases.map {
                    try response($0, profile: profile.identifier)
                }
                let analytic = try response(
                    fineCases[0], profile: profile.identifier
                ).analyticResponse
                let coarseMean = mean(coarseResponses.map(\.metalResponse))
                let fineMean = mean(fineResponses.map(\.metalResponse))
                let scale = max(magnitude(analytic), 1e-30)
                return MetalDirectionCompositionProfileSummary(
                    profileIdentifier: profile.identifier,
                    coarsePhaseMeanResponse: coarseMean,
                    finePhaseMeanResponse: fineMean,
                    analyticResponse: analytic,
                    maximumFineVectorRelativeError: fineResponses.map(
                        \.metalVectorRelativeError
                    ).max() ?? .infinity,
                    coarseFinePhaseMeanRelativeDifference:
                        magnitude(fineMean - coarseMean) / scale,
                    maximumFinePhaseRelativeSpread: fineResponses.map {
                        magnitude($0.metalResponse - fineMean) / scale
                    }.max() ?? .infinity
                )
            }
            let equilibrium = try profiles.first {
                $0.profileIdentifier == "rest-equilibrium"
            }.required("missing equilibrium profile summary")
            let normalized = equilibrium.finePhaseMeanResponse
                / (D3Q19.soundSpeedSquared.doubleValue
                    * preregistration.patchSideLengthMeters
                    * preregistration.patchSideLengthMeters)
            let normalResponse = dot(normalized, normal)
            let tangent = normalized - normalResponse * normal
            return MetalDirectionCompositionOrientationSummary(
                orientationIdentifier: orientation.identifier,
                normal: normal,
                coarseFineDirectionHistogramTotalVariation: histogramTV,
                equilibriumFineNormalResponseError: abs(normalResponse - 1),
                equilibriumFineTangentialLeakage: magnitude(tangent),
                profiles: profiles
            )
        }
    }

    private static func response(
        _ report: MetalDirectionCompositionCaseReport,
        profile: String
    ) throws -> MetalDirectionCompositionProfileResponse {
        guard let response = report.profileResponses.first(where: {
            $0.profileIdentifier == profile
        }) else {
            throw MetalDirectionCompositionValidationError.executionFailed(
                "missing profile response"
            )
        }
        return response
    }

    private static func analyticResponse(
        normal: SIMD3<Double>,
        area: Double,
        populations: [Double]
    ) -> SIMD3<Double> {
        var result = SIMD3<Double>.zero
        for direction in 1..<D3Q19.count {
            let c = SIMD3<Double>(D3Q19.directions[direction])
            let projection = dot(c, normal)
            if projection > 0 {
                result += 2 * area * populations[direction] * projection * c
            }
        }
        return result
    }

    private static func latticeResponse(
        counts: [Int],
        dx: Double,
        populations: [Double]
    ) -> SIMD3<Double> {
        var result = SIMD3<Double>.zero
        for direction in 1..<D3Q19.count {
            let c = SIMD3<Double>(D3Q19.directions[direction])
            result += 2 * dx * dx * Double(counts[direction])
                * populations[direction] * c
        }
        return result
    }

    private static func mean(_ values: [SIMD3<Double>]) -> SIMD3<Double> {
        values.reduce(.zero, +) / Double(max(values.count, 1))
    }

    private static func meanVectors(_ values: [[Double]]) -> [Double] {
        guard let count = values.first?.count else { return [] }
        var result = [Double](repeating: 0, count: count)
        for value in values {
            for index in result.indices {
                result[index] += value[index]
            }
        }
        return result.map { $0 / Double(max(values.count, 1)) }
    }

    private static func dot<T: BinaryFloatingPoint>(
        _ first: SIMD3<T>, _ second: SIMD3<T>
    ) -> T {
        first.x * second.x + first.y * second.y + first.z * second.z
    }

    private static func cross(
        _ first: SIMD3<Float>, _ second: SIMD3<Float>
    ) -> SIMD3<Float> {
        SIMD3<Float>(
            first.y * second.z - first.z * second.y,
            first.z * second.x - first.x * second.z,
            first.x * second.y - first.y * second.x
        )
    }

    private static func magnitude<T: BinaryFloatingPoint>(
        _ value: SIMD3<T>
    ) -> T {
        (value.x * value.x + value.y * value.y + value.z * value.z)
            .squareRoot()
    }
}

private extension Optional {
    func required(_ message: String) throws -> Wrapped {
        guard let self else {
            throw MetalDirectionCompositionValidationError.executionFailed(
                message
            )
        }
        return self
    }
}

private extension Float {
    var doubleValue: Double { Double(self) }
}
#endif

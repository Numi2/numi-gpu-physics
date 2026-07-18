import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal
#endif

public struct FormationGeometrySubcellCase: Codable, Sendable {
    public let chordCells: Int
    public let offsetCells: SIMD3<Double>
    public let actualLeaderPhase: Double
    public let actualFollowerPhase: Double
    public let occupiedLeaderCells: Int
    public let occupiedFollowerCells: Int
    public let totalLeaderBoundaryLinkCount: Int
    public let totalFollowerBoundaryLinkCount: Int
    public let overlapVoxelCount: Int
    public let runtimeSeconds: Double
    public let directions: [FormationGeometryDirectionCount]
}

public struct FormationGeometrySubcellEnsembleGates: Codable, Sendable {
    public let noFluidTimesteps: Bool
    public let completeTensorGrid: Bool
    public let positiveLinkSupport: Bool
    public let zeroOverlap: Bool
    public let allFinite: Bool
}

public struct FormationGeometrySubcellEnsembleReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let deviceName: String
    public let chordCells: [Int]
    public let offsetDivisionsPerAxis: Int
    public let followerOffsetChords: SIMD3<Double>
    public let followerPhaseOffsetCycles: Double
    public let requestedLeaderPhase: Double
    public let cases: [FormationGeometrySubcellCase]
    public let gates: FormationGeometrySubcellEnsembleGates
    public let passed: Bool
    public let claimBoundary: String
}

public enum FormationGeometrySubcellClassification: String, Codable, Sendable {
    case aliasingAveragedOut
    case persistentResolutionBias
    case mixedSubcellSensitivity
}

public enum FormationGeometrySubcellDecision {
    public static func classify(
        meanDensityBetweenEndpoints: Bool,
        meanDensityCurvature: Double,
        meanDirectionCurvature: Double,
        meanArealProfileCurvature: Double
    ) -> FormationGeometrySubcellClassification {
        if meanDensityBetweenEndpoints,
           meanDensityCurvature <= 0.5,
           meanDirectionCurvature <= 0.5,
           meanArealProfileCurvature <= 0.5 {
            return .aliasingAveragedOut
        }
        if !meanDensityBetweenEndpoints
            || meanDensityCurvature >= 1
            || meanDirectionCurvature >= 1
            || meanArealProfileCurvature >= 1 {
            return .persistentResolutionBias
        }
        return .mixedSubcellSensitivity
    }
}

public enum MetalFormationGeometrySubcellEnsembleValidator {
    public static let schemaVersion = 1

    public static func run(
        chordCells: [Int] = [16, 18, 20],
        offsetDivisionsPerAxis: Int = 4,
        leaderPhase: Double = 0.785,
        followerOffsetChords: SIMD3<Double> = SIMD3<Double>(0, 0, -3),
        followerPhaseOffsetCycles: Double = 0.25
    ) throws -> FormationGeometrySubcellEnsembleReport {
        guard chordCells.sorted() == [16, 18, 20],
              (2...8).contains(offsetDivisionsPerAxis),
              leaderPhase.isFinite,
              followerPhaseOffsetCycles.isFinite,
              followerOffsetChords.x.isFinite,
              followerOffsetChords.y.isFinite,
              followerOffsetChords.z.isFinite else {
            throw FormationGeometryCensusError.invalidRequest(
                "the subcell ensemble requires c16/c18/c20, 2...8 divisions, and finite phase/offset values"
            )
        }
        #if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let offsets = (0..<offsetDivisionsPerAxis).flatMap { z in
            (0..<offsetDivisionsPerAxis).flatMap { y in
                (0..<offsetDivisionsPerAxis).map { x in
                    SIMD3<Double>(
                        Double(x) / Double(offsetDivisionsPerAxis),
                        Double(y) / Double(offsetDivisionsPerAxis),
                        Double(z) / Double(offsetDivisionsPerAxis)
                    )
                }
            }
        }
        var cases: [FormationGeometrySubcellCase] = []
        cases.reserveCapacity(chordCells.count * offsets.count)
        for resolution in chordCells.sorted() {
            let workspace = try FormationGeometrySubcellWorkspace(
                backend: backend,
                chordCells: resolution,
                leaderPhase: leaderPhase,
                followerOffsetChords: followerOffsetChords,
                followerPhaseOffsetCycles: followerPhaseOffsetCycles
            )
            for offset in offsets {
                cases.append(try workspace.capture(offsetCells: offset))
            }
        }
        let expectedCount = chordCells.count * offsets.count
        let complete = cases.count == expectedCount
            && Set(cases.map {
                "\($0.chordCells)/\($0.offsetCells.x)/\($0.offsetCells.y)/\($0.offsetCells.z)"
            }).count == expectedCount
        let positive = cases.allSatisfy {
            $0.totalLeaderBoundaryLinkCount > 0
                && $0.totalFollowerBoundaryLinkCount > 0
        }
        let noOverlap = cases.allSatisfy { $0.overlapVoxelCount == 0 }
        let finite = cases.allSatisfy {
            $0.actualLeaderPhase.isFinite
                && $0.actualFollowerPhase.isFinite
                && $0.runtimeSeconds.isFinite
        }
        let gates = FormationGeometrySubcellEnsembleGates(
            noFluidTimesteps: true,
            completeTensorGrid: complete,
            positiveLinkSupport: positive,
            zeroOverlap: noOverlap,
            allFinite: finite
        )
        return FormationGeometrySubcellEnsembleReport(
            schemaVersion: schemaVersion,
            scientificScope: "A complete tensor grid of global subcell translations applied to both prescribed flyers before production Metal voxelization; owner-mask readback and D3Q19 link counting only, with zero fluid timesteps.",
            deviceName: backend.device.name,
            chordCells: chordCells.sorted(),
            offsetDivisionsPerAxis: offsetDivisionsPerAxis,
            followerOffsetChords: followerOffsetChords,
            followerPhaseOffsetCycles: unitPhase(followerPhaseOffsetCycles),
            requestedLeaderPhase: leaderPhase,
            cases: cases,
            gates: gates,
            passed: complete && positive && noOverlap && finite,
            claimBoundary: "This ensemble quantifies sensitivity of boundary-link realization to global lattice phase. It cannot validate force convergence, authorize a boundary correction, establish a quantitative formation benefit, or support a biological claim."
        )
        #else
        throw FormationGeometryCensusError.unavailable(
            "Metal is required for the subcell geometry ensemble"
        )
        #endif
    }

    fileprivate static func unitPhase(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}

#if canImport(Metal)
private final class FormationGeometrySubcellWorkspace {
    private let backend: MetalBackend
    private let chordCells: Int
    private let leaderPhase: Double
    private let followerPhaseOffsetCycles: Double
    private let grid: GridSize
    private let cycleSteps: Int
    private let configuration: SimulationConfiguration
    private let baseLeaderRoot: SIMD3<Float>
    private let baseFollowerRoot: SIMD3<Float>
    private let leaderParameters: MTLBuffer
    private let followerParameters: MTLBuffer
    private let leaderPrepared: MTLBuffer
    private let followerPrepared: MTLBuffer
    private let targetMask: MTLBuffer
    private let previousMask: MTLBuffer
    private let readbackMask: MTLBuffer
    private let wallVelocity: MTLBuffer
    private let boundaryLinks: MTLBuffer
    private let coveredMomentum: MTLBuffer
    private let overlapCounts: MTLBuffer
    private let control: MTLBuffer
    private let preparePipeline: MTLComputePipelineState
    private let geometryPipeline: MTLComputePipelineState
    private let actualLeaderPhase: Double
    private let actualFollowerPhase: Double
    private let stepWithinCycle: Int

    init(
        backend: MetalBackend,
        chordCells: Int,
        leaderPhase: Double,
        followerOffsetChords: SIMD3<Double>,
        followerPhaseOffsetCycles: Double
    ) throws {
        self.backend = backend
        self.chordCells = chordCells
        self.leaderPhase = leaderPhase
        self.followerPhaseOffsetCycles = followerPhaseOffsetCycles
        func dimension(_ offset: Double) throws -> Int {
            let value = ceil(10 + abs(offset)) * Double(chordCells)
            guard value.isFinite,
                  value >= 16,
                  value <= Double(Int.max) else {
                throw FormationGeometryCensusError.invalidRequest(
                    "subcell offset and resolution produce an invalid grid"
                )
            }
            return Int(value)
        }
        grid = try GridSize(
            x: dimension(followerOffsetChords.x),
            y: dimension(followerOffsetChords.y),
            z: dimension(followerOffsetChords.z)
        )
        let cycleValue = (
            MetalFlappingWingValidator.cycleTravelPerChord
                * Double(chordCells)
                / MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
        ).rounded()
        cycleSteps = Int(cycleValue)
        let requested = MetalFormationGeometrySubcellEnsembleValidator
            .unitPhase(leaderPhase)
        if requested == 0 {
            stepWithinCycle = cycleSteps
        } else {
            stepWithinCycle = min(
                cycleSteps,
                max(1, Int((requested * Double(cycleSteps)).rounded()))
            )
        }
        actualLeaderPhase = stepWithinCycle == cycleSteps
            ? 0
            : Double(stepWithinCycle) / Double(cycleSteps)
        actualFollowerPhase = MetalFormationGeometrySubcellEnsembleValidator
            .unitPhase(actualLeaderPhase + followerPhaseOffsetCycles)
        let midpoint = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.5 * Float(grid.z)
        )
        let bodyOffset = SIMD3<Float>(followerOffsetChords)
            * Float(chordCells)
        baseLeaderRoot = midpoint - 0.5 * bodyOffset
        baseFollowerRoot = midpoint + 0.5 * bodyOffset
        let scaling = try LatticeScaling(
            characteristicLengthMeters: Float(chordCells),
            characteristicLengthCells: chordCells,
            referenceSpeedMetersPerSecond: Float(
                MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
            ),
            targetReynoldsNumber: Float(
                MetalFlappingWingValidator.reynoldsNumber
            ),
            physicalAirDensity: 1,
            latticeReferenceSpeed: Float(
                MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
            )
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: max(4, chordCells / 2),
            spongeStrength: 0.04,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        leaderParameters = try backend.makeSharedBuffer(
            value: Self.parameters(root: baseLeaderRoot, chordCells: chordCells, cycleSteps: cycleSteps)
        )
        followerParameters = try backend.makeSharedBuffer(
            value: Self.parameters(root: baseFollowerRoot, chordCells: chordCells, cycleSteps: cycleSteps)
        )
        leaderPrepared = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedFlappingWing>.stride
        )
        followerPrepared = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedFlappingWing>.stride
        )
        let cells = grid.cellCount
        let maskBytes = cells * MemoryLayout<UInt8>.stride
        targetMask = try backend.makePrivateBuffer(length: maskBytes)
        previousMask = try backend.makeSharedBuffer(length: maskBytes)
        readbackMask = try backend.makeSharedBuffer(length: maskBytes)
        wallVelocity = try backend.makePrivateBuffer(
            length: cells * MemoryLayout<SIMD4<Float>>.stride
        )
        boundaryLinks = try backend.makePrivateBuffer(
            length: D3Q19.count * cells * MemoryLayout<Float>.stride
        )
        coveredMomentum = try backend.makePrivateBuffer(
            length: cells * MemoryLayout<SIMD4<Float>>.stride
        )
        overlapCounts = try backend.makeSharedBuffer(
            length: cycleSteps * MemoryLayout<UInt32>.stride
        )
        control = try backend.makeSharedBuffer(
            value: GPUFormationFlightControl(
                activeOwnersAndCycleSteps: SIMD4<UInt32>(
                    3,
                    UInt32(cycleSteps),
                    0,
                    0
                )
            )
        )
        try backend.validateAllocationPlan(bufferLengths: [
            leaderParameters.length,
            followerParameters.length,
            leaderPrepared.length,
            followerPrepared.length,
            targetMask.length,
            previousMask.length,
            readbackMask.length,
            wallVelocity.length,
            boundaryLinks.length,
            coveredMomentum.length,
            overlapCounts.length,
            control.length,
        ])
        preparePipeline = try backend.pipeline(
            named: "preparePrescribedFlappingWing"
        )
        geometryPipeline = try backend.pipeline(
            named: "buildPrescribedFormationWings"
        )
    }

    func capture(offsetCells: SIMD3<Double>) throws
        -> FormationGeometrySubcellCase {
        let start = Date()
        let shift = SIMD3<Float>(offsetCells)
            * configuration.scaling.cellSizeMeters
        leaderParameters.contents()
            .assumingMemoryBound(to: GPUFlappingWingParameters.self).pointee =
            Self.parameters(
                root: baseLeaderRoot + shift,
                chordCells: chordCells,
                cycleSteps: cycleSteps
            )
        followerParameters.contents()
            .assumingMemoryBound(to: GPUFlappingWingParameters.self).pointee =
            Self.parameters(
                root: baseFollowerRoot + shift,
                chordCells: chordCells,
                cycleSteps: cycleSteps
            )
        memset(overlapCounts.contents(), 0, overlapCounts.length)
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw FormationGeometryCensusError.failed(
                "unable to create a subcell geometry command buffer"
            )
        }
        var leaderUniforms = uniforms(time: Float(stepWithinCycle))
        var followerUniforms = uniforms(
            time: Float(stepWithinCycle)
                + Float(
                    MetalFormationGeometrySubcellEnsembleValidator.unitPhase(
                        followerPhaseOffsetCycles
                    )
                ) * Float(cycleSteps)
        )
        try encodePreparation(
            commandBuffer: commandBuffer,
            prepared: leaderPrepared,
            parameters: leaderParameters,
            uniforms: &leaderUniforms
        )
        try encodePreparation(
            commandBuffer: commandBuffer,
            prepared: followerPrepared,
            parameters: followerParameters,
            uniforms: &followerUniforms
        )
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw FormationGeometryCensusError.failed(
                "unable to create a subcell geometry encoder"
            )
        }
        encoder.setBuffer(targetMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocity, offset: 0, index: 1)
        encoder.setBuffer(previousMask, offset: 0, index: 2)
        encoder.setBuffer(leaderParameters, offset: 0, index: 3)
        encoder.setBuffer(leaderPrepared, offset: 0, index: 4)
        encoder.setBuffer(followerParameters, offset: 0, index: 5)
        encoder.setBuffer(followerPrepared, offset: 0, index: 6)
        encoder.setBytes(
            &leaderUniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        encoder.setBuffer(boundaryLinks, offset: 0, index: 8)
        encoder.setBuffer(coveredMomentum, offset: 0, index: 9)
        encoder.setBuffer(overlapCounts, offset: 0, index: 10)
        encoder.setBuffer(control, offset: 0, index: 11)
        backend.dispatch3D(
            encoder: encoder,
            pipeline: geometryPipeline,
            width: grid.x,
            height: grid.y,
            depth: grid.z
        )
        encoder.endEncoding()
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw FormationGeometryCensusError.failed(
                "unable to create a subcell geometry readback encoder"
            )
        }
        blit.copy(
            from: targetMask,
            sourceOffset: 0,
            to: readbackMask,
            destinationOffset: 0,
            size: readbackMask.length
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw FormationGeometryCensusError.failed(
                commandBuffer.error?.localizedDescription
                    ?? "unknown subcell Metal command failure"
            )
        }
        let mask = readbackMask.contents().assumingMemoryBound(to: UInt8.self)
        var counts = Array(
            repeating: SIMD2<Int>(repeating: 0),
            count: D3Q19.count
        )
        var occupied = SIMD2<Int>(repeating: 0)
        for gid in 0..<grid.cellCount {
            let owner = Int(mask[gid])
            guard owner == 1 || owner == 2 else { continue }
            occupied[owner - 1] += 1
            let x = gid % grid.x
            let yz = gid / grid.x
            let y = yz % grid.y
            let z = yz / grid.y
            for q in 1..<D3Q19.count {
                let direction = D3Q19.directions[q]
                let nx = x + Int(direction.x)
                let ny = y + Int(direction.y)
                let nz = z + Int(direction.z)
                guard nx >= 0, nx < grid.x,
                      ny >= 0, ny < grid.y,
                      nz >= 0, nz < grid.z else { continue }
                let neighbor = nx + grid.x * (ny + grid.y * nz)
                if mask[neighbor] == 0 {
                    counts[q][owner - 1] += 1
                }
            }
        }
        let overlap = overlapCounts.contents()
            .assumingMemoryBound(to: UInt32.self)
        let overlapTotal = (0..<cycleSteps).reduce(0) {
            $0 + Int(overlap[$1])
        }
        return FormationGeometrySubcellCase(
            chordCells: chordCells,
            offsetCells: offsetCells,
            actualLeaderPhase: actualLeaderPhase,
            actualFollowerPhase: actualFollowerPhase,
            occupiedLeaderCells: occupied.x,
            occupiedFollowerCells: occupied.y,
            totalLeaderBoundaryLinkCount: counts.reduce(0) { $0 + $1.x },
            totalFollowerBoundaryLinkCount: counts.reduce(0) { $0 + $1.y },
            overlapVoxelCount: overlapTotal,
            runtimeSeconds: Date().timeIntervalSince(start),
            directions: D3Q19.directions.enumerated().map { q, direction in
                FormationGeometryDirectionCount(
                    directionIndex: q,
                    direction: direction,
                    leaderLinkCount: counts[q].x,
                    followerLinkCount: counts[q].y
                )
            }
        )
    }

    private static func parameters(
        root: SIMD3<Float>,
        chordCells: Int,
        cycleSteps: Int
    ) -> GPUFlappingWingParameters {
        GPUFlappingWingParameters(
            rootAndChord: SIMD4<Float>(root, Float(chordCells)),
            geometry: SIMD4<Float>(
                Float(MetalFlappingWingValidator.aspectRatio)
                    * Float(chordCells),
                0.05 * Float(chordCells),
                Float(MetalFlappingWingValidator.betaShape - 1),
                Float(MetalFlappingWingValidator.betaNormalization)
            ),
            kinematics0: SIMD4<Float>(
                Float(cycleSteps),
                Float(MetalFlappingWingValidator.strokeHalfAmplitudeRadians),
                Float(MetalFlappingWingValidator.accelerationDuration),
                Float(MetalFlappingWingValidator.pitchDuration)
            ),
            kinematics1: SIMD4<Float>(
                45 * .pi / 180,
                135 * .pi / 180,
                Float(
                    MetalFlappingWingValidator.maximumStrokeRateRadiansPerCycle
                ),
                Float(
                    MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
                )
            )
        )
    }

    private func uniforms(time: Float) -> GPUUniforms {
        GPUUniforms(
            configuration: configuration,
            time: time,
            captureMacroscopicFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false,
            periodicBoundaries: false,
            caseParameters: SIMD4<Float>(0, 6, 0, -1)
        )
    }

    private func encodePreparation(
        commandBuffer: MTLCommandBuffer,
        prepared: MTLBuffer,
        parameters: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw FormationGeometryCensusError.failed(
                "unable to create a subcell preparation encoder"
            )
        }
        encoder.setBuffer(prepared, offset: 0, index: 0)
        encoder.setBuffer(parameters, offset: 0, index: 1)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 2
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: preparePipeline,
            count: 1
        )
        encoder.endEncoding()
    }
}
#endif

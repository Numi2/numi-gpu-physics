import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal
#endif

public struct FormationGeometryDirectionCount: Codable, Sendable, Equatable {
    public let directionIndex: Int
    public let direction: SIMD3<Int32>
    public let leaderLinkCount: Int
    public let followerLinkCount: Int
}

public struct FormationGeometryCensusSample: Codable, Sendable {
    public let chordCells: Int
    public let requestedLeaderPhase: Double
    public let actualLeaderPhase: Double
    public let actualFollowerPhase: Double
    public let cycleSteps: Int
    public let grid: GridSize
    public let occupiedLeaderCells: Int
    public let occupiedFollowerCells: Int
    public let totalLeaderBoundaryLinkCount: Int
    public let totalFollowerBoundaryLinkCount: Int
    public let overlapVoxelCount: Int
    public let runtimeSeconds: Double
    public let directions: [FormationGeometryDirectionCount]
}

public struct FormationGeometryCensusGates: Codable, Sendable {
    public let noFluidTimesteps: Bool
    public let positiveLinkSupport: Bool
    public let zeroOverlap: Bool
    public let allFinite: Bool
}

public struct FormationGeometryCensusReport: Codable, Sendable {
    public let schemaVersion: Int
    public let scientificScope: String
    public let deviceName: String
    public let followerOffsetChords: SIMD3<Double>
    public let followerPhaseOffsetCycles: Double
    public let samples: [FormationGeometryCensusSample]
    public let gates: FormationGeometryCensusGates
    public let passed: Bool
    public let claimBoundary: String
}

public enum FormationGeometryBridgeClassification: String, Codable, Sendable {
    case monotonicGeometryBridge
    case latticePhaseAliasingSuspected
    case mixedGeometryBridge
}

public enum FormationGeometryBridgeDecision {
    /// Frozen geometry-only discriminator. Values are normalized midpoint
    /// curvatures for density, direction distribution, and areal profile.
    public static func classify(
        densityBetweenEndpoints: Bool,
        densityCurvature: Double,
        directionCurvature: Double,
        arealProfileCurvature: Double
    ) -> FormationGeometryBridgeClassification {
        if densityBetweenEndpoints,
           densityCurvature <= 0.5,
           directionCurvature <= 0.5,
           arealProfileCurvature <= 0.5 {
            return .monotonicGeometryBridge
        }
        if !densityBetweenEndpoints
            || densityCurvature >= 1
            || directionCurvature >= 1
            || arealProfileCurvature >= 1 {
            return .latticePhaseAliasingSuspected
        }
        return .mixedGeometryBridge
    }
}

public enum FormationGeometryCensusError: Error, CustomStringConvertible {
    case invalidRequest(String)
    case unavailable(String)
    case failed(String)

    public var description: String {
        switch self {
        case .invalidRequest(let message):
            return "Invalid formation geometry census request: \(message)"
        case .unavailable(let message):
            return "Formation geometry census unavailable: \(message)"
        case .failed(let message):
            return "Formation geometry census failed: \(message)"
        }
    }
}

public enum MetalFormationGeometryCensusValidator {
    public static let schemaVersion = 1
    public static let defaultChordCells = [16, 18, 20]
    public static let defaultLeaderPhase = 0.785
    public static let defaultFollowerOffsetChords = SIMD3<Double>(0, 0, -3)
    public static let defaultFollowerPhaseOffsetCycles = 0.25

    public static func run(
        chordCells: [Int] = defaultChordCells,
        leaderPhase: Double = defaultLeaderPhase,
        followerOffsetChords: SIMD3<Double> = defaultFollowerOffsetChords,
        followerPhaseOffsetCycles: Double = defaultFollowerPhaseOffsetCycles
    ) throws -> FormationGeometryCensusReport {
        guard !chordCells.isEmpty,
              chordCells.allSatisfy({ $0 >= 4 }),
              Set(chordCells).count == chordCells.count,
              leaderPhase.isFinite,
              followerPhaseOffsetCycles.isFinite,
              followerOffsetChords.x.isFinite,
              followerOffsetChords.y.isFinite,
              followerOffsetChords.z.isFinite else {
            throw FormationGeometryCensusError.invalidRequest(
                "resolutions must be unique and at least four; phases and offsets must be finite"
            )
        }
        #if canImport(Metal)
        let backend = try MetalBackend(fastMath: false)
        let samples = try chordCells.sorted().map {
            try runSample(
                backend: backend,
                chordCells: $0,
                leaderPhase: leaderPhase,
                followerOffsetChords: followerOffsetChords,
                followerPhaseOffsetCycles: followerPhaseOffsetCycles
            )
        }
        let positive = samples.allSatisfy {
            $0.totalLeaderBoundaryLinkCount > 0
                && $0.totalFollowerBoundaryLinkCount > 0
        }
        let noOverlap = samples.allSatisfy { $0.overlapVoxelCount == 0 }
        let finite = samples.allSatisfy {
            $0.requestedLeaderPhase.isFinite
                && $0.actualLeaderPhase.isFinite
                && $0.actualFollowerPhase.isFinite
                && $0.runtimeSeconds.isFinite
        }
        let gates = FormationGeometryCensusGates(
            noFluidTimesteps: true,
            positiveLinkSupport: positive,
            zeroOverlap: noOverlap,
            allFinite: finite
        )
        return FormationGeometryCensusReport(
            schemaVersion: schemaVersion,
            scientificScope: "Prescribed-pose Metal voxelization and owner-resolved D3Q19 boundary-link counting only; no population initialization, collision, streaming, force evaluation, or fluid timestep is executed.",
            deviceName: backend.device.name,
            followerOffsetChords: followerOffsetChords,
            followerPhaseOffsetCycles: unitPhase(followerPhaseOffsetCycles),
            samples: samples,
            gates: gates,
            passed: positive && noOverlap && finite,
            claimBoundary: "This geometry-only bridge can distinguish smooth refinement from lattice-phase sensitivity in boundary-link realization. It cannot establish a quantitative formation-flight benefit, validate a force law, authorize a production correction, or support a biological claim."
        )
        #else
        throw FormationGeometryCensusError.unavailable(
            "Metal is required for the prescribed-pose voxelization"
        )
        #endif
    }

    private static func unitPhase(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}

#if canImport(Metal)
private extension MetalFormationGeometryCensusValidator {
    struct Layout {
        let grid: GridSize
        let cycleSteps: Int
        let leaderRoot: SIMD3<Float>
        let followerRoot: SIMD3<Float>
        let scaling: LatticeScaling
    }

    static func makeLayout(
        chordCells chord: Int,
        followerOffsetChords: SIMD3<Double>
    ) throws -> Layout {
        func dimension(offset: Double) throws -> Int {
            let value = ceil(10 + abs(offset)) * Double(chord)
            guard value.isFinite,
                  value >= 16,
                  value <= Double(Int.max) else {
                throw FormationGeometryCensusError.invalidRequest(
                    "offset and resolution produce an unrepresentable grid"
                )
            }
            return Int(value)
        }
        let grid = try GridSize(
            x: dimension(offset: followerOffsetChords.x),
            y: dimension(offset: followerOffsetChords.y),
            z: dimension(offset: followerOffsetChords.z)
        )
        let cycleValue = (
            MetalFlappingWingValidator.cycleTravelPerChord * Double(chord)
                / MetalFlappingWingValidator.latticeRadiusOfGyrationSpeed
        ).rounded()
        guard cycleValue.isFinite,
              cycleValue >= 1,
              cycleValue <= Double(UInt32.max) else {
            throw FormationGeometryCensusError.invalidRequest(
                "resolution produces an unrepresentable cycle"
            )
        }
        let midpoint = SIMD3<Float>(
            0.5 * Float(grid.x),
            0.5 * Float(grid.y),
            0.5 * Float(grid.z)
        )
        let offset = SIMD3<Float>(followerOffsetChords) * Float(chord)
        return Layout(
            grid: grid,
            cycleSteps: Int(cycleValue),
            leaderRoot: midpoint - 0.5 * offset,
            followerRoot: midpoint + 0.5 * offset,
            scaling: try LatticeScaling(
                characteristicLengthMeters: Float(chord),
                characteristicLengthCells: chord,
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
        )
    }

    static func runSample(
        backend: MetalBackend,
        chordCells: Int,
        leaderPhase: Double,
        followerOffsetChords: SIMD3<Double>,
        followerPhaseOffsetCycles: Double
    ) throws -> FormationGeometryCensusSample {
        let start = Date()
        let layout = try makeLayout(
            chordCells: chordCells,
            followerOffsetChords: followerOffsetChords
        )
        let requestedPhase = unitPhase(leaderPhase)
        let stepWithinCycle: Int
        if requestedPhase == 0 {
            stepWithinCycle = layout.cycleSteps
        } else {
            stepWithinCycle = min(
                layout.cycleSteps,
                max(
                    1,
                    Int((requestedPhase * Double(layout.cycleSteps)).rounded())
                )
            )
        }
        let actualLeaderPhase = stepWithinCycle == layout.cycleSteps
            ? 0
            : Double(stepWithinCycle) / Double(layout.cycleSteps)
        let actualFollowerPhase = unitPhase(
            actualLeaderPhase + followerPhaseOffsetCycles
        )
        let configuration = try SimulationConfiguration(
            grid: layout.grid,
            domainOriginMeters: .zero,
            scaling: layout.scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: max(4, chordCells / 2),
            spongeStrength: 0.04,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )

        func parameters(root: SIMD3<Float>) -> GPUFlappingWingParameters {
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
                    Float(layout.cycleSteps),
                    Float(MetalFlappingWingValidator.strokeHalfAmplitudeRadians),
                    Float(MetalFlappingWingValidator.accelerationDuration),
                    Float(MetalFlappingWingValidator.pitchDuration)
                ),
                kinematics1: SIMD4<Float>(
                    45 * .pi / 180,
                    135 * .pi / 180,
                    Float(
                        MetalFlappingWingValidator
                            .maximumStrokeRateRadiansPerCycle
                    ),
                    Float(
                        MetalFlappingWingValidator
                            .latticeRadiusOfGyrationSpeed
                    )
                )
            )
        }

        let leaderParameters = try backend.makeSharedBuffer(
            value: parameters(root: layout.leaderRoot)
        )
        let followerParameters = try backend.makeSharedBuffer(
            value: parameters(root: layout.followerRoot)
        )
        let leaderPrepared = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedFlappingWing>.stride
        )
        let followerPrepared = try backend.makePrivateBuffer(
            length: MemoryLayout<GPUPreparedFlappingWing>.stride
        )
        let cells = layout.grid.cellCount
        let maskBytes = cells * MemoryLayout<UInt8>.stride
        let targetMask = try backend.makePrivateBuffer(length: maskBytes)
        let previousMask = try backend.makeSharedBuffer(length: maskBytes)
        let readbackMask = try backend.makeSharedBuffer(length: maskBytes)
        let wallVelocity = try backend.makePrivateBuffer(
            length: cells * MemoryLayout<SIMD4<Float>>.stride
        )
        let boundaryLinks = try backend.makePrivateBuffer(
            length: D3Q19.count * cells * MemoryLayout<Float>.stride
        )
        let coveredMomentum = try backend.makePrivateBuffer(
            length: cells * MemoryLayout<SIMD4<Float>>.stride
        )
        let overlapCounts = try backend.makeSharedBuffer(
            length: layout.cycleSteps * MemoryLayout<UInt32>.stride
        )
        let control = try backend.makeSharedBuffer(
            value: GPUFormationFlightControl(
                activeOwnersAndCycleSteps: SIMD4<UInt32>(
                    3,
                    UInt32(layout.cycleSteps),
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
        let preparePipeline = try backend.pipeline(
            named: "preparePrescribedFlappingWing"
        )
        let geometryPipeline = try backend.pipeline(
            named: "buildPrescribedFormationWings"
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw FormationGeometryCensusError.failed(
                "unable to create the prescribed-pose command buffer"
            )
        }
        var leaderUniforms = GPUUniforms(
            configuration: configuration,
            time: Float(stepWithinCycle),
            captureMacroscopicFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false,
            periodicBoundaries: false,
            caseParameters: SIMD4<Float>(0, 6, 0, -1)
        )
        var followerUniforms = GPUUniforms(
            configuration: configuration,
            time: Float(stepWithinCycle)
                + Float(unitPhase(followerPhaseOffsetCycles))
                    * Float(layout.cycleSteps),
            captureMacroscopicFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false,
            periodicBoundaries: false,
            caseParameters: SIMD4<Float>(0, 6, 0, -1)
        )

        try encodePreparation(
            backend: backend,
            commandBuffer: commandBuffer,
            pipeline: preparePipeline,
            prepared: leaderPrepared,
            parameters: leaderParameters,
            uniforms: &leaderUniforms
        )
        try encodePreparation(
            backend: backend,
            commandBuffer: commandBuffer,
            pipeline: preparePipeline,
            prepared: followerPrepared,
            parameters: followerParameters,
            uniforms: &followerUniforms
        )
        guard let geometry = commandBuffer.makeComputeCommandEncoder() else {
            throw FormationGeometryCensusError.failed(
                "unable to create the prescribed-pose geometry encoder"
            )
        }
        geometry.setBuffer(targetMask, offset: 0, index: 0)
        geometry.setBuffer(wallVelocity, offset: 0, index: 1)
        geometry.setBuffer(previousMask, offset: 0, index: 2)
        geometry.setBuffer(leaderParameters, offset: 0, index: 3)
        geometry.setBuffer(leaderPrepared, offset: 0, index: 4)
        geometry.setBuffer(followerParameters, offset: 0, index: 5)
        geometry.setBuffer(followerPrepared, offset: 0, index: 6)
        geometry.setBytes(
            &leaderUniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        geometry.setBuffer(boundaryLinks, offset: 0, index: 8)
        geometry.setBuffer(coveredMomentum, offset: 0, index: 9)
        geometry.setBuffer(overlapCounts, offset: 0, index: 10)
        geometry.setBuffer(control, offset: 0, index: 11)
        backend.dispatch3D(
            encoder: geometry,
            pipeline: geometryPipeline,
            width: layout.grid.x,
            height: layout.grid.y,
            depth: layout.grid.z
        )
        geometry.endEncoding()
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw FormationGeometryCensusError.failed(
                "unable to create the prescribed-pose readback encoder"
            )
        }
        blit.copy(
            from: targetMask,
            sourceOffset: 0,
            to: readbackMask,
            destinationOffset: 0,
            size: maskBytes
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        if commandBuffer.status == .error {
            throw FormationGeometryCensusError.failed(
                commandBuffer.error?.localizedDescription
                    ?? "unknown Metal command failure"
            )
        }

        let mask = readbackMask.contents().assumingMemoryBound(to: UInt8.self)
        var counts = Array(
            repeating: SIMD2<Int>(repeating: 0),
            count: D3Q19.count
        )
        var occupied = SIMD2<Int>(repeating: 0)
        for gid in 0..<cells {
            let owner = Int(mask[gid])
            guard owner == 1 || owner == 2 else { continue }
            occupied[owner - 1] += 1
            let x = gid % layout.grid.x
            let yz = gid / layout.grid.x
            let y = yz % layout.grid.y
            let z = yz / layout.grid.y
            for q in 1..<D3Q19.count {
                let direction = D3Q19.directions[q]
                let nx = x + Int(direction.x)
                let ny = y + Int(direction.y)
                let nz = z + Int(direction.z)
                guard nx >= 0, nx < layout.grid.x,
                      ny >= 0, ny < layout.grid.y,
                      nz >= 0, nz < layout.grid.z else { continue }
                let neighbor = nx + layout.grid.x * (
                    ny + layout.grid.y * nz
                )
                if mask[neighbor] == 0 {
                    counts[q][owner - 1] += 1
                }
            }
        }
        let directions = D3Q19.directions.enumerated().map { q, direction in
            FormationGeometryDirectionCount(
                directionIndex: q,
                direction: direction,
                leaderLinkCount: counts[q].x,
                followerLinkCount: counts[q].y
            )
        }
        let overlapPointer = overlapCounts.contents()
            .assumingMemoryBound(to: UInt32.self)
        let overlap = (0..<layout.cycleSteps).reduce(0) {
            $0 + Int(overlapPointer[$1])
        }
        return FormationGeometryCensusSample(
            chordCells: chordCells,
            requestedLeaderPhase: leaderPhase,
            actualLeaderPhase: actualLeaderPhase,
            actualFollowerPhase: actualFollowerPhase,
            cycleSteps: layout.cycleSteps,
            grid: layout.grid,
            occupiedLeaderCells: occupied.x,
            occupiedFollowerCells: occupied.y,
            totalLeaderBoundaryLinkCount: counts.reduce(0) { $0 + $1.x },
            totalFollowerBoundaryLinkCount: counts.reduce(0) { $0 + $1.y },
            overlapVoxelCount: overlap,
            runtimeSeconds: Date().timeIntervalSince(start),
            directions: directions
        )
    }

    static func encodePreparation(
        backend: MetalBackend,
        commandBuffer: MTLCommandBuffer,
        pipeline: MTLComputePipelineState,
        prepared: MTLBuffer,
        parameters: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw FormationGeometryCensusError.failed(
                "unable to create the prescribed-pose preparation encoder"
            )
        }
        encoder.setBuffer(prepared, offset: 0, index: 0)
        encoder.setBuffer(parameters, offset: 0, index: 1)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 2
        )
        backend.dispatch1D(encoder: encoder, pipeline: pipeline, count: 1)
        encoder.endEncoding()
    }
}
#endif

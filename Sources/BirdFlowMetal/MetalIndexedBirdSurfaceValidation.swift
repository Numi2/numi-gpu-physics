import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal
#endif

public struct MetalIndexedBirdSurfaceFrameAudit: Codable, Sendable {
    public let frameIndex: Int
    public let sourceFrameNumber: Int
    public let timeSeconds: Double
    public let solidCellCount: Int
    public let componentSolidCellCounts: [Int]
    public let occupancySHA256: String
    public let maximumLatticeWallSpeed: Double
    public let maximumPreparedPositionErrorMeters: Double
    public let maximumPreparedVelocityErrorMetersPerSecond: Double
    public let cpuRasterCompared: Bool
    public let cpuMaskMismatchCellCount: Int?
    public let maximumCPUWallVelocityDifferenceLattice: Double?
    public let maximumCPUSignedDistanceDifferenceCells: Double?
}

public struct MetalIndexedBirdSurfaceReplayReport: Codable, Sendable {
    public let schemaVersion: Int
    public let deviceName: String
    public let datasetIdentifier: String
    public let scientificTier: String
    public let manifestSHA256: String
    public let sourceSurfaceSHA256: String
    public let sourceMuscleModelSHA256: String
    public let frameCount: Int
    public let vertexCount: Int
    public let triangleCount: Int
    public let gridX: Int
    public let gridY: Int
    public let gridZ: Int
    public let cellSizeMeters: Double
    public let halfThicknessCells: Double
    public let runtimeSeconds: Double
    public let geometryKernelSequence: [String]
    public let cpuRasterMilestoneFrames: [Int]
    public let fractionalInterpolationProbeTimesSeconds: [Double]
    public let maximumPreparedPositionErrorMeters: Double
    public let maximumPreparedVelocityErrorMetersPerSecond: Double
    public let maximumCPUWallVelocityDifferenceLattice: Double
    public let maximumCPUSignedDistanceDifferenceCells: Double
    public let maximumCPUMaskMismatchCellCount: Int
    public let allComponentsPresentEveryFrame: Bool
    public let allValuesFinite: Bool
    public let fluidCollisionExecuted: Bool
    public let forceAccumulationExecuted: Bool
    public let frameAudits: [MetalIndexedBirdSurfaceFrameAudit]
    public let passed: Bool
    public let claimBoundary: String
}

public enum MetalIndexedBirdSurfaceValidator {
    public static func audit(
        _ dataset: MeasuredBirdSurfaceSequence,
        cellSizeMeters: Float = 0.01,
        halfThicknessCells: Float = 0.75,
        cpuRasterMilestoneFrames: [Int] = [0, 33, 89, 126, 143]
    ) throws -> MetalIndexedBirdSurfaceReplayReport {
        guard cellSizeMeters.isFinite,
              cellSizeMeters > 0,
              halfThicknessCells.isFinite,
              (0.5...2).contains(halfThicknessCells) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "geometry audit cell size and thickness are invalid"
            )
        }
        let milestones = Array(Set(cpuRasterMilestoneFrames)).sorted()
        guard milestones.allSatisfy({ $0 >= 0 && $0 < dataset.frameCount }) else {
            throw MeasuredBirdSurfaceSequenceError.invalidDataset(
                "CPU raster milestone is outside the surface sequence"
            )
        }
#if canImport(Metal)
        let startTime = Date()
        let backend = try MetalBackend(fastMath: false)
        let replay = try MetalIndexedBirdSurfaceReplay(
            backend: backend,
            dataset: dataset,
            cellSizeMeters: cellSizeMeters,
            halfThicknessCells: halfThicknessCells
        )
        var frameAudits: [MetalIndexedBirdSurfaceFrameAudit] = []
        frameAudits.reserveCapacity(dataset.frameCount)
        var maximumPositionError = 0.0
        var maximumVelocityError = 0.0
        var maximumWallDifference = 0.0
        var maximumDistanceDifference = 0.0
        var maximumMaskMismatch = 0
        var allComponentsPresent = true
        var allFinite = true

        for frame in 0..<dataset.frameCount {
            let compareCPU = milestones.contains(frame)
            let time = dataset.frameTimesSeconds[frame]
            let snapshot = try replay.snapshot(
                timeSeconds: time,
                includeWallField: compareCPU
            )
            var framePositionError = 0.0
            var frameVelocityError = 0.0
            for vertex in 0..<dataset.vertexCount {
                let expected = dataset.state(
                    timeSeconds: time,
                    vertexIndex: vertex
                )
                let actual = snapshot.prepared[vertex]
                let position = SIMD3<Float>(
                    actual.position.x,
                    actual.position.y,
                    actual.position.z
                )
                let velocityPhysical = SIMD3<Float>(
                    actual.velocity.x,
                    actual.velocity.y,
                    actual.velocity.z
                ) / replay.velocityToLattice
                framePositionError = max(
                    framePositionError,
                    Double(vectorLength(position - expected.positionMeters))
                )
                frameVelocityError = max(
                    frameVelocityError,
                    Double(vectorLength(
                        velocityPhysical - expected.velocityMetersPerSecond
                    ))
                )
                allFinite = allFinite
                    && position.x.isFinite && position.y.isFinite
                    && position.z.isFinite && velocityPhysical.x.isFinite
                    && velocityPhysical.y.isFinite
                    && velocityPhysical.z.isFinite
            }
            maximumPositionError = max(maximumPositionError, framePositionError)
            maximumVelocityError = max(maximumVelocityError, frameVelocityError)

            var counts = [Int](repeating: 0, count: dataset.components.count)
            var solidCount = 0
            for identifier in snapshot.partIdentifiers where identifier != 0 {
                solidCount += 1
                let index = Int(identifier) - 1
                if counts.indices.contains(index) {
                    counts[index] += 1
                } else {
                    allFinite = false
                }
            }
            allComponentsPresent = allComponentsPresent
                && counts.allSatisfy { $0 > 0 }

            var maximumLatticeWallSpeed = 0.0
            var mismatch: Int?
            var wallDifference: Double?
            var distanceDifference: Double?
            if compareCPU, let gpuWall = snapshot.wallVelocityAndDistance {
                let cpu = replay.cpuRaster(timeSeconds: time)
                var localMismatch = 0
                var localWallDifference = 0.0
                var localDistanceDifference = 0.0
                for cell in 0..<snapshot.partIdentifiers.count {
                    if snapshot.partIdentifiers[cell] != cpu.partIdentifiers[cell] {
                        localMismatch += 1
                    }
                    let gpu = gpuWall[cell]
                    let expected = cpu.wallVelocityAndDistance[cell]
                    // Wall velocity is consumed only on occupied moving-boundary
                    // cells. Candidate AABB cells retain distance diagnostics but
                    // may contain extrapolated barycentrics that never reach the
                    // boundary operator.
                    if snapshot.partIdentifiers[cell] != 0
                        || cpu.partIdentifiers[cell] != 0 {
                        localWallDifference = max(
                            localWallDifference,
                            Double(vectorLength(SIMD3<Float>(
                                gpu.x - expected.x,
                                gpu.y - expected.y,
                                gpu.z - expected.z
                            )))
                        )
                    }
                    localDistanceDifference = max(
                        localDistanceDifference,
                        Double(abs(gpu.w - expected.w))
                    )
                    if snapshot.partIdentifiers[cell] != 0 {
                        maximumLatticeWallSpeed = max(
                            maximumLatticeWallSpeed,
                            Double(vectorLength(SIMD3<Float>(
                                gpu.x, gpu.y, gpu.z
                            )))
                        )
                    }
                    allFinite = allFinite
                        && gpu.x.isFinite && gpu.y.isFinite
                        && gpu.z.isFinite && gpu.w.isFinite
                }
                mismatch = localMismatch
                wallDifference = localWallDifference
                distanceDifference = localDistanceDifference
                maximumMaskMismatch = max(maximumMaskMismatch, localMismatch)
                maximumWallDifference = max(
                    maximumWallDifference,
                    localWallDifference
                )
                maximumDistanceDifference = max(
                    maximumDistanceDifference,
                    localDistanceDifference
                )
            } else {
                // Prepared vertex speed bounds every barycentric surface speed.
                maximumLatticeWallSpeed = snapshot.prepared.reduce(0.0) {
                    max($0, Double(vectorLength(SIMD3<Float>(
                        $1.velocity.x, $1.velocity.y, $1.velocity.z
                    ))))
                }
            }
            let occupancyData = Data(snapshot.partIdentifiers)
            frameAudits.append(MetalIndexedBirdSurfaceFrameAudit(
                frameIndex: frame,
                sourceFrameNumber: dataset.frameNumbers[frame],
                timeSeconds: Double(time),
                solidCellCount: solidCount,
                componentSolidCellCounts: counts,
                occupancySHA256: CheckpointArchive.sha256(occupancyData),
                maximumLatticeWallSpeed: maximumLatticeWallSpeed,
                maximumPreparedPositionErrorMeters: framePositionError,
                maximumPreparedVelocityErrorMetersPerSecond: frameVelocityError,
                cpuRasterCompared: compareCPU,
                cpuMaskMismatchCellCount: mismatch,
                maximumCPUWallVelocityDifferenceLattice: wallDifference,
                maximumCPUSignedDistanceDifferenceCells: distanceDifference
            ))
        }

        let fractionalProbeIntervals = [0, 33, 89, 126, 142]
        let fractionalProbeTimes = fractionalProbeIntervals.map { frame in
            0.5 * (
                dataset.frameTimesSeconds[frame]
                    + dataset.frameTimesSeconds[frame + 1]
            )
        }
        for time in fractionalProbeTimes {
            let snapshot = try replay.snapshot(
                timeSeconds: time,
                includeWallField: false
            )
            var counts = [Int](repeating: 0, count: dataset.components.count)
            for identifier in snapshot.partIdentifiers where identifier != 0 {
                let index = Int(identifier) - 1
                if counts.indices.contains(index) {
                    counts[index] += 1
                } else {
                    allFinite = false
                }
            }
            allComponentsPresent = allComponentsPresent
                && counts.allSatisfy { $0 > 0 }
            for vertex in 0..<dataset.vertexCount {
                let expected = dataset.state(
                    timeSeconds: time,
                    vertexIndex: vertex
                )
                let actual = snapshot.prepared[vertex]
                let position = SIMD3<Float>(
                    actual.position.x,
                    actual.position.y,
                    actual.position.z
                )
                let velocityPhysical = SIMD3<Float>(
                    actual.velocity.x,
                    actual.velocity.y,
                    actual.velocity.z
                ) / replay.velocityToLattice
                maximumPositionError = max(
                    maximumPositionError,
                    Double(vectorLength(position - expected.positionMeters))
                )
                maximumVelocityError = max(
                    maximumVelocityError,
                    Double(vectorLength(
                        velocityPhysical - expected.velocityMetersPerSecond
                    ))
                )
                allFinite = allFinite
                    && position.x.isFinite && position.y.isFinite
                    && position.z.isFinite && velocityPhysical.x.isFinite
                    && velocityPhysical.y.isFinite && velocityPhysical.z.isFinite
            }
        }

        let passed = maximumPositionError <= 2.0e-7
            && maximumVelocityError <= 5.0e-3
            && maximumMaskMismatch == 0
            // CPU SIMD and strict Metal arithmetic need not fuse the same
            // barycentric operations. This remains below 0.1% of the measured
            // maximum wall speed while occupancy must still match exactly.
            && maximumWallDifference <= 2.5e-5
            && maximumDistanceDifference <= 2.0e-5
            && allComponentsPresent
            && allFinite
            && frameAudits.allSatisfy {
                $0.solidCellCount > 0
                    && $0.maximumLatticeWallSpeed.isFinite
                    && $0.maximumLatticeWallSpeed <= 0.08
            }
            && dataset.completeBirdSurfaceReady
            && !dataset.quantitativeForceAcceptanceReady
        return MetalIndexedBirdSurfaceReplayReport(
            schemaVersion: 2,
            deviceName: backend.device.name,
            datasetIdentifier: dataset.datasetIdentifier,
            scientificTier: dataset.scientificTier,
            manifestSHA256: dataset.manifestSHA256,
            sourceSurfaceSHA256: dataset.sourceSurfaceSHA256,
            sourceMuscleModelSHA256: dataset.sourceMuscleModelSHA256,
            frameCount: dataset.frameCount,
            vertexCount: dataset.vertexCount,
            triangleCount: dataset.triangleCount,
            gridX: replay.grid.x,
            gridY: replay.grid.y,
            gridZ: replay.grid.z,
            cellSizeMeters: Double(cellSizeMeters),
            halfThicknessCells: Double(halfThicknessCells),
            runtimeSeconds: Date().timeIntervalSince(startTime),
            geometryKernelSequence: [
                "prepareIndexedBirdSurface",
                "clearMeasuredWingSurface",
                "rasterizeIndexedBirdSurface",
                "resolveIndexedBirdSurface",
            ],
            cpuRasterMilestoneFrames: milestones,
            fractionalInterpolationProbeTimesSeconds:
                fractionalProbeTimes.map(Double.init),
            maximumPreparedPositionErrorMeters: maximumPositionError,
            maximumPreparedVelocityErrorMetersPerSecond: maximumVelocityError,
            maximumCPUWallVelocityDifferenceLattice: maximumWallDifference,
            maximumCPUSignedDistanceDifferenceCells: maximumDistanceDifference,
            maximumCPUMaskMismatchCellCount: maximumMaskMismatch,
            allComponentsPresentEveryFrame: allComponentsPresent,
            allValuesFinite: allFinite,
            fluidCollisionExecuted: false,
            forceAccumulationExecuted: false,
            frameAudits: frameAudits,
            passed: passed,
            claimBoundary: (
                "This geometry-only gate closes indexed loading, non-periodic "
                    + "interpolation, component occupancy, rasterization, and "
                    + "wall velocity. It executes no fluid collision or force "
                    + "accumulation and implies no aerodynamic agreement."
            )
        )
#else
        throw BirdFlowError.metalUnavailable
#endif
    }
}

#if canImport(Metal)
private final class MetalIndexedBirdSurfaceReplay {
    struct Snapshot {
        let prepared: [GPUPreparedMeasuredWingPoint]
        let partIdentifiers: [UInt8]
        let wallVelocityAndDistance: [SIMD4<Float>]?
    }

    struct CPURaster {
        let partIdentifiers: [UInt8]
        let wallVelocityAndDistance: [SIMD4<Float>]
    }

    let grid: GridSize
    let velocityToLattice: Float

    private let backend: MetalBackend
    private let dataset: MeasuredBirdSurfaceSequence
    private let configuration: SimulationConfiguration
    private let halfThicknessMeters: Float
    private let parameters: MTLBuffer
    private let sourcePoints: MTLBuffer
    private let frameTimes: MTLBuffer
    private let triangleIndices: MTLBuffer
    private let trianglePartIdentifiers: MTLBuffer
    private let prepared: MTLBuffer
    private let partMask: MTLBuffer
    private let wallVelocityAndDistance: MTLBuffer
    private let distanceKeys: MTLBuffer
    private let preparedStaging: MTLBuffer
    private let maskStaging: MTLBuffer
    private let wallStaging: MTLBuffer
    private let preparePipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState
    private let rasterPipeline: MTLComputePipelineState
    private let resolvePipeline: MTLComputePipelineState

    init(
        backend: MetalBackend,
        dataset: MeasuredBirdSurfaceSequence,
        cellSizeMeters: Float,
        halfThicknessCells: Float
    ) throws {
        self.backend = backend
        self.dataset = dataset
        halfThicknessMeters = halfThicknessCells * cellSizeMeters
        let paddingCells = 4
        let minimum = dataset.minimumPositionMeters
            - SIMD3<Float>(repeating: Float(paddingCells) * cellSizeMeters)
        let maximum = dataset.maximumPositionMeters
            + SIMD3<Float>(repeating: Float(paddingCells) * cellSizeMeters)
        let extent = maximum - minimum
        grid = try GridSize(
            x: max(16, Int(ceil(extent.x / cellSizeMeters)) + 1),
            y: max(16, Int(ceil(extent.y / cellSizeMeters)) + 1),
            z: max(16, Int(ceil(extent.z / cellSizeMeters)) + 1)
        )
        let maximumSpeed = dataset.maximumPointSpeedMetersPerSecond
        let scaling = try LatticeScaling(
            characteristicLengthMeters: 8 * cellSizeMeters,
            characteristicLengthCells: 8,
            referenceSpeedMetersPerSecond: maximumSpeed,
            targetReynoldsNumber: 1_000,
            physicalAirDensity: 1,
            latticeReferenceSpeed: 0.04
        )
        configuration = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: minimum,
            scaling: scaling,
            physicalAirDensity: 1,
            farFieldVelocityMetersPerSecond: .zero,
            spongeWidthCells: 4,
            spongeStrength: 0,
            freeFlight: false,
            gravityMetersPerSecondSquared: .zero,
            fastMath: false
        )
        velocityToLattice = scaling.velocityToLattice
        let gpuParameters = GPUIndexedBirdSurfaceParameters(
            counts: SIMD4<UInt32>(
                UInt32(dataset.vertexCount),
                UInt32(dataset.triangleCount),
                UInt32(dataset.frameCount),
                0
            ),
            queryTimeAndThickness: SIMD4<Float>(
                dataset.frameTimesSeconds[0],
                halfThicknessMeters,
                cellSizeMeters,
                0
            ),
            translationAndVelocityScale: SIMD4<Float>(
                0, 0, 0, scaling.velocityToLattice
            )
        )
        parameters = try backend.makeSharedBuffer(value: gpuParameters)

        let packedPoints = dataset.packedPoints()
        let sourcePointsBuffer = try backend.makeSharedBuffer(
            length: packedPoints.count * MemoryLayout<SIMD4<Float>>.stride
        )
        _ = packedPoints.withUnsafeBytes { source in
            memcpy(
                sourcePointsBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        sourcePoints = sourcePointsBuffer
        let frameTimesBuffer = try backend.makeSharedBuffer(
            length: dataset.frameTimesSeconds.count * MemoryLayout<Float>.stride
        )
        _ = dataset.frameTimesSeconds.withUnsafeBytes { source in
            memcpy(
                frameTimesBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        frameTimes = frameTimesBuffer
        let triangleIndicesBuffer = try backend.makeSharedBuffer(
            length: dataset.triangleIndices.count * MemoryLayout<UInt16>.stride
        )
        _ = dataset.triangleIndices.withUnsafeBytes { source in
            memcpy(
                triangleIndicesBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        triangleIndices = triangleIndicesBuffer
        let trianglePartIdentifiersBuffer = try backend.makeSharedBuffer(
            length: dataset.trianglePartIdentifiers.count
        )
        _ = dataset.trianglePartIdentifiers.withUnsafeBytes { source in
            memcpy(
                trianglePartIdentifiersBuffer.contents(),
                source.baseAddress!,
                source.count
            )
        }
        trianglePartIdentifiers = trianglePartIdentifiersBuffer

        let preparedBytes = dataset.vertexCount
            * MemoryLayout<GPUPreparedMeasuredWingPoint>.stride
        let maskBytes = grid.cellCount
        let wallBytes = grid.cellCount * MemoryLayout<SIMD4<Float>>.stride
        let distanceBytes = grid.cellCount * MemoryLayout<UInt32>.stride
        try backend.validateAllocationPlan(bufferLengths: [
            parameters.length,
            sourcePoints.length,
            frameTimes.length,
            triangleIndices.length,
            trianglePartIdentifiers.length,
            preparedBytes,
            maskBytes,
            wallBytes,
            distanceBytes,
            preparedBytes,
            maskBytes,
            wallBytes,
        ])
        prepared = try backend.makePrivateBuffer(length: preparedBytes)
        partMask = try backend.makePrivateBuffer(length: maskBytes)
        wallVelocityAndDistance = try backend.makePrivateBuffer(length: wallBytes)
        distanceKeys = try backend.makePrivateBuffer(length: distanceBytes)
        preparedStaging = try backend.makeSharedBuffer(length: preparedBytes)
        maskStaging = try backend.makeSharedBuffer(length: maskBytes)
        wallStaging = try backend.makeSharedBuffer(length: wallBytes)
        preparePipeline = try backend.pipeline(named: "prepareIndexedBirdSurface")
        clearPipeline = try backend.pipeline(named: "clearMeasuredWingSurface")
        rasterPipeline = try backend.pipeline(named: "rasterizeIndexedBirdSurface")
        resolvePipeline = try backend.pipeline(named: "resolveIndexedBirdSurface")
    }

    func snapshot(
        timeSeconds: Float,
        includeWallField: Bool
    ) throws -> Snapshot {
        let interval = dataset.interpolationInterval(timeSeconds: timeSeconds)
        let surface = parameters.contents().assumingMemoryBound(
            to: GPUIndexedBirdSurfaceParameters.self
        )
        surface.pointee.counts.w = UInt32(interval.first)
        surface.pointee.queryTimeAndThickness.x = timeSeconds
        var uniforms = GPUUniforms(
            configuration: configuration,
            time: 0,
            captureMacroscopicFields: false,
            accumulateLoads: false,
            hasPreviousGeometry: false
        )
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create indexed-bird geometry command buffer."
            )
        }
        try encodeIndexedPreparation(commandBuffer: commandBuffer)
        try encodeClear(commandBuffer: commandBuffer, uniforms: &uniforms)
        try encodeIndexedRaster(commandBuffer: commandBuffer, uniforms: &uniforms)
        try encodeIndexedResolve(commandBuffer: commandBuffer, uniforms: &uniforms)
        guard let blit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create indexed-bird geometry audit blit."
            )
        }
        blit.copy(
            from: prepared,
            sourceOffset: 0,
            to: preparedStaging,
            destinationOffset: 0,
            size: prepared.length
        )
        blit.copy(
            from: partMask,
            sourceOffset: 0,
            to: maskStaging,
            destinationOffset: 0,
            size: partMask.length
        )
        if includeWallField {
            blit.copy(
                from: wallVelocityAndDistance,
                sourceOffset: 0,
                to: wallStaging,
                destinationOffset: 0,
                size: wallVelocityAndDistance.length
            )
        }
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        try check(commandBuffer)

        let preparedValues = Array(UnsafeBufferPointer(
            start: preparedStaging.contents().assumingMemoryBound(
                to: GPUPreparedMeasuredWingPoint.self
            ),
            count: dataset.vertexCount
        ))
        let maskValues = Array(UnsafeBufferPointer(
            start: maskStaging.contents().assumingMemoryBound(to: UInt8.self),
            count: grid.cellCount
        ))
        let wallValues: [SIMD4<Float>]? = includeWallField
            ? Array(UnsafeBufferPointer(
                start: wallStaging.contents().assumingMemoryBound(
                    to: SIMD4<Float>.self
                ),
                count: grid.cellCount
            ))
            : nil
        return Snapshot(
            prepared: preparedValues,
            partIdentifiers: maskValues,
            wallVelocityAndDistance: wallValues
        )
    }

    func cpuRaster(timeSeconds: Float) -> CPURaster {
        let states = (0..<dataset.vertexCount).map {
            dataset.state(timeSeconds: timeSeconds, vertexIndex: $0)
        }
        let positions = states.map(\.positionMeters)
        let velocities = states.map {
            $0.velocityMetersPerSecond * velocityToLattice
        }
        var distanceKeys = [UInt32](
            repeating: UInt32.max,
            count: grid.cellCount
        )
        let origin = configuration.domainOriginMeters
        let cellSize = configuration.scaling.cellSizeMeters
        for triangle in 0..<dataset.triangleCount {
            let indices = dataset.triangle(triangle)
            let a = positions[Int(indices.x)]
            let b = positions[Int(indices.y)]
            let c = positions[Int(indices.z)]
            let guardDistance = halfThicknessMeters + 2 * cellSize
            let lowerWorld = componentMinimum(a, b, c)
                - SIMD3<Float>(repeating: guardDistance)
            let upperWorld = componentMaximum(a, b, c)
                + SIMD3<Float>(repeating: guardDistance)
            let lower = clampedCell(
                world: lowerWorld,
                origin: origin,
                cellSize: cellSize,
                upper: false
            )
            let upper = clampedCell(
                world: upperWorld,
                origin: origin,
                cellSize: cellSize,
                upper: true
            )
            for z in lower.z...upper.z {
                for y in lower.y...upper.y {
                    for x in lower.x...upper.x {
                        let world = origin + (
                            SIMD3<Float>(Float(x), Float(y), Float(z))
                                + SIMD3<Float>(repeating: 0.5)
                        ) * cellSize
                        let closest = triangleClosestPoint(
                            point: world,
                            a: a,
                            b: b,
                            c: c
                        )
                        let distanceCells = vectorLength(
                            world - closest.position
                        ) / cellSize
                        let bin = min(
                            UInt32((distanceCells * 65_536).rounded()),
                            0xF_FFFF
                        )
                        let key = (bin << 12) | UInt32(triangle)
                        let index = x + grid.x * (y + grid.y * z)
                        distanceKeys[index] = min(distanceKeys[index], key)
                    }
                }
            }
        }

        var mask = [UInt8](repeating: 0, count: grid.cellCount)
        var wall = [SIMD4<Float>](
            repeating: SIMD4<Float>(0, 0, 0, 16),
            count: grid.cellCount
        )
        for index in 0..<grid.cellCount {
            let key = distanceKeys[index]
            guard key != UInt32.max else { continue }
            let triangle = Int(key & 0xFFF)
            let indices = dataset.triangle(triangle)
            let x = index % grid.x
            let yz = index / grid.x
            let y = yz % grid.y
            let z = yz / grid.y
            let world = origin + (
                SIMD3<Float>(Float(x), Float(y), Float(z))
                    + SIMD3<Float>(repeating: 0.5)
            ) * cellSize
            let closest = triangleClosestPoint(
                point: world,
                a: positions[Int(indices.x)],
                b: positions[Int(indices.y)],
                c: positions[Int(indices.z)]
            )
            let velocity = closest.barycentric.x * velocities[Int(indices.x)]
                + closest.barycentric.y * velocities[Int(indices.y)]
                + closest.barycentric.z * velocities[Int(indices.z)]
            let signedDistance = vectorLength(world - closest.position)
                - halfThicknessMeters
            if signedDistance <= 0 {
                mask[index] = dataset.trianglePartIdentifiers[triangle]
            }
            wall[index] = SIMD4<Float>(
                velocity,
                signedDistance / cellSize
            )
        }
        return CPURaster(
            partIdentifiers: mask,
            wallVelocityAndDistance: wall
        )
    }

    private func clampedCell(
        world: SIMD3<Float>,
        origin: SIMD3<Float>,
        cellSize: Float,
        upper: Bool
    ) -> SIMD3<Int> {
        let scaled = (world - origin) / cellSize
            - SIMD3<Float>(repeating: 0.5)
        let converted = SIMD3<Int>(
            Int(upper ? ceil(scaled.x) : floor(scaled.x)),
            Int(upper ? ceil(scaled.y) : floor(scaled.y)),
            Int(upper ? ceil(scaled.z) : floor(scaled.z))
        )
        return SIMD3<Int>(
            min(max(converted.x, 0), grid.x - 1),
            min(max(converted.y, 0), grid.y - 1),
            min(max(converted.z, 0), grid.z - 1)
        )
    }

    private func encodeIndexedPreparation(
        commandBuffer: MTLCommandBuffer
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird preparation."
            )
        }
        encoder.setBuffer(sourcePoints, offset: 0, index: 0)
        encoder.setBuffer(frameTimes, offset: 0, index: 1)
        encoder.setBuffer(prepared, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        backend.dispatch1D(
            encoder: encoder,
            pipeline: preparePipeline,
            count: dataset.vertexCount
        )
        encoder.endEncoding()
    }

    private func encodeClear(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird clear."
            )
        }
        encoder.setBuffer(partMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 1)
        encoder.setBuffer(distanceKeys, offset: 0, index: 2)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 3
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: clearPipeline,
            count: grid.cellCount
        )
        encoder.endEncoding()
    }

    private func encodeIndexedRaster(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird rasterization."
            )
        }
        encoder.setBuffer(prepared, offset: 0, index: 0)
        encoder.setBuffer(triangleIndices, offset: 0, index: 1)
        encoder.setBuffer(distanceKeys, offset: 0, index: 2)
        encoder.setBuffer(parameters, offset: 0, index: 3)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 4
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: rasterPipeline,
            count: dataset.triangleCount
        )
        encoder.endEncoding()
    }

    private func encodeIndexedResolve(
        commandBuffer: MTLCommandBuffer,
        uniforms: inout GPUUniforms
    ) throws {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to encode indexed-bird resolution."
            )
        }
        encoder.setBuffer(partMask, offset: 0, index: 0)
        encoder.setBuffer(wallVelocityAndDistance, offset: 0, index: 1)
        encoder.setBuffer(prepared, offset: 0, index: 2)
        encoder.setBuffer(triangleIndices, offset: 0, index: 3)
        encoder.setBuffer(trianglePartIdentifiers, offset: 0, index: 4)
        encoder.setBuffer(distanceKeys, offset: 0, index: 5)
        encoder.setBuffer(parameters, offset: 0, index: 6)
        encoder.setBytes(
            &uniforms,
            length: MemoryLayout<GPUUniforms>.stride,
            index: 7
        )
        backend.dispatch1D(
            encoder: encoder,
            pipeline: resolvePipeline,
            count: grid.cellCount
        )
        encoder.endEncoding()
    }

    private func check(_ commandBuffer: MTLCommandBuffer) throws {
        if commandBuffer.status == .error {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Indexed-bird geometry command failed."
            )
        }
    }
}

private struct TriangleClosestPoint {
    let position: SIMD3<Float>
    let barycentric: SIMD3<Float>
}

private func triangleClosestPoint(
    point: SIMD3<Float>,
    a: SIMD3<Float>,
    b: SIMD3<Float>,
    c: SIMD3<Float>
) -> TriangleClosestPoint {
    let ab = b - a
    let ac = c - a
    let ap = point - a
    let d1 = dot(ab, ap)
    let d2 = dot(ac, ap)
    if d1 <= 0, d2 <= 0 {
        return TriangleClosestPoint(position: a, barycentric: SIMD3(1, 0, 0))
    }
    let bp = point - b
    let d3 = dot(ab, bp)
    let d4 = dot(ac, bp)
    if d3 >= 0, d4 <= d3 {
        return TriangleClosestPoint(position: b, barycentric: SIMD3(0, 1, 0))
    }
    let vc = d1 * d4 - d3 * d2
    if vc <= 0, d1 >= 0, d3 <= 0 {
        let value = d1 / (d1 - d3)
        return TriangleClosestPoint(
            position: a + value * ab,
            barycentric: SIMD3(1 - value, value, 0)
        )
    }
    let cp = point - c
    let d5 = dot(ab, cp)
    let d6 = dot(ac, cp)
    if d6 >= 0, d5 <= d6 {
        return TriangleClosestPoint(position: c, barycentric: SIMD3(0, 0, 1))
    }
    let vb = d5 * d2 - d1 * d6
    if vb <= 0, d2 >= 0, d6 <= 0 {
        let value = d2 / (d2 - d6)
        return TriangleClosestPoint(
            position: a + value * ac,
            barycentric: SIMD3(1 - value, 0, value)
        )
    }
    let va = d3 * d6 - d5 * d4
    if va <= 0, d4 - d3 >= 0, d5 - d6 >= 0 {
        let value = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return TriangleClosestPoint(
            position: b + value * (c - b),
            barycentric: SIMD3(0, 1 - value, value)
        )
    }
    let inverse = 1 / max(va + vb + vc, 1.0e-20)
    let v = vb * inverse
    let w = vc * inverse
    return TriangleClosestPoint(
        position: a + v * ab + w * ac,
        barycentric: SIMD3(1 - v - w, v, w)
    )
}

private func dot(_ first: SIMD3<Float>, _ second: SIMD3<Float>) -> Float {
    first.x * second.x + first.y * second.y + first.z * second.z
}

private func componentMinimum(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ third: SIMD3<Float>
) -> SIMD3<Float> {
    SIMD3<Float>(
        min(first.x, second.x, third.x),
        min(first.y, second.y, third.y),
        min(first.z, second.z, third.z)
    )
}

private func componentMaximum(
    _ first: SIMD3<Float>,
    _ second: SIMD3<Float>,
    _ third: SIMD3<Float>
) -> SIMD3<Float> {
    SIMD3<Float>(
        max(first.x, second.x, third.x),
        max(first.y, second.y, third.y),
        max(first.z, second.z, third.z)
    )
}

private func vectorLength(_ vector: SIMD3<Float>) -> Float {
    sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
}
#endif

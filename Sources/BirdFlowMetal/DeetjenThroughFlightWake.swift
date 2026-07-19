import BirdFlowCore
import Foundation

#if canImport(Metal)
    import Metal
#endif

public struct DeetjenDoveWakeSlice: Codable, Sendable, Equatable {
    public let sourceFrameIndex: Int
    public let sourceTimeSeconds: Double
    public let bodyCenterMeters: SIMD3<Double>
    public let desiredAftPlaneXMeters: Double
    public let planeXCellIndex: Int
    public let planeXMeters: Double
    public let gridY: Int
    public let gridZ: Int
    public let validCellCount: Int
    public let minimumValidDensityLattice: Double
    public let maximumValidDensityLattice: Double
    public let maximumAbsoluteStreamwiseVorticityPerSecond: Double
    public let maximumPositiveQCriterionPerSecondSquared: Double
    public let streamwiseVorticityPerSecond: [Float]
    public let qCriterionPerSecondSquared: [Float]
    public let valid: [UInt8]
}

public enum DeetjenDoveWakeSliceReference {
    public static func compute(
        densityLattice: [Float],
        velocityLattice: [SIMD3<Float>],
        solidPartIdentifiers: [UInt8],
        grid: GridSize,
        domainOriginMeters: SIMD3<Float>,
        cellSizeMeters: Float,
        velocityToPhysical: Float,
        bodyCenterMeters: SIMD3<Float>,
        aftOffsetMeters: Float,
        sourceFrameIndex: Int,
        sourceTimeSeconds: Float
    ) -> DeetjenDoveWakeSlice {
        precondition(densityLattice.count == grid.cellCount)
        precondition(velocityLattice.count == grid.cellCount)
        precondition(solidPartIdentifiers.count == grid.cellCount)
        precondition(cellSizeMeters > 0)
        precondition(velocityToPhysical > 0)
        precondition(aftOffsetMeters > 0)

        let desiredX = bodyCenterMeters.x - aftOffsetMeters
        let rawX = Int(
            round(
                (desiredX - domainOriginMeters.x) / cellSizeMeters - 0.5
            ))
        let x = min(max(rawX, 1), grid.x - 2)
        let planeX =
            domainOriginMeters.x
            + (Float(x) + 0.5) * cellSizeMeters
        let planeCellCount = grid.y * grid.z
        var streamwiseVorticity = [Float](
            repeating: 0,
            count: planeCellCount
        )
        var qCriterion = [Float](repeating: 0, count: planeCellCount)
        var valid = [UInt8](repeating: 0, count: planeCellCount)
        var validCellCount = 0
        var minimumDensity = Float.infinity
        var maximumDensity = -Float.infinity
        var maximumVorticity = Float.zero
        var maximumPositiveQ = Float.zero
        let derivativeScale = 0.5 * velocityToPhysical / cellSizeMeters

        func volumeIndex(_ x: Int, _ y: Int, _ z: Int) -> Int {
            x + grid.x * (y + grid.y * z)
        }
        func planeIndex(_ y: Int, _ z: Int) -> Int {
            y + grid.y * z
        }
        func finite(_ value: SIMD3<Float>) -> Bool {
            value.x.isFinite && value.y.isFinite && value.z.isFinite
        }

        for z in 1..<(grid.z - 1) {
            for y in 1..<(grid.y - 1) {
                let center = volumeIndex(x, y, z)
                let lowerX = volumeIndex(x - 1, y, z)
                let upperX = volumeIndex(x + 1, y, z)
                let lowerY = volumeIndex(x, y - 1, z)
                let upperY = volumeIndex(x, y + 1, z)
                let lowerZ = volumeIndex(x, y, z - 1)
                let upperZ = volumeIndex(x, y, z + 1)
                let stencil = [
                    center, lowerX, upperX, lowerY, upperY, lowerZ, upperZ,
                ]
                guard
                    stencil.allSatisfy({
                        solidPartIdentifiers[$0] == 0
                            && densityLattice[$0].isFinite
                            && densityLattice[$0] > 0
                            && finite(velocityLattice[$0])
                    })
                else {
                    continue
                }

                let dx =
                    derivativeScale
                    * (velocityLattice[upperX] - velocityLattice[lowerX])
                let dy =
                    derivativeScale
                    * (velocityLattice[upperY] - velocityLattice[lowerY])
                let dz =
                    derivativeScale
                    * (velocityLattice[upperZ] - velocityLattice[lowerZ])
                let streamwise = dy.z - dz.y
                let traceSquare =
                    dx.x * dx.x + dy.y * dy.y + dz.z * dz.z
                    + 2 * (dx.y * dy.x + dx.z * dz.x + dy.z * dz.y)
                let q = -0.5 * traceSquare
                guard streamwise.isFinite, q.isFinite else { continue }

                let output = planeIndex(y, z)
                streamwiseVorticity[output] = streamwise
                qCriterion[output] = q
                valid[output] = 1
                validCellCount += 1
                minimumDensity = min(minimumDensity, densityLattice[center])
                maximumDensity = max(maximumDensity, densityLattice[center])
                maximumVorticity = max(maximumVorticity, abs(streamwise))
                maximumPositiveQ = max(maximumPositiveQ, q)
            }
        }

        return DeetjenDoveWakeSlice(
            sourceFrameIndex: sourceFrameIndex,
            sourceTimeSeconds: Double(sourceTimeSeconds),
            bodyCenterMeters: SIMD3<Double>(
                Double(bodyCenterMeters.x),
                Double(bodyCenterMeters.y),
                Double(bodyCenterMeters.z)
            ),
            desiredAftPlaneXMeters: Double(desiredX),
            planeXCellIndex: x,
            planeXMeters: Double(planeX),
            gridY: grid.y,
            gridZ: grid.z,
            validCellCount: validCellCount,
            minimumValidDensityLattice: minimumDensity.isFinite
                ? Double(minimumDensity) : 0,
            maximumValidDensityLattice: maximumDensity.isFinite
                ? Double(maximumDensity) : 0,
            maximumAbsoluteStreamwiseVorticityPerSecond:
                Double(maximumVorticity),
            maximumPositiveQCriterionPerSecondSquared:
                Double(maximumPositiveQ),
            streamwiseVorticityPerSecond: streamwiseVorticity,
            qCriterionPerSecondSquared: qCriterion,
            valid: valid
        )
    }
}

#if canImport(Metal)
    final class MetalIndexedBirdSurfaceWakeCapture {
        let sourceFrameIndices: [Int]
        let aftOffsetMeters: Float
        private(set) var slices: [DeetjenDoveWakeSlice] = []

        private let selectedFrames: Set<Int>
        private let fluidStepsPerSourceFrame: Int
        private let grid: GridSize
        private let domainOriginMeters: SIMD3<Float>
        private let cellSizeMeters: Float
        private let velocityToPhysical: Float
        private let densityStaging: MTLBuffer
        private let velocityStaging: MTLBuffer
        private let maskStaging: MTLBuffer

        init(
            backend: MetalBackend,
            sourceFrameIndices: [Int],
            fluidStepsPerSourceFrame: Int,
            grid: GridSize,
            domainOriginMeters: SIMD3<Float>,
            cellSizeMeters: Float,
            velocityToPhysical: Float,
            aftOffsetMeters: Float
        ) throws {
            precondition(!sourceFrameIndices.isEmpty)
            precondition(fluidStepsPerSourceFrame > 0)
            self.sourceFrameIndices = sourceFrameIndices
            selectedFrames = Set(sourceFrameIndices)
            self.fluidStepsPerSourceFrame = fluidStepsPerSourceFrame
            self.grid = grid
            self.domainOriginMeters = domainOriginMeters
            self.cellSizeMeters = cellSizeMeters
            self.velocityToPhysical = velocityToPhysical
            self.aftOffsetMeters = aftOffsetMeters
            let densityBytes = grid.cellCount * MemoryLayout<Float>.stride
            let velocityBytes =
                grid.cellCount
                * MemoryLayout<SIMD4<Float>>.stride
            let maskBytes = grid.cellCount * MemoryLayout<UInt8>.stride
            try backend.validateAllocationPlan(bufferLengths: [
                densityBytes, velocityBytes, maskBytes,
            ])
            densityStaging = try backend.makeSharedBuffer(length: densityBytes)
            velocityStaging = try backend.makeSharedBuffer(length: velocityBytes)
            maskStaging = try backend.makeSharedBuffer(length: maskBytes)
            densityStaging.label = "Deetjen wake density staging"
            velocityStaging.label = "Deetjen wake velocity staging"
            maskStaging.label = "Deetjen wake mask staging"
        }

        func sourceFrameIndex(forStep step: Int) -> Int? {
            guard step % fluidStepsPerSourceFrame == 0 else { return nil }
            let frame = step / fluidStepsPerSourceFrame
            return selectedFrames.contains(frame) ? frame : nil
        }

        func encodeReadback(
            commandBuffer: MTLCommandBuffer,
            density: MTLBuffer,
            velocity: MTLBuffer,
            solidPartIdentifiers: MTLBuffer
        ) throws {
            guard let blit = commandBuffer.makeBlitCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to encode Deetjen wake-field readback."
                )
            }
            blit.copy(
                from: density,
                sourceOffset: 0,
                to: densityStaging,
                destinationOffset: 0,
                size: densityStaging.length
            )
            blit.copy(
                from: velocity,
                sourceOffset: 0,
                to: velocityStaging,
                destinationOffset: 0,
                size: velocityStaging.length
            )
            blit.copy(
                from: solidPartIdentifiers,
                sourceOffset: 0,
                to: maskStaging,
                destinationOffset: 0,
                size: maskStaging.length
            )
            blit.endEncoding()
        }

        func record(
            sourceFrameIndex: Int,
            sourceTimeSeconds: Float,
            bodyCenterMeters: SIMD3<Float>
        ) {
            let densityPointer = densityStaging.contents()
                .assumingMemoryBound(to: Float.self)
            let velocityPointer = velocityStaging.contents()
                .assumingMemoryBound(to: SIMD4<Float>.self)
            let maskPointer = maskStaging.contents()
                .assumingMemoryBound(to: UInt8.self)
            var density = [Float](repeating: 0, count: grid.cellCount)
            var velocity = [SIMD3<Float>](repeating: .zero, count: grid.cellCount)
            var mask = [UInt8](repeating: 0, count: grid.cellCount)
            for index in 0..<grid.cellCount {
                density[index] = densityPointer[index]
                velocity[index] = SIMD3<Float>(
                    velocityPointer[index].x,
                    velocityPointer[index].y,
                    velocityPointer[index].z
                )
                mask[index] = maskPointer[index]
            }
            slices.append(
                DeetjenDoveWakeSliceReference.compute(
                    densityLattice: density,
                    velocityLattice: velocity,
                    solidPartIdentifiers: mask,
                    grid: grid,
                    domainOriginMeters: domainOriginMeters,
                    cellSizeMeters: cellSizeMeters,
                    velocityToPhysical: velocityToPhysical,
                    bodyCenterMeters: bodyCenterMeters,
                    aftOffsetMeters: aftOffsetMeters,
                    sourceFrameIndex: sourceFrameIndex,
                    sourceTimeSeconds: sourceTimeSeconds
                ))
        }
    }
#endif

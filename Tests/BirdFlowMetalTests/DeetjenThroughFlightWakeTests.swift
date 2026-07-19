import BirdFlowCore
import Foundation
import Testing

@testable import BirdFlowMetal

@Test("Deetjen transverse wake slice matches the shared diagnostic convention")
func deetjenWakeSliceMatchesSharedFlowDiagnostics() throws {
    let grid = try GridSize(x: 16, y: 17, z: 18)
    let cellSize: Float = 0.01
    let velocityToPhysical: Float = 3.5
    let latticeGradient: Float = 0.002
    var velocity = [SIMD3<Float>](repeating: .zero, count: grid.cellCount)
    func index(_ x: Int, _ y: Int, _ z: Int) -> Int {
        x + grid.x * (y + grid.y * z)
    }
    for z in 0..<grid.z {
        for y in 0..<grid.y {
            for x in 0..<grid.x {
                velocity[index(x, y, z)] = SIMD3<Float>(
                    0,
                    -latticeGradient * Float(z),
                    latticeGradient * Float(y)
                )
            }
        }
    }
    let density = [Float](repeating: 1, count: grid.cellCount)
    let solid = [UInt8](repeating: 0, count: grid.cellCount)
    let bodyCenter = SIMD3<Float>(0.12, 0.08, 0.09)
    let slice = DeetjenDoveWakeSliceReference.compute(
        densityLattice: density,
        velocityLattice: velocity,
        solidPartIdentifiers: solid,
        grid: grid,
        domainOriginMeters: .zero,
        cellSizeMeters: cellSize,
        velocityToPhysical: velocityToPhysical,
        bodyCenterMeters: bodyCenter,
        aftOffsetMeters: 0.05,
        sourceFrameIndex: 25,
        sourceTimeSeconds: 0.025
    )
    let reference = FlowDiagnosticsReference.compute(
        velocity: velocity,
        grid: grid,
        cellSizeMeters: cellSize,
        velocityToPhysical: velocityToPhysical
    )
    #expect(slice.gridY == grid.y)
    #expect(slice.gridZ == grid.z)
    #expect(slice.validCellCount == (grid.y - 2) * (grid.z - 2))
    for z in 1..<(grid.z - 1) {
        for y in 1..<(grid.y - 1) {
            let planeIndex = y + grid.y * z
            let volumeIndex = index(slice.planeXCellIndex, y, z)
            #expect(slice.valid[planeIndex] == 1)
            #expect(
                abs(
                    slice.streamwiseVorticityPerSecond[planeIndex]
                        - reference.vorticity[volumeIndex].x
                ) <= 1e-6
            )
            #expect(
                abs(
                    slice.qCriterionPerSecondSquared[planeIndex]
                        - reference.qCriterion[volumeIndex]
                ) <= 1e-6
            )
        }
    }
    #expect(slice.maximumAbsoluteStreamwiseVorticityPerSecond > 0)
    #expect(slice.maximumPositiveQCriterionPerSecondSquared > 0)
}

@Test("Deetjen wake schedule locks source and force-window landmarks")
func deetjenWakeScheduleLocksLandmarks() throws {
    let frames =
        try MetalIndexedBirdSurfacePilotValidator
        .deetjenWakeSourceFrameIndices(frameCount: 144)
    #expect(frames.first == 1)
    #expect(frames.last == 143)
    #expect(frames.contains(25))
    #expect(frames.contains(118))
    #expect(frames == frames.sorted())
    #expect(Set(frames).count == frames.count)
}

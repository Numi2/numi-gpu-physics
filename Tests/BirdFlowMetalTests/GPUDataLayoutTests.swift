@testable import BirdFlowMetal
import Testing

@Test
func gpuDataLayoutsMatchMetalFloat4Packing() {
    #expect(MemoryLayout<GPUUniforms>.stride == 8 * 16)
    #expect(MemoryLayout<GPUBirdParameters>.stride == 7 * 16)
    #expect(MemoryLayout<GPUBirdBodyState>.stride == 4 * 16)
    #expect(MemoryLayout<GPUPreparedBirdGeometry>.stride == 14 * 16)
    #expect(MemoryLayout<GPUForceTorque>.stride == 2 * 16)

    #expect(MemoryLayout<GPUUniforms>.alignment == 16)
    #expect(MemoryLayout<GPUBirdParameters>.alignment == 16)
    #expect(MemoryLayout<GPUBirdBodyState>.alignment == 16)
    #expect(MemoryLayout<GPUPreparedBirdGeometry>.alignment == 16)
    #expect(MemoryLayout<GPUForceTorque>.alignment == 16)
}

@testable import BirdFlowMetal
import Testing

@Test
func gpuDataLayoutsMatchMetalFloat4Packing() {
    #expect(MemoryLayout<GPUUniforms>.stride == 8 * 16)
    #expect(MemoryLayout<GPUBirdParameters>.stride == 7 * 16)
    #expect(MemoryLayout<GPUBirdBodyState>.stride == 4 * 16)
    #expect(MemoryLayout<GPUMeasuredWingKeyframe>.stride == 5 * 16)
    #expect(MemoryLayout<GPUPreparedBirdGeometry>.stride == 14 * 16)
    #expect(MemoryLayout<GPUFlappingWingParameters>.stride == 4 * 16)
    #expect(MemoryLayout<GPUPreparedFlappingWing>.stride == 6 * 16)
    #expect(MemoryLayout<GPUMeasuredWingSurfaceParameters>.stride == 4 * 16)
    #expect(MemoryLayout<GPUPreparedMeasuredWingPoint>.stride == 2 * 16)
    #expect(MemoryLayout<GPUForceTorque>.stride == 2 * 16)

    #expect(MemoryLayout<GPUUniforms>.alignment == 16)
    #expect(MemoryLayout<GPUBirdParameters>.alignment == 16)
    #expect(MemoryLayout<GPUBirdBodyState>.alignment == 16)
    #expect(MemoryLayout<GPUMeasuredWingKeyframe>.alignment == 16)
    #expect(MemoryLayout<GPUPreparedBirdGeometry>.alignment == 16)
    #expect(MemoryLayout<GPUFlappingWingParameters>.alignment == 16)
    #expect(MemoryLayout<GPUPreparedFlappingWing>.alignment == 16)
    #expect(MemoryLayout<GPUMeasuredWingSurfaceParameters>.alignment == 16)
    #expect(MemoryLayout<GPUPreparedMeasuredWingPoint>.alignment == 16)
    #expect(MemoryLayout<GPUForceTorque>.alignment == 16)
}

@Test
func publishedPrescribedWingKinematicsHitLockedReversals() {
    let phase0 = MetalFlappingWingValidator.kinematicState(phase: 0)
    let phase25 = MetalFlappingWingValidator.kinematicState(phase: 0.25)
    let phase50 = MetalFlappingWingValidator.kinematicState(phase: 0.5)
    let phase75 = MetalFlappingWingValidator.kinematicState(phase: 0.75)

    #expect(abs(phase0.strokeAngleRadians - 80 * .pi / 180) < 1e-12)
    #expect(abs(phase50.strokeAngleRadians + 80 * .pi / 180) < 1e-12)
    #expect(abs(phase25.strokeAngleRadians) < 1e-12)
    #expect(abs(phase75.strokeAngleRadians) < 1e-12)
    #expect(abs(phase0.strokeRateRadiansPerCycle) < 1e-12)
    #expect(abs(phase50.strokeRateRadiansPerCycle) < 1e-12)
    #expect(
        abs(
            phase25.strokeRateRadiansPerCycle
                + MetalFlappingWingValidator.maximumStrokeRateRadiansPerCycle
        ) < 1e-12
    )
    #expect(
        abs(
            phase75.strokeRateRadiansPerCycle
                - MetalFlappingWingValidator.maximumStrokeRateRadiansPerCycle
        ) < 1e-12
    )
    #expect(abs(phase0.pitchAngleRadians - .pi / 2) < 1e-12)
    #expect(abs(phase50.pitchAngleRadians - .pi / 2) < 1e-12)
    #expect(abs(phase25.pitchAngleRadians - .pi / 4) < 1e-12)
    #expect(abs(phase75.pitchAngleRadians - 3 * .pi / 4) < 1e-12)
}

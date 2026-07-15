import BirdFlowCore
import Foundation

#if canImport(Metal)
import Metal

struct BirdPartLoadCapture {
    var loads: [ForceTorque]
    var geometry: GPUPreparedBirdGeometry
}

final class BirdPartLoadDiagnosticResources {
    private let backend: MetalBackend
    private let partialCount: Int
    private let capturePipeline: MTLComputePipelineState
    private let reductionPipeline: MTLComputePipelineState
    private let reductionA: MTLBuffer
    private let reductionB: MTLBuffer
    private let totals: MTLBuffer
    private let geometryReadback: MTLBuffer

    init(backend: MetalBackend, cellCount: Int) throws {
        self.backend = backend
        partialCount = max(1, (cellCount + 255) / 256)
        capturePipeline = try backend.pipeline(named: "captureBirdPartLoad")
        reductionPipeline = try backend.pipeline(named: "reduceForceTorque")
        let reductionBytes = partialCount
            * MemoryLayout<GPUForceTorque>.stride
        let totalBytes = AerodynamicBodyPart.allCases.count
            * MemoryLayout<GPUForceTorque>.stride
        let geometryBytes = MemoryLayout<GPUPreparedBirdGeometry>.stride
        try backend.validateAllocationPlan(
            bufferLengths: [
                reductionBytes, reductionBytes, totalBytes, geometryBytes,
            ]
        )
        reductionA = try backend.makeSharedBuffer(length: reductionBytes)
        reductionB = try backend.makeSharedBuffer(length: reductionBytes)
        totals = try backend.makeSharedBuffer(length: totalBytes)
        geometryReadback = try backend.makeSharedBuffer(length: geometryBytes)
        reductionA.label = "Part-load reduction A"
        reductionB.label = "Part-load reduction B"
        totals.label = "Body/left/right/tail aerodynamic loads"
        geometryReadback.label = "Part-load articulated frame"
    }

    func capture(
        populationsIn: MTLBuffer,
        solidPrevious: MTLBuffer,
        solidCurrent: MTLBuffer,
        wallVelocity: MTLBuffer,
        preparedGeometry: MTLBuffer,
        uniforms: inout GPUUniforms
    ) throws -> BirdPartLoadCapture {
        guard let commandBuffer = backend.queue.makeCommandBuffer() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to create per-part load command buffer."
            )
        }
        commandBuffer.label = "Bird aerodynamic part-load reconstruction"

        for (partIndex, part) in AerodynamicBodyPart.allCases.enumerated() {
            guard let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to encode per-part load capture."
                )
            }
            var selectedPart = part.maskIdentifier
            encoder.label = "Capture \(part.rawValue) aerodynamic load"
            encoder.setBuffer(populationsIn, offset: 0, index: 0)
            encoder.setBuffer(solidPrevious, offset: 0, index: 1)
            encoder.setBuffer(solidCurrent, offset: 0, index: 2)
            encoder.setBuffer(wallVelocity, offset: 0, index: 3)
            encoder.setBuffer(reductionA, offset: 0, index: 4)
            encoder.setBuffer(preparedGeometry, offset: 0, index: 5)
            encoder.setBytes(
                &uniforms,
                length: MemoryLayout<GPUUniforms>.stride,
                index: 6
            )
            encoder.setBytes(
                &selectedPart,
                length: MemoryLayout<UInt32>.stride,
                index: 7
            )
            backend.dispatch1DPadded(
                encoder: encoder,
                pipeline: capturePipeline,
                count: Int(uniforms.grid.w),
                threadsPerThreadgroup: 256
            )
            encoder.endEncoding()

            let total = try encodeReduction(commandBuffer: commandBuffer)
            guard let blit = commandBuffer.makeBlitCommandEncoder() else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to store per-part load reduction."
                )
            }
            blit.copy(
                from: total,
                sourceOffset: 0,
                to: totals,
                destinationOffset: partIndex
                    * MemoryLayout<GPUForceTorque>.stride,
                size: MemoryLayout<GPUForceTorque>.stride
            )
            blit.endEncoding()
        }

        guard let geometryBlit = commandBuffer.makeBlitCommandEncoder() else {
            throw BirdFlowError.commandBufferFailed(
                "Unable to read the per-part articulated frame."
            )
        }
        geometryBlit.copy(
            from: preparedGeometry,
            sourceOffset: 0,
            to: geometryReadback,
            destinationOffset: 0,
            size: MemoryLayout<GPUPreparedBirdGeometry>.stride
        )
        geometryBlit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            throw BirdFlowError.commandBufferFailed(
                commandBuffer.error?.localizedDescription
                    ?? "Per-part load reconstruction failed."
            )
        }

        let pointer = totals.contents()
            .assumingMemoryBound(to: GPUForceTorque.self)
        return BirdPartLoadCapture(
            loads: (0..<AerodynamicBodyPart.allCases.count).map {
                pointer[$0].coreValue
            },
            geometry: geometryReadback.contents()
                .assumingMemoryBound(to: GPUPreparedBirdGeometry.self)
                .pointee
        )
    }

    private func encodeReduction(
        commandBuffer: MTLCommandBuffer
    ) throws -> MTLBuffer {
        var input = reductionA
        var output = reductionB
        var inputCount = partialCount
        while inputCount > 1 {
            let outputCount = (inputCount + 255) / 256
            var count = UInt32(inputCount)
            guard let encoder = commandBuffer.makeComputeCommandEncoder()
            else {
                throw BirdFlowError.commandBufferFailed(
                    "Unable to reduce a bird-part load."
                )
            }
            encoder.setBuffer(input, offset: 0, index: 0)
            encoder.setBuffer(output, offset: 0, index: 1)
            encoder.setBytes(
                &count,
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
}

func makeAerodynamicPartLoadSample(
    step: UInt64,
    timeSeconds: Float,
    capture: BirdPartLoadCapture,
    reaction: GPUWingInertialReaction,
    productionTotal: ForceTorque
) -> AerodynamicPartLoadSample {
    let geometry = capture.geometry
    let body = partXYZ(geometry.bodyPosition)
    let leftHinge = partXYZ(geometry.leftRoot)
    let rightHinge = partXYZ(geometry.rightRoot)
    let references = [body, leftHinge, rightHinge, body]
    let parts = zip(AerodynamicBodyPart.allCases, capture.loads)
        .enumerated().map { index, pair in
            let reference = references[index]
            let load = pair.1
            return AerodynamicPartLoad(
                part: pair.0,
                loadAboutBodyCOM: load,
                referencePointMeters: reference,
                torqueAboutReferenceNewtonMeters:
                    load.torqueNewtonMeters
                    - cross(
                        reference - body,
                        load.forceNewtons
                    )
            )
        }
    let left = makeWingActuatorEffort(
        part: .leftWing,
        partLoad: parts[1],
        bodyPosition: body,
        angularVelocity: partXYZ(geometry.leftAngularVelocity),
        reactionForce: partXYZ(reaction.leftForce),
        reactionTorqueAboutBody: partXYZ(reaction.leftTorque)
    )
    let right = makeWingActuatorEffort(
        part: .rightWing,
        partLoad: parts[2],
        bodyPosition: body,
        angularVelocity: partXYZ(geometry.rightAngularVelocity),
        reactionForce: partXYZ(reaction.rightForce),
        reactionTorqueAboutBody: partXYZ(reaction.rightTorque)
    )
    let summed = parts.reduce(ForceTorque()) {
        ForceTorque(
            forceNewtons: $0.forceNewtons
                + $1.loadAboutBodyCOM.forceNewtons,
            torqueNewtonMeters: $0.torqueNewtonMeters
                + $1.loadAboutBodyCOM.torqueNewtonMeters
        )
    }
    let leftForce = parts[1].loadAboutBodyCOM.forceNewtons
    let rightForce = parts[2].loadAboutBodyCOM.forceNewtons
    let leftTorque = parts[1].torqueAboutReferenceNewtonMeters
    let rightTorque = parts[2].torqueAboutReferenceNewtonMeters
    return AerodynamicPartLoadSample(
        step: step,
        timeSeconds: timeSeconds,
        parts: parts,
        leftWingActuator: left,
        rightWingActuator: right,
        summedPartLoad: summed,
        productionTotalLoad: productionTotal,
        forceClosureResidualNewtons:
            summed.forceNewtons - productionTotal.forceNewtons,
        torqueClosureResidualNewtonMeters:
            summed.torqueNewtonMeters - productionTotal.torqueNewtonMeters,
        bilateralForceMirrorResidualNewtons: leftForce
            - SIMD3<Float>(rightForce.x, -rightForce.y, rightForce.z),
        bilateralTorqueMirrorResidualNewtonMeters: leftTorque
            - SIMD3<Float>(-rightTorque.x, rightTorque.y, -rightTorque.z),
        bilateralActuatorPowerResidualWatts:
            left.signedMechanicalPowerWatts
            - right.signedMechanicalPowerWatts
    )
}

func makeAerodynamicPartLoadReport(
    deviceName: String,
    samples: [AerodynamicPartLoadSample],
    bilateralSymmetryExpected: Bool,
    maximumRelativeClosureResidual: Double = 0.005,
    maximumRelativeBilateralResidual: Double = 0.02
) -> AerodynamicPartLoadReport {
    func rms(_ values: [SIMD3<Float>]) -> Double {
        sqrt(values.reduce(0.0) { total, value in
            total + Double(value.x * value.x + value.y * value.y
                + value.z * value.z)
        } / Double(max(values.count, 1)))
    }
    let totalForces = samples.map(\.productionTotalLoad.forceNewtons)
    let totalTorques = samples.map(\.productionTotalLoad.torqueNewtonMeters)
    let forceClosure = rms(samples.map(\.forceClosureResidualNewtons))
    let torqueClosure = rms(samples.map(\.torqueClosureResidualNewtonMeters))
    let partForceScale = rms(samples.flatMap {
        $0.parts.map(\.loadAboutBodyCOM.forceNewtons)
    })
    let partTorqueScale = rms(samples.flatMap {
        $0.parts.map(\.loadAboutBodyCOM.torqueNewtonMeters)
    })
    let forceReference = max(max(rms(totalForces), partForceScale), 1.0e-30)
    let torqueReference = max(
        max(rms(totalTorques), partTorqueScale),
        1.0e-30
    )
    let symmetryForce = rms(
        samples.map(\.bilateralForceMirrorResidualNewtons)
    )
    let symmetryTorque = rms(
        samples.map(\.bilateralTorqueMirrorResidualNewtonMeters)
    )
    let wingForceReference = max(
        rms(samples.flatMap {
            [
                $0.parts[1].loadAboutBodyCOM.forceNewtons,
                $0.parts[2].loadAboutBodyCOM.forceNewtons,
            ]
        }),
        1.0e-30
    )
    let wingTorqueReference = max(
        rms(samples.flatMap {
            [
                $0.parts[1].torqueAboutReferenceNewtonMeters,
                $0.parts[2].torqueAboutReferenceNewtonMeters,
            ]
        }),
        1.0e-30
    )
    let powerResidualRMS = sqrt(
        samples.reduce(0.0) {
            $0 + Double(
                $1.bilateralActuatorPowerResidualWatts
                    * $1.bilateralActuatorPowerResidualWatts
            )
        } / Double(max(samples.count, 1))
    )
    let powerReference = max(
        sqrt(
            samples.reduce(0.0) {
                $0 + 0.5 * (
                    Double($1.leftWingActuator.signedMechanicalPowerWatts
                        * $1.leftWingActuator.signedMechanicalPowerWatts)
                    + Double($1.rightWingActuator.signedMechanicalPowerWatts
                        * $1.rightWingActuator.signedMechanicalPowerWatts)
                )
            } / Double(max(samples.count, 1))
        ),
        1.0e-30
    )
    let relativeForceClosure = forceClosure / forceReference
    let relativeTorqueClosure = torqueClosure / torqueReference
    let relativeSymmetryForce = symmetryForce / wingForceReference
    let relativeSymmetryTorque = symmetryTorque / wingTorqueReference
    let relativePower = powerResidualRMS / powerReference
    let finite = samples.allSatisfy(partLoadSampleIsFinite)
    let closurePassed = finite
        && relativeForceClosure <= maximumRelativeClosureResidual
        && relativeTorqueClosure <= maximumRelativeClosureResidual
    let symmetryPassed = relativeSymmetryForce
            <= maximumRelativeBilateralResidual
        && relativeSymmetryTorque <= maximumRelativeBilateralResidual
        && relativePower <= maximumRelativeBilateralResidual
    let evaluatedSymmetry: Bool? = bilateralSymmetryExpected
        ? symmetryPassed
        : nil
    let passed = closurePassed && (evaluatedSymmetry ?? true)
    return AerodynamicPartLoadReport(
        schemaVersion: AerodynamicPartLoadReport.schemaVersion,
        deviceName: deviceName,
        steps: samples.count,
        partIdentityDefinition:
            "solid-mask IDs 1=body, 2=left wing, 3=right wing, 4=tail; each conservative link and cover/uncover impulse is attributed to its current or previous solid owner",
        actuatorDefinition:
            "required torque applied to each wing = -(aerodynamic torque about hinge + prescribed-wing inertial reaction torque on body shifted to hinge); signed power = required torque dot relative wing angular velocity",
        bilateralSymmetryExpected: bilateralSymmetryExpected,
        samples: samples,
        relativeRMSForceClosureResidual: relativeForceClosure,
        relativeRMSTorqueClosureResidual: relativeTorqueClosure,
        relativeRMSBilateralForceMirrorResidual: relativeSymmetryForce,
        relativeRMSBilateralTorqueMirrorResidual: relativeSymmetryTorque,
        relativeRMSBilateralActuatorPowerResidual: relativePower,
        maximumAllowedRelativeRMSClosureResidual:
            maximumRelativeClosureResidual,
        maximumAllowedRelativeRMSBilateralResidual:
            maximumRelativeBilateralResidual,
        finite: finite,
        closurePassed: closurePassed,
        bilateralSymmetryPassed: evaluatedSymmetry,
        passed: passed,
        scientificVerdict: passed
            ? (bilateralSymmetryExpected
                ? "per-part conservative loads close to production total; bilateral wing-load and actuator-effort symmetry passed"
                : "per-part conservative loads close to production total; bilateral symmetry was not requested")
            : "per-part load closure or requested bilateral actuator-effort symmetry failed"
    )
}

private func makeWingActuatorEffort(
    part: AerodynamicBodyPart,
    partLoad: AerodynamicPartLoad,
    bodyPosition: SIMD3<Float>,
    angularVelocity: SIMD3<Float>,
    reactionForce: SIMD3<Float>,
    reactionTorqueAboutBody: SIMD3<Float>
) -> WingActuatorEffort {
    let hinge = partLoad.referencePointMeters
    let reactionAtHinge = reactionTorqueAboutBody
        - cross(hinge - bodyPosition, reactionForce)
    let required = -(
        partLoad.torqueAboutReferenceNewtonMeters + reactionAtHinge
    )
    return WingActuatorEffort(
        part: part,
        hingeMeters: hinge,
        relativeAngularVelocityRadiansPerSecond: angularVelocity,
        aerodynamicTorqueAboutHingeNewtonMeters:
            partLoad.torqueAboutReferenceNewtonMeters,
        inertialReactionForceOnBodyNewtons: reactionForce,
        inertialReactionTorqueOnBodyAboutHingeNewtonMeters:
            reactionAtHinge,
        requiredActuatorTorqueOnWingNewtonMeters: required,
        signedMechanicalPowerWatts: dot(required, angularVelocity)
    )
}

private func partLoadSampleIsFinite(
    _ sample: AerodynamicPartLoadSample
) -> Bool {
    let vectors = sample.parts.flatMap {
        [
            $0.loadAboutBodyCOM.forceNewtons,
            $0.loadAboutBodyCOM.torqueNewtonMeters,
            $0.referencePointMeters,
            $0.torqueAboutReferenceNewtonMeters,
        ]
    } + [
        sample.forceClosureResidualNewtons,
        sample.torqueClosureResidualNewtonMeters,
        sample.leftWingActuator.requiredActuatorTorqueOnWingNewtonMeters,
        sample.rightWingActuator.requiredActuatorTorqueOnWingNewtonMeters,
    ]
    return sample.timeSeconds.isFinite
        && sample.leftWingActuator.signedMechanicalPowerWatts.isFinite
        && sample.rightWingActuator.signedMechanicalPowerWatts.isFinite
        && vectors.allSatisfy {
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }
}

private func partXYZ(_ value: SIMD4<Float>) -> SIMD3<Float> {
    SIMD3<Float>(value.x, value.y, value.z)
}

#endif

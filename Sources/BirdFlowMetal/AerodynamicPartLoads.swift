import BirdFlowCore
import Foundation

@frozen
public enum AerodynamicBodyPart: String, Codable, CaseIterable, Sendable {
    case body
    case leftWing
    case rightWing
    case tail

    var maskIdentifier: UInt32 {
        switch self {
        case .body: 1
        case .leftWing: 2
        case .rightWing: 3
        case .tail: 4
        }
    }
}
@frozen
public struct AerodynamicPartLoad: Codable, Sendable {
    public var part: AerodynamicBodyPart
    public var loadAboutBodyCOM: ForceTorque
    public var referencePointMeters: SIMD3<Float>
    public var torqueAboutReferenceNewtonMeters: SIMD3<Float>
}

/// Actuator-side wing effort. The required torque is the torque applied to
/// the wing; the archived inertial reaction is the opposite wrench applied to
/// the body by the prescribed motion.
@frozen
public struct WingActuatorEffort: Codable, Sendable {
    public var part: AerodynamicBodyPart
    public var hingeMeters: SIMD3<Float>
    public var relativeAngularVelocityRadiansPerSecond: SIMD3<Float>
    public var aerodynamicTorqueAboutHingeNewtonMeters: SIMD3<Float>
    public var inertialReactionForceOnBodyNewtons: SIMD3<Float>
    public var inertialReactionTorqueOnBodyAboutHingeNewtonMeters:
        SIMD3<Float>
    public var requiredActuatorTorqueOnWingNewtonMeters: SIMD3<Float>
    public var signedMechanicalPowerWatts: Float
}

@frozen
public struct AerodynamicPartLoadSample: Codable, Sendable {
    public var step: UInt64
    public var timeSeconds: Float
    public var parts: [AerodynamicPartLoad]
    public var leftWingActuator: WingActuatorEffort
    public var rightWingActuator: WingActuatorEffort
    public var summedPartLoad: ForceTorque
    public var productionTotalLoad: ForceTorque
    public var forceClosureResidualNewtons: SIMD3<Float>
    public var torqueClosureResidualNewtonMeters: SIMD3<Float>
    public var bilateralForceMirrorResidualNewtons: SIMD3<Float>
    public var bilateralTorqueMirrorResidualNewtonMeters: SIMD3<Float>
    public var bilateralActuatorPowerResidualWatts: Float
}

@frozen
public struct AerodynamicPartLoadReport: Codable, Sendable {
    public static let schemaVersion = 1

    public var schemaVersion: Int
    public var deviceName: String
    public var steps: Int
    public var partIdentityDefinition: String
    public var actuatorDefinition: String
    public var bilateralSymmetryExpected: Bool
    public var samples: [AerodynamicPartLoadSample]
    public var relativeRMSForceClosureResidual: Double
    public var relativeRMSTorqueClosureResidual: Double
    public var relativeRMSBilateralForceMirrorResidual: Double
    public var relativeRMSBilateralTorqueMirrorResidual: Double
    public var relativeRMSBilateralActuatorPowerResidual: Double
    public var maximumAllowedRelativeRMSClosureResidual: Double
    public var maximumAllowedRelativeRMSBilateralResidual: Double
    public var finite: Bool
    public var closurePassed: Bool
    public var bilateralSymmetryPassed: Bool?
    public var passed: Bool
    public var scientificVerdict: String
}

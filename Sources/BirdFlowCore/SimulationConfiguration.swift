import Foundation

public enum BirdFlowConfigurationError: Error, CustomStringConvertible, Equatable {
    case invalidGrid
    case invalidPhysicalScale(String)
    case latticeMachTooHigh(Float)
    case relaxationTooCloseToLimit(Float)
    case birdDoesNotFitDomain

    public var description: String {
        switch self {
        case .invalidGrid:
            return "Each grid dimension must be at least 16 cells and the total cell count must fit in UInt32."
        case .invalidPhysicalScale(let message):
            return message
        case .latticeMachTooHigh(let mach):
            return "The estimated lattice Mach number is \(mach); keep it at or below 0.15."
        case .relaxationTooCloseToLimit(let tau):
            return "The TRT symmetric relaxation time is \(tau); increase resolution, lower Reynolds number, or lower lattice reference speed."
        case .birdDoesNotFitDomain:
            return "The bird and its wing stroke do not fit inside the configured domain and sponge margin."
        }
    }
}

@frozen
public struct GridSize: Sendable, Equatable, Codable {
    public var x: Int
    public var y: Int
    public var z: Int

    public init(x: Int, y: Int, z: Int) throws {
        guard x >= 16, y >= 16, z >= 16 else {
            throw BirdFlowConfigurationError.invalidGrid
        }

        let (xy, xyOverflow) = Int64(x).multipliedReportingOverflow(by: Int64(y))
        let (count64, countOverflow) = xy.multipliedReportingOverflow(by: Int64(z))
        guard !xyOverflow,
              !countOverflow,
              count64 > 0,
              count64 <= Int64(UInt32.max) else {
            throw BirdFlowConfigurationError.invalidGrid
        }

        self.x = x
        self.y = y
        self.z = z
    }

    public var cellCount: Int { x * y * z }
}

@frozen
public struct LatticeScaling: Sendable, Equatable, Codable {
    public let cellSizeMeters: Float
    public let timeStepSeconds: Float
    public let latticeReferenceSpeed: Float
    public let latticeKinematicViscosity: Float
    public let tauPlus: Float
    public let tauMinus: Float
    public let omegaPlus: Float
    public let omegaMinus: Float
    public let velocityToLattice: Float
    public let velocityToPhysical: Float
    public let pressureScalePascals: Float
    public let forceToPhysical: Float
    public let torqueToPhysical: Float
    public let latticeMach: Float

    /// Density used to derive pressure, force, and torque conversion scales.
    public var physicalAirDensity: Float {
        pressureScalePascals / (velocityToPhysical * velocityToPhysical)
    }

    public init(
        characteristicLengthMeters: Float,
        characteristicLengthCells: Int,
        referenceSpeedMetersPerSecond: Float,
        targetReynoldsNumber: Float,
        physicalAirDensity: Float,
        latticeReferenceSpeed: Float = 0.05,
        trtMagicParameter: Float = 3.0 / 16.0
    ) throws {
        try self.init(
            characteristicLengthMeters: characteristicLengthMeters,
            characteristicLengthCells: characteristicLengthCells,
            referenceSpeedMetersPerSecond: referenceSpeedMetersPerSecond,
            targetReynoldsNumber: targetReynoldsNumber,
            physicalAirDensity: physicalAirDensity,
            latticeReferenceSpeed: latticeReferenceSpeed,
            trtMagicParameter: trtMagicParameter,
            minimumTauPlus: 0.500_05
        )
    }

    /// Constructs a deliberately sub-margin scaling for a package-owned,
    /// preregistered stability diagnostic. Production callers must use the
    /// public initializer and retain its `tauPlus >= 0.50005` guard.
    package static func diagnosticSubMargin(
        characteristicLengthMeters: Float,
        characteristicLengthCells: Int,
        referenceSpeedMetersPerSecond: Float,
        targetReynoldsNumber: Float,
        physicalAirDensity: Float,
        latticeReferenceSpeed: Float = 0.05,
        trtMagicParameter: Float = 3.0 / 16.0,
        minimumTauPlus: Float
    ) throws -> Self {
        guard minimumTauPlus > 0.5, minimumTauPlus < 0.500_05 else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "A diagnostic tau floor must be above 0.5 and below the production 0.50005 margin."
            )
        }
        return try Self(
            characteristicLengthMeters: characteristicLengthMeters,
            characteristicLengthCells: characteristicLengthCells,
            referenceSpeedMetersPerSecond: referenceSpeedMetersPerSecond,
            targetReynoldsNumber: targetReynoldsNumber,
            physicalAirDensity: physicalAirDensity,
            latticeReferenceSpeed: latticeReferenceSpeed,
            trtMagicParameter: trtMagicParameter,
            minimumTauPlus: minimumTauPlus
        )
    }

    private init(
        characteristicLengthMeters: Float,
        characteristicLengthCells: Int,
        referenceSpeedMetersPerSecond: Float,
        targetReynoldsNumber: Float,
        physicalAirDensity: Float,
        latticeReferenceSpeed: Float,
        trtMagicParameter: Float,
        minimumTauPlus: Float
    ) throws {
        guard characteristicLengthMeters > 0,
              characteristicLengthCells >= 8,
              referenceSpeedMetersPerSecond > 0,
              targetReynoldsNumber > 0,
              physicalAirDensity > 0,
              latticeReferenceSpeed > 0,
              trtMagicParameter > 0 else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "All physical and lattice scale values must be positive."
            )
        }

        let latticeMach = latticeReferenceSpeed / D3Q19.soundSpeed
        guard latticeMach <= 0.15 else {
            throw BirdFlowConfigurationError.latticeMachTooHigh(latticeMach)
        }

        let dx = characteristicLengthMeters / Float(characteristicLengthCells)
        let dt = latticeReferenceSpeed * dx / referenceSpeedMetersPerSecond
        let nuLattice = latticeReferenceSpeed
            * Float(characteristicLengthCells)
            / targetReynoldsNumber
        let tauPlus = 0.5 + 3 * nuLattice

        // This is a stability margin for a single-precision implementation, not
        // a claim that every case above the threshold is automatically stable.
        guard tauPlus >= minimumTauPlus else {
            throw BirdFlowConfigurationError.relaxationTooCloseToLimit(tauPlus)
        }

        let tauMinus = 0.5 + trtMagicParameter / (tauPlus - 0.5)
        let forceScale = physicalAirDensity * pow(dx, 4) / pow(dt, 2)

        self.cellSizeMeters = dx
        self.timeStepSeconds = dt
        self.latticeReferenceSpeed = latticeReferenceSpeed
        self.latticeKinematicViscosity = nuLattice
        self.tauPlus = tauPlus
        self.tauMinus = tauMinus
        self.omegaPlus = 1 / tauPlus
        self.omegaMinus = 1 / tauMinus
        self.velocityToLattice = dt / dx
        self.velocityToPhysical = dx / dt
        self.pressureScalePascals = physicalAirDensity * pow(dx / dt, 2)
        self.forceToPhysical = forceScale
        self.torqueToPhysical = forceScale * dx
        self.latticeMach = latticeMach
    }

    /// Converts lattice density to isothermal gauge pressure relative to
    /// `referenceDensity`, in pascals.
    @inlinable
    public func gaugePressurePascals(
        fromLatticeDensity density: Float,
        referenceDensity: Float = 1
    ) -> Float {
        D3Q19.soundSpeedSquared
            * (density - referenceDensity)
            * pressureScalePascals
    }
}

@frozen
public struct SimulationConfiguration: Sendable, Equatable, Codable {
    public var grid: GridSize
    public var domainOriginMeters: SIMD3<Float>
    public var scaling: LatticeScaling
    public var physicalAirDensity: Float
    public var farFieldVelocityMetersPerSecond: SIMD3<Float>
    public var spongeWidthCells: Int
    public var spongeStrength: Float
    public var freeFlight: Bool
    /// Number of rigid-body updates performed under each fluid-step load.
    /// Increasing this refines only the six-DOF integrator; fluid `dx`, fluid
    /// `dt`, geometry timing, and force evaluation remain unchanged.
    public var bodySubsteps: Int
    public var gravityMetersPerSecondSquared: SIMD3<Float>
    public var fastMath: Bool

    public init(
        grid: GridSize,
        domainOriginMeters: SIMD3<Float>,
        scaling: LatticeScaling,
        physicalAirDensity: Float = 1.225,
        farFieldVelocityMetersPerSecond: SIMD3<Float> = .zero,
        spongeWidthCells: Int = 12,
        spongeStrength: Float = 0.08,
        freeFlight: Bool = false,
        bodySubsteps: Int = 1,
        gravityMetersPerSecondSquared: SIMD3<Float> = SIMD3<Float>(0, 0, -9.80665),
        fastMath: Bool = false
    ) throws {
        guard physicalAirDensity > 0,
              abs(scaling.physicalAirDensity - physicalAirDensity)
                <= max(1e-6, physicalAirDensity * 1e-5),
              spongeWidthCells >= 4,
              spongeWidthCells * 2 < min(grid.x, min(grid.y, grid.z)),
              spongeStrength >= 0,
              spongeStrength <= 1,
              (1...64).contains(bodySubsteps) else {
            throw BirdFlowConfigurationError.invalidPhysicalScale(
                "Air density must match the lattice scaling density, sponge settings must remain inside their valid ranges, and bodySubsteps must be in 1...64."
            )
        }

        let farFieldLatticeSpeed = vectorLength(farFieldVelocityMetersPerSecond)
            * scaling.velocityToLattice
        let farFieldMach = farFieldLatticeSpeed / D3Q19.soundSpeed
        guard farFieldMach <= 0.15 else {
            throw BirdFlowConfigurationError.latticeMachTooHigh(farFieldMach)
        }

        self.grid = grid
        self.domainOriginMeters = domainOriginMeters
        self.scaling = scaling
        self.physicalAirDensity = physicalAirDensity
        self.farFieldVelocityMetersPerSecond = farFieldVelocityMetersPerSecond
        self.spongeWidthCells = spongeWidthCells
        self.spongeStrength = spongeStrength
        self.freeFlight = freeFlight
        self.bodySubsteps = bodySubsteps
        self.gravityMetersPerSecondSquared = gravityMetersPerSecondSquared
        self.fastMath = fastMath
    }

    public var domainSizeMeters: SIMD3<Float> {
        SIMD3<Float>(Float(grid.x), Float(grid.y), Float(grid.z))
            * scaling.cellSizeMeters
    }

    private enum CodingKeys: String, CodingKey {
        case grid
        case domainOriginMeters
        case scaling
        case physicalAirDensity
        case farFieldVelocityMetersPerSecond
        case spongeWidthCells
        case spongeStrength
        case freeFlight
        case bodySubsteps
        case gravityMetersPerSecondSquared
        case fastMath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            grid: container.decode(GridSize.self, forKey: .grid),
            domainOriginMeters: container.decode(
                SIMD3<Float>.self,
                forKey: .domainOriginMeters
            ),
            scaling: container.decode(LatticeScaling.self, forKey: .scaling),
            physicalAirDensity: container.decode(
                Float.self,
                forKey: .physicalAirDensity
            ),
            farFieldVelocityMetersPerSecond: container.decode(
                SIMD3<Float>.self,
                forKey: .farFieldVelocityMetersPerSecond
            ),
            spongeWidthCells: container.decode(
                Int.self,
                forKey: .spongeWidthCells
            ),
            spongeStrength: container.decode(Float.self, forKey: .spongeStrength),
            freeFlight: container.decode(Bool.self, forKey: .freeFlight),
            bodySubsteps: container.decodeIfPresent(
                Int.self,
                forKey: .bodySubsteps
            ) ?? 1,
            gravityMetersPerSecondSquared: container.decode(
                SIMD3<Float>.self,
                forKey: .gravityMetersPerSecondSquared
            ),
            fastMath: container.decode(Bool.self, forKey: .fastMath)
        )
    }
}

import BirdFlowCore
import Testing

@Test
func scalingPreservesRequestedReynoldsNumber() throws {
    let scaling = try LatticeScaling(
        characteristicLengthMeters: 0.15,
        characteristicLengthCells: 24,
        referenceSpeedMetersPerSecond: 10,
        targetReynoldsNumber: 6_000,
        physicalAirDensity: 1.225,
        latticeReferenceSpeed: 0.04
    )

    let reconstructed = scaling.latticeReferenceSpeed
        * 24
        / scaling.latticeKinematicViscosity
    #expect(abs(reconstructed - 6_000) < 0.01)
    #expect(abs(scaling.velocityToLattice * 10 - 0.04) < 1e-7)
    #expect(scaling.latticeMach < 0.15)
    #expect(scaling.tauPlus > 0.5)
    #expect(scaling.tauMinus > 0.5)
}

@Test
func highLatticeMachIsRejected() {
    #expect(throws: BirdFlowConfigurationError.self) {
        _ = try LatticeScaling(
            characteristicLengthMeters: 0.15,
            characteristicLengthCells: 24,
            referenceSpeedMetersPerSecond: 10,
            targetReynoldsNumber: 1_000,
            physicalAirDensity: 1.225,
            latticeReferenceSpeed: 0.2
        )
    }
}

@Test
func pressureConversionUsesIsothermalEquationOfState() throws {
    let scaling = try LatticeScaling(
        characteristicLengthMeters: 0.15,
        characteristicLengthCells: 24,
        referenceSpeedMetersPerSecond: 10,
        targetReynoldsNumber: 6_000,
        physicalAirDensity: 1.225,
        latticeReferenceSpeed: 0.04
    )

    #expect(abs(scaling.gaugePressurePascals(fromLatticeDensity: 1)) < 1e-7)
    let expected = D3Q19.soundSpeedSquared
        * 0.01
        * scaling.pressureScalePascals
    #expect(
        abs(
            scaling.gaugePressurePascals(fromLatticeDensity: 1.01)
                - expected
        ) < 1e-3
    )
}

@Test
func gridOverflowIsRejectedWithoutTrapping() {
    #expect(throws: BirdFlowConfigurationError.self) {
        _ = try GridSize(x: Int.max, y: 16, z: 16)
    }
}

@Test
func configurationRejectsDensityThatDiffersFromScaling() throws {
    let scaling = try LatticeScaling(
        characteristicLengthMeters: 0.1,
        characteristicLengthCells: 16,
        referenceSpeedMetersPerSecond: 4,
        targetReynoldsNumber: 1_000,
        physicalAirDensity: 1.225,
        latticeReferenceSpeed: 0.04
    )
    let grid = try GridSize(x: 48, y: 48, z: 48)

    #expect(throws: BirdFlowConfigurationError.self) {
        _ = try SimulationConfiguration(
            grid: grid,
            domainOriginMeters: .zero,
            scaling: scaling,
            physicalAirDensity: 1.0,
            spongeWidthCells: 4
        )
    }
}

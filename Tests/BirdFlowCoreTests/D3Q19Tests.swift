import BirdFlowCore
import Testing

@Test
func equilibriumRecoversDensityAndVelocity() {
    let rho: Float = 1.037
    let velocity = SIMD3<Float>(0.041, -0.017, 0.009)
    let populations = D3Q19.equilibrium(density: rho, velocity: velocity)
    let moments = D3Q19.moments(of: populations)

    #expect(abs(moments.density - rho) < 1e-6)
    #expect(vectorLength(moments.velocity - velocity) < 1e-6)
}

@Test
func trtLeavesEquilibriumUnchanged() {
    let rho: Float = 0.996
    let velocity = SIMD3<Float>(0.025, 0.006, -0.013)
    let equilibrium = D3Q19.equilibrium(density: rho, velocity: velocity)
    let collided = D3Q19.trtCollision(
        populations: equilibrium,
        density: rho,
        velocity: velocity,
        omegaPlus: 1.7,
        omegaMinus: 0.31
    )

    for q in 0..<D3Q19.count {
        #expect(abs(collided[q] - equilibrium[q]) < 1e-7)
    }
}

@Test
func directionsAndOppositesAreConsistent() {
    for q in 0..<D3Q19.count {
        let opposite = D3Q19.opposite[q]
        #expect(D3Q19.opposite[opposite] == q)
        let d = D3Q19.directions[q]
        #expect(
            D3Q19.directions[opposite]
                == SIMD3<Int32>(-d.x, -d.y, -d.z)
        )
        #expect(D3Q19.weights[opposite] == D3Q19.weights[q])
    }
}

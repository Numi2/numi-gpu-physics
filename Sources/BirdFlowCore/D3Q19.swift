import Foundation

public enum D3Q19 {
    public static let count = 19
    public static let soundSpeedSquared: Float = 1.0 / 3.0
    public static let soundSpeed: Float = sqrt(soundSpeedSquared)

    public static let directions: [SIMD3<Int32>] = [
        SIMD3<Int32>(0, 0, 0),
        SIMD3<Int32>(1, 0, 0), SIMD3<Int32>(-1, 0, 0),
        SIMD3<Int32>(0, 1, 0), SIMD3<Int32>(0, -1, 0),
        SIMD3<Int32>(0, 0, 1), SIMD3<Int32>(0, 0, -1),
        SIMD3<Int32>(1, 1, 0), SIMD3<Int32>(-1, -1, 0),
        SIMD3<Int32>(1, -1, 0), SIMD3<Int32>(-1, 1, 0),
        SIMD3<Int32>(1, 0, 1), SIMD3<Int32>(-1, 0, -1),
        SIMD3<Int32>(1, 0, -1), SIMD3<Int32>(-1, 0, 1),
        SIMD3<Int32>(0, 1, 1), SIMD3<Int32>(0, -1, -1),
        SIMD3<Int32>(0, 1, -1), SIMD3<Int32>(0, -1, 1)
    ]

    public static let weights: [Float] = [
        1.0 / 3.0,
        1.0 / 18.0, 1.0 / 18.0,
        1.0 / 18.0, 1.0 / 18.0,
        1.0 / 18.0, 1.0 / 18.0,
        1.0 / 36.0, 1.0 / 36.0,
        1.0 / 36.0, 1.0 / 36.0,
        1.0 / 36.0, 1.0 / 36.0,
        1.0 / 36.0, 1.0 / 36.0,
        1.0 / 36.0, 1.0 / 36.0,
        1.0 / 36.0, 1.0 / 36.0
    ]

    public static let opposite: [Int] = [
        0,
        2, 1,
        4, 3,
        6, 5,
        8, 7,
        10, 9,
        12, 11,
        14, 13,
        16, 15,
        18, 17
    ]

    @inlinable
    public static func equilibrium(
        direction q: Int,
        density rho: Float,
        velocity u: SIMD3<Float>
    ) -> Float {
        let c = directions[q]
        let cf = SIMD3<Float>(Float(c.x), Float(c.y), Float(c.z))
        let cu = dot(cf, u)
        let u2 = dot(u, u)
        return weights[q] * rho * (1 + 3 * cu + 4.5 * cu * cu - 1.5 * u2)
    }

    public static func equilibrium(
        density rho: Float,
        velocity u: SIMD3<Float>
    ) -> [Float] {
        (0..<count).map { equilibrium(direction: $0, density: rho, velocity: u) }
    }

    public static func moments(
        of populations: [Float]
    ) -> (density: Float, velocity: SIMD3<Float>) {
        precondition(populations.count == count)
        var rho: Float = 0
        var momentum = SIMD3<Float>.zero

        for q in 0..<count {
            let population = populations[q]
            let c = directions[q]
            rho += population
            momentum += SIMD3<Float>(Float(c.x), Float(c.y), Float(c.z)) * population
        }

        return (rho, rho > 0 ? momentum / rho : .zero)
    }

    public static func trtCollision(
        populations: [Float],
        density rho: Float,
        velocity u: SIMD3<Float>,
        omegaPlus: Float,
        omegaMinus: Float
    ) -> [Float] {
        precondition(populations.count == count)
        let eq = equilibrium(density: rho, velocity: u)
        var output = Array(repeating: Float.zero, count: count)

        for q in 0..<count {
            let qo = opposite[q]
            let fPlus = 0.5 * (populations[q] + populations[qo])
            let fMinus = 0.5 * (populations[q] - populations[qo])
            let eqPlus = 0.5 * (eq[q] + eq[qo])
            let eqMinus = 0.5 * (eq[q] - eq[qo])

            output[q] = populations[q]
                - omegaPlus * (fPlus - eqPlus)
                - omegaMinus * (fMinus - eqMinus)
        }

        return output
    }
}

import Foundation

@inlinable
public func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
    a.x * b.x + a.y * b.y + a.z * b.z
}

@inlinable
public func cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    SIMD3<Float>(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    )
}

@inlinable
public func squaredLength(_ v: SIMD3<Float>) -> Float {
    dot(v, v)
}

@inlinable
public func vectorLength(_ v: SIMD3<Float>) -> Float {
    sqrt(squaredLength(v))
}

@inlinable
public func normalizedVector(
    _ v: SIMD3<Float>,
    fallback: SIMD3<Float> = SIMD3<Float>(1, 0, 0)
) -> SIMD3<Float> {
    let magnitude = vectorLength(v)
    return magnitude > 1e-12 ? v / magnitude : fallback
}

@frozen
public struct Quaternion: Sendable, Equatable, Codable {
    public var vector: SIMD3<Float>
    public var scalar: Float

    @inlinable
    public init(vector: SIMD3<Float>, scalar: Float) {
        self.vector = vector
        self.scalar = scalar
    }

    @inlinable
    public init(x: Float, y: Float, z: Float, w: Float) {
        self.init(vector: SIMD3<Float>(x, y, z), scalar: w)
    }

    public static let identity = Quaternion(vector: .zero, scalar: 1)

    @inlinable
    public static func axisAngle(axis: SIMD3<Float>, angle: Float) -> Quaternion {
        let halfAngle = 0.5 * angle
        let n = normalizedVector(axis)
        return Quaternion(vector: n * sin(halfAngle), scalar: cos(halfAngle))
    }

    @inlinable
    public var conjugate: Quaternion {
        Quaternion(vector: -vector, scalar: scalar)
    }

    @inlinable
    public var normalized: Quaternion {
        let magnitude = sqrt(dot(vector, vector) + scalar * scalar)
        guard magnitude > 1e-12 else { return .identity }
        return Quaternion(vector: vector / magnitude, scalar: scalar / magnitude)
    }

    @inlinable
    public static func * (lhs: Quaternion, rhs: Quaternion) -> Quaternion {
        Quaternion(
            vector: lhs.scalar * rhs.vector
                + rhs.scalar * lhs.vector
                + cross(lhs.vector, rhs.vector),
            scalar: lhs.scalar * rhs.scalar - dot(lhs.vector, rhs.vector)
        )
    }

    @inlinable
    public func rotate(_ point: SIMD3<Float>) -> SIMD3<Float> {
        let t = 2 * cross(vector, point)
        return point + scalar * t + cross(vector, t)
    }

    @inlinable
    public func unrotate(_ point: SIMD3<Float>) -> SIMD3<Float> {
        conjugate.rotate(point)
    }

    @inlinable
    public var simd4: SIMD4<Float> {
        SIMD4<Float>(vector.x, vector.y, vector.z, scalar)
    }

    @inlinable
    public init(simd4: SIMD4<Float>) {
        self.init(x: simd4.x, y: simd4.y, z: simd4.z, w: simd4.w)
    }
}

@inlinable
public func radians(_ degrees: Float) -> Float {
    degrees * .pi / 180
}

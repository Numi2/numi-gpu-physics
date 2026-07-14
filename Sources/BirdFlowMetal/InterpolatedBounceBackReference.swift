import Foundation

struct MovingDomainNeighborStencil {
    let directionFromUncoveredCell: SIMD3<Double>
    let oldSolidOutgoing: Double
    let suppressedNeighborIncoming: Double
}

/// CPU reference for the link-wise interpolated moving-boundary rule used by
/// `stepFluidTRT`. It keeps canonical tests independent of the Metal compiler.
enum InterpolatedBounceBackReference {
    static func linkFraction(
        fluidImplicit: Double,
        solidImplicit: Double
    ) -> Double {
        precondition(fluidImplicit > 0)
        precondition(solidImplicit <= 0)
        return min(
            max(
                fluidImplicit / (fluidImplicit - solidImplicit),
                1.0e-4
            ),
            1
        )
    }

    static func population(
        linkFraction q: Double,
        reflected: Double,
        fartherOutgoing: Double,
        previousIncoming: Double,
        movingWallCorrection: Double
    ) -> Double {
        precondition(q > 0 && q <= 1)
        if q <= 0.5 {
            return 2 * q * reflected
                + (1 - 2 * q) * fartherOutgoing
                + movingWallCorrection
        }
        return (reflected + movingWallCorrection) / (2 * q)
            + (2 * q - 1) * previousIncoming / (2 * q)
    }

    static func conservativeCoveredBodyImpulse(
        previousFluidMomentum: SIMD3<Double>
    ) -> SIMD3<Double> {
        previousFluidMomentum
    }

    static func conservativeUncoveredBodyImpulse(
        refillMomentum: SIMD3<Double>,
        persistentNeighborStencils: [MovingDomainNeighborStencil]
    ) -> SIMD3<Double> {
        persistentNeighborStencils.reduce(-refillMomentum) {
            partial, stencil in
            partial - (
                stencil.oldSolidOutgoing
                    + stencil.suppressedNeighborIncoming
            ) * stencil.directionFromUncoveredCell
        }
    }
}

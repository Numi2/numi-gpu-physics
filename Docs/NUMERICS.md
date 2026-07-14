# Numerical formulation

## Physical regime

BirdFlowMetal is formulated for low-Mach external aerodynamics. It uses an isothermal, weakly compressible lattice Boltzmann model. Configuration rejects an initial estimated lattice Mach number above 0.15, including far-field translation, prescribed wing-tip motion, and initial rigid-body motion. The current GPU loop does not re-evaluate this guard after free-flight acceleration.

For characteristic length `L`, reference speed `U`, target Reynolds number `Re`, and `N` cells across `L`:

```text
nu_physical = U L / Re
nu_lattice  = U_l N / Re
dx = L / N
dt = U_l dx / U
```

## D3Q19 state

Each cell stores 19 distribution populations `f_q`. Macroscopic state is recovered as:

```text
rho = sum_q f_q
rho u = sum_q f_q c_q
p_lattice = c_s^2 rho
c_s^2 = 1/3
```

The equilibrium distribution is:

```text
f_q^eq = w_q rho [1 + 3(c_q·u) + 4.5(c_q·u)^2 - 1.5(u·u)]
```

Buffers are direction-major:

```text
f[q * cellCount + cell]
```

## TRT collision

For each opposite-direction pair:

```text
f+ = (f_q + f_opposite)/2
f- = (f_q - f_opposite)/2

f'_q = f_q
       - omegaPlus  (f+ - f+eq)
       - omegaMinus (f- - f-eq)
```

Viscosity is controlled by:

```text
tauPlus = 0.5 + 3 nu_lattice
omegaPlus = 1 / tauPlus
```

The antisymmetric relaxation uses:

```text
(tauPlus - 0.5)(tauMinus - 0.5) = 3/16
omegaMinus = 1 / tauMinus
```

## Streaming and far field

The main kernel uses pull streaming. Each fluid cell reads the population arriving from `cell - c_q`. In bird cases, sources outside the domain are supplied with far-field equilibrium and a quadratic sponge in the outer band relaxes post-collision populations toward that state. Canonical harnesses can select periodic wrapping while disabling sponge relaxation and retaining the same `stepFluidTRT` streaming and TRT collision implementation. A periodically wrapped source is still tested against the solid mask after wrapping; this is essential when an x/z edge link also lands on a planar y wall.

The moving-wall harness represents the first and last y planes as stationary lower and driven upper solid parts. A plane-sized update kernel changes only upper-wall velocity each step. The production fluid kernel performs halfway moving-wall bounce-back, while its existing deterministic load reduction can select the upper-wall part for comparison with analytic transient-Couette and finite-gap Stokes shear force. Bird runs leave the selection value zero and continue to reduce loads from every body part.

The fixed-sphere harness represents the curved surface with the same byte-mask occupancy and halfway-link bounce-back used by the bird. A sphere-specific initialization kernel writes both static masks, wall velocities, populations, density, and velocity in one coalesced volume pass; it does not introduce an alternate collision, streaming, boundary, or force operator. The production fluid kernel selects part 1 for sphere-only momentum exchange. Nonperiodic far-field populations and the quadratic sponge remain active, exercising the external-flow boundary path that the planar periodic cases intentionally bypass.

The fixed-wing harness uses the same static-canonical orchestration and production operators. Its initializer writes an axis-aligned, one-cell-thick rectangular part-1 surface in one volume pass. The incoming velocity is inclined by the angle of attack, and reported lift/drag are projections normal and parallel to that stream. This avoids diagonal voxel-mask aliasing while preserving the relative wing/flow orientation of the unbounded canonical problem.

The prescribed flapping-wing harness evaluates the Li--Nabawy `Re=100`, `AR=3` beta planform. A one-thread preparation kernel evaluates the piecewise stroke and pitch waveforms once per timestep. The volume kernel then consumes the prepared orthonormal frame, rejects cells outside a conservative wing sphere and radial/normal slabs, and evaluates the beta-function `pow` only for the small remaining candidate set. The analytic thickness is `0.05c`, regularized to at least one lattice cell. This path intentionally rotates the voxel surface through the lattice; unlike the fixed-wing harness, it does not avoid diagonal mask aliasing.

The prescribed-wing input audit independently integrates the analytic beta planform and kinematics on CPU, then compares a Double-precision CPU voxel predicate with the production Float32 Metal mask and wall velocity. At 8, 12, and 16 cells per chord the two implementations match cell-for-cell, but the phase-`0.25` occupied-volume ratios relative to the continuous regularized wing are `1.40625`, `1.39815`, and `0.71354`; relative to the published 5%-chord wing they are `3.51563`, `2.33025`, and `0.89193`. This separates coarse thickness regularization and orientation/parity limitations of binary occupancy from any host/GPU formula discrepancy. Consequently, small force changes on that ladder do not establish geometric convergence; a link-distance or other sub-grid moving-boundary representation is required before quantitative flapping acceptance.

## Moving bird boundary

One GPU thread first prepares the normalized body pose and both articulated wing frames for the timestep. The geometry kernel dispatches over the Cartesian grid, rejects cells outside a conservative body-centered bound unless they were solid at the previous step, and evaluates the detailed signed-distance functions only inside that region. It writes wall velocity and a byte mask whose value is zero for fluid or `1...4` for body, left wing, right wing, or tail.

Rigid-body surface velocity is:

```text
v(point) = v_center + omega_world × (point - center)
```

Wing points add stroke and pitch angular velocity about each wing root.

When pull streaming encounters a solid source cell, moving-wall halfway bounce-back reconstructs the incoming population. Previous and current occupancy masks make topology changes explicit. A newly uncovered cell is refilled from local moving-boundary equilibrium. A newly covered cell transfers the difference between its previous fluid momentum and the stored moving-solid equilibrium to the body-load reduction.

## Force and torque

Each fluid–solid link produces momentum exchange. For moving walls, incoming and reflected population momenta are evaluated relative to the local wall velocity; the expression reduces exactly to conventional momentum exchange for a stationary wall. This wall-frame form removes a known Galilean-frame bias without changing the moving-wall population reconstruction. The opposite of fluid momentum change is force on the bird. Lattice force is converted to newtons with:

```text
forceScale = rho0 dx^4 / dt^2
```

Fluid–solid link-exchange torque uses the halfway-link boundary point:

```text
torque = (boundaryPoint - center) × force
```

When a moving boundary newly covers a cell, its fluid-to-solid conversion impulse uses the cell center for the torque arm. This topology-change contribution is distinct from halfway-link exchange.

Each fluid threadgroup performs the first deterministic reduction level in threadgroup memory and writes one partial force/torque pair. Subsequent deterministic reduction passes produce one pair without floating-point atomics. The first level retains ascending cell-index summation order.

Coupled bird steps accumulate loads on every step because the rigid-body update consumes them. Static steady canonical cases only require the final load: a uniform flag disables boundary-load arithmetic, the threadgroup barrier, and the 256-lane first-level sum on intermediate steps. The final canonical step takes the unchanged deterministic path. Locked 8- and 16-cells-per-chord wing cases reproduced the pre-optimization coefficients exactly.

Phase-resolved flapping validation is a third mode: every step of the last two cycles executes the deterministic reduction and a one-thread kernel stores the reduced pair in a small cycle-history buffer. The CPU reads the buffer once per cycle and averages it into 100 phase bins. This avoids synchronizing for every load and prevents cell-cover/uncover impulses from being aliased by sparse point sampling. Density and velocity are still captured only at the five requested vortex phases.

Density and velocity are recovered before collision on every step because collision requires them. Their diagnostic buffers are written only on the final externally visible step of an `advance` call; initialization also populates them. On a captured step the kernel accumulates moments from the final post-collision, post-sponge populations, so readback is co-temporal with the stored fluid state, including inside the sponge band.

## Body dynamics

Free-flight translation uses semi-implicit Euler:

```text
v_next = v + (F/m + gravity) dt
x_next = x + v_next dt
```

Angular dynamics are evaluated in principal body axes:

```text
I domega/dt + omega × (I omega) = torque_body
```

The body-to-world quaternion is advanced from body angular velocity and normalized each step.

Fluid/body coupling is first-order staggered. For step `n -> n+1`, geometry uses body pose `n` with prescribed wing phase `n+1`, the fluid and load update runs, and the body is then integrated to pose `n+1`. A final snapshot therefore reports the updated body pose while the completed geometry/fluid boundary used the pre-integration torso pose. Body-step refinement and any stronger coupling scheme must account for this one-step lag.

Only the rigid torso mass and principal inertia are integrated. Prescribed wings are massless kinematic boundaries; hinge reactions, actuator work, and wing mass/inertia do not feed back into the body. A quantitative free-flight model must justify that approximation or add articulated-body reaction dynamics. It must also monitor evolving surface Mach number and domain/sponge clearance because the current validation guards apply only to the initial state.

## Derived pressure

For reference lattice density one, physical gauge pressure is:

```text
p_gauge = c_s^2 (rho - 1) rho0 (dx/dt)^2
```

Lift, drag, side force, and aerodynamic moments are projections of total force and torque onto selected axes.

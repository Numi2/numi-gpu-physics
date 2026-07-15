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

The prescribed flapping-wing harness evaluates the Li--Nabawy `Re=100`, `AR=3` beta planform. A one-thread preparation kernel evaluates the piecewise stroke and pitch waveforms once per timestep. The volume kernel then consumes the prepared orthonormal frame, rejects cells outside a conservative wing sphere and radial/normal slabs, and evaluates the beta-function `pow` only for the small remaining candidate set. The analytic thickness is `0.05c`, regularized to at least one lattice cell. For every solid-to-fluid D3Q19 link, a ten-iteration bracketed intersection locates the complete analytic beta-planform surface to below `0.001` lattice cell. The production fluid kernel applies the two-branch interpolated moving-wall reconstruction documented by Zhang et al. and reduces exactly to halfway bounce-back at `q=0.5`.

The prescribed-wing input audit independently integrates the analytic beta planform and kinematics on CPU, then compares a Double-precision CPU voxel predicate with the production Float32 Metal mask and wall velocity. It sparsely gathers the GPU link table and compares a deterministic sample of up to 1,024 links per phase with independent CPU bisection. The largest observed interpolated wall-position error on the 8/12/16 ladder is below `0.00071` cell, versus roughly `0.707` cell for the old halfway placement. The phase-`0.25` occupied-volume ratios remain `1.40625`, `1.39815`, and `0.71354` relative to the continuous regularized wing, and `3.51563`, `2.33025`, and `0.89193` relative to the published 5%-chord wing. Those raw center-occupancy counts remain useful aliasing diagnostics, but they are no longer used as the location of the hydrodynamic wall.

No production buffer was added for the link table. The geometry pass reuses direction slots belonging to current solid nodes, which streaming never consumes as fluid populations. Before a newly covered node is repurposed, its density and momentum are preserved in its existing macroscopic-velocity slot so the topology-change impulse remains intact. The input audit gathers only requested solid-link values rather than reading back the full `19*N` population allocation.

## Moving bird boundary

One GPU thread first prepares the normalized body pose and both articulated wing frames for the timestep. The geometry kernel dispatches over the Cartesian grid, rejects cells outside a conservative body-centered bound unless they were solid at the previous step, and evaluates the detailed signed-distance functions only inside that region. It writes wall velocity and a byte mask whose value is zero for fluid or `1...4` for body, left wing, right wing, or tail.

Rigid-body surface velocity is:

```text
v(point) = v_center + omega_world × (point - center)
```

Wing points add stroke and pitch angular velocity about each wing root.

When pull streaming encounters a solid source cell, moving-wall bounce-back reconstructs the incoming population. The procedural bird and existing planar/sphere/axis-aligned-wing canonical cases retain the halfway rule. The prescribed beta-wing benchmark selects link-distance interpolation: for `q <= 0.5` it blends the local reflected and next-fluid outgoing populations, while for `q > 0.5` it blends the corrected reflection with the previous local incoming population. Rigid wall velocity is evaluated at the same interpolated boundary point. Previous and current occupancy masks make topology changes explicit. A newly uncovered cell is refilled from local moving-boundary equilibrium. A newly covered cell transfers the difference between its preserved previous fluid momentum and the moving-solid equilibrium to the body-load reduction.

## Force and torque

Each fluid–solid link produces momentum exchange. For moving walls, incoming and reflected population momenta are evaluated relative to the local wall velocity; the expression reduces exactly to conventional momentum exchange for a stationary wall. This wall-frame form removes a known Galilean-frame bias without changing the moving-wall population reconstruction. The opposite of fluid momentum change is force on the bird. Lattice force is converted to newtons with:

```text
forceScale = rho0 dx^4 / dt^2
```

Fluid–solid link-exchange torque uses the reconstructed link boundary point (`q=0.5` for halfway cases and the analytic link fraction for the prescribed beta wing):

```text
torque = (boundaryPoint - center) × force
```

When a moving boundary newly covers a cell, its fluid-to-solid conversion impulse uses the cell center for the torque arm. This topology-change contribution is distinct from halfway-link exchange.

Each fluid threadgroup performs the first deterministic reduction level in threadgroup memory and writes one partial force/torque pair. Subsequent deterministic reduction passes produce one pair without floating-point atomics. The first level retains ascending cell-index summation order.

Coupled bird steps accumulate loads on every step because the rigid-body update consumes them. Static steady canonical cases only require the final load: a uniform flag disables boundary-load arithmetic, the threadgroup barrier, and the 256-lane first-level sum on intermediate steps. The final canonical step takes the unchanged deterministic path. Locked 8- and 16-cells-per-chord wing cases reproduced the pre-optimization coefficients exactly.

Phase-resolved flapping validation is a third mode: every step of the last two cycles executes the deterministic reduction and a one-thread kernel stores the reduced pair in a small cycle-history buffer. The CPU reads the buffer once per cycle and averages it into 100 phase bins. This avoids synchronizing for every load and prevents cell-cover/uncover impulses from being aliased by sparse point sampling. Density and velocity are still captured only at the five requested vortex phases.

The load-decomposition diagnostic repeats the same prescribed flow with a uniform selector in `caseParameters.x`: total, fluid-link exchange only, or cover/uncover conversion only. The selector gates load accumulation after streaming/geometry work and never changes populations, masks, or wall motion. Three independent runs therefore provide a non-tautological closure check without adding component buffers to the production Metal working set.

For the prescribed-wing force-law diagnostic, `caseParameters.y` is a dispatch-uniform estimator selector. Zero explicitly selects the legacy Galilean-invariant equation, `-(f_in(c-u_w) - f_out(-c-u_w))`; one selects conventional momentum exchange, `-(f_in+f_out)c`. Here `f_in` is already reconstructed by the same link-distance boundary rule, so the comparison changes only force evaluation, not the flow or wall location. All lanes take the same branch and no full-grid estimator buffer or additional readback is allocated. The conventional moving-body total is its link history plus the separately selected legacy cover/uncover history.

Diagnostic selector values two through five expose the algebraic link terms without changing populations: base reflection `-(2*f_out)c`, moving-wall population correction `-delta_f_wall*c`, interpolation residual `-(f_in-f_out-delta_f_wall)c`, and Galilean wall-frame correction `(f_in-f_out)u_w`. The first three close to conventional link exchange; all four close to Galilean-invariant link exchange. Each diagnostic repeats the flow using the existing reduction allocation.

The near-wing momentum diagnostic does not reuse any of those force expressions. Before geometry repurposes solid-node distribution slots, a validation-only Metal reduction records fluid momentum `P_n` and the signed post-collision population flux `Phi_out` through a fixed rectangular surface. After streaming and collision, a second reduction records `P_(n+1)`. The body-equivalent budget is `F_CV = -(P_(n+1)-P_n) - Phi_out + J_reservoir`, converted with the normal lattice-force scale. `J_reservoir` is required by moving occupancy: it returns the equilibrium momentum of newly uncovered cells and removes `rho_old*u_wall` deposited in newly covered solid cells. The latter density comes from the pre-geometry value already preserved for topology conversion, not from the link-force reduction. The control surface is checked for solid crossings and must lie at or beyond the sponge-free distance. These reductions are used only by validation harnesses (with compact history in the prescribed-wing case); the production coupled solver receives no additional dispatch or full-grid allocation.

Estimator selector six is the production conservative moving-domain equation. Persistent fluid–solid links use conventional population momentum exchange, which is the exact global balance for a fixed mask even when the reconstructed incoming population uses the farther-node or previous-incoming interpolation branch. A newly covered cell contributes its complete preserved old-fluid momentum. A newly uncovered cell contributes the negative refill momentum and, for every persistent-fluid neighbor, the negative sum of the old solid population streaming outward and the neighbor population whose streaming into the uncovered target was suppressed. Those are the actual terms added or removed by the fused population update. The estimator therefore closes against the raw `-(P_(n+1)-P_n)-Phi_out` budget; it deliberately excludes the separately reported virtual equilibrium-reservoir convention. Non-diagnostic coupled dispatches select mode six directly, and the prescribed-wing harness uses it by default. Selectors zero and one remain available for explicit legacy A/B diagnostics.

`Scripts/audit-flapping-coefficients.py` is intentionally independent of the Swift implementation. From the paper it derives `r2/R`, full-cycle travel at `r2`, rounded cycle steps, actual `U2`, and the single-wing area `S=AR*c^2`; it then applies `0.5*rho*U2^2*S` directly to the captured force vectors. Lift reconstructs exactly from the bin-averaged vertical force. Drag is reprojected at each bin center and is expected to differ slightly because the production path projects every step before binning. This audit allocates no Metal resources and reruns no flow history.

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

Demonstration and schema-1 prescribed wings remain explicit massless
kinematic boundaries. Schema 2 instead requires whole-bird reference mass and
inertia plus bilateral wing mass properties. The GPU computes the change in
each rigid prescribed wing's internal linear/angular momentum, adds the
opposite inertial hinge reaction to the body equation, and archives both sides.
Aerodynamic actuator effort remains unresolved until per-part aerodynamic
loads are exposed.

`bodySubsteps` performs `1...64` semi-implicit/quaternion updates under one
fluid-step load, so body integration can be refined without changing fluid
`dx` or `dt`. After every free-flight step a GPU ledger evaluates conservative
surface Mach and the rotated articulated bounding-box clearance outside the
sponge plus three stencil cells. It freezes the exact first violation and the
host stops before submitting another batch if Mach exceeds `0.15`, clearance
is negative, or state is non-finite.

The publication diagnostic `advanceWithCoupledMomentumLedger` deliberately
runs one fluid step per command buffer. It reduces `P(n+1)-P(n)` directly from
the two population fields with independent old/new occupancy masks, avoiding
loss of significance from subtracting two large far-field momenta. A second
compact reduction reconstructs open-boundary and sponge source impulses
without adding writes to `stepFluidTRT`; persistent solid links are separated
from the cover/uncover remainder. The gated identity is

```text
delta(P_fluid + M V_body + P_wing,relative)
    = I_far-field + I_sponge + I_gravity
```

and the independent force-side identity is

```text
I_aerodynamic + I_fluid-boundary = 0.
```

The diagnostic buffers are lazily allocated and ordinary batched stepping has
zero additional memory traffic or dispatches.

## Derived pressure

For reference lattice density one, physical gauge pressure is:

```text
p_gauge = c_s^2 (rho - 1) rho0 (dx/dt)^2
```

Lift, drag, side force, and aerodynamic moments are projections of total force and torque onto selected axes.

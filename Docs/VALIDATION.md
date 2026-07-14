# Validation protocol

Aerodynamic output is not accepted as quantitative until this sequence passes. Each case should archive configuration, commit, device, runtime, raw fields, and comparison plots.

## Current automated coverage

`Scripts/validate.sh` currently provides five gates:

- Swift algebra, scaling, rigid-body, and layout tests;
- live strict-math Metal moving-wing fixed-body and free-flight batch-partition regressions, plus CPU/GPU rigid-body one-step parity;
- an independent NumPy periodic shear-wave decay/convergence reference;
- a production-Metal periodic shear-wave refinement, cell-by-cell CPU comparison, population-mass, and command-buffer batch-invariance check; and
- offline compilation and linking of every Metal entry point.

This is a compilation and regression gate, not completion of the benchmark ladder below. Section 2 now runs on the production fluid kernel. Channel forcing, planar moving walls, and selectable canonical sphere/isolated-wing cases are still absent, so sections 3–6 require dedicated GPU case modes and comparison tooling. The procedural bird already contains finite wings, but that is not a canonical case harness.

## 1. Algebra and layout

```bash
swift test
python3 Scripts/static-audit.py
```

Acceptance:

- D3Q19 directions, opposites, and weights are consistent.
- Equilibrium moments recover prescribed density and velocity.
- TRT leaves equilibrium invariant.
- Swift and Metal shared structures have matching 16-byte layouts.
- Swift and Metal D3Q19 direction, weight, and opposite tables match.
- Swift pipeline names, Metal entry points, and named buffer contracts match the audited binding specification.

## 2. Periodic shear-wave decay

```bash
python3 Reference/shear_wave_reference.py
python3 Reference/shear_wave_convergence.py
swift run -c release birdflow validate shear-wave --resolution 32 --json
```

To archive the machine-readable report and final raw fields for all three grids:

```bash
swift run -c release birdflow validate shear-wave \
  --resolution 32 \
  --archive ValidationArtifacts/shear-wave-m4 \
  --json
```

The archive contains `report.json`, an encoding manifest, and little-endian Float32 density and interleaved XYZ velocity fields in x-fast cell order.

The analytic amplitude is:

```text
A(t) = A(0) exp(-nu k^2 t)
```

Independent Float64 reference acceptance:

- relative mass drift below `1e-6`
- relative decay error below `3%`
- convergence order at least `1.8`

Production strict-math Metal acceptance:

- actual population-mass drift below `5e-6` over the default 120-step finest case
- relative decay error below `3%`
- convergence order at least `1.8` over `16^3`, `24^3`, and `32^3`
- maximum cell-population difference below `5e-6` against the host CPU reference implementation over steps 1–8
- density and velocity differences below `1e-7` between stepwise and batched command-buffer execution

The Metal mass threshold is five parts per million because it measures the real single-precision distribution field; it is intentionally distinct from the Float64 NumPy threshold rather than hiding the observed GPU roundoff in diagnostic density.

## 3. Laminar channel flow

Use periodic streamwise boundaries, no-slip walls, and a small constant body force.

Acceptance:

- steady profile agrees with the parabolic analytic solution
- normalized L2 error decreases approximately quadratically
- flow rate agrees within `2%` at accepted resolution

## 4. Moving-wall verification

Use translating and oscillating planar walls.

Acceptance:

- no-penetration is satisfied
- tangential response agrees with the Stokes-layer solution
- integrated wall force has the correct phase and converges

## 5. Canonical body

Use a sphere and then a finite wing at documented Reynolds numbers.

Acceptance:

- mean drag lies within selected experimental or trusted numerical uncertainty
- symmetry is preserved under symmetric conditions
- force changes below `3%` between the two finest grids

For the included bird case, `birdflow --resolution-scale N` preserves physical domain size, geometry, Reynolds number, and sponge thickness by scaling the grid, chord cells, and sponge cells together. Multiply the number of timesteps by `N` to preserve physical duration. This supports a refinement run, but accepted convergence still requires archived fields, identical nondimensional sample times, and the canonical cases above.

## 6. Prescribed flapping wing

Use published rigid-wing geometry and kinematics.

Acceptance:

- phase-resolved lift and thrust reproduce timing and mean coefficients
- vortex topology is consistent at matching nondimensional times
- mean loads change below `5%` between the two finest grids

## 7. Complete measured bird

Import measured body/wing geometry and measured stroke, deviation, pitch, and twist histories.

Acceptance:

- for prescribed or trimmed periodic hovering/level flight, mean vertical force balances weight within study tolerance
- for prescribed or trimmed steady forward flight, mean thrust balances drag
- left/right loads agree for symmetric motion
- cycle statistics are stationary before reporting

## 8. Free flight

Enable six-degree-of-freedom coupling after prescribed-motion loads pass.

Acceptance:

- momentum balances close to recorded external impulse
- body-step refinement leaves trajectory unchanged within tolerance
- a trim case remains bounded without artificial pose stabilization
- evolving surface Mach number and domain/sponge clearance remain inside the validated limits, with the run aborted otherwise
- wing mass/inertia, hinge reactions, and actuator loads are either modeled or a massless-wing approximation is explicitly justified

Required harness work before these criteria are measurable:

- expose an independently adjustable body timestep or body substeps; `--resolution-scale` changes fluid `dx`, fluid `dt`, and the body step together and is not an isolated body-integrator refinement;
- archive a control-volume momentum budget including fluid momentum, far-field boundary flux, sponge impulse, bird load, gravity, and topology-conversion impulse; current CLI output does not expose the boundary/sponge terms; and
- compare constant-torque and torque-free asymmetric-body cases across the CPU and Metal integrators over multiple steps, in addition to the existing one-step parity regression.

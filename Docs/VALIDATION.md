# Validation protocol

Aerodynamic output is not accepted as quantitative until this sequence passes. Each case should archive configuration, commit, device, runtime, raw fields, and comparison plots.

## Current automated coverage

The repository currently provides eleven automated harnesses:

- Swift algebra, scaling, rigid-body, and layout tests;
- live strict-math Metal moving-wing fixed-body and free-flight batch-partition regressions, plus CPU/GPU rigid-body one-step parity;
- an independent NumPy periodic shear-wave decay/convergence reference;
- a production-Metal periodic shear-wave refinement, cell-by-cell CPU comparison, population-mass, and command-buffer batch-invariance check;
- production-Metal transient Couette and oscillating Stokes-layer profile, no-penetration, wall-force, phase, refinement, and batching checks;
- a production-Metal translating-sphere topology gate that closes cover/uncover force against an independent fluid-momentum budget;
- production-Metal fixed-sphere steady drag, curved-boundary symmetry, torque leakage, refinement, and batching checks;
- production-Metal fixed finite-wing lift/drag, symmetry, leakage, refinement, and batching checks;
- a production-Metal prescribed flapping-wing phase-load, periodicity, vortex-diagnostic, refinement, and batching gate;
- a two-flyer formation-flight gate with shared-fluid ownership, actuator power, matched isolated controls, and global load closure; and
- offline compilation and linking of every Metal entry point.

`Scripts/validate.sh` retains the compact local release gates; expensive
flapping, formation, measured-bird, and refinement studies remain explicit
local commands. Sections 2, 4, 5, and 6 all execute the production fluid and
momentum-exchange operators; section 3 still requires a forced-channel GPU
mode. The fixed-wing gate isolates axis-aligned load accuracy and does not
validate the procedural bird's geometry or kinematics. The accepted flapping
gate is the current evidence boundary for one rotating sub-cell moving surface;
the formation gate extends that accounting to two independently phased owners.

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

```bash
swift run -c release birdflow validate moving-wall --resolution 32 --json
```

To archive the report and final fields for both cases on all three grids:

```bash
swift run -c release birdflow validate moving-wall \
  --resolution 32 \
  --archive ValidationArtifacts/moving-wall-m4 \
  --json
```

The translating case starts from rest and is compared with the transient Couette series at `nu t / H^2 = 0.2`. The oscillating case uses the finite-gap complex Stokes solution with dimensionless angular frequency `omega H^2 / nu = 30`, six warmup cycles, and sixteen phase samples. Periodic x/z links that wrap onto a wall are required to execute the same moving-wall bounce-back as interior wall links.

Acceptance:

- normalized profile L2 error below `1%` on every grid
- oscillating-profile convergence order at least `1.5`
- isolated upper-wall momentum-exchange force error below `1%` on every grid
- translating and oscillating wall-force convergence order at least `1.0`
- oscillating force phase error below `0.01 rad`
- maximum cross-flow speed below `2e-6` lattice units
- density, velocity, and selected-wall force differences below `1e-7` between stepwise and batched execution

The transient Couette profile is already within `8e-5` on the coarsest grid and reaches a single-precision error floor, so its fitted profile order is reported but not used as a gate. Force convergence and the oscillating profile retain explicit order gates.

Topology-changing translation is a separate release gate because fixed masks
cannot exercise cover/uncover accounting:

```bash
swift run -c release birdflow validate translating-body --json
```

The case uses a `24^3` periodic quiescent domain, a radius-`3.25` voxel sphere,
wall speed `0.05`, and a 40-step trajectory spanning exactly two lattice cells.
A fixed control surface stays clear of the body. The report requires nonzero
cover and uncover counts, no solid/control-surface links, a maximum conservative
force residual at most `5e-4`, relative RMS residual at most `0.5%`, at least a
`5x` improvement over the legacy estimator, and identical raw budgets between
the two deterministic runs.

The Apple M4 acceptance run completed in `0.65 s`: 64 newly covered and 64
newly uncovered cell events occurred over 16 transition steps. Conservative RMS
residual was `3.6449e-5`, maximum residual was `8.3824e-5`, relative RMS was
`3.1759e-5`, and the improvement over legacy was `22020.8x`. The existing
three-grid Couette/Stokes test also passed after promotion. This canonical is a
fast force-accounting release gate, not an accuracy study of sphere drag.

## 5. Canonical body

The fixed-sphere production-Metal gate is available:

```bash
swift run -c release birdflow validate sphere --resolution 160 --json
```

To archive the report and final fields for all three grids:

```bash
swift run -c release birdflow validate sphere \
  --resolution 160 \
  --archive ValidationArtifacts/sphere-m4 \
  --json
```

The case uses uniform flow at `Re=100`, lattice speed `0.04`, and a fixed voxelized sphere in geometrically similar `10D x 6D x 6D` domains. The refinement ladder is `80 x 48 x 48`, `120 x 72 x 72`, and `160 x 96 x 96`, with 8, 12, and 16 cells across the diameter. The sphere center is 3D from the inlet, leaving 6.5D from its downstream surface to the outlet. One initialization kernel writes both masks, zero wall velocity, populations, density, and velocity; all subsequent evolution and loads use the production `stepFluidTRT` and deterministic reduction kernels.

The reference is `Cd=1.09` from the uniform-flow `Re=100` entry reported by [Bagchi and Balachandar, JFM 2002](https://electronicsandbooks.com/edt/manual/Magazine/J/Journal%20of%20Fluid%20Mechanics/2002%20Volume%20466/S0022112002001490.pdf). A later particle-resolved DNS validation used a cubic 30D domain and reported convergence from `Cd=1.16` at 15 cells per diameter to `1.096` at 31 and `1.091` at 61, demonstrating why this repository's smaller domain and 16-cell finest sphere must retain a wider engineering tolerance ([Homann et al., JFM 2016](https://www.cambridge.org/core/services/aop-cambridge-core/content/view/96C8D7F0210BB5029FD23A7168C290E8/S0022112016002287a.pdf/particle-resolved-direct-numerical-simulation-of-homogeneous-isotropic-turbulence-modified-by-small-fixed-spheres.pdf)).

Automated sphere acceptance:

- every grid reaches a load window whose drag range is at most `1%`; samples are separated by a grid-independent `0.16D/U`
- finest-grid drag is within `15%` of `Cd=1.09`
- drag changes by at most `3%` between the two finest grids
- side-force/drag and torque/(drag diameter) ratios remain below `1e-3`
- normalized mirrored-velocity error remains below `1e-3`
- density, velocity, and load differences remain below `1e-7` between stepwise and batched execution

The default Apple M4 run produced finest `Cd=1.2170706918439962` (`11.6579%` relative error), a finest-two drag change of `0.02885%`, normalized finest velocity-symmetry error `2.6488133134475767e-6`, and exactly zero batch differences. These establish a curved-body production regression; they do not establish publication-grade absolute sphere drag.

The fixed finite-wing production-Metal gate is also available:

```bash
swift run -c release birdflow validate wing --resolution 400 --json
```

To archive the report and final fields for all three grids:

```bash
swift run -c release birdflow validate wing \
  --resolution 400 \
  --archive ValidationArtifacts/wing-m4 \
  --json
```

The case follows the `Re=100`, aspect-ratio-2 rectangular flat plate at 30 degrees in [Taira and Colonius, JFM 2009](https://authors.library.caltech.edu/records/frnmk-28536). Figure 3 gives approximately `CL=0.75` and `CD=0.75` at `U*t/c=13`. The harness represents the nominally thin plate as an axis-aligned one-cell voxel surface and inclines the uniform stream by 30 degrees, which is equivalent to inclining the plate in an unbounded domain while avoiding resolution-dependent diagonal voxel aliasing.

The grid ladder is `240 x 240 x 144`, `320 x 320 x 192`, and `400 x 400 x 240`, with 24, 32, and 40 cells per chord and 48, 64, and 80 cells across the span. The domain is `10c x 10c x 6c`; the shorter spanwise extent and one-cell boundary regularization remain engineering limitations relative to the source study. Lattice speed is `0.08` (Mach `0.139`); a separate `0.04` calibration at 8–16 cells per chord changed coefficients by less than `0.5%`, while refinement changed lift materially, identifying boundary resolution rather than compressibility as the dominant error.

Automated wing acceptance:

- finest lift and drag are each within `20%` of the approximate published values
- lift and drag each change by at most `3%` between the two finest grids
- side-force ratio and roll/yaw moment coefficient remain below `1e-3`
- normalized span-mirrored velocity error remains below `1e-3`
- density, velocity, and load differences remain below `1e-7` between stepwise and batched execution

The accepted Apple M4 run produced `(CL, CD)` values of `(0.724617, 0.702652)`, `(0.747062, 0.705491)`, and `(0.761354, 0.707108)`. The finest result differs from the approximate reference by `1.514%` in lift and `5.719%` in drag. The 32-to-40-cells-per-chord changes are `1.877%` and `0.229%`; finest normalized span-symmetry error is `7.074e-7`; batch differences are exactly zero. The full ladder took `1569.51 s` and `9.17 GB` peak unified-memory footprint on Apple M4, so it is a release/calibration gate. The ordinary test suite instead locks an 8-cells-per-chord diagnostic in about two seconds.

For the included bird case, `birdflow --resolution-scale N` preserves physical domain size, geometry, Reynolds number, and sponge thickness by scaling the grid, chord cells, and sponge cells together. Multiply the number of timesteps by `N` to preserve physical duration. This supports a refinement run, but accepted convergence still requires archived fields, identical nondimensional sample times, and the canonical cases above.

## 6. Prescribed flapping wing

The implemented release case follows the open baseline in [Li and Nabawy, Insects 13, 459 (2022)](https://pmc.ncbi.nlm.nih.gov/articles/PMC9145969/):

```bash
swift run birdflow validate flapping-wing \
  --audit-inputs \
  --chord-cells 16 \
  --json
```

Run this preflight before the full fluid ladder. It independently reconstructs the normalized beta area, radial centroid and radius of gyration from gamma-function moments, integrates the stroke and pitch rates, and reconstructs the coefficient denominator. It also builds the analytic voxel predicate on CPU, compares occupancy and rigid wall velocity cell-by-cell with the production Metal geometry kernel, and compares a deterministic sample of up to 1,024 GPU link fractions per phase with independent CPU surface intersections at phases `0`, `0.125`, `0.25`, and `0.375`.

```bash
swift run -c release birdflow validate flapping-wing \
  --chord-cells 16 \
  --archive ValidationArtifacts/flapping-wing-m4 \
  --json
```

The case uses `Re=100`, `AR=3`, radial centroid `r1/R=0.5`, zero root offset, and the paper's beta planform. Ellington's relation gives `r2/R=0.5593218136` and `p=q=1.4891506584`. Thickness is `0.05c`, the pitch axis is `0.25c` behind the leading edge, stroke amplitude is 160 degrees (`phi=+/-80 degrees`), pitch amplitude is 90 degrees, and acceleration and pitch durations are each `0.25T`. The radius-of-gyration speed defines Reynolds number and force coefficients. The paper's three-million-cell, `dt/T=0.001` baseline reports fifth-cycle means `CL=1.460` and `CD=2.046`.

The compact uniform-grid ladder uses 8, 12, and 16 cells per chord in `10c x 10c x 8c` domains. It executes five cycles, records every reduced load of cycles four and five into a small GPU history buffer, and reports 100 phase bins without per-step CPU synchronization. At phases `4.55`, `4.65`, `4.75`, `4.85`, and `4.95`, it archives density, velocity, central-difference Q criterion, and vorticity fields. These correspond to the paper's LEV/TEV/tip-vortex ring formation, attached conical LEV, tube-like LEV/tip-vortex development, and late-half-stroke growth sequence. The Q archive makes that comparison possible, but the paper supplies qualitative vortex images rather than numeric Q thresholds, so automated acceptance checks capture completeness and finite positive-Q structure rather than claiming image-level topology agreement.

Scientific and operator acceptance gates are:

- analytic normalized area is one and the reconstructed `r1/R`, `r2/R`, stroke travel, pitch travel, and kinematic derivatives agree within their encoded `1e-8...1e-12` tolerances;
- CPU/Metal voxel mismatch is at most `1%`, solid-cell wall-velocity error is at most `1e-5`, voxel radial moments are within `0.04` of the analytic values, and audited link-wall position is within `0.10` cell and strictly closer than halfway placement;
- fifth-cycle mean lift and drag are each within `30%` of the tabulated source values;
- mean lift and drag each change by at most `5%` between the two finest grids;
- normalized half-stroke symmetry and fourth-to-fifth-cycle curve differences are each at most `15%`;
- midstroke mean lift is at least `1.0`, and half-stroke lift peaks fall in source-consistent phase windows `0.25...0.45` and `0.75...0.95`;
- all five Q/vorticity phase diagnostics are present and finite; and
- density, velocity, and load differences are below `1e-7` between stepwise and batched moving-boundary execution.

A one-grid diagnostic is available without assigning a verdict:

```bash
swift run birdflow validate flapping-wing \
  --single-chord-cells 8 \
  --cycles 5 \
  --json
```

The independent input fixture now passes every analytic and link-location gate. CPU and Metal masks match exactly at every audited phase, maximum wall-velocity disagreement is below `8.3e-9`, and the largest sampled link-wall error across the 8/12/16 ladder is below `0.00071` cell; fixed halfway placement reaches approximately `0.707` cell. At phase `0.25`, raw occupied volume relative to the one-cell-regularized wing remains `1.40625`, `1.39815`, and `0.71354`. Relative to the paper's actual 5%-chord thickness, the values remain `3.51563`, `2.33025`, and `0.89193`. These counts expose center-occupancy parity and thickness regularization, but the hydrodynamic boundary is now placed at the analytic sub-cell intersection instead of at each binary link midpoint.

The completed link-distance Apple M4 release ladder produced `(CL, CD)` means of `(7.45076, 9.58556)`, `(8.58688, 9.50008)`, and `(8.60733, 9.61182)` at 8, 12, and 16 cells per chord. The finest errors remain `489.54%` in lift and `369.79%` in drag. Relative to the previous halfway run, lift changed by only `+0.074%`, `+0.013%`, and `+0.069%`; drag changed by `-1.291%`, `-0.892%`, and `-0.652%`. The new wall location is therefore not the dominant source of the absolute load bias.

The 12-to-16-cell changes are `0.238%` in lift and `1.163%` in drag, finest half-stroke symmetry is `0.237%`, fourth-to-fifth-cycle difference is `0.210%`, all five vortex milestones are present, and batch density, velocity, and force differences are zero. Those repeatability/refinement gates pass. The finest lift peaks remain at phases `0.245` and `0.745`, `0.005T` before the locked windows, and the absolute coefficient gates fail. The `774 MB` archive completed in `634.61 s` with a `1.050 GB` peak memory footprint. This result narrows the next investigation to moving-boundary load accounting and phase-resolved force components rather than further tuning link placement.

Use the cheap component diagnostic before another ladder:

```bash
swift run birdflow validate flapping-wing \
  --decompose-loads \
  --single-chord-cells 8 \
  --cycles 1 \
  --json
```

It runs identical total, link-only, and cover/uncover-only fixed-kinematics histories. Because loads do not feed back into the prescribed flow, selection cannot alter the fluid solution. The Apple M4 diagnostic completed in `9.84 s` and closed total against the two independently selected components within `9.69e-6` lift coefficient and `1.96e-6` drag coefficient. Cover/uncover impulse supplied only `0.47%` of mean lift, `2.90%` of mean drag, `1.29%` of RMS lift, and `3.01%` of RMS drag. Link exchange supplied essentially all of the bias. Cell-conversion double counting is therefore not the dominant failure; the next targeted check is link-force evaluation and coefficient normalization.

Compare the two source-backed link-force equations before another ladder:

```bash
swift run birdflow validate flapping-wing \
  --compare-link-forces \
  --single-chord-cells 8 \
  --cycles 1 \
  --json
```

Interpolation reconstructs the boundary populations but does not create an independent third force equation. This diagnostic therefore compares Wen et al.'s Galilean-invariant equation with conventional momentum exchange evaluated on those same interpolated populations. It then combines conventional link exchange with the independently selected cover/uncover impulse to form the moving-body conventional total.

The Apple M4 run completed in `12.23 s`. Galilean-invariant total `(CL, CD)` was `(7.52805, 9.48616)`; conventional moving-body total was `(7.50904, 9.56192)`. Conventional/Galilean mean ratios were `0.99747` in lift and `1.00799` in drag. Maximum phase-resolved link differences were `0.17720` lift coefficient and `0.12919` drag coefficient, while the independently run Galilean-invariant total still closed against link plus topology within `9.69e-6` lift coefficient, `1.96e-6` drag coefficient, and `1.15e-6` force units. Relative mean errors versus the published target remained `415.62%/363.64%` for Galilean-invariant exchange and `414.32%/367.35%` for conventional exchange. The wall-velocity term is therefore not the dominant cause; investigate coefficient/reference scaling and momentum-exchange factors shared by both equations next.

Audit the coefficient denominator from the captured raw forces without another fluid run:

```bash
python3 Scripts/audit-flapping-coefficients.py \
  /tmp/birdflow-link-force-comparison.json \
  --output ValidationArtifacts/flapping-wing-coefficient-ledger.json
```

Li and Nabawy define `CL=2L/(rho U2^2 S)` and `CD=2D/(rho U2^2 S)`, where `U2` is the cycle-average wing speed at the radius of gyration and `S` is the single-wing planform area. An independent Python transcription gives `r2/R=0.5593218136`, full-cycle angular travel `5.5850536064 rad`, `2142` lattice steps, `U2=0.03500103431`, `S=192`, and coefficient denominator `0.11760695065887139` for the captured 8-cell case.

The median denominator inferred independently from the captured `forceZ/CL` values is exactly `0.11760695065887139`; its relative difference from the paper-derived value is zero at binary-double precision. Recomputed mean lift is identical to the stored values, with a maximum phase residual of `5.33e-15`. Reprojecting the 100 bin-averaged force vectors gives mean drag residuals of only `4.36e-4` and `4.24e-4`; this small approximation exists because production drag is projected per step before forces are binned. For the Galilean-invariant history, matching the published lift would require denominator `0.6064052`, while matching drag would require `0.5453031`, an `11.2%` disagreement; no single missing scalar can reconcile both. Coefficient normalization is cleared. The next short diagnostic should decompose the common link numerator into reflected-population base exchange, interpolation residual, and moving-wall population correction before another refinement ladder.

Run that link-numerator decomposition with:

```bash
swift run birdflow validate flapping-wing \
  --decompose-link-numerator \
  --single-chord-cells 8 \
  --cycles 1 \
  --json
```

Six identical prescribed histories independently select Galilean link exchange, conventional link exchange, base reflection, moving-wall population correction, interpolation residual, and the Galilean wall-frame correction. The latter four satisfy `F_GI = F_base + F_wall-population + F_interpolation + F_wall-frame`; the first three satisfy conventional exchange. Selection is dispatch-uniform and affects only load accumulation.

The Apple M4 diagnostic completed in `18.23 s`. Mean component `(CL, CD)` values were `(-6.75135, -62.26542)` for base reflection, `(14.71945, 72.26319)` for moving-wall population correction, `(-0.49416, -0.71106)` for interpolation residual, and `(0.01902, -0.07576)` for the Galilean wall-frame correction. They close to Galilean link exchange `(7.49296, 9.21095)` within `1.23e-5` lift coefficient, `7.14e-6` drag coefficient, and `1.55e-6` force units. Conventional closure is within `1.39e-5`, `6.03e-6`, and `1.65e-6`, respectively.

The moving-wall population term is `196.44%` of net mean link lift and `784.54%` of net mean link drag, opposed primarily by base reflection at `-90.10%` and `-675.99%`. Interpolation residual contributes only `-6.59%/-7.72%`, and the Galilean wall-frame term contributes `0.25%/-0.82%`. The dominant numerical sensitivity is therefore cancellation between moving-wall population correction and reflected populations. This decomposition localizes the next investigation but does not establish that the moving-wall formula itself is wrong; the next check should close the boundary force against an independently measured fluid-momentum budget at the same phases.

Run the independent near-wing momentum balance with:

```bash
swift run birdflow validate flapping-wing \
  --momentum-budget \
  --single-chord-cells 8 \
  --cycles 1 \
  --json
```

The fixed control volume spans `[6,74) x [6,74) x [29,54)` on the `80 x 80 x 64` grid. Its closest streaming link is five cells from a domain boundary, outside the four-cell sponge, and no solid link crosses its surface. Before geometry can overwrite newly covered population slots, the diagnostic records fluid momentum and the exact outer streaming flux; after the fluid step it records the new momentum and an independently reconstructed cover/uncover equilibrium-reservoir correction. Phasewise body-equivalent force is `-(P_(n+1)-P_n)-Phi_out+J_reservoir`.

On Apple M4 the original two-history check completed in `11.61 s`. Mean coefficient components were `(0.06746, 1.13119)` from negative storage, `(1.11346, 0.91814)` from negative outward flux, and `(-0.02317, 0.02298)` from the optional equilibrium-reservoir convention. Raw fluid storage plus flux gives `(CL, CD)=(1.18092, 2.04933)`; adding the reservoir convention gives `(1.15774, 2.07231)`. The same flow's conventional boundary load was `(7.50904, 9.56192)` and its Galilean-invariant load was `(7.52805, 9.48616)`. An alternate surface one cell farther out changed the adjusted budget means by only `6.04e-5` lift and `1.07e-5` drag coefficient.

The conservative moving-domain estimator uses conventional exchange for
persistent links, complete preserved momentum for newly covered cells, and the
refill plus suppressed/injected neighbor stencil for newly uncovered cells. It
produces mean `(CL, CD)=(1.18061, 2.04933)` against the raw fluid budget
`(1.18092, 2.04933)`. Maximum phase residuals are `0.0025111` lift coefficient,
`0.0002467` drag coefficient, and `0.0002954` force units, all below the
tightened `0.005` coefficient tolerance. Its correction relative to the legacy
conventional total is `(-6.32843, -7.51260)` in mean coefficient.

The independent translating-body topology canonical and existing three-grid
Couette/Stokes moving-wall canonical both pass after selecting mode six as the
production default. A short 8-cell, one-cycle run through the normal flapping
CLI path produces `(CL, CD)=(1.18057, 2.04910)`, confirming that the promoted
path—not only a diagnostic selector—uses the momentum-closed load. The raw
budget's first-cycle drag is within `0.16%` of the published fifth-cycle mean
and lift is `19.12%` low.

The promoted five-cycle Apple M4 release ladder completed on 2026-07-14 in
`317.89 s` with a `1.051 GB` peak memory footprint and a `774 MB` field archive.
The 8/12/16-cell means are `(CL, CD)=(1.10193, 2.15741)`,
`(1.37756, 2.22153)`, and `(1.42346, 2.11525)`. Finest errors relative to the
published `(1.460, 2.046)` values are `2.503%` lift and `3.384%` drag. Finest
peak phases are `0.335T/0.835T`, midstroke mean lift is `1.76157`, half-stroke
symmetry error is `1.216%`, fourth-to-fifth-cycle difference is `0.999%`, all
five vortex diagnostics are finite, and batch density, velocity, and force
differences are exactly zero.

The unchanged scientific gate still reports failure. Lift changes `3.225%`
between 12 and 16 cells per chord and passes; drag changes `5.024%`, exceeding
the `5%` limit by `0.024` percentage points. No threshold was relaxed. The full
archive is `/tmp/birdflow-flapping-promoted-m4-20260714` on the validation host,
and the durable compact record is
`ValidationArtifacts/flapping-wing-promoted-ladder-summary.json`.

To resolve that marginal miss without rerunning the coarse grids, a five-cycle
20-cell diagnostic was run with:

```bash
.build/release/birdflow validate flapping-wing \
  --single-chord-cells 20 \
  --cycles 5 \
  --archive /tmp/birdflow-flapping-chord-20-m4-20260714 \
  --json
```

It completed in `582.12 s` with a `1.717 GB` peak memory footprint and `977 MiB`
archive. Mean `(CL, CD)=(1.48928, 2.16937)` is within `2.006%/6.030%` of the
published values. Relative to 16 cells, lift changes `4.420%` and drag `2.495%`,
both below the unchanged `5%` gate. Peak phases are `0.375T/0.855T`, midstroke
mean lift is `1.91521`, symmetry error is `1.552%`, fourth-to-fifth-cycle
difference is `1.155%`, and all vortex milestones are finite. The normalized
16-to-20 phase-curve difference is `5.216%`; its largest drag-bin change is
`0.34770` at phase `0.755T`.

The separate 20-cell input audit passes with exact CPU/Metal mask agreement,
maximum wall-velocity error `8.04e-9`, and maximum interpolated wall-position
error below `0.00071` cell. The compact diagnostic record is
`ValidationArtifacts/flapping-wing-chord-20-summary.json`.

The fixed-thickness completion case was run with:

```bash
.build/release/birdflow validate flapping-wing \
  --single-chord-cells 24 \
  --cycles 5 \
  --archive /tmp/birdflow-flapping-chord-24-m4-20260714 \
  --json
```

It completed in `1393.77 s` with a `2.947 GB` peak memory footprint and
`1.648 GiB` archive. Mean `(CL, CD)=(1.51819, 2.10509)` is within
`3.986%/2.888%` of the published values. Relative to the 20-cell case at the
same nominal `0.05c` thickness, lift changes `1.904%` and drag `3.054%`, both
below the unchanged `5%` gate. Finest peak phases are `0.405T/0.905T`,
midstroke mean lift is `2.05625`, symmetry error is `1.516%`,
fourth-to-fifth-cycle difference is `1.238%`, and all vortex milestones are
finite. The 24-cell input audit also passes with exact mask agreement and less
than `0.00071`-cell wall-position error.

The complete archive verdict is reconstructed without another solve:

```bash
python3 Scripts/audit-flapping-refinement.py \
  /tmp/birdflow-flapping-chord-20-m4-20260714/case.json \
  /tmp/birdflow-flapping-chord-24-m4-20260714/case.json \
  /tmp/birdflow-flapping-promoted-m4-20260714/report.json \
  --coarse-audit /tmp/birdflow-flapping-chord-20-input-audit.json \
  --fine-audit /tmp/birdflow-flapping-chord-24-input-audit.json \
  --output ValidationArtifacts/flapping-wing-fixed-thickness-acceptance.json
```

This applies the same coefficient, refinement, symmetry, periodicity,
midstroke, timing, vortex, and batch limits as the production Swift validator,
plus explicit five-cycle, aligned-phase, fixed-thickness, and input-audit
requirements. Every gate passes. The prescribed flapping-wing canonical is
therefore accepted on the archived fixed-thickness 20/24 refinement pair. This
does not promote the procedural complete-bird case, which still requires the
separate measured-geometry and free-flight gates below.

Acceptance:

- phase-resolved lift and drag reproduce timing and mean coefficients
- vortex topology is reviewed at matching nondimensional times from the archived Q/vorticity fields
- mean loads change below `5%` between the two finest grids

## 7. Measured right-wing surface

The Maeda et al. measured `201 x 401 x 17` PLOT3D sequence now has a distinct
wing-only replay tier. Generate its deterministic `21 x 41 x 17` runtime input
and audit every deposited phase on Metal:

```bash
python3 Scripts/import-measured-wing-grid.py \
  --input /path/to/rsos170307_si_008.zip \
  --song-dryad-tar /path/to/Data.tar \
  --surface-output ValidationInputs/maeda-hovering-right-wing-surface-v1.json

.build/release/birdflow replay measured-wing \
  --input ValidationInputs/maeda-hovering-right-wing-surface-v1.json \
  --chord-cells 8 \
  --json
```

Periodic position uses the two adjacent measured frames, including the
last-to-first wrap; wall velocity is the analytic derivative of that exact
linear segment. Metal prepares the compact vertices once per step, clears the
topology field, rasterizes one thread per measured triangle into deterministic
atomic distance/triangle keys, resolves occupancy and wall velocity, and then
builds signed-distance link fractions after an encoder synchronization point.
This avoids a grid-cell by triangle search and retains the conservative
cover/uncover estimator used by `stepFluidTRT`.

The default geometry gate checks all 17 phases, CPU/Metal prepared-point
parity, nonempty topology, finite wall speed, and boundary-link range. Add
`--fluid-cycle` to exercise one startup cycle through the production fluid and
load kernels. That startup force is diagnostic only: the source has no body,
left wing, mass, inertia, tail, or measured physical wing thickness. The
default `0.75`-cell half-thickness is explicitly numerical regularization.

Thickness sensitivity is a separate local gate:

```bash
.build/release/birdflow replay measured-wing \
  --input ValidationInputs/maeda-hovering-right-wing-surface-v1.json \
  --chord-cells 8 \
  --thickness-ladder \
  --json
```

It runs complete `0.5`, `0.75`, and `1.0`-cell-half-thickness startup cycles
and compares the full endpoint envelope against the same `5%` sensitivity
ceiling used for finest-grid mean loads. Comparisons are normalized by the
`0.75`-cell mean-force magnitude and vertical force; comparing only each
endpoint with the center is intentionally insufficient because it hides the
full uncertain range.

The local Apple M4 wing-only gate passes with `1992` steps per cycle, maximum
lattice point speed `0.0797478`, maximum prepared-position error
`9.13e-9 m`, and maximum prepared-velocity error `9.83e-7 m/s`. In the locked
release run, the 17-phase geometry gate takes `0.143 s`. The optional one-cycle
production-fluid diagnostic takes `3.32 s`, also passes, and records startup mean
force `[0.00151688, 0.000548557, 0.0118854] N` in
`ValidationArtifacts/measured-wing-surface-one-cycle.json`. No weight or
published-force comparison is made because the deposit lacks specimen mass and
complete geometry. This diagnostic uses the existing canonical `Re=100` and
`1 kg/m^3` density; both are recorded in the report and are not claimed as the
specimen's measured flight condition.

The locked eight-cell thickness ladder takes `11.29 s`. All three individual
geometry/fluid cases pass, but the combined gate is classified
`numerical-thickness-sensitive`: the maximum pairwise mean-force-vector
difference is `6.7416%` and the vertical-force envelope is `5.1810%`. The
result is retained in
`ValidationArtifacts/measured-wing-thickness-sensitivity-c8.json`. This does
not invalidate the measured boundary implementation; it prevents the arbitrary
`0.75`-cell regularization from being treated as quantitatively cleared.

The same gate at 12 chord cells is retained in
`ValidationArtifacts/measured-wing-thickness-sensitivity-c12.json`. Its three
cases all pass and complete in `44.00 s`. The force-vector envelope contracts
by `22.07%`, from `6.7416%` to `5.2535%`; the vertical envelope contracts by
`14.16%`, from `5.1810%` to `4.4475%`. Vertical sensitivity therefore clears,
but the full vector remains above the `5%` gate and the classification remains
`numerical-thickness-sensitive`. The `0.75`-cell mean-force vector also changes
`6.80%` from 8 to 12 chord cells, so load refinement is not yet cleared.

The 12-cell run exposed and fixed a harness defect: the measured-wing domain
previously used a fixed ten-cell clearance that only fit the eight-cell sponge.
The control-volume margin now scales with the resolution-dependent sponge, and
invalid clearance throws a descriptive request error instead of trapping on a
precondition.

At 16 chord cells the thickness gate clears. All three cases pass in
`155.48 s`; the full force-vector envelope is `3.9323%` and the vertical-force
envelope is `3.3543%`. These are reductions of `25.15%` and `24.58%`
respectively from the 12-cell envelopes. The center `0.75`-cell case changes
only `2.7647%` in force-vector norm and `2.7570%` in vertical force from 12 to
16 cells. Both the finest-grid thickness sensitivity and finest-two startup
load refinement therefore pass the `5%` engineering gate. The three-grid
conclusion and artifact hashes are locked in
`ValidationArtifacts/measured-wing-thickness-refinement-summary.json`.

This clears the wing-only *startup engineering refinement* gate, not
quantitative bird-flight acceptance. The forces are still first-cycle
transients at diagnostic `Re=100` and `1 kg/m^3`; complete specimen geometry
and physical membrane thickness remain unavailable.

Cycle stationarity is measured independently at the cleared 16-cell,
`0.75`-cell-half-thickness point:

```bash
.build/release/birdflow replay measured-wing \
  --input ValidationInputs/maeda-hovering-right-wing-surface-v1.json \
  --chord-cells 16 \
  --half-thickness-cells 0.75 \
  --stationarity \
  --json
```

The command runs five complete cycles, records cycles four and five in the
same one-cycle GPU history buffer, copies cycle four before reuse, and compares
raw three-component force in 100 phase bins. Mean force-vector, mean vertical
force, and normalized phase-resolved RMS differences must each remain below
`5%`; raw force is used because a deforming measured surface has no unique
rigid-wing lift/drag projection.

The Apple M4 release run takes `277.12 s` and passes. Cycle-four-to-five
differences are `0.3403%` for the mean force vector, `0.2406%` vertically, and
`0.1722%` for the complete phase-resolved curve. The maximum single-bin force
difference is `0.3739%` of final-cycle RMS force. The stationary final mean is
`[-0.000777677, 0.0000116009, 0.0118172] N`. It differs from the first-cycle
16-cell center result by `23.76%` in force-vector norm and `11.01%` vertically,
demonstrating why startup loads could not be promoted directly.

The stationarity report is
`ValidationArtifacts/measured-wing-stationarity-c16.json`; the consolidated
numerical verdict and SHA-locked dependencies are in
`ValidationArtifacts/measured-wing-numerical-acceptance-summary.json`.
Wing-only numerical acceptance is now cleared. Quantitative physical
acceptance remains open because `Re=100` and `1 kg/m^3` are diagnostic inputs,
not measured specimen flight conditions, and complete-bird fields remain
missing.

### Physical-condition source contract

The original Maeda et al. article reports an approximate greenhouse air
temperature of `22 deg C`, but neither the article, the complete nine-page
supplement, nor the deposited wing-grid README reports pressure, humidity,
density, viscosity, Reynolds number, an aerodynamic reference-speed
definition, or measured force. The article explicitly defers direct CFD
assessment. Consequently, `22 deg C` is not enough to reconstruct a measured
atmospheric state, and the existing `Re=100`, `1 kg/m^3` histories cannot be
relabelled or scalar-rescaled into physical results.

A later published CFD study by Dong et al. applies a numerical convention to
the same Maeda wing. Its equations 8 and 9 define mean chord `0.0195 m`,
average wingtip speed `Uref = 2 Phi f R = 7.1758 m/s`, density `1.205 kg/m^3`,
dynamic viscosity `1.81e-5 Pa s`, reported `Re=9367.4`, and force denominator
`0.5 rho Uref^2 S = 0.0423477513 N` for mean single-wing area `0.001365 m^2`.
This is a source-backed *published numerical condition*, not a measurement of
the greenhouse atmosphere.

The source is internally imperfect and the audit preserves that fact. Direct
substitution of the rounded printed values gives `Re=9315.6549`, `0.5524%`
below the reported value. Equation 8's speed closes independently to
`7.1757997 m/s`, while table 3 separately prints `7.58 m/s`, `5.63%` higher.
For reproducibility, the published numerical target uses literal `Re=9367.4`
and equations 8-9 use `Uref=7.1758 m/s`; `Re=9315.6549` is retained only as an
arithmetic-closure sensitivity point, and table 3's speed is not used.

The machine-readable evidence boundary and recomputation are locked in
`ValidationArtifacts/measured-wing-physical-condition-audit.json`. Verify it
without a fluid simulation:

```bash
python3 Scripts/verify-measured-wing-physical-condition.py
```

The local published-condition feasibility gate is explicit and does not alter
the diagnostic default:

```bash
.build/release/birdflow replay measured-wing \
  --input ValidationInputs/maeda-hovering-right-wing-surface-v1.json \
  --chord-cells 8 \
  --half-thickness-cells 0.75 \
  --published-condition \
  --json
```

`--published-condition` selects `Re=9367.4` and `1.205 kg/m^3`, runs one
cycle, and records actual population-mass drift, population extrema, finite
load coverage, lattice viscosity, and TRT relaxation margin. Geometry remains
valid, but the Apple M4 release run fails the fluid gate: `tau+=0.500131488`,
only `0.000131488` above the lower relaxation limit, and the first non-finite
load occurs at step `358/1992` (`t/T=0.179719`). Only 357 load steps are finite;
the final population field is non-finite, so mass drift and dimensional force
cannot be reported. Runtime is `5.71 s`.

The failure is retained in
`ValidationArtifacts/measured-wing-published-condition-feasibility-c8.json`.
It blocks a five-cycle published-condition ladder; clamping populations or
weakening finite-value gates would hide the instability rather than validate
the flow.

The one-cycle 12-cell discriminator also fails. Its relaxation margin rises by
`50.18%` to `0.000197470`, but the first non-finite load occurs at step
`430/2984`, phase `0.144102`—earlier in nondimensional time than the eight-cell
failure at phase `0.179719`. Geometry again passes, while final population mass
and mean force remain invalid. The run takes `15.81 s` and is locked in
`ValidationArtifacts/measured-wing-published-condition-feasibility-c12.json`.
This rules out a simple monotonic cure from the first resolution increase.

The one-cycle 16-cell discriminator also fails. Although its relaxation margin
is `0.000263453`, twice the eight-cell value, the first non-finite load arrives
at step `334/3976`, phase `0.084004`—earlier again in nondimensional time.
Geometry passes before the failure. The Apple M4 run takes `41.85 s` and is
locked in
`ValidationArtifacts/measured-wing-published-condition-feasibility-c16.json`.
Failures now stay within 334–430 lattice steps while moving earlier in physical
phase as resolution rises, so resolution-only escalation is closed.

The collision/topology discriminator is a sub-second release command:

```bash
.build/release/birdflow validate moving-wall --high-re-stability --json
```

It runs the production `stepFluidTRT` kernel for 500 steps in a fixed `16^3`
periodic planar channel at wall lattice speed `0.08`, using the exact c8, c12,
and c16 viscosities and relaxation margins. No cell is covered or uncovered.
All three cases remain finite on Apple M4 in `0.95 s`; every case completes all
500 steps, all final populations are positive, and the worst relative
population-mass drift is `1.23647e-5` against the `5e-5` gate. The result is
locked in
`ValidationArtifacts/measured-wing-high-re-fixed-moving-wall-stability.json`.

This clears collision-only TRT instability under the matched stress. The
topology-changing discriminator is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --json
```

It uses a `56 x 24 x 24` periodic domain so a radius-`3.25` voxel sphere can
translate `40` cells over 500 steps without touching the momentum-budget
surface. Wall speed and c8/c12/c16 viscosities exactly match the fixed-wall
gate. The Apple M4 release run takes `1.17 s` and fails at load steps `276`,
`282`, and `287`; final populations, macroscopic fields, and loads are
non-finite in every case. Each requested trajectory produces 1,280 cover and
1,280 uncover events over 220 transition steps, with zero solid links crossing
the control surface. The expected failure is archived in
`ValidationArtifacts/measured-wing-high-re-translating-body-stability.json`.
Residual statistics after explosive growth are not treated as a momentum-
closure result; finiteness fails first.

The fixed-occupancy curved-link discriminator is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --json
```

It holds the identical sphere mask fixed while retaining uniform wall lattice
velocity `0.08`. All topology counts are exactly zero, but the c8/c12/c16
cases become non-finite much earlier at steps `71`, `71`, and `72`. The Apple
M4 release run takes `1.17 s`; its expected failure is archived in
`ValidationArtifacts/measured-wing-high-re-fixed-occupancy-sphere-stability.json`.
Cover/uncover refill is therefore not required for the instability, and curved
moving-link forcing is sufficient under this stress.

This gate intentionally applies uniform translational wall velocity to a fixed
sphere, so some wall velocity is normal to a surface that does not move. The
component discriminator is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --decompose-wall-velocity \
  --json
```

At every sphere voxel it evaluates `u_n = (u dot n)n` and
`u_t = u - (u dot n)n` as separate 500-step histories. Normal-only c8/c12/c16
all become non-finite at step `86`. Tangential-only cases also fail, at steps
`186`, `187`, and `189`. The combined Apple M4 run takes `3.05 s`, contains no
topology events, and is archived in
`ValidationArtifacts/measured-wing-high-re-fixed-occupancy-wall-decomposition.json`.
The interaction is therefore general to curved moving links at these low TRT
relaxation margins, although normal forcing is more aggressive.

The stationary-wall discriminator is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --json
```

The boundary-component diagnostic exposed a parameter-wiring defect in this
canonical: the GPU received `referenceSpeedLattice` as wall velocity even when
the case report requested a stationary wall. The GPU parameter now comes from
`caseConfiguration.wallVelocityLattice`, and the static audit locks that
assignment. Every earlier stationary-sphere, relaxation, long-horizon,
positivity, TRT, and limiter result was therefore invalid and has been
replaced. The genuinely moving-wall cases are unaffected because their
configured wall speed already equals the reference speed.

With the corrected zero wall velocity, maintained far-field boundaries, and
the established `0.04` sphere sponge, c8/c12/c16 all become non-finite at step
`105` after `104` finite load samples. Topology remains fixed and pre-failure
loads are nonzero. The `0.93 s` Apple M4 release result is archived in
`ValidationArtifacts/measured-wing-high-re-stationary-wall-sphere-stability.json`.
The low-margin stationary curved-boundary configuration therefore remains
unstable, but only the corrected evidence is admissible.

The relaxation-margin sweep is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --relaxation-sweep \
  --json
```

Fourteen corrected 500-step cases retain the same external-flow setup and vary
only `tauPlus - 0.5`. Failure moves monotonically from step `105` at margin
`0.00025` through step `454` at `0.01`. Margin `0.0125` is the first stable
point, and every larger sampled margin through `0.05` also remains finite. The
transition is bracketed by effective Float margins `0.0099999905` and
`0.0124999881`. The `3.74 s` Apple M4 result is archived in
`ValidationArtifacts/measured-wing-stationary-wall-relaxation-sweep.json`.
This clears the former non-monotonic-band claim. These remain stability-only
results: every point still fails the full force-budget acceptance contract.

The long-horizon command is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --long-horizon-survival \
  --json
```

All three corrected points (`0.015625`, `0.016875`, and `0.02`) remain finite
for 1,000 steps. Relative mass drift stays between `9.45e-5` and `1.03e-4`,
and no population exceeds `0.338`. The result reproduces exactly apart from
runtime; the Apple M4 release run takes `2.15 s`. It is archived in
`ValidationArtifacts/measured-wing-stationary-wall-long-horizon-survival.json`.
This removes the former horizon-censoring conclusion, but none of the points
passes the separate force-budget acceptance gate.

The spatial population-positivity diagnostic is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --population-positivity \
  --archive ValidationArtifacts/measured-wing-stationary-wall-c16-population-positivity.json
```

It reduces all `19 * 56 * 24 * 24` populations on the GPU and reads only
`38,304` bytes of partial minima per step. In the corrected c16 case, `q=10`,
direction `(-1,1,0)`, first becomes negative at step `27`, cell `(5,9,12)`,
only `0.320714` cells outside the sphere. The cell is boundary-adjacent and has
five solid pull directions, but the failing `q=10` pull source `(6,8,12)` is
ordinary fluid. Its sponge factor is zero. The failing direction therefore
uses an ordinary fluid pull followed by TRT collision, while the local state
is still coupled to the curved boundary through other directions. The first
NaN appears at step `105`, `q=0`, cell `(2,10,9)` inside the sponge, on the
same step as the first non-finite load. There are no cover, uncover, or
topology events. The Apple M4 release run takes `0.20 s`, and a second run
reproduces both event locations exactly. The full phase history is archived in
`ValidationArtifacts/measured-wing-stationary-wall-c16-population-positivity.json`.

The one-cell TRT decomposition is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --trt-collision-decomposition \
  --archive ValidationArtifacts/measured-wing-stationary-wall-c16-trt-collision-decomposition.json
```

The diagnostic captures every boundary-interpolation component in the target
stencil and all 19 step-27 collision terms. It closes against the production
population output within `7.45e-9`. The corrected stationary wall contributes
exactly zero wall impulse in every captured boundary link. Every reconstructed
incoming population is positive. For the failing fluid-pull `q=10`, the pulled
population is `0.03086548`, the symmetric increment is `-0.03093607`, and the
antisymmetric increment is only `+9.07e-6`. Removing the symmetric increment
leaves `+0.03087455`; removing the antisymmetric increment still gives
`-7.05868e-5`. The first negative is therefore a symmetric/even TRT relaxation
overshoot at `omegaPlus=1.9989468`, while the antisymmetric mode is slightly
stabilizing. The `0.085 s` Apple M4 release result repeats exactly and is
archived in
`ValidationArtifacts/measured-wing-stationary-wall-c16-trt-collision-decomposition.json`.

The diagnostic-only symmetric-limiter A/B is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --symmetric-limiter-ab \
  --archive ValidationArtifacts/measured-wing-stationary-wall-c16-symmetric-limiter-ab.json
```

The corrected control repeats first negativity at step `27` and first
non-finite population/load at step `105`. The treatment stays finite and
strictly positive through all 500 steps. It first activates at step `27`, on
`1,417,658` cell-steps across 467 steps, never reaches scale zero, and touches
6,819 cells in its busiest step. The minimum scale is `0.00142777`, and the
minimum population is `8.72842e-9`. Positivity is therefore cleared.

The uncorrected acceptance flags still fail: relative mass drift is
`0.00182889`, maximum raw force-budget residual is `0.240913`, and relative
RMS residual is `0.039366`. The new 500-sample GPU ledger reconstructs every
step as curved-boundary replacement, open-far-field replacement, baseline TRT
collision, symmetric limiting, and sponge relaxation. Global mass closes with
maximum per-step residual `5.19e-6`, while the summed history differs from the
final-minus-initial population mass by only `8.93e-6`.

The attribution clears limiter arithmetic. The observed mass change is
`-58.9928`; open far-field replacement contributes `-212.359`, sponge
relaxation contributes `+152.514`, baseline collision contributes `+0.867`,
and symmetric limiting contributes only `-0.0151`—`4.69e-7` of initial mass.
Inside the existing control volume, sponge forcing is `0.125604 N` RMS versus
`3.34e-7 N` RMS from the limiter. These sources explain the old force residual
to `0.287%` RMS and `0.578%` peak. Independently, measured body load closes
against curved-boundary fluid momentum to `3.03e-7` relative RMS. Open-domain
mass flux and sponge forcing, not limiter arithmetic or boundary load
accounting, caused the raw gate failures.

Two Apple M4 release runs match exactly apart from runtime. The expanded
three-case diagnostic is stored in
`ValidationArtifacts/measured-wing-stationary-wall-c16-symmetric-limiter-ab.json`.

The source-aware treatment repeats the identical fluid history with control
bounds `[4,4,4]` through `[52,20,20]`, wholly outside the four-cell sponge.
Every one of its 500 samples contains zero control-volume sponge cells, and no
solid link crosses the control surface. The global source ledger replaces the
invalid closed-domain zero-mass-drift rule and closes. With the sponge removed
from the local momentum budget, the canonical raw budget also passes: maximum
residual is `0.000464316 N` under the `0.0005 N` gate and relative RMS residual
is `5.37373e-5` (`0.00537%`) under the `0.5%` gate. Boundary load retains
`3.03e-7` relative RMS closure. The c16 source-aware acceptance therefore
passes; the limiter is promoted to the locked c8/c12/c16 stationary-sphere
refinement ladder, not yet to coupled bird replay.

The promoted geometric ladder is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --geometric-limiter-ladder \
  --archive ValidationArtifacts/measured-wing-stationary-wall-geometric-limiter-refinement.json
```

It holds the physical geometry and duration fixed while refining from 8 to 12
to 16 cells per diameter. The domains are `10D x 6D x 6D`, the sphere center is
`3D` from the inlet, the sponge is `0.5D`, and every case runs for `5 tU/D` at
`Re=9367.4`, lattice speed `0.08`, and Mach `0.1386`. All three cases remain
finite and positive, close the global source ledger, pass the local force
budget, and keep both sponge cells and solid links off the control surface.

The predeclared non-intrusiveness and convergence gates fail. Inside the
sponge-excluded control volume, limiter activation grows from `3.53%` to
`6.65%` to `8.07%`; limiter-to-collision correction is
`3.40%/5.87%/6.17%` in L1 and `11.71%/14.74%/14.54%` in L2. Mean drag is
`1.8056`, `2.4725`, and `2.1535`; the finest-two change is `14.81%` against a
`5%` gate and is non-monotonic, so no observed order, Richardson extrapolate,
or GCI is reported. This proves the failure is not a sponge artifact. It also
blocks promotion to flapping or measured-bird replay without relaxing any
threshold. The full phase histories and paper-ready figure are archived in
`ValidationArtifacts/measured-wing-stationary-wall-geometric-limiter-refinement.json`
and `ValidationArtifacts/Figures/stationary-wall-geometric-limiter-refinement.svg`.

The next admissible physics step is a controlled collision-operator A/B on
this same ladder, preceded by radial localization of limiter corrections. It
must reduce interior intervention and restore convergence before another
bird-scale run is justified.

The D=16 radial localization is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --radial-limiter-localization \
  --archive ValidationArtifacts/measured-wing-stationary-wall-c16-radial-limiter-localization.json
```

It reuses the accepted source-aware control volume and captures the known first
activation at step 15 plus steps 100, 250, 500, 750, and 1,000. A deterministic
GPU reduction partitions the physical flow into eight shells with outer edges
at `1/16`, `1/8`, `1/4`, `1/2`, `1`, `2`, and `3` sphere diameters from the
surface. Every shell sum closes back to the independent control-volume ledger;
the maximum relative closure residual is `8.02e-7` under the predeclared
`1e-4` gate.

The limiter starts at the curved wall: at `tU/D=0.075`, all correction and all
40 activated control-volume cells are within one lattice cell of the surface.
It then propagates outward. At `tU/D=2.5`, `61.58%` of limiter L1 is already
beyond `1D`; by `tU/D=5`, the fraction is `88.58%`, while only `1.11%` remains
within `0.25D`. Activated-cell shares give the same result (`88.28%` beyond
`1D`, `1.15%` within `0.25D`). The predeclared boundary-localization contract
required at least `80%` near-surface correction and no more than `5%` beyond
`1D`, so it fails by a wide margin. This rules out a boundary-only limiter
repair and directs the next A/B toward a genuinely positivity-preserving or
regularized bulk collision model at the same Reynolds number and geometry.

The exact report and figure are
`ValidationArtifacts/measured-wing-stationary-wall-c16-radial-limiter-localization.json`
and `ValidationArtifacts/Figures/stationary-wall-radial-limiter-localization.svg`.

The locked D=16 bulk collision-operator A/B is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --bulk-collision-operator-ab \
  --archive ValidationArtifacts/measured-wing-stationary-wall-c16-bulk-collision-operator-ab.json
```

Both 1,000-step cases retain the radial-localization geometry, `Re=9367.4`,
`U=0.08`, sponge, control volume, stationary curved-wall reconstruction, load
estimator, population floor, and capture/reduction kernels. The control is the
source-aware symmetric-limited TRT treatment. The candidate projects the
pre-collision nonequilibrium distribution onto its second-order Hermite stress
tensor, applies the viscosity-setting `omegaPlus` BGK relaxation, then uses one
cell-local convex scale from equilibrium to the unbounded regularized state.
The common scale preserves density and momentum while enforcing the same
positive-population floor. This is the projection-based regularization of
[Latt and Chopard](https://arxiv.org/abs/physics/0506157), used here only as a
diagnostic candidate rather than a production-model promotion.

The promotion gates are copied without relaxation from the geometric ladder:
relative RMS force residual at most `0.5%`, peak force residual ratio at most
`0.1%`, control-volume correction activation at most `5%`, and both relative L1
and L2 correction at most `1%`. Population positivity, global source-ledger
closure, boundary/load closure, sponge exclusion, control-surface isolation,
and final radial closure are also mandatory.

The regularized candidate remains positive for all 1,000 steps, closes the
global source ledger, closes its radial reduction to `6.83e-9`, and passes the
force gates (`0.1207%` relative RMS and `0.0701%` peak ratio). It reduces
control-volume correction activation from `8.070%` to `0.028%` and relative L1
correction from `6.169%` to `0.053%`. It is nevertheless rejected: relative L2
correction is `1.0968%`, above the locked `1.0000%` gate. No D=8/12/16 ladder
is justified for this candidate. The exact report and figure are
`ValidationArtifacts/measured-wing-stationary-wall-c16-bulk-collision-operator-ab.json`
and `ValidationArtifacts/Figures/stationary-wall-bulk-collision-operator-ab.svg`.

The follow-up recursive-regularization A/B is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --recursive-regularization-ab \
  --archive ValidationArtifacts/measured-wing-stationary-wall-c16-recursive-regularization-ab.json
```

This test changes only moment retention. The rejected second-order regularized
BGK candidate is the control. The candidate recursively reconstructs
third-order nonequilibrium from velocity and the second-order stress following
the recursive regularization framework of
[Coreixas et al.](https://arxiv.org/abs/1704.04413). It retains the six mixed
third-order modes supported by D3Q19 (`xxy`, `xxz`, `xyy`, `xzz`, `yyz`, and
`yzz`); pure cubic Hermites vanish on this stencil and `xyz` is unsupported.
The same equilibrium-to-post-collision convex line search is applied after the
unbounded recursive reconstruction. Geometry, `Re=9367.4`, `U=0.08`, sponge,
control volume, 1,000-step horizon, population floor, wall treatment, load
estimator, ledgers, and promotion gates remain unchanged.

The recursive candidate remains positive, closes the global source and radial
ledgers, and passes the force budget (`0.16064%` relative RMS and `0.07991%`
peak ratio). Relative to the second-order control, activation falls from
`0.02803%` to `0.00645%`, relative L1 correction falls from `0.05304%` to
`0.01932%`, and relative L2 correction falls from the rejected `1.09683%` to
`0.35279%`. The candidate therefore clears every unchanged D=16 gate and is
eligible for the locked D=8/12/16 geometric refinement ladder. This is not a
grid-convergence result and does not authorize flapping or measured-bird replay.
The exact report and figure are
`ValidationArtifacts/measured-wing-stationary-wall-c16-recursive-regularization-ab.json`
and `ValidationArtifacts/Figures/stationary-wall-recursive-regularization-ab.svg`.

The promoted-to-test RR3 refinement ladder is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --recursive-regularization-ladder \
  --archive ValidationArtifacts/measured-wing-stationary-wall-recursive-regularization-refinement.json
```

This command changes only the collision selector from the rejected symmetric
TRT limiter to RR3. It retains the old geometric ladder's D=8/12/16 domains,
500/750/1,000 steps, five convective times, source and force ledgers, final-one-
convective-time drag average, and all predeclared gates. Every case remains
positive, source closed, force-budget closed, and individually non-intrusive.
Control-volume correction activation decreases from `0.01352%` through
`0.01087%` to `0.00645%`; relative L1 correction decreases from `0.02436%` to
`0.02349%` to `0.01932%`, and relative L2 correction decreases from `0.41331%`
to `0.37792%` to `0.35279%`.

Promotion is nevertheless rejected without threshold relaxation. D=8/12/16
mean drag coefficients are `1.32042`, `0.93800`, and `1.04777`. The D12-to-D16
change is `10.476%` against the unchanged `5%` gate, the sequence is
non-monotonic, and no admissible three-grid Richardson fit exists. The archived
phase history also exposes a duration sensitivity worth resolving before a
larger grid: fourth-to-fifth convective-window means change `11.54%`, `13.28%`,
and `0.052%` on D=8, D=12, and D=16. A short extension of only the two cheaper
coarse cases can therefore distinguish transient-window bias from spatial
non-convergence before paying for D=20. The exact report and figure are
`ValidationArtifacts/measured-wing-stationary-wall-recursive-regularization-refinement.json`
and `ValidationArtifacts/Figures/stationary-wall-recursive-regularization-refinement.svg`.

The controlled coarse-grid duration diagnostic is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --recursive-regularization-duration \
  --archive ValidationArtifacts/measured-wing-stationary-wall-recursive-regularization-duration.json
```

It changes only the requested duration and runs only D=8/12, the two cases
whose fourth-to-fifth window changes exceeded 11%. Both histories reach ten
convective times and retain population positivity, source-ledger closure,
force-budget closure, control-volume isolation, and the unchanged non-intrusive
correction gates. D=12 clears the predeclared late-window check: ninth-to-tenth
mean drag changes `4.543%` against `5%`, and its fifth-to-tenth change is only
`2.177%`. D=8 does not settle: its ninth-to-tenth change is `46.848%`, its
fifth-to-tenth change is `29.219%`, and the ninth one-convective-time mean has a
large excursion. The five-convective-time spatial ladder therefore cannot yet
be reclassified as duration-biased, and D=20 is deferred.

This is an admissible negative result, not a numerical failure: every
individual physics and accounting gate passes, while the separate scientific
duration flag remains false. The next gate should extend only D=8 and estimate
the dominant shedding period plus uncertainty from period-complete block means.
That avoids treating adjacent one-convective-time samples of an unsteady wake as
independent steady estimates. The exact report and figure are
`ValidationArtifacts/measured-wing-stationary-wall-recursive-regularization-duration.json`
and `ValidationArtifacts/Figures/stationary-wall-recursive-regularization-duration.svg`.

Even a passing numerical gate would not supply the missing specimen body,
mass, left wing, tail, physical feather thickness, pressure, or humidity.

The locked compact input SHA-256 is
`5de3e1d9377ad652ab88d2f460287affd6055c69691e32f120d74cdf79628887`.

## 7.5. Reconstructed dove with measured external force

The Deetjen et al. Ringneck-dove deposit is qualified as a separate
prescribed-motion experimental benchmark. It does not complete the Maeda
specimen and does not satisfy schema 2. Its value is independent measured force:
processed horizontal and vertical aerodynamic-force-platform histories are
synchronized with structured-light body/tail/left-wing surfaces and tracked
kinematics.

Verify the remote source without downloading the 19.3 GB archive:

```bash
python3 Scripts/acquire-dove-benchmark.py --json
```

Selectively acquire and inspect the qualified `2018_12_11_OB_F03` flight:

```bash
python3 Scripts/acquire-dove-benchmark.py \
  --download --include-surface --include-force-code \
  --output /path/to/deetjen-ob-f03 --json

python3 Scripts/inspect-dove-benchmark.py \
  --input /path/to/deetjen-ob-f03 --include-surface
```

The source and engineering-ingestion chain locks all nine data members plus the
two force-registration scripts, the `1000/2000 Hz` synchronization,
body/wing/tail topology inventory, source coordinate scale, processed force
window, and measured-versus-modeled boundary.
The source's right wing is a symmetry assumption, lateral/per-wing forces are
derived, and its 20-point wing mass distribution is cross-source scaled. Only
`FxWings` and `FzWings` may enter the experimental-force verdict.

Before the fluid comparison, acceptance requires:

- compact surface conversion preserves source landmarks, areas, topology,
  body/wing/world transforms, and wall velocity within preregistered tolerances
  (**passed** for the selected flight);
- generic indexed Metal interpolation/rasterization preserves all component
  masks and wall velocity against an independent CPU raster without executing
  fluid or force kernels (**passed** for all 144 frames, with exact occupancy at
  five milestones);
- the accepted indexed surface closes direct before/after fluid momentum against
  the production interpolated-link, conservative moving-domain, and TRT path in
  a periodic zero-sponge topology-changing gate (**passed** at `1.789e-5`
  relative RMS);
- the source force sign and axes close independently against the registered
  BirdFlow frame (**passed**: `[-FxWings, unavailable, -FzWings]`, with no
  lateral zero-fill);
- the five flights for bird `OB` establish a measurement/biological
  repeatability envelope before CFD error thresholds are frozen;
- time-step and `8/12/16` spatial refinement pass without modifying measured
  geometry or kinematics; and
- only horizontal/vertical total-force impulse, mean, peak phase, peak
  magnitude, and phase-resolved residuals determine experimental acceptance.

The committed non-periodic surface sequence contains 144 frames, 2,157
vertices per frame, and 3,968 fixed triangles. Independent CPU decoding
reproduces the source-area and coordinate-bound closure and limits the maximum
adjacent-frame point speed to `25.2305 m/s`, `1.1807x` the deposited filtered
blade-element maximum under the locked `1.25x` ceiling. Worst absolute area
errors are `4.703%` body, `8.905%` wing, and `0.566%` tail. The original sparse
outline remesh was rejected because it generated a false `91.9 m/s` tip speed.

Status: selective source acquisition, integrity, MATLAB decoding, timing,
compact topology, coordinate registration, and CPU wall-velocity parity pass.
The geometry-only Metal replay also passes on Apple M4 in `7.02 s` for all 144
stored frames plus five fractional-time interpolation probes. All four
components remain present, the five CPU milestones have zero occupancy
mismatches, and maximum position/wall-velocity/signed-distance differences are
`1.669e-8 m`, `2.182e-5` lattice, and `1.574e-5` cells. Fluid collision, force
accumulation, and every experimental-force comparison remain open in that
geometry-only artifact. A separate eight-step production integration gate then
exercises 39 cover, 53 uncover, and 101,262 persistent-link events with periodic
boundaries and zero sponge. Direct population momentum closes against the
production load at `1.789e-5` relative RMS and `3.8846e-8 kg m/s` maximum
absolute residual. Developed flow and every experimental-force comparison remain
open. The separate source-code registration selects the same `191878...192164`
force window by nearest lookup and exact camera arithmetic, gives zero residual
at all 144 stored-frame timestamps, inserts 143 exact half-frame samples, and
matches the deposited derived vertical series with zero residual. Its canonical
287-sample target has `0.0207113 N s` forward and `0.162774 N s` upward impulse;
lateral force remains unavailable. Evidence is in
`ValidationArtifacts/deetjen-dove-source-qualification.json` and
`ValidationArtifacts/deetjen-dove-engineering-ingestion.json`, plus
`ValidationArtifacts/deetjen-dove-surface-conversion.json` and
`ValidationArtifacts/deetjen-dove-surface-cpu-parity.json`, with the complete
144-frame GPU audit in
`ValidationArtifacts/deetjen-dove-indexed-metal-geometry.json` and the short
production ledger in
`ValidationArtifacts/deetjen-dove-indexed-production-coupling.json`. The force
target and registration gate are
`ValidationInputs/deetjen-ob-f03-force-v1.json` and
`ValidationArtifacts/deetjen-dove-force-registration.json`; the separate
committed-input audit is
`ValidationArtifacts/deetjen-dove-force-target-cpu-parity.json`.

The bounded coarse pilot is now executed with 16 fluid steps per 2 kHz force
sample. It advances an 800-step pre-roll before the registered 187-sample
`0.025...0.118 s` comparison window. The `0.01 m` grid cannot represent the
source viscosity inside the Float TRT margin: it would require
`tau+=0.50001469`. The pilot therefore declares a `tau+=0.501` viscosity floor,
`68.07x` the source viscosity, and explicitly disables experimental-agreement
acceptance. On Apple M4, the first sampled negative population occurs at step
176 (`5.5 ms`), D3Q19 direction 7, cell `[31,35,29]`, `0.0764` cells from the
moving surface. The load becomes nonfinite at step 331, before pre-roll ends;
there are consequently no comparison samples and no zero-filled aggregate
errors. `ValidationArtifacts/deetjen-dove-coarse-force-pilot.json` records the
negative integration result, while
`ValidationArtifacts/deetjen-dove-coarse-force-pilot-audit.json` independently
passes artifact arithmetic/provenance and retains `pilotIntegrationPassed=false`.

The following fixed-input collision screen runs production TRT,
positivity-preserving regularized BGK, and positivity-preserving recursive-
regularized BGK through the same 800-step pre-roll. It reduces the population
minimum every step and obtains limiter activation from the existing fused load
reduction. Production TRT reproduces the first negative population at step 150
(`4.6875 ms`) in the same direction-7 cell. Both candidates complete 800 steps
with finite loads and positive populations. Regularized BGK activates in 55
cell-steps (`2.013e-7`); RR3 activates in 28 (`1.025e-7`), both below the fixed
`5%` cell-step ceiling. The independent audit passes for
`ValidationArtifacts/deetjen-dove-collision-pre-roll-ab.json` and
`ValidationArtifacts/deetjen-dove-collision-pre-roll-ab-audit.json`.
This is a stability screen, not collision promotion. The next admissible step
is candidate-specific momentum closure for both survivors, not the measured-
force refinement ladder.

Run that locked closure with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-momentum-closure \
  --archive ValidationArtifacts/deetjen-dove-collision-momentum-closure.json \
  --json

python3 Scripts/audit-dove-collision-momentum-closure.py
```

Both candidates complete the same 800 steps with positive populations and
finite loads. The fixed `[7,68) x [7,62) x [7,59)` control volume remains five
cells outside the swept surface, outside the six-cell sponge, with zero solid-
crossing links. Regularized BGK and RR3 close raw momentum storage plus surface
flux against the conservative boundary load at `7.944e-4` and `7.987e-4`
relative RMS. The separate whole-domain fluid/source ledger closes at
`1.1459e-3` and `1.1453e-3`. All results clear the unchanged `0.005` threshold,
and the independent audit reconstructs all 1,600 step samples and summary
statistics. This accepts momentum consistency only. Both candidates advance to
the fixed extended pilot; the RR3 activation advantage is not a production-
selection rule, and experimental agreement/refinement remain deferred.

Run the full registered-window extension with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-extended-pilot \
  --archive ValidationArtifacts/deetjen-dove-collision-extended-pilot.json

python3 Scripts/audit-dove-collision-extended-pilot.py
```

Both candidates complete all 3,776 steps and all 187 comparison samples with
finite loads and positive every-step population diagnostics. Regularized BGK
and RR3 retain minima `2.642e-9` and `3.202e-9`; their correction counts remain
55 and 28, now only `4.265e-8` and `2.171e-8` of the longer run's cell-steps.
The candidate force histories differ by `0.656%` endpoint and `0.882%`
interval-mean normalized RMS. The independent audit reconstructs the complete
registered window and both parent differences.

This is a numerical full-window gate. The endpoint measured-force errors
`5.665/5.676` and interval-mean errors `2.274/2.264` are descriptive because
the pilot viscosity is `68.07x` the source value. They cannot select an
operator or establish experimental agreement. The next admissible allocation
was the preregistered two-operator 8/12-grid discriminator; only its selected
candidate could advance to the 16-cell completion run.

Freeze, run, complete, and independently audit that workflow with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-preregister \
  --archive ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-discriminator \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-completion \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --archive ValidationArtifacts/deetjen-dove-collision-grid-completion.json

python3 Scripts/audit-dove-collision-grid-workflow.py
```

The preregistration fixes a `0.08 m` reference length, `0.0075 m` physical
half-thickness, `0.12 m` padding, `0.06 m` sponge, and the `68.07195x`
viscosity floor. D=8/12/16 use `16/24/32` fluid steps per force sample,
`12/18/24` padding cells, and `6/9/12` sponge cells. Thus physical timing,
domain, geometry regularization, viscosity, and maximum Mach `0.136564` remain
fixed while resolution changes. Both operators complete D=8 and D=12 with
positive finite populations and negligible correction activation. Their
D8-to-D12 trend scores are `0.125454` regularized BGK and `0.125081` RR3;
operator disagreement decreases from `0.008824` to `0.008164`. Both are inside
the locked 10% trend-penalty envelope, so the stationary-wall correction gate
breaks the tie: regularized BGK previously missed its 1% L2 limit at `1.0968%`,
while RR3 passed at `0.3528%`. RR3 alone is selected.

The only authorized D=16 run stops at step `751/7,552`, before the comparison
window, on a negative direction-0 population at cell `[64,63,68]`, `0.2151`
cells from the surface. Loads and sampled values are still finite, and
correction activation is only `1.435e-7`, but positivity and completion fail.
The completion command therefore writes the negative archive and exits
nonzero. The independent audit verifies the four-case discriminator, selection
arithmetic, single D=16 allocation, and absent convergence values. This rejects
the measured-dove D=16 completion; it does not authorize regularized BGK at
D=16 or experimental force comparison.

Localize that retained failure without changing production populations:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-provenance \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --completion ValidationArtifacts/deetjen-dove-collision-grid-completion.json \
  --archive ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json

python3 Scripts/audit-dove-d16-population-provenance.py
```

The opt-in one-cell kernels run immediately before and after the unmodified
production `stepFluidTRT` kernel at steps `747...751`. Their predicted
direction-0 outputs equal the production outputs exactly at all five steps.
At step 751, the pre-step and reconstructed direction-0 population remains
positive at `0.00596387`, but moving-boundary reconstruction has already made
directions `2, 8, 12, 13, 16` negative. The reconstructed velocity is
`[0.643648, 0.507265, 0.585985]` lattice units, speed `1.007461` and lattice
Mach `1.744974`. That exceeds the rest-population equilibrium positivity limit
`sqrt(2/3) = 0.816497`; the direction-0 equilibrium is consequently
`-0.003425966`. RR3's global positivity scale becomes zero, so collision
returns that inadmissible equilibrium and writes the first negative retained
population. The target direction uses local-fluid reconstruction and the cell
is persistent fluid; far field, topology refill, and sponge are absent.

The independent audit reconstructs density, velocity, all equilibrium values,
the second- and recursive-third-order regularized moments, the global
positivity scale, and the final selected population from the archived 19
incoming values. All 13 checks pass. This locates the retained direction-0
write at collision while preserving the important upstream fact that the
moving-boundary reconstruction already contains negative incoming directions.
It does not yet determine whether those negatives originate in the reflected
population, wall correction, or interpolation residual, and it does not
authorize a collision patch or another refinement run.

Decompose the upstream boundary inputs and evaluate non-mutating
counterfactuals with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-boundary-decomposition \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --completion ValidationArtifacts/deetjen-dove-collision-grid-completion.json \
  --provenance ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json \
  --archive ValidationArtifacts/deetjen-dove-d16-boundary-term-decomposition.json

python3 Scripts/audit-dove-d16-boundary-terms.py
```

The diagnostic captures every moving-boundary direction at steps 750 and 751
without writing a population or geometry buffer. Its reconstructed values
match the prior stage artifact within `1.892e-10`; reflected, auxiliary, and
wall contributions close within `1.747e-10`. Negative boundary directions
change from `[2,3,10]` to `[2,8,12,13,16]`. At the failure step, all five
reflected populations are positive and the single far-wall auxiliary
contribution is also positive. Every wall-correction contribution is negative
and dominates its reconstructed population.

Four failing directions already use the halfway fallback. Direction 12 uses
the interpolated far-wall branch, but moving-wall halfway makes it more
negative (`-0.005518` versus `-0.002446`). Thus switching interpolation branch
does not make any failing input nonnegative. Removing only the auxiliary term
also fixes none. Both interpolated zero-wall and halfway zero-wall
counterfactuals make all five directions positive, while no reflected
population remains negative under halfway zero-wall. The independently
reconstructed 12-check audit therefore identifies
`moving-wall-correction` as the first repair surface. These counterfactuals are
diagnostics only; zero wall is not promoted as a physical boundary condition.
The next admissible experiment is a one-cell density-normalization and
admissibility A/B for the moving-wall correction, followed by the existing
momentum ledger before any production change or refinement run.

Run that archive-only discriminator with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-ab \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --completion ValidationArtifacts/deetjen-dove-collision-grid-completion.json \
  --provenance ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json \
  --boundary-terms ValidationArtifacts/deetjen-dove-d16-boundary-term-decomposition.json \
  --archive ValidationArtifacts/deetjen-dove-d16-moving-wall-admissibility-ab.json

python3 Scripts/audit-dove-d16-moving-wall-admissibility.py
```

All 19 pre-step target populations are reconstructed from the locked rest
population, reflected populations, and the far-wall previous-target auxiliary
population. Candidate A scales every wall contribution uniformly by the
pre-step local density `0.0301927`; candidate B keeps the reference-density
form but applies the largest global scale (`0.115051`) allowed by the worst
link. Candidate A makes every population positive with minimum `5.580e-5`,
restores a positive equilibrium with lattice Mach `0.548166`, and needs no
positivity intervention. The self-consistent density cross-check (`0.0348964`)
also passes. Candidate B passes algebraic admissibility but explicitly
activates its limiter and places the worst population at the floor.

The independent 13-check audit reconstructs both candidates, the
self-consistent density solution, all D3Q19 moments and equilibria, the global
admissibility scale, and every direction sample. Candidate A is authorized
only for a controlled production force/momentum-ledger experiment. No fluid
simulation was rerun, no boundary or collision law changed, and neither
candidate is authorized for production, refinement, or an experimental claim.

Run the authorized ledger with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-ledger \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --completion ValidationArtifacts/deetjen-dove-collision-grid-completion.json \
  --provenance ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json \
  --boundary-terms ValidationArtifacts/deetjen-dove-d16-boundary-term-decomposition.json \
  --moving-wall-ab ValidationArtifacts/deetjen-dove-d16-moving-wall-admissibility-ab.json \
  --archive ValidationArtifacts/deetjen-dove-d16-moving-wall-ledger.json

python3 Scripts/audit-dove-d16-moving-wall-ledger.py
```

The Apple M4 validation-only replay completed all `751` retained D=16 steps in
`22.81 s`. Its `149 x 136 x 131` grid, RR3 collision operator, geometry,
kinematics, time step, viscosity floor, sponge, and force estimator are
unchanged from the failed completion. Only the moving-wall correction density
normalization is opt-in: it uses the complete pre-step target-cell population
density. The minimum population is `1.634e-8`; no wall limiter exists or
activates. The RR3 collision limiter activates twice, only `1.003e-9` of cell
steps, below the unchanged `5%` intrusion ceiling.

The near-wing storage-plus-flux ledger closes at `4.719e-4` relative RMS and
the separately reduced whole-domain fluid/source ledger at `5.306e-4`, both
below `0.005`. The control surface remains approximately 11 cells outside the
swept bird and 12 cells from the domain edge, outside the 12-cell sponge, with
zero solid-crossing links. The independent nine-check audit reconstructs all
751 vector equations, RMS summaries, extrema, activation fraction, input
hashes, and gate booleans. Candidate A therefore advances to one full
registered-window D=16 run. It is not a production default, refinement result,
experimental-force acceptance, or free-flight validation.

Run the source-locked full window with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-full-window \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --completion ValidationArtifacts/deetjen-dove-collision-grid-completion.json \
  --provenance ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json \
  --boundary-terms ValidationArtifacts/deetjen-dove-d16-boundary-term-decomposition.json \
  --moving-wall-ab ValidationArtifacts/deetjen-dove-d16-moving-wall-admissibility-ab.json \
  --moving-wall-ledger ValidationArtifacts/deetjen-dove-d16-moving-wall-ledger.json \
  --archive ValidationArtifacts/deetjen-dove-d16-moving-wall-full-window.json

python3 Scripts/audit-dove-d16-moving-wall-full-window.py
```

The Apple M4 run completes all `7,552` D=16 steps in `293.34 s` and retains a
positive `1.025e-8` minimum population. All 187 registered force samples are
present. The near-wing and global relative RMS force/momentum residuals are
`6.247e-4` and `8.312e-4`, respectively, under the unchanged `0.005` limit;
the maximum absolute residuals are `0.01958 N` and `0.01941 N`. No solid link
crosses the control surface. RR3 correction activates in 34 cell-steps, only
`1.696e-9` of the total, and the opt-in moving-wall law adds no positivity
limiter.

The independent audit reconstructs all 7,552 storage, flux, source, force, and
residual vectors, every summary norm and extremum, the collision-activation
fraction, all 187 32-step force bins, means, impulses, peaks, and the normalized
error. Its 11 checks pass. The descriptive measured-versus-computed normalized
RMS error is `2.17306`; mean measured/computed `(Fx,Fz)` is
`(0.15597,1.42023) N` versus `(0.00408,1.93581) N`, and peak time is
`0.0680 s` versus `0.1065 s`. This discrepancy is retained, not accepted or
tuned away. The condition is still `68.07195x` over-viscous and has no
candidate-A grid ladder, so the full-window numerical pass authorizes only a
preregistered candidate-A spatial discriminator. Production, experimental
agreement, and free flight remain unpromoted.

### Candidate-A full-window spatial discriminator

The spatial rule was archived before either new grid was executed. It freezes
candidate A, pre-step local-density normalization, the complete registered
window, the dual `0.005` momentum-ledger limit, the `5%` collision-intrusion
limit, and a `5%` D12-to-D16 force-history/mean/impulse limit. It additionally
requires every fine-pair metric to decrease from its D8-to-D12 value. Measured
force error is explicitly forbidden from selecting or passing the numerical
model.

Create the source-hashed preregistration with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-spatial-preregister \
  --moving-wall-full-window ValidationArtifacts/deetjen-dove-d16-moving-wall-full-window.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-spatial-preregistration.json
```

Run each resumable case by supplying the same promotion chain used by the D16
full window, plus the locked spatial files. The D=8 command is:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-spatial-case \
  --preregistration ValidationArtifacts/deetjen-dove-collision-grid-preregistration.json \
  --discriminator ValidationArtifacts/deetjen-dove-collision-grid-discriminator.json \
  --completion ValidationArtifacts/deetjen-dove-collision-grid-completion.json \
  --provenance ValidationArtifacts/deetjen-dove-d16-population-stage-provenance.json \
  --boundary-terms ValidationArtifacts/deetjen-dove-d16-boundary-term-decomposition.json \
  --moving-wall-ab ValidationArtifacts/deetjen-dove-d16-moving-wall-admissibility-ab.json \
  --moving-wall-ledger ValidationArtifacts/deetjen-dove-d16-moving-wall-ledger.json \
  --moving-wall-full-window ValidationArtifacts/deetjen-dove-d16-moving-wall-full-window.json \
  --spatial-preregistration ValidationArtifacts/deetjen-dove-moving-wall-spatial-preregistration.json \
  --reference-length-cells 8 \
  --archive ValidationArtifacts/deetjen-dove-d8-moving-wall-full-window.json
```

Repeat with `--reference-length-cells 12` and archive
`ValidationArtifacts/deetjen-dove-d12-moving-wall-full-window.json`. Combine
the two cases with the unchanged D16 archive using:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-spatial-discriminator \
  --moving-wall-full-window ValidationArtifacts/deetjen-dove-d16-moving-wall-full-window.json \
  --spatial-preregistration ValidationArtifacts/deetjen-dove-moving-wall-spatial-preregistration.json \
  --spatial-d8 ValidationArtifacts/deetjen-dove-d8-moving-wall-full-window.json \
  --spatial-d12 ValidationArtifacts/deetjen-dove-d12-moving-wall-full-window.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-spatial-discriminator.json

python3 Scripts/audit-dove-moving-wall-spatial-refinement.py
```

Both Apple M4 cases pass their numerical gates. D=8 completes `3,776` steps in
`27.07 s` on a `75 x 69 x 66` grid with minimum population `1.516e-8` and
near-wing/global residuals `8.929e-4/1.071e-3`. D=12 completes `5,664` steps
in `106.09 s` on a `112 x 103 x 99` grid with minimum population `7.330e-4`
and residuals `4.005e-4/6.287e-4`. Each archive contains all 187 registered
force bins; D=16 is not rerun.

The locked discriminator fails. Force-history difference falls monotonically
from `0.127045` at D8-to-D12 to `0.0626834` at D12-to-D16, a `2.027x`
reduction. D12-to-D16 mean and impulse differences are both `0.010576` and
pass `0.05`, but the force-history difference exceeds `0.05` by `0.0126834`.
The CLI therefore archives the report and exits nonzero. The independent audit
reconstructs every D8/D12 per-step ledger equation, all 374 force bins, source
hashes, both trend vectors, and the rejected gate; all audit checks pass. This
is a verified negative result, not spatial convergence. Production,
experimental agreement, and free flight remain blocked.

The next allocation decision must first use the existing archives to localize
the phase-resolved D12-to-D16 discrepancy. A D=20 run is justified only if
that zero-simulation diagnostic shows a smooth distributed truncation trend,
not a localized topology or force-accounting event.

Run the frozen archive-only localization and its independent reconstruction:

```bash
python3 Scripts/analyze-dove-moving-wall-spatial-localization.py
python3 Scripts/audit-dove-moving-wall-spatial-localization.py
```

The diagnostic uses only computed D12/D16 registered force histories,
per-step topology-reservoir corrections, and near-wing/global closure
residuals. Measured-force error is absent from every classification and
allocation expression. Before evaluating the archives, it fixes three
concentration classes, adjacent-bin and non-DC spectral smoothness limits,
topology projection/correlation limits, a maximum `25%` ledger-residual to
force-difference ratio, and a maximum `1.5x` fine-grid miss ratio for a D20
allocation.

The result does not authorize D20. The `6.26834%` force-history difference has
a mixed concentration: 27 of 187 bins produce half its squared norm, the top
10% of bins produce `42.54%`, and the strongest contiguous 5 ms window
produces only `16.81%`. It is therefore not one localized phase event, but it
also fails the distributed effective-bin threshold (`59.55/187 = 31.84%`).
More importantly, its normalized adjacent-bin roughness is `1.35139` and
`50.267%` of the non-DC spectral energy lies in the upper half of resolved
frequencies, failing the frozen `0.5/15%` smoothness limits.

This roughness is not attributed to the already-cleared accounting path. The
near-wing and global residual-difference RMS values are only `0.375%` and
`0.749%` of the force-difference RMS. Nor is it a topology spike: least-squares
topology correction explains `12.62%`, magnitude correlation is `0.209`, and
top-10% rank overlap is `21.05%`, all below their event thresholds. The
independent audit reconstructs all 187 bins, source hashes, concentration,
windows, spectrum, topology projection, accounting ratios, classification,
and rejected D20 decision; all 11 checks pass.

This narrows the next zero-simulation question to temporal structure. A
source-locked lag/band discriminator should determine whether the rough
fine-pair difference is sub-bin phase/registration sensitivity or broadband
grid-dependent force-estimator noise. It may not retroactively pass the raw
`5%` spatial gate. D20 remains unjustified until that distinction is made.

Run that frozen discriminator and its independent reconstruction:

```bash
python3 Scripts/analyze-dove-moving-wall-spatial-lag-band.py
python3 Scripts/audit-dove-moving-wall-spatial-lag-band.py
```

The lag search is fixed to `-0.5...+0.5` registered bins in `0.01`-bin
increments and uses five contiguous held-out folds. A registration mechanism
requires at least `0.05` bin shift, `20%` cross-validated improvement,
consistent sign, and at most `0.15`-bin fold standard deviation. The
nonperiodic DCT-II discriminator evaluates fixed `50/100/200/400/1000 Hz`
low-pass bands. The 200 Hz decision band may be called broadband estimator
noise only if it retains at least `99%` of combined D12/D16 force energy while
meeting the unchanged raw-difference evidence rules. No filtered history can
replace or retroactively pass the preregistered raw metric.

The best global shift is `-0.02` bin (`-10 us`). Held-out comparison improves
only from `0.0623413` to `0.0614027`, or `1.506%`, despite stable fold lags
`[-0.01, -0.02, -0.01, -0.02, -0.02]`. Sub-bin registration sensitivity is
therefore rejected. At 200 Hz the difference falls to `0.0425302`, but the
filtered histories retain only `74.2699%` of combined force energy, far below
the frozen `99%` requirement. That result cannot distinguish discarded
physical grid response from force-estimator noise. Neither broadband noise nor
coherent low-band bias is accepted, the classification is `mixed-unresolved`,
the raw `0.0626834 > 0.05` rejection remains authoritative, and D20 is still
blocked. The independent audit reconstructs all five folds, five DCT bands,
187 decision-band vectors, source hashes, classification, and allocation
decision; all 11 checks pass.

The next diagnostic isolates estimator sampling from evolving flow. Its rules
are archived before either grid is run:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-temporal-preregister \
  --spatial-discriminator ValidationArtifacts/deetjen-dove-moving-wall-spatial-discriminator.json \
  --lag-band ValidationArtifacts/deetjen-dove-moving-wall-spatial-lag-band.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-temporal-sampling \
  --spatial-discriminator ValidationArtifacts/deetjen-dove-moving-wall-spatial-discriminator.json \
  --lag-band ValidationArtifacts/deetjen-dove-moving-wall-spatial-lag-band.json \
  --temporal-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling.json

python3 Scripts/audit-dove-moving-wall-temporal-sampling.py
```

The locked phase is source sample 53 at `26.5 ms`, the largest single-bin
contributor in the preceding localization. Geometry and deposited wall
velocity are held constant for eight physical 0.5 ms bins; D12 records 24 and
D16 records 32 conservative-force substeps per bin. This deliberately
nonphysical treadmilling-surface test removes topology and changing measured
kinematics while preserving physical grid, thickness, viscosity-floor, sponge,
collision operator, moving-wall normalization, and momentum-ledger definitions.
Temporal aggregation sensitivity requires direct-impulse D12/D16 history at or
below `5%`, endpoint history above `5%`, and at least `20%` improvement.
Aggregation-invariant grid disagreement requires all three histories above
`5%` with no more than `10%` relative estimator spread. Neither result can
modify the raw moving-window gate or authorize D20.

The two numerical cases complete in `2.84 s` and `7.89 s` (`10.82 s` command
wall time). Their near-wing/global relative RMS residuals are
`0.0196%/0.0280%` and `0.0254%/0.0360%`; minimum populations are
`0.01046/0.01120`. Every topology-reservoir correction is exactly zero, and
direct-versus-binned impulse identity closes to `8.02e-17` relative error.

Endpoint D12/D16 history differs by `19.5868%`. Sample-centered trapezoidal
and direct impulse-preserving histories differ by `9.7600%` and `9.4871%`, so
impulse aggregation removes `51.56%` of the endpoint disagreement but does not
reach the frozen `5%` criterion. The complete eight-bin impulses differ by
only `0.8639%`, showing substantial cancellation that a single history metric
must not hide. The locked classification is therefore `mixed-unresolved`, not
temporal-aggregation-sensitive or fixed-grid-cleared. The independent audit
reconstructs source hashes, both per-step ledgers, all 16 bins and three
quadratures, impulse identity, zero topology, metrics, classification, and
claim boundary; all 13 checks pass.

The same-phase 24-bin duration extension is frozen and run as follows:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-temporal-duration-preregister \
  --temporal-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling-preregistration.json \
  --temporal-sampling ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-temporal-duration \
  --spatial-discriminator ValidationArtifacts/deetjen-dove-moving-wall-spatial-discriminator.json \
  --lag-band ValidationArtifacts/deetjen-dove-moving-wall-spatial-lag-band.json \
  --temporal-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling-preregistration.json \
  --temporal-sampling ValidationArtifacts/deetjen-dove-moving-wall-temporal-sampling.json \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json

python3 Scripts/audit-dove-moving-wall-temporal-duration.py
```

The extension independently restarts both grids and must reproduce all first-
eight-bin endpoint, sample-trapezoidal, impulse-mean, and direct-impulse
vectors within `1e-12` relative error. It then reports prefixes 8/16/24 and
non-overlapping blocks 0–8/8–16/16–24. Duration clears only if the 24-bin
impulse-history and cumulative-impulse differences both pass 5%. Startup
relaxation requires the late block to pass 5% with at least 20% improvement.
Persistent bias requires all three blocks to fail and less than 20% late-block
improvement. These rules and all source hashes precede the extension run.

The baseline prefix reproduces exactly (`0` relative error). The
impulse-preserving prefix differences are `0.0948712`, `0.0992872`, and
`0.0996112`; cumulative-impulse differences are `0.00863853`, `0.0297160`,
and `0.0471626`. The blockwise force-history differences are `0.0948712`,
`0.282082`, and `0.123791`. Thus the late block remains above 5% and is
`30.48%` worse than the first rather than improving. The locked classification
is `persistent-fixed-wall-grid-disagreement`, not startup relaxation or
duration clearance.

D12 completes 576 steps in `8.45 s`; D16 completes 768 in `24.04 s`. Minimum
populations are `0.00753/0.01120`, near-wing residuals are
`0.0286%/0.0427%`, global residuals are `0.0593%/0.0685%`, and topology
correction remains exactly zero. The independent audit reconstructs all 1,344
substep forces, 48 bins, every prefix/block quadrature and impulse, exact
baseline reproduction, both ledgers, the classification, and D20 rejection;
all 13 checks pass.

The same-phase geometry/link discriminator is frozen and run as follows:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-geometry-preregister \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --temporal-duration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-geometry \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --temporal-duration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json \
  --link-geometry-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json

python3 Scripts/audit-dove-moving-wall-link-geometry.py
```

This path advances no fluid and allocates no populations. It reconstructs the
production solid-to-fluid link convention, `q = d_f/(d_f-d_s)`, and
`6 w_q dx^2` link measure directly from D12/D16 Metal rasters, repeats the
entire calculation from the CPU raster, and compares per-component wall
moments with a resolution-independent thickened-triangle D3Q19 quadrature.
The version-2 contract documents one pre-result correction: its draft `1e-5`
pointwise wall tolerance was tighter than the already archived `2.1819e-5`
geometry-parity envelope. The accepted contract uses `5e-5` plus a stronger
`0.5%` limit on every complete link aggregate; none of the D12/D16 scientific
limits changed.

The cases complete in `1.93 s` and `3.06 s`. Both have zero occupancy
mismatches and exact link-count parity; worst aggregate CPU/Metal differences
are `0.0985%` and `0.1815%`. D12→D16 total and maximum-component physical
link measures change by `1.362%` and `2.301%`; total and maximum-component
interpolation-histogram variation are `3.143%` and `6.898%`; mean wall
velocity changes by at most `0.418%` of quadrature RMS and RMS speed by
`0.271%`. All of those clear their frozen limits.

The maximum link-to-quadrature mean-velocity error is `10.742%`, however,
above the frozen `10%` limit. It is the left wing and persists at `10.379%`
on D16, so the locked result is `wall-velocity-deposition-bias`, not link-area
or interpolation bias. The independent audit reconstructs source hashes, all
144 Metal/CPU direction-component bins, link aggregates, the triangle and cap
quadrature from the binary surface, cross-grid metrics, classification, and
D20 rejection; all 13 checks pass.

The velocity-deposition A/B is frozen and run without fluid as follows:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-velocity-preregister \
  --link-geometry-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-preregistration.json \
  --link-geometry ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-velocity-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-velocity \
  --link-geometry-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-preregistration.json \
  --link-geometry ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json \
  --link-velocity-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-velocity-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-velocity.json

python3 Scripts/audit-dove-moving-wall-link-velocity.py
```

For each archived production link the gate compares solid-node velocity,
`q*u_solid + (1-q)*u_fluid`, and the exact same-component triangle-barycentric
velocity at `x_solid + (1-q)c_q dx`; production `q` is measured from the fluid
node. The accepted run reconstructs candidate A from the hashed 72 direction-
component bins exactly, while the new raster independently preserves every
link count. This avoids treating floating-point replay order as a physics
difference.

D12/D16 complete in `7.56 s` and `13.66 s`. Exact barycentric sampling does
not reduce the left-wing discrepancy: the worst production mean error is
`10.742%`, exact-intersection error is `10.783%`, and endpoint interpolation
worsens it to `11.430%`. Exact and endpoint D12/D16 mean differences remain
small (`0.511%` and `1.264%`), so this is not an emerging fine-grid split.

The reconstructed points have only `0.0696`-cell worst-component RMS error
against the physical 7.5 mm offset surface, below the frozen `0.10` limit, but
the maximum is `0.8742` cell against `0.75`. The locked classification is
therefore `signed-distance-intersection-placement-bias`: the contract does not
allow the velocity-sampling hypothesis to clear while link placement contains
these outliers. Endpoint interpolation, exact-intersection velocity, any
production modification, fluid allocation, and D20 all remain unauthorized.
The independent audit reconstructs all 144 direction-component bins,
candidate moments, source production identity, cross-grid metrics, placement
limits, classification, and claim boundary; all 13 checks pass.

The sparse-outlier localization is frozen and run without fluid as follows:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-intersection-preregister \
  --link-velocity-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-velocity-preregistration.json \
  --link-velocity ValidationArtifacts/deetjen-dove-moving-wall-link-velocity.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-intersection-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-intersection \
  --link-velocity-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-velocity-preregistration.json \
  --link-velocity ValidationArtifacts/deetjen-dove-moving-wall-link-velocity.json \
  --link-intersection-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-intersection-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-intersection.json

python3 Scripts/audit-dove-moving-wall-link-intersection.py
```

The Apple M4 cases complete in `0.152 s` and `0.249 s`. They reproduce all
`25,262` D12 and `45,514` D16 source links and both source maximum residuals
exactly. Only eight and seven links exceed `0.75` cell, respectively:
`0.0251%` and `0.0122%` of total link measure. Every outlier record includes
component, direction, solid and fluid cells, production `q`, world-space
intersection, nearest triangle and barycentrics, signed residual, triangle
feature, true mesh-boundary incidence, and nearest alternate component.

No outlier lies on a true mesh boundary. Seven of eight D12 outliers and all
seven D16 outliers are within `0.25` cell of another component's physical
offset surface, producing a minimum `87.5%` edge-or-junction measure
association against the frozen `80%` rule. This association is specifically a
component-junction result, not a mesh-edge result. Dominant directions differ
(`14` on D12, `13` on D16) and contain only `25.0%` and `28.6%` of outlier
measure, so the frozen stencil-direction rule does not trigger. The locked
classification is `mesh-edge-or-component-junction-associated`; it is an
association, not proof of a causal repair.

The independent audit decodes the source float32 position stream and uint16
topology, reconstructs the `26.5 ms` interpolated mesh, scans nearest triangles
and alternate components, verifies true edge incidence, checks each lattice
direction and production `q`, reconstructs both case summaries and the
cross-grid classification, and validates the source hash chain. All 13 checks
pass. No production change, fluid evolution, D20 allocation, or experimental
claim is authorized.

The exact owner-component/global-union ray-root A/B is frozen and run with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-ray-root-preregister \
  --link-intersection-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-intersection-preregistration.json \
  --link-intersection ValidationArtifacts/deetjen-dove-moving-wall-link-intersection.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-ray-root \
  --link-intersection-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-intersection-preregistration.json \
  --link-intersection ValidationArtifacts/deetjen-dove-moving-wall-link-intersection.json \
  --link-ray-root-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root.json

python3 Scripts/audit-dove-moving-wall-link-ray-root.py
```

The contract reconstructs each solid/fluid segment and production `t=1-q`,
then scans from fluid toward solid in 256 fixed intervals and bisects the
fluid-nearest outside-to-inside bracket 48 times. Candidate B uses only the
solid cell's source component; candidate C uses the production raster's true
global union over all component triangles. Both solve distance-to-mid-surface
minus the physical 7.5 mm half-thickness. Roots must close within `1e-5` cell,
and global-union placement retains the prior `0.10`-cell measure-weighted RMS
and `0.75`-cell maximum limits. Calling owner-surface diagnosis causal also
requires at least `80%` RMS reduction.

D12/D16 finish in `0.043 s` and `0.029 s`. Every one of the 15 links changes
nearest component between its solid and fluid endpoints, and every fluid
endpoint uses the alternate component recorded by the localization. The
production formula is therefore linearly interpolating signed distances from
two distinct surfaces. The exact global-union junction-root RMS shifts are
`0.5194` cell on D12 and `0.9435` on D16; their maxima are `0.8860` and
`1.1359` cells. Both RMS values fail `0.10`, and both maxima fail `0.75`.
D12's global union reduces owner-root RMS by only `38.42%`; D16's global roots
are all owner-component roots, giving zero reduction. Only five of 15 global
roots switch away from the source component despite all 15 endpoint component
changes.

Root closure reaches `6.985e-7` cell, safely below `1e-5`. The independent
NumPy audit decodes the source binary mesh, implements a separate vectorized
point-to-triangle distance function, repeats both reverse scans and bisections,
reconstructs all sample and cross-grid metrics, verifies all 15 endpoint
component changes, and passes all 13 checks. The locked classification is
`junction-global-root-linearization-bias`. This rejects the tempting
interpretation that the prior residual was merely measured against the wrong
owner surface; production `q`, D20, fluid evolution, and the raw spatial gate
remain unchanged.

The q-dependent coefficient discriminator is frozen and run with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-coefficient-preregister \
  --link-ray-root-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root-preregistration.json \
  --link-ray-root ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-coefficient \
  --link-ray-root-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root-preregistration.json \
  --link-ray-root ValidationArtifacts/deetjen-dove-moving-wall-link-ray-root.json \
  --link-coefficient-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient.json

python3 Scripts/audit-dove-moving-wall-link-coefficient.py
```

The frozen five-term coefficient vector maps unit-scaled reflected,
farther-outgoing, previous-incoming, and fluid/solid endpoint wall-projection
primitives to the reconstructed population after factoring the common
moving-wall weight/density scale. For `q<=0.5` it is
`[2q, 1-2q, 0, 1-q, q]`; for `q>0.5` it is
`[1/(2q), 0, (2q-1)/(2q), (1-q)/(2q), 1/2]`, exactly matching the production
Metal branches. A dynamically insignificant result requires zero branch
changes, at most `0.10` measure-weighted RMS L1 change, at most `0.25` maximum
L1 change, and no more than a `1.10x` symmetric operator-norm ratio on either
grid.

The calculation completes in less than `0.04 ms`. Production linear `q` is in
the near branch for all 15 links, while exact global-union `q` moves `3/8` D12
and `7/7` D16 links to the far branch. Branch-changing measure is `37.5%` of
the D12 outlier set and `100%` of D16. The measure-weighted coefficient L1
change is `1.723/2.782`, the maximum is `2.824/3.189`, and the largest single
coefficient changes by `0.9515`; all exceed the frozen insensitivity envelope.
The maximum symmetric operator-norm ratio is `1.294`. A separate Python
implementation reconstructs all sample coefficients, summaries, cross-grid
metrics, source hashes, classification, and safety boundary with all 12 checks
passing.

The locked classification is `branch-changing-coefficient-sensitive`. It
establishes algebraic capacity for a material population change but not force
causality, because the actual reflected/auxiliary populations, wall projection,
and local density were intentionally absent. Production, D20, fluid evolution,
and the raw spatial rejection remain unchanged. The highest-ROI next step is a
single frozen-phase D12 capture of those five production primitives on the 15
links, followed by an offline production-q/exact-q population and momentum-
exchange replay. Why: it measures realized rather than worst-case sensitivity.
ROI: one short source-state capture and 30 local evaluations can accept or
reject a boundary fluid A/B before changing the kernel or paying for a full
refinement run.

The production-primitive discriminator is frozen and run with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-population-preregister \
  --link-coefficient-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient-preregistration.json \
  --link-coefficient ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient.json \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --temporal-duration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-link-population \
  --link-coefficient-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient-preregistration.json \
  --link-coefficient ValidationArtifacts/deetjen-dove-moving-wall-link-coefficient.json \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --temporal-duration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json \
  --link-population-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback.json

python3 Scripts/audit-dove-moving-wall-link-population-fallback.py
```

The full `576`-step D12 window captures reflected, farther-outgoing,
previous-incoming, pre-step density, and both endpoint wall-projection
primitives on all eight D12 outliers. This is `4,608` link-step samples, not a
selected snapshot. The diagnostic never writes geometry or populations. It
reconstructs conventional mode-6 link force and torque from the captured state
and substitutes exact global-union `q` offline.

The initial schema-1 replay is retained as failed evidence. Its production
population algebra closed within `3.32e-9`, but its production-`q` provenance
failed by `0.4928`: four links had correctly fallen back to halfway because
their near-wall branch required a farther node that was solid. Applying exact
`q` to the unavailable farther population would invent state. Revision 2 was
therefore frozen before rerun, retained the original `10%` population,
`10%` outlier-force, `1%` global-force, and `1%` global-impulse gates, and
recorded four expected production fallbacks. Three exact roots exceed `0.5`
and can use the far-wall branch; the remaining exact root is below `0.5` and
must retain halfway fallback. This changes feasibility, not a science limit.

The fallback-aware replay completes in `10.02 s`. It records zero source
mismatches, a `2.03e-9` maximum effective-`q` difference, a `3.32e-9` maximum
production-population difference, minimum population `0.00753`, zero limiter
activation, and near-wing/global momentum residuals `2.86e-4`/`5.93e-4` under
the unchanged `0.005` gate. Exact `q` changes population by `1.822%` relative
RMS and the eight-link force by `1.094%` relative RMS, both below `10%`.
The delta is `0.01012 N` RMS, only `0.1085%` of the `9.323 N` global force RMS;
its impulse is `0.4428%` of global impulse, both below `1%`.

The independent standard-library Python audit does not consume Swift summary
logic. It reconstructs all `4,608` populations, wall corrections, link forces,
link torques, `576` step reductions, RMS values, and impulses from the raw
primitives and D3Q19 constants. It verifies every source hash, numerical gate,
fallback branch, original failed archive, revision rationale, classification,
and safety field; all 12 checks pass. The locked result is
`realized-population-insensitive`. It rejects both a D12 exact-root boundary
A/B and a D16 sparse-link replay, leaves D20 blocked, and makes no production
change or experimental-agreement claim.

### Distributed full-link force attribution

The distributed experiment was frozen before execution and run with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-distributed-force-preregister \
  --link-geometry-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-preregistration.json \
  --link-geometry ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --temporal-duration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json \
  --link-population-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-preregistration.json \
  --link-population ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback.json \
  --link-population-audit ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-audit.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-distributed-force \
  --link-geometry-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-geometry-preregistration.json \
  --link-geometry ValidationArtifacts/deetjen-dove-moving-wall-link-geometry.json \
  --temporal-duration-preregistration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration-preregistration.json \
  --temporal-duration ValidationArtifacts/deetjen-dove-moving-wall-temporal-duration.json \
  --link-population-preregistration ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-preregistration.json \
  --link-population ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback.json \
  --link-population-audit ValidationArtifacts/deetjen-dove-moving-wall-link-population-fallback-audit.json \
  --distributed-force-preregistration ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-distributed-force.json

python3 Scripts/audit-dove-moving-wall-distributed-force.py
```

The capture is read-only and dispatches once per production boundary link
immediately before collision. It uses the same populations, signed distance,
wall velocity, pre-step local density, interpolation branches, and physical
force conversion as production. It separates conventional mode-6 exchange
into `-2 f_reflected c`, `-wallCorrection c`, and the remaining interpolation
term. Host aggregation retains 24 temporal bins and joint component × D3Q19
direction × 20-bin `q` summaries; it does not archive the full lattice.

D12 captures all `25,262` links for `576` steps in `9.68 s`; D16 captures all
`45,514` links for `768` steps in `25.67 s`. Both have zero metadata and static
classification mismatches. Maximum per-link algebraic closure is
`5.96e-8 N`/`2.98e-8 N`; reconstructed force closes to production at
`6.31e-6`/`5.01e-6` relative RMS; and the independently restarted 24-bin
histories reproduce the duration archive within `1.69e-5`/`2.62e-5`. Both
positivity and momentum-closure gates pass.

The total D12/D16 pairwise force difference is `9.9611%`. Base reflection has
`89.90%` full-window signed alignment, moving wall `29.78%`, and interpolation
residual `-19.68%`; the terms cancel substantially because their individual
delta RMS values are `2.57×`, `2.13×`, and `0.60×` the total-delta RMS. The
non-overlapping eight-bin winners are base reflection, moving wall, and moving
wall. The base-reflection winner therefore fails the preregistered requirement
to remain the at-least-`60%` winner in all three blocks. No component,
direction, or `q` bin supplies `60%` of absolute aligned contribution, and
`518` of `1,440` active joint bins are needed to reach `80%`.

The independent Python implementation recomputes source hashes, contract and
case gates, temporal/spatial algebra, duration reproduction, total and per-term
cross-grid metrics, block winners, axis concentration, joint-bin concentration,
classification, and safety fields. All 14 checks pass. The locked result is
`mixed-term-distributed-grid-bias`: it rejects a single-term correction, leaves
D20 and production changes blocked, and does not weaken the raw spatial or
experimental-agreement gates.

### Archive-only force-term covariance

The pairwise energy/covariance contract was frozen before evaluating the
archived term histories:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-force-covariance-preregister \
  --distributed-force-preregistration ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-preregistration.json \
  --distributed-force ValidationArtifacts/deetjen-dove-moving-wall-distributed-force.json \
  --distributed-force-audit ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-audit.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-force-covariance \
  --distributed-force-preregistration ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-preregistration.json \
  --distributed-force ValidationArtifacts/deetjen-dove-moving-wall-distributed-force.json \
  --distributed-force-audit ValidationArtifacts/deetjen-dove-moving-wall-distributed-force-audit.json \
  --force-covariance-preregistration ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-force-covariance.json

python3 Scripts/audit-dove-moving-wall-force-covariance.py
```

For each force term, the analysis forms the 24-vector D16-minus-D12 history.
It exactly decomposes total mean-squared delta into three self energies and
three doubled pair interactions. Each pair dot product is then split into the
trace of centered covariance and the dot product of its mean vectors. The
dominant pair was preregistered as robust only if it supplied at least `50%`
absolute full-window interaction, remained the largest pair with the same sign
in all three eight-bin blocks, and supplied at least `30%` in every block. A
centered or mean mechanism required `60%` of the pair's absolute decomposition.

The archived term sum reconstructs the total grid delta within `1.163e-6 N`.
Raw, centered, and mean energy identities close at `1.777e-7`, `1.506e-7`, and
`1.541e-6` relative error, respectively. Base reflection plus moving wall is
the dominant interaction in all three blocks and is canceling throughout. Its
full interaction fraction is `-9.40036`; block fractions are `-3.73230`,
`-32.44041`, and `-163.20663`. Values with magnitude above one are physically
and algebraically possible here because the normalized total is the much
smaller residual after large self energies and pair interactions cancel.

The dominant pair's centered covariance is small and positive, while its mean
dot product is strongly negative. The absolute centered/mean split is
`1.676%`/`98.324%`, clearing the frozen `60%` mean-offset criterion. A separate
standard-library Python implementation reconstructs all term means, self
energies, pair dots, block fractions, centered/mean identities, hashes, gates,
classification, and safety fields; all nine checks pass. The locked result is
`robust-canceling-mean-offset-dominated-pair-covariance`.

This result is stronger than marginal term ranking but still diagnostic: it
identifies an opposing mean-force pair, not which spatial population class or
boundary primitive creates it. It performs no Metal dispatch, changes no
production physics, leaves D20 blocked, and does not relax the raw spatial or
experimental-agreement gates.

### Exact spatial allocation of the dominant mean interaction

The complete within- and cross-bin allocation was frozen and executed with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-spatial-interaction-preregister \
  --distributed-force ValidationArtifacts/deetjen-dove-moving-wall-distributed-force.json \
  --force-covariance-preregistration ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-preregistration.json \
  --force-covariance ValidationArtifacts/deetjen-dove-moving-wall-force-covariance.json \
  --force-covariance-audit ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-audit.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-spatial-interaction-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-grid-moving-wall-spatial-interaction \
  --distributed-force ValidationArtifacts/deetjen-dove-moving-wall-distributed-force.json \
  --force-covariance-preregistration ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-preregistration.json \
  --force-covariance ValidationArtifacts/deetjen-dove-moving-wall-force-covariance.json \
  --force-covariance-audit ValidationArtifacts/deetjen-dove-moving-wall-force-covariance-audit.json \
  --spatial-interaction-preregistration ValidationArtifacts/deetjen-dove-moving-wall-spatial-interaction-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-moving-wall-spatial-interaction.json

python3 Scripts/audit-dove-moving-wall-spatial-interaction.py
```

A same-bin product would omit cross-bin cancellation. Instead, for reflection
delta `r_i`, moving-wall delta `w_i`, and global term means `R` and `W`, each
joint bin receives the symmetric contribution
`c_i = r_i dot W + w_i dot R`. Summing all `c_i` exactly recovers
`2 R dot W`; no `1,440²` pair matrix or arbitrary cross-bin assignment is
needed. The frozen gate names an axis only at `60%` absolute contribution and
authorizes a future primitive capture only when at least two axes pass and
`80%` of interaction fits within at most `20%` of active joint bins.

The D12/D16 spatial sums reproduce both covariance term means within
`2.47e-14 N`; the symmetric interaction closes within `1.12e-14` relative.
No axis approaches `60%`. The leading component is left wing at `44.386%` of
absolute interaction, the leading stencil direction is direction 2 at
`10.192%`, and the leading interpolation class is `q` bin 13 at `10.490%`.
Reaching `80%` requires `591` of all `1,440` active joint bins, exceeding the
frozen `20%` concentration limit. Exactly `720` bins support and `720` oppose
the global cancellation; their absolute split is `50.102%` versus `49.898%`.

Sorted reductions make both the Swift report and Python audit byte-stable
across independent processes. The Python implementation reconstructs source
hashes, both term means, complete symmetric allocation, all axis summaries,
every joint-bin vector and contribution, concentration, classification, and
safety locks; all nine checks pass. The classification is
`distributed-spatial-mean-cancellation`. A targeted primitive capture, D20,
and production modification are all rejected.

### Source-property and Reynolds convention audit

The archive-only source-scaling audit consumes the version-of-record article,
the SHA-locked deposited `MuscleModel.m`, selected-bird wing span and area,
selected-flight derived blade-element velocities, and the existing surface and
grid artifacts. It dispatches no Metal work and advances no fluid state.

Reproduce it after selective source acquisition:

```bash
python3 Scripts/acquire-dove-benchmark.py \
  --download --include-force-code \
  --output /tmp/deetjen-ob-f03-source --json

curl -L https://elifesciences.org/articles/89968.pdf \
  -o /tmp/deetjen-elife-89968.pdf
pdftotext -layout /tmp/deetjen-elife-89968.pdf \
  /tmp/deetjen-elife-89968.txt

python3 Scripts/build-dove-source-scaling.py \
  --preregister \
  --source-root /tmp/deetjen-ob-f03-source \
  --article-pdf /tmp/deetjen-elife-89968.pdf \
  --article-text /tmp/deetjen-elife-89968.txt

python3 Scripts/build-dove-source-scaling.py \
  --evaluate \
  --source-root /tmp/deetjen-ob-f03-source \
  --article-pdf /tmp/deetjen-elife-89968.pdf \
  --article-text /tmp/deetjen-elife-89968.txt

python3 Scripts/audit-dove-source-scaling.py \
  --source-root /tmp/deetjen-ob-f03-source \
  --article-pdf /tmp/deetjen-elife-89968.pdf \
  --article-text /tmp/deetjen-elife-89968.txt
```

The source code fixes `rho=1.18 kg/m^3` and `mu=1.849e-5 Pa s`, giving
`nu=1.56694915e-5 m^2/s`. The solver constants, D8 source relaxation
`tau+=0.5000146901`, and all three `68.07195x` effective/source viscosity ratios
reconstruct within the frozen `2e-7` relative tolerance. The paper itself does
not publish a Reynolds number or same-flight ambient temperature, pressure, or
humidity. Standard dry-air inversions place the constant pair near
`26.0...27.5 C` and one atmosphere, but the audit marks that only as a
plausibility inference, never a measurement.

The selected bird's deposited `0.0164165 m^2` single-wing area and
`0.218591 m` radius give a mean chord of `0.0751015 m`. Combining that with the
deposited `21.3687 m/s` maximum blade-element speed gives an author-data proxy
`Re=102,417`. BirdFlow's converted `25.2304 m/s` maximum point speed and fixed
`0.08 m` engineering length give source-property `Re=128,813`. Length differs
only `6.522%`, but speed differs `18.072%` and their Reynolds products differ
`25.773%`, failing the frozen `10%/15%` interchangeability gates. The result is
`source-fluid-properties-confirmed-engineering-reynolds-not-published`.

At fixed Courant scaling, source-viscosity `tau+` is `0.50001469`,
`0.50002204`, and `0.50002938` for D8/D12/D16. D20 remains below the unchanged
`0.50005` Float margin; D28 is the first eligible integer grid. The independent
implementation re-reads all four primary source files, reproduces the article
evidence and every equation, and passes all ten checks. No source-viscosity run,
D20 allocation, production change, or experimental agreement is authorized.

### Source-viscosity collision survival and first admissible grid

The source-viscosity follow-up keeps the normal public `tau+>=0.50005`
constructor unchanged. D16 is admitted only through a package-scoped,
preregistered diagnostic floor of `0.50002`; D28 uses the normal constructor.
Reproduce the locked chain locally:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d16-preregister \
  --source-scaling ValidationArtifacts/deetjen-dove-source-scaling.json \
  --source-scaling-audit ValidationArtifacts/deetjen-dove-source-scaling-audit.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d16-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d16-ab \
  --source-scaling ValidationArtifacts/deetjen-dove-source-scaling.json \
  --source-scaling-audit ValidationArtifacts/deetjen-dove-source-scaling-audit.json \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d16-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d16-ab.json

python3 Scripts/audit-dove-source-viscosity-d16.py

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d28-preregister \
  --source-d16-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d16-preregistration.json \
  --source-d16-report ValidationArtifacts/deetjen-dove-source-viscosity-d16-ab.json \
  --source-d16-audit ValidationArtifacts/deetjen-dove-source-viscosity-d16-audit.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d28-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d28-pre-roll \
  --source-d16-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d16-preregistration.json \
  --source-d16-report ValidationArtifacts/deetjen-dove-source-viscosity-d16-ab.json \
  --source-d16-audit ValidationArtifacts/deetjen-dove-source-viscosity-d16-audit.json \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d28-pre-roll.json

python3 Scripts/audit-dove-source-viscosity-d28.py

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d28-full-window-preregister \
  --source-d28-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-preregistration.json \
  --source-d28-pre-roll ValidationArtifacts/deetjen-dove-source-viscosity-d28-pre-roll.json \
  --source-d28-audit ValidationArtifacts/deetjen-dove-source-viscosity-d28-audit.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d28-full-window \
  --source-d28-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-preregistration.json \
  --source-d28-pre-roll ValidationArtifacts/deetjen-dove-source-viscosity-d28-pre-roll.json \
  --source-d28-audit ValidationArtifacts/deetjen-dove-source-viscosity-d28-audit.json \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window.json

python3 Scripts/audit-dove-source-viscosity-d28-full-window.py
python3 Scripts/analyze-dove-source-viscosity-d28-force.py

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d32-preregister \
  --source-d28-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-preregistration.json \
  --source-d28-full-window-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window-preregistration.json \
  --source-d28-full-window-report ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window.json \
  --source-d28-full-window-audit ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window-audit.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d32-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d32-pre-roll \
  --source-d28-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-preregistration.json \
  --source-d28-full-window-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window-preregistration.json \
  --source-d28-full-window-report ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window.json \
  --source-d28-full-window-audit ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window-audit.json \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d32-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d32-pre-roll.json

python3 Scripts/audit-dove-source-viscosity-d32.py

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d32-full-window-preregister \
  --source-d32-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d32-preregistration.json \
  --source-d32-pre-roll ValidationArtifacts/deetjen-dove-source-viscosity-d32-pre-roll.json \
  --source-d32-audit ValidationArtifacts/deetjen-dove-source-viscosity-d32-audit.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window-preregistration.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-d32-full-window \
  --source-d32-preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d32-preregistration.json \
  --source-d32-pre-roll ValidationArtifacts/deetjen-dove-source-viscosity-d32-pre-roll.json \
  --source-d32-audit ValidationArtifacts/deetjen-dove-source-viscosity-d32-audit.json \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window.json

python3 Scripts/audit-dove-source-viscosity-d32-full-window.py
python3 Scripts/build-dove-source-viscosity-d28-d32-refinement.py --preregister
python3 Scripts/build-dove-source-viscosity-d28-d32-refinement.py --evaluate
python3 Scripts/audit-dove-source-viscosity-d28-d32-refinement.py
python3 Scripts/analyze-dove-source-viscosity-d28-d32-phase.py
python3 Scripts/audit-dove-source-viscosity-d28-d32-phase.py

python3 Scripts/preregister-dove-targeted-boundary-replay.py

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-targeted-boundary-case \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-preregistration.json \
  --source-targeted-full-window-report ValidationArtifacts/deetjen-dove-source-viscosity-d28-full-window.json \
  --targeted-reference-length-cells 28 \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-d28.json

.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --source-viscosity-targeted-boundary-case \
  --preregistration ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-preregistration.json \
  --source-targeted-full-window-report ValidationArtifacts/deetjen-dove-source-viscosity-d32-full-window.json \
  --targeted-reference-length-cells 32 \
  --archive ValidationArtifacts/deetjen-dove-source-viscosity-targeted-boundary-d32.json

python3 Scripts/analyze-dove-targeted-boundary-replay.py
python3 Scripts/audit-dove-targeted-boundary-replay.py
```

Both D16 candidates completed 1,600 source-viscosity steps with strictly
positive finite populations. Regularized BGK and RR3 reached minima of
`9.344e-9` and `1.049e-8`; worst near-wing/global relative RMS residuals were
`6.860e-4` and `6.584e-4`; limiter activation fractions were `1.083e-8` and
`1.648e-9`. The independent audit reconstructs all 3,200 per-step force and
momentum identities and passes 15 checks. This authorizes D28 planning only;
D16 remains below the production Float margin.

The frozen D28 selection rule minimizes the worst D16 momentum residual, then
correction activation, then maximizes minimum population. It selects RR3 before
any D28 fluid result is observed. The `259 x 238 x 229` grid contains
`14,116,018` cells, estimates `3,613,700,608` bytes of concurrent working set,
and has `tau+=0.50005144`. The Apple M4 run completed all 2,800 steps in
`740.56 s`; minimum population was `4.838e-9`, near-wing/global relative RMS
residuals were `0.0011814/0.0019461`, and correction activation was
`1.441e-7`. The independent implementation passes all 17 checks and authorized
only a preregistered single-RR3 D28 full force window.

That full-window contract was written at
`2026-07-17T05:20:32+0200`, before its output was observed, with SHA-256
`65a60560363dac6f21ba5783e794a4da3bd05b50a864c283059888b16ac9febd`.
It froze 13,216 steps, 56 steps per force bin, 187 bins, the existing `0.005`
near/global momentum gates, and the existing `0.05` correction-intrusion gate.
The Apple M4 RR3 run completed in `2,706.01 s`. Minimum population was
`4.838e-9`; near-wing/global relative RMS residuals were
`0.0008241/0.0015074`; correction activation was `1.3594e-5`; and every
registered bin was recorded. The independent Python implementation recomputes
all 13,216 step-level ledger identities, all 187 interval-mean force samples,
their aggregate means, impulses, peak time, and normalized RMS error. All 17
checks pass. The report and audit SHA-256 values are
`5d5168aee5298a2d783e39d53c9017e386577e593057aa32300cbb1ae987278e`
and `8d80288432fec231caba377fc3d1437b6874bfc4a970b74556ec32a169d055ab`.

Numerical acceptance does not imply force agreement. Joint normalized RMS
error is `2.135734`. The explicitly post-hoc component diagnosis classifies the
result as `vertical-shape-correlated-but-amplitude-biased-with-horizontal-force-mismatch`:
vertical correlation is `0.84785` with a `38.98%` high mean; horizontal
correlation is `0.34319` with a `74.52%` mean deficit. The best vertical
correlation lag is only `2 ms`. D16 over-viscous to D28 source-viscosity error
improves by just `1.718%`, but that comparison changes both grid and viscosity
and is not a convergence pair.

The same-physics D32 path was frozen and run independently. Its `296 x 271 x
261` grid contains `20,936,376` cells, estimates `5,359,712,256` bytes of
working set, and has `tau+=0.50005877`. The 3,200-step pre-roll completed in
`923.59 s`, with positive populations and both ledgers below `0.159%`; its
18-check audit authorized the separately preregistered full window. That
15,104-step Apple M4 run completed in `4,627.86 s`, retained minimum population
`4.685e-9`, closed near-wing/global ledgers at `0.0016128/0.0009644`, activated
correction in `1.4426e-5` of cell-steps, and recorded all 187 bins. Its
17-check independent audit reproduces every ledger sample, force bin,
aggregate, hash, and safety boundary. The D32 numerical gate passes; its
descriptive joint normalized RMS experimental error is `2.11686` and is not an
acceptance gate.

The D28/D32 refinement comparison was frozen after the D32 numerical report
existed but before the two force histories were compared. This timing and the
inherited `5%` limits are explicit in the preregistration. Mean-force,
impulse, and normalized peak-time differences pass at `0.7598%`, `0.7259%`,
and `0%`, but the primary phase-resolved force-history difference is `5.6322%`.
The horizontal and vertical component differences are `7.3757%` and
`4.6610%`. The fine pair therefore does not stabilize; two grids also cannot
supply observed order or Richardson uncertainty. The independent 12-check
audit reproduces the failure and explicitly leaves D36 unauthorized.

The next analysis executes no fluid. It localizes `42.67%` of total squared
pair difference to the first `0.025...0.036 s` phase band and `28.94%` of
horizontal squared difference to `0.025...0.030 s`. Horizontal/vertical
absolute difference energy is nearly even (`52.46%/47.54%`), the best
horizontal lag is zero, and difference magnitude has only `0.0131` correlation
with ordinary horizontal-force transients. Its independent 13-check audit
supports a targeted D28/D32 replay of that 5 ms interval, not D36. No
experimental-force, grid-convergence, published-Reynolds, production, or
free-flight claim is accepted.

The targeted replay was frozen before either valid run. V2 explicitly locks
the source-property Reynolds number `128812.9372` and expected D28/D32 tau
values after the first runner mistakenly used the plan Reynolds number. That
invalid V1 contract and D28 artifact are retained and labeled; the frozen
archived-force reproduction gate rejected the run at `9.380%`. V2 changes no
interval, threshold, attribution rule, or production physics. Its D28 and D32
runs completed `3,360/3,840` steps in `1,090.40/1,846.16 s`, captured every
one of the `616/704` fluid steps contributing to samples `50...60`, reproduced
all 11 archived interval means exactly, retained positive populations, and
closed near/global momentum ledgers below `0.203%`. The four force selectors
sum to the authoritative production force within `2.683e-5/3.334e-5` relative
RMS against the frozen `1e-4` limit.

The pair analysis expands D32-minus-D28 X/Z squared-difference energy into four
self contributions and all six signed pair interactions. Its independent
15-check audit reconstructs component deltas, the full ten-term ledger, both
temporal halves, hashes, gates, and claim boundary. Reflected-population self
energy is the preregistered dominant term: `58.428%` of the absolute ledger,
and it remains largest in both halves. Reflected/topology and
reflected/interpolation interactions are negative `14.682%` and `7.510%`
contributions, while moving-wall self energy is `3.290%`; therefore the result
localizes sensitivity but does not justify scaling or removing any force term.
Component-difference and squared-energy closure are `2.383e-5` and
`1.674e-6`. The next admissible experiment is selected-link provenance of the
pre-step reflected population at D28/D32; D36 and production edits remain
unauthorized.

That selected-link experiment is complete under a transparent V2 contract.
The preserved V1 capture retained only `8,192` links and covered `10.028%` of
the D28 absolute X/Z reflected score; it nevertheless passed the numerical
ledger, source-force reproduction (`8.931e-7` relative RMS), and exact
candidate-detail identity. V2 therefore changed observation capacity only,
not physics, phases, score, the `50%` gate, or the attribution rule. It appends
every positive-score production link into a `262,144`-entry bounded buffer,
requires zero overflow, and deterministically retains at most `131,072` links.

The V2 D28/D32 cases completed `3,360/3,840` steps on Apple M4 and captured all
11 endpoints. Minimum selected-score coverage is `99.9999999%/83.4524%`;
source reflected-force reproduction is `8.931e-7/9.336e-7` relative RMS; and
candidate score difference, identity mismatch, and overflow counts are zero.
Both positivity and momentum ledgers pass. The exact per-stratum midpoint
identity

`0.5(K32 + K28)(m32 - m28) + 0.5(m32 + m28)(K32 - K28)`

separates mean reflected-population history from link-composition coefficient
change for every part, lattice direction, interpolation branch, topology
class, and link-fraction bin. Algebra closes at `5.539e-16` relative RMS and
the independently accumulated Metal float-force sum agrees at `1.477e-9`.
The independent 16-check audit reconstructs the preserved negative control,
source hashes, both case gates, endpoint alignment, decomposition, three-term
signed ledger, temporal halves, and claim boundary. Near-wall link composition
is the stable dominant self term at `91.125%` of the absolute ledger;
population history is `0.216%`, and their negative interaction is `8.659%`.

This clears bulk collision/transport population history as the primary cause
of the localized D28/D32 reflected-force change. It does not by itself prove a
boundary defect or authorize a boundary edit.

The follow-on conditioned-factor discriminator was preregistered before its
outcome and executes no fluid steps. For each endpoint it reconstructs selected
reflected force as total selected-link count times the physical per-link force
scale, then conditions successively on part occupancy, lattice direction,
interpolation branch, topology class, and link-fraction bin. All `2^6 = 64`
D28/D32 hybrid states are evaluated, with pooled D28+D32 conditionals used only
when a chosen source has zero support for the parent context. Exact six-factor
Shapley values close the signed force difference and its squared-energy ledger.

Endpoint reconstruction closes at `5.627e-16` relative RMS, source-composition
reproduction at `5.632e-16`, Shapley force closure at `1.808e-16`, energy
closure at `1.169e-16`, and conditional normalization at `1.110e-16`. Maximum
pooled fallback mass is `0.07434%` against the frozen `5%` gate. Lattice
direction composition leads both temporal halves and supplies `87.6607%` of
the absolute factor ledger. Link-measure scale contributes `11.7052%` with a
cancelling sign; part occupancy, link-fraction bin, interpolation branch, and
topology class contribute `0.3341%`, `0.1459%`, `0.1443%`, and `0.0100%`.
The independent audit reconstructs the 64 states, factor Shapley values,
temporal leaders, fallbacks, hashes, and safety boundary with all 18 checks
passing.

This authorizes one minimal canonical only: an oblique planar/slab surface that
changes direction composition across resolution and subcell phase while wall
motion, interpolation branch, topology, populations, and physical area remain
fixed. It does not authorize D36, a production boundary change, grid
convergence, experimental agreement, quantitative bird-load acceptance, or
free flight.

That planar canonical is complete under the frozen V2 contract. Four X/Z plane
orientations, two resolutions (`48/64` cells per fixed physical patch), five
normal subcell phases, and two fixed population profiles produce 40 static
cases. No collision, streaming, topology, or fluid evolution occurs. Metal and
the independent CPU enumerator have zero per-direction count mismatch in every
case. All eight unchanged `5%` gates pass: maximum fine analytic-vector error
`1.28364%`, coarse/fine phase-mean response change `2.86748%`, fine phase spread
`1.18702%`, coarse/fine direction-histogram total variation `0.65695%`,
equilibrium normal-response error `0.47711%`, and equilibrium tangential
leakage `0.33192%`.

The preserved V1 result is a negative control: every response, refinement,
phase, and histogram gate passed, but exact phase-0.5 lattice-center ties were
classified differently by world-coordinate Float arithmetic on Metal and CPU.
V2 changes only the evaluation coordinates to centered cell units with the
frozen integer normal; its preregistration locks both V1 hashes. An independent
NumPy implementation reconstructs all 40 counts, vector responses, summaries,
gates, hashes, revision provenance, and safety boundary with `14/14` checks
passing. This clears basic planar D3Q19 direction weighting and authorizes no
production edit, D36 run, convergence claim, or experimental comparison.

Reproduce the frozen planar gate locally:

```bash
python3 Scripts/preregister-dove-direction-composition-canonical.py
swift build -c release --product birdflow
.build/release/birdflow validate direction-composition \
  --preregistration ValidationArtifacts/deetjen-dove-direction-composition-canonical-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-direction-composition-canonical.json \
  --json
python3 Scripts/audit-dove-direction-composition-canonical.py
```

The archived report includes runtime metadata, so rerunning with `--archive`
creates a new report hash; the preregistration generator is byte-stable across
Python hash seeds, and the audit is byte-stable for a fixed report.

The subsequent source-locked curved canonical consumes the already audited
complete-dove D12/D16 Metal and CPU link counts at source sample 53
(`26.5 ms`). It reconstructs body, left-wing, right-wing, tail, and whole-bird
direction histograms plus the same two fixed-population response ledgers. No
wall velocity, interpolation fraction, force history, collision, streaming,
topology evolution, or new Metal execution is used. Whole-surface opposite
counts and equilibrium cancellation are exact. D12-to-D16 whole histogram TV
is `0.00130179`, maximum whole-response change `9.12568e-5`, and maximum
component histogram/response changes `0.00707305/0.00711128`; every frozen gate
passes and the independent NumPy reconstruction passes `14/14` checks.

Reproduce the archive-only curved gate locally:

```bash
python3 Scripts/preregister-dove-curved-direction-composition-canonical.py
python3 Scripts/analyze-dove-curved-direction-composition-canonical.py
python3 Scripts/audit-dove-curved-direction-composition-canonical.py
```

This clears D12/D16 fixed-profile curved direction redistribution only. It does
not validate wall velocity or interpolation, establish the D28/D32 grid limit,
or authorize a fluid run or production edit.

The separately preregistered D28/D32 complete-link census then executes the
same sample-53 geometry through the production indexed Metal raster and the
independent CPU raster. It scans every current solid-to-fluid link by component
and D3Q19 direction, but allocates no populations and invokes no collision,
streaming, force, or new physics kernel. On Apple M4, the two cases complete in
`0.483 s` internally (`1.01 s` command wall time), with about `1.89 GB` peak
footprint. Metal and CPU masks and all 144 component/direction counts match
exactly. Static total-link counts are `141,018/184,542`; their differences from
the archived moving-run active-link totals are `0.7481%/0.6351%`, both below
the frozen `5%` consistency gate.

Applying the unchanged fixed-profile ledger gives D28-to-D32 whole histogram TV
`0.000656866`, maximum whole response change `1.16085e-5`, maximum component
histogram TV `0.00248144`, and maximum component response change `0.00194463`.
Opposite-direction balance and equilibrium cancellation are exact. All eight
gates and the independent `16/16`-check NumPy audit pass.

Reproduce the fine-grid gate locally:

```bash
python3 Scripts/preregister-dove-fine-direction-composition.py
swift build -c release --product birdflow
.build/release/birdflow validate fine-direction-census \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --preregistration ValidationArtifacts/deetjen-dove-fine-direction-composition-preregistration.json \
  --archive ValidationArtifacts/deetjen-dove-fine-direction-composition-census.json
python3 Scripts/analyze-dove-fine-direction-composition.py
python3 Scripts/audit-dove-fine-direction-composition.py
```

The raw census report includes runtime metadata, so rerunning it changes its
hash. This one-phase result alone does not establish phase-resolved direction
stability or bird-load convergence.

The follow-on phase-window census freezes source samples `50...60`
(`25...30 ms`) before capture and executes 22 D28/D32 geometry cases. Exact
parity V1 correctly stops on four isolated one-cell disagreements. Three are
solid/fluid sign ties whose Metal and CPU signed distances are within
`4.9e-6` cells of zero; the fourth is a wing/tail ownership tie whose distance
difference is `7.7e-6` cells. The V1 preregistration and failed census remain
immutable negative controls. V2 changes only arithmetic equivalence: at most
one tie per case, a frozen `1e-5`-cell tolerance, at most one component-link
count difference, and exact whole-surface direction counts in all 18
directions. It does not relax any physical histogram or response threshold.

All 22 cases qualify, all eight gates pass at all 11 phases, and the largest
production active-link difference is `0.7482%` against `5%`. The phase-window
maxima are `0.07833%` whole histogram TV, `0.6251%` component histogram TV,
`0.003243%` whole fixed-profile response change, and `0.5665%` component
response change. Opposite-direction balance and equilibrium cancellation are
exact. The independent implementation reconstructs the V1 stop, four tie
qualifications, every phase metric, all gates, hashes, and safety fields with
`18/18` checks passing. The source capture takes `4.06 s` internally (`4.52 s`
command wall time) on Apple M4 and executes no fluid evolution or force kernel.

Reproduce the phase-window chain locally:

```bash
python3 Scripts/preregister-dove-fine-direction-phase-window.py
.build/release/birdflow validate fine-direction-phase-window \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --preregistration ValidationArtifacts/deetjen-dove-fine-direction-phase-window-preregistration-v1-exact-parity.json \
  --archive ValidationArtifacts/deetjen-dove-fine-direction-phase-window-census-v1-exact-parity-failure.json
python3 Scripts/preregister-dove-fine-direction-phase-window-v2.py
python3 Scripts/qualify-dove-fine-direction-phase-window.py
python3 Scripts/analyze-dove-fine-direction-phase-window.py
python3 Scripts/audit-dove-fine-direction-phase-window.py
```

The first CLI command is expected to stop at the retained V1 exact-parity gate
after writing its archive. Static direction support is now cleared across the
localized interval, but wall velocity, interpolation, realized populations,
force convergence, experimental agreement, D36, and production changes remain
unauthorized. The next permitted experiment is a preregistered zero-fluid
force-bearing replay separating those remaining boundary terms over the same
samples.

## 8. Complete measured bird

The first ingestion/replay tier is implemented:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --audit-only \
  --json

.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --cycles 5 \
  --archive /path/to/specimen-replay-c12 \
  --json
```

Schema 1 requires explicit provenance, SI units, the COM-centered principal-axis
frame, study/domain conditions, registered morphometrics, and independent
left/right stroke, deviation, pitch, and tip-twist pose and physical rate
histories. Periodic cubic-Hermite interpolation supplies consistent pose and
wall velocity. Preflight rejects invalid phase order/coverage, unresolved
domain clearance, under-resolved thickness, and estimated lattice Mach above
`0.15` before Metal allocation. Archives retain the exact input bytes and
SHA-256 with per-step physical loads.

`registeredAnalyticProxyV1` remains the only *complete-bird* geometry
representation. The measured surface tier above is intentionally wing-only and
cannot satisfy schema 1. The bundled complete-bird example is a synthetic
conformance fixture. The data contract is in `Docs/MEASURED_BIRD_DATA.md`.

Acceptance:

- an actual measured dataset, rather than the conformance fixture, passes the
  preflight and its input SHA-256/provenance are retained in every archive
- for prescribed or trimmed periodic hovering/level flight, mean vertical force balances weight within study tolerance
- for prescribed or trimmed steady forward flight, mean thrust balances drag
- left/right loads agree for symmetric motion
- cycle statistics are stationary before reporting
- mean loads change below `5%` between the two finest registered grids

Status: complete-bird ingestion and total-load prescribed replay are complete,
measured right-wing surface replay is implemented separately, and opt-in
body/left-wing/right-wing/tail load plus rigid-wing actuator reporting is now
archived. The compact symmetric canonical closes part sums at `1.0877e-6`
force and `3.1474e-6` torque relative RMS; mirrored force, hinge torque, and
actuator power residuals are all below `1.505e-5` against the unchanged `2%`
gate. No actual complete measured specimen has been supplied, so complete-bird
acceptance remains open without weakening it.
The synthetic release conformance result is recorded in
`ValidationArtifacts/measured-bird-replay-summary.json`.

## 8.5 Formation Flight Observatory

The formation canonical places two accepted prescribed wings in one fluid and
compares each coupled flyer with a matched isolated control.

```bash
swift run -c release birdflow validate formation-flight \
  --chord-cells 8 --cycles 3 \
  --offset-x 0 --offset-y 0 --offset-z -4 \
  --phase-offset 0.25 \
  --archive ValidationArtifacts/formation-flight-c8-z4-phase025
```

Accounting acceptance:

- zero simultaneous leader/follower occupancy;
- finite per-owner force, root torque, signed power, and positive power;
- leader plus follower force closes to the production total below `2e-4` in
  cycle-global relative L-infinity norm;
- owner root torques shifted to the global origin close to the production total
  torque below the same `2e-4` limit;
- both isolated-control ownership reconstructions pass that closure limit; and
- the two final coupled cycles change by no more than `20%` in RMS power during
  the coarse screen.

Interaction acceptance requires a preregistered position/phase screen at eight
cells per chord, then five-cycle 12/16-cell promotion of the selected best,
neutral, and worst cells. Mean positive follower power is the primary metric.
Signed and phase-resolved power must remain archived so energy return and
load-phase shifts cannot be hidden by one scalar.

Archived coupled runs also emit a compact final-phase symmetry-plane CFD field
with signed vertical velocity, vorticity magnitude, and owner mask. Field
capture is enabled only on the target step. A one-cycle c8 observation smoke
retains exact formation accounting (`7.85e-8` force and `2.58e-6` torque
relative closure), so the native visualization cannot silently alter the
reported load or power result. A focused translating-body regression also
requires capture-disabled and capture-enabled conservative residuals and
cover/uncover event counts to be identical; it completes in under a second on
the Apple M4.

Status: the c8 three-cycle `z/c=-4`, `Δφ=0.25` case passes with zero overlap,
cycle-global relative force/torque closure of `4.65e-7` and `6.10e-6`, and a
`10.26%` last-two-cycle power difference below the frozen `20%` coarse limit.
The follower positive-power reduction is `3.69%` and system reduction is
`2.14%`. They are coarse hypotheses because the full map and 12/16-cell
refinement promotion remain open. The preregistered eight-case quick map is now
complete: all cases pass, follower positive-power
saving spans `1.21%...7.91%`, and the maximum occurs at `z/c=-3`, `Δφ=0.25`
with a `4.56%` system reduction. The worst owner closure anywhere in the screen
is `4.72e-7` force and `1.12e-5` torque. No c8 penalty was observed, so the
frozen minimum selector is the `1.21%` smallest-saving cell.
The selected five-cycle c12/c16 extrema all pass. At c16 the maximum and
minimum savings are `11.916%` and `3.738%`; final-two-cycle power differences
are `2.34%`/`2.83%`, force closure is at most `1.26e-6`, torque closure at most
`4.28e-6`, isolated closure at most `4.42e-6`, and overlap is zero. The c16
best-minus-minimum contrast is `8.178` percentage points, a `1.519`-point
(`18.57%`) change from c12. Maximum saving changes `18.77%` from c12 to c16.
The c8/c12 timing agreement therefore does not survive the fine pair: extrema
execution is complete, but absolute saving and phase contrast remain
grid-dependent and no quantitative formation-benefit claim is authorized.
The exploratory phase-refinement atlas aligns the archived c12/c16 extrema by
follower-local phase without new CFD. Its normalized power-discrimination
residual has RMS `0.0336`, peaks at phase `0.745`, and places half of its
absolute magnitude in 21 of 100 bins. The fixed `0.20...0.30` and
`0.70...0.80` midstroke bands carry `42.3%`; absolute power residual correlates
with lift/drag residuals at `0.757`/`0.760`. This localizes the next refinement
study but is explicitly not an acceptance gate or a phase-resolved saving
curve because isolated phase histories are not present in schema 1.

An audit of all 12 scout/promoted reports confirms that gates classify output
and never mutate or clamp the solver. Promoted conservation and periodicity
headroom are `36.5x` and `7.07x`; the c8 screen's smaller `1.65x` periodicity
headroom affects only hypothesis selection. Arbitrary maxima of 24
cells/chord, 20 cycles, and 12 chord offsets have been removed in favor of
device working-set, checked-arithmetic, and exact-representability limits.
Validity, non-overlap, finite-state, and conservation checks remain mandatory.
The preregistered sequential c20 stage 1 is complete. Maximum-selector saving
increases from `11.916%` at c16 to `13.341%` at c20, a `10.679%` change
relative to c20 against the frozen `5%` continuation limit. Stage 1 therefore
fails and the c20 minimum is not executed. All unchanged c20 gates pass: zero
overlap, `7.17e-7` force closure, `4.42e-6` torque closure, `3.75e-6` isolated
closure, and `2.366%` final-cycle power difference. This is a grid-convergence
failure, not an accounting or repeatability failure; quantitative formation
benefit remains unauthorized.

Twenty compact GPU-resident center-plane captures cover the two
phase-localized follower midstroke bands; their index records leader and
follower-local phase explicitly. All 21 archived slices are finite and
complete. A c8 capture-invariance smoke retained identical scientific reports
and agrees with the retired CPU slice reconstruction to `1e-9` maximum
vorticity difference. The decision, report SHA, index SHA, and every slice SHA
are retained in
`ValidationArtifacts/formation-flight-promotion/formation-flight-c20-discriminator-summary.json`.
The phase-aligned c16/c20 maximum-selector normalized-power residual has RMS
`0.0313`, maximum `0.1122` at follower phase `0.055`, and only `23.15%` of
its absolute magnitude in the prior midstroke bands. Absolute residual tracks
drag (`r=0.683`) rather than lift (`r=-0.065`).

The preregistered coupled-only c16/c20 replay around follower phase
`0.005...0.095` is now complete. Replay acceptance requires the exact source
configuration/grid/cycle length, all unchanged coupled gates, and relative RMS
difference no greater than `1e-6` across the source coupled summaries and full
100-bin power/lift/drag/force history. Both c16 and c20 differences are exactly
zero. Runtime is `1105.21 s`/`2755.89 s`, compared with `2370.26 s`/`6768.86 s`
for the complete three-case measurements: `2.37x` combined speedup and
`87.97 min` saved without changing cycles or requested phases.

After mapping c16 scalars to the c20 `200 x 260` cell-center grid and excluding
either-grid solids plus one fine-cell halo, signed vertical velocity differs by
`7.26...7.62%` normalized RMS with correlation at least `0.9972`; vorticity
differs by `19.15...23.64%`. Combined normalized residual energy within `0.5`
chord of either wing falls across the phase window and aggregates to `45.04%`.
That lies in the preregistered `40...60%` mixed band: neither boundary-local
discretization nor wake transport alone explains the fine-grid residual. The
selected local probes are phase `0.035` near `(x/c,z/c)=(1.822,1.023)` for the
boundary contribution and phase `0.095` near `(2.322,-1.135)` for the wake
contribution. The independent reconstruction passes `99/99` checks. Evidence
is archived under
`ValidationArtifacts/formation-flight-early-cycle-replay/`; quantitative
formation benefit remains unauthorized. See
`Docs/FORMATION_FLIGHT_OBSERVATORY.md`.

The two selected early-cycle phases now have an exact microscopic
momentum-exchange discriminator. A read-only Metal pass decomposes each owner
load into reflected-population, interpolation-auxiliary, moving-wall, cover,
and uncover terms. The c8 smoke and c16/c20 promoted replays reproduce their
locked coupled histories exactly. Maximum c16/c20 component closure is
`2.32e-7`/`1.88e-7` force, `1.34e-7`/`1.20e-7` torque, and
`6.14e-8`/`8.15e-8` actuator power against the unchanged `2e-4` limit.

After normalization by each grid's matched isolated-follower positive-power
scalar, moving-wall work carries `50.43%` of the phase-`0.035` c20-minus-c16
component change, below the frozen `60%` single-term threshold; interpolation
carries an opposing `34.69%`. At phase `0.095`, reflected and moving-wall
changes also oppose one another while `74.72%` of the field residual remains
outside the half-chord boundary band. The preregistered classification is
`wakeTransportDominated`. Component cancellation condition numbers are
`16.67` and `14.93` for the two grid differences, so the result localizes the
next experiment but does not identify any large individual work term as
erroneous. The independent audit passes `106/106` checks.

A second preregistered, no-new-CFD discriminator searches `441` bounded c16
shifts at each of five follower phases `0.055...0.095` on the c20 common grid.
The `2,205` candidate alignments remove only `0.852%` of combined signed-w and
vorticity residual energy. Four phases select zero shift; the remaining phase
selects `-0.05` chord in `x`, for a mean `(-0.01,0.00)`-chord displacement.
The frozen and independently audited (`41/41`) result is
`amplitudeDiffusionDominated`, not a spatial wake-position or phase-lag error.
This authorizes only a localized collision/advection-dissipation discriminator
in the locked wake region. The c20 minimum, global c24 ladder, quantitative
formation effect, and biological claim remain unauthorized.

The collision discriminator is executed locally with:

```bash
./Scripts/run-formation-collision-dissipation.sh
```

The preregistration allocates one five-cycle c16 RR3 candidate and requires
strict population positivity, no overlap, the unchanged `2e-4` owner-closure
and `20%` periodicity limits, correction activation below `5%` of cell-steps,
at least `25%` wake-residual reduction, and at least `10%` dimensionless
force-residual reduction before c20 is allowed. A fused per-step minimum uses
the existing force reduction; it does not add a second full population pass or
change the production TRT state.

The candidate is numerically clean: c8/c16 minima are `0.01508`/`0.01560`,
both have zero limiter activation, and c16 force/torque closure is
`1.10e-6`/`3.70e-6`. Nevertheless, c16 RR3 increases the locked wake residual
by `28.98%` and the coefficient-history residual by `84.82%`. The frozen
classification is `collisionChangeAdverseOrUnsupported`; the `51/51` audit
passes and confirms the c20 RR3 case was not allocated. RR3 is not promoted,
production remains TRT, and the c20 TRT reference is not declared truth.

An immediately following no-new-CFD localizer divides the exact wake ROI into
three one-chord streamwise bands under
`ValidationInputs/formation-flight-streamwise-attenuation-localizer-v1.json`.
The downstream/upstream residual-density ratio is `0.818`, below the
preregistered `1.15` source-dominated boundary. The `94/94` audit independently
reconstructs the band and classification arithmetic. Thus the discrepancy is
largest at the upstream edge and does not accumulate downstream. The next
admissible experiment was a phase- and direction-resolved near-wing boundary
population source census, not another bulk collision candidate or global
refinement allocation.

That census is now complete under
`ValidationInputs/formation-flight-boundary-source-census-v1.json`. The first
c8 reporting smoke is retained as a fail-closed negative control; it exposed an
empty phase-zero host-report slot after proving exact solver-history replay.
The narrow filter amendment was locked before c16/c20. Corrected c8 and the
five-cycle c16/c20 replays contain four owner/phase samples, reproduce their
reference histories exactly, and close reconstructed incoming population to
reflected, interpolation, and moving-wall sources within
`1.24e-7`, `9.28e-8`, and `9.09e-8`, respectively. c16/c20 owner force closure
is `1.14e-6`/`7.17e-7`; torque closure is `4.23e-6`/`4.42e-6`.

The preregistered exact product identity uses
`a(q)=linkCount(q)/chordCells²`, conditional momentum-exchange population
`m(q)`, and `s(q)=a(q)m(q)`. At the primary leader sample (follower phase
`0.035`), `98.25%` of the c16-to-c20 weighted-L1 source change is link sampling
and `1.75%` conditional population amplitude. The three secondary samples
remain `98.08%...98.85%` link-sampling dominated. Direction identities close
below `2.14e-17`; independent reconstruction passes `319/319` checks. This
selects geometric link realization over collision or force-law modification.

The immediate no-new-CFD subdecomposition under
`ValidationInputs/formation-flight-link-sampling-subdecomposition-v1.json`
factors `a(q)=D p(q)`. At the primary sample, total areal link density supplies
`47.55%` and D3Q19 direction redistribution `52.45%` of the dominant parent
term. Neither reaches the frozen `60%` threshold, and all owner/phase samples
remain mixed. The identity closes below `3.78e-17`; the independent audit
passes `521/521`. The next admissible allocation is one geometry-only c18
bridge at the primary phase retaining both pathways. Production edits, the
stopped c20 minimum, a global c24 ladder, and quantitative formation effect
remain unauthorized.

## 9. Free flight

Enable six-degree-of-freedom coupling after prescribed-motion loads pass.

Acceptance:

- momentum balances close to recorded external impulse
- body-step refinement leaves trajectory unchanged within tolerance
- a trim case remains bounded without artificial pose stabilization
- evolving surface Mach number and domain/sponge clearance remain inside the validated limits, with the run aborted otherwise
- wing mass/inertia, hinge reactions, and actuator loads are either modeled or a massless-wing approximation is explicitly justified

Required harness work before these criteria are measurable:

- independently adjustable `1/2/4` body substeps, GPU/CPU substep parity, an
  exact first-event runtime Mach/clearance ledger, and schema-2 bilateral
  prescribed-wing inertial hinge reactions are implemented. The measured-bird
  CLI archives the reactions and provides locked body/load refinement ladders;
- 256-step torque-free and constant-torque asymmetric-body CPU/Metal
  canonicals are implemented in addition to one-step/substep parity; and
- the opt-in `--momentum-ledger` free-flight path directly reduces fluid
  momentum on both sides of every step, records whole-bird translation and
  prescribed-wing internal momentum, and independently reconstructs open
  far-field, sponge, persistent-link, gravity, and source-closure-inferred
  topology impulses. It archives JSON/CSV and applies unchanged `0.5%`
  relative RMS boundary and total-system gates. The compact four-step moving
  topology/gravity canonical closed at `2.4483e-6` boundary and `5.0808e-5`
  total-system relative RMS, with maximum absolute residual below
  `6.1e-10 kg m/s`.
- the same opt-in path independently reconstructs conservative loads for mask
  IDs body/left wing/right wing/tail, closes their sum to the production load,
  and archives hinge-shifted aerodynamic torque, prescribed-wing inertial
  reaction, required actuator torque, and signed mechanical power. Symmetry is
  an explicit gate rather than an assumption about measured animals.
- `--trim-search` implements a reproducible forward-flight prescribed-balance
  search over bounded body pitch and airspeed only. It preserves physical
  viscosity, measured geometry, and measured kinematics; archives the exact
  base and selected derived inputs; screens candidates for at least two cycles;
  and confirms the selected point for at least five cycles against unchanged
  `5%` force, moment, and stationarity gates. Hover is rejected without a
  declared physical control variable.
- `--free-flight-confirmation` consumes that exact selected input and launches
  independent minimum-duration runs: five cycles of four-substep free flight,
  one cycle of `1/2/4` body refinement, and one cycle of coupled momentum plus
  per-part load closure. It atomically archives the exact input and all three
  evidence streams. Maximum trajectory excursion is locked at `0.10` chord,
  `0.05` reference speed, `5 deg`, and `0.05` cycle-scaled angular velocity;
  all existing runtime, refinement, and `0.5%` closure gates also apply.

Status: solver-side runtime bounds, body-step refinement, rigid prescribed
wing inertia/hinge treatment, the external linear-momentum ledger, per-part
actuator effort, forward-flight trim search, and independently restarted
bounded free-flight confirmation harness are implemented.
Quantitative free-flight remains blocked by the absent same-specimen schema-2
dataset and therefore has no executed real-specimen trim, load refinement,
body refinement, or bounded free-flight result. See
`ValidationArtifacts/quantitative-complete-bird-readiness.json`.

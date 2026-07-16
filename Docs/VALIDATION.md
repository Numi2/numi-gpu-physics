# Validation protocol

Aerodynamic output is not accepted as quantitative until this sequence passes. Each case should archive configuration, commit, device, runtime, raw fields, and comparison plots.

## Current automated coverage

The repository currently provides ten automated harnesses:

- Swift algebra, scaling, rigid-body, and layout tests;
- live strict-math Metal moving-wing fixed-body and free-flight batch-partition regressions, plus CPU/GPU rigid-body one-step parity;
- an independent NumPy periodic shear-wave decay/convergence reference;
- a production-Metal periodic shear-wave refinement, cell-by-cell CPU comparison, population-mass, and command-buffer batch-invariance check;
- production-Metal transient Couette and oscillating Stokes-layer profile, no-penetration, wall-force, phase, refinement, and batching checks;
- a production-Metal translating-sphere topology gate that closes cover/uncover force against an independent fluid-momentum budget;
- production-Metal fixed-sphere steady drag, curved-boundary symmetry, torque leakage, refinement, and batching checks;
- production-Metal fixed finite-wing lift/drag, symmetry, leakage, refinement, and batching checks;
- a production-Metal prescribed flapping-wing phase-load, periodicity, vortex-diagnostic, refinement, and batching gate; and
- offline compilation and linking of every Metal entry point.

`Scripts/validate.sh` runs the nine currently accepted build/canonical gates. The prescribed flapping command is intentionally separate because its locked literature load gates have not passed. Sections 2, 4, 5, and 6 all execute the production fluid and momentum-exchange operators; section 3 still requires a forced-channel GPU mode. The fixed-wing gate isolates axis-aligned load accuracy and does not validate the procedural bird's geometry or kinematics. The flapping gate is the current evidence boundary for rotating sub-cell moving surfaces.

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

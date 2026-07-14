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

The locked compact input SHA-256 is
`5de3e1d9377ad652ab88d2f460287affd6055c69691e32f120d74cdf79628887`.

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
and measured right-wing surface replay is implemented separately. No actual
complete measured specimen has been supplied, and per-part left/right load
reporting is not yet exposed. Therefore the complete measured-bird acceptance
gate remains open without weakening it.
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

- expose an independently adjustable body timestep or body substeps; `--resolution-scale` changes fluid `dx`, fluid `dt`, and the body step together and is not an isolated body-integrator refinement;
- archive a control-volume momentum budget including fluid momentum, far-field boundary flux, sponge impulse, bird load, gravity, and topology-conversion impulse; current CLI output does not expose the boundary/sponge terms; and
- compare constant-torque and torque-free asymmetric-body cases across the CPU and Metal integrators over multiple steps, in addition to the existing one-step parity regression.

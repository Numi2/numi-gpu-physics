# BirdFlowMetal

![BirdFlowMetal native Metal viewer showing an articulated flapping bird with pressure, vorticity, GPU pathlines, and positive-Q structures](Docs/Media/birdflow-metal-native-viewer.gif)

*Native Metal viewer capture of a finite `Re=100` development case. The progress panel reports the separate c16 source-aware canonical; this animation is a visual demonstration, not a quantitative bird-flight result.*

BirdFlowMetal is a bird-specific, three-dimensional fluid–body solver for Apple silicon. It advances air on the GPU with a D3Q19 two-relaxation-time lattice Boltzmann method, represents an articulated bird as a moving solid boundary, obtains aerodynamic force and torque by momentum exchange, and can feed those loads into a six-degree-of-freedom rigid-body update.

The package is an original implementation. Its software organization adopts PyFR’s controller/resource/command-graph separation: host-side physical types and reference algebra are separated from Metal resource orchestration, pipeline states are compiled once per simulation backend instance, and a fixed per-step GPU graph is encoded repeatedly. The production fluid and boundary operators themselves are Metal-specific MSL.

This repository is a complete vertical slice, not a validated bird-flight research result. The validation commands compile and execute the Swift/Metal path on a supported Mac, run the independent reference checks, and execute periodic shear-wave, translating/oscillating planar-wall, fixed-sphere, fixed finite-wing, and prescribed flapping-wing refinement on the production fluid and momentum-exchange kernels. The promoted fixed-thickness flapping benchmark now passes: finest mean coefficients are within `4%` of the published values and the 20-to-24-cell changes are `1.904%` lift and `3.054%` drag under the unchanged `5%` gate. A versioned measured-data preflight and prescribed replay path is implemented, but no measured specimen is bundled and the first geometry tier is an explicitly labeled analytic proxy. Forced channel flow, actual measured data, bird-load grid convergence, higher-fidelity measured surface geometry where required, and free-flight refinement remain mandatory before complete-bird results are treated as quantitative.

## Implemented solver

The fluid state consists of 19 distribution populations per lattice cell. Density, velocity, and isothermal pressure are moments of those populations. The collision operator is TRT; populations are stored direction-major so adjacent GPU threads access adjacent cells.

The bird consists of a rigid body, two evaluated flapping-wing boundaries, and a tail. The development model uses analytic stroke/pitch; measured replay uses independent left/right periodic stroke, deviation, pitch, and twist tables. Every fluid step performs:

```text
update articulated bird boundary and wall velocity
pull-stream D3Q19 populations
apply moving-wall bounce-back at bird links
recover density and velocity
TRT collision and far-field sponge
accumulate momentum-exchange force and torque
reduce loads on the GPU
optionally integrate the bird body
```

The solver tracks previous and current occupancy masks. Newly uncovered nodes are refilled from the local moving-boundary equilibrium, while newly covered nodes contribute their momentum conversion to the body load.

The production GPU path also:

- prepares articulated wing frames once per timestep and culls geometry work outside a conservative bound;
- samples measured periodic keyframes with one GPU thread per timestep, preserving physical angular rates for wall velocity without per-cell table reads;
- stores occupancy and part identity together in byte masks;
- folds the first deterministic load-reduction level into the fluid threadgroups instead of writing one load record per cell;
- stores density and velocity only for the final externally visible step of an `advance` call;
- skips threadgroup load accumulation on intermediate steps of static steady canonical cases while retaining it on every coupled bird step;
- evaluates prescribed-wing trigonometry once per timestep, rejects most geometry cells before the beta-planform power evaluation, and records phase loads into a compact GPU cycle buffer without per-step CPU waits;
- locates prescribed beta-wing boundary crossings below the grid scale and stores their direction-wise fractions in otherwise dormant solid-node population slots, adding no full-grid buffer;
- queues command-buffer batches without an intermediate CPU wait; and
- omits the rigid-body dispatch entirely for fixed-bird cases.

The default executable holds the bird fixed in an incoming stream. `--free-flight` starts the bird in stationary air and integrates the rigid torso under aerodynamic loads and gravity. Prescribed wings are massless kinematic boundaries: wing inertia, hinge reactions, and actuator loads are not included in the body dynamics.

## Requirements

- Apple-silicon Mac
- macOS 14 or later
- Xcode command-line tools with Metal compiler support
- Swift 6 or later
- Python 3 with NumPy for the independent reference test

## Build and verify

```bash
swift test
./Scripts/check-metal.sh
./Scripts/validate.sh
```

`check-metal.sh` compiles the `.metal` source directly with Apple’s offline compiler. `validate.sh` also runs independent periodic shear-wave references and the accepted strict-math production-Metal shear-wave, moving-wall, fixed-sphere, and fixed-wing harnesses. The expensive flapping-wing solves remain separate; the original 8/12/16 command exits nonzero by `0.024` percentage points, while the archived fixed-thickness 20/24 composite gate passes. The fixed-wing release tier uses roughly 9.2 GB peak unified memory and took about 26 minutes on the documented Apple M4 host.

These checks are intentionally local-only. The repository contains no GitHub Actions workflows, so pushes and pull requests do not spend hosted macOS CI minutes. Run only the local command appropriate to the change being evaluated.

The test suite includes live Metal regressions for moving-wing fixed-body and free-flight batch partitioning, including total loads, captured fields, and body state. A direct CPU-versus-GPU rigid-body step covers translation, torque, angular velocity, and orientation. The production-Metal shear wave checks three-grid convergence, actual population-mass drift, steps 1–8 cell-by-cell against a host CPU reference, and command-buffer batch invariance. The moving-wall harness checks transient Couette and finite-gap oscillating Stokes profiles, isolated upper-wall force and phase, no-penetration, refinement, and dynamic-wall batch invariance. The fixed-sphere harness checks steady drag, symmetry, torque leakage, refinement, and batching. Fast fixed-wing and one-cycle prescribed-wing regressions lock initialization, published interpolation algebra, GPU layouts, phase capture, Q/vorticity diagnostics, and finite loads. The prescribed-wing preflight independently checks analytic normalization and kinematics, CPU-versus-Metal occupancy, geometric moments, wall velocity, and sparsely read-back sub-cell link placement before release commands own the expensive refinement ladders.

## Run

Native same-process Metal viewer:

```bash
swift run -c release birdflow-viewer
```

The viewer consumes completed density/velocity buffers without volume copies,
drops visualization frames instead of waiting the solver, and records only
compact samples/settings plus explicit derived keyframes or checkpoints. See
[`Docs/VIEWER.md`](Docs/VIEWER.md) for controls, persistence, numerical
separation, diagnostics, and verification.

Canonical production-Metal shear-wave validation:

```bash
swift run -c release birdflow validate shear-wave \
  --resolution 32 \
  --archive ValidationArtifacts/shear-wave \
  --json
```

The optional archive contains `report.json`, a format manifest, and final density/velocity fields for each refinement grid.

Canonical production-Metal moving-wall validation:

```bash
swift run -c release birdflow validate moving-wall \
  --resolution 32 \
  --archive ValidationArtifacts/moving-wall \
  --json
```

Topology-changing translating-body release gate:

```bash
swift run -c release birdflow validate translating-body --json
```

This `24^3` periodic canonical translates a radius-`3.25` voxel sphere by two
lattice cells and requires both cover and uncover events. On Apple M4 it
completed in `0.65 s`, observed `64/64` cover/uncover events over 16 transition
steps, and kept the control surface clear. The conservative estimator closed
the independent raw fluid-momentum budget with `3.64e-5` RMS and `8.38e-5`
maximum force residual, versus `0.803` RMS for the legacy estimator. The
conservative moving-domain estimator is therefore the production default;
legacy Galilean-invariant and conventional modes remain available to explicit
diagnostics.

Canonical production-Metal fixed-sphere validation:

```bash
swift run -c release birdflow validate sphere \
  --resolution 160 \
  --archive ValidationArtifacts/sphere \
  --json
```

The sphere ladder uses `80 x 48 x 48`, `120 x 72 x 72`, and `160 x 96 x 96` domains with 8, 12, and 16 cells across the diameter. It is a compact engineering gate against a published `Re=100`, `Cd=1.09` reference, not a substitute for the wider-domain and finer-resolution study required for publication-quality drag.

Canonical production-Metal fixed finite-wing validation:

```bash
swift run -c release birdflow validate wing \
  --resolution 400 \
  --archive ValidationArtifacts/wing \
  --json
```

The wing ladder uses `240 x 240 x 144`, `320 x 320 x 192`, and `400 x 400 x 240` domains with 24, 32, and 40 cells per chord. It runs the `Re=100`, aspect-ratio-2 flat plate at 30 degrees through `U*t/c=13` and compares with the approximate `CL=0.75`, `CD=0.75` values in Taira and Colonius (JFM 2009). This validates the isolated fixed-wing operator; it does not validate the procedural flapping bird.

Published prescribed flapping-wing validation:

```bash
swift run birdflow validate flapping-wing \
  --audit-inputs --chord-cells 16 --json

swift run -c release birdflow validate flapping-wing \
  --chord-cells 16 \
  --archive ValidationArtifacts/flapping-wing \
  --json
```

The preflight runs the same 8/12/16 ladder and reconstructs the paper's beta moments, kinematics, coefficient scales, CPU mask, wall velocity, and analytic link intersections before touching the fluid. GPU link locations agree with independent CPU intersections within `0.00071` cell on the measured ladder, compared with about `0.707` cell worst-case error for fixed halfway placement. Raw phase-`0.25` occupied volume still changes from `1.406` to `1.398` to `0.714` times the continuous regularized volume; those center-count ratios remain diagnostics, while the fluid wall now sits at the sub-cell analytic crossing.

The archived legacy link-distance ladder produced `(CL, CD)=(7.45076, 9.58556)`,
`(8.58688, 9.50008)`, and `(8.60733, 9.61182)` and localized the old
force-accounting defect, but it is no longer a result for the production
estimator. The promoted five-cycle 8/12/16 ladder now gives
`(1.10193, 2.15741)`, `(1.37756, 2.22153)`, and `(1.42346, 2.11525)`. Finest
mean errors are `2.503%` lift and `3.384%` drag; phase timing, periodicity,
symmetry, vortex coverage, batch invariance, and lift convergence pass. The
locked verdict remains failure because drag changes `5.024%` between 12 and 16
cells per chord, exceeding the unchanged `5%` limit by `0.024` percentage
points. The compact result is archived in
`ValidationArtifacts/flapping-wing-promoted-ladder-summary.json`.

Targeted five-cycle 20- and 24-cell cases then held the paper's nominal `0.05c`
thickness fixed. They produced `(CL, CD)=(1.48928, 2.16937)` and
`(1.51819, 2.10509)`. The finest errors are `3.986%` lift and `2.888%` drag;
20-to-24 changes are `1.904%` and `3.054%`. Timing, periodicity, symmetry,
midstroke, vortex, batch-invariance, and independent input-audit gates also
pass without relaxing a threshold. The reproducible archive-composite verdict
is `ValidationArtifacts/flapping-wing-fixed-thickness-acceptance.json`; the
audit command is `Scripts/audit-flapping-refinement.py`.

The phase-resolved decomposition is available with `birdflow validate flapping-wing --decompose-loads --single-chord-cells 8 --cycles 1 --json`. On Apple M4 it completes in `9.84 s`; cover/uncover impulse contributes only `0.47%` of mean lift and `2.90%` of mean drag, while link exchange supplies the remainder. RMS topology fractions are `1.29%` lift and `3.01%` drag, and independently selected components close to total within `9.7e-6` coefficient. Geometry and topology double counting are therefore ruled out as dominant causes; link-force evaluation/normalization is the next fault domain.

The follow-up force-law A/B check is available with `birdflow validate flapping-wing --compare-link-forces --single-chord-cells 8 --cycles 1 --json`. It evaluates Wen et al.'s Galilean-invariant momentum exchange and conventional momentum exchange on the same interpolated populations, then adds the separately measured cover/uncover impulse to each. On Apple M4 it completes in `12.23 s`. Conventional exchange changes mean lift from `7.52805` to `7.50904` (`-0.25%`) and mean drag from `9.48616` to `9.56192` (`+0.80%`); the Galilean-invariant closure remains below `9.7e-6` coefficient. Both estimators retain essentially the full published-load error, ruling out the wall-frame correction as the dominant cause. The next fault domain is coefficient/reference scaling or a link-momentum factor shared by both estimators.

The CPU-only coefficient ledger removes the scaling branch without another solve:

```bash
python3 Scripts/audit-flapping-coefficients.py \
  /tmp/birdflow-link-force-comparison.json \
  --output ValidationArtifacts/flapping-wing-coefficient-ledger.json
```

It independently transcribes the paper's `CL=2L/(rho U2^2 S)` and `CD=2D/(rho U2^2 S)` definitions, derives `r2/R=0.5593218`, single-wing area `S=192` lattice cells squared, actual `U2=0.0350010`, and denominator `0.11760695065887139`. The same denominator inferred from every captured raw lift force agrees with zero relative difference; recomputed lift agrees within `5.33e-15`. Mean drag reprojected from 100 bin-averaged vectors differs by only `4.36e-4` because the original projection occurred before binning. An arbitrary denominator large enough to match published lift would still be `11.2%` larger than the one required to match drag, so a single missing scalar cannot reconcile both. Coefficient normalization is therefore cleared. The remaining load bias is in the link-population or momentum-transfer numerator shared by both force estimators.

Decompose that common numerator with:

```bash
swift run birdflow validate flapping-wing \
  --decompose-link-numerator \
  --single-chord-cells 8 \
  --cycles 1 \
  --json
```

The Apple M4 diagnostic completed in `18.23 s`. Mean `(CL, CD)` contributions were base reflection `(-6.751, -62.265)`, moving-wall population correction `(14.719, 72.263)`, interpolation residual `(-0.494, -0.711)`, and Galilean wall-frame correction `(0.019, -0.076)`, closing to the Galilean link total `(7.493, 9.211)` within `1.4e-5` coefficient. The moving-wall population term is `196%` of net mean lift and `785%` of net mean drag and is opposed by the base reflected populations. Interpolation and wall-frame terms are small. This identifies the cancellation between moving-wall correction and reflected populations as the dominant sensitivity; it does not by itself prove either term is incorrect.

Close that force accounting against a fluid-only control volume with:

```bash
swift run birdflow validate flapping-wing \
  --momentum-budget \
  --single-chord-cells 8 \
  --cycles 1 \
  --json
```

The fixed `68 x 68 x 25` near-wing volume remains clear of the swept solid and outside the sponge. Its raw storage-plus-flux balance gives mean `(CL, CD)=(1.18092, 2.04933)`; the separately reported virtual equilibrium-reservoir convention changes that to `(1.15774, 2.07231)`. Conventional boundary accounting on the identical deterministic flow gives `(7.50904, 9.56192)`, and moving the control surface one cell outward changes adjusted budget means by only `6.04e-5/1.07e-5`.

The conservative moving-domain estimator closes the raw population balance at
`(CL, CD)=(1.18061, 2.04933)`. Maximum phase residuals are
`0.002511/0.000247`, below the `0.005` tolerance. Its mean correction relative
to legacy conventional total is `(-6.32843, -7.51260)`. The translating-body
topology gate, the existing three-grid Couette/Stokes gate, and a short
promoted-default flapping run all pass, so this estimator is now production.
This fixes force accounting. The promoted five-cycle ladder clears the
published mean-load gates, and the fixed-thickness 20/24 archive composite now
clears both two-finest-grid convergence gates. The prescribed flapping-wing
canonical is accepted; this does not validate the procedural complete bird.

Measured-data preflight without starting Metal:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --audit-only \
  --json
```

Prescribed replay with exact-input provenance and phase-load archive:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --cycles 5 \
  --archive /path/to/specimen-replay-c12 \
  --json
```

The schema, coordinate/rotation conventions, interpolation, and scientific
boundary are documented in [`Docs/MEASURED_BIRD_DATA.md`](Docs/MEASURED_BIRD_DATA.md).
The bundled JSON is a synthetic ingestion fixture, not measured bird data.

A fixed-bird wind-tunnel case:

```bash
swift run -c release birdflow \
  --steps 4096 \
  --report-every 128 \
  --reynolds 2000 \
  --reference-speed 8 \
  --lattice-speed 0.04
```

A free-flight case:

```bash
swift run -c release birdflow \
  --free-flight \
  --steps 4096 \
  --report-every 128
```

A physical-domain-preserving refinement run:

```bash
swift run -c release birdflow \
  --resolution-scale 2 \
  --steps 8192 \
  --report-every 256
```

`--resolution-scale N` multiplies all grid dimensions, chord resolution, and sponge width by `N`. This keeps the physical domain and geometry fixed while reducing `dx` and `dt` by `N`; multiply the step count by `N` when comparing the same physical duration. The allocator rejects a requested grid before partial allocation if any buffer exceeds the device limit or the planned persistent buffer bytes exceed Metal’s recommended working-set limit.

The executable emits CSV containing time, body position, linear velocity, aerodynamic force, and aerodynamic torque.

## Project layout

```text
Sources/BirdFlowCore/
  D3Q19.swift                    lattice, equilibrium, TRT reference
  SimulationConfiguration.swift physical-to-lattice scaling and guards
  BirdModel.swift               morphology and wing kinematics
  RigidBody.swift               CPU reference body integrator

Sources/BirdFlowMetal/
  MetalBackend.swift            device, runtime compilation, pipelines
  BirdFlowSimulation.swift      state ownership and step command graph
  MetalShearWaveValidation.swift production-kernel canonical validation
  MetalMovingWallValidation.swift planar-wall profile/load validation
  MetalSphereValidation.swift    curved-body external-flow validation
  MetalWingValidation.swift      finite-wing load/refinement validation
  MetalFlappingWingValidation.swift prescribed moving-wing validation
  GPUData.swift                 Swift/MSL-compatible data layouts
  Metal/BirdFlow.metal          geometry, fluid, reduction, body kernels

Reference/
  shear_wave_reference.py       independent periodic decay benchmark

Docs/
  PYFR_STUDY.md                 architecture extracted from PyFR
  NUMERICS.md                   equations and discretization
  VALIDATION.md                 acceptance tests before scientific use
  BUILD_REPORT.md               completed checks and verification boundary
  BIRD_MODEL.md                 bird geometry and asset path
```

## Scope

BirdFlowMetal targets low-Mach flapping flight and wakes. It currently uses an isothermal weakly-compressible formulation, rigid wing surfaces, a uniform Cartesian grid, and moving masks with sub-cell link placement in the prescribed beta-wing benchmark. The published flapping benchmark demonstrates that axis-aligned fixed-wing agreement does not transfer automatically to a rotating diagonal surface. Extending link-distance treatment to the complete procedural bird, measured geometry, turbulence closure, flexible-wing coupling, and multiblock refinement remain planned directions rather than exposed plug-in interfaces.

Mach and domain-fit guards validate the initial configuration. Free-flight production studies must additionally monitor the evolving surface Mach number and sponge/domain margin and abort when either leaves the validated regime.

## License

BSD-3-Clause. See `LICENSE`.

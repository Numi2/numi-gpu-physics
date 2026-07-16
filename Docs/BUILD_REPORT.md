# Build, Metal optimization, and verification report

Date: 2026-07-14

## Delivered implementation

- Swift Package Manager project targeting macOS 14+
- D3Q19 two-relaxation-time lattice Boltzmann fluid solver
- GPU-generated articulated bird body, paired flapping wings, and tail
- Moving-wall bounce-back with previous/current occupancy handling, including link-distance interpolation for the prescribed beta wing
- Momentum-exchange force and torque with deterministic GPU reduction
- Optional six-degree-of-freedom rigid-body update
- Physical/lattice scaling, initial Mach/domain-fit guards, and field readback
- macOS Metal compilation plus live Metal execution regression
- production-Metal periodic shear-wave validation and raw-field archive mode
- production-Metal translating/oscillating planar-wall validation and archive mode
- production-Metal translating-body topology/momentum-closure release gate
- production-Metal fixed-sphere external-flow validation and archive mode
- production-Metal fixed finite-wing external-flow validation and archive mode
- production-Metal published prescribed flapping-wing validation with phase-load and Q/vorticity archives
- physical-domain-preserving `--resolution-scale` control and allocation preflight

## GPU optimization pass

The strict-math execution path now includes:

- direction-major populations and three-dimensional geometry dispatch;
- one GPU preparation thread for timestep-uniform pose and wing kinematics;
- an exact conservative geometry broad phase with a previous-solid exception;
- byte masks that retain both occupancy and body-part IDs `0...4`;
- first-stage force/torque reduction fused into fluid threadgroups, eliminating the full-cell load buffer;
- density/velocity diagnostic stores only on the final visible step;
- one CPU/GPU synchronization after a multi-command-buffer `advance` call;
- no body-integration encoder or dispatch in fixed-bird mode;
- one initial geometry build and initialization of only the population buffer that is first consumed;
- an interior-domain streaming fast path;
- a sphere initializer that writes static geometry, populations, and diagnostic fields in one coalesced pass while retaining the production fluid/load kernels;
- a shared static-canonical sphere/wing orchestration path and a one-pass fixed-wing initializer; and
- uniform skipping of boundary-load arithmetic, the threadgroup barrier, and first-stage reduction on non-final static steady steps, while coupled bird steps retain per-step loads;
- conservative moving-domain load accounting with complete cover/uncover stencil impulse, while retaining explicit legacy force modes for diagnostics;
- one-thread prescribed-wing stroke/pitch preparation plus sphere/slab rejection before beta-planform power evaluation; and
- a compact GPU load-history buffer that records every phase load without per-step CPU synchronization;
- exact prescribed-wing link intersections stored in dormant solid-node population slots, avoiding another full-grid allocation;
- preservation of newly covered density/momentum in the existing macroscopic field slot before those solid-node slots are reused; and
- sparse audit gathering of only boundary-link values instead of the complete `19*N` population lattice.

At the default `96 x 112 x 96` grid, removing the full-cell load buffer and packing masks reduces persistent Metal buffers by `41.34375 MiB`. Fusing the first reduction removes `63 MiB` of global load-record write/read traffic per step. Suppressing internal diagnostic stores removes `19.6875 MiB` per non-captured step, and single-buffer initialization avoids `74.8125 MiB` of startup stores.

The pre-change and optimized strict-math CLI snapshots printed identical body loads and torques at steps 4 and 32. An unarchived local timing snapshot used `/usr/bin/time -p .build/release/birdflow --steps 32 --report-every 32`: it measured `0.28 s` before the pass and optimized samples of `0.19, 0.13, 0.14, 0.14, 0.14 s` (median `0.14 s`). Those raw timing samples were not archived, so this result is indicative only. It includes process startup and runtime shader/library work and is not a reproducible Metal counter study.

## Verification completed on the available host

Host toolchain:

```text
macOS 26.6 (25G5028f)
Apple M4, 10 GPU cores, Metal 4
Apple Swift 6.3
Python 3.10.12
NumPy 2.2.5
Target: arm64-apple-macosx26.0
```

Validation components executed:

```bash
bash -n Scripts/validate.sh Scripts/check-metal.sh
swift test
python3 Scripts/static-audit.py
python3 Reference/shear_wave_reference.py
python3 Reference/shear_wave_convergence.py
Scripts/check-metal.sh
swift run birdflow validate shear-wave --json
swift run birdflow validate moving-wall --json
swift run birdflow validate translating-body --json
swift run birdflow validate sphere --json
.build/release/birdflow validate wing --json
.build/debug/birdflow validate flapping-wing --audit-inputs --chord-cells 16 --json
.build/debug/birdflow validate flapping-wing --compare-link-forces --single-chord-cells 8 --cycles 1 --json
.build/debug/birdflow validate flapping-wing --decompose-link-numerator --single-chord-cells 8 --cycles 1 --json
.build/debug/birdflow validate flapping-wing --momentum-budget --single-chord-cells 8 --cycles 1 --json
python3 Scripts/audit-flapping-coefficients.py /tmp/birdflow-link-force-comparison.json --output ValidationArtifacts/flapping-wing-coefficient-ledger.json
.build/debug/birdflow validate flapping-wing --chord-cells 16 --json --archive /tmp/birdflow-flapping-release-20260714
.build/release/birdflow validate flapping-wing --chord-cells 16 --json --archive /tmp/birdflow-flapping-link-release-20260714
.build/release/birdflow validate flapping-wing --chord-cells 16 --json --archive /tmp/birdflow-flapping-promoted-m4-20260714
.build/release/birdflow validate flapping-wing --single-chord-cells 20 --cycles 5 --json --archive /tmp/birdflow-flapping-chord-20-m4-20260714
.build/release/birdflow validate flapping-wing --audit-inputs --single-chord-cells 20 --json
.build/release/birdflow validate flapping-wing --single-chord-cells 24 --cycles 5 --json --archive /tmp/birdflow-flapping-chord-24-m4-20260714
.build/release/birdflow validate flapping-wing --audit-inputs --single-chord-cells 24 --json
python3 Scripts/audit-flapping-refinement.py /tmp/birdflow-flapping-chord-20-m4-20260714/case.json /tmp/birdflow-flapping-chord-24-m4-20260714/case.json /tmp/birdflow-flapping-promoted-m4-20260714/report.json --coarse-audit /tmp/birdflow-flapping-chord-20-input-audit.json --fine-audit /tmp/birdflow-flapping-chord-24-input-audit.json --output ValidationArtifacts/flapping-wing-fixed-thickness-acceptance.json
.build/debug/birdflow replay measured-bird --input Examples/measured-bird-schema-v1.json --audit-only --json
.build/debug/birdflow replay measured-bird --input Examples/measured-bird-schema-v1.json --steps 2 --batch-size 1 --archive /tmp/birdflow-measured-replay-fixture --json
swift test -c release
swift build -c release
```

All listed build, compiler, audit, and test commands passed except the legacy prescribed-wing fluid ladders and the promoted 8/12/16 ladder, which emitted complete reports before their locked nonzero exits. The input preflight originally exposed the halfway-geometry limitation and now passes after the link-distance implementation. The promoted 20/24 fixed-thickness archive composite passes every unchanged scientific gate.

Results:

- The previously recorded debug/release suite passed, and the added translating-body topology test passed its focused Apple M4 run in `0.20 s` (`0.125 s` after final audit renaming). Together the focused gates lock the static results, published interpolation algebra, analytic kinematics, GPU layouts, CPU/Metal input geometry/link placement, phase capture, vortex diagnostics, component closure, and topology-changing momentum closure.
- Live Metal tests matched moving-wing fixed-body and free-flight multi-command-buffer advances against synchronized one-step advances, including loads, captured fields, and rigid-body state.
- A direct strict-math CPU/Metal rigid-body step matched position, linear/angular velocity, and orientation within `1e-6` under nonzero force and torque.
- Cross-language audit passed for kernel/pipeline names, shared layouts, Swift/Metal D3Q19 direction/weight/opposite tables, and named buffer contracts.
- Apple’s Metal 3.1 offline compiler compiled and linked every kernel with `-Wall -Wextra` and no warning.
- Periodic shear-wave relative mass drift: `1.1879386363489175e-14`.
- Periodic shear-wave relative decay error: `0.002892715023138497` (about `0.289%`).
- Four-grid independent reference convergence order: `1.9861403033324327`.
- Production-Metal finest-grid shear-wave decay error: `0.0028964498775389` (about `0.290%`).
- Production-Metal three-grid convergence order: `1.9870657216321463`.
- Production-Metal maximum actual population-mass drift: `2.9401853382824776e-6` (below the `5e-6` single-precision gate).
- Production-Metal maximum steps 1–8 cell-population difference from the CPU implementation: `1.7881393432617188e-7`.
- Production-Metal batched-versus-stepwise density and velocity differences: exactly zero in the default validation case.
- Production-Metal finest-grid transient Couette profile error: `5.0501359775896124e-5`; isolated top-wall force error: `3.703458540506022e-5`.
- Production-Metal finest-grid oscillating-wall profile error: `0.001796520595387387`; force-phasor error: `0.0011740580418155779`; force phase error: `-0.0011740452422879244 rad`.
- Oscillating moving-wall profile and force convergence orders: `1.986436490328703` and `2.0208052383958144`.
- Maximum moving-wall cross-flow speed across all cases: `1.296122945859679e-6`; dynamic-wall batched-versus-stepwise density, velocity, and selected-wall force differences were exactly zero.
- The moving-wall case exposed and fixed a periodic-edge/solid-corner bug: wrapped links now execute solid bounce-back instead of reading solid populations directly.
- Production-Metal `Re=100` fixed-sphere finest-grid drag coefficient: `1.2170706918439962`, an `11.657861637063863%` difference from the published `Cd=1.09` compact-gate reference.
- Fixed-sphere drag change between the two finest grids: `0.00028850222554029217` (`0.02885%`); finest normalized mirrored-velocity error: `2.6488133134475767e-6`.
- Fixed-sphere side-force and torque leakage passed `1e-3`; batched-versus-stepwise density, velocity, and load differences were exactly zero.
- A rejected 5D cubic trial produced finest `Cd=1.357528228258264` (`24.54%` high). Expanding to a `10D x 6D x 6D` domain reduced the result inside the unchanged `15%` absolute-drag gate, directly demonstrating boundary-proximity contamination rather than hiding it by relaxing acceptance.
- Production-Metal `Re=100`, aspect-ratio-2 fixed-wing finest coefficients were `CL=0.761354209564864` and `CD=0.7071078500190809`, versus approximate published values of `0.75` and `0.75` at `U*t/c=13`.
- Fixed-wing changes from 32 to 40 cells per chord were `1.8772254779546624%` in lift and `0.2286832450047148%` in drag, both below the unchanged `3%` gate. Finest normalized span symmetry was `7.073535397279364e-7`; batch density, velocity, and load differences were exactly zero.
- The accepted `240/320/400` wing ladder took `1569.51 s` with a `9.173911952 GB` peak unified-memory footprint on Apple M4. A separate unoptimized 400-only calibration took `1160.28 s`; because the workloads differ, this supports only the narrow claim that intermediate reduction work was removed without changing coefficients, not a formal speedup percentage.
- The published Li--Nabawy prescribed-wing ladder deliberately failed: 8/12/16-cells-per-chord fifth-cycle means were `(CL, CD) = (7.44525, 9.71093)`, `(8.58575, 9.58558)`, and `(8.60144, 9.67489)` versus `(1.460, 2.046)`. The finest absolute errors were `489.14%` and `372.87%`.
- The independent input fixture cleared the published mapping: gamma-function beta normalization, area, `r1/R`, `r2/R`, integrated stroke/pitch travel, analytic rates, reference area, Reynolds velocity, and coefficient denominator all passed. CPU and production-Metal masks matched cell-for-cell at four phases, with maximum solid wall-velocity disagreement below `8.3e-9`.
- The link-distance fixture now passes: deterministic sparse readback of production GPU link fractions differs from independent CPU surface intersection by less than `0.00071` cell across the 8/12/16 ladder, versus roughly `0.707` cell for fixed halfway placement. The raw phase-`0.25` occupied-volume ratios remain `1.40625`, `1.39815`, and `0.71354` relative to the regularized surface and `3.51563`, `2.33025`, and `0.89193` relative to published thickness; they remain aliasing diagnostics rather than hydrodynamic wall locations.
- The earlier halfway input ladder took `4.65 s`. An initial link-audit traversal that checked directions from every fluid cell took `78.39 s`; enumerating outward from the sparse solid set plus deterministic link sampling reduced the final debug preflight to `7.38 s`. This is about `86x` cheaper than the new `634.61 s` five-cycle ladder while retaining 10,451 independently intersected links across the four phases of all three grids.
- The earlier halfway fluid failure was numerically repeatable rather than noisy: 12-to-16-cell changes were `0.1823%` in lift and `0.9231%` in drag; finest half-stroke symmetry error was `0.2553%`; fourth-to-fifth-cycle difference was `0.1963%`; all five Q/vorticity milestones were finite; and batch density, velocity, and load differences were exactly zero. The finest lift peaks were phases `0.245` and `0.745`. The subsequent link-distance ladder shows that this apparent plateau persists even after accurate sub-cell wall placement.
- The strict-math debug-host calibration and 774 MB archive took `598.07 s` with a `1.045 GB` peak unified-memory footprint on Apple M4. Runtime shader kernels are the same strict-math kernels used by the release command; the timing is recorded as calibration evidence, not a release performance comparison.
- The default fixed-bird and free-flight release executables completed live Metal runs on the M4.
- The one-cycle prescribed-wing smoke case captured 100 phase-load bins and all five finite positive-Q/vorticity milestones. The existing moving-wall gate still passed after switching force evaluation to the local wall frame, and the stationary fixed-wing locked coefficients remained unchanged.
- With link interpolation enabled, a new one-cycle 8-cells-per-chord diagnostic completed in `6.42 s`, produced `(CL, CD)=(7.52808, 9.48408)`, and placed lift peaks at `0.305T` and `0.805T`. It is an execution/timing diagnostic, not a substitute for the five-cycle refinement ladder.
- The completed link-distance five-cycle release ladder produced `(CL, CD)=(7.45076, 9.58556)`, `(8.58688, 9.50008)`, and `(8.60733, 9.61182)`. Compared with halfway, lift moved by only `+0.074%`, `+0.013%`, and `+0.069%`, while drag moved by `-1.291%`, `-0.892%`, and `-0.652%`. Wall-location aliasing is therefore not the dominant coefficient-error source.
- The new two-finest changes were `0.238%` lift and `1.163%` drag; finest symmetry was `0.237%`, fourth-to-fifth-cycle difference was `0.210%`, all vortex phases were finite, and all batch differences were zero. Absolute errors remained `489.54%` lift and `369.79%` drag, and finest peaks remained `0.245T/0.745T`, so the unchanged scientific verdict is failure.
- The link-distance run and 774 MB archive took `634.61 s` with a `1.050 GB` peak memory footprint. This is not a controlled performance comparison with the earlier debug-host run, but the near-identical peak supports the implementation claim that no persistent full-grid link buffer was added.
- The one-cycle 8-cell total/link/topology diagnostic took `9.84 s`. Total closed against independently selected link plus cover/uncover histories within `9.69e-6` lift coefficient, `1.96e-6` drag coefficient, and `1.15e-6` force units. Cover/uncover supplied `0.47%/2.90%` of mean lift/drag and `1.29%/3.01%` of RMS lift/drag; link exchange is the dominant bias path.
- The subsequent one-cycle force-law A/B diagnostic took `12.23 s`. Galilean-invariant momentum exchange produced `(CL, CD)=(7.52805, 9.48616)`; conventional momentum exchange evaluated on the same interpolated populations and combined with the same topology impulse produced `(7.50904, 9.56192)`. The conventional/Galilean ratios were `0.99747` in lift and `1.00799` in drag, while the independent Galilean-invariant component closure stayed below `9.69e-6` coefficient. The wall-frame correction is therefore not the dominant load-error source.
- The CPU-only paper-equation ledger derived `r2/R=0.5593218136`, `U2=0.03500103431`, single-wing area `S=192`, and coefficient denominator `0.11760695065887139`. Every captured raw lift force inferred the same denominator to binary-double precision; recomputed lift differed by at most `5.33e-15`. Mean drag reprojection from bin-averaged vectors differed by at most `4.36e-4`. Matching the published Galilean-invariant lift and drag would require incompatible denominators, `0.6064052` and `0.5453031`. Coefficient normalization is cleared without another fluid run, leaving the shared link numerator as the next fault domain.
- The six-history link-numerator diagnostic took `18.23 s`. Mean base-reflection `(CL, CD)` was `(-6.75135, -62.26542)`, moving-wall population correction was `(14.71945, 72.26319)`, interpolation residual was `(-0.49416, -0.71106)`, and Galilean wall-frame correction was `(0.01902, -0.07576)`. Both conventional and Galilean phase closures stayed below `1.4e-5` coefficient. The moving-wall population term dominates the net load through cancellation against reflected populations; interpolation and Galilean corrections are small.
- The independent near-wing momentum diagnostic measured raw storage-plus-flux mean `(CL, CD)=(1.18092, 2.04933)` and optional equilibrium-reservoir-adjusted `(1.15774, 2.07231)`, while conventional and Galilean accumulation reported `(7.50904, 9.56192)` and `(7.52805, 9.48616)`. The conservative moving-domain estimator produced `(1.18061, 2.04933)`, closing the raw budget within maximum phase residuals `0.002511/0.000247` under a `0.005` tolerance. Its mean correction relative to legacy conventional total is `(-6.32843, -7.51260)`. The fixed-mask link equation is conservative; incomplete uncover stencil accounting was the localized fault domain.
- The new `24^3`, 40-step translating-sphere gate crossed exactly two lattice cells in `0.65 s`, recording 64 covered and 64 uncovered events over 16 transition steps with no solid link on the control surface. Conservative force closed the raw fluid budget at `3.6449e-5` RMS and `8.3824e-5` maximum residual, versus `0.80263` legacy RMS (`22020.8x` improvement). The focused Swift test took `0.20 s`; the existing Couette/Stokes moving-wall test passed after promotion in `1.81 s`.
- Mode six is now the non-diagnostic production default and the normal prescribed-wing default. A short 8-cell, one-cycle production-path run completed in `3.28 s` at `(CL, CD)=(1.18057, 2.04910)`. The previous full flapping ladder is pre-promotion evidence; the promoted five-cycle result is recorded below.
- The promoted five-cycle 8/12/16 ladder completed in `317.89 s` with a `1.051 GB` peak memory footprint and `774 MB` archive. Mean `(CL, CD)` values were `(1.10193, 2.15741)`, `(1.37756, 2.22153)`, and `(1.42346, 2.11525)`. Finest absolute errors were `2.503%/3.384%`; peak timing, midstroke lift, symmetry, periodicity, vortex coverage, batch invariance, and `3.225%` lift convergence all passed. Drag changed `5.024%` between 12 and 16 cells per chord, missing the unchanged `5%` gate by `0.024` percentage points, so the scientific verdict remains failure without threshold relaxation.
- The targeted five-cycle 20-cell case completed in `582.12 s` with a `1.717 GB` peak memory footprint and `977 MiB` archive. It produced `(CL, CD)=(1.48928, 2.16937)`; the 16-to-20 changes are `4.420%` lift and `2.495%` drag, both below the unchanged `5%` criterion. All individual timing, periodicity, symmetry, midstroke, vortex, and mean-load gates pass. The separate input audit also passes with exact mask agreement and sub-`0.00071`-cell wall placement. Because single-grid mode assigns no verdict and 20 cells is the first grid at nominal `0.05c` thickness, it established the fixed-thickness comparison boundary cleared by the following 24-cell result.
- The five-cycle 24-cell completion case took `1393.77 s`, peaked at `2.947 GB`, and wrote a `1.648 GiB` archive. It produced `(CL, CD)=(1.51819, 2.10509)`, within `3.986%/2.888%` of the published means. Fixed-thickness 20-to-24 changes are `1.904%` lift and `3.054%` drag. The independent archive audit reconstructs the production limits, incorporates both input audits and the zero-difference batch report, and passes every gate. This accepts the prescribed flapping-wing canonical without weakening the original thresholds.
- Measured-bird schema 1 now performs a sub-second CPU preflight of provenance, SI units, COM/principal-axis registration, periodic left/right stroke/deviation/pitch/twist pose and rates, domain/thickness resolution, and conservative Mach before Metal allocation. The Mach guard analytically checks extrema between Hermite keyframes rather than only sampled rates. The synthetic conformance fixture planned a `120 x 138 x 120` grid, `3810` steps/cycle, and maximum estimated Mach `0.14670132`; its final timed two-step release production-Metal replay and atomic SHA-linked archive completed in `0.09 s` wall time (`0.0358 s` solver interval). Exact archived-input bytes, SHA-256, and two phase rows were independently checked. The compact record is `ValidationArtifacts/measured-bird-replay-summary.json`. This proves ingestion/replay plumbing only, not measured-bird aerodynamics.
- The Deetjen et al. Ringneck-dove source is qualified as the next prescribed-motion experimental-force benchmark. Remote Zip64 indexing selected `2018_12_11_OB_F03`, reducing the required transfer from `19,294,077,798` compressed bytes to `671,462,764` including its complete processed surface. The standard-library extractor verified all nine member CRCs. Independent MATLAB inspection recovered a `200 x 200` body grid, sparse `381 x 436` left-wing grid, 144 tail meshes, 144 kinematic frames at 1000 Hz, and a 287-sample synchronized force window at 2000 Hz with `8.89e-15 s` maximum nearest-sample residual. Only processed `FxWings/FzWings` are experimental force targets; the mirrored wing, lateral force, per-wing split, and 20-point wing mass distribution remain assumptions or models. No fluid result is claimed until coordinate, topology, wall-velocity, repeatability, and refinement gates pass.
- The Deetjen surface conversion gate now commits a 144-frame, 2,157-vertex, 3,968-triangle fixed complete-surface sequence in 3.73 MB of float32 positions plus 23.8 KB of uint16 topology. Independent CPU decoding reproduces all source/binary identities, component index ranges, nondegenerate triangles, area and bound closure, and adjacent-frame wall speed. Worst absolute area errors are `4.703%` body, `8.905%` wing, and `0.566%` tail. A naive sparse-outline remesh was rejected after exposing a false `91.9 m/s` tip speed; the promoted material-coordinate regularization reaches `25.2305 m/s`, `1.1807x` the deposit's filtered blade-element maximum under a locked `1.25x` ceiling. This clears CPU input parity, not Metal replay or force validation.
- The dedicated indexed-surface Metal gate now replays all 144 Deetjen frames plus five fractional-time probes in `7.02 s` on Apple M4 using generic prepare, raster, and resolve kernels without allocating fluid populations or dispatching collision/force work. Host-side binary interval selection eliminates a redundant timestamp scan in every vertex thread without expanding the 48-byte parameter block. The `59 x 53 x 50` audit retains body, both wings, and tail at every frame and probe. Five independent CPU raster milestones have exactly zero occupancy mismatch, `2.182e-5` maximum occupied-cell wall-velocity difference, and `1.574e-5` maximum signed-distance difference; prepared positions and physical velocities differ by at most `1.669e-8 m` and `1.907e-6 m/s`. This accepts indexed Metal geometry only; aerodynamic force agreement remains open.
- The promoted indexed-surface production integration gate takes `0.24 s` for eight Apple M4 steps. Periodic boundaries and zero sponge isolate the surface while the accepted geometry drives the production interpolated link builder, conservative moving-domain force mode 6, and `stepFluidTRT`. It crosses 39 cells into solid and 53 back to fluid, records 101,262 persistent link events, preserves all four component identifiers, and matches the independent topology-event count exactly. Direct before/after population momentum closes against aerodynamic impulse at `1.789e-5` relative RMS with `3.8846e-8 kg m/s` maximum residual under the unchanged `0.005` gate. The separately reported halfway persistent-link split is diagnostic only. This accepts geometry-to-fluid impulse accounting, not developed flow or experimental force agreement.
- The Deetjen force-registration gate locks two deposited MATLAB scripts in addition to the measured arrays. Their independent equations map stored platform reaction to BirdFlow external force as `[-FxWings, unavailable, -FzWings]`; lateral force is not zero-filled. Nearest lookup and exact camera-zero arithmetic both select indices `191878...192164`, all 144 stored surface times match exactly after normalization, and the 143 intervening samples are fixed at half-frame interpolation points. The 287-sample target spans `0.143 s`, carries `0.0207113 N s` forward and `0.162774 N s` upward impulse, and reproduces the authors' derived per-wing vertical force with zero maximum residual. This accepts input registration for a coarse pilot, not CFD agreement, uncertainty, or refinement.
- The locked 1,000-step D=16 recursive-regularization A/B took `132.60 s` on Apple M4. Against the rejected second-order regularized control, the candidate cut activation from `0.02803%` to `0.00645%`, relative L1 correction from `0.05304%` to `0.01932%`, and relative L2 correction from `1.09683%` to `0.35279%`. Positivity, source ledger, force budget, radial closure, and both unchanged correction gates pass. This qualifies the operator only for the D=8/12/16 geometric ladder; it is not yet enabled in flapping or measured-bird replay.
- The locked RR3 D=8/12/16 refinement ladder completed in `35.23 s` on Apple M4. Every case passed positivity, source-ledger, force-budget, and non-intrusive correction gates; activation and L1/L2 correction all decreased with refinement. Promotion is blocked because drag coefficients `1.32042/0.93800/1.04777` are non-monotonic, D12-to-D16 changes `10.476%` against the unchanged `5%` gate, and no Richardson fit exists. Fourth-to-fifth convective-window means still change `11.54%/13.28%/0.052%`, motivating a cheap coarse-grid duration extension before D=20.
- The controlled RR3 D=8/12 ten-convective-time extension completed in `19.78 s` on Apple M4. Both cases retained every positivity, source-ledger, force-budget, control-isolation, and non-intrusive correction gate. D=12 became duration-stable: ninth-to-tenth drag changed `4.543%` and fifth-to-tenth changed `2.177%`. D=8 remained unresolved at `46.848%` and `29.219%`, respectively, with a large ninth-window excursion. The next allocation is therefore a D=8-only shedding-period and block-uncertainty diagnostic, not D=20.
- The macOS GitHub Actions workflow was deleted. Swift, reference, static-audit, and Metal validation remain explicit local commands and no push or pull request consumes hosted macOS CI minutes.
- Schema 2 now rejects free flight without bilateral measured wing mass,
  hinge-relative COM, and inertia. Its GPU prescribed-rigid-wing momentum
  model feeds left/right inertial hinge reactions into six-DOF dynamics and
  archives them. Independent `1/2/4` body-substep and five-cycle `8/12/16`
  measured-bird load ladders are exposed. A per-step GPU ledger freezes the
  first Mach, sponge/three-cell-clearance, or non-finite failure. The source
  audit still finds no complete same-specimen dataset, so no quantitative bird
  result is claimed.
- The opt-in coupled free-flight ledger now closes direct population momentum,
  whole-bird translation, prescribed-wing internal momentum, far-field,
  sponge, gravity, persistent-link exchange, and the inferred topology
  remainder. Its four-step moving-topology/gravity gate measured `2.4483e-6`
  boundary and `5.0808e-5` total-system relative RMS closure against a locked
  `0.005` limit. Lazy compact reductions leave normal batched production and
  viewer execution unchanged.
- The complete local Apple-M4 suite passed all `88` tests in `805.564 s`
  (`806.24 s` command wall time). The
  new exact-first-event Mach monitor, schema-2 strict loader, CPU/Metal wing
  reaction reference, four-substep parity, and 256-step torque-free and
  constant-torque rotational canonicals all passed, along with the new
  per-part archive, bilateral actuator gate, bounded trim optimizer, and
  byte-exact trim archive round trip, plus the bounded-free-flight dimensionless
  excursion and schema rejection contracts. The release products and both
  standalone Metal libraries compiled.
- The coupled momentum and per-part canonical also passed a focused
  release-mode run in `0.062 s`; both standalone Metal libraries compiled after the new kernels
  were added, and the static Swift/Metal binding audit passed. No hosted CI
  was used.
- Opt-in GPU part-load reconstruction now attributes the exact production
  conservative exchange to body, left wing, right wing, and tail, then reports
  hinge-shifted aerodynamic torque, prescribed-wing inertial reaction,
  required actuator torque, and signed power. The compact four-step canonical
  closed force/torque sums at `1.0876062e-6`/`3.1473154e-6` relative RMS.
- That diagnostic exposed and fixed the right-wing anatomical pitch/tip-twist
  sign convention. With the physical mirror restored, relative bilateral
  residuals are `7.6318046e-7` force, `4.4050828e-6` hinge torque, and
  `1.5049285e-5` actuator power against the unchanged `0.02` limit.
- A bounded forward-flight trim harness now searches only body-local pitch and
  airspeed, scales Reynolds number with speed to preserve physical viscosity,
  and minimizes all six force/moment components. Two-cycle candidates feed a
  five-cycle selected-point confirmation under unchanged `5%` balance and
  stationarity gates. Archives retain the base and exact derived best input;
  no real-specimen trim result is claimed while that input remains absent.
- The bounded optimizer and byte-exact archive round trip passed in debug and
  release mode (`0.005 s` focused test). The release CLI exposes separate
  screening/confirmation durations and rejects ambiguous duration, free-flight,
  refinement, and momentum-ledger option combinations.
- A combined `--free-flight-confirmation` release gate now restarts the exact
  selected trim input for a minimum five-cycle bounded trajectory, one-cycle
  `1/2/4` body refinement, and one-cycle direct momentum/per-part load closure.
  It archives the byte-identical input, trajectory, runtime safety, and each
  nested report atomically. Fast tests independently verify the dimensionless
  excursion algebra and reject schema-1 input before Metal allocation; no real
  specimen result is claimed.

## Verification boundary

The current tests prove buildability, cross-language consistency, the independent reference algebra/convergence result, production-Metal periodic shear-wave decay and convergence, steps 1–8 population agreement, translating and oscillating planar-wall profiles and forces, topology-changing momentum closure, fixed-sphere curved-boundary drag/refinement/symmetry, isolated fixed-wing lift/drag/refinement/symmetry, prescribed-wing analytic normalization/kinematics, CPU/Metal geometry agreement, sub-cell link placement, phase capture/vortex diagnostics, fixed-thickness 20/24 prescribed-wing convergence, measured-data contract/interpolation/GPU replay plumbing, live Metal command ordering, moving-wing/free-flight batch invariance, field capture, deterministic load agreement, and one-step CPU/GPU rigid-body parity. Forced channel flow remains absent. The prior interpolated full flapping ladder used the retired legacy force default; its refinement and repeatability evidence remains diagnostic, but its absolute-load verdict is not a result for the promoted estimator. The prescribed flapping-wing canonical is accepted; quantitative complete-bird use remains blocked by an actual measured specimen, higher-fidelity measured surface geometry where required, executed real-specimen trim and per-part results, bird-load grid convergence, and free-flight momentum/body-step refinement.

Quantitative complete-bird use still requires the remaining ladder in
`Docs/VALIDATION.md`, including forced channel flow, Metal-versus-reference
field comparisons, one real same-specimen dataset and appropriate surface
representation, executed bird-load/body-step refinement, confirmed trim, and
executed real-specimen external-momentum evidence. Runtime Mach/domain
monitoring, rigid prescribed-wing inertial hinge reaction, and the external
linear-momentum archive gate are now implemented. The optimization timings
above are engineering evidence only and are not aerodynamic validation.

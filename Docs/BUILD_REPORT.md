# Build, Metal optimization, and verification report

Date: 2026-07-14

## Delivered implementation

- Swift Package Manager project targeting macOS 14+
- D3Q19 two-relaxation-time lattice Boltzmann fluid solver
- GPU-generated articulated bird body, paired flapping wings, and tail
- Moving-wall halfway bounce-back with previous/current occupancy handling
- Momentum-exchange force and torque with deterministic GPU reduction
- Optional six-degree-of-freedom rigid-body update
- Physical/lattice scaling, initial Mach/domain-fit guards, and field readback
- macOS Metal compilation plus live Metal execution regression
- production-Metal periodic shear-wave validation and raw-field archive mode
- production-Metal translating/oscillating planar-wall validation and archive mode
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
- wall-frame, Galilean-invariant moving-boundary momentum exchange that reduces exactly to the previous expression for stationary walls;
- one-thread prescribed-wing stroke/pitch preparation plus sphere/slab rejection before beta-planform power evaluation; and
- a compact GPU load-history buffer that records every phase load without per-step CPU synchronization.

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
swift run birdflow validate sphere --json
.build/release/birdflow validate wing --json
.build/debug/birdflow validate flapping-wing --audit-inputs --chord-cells 16 --json
.build/debug/birdflow validate flapping-wing --chord-cells 16 --json --archive /tmp/birdflow-flapping-release-20260714
swift test -c release
swift build -c release
```

All build, compiler, audit, and test commands passed. The prescribed-wing input preflight and full fluid ladder exited nonzero at their locked scientific gates after emitting complete reports; those failures are the recorded validation outcome.

Results:

- 25 Swift tests passed in debug and release configurations; fast fixed-wing and prescribed-wing tests lock the 80-cell static result plus analytic kinematics, GPU layouts, CPU/Metal input geometry, phase capture, and vortex diagnostics.
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
- The fixture then localized a binary-boundary failure: phase-`0.25` occupied-volume ratios relative to the one-cell-regularized surface were `1.40625`, `1.39815`, and `0.71354` at 8, 12, and 16 cells per chord; relative to the published 5%-chord thickness they were `3.51563`, `2.33025`, and `0.89193`. Coarse thickness inflation and non-monotonic orientation/parity alias exceed the locked `25%` gates and prove the surface is not geometrically converged.
- The full 8/12/16 input ladder took `4.65 s` in the debug host executable on Apple M4, versus `598.07 s` for the five-cycle fluid ladder, so it is suitable as a routine preflight rather than a release-only calibration.
- The fluid failure is numerically repeatable rather than noisy: 12-to-16-cell changes were `0.1823%` in lift and `0.9231%` in drag; finest half-stroke symmetry error was `0.2553%`; fourth-to-fifth-cycle difference was `0.1963%`; all five Q/vorticity milestones were finite; and batch density, velocity, and load differences were exactly zero. The finest lift peaks were at phases `0.245` and `0.745`, each `0.005T` before its locked window. In light of the independent geometry failure, the small force changes are an apparent binary-boundary plateau, not evidence of continuum grid convergence.
- The strict-math debug-host calibration and 774 MB archive took `598.07 s` with a `1.045 GB` peak unified-memory footprint on Apple M4. Runtime shader kernels are the same strict-math kernels used by the release command; the timing is recorded as calibration evidence, not a release performance comparison.
- The default fixed-bird and free-flight release executables completed live Metal runs on the M4.
- The one-cycle prescribed-wing smoke case captured 100 phase-load bins and all five finite positive-Q/vorticity milestones. The existing moving-wall gate still passed after switching force evaluation to the local wall frame, and the stationary fixed-wing locked coefficients remained unchanged.

## Verification boundary

The current tests prove buildability, cross-language consistency, the independent reference algebra/convergence result, production-Metal periodic shear-wave decay and convergence, steps 1–8 population agreement, translating and oscillating planar-wall profiles and forces, fixed-sphere curved-boundary drag/refinement/symmetry, isolated fixed-wing lift/drag/refinement/symmetry, prescribed-wing analytic normalization/kinematics and CPU/Metal geometry agreement, phase capture/vortex diagnostics, live Metal command ordering, moving-wing/free-flight batch invariance, field capture, deterministic load agreement, and one-step CPU/GPU rigid-body parity. Forced channel flow remains absent. The prescribed literature case passes repeatability, phase-coverage, batching, and the numerical two-finest-load-change check, but the independent geometry preflight fails, as do the locked absolute-load gates and both peak-phase windows by `0.005T`; implementation is not acceptance.

Quantitative aerodynamic use still requires the complete ladder in `Docs/VALIDATION.md`, including an accepted sub-grid moving/curved-boundary flapping result, Metal-versus-reference field comparisons, two-finest-grid load convergence, measured bird geometry and kinematics, and free-flight momentum/body-step refinement. Free-flight studies must also add runtime Mach/domain monitoring and either model wing inertial/hinge/actuator reactions or justify the current massless-wing approximation. The optimization timings above are engineering evidence only and are not aerodynamic validation.

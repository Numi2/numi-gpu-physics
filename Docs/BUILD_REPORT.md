# Build, Metal optimization, and verification report

Date: 2026-07-12

## Delivered implementation

- Swift Package Manager project targeting macOS 14+
- D3Q19 two-relaxation-time lattice Boltzmann fluid solver
- GPU-generated articulated bird body, paired flapping wings, and tail
- Moving-wall halfway bounce-back with previous/current occupancy handling
- Momentum-exchange force and torque with deterministic GPU reduction
- Optional six-degree-of-freedom rigid-body update
- Physical/lattice scaling, initial Mach/domain-fit guards, and field readback
- macOS Metal compilation plus live Metal execution regression
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
- one initial geometry build and initialization of only the population buffer that is first consumed; and
- an interior-domain streaming fast path.

At the default `96 x 112 x 96` grid, removing the full-cell load buffer and packing masks reduces persistent Metal buffers by `41.34375 MiB`. Fusing the first reduction removes `63 MiB` of global load-record write/read traffic per step. Suppressing internal diagnostic stores removes `19.6875 MiB` per non-captured step, and single-buffer initialization avoids `74.8125 MiB` of startup stores.

The pre-change and optimized strict-math CLI snapshots printed identical body loads and torques at steps 4 and 32. An unarchived local timing snapshot used `/usr/bin/time -p .build/release/birdflow --steps 32 --report-every 32`: it measured `0.28 s` before the pass and optimized samples of `0.19, 0.13, 0.14, 0.14, 0.14 s` (median `0.14 s`). The workspace has no Git metadata or archived raw timing artifact, so this result is indicative only. It includes process startup and runtime shader/library work and is not a reproducible Metal counter study.

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

Commands completed successfully:

```bash
bash -n Scripts/validate.sh Scripts/check-metal.sh
./Scripts/validate.sh
swift test -c release
swift build -c release
```

Results:

- 18 Swift tests passed in debug and release configurations.
- Live Metal tests matched moving-wing fixed-body and free-flight multi-command-buffer advances against synchronized one-step advances, including loads, captured fields, and rigid-body state.
- A direct strict-math CPU/Metal rigid-body step matched position, linear/angular velocity, and orientation within `1e-6` under nonzero force and torque.
- Cross-language audit passed for kernel/pipeline names, shared layouts, Swift/Metal D3Q19 direction/weight/opposite tables, and named buffer contracts.
- Apple’s Metal 3.1 offline compiler compiled and linked every kernel with `-Wall -Wextra` and no warning.
- Periodic shear-wave relative mass drift: `1.1879386363489175e-14`.
- Periodic shear-wave relative decay error: `0.002892715023138497` (about `0.289%`).
- Four-grid independent reference convergence order: `1.9861403033324327`.
- The default fixed-bird and free-flight release executables completed live Metal runs on the M4.

## Verification boundary

The current tests prove buildability, cross-language consistency, the independent reference algebra/convergence result, live Metal command ordering, moving-wing/free-flight batch invariance, field capture, deterministic load agreement, and one-step CPU/GPU rigid-body parity. They do not yet execute the periodic shear wave, channel, planar moving wall, sphere, or isolated wing on the production Metal solver.

Quantitative aerodynamic use still requires the complete ladder in `Docs/VALIDATION.md`, including Metal-versus-reference field comparisons, canonical boundary cases, two-finest-grid load convergence, measured bird geometry and kinematics, and free-flight momentum/body-step refinement. Free-flight studies must also add runtime Mach/domain monitoring and either model wing inertial/hinge/actuator reactions or justify the current massless-wing approximation. The optimization timings above are engineering evidence only and are not aerodynamic validation.

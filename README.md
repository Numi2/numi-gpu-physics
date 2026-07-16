# BirdFlowMetal

<p align="center">
  <strong>A GPU-native, three-dimensional fluid–body laboratory for articulated bird flight on Apple silicon.</strong>
</p>

<p align="center">
  <img alt="Swift 6" src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white">
  <img alt="Apple Metal" src="https://img.shields.io/badge/Apple%20Metal-GPU-111111?logo=apple&logoColor=white">
  <img alt="D3Q19 LBM" src="https://img.shields.io/badge/Fluid-D3Q19%20LBM-0066CC">
  <img alt="Local validation" src="https://img.shields.io/badge/Validation-local%20only-2E8B57">
  <img alt="BSD 3-Clause" src="https://img.shields.io/badge/License-BSD--3--Clause-blue">
</p>

![BirdFlowMetal native Metal viewer showing an articulated flapping bird with pressure, vorticity, GPU pathlines, and positive-Q structures](Docs/Media/birdflow-metal-native-viewer.gif)

<p align="center"><em>Deterministic offscreen capture from the native Metal viewer. This is a finite Re=100 development visualization, not a quantitative bird-flight result.</em></p>

BirdFlowMetal advances a real D3Q19 fluid state on the GPU, evaluates articulated moving boundaries, exchanges momentum with those boundaries, reduces aerodynamic force and torque, and can integrate a six-degree-of-freedom rigid body—all in one Swift/Metal package. It also includes a native scientific viewer, exact-input measured-motion replay, independent reference algebra, archived validation reports, and deliberately strict scientific acceptance gates.

> [!IMPORTANT]
> **Scientific status:** the coupled vertical slice is complete and the fixed-thickness prescribed flapping-wing canonical is quantitatively accepted. Complete measured-bird and free-flight results are **not** yet publication-ready. The repository keeps those boundaries explicit instead of converting engineering success into an aerodynamic claim.

[Quick start](#quick-start) · [Validation scoreboard](#validation-scoreboard) · [Native viewer](#native-metal-viewer) · [Architecture](#architecture) · [Measured data](#measured-geometry-and-kinematics) · [Scientific limits](#scientific-boundary) · [Full validation contract](Docs/VALIDATION.md)

## Why this project is interesting

- **One coupled stack:** fluid populations, articulated geometry, moving-wall treatment, topology changes, load extraction, and body dynamics live in one executable system.
- **GPU-resident science:** production stepping, geometry preparation, diagnostics, load reduction, Q criterion, marching cubes, pathlines, and rendering all use Metal.
- **Estimator-independent checks:** boundary loads close against fluid momentum storage and control-surface flux; free flight also closes direct fluid + body + wing momentum against far-field, sponge, and gravity impulse.
- **Negative results are first-class artifacts:** rejected operators, failed gates, source locks, phase histories, and exact thresholds are committed beside accepted results.
- **Measured-motion ready:** periodic left/right stroke, deviation, pitch, and twist are replayed with consistent pose and physical angular rates; exact input bytes and SHA-256 are retained.
- **No hosted macOS bill:** Swift and Metal validation is intentionally local. This repository contains no GitHub Actions workflows.

## Validation scoreboard

| Layer | Current result | Evidence |
|---|---|---|
| D3Q19 reference and production kernels | **Accepted engineering gate** | CPU/GPU early-step agreement, shear-wave convergence, mass tracking, batch invariance |
| Moving planar walls | **Accepted** | Couette and oscillating Stokes velocity/force/phase refinement |
| Topology-changing body | **Accepted** | 64 covered + 64 uncovered events; conservative force-budget RMS residual `3.64e-5` |
| Fixed sphere, Re=100 | **Accepted canonical** | drag, symmetry, torque leakage, refinement, batching |
| Fixed finite wing, Re=100 | **Accepted canonical** | finest `CL=0.76135`, `CD=0.70711`; two-finest changes below `3%` |
| Prescribed flapping wing | **Accepted canonical** | 20/24-cell fixed-thickness changes `1.904%` lift and `3.054%` drag; finest mean errors below `4%` |
| Native viewer | **Accepted engineering gate** | observation invariance, zero solver waits, Q/pressure/slice/pathline tests, exact checkpoint continuation |
| Measured-bird ingestion/replay | **Plumbing accepted; science open** | schema, provenance, interpolation, Mach/domain preflight, production-Metal replay |
| Measured dove external-force benchmark | **CPU + Metal geometry accepted; fluid/force open** | all 144 indexed frames preserve four components with exact CPU/GPU occupancy; position error including fractional-time probes is `1.67e-8 m` |
| Published-condition high-Re sphere | **Open** | RR3 clears numerical gates, but D=8 wake averaging remains statistically unresolved |
| Quantitative complete bird / free flight | **Solver gates implemented; same-specimen data blocked** | external-system momentum closes at `5.08e-5` relative RMS in the compact topology/gravity gate; schema-2 inertia, runtime aborts, and load/body ladders are ready; real complete specimen input is absent |

The most important accepted flapping result is committed as [`flapping-wing-fixed-thickness-acceptance.json`](ValidationArtifacts/flapping-wing-fixed-thickness-acceptance.json). The current high-Re open question is committed as [`measured-wing-stationary-wall-recursive-regularization-duration.json`](ValidationArtifacts/measured-wing-stationary-wall-recursive-regularization-duration.json).

The next experimental validation source is now qualified without weakening the
measured-data contract. Deetjen et al.'s Ringneck-dove deposit provides
synchronized processed 3D surfaces, kinematics, and measured horizontal and
vertical aerodynamic-force histories. The selected `OB` flight can be acquired
as a CRC-locked 15 MB engineering subset or a 671 MB subset including its full
surface instead of downloading the 19.3 GB archive. See
[`Docs/DEETJEN_DOVE_BENCHMARK.md`](Docs/DEETJEN_DOVE_BENCHMARK.md). Its inertia
remains modeled, so it advances prescribed-force validation—not measured
schema-2 free flight.

The decoded surface is now a committed 3.73 MB float32 sequence with one fixed
topology for the body, measured left wing, explicitly mirrored right wing, and
tail. It uses the deposited laboratory motion without an artificial periodic
wrap. The compact mesh stays 128 triangles below the current Metal identifier
limit. Independent CPU reconstruction passes every binary, topology, area,
coordinate-bound, and adjacent-frame wall-speed check; the exact artifacts are
[`manifest.json`](ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json) and
[`deetjen-dove-surface-cpu-parity.json`](ValidationArtifacts/deetjen-dove-surface-cpu-parity.json).
The geometry-only Apple M4 replay then dispatches the generic indexed Metal
prepare/raster/resolve path for all 144 frames on a `59 x 53 x 50` grid. It
preserves all four components every frame, matches CPU occupancy exactly at five
milestones, and bounds wall-velocity and signed-distance differences by
`2.182e-5` lattice and `1.574e-5` cells. Five additional fractional-time probes
exercise interpolation between stored frames. The archived 7.02-second result is
[`deetjen-dove-indexed-metal-geometry.json`](ValidationArtifacts/deetjen-dove-indexed-metal-geometry.json).
It deliberately executes no collision or force kernel, so aerodynamic agreement
remains open.

## Latest high-Re result

<p align="center">
  <img width="49%" alt="Recursive regularization D8 D12 D16 refinement result" src="ValidationArtifacts/Figures/stationary-wall-recursive-regularization-refinement.png">
  <img width="49%" alt="Recursive regularization D8 D12 duration sensitivity result" src="ValidationArtifacts/Figures/stationary-wall-recursive-regularization-duration.png">
</p>

Recursive-regularized BGK keeps the D=8/12/16 stationary-sphere cases positive, source/force closed, and non-intrusive while correction decreases with refinement. Promotion is still blocked: `Cd = 1.32042, 0.93800, 1.04777` is non-monotonic and the D12→D16 change is `10.476%` against the unchanged `5%` gate.

The cheap ten-convective-time follow-up resolved half the ambiguity:

- D=12 is late-window stable: ninth→tenth change `4.543%`; fifth→tenth change `2.177%`.
- D=8 is not: ninth→tenth change `46.848%`; fifth→tenth change `29.219%`.
- Every positivity, conservation, force-budget, control-isolation, and correction gate still passes.

Therefore the next highest-ROI experiment is **D=8 only**: estimate its dominant shedding period, then report period-complete block means and uncertainty. That is more defensible—and far cheaper—than spending immediately on D=20 or treating adjacent one-convective-time windows as independent steady estimates.

## The force-accounting investigation

The prescribed-wing load error was once roughly fivefold. The repository now contains the full chain that found and corrected it:

1. **Load decomposition** showed cover/uncover topology impulse contributed only `0.47%` of mean lift and `2.90%` of mean drag; link exchange dominated.
2. **Conventional versus Galilean-invariant momentum exchange** changed mean loads by less than `1%`, ruling out the wall-frame correction as the main factor.
3. **Independent coefficient reconstruction** recovered the paper denominator exactly from equations and raw forces, ruling out a shared normalization multiplier.
4. **Link-numerator decomposition** localized the sensitivity to cancellation between reflected populations and moving-wall correction.
5. **Near-wing fluid momentum balance** gave `(CL, CD)=(1.18092, 2.04933)` while legacy boundary accumulation gave approximately `(7.51, 9.56)`.
6. **A conservative moving-domain estimator** closed that independent balance within `0.002511/0.000247` maximum phase residuals under a `0.005` gate.
7. **A translating-sphere topology canonical** improved RMS momentum closure by `22,020×` over the retired estimator and made the corrected estimator the production default.
8. **The promoted 20/24-cell flapping ladder** then passed mean-load, phase, symmetry, periodicity, vortex, batching, and grid-change gates without relaxing thresholds.

This sequence is summarized in [`Docs/VALIDATION.md`](Docs/VALIDATION.md); machine-readable ledgers live in [`ValidationArtifacts/`](ValidationArtifacts/).

## Architecture

```mermaid
flowchart LR
    K["Analytic or measured kinematics"] --> G["Prepared articulated geometry"]
    G --> M["Occupancy masks and sub-cell links"]
    P["D3Q19 populations"] --> S["Pull streaming"]
    M --> B["Moving-boundary operator"]
    S --> B
    B --> C["TRT or regularized collision"]
    C --> P
    B --> R["GPU force and torque reduction"]
    R --> D["6-DoF rigid-body update"]
    D --> G
    P --> O["Read-only observation lease"]
    G --> O
    O --> V["Native Metal viewer"]
    P -. "momentum ledger" .-> A["Independent control-volume audit"]
    R -. "closure" .-> A
```

The package is an original implementation. Its software organization adopts PyFR’s controller/resource/command-graph separation: physical types and reference algebra are isolated from Metal resource orchestration, pipeline states are compiled once per backend, and a fixed GPU command graph is encoded repeatedly. The numerical operators themselves are Metal-specific MSL.

### Per-step coupled path

```text
prepare articulated pose and physical wall velocity
update current and previous solid occupancy
pull-stream 19 populations per fluid cell
apply interpolated moving-boundary reconstruction
recover density, velocity, and isothermal pressure
apply TRT or selected regularized collision + far-field sponge
accumulate link exchange and cover/uncover momentum
reduce force and torque deterministically on the GPU
optionally integrate the rigid torso and orientation
publish a read-only field lease when visualization requests one
```

Newly uncovered nodes are refilled from a local moving-boundary equilibrium. Newly covered nodes contribute their population momentum conversion to the body load. Demonstration and schema-1 prescribed wings remain explicitly massless. Schema 2 instead requires bilateral measured wing mass properties; the GPU applies their phase-resolved internal-momentum reaction to the body and archives left/right hinge reactions.

## Metal engineering

The production path is structured for Apple unified memory and predictable command submission:

- direction-major population storage gives adjacent GPU threads adjacent cell access;
- articulated wing frames are prepared once per timestep rather than once per cell;
- conservative bounds cull expensive bird geometry work;
- measured periodic keyframes are sampled once per timestep with physical rates preserved;
- occupancy and part identity share compact byte masks;
- the first deterministic load reduction is fused into fluid threadgroups;
- prescribed-wing phase loads reduce into a compact cycle buffer without per-step CPU waits;
- sub-cell boundary fractions reuse dormant solid-node population slots instead of allocating a full-grid link buffer;
- command-buffer batches are queued without intermediate CPU waits;
- density and velocity are captured only for the final externally visible step;
- fixed cases skip unused body-integration and intermediate load work; and
- allocation preflight rejects grids exceeding per-buffer or recommended working-set limits before partial allocation.

Optimization is accepted only when numerical state, loads, body state, and validation thresholds remain unchanged. [`Docs/BUILD_REPORT.md`](Docs/BUILD_REPORT.md) records the exact verification boundary and measured host timings.

## Native Metal viewer

```bash
swift run -c release birdflow-viewer
```

The same-process macOS viewer includes:

- pressure or `Cp` on the articulated body;
- arbitrary oblique slices with velocity, normal velocity, or vorticity;
- live world/velocity/vorticity probes and in-plane glyphs;
- RK2 pathlines with CFL subdivision and discontinuity reset;
- physical-unit vorticity and Q criterion;
- GPU classic marching cubes with capacity-safe indirect drawing;
- force, torque, body pose, solver time, render time, dropped-frame, and Q-capacity HUDs;
- versioned run bundles, derived-field keyframes, and exact compressed solver checkpoints.

Visualization receives only completed read-only field leases. Three best-effort slots prevent rendering from waiting the solver; if all slots are busy, the frame is dropped. The standalone compact M4 benchmark recorded `751.4 step/s` without observation and `643.2 step/s` with active offscreen rendering—`14.4%` ordinary GPU contention, zero visualization solver waits, and zero dropped frames.

Regenerate the hero GIF locally:

```bash
./Scripts/capture-readme-gif.sh
```

See [`Docs/VIEWER.md`](Docs/VIEWER.md) for controls, persistence formats, numerical separation, and verification.

## Quick start

### Requirements

- Apple-silicon Mac
- macOS 14 or later
- Xcode command-line tools with Metal compiler support
- Swift 6 or later
- Python 3 with NumPy and Matplotlib for reference/audit plots

### Build and run the local gates

```bash
swift build -c release
swift test -c release
./Scripts/check-metal.sh
python3 Scripts/static-audit.py
./Scripts/validate.sh
```

`check-metal.sh` invokes Apple’s offline compiler on both Metal libraries. `validate.sh` adds the independent reference cases and core production-Metal canonicals. Expensive flapping and high-Re refinement ladders remain explicit commands rather than surprise work inside every local check.

> [!NOTE]
> Validation is local-only. There are intentionally no GitHub Actions workflows, so pushes and pull requests do not consume hosted macOS CI minutes.

Latest recorded local run on Apple M4 (2026-07-16): **88 tests passed in 805.564 seconds**, followed by a successful release build, the independent physical-condition verifier, static Swift/MSL layout audit, and offline compilation of both Metal libraries.

## Run the solver

Fixed bird in an incoming stream:

```bash
swift run -c release birdflow \
  --steps 4096 \
  --report-every 128 \
  --reynolds 2000 \
  --reference-speed 8 \
  --lattice-speed 0.04
```

Free flight in initially stationary air:

```bash
swift run -c release birdflow \
  --free-flight \
  --steps 4096 \
  --report-every 128
```

Physical-domain-preserving refinement:

```bash
swift run -c release birdflow \
  --resolution-scale 2 \
  --steps 8192 \
  --report-every 256
```

`--resolution-scale N` multiplies grid dimensions, chord resolution, and sponge width by `N`, reducing `dx` and `dt` by `N`. Multiply the step count by `N` to compare the same physical duration. The executable emits CSV with time, body pose, linear velocity, aerodynamic force, and aerodynamic torque.

## Canonical validation commands

```bash
# Periodic shear-wave decay and convergence
swift run -c release birdflow validate shear-wave --resolution 32 --json

# Couette + oscillating Stokes moving walls
swift run -c release birdflow validate moving-wall --resolution 32 --json

# Topology-changing translating sphere and momentum closure
swift run -c release birdflow validate translating-body --json

# Re=100 fixed sphere
swift run -c release birdflow validate sphere --resolution 160 --json

# Re=100 aspect-ratio-2 fixed finite wing
swift run -c release birdflow validate wing --resolution 400 --json

# Published prescribed-wing input/geometry audit
swift run birdflow validate flapping-wing --audit-inputs --chord-cells 16 --json

# Published prescribed-wing production solve
swift run -c release birdflow validate flapping-wing --chord-cells 16 --json

# Current high-Re RR3 coarse-grid duration diagnostic
.build/release/birdflow validate translating-body \
  --high-re-stability --fixed-occupancy --stationary-wall \
  --recursive-regularization-duration --json
```

The fixed sphere and fixed wing are compact engineering canonicals, not substitutes for publication-scale domain and resolution studies. The accepted prescribed-wing composite is independently audited by:

```bash
python3 Scripts/audit-flapping-refinement.py
python3 Scripts/verify-measured-wing-physical-condition.py
```

## Measured geometry and kinematics

Audit a specimen input without allocating Metal resources:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --audit-only \
  --json
```

Replay prescribed motion and retain exact-input provenance plus phase loads:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --cycles 5 \
  --archive /path/to/specimen-replay-c12 \
  --json
```

Schema 1 requires SI units, source provenance, a COM-centered principal-axis frame, domain conditions, morphometrics, and independent left/right periodic pose and rate histories. Schema 2 adds measured bilateral wing mass, hinge-relative COM, inertia, and explicit whole-bird mass definitions for free flight. Cubic-Hermite interpolation keeps pose and wall velocity consistent. Preflight rejects invalid phase coverage, domain/sponge collisions, under-resolved thickness, and excessive estimated lattice Mach before Metal allocation.

The bundled complete-bird JSON is a **synthetic conformance fixture**, not a measured specimen. The measured right-wing surface tier is also intentionally wing-only. Read [`Docs/MEASURED_BIRD_DATA.md`](Docs/MEASURED_BIRD_DATA.md) before interpreting any replay.

For a same-specimen schema-2 input, `--load-refinement` runs the locked
five-cycle `8/12/16` load ladder and `--body-refinement --steps N` runs the
same-fluid `1/2/4` body-substep ladder. Free flight records bilateral inertial
hinge reactions and aborts on the first GPU-recorded Mach, clearance, or
non-finite-state event. Add `--momentum-ledger` to a free-flight replay to
archive direct population/body/wing momentum, far-field and sponge sources,
gravity, persistent-link exchange, inferred topology conversion, and both
locked `0.5%` closure gates. `--part-loads` additionally makes that intent
explicit and archives conservative body/left-wing/right-wing/tail loads,
aerodynamic hinge torque, prescribed-wing inertial reaction, required actuator
torque, and signed mechanical power:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/schema-2-specimen.json \
  --chord-cells 12 --steps 100 --body-substeps 4 \
  --part-loads --archive /path/to/free-flight-ledger --json
```

For deliberately symmetric input, add `--expect-bilateral-symmetry` to apply
the locked `2%` mirrored force, hinge-torque, and actuator-power gate. It is
opt-in because measured left/right asymmetry can be physical.

For a schema-2 forward-flight specimen with nonzero freestream,
`--trim-search` performs a bounded body-pitch/airspeed Gauss-Newton search. It
uses two-cycle candidates at the requested screening grid, then reruns only the
selected point for at least five cycles before applying the unchanged `5%`
force, moment, and stationarity gates:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/schema-2-specimen.json \
  --chord-cells 8 --trim-search --trim-iterations 2 \
  --archive /path/to/trim-search --json
```

The archive retains the byte-identical base input, every candidate result, and
the exact derived best-candidate JSON. Speed and Reynolds number scale together
so physical viscosity is unchanged; measured geometry and wing kinematics are
never tuned. A passing prescribed trim search is still not free-flight
boundedness or grid/body-step acceptance. Hover trim is rejected until the
input declares a physical aerodynamic control variable.

Use that archive's exact selected input for the combined confirmation gate:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/trim-search/best-candidate-input.json \
  --chord-cells 8 --free-flight-confirmation \
  --archive /path/to/free-flight-confirmation --json
```

The command starts three independent experiments from the same input: a
minimum five-cycle, four-body-substep free-flight trajectory; a one-cycle
`1/2/4` body-step ladder; and a one-cycle coupled momentum/per-part load audit.
The trajectory must remain within `0.10` chord position drift, `0.05` reference
speed, `5 deg` attitude change, and `0.05` cycle-scaled angular velocity while
also passing runtime, refinement, `0.5%` momentum, and `0.5%` part-sum gates.
Its atomic archive includes the byte-identical input, trajectory CSV, and every
nested report. These are solver boundedness thresholds, not a universal claim
about biological maneuver amplitude or passive stability.

The diagnostic is opt-in and lazily allocates only compact reduction buffers;
normal batched solver/viewer throughput is unchanged. The current missing-data decision is retained in
[`ValidationArtifacts/quantitative-complete-bird-readiness.json`](ValidationArtifacts/quantitative-complete-bird-readiness.json).

## Scientific boundary

BirdFlowMetal targets low-Mach flapping flight and wakes using an isothermal weakly compressible formulation, a uniform Cartesian grid, rigid surfaces, moving occupancy masks, and sub-cell link placement in the prescribed beta-wing benchmark.

Quantitative complete-bird claims still require:

- an actual measured specimen with body, both wings, tail, mass properties, geometry provenance, and synchronized kinematics;
- a surface representation appropriate to the measured feather/wing geometry;
- passing the five-cycle `8/12/16` measured-bird load ladder;
- a passing five-cycle-confirmed prescribed trim search at the declared flight
  condition, followed by the archived `--free-flight-confirmation` gate;
- a passing archived per-part load/actuator report on that specimen, with the
  bilateral symmetry gate enabled only when its input is intentionally
  symmetric;
- a confirmation trajectory that stays inside the declared boundedness and
  per-step Mach/sponge/domain abort bounds, plus its independently restarted
  coupled-momentum/per-part and `1/2/4` rigid-body substep runs;
- same-specimen schema-2 wing inertia and a passing archived hinge-reaction
  treatment (or a separately justified massless-wing scientific model);
- forced channel-flow coverage and any turbulence/flexibility model required by the target regime.

The high-Re stationary-sphere RR3 branch is a collision-operator research gate. It is **not enabled** in flapping or measured-bird replay while its force statistic is unresolved. The accepted prescribed flapping benchmark validates the production moving-boundary/load path; it does not magically validate arbitrary complete-bird morphology or free-flight physics.

## Repository map

```text
Sources/BirdFlowCore/
  D3Q19.swift                       lattice and host reference algebra
  SimulationConfiguration.swift    physical/lattice scaling and guards
  BirdModel.swift                   morphology and articulated kinematics
  RigidBody.swift                   six-degree-of-freedom CPU reference

Sources/BirdFlowMetal/
  BirdFlowSimulation.swift          GPU state and command graph
  MetalBackend.swift                device, pipelines, resource setup
  Metal*Validation.swift            production-kernel canonical harnesses
  GPUData.swift                     Swift/MSL-compatible layouts
  Metal/BirdFlow.metal              fluid, boundary, reduction, body kernels

Sources/BirdFlowVisualization/
  ...                               read-only field diagnostics and renderer
  Metal/Visualization.metal         Q, slices, pathlines, marching cubes

Sources/BirdFlowViewerApp/           native SwiftUI/MetalKit macOS viewer
Reference/                           independent numerical references
Scripts/                             local audits, plotting, capture, gates
ValidationArtifacts/                exact machine-readable scientific record
ValidationInputs/                   locked input fixtures and provenance
Docs/                                numerics, validation, viewer, data contract
```

Start with [`Docs/NUMERICS.md`](Docs/NUMERICS.md) for equations, [`Docs/VALIDATION.md`](Docs/VALIDATION.md) for acceptance logic, and [`Docs/BUILD_REPORT.md`](Docs/BUILD_REPORT.md) for what has actually been verified.

## Published anchors and data qualification

- Fixed-wing comparison: [Taira and Colonius, *Journal of Fluid Mechanics* (2009)](https://authors.library.caltech.edu/records/frnmk-28536).
- Measured hummingbird right-wing surface: [Maeda et al., *Royal Society Open Science* (2017), DOI 10.1098/rsos.170307](https://doi.org/10.1098/rsos.170307), deposited grid [DOI 10.6084/m9.figshare.5406124.v1](https://doi.org/10.6084/m9.figshare.5406124.v1), CC BY 4.0.
- Prescribed numerical comparison: [Dong et al., *Insects* (2022), DOI 10.3390/insects13050459](https://doi.org/10.3390/insects13050459).
- Synchronized dove geometry/kinematics/force candidate: [Deetjen et al., *eLife* (2024), DOI 10.7554/eLife.89968](https://doi.org/10.7554/eLife.89968), deposited data [DOI 10.5061/dryad.wwpzgmsqs](https://doi.org/10.5061/dryad.wwpzgmsqs), CC0 1.0.
- The checked Song et al. Dryad archive [DOI 10.5061/dryad.8ch1b](https://doi.org/10.5061/dryad.8ch1b) is retained only as reference-curve material; it does not contain a complete reconstructed bird mesh.

[`measured-wing-source-audit.json`](ValidationArtifacts/measured-wing-source-audit.json) locks source filenames, licenses, MD5/SHA-256 digests, coordinate registration, scale reconstruction, surface-area closure, and the fields still missing for complete-bird replay.
The follow-up [`same-specimen source-gap audit`](ValidationArtifacts/maeda-same-specimen-source-gap-audit.json)
enumerates the complete public Maeda collection and separates potentially
recoverable author/zoo records from measurements that likely require a new
campaign. A concise, ready-to-send availability inquiry is in
[`Docs/SAME_SPECIMEN_DATA_REQUEST.md`](Docs/SAME_SPECIMEN_DATA_REQUEST.md).
The independent
[`Deetjen dove source qualification`](ValidationArtifacts/deetjen-dove-source-qualification.json)
selects one bounded prescribed-force benchmark, locks its remote Zip64 members,
and separates measured force channels from modeled lateral force and inertia.
The follow-up
[`engineering ingestion audit`](ValidationArtifacts/deetjen-dove-engineering-ingestion.json)
CRC/SHA-verifies the selectively acquired nine-member flight, reconstructs the
1000/2000 Hz synchronization, and inventories the real body/wing/tail surfaces;
coordinate/topology conversion remains explicitly open.

## Reproducibility and citation

Validation artifacts are versioned JSON, figures are generated from those artifacts, and source-lock chains make stale provenance detectable. For academic discussion before a formal release DOI exists, cite the repository URL plus an immutable Git commit and name the exact artifact used. Do not cite a screenshot, GIF, branch name, or unarchived console result as quantitative evidence.

## License

BSD-3-Clause. See [`LICENSE`](LICENSE).

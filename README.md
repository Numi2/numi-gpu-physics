# BirdFlowMetal

BirdFlowMetal is a bird-specific, three-dimensional fluid–body solver for Apple silicon. It advances air on the GPU with a D3Q19 two-relaxation-time lattice Boltzmann method, represents an articulated bird as a moving solid boundary, obtains aerodynamic force and torque by momentum exchange, and can feed those loads into a six-degree-of-freedom rigid-body update.

The package is an original implementation. Its software organization adopts PyFR’s controller/resource/command-graph separation: host-side physical types and reference algebra are separated from Metal resource orchestration, pipeline states are compiled once per simulation backend instance, and a fixed per-step GPU graph is encoded repeatedly. The production fluid and boundary operators themselves are Metal-specific MSL.

This repository is a complete vertical slice, not a validated research result. The validation command compiles and executes the Swift/Metal path on a supported Mac, runs the independent reference checks, and now executes periodic shear-wave decay/refinement on the production fluid kernel. It does not yet implement the full canonical moving-boundary ladder in `Docs/VALIDATION.md`; those cases, aerodynamic-load grid convergence, and measured geometry/kinematics remain mandatory before bird-flight results are treated as quantitative.

## Implemented solver

The fluid state consists of 19 distribution populations per lattice cell. Density, velocity, and isothermal pressure are moments of those populations. The collision operator is TRT; populations are stored direction-major so adjacent GPU threads access adjacent cells.

The bird consists of a rigid body, two evaluated flapping-wing boundaries, and a tail. Wing stroke and pitch are prescribed analytically. Every fluid step performs:

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
- stores occupancy and part identity together in byte masks;
- folds the first deterministic load-reduction level into the fluid threadgroups instead of writing one load record per cell;
- stores density and velocity only for the final externally visible step of an `advance` call;
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

`check-metal.sh` compiles the `.metal` source directly with Apple’s offline compiler. `validate.sh` also runs independent periodic shear-wave references and the strict-math production-Metal shear-wave harness.

The test suite includes live Metal regressions for moving-wing fixed-body and free-flight batch partitioning, including total loads, captured fields, and body state. A direct CPU-versus-GPU rigid-body step covers translation, torque, angular velocity, and orientation. The production-Metal shear wave checks three-grid convergence, actual population-mass drift, steps 1–8 cell-by-cell against an independent CPU implementation, and command-buffer batch invariance.

## Run

Canonical production-Metal shear-wave validation:

```bash
swift run -c release birdflow validate shear-wave \
  --resolution 32 \
  --archive ValidationArtifacts/shear-wave \
  --json
```

The optional archive contains `report.json`, a format manifest, and final density/velocity fields for each refinement grid.

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

BirdFlowMetal targets low-Mach flapping flight and wakes. It currently uses an isothermal weakly-compressible formulation, rigid wing surfaces, a uniform Cartesian grid, and a voxelized moving boundary. Measured geometry, curved boundary links, turbulence closure, flexible-wing coupling, and multiblock refinement are planned extension directions rather than exposed plug-in interfaces.

Mach and domain-fit guards validate the initial configuration. Free-flight production studies must additionally monitor the evolving surface Mach number and sponge/domain margin and abort when either leaves the validated regime.

## License

BSD-3-Clause. See `LICENSE`.

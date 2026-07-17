# Native Metal viewer

Launch the same-process macOS viewer on Apple silicon with:

```bash
swift run -c release birdflow-viewer
```

## README showcase capture

Regenerate the repository's top-of-README GIF locally with:

```bash
./Scripts/capture-readme-gif.sh
```

The script invokes the native viewer's deterministic offscreen Metal path and
GPU-rasterizes the source-locked `2018_12_11_OB_F03` dove surface. The display
advances forward through the closest repeated source poses, zero-based surface
samples 27 through 121 (`27...121 ms`, a `94 ms` interval), in a body-following
frame. A velocity-matched cubic Hermite
transition closes the remaining `14 ms` for presentation only; the overlay
labels every closure frame and never treats it as measured kinematics or CFD.
The capture writes 72 unique display frames plus one pixel-identical endpoint
probe at `1120 x 630`; local `ffmpeg` encodes only the unique frames into a
continuous three-second loop with no reversed wingbeat. Full-frame palette
optimization creates
`Docs/Media/birdflow-metal-native-viewer.gif`. Transient wing ghosts and ribbons
are explicitly kinematic histories, not CFD streamlines. The embedded force
chart is decoded from the committed D32 RR3 source-viscosity full-window
artifact and remains explicitly descriptive. The D32 rail node is locked to
its audit: 15,104 positive finite steps, all 187 registered force bins, closed
momentum ledgers, and negligible correction intrusion. The top status and
`PROVENANCE` node additionally require the V2 reflected-population
preregistration, both passing selected-link D28/D32 cases, the exact
population/composition attribution, and its independent 16-check audit. They
report near-wall link composition as the stable `91.1%` absolute-ledger
leader, with `100.0%/83.45%` D28/D32 X/Z score coverage and zero capture
overflow or detail mismatch.
The scientific-boundary panel is separately locked to the failed D28/D32
`5.632% > 5%` refinement result. The chart's amber
`25...30 ms` band is locked to the independently audited archive-only phase
localization, not selected by the renderer. Capture rejects a surface, D32
window, refinement, localization, targeted case, provenance preregistration or
case, attribution, or audit that no
longer matches the locked hashes, the `144 / 2,157 / 3,968`
frame/vertex/triangle contract, the 187-bin force window, or the explicit
no-D36/no-convergence boundary. It also rejects
a wrong image size, display-frame count, frame rate, file budget, or
nonidentical endpoint probe.
Only the completed Metal render texture is read back for image encoding. Exact
earlier hero binaries are retained in [`Media/Progress`](Media/Progress/README.md).

The New Run sheet uses the CLI defaults: fixed flight, `Re=2000`, an `8 m/s`
reference speed, `0.04` lattice speed, resolution scale 1, and a 32-step solver
batch. It also exposes free flight, resolution scaling, and batch size. The
toolbar runs, pauses, advances one batch, resets, and resumes a `.bfcp`
checkpoint. Drag to orbit, right-drag to pan, scroll to dolly, and move the
pointer over the view to update the slice probe.

## Numerical boundary

`BirdFlowMetal` remains the only owner of populations, masks, load reductions,
and body state. It does not import `BirdFlowVisualization`, SwiftUI, MetalKit,
or AppKit. `BirdFlowVisualization` has its own command queue and Metal source.
Its only solver-volume interface is `GPUFieldFrameLease`, which can bind
density and velocity to `device const` compute arguments but cannot expose the
underlying `MTLBuffer` values.

Viewer runs request three observation slots and `.bestEffort` capture. A frame
is published only after its solver command buffer completes. A leased slot is
released after the renderer command buffer finishes. If all three are busy,
the field is dropped and the solver advances without waiting. The HUD reports
the displayed step, render/solver timing, frame drops, and Q-capacity warnings.
The static audit enforces the one-way module dependency and read-only shader
bindings.

This separation means visualization cannot change the physical timestep,
solver command ordering, loads, body state, density, or velocity. Rendering on
the same GPU can still reduce wall-clock throughput through ordinary GPU
contention; that cost is measured and reported, not described as zero.

## Layers

- The articulated body, tapered finite-thickness wings, and tail use the exact
  prepared geometry record captured with each field. Gauge pressure is sampled
  directly from density at an outward `1.5 dx` offset. A GPU histogram drives a
  lockable symmetric percentile range. Legends can use pascals or `Cp`; the
  latter is derived only from the configuration's valid reference dynamic
  pressure.
- One arbitrary slice supports X/Y/Z snapping, translation, yaw/pitch,
  velocity magnitude, signed normal velocity, physical vorticity, opacity,
  in-plane glyphs, and a live world/velocity/vorticity probe.
- Upstream and wing-tip tracers use trilinear velocity sampling, RK2, and
  half-cell CFL subdivision. More than eight required substeps resets the trail
  instead of connecting across skipped field time. Ribbons can be colored by
  speed or vorticity.
- The physical-unit diagnostic kernel computes vorticity in `s^-1`, Q in
  `s^-2`, and a validity mask excluding domain boundaries and the captured bird
  plus a one-cell stencil guard. The CPU reference and GPU convention are
  checked cell-by-cell on solid rotation, shear, strain, and a captured
  flapping-bird field before Q extraction tests run.
- Positive-Q surfaces use the classic 256-case marching-cubes lookup, GPU cube
  classification, an exclusive hierarchical scan, interpolated Q-gradient
  normals, and indirect drawing.
  Threshold changes reuse the verified Q field. The default capacity is two
  million triangles. Overflow sets the indirect vertex count to zero and shows
  a warning, so a partial surface is never displayed.

## Persistence

Choose a `.birdflowrun` bundle to begin every-step sample recording. Its
contents are:

```text
manifest.json       schema, configuration, bird, device, build identity, index
samples.bin         BFRUN001 header plus fixed 88-byte force/pose records
visualization.json  debounced camera, layers, legends, slice, ribbon, Q settings
derived/            manual .bfdf LZFSE vorticity/Q/valid-mask keyframes
checkpoints/        manual .bfcp LZFSE full solver checkpoints
```

Sample chunks are written asynchronously through a bounded queue. A queue or
storage failure pauses the run at a completed batch and retains the failed
chunk in memory; records are never silently skipped. Derived keyframes contain
no raw density or velocity. Full population and mask readback occurs only for
an explicit checkpoint. Both formats are versioned and checksummed, and corrupt
archives fail explicitly.

## Verification

The focused viewer checks are part of `swift test`. They cover observation
invariance, slot exhaustion and zero capture waits, contiguous samples,
checkpoint continuation and exact compressed population bytes, corrupt files,
settings/derived round trips, diagnostic thresholds, analytic sphere/plane
surfaces, all 256 cube sign configurations, overflow suppression, pressure and
oblique interpolation, glyph projection, pathline discontinuity reset, and a
finite nonempty offscreen render.

Run the complete local gates with:

```bash
swift test
swift test -c release
python3 Scripts/static-audit.py
./Scripts/check-metal.sh
./Scripts/validate.sh
```

The active-viewer throughput check is
`swift test -c release --filter viewerThroughputBenchmark`. It uses a compact
`48^3` strict-math case and renders a `320 x 240` pressure/slice frame every
four steps. On the Apple M4 validation host, the 2026-07-14 release result was
`751.4 step/s` with observation disabled and `643.2 step/s` with active
offscreen rendering: `14.4%` wall-clock GPU contention, zero visualization
solver waits, and zero dropped frames. This compact benchmark is a comparison,
not a promise that all scene/grid combinations have the same contention cost.

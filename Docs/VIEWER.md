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
momentum ledgers, and negligible correction intrusion. The phase-resolved
status additionally requires the V2 reflected-population
preregistration, both passing selected-link D28/D32 cases, the exact
population/composition attribution and 16-check audit, plus the zero-fluid
conditioned-factor preregistration, Shapley result, and independent 18-check
audit. They then require the planar direction-composition V2 preregistration,
40-case Metal/CPU result, and independent 14-check audit, followed by the exact
source link-geometry report and the curved D12/D16 preregistration, result, and
independent 14-check audit. Next, the sample-53 D28/D32 complete-link
preregistration, production-Metal/independent-CPU census, eight-gate
discriminator, and independent 16-check audit must all match their source
hashes. Finally, V14 requires the retained exact-parity phase-window failure,
the preregistered arithmetic-only V2 tie qualification, all 22 qualified
D28/D32 cases across samples 50 through 60, eight passing gates at every
phase, and the independent 18-check audit. The panel reports the worst
phase-window direction redistribution as `0.078%` whole histogram variation
and `0.0032%` maximum whole-response change. The rail advances to `PHASE OK`
and ends at `WALL OPEN`, because a zero-fluid count census does not establish
moving-wall velocity, interpolation, realized-population behavior, or
bird-load convergence. The underlying selected links
retain `100.0%/83.45%` D28/D32 X/Z score coverage and zero capture overflow or
detail mismatch.
The scientific-boundary panel is separately locked to the failed D28/D32
`5.632% > 5%` refinement result. The chart's amber
`25...30 ms` band is locked to the independently audited archive-only phase
localization, not selected by the renderer. Capture rejects a surface, D32
window, refinement, localization, targeted case, provenance preregistration or
case, conditioned-factor contract, planar or curved canonical, attribution, or audit that no
longer matches the locked hashes, either retained phase-window negative
control, the qualified phase census, the `144 / 2,157 / 3,968`
frame/vertex/triangle contract, the 187-bin force window, or the explicit
no-D36/no-convergence boundary. It also rejects
a wrong image size, display-frame count, frame rate, file budget, or
nonidentical endpoint probe.
Only the completed Metal render texture is read back for image encoding. Exact
earlier hero binaries are retained in [`Media/Progress`](Media/Progress/README.md).

## Formation Observatory capture

Regenerate the separate formation-flight presentation locally with:

```bash
./Scripts/capture-formation-observatory-gif.sh
```

The command decodes the c20 formation accounting archive, its 21 indexed field
captures, the preregistered sequential decision, the accepted 192-pose
geometry-only subcell ensemble, the common-offset c16/c18/c20 source
discriminator, and the complete passed c18 leader-q5 focused trace. It
evaluates the same published prescribed-wing kinematics for a leader and
phase-shifted follower, while presenting two copies of the locked Deetjen OB
F03 complete dove surface sequence. Each dove contains
`2,157` vertices and `3,968` triangles; source frames `27...121` feed the
forward replay and the existing velocity-matched `14 ms` Hermite segment closes
the visual loop. The dove surfaces are visual context only: they never enter
the archived voxel mask, fluid state, load, or power. The leader and follower
retain their intentional `Δφ=0.25` experimental offset. Every encoded frame
shows the archived c20 field at full opacity. Cyclic linear interpolation
between adjacent archived states removes presentation stepping, while the real
zero-phase capture anchors the loop seam. Slice hue shows signed vertical
velocity; opacity combines vorticity magnitude and absolute vertical velocity.
A mask-aware radius-4, sigma-2 Gaussian presentation filter suppresses the
lattice-scale seam, and hidden canonical solid cells are filled from surrounding
fluid samples so their unmatched silhouette does not cut a dark beam through
the dove scene. The archived fields and owner mask remain unchanged. Three wake
ridges follow the displayed c20 vorticity/vertical velocity, use cyan-to-violet wake age, and take
luminance from the normalized 4,820-step c18 leader-q5 reflected-population
trace. The follower-plane ring is a presentation locator. No overlay, label,
or text box is rendered. Interpolated fields, wake guides, and the ring remain
presentation-only and never enter the solver or reported forces.
The camera follows a spherical figure-eight with `±0.34 rad` yaw,
`±0.10 rad` pitch, and `±0.10 chord` distance variation. One yaw cycle and two
pitch lobes expose several angles while the wrapped phase makes its endpoint
parameters exactly identical to frame zero.

V10 also places an exact D3Q19 collision-streaming lens on the strongest
available positive-`x` archived wake ridge at the selected downstream phase.
The center represents the rest/collision population; six axial and twelve
face-diagonal nodes reproduce the complete moving stencil, and phase-locked
packets stream outward along all 18 links. The gold positive-`z` link is the
locked leader `q5` direction and its luminance follows the same 4,820-sample
boundary-source trace as the wake bridge. The cell frame, nodes, and packets
are presentation-only; no interpolated or invented population enters the
solver, force ledger, or archive. The scene is rendered through an
`RGBA16Float` target with half-resolution 25-tap selective bloom and bounded
highlight rolloff. All wake ribbons share one degenerate triangle-strip batch,
reducing their per-frame buffer allocations and draw calls to one.

V11 adds a phase-resolved resultant-force vector at each dove. Its direction is
cyclic linear interpolation of the corresponding three-component force in the
100-bin archived c20 report; its length is a square-root presentation map of
magnitude normalized by that flyer's cycle maximum. Both vectors are depth
tested and batched with the D3Q19 diagnostic geometry. This makes the chain from
collision and streaming through moving-boundary exchange to the archived flyer
load visible, while explicitly avoiding a scale-arrow or new-force claim.

The capture writes 48 unique frames plus a pixel-identical endpoint probe at
`1120 x 630`. The local script requires a seamless endpoint, exactly 48 encoded
frames, and a file below 10 MB before replacing
`Docs/Media/formation-flight-observatory.gif`. The source c20 run captured fields
GPU-resident at 20 requested follower-local phases plus its legacy final state.
A capture-side dove audit requires the exact Dryad/eLife identity, CC0 license,
144-frame source sequence, two-flyer topology, documented component evidence,
`Δφ=0.25`, and zero endpoint residual. It also bounds the tail's lateral
presentation scale below half the wing scale after the first visual pass showed
the reconstructed fan was too dominant. It also requires all `48/48` unique
capture phases to resolve the cyclic archived field at minimum opacity `1.0`.
A separate V11 manifest and fail-closed audit lock that sidecar, all
dove/source/CFD hashes, the independent source and q5-trace audits, exact
`1+6+12` D3Q19 topology, positive-`z` q5 cue, all 100 c20 force vectors,
21-slice combined hash, `8,014,782`-byte GIF, HDR/batching contract,
no-overlay figure-eight camera, forward-only frame count, encoded seam ratio
`0.973`, and a high-edge-density
burst limit that detects transient geometry streaks.
The independent V11 audit passes `65/65` checks. Exact V10 is retained under
`Docs/Media/Progress` before the load-vector layer.
A dedicated archive smoke proves that simultaneous field capture preserves
conservative owner accounting and reproduces the prior CPU vorticity extraction
to `1e-9` maximum absolute difference. The capture script itself neither reruns
nor mutates the fluid solution.

The detailed matched median-phase source result remains available as the static
convergence figure at
`Docs/Media/formation-flight-subcell-source-convergence.png`. The GIF reports
only its locked classification and two headline curvatures; it does not turn
the dove presentation replay into direction-resolved population evidence or
replace the prescribed-wing force owner.

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

# Measured bird data and prescribed replay

`birdflow replay measured-bird` is the first complete-bird data-ingestion
tier. It replaces hard-coded sinusoidal wing motion with phase-periodic,
independent left/right measurements and replaces demonstration dimensions with
registered specimen morphometrics. The exact input bytes and SHA-256 are
carried into every replay archive.

No measured specimen is bundled. `Examples/measured-bird-schema-v1.json` is
explicitly a synthetic conformance fixture and must not be cited as bird data.

## Published-source qualification

Use the source importer before constructing a specimen JSON:

```bash
python3 Scripts/import-measured-wing-grid.py \
  --input /path/to/rsos170307_si_008.zip \
  --song-dryad-tar /path/to/Data.tar \
  --output /tmp/measured-wing-source-audit.json
```

The importer verifies both deposited digests, parses all 17 PLOT3D surfaces,
registers the paper's backward/right/up coordinates to BirdFlow's
forward/left/up axes, locks the otherwise undocumented grid scale against the
published `70.0 mm` mean shortest-path length, and independently checks the
published mean wing area. It also fits the current rigid-span/linear-twist
proxy at every phase and reports the angular residual instead of hiding wing
bending and nonlinear twist.

The qualified Maeda et al. source is a measured `201 x 401` right-wing surface
over one hovering cycle, not a complete bird. The checked Song et al. Dryad
`Data.tar` contains numerical MATLAB figure sources but does not contain the
reconstructed wing or body meshes described in its article. The compact locked
result is `ValidationArtifacts/measured-wing-source-audit.json`; the full
per-frame report is regenerated from the original archives.

`--require-complete-bird` deliberately exits with status `2` for these sources.
They do not report the body radii, body-COM wing root, principal inertia, tail
geometry, measured left wing, or a physical wing thickness required by schema
1. Combining those values from another specimen would create a hybrid model,
not measured-bird input.

## Preflight before Metal

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --audit-only \
  --json
```

The audit rejects unsupported schemas, missing provenance, non-SI units,
incorrect coordinate frames, empty or unordered phase histories, non-finite
values, unresolved domain/sponge clearance, under-resolved surfaces, and a
conservative estimated lattice Mach above `0.15`. It reports the exact input
SHA-256, represented grid and domain, fluid timestep, cycle steps, and maximum
measured angular rate without allocating a Metal fluid volume.

The Mach bound evaluates the extrema of the cubic-Hermite angular-rate
polynomials between keyframes. A dataset cannot evade the guard merely because
its tabulated endpoint rates are small.

## Schema 1 contract

The machine-readable companion is
`Schemas/measured-bird-v1.schema.json`. Runtime decoding additionally enforces
phase ordering, exact first-phase coverage, finite values, domain fit,
resolution, and Mach constraints that JSON Schema cannot express alone.

The top-level JSON keys are:

- `schemaVersion`: exactly `1`;
- `datasetIdentifier`: stable study-local identifier;
- `provenance`: nonempty specimen identifier, geometry citation, kinematics
  citation, license, and processing description;
- `units`: exactly `meter`, `kilogram`, `second`, `radian`, and
  `radianPerSecond`;
- `coordinateFrame`: exactly right-handed, origin at center of mass, `+x`
  forward, `+y` left, and `+z` up. The inertia values must be principal moments
  in this frame;
- `geometryRepresentation`: currently exactly
  `registeredAnalyticProxyV1`;
- `geometry`: measured/registered body ellipsoid radii, mass, principal
  inertia, symmetric-average tapered-wing dimensions/root, and tail dimensions;
- `kinematics`: frequency and 4...4096 strictly increasing phase keyframes in
  `[0, 1)`, with the first phase exactly zero; and
- `replay`: registered domain/body pose and the measured flight condition.

Each left/right keyframe supplies stroke, deviation, pitch, and tip-twist
angles plus their physical angular rates. Rates are required rather than
silently differentiated because moving-wall force depends directly on wall
velocity. Pose and rate are joined with periodic cubic Hermite interpolation,
including the last-to-first interval.

The articulated rotation convention is fixed:

1. anatomical stroke rotates about body `+x`; the solver mirrors this rotation
   for the right wing;
2. deviation rotates about the stroke-rotated wing normal;
3. pitch rotates about the resulting span axis; and
4. tip twist is applied linearly from zero at the root to the measured value at
   the tip, with the corresponding spanwise wall velocity.

Angle unwrapping, filtering, phase alignment, coordinate registration, and any
left/right geometry averaging are data-processing operations. They must be
described in `provenance.processingDescription`; the loader does not guess.

## Prescribed replay and archive

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/specimen.json \
  --chord-cells 12 \
  --cycles 5 \
  --archive /path/to/specimen-replay-c12 \
  --json
```

`--steps N` can replace the cycle-derived duration, and `--batch-size N`
controls command-buffer partitioning. The body pose remains prescribed/fixed;
only the measured articulated wings move. The archive is created atomically and
contains:

- `input.json`: byte-for-byte source data;
- `report.json`: audit, SHA-256, device, resolution, runtime, means, and raw
  phase samples;
- `phase-loads.csv`: physical total force and torque for each step; and
- `FORMAT.txt`: the representation and scientific boundary.

## Scientific boundary

`registeredAnalyticProxyV1` ingests real morphometrics but remains an ellipsoid,
tapered-wing, and tapered-tail proxy. It is not a surface scan, mesh, or
mesh-derived signed-distance boundary. It is useful now for detecting unit,
registration, kinematic, Mach, force-balance, and sensitivity failures before
expensive refinement.

A quantitative complete-bird claim still requires actual measured input, a
mesh/SDF or cut-link geometry tier when surface fidelity matters, two-finest-grid
load convergence, stationary cycle statistics, force balance, left/right
part-load symmetry for symmetric motion, and the free-flight gates in
`Docs/VALIDATION.md`.

The Maeda source audit sharpened the geometry decision: its measured area varies
by `18.26%` over the cycle and the current linear-twist proxy reaches an
`8.05 deg` worst-phase spanwise RMS / `11.24 deg` maximum section-angle
residual. A fixed tapered proxy therefore remains useful for preflight only.

## Wing-only measured-surface tier

`Scripts/import-measured-wing-grid.py --surface-output` converts the locked
Maeda archive into
`ValidationInputs/maeda-hovering-right-wing-surface-v1.json`. This is not a
schema-1 complete-bird input. It retains all 17 measured phases with a
deterministic endpoint-inclusive `21 x 41` structured surface per phase,
BirdFlow axes, per-frame measured-root registration, the published `28.8 Hz`
frequency, source hashes, and the explicit periodic interpolation policy.

Run the Metal boundary gate with:

```bash
.build/release/birdflow replay measured-wing \
  --input ValidationInputs/maeda-hovering-right-wing-surface-v1.json \
  --chord-cells 8 \
  --json
```

The geometry and wall velocity use the same piecewise-linear phase segment.
The Metal implementation uses triangle-driven atomic voxel rasterization,
rather than searching the compact triangle set from every cell. A separate
resolve pass reconstructs the winning triangle's barycentric wall velocity,
and another synchronized pass constructs boundary-link fractions from signed
distance. The production cover/uncover momentum reservoir and
`stepFluidTRT` path are reused unchanged.

The remaining scientific unknowns are explicit: physical membrane thickness,
the left wing, body/COM registration, mass, inertia, and tail. Therefore
`--fluid-cycle` is a startup engineering diagnostic; it is not a quantitative
complete-bird result.

The promoted eight-cell `--thickness-ladder` runs `0.5/0.75/1.0`-cell
half-thickness cases through the complete fluid path. Every case passes its
geometry and fluid checks, but the full force-vector envelope is `6.7416%` and
the vertical-force envelope is `5.1810%`, narrowly exceeding the `5%`
sensitivity ceiling. At 12 chord cells the full-vector envelope contracts to
`5.2535%` and the vertical envelope to `4.4475%`; all individual cases still
pass, but full-vector thickness independence remains narrowly uncleared. The
16 chord cells the envelopes contract again to `3.9323%` and `3.3543%`, so
finest-grid thickness sensitivity clears. The `0.75`-cell mean-force vector
changes `2.7647%` from 12 to 16 cells, also clearing the finest-two `5%` gate.
This closes startup engineering refinement for the measured right-wing tier.
The subsequent five-cycle 16-cell stationarity run compares cycles four and
five and passes: mean force-vector difference is `0.3403%`, vertical difference
is `0.2406%`, and the complete phase-curve RMS difference is `0.1722%`. The
stationary vertical force is `11.01%` below the first-cycle value, confirming
that the stationarity gate was necessary. This closes wing-only numerical
acceptance, but it does not supply the missing complete-bird or measured-flight
inputs needed for quantitative physical interpretation.

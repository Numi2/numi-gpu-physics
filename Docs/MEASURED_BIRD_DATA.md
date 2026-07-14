# Measured bird data and prescribed replay

`birdflow replay measured-bird` is the first complete-bird data-ingestion
tier. It replaces hard-coded sinusoidal wing motion with phase-periodic,
independent left/right measurements and replaces demonstration dimensions with
registered specimen morphometrics. The exact input bytes and SHA-256 are
carried into every replay archive.

No measured specimen is bundled. `Examples/measured-bird-schema-v1.json` is
explicitly a synthetic conformance fixture and must not be cited as bird data.

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

# Deetjen dove prescribed-force benchmark

## Decision

The Deetjen et al. dove dataset is the highest-return public-data route for the
next BirdFlowMetal validation slice. It synchronizes processed structured-light
surface fits and 1000 Hz kinematics with two independently measured components
of aerodynamic force at 2000 Hz. This supports a prescribed-motion comparison
against experimental force truth that the Maeda wing record cannot provide.

It does **not** close the measured free-flight data requirement. The unobserved
right wing is assumed bilaterally symmetric, lateral force is computed, and the
wing mass distribution is modeled rather than measured for each specimen.
Those fields may support an explicitly hybrid uncertainty study but cannot be
promoted into the strict measured schema-2 gate.

The machine-readable decision, source locks, selected-member CRCs, and claim
boundary are in
[`deetjen-dove-source-qualification.json`](../ValidationArtifacts/deetjen-dove-source-qualification.json).

## Why this has the best ROI

The source archive is 19.3 GB, but its Zenodo mirror supports byte ranges. The
qualified flight `2018_12_11_OB_F03` is the smallest of the 20 analysis flights
with a complete `SurfFits.mat`. Selective acquisition costs approximately:

| Acquisition tier | Compressed transfer | Purpose |
|---|---:|---|
| Remote qualification | central-directory ranges only | reject source drift before downloading data |
| Engineering subset | 15,034,509 bytes | inspect force, kinematics, dimensions, timing, and derived analysis |
| Engineering subset plus surface | 671,462,764 bytes | implement the real processed-surface importer |
| Entire archive | 19,294,077,798 bytes | unnecessary for the first benchmark |

This turns a large unstructured download into one bounded flight with exact
member-level CRCs. It also keeps raw source data out of Git.

## Source qualification

The public record contains four individually named birds (`OG`, `OB`, `OP`,
and `BB`) with five analysis flights per bird. For the selected `OB` flight:

- `Kinematics.mat` contains 144 frames of multi-view point observations,
  triangulated 3D points, reprojections, and smoothed coordinates;
- `SurfFits.mat` contains the processed structured-light surface fits;
- the processed force-platform file contains `FxWings` and `FzWings` over
  196,800 samples with a reconstructed `0.0005 s` interval;
- the authors' `2TestRuns` product contains 144 synchronized frames, including
  blade-element leading/trailing edges and derived three-dimensional loads; and
- the dissection records contain same-bird morphometric measurements.

The deposited README explicitly says the original high-speed videos, original
camera-calibration content, and original unprocessed 3D reconstructions were
removed to save space. Compressed annotated videos and processed reconstructions
remain. The earlier Deetjen et al. 2020 deposit contains example reconstruction
code, but it is not a substitute for missing raw frames from this flight.

## Measured versus modeled

| Quantity | Classification | BirdFlowMetal use |
|---|---|---|
| `FxWings`, `FzWings` | measured, source-processed AFP channels | experimental comparison target |
| tracked 3D landmarks | measured, triangulated, and smoothed | pose and synchronization reconstruction |
| body/tail/left-wing surface fits | measured, reconstructed, and processed | prescribed moving boundary after importer audit |
| right-wing surface | bilateral-symmetry assumption | explicit geometric assumption |
| lateral force | computed | never label as measured |
| per-wing force and aerodynamic moment | modeled decomposition | diagnostic only unless independently reconstructed |
| body mass | measured sources combined by the authors | normalization with provenance |
| 20 wing point masses | cross-source scaled model | hybrid inertia sensitivity only |
| whole-bird and bilateral wing inertia | unavailable as same-specimen measurements | blocks measured schema 2 |

The force comparison must therefore use the horizontal and vertical total
external-force histories. It must not compare our per-part loads against the
source's derived per-wing loads as though both were measurements.

## Completed local ingestion proof

The selected nine-member subset, including `SurfFits.mat`, has been streamed
from the remote Zip64 archive and independently verified without committing
the source data. The reproducible inspector established:

- all nine uncompressed sizes and CRCs match the remote central directory;
- the full surface member SHA-256 is
  `985700b8904813dbdf62fc8339d5bc034f75a0862414b584313a23778c00f789`;
- the 144 kinematic frames map one-to-one onto force samples with a maximum
  timing residual of `8.89e-15 s` and retain 287 force samples at 2000 Hz;
- the surface contains a `200 x 200` body grid, a sparse `381 x 436` measured
  wing grid, 144 tail meshes, explicit body/wing/world transforms, and 20
  wing-to-body contact points per frame; and
- the source coordinates are millimeters and require an explicit `0.001`
  conversion before BirdFlow registration.

The ingestion evidence is
[`deetjen-dove-engineering-ingestion.json`](../ValidationArtifacts/deetjen-dove-engineering-ingestion.json).
It deliberately recorded BirdFlow coordinate registration, topology conversion,
and force sign/axis promotion as false at that stage. Decoding a field is not
the same as proving its physical mapping.

## Compact complete-surface gate

The next CPU-only gate is complete. The converter writes 144 non-periodic
laboratory-frame samples with 2,157 vertices per frame and one fixed 3,968-
triangle topology: body, measured left wing, explicitly mirrored right wing,
and tail. The 3.73 MB position stream and 23.8 KB index stream are small enough
to version and remain 128 triangles below the current Metal identifier limit.

The sparse measured-wing field contains visibility holes. The deposited
`zAll` surface is therefore used only inside the observed outline. Directly
remeshing the outline produced a false `91.9 m/s` tip speed when visibility
changed between frames. A 15-frame cubic Savitzky-Golay regularization of the
body-frame material coordinates reduces the maximum adjacent-frame speed to
`25.2305 m/s`, or `1.1807x` the deposit's independently stored `21.3687 m/s`
filtered blade-element maximum. The preregistered ceiling is `1.25x`.

Independent decoding from the deposited MATLAB files passes all hashes,
counts, index ranges, nondegeneracy, area, coordinate-bound, and wall-speed
checks. Worst absolute area errors are `4.703%` for the body, `8.905%` for each
wing, and `0.566%` for the tail. The wing tolerance is wider because temporal
material-point continuity is more important to moving-wall impulse than a
single-frame visibility outline.

Reproduce both stages after acquiring the source subset:

```bash
python3 Scripts/convert-dove-surface-sequence.py \
  --surface-mat /path/to/SurfFits.mat \
  --muscle-model-mat /path/to/2018_12_11_OB_F03.mat \
  --output ValidationInputs/deetjen-ob-f03-surface-v1 \
  --audit ValidationArtifacts/deetjen-dove-surface-conversion.json

python3 Scripts/audit-dove-surface-sequence.py \
  --manifest ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --surface-mat /path/to/SurfFits.mat \
  --muscle-model-mat /path/to/2018_12_11_OB_F03.mat \
  --conversion-audit ValidationArtifacts/deetjen-dove-surface-conversion.json \
  --output ValidationArtifacts/deetjen-dove-surface-cpu-parity.json
```

This proves conversion and wall-velocity input quality only. Metal occupancy,
fluid loads, force-axis/sign closure, repeatability across five flights, and
numerical refinement remain open.

## Reproducible acquisition

The default command is read-only. It verifies the Dryad/Zenodo identity,
license, file sizes and MD5 values, README SHA-256, Zip64 entry count, and every
selected member's size and CRC:

```bash
python3 Scripts/acquire-dove-benchmark.py --json
```

The offline form validates the committed totals and scientific claim boundary
without network access:

```bash
python3 Scripts/acquire-dove-benchmark.py --offline --json
```

After acquisition, reproduce the MATLAB inventory, synchronization, digests,
mass provenance, force-window statistics, and optional surface summary:

```bash
python3 Scripts/inspect-dove-benchmark.py \
  --input /path/to/deetjen-ob-f03 --include-surface
```

Acquire only the approximately 15 MB engineering subset:

```bash
python3 Scripts/acquire-dove-benchmark.py \
  --download --output /path/to/deetjen-ob-f03 --json
```

Add the selected flight's approximately 656 MB compressed surface member:

```bash
python3 Scripts/acquire-dove-benchmark.py \
  --download --include-surface \
  --output /path/to/deetjen-ob-f03 --json
```

Extraction streams one byte range per member, writes through a temporary file,
and promotes the file only after its uncompressed byte count and CRC match the
remote ZIP directory. A matching existing file is reused; a conflicting file
causes a hard failure.

## Benchmark implementation sequence

1. Decode the engineering subset and independently reproduce all recorded MAT
   variable names, dimensions, force sample interval, selected frame window,
   body weight, and sign conventions.
2. Decode `SurfFits.mat`; preserve the source coordinate frames and surface
   topology, and establish mesh area, landmark, bilateral-reflection, and unit
   closure before allocating a Metal volume.
3. Reconstruct the 1000 Hz geometry-to-2000 Hz force synchronization from the
   deposited source code. Archive the exact source member CRCs and converted
   input bytes.
4. Run a prescribed complete-surface replay at the reported `rho=1.18 kg/m^3`
   and `mu=1.849e-5 kg/(m s)` source-model convention, while recording any
   atmospheric uncertainty rather than calling those values same-flight
   measurements.
5. Compare measured `FxWings` and `FzWings` using impulse, mean, peak magnitude,
   peak phase, and phase-resolved residuals. Keep computed lateral and per-wing
   quantities outside the experimental acceptance verdict.
6. Use all five `OB` flights to estimate biological/measurement repeatability
   before freezing CFD error thresholds. Then run time-step and `8/12/16`
   spatial refinement without changing geometry or kinematics.

Source acquisition, MATLAB decoding, synchronization reconstruction, compact
topology conversion, BirdFlow frame registration, and independent CPU parity
are complete. Generic indexed-surface Metal replay is the active boundary. The
first single-flight replay is an engineering integration gate. Quantitative
experimental acceptance begins only after the repeatability envelope and
numerical refinement thresholds are preregistered from independent evidence.

## Claim after a successful ladder

A successful result can support this bounded statement:

> At the declared numerical and experimental uncertainty, BirdFlowMetal
> reproduces the measured horizontal and vertical external-force history of a
> prescribed, reconstructed Ringneck-dove flight.

It cannot by itself support passive stability, unforced free flight, measured
wing inertia, muscle-force recovery, or generalization across bird species.

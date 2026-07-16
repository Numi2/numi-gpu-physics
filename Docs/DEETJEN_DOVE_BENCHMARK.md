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

## Compact complete-surface gates

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

Run the separate geometry-only Metal gate after the CPU artifact passes:

```bash
swift run birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --archive ValidationArtifacts/deetjen-dove-indexed-metal-geometry.json
```

On Apple M4, all 144 frames plus five fractional-time interpolation probes
complete in `7.02 s` on a `59 x 53 x 50` grid. The host selects the common
interpolation interval once, avoiding the same timestamp scan in all 2,157
vertex threads. Strict Metal interpolation differs from the CPU reference by at
most `1.669e-8 m` in position and `1.907e-6 m/s` in vertex velocity. Five exact
CPU raster milestones have zero mask mismatches, `2.182e-5` maximum lattice
wall-velocity difference, and `1.574e-5` maximum signed-distance difference in
cell units. Body, both wings, and tail remain present in every frame and probe.

This closes conversion plus indexed Metal interpolation, component masks,
rasterization, and occupied-cell wall velocity. The gate allocates no fluid
populations and dispatches neither collision nor force accumulation. Fluid
loads, repeatability across five flights, and numerical refinement remain open.

## Production moving-boundary integration gate

The next gate connects the accepted indexed surface to the existing production
fluid path without paying for developed flow:

```bash
swift run birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --coupling-gate \
  --archive ValidationArtifacts/deetjen-dove-indexed-production-coupling.json
```

Periodic boundaries and zero sponge isolate the moving surface as the only
fluid-momentum source. Eight Apple M4 steps take `0.24 s`, exercise 39 cover and
53 uncover events plus 101,262 persistent boundary-link events, and retain all
four component identifiers. The independent event counter matches exactly.
Maximum wall Mach is `0.0693`. Directly reduced fluid momentum closes against
the production conservative moving-domain load with `1.789e-5` relative RMS and
`3.8846e-8 kg m/s` maximum absolute residual under the unchanged `0.005` gate.

The diagnostic persistent-link source split is archived but is not used for
acceptance because it reconstructs the halfway source while the production step
uses interpolated links. Acceptance uses only the production load and direct
before/after population momentum. This is an impulse-level integration result,
not developed-flow or measured-force agreement.

## Force-axis, sign, and window registration gate

Two additional source-code members are selectively acquired and locked by
size, CRC-32, and SHA-256. `AeroSonoEMG.m` establishes camera frame zero, the
2000/1000 Hz force/kinematics clocks, and the source's use of `-FxWings` and
`-FzWings` for external impulse. `MuscleModel.m` independently maps the
platform horizontal channel into source world `y` and samples it at
`(StartFrame + frame - 1) / FPS`. Combined with the accepted surface mapping,
the measured BirdFlow target is:

```text
BirdFlow force = [-FxWings, unavailable, -FzWings]
```

The lateral component is unavailable and is never represented as zero. The
source-world to BirdFlow transform has determinant `+1`. Nearest-sample lookup
and exact camera-zero arithmetic both select source indices `191878...192164`.
They agree at every stored surface frame with `8.89e-15 s` maximum source-time
residual. The canonical target contains 287 samples over `0.143 s`: 144 samples
coincide with stored surfaces and 143 lie at the exact half-frame interpolation
points. The source's derived per-wing vertical series independently matches
`-FzWings/2` with zero maximum residual. The measured impulses in BirdFlow
coordinates are `0.0207113 N s` forward and `0.162774 N s` upward.

Reproduce the conversion and its separate committed-input audit with:

```bash
python3 Scripts/register-dove-force-window.py \
  --input /path/to/deetjen-ob-f03

python3 Scripts/audit-dove-force-target.py
```

The outputs are
[`deetjen-ob-f03-force-v1.json`](../ValidationInputs/deetjen-ob-f03-force-v1.json),
[`deetjen-dove-force-registration.json`](../ValidationArtifacts/deetjen-dove-force-registration.json),
and
[`deetjen-dove-force-target-cpu-parity.json`](../ValidationArtifacts/deetjen-dove-force-target-cpu-parity.json).
This gate clears the input for one coarse prescribed-motion fluid pilot. It is
not measured-force agreement, uncertainty quantification, or grid acceptance.

## Coarse viscosity-floor fluid pilot

The bounded production pilot is reproducible with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --coarse-fluid-pilot \
  --archive ValidationArtifacts/deetjen-dove-coarse-force-pilot.json \
  --json

python3 Scripts/audit-dove-coarse-force-pilot.py
```

The target contains a `0.025 s` pre-roll, the authors' inclusive 187-sample
analysis window from `0.025` through `0.118 s`, and a `0.025 s` post-roll used
to preserve nonperiodic endpoint kinematics. The pilot advances 16 fluid steps
per force sample, or 3,776 steps through the comparison endpoint. At the fixed
`0.01 m` engineering grid, source `rho=1.18 kg/m^3` and
`mu=1.849e-5 Pa s` imply `tau+=0.50001469`, below BirdFlowMetal's Float TRT
margin. The pilot therefore declares `tau+=0.501`; its effective viscosity is
`68.07x` the source convention. `experimentalAgreementGateApplied` is false by
construction.

The run is a negative integration result, not a force curve. The first sampled
negative population appears at fluid step 176 (`5.5 ms`) in D3Q19 direction 7,
cell `[31,35,29]`, `0.0764` cells from the moving surface. The load reduction
becomes nonfinite at step 331, before the 800-step pre-roll completes, so no
comparison samples or aggregate force errors are emitted. The independent
audit passes because it verifies the archive and the negative outcome; the
pilot integration gate remains false. This distinction prevents an artifact-
integrity pass from being misreported as physical acceptance.

The highest-ROI next experiment is a controlled near-wall collision-operator
A/B with geometry, grid, time step, viscosity floor, boundary treatment,
sponge, and gates fixed. A candidate advances only if it survives at least the
800-step pre-roll with positive populations and finite loads. Five-flight
repeatability and measured-force refinement remain deferred until then.

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
  --download --include-surface --include-force-code \
  --output /path/to/deetjen-ob-f03 --json
```

`--include-force-code` adds only `28,994` compressed bytes and is required to
regenerate the force-registration evidence. The deposited scripts are not
committed into this repository.

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
topology conversion, BirdFlow frame registration, independent CPU parity,
indexed Metal geometry, production impulse coupling, and force target
registration are complete. The coarse prescribed-motion pilot is executed and
fails its pre-roll positivity/load gate with a localized near-wall population.
Quantitative experimental acceptance begins only after a fixed-input collision
candidate survives that boundary, the five-flight repeatability envelope is
established, and time/space refinement is preregistered and passed.

## Claim after a successful ladder

A successful result can support this bounded statement:

> At the declared numerical and experimental uncertainty, BirdFlowMetal
> reproduces the measured horizontal and vertical external-force history of a
> prescribed, reconstructed Ringneck-dove flight.

It cannot by itself support passive stability, unforced free flight, measured
wing inertia, muscle-force recovery, or generalization across bird species.

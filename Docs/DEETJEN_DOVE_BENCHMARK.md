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

The later source-scaling audit verifies both fluid-property constants directly
from the SHA-locked deposited `MuscleModel.m` and reconstructs the viscosity
ratio on D8/D12/D16. They are author-code conventions, not same-flight
atmospheric measurements. The article reports no ambient temperature, pressure,
humidity, or Reynolds number. BirdFlow's `128,813` source-property Reynolds is
therefore labeled an engineering maximum-wall-speed/`0.08 m` proxy; it differs
by `25.773%` from the deposited-blade-speed/selected-mean-chord proxy `102,417`.
See `ValidationArtifacts/deetjen-dove-source-scaling.json` and its independent
audit.

The run is a negative integration result, not a force curve. The first sampled
negative population appears at fluid step 176 (`5.5 ms`) in D3Q19 direction 7,
cell `[31,35,29]`, `0.0764` cells from the moving surface. The load reduction
becomes nonfinite at step 331, before the 800-step pre-roll completes, so no
comparison samples or aggregate force errors are emitted. The independent
audit passes because it verifies the archive and the negative outcome; the
pilot integration gate remains false. This distinction prevents an artifact-
integrity pass from being misreported as physical acceptance.

The controlled near-wall collision screen is now reproducible with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-pre-roll-ab \
  --archive ValidationArtifacts/deetjen-dove-collision-pre-roll-ab.json \
  --json

python3 Scripts/audit-dove-collision-pre-roll-ab.py
```

Geometry, kinematics, grid, time step, viscosity floor, boundary treatment,
sponge, force estimator, and thresholds are identical in all three arms.
Population minimum is reduced every step. This localizes the production-TRT
control's first negative population at step 150 (`4.6875 ms`) in the same
direction-7 near-surface fluid cell. Positivity-preserving regularized BGK and
recursive-regularized BGK both survive all 800 steps with finite loads and
positive populations. Their convex correction activates in 55 and 28
cell-steps (`2.013e-7` and `1.025e-7` of all cell-steps), both far below the
fixed `5%` screening ceiling.

The screen makes both candidates eligible for a candidate-specific momentum-
closure gate and extended pilot only. It does not promote either collision
operator into measured-bird production, compare experimental forces, or clear
the unresolved RR3 sphere force statistic. Five-flight repeatability and
measured-force refinement remain deferred.

Reproduce the candidate-specific momentum gate with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-momentum-closure \
  --archive ValidationArtifacts/deetjen-dove-collision-momentum-closure.json \
  --json

python3 Scripts/audit-dove-collision-momentum-closure.py
```

The fixed control volume spans `[7,68) x [7,62) x [7,59)` on the unchanged
`75 x 69 x 66` grid. It is five cells beyond the complete swept surface,
outside the six-cell sponge, and records zero solid-crossing links. Over all
800 pre-roll steps, regularized BGK and RR3 close the conservative moving-
domain load against independent storage-plus-flux force at `0.07944%` and
`0.07987%` relative RMS. A whole-domain before/after fluid ledger with only
far-field and sponge sources removed closes at `0.11459%` and `0.11453%`.
The independent audit rebuilds both residual histories and all summary values.

Both candidates therefore advance to the fixed extended pilot. This result
does not select RR3 from its lower activation count, promote either operator,
apply an experimental-force gate at the viscosity-distorted coarse grid, or
clear the later refinement/repeatability requirements.

Reproduce the full registered-window extension with:

```bash
.build/release/birdflow replay measured-bird-surface \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --collision-extended-pilot \
  --archive ValidationArtifacts/deetjen-dove-collision-extended-pilot.json

python3 Scripts/audit-dove-collision-extended-pilot.py
```

Regularized BGK and RR3 both complete all 3,776 steps and 187 registered
comparison samples with finite loads and positive populations. Their minimum
populations are `2.642e-9` and `3.202e-9`. Correction remains limited to the
same 55 and 28 cell-steps, now `4.265e-8` and `2.171e-8` of all cell-steps.
Endpoint and interval-mean force histories differ between operators by only
`0.656%` and `0.882%` normalized RMS. The independent audit reconstructs all
force statistics and pairwise differences from the archived samples.

The reported endpoint measured-force errors (`5.665` and `5.676`) and interval-
mean errors (`2.274` and `2.264`) are descriptive only. The pilot remains
`68.07x` over-viscous, so these values cannot select a collision operator or
support experimental agreement. The following preregistered D=8/D=12
discriminator instead fixes physical domain, thickness, timing, Mach, and
viscosity. Both operators pass both grids. Their D8-to-D12 trend scores are
`0.125454` and `0.125081`, and their disagreement decreases from `0.882%` to
`0.816%`. With neither operator more than 10% worse in grid trend, the locked
stationary-wall correction gate selects RR3 and authorizes no other D=16 run.
RR3 then fails that completion at step `751/7,552`: direction 0 is negative at
cell `[64,63,68]`, `0.2151` cells from the surface, before any force-comparison
sample. The independent audit preserves this negative result and confirms that
no D12-to-D16 force metric is available.

A sparse stage-provenance replay then reproduces the same D=16 failure while
capturing only cell `[64,63,68]`, direction 0, at steps `747...751`. The
diagnostic prediction matches the production output exactly. At step 751 the
selected population is positive before and after reconstruction, while five
moving-boundary-reconstructed directions (`2, 8, 12, 13, 16`) are already
negative. They produce reconstructed lattice speed `1.007461`, above the
direction-0 equilibrium positivity limit `0.816497`. The RR3 limiter scale
therefore reaches zero but returns a negative equilibrium, so collision first
writes direction 0 as `-0.003425966`. Persistent-fluid topology, zero sponge,
and no far-field use exclude the other fused stages for the selected write.
The independent audit reconstructs the entire RR3 chain from the archived 19
incoming populations. This identifies the numerical failure path; it does not
yet validate or repair the upstream moving-boundary terms.

The following two-step boundary decomposition distinguishes those terms. Its
17-direction reconstruction matches the prior stage archive within
`1.892e-10`, and every contribution sum closes within `1.747e-10`. The negative
direction set changes from `[2,3,10]` at step 750 to `[2,8,12,13,16]` at step
751. At failure, all reflected populations and auxiliary contributions are
nonnegative, whereas all five wall corrections are negative. Four failing
links already use halfway fallback; moving-wall halfway fixes none and makes
the lone far-wall link more negative. Zero-wall counterfactuals make all five
positive, while removing only the interpolation auxiliary term fixes none.
The independent audit therefore isolates moving-wall-correction admissibility,
not interpolation branch selection or inherited negative reflection, as the
first repair surface. No counterfactual is enabled in production.

The follow-on archive-only admissibility A/B reconstructs every pre-step
population at the failure cell. Pre-step local-density normalization removes
all negative populations without a limiter (minimum `5.580e-5`, lattice Mach
`0.5482`); the reference-density positivity alternative requires an active
global scale of `0.11505`. The independently audited result advances the local
density candidate only to a controlled force/momentum-ledger experiment. It
does not change the production boundary law or reopen the refinement ladder.

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
4. Run a prescribed complete-surface replay at the deposited author-code
   `rho=1.18 kg/m^3` and `mu=1.849e-5 kg/(m s)` convention, while recording any
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
registration are complete. The coarse production-TRT pilot fails its pre-roll
positivity/load gate with a localized near-wall population. Two positivity-
preserving alternatives pass the fixed pre-roll, independent momentum closure,
and the full 3,776-step registered-window extension. The preregistered D=8/D=12
decision selects RR3, but its sole authorized D=16 run fails positivity before
the comparison window under the old fixed-viscosity scaling.

The subsequent source-property reconstruction established D28 as the first
grid meeting the unchanged production `tau+>=0.50005` margin. RR3 then passed a
2,800-step D28 pre-roll and the preregistered 13,216-step full measured-force
window. All 187 bins were recorded; minimum population stayed positive;
near-wing/global momentum residuals were `0.0824%/0.1507%`; and correction
activated in only `0.00136%` of cell-steps. An independent audit reconstructs
every step and bin. This cleared the earlier fine-grid numerical-survival
blocker, but not quantitative experimental acceptance: joint normalized RMS
force error is `2.1357`, vertical mean force is `39.0%` high, and horizontal
mean force is `74.5%` low.

The fixed-physics D32 member is now complete too. Its preregistered `296 x 271
x 261` RR3 case completed the 3,200-step pre-roll and separately frozen
15,104-step force window on Apple M4. All 187 bins were recorded; minimum
population was `4.685e-9`; near-wing/global ledgers closed at
`0.1613%/0.0964%`; and correction activation was `0.00144%`. Independent
audits pass 18/18 pre-roll and 17/17 full-window checks.

The preregistered D28/D32 pair nevertheless misses the inherited `5%`
phase-history stabilization limit: the primary difference is `5.632%`, with
horizontal/vertical component differences `7.376%/4.661%`. Mean, impulse, and
peak time are stable below `0.8%`, but that cannot override the history gate.
Archive-only phase localization places `42.67%` of total squared difference in
the first 11 ms and identifies `25...30 ms` as the highest-information 5 ms
target; a simple time lag does not explain it. The preregistered targeted replay
then reproduced both archived trajectories exactly and closed reflected,
moving-wall, interpolation, and topology components at `2.68e-5/3.33e-5`
relative RMS. Its independent 15-check signed-energy audit identifies
reflected-population self energy as a stable dominant contribution (`58.43%`
of the absolute ledger in both temporal halves). Negative interactions with
topology (`14.68%`) and interpolation (`7.51%`) prohibit a one-term rescaling.
D36 is still not authorized. The next allocation should record selected-link
pre-step outgoing-population provenance at D28/D32 to distinguish bulk
collision/transport history from near-wall interpolation history. The
five-flight repeatability envelope also remains open. These results are
numerical refinement evidence—not experimental agreement, production
readiness, or free flight.

## Claim after a successful ladder

A successful result can support this bounded statement:

> At the declared numerical and experimental uncertainty, BirdFlowMetal
> reproduces the measured horizontal and vertical external-force history of a
> prescribed, reconstructed Ringneck-dove flight.

It cannot by itself support passive stability, unforced free flight, measured
wing inertia, muscle-force recovery, or generalization across bird species.

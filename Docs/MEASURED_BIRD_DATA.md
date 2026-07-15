# Measured bird data and prescribed replay

`birdflow replay measured-bird` is the first complete-bird data-ingestion
tier. It replaces hard-coded sinusoidal wing motion with phase-periodic,
independent left/right measurements and replaces demonstration dimensions with
registered specimen morphometrics. The exact input bytes and SHA-256 are
carried into every replay archive.

No measured complete specimen is bundled. `Examples/measured-bird-schema-v1.json` is
explicitly a synthetic conformance fixture and must not be cited as bird data.
The current source-by-source decision is machine-readable in
`ValidationArtifacts/quantitative-complete-bird-readiness.json`.

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
3. anatomical pitch rotates about the resulting outward span axis, with its
   algebraic world rotation reversed on the right wing so equal bilateral
   values produce mirror geometry; and
4. tip twist is applied linearly from zero at the root to the measured value at
   the tip, with the corresponding spanwise wall velocity and the same
   right-wing anatomical sign convention as pitch.

Angle unwrapping, filtering, phase alignment, coordinate registration, and any
left/right geometry averaging are data-processing operations. They must be
described in `provenance.processingDescription`; the loader does not guess.

## Schema 2 quantitative free-flight contract

`Schemas/measured-bird-v2.schema.json` extends the prescribed schema with
`prescribedWingDynamics`. It requires left and right measured wing mass,
hinge-relative center of mass, and principal inertia in the instantaneous
untwisted chord/span/normal frame. Whole-bird mass must include both wings and
the registered principal inertia must describe the whole bird at the declared
reference pose. A source citation is mandatory.

The first implemented model is `prescribedRigidWingMomentumV1`. At every fluid
step the GPU reconstructs each wing's linear and angular momentum about the
body origin, differences it against the previous phase, and applies the
opposite rate to the six-DOF body equation. Archives record the resulting left
and right inertial hinge reactions separately. This closes the previously
silent massless-wing coupling for rigid prescribed wings. Because this model
uses one rigid mass frame per wing, schema 2 rejects distributed tip twist;
twisting measured wings require a future distributed-mass model rather than a
hidden approximation.

Free flight is deliberately unavailable to schema 1 measured inputs:

```bash
.build/release/birdflow replay measured-bird \
  --input /path/to/same-specimen-v2.json \
  --free-flight \
  --body-substeps 4 \
  --steps 1000 \
  --json
```

The GPU evaluates the evolving conservative surface Mach and rotated
bird-to-sponge/stencil clearance after every body update. It records the exact
first violating step and aborts before submitting another command-buffer
batch if Mach exceeds `0.15`, clearance becomes negative, or body state becomes
non-finite.

Two independent refinement commands keep their changed variable explicit:

```bash
# Same fluid grid and fluid dt; only rigid-body dt changes (1/2/4 substeps).
.build/release/birdflow replay measured-bird \
  --input /path/to/same-specimen-v2.json \
  --body-refinement --steps 1000 --chord-cells 12 --json

# Fixed prescribed motion; five-cycle 8/12/16 load and stationarity ladder.
.build/release/birdflow replay measured-bird \
  --input /path/to/same-specimen-v2.json \
  --load-refinement --cycles 5 --json
```

The body ladder locks the fine `2 -> 4` differences to `1%` of root chord,
`1%` of reference speed, `0.5 deg`, and `1%` of wingbeat angular frequency.
The load ladder locks cycles four/five and the `12 -> 16` force/torque change
to `5%` of declared physical force and torque scales.

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
only the measured articulated wings move unless `--free-flight` is explicit.
The archive is created atomically and
contains:

- `input.json`: byte-for-byte source data;
- `report.json`: audit, SHA-256, device, resolution, runtime, means, and raw
  phase samples;
- `phase-loads.csv`: body trajectory, physical total aerodynamic load, and
  bilateral prescribed-wing inertial hinge reaction for each step; and
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

## Physical-condition provenance

The Maeda experiment reports approximately `22 deg C`, but it does not report
pressure, humidity, density, viscosity, Reynolds number, a force-coefficient
reference speed, or aerodynamic loads. Those omissions are source facts, not
values to fill with a generic sea-level atmosphere. The phase-resolved
supplement does show a wingtip relative-wind peak of roughly `11.2 m/s`; that
is a measured kinematic maximum, not a declared normalization velocity. The
compact replay independently reaches `11.1517992 m/s` under its locked
piecewise-linear interpolation and uses that maximum only to choose a safe
timestep and lattice Mach number.

Dong et al. later published CFD for the Maeda wing and declared a reproducible
numerical convention: `Uref=7.1758 m/s`, `rho=1.205 kg/m^3`,
`mu=1.81e-5 Pa s`, and `Re=9367.4`. This condition may be used for a
paper-comparable numerical replay, but `rho=1.205 kg/m^3` must not be described
as a measured greenhouse density. The printed rounded inputs reconstruct
`Re=9315.6549`, a `0.5524%` difference; that closure gap and the paper's
inconsistent table-3 speed are retained in
`ValidationArtifacts/measured-wing-physical-condition-audit.json`.

Run the sub-second arithmetic gate before any physical-condition CFD:

```bash
python3 Scripts/verify-measured-wing-physical-condition.py
```

This separation has high leverage: it prevents the cleared `Re=100` numerical
histories from being rescaled into a false physical claim while giving local
Metal feasibility runs an explicit, published target.

The promoted eight-cell one-cycle gate now runs with
`--published-condition`. It fails honestly on Apple M4: the geometric audit
still passes, but `tau+=0.500131488` and the first non-finite load appears at
step `358/1992` (`t/T=0.179719`). The final populations are non-finite, so the
run has no valid mean force or mass-drift result. The compact failure record is
`ValidationArtifacts/measured-wing-published-condition-feasibility-c8.json`.
This blocks the five-cycle published-condition ladder. A one-cycle 12-cell run
was therefore run: its TRT relaxation margin increases by `50.18%`, but the
first non-finite load moves earlier from phase `0.179719` to `0.144102`.
Resolution from 8 to 12 cells does not provide a monotonic stability cure. The
12-cell failure is retained in
`ValidationArtifacts/measured-wing-published-condition-feasibility-c12.json`.
The 16-cell cycle also fails despite doubling the eight-cell relaxation
margin: its first non-finite load appears at step `334/3976`, phase `0.084004`,
earlier than both coarser failures. The record is
`ValidationArtifacts/measured-wing-published-condition-feasibility-c16.json`.
Resolution-only escalation is therefore closed.

The fixed-topology collision discriminator is:

```bash
.build/release/birdflow validate moving-wall --high-re-stability --json
```

It reuses production `stepFluidTRT`, wall lattice speed `0.08`, and the exact
c8/c12/c16 viscosities for 500 steps in a fixed `16^3` planar channel. All
three cases pass on Apple M4 in `0.95 s`, with finite loads and fields,
positive final populations, and worst relative mass drift `1.23647e-5`. The
archive is
`ValidationArtifacts/measured-wing-high-re-fixed-moving-wall-stability.json`.
Because the same collision kernel survives when occupancy is fixed, changing
collision physics has low diagnostic ROI. The matching topology-changing test
is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --json
```

The radius-`3.25` sphere translates 40 cells through a `56 x 24 x 24` periodic
domain over 500 steps. The c8/c12/c16 cases become non-finite at steps `276`,
`282`, and `287` respectively, despite zero solid crossings of the independent
control surface. All three requested paths contain 1,280 cover and 1,280
uncover events. The Apple M4 run takes `1.17 s`, returns a failed validation
status, and is archived in
`ValidationArtifacts/measured-wing-high-re-translating-body-stability.json`.

The fixed-occupancy comparison is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --json
```

With the sphere mask fixed and all cover/uncover counts exactly zero, the same
three cases fail earlier at steps `71`, `71`, and `72`. The `1.17 s` Apple M4
record is
`ValidationArtifacts/measured-wing-high-re-fixed-occupancy-sphere-stability.json`.
Thus topology refill is not necessary; curved moving-link boundary forcing is
already sufficient under this operator stress.

Uniform translation on a fixed sphere includes a nonphysical normal wall
component. The component A/B is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --decompose-wall-velocity \
  --json
```

Normal-only c8/c12/c16 all fail at step `86`; tangential-only cases fail at
steps `186`, `187`, and `189`. The `3.05 s` Apple M4 run has no topology
events and is archived in
`ValidationArtifacts/measured-wing-high-re-fixed-occupancy-wall-decomposition.json`.
Thus the low-margin instability is general to curved moving links rather than
normal-only, although normal forcing grows unstable sooner.

The stationary-wall discriminator is:

```bash
.build/release/birdflow validate translating-body \
  --high-re-stability \
  --fixed-occupancy \
  --stationary-wall \
  --json
```

The boundary-component capture found that this supposedly stationary case had
been passing `referenceSpeedLattice` to the GPU wall parameter. The GPU now
uses `caseConfiguration.wallVelocityLattice`, the static audit locks that
wiring, and every invalid stationary-wall artifact has been replaced. The
genuinely moving-wall cases are unaffected because both speeds coincide there.

With the corrected zero wall speed, maintained far-field boundaries, and the
`0.04` sphere sponge, all c8/c12/c16 cases become non-finite at step `105`
after 104 finite load samples. The corrected fourteen-point relaxation sweep
is monotonic: margin `0.01` fails at step `454`, `0.0125` is the first stable
500-step point, and every larger sampled margin through `0.05` remains finite.
The `--long-horizon-survival` audit then keeps margins `0.015625`, `0.016875`,
and `0.02` finite through 1,000 steps with relative mass drift near `1e-4`.
All still fail the independent force-budget acceptance contract.

The corrected c16 positivity trace locates the first negative at step `27`:
`q=10`, direction `(-1,1,0)`, boundary-adjacent cell `(5,9,12)`, and signed
sphere distance `0.320714` cells. Five pull directions reach the sphere, but
the failing `q=10` source `(6,8,12)` is ordinary fluid and the event is outside
the sponge. The first NaN follows at step `105`, inside the sponge and
coincident with the first non-finite load. The one-cell TRT decomposition
closes within `7.45e-9`; every reconstructed incoming value is positive and
the captured stationary-wall correction is exactly zero. The `q=10` symmetric
increment is `-0.03093607`, while the antisymmetric increment is a stabilizing
`+9.07e-6`, isolating symmetric TRT overshoot at `omegaPlus=1.9989468`.

The corrected symmetric-limiter treatment finishes all 500 steps finite and
positive, with minimum population `8.72842e-9`; the control becomes negative
at `27` and non-finite at `105`. Its per-step mass/momentum ledger closes the
apparent conservation failure. Open far-field replacement contributes
`-212.359` mass units and sponge relaxation `+152.514`, while limiting
contributes only `-0.0151`, or `4.69e-7` of initial mass. Sponge momentum is
`0.125604 N` RMS versus `3.34e-7 N` RMS from limiting and explains the old
force residual to `0.287%` RMS. Boundary load closes independently to
`3.03e-7` relative RMS. A follow-up c16 run moves the control volume wholly
outside the four-cell sponge (`[4,4,4]` through `[52,20,20]`), where all 500
samples contain zero sponge cells and zero solid links cross the control
surface. The global source ledger closes, maximum raw force residual is
`0.000464316 N` under the `0.0005 N` gate, and relative RMS residual is
`0.00537%` under the `0.5%` gate. The source-aware c16 acceptance passes. The
subsequent geometrically similar c8/c12/c16 ladder does not: control-volume
activation grows `3.53% -> 6.65% -> 8.07%`, the corresponding L2 correction
remains `11.71% -> 14.74% -> 14.54%`, and finest-two mean drag changes `14.81%`
against a `5%` gate. All cases are positive, source-closed, and force-budget
closed, which isolates the remaining failure to intrusive, resolution-dependent
collision limiting in the physical flow region. The limiter therefore remains
excluded from coupled bird replay.

The D=16 radial follow-up closes its eight shell sums to `8.02e-7`. Limiting
begins within one lattice cell of the sphere, but by `tU/D=5` only `1.11%` of
limiter L1 remains within `0.25D` and `88.58%` lies beyond `1D`. The remaining
defect is therefore not boundary-localized; measured-bird promotion now
requires a bulk collision-operator A/B followed by the unchanged geometric
ladder.

The locked D=16 A/B keeps every physical and numerical boundary fixed while
replacing only the bulk collision. A second-order Hermite-regularized,
convex-positive BGK candidate cuts control-volume activation from `8.070%` to
`0.028%` and relative L1 correction from `6.169%` to `0.053%`; positivity,
source closure, and force closure pass. It remains excluded from measured-bird
replay because relative L2 correction is `1.0968%` against the unchanged `1%`
gate. The candidate is rejected before a refinement ladder, preserving the
measured-data validation boundary.

The next controlled D=16 A/B keeps that rejected second-order candidate as the
control and adds only the six recursively reconstructed third-order moments
supported by D3Q19. The recursive candidate remains positive and source/force
closed while reducing activation to `0.00645%`, relative L1 correction to
`0.01932%`, and relative L2 correction to `0.35279%`. It clears every unchanged
D=16 gate and is eligible for the locked D=8/12/16 geometric ladder. It remains
excluded from measured-bird replay until that ladder establishes non-intrusive
correction and force convergence on every grid.

The RR3 ladder now gives a deliberate negative promotion result. All three
grids remain positive, source/force closed, and non-intrusive, with activation
and both correction norms decreasing under refinement. Drag does not converge:
D=8/12/16 coefficients are `1.32042`, `0.93800`, and `1.04777`; the finest-two
change is `10.476%` against the unchanged `5%` gate and no Richardson fit
exists. RR3 therefore remains excluded from measured-bird replay. Because the
D=8 and D=12 fourth-to-fifth convective-window means still change `11.54%` and
`13.28%`, a cheap duration-sensitivity extension precedes any D=20 study.

That controlled extension is now complete through ten convective times. D=12
clears duration sensitivity: ninth-to-tenth drag changes `4.543%` and
fifth-to-tenth changes `2.177%`. D=8 remains unresolved at `46.848%` and
`29.219%`, respectively, despite retaining positivity, conservation,
force-budget, and non-intrusive correction gates. RR3 therefore remains
excluded from measured-bird replay. The next gate extends only D=8 and uses its
measured shedding period to form period-complete block means and uncertainty;
D=20 remains deferred until the coarse unsteady statistic is defensible.

# Formation Flight Observatory

## Scientific question

The observatory asks a controlled question before introducing uncertain bird
geometry: when two identical prescribed flapping wings share one fluid, how do
relative position `(x, y, z)` and wingbeat phase offset `Δφ` change the
follower's aerodynamic actuator power relative to the same wing flying alone?

The first implementation uses two copies of the accepted Li--Nabawy hovering
wing canonical. It is a multi-body wake-interaction and accounting experiment,
not yet a quantitative claim about a bird flock.

## What is actually coupled

- Both wings occupy one D3Q19 fluid domain. There is no superposition of two
  independently computed wake fields.
- One union geometry kernel writes `0=fluid`, `1=leader`, and `2=follower`.
- Each wing has its own root and phase, but both use the same accepted analytic
  planform and prescribed stroke/pitch law.
- The production TRT collision, interpolated moving boundary, conservative
  cover/uncover impulse, sponge, and global load reduction are unchanged.
- A load-only Metal pass reconstructs force and torque for each owner. It uses
  the same reflected population, link fraction, moving-wall correction, and
  topology impulse as the total solver load.
- Mechanical power uses the required massless actuator torque
  `τ_actuator = -τ_aerodynamic` and `P = τ_actuator · ω` about each wing root.
  The primary energetic comparison is mean positive power; signed and RMS power
  remain in the archive.

## Fail-closed gates

Every promoted result must satisfy all of these checks:

1. no voxel is simultaneously occupied by both wings;
2. leader plus follower force closes to the production total;
3. root-referenced owner torques, shifted to the global origin, close to the
   production total torque;
4. the same owner closure holds for leader-only and follower-only controls;
5. all loads and power values are finite; and
6. the final two cycles meet the frozen power-repeatability limit.

The force and torque closure norm is a cycle-global relative L-infinity norm.
Using one scale for the complete cycle avoids an ill-conditioned relative error
when a valid periodic load crosses zero.

## Run one controlled experiment

```bash
swift run birdflow validate formation-flight \
  --chord-cells 8 \
  --cycles 3 \
  --offset-x 0 --offset-y 0 --offset-z -4 \
  --phase-offset 0.25 \
  --archive ValidationArtifacts/formation-flight-c8-z4-phase025
```

Offsets are in mean chord lengths and phase is in cycles. The default puts the
follower four chords below the leader, in the direction of the hovering-wing
downwash. This is the cleanest first interaction geometry for a zero-freestream
hovering canonical. A forward-flight bird formation will later add a common
freestream and measured complete-bird surfaces.

The canonical frame uses `z` as lift/downwash, with `x` and `y` spanning the
horizontal plane. Because the isolated hovering wing has no preferred forward
direction, the first preregistered discriminator fixes `x/c=0`, samples vertical
separation and phase, and reserves lateral `y/c` offsets for the wider map.
Calling `z/c<0` “behind” means downstream in the hovering wake; it must not be
confused with aft placement in a forward-flight flock.

## Interpreting the report

`followerPositivePowerSavingFraction` is

```text
(isolated follower positive power - coupled follower positive power)
-------------------------------------------------------------------
                 isolated follower positive power
```

Positive values indicate a lower follower power requirement in the coupled
case. Negative values indicate a penalty. The system change compares the two
coupled flyers with the sum of their two matched isolated controls.

The archived watt values use the canonical's declared lattice-to-SI mapping and
are useful within one matched grid. They are not bird muscle or metabolic
power. Cross-grid and publication-facing comparisons use the dimensionless
coupled/isolated fractions above; a measured-bird study must replace the
canonical length, density, and kinematics before reporting physical watts.

The archive also retains 100 phase bins with leader/follower lift, drag, signed
power, and force. A cycle-mean saving is not accepted by itself: the phase trace
must reveal when the wake produces the benefit or penalty.

When an archive directory is supplied, the coupled run also writes
`formation-flight-flow-slice.json`. This is a compact final-phase symmetry-plane
field containing signed vertical velocity, vorticity magnitude, and the exact
owner mask. Extraction happens only on the final step. The load-plus-field
smoke closes force/torque at `7.85e-8`/`2.58e-6`, demonstrating that observation
does not perturb the conservative topology ledger. The underlying ordering fix
is also protected by the translating-body topology canonical: capture off and
capture on must produce bit-identical conservative residuals and event counts.
That focused regression completes in under a second on the Apple M4.

## Current executed evidence

The first three-cycle c8 case at `z/c=-4`, `Δφ=0.25` completed on Apple M4 in
`47.24 s`. It has zero overlap and closes owner force/torque to the production
total at `4.65e-7`/`6.10e-6`; the isolated maximum closure residual is
`5.41e-6`. Its final-two-cycle RMS power difference is `10.26%`, below the
frozen `20%` coarse-screen limit. The follower mean positive power changes from
`0.0119115 W` isolated to `0.0114725 W` coupled, a `3.69%` reduction. The
two-flyer total changes by `-2.14%`.

The preregistered quick map is now complete:

| `z/c` | `Δφ=0` | `Δφ=0.25` | `Δφ=0.5` | `Δφ=0.75` |
|---:|---:|---:|---:|---:|
| `-3` | `4.90%` | **`7.91%`** | `3.41%` | `1.21%` |
| `-4` | `7.06%` | `3.69%` | `1.48%` | `4.96%` |

Every value is the follower mean-positive-power saving against its matched
isolated control. All eight cells pass the frozen gates; worst owner force and
torque closure are `4.72e-7` and `1.12e-5`, and overlap is zero. The maximum
cell at `z/c=-3`, `Δφ=0.25` also reduces two-flyer system power by `4.56%` and
has a `6.12%` final-two-cycle power difference. No coarse cell shows a penalty.
Under the preregistration, the largest-penalty selector therefore equals the
smallest-saving `1.21%` cell.

These numbers selected hypotheses; they did not by themselves establish a
resolved formation benefit.

The frozen c12 five-cycle promotion has now completed for the maximum and
minimum c8 cells. The maximum changes from `7.912%` to `9.680%`; the minimum
changes from `1.209%` to `3.021%`. Both retain zero overlap, improve final-cycle
repeatability to about `2.4%`, and close owner loads below `1e-6` force and
`5.5e-6` torque. The best-minus-minimum phase contrast is `6.703` percentage
points at c8 and `6.659` at c12, only `0.044` points (`0.65%`) apart. Thus the
c8/c12 pair suggested stable phase discrimination, but c16 was required to test
whether that apparent agreement persisted.

The selected c16 extrema have now completed. At `z/c=-3`, maximum-phase
`Δφ=0.25` gives `11.916%` follower saving and `6.536%` two-flyer system
reduction; minimum-phase `Δφ=0.75` gives `3.738%` and `2.599%`. Both five-cycle
runs have zero overlap. Their final-two-cycle power differences are
`2.34%`/`2.83%`; force closure is at most `1.26e-6`, torque closure at most
`4.28e-6`, and isolated closure at most `4.42e-6`.

The c16 best-minus-minimum phase contrast is `8.178` percentage points. It
differs from c12 by `1.519` points, or `18.57%` relative to the fine value. The
maximum saving also changes by `2.236` points (`18.77%`) from c12 to c16, while
the minimum changes by `0.718` points (`19.20%`). Thus the encouraging c8/c12
contrast agreement was not sustained at c16. The extrema executions are
complete, but neither absolute magnitude nor phase contrast is grid-converged.
`ValidationArtifacts/formation-flight-promotion/formation-flight-refinement-summary.json`
SHA-locks every passed report and keeps
`quantitativeFormationClaimAuthorized=false`.

## Phase-resolved refinement atlas

![Phase-aligned c12/c16 power, lift, and drag discrimination with the fine-pair residual](Media/formation-flight-phase-refinement-atlas.png)

The archived 100-bin histories now support a no-new-CFD diagnosis of that fine
pair. `Scripts/analyze-formation-phase-refinement.py` aligns both extrema by
the follower's own wingbeat phase, normalizes each coupled signed-power trace
by its matched isolated mean-positive-power scalar, and compares the c12 and
c16 maximum-minus-minimum waveforms. It emits SHA-locked JSON, long-form CSV,
PNG, and SVG artifacts.

The normalized power-discrimination residual has RMS `0.0336` and maximum
absolute value `0.0953` at follower phase `0.745`. Twenty-one of 100 bins carry
half of its absolute residual, and the two fixed midstroke neighborhoods
`0.20...0.30` and `0.70...0.80` carry `42.3%`. Absolute power residual is
correlated with absolute lift and drag residuals at `0.757` and `0.760`.
Therefore the unresolved change is concentrated in phase and shared by the
load channels; it is not evidence that an acceptance classifier truncated the
mean result.

This is exploratory localization, not a new pass/fail criterion. Schema-1
formation reports do not retain phase-resolved isolated histories, so the
atlas diagnoses coupled waveform refinement rather than reconstructing a
phase-resolved saving curve. Quantitative formation benefit remains
unauthorized.

## Gate and quality-ceiling audit

The acceptance checks classify completed solver output; they do not alter,
clamp, smooth, or stop the flow state. Across eight c8 scout reports and four
c12/c16 promoted reports, overlap is zero and every report passes. The worst
owner or isolated closure residual is `1.118e-5` against `2e-4` (`17.9x`
headroom). Within the promoted fine pair, closure headroom is `36.5x` and the
worst final-cycle periodic difference is `2.827%` against `20%` (`7.07x`
headroom). The smaller `1.65x` periodic headroom belongs only to the cheap c8
hypothesis screen; those values are never promoted as quantitative results.

The former fixed upper bounds of 24 cells/chord, 20 cycles, and 12 chord
offsets were engineering conveniences that could cap a capable machine. They
have been removed. Resolution is now limited only by the Metal device's buffer
and recommended working-set bounds; duration and domain use checked arithmetic
and exact timestep/grid representability. Minimum resolution, non-overlap,
finite-state, conservation, and representability checks remain because
removing them would reduce scientific quality rather than increase it.

## Preregistered c20 sequential discriminator

`ValidationInputs/formation-flight-c20-sequential-discriminator-v1.json`
locks the next decision before c20 output exists. Stage 1 runs only the
maximum selector at `z/c=-3`, `Δφ=0.25`. Stage 2 is allowed only when the
absolute c16-to-c20 maximum-saving change, divided by the c20 magnitude, is no
greater than `5%`. A stage-1 failure stops the ladder and preserves the
negative result instead of spending a second fine run. If stage 1 passes, the
minimum selector at `Δφ=0.75` runs and the c16/c20 phase-contrast change must
also be at most `5%`.

Both stages retain the unchanged closure, non-overlap, finite-state, and
repeatability gates. They also capture 20 final-cycle center-plane fields in
the follower-local `0.20...0.30` and `0.70...0.80` bands identified by the
phase atlas. The capture kernel writes only vertical velocity, full
three-dimensional central-difference vorticity magnitude, and owner mask into
a compact GPU-resident history. It does not modify populations or loads. A c8
capture-on/off smoke produced identical reports after excluding runtime, exact
owner masks and vertical velocity, and a maximum old-CPU/new-GPU vorticity
difference of `1e-9`.

The generic CLI accepts leader-frame capture phases and the archive index
records both leader and follower-local phase:

```bash
.build/release/birdflow validate formation-flight \
  --chord-cells 20 --cycles 5 \
  --offset-z -3 --phase-offset 0.25 \
  --field-phases 0.005,0.015,0.025,0.035,0.045,0.455,0.465,0.475,0.485,0.495,0.505,0.515,0.525,0.535,0.545,0.955,0.965,0.975,0.985,0.995 \
  --archive ValidationArtifacts/formation-flight-promotion/c20-best-z3-phase025
```

Stage 1 completed on Apple M4 in `6768.86 s`. The c20 maximum-selector saving
is `13.341%`, compared with `11.916%` at c16. Their `1.425`-point difference is
`10.679%` relative to the c20 value, more than twice the frozen `5%`
continuation limit. The preregistered decision is therefore
`stage1_failed_stop`: the c20 minimum selector was not run, and quantitative
formation benefit remains unauthorized.

This is a convergence failure, not a solver-validity failure. The c20 run has
zero overlap, `7.17e-7` force closure, `4.42e-6` torque closure, `3.75e-6`
isolated closure, and `2.366%` final-cycle power difference; every unchanged
gate passes. All 21 flow slices are finite and indexed, including every
requested follower-local phase. The SHA-locked decision is
`ValidationArtifacts/formation-flight-promotion/formation-flight-c20-discriminator-summary.json`.

![Preregistered c20 maximum-selector refinement, phase power residual, and GPU-resident midstroke field envelope](Media/formation-flight-c20-stage1-atlas.png)

![Four actual c20 wake fields with common signed-velocity and vorticity scales, owner silhouettes, and the preregistered stop decision](Media/formation-flight-c20-cfd-phase-plate.png)

The companion CFD phase plate enlarges four actual archived states at follower
phases `0.205`, `0.255`, `0.705`, and `0.755`. All panels use one signed
vertical-velocity scale and one set of vorticity contour levels. The phase rail
marks every requested midstroke capture, and the renderer performs no temporal
interpolation. This is a visualization of the stopped c20 case, not additional
evidence for a quantitative formation-saving claim.

The maximum saving has increased monotonically from `7.912%` at c8 to
`9.680%`, `11.916%`, and `13.341%` at c12/c16/c20. That trend rules out the
possibility that the earlier c12/c16 discrepancy was a one-grid anomaly. It
also makes an immediate brute-force c20 minimum or full c24 ladder poor ROI:
the maximum magnitude alone has not entered the accepted refinement regime.

The phase-aligned c16/c20 maximum-selector power residual has RMS `0.0313` and
maximum absolute value `0.1122` at follower phase `0.055`. Only `23.15%` of
its absolute magnitude lies in the two earlier midstroke bands, and absolute
power residual correlates with drag residual at `0.683` but not lift residual
(`-0.065`). Thus the c20 result refines the diagnosis: the largest remaining
maximum-selector change is early in the cycle and drag-aligned, not confined
to the phase-contrast midstroke neighborhoods.

## Early-cycle coupled-field discriminator

`ValidationInputs/formation-flight-early-cycle-field-replay-v1.json` locks ten
follower-local phases from `0.005` through `0.095`, the c16/c20 source-report
SHAs, a common-grid comparison, and the mechanism thresholds before either
replay runs. The new `--field-replay-reference` mode advances only the coupled
two-owner case. It fails closed unless the requested configuration, grid,
cycle length, complete 100-bin coupled power/lift/drag/force history, closure,
periodicity, overlap, and finiteness reproduce the passed complete report. The
maximum permitted relative reference-history difference is `1e-6`.

```bash
./Scripts/run-formation-early-cycle-replay.sh
```

The c8 release smoke reproduced its source history exactly and reduced runtime
from `132.83 s` to `54.16 s`. Promoted c16 and c20 replays also reproduce their
source histories exactly. They complete in `1105.21 s` and `2755.89 s`, versus
`2370.26 s` and `6768.86 s` for the original complete runs. Combined runtime
falls by `87.97 min` (`2.37x`) without reducing five-cycle stationarity or any
requested field phase.

![Early-cycle c16/c20 signed vertical velocity, spatial residual, and preregistered mechanism classification](Media/formation-flight-early-cycle-field-discriminator.png)

The analysis bilinearly maps c16 scalars onto c20 cell-center coordinates,
uses nearest-neighbor ownership, and excludes cells solid on either grid plus
one c20-cell halo. Vertical-velocity normalized RMS difference stays within
`7.26...7.62%` with spatial correlation `0.9972...0.9974`; vorticity difference
is larger at `19.15...23.64%` with correlation `0.9775...0.9882`. The fraction
of combined normalized residual energy within `0.5` chord of either wing falls
from a maximum `64.69%` at phase `0.015` to `25.28%` at `0.095`. Its aggregate
is `45.04%`, so the preregistered classification is `mixed`.

The maximum absolute near-boundary energy selects follower phase `0.035`, with
an energy-weighted center at `(x/c,z/c)=(1.822,1.023)`. The maximum outside-band
wake energy selects phase `0.095`, centered at `(2.322,-1.135)`. The independent
SciPy reconstruction verifies every SHA, replay gate, phase metric, aggregate,
classification, and probe coordinate in `99/99` checks. The next high-ROI
experiment is therefore one local realized-population/interpolation probe at
the phase-`0.035` boundary region and one wake-core transport probe at phase
`0.095`; neither the stopped c20 minimum nor a c24 ladder is authorized by this
diagnostic. Quantitative formation benefit remains unauthorized.

## Causal momentum-exchange and wake-transport discriminators

The mixed spatial result selected two preregistered phases rather than opening
a c24 ladder: follower phase `0.035` for the boundary-local maximum and `0.095`
for the outside-band wake maximum. A read-only Metal pass now decomposes each
owner load at those phases into reflected-population, interpolation-auxiliary,
moving-wall, conservative cover, and conservative uncover terms. Five separate
GPU reductions use the exact production pre-step populations and geometry, and
their sum must close force, root torque, and actuator power to the unchanged
owner history.

```bash
./Scripts/run-formation-mechanism-probe.sh
```

The c8 smoke reproduces its coupled history exactly and closes the five terms
at `1.55e-6` force, `6.13e-7` torque, and `4.01e-7` power. The promoted c16 and
c20 replays also have zero reference-history difference. Their maximum
component closure residuals are respectively `2.32e-7`/`1.34e-7`/`6.14e-8`
and `1.88e-7`/`1.20e-7`/`8.15e-8` for force/torque/power. Runtime is `864.70 s`
and `2210.35 s`; no isolated control or global refinement run is repeated.

![Exact c16/c20 momentum-exchange work decomposition beside the selected signed-w residual fields](Media/formation-flight-causal-mechanism-atlas.png)

Every component power is divided by that grid's matched isolated-follower
mean-positive-power scalar before comparison. At phase `0.035`, moving-wall
work carries `50.43%` of the L1 c20-minus-c16 component change, below the
preregistered `60%` single-component threshold. Interpolation carries a
counteracting `34.69%`; no boundary subterm dominates. At phase `0.095`, the
reflected and moving-wall changes also oppose one another, while `74.72%` of
the locked field residual lies outside the half-chord boundary band. The frozen
classification is therefore `wakeTransportDominated`, verified independently
in `106/106` checks.

The decomposition is strongly cancelling: per-grid component condition
numbers span about `42...64`, and the c20-minus-c16 condition numbers are
`16.67`/`14.93` at the boundary/wake phases. The classification is a numerical
localization result, not evidence that a large individual work term is itself
incorrect.

The next discriminator uses no new CFD. It locks follower phases
`0.055...0.095`, a wake region centered at `(x/c,z/c)=(2.322,-1.135)`, and a
common-grid search that shifts mapped c16 signed vertical velocity and
vorticity by at most `0.5` chord in `0.05`-chord increments. Across `2,205`
candidate alignments, the optimum removes only `0.852%` of combined residual
energy. Four of five phases select zero displacement; phase `0.055` selects
only `-0.05` chord in `x`, and the mean displacement is
`(-0.01,0.00)` chord.

![Preregistered wake displacement search showing unshifted and optimally aligned c16/c20 residuals](Media/formation-flight-wake-transport-atlas.png)

The frozen result is `amplitudeDiffusionDominated`, independently reproduced
in `41/41` checks. Thus the late residual is not primarily a convective
position or phase-lag error. The next justified solver experiment is a
localized collision/advection-dissipation discriminator in the locked wake
region. A global c24 ladder, c20 minimum selector, quantitative power claim,
and bird-formation claim remain unauthorized.

## Collision/dissipation A/B and streamwise source localization

`ValidationInputs/formation-flight-collision-dissipation-discriminator-v1.json`
locks one c16 RR3 candidate before execution and permits a c20 RR3 allocation
only if it reduces both the wake residual by at least `25%` and the
dimensionless force-history residual by at least `10%`. The validation-only
path changes only the bulk collision selector. Production formation flight
remains TRT. A fused diagnostic records the global minimum population and
limiter activation count on every step through the existing load reduction,
avoiding a second D3Q19 population scan.

```bash
./Scripts/run-formation-collision-dissipation.sh
```

The c8 smoke passes in `22.23 s` with minimum population `0.01508` and zero
limiter activation. The five-cycle c16 candidate completes on Apple M4 in
`1075.62 s`; its minimum population is `0.01560`, correction activation is
zero, force/torque closure is `1.10e-6`/`3.70e-6`, overlap is zero, and every
unchanged gate passes. Positivity is therefore not limiting the comparison.

![Preregistered formation collision/dissipation screen](Media/formation-flight-collision-dissipation-atlas.png)

The scientific screen is negative. Against the locked c20 TRT discriminator,
RR3 increases the five-phase common-grid wake residual by `28.98%` and the
four-signal dimensionless coefficient-history residual by `84.82%`. The
classification is `collisionChangeAdverseOrUnsupported`; the independent
artifact audit passes `51/51` checks, verifies the exact operator and every
population/closure gate, and confirms no c20 RR3 allocation exists. This does
not make c20 TRT truth. It rejects RR3 as a convergence repair under the
preregistered cross-grid discriminator and preserves the production default.
A post-change c8 TRT replay completes in `47.05 s` and reproduces the locked
100-bin history with exactly zero relative difference, directly confirming
that the new diagnostic branch is observational when disabled.

The next mechanism selector is archive-only.
`ValidationInputs/formation-flight-streamwise-attenuation-localizer-v1.json`
freezes the same five phases and wake ROI, then partitions it into upstream,
middle, and downstream one-chord bands. Residual energy is normalized by the
whole-ROI c16/c20 signal scales and divided by valid cell support before bands
are compared.

![Preregistered streamwise source-versus-attenuation localizer](Media/formation-flight-streamwise-attenuation-atlas.png)

The downstream/upstream TRT residual-density ratio is `0.818`. It is below the
frozen `1.15` source-dominated threshold, rather than above the `1.50`
transport-attenuation threshold. The `94/94` independent audit reproduces all
slice hashes, band supports, per-phase energies, aggregate densities, ratio,
and classification. The discrepancy is therefore already injected at the
upstream edge of the wake ROI and diminishes downstream; it is not growing as
the wake travels.

This center-plane result is a selector, not a three-dimensional energy budget.
It directs the next experiment to phase-resolved near-wing population
generation: D3Q19 direction, reconstructed incoming population, reflected and
interpolation-auxiliary terms, moving-wall correction, link fraction, owner,
and normal/tangential injected momentum. It does not authorize a quantitative
formation benefit, a production collision change, the stopped c20 minimum, or
a blind c24 ladder.

## Boundary-source census and link-sampling microscope

The selected near-wing experiment is complete under
`ValidationInputs/formation-flight-boundary-source-census-v1.json`. A read-only
Metal pass captures the exact production boundary reconstruction by owner and
D3Q19 direction at follower phases `0.035` and `0.095`. The source identity
includes both momentum-exchange populations—raw reflected plus reconstructed
incoming—and splits the incoming population into reflected, interpolation
auxiliary, and moving-wall contributions. Link-fraction moments, wall
projection, and near/far/halfway branch counts are retained as sufficient
statistics.

```bash
./Scripts/run-formation-boundary-source-census.sh
```

The first c8 instrumentation-only smoke is retained as a negative control. It
reproduced the production history exactly and closed reconstruction at
`1.24e-7`, but correctly failed because an empty phase-zero report slot was
copied as two zero-support samples. The preregistration records the narrow host
filter amendment before c16 or c20 ran. Corrected c8, c16, and c20 reports
contain exactly four source samples and pass every unchanged replay gate. c16
and c20 run in `890.86 s` and `2293.58 s`, reproduce reference histories with
zero relative difference, and close population reconstruction at
`9.28e-8`/`9.09e-8`.

![Owner-, phase-, and D3Q19-resolved boundary population source census](Media/formation-flight-boundary-source-atlas.png)

For each direction, the grid-normalized source is written as `s=a*m`, where
`a=linkCount/chordCells²` and `m` is conditional momentum-exchange population
per link. The exact symmetric product identity assigns the c16-to-c20 change
without privileging either grid. At the preregistered primary leader sample,
the areal directional link measure supplies `98.25%` of weighted-L1 change and
conditional population amplitude `1.75%`. The other three owner/phase samples
assign `98.08%...98.85%` to link sampling. Direction identities close below
`2.14e-17`; the independent audit passes `319/319` checks.

This is a strong mechanism selector but not evidence of a gross geometry
failure. D3Q19 direction-distribution TV is only `0.55%...0.99%`, and total
areal link density changes by `-1.37%...-2.35%`. These small geometric
realization differences dominate because conditional population changes are
smaller.

The archive-only follow-up preregisters a second exact factorization,
`a=D*p`, under
`ValidationInputs/formation-flight-link-sampling-subdecomposition-v1.json`.
It separates total grid-normalized link density `D` from D3Q19 direction
probability `p` without new CFD.

```bash
./Scripts/run-formation-link-sampling-subdecomposition.sh
```

![Exact density-versus-direction subdecomposition of the dominant link-sampling term](Media/formation-flight-link-sampling-subdecomposition.png)

The primary result is mixed: areal link density contributes `47.55%` and
direction redistribution `52.45%`, both below the frozen `60%` threshold. All
four owner/phase samples remain mixed; the largest directionwise identity
residual is `3.78e-17`, and the independent audit passes `521/521`. The next
admissible experiment is one geometry-only c18 bridge at the primary phase,
retaining both density and direction pathways. No production boundary edit,
bulk collision change, c20 minimum, global c24 ladder, quantitative formation
benefit, or biological claim is authorized.

## Geometry-only c18 bridge

The frozen follow-up is complete under
`ValidationInputs/formation-flight-geometry-c18-bridge-v1.json`. A dedicated
`birdflow-formation-geometry` executable reuses the production prescribed-wing
preparation and union voxelization, reads back only the ownership mask, and
counts owner-resolved D3Q19 fluid-solid links on the host. It does not
initialize populations or execute collision, streaming, moving-boundary force,
or a fluid timestep.

```bash
./Scripts/run-formation-geometry-c18-bridge.sh
```

![Preregistered no-fluid c18 bridge retaining density and direction pathways](Media/formation-flight-geometry-c18-bridge.png)

Before c18 is classified, the harness reproduces all primary-phase archived
c16/c20 counts exactly for leader and follower. Total counts are
`8,634/8,854` at c16 and `13,306/13,626` at c20. The three voxelizations take
`0.072/0.090/0.118 s` on Apple M4 and have positive support, finite output, and
zero overlap.

For the frozen primary leader, `D=N/r²` is `33.7266`, `33.1111`, and `33.2650`
at c16/c18/c20. Because c18 lies outside the endpoint interval, the
preregistered verdict is `latticePhaseAliasingSuspected`. The normalized
midpoint curvatures are `0.833` for density, `0.503` for direction
distribution TV, and `0.768` for the direction-length-weighted areal profile.
The independent implementation passes `105/105` checks.

The scientific consequence is allocation control, not a solver correction:
one geometry-only subcell-offset ensemble at c16/c18/c20 and the same phase is
now selected to quantify lattice-phase uncertainty. A c18 fluid census, global
refinement ladder, boundary change, quantitative formation advantage, and
biological interpretation remain unauthorized.

## Subcell-offset uncertainty ensemble

The selected follow-up is complete under
`ValidationInputs/formation-flight-geometry-subcell-ensemble-v1.json`. It
translates both flyers together over the full `4 × 4 × 4` tensor
`{0, 0.25, 0.5, 0.75}³` at c16, c18, and c20 while holding separation,
kinematics, thickness, and grid dimensions fixed. All 192 cases reuse the
production Metal pose preparation and union voxelizer; no population, fluid,
force, or sponge step executes.

```bash
./Scripts/run-formation-geometry-subcell-ensemble.sh
```

![Complete 192-pose subcell-offset uncertainty ensemble](Media/formation-flight-geometry-subcell-ensemble.png)

Every zero-offset case reproduces the earlier bridge exactly for both owners.
The complete ensemble takes `3.71 s` of recorded pose/count work on Apple M4,
has positive link support and zero overlap, and passes independent
reconstruction `334/334`. Mean leader densities are `33.4672`, `33.3124`, and
`33.2221` at c16/c18/c20. c18 now lies between the endpoint means; normalized
mean density, direction-TV, and joint-profile curvatures are
`0.1315/0.0926/0.1315`, below the frozen `0.5` threshold. The preregistered
classification is `aliasingAveragedOut`.

This resolves the isolated c18 excursion as lattice-phase sensitivity and
provides explicit uncertainty distributions; it does not make a single-grid
force history converged. The next scientific allocation is a phase-locked
c16/c18/c20 boundary-source census at matched median-density offsets, before a
full fluid ladder or any production boundary change.

## Common median-phase population source

That allocation is complete under
`ValidationInputs/formation-flight-subcell-source-census-v1.json`. A
deterministic archive-only selector minimizes the sum of squared,
sample-SD-normalized distances from the c16/c18/c20 leader-density medians.
It selects the common global translation `[0.25, 0.25, 0.75]` cells with score
`0.82576`; the legacy zero offset scores `1.64086`. Selection occurred before
any translated CFD.

The new diagnostic path shifts both flyer roots together, preserving their
separation and kinematics. It runs only the coupled production-TRT case for
five cycles and captures one exact owner- and D3Q19-resolved pre-fluid boundary
source at leader phase `0.785`. Production entry points retain a zero-offset
default. The earlier implementation is exactly recoverable from the parent
commit and hash recorded in the preregistration.

```bash
./Scripts/run-formation-subcell-source-census.sh
```

![Common median-phase geometry and population-weighted boundary-source convergence](Media/formation-flight-subcell-source-convergence.png)

The c8 instrumentation smoke passes. c16/c18/c20 then complete locally on
Apple M4 in `1016.72/1367.68/2544.79 s`. All three reports are finite and
overlap-free, contain exactly one leader and one follower sample, and pass
unchanged owner closure and periodicity. Worst reconstruction, force closure,
torque closure, and periodic difference are `8.06e-8`, `7.47e-7`, `3.19e-6`,
and `2.395%`.

Refinement is evaluated at the correct c18 coordinate in `h=1/chordCells`,
not an arithmetic cell-count midpoint. The selected scalar geometry density
has normalized curvature `0.14998`, but the leader direction-resolved areal
link profile is `0.78497`, conditional population is `0.58733`, and their
exact production product is `0.88415`. The frozen result is
`mixedPopulationWeightedSource`: it is below the `1.0` persistent-bias boundary
but above the `0.5` smooth boundary. Source weighted-L1 norms decrease
monotonically (`2.95652/2.93487/2.90665`), yet the directional c18 profile is
not sufficiently h-linear. Component curvatures are `0.92415` reflected,
`0.99675` interpolation auxiliary, and `0.56016` moving wall; none provides a
clean single-mechanism promotion.

The first plotting pass reconstructed the primary source from its decomposed
terms rather than using the preregistered exact production incoming sum. The
independent audit rejected the approximately `1.2e-7` headline mismatch
`62/64`. That failed audit is preserved byte-for-byte. A transparent post-run
amendment changes only the analysis expression, not CFD, thresholds, decision
rule, or classification; the corrected audit passes `66/66`.

This representative phase does not establish offset-ensemble source
robustness or force convergence. The preregistered next action is limited to
the two next-best median candidates, `[0.5,0.75,0.5]` and `[0.25,0,0.5]`, to
decide whether the mixed residual is phase-local or systematic. A full
formation-power ladder, production correction, quantitative benefit, and
biological claim remain unauthorized.

## First alternate source phase

The first authorized phase-robustness discriminator is complete under
`ValidationInputs/formation-flight-subcell-source-offset2-v1.json`. It freezes
the second-ranked deterministic median candidate `[0.5,0.75,0.5]` (score
`0.8437568`) before translated CFD. The runner verifies hashes for its parent
geometry ensemble, accepted source summary/audit, production Metal and Swift
implementation, CLI, test, runner, analyzer, and independent auditor before
allocating fluid state.

```bash
PATH=".build/formation-analysis-venv/bin:$PATH" \
  ./Scripts/run-formation-subcell-source-offset2.sh
```

![Second-ranked lattice-phase source convergence](Media/formation-flight-subcell-source-offset2-convergence.png)

The unchanged five-cycle production-TRT c16/c18/c20 cases complete on Apple M4
in `397.70/772.67/1114.85 s`, or `2285.22 s` recorded solver time. All cases
are finite, overlap-free, have exactly two owner samples and complete D3Q19
support, and pass force/torque closure and periodicity. Maximum source
reconstruction residual is `8.32e-8`; maximum force/torque closure is
`6.25e-7/2.38e-6`; maximum final-cycle periodic power difference is `2.293%`.

At the alternate phase, direction-resolved areal links, conditional
population, and exact production population-weighted source have normalized
h-linear curvatures `0.61730/0.60159/0.57541`. Reflected, interpolation, and
moving-wall component curvatures are `0.54555/0.60586/1.05465`. The exact
source improves by `34.92%` relative to the representative phase but remains
above the unchanged `0.5` smooth boundary, so the classification remains
`mixedPopulationWeightedSource`. The arithmetic two-offset mean source
curvature is `0.58368`, also mixed. Source norms are
`2.93984/2.95435/2.91729`, so monotonicity is not claimed.

The preregistration records the alternate scalar geometry-density curvature
`1.17661` before CFD as context, not a hidden acceptance failure. Because the
candidate was selected by distance to each grid's ensemble median rather than
endpoint interpolation, a nonsmooth full source cannot by itself be assigned
to the population operator. Direction, conditional-population, full-source,
and component evidence are therefore retained separately. The independent
implementation reconstructs provenance, D3Q19 populations, branch closure,
all primary/component/parent/two-offset curvatures, classification, figures,
and claim boundary with `109/109` checks passing.

Two deterministic phases are now nonsmooth. Only the final authorized median
candidate `[0.25,0,0.5]` may complete the minimal phase-robustness set. A full
formation-power ladder, production correction, quantitative formation benefit,
and biological claim remain unauthorized.

## Three-offset source robustness decision

The final authorized offset and the aggregate decision are complete under
`ValidationInputs/formation-flight-subcell-source-offset3-v1.json`. Before the
third CFD triplet, the contract freezes the final rank-3 candidate
`[0.25,0,0.5]`, exact implementation and analysis hashes, NumPy `2.5.1`,
Matplotlib `3.11.1`, and a two-part promotion rule:

- direction-resolved three-offset mean source curvature must be at most `0.5`;
- maximum pairwise direction-weighted source-profile spread must be at most
  `5%`.

The `5%` spread bound is fixed before the third phase and is more than four
times the already known two-phase maximum `1.1618%`. The individual final
offset's scalar geometry curvature is recorded as an ill-conditioned `60.38`
because its c16 and c20 endpoint densities are almost equal. It is explicitly
not used as the primary decision metric.

```bash
BIRDFLOW_ANALYSIS_PYTHON="$PWD/.build/formation-analysis-venv/bin/python" \
  ./Scripts/run-formation-subcell-source-offset3.sh
```

![Three-offset source robustness decision](Media/formation-flight-subcell-source-three-offset-convergence.png)

The new five-cycle production-TRT c16/c18/c20 cases complete in
`497.74/891.05/1630.52 s` (`3019.32 s` total). All nine source cases across the
three offsets are finite, overlap-free, owner-complete, D3Q19-complete, and
inside unchanged reconstruction, force, torque, and periodicity gates. For the
new triplet, worst source reconstruction is `7.57e-8`; worst force/torque
closure is `8.45e-7/4.03e-6`; worst final-cycle periodic difference is
`2.327%`.

Individual exact-source curvatures are `0.88415/0.57541/0.68861`. The
three-offset mean areal-link, conditional-population, and exact-source
curvatures are `0.58081/0.56446/0.59595`. Mean reflected, interpolation, and
moving-wall component curvatures are `0.62088/0.67654/0.86144`. Thus sampling,
conditional population, and all three source components remain mixed; no
single population term can be rescaled or promoted.

Maximum pairwise exact-source spread is only `1.3844%` across all grids
(`1.3844/1.1784/1.3159%` at c16/c18/c20), clearing the frozen `5%` limit.
Conditional-population spread is only `0.0724%`, areal-link spread is `1.292%`,
and the largest component spread is `2.199%`. Lattice-phase variability is
therefore small, but averaging it does not restore the required h-linear
source refinement. The frozen classification is
`mixedPopulationWeightedSourceMean`; the quantitative power gate fails, while
the evidence-integrity result passes. An independent implementation
reconstructs all nine inputs, branches, populations, individual/mean/component
curvatures, phase spreads, geometry conditioning, classification, figures, and
claim boundary with `190/190` checks passing.

The wider position-phase power map is not authorized. The next allocation is
archive-only: compute the c18 direction/component residual covariance across
the three offsets, then select at most one focused production phase trace. No
additional offset, global grid, power scout, production correction,
quantitative benefit, or biological claim is authorized.

## Archive-only c18 residual selector

The authorized residual-covariance selector is complete under
`ValidationInputs/formation-flight-source-residual-covariance-v1.json`. It
locks all nine census hashes and the analysis before inspecting the detailed
direction/component ranking. For each offset, component, and D3Q19 direction,
it reconstructs the c18 residual against the h-linear c16/c20 expectation. Its
primary systematic-alignment score is the direction weight times the product
of the phase-mean component and exact-source residuals; centered phase
covariance and per-offset sign agreement remain separate evidence.

A single trace requires at least `10%` of the positive systematic-alignment
ledger, agreement in at least two of three offsets, and a non-rest direction.
The `10%` threshold is more than `5.4x` a uniform allocation over three
components and 18 moving directions and is frozen before ranking.

```bash
BIRDFLOW_ANALYSIS_PYTHON="$PWD/.build/formation-analysis-venv/bin/python" \
  ./Scripts/run-formation-source-residual-covariance.sh
```

![Archive-only source residual selector](Media/formation-flight-source-residual-covariance.png)

The result is `concentratedStableTraceSelected`. Leader reflected momentum
exchange at D3Q19 `q=5`, direction `[0,0,+1]`, supplies `21.7875%` of the
positive systematic-alignment ledger and aligns with the exact-source residual
in all `3/3` offsets. Its systematic alignment is `7.7377e-6`; centered phase
covariance is `3.7829e-6`. The opposite reflected direction `q=6`,
`[0,0,-1]`, ranks second at `16.5199%`, so the dominant evidence is a vertical
reflected-population pair. The frozen one-direction rule nevertheless selects
only `q=5`.

Local selected-direction alignment is strongest at the representative offset
`[0.25,0.25,0.75]`: `3.0268e-5`, versus `3.1778e-6` and `1.1160e-6` at the
other offsets. Residual component closure is `1.37e-8`; every parent, hash,
D3Q19, finiteness, and moving-direction gate passes. A separate implementation
reconstructs all inputs, residuals, 57 component/direction candidates,
systematic alignment, centered covariance, ranking, offset choice,
classification, and claim boundary with `57/57` checks passing. Runtime fluid
steps are exactly zero.

Exactly one new diagnostic is authorized: a c18 production-TRT final-cycle
temporal trace for the leader's reflected momentum-exchange term, `q=5`, at
subcell offset `[0.25,0.25,0.75]`. Collision, boundary, force, geometry, and
kinematics must remain unchanged. The power map, source convergence,
production correction, quantitative benefit, and biological claims remain
blocked.

## Focused q5 final-cycle temporal trace

The authorized run is complete under
`ValidationInputs/formation-flight-focused-source-trace-v1.json`. The capture
uses the existing read-only source-census kernel once per final-cycle step for
only leader `q=5`; it writes one compact record per step and allocates no flow
slices. Capture occurs after current-step geometry and owner-load reads and
before collision/streaming, exactly matching the locked phase census. The
production Metal kernel and `GPUData.swift` hashes are unchanged from baseline.

```bash
BIRDFLOW_ANALYSIS_PYTHON="$PWD/.build/formation-analysis-venv/bin/python" \
  ./Scripts/run-formation-focused-source-trace.sh
```

![Focused leader q5 source trace](Media/formation-flight-focused-source-trace.png)

The Apple M4 run records the complete `4,820/4,820` step fifth cycle in
`1323.54 s`. Every record preserves direction `[0,0,+1]`, reconstructed
incoming population closes to reflected, interpolation, and wall terms within
`2.71e-7`, and branch counts close exactly. The locked c18 coupled leader and
follower summaries reproduce with zero relative difference. At the locked
leader phase `0.785062`, all 12 source totals and all four branch counts also
reproduce exactly. Force/torque closure is `6.83e-7/3.19e-6`; periodic power
difference is unchanged at `2.213%`. The independent implementation passes
`59/59` checks.

The signal is not temporally narrow. The shortest circular 64-bin window
containing `50%` of centered reflected-exchange energy spans `31/64 = 0.4844`
cycles, from phase `0.578125` through the periodic seam to `0.0625`, failing
the preregistered `0.35` localization rule. Absolute reflected exchange peaks
at leader phase `0.748963`; per-link exchange and topology turnover both peak
at `0.250830`.

Branch topology is nevertheless associated with the per-link signal:
near/far occupancy correlations are `-0.4284/+0.4284`, clearing the frozen
`0.35` moderate-association threshold. Mean near/far occupancy is
`50.86%/49.14%`; no halfway fallback occurs. Total reflected exchange tracks
link count at `r=0.9988`, so support dominates the gross time history. These
are associations, not branch-specific population attribution or causation.

The frozen classification is `cycleDistributedBranchAssociated`. It rejects a
narrow-window endpoint rerun. The next admissible experiment is sparse,
matched-phase c16/c20 tracing stratified by near and far occupancy. This c18
trace does not itself localize the cross-grid residual in time, establish
source convergence, authorize the formation-power map, justify a boundary
change, or support a quantitative biological claim.

## Native Metal presentation integrity

The complete birds in the README animation are two independently phased copies
of the locked Deetjen OB F03 measured-derived surface sequence. Each contains
`2,157` vertices and `3,968` triangles. The replay advances source frames
`27...121`, then uses the existing velocity-matched `14 ms` cubic-Hermite
segment to close the forward-only presentation loop. The intentional
leader/follower `Δφ=0.25` is applied to this normalized dove presentation phase.

Evidence boundaries remain documented and machine-audited without occupying
the cinematic frame. The body is a processed measured surface; the left wing
is measured-outline-derived and gap-filled; the right wing is a documented
bilateral-reflection assumption; and the tail is a fixed parameterization
derived from the processed surface. A first native-Metal pass revealed that
scaling the reconstructed tail with full wing span made its fan dominate the
scene. V9 retains the promoted part-aware presentation scales: `[16,16,7]` for
body/wings and `[14,6,6]` for the tail. The audit requires tail lateral scale to
stay below half the body/wing value.

Capture writes a machine-readable dove sidecar and refuses the GIF unless the
dataset identity, Dryad/eLife DOI, CC0 license, exact topology, component
evidence, two-flyer phase offset, loop window, closure duration, zero endpoint
residual, and presentation-only claim boundary all match. It also requires all
`48/48` unique phases to show the archived c20 field at full opacity. V9 uses
cyclic linear interpolation between adjacent members of the 21-state archive
to remove visual stepping. This is a presentation transform only: no
interpolated field enters force, power, convergence, or any solver claim.
The field plane additionally uses a mask-aware radius-4, sigma-2 Gaussian
display filter. Hidden canonical solid cells are filled from surrounding
archived fluid samples so their unmatched silhouette does not form a dark
diagonal beam behind the dove shell. Opacity combines vorticity and absolute
vertical velocity, eliminating the remaining low-vorticity seam through the
blue jet. These pixels are explicitly presentation-only; the source arrays and
owner mask remain unchanged.

The living wake bridge adds three vorticity ridges reconstructed at each frame
from the displayed c20 vorticity and vertical-velocity arrays. Ridge color runs
from cyan to violet with downstream wake age; its luminance follows the
normalized reflected-population exchange from every sample of the passed c18
leader `q5 [0,0,+1]` focused trace. The follower-plane ring is explicitly a
presentation-phase locator, not a measured vortex boundary. The V9 camera
follows a spherical figure-eight: yaw varies as `0.34 sin(2πφ)`, pitch as
`0.10 sin(4πφ)`, and distance as `0.10 cos(2πφ)`. This produces two viewing
lobes and several distinct upper/lower side-quarter angles while returning to
identical parameters at the loop endpoint. The V9 manifest
locks the renderer, dove binaries, all 21 CFD fields, the complete 4,820-step
q5 trace and its independent audit, the no-overlay figure-eight camera
contract, spatial-display contract, GIF hash, frame count, and loop seam. Its
visual audit passes `57/57`.

The two doves and their wingtip guides do not enter voxelization, fluid
stepping, loads, torque, or actuator power. Those remain the archived
prescribed-wing canonical. Geometry curvature `0.150` is smooth, exact
population-weighted source curvature `0.884` is mixed, and the original
`10.68% > 5%` force-convergence stop remains governing even though the HUD is
gone. The exact V8 unsmoothed-field binary, V7 restrained-camera binary, V6 HUD
binary, V4 synchronized procedural birds, and V3 invalid rotated partner-wing
presentation are retained under `Docs/Media/Progress`.

## Wider position-phase map

The completed quick discriminator covers two vertical separations and four
phases. A wider matrix is already declared in the preregistration but has not
been executed:

- vertical separation: `z/c = -2, -3, -4, -5`;
- lateral offset: `y/c = 0, 0.5, 1.0`;
- phase offset: `Δφ = 0, 0.25, 0.5, 0.75`;
- coarse discriminator: 8 cells/chord, three cycles;
- promotion: only the best, neutral, and worst cells advance to 12 and 16
  cells/chord with five cycles.

This staged design keeps the expensive refinement ladder focused on hypotheses
selected by a fixed coarse screen rather than by attractive imagery.

## Scientific boundary

The observatory currently establishes multi-flyer coupling and controlled power
comparisons for prescribed hovering wings. Claims about formation flight in
birds require measured complete-bird geometry and kinematics, a forward-flight
condition, refinement of the selected map cells, body and hinge inertia, and
uncertainty intervals. Those requirements remain unchanged in
`Docs/VALIDATION.md`.

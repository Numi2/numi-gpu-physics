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
to the phase-contrast midstroke neighborhoods. A targeted coupled-only
c16/c20 field replay around follower phase `0.00...0.10` has better ROI than
either the stopped c20 minimum or a brute-force c24 ladder.

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

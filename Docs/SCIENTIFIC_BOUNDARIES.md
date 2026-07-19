# Scientific boundaries

This is the decision ledger for what BirdFlowMetal has established, what can be
answered by another controlled computation, and what cannot be solved without
new measured data. A numerical run passing is not automatically a physical
validation. Every promotion must cross its own preregistered numerical,
refinement, and comparison gates.

## Boundary classes

- **Closed engineering boundary** — the implementation has a passing canonical
  and is safe to use inside the stated claim.
- **Active code-solvable boundary** — the next discriminator is known and can
  be run with repository code or archived state.
- **Compute-blocked boundary** — the method exists, but a cheaper prerequisite
  failed or has not yet authorized the expensive allocation.
- **Measured-data boundary** — the solver is ready, but the required property
  was never measured for the same specimen. Code must not synthesize it from a
  species average.
- **Model-scope boundary** — the governing model or validation canonical is not
  implemented; output depending on it is out of scope.

## Current ledger

| Scientific question | Status | Evidence-based boundary | Next admissible action |
|---|---|---|---|
| Does the D3Q19/Metal implementation reproduce its engineering canonicals? | **Closed engineering boundary** | Shear-wave, moving-wall, topology-changing-body, Re=100 sphere, fixed-wing, and prescribed-flapping gates pass within their declared tolerances. These gates validate those configurations, not arbitrary bird flight. | Keep them as release regressions; do not widen their claims. |
| Is the published-condition high-Re stationary sphere spatially converged? | **Resolved negative at D8; D20 blocked** | RR3 keeps D8/D12/D16 positive and accounting-closed, but drag is non-monotonic. The retained ten-time and both single-period attempts failed. A preregistered vector-force test then separated a low transverse mode from its drag harmonic at 30 times, but only two complete low-mode blocks fit. The exact-prefix 60-time extension tightened mean-drag uncertainty to `4.394%` while low-band dominance fell to `1.180 < 1.5`; longer averaging therefore did not identify one stable D8 mode. | Test D8 sub-cell placement/grid-orientation sensitivity. Do not allocate D20, change thresholds, or promote RR3 into bird replay. |
| Is the measured dove D28/D32 force history grid-stable? | **Active code-solvable boundary** | Both grids pass numerical gates, and static whole-surface direction redistribution is cleared over the localized phase window, but the force-history change is `5.6322% > 5%`. | Run the already identified zero-fluid force-bearing replay of moving-wall velocity, interpolation branch, and reflected-population interaction over the same 11 samples. D36 remains blocked. |
| Is formation-flight aerodynamic power quantitatively converged? | **Compute-blocked boundary** | Shared-fluid coupling, ownership, actuator accounting, and nine-case audits pass. The three-phase source mean remains mixed and the wider power study is not authorized. | Resolve the source/refinement prerequisite before allocating the wider formation-power map. |
| Can the project predict quantitative six-DOF flight for a real bird? | **Measured-data boundary** | Schema-2 loading, bilateral wing inertial reaction, whole-body dynamics, runtime safety aborts, and refinement ladders exist. No complete same-specimen dataset supplies the required bilateral wing and whole-bird inertial properties. | Acquire and register one specimen's calibrated geometry, kinematics, mass, COM, and inertia. Until then, retain wing-only or explicitly hybrid claims. |
| Is forced channel flow validated? | **Model-scope boundary** | The validation protocol specifies the parabolic-profile and flow-rate gates, but the production forced-channel GPU mode is not implemented. | Implement the constant-body-force channel canonical before making pressure-gradient/channel claims. |
| Are turbulence, feather porosity/flexibility, aeroelastic deformation, and biological control validated? | **Model-scope boundary** | The present production model is rigid-surface weakly compressible LBM with the documented boundary and correction operators. These additional physical models have no accepted canonical here. | Add one model at a time with an independent canonical and refinement contract; do not infer it from visual wake quality. |

## High-Re sphere decision chain

The old statement “D8 needs more averaging” is now falsified.

1. The 10-time drag-only source was numerically valid but its adjacent-window
   means were unstable.
2. The preregistered V1 analysis (`tU/D = 2...10`) found Fourier period
   `2.67` but autocorrelation period `0.260`, so period identification failed.
3. The exact-prefix 30-time extension passed every unchanged numerical gate.
   V2 (`10...30`) again found Fourier period `2.492` versus autocorrelation
   period `0.260`; the single-period model failed again.
4. That failure was scientifically informative. Experiments report coexisting
   low and high sphere-wake modes for `800 <= Re <= 15000`
   ([Sakamoto and Haniu, 1990](https://doi.org/10.1115/1.2909415)), while
   Re=10,000 studies place the low vortex-shedding mode near `St=0.195` and
   the shear-layer mode near `St=1.7...2.3`
   ([Rodriguez et al., 2013](https://doi.org/10.1016/j.compfluid.2012.03.009)).
   A drag-only single-period estimator was therefore the wrong discriminator.
5. Before another run, the vector-force multimode contract froze a low
   transverse band, drag-harmonic band, shear-layer band, split-half gate, and
   complete-low-mode-period uncertainty gate. At 30 times it identified
   transverse `St=0.1499`, drag `St=0.4013`, and a descriptive shear-band peak
   at `St=1.604`, but the duration supported only two complete low-mode blocks.
6. The preregistered 60-time extension reproduced all first 3,000 drag/Y/Z
   samples exactly. It produced 11 complete blocks and tight drag uncertainty,
   but the low frequency shifted to `St=0.2318` and lost the frozen dominance
   gate. Independent reconstruction passes `19/19` checks for each analysis.

The defensible conclusion is not that the physical sphere has no shedding
frequency. It is that this D8 voxel/lattice representation does not provide a
stationary, placement-independent low-mode statistic capable of authorizing
the next spatial allocation. No threshold was relaxed and both failed
single-period analyses remain retained evidence.

## Bird data boundary: files and how they are made

Quantitative prescribed replay needs a specimen JSON plus traceable source
files. Quantitative free flight needs schema 2 of that same specimen.

| Data | Preferred source file | How it is made |
|---|---|---|
| Calibrated surface geometry | PLY/OBJ/STL or calibrated point cloud, plus transform/calibration metadata | Multi-camera reconstruction, structured-light/laser scan, CT, or another calibrated 3-D acquisition. Preserve the raw mesh and record the transform into the body COM principal-axis frame. |
| Independent left/right pose and rate history | CSV/JSON tables with timestamps, quaternions/rotation matrices, and angular rates | Calibrated multi-view tracking or motion capture. Export measured timestamps; derive rates with a declared smoothing/differentiation method rather than hand-entering them. |
| Flight and fluid condition | JSON/CSV laboratory log | Measure air density inputs, dynamic viscosity or temperature/pressure/humidity, freestream vector, sampling rate, and tunnel/room boundaries during the same trial. |
| Whole-bird mass, COM, and principal inertia | CSV/JSON measurement record with uncertainty and frame definition | Weigh the same specimen; determine COM by balance/suspension and inertia by a calibrated pendulum, torsional, imaging-plus-density, or equivalent documented method. Register the result to the declared body frame. |
| Left and right wing mass, hinge-relative COM, and principal inertia | One record per wing, with uncertainty | Measure each wing from the same specimen. Preserve bilateral values; do not mirror one side or substitute a species mean for a measured claim. |
| External comparison forces | CSV with time, channel definitions, calibration, sign/frame, filtering, and uncertainty | Calibrate the balance/sensor, retain the raw voltage/count file, document filtering and registration, then export the comparison channels without hiding unavailable lateral force. |
| Provenance manifest | JSON plus checksums | Record specimen ID, acquisition, processing code/version, units, coordinate transforms, citations/licenses, and SHA-256 of every deposited source file. |

The exact schema and preflight rules are in
[`MEASURED_BIRD_DATA.md`](MEASURED_BIRD_DATA.md). The source-owner request for
missing same-specimen properties is in
[`SAME_SPECIMEN_DATA_REQUEST.md`](SAME_SPECIMEN_DATA_REQUEST.md). If the mass or
inertia measurements do not exist, a more elaborate JSON file does not remove
the boundary.

## Operating rule

For every active scientific boundary:

1. state the one hypothesis that the next run can falsify;
2. hash-lock inputs and thresholds before observing its output;
3. retain negative results and exact-prefix checks;
4. independently reconstruct the decisive statistics;
5. authorize only the next bounded experiment, never a production or biological
   claim by implication.

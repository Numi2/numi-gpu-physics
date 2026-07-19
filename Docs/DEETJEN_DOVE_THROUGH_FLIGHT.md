# Deetjen dove through-flight direction

## Objective

Simulate the reconstructed Deetjen OB F03 dove moving through its measured-
derived laboratory trajectory. Preserve the source's non-periodic body
translation, wing motion, tail motion, timing, force registration, and
scientific provenance instead of turning the flight into a body-fixed loop.

## Implemented first slice

`birdflow simulate deetjen-dove` loads the locked complete-surface manifest and
the synchronized measured-force target, then advances the complete `0...143 ms`
source interval through the production moving-boundary geometry, link, fluid,
and conservative-force path.

```bash
.build/release/birdflow simulate deetjen-dove \
  --input ValidationInputs/deetjen-ob-f03-surface-v1/manifest.json \
  --force-target ValidationInputs/deetjen-ob-f03-force-v1.json \
  --archive ValidationArtifacts/deetjen-dove-through-flight-v1.json
```

The wrapper builds the release executable, runs the same command, and checks
the resulting completion contract:

```bash
./Scripts/run-deetjen-through-flight.sh
```

## Locked through-flight result

| Quantity | Result |
|---|---:|
| Source frames | `144` |
| Source duration | `0.143 s` |
| Grid | `75 x 69 x 66` |
| Fluid steps | `4,576 / 4,576` |
| Collision operator | recursive-regularized BGK |
| Body-center displacement | `[0.187064, 0.044940, -0.008277] m` |
| Body-center travel | `0.241865 m` |
| Mean displacement velocity | `[1.308141, 0.314267, -0.057879] m/s` |
| Registered comparison samples | `187` |
| Population diagnostic samples | `286` |
| Minimum sampled population | `2.81374e-4` |
| Archived wake slices | `26` transverse `69 x 66` planes |
| Wake-plane position | `x = body - 0.22 m` |
| Complete timeline | passed |

The authoritative machine-readable evidence is
`ValidationArtifacts/deetjen-dove-through-flight-v1.json`.

Schema 3 archives one `bodyTrajectorySamples` entry for each of the 144 source
frames: body-center position, measured-derived velocity, displacement from the
first frame, and monotone cumulative travel. The run wrapper rejects missing,
reordered, or non-monotone trajectory evidence.

The same report now contains 26 observational wake readbacks at source frames
`1, 7, 13, 19, 25, 31, 37, 43, 49, 55, 61, 67, 73, 79, 85, 91, 97, 103,
109, 115, 118, 121, 127, 133, 139, 143`. Each is a body-following transverse
plane at `x = body - 0.22 m` with density, signed streamwise vorticity
`omega_x`, positive Q, and a validity mask. The diagnostic uses centered
physical-space differences and excludes solid or incomplete seven-cell
stencils. Shared-buffer readback is observational: the original pilot report
is byte-for-byte identical after excluding runtime.

## Through-flight observatory

The deterministic native Metal capture consumes the complete-surface manifest
and the hashed schema-3 simulation report:

```bash
./Scripts/capture-deetjen-through-flight-observatory.sh
```

It produces:

- `Docs/Media/deetjen-through-flight-observatory.mp4`: 48 frames at 1120x630;
- `Docs/Media/deetjen-through-flight-observatory.png`: the poster frame;
- `ValidationArtifacts/deetjen-through-flight-observatory-v1.json`: the visual
  evidence audit and exact input-report hash.

The camera follows the body, but geometry remains in the laboratory frame. A
cyan line retains the translating body-centroid path, while the HUD shows raw
source time/frame, body speed and displacement, the registered measured and D8
RR3 vertical-force histories, solver completion, and population positivity.
The renderer reproduces every archived body center against the source surface
to within `1e-7 m` before capturing.

The observatory renders the archived wake plane behind the moving body. Blue
and orange encode signed `omega_x`; positive Q raises luminance. Common display
scales are frozen from the report's 95th-percentile signal magnitudes
(`161.111 s^-1` vorticity and `73024.578 s^-2` positive Q). The 48-frame movie
linearly interpolates adjacent archived slices in source time and renders wake
evidence on 47 frames; the initial frame precedes the first readback. This
interpolation is a visualization transform, not an additional CFD sample or a
full wake volume.

Translucent prior wing surfaces and wingtip ribbons remain kinematic history,
not computed vortices. The capture labels the computed transverse plane and
keeps these presentation layers visually distinct.

## What changed from the existing showcase

The README dove showcase uses frames `27...121`, subtracts the body centroid,
and adds a labeled `14 ms` presentation-only closure to form a seamless loop.
That path is useful for inspecting wing motion but it does not depict the
bird's measured-derived travel through the laboratory frame.

The through-flight path uses the raw registered vertex positions and velocities
from all frames. Body translation is therefore part of the moving wall seen by
the fluid, not a camera effect or post-render transform.

## Scientific boundary

This is prescribed-motion engineering CFD:

- the measured-derived surface trajectory drives the fluid;
- the computed aerodynamic load does not alter the bird trajectory;
- the right wing remains a bilateral reconstruction from the measured side;
- D8 uses the stable engineering viscosity, which exceeds the source viscosity;
- the archived wake evidence is one sparse body-following transverse plane,
  not a simultaneous three-dimensional wake volume;
- the `25...118 ms` registered force window is retained, but V1 does not claim
  experimental agreement or grid convergence.

Calling this result free flight would be incorrect. A load-responsive Deetjen
body requires same-specimen whole-bird and bilateral-wing mass properties that
the public record does not provide.

## Direction from here

1. Add two or more aft stations, or a bounded full-volume archive, to separate
   wake convection from evolution without weakening the observational readback
   contract.
2. Extend the already-qualified source-viscosity refinement from the registered
   force window through the complete `143 ms` surface timeline.
3. Compare the synchronized horizontal and vertical forces only after the
   finest-two grid result stabilizes under the frozen validation contract.
4. Keep any body-response experiment explicitly hybrid until same-specimen
   inertia and bilateral wing mass properties are available.

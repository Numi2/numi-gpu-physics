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

## Locked V1 result

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
| Complete timeline | passed |

The authoritative machine-readable evidence is
`ValidationArtifacts/deetjen-dove-through-flight-v1.json`.

## What changed from the existing showcase

The README dove showcase uses frames `27...121`, subtracts the body centroid,
and adds a labeled `14 ms` presentation-only closure to form a seamless loop.
That path is useful for inspecting wing motion but it does not depict the
bird's measured-derived travel through the laboratory frame.

The through-flight path uses the raw registered vertex positions and velocities
from all frames. Body translation is therefore part of the moving wall seen by
the fluid, not a camera effect or post-render transform.

## Scientific boundary

V1 is prescribed-motion engineering CFD:

- the measured-derived surface trajectory drives the fluid;
- the computed aerodynamic load does not alter the bird trajectory;
- the right wing remains a bilateral reconstruction from the measured side;
- D8 uses the stable engineering viscosity, which exceeds the source viscosity;
- the `25...118 ms` registered force window is retained, but V1 does not claim
  experimental agreement or grid convergence.

Calling this result free flight would be incorrect. A load-responsive Deetjen
body requires same-specimen whole-bird and bilateral-wing mass properties that
the public record does not provide.

## Direction from here

1. Add a through-flight observatory that follows the translating body and
   renders the evolving computed wake without body-centering the geometry.
2. Extend the already-qualified source-viscosity refinement from the registered
   force window through the complete `143 ms` surface timeline.
3. Compare the synchronized horizontal and vertical forces only after the
   finest-two grid result stabilizes under the frozen validation contract.
4. Keep any body-response experiment explicitly hybrid until same-specimen
   inertia and bilateral wing mass properties are available.

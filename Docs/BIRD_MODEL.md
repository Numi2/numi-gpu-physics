# Bird model

## Included model

The included development geometry contains:

- ellipsoidal torso
- two tapered finite-thickness wings
- tapered tail
- six-degree-of-freedom rigid torso
- sinusoidal wing stroke and pitch

The prescribed wings are massless kinematic boundaries in the current dynamics model. Their aerodynamic loads enter the rigid-torso total, but wing mass/inertia, hinge reactions, and actuator loads are not modeled.

It is not assigned to a species. `BirdParameters.demonstration` is selected to fit the default domain and exercise moving-boundary coupling.

## Coordinate system

```text
+x  forward
+y  bird's left
+z  upward
```

The tail extends in `-x`. The wing roots are offset in `+y` and `-y`. Stroke rotates around the forward body axis. Pitch rotates around each instantaneous span axis.

`BirdBodyState.positionMeters` is the center of mass used by every aerodynamic torque arm. `BirdParameters.principalInertiaKilogramMetersSquared` is treated as diagonal in this same body frame. Imported meshes, hinge coordinates, measured kinematics, and the inertia tensor must therefore be registered to a center-of-mass-centered principal-axis frame before use.

## Data required for a measured bird

- body and tail surface geometry
- left and right wing planform and thickness
- mass and center of mass
- principal inertia tensor and body-frame orientation
- wing hinge locations
- stroke, deviation, pitch, and twist versus phase
- flight speed and atmospheric density/viscosity

## Production geometry path

```text
measured surface mesh
    -> watertight repair and body coordinates
    -> segmented body / left wing / right wing / tail
    -> signed-distance volumes or surface cut links
    -> GPU boundary field at each timestep
```

For rigid articulated segments, each segment can retain a local signed-distance volume and be transformed on the GPU. Deforming wings require a narrow-band distance update or cut-link calculation from the deformed surface.

The fluid boundary interface should expose only occupancy/intersection, boundary point, normal when required, local wall velocity, and part identifier. This keeps geometry independent from collision and body integration.

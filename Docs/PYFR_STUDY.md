# PyFR architecture study and BirdFlowMetal mapping

## Scope

No separate public project named “PyFR++” was identified. The reference studied here is PyFR 3.1 and its Metal backend.

PyFR is organized around a strong separation of responsibilities:

1. A controller owns time advancement and determines when output or synchronization is required.
2. A stepper/integrator defines how physical state advances.
3. A system owns physical elements, interfaces, boundary conditions, and state arrays.
4. A backend owns device allocation, kernel compilation, pipeline selection, dispatch, and execution ordering.
5. Pointwise numerical kernels are described independently and rendered into backend-specific source.
6. Kernels are created ahead of the timestep loop and grouped into an execution graph.

The Navier–Stokes system itself is thin. It selects element and interface implementations. Elements register volume-flux operations; interfaces register interior and boundary-flux operations. The Metal backend supplies buffer types, runtime compilation, compute pipelines, dispatch dimensions, command queues, and a graph that sequences kernels.

## BirdFlowMetal mapping

| PyFR responsibility | BirdFlowMetal component |
|---|---|
| Controller/integrator | `BirdFlowSimulation.advance` |
| Physical system | `BirdFlowSimulation` fluid and body state |
| Element volume work | bulk D3Q19 stream/collision in `stepFluidTRT` |
| Boundary/interface work | moving bird links and far-field handling |
| Backend | `MetalBackend` |
| Pointwise kernels | MSL functions in `BirdFlow.metal` |
| Kernel graph | geometry → fluid → reduction → body integration |
| Host/device state types | `GPUData.swift` |

The reusable design principle is not PyFR’s exact flux-reconstruction method. It is the controller/resource/command-graph separation. Unlike PyFR’s templated pointwise operators, BirdFlowMetal’s production numerical operators are currently written directly in backend-specific MSL.

## Bird-specific changes

PyFR is a general high-order compressible solver on unstructured, body-fitted meshes. BirdFlowMetal specializes the problem:

- The target is low-Mach flapping flight rather than a general compressible-flow suite.
- The boundary moves and articulates every step.
- Wing kinematics are first-class state.
- Aerodynamic loads return to a body integrator every step.
- A regular lattice gives a fixed stencil and predictable Metal dispatch.
- The geometry operator generates body/wing/tail occupancy and local wall velocity directly on the GPU.

## Command graph

```text
prepareBirdGeometry
    writes one timestep-uniform articulated pose/frame record

buildBirdGeometry
    writes next byte occupancy/part mask and wall velocity

stepFluidTRT
    reads current populations and previous/current geometry
    writes next populations, optional captured density/velocity,
    and one partial load per 256-cell threadgroup

reduceForceTorque
    reduces threadgroup partials to one total load

integrateBirdBody
    reads total load
    updates pose and velocity when free flight is enabled
```

All pipelines are created once per backend. Population and solid-mask buffers ping-pong without copies. Several complete coupled steps are encoded in each command buffer; a larger `advance` call can queue multiple ordered command buffers and waits only after the final submission.

## Extension points

- Replace procedural geometry with local signed-distance volumes or mesh-derived cut links.
- Replace halfway bounce-back with interpolated curved-link bounce-back or immersed-boundary forcing.
- Replace TRT with regularized MRT, central-moment, or entropic collision.
- Add a subgrid turbulence operator before collision.
- Replace one uniform lattice with multiblock refinement.
- Replace prescribed rigid wings with structural degrees of freedom and two-way deformation coupling.

## PyFR files inspected

- `pyfr/backends/metal/base.py`
- `pyfr/backends/metal/provider.py`
- `pyfr/backends/metal/generator.py`
- `pyfr/backends/metal/types.py`
- `pyfr/solvers/navstokes/system.py`
- `pyfr/solvers/navstokes/elements.py`
- `pyfr/solvers/navstokes/inters.py`
- `pyfr/solvers/navstokes/kernels/tflux.mako`

See `SOURCES.md` for links.

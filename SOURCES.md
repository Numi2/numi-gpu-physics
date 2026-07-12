# Sources studied

## PyFR architecture

- PyFR project and documentation: https://www.pyfr.org/ and https://pyfr.readthedocs.io/
- PyFR source: https://github.com/PyFR/PyFR
- PyFR v3.1 release: https://github.com/PyFR/PyFR/releases/tag/v3.1
- Metal backend: https://github.com/PyFR/PyFR/tree/v3.1/pyfr/backends/metal
- Navier–Stokes solver: https://github.com/PyFR/PyFR/tree/v3.1/pyfr/solvers/navstokes
- F. D. Witherden, A. M. Farrington, and P. E. Vincent, “PyFR: An Open Source Framework for Solving Advection–Diffusion Type Problems on Streaming Architectures Using the Flux Reconstruction Approach”: https://arxiv.org/abs/1312.1638
- F. D. Witherden et al., “PyFR v2.0.3: Towards Industrial Adoption of Scale-Resolving Simulations”: https://arxiv.org/abs/2408.16509

## Moving-body and bird-flight numerics

- M. Guerrero-Hurtado et al., “A Python-based flow solver for numerical simulations using an immersed boundary method on single GPUs”: https://arxiv.org/abs/2406.19920
- J. P. Giovacchini and O. E. Ortiz, “Flow force and torque on submerged bodies in lattice-Boltzmann via momentum exchange”: https://arxiv.org/abs/1407.4524
- P. Zhang et al., “Velocity interpolation based Bounce-Back scheme for non-slip boundary condition in Lattice Boltzmann Method”: https://arxiv.org/abs/1903.01111
- X. Cui et al., “A Coupled Two-relaxation-time Lattice Boltzmann–Volume Penalization method for Flows Past Obstacles”: https://arxiv.org/abs/1901.08766
- K. Xiao et al., “Modeling, Simulation and Implementation of a Bird-Inspired Morphing Wing Aircraft”: https://arxiv.org/abs/2007.03352

The code in this repository is original and does not copy PyFR source. PyFR was used to study component boundaries, precompiled kernel execution, backend separation, data ownership, and command-graph organization. The numerical references above informed the choice of a regular low-Mach lattice, moving boundaries, TRT collision, and momentum-exchange loads.

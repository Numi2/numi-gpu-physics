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
- B. Wen et al., “Galilean Invariant Fluid-Solid Interfacial Dynamics in Lattice Boltzmann Simulations”: https://arxiv.org/abs/1303.0625
- C. Peng et al., “Issues associated with Galilean invariance on a moving solid boundary in the lattice Boltzmann method,” Phys. Rev. E 95, 013301 (2017): https://doi.org/10.1103/PhysRevE.95.013301
- P. Lallemand and L.-S. Luo, “Lattice Boltzmann method for moving boundaries,” J. Comput. Phys. 184 (2003): https://doi.org/10.1016/S0021-9991(02)00022-0
- P. Zhang et al., “Velocity interpolation based Bounce-Back scheme for non-slip boundary condition in Lattice Boltzmann Method”: https://arxiv.org/abs/1903.01111
- X. Cui et al., “A Coupled Two-relaxation-time Lattice Boltzmann–Volume Penalization method for Flows Past Obstacles”: https://arxiv.org/abs/1901.08766
- K. Xiao et al., “Modeling, Simulation and Implementation of a Bird-Inspired Morphing Wing Aircraft”: https://arxiv.org/abs/2007.03352

## Canonical external-flow validation

- R. Taira and T. Colonius, “Three-dimensional flows around low-aspect-ratio flat-plate wings at low Reynolds numbers,” JFM 623 (2009): https://authors.library.caltech.edu/records/frnmk-28536
- P. Bagchi and S. Balachandar, “Effect of free rotation on the motion of a solid sphere in linear shear flow at moderate Re,” JFM 466 (2002): https://doi.org/10.1017/S0022112002001490
- H. Homann et al., “Particle-resolved direct numerical simulation of homogeneous isotropic turbulence modified by small fixed spheres,” JFM 804 (2016): https://doi.org/10.1017/jfm.2016.548
- H. Li and M. R. A. Nabawy, “Wing Planform Effect on the Aerodynamics of Insect Wings,” Insects 13, 459 (2022): https://doi.org/10.3390/insects13050459

## Measured avian geometry, kinematics, and force

- M. E. Deetjen et al., “Small deviations in kinematics and body form dictate muscle performances in the finely tuned avian downstroke,” eLife 12, RP89968 (2024): https://doi.org/10.7554/eLife.89968
- Deetjen et al. synchronized Ringneck-dove data and code, Dryad: https://doi.org/10.5061/dryad.wwpzgmsqs
- M. E. Deetjen, D. D. Chin, and D. Lentink, “The aerodynamic force platform as an ergometer,” J. Exp. Biol. 223 (2020), including the earlier reconstruction-code deposit referenced by the 2023 dataset: https://doi.org/10.1242/jeb.220475
- M. E. Deetjen et al., “High-speed surface reconstruction of a flying bird using structured light,” J. Exp. Biol. 220 (2017): https://doi.org/10.1242/jeb.149708
- C. Berg and J. M. V. Rayner, “The moment of inertia of bird wings and the inertial power requirement for flapping flight,” J. Exp. Biol. 198 (1995): https://doi.org/10.1242/jeb.198.8.1655

The code in this repository is original and does not copy PyFR source. PyFR was used to study component boundaries, precompiled kernel execution, backend separation, data ownership, and command-graph organization. The numerical references above informed the choice of a regular low-Mach lattice, moving boundaries, TRT collision, and momentum-exchange loads.

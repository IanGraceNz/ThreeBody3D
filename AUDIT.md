# ThreeBody3D 0.2.0 audit

## Removed

- `Revise` runtime dependency.
- Duplicate `Body`, `BodyState`, and `State` public hierarchy, which was not used
  by the integrator and created two competing state representations.
- Low-level exports (`make_problem`, force helpers, validation internals) that
  were implementation details rather than a stable user API.
- Bundled generated `threebody.mp4` artifact.

## Corrected

- Simulation results now retain the system required for diagnostics.
- Diagnostics measure maximum drift over saved states rather than only final
  drift, and center-of-mass motion is compared with its correct inertial path.
- Zero initial energy is handled without division by zero.
- Pairwise force calculations reuse each separation and enforce equal/opposite
  pair contributions, reducing avoidable momentum drift and computation.
- Constructors validate finite, positive masses, positive `G`, finite states,
  tolerances, and time spans.
- Animation and recording use a fixed playback duration instead of treating
  physical simulation time as wall-clock seconds.
- Static plotting, animation, and recording share sampling and axis-limit code.
- Axis limits include a configurable 5% margin and robust handling for flat axes.
- MP4 output validates its extension and destination directory.

## Added

- Docstrings for every exported symbol.
- Comprehensive tests covering constructors, state layout, singularities,
  equations, conservation, integration, diagnostics, argument errors, export
  documentation, and plotting smoke tests.
- Complete figure-eight and hierarchical-triple examples.
- A README with installation, end-to-end usage, numerical scope, and test notes.

## Important limitation

This package is not in Julia's General registry, so the literal command
`Pkg.add("ThreeBody3D")` cannot work for a fresh user until registration. Local
path and Git URL installation are supported. Exact collision regularization is
also not implemented; version 0.2.0 fails explicitly at an exact point-mass
collision rather than changing the physics with softening.

# ThreeBody3D

**ThreeBody3D** is a Julia package for high-accuracy numerical
integration of the Newtonian three-body problem. It combines adaptive
numerical integration, conservation diagnostics, visualization, and a
rigorously validated research framework for close-encounter
regularization.

The project is designed around four principles:

-   Scientific correctness
-   Numerical accuracy
-   Reproducibility
-   Clean, modular APIs

------------------------------------------------------------------------

# Features

-   High-accuracy adaptive Newtonian three-body integration
-   Multiple solver accuracy profiles
-   Energy, momentum, angular-momentum, and centre-of-mass diagnostics
-   Built-in 3D plotting, animation, and MP4 recording
-   Continuous close-approach monitoring
-   Arbitrary-precision (`BigFloat`) reference integrations
-   Pair-centred coordinate transformations
-   Levi--Civita and spatial KS regularization research infrastructure
-   Experimental automatic regularization switching with selectable backends
-   Comprehensive scientific validation suite

------------------------------------------------------------------------

# Installation

``` julia
using Pkg

Pkg.add(path="/path/to/ThreeBody3D")
# or
Pkg.add(url="https://.../ThreeBody3D.jl")
```

After registration:

``` julia
Pkg.add("ThreeBody3D")
```

------------------------------------------------------------------------

# Quick Start

``` julia
using ThreeBody3D

system = ThreeBodySystem((1.0,1.0,1.0))

u0 = statevector(
    [-0.97000436, 0.24308753, 0.0], [ 0.466203685, 0.432365730, 0.0],
    [ 0.97000436,-0.24308753, 0.0], [ 0.466203685, 0.432365730, 0.0],
    [ 0.0, 0.0, 0.0],              [-0.93240737,-0.86473146,0.0],
)

result = simulate(system, u0, (0.0,6.4); saveat=0.01)

println(diagnostics_report(result))
plot_trajectory(result)
animate(result)
record_animation(result,"figure_eight.mp4")
```

------------------------------------------------------------------------

# Simulation

The primary interface is:

``` julia
simulate(system, initial_state, timespan; kwargs...)
```

ThreeBody3D models exact Newtonian point masses. Exact collisions remain
mathematical singularities and are reported rather than hidden by force
softening.

------------------------------------------------------------------------

# Accuracy Profiles

  Profile       Purpose
  ------------- -------------------------------------------------------
  `:fast`       Exploratory calculations
  `:accurate`   Recommended production simulations
  `:extreme`    Arbitrary-precision `BigFloat` reference calculations

------------------------------------------------------------------------

# Diagnostics

Each simulation reports:

-   Relative energy drift
-   Momentum drift
-   Angular momentum drift
-   Centre-of-mass residuals
-   Solver statistics
-   Minimum pair separation

------------------------------------------------------------------------

# Close-Approach Monitoring

Continuous event detection is available using `close_approach_threshold`
together with the policies:

-   `:ignore`
-   `:warn`
-   `:terminate`

------------------------------------------------------------------------

# Visualization

ThreeBody3D includes:

-   3D trajectory plots
-   Interactive animation
-   MP4 recording

------------------------------------------------------------------------

# Regularization Research

Research capabilities currently include:

-   Pair-centred coordinates
-   Analytic Kepler reference solutions
-   Planar Levi--Civita regularization
-   Spatial Kustaanheimo--Stiefel (KS) regularization for one selected pair
-   Sundman physical-time reconstruction
-   Explicit regularized segment propagation
-   Manual regularized trajectory composition
-   Experimental automatic switching between Cartesian and regularized segments

The KS implementation is retained as internal research infrastructure during
the first implementation cycle. It is exercised through repository tests,
validation programs, and the existing experimental switching interface; no
stable public KS API is introduced in v0.4 development. See
`KS_REGULARIZATION_DESIGN.md`, `KS_FORMULATION_REVIEW.md`, and
`REGULARIZATION_DESIGN.md` for the mathematical scope and design decisions.

------------------------------------------------------------------------

# Experimental Automatic Switching

An experimental controller can automatically alternate between Cartesian
integration and a selected regularized backend for isolated binary encounters.
The validated backends are planar Levi--Civita and spatial KS. KS is selected
with `regularization_backend=:ks` in the experimental controller. This research
interface is separate from the stable production `simulate` API and may change
without deprecation while v0.4 remains in development.

------------------------------------------------------------------------

# Scientific Validation

The repository includes validation benchmarks covering:

-   Figure-eight periodic orbit
-   Hierarchical triple
-   Automatic switching
-   Close-encounter regularization
-   Equilateral triple collision
-   Randomized regression
-   Exact Kepler propagation in KS coordinates
-   KS continuation through radial binary collision
-   Independent KS and Levi--Civita cross-validation
-   Coupled KS propagation in a hierarchical triple
-   KS and Levi--Civita automatic-switching comparison

Each benchmark contains explicit quantitative acceptance criteria. Run the
complete suite from the repository root with:

``` julia
julia --project=. examples/validation/run_validation_suite.jl
```

The suite runs each case in a separate Julia process and reports an overall
pass or failure result.

------------------------------------------------------------------------

# Regularization Limitations

The validated regularization scope is one explicitly selected Newtonian binary
pair at a time. It does not regularize a simultaneous triple collision, a
non-selected pair that independently becomes singular, or general compact
few-body dynamics. Pair isolation, switching thresholds, gauge diagnostics,
and transition residuals remain part of the experimental research workflow.
Exact Newtonian point-mass collisions outside the selected regularized pair
remain singular.

------------------------------------------------------------------------

# Testing

``` julia
using Pkg
Pkg.test("ThreeBody3D")
```

------------------------------------------------------------------------

# API Stability

Stable and experimental interfaces are documented in `API_STABILITY.md`.

------------------------------------------------------------------------

# Examples

The `examples/` directory contains complete runnable demonstrations for
all major capabilities.

------------------------------------------------------------------------

# License

See the repository license for licensing information.

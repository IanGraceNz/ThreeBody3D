# ThreeBody3D

A focused Julia package for high-accuracy Newtonian three-body integration,
conservation diagnostics, 3D plotting, live animation, and MP4 recording.

## Installation

Until ThreeBody3D is registered in Julia's General registry, install it from a
local checkout or a Git repository:

```julia
using Pkg
Pkg.add(path="/path/to/ThreeBody3D")
# or: Pkg.add(url="https://.../ThreeBody3D.jl")
```

After registry acceptance, `Pkg.add("ThreeBody3D")` will work directly.

## Complete workflow

```julia
using ThreeBody3D

system = ThreeBodySystem((1.0, 1.0, 1.0))
u0 = statevector(
    [-0.97000436,  0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.97000436, -0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [0.0, 0.0, 0.0],                [-0.93240737, -0.86473146, 0.0],
)

result = simulate(system, u0, (0.0, 6.4); saveat=0.01)
println(diagnostics_report(result))
plot_trajectory(result)
animate(result; duration=10)
record_animation(result, "figure_eight.mp4"; duration=10)
```

`duration` is playback duration, independent of the physical integration span.
All visualization functions add a 5% axis margin by default.

## Numerical scope

The default `Vern9()` adaptive solver with `reltol=abstol=1e-12` is intended as
a strong general-purpose accuracy baseline. Diagnostics report maximum drift
across saved states, so use a suitable `saveat` when detailed monitoring is
important.

ThreeBody3D models exact Newtonian point masses. An exact collision is a true
mathematical singularity; the package deliberately raises an error instead of
silently applying force softening. Near-collision trajectories can require
stricter tolerances and specialized regularized coordinates. Such
regularization is not claimed by version 0.2.0.

## Testing

```julia
using Pkg
Pkg.test("ThreeBody3D")
```

On headless Linux systems, GLMakie visualization tests may require an X virtual
framebuffer, for example `xvfb-run -a julia --project -e 'using Pkg; Pkg.test()'`.

## Accuracy profiles and validation (v0.3 development)

`simulate` accepts a named accuracy profile or an OrdinaryDiffEq algorithm:

```julia
fast_result = simulate(system, u0, (0.0, 6.4); solver=:fast, saveat=0.01)
accurate_result = simulate(system, u0, (0.0, 6.4); solver=:accurate, saveat=0.01)
extreme_result = simulate(system, u0, (0.0, 6.4); solver=:extreme, saveat=0.01)
```

The profiles select both an algorithm and default tolerances. Explicit
`reltol` or `abstol` values override those defaults. They are convenient
starting points rather than guarantees for every trajectory.

For a known periodic orbit:

```julia
period = 6.32591398
error = periodicity_error(accurate_result, period)
```

Compare profiles reproducibly:

```julia
benchmarks = benchmark_solvers(
    system, u0, (0.0, period);
    profiles=(:fast, :accurate, :extreme),
    saveat=0.01,
    period=period,
)
```

Inspect sampled close approaches:

```julia
approach = close_approach_report(accurate_result; threshold=0.7)
println(approach.minimum_separation, " at t = ", approach.time)
```

`close_approach_report` examines saved states. It is a monitoring tool, not a
regularization method, and can miss an undersampled minimum. Use dense output
for encounter studies. Exact collisions remain singular.

Run the complete numerical comparison example with:

```julia
include("examples/numerical_validation.jl")
```

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

`close_approach_report` uses saved states to bracket a candidate encounter and,
by default, refines it using dense interpolation. It is still a monitoring tool,
not a regularization method, and can miss an encounter that is not bracketed by
the saved grid. Use a sufficiently dense `saveat` for encounter studies. Exact
collisions remain singular.


### Continuous close-approach monitoring

For threshold detection during integration, use the continuous event monitor:

```julia
result = simulate(
    system, u0, (0.0, 20.0);
    solver=:accurate,
    saveat=0.1,
    close_approach_threshold=0.7,
    close_approach_policy=:warn,
)

for event in result.close_approach_events
    println(event)
end
```

The available policies are:

- `:ignore` — record inward threshold crossings and continue;
- `:warn` — record, emit a warning, and continue;
- `:terminate` — record and stop at the first inward crossing.

Crossing times are found by the ODE solver's continuous root finder and do not
depend on `saveat`. A callback supplied through `callback=` is combined with the
monitor. This detects threshold entries only; it is not collision
regularization and does not alter the Newtonian force law.

Run the complete numerical comparison example with:

```julia
include("examples/numerical_validation.jl")
```


### Figure-eight benchmark precision

The standard Simó initial conditions and period used in the examples are the
digits published with the original figure-eight result. The observed periodicity
error therefore includes uncertainty in those benchmark constants; tighter solver
tolerances cannot recover digits that are absent from the initial data. Energy and
momentum conservation remain useful independent accuracy checks.

A complete policy demonstration is available in:

```julia
include("examples/close_approach_policies.jl")
```

`terminated_by_close_approach(result)` reads an explicit termination flag
recorded by the integration callback; it does not infer termination from
floating-point equality between event and final times.

## Arbitrary-precision reference calculations

The `:extreme` profile is a reference-computation mode rather than a faster or
more convenient version of `:accurate`. It performs the complete integration
with `BigFloat`, uses 256-bit precision by default, and starts with
`Vern9()` at `1e-30` relative and absolute tolerances:

```julia
reference = simulate(
    system_big,
    u0_big,
    (big"0.0", big"6.32591398");
    solver=:extreme,
    precision=256,
    saveat=big"0.01",
)
```

For genuine reference work, construct masses, state components, times, and
thresholds from decimal strings. `BigFloat(0.1)` preserves the already-rounded
Float64 value; `parse(BigFloat, "0.1")` or `big"0.1"` starts from the decimal
value.

The default was selected from measured results on the figure-eight benchmark: BigFloat `Vern9` delivered approximately `1e-32` relative energy drift, while the tested Feagin methods remained near `1e-11` to `1e-10`. The comparison harness is retained because solver performance can change across problems and future SciML releases:

```julia
benchmarks = benchmark_extreme_solvers(
    system_big,
    u0_big,
    (big"0.0", big"6.32591398");
    algorithms=(:vern9, :feagin12, :feagin14),
    precision=256,
    reltol="1e-30",
    abstol="1e-30",
    saveat=big"0.01",
)
```

See `examples/high_precision_reference.jl` for a complete example. Very tight
local tolerances do not prove equally small global trajectory error, especially
for chaotic trajectories, close encounters, interpolation, or truncated
initial data.

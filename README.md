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


## Experimental v0.4 pair coordinates

Stage 1 of the regularization roadmap adds an algebraic, exactly reversible
pair-centred decomposition without changing the integrator:

```julia
coordinates = to_pair_coordinates(system, u0, (1, 2))
reconstructed = from_pair_coordinates(system, coordinates)
```

For an ordered pair `(i, j)`, the relative vectors are `rᵢ-rⱼ` and `vᵢ-vⱼ`.
The remaining fields contain the binary centre-of-mass state and the third-body
state. Reversing the pair reverses the relative-vector orientation but reconstructs
the same physical state. This is infrastructure for future Levi–Civita and KS
regularization; it does not itself remove the Newtonian singularity. See
`REGULARIZATION_DESIGN.md`.

## Analytic Kepler validation (v0.4 development)

The regularization validation layer includes a universal-variable two-body
reference propagator covering elliptic, near-parabolic, hyperbolic, and radial
motion:

```julia
reference = KeplerReference(1.0, [1.0, 0.0, 0.0], [0.0, 1.0, 0.0])
r, v = kepler_state(reference, π / 2)
```

These functions are validation tools for forthcoming Levi–Civita and KS
implementations. They do not replace or modify the production three-body
integrator. See `examples/analytic_kepler_validation.jl`.

## Experimental planar Levi-Civita maps

The v0.4 development API includes algebraic planar Levi-Civita maps for future
binary-collision regularization:

```julia
lc = to_levi_civita([1.0, 0.2], [0.0, 1.0])
q, qdot = from_levi_civita(lc)
```

The two branches selected by `branch=1` and `branch=-1` are gauge-equivalent.
These functions do not yet integrate Levi-Civita equations or introduce a
Sundman time transformation.

## Experimental fixed-fictitious-time Levi-Civita oscillator

Stage 4A provides `LeviCivitaOscillator` and
`integrate_levi_civita_fictitious` for the isolated planar Kepler problem.
This experimental layer integrates only fictitious time; physical-time
reconstruction and stopping are intentionally deferred to Stage 4B.

### Fixed-fictitious-time Sundman validation

Stage 4B can integrate physical time alongside the isolated Levi-Civita
oscillator without stopping on physical time:

```julia
oscillator = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 0.5])
result = integrate_levi_civita_sundman(oscillator, (0.0, 0.8))
u, uprime, physical_time = levi_civita_sundman_state(result, 0.8)
```

This remains a research validation path and does not alter `simulate`.

### Stage 4C: requested physical-time states

`levi_civita_fictitious_time` inverts the monotone exact Sundman map with an expanding bracket and bisection. `levi_civita_state_at_time` returns the isolated regularized solution at a requested physical time without callbacks.

```julia
state = levi_civita_state_at_time(oscillator, 0.75)
```

### Experimental perturbed planar binary

Version 0.4 development includes an explicit selected-pair planar research path:

```julia
problem = PerturbedLeviCivitaProblem(system, u0, (1, 2))
regularized = integrate_perturbed_levi_civita(problem, (0.0, 0.5))
state = perturbed_levi_civita_state(regularized, 0.5)
```

This integrates over fixed fictitious time. It does not automatically select a
pair, switch from the production Cartesian solver, or target a requested
physical end time. All input positions and velocities must be planar.

### Targeting physical time in the perturbed planar solver

The experimental selected-pair planar regularization can now be evaluated at a
requested absolute physical time without callbacks:

```julia
state = perturbed_levi_civita_state_at_time(
    problem,
    0.5;
    initial_step=0.5,
    tolerance=1e-11,
)
```

The implementation expands a fictitious-time bracket, integrates once over the
final bracket, and bisects the dense physical-time state. It still performs no
automatic pair selection or switching.

### Explicit regularized segment handoff (experimental)

```julia
segment = propagate_regularized_segment(
    system, u0, (1, 2), 0.0, 0.5;
    initial_step=0.5,
    tolerance=1e-11,
)

println(segment.entry_diagnostics)
println(segment.exit_diagnostics)
```

This performs one explicitly selected planar Cartesian → Levi-Civita →
Cartesian segment. It records coordinate-reconstruction residuals and invariant
jumps at both boundaries. It does not select pairs or switch automatically.

### Manual multi-segment regularization

`compose_regularized_trajectory` composes a Cartesian segment, one explicitly
selected planar Levi-Civita interval, and a final Cartesian segment. The result
retains every underlying solve, transition diagnostics, solver statistics, and
one unified physical trajectory. This is a manual research workflow; it does
not perform automatic threshold switching.

See `examples/manual_regularized_composition.jl`.

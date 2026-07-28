# ThreeBody3D

**ThreeBody3D** is a Julia package for accurate numerical solution and display
of the Newtonian gravitational three-body initial-value problem. It provides
adaptive integration, conservation diagnostics, visualization, analytic
reference solutions, and rigorously validated research tools for close
encounters and selected-pair regularization.

The governing priorities are scientific correctness, long-term numerical
accuracy, careful treatment of singularities, reproducibility, and clean
modular design. Accuracy is preferred to speed whenever the two conflict.

## Installation

From a local checkout:

```julia
using Pkg
Pkg.develop(path = raw"C:\path\to\ThreeBody3D")
```

After registration, installation will be:

```julia
using Pkg
Pkg.add("ThreeBody3D")
```

Load the package with:

```julia
using ThreeBody3D
```

## Quick start

```julia
using ThreeBody3D

system = ThreeBodySystem((1.0, 1.0, 1.0))

u0 = statevector(
    [-0.97000436,  0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.97000436, -0.24308753, 0.0], [ 0.466203685,  0.432365730, 0.0],
    [ 0.0,         0.0,        0.0], [-0.93240737,  -0.86473146,  0.0],
)

result = simulate(system, u0, (0.0, 6.4); solver = :accurate, saveat = 0.01)
println(diagnostics_report(result))
plot_trajectory(result)
```

## Stable public API

### System and state construction

- `ThreeBodySystem(masses; G=1)` constructs the three point masses and
  gravitational constant. `masses` may be a three-tuple or vector of positive
  real values.
- `STATE_SIZE` is the required Cartesian state length, currently `18`.
- `statevector(r1, v1, r2, v2, r3, v3)` builds the state in body order.
- `body_position(u, i)` returns body `i`'s three-component position.
- `velocity(u, i)` returns body `i`'s three-component velocity.

### Accuracy profiles and simulation

- `accuracy_profile(name=:accurate; precision=256)` returns an
  `AccuracyProfile`. Available names are `:fast`, `:accurate`, and `:extreme`.
- `simulate(system, u0, tspan; solver=:accurate, saveat=nothing,
  close_approach_threshold=nothing, close_approach_policy=:ignore, kwargs...)`
  integrates the Cartesian equations and returns a `SimulationResult`.
- `terminated_by_close_approach(result)` reports whether a terminating
  close-approach callback ended the integration.
- `CloseApproachEvent` records a detected threshold crossing.

The profiles are intended as follows:

| Profile | Intended use |
|---|---|
| `:fast` | Exploratory calculations |
| `:accurate` | Recommended ordinary production calculations |
| `:extreme` | Arbitrary-precision `BigFloat` reference calculations |

Example with monitoring:

```julia
result = simulate(
    system,
    u0,
    (0.0, 20.0);
    solver = :accurate,
    close_approach_threshold = 1e-3,
    close_approach_policy = :terminate,
)

println(terminated_by_close_approach(result))
```

Valid close-approach policies are `:ignore`, `:warn`, and `:terminate`.
ThreeBody3D models exact Newtonian point masses; it does not hide singularities
with force softening.

### Physical diagnostics

Each state-level function accepts a `ThreeBodySystem` and Cartesian state:

- `center_of_mass(system, u)`;
- `center_of_mass_velocity(system, u)`;
- `linear_momentum(system, u)`;
- `angular_momentum(system, u)`;
- `kinetic_energy(system, u)`;
- `potential_energy(system, u)`;
- `total_energy(system, u)`;
- `minimum_separation(u)`.

Trajectory-level diagnostics are:

- `relative_energy_error(result)`;
- `diagnostics_report(result)`, returning a printable `DiagnosticsReport`;
- `periodicity_error(result, period; relative=true)`;
- `close_approach_report(result; threshold, ...)`, returning a
  `CloseApproachReport`.

```julia
report = diagnostics_report(result)
println(report)
println("maximum relative energy drift = ", relative_energy_error(result))
println("minimum separation = ", minimum_separation(result.solution.u[end]))
```

### Solver and benchmark utilities

- `benchmark_solvers(system, u0, tspan; kwargs...)` compares the standard
  profiles and returns `SolverBenchmark` records.
- `benchmark_extreme_solvers(system, u0, tspan; kwargs...)` compares candidate
  arbitrary-precision reference solvers.
- `validation_benchmark_names()` returns the built-in benchmark names.
- `run_validation_benchmark(name; kwargs...)` runs one built-in benchmark and
  returns a `ValidationBenchmarkReport`.
- `FIGURE_EIGHT_PERIOD` and `HIERARCHICAL_TRIPLE_DURATION` provide the standard
  benchmark durations used by the package.

```julia
println(validation_benchmark_names())
report = run_validation_benchmark(:figure_eight)
println(report)
```

### Visualization and GLMakie requirements

ThreeBody3D currently uses `GLMakie` directly for all plotting and animation.
`GLMakie` is a package dependency, so ordinary users need only load
ThreeBody3D:

```julia
using ThreeBody3D
```

The visualization functions accept a `SimulationResult` and also support an
`ExperimentalSwitchingTrajectory`:

- `plot_trajectory(result; show=true, kwargs...)` creates and returns a
  three-dimensional `Makie.Figure`;
- `animate(result; fps=30, duration=10, kwargs...)` displays and plays an
  interactive animation, then returns its figure;
- `record_animation(result, filename; fps=30, duration=10, kwargs...)` records
  an MP4 file and returns its absolute path. The filename must end in `.mp4`,
  and its output directory must already exist.

```julia
plot_trajectory(result; margin = 0.05)
animate(result; duration = 12)
output = record_animation(result, "three_body.mp4"; duration = 12)
println(output)
```

These calls may be launched from PowerShell in the same way as numerical
examples:

```powershell
julia --project=. examples\basic_usage.jl
```

A normal Windows desktop session with functioning OpenGL graphics is required.
Launching Julia from PowerShell does not itself make the process headless:
interactive windows can still open, and `record_animation` can render directly
to an MP4 file. Video recording also requires the Makie-provided FFMPEG
components to initialize successfully.

The expected command-line behaviour is:

| Function | PowerShell in a desktop session | Opens a window | Produces a file |
|---|---:|---:|---:|
| `plot_trajectory(result)` | Yes | Yes, by default | No |
| `plot_trajectory(result; show=false)` | Yes | No | No |
| `animate(result)` | Yes | Yes | No |
| `record_animation(result, "orbit.mp4")` | Yes | Not required | Yes, MP4 |

`show=false` suppresses display of a static plot, which is useful for tests, but
the current GLMakie implementation may still require a working OpenGL context.
Consequently, server, CI, SSH, container, and other genuinely headless
environments are not claimed to be supported for visualization. `CairoMakie`
is not currently a supported substitute because the visualization module
imports `GLMakie` directly.

To save a returned static figure, load `GLMakie` explicitly to use its `save`
function:

```julia
using ThreeBody3D
using GLMakie

fig = plot_trajectory(result; show = false)
save("three_body.png", fig)
```

Visualization options affect only presentation; they do not modify the
calculated trajectory data.

## Development research API

These exported interfaces support reproducible regularization research. They
are public during v0.4 development but may still change before release. Users
should call documented functions rather than depend on struct field order.

### Pair-centred coordinates

- `PairCoordinates` stores the selected pair's relative variables, pair
  centre-of-mass variables, and the third body's variables.
- `to_pair_coordinates(system, u, pair)` transforms a Cartesian three-body
  state.
- `from_pair_coordinates(system, coordinates)` reconstructs the Cartesian
  state.

```julia
coordinates = to_pair_coordinates(system, u0, (1, 2))
reconstructed = from_pair_coordinates(system, coordinates)
```

### Levi-Civita coordinate maps

- `LeviCivitaCoordinates` stores planar Levi-Civita coordinates.
- `levi_civita_position(u)` maps the two-dimensional regularized position to
  physical relative position.
- `levi_civita_velocity(u, w)` maps regularized variables to physical relative
  velocity.
- `to_levi_civita(r, v; kwargs...)` performs the inverse lift.
- `from_levi_civita(coordinates)` returns physical planar position and velocity.

### Isolated Levi-Civita propagation

- `LeviCivitaOscillator` defines an isolated regularized two-body problem.
- `integrate_levi_civita_fictitious(problem, sspan; kwargs...)` returns a
  `LeviCivitaFictitiousResult`.
- `levi_civita_fictitious_state(problem_or_result, s)` evaluates regularized
  variables.
- `levi_civita_cartesian_state(problem_or_result, s)` evaluates physical
  relative position and velocity.

### Sundman time reconstruction

- `integrate_levi_civita_sundman(problem, sspan; kwargs...)` returns a
  `LeviCivitaSundmanResult` containing physical time.
- `levi_civita_physical_time(result, s)` maps fictitious to physical time.
- `levi_civita_fictitious_time(result, t; kwargs...)` solves the inverse map.
- `levi_civita_sundman_state(result, s)` evaluates the augmented Sundman state.
- `levi_civita_state_at_time(result, t; kwargs...)` evaluates at physical time.

### Perturbed planar Levi-Civita propagation

- `PerturbedLeviCivitaProblem(system, state, pair; kwargs...)` defines a selected
  pair coupled to the third body.
- `integrate_perturbed_levi_civita(problem, sspan; kwargs...)` returns a
  `PerturbedLeviCivitaResult`.
- `perturbed_levi_civita_state(result, s)` evaluates in fictitious time.
- `perturbed_levi_civita_fictitious_time(result, t; kwargs...)` targets physical
  time.
- `perturbed_levi_civita_state_at_time(result, t; kwargs...)` reconstructs the
  Cartesian three-body state at physical time.

### Explicit segments and manual composition

- `propagate_regularized_segment(system, state, tspan, pair; kwargs...)` returns
  an `ExplicitRegularizedSegment` with `RegularizationTransitionDiagnostics`.
- `compose_regularized_trajectory(...)` combines Cartesian and regularized
  pieces into a `ComposedRegularizedTrajectory` and records
  `SegmentSolverStatistics`.
- `composed_regularized_state(trajectory, t)` evaluates the composed trajectory.

See `examples/explicit_regularized_segment.jl` and
`examples/manual_regularized_composition.jl` for complete workflows.

### Analytic reference solutions

- `KeplerReference(μ, r0, v0)` constructs an analytic two-body reference.
- `kepler_state(reference, Δt; kwargs...)` evaluates position and velocity.
- `kepler_specific_energy(μ, r, v)` evaluates specific orbital energy.
- `kepler_angular_momentum(r, v)` evaluates specific angular momentum.
- `radial_free_fall_time(μ, initial_radius)` returns the collision time for
  zero-velocity radial fall.
- `radial_free_fall_state(μ, initial_position, t; kwargs...)` evaluates the
  analytic radial solution.

## Experimental automatic-switching API

This API automatically alternates between Cartesian propagation and one
selected regularized backend. It is validated for isolated
binary encounters but remains separate from production `simulate` and may
change without deprecation.

### Main workflow

- `AutomaticSwitchingParameters(; kwargs...)` defines entry, exit, pair
  isolation, and backend settings.
- `simulate_experimental_switching(system, u0, tspan, parameters;
  regularization_backend=:levi_civita, cartesian_kwargs=NamedTuple(),
  regularized_kwargs=NamedTuple())` returns an
  `ExperimentalSwitchingTrajectory`.
- `experimental_switching_state(trajectory, t; kwargs...)` evaluates one state.
- `sample_experimental_switching(trajectory, times; kwargs...)` samples explicit
  physical times and returns `ExperimentalSwitchingSamples`.
- `sample_experimental_switching(trajectory; dt, kwargs...)` samples a uniform
  physical-time grid. For either sampling form, `regularized_kwargs` accepts only
  `tolerance` and `max_iterations`; retained regularized segments are evaluated
  by bounded inversion of their dense solutions and are never reintegrated.
- `diagnostics_report(trajectory, samples)` or
  `diagnostics_report(trajectory; dt, kwargs...)` returns an
  `ExperimentalSwitchingDiagnosticsReport`.

```julia
parameters = AutomaticSwitchingParameters()
trajectory = simulate_experimental_switching(
    system,
    u0,
    (0.0, 10.0),
    parameters;
    regularization_backend = :levi_civita, # or :ks
)
samples = sample_experimental_switching(trajectory; dt = 0.02)
println(diagnostics_report(trajectory, samples))
```

The spatial Kustaanheimo–Stiefel transformation (KS) implementation itself
remains internal; selecting
`regularization_backend=:ks` does not make its low-level names public.

### Switching states, events, and helpers

The following exported names support research inspection and testing:

- modes: `ExperimentalSwitchingMode`, `CartesianSwitchingMode`, and
  `RegularizedSwitchingMode`;
- failures and events: `AutomaticSwitchingFailure` and
  `RegularizationSwitchEvent`;
- pair data: `PairObservables`, `pair_observables(u)`, `pair_separations(u)`, and
  `pair_radial_rates(u)`;
- decisions: `AutomaticSwitchingDecision`, `automatic_entry_decision(...)`, and
  `automatic_exit_decision(...)`;
- event location: `CartesianEntryLocationResult`,
  `locate_cartesian_entry_event(...)`, `RegularizedExitLocationResult`, and
  `locate_regularized_exit_event(...)`;
- retained segments: `AutomaticCartesianSegment` and
  `AutomaticRegularizedSegment`.

These are experimental implementation-facing records. Prefer the main workflow
unless investigating switching behaviour or contributing validation work.

## Regularization scope and limitations

The validated regularization scope is one explicitly selected Newtonian binary
pair at a time. The implementation does not regularize:

- a simultaneous triple collision;
- a non-selected pair that independently becomes singular;
- general multiparticle or compact few-body singular configurations.

The Levi-Civita backend is planar. The KS backend is spatial but remains
internal research infrastructure. Pair isolation, switching thresholds, gauge
diagnostics, and transition residuals remain part of the experimental workflow.

## Examples

Every Julia file under `examples/` is user-visible and is included in the v0.4
release-readiness execution audit. Top-level demonstrations include:

- `figure_eight.jl` and `hierarchical_triple.jl`;
- `numerical_validation.jl` and `high_precision_reference.jl`;
- `close_approach_policies.jl`;
- `analytic_kepler_validation.jl`;
- `levi_civita_fictitious_time.jl`, `levi_civita_sundman_time.jl`, and
  `levi_civita_physical_time_target.jl`;
- `perturbed_planar_binary.jl` and
  `perturbed_planar_binary_physical_time.jl`;
- `explicit_regularized_segment.jl`, `manual_regularized_composition.jl`, and
  `composed_regularized_trajectory.jl`;
- `automatic_regularization.jl` and
  `long_duration_switching_validation.jl`.

Run any standalone example from the repository root:

```powershell
julia --project=. examples/figure_eight.jl
```

The `examples/validation/` directory contains the quantitative
benchmarks and support code. Run the complete suite with:

```powershell
julia --project=. examples/validation/run_validation_suite.jl
```

The suite currently covers figure-eight and hierarchical-triple benchmarks,
automatic switching, independent high-precision close-encounter comparison,
equilateral triple collision, randomized regression, KS Kepler propagation,
collision continuation, KS/Levi-Civita cross-validation, coupled KS
hierarchical propagation, and backend switching comparison.

To run the canonical scientific regression workflow against an immutable,
human-reviewed reference and optionally retain deterministic CI artifacts, use
the following command after an approved reference record exists:

```powershell
julia --project=. examples/validation/reviewed_reference_workflow.jl `
    path/to/reviewed-reference.toml `
    validation_reports/current-suite.toml `
    validation_reports/reference-comparison.toml
```

Run the example with `--help` to display its prerequisite without executing the
suite. See `VALIDATION_WORKFLOW.md` for candidate-reference preparation,
approval rules, programmatic use, status interpretation, and CI guidance. The
workflow never updates reference baselines automatically.

Repository performance benchmarks and the fixed accuracy-versus-work series are
documented in `PERFORMANCE_BENCHMARKS.md`. They retain descriptive timing,
solver-work, and accuracy evidence separately from scientific acceptance.

## Testing

From the repository root:

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.test()"
```

## API stability

The detailed stability classification is in `API_STABILITY.md`:

- ordinary simulation, diagnostics, validation, and visualization are the
  stable public API for the current development line;
- Levi-Civita and selected regularization tools are development research API;
- automatic switching is experimental;
- unexported KS internals are not public API.

## Design and validation documents

- `REGULARIZATION_DESIGN.md` describes the regularization
  programme;
- `KS_REGULARIZATION_DESIGN.md` and `KS_FORMULATION_REVIEW.md` document the KS
  formulation and review;
- `IMPLEMENTATION_PLAN_KS.md` records the completed frozen KS implementation
  plan;
- `V0_4_RELEASE_READINESS.md` defines the release gates;
- `VALIDATION_WORKFLOW.md` defines the canonical reviewed-reference validation
  and CI workflow;
- `PERFORMANCE_BENCHMARKS.md` documents reproducible performance and
  accuracy-versus-work workflows;
- `V0_6_AUTOMATIC_SWITCHING_ROBUSTNESS_DESIGN.md` defines the next
  design-first numerical workstream for scale-aware, auditable automatic
  regularization switching;
- `AUTOMATIC_SWITCHING_POLICY_INVENTORY.md` freezes the AS-0 algebraic
  decision matrix, boundary semantics, reason symbols, and pair conventions;
- AS-1 decisions retain `AutomaticSwitchingDecisionEvidence` so each algebraic
  outcome is auditable without recomputing candidate or pair-competition state;
- AS-2 adds immutable absolute and experimental characteristic-length threshold
  policies while preserving the existing absolute default;
- AS-3 adds explicit immutable switch-progress evidence and an optional same-pair
  re-entry excursion safeguard. Its zero default preserves existing trajectories;
- AS-4a adds immutable quantitative pair-competition evidence while preserving
  all established switching decisions; `V0_6_AS4_PAIR_COMPETITION_DESIGN.md`
  defines the remaining certified-crossing provenance and competition study.
- `CHANGELOG.md` records user-visible changes.

## Licence

ThreeBody3D is released under the MIT License.

See the [`LICENCE`](LICENCE) file for the full licence text.

## Citation

If you use ThreeBody3D in research or published work, please cite the software
using the metadata in [`CITATION.cff`](CITATION.cff). GitHub also exposes this
metadata through its **Cite this repository** feature.

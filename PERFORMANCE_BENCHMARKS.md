# Reproducible performance benchmarks

The repository performance framework records descriptive engineering evidence separately from scientific validation. Performance reports never determine whether a numerical result is scientifically acceptable.

## Registered workloads

The initial production suite contains the ten-period figure-eight and 100-time-unit hierarchical-triple workloads. Each benchmark runs in an isolated Julia child process, performs one warm-up, and retains five post-warm-up samples under `StandardBenchmark()`.

The final V5-V6 accuracy-versus-work series adds two fixed solver profiles for each workload:

- `:fast`
- `:accurate`

Every series point retains the complete numerical configuration, raw timing samples, median elapsed time, accepted and rejected steps, RHS evaluations, saved states, and maximum relative energy drift. The series is ordered descriptive evidence; it does not combine unlike errors into a global score or declare one solver universally superior.

## Run the representative production suite

From the repository root:

```julia
using ThreeBody3D
include(joinpath(pwd(), "examples", "validation", "framework", "ValidationFramework.jl"))
using .ValidationFramework

result = run_performance_suite(
    representative_performance_entries();
    report_directory=joinpath(pwd(), "validation_reports", "performance", "benchmarks"),
    report_path=joinpath(pwd(), "validation_reports", "performance", "suite.toml"),
    suite_id=:representative_performance,
    title="Representative production performance benchmarks",
)
render_performance_suite(result.suite)
```

## Run the production accuracy-versus-work suite

```julia
result = run_performance_suite(
    representative_accuracy_work_entries();
    report_directory=joinpath(pwd(), "validation_reports", "accuracy_work", "benchmarks"),
    report_path=joinpath(pwd(), "validation_reports", "accuracy_work", "suite.toml"),
    suite_id=:production_accuracy_work,
    title="Production accuracy-versus-work benchmarks",
)

figure_series = figure_eight_accuracy_work_series(result.suite)
hierarchy_series = hierarchical_triple_accuracy_work_series(result.suite)
render_accuracy_work_series(figure_series)
println()
render_accuracy_work_series(hierarchy_series)
```

The four child benchmarks execute sequentially. With the default policy, each point performs one warm-up and five retained runs.

## Interpretation

Timing and allocation changes require matching environment metadata and review of raw variability. Solver-work counts are often more portable, but still require matching numerical configuration and software. Accuracy measures remain benchmark-specific and descriptive.

A completed performance benchmark means that the requested evidence was collected. It does not mean that the performance is acceptable, that a change is an improvement or regression, or that scientific validation passed.

Any performance claim requires human review of raw samples, work counts, scientific validation evidence, environment differences, and implementation changes. The framework intentionally defines no approved performance baseline, automatic threshold, regression alarm, or CI failure policy.

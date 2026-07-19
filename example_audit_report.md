# ThreeBody3D example audit

- Date: 2026-07-19 19:25:01 +12:00
- Branch: `v0.4-development`
- Commit: `0b119f3`
- Julia command: `julia --project=.`
- Automatic plot display: suppressed during batch execution

## Standalone execution results

| File | Status | Seconds | Log |
|---|---:|---:|---|
| `examples/analytic_kepler_validation.jl` | PASS | 7.461 | `example_audit_logs/examples_analytic_kepler_validation.jl.log` |
| `examples/automatic_regularization.jl` | PASS | 19.762 | `example_audit_logs/examples_automatic_regularization.jl.log` |
| `examples/close_approach_policies.jl` | PASS | 11.64 | `example_audit_logs/examples_close_approach_policies.jl.log` |
| `examples/composed_regularized_trajectory.jl` | PASS | 14.135 | `example_audit_logs/examples_composed_regularized_trajectory.jl.log` |
| `examples/explicit_regularized_segment.jl` | PASS | 9.779 | `example_audit_logs/examples_explicit_regularized_segment.jl.log` |
| `examples/figure_eight.jl` | PASS | 15.016 | `example_audit_logs/examples_figure_eight.jl.log` |
| `examples/hierarchical_triple.jl` | PASS | 15.032 | `example_audit_logs/examples_hierarchical_triple.jl.log` |
| `examples/high_precision_reference.jl` | PASS | 56.933 | `example_audit_logs/examples_high_precision_reference.jl.log` |
| `examples/levi_civita_fictitious_time.jl` | PASS | 8.751 | `example_audit_logs/examples_levi_civita_fictitious_time.jl.log` |
| `examples/levi_civita_physical_time_target.jl` | PASS | 7.367 | `example_audit_logs/examples_levi_civita_physical_time_target.jl.log` |
| `examples/levi_civita_sundman_time.jl` | PASS | 9.106 | `example_audit_logs/examples_levi_civita_sundman_time.jl.log` |
| `examples/long_duration_switching_validation.jl` | PASS | 16.643 | `example_audit_logs/examples_long_duration_switching_validation.jl.log` |
| `examples/manual_regularized_composition.jl` | PASS | 14.304 | `example_audit_logs/examples_manual_regularized_composition.jl.log` |
| `examples/numerical_validation.jl` | PASS | 28.344 | `example_audit_logs/examples_numerical_validation.jl.log` |
| `examples/perturbed_planar_binary.jl` | PASS | 13.067 | `example_audit_logs/examples_perturbed_planar_binary.jl.log` |
| `examples/perturbed_planar_binary_physical_time.jl` | PASS | 13.323 | `example_audit_logs/examples_perturbed_planar_binary_physical_time.jl.log` |
| `examples/validation/run_validation_suite.jl` | PASS | 175.131 | `example_audit_logs/examples_validation_run_validation_suite.jl.log` |

## Validation support-file coverage

`examples/validation/AcceptanceCriteria.jl` is **NOT STANDALONE**. It is included by the scientific validation cases executed through `examples/validation/run_validation_suite.jl`.

The following validation programs are exercised by the suite:

- `examples/validation/close_encounter_comparison.jl`
- `examples/validation/equilateral_triple_collision_reference.jl`
- `examples/validation/figure_eight_benchmark.jl`
- `examples/validation/hierarchical_triple_benchmark.jl`
- `examples/validation/ks_collision_continuation.jl`
- `examples/validation/ks_hierarchical_triple.jl`
- `examples/validation/ks_kepler_validation.jl`
- `examples/validation/ks_levi_civita_comparison.jl`
- `examples/validation/ks_switching_comparison.jl`
- `examples/validation/randomized_regression_validation.jl`

## Manual graphics checks

These checks require a Windows desktop session with a working OpenGL environment. MP4 recording also requires the bundled or system FFmpeg path to function.

- [ ] `julia --project=. examples/figure_eight.jl` displays a trajectory figure.
- [ ] `julia --project=. examples/hierarchical_triple.jl` displays a trajectory figure.
- [ ] With `THREEBODY3D_ANIMATE=true`, `examples/automatic_regularization.jl` displays and plays an animation.
- [ ] With `THREEBODY3D_RECORD_MP4=true`, `examples/automatic_regularization.jl` writes a playable MP4.
- [ ] `animate_collision_ejection_reference()` works after loading `examples/validation/equilateral_triple_collision_reference.jl` interactively.

## Overall batch status

**PASS** - all standalone batch examples and the complete scientific validation suite exited successfully.

# Changelog

## 0.4.0-DEV

- Added reversible mass-weighted pair-centred coordinates as the first regularization building block.
- Added ordered-pair orientation, third-body metadata, Float64/BigFloat round-trip tests, and the v0.4 regularization design specification.
- No integration equations or existing simulation behaviour changed in Stage 1.

## 0.3.0-DEV

- Added named `:fast`, `:accurate`, and `:extreme` integration profiles.
- Allowed `simulate(...; solver=:profile)` while retaining support for custom
  OrdinaryDiffEq algorithm objects and explicit tolerance overrides.
- Added figure-eight and general periodic-return validation with
  `periodicity_error`.
- Added sampled close-approach reporting with body pair and refined encounter
  time.
- Added continuous close-approach threshold detection during integration with
  `:ignore`, `:warn`, and `:terminate` policies.
- Added `CloseApproachEvent` records to `SimulationResult` and
  `terminated_by_close_approach`.
- Preserved user callbacks by combining them with the close-approach monitor.
- Added reproducible multi-profile conservation benchmarking.
- Replaced the unsuitable Float64 `Feagin14` extreme profile with `Vern9`.
- Added profile-order regression testing.
- Added RHS-evaluation counts and readable benchmark display.
- Documented the precision limit of the published figure-eight constants.
- Added `examples/numerical_validation.jl` and expanded tests/documentation.

## 0.2.0

- Audited baseline with validated state/system construction, conservation
  diagnostics, plotting, animation, MP4 recording, examples, and tests.
- Stored close-approach termination status explicitly instead of inferring it
  from floating-point time equality.
- Added warning-policy and user-callback composition regression tests.
- Added `examples/close_approach_policies.jl`.

### High-precision reference mode

- Redefined `:extreme` as a scoped 256-bit `BigFloat` profile using
  `Vern9()` and `1e-30` tolerances by default.
- Added a warning when ordinary floating-point inputs are promoted, because
  promotion cannot restore digits already lost to Float64 rounding.
- Selected BigFloat `Vern9` as the long-term `:extreme` reference solver after
  local benchmarking showed roughly `1e-32` relative energy drift versus
  `1e-11` to `1e-10` for the tested Feagin methods.
- Retained `benchmark_extreme_solvers` to compare BigFloat `Vern9`, `Feagin12`,
  and `Feagin14` on future problems and SciML versions.
- Added `examples/high_precision_reference.jl` and regression tests for the
  arbitrary-precision path.

## 0.4.0-DEV — Stage 2

- Added a type-generic analytic Kepler reference harness based on universal variables.
- Added elliptic, near-parabolic, hyperbolic, and radial reference propagation.
- Added an independent exact radial free-fall solution and collision-time formula.
- Added Float64 and 256-bit BigFloat validation tests.
- Added `examples/analytic_kepler_validation.jl`.

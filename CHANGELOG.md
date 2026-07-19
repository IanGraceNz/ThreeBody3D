# Changelog

## 0.4.0-DEV

### Stage 1 — Regularization infrastructure

- Documented stable, development, experimental, and internal API tiers in
  `API_STABILITY.md` without changing implementation behaviour.
- Clarified that the production `simulate` interface remains separate from the
  experimental automatic-switching controller.
- Added reversible mass-weighted pair-centred coordinates as the first
  regularization building block.
- Added ordered-pair orientation, third-body metadata, Float64/BigFloat
  round-trip tests, and the v0.4 regularization design specification.
- No integration equations or existing simulation behaviour changed in
  Stage 1.

### Stage 2 — Analytic Kepler reference infrastructure

- Added a type-generic analytic Kepler reference harness based on universal
  variables.
- Added elliptic, near-parabolic, hyperbolic, and radial reference propagation.
- Added an independent exact radial free-fall solution and collision-time
  formula.
- Added Float64 and 256-bit BigFloat validation tests.
- Added `examples/analytic_kepler_validation.jl`.

### Stage 3 — Planar Levi-Civita coordinate maps

- Added the quadratic planar Levi-Civita position map and its physical-time
  velocity Jacobian.
- Added inverse initialization with explicit `±` gauge selection.
- Added collision-limit, sign-equivalence, Float64, and BigFloat tests.
- No regularized equations or integrator switching are introduced in this
  stage.

### Stage 4A — Isolated Levi-Civita dynamics

- Added isolated planar Levi-Civita oscillator integration over fixed
  fictitious time.
- Added exact elliptic, parabolic, and hyperbolic regularized-state propagation.
- Added collision-passage, gauge, Float64, and BigFloat validation.
- Physical-time integration and stopping remain deferred to Stage 4B.

### Stage 4B — Sundman physical-time reconstruction

- Added the exact isolated Levi-Civita physical-time integral.
- Added fixed-fictitious-time numerical integration of `dt/ds = |u|²`.
- Added monotonicity, radial-collision, Kepler-reference, and BigFloat tests.
- No callback or physical-time stopping is included in this stage.

### Stage 4C — Physical-time inversion

- Added bounded inversion of the exact Sundman map from physical time to
  fictitious time.
- Added exact physical-time state queries without ODE callbacks.
- Added forward, backward, radial-collision, and BigFloat validation.

### Stage 5 — Perturbed Levi-Civita propagation

- Added fixed-fictitious-time perturbed planar Levi-Civita integration for one
  explicitly selected binary pair.
- Evolved the binary energy variable, binary centre of mass, third body, and
  physical time together with the regularized pair.
- Added reconstruction to the ordinary 18-element physical state.
- Added short-interval Cartesian cross-validation, collision-regularity checks,
  BigFloat coverage, and a complete example.
- Automatic pair selection, physical-time targeting, and switching remain
  intentionally out of scope.

### Stage 6 — Perturbed planar binary physical-time targeting

- Added callback-free bracket expansion and bisection for locating fictitious
  time from an absolute physical-time target in the perturbed planar
  Levi-Civita solver.
- Added forward, backward, reversed-pair, and BigFloat validation against the
  independent Cartesian three-body solver.

### Stage 7 — Explicit regularized segments

- Added explicit Cartesian → perturbed Levi-Civita → Cartesian segments.
- Added transition diagnostics for state reconstruction and invariant jumps.
- Added segment metadata retaining the regularized problem and solution.
- Added Float64, BigFloat, reversed-pair, shifted-epoch, and
  save-grid-independence tests.

### Stage 7A — Manual multi-segment composition

- Added an explicit Cartesian → Levi-Civita → Cartesian composed trajectory.
- Added unified physical-time sampling and evaluation across all three
  segments.
- Added transition continuity diagnostics and per-segment solver statistics.
- Automatic threshold switching remains intentionally out of scope.
- Fixed manual-composition sampling so dense physical-time interpolation is
  accepted when the fictitious-time bisection bracket has converged; this
  avoids false failures from demanding machine-epsilon accuracy of the
  interpolated Sundman time component.
- Removed an unused duplicate composition source file.

### Spatial KS regularization research infrastructure

- Implemented the fixed KS1 coordinate convention, analytic Jacobians, gauge
  transformations, deterministic inverse lift, velocity maps, and scale-aware
  algebraic diagnostics.
- Added isolated and perturbed KS dynamics with Sundman physical time, coupled
  the selected pair to pair-centred three-body coordinates, and added explicit
  KS regularized segments.
- Integrated KS as a selectable backend of the experimental automatic-switching
  controller without changing the stable production `simulate` API.
- Added Float32, Float64, and BigFloat tests together with exact Kepler, radial
  collision continuation, Levi--Civita cross-validation, hierarchical-triple,
  automatic-switching, and independent high-precision validation benchmarks.
- Retained KS implementation names as internal research infrastructure for the
  first implementation cycle; no stable public KS API is introduced.
- Documented the validated limitation to one selected binary pair at a time.
  Simultaneous triple collision and general multiparticle regularization remain
  outside the implemented scope.

## 0.3.0

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

## 0.2.0

- Audited baseline with validated state/system construction, conservation
  diagnostics, plotting, animation, MP4 recording, examples, and tests.
- Stored close-approach termination status explicitly instead of inferring it
  from floating-point time equality.
- Added warning-policy and user-callback composition regression tests.
- Added `examples/close_approach_policies.jl`.

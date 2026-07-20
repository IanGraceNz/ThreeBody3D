# API stability policy

ThreeBody3D is still under active pre-1.0 development. This document records the
intended stability of its user-facing interfaces so that numerical research can
continue without implying that every exported name has the same compatibility
commitment.

## Stability levels

### Stable public API

These interfaces are the supported entry points for ordinary three-body
simulation, diagnostics, validation, and visualization. Within a minor release
series, changes should preserve documented behaviour unless a correctness issue
requires otherwise.

- System and state construction: `ThreeBodySystem`, `STATE_SIZE`, `statevector`,
  `body_position`, and `velocity`.
- Production integration: `AccuracyProfile`, `accuracy_profile`, `simulate`,
  `SimulationResult`, `CloseApproachEvent`, and
  `terminated_by_close_approach`.
- Physical diagnostics: `center_of_mass`, `center_of_mass_velocity`,
  `linear_momentum`, `angular_momentum`, `kinetic_energy`, `potential_energy`,
  `total_energy`, `minimum_separation`, and `relative_energy_error`.
- Reports and validation: `DiagnosticsReport`, `diagnostics_report`,
  `periodicity_error`, `CloseApproachReport`, `close_approach_report`,
  `SolverBenchmark`, `benchmark_solvers`, `benchmark_extreme_solvers`,
  `ValidationBenchmarkReport`, `validation_benchmark_names`, and
  `run_validation_benchmark`.
- Visualization: `plot_trajectory`, `animate`, and `record_animation`.

"Stable" here means the preferred supported surface of the current development
line; it is not a promise of semantic-versioning compatibility across a future
1.0 boundary.

### Development research API

These interfaces are intentionally public because they support reproducible
regularization research and validation. Their mathematical meaning is expected
to remain recognizable, but constructors, fields, keyword arguments, or return
types may still change before v0.4 is released.

- Pair-centred and Levi-Civita coordinate maps.
- Analytic Kepler and radial free-fall references.
- Isolated and perturbed Levi-Civita propagation.
- Sundman physical-time reconstruction and targeting.
- Explicit regularized segment handoff and manual multi-segment composition.

This level includes the exported names from `PairCoordinates` through
`composed_regularized_state`, together with the Kepler-reference utilities.
Call documented functions rather than depending directly on struct field order
or undocumented internal state.

### Kustaanheimo–Stiefel transformation (KS) research infrastructure

The spatial Kustaanheimo–Stiefel implementation remains internal research
infrastructure for the first implementation cycle. Its transformation,
dynamics, coupled three-body, segment, and validation names are intentionally
not exported from `ThreeBody3D`. They may be accessed by repository tests and
validation programs using qualified internal names, but external users should
not treat those names, constructors, fields, or source paths as an API.

The experimental switching controller may select the validated KS backend with
`regularization_backend=:ks`. That keyword value is covered by the
experimental automatic-switching tier below; it does not make the underlying KS
types stable or public.

### Experimental automatic-switching API

All exported names whose purpose is automatic threshold switching remain
explicitly experimental, including:

- `AutomaticSwitchingParameters` and switching mode types;
- pair-observable and entry/exit decision helpers;
- event-location result types and retained segment types;
- `ExperimentalSwitchingTrajectory`;
- `simulate_experimental_switching`;
- `experimental_switching_state`;
- `ExperimentalSwitchingSamples` and `sample_experimental_switching`;
- `ExperimentalSwitchingDiagnosticsReport`.

These interfaces are scientifically validated for the documented isolated
binary-encounter scope. The Levi-Civita backend is planar; the KS backend is
spatial and still regularizes only the selected pair. They are not yet part of
the production `simulate` API. Names, constructors, fields, thresholds, failure records, and
return structures may change without deprecation while v0.4 remains in
development.

## Internal interfaces

Anything not exported from `ThreeBody3D` is internal unless a document states
otherwise. Internal names may change at any time. Users should not rely on
source-file layout, helper functions, or fields that are absent from the public
documentation.

## Numerical compatibility

API stability does not imply bitwise-identical trajectories. Solver-library
updates, improved event location, corrected tolerances, or stricter validation
may produce small numerical differences. Changes must continue to satisfy the
package tests and the scientific validation suite.

## Deprecation approach

For stable public interfaces, avoid removals or incompatible signature changes
without a documented transition when practical. Development and experimental
interfaces may change directly when required for mathematical correctness or a
cleaner eventual public API; such changes should be recorded in `CHANGELOG.md`.

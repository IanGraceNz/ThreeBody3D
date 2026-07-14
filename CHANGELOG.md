# Changelog

## 0.3.0-DEV

- Added named `:fast`, `:accurate`, and `:extreme` integration profiles.
- Allowed `simulate(...; solver=:profile)` while retaining support for custom
  OrdinaryDiffEq algorithm objects and explicit tolerance overrides.
- Added figure-eight and general periodic-return validation with
  `periodicity_error`.
- Added sampled close-approach reporting with body pair and encounter time.
- Added reproducible multi-profile conservation benchmarking.
- Added `examples/numerical_validation.jl` and expanded tests/documentation.

## 0.2.0

- Audited baseline with validated state/system construction, conservation
  diagnostics, plotting, animation, MP4 recording, examples, and tests.

- Replaced the unsuitable Float64 `Feagin14` extreme profile with `Vern9`.
- Added profile-order regression testing.
- Added RHS-evaluation counts and readable benchmark display.
- Refined close-approach estimates using dense interpolation.
- Documented the precision limit of the published figure-eight constants.

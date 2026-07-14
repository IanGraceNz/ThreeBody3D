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

# ThreeBody3D v0.4 Release-Readiness Plan

**Status:** RP-6 release candidate accepted; release metadata prepared; RP-7 pending
**Target branch:** `v0.4-development`  
**Starting commit:** `724f745`  
**Scope:** Release preparation only; no new mathematics or numerical features

## 1. Purpose

This document defines the remaining verification and release-preparation work
for ThreeBody3D v0.4 after completion of the Levi-Civita and
Kustaanheimo–Stiefel transformation (KS) regularization research programme.

The release-preparation phase shall preserve the project's governing
priorities:

1. scientific correctness above new features;
2. long-term numerical accuracy above speed;
3. clean modular architecture;
4. small, fully tested Git commits;
5. design first for major numerical algorithms;
6. rigorous validation before introducing additional mathematics.

No new regularization method, switching policy, public API, or numerical
optimization belongs in this phase.

## 2. Current validated baseline

At commit `724f745`:

- package tests pass;
- the scientific validation suite passes 11/11 cases;
- Stage KS-13 documentation and API review is complete;
- KS remains internal research infrastructure;
- automatic switching remains experimental;
- the working tree is clean;
- `Project.toml` remains at `0.4.0-DEV`.

This baseline must remain reproducible throughout release preparation.

## 3. Release-preparation stages

### RP-1: Repository and metadata audit

Verify:

- package name, UUID, authorship, version, dependencies, extras, targets, and
  compatibility bounds in `Project.toml`;
- source files are included exactly once and in a deterministic order;
- exported names match `README.md` and `API_STABILITY.md`;
- internal KS names remain unexported;
- repository text files satisfy `git diff --check`;
- no generated files, local paths, temporary diagnostics, or stale duplicate
  sources are tracked.

Acceptance gate:

```text
No metadata defect or source-layout inconsistency remains unresolved.
No numerical behaviour changes.
```

### RP-2: Complete automated verification

Run from a clean checkout:

```powershell
julia --project=. -e "using Pkg; Pkg.instantiate(); Pkg.test()"
julia --project=. examples/validation/run_validation_suite.jl
```

Confirm that the package tests include Aqua and that all scientific validation
cases pass under the release candidate tree.

Record:

- Julia version;
- operating system;
- package-test result;
- validation case count;
- validation elapsed time;
- commit hash tested.

Acceptance gate:

```text
All package tests pass.
All scientific validation cases pass.
The tested commit is identified exactly.
```

### RP-3: Complete example inventory and execution audit

Every Julia program distributed under `examples/` is user-visible and shall be
checked from a clean checkout. A representative subset is not sufficient.
Before execution, generate and retain an inventory with:

```powershell
Get-ChildItem -Recurse examples -Filter *.jl | Sort-Object FullName
```

The audit shall cover all top-level demonstrations:

- `examples/analytic_kepler_validation.jl`;
- `examples/automatic_regularization.jl`;
- `examples/close_approach_policies.jl`;
- `examples/composed_regularized_trajectory.jl`;
- `examples/explicit_regularized_segment.jl`;
- `examples/figure_eight.jl`;
- `examples/hierarchical_triple.jl`;
- `examples/high_precision_reference.jl`;
- `examples/levi_civita_fictitious_time.jl`;
- `examples/levi_civita_physical_time_target.jl`;
- `examples/levi_civita_sundman_time.jl`;
- `examples/long_duration_switching_validation.jl`;
- `examples/manual_regularized_composition.jl`;
- `examples/numerical_validation.jl`;
- `examples/perturbed_planar_binary.jl`;
- `examples/perturbed_planar_binary_physical_time.jl`.

The audit shall also cover every program under `examples/validation/`, either by
running it directly or by proving that it is invoked by
`examples/validation/run_validation_suite.jl`. The inventory currently includes:

- `AcceptanceCriteria.jl`;
- `close_encounter_comparison.jl`;
- `equilateral_triple_collision_reference.jl`;
- `figure_eight_benchmark.jl`;
- `hierarchical_triple_benchmark.jl`;
- `ks_collision_continuation.jl`;
- `ks_hierarchical_triple.jl`;
- `ks_kepler_validation.jl`;
- `ks_levi_civita_comparison.jl`;
- `ks_switching_comparison.jl`;
- `randomized_regression_validation.jl`;
- `run_validation_suite.jl`.

For each file, record one of:

- `PASS`: executes to completion with its documented command;
- `PASS (interactive)`: constructs the expected display or animation and exits
  normally when the display is closed;
- `PASS (optional dependency)`: succeeds when the documented graphics or encoder
  dependency is available;
- `NOT STANDALONE`: a support file intentionally loaded by another checked
  example, with the parent example identified;
- `FAIL`: package, documentation, or example defect requiring correction before
  release.

Every top-level example shall be executed directly with:

```powershell
julia --project=. <example-path>
```

Interactive plotting and animation examples must still be inspected for errors;
they may not be omitted merely because they open a window. MP4 recording shall
be tested where the local graphics environment provides the required encoder.
Environment-only display or encoder failures must be distinguished explicitly
from package defects.

When an example defect is found, stop release preparation and apply the
change-control rule in Section 6: correct it in a separate commit, add or
strengthen regression coverage where practical, and rerun the complete example
inventory.

Acceptance gate:

```text
Every *.jl file under examples/ is accounted for.
Every standalone example executes as written.
Every support file is exercised by an identified passing parent program.
No user-visible example defect remains unresolved.
Optional display or encoder limitations are documented honestly.
```

### RP-4: Fresh-environment installation test

Test outside the development environment using a new temporary Julia project.
The test shall verify at least:

```julia
using Pkg
Pkg.develop(path = raw"<path-to-ThreeBody3D>")
using ThreeBody3D
```

Then construct a system, create an initial state, run `simulate`, compute a
`diagnostics_report`, and create a trajectory plot.

Acceptance gate:

```text
A fresh user can instantiate, load, simulate, diagnose, and visualize without
editing package source files.
```

### RP-5: Documentation and API consistency audit

Cross-check:

- `README.md`;
- `API_STABILITY.md`;
- `CHANGELOG.md`;
- exported docstrings;
- example names and paths;
- regularization limitations;
- experimental-interface warnings.

Requirements:

- do not describe internal KS functions as public;
- do not present automatic switching as part of the production `simulate` API;
- do not claim simultaneous triple-collision or general multiparticle
  regularization;
- do not present benchmark timings as universal performance measurements;
- ensure all commands are reproducible and current.

Acceptance gate:

```text
Documentation matches the release-candidate implementation exactly.
```

### RP-6: Release-candidate version and changelog

Only after RP-1 through RP-5 pass:

- change `Project.toml` from `0.4.0-DEV` to `0.4.0`;
- convert the changelog development heading to the final `0.4.0` release
  heading;
- add the release date;
- make no unrelated source changes in the release commit.

Suggested commit:

```text
Prepare v0.4.0 release
```

Acceptance gate:

```text
The version and changelog describe the exact tested tree.
All tests and the full validation suite pass after the metadata change.
```

### RP-7: Final tag and branch verification

After the release commit is tested and the working tree is clean:

```powershell
git status
git log -5 --oneline
git tag -a v0.4.0 -m "ThreeBody3D v0.4.0"
git show --stat v0.4.0
```

Verify that the tag points to the intended release commit. Tagging shall not be
performed before the user explicitly accepts the final release candidate.

## 4. Required release evidence

Retain a concise release record containing:

- release commit hash;
- tag hash;
- Julia version;
- package-test summary;
- validation-suite summary;
- fresh-environment result;
- example smoke-test result;
- known limitations.

This may be recorded in a continuation or release report without adding
machine-specific output to the package source tree.

## 5. Known release limitations

The v0.4 release documentation must retain these limitations:

- only one selected binary pair is regularized at a time;
- simultaneous triple collision is not regularized;
- general multiparticle regularization is not implemented;
- the automatic-switching API is experimental;
- KS implementation details are internal research infrastructure;
- the production `simulate` interface remains the ordinary Cartesian solver;
- numerical results may vary slightly with solver-library versions while still
  satisfying the scientific acceptance criteria.

## 6. Change-control rule

If any release audit reveals a numerical, mathematical, or API defect:

1. stop release preparation;
2. document the defect;
3. correct it in a separate, narrowly scoped commit;
4. add or strengthen a regression test;
5. rerun package tests and the relevant scientific validation;
6. resume at the failed release-preparation gate.

A release metadata commit shall never conceal a functional correction.

## 7. Immediate next action

The RP-6 release candidate at commit `fcfd55f` passed the complete package test
suite and all 11 scientific validation cases. Release metadata has now been
prepared for v0.4.0.

Rerun the complete package test suite, scientific validation suite, and fresh-
environment validation against the release metadata commit. If all checks pass
and the working tree is clean, proceed to RP-7 only after explicit acceptance
of the final release commit.

# ThreeBody3D Continuation Report

**Report date:** 2 August 2026
**Local time zone:** Pacific/Auckland
**Repository:** `https://github.com/IanGraceNz/ThreeBody3D`
**Local repository path:** `C:\Dev\ThreeBody3D`
**Current branch:** `v0.5-development`

---

## 1. Purpose of This Report

This report records the exact state of the ThreeBody3D project at the end of the current development session.

It is intended to permit development to resume in a new ChatGPT conversation without losing:

* project objectives;
* scientific priorities;
* approved design decisions;
* implementation history;
* validation results;
* Git state;
* the exact point reached in the approved Investigation 2 plan; or
* constraints that must be preserved during the next implementation increment.

At the beginning of the next conversation, upload the then-current repository archive before asking for source inspection or modification.

Do not reconstruct or guess current file contents from this report. The repository itself remains authoritative for implementation details.

---

## 2. Exact Repository State

### 2.1 Current local commit

The latest local commit is:

```text
e968c1d Add conditional figure-eight precision investigation
```

### 2.2 Current remote state

At the time this report was requested:

```text
origin/v0.5-development = 767bba5
local v0.5-development  = e968c1d
```

Therefore, before this continuation report is committed:

* the local branch is one commit ahead of the remote;
* commit `e968c1d` has not yet been pushed;
* the working tree is clean;
* there are no staged changes;
* there are no untracked files.

The reported Git state immediately after committing I2-B3 was:

```text
On branch v0.5-development
Your branch is ahead of 'origin/v0.5-development' by 1 commit.
  (use "git push" to publish your local commits)

nothing to commit, working tree clean
```

### 2.3 Latest commits

The latest commits are:

```text
e968c1d Add conditional figure-eight precision investigation
767bba5 Add core duration and sampling investigations
002fe90 Add core tolerance investigation foundation
a5f6f59 Approve Investigation 2 experimental plan
212465c Add Investigation 1 baseline execution and reporting
10ffc32 Update Continuation Report CONTINUATION_REPORT.md
aa87ff1 Add KS switching Investigation 1 pilot adapter
6ef5489 Add close-encounter Investigation 1 pilot adapter
bff7a94 Add hierarchical-triple Investigation 1 pilot adapter
822f156 Add figure-eight Investigation 1 pilot adapter
dbe61c0 Add Investigation 1 record types
```

### 2.4 Expected Git action after copying this report

After replacing `CONTINUATION_REPORT.md` with this text, the intended commands are:

```powershell
git add CONTINUATION_REPORT.md
git commit -m "Update Continuation Report"
git push
```

That push should publish both:

* `e968c1d Add conditional figure-eight precision investigation`; and
* the new continuation-report commit.

After the push, verify:

```powershell
git status
git log -5 --oneline
```

The expected final state is a clean working tree with local and remote `v0.5-development` synchronized.

---

## 3. Project Purpose and Priorities

ThreeBody3D is a Julia package for solving three-dimensional three-body initial-value problems.

Its primary purpose is to produce increasingly accurate, robust, and scientifically defensible three-body solutions.

The agreed priorities are:

1. **Scientific correctness and acceptability**
2. **Long-term numerical accuracy**
3. **Robust handling of close encounters and singular behaviour**
4. **Ease of use**
5. **Simplicity**
6. **Clean and modular architecture**
7. **Performance where it does not compromise the preceding goals**

Validation, benchmarking, reference records, reporting, and investigation infrastructure are supporting tools rather than the project’s primary purpose.

Infrastructure work is justified only when it helps:

* identify numerical weaknesses;
* distinguish genuine accuracy improvements from attractive diagnostics;
* compare alternative formulations fairly;
* discover better regularisation methods;
* improve the accuracy and quality of physical solutions; or
* avoid implementing changes that are unsupported by evidence.

The governing principle remains:

> Each successive iteration should genuinely improve the accuracy and quality of ThreeBody3D.

“No change” is an acceptable scientific conclusion when controlled evidence does not justify an implementation change.

---

## 4. Development and Review Workflow

### 4.1 Repository inspection

Before modifying files in a new conversation:

* upload the latest repository;
* inspect the real current files;
* read the relevant approved design document;
* determine the next approved stage from that design document;
* do not infer the next stage from this continuation report alone;
* do not reconstruct source files from memory, old patches, excerpts, or previous archives.

### 4.2 Change discipline

Changes should be:

* small;
* design-led;
* scientifically motivated;
* narrowly scoped;
* fully documented;
* covered by focused tests;
* followed by the complete package test suite;
* committed separately by logical increment.

Do not combine unrelated cleanup with scientific implementation work.

### 4.3 Review and Git workflow

Before committing:

```powershell
git diff --check
git status
git diff --stat
git diff
```

After staging:

```powershell
git diff --cached --check
git diff --cached --stat
git diff --cached
```

After committing:

```powershell
git status
git log -5 --oneline
```

The user normally performs all staging, commit, and push operations locally after reviewing the complete diff.

Do not stage, commit, amend, reset, rebase, or push unless expressly instructed.

### 4.4 Test expectations

For a significant validation or investigation increment, run:

* the focused validation-framework suite;
* full `Pkg.test()`;
* affected standalone benchmarks;
* representative direct smoke executions;
* representative process-isolated performance children;
* `git diff --check`.

A syntax check is not a substitute for running the affected benchmark.

### 4.5 Historical commits

Do not amend or alter established historical commits unless expressly instructed.

Earlier instructions specifically required that commit `026b393` not be amended or changed.

---

## 5. Development Environment

The user’s primary environment is:

* Windows;
* PowerShell;
* Visual Studio Code;
* Julia 1.12.5;
* Git command-line tools;
* local path `C:\Dev\ThreeBody3D`.

Typical full test command:

```powershell
julia --project=. -e "using Pkg; Pkg.test()"
```

A known manifest-resolution recommendation may appear during `Pkg.test()`.

It has appeared repeatedly without causing test failure. No dependency files were changed during the recent Investigation 2 increments.

Treat the warning as pre-existing unless its content or consequences change.

---

## 6. Authoritative Design Documents

### 6.1 Investigation 1

The authoritative Investigation 1 design is:

```text
docs/design/V0_6_INVESTIGATION_1_MEASUREMENT_PLAN.md
```

Investigation 1 is complete.

### 6.2 Investigation 2

The authoritative Investigation 2 design is:

```text
docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md
```

It was approved and committed as:

```text
a5f6f59 Approve Investigation 2 experimental plan
```

This document, not this continuation report, determines:

* the scientific hypotheses;
* approved point values;
* fixed controls;
* experimental stages;
* interpretation rules;
* completion criteria;
* prohibited conclusions.

The approved implementation stages are:

```text
I2-A — Experimental-plan approval
I2-B — Core integration experiments
I2-C — Close-encounter decomposition
I2-D — KS backend localisation
I2-E — Explanatory execution and report
```

Stage I2-A is complete.

Work remains within Stage I2-B.

Do not begin I2-C until the remaining I2-B integration work has been reviewed, committed, and published.

---

## 7. Completed Investigation 1 Programme

Investigation 1 established a structured factual baseline without attempting causal explanation.

### 7.1 Record types

Commit:

```text
dbe61c0 Add Investigation 1 record types
```

The validation framework contains immutable records for:

* `InvestigationDefinition`;
* `InvestigationMeasurementPoint`;
* `InvestigationMeasurementSeries`.

These records preserve:

* benchmark identity;
* independent variable;
* fixed controls;
* ordered point identity;
* configuration;
* environment and provenance;
* execution outcome;
* direct metrics;
* solver statistics;
* performance reports;
* optional supporting evidence;
* factual notes.

Unavailable or inapplicable measurements are omitted rather than represented by fabricated zeroes, `NaN`, infinity, or empty numerical sentinels.

### 7.2 Pilot adapters

The four Investigation 1 pilot adapters were completed in:

```text
822f156 Add figure-eight Investigation 1 pilot adapter
bff7a94 Add hierarchical-triple Investigation 1 pilot adapter
6ef5489 Add close-encounter Investigation 1 pilot adapter
aa87ff1 Add KS switching Investigation 1 pilot adapter
```

The pilot regimes are:

1. figure-eight profile comparison;
2. hierarchical-triple profile comparison;
3. close-encounter representation comparison;
4. KS versus Levi-Civita automatic-switching comparison.

### 7.3 Baseline execution and reporting

Stage I1-E was completed in:

```text
212465c Add Investigation 1 baseline execution and reporting
```

The implementation provides:

* deterministic Investigation-series TOML serialization;
* complete KS supporting-evidence serialization;
* process-isolated execution;
* explicit operational-failure retention;
* fixed report filenames;
* atomic output;
* two-execution reproducibility comparison;
* deterministic Markdown baseline reporting;
* separation of measurements and interpretation.

Generated Investigation 1 artifacts are placed under:

```text
validation_reports/investigation_1/
```

The standard files are:

```text
figure_eight_profile.toml
hierarchical_triple_profile.toml
close_encounter_representation.toml
ks_switching_backend.toml
INVESTIGATION_1_BASELINE_REPORT.md
```

The generated directory is ignored by Git.

The final committed-tree regeneration reported:

```text
Reproducibility: PASS
Mismatches: none
```

Timing and garbage-collection timing were excluded from reproducibility equality.

### 7.4 Investigation 1 scientific observations

Investigation 1 identified behaviours requiring causal explanation, including:

* very large profile-dependent differences in invariant drift;
* much smaller changes in some trajectory-specific measurements;
* substantial Cartesian near-periapsis error;
* strong agreement between automatic and explicitly bounded regularised propagation;
* a measurable KS/Levi-Civita physical-state discrepancy despite small event-time and transition residuals.

Investigation 1 did not establish the causes of those behaviours.

That causal work belongs to Investigation 2.

---

## 8. Approved Investigation 2 Hypotheses

The approved hypotheses are recorded in the design document.

Their final wording avoids treating profile names as causal mechanisms.

### H1 — Contributions of integration algorithm and tolerance

The differences observed between the `:fast` and `:accurate` core profiles may arise from:

* the integration algorithms;
* tolerance settings; and
* interactions between algorithm and tolerance.

The experiments must separate those effects using matched algorithms and matched tolerances.

### H2 — Distinct behaviour of trajectory and diagnostic measurements

Trajectory-specific errors and invariant-drift measurements may respond differently to:

* tolerance;
* duration;
* diagnostic sampling.

Improved invariant drift must not automatically be interpreted as proportionally improved trajectory accuracy.

### H3 — Limiting source of figure-eight periodicity error

At sufficiently tight tolerances, figure-eight periodicity error may become limited by:

* the fixed benchmark initial conditions;
* the fixed period value;
* arithmetic precision; or
* another non-integrator source.

The conditional precision experiment is designed to test whether ordinary Float64 integration remains the dominant limitation.

### H4 — Source of Cartesian close-encounter error

The dominant Cartesian close-encounter error may develop during unregularised propagation through the near-periapsis region.

This will be tested in Stage I2-C using reference-defined temporal localisation.

### H5 — Contribution of switching and handoff

For the Investigation 1 close encounter, switching detection and segment handoff may contribute less error than propagation within the regularised representation.

This will be tested using matched automatic and explicit regularised experiments.

### H6 — Origin of the KS and Levi-Civita discrepancy

The KS/Levi-Civita physical-state discrepancy may arise primarily during:

* regularised propagation;
* physical-state reconstruction; or
* dense-output evaluation,

rather than from switching-event timing or transition discontinuity.

This will be tested in Stage I2-D.

No hypothesis is considered established merely because it is stated in the plan.

---

## 9. Stage I2-A — Experimental-Plan Approval

Stage I2-A is complete.

Commit:

```text
a5f6f59 Approve Investigation 2 experimental plan
```

The approved plan freezes:

* target behaviours;
* hypotheses;
* point values;
* fixed controls;
* comparison grids;
* comparison norms and scales;
* precision-safe input construction;
* reference-defined encounter boundaries;
* reconstruction and dense-output definitions;
* interpretation rules;
* completion criteria.

The plan must not be casually edited during implementation.

Any proposed scientific change to it should be reviewed and approved separately.

---

## 10. Stage I2-B Status

Stage I2-B is the current approved stage.

Its required scientific components are:

* matched algorithm-and-tolerance series;
* matched-tolerance algorithm comparisons;
* core duration series;
* diagnostic-sampling series;
* fixed adjacent-tolerance state comparisons;
* the conditional precision trigger;
* precision-safe canonical-input construction.

Three implementation increments have been completed and committed:

```text
I2-B1 — Core tolerance investigation foundation
I2-B2 — Core duration and diagnostic-sampling investigations
I2-B3 — Conditional figure-eight precision confirmation support
```

These labels are useful implementation subdivisions. The approved design document itself defines only the broader Stage I2-B.

---

## 11. I2-B1 — Core Tolerance Investigation Foundation

### 11.1 Commit

```text
002fe90 Add core tolerance investigation foundation
```

### 11.2 Approved tolerance series

I2-B1 defines:

```text
figure_eight_tsit5_tolerance
figure_eight_vern9_tolerance
hierarchical_triple_tsit5_tolerance
hierarchical_triple_vern9_tolerance
```

Each uses the exact ordered tolerances:

```text
1e-9
1e-10
1e-11
1e-12
1e-13
```

The scientific algorithm identity is distinct from the package selector:

```text
:tsit5 → :fast
:vern9 → :accurate
```

The series are not described as profile comparisons.

They record:

* the actual scientific algorithm;
* the internal selector;
* explicit relative and absolute tolerances;
* benchmark duration or period count;
* `saveat`;
* arithmetic type;
* direct metrics;
* solver work;
* retained performance evidence;
* execution outcomes;
* notes.

### 11.3 Direct execution model

I2-B1 introduced:

* immutable parameterised configurations;
* validated direct attempt records;
* completed, terminated, and errored outcomes;
* strict validation against package-owned physical inputs;
* strict Float64 arithmetic validation;
* exact benchmark identity and profile validation;
* exact saved-grid validation;
* factual preservation of failures.

An errored point remains in its declared order without fabricated:

* benchmark metrics;
* trajectories;
* solver statistics.

### 11.4 Adjacent-tolerance comparisons

The comparison pairs are:

```text
1e-9  versus 1e-10
1e-10 versus 1e-11
1e-11 versus 1e-12
1e-12 versus 1e-13
```

The comparison is attached to the looser point.

The `1e-13` point has no adjacent-comparison metrics.

Comparisons use:

```text
L₀ = maximum initial pair separation
V₀ = maximum initial pair-relative speed
```

with an explicit `1` fallback when either scale is exactly zero.

At each shared saved physical time, centre-of-mass position and velocity are removed separately from both solutions.

The retained comparisons are:

```text
maximum_position_difference
maximum_velocity_difference
maximum_scaled_state_difference
final_position_difference
final_velocity_difference
final_scaled_state_difference
```

These are self-convergence differences, not approved-reference errors.

### 11.5 Benchmark execution paths

The package benchmark internals now distinguish:

1. a genuinely report-only path;
2. a lightweight observation path;
3. a trajectory-retaining path.

For I2-B1:

* the report-only path returns `ValidationBenchmarkReport`;
* the trajectory path returns a trajectory-bearing internal execution;
* trajectory copying occurs only when explicitly required;
* the direct Investigation execution receives one owned snapshot;
* the retained performance operation uses the report-only path;
* no extra full trajectory copying is included in retained timing.

Public benchmark return types and defaults remain unchanged.

### 11.6 Precision-safe canonical figure-eight values

I2-B1 added package-owned canonical decimal strings and a scoped BigFloat constructor.

The canonical constructor:

* sets the requested precision before parsing;
* parses decimal strings directly into `BigFloat`;
* does not promote Float64 benchmark values;
* restores the caller’s global precision afterward;
* does not add digits or revise the published benchmark.

This helper later became the basis of I2-B3.

### 11.7 I2-B1 verification

Before commit, the final focused suite reported:

```text
313 I2-B1 assertions passed
```

Also reported successful:

* full `Pkg.test()`;
* standalone figure-eight benchmark;
* standalone hierarchical-triple benchmark;
* four parameterised smoke points;
* `git diff --check`.

---

## 12. I2-B2 — Core Duration and Diagnostic-Sampling Investigations

### 12.1 Commit

```text
767bba5 Add core duration and sampling investigations
```

### 12.2 Approved duration series

#### Figure-eight

```text
series: figure_eight_duration
periods: 1, 2, 5, 10, 20
algorithm: Vern9
selector: :accurate
reltol = abstol = 1e-12
saveat = 0.02
arithmetic = Float64
```

#### Hierarchical triple

```text
series: hierarchical_triple_duration
duration: 25.0, 50.0, 100.0, 200.0
algorithm: Vern9
selector: :accurate
reltol = abstol = 1e-13
saveat = 0.02
arithmetic = Float64
```

### 12.3 Approved diagnostic-sampling series

#### Figure-eight

```text
series: figure_eight_diagnostic_sampling
saveat: 0.1, 0.02, 0.004
periods: 10
algorithm: Vern9
selector: :accurate
reltol = abstol = 1e-12
arithmetic = Float64
```

#### Hierarchical triple

```text
series: hierarchical_triple_diagnostic_sampling
saveat: 0.1, 0.02, 0.004
duration: 100.0
algorithm: Vern9
selector: :accurate
reltol = abstol = 1e-13
arithmetic = Float64
```

### 12.4 Lightweight observation path

I2-B2 added a lightweight package observation retaining:

* the existing `ValidationBenchmarkReport`;
* saved physical times;
* the physical system;
* the initial state.

It does not retain all saved trajectory states.

The path:

* integrates once;
* copies the saved-time vector once;
* copies only the initial state;
* does not construct the I2-B1 trajectory execution;
* does not invoke the complete trajectory snapshot helper.

The report-only and trajectory-retaining paths remain distinct.

### 12.5 Saved-grid convention

A real smoke run exposed a one-bit reconstruction difference.

The validator was corrected to match the actual OrdinaryDiffEq scalar-`saveat` convention:

* retain the initial time;
* construct requested entries from `saveat:saveat:final_time`;
* retain or append the exact final endpoint as required.

The validator rejects:

* wrong spacing;
* duplicated times;
* omitted times;
* reordered times;
* extra times;
* incorrect initial or final time;
* nonfinite time values.

### 12.6 Truthful parameterised case definitions

I2-B2 introduced truthful Investigation 2 case definitions:

```text
:figure_eight_parameterized
:hierarchical_triple_parameterized
```

They do not falsely claim that every duration point uses:

* ten figure-eight periods; or
* one fixed hierarchical-triple duration.

They use the approved Investigation 2 plan as provenance.

The existing Investigation 1 case definitions remain unchanged and are regression-tested field by field.

### 12.7 Attempt and note integrity

Both I2-B1 and I2-B2 attempts now require a factual execution summary when no direct evidence exists.

Point-note construction:

* preserves direct execution summaries;
* preserves additional notes;
* avoids duplicating identical text;
* labels direct and performance failures separately.

### 12.8 Performance infrastructure

I2-B2 uses one parameterised process child:

```text
examples/validation/performance/core_duration_sampling_work.jl
```

Performance IDs are stable and encode:

* experiment kind;
* benchmark family;
* algorithm;
* point value.

The timed operation uses:

```julia
configuration.solver_selector
```

rather than a hard-coded selector.

The operation remains report-only and does not copy:

* saved-time vectors;
* saved-state trajectories;
* Investigation records.

### 12.9 I2-B2 verification

Final reported focused results were:

```text
Definitions/configurations: 47/47
Observation boundaries:     18/18
Direct validation/grids:    32/32
Attempt invariants:         10/10
Performance contracts:      27/27
Series/serialization:      236/236
```

Also reported successful:

* full `Pkg.test()`;
* standalone figure-eight benchmark;
* standalone hierarchical-triple benchmark;
* four direct I2-B2 smoke points;
* duration performance-child smoke;
* diagnostic-sampling performance-child smoke;
* `git diff --check`.

Representative direct smoke results were:

```text
Figure-eight, periods 1:
    saved states: 318
    accepted: 112
    rejected: 0
    RHS: 1794

Hierarchical triple, duration 25.0:
    saved states: 1251
    accepted: 296
    rejected: 0
    RHS: 4738

Figure-eight, saveat 0.1:
    saved states: 634
    accepted: 1088
    rejected: 0
    RHS: 17410

Hierarchical triple, saveat 0.1:
    saved states: 1001
    accepted: 1168
    rejected: 0
    RHS: 18690
```

---

## 13. I2-B3 — Conditional Figure-Eight Precision Confirmation

### 13.1 Commit

```text
e968c1d Add conditional figure-eight precision investigation
```

This commit is currently local and must be pushed together with the continuation-report commit.

### 13.2 Trigger source

The trigger accepts only the exact approved source series:

```text
figure_eight_vern9_tolerance
```

It uses the exact points:

```text
1e-12
1e-13
```

and exact metrics:

```text
periodicity_error
maximum_relative_energy_drift
```

The trigger validates:

* exact series identity;
* exact definition;
* exact point IDs;
* exact independent values and order;
* exact approved configurations;
* complete direct metrics;
* `integration_status = :completed`;
* solver statistics;
* complete performance-report contracts;
* common environment.

### 13.3 Direct versus performance failure

The trigger requires completed direct numerical evidence.

It does not evaluate from:

* a terminated direct integration;
* an errored direct integration;
* missing direct metrics;
* missing solver statistics;
* manually inconsistent direct evidence.

A genuine performance-only failure remains scientifically evaluable when:

* direct numerical execution completed;
* all direct metrics exist;
* solver statistics exist;
* only retained performance measurement failed.

The source point’s combined execution outcome remains retained in the trigger assessment.

### 13.4 Trigger mathematics

Let:

```text
p12 = periodicity error at 1e-12
p13 = periodicity error at 1e-13

e12 = maximum relative energy drift at 1e-12
e13 = maximum relative energy drift at 1e-13
```

#### Periodicity condition

The periodicity error changes by less than a factor of two when:

```text
max(p12, p13) < 2 * min(p12, p13)
```

The comparison is strict.

Special cases:

* if both periodicity errors are zero, the factor is `1` and the condition is true;
* if exactly one is zero, the condition is false and no finite factor is retained.

#### Energy condition

The tighter tolerance improves energy drift by at least a factor of ten when:

```text
e12 >= 10 * e13
```

and:

```text
e12 > 0
```

This condition is directional.

A tenfold worsening does not trigger the experiment.

Special cases:

* if `e12 > 0` and `e13 == 0`, the improvement is retained as unbounded without serializing infinity;
* if both are zero, the condition is false because no measured positive drift was improved tenfold.

### 13.5 Trigger statuses

The immutable trigger assessment uses:

```text
:triggered
:not_triggered
:unavailable
```

The status is:

```text
:triggered
```

only when both conditions are available and true.

It is:

```text
:not_triggered
```

when both conditions are available and at least one is false.

It is:

```text
:unavailable
```

when either condition cannot be evaluated from completed direct evidence.

Unavailable is not treated as false.

### 13.6 Trigger-record invariants

One shared mathematical derivation governs:

* trigger evaluation;
* trigger-record construction;
* TOML deserialization.

The constructor and reader reject inconsistent combinations involving:

* source identity;
* source point IDs;
* factors;
* conditions;
* unbounded flags;
* statuses;
* absent values;
* retained optional values.

A manually constructed or edited report cannot claim `:triggered` while retaining inconsistent measurements or false conditions.

### 13.7 Trigger serialization

The trigger assessment is a separate retained record rather than an artificial zero-point Investigation series.

I2-B3 added deterministic operations for:

* writing a trigger assessment;
* producing deterministic TOML text;
* reading the assessment;
* atomic file writing.

The serializer:

* preserves schema identity;
* preserves the source environment;
* preserves source point outcomes;
* preserves optional values explicitly;
* does not serialize `NaN` or infinity;
* rejects malformed records.

### 13.8 Precision configurations

The approved precision series is:

```text
figure_eight_precision_confirmation
```

with points:

```text
128
256
384
```

The independent variable is:

```text
:precision_bits
```

Each point uses:

```text
scientific algorithm: Vern9
internal selector: :extreme
periods: 10
reltol = abstol = 1e-30
saveat = 0.02
arithmetic: BigFloat
```

The term `:extreme` is the internal package selector. It is not treated as the scientific algorithm identity.

### 13.9 Canonical BigFloat construction

All precision-experiment inputs are constructed directly from package-owned canonical decimal strings inside the requested precision scope.

The canonical record includes:

* masses;
* gravitational constant;
* all initial positions;
* all initial velocities;
* initial time;
* period;
* tolerance text;
* `saveat` text.

The implementation does not:

* promote Float64 benchmark inputs;
* add digits;
* fit corrected values;
* use external initial conditions;
* revise the figure-eight period.

The caller’s BigFloat precision is restored after construction and execution.

### 13.10 Precision benchmark paths

The package provides separate internal paths for:

#### Report-only precision execution

Returns:

```text
ValidationBenchmarkReport
```

It is used for retained performance timing.

It does not copy saved times or states.

#### Lightweight precision observation

Retains:

* the report;
* saved BigFloat times;
* the physical system;
* the initial state;
* precision identity.

It:

* copies saved times once;
* copies only the initial state;
* does not retain the complete trajectory;
* does not construct the I2-B1 trajectory execution.

The observation’s declared `precision_bits` is preserved and validated.

### 13.11 Direct precision validation

Direct precision evidence is checked against:

* exact family;
* exact `:extreme` report profile;
* exact canonical physical inputs;
* exact BigFloat precision;
* exact tolerances;
* exact period count;
* exact final time;
* exact `saveat`;
* exact BigFloat saved-time grid;
* supported completion status;
* solver statistics;
* finite nonnegative diagnostics.

Float64, promoted Float64, wrong-precision, malformed, or nonfinite evidence is rejected.

Direct Investigation metrics remain BigFloat and are not converted to Float64.

### 13.12 Precision performance evidence

Stable performance IDs are:

```text
figure_eight_precision_128
figure_eight_precision_256
figure_eight_precision_384
```

The performance child is:

```text
examples/validation/performance/figure_eight_precision_work.jl
```

It uses:

* process isolation;
* `StandardBenchmark`;
* the report-only precision benchmark path.

Every retained performance sample must contain exactly:

```text
maximum_relative_energy_drift
minimum_pair_separation
```

Both values must be:

* finite;
* nonnegative;
* BigFloat;
* at the declared precision.

Float64, wrong-precision, missing, duplicate, additional, or nonfinite deterministic measurements are rejected.

Timing remains descriptive Float64 evidence.

### 13.13 Precision-series construction

The series builder requires a valid `:triggered` assessment.

It rejects:

```text
:not_triggered
:unavailable
```

It does not fabricate an empty precision series.

All three declared precision points remain ordered even when a direct or performance point fails.

Direct failure takes precedence over performance failure.

Only completed direct and performance evidence produces a completed combined point.

### 13.14 I2-B3 verification

Final reported focused results included:

```text
Trigger contract:                  25/25
Trigger serialization:             20/20
Evidence validation:               19/19
Performance/series serialization:  79/79
```

Also reported successful:

* complete focused framework suite;
* full `Pkg.test()`;
* standalone figure-eight benchmark;
* standalone hierarchical-triple benchmark;
* triggered fixture;
* not-triggered fixture;
* unavailable fixture;
* genuine performance-only-failure fixture;
* direct-failure fixture;
* real 128-bit direct precision run;
* process-isolated 128-bit performance run;
* `git diff --check`.

The real 128-bit direct run completed with:

```text
saved states:   3164
accepted steps: 105667
precision:      128 bits
```

It used:

* canonical BigFloat inputs;
* Vern9 through `:extreme`;
* ten periods;
* `1e-30` tolerances;
* `0.02` sampling.

No Float64-promotion warning occurred.

The caller’s BigFloat precision was restored afterward.

The process-isolated 128-bit performance child completed with:

```text
five retained samples
exit code zero
```

Both deterministic sample measurements retained 128-bit BigFloat values.

---

## 14. Current Benchmark Baselines

The unchanged standalone benchmarks continued to pass after I2-B3.

### Figure-eight accurate baseline

Reported after final I2-B3 verification:

```text
final time:       63.2591398
saved states:     3164
accepted steps:   1088
periodicity error:
    3.504220230353128e-7
```

### Hierarchical-triple accurate baseline

Reported after final I2-B3 verification:

```text
final time:      100.0
saved states:    5001
accepted steps:  1168
```

These values remain regression baselines. Their continued appearance does not constitute Investigation 2 interpretation.

---

## 15. Important Current Files

### Approved plans

```text
docs/design/V0_6_INVESTIGATION_1_MEASUREMENT_PLAN.md
docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md
```

### Investigation framework

```text
examples/validation/framework/InvestigationTypes.jl
examples/validation/framework/InvestigationSerialization.jl
examples/validation/framework/InvestigationBaselineRunner.jl
examples/validation/framework/InvestigationPresentation.jl
examples/validation/framework/ValidationFramework.jl
```

### I2-B1

```text
examples/validation/framework/CoreToleranceInvestigation.jl
examples/validation/performance/core_tolerance_accuracy_work.jl
test/validation_framework/core_tolerance_investigation.jl
```

### I2-B2

```text
examples/validation/framework/CoreDurationSamplingInvestigation.jl
examples/validation/performance/core_duration_sampling_work.jl
test/validation_framework/core_duration_sampling_investigation.jl
```

### I2-B3

```text
examples/validation/framework/FigureEightPrecisionInvestigation.jl
examples/validation/framework/PrecisionTriggerSerialization.jl
examples/validation/performance/figure_eight_precision_work.jl
test/validation_framework/figure_eight_precision_investigation.jl
```

### Package benchmark internals

```text
src/ValidationBenchmarks/FigureEight.jl
src/ValidationBenchmarks/HierarchicalTriple.jl
src/ValidationBenchmarks/Reports.jl
src/ValidationBenchmarks/ValidationBenchmarks.jl
```

### Test entry

```text
test/validation_framework/runtests.jl
```

---

## 16. Architectural Invariants That Must Be Preserved

### 16.1 Algorithm identity and package selector

The scientific algorithm and package selector are distinct:

```text
Tsit5  → :fast
Vern9  → :accurate
Vern9 BigFloat → :extreme
```

Do not report `:fast`, `:accurate`, or `:extreme` as though they were scientific algorithms.

### 16.2 Benchmark paths

The package now intentionally distinguishes:

* report-only execution;
* lightweight observation;
* full trajectory snapshot.

Do not collapse them into one path that copies unnecessary data.

Performance measurement must use report-only execution.

### 16.3 No fabricated unavailable values

Unavailable or inapplicable evidence must not be represented as:

* zero;
* `NaN`;
* infinity;
* empty numerical fields;
* invented metrics.

Omit unavailable optional metrics and retain factual execution evidence.

### 16.4 State accuracy and invariant drift

Do not combine:

* state error;
* periodicity error;
* hierarchy measurements;
* invariant drift;
* minimum separation;
* solver work

into a synthetic score.

Improved invariant drift is not automatically improved trajectory accuracy.

### 16.5 Minimum sampled separation

Minimum sampled separation is not periapsis error.

Do not use the terms interchangeably.

### 16.6 BigFloat input construction

For the precision experiment:

* parse canonical strings inside the requested precision scope;
* do not promote Float64 inputs;
* do not revise the canonical period;
* do not add digits;
* do not source alternative initial conditions.

### 16.7 Trigger evidence

The precision trigger requires completed direct numerical evidence.

A performance-only failure may remain evaluable.

A direct failure makes the trigger unavailable.

Unavailable must not be converted into not triggered.

### 16.8 Interpretation boundaries

Stage I2-B records measurements and controlled configurations.

It does not establish causal conclusions.

Do not claim:

* a periodicity floor;
* secular growth;
* an algorithmic cause;
* a sampling-based accuracy improvement;
* superiority of a production profile;
* a need to change a solver

until the complete Investigation 2 evidence is evaluated under the approved interpretation rules.

---

## 17. Current Stage and Exact Next Work

### 17.1 Current formal stage

The project remains in:

```text
Stage I2-B — Core integration experiments
```

I2-B1, I2-B2, and I2-B3 are implemented and committed.

However, Stage I2-B should not yet be treated as fully complete.

The definitions, adapters, validation, performance children, trigger assessment, and conditional precision-series support now exist, but the components have not yet been integrated into one controlled core-experiment orchestration workflow.

### 17.2 Recommended next implementation increment

A useful working label is:

```text
I2-B4 — Controlled core-experiment orchestration
```

This is an implementation subdivision for planning convenience. It is not a separate stage named in the approved design document.

The next increment should integrate the existing I2-B1, I2-B2, and I2-B3 components without changing their scientific definitions.

### 17.3 Required orchestration scope

The runner or workflow should be capable of constructing the following eight mandatory core series:

```text
figure_eight_tsit5_tolerance
figure_eight_vern9_tolerance
hierarchical_triple_tsit5_tolerance
hierarchical_triple_vern9_tolerance

figure_eight_duration
hierarchical_triple_duration

figure_eight_diagnostic_sampling
hierarchical_triple_diagnostic_sampling
```

The mandatory nonprecision point count is:

```text
20 tolerance points
 9 duration points
 6 diagnostic-sampling points
--------------------------------
35 mandatory core points
```

After constructing the figure-eight Vern9 tolerance series, the workflow must evaluate and retain the precision trigger assessment.

If the assessment is:

```text
:triggered
```

the workflow should be capable of constructing:

```text
figure_eight_precision_confirmation
```

with points:

```text
128
256
384
```

If the assessment is:

```text
:not_triggered
```

or:

```text
:unavailable
```

the workflow must retain the assessment and must not fabricate a precision series.

### 17.4 Recommended runner responsibilities

The next workflow should:

* use the existing approved series factories;
* use process-isolated performance children;
* preserve declared point order;
* continue after individual safe failures;
* retain all factual partial evidence;
* retain actual child exit codes;
* validate report contracts before accepting them;
* use one common parent environment where required;
* atomically write deterministic machine-readable records;
* use fixed output filenames;
* prevent untrusted child IDs from controlling output paths;
* preserve raw malformed or partial evidence separately;
* avoid rerunning a numerical integration merely to build records.

### 17.5 Output location

The approved Investigation 2 plan places machine-readable outputs under:

```text
validation_reports/investigation_2/
```

The full explanatory report belongs to Stage I2-E:

```text
validation_reports/investigation_2/INVESTIGATION_2_EXPLANATORY_REPORT.md
```

The next Stage I2-B orchestration increment must not create causal interpretation or the final explanatory report.

It may create deterministic development or core-series machine-readable outputs if required by the approved workflow, but their purpose and relationship to Stage I2-E must remain clear.

### 17.6 Testing expectations for the next increment

Use injected or synthetic child runners for ordinary orchestration tests.

Unit tests should cover:

* stable series order;
* stable point order;
* exact output filenames;
* direct child failure;
* performance child failure;
* missing report;
* malformed report;
* partial evidence preservation;
* continuation to later safe points;
* trigger evaluation after source-series construction;
* triggered precision path;
* not-triggered path;
* unavailable path;
* raw operational-evidence preservation;
* deterministic serialization;
* nonzero workflow exit status when operational failures occur.

Do not run all 35 mandatory core points in the ordinary package test suite.

### 17.7 Execution boundary

The approved Stage I2-E says:

> Execute all approved series twice, preserve deterministic records, evaluate the registered hypotheses, and produce the Investigation 2 explanatory report.

Therefore, the next I2-B orchestration increment should not silently expand into the complete two-execution Investigation 2 programme.

Unless expressly approved otherwise, it should:

* implement and test the orchestration;
* use synthetic and limited smoke execution;
* stop before full Investigation 2 causal analysis;
* stop before I2-C;
* stop before the explanatory report.

---

## 18. Work Explicitly Deferred

The following work has not begun and must remain deferred until its approved stage.

### Stage I2-C

Do not yet implement:

* Cartesian close-encounter tolerance series;
* reference-defined temporal error localisation;
* automatic regularised tolerance series;
* explicit regularised tolerance series;
* close-encounter threshold-scale series.

### Stage I2-D

Do not yet implement:

* KS regularised-tolerance series;
* KS/Levi-Civita threshold-scale series;
* segment-localised backend discrepancy;
* reconstruction-consistency evidence;
* dense-output consistency evidence.

### Stage I2-E

Do not yet:

* execute the complete Investigation 2 programme twice;
* classify the hypotheses;
* produce the explanatory report;
* transfer candidate improvements to Investigation 3.

### Investigation 3

Do not implement:

* solver changes;
* profile changes;
* production threshold changes;
* new regularisation algorithms;
* revised canonical benchmark data;
* candidate numerical improvements.

Investigation 2 must explain the evidence before Investigation 3 evaluates changes.

---

## 19. Suggested Opening Instruction for the Next Conversation

A suitable opening request is:

```text
Continue with the ThreeBody3D project.

The current repository is attached.

1. Read CONTINUATION_REPORT.md.
2. Read docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md.
3. Determine the current approved stage directly from the Investigation 2 plan.
4. Verify the Git state.
5. Review the committed I2-B1, I2-B2, and I2-B3 implementations.
6. Design the smallest next increment needed to integrate the approved core experiments into a controlled orchestration workflow.
7. Do not implement I2-C, causal interpretation, or the Investigation 2 explanatory report.
```

Before changing code, the next conversation should inspect the real current contents of:

```text
examples/validation/framework/CoreToleranceInvestigation.jl
examples/validation/framework/CoreDurationSamplingInvestigation.jl
examples/validation/framework/FigureEightPrecisionInvestigation.jl
examples/validation/framework/PrecisionTriggerSerialization.jl
examples/validation/framework/PerformanceRunner.jl
examples/validation/framework/InvestigationSerialization.jl
examples/validation/framework/InvestigationBaselineRunner.jl
examples/validation/framework/ValidationFramework.jl

examples/validation/performance/core_tolerance_accuracy_work.jl
examples/validation/performance/core_duration_sampling_work.jl
examples/validation/performance/figure_eight_precision_work.jl

src/ValidationBenchmarks/FigureEight.jl
src/ValidationBenchmarks/HierarchicalTriple.jl
src/ValidationBenchmarks/Reports.jl
src/ValidationBenchmarks/ValidationBenchmarks.jl

test/validation_framework/core_tolerance_investigation.jl
test/validation_framework/core_duration_sampling_investigation.jl
test/validation_framework/figure_eight_precision_investigation.jl
test/validation_framework/investigation_baseline_runner.jl
test/validation_framework/runtests.jl
```

---

## 20. Final Handoff Summary

At the end of this session:

* Investigation 1 is complete.
* The Investigation 1 baseline is reproducible.
* The Investigation 2 experimental plan is approved.
* Stage I2-A is complete.
* I2-B1 is complete, committed, and pushed.
* I2-B2 is complete, committed, and pushed.
* I2-B3 is complete and committed locally.
* The working tree is clean.
* Commit `e968c1d` still needs to be pushed.
* This continuation report should be committed and pushed with it.
* The project remains within Stage I2-B.
* The next work is controlled orchestration of the existing core experiment components.
* Close-encounter decomposition, KS localisation, causal interpretation, and numerical improvements remain deferred.

The next conversation must use the newly uploaded repository as the implementation authority and the approved Investigation 2 plan as the stage authority.

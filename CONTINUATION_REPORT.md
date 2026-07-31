# ThreeBody3D Continuation Report

**Report date:** 1 August 2026
**Local time zone:** Pacific/Auckland
**Repository:** `https://github.com/IanGraceNz/ThreeBody3D`
**Local repository path:** `C:\Dev\ThreeBody3D`
**Current branch:** `v0.5-development`

---

## 1. Purpose of This Report

This report records the exact state of the ThreeBody3D project at the end of the current development session. It is intended to permit work to resume in a new ChatGPT conversation without losing project context, design intent, implementation history, validation results, or the current Git checkpoint.

The current repository should be uploaded at the beginning of the next conversation before any file is inspected or modified. Do not reconstruct or guess current file contents from this report.

---

## 2. Current Repository State

The latest commit is:

```text
aa87ff1 Add KS switching Investigation 1 pilot adapter
```

The latest branch state reported by Git is:

```text
On branch v0.5-development
Your branch is up to date with 'origin/v0.5-development'.

nothing to commit, working tree clean
```

The latest five commits are:

```text
aa87ff1 Add KS switching Investigation 1 pilot adapter
6ef5489 Add close-encounter Investigation 1 pilot adapter
bff7a94 Add hierarchical-triple Investigation 1 pilot adapter
822f156 Add figure-eight Investigation 1 pilot adapter
dbe61c0 Add Investigation 1 record types
```

Commit `aa87ff1` has been pushed successfully:

```text
6ef5489..aa87ff1  v0.5-development -> v0.5-development
```

Therefore:

* local `HEAD` and `origin/v0.5-development` both point to `aa87ff1`;
* the working tree is clean;
* there are no staged or unstaged changes;
* there are no untracked files;
* there is no outstanding commit or push.

---

## 3. Project Purpose and Priorities

ThreeBody3D is a Julia package for solving three-dimensional three-body initial-value problems.

The project’s primary purpose is to produce increasingly accurate, robust, and scientifically defensible three-body solutions.

The agreed priorities are:

1. **Scientific correctness and acceptability**
2. **Long-term numerical accuracy**
3. **Robust handling of close encounters and singular behaviour**
4. **Ease of use**
5. **Simplicity**
6. **Clean, modular architecture**
7. **Performance only where it does not compromise the preceding goals**

Validation, benchmarking, baseline approval, reporting, and investigation infrastructure are supporting tools. They are justified only insofar as they help:

* discover better regularization methods;
* expose numerical weaknesses;
* compare alternative formulations truthfully;
* improve solution accuracy and quality.

The project should not become primarily an infrastructure project.

The governing principle remains:

> Each successive iteration should genuinely improve the accuracy and quality of ThreeBody3D.

---

## 4. Development and Review Workflow

The established workflow should continue.

### 4.1 File handling

Before inspecting or modifying code in a new conversation:

* request or use the current repository archive uploaded by the user;
* inspect the real files;
* do not reconstruct files from memory, excerpts, old diffs, or this report;
* do not assume an earlier repository archive is still current.

### 4.2 Change discipline

Changes should be:

* small;
* design-led;
* scientifically motivated;
* fully documented;
* covered by focused unit tests;
* followed by the full package test suite;
* committed separately by logical stage.

Before committing:

```powershell
git diff --check
git diff --stat
git diff
```

After staging:

```powershell
git diff --cached --check
git diff --cached --stat
```

After committing:

```powershell
git status
git log -5 --oneline
```

The user normally performs Git commands locally after reviewing the complete diff.

### 4.3 Validation expectations

For significant validation or benchmark adapters, run:

* focused validation-framework tests;
* full `Pkg.test()`;
* the complete affected standalone benchmark, not merely a syntax check;
* `git diff --check`.

Successful syntax parsing is not a substitute for executing a benchmark.

### 4.4 Commit history

Do not amend or alter established historical commits unless expressly instructed.

In particular, earlier instructions required that commit `026b393` not be amended or altered.

---

## 5. Development Environment

The user works primarily with:

* Windows;
* PowerShell;
* Visual Studio Code;
* Julia 1.12.5;
* Git command-line tools;
* repository path `C:\Dev\ThreeBody3D`.

Typical package test command:

```powershell
julia --project=. -e "using Pkg; Pkg.test()"
```

A recurring manifest-resolution warning appears during the full package test. It is already known. The package test nevertheless completes successfully with the ThreeBody3D tests passing.

This warning should not be treated as a newly introduced failure unless its behaviour changes.

---

## 6. Current Investigation 1 Design Basis

The relevant design document is:

```text
docs/design/V0_6_INVESTIGATION_1_MEASUREMENT_PLAN.md
```

The Investigation 1 implementation has been developed in four pilot regimes:

1. Figure-eight
2. Hierarchical triple
3. Close encounter
4. KS/Levi-Civita automatic-switching comparison

The Investigation 1 work is structured around immutable records representing:

* an investigation definition;
* one measurement point;
* an explicitly ordered measurement series.

Each measurement point may retain:

* controlled configuration;
* environment and provenance;
* execution outcome;
* metrics;
* solver statistics;
* performance measurements;
* experiment-specific supporting evidence.

The implementation deliberately distinguishes:

* execution failure;
* acceptance failure;
* unavailable evidence;
* not-applicable evidence;
* successful measurements.

Unavailable or inapplicable measurements must not be represented with fabricated zeroes, infinities, `NaN`, or other numerical sentinels.

---

## 7. Investigation 1 Record Types

### Commit

```text
dbe61c0 Add Investigation 1 record types
```

### Main types

The validation framework now contains immutable types representing:

* `InvestigationDefinition`
* `InvestigationMeasurementPoint`
* `InvestigationMeasurementSeries`

The records enforce:

* benchmark identity and version;
* one declared independent variable;
* fixed controls;
* required and optional metric identifiers;
* deterministic point ordering;
* configuration and provenance consistency;
* completed-point evidence requirements;
* factual retention of unsuccessful attempts.

### Supporting evidence extension

Commit `aa87ff1` extended `InvestigationMeasurementPoint` with:

```julia
supporting_evidence
```

This permits an immutable experiment-specific report to remain attached to a measurement point when generic metrics and solver statistics cannot represent all raw observations.

This was required for the KS switching pilot so that the resulting series retains structural access to:

* sampled states and times;
* switch events;
* decisions;
* competition evidence;
* progress evidence;
* crossing observations;
* backend execution records.

The generic field is currently typed as `Any` so experiment-specific immutable report types can be retained without changing the common record for every experiment.

---

## 8. Figure-Eight Investigation Pilot

### Commit

```text
822f156 Add figure-eight Investigation 1 pilot adapter
```

### Experiment

The figure-eight pilot compares the existing solver profiles:

```text
:fast
:accurate
```

The experiment uses:

* the existing figure-eight benchmark;
* ten periods;
* `saveat = 0.02`;
* explicitly ordered points;
* existing accuracy and performance infrastructure.

### Retained evidence

The adapter retains applicable evidence including:

* periodicity error;
* maximum relative energy drift;
* linear momentum drift;
* angular momentum drift;
* centre-of-mass residual;
* minimum pair separation;
* solver statistics;
* full performance report;
* retained raw timing samples;
* configuration;
* environment;
* provenance;
* execution outcome.

### Important implementation note

Some helpers used by later adapters are currently located physically in:

```text
examples/validation/framework/FigureEightInvestigation.jl
```

These include helpers such as:

```text
_parameter_value
_retained_solver_statistics
_investigation_execution
_investigation_notes
_performance_reports_by_id
```

This is not a current correctness problem, but a future maintainability cleanup may move shared helpers into a neutral support file.

Do not perform that refactor casually or as part of unrelated scientific work.

---

## 9. Hierarchical-Triple Investigation Pilot

### Commit

```text
bff7a94 Add hierarchical-triple Investigation 1 pilot adapter
```

### Experiment

The hierarchical-triple pilot compares:

```text
:fast
:accurate
```

The fixed experiment uses:

* duration `100.0`;
* `saveat = 0.02`;
* the existing hierarchical-triple benchmark and performance records;
* deterministic order: fast, then accurate.

### Solver-profile fidelity

An important issue was corrected before committing.

The shared profile rule is:

```julia
:fast     => reltol=nothing, abstol=nothing
:accurate => reltol=1e-13, abstol=1e-13
```

This ensures that:

* the fast profile truthfully uses its profile defaults;
* the accurate profile truthfully records explicit tolerance overrides;
* execution and structured result construction use the same values;
* partial tolerance pairs are rejected.

### Retained evidence

The adapter retains:

* minimum hierarchy ratio;
* maximum relative energy drift;
* maximum linear momentum drift;
* maximum angular momentum drift;
* maximum centre-of-mass residual;
* minimum pair separation;
* solver statistics;
* performance report and raw timing observations;
* configuration;
* provenance;
* execution status;
* notes.

Complete evidence is required for completed points. Partial evidence remains retainable for unsuccessful points.

---

## 10. Close-Encounter Investigation Pilot

### Commit

```text
6ef5489 Add close-encounter Investigation 1 pilot adapter
```

### Independent variable and order

The close-encounter series uses:

```text
:representation_mode
```

with explicit order:

1. `:cartesian`
2. `:automatic_switching`
3. `:explicit_regularized`

### Experiment characteristics

The adapter reuses the existing close-encounter comparison benchmark and its independent BigFloat Cartesian reference.

The configuration records the complete controlled experiment, including:

* masses;
* gravitational constant;
* initial state;
* apoapsis;
* nominal periapsis;
* third-body offset;
* selected pair;
* time interval;
* sampling;
* Cartesian tolerances;
* regularized tolerances;
* evaluation tolerance;
* switching thresholds;
* ambiguity threshold;
* minimum separation ratio;
* maximum switches;
* regularized initial step;
* maximum regularized iterations;
* evaluation iterations;
* BigFloat precision;
* reference tolerance;
* reference solver and dense-output settings;
* existing acceptance limits.

### Retained evidence

Each applicable point retains:

* integration status;
* final-time residual;
* maximum position error;
* maximum velocity error;
* maximum combined state error;
* final position error;
* final velocity error;
* final state error;
* maximum relative energy drift;
* linear momentum drift;
* angular momentum drift;
* centre-of-mass residual;
* minimum sampled pair separation;
* periapsis time error;
* periapsis separation error;
* solver work;
* elapsed time;
* segment count;
* switch count;
* configuration;
* environment;
* provenance;
* execution status.

Transition-state residual is optional:

* omitted for Cartesian because no representation transition exists;
* retained for automatic switching;
* retained for explicit regularized propagation.

The standalone method table prints:

```text
-
```

for the Cartesian handoff residual rather than inventing a zero-valued transition observation.

### Validation result

The complete standalone close-encounter benchmark was executed after the final correction and passed all eight existing acceptance criteria.

Full `Pkg.test()` also passed.

---

## 11. KS/Levi-Civita Switching Investigation Pilot

### Commit

```text
aa87ff1 Add KS switching Investigation 1 pilot adapter
```

This is the latest commit and the most substantial Investigation 1 adapter.

### Independent variable and order

The independent variable is:

```text
:regularization_backend
```

with deterministic order:

1. `:ks`
2. `:levi_civita`

### Purpose

The experiment compares KS and Levi-Civita regularized propagation under the same fixed automatic-switching policy.

The comparison is not a new switching policy or solver experiment. It reuses the existing fixed benchmark.

### Successful benchmark baseline

The final standalone benchmark retained the existing numerical results:

```text
KS status: completed
Levi-Civita status: completed
KS switches: 2
Levi-Civita switches: 2
Maximum scaled state discrepancy:
    1.8642114308446656e-9
Entry-time discrepancy:
    0.0
Exit-time discrepancy:
    4.8183679268731794e-14
Maximum KS transition residual:
    1.3877787807814457e-17
Maximum Levi-Civita transition residual:
    1.3877787807814457e-17
```

The complete standalone benchmark passed all nine existing acceptance criteria.

### Resolved fixed settings

The final implementation removed vague configuration labels such as:

```text
:profile_defaults
:backend_defaults
```

One shared resolved-settings definition now drives:

* actual execution;
* retained-segment evaluation;
* diagnostic sampling;
* structured configuration;
* fixed controls;
* tests.

The recorded settings include concrete values or explicit derived rules for:

#### Cartesian segments

* solver profile: `:accurate`;
* algorithm: `Vern9`;
* relative tolerance: `1e-12`;
* absolute tolerance: `1e-12`;
* maximum iterations: `10^7`;
* precision: `256`;
* dense solution without `saveat`.

#### Levi-Civita segments

* algorithm: `Vern9`;
* relative tolerance: `1e-12`;
* absolute tolerance: `1e-12`;
* physical-time-targeting initial step: `1.0`;
* targeting tolerance: `sqrt(eps(Float64))`;
* targeting maximum iterations: `256`;
* dense solution without `saveat`.

#### KS segments

* algorithm: `Vern9`;
* relative tolerance: `1e-12`;
* absolute tolerance: `1e-12`;
* maximum fictitious-span expansions: `32`;
* initial fictitious span: derived;
* derivation rule and inputs retained explicitly;
* non-selected-pair threshold rule: equal to entry threshold;
* concrete non-selected threshold recorded;
* dense solution without `saveat`.

#### Retained-segment evaluation

* tolerance: `100 * eps(Float64)`;
* maximum iterations: `256`.

Per-setting drift tests verify that changing any recorded numerical setting causes configuration validation to reject the report.

### Typed supporting evidence

The adapter defines a typed immutable backend report:

```text
KSSwitchingBackendReport
```

Each point retains this report through:

```text
supporting_evidence
```

The report includes:

* backend identity;
* benchmark definition and version;
* complete configuration;
* environment;
* execution outcome;
* actual final time;
* sampled trajectory evidence;
* diagnostics;
* solver statistics;
* ordered crossing observations;
* original switch events;
* shared pairwise comparison observations.

### Ordered crossing observations

The adapter defines:

```text
KSSwitchingCrossingObservation
```

An observation can retain:

* sequence number;
* crossing or terminal-decision kind;
* whether a successful switch occurred;
* physical time;
* fictitious/Sundman time if applicable;
* original switch event;
* original decision;
* competition evidence;
* progress evidence.

This preserves:

* successful entry and exit crossings;
* terminal safety decisions;
* non-selected-pair KS safety crossings;
* ambiguous or rejected decisions;
* progress-certification failures;
* repeated or unexpected crossing sequences.

Repeated entry/exit cycles are represented through ordered sequence evidence rather than duplicate metric identifiers.

### Partial and unsuccessful trajectories

The production report builder now supports:

* zero-switch trajectories;
* one-switch trajectories;
* terminated trajectories;
* trajectories ending before the requested final time;
* initial rejections;
* missing numerical solutions on rejected segments;
* safety-crossing termination;
* progress-certification failures.

Terminated trajectories are sampled only through their actual final epoch.

Solver statistics skip segments without numerical solutions.

Pairwise observations are omitted when undefined, including:

* backend state discrepancy;
* entry-time discrepancy;
* exit-time discrepancy.

No sentinel numerical values are used.

A transition-state residual is omitted when no transition occurred.

### Execution and acceptance semantics

Execution failure is not converted into acceptance failure.

For a successful complete comparison:

* all nine acceptance criteria are declared and evaluated;
* the structured execution outcome is completed;
* exit status is zero.

For an incomplete comparison:

* all available observations are retained;
* undefined metrics are omitted;
* acceptance criteria are not evaluated;
* the structured execution outcome is terminated;
* `validation_exit_code` returns nonzero;
* direct standalone execution also exits nonzero after constructing the partial result and investigation series.

The report-requested and direct standalone paths therefore use consistent exit semantics.

### Validation completed

Before commit `aa87ff1`, the following passed:

* focused validation suite;
* production report-builder tests;
* Investigation adapter tests;
* full `Pkg.test()`;
* complete standalone KS switching benchmark;
* `git diff --check`.

The focused test counts reported in the final revision included:

```text
Production report builder: 70/70
Investigation adapter: 36/36
```

---

## 12. Investigation 1 Completion Status

The following sequence is complete:

### I1-B — Investigation Record Types

Completed by:

```text
dbe61c0 Add Investigation 1 record types
```

### I1-C — Core Pilot Adapters

Completed by:

```text
822f156 Add figure-eight Investigation 1 pilot adapter
bff7a94 Add hierarchical-triple Investigation 1 pilot adapter
```

### I1-D — Regularisation Pilot Adapters

Completed by:

```text
6ef5489 Add close-encounter Investigation 1 pilot adapter
aa87ff1 Add KS switching Investigation 1 pilot adapter
```

All four pilot regimes defined for Investigation 1 now have structured adapters.

No additional I1-D code is outstanding.

---

## 13. Important Scientific Semantics Established During This Work

The following principles were enforced and should be preserved.

### 13.1 State error is distinct from conservation drift

Energy, momentum, angular momentum, and centre-of-mass drift are not substitutes for state or trajectory accuracy.

Where an independent or pairwise state comparison exists, it must be retained independently.

### 13.2 Minimum sampled separation is not periapsis error

For the close-encounter benchmark:

* minimum sampled separation;
* periapsis time error;
* periapsis separation error;

are separate measurements and must remain separate.

### 13.3 Not applicable is not zero

Examples:

* Cartesian transition residual does not exist;
* a trajectory with no switches has no transition residual;
* unavailable pairwise comparisons after early termination must be omitted.

Zero should be used only when a quantity was genuinely measured and found to be zero.

### 13.4 Execution failure is not acceptance failure

A trajectory can fail to complete before there is enough evidence to evaluate acceptance limits.

Such a case should retain:

* actual execution outcome;
* failure summary;
* exit code;
* all partial observations;
* solver work;
* provenance.

It should not be converted into an ordinary failed acceptance criterion.

### 13.5 Raw observations must not be replaced by summaries

Summary metrics are useful, but the underlying evidence should remain accessible when it is scientifically important.

This motivated the `supporting_evidence` field and the typed KS backend reports.

### 13.6 Configuration must be reproducible

Labels such as “defaults” are inadequate when those defaults may change.

Record:

* concrete resolved values;
* algorithms;
* solver profiles;
* iteration limits;
* sampling rules;
* evaluation settings;
* stable derivation rules and all derivation inputs.

Execution and configuration must be driven from the same shared settings object or definition.

---

## 14. Known Non-Blocking Notes

### 14.1 Existing manifest warning

The full package test emits an existing manifest-resolution warning. Tests still complete successfully.

Do not treat this as a regression without evidence that its behaviour has changed.

### 14.2 Shared helper placement

Some generic Investigation helper functions remain in `FigureEightInvestigation.jl`.

A future neutral support module may be cleaner, but this is not an active blocker and should not displace scientific development.

### 14.3 Large KS adapter

`KSSwitchingInvestigation.jl` is substantial because it must preserve raw switching, crossing, failure, and configuration evidence.

Do not split or refactor it merely for line-count reduction. Any restructuring should preserve:

* evidence identity;
* immutable records;
* partial-execution support;
* exact configuration provenance;
* existing tests.

### 14.4 `supporting_evidence::Any`

The generic measurement point accepts experiment-specific immutable evidence through an `Any` field.

This is intentional for now. A future type hierarchy could be considered, but only if it clearly improves maintainability without complicating the validation framework or distracting from numerical research.

---

## 15. Earlier Major Project Milestones

The following earlier work remains relevant.

### 15.1 v0.4 regularization and switching

The v0.4 development programme implemented and validated:

* close-approach monitoring;
* pair-centred transformations;
* Levi-Civita regularization;
* Kustaanheimo–Stiefel regularization;
* explicit regularized segments;
* automatic switching;
* segment handoff;
* retained-solution switching evaluation;
* switching diagnostics;
* KS comparison benchmarks.

The Stage KS-12 validation suite previously passed all 11 validation benchmarks.

### 15.2 v0.5 validation framework

The v0.5 programme added:

* immutable validation result types;
* criterion evaluation;
* deterministic serialization;
* structured case-result builders;
* structured suite-result builders;
* console presentation;
* execution semantics;
* approved scientific reference records;
* deterministic approved-reference serialization;
* approval workflow;
* validation-run workflow;
* performance record types;
* performance serialization;
* performance measurement infrastructure.

### 15.3 JET development environment

JET was removed as a runtime dependency and placed in a dedicated development environment.

The established setup is:

```powershell
julia --project=dev/jet -e 'using Pkg; Pkg.develop(path="."); Pkg.instantiate()'
```

Normal analysis:

```powershell
julia --project=dev/jet -e 'using ThreeBody3D, JET; JET.report_package(ThreeBody3D)'
```

`dev/jet/Manifest.toml` is ignored so each checkout can retain its local developed path.

### 15.4 Scientific reference and performance work

The approved scientific reference framework and the performance benchmark framework were designed and substantially implemented before the Investigation 1 work.

These systems should continue to support, rather than dominate, future accuracy research.

---

## 16. Recommended Restart Procedure

At the beginning of the next conversation:

1. State that development is resuming from commit:

   ```text
   aa87ff1 Add KS switching Investigation 1 pilot adapter
   ```

2. Upload the latest repository archive from:

   ```text
   C:\Dev\ThreeBody3D
   ```

3. Confirm:

   ```powershell
   git status
   git log -5 --oneline
   ```

   Expected state:

   ```text
   On branch v0.5-development
   Your branch is up to date with 'origin/v0.5-development'.

   nothing to commit, working tree clean
   ```

4. Inspect the current version of:

   ```text
   docs/design/V0_6_INVESTIGATION_1_MEASUREMENT_PLAN.md
   ```

5. Determine the next approved stage directly from that document.

6. Do not infer the next stage solely from this report.

7. Before implementing, review the relevant existing benchmark, adapter, types, and tests from the uploaded repository.

---

## 17. Recommended Next Development Decision

The four Investigation 1 pilot adapters are complete.

The next task should be chosen from the actual remaining stages in:

```text
docs/design/V0_6_INVESTIGATION_1_MEASUREMENT_PLAN.md
```

The next conversation should first determine whether the approved plan calls for work such as:

* executing and recording real Investigation 1 series;
* deterministic serialization of investigation records;
* presentation or analysis tooling;
* integration with approved reference workflows;
* review and consolidation of pilot evidence;
* beginning the next numerical investigation;
* updating design and continuation documents.

These possibilities must not be assumed. The current design document should be read from the uploaded repository and treated as authoritative.

The next development stage should continue to satisfy the central project test:

> Does this work directly help ThreeBody3D identify or produce more accurate and scientifically reliable three-body solutions?

---

## 18. Exact Final Checkpoint

At the close of this session:

```text
Repository:     IanGraceNz/ThreeBody3D
Branch:         v0.5-development
HEAD:           aa87ff1
Remote branch:  origin/v0.5-development at aa87ff1
Working tree:   clean
Push status:    complete
Pkg.test():     passed before latest commit
Standalone KS switching benchmark:
                passed all 9 criteria
Investigation 1 pilots:
                4 of 4 complete
Outstanding uncommitted work:
                none
Known code blocker:
                none
```

The project is safe to resume from this checkpoint in a fresh conversation.

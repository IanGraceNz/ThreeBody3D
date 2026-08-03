# ThreeBody3D Continuation Report

**Report date:** 3 August 2026
**Local time zone:** Pacific/Auckland
**Repository:** `https://github.com/IanGraceNz/ThreeBody3D`
**Local repository path:** `C:\Dev\ThreeBody3D`
**Development branch:** `v0.5-development`

---

## 1. Purpose of This Report

This report records the exact ThreeBody3D development state reached at the end of the current session.

It is intended to allow work to resume in a new ChatGPT or Codex conversation without losing:

* the scientific purpose of the project;
* the approved development priorities;
* the Investigation 2 design constraints;
* the stages and increments already completed;
* the current uncommitted implementation;
* verification already performed;
* the precise Git actions still required;
* the next approved scientific stage; or
* the scope restrictions that must remain in force.

At the start of a future conversation, the then-current repository archive must be uploaded and inspected. This report is a handoff aid; the repository and approved design documents remain authoritative for source details and current Git state.

Do not reconstruct source files from this report.

---

## 2. Git Checkpoint at Report Preparation

### 2.1 Branch and committed HEAD

At the time this report was prepared:

```text
branch: v0.5-development
HEAD:   edc7af7e6018f8e5e3e4422bc0d516f094ef6e49
```

The current committed HEAD is:

```text
edc7af7 Add matched close-encounter threshold-scale investigations
```

The recorded remote-tracking state is:

```text
origin/v0.5-development = edc7af7
local v0.5-development  = edc7af7
```

Therefore, before the orchestration commit is created:

* local and remote are synchronized;
* divergence is zero;
* the real Git index is empty;
* no implementation files have been staged;
* no history-changing Git operation has been performed.

### 2.2 Current working tree

The working tree contains the following changes:

```text
modified:
    CONTINUATION_REPORT.md
    examples/validation/framework/ValidationFramework.jl
    test/validation_framework/runtests.jl

untracked:
    examples/validation/framework/CloseEncounterInvestigationRunner.jl
    examples/validation/run_investigation_2_close_encounter.jl
    test/validation_framework/close_encounter_investigation_runner.jl
```

`CONTINUATION_REPORT.md` is not part of the scientific implementation patch.

The intended orchestration patch is exactly these five files:

```text
examples/validation/framework/CloseEncounterInvestigationRunner.jl
examples/validation/framework/ValidationFramework.jl
examples/validation/run_investigation_2_close_encounter.jl
test/validation_framework/close_encounter_investigation_runner.jl
test/validation_framework/runtests.jl
```

The verified staged-set statistics are:

```text
5 files changed, 872 insertions(+)
```

Per-file statistics are:

```text
336  examples/validation/framework/CloseEncounterInvestigationRunner.jl
  3  examples/validation/framework/ValidationFramework.jl
 38  examples/validation/run_investigation_2_close_encounter.jl
494  test/validation_framework/close_encounter_investigation_runner.jl
  1  test/validation_framework/runtests.jl
```

A disposable Git index containing exactly those five files passed the equivalent of:

```text
git diff --cached --check
```

with no output.

The real repository index remained empty.

### 2.3 Required implementation commit

Stage only the five implementation files and commit them separately from this report:

```powershell
git add `
    examples/validation/framework/CloseEncounterInvestigationRunner.jl `
    examples/validation/framework/ValidationFramework.jl `
    examples/validation/run_investigation_2_close_encounter.jl `
    test/validation_framework/close_encounter_investigation_runner.jl `
    test/validation_framework/runtests.jl

git diff --cached --check
git diff --cached --stat
git status

git commit -m "Add controlled close-encounter investigation orchestration"
```

Expected staged statistics:

```text
5 files changed, 872 insertions(+)
```

Do not stage `CONTINUATION_REPORT.md` in that commit.

### 2.4 Continuation-report commit

After the implementation commit, replace `CONTINUATION_REPORT.md` with this report and commit it separately:

```powershell
git add CONTINUATION_REPORT.md
git diff --cached --check
git status
git commit -m "Update Continuation Report after I2-C orchestration"
```

The separate commit preserves an atomic distinction between:

1. scientific and orchestration implementation; and
2. session-continuity documentation.

### 2.5 Push

After both commits exist:

```powershell
git push
git status
git log -4 --oneline
```

Expected final state:

* `v0.5-development` synchronized with `origin/v0.5-development`;
* no staged files;
* no untracked implementation files;
* clean working tree;
* the orchestration implementation and continuation report both published.

The actual commit hashes must be obtained from Git after the commits are created.

---

## 3. Project Purpose and Priorities

ThreeBody3D is a Julia package for solving three-dimensional three-body initial-value problems.

Its primary purpose is to improve:

1. the numerical accuracy of three-body solutions; and
2. the handling of close encounters and singularities.

All implementation and infrastructure work must contribute directly to those purposes.

The agreed priority order is:

1. scientific acceptability and numerical correctness;
2. ease of use;
3. simplicity.

Long-term numerical accuracy takes priority over speed.

Close encounters and singularities must be handled as accurately and robustly as practical.

Validation infrastructure, record types, serialization, orchestration, and reporting are supporting tools. They are not the project’s primary purpose and must not become ends in themselves.

Major algorithmic work, especially regularisation work, must be designed before coding.

Implementation should proceed through small, bounded, fully tested Git commits.

Scientific evidence must be recorded factually before interpretation or production changes are considered.

---

## 4. Development Environment

The active development environment is:

```text
Operating system: Windows
Shell:           PowerShell
Editor:          Visual Studio Code
Repository:      C:\Dev\ThreeBody3D
Branch:          v0.5-development
```

Recent work has used Julia 1.12.5.

Normal package verification is:

```powershell
julia --project=. -e "using Pkg; Pkg.test()"
```

Focused validation-framework execution is:

```powershell
julia --project=. test/validation_framework/runtests.jl
```

The root `Manifest.toml` is Git-ignored and is local environment state.

JET is intentionally isolated in:

```text
dev/jet/
```

JET must not be restored as a root runtime dependency.

---

## 5. Manifest-Resolution Warning

A previous `Pkg.test()` emitted a warning that the local manifest required resolution.

The root manifest contained an outdated project hash and retained stale root-environment information from the earlier JET configuration.

The following command was run:

```powershell
julia --project=. -e "using Pkg; Pkg.resolve(); Pkg.instantiate()"
```

Julia reported:

```text
Project  No packages added to or removed from Project.toml
Manifest No packages added to or removed from Manifest.toml
```

The current manifest project hash is:

```text
b052e71bd87b368e15aa5dd2e47fa0e5f10d7b2b
```

The local manifest no longer identifies JET as a direct dependency of ThreeBody3D.

A subsequent complete:

```powershell
julia --project=. -e "using Pkg; Pkg.test()"
```

ran without the manifest-resolution advisory and ended with:

```text
ThreeBody3D tests passed
```

The root manifest is ignored and must not be staged or committed.

No package versions were added or removed by the resolution.

---

## 6. Core Package Context

The main public simulation API includes:

```julia
ThreeBodySystem
statevector
simulate
```

The physical state contains positions and velocities for three bodies and has 18 scalar components.

Typical solver profiles include:

```text
:fast
:accurate
:extreme
```

The package contains:

* Cartesian three-body propagation;
* numerical diagnostics and invariant calculations;
* close-approach monitoring;
* planar Levi-Civita transformations and dynamics;
* explicit regularised segment composition;
* experimental automatic switching;
* KS transformations and dynamics;
* KS and Levi-Civita cross-validation;
* scientific validation adapters;
* deterministic validation records;
* performance-measurement records;
* Investigation 1 and Investigation 2 experiment infrastructure.

No source under `src/` was changed by the current orchestration increment.

---

## 7. Governing Scientific Documents

The current scientific programme is governed primarily by:

```text
docs/design/V0_6_SCIENTIFIC_ACCURACY_IMPROVEMENT_DESIGN.md
docs/design/V0_6_INVESTIGATION_1_MEASUREMENT_PLAN.md
docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md
```

The programme theme is:

```text
Measure – Explain – Improve
```

The current approved Investigation 2 plan was committed as:

```text
a5f6f59 Approve Investigation 2 experimental plan
```

The Investigation 2 plan defines:

* scientific questions;
* hypotheses;
* fixed controls;
* experimental point values;
* required metrics;
* independent-reference rules;
* temporal and segment localisation;
* reconstruction and dense-output evidence;
* interpretation rules;
* stage boundaries;
* completion criteria.

The plan must be read directly before designing or implementing the next increment.

---

## 8. Investigation 1 Status

Investigation 1 established deterministic measurement and reporting infrastructure for the existing benchmark cases.

Relevant completed work includes:

* immutable investigation record types;
* figure-eight pilot adapter;
* hierarchical-triple pilot adapter;
* close-encounter pilot adapter;
* KS-switching pilot adapter;
* deterministic series serialization;
* baseline execution;
* baseline Markdown reporting;
* reproducibility comparison;
* operational-failure retention.

Relevant commits include:

```text
bbda981 Design Investigation 1 measurement programme
dbe61c0 Add Investigation 1 record types
822f156 Add figure-eight Investigation 1 pilot adapter
bff7a94 Add hierarchical-triple Investigation 1 pilot adapter
6ef5489 Add close-encounter Investigation 1 pilot adapter
aa87ff1 Add KS switching Investigation 1 pilot adapter
212465c Add Investigation 1 baseline execution and reporting
```

Investigation 1 provided the factual baseline that Investigation 2 is designed to explain.

---

## 9. Investigation 2 Stage Structure

The approved Investigation 2 stages are:

### Stage I2-A — Experimental-plan approval

Completed.

### Stage I2-B — Core integration experiments

Completed and committed.

### Stage I2-C — Close-encounter decomposition

The five scientific series are completed and committed.

The controlled orchestration workflow is implemented, verified, and awaiting its separate five-file commit.

Once that commit is created, Stage I2-C implementation is complete.

### Stage I2-D — KS backend localisation

Not yet implemented.

### Stage I2-E — Explanatory execution and report

Not yet started.

No causal interpretation or production algorithm change has been approved.

---

## 10. Completed Investigation 2 Core Work

### 10.1 Core tolerance foundation

Commit:

```text
002fe90 Add core tolerance investigation foundation
```

This added controlled Tsit5-versus-Vern9 tolerance comparisons using identical saved grids and established scaled state-difference metrics.

It introduced:

* immutable configurations;
* direct attempt records;
* completed, terminated, errored, and unavailable outcomes;
* report-only measurement paths;
* validation of solver identity and controls;
* deterministic series construction;
* process-isolated performance support.

### 10.2 Core duration and sampling series

Commit:

```text
767bba5 Add core duration and sampling investigations
```

This added:

```text
figure_eight_duration
hierarchical_triple_duration
figure_eight_diagnostic_sampling
hierarchical_triple_diagnostic_sampling
```

It preserved fixed solver controls and separated scientific trajectory evidence from diagnostic-sampling effects.

### 10.3 Conditional precision confirmation

Commit:

```text
e968c1d Add conditional figure-eight precision investigation
```

This added:

* strict precision-trigger semantics;
* 128-, 256-, and 384-bit configurations;
* precision-safe canonical decimal parsing;
* BigFloat reference execution;
* deterministic trigger and precision-series serialization;
* process-isolated performance support.

### 10.4 Core orchestration

Commit:

```text
ee916b2 Add controlled Investigation 2 core orchestration
```

This added a deterministic workflow for the approved I2-B series with:

* fixed execution order;
* partial-result retention;
* atomic report output;
* operational-evidence preservation;
* process-isolated performance;
* conditional precision execution;
* deterministic CLI behaviour.

---

## 11. Completed Investigation 2 Close-Encounter Scientific Foundations

### 11.1 I2-C1 — Cartesian close-encounter decomposition

Commit:

```text
d210e97 Add Cartesian close-encounter decomposition foundation
```

This implemented:

```text
close_encounter_cartesian_tolerance
```

at:

```text
1e-9
1e-10
1e-11
1e-12
1e-13
```

It added:

* one 256-bit independent BigFloat reference;
* reference-defined entry, periapsis, and exit boundaries;
* temporal error localisation;
* before-, during-, and after-encounter maxima;
* exact boundary sampling;
* dense-periapsis localisation;
* propagation and invariant evidence;
* partial-evidence retention;
* deterministic serialization;
* process-isolated performance support.

The reference boundaries are defined from the independent reference only:

```text
entry:
    inbound crossing of pair separation 0.1

periapsis:
    independent-reference minimum separation

exit:
    outbound crossing of pair separation 0.25
```

### 11.2 I2-C2 — Matched regularised-tolerance investigations

Commit:

```text
ca8e15f Add matched regularized close-encounter tolerance investigations
```

This implemented:

```text
close_encounter_automatic_regularized_tolerance
close_encounter_explicit_regularized_tolerance
```

at:

```text
1e-10
1e-11
1e-12
1e-13
```

Fixed controls include:

```text
Cartesian reltol = abstol = 1e-13
entry threshold = 0.1
ambiguity threshold = 0.25
exit threshold = 0.25
state-evaluation tolerance = 1e-14
reference precision = 256 bits
```

For every point:

* automatic propagation determines the physical entry and exit times;
* explicit propagation receives that exact automatic interval;
* automatic and explicit results are compared on the matched interval;
* the independent reference remains the accuracy source;
* the independent-reference periapsis remains exactly linked to the second comparison sample.

The implementation retains:

* reference position, velocity, and full-state errors;
* automatic-versus-explicit differences;
* entry, periapsis, exit, and final comparison locations;
* in-interval maximum discrepancy;
* automatic event evidence;
* transition evidence;
* fictitious-time endpoint evidence;
* segment and switch counts;
* solver work;
* matched endpoint evidence;
* partial staged evidence;
* complete and partial deterministic round trips.

The final I2-C2 corrections require:

* complete paired evidence only when both direct executions completed;
* no comparison-failure summary alongside complete paired evidence;
* exact staged comparison table names;
* rejection of missing, renamed, zero-indexed, or extra tables.

### 11.3 I2-C3 — Matched threshold-scale investigations

Commit:

```text
edc7af7 Add matched close-encounter threshold-scale investigations
```

This implemented:

```text
close_encounter_automatic_threshold_scale
close_encounter_explicit_threshold_scale
```

at the exact ordered scales:

```text
0.5
1.0
2.0
```

with approved mappings:

| Scale | Entry | Ambiguity |  Exit |
| ----: | ----: | --------: | ----: |
|   0.5 |  0.05 |     0.125 | 0.125 |
|   1.0 |  0.10 |      0.25 |  0.25 |
|   2.0 |  0.20 |      0.50 |  0.50 |

The implementation preserves:

* fixed I1 baseline tolerances;
* one independent 256-bit reference;
* current-threshold event-separation residuals;
* fixed independent-reference event-time comparisons;
* exact automatic-to-explicit interval matching;
* the I2-C2 staged attempt model;
* distinct threshold-family serialization;
* trusted definition-derived evidence-family validation;
* strict scale-to-threshold validation;
* six process-isolated performance registrations.

The serialized-family correction ensures that threshold evidence cannot be disguised as regularised-tolerance evidence, including at scale `1.0`, where the numerical threshold values coincide with the I2-C2 controls.

---

## 12. Current Increment — Controlled Stage I2-C Orchestration

### 12.1 Purpose

The current increment provides one controlled workflow that executes and persists all five approved Stage I2-C series.

It does not add scientific experiments, change solver behaviour, interpret evidence, or modify production controls.

The workflow is implemented in:

```text
examples/validation/framework/CloseEncounterInvestigationRunner.jl
```

The CLI is:

```text
examples/validation/run_investigation_2_close_encounter.jl
```

The focused tests are:

```text
test/validation_framework/close_encounter_investigation_runner.jl
```

### 12.2 Exact series order

The workflow enforces this exact order:

```text
1. close_encounter_cartesian_tolerance
2. close_encounter_automatic_regularized_tolerance
3. close_encounter_explicit_regularized_tolerance
4. close_encounter_automatic_threshold_scale
5. close_encounter_explicit_threshold_scale
```

### 12.3 Deterministic output files

The exact output filenames are:

```text
close_encounter_cartesian_tolerance.toml
close_encounter_automatic_regularized_tolerance.toml
close_encounter_explicit_regularized_tolerance.toml
close_encounter_automatic_threshold_scale.toml
close_encounter_explicit_threshold_scale.toml
```

The default output directory is:

```text
validation_reports/investigation_2/
```

### 12.4 Shared environment and reference

The workflow resolves one parent `ValidationEnvironment`.

It constructs exactly one direct:

```text
CloseEncounterReferenceExecution
```

at 256-bit precision.

That same reference object is reused by identity across:

* five Cartesian tolerance configurations;
* four matched regularised-tolerance configurations;
* three matched threshold-scale configurations.

This gives 12 direct configurations sharing one reference.

The paired automatic and explicit attempts are constructed once per regularised tolerance or threshold scale and reused to build both method series.

Performance children retain their existing independent untimed setup because they execute in isolated processes.

### 12.5 Performance groups

The workflow executes three deterministic process-isolated performance suites:

```text
Cartesian tolerance:       5 registrations
regularised tolerance:     8 registrations
threshold scale:           6 registrations
```

Total:

```text
19 performance reports
```

Separate temporary performance-report directories are used for:

```text
cartesian
regularized_tolerance
threshold_scale
```

The existing `StandardBenchmark` protocol is preserved.

### 12.6 Result record

The workflow returns an immutable result containing:

```text
series
report_paths
failures
exit_code
```

The result does not retain:

* solver objects;
* complete trajectories;
* dense solutions;
* the complete independent reference solution.

Exit semantics are:

```text
0 = no retained operational failures
1 = one or more retained operational failures
```

Scientific unsuccessful point evidence remains represented through the existing investigation point records and is not replaced by workflow exceptions.

### 12.7 Trusted series validation

Before persistence, the workflow validates:

* exact series ID;
* exact investigation definition;
* exact independent variable;
* exact point count;
* exact point identities and ordering;
* exact configuration family;
* parent environment identity;
* method association;
* performance-report association;
* retained reference boundaries;
* paired automatic and explicit series presence.

Wrong, missing, duplicated, additional, or reordered series are rejected.

The workflow does not silently normalize invalid child output.

### 12.8 Persistence safety

Each valid series is written atomically.

Before an execution, the workflow removes only its own:

* five series files;
* workflow-owned operational diagnostics.

It preserves unrelated files and unrelated operational evidence.

Failure behaviour includes:

* parent-environment failure blocks all groups;
* shared-reference failure blocks all groups;
* one experiment-group exception removes only that group’s owned outputs;
* later independent groups continue after a group exception;
* paired-group failure removes both method outputs;
* atomic write failure excludes that report from retained results;
* stale successful files cannot survive a failed rerun.

### 12.9 Operational evidence

The workflow retains independent evidence for:

* direct execution failures;
* performance-child failures;
* missing reports;
* malformed reports;
* workflow exceptions;
* persistence exceptions.

Malformed performance-report bytes are retained exactly.

Missing reports do not fabricate raw-report files.

A performance failure does not remove valid direct metrics or supporting evidence.

Multiple independent failures remain distinct.

### 12.10 Parent-environment stale-evidence correction

The workflow cleanup explicitly owns:

```text
close_encounter_parent_environment
```

A failed environment-resolution run may retain:

```text
operational_evidence/close_encounter_parent_environment__exception.txt
```

A later workflow invocation clears that obsolete owned diagnostic while preserving unrelated evidence.

The regression test confirms:

* one parent-environment failure is retained after the failed run;
* no series or paths are retained;
* all five owned reports are absent;
* a successful same-directory rerun removes the obsolete diagnostic;
* all five series are then retained in order;
* no other close-encounter workflow diagnostic remains;
* unrelated bytes remain byte-identical;
* a non-`ValidationEnvironment` return uses the same owned label and cleanup rule.

### 12.11 CLI

The CLI accepts zero or one argument:

```powershell
julia --project=. examples/validation/run_investigation_2_close_encounter.jl
```

or:

```powershell
julia --project=. examples/validation/run_investigation_2_close_encounter.jl <output-directory>
```

It:

* rejects excess arguments;
* runs the workflow once;
* prints retained report paths;
* prints operational-failure details;
* exits with the workflow exit code.

The CLI ends with exactly one terminating LF and no blank line at EOF.

---

## 13. Verification of the Current Increment

### 13.1 Focused orchestration tests

After the stale parent-environment correction:

```text
Investigation 2 close-encounter orchestration: 105/105 passed
```

This consists of:

```text
original orchestration assertions: 84/84
new stale-environment assertions:  21/21
```

Coverage includes:

* shared-reference identity;
* exact point ordering;
* exact performance registrations;
* trusted series contracts;
* deterministic persistence;
* strict read-back;
* group failure continuation;
* shared-reference failure;
* atomic-write failure;
* malformed-report retention;
* missing-report handling;
* direct-metric retention;
* stale-evidence cleanup;
* unrelated-file preservation;
* CLI excess-argument rejection.

### 13.2 Existing Investigation 2 suites

The following existing suites remained passing:

```text
Investigation 2 core orchestration:                186/186
Close-encounter Cartesian investigation:            86/86
Regularised staged attempts:                        84/84
Regularised paired series:                         117/117
Threshold-scale configurations:                     23/23
Threshold matched attempts and series:              54/54
Threshold performance contracts:                    13/13
Threshold serialization integrity:                  22/22
```

### 13.3 Full package tests

The full command:

```powershell
julia --project=. -e "using Pkg; Pkg.test()"
```

passed and ended with:

```text
ThreeBody3D tests passed
```

The manifest-resolution warning had already been removed through `Pkg.resolve()`.

### 13.4 Standalone close-encounter benchmark

The command:

```powershell
julia --project=. examples/validation/close_encounter_comparison.jl
```

passed all:

```text
8/8 acceptance criteria
```

The independent reference retained 256-bit precision.

### 13.5 Final EOF-only correction

After the scientific and orchestration tests, one extra blank line was removed from the untracked CLI file.

That correction changed only terminal newline layout.

Julia tests were not repeated after that whitespace-only correction, as instructed.

A disposable index containing all five intended implementation files then passed the exact staged-set diff check.

---

## 14. Real Workflow Smoke Evidence

The real close-encounter workflow was executed exactly once in a self-cleaning temporary directory.

Results:

```text
exit code:              0
retained series:        5
retained report paths:  5
completed points:      19
performance reports:   19
samples per report:     5
```

Exact series and point counts:

```text
close_encounter_cartesian_tolerance:                  5
close_encounter_automatic_regularized_tolerance:      4
close_encounter_explicit_regularized_tolerance:       4
close_encounter_automatic_threshold_scale:            3
close_encounter_explicit_threshold_scale:             3
```

All reports passed strict deserialization and byte-identical write/read/write checks.

All successful direct points reached:

```text
final physical time = 1.6
```

All 14 regularised automatic and explicit points retained:

```text
segments = 3
switches = 2
```

Automatic and explicit intervals remained exactly linked.

All 19 points retained matching reference boundaries.

The reference boundary times were:

```text
entry:
0.7746243491207307049706846417403295048093181536163255909079076250083048447831296

periapsis:
0.7855162473072730090765249433207896631191304823341874944970924513276777125351991

exit:
0.8308377255249349621931462406667649307029080741607653855841658765058063177267532
```

The boundary values retained 256-bit `BigFloat` precision.

Ambient `BigFloat` precision before and after the workflow was:

```text
256 bits
```

The smoke directory was removed automatically and did not alter retained validation reports.

The smoke was not repeated after the stale-diagnostic and EOF corrections because neither correction changed scientific execution or performance code.

---

## 15. Scientific Interpretation Status

No causal conclusion has yet been approved from the Investigation 2 evidence.

In particular, do not yet conclude:

* that Cartesian near-periapsis propagation is the dominant error mechanism;
* that automatic switching is or is not a material contributor;
* that any threshold scale is preferable;
* that any regularised tolerance should become a production default;
* that KS or Levi-Civita is scientifically superior;
* that a production switching policy should change.

Stage I2-C has created controlled measurements and deterministic execution infrastructure.

The evidence must remain factual until the approved explanatory stage.

Stage I2-E, not the current stage, is responsible for:

* repeated execution;
* reproducibility confirmation;
* hypothesis evaluation;
* causal classification;
* explanatory reporting.

---

## 16. Next Approved Stage

After the orchestration implementation and this continuation report are committed and pushed, the next formal stage is:

```text
Stage I2-D — KS backend localisation
```

The Investigation 2 plan requires I2-D to implement:

* a common KS and Levi-Civita regularised-tolerance series;
* a switching-threshold series;
* segment-localised physical-state discrepancies;
* reconstruction-consistency evidence;
* dense-output consistency evidence.

The defined series are:

```text
ks_switching_regularized_tolerance
ks_switching_threshold_scale
```

### 16.1 Common regularised-tolerance points

```text
regularised reltol = abstol:
1e-10
1e-11
1e-12
1e-13
```

Fixed controls:

```text
Cartesian reltol = abstol = 1e-12
entry threshold = 0.2
ambiguity threshold = 0.3
exit threshold = 0.4
```

### 16.2 Threshold-scale points

```text
threshold_scale:
0.5
1.0
2.0
```

Approved thresholds:

| Scale | Entry | Ambiguity | Exit |
| ----: | ----: | --------: | ---: |
|   0.5 |  0.10 |      0.15 | 0.20 |
|   1.0 |  0.20 |      0.30 | 0.40 |
|   2.0 |  0.40 |      0.60 | 0.80 |

### 16.3 Required I2-D evidence

The plan requires physical-state discrepancy evidence partitioned into:

* Cartesian propagation before entry;
* regularised propagation;
* Cartesian propagation after exit;
* entry state;
* exit state;
* final state.

It also requires:

* pair-relative position discrepancy;
* pair-relative velocity discrepancy;
* scaled full-state discrepancy;
* maximum-discrepancy time and segment;
* event-time differences;
* transition residuals;
* reconstruction-consistency residuals;
* dense-output consistency residuals;
* backend-specific invariant drift;
* segment and switch counts;
* solver work;
* saved-state counts;
* retained timing evidence.

Two nested full-interval physical-time grids of 801 and 3201 points are required.

### 16.4 Design-first requirement

Do not begin by implementing all of I2-D in one increment.

The next conversation should first:

1. inspect the repository at its new committed HEAD;
2. read the Investigation 2 plan directly;
3. inspect the existing KS and Levi-Civita switching APIs and records;
4. inventory which reconstruction and accepted-node operations already exist;
5. identify unavailable operations explicitly;
6. design the smallest scientifically complete first I2-D foundation;
7. produce a bounded Codex instruction before editing source.

If a required reconstruction operation is unavailable through existing mathematical maps, record the evidence as unavailable. Do not invent a proxy or add an unapproved mathematical map merely to satisfy the experiment.

---

## 17. Scope Restrictions for Future Work

Until a new bounded instruction is approved, do not:

* implement Stage I2-D wholesale;
* begin Stage I2-E;
* run the final repeated explanatory experiment programme;
* produce causal interpretations;
* classify mechanisms as primary or secondary;
* recommend a production threshold;
* change the switching policy;
* change solver algorithms;
* change mathematical regularisation maps;
* change public package APIs;
* change production solver profiles;
* introduce new acceptance thresholds;
* change benchmark physics;
* alter existing Investigation 2 serialized forms;
* weaken record-integrity validation;
* stage or commit unrelated files.

No algorithmic improvement is permitted during the Investigation 2 measurement and explanation stages.

---

## 18. Restart Procedure for a New Conversation

At the beginning of the next conversation:

1. Upload the current repository archive.

2. State the local repository path:

   ```text
   C:\Dev\ThreeBody3D
   ```

3. Ask the assistant to inspect the repository.

4. Require it to read:

   ```text
   CONTINUATION_REPORT.md
   docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md
   ```

5. Require verification of:

   * current branch;
   * exact HEAD;
   * remote divergence;
   * staged state;
   * working-tree state;
   * recent commits;
   * whether the orchestration and continuation-report commits were pushed.

6. Confirm that Stage I2-C is complete.

7. Ask for design of the smallest first I2-D increment.

8. Do not authorize implementation until that design and Codex instruction have been reviewed.

The repository must be treated as authoritative where it differs from this report.

---

## 19. Important Recent Commit Sequence

Before the pending orchestration and report commits, the recent committed sequence is:

```text
edc7af7 Add matched close-encounter threshold-scale investigations
ca8e15f Add matched regularized close-encounter tolerance investigations
d210e97 Add Cartesian close-encounter decomposition foundation
ee916b2 Add controlled Investigation 2 core orchestration
0b63eb7 Update Continuation Report CONTINUATION_REPORT.md
e968c1d Add conditional figure-eight precision investigation
767bba5 Add core duration and sampling investigations
002fe90 Add core tolerance investigation foundation
a5f6f59 Approve Investigation 2 experimental plan
212465c Add Investigation 1 baseline execution and reporting
```

The next implementation commit should be:

```text
Add controlled close-encounter investigation orchestration
```

The following documentation commit should be:

```text
Update Continuation Report after I2-C orchestration
```

Actual hashes must be read from Git after creation.

---

## 20. Final Handoff Summary

At report preparation:

* I2-B is complete and committed;
* all five I2-C scientific series are complete and committed;
* the controlled I2-C orchestration workflow is implemented;
* the orchestration workflow is verified;
* the implementation patch contains exactly five files;
* its verified size is 872 insertions;
* the index is empty;
* the implementation is ready to commit;
* the continuation report must remain outside that implementation commit;
* the report should be committed separately;
* both commits should be pushed;
* the root manifest must remain uncommitted;
* the next formal stage is I2-D;
* no I2-D implementation instruction has yet been approved;
* no scientific interpretation or production change is authorized.

The immediate task is to create and push the two atomic commits described in Section 2.

Afterward, development may resume by designing the first bounded Stage I2-D increment.

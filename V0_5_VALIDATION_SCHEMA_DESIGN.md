# ThreeBody3D v0.5 Validation Result Schema Design

## 1. Purpose

This document defines the versioned validation-result model required by Stage
V5-V0 of `V0_5_IMPLEMENTATION_PLAN.md`.

The design separates three responsibilities that are currently combined inside
standalone scripts:

1. **measurement** computes physical and numerical quantities;
2. **evaluation** compares measured quantities with declared scientific
   criteria; and
3. **presentation** renders the same retained result for people or tools.

The separation is architectural only at Stage V5-V0. Implementation belongs to
Stage V5-V1. No numerical algorithm, solver configuration, or acceptance limit
is changed by this design.

## 2. Design goals

The schema must:

- represent every metric and criterion in the current eleven-case suite;
- preserve exact standalone-script behaviour;
- distinguish pass, fail, execution error, expected stop, and expected error;
- retain sufficient metadata to reproduce a result;
- support deterministic serialization;
- remain extensible for long-duration cases, sweeps, ensembles, and regularized
  formulations;
- separate scientific acceptance from descriptive performance data;
- permit human-readable console output without parsing printed text;
- avoid embedding arbitrary executable logic in stored reports; and
- be versioned independently from the package version.

## 3. Non-goals for V5-V1

The first implementation is not intended to:

- replace the package test suite;
- change any current acceptance threshold;
- make wall-clock timing a correctness criterion;
- create a general database system;
- serialize Julia implementation details that are unstable across versions;
- automatically update reviewed reference results; or
- force all validation cases to report an identical set of metrics.

## 4. Three-layer validation model

### 4.1 Measurement layer

The measurement layer runs a deterministic validation calculation and returns
named observations. It must not decide whether a scientific result passes.

Examples include:

- maximum relative energy drift;
- periodicity error;
- minimum pair separation;
- maximum gauge-constraint residual;
- switch count;
- completion status; and
- accepted-step count.

The measurement layer may use package internals when a research validation
requires them, but it must identify that dependency in the case definition.

### 4.2 Evaluation layer

The evaluation layer applies explicit criteria to retained measurements.

Each criterion must record:

- a stable criterion identifier;
- a human-readable label;
- the metric identifier being assessed;
- the comparison relation;
- the declared limit or expected value;
- optional absolute and relative comparison tolerances;
- the observed value;
- the resulting status; and
- a rationale or provenance reference for the criterion.

Evaluation must be deterministic for a fixed measurement record. Presentation
formatting must not influence evaluation.

### 4.3 Presentation layer

The presentation layer consumes a complete retained result and may render:

- the existing console tables;
- a suite summary;
- deterministic machine-readable output;
- future Markdown release evidence; or
- future reference-comparison reports.

Presentation must not recompute scientific metrics or criteria. A renderer may
round values for display, but the unrounded retained value governs evaluation
and serialization.

## 5. Schema version

The initial structured format will use schema identifier:

```text
threebody3d.validation-result
```

and schema version:

```text
1.0.0
```

Schema versioning follows semantic intent:

- a patch version clarifies representation without changing meaning;
- a minor version adds optional backward-compatible fields or metric kinds; and
- a major version makes an incompatible structural or semantic change.

Every serialized case and suite report must contain both identifier and version.
The package version is separate metadata and must not be used as a substitute
for the schema version.

## 6. Core records

The names below are design names. Exact Julia type names will be reviewed in
Stage V5-V1.

### 6.1 Validation case definition

A case definition describes what should be run.

Required fields:

- `case_id`: stable symbolic or string identifier;
- `title`: human-readable name;
- `description`: concise scientific purpose;
- `classifications`: one or more of regression, scientific-reference, stress,
  or performance;
- `source_path`: repository-relative standalone entry script;
- `tier_membership`: declared suite tiers;
- `expected_outcome`: success, stop, or error;
- `required`: whether failure makes the containing suite fail; and
- `definition_version`: integer incremented when the scientific configuration
  or acceptance meaning changes.

Optional fields:

- tags such as `ks`, `levi-civita`, `switching`, `collision`, or
  `hierarchical`;
- dependencies on external tools or optional packages; and
- a human-readable reference or design-document citation.

`case_id` must remain stable when wording changes. `definition_version` must
change when initial conditions, integration interval, solver configuration,
sampling policy, metrics, or acceptance criteria change materially.

### 6.2 Reproducibility metadata

Required environment fields:

- package name and version;
- repository commit identifier when available;
- dirty-working-tree flag when available;
- Julia version;
- operating system;
- machine architecture;
- number of Julia threads;
- numeric type;
- numeric precision in bits where applicable;
- validation schema identifier and version; and
- timestamp in UTC.

Required numerical-configuration fields where applicable:

- solver profile or explicit solver identifier;
- relative tolerance;
- absolute tolerance;
- any regularized-propagation tolerance;
- initial-condition identifier;
- complete integration interval;
- sampling policy;
- selected pair;
- switching thresholds;
- random master seed and per-trial seed; and
- arbitrary case-specific parameters represented as ordered named values.

Unknown or inapplicable values must be represented explicitly as absent. They
must not be silently replaced by guessed defaults in a report.

### 6.3 Validation metric

Each metric record contains:

- `metric_id`: stable case-local identifier;
- `label`: human-readable description;
- `value`: retained typed value;
- `value_kind`: scalar, integer, Boolean, status, string, or finite sequence;
- `unit`: optional physical or logical unit;
- `scale`: absolute, relative, scaled, count, status, or descriptive;
- `role`: scientific or performance;
- `aggregation`: none, maximum, minimum, final, mean, quantile, count, or other
  declared aggregation;
- `finite`: whether every numeric component is finite; and
- optional notes identifying normalization or conditioning.

Metric identifiers must be stable and machine-friendly, for example:

```text
maximum_relative_energy_drift
maximum_scaled_state_error
minimum_pair_separation
accepted_steps
```

Labels may improve over time without changing identifiers.

A metric that is only descriptive must use `role = performance` or another
explicit non-scientific role. Merely recording elapsed time must never create an
implicit pass/fail rule.

### 6.4 Acceptance criterion

Each criterion contains:

- `criterion_id`: stable case-local identifier;
- `label`;
- `metric_id`;
- `relation`;
- `expected` or `limit`;
- optional absolute tolerance;
- optional relative tolerance;
- `observed`;
- `status`;
- `severity`;
- `rationale`; and
- optional provenance reference.

Initial supported relations should cover every current case:

- less than;
- less than or equal;
- greater than;
- greater than or equal;
- equal;
- approximately equal;
- Boolean is true;
- status equals expected status; and
- count equals or exceeds an expected count.

Criterion status is one of:

- `pass`;
- `fail`;
- `not_evaluated`; or
- `error`.

Scientific criteria use severity `required` by default. A future advisory
criterion may use severity `warning`, but warnings must never be counted as
passes or silently promoted to release evidence.

The human-readable rationale must explain why the criterion exists. The
provenance reference identifies the design document, analytic result, reviewed
baseline, or independent comparison from which the limit was derived.

### 6.5 Solver statistics

Solver work statistics are retained in a dedicated optional record because they
are widely shared and useful for both reproducibility and performance review.

Fields include, where available:

- accepted steps;
- rejected steps;
- right-hand-side evaluations;
- Jacobian evaluations;
- linear solves;
- nonlinear iterations;
- saved-state count;
- segment count;
- switch count; and
- elapsed seconds.

These fields are descriptive unless a case separately defines a scientific
criterion involving a count for a physical reason, such as requiring an
expected representation switch.

### 6.6 Execution outcome

Execution outcome is distinct from scientific evaluation.

Required fields:

- `status`: completed, expected_stop, expected_error, unexpected_stop,
  execution_error, or not_run;
- `exit_code` where a child process is used;
- `message`;
- exception type and concise error text when available;
- start and finish timestamps; and
- elapsed seconds.

A case can execute successfully but fail scientific criteria. Conversely, an
expected-stop validation can pass only when the recorded stop reason matches the
case definition.

### 6.7 Validation case result

A complete case result contains:

- schema identifier and version;
- case definition identity and version;
- reproducibility metadata;
- execution outcome;
- ordered metrics;
- ordered criteria;
- optional solver statistics;
- case-level status; and
- optional child results for sweep points or ensemble trials.

Case-level status is derived, not independently assigned:

- `pass` when execution matches the expected outcome and every required
  criterion passes;
- `fail` when execution matches the expected outcome but one or more required
  criteria fail;
- `error` when execution is incomplete or does not match the expected outcome;
  and
- `not_run` when the case was not attempted.

### 6.8 Validation suite result

A suite result contains:

- schema identifier and version;
- suite identifier;
- tier identifier;
- suite-definition version;
- common environment metadata;
- ordered case results;
- included and omitted case identifiers;
- suite start and finish timestamps;
- total elapsed seconds;
- counts by case-level status; and
- derived suite-level status.

A required case must never disappear silently. Any omitted registered case must
be listed with an explicit reason.

## 7. Sweep and ensemble extension

The schema must support V5-V3 and V5-V4 without redesigning the core model.

A sweep point or randomized trial is represented as a child case result with:

- a stable parent case identifier;
- a unique child identifier;
- complete varying parameters;
- master seed and per-trial seed where applicable;
- the generated initial condition or a lossless representation of it;
- its own execution outcome, metrics, criteria, and status; and
- an ordinal that preserves deterministic ordering.

Aggregate metrics may summarize children, but no aggregate may hide a failed
child. Parent status is fail or error whenever a required child fails or errors,
unless the child's expected outcome explicitly permits that result.

## 8. Deterministic serialization

### 8.1 Initial format

Stage V5-V1 should use a simple text format available without adding a heavy
runtime dependency. The exact choice will be made during implementation after
checking Julia standard-library support and repository compatibility.

Regardless of format, deterministic serialization requires:

- fixed top-level and nested field order;
- deterministic case, metric, criterion, and child-result ordering;
- locale-independent numeric formatting;
- explicit encoding of non-finite values rather than invalid numeric literals;
- UTC timestamps in one documented representation;
- lowercase stable enum strings;
- no memory addresses or unordered dictionary iteration;
- repository-relative paths; and
- a trailing newline.

Repeated serialization of the same in-memory result must be byte-for-byte
identical. Timestamp-bearing reports are identical only when the timestamp
fields are held fixed for the determinism test.

### 8.2 Numeric fidelity

Serialized values must preserve enough information to reconstruct the retained
numeric value for comparison purposes.

- ordinary finite integers and Float64 values use deterministic decimal text;
- BigFloat values record both precision and a deterministic decimal or
  hexadecimal representation sufficient for round-trip reconstruction;
- `NaN`, positive infinity, and negative infinity use explicit tagged strings;
- negative zero must be preserved when the format can represent it; and
- display rounding is never reused for stored values.

## 9. Console compatibility

The current console presentation should remain recognizable during V5-V1.

A structured implementation may continue to print:

- the case heading and description;
- relevant configuration;
- measured values;
- the acceptance table;
- case PASS/FAIL/ERROR and elapsed time; and
- the suite summary.

The console renderer must operate on retained records. Existing scripts should
not need to parse their own output, and the suite runner should not need to
infer metrics from child-process text.

During migration, a child script may write one structured report to a temporary
or requested path while continuing to stream human-readable output. The parent
runner then reads the structured report and retains stdout/stderr for diagnosis.

## 10. Scientific versus performance data

The separation is mandatory.

### 10.1 Scientific data

Scientific metrics characterize correctness, physical invariants, reference
agreement, supported termination, or numerical robustness. They may be bound to
required acceptance criteria.

Examples:

- relative energy drift;
- periodicity error;
- transition-state residual;
- event-time discrepancy;
- gauge-constraint residual; and
- state finiteness.

### 10.2 Performance data

Performance metrics describe computational work or resource use. They are
reported but do not determine scientific status.

Examples:

- elapsed seconds;
- allocations;
- accepted and rejected steps;
- right-hand-side evaluations; and
- saved-state count.

A switch count may be scientific in a case that explicitly requires switching,
while also being useful performance context. The metric role and criterion
relationship must therefore be explicit rather than inferred from its name.

## 11. Reference-value and tolerance policy

### 11.1 General rule

A reference value or tolerance is scientific evidence, not generated output to
be accepted automatically. It may change only through an explicit reviewed
commit.

### 11.2 Sources of acceptance limits

Every required limit must identify one or more of:

- an analytic or exact result;
- a mathematical invariant;
- an independently implemented formulation;
- a higher-precision reference calculation;
- a reviewed cross-platform baseline; or
- a documented supported-behaviour requirement.

A limit must not be chosen solely because the current implementation happens to
pass it.

### 11.3 Margin selection

The recorded rationale must distinguish:

- estimated reference uncertainty;
- integration and sampling error;
- conditioning near singular or nearly singular states;
- expected cross-platform floating-point variation; and
- an intentional regression-detection margin.

Margins should be tight enough to detect meaningful deterioration and broad
enough to avoid failures caused only by scientifically irrelevant platform
variation. Tightening a limit requires the same review as loosening one.

### 11.4 Changing a limit

A change to an accepted limit requires:

1. a written reason;
2. before-and-after results;
3. identification of whether the change reflects corrected science, expanded
   platform support, changed configuration, or accepted algorithmic behaviour;
4. review of all affected cases;
5. an increment to the affected case `definition_version`; and
6. a dedicated commit that does not hide unrelated numerical changes.

Loosening a limit merely to restore a passing suite is prohibited.

### 11.5 Changing a reference value

Reference generation and reference comparison must be separate actions.
Validation must never rewrite a reviewed reference file.

A changed reference requires:

- exact provenance, including package commit and environment metadata;
- successful package tests and all unaffected validation cases;
- independent review of the numerical difference;
- confirmation that no unexpected metric changed; and
- an explicit commit recording the new reference and its rationale.

### 11.6 Exact, tolerance-based, and trend-based comparisons

- **Exact comparison** is reserved for deterministic identifiers, counts,
  statuses, and values expected to be bitwise stable by construction.
- **Tolerance-based comparison** is used for floating-point scientific metrics
  with declared absolute or relative limits.
- **Trend-based comparison** may later describe long-duration or performance
  behaviour, but it cannot replace per-case scientific acceptance criteria.

## 12. Privacy, portability, and repository hygiene

Reports intended for repository retention must avoid machine-specific private
information.

- repository paths must be relative;
- user names and home-directory paths must not be stored;
- host names are omitted by default;
- operating system and architecture are retained in normalized form;
- source commit and dirty-state metadata are retained when available; and
- temporary paths and process identifiers are not part of deterministic
  reports.

## 13. Migration plan for Stage V5-V1

A safe implementation sequence is:

1. add focused internal validation record types without changing any existing
   script;
2. add unit tests for construction, status derivation, and invalid records;
3. adapt `validation_criterion` to construct the richer criterion record while
   preserving its current call surface;
4. add a case-result builder to one inexpensive validation case;
5. add deterministic serialization and round-trip or comparison tests;
6. add a console renderer based on retained records;
7. migrate the remaining cases one at a time without changing their limits;
8. allow each child process to emit a structured report;
9. update the suite runner to aggregate those reports while preserving captured
   diagnostic output; and
10. run package tests and the complete unchanged scientific suite after each
    small migration group.

Suggested commit boundaries remain those in the implementation plan:

1. `Add structured validation result types`
2. `Emit deterministic validation reports`

Case migrations may require additional narrowly scoped commits if reviewability
would otherwise suffer.

## 14. V5-V0 acceptance checklist

Stage V5-V0 is complete when:

- all eleven current suite entries appear in the inventory;
- the schema represents every current metric family;
- measurement, evaluation, and presentation are explicitly separated;
- environment and numerical reproducibility metadata are defined;
- scientific and performance roles are distinct;
- pass, fail, execution error, expected stop, and expected error are
  representable;
- deterministic serialization requirements are defined;
- reference and tolerance update policies are documented;
- no numerical source file or acceptance limit is changed; and
- the existing package tests and scientific suite remain unchanged.

# ThreeBody3D v0.5 Validation Architecture Design

## 1. Purpose

This document maps the approved validation-result model in
`V0_5_VALIDATION_SCHEMA_DESIGN.md` onto the ThreeBody3D repository and defines
the implementation architecture for Stage V5-V1.

The architecture preserves the existing scientific workflow while introducing
structured validation results. It specifies:

- ownership boundaries between package code and validation infrastructure;
- the proposed directory and module structure;
- internal types and interfaces;
- the lifecycle of one validation case and one validation suite;
- deterministic report serialization;
- migration of the current eleven validation cases;
- test strategy and compatibility requirements; and
- small implementation and commit boundaries.

This is a design document. It changes no numerical algorithm, solver setting,
acceptance criterion, validation configuration, or public API.

## 2. Governing principles

The implementation must preserve the project priorities:

1. scientific correctness before convenience;
2. numerical accuracy before execution speed;
3. explicit evidence instead of inferred success;
4. deterministic and reproducible validation;
5. clean separation of measurement, evaluation, and presentation;
6. no silent change to accepted limits or reference values;
7. small, independently reviewable commits; and
8. no expansion of the public package API without a demonstrated user need.

The structured framework is supporting scientific infrastructure. It is not a
new numerical feature and must not alter the calculations being validated.

## 3. Current architecture

### 3.1 Package-owned validation utilities

The package currently contains reusable scientific calculations in:

- `src/Validation.jl`; and
- `src/ValidationBenchmarks/`.

These include:

- periodicity error;
- close-approach reporting;
- solver comparison records;
- the figure-eight benchmark;
- the hierarchical-triple benchmark; and
- common benchmark reports.

These functions operate on package data and are useful independently of the
repository's complete release-validation suite. Some are part of the exported
API.

### 3.2 Repository-owned validation cases

The full scientific suite currently lives under `examples/validation/`, with
one standalone script per validation case and a separate-process runner in
`run_validation_suite.jl`.

The scripts currently combine some or all of:

- configuration;
- numerical execution;
- measurement;
- acceptance evaluation;
- console presentation; and
- process exit behaviour.

`AcceptanceCriteria.jl` provides a shared tuple constructor and console table,
but it throws immediately after a failed criterion and does not retain a
complete structured case result.

### 3.3 Existing strengths to preserve

The current design has important strengths:

- every case can be run directly;
- every case executes in an independent Julia process in the complete suite;
- child stdout and stderr remain visible;
- a failed case produces a nonzero process exit;
- the suite continues to subsequent cases after one failure;
- case failures are easy to reproduce from the displayed file path; and
- package tests and scientific validation remain distinct activities.

V5-V1 must preserve all of these behaviours.

## 4. Architectural decision: repository-owned framework

### 4.1 Decision

The structured suite framework will be owned by the repository under:

```text
examples/validation/framework/
```

It will not initially be included from `src/ThreeBody3D.jl`, and its types will
not be exported by the ThreeBody3D package.

### 4.2 Rationale

The complete validation suite contains repository and release-process concerns
that are not required by ordinary package users:

- repository-relative script paths;
- Git commit and dirty-tree metadata;
- child-process orchestration;
- suite tiers;
- reviewed reference provenance;
- report-file paths;
- release-gate summaries; and
- migration state for repository validation scripts.

Putting these concerns in `src` would enlarge the package runtime surface,
create compatibility obligations for internal release tooling, and risk
confusing validation infrastructure with the scientific API.

Keeping the framework under `examples/validation/` allows it to evolve under
schema versioning without implying that every internal record is a supported
package API.

### 4.3 Package boundary

The boundary is:

- **package code** owns reusable physical and numerical measurements that make
  sense outside the release suite;
- **validation framework code** owns case definitions, criteria, execution
  outcomes, structured reports, serialization, presentation, suite registry,
  tiers, and child-process orchestration; and
- **case scripts** own scientific configuration and case-specific measurement
  adapters.

A measurement should move into `src` only when it is generally useful, has a
stable meaning, and deserves package-level tests and documentation. It must not
be moved merely because the validation framework needs it.

## 5. Proposed repository structure

The target V5-V1 structure is:

```text
examples/validation/
├── framework/
│   ├── ValidationFramework.jl
│   ├── Types.jl
│   ├── Definitions.jl
│   ├── Metrics.jl
│   ├── Criteria.jl
│   ├── Outcomes.jl
│   ├── Metadata.jl
│   ├── CaseResults.jl
│   ├── SuiteResults.jl
│   ├── Serialization.jl
│   ├── ConsolePresentation.jl
│   ├── CaseProtocol.jl
│   └── ProcessRunner.jl
├── cases/
│   └── [future case adapters, only if migration later warrants them]
├── AcceptanceCriteria.jl
├── run_validation_suite.jl
└── [existing standalone validation scripts]

test/
└── validation_framework/
    ├── runtests.jl
    ├── types.jl
    ├── evaluation.jl
    ├── serialization.jl
    ├── presentation.jl
    ├── case_protocol.jl
    └── process_runner.jl
```

The final number of files may be reduced during implementation if adjacent
responsibilities remain clear. The ownership boundaries matter more than the
exact file count.

### 5.1 `ValidationFramework.jl`

This is the sole include point for validation scripts and the suite runner. It
creates an internal module:

```julia
module ValidationFramework

# includes

end
```

Case scripts should use one repository-relative include and import only the
names they need. They should not include individual framework files directly.

### 5.2 No immediate case-directory migration

The existing scripts should remain at their current paths during the first
V5-V1 implementation. Moving all files while changing their internal protocol
would create unnecessary review noise and make regressions harder to isolate.

A later dedicated commit may place adapters under `cases/` if the common
pattern becomes clear. File movement is not an acceptance requirement for
V5-V1.

## 6. Module ownership and dependency direction

Dependencies must point in one direction:

```text
ThreeBody3D package
        ↑
case-specific measurement code
        ↑
validation framework records and evaluation
        ↑
console / serialization presenters
        ↑
suite and child-process orchestration
```

More precisely:

- the validation framework may use the installed ThreeBody3D package;
- case scripts may use both ThreeBody3D and ValidationFramework;
- package source must not include or import ValidationFramework;
- core result types must not depend on console formatting or process execution;
- criteria may depend on metrics, but metrics must not depend on criteria;
- presentation may depend on complete results, but result construction must not
  depend on presentation; and
- serialization must not call numerical solvers or recompute metrics.

Circular inclusion between case scripts and framework files is prohibited.

## 7. Internal API surface

### 7.1 Stability status

All V5-V1 validation-framework names are internal repository interfaces. They
are governed by the validation schema and committed design documents, but they
are not exported from `ThreeBody3D` and are not covered by the package's public
API stability statement.

Stable identifiers in serialized reports have stronger compatibility
requirements than Julia constructor signatures. A refactoring may change an
internal type name but must not silently change the meaning of a stored field,
metric identifier, criterion identifier, case identifier, or enum value.

### 7.2 Constructor policy

Constructors must validate invariants at creation time. Invalid records should
not remain representable merely because a later renderer might detect them.

Examples of required construction checks include:

- nonempty stable identifiers;
- supported enum values;
- unique metric identifiers within a case;
- unique criterion identifiers within a case;
- criteria referencing existing metrics;
- finite flags consistent with retained numeric values;
- nonnegative counts and durations;
- ordered children with unique identifiers and ordinals;
- case status consistent with execution and criteria; and
- suite counts consistent with contained case results.

Derived status fields should be created by dedicated builders rather than
accepted as unrelated user input.

## 8. Core type architecture

The exact Julia field parameterization will be finalized during implementation,
but the following roles are fixed.

### 8.1 Stable identifier representation

Case, metric, criterion, suite, and tier identifiers should use `Symbol` in
memory where the set is controlled by repository code. Serialization renders
them as lowercase stable strings.

Free-form external identifiers and provenance references remain `String`.

Identifiers must use ASCII lowercase words separated by underscores. Human
labels may use full Unicode typography.

### 8.2 Enum representation

Closed status sets should use Julia `@enum` or validated symbols. The choice
must be consistent across the framework.

The preferred design is `@enum` for states whose membership is fixed by schema
version 1.0.0, including:

- metric kind;
- metric scale;
- metric role;
- aggregation kind;
- criterion relation;
- criterion status;
- criterion severity;
- expected execution outcome;
- actual execution outcome; and
- case and suite status.

Serialization must use explicit mapping functions. It must never depend on the
printed form or integer backing value of an enum.

Validated symbols remain appropriate for open tag sets and case-specific
parameter names.

### 8.3 `ValidationCaseDefinition`

This record owns stable case identity and declared behaviour. It must not
contain executable closures because definitions will be serialized, compared,
and registered independently of process execution.

The executable entry remains the repository-relative `source_path`.

The first implementation should include:

- `case_id`;
- title and description;
- classifications and tags;
- source path;
- tier membership;
- expected outcome;
- required flag;
- definition version; and
- optional provenance reference.

A registry must reject duplicate case identifiers and duplicate normalized
source paths.

### 8.4 Reproducibility records

Environment metadata and case numerical configuration should be separate
records.

This prevents common environment data from being repeated conceptually inside
suite logic while still allowing each standalone case report to be complete.

Recommended records are:

- `ValidationEnvironment` for package, repository, Julia, OS, architecture,
  thread, schema, and timestamp fields; and
- `ValidationConfiguration` for solver, tolerances, precision, initial
  conditions, interval, sampling, pair, thresholds, seeds, and ordered
  case-specific parameters.

Case-specific parameter values should not use an unordered `Dict`. Use an
ordered vector of named parameter records or a named tuple whose field order is
explicitly retained.

Git metadata collection is best-effort. Failure to execute Git must yield
explicit absent fields, not failure of the numerical validation.

### 8.5 Metric value model

A metric must retain a typed value without allowing arbitrary Julia objects.
The supported schema-1 value domain should be deliberately closed:

- `Bool`;
- signed and unsigned integers representable without loss;
- `Float32` and `Float64`;
- `BigFloat` with precision metadata;
- `Symbol` or validated status value;
- `String`; and
- finite sequences of the preceding scalar numeric or Boolean forms where a
  current case genuinely requires them.

Complex numbers, matrices, package-specific structs, functions, and opaque
serialized Julia objects are not part of schema 1. A case must convert such
objects into scientifically meaningful scalar or finite-sequence metrics.

The in-memory implementation may use a parametric `ValidationMetric{T}` so the
original numeric type is retained. A complete case result may therefore store a
heterogeneous vector through an abstract internal supertype or a small tagged
wrapper.

This controlled heterogeneity is acceptable in validation tooling, where
correct representation is more important than hot-loop performance.

### 8.6 `AcceptanceCriterion`

A criterion retains both the declared rule and its evaluation result.

Criterion construction occurs in two steps:

1. create a criterion specification referencing a metric identifier; and
2. evaluate the specification against the retained metric set to create an
   evaluated criterion.

This prevents callers from supplying a Boolean `passed` value unrelated to the
observed metric, which is possible in the current tuple helper.

The evaluator owns comparison semantics, including:

- finite-value requirements;
- approximate equality;
- absolute and relative tolerances;
- expected statuses;
- integer count comparisons; and
- type compatibility errors.

A criterion evaluation error must produce criterion status `error`; it must not
be converted into an ordinary scientific failure.

### 8.7 `SolverStatistics`

Solver statistics are optional and descriptive by default. The record should
contain optional fields rather than sentinel negative counts.

The first implementation should support the currently available SciML fields:

- accepted steps;
- rejected steps;
- right-hand-side evaluations;
- saved states;
- elapsed seconds;
- segment count; and
- switch count.

Additional optional fields may be added in a schema-compatible minor version.

### 8.8 `ExecutionOutcome`

Execution and scientific status remain independent.

A standalone in-process case normally records completed, expected stop, or
expected error. The parent process may replace or augment this with child exit
code, captured exception summary, timestamps, and elapsed time.

The process runner must distinguish:

- a child that wrote a valid report and exited as expected;
- a child that wrote a valid failing report and exited nonzero;
- a child that exited before writing a report;
- a child that wrote a malformed or incompatible report; and
- a child terminated by the host environment.

### 8.9 `ValidationCaseResult`

The case result is immutable after construction. It contains ordered metrics and
criteria and derives its final status from:

- expected versus actual execution outcome; and
- every required criterion status.

A builder may be mutable while a case runs, but the retained result passed to
presentation or serialization must be immutable and fully validated.

The builder should have an intentionally small interface:

```text
start case
record configuration
record metric
record solver statistics
evaluate criteria
finish execution
build immutable result
```

It must reject duplicate metrics and criteria rather than silently replacing an
earlier value.

### 8.10 `ValidationSuiteResult`

The suite result contains an ordered vector matching registry order, not child
completion order. This guarantees deterministic presentation even if parallel
execution is introduced in a later version.

V5-V1 remains sequential. Parallel execution is outside scope.

## 9. Case-definition registry

### 9.1 Single source of suite membership

The current `VALIDATION_SUITE_ENTRIES` tuple in `run_validation_suite.jl` should
be migrated into a registry file owned by the framework, for example
`Definitions.jl`.

The registry becomes the single source for:

- case identity;
- title and description;
- standalone source path;
- classification and tags;
- expected outcome;
- required status;
- definition version; and
- tier membership.

The runner must not maintain a second parallel list.

### 9.2 Tier selection

The registry supports the tiers defined in the v0.5 implementation plan:

- `quick`;
- `standard`;
- `extended`; and
- `performance`.

V5-V1 should implement tier metadata and deterministic selection, but it must
preserve the current complete eleven-case run as the default until Stage V5-V7
formally assigns and releases tier memberships.

In other words, adding the field is allowed; changing which cases run by
default is not part of V5-V1.

### 9.3 Definition versions

All current cases begin with an explicitly reviewed definition version, normally
`1`. A case version changes only when scientific meaning changes as defined in
`V0_5_VALIDATION_SCHEMA_DESIGN.md`.

Migration to structured reporting alone does not change a case's scientific
configuration and therefore does not require an increment after the initial
version is assigned.

## 10. Case execution protocol

### 10.1 Requirements

A case must remain directly executable:

```powershell
julia --project=. examples/validation/figure_eight_benchmark.jl
```

It must also support execution by the suite runner with a requested structured
report path.

The protocol must not require the parent process to parse console output.

### 10.2 Environment-variable protocol

The initial protocol should use reserved environment variables because each
existing case is a simple Julia script rather than a command-line application.

Recommended variables are:

```text
THREEBODY3D_VALIDATION_REPORT
THREEBODY3D_VALIDATION_CASE_ID
THREEBODY3D_VALIDATION_SCHEMA_VERSION
```

`THREEBODY3D_VALIDATION_REPORT` gives the requested output path. When absent,
the script behaves as a direct standalone case and need not write a report.

The case identifier and schema version allow the child to reject a mismatched
invocation before running an expensive calculation.

Environment variables avoid adding ad hoc argument parsing to every script and
avoid collisions with Julia's own command-line options. They must be read only
by the shared case protocol, not independently throughout case code.

### 10.3 Atomic report writing

A child must write to a temporary sibling path and atomically rename it to the
requested final path after serialization succeeds.

This prevents the parent from mistaking a partial report for a completed case.
The parent must remove stale requested and temporary paths before execution.

### 10.4 Exit semantics

After building and optionally writing the structured result, a standalone case
must retain current exit behaviour:

- pass: normal exit;
- scientific fail: nonzero exit;
- execution error: nonzero exit; and
- expected stop or expected error: normal exit only when the expectation and
  recorded reason match the case definition.

The structured report is authoritative for scientific details. The exit code
is authoritative for shell and CI compatibility. The parent verifies that they
are consistent.

### 10.5 Exceptions

A top-level shared case wrapper should catch unexpected exceptions long enough
to create an execution-error report when possible, then rethrow or exit nonzero
after report writing.

The exception record must be concise and deterministic. Full stack traces remain
in stderr for diagnosis and should not be embedded in reference reports because
they contain unstable paths and line numbers.

## 11. Measurement adapters

### 11.1 Case-specific ownership

Each existing case will initially retain its scientific calculation. Migration
extracts its measured quantities into named metric records without changing how
they are computed.

The migration must not:

- change initial conditions;
- change solver or tolerance selection;
- change integration intervals;
- change sampling;
- change event handling;
- change normalization;
- replace a directly computed value with a rounded printed value; or
- consolidate superficially similar metrics whose meanings differ.

### 11.2 Common helper threshold

A repeated measurement may become a shared helper only after at least two cases
use the same scientific definition and the helper can be tested independently.

Prematurely generalizing case-specific logic during protocol migration is
prohibited. The first goal is faithful retention, not minimum line count.

### 11.3 Existing benchmark reports

`ValidationBenchmarkReport` remains package-owned and unchanged during the
initial framework commit. Case adapters may translate its fields into generic
metrics and solver statistics.

The generic validation framework must not replace this public benchmark report
or force it to depend on repository-owned types.

## 12. Evaluation architecture

### 12.1 Central evaluator

All relation semantics belong in `Criteria.jl`. Individual cases declare rules;
they do not independently implement `<`, approximate equality, status matching,
or finite checks.

This centralization is required to make a stored criterion reproducible and to
avoid subtle differences between cases.

### 12.2 Relation-specific validation

Each criterion specification must be checked before evaluation. Examples:

- ordering comparisons require compatible ordered scalar values;
- approximate equality requires numeric values and valid nonnegative
  tolerances;
- Boolean relations require Boolean observed values;
- status equality requires a declared status domain;
- sequence metrics cannot be compared by scalar relations unless an explicit
  aggregation metric was separately recorded; and
- non-finite numeric observations fail required finite scientific comparisons
  unless the criterion explicitly expects a tagged non-finite state.

### 12.3 No callback criteria in reports

A criterion specification must not store an arbitrary function. Every supported
relation must have stable schema semantics.

A genuinely new comparison relation requires:

1. design review;
2. evaluator tests;
3. serialization mapping;
4. schema compatibility assessment; and
5. documentation of its scientific meaning.

### 12.4 Compatibility adapter

`AcceptanceCriteria.jl` should temporarily become a compatibility facade over
the new evaluator and console renderer.

During migration it may retain the existing function names, but new code should
not construct criteria from a caller-supplied `passed` Boolean. Once all eleven
cases use structured specifications, the legacy tuple path can be removed in a
separate commit with explicit test coverage.

## 13. Presentation architecture

### 13.1 Console rendering

`ConsolePresentation.jl` owns all human-readable validation output generated
from retained records.

It should provide distinct functions for:

- case definition/configuration heading;
- metric summary;
- acceptance table;
- execution and case status;
- suite case table; and
- failure details.

Renderers accept an `IO` argument so tests can use `IOBuffer` without capturing
global stdout.

### 13.2 Compatibility objective

The existing output need not be byte-for-byte identical, but it must remain
recognizable and contain at least the same scientific evidence. Any deliberate
wording or ordering change should be reviewed independently from numerical
migration.

During the first migration commits, preserving current headings, metric labels,
and PASS/FAIL summaries is preferred.

### 13.3 Presentation purity

A renderer must not:

- run a solver;
- derive a new scientific metric;
- reevaluate a criterion;
- mutate a result;
- choose a case status;
- update a reference; or
- omit a failed required criterion.

Formatting precision may differ from retained precision, and the renderer must
make that distinction clear in implementation tests.

## 14. Serialization architecture

### 14.1 Chosen initial format

The initial machine-readable format should be deterministic TOML-like text
written by a framework-owned serializer, using only Julia standard-library
functionality.

The report file extension should be:

```text
.toml
```

The serializer must control field order and numeric encoding directly rather
than relying on unordered container traversal.

### 14.2 Why not Julia `Serialization`

Julia's binary `Serialization` format is inappropriate for scientific evidence
because it is implementation-specific, not intended as a durable interchange
format, difficult to inspect in code review, and capable of preserving opaque
Julia objects outside the approved schema.

### 14.3 Why not add JSON immediately

A conventional JSON package would add a new dependency solely for repository
validation infrastructure. That may become worthwhile later, but V5-V1 can
avoid it while the schema and migration are still being proven.

The architecture must keep the object-to-report mapping format-neutral so a
future deterministic JSON renderer can be added without changing case
measurement or evaluation.

### 14.4 Tagged numeric values

To retain numeric fidelity across ordinary floats, BigFloat, negative zero, and
non-finite values, metrics should serialize values as tagged records rather than
assuming every value can be represented by a native TOML number.

Conceptually:

```text
value_kind = "float64"
value_text = "1.2345678901234567e-12"
```

or:

```text
value_kind = "bigfloat"
precision_bits = 256
value_text = "...deterministic round-trippable representation..."
```

Integers and Booleans may still use tagged canonical text for uniform decoding.
The exact textual representation must have round-trip tests before adoption.

### 14.5 Reader and writer

V5-V1 requires both:

- a deterministic writer; and
- a strict reader that validates schema identity, version, required fields,
  enum strings, value tags, uniqueness, and derived-status consistency.

The reader must reject unknown major schema versions. It may accept documented
optional fields from compatible minor versions.

### 14.6 Determinism boundary

A report containing current timestamps and elapsed time is not byte-identical
across separate executions. Determinism means:

- identical in-memory records serialize identically;
- fixed timestamps and elapsed values produce byte-identical files;
- ordering does not depend on hash iteration, process ID, temporary path, or
  memory address; and
- scientifically equivalent but differently ordered input collections are
  normalized or rejected according to the schema.

## 15. Process-runner architecture

### 15.1 Parent responsibilities

`ProcessRunner.jl` owns:

- constructing the child command;
- supplying protocol environment variables;
- selecting a temporary report location;
- streaming child stdout and stderr;
- measuring host-observed elapsed time;
- recording exit code or process exception;
- reading and validating the child report;
- reconciling report status with exit status;
- creating an execution-error result when no valid report exists; and
- returning one complete case result without throwing for an ordinary case
  failure.

A configuration or framework invariant violation may throw because it means the
suite itself is invalid.

### 15.2 Output capture

The first implementation should preserve live child output. Capturing a second
copy for reports is optional and should not be added until storage, size, and
path-scrubbing policies are designed.

The suite result stores concise messages, not the full child transcript.

### 15.3 Sequential execution

Cases remain sequential in registry order. This preserves diagnostic clarity,
resource expectations, and current behaviour.

Parallel case execution is explicitly outside V5-V1 because it changes timing,
resource contention, output ordering, and failure diagnosis.

### 15.4 Temporary files

Report temporary files should be created in a suite-owned temporary directory
that is removed after reports are read. A user-requested persistent report
output directory can be added later.

Temporary paths must never appear in deterministic serialized scientific
content.

## 16. Standalone case lifecycle

The intended lifecycle of one migrated case is:

1. include and import `ValidationFramework`;
2. resolve and validate the expected registered case definition;
3. start a case-result builder and collect environment/configuration metadata;
4. run the unchanged scientific calculation;
5. record unrounded measurements as metrics;
6. translate solver work into optional solver statistics;
7. declare criterion specifications with rationale and provenance;
8. evaluate all criteria centrally;
9. record the actual execution outcome;
10. build and validate the immutable case result;
11. render the console report from that result;
12. atomically write the structured report when requested; and
13. exit consistently with the derived case status.

No console line is an input to any later step.

## 17. Suite lifecycle

The intended lifecycle of the complete suite is:

1. load and validate the case registry;
2. select the requested case set, preserving registry order;
3. collect common host environment metadata;
4. execute each case in a separate child process;
5. retain one structured result for every selected case, including errors;
6. explicitly list any omitted registered case and reason;
7. derive suite counts and suite status;
8. render the console summary from the suite result;
9. optionally serialize the suite result; and
10. exit nonzero unless every required selected case passes.

The parent must never infer a PASS solely from exit code zero when a structured
report was requested.

## 18. Migration strategy for the eleven cases

### 18.1 General order

Migration should proceed from structurally simple cases to cases with nested
trials or switching-specific outcomes.

Recommended order:

1. figure-eight benchmark;
2. hierarchical-triple benchmark;
3. equilateral triple-collision reference;
4. close-encounter comparison;
5. KS Kepler validation;
6. KS collision continuation;
7. KS and Levi-Civita comparison;
8. KS hierarchical triple;
9. long-duration switching diagnostics;
10. KS switching comparison; and
11. randomized regression validation.

### 18.2 Pilot cases

The figure-eight and hierarchical-triple cases should be the first pilot pair
because both already return `ValidationBenchmarkReport` and share broad
conservation metrics while differing in periodic and hierarchy-specific
criteria.

The pilot validates that the framework supports both shared and case-specific
metrics without changing package-owned benchmark reports.

### 18.3 Expected-stop and expected-error cases

Cases that intentionally exercise stopping or error policies must not be
migrated until `ExecutionOutcome` and expected-outcome evaluation are tested.
Their successful nonstandard termination must never be flattened into a generic
Boolean pass.

### 18.4 Randomized case

The randomized regression validation migrates last because it motivates child
trial results, seed provenance, aggregate metrics, and failure reproduction.

V5-V1 may first retain its current aggregate metrics in one case result if the
approved schema's full per-trial model is scheduled for V5-V4. The architecture
must not block later addition of child results.

## 19. Testing architecture

### 19.1 Test location

Framework tests belong under `test/validation_framework/` and are included from
`test/runtests.jl`.

They should use small synthetic records and tiny helper child scripts. Normal
package tests must not run the full scientific suite.

### 19.2 Unit-test groups

Required unit tests include:

#### Types and invariants

- valid construction of every core record;
- rejection of empty or malformed identifiers;
- duplicate metric and criterion detection;
- invalid enum and relation rejection;
- negative counts and durations rejected;
- inconsistent finite flags rejected;
- criteria referencing absent metrics rejected; and
- derived status consistency.

#### Evaluation

- every supported comparison relation;
- boundary equality;
- absolute and relative approximate comparisons;
- zero and signed-zero behaviour;
- Float32, Float64, integer, and BigFloat observations;
- NaN and infinities;
- type mismatch producing criterion error; and
- required versus warning severity.

#### Serialization

- deterministic field order;
- byte-identical repeated writes of fixed records;
- round-trip of every value kind;
- BigFloat precision and value round-trip;
- negative zero;
- explicit non-finite tags;
- Unicode labels;
- trailing newline;
- rejection of malformed reports;
- rejection of incompatible schema major version; and
- repository-relative path enforcement.

#### Presentation

- console rendering to `IOBuffer`;
- pass, fail, error, expected stop, and not-run labels;
- failed required criteria always shown;
- display rounding does not mutate retained values; and
- stable ordering.

#### Case protocol

- standalone execution without report path;
- requested report written atomically;
- mismatched case identifier rejected;
- mismatched schema version rejected;
- scientific failure writes a report then exits nonzero; and
- unexpected exception produces an execution-error report when possible.

#### Process runner

- passing child;
- scientifically failing child;
- child exits before report;
- malformed report;
- inconsistent exit code and report status;
- missing source path;
- output remains visible; and
- later cases run after one case failure.

### 19.3 Integration tests

After pilot migration, tests should compare old and new paths for the same
retained benchmark values and pass/fail decision.

The comparison must use unrounded metrics, not console text. Any difference
requires investigation before migrating further cases.

### 19.4 Scientific validation

After all eleven cases are migrated:

- `Pkg.test()` must pass;
- the complete scientific suite must report 11/11 PASS;
- each case must remain directly executable;
- the parent suite must consume structured reports without parsing stdout; and
- reviewed before-and-after numerical metrics must agree within exact equality
  where calculations are unchanged, or within a justified representation-only
  comparison where numeric type conversion is unavoidable.

No acceptance limit may be changed in the migration commit.

## 20. Error and failure policy

The framework distinguishes four classes of problem:

1. **scientific failure**: calculation completed but a required criterion failed;
2. **expected nonstandard execution**: declared stop or error occurred with the
   expected reason;
3. **case execution error**: the calculation or case adapter failed
   unexpectedly; and
4. **framework error**: invalid registry, schema, report, or internal invariant.

Scientific failures and case execution errors become retained case results so
the suite can continue. Framework errors may stop the suite because subsequent
results cannot be trusted.

The console must use distinct labels and messages for these categories.

## 21. Public API and documentation policy

### 21.1 No public exports in V5-V1

No ValidationFramework type or function will be added to the `ThreeBody3D`
export list during V5-V1.

This avoids premature API commitment while the framework is validated across
all eleven cases.

### 21.2 Future promotion criteria

A framework concept may be considered for package-level exposure only when:

- it is useful to package users outside repository release validation;
- its semantics have remained stable through at least one release cycle;
- it does not expose repository paths or Git assumptions;
- it has package docstrings and public API tests; and
- promotion simplifies rather than duplicates the scientific API.

### 21.3 Documentation outputs

V5-V1 should document:

- how to run one case;
- how to run the complete suite;
- how to request a structured report;
- schema identifier and version;
- case and suite status meanings; and
- the prohibition on automatically rewriting references.

Detailed user-facing tier documentation belongs to V5-V7.

## 22. Dependency policy

The initial framework should use Julia standard libraries and existing project
dependencies only.

A new external dependency requires a separate reviewed decision considering:

- scientific necessity;
- maintenance and compatibility burden;
- deterministic behaviour;
- transitive dependency size;
- support for Julia 1.10 and later; and
- whether the functionality belongs in package runtime or repository tooling.

The validation architecture must not require GLMakie or graphical display.
Validation cases should remain suitable for headless CI.

If a standard library is imported by code executed in the project environment,
its Project.toml declaration must follow Julia package dependency rules and be
added in a dedicated, explained commit.

## 23. Performance considerations

The framework is not in an integration hot loop. Clarity, correctness, and
numeric fidelity take precedence over micro-optimization.

Nevertheless:

- metrics should be computed once;
- presentation and serialization reuse retained records;
- child processes should not rerun a case to produce different formats;
- report reading should be linear in report size;
- suite ordering should not require repeated searches through large collections;
  and
- framework overhead should be measured separately during V5-V6 if it becomes
  material.

Elapsed time from the existing validation remains descriptive and must not be
made a V5-V1 pass/fail criterion.

## 24. Security and trust boundaries

Structured reports are data, not executable Julia source.

The reader must never use `eval`, deserialize arbitrary Julia objects, execute
paths contained in a report, or load modules named by report content.

The parent chooses executable case paths from the reviewed registry. A child
report may identify its source path, but cannot redirect the runner to another
program.

Repository-relative path normalization must reject traversal outside the
repository root.

## 25. V5-V1 implementation increments

V5-V1 should be implemented through the following small commits.

### V5-V1a — Core structured records

Add:

- framework module skeleton;
- stable enums and mappings;
- definitions, metadata, metrics, criterion specifications, outcomes, solver
  statistics, case results, and suite results;
- constructor invariants; and
- unit tests for types and derived status.

No existing validation script changes.

Suggested commit intent:

```text
Add structured validation result types
```

### V5-V1b — Central criterion evaluation

Add:

- relation evaluator;
- approximate-comparison rules;
- finite and type checks;
- criterion-result construction; and
- exhaustive evaluator tests.

Adapt `AcceptanceCriteria.jl` only enough to support compatibility tests. No
scientific limits change.

Suggested commit intent:

```text
Add structured validation criterion evaluation
```

### V5-V1c — Deterministic report serialization

Add:

- canonical value encoding;
- deterministic case and suite writer;
- strict reader;
- atomic report writing helper; and
- serialization and malformed-input tests.

Suggested commit intent:

```text
Add deterministic validation reports
```

### V5-V1d — Console presentation and case protocol

Add:

- case and suite console renderers;
- result builder or case wrapper;
- environment-variable protocol;
- exit-semantics helpers; and
- protocol tests using synthetic cases.

Suggested commit intent:

```text
Add validation case reporting protocol
```

### V5-V1e — Pilot benchmark migration

Migrate:

- figure-eight; and
- hierarchical-triple.

Demonstrate unchanged measurements, criteria, standalone behaviour, and suite
behaviour. Retain `ValidationBenchmarkReport` unchanged.

Suggested commit intent:

```text
Migrate core benchmarks to structured validation
```

### V5-V1f — Structured process runner

Migrate the suite runner to:

- the validated registry;
- child requested report paths;
- strict report reading;
- exit/report consistency checks; and
- structured suite summary.

The remaining unmigrated cases may temporarily use an explicit legacy adapter
only if it cannot be mistaken for a structured scientific report. The preferred
approach is to complete case migration promptly rather than maintain a long-term
mixed mode.

Suggested commit intent:

```text
Collect structured validation suite results
```

### V5-V1g — Remaining deterministic cases

Migrate the fixed-reference, close-encounter, and KS cases that do not require
nested trials. Preserve all calculations and criteria.

This may be split into multiple commits if review size becomes large.

Suggested commit intents should name the migrated case group.

### V5-V1h — Switching and randomized cases

Migrate:

- long-duration switching diagnostics;
- KS switching comparison; and
- randomized regression validation.

Record seeds and all switching configuration required by the approved schema.
Do not expand trial counts or alter stress coverage in this stage.

Suggested commit intent:

```text
Complete structured validation case migration
```

### V5-V1i — Cleanup and documentation

After all cases use the structured path:

- remove obsolete tuple-based compatibility code;
- document report generation and schema version;
- verify direct execution of every case;
- run package tests and 11/11 scientific validation; and
- record migration evidence.

Suggested commit intent:

```text
Complete structured validation reporting
```

## 26. V5-V1 acceptance criteria

Stage V5-V1 is complete only when all of the following hold:

1. measurement, evaluation, and presentation are separate in code;
2. all eleven registered cases produce validated structured case results;
3. the suite runner consumes structured reports and never parses console output;
4. every current case remains directly executable;
5. child cases continue to run in separate Julia processes;
6. scientific failure, execution error, expected stop, and expected error remain
   distinguishable;
7. report serialization is deterministic for fixed records;
8. ordinary and BigFloat metric values round-trip with required fidelity;
9. case, metric, and criterion identifiers are stable and unique;
10. no current scientific metric, numerical configuration, or acceptance limit
    changes as part of migration;
11. console output remains scientifically complete and recognizable;
12. package tests pass;
13. framework unit and integration tests pass;
14. the full suite reports 11/11 PASS; and
15. no framework type is added to the public ThreeBody3D export list.

## 27. Deferred decisions

The following are intentionally deferred:

- persistent reference-result archive layout, to V5-V5;
- formal quick, standard, extended, and performance membership, to V5-V7;
- parameter-sweep parent and child case implementation, to V5-V3;
- full randomized per-trial result trees, to V5-V4 if not required earlier;
- performance-baseline storage, to V5-V6;
- parallel suite execution;
- remote result databases or dashboards;
- automatic CI publication of reports;
- promotion of validation-framework types into the package API; and
- JSON or other additional report formats.

Deferral prevents V5-V1 from becoming a general workflow project before the
core scientific-reporting architecture is proven.

## 28. Recommended next action

After this design is accepted, begin **V5-V1a — Core structured records**.

Before modifying any repository file, inspect the exact current versions of:

- `examples/validation/AcceptanceCriteria.jl`;
- `examples/validation/run_validation_suite.jl`;
- `src/ValidationBenchmarks/Reports.jl`;
- `test/runtests.jl`; and
- `Project.toml`.

The first implementation patch should add only the framework module, core
records, invariants, and unit tests. It should not migrate a scientific case or
change any existing console output.

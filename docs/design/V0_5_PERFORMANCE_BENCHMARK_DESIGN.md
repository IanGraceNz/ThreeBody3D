# ThreeBody3D v0.5 Performance Benchmark Design

## 1. Purpose

This document defines Stage V5-V6 of the ThreeBody3D v0.5 implementation
plan: reproducible performance benchmarking that remains strictly separate from
scientific validation.

The performance framework exists to answer descriptive engineering questions:

- how much computational work does a fixed numerical configuration require;
- how variable is elapsed time under repeated execution;
- how many allocations and allocated bytes are observed when those quantities
  can be measured reliably;
- how does computational work change when accuracy requirements change; and
- whether an observed performance change deserves investigation.

It does **not** decide whether a simulation is scientifically correct. Existing
scientific criteria, validation status, approved scientific references, and
release evidence remain authoritative for correctness.

## 2. Governing principles

The design follows these rules.

1. **Scientific acceptance is independent.** A performance observation cannot
   pass, fail, weaken, replace, or reinterpret a scientific criterion.
2. **Performance is descriptive.** Reports present measurements and variability;
   they do not make automatic regression decisions in V5-V6.
3. **Configuration is explicit.** Every retained result records the benchmark,
   numerical configuration, environment, warm-up policy, sample count, and
   measurement policy.
4. **Compilation is not silently mixed with steady-state timing.** Warm-up is
   explicit and excluded from retained samples unless a future benchmark is
   deliberately defined to measure first-use latency.
5. **Repeated samples are mandatory for elapsed time.** A single wall-clock
   observation is never treated as evidence of improvement or regression.
6. **Work counts are preferred for portability.** Accepted steps, rejected
   steps, right-hand-side evaluations, and saved states are retained whenever
   available because they are more comparable across machines than time.
7. **Raw samples are preserved.** Summary statistics supplement rather than
   replace the individual observations.
8. **No hidden tuning.** Solver, tolerances, precision, interval, sampling, and
   benchmark-specific parameters are fixed before a run and retained in the
   report.
9. **No automatic baseline rewriting.** V5-V6 does not introduce an approved
   performance baseline or a command that updates one.
10. **Repository validation remains runnable without benchmarking.** Package
    tests and scientific validation do not depend on performance tooling.
11. **The performance framework is a thin extension of validation
    infrastructure.** Existing validated configuration, environment,
    serialization, presentation, and runner components are reused whenever that
    can be done without reducing clarity or scientific correctness. V5-V6 must
    not grow into a second general-purpose validation framework.
12. **Numerical robustness takes precedence over benchmark speed.** Performance
    measurements guide engineering decisions; they do not define scientific
    success. A faster configuration is not preferred when it weakens accuracy or
    robustness unless equivalent scientific behaviour has first been
    demonstrated by the independent validation framework.

## 3. Scope

### 3.1 Included in V5-V6

V5-V6 will provide:

- immutable performance benchmark definitions;
- immutable per-sample observations;
- deterministic aggregate summaries;
- immutable benchmark and suite reports;
- deterministic TOML serialization and strict reading;
- console presentation;
- a process-isolated benchmark runner;
- explicit warm-up and repetition policies;
- work-count, elapsed-time, and optional allocation measurements;
- accuracy-versus-work benchmark series; and
- focused unit and integration tests.

### 3.2 Excluded from V5-V6

The following are deliberately deferred:

- pass/fail performance thresholds;
- automatic regression alarms;
- approved performance baselines;
- cross-machine ranking;
- remote dashboards or databases;
- continuous background collection;
- statistical significance claims;
- parallel benchmark execution;
- automatic solver retuning;
- changing scientific tolerances to improve speed; and
- formal `performance` tier integration, which belongs to V5-V7.

## 4. Relationship to the existing validation framework

The existing validation framework already retains:

- `ValidationEnvironment`;
- `ValidationConfiguration`;
- `SolverStatistics`;
- `ExecutionOutcome`;
- elapsed seconds;
- metrics with `role_performance`; and
- deterministic serialization infrastructure.

Those capabilities remain useful, but `ValidationCaseResult` is not the correct
container for a performance suite because it represents one scientific case
execution with criteria and one derived scientific status. Performance
benchmarking requires multiple raw timing observations, explicit warm-up
records, variability summaries, and optional accuracy-versus-work series.

V5-V6 therefore introduces a separate set of performance report records inside
the repository-only `ValidationFramework` module. These records may reuse
validated configuration and environment types, but they must not contain
`AcceptanceCriterion`, `ValidationCaseStatus`, or `ValidationSuiteStatus`.

No V5-V6 type is exported from the public `ThreeBody3D` package module.

## 5. Terminology

- **Benchmark definition**: stable metadata identifying one performance
  experiment and its source implementation.
- **Warm-up run**: an execution performed to trigger compilation and initialize
  caches; it is recorded as policy metadata but excluded from retained timing
  samples.
- **Sample**: one measured execution after warm-up.
- **Work count**: a deterministic or near-deterministic algorithmic count such
  as accepted steps or right-hand-side evaluations.
- **Timing sample**: elapsed wall-clock duration for one measured execution.
- **Allocation sample**: allocated bytes and allocation count for one measured
  execution when supported by the measurement method.
- **Benchmark report**: all raw samples and summaries for one fixed definition
  and configuration.
- **Performance suite report**: an ordered collection of benchmark reports from
  one runner invocation.
- **Accuracy-versus-work series**: repeated benchmark reports over an explicit
  ordered set of numerical configurations, retaining both scientific error
  measures and work counts without deriving scientific acceptance.

## 6. Proposed record model

### 6.1 `PerformanceBenchmarkDefinition`

Stable metadata for one benchmark:

```julia
struct PerformanceBenchmarkDefinition
    benchmark_id::Symbol
    title::String
    description::String
    source_path::String
    classifications::Tuple{Vararg{Symbol}}
    tags::Tuple{Vararg{Symbol}}
    definition_version::String
    required_measurements::Tuple{Vararg{Symbol}}
    provenance::Union{Nothing,String}
end
```

Invariants:

- identifiers use the existing lowercase underscore convention;
- source paths are repository-relative;
- classifications, tags, and required measurements are unique;
- at least one required measurement is declared;
- the definition version uses `major.minor.patch` form; and
- changes to numerical configuration or measurement policy require a definition
  version change.

### 6.2 `PerformanceMeasurementPolicy`

Explicit execution and measurement policy:

```julia
struct PerformanceMeasurementPolicy
    warmup_runs::Int
    sample_runs::Int
    collect_elapsed_time::Bool
    collect_allocated_bytes::Bool
    collect_allocation_count::Bool
    collect_gc_time::Bool
    garbage_collection_before_sample::Bool
    process_isolation::Bool
    timing_clock::Symbol
end
```

Initial V5-V6 rules:

- `warmup_runs >= 1` for steady-state benchmarks;
- `sample_runs >= 3` when elapsed time is collected;
- process isolation is required for registered suite benchmarks;
- the initial timing clock is Julia's monotonic elapsed-time facility;
- allocation metrics may be omitted when reliable measurement is unavailable;
- allocation collection must not be inferred from elapsed timing; and
- any GC policy is recorded exactly.

The design does not prescribe a universal sample count larger than three.
Registered benchmarks may choose a higher fixed count based on runtime and
variability, but the choice is part of their definition and tests.

To keep routine use simple, V5-V6 will provide a small set of named policy
constructors that expand to explicit `PerformanceMeasurementPolicy` values:

- `QuickBenchmark()` for local development checks with the minimum valid
  steady-state repetition count and elapsed-time measurement only;
- `StandardBenchmark()` as the default registered-suite policy, with a fixed
  moderate sample count and the measurements supported reliably by the runner;
  and
- `PublicationBenchmark()` for deliberately higher repetition counts and the
  fullest reliable measurement set when preparing retained scientific or
  release evidence.

The exact field values for these constructors will be fixed and tested during
V5-V6a implementation. Their expanded `PerformanceMeasurementPolicy` is always
retained in reports, so the convenience API does not hide the actual measurement
protocol. Advanced callers may construct `PerformanceMeasurementPolicy`
directly.

### 6.3 `PerformanceSample`

One retained post-warm-up observation:

```julia
struct PerformanceSample
    sample_index::Int
    elapsed_seconds::Union{Nothing,Float64}
    allocated_bytes::Union{Nothing,Int}
    allocation_count::Union{Nothing,Int}
    gc_seconds::Union{Nothing,Float64}
    solver_statistics::Union{Nothing,SolverStatistics}
    saved_states::Union{Nothing,Int}
    measurements::Tuple{Vararg{ValidationMetric}}
end
```

Rules:

- sample indices are positive and contiguous within a report;
- durations and counts are finite and nonnegative;
- retained custom metrics must have `role_performance` or `role_descriptive`;
- scientific acceptance metrics are not copied into a sample as acceptance
  evidence;
- solver statistics retain accepted steps, rejected steps, RHS evaluations,
  saved states, and optional elapsed time where already available; and
- duplicated measurements are rejected.

The benchmark implementation must return the scientific output needed to
calculate descriptive accuracy metrics, but the timing boundary must exclude
report formatting, TOML writing, and console output.

### 6.4 `PerformanceSummary`

Deterministic summaries computed only from raw samples:

```julia
struct PerformanceSummary
    sample_count::Int
    elapsed_minimum::Union{Nothing,Float64}
    elapsed_median::Union{Nothing,Float64}
    elapsed_mean::Union{Nothing,Float64}
    elapsed_maximum::Union{Nothing,Float64}
    elapsed_standard_deviation::Union{Nothing,Float64}
    allocated_bytes_minimum::Union{Nothing,Int}
    allocated_bytes_median::Union{Nothing,Float64}
    allocated_bytes_maximum::Union{Nothing,Int}
    allocation_count_minimum::Union{Nothing,Int}
    allocation_count_median::Union{Nothing,Float64}
    allocation_count_maximum::Union{Nothing,Int}
end
```

The initial summary intentionally uses conventional descriptive statistics and
makes no inferential claim. Median is the primary displayed timing statistic;
minimum, mean, maximum, and standard deviation expose variability.

Summaries are recomputed and checked by the strict reader rather than trusted
blindly if retained in TOML.

### 6.5 `PerformanceBenchmarkReport`

One fixed benchmark configuration:

```julia
struct PerformanceBenchmarkReport
    definition::PerformanceBenchmarkDefinition
    environment::ValidationEnvironment
    configuration::ValidationConfiguration
    policy::PerformanceMeasurementPolicy
    samples::Tuple{Vararg{PerformanceSample}}
    summary::PerformanceSummary
    execution::ExecutionOutcome
end
```

Rules:

- reports are immutable;
- all retained samples follow the same definition, configuration, and policy;
- sample count matches the policy;
- the report retains raw samples in execution order;
- report execution status describes whether measurement completed, not whether
  performance was acceptable;
- a completed report contains every required measurement;
- a failed benchmark process is represented as an execution error, never a
  scientific failure; and
- timestamps originate from `ValidationEnvironment`, not the formatter.

### 6.6 `PerformanceSuiteReport`

Ordered result of one benchmark runner invocation:

```julia
struct PerformanceSuiteReport
    suite_id::Symbol
    title::String
    schema_version::String
    environment::ValidationEnvironment
    benchmarks::Tuple{Vararg{PerformanceBenchmarkReport}}
end
```

The suite has no pass/fail status. A helper may report whether every benchmark
completed, but this is execution completeness rather than performance
acceptance.

## 7. Accuracy-versus-work representation

Accuracy-versus-work comparisons are scientifically useful because they avoid
reducing performance to wall-clock speed alone. V5-V6 will represent these as
an explicitly ordered series of fixed configurations.

Each point must retain:

- the full `ValidationConfiguration`;
- a named descriptive error metric;
- accepted and rejected steps where available;
- RHS evaluations where available;
- saved-state count;
- median elapsed time;
- raw timing samples; and
- environment and definition metadata.

The error metric may be derived from an analytic solution, a high-precision
reference, a periodicity residual, or another benchmark-specific measure. It is
labelled descriptive in the performance report. Existing scientific validation
continues to determine whether the method is acceptable.

V5-V6 will not combine unlike error measures into a global score and will not
claim one solver is universally superior.

## 8. Initial benchmark inventory

The first suite should be compact enough for deliberate local execution while
covering representative numerical regimes.

### 8.1 Figure-eight steady-state benchmark

Purpose:

- representative smooth periodic three-body integration;
- solver work counts;
- elapsed-time variability; and
- accuracy-versus-work over a small fixed tolerance set.

Retained work measures:

- accepted steps;
- rejected steps;
- RHS evaluations;
- saved states; and
- elapsed samples.

Descriptive accuracy measures should reuse the existing energy-drift and
periodicity calculations without changing their scientific criteria.

### 8.2 Hierarchical-triple steady-state benchmark

Purpose:

- longer multi-scale integration;
- comparison with the figure-eight workload; and
- accuracy-versus-work in a stable hierarchical regime.

Retained work and descriptive accuracy measures should reuse the existing
structured benchmark calculations.

### 8.3 Close-encounter method comparison benchmark

Purpose:

- compare Cartesian, automatic-switching, and explicit regularized paths under
  one fixed close-encounter configuration;
- retain method-specific work counts; and
- expose the cost of robust close-encounter treatment without weakening the
  scientific comparison.

The report must preserve method labels and may not aggregate unlike methods into
one misleading total except where the existing composed trajectory naturally
reports total segment work.

### 8.4 KS switching benchmark

Purpose:

- exercise regularized switching overhead;
- retain switch and segment counts as descriptive metrics; and
- compare work counts with the existing Cartesian or alternative path where the
  scientific benchmark already defines that comparison.

### 8.5 Deferred benchmarks

BigFloat reference generation and large randomized ensembles are not initial
steady-state timing benchmarks. Their runtimes and variability require separate
policies and may be added after the core framework is validated.

## 9. Benchmark configuration policy

Every registered benchmark must declare its complete numerical configuration
in code. Environment variables may select output paths or a future suite tier,
but must not silently modify solver, tolerances, duration, sample count, or
measurement policy.

A benchmark configuration includes, as applicable:

- solver algorithm or profile;
- absolute and relative tolerances;
- arithmetic precision;
- integration interval;
- save policy;
- selected pair;
- close-approach thresholds;
- switching thresholds and hysteresis;
- regularized solver choices;
- random seeds; and
- benchmark-specific parameters.

A configuration change that affects comparability requires either a new
benchmark identifier or an incremented definition version with an explicit
rationale.

## 10. Warm-up and compilation policy

Each child benchmark process follows this order:

1. load the package and benchmark module;
2. construct immutable benchmark inputs;
3. execute the declared number of warm-up runs;
4. optionally invoke garbage collection according to policy;
5. execute retained samples without console rendering or serialization inside
   the timed region;
6. construct and validate the immutable report;
7. write the child report atomically; and
8. exit with success only when the report is complete and valid.

Warm-up outputs are discarded except for errors. They are not included in raw
sample arrays or summaries.

The runner must not describe warm-up time as benchmark time. First-use latency
would require a separate future benchmark definition and a fresh-process policy.

## 11. Timing policy

Elapsed time is measured with a monotonic clock around only the benchmarked
operation. The timed region excludes:

- package loading;
- benchmark input construction when inputs can be reused safely;
- console output;
- report construction;
- summary calculation;
- TOML serialization; and
- file I/O unrelated to the numerical operation.

If output construction is intrinsic to the public operation being measured, it
remains inside the timed region and is documented in the benchmark definition.

No single elapsed sample is labelled representative. Console summaries display
median first and show the observed range and standard deviation.

## 12. Allocation policy

Allocation measurement is optional because instrumentation, compiler version,
and measurement method can affect results.

When enabled:

- allocation collection occurs after warm-up;
- the exact measurement method is retained in the policy or provenance;
- allocated bytes and allocation count are reported separately;
- measuring allocations must not silently replace timing samples;
- the benchmark must avoid unrelated allocations from report formatting; and
- unsupported or unreliable allocation counts are recorded as unavailable,
  not zero.

Allocation observations are descriptive and machine/runtime specific. They are
not compared automatically across Julia versions in V5-V6.

## 13. Process isolation

The performance suite runner executes each registered benchmark in a separate
Julia process, matching the scientific suite's isolation philosophy.

Benefits include:

- bounded cross-benchmark compiler and cache contamination;
- independent failure reporting;
- explicit environment capture; and
- simpler reproduction of one benchmark command.

Within one child process, warm-up and retained samples run sequentially.
Benchmarks are not run concurrently because competition for CPU and memory
would undermine timing interpretation.

The parent runner records process elapsed time separately from the benchmark's
retained sample timings. Process elapsed time is operational information and is
not substituted for numerical timing.

## 14. Serialization

Performance reports use a new report identity and schema version rather than
reusing scientific suite report kinds.

Proposed report kinds:

- `performance_benchmark`; and
- `performance_suite`.

Serialization requirements:

- deterministic field ordering;
- deterministic benchmark and sample ordering;
- exact retention of integer work counts;
- round-trip-safe floating-point encoding;
- strict rejection of missing or unsupported fields;
- atomic writing;
- no ANSI codes or locale-dependent formatting;
- no derived pass/fail field; and
- reader verification that retained summaries match raw samples.

Scientific validation report readers remain unchanged.

## 15. Console presentation

The console report should present:

1. benchmark identity and definition version;
2. full numerical configuration;
3. environment summary;
4. warm-up and sample policy;
5. execution completeness;
6. primary timing summary;
7. allocation summary when available;
8. per-sample timing and work counts;
9. descriptive accuracy measures; and
10. an explicit statement that performance results do not determine scientific
    acceptance.

Console presentation must not hide raw variability behind a single rounded
number.

## 16. Comparison and interpretation policy

V5-V6 does not define a performance comparison status. A helper may calculate
and render descriptive differences between two compatible reports, but it must
not label those differences as pass or fail.

A compatible comparison requires matching:

- benchmark identifier;
- definition version;
- numerical configuration;
- measurement policy;
- Julia major/minor version unless explicitly overridden for descriptive use;
- thread count; and
- architecture when interpreting allocation or timing changes.

Work-count changes may be compared across machines when configuration and
software are otherwise compatible. Timing and allocation changes require more
caution and complete environment metadata.

Any claim of improvement or regression requires human review of:

- all raw samples;
- timing variability;
- work counts;
- scientific validation evidence;
- environment differences; and
- implementation changes.

## 17. Failure semantics

Performance execution distinguishes:

- completed benchmark report;
- benchmark process error;
- missing report;
- malformed report; and
- terminated process.

A benchmark execution error causes the runner command to return nonzero because
the requested evidence was not collected. This is not a scientific validation
failure and must be reported with different wording.

A slow but completed benchmark does not return nonzero merely because it is
slow.

## 18. Repository layout

Proposed additions:

```text
examples/validation/framework/
    PerformanceTypes.jl
    PerformanceResults.jl
    PerformanceSerialization.jl
    PerformancePresentation.jl
    PerformanceRunner.jl
    PerformanceBenchmarks.jl

examples/validation/performance/
    figure_eight_performance.jl
    hierarchical_triple_performance.jl
    close_encounter_performance.jl
    ks_switching_performance.jl

examples/validation/run_performance_suite.jl

test/validation_framework/
    performance_types.jl
    performance_results.jl
    performance_serialization.jl
    performance_presentation.jl
    performance_runner.jl
    performance_benchmarks.jl
```

Exact file grouping may be adjusted during implementation if a smaller module
layout is clearer, but scientific and performance result code must remain
separable.

Generated reports belong under `validation_reports/` or another ignored output
location. Raw local performance reports are not committed as approved
scientific evidence.

## 19. Public and internal API boundary

The performance framework remains repository validation infrastructure.

Initial internal API candidates:

```julia
build_performance_benchmark_report(...)
build_performance_suite_report(...)
performance_benchmark_text(report)
performance_suite_text(report)
read_performance_benchmark(source)
read_performance_suite(source)
write_performance_benchmark(io, report)
write_performance_suite(io, report)
render_performance_benchmark(io, report)
render_performance_suite(io, report)
run_performance_suite(...)
```

These names may be exported from the internal `ValidationFramework` module for
examples and tests, but must not be exported by `ThreeBody3D`.

## 20. Testing strategy

### 20.1 Record tests

Test:

- identifier and version validation;
- positive warm-up and sample counts;
- nonnegative finite timings and counts;
- contiguous sample indices;
- duplicate metric rejection;
- required measurement completeness;
- role restrictions on retained custom metrics; and
- immutability of completed records.

### 20.2 Summary tests

Use synthetic samples with exactly known statistics to verify:

- minimum;
- median for odd and even sample counts;
- mean;
- maximum;
- standard deviation;
- optional allocation summaries; and
- deterministic recomputation.

### 20.3 Serialization tests

Test:

- deterministic repeated serialization;
- exact integer round-trip;
- floating-point round-trip;
- sample ordering;
- malformed report kind;
- missing configuration or policy;
- inconsistent sample count;
- inconsistent retained summary;
- unsupported metric role; and
- atomic writing.

### 20.4 Runner tests

Use lightweight synthetic child scripts to test:

- warm-up exclusion;
- requested sample count;
- child-process isolation;
- successful collection;
- missing report;
- malformed report;
- child error;
- parent nonzero exit on incomplete evidence; and
- no concurrent execution.

Unit and integration tests must not assert strict wall-clock performance.
Timing tests should assert only structural properties such as finite,
nonnegative retained durations.

### 20.5 Benchmark adapter tests

For each initial numerical benchmark, test:

- fixed definition and configuration metadata;
- expected measurement identifiers;
- presence of available solver work counts;
- successful report construction from a reduced test configuration; and
- no alteration of existing scientific criteria or case definitions.

Full production benchmark durations do not run as part of ordinary `Pkg.test()`.

## 21. Implementation sequence

### V5-V6a — Core performance records

Add immutable definitions, policies, samples, summaries, benchmark reports, and
suite reports with invariant tests.

Suggested commit:

```text
Add structured performance benchmark records
```

### V5-V6b — Deterministic performance serialization

Add strict deterministic TOML writers/readers and atomic report support.

Suggested commit:

```text
Add deterministic performance benchmark reports
```

### V5-V6c — Presentation and measurement protocol

Add console rendering, summary presentation, child report protocol, and warm-up
measurement helpers using synthetic tests.

Suggested commit:

```text
Add performance benchmark measurement protocol
```

### V5-V6d — Process-isolated suite runner

Add the benchmark registry and sequential child-process runner with explicit
execution-completeness semantics.

Suggested commit:

```text
Add reproducible performance benchmark runner
```

### V5-V6e — Initial numerical benchmarks

Integrate the figure-eight, hierarchical-triple, close-encounter, and KS
switching benchmarks without changing their scientific validation definitions.
This may be split into two commits if review size warrants it.

Suggested commit:

```text
Add representative numerical performance benchmarks
```

### V5-V6f — Accuracy-versus-work series and documentation

Add small fixed configuration series, document commands and interpretation, and
run the complete scientific suite to confirm independence.

Suggested commit:

```text
Complete reproducible performance benchmark suite
```

## 22. Acceptance gate

Stage V5-V6 is complete only when all of the following hold:

1. performance reports are structurally separate from scientific validation
   results;
2. no performance measurement affects scientific pass/fail status;
3. each registered benchmark records complete definition, configuration,
   environment, and measurement-policy metadata;
4. steady-state elapsed timing uses at least one warm-up and at least three raw
   retained samples;
5. raw samples and deterministic summaries are both retained;
6. timing variability is visible in console and serialized reports;
7. accepted steps, rejected steps, RHS evaluations, and saved states are
   retained wherever available;
8. allocation metrics are explicitly available or unavailable and never
   fabricated as zero;
9. benchmarks execute sequentially in isolated child processes;
10. reports serialize deterministically and read strictly;
11. runner errors indicate incomplete performance evidence rather than
    scientific failure;
12. no automatic performance baseline or threshold is introduced;
13. ordinary package tests do not depend on production benchmark timings;
14. existing package tests pass;
15. the full scientific validation suite remains passing and unchanged; and
16. no performance framework type is added to the public ThreeBody3D API.

## 23. Scientific and engineering review checklist

Before accepting a registered benchmark, reviewers must confirm:

- the benchmark represents a meaningful numerical workload;
- its numerical configuration is fixed and fully retained;
- the timed region measures the intended operation;
- warm-up excludes compilation from steady-state samples;
- repeated timings expose variability;
- work counts are collected from the underlying solution rather than inferred;
- descriptive accuracy measures are scientifically interpretable;
- scientific criteria remain in the validation framework, not the performance
  report;
- allocation instrumentation is documented and reliable enough for retention;
- no report field claims an automatic regression decision; and
- the benchmark can be reproduced with one documented command.

## 24. Recommended next action

After this design is reviewed and accepted, begin **V5-V6a — Core performance
records** only.

Before modifying implementation files, inspect the exact current versions of:

- `examples/validation/framework/Types.jl`;
- `examples/validation/framework/Serialization.jl`;
- `examples/validation/framework/SuiteRunner.jl`;
- `examples/validation/framework/ValidationFramework.jl`; and
- `test/validation_framework/runtests.jl`.

The first implementation patch should add only core performance records,
summary construction, invariants, and focused unit tests. It must not introduce
a numerical benchmark, subprocess runner, serialization format, or change any
scientific validation output.

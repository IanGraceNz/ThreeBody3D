# v0.6 Investigation 1 Measurement Plan

## 1. Purpose

Investigation 1 quantifies the numerical error of the current ThreeBody3D
solver before algorithmic changes are considered. Its purpose is to establish a
reproducible numerical baseline, identify the regimes in which accuracy
deteriorates, and provide the evidence required by Investigation 2.

The governing question is:

> **What are the dominant magnitudes and distributions of numerical error
> across the current ThreeBody3D solver?**

This plan defines the measurements, controlled variables, benchmark coverage,
and completion criteria for answering that question. It does not propose solver
improvements and does not alter existing acceptance criteria.

## 2. Relationship to the existing validation framework

The existing validation framework remains the authoritative source of
structured case definitions, configurations, metrics, solver statistics,
provenance, deterministic serialization, approved scientific references, and
performance measurements.

Investigation 1 extends the use of that framework from acceptance testing to
descriptive numerical investigation. Existing pass-or-fail criteria continue to
protect the validated baseline, but they do not by themselves identify dominant
error magnitudes, convergence behaviour, error floors, or deterioration across
numerical regimes.

The investigation shall therefore reuse existing records and conventions
wherever they represent the required evidence faithfully. New records shall be
introduced only where the investigation requires an ordered experimental series
or a relationship that cannot be expressed clearly by the current framework.

## 3. Scope

### 3.1 Included

Investigation 1 includes:

- quantitative comparison with approved scientific reference solutions where
  suitable references exist;
- invariant and residual measurements across representative benchmark
  problems;
- controlled comparisons of supported solver profiles;
- controlled tolerance sweeps where explicit tolerances are supported;
- variation of selected physical or numerical regime parameters;
- accuracy-versus-work comparisons;
- reproducibility checks; and
- deterministic reporting of measurements, configurations, provenance, and
  solver statistics.

### 3.2 Excluded

Investigation 1 excludes:

- changes to solver algorithms;
- changes to switching or regularisation policy;
- introduction of new acceptance thresholds solely to classify descriptive
  results;
- optimisation of implementation performance;
- selection or adoption of candidate algorithmic improvements; and
- causal explanation of observed errors beyond what is required to design or
  interpret a measurement.

Unexpected behaviour may be recorded as evidence, but causal investigation is
reserved for Investigation 2.

## 4. Measurement principles

### 4.1 Separate state error from invariant drift

State error and invariant drift are distinct forms of evidence.

A trajectory may preserve an invariant while accumulating phase or state error,
and a small local state error may coexist with measurable invariant drift.
Investigation 1 shall therefore avoid treating conservation measurements as
substitutes for comparison with a reference solution.

### 4.2 Control one independent variable at a time

Each experimental series shall vary one declared independent variable while
holding all other configuration values fixed wherever practical. Any unavoidable
coupling shall be stated explicitly in the experiment definition.

### 4.3 Preserve raw measurements

Reports shall retain the measured values from every completed point in an
experimental series. Aggregated summaries may be added, but shall not replace
the underlying observations.

### 4.4 Record unsuccessful points

A failed integration, unsupported configuration, non-finite result, or unmet
precondition is evidence. Such a point shall be represented explicitly rather
than omitted from an ordered series.

### 4.5 Prefer reproducibility over breadth

The initial study shall use a small representative benchmark set and a modest
number of controlled points. Coverage shall expand only after the pilot protocol
has demonstrated deterministic configuration, execution, and reporting.

## 5. Categories of evidence

Investigation 1 shall distinguish three categories of evidence.

### 5.1 Reference error

Where an approved or otherwise explicitly qualified reference solution exists,
record state error using definitions appropriate to the benchmark. Candidate
measurements include:

- final-state position error;
- final-state velocity error;
- maximum sampled position error;
- maximum sampled velocity error;
- phase or periodicity error;
- event-time error; and
- benchmark-specific reconstruction or continuation error.

Every reference-error metric shall state:

- the reference source and approval status;
- the comparison interval;
- the sampling or interpolation procedure;
- the norm and normalisation convention; and
- any transformation required before comparison.

Reference-error metrics shall not be reported where those conditions cannot be
specified unambiguously.

### 5.2 Invariant and residual behaviour

Record the applicable physical and structural measurements, including:

- maximum relative total-energy drift;
- maximum linear-momentum drift;
- maximum angular-momentum drift;
- maximum centre-of-mass residual;
- minimum pair separation;
- periodicity residual;
- hierarchy ratio;
- switching continuity residuals;
- regularised reconstruction residuals; and
- benchmark-specific analytical residuals.

Not every measurement applies to every benchmark. Each experiment definition
shall identify its required and optional metrics.

### 5.3 Solver behaviour and computational work

Record the applicable solver and controller measurements, including:

- accepted steps;
- rejected steps;
- right-hand-side evaluations;
- saved states;
- elapsed time under the established performance protocol;
- switching count;
- regularised and Cartesian segment counts;
- event or termination status; and
- other deterministic work indicators exposed by the benchmark report.

Elapsed time is descriptive environment-dependent evidence. Deterministic work
counts shall remain available so numerical conclusions do not depend solely on
wall-clock timing.

## 6. Initial benchmark set

The pilot study shall use four benchmark families selected from the existing
validation suite.

### 6.1 Figure-eight orbit

The figure-eight benchmark represents strongly coupled periodic three-body
motion over repeated periods. It is suitable for measuring:

- long-duration accumulation of numerical error;
- periodicity error;
- invariant drift;
- solver-profile differences; and
- accuracy relative to computational work.

### 6.2 Hierarchical triple

The hierarchical-triple benchmark represents multiscale weakly perturbed
motion with separated orbital timescales. It is suitable for measuring:

- sensitivity to integration tolerances;
- long-duration invariant behaviour;
- preservation of hierarchy;
- solver-profile differences; and
- accuracy relative to computational work.

### 6.3 Close-encounter comparison

The close-encounter benchmark compares Cartesian, automatic-switching, and
explicitly regularised propagation against the existing independent
higher-precision reference used by the validation case. It is suitable for
measuring:

- error near a severe binary encounter;
- differences between propagation representations;
- periapsis and final-state error;
- switching continuity; and
- computational work associated with regularisation.

### 6.4 KS switching comparison

The Kustaanheimo-Stiefel switching comparison represents controlled switching
between Cartesian and regularised propagation and comparison with the
Levi-Civita backend on the same encounter. It is suitable for measuring:

- switching and representation residuals;
- backend agreement;
- switch and segment counts;
- conservation behaviour; and
- sensitivity of the measured result to switching activity.

### 6.5 Expansion beyond the pilot

The remaining validation cases shall be added only after the pilot protocol is
shown to produce complete and reproducible series. Expansion shall prioritise
cases that introduce a numerical regime not already represented by the pilot,
such as collision continuation, deterministic randomized regression, or
analytic Kepler comparisons.

## 7. Controlled variables

### 7.1 Solver profile

Where supported by the benchmark adapter, compare the package-owned solver
profiles under otherwise fixed conditions. The configuration shall record the
profile symbol and any explicit tolerance overrides.

A profile comparison is not equivalent to a tolerance sweep because profiles
may differ in solver algorithm and default configuration.

### 7.2 Integration tolerance

Where the benchmark API accepts explicit relative and absolute tolerances,
construct an ordered series in which both tolerances are varied together unless
a separate experiment justifies varying them independently.

The first implementation shall use a small logarithmically spaced set selected
to expose convergence behaviour without incurring unnecessary computation. The
exact values shall be fixed in the experiment definition and shall not be
chosen after inspecting the results.

### 7.3 Integration duration

Duration series shall preserve initial conditions, solver configuration, and
sampling conventions while varying the final time or number of periods.

Duration-dependent measurements shall distinguish bounded oscillation from
secular growth where the available points support that distinction.

### 7.4 Encounter severity and hierarchy

Where an existing benchmark family exposes a scientifically meaningful regime
parameter, a separate ordered series may vary:

- minimum encounter scale;
- regularisation threshold relative to encounter scale;
- hierarchy ratio;
- timescale separation; or
- another explicitly defined dimensionless parameter.

A new physical family of initial conditions shall not be introduced merely to
increase coverage. Any extension of a benchmark family requires separate
review of its scientific interpretation and reference strategy.

### 7.5 Arithmetic precision

Precision comparison shall be performed only where:

- the benchmark implementation supports the precision consistently;
- the reference has greater effective accuracy than the measured solution;
- conversions do not dominate the comparison; and
- the cost remains proportionate to the evidence sought.

Higher precision is not automatically an approved reference. Its construction,
solver configuration, and validation status shall be recorded.

### 7.6 Sampling and interpolation

Sampling shall remain fixed within an experimental series unless sampling is
the independent variable. When trajectories are compared at common times, the
comparison shall record whether values were saved directly or obtained through
dense interpolation.

## 8. Mandatory record for each measurement point

Each completed or attempted measurement point shall retain:

- experiment-family identifier;
- ordered point identifier;
- benchmark definition and version;
- complete validation configuration;
- the independent-variable name and value;
- fixed control values;
- execution environment and provenance;
- completion or failure status;
- all applicable reference-error metrics;
- all applicable invariant and residual metrics;
- solver statistics;
- switching or regularisation counts where applicable;
- elapsed-time measurements where collected; and
- explanatory notes limited to factual execution conditions.

Human interpretation shall be reported separately from the immutable
measurement record.

## 9. Experimental series

The pilot shall produce the following series.

### 9.1 Figure-eight profile and duration series

Hold the benchmark initial conditions and sampling fixed. Measure each supported
profile at the established duration, then measure selected durations using one
fixed high-accuracy configuration.

Primary evidence:

- periodicity residual;
- invariant drift;
- reference error where a suitable approved reference is available;
- accepted and rejected steps;
- right-hand-side evaluations; and
- elapsed time under the performance protocol.

### 9.2 Hierarchical-triple tolerance and duration series

Hold the benchmark initial conditions and sampling fixed. Vary explicit
relative and absolute tolerances together, then vary duration using one fixed
high-accuracy configuration.

Primary evidence:

- invariant drift;
- centre-of-mass residual;
- minimum hierarchy ratio;
- reference error where a suitable approved reference is available;
- accepted and rejected steps;
- right-hand-side evaluations; and
- elapsed time under the performance protocol.

### 9.3 Close-encounter representation series

Use the existing controlled encounter and its independent higher-precision
reference. Preserve the physical initial conditions and comparison interval
while comparing the existing Cartesian, automatic-switching, and explicit
regularised propagation modes.

Primary evidence:

- periapsis error;
- final-state position and velocity error;
- maximum sampled state error where already supported by the case;
- invariant drift;
- switching or segment counts; and
- computational work.

### 9.4 KS switching evidence series

Use the existing KS switching comparison and retain its fixed encounter. The
first series shall compare the existing KS and Levi-Civita switching backends
without changing policy parameters.

Primary evidence:

- backend final-state agreement;
- switching continuity and reconstruction residuals;
- invariant drift;
- switch and segment counts; and
- computational work where available.

Variation of switching thresholds or policy parameters belongs in a later
series only after the fixed-policy baseline has been recorded.

## 10. Interpretation of results

Investigation 1 is descriptive. It shall identify observed behaviour without
assigning causal mechanisms prematurely.

The baseline report shall examine:

- magnitude and range of each error metric;
- ordering of errors across benchmarks and configurations;
- convergence as tolerances are reduced;
- apparent error floors;
- non-monotonic or anomalous points;
- growth with duration;
- deterioration with encounter severity or timescale separation;
- accuracy relative to deterministic solver work and measured elapsed time; and
- reproducibility of equivalent runs.

Terms such as *convergent*, *error floor*, *secular growth*, or *outlier* shall
be used only when the collected series supports the stated interpretation.

## 11. Reporting

### 11.1 Deterministic machine-readable report

Each series shall be serializable using deterministic ordering and stable field
names consistent with the existing validation framework. The report shall
preserve every measurement point and its provenance.

### 11.2 Human-readable baseline report

A separate report shall summarise:

- the experimental scope;
- completed and unsuccessful series;
- dominant measured errors;
- regimes in which accuracy deteriorates;
- convergence and accuracy-versus-work behaviour;
- limitations of the evidence; and
- questions transferred to Investigation 2.

The report shall distinguish direct measurements from interpretation.

### 11.3 No automatic ranking across incomparable metrics

The framework shall not combine state error, invariant drift, elapsed time, and
benchmark-specific residuals into one synthetic score. Any ordering of
benchmarks shall name the metric and normalisation used.

## 12. Reproducibility requirements

A result is reproducible for the purposes of Investigation 1 when:

- its benchmark and configuration are completely identified;
- deterministic work and numerical metrics repeat within explicitly stated
  comparison rules;
- environment-dependent timing uses the existing warm-up and retained-sample
  protocol;
- random inputs, if introduced by a later series, use a recorded deterministic
  seed;
- the reference source and comparison method are recorded; and
- the machine-readable report can be regenerated without manual editing.

Bitwise equality of floating-point timing or solver results is not assumed
unless a specific experiment establishes it as a requirement.

## 13. Pilot completion criteria

The pilot measurement programme is complete when:

- each of the four pilot benchmark families has at least one complete ordered
  experimental series;
- each point records configuration, provenance, status, numerical metrics, and
  solver work without ambiguous definitions;
- reference-error metrics are included only where the reference and comparison
  procedure are explicitly qualified;
- repeated execution confirms that the protocol is reproducible under the
  stated rules;
- deterministic machine-readable reports and a human-readable baseline summary
  have been produced;
- the evidence is sufficient to decide whether the protocol can be extended to
  the remaining validation suite without redesign; and
- no solver or switching algorithm has been modified as part of the
  measurement programme.

Completion does not require that every measured error be explained or that an
algorithmic improvement be identified.

## 14. Implementation stages

### Stage I1-A — Measurement design

Approve this measurement plan and freeze the pilot scope, evidence categories,
and completion criteria.

### Stage I1-B — Investigation records

Introduce the smallest additional immutable records required to represent an
experiment definition, one attempted measurement point, and an ordered series.
Reuse existing validation metrics, configurations, provenance, solver
statistics, status conventions, and serialization utilities.

### Stage I1-C — Core pilot adapters

Implement and test the figure-eight and hierarchical-triple series by adapting
existing core benchmark and performance operations.

### Stage I1-D — Regularisation pilot adapters

Implement and test the close-encounter and KS switching series, retaining the
existing physical cases and switching policies.

### Stage I1-E — Baseline execution and report

Run the approved pilot, preserve its deterministic records, and produce the
first Investigation 1 baseline report. Record questions requiring causal
analysis for Investigation 2 without proposing algorithmic changes.

## 15. First implementation increment

The first source-code increment after approval of this plan shall be limited to
Stage I1-B.

It shall not:

- modify the numerical solver;
- modify validation-case acceptance criteria;
- add new benchmark physics;
- execute the full pilot; or
- generalise the framework beyond requirements demonstrated by the approved
  pilot series.

The increment shall be accepted only after focused unit tests and the complete
package test suite pass.

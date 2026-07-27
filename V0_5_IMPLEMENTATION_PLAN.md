# ThreeBody3D v0.5 Implementation Plan

## 1. Purpose

ThreeBody3D v0.5 will increase the scientific maturity of the package while
preserving the validated v0.4.0 numerical baseline.

The release has three primary workstreams:

1. provide scientifically defensible validation that enables continued
   improvement of regularization methods, numerical algorithms, and solver
   accuracy;
2. improve experimental automatic switching; and
3. advance regularization robustness.

Work proceeds in that order. Validation infrastructure must be capable of
measuring and detecting regressions before switching or regularization
algorithms are changed.

### Scientific objective

The primary objective of ThreeBody3D is to improve the scientific accuracy,
robustness, and reproducibility of numerical solutions of the Newtonian
three-body problem.

Every development stage should contribute directly to one or more of the
following objectives:

- improve numerical accuracy;
- improve robustness during close encounters and other challenging dynamical
  regimes; and
- increase scientific confidence that reported improvements are genuine,
  reproducible, and quantitatively supported.

The validation framework is not an end in itself. Its purpose is to provide
sufficient scientific evidence that improvements to regularization methods,
numerical algorithms, and solver strategies represent genuine advances rather
than incidental numerical variation.

Accordingly, the validation framework should remain as simple as possible while
meeting the standards of scientific acceptability and reproducibility required
for trustworthy scientific software.

### Validation design priorities

The validation framework follows three priorities, in this order:

1. scientific acceptability;
2. ease of use; and
3. simplicity.

Scientific correctness takes precedence over convenience, implementation
complexity, or feature count. Routine validation should be straightforward to
execute, understand, and reproduce. Additional infrastructure should be added
only when it demonstrably improves the project's scientific capability.

### Scientific return test

Before introducing new validation functionality, ask:

> Will this feature help determine whether a new numerical method is
> scientifically better than the previous one?

If the answer is yes, the feature supports the project's primary objective. If
the answer is no, implementation should normally be deferred.

The purpose of "not fooling ourselves" is practical: to produce better, more
accurate software. Validation should be capable of disproving an expected
improvement as readily as confirming one, while remaining focused on advancing
the quality of the numerical solution.

## 2. Development principles

The following requirements apply to every stage:

- scientific correctness takes priority over feature count;
- numerical accuracy takes priority over execution speed;
- major mathematical changes require design review before implementation;
- public behaviour must not change accidentally;
- each implementation increment requires focused unit tests;
- scientific claims require explicit quantitative acceptance criteria;
- randomized work must be reproducible from recorded seeds;
- validation and benchmark results must identify the configuration that
  produced them;
- unrelated changes must not be combined in one commit; and
- `main` remains stable while work proceeds on `v0.5-development`.

## 3. Workstream A: Scientific validation

This workstream provides scientifically defensible evidence that enables
continued improvement of regularization methods, numerical algorithms, solver
strategies, and overall numerical accuracy. It is not intended to build an
increasingly sophisticated validation framework.

ThreeBody3D follows the principle of scientific minimalism: validation
infrastructure should implement only the minimum capability required to support
scientifically rigorous development. Features that primarily add
administrative, architectural, or organisational sophistication without
improving scientific capability should normally be deferred.

### Stage V5-V0: Validation inventory and schema design

#### Objective

Define a common representation for validation configuration, measured results,
acceptance criteria, and reproducibility metadata without changing numerical
algorithms.

#### Deliverables

- inventory the existing validation cases and the scientific property tested by
  each case;
- classify cases as unit, regression, scientific-reference, stress, or
  performance validation;
- define a versioned validation-result schema;
- define required metadata, including:
  - package and Julia versions;
  - operating system and architecture;
  - solver profile and tolerances;
  - numeric type and precision;
  - initial-condition identifier or seed;
  - integration interval and sampling policy; and
  - elapsed time and solver statistics where relevant;
- distinguish scientific pass/fail limits from descriptive performance data;
- document policies for updating reference values and tolerances.

#### Acceptance gate

- every current suite entry is represented in the inventory;
- the schema can represent every metric currently printed by the suite;
- no numerical source file is changed;
- package tests and the existing validation suite remain unchanged and passing.

#### Suggested commit

`Design v0.5 validation framework`

### Stage V5-V1: Structured validation results

#### Objective

Replace ad hoc result aggregation with reusable typed validation records while
preserving standalone human-readable output.

#### Deliverables

- typed records for validation metadata, metrics, criteria, and case results;
- deterministic serialization to a simple machine-readable format;
- suite-level summary containing all case results;
- explicit distinction among pass, fail, and execution error;
- retained nonzero process exit status for failed criteria or execution errors;
- unit tests for construction, validation, serialization, and failure paths.

#### Acceptance gate

- all existing validation scripts still run independently;
- all existing acceptance criteria retain their current numerical limits;
- the complete suite produces both readable console output and structured
  output;
- repeated serialization of one result is byte-for-byte deterministic;
- package tests and the full validation suite pass.

#### Suggested commits

1. `Add structured validation result types`
2. `Emit deterministic validation reports`

### Stage V5-V2: Long-duration validation

#### Objective

Measure numerical behaviour over substantially longer intervals than the v0.4
release suite.

#### Required cases

- multiple-period figure-eight propagation;
- long-lived hierarchical triple propagation;
- repeated close encounters with automatic switching;
- long-duration Kustaanheimo–Stiefel transformation (KS) propagation where the
  current formulation is applicable.

#### Measurements

At minimum:

- maximum and final relative energy drift;
- maximum linear- and angular-momentum drift;
- centre-of-mass position and velocity residuals;
- minimum pair separation;
- periodicity or reference-state error where defined;
- switch counts and transition residuals for switching cases;
- accepted and rejected steps and right-hand-side evaluations; and
- completion status and finiteness.

#### Acceptance policy

Limits must be established from independently reviewed baseline runs. They must
not be chosen merely to make the current implementation pass. Each limit must
include a written physical or numerical rationale and a margin appropriate to
cross-platform floating-point variation.

#### Acceptance gate

- every required case completes with finite states;
- all conservation and reference criteria pass;
- results are reproducible within documented cross-platform tolerances;
- runtime remains suitable for an explicitly invoked research-validation suite;
- no regression is introduced in the ordinary package tests.

#### Suggested commits

1. `Add long-duration validation cases`
2. `Record long-duration acceptance baselines`

### Stage V5-V3: Parameter sweeps

#### Objective

Test behaviour over controlled families of masses, geometries, encounter
strengths, and solver configurations rather than isolated fixtures.

#### Initial sweep dimensions

- binary mass ratio;
- third-body mass ratio;
- hierarchy ratio;
- eccentricity or impact parameter;
- encounter orientation;
- switching entry and exit thresholds; and
- Float64 and selected BigFloat reference points.

Sweep dimensions should initially be varied one at a time around reviewed
reference systems. Multi-dimensional sweeps are deferred until the single-axis
behaviour is understood.

#### Deliverables

- deterministic sweep specification;
- per-point structured results;
- aggregate worst-case and distribution summaries;
- clear identification of the failing parameter point;
- resumable execution without changing scientific results;
- tests of sweep construction and aggregation using inexpensive fixtures.

#### Acceptance gate

- every sweep point is uniquely and reproducibly identified;
- failures preserve enough metadata for direct reproduction;
- aggregate summaries cannot hide individual failed points;
- reviewed acceptance criteria pass across the approved initial domain.

#### Suggested commits

1. `Add deterministic validation sweeps`
2. `Add initial three-body parameter sweeps`

### Stage V5-V4: Randomized ensembles and stress testing

#### Objective

Extend the existing deterministic-seed randomized regression case into
classified reproducible ensembles, including deliberately difficult systems.

#### Ensemble classes

- moderate bound triples;
- hierarchical triples;
- near-parabolic encounters;
- strong binary encounters;
- near-simultaneous competing encounters; and
- invalid or unsupported configurations used to verify explicit failure.

#### Requirements

- one recorded master seed and a deterministic per-trial seed;
- the complete generated initial condition recorded for every failure;
- separation of expected-success, expected-stop, and expected-error cases;
- no silent filtering of difficult generated systems;
- configurable quick and extended ensemble sizes;
- statistical summaries used only in addition to, never instead of, per-trial
  pass/fail criteria.

#### Acceptance gate

- every failed trial can be reproduced independently from its report;
- the quick ensemble is stable enough for routine development use;
- the extended ensemble is suitable for release qualification;
- all approved expected-success cases satisfy their declared limits;
- expected-stop and expected-error cases terminate for the documented reason.

#### Suggested commits

1. `Refactor randomized validation into reproducible ensembles`
2. `Add close-encounter stress ensembles`

### Stage V5-V5: Scientific reference support

#### Objective

Define and implement the minimum scientifically defensible support required to
preserve approved scientific references and compare current structured results
with them.

An approved scientific reference represents a reviewed scientific observation,
not software state. The validation framework preserves, compares, and reports
that evidence; scientific interpretation remains the responsibility of the
reviewer.

#### Deliverables

- a compact repository-managed set of approved scientific references for
  selected deterministic cases;
- a concise design defining scientific acceptance, minimum metadata,
  immutability, comparison, and replacement rules;
- documented rules distinguishing exact and tolerance-based comparisons;
- provenance and scientific rationale recorded for each approved reference;
- an explicit human review procedure for accepting a candidate reference;
- a comparison tool that reports every retained metric and observed
  difference; and
- no automatic selection, approval, or rewriting of approved references during
  validation.

#### Acceptance gate

- reference generation and reference comparison are separate commands;
- a changed numerical result cannot silently update its baseline;
- deliberate fixture perturbations are detected by tests;
- accepted references are portable across supported platforms within declared
  tolerances.

#### Suggested commits

1. `Define scientific reference baseline design`
2. `Add minimal approved scientific reference support`
3. `Apply approved references to a scientific comparison`

### Stage V5-V6: Performance benchmarking

#### Objective

Measure performance without weakening scientific acceptance criteria or making
wall-clock timing a correctness requirement.

#### Measurements

- elapsed time, reported descriptively;
- allocations where reliably measurable;
- accepted and rejected steps;
- right-hand-side evaluations;
- saved-state count; and
- accuracy-versus-work comparisons.

#### Requirements

- performance runs are separate from scientific pass/fail validation;
- warm-up and compilation effects are handled explicitly;
- benchmark configurations are fixed and recorded;
- performance regressions are reviewed, not automatically hidden by looser
  scientific tolerances;
- no claim of improvement is made from a single noisy wall-clock sample.

#### Acceptance gate

- benchmark results include full configuration metadata;
- repeated runs expose timing variability;
- work-count metrics are available for cross-machine comparison;
- scientific validation remains independent and passing.

#### Suggested commit

`Add reproducible performance benchmark suite`

### Stage V5-V7: Validation-suite tiers and release gate

#### Objective

Provide clear execution tiers suitable for development, continuous integration,
and release qualification.

#### Proposed tiers

- `quick`: focused deterministic regression cases;
- `standard`: the current scientific suite plus selected v0.5 additions;
- `extended`: long-duration cases, parameter sweeps, and larger ensembles;
- `performance`: descriptive benchmarking only.

#### Requirements

- tier membership is explicit and documented;
- no case is skipped silently;
- commands return nonzero status on scientific failure;
- reports state the exact tier and included cases;
- the release-readiness process requires the approved standard and extended
  tiers.

#### Acceptance gate

- each tier can be invoked with one documented command;
- package tests remain distinct from scientific validation;
- the standard tier is practical for continuous integration;
- the extended tier is practical for explicit release qualification;
- all required v0.5 validation evidence is archived before release.

#### Suggested commits

1. `Add tiered scientific validation runner`
2. `Document v0.5 release validation gate`

## 4. Workstream B: Automatic switching

Automatic-switching work begins only after Stages V5-V0 through V5-V4 provide
adequate regression and stress coverage.

Planned subjects are:

- formal hysteresis and anti-chattering invariants;
- threshold scaling and selection;
- pair competition and near-simultaneous encounters;
- failure classification and diagnostics;
- transition conservation and gauge continuity; and
- long-duration switched-trajectory robustness.

A separate design specification must define these stages and acceptance limits
before implementation begins. That specification is now provided by
`V0_6_AUTOMATIC_SWITCHING_ROBUSTNESS_DESIGN.md`.

## 5. Workstream C: Regularization robustness

Further regularization development begins after the validation framework and
switching design are established.

Planned subjects are:

- Sundman transformation robustness;
- transition algorithms and reconstruction diagnostics;
- long-duration KS behaviour;
- pathological and near-degenerate encounters;
- precision-generic reference validation; and
- the boundary between supported three-body regularization and future research
  methods such as chain regularization.

Major mathematical extensions require an independent formulation review before
source changes.

## 6. Immediate next action

Complete Stage V5-V5 design before implementation by adding
`V0_5_SCIENTIFIC_REFERENCE_BASELINE_DESIGN.md` and reviewing it together with
this implementation plan and `VALIDATION_WORKFLOW.md`.

The first implementation increment should then introduce only the minimum
approved-scientific-reference representation required by the accepted design.
No numerical algorithm should be changed during that increment. Each later
reference feature must pass the scientific return test and remain subordinate
to the project's primary goal of improving regularization and numerical
accuracy.

## 7. Long-term philosophy

ThreeBody3D is fundamentally a scientific computing project rather than a
validation-framework project. Validation infrastructure exists to support the
continued development of increasingly accurate and robust numerical methods.

The framework should collect, preserve, and present scientific evidence without
substituting automated conclusions for scientific judgement. Every iteration
should either improve the numerical methods or improve confidence in their
behaviour, with the overall purpose of producing better, more accurate
software.

As the project matures, validation infrastructure should stabilise while
scientific capability continues to expand. The approved scientific reference
system exists to provide confidence that each successive iteration genuinely
improves accuracy and quality.

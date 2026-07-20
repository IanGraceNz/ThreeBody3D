# ThreeBody3D v0.5 Validation Inventory

## 1. Purpose

This document records the scientific-validation baseline inherited from
ThreeBody3D v0.4.0. It satisfies the inventory portion of Stage V5-V0 in
`V0_5_IMPLEMENTATION_PLAN.md` and provides the traceability needed before the
validation framework is refactored.

The inventory describes what each current validation case establishes, how it
is classified, which configuration controls it uses, which measurements it
reports, and how it currently determines success or failure. It does not alter
any numerical algorithm, acceptance limit, or suite membership.

## 2. Classification vocabulary

Each validation case may have more than one classification.

- **Unit validation** checks a narrowly scoped mathematical or software
  invariant with inexpensive fixtures. Unit validation normally belongs in the
  package test suite rather than the standalone scientific suite.
- **Regression validation** detects unintended changes in behaviour relative to
  a deterministic established case.
- **Scientific-reference validation** compares against an analytic solution,
  an exact invariant, an independent formulation, or a higher-precision
  reference calculation.
- **Stress validation** exercises difficult but supported dynamics, such as
  close encounters, collisions, multiscale motion, or representation
  switching.
- **Performance validation** records descriptive work or timing measurements.
  Performance measurements are not scientific pass/fail criteria.

The current standalone suite contains regression, scientific-reference, stress,
and descriptive performance elements. Focused unit validation remains in
`test/`.

## 3. Current suite architecture

The suite runner is `examples/validation/run_validation_suite.jl`.

Its present behaviour is intentionally simple:

1. each case is represented by a `ValidationSuiteEntry` containing a symbolic
   name, a description, and a script path;
2. each script runs in a separate Julia process;
3. each script prints its own measurements and acceptance criteria;
4. a nonzero child-process exit status is interpreted as failure;
5. the runner records only case-level pass/fail, elapsed seconds, and an error
   message; and
6. the runner exits nonzero unless every case passes.

Running cases in separate processes preserves standalone reproducibility and
prevents global definitions from leaking between cases. This property should be
retained unless a later design demonstrates an equally reliable alternative.

Shared acceptance-table behaviour is implemented in
`examples/validation/AcceptanceCriteria.jl`. Its current criterion record
contains:

- label;
- measured value;
- human-readable criterion text; and
- Boolean pass/fail.

This is a useful foundation, but it does not yet retain typed limits, units,
comparison operators, case metadata, or machine-readable measurements.

## 4. Inventory of current scientific-validation cases

The v0.4.0 scientific suite contains eleven entries. All eleven are represented
below.

### 4.1 Figure-eight benchmark

- **Suite identifier:** `figure_eight`
- **Script:** `examples/validation/figure_eight_benchmark.jl`
- **Primary classifications:** regression; scientific-reference
- **Physical regime:** strongly coupled periodic three-body motion
- **Current configuration:** ten nominal periods using the accurate profile
- **Scientific properties tested:**
  - completion at the expected final time;
  - conservation of total energy;
  - conservation of linear momentum;
  - conservation of angular momentum;
  - centre-of-mass position behaviour; and
  - return of the full state after ten periods.
- **Current acceptance measurements:**
  - completion status;
  - final-time residual;
  - maximum relative energy drift;
  - maximum momentum drift;
  - maximum angular-momentum drift;
  - maximum centre-of-mass residual; and
  - ten-period state periodicity error.
- **Descriptive work measurements:** saved states, accepted and rejected steps,
  and right-hand-side evaluations as supplied by the benchmark report.
- **Determinism:** deterministic fixed initial condition.
- **Principal limitation:** one duration and one fixed figure-eight orbit are
  represented.

### 4.2 Hierarchical-triple benchmark

- **Suite identifier:** `hierarchical_triple`
- **Script:** `examples/validation/hierarchical_triple_benchmark.jl`
- **Primary classifications:** regression; stress
- **Physical regime:** weakly perturbed multiscale hierarchical dynamics
- **Current configuration:** duration `100.0` using the accurate profile
- **Scientific properties tested:**
  - completion at the expected final time;
  - conservation of total energy, linear momentum, and angular momentum;
  - centre-of-mass behaviour; and
  - continued separation of inner and outer orbital scales.
- **Current acceptance measurements:**
  - completion status;
  - final-time residual;
  - maximum relative energy drift;
  - maximum momentum drift;
  - maximum angular-momentum drift;
  - maximum centre-of-mass residual; and
  - minimum hierarchy ratio.
- **Descriptive work measurements:** saved states, accepted and rejected steps,
  and right-hand-side evaluations.
- **Determinism:** deterministic fixed initial condition.
- **Principal limitation:** one mass configuration, hierarchy ratio, and
  duration are represented.

### 4.3 Long-duration automatic-switching diagnostics

- **Suite identifier:** `switching_diagnostics`
- **Script:** `examples/long_duration_switching_validation.jl`
- **Primary classifications:** regression; stress
- **Physical regime:** close encounter with Cartesian/regularized
  representation changes
- **Current configuration:** fixed entry, exit, and ambiguity thresholds of
  `0.2`, `0.4`, and `0.3`
- **Scientific properties tested:**
  - successful switched-trajectory completion;
  - conservation through propagation;
  - continuity across representation transitions; and
  - occurrence of the expected switching activity.
- **Current acceptance measurements:**
  - completion status;
  - minimum required number of segments;
  - minimum required number of switch events;
  - maximum relative energy drift;
  - maximum momentum drift;
  - maximum angular-momentum drift;
  - maximum centre-of-mass residual;
  - maximum transition-state residual; and
  - maximum transition-energy jump.
- **Additional descriptive measurements:** switch count, segment count, minimum
  pair separation, saved samples, and solver work statistics where reported.
- **Determinism:** deterministic fixed initial condition and thresholds.
- **Principal limitation:** one encounter geometry and one threshold set are
  represented.

### 4.4 Close-encounter comparison

- **Suite identifier:** `close_encounter_comparison`
- **Script:** `examples/validation/close_encounter_comparison.jl`
- **Primary classifications:** scientific-reference; regression; stress
- **Physical regime:** strong binary encounter in a three-body system
- **Current configuration:**
  - 256-bit reference precision;
  - sampling step `0.002`;
  - selected pair `(1, 2)`;
  - entry and exit thresholds `0.10` and `0.25`;
  - Cartesian tolerance `1e-13`;
  - regularized tolerance `1e-12`; and
  - state-evaluation tolerance `1e-14`.
- **Scientific properties tested:**
  - agreement of automatic and manually composed propagation;
  - agreement with an independent high-precision Cartesian reference;
  - consistency of event locations and segment transitions;
  - conservation across each propagation strategy; and
  - comparable work and sampling coverage.
- **Current acceptance measurements:** the script constructs a detailed set of
  method-specific trajectory, state-error, conservation, event-time,
  transition, and work checks and fails if any declared check fails.
- **Descriptive work measurements:** segment count, switch count, accepted and
  rejected steps, right-hand-side evaluations, and saved-state count.
- **Determinism:** deterministic fixed initial condition and thresholds.
- **Principal limitation:** one selected pair, encounter geometry, and threshold
  configuration are represented.

### 4.5 Equilateral triple-collision reference

- **Suite identifier:** `equilateral_triple_collision_reference`
- **Script:** `examples/validation/equilateral_triple_collision_reference.jl`
- **Primary classifications:** scientific-reference; stress
- **Physical regime:** equal-mass homothetic collapse toward triple collision
- **Current configuration:** unit masses, unit side length, close-approach stop
  threshold `1e-5`, and validation separation cutoff `1e-3`
- **Scientific properties tested:**
  - agreement with the analytic homothetic position solution;
  - agreement with the analytic homothetic velocity solution;
  - accurate event separation at numerical termination; and
  - expected stop status near the singularity.
- **Current acceptance measurements:**
  - expected close-approach stop status;
  - maximum scaled position error;
  - maximum scaled velocity error; and
  - event-separation relative error.
- **Determinism:** deterministic analytic reference case.
- **Principal limitation:** validation stops before the physical triple
  singularity and does not test continuation through it.

### 4.6 Randomized-regression validation

- **Suite identifier:** `randomized_regression`
- **Script:** `examples/validation/randomized_regression_validation.jl`
- **Primary classifications:** regression; stress
- **Physical regime:** generated moderate three-body initial conditions
- **Current configuration:**
  - deterministic master seed `0x3b0d_9a71`;
  - 25 trials;
  - duration `5.0`;
  - save interval `0.05`; and
  - minimum initial separation `0.75`.
- **Scientific properties tested:**
  - completion of every generated trial;
  - finiteness of every generated trajectory; and
  - per-trial conservation and centre-of-mass behaviour within fixed limits.
- **Current acceptance measurements:**
  - number of completed trials;
  - number of finite trials; and
  - number of trials satisfying all validation limits.
- **Per-trial descriptive measurements:** generated system and state data,
  conservation metrics, minimum separation, and solver statistics as printed by
  the script.
- **Determinism:** deterministic sequence from one recorded master seed.
- **Principal limitations:** trial-level seeds are not yet first-class report
  fields; generated systems are not grouped by physical regime; aggregate
  counts are the suite-level criteria.

### 4.7 Kustaanheimo–Stiefel Kepler validation

- **Suite identifier:** `ks_kepler`
- **Script:** `examples/validation/ks_kepler_validation.jl`
- **Primary classifications:** scientific-reference; regression
- **Physical regime:** isolated two-body Kepler motion represented in
  Kustaanheimo–Stiefel transformation (KS) coordinates
- **Scientific properties tested:**
  - agreement with the exact KS oscillator solution;
  - accurate physical-time reconstruction;
  - preservation of the KS gauge constraint; and
  - consistency of the KS binding energy.
- **Current acceptance measurements:**
  - maximum KS position-coordinate error;
  - maximum KS velocity-coordinate error;
  - maximum physical-time error;
  - maximum gauge-constraint residual; and
  - maximum energy-consistency residual.
- **Determinism:** deterministic exact-reference problem.
- **Principal limitation:** isolated unperturbed Kepler motion does not exercise
  full three-body perturbations or automatic switching.

### 4.8 KS collision continuation

- **Suite identifier:** `ks_collision_continuation`
- **Script:** `examples/validation/ks_collision_continuation.jl`
- **Primary classifications:** scientific-reference; stress
- **Physical regime:** radial binary collision continued in KS coordinates
- **Scientific properties tested:**
  - finite regularized continuation through zero physical separation;
  - expected symmetry of the reconstructed Cartesian motion;
  - agreement with the analytic KS solution;
  - accurate physical-time reconstruction; and
  - consistency of the KS energy constraint at collision.
- **Current acceptance measurements:**
  - collision radius;
  - Cartesian position symmetry error;
  - maximum numerical KS coordinate error;
  - maximum numerical KS derivative error;
  - maximum physical-time error;
  - collision energy-consistency residual; and
  - finiteness of the post-collision continuation.
- **Determinism:** deterministic analytic collision case.
- **Principal limitation:** isolated radial collision omits third-body
  perturbations and transition logic.

### 4.9 KS/Levi-Civita comparison

- **Suite identifier:** `ks_levi_civita_comparison`
- **Script:** `examples/validation/ks_levi_civita_comparison.jl`
- **Primary classifications:** scientific-reference; regression; stress
- **Physical regime:** the same binary encounter propagated by independent KS
  and Levi-Civita formulations
- **Scientific properties tested:**
  - agreement of reconstructed positions, velocities, physical times, and
  specific energies;
  - energy stability within each regularized formulation;
  - appropriate conditioning treatment close to collision; and
  - agreement at the final transition back to Cartesian variables.
- **Current acceptance measurements:**
  - maximum scaled position discrepancy;
  - maximum ordinary scaled velocity discrepancy;
  - maximum near-collision velocity-conditioning ratio;
  - maximum scaled physical-time discrepancy;
  - maximum scaled specific-energy discrepancy;
  - maximum KS specific-energy drift;
  - maximum Levi-Civita specific-energy drift;
  - final transition position discrepancy; and
  - final transition velocity discrepancy.
- **Determinism:** deterministic common initial condition.
- **Principal limitation:** one planar encounter and one comparison interval are
  represented.

### 4.10 KS hierarchical-triple validation

- **Suite identifier:** `ks_hierarchical_triple`
- **Script:** `examples/validation/ks_hierarchical_triple.jl`
- **Primary classifications:** scientific-reference; regression; stress
- **Physical regime:** pair-centred KS propagation with a perturbing third body
  in a hierarchical triple
- **Scientific properties tested:**
  - agreement with a Cartesian reference trajectory;
  - energy agreement and KS energy stability;
  - gauge-constraint preservation;
  - nonselected-pair separation; and
  - entry and exit reconstruction continuity.
- **Current acceptance measurements:**
  - maximum scaled Cartesian-state discrepancy;
  - maximum relative energy discrepancy;
  - maximum KS relative energy drift;
  - maximum KS gauge-constraint residual;
  - minimum nonselected-pair separation;
  - entry transition-state residual; and
  - exit transition-state residual.
- **Determinism:** deterministic fixed hierarchical system.
- **Principal limitation:** one hierarchy, selected pair, perturbation strength,
  and integration interval are represented.

### 4.11 KS/Levi-Civita automatic-switching comparison

- **Suite identifier:** `ks_switching_comparison`
- **Script:** `examples/validation/ks_switching_comparison.jl`
- **Primary classifications:** scientific-reference; regression; stress
- **Physical regime:** automatic switching using two independent regularization
  backends
- **Current configuration:** entry threshold `0.2`, exit threshold `0.4`,
  ambiguity threshold `0.3`, integration interval `(0.0, 1.6)`, and 161
  comparison samples
- **Scientific properties tested:**
  - completion of both switched trajectories;
  - expected switching activity in both backends;
  - agreement of reconstructed physical states;
  - agreement of entry and exit event times; and
  - small transition residuals in both backends.
- **Current acceptance measurements:**
  - KS completion status;
  - Levi-Civita completion status;
  - KS switch count;
  - Levi-Civita switch count;
  - maximum scaled backend state discrepancy;
  - entry-event time discrepancy;
  - exit-event time discrepancy;
  - maximum KS transition residual; and
  - maximum Levi-Civita transition residual.
- **Determinism:** deterministic common initial condition and thresholds.
- **Principal limitation:** one encounter, one threshold set, and two backend
  choices are represented.

## 5. Cross-suite coverage summary

### 5.1 Coverage already established

The current suite provides direct evidence for:

- strongly coupled periodic motion;
- weakly perturbed multiscale hierarchical motion;
- ordinary conservation diagnostics;
- centre-of-mass behaviour;
- a deterministic randomized sample of moderate triples;
- close-encounter propagation;
- automatic representation switching;
- transition continuity and conservation;
- an analytic approach to triple collision;
- exact isolated KS Kepler motion;
- finite KS continuation through radial binary collision;
- agreement between independent KS and Levi-Civita formulations; and
- perturbed KS propagation in a hierarchical triple.

### 5.2 Principal gaps motivating v0.5

The current suite does not yet provide systematic evidence across:

- substantially longer integration durations;
- controlled mass-ratio, hierarchy, eccentricity, orientation, or impact-
  parameter ranges;
- multiple switching threshold choices;
- classified randomized ensembles for distinct physical regimes;
- independently reproducible per-trial randomized failures;
- near-simultaneous competing close encounters;
- broad Float64/BigFloat comparison points;
- repository-managed reviewed reference records;
- deterministic machine-readable case reports;
- cross-platform reproducibility margins; or
- repeatable performance measurements separated from scientific acceptance.

These gaps correspond directly to Stages V5-V1 through V5-V7.

## 6. Existing metric families the schema must represent

A common result schema must be able to represent every current output without
forcing unrelated quantities into one rigid structure. Required metric families
are:

- execution and completion status;
- integration interval and final-time residual;
- state finiteness and saved-state count;
- absolute, relative, and scaled state errors;
- periodicity and reference-state errors;
- energy values, drifts, discrepancies, jumps, and constraint residuals;
- linear- and angular-momentum drifts;
- centre-of-mass position and velocity residuals;
- minimum pair separation and hierarchy ratio;
- regularized-coordinate and derivative errors;
- gauge-constraint residuals;
- physical-time reconstruction errors;
- event times, event-time discrepancies, and event-separation residuals;
- transition position, velocity, state, energy, and momentum residuals;
- segment and switch counts;
- randomized trial counts and identifiers;
- accepted and rejected steps;
- right-hand-side evaluation counts;
- elapsed time; and
- explanatory status or failure messages.

Metrics must therefore be named, typed, unit-aware where appropriate, and
extensible. The schema must not require every case to populate every metric.

## 7. Current suite invariants to preserve during V5-V1

The structured-result implementation must preserve these behaviours:

- every validation script remains directly executable;
- every current numerical acceptance limit remains unchanged;
- each failed criterion produces a nonzero process exit status;
- an execution error remains distinguishable from a scientific failure;
- the complete suite exits nonzero unless all required cases pass;
- separate-process execution remains available;
- readable console output remains available; and
- no performance measurement becomes a scientific correctness requirement.

## 8. Inventory acceptance statement

This inventory represents all eleven entries in
`VALIDATION_SUITE_ENTRIES` at the v0.4.0 baseline. It identifies the purpose,
classification, principal configuration, acceptance-measurement families,
determinism, and current limitations of every case.

No source code or acceptance criterion is changed by this document.

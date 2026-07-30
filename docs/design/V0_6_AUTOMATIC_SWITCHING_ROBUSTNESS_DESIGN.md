# ThreeBody3D v0.6 Automatic-Switching Robustness Design

## 1. Purpose

This document defines the next numerical-development workstream after the v0.5
validation and performance framework. Its purpose is to improve the scientific
robustness of the experimental Cartesian/regularized switching controller
without weakening the validated behaviour of the existing solvers.

The workstream is deliberately narrower than a general regularization rewrite.
It retains the existing pair-centred Levi-Civita and spatial Kustaanheimo–Stiefel
(KS) formulations and concentrates first on the policy that decides:

- when Cartesian propagation should enter a regularized segment;
- which pair may be selected safely;
- when the regularized segment should return to Cartesian propagation;
- when ambiguity requires safe termination rather than an arbitrary choice; and
- what evidence must be retained at every transition.

The primary objective is improved numerical reliability through close
encounters. Runtime reduction is secondary and must not be obtained by relaxing
scientific acceptance criteria.

## 2. Current foundation

The repository already provides the following experimental building blocks:

- `AutomaticSwitchingParameters`, including entry and exit thresholds,
  ambiguity threshold, minimum pair-isolation ratio, maximum switch count, and
  minimum physical-time progress;
- solver-independent `PairObservables` containing all three pair separations,
  radial rates, deterministic ordering, collision flags, and isolation ratio;
- algebraic `automatic_entry_decision` and `automatic_exit_decision` policies;
- continuous Cartesian entry-event location;
- continuous Levi-Civita and KS exit-event location;
- `simulate_experimental_switching` for alternating Cartesian and regularized
  segments;
- immutable switch-event and structured failure records;
- transition diagnostics, unified physical-time sampling, and trajectory-wide
  diagnostics; and
- scientific validation cases comparing switching backends and Cartesian
  propagation.

These components establish a strong implementation base, but the current policy
uses fixed dimensional thresholds and treats several difficult multi-pair
situations only as terminal failures. The next work must improve evidence and
robustness before broadening supported encounter classes.

## 3. Scope

### 3.1 In scope

The v0.6 switching workstream covers:

1. formal policy invariants and state-machine behaviour;
2. scale-aware threshold definitions;
3. anti-chattering and minimum-dwell safeguards;
4. deterministic handling and classification of pair competition;
5. stronger entry/exit certification;
6. transition conservation and KS gauge-continuity evidence;
7. long-duration and repeated-encounter validation;
8. precision-generic validation where the numerical backend permits it; and
9. documentation of the scientifically supported operating envelope.

### 3.2 Out of scope

This workstream does not introduce:

- chain regularization;
- simultaneous regularization of two or three binaries;
- arbitrary regularization of non-isolated triple collision;
- a production replacement for `simulate`;
- automatic selection of scientific tolerances from timing results;
- silent recovery from ambiguous or unsupported encounter geometry; or
- claims that one regularization backend is universally superior.

Any mathematical extension beyond the existing Levi-Civita and KS formulations
requires a separate formulation review.

## 4. Scientific principles

### 4.1 Accuracy before convenience

A switch is justified only when the combined trajectory is at least as
scientifically credible as the corresponding all-Cartesian trajectory and
provides improved behaviour in the close-encounter regime for which it is
intended.

### 4.2 Fail explicitly rather than choose arbitrarily

When two pairs are simultaneously eligible and the current model cannot justify
one selection, the controller must retain a structured failure or unsupported
classification. Deterministic tie-breaking is useful for reproducibility but is
not scientific evidence that the chosen pair is valid.

### 4.3 Separate observation, policy, event location, and propagation

The existing architectural separation must be retained:

1. `PairObservables` describes geometry and motion;
2. policy functions classify the state;
3. event locators certify threshold crossings;
4. propagation functions integrate one representation; and
5. the controller composes segments and records evidence.

No stage should hide policy inside solver callbacks or infer scientific status
from save-grid samples.

### 4.4 Every transition is an auditable numerical event

Entry and exit records must preserve enough information to reproduce why the
transition occurred and to assess state reconstruction, conserved quantities,
pair hierarchy, and time progress.

## 5. Required invariants

The implementation must make the following invariants explicit and testable.

### 5.1 Mode invariant

At every physical time the controller is in exactly one mode:

- Cartesian; or
- regularized for exactly one ordered pair.

No hidden intermediate mode may own propagation state.

### 5.2 Hysteresis invariant

For the active threshold scale,

```text
0 < entry threshold < exit threshold
```

must hold. A completed entry cannot be followed by an exit at the same physical
time, and a completed exit cannot be followed by re-entry without positive
physical-time progress.

### 5.3 Pair-validity invariant

Entry is allowed only for a unique approaching pair that is the closest pair
and satisfies the configured isolation evidence. While regularized, the
selected pair must remain scientifically supportable as the active pair.

### 5.4 Monotone-time invariant

Segment boundaries and switch events must be strictly ordered in physical time,
subject only to a documented floating-point comparison tolerance. The controller
must never form a zero-time switching loop.

### 5.5 Reconstruction invariant

The Cartesian state reconstructed at every transition must agree with the state
represented on the departing side to within a precision- and scale-aware bound.
Mass, ordering, and physical time must be unchanged by the coordinate handoff.

### 5.6 Failure-retention invariant

On safe termination, all completed segments, switch events, terminal state,
physical time, and structured failure evidence must remain available.

## 6. Scale-aware switching policy

Fixed dimensional distances are useful for controlled tests but are not a
sufficient general policy. v0.6 should introduce a scale abstraction while
retaining explicit absolute thresholds for backwards compatibility.

### 6.1 Threshold model

The design should support an internal threshold model that produces physical
entry, exit, and ambiguity distances from:

- explicit absolute values; or
- dimensionless factors multiplied by a documented local reference scale.

The first scale-aware implementation should use only quantities already defined
and stable at the policy boundary. Candidate scales must be evaluated against
scientific benchmarks before one becomes the default. Plausible candidates
include:

- a characteristic system length supplied by the caller;
- the current second-smallest pair separation;
- a pair-specific osculating or gravitational length; and
- combinations that remain finite for weakly bound or unbound encounters.

No scale formula should be adopted merely because it reduces switch counts.

### 6.2 Freeze policy during a segment

Thresholds used to certify an entry or exit must not drift discontinuously while
the corresponding event is being located. Any local scale used for a
regularized segment must be recorded at entry, with a clearly defined rule for
whether it is frozen or evolves smoothly.

### 6.3 Backwards compatibility

Existing `AutomaticSwitchingParameters` construction with absolute thresholds
must continue to work throughout the experimental period. A new scale policy
should be introduced as a separate immutable object or an additive field with a
non-breaking default, not by silently changing existing semantics.

## 7. Pair competition and ambiguity

### 7.1 Classification

The controller must distinguish at least:

- no eligible pair;
- one unique isolated approaching pair;
- multiple entry candidates;
- one candidate that is not the closest pair;
- insufficient isolation;
- selected-pair hierarchy loss;
- selected-pair collision;
- non-selected-pair collision; and
- near-simultaneous threshold crossings.

Existing reason symbols should be retained unless a migration is documented.
New classifications must be machine-readable and covered by exhaustive tests.

### 7.2 Competition evidence

For ambiguous states, diagnostics should retain:

- all pair separations and radial rates;
- ordering and isolation ratio;
- active thresholds and their scale source;
- eligible candidate set;
- selected pair, when one exists; and
- the exact policy rule that prevented or permitted a switch.

### 7.3 Unsupported geometries

A close triple or two simultaneously close binaries remain outside the supported
single-pair model. v0.6 may improve their classification and early detection,
but must not disguise them as successful single-pair regularization.

## 8. Anti-chattering and progress safeguards

The current `maximum_switches` and `minimum_time_progress` checks form a useful
base. v0.6 should formalise them into a controller-level progress policy.

Required evidence includes:

- time since the previous switch;
- separation change since the previous switch;
- whether the entry and exit thresholds were crossed in the required direction;
- consecutive switches involving the same unordered pair;
- pair changes between adjacent regularized segments; and
- termination reason when a progress invariant is violated.

A minimum dwell-time or minimum separation-excursion rule may be added only if
its scaling and effect on valid repeated encounters are validated. It must not
suppress a physically distinct second encounter.

## 9. Transition quality and gauge continuity

### 9.1 Common transition diagnostics

Both Levi-Civita and KS backends must report a common minimum set:

- state reconstruction residual;
- relative-position and relative-velocity residuals for the selected pair;
- physical-time residual;
- total-energy jump;
- linear-momentum jump;
- angular-momentum jump;
- centre-of-mass position and velocity jumps; and
- active pair and orientation.

### 9.2 Scale-aware residuals

Absolute residuals should be retained, but scientific comparisons should also
use well-defined scaled residuals that remain meaningful across encounter size
and precision. Zero-reference quantities require explicit handling rather than
unbounded relative errors.

### 9.3 KS gauge evidence

For KS entry, continuation, and exit, diagnostics must record enough information
to verify that gauge choice and reconstruction remain continuous. Gauge-equivalent
states should not be reported as physical discontinuities. Any gauge projection
or normalisation introduced in v0.6 requires an independent mathematical review
and dedicated round-trip tests.

## 10. Validation programme

No switching-policy change is accepted from unit tests alone. Each increment
must pass package tests and the applicable scientific validation tier.

### 10.1 Algebraic policy matrix

Construct deterministic state families spanning:

- separations just outside, at, and just inside every threshold;
- approaching, tangential, stationary, and receding radial motion;
- isolation ratios below, at, and above the required value;
- exact and near ties between pair separations;
- all three canonical pairs and reversed ordered-pair orientations;
- exact selected and non-selected collisions; and
- Float64 and BigFloat where supported.

The matrix must verify action, pair, reason, and retained evidence.

### 10.2 Event-location invariance

Entry and exit times must be insensitive to output `saveat` and stable under
reasonable solver-tolerance refinement. Tests must compare located states and
not only callback status.

### 10.3 Backend cross-validation

For encounter classes supported by both planar Levi-Civita and spatial KS,
compare:

- switch count and event ordering;
- entry and exit times;
- reconstructed Cartesian states;
- trajectory diagnostics;
- work counts; and
- behaviour under tolerance refinement.

Differences must be described scientifically; no backend wins solely from one
wall-clock result.

### 10.4 Repeated-encounter trajectories

Add trajectories containing multiple well-separated close encounters to test:

- repeated entry/exit cycles;
- absence of chattering;
- long-duration energy and momentum behaviour;
- preservation of pair identity; and
- correct handling when the closest pair changes between encounters.

### 10.5 Boundary and unsupported cases

Add cases that deliberately approach the limits of the single-pair model:

- weak isolation;
- near-simultaneous pair approaches;
- hierarchical-triple breakdown;
- near-degenerate relative angular momentum;
- high eccentricity and near-parabolic passage; and
- perturbations that cause selected-pair hierarchy loss.

Success for these cases may be a precise, reproducible safe failure rather than
continued propagation.

### 10.6 Precision and reference checks

Selected cases should compare Float64 results with higher-precision or
independent reference trajectories. Acceptance should examine convergence under
precision and tolerance refinement, not agreement with a single finite-precision
run.

## 11. Staged implementation plan

### Stage AS-0 — Policy inventory and invariant tests

**Objective:** Freeze current behaviour in a comprehensive algebraic decision
matrix and document every existing reason symbol.

**Changes:** Tests and documentation only unless an inconsistency prevents
faithful classification.

**Acceptance gate:** Existing behaviour is reproducible for all pairs,
orientations, threshold boundaries, and collision classes.

**Suggested commit:** `Define automatic-switching policy invariants`

### Stage AS-1 — Structured decision evidence — complete

**Objective:** Extend decisions or companion records so every policy outcome
retains candidate, threshold, scale, and pair-competition evidence.

**Acceptance gate:** Diagnostics can explain every `:none`, `:enter`, `:exit`,
and `:failure` result without recomputing hidden policy state.

**Suggested commit:** `Add automatic-switching decision evidence`

### Stage AS-2 — Scale-policy abstraction — complete

**Objective:** Introduce an immutable, backwards-compatible abstraction for
absolute and experimental scale-aware thresholds.

**Acceptance gate:** Absolute-threshold behaviour is unchanged; scale-aware
thresholds are deterministic, finite, recorded, and unit tested.

**Suggested commit:** `Add scale-aware switching thresholds`

### Stage AS-3 — Certified progress and anti-chattering — complete

**Objective:** Make dwell/progress invariants explicit in controller state and
failure records.

**Acceptance gate:** Synthetic boundary oscillations terminate or progress
predictably, while physically separate repeated encounters are not suppressed.

**Suggested commit:** `Strengthen automatic-switching progress safeguards`

### Stage AS-4 — Pair-competition robustness

**Objective:** Improve classification and event evidence for changing or
near-simultaneous closest pairs without adding unsupported multi-pair
regularization.

**Acceptance gate:** Pair competition is deterministic, auditable, and never
resolved by an undocumented arbitrary choice.

**Suggested commit:** `Strengthen automatic-switching pair competition handling`

### Stage AS-5 — Transition and KS gauge diagnostics

**Objective:** Provide common scaled transition diagnostics and explicit KS
gauge-continuity evidence.

**Acceptance gate:** Entry/exit residuals converge under tolerance refinement
and gauge-equivalent states are correctly identified.

**Suggested commit:** `Strengthen regularization transition diagnostics`

### Stage AS-6 — Repeated-encounter validation

**Objective:** Add scientific cases with multiple switching cycles and changing
encounter geometry.

**Acceptance gate:** Long-duration invariants, event ordering, and failure
classification meet documented limits across repeated runs and save grids.

**Suggested commit:** `Add repeated-encounter switching validation`

### Stage AS-7 — Scientific threshold study

**Objective:** Use the v0.5 validation and performance framework to compare
candidate scale policies and threshold ranges.

**Acceptance gate:** A recommended experimental policy is supported by accuracy,
robustness, and work evidence across the approved case set. No default changes
without review of the complete evidence.

**Suggested commit:** `Evaluate automatic-switching threshold policies`

### Stage AS-8 — Supported-scope review

**Objective:** Decide whether the improved controller is ready for broader
experimental use and document remaining limitations.

**Acceptance gate:** API tier, supported encounter classes, safe-failure classes,
and release evidence are explicit. Promotion into the stable `simulate` API is
not automatic.

**Suggested commit:** `Document automatic-switching supported scope`

## 12. Compatibility and API policy

All automatic-switching interfaces remain experimental during this workstream.
Existing public experimental constructors and result accessors should remain
source-compatible unless a demonstrated correctness issue requires change.

New records should be immutable and precision-generic. Internal implementation
helpers need not be exported. Serialization is required only for evidence that
must enter the structured validation workflow; it should not be added merely to
increase framework surface area.

## 13. Acceptance evidence for algorithm changes

Every source-code increment after AS-0 must provide:

1. focused unit tests;
2. full `Pkg.test()` success;
3. applicable scientific validation cases;
4. before/after structured reports;
5. tolerance-refinement evidence;
6. accuracy-versus-work evidence where work changes materially; and
7. an explicit statement of supported and unsupported geometry.

A reduction in elapsed time, step count, or switch count is not sufficient.
Improvement means better accuracy or robustness, or equivalent scientific
quality with clearly reduced work and no hidden loss of coverage.

## 14. Immediate next action

Stage **AS-0 — Policy inventory and invariant tests** is complete. The current
behaviour is frozen by `AUTOMATIC_SWITCHING_POLICY_INVENTORY.md` and the
table-driven tests in `test/automatic_switching_policy_inventory.jl`. No
switching decision was changed.

Stage **AS-1 — Structured decision evidence** is complete. Algebraic entry and
exit decisions now retain immutable, precision-generic evidence for observables,
effective absolute thresholds, candidates, selected pairs, and pair competition.
AS-0 actions, reasons, orientations, boundaries, and precedence remain unchanged.

Stage **AS-2 — Scale-policy abstraction** is complete. Immutable absolute and
experimental characteristic-length policies now resolve once into fixed physical
thresholds. The existing keyword-only parameter constructor remains the absolute
default, and decision evidence retains the scale kind and reference scale.

Stage **AS-3 — Certified progress and anti-chattering** is complete. Existing
segment-level time-progress semantics remain unchanged. Immutable progress state
and evidence now support an opt-in same-pair exit-to-re-entry separation
excursion, while first switches and pair changes remain unaffected.

Stage AS-4 is now in progress. AS-4a adds immutable quantitative competition
evidence to algebraic entry and exit decisions without changing policy. The next
increment is AS-4b, certified event-crossing provenance, as defined in
`V0_6_AS4_PAIR_COMPETITION_DESIGN.md`.

# v0.6 AS-4 Pair-Competition Robustness Design

## 1. Purpose

Stage AS-4 strengthens how the experimental automatic-switching subsystem
classifies, records, and reports competition between binary pairs.

The stage does **not** add multi-pair regularization and does **not** permit the
controller to choose one pair merely because a deterministic ordering exists.
Its purpose is to make unsupported or marginal single-pair geometry explicit,
quantitative, reproducible, and auditable while preserving the AS-0 decision
matrix unless a later implementation increment is separately reviewed.

## 2. Current behaviour to preserve

The current algebraic policy already provides deterministic canonical ordering
for `(1,2)`, `(1,3)`, and `(2,3)`, and retains all three separations, radial
rates, collision flags, ordering, isolation ratio, candidate mask, candidate
count, candidate or selected pair, selected index, and second-closest index.

The following AS-0 actions, reasons, boundaries, and precedence rules remain
frozen during the first AS-4 implementation increment:

- exact collision precedes entry-candidate classification;
- more than one entry candidate returns
  `:failure/:simultaneous_entry_candidates`;
- a unique candidate that is not closest returns
  `:failure/:candidate_not_closest`;
- ambiguity-threshold equality returns
  `:failure/:ambiguous_close_pairs`;
- isolation-ratio equality is accepted;
- while regularized, a non-selected collision precedes selected-pair collision;
- loss of selected-pair hierarchy returns
  `:failure/:selected_pair_lost`; and
- deterministic canonical ordering remains a reproducibility mechanism, not a
  scientific selection rule.

AS-4 must not silently convert any current failure into entry, exit, or
continued propagation.

## 3. Problem statement

The current evidence identifies which pairs were candidates and which pair was
closest, but it does not directly quantify how strongly the leading pair was
separated from its competitors or how close each pair was to an entry or exit
boundary. Event-locator helper decisions can also omit algebraic evidence when
they rely on a continuously certified threshold crossing.

Consequently, a reviewer can reconstruct pair competition from retained raw
values, but the record does not yet state the competition margins or crossing
provenance explicitly. Near-simultaneous threshold crossings therefore remain
less auditable than the algebraic policy itself.

## 4. Scientific constraints

### 4.1 Single-pair support only

A close triple, two simultaneously eligible binaries, or a changing closest
pair remains outside the supported single-pair regularization model. AS-4 may
classify these states more precisely, but it must not disguise them as a
successful single-pair choice.

### 4.2 Determinism is not validity

Exact ties continue to use canonical ordering so repeated runs are identical.
No implementation may interpret that ordering as evidence that the first
canonical pair is physically preferred.

### 4.3 Observation, policy, event location, and propagation remain separate

- `PairObservables` describes geometry and motion.
- algebraic policy functions classify the state;
- event locators certify threshold crossings;
- propagation routines integrate one representation; and
- the alternating controller composes segments and retains evidence.

Pair-competition rules must not be hidden inside solver callbacks.

### 4.4 No tolerance invented from machine epsilon

AS-4 must not introduce an undocumented fuzzy tie or arbitrary relative
comparison. Any future numerical competition tolerance must have an explicit
physical or dimensionless definition, be recorded in evidence, and be studied
through validation before affecting actions.

## 5. Required competition evidence

The first AS-4 source increment should extend immutable decision evidence with
quantities derived deterministically from the already retained observables and
resolved thresholds.

### 5.1 Separation competition

Record:

- closest separation;
- second-closest separation;
- absolute separation gap
  `second_closest_separation - closest_separation`;
- relative separation gap, normalised by the closest separation when nonzero;
- whether the two leading separations are exactly tied; and
- the canonical indices and unordered pairs of the two leading competitors.

For an exact closest-pair collision, the relative gap must use an explicit
sentinel or `nothing`; it must not divide by zero.

### 5.2 Threshold margins

For each canonical pair, record signed margins relative to the resolved entry
threshold:

```text
entry_margin = separation - enter_threshold
```

For exit evidence, also record the selected pair's signed margin:

```text
exit_margin = selected_separation - exit_threshold
```

The sign convention is fixed:

- non-positive entry margin means geometrically at or inside the entry
  threshold;
- non-negative exit margin means geometrically at or outside the exit
  threshold.

Radial direction remains independent evidence and is not folded into these
margins.

### 5.3 Candidate competition

Retain the existing candidate mask and count, and add a canonical tuple of all
candidate pairs. The tuple must be derived from the mask without sorting by
floating-point values.

For a unique candidate, record whether it is:

- the closest pair;
- exactly tied for closest separation; or
- not the closest pair.

These fields explain existing outcomes but do not alter them.

### 5.4 Isolation margins

Record:

- absolute ambiguity margin
  `second_closest_separation - ambiguity_threshold`; and
- isolation-ratio margin
  `isolation_ratio - minimum_separation_ratio`.

Equality semantics remain those frozen by AS-0. The margins make the distance
to those boundaries explicit.

### 5.5 Crossing provenance

Decisions produced after continuous event location must identify whether their
threshold crossing came from:

- a complete algebraic policy evaluation;
- a continuously certified inward Cartesian crossing; or
- a continuously certified outward regularized crossing.

Crossing provenance must not weaken post-event pair-validity and isolation
checks. Where dense interpolation differs by a few ulps from the root condition,
the event locator remains authoritative only for the crossed pair's threshold
and direction; pair competition is still evaluated from the reconstructed state.

## 6. Proposed immutable record

The preferred first increment is an additive record referenced by
`AutomaticSwitchingDecisionEvidence`, rather than a new controller policy.
A suitable conceptual structure is:

```julia
struct AutomaticSwitchingCompetitionEvidence{T<:AbstractFloat}
    closest_index::Int
    second_index::Int
    closest_pair::Tuple{Int,Int}
    second_pair::Tuple{Int,Int}
    closest_separation::T
    second_separation::T
    absolute_separation_gap::T
    relative_separation_gap::Union{Nothing,T}
    exact_closest_tie::Bool
    entry_margins::NTuple{3,T}
    exit_margin::Union{Nothing,T}
    ambiguity_margin::T
    isolation_ratio_margin::T
    candidate_pairs::Tuple
    candidate_is_closest::Union{Nothing,Bool}
    candidate_tied_for_closest::Union{Nothing,Bool}
    crossing_provenance::Symbol
end
```

The exact Julia representation of `candidate_pairs` should be chosen for type
stability after focused implementation review. Acceptable provenance symbols
should be closed and validated, for example:

- `:algebraic`;
- `:certified_cartesian_entry`; and
- `:certified_regularized_exit`.

No public constructor should require callers to calculate derived margins by
hand. Internal builders should derive them from `PairObservables`, resolved
parameters, phase, selected/candidate pair, and provenance.

## 7. Implementation increments

### AS-4a — Competition evidence record — complete

The immutable precision-generic competition record and internal builder are
implemented. They are attached to every algebraic entry and exit decision.
Attach it to every algebraic entry and exit decision without changing actions,
reasons, pairs, boundaries, or precedence.

**Acceptance gate**

- all AS-0 through AS-3 tests pass unchanged;
- exhaustive focused tests cover every canonical pair;
- exact ties, collisions, threshold equality, and ratio equality are covered;
- `Float64` and `BigFloat` are covered; and
- all derived margins are deterministic and finite except for explicitly
  documented collision sentinels.

**Suggested commit**

```text
Add pair-competition decision evidence
```

### AS-4b — Event-crossing provenance

Ensure decisions returned by Cartesian and regularized event locators retain
competition evidence and explicit crossing provenance, including the certified
crossing paths currently represented by helper decisions with no algebraic
evidence.

**Acceptance gate**

- save-grid changes do not alter provenance or competition classification;
- continuously certified crossings retain the located event pair and direction;
- post-event closest-pair, ambiguity, and isolation checks remain unchanged;
- existing locator status and reason semantics remain compatible; and
- failure records retain the complete decision evidence.

**Suggested commit**

```text
Retain pair competition at certified crossings
```

### AS-4c — Near-simultaneous crossing classification study

Add synthetic and integrated tests that vary the temporal spacing between two
candidate threshold crossings. This increment is evidence gathering first. It
must determine whether the existing state-based classifications are sufficient
or whether a separately configured event-time competition tolerance is
scientifically justified.

No controller action changes are authorised in AS-4c without a reviewed design
amendment and before/after validation evidence.

**Acceptance gate**

- deterministic results across repeated runs and save grids;
- explicit classification of exact and near-simultaneous synthetic cases;
- no arbitrary pair selection;
- documented supported and unsupported geometry; and
- a recommendation, which may be to retain strict current behaviour.

**Suggested commit**

```text
Study near-simultaneous switching events
```

## 8. Test matrix

Focused tests should include:

1. one unique isolated candidate for each canonical pair;
2. two and three simultaneous entry candidates;
3. unique candidate not closest;
4. exact separation ties in every canonical ordering position;
5. ambiguity-threshold equality and values immediately around it;
6. isolation-ratio equality and values immediately around it;
7. selected-pair hierarchy loss for every selected pair orientation;
8. selected and non-selected collision precedence;
9. certified Cartesian entry whose dense state lies a few ulps outside the
   threshold;
10. certified regularized exit whose reconstructed state lies a few ulps inside
    the threshold;
11. `Float64` and `BigFloat`; and
12. constructor validation for all new immutable evidence fields.

Tests must assert both the unchanged decision and the new quantitative evidence.

## 9. Validation requirements

AS-4a is observational and should not change trajectories. Its validation is
therefore:

- complete `Pkg.test()` success;
- unchanged existing automatic-switching benchmark outputs; and
- deterministic evidence across repeated evaluations.

AS-4b and AS-4c additionally require the applicable Cartesian, Levi-Civita, KS,
and alternating-switching validation cases. Any later action change requires
structured before/after reports, tolerance refinement, and accuracy-versus-work
evidence as specified by the parent robustness design.

## 10. Compatibility policy

All additions should be backwards compatible:

- existing public experimental constructors continue to work;
- existing `AutomaticSwitchingDecision` fields remain available;
- current reason symbols and actions are unchanged in AS-4a and AS-4b;
- new records are immutable and precision-generic;
- internal builders need not be exported; and
- serialization is added only if the evidence enters structured validation
  artifacts.

## 11. Current implementation recommendation

AS-4a is implemented. After its evidence representation and complete regression
results are reviewed, proceed with **AS-4b — Event-crossing provenance**. No
controller action or pair-selection policy change is authorised.

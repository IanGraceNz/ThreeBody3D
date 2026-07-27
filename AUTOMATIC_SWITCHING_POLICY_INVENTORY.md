# Automatic-Switching Policy Inventory

## 1. Purpose

This document records the algebraic behaviour of the experimental automatic
Cartesian/regularized switching policy at the start of the v0.6 robustness
workstream. It is a behavioural inventory, not a proposed policy change.

The inventory covers:

- `pair_observables`;
- `automatic_entry_decision`; and
- `automatic_exit_decision`.

Event location, segment propagation, controller progress checks, and transition
diagnostics are outside this AS-0 inventory.

## 2. Canonical pair convention

Unordered binary geometry is stored in the fixed canonical order:

```text
index 1: (1, 2)
index 2: (1, 3)
index 3: (2, 3)
```

`pair_observables` sorts these indices by increasing separation. Exact distance
ties are broken by canonical index, so the ordering is deterministic.

Entry decisions always return a canonical pair. Exit decisions retain the exact
ordered pair supplied by the active regularized mode, including reversed
orientations such as `(2, 1)`.

## 3. Pair observables

For every canonical pair, `pair_observables` records:

- separation;
- radial separation rate;
- exact-collision flag;
- deterministic separation order;
- closest and second-closest pairs; and
- the ratio of the second-smallest to smallest separation.

The radial rate is

```text
dot(relative position, relative velocity) / separation
```

when the separation is nonzero. At exact collision the stored radial rate is
zero and the collision flag, rather than that zero, determines policy.

The isolation ratio is:

- the ordinary positive ratio away from collision;
- positive infinity for one isolated exact collision; and
- one when at least the two smallest separations are zero.

## 4. Entry policy

A pair is an entry candidate exactly when:

```text
separation <= enter_threshold
and
radial_rate < 0
```

The distance boundary is inclusive. Zero radial rate is not approaching.
Policy checks occur in the order listed below; the first applicable outcome is
returned.

| Action | Reason | Pair field | Current meaning |
|---|---|---:|---|
| `:failure` | `:collision_state` | closest canonical pair | At least one pair is at exact collision. |
| `:none` | `:no_entry_candidate` | `nothing` | No pair is both at/below the entry threshold and approaching. |
| `:failure` | `:simultaneous_entry_candidates` | `nothing` | More than one pair satisfies the entry-candidate test. |
| `:failure` | `:candidate_not_closest` | candidate | The unique candidate is not the closest pair. |
| `:failure` | `:ambiguous_close_pairs` | candidate | The second-smallest separation is at or below `ambiguity_threshold`. |
| `:failure` | `:insufficient_pair_isolation` | candidate | The isolation ratio is strictly below `minimum_separation_ratio`. |
| `:enter` | `:unique_approaching_pair` | candidate | One closest, non-ambiguous, sufficiently isolated pair is eligible. |

Consequences of the ordered checks include:

- collision classification takes precedence over all candidate logic;
- simultaneous candidacy takes precedence over closest-pair and isolation
  checks; and
- equality with `minimum_separation_ratio` is accepted.

## 5. Exit policy

The selected ordered pair is mapped to its canonical geometry index for policy
evaluation. Policy checks occur in the order listed below.

| Action | Reason | Pair field | Current meaning |
|---|---|---:|---|
| `:failure` | `:nonselected_pair_collision` | selected ordered pair | A pair other than the selected pair is at exact collision. |
| `:none` | `:selected_pair_collision` | selected ordered pair | The selected pair is at exact collision and regularized propagation should continue. |
| `:failure` | `:selected_pair_lost` | selected ordered pair | The selected pair is no longer the closest pair. |
| `:failure` | `:ambiguous_close_pairs` | selected ordered pair | The second-smallest separation is at or below `ambiguity_threshold`. |
| `:failure` | `:insufficient_pair_isolation` | selected ordered pair | The isolation ratio is strictly below `minimum_separation_ratio`. |
| `:exit` | `:isolated_receding_pair` | selected ordered pair | The isolated selected pair is at/above the exit threshold and receding. |
| `:none` | `:exit_condition_not_met` | selected ordered pair | All safety checks pass, but the exit distance or radial-direction condition is not met. |

Exit occurs exactly when:

```text
selected separation >= exit_threshold
and
selected radial rate > 0
```

The distance boundary is inclusive. Zero radial rate is not receding. Equality
with `minimum_separation_ratio` is accepted.

Collision precedence is intentional: a non-selected collision is reported
before a selected-pair collision if both are present.

## 6. AS-0 invariant coverage

The AS-0 tests freeze the current policy for:

- all three canonical pairs;
- both orientations of every selected exit pair;
- deterministic exact-distance ties;
- entry and exit threshold equality;
- zero, negative, and positive radial-rate boundaries;
- ambiguity-threshold equality;
- isolation-ratio equality and strict failure below it;
- unique and simultaneous candidates;
- candidate-not-closest geometry;
- selected-pair hierarchy loss;
- isolated, selected, non-selected, and triple collision classes; and
- `Float64` and `BigFloat` decision arithmetic.

These tests describe existing behaviour. Any future change to a reason, boundary,
precedence rule, pair orientation, or action requires an explicit later-stage
policy review rather than an incidental test update.


## 7. AS-1 decision evidence

Beginning with AS-1, every result returned directly by
`automatic_entry_decision` or `automatic_exit_decision` retains immutable
`AutomaticSwitchingDecisionEvidence`. The evidence records the original pair
observables, effective absolute thresholds, entry-candidate mask and count,
candidate or selected pair, selected canonical index, and second-closest index.

This addition does not alter any AS-0 action, reason, pair orientation, boundary,
or precedence rule. The legacy three-argument `AutomaticSwitchingDecision`
constructor remains available for controller helper outcomes that do not result
from one complete algebraic policy evaluation; those records have `evidence ===
nothing`.

## 8. AS-2 threshold policies

AS-2 separates threshold specification from the resolved physical distances used
by the controller.

`AbsoluteSwitchingThresholdPolicy` stores the existing explicit entry, exit, and
ambiguity distances. The original keyword-only `AutomaticSwitchingParameters`
constructor delegates to this policy and therefore retains the AS-0 behaviour.

`ScaleAwareSwitchingThresholdPolicy` is experimental. It stores one positive
caller-supplied `characteristic_length` and dimensionless entry, exit, and
ambiguity factors. Construction of `AutomaticSwitchingParameters(policy)`
multiplies the factors by that immutable reference scale exactly once. The
resolved physical thresholds remain fixed throughout later event location and
regularized propagation.

Decision evidence records `scale_kind` and `reference_scale` in addition to the
resolved physical thresholds. AS-2 supports only the documented scale kinds
`:absolute` and `:characteristic_length`; it does not infer a dynamical scale,
change the default policy, or recommend scale factors.


## AS-3 certified progress and anti-chattering

The controller now retains immutable progress state after each successful switch.
The existing segment-level `minimum_time_progress` checks remain unchanged. An
optional `minimum_separation_excursion` applies only to an entry following a
successful exit of the same unordered pair. The default value is zero, so the
AS-0 controller behaviour remains unchanged unless the safeguard is explicitly
configured. Pair changes are never rejected by the same-pair excursion rule.

Progress failures retain `AutomaticSwitchingProgressEvidence`, including the
prior switch, elapsed physical time, pair identity, observed excursion, required
excursion, and the machine-readable certification reason. Event locators remain
authoritative for crossing direction; AS-3 does not add a second direction test.

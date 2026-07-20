# IMPLEMENTATION_PLAN_KS

## ThreeBody3D Kustaanheimo–Stiefel Transformation (KS) Regularization Implementation Plan

**Status:** Proposed implementation roadmap  
**Target branch:** `v0.4-development`  
**Governing specification:** `KS_REGULARIZATION_DESIGN.md`

---

## 1. Purpose

This document defines the implementation sequence for the
Kustaanheimo–Stiefel regularization subsystem in ThreeBody3D.

It translates the mathematical requirements in
`KS_REGULARIZATION_DESIGN.md` into small, testable engineering stages.

The objectives are to:

- preserve scientific correctness;
- keep each implementation step independently reviewable;
- prevent unverified mathematics from entering the ODE solver;
- establish explicit acceptance gates before later stages begin;
- maintain a clean Git history of small, fully tested commits.

This document does not redefine the mathematics. If this plan conflicts with
`KS_REGULARIZATION_DESIGN.md`, the design specification takes precedence.

---

## 2. Development principles

All KS implementation work shall follow these principles.

### 2.1 Mathematics before dynamics

Pure transformations and identities shall be implemented and tested before any
regularized ODE is introduced.

### 2.2 One responsibility per stage

Each stage shall introduce one coherent capability.

A stage shall not combine unrelated architectural, mathematical, and
visualization changes.

### 2.3 Tests before integration

A lower-level stage must pass its complete test set before later modules depend
on it.

### 2.4 No hidden correction

Gauge projection, force softening, and undocumented stabilization shall not be
introduced during initial implementation.

### 2.5 Generic precision

All algorithms shall support at least:

    Float32
    Float64
    BigFloat

without separate implementations.

### 2.6 Small commits

Each completed unit of work shall be committed separately after:

    git diff --check
    julia --project=. -e "using Pkg; Pkg.test()"

Validation examples shall also be run when a stage introduces new scientific
behavior.

---

## 3. Planned module structure

The final structure may be consolidated during implementation, but the
responsibilities shall remain separated.

    src/
        Regularization/
            KS.jl
            KSTransforms.jl
            KSState.jl
            KSDynamics.jl
            KSDiagnostics.jl
            KSReconstruction.jl

Suggested responsibilities:

### `KSTransforms.jl`

- forward position map;
- radius identity;
- analytic Jacobian;
- gauge direction;
- finite gauge action;
- inverse position lift;
- velocity transformations;
- gauge alignment.

### `KSState.jl`

- internal state representation;
- state packing and unpacking;
- parameter containers;
- precision-generic constructors.

### `KSDynamics.jl`

- unperturbed KS oscillator;
- perturbed relative dynamics;
- propagated energy variable;
- pair-centred three-body coupling.

### `KSReconstruction.jl`

- relative Cartesian reconstruction;
- complete three-body reconstruction;
- physical-time reconstruction;
- dense-output conversion.

### `KSDiagnostics.jl`

- algebraic residuals;
- gauge residuals;
- energy consistency;
- transition diagnostics;
- acceptance calculations.

### `KS.jl`

- internal module assembly;
- controlled exports to the parent regularization subsystem.

---

## 4. Stage KS-0: Repository preparation

### Objective

Prepare the regularization subsystem for KS files without changing numerical
behavior.

### Deliverables

- confirm the existing regularization module layout;
- add empty or minimally assembled KS source files;
- include them from the correct parent module;
- avoid exporting new public functions;
- add a dedicated KS test file to `test/runtests.jl`.

### Tests

- package loads successfully;
- existing test suite remains unchanged and passes;
- no method ambiguities are introduced;
- Aqua remains clean.

### Acceptance gate

    Existing package behavior is unchanged.
    All existing tests pass.
    Working tree contains only KS scaffolding changes.

### Suggested commit

    Add KS regularization module scaffolding

---

## 5. Stage KS-1: Forward transformation

### Objective

Implement the normative forward position transformation from
`KS_REGULARIZATION_DESIGN.md`.

### Functions

Suggested internal interface:

```julia
ks_position(u)
ks_radius(u)
ks_jacobian(u)
ks_gauge_direction(u)
ks_constraint_residual(u, w)
```

### Mathematical definitions

Implement exactly:

    x = u₁² - u₂² - u₃² + u₄²
    y = 2(u₁u₂ - u₃u₄)
    z = 2(u₁u₃ + u₂u₄)

    ρ = uᵀu

             ┌ 2u₁  -2u₂  -2u₃   2u₄ ┐
    J(u)  =  │ 2u₂   2u₁  -2u₄  -2u₃ │
             └ 2u₃   2u₄   2u₁   2u₂ ┘

    g(u) = (u₄, -u₃, u₂, -u₁)

    C(u, w) = g(u)ᵀw.

### Implementation requirements

- use fixed-size vectors and matrices;
- avoid heap allocation;
- preserve scalar type;
- do not introduce quaternion dependencies;
- keep component ordering identical to the design document.

### Unit tests

#### Exact fixtures

Test basis states and mixed-component states that exercise every sign.

#### Radial identity

    ‖ks_position(u)‖ = ks_radius(u)

within precision-scaled tolerance.

#### Jacobian identity

    J(u)J(u)ᵀ = 4ρI₃.

#### Gauge null direction

    J(u)g(u) = 0.

#### Finite-difference check

Compare the analytic Jacobian with a central finite-difference approximation
for representative nonzero states.

Finite differences are test-only.

#### Precision coverage

Run the same core identities for:

    Float32
    Float64
    BigFloat.

### Acceptance gate

- all algebraic identities pass;
- no allocations occur in the elementary transformation functions under normal
  compiled use;
- finite-difference checks agree with the analytic Jacobian;
- the full package test suite passes.

### Suggested commit

    Implement KS forward transformations

---

## 6. Stage KS-2: Gauge action

### Objective

Implement the finite gauge transformation and verify fiber invariance.

### Functions

```julia
ks_gauge_transform(u, phi)
ks_gauge_transform(u, w, phi)
align_ks_gauge(u, w, reference_u)
```

### Mathematical definition

Implement the fixed gauge action:

             ┌  cosφ    0       0     sinφ ┐
             │   0     cosφ  -sinφ    0    │
    G(φ)  =  │   0     sinφ   cosφ    0    │
             └ -sinφ    0       0     cosφ ┘.

### Alignment rule

Given candidate `u` and reference `uref`:

    a = uᵀuref
    b = g(u)ᵀuref
    φ = atan(b, a)

then

    ualigned = G(φ)u.

Apply the same transformation to `w`.

### Unit tests

- `ks_position(G(phi)u) == ks_position(u)`;
- `ks_radius(G(phi)u) == ks_radius(u)`;
- group composition:

      G(phi_1)G(phi_2)u = G(phi_1 + phi_2)u;

- `G(0)u == u`;
- `G(pi)u == -u`;
- gauge alignment does not alter Cartesian position or velocity;
- aligned representative is no farther from the reference than the original
  candidate;
- BigFloat tests use high-precision angle values.

### Acceptance gate

Gauge invariance and group composition pass across randomized tests and all
supported scalar types.

### Suggested commit

    Implement KS gauge transformations

---

## 7. Stage KS-3: Deterministic inverse position lift

### Objective

Implement a numerically stable Cartesian-to-KS position lift using the
two-chart design.

### Function

```julia
cartesian_to_ks_position(q; reference=nothing)
```

### Positive-axis chart

When `x >= 0`:

    d₊ = √(2(ρ + x))

    u₁ = 0
    u₂ = -z/d₊
    u₃ =  y/d₊
    u₄ = -d₊/2.

### Negative-axis chart

When `x < 0`:

    d₋ = √(2(ρ - x))

    u₁ =  y/d₋
    u₂ =  d₋/2
    u₃ =  0
    u₄ =  z/d₋.

### Collision policy

For

    ρ = 0,

returning a unique nonhistorical lift is not meaningful.

The function shall either:

- throw a documented domain error; or
- require an explicit collision-handling path used only by regularized-state
  continuation.

The public internal helper for ordinary switching should reject exact
collision.

### Reference alignment

When `reference` is supplied:

- compute the deterministic chart representative;
- align it over the complete gauge fiber;
- preserve Cartesian reconstruction exactly to numerical tolerance.

### Unit tests

- round trip:

      q → u → q;

- positive and negative `x` axes;
- points near both axes;
- chart boundary near `x = 0`;
- wide dynamic range;
- arbitrary rotations represented as randomized Cartesian vectors;
- reference alignment continuity;
- `Float32`, `Float64`, and `BigFloat`;
- exact collision rejection.

### Acceptance gate

Position round trips meet the precision-scaled acceptance criteria in
`KS_REGULARIZATION_DESIGN.md`, including axis and near-axis cases.

### Suggested commit

    Implement deterministic Cartesian to KS lift

---

## 8. Stage KS-4: Velocity transformations

### Objective

Implement horizontal Cartesian-to-KS velocity lifting and KS-to-Cartesian
velocity reconstruction.

### Functions

```julia
cartesian_to_ks_velocity(u, v)
ks_to_cartesian_velocity(u, w)
cartesian_to_ks_state(q, v; reference=nothing)
```

### Mathematical definitions

    w = ¼J(u)ᵀv

    v = J(u)w/ρ.

### Preconditions

`ks_to_cartesian_velocity` requires:

    ρ > 0.

It shall not silently evaluate at exact collision.

### Unit tests

- Cartesian velocity round trip;
- KS velocity round trip for horizontal `w`;
- nonhorizontal `w` maps back to its horizontal projection;
- bilinear constraint is satisfied after Cartesian-to-KS lifting;
- gauge-transform invariance of reconstructed physical velocity;
- position and velocity state round trip;
- near-collision tests at representable nonzero separation;
- BigFloat reference comparisons.

### Acceptance gate

- velocity round trips meet precision-scaled tolerances;
- initialized states satisfy the bilinear constraint to roundoff;
- exact-collision reconstruction is explicitly rejected;
- all previous tests remain green.

### Suggested commit

    Implement KS velocity transformations

---

## 9. Stage KS-5: Transformation diagnostics

### Objective

Provide a reusable diagnostics layer before dynamics are introduced.

### Functions

```julia
ks_radial_identity_residual(u)
ks_jacobian_identity_residual(u)
ks_scaled_constraint_residual(u, w)
ks_position_roundtrip_residual(q)
ks_velocity_roundtrip_residual(q, v)
ks_energy_consistency_residual(u, w, h, mu)
```

### Requirements

Residuals shall:

- be generic in scalar type;
- use scale-aware denominators;
- avoid division by zero;
- distinguish absolute and normalized quantities;
- remain finite near collision whenever the mathematical diagnostic permits.

### Tests

- exact fixtures produce zero or roundoff-level residuals;
- deliberately corrupted states produce nonzero residuals;
- scaling tests verify consistency across many magnitudes;
- no diagnostic mutates its input.

### Acceptance gate

Diagnostics are suitable for reuse in standalone benchmarks and future
switching validation.

### Suggested commit

    Add KS transformation diagnostics

---

## 10. Stage KS-6: Unperturbed KS state and dynamics

### Objective

Implement the isolated unperturbed binary in fictitious time.

### State

The first-order relative state is:

    yKS = (u, w, h, t).

### Equations

    u′ = w
    w′ = -½hu
    h′ = 0
    t′ = ρ
    ρ  = uᵀu.

### Deliverables

- internal KS state representation;
- packing and unpacking helpers;
- unperturbed RHS;
- direct initialization from Cartesian relative state;
- reconstruction to Cartesian relative state;
- physical final-time termination.

### Tests

#### Unit tests

- RHS agrees with hand-computed fixtures;
- scalar type is preserved;
- `h` remains constant;
- `t′ = ρ`;
- state initialization satisfies the energy identity.

#### Scientific tests

- circular Kepler orbit;
- eccentric ellipse;
- highly eccentric ellipse;
- hyperbolic orbit;
- inclined orbit;
- radial collision continuation.

### Collision continuation requirements

- `u`, `w`, `h`, and `t` remain finite;
- integration passes through `u = 0`;
- Cartesian position is reconstructed on both sides;
- Cartesian velocity is not sampled exactly at collision;
- post-collision continuation agrees with the analytic solution.

### Acceptance gate

The unperturbed KS solver matches analytic Kepler propagation and passes
collision-continuation tests before any perturbing force is added.

### Suggested commits

    Add unperturbed KS dynamics

    Validate unperturbed KS Kepler motion

Use two commits if the benchmark work is substantial.

---

## 11. Stage KS-7: Levi–Civita cross-validation

### Objective

Cross-check the spatial KS implementation against the existing planar
Levi–Civita subsystem.

### Benchmark design

Construct compatible planar states and propagate them using:

- existing Levi–Civita regularization;
- KS regularization;
- high-accuracy Cartesian reference where appropriate.

Compare after Cartesian reconstruction:

    position
    velocity
    physical time
    energy
    transition quantities.

### Requirements

- no assumption that internal regularized coordinates match;
- comparison occurs only in physical Cartesian variables;
- use BigFloat reference runs for representative difficult cases;
- include near-collision and noncollision cases.

### Acceptance gate

KS and Levi–Civita produce physically equivalent trajectories within the
derived validation tolerances.

### Suggested commit

    Cross-validate KS and Levi-Civita regularization

---

## 12. Stage KS-8: General perturbing acceleration

### Objective

Implement the regularized relative equations for a supplied smooth
perturbation.

### Equations

    u′ = w

    w′ = -½hu + ¼ρJ(u)ᵀf

    h′ = -(J(u)w)·f

    t′ = ρ.

### Deliverables

- perturbation callback or internal force interface;
- propagated binding-energy parameter;
- regular energy-consistency residual;
- tests with known smooth forcing.

### Test perturbations

Use analytically controllable examples before introducing full three-body
coupling, such as:

- zero force;
- constant acceleration;
- weak linear restoring acceleration;
- time-dependent smooth forcing if useful.

### Tests

- zero-force path reproduces Stage KS-6;
- energy evolution agrees with numerical work;
- regularized forcing remains finite as `u → 0`;
- BigFloat comparisons confirm convergence;
- gauge constraint drift is measured but not projected.

### Acceptance gate

Perturbed relative dynamics pass controlled-force benchmarks and preserve the
regularized identities.

### Suggested commit

    Implement perturbed KS relative dynamics

---

## 13. Stage KS-9: Pair-centred three-body coupling

### Objective

Couple the KS relative subsystem to the selected pair centre of mass and the
third body.

### State additions

Include:

    pair centre position R
    pair centre velocity V
    third-body position r_k
    third-body velocity v_k.

### Fictitious-time equations

    R′   = ρV
    V′   = ρaR
    r_k′ = ρv_k
    v_k′ = ρa_k.

### Deliverables

- selected-pair parameter container;
- reconstruction of individual selected bodies;
- third-body differential perturbation;
- complete regularized RHS;
- full Cartesian reconstruction.

### Unit tests

- body reconstruction from pair-centred variables;
- pair-centre acceleration;
- differential perturbation sign and ordering;
- conservation-law fixtures;
- pair permutations `(1,2)`, `(1,3)`, and `(2,3)`.

### Scientific validation

- hierarchical triple;
- close encounter with finite third-body perturbation;
- BigFloat reference comparison;
- long-duration conservation diagnostics;
- nonselected-pair distance monitoring.

### Acceptance gate

The complete regularized three-body segment is scientifically validated before
it is connected to automatic switching.

### Suggested commits

    Couple KS dynamics to pair-centred coordinates

    Validate KS hierarchical triple dynamics

---

## 14. Stage KS-10: Explicit KS segment

### Objective

Provide a standalone segment abstraction compatible with the existing manual
regularization architecture.

### Deliverables

- segment constructor;
- physical start and end times;
- retained ODE solution;
- dense physical-time evaluation;
- Cartesian reconstruction;
- segment diagnostics;
- plotting compatibility where practical.

### Event requirements

- terminate at requested physical time;
- handle monotonic `t(s)`;
- reject target times before the segment start;
- detect solver failure;
- detect nonselected close encounters;
- preserve the retained solution for switching evaluation.

### Tests

- segment reaches requested physical final time;
- dense evaluation agrees with saved states;
- reconstruction is continuous;
- repeated evaluation is deterministic;
- solver retcodes are handled explicitly;
- diagnostics use the retained solution.

### Acceptance gate

Standalone explicit KS segments behave consistently with existing Cartesian
and Levi–Civita segment abstractions.

### Suggested commit

    Add explicit KS regularized segments

---

## 15. Stage KS-11: Automatic switching integration

### Objective

Integrate validated KS segments with the experimental automatic-switching
controller.

### Entry path

    Cartesian state
        → pair-centred state
        → deterministic KS lift
        → horizontal velocity lift
        → KS segment.

### Exit path

    KS state
        → Cartesian relative state
        → complete Cartesian state
        → Cartesian segment.

### Gauge continuity

If prior KS history for the same pair exists, align the new representative to
the prior gauge state before propagation.

### Switching conditions

Reuse the existing switching design where mathematically applicable:

- entry threshold;
- exit threshold;
- hysteresis;
- radial-rate criteria;
- target location;
- retained-solution evaluation;
- pair-selection policy.

### Additional failure conditions

- exact-collision entry requested from Cartesian coordinates;
- nonselected pair reaches an unsafe threshold;
- gauge or energy residual exceeds acceptance limit;
- physical time ceases to advance as expected outside an isolated collision;
- reconstruction failure.

### Tests

- Cartesian entry event;
- KS exit event;
- one complete entry/exit cycle;
- repeated cycles;
- all selected pair permutations;
- gauge-continuous re-entry;
- near-threshold chattering resistance;
- BigFloat entry decisions;
- comparison with manual composition;
- transition conservation diagnostics.

### Acceptance gate

Automatic switching passes all unit tests and scientific validation benchmarks
without weakening existing acceptance criteria.

### Suggested commits

    Integrate KS segments with automatic switching

    Validate automatic KS switching

---

## 16. Stage KS-12: Scientific validation suite integration

### Objective

Promote the validated KS benchmarks into the repository's scientific
regression suite.

### Proposed validation files

    examples/validation/ks_kepler_validation.jl
    examples/validation/ks_collision_continuation.jl
    examples/validation/ks_levi_civita_comparison.jl
    examples/validation/ks_hierarchical_triple.jl
    examples/validation/ks_switching_comparison.jl

### Requirements

Each benchmark shall:

- use the shared acceptance-criteria framework;
- print all required diagnostics;
- terminate with failure when a criterion is exceeded;
- use reproducible initial conditions;
- document the scientific purpose;
- avoid depending on undocumented internal state.

### Suite integration

Add the benchmarks to:

    examples/validation/run_validation_suite.jl

only after each benchmark passes independently.

### Acceptance gate

The complete validation suite and package test suite pass in one clean run.

### Suggested commit

    Add KS scientific validation benchmarks

---

## 17. Stage KS-13: Documentation and API review

### Objective

Document the validated capability without prematurely stabilizing it.

### Documentation updates

Review and update:

    README.md
    API_STABILITY.md
    CHANGELOG.md
    KS_REGULARIZATION_DESIGN.md
    KS_FORMULATION_REVIEW.md

### Requirements

- conform to `DOCUMENTATION_STYLE_GUIDE.md`;
- distinguish experimental and stable APIs;
- describe limitations honestly;
- avoid claiming full collision regularization beyond the selected pair;
- include reproducible examples only after the implementation is validated.

### API decision

Choose one of:

1. retain KS as internal research infrastructure; or
2. expose a clearly experimental API.

A stable public API should not be introduced during the first implementation
cycle.

### Acceptance gate

Documentation matches actual validated behavior and contains no aspirational
claims presented as implemented features.

### Suggested commit

    Document experimental KS regularization

---

## 18. Required test organization

Suggested test structure:

    test/
        ks/
            runtests.jl
            transforms.jl
            gauge.jl
            inverse_lift.jl
            velocity.jl
            diagnostics.jl
            unperturbed_dynamics.jl
            perturbed_dynamics.jl
            pair_coupling.jl
            segments.jl
            switching.jl

If the repository convention favors fewer files, these may be consolidated,
but the logical test groups shall remain identifiable.

---

## 19. Precision strategy

### 19.1 Float32

Used to detect:

- accidental Float64 promotion;
- poorly scaled tolerances;
- unstable chart behavior;
- type-instability.

### 19.2 Float64

Primary production and regression precision.

### 19.3 BigFloat

Used for:

- algebraic reference cases;
- near-collision validation;
- difficult inverse lifts;
- reference trajectory generation;
- tolerance calibration.

BigFloat tests should be selective enough to keep the routine test suite
practical. Long reference benchmarks may remain in the validation suite rather
than `Pkg.test()`.

---

## 20. Performance policy

Correctness has priority over optimization.

After a stage is scientifically accepted, inspect:

- allocations;
- type stability;
- static-array inference;
- unnecessary matrix construction;
- repeated reconstruction work.

Optimization shall not:

- alter the frozen convention;
- replace analytic formulas with approximations;
- weaken tests;
- obscure the correspondence between code and specification.

Performance work should be committed separately from functional
implementation.

---

## 21. Error-handling policy

The implementation shall fail explicitly for:

- malformed state dimensions;
- nonfinite inputs;
- nonpositive masses;
- invalid selected pairs;
- exact-collision Cartesian entry;
- Cartesian velocity reconstruction at exact collision;
- nonmonotonic requested physical time;
- solver failure;
- violated segment preconditions.

Errors shall identify:

- the failed operation;
- the selected pair;
- the relevant physical or regularized quantity;
- the value that violated the precondition when practical.

---

## 22. Completion criteria

The KS implementation phase is complete only when:

1. all transformation identities pass;
2. deterministic inverse lifting is robust across both charts;
3. velocity round trips and the gauge constraint pass;
4. unperturbed Kepler motion is validated;
5. collision continuation is validated;
6. Levi–Civita cross-validation passes;
7. perturbed relative dynamics pass;
8. pair-centred three-body coupling passes;
9. explicit KS segments pass;
10. automatic switching passes;
11. BigFloat reference comparisons pass;
12. scientific validation benchmarks are integrated;
13. package tests, Aqua, and validation suite all pass;
14. documentation accurately describes the implemented capability;
15. the working tree is clean.

---

## 23. Recommended immediate next step

Begin with Stage KS-0 and Stage KS-1 only.

The first coding milestone should contain:

- KS module scaffolding;
- forward map;
- radius;
- analytic Jacobian;
- gauge direction;
- bilinear residual;
- exact and randomized algebraic tests.

Do not implement inverse lifting or dynamics in the same milestone.

This preserves a clear review boundary around the most fundamental algebra.

---

## 24. Proposed initial commit sequence

A suitable early sequence is:

    Add KS regularization module scaffolding
    Implement KS forward transformations
    Implement KS gauge transformations
    Implement deterministic Cartesian to KS lift
    Implement KS velocity transformations
    Add KS transformation diagnostics
    Add unperturbed KS dynamics
    Validate unperturbed KS Kepler motion

Later commit names should reflect the actual completed responsibility rather
than the planned stage number.

---

## 25. Change-control rule

If implementation reveals that a frozen mathematical definition must change:

1. stop implementation;
2. document the inconsistency;
3. verify the correction independently;
4. update `KS_REGULARIZATION_DESIGN.md`;
5. update this implementation plan if sequencing changes;
6. update all affected tests;
7. commit the design correction separately from resumed implementation.

No silent divergence between code and design is permitted.

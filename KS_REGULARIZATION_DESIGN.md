# KS_REGULARIZATION_DESIGN

## ThreeBody3D Spatial Binary Regularization Specification

**Status:** Proposed normative design  
**Target branch:** `v0.4-development`  
**Implementation authorization:** Transformation and dynamics implementation may begin only after the algebraic test fixtures defined here are accepted.  
**Scope:** One selected Newtonian binary pair in a spatial three-body system.

---

## 1. Purpose

This document specifies the mathematical and software design of the
Kustaanheimo–Stiefel (KS) regularization subsystem for ThreeBody3D.

The design extends the existing planar Levi–Civita work to arbitrary
three-dimensional close encounters. It fixes one KS convention and derives,
from that convention alone:

- the forward Cartesian map;
- the analytic Jacobian;
- the gauge direction and bilinear constraint;
- deterministic Cartesian-to-KS lifting;
- position and velocity reconstruction;
- the Sundman time transformation;
- the perturbed regularized equations;
- the coupled pair-centred three-body equations;
- diagnostics, testing, and validation requirements.

This document is normative. The implementation shall be regarded as incorrect
if it differs from these definitions without a corresponding revision of this
document and revalidation of the KS subsystem.

---

## 2. Source verification

The adopted convention was checked against the classical KS1 formulation
introduced by Kustaanheimo and Stiefel and reproduced in later primary
research on the defining-vector formulation.

The classical component map is

    x = u₁² - u₂² - u₃² + u₄²
    y = 2(u₁u₂ - u₃u₄)
    z = 2(u₁u₃ + u₂u₄)
    r = u₁² + u₂² + u₃² + u₄²

and the associated Kustaanheimo–Stiefel matrix is

             ┌  u₁  -u₂  -u₃   u₄ ┐
             │  u₂   u₁  -u₄  -u₃ │
    L(u)  =  │  u₃   u₄   u₁   u₂ │
             └  u₄  -u₃   u₂  -u₁ ┘

with

    (x, y, z, 0)ᵀ = L(u)u.

The original KS1 convention assigns the preferred direction to the first
Cartesian axis. Modern defining-vector treatments identify this as the choice

    c = e₁.

The design deliberately retains this historical KS1 convention because it is
widely used in celestial mechanics, has a simple fixed matrix representation,
and agrees directly with the equations reproduced in the reviewed literature.

The regularized perturbed Kepler equations were checked against the
quaternion derivation in Waldvogel's formulation. With fictitious time `s`
defined by

    dt/ds = r,

the unperturbed equation is a four-dimensional oscillator and the perturbing
acceleration enters through a regular forcing term.

### 2.1 Source hierarchy

The mathematical source hierarchy for this design is:

1. Kustaanheimo and Stiefel (1965), original spinor regularization paper.
2. Stiefel and Scheifele (1971), classical celestial-mechanics treatment.
3. Breiter and Langner (2017), primary research clarifying the defining vector,
   fiber, inverse representatives, and canonical extension.
4. Waldvogel (2007), explicit quaternion derivation of the perturbed spatial
   equations.

No formula in this document is assembled by mixing incompatible conventions.
All matrix equations below use the fixed KS1 ordering stated in Section 5.

---

## 3. Scope

### 3.1 In scope

The first KS implementation shall support:

- one explicitly selected binary pair;
- arbitrary spatial relative motion;
- Newtonian perturbation by the third body;
- `Float32`, `Float64`, and `BigFloat`;
- Cartesian-to-KS initialization;
- KS-to-Cartesian reconstruction;
- physical-time reconstruction;
- explicit regularized segments;
- later integration with the existing automatic-switching controller;
- quantitative gauge and reconstruction diagnostics.

### 3.2 Out of scope

The first implementation shall not attempt:

- simultaneous regularization of more than one pair;
- triple-collision regularization;
- chain regularization;
- arbitrary N-body regularization;
- post-Newtonian forces;
- collision, merger, rebound, or finite-size physics;
- constraint projection;
- a public quaternion API;
- a configurable KS convention.

---

## 4. Design requirements

### 4.1 Scientific requirements

The subsystem shall:

- remove the selected binary's explicit Newtonian collision singularity;
- preserve the corresponding physical trajectory;
- include the differential perturbation from the third body;
- reconstruct position, velocity, and physical time;
- expose every nonphysical constraint as a measurable diagnostic.

### 4.2 Numerical requirements

The subsystem shall:

- use analytic transformations and derivatives;
- avoid finite-difference Jacobians in production;
- remain generic in scalar type;
- introduce no force softening;
- avoid hidden constraint correction;
- preserve continuity across switching boundaries as accurately as practical.

### 4.3 Software requirements

The subsystem shall:

- use fixed-size `StaticArrays`;
- allocate no heap memory in elementary transformations;
- isolate KS mathematics from the ODE solver;
- reuse the existing pair-centred decomposition;
- remain internal and experimental during the v0.4 research phase;
- not destabilize the existing `simulate` API.

---

## 5. Fixed notation and convention

### 5.1 Physical pair variables

For the selected pair `(i, j)` define

    q = rᵢ - rⱼ
    v = vᵢ - vⱼ
    ρ = ‖q‖
    μ = G(mᵢ + mⱼ)

where:

- `q ∈ R³` is the physical relative position;
- `v ∈ R³` is the physical relative velocity;
- `ρ` is the selected-pair separation;
- `μ` is the pair gravitational parameter.

The symbol `ρ` is used for separation in this document to avoid overloading
the vector symbol `r`.

### 5.2 KS variables

The regularized coordinate and fictitious-time derivative are

    u = (u₁, u₂, u₃, u₄) ∈ R⁴
    w = du/ds ∈ R⁴

where `s` is fictitious time.

### 5.3 Coordinate ordering

Cartesian ordering is fixed as

    q = (x, y, z).

KS ordering is fixed as

    u = (u₁, u₂, u₃, u₄).

No permutation or sign reversal is permitted within the implementation.

### 5.4 Defining vector

The defining vector is fixed as

    c = e₁ = (1, 0, 0).

This is the classical celestial-mechanics KS1 convention.

### 5.5 Time convention

The Sundman transformation is fixed as

    dt/ds = ρ.

A prime denotes differentiation with respect to fictitious time:

    u′ = du/ds
    t′ = dt/ds.

A dot denotes differentiation with respect to physical time:

    q̇ = dq/dt
    v̇ = dv/dt.

---

## 6. Forward KS transformation

### 6.1 Component form

The physical relative position is reconstructed from `u` by

    x = u₁² - u₂² - u₃² + u₄²
    y = 2(u₁u₂ - u₃u₄)
    z = 2(u₁u₃ + u₂u₄).

Define

    K(u) = (x, y, z).

### 6.2 Matrix form

Define

             ┌  u₁  -u₂  -u₃   u₄ ┐
             │  u₂   u₁  -u₄  -u₃ │
    L(u)  =  │  u₃   u₄   u₁   u₂ │
             └  u₄  -u₃   u₂  -u₁ ┘.

Then

    (x, y, z, 0)ᵀ = L(u)u.

Let `A(u)` denote the first three rows of `L(u)`:

             ┌ u₁  -u₂  -u₃   u₄ ┐
    A(u)  =  │ u₂   u₁  -u₄  -u₃ │.
             └ u₃   u₄   u₁   u₂ ┘

Then

    q = A(u)u.

Because `A(u)` is linear in `u`, this expression is quadratic overall.

### 6.3 Radial identity

The adopted map satisfies exactly

    ρ = ‖q‖ = uᵀu = ‖u‖².

Equivalently,

    x² + y² + z² = (u₁² + u₂² + u₃² + u₄²)².

This identity is part of the mathematical contract and shall be tested
symbolically and numerically.

### 6.4 Collision

The selected binary collision

    ρ = 0

corresponds uniquely to

    u = 0.

The coordinate map itself is polynomial and nonsingular at `u = 0`. The
inverse lift is not defined uniquely at collision because every gauge
representative collapses to the origin, but no inverse is required while
propagating through collision in KS variables.

---

## 7. Analytic Jacobian

### 7.1 Definition

The Jacobian of the forward map is

    J(u) = ∂K/∂u.

For the fixed convention,

             ┌ 2u₁  -2u₂  -2u₃   2u₄ ┐
    J(u)  =  │ 2u₂   2u₁  -2u₄  -2u₃ │.
             └ 2u₃   2u₄   2u₁   2u₂ ┘

Therefore

    J(u) = 2A(u).

### 7.2 Differential map

For any increment `δu`,

    δq = J(u)δu.

Along a fictitious-time trajectory,

    q′ = J(u)u′
       = J(u)w.

### 7.3 Orthogonality identity

The rows of the Jacobian are mutually orthogonal and have equal norm:

    J(u)J(u)ᵀ = 4ρ I₃.

Equivalently,

    A(u)A(u)ᵀ = ρ I₃.

This identity supplies an analytic right inverse away from collision.

### 7.4 Rank

For `u ≠ 0`,

    rank J(u) = 3.

The missing rank corresponds exactly to the one-dimensional KS gauge fiber.

---

## 8. Gauge fiber and bilinear constraint

### 8.1 Gauge generator

Define the gauge-direction vector

    g(u) = (u₄, -u₃, u₂, -u₁).

The Jacobian annihilates this vector:

    J(u)g(u) = 0.

Therefore changes parallel to `g(u)` do not change the physical Cartesian
position to first order.

### 8.2 Finite gauge action

All representatives on the same fiber are generated by

    ũ = G(φ)u,

where

             ┌  cosφ    0       0     sinφ ┐
             │   0     cosφ  -sinφ    0    │
    G(φ)  =  │   0     sinφ   cosφ    0    │.
             └ -sinφ    0       0     cosφ ┘

This action satisfies

    K(G(φ)u) = K(u)
    ‖G(φ)u‖ = ‖u‖.

The sign ambiguity `u ↦ -u` is the special case `φ = π`.

### 8.3 Bilinear constraint

The horizontal KS velocity condition is

    g(u)ᵀw = 0.

In components,

    u₄w₁ - u₃w₂ + u₂w₃ - u₁w₄ = 0.

This is the classical KS1 bilinear relation.

Define the residual

    C(u, w) = g(u)ᵀw.

The implementation shall report `C` and a scaled residual such as

    Cscaled = |C| / max(‖u‖‖w‖, scale_floor).

### 8.4 Constraint policy

The first implementation shall:

- initialize states satisfying the constraint to roundoff;
- propagate without projection;
- measure constraint drift;
- terminate validation benchmarks if drift exceeds stated acceptance criteria.

Automatic projection is explicitly deferred until natural numerical behavior
has been measured.

---

## 9. Deterministic Cartesian-to-KS lift

The inverse of `K` is a one-dimensional fiber, not a single point. ThreeBody3D
therefore defines a deterministic representative.

### 9.1 Preconditions

For a noncollision Cartesian position,

    ρ = ‖q‖ > 0.

At exact collision, the only coordinate representative is `u = 0`, but a
Cartesian velocity does not uniquely determine a crossing direction without
additional regularized-state history. Switching into KS exactly at collision
is therefore forbidden.

### 9.2 Positive-axis chart

When `ρ + x` is numerically well resolved, use

    d₊ = √(2(ρ + x))

and define

    u₁ = 0
    u₂ = -z/d₊
    u₃ =  y/d₊
    u₄ = -d₊/2.

This representative reconstructs `(x, y, z)` exactly in exact arithmetic.

### 9.3 Negative-axis chart

Near the negative `x` axis, the positive-axis chart suffers cancellation.
Use instead

    d₋ = √(2(ρ - x))

and define

    u₁ =  y/d₋
    u₂ =  d₋/2
    u₃ =  0
    u₄ =  z/d₋.

This representative also reconstructs `(x, y, z)` exactly.

At the exact negative axis,

    q = (-ρ, 0, 0),

the second chart gives

    u = (0, √ρ, 0, 0).

### 9.4 Chart selection

Use the chart with the larger denominator:

    if ρ + x ≥ ρ - x
        use the positive-axis chart
    else
        use the negative-axis chart
    end

which is equivalent to selecting according to the sign of `x`.

This avoids dividing by the smaller of `√(ρ + x)` and `√(ρ - x)`.

A small tolerance may be used only to protect against negative radicands caused
by roundoff:

    radicand = max(radicand, zero(T)).

The implementation shall not otherwise alter the Cartesian state.

### 9.5 Sign selection

For an isolated initial lift with no previous KS state, retain the signs given
above.

When a previous compatible KS coordinate `uref` is available, select the fiber
representative continuously rather than applying only a sign test.

Given a candidate `u`, define

    a = uᵀuref
    b = g(u)ᵀuref.

The gauge angle that maximizes alignment with `uref` is

    φ = atan(b, a).

Then use

    ualigned = G(φ)u.

This minimizes Euclidean distance to the reference representative over the
complete gauge fiber. Apply the same `G(φ)` to `w`.

This rule is appropriate for:

- repeated regularized segments;
- handoff from a prior KS state;
- dense reconstruction followed by reinitialization.

It is not needed for the first standalone Cartesian-to-KS lift.

---

## 10. Velocity transformation

### 10.1 KS-to-Cartesian velocity

From

    q′ = J(u)w
    t′ = ρ,

the physical relative velocity is

    v = dq/dt
      = J(u)w / ρ.

This formula is valid for `ρ > 0`.

### 10.2 Cartesian-to-KS velocity

Using

    J(u)J(u)ᵀ = 4ρI₃,

the horizontal inverse is

    w = ¼ J(u)ᵀv.

Indeed,

    J(u)w
      = ¼J(u)J(u)ᵀv
      = ρv.

This `w` satisfies the bilinear constraint automatically because

    J(u)g(u) = 0.

### 10.3 General velocity fiber

The most general `w` producing the same Cartesian velocity is

    wgeneral = ¼J(u)ᵀv + λg(u),

where `λ` is arbitrary.

ThreeBody3D fixes

    λ = 0

for initialization and handoff. This is the horizontal, minimum-norm lift.

### 10.4 Round-trip identities

For every noncollision horizontal state,

    cartesian_velocity(u, ks_velocity(u, v)) = v

and

    ks_velocity(u, cartesian_velocity(u, w)) = w

provided

    C(u, w) = 0.

For a nonhorizontal `w`, the second round trip returns its horizontal
projection.

---

## 11. Sundman time transformation

The adopted fictitious time satisfies

    t′ = ρ = ‖u‖².

Consequences:

- physical time slows quadratically as `u → 0`;
- the selected binary collision is reached at a regular fictitious-time point;
- event termination must be based on the integrated physical-time state;
- all non-KS state derivatives must be multiplied by `ρ` when expressed in
  fictitious time.

The physical-time state is propagated explicitly:

    dt/ds = ρ.

Monotonicity requirement:

    ρ ≥ 0

and therefore `t(s)` is nondecreasing. Away from collision, it is strictly
increasing.

---

## 12. Pair relative dynamics

### 12.1 Physical equation

The selected relative coordinate obeys

    q̈ = -μq/ρ³ + f,

where `f` is the differential perturbing acceleration not included in the
selected pair's internal Kepler term.

For the Newtonian three-body problem,

    f = aᵢ,third - aⱼ,third.

### 12.2 Energy variable

Define the positive binding-energy parameter

    h = μ/ρ - ½‖v‖².

Thus `h` is the negative of the ordinary specific Kepler energy:

    E = ½‖v‖² - μ/ρ
    h = -E.

In KS variables,

    h = (μ - 2‖w‖²)/ρ.

For unperturbed motion, `h` is constant.

### 12.3 Regularized coordinate equation

The perturbed KS equation in the fixed matrix convention is

    u″ = -½hu + ¼ρJ(u)ᵀf.

Since `J = 2A`, the equivalent form is

    u″ = -½hu + ½ρA(u)ᵀf.

The forcing is regular at the selected binary collision provided `f` remains
finite there.

For the unperturbed pair,

    f = 0,

and therefore

    2u″ + hu = 0.

This is a four-dimensional isotropic harmonic oscillator for `h > 0`, a
linear system for `h = 0`, and a hyperbolic oscillator for `h < 0`.

### 12.4 Energy evolution

Because

    dE/dt = v·f,

the binding-energy parameter satisfies

    dh/dt = -v·f.

In fictitious time,

    h′ = -ρv·f
       = -q′·f
       = -(J(u)w)·f.

Either of the following state designs is mathematically valid:

1. propagate `h` as an independent state using the equation above; or
2. recompute `h = (μ - 2‖w‖²)/ρ`.

### 12.5 Adopted energy-state policy

The first implementation shall propagate `h` as an explicit state variable.

Reasons:

- it avoids division by `ρ` at collision;
- it preserves the regular oscillator equation through collision;
- it provides an independent consistency diagnostic;
- it follows the classical perturbed KS formulation.

Define the energy consistency residual away from collision:

    Rh = h - (μ - 2‖w‖²)/ρ.

Near collision, use the nonsingular multiplied form

    Rh_regular = ρh - μ + 2‖w‖².

The regular residual is the primary diagnostic.

---

## 13. Full first-order KS subsystem

Let the regularized relative state be

    yKS = (u, w, h, t).

The first-order equations are

    u′ = w

    w′ = -½hu + ¼ρJ(u)ᵀf

    h′ = -(J(u)w)·f

    t′ = ρ

    ρ = uᵀu

    q = K(u)

    v = J(u)w/ρ          for ρ > 0.

The coordinate and energy equations remain finite at `u = 0` when `f` is
finite. Cartesian velocity reconstruction is not evaluated exactly at
collision because it divides by `ρ`; the regularized state itself remains the
authoritative state there.

---

## 14. Coupled pair-centred three-body equations

### 14.1 Pair-centred variables

For selected pair `(i, j)` and remaining body `k`, define

    M = mᵢ + mⱼ

    R = (mᵢrᵢ + mⱼrⱼ)/M
    V = (mᵢvᵢ + mⱼvⱼ)/M

    q = rᵢ - rⱼ
    v = vᵢ - vⱼ.

Reconstruct the selected bodies as

    rᵢ = R + (mⱼ/M)q
    rⱼ = R - (mᵢ/M)q

    vᵢ = V + (mⱼ/M)v
    vⱼ = V - (mᵢ/M)v.

### 14.2 Third-body accelerations

Let

    dᵢk = rₖ - rᵢ
    dⱼk = rₖ - rⱼ.

Then

    aᵢ,third = Gmₖ dᵢk / ‖dᵢk‖³
    aⱼ,third = Gmₖ dⱼk / ‖dⱼk‖³.

The relative perturbation is

    f = aᵢ,third - aⱼ,third.

The selected-pair centre acceleration is

    aR = (mᵢaᵢ,third + mⱼaⱼ,third)/M.

The third-body acceleration is

    aₖ =
        Gmᵢ(rᵢ - rₖ)/‖rᵢ - rₖ‖³
      + Gmⱼ(rⱼ - rₖ)/‖rⱼ - rₖ‖³.

### 14.3 Fictitious-time equations for nonsingular variables

All physical-time derivatives are multiplied by `ρ`:

    R′  = ρV
    V′  = ρaR

    rₖ′ = ρvₖ
    vₖ′ = ρaₖ.

Together with Section 13, this forms the complete selected-pair KS system.

### 14.4 Remaining singularities

This transformation regularizes only the selected separation `‖rᵢ-rⱼ‖`.

It does not regularize:

    ‖rᵢ-rₖ‖ → 0
    ‖rⱼ-rₖ‖ → 0.

The switching controller must reject or terminate a KS segment if a different
pair becomes singular before the selected segment exits.

---

## 15. Reconstruction

### 15.1 Relative reconstruction

For `ρ > 0`,

    q = K(u)
    v = J(u)w/ρ.

### 15.2 Full Cartesian reconstruction

Using the pair-centred relations,

    rᵢ = R + (mⱼ/M)q
    rⱼ = R - (mᵢ/M)q

    vᵢ = V + (mⱼ/M)v
    vⱼ = V - (mᵢ/M)v.

The third body's state is already explicit.

### 15.3 Collision state

At exact binary collision:

    q = 0.

The separate Cartesian velocities of the selected point masses are singular
for a true Newtonian collision orbit and shall not be reconstructed at the
collision instant. The regularized state shall continue through collision,
and Cartesian states may be reconstructed again after `ρ > 0`.

A validation output grid shall not demand a Cartesian velocity sample exactly
at collision unless a mathematically defined limiting convention is added in a
future revision.

---

## 16. Software architecture

### 16.1 Proposed files

    src/
        Regularization/
            KS.jl
            KSTransforms.jl
            KSState.jl
            KSDynamics.jl
            KSDiagnostics.jl
            KSReconstruction.jl

The final names may be consolidated if the resulting files remain small and
cohesive.

### 16.2 Core internal operations

Suggested internal functions:

```julia
ks_position(u)
ks_radius(u)
ks_jacobian(u)
ks_gauge_direction(u)
ks_constraint_residual(u, w)

cartesian_to_ks_position(q; reference=nothing)
cartesian_to_ks_state(q, v; reference=nothing)
ks_to_cartesian_position(u)
ks_to_cartesian_velocity(u, w)

align_ks_gauge(u, w, reference_u)

initialize_ks_state(system, physical_state, pair)
ks_rhs!(dy, y, parameters, s)
reconstruct_ks_state(state, parameters)
ks_diagnostics(state, parameters)
```

### 16.3 Types

Elementary operations shall use:

```julia
SVector{3,T}
SVector{4,T}
SMatrix{3,4,T,12}
```

No transformation shall hard-code `Float64`.

A possible internal state container is:

```julia
struct KSRelativeState{T}
    u::SVector{4,T}
    w::SVector{4,T}
    h::T
    t::T
end
```

The actual ODE state may remain a flat static or ordinary vector if that is
more compatible with SciML.

### 16.4 API status

No new stable public API is authorized by this design.

During research development, KS functions should remain internal or clearly
marked experimental. Public exposure shall occur only after standalone and
switching validation is complete.

---

## 17. Diagnostics

Every KS segment shall report at least:

### 17.1 Algebraic diagnostics

    radial identity residual
        |‖K(u)‖ - uᵀu|

    Jacobian orthogonality residual
        ‖J(u)J(u)ᵀ - 4ρI₃‖

    gauge constraint residual
        |C(u, w)|

    energy consistency residual
        |ρh - μ + 2‖w‖²|

### 17.2 Reconstruction diagnostics

    position reconstruction residual
    velocity reconstruction residual
    Cartesian → KS → Cartesian round-trip residual
    KS → Cartesian → KS fiber-aligned residual

### 17.3 Segment diagnostics

    physical-time monotonicity
    transition state residual
    transition energy jump
    transition momentum jump
    transition angular-momentum jump
    minimum selected-pair separation
    minimum nonselected-pair separation

### 17.4 Global diagnostics

Existing package diagnostics shall continue to report:

    total energy drift
    total momentum drift
    total angular-momentum drift
    centre-of-mass residual
    centre-of-mass velocity drift.

---

## 18. Algebraic testing strategy

The transformation layer shall be completed and tested before any KS ODE is
implemented.

### 18.1 Exact fixtures

Include hand-computable states such as:

    u = (1, 0, 0, 0)       → q = (1, 0, 0)
    u = (0, 1, 0, 0)       → q = (-1, 0, 0)
    u = (0, 0, 1, 0)       → q = (-1, 0, 0)
    u = (0, 0, 0, 1)       → q = (1, 0, 0)

and mixed-component fixtures exercising every sign.

### 18.2 Symbolic identities

Verify independently, preferably with generated fixtures committed as ordinary
tests:

    ‖K(u)‖² = (uᵀu)²
    J(u)J(u)ᵀ = 4ρI₃
    J(u)g(u) = 0
    K(G(φ)u) = K(u).

The package test suite need not depend on a symbolic algebra package.

### 18.3 Randomized tests

For random `u`, `v`, and `φ`:

- verify the radial identity;
- verify gauge invariance;
- verify Jacobian finite differences;
- verify velocity round trips;
- verify lift round trips;
- repeat with `Float32`, `Float64`, and `BigFloat`.

### 18.4 Chart-boundary tests

Test positions:

- on both Cartesian `x` semiaxes;
- near both semiaxes;
- with `x ≈ 0`;
- with subnormal transverse components where supported;
- over a wide dynamic range.

The two lift charts must agree physically even when their gauge
representatives differ.

---

## 19. Dynamical validation strategy

### 19.1 Isolated Kepler motion

Validate:

- circular orbit;
- moderate-eccentricity ellipse;
- extreme-eccentricity ellipse;
- parabolic orbit;
- hyperbolic orbit;
- radial collision and re-emergence;
- inclined versions of planar fixtures.

Compare with analytic Kepler propagation where available.

### 19.2 Levi–Civita reduction

For motion confined to a compatible Levi–Civita plane, compare KS and existing
Levi–Civita trajectories after Cartesian reconstruction.

This is a particularly important cross-validation because the two
regularizations should describe the same physical motion while using different
internal dimensions.

### 19.3 Perturbed binary

Use a hierarchical triple in which the selected inner pair undergoes a close
encounter while the third-body perturbation remains finite.

Compare:

- KS result;
- high-accuracy Cartesian result before conditioning fails;
- `BigFloat` reference result;
- existing manual-switching result where applicable.

### 19.4 Collision continuation

Use a radial binary collision fixture for which the KS oscillator passes
smoothly through `u = 0`.

Required behavior:

- regularized integration remains finite;
- physical time is continuous;
- position passes through collision;
- post-collision trajectory matches the analytic continuation;
- no Cartesian velocity is requested exactly at collision.

### 19.5 Switching validation

After standalone KS validation:

- Cartesian → KS entry;
- KS propagation;
- KS → Cartesian exit;
- repeated entry and exit;
- gauge-continuous re-entry;
- comparison with retained-solution switching evaluation;
- transition residual acceptance criteria.

---

## 20. Initial acceptance criteria

Final tolerances shall be calibrated from precision-scaled experiments rather
than copied blindly. Initial `Float64` targets are:

### 20.1 Elementary transforms

    radial identity residual           ≤ 100 eps(T) × scale
    Jacobian identity residual         ≤ 500 eps(T) × scale
    position round-trip residual       ≤ 500 eps(T) × scale
    velocity round-trip residual       ≤ 1000 eps(T) × scale
    scaled gauge residual              ≤ 1000 eps(T)

### 20.2 Segment handoff

    normalized position discontinuity  ≤ 1e-12
    normalized velocity discontinuity  ≤ 1e-11
    normalized energy jump             ≤ 1e-11

These are provisional research thresholds. The validation framework shall
derive precision-aware tolerances where practical.

### 20.3 Dynamical benchmarks

Each benchmark shall define explicit criteria for:

- completion status;
- physical final-time error;
- energy drift;
- momentum drift;
- angular-momentum drift;
- gauge drift;
- reconstruction residual;
- transition residual.

A benchmark that exceeds any required criterion shall fail.

---

## 21. Implementation plan

### Stage KS-1: Pure transformation layer

Implement only:

- `ks_position`;
- `ks_radius`;
- `ks_jacobian`;
- gauge action;
- gauge residual;
- deterministic inverse lift;
- velocity maps;
- algebraic tests.

No ODE code.

### Stage KS-2: Isolated unperturbed binary

Implement:

- `(u, w, h, t)` state;
- harmonic-oscillator equations;
- analytic Kepler validation;
- radial collision continuation.

### Stage KS-3: General perturbing acceleration

Implement:

- regular forcing term;
- propagated `h`;
- energy consistency diagnostics;
- externally supplied smooth perturbation tests.

### Stage KS-4: Pair-centred three-body coupling

Implement:

- third-body differential perturbation;
- pair-centre and third-body fictitious-time equations;
- hierarchical triple validation;
- BigFloat comparisons.

### Stage KS-5: Explicit KS segments

Implement:

- segment type;
- physical-time stopping;
- dense reconstruction;
- plotting and diagnostics.

### Stage KS-6: Automatic switching integration

Only after all preceding stages pass:

- KS entry and exit;
- pair selection policy;
- repeated switching;
- gauge-continuous re-entry;
- close-encounter comparison benchmark.

Each stage shall be one or more small, fully tested Git commits.

---

## 22. Design decisions frozen by this document

The following decisions are fixed for the first implementation:

- classical KS1 convention;
- Cartesian order `(x, y, z)`;
- KS order `(u₁, u₂, u₃, u₄)`;
- defining vector `c = e₁`;
- forward map in Section 6;
- Jacobian in Section 7;
- gauge generator in Section 8;
- bilinear constraint `g(u)ᵀw = 0`;
- two-chart deterministic inverse lift;
- horizontal velocity lift `w = ¼Jᵀv`;
- Sundman scaling `dt/ds = ρ`;
- propagated binding-energy parameter `h`;
- perturbed equation `u″ = -½hu + ¼ρJᵀf`;
- no automatic constraint projection;
- no public quaternion API.

Any change to these decisions requires:

1. revision of this document;
2. revision of algebraic fixtures;
3. rerunning every KS validation benchmark;
4. explicit justification in the changelog or design history.

---

## 23. Open implementation questions

The mathematical convention is fixed, but several engineering questions remain
for implementation stages:

- exact flat ODE-state ordering;
- whether elementary matrices are constructed explicitly or expanded into
  scalar expressions;
- event strategy for requested physical final time;
- dense physical-time interpolation;
- precision-scaled acceptance formulas;
- storage of prior gauge reference across Cartesian segments;
- policy when another pair becomes closer than the selected pair;
- plotting behavior at exact collision.

These questions do not alter the mathematical convention.

---

## 24. References

1. Kustaanheimo, P. and Stiefel, E. L. (1965).  
   *Perturbation theory of Kepler motion based on spinor regularization.*  
   Journal für die reine und angewandte Mathematik, 218, 204–219.  
   DOI: 10.1515/crll.1965.218.204.

2. Stiefel, E. L. and Scheifele, G. (1971).  
   *Linear and Regular Celestial Mechanics: Perturbed Two-Body Motion,
   Numerical Methods, Canonical Theory.*  
   Springer-Verlag.

3. Breiter, S. and Langner, K. (2017).  
   *Kustaanheimo–Stiefel transformation with an arbitrary defining vector.*  
   Celestial Mechanics and Dynamical Astronomy, 128, 323–342.  
   arXiv:1701.02147.

4. Waldvogel, J. (2007).  
   *Fundamentals of Regularization in Celestial Mechanics and Linear
   Perturbation Theories.*  
   In *Dynamics of Populations of Planetary Systems*, IAU Colloquium 197.

5. Zhao, L. (2013).  
   *Kustaanheimo–Stiefel Regularization and the Quadrupolar Conjugacy.*  
   arXiv:1308.2314.

---

## 25. Verification note

Before implementation, the equations in Sections 6–13 should be transcribed
into a small independent Julia or symbolic verification script and checked for:

    ‖K(u)‖² - (uᵀu)² = 0

    J(u)J(u)ᵀ - 4(uᵀu)I₃ = 0

    J(u)g(u) = 0

    K(G(φ)u) - K(u) = 0.

These identities were independently algebraically checked while preparing this
design. The committed package tests remain the authoritative verification.

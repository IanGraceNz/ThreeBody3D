# Comparative Review of Three-Dimensional Close-Encounter Regularization

## Recommendation for ThreeBody3D Stage 10A

**Status:** Historical design review; recommendation implemented and validated

**Target branch:** `v0.4-development`

**Resulting normative artifact:** `KS_REGULARIZATION_DESIGN.md`

**Implementation status:** The recommended fixed-convention Kustaanheimo–Stiefel transformation (KS) formulation
completed Stages KS-1 through KS-12 and remains internal research
infrastructure.

---

## 1. Purpose

ThreeBody3D already provides:

- Cartesian three-body integration;
- pair-centred coordinate transformations;
- planar Levi–Civita regularization;
- physical-time reconstruction;
- explicit regularized segments;
- experimental automatic switching;
- arbitrary-precision reference integration; and
- a scientific validation suite with explicit acceptance criteria.

The next research objective is a mathematically rigorous regularization of an
arbitrary three-dimensional close encounter. This review compares the main
candidate formulations and recommends the formulation that best fits the
existing architecture and scientific priorities of ThreeBody3D.

The central question is not merely whether a method removes the binary
collision singularity. The selected method must also support:

1. deterministic Cartesian-to-regularized and regularized-to-Cartesian maps;
2. accurate perturbed-pair propagation inside a three-body calculation;
3. reliable physical-time reconstruction;
4. switching with small transition residuals;
5. independently testable mathematical identities;
6. generic floating-point types, including `BigFloat`;
7. a clean and comprehensible Julia implementation; and
8. future extension without destabilizing the production `simulate` API.

---

## 2. Scope

This review addresses **pairwise close-encounter regularization** within the
Newtonian three-body problem.

It does not recommend replacing the complete ThreeBody3D integrator with a
special-purpose collisional N-body code. In particular, simultaneous strong
three-body interactions and near-triple collisions may eventually require
chain or algorithmic regularization. Those methods remain relevant future
research directions, but they solve a broader problem than the immediate
Stage 10 objective.

---

## 3. Mathematical problem

For a selected pair with relative position $\mathbf r$, relative velocity
$\mathbf v$, and gravitational parameter $\mu$, the perturbed relative
equation may be written schematically as

$$
\ddot{\mathbf r}
=
-\mu\frac{\mathbf r}{r^3}
+
\mathbf f(\mathbf r,\mathbf v,t),
\qquad
r=\lVert\mathbf r\rVert ,
$$

where $\mathbf f$ is the perturbation induced by the third body and any
future supported forces.

Direct Cartesian integration becomes increasingly difficult as $r$ becomes
small because the Newtonian acceleration scales as $r^{-2}$, while the
natural physical timescale of the encounter becomes very short.

A useful regularization should:

- remove the explicit collision singularity from the transformed equations;
- slow physical time near collision;
- preserve enough structure to reconstruct the physical trajectory;
- remain well-defined for non-planar motion; and
- expose numerical constraints that can be monitored in tests.

---

## 4. Candidate methods

### 4.1 Classical Kustaanheimo–Stiefel regularization

The KS transformation represents a three-dimensional relative position by a
four-dimensional variable. In common notation,

$$
\mathbf r = \mathcal K(\mathbf u),
\qquad
\mathbf u\in\mathbb R^4,
$$

with the fundamental radial identity

$$
r = \lVert\mathbf u\rVert^2
$$

for the selected convention.

Together with a Sundman transformation such as

$$
\frac{dt}{ds}=r,
$$

the unperturbed Kepler problem becomes a four-dimensional harmonic-oscillator
problem. Perturbations add regular forcing terms.

#### Strengths

- Direct three-dimensional analogue of Levi–Civita regularization.
- Removes the binary collision singularity.
- Well established in celestial mechanics and close-encounter integration.
- Natural conceptual continuation of ThreeBody3D's planar regularization.
- Supports explicit coordinate identities and constraint tests.
- Compatible with adaptive integration in fictitious time.
- Can be embedded around a selected pair while retaining pair-centred
  centre-of-mass variables.

#### Costs and risks

- Introduces one redundant coordinate.
- Requires a gauge or bilinear constraint.
- Published conventions differ in signs, component ordering, defining vector,
  momentum scaling, and time scaling.
- An inverse Cartesian-to-KS lift is not globally unique.
- Careless mixing of conventions can produce transformations that appear
  plausible but are not mutually consistent.

#### Assessment

Classical KS is the strongest match to the immediate ThreeBody3D objective,
provided that one convention is frozen and exhaustively tested before any
dynamical implementation.

---

### 4.2 Quaternion or spinor presentation of KS

KS was introduced through spinor ideas and is often presented using
quaternions. Quaternionic formulations make the geometry, gauge freedom, and
relation to rotations more explicit.

#### Strengths

- Clear geometric interpretation of the four-dimensional variable.
- Compact derivations.
- Natural expression of the circle action and gauge freedom.
- Valuable for proving identities and understanding the bilinear relation.
- Helpful when comparing the spatial and planar regularizations.

#### Costs and risks

- Quaternion notation may obscure implementation details for contributors
  unfamiliar with the convention.
- Left-versus-right multiplication and conjugation conventions vary.
- A custom quaternion abstraction could add unnecessary software machinery.
- A mathematically elegant canonical formulation is not automatically the
  simplest formulation for the first numerical prototype.

#### Assessment

Quaternion mathematics should guide the derivation and documentation, but the
first implementation should use explicit fixed-size real vectors and matrices.
This retains clarity in code, works naturally with `StaticArrays`, and makes
component-level tests straightforward.

---

### 4.3 Matrix formulation of KS

The matrix formulation expresses the Cartesian map and its differential with
an explicit convention-dependent matrix $L(\mathbf u)$. Schematically,

$$
\mathbf r = \Pi L(\mathbf u)\mathbf u,
$$

where $\Pi$ selects the physical three components from an associated
four-dimensional expression.

#### Strengths

- Directly implementable with fixed-size arrays.
- Transparent component ordering.
- Easy to compare against hand-calculated fixtures.
- Convenient for Jacobian, velocity, and inverse-map tests.
- Avoids introducing a public quaternion type.

#### Costs and risks

- Can hide the underlying geometry.
- Sign and ordering errors are easy to make.
- A matrix copied from a source using another convention may silently break
  the velocity map or gauge relation.

#### Assessment

Use the matrix formulation in production code, while documenting its exact
quaternion interpretation. The design specification must derive every matrix
from the selected convention rather than assembling formulas from unrelated
sources.

---

### 4.4 Canonical and symplectic KS formulations

Canonical KS formulations transform phase-space variables and treat the
bilinear relation as a momentum-map constraint associated with a circle
action. They are the appropriate language for Hamiltonian reduction and
symplectic analysis.

#### Strengths

- Mathematically rigorous phase-space structure.
- Clear treatment of the gauge symmetry.
- Suitable foundation for future symplectic or geometric integrators.
- Strong framework for proving equivalence and conservation properties.

#### Costs and risks

- More design complexity than required for an initial regularized ODE segment.
- Requires careful distinction between physical momentum, relative velocity,
  fictitious-time derivative, and canonical KS momentum.
- A canonical transformation alone does not guarantee that an arbitrary
  adaptive ODE solver will preserve symplectic structure.
- Raises implementation scope before the basic transforms have been validated.

#### Assessment

The canonical formulation should inform the design and supply invariants, but
it should not be required for the first implementation milestone. A later
geometric-integration phase may introduce canonical variables behind a
separate experimental API.

---

### 4.5 KS with an arbitrary defining vector

Some formulations expose an arbitrary preferred direction or defining vector
in the KS map. This clarifies that common textbook matrices encode a particular
choice rather than a unique transformation.

#### Strengths

- Makes convention dependence explicit.
- May permit orientation choices adapted to a problem.
- Useful for theoretical analysis and cross-checking formulations.

#### Costs and risks

- Adds configuration and test dimensions.
- Dynamically changing the defining vector creates an additional transition
  problem.
- Little immediate numerical benefit has been established for ThreeBody3D.
- Makes reproducibility harder unless the choice is fixed and serialized.

#### Assessment

Freeze one defining vector in the first implementation. Document it as part of
the mathematical convention. Do not expose arbitrary defining vectors in the
initial API. A generalized internal implementation may be considered only
after the fixed-convention version is validated.

---

### 4.6 Lissajous–KS and element-based formulations

Lissajous–KS and related element formulations reorganize KS variables into
oscillator-like amplitudes and angles. They are attractive for secular theory,
perturbation analysis, and orbit-element descriptions.

#### Strengths

- Can separate fast and slow variables.
- Useful for analytical perturbation theory.
- May offer insight into long-term orbital structure.

#### Costs and risks

- Not the shortest path to robust close-encounter switching.
- Introduces angular variables and additional singularity/branch concerns.
- Less directly compatible with the current state-vector and segment-handoff
  architecture.
- Harder to validate initially against the existing Cartesian and
  Levi–Civita infrastructure.

#### Assessment

Do not use Lissajous–KS as the first regularized propagation state. Revisit it
only if future work targets secular dynamics or regularized orbital elements.

---

### 4.7 Burdet–Ferrándiz and related regular elements

Burdet–Ferrándiz-type approaches regularize or linearize aspects of the
perturbed Kepler problem through transformed variables or orbital elements.

#### Strengths

- Strong celestial-mechanics pedigree.
- Potentially effective for long-term perturbed two-body propagation.
- Can offer element-like variables with useful analytical properties.

#### Costs and risks

- Less direct conceptual continuity with ThreeBody3D's Levi–Civita work.
- More difficult to integrate into the current Cartesian/regularized segment
  switching model.
- Often optimized for a perturbed two-body viewpoint rather than an explicit
  collision-coordinate map.
- Would require a new validation and interpretation layer.

#### Assessment

Not recommended for Stage 10. It may later be valuable as an independent
high-accuracy propagation formulation, but it does not offer the clearest path
to extending the existing regularization architecture from two to three
dimensions.

---

### 4.8 Algorithmic regularization and chain methods

Algorithmic regularization methods use time transformations and specially
constructed numerical maps without applying the nonlinear KS coordinate
transformation. Chain coordinates reduce roundoff during compact few-body
interactions.

#### Strengths

- Designed for general few-body encounters.
- Can handle strong multiparticle interactions.
- Avoids the KS gauge redundancy.
- Modern variants can support extreme mass ratios and velocity-dependent
  perturbations.
- May outperform older KS-chain schemes for some problems.

#### Costs and risks

- Represents a substantially different integrator architecture.
- Would not be a direct extension of the existing Levi–Civita and switching
  framework.
- Often relies on time-symmetric leapfrog or extrapolation machinery rather
  than the package's current SciML adaptive ODE structure.
- A production-quality implementation would be a major independent project.

#### Assessment

Algorithmic regularization is the leading alternative for eventual general
few-body regularization. It should be recorded on the long-term roadmap,
especially for simultaneous close encounters. It should not displace KS as
the next milestone because ThreeBody3D has already built the pair-selection,
regularized-segment, time-reconstruction, and switching infrastructure that KS
can reuse.

---

## 5. Comparative decision matrix

Scores are qualitative and specific to the current ThreeBody3D architecture.

| Method | Binary collision removal | 3D support | Fits existing switching | Implementation transparency | General multiparticle encounters | Recommendation |
|---|---:|---:|---:|---:|---:|---|
| Classical KS | Excellent | Excellent | Excellent | Good | Limited | **Adopt** |
| Quaternion presentation | Excellent | Excellent | Excellent | Good with care | Limited | Use for derivation |
| Matrix KS | Excellent | Excellent | Excellent | Excellent | Limited | Use in code |
| Canonical/symplectic KS | Excellent | Excellent | Good | Moderate | Limited | Defer full implementation |
| Arbitrary-vector KS | Excellent | Excellent | Moderate | Moderate | Limited | Fix one convention |
| Lissajous–KS | Excellent | Excellent | Low initially | Moderate | Limited | Defer |
| Burdet–Ferrándiz | Good | Excellent | Low | Moderate | Limited | Do not adopt now |
| Algorithmic/chain regularization | Excellent | Excellent | Requires redesign | Moderate | Excellent | Future separate track |

---

## 6. Recommended formulation

ThreeBody3D should implement a **classical fixed-convention KS
regularization**, represented in code by explicit four-component real vectors
and fixed-size transformation matrices.

The implementation should be derived and documented using quaternionic
geometry, but it should not require a public quaternion abstraction.

### Selected high-level decisions

1. **Physical scope**  
   Regularize one selected pair. Treat the third body's influence as a
   perturbation in pair-centred variables.

2. **Coordinate representation**  
   Use a four-component KS coordinate
   `SVector{4,T}`.

3. **Code representation**  
   Use explicit `StaticArrays` vectors and matrices. Keep all convention
   choices visible in one internal module.

4. **Time transformation**  
   Begin with the classical Sundman relation
   $$
   dt/ds=r.
   $$
   Any constant scaling must be fixed once and included consistently in every
   derivative and momentum formula.

5. **Gauge convention**  
   Adopt one deterministic gauge for Cartesian-to-KS initialization. Treat the
   associated bilinear relation as a required invariant.

6. **Defining vector**  
   Fix one defining vector and document it. Do not expose it as a user option
   in the first implementation.

7. **Dynamical variables**  
   Prefer variables that mirror the proven Levi–Civita segment design:
   regularized relative coordinates, their fictitious-time derivatives,
   pair centre-of-mass variables, third-body variables, and physical time.
   Whether an energy-like scalar must be integrated should be decided from the
   final perturbed equations, not by analogy alone.

8. **Numerical solver**  
   Initially retain the existing adaptive SciML solver strategy. Do not claim
   symplectic integration merely because the transformation has a canonical
   interpretation.

9. **API status**  
   Keep all KS functions experimental and internal or explicitly marked
   experimental until the validation programme is complete.

10. **Production API**  
    Do not alter the stable Cartesian `simulate` behaviour in the first KS
    milestones.

---

## 7. Required convention freeze

Before equations of motion are implemented, the design document must define
all of the following in one place.

### 7.1 Component ordering

Specify exactly:

- $\mathbf u=(u_1,u_2,u_3,u_4)$;
- the Cartesian ordering $(x,y,z)$;
- the selected defining vector;
- the sign convention;
- the associated $4\times4$ or $3\times4$ matrices.

### 7.2 Forward map

State the complete polynomial map

$$
\mathbf r=\mathcal K(\mathbf u)
$$

and prove or verify computationally that

$$
\lVert\mathbf r\rVert=\lVert\mathbf u\rVert^2.
$$

### 7.3 Differential map

Define the Jacobian

$$
D\mathcal K(\mathbf u)
$$

and the exact relation among:

- Cartesian physical velocity $d\mathbf r/dt$;
- fictitious-time derivative $d\mathbf r/ds$;
- KS derivative $d\mathbf u/ds$; and
- any canonical KS momentum.

These quantities must never share an ambiguous variable name.

### 7.4 Gauge or bilinear relation

State the scalar constraint in the selected convention and specify:

- how initial data satisfy it;
- how it is monitored;
- its expected numerical scale;
- whether projection is prohibited, optional, or required;
- how gauge-equivalent states are compared.

### 7.5 Inverse lift

Document a deterministic Cartesian-to-KS lift, including:

- branch selection;
- behaviour near branch boundaries;
- velocity lifting;
- continuity when a prior KS state is available;
- fallback behaviour when no prior gauge reference exists.

### 7.6 Time convention

State whether

$$
dt/ds=r
$$

or a scaled equivalent is used. Include dimensions and scaling.

---

## 8. Gauge strategy

The extra KS coordinate represents a circle of gauge-equivalent states.
Ignoring this redundancy is unsafe.

The first implementation should distinguish three operations.

### 8.1 Initial deterministic lift

For the first entry into KS coordinates, choose a deterministic algebraic lift.
It must be reproducible and tested in every Cartesian octant, near coordinate
planes, and for `BigFloat`.

### 8.2 Continuation-aware lift

When re-entering KS after an earlier KS segment, select the gauge-equivalent
lift that is closest to the retained previous KS state after appropriate
propagation or comparison. This should reduce artificial discontinuities.

### 8.3 Constraint monitoring

Record the bilinear-constraint residual throughout every KS segment. A
constraint failure must be observable in diagnostics and validation.

Do not add numerical projection during the earliest milestones. Projection can
mask an inconsistent equation or transformation. Consider projection only
after unconstrained drift has been measured and the projection's effect on
physical invariants has been validated.

---

## 9. Relationship to existing Levi–Civita work

The KS implementation should reuse architectural lessons, not merely copy
formulas.

### Reusable concepts

- selected-pair identity;
- pair-centred centre-of-mass decomposition;
- explicit regularized segment type;
- physical-time state and reconstruction;
- entry and exit events;
- transition diagnostics;
- retained-solution evaluation;
- automatic-switching controller;
- comparison against Cartesian and `BigFloat` references.

### Concepts that must be re-derived

- coordinate map;
- inverse map;
- velocity lift;
- gauge condition;
- regularized perturbation;
- energy relation;
- fictitious-time equations;
- entry-state continuity metric;
- three-dimensional validation cases.

A successful planar implementation is evidence that the architecture is
viable, not evidence that unverified spatial formulas are correct.

---

## 10. Perturbation model

For a selected pair $i,j$, the regularized relative subsystem must include
the differential acceleration exerted by the third body $k$:

$$
\mathbf f_{\mathrm{pert}}
=
\mathbf a_i^{(k)}-\mathbf a_j^{(k)}.
$$

The design must derive this perturbation in a form that remains regular after
multiplication by the required powers of $r$ from the Sundman and KS
transformations.

The pair centre of mass and third body may continue to evolve in Cartesian
physical coordinates or in a mixed fictitious-time formulation. The chosen
state must use one independent variable consistently within a segment.

The implementation must not freeze the third body or assume a constant tidal
field except in explicitly labelled unit tests.

---

## 11. Proposed module architecture

Names are provisional and should be reconciled with the current repository
before coding.

```text
src/
  regularization/
    KSConvention.jl
    KSTransforms.jl
    KSKinematics.jl
    KSDynamics.jl
    KSSegments.jl
    KSDiagnostics.jl
    KSSwitching.jl
```

### `KSConvention.jl`

Owns:

- component ordering;
- defining vector;
- fixed matrices;
- sign conventions;
- gauge matrix or bilinear form.

No other source file should duplicate these formulas.

### `KSTransforms.jl`

Owns:

- forward coordinate map;
- deterministic inverse lift;
- gauge transformations;
- radial identity;
- round-trip utilities.

### `KSKinematics.jl`

Owns:

- Jacobian;
- velocity and derivative maps;
- constraint residual;
- physical-time derivative.

### `KSDynamics.jl`

Owns:

- perturbed regularized RHS;
- parameter bundle;
- energy-like state if required;
- generic scalar type handling.

### `KSSegments.jl`

Owns:

- explicit KS segment propagation;
- physical-time interpolation;
- segment result type;
- Cartesian reconstruction.

### `KSDiagnostics.jl`

Owns:

- gauge residual;
- transition residual;
- physical invariant drift;
- reconstruction error;
- segment metadata.

### `KSSwitching.jl`

Owns:

- KS entry/exit handoff;
- deterministic and continuation-aware lift selection;
- integration with the existing controller.

The exact file layout should remain smaller if the current regularization
subsystem already provides suitable shared abstractions.

---

## 12. Incremental implementation plan

Each milestone should be a separate, tested commit.

### KS-1 — Convention and algebraic forward map

Implement only:

- fixed convention;
- forward map;
- radial identity;
- gauge transformation utility if needed.

Tests:

- known coordinate fixtures;
- random radial identity;
- homogeneity;
- gauge invariance of Cartesian position;
- `Float64` and `BigFloat`.

No ODE code.

### KS-2 — Deterministic inverse coordinate lift

Implement:

- Cartesian-to-KS position lift;
- branch handling;
- round-trip tests.

Tests:

- all octants;
- coordinate planes;
- near branch boundaries;
- random round trips;
- scale extremes;
- `BigFloat`.

### KS-3 — Differential and velocity maps

Implement:

- Jacobian;
- fictitious-time derivative map;
- Cartesian velocity reconstruction;
- inverse velocity lift subject to the gauge condition.

Tests:

- finite-difference Jacobian;
- analytic round trips;
- gauge residual;
- automatic differentiation comparison if practical;
- dimensional consistency.

### KS-4 — Unperturbed Kepler propagation

Implement a standalone relative two-body KS problem.

Validation:

- circular orbit;
- eccentric elliptic orbit;
- near-radial orbit;
- collision trajectory;
- hyperbolic flyby;
- comparison with universal-variable or Cartesian `BigFloat` reference;
- physical-time reconstruction.

Do not integrate the full three-body system yet.

### KS-5 — Perturbed pair dynamics

Add an externally supplied smooth perturbing acceleration.

Validation:

- zero perturbation recovers KS-4;
- constant test perturbation;
- manufactured solution where possible;
- convergence under tolerance refinement.

### KS-6 — Explicit three-body KS segment

Integrate:

- selected pair in KS variables;
- pair centre of mass;
- third body;
- physical time.

Validation:

- Cartesian reconstruction;
- conservation diagnostics;
- comparison with high-precision Cartesian reference away from collision;
- close-encounter comparison.

### KS-7 — Manual Cartesian–KS–Cartesian composition

Implement manual entry and exit at prescribed physical times.

Acceptance checks:

- state transition residual;
- energy jump;
- momentum jump;
- angular-momentum jump;
- gauge residual;
- monotonic physical time;
- solution continuity.

### KS-8 — Event-targeted segment boundaries

Add event location in physical observables while integrating in fictitious
time.

Tests:

- entry/exit threshold accuracy;
- targeting-tolerance derivation;
- retained-solution evaluation;
- no duplicate or reversed physical times.

### KS-9 — Experimental automatic switching

Integrate KS as a new spatial regularization mode in the existing controller.

Initial policy:

- use Levi–Civita only when an explicitly planar mode is requested or proven;
- use KS for general spatial encounters;
- preserve the stable Cartesian `simulate` path.

### KS-10 — Scientific validation promotion

Add benchmarks with explicit acceptance criteria. Only after this milestone
should KS be described as scientifically validated.

---

## 13. Validation programme

### 13.1 Algebraic validation

- radial identity;
- gauge invariance;
- forward/inverse position round trip;
- forward/inverse velocity round trip;
- Jacobian finite-difference agreement;
- scaling laws;
- component-permutation and sign fixtures.

### 13.2 Unperturbed dynamical validation

- conservation of two-body energy and angular momentum;
- oscillator-equation residual;
- exact or universal-variable comparison;
- repeated high-eccentricity periapsis passages;
- collision and ejection branches where mathematically appropriate.

### 13.3 Perturbed validation

- weak distant third-body perturbation;
- inclined hierarchical triple;
- non-planar close flyby;
- exchange encounter;
- tolerance refinement;
- comparison with Cartesian `BigFloat` Vern9 reference.

### 13.4 Switching validation

- Cartesian-to-KS transition;
- KS-to-Cartesian transition;
- repeated switching;
- pair identity retention;
- pair change only through a separately validated policy;
- physical-time monotonicity;
- no missed threshold crossings;
- conservation jumps at handoff.

### 13.5 Failure validation

The code should intentionally reject or report:

- zero or invalid masses;
- non-finite states;
- inconsistent gauge-constrained derivatives;
- invalid pair indices;
- impossible inverse-lift requests;
- non-monotonic physical time;
- event-targeting failure;
- solver failure;
- triple-close configurations outside the pairwise model's validity.

---

## 14. Acceptance criteria policy

Thresholds must be derived empirically from validated reference runs and
include a justified margin above the observed numerical floor.

Every promoted KS benchmark should report at least:

- completion status;
- final physical time;
- minimum selected-pair separation;
- maximum relative energy drift;
- momentum drift;
- angular-momentum drift;
- centre-of-mass residual;
- maximum gauge-constraint residual;
- maximum Cartesian reconstruction residual;
- transition residual;
- energy jump at each switch;
- physical-time monotonicity;
- comparison error against the selected reference.

No benchmark should pass merely because it reaches the final time.

---

## 15. API policy

During development:

- KS types and functions remain experimental.
- Public names should be minimal.
- Mathematical convention details remain internal but documented.
- Stable users continue to call `simulate`.
- Automatic KS switching should require explicit opt-in until validation is
  complete.
- No existing exported API should be renamed merely to accommodate KS.

Potential experimental entry point:

```julia
simulate_ks_segment(...)
```

The exact name should follow the existing regularization subsystem rather than
creating a parallel naming scheme.

---

## 16. What should not be done

1. Do not combine formulas from sources using different KS conventions.
2. Do not begin with automatic switching.
3. Do not hide the gauge residual.
4. Do not add constraint projection before measuring natural drift.
5. Do not describe an adaptive transformed ODE solve as symplectic.
6. Do not treat a close triple as a regular perturbed binary without a
   validity diagnostic.
7. Do not optimize before the `BigFloat` reference comparisons pass.
8. Do not expose arbitrary defining-vector choices prematurely.
9. Do not replace existing Levi–Civita validation; use it as an independent
   planar cross-check.
10. Do not implement from memory when the exact repository files are not
    available for inspection.

---

## 17. Long-term alternatives

### 17.1 Algorithmic regularization track

After pairwise KS is complete, evaluate algorithmic regularization for:

- simultaneous strong three-body interactions;
- near-triple collisions;
- velocity-dependent perturbations;
- extreme mass ratios;
- longer compact few-body integrations.

This should be a separate design project rather than an extension hidden
inside the KS subsystem.

### 17.2 Geometric integration track

After the baseline KS equations are validated, evaluate:

- canonical KS variables;
- time-symmetric integration;
- symplectic or variational methods;
- long-term phase and invariant behaviour.

The existing adaptive solver remains the scientific baseline for comparisons.

### 17.3 Regularized elements

Consider Lissajous–KS or other regularized elements only for future secular
analysis or orbit-element APIs.

---

## 18. Final recommendation

Proceed to Stage 10B with the following decision:

> Implement a fixed-convention classical Kustaanheimo–Stiefel
> regularization for one selected pair, using a quaternion-derived but
> matrix-implemented four-real-coordinate representation, the classical
> Sundman transformation, explicit gauge-constraint diagnostics, and the
> existing pair-centred segment and switching architecture.

This is preferred because it:

- directly generalizes the validated Levi–Civita research;
- targets the immediate three-dimensional binary close-encounter problem;
- fits the current code architecture;
- supports rigorous algebraic and numerical tests;
- retains generic precision;
- avoids premature replacement of the production integrator; and
- leaves algorithmic regularization available as a distinct future solution
  for genuinely multiparticle close encounters.

The next repository change should be a design-only commit containing a
convention-complete `KS_REGULARIZATION_DESIGN.md`. No KS dynamics code should
be written until that document fixes the coordinate map, gauge relation,
velocity lift, time transformation, and perturbed equations in one internally
consistent notation.

---

## 19. Principal literature

1. P. Kustaanheimo and E. Stiefel, *Perturbation theory of Kepler motion
   based on spinor regularization*, Journal für die reine und angewandte
   Mathematik 218 (1965).

2. E. L. Stiefel and G. Scheifele, *Linear and Regular Celestial Mechanics:
   Perturbed Two-Body Motion, Numerical Methods, Canonical Theory*,
   Springer, 1971.

3. P. Saha, *Interpreting the Kustaanheimo–Stiefel transform in gravitational
   dynamics*, Monthly Notices of the Royal Astronomical Society 400 (2009),
   228–231; arXiv:0803.4441.

4. L. Zhao, *Kustaanheimo–Stiefel regularization and the quadrupolar
   conjugacy*, Regular and Chaotic Dynamics 20 (2015), 19–36;
   arXiv:1308.2314.

5. S. Breiter, *Kustaanheimo–Stiefel transformation with an arbitrary
   defining vector*, Celestial Mechanics and Dynamical Astronomy 128 (2017).

6. Y. Funato, P. Hut, S. McMillan, and J. Makino,
   *Time-symmetrized Kustaanheimo–Stiefel regularization*,
   The Astronomical Journal 112 (1996); arXiv:astro-ph/9604025.

7. S. Mikkola and K. Tanikawa, *Algorithmic regularization of the few-body
   problem*, Monthly Notices of the Royal Astronomical Society 310 (1999),
   745–749.

8. S. Mikkola and D. Merritt, *Implementing few-body algorithmic
   regularization with post-Newtonian terms*, The Astronomical Journal 135
   (2008); arXiv:0709.3367.

---

## 20. Review outcome

The recommendation in Section 18 was adopted without changing the selected
mathematical convention. The implementation now includes the algebraic,
dynamical, coupled three-body, explicit-segment, automatic-switching, testing,
and scientific-validation stages specified by the subsequent frozen
implementation plan.

The review did not authorize, and the implementation does not claim, general
three-body collision regularization. The validated capability applies to one
selected binary pair. Simultaneous triple collision, loss of pair isolation,
and general multiparticle close encounters remain separate research problems.

For API purposes, the KS implementation is retained as internal research
infrastructure. Only its selection through the existing experimental
automatic-switching controller is externally visible, and that controller
remains explicitly experimental.

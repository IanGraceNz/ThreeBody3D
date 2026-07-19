# ThreeBody3D v0.4 Design Specification
## Regularized Close-Encounter Integration

**Status:** Proposed design  
**Target branch:** `v0.4-development`  
**Primary objective:** Preserve scientifically meaningful trajectories through arbitrarily close binary encounters without force softening, while keeping the public API simple and the implementation testable.

## 1. Executive decision

Version 0.4 will proceed in small, independently verifiable stages:

1. Establish mathematical and numerical reference problems.
2. Implement a standalone planar Levi–Civita two-body prototype.
3. Extend it to a perturbed binary embedded in a planar three-body system.
4. Implement spatial Kustaanheimo–Stiefel regularization for a selected binary pair.
5. Add Sundman fictitious-time integration and physical-time reconstruction.
6. Only after standalone validation, design and implement automatic switching.
7. Compare classical coordinate regularization with algorithmic regularization as an independent benchmark and possible fallback.

The package will not use gravitational softening as a substitute for regularization.

## 2. Scientific problem

For Newtonian point masses,

\[
\ddot{\mathbf r}_i =
G\sum_{j\ne i}m_j
\frac{\mathbf r_j-\mathbf r_i}
{\lVert\mathbf r_j-\mathbf r_i\rVert^3}.
\]

As a pair separation approaches zero, acceleration diverges, the physical-time ODE becomes singular, adaptive steps collapse, and numerical conditioning deteriorates. The current close-approach monitor only reports this region; it does not remove the singularity.

The v0.4 objective is to transform the equations so a selected binary collision becomes a regular point of a new system.

## 3. Scope

### In scope

- Newtonian three-body dynamics in two and three dimensions.
- Binary close encounters and binary collisions.
- Levi–Civita regularization for planar relative motion.
- Kustaanheimo–Stiefel regularization for spatial relative motion.
- Sundman-type physical/fictitious time transformation.
- Physical-state reconstruction and invariant diagnostics.
- Explicit selection of the regularized pair.
- High-precision validation against BigFloat `:extreme` solutions.
- A later, separately designed automatic switching layer.

### Initially out of scope

- Simultaneous regularization of all three pairs.
- Triple-collision regularization.
- Post-Newtonian terms.
- Finite-size collision physics, mergers, rebound, or disruption.
- Force softening.
- Automatic production switching before standalone validation.

Triple collision is qualitatively different from isolated binary collision and requires separate treatment.

## 4. Pair-centred decomposition

For selected pair `(i,j)`, define

\[
M=m_i+m_j,\qquad \mu=\frac{m_i m_j}{M},
\]

\[
\mathbf R=\frac{m_i\mathbf r_i+m_j\mathbf r_j}{M},\qquad
\mathbf q=\mathbf r_i-\mathbf r_j.
\]

Reconstruction is

\[
\mathbf r_i=\mathbf R+\frac{m_j}{M}\mathbf q,\qquad
\mathbf r_j=\mathbf R-\frac{m_i}{M}\mathbf q,
\]

with analogous velocity relations. This isolates the singular internal binary motion in `q`, nonsingular binary-centre translation, and third-body perturbation.

This pair-coordinate layer must be shared by Levi–Civita and KS methods.

## 5. Levi–Civita regularization

For planar relative motion, introduce `u` through the quadratic map

\[
q=u^2
\]

in complex notation, or

\[
q_x=u_1^2-u_2^2,\qquad q_y=2u_1u_2,
\]

so that

\[
\lVert q\rVert=\lVert u\rVert^2.
\]

Use a Sundman transformation such as

\[
\frac{dt}{ds}=\lVert q\rVert=\lVert u\rVert^2.
\]

The collision `q=0` maps to `u=0`, where the transformed equations can remain regular.

### Milestone A: isolated planar two-body problem

Required:

- Cartesian ↔ Levi–Civita conversion.
- Consistent sign/gauge handling.
- Fictitious-time integration.
- Physical-time reconstruction.
- Elliptic, parabolic, hyperbolic, radial, and collision-orbit tests.
- Comparison with analytic Kepler solutions.

### Milestone B: perturbed planar binary

Embed a selected binary in the planar three-body problem. The third-body perturbation must be expressed in the regularized relative equations without creating a new singularity at binary collision.

Initial experimental API:

```julia
result = simulate_regularized(
    system,
    u0,
    tspan;
    pair = (1, 2),
    method = :levi_civita,
)
```

Automatic pair selection is deferred.

## 6. Kustaanheimo–Stiefel regularization

KS maps a four-dimensional coordinate `U ∈ R⁴` to the physical relative coordinate `q ∈ R³`. The map is quadratic and includes one gauge degree of freedom. Spatial Kepler motion becomes oscillator-like in four dimensions. citeturn300857search3turn300857search12

The implementation must define:

- one canonical KS convention;
- the quadratic map and Jacobian;
- the momentum/velocity map;
- the bilinear constraint;
- gauge initialization and monitoring;
- Cartesian-to-KS initialization;
- physical-state reconstruction;
- constraint handling policy.

Required diagnostics:

- KS bilinear constraint residual;
- map reconstruction error;
- physical energy and angular-momentum error;
- momentum and centre-of-mass residuals;
- monotonicity of physical time.

The exact internal canonical variables must be derived and documented before implementation.

## 7. Sundman time layer

Represent

\[
\frac{dt}{ds}=g(x),
\]

with `g(x)>0` away from collision and controlled decay near the selected singularity. For binary regularization, the first candidate is proportional to selected-pair separation. Sundman-style time transformation is a classical route to regularizing the three-body problem. citeturn300857search6turn300857search19

Requirements:

- Physical time is integrated as a state variable.
- Stop at the requested physical end time, not guessed fictitious time.
- Event times are reported in physical time.
- Dense physical-time output uses a controlled inversion/interpolation layer.
- Diagnostics distinguish physical-time samples from fictitious-time internal work.

## 8. Software architecture

Proposed internal structure:

```text
src/
    Regularization/
        Regularization.jl
        PairCoordinates.jl
        Sundman.jl
        LeviCivita.jl
        KS.jl
        Reconstruction.jl
        RegularizedIntegrator.jl
        Constraints.jl
```

Suggested internal operations:

```julia
initialize_regularized_state(method, system, physical_state, pair)
regularized_rhs!(du, u, parameters, s)
reconstruct_physical_state(method, regularized_state)
physical_time(regularized_state)
constraint_residual(method, regularized_state)
```

Avoid a large abstract-type hierarchy until at least two methods exist. Start with concrete functions and small shared data structures.

Initial public API:

```julia
simulate_regularized(system, u0, tspan; pair=(1,2), method=:levi_civita)
simulate_regularized(system, u0, tspan; pair=(1,2), method=:ks)
```

Only after validation:

```julia
simulate(system, u0, tspan; regularization=:automatic,
         enter_threshold=..., exit_threshold=...)
```

## 9. Automatic switching

Automatic switching introduces conversion discontinuities, time-consistency risks, threshold chatter, pair ambiguity, and possible invariant jumps. It must therefore be implemented as a state machine:

```text
OrdinaryIntegration
RegularizedIntegration(pair, method)
Completed
Failed
```

### Entry conditions

- Pair separation below `enter_threshold`.
- Pair approaching, not receding.
- Selected pair clearly closer than the other two.
- No competing simultaneous close pair.
- Coordinate-conversion residual below tolerance.

### Exit conditions

- Separation above a larger `exit_threshold`.
- Pair receding.
- Reconstruction and constraint residuals acceptable.

Require `exit_threshold > enter_threshold` to provide hysteresis.

If two pairs are simultaneously close, the first production implementation should stop with a structured diagnostic rather than guess. This may indicate a near-triple encounter needing chain or global regularization.

## 10. Result and event model

The public result should expose a physical trajectory regardless of internal coordinates.

Proposed metadata:

```julia
struct RegularizationEvent{T}
    physical_time::T
    kind::Symbol
    pair::Tuple{Int,Int}
    method::Symbol
    separation::T
    conversion_residual::T
    constraint_residual::T
end
```

Store ordinary and regularized segments, all transitions, transition states, per-segment solver statistics, constraint diagnostics, and structured failure reasons.

## 11. Validation programme

### Level 1: map tests

For LC and KS:

- Physical → regularized → physical round trips.
- Regularized → physical → regularized modulo gauge.
- Jacobian verification.
- Velocity/momentum transformation checks.
- Collision-limit behaviour.
- `Float64` and `BigFloat` coverage.

### Level 2: analytic two-body tests

- Circular orbit.
- High-eccentricity ellipse.
- Parabolic passage.
- Hyperbolic scattering.
- Radial collision and continuation.
- Time reversal.

Compare with analytic Kepler solutions using position, velocity, phase, energy, angular momentum, collision continuity, and physical-time reconstruction errors.

### Level 3: perturbed binary tests

Embed a close binary with a distant third body. Compare ordinary BigFloat `:extreme`, regularized integration, and—where needed—a still-higher-precision reference. Vary mass ratio, eccentricity, third-body distance, orientation, and minimum separation.

### Level 4: three-body close-encounter benchmarks

Candidate families:

- Pythagorean three-body problem.
- Hierarchical triple with extreme binary eccentricity.
- Binary-single scattering.
- Controlled near-collision variants.
- Time-reversed trajectories.

Each benchmark must include stored initial conditions, units, expected qualitative outcome, and quantitative thresholds.

### Level 5: switching tests

Only after standalone validation:

- Compare always-regularized and switched trajectories.
- Vary entry/exit thresholds.
- Check convergence as thresholds move.
- Measure invariant jumps at transitions.
- Verify independence from `saveat`.
- Test deterministic event ordering and competing-pair ambiguity.

## 12. Acceptance criteria

Before exposing a method publicly:

- Every transformation has round-trip tests.
- Exact or near-radial collision continues in regularized variables.
- Physical time remains monotone.
- No softening parameter is introduced.
- Conservation improves materially for close encounters.
- Far from encounters, results agree with ordinary `:extreme` references.
- Results converge with increased precision and tighter tolerances.
- `BigFloat` is supported.
- Constraint residuals are reported and bounded.
- All v0.3 tests still pass.

Before automatic switching becomes default:

- Transition invariant jumps stay below documented limits.
- Hysteresis prevents chatter.
- Ambiguous encounters fail safely.
- Switched and always-regularized solutions agree within established tolerances.
- Adversarial regression tests pass.

## 13. Failure policy

Fail explicitly rather than silently corrupting a trajectory. Structured reasons should include:

- unsupported dimensionality;
- invalid pair;
- ill-conditioned conversion;
- KS constraint violation;
- non-monotone physical time;
- simultaneous close pairs;
- triple-collision candidate;
- reconstruction residual above tolerance;
- fictitious-time solver failure.

Errors should include physical time, pair, separation, method, and relevant residuals.

## 14. Precision policy

All regularization code must be generic over `T<:AbstractFloat`.

Use:

- `Float64` for normal operation;
- 256-bit BigFloat for reference tests;
- higher precision selectively to demonstrate convergence.

Construct high-precision constants from decimal strings. Scope precision with `setprecision(... do ...)`; do not change global precision.

## 15. Performance policy

Correctness first, but record:

- warmed elapsed time;
- allocations where practical;
- accepted/rejected steps;
- RHS evaluations;
- conversion cost;
- number and duration of regularized segments;
- constraint-correction work.

Do not treat first-run timings that include Julia compilation as performance evidence.

## 16. Alternative benchmark: algorithmic regularization

Classical LC/KS is not the only rigorous route. Time-transformed leapfrog, logarithmic-Hamiltonian methods, chain coordinates, and AR-CHAIN-style methods can handle difficult few-body encounters using only linear coordinate transformations. Published tests report competitive or superior performance to KS-chain methods in some regimes. citeturn300857search7turn300857search31

ThreeBody3D should keep LC/KS as the mathematically transparent primary route while retaining algorithmic regularization as a benchmark and possible later architecture for ambiguous multi-pair encounters.

## 17. Git and implementation plan

After the v0.3 milestone is committed, create `v0.4-development`.

Proposed commits:

1. `Add v0.4 regularization design specification`
2. `Add pair-centred coordinate transformations`
3. `Add analytic planar two-body validation cases`
4. `Implement Levi-Civita coordinate maps`
5. `Implement isolated Levi-Civita integration`
6. `Validate Levi-Civita collision continuation`
7. `Embed Levi-Civita binary in planar three-body dynamics`
8. `Add KS mathematical conventions and constraint tests`
9. `Implement KS coordinate maps`
10. `Implement isolated spatial KS integration`
11. `Embed KS binary in spatial three-body dynamics`
12. `Add Sundman physical-time reconstruction`
13. `Add regularized result and event metadata`
14. `Prototype explicit ordinary-to-regularized switching`
15. `Add switching hysteresis and ambiguity handling`
16. `Add publication-quality close-encounter benchmarks`

Each commit must have one main purpose, include tests, preserve all earlier tests, and update documentation where public behaviour changes.

## 18. First implementation task

Do not begin with the full LC ODE. First implement and exhaustively test:

```julia
to_pair_coordinates(system, physical_state, pair)
from_pair_coordinates(system, pair_state, pair)
```

This common decomposition supports both LC and KS and can be validated independently.

Second, build the analytic two-body validation harness. Only then implement the Levi–Civita transformation.

## 19. Open decisions

Before each affected implementation phase, explicitly decide:

1. Canonical momentum versus velocity variables.
2. Exact KS matrix/quaternion convention.
3. KS gauge initialization and monitoring.
4. Constraint projection, stabilization, or rejection.
5. Dense physical-time interpolation strategy.
6. Online physical sampling versus post-reconstruction.
7. Criterion for isolated versus ambiguous encounter.
8. Initial regularized solver choice.
9. Visualization path for regularized solutions.
10. Timing of the algorithmic-regularization comparison prototype.

## 20. Final recommendation

Proceed as a research and validation programme:

```text
pair coordinates
→ analytic two-body harness
→ planar Levi–Civita
→ perturbed planar binary
→ spatial KS
→ Sundman/output layer
→ explicit switching
→ automatic switching
```

This sequence maximizes auditability, minimizes architectural rework, and preserves the stable ordinary-integration path throughout development.

## References

- D. K. Yeomans, *Exposition of Sundman's Regularization of the Three-Body Problem*, NASA TM X-55636, 1966. citeturn300857search6turn300857search19
- P. Saha, *Interpreting the Kustaanheimo–Stiefel Transform in Gravitational Dynamics*. citeturn300857search3turn300857search35
- L. Zhao, *Kustaanheimo–Stiefel Regularization and the Quadrupolar Conjugacy*. citeturn300857search12
- S. Mikkola and D. Merritt, *Implementing Few-Body Algorithmic Regularization with Post-Newtonian Terms*. citeturn300857search7turn300857search25
- S. Mikkola, *Algorithmic Regularization of the Few-Body Problem*. citeturn300857search31

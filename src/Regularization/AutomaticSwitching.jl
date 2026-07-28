"""
    ExperimentalSwitchingMode

Abstract supertype for the internal mode of the experimental automatic
regularization controller.

The initial implementation distinguishes ordinary Cartesian propagation from
propagation of one explicitly selected planar Levi-Civita pair. These mode
objects contain no solver state and do not themselves perform integration.
"""
abstract type ExperimentalSwitchingMode end

"""
    CartesianSwitchingMode()

Mode indicating that the experimental controller is propagating the ordinary
Cartesian three-body equations.
"""
struct CartesianSwitchingMode <: ExperimentalSwitchingMode end

"""
    RegularizedSwitchingMode(pair)

Mode indicating that the experimental controller is propagating one selected
binary pair with planar Levi-Civita regularization.

`pair` must contain two distinct body indices from `1:3`. The selected ordered
pair is retained exactly because reversing its order changes the coordinate
orientation even though it represents the same physical binary.
"""
struct RegularizedSwitchingMode <: ExperimentalSwitchingMode
    pair::Tuple{Int,Int}

    function RegularizedSwitchingMode(pair::Tuple{<:Integer,<:Integer})
        i, j, _ = _validate_pair(pair)
        new((i, j))
    end
end

"""
    AutomaticSwitchingThresholdPolicy

Abstract supertype for immutable threshold policies used by the experimental
automatic-switching controller.

A threshold policy is resolved once into fixed physical entry, exit, and
ambiguity distances before event location begins. This prevents thresholds from
drifting during a Cartesian or regularized segment.
"""
abstract type AutomaticSwitchingThresholdPolicy end

"""
    AbsoluteSwitchingThresholdPolicy(; enter_threshold, exit_threshold,
                                     ambiguity_threshold=exit_threshold)

Backwards-compatible threshold policy storing explicit physical distances.
"""
struct AbsoluteSwitchingThresholdPolicy{T<:AbstractFloat} <:
       AutomaticSwitchingThresholdPolicy
    enter_threshold::T
    exit_threshold::T
    ambiguity_threshold::T
end

function AbsoluteSwitchingThresholdPolicy(;
    enter_threshold::Real,
    exit_threshold::Real,
    ambiguity_threshold::Real=exit_threshold,
)
    T = float(promote_type(
        typeof(enter_threshold), typeof(exit_threshold), typeof(ambiguity_threshold),
    ))
    enter = T(enter_threshold)
    exit = T(exit_threshold)
    ambiguity = T(ambiguity_threshold)
    all(isfinite, (enter, exit, ambiguity)) ||
        throw(ArgumentError("automatic-switching thresholds must be finite."))
    enter > zero(T) || throw(ArgumentError("enter_threshold must be positive."))
    exit > enter ||
        throw(ArgumentError("exit_threshold must be greater than enter_threshold."))
    ambiguity >= enter ||
        throw(ArgumentError("ambiguity_threshold must be at least enter_threshold."))
    AbsoluteSwitchingThresholdPolicy{T}(enter, exit, ambiguity)
end

"""
    ScaleAwareSwitchingThresholdPolicy(; characteristic_length, enter_factor,
                                       exit_factor,
                                       ambiguity_factor=exit_factor)

Experimental scale-aware policy that multiplies dimensionless factors by one
caller-supplied positive `characteristic_length`.

The characteristic length is immutable and is resolved once when
[`AutomaticSwitchingParameters`](@ref) is constructed. AS-2 intentionally does
not infer a local dynamical scale or change the default absolute policy.
"""
struct ScaleAwareSwitchingThresholdPolicy{T<:AbstractFloat} <:
       AutomaticSwitchingThresholdPolicy
    characteristic_length::T
    enter_factor::T
    exit_factor::T
    ambiguity_factor::T
end

function ScaleAwareSwitchingThresholdPolicy(;
    characteristic_length::Real,
    enter_factor::Real,
    exit_factor::Real,
    ambiguity_factor::Real=exit_factor,
)
    T = float(promote_type(
        typeof(characteristic_length), typeof(enter_factor),
        typeof(exit_factor), typeof(ambiguity_factor),
    ))
    scale = T(characteristic_length)
    enter = T(enter_factor)
    exit = T(exit_factor)
    ambiguity = T(ambiguity_factor)
    all(isfinite, (scale, enter, exit, ambiguity)) ||
        throw(ArgumentError("scale-aware switching policy values must be finite."))
    scale > zero(T) ||
        throw(ArgumentError("characteristic_length must be positive."))
    enter > zero(T) || throw(ArgumentError("enter_factor must be positive."))
    exit > enter ||
        throw(ArgumentError("exit_factor must be greater than enter_factor."))
    ambiguity >= enter ||
        throw(ArgumentError("ambiguity_factor must be at least enter_factor."))
    ScaleAwareSwitchingThresholdPolicy{T}(scale, enter, exit, ambiguity)
end

"""
    automatic_switching_thresholds(policy)

Resolve an immutable threshold policy into deterministic physical distances and
scale evidence. The result contains `enter_threshold`, `exit_threshold`,
`ambiguity_threshold`, `scale_kind`, and `reference_scale`.
"""
function automatic_switching_thresholds(policy::AbsoluteSwitchingThresholdPolicy{T}) where {T}
    (
        enter_threshold=policy.enter_threshold,
        exit_threshold=policy.exit_threshold,
        ambiguity_threshold=policy.ambiguity_threshold,
        scale_kind=:absolute,
        reference_scale=one(T),
    )
end

function automatic_switching_thresholds(policy::ScaleAwareSwitchingThresholdPolicy{T}) where {T}
    scale = policy.characteristic_length
    enter = scale * policy.enter_factor
    exit = scale * policy.exit_factor
    ambiguity = scale * policy.ambiguity_factor
    all(isfinite, (enter, exit, ambiguity)) ||
        throw(ArgumentError("resolved scale-aware switching thresholds must be finite."))
    (
        enter_threshold=enter,
        exit_threshold=exit,
        ambiguity_threshold=ambiguity,
        scale_kind=:characteristic_length,
        reference_scale=scale,
    )
end

"""
    AutomaticSwitchingParameters(; enter_threshold, exit_threshold, ...)
    AutomaticSwitchingParameters(policy; ...)

Validated numerical and safety parameters for experimental threshold-driven
automatic regularization.

The keyword-only form remains the backwards-compatible absolute-threshold API.
The policy form accepts either [`AbsoluteSwitchingThresholdPolicy`](@ref) or
[`ScaleAwareSwitchingThresholdPolicy`](@ref) and resolves it once into fixed
physical thresholds.

Required hysteresis is enforced by
`0 < enter_threshold < exit_threshold`. `ambiguity_threshold` defaults to the
exit threshold and must not be smaller than the entry threshold.
`minimum_separation_ratio > 1` requires the second-smallest pair separation to
remain larger than the selected separation by a configurable factor.
`maximum_switches` bounds the total number of entry and exit events, while
`minimum_time_progress > 0` prevents zero-time switching loops.
`minimum_separation_excursion >= 0` optionally requires a completed exit to be
followed by a sufficiently deep inward excursion before the same unordered pair
may enter regularization again. The default zero preserves existing behaviour.
"""
struct AutomaticSwitchingParameters{T<:AbstractFloat}
    enter_threshold::T
    exit_threshold::T
    ambiguity_threshold::T
    minimum_separation_ratio::T
    maximum_switches::Int
    minimum_time_progress::T
    minimum_separation_excursion::T
    threshold_scale_kind::Symbol
    threshold_reference_scale::T
end

function AutomaticSwitchingParameters(;
    enter_threshold::Real,
    exit_threshold::Real,
    ambiguity_threshold::Real=exit_threshold,
    minimum_separation_ratio::Real=2,
    maximum_switches::Integer=100,
    minimum_time_progress::Real=eps(float(promote_type(
        typeof(enter_threshold), typeof(exit_threshold),
    ))),
    minimum_separation_excursion::Real=0,
)
    policy = AbsoluteSwitchingThresholdPolicy(;
        enter_threshold, exit_threshold, ambiguity_threshold,
    )
    AutomaticSwitchingParameters(
        policy;
        minimum_separation_ratio,
        maximum_switches,
        minimum_time_progress,
        minimum_separation_excursion,
    )
end

function AutomaticSwitchingParameters(
    policy::AutomaticSwitchingThresholdPolicy;
    minimum_separation_ratio::Real=2,
    maximum_switches::Integer=100,
    minimum_time_progress::Real=eps(float(typeof(
        automatic_switching_thresholds(policy).enter_threshold,
    ))),
    minimum_separation_excursion::Real=0,
)
    resolved = automatic_switching_thresholds(policy)
    T = float(promote_type(
        typeof(resolved.enter_threshold),
        typeof(resolved.exit_threshold),
        typeof(resolved.ambiguity_threshold),
        typeof(resolved.reference_scale),
        typeof(minimum_separation_ratio),
        typeof(minimum_time_progress),
        typeof(minimum_separation_excursion),
    ))
    enter = T(resolved.enter_threshold)
    exit = T(resolved.exit_threshold)
    ambiguity = T(resolved.ambiguity_threshold)
    ratio = T(minimum_separation_ratio)
    progress = T(minimum_time_progress)
    excursion = T(minimum_separation_excursion)
    reference_scale = T(resolved.reference_scale)

    all(isfinite, (enter, exit, ambiguity, ratio, progress, excursion, reference_scale)) ||
        throw(ArgumentError("automatic-switching parameters must be finite."))
    enter > zero(T) || throw(ArgumentError("enter_threshold must be positive."))
    exit > enter ||
        throw(ArgumentError("exit_threshold must be greater than enter_threshold."))
    ambiguity >= enter ||
        throw(ArgumentError("ambiguity_threshold must be at least enter_threshold."))
    ratio > one(T) ||
        throw(ArgumentError("minimum_separation_ratio must be greater than one."))
    maximum_switches > 0 ||
        throw(ArgumentError("maximum_switches must be positive."))
    progress > zero(T) ||
        throw(ArgumentError("minimum_time_progress must be positive."))
    excursion >= zero(T) ||
        throw(ArgumentError("minimum_separation_excursion must be nonnegative."))
    resolved.scale_kind in (:absolute, :characteristic_length) ||
        throw(ArgumentError("unsupported automatic-switching threshold scale kind."))
    reference_scale > zero(T) ||
        throw(ArgumentError("threshold reference scale must be positive."))

    AutomaticSwitchingParameters{T}(
        enter,
        exit,
        ambiguity,
        ratio,
        Int(maximum_switches),
        progress,
        excursion,
        resolved.scale_kind,
        reference_scale,
    )
end

"""
    AutomaticSwitchingProgressState

Immutable history of the most recent successful automatic switch. It is used
only to certify later same-pair re-entry cycles; an absent state means that no
switch has yet completed.
"""
struct AutomaticSwitchingProgressState{T<:AbstractFloat}
    last_switch_time::T
    last_kind::Symbol
    last_pair::Tuple{Int,Int}
    last_separation::T
    consecutive_same_pair_switches::Int
end

"""
    AutomaticSwitchingProgressEvidence

Immutable evidence for one controller-level progress certification.
`same_pair_reentry` is true only for an entry following a successful exit of the
same unordered pair. The optional excursion safeguard is applied only then.
"""
struct AutomaticSwitchingProgressEvidence{T<:AbstractFloat}
    switch_kind::Symbol
    pair::Tuple{Int,Int}
    physical_time::T
    separation::T
    previous_switch_time::Union{Nothing,T}
    previous_kind::Union{Nothing,Symbol}
    previous_pair::Union{Nothing,Tuple{Int,Int}}
    elapsed_time::Union{Nothing,T}
    same_unordered_pair::Bool
    same_pair_reentry::Bool
    observed_separation_excursion::Union{Nothing,T}
    required_separation_excursion::T
    time_progress_satisfied::Bool
    separation_excursion_satisfied::Bool
    certified::Bool
    reason::Symbol
end

@inline _unordered_pair(pair::Tuple{<:Integer,<:Integer}) = minmax(Int(pair[1]), Int(pair[2]))

function _certify_automatic_switching_progress(
    state::Union{Nothing,AutomaticSwitchingProgressState{T}},
    switch_kind::Symbol,
    pair::Tuple{<:Integer,<:Integer},
    physical_time::T,
    separation::T,
    parameters::AutomaticSwitchingParameters,
) where {T<:AbstractFloat}
    switch_kind in (:entry, :exit) || throw(ArgumentError("switch_kind must be :entry or :exit."))
    all(isfinite, (physical_time, separation)) ||
        throw(ArgumentError("switch progress observables must be finite."))
    separation >= zero(T) || throw(ArgumentError("switch separation must be nonnegative."))
    canonical_pair = _unordered_pair(pair)

    previous_time = isnothing(state) ? nothing : state.last_switch_time
    previous_kind = isnothing(state) ? nothing : state.last_kind
    previous_pair = isnothing(state) ? nothing : state.last_pair
    elapsed = isnothing(state) ? nothing : physical_time - state.last_switch_time
    same_pair = !isnothing(state) && canonical_pair == state.last_pair
    same_pair_reentry = !isnothing(state) && switch_kind === :entry &&
        state.last_kind === :exit && same_pair
    observed_excursion = same_pair_reentry ? state.last_separation - separation : nothing
    time_ok = isnothing(elapsed) || elapsed >= parameters.minimum_time_progress
    excursion_ok = !same_pair_reentry || parameters.minimum_separation_excursion == zero(T) ||
        something(observed_excursion) >= parameters.minimum_separation_excursion
    certified = time_ok && excursion_ok
    reason = !time_ok ? :insufficient_time_progress :
        (!excursion_ok ? :insufficient_separation_excursion : :progress_certified)

    evidence = AutomaticSwitchingProgressEvidence{T}(
        switch_kind, canonical_pair, physical_time, separation, previous_time,
        previous_kind, previous_pair, elapsed, same_pair, same_pair_reentry,
        observed_excursion, T(parameters.minimum_separation_excursion), time_ok,
        excursion_ok, certified, reason,
    )
    next_count = same_pair && !isnothing(state) ? state.consecutive_same_pair_switches + 1 : 1
    next_state = AutomaticSwitchingProgressState{T}(
        physical_time, switch_kind, canonical_pair, separation, next_count,
    )
    evidence, next_state
end

"""
    AutomaticSwitchingFailure

Structured safe-termination record for the experimental automatic-switching
controller.

`reason` is a machine-readable symbol, while `message` provides a human-readable
explanation. `pair` is present when the failure concerns a particular selected
binary. Completed trajectory segments should remain available to callers even
when such a failure is recorded.
"""
struct AutomaticSwitchingFailure{T<:AbstractFloat}
    physical_time::T
    reason::Symbol
    message::String
    pair::Union{Nothing,Tuple{Int,Int}}
    progress_evidence::Union{Nothing,AutomaticSwitchingProgressEvidence{T}}
end

function AutomaticSwitchingFailure(
    physical_time::T,
    reason::Symbol,
    message::AbstractString;
    pair::Union{Nothing,Tuple{<:Integer,<:Integer}}=nothing,
    progress_evidence::Union{Nothing,AutomaticSwitchingProgressEvidence{T}}=nothing,
) where {T<:AbstractFloat}
    isfinite(physical_time) ||
        throw(ArgumentError("failure physical_time must be finite."))
    isempty(message) && throw(ArgumentError("failure message must not be empty."))
    validated_pair = if isnothing(pair)
        nothing
    else
        i, j, _ = _validate_pair(pair)
        (i, j)
    end
    AutomaticSwitchingFailure{T}(
        physical_time,
        reason,
        String(message),
        validated_pair,
        progress_evidence,
    )
end

"""
    RegularizationSwitchEvent

Immutable record of one experimental automatic entry into or exit from a
regularized segment.

`kind` is either `:entry` or `:exit`. Pair separations and radial separation
rates use the canonical unordered order `(1,2), (1,3), (2,3)`. The
`isolation_ratio` is the second-smallest separation divided by the smallest
separation at the event. `transition_diagnostics` records coordinate-handoff
residuals and invariant jumps.
"""
struct RegularizationSwitchEvent{T<:AbstractFloat,D}
    physical_time::T
    kind::Symbol
    pair::Tuple{Int,Int}
    separations::NTuple{3,T}
    radial_rates::NTuple{3,T}
    isolation_ratio::T
    transition_diagnostics::D

    function RegularizationSwitchEvent{T,D}(
        physical_time::T,
        kind::Symbol,
        pair::Tuple{Int,Int},
        separations::NTuple{3,T},
        radial_rates::NTuple{3,T},
        isolation_ratio::T,
        transition_diagnostics::D,
    ) where {T<:AbstractFloat,D}
        kind in (:entry, :exit) ||
            throw(ArgumentError("switch-event kind must be :entry or :exit."))
        i, j, _ = _validate_pair(pair)
        isfinite(physical_time) ||
            throw(ArgumentError("switch-event physical_time must be finite."))
        all(isfinite, separations) ||
            throw(ArgumentError("switch-event separations must be finite."))
        all(>(zero(T)), separations) ||
            throw(ArgumentError("switch-event separations must be positive."))
        all(isfinite, radial_rates) ||
            throw(ArgumentError("switch-event radial rates must be finite."))
        isfinite(isolation_ratio) && isolation_ratio >= one(T) ||
            throw(ArgumentError("switch-event isolation_ratio must be finite and at least one."))

        new{T,D}(
            physical_time,
            kind,
            (i, j),
            separations,
            radial_rates,
            isolation_ratio,
            transition_diagnostics,
        )
    end
end

function RegularizationSwitchEvent(
    physical_time::T,
    kind::Symbol,
    pair::Tuple{<:Integer,<:Integer},
    separations::NTuple{3,T},
    radial_rates::NTuple{3,T},
    isolation_ratio::T,
    transition_diagnostics::D,
) where {T<:AbstractFloat,D}
    i, j, _ = _validate_pair(pair)
    RegularizationSwitchEvent{T,D}(
        physical_time,
        kind,
        (i, j),
        separations,
        radial_rates,
        isolation_ratio,
        transition_diagnostics,
    )
end

const _CANONICAL_BINARY_PAIRS = ((1, 2), (1, 3), (2, 3))

"""
    PairObservables

Solver-independent geometric observables for the three unordered binary pairs
in the canonical order `(1,2)`, `(1,3)`, `(2,3)`.

`separations` contains the three pair distances. `radial_rates` contains
`dot(rᵢ-rⱼ, vᵢ-vⱼ) / separation` away from exact collision. At an exact
collision the corresponding radial rate is stored as zero and the matching
entry of `collisions` is `true`; callers must inspect that flag rather than
interpreting the zero as a physical radial rate.

`order` contains the canonical pair indices sorted by increasing separation,
with canonical pair order used to break exact ties. `isolation_ratio` is the
second-smallest separation divided by the smallest. It is infinite for one
exactly colliding isolated pair and one when the two smallest separations are
both zero.
"""
struct PairObservables{T<:AbstractFloat}
    separations::NTuple{3,T}
    radial_rates::NTuple{3,T}
    collisions::NTuple{3,Bool}
    order::NTuple{3,Int}
    closest_pair::Tuple{Int,Int}
    second_closest_pair::Tuple{Int,Int}
    isolation_ratio::T
end

@inline function _pair_separation_and_radial_rate(
    u::AbstractVector{T},
    pair::Tuple{Int,Int},
) where {T<:AbstractFloat}
    i, j = pair
    relative_position = body_position(u, i) - body_position(u, j)
    relative_velocity = velocity(u, i) - velocity(u, j)
    separation = norm(relative_position)
    collision = iszero(separation)
    radial_rate = collision ? zero(T) : dot(relative_position, relative_velocity) / separation
    separation, radial_rate, collision
end

"""
    pair_observables(u)

Compute separation, radial separation rate, collision flags, deterministic
separation ordering, and pair-isolation ratio for all three unordered binary
pairs in solver state `u`.

This function is algebraic and independent of ODE solvers, save grids, masses,
and the gravitational constant. Exact collisions are represented safely using
`collisions`; no division by zero is performed.
"""
function pair_observables(u::AbstractVector{T}) where {T<:AbstractFloat}
    validate_state(u)

    first = _pair_separation_and_radial_rate(u, _CANONICAL_BINARY_PAIRS[1])
    second = _pair_separation_and_radial_rate(u, _CANONICAL_BINARY_PAIRS[2])
    third = _pair_separation_and_radial_rate(u, _CANONICAL_BINARY_PAIRS[3])

    separations = (first[1], second[1], third[1])
    radial_rates = (first[2], second[2], third[2])
    collisions = (first[3], second[3], third[3])

    ordered = sortperm(1:3; by=index -> (separations[index], index))
    order = (ordered[1], ordered[2], ordered[3])
    smallest = separations[order[1]]
    second_smallest = separations[order[2]]
    isolation_ratio = if iszero(smallest)
        iszero(second_smallest) ? one(T) : T(Inf)
    else
        second_smallest / smallest
    end

    PairObservables{T}(
        separations,
        radial_rates,
        collisions,
        order,
        _CANONICAL_BINARY_PAIRS[order[1]],
        _CANONICAL_BINARY_PAIRS[order[2]],
        isolation_ratio,
    )
end

"""Return pair separations in canonical order `(1,2)`, `(1,3)`, `(2,3)`."""
pair_separations(u::AbstractVector{<:AbstractFloat}) = pair_observables(u).separations

"""
Return pair radial separation rates in canonical order `(1,2)`, `(1,3)`,
`(2,3)`. Use [`pair_observables`](@ref) when exact-collision flags are needed.
"""
pair_radial_rates(u::AbstractVector{<:AbstractFloat}) = pair_observables(u).radial_rates


"""
    AutomaticSwitchingCompetitionEvidence

Immutable, precision-generic quantitative evidence describing competition
between the three canonical binary pairs during one automatic-switching policy
evaluation.

The record is derived entirely from retained [`PairObservables`](@ref), resolved
thresholds, and the current candidate or selected pair. Signed entry margins use
`separation - enter_threshold`; `exit_margin` uses
`selected_separation - exit_threshold`. `relative_separation_gap` is `nothing`
when the closest separation is zero, avoiding division by zero. Candidate pairs
remain in canonical pair order. AS-4a records only `:algebraic` provenance;
continuous-crossing provenance is reserved for AS-4b.
"""
struct AutomaticSwitchingCompetitionEvidence{T<:AbstractFloat,C<:Tuple}
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
    candidate_pairs::C
    candidate_is_closest::Union{Nothing,Bool}
    candidate_tied_for_closest::Union{Nothing,Bool}
    crossing_provenance::Symbol

    function AutomaticSwitchingCompetitionEvidence{T,C}(
        closest_index::Int,
        second_index::Int,
        closest_pair::Tuple{Int,Int},
        second_pair::Tuple{Int,Int},
        closest_separation::T,
        second_separation::T,
        absolute_separation_gap::T,
        relative_separation_gap::Union{Nothing,T},
        exact_closest_tie::Bool,
        entry_margins::NTuple{3,T},
        exit_margin::Union{Nothing,T},
        ambiguity_margin::T,
        isolation_ratio_margin::T,
        candidate_pairs::C,
        candidate_is_closest::Union{Nothing,Bool},
        candidate_tied_for_closest::Union{Nothing,Bool},
        crossing_provenance::Symbol,
    ) where {T<:AbstractFloat,C<:Tuple}
        1 <= closest_index <= 3 ||
            throw(ArgumentError("closest_index must be in 1:3."))
        1 <= second_index <= 3 ||
            throw(ArgumentError("second_index must be in 1:3."))
        closest_index != second_index ||
            throw(ArgumentError("closest_index and second_index must differ."))
        _validate_pair(closest_pair)
        _validate_pair(second_pair)
        all(pair -> begin
            i, j, _ = _validate_pair(pair)
            i < j
        end, candidate_pairs) ||
            throw(ArgumentError("candidate_pairs must contain canonical unordered pairs."))
        length(unique(candidate_pairs)) == length(candidate_pairs) ||
            throw(ArgumentError("candidate_pairs must not contain duplicates."))
        crossing_provenance in (
            :algebraic,
            :certified_cartesian_entry,
            :certified_regularized_exit,
            :certified_nonselected_pair_crossing,
        ) || throw(ArgumentError("unsupported crossing provenance."))
        closest_separation >= zero(T) && isfinite(closest_separation) ||
            throw(ArgumentError("closest separation must be finite and nonnegative."))
        second_separation >= zero(T) && isfinite(second_separation) ||
            throw(ArgumentError("second separation must be finite and nonnegative."))
        absolute_separation_gap >= zero(T) && isfinite(absolute_separation_gap) ||
            throw(ArgumentError("absolute separation gap must be finite and nonnegative."))
        if !isnothing(relative_separation_gap)
            relative_separation_gap >= zero(T) && isfinite(relative_separation_gap) ||
                throw(ArgumentError("relative separation gap must be finite and nonnegative."))
        end
        all(isfinite, entry_margins) ||
            throw(ArgumentError("entry margins must be finite."))
        isnothing(exit_margin) || isfinite(exit_margin) ||
            throw(ArgumentError("exit margin must be finite when present."))
        isfinite(ambiguity_margin) ||
            throw(ArgumentError("ambiguity margin must be finite."))
        isfinite(isolation_ratio_margin) || isinf(isolation_ratio_margin) ||
            throw(ArgumentError("isolation-ratio margin must be finite or infinite."))
        if isnothing(candidate_is_closest) != isnothing(candidate_tied_for_closest)
            throw(ArgumentError("candidate competition flags must both be present or both be nothing."))
        end

        new{T,C}(
            closest_index,
            second_index,
            closest_pair,
            second_pair,
            closest_separation,
            second_separation,
            absolute_separation_gap,
            relative_separation_gap,
            exact_closest_tie,
            entry_margins,
            exit_margin,
            ambiguity_margin,
            isolation_ratio_margin,
            candidate_pairs,
            candidate_is_closest,
            candidate_tied_for_closest,
            crossing_provenance,
        )
    end
end


"""
    AutomaticSwitchingDecisionEvidence

Immutable, precision-generic evidence retained for one algebraic automatic-
switching policy evaluation.

The record preserves the policy phase, all pair observables, the effective
resolved thresholds and scale evidence, the entry-candidate mask, the selected/candidate pair,
and immutable quantitative pair-competition evidence. It is sufficient to explain the decision without
recomputing hidden policy state. `scale_kind` is `:absolute` or
`:characteristic_length`; `reference_scale` is the immutable scale used to
resolve the physical thresholds.
"""
struct AutomaticSwitchingDecisionEvidence{T<:AbstractFloat,C<:Tuple}
    phase::Symbol
    scale_kind::Symbol
    reference_scale::T
    separations::NTuple{3,T}
    radial_rates::NTuple{3,T}
    collisions::NTuple{3,Bool}
    order::NTuple{3,Int}
    isolation_ratio::T
    enter_threshold::T
    exit_threshold::T
    ambiguity_threshold::T
    minimum_separation_ratio::T
    candidate_mask::NTuple{3,Bool}
    candidate_count::Int
    candidate_pair::Union{Nothing,Tuple{Int,Int}}
    selected_pair::Union{Nothing,Tuple{Int,Int}}
    selected_index::Union{Nothing,Int}
    second_index::Int
    competition::AutomaticSwitchingCompetitionEvidence{T,C}

    function AutomaticSwitchingDecisionEvidence{T,C}(
        phase::Symbol,
        scale_kind::Symbol,
        reference_scale::T,
        separations::NTuple{3,T},
        radial_rates::NTuple{3,T},
        collisions::NTuple{3,Bool},
        order::NTuple{3,Int},
        isolation_ratio::T,
        enter_threshold::T,
        exit_threshold::T,
        ambiguity_threshold::T,
        minimum_separation_ratio::T,
        candidate_mask::NTuple{3,Bool},
        candidate_count::Int,
        candidate_pair::Union{Nothing,Tuple{Int,Int}},
        selected_pair::Union{Nothing,Tuple{Int,Int}},
        selected_index::Union{Nothing,Int},
        second_index::Int,
        competition::AutomaticSwitchingCompetitionEvidence{T,C},
    ) where {T<:AbstractFloat,C<:Tuple}
        phase in (:entry, :exit) ||
            throw(ArgumentError("decision-evidence phase must be :entry or :exit."))
        scale_kind in (:absolute, :characteristic_length) ||
            throw(ArgumentError("unsupported decision-evidence scale_kind."))
        isfinite(reference_scale) && reference_scale > zero(T) ||
            throw(ArgumentError("decision-evidence reference_scale must be finite and positive."))
        sort(collect(order)) == [1, 2, 3] ||
            throw(ArgumentError("decision-evidence order must be a permutation of 1:3."))
        1 <= second_index <= 3 ||
            throw(ArgumentError("decision-evidence second_index must be in 1:3."))
        candidate_count == count(identity, candidate_mask) ||
            throw(ArgumentError("candidate_count must match candidate_mask."))
        0 <= candidate_count <= 3 ||
            throw(ArgumentError("candidate_count must be between zero and three."))
        if !isnothing(candidate_pair)
            _validate_pair(candidate_pair)
        end
        if !isnothing(selected_pair)
            _validate_pair(selected_pair)
        end
        if !isnothing(selected_index)
            1 <= selected_index <= 3 ||
                throw(ArgumentError("selected_index must be in 1:3."))
        end
        all(isfinite, separations) ||
            throw(ArgumentError("decision-evidence separations must be finite."))
        all(isfinite, radial_rates) ||
            throw(ArgumentError("decision-evidence radial rates must be finite."))
        isfinite(isolation_ratio) || isinf(isolation_ratio) ||
            throw(ArgumentError("decision-evidence isolation ratio must be finite or infinite."))
        all(isfinite, (
            enter_threshold,
            exit_threshold,
            ambiguity_threshold,
            minimum_separation_ratio,
        )) || throw(ArgumentError("decision-evidence thresholds must be finite."))

        new{T,C}(
            phase,
            scale_kind,
            reference_scale,
            separations,
            radial_rates,
            collisions,
            order,
            isolation_ratio,
            enter_threshold,
            exit_threshold,
            ambiguity_threshold,
            minimum_separation_ratio,
            candidate_mask,
            candidate_count,
            candidate_pair,
            selected_pair,
            selected_index,
            second_index,
            competition,
        )
    end
end

"""
    AutomaticSwitchingDecision

Solver-independent decision returned by the experimental automatic-switching
policy.

`action` is one of `:none`, `:enter`, `:exit`, or `:failure`. `pair` identifies
the affected ordered pair when applicable. `reason` is a machine-readable
explanation suitable for diagnostics and tests. Algebraic entry and exit policy
functions also attach [`AutomaticSwitchingDecisionEvidence`](@ref), allowing
every outcome to be audited without recomputing hidden policy state. The
three-argument constructor remains available and records `nothing` evidence for
non-policy helper decisions.
"""
struct AutomaticSwitchingDecision
    action::Symbol
    pair::Union{Nothing,Tuple{Int,Int}}
    reason::Symbol
    evidence::Union{Nothing,AutomaticSwitchingDecisionEvidence}

    function AutomaticSwitchingDecision(
        action::Symbol,
        pair::Union{Nothing,Tuple{<:Integer,<:Integer}},
        reason::Symbol,
        evidence::Union{Nothing,AutomaticSwitchingDecisionEvidence}=nothing,
    )
        action in (:none, :enter, :exit, :failure) ||
            throw(ArgumentError("decision action must be :none, :enter, :exit, or :failure."))
        validated_pair = if isnothing(pair)
            nothing
        else
            i, j, _ = _validate_pair(pair)
            (i, j)
        end
        action in (:enter, :exit) && isnothing(validated_pair) &&
            throw(ArgumentError("entry and exit decisions require a selected pair."))
        new(action, validated_pair, reason, evidence)
    end
end

@inline function _canonical_pair_index(pair::Tuple{<:Integer,<:Integer})
    i, j, _ = _validate_pair(pair)
    unordered = i < j ? (i, j) : (j, i)
    index = findfirst(==(unordered), _CANONICAL_BINARY_PAIRS)
    isnothing(index) && throw(ArgumentError("invalid binary pair."))
    index
end

@inline _none_decision(reason::Symbol=:no_switch) =
    AutomaticSwitchingDecision(:none, nothing, reason)
@inline _failure_decision(reason::Symbol, pair=nothing) =
    AutomaticSwitchingDecision(:failure, pair, reason)

@inline function _entry_candidate_mask(
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters,
) where {T<:AbstractFloat}
    ntuple(3) do index
        observables.separations[index] <= parameters.enter_threshold &&
            observables.radial_rates[index] < zero(T)
    end
end

function _competition_evidence(
    phase::Symbol,
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters;
    candidate_mask::NTuple{3,Bool}=(false, false, false),
    candidate_pair::Union{Nothing,Tuple{Int,Int}}=nothing,
    selected_index::Union{Nothing,Int}=nothing,
    crossing_provenance::Symbol=:algebraic,
) where {T<:AbstractFloat}
    phase in (:entry, :exit) ||
        throw(ArgumentError("competition-evidence phase must be :entry or :exit."))
    closest_index = observables.order[1]
    second_index = observables.order[2]
    closest_separation = observables.separations[closest_index]
    second_separation = observables.separations[second_index]
    absolute_gap = second_separation - closest_separation
    relative_gap = iszero(closest_separation) ? nothing : absolute_gap / closest_separation
    entry_margins = ntuple(3) do index
        observables.separations[index] - T(parameters.enter_threshold)
    end
    exit_margin = isnothing(selected_index) ? nothing :
        observables.separations[selected_index] - T(parameters.exit_threshold)
    candidate_pairs = Tuple(
        _CANONICAL_BINARY_PAIRS[index] for index in 1:3 if candidate_mask[index]
    )
    candidate_index = isnothing(candidate_pair) ? nothing : _canonical_pair_index(candidate_pair)
    candidate_is_closest = isnothing(candidate_index) ? nothing : candidate_index == closest_index
    candidate_tied_for_closest = isnothing(candidate_index) ? nothing :
        observables.separations[candidate_index] == closest_separation

    AutomaticSwitchingCompetitionEvidence{T,typeof(candidate_pairs)}(
        closest_index,
        second_index,
        _CANONICAL_BINARY_PAIRS[closest_index],
        _CANONICAL_BINARY_PAIRS[second_index],
        closest_separation,
        second_separation,
        absolute_gap,
        relative_gap,
        closest_separation == second_separation,
        entry_margins,
        exit_margin,
        second_separation - T(parameters.ambiguity_threshold),
        observables.isolation_ratio - T(parameters.minimum_separation_ratio),
        candidate_pairs,
        candidate_is_closest,
        candidate_tied_for_closest,
        crossing_provenance,
    )
end

function _decision_evidence(
    phase::Symbol,
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters;
    candidate_mask::NTuple{3,Bool}=(false, false, false),
    candidate_pair::Union{Nothing,Tuple{Int,Int}}=nothing,
    selected_pair::Union{Nothing,Tuple{Int,Int}}=nothing,
    selected_index::Union{Nothing,Int}=nothing,
    crossing_provenance::Symbol=:algebraic,
) where {T<:AbstractFloat}
    competition = _competition_evidence(
        phase,
        observables,
        parameters;
        candidate_mask,
        candidate_pair,
        selected_index,
        crossing_provenance,
    )
    AutomaticSwitchingDecisionEvidence{T,typeof(competition.candidate_pairs)}(
        phase,
        parameters.threshold_scale_kind,
        T(parameters.threshold_reference_scale),
        observables.separations,
        observables.radial_rates,
        observables.collisions,
        observables.order,
        observables.isolation_ratio,
        T(parameters.enter_threshold),
        T(parameters.exit_threshold),
        T(parameters.ambiguity_threshold),
        T(parameters.minimum_separation_ratio),
        candidate_mask,
        count(identity, candidate_mask),
        candidate_pair,
        selected_pair,
        selected_index,
        observables.order[2],
        competition,
    )
end

@inline _decision(action, pair, reason, evidence) =
    AutomaticSwitchingDecision(action, pair, reason, evidence)

"""
    automatic_entry_decision(observables, parameters)

Apply the experimental automatic-entry policy to already computed
[`PairObservables`](@ref).

Entry is permitted only for one uniquely eligible pair whose separation is at
or below `enter_threshold` and whose radial rate is negative. The pair must be
the closest pair, the second-smallest separation must exceed
`ambiguity_threshold`, and the isolation ratio must meet
`minimum_separation_ratio`.

Exact collisions and ambiguous close-pair configurations return structured
`:failure` decisions. This function is algebraic: it performs no integration,
root finding, or threshold-crossing location.
"""
function automatic_entry_decision(
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters,
    ;
    crossing_provenance::Symbol=:algebraic,
) where {T<:AbstractFloat}
    candidate_mask = _entry_candidate_mask(observables, parameters)
    candidate_indices = findall(identity, candidate_mask)
    candidate_pair = length(candidate_indices) == 1 ?
        _CANONICAL_BINARY_PAIRS[only(candidate_indices)] : nothing
    evidence = _decision_evidence(
        :entry,
        observables,
        parameters;
        candidate_mask,
        candidate_pair,
        crossing_provenance,
    )

    any(observables.collisions) &&
        return _decision(:failure, observables.closest_pair, :collision_state, evidence)

    isempty(candidate_indices) &&
        return _decision(:none, nothing, :no_entry_candidate, evidence)
    length(candidate_indices) > 1 &&
        return _decision(:failure, nothing, :simultaneous_entry_candidates, evidence)

    candidate_index = only(candidate_indices)
    candidate_pair = _CANONICAL_BINARY_PAIRS[candidate_index]
    candidate_index == observables.order[1] ||
        return _decision(:failure, candidate_pair, :candidate_not_closest, evidence)

    second_index = observables.order[2]
    observables.separations[second_index] <= parameters.ambiguity_threshold &&
        return _decision(:failure, candidate_pair, :ambiguous_close_pairs, evidence)
    observables.isolation_ratio < parameters.minimum_separation_ratio &&
        return _decision(:failure, candidate_pair, :insufficient_pair_isolation, evidence)

    _decision(:enter, candidate_pair, :unique_approaching_pair, evidence)
end

"""
    automatic_exit_decision(observables, parameters, pair)

Apply the experimental automatic-exit policy for the currently regularized
ordered `pair`.

Exit is permitted only when the selected pair is still the closest isolated
pair, its separation is at or above `exit_threshold`, and its radial rate is
positive. Exact collision of the selected pair produces `:none`, because a
Levi-Civita segment is expected to pass safely through that state. Collision of
another pair, loss of the selected pair hierarchy, or inadequate isolation
produces a structured `:failure` decision.

This function is algebraic and performs no integration or event location.
"""
function automatic_exit_decision(
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters,
    pair::Tuple{<:Integer,<:Integer},
    ;
    crossing_provenance::Symbol=:algebraic,
) where {T<:AbstractFloat}
    selected_index = _canonical_pair_index(pair)
    selected_pair = (Int(pair[1]), Int(pair[2]))
    evidence = _decision_evidence(
        :exit,
        observables,
        parameters;
        selected_pair,
        selected_index,
        crossing_provenance,
    )

    for index in 1:3
        if observables.collisions[index] && index != selected_index
            return _decision(
                :failure,
                selected_pair,
                :nonselected_pair_collision,
                evidence,
            )
        end
    end
    observables.collisions[selected_index] &&
        return _decision(:none, selected_pair, :selected_pair_collision, evidence)

    selected_index == observables.order[1] ||
        return _decision(:failure, selected_pair, :selected_pair_lost, evidence)

    second_index = observables.order[2]
    observables.separations[second_index] <= parameters.ambiguity_threshold &&
        return _decision(:failure, selected_pair, :ambiguous_close_pairs, evidence)
    observables.isolation_ratio < parameters.minimum_separation_ratio &&
        return _decision(:failure, selected_pair, :insufficient_pair_isolation, evidence)

    selected_separation = observables.separations[selected_index]
    selected_rate = observables.radial_rates[selected_index]
    if selected_separation >= parameters.exit_threshold && selected_rate > zero(T)
        return _decision(:exit, selected_pair, :isolated_receding_pair, evidence)
    end

    _decision(:none, selected_pair, :exit_condition_not_met, evidence)
end

"""
    CartesianEntryLocationResult

Result of one experimental Cartesian propagation performed while searching for
an inward crossing of `enter_threshold`.

`status` is one of `:completed`, `:entry`, or `:failure`. `simulation` retains
the complete Cartesian [`SimulationResult`](@ref). `physical_time` and `state`
identify the final time and Cartesian state of this propagation. `decision` and
`observables` record the automatic-switching policy evaluation at that state.

This type represents only Cartesian entry-event location. It does not start a
regularized segment or run the full switching controller.
"""
struct CartesianEntryLocationResult{T<:AbstractFloat,S,R,O}
    status::Symbol
    physical_time::T
    state::S
    simulation::R
    decision::AutomaticSwitchingDecision
    observables::O

    function CartesianEntryLocationResult(
        status::Symbol,
        physical_time::T,
        state::S,
        simulation::R,
        decision::AutomaticSwitchingDecision,
        observables::O,
    ) where {T<:AbstractFloat,S,R,O}
        status in (:completed, :entry, :failure) ||
            throw(ArgumentError("Cartesian entry-location status must be :completed, :entry, or :failure."))
        isfinite(physical_time) ||
            throw(ArgumentError("Cartesian entry-location physical_time must be finite."))
        status === :entry && decision.action !== :enter &&
            throw(ArgumentError("an :entry result requires an :enter decision."))
        status === :failure && decision.action !== :failure &&
            throw(ArgumentError("a :failure result requires a :failure decision."))
        status === :completed && decision.action !== :none &&
            throw(ArgumentError("a :completed result requires a :none decision."))
        new{T,S,R,O}(status, physical_time, state, simulation, decision, observables)
    end
end

@inline function _certified_entry_decision(
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters,
    pair::Tuple{Int,Int},
) where {T<:AbstractFloat}
    decision = automatic_entry_decision(
        observables,
        parameters;
        crossing_provenance=:certified_cartesian_entry,
    )
    decision.action !== :none && return decision

    event_index = _canonical_pair_index(pair)
    event_rate = observables.radial_rates[event_index]
    if !observables.collisions[event_index] && event_rate < zero(event_rate)
        if event_index != observables.order[1]
            return _decision(:failure, pair, :candidate_not_closest, decision.evidence)
        end

        second_index = observables.order[2]
        if observables.separations[second_index] <= parameters.ambiguity_threshold
            return _decision(:failure, pair, :ambiguous_close_pairs, decision.evidence)
        elseif observables.isolation_ratio < parameters.minimum_separation_ratio
            return _decision(
                :failure,
                pair,
                :insufficient_pair_isolation,
                decision.evidence,
            )
        end

        return _decision(
            :enter,
            pair,
            :certified_inward_threshold_crossing,
            decision.evidence,
        )
    end

    _decision(:failure, pair, :entry_condition_not_met, decision.evidence)
end


"""
    locate_cartesian_entry_event(system, u0, tspan, parameters; kwargs...)

Propagate one ordinary Cartesian segment and locate the earliest inward crossing
of `parameters.enter_threshold` using continuous solver root finding.

The returned [`CartesianEntryLocationResult`](@ref) has status:

- `:completed` when the segment reaches the end of `tspan` without a crossing;
- `:entry` when a unique isolated approaching pair is eligible for
  regularization at the located crossing;
- `:failure` when the located state is ambiguous or otherwise unsafe.

Event detection is independent of `saveat`; that keyword controls only saved
output. Initial states at or inside `enter_threshold` are rejected because the
first experimental controller must not guess whether such a state lies before
or after pericentre. Remaining keywords are forwarded to [`simulate`](@ref).

This function does not start a Levi-Civita segment and does not alter the public
behavior of `simulate`.
"""
function locate_cartesian_entry_event(
    system::ThreeBodySystem,
    u0::AbstractVector{<:AbstractFloat},
    tspan::Tuple{<:Real,<:Real},
    parameters::AutomaticSwitchingParameters;
    solver=:accurate,
    reltol::Union{Nothing,Real}=nothing,
    abstol::Union{Nothing,Real}=nothing,
    saveat=nothing,
    maxiters::Integer=10^7,
    precision::Integer=256,
    kwargs...,
)
    initial_observables = pair_observables(u0)
    if minimum(initial_observables.separations) <= parameters.enter_threshold
        decision = _failure_decision(
            :initial_state_inside_entry_threshold,
            initial_observables.closest_pair,
        )
        T = eltype(u0)
        return CartesianEntryLocationResult(
            :failure,
            T(first(tspan)),
            copy(u0),
            nothing,
            decision,
            initial_observables,
        )
    end

    simulation = simulate(
        system,
        u0,
        tspan;
        solver,
        reltol,
        abstol,
        saveat,
        maxiters,
        precision,
        close_approach_threshold=parameters.enter_threshold,
        close_approach_policy=:terminate,
        kwargs...,
    )

    if !terminated_by_close_approach(simulation)
        physical_time = last(simulation.solution.prob.tspan)
        state = collect(simulation(physical_time))
        observables = pair_observables(state)
        decision = _none_decision(:entry_threshold_not_reached)
        return CartesianEntryLocationResult(
            :completed,
            physical_time,
            state,
            simulation,
            decision,
            observables,
        )
    end

    isempty(simulation.close_approach_events) &&
        error("Cartesian entry search terminated without recording a close-approach event.")
    event = first(simulation.close_approach_events)
    physical_time = event.time
    state = collect(simulation(physical_time))
    observables = pair_observables(state)
    decision = _certified_entry_decision(observables, parameters, event.pair)

    if decision.action === :enter
        return CartesianEntryLocationResult(
            :entry,
            physical_time,
            state,
            simulation,
            decision,
            observables,
        )
    elseif decision.action === :failure
        return CartesianEntryLocationResult(
            :failure,
            physical_time,
            state,
            simulation,
            decision,
            observables,
        )
    end

    failure = _decision(
        :failure,
        event.pair,
        :entry_condition_not_met,
        decision.evidence,
    )
    CartesianEntryLocationResult(
        :failure,
        physical_time,
        state,
        simulation,
        failure,
        observables,
    )
end


"""
    RegularizedExitLocationResult

Result of one perturbed planar Levi-Civita propagation performed while
searching for the first outward crossing of `exit_threshold` by an explicitly
selected ordered pair.

`status` is one of `:completed`, `:exit`, or `:failure`. `regularized_result`
retains the full fictitious-time numerical solution, while `physical_time`,
`fictitious_time`, and `state` identify the terminal reconstructed Cartesian
state. This type represents only one regularized segment; it does not resume
Cartesian propagation or run the full switching controller.
"""
struct RegularizedExitLocationResult{T<:AbstractFloat,S,P,R,O}
    status::Symbol
    physical_time::T
    fictitious_time::T
    state::S
    problem::P
    regularized_result::R
    decision::AutomaticSwitchingDecision
    observables::O

    function RegularizedExitLocationResult(
        status::Symbol,
        physical_time::T,
        fictitious_time::T,
        state::S,
        problem::P,
        regularized_result::R,
        decision::AutomaticSwitchingDecision,
        observables::O,
    ) where {T<:AbstractFloat,S,P,R,O}
        status in (:completed, :exit, :failure) ||
            throw(ArgumentError("regularized exit-location status must be :completed, :exit, or :failure."))
        all(isfinite, (physical_time, fictitious_time)) ||
            throw(ArgumentError("regularized exit-location times must be finite."))
        status === :exit && decision.action !== :exit &&
            throw(ArgumentError("an :exit result requires an :exit decision."))
        status === :failure && decision.action !== :failure &&
            throw(ArgumentError("a :failure result requires a :failure decision."))
        status === :completed && decision.action !== :none &&
            throw(ArgumentError("a :completed result requires a :none decision."))
        new{T,S,P,R,O}(
            status, physical_time, fictitious_time, state, problem,
            regularized_result, decision, observables,
        )
    end
end

@inline function _certified_exit_decision(
    observables::PairObservables{T},
    parameters::AutomaticSwitchingParameters,
    pair::Tuple{Int,Int},
) where {T<:AbstractFloat}
    decision = automatic_exit_decision(
        observables,
        parameters,
        pair;
        crossing_provenance=:certified_regularized_exit,
    )
    decision.action !== :none && return decision

    selected_index = _canonical_pair_index(pair)
    if decision.reason === :exit_condition_not_met &&
       observables.radial_rates[selected_index] > zero(T)
        return _decision(
            :exit,
            pair,
            :certified_outward_threshold_crossing,
            decision.evidence,
        )
    end

    _decision(:failure, pair, :exit_condition_not_met, decision.evidence)
end

"""
    locate_regularized_exit_event(system, state, pair, entry_time, target_time,
                                  parameters; kwargs...)

Propagate one explicitly selected planar binary with the existing perturbed
Levi-Civita equations and locate its first outward crossing of
`parameters.exit_threshold`.

The returned [`RegularizedExitLocationResult`](@ref) has status:

- `:completed` when physical `target_time` is reached before an exit crossing;
- `:exit` when the selected pair crosses outward while receding and remains the
  closest sufficiently isolated pair;
- `:failure` when the initial state or located state is unsafe or ambiguous.

The crossing condition is evaluated directly from the regularized binary
position, for which the physical separation is `|u|^2`. Continuous root
finding therefore remains well behaved through binary collision and is
independent of `saveat`; that keyword controls only stored fictitious-time
output. Physical-time targeting is used only to determine the maximum
fictitious-time interval corresponding to `target_time`.

This function does not resume Cartesian propagation and does not implement the
full automatic-switching controller.
"""
function locate_regularized_exit_event(
    system::ThreeBodySystem,
    state::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer},
    entry_time::Real,
    target_time::Real,
    parameters::AutomaticSwitchingParameters;
    branch::Integer=1,
    initial_step::Real=1,
    tolerance=nothing,
    max_iterations::Integer=256,
    algorithm=Vern9(),
    reltol=nothing,
    abstol=nothing,
    saveat=nothing,
    kwargs...,
)
    validate_state(state)
    i, j, _ = _validate_pair(pair)
    T = float(promote_type(
        eltype(system.masses), eltype(state), typeof(entry_time), typeof(target_time),
    ))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    entry = Vector{T}(state)
    t_entry = T(entry_time)
    t_target = T(target_time)
    all(isfinite, (t_entry, t_target)) ||
        throw(ArgumentError("entry_time and target_time must be finite."))
    t_target > t_entry ||
        throw(ArgumentError("target_time must be greater than entry_time."))

    initial_observables = pair_observables(entry)
    selected_index = _canonical_pair_index((i, j))
    if initial_observables.collisions[selected_index]
        decision = _failure_decision(:initial_selected_pair_collision, (i, j))
        return RegularizedExitLocationResult(
            :failure, t_entry, zero(T), entry, nothing, nothing,
            decision, initial_observables,
        )
    end
    if initial_observables.separations[selected_index] >= parameters.exit_threshold
        decision = _failure_decision(:initial_state_at_or_outside_exit_threshold, (i, j))
        return RegularizedExitLocationResult(
            :failure, t_entry, zero(T), entry, nothing, nothing,
            decision, initial_observables,
        )
    end

    problem = PerturbedLeviCivitaProblem(
        converted_system, entry, (i, j); branch=branch, initial_time=t_entry,
    )

    step = abs(T(initial_step))
    isfinite(step) && step > zero(T) ||
        throw(ArgumentError("initial_step must be finite and positive."))
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))
    tol = isnothing(tolerance) ? sqrt(eps(T)) : T(tolerance)
    isfinite(tol) && tol > zero(T) ||
        throw(ArgumentError("tolerance must be finite and positive."))

    located_s = Ref{Union{Nothing,T}}(nothing)
    function condition(y, _s, _integrator)
        y[1] * y[1] + y[2] * y[2] - parameters.exit_threshold
    end
    function affect_exit!(integrator)
        located_s[] = T(integrator.t)
        SciMLBase.terminate!(integrator)
    end
    callback = SciMLBase.ContinuousCallback(
        condition, affect_exit!, nothing; save_positions=(true, true),
    )

    function final_integration(endpoint_s)
        if isnothing(saveat)
            integrate_perturbed_levi_civita(
                problem, (zero(T), endpoint_s);
                algorithm=algorithm, reltol=reltol, abstol=abstol, kwargs...,
            )
        else
            integrate_perturbed_levi_civita(
                problem, (zero(T), endpoint_s);
                algorithm=algorithm, reltol=reltol, abstol=abstol,
                saveat=saveat, kwargs...,
            )
        end
    end

    search_result = nothing
    search_limit = step
    target_s = nothing

    for _ in 1:max_iterations
        located_s[] = nothing
        search_result = integrate_perturbed_levi_civita(
            problem, (zero(T), search_limit);
            algorithm=algorithm, reltol=reltol, abstol=abstol,
            callback=callback, dense=true, save_everystep=true, kwargs...,
        )

        if !isnothing(located_s[])
            break
        end

        terminal_time = T(search_result.solution(search_limit)[14])
        if terminal_time >= t_target
            left_s = zero(T)
            right_s = search_limit
            for _ in 1:max_iterations
                midpoint_s = (left_s + right_s) / T(2)
                midpoint_time = T(search_result.solution(midpoint_s)[14])
                time_scale = max(one(T), abs(t_target))
                s_scale = max(one(T), abs(left_s), abs(right_s), abs(midpoint_s))
                time_converged = abs(midpoint_time - t_target) <= tol * time_scale
                bracket_converged = abs(right_s - left_s) <= tol * s_scale
                if time_converged && bracket_converged
                    target_s = midpoint_s
                    break
                end
                if midpoint_time < t_target
                    left_s = midpoint_s
                else
                    right_s = midpoint_s
                end
            end
            isnothing(target_s) && (target_s = (left_s + right_s) / T(2))
            break
        end

        search_limit *= T(2)
        isfinite(search_limit) || throw(ErrorException(
            "Fictitious-time search interval overflowed before exit or target_time.",
        ))
    end

    if isnothing(located_s[]) && isnothing(target_s)
        throw(ErrorException(
            "Unable to locate an exit crossing or target physical time within max_iterations expansions.",
        ))
    end

    if !isnothing(target_s)
        terminal_s = something(target_s)
        regularized_result = final_integration(terminal_s)
        terminal = perturbed_levi_civita_state(regularized_result, terminal_s)
        terminal_state = Vector{T}(terminal.physical_state)
        observables = pair_observables(terminal_state)
        decision = automatic_exit_decision(observables, parameters, (i, j))
        if decision.action === :failure
            return RegularizedExitLocationResult(
                :failure, T(terminal.physical_time), terminal_s, terminal_state,
                problem, regularized_result, decision, observables,
            )
        end
        return RegularizedExitLocationResult(
            :completed, T(terminal.physical_time), terminal_s, terminal_state,
            problem, regularized_result,
            AutomaticSwitchingDecision(:none, (i, j), :exit_threshold_not_reached),
            observables,
        )
    end

    exit_s = something(located_s[])
    regularized_result = final_integration(exit_s)
    exit_state = perturbed_levi_civita_state(regularized_result, exit_s)
    cartesian_state = Vector{T}(exit_state.physical_state)
    observables = pair_observables(cartesian_state)
    decision = _certified_exit_decision(observables, parameters, (i, j))
    status = decision.action === :exit ? :exit : :failure
    RegularizedExitLocationResult(
        status,
        T(exit_state.physical_time),
        exit_s,
        cartesian_state,
        problem,
        regularized_result,
        decision,
        observables,
    )
end

"""
    AutomaticCartesianSegment

One retained Cartesian segment produced by the experimental automatic-switching
controller. `location` is the validated [`CartesianEntryLocationResult`](@ref)
that terminated the segment.
"""
struct AutomaticCartesianSegment{T<:AbstractFloat,S,L}
    start_time::T
    end_time::T
    entry_state::S
    exit_state::S
    location::L
end

"""
    AutomaticRegularizedSegment

One retained perturbed Levi-Civita segment produced by the experimental
automatic-switching controller. `pair` preserves the ordered regularized pair
and `location` is the validated [`RegularizedExitLocationResult`](@ref).
"""
struct AutomaticRegularizedSegment{T<:AbstractFloat,S,L}
    pair::Tuple{Int,Int}
    start_time::T
    end_time::T
    entry_state::S
    exit_state::S
    location::L
end

"""
    ExperimentalSwitchingTrajectory

Controller-level result for experimental automatic switching between Cartesian
and a selected regularized backend (planar Levi-Civita or spatial KS).

All completed segments and switch events are retained even when `status` is
`:failure`. Dense unified sampling is intentionally not part of this stage.
"""
struct ExperimentalSwitchingTrajectory{T<:AbstractFloat,S}
    system::S
    tspan::Tuple{T,T}
    parameters::AutomaticSwitchingParameters
    segments::Vector{Any}
    switch_events::Vector{Any}
    status::Symbol
    final_time::T
    final_state::Vector{T}
    failure::Union{Nothing,AutomaticSwitchingFailure{T}}

    function ExperimentalSwitchingTrajectory(
        system::S,
        tspan::Tuple{T,T},
        parameters::AutomaticSwitchingParameters,
        segments::Vector{Any},
        switch_events::Vector{Any},
        status::Symbol,
        final_time::T,
        final_state::Vector{T},
        failure::Union{Nothing,AutomaticSwitchingFailure{T}},
    ) where {T<:AbstractFloat,S}
        status in (:completed, :failure) ||
            throw(ArgumentError("experimental trajectory status must be :completed or :failure."))
        status === :completed && !isnothing(failure) &&
            throw(ArgumentError("a completed trajectory cannot contain a failure record."))
        status === :failure && isnothing(failure) &&
            throw(ArgumentError("a failed trajectory requires a failure record."))
        new{T,S}(
            system, tspan, parameters, segments, switch_events, status,
            final_time, final_state, failure,
        )
    end
end

@inline function _automatic_failure(
    time::T,
    decision::AutomaticSwitchingDecision,
) where {T<:AbstractFloat}
    AutomaticSwitchingFailure(
        time,
        decision.reason,
        "Experimental automatic switching terminated safely: $(decision.reason).";
        pair=decision.pair,
    )
end

function _failed_switching_trajectory(
    converted_system,
    tspan,
    parameters,
    segments,
    events,
    current_time,
    current_state,
    reason::Symbol,
    message::String;
    pair=nothing,
    progress_evidence=nothing,
)
    failure = AutomaticSwitchingFailure(
        current_time, reason, message; pair=pair, progress_evidence=progress_evidence,
    )
    ExperimentalSwitchingTrajectory(
        converted_system,
        tspan,
        parameters,
        segments,
        events,
        :failure,
        current_time,
        copy(current_state),
        failure,
    )
end

function _entry_transition_diagnostics(system, state, time, pair)
    problem = PerturbedLeviCivitaProblem(system, state, pair; initial_time=time)
    reconstructed = Vector{eltype(state)}(
        perturbed_levi_civita_state_at_time(problem, time).physical_state,
    )
    _transition_diagnostics(system, state, reconstructed, time, pair)
end

function _exit_transition_diagnostics(system, state, time, pair)
    pair_state = to_pair_coordinates(system, state, pair)
    reconstructed = Vector{eltype(state)}(from_pair_coordinates(system, pair_state))
    _transition_diagnostics(system, state, reconstructed, time, pair)
end

@inline function _switch_event(time, kind, pair, observables, diagnostics)
    RegularizationSwitchEvent(
        time,
        kind,
        pair,
        observables.separations,
        observables.radial_rates,
        observables.isolation_ratio,
        diagnostics,
    )
end

"""
    simulate_experimental_switching(system, u0, tspan, parameters; kwargs...)

Run the experimental alternating automatic-switching controller. Cartesian
propagation searches for an isolated inward entry crossing, and the selected
regularization backend then searches for its isolated outward exit crossing.
Set `regularization_backend=:ks` to use coupled spatial KS propagation; the
default `:levi_civita` preserves the validated legacy path. Every completed segment and switch event is retained.

The controller fails safely on ambiguous decisions, insufficient physical-time
progress, or exhaustion of `parameters.maximum_switches`. It leaves the
ordinary [`simulate`](@ref) API unchanged. `cartesian_kwargs` and
`regularized_kwargs` are named tuples forwarded to the corresponding validated
one-segment locators. Unified dense sampling is deliberately deferred to a
later stage.
"""
function simulate_experimental_switching(
    system::ThreeBodySystem,
    u0::AbstractVector{<:AbstractFloat},
    tspan::Tuple{<:Real,<:Real},
    parameters::AutomaticSwitchingParameters;
    cartesian_kwargs::NamedTuple=NamedTuple(),
    regularized_kwargs::NamedTuple=NamedTuple(),
    regularization_backend::Symbol=:levi_civita,
)
    validate_state(u0)
    T = float(promote_type(eltype(system.masses), eltype(u0), typeof(first(tspan)), typeof(last(tspan))))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    t0, tf = T(first(tspan)), T(last(tspan))
    all(isfinite, (t0, tf)) || throw(ArgumentError("tspan endpoints must be finite."))
    tf > t0 || throw(ArgumentError("experimental automatic switching requires an increasing tspan."))

    regularization_backend in (:levi_civita, :ks) ||
        throw(ArgumentError("regularization_backend must be :levi_civita or :ks."))

    initial_state = Vector{T}(u0)
    current_state = copy(initial_state)
    current_time = t0
    mode::ExperimentalSwitchingMode = CartesianSwitchingMode()
    segments = Any[]
    events = Any[]
    switch_count = 0
    progress_state::Union{Nothing,AutomaticSwitchingProgressState{T}} = nothing
    ks_gauge_references = Dict{Tuple{Int,Int},Any}()

    while current_time < tf
        segment_start = current_time
        segment_entry_state = copy(current_state)

        if mode isa CartesianSwitchingMode
            located = locate_cartesian_entry_event(
                converted_system, current_state, (current_time, tf), parameters;
                cartesian_kwargs...,
            )
            push!(segments, AutomaticCartesianSegment(
                segment_start,
                T(located.physical_time),
                segment_entry_state,
                Vector{T}(located.state),
                located,
            ))
            current_time = T(located.physical_time)
            current_state = Vector{T}(located.state)

            if located.status === :completed
                return ExperimentalSwitchingTrajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    :completed, current_time, current_state, nothing,
                )
            elseif located.status === :failure
                return ExperimentalSwitchingTrajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    :failure, current_time, current_state,
                    _automatic_failure(current_time, located.decision),
                )
            end

            current_time - segment_start >= parameters.minimum_time_progress ||
                return _failed_switching_trajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    current_time, current_state, :insufficient_time_progress,
                    "Cartesian entry event did not advance physical time sufficiently.";
                    pair=located.decision.pair,
                )

            pair = something(located.decision.pair)
            selected_index = _canonical_pair_index(pair)
            progress_evidence, proposed_progress_state = _certify_automatic_switching_progress(
                progress_state, :entry, pair, current_time,
                T(located.observables.separations[selected_index]), parameters,
            )
            progress_evidence.certified ||
                return _failed_switching_trajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    current_time, current_state, progress_evidence.reason,
                    progress_evidence.reason === :insufficient_time_progress ?
                        "Cartesian entry event did not advance physical time sufficiently." :
                        "Same-pair re-entry did not achieve the configured separation excursion.";
                    pair=pair, progress_evidence=progress_evidence,
                )
            switch_count += 1
            switch_count <= parameters.maximum_switches ||
                return _failed_switching_trajectory(
                    converted_system,
                    (t0, tf),
                    parameters,
                    segments,
                    events,
                    current_time,
                    current_state,
                    :maximum_switches_exceeded,
                    "The configured maximum number of switch events was exceeded.";
                    pair=located.decision.pair,
                )

            diagnostics = if regularization_backend === :ks
                reference = get(ks_gauge_references, pair, nothing)
                _ks_entry_transition_diagnostics(
                    converted_system, current_state, current_time, pair, reference,
                )
            else
                _entry_transition_diagnostics(
                    converted_system, current_state, current_time, pair,
                )
            end
            push!(events, _switch_event(
                current_time, :entry, pair, located.observables, diagnostics,
            ))
            progress_state = proposed_progress_state
            mode = RegularizedSwitchingMode(pair)
        else
            pair = mode.pair
            located = if regularization_backend === :ks
                reference = get(ks_gauge_references, pair, nothing)
                locate_ks_regularized_exit_event(
                    converted_system, current_state, pair, current_time, tf, parameters;
                    reference=reference, regularized_kwargs...,
                )
            else
                locate_regularized_exit_event(
                    converted_system, current_state, pair, current_time, tf, parameters;
                    regularized_kwargs...,
                )
            end
            push!(segments, AutomaticRegularizedSegment(
                pair,
                segment_start,
                T(located.physical_time),
                segment_entry_state,
                Vector{T}(located.state),
                located,
            ))
            current_time = T(located.physical_time)
            current_state = Vector{T}(located.state)

            if located.status === :completed
                return ExperimentalSwitchingTrajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    :completed, current_time, current_state, nothing,
                )
            elseif located.status === :failure
                return ExperimentalSwitchingTrajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    :failure, current_time, current_state,
                    _automatic_failure(current_time, located.decision),
                )
            end

            current_time - segment_start >= parameters.minimum_time_progress ||
                return _failed_switching_trajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    current_time, current_state, :insufficient_time_progress,
                    "Regularized exit event did not advance physical time sufficiently.";
                    pair=pair,
                )

            selected_index = _canonical_pair_index(pair)
            progress_evidence, proposed_progress_state = _certify_automatic_switching_progress(
                progress_state, :exit, pair, current_time,
                T(located.observables.separations[selected_index]), parameters,
            )
            progress_evidence.certified ||
                return _failed_switching_trajectory(
                    converted_system, (t0, tf), parameters, segments, events,
                    current_time, current_state, progress_evidence.reason,
                    "Regularized exit event did not advance physical time sufficiently.";
                    pair=pair, progress_evidence=progress_evidence,
                )
            switch_count += 1
            switch_count <= parameters.maximum_switches ||
                return _failed_switching_trajectory(
                    converted_system,
                    (t0, tf),
                    parameters,
                    segments,
                    events,
                    current_time,
                    current_state,
                    :maximum_switches_exceeded,
                    "The configured maximum number of switch events was exceeded.";
                    pair=pair,
                )

            if regularization_backend === :ks && !isnothing(located.problem) &&
               !isnothing(located.regularized_result)
                terminal_y = located.regularized_result.solution.u[end]
                ks_gauge_references[pair] = SVector{4,T}(terminal_y[1:4])
            end
            diagnostics = _exit_transition_diagnostics(
                converted_system, current_state, current_time, pair,
            )
            push!(events, _switch_event(
                current_time, :exit, pair, located.observables, diagnostics,
            ))
            progress_state = proposed_progress_state
            mode = CartesianSwitchingMode()
        end
    end

    ExperimentalSwitchingTrajectory(
        converted_system, (t0, tf), parameters, segments, events,
        :completed, current_time, current_state, nothing,
    )
end

@inline function _automatic_segment_contains(segment, time)
    segment.start_time <= time <= segment.end_time
end

function _automatic_segment_index(
    trajectory::ExperimentalSwitchingTrajectory,
    time::Real,
)
    T = eltype(trajectory.final_state)
    target = T(time)
    isfinite(target) || throw(ArgumentError("evaluation time must be finite."))
    t0, tf = trajectory.tspan
    t0 <= target <= trajectory.final_time || throw(ArgumentError(
        "evaluation time must lie within the computed trajectory interval " *
        "[$t0, $(trajectory.final_time)].",
    ))

    for (index, segment) in pairs(trajectory.segments)
        _automatic_segment_contains(segment, target) && return index, target
    end
    throw(ErrorException("no retained automatic-switching segment contains time $target."))
end

"""
    experimental_switching_state(trajectory, time; regularized_kwargs=NamedTuple())

Evaluate an [`ExperimentalSwitchingTrajectory`](@ref) at absolute physical time
`time`.

Cartesian segments use the retained dense ODE solution. Regularized segments use
bounded inversion of the retained Levi-Civita or KS Sundman-time solution. Exact segment boundaries
return the stored handoff states without interpolation, so entry and exit epochs
are represented consistently across adjacent segments.

`regularized_kwargs` configures inversion of physical time within the retained
regularized dense solution. The supported keys are `tolerance` and
`max_iterations`; evaluator calls never reintegrate the segment.
"""
function experimental_switching_state(
    trajectory::ExperimentalSwitchingTrajectory,
    time::Real;
    regularized_kwargs::NamedTuple=NamedTuple(),
)
    index, target = _automatic_segment_index(trajectory, time)
    segment = trajectory.segments[index]

    target == segment.start_time && return copy(segment.entry_state)
    target == segment.end_time && return copy(segment.exit_state)

    if segment isa AutomaticCartesianSegment
        return Vector{eltype(trajectory.final_state)}(
            segment.location.simulation.solution(target),
        )
    elseif segment isa AutomaticRegularizedSegment
        supported_keys = (:tolerance, :max_iterations)
        unsupported_keys = setdiff(keys(regularized_kwargs), supported_keys)
        isempty(unsupported_keys) || throw(ArgumentError(
            "unsupported regularized evaluation keyword(s): " *
            join(string.(unsupported_keys), ", ") *
            "; supported keywords are tolerance and max_iterations.",
        ))

        result = segment.location.regularized_result
        endpoint_s = segment.location.fictitious_time
        T = eltype(trajectory.final_state)
        default_tolerance = T(100) * eps(T)
        tolerance = haskey(regularized_kwargs, :tolerance) ?
            T(regularized_kwargs.tolerance) : default_tolerance
        max_iterations = haskey(regularized_kwargs, :max_iterations) ?
            Int(regularized_kwargs.max_iterations) : 256
        isfinite(tolerance) && tolerance > zero(T) ||
            throw(ArgumentError("regularized evaluation tolerance must be finite and positive."))
        max_iterations > 0 ||
            throw(ArgumentError("regularized evaluation max_iterations must be positive."))

        left_s = zero(T)
        right_s = T(endpoint_s)
        midpoint_s = (left_s + right_s) / T(2)
        for _ in 1:max_iterations
            midpoint_s = (left_s + right_s) / T(2)
            is_ks = segment.location.problem isa KSThreeBodyProblem
            time_index = is_ks ? 10 : 14
            midpoint_time = T(result.solution(midpoint_s)[time_index])
            time_scale = max(one(T), abs(target))
            s_scale = max(one(T), abs(left_s), abs(right_s), abs(midpoint_s))
            time_converged = abs(midpoint_time - target) <= tolerance * time_scale
            bracket_converged = abs(right_s - left_s) <= tolerance * s_scale
            if time_converged && bracket_converged
                if segment.location.problem isa KSThreeBodyProblem
                    return Vector{T}(ks_three_body_cartesian_state(
                        segment.location.problem, result.solution(midpoint_s),
                    ))
                end
                reconstructed = perturbed_levi_civita_state(result, midpoint_s)
                return Vector{T}(reconstructed.physical_state)
            end
            if midpoint_time < target
                left_s = midpoint_s
            else
                right_s = midpoint_s
            end
        end

        midpoint_s = (left_s + right_s) / T(2)
        if segment.location.problem isa KSThreeBodyProblem
            return Vector{T}(ks_three_body_cartesian_state(
                segment.location.problem, result.solution(midpoint_s),
            ))
        end
        reconstructed = perturbed_levi_civita_state(result, midpoint_s)
        return Vector{T}(reconstructed.physical_state)
    end

    throw(ErrorException("unsupported automatic-switching segment type $(typeof(segment))."))
end

function (trajectory::ExperimentalSwitchingTrajectory)(time::Real; kwargs...)
    experimental_switching_state(trajectory, time; kwargs...)
end


"""
    ExperimentalSwitchingSamples

Unified physical-time samples from an [`ExperimentalSwitchingTrajectory`](@ref).
`times` is strictly increasing and `states[k]` is the complete Cartesian state
at `times[k]`. Switch epochs, when requested, occur exactly once.
"""
struct ExperimentalSwitchingSamples{T<:AbstractFloat}
    times::Vector{T}
    states::Vector{Vector{T}}

    function ExperimentalSwitchingSamples(
        times::Vector{T},
        states::Vector{Vector{T}},
    ) where {T<:AbstractFloat}
        length(times) == length(states) ||
            throw(ArgumentError("sample times and states must have equal lengths."))
        isempty(times) && throw(ArgumentError("at least one sample is required."))
        all(isfinite, times) || throw(ArgumentError("sample times must be finite."))
        all(diff(times) .> zero(T)) ||
            throw(ArgumentError("sample times must be strictly increasing."))
        all(state -> length(state) == STATE_SIZE, states) ||
            throw(ArgumentError("every sampled state must have length STATE_SIZE."))
        new{T}(times, states)
    end
end

Base.length(samples::ExperimentalSwitchingSamples) = length(samples.times)
Base.firstindex(::ExperimentalSwitchingSamples) = 1
Base.lastindex(samples::ExperimentalSwitchingSamples) = length(samples)
Base.eachindex(samples::ExperimentalSwitchingSamples) = Base.OneTo(length(samples))
Base.getindex(samples::ExperimentalSwitchingSamples, index::Integer) = samples.states[index]

function _validated_automatic_sample_times(
    trajectory::ExperimentalSwitchingTrajectory,
    times;
    include_switches::Bool,
)
    T = eltype(trajectory.final_state)
    converted = T[]
    for time in times
        value = T(time)
        isfinite(value) || throw(ArgumentError("sample times must be finite."))
        push!(converted, value)
    end
    isempty(converted) && throw(ArgumentError("at least one sample time is required."))
    all(diff(converted) .> zero(T)) ||
        throw(ArgumentError("explicit sample times must be strictly increasing and unique."))

    t0 = trajectory.tspan[1]
    tf = trajectory.final_time
    first(converted) >= t0 && last(converted) <= tf || throw(ArgumentError(
        "sample times must lie within the computed trajectory interval [$t0, $tf].",
    ))

    include_switches || return converted
    switch_times = T[event.physical_time for event in trajectory.switch_events]
    sort!(unique!(vcat(converted, switch_times)))
end

"""
    sample_experimental_switching(trajectory, times;
                                  include_switches=true,
                                  regularized_kwargs=NamedTuple())

Evaluate an [`ExperimentalSwitchingTrajectory`](@ref) at explicit, strictly
increasing physical times. When `include_switches=true`, every retained switch
epoch is inserted and represented exactly once. Sampling is restricted to the
successfully computed interval, including for safely failed trajectories.
"""
function sample_experimental_switching(
    trajectory::ExperimentalSwitchingTrajectory,
    times;
    include_switches::Bool=true,
    regularized_kwargs::NamedTuple=NamedTuple(),
)
    sample_times = _validated_automatic_sample_times(
        trajectory, times; include_switches=include_switches,
    )
    T = eltype(trajectory.final_state)
    states = Vector{Vector{T}}(undef, length(sample_times))
    for index in eachindex(sample_times)
        states[index] = experimental_switching_state(
            trajectory,
            sample_times[index];
            regularized_kwargs=regularized_kwargs,
        )
    end
    ExperimentalSwitchingSamples(sample_times, states)
end

"""
    sample_experimental_switching(trajectory; dt, include_switches=true,
                                  regularized_kwargs=NamedTuple(),
                                  maximum_samples=1_000_000)

Sample an experimental switching trajectory on a uniform physical-time grid.
The initial and final computed epochs are always included. If the interval is
not an integer multiple of `dt`, the final interval is shortened. Switch epochs
are optionally inserted exactly once without changing event location.
"""
function sample_experimental_switching(
    trajectory::ExperimentalSwitchingTrajectory;
    dt::Real,
    include_switches::Bool=true,
    regularized_kwargs::NamedTuple=NamedTuple(),
    maximum_samples::Integer=1_000_000,
)
    maximum_samples > 1 || throw(ArgumentError("maximum_samples must exceed one."))
    T = eltype(trajectory.final_state)
    step = T(dt)
    isfinite(step) && step > zero(T) ||
        throw(ArgumentError("dt must be finite and positive."))

    t0 = trajectory.tspan[1]
    tf = trajectory.final_time
    interval = tf - t0
    estimated = floor(Int, interval / step) + 2
    estimated <= maximum_samples || throw(ArgumentError(
        "requested sampling grid exceeds maximum_samples=$maximum_samples.",
    ))

    times = T[t0]
    time = t0
    while time + step < tf
        time += step
        push!(times, time)
        length(times) < maximum_samples || throw(ArgumentError(
            "requested sampling grid exceeds maximum_samples=$maximum_samples.",
        ))
    end
    tf > last(times) && push!(times, tf)

    sample_experimental_switching(
        trajectory,
        times;
        include_switches=include_switches,
        regularized_kwargs=regularized_kwargs,
    )
end

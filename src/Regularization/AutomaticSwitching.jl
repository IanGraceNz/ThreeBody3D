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
    AutomaticSwitchingParameters(; enter_threshold, exit_threshold, ...)

Validated numerical and safety parameters for experimental threshold-driven
automatic regularization.

Required hysteresis is enforced by
`0 < enter_threshold < exit_threshold`. `ambiguity_threshold` defaults to the
exit threshold and must not be smaller than the entry threshold.
`minimum_separation_ratio > 1` requires the second-smallest pair separation to
remain larger than the selected separation by a configurable factor.
`maximum_switches` bounds the total number of entry and exit events, while
`minimum_time_progress > 0` prevents zero-time switching loops.

This type only stores policy. It does not alter [`simulate`](@ref) or perform
an integration.
"""
struct AutomaticSwitchingParameters{T<:AbstractFloat}
    enter_threshold::T
    exit_threshold::T
    ambiguity_threshold::T
    minimum_separation_ratio::T
    maximum_switches::Int
    minimum_time_progress::T
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
)
    T = float(promote_type(
        typeof(enter_threshold),
        typeof(exit_threshold),
        typeof(ambiguity_threshold),
        typeof(minimum_separation_ratio),
        typeof(minimum_time_progress),
    ))

    enter = T(enter_threshold)
    exit = T(exit_threshold)
    ambiguity = T(ambiguity_threshold)
    ratio = T(minimum_separation_ratio)
    progress = T(minimum_time_progress)

    all(isfinite, (enter, exit, ambiguity, ratio, progress)) ||
        throw(ArgumentError("automatic-switching parameters must be finite."))
    enter > zero(T) ||
        throw(ArgumentError("enter_threshold must be positive."))
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

    AutomaticSwitchingParameters{T}(
        enter,
        exit,
        ambiguity,
        ratio,
        Int(maximum_switches),
        progress,
    )
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
end

function AutomaticSwitchingFailure(
    physical_time::T,
    reason::Symbol,
    message::AbstractString;
    pair::Union{Nothing,Tuple{<:Integer,<:Integer}}=nothing,
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

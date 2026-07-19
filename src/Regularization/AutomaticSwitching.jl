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

"""
    AutomaticSwitchingDecision

Solver-independent decision returned by the experimental automatic-switching
policy.

`action` is one of `:none`, `:enter`, `:exit`, or `:failure`. `pair` identifies
the affected ordered pair when applicable. `reason` is a machine-readable
explanation suitable for diagnostics and tests. This type contains no solver
state and does not locate threshold crossings.
"""
struct AutomaticSwitchingDecision
    action::Symbol
    pair::Union{Nothing,Tuple{Int,Int}}
    reason::Symbol

    function AutomaticSwitchingDecision(
        action::Symbol,
        pair::Union{Nothing,Tuple{<:Integer,<:Integer}},
        reason::Symbol,
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
        new(action, validated_pair, reason)
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
) where {T<:AbstractFloat}
    any(observables.collisions) &&
        return _failure_decision(:collision_state, observables.closest_pair)

    candidates = Int[]
    for index in 1:3
        if observables.separations[index] <= parameters.enter_threshold &&
           observables.radial_rates[index] < zero(T)
            push!(candidates, index)
        end
    end

    isempty(candidates) && return _none_decision(:no_entry_candidate)
    length(candidates) > 1 && return _failure_decision(:simultaneous_entry_candidates)

    candidate_index = only(candidates)
    candidate_pair = _CANONICAL_BINARY_PAIRS[candidate_index]
    candidate_index == observables.order[1] ||
        return _failure_decision(:candidate_not_closest, candidate_pair)

    second_index = observables.order[2]
    observables.separations[second_index] <= parameters.ambiguity_threshold &&
        return _failure_decision(:ambiguous_close_pairs, candidate_pair)
    observables.isolation_ratio < parameters.minimum_separation_ratio &&
        return _failure_decision(:insufficient_pair_isolation, candidate_pair)

    AutomaticSwitchingDecision(:enter, candidate_pair, :unique_approaching_pair)
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
) where {T<:AbstractFloat}
    selected_index = _canonical_pair_index(pair)
    selected_pair = (Int(pair[1]), Int(pair[2]))

    for index in 1:3
        if observables.collisions[index] && index != selected_index
            return _failure_decision(:nonselected_pair_collision, selected_pair)
        end
    end
    observables.collisions[selected_index] &&
        return AutomaticSwitchingDecision(:none, selected_pair, :selected_pair_collision)

    selected_index == observables.order[1] ||
        return _failure_decision(:selected_pair_lost, selected_pair)

    second_index = observables.order[2]
    observables.separations[second_index] <= parameters.ambiguity_threshold &&
        return _failure_decision(:ambiguous_close_pairs, selected_pair)
    observables.isolation_ratio < parameters.minimum_separation_ratio &&
        return _failure_decision(:insufficient_pair_isolation, selected_pair)

    selected_separation = observables.separations[selected_index]
    selected_rate = observables.radial_rates[selected_index]
    if selected_separation >= parameters.exit_threshold && selected_rate > zero(T)
        return AutomaticSwitchingDecision(:exit, selected_pair, :isolated_receding_pair)
    end

    AutomaticSwitchingDecision(:none, selected_pair, :exit_condition_not_met)
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
    decision = automatic_entry_decision(observables, parameters)

    # The continuous callback has already certified that `event.pair` crossed
    # the entry threshold inward. Dense reevaluation at the same root-found
    # time can differ by a few ulps and place the separation just above the
    # threshold, so revalidate the physical entry conditions without requiring
    # a second exact threshold comparison.
    if decision.action === :none
        event_index = _canonical_pair_index(event.pair)
        event_rate = observables.radial_rates[event_index]
        if !observables.collisions[event_index] && event_rate < zero(event_rate)
            if event_index != observables.order[1]
                decision = _failure_decision(:candidate_not_closest, event.pair)
            else
                second_index = observables.order[2]
                if observables.separations[second_index] <= parameters.ambiguity_threshold
                    decision = _failure_decision(:ambiguous_close_pairs, event.pair)
                elseif observables.isolation_ratio < parameters.minimum_separation_ratio
                    decision = _failure_decision(:insufficient_pair_isolation, event.pair)
                else
                    decision = AutomaticSwitchingDecision(
                        :enter,
                        event.pair,
                        :certified_inward_threshold_crossing,
                    )
                end
            end
        end
    end

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

    failure = _failure_decision(:entry_condition_not_met, event.pair)
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
    decision = automatic_exit_decision(observables, parameters, pair)
    decision.action !== :none && return decision

    selected_index = _canonical_pair_index(pair)
    if decision.reason === :exit_condition_not_met &&
       observables.radial_rates[selected_index] > zero(T)
        return AutomaticSwitchingDecision(
            :exit, pair, :certified_outward_threshold_crossing,
        )
    end

    _failure_decision(:exit_condition_not_met, pair)
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
    ks_gauge_references = Dict{Tuple{Int,Int},Any}()

    function failed(reason::Symbol, message::String; pair=nothing)
        failure = AutomaticSwitchingFailure(current_time, reason, message; pair=pair)
        ExperimentalSwitchingTrajectory(
            converted_system, (t0, tf), parameters, segments, events,
            :failure, current_time, copy(current_state), failure,
        )
    end

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
                return failed(
                    :insufficient_time_progress,
                    "Cartesian entry event did not advance physical time sufficiently.";
                    pair=located.decision.pair,
                )
            switch_count += 1
            switch_count <= parameters.maximum_switches ||
                return failed(
                    :maximum_switches_exceeded,
                    "The configured maximum number of switch events was exceeded.";
                    pair=located.decision.pair,
                )

            pair = something(located.decision.pair)
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
                return failed(
                    :insufficient_time_progress,
                    "Regularized exit event did not advance physical time sufficiently.";
                    pair=pair,
                )
            switch_count += 1
            switch_count <= parameters.maximum_switches ||
                return failed(
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

const DEFAULT_RELTOL = 1e-12
const DEFAULT_ABSTOL = 1e-12
const _CLOSE_APPROACH_POLICIES = (:ignore, :warn, :terminate)
const _BODY_PAIRS = ((1, 2), (1, 3), (2, 3))

"""
    AccuracyProfile

Named integration configuration containing a solver algorithm and default
relative and absolute tolerances. Construct profiles with [`accuracy_profile`](@ref).
"""
struct AccuracyProfile{A,T<:AbstractFloat}
    name::Symbol
    algorithm::A
    reltol::T
    abstol::T
end

"""
    accuracy_profile(name=:accurate)

Return a built-in integration profile:

- `:fast` uses `Tsit5()` with `1e-9` tolerances.
- `:accurate` uses `Vern9()` with `1e-12` tolerances.
- `:extreme` uses `Vern9()` with `1e-13` tolerances.

The profiles are starting points, not universal guarantees. Close encounters
may require stricter tolerances, shorter spans, and eventually regularized
coordinates.
"""
function accuracy_profile(name::Symbol=:accurate)
    name === :fast && return AccuracyProfile(:fast, Tsit5(), 1e-9, 1e-9)
    name === :accurate && return AccuracyProfile(:accurate, Vern9(), 1e-12, 1e-12)
    name === :extreme && return AccuracyProfile(:extreme, Vern9(), 1e-13, 1e-13)
    throw(ArgumentError("Unknown accuracy profile $name. Use :fast, :accurate, or :extreme."))
end

"""
    CloseApproachEvent

A threshold-entry event detected continuously during integration. `time` is
the root-found crossing time, `pair` identifies the bodies, `separation` is
the pair distance at the event, and `policy` records the requested response.
"""
struct CloseApproachEvent{T<:AbstractFloat}
    time::T
    pair::Tuple{Int,Int}
    separation::T
    threshold::T
    policy::Symbol
end

function Base.show(io::IO, event::CloseApproachEvent)
    print(io, "CloseApproachEvent(time=", event.time,
          ", pair=", event.pair,
          ", separation=", event.separation,
          ", threshold=", event.threshold,
          ", policy=", event.policy, ")")
end

"""
    SimulationResult

Result returned by [`simulate`](@ref). The underlying SciML solution is in
`result.solution`; `result.system` retains the physical model for diagnostics,
and `result.close_approach_events` contains continuously detected threshold
entries requested through `simulate`.
"""
struct SimulationResult{S,Y,E}
    solution::S
    system::Y
    close_approach_events::E
end

SimulationResult(solution, system) = SimulationResult(solution, system, CloseApproachEvent{eltype(solution.t)}[])

Base.length(result::SimulationResult) = length(result.solution)
Base.getindex(result::SimulationResult, i) = result.solution[i]
(result::SimulationResult)(t) = result.solution(t)

"""Return `true` when integration stopped because of a `:terminate` close-approach policy."""
terminated_by_close_approach(result::SimulationResult) =
    !isempty(result.close_approach_events) &&
    last(result.close_approach_events).policy === :terminate &&
    last(result.solution.t) ≈ last(result.close_approach_events).time

function make_problem(system::ThreeBodySystem, u0::AbstractVector, tspan::Tuple{<:Real,<:Real})
    validate_state(u0)
    tspan[2] > tspan[1] || throw(ArgumentError("tspan must satisfy t_final > t_initial."))
    T = promote_type(eltype(u0), typeof(system.G), typeof(float(tspan[1])), typeof(float(tspan[2])))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    ODEProblem(threebody!, T.(u0), (T(tspan[1]), T(tspan[2])), converted_system)
end

function _resolve_solver(solver, reltol, abstol)
    if solver isa Symbol
        profile = accuracy_profile(solver)
        resolved_reltol = isnothing(reltol) ? profile.reltol : reltol
        resolved_abstol = isnothing(abstol) ? profile.abstol : abstol
        return profile.algorithm, resolved_reltol, resolved_abstol
    end
    resolved_reltol = isnothing(reltol) ? DEFAULT_RELTOL : reltol
    resolved_abstol = isnothing(abstol) ? DEFAULT_ABSTOL : abstol
    solver, resolved_reltol, resolved_abstol
end

@inline function _closest_pair(u)
    distances = _pair_separations(u)
    index = argmin(distances)
    _BODY_PAIRS[index], distances[index]
end

function _validate_close_approach_options(threshold, policy)
    policy in _CLOSE_APPROACH_POLICIES ||
        throw(ArgumentError("close_approach_policy must be :ignore, :warn, or :terminate."))
    isnothing(threshold) && return nothing
    threshold isa Real || throw(ArgumentError("close_approach_threshold must be a real number or nothing."))
    isfinite(threshold) && threshold > 0 ||
        throw(ArgumentError("close_approach_threshold must be finite and positive."))
    nothing
end

function _close_approach_callback(threshold::T, policy::Symbol,
                                  events::Vector{CloseApproachEvent{T}}) where {T<:AbstractFloat}
    condition(u, _t, _integrator) = _closest_pair(u)[2] - threshold

    function affect_enter!(integrator)
        pair, separation = _closest_pair(integrator.u)
        event = CloseApproachEvent(T(integrator.t), pair, T(separation), threshold, policy)
        push!(events, event)
        if policy === :warn
            @warn "Close-approach threshold crossed" time=event.time pair=event.pair separation=event.separation threshold=event.threshold
        elseif policy === :terminate
            SciMLBase.terminate!(integrator)
        end
        nothing
    end

    SciMLBase.ContinuousCallback(condition, nothing, affect_enter!;
                                 save_positions=(true, policy === :terminate))
end

@inline function _combine_callbacks(user_callback, monitor_callback)
    isnothing(user_callback) && return monitor_callback
    isnothing(monitor_callback) && return user_callback
    SciMLBase.CallbackSet(user_callback, monitor_callback)
end

"""
    simulate(system, u0, tspan; solver=:accurate, reltol=nothing,
             abstol=nothing, saveat=nothing, maxiters=10^7,
             close_approach_threshold=nothing,
             close_approach_policy=:ignore, callback=nothing, kwargs...)

Integrate the Newtonian three-body equations. `solver` may be one of the
built-in profile names `:fast`, `:accurate`, or `:extreme`, or any compatible
OrdinaryDiffEq algorithm object. Explicit `reltol` and `abstol` values override
the selected profile defaults.

Set a positive `close_approach_threshold` to detect inward crossings during
integration using continuous root finding. `close_approach_policy` may be
`:ignore` (record only), `:warn` (record and warn), or `:terminate` (record and
stop exactly at the first crossing). Events are available in
`result.close_approach_events`; detection does not depend on `saveat`. A user
`callback` is combined with the monitoring callback.

For reliable conservation diagnostics, pass a sufficiently dense `saveat`;
diagnostics are computed from saved states. Close-approach monitoring is not
regularization and does not soften gravity. Exact point-mass collisions remain
mathematical singularities and raise an error. Additional keywords are
forwarded to `OrdinaryDiffEq.solve`.
"""
function simulate(system::ThreeBodySystem, u0::AbstractVector,
                  tspan::Tuple{<:Real,<:Real};
                  solver=:accurate, reltol::Union{Nothing,Real}=nothing,
                  abstol::Union{Nothing,Real}=nothing, saveat=nothing,
                  maxiters::Integer=10^7,
                  close_approach_threshold::Union{Nothing,Real}=nothing,
                  close_approach_policy::Symbol=:ignore,
                  callback=nothing, kwargs...)
    algorithm, resolved_reltol, resolved_abstol = _resolve_solver(solver, reltol, abstol)
    resolved_reltol > 0 || throw(ArgumentError("reltol must be positive."))
    resolved_abstol > 0 || throw(ArgumentError("abstol must be positive."))
    maxiters > 0 || throw(ArgumentError("maxiters must be positive."))
    _validate_close_approach_options(close_approach_threshold, close_approach_policy)

    problem = make_problem(system, u0, tspan)
    T = eltype(problem.u0)
    events = CloseApproachEvent{T}[]
    monitor_callback = nothing

    if !isnothing(close_approach_threshold)
        threshold = T(close_approach_threshold)
        pair0, separation0 = _closest_pair(problem.u0)
        if separation0 <= threshold
            event = CloseApproachEvent(first(problem.tspan), pair0, T(separation0),
                                       threshold, close_approach_policy)
            push!(events, event)
            if close_approach_policy === :warn
                @warn "Initial state is inside the close-approach threshold" time=event.time pair=event.pair separation=event.separation threshold=event.threshold
            elseif close_approach_policy === :terminate
                throw(ArgumentError("The initial state is already inside close_approach_threshold; no integration was performed."))
            end
        end
        monitor_callback = _close_approach_callback(threshold, close_approach_policy, events)
    end

    combined_callback = _combine_callbacks(callback, monitor_callback)
    common_kwargs = (; reltol=resolved_reltol, abstol=resolved_abstol, maxiters)
    sol = if isnothing(saveat) && isnothing(combined_callback)
        solve(problem, algorithm; common_kwargs..., kwargs...)
    elseif isnothing(saveat)
        solve(problem, algorithm; common_kwargs..., callback=combined_callback, kwargs...)
    elseif isnothing(combined_callback)
        solve(problem, algorithm; common_kwargs..., saveat, kwargs...)
    else
        solve(problem, algorithm; common_kwargs..., saveat, callback=combined_callback, kwargs...)
    end
    SciMLBase.successful_retcode(sol) || error("Integration failed with retcode $(sol.retcode).")
    SimulationResult(sol, problem.p, events)
end

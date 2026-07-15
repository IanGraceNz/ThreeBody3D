"""
    ComposedRegularizedTrajectory

A manually composed physical trajectory containing an optional Cartesian
pre-segment, one explicit planar Levi-Civita segment, and an optional Cartesian
post-segment.

The object retains each underlying segment, a unified set of sampled physical
times and states, and continuity diagnostics at the entry and exit handoffs.
No threshold detection or automatic switching is performed.
"""
struct ComposedRegularizedTrajectory{T<:AbstractFloat,S,Pre,Reg,Post}
    system::S
    pair::Tuple{Int,Int}
    tspan::Tuple{T,T}
    regularized_interval::Tuple{T,T}
    pre_segment::Pre
    regularized_segment::Reg
    post_segment::Post
    times::Vector{T}
    states::Vector{Vector{T}}
    entry_continuity::RegularizationTransitionDiagnostics{T}
    exit_continuity::RegularizationTransitionDiagnostics{T}
end

Base.length(result::ComposedRegularizedTrajectory) = length(result.times)
Base.getindex(result::ComposedRegularizedTrajectory, i::Integer) = result.states[i]

function Base.show(io::IO, result::ComposedRegularizedTrajectory)
    println(io, "Composed Cartesian → Levi-Civita → Cartesian trajectory")
    println(io, "  selected pair:          $(result.pair)")
    println(io, "  physical interval:      $(result.tspan)")
    println(io, "  regularized interval:   $(result.regularized_interval)")
    println(io, "  sampled physical states:$(length(result.times))")
    println(io, "  pre-segment present:    $(!isnothing(result.pre_segment))")
    print(io,   "  post-segment present:   $(!isnothing(result.post_segment))")
end

@inline function _state_vector_at(solution, t, ::Type{T}) where {T}
    Vector{T}(solution(t))
end

function _regularized_state_from_segment(
    segment::ExplicitRegularizedSegment{T},
    target_time::T;
    tolerance::T,
    max_iterations::Integer,
) where {T}
    target_time == segment.entry_time && return copy(segment.entry_state)
    target_time == segment.exit_time && return copy(segment.exit_state)

    lower_s, upper_s = if segment.exit_fictitious_time > zero(T)
        (zero(T), segment.exit_fictitious_time)
    else
        (segment.exit_fictitious_time, zero(T))
    end
    solution = segment.regularized_result.solution
    lower_value = T(solution(lower_s)[14]) - target_time
    upper_value = T(solution(upper_s)[14]) - target_time
    signbit(lower_value) == signbit(upper_value) &&
        throw(ArgumentError("target_time is outside the regularized segment."))

    for _ in 1:max_iterations
        midpoint = (lower_s + upper_s) / T(2)
        midpoint_value = T(solution(midpoint)[14]) - target_time
        time_converged = abs(midpoint_value) <= tolerance * max(one(T), abs(target_time))
        bracket_converged = abs(upper_s - lower_s) <=
            tolerance * max(one(T), abs(midpoint), abs(lower_s), abs(upper_s))
        if time_converged && bracket_converged
            return Vector{T}(
                perturbed_levi_civita_state(segment.regularized_result, midpoint).physical_state,
            )
        elseif iszero(midpoint_value)
            return Vector{T}(
                perturbed_levi_civita_state(segment.regularized_result, midpoint).physical_state,
            )
        elseif signbit(midpoint_value) == signbit(lower_value)
            lower_s = midpoint
            lower_value = midpoint_value
        else
            upper_s = midpoint
            upper_value = midpoint_value
        end
    end

    midpoint = (lower_s + upper_s) / T(2)
    Vector{T}(perturbed_levi_civita_state(segment.regularized_result, midpoint).physical_state)
end

"""
    composed_state_at_time(result, time; tolerance=nothing, max_iterations=256)

Return the ordinary 18-element physical state of a
[`ComposedRegularizedTrajectory`](@ref) at `time`.

Cartesian segments are evaluated through their dense SciML solutions. Times
inside the regularized interval are evaluated by bisecting the already-computed
Sundman time stored in the regularized segment; no additional ODE integration
is performed.
"""
function composed_state_at_time(
    result::ComposedRegularizedTrajectory{T},
    time::Real;
    tolerance=nothing,
    max_iterations::Integer=256,
) where {T}
    target = T(time)
    isfinite(target) || throw(ArgumentError("time must be finite."))
    t0, tf = result.tspan
    t0 <= target <= tf || throw(BoundsError(result.tspan, target))
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))
    tol = isnothing(tolerance) ? T(64) * eps(T) : T(tolerance)
    isfinite(tol) && tol > zero(T) ||
        throw(ArgumentError("tolerance must be finite and positive."))

    entry_time, exit_time = result.regularized_interval
    if target < entry_time
        isnothing(result.pre_segment) && return copy(result.regularized_segment.entry_state)
        return _state_vector_at(result.pre_segment.solution, target, T)
    elseif target > exit_time
        isnothing(result.post_segment) && return copy(result.regularized_segment.exit_state)
        return _state_vector_at(result.post_segment.solution, target, T)
    end
    _regularized_state_from_segment(
        result.regularized_segment, target; tolerance=tol, max_iterations=max_iterations,
    )
end

(result::ComposedRegularizedTrajectory)(time::Real) = composed_state_at_time(result, time)

function _resolve_composed_times(t0::T, tf::T, saveat) where {T}
    if isnothing(saveat)
        return collect(range(t0, tf; length=101))
    elseif saveat isa Real
        step = T(saveat)
        isfinite(step) && step > zero(T) ||
            throw(ArgumentError("saveat must be finite and positive."))
        times = collect(t0:step:tf)
        isempty(times) && push!(times, t0)
        last(times) == tf || push!(times, tf)
        return times
    elseif saveat isa AbstractVector
        times = T.(saveat)
        all(isfinite, times) || throw(ArgumentError("saveat times must be finite."))
        issorted(times) || throw(ArgumentError("saveat times must be sorted."))
        all(t -> t0 <= t <= tf, times) ||
            throw(ArgumentError("saveat times must lie inside tspan."))
        isempty(times) && throw(ArgumentError("saveat must not be empty."))
        first(times) == t0 || pushfirst!(times, t0)
        last(times) == tf || push!(times, tf)
        return unique(times)
    end
    throw(ArgumentError("saveat must be nothing, a positive real step, or a vector of times."))
end

"""
    compose_regularized_trajectory(system, u0, tspan, pair, regularized_interval; kwargs...)

Manually compose a Cartesian pre-segment, one explicit planar Levi-Civita
segment, and a Cartesian post-segment into one physical trajectory.

`tspan = (t_initial, t_final)` and `regularized_interval = (t_enter, t_exit)`
must satisfy

`t_initial ≤ t_enter < t_exit ≤ t_final`.

The Cartesian segments use [`simulate`](@ref). The middle segment uses
[`propagate_regularized_segment`](@ref). `saveat` controls only the unified
physical samples returned in `times` and `states`; it does not affect the
segment integrations or transition states.

Keywords beginning with `cartesian_` configure both Cartesian solves. Remaining
keywords are forwarded to `propagate_regularized_segment`.
"""
function compose_regularized_trajectory(
    system::ThreeBodySystem,
    u0::AbstractVector{<:AbstractFloat},
    tspan::Tuple{<:Real,<:Real},
    pair::Tuple{<:Integer,<:Integer},
    regularized_interval::Tuple{<:Real,<:Real};
    saveat=nothing,
    branch::Integer=1,
    cartesian_solver=:accurate,
    cartesian_reltol::Union{Nothing,Real}=nothing,
    cartesian_abstol::Union{Nothing,Real}=nothing,
    sample_tolerance=nothing,
    sample_max_iterations::Integer=256,
    kwargs...,
)
    validate_state(u0)
    i, j, _ = _validate_pair(pair)
    T = float(promote_type(
        eltype(system.masses), eltype(u0), typeof(tspan[1]), typeof(tspan[2]),
        typeof(regularized_interval[1]), typeof(regularized_interval[2]),
    ))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    initial_state = Vector{T}(u0)
    t0, tf = T(tspan[1]), T(tspan[2])
    entry_time, exit_time = T(regularized_interval[1]), T(regularized_interval[2])
    all(isfinite, (t0, tf, entry_time, exit_time)) ||
        throw(ArgumentError("all physical times must be finite."))
    t0 < tf || throw(ArgumentError("tspan must satisfy t_final > t_initial."))
    t0 <= entry_time < exit_time <= tf || throw(ArgumentError(
        "regularized_interval must satisfy t_initial ≤ t_enter < t_exit ≤ t_final.",
    ))

    pre_segment = if entry_time == t0
        nothing
    else
        simulate(
            converted_system, initial_state, (t0, entry_time);
            solver=cartesian_solver, reltol=cartesian_reltol,
            abstol=cartesian_abstol,
        )
    end
    entry_state = isnothing(pre_segment) ? copy(initial_state) :
        _state_vector_at(pre_segment.solution, entry_time, T)

    regularized_segment = propagate_regularized_segment(
        converted_system, entry_state, (i, j), entry_time, exit_time;
        branch=branch, kwargs...,
    )

    post_segment = if exit_time == tf
        nothing
    else
        simulate(
            converted_system, regularized_segment.exit_state, (exit_time, tf);
            solver=cartesian_solver, reltol=cartesian_reltol,
            abstol=cartesian_abstol,
        )
    end

    entry_reference = isnothing(pre_segment) ? initial_state :
        _state_vector_at(pre_segment.solution, entry_time, T)
    entry_continuity = _transition_diagnostics(
        converted_system, entry_reference, regularized_segment.entry_state,
        entry_time, (i, j),
    )
    exit_reference = isnothing(post_segment) ? regularized_segment.exit_state :
        _state_vector_at(post_segment.solution, exit_time, T)
    exit_continuity = _transition_diagnostics(
        converted_system, regularized_segment.exit_state, exit_reference,
        exit_time, (i, j),
    )

    times = _resolve_composed_times(t0, tf, saveat)
    placeholder = ComposedRegularizedTrajectory{T,typeof(converted_system),typeof(pre_segment),
        typeof(regularized_segment),typeof(post_segment)}(
        converted_system, (i, j), (t0, tf), (entry_time, exit_time), pre_segment,
        regularized_segment, post_segment, times, Vector{Vector{T}}(),
        entry_continuity, exit_continuity,
    )
    states = [composed_state_at_time(
        placeholder, time; tolerance=sample_tolerance,
        max_iterations=sample_max_iterations,
    ) for time in times]

    ComposedRegularizedTrajectory{T,typeof(converted_system),typeof(pre_segment),
        typeof(regularized_segment),typeof(post_segment)}(
        converted_system, (i, j), (t0, tf), (entry_time, exit_time), pre_segment,
        regularized_segment, post_segment, times, states,
        entry_continuity, exit_continuity,
    )
end

"""
    composed_segment_statistics(result)

Return the solver statistics retained for the Cartesian pre-segment, the
regularized segment, and the Cartesian post-segment. Missing outer segments are
reported as `nothing`.
"""
function composed_segment_statistics(result::ComposedRegularizedTrajectory)
    (
        pre=isnothing(result.pre_segment) ? nothing : result.pre_segment.solution.stats,
        regularized=result.regularized_segment.regularized_result.solution.stats,
        post=isnothing(result.post_segment) ? nothing : result.post_segment.solution.stats,
    )
end

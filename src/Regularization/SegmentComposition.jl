"""
    SegmentSolverStatistics

Internal-work summary for one segment of a manually composed trajectory.
`saved_states` counts stored solution states; the remaining fields come from
SciML's solver statistics and describe integration work.
"""
struct SegmentSolverStatistics
    segment::Symbol
    saved_states::Int
    accepted_steps::Int
    rejected_steps::Int
    rhs_evaluations::Int
end

function Base.show(io::IO, statistics::SegmentSolverStatistics)
    println(io, "Segment solver statistics: ", statistics.segment)
    println(io, "  saved states:            ", statistics.saved_states)
    println(io, "  accepted internal steps: ", statistics.accepted_steps)
    println(io, "  rejected internal steps: ", statistics.rejected_steps)
    print(io,   "  RHS evaluations:         ", statistics.rhs_evaluations)
end

@inline function _segment_solver_statistics(segment::Symbol, solution)
    statistics = solution.stats
    SegmentSolverStatistics(
        segment,
        length(solution.t),
        Int(statistics.naccept),
        Int(statistics.nreject),
        Int(statistics.nf),
    )
end

"""
    ComposedRegularizedTrajectory

A manually composed physical trajectory consisting of three explicit segments:
Cartesian integration before a selected interval, one planar Levi-Civita
regularized interval, and Cartesian integration afterward.

The object retains every underlying solution, transition diagnostics, unified
physical sample times and states, and per-segment solver statistics. It performs
no threshold detection, automatic pair selection, or automatic switching.
"""
struct ComposedRegularizedTrajectory{T<:AbstractFloat,S,B,R,A}
    system::S
    pair::Tuple{Int,Int}
    tspan::Tuple{T,T}
    regularized_interval::Tuple{T,T}
    cartesian_before::B
    regularized_segment::R
    cartesian_after::A
    entry_continuity::RegularizationTransitionDiagnostics{T}
    exit_continuity::RegularizationTransitionDiagnostics{T}
    times::Vector{T}
    states::Vector{Vector{T}}
    solver_statistics::NTuple{3,SegmentSolverStatistics}
end

Base.length(result::ComposedRegularizedTrajectory) = length(result.times)
Base.getindex(result::ComposedRegularizedTrajectory, i::Integer) = result.states[i]

function _regularized_segment_state_at_time(
    segment::ExplicitRegularizedSegment{T},
    physical_time::T;
    tolerance::T=T(64) * eps(T),
    max_iterations::Int=256,
) where {T<:AbstractFloat}
    time_scale = max(one(T), abs(segment.entry_time), abs(segment.exit_time), abs(physical_time))
    time_tolerance = tolerance * time_scale

    abs(physical_time - segment.entry_time) <= time_tolerance &&
        return copy(segment.entry_state)
    abs(physical_time - segment.exit_time) <= time_tolerance &&
        return copy(segment.exit_state)
    segment.entry_time < physical_time < segment.exit_time ||
        throw(ArgumentError("physical_time lies outside the regularized segment."))

    solution = segment.regularized_result.solution
    left = zero(T)
    right = segment.exit_fictitious_time
    left_time = T(solution(left)[14])
    right_time = T(solution(right)[14])

    increasing = right_time >= left_time
    lower_time, upper_time = increasing ? (left_time, right_time) : (right_time, left_time)
    lower_time - time_tolerance <= physical_time <= upper_time + time_tolerance ||
        throw(ErrorException("Stored regularized solution does not bracket the requested physical time."))

    for _ in 1:max_iterations
        midpoint = (left + right) / T(2)
        midpoint_time = T(solution(midpoint)[14])

        if (increasing && midpoint_time < physical_time) ||
           (!increasing && midpoint_time > physical_time)
            left = midpoint
        else
            right = midpoint
        end

        bracket_tolerance = tolerance * max(one(T), abs(left), abs(right), abs(midpoint))
        if abs(right - left) <= bracket_tolerance
            target_s = (left + right) / T(2)
            return Vector{T}(
                perturbed_levi_civita_state(segment.regularized_result, target_s).physical_state,
            )
        end
    end

    throw(ErrorException("Unable to narrow the fictitious-time bracket inside the regularized segment."))
end

"""
    composed_regularized_state(result, physical_time; tolerance=nothing)

Evaluate a [`ComposedRegularizedTrajectory`](@ref) at an absolute physical time.
The appropriate underlying segment is selected deterministically. Exact handoff
times return the stored boundary states. Within the regularized interval, the
stored dense Sundman solution is inverted by bounded bisection; no new ODE solve
is performed.
"""
function composed_regularized_state(
    result::ComposedRegularizedTrajectory{T},
    physical_time::Real;
    tolerance=nothing,
) where {T<:AbstractFloat}
    time = T(physical_time)
    isfinite(time) || throw(ArgumentError("physical_time must be finite."))
    first(result.tspan) <= time <= last(result.tspan) ||
        throw(ArgumentError("physical_time lies outside the composed trajectory."))
    entry_time, exit_time = result.regularized_interval
    if time < entry_time
        return Vector{T}(result.cartesian_before.solution(time))
    elseif time == entry_time
        return copy(result.regularized_segment.entry_state)
    elseif time < exit_time
        tol = isnothing(tolerance) ? T(64) * eps(T) : T(tolerance)
        isfinite(tol) && tol > zero(T) ||
            throw(ArgumentError("tolerance must be finite and positive."))
        return _regularized_segment_state_at_time(
            result.regularized_segment, time; tolerance=tol,
        )
    elseif time == exit_time
        return copy(result.regularized_segment.exit_state)
    end
    Vector{T}(result.cartesian_after.solution(time))
end

(result::ComposedRegularizedTrajectory)(physical_time::Real) =
    composed_regularized_state(result, physical_time)

function _composition_sample_times(
    ::Type{T}, tspan::Tuple{T,T}, saveat,
    before, regularized, after,
) where {T<:AbstractFloat}
    t0, tf = tspan
    if isnothing(saveat)
        values = T[]
        append!(values, T.(before.solution.t))
        append!(values, T[state[14] for state in regularized.regularized_result.solution.u])
        append!(values, T.(after.solution.t))
        sort!(unique!(values))
        return values
    elseif saveat isa Real
        step = T(saveat)
        isfinite(step) && step > zero(T) ||
            throw(ArgumentError("saveat must be finite and positive."))
        values = collect(range(t0; step=step, stop=tf))
        isempty(values) || values[end] == tf || push!(values, tf)
        return values
    elseif saveat isa AbstractRange || saveat isa AbstractVector
        values = T.(collect(saveat))
        isempty(values) && throw(ArgumentError("saveat cannot be empty."))
        all(isfinite, values) || throw(ArgumentError("saveat values must be finite."))
        issorted(values) || throw(ArgumentError("saveat values must be sorted."))
        first(values) >= t0 && last(values) <= tf ||
            throw(ArgumentError("saveat values must lie within tspan."))
        return unique(values)
    end
    throw(ArgumentError("saveat must be nothing, a positive number, a range, or a vector."))
end

"""
    compose_regularized_trajectory(system, u0, tspan, pair,
                                   regularized_interval; kwargs...)

Manually compose three forward-time segments:

1. ordinary Cartesian integration from `tspan[1]` to the regularized entry time;
2. one explicit selected-pair planar Levi-Civita segment;
3. ordinary Cartesian integration from the regularized exit time to `tspan[2]`.

The regularized interval must lie strictly inside `tspan`. The returned
[`ComposedRegularizedTrajectory`](@ref) retains all underlying solutions and
provides one unified physical trajectory through `result.times`,
`result.states`, and [`composed_regularized_state`](@ref).

`saveat` controls only the unified output samples; it does not control either
handoff state. Cartesian solver options use the `cartesian_*` keywords, while
regularized targeting and integration use the `regularized_*` keywords. When
`regularized_tolerance` is omitted but either regularized ODE tolerance is
supplied, the tighter supplied tolerance is also used for physical-time
targeting. This prevents the Sundman-time inversion from becoming less accurate
than the requested regularized integration. This is an explicit research
workflow: it does not detect thresholds or switch pairs automatically.
"""
function compose_regularized_trajectory(
    system::ThreeBodySystem,
    u0::AbstractVector{<:AbstractFloat},
    tspan::Tuple{<:Real,<:Real},
    pair::Tuple{<:Integer,<:Integer},
    regularized_interval::Tuple{<:Real,<:Real};
    branch::Integer=1,
    saveat=nothing,
    cartesian_solver=:accurate,
    cartesian_reltol=nothing,
    cartesian_abstol=nothing,
    regularized_algorithm=Vern9(),
    regularized_reltol=nothing,
    regularized_abstol=nothing,
    regularized_initial_step::Real=one(eltype(u0)),
    regularized_tolerance=nothing,
    regularized_max_iterations::Integer=256,
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
        throw(ArgumentError("All time values must be finite."))
    t0 < entry_time < exit_time < tf || throw(ArgumentError(
        "regularized_interval must lie strictly inside the increasing tspan.",
    ))
    regularized_max_iterations > 0 ||
        throw(ArgumentError("regularized_max_iterations must be positive."))

    before = simulate(
        converted_system, initial_state, (t0, entry_time);
        solver=cartesian_solver,
        reltol=cartesian_reltol,
        abstol=cartesian_abstol,
    )
    entry_state = Vector{T}(before.solution(entry_time))

    regularized_keyword_values = (
        initial_step=T(regularized_initial_step),
        max_iterations=regularized_max_iterations,
        algorithm=regularized_algorithm,
        reltol=regularized_reltol,
        abstol=regularized_abstol,
    )
    targeting_tolerance = if !isnothing(regularized_tolerance)
        T(regularized_tolerance)
    elseif !isnothing(regularized_reltol) && !isnothing(regularized_abstol)
        min(T(regularized_reltol), T(regularized_abstol))
    elseif !isnothing(regularized_reltol)
        T(regularized_reltol)
    elseif !isnothing(regularized_abstol)
        T(regularized_abstol)
    else
        nothing
    end
    regularized_segment = if isnothing(targeting_tolerance)
        propagate_regularized_segment(
            converted_system, entry_state, (i, j), entry_time, exit_time;
            branch=branch, regularized_keyword_values...,
        )
    else
        propagate_regularized_segment(
            converted_system, entry_state, (i, j), entry_time, exit_time;
            branch=branch, tolerance=targeting_tolerance,
            regularized_keyword_values...,
        )
    end

    after = simulate(
        converted_system, regularized_segment.exit_state, (exit_time, tf);
        solver=cartesian_solver,
        reltol=cartesian_reltol,
        abstol=cartesian_abstol,
    )

    entry_continuity = _transition_diagnostics(
        converted_system,
        entry_state,
        regularized_segment.entry_state,
        entry_time,
        (i, j),
    )
    exit_continuity = _transition_diagnostics(
        converted_system,
        regularized_segment.exit_state,
        Vector{T}(after.solution(exit_time)),
        exit_time,
        (i, j),
    )

    times = _composition_sample_times(
        T, (t0, tf), saveat, before, regularized_segment, after,
    )

    statistics = (
        _segment_solver_statistics(:cartesian_before, before.solution),
        _segment_solver_statistics(
            :regularized, regularized_segment.regularized_result.solution,
        ),
        _segment_solver_statistics(:cartesian_after, after.solution),
    )

    provisional = ComposedRegularizedTrajectory{
        T,typeof(converted_system),typeof(before),typeof(regularized_segment),typeof(after)
    }(
        converted_system,
        (i, j),
        (t0, tf),
        (entry_time, exit_time),
        before,
        regularized_segment,
        after,
        entry_continuity,
        exit_continuity,
        times,
        Vector{Vector{T}}(),
        statistics,
    )
    states = [composed_regularized_state(provisional, time) for time in times]

    ComposedRegularizedTrajectory{
        T,typeof(converted_system),typeof(before),typeof(regularized_segment),typeof(after)
    }(
        converted_system,
        (i, j),
        (t0, tf),
        (entry_time, exit_time),
        before,
        regularized_segment,
        after,
        entry_continuity,
        exit_continuity,
        times,
        states,
        statistics,
    )
end

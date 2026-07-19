"""Summary diagnostics for one explicit coupled KS segment."""
struct KSSegmentDiagnostics{T<:AbstractFloat,D,S}
    entry_transition::D
    exit_transition::D
    maximum_scaled_constraint_residual::T
    maximum_relative_energy_drift::T
    minimum_nonselected_separation::T
    solver_statistics::S
end

"""One explicitly requested pair-centred KS segment between two physical times."""
struct ExplicitKSSegment{T<:AbstractFloat,S,P,R,D}
    system::S
    pair::Tuple{Int,Int}
    start_time::T
    end_time::T
    entry_state::Vector{T}
    exit_state::Vector{T}
    exit_fictitious_time::T
    ks_problem::P
    ks_result::R
    diagnostics::D
    times::Vector{T}
    states::Vector{Vector{T}}
end

Base.length(segment::ExplicitKSSegment) = length(segment.times)
Base.getindex(segment::ExplicitKSSegment, i::Integer) = segment.states[i]

@inline function _ks_nonselected_separations(problem::KSThreeBodyProblem, y)
    state = ks_three_body_cartesian_state(problem, y)
    i, j = problem.pair
    k = problem.third
    (
        norm(body_position(state, i) - body_position(state, k)),
        norm(body_position(state, j) - body_position(state, k)),
    )
end

function _ks_segment_solve(
    problem::KSThreeBodyProblem{T}, target_time::T;
    algorithm=Vern9(), reltol=nothing, abstol=nothing,
    initial_fictitious_span=nothing, max_expansions::Integer=32,
    nonselected_threshold::Real=zero(T), kwargs...,
) where {T}
    max_expansions > 0 || throw(ArgumentError("max_expansions must be positive."))
    threshold = T(nonselected_threshold)
    isfinite(threshold) && threshold >= zero(T) ||
        throw(ArgumentError("nonselected_threshold must be finite and nonnegative."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    isfinite(rt) && rt > zero(T) || throw(ArgumentError("reltol must be finite and positive."))
    isfinite(at) && at > zero(T) || throw(ArgumentError("abstol must be finite and positive."))

    y0 = ks_initial_state(problem)
    if threshold > zero(T)
        d1, d2 = _ks_nonselected_separations(problem, y0)
        min(d1, d2) <= threshold &&
            throw(DomainError(threshold, "A nonselected pair already lies within the configured close-encounter threshold."))
    end
    rho0 = max(dot(problem.u0, problem.u0), sqrt(eps(T)))
    estimate = (target_time - problem.initial_time) / rho0
    span = isnothing(initial_fictitious_span) ? max(one(T), T(2) * estimate) : T(initial_fictitious_span)
    isfinite(span) && span > zero(T) ||
        throw(ArgumentError("initial_fictitious_span must be finite and positive."))

    for _ in 1:max_expansions
        reason = Ref(:none)
        target_condition(y, s, integrator) = y[10] - target_time
        target_affect!(integrator) = (reason[] = :target; SciMLBase.terminate!(integrator))
        target_callback = SciMLBase.ContinuousCallback(
            target_condition, target_affect!, nothing; save_positions=(true, true),
        )
        callbacks = Any[target_callback]
        if threshold > zero(T)
            for which in 1:2
                condition(y, s, integrator) = _ks_nonselected_separations(problem, y)[which] - threshold
                affect!(integrator) = (reason[] = :nonselected; SciMLBase.terminate!(integrator))
                push!(callbacks, SciMLBase.ContinuousCallback(condition, affect!))
            end
        end
        callback = SciMLBase.CallbackSet(callbacks...)
        rhs(y, p, s) = ks_three_body_rhs(y, p)
        solution = solve(
            ODEProblem(rhs, y0, (zero(T), span), problem), algorithm;
            reltol=rt, abstol=at, callback=callback, dense=true, kwargs...,
        )
        SciMLBase.successful_retcode(solution) ||
            error("Explicit KS segment integration failed with retcode $(solution.retcode).")
        reason[] === :nonselected &&
            throw(DomainError(threshold, "A nonselected pair reached the configured close-encounter threshold."))
        if reason[] === :target
            return solution
        end
        span *= T(2)
        isfinite(span) || error("Fictitious-time search span overflowed before reaching the target physical time.")
    end
    error("Explicit KS segment did not reach the requested physical time within max_expansions.")
end

function _ks_segment_diagnostics(system, problem, result, entry_state, exit_state, start_time, end_time)
    T = eltype(entry_state)
    entry_reconstructed = ks_three_body_cartesian_state(problem, ks_initial_state(problem))
    entry_diag = _transition_diagnostics(system, entry_state, entry_reconstructed, start_time, problem.pair)
    exit_reconstructed = ks_three_body_cartesian_state(problem, result.solution.u[end])
    exit_diag = _transition_diagnostics(system, exit_state, exit_reconstructed, end_time, problem.pair)
    initial_energy = total_energy(system, entry_state)
    energy_scale = max(one(T), abs(initial_energy))
    max_constraint = zero(T)
    max_energy = zero(T)
    min_nonselected = T(Inf)
    for y in result.solution.u
        u, w, _, _, _, _, _, _ = ks_unpack_three_body_state(y)
        max_constraint = max(max_constraint, T(ks_scaled_constraint_residual(u, w)))
        state = ks_three_body_cartesian_state(problem, y)
        max_energy = max(max_energy, abs(total_energy(system, state) - initial_energy) / energy_scale)
        d1, d2 = _ks_nonselected_separations(problem, y)
        min_nonselected = min(min_nonselected, T(d1), T(d2))
    end
    KSSegmentDiagnostics(
        entry_diag, exit_diag, max_constraint, max_energy, min_nonselected,
        _segment_solver_statistics(:ks_regularized, result.solution),
    )
end

"""
    propagate_ks_segment(system, state, pair, start_time, end_time; kwargs...)

Propagate one explicit Cartesian → coupled KS → Cartesian segment. The retained
ODE solution is terminated at `end_time` and is used for all later dense
physical-time evaluation; evaluation never reintegrates the segment.
"""
function propagate_ks_segment(
    system::ThreeBodySystem,
    state::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer},
    start_time::Real,
    end_time::Real;
    reference=nothing,
    kwargs...,
)
    validate_state(state)
    i, j, _ = _validate_pair(pair)
    T = float(promote_type(eltype(system.masses), eltype(state), typeof(start_time), typeof(end_time)))
    converted_system = ThreeBodySystem(Tuple(T.(system.masses)); G=T(system.G))
    entry = Vector{T}(state)
    t0 = T(start_time)
    tf = T(end_time)
    all(isfinite, (t0, tf)) || throw(ArgumentError("start_time and end_time must be finite."))
    tf < t0 && throw(ArgumentError("end_time must not precede start_time."))
    tf == t0 && throw(ArgumentError("end_time must differ from start_time."))

    problem = KSThreeBodyProblem(converted_system, entry, (i, j); reference=reference, initial_time=t0)
    solution = _ks_segment_solve(problem, tf; kwargs...)
    result = KSThreeBodyResult(problem, solution)
    sf = T(solution.t[end])
    reached = T(solution.u[end][10])
    time_tolerance = T(256) * eps(T) * max(one(T), abs(tf))
    abs(reached - tf) <= time_tolerance ||
        error("Explicit KS segment terminated at physical time $reached instead of $tf.")
    exit_state = Vector{T}(ks_three_body_cartesian_state(problem, solution.u[end]))
    times = T[T(y[10]) for y in solution.u]
    states = [Vector{T}(ks_three_body_cartesian_state(problem, y)) for y in solution.u]
    diagnostics = _ks_segment_diagnostics(
        converted_system, problem, result, entry, exit_state, t0, tf,
    )
    ExplicitKSSegment{T,typeof(converted_system),typeof(problem),typeof(result),typeof(diagnostics)}(
        converted_system, (i, j), t0, tf, entry, exit_state, sf,
        problem, result, diagnostics, times, states,
    )
end

function ks_segment_state(
    segment::ExplicitKSSegment{T}, physical_time::Real;
    tolerance=nothing, max_iterations::Integer=256,
) where {T}
    target = T(physical_time)
    isfinite(target) || throw(ArgumentError("physical_time must be finite."))
    segment.start_time <= target <= segment.end_time ||
        throw(ArgumentError("physical_time lies outside the KS segment."))
    target == segment.start_time && return copy(segment.entry_state)
    target == segment.end_time && return copy(segment.exit_state)
    max_iterations > 0 || throw(ArgumentError("max_iterations must be positive."))
    tol = isnothing(tolerance) ? T(64) * eps(T) : T(tolerance)
    isfinite(tol) && tol > zero(T) || throw(ArgumentError("tolerance must be finite and positive."))
    solution = segment.ks_result.solution
    left = zero(T)
    right = segment.exit_fictitious_time
    for _ in 1:max_iterations
        middle = (left + right) / T(2)
        middle_time = T(solution(middle)[10])
        if middle_time < target
            left = middle
        else
            right = middle
        end
        if abs(right - left) <= tol * max(one(T), abs(left), abs(right))
            return Vector{T}(ks_three_body_cartesian_state(segment.ks_problem, solution((left + right) / T(2))))
        end
    end
    error("Unable to invert retained KS Sundman time for the requested physical time.")
end

(segment::ExplicitKSSegment)(physical_time::Real) = ks_segment_state(segment, physical_time)

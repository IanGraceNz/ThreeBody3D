"""Entry transition diagnostics for the coupled spatial KS representation."""
function _ks_entry_transition_diagnostics(system, state, time, pair, reference)
    problem = KSThreeBodyProblem(
        system, state, pair; reference=reference, initial_time=time,
    )
    reconstructed = ks_three_body_cartesian_state(problem, ks_initial_state(problem))
    _transition_diagnostics(system, state, reconstructed, time, pair)
end

"""
    locate_ks_regularized_exit_event(system, state, pair, entry_time, target_time,
                                     parameters; kwargs...)

Propagate one coupled spatial KS segment and locate either the selected pair's
first certified outward exit-threshold crossing or the requested target
physical time. The retained dense solution is returned in the ordinary
`RegularizedExitLocationResult` container so the experimental controller and
its unified sampling layer remain backend-independent.
"""
function locate_ks_regularized_exit_event(
    system::ThreeBodySystem,
    state::AbstractVector{<:AbstractFloat},
    pair::Tuple{<:Integer,<:Integer},
    entry_time::Real,
    target_time::Real,
    parameters::AutomaticSwitchingParameters;
    reference=nothing,
    initial_fictitious_span=nothing,
    max_expansions::Integer=32,
    algorithm=Vern9(),
    reltol=nothing,
    abstol=nothing,
    saveat=nothing,
    nonselected_threshold::Real=parameters.enter_threshold,
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
    max_expansions > 0 || throw(ArgumentError("max_expansions must be positive."))

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

    problem = KSThreeBodyProblem(
        converted_system, entry, (i, j); reference=reference, initial_time=t_entry,
    )
    y0 = ks_initial_state(problem)
    rho0 = max(dot(problem.u0, problem.u0), sqrt(eps(T)))
    estimate = (t_target - t_entry) / rho0
    span = isnothing(initial_fictitious_span) ? max(one(T), T(2) * estimate) : T(initial_fictitious_span)
    isfinite(span) && span > zero(T) ||
        throw(ArgumentError("initial_fictitious_span must be finite and positive."))
    threshold = T(nonselected_threshold)
    isfinite(threshold) && threshold >= zero(T) ||
        throw(ArgumentError("nonselected_threshold must be finite and nonnegative."))
    rt = isnothing(reltol) ? T(1e-12) : T(reltol)
    at = isnothing(abstol) ? T(1e-12) : T(abstol)
    isfinite(rt) && rt > zero(T) || throw(ArgumentError("reltol must be finite and positive."))
    isfinite(at) && at > zero(T) || throw(ArgumentError("abstol must be finite and positive."))

    for _ in 1:max_expansions
        reason = Ref(:none)
        exit_condition(y, _s, _integrator) = dot(view(y, 1:4), view(y, 1:4)) - T(parameters.exit_threshold)
        function exit_affect!(integrator)
            reconstructed = ks_three_body_cartesian_state(problem, integrator.u)
            observables = pair_observables(reconstructed)
            selected = _canonical_pair_index((i, j))
            if observables.radial_rates[selected] > zero(T)
                reason[] = :exit
                SciMLBase.terminate!(integrator)
            end
        end
        target_condition(y, _s, _integrator) = y[10] - t_target
        target_affect!(integrator) = (reason[] = :target; SciMLBase.terminate!(integrator))
        callbacks = Any[
            SciMLBase.ContinuousCallback(exit_condition, exit_affect!, nothing; save_positions=(true, true)),
            SciMLBase.ContinuousCallback(target_condition, target_affect!, nothing; save_positions=(true, true)),
        ]
        if threshold > zero(T)
            for which in 1:2
                condition(y, _s, _integrator) = _ks_nonselected_separations(problem, y)[which] - threshold
                affect!(integrator) = (reason[] = :nonselected; SciMLBase.terminate!(integrator))
                push!(callbacks, SciMLBase.ContinuousCallback(condition, affect!, nothing))
            end
        end
        callback = SciMLBase.CallbackSet(callbacks...)
        rhs(y, p, s) = ks_three_body_rhs(y, p)
        # Automatic switching requires a valid retained dense solution for
        # physical-time inversion. OrdinaryDiffEq does not support combining
        # dense interpolation with `saveat`; doing so can leave interpolation
        # caches inconsistent with the saved solution vectors. Retain every
        # accepted step instead. `saveat` remains accepted for compatibility
        # with the backend-independent controller keyword interface.
        _ = saveat
        solution = solve(
            ODEProblem(rhs, y0, (zero(T), span), problem), algorithm;
            reltol=rt, abstol=at, callback=callback, dense=true,
            save_everystep=true, kwargs...,
        )
        SciMLBase.successful_retcode(solution) ||
            error("Automatic KS segment failed with retcode $(solution.retcode).")
        result = KSThreeBodyResult(problem, solution)
        terminal_y = solution.u[end]
        terminal_s = T(solution.t[end])
        terminal_time = T(terminal_y[10])
        terminal_state = Vector{T}(ks_three_body_cartesian_state(problem, terminal_y))
        observables = pair_observables(terminal_state)

        if reason[] === :nonselected
            decision = _failure_decision(:nonselected_pair_unsafe, (i, j))
            return RegularizedExitLocationResult(
                :failure, terminal_time, terminal_s, terminal_state,
                problem, result, decision, observables,
            )
        elseif reason[] === :exit
            decision = _certified_exit_decision(observables, parameters, (i, j))
            status = decision.action === :exit ? :exit : :failure
            return RegularizedExitLocationResult(
                status, terminal_time, terminal_s, terminal_state,
                problem, result, decision, observables,
            )
        elseif reason[] === :target
            decision = automatic_exit_decision(observables, parameters, (i, j))
            if decision.action === :failure
                return RegularizedExitLocationResult(
                    :failure, terminal_time, terminal_s, terminal_state,
                    problem, result, decision, observables,
                )
            end
            return RegularizedExitLocationResult(
                :completed, terminal_time, terminal_s, terminal_state,
                problem, result,
                AutomaticSwitchingDecision(:none, (i, j), :exit_threshold_not_reached),
                observables,
            )
        end

        span *= T(2)
        isfinite(span) || error("Fictitious-time search span overflowed before KS exit or target time.")
    end
    error("Automatic KS segment did not reach an exit or target time within max_expansions.")
end

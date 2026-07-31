# Investigation 1 adapter for the fixed-policy regularization-backend comparison.

using LinearAlgebra: norm
using OrdinaryDiffEq: Vern9

const KS_SWITCHING_INVESTIGATION_VERSION = "1.0.0"
const KS_SWITCHING_INVESTIGATION_BACKENDS = (:ks, :levi_civita)
const KS_SWITCHING_REQUIRED_METRICS = (
    :integration_status, :final_time_residual,
    :maximum_scaled_backend_state_discrepancy,
    :maximum_relative_energy_drift, :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift, :maximum_center_of_mass_residual,
    :minimum_pair_separation,
)
const KS_SWITCHING_OPTIONAL_METRICS = (
    :entry_event_time_discrepancy, :exit_event_time_discrepancy,
    :maximum_transition_state_residual,
    :entry_state_residual, :exit_state_residual,
    :entry_physical_time, :exit_physical_time,
    :entry_crossing_certified, :exit_crossing_certified,
    :entry_crossing_provenance, :exit_crossing_provenance,
    :crossing_kinds, :crossing_certifications,
    :crossing_provenances, :crossing_reasons,
    :entry_sundman_time, :exit_sundman_time,
    :entry_ambiguity_margin, :exit_ambiguity_margin,
    :entry_isolation_ratio, :exit_isolation_ratio,
    :entry_candidate_count, :exit_candidate_count,
    :entry_crossing_reason, :exit_crossing_reason,
    :entry_separations, :exit_separations,
    :entry_radial_rates, :exit_radial_rates,
    :entry_candidate_is_closest, :exit_candidate_is_closest,
    :entry_candidate_tied_for_closest, :exit_candidate_tied_for_closest,
)

"""Resolved execution and evaluation settings for the fixed KS comparison."""
function _ks_switching_fixed_settings(; enter_threshold=0.2)
    cartesian = (
        solver=:accurate, algorithm=:Vern9, reltol=1e-12, abstol=1e-12,
        maxiters=10^7, precision=256, sampling=:dense_solution_without_saveat,
    )
    levi_civita = (
        algorithm=:Vern9, reltol=1e-12, abstol=1e-12,
        initial_step=1.0, targeting_tolerance=sqrt(eps(Float64)),
        targeting_max_iterations=256, sampling=:dense_solution_without_saveat,
    )
    ks = (
        algorithm=:Vern9, reltol=1e-12, abstol=1e-12,
        max_fictitious_span_expansions=32,
        initial_fictitious_span_rule=:maximum_of_one_and_twice_remaining_physical_time_over_regularized_radius_squared,
        initial_fictitious_span_inputs=(
            :requested_final_time, :regularized_segment_entry_time,
            :maximum_of_ks_radius_squared_and_sqrt_machine_epsilon,
            eps(Float64),
        ),
        nonselected_pair_threshold_rule=:equal_to_entry_threshold,
        nonselected_pair_threshold=enter_threshold,
        sampling=:dense_solution_without_saveat,
    )
    evaluation = (tolerance=100 * eps(Float64), max_iterations=256)
    (
        cartesian,
        levi_civita,
        ks,
        evaluation,
        cartesian_kwargs=(
            solver=cartesian.solver, reltol=cartesian.reltol,
            abstol=cartesian.abstol, maxiters=cartesian.maxiters,
            precision=cartesian.precision, saveat=nothing,
        ),
        levi_civita_kwargs=(
            algorithm=Vern9(), reltol=levi_civita.reltol,
            abstol=levi_civita.abstol, initial_step=levi_civita.initial_step,
            tolerance=levi_civita.targeting_tolerance,
            max_iterations=levi_civita.targeting_max_iterations,
            saveat=nothing,
        ),
        ks_kwargs=(
            algorithm=Vern9(), reltol=ks.reltol, abstol=ks.abstol,
            initial_fictitious_span=nothing,
            max_expansions=ks.max_fictitious_span_expansions,
            nonselected_threshold=ks.nonselected_pair_threshold,
            saveat=nothing,
        ),
        evaluation_kwargs=evaluation,
    )
end

function _ks_switching_investigation_initial_state()
    (
        -0.5, 0.0, 0.0, 0.5, 0.0, 0.0,
         0.5, 0.0, 0.0, -0.5, 0.0, 0.0,
        10.0, 0.0, 0.0, 0.0, 0.0, 0.0,
    )
end

"""One ordered retained switching decision and its original evidence records."""
struct KSSwitchingCrossingObservation
    sequence_number::Int
    kind::Symbol
    successful_switch::Bool
    physical_time::Float64
    sundman_time::Union{Nothing,Float64}
    event::Any
    decision::Any
    competition_evidence::Any
    progress_evidence::Any
end

"""Complete immutable production evidence for one switching backend."""
struct KSSwitchingBackendReport{S,D,O,E}
    backend::Symbol
    definition::ValidationCaseDefinition
    configuration::ValidationConfiguration
    environment::ValidationEnvironment
    execution::ExecutionOutcome
    final_time::Float64
    samples::S
    diagnostics::D
    solver_statistics::SolverStatistics
    crossing_observations::O
    switch_events::E
    maximum_scaled_backend_state_discrepancy::Union{Nothing,Float64}
    entry_event_time_discrepancy::Union{Nothing,Float64}
    exit_event_time_discrepancy::Union{Nothing,Float64}
end

function _ks_switching_solution(segment)
    location = segment.location
    if hasproperty(location, :simulation) && !isnothing(location.simulation)
        return location.simulation.solution
    end
    if hasproperty(location, :regularized_result) && !isnothing(location.regularized_result)
        return location.regularized_result.solution
    end
    nothing
end


function _ks_switching_solver_statistics(trajectory)
    accepted = rejected = rhs = saved = 0
    for segment in trajectory.segments
        solution = _ks_switching_solution(segment)
        isnothing(solution) && continue
        accepted += solution.stats.naccept
        rejected += solution.stats.nreject
        rhs += solution.stats.nf
        saved += length(solution.t)
    end
    SolverStatistics(
        accepted_steps=accepted, rejected_steps=rejected,
        rhs_evaluations=rhs, saved_states=saved,
        segment_count=length(trajectory.segments),
        switch_count=length(trajectory.switch_events),
    )
end

function _ks_switching_crossing_observations(trajectory)
    observations = KSSwitchingCrossingObservation[]
    event_index = 1
    for segment in trajectory.segments
        location = segment.location
        hasproperty(location, :decision) || continue
        decision = location.decision
        status = location.status
        status in (:entry, :exit, :failure) || continue
        event = if event_index <= length(trajectory.switch_events) &&
                   trajectory.switch_events[event_index].kind == status
            retained = trajectory.switch_events[event_index]
            event_index += 1
            retained
        else
            nothing
        end
        evidence = decision.evidence
        competition = isnothing(evidence) || !hasproperty(evidence, :competition) ?
            nothing : evidence.competition
        progress = !isnothing(trajectory.failure) &&
            trajectory.failure.physical_time == location.physical_time ?
            trajectory.failure.progress_evidence : nothing
        kind = isnothing(event) ? :terminal_decision : event.kind
        push!(observations, KSSwitchingCrossingObservation(
            length(observations) + 1, kind, !isnothing(event),
            Float64(location.physical_time),
            hasproperty(location, :fictitious_time) ? Float64(location.fictitious_time) : nothing,
            event, decision, competition, progress,
        ))
    end
    if !isnothing(trajectory.failure) && !isnothing(trajectory.failure.progress_evidence) &&
       (isempty(observations) || isnothing(last(observations).progress_evidence))
        progress = trajectory.failure.progress_evidence
        push!(observations, KSSwitchingCrossingObservation(
            length(observations) + 1, :progress_failure, false,
            Float64(trajectory.failure.physical_time), nothing,
            nothing, nothing, nothing, progress,
        ))
    end
    Tuple(observations)
end

function _ks_switching_sample_trajectory(
    trajectory; sample_count=161, evaluation_kwargs=(tolerance=100 * eps(Float64), max_iterations=256),
)
    t0 = first(trajectory.tspan)
    tf = trajectory.final_time
    times = tf == t0 ? [t0] : collect(range(t0, tf; length=sample_count))
    ThreeBody3D.sample_experimental_switching(
        trajectory, times; include_switches=trajectory.status != :completed,
        regularized_kwargs=evaluation_kwargs,
    )
end

function _ks_switching_execution(trajectory)
    trajectory.status == :completed && return ExecutionOutcome(actual_completed; exit_code=0)
    summary = isnothing(trajectory.failure) ?
        "Switching trajectory terminated." : trajectory.failure.message
    ExecutionOutcome(actual_terminated; exit_code=1, summary)
end

function _ks_switching_first_event_time(trajectory, kind)
    event = findfirst(item -> item.kind == kind, trajectory.switch_events)
    isnothing(event) ? nothing : trajectory.switch_events[event].physical_time
end

function _ks_switching_maximum_transition_residual(trajectory)
    isempty(trajectory.switch_events) && return nothing
    maximum(event.transition_diagnostics.state_residual for event in trajectory.switch_events)
end

function _build_ks_switching_backend_report(
    backend, trajectory, samples, diagnostics, configuration, environment;
    maximum_scaled_backend_state_discrepancy=nothing,
    entry_event_time_discrepancy=nothing,
    exit_event_time_discrepancy=nothing,
)
    KSSwitchingBackendReport(
        backend, ks_switching_comparison_case_definition(), configuration,
        environment, _ks_switching_execution(trajectory), Float64(trajectory.final_time),
        samples, diagnostics, _ks_switching_solver_statistics(trajectory),
        _ks_switching_crossing_observations(trajectory), Tuple(trajectory.switch_events),
        isnothing(maximum_scaled_backend_state_discrepancy) ? nothing :
            Float64(maximum_scaled_backend_state_discrepancy),
        isnothing(entry_event_time_discrepancy) ? nothing : Float64(entry_event_time_discrepancy),
        isnothing(exit_event_time_discrepancy) ? nothing : Float64(exit_event_time_discrepancy),
    )
end


"""Build both production backend reports without sampling beyond either trajectory."""
function build_ks_switching_backend_reports(
    ks, levi_civita, configuration::ValidationConfiguration,
    environment::ValidationEnvironment;
    comparison_sample_count=161,
    fixed_settings=_ks_switching_fixed_settings(),
)
    ks_samples = _ks_switching_sample_trajectory(
        ks; sample_count=comparison_sample_count,
        evaluation_kwargs=fixed_settings.evaluation_kwargs,
    )
    lc_samples = _ks_switching_sample_trajectory(
        levi_civita; sample_count=comparison_sample_count,
        evaluation_kwargs=fixed_settings.evaluation_kwargs,
    )
    ks_diagnostics = ThreeBody3D.diagnostics_report(ks, ks_samples)
    lc_diagnostics = ThreeBody3D.diagnostics_report(levi_civita, lc_samples)

    maximum_difference = entry_difference = exit_difference = nothing
    if ks.status == :completed && levi_civita.status == :completed
        maximum_difference = maximum(
            norm(ks_state - lc_state) / max(1.0, norm(lc_state))
            for (ks_state, lc_state) in zip(ks_samples.states, lc_samples.states)
        )
        ks_entry = _ks_switching_first_event_time(ks, :entry)
        lc_entry = _ks_switching_first_event_time(levi_civita, :entry)
        ks_exit = _ks_switching_first_event_time(ks, :exit)
        lc_exit = _ks_switching_first_event_time(levi_civita, :exit)
        !isnothing(ks_entry) && !isnothing(lc_entry) &&
            (entry_difference = abs(ks_entry - lc_entry))
        !isnothing(ks_exit) && !isnothing(lc_exit) &&
            (exit_difference = abs(ks_exit - lc_exit))
    end
    common = (
        maximum_scaled_backend_state_discrepancy=maximum_difference,
        entry_event_time_discrepancy=entry_difference,
        exit_event_time_discrepancy=exit_difference,
    )
    (
        ks=_build_ks_switching_backend_report(
            :ks, ks, ks_samples, ks_diagnostics, configuration, environment; common...,
        ),
        levi_civita=_build_ks_switching_backend_report(
            :levi_civita, levi_civita, lc_samples, lc_diagnostics,
            configuration, environment; common...,
        ),
        common...,
    )
end

function _ks_switching_investigation_configuration(;
    fixed_settings=_ks_switching_fixed_settings(),
)
    _ks_switching_comparison_configuration(
        masses=(1e-12, 1e-12, 1e-12), gravitational_constant=1.0,
        initial_state=_ks_switching_investigation_initial_state(), selected_pair=(1, 2),
        physical_time_interval=(0.0, 1.6), comparison_sample_count=161,
        enter_threshold=0.2, exit_threshold=0.4, ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0, maximum_switches=10,
        minimum_time_progress=eps(Float64), minimum_separation_excursion=0.0,
        threshold_scale_kind=:absolute, threshold_reference_scale=1.0,
        fixed_settings=fixed_settings,
        state_difference_limit=2e-8, event_time_difference_limit=2e-6,
        transition_residual_limit=1e-11,
    )
end

function _ks_switching_fixed_controls(configuration::ValidationConfiguration)
    (
        ValidationParameter(:solver, configuration.solver),
        ValidationParameter(:time_interval, configuration.time_interval),
        ValidationParameter(:sampling, configuration.sampling),
        ValidationParameter(:selected_pair, configuration.selected_pair),
        configuration.thresholds...,
        configuration.parameters...,
    )
end

"""Define the fixed-policy KS/Levi-Civita backend experiment."""
function ks_switching_backend_investigation_definition()
    configuration = _ks_switching_investigation_configuration()
    InvestigationDefinition(
        :ks_switching_backend,
        "Fixed-policy regularization-backend comparison",
        "Compare KS and Levi-Civita propagation under the existing automatic-switching policy.",
        ks_switching_comparison_case_definition(),
        :regularization_backend,
        _ks_switching_fixed_controls(configuration),
        KS_SWITCHING_REQUIRED_METRICS,
        KS_SWITCHING_OPTIONAL_METRICS,
        KS_SWITCHING_INVESTIGATION_VERSION,
    )
end

function _validate_ks_switching_report(report, result)
    all(field -> hasproperty(report, field),
        (:backend, :definition, :configuration, :environment, :execution,
         :final_time, :samples, :diagnostics, :solver_statistics,
         :crossing_observations)) || throw(ArgumentError(
        "KS switching reports must retain the complete structured report contract.",
    ))
    report.backend in KS_SWITCHING_INVESTIGATION_BACKENDS ||
        throw(ArgumentError("Unsupported regularization backend $(report.backend)."))
    report.definition isa ValidationCaseDefinition || throw(ArgumentError("Invalid report definition."))
    report.configuration isa ValidationConfiguration || throw(ArgumentError("Invalid report configuration."))
    report.environment isa ValidationEnvironment || throw(ArgumentError("Invalid report environment."))
    report.execution isa ExecutionOutcome || throw(ArgumentError("Invalid report execution."))
    report.solver_statistics isa SolverStatistics || throw(ArgumentError("Invalid solver statistics."))
    report isa KSSwitchingBackendReport || throw(ArgumentError("Invalid KS switching backend report."))
    _record_fields_equal(report.definition, result.definition) || throw(ArgumentError("Benchmark identity or version mismatch."))
    _record_fields_equal(report.configuration, result.configuration) || throw(ArgumentError("Benchmark configuration mismatch."))
    _record_fields_equal(report.environment, result.environment) || throw(ArgumentError("Benchmark provenance mismatch."))
    report
end

function _ks_metric!(metrics, source, field, id, label; kwargs...)
    hasproperty(source, field) || return
    value = getproperty(source, field)
    isnothing(value) && return
    push!(metrics, ValidationMetric(id, label, value; kwargs...))
end

function _ks_switching_metrics(report, execution, configuration)
    metrics = AbstractValidationMetric[
        ValidationMetric(:integration_status, "Integration status", Symbol(stable_string(execution.actual)); role=role_diagnostic),
    ]
    _ks_metric!(metrics, report, :final_time, :final_time_residual, "Final-time residual";
        scale=scale_duration, role=role_diagnostic, aggregation=aggregation_final)
    metrics[end] = ValidationMetric(:final_time_residual, "Final-time residual",
        abs(report.final_time - last(configuration.time_interval)); scale=scale_duration,
        role=role_diagnostic, aggregation=aggregation_final)
    _ks_metric!(metrics, report, :maximum_scaled_backend_state_discrepancy,
        :maximum_scaled_backend_state_discrepancy, "Maximum scaled backend state discrepancy";
        scale=scale_relative, role=role_descriptive, aggregation=aggregation_maximum)
    _ks_metric!(metrics, report, :entry_event_time_discrepancy,
        :entry_event_time_discrepancy, "Entry-event time discrepancy";
        scale=scale_duration, role=role_descriptive)
    _ks_metric!(metrics, report, :exit_event_time_discrepancy,
        :exit_event_time_discrepancy, "Exit-event time discrepancy";
        scale=scale_duration, role=role_descriptive)
    diagnostics = report.diagnostics
    for (field, id, label, scale, aggregation) in (
        (:maximum_relative_energy_drift, :maximum_relative_energy_drift, "Maximum relative energy drift", scale_relative, aggregation_maximum),
        (:maximum_linear_momentum_drift, :maximum_linear_momentum_drift, "Maximum linear-momentum drift", scale_absolute, aggregation_maximum),
        (:maximum_angular_momentum_drift, :maximum_angular_momentum_drift, "Maximum angular-momentum drift", scale_absolute, aggregation_maximum),
        (:maximum_center_of_mass_residual, :maximum_center_of_mass_residual, "Maximum centre-of-mass residual", scale_absolute, aggregation_maximum),
        (:minimum_separation, :minimum_pair_separation, "Minimum pair separation", scale_absolute, aggregation_minimum),
    )
        _ks_metric!(metrics, diagnostics, field, id, label; scale, role=role_descriptive, aggregation)
    end
    isempty(report.switch_events) || _ks_metric!(
        metrics, diagnostics, :maximum_transition_state_residual,
        :maximum_transition_state_residual, "Maximum transition state residual";
        scale=scale_absolute, role=role_descriptive, aggregation=aggregation_maximum,
    )
    observations = report.crossing_observations
    if !isempty(observations)
        provenances = map(observation -> isnothing(observation.competition_evidence) ?
            :unavailable : observation.competition_evidence.crossing_provenance, observations)
        certifications = map(provenances) do provenance
            provenance in (
                :certified_cartesian_entry,
                :certified_regularized_exit,
                :certified_nonselected_pair_crossing,
            )
        end
        reasons = map(observations) do observation
            !isnothing(observation.decision) ? observation.decision.reason :
                observation.progress_evidence.reason
        end
        for (id, label, values) in (
            (:crossing_kinds, "Ordered crossing kinds", map(item -> item.kind, observations)),
            (:crossing_certifications, "Ordered crossing certifications", certifications),
            (:crossing_provenances, "Ordered crossing provenances", provenances),
            (:crossing_reasons, "Ordered crossing decision reasons", reasons),
        )
            push!(metrics, ValidationMetric(id, label, Tuple(values); role=role_descriptive))
        end
    end
    for kind in (:entry, :exit)
        index = findfirst(item -> item.successful_switch && item.kind == kind, observations)
        isnothing(index) && continue
        observation = observations[index]
        event = observation.event
        competition = observation.competition_evidence
        crossing = (
            state_residual=event.transition_diagnostics.state_residual,
            physical_time=event.physical_time,
            certified=!isnothing(competition) && competition.crossing_provenance in (
                :certified_cartesian_entry,
                :certified_regularized_exit,
                :certified_nonselected_pair_crossing,
            ),
            provenance=isnothing(competition) ? nothing : competition.crossing_provenance,
            sundman_time=observation.sundman_time,
            ambiguity_margin=isnothing(competition) ? nothing : competition.ambiguity_margin,
            isolation_ratio=event.isolation_ratio,
            candidate_count=isnothing(observation.decision.evidence) ? nothing :
                observation.decision.evidence.candidate_count,
            reason=observation.decision.reason,
            separations=event.separations,
            radial_rates=event.radial_rates,
            candidate_is_closest=isnothing(competition) ? nothing : competition.candidate_is_closest,
            candidate_tied_for_closest=isnothing(competition) ? nothing : competition.candidate_tied_for_closest,
        )
        prefix = kind
        for (field, suffix, label, scale) in (
            (:state_residual, :state_residual, "state residual", scale_absolute),
            (:physical_time, :physical_time, "physical time", scale_duration),
            (:certified, :crossing_certified, "crossing certified", scale_absolute),
            (:provenance, :crossing_provenance, "crossing provenance", scale_absolute),
            (:sundman_time, :sundman_time, "Sundman time", scale_duration),
            (:ambiguity_margin, :ambiguity_margin, "ambiguity margin", scale_absolute),
            (:isolation_ratio, :isolation_ratio, "isolation ratio", scale_absolute),
            (:candidate_count, :candidate_count, "candidate count", scale_count),
            (:reason, :crossing_reason, "crossing reason", scale_absolute),
            (:separations, :separations, "pair separations", scale_absolute),
            (:radial_rates, :radial_rates, "radial rates", scale_absolute),
            (:candidate_is_closest, :candidate_is_closest, "candidate is closest", scale_absolute),
            (:candidate_tied_for_closest, :candidate_tied_for_closest, "candidate tied for closest", scale_absolute),
        )
            _ks_metric!(metrics, crossing, field, Symbol(prefix, :_, suffix), "$(uppercasefirst(string(prefix))) $label";
                scale, role=role_descriptive)
        end
    end
    Tuple(metrics)
end

"""
Build the explicitly ordered backend series. An unsuccessful backend outcome is
primary; otherwise the combined comparison outcome is retained.
"""
function ks_switching_backend_investigation_series(result::ValidationCaseResult, backend_reports)
    _record_fields_equal(result.definition, ks_switching_comparison_case_definition()) ||
        throw(ArgumentError("KS switching benchmark identity or version mismatch."))
    _record_fields_equal(result.configuration, _ks_switching_investigation_configuration()) ||
        throw(ArgumentError("KS switching configuration does not match the approved fixed controls."))
    reports = Dict{Symbol,Any}()
    for report in Tuple(backend_reports)
        _validate_ks_switching_report(report, result)
        haskey(reports, report.backend) && throw(ArgumentError("Duplicate KS switching report for $(report.backend)."))
        reports[report.backend] = report
    end
    definition = ks_switching_backend_investigation_definition()
    points = map(KS_SWITCHING_INVESTIGATION_BACKENDS) do backend
        haskey(reports, backend) || throw(ArgumentError("Missing KS switching report for $backend."))
        report = reports[backend]
        execution = report.execution.actual == actual_completed ? result.execution : report.execution
        InvestigationMeasurementPoint(
            backend, definition, result.configuration,
            ValidationParameter(:regularization_backend, backend), result.environment,
            execution, _ks_switching_metrics(report, execution, result.configuration),
            report.solver_statistics;
            supporting_evidence=report,
            notes=isnothing(report.execution.summary) ? result.execution.summary : report.execution.summary,
        )
    end
    InvestigationMeasurementSeries(
        :ks_switching_backend, "Fixed-policy regularization-backend comparison",
        "Ordered Investigation 1 measurements for KS and Levi-Civita propagation.",
        definition, Tuple(points),
    )
end

function _ks_investigation_configuration(;
    selected_pair=(1, 2),
    fixed_settings=ValidationFramework._ks_switching_fixed_settings(),
)
    ValidationFramework._ks_switching_comparison_configuration(
        masses=(1e-12, 1e-12, 1e-12), gravitational_constant=1.0,
        initial_state=ValidationFramework._ks_switching_investigation_initial_state(),
        selected_pair=selected_pair, physical_time_interval=(0.0, 1.6), comparison_sample_count=161,
        enter_threshold=0.2, exit_threshold=0.4, ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0, maximum_switches=10,
        minimum_time_progress=eps(Float64), minimum_separation_excursion=0.0,
        threshold_scale_kind=:absolute, threshold_reference_scale=1.0,
        fixed_settings=fixed_settings,
        state_difference_limit=2e-8, event_time_difference_limit=2e-6,
        transition_residual_limit=1e-11,
    )
end

function _ks_production_trajectories()
    TB = ValidationFramework.ThreeBody3D
    system = TB.ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
    parameters = TB.AutomaticSwitchingParameters(
        enter_threshold=0.2, exit_threshold=0.4,
        ambiguity_threshold=0.3, minimum_separation_ratio=2.0,
        maximum_switches=10,
    )
    fixed_settings = ValidationFramework._ks_switching_fixed_settings(
        enter_threshold=parameters.enter_threshold,
    )
    state = TB.statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
    )
    ks = TB.simulate_experimental_switching(
        system, state, (0.0, 1.6), parameters; regularization_backend=:ks,
        cartesian_kwargs=fixed_settings.cartesian_kwargs,
        regularized_kwargs=fixed_settings.ks_kwargs,
    )
    lc = TB.simulate_experimental_switching(
        system, state, (0.0, 1.6), parameters; regularization_backend=:levi_civita,
        cartesian_kwargs=fixed_settings.cartesian_kwargs,
        regularized_kwargs=fixed_settings.levi_civita_kwargs,
    )
    (; TB, system, parameters, fixed_settings, state, ks, lc)
end

function _ks_investigation_result(; configuration=_ks_investigation_configuration(),
    environment=performance_test_environment(),
    execution=ExecutionOutcome(actual_completed; exit_code=0))
    ValidationCaseResult(ks_switching_comparison_case_definition(), environment,
        configuration, (), (), SolverStatistics(segment_count=6, switch_count=4), execution)
end

function _replace_ks_report(report;
    definition=report.definition, configuration=report.configuration,
    environment=report.environment, execution=report.execution,
    diagnostics=report.diagnostics,
    crossing_observations=report.crossing_observations,
    switch_events=report.switch_events,
)
    ValidationFramework.KSSwitchingBackendReport(
        report.backend, definition, configuration, environment, execution,
        report.final_time, report.samples, diagnostics, report.solver_statistics,
        crossing_observations, switch_events,
        report.maximum_scaled_backend_state_discrepancy,
        report.entry_event_time_discrepancy,
        report.exit_event_time_discrepancy,
    )
end


@testset "KS switching production report builder" begin
    fixture = _ks_production_trajectories()
    environment = performance_test_environment()
    configuration = _ks_investigation_configuration()
    reports = build_ks_switching_backend_reports(
        fixture.ks, fixture.lc, configuration, environment;
        fixed_settings=fixture.fixed_settings,
    )
    result = build_ks_switching_comparison_case_result(
        fixture.ks.status, fixture.lc.status,
        length(fixture.ks.switch_events), length(fixture.lc.switch_events),
        reports.maximum_scaled_backend_state_discrepancy,
        reports.entry_event_time_discrepancy,
        reports.exit_event_time_discrepancy,
        ValidationFramework._ks_switching_maximum_transition_residual(fixture.ks),
        ValidationFramework._ks_switching_maximum_transition_residual(fixture.lc),
        161, SolverStatistics(
            segment_count=length(fixture.ks.segments) + length(fixture.lc.segments),
            switch_count=length(fixture.ks.switch_events) + length(fixture.lc.switch_events),
        ), environment; configuration, state_difference_limit=2e-8,
        event_time_difference_limit=2e-6, transition_residual_limit=1e-11,
    )
    series = ks_switching_backend_investigation_series(
        result, (reports.levi_civita, reports.ks),
    )
    metric(point, id) = only(filter(item -> item.metric_id == id, point.metrics)).value
    recorded = Dict(parameter.parameter_id => parameter.value for parameter in configuration.parameters)

    @test recorded[:cartesian_solver_profile] == fixture.fixed_settings.cartesian.solver
    @test recorded[:cartesian_algorithm] == :Vern9
    @test recorded[:cartesian_relative_tolerance] == fixture.fixed_settings.cartesian.reltol
    @test recorded[:cartesian_absolute_tolerance] == fixture.fixed_settings.cartesian.abstol
    @test recorded[:cartesian_maximum_iterations] == fixture.fixed_settings.cartesian.maxiters
    @test recorded[:cartesian_precision_bits] == fixture.fixed_settings.cartesian.precision
    @test recorded[:levi_civita_algorithm] == :Vern9
    @test recorded[:levi_civita_targeting_initial_step] == 1.0
    @test recorded[:levi_civita_targeting_tolerance] == sqrt(eps(Float64))
    @test recorded[:levi_civita_targeting_maximum_iterations] == 256
    @test recorded[:ks_algorithm] == :Vern9
    @test recorded[:ks_maximum_fictitious_span_expansions] == 32
    @test recorded[:ks_initial_fictitious_span_rule] ==
        :maximum_of_one_and_twice_remaining_physical_time_over_regularized_radius_squared
    @test recorded[:ks_nonselected_pair_threshold] == fixture.parameters.enter_threshold
    @test recorded[:regularized_evaluation_tolerance] == 100 * eps(Float64)
    @test recorded[:regularized_evaluation_maximum_iterations] == 256
    @test !occursin("profile_defaults", repr(configuration))
    @test !occursin("backend_defaults", repr(configuration))
    @test validation_exit_code(result) == 0
    @test length(result.criteria) == 9
    @test length(reports.ks.samples.times) == 161
    @test reports.maximum_scaled_backend_state_discrepancy !== nothing
    @test reports.entry_event_time_discrepancy !== nothing
    @test reports.exit_event_time_discrepancy !== nothing
    @test metric(series.points[1], :entry_event_time_discrepancy) ==
        reports.entry_event_time_discrepancy
    @test metric(series.points[1], :exit_event_time_discrepancy) ==
        reports.exit_event_time_discrepancy
    @test series.points[1].supporting_evidence === reports.ks
    @test series.points[1].supporting_evidence.samples.states === reports.ks.samples.states
    @test series.points[1].supporting_evidence.crossing_observations ===
        reports.ks.crossing_observations
    @test map(point -> point.point_id, series.points) == (:ks, :levi_civita)
    @test series.points[1].environment === environment
    restored = read_investigation_series(IOBuffer(investigation_series_report_text(series)))
    for (original_point, restored_point) in zip(series.points, restored.points)
        original = original_point.supporting_evidence
        retained = restored_point.supporting_evidence
        @test typeof(retained.samples) == typeof(original.samples)
        @test typeof(retained.diagnostics) == typeof(original.diagnostics)
        @test typeof(retained) == typeof(original)
        for name in fieldnames(typeof(original))
            name in (:samples, :diagnostics) && continue
            @test getfield(retained, name) == getfield(original, name)
        end
        @test retained.samples.times == original.samples.times
        @test retained.samples.states == original.samples.states
        for name in fieldnames(typeof(original.diagnostics))
            @test getfield(retained.diagnostics, name) == getfield(original.diagnostics, name)
        end
        @test length(retained.switch_events) == length(original.switch_events)
        @test all(
            ValidationFramework._record_fields_equal(left, right)
            for (left, right) in zip(retained.switch_events, original.switch_events)
        )
        @test all(
            ValidationFramework._record_fields_equal(left, right)
            for (left, right) in zip(
                retained.crossing_observations,
                original.crossing_observations,
            )
        )
    end

    combined_failure = ExecutionOutcome(
        actual_terminated; exit_code=23, summary="Combined comparison unsuccessful.",
    )
    first_point = series.points[1]
    failed_point = InvestigationMeasurementPoint(
        first_point.point_id, first_point.definition, first_point.configuration,
        first_point.independent_value, first_point.environment, combined_failure,
        first_point.metrics, first_point.solver_statistics;
        supporting_evidence=first_point.supporting_evidence,
    )
    mixed_execution_series = InvestigationMeasurementSeries(
        series.series_id, series.title, series.description, series.definition,
        (failed_point, series.points[2]),
    )
    mixed_restored = read_investigation_series(IOBuffer(
        investigation_series_report_text(mixed_execution_series),
    ))
    @test mixed_restored.points[1].execution == combined_failure
    @test mixed_restored.points[1].supporting_evidence.execution.actual == actual_completed
    @test mixed_restored.points[1].supporting_evidence.execution ==
        first_point.supporting_evidence.execution
    @test all(name -> ValidationFramework._record_fields_equal(
        getfield(mixed_restored.points[1].supporting_evidence, name),
        getfield(first_point.supporting_evidence, name),
    ), fieldnames(typeof(first_point.supporting_evidence)))

    inside_state = copy(fixture.state)
    inside_state[7] = -0.4
    rejected = fixture.TB.simulate_experimental_switching(
        fixture.system, inside_state, (0.0, 1.6), fixture.parameters;
        regularization_backend=:ks,
        cartesian_kwargs=fixture.fixed_settings.cartesian_kwargs,
        regularized_kwargs=fixture.fixed_settings.ks_kwargs,
    )
    @test rejected.status == :failure
    @test isempty(rejected.switch_events)
    partial_reports = build_ks_switching_backend_reports(
        rejected, fixture.lc, configuration, environment;
        fixed_settings=fixture.fixed_settings,
    )
    @test last(partial_reports.ks.samples.times) == rejected.final_time
    @test all(time -> time <= rejected.final_time, partial_reports.ks.samples.times)
    @test isnothing(partial_reports.ks.maximum_scaled_backend_state_discrepancy)
    @test partial_reports.ks.solver_statistics.accepted_steps == 0
    @test length(partial_reports.ks.crossing_observations) == 1
    @test isnothing(first(partial_reports.ks.crossing_observations).competition_evidence)

    failed_result = build_ks_switching_comparison_case_result(
        rejected.status, fixture.lc.status,
        length(rejected.switch_events), length(fixture.lc.switch_events),
        nothing, nothing, nothing, nothing,
        ValidationFramework._ks_switching_maximum_transition_residual(fixture.lc),
        161, SolverStatistics(segment_count=length(rejected.segments) + length(fixture.lc.segments)),
        environment; configuration, state_difference_limit=2e-8,
        event_time_difference_limit=2e-6, transition_residual_limit=1e-11,
    )
    @test failed_result.execution.actual == actual_terminated
    @test validation_exit_code(failed_result) != 0
    @test isempty(failed_result.criteria)
    @test !any(item -> item.metric_id == :maximum_scaled_backend_state_discrepancy,
        failed_result.metrics)
    partial_series = ks_switching_backend_investigation_series(
        failed_result, (partial_reports.levi_civita, partial_reports.ks),
    )
    @test partial_series.points[1].execution.actual == actual_terminated
    @test !any(item -> item.metric_id == :maximum_scaled_backend_state_discrepancy,
        partial_series.points[1].metrics)
    @test !any(item -> item.metric_id == :maximum_transition_state_residual,
        partial_series.points[1].metrics)

    for parameter_id in (
        :cartesian_relative_tolerance,
        :cartesian_absolute_tolerance,
        :cartesian_maximum_iterations,
        :cartesian_precision_bits,
        :levi_civita_relative_tolerance,
        :levi_civita_absolute_tolerance,
        :levi_civita_targeting_initial_step,
        :levi_civita_targeting_tolerance,
        :levi_civita_targeting_maximum_iterations,
        :ks_relative_tolerance,
        :ks_absolute_tolerance,
        :ks_maximum_fictitious_span_expansions,
        :ks_nonselected_pair_threshold,
        :regularized_evaluation_tolerance,
        :regularized_evaluation_maximum_iterations,
    )
        changed_parameters = map(configuration.parameters) do parameter
            parameter.parameter_id == parameter_id ?
                ValidationParameter(parameter_id, parameter.value * 2) : parameter
        end
        changed_configuration = ValidationConfiguration(
            solver=configuration.solver,
            time_interval=configuration.time_interval,
            sampling=configuration.sampling,
            selected_pair=configuration.selected_pair,
            thresholds=configuration.thresholds,
            parameters=Tuple(changed_parameters),
        )
        changed_result = _ks_investigation_result(
            ; configuration=changed_configuration, environment,
        )
        @test_throws ArgumentError ks_switching_backend_investigation_series(
            changed_result,
            (_replace_ks_report(reports.levi_civita;
                configuration=changed_configuration),
             _replace_ks_report(reports.ks; configuration=changed_configuration)),
        )
    end

    encounter_state = fixture.TB.statevector(
        [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
        [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
        [0.95, 0.0, 0.0], [1.0, 0.0, 0.0],
    )
    unsafe = fixture.TB.simulate_experimental_switching(
        fixture.system, encounter_state, (0.0, 1.6), fixture.parameters;
        regularization_backend=:ks,
        cartesian_kwargs=fixture.fixed_settings.cartesian_kwargs,
        regularized_kwargs=merge(fixture.fixed_settings.ks_kwargs,
            (nonselected_threshold=2.0,)),
    )
    @test unsafe.status == :failure
    @test length(unsafe.switch_events) == 1
    unsafe_reports = build_ks_switching_backend_reports(
        unsafe, fixture.lc, configuration, environment;
        fixed_settings=fixture.fixed_settings,
    )
    terminal = last(unsafe_reports.ks.crossing_observations)
    @test terminal.kind == :terminal_decision
    @test terminal.decision.reason == :nonselected_pair_unsafe
    @test terminal.competition_evidence.crossing_provenance ==
        :certified_nonselected_pair_crossing
    unsafe_result = build_ks_switching_comparison_case_result(
        unsafe.status, fixture.lc.status,
        length(unsafe.switch_events), length(fixture.lc.switch_events),
        nothing, nothing, nothing,
        ValidationFramework._ks_switching_maximum_transition_residual(unsafe),
        ValidationFramework._ks_switching_maximum_transition_residual(fixture.lc),
        161, SolverStatistics(segment_count=length(unsafe.segments) + length(fixture.lc.segments)),
        environment; configuration, state_difference_limit=2e-8,
        event_time_difference_limit=2e-6, transition_residual_limit=1e-11,
    )
    unsafe_series = ks_switching_backend_investigation_series(
        unsafe_result, (unsafe_reports.levi_civita, unsafe_reports.ks),
    )
    retained_terminal = last(unsafe_series.points[1].supporting_evidence.crossing_observations)
    @test retained_terminal.decision.reason == :nonselected_pair_unsafe
    @test retained_terminal.competition_evidence === terminal.competition_evidence

    repeated_observations = (
            reports.ks.crossing_observations...,
            reports.ks.crossing_observations...,
    )
    repeated = _replace_ks_report(
        reports.ks; crossing_observations=repeated_observations,
        switch_events=Tuple(item.event for item in repeated_observations),
    )
    repeated_series = ks_switching_backend_investigation_series(
        result, (reports.levi_civita, repeated),
    )
    ids = map(item -> item.metric_id, repeated_series.points[1].metrics)
    @test length(ids) == length(unique(ids))
    @test metric(repeated_series.points[1], :crossing_kinds) ==
        (:entry, :exit, :entry, :exit)
end

function _ks_backend_report(backend; result=_ks_investigation_result(),
    definition=result.definition, configuration=result.configuration,
    environment=result.environment, execution=ExecutionOutcome(actual_completed; exit_code=0),
    crossing_observations=nothing, diagnostics=nothing,
    maximum_state_difference=backend == :ks ? 1.0e-9 : 1.1e-9,
    entry_time_difference=1e-14, exit_time_difference=2e-14)
    scale = backend == :ks ? 1.0 : 1.1
    diagnostics = isnothing(diagnostics) ? (
        maximum_relative_energy_drift=scale * 1e-12,
        maximum_linear_momentum_drift=scale * 2e-13,
        maximum_angular_momentum_drift=scale * 3e-13,
        maximum_center_of_mass_residual=scale * 4e-13,
        minimum_separation=0.1 + scale * eps(),
        maximum_transition_state_residual=scale * 5e-14,
    ) : diagnostics
    function observation(kind, time, sundman, provenance, residual)
        event = (
            kind, physical_time=time,
            transition_diagnostics=(state_residual=residual,),
            isolation_ratio=10.0, separations=(0.1, 1.0, 2.0),
            radial_rates=(-1.0, 0.0, 0.0),
        )
        competition = (
            crossing_provenance=provenance, ambiguity_margin=0.1,
            candidate_is_closest=true, candidate_tied_for_closest=false,
        )
        (
            kind, successful_switch=true, physical_time=time, sundman_time=sundman,
            event, decision=(reason=Symbol(:certified_, kind), evidence=(candidate_count=1,)),
            competition_evidence=competition, progress_evidence=nothing,
        )
    end
    crossing_observations = isnothing(crossing_observations) ? (
        observation(:entry, 0.8, nothing, :certified_cartesian_entry, scale * 2e-14),
        observation(:exit, 1.2, 0.3, :certified_regularized_exit, scale * 3e-14),
    ) : crossing_observations
    ValidationFramework.KSSwitchingBackendReport(
        backend, definition, configuration, environment, execution,
        execution.actual == actual_completed ? 1.6 : 1.1,
        (times=(0.0, 1.6), states=((0.0,), (1.0,))), diagnostics,
        SolverStatistics(accepted_steps=100, rejected_steps=2,
            rhs_evaluations=700, saved_states=161, segment_count=3, switch_count=2),
        crossing_observations,
        Tuple(observation.event for observation in crossing_observations),
        maximum_state_difference, entry_time_difference, exit_time_difference,
    )
end

@testset "KS switching Investigation 1 adapter" begin
    result = _ks_investigation_result()
    ks = _ks_backend_report(:ks; result)
    lc = _ks_backend_report(:levi_civita; result)
    series = ks_switching_backend_investigation_series(result, (lc, ks))

    @test series.definition.independent_variable == :regularization_backend
    @test map(point -> point.point_id, series.points) == (:ks, :levi_civita)
    @test map(point -> point.independent_value.value, series.points) == (:ks, :levi_civita)
    @test series.definition.benchmark.definition_version == "1.0.0"
    @test any(control -> control.parameter_id == :selected_pair && control.value == (1, 2),
        series.definition.fixed_controls)
    @test all(point -> point.solver_statistics.accepted_steps == 100, series.points)
    @test all(point -> point.solver_statistics.rhs_evaluations == 700, series.points)

    metric(point, id) = only(filter(item -> item.metric_id == id, point.metrics)).value
    @test metric(series.points[1], :maximum_scaled_backend_state_discrepancy) ≈ 1e-9
    @test metric(series.points[1], :maximum_relative_energy_drift) ≈ 1e-12
    @test metric(series.points[1], :minimum_pair_separation) > 0.1
    @test metric(series.points[1], :entry_crossing_provenance) == :certified_cartesian_entry
    @test metric(series.points[1], :exit_crossing_certified)
    @test metric(series.points[1], :exit_sundman_time) == 0.3
    @test !any(item -> item.metric_id == :entry_sundman_time, series.points[1].metrics)
    @test series.points[1].configuration === result.configuration
    @test series.points[1].environment === result.environment

    zero_switch = _ks_backend_report(
        :ks; result, crossing_observations=(),
        entry_time_difference=nothing, exit_time_difference=nothing,
    )
    zero_series = ks_switching_backend_investigation_series(result, (lc, zero_switch))
    @test zero_series.points[1].execution.actual == actual_completed
    @test isempty(zero_series.points[1].supporting_evidence.switch_events)
    @test !any(item -> item.metric_id == :maximum_transition_state_residual,
        zero_series.points[1].metrics)
    @test !any(item -> item.metric_id == :entry_physical_time,
        zero_series.points[1].metrics)

    one_observation = (first(ks.crossing_observations),)
    one_switch = _ks_backend_report(
        :ks; result, crossing_observations=one_observation,
        exit_time_difference=nothing,
    )
    one_series = ks_switching_backend_investigation_series(result, (lc, one_switch))
    @test one_series.points[1].execution.actual == actual_completed
    @test length(one_series.points[1].supporting_evidence.switch_events) == 1
    @test any(item -> item.metric_id == :entry_physical_time, one_series.points[1].metrics)
    @test !any(item -> item.metric_id == :exit_physical_time, one_series.points[1].metrics)

    @test_throws ArgumentError ks_switching_backend_investigation_series(result, (ks, ks, lc))
    @test_throws ArgumentError ks_switching_backend_investigation_series(result, (ks,))
    @test_throws ArgumentError ks_switching_backend_investigation_series(result,
        (_replace_ks_report(ks; definition=close_encounter_case_definition()), lc))
    @test_throws ArgumentError ks_switching_backend_investigation_series(result,
        (_replace_ks_report(ks;
            configuration=_ks_investigation_configuration(selected_pair=(1, 3))), lc))
    @test_throws ArgumentError ks_switching_backend_investigation_series(result,
        (_replace_ks_report(ks; environment=_pilot_environment()), lc))
    mismatched_result = _ks_investigation_result(
        configuration=_ks_investigation_configuration(selected_pair=(1, 3)))
    @test_throws ArgumentError ks_switching_backend_investigation_series(
        mismatched_result,
        (_ks_backend_report(:ks; result=mismatched_result),
         _ks_backend_report(:levi_civita; result=mismatched_result)),
    )
    malformed = (backend=:ks,)
    @test_throws ArgumentError ks_switching_backend_investigation_series(result, (malformed, lc))

    terminated = ExecutionOutcome(actual_terminated; exit_code=31, summary="Certified exit not found.")
    partial_crossings = (first(ks.crossing_observations),)
    partial = _ks_backend_report(:ks; result, execution=terminated,
        crossing_observations=partial_crossings)
    partial_series = ks_switching_backend_investigation_series(result, (lc, partial))
    @test partial_series.points[1].execution.actual == actual_terminated
    @test partial_series.points[1].execution.exit_code == 31
    @test metric(partial_series.points[1], :entry_physical_time) == 0.8
    @test !any(item -> item.metric_id == :exit_state_residual, partial_series.points[1].metrics)

    missing_diagnostics = (; (name => value for (name, value) in pairs(ks.diagnostics)
        if name != :minimum_separation)...)
    @test_throws ArgumentError ks_switching_backend_investigation_series(result,
        (_replace_ks_report(ks; diagnostics=missing_diagnostics), lc))
end

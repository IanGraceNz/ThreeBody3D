function _close_investigation_configuration(; sampling="step=0.002")
    configuration = ValidationFramework._close_encounter_investigation_configuration()
    ValidationConfiguration(
        solver=configuration.solver,
        absolute_tolerance=configuration.absolute_tolerance,
        relative_tolerance=configuration.relative_tolerance,
        precision_bits=configuration.precision_bits,
        time_interval=configuration.time_interval,
        sampling=sampling,
        selected_pair=configuration.selected_pair,
        thresholds=configuration.thresholds,
        parameters=configuration.parameters,
    )
end

function _close_investigation_case_result(;
    definition=close_encounter_case_definition(),
    environment=performance_test_environment(),
    configuration=_close_investigation_configuration(),
    execution=ExecutionOutcome(actual_completed; exit_code=0),
)
    ValidationCaseResult(
        definition,
        environment,
        configuration,
        (),
        (),
        nothing,
        execution,
    )
end

function _close_method_name(representation)
    representation == :cartesian && return "Cartesian"
    representation == :automatic_switching && return "Automatic switching"
    representation == :explicit_regularized && return "Explicit regularized"
    error("Unsupported synthetic close-encounter representation.")
end

function _close_method_report(
    representation;
    result=_close_investigation_case_result(),
    definition=result.definition,
    configuration=result.configuration,
    environment=result.environment,
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    errors_scale=representation == :cartesian ? 1.0 : 0.01,
    include_errors=true,
    include_conservation=true,
)
    errors = (
        maximum_position=errors_scale * 1.0e-4,
        maximum_velocity=errors_scale * 2.0e-4,
        maximum_combined=errors_scale * 3.0e-4,
        final_position=errors_scale * 4.0e-5,
        final_velocity=errors_scale * 5.0e-5,
        final_combined=errors_scale * 6.0e-5,
    )
    conservation = (
        maximum_relative_energy_drift=errors_scale * 1.0e-10,
        maximum_momentum_drift=errors_scale * 2.0e-12,
        maximum_angular_momentum_drift=errors_scale * 3.0e-11,
        maximum_com_residual=errors_scale * 4.0e-12,
        minimum_separation=0.0001 + errors_scale * eps(),
    )
    common = (
        name=_close_method_name(representation),
        definition,
        configuration,
        environment,
        execution,
        final_time=1.6,
        work=(
            accepted_steps=representation == :cartesian ? 100 : 200,
            rejected_steps=representation == :cartesian ? 3 : 2,
            rhs_evaluations=representation == :cartesian ? 900 : 1800,
            saved_states=801,
        ),
        elapsed=representation == :cartesian ? 0.5 : 1.5,
        segments=representation == :cartesian ? 1 : 3,
        switches=representation == :cartesian ? 0 : 2,
        periapsis_time_error=errors_scale * 7.0e-6,
        periapsis_separation_error=errors_scale * 8.0e-7,
    )
    evidence = if include_errors && include_conservation
        (; common..., errors, conservation)
    elseif include_errors
        (; common..., errors)
    elseif include_conservation
        (; common..., conservation)
    else
        common
    end
    representation == :cartesian ?
        evidence :
        (; evidence..., transition_residual=1.0e-12)
end

function _close_investigation_inputs()
    result = _close_investigation_case_result()
    reports = (
        _close_method_report(:explicit_regularized; result),
        _close_method_report(:cartesian; result),
        _close_method_report(:automatic_switching; result),
    )
    result, reports
end

function _without_close_report_field(report, omitted::Symbol)
    retained = Tuple(key for key in keys(report) if key != omitted)
    NamedTuple{retained}(Tuple(getproperty(report, key) for key in retained))
end

@testset "Close-encounter Investigation 1 definition" begin
    definition = close_encounter_representation_investigation_definition()
    @test definition.family_id == :close_encounter_representation
    @test definition.independent_variable == :representation_mode
    @test ValidationFramework._record_fields_equal(
        definition.benchmark,
        close_encounter_case_definition(),
    )
    @test definition.required_metric_ids == CLOSE_ENCOUNTER_INVESTIGATION_METRICS
    @test definition.optional_metric_ids == (:transition_state_residual,)
    control_ids = map(control -> control.parameter_id, definition.fixed_controls)
    @test all(
        id -> id in control_ids,
        (
            :solver,
            :time_interval,
            :sampling,
            :selected_pair,
            :initial_state,
            :masses,
            :nominal_periapsis,
            :entry_threshold,
            :exit_threshold,
            :regularized_tolerance,
            :reference_precision_bits,
        ),
    )
end

@testset "Close-encounter Investigation 1 ordered complete series" begin
    result, reports = _close_investigation_inputs()
    series = close_encounter_representation_investigation_series(result, reports)

    @test map(point -> point.point_id, series.points) ==
          (:cartesian, :automatic_switching, :explicit_regularized)
    @test map(point -> point.independent_value.value, series.points) ==
          (:cartesian, :automatic_switching, :explicit_regularized)
    @test all(point -> point.configuration === result.configuration, series.points)
    @test all(point -> point.environment === result.environment, series.points)
    cartesian, automatic, explicit = series.points
    @test map(metric -> metric.metric_id, cartesian.metrics) ==
          CLOSE_ENCOUNTER_INVESTIGATION_METRICS
    @test map(metric -> metric.metric_id, automatic.metrics) ==
          (CLOSE_ENCOUNTER_INVESTIGATION_METRICS..., :transition_state_residual)
    @test map(metric -> metric.metric_id, explicit.metrics) ==
          (CLOSE_ENCOUNTER_INVESTIGATION_METRICS..., :transition_state_residual)
    @test !any(metric -> metric.metric_id == :transition_state_residual, cartesian.metrics)
    @test all(
        point -> any(metric -> metric.metric_id == :transition_state_residual, point.metrics),
        (automatic, explicit),
    )
    @test map(
        point -> only(filter(
            metric -> metric.metric_id == :integration_status,
            point.metrics,
        )).value,
        series.points,
    ) == (:completed, :completed, :completed)
    @test only(filter(metric -> metric.metric_id == :maximum_state_error, cartesian.metrics)).value ≈
          3.0e-4
    @test only(filter(metric -> metric.metric_id == :final_state_error, automatic.metrics)).value ≈
          6.0e-7
    @test only(filter(metric -> metric.metric_id == :maximum_relative_energy_drift, explicit.metrics)).value ≈
          1.0e-12
    @test only(filter(metric -> metric.metric_id == :minimum_pair_separation, automatic.metrics)).value >
          0.0001
    @test all(
        point -> any(metric -> metric.metric_id == :periapsis_time_error, point.metrics),
        series.points,
    )
    @test all(
        point -> any(metric -> metric.metric_id == :periapsis_separation_error, point.metrics),
        series.points,
    )
    @test map(point -> point.solver_statistics.rhs_evaluations, series.points) ==
          (900, 1800, 1800)
    @test map(point -> point.solver_statistics.segment_count, series.points) == (1, 3, 3)
    @test map(point -> point.solver_statistics.switch_count, series.points) == (0, 2, 2)
    @test map(point -> point.solver_statistics.elapsed_seconds, series.points) == (0.5, 1.5, 1.5)
end

@testset "Close-encounter Investigation 1 method-report contract" begin
    result, reports = _close_investigation_inputs()
    series = close_encounter_representation_investigation_series(result, reports)
    @test all(report -> report.definition === result.definition, reports)
    @test all(report -> report.configuration === result.configuration, reports)
    @test all(report -> report.environment === result.environment, reports)
    @test all(report -> report.execution isa ExecutionOutcome, reports)
    @test all(point -> point.configuration === result.configuration, series.points)
    @test all(point -> point.environment === result.environment, series.points)

    for field in (:definition, :configuration, :environment, :execution)
        malformed = _without_close_report_field(reports[2], field)
        @test_throws ArgumentError close_encounter_representation_investigation_series(
            result,
            (reports[1], malformed, reports[3]),
        )
    end
end

@testset "Close-encounter Investigation 1 identities and fixed controls" begin
    result, reports = _close_investigation_inputs()
    wrong_definition = _case_definition_with_version(close_encounter_case_definition(), "2.0.0")
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        _close_investigation_case_result(; definition=wrong_definition),
        reports,
    )

    wrong_configuration = _close_investigation_configuration(; sampling="step=0.01")
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        _close_investigation_case_result(; configuration=wrong_configuration),
        reports,
    )

    mismatched_report = _close_method_report(
        :cartesian;
        result,
        configuration=wrong_configuration,
    )
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        result,
        (mismatched_report, reports[1], reports[3]),
    )

    other_environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "deadbeef", false, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-27T00:00:00Z",
    )
    mismatched_provenance = _close_method_report(
        :cartesian;
        result,
        environment=other_environment,
    )
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        result,
        (mismatched_provenance, reports[1], reports[3]),
    )
end

@testset "Close-encounter Investigation 1 duplicate and missing inputs" begin
    result, reports = _close_investigation_inputs()
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        result,
        (reports[2], reports[2], reports[3]),
    )
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        result,
        reports[1:2],
    )
end

@testset "Close-encounter Investigation 1 incomplete completed point" begin
    result, reports = _close_investigation_inputs()
    incomplete = _close_method_report(
        :automatic_switching;
        result,
        include_conservation=false,
    )
    @test_throws ArgumentError close_encounter_representation_investigation_series(
        result,
        (reports[1], reports[2], incomplete),
    )
end

@testset "Close-encounter Investigation 1 unsuccessful partial evidence" begin
    result, reports = _close_investigation_inputs()
    execution = ExecutionOutcome(
        actual_terminated;
        exit_code=7,
        summary="Automatic switching terminated after retaining reference-error evidence.",
    )
    partial = _close_method_report(
        :automatic_switching;
        result,
        execution,
        include_conservation=false,
    )
    series = close_encounter_representation_investigation_series(
        result,
        (reports[1], reports[2], partial),
    )
    point = series.points[2]
    @test point.execution.actual == actual_terminated
    @test point.execution.exit_code == 7
    @test map(metric -> metric.metric_id, point.metrics) == (
        :integration_status,
        :final_time_residual,
        :maximum_position_error,
        :maximum_velocity_error,
        :maximum_state_error,
        :final_position_error,
        :final_velocity_error,
        :final_state_error,
        :periapsis_time_error,
        :periapsis_separation_error,
        :transition_state_residual,
    )
    @test first(point.metrics).value == :terminated
    @test point.solver_statistics.rhs_evaluations == 1800
    @test point.solver_statistics.switch_count == 2
    @test occursin("terminated", point.notes)
end

using Test

function synthetic_float_runner(reference; fail=false)
    function runner(system, initial_state, tspan; kwargs...)
        fail && error("synthetic propagation failure")
        times = Float64.(kwargs[:saveat])
        saved_state = time -> Float64.(ValidationFramework.close_encounter_reference_state(
            reference, time,
        ))
        state_at_time = function(time)
            state = saved_state(time)
            state[2] += 1e-6
            state
        end
        states = [saved_state(time) for time in times]
        solution = CloseSyntheticSolution(
            times, states, CloseSyntheticStats(20, 3, 240), state_at_time,
        )
        (solution=solution,)
    end
end

function synthetic_close_performance_report(configuration, environment;
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    definition=ValidationFramework.close_encounter_cartesian_performance_definition(configuration),
    recorded_configuration=ValidationFramework._close_cartesian_validation_configuration(configuration),
    policy=StandardBenchmark())
    samples = execution.actual == actual_completed ? Tuple(
        PerformanceSample(index; elapsed_seconds=0.01 * index,
            solver_statistics=SolverStatistics(accepted_steps=20, rejected_steps=3,
                rhs_evaluations=240, saved_states=801), saved_states=801)
        for index in 1:policy.sample_runs) : ()
    build_performance_benchmark_report(
        definition, environment, recorded_configuration, policy, samples, execution,
    )
end

function synthetic_close_performance_suite(configurations, environment; overrides=Dict())
    reports = Tuple(get(overrides, configuration.relative_tolerance,
        synthetic_close_performance_report(configuration, environment))
        for configuration in configurations)
    PerformanceSuiteReport(
        :close_encounter_cartesian_test, "Close-encounter Cartesian test",
        VALIDATION_SCHEMA_VERSION, environment, reports,
    )
end

@testset "Close-encounter Cartesian investigation foundation" begin
    @test CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES == (1e-9, 1e-10, 1e-11, 1e-12, 1e-13)
    @test_throws ArgumentError close_encounter_cartesian_configuration(1e-8)
    configurations = map(close_encounter_cartesian_configuration,
        CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
    @test map(item -> item.relative_tolerance, configurations) ==
        CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES

    definition = ValidationFramework.close_encounter_cartesian_investigation_definition()
    @test definition.family_id == :close_encounter_cartesian_tolerance
    @test definition.independent_variable == :tolerance
    @test length(definition.fixed_controls) == 15

    for tolerance in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES
        configuration = close_encounter_cartesian_configuration(tolerance)
        id = ValidationFramework.close_encounter_cartesian_performance_benchmark_id(tolerance)
        @test ValidationFramework.decode_close_encounter_cartesian_benchmark_id(id) == configuration
    end
    @test_throws ArgumentError ValidationFramework.decode_close_encounter_cartesian_benchmark_id(
        :close_encounter_cartesian_tolerance_1e_8,
    )

    reference = synthetic_close_reference()
    configuration = last(configurations)
    runner = synthetic_float_runner(reference)
    attempt = attempt_close_encounter_cartesian(configuration, reference; runner=runner)
    @test attempt.execution.actual == actual_completed
    @test !isnothing(attempt.evidence)
    @test isnothing(attempt.partial_evidence)
    @test map(sample -> sample.location, attempt.evidence.localization.samples) ==
        (:entry, :periapsis, :exit, :final)
    @test map(region -> region.region, attempt.evidence.localization.regions) ==
        (:before, :during, :after)
    @test attempt.evidence.localization.samples[1].state_source == :dense_interpolation
    @test attempt.evidence.localization.samples[2].state_source == :dense_interpolation
    @test attempt.evidence.localization.samples[4].state_source == :saved_direct
    setprecision(BigFloat, 256) do
        exact_periapsis = parse(BigFloat, "0.8")
        promoted_grid_time = BigFloat(0.8)
        periapsis_states = ValidationFramework._close_cartesian_states_at_time(
            attempt.evidence.base, exact_periapsis,
        )
        saved_states = ValidationFramework._close_cartesian_states_at_time(
            attempt.evidence.base, promoted_grid_time,
        )
        saved_index = ValidationFramework._close_cartesian_saved_index(
            attempt.evidence.base, promoted_grid_time,
        )
        @test periapsis_states.source == :dense_interpolation
        @test saved_states.source == :saved_direct
        @test !isnothing(saved_index)
        @test saved_states.method === attempt.evidence.base.states[saved_index]
        @test saved_states.reference === reference.sampled_states[saved_index]
        @test periapsis_states.method != saved_states.method
        @test periapsis_states.reference != saved_states.reference
    end
    @test attempt.evidence.base.work == (saved_states=801, accepted_steps=20,
        rejected_steps=3, rhs_evaluations=240)
    @test hasproperty(attempt.evidence.base.conservation, :minimum_separation)
    @test hasproperty(attempt.evidence.dense_periapsis, :separation)
    @test length(ValidationFramework._close_cartesian_metrics(
        attempt.evidence.base; dense_periapsis=attempt.evidence.dense_periapsis,
    )) == 16

    failed = attempt_close_encounter_cartesian(configuration, reference;
        runner=synthetic_float_runner(reference; fail=true))
    @test failed.execution.actual == actual_errored
    @test isnothing(failed.evidence)
    @test isnothing(failed.partial_evidence)
    @test occursin("propagation/global measurement failed", failed.execution.summary)

    periapsis_partial = attempt_close_encounter_cartesian(
        configuration, reference; runner=runner,
        periapsis_localizer=base -> error("synthetic periapsis failure"),
    )
    @test periapsis_partial.execution.actual == actual_errored
    @test isnothing(periapsis_partial.evidence)
    @test !isnothing(periapsis_partial.partial_evidence)
    @test length(ValidationFramework._close_cartesian_metrics(
        periapsis_partial.partial_evidence,
    )) == 14
    @test occursin("dense-periapsis localisation failed",
        periapsis_partial.execution.summary)

    partial = attempt_close_encounter_cartesian(
        configuration, reference; runner=runner,
        localizer=base -> error("synthetic localization failure"),
    )
    @test partial.execution.actual == actual_errored
    @test isnothing(partial.evidence)
    @test !isnothing(partial.partial_evidence)
    @test partial.partial_evidence.work.rhs_evaluations == 240
    @test length(ValidationFramework._close_cartesian_metrics(partial.partial_evidence)) == 14
    @test occursin("temporal localisation failed", partial.execution.summary)

    @test_throws ArgumentError ValidationFramework.CloseEncounterCartesianAttempt(
        configuration, ExecutionOutcome(actual_completed; exit_code=0), nothing,
    )
    @test_throws ArgumentError ValidationFramework.CloseEncounterCartesianAttempt(
        configuration, ExecutionOutcome(actual_errored; exit_code=1, summary="bad"),
        attempt.evidence, nothing,
    )

    localization = attempt.evidence.localization
    text_buffer = IOBuffer()
    # Supporting evidence is exercised through a minimal unsuccessful point, so
    # required-metric completeness does not obscure serialization behavior.
    point = InvestigationMeasurementPoint(
        :tolerance_1e_13, definition,
        ValidationFramework._close_cartesian_validation_configuration(configuration),
        ValidationParameter(:tolerance, 1e-13), current_validation_environment(),
        ExecutionOutcome(actual_errored; exit_code=1, summary="fixture"), (), nothing;
        supporting_evidence=localization,
    )
    series = InvestigationMeasurementSeries(
        :close_encounter_cartesian_tolerance, definition.title, definition.description,
        definition, (point,),
    )
    write_investigation_series(text_buffer, series)
    first_text = String(take!(text_buffer))
    restored = read_investigation_series(IOBuffer(first_text))
    restored_evidence = only(restored.points).supporting_evidence
    @test restored_evidence.boundaries.entry_time == localization.boundaries.entry_time
    @test precision(restored_evidence.boundaries.entry_time) == 256
    second_buffer = IOBuffer()
    write_investigation_series(second_buffer, restored)
    @test String(take!(second_buffer)) == first_text
    @test map(sample -> sample.state_source, restored_evidence.samples) ==
        map(sample -> sample.state_source, localization.samples)

    entry = close_encounter_cartesian_performance_entry(configuration)
    @test isfile(entry.path)
    observation = ValidationFramework.close_encounter_cartesian_performance_operation(
        configuration; runner=runner,
    )()
    @test observation.saved_states == 801
    @test observation.solver_statistics.rhs_evaluations == 240

    environment = current_validation_environment()
    attempts = Tuple(attempt_close_encounter_cartesian(item, reference; runner=runner)
        for item in configurations)
    suite = synthetic_close_performance_suite(configurations, environment)
    complete_series = close_encounter_cartesian_investigation_series(suite, attempts)
    @test map(point -> point.point_id, complete_series.points) ==
        (:tolerance_1e_9, :tolerance_1e_10, :tolerance_1e_11,
         :tolerance_1e_12, :tolerance_1e_13)
    @test all(point -> point.environment == environment, complete_series.points)
    @test all(point -> length(point.metrics) == 16, complete_series.points)
    @test all(point -> !isnothing(point.performance_report), complete_series.points)
    @test all(point -> !isnothing(point.solver_statistics), complete_series.points)
    @test all(point -> !isnothing(point.supporting_evidence), complete_series.points)
    @test all(item -> item.evidence.base.reference === reference, attempts)

    series_buffer = IOBuffer()
    write_investigation_series(series_buffer, complete_series)
    series_text = String(take!(series_buffer))
    restored_series = read_investigation_series(IOBuffer(series_text))
    @test map(point -> point.point_id, restored_series.points) ==
        map(point -> point.point_id, complete_series.points)
    @test all(point -> precision(point.supporting_evidence.boundaries.entry_time) == 256,
        restored_series.points)
    @test all(point -> length(point.supporting_evidence.samples) == 4,
        restored_series.points)
    restored_buffer = IOBuffer()
    write_investigation_series(restored_buffer, restored_series)
    @test String(take!(restored_buffer)) == series_text

    partial_attempts = collect(attempts)
    partial_attempts[2] = attempt_close_encounter_cartesian(
        configurations[2], reference; runner=runner,
        localizer=base -> error("series localization failure"),
    )
    partial_series = close_encounter_cartesian_investigation_series(
        suite, Tuple(partial_attempts),
    )
    @test length(partial_series.points[2].metrics) == 14
    @test isnothing(partial_series.points[2].supporting_evidence)
    @test !isnothing(partial_series.points[2].solver_statistics)
    @test occursin("Direct execution", partial_series.points[2].notes)

    failed_attempts = collect(attempts)
    failed_attempts[1] = attempt_close_encounter_cartesian(
        configurations[1], reference;
        runner=synthetic_float_runner(reference; fail=true),
    )
    missing_performance = synthetic_close_performance_report(
        configurations[1], environment;
        execution=ExecutionOutcome(actual_missing_report; exit_code=1,
            summary="missing child report"),
    )
    mixed_suite = synthetic_close_performance_suite(
        configurations, environment;
        overrides=Dict(1e-9 => missing_performance),
    )
    missing_series = close_encounter_cartesian_investigation_series(
        mixed_suite, attempts,
    )
    @test missing_series.points[1].execution.actual == actual_missing_report
    @test length(missing_series.points[1].metrics) == 16
    @test !isnothing(missing_series.points[1].performance_report)
    @test occursin("Performance execution", missing_series.points[1].notes)
    mixed_series = close_encounter_cartesian_investigation_series(
        mixed_suite, Tuple(failed_attempts),
    )
    @test mixed_series.points[1].execution.actual == actual_errored
    @test occursin("Direct execution", mixed_series.points[1].notes)
    @test occursin("Performance execution", mixed_series.points[1].notes)
    @test mixed_series.points[1].performance_report.execution.actual == actual_missing_report

    malformed_performance = synthetic_close_performance_report(
        configurations[3], environment;
        execution=ExecutionOutcome(actual_malformed_report; exit_code=1,
            summary="malformed child report"),
    )
    malformed_suite = synthetic_close_performance_suite(
        configurations, environment;
        overrides=Dict(1e-11 => malformed_performance),
    )
    malformed_series = close_encounter_cartesian_investigation_series(
        malformed_suite, attempts,
    )
    @test malformed_series.points[3].execution.actual == actual_malformed_report
    @test occursin("Performance execution", malformed_series.points[3].notes)
    @test length(malformed_series.points[3].metrics) == 16

    @test_throws ArgumentError close_encounter_cartesian_investigation_series(
        PerformanceSuiteReport(:missing_close, "Missing", VALIDATION_SCHEMA_VERSION,
            environment, suite.benchmarks[1:4]), attempts,
    )
    @test_throws ArgumentError close_encounter_cartesian_investigation_series(
        PerformanceSuiteReport(:extra_close, "Extra", VALIDATION_SCHEMA_VERSION,
            environment, (suite.benchmarks..., first(suite.benchmarks))), attempts,
    )
    duplicate_reports = (suite.benchmarks[1], suite.benchmarks[1], suite.benchmarks[3:end]...)
    @test_throws ArgumentError close_encounter_cartesian_investigation_series(
        PerformanceSuiteReport(:duplicate_close, "Duplicate", VALIDATION_SCHEMA_VERSION,
            environment, duplicate_reports), attempts,
    )
    wrong_report = synthetic_close_performance_report(
        configurations[1], environment;
        recorded_configuration=ValidationFramework._close_cartesian_validation_configuration(
            configurations[2]),
    )
    wrong_suite = synthetic_close_performance_suite(
        configurations, environment; overrides=Dict(1e-9 => wrong_report),
    )
    @test_throws ArgumentError close_encounter_cartesian_investigation_series(
        wrong_suite, attempts,
    )
    @test_throws ArgumentError close_encounter_cartesian_investigation_series(
        suite, reverse(attempts),
    )
end

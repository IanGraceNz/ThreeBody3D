function _duration_sampling_observation(kind, family, value;
    status=:completed, times=nothing, report_changes=NamedTuple(), system=nothing,
    initial_state=nothing)
    configuration = core_duration_sampling_configuration(kind, family, value)
    authoritative = family == :figure_eight ?
        ValidationFramework.ThreeBody3D._figure_eight_benchmark_inputs() :
        ValidationFramework.ThreeBody3D._hierarchical_triple_benchmark_inputs()
    system = isnothing(system) ? authoritative[1] : system
    initial_state = isnothing(initial_state) ? authoritative[2] : initial_state
    final_time = family == :figure_eight ?
        ValidationFramework.ThreeBody3D.FIGURE_EIGHT_PERIOD * configuration.periods :
        configuration.duration
    if isnothing(times)
        times = ValidationFramework._core_scalar_saveat_grid(final_time,
            configuration.saveat)
    else
        times = collect(times)
    end
    report = merge(_core_fixture_report(family, :vern9, times; status,
        expected_final_time=final_time), report_changes)
    CoreBenchmarkObservation(configuration, report, times, system, initial_state)
end

function _duration_sampling_attempt(observation)
    completed = observation.report.status == :completed
    outcome = ExecutionOutcome(completed ? actual_completed : actual_terminated;
        exit_code=completed ? 0 : 1,
        summary=completed ? nothing : "direct benchmark terminated")
    CoreDurationSamplingAttempt(observation.configuration, outcome, observation;
        notes=outcome.summary)
end

function _duration_sampling_performance_report(configuration, environment;
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    definition=core_duration_sampling_performance_definition(configuration),
    recorded_configuration=ValidationFramework._core_duration_sampling_validation_configuration(configuration),
    policy=StandardBenchmark())
    samples = execution.actual == actual_completed ? Tuple(
        PerformanceSample(index; elapsed_seconds=0.01 * index,
            solver_statistics=SolverStatistics(accepted_steps=10, rejected_steps=0,
                rhs_evaluations=80, saved_states=2), saved_states=2,
            measurements=(ValidationMetric(:maximum_relative_energy_drift,
                "Maximum relative energy drift", 1e-10; role=role_performance),))
        for index in 1:policy.sample_runs) : ()
    build_performance_benchmark_report(definition, environment,
        recorded_configuration, policy, samples, execution)
end

function _duration_sampling_suite(kind, family, environment; overrides=Dict())
    reports = Tuple(begin
        configuration = core_duration_sampling_configuration(kind, family, value)
        get(overrides, value,
            _duration_sampling_performance_report(configuration, environment))
    end for value in ValidationFramework._core_duration_sampling_values(kind, family))
    PerformanceSuiteReport(Symbol(family, :_, kind, :_test), "Duration/sampling test",
        VALIDATION_SCHEMA_VERSION, environment, reports)
end

@testset "Core duration and sampling configurations" begin
    cases = (
        (:duration, :figure_eight, CORE_DURATION_PERIODS, :periods,
            :figure_eight_duration),
        (:duration, :hierarchical_triple, CORE_DURATION_VALUES, :duration,
            :hierarchical_triple_duration),
        (:diagnostic_sampling, :figure_eight, CORE_DIAGNOSTIC_SAVEATS, :saveat,
            :figure_eight_diagnostic_sampling),
        (:diagnostic_sampling, :hierarchical_triple, CORE_DIAGNOSTIC_SAVEATS, :saveat,
            :hierarchical_triple_diagnostic_sampling),
    )
    for (kind, family, values, independent, series_id) in cases
        configurations = map(value -> core_duration_sampling_configuration(kind, family, value), values)
        definition = core_duration_sampling_investigation_definition(kind, family)
        @test definition.family_id == series_id
        @test definition.independent_variable == independent
        @test definition.required_metric_ids == ValidationFramework._core_tolerance_metric_ids(family)
        @test isempty(definition.optional_metric_ids)
        @test all(configuration -> configuration.algorithm_id == :vern9 &&
            configuration.solver_selector == :accurate, configurations)
        @test all(configuration -> configuration.relative_tolerance ==
            (family == :figure_eight ? 1e-12 : 1e-13), configurations)
        @test all(configuration -> configuration.arithmetic == :Float64, configurations)
        expected_benchmark = family == :figure_eight ?
            investigation_2_figure_eight_case_definition() :
            investigation_2_hierarchical_triple_case_definition()
        @test ValidationFramework._record_fields_equal(definition.benchmark,
            expected_benchmark)
    end
    figure_definition = investigation_2_figure_eight_case_definition()
    hierarchy_definition = investigation_2_hierarchical_triple_case_definition()
    @test figure_definition.case_id == :figure_eight_parameterized
    @test hierarchy_definition.case_id == :hierarchical_triple_parameterized
    @test occursin("explicitly recorded integer number of periods",
        figure_definition.description)
    @test !occursin("ten periods", lowercase(figure_definition.description))
    @test occursin("explicitly recorded physical duration", hierarchy_definition.description)
    @test figure_definition.source_path == "examples/validation/figure_eight_benchmark.jl"
    @test hierarchy_definition.source_path ==
        "examples/validation/hierarchical_triple_benchmark.jl"
    @test figure_definition.provenance == hierarchy_definition.provenance ==
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md"
    @test_throws ArgumentError core_duration_sampling_configuration(:duration,
        :figure_eight, 3)
    @test_throws ArgumentError core_duration_sampling_configuration(:diagnostic_sampling,
        :hierarchical_triple, 0.01)
    @test_throws ArgumentError CoreDurationSamplingConfiguration(:duration,
        :figure_eight, :tsit5, :fast, 1e-12, 1e-12; periods=1, saveat=0.02)
    @test_throws ArgumentError CoreDurationSamplingConfiguration(:duration,
        :figure_eight, :vern9, :accurate, 1e-11, 1e-11; periods=1, saveat=0.02)
    @test_throws ArgumentError CoreDurationSamplingConfiguration(:duration,
        :figure_eight, :vern9, :accurate, 1e-12, 1e-12; periods=1, saveat=0.1)
    @test_throws ArgumentError CoreDurationSamplingConfiguration(:diagnostic_sampling,
        :hierarchical_triple, :vern9, :accurate, 1e-13, 1e-13;
        duration=50.0, saveat=0.1)
    @test core_tolerance_investigation_definition(:figure_eight, :vern9).family_id ==
        :figure_eight_vern9_tolerance
end

@testset "Lightweight core observation path boundaries" begin
    package = ValidationFramework.ThreeBody3D
    report = package._run_figure_eight_benchmark(1, :fast, 1.0)
    @test report isa package.ValidationBenchmarkReport
    trajectory = package._run_figure_eight_benchmark_execution(1, :fast, 1.0)
    @test trajectory isa package.CoreValidationBenchmarkExecution
    observation_calls = Ref(0)
    observer = function (retained_report, result)
        observation_calls[] += 1
        package._snapshot_core_validation_observation(retained_report, result)
    end
    observation = package._run_figure_eight_benchmark_observation(
        1, :fast, 1.0; observer)
    @test observation isa package.CoreValidationBenchmarkObservation
    @test observation_calls[] == 1
    @test !hasproperty(observation, :states)
    @test length(observation.times) == observation.report.saved_states

    configuration = core_duration_sampling_configuration(:duration, :figure_eight, 1)
    fixture = _duration_sampling_observation(:duration, :figure_eight, 1)
    carrier = package.CoreValidationBenchmarkObservation(fixture.report, fixture.times,
        fixture.system, fixture.initial_state)
    direct_calls = Ref(0)
    runner = function (family; kwargs...)
        direct_calls[] += 1
        @test family == :figure_eight
        carrier
    end
    retained = run_core_benchmark_observation(configuration; runner)
    @test direct_calls[] == 1
    @test retained.times === carrier.times
    @test retained.initial_state === carrier.initial_state

    performance_calls = Ref(0)
    captured = Ref{Any}()
    report_runner = function (family; kwargs...)
        performance_calls[] += 1
        captured[] = (; family, kwargs...)
        fixture.report
    end
    core_duration_sampling_performance_operation(configuration;
        runner=report_runner)()
    @test performance_calls[] == 1
    @test captured[].family == configuration.benchmark_family
    @test captured[].solver == configuration.solver_selector
    @test captured[].reltol == configuration.relative_tolerance
    @test captured[].abstol == configuration.absolute_tolerance
    @test captured[].periods == configuration.periods
    @test captured[].duration == configuration.duration
    @test captured[].saveat == configuration.saveat
end

@testset "Core duration/sampling direct validation and grids" begin
    representatives = (
        (:duration, :figure_eight, 1),
        (:duration, :hierarchical_triple, 25.0),
        (:diagnostic_sampling, :figure_eight, 0.1),
        (:diagnostic_sampling, :figure_eight, 0.004),
        (:diagnostic_sampling, :hierarchical_triple, 0.004),
    )
    for arguments in representatives
        observation = _duration_sampling_observation(arguments...)
        @test ValidationFramework._validate_core_benchmark_observation(observation) === observation
        bad = copy(observation.times); bad[2] = bad[2] / 2
        @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
            _duration_sampling_observation(arguments...; times=bad))
    end
    observation = _duration_sampling_observation(:duration, :figure_eight, 1)
    range_grid = collect(0.0:observation.configuration.saveat:observation.report.final_time)
    last(range_grid) == observation.report.final_time || push!(range_grid,
        observation.report.final_time)
    @test range_grid != observation.times
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1; times=range_grid))
    for transform in (
        times -> (times[3] = times[2]; times),
        times -> (deleteat!(times, 3); times),
        times -> (insert!(times, 3, 0.03); times),
        times -> (times[1] = -0.02; times),
        times -> (times[end] -= 0.001; times),
        times -> (times[2] = Inf; times),
        times -> begin
            times[2], times[3] = times[3], times[2]
            times
        end,
    )
        bad = transform(copy(observation.times))
        @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
            _duration_sampling_observation(:duration, :figure_eight, 1; times=bad))
    end
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            report_changes=(name=:hierarchical_triple,)))
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            report_changes=(profile=:fast,)))
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            report_changes=(status=:unsupported,)))
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            report_changes=(expected_final_time=1.0,)))
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            report_changes=(saved_states=1,)))
    altered = ValidationFramework.ThreeBody3D.ThreeBodySystem((1.0, 1.0, 1.0); G=2.0)
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1; system=altered))
    initial = copy(observation.initial_state); initial[1] += 1e-6
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1; initial_state=initial))
    float_system, float_initial, _ = ValidationFramework.ThreeBody3D._figure_eight_benchmark_inputs(Float32)
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            system=float_system, initial_state=float_initial))
    big_inputs = ValidationFramework.ThreeBody3D._figure_eight_canonical_inputs(128)
    big_system, big_initial = big_inputs.system, big_inputs.initial_state
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            system=big_system, initial_state=big_initial))
    diagnostics = merge(observation.report.diagnostics,
        (maximum_relative_energy_drift=Inf,))
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :figure_eight, 1;
            report_changes=(; diagnostics)))
    hierarchy = _duration_sampling_observation(:duration, :hierarchical_triple, 25.0)
    @test isnan(hierarchy.report.periodicity_error)
    @test ValidationFramework._validate_core_benchmark_observation(hierarchy) === hierarchy
    @test_throws ArgumentError ValidationFramework._validate_core_benchmark_observation(
        _duration_sampling_observation(:duration, :hierarchical_triple, 25.0;
            report_changes=(benchmark_metrics=(minimum_hierarchy_ratio=9.0,),)))
end

@testset "Core duration/sampling attempts" begin
    completed = _duration_sampling_observation(:duration, :figure_eight, 1)
    terminated = _duration_sampling_observation(:duration, :figure_eight, 1;
        status=:terminated_close_approach)
    @test _duration_sampling_attempt(completed).execution.actual == actual_completed
    @test _duration_sampling_attempt(terminated).execution.actual == actual_terminated
    errored = attempt_core_benchmark_observation(completed.configuration;
        runner=_ -> error("synthetic observation failure"))
    @test errored.execution.actual == actual_errored
    @test isnothing(errored.evidence)
    @test occursin("synthetic observation failure", errored.notes)
    configuration = completed.configuration
    @test_throws ArgumentError CoreDurationSamplingAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0))
    @test_throws ArgumentError CoreDurationSamplingAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="no evidence"))
    @test_throws ArgumentError CoreDurationSamplingAttempt(configuration,
        ExecutionOutcome(actual_stopped; exit_code=1))
    @test_throws ArgumentError CoreDurationSamplingAttempt(configuration,
        ExecutionOutcome(actual_errored; exit_code=1))
    explained = CoreDurationSamplingAttempt(configuration,
        ExecutionOutcome(actual_errored; exit_code=1, summary="integration failed"))
    @test explained.execution.summary == "integration failed"
end

@testset "Core duration/sampling performance contracts" begin
    environment = _pilot_environment()
    for kind in (:duration, :diagnostic_sampling), family in (:figure_eight, :hierarchical_triple)
        values = ValidationFramework._core_duration_sampling_values(kind, family)
        configurations = map(value -> core_duration_sampling_configuration(kind, family, value), values)
        ids = map(core_duration_sampling_performance_benchmark_id, configurations)
        @test length(unique(ids)) == length(ids)
        @test map(decode_core_duration_sampling_benchmark_id, ids) == configurations
        @test all(configuration -> core_duration_sampling_performance_entry(configuration).policy.process_isolation,
            configurations)
        suite = _duration_sampling_suite(kind, family, environment)
        @test length(suite.benchmarks) == length(values)
        attempts = map(value -> _duration_sampling_attempt(
            _duration_sampling_observation(kind, family, value)), values)
        @test_throws ArgumentError core_duration_sampling_investigation_series(
            PerformanceSuiteReport(:missing, "Missing", VALIDATION_SCHEMA_VERSION,
                environment, suite.benchmarks[1:end-1]), attempts)
    end
    @test_throws ArgumentError decode_core_duration_sampling_benchmark_id(:invalid)

    kind, family = :duration, :figure_eight
    values = CORE_DURATION_PERIODS
    configurations = map(value -> core_duration_sampling_configuration(kind, family, value), values)
    attempts = map(value -> _duration_sampling_attempt(
        _duration_sampling_observation(kind, family, value)), values)
    suite = _duration_sampling_suite(kind, family, environment)
    @test_throws ArgumentError PerformanceSuiteReport(:duplicate, "Duplicate",
        VALIDATION_SCHEMA_VERSION, environment,
        (suite.benchmarks[1], suite.benchmarks[1], suite.benchmarks[3:end]...))
    extra_configuration = core_tolerance_configuration(:figure_eight, :vern9, 1e-9)
    extra = _core_performance_report(extra_configuration, environment)
    @test_throws ArgumentError core_duration_sampling_investigation_series(
        PerformanceSuiteReport(:extra, "Extra", VALIDATION_SCHEMA_VERSION,
            environment, (suite.benchmarks..., extra)), attempts)
    original = suite.benchmarks[2]
    wrong_definition = _definition_with_version(original.definition, "9.9.9")
    wrong_configuration = ValidationFramework._core_duration_sampling_validation_configuration(
        configurations[3])
    for replacement in (
        _duration_sampling_performance_report(configurations[2], environment;
            definition=wrong_definition),
        _duration_sampling_performance_report(configurations[2], environment;
            recorded_configuration=wrong_configuration),
        _duration_sampling_performance_report(configurations[2], environment;
            policy=QuickBenchmark()),
    )
        @test_throws ArgumentError core_duration_sampling_investigation_series(
            _duration_sampling_suite(kind, family, environment;
                overrides=Dict(values[2] => replacement)), attempts)
    end
    other_environment = ValidationEnvironment(environment.schema_version,
        environment.package_version, environment.repository_commit,
        environment.repository_dirty, environment.julia_version,
        environment.operating_system, environment.architecture,
        environment.thread_count, "2099-01-01T00:00:00Z")
    @test_throws ArgumentError PerformanceSuiteReport(:environment, "Environment",
        VALIDATION_SCHEMA_VERSION, environment,
        (suite.benchmarks[1:end-1]...,
         _duration_sampling_performance_report(configurations[end], other_environment)))
end

@testset "Core duration/sampling series and serialization" begin
    environment = _pilot_environment()
    expected_point_ids = Dict(
        (:duration, :figure_eight) =>
            (:periods_1, :periods_2, :periods_5, :periods_10, :periods_20),
        (:duration, :hierarchical_triple) =>
            (:duration_25, :duration_50, :duration_100, :duration_200),
        (:diagnostic_sampling, :figure_eight) =>
            (:saveat_0_1, :saveat_0_02, :saveat_0_004),
        (:diagnostic_sampling, :hierarchical_triple) =>
            (:saveat_0_1, :saveat_0_02, :saveat_0_004),
    )
    for kind in (:duration, :diagnostic_sampling), family in (:figure_eight, :hierarchical_triple)
        values = ValidationFramework._core_duration_sampling_values(kind, family)
        attempts = map(value -> _duration_sampling_attempt(
            _duration_sampling_observation(kind, family, value)), values)
        suite = _duration_sampling_suite(kind, family, environment)
        series = core_duration_sampling_investigation_series(suite, attempts)
        @test length(series.points) == length(values)
        @test map(point -> point.point_id, series.points) == expected_point_ids[(kind, family)]
        @test map(point -> point.independent_value.value, series.points) == values
        @test all(point -> point.environment == environment, series.points)
        @test all(point -> !isnothing(point.solver_statistics), series.points)
        @test all(point -> !isnothing(point.performance_report), series.points)
        @test all(point -> isempty(intersect(map(metric -> metric.metric_id, point.metrics),
            CORE_TOLERANCE_COMPARISON_METRICS)), series.points)
        text = investigation_series_report_text(series)
        @test !occursin("saved physical times", lowercase(text))
        restored = read_investigation_series(IOBuffer(text))
        @test restored.series_id == series.series_id
        @test restored.title == series.title
        @test restored.description == series.description
        @test ValidationFramework._record_fields_equal(restored.definition,
            series.definition)
        @test map(point -> point.point_id, restored.points) == map(point -> point.point_id, series.points)
        for (left, right) in zip(restored.points, series.points)
            @test left.independent_value == right.independent_value
            @test ValidationFramework._record_fields_equal(left.configuration,
                right.configuration)
            @test ValidationFramework._record_fields_equal(left.environment,
                right.environment)
            @test left.execution == right.execution
            @test left.metrics == right.metrics
            @test map(metric -> metric.metric_id, left.metrics) ==
                map(metric -> metric.metric_id, right.metrics)
            @test left.solver_statistics == right.solver_statistics
            @test ValidationFramework._record_fields_equal(left.performance_report,
                right.performance_report)
            @test left.notes == right.notes
            @test isnothing(left.supporting_evidence)
            @test isempty(intersect(map(metric -> metric.metric_id, left.metrics),
                CORE_TOLERANCE_COMPARISON_METRICS))
        end
    end

    kind, family = :duration, :figure_eight
    values = CORE_DURATION_PERIODS
    attempts = collect(map(value -> _duration_sampling_attempt(
        _duration_sampling_observation(kind, family, value)), values))
    terminated_summary = "direct benchmark terminated"
    terminated_evidence = _duration_sampling_observation(kind, family, values[2];
        status=:terminated_close_approach)
    attempts[2] = CoreDurationSamplingAttempt(terminated_evidence.configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary=terminated_summary),
        terminated_evidence)
    direct_summary = "middle direct failure"
    attempts[3] = CoreDurationSamplingAttempt(
        core_duration_sampling_configuration(kind, family, values[3]),
        ExecutionOutcome(actual_errored; exit_code=1, summary=direct_summary))
    environment = _pilot_environment()
    failed_performance = _duration_sampling_performance_report(
        core_duration_sampling_configuration(kind, family, values[4]), environment;
        execution=ExecutionOutcome(actual_errored; exit_code=1,
            summary="performance child failure"))
    suite = _duration_sampling_suite(kind, family, environment;
        overrides=Dict(values[4] => failed_performance))
    series = core_duration_sampling_investigation_series(suite, Tuple(attempts))
    @test series.points[2].execution.actual == actual_terminated
    @test series.points[2].notes == "Direct execution: $terminated_summary"
    @test series.points[3].execution.actual == actual_errored
    @test series.points[3].notes == "Direct execution: $direct_summary"
    @test isempty(series.points[3].metrics)
    @test isnothing(series.points[3].solver_statistics)
    @test !isnothing(series.points[3].performance_report)
    @test series.points[4].execution.actual == actual_errored
    @test occursin("Performance execution", series.points[4].notes)
    @test !isempty(series.points[5].metrics)
    restored_failure = read_investigation_series(IOBuffer(
        investigation_series_report_text(series)))
    @test restored_failure.points[2].execution.summary == terminated_summary
    @test restored_failure.points[2].notes == "Direct execution: $terminated_summary"
    @test restored_failure.points[3].execution.summary == direct_summary
    @test restored_failure.points[3].notes == "Direct execution: $direct_summary"
    @test restored_failure.points[4].performance_report.execution.summary ==
        "performance child failure"
    @test occursin("Performance execution: performance child failure",
        restored_failure.points[4].notes)

    duplicate_attempts = collect(attempts)
    duplicate_attempts[2] = CoreDurationSamplingAttempt(terminated_evidence.configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary=terminated_summary),
        terminated_evidence; notes=terminated_summary)
    duplicate_series = core_duration_sampling_investigation_series(suite,
        Tuple(duplicate_attempts))
    @test length(findall(terminated_summary, duplicate_series.points[2].notes)) == 1
    duplicate_attempts[2] = CoreDurationSamplingAttempt(terminated_evidence.configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary=terminated_summary),
        terminated_evidence; notes="additional direct context")
    detailed_series = core_duration_sampling_investigation_series(suite,
        Tuple(duplicate_attempts))
    @test occursin("additional direct context", detailed_series.points[2].notes)
    @test occursin(terminated_summary, detailed_series.points[2].notes)
end

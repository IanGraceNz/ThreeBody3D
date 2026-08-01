function _core_fixture_report(family, algorithm, times; status=:completed,
    report_family=family, profile=algorithm == :tsit5 ? :fast : :accurate,
    expected_final_time=last(times), saved_states=length(times))
    diagnostics = (
        maximum_relative_energy_drift=1e-10,
        maximum_linear_momentum_drift=2e-12,
        maximum_angular_momentum_drift=3e-12,
        maximum_center_of_mass_residual=4e-12,
        minimum_separation=0.5,
    )
    (
        name=report_family, status, profile, initial_time=0.0,
        final_time=last(times), expected_final_time,
        diagnostics, periodicity_error=family == :figure_eight ? 1e-7 : NaN,
        benchmark_metrics=family == :figure_eight ? NamedTuple() :
            (initial_hierarchy_ratio=10.0,
             minimum_hierarchy_ratio=9.9, final_hierarchy_ratio=10.1),
        saved_states, accepted_steps=10, rejected_steps=1, rhs_evaluations=70,
    )
end


function _core_performance_report(configuration, environment;
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    definition=core_tolerance_performance_definition(configuration),
    recorded_configuration=ValidationFramework._core_validation_configuration(configuration),
    policy=StandardBenchmark())
    samples = execution.actual == actual_completed ? Tuple(
        PerformanceSample(index; elapsed_seconds=0.01 * index,
            solver_statistics=SolverStatistics(accepted_steps=10, rejected_steps=1,
                rhs_evaluations=70, saved_states=2), saved_states=2,
            measurements=(ValidationMetric(:maximum_relative_energy_drift,
                "Maximum relative energy drift", 1e-10; role=role_performance),))
        for index in 1:policy.sample_runs) : ()
    build_performance_benchmark_report(definition, environment, recorded_configuration,
        policy, samples, execution)
end

function _core_performance_suite(family, algorithm, environment; overrides=Dict())
    reports = Tuple(get(overrides, tolerance,
        _core_performance_report(core_tolerance_configuration(family, algorithm, tolerance), environment))
        for tolerance in CORE_TOLERANCE_VALUES)
    PerformanceSuiteReport(:core_tolerance_test, "Core tolerance test",
        VALIDATION_SCHEMA_VERSION, environment, reports)
end

_core_attempt(execution) = CoreToleranceAttempt(execution.configuration,
    ExecutionOutcome(execution.report.status == :completed ? actual_completed : actual_terminated;
        exit_code=execution.report.status == :completed ? 0 : 1,
        summary=execution.report.status == :completed ? nothing : "terminated"), execution;
    notes=execution.report.status == :completed ? nothing : "terminated")

function _core_fixture_execution(family, algorithm, tolerance;
    translation=(0.0, 0.0, 0.0), velocity_offset=(0.0, 0.0, 0.0),
    position_delta=0.0, status=:completed, times=nothing, report_kwargs=NamedTuple())
    configuration = core_tolerance_configuration(family, algorithm, tolerance)
    system, initial, _ = family == :figure_eight ?
        ValidationFramework.ThreeBody3D._figure_eight_benchmark_inputs() :
        ValidationFramework.ThreeBody3D._hierarchical_triple_benchmark_inputs()
    final_time = family == :figure_eight ?
        ValidationFramework.ThreeBody3D.FIGURE_EIGHT_PERIOD * 10 : 100.0
    if isnothing(times)
        times = ValidationFramework._core_scalar_saveat_grid(final_time, 0.02)
    end
    states = [begin
        state = copy(initial)
        for body in 1:3
            position = 6(body - 1) + 1:6(body - 1) + 3
            velocity = 6(body - 1) + 4:6(body - 1) + 6
            index > 1 && (state[position] .+= collect(translation))
            index > 1 && (state[velocity] .+= collect(velocity_offset))
        end
        state[1] += position_delta * (index - 1) / max(length(times) - 1, 1)
        state
    end for index in eachindex(times)]
    CoreToleranceExecution(
        configuration, _core_fixture_report(family, algorithm, times; status, report_kwargs...), collect(times), states,
        system, initial,
    )
end

@testset "Core tolerance configurations and definitions" begin
    ids = Tuple(core_tolerance_investigation_definition(family, algorithm).family_id
        for family in (:figure_eight, :hierarchical_triple)
        for algorithm in (:tsit5, :vern9))
    @test ids == (:figure_eight_tsit5_tolerance, :figure_eight_vern9_tolerance,
                  :hierarchical_triple_tsit5_tolerance, :hierarchical_triple_vern9_tolerance)
    @test core_tolerance_configuration(:figure_eight, :tsit5, 1e-9).solver_selector == :fast
    @test core_tolerance_configuration(:figure_eight, :vern9, 1e-12).solver_selector == :accurate
    @test core_tolerance_configuration(:hierarchical_triple, :vern9, 1e-13).duration == 100.0
    @test_throws ArgumentError CoreToleranceExperimentConfiguration(
        :figure_eight, :tsit5, :accurate, 1e-9, 1e-9; periods=10)
    @test_throws ArgumentError CoreToleranceExperimentConfiguration(
        :figure_eight, :tsit5, :fast, 1e-9, 1e-10; periods=10)
    @test_throws ArgumentError CoreToleranceExperimentConfiguration(
        :figure_eight, :tsit5, :fast, 1e-9, 1e-9; duration=10.0)
    @test_throws ArgumentError CoreToleranceExperimentConfiguration(
        :hierarchical_triple, :vern9, :accurate, 1e-9, 1e-9; periods=10)
    definition = core_tolerance_investigation_definition(:figure_eight, :tsit5)
    @test definition.independent_variable == :integration_tolerance
    @test definition.optional_metric_ids == CORE_TOLERANCE_COMPARISON_METRICS
    @test figure_eight_profile_investigation_definition().family_id == :figure_eight_profile
    expected_figure_eight = ValidationCaseDefinition(:figure_eight,
        "Figure-eight validation benchmark",
        "Strongly coupled periodic equal-mass three-body choreography propagated for ten periods.",
        (:periodic_orbit, :conservation, :reference_state),
        (:figure_eight, :core_benchmark), "examples/validation/figure_eight_benchmark.jl",
        (:standard,), expected_completed, true, "1.0.0",
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md")
    expected_hierarchy = ValidationCaseDefinition(:hierarchical_triple,
        "Hierarchical-triple validation benchmark",
        "Long-duration weakly perturbed hierarchical triple with conservation and hierarchy checks.",
        (:hierarchical_system, :conservation, :multiscale),
        (:hierarchical_triple, :core_benchmark),
        "examples/validation/hierarchical_triple_benchmark.jl", (:standard,),
        expected_completed, true, "1.0.0", "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md")
    @test ValidationFramework._record_fields_equal(figure_eight_case_definition(),
        expected_figure_eight)
    @test ValidationFramework._record_fields_equal(hierarchical_triple_case_definition(),
        expected_hierarchy)
end

@testset "Core tolerance point-contract validation" begin
    vern9 = _core_fixture_execution(:figure_eight, :vern9, 1e-9)
    bad_profile = CoreToleranceExecution(vern9.configuration,
        merge(vern9.report, (profile=:fast,)), vern9.times, vern9.states,
        vern9.system, vern9.initial_state)
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(bad_profile)
    bad_family = CoreToleranceExecution(vern9.configuration,
        merge(vern9.report, (name=:hierarchical_triple,)), vern9.times, vern9.states,
        vern9.system, vern9.initial_state)
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(bad_family)
    five_periods = CoreToleranceExperimentConfiguration(
        :figure_eight, :vern9, :accurate, 1e-9, 1e-9; periods=5, saveat=0.02)
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(five_periods, vern9.report, vern9.times, vern9.states,
            vern9.system, vern9.initial_state), five_periods)
    hierarchical = _core_fixture_execution(:hierarchical_triple, :tsit5, 1e-9)
    other_duration = CoreToleranceExperimentConfiguration(
        :hierarchical_triple, :tsit5, :fast, 1e-9, 1e-9; duration=50.0, saveat=0.02)
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(other_duration, hierarchical.report, hierarchical.times,
            hierarchical.states, hierarchical.system, hierarchical.initial_state), other_duration)
    altered_system = ValidationFramework.ThreeBody3D.ThreeBodySystem(
        Tuple(vern9.system.masses); G=2.0)
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(vern9.configuration, vern9.report, vern9.times, vern9.states,
            altered_system, vern9.initial_state))
    altered_initial = copy(vern9.initial_state); altered_initial[1] += 1e-6
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(vern9.configuration, vern9.report, vern9.times, vern9.states,
            vern9.system, altered_initial))
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(vern9.configuration,
            merge(vern9.report, (expected_final_time=1.0,)), vern9.times, vern9.states,
            vern9.system, vern9.initial_state))
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(vern9.configuration,
            merge(vern9.report, (final_time=vern9.report.final_time - 0.01,)),
            vern9.times, vern9.states, vern9.system, vern9.initial_state))
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(vern9.configuration,
            merge(vern9.report, (saved_states=length(vern9.times)-1,)), vern9.times,
            vern9.states, vern9.system, vern9.initial_state))

    environment = _pilot_environment()
    altered_attempts = Tuple(begin
        item = _core_fixture_execution(:figure_eight, :vern9, tolerance)
        altered = CoreToleranceExecution(item.configuration, item.report, item.times,
            item.states, altered_system, item.initial_state)
        CoreToleranceAttempt(item.configuration,
            ExecutionOutcome(actual_completed; exit_code=0), altered)
    end for tolerance in CORE_TOLERANCE_VALUES)
    @test_throws ArgumentError core_tolerance_investigation_series(
        _core_performance_suite(:figure_eight, :vern9, environment), altered_attempts)

    five_period_attempts = Tuple(begin
        item = _core_fixture_execution(:figure_eight, :vern9, tolerance)
        configuration = CoreToleranceExperimentConfiguration(:figure_eight, :vern9,
            :accurate, tolerance, tolerance; periods=5, saveat=0.02)
        CoreToleranceAttempt(configuration, ExecutionOutcome(actual_completed; exit_code=0),
            CoreToleranceExecution(configuration, item.report, item.times, item.states,
                item.system, item.initial_state))
    end for tolerance in CORE_TOLERANCE_VALUES)
    @test_throws ArgumentError core_tolerance_investigation_series(
        _core_performance_suite(:figure_eight, :vern9, environment), five_period_attempts)
    other_duration_attempts = Tuple(begin
        item = _core_fixture_execution(:hierarchical_triple, :tsit5, tolerance)
        configuration = CoreToleranceExperimentConfiguration(:hierarchical_triple, :tsit5,
            :fast, tolerance, tolerance; duration=50.0, saveat=0.02)
        CoreToleranceAttempt(configuration, ExecutionOutcome(actual_completed; exit_code=0),
            CoreToleranceExecution(configuration, item.report, item.times, item.states,
                item.system, item.initial_state))
    end for tolerance in CORE_TOLERANCE_VALUES)
    @test_throws ArgumentError core_tolerance_investigation_series(
        _core_performance_suite(:hierarchical_triple, :tsit5, environment),
        other_duration_attempts)
end

@testset "Core tolerance attempt invariants and wrapper" begin
    configuration = core_tolerance_configuration(:figure_eight, :tsit5, 1e-9)
    completed_evidence = _core_fixture_execution(:figure_eight, :tsit5, 1e-9)
    terminated_evidence = _core_fixture_execution(:figure_eight, :tsit5, 1e-9;
        status=:terminated_close_approach)
    completed = CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0), completed_evidence)
    terminated = CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="close approach"),
        terminated_evidence)
    errored = attempt_core_tolerance_experiment(configuration;
        runner=_ -> error("synthetic thrown error"))
    @test completed.execution.actual == actual_completed
    @test terminated.execution.actual == actual_terminated
    @test errored.execution.actual == actual_errored
    @test isnothing(errored.evidence)
    @test occursin("synthetic thrown error", errored.execution.summary)
    @test attempt_core_tolerance_experiment(configuration;
        runner=_ -> completed_evidence).execution.actual == actual_completed
    @test attempt_core_tolerance_experiment(configuration;
        runner=_ -> terminated_evidence).execution.actual == actual_terminated

    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0))
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="missing evidence"))
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_stopped; exit_code=1))
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_errored; exit_code=1))
    explained = CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_errored; exit_code=1, summary="integration failed"))
    @test explained.execution.summary == "integration failed"
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_errored; exit_code=1, summary="wrong"), completed_evidence)
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0), terminated_evidence)
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="wrong"), completed_evidence)
    unsupported = CoreToleranceExecution(configuration,
        merge(completed_evidence.report, (status=:arbitrary_status,)),
        completed_evidence.times, completed_evidence.states,
        completed_evidence.system, completed_evidence.initial_state)
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="unsupported"), unsupported)
    abnormal_completed = ExecutionOutcome(actual_completed; exit_code=0,
        summary="unexpected completed summary")
    @test_throws ArgumentError CoreToleranceAttempt(configuration,
        abnormal_completed, completed_evidence)
end

@testset "Core retained initial state and Float64 arithmetic" begin
    execution = _core_fixture_execution(:figure_eight, :tsit5, 1e-9)
    altered_first = copy(execution.states)
    altered_first[1] = copy(altered_first[1]); altered_first[1][1] += 1e-6
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(execution.configuration, execution.report, execution.times,
            altered_first, execution.system, execution.initial_state))
    altered_later = copy(execution.states)
    altered_later[2] = copy(altered_later[2]); altered_later[2][1] += 1e-6
    @test ValidationFramework._validate_core_tolerance_execution(
        CoreToleranceExecution(execution.configuration, execution.report, execution.times,
            altered_later, execution.system, execution.initial_state)) isa CoreToleranceExecution

    function arithmetic_execution(::Type{T}) where {T<:AbstractFloat}
        system, initial, _ = ValidationFramework.ThreeBody3D._figure_eight_benchmark_inputs(T)
        diagnostics = NamedTuple{propertynames(execution.report.diagnostics)}(
            Tuple(T(getproperty(execution.report.diagnostics, name))
                for name in propertynames(execution.report.diagnostics)))
        report = merge(execution.report, (
            initial_time=T(execution.report.initial_time),
            final_time=T(execution.report.final_time),
            expected_final_time=T(execution.report.expected_final_time),
            diagnostics, periodicity_error=T(execution.report.periodicity_error)))
        CoreToleranceExecution(execution.configuration, report, T.(execution.times),
            [T.(state) for state in execution.states], system, initial)
    end
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        arithmetic_execution(Float32))
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        arithmetic_execution(BigFloat))
end

@testset "Core direct report numerical evidence" begin
    figure = _core_fixture_execution(:figure_eight, :tsit5, 1e-9)
    function with_figure_report(report)
        CoreToleranceExecution(figure.configuration, report, figure.times, figure.states,
            figure.system, figure.initial_state)
    end
    for diagnostics in (
        merge(figure.report.diagnostics, (maximum_relative_energy_drift=Inf,)),
        merge(figure.report.diagnostics, (minimum_separation=Inf,)),
        merge(figure.report.diagnostics, (minimum_separation=-1.0,)),
    )
        @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
            with_figure_report(merge(figure.report, (; diagnostics))))
    end
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        with_figure_report(merge(figure.report, (periodicity_error=NaN,))))

    hierarchical = _core_fixture_execution(:hierarchical_triple, :vern9, 1e-9)
    function with_hierarchy_metrics(metrics)
        CoreToleranceExecution(hierarchical.configuration,
            merge(hierarchical.report, (benchmark_metrics=metrics,)),
            hierarchical.times, hierarchical.states, hierarchical.system,
            hierarchical.initial_state)
    end
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        with_hierarchy_metrics((initial_hierarchy_ratio=10.0,
            minimum_hierarchy_ratio=9.0)))
    @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(
        with_hierarchy_metrics((initial_hierarchy_ratio=10.0,
            minimum_hierarchy_ratio=NaN, final_hierarchy_ratio=10.0)))
    @test ValidationFramework._validate_core_tolerance_execution(hierarchical) === hierarchical

    malformed = with_figure_report(merge(figure.report,
        (diagnostics=merge(figure.report.diagnostics,
            (maximum_relative_energy_drift=Inf,)),)))
    malformed_attempt = attempt_core_tolerance_experiment(figure.configuration;
        runner=_ -> malformed)
    @test malformed_attempt.execution.actual == actual_errored
    @test isnothing(malformed_attempt.evidence)
    @test occursin("diagnostics", malformed_attempt.execution.summary)
end

@testset "Exact approved core saved grids" begin
    execution = _core_fixture_execution(:figure_eight, :tsit5, 1e-9)
    function with_times(times)
        states = [execution.states[min(index, length(execution.states))]
            for index in eachindex(times)]
        report = merge(execution.report,
            (final_time=last(times), saved_states=length(times)))
        CoreToleranceExecution(execution.configuration, report, collect(times), states,
            execution.system, execution.initial_state)
    end
    wrong_spacing = collect(execution.times); wrong_spacing[2] = 0.01
    duplicate = collect(execution.times); duplicate[3] = duplicate[2]
    missing = collect(execution.times); deleteat!(missing, 3)
    wrong_initial = collect(execution.times); wrong_initial[1] = -0.02
    wrong_final = collect(execution.times); wrong_final[end] -= 0.001
    nonfinite = collect(execution.times); nonfinite[2] = Inf
    for times in (wrong_spacing, duplicate, missing, wrong_initial, wrong_final, nonfinite)
        @test_throws ArgumentError ValidationFramework._validate_core_tolerance_execution(with_times(times))
        loose = with_times(times)
        tight_source = _core_fixture_execution(:figure_eight, :tsit5, 1e-10)
        tight_report = merge(tight_source.report,
            (final_time=last(times), saved_states=length(times)))
        tight = CoreToleranceExecution(tight_source.configuration, tight_report,
            collect(times), loose.states, tight_source.system, tight_source.initial_state)
        @test_throws ArgumentError compare_adjacent_core_tolerances(loose, tight)
    end
end

@testset "Adjacent core tolerance comparison" begin
    loose = _core_fixture_execution(:figure_eight, :tsit5, 1e-9; position_delta=0.01)
    tight = _core_fixture_execution(:figure_eight, :tsit5, 1e-10)
    comparison = compare_adjacent_core_tolerances(loose, tight)
    @test comparison.maximum_position_difference > 0
    @test comparison.final_position_difference == comparison.maximum_position_difference
    @test comparison.maximum_velocity_difference == 0
    translated = _core_fixture_execution(:figure_eight, :tsit5, 1e-9;
        translation=(3.0, -2.0, 1.0), velocity_offset=(4.0, 2.0, -1.0))
    @test compare_adjacent_core_tolerances(translated, tight).maximum_scaled_state_difference ≈ 0 atol=1e-15
    @test_throws ArgumentError compare_adjacent_core_tolerances(tight, loose)
    @test_throws ArgumentError compare_adjacent_core_tolerances(
        loose, _core_fixture_execution(:figure_eight, :tsit5, 1e-11))
    @test_throws ArgumentError compare_adjacent_core_tolerances(
        _core_fixture_execution(:figure_eight, :vern9, 1e-9), tight)
    @test_throws ArgumentError compare_adjacent_core_tolerances(
        _core_fixture_execution(:figure_eight, :tsit5, 1e-9; times=(0.0, 0.03)), tight)
    malformed = CoreToleranceExecution(loose.configuration, loose.report, loose.times,
        ([1.0], [1.0]), loose.system, loose.initial_state)
    @test_throws ArgumentError compare_adjacent_core_tolerances(malformed, tight)
    nonfinite = CoreToleranceExecution(loose.configuration, loose.report, loose.times,
        (loose.states[1], fill(Inf, 18)), loose.system, loose.initial_state)
    @test_throws ArgumentError compare_adjacent_core_tolerances(nonfinite, tight)
    huge_states = copy(loose.states)
    huge_states[end] = fill(1e308, 18)
    huge = CoreToleranceExecution(loose.configuration, loose.report, loose.times,
        huge_states, loose.system, loose.initial_state)
    @test_throws ArgumentError compare_adjacent_core_tolerances(huge, tight)
    other_system = ValidationFramework.ThreeBody3D.ThreeBodySystem((1.0, 1.0, 1.0); G=2.0)
    @test_throws ArgumentError compare_adjacent_core_tolerances(loose,
        CoreToleranceExecution(tight.configuration, tight.report, tight.times, tight.states,
            other_system, tight.initial_state))
    changed_initial = copy(tight.initial_state); changed_initial[1] += 1e-3
    @test_throws ArgumentError compare_adjacent_core_tolerances(loose,
        CoreToleranceExecution(tight.configuration, tight.report, tight.times, tight.states,
            tight.system, changed_initial))
    changed_control = CoreToleranceExperimentConfiguration(
        :figure_eight, :tsit5, :fast, 1e-10, 1e-10; periods=5, saveat=0.02)
    @test_throws ArgumentError compare_adjacent_core_tolerances(loose,
        CoreToleranceExecution(changed_control, tight.report, tight.times, tight.states,
            tight.system, tight.initial_state))
    zero_state = zeros(18)
    zero_scales = ValidationFramework._core_characteristic_scales(loose.system, zero_state)
    @test zero_scales.position_scale == 1
    @test zero_scales.velocity_scale == 1
    @test zero_scales.position_scale_fallback
    @test zero_scales.velocity_scale_fallback
end


@testset "Public core benchmark compatibility" begin
    figure = ValidationFramework.ThreeBody3D.run_validation_benchmark(
        :figure_eight; periods=1, saveat=1.0)
    hierarchical = ValidationFramework.ThreeBody3D.run_validation_benchmark(
        :hierarchical_triple; duration=1.0, saveat=0.5)
    @test figure isa ValidationFramework.ThreeBody3D.ValidationBenchmarkReport
    @test hierarchical isa ValidationFramework.ThreeBody3D.ValidationBenchmarkReport
    @test figure.profile == :accurate
    @test hierarchical.profile == :accurate
    @test figure.expected_final_time == ValidationFramework.ThreeBody3D.FIGURE_EIGHT_PERIOD
    @test hierarchical.expected_final_time == 1.0
end

@testset "Report-only and trajectory-retaining core paths" begin
    package = ValidationFramework.ThreeBody3D
    for (family, report_runner, execution_runner, arguments) in (
        (:figure_eight, package._run_figure_eight_benchmark,
            package._run_figure_eight_benchmark_execution,
            (periods=1, solver=:fast, saveat=1.0)),
        (:hierarchical_triple, package._run_hierarchical_triple_benchmark,
            package._run_hierarchical_triple_benchmark_execution,
            (duration=1.0, solver=:fast, saveat=0.5)),
    )
        snapshot_calls = Ref(0)
        report = report_runner(values(arguments)...)
        @test report isa package.ValidationBenchmarkReport
        @test snapshot_calls[] == 0
        snapshotter = function (retained_report, result)
            snapshot_calls[] += 1
            package._snapshot_core_validation_execution(retained_report, result)
        end
        execution = execution_runner(values(arguments)...; snapshotter)
        @test execution isa package.CoreValidationBenchmarkExecution
        @test snapshot_calls[] == 1
        @test all(field -> field == :diagnostics ||
            isequal(getfield(execution.report, field), getfield(report, field)),
            fieldnames(typeof(report)))
        @test all(field -> getfield(execution.report.diagnostics, field) ==
            getfield(report.diagnostics, field), fieldnames(typeof(report.diagnostics)))
        @test execution.report.name == family
    end

    configuration = core_tolerance_configuration(:figure_eight, :tsit5, 1e-9)
    fixture = _core_fixture_execution(:figure_eight, :tsit5, 1e-9)
    carrier = package.CoreValidationBenchmarkExecution(fixture.report, fixture.times,
        fixture.states, fixture.system, fixture.initial_state)
    calls = Ref(0)
    runner = function (family; kwargs...)
        calls[] += 1
        @test family == :figure_eight
        @test kwargs[:solver] == :fast
        carrier
    end
    direct = run_core_tolerance_experiment(configuration; runner)
    @test calls[] == 1
    @test direct.times === carrier.times
    @test direct.states === carrier.states
    @test direct.initial_state === carrier.initial_state
end

@testset "Core tolerance series construction and serialization" begin
    environment = _pilot_environment()
    for family in (:figure_eight, :hierarchical_triple), algorithm in (:tsit5, :vern9)
        executions = Tuple(_core_fixture_execution(family, algorithm, tolerance;
            position_delta=1e-3 * index) for (index, tolerance) in enumerate(CORE_TOLERANCE_VALUES))
        suite = _core_performance_suite(family, algorithm, environment)
        series = core_tolerance_investigation_series(suite, map(_core_attempt, executions))
        @test series.series_id == Symbol(family, :_, algorithm, :_tolerance)
        @test map(point -> point.independent_value.value, series.points) == CORE_TOLERANCE_VALUES
        @test all(point -> point.configuration.relative_tolerance == point.independent_value.value, series.points)
        @test all(id -> id in map(metric -> metric.metric_id, series.points[1].metrics), CORE_TOLERANCE_COMPARISON_METRICS)
        @test all(id -> id ∉ map(metric -> metric.metric_id, series.points[end].metrics), CORE_TOLERANCE_COMPARISON_METRICS)
        text = investigation_series_report_text(series)
        restored = read_investigation_series(IOBuffer(text))
        @test ValidationFramework._record_fields_equal(restored.definition, series.definition)
        @test map(point -> point.point_id, restored.points) == map(point -> point.point_id, series.points)
        @test map(point -> point.configuration, restored.points) == map(point -> point.configuration, series.points)
        @test map(point -> point.independent_value, restored.points) == map(point -> point.independent_value, series.points)
        @test map(point -> map(metric -> metric.metric_id, point.metrics), restored.points) ==
            map(point -> map(metric -> metric.metric_id, point.metrics), series.points)
        for (left, right) in zip(restored.points, series.points)
            @test left.metrics == right.metrics
            @test left.solver_statistics == right.solver_statistics
            @test left.performance_report == right.performance_report
            @test left.execution == right.execution
            @test left.notes == right.notes
        end

        unsuccessful = collect(executions)
        unsuccessful[3] = _core_fixture_execution(family, algorithm, 1e-11;
            status=:terminated_close_approach)
        partial = core_tolerance_investigation_series(suite, map(_core_attempt, Tuple(unsuccessful)))
        @test map(point -> point.independent_value.value, partial.points) == CORE_TOLERANCE_VALUES
        @test partial.points[3].execution.actual == actual_terminated
        @test !isempty(partial.points[3].metrics)
        @test all(id -> id ∉ map(metric -> metric.metric_id, partial.points[2].metrics),
            CORE_TOLERANCE_COMPARISON_METRICS)
    end
end

@testset "Core tolerance direct summary notes" begin
    family, algorithm = :figure_eight, :tsit5
    environment = _pilot_environment()
    executions = Tuple(_core_fixture_execution(family, algorithm, tolerance)
        for tolerance in CORE_TOLERANCE_VALUES)
    attempts = collect(map(_core_attempt, executions))
    terminated_summary = "direct tolerance benchmark terminated"
    terminated_evidence = _core_fixture_execution(family, algorithm,
        CORE_TOLERANCE_VALUES[2]; status=:terminated_close_approach)
    attempts[2] = CoreToleranceAttempt(terminated_evidence.configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary=terminated_summary),
        terminated_evidence)
    errored_summary = "direct tolerance integration failed"
    attempts[3] = CoreToleranceAttempt(executions[3].configuration,
        ExecutionOutcome(actual_errored; exit_code=1, summary=errored_summary))
    series = core_tolerance_investigation_series(
        _core_performance_suite(family, algorithm, environment), Tuple(attempts))
    @test series.points[2].notes == "Direct execution: $terminated_summary"
    @test series.points[3].notes == "Direct execution: $errored_summary"

    attempts[2] = CoreToleranceAttempt(terminated_evidence.configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary=terminated_summary),
        terminated_evidence; notes=terminated_summary)
    duplicate_series = core_tolerance_investigation_series(
        _core_performance_suite(family, algorithm, environment), Tuple(attempts))
    @test length(findall(terminated_summary, duplicate_series.points[2].notes)) == 1
end

@testset "Parameterized core performance identity" begin
    configuration = core_tolerance_configuration(:figure_eight, :vern9, 1e-12)
    id = core_tolerance_performance_benchmark_id(:figure_eight, :vern9, 1e-12)
    @test id == :figure_eight_vern9_tolerance_1e_12
    @test decode_core_tolerance_benchmark_id(id) == configuration
    @test core_tolerance_performance_definition(configuration).benchmark_id == id
    entry = core_tolerance_performance_entry(configuration)
    @test entry.policy.process_isolation
    @test isfile(entry.path)
    @test entry.configuration.relative_tolerance == 1e-12
    @test_throws ArgumentError decode_core_tolerance_benchmark_id(:invalid)

    captured = Ref{Any}()
    fixture = _core_fixture_execution(:figure_eight, :vern9, 1e-12)
    fake_runner = function (family; kwargs...)
        captured[] = (; family, kwargs...)
        fixture.report
    end
    observation = core_tolerance_performance_operation(configuration; runner=fake_runner)()
    @test captured[].family == :figure_eight
    @test captured[].solver == :accurate
    @test captured[].reltol == captured[].abstol == 1e-12
    @test captured[].periods == 10
    @test captured[].saveat == 0.02
    @test observation.saved_states == fixture.report.saved_states
end

@testset "Required core performance evidence and combined outcomes" begin
    environment = _pilot_environment()
    family, algorithm = :figure_eight, :tsit5
    executions = Tuple(_core_fixture_execution(family, algorithm, tolerance)
        for tolerance in CORE_TOLERANCE_VALUES)
    attempts = map(_core_attempt, executions)
    suite = _core_performance_suite(family, algorithm, environment)
    @test_throws ArgumentError PerformanceSuiteReport(:duplicate, "Duplicate",
        VALIDATION_SCHEMA_VERSION, environment,
        (suite.benchmarks[1], suite.benchmarks[1], suite.benchmarks[3:5]...))
    @test_throws ArgumentError core_tolerance_investigation_series(
        PerformanceSuiteReport(:missing, "Missing", VALIDATION_SCHEMA_VERSION,
            environment, suite.benchmarks[1:4]), attempts)

    configuration = core_tolerance_configuration(family, algorithm, 1e-11)
    original = suite.benchmarks[3]
    wrong_configuration = ValidationFramework._core_validation_configuration(
        core_tolerance_configuration(family, algorithm, 1e-12))
    wrong_definition = PerformanceBenchmarkDefinition(original.definition.benchmark_id,
        "Wrong", original.definition.description, original.definition.source_path,
        original.definition.classifications, original.definition.tags,
        original.definition.definition_version, original.definition.required_measurements,
        original.definition.provenance)
    for replacement in (
        _core_performance_report(configuration, environment;
            recorded_configuration=wrong_configuration),
        _core_performance_report(configuration, environment; definition=wrong_definition),
        _core_performance_report(configuration, environment; policy=QuickBenchmark()),
    )
        overrides = Dict(1e-11 => replacement)
        @test_throws ArgumentError core_tolerance_investigation_series(
            _core_performance_suite(family, algorithm, environment; overrides), attempts)
    end
    other_environment = ValidationEnvironment(environment.schema_version,
        environment.package_version, environment.repository_commit,
        environment.repository_dirty, environment.julia_version,
        environment.operating_system, environment.architecture,
        environment.thread_count, "2099-01-01T00:00:00Z")
    @test_throws ArgumentError PerformanceSuiteReport(:bad_environment, "Bad environment",
        VALIDATION_SCHEMA_VERSION, environment,
        (suite.benchmarks[1:4]...,
         _core_performance_report(core_tolerance_configuration(family, algorithm, 1e-13), other_environment)))

    failed_performance = _core_performance_report(configuration, environment;
        execution=ExecutionOutcome(actual_errored; exit_code=1, summary="timing child failed"))
    failed_suite = _core_performance_suite(family, algorithm, environment;
        overrides=Dict(1e-11 => failed_performance))
    performance_primary = core_tolerance_investigation_series(failed_suite, attempts)
    @test performance_primary.points[3].execution.actual == actual_errored
    @test performance_primary.points[3].performance_report === failed_performance
    @test occursin("timing child failed", performance_primary.points[3].notes)

    terminated = collect(attempts)
    terminated[3] = _core_attempt(_core_fixture_execution(family, algorithm, 1e-11;
        status=:terminated_close_approach))
    direct_primary = core_tolerance_investigation_series(suite, Tuple(terminated))
    @test direct_primary.points[3].execution.actual == actual_terminated
    @test direct_primary.points[3].performance_report === suite.benchmarks[3]
end

@testset "Thrown direct attempt retains declared point" begin
    environment = _pilot_environment()
    family, algorithm = :figure_eight, :tsit5
    executions = Tuple(_core_fixture_execution(family, algorithm, tolerance)
        for tolerance in CORE_TOLERANCE_VALUES)
    attempts = collect(map(_core_attempt, executions))
    attempts[3] = attempt_core_tolerance_experiment(
        core_tolerance_configuration(family, algorithm, 1e-11);
        runner=_ -> error("synthetic integration failure"))
    failed_performance = _core_performance_report(
        core_tolerance_configuration(family, algorithm, 1e-12), environment;
        execution=ExecutionOutcome(actual_errored; exit_code=2,
            summary="synthetic performance child failure"))
    suite = _core_performance_suite(family, algorithm, environment;
        overrides=Dict(1e-12 => failed_performance))
    series = core_tolerance_investigation_series(suite, Tuple(attempts))
    @test map(point -> point.independent_value.value, series.points) == CORE_TOLERANCE_VALUES
    @test series.points[3].execution.actual == actual_errored
    @test isempty(series.points[3].metrics)
    @test isnothing(series.points[3].solver_statistics)
    @test !isnothing(series.points[3].performance_report)
    @test occursin("synthetic integration failure", series.points[3].notes)
    @test all(id -> id ∉ map(metric -> metric.metric_id, series.points[2].metrics),
        CORE_TOLERANCE_COMPARISON_METRICS)
    @test all(id -> id ∉ map(metric -> metric.metric_id, series.points[3].metrics),
        CORE_TOLERANCE_COMPARISON_METRICS)
    @test !isempty(series.points[4].metrics)
    @test series.points[4].execution.actual == actual_errored
    @test series.points[4].performance_report === failed_performance
    @test occursin("synthetic performance child failure", series.points[4].notes)
end

@testset "Precision-safe canonical figure-eight inputs" begin
    original_precision = precision(BigFloat)
    first_inputs = ValidationFramework.ThreeBody3D._figure_eight_canonical_inputs(192)
    second_inputs = ValidationFramework.ThreeBody3D._figure_eight_canonical_inputs(192)
    @test eltype(first_inputs.initial_state) == BigFloat
    @test eltype(first_inputs.system.masses) == BigFloat
    @test first_inputs.system.G isa BigFloat
    @test first_inputs.initial_time isa BigFloat
    @test first_inputs.period isa BigFloat
    @test first_inputs.tolerance isa BigFloat
    @test first_inputs.saveat isa BigFloat
    @test precision(first(first_inputs.initial_state)) == 192
    @test first_inputs.initial_state == second_inputs.initial_state
    @test first_inputs.initial_state[1] != BigFloat(Float64(-0.97000436))
    ValidationFramework.ThreeBody3D._figure_eight_canonical_inputs(256)
    @test precision(BigFloat) == original_precision
    float_system, float_state, float_period = ValidationFramework.ThreeBody3D._figure_eight_benchmark_inputs()
    @test Tuple(float_system.masses) == (1.0, 1.0, 1.0)
    @test float_state[1] == -0.97000436
    @test float_period == ValidationFramework.ThreeBody3D.FIGURE_EIGHT_PERIOD
end

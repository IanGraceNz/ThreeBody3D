function _precision_metric_copy(metric, value)
    ValidationMetric(metric.metric_id, metric.label, value; scale=metric.scale,
        role=metric.role, aggregation=metric.aggregation, units=metric.units,
        description=metric.description)
end

function _precision_source_series(p12, p13, e12, e13; missing=Symbol[],
    performance_failure=false, direct_status=nothing, missing_statistics=false,
    inconsistent_execution=false)
    environment = _pilot_environment()
    executions = Tuple(_core_fixture_execution(:figure_eight, :vern9, tolerance)
        for tolerance in CORE_TOLERANCE_VALUES)
    suite = _core_performance_suite(:figure_eight, :vern9, environment)
    series = core_tolerance_investigation_series(suite, map(_core_attempt, executions))
    points = collect(series.points)
    for (index, pvalue, evalue) in ((4, p12, e12), (5, p13, e13))
        point = points[index]
        metrics = Tuple(begin
            value = metric.metric_id == :periodicity_error ? pvalue :
                metric.metric_id == :maximum_relative_energy_drift ? evalue : metric.value
            _precision_metric_copy(metric, value)
        end for metric in point.metrics if metric.metric_id ∉ missing)
        execution = isempty(missing) ? point.execution :
            ExecutionOutcome(actual_errored; exit_code=1, summary="direct metrics unavailable")
        performance = point.performance_report
        if !isnothing(direct_status) && index == 4
            metrics = Tuple(_precision_metric_copy(metric,
                metric.metric_id == :integration_status ? direct_status : metric.value)
                for metric in metrics)
            execution = ExecutionOutcome(direct_status == :terminated_close_approach ?
                actual_terminated : actual_errored; exit_code=1,
                summary="direct execution did not complete")
        elseif performance_failure && index == 4
            failed = ExecutionOutcome(actual_errored; exit_code=1,
                summary="performance timing failed")
            performance = build_performance_benchmark_report(performance.definition,
                performance.environment, performance.configuration, performance.policy,
                (), failed)
            execution = ValidationFramework._core_combined_execution(
                ExecutionOutcome(actual_completed; exit_code=0), failed)
        end
        missing_statistics && index == 4 && (execution = ExecutionOutcome(
            actual_errored; exit_code=1, summary="direct solver statistics unavailable"))
        inconsistent_execution && index == 4 && (execution = ExecutionOutcome(
            actual_errored; exit_code=1, summary="stale direct metrics"))
        points[index] = InvestigationMeasurementPoint(point.point_id, series.definition,
            point.configuration, point.independent_value, point.environment, execution,
            metrics, missing_statistics && index == 4 ? nothing : point.solver_statistics;
            performance_report=performance,
            notes=execution.summary)
    end
    InvestigationMeasurementSeries(series.series_id, series.title, series.description,
        series.definition, Tuple(points))
end

function _precision_fixture_evidence(bits; status=:completed, changes=NamedTuple(),
    times=nothing, system=nothing, initial_state=nothing, precision_bits=bits)
    configuration = figure_eight_precision_configuration(bits)
    inputs = ValidationFramework.ThreeBody3D._figure_eight_canonical_inputs(bits)
    system = isnothing(system) ? inputs.system : system
    initial_state = isnothing(initial_state) ? inputs.initial_state : initial_state
    final_time = setprecision(BigFloat, bits) do
        inputs.initial_time + 10 * inputs.period
    end
    times = isnothing(times) ? ValidationFramework._precision_scalar_grid(
        configuration, final_time) : collect(times)
    value(text) = setprecision(BigFloat, bits) do; parse(BigFloat, text); end
    diagnostics = (maximum_relative_energy_drift=value("1e-25"),
        maximum_linear_momentum_drift=value("2e-25"),
        maximum_angular_momentum_drift=value("3e-25"),
        maximum_center_of_mass_residual=value("4e-25"),
        minimum_separation=value("0.69"))
    report = merge((name=:figure_eight, status, profile=:extreme,
        initial_time=inputs.initial_time, final_time=last(times),
        expected_final_time=final_time, diagnostics,
        periodicity_error=value("3e-7"), benchmark_metrics=NamedTuple(),
        saved_states=length(times), accepted_steps=20, rejected_steps=0,
        rhs_evaluations=320), changes)
    FigureEightPrecisionEvidence(configuration, report, times, system, initial_state,
        inputs.canonical, precision_bits)
end

function _rebuild_trigger(assessment; changes=NamedTuple())
    values = NamedTuple{fieldnames(FigureEightPrecisionTriggerAssessment)}(
        Tuple(getfield(assessment, field) for field in
            fieldnames(FigureEightPrecisionTriggerAssessment)))
    retained = merge(values, changes)
    FigureEightPrecisionTriggerAssessment((getfield(retained, field) for field in
        fieldnames(FigureEightPrecisionTriggerAssessment))...)
end

function _precision_attempt(evidence)
    completed = evidence.report.status == :completed
    outcome = ExecutionOutcome(completed ? actual_completed : actual_terminated;
        exit_code=completed ? 0 : 1,
        summary=completed ? nothing : "precision benchmark terminated")
    FigureEightPrecisionAttempt(evidence.configuration, outcome, evidence;
        notes=outcome.summary)
end

function _precision_performance_report(configuration, environment;
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    definition=figure_eight_precision_performance_definition(configuration),
    recorded_configuration=ValidationFramework._figure_eight_precision_validation_configuration(configuration),
    policy=StandardBenchmark(), measurement_bits=configuration.precision_bits,
    float_measurement=false, nonfinite=false, missing_minimum=false,
    extra_measurement=false)
    measurement = setprecision(BigFloat, measurement_bits) do
        nonfinite ? BigFloat(Inf) : parse(BigFloat, "1e-25")
    end
    measurement = float_measurement ? 1e-25 : measurement
    measurements = AbstractValidationMetric[ValidationMetric(
        :maximum_relative_energy_drift, "Maximum relative energy drift",
        measurement; role=role_performance)]
    missing_minimum || push!(measurements, ValidationMetric(:minimum_pair_separation,
        "Minimum pair separation", measurement; role=role_performance))
    extra_measurement && push!(measurements, ValidationMetric(:unexpected,
        "Unexpected", measurement; role=role_performance))
    measurements = Tuple(measurements)
    samples = execution.actual == actual_completed ? Tuple(
        PerformanceSample(index; elapsed_seconds=0.01 * index,
            solver_statistics=SolverStatistics(accepted_steps=20, rejected_steps=0,
                rhs_evaluations=320, saved_states=2), saved_states=2,
            measurements=measurements)
        for index in 1:policy.sample_runs) : ()
    build_performance_benchmark_report(definition, environment, recorded_configuration,
        policy, samples, execution)
end

function _precision_suite(environment; overrides=Dict())
    reports = Tuple(begin
        configuration = figure_eight_precision_configuration(bits)
        get(overrides, bits, _precision_performance_report(configuration, environment))
    end for bits in FIGURE_EIGHT_PRECISION_BITS)
    PerformanceSuiteReport(:precision_test, "Precision test", VALIDATION_SCHEMA_VERSION,
        environment, reports)
end

@testset "Figure-eight precision trigger mathematics and source contract" begin
    triggered = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.99, 1.0, 10.0, 1.0))
    @test triggered.status == :triggered
    @test triggered.periodicity_change_factor == 1.99
    @test triggered.energy_improvement_factor == 10.0
    @test evaluate_figure_eight_precision_trigger(
        _precision_source_series(2.0, 1.0, 10.0, 1.0)).status == :not_triggered
    @test evaluate_figure_eight_precision_trigger(
        _precision_source_series(2.01, 1.0, 10.0, 1.0)).status == :not_triggered
    @test evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 9.99, 1.0)).status == :not_triggered
    @test evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 1.0, 10.0)).status == :not_triggered
    zeros = evaluate_figure_eight_precision_trigger(
        _precision_source_series(0.0, 0.0, 0.0, 0.0))
    @test zeros.periodicity_condition === true
    @test zeros.periodicity_change_factor == 1.0
    @test zeros.energy_condition === false
    one_zero = evaluate_figure_eight_precision_trigger(
        _precision_source_series(0.0, 1.0, 1.0, 0.0))
    @test one_zero.periodicity_condition === false
    @test isnothing(one_zero.periodicity_change_factor)
    @test one_zero.energy_condition === true
    @test one_zero.energy_improvement_unbounded
    unavailable = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 10.0, 1.0;
            missing=[:periodicity_error]))
    @test unavailable.status == :unavailable
    performance_only = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 10.0, 1.0;
            performance_failure=true))
    @test performance_only.status == :triggered
    @test performance_only.point_1e12_execution.actual == actual_errored
    @test evaluate_figure_eight_precision_trigger(_precision_source_series(
        1.0, 1.0, 10.0, 1.0; direct_status=:terminated_close_approach)).status == :unavailable
    @test evaluate_figure_eight_precision_trigger(_precision_source_series(
        1.0, 1.0, 10.0, 1.0; direct_status=:errored)).status == :unavailable
    @test evaluate_figure_eight_precision_trigger(_precision_source_series(
        1.0, 1.0, 10.0, 1.0; missing=[:integration_status])).status == :unavailable
    @test evaluate_figure_eight_precision_trigger(_precision_source_series(
        1.0, 1.0, 10.0, 1.0; missing_statistics=true)).status == :unavailable
    @test evaluate_figure_eight_precision_trigger(_precision_source_series(
        1.0, 1.0, 10.0, 1.0; inconsistent_execution=true)).status == :unavailable
    wrong = _precision_source_series(1.0, 1.0, 10.0, 1.0)
    @test_throws ArgumentError evaluate_figure_eight_precision_trigger(
        InvestigationMeasurementSeries(:wrong, wrong.title, wrong.description,
            wrong.definition, wrong.points))
    shuffled_points = collect(wrong.points)
    point = shuffled_points[4]
    shuffled_points[4] = InvestigationMeasurementPoint(point.point_id,
        wrong.definition, point.configuration, point.independent_value,
        point.environment, point.execution, reverse(point.metrics),
        point.solver_statistics; performance_report=point.performance_report,
        notes=point.notes)
    @test evaluate_figure_eight_precision_trigger(InvestigationMeasurementSeries(
        wrong.series_id, wrong.title, wrong.description, wrong.definition,
        Tuple(shuffled_points))).status == :triggered
    swapped = copy(shuffled_points)
    swapped[4], swapped[5] = swapped[5], swapped[4]
    @test_throws ArgumentError evaluate_figure_eight_precision_trigger(
        InvestigationMeasurementSeries(wrong.series_id, wrong.title,
            wrong.description, wrong.definition, Tuple(swapped)))
end

@testset "Canonical precision package path boundaries" begin
    package = ValidationFramework.ThreeBody3D
    fixture = _precision_fixture_evidence(128)
    inputs = package._figure_eight_canonical_inputs(128)
    fake_result = (; marker=:solver_owned)
    calculator_calls = Ref(0)
    package_report = package.ValidationBenchmarkReport(fixture.report.name,
        fixture.report.status, fixture.report.profile, fixture.report.initial_time,
        fixture.report.final_time, fixture.report.expected_final_time,
        fixture.report.diagnostics, fixture.report.periodicity_error,
        fixture.report.benchmark_metrics, fixture.report.saved_states,
        fixture.report.accepted_steps, fixture.report.rejected_steps,
        fixture.report.rhs_evaluations)
    calculator = bits -> begin
        calculator_calls[] += 1
        @test bits == 128
        (; report=package_report, result=fake_result, inputs)
    end
    report = package._run_figure_eight_precision_benchmark(128; calculator)
    @test report isa package.ValidationBenchmarkReport
    @test calculator_calls[] == 1
    observer_calls = Ref(0)
    observer = function (retained_report, result, retained_inputs)
        observer_calls[] += 1
        @test result === fake_result
        package.FigureEightPrecisionObservation(retained_report, fixture.times,
            fixture.system, fixture.initial_state, retained_inputs.canonical, 128)
    end
    observation = package._run_figure_eight_precision_benchmark_observation(128;
        calculator, observer)
    @test observation isa package.FigureEightPrecisionObservation
    @test observer_calls[] == 1
    @test !hasproperty(observation, :states)
    @test observation.times === fixture.times
    ordinary = package._run_figure_eight_benchmark(1, :fast, 1.0)
    @test ordinary isa package.ValidationBenchmarkReport
    @test ordinary.profile == :fast
end

@testset "Precision trigger deterministic serialization" begin
    assessment = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 10.0, 0.0))
    first_text = figure_eight_precision_trigger_text(assessment)
    @test first_text == figure_eight_precision_trigger_text(assessment)
    @test !occursin("Inf", first_text)
    @test !occursin("NaN", first_text)
    restored = read_figure_eight_precision_trigger(IOBuffer(first_text))
    @test ValidationFramework._record_fields_equal(restored, assessment)
    not_triggered = evaluate_figure_eight_precision_trigger(
        _precision_source_series(2.0, 1.0, 10.0, 1.0))
    unavailable = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 10.0, 1.0;
            missing=[:periodicity_error]))
    for retained in (assessment, not_triggered, unavailable)
        round_trip = read_figure_eight_precision_trigger(IOBuffer(
            figure_eight_precision_trigger_text(retained)))
        @test ValidationFramework._record_fields_equal(round_trip, retained)
    end
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(point_1e12_id=:wrong,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(periodicity_change_factor=1.5,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(periodicity_condition=false,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(energy_improvement_factor=9.0,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(energy_condition=false,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(energy_improvement_unbounded=false,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(status=:not_triggered,))
    @test_throws ArgumentError _rebuild_trigger(not_triggered;
        changes=(status=:triggered,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(periodicity_error_1e12=nothing,))
    @test_throws ArgumentError _rebuild_trigger(assessment;
        changes=(periodicity_condition=nothing,))
    malformed_text = replace(first_text, "status = \"triggered\"" =>
        "status = \"not_triggered\"")
    @test_throws ArgumentError read_figure_eight_precision_trigger(
        IOBuffer(malformed_text))
    mktempdir() do directory
        path = joinpath(directory, "trigger.toml")
        @test write_figure_eight_precision_trigger_atomic(path, assessment) == abspath(path)
        @test ValidationFramework._record_fields_equal(
            read_figure_eight_precision_trigger(path), assessment)
    end
end

@testset "Figure-eight precision configurations and definition" begin
    original = precision(BigFloat)
    configurations = map(figure_eight_precision_configuration,
        FIGURE_EIGHT_PRECISION_BITS)
    @test precision(BigFloat) == original
    @test map(configuration -> configuration.precision_bits, configurations) ==
        FIGURE_EIGHT_PRECISION_BITS
    for configuration in configurations
        @test configuration.algorithm_id == :vern9
        @test configuration.solver_selector == :extreme
        @test precision(configuration.relative_tolerance) == configuration.precision_bits
        @test precision(configuration.saveat) == configuration.precision_bits
        @test configuration.canonical ==
            ValidationFramework.ThreeBody3D._FIGURE_EIGHT_CANONICAL_DECIMALS
    end
    @test_throws ArgumentError figure_eight_precision_configuration(192)
    c = configurations[1]
    @test_throws ArgumentError FigureEightPrecisionConfiguration(:figure_eight, :vern9,
        :extreme, 128, 1e-30, 1e-30, 10, 0.02, :BigFloat, c.canonical)
    definition = figure_eight_precision_investigation_definition()
    @test definition.family_id == :figure_eight_precision_confirmation
    @test definition.independent_variable == :precision_bits
    @test isempty(definition.optional_metric_ids)
    @test definition.benchmark == investigation_2_figure_eight_case_definition()
    @test core_tolerance_investigation_definition(:figure_eight, :vern9).family_id ==
        :figure_eight_vern9_tolerance
    @test core_duration_sampling_investigation_definition(:duration,
        :figure_eight).family_id == :figure_eight_duration
end

@testset "Precision evidence validation and attempts" begin
    evidence = _precision_fixture_evidence(128)
    @test ValidationFramework._validate_figure_eight_precision_evidence(evidence) === evidence
    terminated = _precision_fixture_evidence(128; status=:terminated_close_approach)
    @test _precision_attempt(evidence).execution.actual == actual_completed
    @test _precision_attempt(terminated).execution.actual == actual_terminated
    bad = copy(evidence.times); deleteat!(bad, 3)
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; times=bad))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; changes=(profile=:accurate,)))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; changes=(name=:hierarchical_triple,)))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; changes=(status=:unsupported,)))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; changes=(saved_states=1,)))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; changes=(periodicity_error=BigFloat(Inf),)))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; precision_bits=256))
    package = ValidationFramework.ThreeBody3D
    retained = package.FigureEightPrecisionObservation(evidence.report, evidence.times,
        evidence.system, evidence.initial_state, evidence.canonical, 256)
    retained_evidence = run_figure_eight_precision_observation(evidence.configuration;
        runner=_ -> retained)
    @test retained_evidence.precision_bits == 256
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        retained_evidence)
    wrong_precision_times = setprecision(BigFloat, 256) do
        BigFloat.(evidence.times)
    end
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; times=wrong_precision_times))
    malformed = merge(evidence.report.diagnostics,
        (maximum_relative_energy_drift=BigFloat(Inf),))
    @test_throws ArgumentError ValidationFramework._validate_figure_eight_precision_evidence(
        _precision_fixture_evidence(128; changes=(; diagnostics=malformed)))
    configuration = evidence.configuration
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0))
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_stopped; exit_code=1))
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="terminated"), evidence)
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0, summary="unexpected"), evidence)
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_completed; exit_code=0), terminated)
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1), terminated)
    @test_throws ArgumentError FigureEightPrecisionAttempt(configuration,
        ExecutionOutcome(actual_terminated; exit_code=1, summary="   "), terminated)
    errored = attempt_figure_eight_precision(configuration;
        runner=_ -> error("synthetic precision error"))
    @test errored.execution.actual == actual_errored
    @test isnothing(errored.evidence)
    @test occursin("synthetic precision error", errored.execution.summary)
end

@testset "Precision performance and series serialization" begin
    environment = _pilot_environment()
    assessment = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 10.0, 1.0))
    configurations = map(figure_eight_precision_configuration,
        FIGURE_EIGHT_PRECISION_BITS)
    attempts = map(bits -> _precision_attempt(_precision_fixture_evidence(bits)),
        FIGURE_EIGHT_PRECISION_BITS)
    suite = _precision_suite(environment)
    @test map(figure_eight_precision_performance_id, configurations) ==
        (:figure_eight_precision_128, :figure_eight_precision_256,
         :figure_eight_precision_384)
    @test map(id -> decode_figure_eight_precision_id(id),
        map(figure_eight_precision_performance_id, configurations)) == configurations
    captured = Ref{Any}()
    operation = figure_eight_precision_performance_operation(configurations[1];
        runner=bits -> begin; captured[] = bits; _precision_fixture_evidence(bits).report; end)
    operation()
    @test captured[] == 128
    @test_throws ArgumentError figure_eight_precision_investigation_series(assessment,
        PerformanceSuiteReport(:missing, "Missing", VALIDATION_SCHEMA_VERSION,
            environment, suite.benchmarks[1:2]), attempts)
    extra = _core_performance_report(
        core_tolerance_configuration(:figure_eight, :vern9, 1e-9), environment)
    @test_throws ArgumentError figure_eight_precision_investigation_series(assessment,
        PerformanceSuiteReport(:extra, "Extra", VALIDATION_SCHEMA_VERSION,
            environment, (suite.benchmarks..., extra)), attempts)
    wrong_definition = _definition_with_version(suite.benchmarks[1].definition, "9.9.9")
    wrong_report = _precision_performance_report(configurations[1], environment;
        definition=wrong_definition)
    @test_throws ArgumentError figure_eight_precision_investigation_series(assessment,
        _precision_suite(environment; overrides=Dict(128 => wrong_report)), attempts)
    wrong_configuration = ValidationFramework._figure_eight_precision_validation_configuration(
        configurations[2])
    wrong_report = _precision_performance_report(configurations[1], environment;
        recorded_configuration=wrong_configuration)
    @test_throws ArgumentError figure_eight_precision_investigation_series(assessment,
        _precision_suite(environment; overrides=Dict(128 => wrong_report)), attempts)
    wrong_report = _precision_performance_report(configurations[1], environment;
        policy=QuickBenchmark())
    @test_throws ArgumentError figure_eight_precision_investigation_series(assessment,
        _precision_suite(environment; overrides=Dict(128 => wrong_report)), attempts)
    for malformed_report in (
        _precision_performance_report(configurations[1], environment;
            float_measurement=true),
        _precision_performance_report(configurations[1], environment;
            measurement_bits=256),
        _precision_performance_report(configurations[1], environment;
            nonfinite=true),
        _precision_performance_report(configurations[1], environment;
            missing_minimum=true),
        _precision_performance_report(configurations[1], environment;
            extra_measurement=true))
        @test_throws ArgumentError figure_eight_precision_investigation_series(
            assessment, _precision_suite(environment;
                overrides=Dict(128 => malformed_report)), attempts)
    end
    duplicate_measurement = setprecision(BigFloat, 128) do
        ValidationMetric(:maximum_relative_energy_drift, "Energy", BigFloat("1e-25");
            role=role_performance)
    end
    @test_throws ArgumentError PerformanceSample(1; measurements=(
        duplicate_measurement, duplicate_measurement))
    series = figure_eight_precision_investigation_series(assessment, suite, attempts)
    @test series.series_id == :figure_eight_precision_confirmation
    @test map(point -> point.independent_value.value, series.points) ==
        FIGURE_EIGHT_PRECISION_BITS
    @test all(point -> isnothing(point.supporting_evidence), series.points)
    failed_attempts = collect(attempts)
    failed_attempts[2] = FigureEightPrecisionAttempt(configurations[2],
        ExecutionOutcome(actual_errored; exit_code=1,
            summary="middle precision integration failed"))
    failed_series = figure_eight_precision_investigation_series(assessment, suite,
        Tuple(failed_attempts))
    @test map(point -> point.independent_value.value, failed_series.points) ==
        FIGURE_EIGHT_PRECISION_BITS
    @test failed_series.points[2].execution.actual == actual_errored
    @test isempty(failed_series.points[2].metrics)
    @test isnothing(failed_series.points[2].solver_statistics)
    @test !isempty(failed_series.points[3].metrics)
    text = investigation_series_report_text(series)
    @test !occursin("saved physical times", lowercase(text))
    @test text == investigation_series_report_text(series)
    restored = read_investigation_series(IOBuffer(text))
    @test investigation_series_report_text(restored) == text
    @test ValidationFramework._record_fields_equal(restored.definition, series.definition)
    for (left, right) in zip(restored.points, series.points)
        @test left.point_id == right.point_id
        @test ValidationFramework._record_fields_equal(left.configuration, right.configuration)
        @test length(left.metrics) == length(right.metrics)
        @test all(ValidationFramework._record_fields_equal(l, r)
            for (l, r) in zip(left.metrics, right.metrics))
        @test left.solver_statistics == right.solver_statistics
        @test performance_benchmark_text(left.performance_report) ==
            performance_benchmark_text(right.performance_report)
        @test precision(left.configuration.relative_tolerance) ==
            left.independent_value.value
        @test precision(left.configuration.absolute_tolerance) ==
            left.independent_value.value
        for metric in left.metrics
            metric.value isa BigFloat && @test precision(metric.value) ==
                left.independent_value.value
        end
        @test all(sample -> all(metric -> metric.value isa BigFloat &&
            precision(metric.value) == left.independent_value.value,
            sample.measurements), left.performance_report.samples)
    end
    not_triggered = evaluate_figure_eight_precision_trigger(
        _precision_source_series(2.0, 1.0, 10.0, 1.0))
    unavailable = evaluate_figure_eight_precision_trigger(
        _precision_source_series(1.0, 1.0, 10.0, 1.0;
            missing=[:periodicity_error]))
    @test_throws ArgumentError figure_eight_precision_investigation_series(
        not_triggered, suite, attempts)
    @test_throws ArgumentError figure_eight_precision_investigation_series(
        unavailable, suite, attempts)
end

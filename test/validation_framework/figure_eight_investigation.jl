function _figure_eight_investigation_metrics(profile::Symbol)
    scale = profile == :fast ? 1.0 : 0.1
    (
        ValidationMetric(:periodicity_error, "Periodicity error", scale * 1.0e-6),
        ValidationMetric(
            :maximum_relative_energy_drift,
            "Maximum relative energy drift",
            scale * 1.0e-10,
        ),
        ValidationMetric(
            :maximum_linear_momentum_drift,
            "Maximum linear-momentum drift",
            scale * 2.0e-12,
        ),
        ValidationMetric(
            :maximum_angular_momentum_drift,
            "Maximum angular-momentum drift",
            scale * 3.0e-11,
        ),
        ValidationMetric(
            :maximum_center_of_mass_residual,
            "Maximum centre-of-mass residual",
            scale * 4.0e-12,
        ),
        ValidationMetric(:minimum_pair_separation, "Minimum pair separation", 0.69),
    )
end

function _figure_eight_case_result(
    profile::Symbol;
    environment=performance_test_environment(),
    definition=figure_eight_case_definition(),
    configuration=ValidationConfiguration(
        solver=profile,
        time_interval=figure_eight_performance_configuration(solver=profile).time_interval,
        sampling="saveat=0.02",
        parameters=(ValidationParameter(:periods, 10),),
    ),
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    metrics=_figure_eight_investigation_metrics(profile),
)
    ValidationCaseResult(
        definition,
        environment,
        configuration,
        metrics,
        (),
        SolverStatistics(
            accepted_steps=profile == :fast ? 100 : 200,
            rejected_steps=profile == :fast ? 2 : 1,
            rhs_evaluations=profile == :fast ? 800 : 1600,
            saved_states=315,
        ),
        execution,
    )
end

function _figure_eight_performance_report(
    profile::Symbol;
    environment=performance_test_environment(),
    definition=figure_eight_accuracy_work_definition(profile),
    configuration=figure_eight_performance_configuration(solver=profile),
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    retained_samples=execution.actual == actual_completed ? 3 : 1,
)
    samples = Tuple(
        PerformanceSample(
            index;
            elapsed_seconds=(profile == :fast ? 0.4 : 0.9) + index / 10,
            solver_statistics=SolverStatistics(
                accepted_steps=profile == :fast ? 100 : 200,
                rejected_steps=profile == :fast ? 2 : 1,
                rhs_evaluations=profile == :fast ? 800 : 1600,
                saved_states=315,
            ),
            saved_states=315,
            measurements=(
                ValidationMetric(
                    :maximum_relative_energy_drift,
                    "Maximum relative energy drift",
                    (profile == :fast ? 1.0e-8 : 1.0e-12) * (1 + index * eps());
                    role=role_descriptive,
                ),
                ValidationMetric(
                    :minimum_pair_separation,
                    "Minimum pair separation",
                    0.69 + index * eps();
                    role=role_descriptive,
                ),
            ),
        ) for index in 1:retained_samples
    )
    build_performance_benchmark_report(
        definition,
        environment,
        configuration,
        QuickBenchmark(),
        samples,
        execution,
    )
end

function _figure_eight_investigation_inputs(;
    fast_result_kwargs=NamedTuple(),
    accurate_result_kwargs=NamedTuple(),
    fast_report_kwargs=NamedTuple(),
    accurate_report_kwargs=NamedTuple(),
)
    environment = performance_test_environment()
    results = (
        _figure_eight_case_result(:accurate; environment, accurate_result_kwargs...),
        _figure_eight_case_result(:fast; environment, fast_result_kwargs...),
    )
    suite = PerformanceSuiteReport(
        :figure_eight_investigation_test,
        "Figure-eight investigation test",
        VALIDATION_SCHEMA_VERSION,
        environment,
        (
            _figure_eight_performance_report(
                :accurate; environment, accurate_report_kwargs...,
            ),
            _figure_eight_performance_report(:fast; environment, fast_report_kwargs...),
        ),
    )
    suite, results
end

function _definition_with_version(definition::PerformanceBenchmarkDefinition, version)
    PerformanceBenchmarkDefinition(
        definition.benchmark_id,
        definition.title,
        definition.description,
        definition.source_path,
        definition.classifications,
        definition.tags,
        version,
        definition.required_measurements,
        definition.provenance,
    )
end

function _case_definition_with_version(definition::ValidationCaseDefinition, version)
    ValidationCaseDefinition(
        definition.case_id,
        definition.title,
        definition.description,
        definition.classifications,
        definition.tags,
        definition.source_path,
        definition.tiers,
        definition.expected_outcome,
        definition.required,
        version,
        definition.provenance,
    )
end

@testset "Figure-eight Investigation 1 definition" begin
    definition = figure_eight_profile_investigation_definition()

    @test definition.family_id == :figure_eight_profile
    @test ValidationFramework._record_fields_equal(
        definition.benchmark,
        figure_eight_case_definition(),
    )
    @test definition.independent_variable == :solver_profile
    @test map(control -> control.parameter_id, definition.fixed_controls) ==
          (:periods, :saveat)
    @test map(control -> control.value, definition.fixed_controls) == (10, 0.02)
    @test definition.required_metric_ids == FIGURE_EIGHT_INVESTIGATION_METRICS
    @test definition.optional_metric_ids == ()
end

@testset "Figure-eight Investigation 1 complete ordered series" begin
    suite, results = _figure_eight_investigation_inputs()
    series = figure_eight_profile_investigation_series(suite, results)

    @test map(point -> point.point_id, series.points) == (:fast, :accurate)
    @test map(point -> point.independent_value.value, series.points) == (:fast, :accurate)
    @test map(point -> point.configuration.solver, series.points) == (:fast, :accurate)
    @test all(point -> point.environment === suite.environment, series.points)
    @test all(
        point -> map(metric -> metric.metric_id, point.metrics) ==
                 FIGURE_EIGHT_INVESTIGATION_METRICS,
        series.points,
    )
    @test map(point -> point.solver_statistics.rhs_evaluations, series.points) ==
          (800, 1600)
    @test map(point -> length(point.performance_report.samples), series.points) == (3, 3)
    @test map(
        point -> map(sample -> sample.elapsed_seconds, point.performance_report.samples),
        series.points,
    ) == ((0.5, 0.6000000000000001, 0.7), (1.0, 1.1, 1.2))
    @test map(point -> point.performance_report.summary.sample_count, series.points) == (3, 3)
    @test all(
        isapprox(value, expected) for (value, expected) in zip(
            map(point -> point.performance_report.summary.elapsed_median, series.points),
            (0.6, 1.1),
        )
    )
    @test map(
        point -> point.performance_report.execution.exit_code,
        series.points,
    ) == (0, 0)
end

@testset "Figure-eight Investigation 1 fixed-control checks" begin
    suite, results = _figure_eight_investigation_inputs()
    fast = first(filter(result -> result.configuration.solver == :fast, results))

    wrong_periods = ValidationConfiguration(
        solver=:fast,
        time_interval=fast.configuration.time_interval,
        sampling=fast.configuration.sampling,
        parameters=(ValidationParameter(:periods, 9),),
    )
    @test_throws ArgumentError figure_eight_profile_investigation_series(
        suite,
        (results[1], _figure_eight_case_result(
            :fast; environment=suite.environment, configuration=wrong_periods,
        )),
    )

    for configuration in (
        figure_eight_performance_configuration(periods=9, solver=:fast),
        figure_eight_performance_configuration(periods=10, solver=:fast, saveat=0.1),
        ValidationConfiguration(
            solver=:fast,
            time_interval=(0.0, 1.0),
            sampling="saveat=0.02",
            parameters=(
                ValidationParameter(:periods, 10),
                ValidationParameter(:saveat, 0.02),
            ),
        ),
        figure_eight_performance_configuration(solver=:accurate),
    )
        mismatched, matched_results = _figure_eight_investigation_inputs(
            fast_report_kwargs=(; configuration),
        )
        @test_throws ArgumentError figure_eight_profile_investigation_series(
            mismatched,
            matched_results,
        )
    end
end

@testset "Figure-eight Investigation 1 benchmark identity" begin
    performance_definition = _definition_with_version(
        figure_eight_accuracy_work_definition(:fast),
        "2.0.0",
    )
    suite, results = _figure_eight_investigation_inputs(
        fast_report_kwargs=(; definition=performance_definition),
    )
    @test_throws ArgumentError figure_eight_profile_investigation_series(suite, results)

    case_definition = _case_definition_with_version(figure_eight_case_definition(), "2.0.0")
    suite, results = _figure_eight_investigation_inputs(
        fast_result_kwargs=(; definition=case_definition),
    )
    @test_throws ArgumentError figure_eight_profile_investigation_series(suite, results)
end

@testset "Figure-eight Investigation 1 unsuccessful evidence" begin
    case_execution = ExecutionOutcome(
        actual_terminated;
        exit_code=1,
        summary="Core benchmark stopped after retaining diagnostics.",
    )
    performance_execution = ExecutionOutcome(
        actual_errored;
        exit_code=1,
        summary="Timing protocol stopped after one sample.",
    )
    suite, results = _figure_eight_investigation_inputs(
        accurate_result_kwargs=(;
            execution=case_execution,
            metrics=_figure_eight_investigation_metrics(:accurate)[1:3],
        ),
        accurate_report_kwargs=(;
            execution=performance_execution,
            retained_samples=1,
        ),
    )
    series = figure_eight_profile_investigation_series(suite, results)
    unsuccessful = series.points[2]

    @test unsuccessful.execution.actual == actual_terminated
    @test results[1].execution.actual == actual_terminated
    @test unsuccessful.performance_report.execution.actual == actual_errored
    @test unsuccessful.performance_report.execution.exit_code == 1
    @test map(metric -> metric.metric_id, unsuccessful.metrics) ==
          FIGURE_EIGHT_INVESTIGATION_METRICS[1:3]
    @test unsuccessful.solver_statistics.rhs_evaluations == 1600
    @test length(unsuccessful.performance_report.samples) == 1
    @test unsuccessful.performance_report.samples[1].elapsed_seconds == 1.0
    @test unsuccessful.performance_report.summary.sample_count == 1
    @test unsuccessful.performance_report.summary.elapsed_median == 1.0
    @test occursin("Core benchmark stopped", unsuccessful.notes)
    @test occursin("Timing protocol stopped", unsuccessful.notes)
end

@testset "Figure-eight Investigation 1 duplicate performance reports" begin
    report = _figure_eight_performance_report(:fast)
    @test_throws ArgumentError ValidationFramework._figure_eight_reports_by_id(
        (report, report),
    )
end

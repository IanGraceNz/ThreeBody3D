function _hierarchical_investigation_metrics(profile::Symbol)
    scale = profile == :fast ? 1.0 : 0.1
    (
        ValidationMetric(:minimum_hierarchy_ratio, "Minimum hierarchy ratio", 12.0),
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
        ValidationMetric(:minimum_pair_separation, "Minimum pair separation", 0.8),
    )
end

function _hierarchical_case_configuration(profile::Symbol; duration=100.0, extra_parameters=())
    tolerances = ValidationFramework._hierarchical_triple_profile_tolerances(profile)
    ValidationConfiguration(
        solver=profile,
        absolute_tolerance=tolerances.abstol,
        relative_tolerance=tolerances.reltol,
        time_interval=(0.0, duration),
        sampling="saveat=0.02",
        parameters=(
            ValidationParameter(:duration, duration),
            extra_parameters...,
        ),
    )
end

function _hierarchical_case_result(
    profile::Symbol;
    environment=performance_test_environment(),
    definition=hierarchical_triple_case_definition(),
    configuration=_hierarchical_case_configuration(profile),
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    metrics=_hierarchical_investigation_metrics(profile),
)
    ValidationCaseResult(
        definition,
        environment,
        configuration,
        metrics,
        (),
        SolverStatistics(
            accepted_steps=profile == :fast ? 300 : 500,
            rejected_steps=profile == :fast ? 4 : 2,
            rhs_evaluations=profile == :fast ? 2400 : 4000,
            saved_states=5001,
        ),
        execution,
    )
end

function _hierarchical_performance_configuration(profile::Symbol; duration=100.0, saveat=0.02)
    tolerances = ValidationFramework._hierarchical_triple_profile_tolerances(profile)
    hierarchical_triple_performance_configuration(;
        duration=duration,
        solver=profile,
        saveat=saveat,
        tolerances...,
    )
end

function _hierarchical_performance_report(
    profile::Symbol;
    environment=performance_test_environment(),
    definition=hierarchical_triple_accuracy_work_definition(profile),
    configuration=_hierarchical_performance_configuration(profile),
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    retained_samples=execution.actual == actual_completed ? 3 : 1,
)
    samples = Tuple(
        PerformanceSample(
            index;
            elapsed_seconds=(profile == :fast ? 0.7 : 1.7) + index / 10,
            solver_statistics=SolverStatistics(
                accepted_steps=profile == :fast ? 300 : 500,
                rejected_steps=profile == :fast ? 4 : 2,
                rhs_evaluations=profile == :fast ? 2400 : 4000,
                saved_states=5001,
            ),
            saved_states=5001,
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
                    0.8 + index * eps();
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

function _hierarchical_investigation_inputs(;
    fast_result_kwargs=NamedTuple(),
    accurate_result_kwargs=NamedTuple(),
    fast_report_kwargs=NamedTuple(),
    accurate_report_kwargs=NamedTuple(),
)
    environment = performance_test_environment()
    results = (
        _hierarchical_case_result(:accurate; environment, accurate_result_kwargs...),
        _hierarchical_case_result(:fast; environment, fast_result_kwargs...),
    )
    suite = PerformanceSuiteReport(
        :hierarchical_investigation_test,
        "Hierarchical investigation test",
        VALIDATION_SCHEMA_VERSION,
        environment,
        (
            _hierarchical_performance_report(
                :accurate; environment, accurate_report_kwargs...,
            ),
            _hierarchical_performance_report(:fast; environment, fast_report_kwargs...),
        ),
    )
    suite, results
end

@testset "Hierarchical-triple Investigation 1 definition" begin
    definition = hierarchical_triple_profile_investigation_definition()

    @test definition.family_id == :hierarchical_triple_profile
    @test ValidationFramework._record_fields_equal(
        definition.benchmark,
        hierarchical_triple_case_definition(),
    )
    @test definition.independent_variable == :solver_profile
    @test map(control -> control.parameter_id, definition.fixed_controls) ==
          (:duration, :saveat)
    @test map(control -> control.value, definition.fixed_controls) == (100.0, 0.02)
    @test definition.required_metric_ids == HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS
end

@testset "Hierarchical-triple Investigation 1 complete ordered series" begin
    suite, results = _hierarchical_investigation_inputs()
    series = hierarchical_triple_profile_investigation_series(suite, results)

    @test map(point -> point.point_id, series.points) == (:fast, :accurate)
    @test map(point -> point.independent_value.value, series.points) == (:fast, :accurate)
    @test map(point -> point.configuration.solver, series.points) == (:fast, :accurate)
    @test map(point -> point.configuration.relative_tolerance, series.points) ==
          (nothing, 1e-13)
    @test map(point -> point.configuration.absolute_tolerance, series.points) ==
          (nothing, 1e-13)
    @test all(point -> point.environment === suite.environment, series.points)
    @test all(
        point -> map(metric -> metric.metric_id, point.metrics) ==
                 HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS,
        series.points,
    )
    @test map(point -> point.solver_statistics.rhs_evaluations, series.points) ==
          (2400, 4000)
    @test map(point -> length(point.performance_report.samples), series.points) == (3, 3)
    @test map(
        point -> point.performance_report.summary.sample_count,
        series.points,
    ) == (3, 3)
    @test map(
        point -> point.performance_report.definition.provenance,
        series.points,
    ) == ("V0_5_PERFORMANCE_BENCHMARK_DESIGN.md", "V0_5_PERFORMANCE_BENCHMARK_DESIGN.md")
    @test all(
        point -> point.performance_report.environment === suite.environment,
        series.points,
    )
    @test map(
        point -> map(sample -> sample.elapsed_seconds, point.performance_report.samples),
        series.points,
    ) == ((0.7999999999999999, 0.8999999999999999, 1.0), (1.8, 1.9, 2.0))
end

@testset "Hierarchical-triple Investigation 1 profile tolerances" begin
    suite, results = _hierarchical_investigation_inputs()
    series = hierarchical_triple_profile_investigation_series(suite, results)
    @test series.points[1].configuration.relative_tolerance === nothing
    @test series.points[1].configuration.absolute_tolerance === nothing
    @test series.points[2].configuration.relative_tolerance == 1e-13
    @test series.points[2].configuration.absolute_tolerance == 1e-13

    fast_explicit = ValidationConfiguration(
        solver=:fast,
        absolute_tolerance=1e-13,
        relative_tolerance=1e-13,
        time_interval=(0.0, 100.0),
        sampling="saveat=0.02",
        parameters=(ValidationParameter(:duration, 100.0),),
    )
    suite, results = _hierarchical_investigation_inputs(
        fast_result_kwargs=(; configuration=fast_explicit),
    )
    @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
        suite,
        results,
    )

    accurate_defaults = ValidationConfiguration(
        solver=:accurate,
        absolute_tolerance=nothing,
        relative_tolerance=nothing,
        time_interval=(0.0, 100.0),
        sampling="saveat=0.02",
        parameters=(ValidationParameter(:duration, 100.0),),
    )
    suite, results = _hierarchical_investigation_inputs(
        accurate_result_kwargs=(; configuration=accurate_defaults),
    )
    @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
        suite,
        results,
    )
end

@testset "Hierarchical-triple Investigation 1 fixed controls" begin
    for configuration in (
        _hierarchical_performance_configuration(:fast; duration=99.0),
        _hierarchical_performance_configuration(:fast; saveat=0.1),
        hierarchical_triple_performance_configuration(
            duration=100.0,
            solver=:fast,
            saveat=0.02,
            reltol=1e-13,
            abstol=1e-13,
        ),
        _hierarchical_performance_configuration(:accurate),
    )
        suite, results = _hierarchical_investigation_inputs(
            fast_report_kwargs=(; configuration),
        )
        @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
            suite,
            results,
        )
    end

    for configuration in (
        _hierarchical_case_configuration(:fast; duration=99.0),
        _hierarchical_case_configuration(
            :fast;
            extra_parameters=(ValidationParameter(:outer_eccentricity, 0.2),),
        ),
        ValidationConfiguration(
            solver=:fast,
            absolute_tolerance=1e-12,
            relative_tolerance=1e-12,
            time_interval=(0.0, 100.0),
            sampling="saveat=0.02",
            parameters=(ValidationParameter(:duration, 100.0),),
        ),
    )
        suite, results = _hierarchical_investigation_inputs(
            fast_result_kwargs=(; configuration),
        )
        @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
            suite,
            results,
        )
    end
end

@testset "Hierarchical-triple Investigation 1 benchmark identity" begin
    performance_definition = _definition_with_version(
        hierarchical_triple_accuracy_work_definition(:fast),
        "2.0.0",
    )
    suite, results = _hierarchical_investigation_inputs(
        fast_report_kwargs=(; definition=performance_definition),
    )
    @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
        suite,
        results,
    )

    case_definition = _case_definition_with_version(
        hierarchical_triple_case_definition(),
        "2.0.0",
    )
    suite, results = _hierarchical_investigation_inputs(
        fast_result_kwargs=(; definition=case_definition),
    )
    @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
        suite,
        results,
    )
end

@testset "Hierarchical-triple Investigation 1 duplicate inputs" begin
    suite, results = _hierarchical_investigation_inputs()
    report = first(suite.benchmarks)
    @test_throws ArgumentError ValidationFramework._performance_reports_by_id(
        (report, report),
    )
    @test_throws ArgumentError hierarchical_triple_profile_investigation_series(
        suite,
        (results[1], results[1]),
    )
end

@testset "Hierarchical-triple Investigation 1 unsuccessful evidence" begin
    core_execution = ExecutionOutcome(
        actual_terminated;
        exit_code=2,
        summary="Core hierarchy run retained partial diagnostics.",
    )
    performance_execution = ExecutionOutcome(
        actual_errored;
        exit_code=3,
        summary="Performance run retained one timing sample.",
    )
    suite, results = _hierarchical_investigation_inputs(
        accurate_result_kwargs=(;
            execution=core_execution,
            metrics=_hierarchical_investigation_metrics(:accurate)[1:3],
        ),
        accurate_report_kwargs=(;
            execution=performance_execution,
            retained_samples=1,
        ),
    )
    series = hierarchical_triple_profile_investigation_series(suite, results)
    unsuccessful = series.points[2]

    @test unsuccessful.execution.actual == actual_terminated
    @test results[1].execution.exit_code == 2
    @test unsuccessful.performance_report.execution.actual == actual_errored
    @test unsuccessful.performance_report.execution.exit_code == 3
    @test map(metric -> metric.metric_id, unsuccessful.metrics) ==
          HIERARCHICAL_TRIPLE_INVESTIGATION_METRICS[1:3]
    @test unsuccessful.solver_statistics.rhs_evaluations == 4000
    @test length(unsuccessful.performance_report.samples) == 1
    @test unsuccessful.performance_report.summary.sample_count == 1
    @test occursin("partial diagnostics", unsuccessful.notes)
    @test occursin("one timing sample", unsuccessful.notes)
end

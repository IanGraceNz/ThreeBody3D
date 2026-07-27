function accuracy_work_test_definition(benchmark_id)
    PerformanceBenchmarkDefinition(
        benchmark_id,
        "Accuracy-work point",
        "Synthetic accuracy-versus-work point.",
        "examples/validation/performance/accuracy_work.jl",
        (:accuracy_work,),
        (:performance,),
        "1.0.0",
        (:elapsed_time, :solver_statistics, :saved_states, :energy_drift),
    )
end

function accuracy_work_test_report(benchmark_id, solver, elapsed, drift)
    samples = Tuple(
        PerformanceSample(
            index;
            elapsed_seconds=elapsed[index],
            solver_statistics=SolverStatistics(
                accepted_steps=10 * index,
                rejected_steps=index - 1,
                rhs_evaluations=100 * index,
                saved_states=20,
            ),
            saved_states=20,
            measurements=(ValidationMetric(
                :energy_drift,
                "Energy drift",
                drift[index];
                scale=scale_relative,
                role=role_descriptive,
                aggregation=aggregation_maximum,
            ),),
        ) for index in eachindex(elapsed)
    )
    build_performance_benchmark_report(
        accuracy_work_test_definition(benchmark_id),
        performance_test_environment(),
        ValidationConfiguration(solver=solver, time_interval=(0.0, 1.0)),
        QuickBenchmark(),
        samples,
        ExecutionOutcome(actual_completed; exit_code=0),
    )
end

@testset "Accuracy-versus-work series records" begin
    fast = accuracy_work_test_report(
        :figure_eight_accuracy_work_fast,
        :fast,
        (0.8, 0.9, 1.0),
        (3e-8, 2e-8, 4e-8),
    )
    accurate = accuracy_work_test_report(
        :figure_eight_accuracy_work_accurate,
        :accurate,
        (1.8, 1.9, 2.0),
        (3e-12, 2e-12, 4e-12),
    )
    suite = PerformanceSuiteReport(
        :accuracy_work_test,
        "Accuracy-work test",
        VALIDATION_SCHEMA_VERSION,
        performance_test_environment(),
        (fast, accurate),
    )
    series = build_accuracy_work_series(
        suite,
        :figure_eight_accuracy_work,
        "Figure-eight accuracy versus work",
        "Synthetic ordered series.",
        :energy_drift,
        ((:fast, "Fast profile", :figure_eight_accuracy_work_fast),
         (:accurate, "Accurate profile", :figure_eight_accuracy_work_accurate)),
    )

    @test series.series_id == :figure_eight_accuracy_work
    @test map(point -> point.point_id, series.points) == (:fast, :accurate)
    @test series.points[1].accuracy_median == 3e-8
    @test series.points[2].accuracy_median == 3e-12
    @test series.points[1].report.summary.elapsed_median == 0.9
    @test ValidationFramework._series_solver_median(series.points[2], :rhs_evaluations) == 200.0

    io = IOBuffer()
    @test render_accuracy_work_series(io, series) === nothing
    text = String(take!(io))
    @test occursin("Accuracy-versus-work series", text)
    @test occursin("Fast profile", text)
    @test occursin("Accuracy median", text)
    @test occursin("no solver is declared universally superior", text)
    @test !occursin("PASS", text)
    @test !occursin("REGRESSION", text)
end

@testset "Accuracy-versus-work series invariants" begin
    report = accuracy_work_test_report(
        :figure_eight_accuracy_work_fast,
        :fast,
        (0.8, 0.9, 1.0),
        (3e-8, 2e-8, 4e-8),
    )
    point = PerformanceAccuracyWorkPoint(:fast, "Fast profile", report, :energy_drift)
    @test_throws ArgumentError PerformanceAccuracyWorkSeries(
        :too_short, "Too short", "Only one point.", :energy_drift, (point,),
    )
    @test_throws ArgumentError PerformanceAccuracyWorkPoint(
        :fast, "Fast profile", report, :missing_metric,
    )
end

@testset "Fixed production accuracy-work entries" begin
    figure_entries = figure_eight_accuracy_work_entries()
    hierarchy_entries = hierarchical_triple_accuracy_work_entries()
    all_entries = representative_accuracy_work_entries()

    @test map(entry -> entry.definition.benchmark_id, figure_entries) ==
          (:figure_eight_accuracy_work_fast, :figure_eight_accuracy_work_accurate)
    @test map(entry -> entry.configuration.solver, figure_entries) == (:fast, :accurate)
    @test map(entry -> entry.definition.benchmark_id, hierarchy_entries) ==
          (:hierarchical_triple_accuracy_work_fast, :hierarchical_triple_accuracy_work_accurate)
    @test length(all_entries) == 4
    @test all(entry -> entry.policy.process_isolation, all_entries)
    @test all(entry -> isfile(entry.path), all_entries)
    @test all(
        entry -> :maximum_relative_energy_drift in entry.definition.required_measurements,
        all_entries,
    )
end

@testset "Reduced accuracy-work operations" begin
    fast = figure_eight_performance_operation(periods=1, solver=:fast, saveat=0.2)()
    accurate = figure_eight_performance_operation(periods=1, solver=:accurate, saveat=0.2)()
    @test fast.solver_statistics.rhs_evaluations > 0
    @test accurate.solver_statistics.rhs_evaluations > 0
    @test any(metric -> metric.metric_id == :maximum_relative_energy_drift, fast.measurements)

    hierarchy_fast = hierarchical_triple_performance_operation(
        duration=1.0, solver=:fast, saveat=0.2, reltol=nothing, abstol=nothing,
    )()
    @test hierarchy_fast.solver_statistics.accepted_steps > 0
end

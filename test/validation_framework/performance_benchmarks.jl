@testset "Representative numerical performance definitions" begin
    figure = figure_eight_performance_definition()
    hierarchy = hierarchical_triple_performance_definition()

    @test figure.benchmark_id == :figure_eight_performance
    @test hierarchy.benchmark_id == :hierarchical_triple_performance
    @test figure.required_measurements == (:elapsed_time, :solver_statistics, :saved_states)
    @test hierarchy.required_measurements == (:elapsed_time, :solver_statistics, :saved_states)
    @test figure.source_path == "examples/validation/performance/figure_eight_performance.jl"
    @test hierarchy.source_path == "examples/validation/performance/hierarchical_triple_performance.jl"

    figure_configuration = figure_eight_performance_configuration()
    hierarchy_configuration = hierarchical_triple_performance_configuration()
    @test figure_configuration.solver == :accurate
    @test hierarchy_configuration.absolute_tolerance == 1e-13
    @test hierarchy_configuration.relative_tolerance == 1e-13

    entries = representative_performance_entries()
    @test map(entry -> entry.definition.benchmark_id, entries) ==
          (:figure_eight_performance, :hierarchical_triple_performance)
    @test all(entry -> entry.policy.process_isolation, entries)
    @test all(entry -> isfile(entry.path), entries)
end

@testset "Reduced numerical performance adapter smoke tests" begin
    figure_observation = figure_eight_performance_operation(
        periods=1,
        solver=:fast,
        saveat=0.2,
    )()
    @test figure_observation.solver_statistics isa SolverStatistics
    @test figure_observation.saved_states > 0
    @test figure_observation.solver_statistics.accepted_steps > 0
    @test figure_observation.solver_statistics.rhs_evaluations > 0
    @test map(metric -> metric.role, figure_observation.measurements) ==
          (role_descriptive, role_descriptive)

    hierarchy_observation = hierarchical_triple_performance_operation(
        duration=1.0,
        solver=:fast,
        saveat=0.2,
        reltol=1e-9,
        abstol=1e-9,
    )()
    @test hierarchy_observation.solver_statistics isa SolverStatistics
    @test hierarchy_observation.saved_states > 0
    @test hierarchy_observation.solver_statistics.accepted_steps > 0
    @test hierarchy_observation.solver_statistics.rhs_evaluations > 0

    policy = QuickBenchmark()
    measurement = run_performance_measurements(
        figure_eight_performance_operation(periods=1, solver=:fast, saveat=0.2),
        policy,
    )
    @test measurement.execution.actual == actual_completed
    @test length(measurement.samples) == policy.sample_runs
    report = build_performance_benchmark_report(
        figure_eight_performance_definition(),
        ValidationEnvironment(
            "1.0.0", "0.5.0", nothing, nothing, string(VERSION),
            string(Sys.KERNEL), string(Sys.ARCH), Threads.nthreads(),
            "2026-07-26T12:00:00Z",
        ),
        figure_eight_performance_configuration(periods=1, solver=:fast, saveat=0.2),
        policy,
        measurement.samples,
        measurement.execution,
    )
    @test report.execution.actual == actual_completed
    @test all(sample -> !isnothing(sample.solver_statistics), report.samples)
    @test all(sample -> !isnothing(sample.saved_states), report.samples)
end

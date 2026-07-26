function performance_test_environment()
    ValidationEnvironment(
        "1.0.0",
        "0.5.0",
        "deadbeef",
        false,
        "1.12.5",
        "Windows",
        "x86_64",
        1,
        "2026-07-26T00:00:00Z",
    )
end

function performance_test_definition(; required_measurements=(:elapsed_time, :rhs_evaluations))
    PerformanceBenchmarkDefinition(
        :figure_eight_performance,
        "Figure-eight performance",
        "Synthetic steady-state performance record test.",
        "examples/validation/performance/figure_eight.jl",
        (:periodic_orbit,),
        (:performance, :figure_eight),
        "1.0.0",
        required_measurements,
        "Synthetic unit-test fixture.",
    )
end

function performance_test_sample(index, elapsed; bytes=nothing, allocations=nothing, gc=nothing)
    PerformanceSample(
        index;
        elapsed_seconds=elapsed,
        allocated_bytes=bytes,
        allocation_count=allocations,
        gc_seconds=gc,
        solver_statistics=SolverStatistics(
            accepted_steps=10 + index,
            rejected_steps=index - 1,
            rhs_evaluations=100 + index,
            saved_states=20,
        ),
        saved_states=20,
        measurements=(
            ValidationMetric(
                :rhs_evaluations,
                "RHS evaluations",
                100 + index;
                scale=scale_count,
                role=role_performance,
            ),
            ValidationMetric(
                :energy_drift,
                "Energy drift",
                1.0e-12 * index;
                scale=scale_relative,
                role=role_descriptive,
            ),
        ),
    )
end

@testset "Performance benchmark definitions and policies" begin
    definition = performance_test_definition()
    @test definition.benchmark_id == :figure_eight_performance
    @test definition.source_path == "examples/validation/performance/figure_eight.jl"
    @test definition.required_measurements == (:elapsed_time, :rhs_evaluations)

    @test_throws ArgumentError PerformanceBenchmarkDefinition(
        :BadId, "Title", "Description", "example.jl", (:smooth,), (), "1.0.0", (:elapsed_time,)
    )
    @test_throws ArgumentError PerformanceBenchmarkDefinition(
        :valid_id, "Title", "Description", "../example.jl", (:smooth,), (), "1.0.0", (:elapsed_time,)
    )
    @test_throws ArgumentError PerformanceBenchmarkDefinition(
        :valid_id, "Title", "Description", "example.jl", (:smooth, :smooth), (), "1.0.0", (:elapsed_time,)
    )
    @test_throws ArgumentError PerformanceBenchmarkDefinition(
        :valid_id, "Title", "Description", "example.jl", (:smooth,), (), "1.0.0", ()
    )

    quick = QuickBenchmark()
    standard = StandardBenchmark()
    publication = PublicationBenchmark()
    @test quick.warmup_runs == 1
    @test quick.sample_runs == 3
    @test !quick.process_isolation
    @test standard.sample_runs == 5
    @test standard.process_isolation
    @test publication.sample_runs == 15
    @test publication.collect_allocated_bytes
    @test publication.collect_allocation_count
    @test publication.collect_gc_time

    @test_throws ArgumentError PerformanceMeasurementPolicy(
        warmup_runs=0, sample_runs=3, collect_elapsed_time=true
    )
    @test_throws ArgumentError PerformanceMeasurementPolicy(
        warmup_runs=1, sample_runs=2, collect_elapsed_time=true
    )
    @test_throws ArgumentError PerformanceMeasurementPolicy(
        warmup_runs=1, sample_runs=3, collect_elapsed_time=false
    )
    @test_throws ArgumentError PerformanceMeasurementPolicy(
        warmup_runs=1, sample_runs=3, collect_elapsed_time=true, timing_clock=:wall_clock
    )
end

@testset "Performance samples and deterministic summaries" begin
    samples = (
        performance_test_sample(1, 1.0; bytes=100, allocations=10),
        performance_test_sample(2, 2.0; bytes=300, allocations=30),
        performance_test_sample(3, 4.0; bytes=200, allocations=20),
    )
    summary = build_performance_summary(samples)
    @test summary.sample_count == 3
    @test summary.elapsed_minimum == 1.0
    @test summary.elapsed_median == 2.0
    @test summary.elapsed_mean == 7 / 3
    @test summary.elapsed_maximum == 4.0
    @test summary.elapsed_standard_deviation ≈ sqrt(7 / 3)
    @test summary.allocated_bytes_minimum == 100
    @test summary.allocated_bytes_median == 200.0
    @test summary.allocated_bytes_maximum == 300
    @test summary.allocation_count_median == 20.0
    @test build_performance_summary(samples) == summary

    even_summary = build_performance_summary((
        performance_test_sample(1, 1.0),
        performance_test_sample(2, 3.0),
        performance_test_sample(3, 5.0),
        performance_test_sample(4, 7.0),
    ))
    @test even_summary.elapsed_median == 4.0

    unavailable = build_performance_summary((
        PerformanceSample(1; measurements=()),
        PerformanceSample(2; measurements=()),
    ))
    @test unavailable.elapsed_median === nothing
    @test unavailable.allocated_bytes_median === nothing

    @test_throws ArgumentError PerformanceSample(0; elapsed_seconds=1.0)
    @test_throws ArgumentError PerformanceSample(1; elapsed_seconds=-1.0)
    @test_throws ArgumentError PerformanceSample(1; allocated_bytes=-1)
    @test_throws ArgumentError PerformanceSample(
        1;
        measurements=(ValidationMetric(:bad_role, "Bad role", 1.0; role=role_acceptance),),
    )
    duplicate = ValidationMetric(:same_metric, "Same", 1; role=role_performance)
    @test_throws ArgumentError PerformanceSample(1; measurements=(duplicate, duplicate))
end

@testset "Performance benchmark and suite reports" begin
    environment = performance_test_environment()
    configuration = ValidationConfiguration(
        solver=:accurate,
        absolute_tolerance=1.0e-12,
        relative_tolerance=1.0e-12,
        time_interval=(0.0, 1.0),
        sampling="saveat=0.01",
    )
    policy = PerformanceMeasurementPolicy(
        warmup_runs=1,
        sample_runs=3,
        collect_elapsed_time=true,
        process_isolation=true,
    )
    samples = (
        performance_test_sample(1, 1.0),
        performance_test_sample(2, 1.1),
        performance_test_sample(3, 0.9),
    )
    execution = ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=4.0)
    report = build_performance_benchmark_report(
        performance_test_definition(),
        environment,
        configuration,
        policy,
        samples,
        execution,
    )
    @test report.summary.elapsed_median == 1.0
    @test report.samples === samples

    suite = PerformanceSuiteReport(
        :core_performance,
        "Core performance suite",
        "1.0.0",
        environment,
        (report,),
    )
    @test performance_suite_complete(suite)
    @test suite.benchmarks[1] === report

    @test_throws ArgumentError build_performance_benchmark_report(
        performance_test_definition(),
        environment,
        configuration,
        policy,
        samples[1:2],
        execution,
    )
    noncontiguous = (
        performance_test_sample(1, 1.0),
        performance_test_sample(3, 1.1),
        performance_test_sample(4, 0.9),
    )
    @test_throws ArgumentError build_performance_benchmark_report(
        performance_test_definition(),
        environment,
        configuration,
        policy,
        noncontiguous,
        execution,
    )
    missing_required = performance_test_definition(required_measurements=(:allocated_bytes,))
    @test_throws ArgumentError build_performance_benchmark_report(
        missing_required,
        environment,
        configuration,
        policy,
        samples,
        execution,
    )
    inconsistent_summary = PerformanceSummary(
        3, 0.0, 0.0, 0.0, 0.0, 0.0, nothing, nothing, nothing, nothing, nothing, nothing
    )
    @test_throws ArgumentError PerformanceBenchmarkReport(
        performance_test_definition(),
        environment,
        configuration,
        policy,
        samples,
        inconsistent_summary,
        execution,
    )

    failed_execution = ExecutionOutcome(actual_errored; exit_code=1, summary="Synthetic failure")
    failed_report = build_performance_benchmark_report(
        performance_test_definition(),
        environment,
        configuration,
        policy,
        (samples[1],),
        failed_execution,
    )
    @test !performance_suite_complete(PerformanceSuiteReport(
        :incomplete_performance,
        "Incomplete performance suite",
        "1.0.0",
        environment,
        (failed_report,),
    ))

    @test_throws ArgumentError PerformanceSuiteReport(
        :duplicate_performance,
        "Duplicate performance suite",
        "1.0.0",
        environment,
        (report, report),
    )
end

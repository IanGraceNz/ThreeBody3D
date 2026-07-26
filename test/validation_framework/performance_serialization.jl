using TOML

function performance_serialization_fixture(; benchmark_id=:serialization_performance)
    environment = performance_test_environment()
    definition = PerformanceBenchmarkDefinition(
        benchmark_id,
        "Serialization performance",
        "Exercises deterministic performance report persistence.",
        "examples/validation/performance/serialization.jl",
        (:infrastructure,),
        (:performance, :serialization),
        "1.0.0",
        (:elapsed_time, :allocated_bytes, :allocation_count, :gc_time, :rhs_evaluations),
        "Synthetic performance serialization fixture.",
    )
    configuration = ValidationConfiguration(
        solver=:vern9,
        absolute_tolerance=1.0e-13,
        relative_tolerance=1.0e-13,
        precision_bits=256,
        time_interval=(0.0, 2.0),
        sampling="saveat=0.01",
        selected_pair=(1, 2),
        thresholds=(ValidationParameter(:switch_distance, 1.0e-4),),
        seeds=(UInt64(17),),
        parameters=(ValidationParameter(:masses, (1.0, 2.0, 3.0)),),
    )
    policy = PerformanceMeasurementPolicy(
        warmup_runs=2,
        sample_runs=3,
        collect_elapsed_time=true,
        collect_allocated_bytes=true,
        collect_allocation_count=true,
        collect_gc_time=true,
        garbage_collection_before_sample=true,
        process_isolation=true,
    )
    samples = Tuple(
        performance_test_sample(
            index,
            (1.0, 0.9, 1.1)[index];
            bytes=(1200, 1100, 1300)[index],
            allocations=(12, 11, 13)[index],
            gc=(0.01, 0.02, 0.015)[index],
        ) for index in 1:3
    )
    build_performance_benchmark_report(
        definition,
        environment,
        configuration,
        policy,
        samples,
        ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=4.5),
    )
end

@testset "Deterministic performance benchmark reports" begin
    report = performance_serialization_fixture()
    first_text = performance_benchmark_text(report)
    second_text = performance_benchmark_text(report)

    @test first_text == second_text
    @test occursin("report_kind = \"performance_benchmark\"", first_text)
    @test occursin("benchmark_id = \"serialization_performance\"", first_text)
    @test occursin("elapsed_median = \"1.0\"", first_text)

    restored = read_performance_benchmark(IOBuffer(first_text))
    @test restored.definition.benchmark_id == report.definition.benchmark_id
    @test restored.definition.required_measurements == report.definition.required_measurements
    @test restored.environment.repository_commit == report.environment.repository_commit
    @test restored.configuration.selected_pair == (1, 2)
    @test restored.configuration.seeds == (UInt64(17),)
    @test restored.policy.sample_runs == 3
    @test restored.policy.collect_gc_time
    @test restored.samples[2].elapsed_seconds == 0.9
    @test restored.samples[3].solver_statistics.rhs_evaluations == 103
    @test restored.samples[1].measurements[2].value == 1.0e-12
    @test restored.summary == report.summary
    @test restored.execution.actual == actual_completed
    @test performance_benchmark_text(restored) == first_text
end

@testset "Deterministic performance suite reports" begin
    first = performance_serialization_fixture()
    second = performance_serialization_fixture(benchmark_id=:second_performance)
    suite = PerformanceSuiteReport(
        :serialization_performance_suite,
        "Serialization performance suite",
        "1.0.0",
        first.environment,
        (first, second),
    )

    text = performance_suite_text(suite)
    @test text == performance_suite_text(suite)
    @test length(findall("[[benchmarks]]", text)) == 2

    restored = read_performance_suite(IOBuffer(text))
    @test restored.suite_id == suite.suite_id
    @test restored.title == suite.title
    @test map(report -> report.definition.benchmark_id, restored.benchmarks) == (
        :serialization_performance,
        :second_performance,
    )
    @test performance_suite_complete(restored)
    @test performance_suite_text(restored) == text
end

@testset "Atomic performance report writing and malformed input" begin
    report = performance_serialization_fixture()
    suite = PerformanceSuiteReport(
        :atomic_performance_suite,
        "Atomic performance suite",
        "1.0.0",
        report.environment,
        (report,),
    )

    mktempdir() do directory
        benchmark_path = joinpath(directory, "benchmark.toml")
        suite_path = joinpath(directory, "suite.toml")
        @test write_report_atomic(benchmark_path, report) == abspath(benchmark_path)
        @test write_report_atomic(suite_path, suite) == abspath(suite_path)
        @test !isfile(benchmark_path * ".tmp")
        @test !isfile(suite_path * ".tmp")
        @test performance_benchmark_text(read_performance_benchmark(benchmark_path)) ==
            performance_benchmark_text(report)
        @test performance_suite_text(read_performance_suite(suite_path)) ==
            performance_suite_text(suite)
    end

    valid = performance_benchmark_text(report)
    @test_throws ArgumentError read_performance_benchmark(IOBuffer(replace(
        valid,
        "report_kind = \"performance_benchmark\"" => "report_kind = \"case\"",
    )))
    @test_throws ArgumentError read_performance_benchmark(IOBuffer(replace(
        valid,
        "schema_version = \"1.0.0\"" => "schema_version = \"2.0.0\"";
        count=1,
    )))
    @test_throws ArgumentError read_performance_benchmark(IOBuffer(replace(
        valid,
        "elapsed_median = \"1.0\"" => "elapsed_median = \"99.0\"",
    )))
    @test_throws TOML.ParserError read_performance_benchmark(IOBuffer("not = [valid"))
end

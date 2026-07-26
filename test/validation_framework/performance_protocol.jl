@testset "Performance benchmark environment protocol" begin
    definition = performance_test_definition()
    standalone = resolve_performance_protocol(definition, "1.0.0"; environment=Dict{String,String}())
    @test !performance_report_requested(standalone)
    @test standalone.report_path === nothing

    mktempdir() do directory
        requested_path = joinpath(directory, "benchmark.toml")
        environment = Dict(
            PERFORMANCE_REPORT_ENV => requested_path,
            PERFORMANCE_BENCHMARK_ID_ENV => "figure_eight_performance",
            PERFORMANCE_SCHEMA_VERSION_ENV => "1.0.0",
        )
        protocol = resolve_performance_protocol(definition, "1.0.0"; environment=environment)
        @test performance_report_requested(protocol)
        @test protocol.report_path == abspath(requested_path)
        @test protocol.requested_benchmark_id == :figure_eight_performance
        @test protocol.requested_schema_version == "1.0.0"
    end

    @test_throws ArgumentError resolve_performance_protocol(definition, "1.0.0";
        environment=Dict(PERFORMANCE_BENCHMARK_ID_ENV => "figure_eight_performance"))
    @test_throws ArgumentError resolve_performance_protocol(definition, "1.0.0";
        environment=Dict(PERFORMANCE_REPORT_ENV => "benchmark.toml"))
    @test_throws ArgumentError resolve_performance_protocol(definition, "1.0.0";
        environment=Dict(
            PERFORMANCE_REPORT_ENV => "benchmark.toml",
            PERFORMANCE_BENCHMARK_ID_ENV => "other_benchmark",
            PERFORMANCE_SCHEMA_VERSION_ENV => "1.0.0",
        ))
end

@testset "Requested performance report publication" begin
    report = presentation_performance_report()
    standalone = PerformanceBenchmarkProtocol(nothing, nothing, nothing)
    @test write_requested_performance_report(standalone, report) === nothing
    @test performance_exit_code(report) == 0

    mktempdir() do directory
        path = joinpath(directory, "nested", "benchmark.toml")
        protocol = PerformanceBenchmarkProtocol(path, :figure_eight_performance, "1.0.0")
        io = IOBuffer()
        @test publish_performance_report(protocol, report; io=io) == 0
        @test isfile(path)
        @test !isfile(path * ".tmp")
        @test read_performance_benchmark(path).definition.benchmark_id == :figure_eight_performance
        @test occursin("Performance benchmark:", String(take!(io)))
    end

    failed = build_performance_benchmark_report(
        report.definition,
        report.environment,
        report.configuration,
        report.policy,
        report.samples[1:1],
        ExecutionOutcome(actual_errored; exit_code=1, summary="Synthetic measurement failure."),
    )
    @test performance_exit_code(failed) == 1

    wrong_benchmark = PerformanceBenchmarkProtocol("benchmark.toml", :other_benchmark, "1.0.0")
    @test_throws ArgumentError write_requested_performance_report(wrong_benchmark, report)
    wrong_schema = PerformanceBenchmarkProtocol("benchmark.toml", :figure_eight_performance, "2.0.0")
    @test_throws ArgumentError write_requested_performance_report(wrong_schema, report)
end

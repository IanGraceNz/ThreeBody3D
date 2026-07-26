function presentation_performance_report(; execution=ExecutionOutcome(actual_completed; exit_code=0))
    samples = (
        performance_test_sample(1, 0.9),
        performance_test_sample(2, 1.0),
        performance_test_sample(3, 1.1),
    )
    build_performance_benchmark_report(
        performance_test_definition(),
        performance_test_environment(),
        ValidationConfiguration(solver=:accurate, time_interval=(0.0, 1.0)),
        QuickBenchmark(),
        samples,
        execution,
    )
end

@testset "Performance benchmark presentation" begin
    report = presentation_performance_report()
    io = IOBuffer()
    @test render_performance_benchmark(io, report) === nothing
    text = String(take!(io))
    @test occursin("Performance benchmark: Figure-eight performance", text)
    @test occursin("Elapsed median seconds: 1.0", text)
    @test occursin("descriptive performance evidence only", text)
    @test !occursin("Benchmark status: PASS", text)
end

@testset "Performance suite presentation" begin
    report = presentation_performance_report()
    suite = PerformanceSuiteReport(
        :presentation_suite,
        "Presentation performance suite",
        "1.0.0",
        report.environment,
        (report,),
    )
    io = IOBuffer()
    @test render_performance_suite(io, suite) === nothing
    text = String(take!(io))
    @test occursin("Performance suite: Presentation performance suite", text)
    @test occursin("[COMPLETED] figure_eight_performance", text)
    @test occursin("Execution complete: true", text)
    @test occursin("not scientific acceptance", text)
end

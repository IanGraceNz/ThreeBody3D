function comparison_report(; elapsed=(1.0, 1.1, 0.9), environment=performance_test_environment(),
    configuration=ValidationConfiguration(solver=:accurate, time_interval=(0.0, 1.0)),
    policy=QuickBenchmark(), definition=performance_test_definition())
    samples = Tuple(performance_test_sample(index, value) for (index, value) in enumerate(elapsed))
    build_performance_benchmark_report(
        definition,
        environment,
        configuration,
        policy,
        samples,
        ExecutionOutcome(actual_completed; exit_code=0),
    )
end

@testset "Descriptive performance differences" begin
    reference = comparison_report(elapsed=(1.0, 1.0, 1.0))
    candidate = comparison_report(elapsed=(1.1, 1.2, 1.3))
    comparison = compare_performance_reports(reference, candidate)

    @test comparison.compatible
    @test isempty(comparison.compatibility_issues)
    @test comparison.benchmark_id == :figure_eight_performance
    elapsed = performance_difference(comparison, :elapsed_median_seconds)
    @test elapsed.reference_value == 1.0
    @test elapsed.candidate_value == 1.2
    @test elapsed.absolute_difference ≈ 0.2
    @test elapsed.relative_difference ≈ 0.2
    @test elapsed.percentage_difference ≈ 20.0

    rhs = performance_difference(comparison, :rhs_evaluations)
    @test rhs.reference_value == 102.0
    @test rhs.candidate_value == 102.0
    @test rhs.percentage_difference == 0.0
    @test performance_difference(comparison, :missing) === nothing
end

@testset "Missing and zero-valued measurements" begin
    difference = PerformanceMeasurementDifference(:zero_reference, "Zero reference", 0.0, 1.0)
    @test difference.absolute_difference == 1.0
    @test difference.relative_difference === nothing
    @test difference.percentage_difference === nothing

    missing = PerformanceMeasurementDifference(:missing_value, "Missing", nothing, 1.0)
    @test missing.absolute_difference === nothing
    @test missing.percentage_difference === nothing
end

@testset "Performance comparison compatibility" begin
    reference = comparison_report()
    different_configuration = ValidationConfiguration(solver=:accurate, time_interval=(0.0, 2.0))
    candidate = comparison_report(configuration=different_configuration)
    @test performance_comparison_issues(reference, candidate) == (:configuration_mismatch,)
    @test_throws ArgumentError compare_performance_reports(reference, candidate)
    descriptive = compare_performance_reports(reference, candidate; require_compatible=false)
    @test !descriptive.compatible
    @test descriptive.compatibility_issues == (:configuration_mismatch,)

    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "cafebabe", false, "1.13.0", "Linux", "aarch64", 4,
        "2026-07-27T00:00:00Z",
    )
    changed_environment = comparison_report(environment=environment)
    issues = performance_comparison_issues(reference, changed_environment)
    @test issues == (:julia_version_mismatch, :thread_count_mismatch, :architecture_mismatch)
    @test isempty(performance_comparison_issues(
        reference, changed_environment; allow_environment_mismatch=true
    ))
    overridden = compare_performance_reports(
        reference, changed_environment; allow_environment_mismatch=true
    )
    @test overridden.compatible
    @test overridden.environment_override
end

@testset "Performance comparison presentation" begin
    comparison = compare_performance_reports(
        comparison_report(elapsed=(1.0, 1.0, 1.0)),
        comparison_report(elapsed=(1.1, 1.2, 1.3)),
    )
    io = IOBuffer()
    @test render_performance_comparison(io, comparison) === nothing
    text = String(take!(io))
    @test occursin("Performance comparison: figure_eight_performance", text)
    @test occursin("Percentage difference:", text)
    @test occursin("descriptive comparison only", text)
    @test !occursin("REGRESSION", text)
    @test !occursin("status: PASS", text)
end

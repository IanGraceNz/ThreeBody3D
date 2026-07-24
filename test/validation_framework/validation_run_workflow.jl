@testset "Validation reference path resolution" begin
    @test resolve_validation_reference_path(environment=Dict{String,String}()) === nothing

    requested = resolve_validation_reference_path(environment=Dict(
        VALIDATION_REFERENCE_ENV => joinpath("relative", "reviewed-reference.toml"),
    ))
    @test isabspath(requested)
    @test endswith(requested, joinpath("relative", "reviewed-reference.toml"))

    @test_throws ArgumentError resolve_validation_reference_path(environment=Dict(
        VALIDATION_REFERENCE_ENV => "   ",
    ))
end

@testset "Validation suite finalization without a reference" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "0238a89", false, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-24T14:00:00Z",
    )
    passing_suite = build_validation_suite_result(
        (_suite_runner_case(:finalization_pass, environment),),
        environment,
    )
    failing_suite = build_validation_suite_result(
        (_suite_runner_case(:finalization_fail, environment; passed=false),),
        environment,
    )

    output = IOBuffer()
    passing = finalize_validation_suite(output, passing_suite)
    @test passing.passed
    @test passing.suite === passing_suite
    @test passing.report_path === nothing
    @test passing.comparison === nothing
    @test isempty(String(take!(output)))

    failing = finalize_validation_suite(IOBuffer(), failing_suite)
    @test !failing.passed
    @test failing.comparison === nothing
end

@testset "Validation suite finalization writes reports and compares references" begin
    passing_suite, reference = _reference_workflow_fixture(observed=1.05)
    failing_suite, _ = _reference_workflow_fixture(observed=1.25)
    reference_text = reference_record_text(reference)

    mktempdir() do directory
        report_path = joinpath(directory, "reports", "suite.toml")
        reference_path = joinpath(directory, "reviewed-reference.toml")
        write_report_atomic(reference_path, reference)

        output = IOBuffer()
        passing = finalize_validation_suite(
            output,
            passing_suite;
            report_path,
            reference_source=reference_path,
        )
        @test passing.passed
        @test passing.report_path == abspath(report_path)
        @test passing.comparison.status == reference_comparison_pass
        @test read(report_path, String) == suite_report_text(passing_suite)
        @test occursin("Overall: PASS", String(take!(output)))
        @test read(reference_path, String) == reference_text

        output = IOBuffer()
        failing = finalize_validation_suite(
            output,
            failing_suite;
            reference_source=reference_path,
        )
        @test !failing.passed
        @test failing.comparison.status == reference_comparison_fail
        @test occursin("Overall: FAIL", String(take!(output)))
        @test read(reference_path, String) == reference_text
    end
end

@testset "Validation finalization stops before partial comparison output" begin
    suite, reference = _reference_workflow_fixture()
    mismatched = ValidationReferenceRecord(
        :other_suite,
        reference.schema_version,
        reference.source_commit,
        reference.provenance,
        reference.metrics,
    )
    output = IOBuffer()

    @test_throws ArgumentError finalize_validation_suite(
        output,
        suite;
        reference_source=IOBuffer(reference_record_text(mismatched)),
    )
    @test isempty(String(take!(output)))
end

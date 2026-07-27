module ValidationRunnerTestHarness

include(joinpath(
    @__DIR__,
    "..",
    "..",
    "examples",
    "validation",
    "run_validation_suite.jl",
))

end

@testset "High-level validation runner reference integration" begin
    runner = ValidationRunnerTestHarness

    # Use the system temporary directory rather than the OneDrive-backed
    # project tree. On Windows, synchronization or indexing can briefly retain
    # handles to newly written child-process reports and make mktempdir cleanup
    # report ENOTEMPTY even after the child process has terminated.
    case_path = joinpath(@__DIR__, "synthetic_runner_case.jl")

    mktempdir() do directory
        entry = runner.ValidationSuiteEntry(
            :synthetic_runner_case,
            "Synthetic process used to test the high-level validation runner.",
            case_path;
            structured=false,
        )

        first_output = IOBuffer()
        first = runner.run_validation_suite(
            (entry,);
            report_path=joinpath(directory, "first-suite.toml"),
            reference_source=nothing,
            comparison_io=first_output,
        )
        @test first.passed
        @test first.comparison === nothing
        @test first.approved_reference === nothing
        @test isfile(first.report_path)
        @test isempty(String(take!(first_output)))

        policy = runner.ValidationMetricReferencePolicy(
            :synthetic_runner_case,
            :process_completed,
            runner.reference_exact,
        )
        reference = runner.build_reference_record(
            first.result,
            (policy,);
            source_commit="0238a89",
            provenance="Reviewed synthetic high-level runner reference.",
        )
        reference_path = joinpath(directory, "reviewed-reference.toml")
        runner.write_report_atomic(reference_path, reference)
        original_reference = read(reference_path, String)

        comparison_output = IOBuffer()
        second = runner.run_validation_suite(
            (entry,);
            report_path=joinpath(directory, "second-suite.toml"),
            reference_source=reference_path,
            comparison_io=comparison_output,
        )
        @test second.passed
        @test second.comparison.status == runner.reference_comparison_pass
        @test second.approved_reference === nothing
        @test occursin("Overall: PASS", String(take!(comparison_output)))
        @test read(reference_path, String) == original_reference

        approved = runner.ApprovedScientificReference(
            "synthetic-runner-approved-reference",
            "1.0.0",
            reference;
            benchmark_scope="Synthetic high-level validation runner.",
            methodology="Review of deterministic process-completion evidence.",
            reviewer="Validation Runner Review Group",
            approval_date="2026-07-25",
            approval_rationale="Approved for exercising the runner workflow.",
        )
        approved_path = joinpath(directory, "approved-reference.toml")
        runner.write_report_atomic(approved_path, approved)
        original_approved = read(approved_path, String)

        approved_output = IOBuffer()
        third = runner.run_validation_suite(
            (entry,);
            report_path=joinpath(directory, "third-suite.toml"),
            reference_source=nothing,
            approved_reference_source=approved_path,
            comparison_io=approved_output,
        )
        approved_text = String(take!(approved_output))
        @test third.passed
        @test third.comparison.status == runner.reference_comparison_pass
        @test third.approved_reference.reference_id == approved.reference_id
        @test occursin("Approved scientific reference:", approved_text)
        @test occursin("Overall: PASS", approved_text)
        @test read(approved_path, String) == original_approved
    end
end

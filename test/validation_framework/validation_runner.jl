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

    mktempdir(runner.project_root()) do directory
        case_path = joinpath(directory, "synthetic_runner_case.jl")
        write(case_path, "println(\"Synthetic validation runner case\")\n")
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
        @test occursin("Overall: PASS", String(take!(comparison_output)))
        @test read(reference_path, String) == original_reference
    end
end

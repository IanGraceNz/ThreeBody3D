function _approved_reference_workflow_fixture(; observed=1.0, known_limitations=nothing)
    suite, observation = _reference_workflow_fixture(; observed)
    approved = ApprovedScientificReference(
        "workflow-suite-reference-2026-07",
        "1.0.0",
        observation;
        benchmark_scope="Synthetic workflow benchmark and retained acceptance metric.",
        methodology="Independent review of deterministic validation output.",
        reviewer="Scientific Review Group",
        approval_date="2026-07-25",
        approval_rationale="Accepted as the controlled comparison point for workflow tests.",
        known_limitations,
    )
    suite, approved
end

@testset "Approved scientific reference metadata presentation" begin
    _, approved = _approved_reference_workflow_fixture(
        known_limitations="Synthetic evidence only.",
    )
    output = IOBuffer()

    @test render_approved_scientific_reference(output, approved) === nothing
    text = String(take!(output))

    @test occursin(
        "Approved scientific reference: workflow-suite-reference-2026-07",
        text,
    )
    @test occursin("Reviewer: Scientific Review Group", text)
    @test occursin("Approval date: 2026-07-25", text)
    @test occursin("Known limitations: Synthetic evidence only.", text)
    @test occursin("numerical agreement only", text)
    @test occursin("explicit human judgement", text)
end

@testset "Approved scientific reference comparison workflow" begin
    suite, approved = _approved_reference_workflow_fixture(observed=1.05)
    source = IOBuffer(approved_scientific_reference_text(approved))
    output = IOBuffer()

    result = run_approved_scientific_reference_comparison(output, suite, source)
    text = String(take!(output))

    @test result.approved_reference.reference_id == approved.reference_id
    @test result.comparison.status == reference_comparison_pass
    @test occursin("Approved scientific reference:", text)
    @test occursin("Reference suite: workflow_suite", text)
    @test occursin("Overall: PASS", text)
    @test findfirst("Approved scientific reference:", text) <
          findfirst("Reference suite:", text)
end

@testset "Approved comparison reports failure without modifying its source" begin
    suite, approved = _approved_reference_workflow_fixture(observed=1.25)
    original_text = approved_scientific_reference_text(approved)

    mktempdir() do directory
        path = joinpath(directory, "approved-reference.toml")
        write_report_atomic(path, approved)
        output = IOBuffer()

        result = run_approved_scientific_reference_comparison(output, suite, path)

        @test result.comparison.status == reference_comparison_fail
        @test occursin("Overall: FAIL", String(take!(output)))
        @test read(path, String) == original_text
        @test !isfile(path * ".tmp")
    end
end

@testset "Approved comparison propagates compatibility errors without output" begin
    suite, approved = _approved_reference_workflow_fixture()
    mismatched_observation = ValidationReferenceRecord(
        :other_suite,
        approved.observation.schema_version,
        approved.observation.source_commit,
        approved.observation.provenance,
        approved.observation.metrics,
    )
    mismatched = ApprovedScientificReference(
        approved.reference_id,
        approved.reference_schema_version,
        mismatched_observation;
        benchmark_scope=approved.benchmark_scope,
        methodology=approved.methodology,
        reviewer=approved.reviewer,
        approval_date=approved.approval_date,
        approval_rationale=approved.approval_rationale,
        known_limitations=approved.known_limitations,
    )
    output = IOBuffer()

    @test_throws ArgumentError run_approved_scientific_reference_comparison(
        output,
        suite,
        IOBuffer(approved_scientific_reference_text(mismatched)),
    )
    @test isempty(String(take!(output)))
end

@testset "Validation finalization with approved scientific references" begin
    passing_suite, approved = _approved_reference_workflow_fixture(observed=1.05)
    failing_suite, _ = _approved_reference_workflow_fixture(observed=1.25)
    approved_text = approved_scientific_reference_text(approved)

    mktempdir() do directory
        report_path = joinpath(directory, "reports", "suite.toml")
        approved_path = joinpath(directory, "approved-reference.toml")
        write_report_atomic(approved_path, approved)

        output = IOBuffer()
        passing = finalize_validation_suite(
            output,
            passing_suite;
            report_path,
            approved_reference_source=approved_path,
        )
        @test passing.passed
        @test passing.approved_reference.reference_id == approved.reference_id
        @test passing.comparison.status == reference_comparison_pass
        @test passing.report_path == abspath(report_path)
        @test occursin("Overall: PASS", String(take!(output)))
        @test read(approved_path, String) == approved_text

        output = IOBuffer()
        failing = finalize_validation_suite(
            output,
            failing_suite;
            approved_reference_source=approved_path,
        )
        @test !failing.passed
        @test failing.approved_reference.reference_id == approved.reference_id
        @test failing.comparison.status == reference_comparison_fail
        @test occursin("Overall: FAIL", String(take!(output)))
        @test read(approved_path, String) == approved_text
    end
end

@testset "Validation finalization rejects dual reference sources before writing" begin
    suite, approved = _approved_reference_workflow_fixture()
    report_path = joinpath(mktempdir(), "suite.toml")

    @test_throws ArgumentError finalize_validation_suite(
        IOBuffer(),
        suite;
        report_path,
        reference_source=IOBuffer(reference_record_text(approved.observation)),
        approved_reference_source=IOBuffer(approved_scientific_reference_text(approved)),
    )
    @test !isfile(report_path)
end

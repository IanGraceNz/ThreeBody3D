function _reference_workflow_fixture(; observed=1.0)
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "7f7ac53", false, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-24T12:00:00Z",
    )
    definition = ValidationCaseDefinition(
        :workflow_case,
        "Reference workflow case",
        "Synthetic case for reference-workflow tests.",
        (:regression,),
        (:reference_workflow,),
        "examples/validation/workflow_case.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    case_result = ValidationCaseResult(
        definition,
        environment,
        ValidationConfiguration(),
        (ValidationMetric(:value, "Value", observed; role=role_acceptance),),
        (),
        nothing,
        ExecutionOutcome(actual_completed; exit_code=0),
    )
    suite = ValidationSuiteResult(
        :workflow_suite,
        "Reference workflow suite",
        "1.0.0",
        environment,
        (case_result,),
    )
    policy = ValidationMetricReferencePolicy(
        :workflow_case,
        :value,
        reference_tolerance;
        absolute_tolerance=0.1,
    )
    reference = build_reference_record(
        ValidationSuiteResult(
            suite.suite_id,
            suite.title,
            suite.schema_version,
            suite.environment,
            (ValidationCaseResult(
                definition,
                environment,
                ValidationConfiguration(),
                (ValidationMetric(:value, "Value", 1.0; role=role_acceptance),),
                (),
                nothing,
                ExecutionOutcome(actual_completed; exit_code=0),
            ),),
        ),
        (policy,);
        source_commit="7f7ac53",
        provenance="Reviewed synthetic workflow reference.",
    )
    suite, reference
end

@testset "Reviewed reference comparison workflow" begin
    suite, reference = _reference_workflow_fixture(observed=1.05)
    source = IOBuffer(reference_record_text(reference))
    output = IOBuffer()

    comparison = run_reference_comparison(output, suite, source)
    text = String(take!(output))

    @test comparison.status == reference_comparison_pass
    @test comparison.reference_source_commit == "7f7ac53"
    @test occursin("Reference suite: workflow_suite", text)
    @test occursin("Overall: PASS", text)
end

@testset "Reference workflow reports failures without updating references" begin
    suite, reference = _reference_workflow_fixture(observed=1.25)
    original_text = reference_record_text(reference)

    mktempdir() do directory
        path = joinpath(directory, "reviewed-reference.toml")
        write_report_atomic(path, reference)
        output = IOBuffer()

        comparison = run_reference_comparison(output, suite, path)

        @test comparison.status == reference_comparison_fail
        @test occursin("Overall: FAIL", String(take!(output)))
        @test read(path, String) == original_text
        @test !isfile(path * ".tmp")
    end
end

@testset "Reference workflow propagates compatibility errors" begin
    suite, reference = _reference_workflow_fixture()
    mismatched = ValidationReferenceRecord(
        :other_suite,
        reference.schema_version,
        reference.source_commit,
        reference.provenance,
        reference.metrics,
    )
    output = IOBuffer()

    @test_throws ArgumentError run_reference_comparison(
        output,
        suite,
        IOBuffer(reference_record_text(mismatched)),
    )
    @test isempty(String(take!(output)))
end

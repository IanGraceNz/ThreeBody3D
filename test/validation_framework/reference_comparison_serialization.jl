function _serialization_reference_comparison()
    passed = ValidationMetricReferenceComparison(
        :first_case,
        :completed,
        reference_exact,
        reference_comparison_pass,
        true,
        true,
    )
    failed = ValidationMetricReferenceComparison(
        :second_case,
        :energy_drift,
        reference_tolerance,
        reference_comparison_fail,
        1.0e-12,
        1.4e-12;
        absolute_difference=4.0e-13,
        allowed_difference=1.0e-13,
    )
    errored = ValidationMetricReferenceComparison(
        :second_case,
        :missing_metric,
        reference_exact,
        reference_comparison_error,
        10,
        nothing;
        message="Synthetic missing metric.",
    )
    ValidationSuiteReferenceComparison(
        :serialization_suite,
        "1.0.0",
        "16b0f7f",
        "Reviewed serialization fixture.",
        (
            ValidationCaseReferenceComparison(:first_case, (passed,)),
            ValidationCaseReferenceComparison(:second_case, (failed, errored)),
        ),
    )
end

@testset "Deterministic reference comparison reports" begin
    comparison = _serialization_reference_comparison()
    first_text = reference_comparison_text(comparison)
    second_text = reference_comparison_text(comparison)

    @test first_text == second_text
    @test occursin("report_kind = \"reference_comparison\"", first_text)
    @test occursin("absolute_difference_text = \"4.0e-13\"", first_text)
    @test occursin("allowed_difference_text = \"1.0e-13\"", first_text)
    @test occursin("observed_present = false", first_text)
    @test findfirst("first_case", first_text) < findfirst("second_case", first_text)

    restored = read_reference_comparison(IOBuffer(first_text))
    @test restored.suite_id == comparison.suite_id
    @test restored.status == reference_comparison_error
    @test map(case_result -> case_result.case_id, restored.cases) == (
        :first_case,
        :second_case,
    )
    restored_metrics = restored.cases[2].metrics
    @test restored_metrics[1].absolute_difference === 4.0e-13
    @test restored_metrics[1].allowed_difference === 1.0e-13
    @test restored_metrics[2].observed_value === nothing
    @test restored_metrics[2].message == "Synthetic missing metric."
    @test reference_comparison_text(restored) == first_text

    mktempdir() do directory
        path = joinpath(directory, "comparison.toml")
        @test write_report_atomic(path, comparison) == abspath(path)
        @test reference_comparison_text(read_reference_comparison(path)) == first_text
    end
end

@testset "Malformed reference comparison reports" begin
    valid = reference_comparison_text(_serialization_reference_comparison())
    @test_throws ArgumentError read_reference_comparison(IOBuffer(replace(
        valid,
        "report_kind = \"reference_comparison\"" => "report_kind = \"reference\"",
    )))
    @test_throws ArgumentError read_reference_comparison(IOBuffer(replace(
        valid,
        "status = \"error\"" => "status = \"pass\"";
        count=1,
    )))
end

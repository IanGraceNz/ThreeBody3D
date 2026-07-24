function _comparison_suite(; energy_drift=1.25e-12, completed=true, include_saved_states=true)
    base = _reference_record_suite()
    original = only(base.cases)
    metrics = ValidationMetric[
        ValidationMetric(:completed, "Completed", completed; role=role_acceptance),
        ValidationMetric(
            :energy_drift,
            "Energy drift",
            energy_drift;
            scale=scale_relative,
            role=role_acceptance,
            aggregation=aggregation_maximum,
        ),
    ]
    include_saved_states && push!(
        metrics,
        ValidationMetric(:saved_states, "Saved states", 101; role=role_diagnostic),
    )
    result = ValidationCaseResult(
        original.definition,
        original.environment,
        original.configuration,
        Tuple(metrics),
        original.criteria,
        original.solver_statistics,
        original.execution,
    )
    ValidationSuiteResult(
        base.suite_id,
        base.title,
        base.schema_version,
        base.environment,
        (result,),
    )
end

function _comparison_reference()
    build_reference_record(
        _reference_record_suite(),
        (
            ValidationMetricReferencePolicy(
                :reference_case,
                :energy_drift,
                reference_tolerance;
                absolute_tolerance=1.0e-14,
                relative_tolerance=1.0e-2,
            ),
            ValidationMetricReferencePolicy(
                :reference_case,
                :completed,
                reference_exact,
            ),
            ValidationMetricReferencePolicy(
                :reference_case,
                :saved_states,
                reference_exact,
            ),
        );
        source_commit="e9763ca",
        provenance="Reviewed synthetic comparison baseline.",
    )
end

@testset "Structured validation reference comparison" begin
    reference = _comparison_reference()
    comparison = compare_reference(_comparison_suite(), reference)

    @test comparison.suite_id == :reference_suite
    @test comparison.reference_source_commit == "e9763ca"
    @test comparison.status == reference_comparison_pass
    @test stable_string(reference_comparison_pass) == "pass"
    @test stable_string(reference_comparison_fail) == "fail"
    @test stable_string(reference_comparison_error) == "error"
    @test map(case -> case.case_id, comparison.cases) == (:reference_case,)
    @test map(metric -> metric.metric_id, only(comparison.cases).metrics) == (
        :energy_drift,
        :completed,
        :saved_states,
    )
    energy = only(comparison.cases).metrics[1]
    @test energy.status == reference_comparison_pass
    @test energy.absolute_difference == 0.0
    @test isapprox(energy.allowed_difference, 1.25e-14; rtol=8eps(Float64), atol=0.0)
end

@testset "Exact and tolerance reference failures" begin
    reference = _comparison_reference()

    exact_failure = compare_reference(
        _comparison_suite(completed=false),
        reference,
    )
    @test exact_failure.status == reference_comparison_fail
    @test only(exact_failure.cases).status == reference_comparison_fail
    @test only(exact_failure.cases).metrics[2].status == reference_comparison_fail
    @test isnothing(only(exact_failure.cases).metrics[2].absolute_difference)

    tolerance_pass = compare_reference(
        _comparison_suite(energy_drift=1.2625e-12),
        reference,
    )
    @test tolerance_pass.status == reference_comparison_pass
    @test only(tolerance_pass.cases).metrics[1].absolute_difference <=
        only(tolerance_pass.cases).metrics[1].allowed_difference

    tolerance_failure = compare_reference(
        _comparison_suite(energy_drift=1.30e-12),
        reference,
    )
    @test tolerance_failure.status == reference_comparison_fail
    @test only(tolerance_failure.cases).metrics[1].status == reference_comparison_fail
end

@testset "Structured reference comparison errors" begin
    reference = _comparison_reference()

    missing_metric = compare_reference(
        _comparison_suite(include_saved_states=false),
        reference,
    )
    @test missing_metric.status == reference_comparison_error
    missing = only(missing_metric.cases).metrics[3]
    @test missing.status == reference_comparison_error
    @test occursin("does not contain metric", something(missing.message))

    nonfinite = compare_reference(
        _comparison_suite(energy_drift=Inf),
        reference,
    )
    @test nonfinite.status == reference_comparison_error
    @test occursin("must be finite", something(only(nonfinite.cases).metrics[1].message))

    integer_observation = _comparison_suite(energy_drift=1.25e-12)
    original = only(integer_observation.cases)
    altered_metrics = (
        ValidationMetric(:completed, "Completed", true; role=role_acceptance),
        ValidationMetric(:energy_drift, "Energy drift", 1; role=role_acceptance),
        ValidationMetric(:saved_states, "Saved states", 101; role=role_diagnostic),
    )
    altered_case = ValidationCaseResult(
        original.definition,
        original.environment,
        original.configuration,
        altered_metrics,
        original.criteria,
        original.solver_statistics,
        original.execution,
    )
    altered_suite = ValidationSuiteResult(
        integer_observation.suite_id,
        integer_observation.title,
        integer_observation.schema_version,
        integer_observation.environment,
        (altered_case,),
    )
    incompatible = compare_reference(altered_suite, reference)
    @test incompatible.status == reference_comparison_error
    @test occursin(
        "floating-point observed metric",
        something(only(incompatible.cases).metrics[1].message),
    )
end

@testset "Reference comparison compatibility and invariants" begin
    reference = _comparison_reference()
    suite = _comparison_suite()

    mismatched_suite = ValidationSuiteResult(
        :other_suite,
        suite.title,
        suite.schema_version,
        suite.environment,
        suite.cases,
    )
    @test_throws ArgumentError compare_reference(mismatched_suite, reference)

    mismatched_schema = ValidationReferenceRecord(
        reference.suite_id,
        "2.0.0",
        reference.source_commit,
        reference.provenance,
        reference.metrics,
    )
    @test_throws ArgumentError compare_reference(suite, mismatched_schema)

    @test_throws ArgumentError ValidationMetricReferenceComparison(
        :reference_case,
        :completed,
        reference_exact,
        reference_comparison_error,
        true,
        nothing,
    )
    @test_throws ArgumentError ValidationMetricReferenceComparison(
        :reference_case,
        :completed,
        reference_exact,
        reference_comparison_pass,
        true,
        true;
        message="Unexpected message.",
    )
end

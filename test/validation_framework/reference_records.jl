function _reference_record_suite()
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "d6c7b9c", false, "1.12.5", "Windows", "x86_64", 2,
        "2026-07-24T09:00:00Z",
    )
    definition = ValidationCaseDefinition(
        :reference_case,
        "Reference case",
        "Synthetic case for reviewed-reference record tests.",
        (:regression,),
        (:reference,),
        "examples/validation/reference_case.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    metrics = (
        ValidationMetric(:completed, "Completed", true; role=role_acceptance),
        ValidationMetric(
            :energy_drift,
            "Energy drift",
            1.25e-12;
            scale=scale_relative,
            role=role_acceptance,
            aggregation=aggregation_maximum,
        ),
        ValidationMetric(:saved_states, "Saved states", 101; role=role_diagnostic),
    )
    result = ValidationCaseResult(
        definition,
        environment,
        ValidationConfiguration(),
        metrics,
        (),
        nothing,
        ExecutionOutcome(actual_completed; exit_code=0),
    )
    ValidationSuiteResult(
        :reference_suite,
        "Reference suite",
        "1.0.0",
        environment,
        (result,),
    )
end

@testset "Validation reference record format" begin
    suite = _reference_record_suite()
    policies = (
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
    )

    record = build_reference_record(
        suite,
        policies;
        source_commit="d6c7b9c",
        provenance="Reviewed synthetic baseline.",
    )

    @test record.suite_id == :reference_suite
    @test record.schema_version == "1.0.0"
    @test record.source_commit == "d6c7b9c"
    @test map(metric -> metric.metric_id, record.metrics) == (
        :energy_drift,
        :completed,
        :saved_states,
    )
    @test record.metrics[1].value == 1.25e-12
    @test record.metrics[1].comparison == reference_tolerance
    @test record.metrics[1].absolute_tolerance == 1.0e-14
    @test record.metrics[2].comparison == reference_exact
    @test stable_string(reference_exact) == "exact"
    @test stable_string(reference_tolerance) == "tolerance"
end

@testset "Validation reference record invariants" begin
    suite = _reference_record_suite()
    exact = ValidationMetricReferencePolicy(
        :reference_case,
        :completed,
        reference_exact,
    )
    @test_throws ArgumentError ValidationMetricReferencePolicy(
        :reference_case,
        :completed,
        reference_exact;
        absolute_tolerance=0.0,
    )
    @test_throws ArgumentError ValidationMetricReferencePolicy(
        :reference_case,
        :energy_drift,
        reference_tolerance,
    )
    @test_throws ArgumentError ValidationMetricReference(
        ValidationMetricReferencePolicy(
            :reference_case,
            :saved_states,
            reference_tolerance;
            absolute_tolerance=0.0,
        ),
        101,
    )
    @test_throws ArgumentError build_reference_record(
        suite,
        (exact, exact);
        source_commit="d6c7b9c",
        provenance="Duplicate policy test.",
    )
    @test_throws ArgumentError build_reference_record(
        suite,
        (ValidationMetricReferencePolicy(
            :missing_case,
            :completed,
            reference_exact,
        ),);
        source_commit="d6c7b9c",
        provenance="Missing case test.",
    )
    @test_throws ArgumentError build_reference_record(
        suite,
        (ValidationMetricReferencePolicy(
            :reference_case,
            :missing_metric,
            reference_exact,
        ),);
        source_commit="d6c7b9c",
        provenance="Missing metric test.",
    )
end

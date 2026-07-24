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

@testset "Deterministic validation reference record reports" begin
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
        source_commit="58d35b4",
        provenance="Reviewed synthetic baseline.",
    )

    first_text = reference_record_text(record)
    second_text = reference_record_text(record)
    @test first_text == second_text
    @test occursin("report_kind = \"reference\"", first_text)
    @test occursin("comparison = \"tolerance\"", first_text)
    @test occursin("absolute_tolerance_kind = \"float64\"", first_text)

    restored = read_reference_record(IOBuffer(first_text))
    @test restored.suite_id == record.suite_id
    @test restored.schema_version == record.schema_version
    @test restored.source_commit == "58d35b4"
    @test restored.provenance == record.provenance
    @test map(metric -> (metric.case_id, metric.metric_id), restored.metrics) == (
        (:reference_case, :energy_drift),
        (:reference_case, :completed),
        (:reference_case, :saved_states),
    )
    @test restored.metrics[1].value === 1.25e-12
    @test restored.metrics[1].absolute_tolerance === 1.0e-14
    @test restored.metrics[1].relative_tolerance === 1.0e-2
    @test restored.metrics[2].value === true
    @test restored.metrics[3].value === 101
    @test reference_record_text(restored) == first_text

    mktempdir() do directory
        path = joinpath(directory, "reference.toml")
        @test write_report_atomic(path, record) == abspath(path)
        @test isfile(path)
        @test !isfile(path * ".tmp")
        @test reference_record_text(read_reference_record(path)) == first_text
    end

    @test_throws ArgumentError read_reference_record(IOBuffer(replace(
        first_text,
        "report_kind = \"reference\"" => "report_kind = \"suite\"",
    )))
    @test_throws ArgumentError read_reference_record(IOBuffer(replace(
        first_text,
        "comparison = \"tolerance\"" => "comparison = \"unknown\"";
        count=1,
    )))
    without_tolerances = replace(
        first_text,
        "absolute_tolerance_kind = \"float64\"\nabsolute_tolerance_text = \"1.0e-14\"\n" => "",
        "relative_tolerance_kind = \"float64\"\nrelative_tolerance_text = \"0.01\"\n" => "",
    )
    @test_throws ArgumentError read_reference_record(IOBuffer(without_tolerances))
end

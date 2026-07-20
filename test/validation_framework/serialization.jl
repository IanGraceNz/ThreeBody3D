using TOML

function _serialization_fixture(; case_id=:serialization_case, required=true, metric_value=1.0e-12)
    definition = ValidationCaseDefinition(
        case_id,
        "Serialization case",
        "Exercises deterministic structured validation reports.",
        (:regression, :infrastructure),
        (:structured_report,),
        "examples/validation/serialization_case.jl",
        (:quick, :standard),
        expected_completed,
        required,
        "1.0.0",
        "Synthetic framework test fixture.",
    )
    environment = ValidationEnvironment(
        "1.0.0", "0.4.0", "84aeda9", false, "1.12.5", "Windows",
        "x86_64", 2, "2026-07-20T09:00:00Z",
    )
    configuration = ValidationConfiguration(
        solver=:vern9,
        absolute_tolerance=1.0e-12,
        relative_tolerance=1.0e-12,
        precision_bits=256,
        time_interval=(0.0, 10.0),
        sampling="saveat=0.1",
        selected_pair=(1, 2),
        thresholds=(ValidationParameter(:entry_threshold, 1.0e-4),),
        seeds=(UInt64(42),),
        parameters=(ValidationParameter(:masses, (1.0, 1.0, 1.0)),),
    )
    metrics = (
        ValidationMetric(
            :energy_drift,
            "Maximum relative energy drift",
            metric_value;
            scale=scale_relative,
            role=role_acceptance,
            aggregation=aggregation_maximum,
            description="Synthetic retained measurement.",
        ),
        ValidationMetric(:completed, "Completed", true; role=role_acceptance),
        ValidationMetric(:status, "Status", :completed; role=role_diagnostic),
        ValidationMetric(:samples, "Samples", (1.0, 2.0, 3.0); role=role_descriptive),
    )
    specifications = (
        AcceptanceCriterionSpecification(
            :energy_limit,
            "Energy drift remains bounded",
            :energy_drift,
            relation_less_than;
            expected_value=1.0e-10,
        ),
        AcceptanceCriterionSpecification(
            :completion_required,
            "Case completed",
            :completed,
            relation_true,
        ),
    )
    criteria = evaluate_criteria(specifications, metrics)
    statistics = SolverStatistics(
        accepted_steps=12,
        rejected_steps=1,
        rhs_evaluations=156,
        saved_states=101,
        elapsed_seconds=0.25,
        segment_count=3,
        switch_count=2,
    )
    ValidationCaseResult(
        definition,
        environment,
        configuration,
        metrics,
        criteria,
        statistics,
        ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=0.3),
    )
end

@testset "Deterministic validation case reports" begin
    result = _serialization_fixture()
    first_text = case_report_text(result)
    second_text = case_report_text(result)
    @test first_text == second_text
    @test occursin("schema_identity = \"threebody3d_validation\"", first_text)
    @test occursin("value_kind = \"float64\"", first_text)

    restored = read_case_report(IOBuffer(first_text))
    @test restored.definition.case_id == result.definition.case_id
    @test restored.environment.repository_commit == "84aeda9"
    @test restored.configuration.selected_pair == (1, 2)
    @test restored.configuration.seeds == (UInt64(42),)
    @test restored.metrics[1].value === result.metrics[1].value
    @test restored.metrics[4].value == (1.0, 2.0, 3.0)
    @test restored.criteria[1].status == criterion_pass
    @test restored.status == case_pass
    @test case_report_text(restored) == first_text
end

@testset "Deterministic validation suite reports" begin
    passing = _serialization_fixture()
    failing = _serialization_fixture(case_id=:optional_failure_case, required=false, metric_value=1.0)
    suite = ValidationSuiteResult(
        :standard_suite,
        "Standard suite",
        "1.0.0",
        passing.environment,
        (passing, failing),
    )
    text = suite_report_text(suite)
    @test text == suite_report_text(suite)
    restored = read_suite_report(IOBuffer(text))
    @test map(result -> result.definition.case_id, restored.cases) == (
        :serialization_case,
        :optional_failure_case,
    )
end

@testset "Atomic report writing and malformed input" begin
    result = _serialization_fixture()
    mktempdir() do directory
        path = joinpath(directory, "case.toml")
        @test write_report_atomic(path, result) == abspath(path)
        @test isfile(path)
        @test !isfile(path * ".tmp")
        @test case_report_text(read_case_report(path)) == case_report_text(result)
    end

    valid = case_report_text(result)
    @test_throws ArgumentError read_case_report(IOBuffer(replace(
        valid,
        "schema_identity = \"threebody3d_validation\"" => "schema_identity = \"unknown\"",
    )))
    @test_throws ArgumentError read_case_report(IOBuffer(replace(
        valid,
        "status = \"pass\"" => "status = \"fail\"";
        count=1,
    )))
    @test_throws TOML.ParserError read_case_report(IOBuffer("not = [valid"))
end

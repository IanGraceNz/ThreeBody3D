function _suite_builder_case(
    case_id::Symbol,
    environment::ValidationEnvironment;
    required::Bool=true,
    criterion_status::CriterionStatus=criterion_pass,
)
    definition = ValidationCaseDefinition(
        case_id,
        "Suite builder case $(case_id)",
        "Synthetic immutable case result for suite-builder tests.",
        (:regression,),
        (:framework,),
        "examples/validation/$(case_id).jl",
        (:quick,),
        expected_completed,
        required,
        "1.0.0",
    )
    metric = ValidationMetric(
        Symbol(case_id, :_metric),
        "Synthetic metric",
        criterion_status == criterion_pass;
        role=role_acceptance,
    )
    specification = AcceptanceCriterionSpecification(
        Symbol(case_id, :_criterion),
        "Synthetic criterion",
        metric.metric_id,
        relation_true,
    )
    criterion = AcceptanceCriterion(
        specification,
        criterion_status;
        message=criterion_status == criterion_error ? "Synthetic evaluation error." : nothing,
    )
    ValidationCaseResult(
        definition,
        environment,
        ValidationConfiguration(),
        (metric,),
        (criterion,),
        nothing,
        ExecutionOutcome(actual_completed; exit_code=0),
    )
end

@testset "Structured suite-result builder" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "720829e", false, "1.12.5", "Windows", "x86_64", 2,
        "2026-07-20T10:00:00Z",
    )
    first = _suite_builder_case(:first_case, environment)
    second = _suite_builder_case(
        :second_case,
        environment;
        criterion_status=criterion_fail,
    )

    builder = ValidationSuiteResultBuilder(
        :standard_suite,
        "Standard validation suite",
        "1.0.0",
        environment,
    )
    @test record_case_result!(builder, first) === builder
    @test record_case_result!(builder, second) === builder

    result = build_suite_result(builder)
    @test map(case -> case.definition.case_id, result.cases) == (:first_case, :second_case)
    @test result.status == suite_fail
    @test result.passed_count == 1
    @test result.failed_count == 1
    @test result.error_count == 0
end

@testset "Suite-result builder invariants" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T10:00:00Z",
    )
    builder = ValidationSuiteResultBuilder(
        :builder_invariants_suite,
        "Builder invariants suite",
        "1.0.0",
        environment,
    )
    case = _suite_builder_case(:unique_case, environment)
    record_case_result!(builder, case)
    @test_throws ArgumentError record_case_result!(builder, case)

    different_environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Linux", "x86_64", 1,
        "2026-07-20T10:00:00Z",
    )
    @test_throws ArgumentError record_case_result!(
        builder,
        _suite_builder_case(:different_environment, different_environment),
    )

    result = build_suite_result(builder)
    @test result.status == suite_pass
    @test_throws ArgumentError record_case_result!(
        builder,
        _suite_builder_case(:late_case, environment),
    )
    @test_throws ArgumentError build_suite_result(builder)
end

@testset "Suite-result builder required-case semantics" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T10:00:00Z",
    )
    builder = ValidationSuiteResultBuilder(
        :required_semantics,
        "Required-case semantics",
        "1.0.0",
        environment,
    )
    record_case_result!(builder, _suite_builder_case(:required_pass, environment))
    record_case_result!(builder, _suite_builder_case(
        :optional_failure,
        environment;
        required=false,
        criterion_status=criterion_fail,
    ))

    result = build_suite_result(builder)
    @test result.status == suite_pass
    @test result.passed_count == 1
    @test result.failed_count == 1
end

@testset "Suite-result builder supports empty suites" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T10:00:00Z",
    )
    result = build_suite_result(ValidationSuiteResultBuilder(
        :empty_suite,
        "Empty suite",
        "1.0.0",
        environment,
    ))
    @test isempty(result.cases)
    @test result.status == suite_pass
    @test result.passed_count == 0
    @test result.failed_count == 0
    @test result.error_count == 0
end

function _suite_runner_case(case_id, environment; passed=true)
    definition = ValidationCaseDefinition(
        case_id,
        "Suite runner case",
        "Synthetic case used to test suite assembly.",
        (:regression,),
        (:suite_runner,),
        "examples/validation/$(case_id).jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    metric = ValidationMetric(
        :completed,
        "Completed",
        passed;
        role=role_acceptance,
    )
    specification = AcceptanceCriterionSpecification(
        :completed,
        "Completed",
        :completed,
        relation_true,
    )
    criterion = AcceptanceCriterion(
        specification,
        passed ? criterion_pass : criterion_fail,
    )
    ValidationCaseResult(
        definition,
        environment,
        ValidationConfiguration(),
        (metric,),
        (criterion,),
        nothing,
        ExecutionOutcome(actual_completed; exit_code=passed ? 0 : 1),
    )
end

@testset "Structured validation suite runner assembly" begin
    suite_environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-24T10:00:00Z",
    )
    child_environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-24T10:00:01Z",
    )
    cases = (
        _suite_runner_case(:first_case, child_environment),
        _suite_runner_case(:second_case, child_environment; passed=false),
    )

    result = build_validation_suite_result(cases, suite_environment)
    @test result.status == suite_fail
    @test map(case -> case.definition.case_id, result.cases) == (:first_case, :second_case)
    @test all(case -> case.environment == suite_environment, result.cases)
end

@testset "Legacy process compatibility result" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-24T10:00:00Z",
    )
    entry = ValidationSuiteEntry(
        :legacy_case,
        "Legacy process case",
        joinpath(@__DIR__, "legacy_case.jl");
        structured=false,
    )
    result = ValidationFramework._process_case_result(
        entry,
        environment,
        normpath(joinpath(@__DIR__, "..", ".."));
        completed=false,
        elapsed_seconds=1.25,
        message="synthetic failure",
    )
    @test result.status == case_error
    @test result.execution.actual == actual_errored
    @test result.execution.elapsed_seconds == 1.25
end

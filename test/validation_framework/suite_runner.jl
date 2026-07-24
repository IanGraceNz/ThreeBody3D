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

@testset "Deterministic complete suite report output" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "1eede3d", false, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-24T10:00:00Z",
    )
    cases = (
        _suite_runner_case(:first_case, environment),
        _suite_runner_case(:second_case, environment; passed=false),
    )
    suite = build_validation_suite_result(cases, environment)

    @test resolve_validation_suite_report_path(environment=Dict{String,String}()) === nothing
    requested = resolve_validation_suite_report_path(environment=Dict(
        VALIDATION_SUITE_REPORT_ENV => joinpath("relative", "suite.toml"),
    ))
    @test isabspath(requested)
    @test endswith(requested, joinpath("relative", "suite.toml"))
    @test_throws ArgumentError resolve_validation_suite_report_path(environment=Dict(
        VALIDATION_SUITE_REPORT_ENV => "   ",
    ))
    @test write_validation_suite_report(suite, nothing) === nothing

    mktempdir() do directory
        first_path = joinpath(directory, "first", "suite.toml")
        second_path = joinpath(directory, "second", "suite.toml")
        @test write_validation_suite_report(suite, first_path) == abspath(first_path)
        @test write_validation_suite_report(suite, second_path) == abspath(second_path)
        @test read(first_path, String) == read(second_path, String)
        @test read(first_path, String) == suite_report_text(suite)
        @test !isfile(first_path * ".tmp")

        restored = read_suite_report(first_path)
        @test restored.status == suite.status
        @test restored.passed_count == suite.passed_count
        @test restored.failed_count == suite.failed_count
        @test restored.error_count == suite.error_count
        @test map(case -> case.definition.case_id, restored.cases) ==
              (:first_case, :second_case)
        @test all(case -> case.environment == environment, restored.cases)
    end
end

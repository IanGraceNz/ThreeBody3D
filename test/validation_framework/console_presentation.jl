function _presentation_case(case_id::Symbol, status::CriterionStatus; required=true)
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "c05309d", false, "1.12.5", "Windows", "x86_64", 2,
        "2026-07-20T10:00:00Z",
    )
    definition = ValidationCaseDefinition(
        case_id,
        "Presentation case $(case_id)",
        "Synthetic case for console-presentation tests.",
        (:regression,),
        (:framework,),
        "examples/validation/$(case_id).jl",
        (:quick,),
        expected_completed,
        required,
        "1.0.0",
    )
    configuration = ValidationConfiguration(
        solver=:vern9,
        absolute_tolerance=1.0e-12,
        time_interval=(0.0, 1.0),
        selected_pair=(1, 2),
        thresholds=(ValidationParameter(:energy_limit, 1.0e-10),),
    )
    metric = ValidationMetric(
        :energy_drift,
        "Maximum relative energy drift",
        2.5e-13;
        scale=scale_relative,
        role=role_acceptance,
    )
    specification = AcceptanceCriterionSpecification(
        :energy_drift_limit,
        "Energy drift remains below the limit",
        :energy_drift,
        relation_less_than;
        expected_value=1.0e-10,
    )
    criterion = AcceptanceCriterion(
        specification,
        status;
        message=status == criterion_error ? "Synthetic evaluation error." : nothing,
    )
    ValidationCaseResult(
        definition,
        environment,
        configuration,
        (metric,),
        (criterion,),
        SolverStatistics(accepted_steps=12, saved_states=20),
        ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=0.25),
    )
end

@testset "Validation case console presentation" begin
    result = _presentation_case(:console_case, criterion_fail)
    before = case_report_text(result)
    io = IOBuffer()
    @test render_case_result(io, result) === nothing
    text = String(take!(io))

    @test occursin("Validation case: Presentation case console_case", text)
    @test occursin("Solver: vern9", text)
    @test occursin("Maximum relative energy drift: 2.5e-13", text)
    @test occursin("[FAIL] Energy drift remains below the limit (required)", text)
    @test occursin("Actual outcome: completed", text)
    @test occursin("Case status: FAIL", text)
    @test case_report_text(result) == before

    io2 = IOBuffer()
    render_case_result(io2, result)
    @test String(take!(io2)) == text
end

@testset "Validation suite console presentation" begin
    first = _presentation_case(:first_console_case, criterion_pass)
    second = _presentation_case(:second_console_case, criterion_fail; required=false)
    suite = ValidationSuiteResult(
        :console_suite,
        "Console presentation suite",
        "1.0.0",
        first.environment,
        (first, second),
    )

    io = IOBuffer()
    @test render_suite_result(io, suite) === nothing
    text = String(take!(io))
    @test occursin("Validation suite: Console presentation suite", text)
    @test findfirst("first_console_case", text) < findfirst("second_console_case", text)
    @test occursin("[PASS] first_console_case", text)
    @test occursin("[FAIL] second_console_case", text)
    @test occursin("Passed: 1", text)
    @test occursin("Failed: 1", text)
    @test occursin("Suite status: PASS", text)
end

@testset "Empty validation presentation sections" begin
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T10:00:00Z",
    )
    suite = ValidationSuiteResult(:empty_console_suite, "Empty suite", "1.0.0", environment, ())
    io = IOBuffer()
    render_suite_result(io, suite)
    @test occursin("Cases\n  (none)", String(take!(io)))
end

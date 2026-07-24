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

function _reference_metric(
    case_id::Symbol,
    metric_id::Symbol,
    status::ReferenceComparisonStatus;
    comparison=reference_exact,
)
    if status == reference_comparison_error
        return ValidationMetricReferenceComparison(
            case_id, metric_id, comparison, status, 1.0, nothing;
            message="Synthetic reference comparison error.",
        )
    elseif comparison == reference_tolerance
        return ValidationMetricReferenceComparison(
            case_id, metric_id, comparison, status, 1.0,
            status == reference_comparison_pass ? 1.01 : 1.25;
            absolute_difference=status == reference_comparison_pass ? 0.01 : 0.25,
            allowed_difference=0.1,
        )
    end
    ValidationMetricReferenceComparison(
        case_id, metric_id, comparison, status, "expected",
        status == reference_comparison_pass ? "expected" : "observed",
    )
end

@testset "Reference comparison status labels" begin
    @test ValidationFramework._status_label(reference_comparison_pass) == "PASS"
    @test ValidationFramework._status_label(reference_comparison_fail) == "FAIL"
    @test ValidationFramework._status_label(reference_comparison_error) == "ERROR"
end

@testset "Reference metric console presentation" begin
    exact = _reference_metric(:case_a, :exact_metric, reference_comparison_pass)
    tolerance = _reference_metric(
        :case_a, :tolerance_metric, reference_comparison_fail;
        comparison=reference_tolerance,
    )
    errored = _reference_metric(:case_a, :error_metric, reference_comparison_error)

    io = IOBuffer()
    @test render_reference_metric(io, exact) === nothing
    exact_text = String(take!(io))
    @test occursin("[PASS] exact_metric", exact_text)
    @test occursin("Reference: expected", exact_text)
    @test occursin("Observed: expected", exact_text)
    @test !occursin("Difference:", exact_text)

    io = IOBuffer()
    render_reference_metric(io, tolerance)
    tolerance_text = String(take!(io))
    @test occursin("[FAIL] tolerance_metric", tolerance_text)
    @test occursin("Difference: 0.25", tolerance_text)
    @test occursin("Allowed: 0.1", tolerance_text)

    io = IOBuffer()
    render_reference_metric(io, errored)
    error_text = String(take!(io))
    @test occursin("[ERROR] error_metric", error_text)
    @test occursin("Observed: nothing", error_text)
    @test occursin("Message: Synthetic reference comparison error.", error_text)
end

@testset "Reference case console presentation" begin
    metrics = (
        _reference_metric(:ordered_case, :first_metric, reference_comparison_pass),
        _reference_metric(
            :ordered_case, :second_metric, reference_comparison_fail;
            comparison=reference_tolerance,
        ),
    )
    comparison = ValidationCaseReferenceComparison(:ordered_case, metrics)

    io = IOBuffer()
    @test render_reference_case(io, comparison) === nothing
    text = String(take!(io))
    @test occursin("Reference case: ordered_case", text)
    @test occursin("Case status: FAIL", text)
    @test findfirst("first_metric", text) < findfirst("second_metric", text)

    empty_comparison = ValidationCaseReferenceComparison(:empty_reference_case, ())
    io = IOBuffer()
    render_reference_case(io, empty_comparison)
    @test occursin("Metrics\n  (none)", String(take!(io)))
end

@testset "Reference suite console presentation" begin
    passed_case = ValidationCaseReferenceComparison(
        :passed_case,
        (_reference_metric(:passed_case, :metric_a, reference_comparison_pass),),
    )
    failed_case = ValidationCaseReferenceComparison(
        :failed_case,
        (_reference_metric(:failed_case, :metric_b, reference_comparison_fail),),
    )
    suite = ValidationSuiteReferenceComparison(
        :reference_suite,
        "1.0.0",
        "437cc13",
        "Synthetic reviewed reference.",
        (passed_case, failed_case),
    )

    io = IOBuffer()
    @test render_reference_suite(io, suite) === nothing
    text = String(take!(io))
    @test occursin("Reference suite: reference_suite", text)
    @test occursin("Schema version: 1.0.0", text)
    @test occursin("Reference source commit: 437cc13", text)
    @test occursin("Reference provenance: Synthetic reviewed reference.", text)
    @test occursin("Suite status: FAIL", text)
    @test findfirst("passed_case", text) < findfirst("failed_case", text)

    empty_suite = ValidationSuiteReferenceComparison(
        :empty_reference_suite,
        "1.0.0",
        "437cc13",
        "Synthetic empty reference.",
        (),
    )
    io = IOBuffer()
    render_reference_suite(io, empty_suite)
    @test occursin("Cases\n  (none)", String(take!(io)))
end

@testset "Reference summary and report presentation" begin
    passed_case = ValidationCaseReferenceComparison(
        :summary_pass,
        (_reference_metric(:summary_pass, :metric_pass, reference_comparison_pass),),
    )
    failed_case = ValidationCaseReferenceComparison(
        :summary_fail,
        (_reference_metric(:summary_fail, :metric_fail, reference_comparison_fail),),
    )
    errored_case = ValidationCaseReferenceComparison(
        :summary_error,
        (_reference_metric(:summary_error, :metric_error, reference_comparison_error),),
    )
    suite = ValidationSuiteReferenceComparison(
        :summary_suite,
        "1.0.0",
        "437cc13",
        "Synthetic summary reference.",
        (passed_case, failed_case, errored_case),
    )

    io = IOBuffer()
    @test render_reference_summary(io, suite) === nothing
    summary_text = String(take!(io))
    @test occursin("Passed: 1", summary_text)
    @test occursin("Failed: 1", summary_text)
    @test occursin("Errors: 1", summary_text)
    @test occursin("Overall: ERROR", summary_text)

    io = IOBuffer()
    @test render_reference_report(io, suite) === nothing
    report_text = String(take!(io))
    @test occursin("Reference suite: summary_suite", report_text)
    @test occursin("Reference case: summary_pass", report_text)
    @test occursin("[PASS] metric_pass", report_text)
    @test occursin("\n\nSummary\n", report_text)

    io2 = IOBuffer()
    render_reference_report(io2, suite)
    @test String(take!(io2)) == report_text
end

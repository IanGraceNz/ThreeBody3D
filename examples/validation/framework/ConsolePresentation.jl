# Pure human-readable presentation for retained validation results.

_status_label(status::CriterionStatus) = uppercase(stable_string(status))
_status_label(status::ValidationCaseStatus) = uppercase(stable_string(status))
_status_label(status::ValidationSuiteStatus) = uppercase(stable_string(status))
_status_label(status::ReferenceComparisonStatus) = uppercase(stable_string(status))

function _display_value(value)
    value isa Tuple && return "[" * join((_display_value(item) for item in value), ", ") * "]"
    value isa Symbol && return String(value)
    string(value)
end

"""Render one immutable validation case result to `io` without reevaluation."""
function render_case_result(io::IO, result::ValidationCaseResult)
    definition = result.definition
    println(io, "Validation case: ", definition.title)
    println(io, "Case ID: ", definition.case_id)
    println(io, "Source: ", definition.source_path)
    println(io, "Required: ", definition.required)
    println(io, "Expected execution: ", stable_string(definition.expected_outcome))
    println(io)

    println(io, "Configuration")
    configuration = result.configuration
    !isnothing(configuration.solver) && println(io, "  Solver: ", configuration.solver)
    !isnothing(configuration.absolute_tolerance) && println(io, "  Absolute tolerance: ", configuration.absolute_tolerance)
    !isnothing(configuration.relative_tolerance) && println(io, "  Relative tolerance: ", configuration.relative_tolerance)
    !isnothing(configuration.precision_bits) && println(io, "  Precision bits: ", configuration.precision_bits)
    !isnothing(configuration.time_interval) && println(io, "  Time interval: ", _display_value(configuration.time_interval))
    !isnothing(configuration.sampling) && println(io, "  Sampling: ", configuration.sampling)
    !isnothing(configuration.selected_pair) && println(io, "  Selected pair: ", _display_value(configuration.selected_pair))
    for parameter in configuration.thresholds
        println(io, "  Threshold ", parameter.parameter_id, ": ", _display_value(parameter.value))
    end
    for parameter in configuration.parameters
        println(io, "  Parameter ", parameter.parameter_id, ": ", _display_value(parameter.value))
    end
    for (index, seed) in pairs(configuration.seeds)
        println(io, "  Seed ", index, ": ", seed)
    end
    println(io)

    println(io, "Metrics")
    if isempty(result.metrics)
        println(io, "  (none)")
    else
        for metric in result.metrics
            suffix = isnothing(metric.units) ? "" : " " * metric.units
            println(io, "  ", metric.label, ": ", _display_value(metric.value), suffix)
        end
    end
    println(io)

    println(io, "Acceptance criteria")
    if isempty(result.criteria)
        println(io, "  (none)")
    else
        for criterion in result.criteria
            specification = criterion.specification
            print(io, "  [", _status_label(criterion.status), "] ", specification.label)
            print(io, " (", stable_string(specification.severity), ")")
            !isnothing(criterion.message) && print(io, ": ", criterion.message)
            println(io)
        end
    end
    println(io)

    println(io, "Execution")
    println(io, "  Actual outcome: ", stable_string(result.execution.actual))
    !isnothing(result.execution.exit_code) && println(io, "  Exit code: ", result.execution.exit_code)
    !isnothing(result.execution.elapsed_seconds) && println(io, "  Elapsed seconds: ", result.execution.elapsed_seconds)
    !isnothing(result.execution.summary) && println(io, "  Summary: ", result.execution.summary)
    println(io, "Case status: ", _status_label(result.status))
    nothing
end

render_case_result(result::ValidationCaseResult) = render_case_result(stdout, result)

"""Render one immutable validation suite result to `io` in retained case order."""
function render_suite_result(io::IO, result::ValidationSuiteResult)
    println(io, "Validation suite: ", result.title)
    println(io, "Suite ID: ", result.suite_id)
    println(io, "Schema version: ", result.schema_version)
    println(io)
    println(io, "Cases")
    if isempty(result.cases)
        println(io, "  (none)")
    else
        for case_result in result.cases
            definition = case_result.definition
            requirement = definition.required ? "required" : "optional"
            println(io, "  [", _status_label(case_result.status), "] ", definition.case_id,
                " — ", definition.title, " (", requirement, ")")
        end
    end
    println(io)
    println(io, "Passed: ", result.passed_count)
    println(io, "Failed: ", result.failed_count)
    println(io, "Errors: ", result.error_count)
    println(io, "Suite status: ", _status_label(result.status))
    nothing
end

render_suite_result(result::ValidationSuiteResult) = render_suite_result(stdout, result)

"""Render one immutable reference metric comparison to `io`."""
function render_reference_metric(io::IO, metric::ValidationMetricReferenceComparison)
    println(io, "[", _status_label(metric.status), "] ", metric.metric_id)
    println(io, "  Reference: ", _display_value(metric.reference_value))
    println(io, "  Observed: ", _display_value(metric.observed_value))
    if metric.comparison == reference_tolerance
        !isnothing(metric.absolute_difference) && println(io, "  Difference: ", metric.absolute_difference)
        !isnothing(metric.allowed_difference) && println(io, "  Allowed: ", metric.allowed_difference)
    end
    !isnothing(metric.message) && println(io, "  Message: ", metric.message)
    nothing
end

render_reference_metric(metric::ValidationMetricReferenceComparison) =
    render_reference_metric(stdout, metric)


"""Render one immutable reference case comparison to `io` in retained metric order."""
function render_reference_case(io::IO, case_result::ValidationCaseReferenceComparison)
    println(io, "Reference case: ", case_result.case_id)
    println(io, "Case status: ", _status_label(case_result.status))
    println(io, "Metrics")
    if isempty(case_result.metrics)
        println(io, "  (none)")
    else
        for metric in case_result.metrics
            metric_io = IOBuffer()
            render_reference_metric(metric_io, metric)
            metric_text = String(take!(metric_io))
            for line in split(chomp(metric_text), '\n')
                println(io, "  ", line)
            end
        end
    end
    nothing
end

render_reference_case(case_result::ValidationCaseReferenceComparison) =
    render_reference_case(stdout, case_result)



"""Render one immutable reference suite comparison to `io` in retained case order."""
function render_reference_suite(io::IO, suite::ValidationSuiteReferenceComparison)
    println(io, "Reference suite: ", suite.suite_id)
    println(io, "Schema version: ", suite.schema_version)
    println(io, "Reference source commit: ", suite.reference_source_commit)
    println(io, "Reference provenance: ", suite.reference_provenance)
    println(io, "Suite status: ", _status_label(suite.status))
    println(io, "Cases")
    if isempty(suite.cases)
        println(io, "  (none)")
    else
        for case_result in suite.cases
            case_io = IOBuffer()
            render_reference_case(case_io, case_result)
            case_text = String(take!(case_io))
            for line in split(chomp(case_text), '\n')
                println(io, "  ", line)
            end
        end
    end
    nothing
end

render_reference_suite(suite::ValidationSuiteReferenceComparison) =
    render_reference_suite(stdout, suite)


"""Render a compact summary of one immutable reference suite comparison to `io`."""
function render_reference_summary(io::IO, suite::ValidationSuiteReferenceComparison)
    passed = count(c -> c.status == reference_comparison_pass, suite.cases)
    failed = count(c -> c.status == reference_comparison_fail, suite.cases)
    errored = count(c -> c.status == reference_comparison_error, suite.cases)

    println(io, "Summary")
    println(io, "  Passed: ", passed)
    println(io, "  Failed: ", failed)
    println(io, "  Errors: ", errored)
    println(io, "  Overall: ", _status_label(suite.status))
    nothing
end

render_reference_summary(suite::ValidationSuiteReferenceComparison) =
    render_reference_summary(stdout, suite)


"""Render a complete immutable reference comparison report to `io`."""
function render_reference_report(io::IO, suite::ValidationSuiteReferenceComparison)
    render_reference_suite(io, suite)
    println(io)
    render_reference_summary(io, suite)
    nothing
end

render_reference_report(suite::ValidationSuiteReferenceComparison) =
    render_reference_report(stdout, suite)

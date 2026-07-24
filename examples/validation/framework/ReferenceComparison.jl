# Structured, side-effect-free comparison of suite results against reviewed references.

@enum ReferenceComparisonStatus begin
    reference_comparison_pass
    reference_comparison_fail
    reference_comparison_error
end

const _REFERENCE_COMPARISON_STATUS_STRINGS = Dict{ReferenceComparisonStatus,String}(
    reference_comparison_pass => "pass",
    reference_comparison_fail => "fail",
    reference_comparison_error => "error",
)

stable_string(value::ReferenceComparisonStatus) = _REFERENCE_COMPARISON_STATUS_STRINGS[value]

"""Comparison outcome for one retained reference metric."""
struct ValidationMetricReferenceComparison
    case_id::Symbol
    metric_id::Symbol
    comparison::ReferenceComparisonKind
    status::ReferenceComparisonStatus
    reference_value::Any
    observed_value::Any
    absolute_difference::Union{Nothing,Real}
    allowed_difference::Union{Nothing,Real}
    message::Union{Nothing,String}

    function ValidationMetricReferenceComparison(
        case_id,
        metric_id,
        comparison::ReferenceComparisonKind,
        status::ReferenceComparisonStatus,
        reference_value,
        observed_value;
        absolute_difference=nothing,
        allowed_difference=nothing,
        message=nothing,
    )
        status == reference_comparison_error && isnothing(message) && throw(
            ArgumentError("Errored reference comparisons must retain a message."),
        )
        status != reference_comparison_error && !isnothing(message) && throw(
            ArgumentError("Only errored reference comparisons may retain a message."),
        )
        for (label, value) in (
            ("absolute_difference", absolute_difference),
            ("allowed_difference", allowed_difference),
        )
            if !isnothing(value)
                value isa Real || throw(ArgumentError("$label must be real."))
                isfinite(value) && value >= zero(value) || throw(
                    ArgumentError("$label must be finite and nonnegative."),
                )
            end
        end
        comparison == reference_exact && (
            isnothing(absolute_difference) && isnothing(allowed_difference)
        ) || comparison == reference_tolerance || throw(
            ArgumentError("Exact comparisons cannot retain numerical differences."),
        )
        new(
            _validated_identifier(case_id, "case_id"),
            _validated_identifier(metric_id, "metric_id"),
            comparison,
            status,
            reference_value,
            observed_value,
            absolute_difference,
            allowed_difference,
            isnothing(message) ? nothing : _nonempty_string(message, "message"),
        )
    end
end

"""Ordered comparison outcomes for one referenced validation case."""
struct ValidationCaseReferenceComparison
    case_id::Symbol
    status::ReferenceComparisonStatus
    metrics::Tuple{Vararg{ValidationMetricReferenceComparison}}

    function ValidationCaseReferenceComparison(case_id, metrics)
        normalized = Tuple(metrics)
        all(metric -> metric isa ValidationMetricReferenceComparison, normalized) || throw(
            ArgumentError("metrics must contain ValidationMetricReferenceComparison records."),
        )
        validated_case_id = _validated_identifier(case_id, "case_id")
        all(metric -> metric.case_id == validated_case_id, normalized) || throw(
            ArgumentError("All metric comparisons must belong to case $validated_case_id."),
        )
        metric_ids = map(metric -> metric.metric_id, normalized)
        length(metric_ids) == length(unique(metric_ids)) || throw(
            ArgumentError("Metric comparison identifiers must be unique within a case."),
        )
        status = _aggregate_reference_comparison_status(map(metric -> metric.status, normalized))
        new(validated_case_id, status, normalized)
    end
end

"""Complete ordered comparison of one suite result against one reviewed reference."""
struct ValidationSuiteReferenceComparison
    suite_id::Symbol
    schema_version::String
    reference_source_commit::String
    reference_provenance::String
    status::ReferenceComparisonStatus
    cases::Tuple{Vararg{ValidationCaseReferenceComparison}}

    function ValidationSuiteReferenceComparison(
        suite_id,
        schema_version,
        reference_source_commit,
        reference_provenance,
        cases,
    )
        normalized = Tuple(cases)
        all(case -> case isa ValidationCaseReferenceComparison, normalized) || throw(
            ArgumentError("cases must contain ValidationCaseReferenceComparison records."),
        )
        case_ids = map(case -> case.case_id, normalized)
        length(case_ids) == length(unique(case_ids)) || throw(
            ArgumentError("Case comparison identifiers must be unique."),
        )
        status = _aggregate_reference_comparison_status(map(case -> case.status, normalized))
        new(
            _validated_identifier(suite_id, "suite_id"),
            _validated_version(schema_version, "schema_version"),
            _nonempty_string(reference_source_commit, "reference_source_commit"),
            _nonempty_string(reference_provenance, "reference_provenance"),
            status,
            normalized,
        )
    end
end

function _aggregate_reference_comparison_status(statuses)
    any(==(reference_comparison_error), statuses) && return reference_comparison_error
    any(==(reference_comparison_fail), statuses) && return reference_comparison_fail
    reference_comparison_pass
end

function _comparison_error(reference::ValidationMetricReference, message)
    ValidationMetricReferenceComparison(
        reference.case_id,
        reference.metric_id,
        reference.comparison,
        reference_comparison_error,
        reference.value,
        nothing;
        message=message,
    )
end

function _compare_exact_reference(
    reference::ValidationMetricReference,
    observed,
)
    status = isequal(observed, reference.value) ?
        reference_comparison_pass : reference_comparison_fail
    ValidationMetricReferenceComparison(
        reference.case_id,
        reference.metric_id,
        reference.comparison,
        status,
        reference.value,
        observed,
    )
end

function _compare_tolerance_reference(
    reference::ValidationMetricReference,
    observed,
)
    observed isa AbstractFloat || return _comparison_error(
        reference,
        "Tolerance comparison requires a floating-point observed metric.",
    )
    isfinite(observed) || return _comparison_error(
        reference,
        "Tolerance-comparison observed values must be finite.",
    )
    absolute_difference = abs(observed - reference.value)
    absolute_allowance = isnothing(reference.absolute_tolerance) ?
        zero(absolute_difference) : reference.absolute_tolerance
    relative_allowance = isnothing(reference.relative_tolerance) ?
        zero(absolute_difference) : reference.relative_tolerance * abs(reference.value)
    allowed_difference = max(absolute_allowance, relative_allowance)
    status = absolute_difference <= allowed_difference ?
        reference_comparison_pass : reference_comparison_fail
    ValidationMetricReferenceComparison(
        reference.case_id,
        reference.metric_id,
        reference.comparison,
        status,
        reference.value,
        observed;
        absolute_difference=absolute_difference,
        allowed_difference=allowed_difference,
    )
end

function _compare_metric_reference(reference::ValidationMetricReference, metric)
    isnothing(metric) && return _comparison_error(
        reference,
        "Case $(reference.case_id) does not contain metric $(reference.metric_id).",
    )
    reference.comparison == reference_exact && return _compare_exact_reference(
        reference,
        metric.value,
    )
    _compare_tolerance_reference(reference, metric.value)
end

"""
    compare_reference(suite, reference)

Compare a completed suite against an immutable reviewed reference. Reference
metric order defines deterministic output order. Metrics not retained by the
reference are intentionally ignored because reference records are compact.
"""
function compare_reference(
    suite::ValidationSuiteResult,
    reference::ValidationReferenceRecord,
)
    suite.suite_id == reference.suite_id || throw(ArgumentError(
        "Suite identifier $(suite.suite_id) does not match reference identifier $(reference.suite_id).",
    ))
    suite.schema_version == reference.schema_version || throw(ArgumentError(
        "Suite schema version $(suite.schema_version) does not match reference schema version $(reference.schema_version).",
    ))

    suite_cases = Dict(result.definition.case_id => result for result in suite.cases)
    ordered_case_ids = unique(map(metric -> metric.case_id, reference.metrics))
    case_comparisons = map(ordered_case_ids) do case_id
        references = filter(metric -> metric.case_id == case_id, reference.metrics)
        result = get(suite_cases, case_id, nothing)
        metric_comparisons = if isnothing(result)
            map(references) do metric_reference
                _comparison_error(
                    metric_reference,
                    "Suite $(suite.suite_id) does not contain case $case_id.",
                )
            end
        else
            metrics = Dict(metric.metric_id => metric for metric in result.metrics)
            map(references) do metric_reference
                _compare_metric_reference(
                    metric_reference,
                    get(metrics, metric_reference.metric_id, nothing),
                )
            end
        end
        ValidationCaseReferenceComparison(case_id, metric_comparisons)
    end

    ValidationSuiteReferenceComparison(
        suite.suite_id,
        suite.schema_version,
        reference.source_commit,
        reference.provenance,
        case_comparisons,
    )
end

# Deterministic criterion evaluation for schema-1 validation records.

function _criterion_error(specification::AcceptanceCriterionSpecification, message)
    AcceptanceCriterion(
        specification,
        criterion_error;
        message=String(message),
    )
end

function _criterion_result(
    specification::AcceptanceCriterionSpecification,
    passed::Bool;
    failure_message=nothing,
)
    if passed
        AcceptanceCriterion(specification, criterion_pass)
    else
        AcceptanceCriterion(
            specification,
            criterion_fail;
            message=isnothing(failure_message) ? nothing : String(failure_message),
        )
    end
end

function _requires_expected_value(relation::CriterionRelation)
    relation in (
        relation_less_than,
        relation_less_than_or_equal,
        relation_greater_than,
        relation_greater_than_or_equal,
        relation_equal,
        relation_approximately_equal,
        relation_expected_status,
    )
end

function _comparison_values(specification, metric)
    observed = metric.value
    expected = specification.expected_value
    _requires_expected_value(specification.relation) && isnothing(expected) && return nothing
    (observed, expected)
end

function _ordered_numeric_values(specification, metric)
    values = _comparison_values(specification, metric)
    isnothing(values) && return nothing
    observed, expected = values
    observed isa Real &&
        expected isa Real &&
        !(observed isa Bool) &&
        !(expected isa Bool) || return nothing
    (observed, expected)
end

function _nonfinite_observation(metric::ValidationMetric)
    metric.value isa AbstractFloat && !isfinite(metric.value)
end

function _evaluate_ordering(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
    comparison,
)
    values = _ordered_numeric_values(specification, metric)
    isnothing(values) && return _criterion_error(
        specification,
        "Ordering comparison requires real observed and expected scalar values.",
    )
    _nonfinite_observation(metric) && return _criterion_result(
        specification,
        false;
        failure_message="Observed numeric value is not finite.",
    )
    observed, expected = values
    isfinite(expected) || return _criterion_error(
        specification,
        "Ordering comparison requires a finite expected value.",
    )
    _criterion_result(specification, comparison(observed, expected))
end

function _evaluate_equal(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
)
    values = _comparison_values(specification, metric)
    isnothing(values) && return _criterion_error(
        specification,
        "Equality comparison requires an expected value.",
    )
    observed, expected = values
    observed isa Tuple && return _criterion_error(
        specification,
        "Sequence metrics require an explicitly aggregated scalar metric for equality evaluation.",
    )
    typeof(observed) == typeof(expected) || return _criterion_error(
        specification,
        "Equality comparison requires observed and expected values of the same type.",
    )
    _nonfinite_observation(metric) && return _criterion_result(
        specification,
        false;
        failure_message="Observed numeric value is not finite.",
    )
    _criterion_result(specification, observed == expected)
end

function _evaluate_approximately_equal(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
)
    values = _ordered_numeric_values(specification, metric)
    isnothing(values) && return _criterion_error(
        specification,
        "Approximate equality requires real observed and expected scalar values.",
    )
    isnothing(specification.absolute_tolerance) &&
        isnothing(specification.relative_tolerance) && return _criterion_error(
            specification,
            "Approximate equality requires an absolute or relative tolerance.",
        )
    _nonfinite_observation(metric) && return _criterion_result(
        specification,
        false;
        failure_message="Observed numeric value is not finite.",
    )
    observed, expected = values
    isfinite(expected) || return _criterion_error(
        specification,
        "Approximate equality requires a finite expected value.",
    )
    atol = something(specification.absolute_tolerance, zero(observed - expected))
    rtol = something(specification.relative_tolerance, zero(observed - expected))
    _criterion_result(
        specification,
        isapprox(observed, expected; atol=atol, rtol=rtol, nans=false),
    )
end

function _evaluate_finite(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
)
    isnothing(specification.expected_value) || return _criterion_error(
        specification,
        "Finite relation does not accept an expected value.",
    )
    metric.value isa Real && !(metric.value isa Bool) || return _criterion_error(
        specification,
        "Finite relation requires a real scalar metric.",
    )
    _criterion_result(specification, isfinite(metric.value))
end

function _evaluate_true(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
)
    isnothing(specification.expected_value) || return _criterion_error(
        specification,
        "True relation does not accept an expected value.",
    )
    metric.value isa Bool || return _criterion_error(
        specification,
        "True relation requires a Boolean metric.",
    )
    _criterion_result(specification, metric.value)
end

function _evaluate_expected_status(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
)
    values = _comparison_values(specification, metric)
    isnothing(values) && return _criterion_error(
        specification,
        "Expected-status relation requires an expected value.",
    )
    observed, expected = values
    observed isa Symbol || return _criterion_error(
        specification,
        "Expected-status relation requires a status metric represented by a Symbol.",
    )
    expected isa Symbol || return _criterion_error(
        specification,
        "Expected-status relation requires an expected Symbol.",
    )
    _criterion_result(specification, observed == expected)
end

"""
    evaluate_criterion(specification, metric)

Evaluate one declared criterion against its referenced immutable metric.
Scientific noncompliance produces `criterion_fail`; invalid criterion domains or
incompatible value types produce `criterion_error` with a deterministic message.
"""
function evaluate_criterion(
    specification::AcceptanceCriterionSpecification,
    metric::ValidationMetric,
)
    specification.metric_id == metric.metric_id || return _criterion_error(
        specification,
        "Criterion references metric $(specification.metric_id), not $(metric.metric_id).",
    )

    relation = specification.relation
    relation == relation_less_than && return _evaluate_ordering(specification, metric, <)
    relation == relation_less_than_or_equal && return _evaluate_ordering(specification, metric, <=)
    relation == relation_greater_than && return _evaluate_ordering(specification, metric, >)
    relation == relation_greater_than_or_equal && return _evaluate_ordering(specification, metric, >=)
    relation == relation_equal && return _evaluate_equal(specification, metric)
    relation == relation_approximately_equal && return _evaluate_approximately_equal(specification, metric)
    relation == relation_finite && return _evaluate_finite(specification, metric)
    relation == relation_true && return _evaluate_true(specification, metric)
    relation == relation_expected_status && return _evaluate_expected_status(specification, metric)
    _criterion_error(specification, "Unsupported criterion relation $(stable_string(relation)).")
end

"""
    evaluate_criteria(specifications, metrics)

Evaluate an ordered collection of criterion specifications against an ordered
collection of metrics. Metric identifiers and criterion identifiers must be
unique, and every criterion must reference a retained metric.
"""
function evaluate_criteria(specifications, metrics)
    normalized_specifications = Tuple(specifications)
    normalized_metrics = Tuple(metrics)
    all(value -> value isa AcceptanceCriterionSpecification, normalized_specifications) || throw(
        ArgumentError("specifications must contain AcceptanceCriterionSpecification records."),
    )
    all(value -> value isa ValidationMetric, normalized_metrics) || throw(
        ArgumentError("metrics must contain ValidationMetric records."),
    )

    criterion_ids = map(value -> value.criterion_id, normalized_specifications)
    metric_ids = map(value -> value.metric_id, normalized_metrics)
    _unique_identifiers(criterion_ids, "specifications")
    _unique_identifiers(metric_ids, "metrics")

    metric_by_id = Dict(metric.metric_id => metric for metric in normalized_metrics)
    missing_metric_ids = unique(collect(
        specification.metric_id for specification in normalized_specifications
        if !haskey(metric_by_id, specification.metric_id)
    ))
    isempty(missing_metric_ids) || throw(
        ArgumentError(
            "Criterion specifications reference missing metrics: " *
            join(string.(missing_metric_ids), ", ") * ".",
        ),
    )

    Tuple(
        evaluate_criterion(specification, metric_by_id[specification.metric_id])
        for specification in normalized_specifications
    )
end

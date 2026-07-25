# Immutable reviewed-reference records for reproducibility comparisons.

@enum ReferenceComparisonKind begin
    reference_exact
    reference_tolerance
end

const _REFERENCE_COMPARISON_STRINGS = Dict{ReferenceComparisonKind,String}(
    reference_exact => "exact",
    reference_tolerance => "tolerance",
)

stable_string(value::ReferenceComparisonKind) = _REFERENCE_COMPARISON_STRINGS[value]

"""Comparison policy for one retained metric in one validation case."""
struct ValidationMetricReferencePolicy
    case_id::Symbol
    metric_id::Symbol
    comparison::ReferenceComparisonKind
    absolute_tolerance::Union{Nothing,Real}
    relative_tolerance::Union{Nothing,Real}

    function ValidationMetricReferencePolicy(
        case_id,
        metric_id,
        comparison::ReferenceComparisonKind;
        absolute_tolerance=nothing,
        relative_tolerance=nothing,
    )
        for (label, tolerance) in (
            ("absolute_tolerance", absolute_tolerance),
            ("relative_tolerance", relative_tolerance),
        )
            if !isnothing(tolerance)
                tolerance isa Real || throw(ArgumentError("$label must be real."))
                isfinite(tolerance) && tolerance >= zero(tolerance) || throw(
                    ArgumentError("$label must be finite and nonnegative."),
                )
            end
        end
        comparison == reference_tolerance || (
            isnothing(absolute_tolerance) && isnothing(relative_tolerance)
        ) || throw(ArgumentError("Tolerances are only valid for tolerance comparison."))
        comparison == reference_exact || (
            !isnothing(absolute_tolerance) || !isnothing(relative_tolerance)
        ) || throw(ArgumentError(
            "Tolerance comparison requires an absolute or relative tolerance.",
        ))
        new(
            _validated_identifier(case_id, "case_id"),
            _validated_identifier(metric_id, "metric_id"),
            comparison,
            absolute_tolerance,
            relative_tolerance,
        )
    end
end

"""One immutable reviewed metric value and its declared comparison policy."""
struct ValidationMetricReference{T}
    case_id::Symbol
    metric_id::Symbol
    value::T
    comparison::ReferenceComparisonKind
    absolute_tolerance::Union{Nothing,Real}
    relative_tolerance::Union{Nothing,Real}

    function ValidationMetricReference(
        policy::ValidationMetricReferencePolicy,
        value,
    )
        retained = _retained_metric_value(value)
        if policy.comparison == reference_tolerance
            retained isa AbstractFloat || throw(ArgumentError(
                "Tolerance comparison requires a floating-point scalar metric.",
            ))
            isfinite(retained) || throw(ArgumentError(
                "Tolerance-comparison reference values must be finite.",
            ))
        end
        new{typeof(retained)}(
            policy.case_id,
            policy.metric_id,
            retained,
            policy.comparison,
            policy.absolute_tolerance,
            policy.relative_tolerance,
        )
    end
end

"""Compact immutable reviewed reference extracted from one validation suite."""
struct ValidationReferenceRecord
    suite_id::Symbol
    schema_version::String
    source_commit::String
    provenance::String
    metrics::Tuple{Vararg{ValidationMetricReference}}

    function ValidationReferenceRecord(
        suite_id,
        schema_version,
        source_commit,
        provenance,
        metrics,
    )
        normalized_metrics = Tuple(metrics)
        all(metric -> metric isa ValidationMetricReference, normalized_metrics) || throw(
            ArgumentError("metrics must contain ValidationMetricReference records."),
        )
        keys = map(metric -> (metric.case_id, metric.metric_id), normalized_metrics)
        length(keys) == length(unique(keys)) || throw(ArgumentError(
            "Reference metrics must contain unique case and metric identifiers.",
        ))
        new(
            _validated_identifier(suite_id, "suite_id"),
            _validated_version(schema_version, "schema_version"),
            _nonempty_string(source_commit, "source_commit"),
            _nonempty_string(provenance, "provenance"),
            normalized_metrics,
        )
    end
end

const _APPROVAL_DATE_PATTERN = r"^[0-9]{4}-[0-9]{2}-[0-9]{2}$"

function _validated_approval_date(value)
    date = _nonempty_string(value, "approval_date")
    occursin(_APPROVAL_DATE_PATTERN, date) || throw(ArgumentError(
        "approval_date must use ISO calendar-date form YYYY-MM-DD.",
    ))
    date
end

"""
Immutable scientific approval metadata wrapped around one retained observation.

`ValidationReferenceRecord` preserves the selected numerical evidence and
comparison policies. `ApprovedScientificReference` records the explicit human
scientific decision that makes that observation an authoritative future
comparison point. Construction performs validation only; it does not approve,
select, serialize, replace, or interpret a reference automatically.
"""
struct ApprovedScientificReference
    reference_id::String
    reference_schema_version::String
    observation::ValidationReferenceRecord
    benchmark_scope::String
    methodology::String
    reviewer::String
    approval_date::String
    approval_rationale::String
    known_limitations::Union{Nothing,String}

    function ApprovedScientificReference(
        reference_id,
        reference_schema_version,
        observation::ValidationReferenceRecord;
        benchmark_scope,
        methodology,
        reviewer,
        approval_date,
        approval_rationale,
        known_limitations=nothing,
    )
        normalized_limitations = isnothing(known_limitations) ?
            nothing :
            _nonempty_string(known_limitations, "known_limitations")
        new(
            _nonempty_string(reference_id, "reference_id"),
            _validated_version(reference_schema_version, "reference_schema_version"),
            observation,
            _nonempty_string(benchmark_scope, "benchmark_scope"),
            _nonempty_string(methodology, "methodology"),
            _nonempty_string(reviewer, "reviewer"),
            _validated_approval_date(approval_date),
            _nonempty_string(approval_rationale, "approval_rationale"),
            normalized_limitations,
        )
    end
end

function _metric_lookup(result::ValidationCaseResult, metric_id::Symbol)
    matches = filter(metric -> metric.metric_id == metric_id, result.metrics)
    isempty(matches) && throw(ArgumentError(
        "Case $(result.definition.case_id) does not contain metric $metric_id.",
    ))
    only(matches)
end

"""
    build_reference_record(suite, policies; source_commit, provenance)

Extract an ordered compact reference record from a completed suite. Policy order
is retained exactly and therefore defines deterministic reference ordering.
Reference generation is explicit and never writes or updates a file.
"""
function build_reference_record(
    suite::ValidationSuiteResult,
    policies;
    source_commit,
    provenance,
)
    normalized_policies = Tuple(policies)
    all(policy -> policy isa ValidationMetricReferencePolicy, normalized_policies) || throw(
        ArgumentError("policies must contain ValidationMetricReferencePolicy records."),
    )
    keys = map(policy -> (policy.case_id, policy.metric_id), normalized_policies)
    length(keys) == length(unique(keys)) || throw(ArgumentError(
        "Reference policies must contain unique case and metric identifiers.",
    ))
    cases = Dict(result.definition.case_id => result for result in suite.cases)
    references = map(normalized_policies) do policy
        haskey(cases, policy.case_id) || throw(ArgumentError(
            "Suite $(suite.suite_id) does not contain case $(policy.case_id).",
        ))
        metric = _metric_lookup(cases[policy.case_id], policy.metric_id)
        ValidationMetricReference(policy, metric.value)
    end
    ValidationReferenceRecord(
        suite.suite_id,
        suite.schema_version,
        source_commit,
        provenance,
        references,
    )
end

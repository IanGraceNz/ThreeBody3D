# Core schema-1 records and invariants. Criterion evaluation, serialization,
# presentation, and process execution are introduced in later V5-V1 stages.

@enum MetricKind begin
    metric_boolean
    metric_integer
    metric_numeric
    metric_status
    metric_text
    metric_sequence
end

@enum MetricScale begin
    scale_absolute
    scale_relative
    scale_dimensionless
    scale_dimensional
    scale_count
    scale_duration
end

@enum MetricRole begin
    role_acceptance
    role_diagnostic
    role_descriptive
    role_performance
end

@enum AggregationKind begin
    aggregation_none
    aggregation_initial
    aggregation_final
    aggregation_minimum
    aggregation_maximum
    aggregation_mean
    aggregation_rms
    aggregation_count
end

@enum CriterionRelation begin
    relation_less_than
    relation_less_than_or_equal
    relation_greater_than
    relation_greater_than_or_equal
    relation_equal
    relation_approximately_equal
    relation_finite
    relation_true
    relation_expected_status
end

@enum CriterionStatus begin
    criterion_pass
    criterion_fail
    criterion_error
end

@enum CriterionSeverity begin
    severity_required
    severity_advisory
end

@enum ExpectedExecutionOutcome begin
    expected_completed
    expected_stop
    expected_error
end

@enum ActualExecutionOutcome begin
    actual_completed
    actual_stopped
    actual_errored
    actual_missing_report
    actual_malformed_report
    actual_terminated
end

@enum ValidationCaseStatus begin
    case_pass
    case_fail
    case_error
end

@enum ValidationSuiteStatus begin
    suite_pass
    suite_fail
    suite_error
end

const _STABLE_ENUM_STRINGS = Dict{Enum,String}(
    metric_boolean => "boolean",
    metric_integer => "integer",
    metric_numeric => "numeric",
    metric_status => "status",
    metric_text => "text",
    metric_sequence => "sequence",
    scale_absolute => "absolute",
    scale_relative => "relative",
    scale_dimensionless => "dimensionless",
    scale_dimensional => "dimensional",
    scale_count => "count",
    scale_duration => "duration",
    role_acceptance => "acceptance",
    role_diagnostic => "diagnostic",
    role_descriptive => "descriptive",
    role_performance => "performance",
    aggregation_none => "none",
    aggregation_initial => "initial",
    aggregation_final => "final",
    aggregation_minimum => "minimum",
    aggregation_maximum => "maximum",
    aggregation_mean => "mean",
    aggregation_rms => "rms",
    aggregation_count => "count",
    relation_less_than => "less_than",
    relation_less_than_or_equal => "less_than_or_equal",
    relation_greater_than => "greater_than",
    relation_greater_than_or_equal => "greater_than_or_equal",
    relation_equal => "equal",
    relation_approximately_equal => "approximately_equal",
    relation_finite => "finite",
    relation_true => "true",
    relation_expected_status => "expected_status",
    criterion_pass => "pass",
    criterion_fail => "fail",
    criterion_error => "error",
    severity_required => "required",
    severity_advisory => "advisory",
    expected_completed => "completed",
    expected_stop => "stop",
    expected_error => "error",
    actual_completed => "completed",
    actual_stopped => "stopped",
    actual_errored => "errored",
    actual_missing_report => "missing_report",
    actual_malformed_report => "malformed_report",
    actual_terminated => "terminated",
    case_pass => "pass",
    case_fail => "fail",
    case_error => "error",
    suite_pass => "pass",
    suite_fail => "fail",
    suite_error => "error",
)

"""Return the schema-stable lowercase string for a validation enum value."""
stable_string(value::Enum) = get(
    _STABLE_ENUM_STRINGS,
    value,
) do
    throw(ArgumentError("No stable string mapping is defined for $(typeof(value)) value $value."))
end

const _IDENTIFIER_PATTERN = r"^[a-z][a-z0-9]*(?:_[a-z0-9]+)*$"
const _VERSION_PATTERN = r"^[0-9]+\.[0-9]+\.[0-9]+$"

function _validated_identifier(value, label::AbstractString)
    identifier = value isa Symbol ? value : Symbol(value)
    occursin(_IDENTIFIER_PATTERN, String(identifier)) || throw(
        ArgumentError("$label must use lowercase ASCII words separated by underscores."),
    )
    identifier
end

function _nonempty_string(value, label::AbstractString)
    text = String(value)
    isempty(strip(text)) && throw(ArgumentError("$label must not be empty."))
    text
end

function _validated_version(value, label::AbstractString)
    version = _nonempty_string(value, label)
    occursin(_VERSION_PATTERN, version) || throw(
        ArgumentError("$label must use major.minor.patch numeric form."),
    )
    version
end

function _validated_source_path(value)
    path = replace(_nonempty_string(value, "source_path"), '\\' => '/')
    startswith(path, "/") && throw(ArgumentError("source_path must be repository-relative."))
    occursin(r"^[A-Za-z]:/", path) && throw(
        ArgumentError("source_path must be repository-relative."),
    )
    components = split(path, '/')
    any(component -> component == "..", components) && throw(
        ArgumentError("source_path must not traverse outside the repository."),
    )
    any(isempty, components) && throw(ArgumentError("source_path contains an empty component."))
    join(components, '/')
end

function _unique_identifiers(values, label::AbstractString)
    length(values) == length(unique(values)) || throw(
        ArgumentError("$label must contain unique identifiers."),
    )
end

"""Stable metadata describing one registered validation case."""
struct ValidationCaseDefinition
    case_id::Symbol
    title::String
    description::String
    classifications::Tuple{Vararg{Symbol}}
    tags::Tuple{Vararg{Symbol}}
    source_path::String
    tiers::Tuple{Vararg{Symbol}}
    expected_outcome::ExpectedExecutionOutcome
    required::Bool
    definition_version::String
    provenance::Union{Nothing,String}

    function ValidationCaseDefinition(
        case_id,
        title,
        description,
        classifications,
        tags,
        source_path,
        tiers,
        expected_outcome::ExpectedExecutionOutcome,
        required::Bool,
        definition_version,
        provenance=nothing,
    )
        normalized_classifications = Tuple(
            _validated_identifier(value, "classification") for value in classifications
        )
        normalized_tags = Tuple(_validated_identifier(value, "tag") for value in tags)
        normalized_tiers = Tuple(_validated_identifier(value, "tier") for value in tiers)
        isempty(normalized_classifications) && throw(
            ArgumentError("At least one classification is required."),
        )
        isempty(normalized_tiers) && throw(ArgumentError("At least one tier is required."))
        _unique_identifiers(normalized_classifications, "classifications")
        _unique_identifiers(normalized_tags, "tags")
        _unique_identifiers(normalized_tiers, "tiers")

        new(
            _validated_identifier(case_id, "case_id"),
            _nonempty_string(title, "title"),
            _nonempty_string(description, "description"),
            normalized_classifications,
            normalized_tags,
            _validated_source_path(source_path),
            normalized_tiers,
            expected_outcome,
            required,
            _validated_version(definition_version, "definition_version"),
            isnothing(provenance) ? nothing : _nonempty_string(provenance, "provenance"),
        )
    end
end

"""Environment and provenance metadata retained with a validation report."""
struct ValidationEnvironment
    schema_version::String
    package_version::String
    repository_commit::Union{Nothing,String}
    repository_dirty::Union{Nothing,Bool}
    julia_version::String
    operating_system::String
    architecture::String
    thread_count::Int
    timestamp_utc::String

    function ValidationEnvironment(
        schema_version,
        package_version,
        repository_commit,
        repository_dirty,
        julia_version,
        operating_system,
        architecture,
        thread_count::Integer,
        timestamp_utc,
    )
        thread_count > 0 || throw(ArgumentError("thread_count must be positive."))
        new(
            _validated_version(schema_version, "schema_version"),
            _validated_version(package_version, "package_version"),
            isnothing(repository_commit) ? nothing : _nonempty_string(repository_commit, "repository_commit"),
            isnothing(repository_dirty) ? nothing : Bool(repository_dirty),
            _nonempty_string(julia_version, "julia_version"),
            _nonempty_string(operating_system, "operating_system"),
            _nonempty_string(architecture, "architecture"),
            Int(thread_count),
            _nonempty_string(timestamp_utc, "timestamp_utc"),
        )
    end
end

const _ParameterScalar = Union{Bool,Signed,Unsigned,AbstractFloat,Symbol,String}

function _supported_parameter_value(value)
    value isa _ParameterScalar || (
        (value isa AbstractVector || value isa Tuple) &&
        all(_supported_parameter_value, value)
    )
end

"""One ordered, case-specific configuration parameter."""
struct ValidationParameter{T}
    parameter_id::Symbol
    value::T

    function ValidationParameter(parameter_id, value)
        _supported_parameter_value(value) || throw(
            ArgumentError("Unsupported validation parameter value type $(typeof(value))."),
        )
        retained = value isa AbstractVector ? Tuple(value) : value
        new{typeof(retained)}(_validated_identifier(parameter_id, "parameter_id"), retained)
    end
end

"""Ordered numerical configuration used to reproduce one validation case."""
struct ValidationConfiguration
    solver::Union{Nothing,Symbol}
    absolute_tolerance::Union{Nothing,Real}
    relative_tolerance::Union{Nothing,Real}
    precision_bits::Union{Nothing,Int}
    time_interval::Union{Nothing,Tuple{Real,Real}}
    sampling::Union{Nothing,String}
    selected_pair::Union{Nothing,NTuple{2,Int}}
    thresholds::Tuple{Vararg{ValidationParameter}}
    seeds::Tuple{Vararg{UInt64}}
    parameters::Tuple{Vararg{ValidationParameter}}

    function ValidationConfiguration(;
        solver=nothing,
        absolute_tolerance=nothing,
        relative_tolerance=nothing,
        precision_bits=nothing,
        time_interval=nothing,
        sampling=nothing,
        selected_pair=nothing,
        thresholds=(),
        seeds=(),
        parameters=(),
    )
        normalized_solver = isnothing(solver) ? nothing : _validated_identifier(solver, "solver")
        for (label, value) in (("absolute_tolerance", absolute_tolerance), ("relative_tolerance", relative_tolerance))
            if !isnothing(value)
                value isa Real || throw(ArgumentError("$label must be real."))
                value >= zero(value) || throw(ArgumentError("$label must be nonnegative."))
            end
        end
        if !isnothing(precision_bits)
            precision_bits isa Integer || throw(ArgumentError("precision_bits must be an integer."))
            precision_bits > 0 || throw(ArgumentError("precision_bits must be positive."))
        end
        normalized_interval = if isnothing(time_interval)
            nothing
        else
            length(time_interval) == 2 || throw(ArgumentError("time_interval must contain two values."))
            first(time_interval) < last(time_interval) || throw(
                ArgumentError("time_interval must be strictly increasing."),
            )
            (first(time_interval), last(time_interval))
        end
        normalized_pair = if isnothing(selected_pair)
            nothing
        else
            length(selected_pair) == 2 || throw(ArgumentError("selected_pair must contain two indices."))
            pair = (Int(first(selected_pair)), Int(last(selected_pair)))
            all(index -> 1 <= index <= 3, pair) || throw(
                ArgumentError("selected_pair indices must lie in 1:3."),
            )
            pair[1] != pair[2] || throw(ArgumentError("selected_pair indices must differ."))
            pair
        end
        normalized_thresholds = Tuple(thresholds)
        normalized_parameters = Tuple(parameters)
        all(value -> value isa ValidationParameter, normalized_thresholds) || throw(
            ArgumentError("thresholds must contain ValidationParameter records."),
        )
        all(value -> value isa ValidationParameter, normalized_parameters) || throw(
            ArgumentError("parameters must contain ValidationParameter records."),
        )
        threshold_ids = map(value -> value.parameter_id, normalized_thresholds)
        parameter_ids = map(value -> value.parameter_id, normalized_parameters)
        _unique_identifiers(threshold_ids, "thresholds")
        _unique_identifiers(parameter_ids, "parameters")
        isempty(intersect(
            Set(threshold_ids),
            Set(parameter_ids),
        )) || throw(ArgumentError("threshold and parameter identifiers must not overlap."))
        normalized_seeds = Tuple(UInt64(seed) for seed in seeds)

        new(
            normalized_solver,
            absolute_tolerance,
            relative_tolerance,
            isnothing(precision_bits) ? nothing : Int(precision_bits),
            normalized_interval,
            isnothing(sampling) ? nothing : _nonempty_string(sampling, "sampling"),
            normalized_pair,
            normalized_thresholds,
            normalized_seeds,
            normalized_parameters,
        )
    end
end

abstract type AbstractValidationMetric end

function _supported_metric_scalar(value)
    value isa Bool || value isa Signed || value isa Unsigned ||
        value isa Float32 || value isa Float64 || value isa BigFloat ||
        value isa Symbol || value isa String
end

function _retained_metric_value(value)
    if _supported_metric_scalar(value)
        value
    elseif value isa AbstractVector || value isa Tuple
        all(_supported_metric_scalar, value) || throw(
            ArgumentError("Metric sequences must contain supported scalar values."),
        )
        Tuple(value)
    else
        throw(ArgumentError("Unsupported validation metric value type $(typeof(value))."))
    end
end

function _inferred_metric_kind(value)
    value isa Bool && return metric_boolean
    (value isa Signed || value isa Unsigned) && return metric_integer
    value isa AbstractFloat && return metric_numeric
    value isa Symbol && return metric_status
    value isa String && return metric_text
    value isa Tuple && return metric_sequence
    throw(ArgumentError("Cannot infer metric kind from $(typeof(value))."))
end

"""One immutable, typed scientific or descriptive validation measurement."""
struct ValidationMetric{T} <: AbstractValidationMetric
    metric_id::Symbol
    label::String
    value::T
    kind::MetricKind
    scale::MetricScale
    role::MetricRole
    aggregation::AggregationKind
    units::Union{Nothing,String}
    description::Union{Nothing,String}

    function ValidationMetric(
        metric_id,
        label,
        value;
        kind=nothing,
        scale::MetricScale=scale_dimensionless,
        role::MetricRole=role_diagnostic,
        aggregation::AggregationKind=aggregation_none,
        units=nothing,
        description=nothing,
    )
        retained = _retained_metric_value(value)
        inferred_kind = _inferred_metric_kind(retained)
        normalized_kind = isnothing(kind) ? inferred_kind : kind
        normalized_kind isa MetricKind || throw(ArgumentError("kind must be a MetricKind."))
        normalized_kind == inferred_kind || throw(
            ArgumentError("Metric kind $(stable_string(normalized_kind)) is inconsistent with value type $(typeof(retained))."),
        )
        new{typeof(retained)}(
            _validated_identifier(metric_id, "metric_id"),
            _nonempty_string(label, "label"),
            retained,
            normalized_kind,
            scale,
            role,
            aggregation,
            isnothing(units) ? nothing : _nonempty_string(units, "units"),
            isnothing(description) ? nothing : _nonempty_string(description, "description"),
        )
    end
end

"""A deterministic acceptance rule referring to one retained metric."""
struct AcceptanceCriterionSpecification
    criterion_id::Symbol
    label::String
    metric_id::Symbol
    relation::CriterionRelation
    expected_value::Any
    absolute_tolerance::Union{Nothing,Real}
    relative_tolerance::Union{Nothing,Real}
    severity::CriterionSeverity

    function AcceptanceCriterionSpecification(
        criterion_id,
        label,
        metric_id,
        relation::CriterionRelation;
        expected_value=nothing,
        absolute_tolerance=nothing,
        relative_tolerance=nothing,
        severity::CriterionSeverity=severity_required,
    )
        for (name, tolerance) in (("absolute_tolerance", absolute_tolerance), ("relative_tolerance", relative_tolerance))
            if !isnothing(tolerance)
                tolerance isa Real || throw(ArgumentError("$name must be real."))
                tolerance >= zero(tolerance) || throw(ArgumentError("$name must be nonnegative."))
            end
        end
        relation == relation_approximately_equal || (
            isnothing(absolute_tolerance) && isnothing(relative_tolerance)
        ) || throw(ArgumentError("Tolerances are only valid for approximate equality."))
        new(
            _validated_identifier(criterion_id, "criterion_id"),
            _nonempty_string(label, "label"),
            _validated_identifier(metric_id, "metric_id"),
            relation,
            expected_value,
            absolute_tolerance,
            relative_tolerance,
            severity,
        )
    end
end

"""A criterion specification paired with its retained evaluation outcome."""
struct AcceptanceCriterion
    specification::AcceptanceCriterionSpecification
    status::CriterionStatus
    message::Union{Nothing,String}

    function AcceptanceCriterion(
        specification::AcceptanceCriterionSpecification,
        status::CriterionStatus;
        message=nothing,
    )
        status == criterion_error && isnothing(message) && throw(
            ArgumentError("An errored criterion must retain an explanatory message."),
        )
        new(
            specification,
            status,
            isnothing(message) ? nothing : _nonempty_string(message, "message"),
        )
    end
end

"""Optional descriptive statistics reported by a numerical solver or controller."""
struct SolverStatistics
    accepted_steps::Union{Nothing,Int}
    rejected_steps::Union{Nothing,Int}
    rhs_evaluations::Union{Nothing,Int}
    saved_states::Union{Nothing,Int}
    elapsed_seconds::Union{Nothing,Float64}
    segment_count::Union{Nothing,Int}
    switch_count::Union{Nothing,Int}

    function SolverStatistics(;
        accepted_steps=nothing,
        rejected_steps=nothing,
        rhs_evaluations=nothing,
        saved_states=nothing,
        elapsed_seconds=nothing,
        segment_count=nothing,
        switch_count=nothing,
    )
        counts = (
            accepted_steps,
            rejected_steps,
            rhs_evaluations,
            saved_states,
            segment_count,
            switch_count,
        )
        all(value -> isnothing(value) || (value isa Integer && value >= 0), counts) || throw(
            ArgumentError("Solver-statistic counts must be nonnegative integers or nothing."),
        )
        if !isnothing(elapsed_seconds)
            elapsed_seconds isa Real || throw(ArgumentError("elapsed_seconds must be real."))
            isfinite(elapsed_seconds) && elapsed_seconds >= 0 || throw(
                ArgumentError("elapsed_seconds must be finite and nonnegative."),
            )
        end
        new(
            isnothing(accepted_steps) ? nothing : Int(accepted_steps),
            isnothing(rejected_steps) ? nothing : Int(rejected_steps),
            isnothing(rhs_evaluations) ? nothing : Int(rhs_evaluations),
            isnothing(saved_states) ? nothing : Int(saved_states),
            isnothing(elapsed_seconds) ? nothing : Float64(elapsed_seconds),
            isnothing(segment_count) ? nothing : Int(segment_count),
            isnothing(switch_count) ? nothing : Int(switch_count),
        )
    end
end

"""Actual execution state retained independently of scientific acceptance."""
struct ExecutionOutcome
    actual::ActualExecutionOutcome
    exit_code::Union{Nothing,Int}
    elapsed_seconds::Union{Nothing,Float64}
    summary::Union{Nothing,String}

    function ExecutionOutcome(
        actual::ActualExecutionOutcome;
        exit_code=nothing,
        elapsed_seconds=nothing,
        summary=nothing,
    )
        if !isnothing(elapsed_seconds)
            elapsed_seconds isa Real || throw(ArgumentError("elapsed_seconds must be real."))
            isfinite(elapsed_seconds) && elapsed_seconds >= 0 || throw(
                ArgumentError("elapsed_seconds must be finite and nonnegative."),
            )
        end
        actual in (actual_errored, actual_missing_report, actual_malformed_report, actual_terminated) &&
            isnothing(summary) && throw(
                ArgumentError("Abnormal execution outcomes must retain a summary."),
            )
        new(
            actual,
            isnothing(exit_code) ? nothing : Int(exit_code),
            isnothing(elapsed_seconds) ? nothing : Float64(elapsed_seconds),
            isnothing(summary) ? nothing : _nonempty_string(summary, "summary"),
        )
    end
end

function _execution_matches(expected::ExpectedExecutionOutcome, actual::ActualExecutionOutcome)
    (expected == expected_completed && actual == actual_completed) ||
    (expected == expected_stop && actual == actual_stopped) ||
    (expected == expected_error && actual == actual_errored)
end

function _derive_case_status(
    definition::ValidationCaseDefinition,
    execution::ExecutionOutcome,
    criteria,
)
    _execution_matches(definition.expected_outcome, execution.actual) || return case_error
    any(result -> result.specification.severity == severity_required && result.status == criterion_error, criteria) &&
        return case_error
    any(result -> result.specification.severity == severity_required && result.status == criterion_fail, criteria) &&
        return case_fail
    case_pass
end

"""Complete immutable structured result for one validation case."""
struct ValidationCaseResult
    definition::ValidationCaseDefinition
    environment::ValidationEnvironment
    configuration::ValidationConfiguration
    metrics::Tuple{Vararg{AbstractValidationMetric}}
    criteria::Tuple{Vararg{AcceptanceCriterion}}
    solver_statistics::Union{Nothing,SolverStatistics}
    execution::ExecutionOutcome
    status::ValidationCaseStatus

    function ValidationCaseResult(
        definition::ValidationCaseDefinition,
        environment::ValidationEnvironment,
        configuration::ValidationConfiguration,
        metrics,
        criteria,
        solver_statistics::Union{Nothing,SolverStatistics},
        execution::ExecutionOutcome,
    )
        normalized_metrics = Tuple(metrics)
        normalized_criteria = Tuple(criteria)
        all(metric -> metric isa AbstractValidationMetric, normalized_metrics) || throw(
            ArgumentError("metrics must contain validation metric records."),
        )
        all(criterion -> criterion isa AcceptanceCriterion, normalized_criteria) || throw(
            ArgumentError("criteria must contain AcceptanceCriterion records."),
        )
        metric_ids = map(metric -> metric.metric_id, normalized_metrics)
        criterion_ids = map(criterion -> criterion.specification.criterion_id, normalized_criteria)
        _unique_identifiers(metric_ids, "metrics")
        _unique_identifiers(criterion_ids, "criteria")
        available_metrics = Set(metric_ids)
        all(criterion -> criterion.specification.metric_id in available_metrics, normalized_criteria) || throw(
            ArgumentError("Every criterion must reference an existing metric."),
        )
        status = _derive_case_status(definition, execution, normalized_criteria)
        new(
            definition,
            environment,
            configuration,
            normalized_metrics,
            normalized_criteria,
            solver_statistics,
            execution,
            status,
        )
    end
end

function _derive_suite_status(cases)
    required_cases = filter(result -> result.definition.required, cases)
    any(result -> result.status == case_error, required_cases) && return suite_error
    any(result -> result.status == case_fail, required_cases) && return suite_fail
    suite_pass
end

"""Ordered immutable result for one complete validation-suite execution."""
struct ValidationSuiteResult
    suite_id::Symbol
    title::String
    schema_version::String
    environment::ValidationEnvironment
    cases::Tuple{Vararg{ValidationCaseResult}}
    status::ValidationSuiteStatus
    passed_count::Int
    failed_count::Int
    error_count::Int

    function ValidationSuiteResult(
        suite_id,
        title,
        schema_version,
        environment::ValidationEnvironment,
        cases,
    )
        normalized_cases = Tuple(cases)
        all(result -> result isa ValidationCaseResult, normalized_cases) || throw(
            ArgumentError("cases must contain ValidationCaseResult records."),
        )
        case_ids = map(result -> result.definition.case_id, normalized_cases)
        _unique_identifiers(case_ids, "cases")
        passed_count = count(result -> result.status == case_pass, normalized_cases)
        failed_count = count(result -> result.status == case_fail, normalized_cases)
        error_count = count(result -> result.status == case_error, normalized_cases)
        new(
            _validated_identifier(suite_id, "suite_id"),
            _nonempty_string(title, "title"),
            _validated_version(schema_version, "schema_version"),
            environment,
            normalized_cases,
            _derive_suite_status(normalized_cases),
            passed_count,
            failed_count,
            error_count,
        )
    end
end

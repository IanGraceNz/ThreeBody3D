using TOML

const VALIDATION_SCHEMA_IDENTITY = "threebody3d_validation"

_toml_string(value) = repr(String(value))

function _write_key_value(io::IO, key::AbstractString, value)
    print(io, key, " = ")
    if value isa AbstractString || value isa Symbol
        println(io, _toml_string(value))
    elseif value isa Bool || value isa Integer
        println(io, value)
    elseif value isa AbstractVector || value isa Tuple
        print(io, "[")
        for (index, item) in enumerate(value)
            index > 1 && print(io, ", ")
            if item isa AbstractString || item isa Symbol
                print(io, _toml_string(item))
            elseif item isa Bool || item isa Integer
                print(io, item)
            else
                throw(ArgumentError("Unsupported direct TOML sequence item type $(typeof(item))."))
            end
        end
        println(io, "]")
    else
        throw(ArgumentError("Unsupported direct TOML value type $(typeof(value))."))
    end
end

function _canonical_scalar(value)
    value isa Bool && return ("bool", string(value), nothing)
    value isa Int8 && return ("int8", string(value), nothing)
    value isa Int16 && return ("int16", string(value), nothing)
    value isa Int32 && return ("int32", string(value), nothing)
    value isa Int64 && return ("int64", string(value), nothing)
    value isa Int128 && return ("int128", string(value), nothing)
    value isa UInt8 && return ("uint8", string(value), nothing)
    value isa UInt16 && return ("uint16", string(value), nothing)
    value isa UInt32 && return ("uint32", string(value), nothing)
    value isa UInt64 && return ("uint64", string(value), nothing)
    value isa UInt128 && return ("uint128", string(value), nothing)
    value isa Float32 && return ("float32", repr(value), nothing)
    value isa Float64 && return ("float64", repr(value), nothing)
    value isa BigFloat && return ("bigfloat", string(value), precision(value))
    value isa Symbol && return ("symbol", String(value), nothing)
    value isa String && return ("string", value, nothing)
    throw(ArgumentError("Unsupported canonical scalar type $(typeof(value))."))
end

function _write_tagged_value(io::IO, value; prefix="value")
    if value isa Tuple
        _write_key_value(io, "$(prefix)_kind", "sequence")
        kinds = String[]
        texts = String[]
        precisions = String[]
        for item in value
            kind, text, precision_bits = _canonical_scalar(item)
            push!(kinds, kind)
            push!(texts, text)
            push!(precisions, isnothing(precision_bits) ? "" : string(precision_bits))
        end
        _write_key_value(io, "$(prefix)_item_kinds", kinds)
        _write_key_value(io, "$(prefix)_item_texts", texts)
        _write_key_value(io, "$(prefix)_item_precisions", precisions)
    else
        kind, text, precision_bits = _canonical_scalar(value)
        _write_key_value(io, "$(prefix)_kind", kind)
        _write_key_value(io, "$(prefix)_text", text)
        !isnothing(precision_bits) && _write_key_value(io, "$(prefix)_precision_bits", precision_bits)
    end
end

function _decode_scalar(kind::AbstractString, text::AbstractString, precision_bits=nothing)
    kind == "bool" && return text == "true" ? true : text == "false" ? false : throw(ArgumentError("Invalid Boolean text."))
    kind == "int8" && return parse(Int8, text)
    kind == "int16" && return parse(Int16, text)
    kind == "int32" && return parse(Int32, text)
    kind == "int64" && return parse(Int64, text)
    kind == "int128" && return parse(Int128, text)
    kind == "uint8" && return parse(UInt8, text)
    kind == "uint16" && return parse(UInt16, text)
    kind == "uint32" && return parse(UInt32, text)
    kind == "uint64" && return parse(UInt64, text)
    kind == "uint128" && return parse(UInt128, text)
    kind == "float32" && return parse(Float32, text)
    kind == "float64" && return parse(Float64, text)
    kind == "bigfloat" && return setprecision(Int(precision_bits)) do
        parse(BigFloat, text)
    end
    kind == "symbol" && return Symbol(text)
    kind == "string" && return String(text)
    throw(ArgumentError("Unknown canonical value kind $kind."))
end

function _read_tagged_value(table::AbstractDict; prefix="value")
    kind_key = "$(prefix)_kind"
    haskey(table, kind_key) || throw(ArgumentError("Missing $kind_key."))
    kind = table[kind_key]
    if kind == "sequence"
        kinds = get(table, "$(prefix)_item_kinds", nothing)
        texts = get(table, "$(prefix)_item_texts", nothing)
        precisions = get(table, "$(prefix)_item_precisions", nothing)
        (isnothing(kinds) || isnothing(texts) || isnothing(precisions)) && throw(ArgumentError("Incomplete sequence encoding."))
        length(kinds) == length(texts) == length(precisions) || throw(ArgumentError("Sequence encoding lengths differ."))
        return Tuple(_decode_scalar(kinds[i], texts[i], isempty(precisions[i]) ? nothing : parse(Int, precisions[i])) for i in eachindex(kinds))
    end
    text = get(table, "$(prefix)_text", nothing)
    isnothing(text) && throw(ArgumentError("Missing $(prefix)_text."))
    precision_bits = get(table, "$(prefix)_precision_bits", nothing)
    _decode_scalar(kind, text, precision_bits)
end

function _enum_from_string(::Type{T}, text::AbstractString) where {T<:Enum}
    matches = T[value for value in instances(T) if stable_string(value) == text]
    length(matches) == 1 || throw(ArgumentError("Unknown $(T) value $text."))
    only(matches)
end

function _write_environment(io::IO, environment::ValidationEnvironment, heading::AbstractString)
    println(io, "[$heading]")
    _write_key_value(io, "schema_version", environment.schema_version)
    _write_key_value(io, "package_version", environment.package_version)
    !isnothing(environment.repository_commit) && _write_key_value(io, "repository_commit", environment.repository_commit)
    !isnothing(environment.repository_dirty) && _write_key_value(io, "repository_dirty", environment.repository_dirty)
    _write_key_value(io, "julia_version", environment.julia_version)
    _write_key_value(io, "operating_system", environment.operating_system)
    _write_key_value(io, "architecture", environment.architecture)
    _write_key_value(io, "thread_count", environment.thread_count)
    _write_key_value(io, "timestamp_utc", environment.timestamp_utc)
    println(io)
end

function _write_definition(io::IO, definition::ValidationCaseDefinition, heading::AbstractString)
    println(io, "[$heading]")
    _write_key_value(io, "case_id", definition.case_id)
    _write_key_value(io, "title", definition.title)
    _write_key_value(io, "description", definition.description)
    _write_key_value(io, "classifications", definition.classifications)
    _write_key_value(io, "tags", definition.tags)
    _write_key_value(io, "source_path", definition.source_path)
    _write_key_value(io, "tiers", definition.tiers)
    _write_key_value(io, "expected_outcome", stable_string(definition.expected_outcome))
    _write_key_value(io, "required", definition.required)
    _write_key_value(io, "definition_version", definition.definition_version)
    !isnothing(definition.provenance) && _write_key_value(io, "provenance", definition.provenance)
    println(io)
end

function _write_parameter(io::IO, parameter::ValidationParameter, heading::AbstractString)
    println(io, "[[$heading]]")
    _write_key_value(io, "parameter_id", parameter.parameter_id)
    _write_tagged_value(io, parameter.value)
    println(io)
end

function _write_configuration(io::IO, configuration::ValidationConfiguration, heading::AbstractString)
    println(io, "[$heading]")
    !isnothing(configuration.solver) && _write_key_value(io, "solver", configuration.solver)
    !isnothing(configuration.absolute_tolerance) && _write_tagged_value(io, configuration.absolute_tolerance; prefix="absolute_tolerance")
    !isnothing(configuration.relative_tolerance) && _write_tagged_value(io, configuration.relative_tolerance; prefix="relative_tolerance")
    !isnothing(configuration.precision_bits) && _write_key_value(io, "precision_bits", configuration.precision_bits)
    if !isnothing(configuration.time_interval)
        _write_tagged_value(io, Tuple(configuration.time_interval); prefix="time_interval")
    end
    !isnothing(configuration.sampling) && _write_key_value(io, "sampling", configuration.sampling)
    !isnothing(configuration.selected_pair) && _write_key_value(io, "selected_pair", configuration.selected_pair)
    _write_key_value(io, "seeds", string.(configuration.seeds))
    println(io)
    for parameter in configuration.thresholds
        _write_parameter(io, parameter, "$heading.thresholds")
    end
    for parameter in configuration.parameters
        _write_parameter(io, parameter, "$heading.parameters")
    end
end

function _write_metric(io::IO, metric::ValidationMetric, heading::AbstractString)
    println(io, "[[$heading]]")
    _write_key_value(io, "metric_id", metric.metric_id)
    _write_key_value(io, "label", metric.label)
    _write_key_value(io, "kind", stable_string(metric.kind))
    _write_key_value(io, "scale", stable_string(metric.scale))
    _write_key_value(io, "role", stable_string(metric.role))
    _write_key_value(io, "aggregation", stable_string(metric.aggregation))
    !isnothing(metric.units) && _write_key_value(io, "units", metric.units)
    !isnothing(metric.description) && _write_key_value(io, "description", metric.description)
    _write_tagged_value(io, metric.value)
    println(io)
end

function _write_criterion(io::IO, criterion::AcceptanceCriterion, heading::AbstractString)
    specification = criterion.specification
    println(io, "[[$heading]]")
    _write_key_value(io, "criterion_id", specification.criterion_id)
    _write_key_value(io, "label", specification.label)
    _write_key_value(io, "metric_id", specification.metric_id)
    _write_key_value(io, "relation", stable_string(specification.relation))
    _write_key_value(io, "severity", stable_string(specification.severity))
    if !isnothing(specification.expected_value)
        _write_tagged_value(io, specification.expected_value; prefix="expected")
    end
    !isnothing(specification.absolute_tolerance) && _write_tagged_value(io, specification.absolute_tolerance; prefix="absolute_tolerance")
    !isnothing(specification.relative_tolerance) && _write_tagged_value(io, specification.relative_tolerance; prefix="relative_tolerance")
    _write_key_value(io, "status", stable_string(criterion.status))
    !isnothing(criterion.message) && _write_key_value(io, "message", criterion.message)
    println(io)
end

function _write_solver_statistics(io::IO, statistics::SolverStatistics, heading::AbstractString)
    println(io, "[$heading]")
    for name in fieldnames(SolverStatistics)
        value = getfield(statistics, name)
        isnothing(value) || _write_key_value(io, String(name), value isa Float64 ? repr(value) : value)
    end
    println(io)
end

function _write_execution(io::IO, execution::ExecutionOutcome, heading::AbstractString)
    println(io, "[$heading]")
    _write_key_value(io, "actual", stable_string(execution.actual))
    !isnothing(execution.exit_code) && _write_key_value(io, "exit_code", execution.exit_code)
    !isnothing(execution.elapsed_seconds) && _write_key_value(io, "elapsed_seconds", repr(execution.elapsed_seconds))
    !isnothing(execution.summary) && _write_key_value(io, "summary", execution.summary)
    println(io)
end

function _write_case_body(io::IO, result::ValidationCaseResult, prefix::AbstractString)
    _write_definition(io, result.definition, "$prefix.definition")
    _write_environment(io, result.environment, "$prefix.environment")
    _write_configuration(io, result.configuration, "$prefix.configuration")
    for metric in result.metrics
        _write_metric(io, metric, "$prefix.metrics")
    end
    for criterion in result.criteria
        _write_criterion(io, criterion, "$prefix.criteria")
    end
    !isnothing(result.solver_statistics) && _write_solver_statistics(io, result.solver_statistics, "$prefix.solver_statistics")
    _write_execution(io, result.execution, "$prefix.execution")
    println(io, "[$prefix.derived]")
    _write_key_value(io, "status", stable_string(result.status))
    println(io)
end

"""Write one case result in deterministic schema-1 TOML text."""
function write_case_report(io::IO, result::ValidationCaseResult)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "case")
    _write_key_value(io, "schema_version", result.environment.schema_version)
    println(io)
    _write_case_body(io, result, "case")
    nothing
end

"""Write one suite result in deterministic schema-1 TOML text."""
function write_suite_report(io::IO, result::ValidationSuiteResult)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "suite")
    _write_key_value(io, "schema_version", result.schema_version)
    _write_key_value(io, "suite_id", result.suite_id)
    _write_key_value(io, "title", result.title)
    println(io)
    _write_environment(io, result.environment, "environment")
    for case_result in result.cases
        println(io, "[[cases]]")
        println(io)
        _write_case_body(io, case_result, "cases")
    end
    println(io, "[derived]")
    _write_key_value(io, "status", stable_string(result.status))
    _write_key_value(io, "passed_count", result.passed_count)
    _write_key_value(io, "failed_count", result.failed_count)
    _write_key_value(io, "error_count", result.error_count)
    nothing
end

"""Write one reviewed reference record in deterministic schema-1 TOML text."""
function write_reference_record(io::IO, record::ValidationReferenceRecord)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "reference")
    _write_key_value(io, "schema_version", record.schema_version)
    _write_key_value(io, "suite_id", record.suite_id)
    _write_key_value(io, "source_commit", record.source_commit)
    _write_key_value(io, "provenance", record.provenance)
    println(io)
    for metric in record.metrics
        println(io, "[[metrics]]")
        _write_key_value(io, "case_id", metric.case_id)
        _write_key_value(io, "metric_id", metric.metric_id)
        _write_key_value(io, "comparison", stable_string(metric.comparison))
        _write_tagged_value(io, metric.value)
        !isnothing(metric.absolute_tolerance) && _write_tagged_value(
            io,
            metric.absolute_tolerance;
            prefix="absolute_tolerance",
        )
        !isnothing(metric.relative_tolerance) && _write_tagged_value(
            io,
            metric.relative_tolerance;
            prefix="relative_tolerance",
        )
        println(io)
    end
    nothing
end

"""Write one approved scientific reference in deterministic schema-1 TOML text."""
function write_approved_scientific_reference(
    io::IO,
    reference::ApprovedScientificReference,
)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "approved_scientific_reference")
    _write_key_value(io, "schema_version", reference.reference_schema_version)
    _write_key_value(io, "reference_id", reference.reference_id)
    _write_key_value(io, "benchmark_scope", reference.benchmark_scope)
    _write_key_value(io, "methodology", reference.methodology)
    _write_key_value(io, "reviewer", reference.reviewer)
    _write_key_value(io, "approval_date", reference.approval_date)
    _write_key_value(io, "approval_rationale", reference.approval_rationale)
    !isnothing(reference.known_limitations) &&
        _write_key_value(io, "known_limitations", reference.known_limitations)
    println(io)

    observation = reference.observation
    println(io, "[observation]")
    _write_key_value(io, "schema_version", observation.schema_version)
    _write_key_value(io, "suite_id", observation.suite_id)
    _write_key_value(io, "source_commit", observation.source_commit)
    _write_key_value(io, "provenance", observation.provenance)
    println(io)

    for metric in observation.metrics
        println(io, "[[observation.metrics]]")
        _write_key_value(io, "case_id", metric.case_id)
        _write_key_value(io, "metric_id", metric.metric_id)
        _write_key_value(io, "comparison", stable_string(metric.comparison))
        _write_tagged_value(io, metric.value)
        !isnothing(metric.absolute_tolerance) && _write_tagged_value(
            io,
            metric.absolute_tolerance;
            prefix="absolute_tolerance",
        )
        !isnothing(metric.relative_tolerance) && _write_tagged_value(
            io,
            metric.relative_tolerance;
            prefix="relative_tolerance",
        )
        println(io)
    end
    nothing
end

"""Write one deterministic reference-comparison report for CI artifacts."""
function write_reference_comparison(
    io::IO,
    comparison::ValidationSuiteReferenceComparison,
)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", "reference_comparison")
    _write_key_value(io, "schema_version", comparison.schema_version)
    _write_key_value(io, "suite_id", comparison.suite_id)
    _write_key_value(io, "reference_source_commit", comparison.reference_source_commit)
    _write_key_value(io, "reference_provenance", comparison.reference_provenance)
    _write_key_value(io, "status", stable_string(comparison.status))
    println(io)

    for case_result in comparison.cases
        println(io, "[[cases]]")
        _write_key_value(io, "case_id", case_result.case_id)
        _write_key_value(io, "status", stable_string(case_result.status))
        println(io)
        for metric in case_result.metrics
            println(io, "[[cases.metrics]]")
            _write_key_value(io, "case_id", metric.case_id)
            _write_key_value(io, "metric_id", metric.metric_id)
            _write_key_value(io, "comparison", stable_string(metric.comparison))
            _write_key_value(io, "status", stable_string(metric.status))
            _write_tagged_value(io, metric.reference_value; prefix="reference")
            _write_key_value(io, "observed_present", !isnothing(metric.observed_value))
            !isnothing(metric.observed_value) &&
                _write_tagged_value(io, metric.observed_value; prefix="observed")
            !isnothing(metric.absolute_difference) &&
                _write_tagged_value(io, metric.absolute_difference; prefix="absolute_difference")
            !isnothing(metric.allowed_difference) &&
                _write_tagged_value(io, metric.allowed_difference; prefix="allowed_difference")
            !isnothing(metric.message) && _write_key_value(io, "message", metric.message)
            println(io)
        end
    end
    nothing
end

function _report_text(writer, result)
    io = IOBuffer()
    writer(io, result)
    String(take!(io))
end

case_report_text(result::ValidationCaseResult) = _report_text(write_case_report, result)
suite_report_text(result::ValidationSuiteResult) = _report_text(write_suite_report, result)
reference_record_text(record::ValidationReferenceRecord) =
    _report_text(write_reference_record, record)
approved_scientific_reference_text(reference::ApprovedScientificReference) =
    _report_text(write_approved_scientific_reference, reference)
reference_comparison_text(comparison::ValidationSuiteReferenceComparison) =
    _report_text(write_reference_comparison, comparison)

function write_report_atomic(
    path::AbstractString,
    result::Union{
        ValidationCaseResult,
        ValidationSuiteResult,
        ValidationReferenceRecord,
        ApprovedScientificReference,
        ValidationSuiteReferenceComparison,
        PerformanceBenchmarkReport,
        PerformanceSuiteReport,
        InvestigationMeasurementSeries,
    },
)
    final_path = abspath(path)
    parent = dirname(final_path)
    isdir(parent) || mkpath(parent)
    temporary_path = final_path * ".tmp"
    isfile(temporary_path) && rm(temporary_path; force=true)
    try
        open(temporary_path, "w") do io
            if result isa ValidationCaseResult
                write_case_report(io, result)
            elseif result isa ValidationSuiteResult
                write_suite_report(io, result)
            elseif result isa ValidationReferenceRecord
                write_reference_record(io, result)
            elseif result isa ApprovedScientificReference
                write_approved_scientific_reference(io, result)
            elseif result isa ValidationSuiteReferenceComparison
                write_reference_comparison(io, result)
            elseif result isa PerformanceBenchmarkReport
                write_performance_benchmark(io, result)
            elseif result isa PerformanceSuiteReport
                write_performance_suite(io, result)
            else
                write_investigation_series(io, result)
            end
            flush(io)
        end
        mv(temporary_path, final_path; force=true)
    catch
        isfile(temporary_path) && rm(temporary_path; force=true)
        rethrow()
    end
    final_path
end

function _read_environment(table)
    ValidationEnvironment(
        table["schema_version"], table["package_version"], get(table, "repository_commit", nothing),
        get(table, "repository_dirty", nothing), table["julia_version"], table["operating_system"],
        table["architecture"], table["thread_count"], table["timestamp_utc"],
    )
end

function _read_definition(table)
    ValidationCaseDefinition(
        Symbol(table["case_id"]), table["title"], table["description"], Symbol.(table["classifications"]),
        Symbol.(table["tags"]), table["source_path"], Symbol.(table["tiers"]),
        _enum_from_string(ExpectedExecutionOutcome, table["expected_outcome"]), table["required"],
        table["definition_version"], get(table, "provenance", nothing),
    )
end

function _read_parameter(table)
    ValidationParameter(Symbol(table["parameter_id"]), _read_tagged_value(table))
end

function _read_configuration(table)
    ValidationConfiguration(
        solver=haskey(table, "solver") ? Symbol(table["solver"]) : nothing,
        absolute_tolerance=haskey(table, "absolute_tolerance_kind") ? _read_tagged_value(table; prefix="absolute_tolerance") : nothing,
        relative_tolerance=haskey(table, "relative_tolerance_kind") ? _read_tagged_value(table; prefix="relative_tolerance") : nothing,
        precision_bits=get(table, "precision_bits", nothing),
        time_interval=haskey(table, "time_interval_kind") ? _read_tagged_value(table; prefix="time_interval") : nothing,
        sampling=get(table, "sampling", nothing),
        selected_pair=haskey(table, "selected_pair") ? Tuple(Int.(table["selected_pair"])) : nothing,
        thresholds=Tuple(_read_parameter(value) for value in get(table, "thresholds", Any[])),
        seeds=Tuple(parse(UInt64, value) for value in get(table, "seeds", String[])),
        parameters=Tuple(_read_parameter(value) for value in get(table, "parameters", Any[])),
    )
end

function _read_metric(table)
    ValidationMetric(
        Symbol(table["metric_id"]), table["label"], _read_tagged_value(table);
        kind=_enum_from_string(MetricKind, table["kind"]),
        scale=_enum_from_string(MetricScale, table["scale"]),
        role=_enum_from_string(MetricRole, table["role"]),
        aggregation=_enum_from_string(AggregationKind, table["aggregation"]),
        units=get(table, "units", nothing), description=get(table, "description", nothing),
    )
end

function _read_criterion(table)
    specification = AcceptanceCriterionSpecification(
        Symbol(table["criterion_id"]), table["label"], Symbol(table["metric_id"]),
        _enum_from_string(CriterionRelation, table["relation"]);
        expected_value=haskey(table, "expected_kind") ? _read_tagged_value(table; prefix="expected") : nothing,
        absolute_tolerance=haskey(table, "absolute_tolerance_kind") ? _read_tagged_value(table; prefix="absolute_tolerance") : nothing,
        relative_tolerance=haskey(table, "relative_tolerance_kind") ? _read_tagged_value(table; prefix="relative_tolerance") : nothing,
        severity=_enum_from_string(CriterionSeverity, table["severity"]),
    )
    AcceptanceCriterion(
        specification, _enum_from_string(CriterionStatus, table["status"]);
        message=get(table, "message", nothing),
    )
end

function _read_solver_statistics(table)
    SolverStatistics(
        accepted_steps=get(table, "accepted_steps", nothing), rejected_steps=get(table, "rejected_steps", nothing),
        rhs_evaluations=get(table, "rhs_evaluations", nothing), saved_states=get(table, "saved_states", nothing),
        elapsed_seconds=haskey(table, "elapsed_seconds") ? parse(Float64, table["elapsed_seconds"]) : nothing,
        segment_count=get(table, "segment_count", nothing), switch_count=get(table, "switch_count", nothing),
    )
end

function _read_execution(table)
    ExecutionOutcome(
        _enum_from_string(ActualExecutionOutcome, table["actual"]);
        exit_code=get(table, "exit_code", nothing),
        elapsed_seconds=haskey(table, "elapsed_seconds") ? parse(Float64, table["elapsed_seconds"]) : nothing,
        summary=get(table, "summary", nothing),
    )
end

function _read_case_table(table)
    result = ValidationCaseResult(
        _read_definition(table["definition"]), _read_environment(table["environment"]),
        _read_configuration(table["configuration"]), Tuple(_read_metric(value) for value in get(table, "metrics", Any[])),
        Tuple(_read_criterion(value) for value in get(table, "criteria", Any[])),
        haskey(table, "solver_statistics") ? _read_solver_statistics(table["solver_statistics"]) : nothing,
        _read_execution(table["execution"]),
    )
    stored_status = _enum_from_string(ValidationCaseStatus, table["derived"]["status"])
    result.status == stored_status || throw(ArgumentError("Stored case status is inconsistent with derived status."))
    result
end

function _validate_report_header(data, expected_kind)
    get(data, "schema_identity", nothing) == VALIDATION_SCHEMA_IDENTITY || throw(ArgumentError("Unknown validation schema identity."))
    get(data, "report_kind", nothing) == expected_kind || throw(ArgumentError("Unexpected report kind."))
    version = get(data, "schema_version", nothing)
    isnothing(version) && throw(ArgumentError("Missing schema_version."))
    startswith(version, "1.") || throw(ArgumentError("Unsupported validation schema major version."))
end

function read_case_report(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "case")
    result = _read_case_table(data["case"])
    result.environment.schema_version == data["schema_version"] || throw(ArgumentError("Case schema versions differ."))
    result
end

function read_suite_report(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "suite")
    environment = _read_environment(data["environment"])
    cases = Tuple(_read_case_table(value) for value in get(data, "cases", Any[]))
    result = ValidationSuiteResult(Symbol(data["suite_id"]), data["title"], data["schema_version"], environment, cases)
    derived = data["derived"]
    result.status == _enum_from_string(ValidationSuiteStatus, derived["status"]) || throw(ArgumentError("Stored suite status is inconsistent with derived status."))
    result.passed_count == derived["passed_count"] || throw(ArgumentError("Stored passed_count is inconsistent."))
    result.failed_count == derived["failed_count"] || throw(ArgumentError("Stored failed_count is inconsistent."))
    result.error_count == derived["error_count"] || throw(ArgumentError("Stored error_count is inconsistent."))
    result
end

function _read_reference_metric(table)
    comparison = _enum_from_string(ReferenceComparisonKind, table["comparison"])
    policy = ValidationMetricReferencePolicy(
        Symbol(table["case_id"]),
        Symbol(table["metric_id"]),
        comparison;
        absolute_tolerance=haskey(table, "absolute_tolerance_kind") ?
            _read_tagged_value(table; prefix="absolute_tolerance") : nothing,
        relative_tolerance=haskey(table, "relative_tolerance_kind") ?
            _read_tagged_value(table; prefix="relative_tolerance") : nothing,
    )
    ValidationMetricReference(policy, _read_tagged_value(table))
end

"""Read and validate one deterministic reviewed-reference TOML report."""
function read_reference_record(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "reference")
    ValidationReferenceRecord(
        Symbol(data["suite_id"]),
        data["schema_version"],
        data["source_commit"],
        data["provenance"],
        Tuple(_read_reference_metric(value) for value in get(data, "metrics", Any[])),
    )
end
"""Read and validate one deterministic approved-scientific-reference TOML report."""
function read_approved_scientific_reference(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "approved_scientific_reference")
    observation_table = get(data, "observation", nothing)
    isnothing(observation_table) && throw(ArgumentError("Missing approved-reference observation."))
    required_observation_fields = (
        "suite_id",
        "schema_version",
        "source_commit",
        "provenance",
    )
    all(field -> haskey(observation_table, field), required_observation_fields) || throw(
        ArgumentError("Approved-reference observation is missing required fields."),
    )
    observation = ValidationReferenceRecord(
        Symbol(observation_table["suite_id"]),
        observation_table["schema_version"],
        observation_table["source_commit"],
        observation_table["provenance"],
        Tuple(
            _read_reference_metric(value)
            for value in get(observation_table, "metrics", Any[])
        ),
    )
    ApprovedScientificReference(
        data["reference_id"],
        data["schema_version"],
        observation;
        benchmark_scope=data["benchmark_scope"],
        methodology=data["methodology"],
        reviewer=data["reviewer"],
        approval_date=data["approval_date"],
        approval_rationale=data["approval_rationale"],
        known_limitations=get(data, "known_limitations", nothing),
    )
end

function _read_reference_comparison_metric(table)
    observed_present = get(table, "observed_present", false)
    observed = observed_present ? _read_tagged_value(table; prefix="observed") : nothing
    ValidationMetricReferenceComparison(
        Symbol(table["case_id"]),
        Symbol(table["metric_id"]),
        _enum_from_string(ReferenceComparisonKind, table["comparison"]),
        _enum_from_string(ReferenceComparisonStatus, table["status"]),
        _read_tagged_value(table; prefix="reference"),
        observed;
        absolute_difference=haskey(table, "absolute_difference_kind") ?
            _read_tagged_value(table; prefix="absolute_difference") : nothing,
        allowed_difference=haskey(table, "allowed_difference_kind") ?
            _read_tagged_value(table; prefix="allowed_difference") : nothing,
        message=get(table, "message", nothing),
    )
end

function _read_reference_comparison_case(table)
    result = ValidationCaseReferenceComparison(
        Symbol(table["case_id"]),
        Tuple(_read_reference_comparison_metric(value) for value in get(table, "metrics", Any[])),
    )
    stored_status = _enum_from_string(ReferenceComparisonStatus, table["status"])
    result.status == stored_status || throw(ArgumentError(
        "Stored reference case status is inconsistent with derived status.",
    ))
    result
end

"""Read and validate one deterministic reference-comparison TOML report."""
function read_reference_comparison(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, "reference_comparison")
    result = ValidationSuiteReferenceComparison(
        Symbol(data["suite_id"]),
        data["schema_version"],
        data["reference_source_commit"],
        data["reference_provenance"],
        Tuple(_read_reference_comparison_case(value) for value in get(data, "cases", Any[])),
    )
    stored_status = _enum_from_string(ReferenceComparisonStatus, data["status"])
    result.status == stored_status || throw(ArgumentError(
        "Stored reference suite status is inconsistent with derived status.",
    ))
    result
end

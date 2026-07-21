# Shared standalone/child-process reporting protocol for structured validation cases.

const VALIDATION_REPORT_ENV = "THREEBODY3D_VALIDATION_REPORT"
const VALIDATION_CASE_ID_ENV = "THREEBODY3D_VALIDATION_CASE_ID"
const VALIDATION_SCHEMA_VERSION_ENV = "THREEBODY3D_VALIDATION_SCHEMA_VERSION"

"""Resolved invocation settings for one validation-case script."""
struct ValidationCaseProtocol
    report_path::Union{Nothing,String}
    requested_case_id::Union{Nothing,Symbol}
    requested_schema_version::Union{Nothing,String}
end

_protocol_value(environment, name) = begin
    value = get(environment, name, nothing)
    isnothing(value) && return nothing
    text = String(value)
    isempty(strip(text)) && throw(ArgumentError("Environment variable $name must not be empty."))
    text
end

"""
    resolve_case_protocol(definition, schema_version; environment=ENV)

Read and validate the reserved environment-variable protocol for a case script.
With no reserved variables present, return standalone settings and do not request
structured output. When a report path is requested, the caller must also provide
matching case and schema identifiers.
"""
function resolve_case_protocol(
    definition::ValidationCaseDefinition,
    schema_version;
    environment=ENV,
)
    expected_schema_version = _validated_version(schema_version, "schema_version")
    report_path = _protocol_value(environment, VALIDATION_REPORT_ENV)
    case_id_text = _protocol_value(environment, VALIDATION_CASE_ID_ENV)
    schema_version_text = _protocol_value(environment, VALIDATION_SCHEMA_VERSION_ENV)

    if isnothing(report_path)
        isnothing(case_id_text) || throw(ArgumentError(
            "$VALIDATION_CASE_ID_ENV requires $VALIDATION_REPORT_ENV.",
        ))
        isnothing(schema_version_text) || throw(ArgumentError(
            "$VALIDATION_SCHEMA_VERSION_ENV requires $VALIDATION_REPORT_ENV.",
        ))
        return ValidationCaseProtocol(nothing, nothing, nothing)
    end

    isnothing(case_id_text) && throw(ArgumentError(
        "$VALIDATION_CASE_ID_ENV is required when $VALIDATION_REPORT_ENV is set.",
    ))
    isnothing(schema_version_text) && throw(ArgumentError(
        "$VALIDATION_SCHEMA_VERSION_ENV is required when $VALIDATION_REPORT_ENV is set.",
    ))

    requested_case_id = _validated_identifier(case_id_text, "requested case_id")
    requested_case_id == definition.case_id || throw(ArgumentError(
        "Requested validation case $(requested_case_id) does not match $(definition.case_id).",
    ))
    requested_schema_version = _validated_version(
        schema_version_text,
        "requested schema_version",
    )
    requested_schema_version == expected_schema_version || throw(ArgumentError(
        "Requested validation schema version $requested_schema_version does not match $expected_schema_version.",
    ))

    ValidationCaseProtocol(
        abspath(report_path),
        requested_case_id,
        requested_schema_version,
    )
end

"""Return whether the invocation requested a structured case report."""
report_requested(protocol::ValidationCaseProtocol) = !isnothing(protocol.report_path)

function _validate_protocol_result(
    protocol::ValidationCaseProtocol,
    result::ValidationCaseResult,
)
    report_requested(protocol) || return nothing
    result.definition.case_id == protocol.requested_case_id || throw(ArgumentError(
        "Result case $(result.definition.case_id) does not match the requested case $(protocol.requested_case_id).",
    ))
    result.environment.schema_version == protocol.requested_schema_version || throw(ArgumentError(
        "Result schema version $(result.environment.schema_version) does not match the requested schema version $(protocol.requested_schema_version).",
    ))
    nothing
end

"""
    write_requested_report(protocol, result)

Atomically write `result` only when the invocation requested a report. Return
the absolute report path, or `nothing` for direct standalone execution.
"""
function write_requested_report(
    protocol::ValidationCaseProtocol,
    result::ValidationCaseResult,
)
    report_requested(protocol) || return nothing
    _validate_protocol_result(protocol, result)
    write_report_atomic(something(protocol.report_path), result)
end

"""Map a retained case result to shell/CI-compatible exit semantics."""
validation_exit_code(result::ValidationCaseResult) = result.status == case_pass ? 0 : 1

"""Map a retained suite result to shell/CI-compatible exit semantics."""
validation_exit_code(result::ValidationSuiteResult) = result.status == suite_pass ? 0 : 1

"""
    publish_case_result(protocol, result; io=stdout, render=true)

Render and optionally write a completed case result, then return the exit code
the script should use. This function does not call `exit`, so it remains simple
to test and embed in case scripts.
"""
function publish_case_result(
    protocol::ValidationCaseProtocol,
    result::ValidationCaseResult;
    io::IO=stdout,
    render::Bool=true,
)
    _validate_protocol_result(protocol, result)
    render && render_case_result(io, result)
    write_requested_report(protocol, result)
    validation_exit_code(result)
end

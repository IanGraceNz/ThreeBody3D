# Shared standalone/child-process reporting protocol for performance benchmarks.

const PERFORMANCE_REPORT_ENV = "THREEBODY3D_PERFORMANCE_REPORT"
const PERFORMANCE_BENCHMARK_ID_ENV = "THREEBODY3D_PERFORMANCE_BENCHMARK_ID"
const PERFORMANCE_SCHEMA_VERSION_ENV = "THREEBODY3D_PERFORMANCE_SCHEMA_VERSION"

"""Resolved invocation settings for one performance benchmark script."""
struct PerformanceBenchmarkProtocol
    report_path::Union{Nothing,String}
    requested_benchmark_id::Union{Nothing,Symbol}
    requested_schema_version::Union{Nothing,String}
end

"""Resolve and validate the reserved child-process environment protocol."""
function resolve_performance_protocol(
    definition::PerformanceBenchmarkDefinition,
    schema_version;
    environment=ENV,
)
    expected_schema_version = _validated_version(schema_version, "schema_version")
    report_path = _protocol_value(environment, PERFORMANCE_REPORT_ENV)
    benchmark_id_text = _protocol_value(environment, PERFORMANCE_BENCHMARK_ID_ENV)
    schema_version_text = _protocol_value(environment, PERFORMANCE_SCHEMA_VERSION_ENV)

    if isnothing(report_path)
        isnothing(benchmark_id_text) || throw(ArgumentError(
            "$PERFORMANCE_BENCHMARK_ID_ENV requires $PERFORMANCE_REPORT_ENV.",
        ))
        isnothing(schema_version_text) || throw(ArgumentError(
            "$PERFORMANCE_SCHEMA_VERSION_ENV requires $PERFORMANCE_REPORT_ENV.",
        ))
        return PerformanceBenchmarkProtocol(nothing, nothing, nothing)
    end

    isnothing(benchmark_id_text) && throw(ArgumentError(
        "$PERFORMANCE_BENCHMARK_ID_ENV is required when $PERFORMANCE_REPORT_ENV is set.",
    ))
    isnothing(schema_version_text) && throw(ArgumentError(
        "$PERFORMANCE_SCHEMA_VERSION_ENV is required when $PERFORMANCE_REPORT_ENV is set.",
    ))

    requested_benchmark_id = _validated_identifier(benchmark_id_text, "requested benchmark_id")
    requested_benchmark_id == definition.benchmark_id || throw(ArgumentError(
        "Requested performance benchmark $requested_benchmark_id does not match $(definition.benchmark_id).",
    ))
    requested_schema_version = _validated_version(schema_version_text, "requested schema_version")
    requested_schema_version == expected_schema_version || throw(ArgumentError(
        "Requested performance schema version $requested_schema_version does not match $expected_schema_version.",
    ))

    PerformanceBenchmarkProtocol(abspath(report_path), requested_benchmark_id, requested_schema_version)
end

performance_report_requested(protocol::PerformanceBenchmarkProtocol) = !isnothing(protocol.report_path)

function _validate_performance_protocol_result(
    protocol::PerformanceBenchmarkProtocol,
    report::PerformanceBenchmarkReport,
)
    performance_report_requested(protocol) || return nothing
    report.definition.benchmark_id == protocol.requested_benchmark_id || throw(ArgumentError(
        "Report benchmark $(report.definition.benchmark_id) does not match the requested benchmark $(protocol.requested_benchmark_id).",
    ))
    report.environment.schema_version == protocol.requested_schema_version || throw(ArgumentError(
        "Report schema version $(report.environment.schema_version) does not match the requested schema version $(protocol.requested_schema_version).",
    ))
    nothing
end

function write_requested_performance_report(
    protocol::PerformanceBenchmarkProtocol,
    report::PerformanceBenchmarkReport,
)
    performance_report_requested(protocol) || return nothing
    _validate_performance_protocol_result(protocol, report)
    write_report_atomic(something(protocol.report_path), report)
end

performance_exit_code(report::PerformanceBenchmarkReport) =
    report.execution.actual == actual_completed ? 0 : 1

function publish_performance_report(
    protocol::PerformanceBenchmarkProtocol,
    report::PerformanceBenchmarkReport;
    io::IO=stdout,
    render::Bool=true,
)
    _validate_performance_protocol_result(protocol, report)
    render && render_performance_benchmark(io, report)
    write_requested_performance_report(protocol, report)
    performance_exit_code(report)
end

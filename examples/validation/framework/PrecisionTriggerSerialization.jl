# Deterministic TOML persistence for the conditional precision-trigger decision.

const PRECISION_TRIGGER_REPORT_KIND = "figure_eight_precision_trigger_assessment"

function _write_trigger_optional(io, name, value)
    _write_key_value(io, "$(name)_present", !isnothing(value))
    isnothing(value) || _write_tagged_value(io, value; prefix=String(name))
end

function _read_trigger_optional(table, name)
    present = get(table, "$(name)_present", nothing)
    present isa Bool || throw(ArgumentError("Missing or malformed optional trigger presence flag."))
    present ? _read_tagged_value(table; prefix=String(name)) : nothing
end

function write_figure_eight_precision_trigger(io::IO,
    assessment::FigureEightPrecisionTriggerAssessment)
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", PRECISION_TRIGGER_REPORT_KIND)
    _write_key_value(io, "schema_version", assessment.schema_version)
    _write_key_value(io, "source_series_id", assessment.source_series_id)
    _write_key_value(io, "source_definition_version", assessment.source_definition_version)
    _write_key_value(io, "point_1e12_id", assessment.point_1e12_id)
    _write_key_value(io, "point_1e13_id", assessment.point_1e13_id)
    _write_key_value(io, "status", assessment.status)
    _write_key_value(io, "summary", assessment.summary)
    _write_key_value(io, "energy_improvement_unbounded",
        assessment.energy_improvement_unbounded)
    for name in (:periodicity_error_1e12, :periodicity_error_1e13,
        :periodicity_change_factor, :periodicity_condition, :energy_drift_1e12,
        :energy_drift_1e13, :energy_improvement_factor, :energy_condition)
        _write_trigger_optional(io, name, getfield(assessment, name))
    end
    println(io)
    _write_environment(io, assessment.source_environment, "source_environment")
    _write_execution(io, assessment.point_1e12_execution, "point_1e12_execution")
    _write_execution(io, assessment.point_1e13_execution, "point_1e13_execution")
    nothing
end

figure_eight_precision_trigger_text(assessment::FigureEightPrecisionTriggerAssessment) =
    _report_text(write_figure_eight_precision_trigger, assessment)

function read_figure_eight_precision_trigger(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, PRECISION_TRIGGER_REPORT_KIND)
    environment = _read_environment(data["source_environment"])
    FigureEightPrecisionTriggerAssessment(data["schema_version"],
        Symbol(data["source_series_id"]), data["source_definition_version"], environment,
        Symbol(data["point_1e12_id"]), Symbol(data["point_1e13_id"]),
        _read_execution(data["point_1e12_execution"]),
        _read_execution(data["point_1e13_execution"]),
        _read_trigger_optional(data, :periodicity_error_1e12),
        _read_trigger_optional(data, :periodicity_error_1e13),
        _read_trigger_optional(data, :periodicity_change_factor),
        _read_trigger_optional(data, :periodicity_condition),
        _read_trigger_optional(data, :energy_drift_1e12),
        _read_trigger_optional(data, :energy_drift_1e13),
        _read_trigger_optional(data, :energy_improvement_factor),
        data["energy_improvement_unbounded"],
        _read_trigger_optional(data, :energy_condition), Symbol(data["status"]),
        data["summary"])
end

function write_figure_eight_precision_trigger_atomic(path::AbstractString,
    assessment::FigureEightPrecisionTriggerAssessment)
    final_path = abspath(path)
    isdir(dirname(final_path)) || mkpath(dirname(final_path))
    temporary_path = final_path * ".tmp"
    isfile(temporary_path) && rm(temporary_path; force=true)
    try
        open(temporary_path, "w") do io
            write_figure_eight_precision_trigger(io, assessment)
            flush(io)
        end
        mv(temporary_path, final_path; force=true)
    catch
        isfile(temporary_path) && rm(temporary_path; force=true)
        rethrow()
    end
    final_path
end

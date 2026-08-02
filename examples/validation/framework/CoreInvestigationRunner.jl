# Controlled Stage I2-B orchestration for the approved core experiments.

const CORE_INVESTIGATION_SERIES_ORDER = (
    (:tolerance, :figure_eight, :tsit5),
    (:tolerance, :figure_eight, :vern9),
    (:tolerance, :hierarchical_triple, :tsit5),
    (:tolerance, :hierarchical_triple, :vern9),
    (:duration, :figure_eight, nothing),
    (:duration, :hierarchical_triple, nothing),
    (:diagnostic_sampling, :figure_eight, nothing),
    (:diagnostic_sampling, :hierarchical_triple, nothing),
)

const CORE_INVESTIGATION_FILENAMES = (
    figure_eight_tsit5_tolerance="figure_eight_tsit5_tolerance.toml",
    figure_eight_vern9_tolerance="figure_eight_vern9_tolerance.toml",
    hierarchical_triple_tsit5_tolerance="hierarchical_triple_tsit5_tolerance.toml",
    hierarchical_triple_vern9_tolerance="hierarchical_triple_vern9_tolerance.toml",
    figure_eight_duration="figure_eight_duration.toml",
    hierarchical_triple_duration="hierarchical_triple_duration.toml",
    figure_eight_diagnostic_sampling="figure_eight_diagnostic_sampling.toml",
    hierarchical_triple_diagnostic_sampling="hierarchical_triple_diagnostic_sampling.toml",
    figure_eight_precision_confirmation="figure_eight_precision_confirmation.toml",
)

const CORE_PRECISION_TRIGGER_FILENAME = "figure_eight_precision_trigger.toml"
const CORE_OPERATIONAL_EVIDENCE_DIRECTORY = "operational_evidence"

struct CoreInvestigationWorkflowFailure
    label::Symbol
    outcome::ActualExecutionOutcome
    exit_code::Union{Nothing,Int}
    message::String
    raw_report_path::Union{Nothing,String}
    diagnostic_path::Union{Nothing,String}
end

struct CoreInvestigationWorkflowResult
    series::Tuple{Vararg{InvestigationMeasurementSeries}}
    trigger::Union{Nothing,FigureEightPrecisionTriggerAssessment}
    report_paths::Tuple{Vararg{String}}
    failures::Tuple{Vararg{CoreInvestigationWorkflowFailure}}
    exit_code::Int
end

function _core_series_id(kind, family, algorithm=nothing)
    kind == :tolerance && return Symbol(family, :_, algorithm, :_tolerance)
    Symbol(family, :_, kind)
end

function _run_core_tolerance_series(family, algorithm, environment, directory;
    performance_runner=run_performance_suite)
    configurations = Tuple(core_tolerance_configuration(family, algorithm, value)
        for value in CORE_TOLERANCE_VALUES)
    attempts = Tuple(attempt_core_tolerance_experiment(configuration)
        for configuration in configurations)
    entries = Tuple(core_tolerance_performance_entry(configuration)
        for configuration in configurations)
    performance = performance_runner(entries; environment,
        report_directory=joinpath(directory, "performance"))
    core_tolerance_investigation_series(performance.suite, attempts)
end

function _run_core_duration_sampling_series(kind, family, environment, directory;
    performance_runner=run_performance_suite)
    values = _core_duration_sampling_values(kind, family)
    configurations = Tuple(core_duration_sampling_configuration(kind, family, value)
        for value in values)
    attempts = Tuple(attempt_core_benchmark_observation(configuration)
        for configuration in configurations)
    entries = Tuple(core_duration_sampling_performance_entry(configuration)
        for configuration in configurations)
    performance = performance_runner(entries; environment,
        report_directory=joinpath(directory, "performance"))
    core_duration_sampling_investigation_series(performance.suite, attempts)
end

function _run_core_precision_series(assessment, environment, directory;
    performance_runner=run_performance_suite)
    configurations = Tuple(figure_eight_precision_configuration(bits)
        for bits in FIGURE_EIGHT_PRECISION_BITS)
    attempts = Tuple(attempt_figure_eight_precision(configuration)
        for configuration in configurations)
    entries = Tuple(figure_eight_precision_performance_entry(configuration)
        for configuration in configurations)
    performance = performance_runner(entries; environment,
        report_directory=joinpath(directory, "performance"))
    figure_eight_precision_investigation_series(assessment, performance.suite, attempts)
end

_owned_series_path(directory, series_id) =
    joinpath(directory, getproperty(CORE_INVESTIGATION_FILENAMES, series_id))
_owned_series_filename(series_id) = getproperty(CORE_INVESTIGATION_FILENAMES, series_id)
_owned_trigger_path(directory) = joinpath(directory, CORE_PRECISION_TRIGGER_FILENAME)

function _remove_owned_file(path)
    isfile(path) && rm(path; force=true)
    nothing
end

function _evidence_directory(directory)
    joinpath(directory, CORE_OPERATIONAL_EVIDENCE_DIRECTORY)
end

function _clear_owned_evidence(directory, label)
    evidence_directory = _evidence_directory(directory)
    isdir(evidence_directory) || return nothing
    prefix = string(label, "__")
    for name in readdir(evidence_directory)
        legacy = name == string(label, ".txt") ||
            (label == :precision_trigger && name == "precision_trigger_or_series.txt")
        (startswith(name, prefix) || legacy) || continue
        path = joinpath(evidence_directory, name)
        isfile(path) && rm(path; force=true)
    end
    nothing
end

function _copy_operational_report(source, destination)
    isfile(source) || return nothing
    isdir(dirname(destination)) || mkpath(dirname(destination))
    temporary = destination * ".tmp"
    isfile(temporary) && rm(temporary; force=true)
    try
        open(source, "r") do input
            open(temporary, "w") do output
                write(output, read(input))
                flush(output)
            end
        end
        mv(temporary, destination; force=true)
    catch
        isfile(temporary) && rm(temporary; force=true)
        rethrow()
    end
    abspath(destination)
end

function _retain_exception_diagnostic(directory, label, error)
    message = sprint(showerror, error)
    evidence_directory = _evidence_directory(directory)
    isdir(evidence_directory) || mkpath(evidence_directory)
    path = joinpath(evidence_directory, string(label, "__exception.txt"))
    temporary = path * ".tmp"
    isfile(temporary) && rm(temporary; force=true)
    try
        open(temporary, "w") do io
            println(io, message)
            flush(io)
        end
        mv(temporary, path; force=true)
        CoreInvestigationWorkflowFailure(label, actual_errored, nothing, message,
            nothing, abspath(path))
    catch
        isfile(temporary) && rm(temporary; force=true)
        CoreInvestigationWorkflowFailure(label, actual_errored, nothing, message, nothing, nothing)
    end
end

function _execution_message(execution)
    isnothing(execution.summary) ?
        "Operational execution failed without a child summary." : execution.summary
end

function _point_failures(series_id, point, work_directory, output_directory)
    failures = CoreInvestigationWorkflowFailure[]
    performance = point.performance_report
    performance_execution = isnothing(performance) ? nothing : performance.execution
    if !isnothing(performance_execution) && performance_execution.actual in
        (actual_errored, actual_malformed_report, actual_missing_report)
        benchmark_id = performance.definition.benchmark_id
        label = Symbol(series_id, :__, benchmark_id, :__performance)
        raw_path = nothing
        if performance_execution.actual == actual_malformed_report
            source = joinpath(work_directory, "performance",
                string(benchmark_id, ".toml"))
            destination = joinpath(_evidence_directory(output_directory),
                string(label, "__malformed.toml"))
            raw_path = _copy_operational_report(source, destination)
        end
        push!(failures, CoreInvestigationWorkflowFailure(label,
            performance_execution.actual, performance_execution.exit_code,
            _execution_message(performance_execution), raw_path, nothing))
    end
    direct_is_error = point.execution.actual == actual_errored
    repeats_performance = !isnothing(performance_execution) &&
        _record_fields_equal(point.execution, performance_execution)
    if direct_is_error && !repeats_performance
        label = Symbol(series_id, :__, point.point_id, :__direct)
        push!(failures, CoreInvestigationWorkflowFailure(label,
            point.execution.actual, point.execution.exit_code,
            _execution_message(point.execution), nothing, nothing))
    end
    failures
end

function _series_operational_failures(series, work_directory, output_directory)
    failures = CoreInvestigationWorkflowFailure[]
    for point in series.points
        append!(failures,
            _point_failures(series.series_id, point, work_directory, output_directory))
    end
    failures
end

function _validate_core_workflow_series(series, series_id, environment)
    series isa InvestigationMeasurementSeries || throw(ArgumentError(
        "Core series runner did not return an InvestigationMeasurementSeries."))
    series.series_id == series_id || throw(ArgumentError(
        "Core series runner returned $(series.series_id), expected $series_id."))
    all(point -> _record_fields_equal(point.environment, environment), series.points) ||
        throw(ArgumentError("Core series points do not use the shared parent environment."))
    series
end

"""
    run_investigation_2_core(; ...)

Construct and persist the eight mandatory Stage I2-B series in approved order,
then retain the precision-trigger decision and run the conditional precision
series only when triggered. Work reports are isolated in one fresh temporary
directory. This is not Stage I2-E repeated execution or explanatory reporting.
"""
function run_investigation_2_core(;
    output_directory=joinpath(@__DIR__, "..", "..", "..",
        "validation_reports", "investigation_2"),
    project_root=normpath(joinpath(@__DIR__, "..", "..", "..")),
    environment=nothing,
    tolerance_runner=_run_core_tolerance_series,
    duration_sampling_runner=_run_core_duration_sampling_series,
    precision_runner=_run_core_precision_series,
)
    parent_environment = isnothing(environment) ?
        _baseline_environment(project_root) : environment
    directory = abspath(output_directory)
    isdir(directory) || mkpath(directory)
    retained = InvestigationMeasurementSeries[]
    paths = String[]
    failures = CoreInvestigationWorkflowFailure[]
    vern9_source = nothing

    mktempdir() do work_root
        for (kind, family, algorithm) in CORE_INVESTIGATION_SERIES_ORDER
            series_id = _core_series_id(kind, family, algorithm)
            output_path = _owned_series_path(directory, series_id)
            _remove_owned_file(output_path)
            _clear_owned_evidence(directory, series_id)
            work_directory = joinpath(work_root, string(series_id))
            try
                series = kind == :tolerance ?
                    tolerance_runner(family, algorithm, parent_environment, work_directory) :
                    duration_sampling_runner(kind, family, parent_environment, work_directory)
                _validate_core_workflow_series(series, series_id, parent_environment)
                append!(failures,
                    _series_operational_failures(series, work_directory, directory))
                path = write_investigation_series_atomic(output_path, series)
                push!(retained, series)
                push!(paths, path)
                series_id == :figure_eight_vern9_tolerance && (vern9_source = series)
            catch error
                _remove_owned_file(output_path)
                push!(failures,
                    _retain_exception_diagnostic(directory, series_id, error))
            end
        end

        trigger_path = _owned_trigger_path(directory)
        precision_id = :figure_eight_precision_confirmation
        precision_path = _owned_series_path(directory, precision_id)
        _remove_owned_file(trigger_path)
        _remove_owned_file(precision_path)
        _clear_owned_evidence(directory, :precision_trigger)
        _clear_owned_evidence(directory, precision_id)

        assessment = nothing
        if isnothing(vern9_source)
            push!(failures, CoreInvestigationWorkflowFailure(:precision_trigger,
                actual_missing_report, nothing,
                "Figure-eight Vern9 tolerance series was unavailable.", nothing, nothing))
        else
            try
                assessment = evaluate_figure_eight_precision_trigger(vern9_source)
                push!(paths, write_figure_eight_precision_trigger_atomic(
                    trigger_path, assessment))
                if assessment.status == :triggered
                    work_directory = joinpath(work_root, string(precision_id))
                    try
                        series = precision_runner(assessment, parent_environment, work_directory)
                        _validate_core_workflow_series(series, precision_id, parent_environment)
                        append!(failures,
                            _series_operational_failures(series, work_directory, directory))
                        path = write_investigation_series_atomic(precision_path, series)
                        push!(retained, series)
                        push!(paths, path)
                    catch error
                        _remove_owned_file(precision_path)
                        push!(failures, _retain_exception_diagnostic(
                            directory, precision_id, error))
                    end
                end
            catch error
                _remove_owned_file(trigger_path)
                _remove_owned_file(precision_path)
                push!(failures, _retain_exception_diagnostic(
                    directory, :precision_trigger, error))
            end
        end
        return CoreInvestigationWorkflowResult(Tuple(retained), assessment,
            Tuple(paths), Tuple(failures), isempty(failures) ? 0 : 1)
    end
end

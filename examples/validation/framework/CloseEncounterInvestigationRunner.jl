# Controlled Stage I2-C orchestration for the approved close-encounter experiments.

const CLOSE_ENCOUNTER_INVESTIGATION_SERIES_ORDER = (
    :close_encounter_cartesian_tolerance,
    :close_encounter_automatic_regularized_tolerance,
    :close_encounter_explicit_regularized_tolerance,
    :close_encounter_automatic_threshold_scale,
    :close_encounter_explicit_threshold_scale,
)

const CLOSE_ENCOUNTER_INVESTIGATION_FILENAMES = (
    close_encounter_cartesian_tolerance="close_encounter_cartesian_tolerance.toml",
    close_encounter_automatic_regularized_tolerance=
        "close_encounter_automatic_regularized_tolerance.toml",
    close_encounter_explicit_regularized_tolerance=
        "close_encounter_explicit_regularized_tolerance.toml",
    close_encounter_automatic_threshold_scale=
        "close_encounter_automatic_threshold_scale.toml",
    close_encounter_explicit_threshold_scale=
        "close_encounter_explicit_threshold_scale.toml",
)

const CLOSE_ENCOUNTER_OPERATIONAL_EVIDENCE_DIRECTORY =
    CORE_OPERATIONAL_EVIDENCE_DIRECTORY

struct CloseEncounterInvestigationWorkflowResult
    series::Tuple{Vararg{InvestigationMeasurementSeries}}
    report_paths::Tuple{Vararg{String}}
    failures::Tuple{Vararg{CoreInvestigationWorkflowFailure}}
    exit_code::Int
end

_close_encounter_owned_filename(series_id) =
    getproperty(CLOSE_ENCOUNTER_INVESTIGATION_FILENAMES, series_id)
_close_encounter_owned_path(directory, series_id) =
    joinpath(directory, _close_encounter_owned_filename(series_id))

function _run_close_encounter_cartesian_group(reference, environment, directory, project_root;
    attempt_runner=attempt_close_encounter_cartesian,
    performance_runner=run_performance_suite)
    configurations = Tuple(close_encounter_cartesian_configuration(tolerance)
        for tolerance in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
    attempts = Tuple(attempt_runner(configuration, reference)
        for configuration in configurations)
    entries = Tuple(close_encounter_cartesian_performance_entry(configuration)
        for configuration in configurations)
    performance = performance_runner(entries; environment,
        report_directory=joinpath(directory, "performance"), project_root)
    close_encounter_cartesian_investigation_series(performance.suite, attempts)
end

function _run_close_encounter_regularized_group(reference, environment, directory, project_root;
    attempt_runner=attempt_close_encounter_regularized_pair,
    performance_runner=run_performance_suite)
    configurations = Tuple(close_encounter_regularized_tolerance_configuration(tolerance)
        for tolerance in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
    attempts = Tuple(attempt_runner(configuration, reference)
        for configuration in configurations)
    performance = performance_runner(close_encounter_regularized_performance_entries();
        environment, report_directory=joinpath(directory, "performance"), project_root)
    close_encounter_regularized_investigation_series(performance.suite, attempts)
end

function _run_close_encounter_threshold_group(reference, environment, directory, project_root;
    attempt_runner=attempt_close_encounter_regularized_pair,
    performance_runner=run_performance_suite)
    configurations = Tuple(close_encounter_threshold_scale_configuration(scale)
        for scale in CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    attempts = Tuple(attempt_runner(configuration, reference)
        for configuration in configurations)
    performance = performance_runner(close_encounter_threshold_performance_entries();
        environment, report_directory=joinpath(directory, "performance"), project_root)
    close_encounter_threshold_investigation_series(performance.suite, attempts)
end

function _close_encounter_expected_contract(series_id)
    if series_id == :close_encounter_cartesian_tolerance
        configurations = Tuple(close_encounter_cartesian_configuration(value)
            for value in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
        return (
            definition=close_encounter_cartesian_investigation_definition(),
            independent=:tolerance,
            values=CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES,
            point_ids=Tuple(Symbol(:tolerance_, _close_tolerance_token(value))
                for value in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES),
            configurations=Tuple(_close_cartesian_validation_configuration(configuration)
                for configuration in configurations),
            performance_definitions=Tuple(close_encounter_cartesian_performance_definition(
                configuration) for configuration in configurations),
            method=nothing,
        )
    end
    if series_id in (
        :close_encounter_automatic_regularized_tolerance,
        :close_encounter_explicit_regularized_tolerance)
        method = series_id == :close_encounter_automatic_regularized_tolerance ?
            :automatic : :explicit
        configurations = Tuple(close_encounter_regularized_tolerance_configuration(value)
            for value in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
        return (
            definition=close_encounter_regularized_investigation_definition(method),
            independent=:regularized_tolerance,
            values=CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES,
            point_ids=Tuple(Symbol(:regularized_tolerance_, _close_regularized_token(value))
                for value in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES),
            configurations=Tuple(_close_regularized_validation_configuration(
                configuration, method) for configuration in configurations),
            performance_definitions=Tuple(close_encounter_regularized_performance_definition(
                method, configuration) for configuration in configurations),
            method,
        )
    end
    if series_id in (
        :close_encounter_automatic_threshold_scale,
        :close_encounter_explicit_threshold_scale)
        method = series_id == :close_encounter_automatic_threshold_scale ?
            :automatic : :explicit
        configurations = Tuple(close_encounter_threshold_scale_configuration(value)
            for value in CLOSE_ENCOUNTER_THRESHOLD_SCALES)
        return (
            definition=close_encounter_threshold_investigation_definition(method),
            independent=:threshold_scale,
            values=CLOSE_ENCOUNTER_THRESHOLD_SCALES,
            point_ids=Tuple(Symbol(:threshold_scale_, _close_threshold_token(value))
                for value in CLOSE_ENCOUNTER_THRESHOLD_SCALES),
            configurations=Tuple(_close_regularized_validation_configuration(
                configuration, method) for configuration in configurations),
            performance_definitions=Tuple(close_encounter_threshold_performance_definition(
                method, configuration) for configuration in configurations),
            method,
        )
    end
    throw(ArgumentError("Unsupported close-encounter workflow series ID $series_id."))
end

function _close_encounter_supporting_boundaries(supporting)
    supporting isa CloseEncounterTemporalLocalizationEvidence && return supporting.boundaries
    supporting isa CloseEncounterRegularizedSupportingEvidence || return nothing
    retained = isnothing(supporting.method_evidence) ? supporting.propagation_evidence :
        supporting.method_evidence.propagation
    retained isa CloseEncounterRegularizedPropagationEvidence ? retained.boundaries : nothing
end

function _validate_close_encounter_workflow_series(series, series_id, environment, boundaries)
    series isa InvestigationMeasurementSeries || throw(ArgumentError(
        "Close-encounter group did not return an InvestigationMeasurementSeries."))
    series.series_id == series_id || throw(ArgumentError(
        "Close-encounter group returned $(series.series_id), expected $series_id."))
    contract = _close_encounter_expected_contract(series_id)
    _record_fields_equal(series.definition, contract.definition) || throw(ArgumentError(
        "Close-encounter series definition differs from the trusted workflow contract."))
    length(series.points) == length(contract.values) || throw(ArgumentError(
        "Close-encounter series point count differs from the trusted workflow contract."))
    Tuple(point.point_id for point in series.points) == contract.point_ids || throw(ArgumentError(
        "Close-encounter series points are missing, additional, duplicated, or reordered."))
    for (point, value, configuration, performance_definition) in zip(series.points,
        contract.values, contract.configurations, contract.performance_definitions)
        _record_fields_equal(point.definition, contract.definition) || throw(ArgumentError(
            "Close-encounter point definition differs from its series."))
        point.independent_value.parameter_id == contract.independent &&
            point.independent_value.value == value || throw(ArgumentError(
                "Close-encounter independent value differs or is reordered."))
        _record_fields_equal(point.configuration, configuration) || throw(ArgumentError(
            "Close-encounter point configuration family or controls differ."))
        _record_fields_equal(point.environment, environment) || throw(ArgumentError(
            "Close-encounter point does not use the shared parent environment."))
        performance = point.performance_report
        performance isa PerformanceBenchmarkReport || throw(ArgumentError(
            "Close-encounter point does not retain its required performance report."))
        _record_fields_equal(performance.definition, performance_definition) ||
            throw(ArgumentError(
                "Close-encounter performance report belongs to the wrong series or method."))
        _record_fields_equal(performance.configuration, configuration) || throw(ArgumentError(
            "Close-encounter performance configuration differs from its point."))
        _record_fields_equal(performance.environment, environment) || throw(ArgumentError(
            "Close-encounter performance report uses a foreign environment."))
        retained_boundaries = _close_encounter_supporting_boundaries(point.supporting_evidence)
        isnothing(retained_boundaries) || _record_fields_equal(retained_boundaries, boundaries) ||
            throw(ArgumentError(
                "Close-encounter supporting evidence retained altered reference boundaries."))
    end
    series
end

function _validate_close_encounter_paired_group(result, expected_ids, environment, boundaries)
    result isa NamedTuple && keys(result) == (:automatic, :explicit) || throw(ArgumentError(
        "Paired close-encounter group must return automatic and explicit series."))
    automatic = _validate_close_encounter_workflow_series(
        result.automatic, expected_ids[1], environment, boundaries)
    explicit = _validate_close_encounter_workflow_series(
        result.explicit, expected_ids[2], environment, boundaries)
    for (automatic_point, explicit_point) in zip(automatic.points, explicit.points)
        automatic_supporting = automatic_point.supporting_evidence
        explicit_supporting = explicit_point.supporting_evidence
        if automatic_supporting isa CloseEncounterRegularizedSupportingEvidence &&
            explicit_supporting isa CloseEncounterRegularizedSupportingEvidence
            _record_fields_equal(automatic_supporting.comparison,
                explicit_supporting.comparison) || throw(ArgumentError(
                    "Paired close-encounter series retain different comparison evidence."))
            _record_fields_equal(automatic_supporting.matched_endpoints,
                explicit_supporting.matched_endpoints) || throw(ArgumentError(
                    "Paired close-encounter series retain different endpoint evidence."))
        end
    end
    (automatic, explicit)
end

function _close_encounter_group_exception_label(series_ids)
    length(series_ids) == 1 && return only(series_ids)
    Symbol(series_ids[1], :__, series_ids[2])
end

function _clear_close_encounter_owned_outputs(directory)
    for series_id in CLOSE_ENCOUNTER_INVESTIGATION_SERIES_ORDER
        _remove_owned_file(_close_encounter_owned_path(directory, series_id))
        _clear_owned_evidence(directory, series_id)
    end
    _clear_owned_evidence(directory, :close_encounter_parent_environment)
    _clear_owned_evidence(directory, :close_encounter_shared_reference)
    nothing
end

function _persist_close_encounter_series!(retained, paths, failures, series,
    work_directory, output_directory, writer)
    series_id = series.series_id
    output_path = _close_encounter_owned_path(output_directory, series_id)
    append!(failures,
        _series_operational_failures(series, work_directory, output_directory))
    try
        path = writer(output_path, series)
        push!(retained, series)
        push!(paths, path)
    catch error
        _remove_owned_file(output_path)
        push!(failures,
            _retain_exception_diagnostic(output_directory, series_id, error))
    end
    nothing
end

"""
    run_investigation_2_close_encounter(; ...)

Construct and persist the five approved Stage I2-C close-encounter series in
their fixed order using one parent environment and one shared direct reference.
This workflow does not execute Stage I2-B, I2-D, or I2-E.
"""
function run_investigation_2_close_encounter(;
    output_directory=joinpath(@__DIR__, "..", "..", "..",
        "validation_reports", "investigation_2"),
    project_root=normpath(joinpath(@__DIR__, "..", "..", "..")),
    environment=nothing,
    environment_runner=_baseline_environment,
    reference_runner=build_close_encounter_reference,
    cartesian_runner=_run_close_encounter_cartesian_group,
    regularized_runner=_run_close_encounter_regularized_group,
    threshold_runner=_run_close_encounter_threshold_group,
    series_writer=write_investigation_series_atomic,
)
    directory = abspath(output_directory)
    isdir(directory) || mkpath(directory)
    _clear_close_encounter_owned_outputs(directory)
    retained = InvestigationMeasurementSeries[]
    paths = String[]
    failures = CoreInvestigationWorkflowFailure[]

    parent_environment = try
        isnothing(environment) ? environment_runner(project_root) : environment
    catch error
        push!(failures, _retain_exception_diagnostic(
            directory, :close_encounter_parent_environment, error))
        return CloseEncounterInvestigationWorkflowResult(
            (), (), Tuple(failures), 1)
    end
    parent_environment isa ValidationEnvironment || begin
        error = ArgumentError("Environment runner did not return ValidationEnvironment.")
        push!(failures, _retain_exception_diagnostic(
            directory, :close_encounter_parent_environment, error))
        return CloseEncounterInvestigationWorkflowResult(
            (), (), Tuple(failures), 1)
    end

    reference = try
        reference_runner()
    catch error
        push!(failures, _retain_exception_diagnostic(
            directory, :close_encounter_shared_reference, error))
        return CloseEncounterInvestigationWorkflowResult(
            (), (), Tuple(failures), 1)
    end
    reference isa CloseEncounterReferenceExecution || begin
        error = ArgumentError("Reference runner did not return CloseEncounterReferenceExecution.")
        push!(failures, _retain_exception_diagnostic(
            directory, :close_encounter_shared_reference, error))
        return CloseEncounterInvestigationWorkflowResult(
            (), (), Tuple(failures), 1)
    end
    boundaries = reference.boundaries

    mktempdir() do work_root
        groups = (
            (ids=(:close_encounter_cartesian_tolerance,), name=:cartesian,
                runner=cartesian_runner),
            (ids=(:close_encounter_automatic_regularized_tolerance,
                    :close_encounter_explicit_regularized_tolerance),
                name=:regularized_tolerance, runner=regularized_runner),
            (ids=(:close_encounter_automatic_threshold_scale,
                    :close_encounter_explicit_threshold_scale),
                name=:threshold_scale, runner=threshold_runner),
        )
        for group in groups
            work_directory = joinpath(work_root, string(group.name))
            try
                result = group.runner(reference, parent_environment,
                    work_directory, project_root)
                series = length(group.ids) == 1 ?
                    (_validate_close_encounter_workflow_series(result, only(group.ids),
                        parent_environment, boundaries),) :
                    _validate_close_encounter_paired_group(result, group.ids,
                        parent_environment, boundaries)
                for item in series
                    _persist_close_encounter_series!(retained, paths, failures, item,
                        work_directory, directory, series_writer)
                end
            catch error
                for series_id in group.ids
                    _remove_owned_file(_close_encounter_owned_path(directory, series_id))
                end
                label = _close_encounter_group_exception_label(group.ids)
                push!(failures, _retain_exception_diagnostic(directory, label, error))
            end
        end
    end
    CloseEncounterInvestigationWorkflowResult(Tuple(retained), Tuple(paths),
        Tuple(failures), isempty(failures) ? 0 : 1)
end

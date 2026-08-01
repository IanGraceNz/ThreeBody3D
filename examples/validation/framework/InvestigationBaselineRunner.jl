# Process-isolated production workflow for Investigation 1 Stage I1-E.

const INVESTIGATION_SERIES_REPORT_ENV = "THREEBODY3D_INVESTIGATION_SERIES_REPORT"
const INVESTIGATION_REPRODUCIBILITY_RTOL = 1e-12
const INVESTIGATION_REPRODUCIBILITY_ATOL = 0.0

struct InvestigationProcessRecord
    label::Symbol
    elapsed_seconds::Float64
    exit_code::Int
    message::String
end

struct InvestigationOperationalFailure
    label::Symbol
    outcome::ActualExecutionOutcome
    exit_code::Int
    message::String
    raw_report_path::Union{Nothing,String}
end

struct InvestigationReproducibilityResult
    performed::Bool
    passed::Bool
    relative_tolerance::Float64
    absolute_tolerance::Float64
    mismatches::Tuple{Vararg{String}}
end

struct InvestigationBaselineResult
    series::Tuple{Vararg{InvestigationMeasurementSeries}}
    report_paths::Tuple{Vararg{String}}
    markdown_path::String
    reproducibility::InvestigationReproducibilityResult
    operational_failures::Tuple{Vararg{InvestigationOperationalFailure}}
    exit_code::Int
end

function _baseline_environment(project_root)
    base = current_validation_environment()
    commit = try
        readchomp(`git -C $project_root rev-parse HEAD`)
    catch
        nothing
    end
    dirty = try
        !isempty(strip(readchomp(`git -C $project_root status --porcelain`)))
    catch
        nothing
    end
    ValidationEnvironment(
        base.schema_version, base.package_version, commit, dirty,
        base.julia_version, base.operating_system, base.architecture,
        base.thread_count, base.timestamp_utc,
    )
end

function _execute_baseline_process(label, command; process_runner=nothing)
    if isnothing(process_runner)
        started = time_ns()
        exit_code = 0
        message = ""
        try
            run(command)
        catch error
            exit_code = error isa ProcessFailedException ? last(error.procs).exitcode : 1
            message = sprint(showerror, error)
        end
        return InvestigationProcessRecord(
            label, (time_ns() - started) / 1e9, exit_code, message,
        )
    end
    record = process_runner(command, label)
    record isa InvestigationProcessRecord || throw(ArgumentError(
        "process_runner must return an InvestigationProcessRecord.",
    ))
    record.label == label || throw(ArgumentError(
        "process_runner returned a record for a different baseline child.",
    ))
    record
end

function _operational_failure(label, outcome, process, message, raw_path=nothing)
    InvestigationOperationalFailure(
        label, outcome, process.exit_code, String(message),
        isnothing(raw_path) ? nothing : abspath(raw_path),
    )
end

function _run_baseline_case(
    path, case_id, environment, directory;
    point=nothing, series_path=nothing, process_runner=nothing,
)
    label = isnothing(point) ? case_id : Symbol(case_id, :_, point)
    report_path = joinpath(directory, string(label, ".toml"))
    command = addenv(
        `$(Base.julia_cmd()) --project=$(normpath(joinpath(@__DIR__, "..", "..", ".."))) $path`,
        VALIDATION_REPORT_ENV => report_path,
        VALIDATION_CASE_ID_ENV => string(case_id),
        VALIDATION_SCHEMA_VERSION_ENV => environment.schema_version,
    )
    isnothing(point) || (command = addenv(
        command, "THREEBODY3D_INVESTIGATION_POINT" => string(point),
    ))
    isnothing(series_path) || (command = addenv(
        command, INVESTIGATION_SERIES_REPORT_ENV => series_path,
    ))
    process = _execute_baseline_process(label, command; process_runner)
    if !isfile(report_path)
        message = isempty(process.message) ?
            "Structured case report was not written." : process.message
        return (; result=nothing, process, failure=_operational_failure(
            label, actual_missing_report, process, message,
        ), child_environment=nothing)
    end
    parsed_result = try
        parsed = read_case_report(report_path)
        parsed.definition.case_id == case_id || throw(ArgumentError(
            "Child report case $(parsed.definition.case_id) does not match $case_id.",
        ))
        expected_exit = validation_exit_code(parsed)
        process.exit_code == expected_exit || throw(ArgumentError(
            "Child exit code $(process.exit_code) does not match retained report exit $expected_exit.",
        ))
        (ValidationCaseResult(
            parsed.definition, environment, parsed.configuration, parsed.metrics,
            parsed.criteria, parsed.solver_statistics, parsed.execution,
        ), parsed.environment)
    catch error
        message = sprint(showerror, error)
        combined = isempty(process.message) ? message : process.message * "; " * message
        return (; result=nothing, process, failure=_operational_failure(
            label, actual_malformed_report, process, combined, report_path,
        ), child_environment=nothing)
    end
    result, child_environment = parsed_result
    (; result, process, failure=nothing, child_environment)
end

function _operational_point(definition, point_id, configuration, environment, failure;
    performance_report=nothing,
)
    execution = ExecutionOutcome(
        failure.outcome; exit_code=failure.exit_code, summary=failure.message,
    )
    InvestigationMeasurementPoint(
        point_id, definition, configuration,
        ValidationParameter(definition.independent_variable, point_id),
        environment, execution, (), nothing;
        performance_report, notes="Operational workflow/reporting failure: $(failure.message)",
    )
end

function _core_series_with_failures(family, performance, executions, environment)
    if family == :figure_eight
        definition = figure_eight_profile_investigation_definition()
        profiles = FIGURE_EIGHT_INVESTIGATION_PROFILES
        reports = _performance_reports_by_id(performance.benchmarks)
        points = map(profiles, executions) do profile, execution
            benchmark_id = Symbol("figure_eight_accuracy_work_", profile)
            report = reports[benchmark_id]
            isnothing(execution.failure) ? _figure_eight_investigation_point(
                execution.result, report, definition, profile,
            ) : _operational_point(
                definition, profile, report.configuration, environment,
                execution.failure; performance_report=report,
            )
        end
        return InvestigationMeasurementSeries(
            :figure_eight_profile, "Figure-eight solver-profile comparison",
            "Ordered Investigation 1 measurements for the fast and accurate solver profiles.",
            definition, Tuple(points),
        )
    end
    definition = hierarchical_triple_profile_investigation_definition()
    profiles = HIERARCHICAL_TRIPLE_INVESTIGATION_PROFILES
    reports = _performance_reports_by_id(performance.benchmarks)
    points = map(profiles, executions) do profile, execution
        benchmark_id = Symbol("hierarchical_triple_accuracy_work_", profile)
        report = reports[benchmark_id]
        isnothing(execution.failure) ? _hierarchical_triple_investigation_point(
            execution.result, report, definition, profile,
        ) : _operational_point(
            definition, profile, report.configuration, environment,
            execution.failure; performance_report=report,
        )
    end
    InvestigationMeasurementSeries(
        :hierarchical_triple_profile, "Hierarchical-triple solver-profile comparison",
        "Ordered Investigation 1 measurements for the fast and accurate solver profiles.",
        definition, Tuple(points),
    )
end

function _series_operational_failure(family, environment, failure)
    definition, point_ids, configuration, title, description = if family == :close_encounter
        definition = close_encounter_representation_investigation_definition()
        (definition, CLOSE_ENCOUNTER_INVESTIGATION_REPRESENTATIONS,
         _close_encounter_investigation_configuration(),
         "Close-encounter propagation-representation comparison",
         "Ordered Investigation 1 measurements for Cartesian, automatic-switching, and explicit regularized propagation.")
    else
        definition = ks_switching_backend_investigation_definition()
        (definition, KS_SWITCHING_INVESTIGATION_BACKENDS,
         _ks_switching_investigation_configuration(),
         "Fixed-policy regularization-backend comparison",
         "Ordered Investigation 1 measurements for KS and Levi-Civita propagation.")
    end
    points = Tuple(
        _operational_point(definition, point_id, configuration, environment, failure)
        for point_id in point_ids
    )
    InvestigationMeasurementSeries(definition.family_id, title, description, definition, points)
end

function _baseline_series_environment(series, environment)
    points = map(series.points) do point
        evidence = point.supporting_evidence
        if evidence isa KSSwitchingBackendReport
            evidence = KSSwitchingBackendReport(
                evidence.backend, evidence.definition, evidence.configuration, environment,
                evidence.execution, evidence.final_time, evidence.samples, evidence.diagnostics,
                evidence.solver_statistics, evidence.crossing_observations, evidence.switch_events,
                evidence.maximum_scaled_backend_state_discrepancy,
                evidence.entry_event_time_discrepancy, evidence.exit_event_time_discrepancy,
            )
        end
        InvestigationMeasurementPoint(
            point.point_id, series.definition, point.configuration, point.independent_value,
            environment, point.execution, point.metrics, point.solver_statistics;
            performance_report=point.performance_report,
            supporting_evidence=evidence, notes=point.notes,
        )
    end
    InvestigationMeasurementSeries(
        series.series_id, series.title, series.description, series.definition, Tuple(points),
    )
end

function _expected_child_series_contract(family)
    if family == :close_encounter
        return (
            series_id=:close_encounter_representation,
            definition=close_encounter_representation_investigation_definition(),
            point_ids=CLOSE_ENCOUNTER_INVESTIGATION_REPRESENTATIONS,
            configuration=_close_encounter_investigation_configuration(),
        )
    elseif family == :ks_switching
        return (
            series_id=:ks_switching_backend,
            definition=ks_switching_backend_investigation_definition(),
            point_ids=KS_SWITCHING_INVESTIGATION_BACKENDS,
            configuration=_ks_switching_investigation_configuration(),
        )
    end
    throw(ArgumentError("Unsupported child investigation family $family."))
end

function _validate_child_investigation_series(
    series, family, schema_version; expected_child_environment=nothing,
)
    expected = _expected_child_series_contract(family)
    series.series_id == expected.series_id || throw(ArgumentError(
        "Child investigation series $(series.series_id) does not match $(expected.series_id).",
    ))
    _record_fields_equal(series.definition, expected.definition) || throw(ArgumentError(
        "Child investigation definition does not match the approved $family definition.",
    ))
    point_ids = map(point -> point.point_id, series.points)
    point_ids == expected.point_ids || throw(ArgumentError(
        "Child investigation point identities or order do not match the approved contract.",
    ))
    child_environment = first(series.points).environment
    child_environment.schema_version == schema_version || throw(ArgumentError(
        "Child investigation schema version does not match the requested schema.",
    ))
    isnothing(expected_child_environment) ||
        _record_fields_equal(child_environment, expected_child_environment) ||
        throw(ArgumentError(
            "Child investigation environment does not match the child case-report environment.",
        ))
    for (point, point_id) in zip(series.points, expected.point_ids)
        _record_fields_equal(point.independent_value, ValidationParameter(
            expected.definition.independent_variable, point_id,
        )) || throw(ArgumentError(
            "Child investigation independent value for $point_id is inconsistent.",
        ))
        _record_fields_equal(point.configuration, expected.configuration) || throw(ArgumentError(
            "Child investigation configuration for $point_id is not approved.",
        ))
        _record_fields_equal(point.environment, child_environment) || throw(ArgumentError(
            "Child investigation points do not share one child environment.",
        ))
    end
    series
end

function _series_with_operational_execution(series, failure)
    points = map(series.points) do point
        retained_status = stable_string(point.execution.actual)
        retained_notes = isnothing(point.notes) ? "" : " Existing notes: $(point.notes)"
        execution = ExecutionOutcome(
            failure.outcome; exit_code=failure.exit_code, summary=failure.message,
        )
        InvestigationMeasurementPoint(
            point.point_id, series.definition, point.configuration,
            point.independent_value, point.environment, execution,
            point.metrics, point.solver_statistics;
            performance_report=point.performance_report,
            supporting_evidence=point.supporting_evidence,
            notes="Operational case-report failure; retained child-series point status was $retained_status.$retained_notes",
        )
    end
    InvestigationMeasurementSeries(
        series.series_id, series.title, series.description, series.definition, Tuple(points),
    )
end

function _read_child_series(path, family, environment, execution)
    if !isfile(path)
        failure = _operational_failure(
            Symbol(family, :_series), actual_missing_report, execution.process,
            "Investigation series report was not written.",
        )
        return _series_operational_failure(family, environment, failure), failure
    end
    try
        retained = read_investigation_series(path)
        child_environment = hasproperty(execution, :child_environment) ?
            execution.child_environment : nothing
        _validate_child_investigation_series(
            retained, family, environment.schema_version;
            expected_child_environment=child_environment,
        )
        retained = _baseline_series_environment(retained, environment)
        isnothing(execution.failure) ||
            (retained = _series_with_operational_execution(retained, execution.failure))
        return retained, nothing
    catch error
        failure = _operational_failure(
            Symbol(family, :_series), actual_malformed_report, execution.process,
            sprint(showerror, error), path,
        )
        return _series_operational_failure(family, environment, failure), failure
    end
end

function _compare_numeric(left, right, path, mismatches, rtol, atol)
    isapprox(left, right; rtol, atol, nans=false) || push!(
        mismatches, "$path differs: $left versus $right",
    )
end

function _compare_evidence(left, right, path, mismatches, rtol, atol)
    typeof(left) == typeof(right) || return push!(mismatches, "$path types differ.")
    if left isa AbstractFloat
        return _compare_numeric(left, right, path, mismatches, rtol, atol)
    elseif left isa Number || left isa Symbol || left isa String || left isa Bool || isnothing(left)
        left == right || push!(mismatches, "$path differs.")
    elseif left isa Tuple || left isa AbstractVector
        length(left) == length(right) || return push!(mismatches, "$path lengths differ.")
        for index in eachindex(left)
            _compare_evidence(left[index], right[index], "$path[$index]", mismatches, rtol, atol)
        end
    else
        for name in fieldnames(typeof(left))
            _compare_evidence(
                getfield(left, name), getfield(right, name), "$path.$name",
                mismatches, rtol, atol,
            )
        end
    end
    nothing
end

function _compare_execution(left, right, path, mismatches)
    matches = left.actual == right.actual &&
        left.exit_code == right.exit_code && left.summary == right.summary
    matches || push!(mismatches, "$path differs.")
end

function _compare_performance_report(left, right, path, mismatches, rtol, atol)
    isnothing(left) == isnothing(right) || return push!(
        mismatches, "$path presence differs.",
    )
    isnothing(left) && return nothing
    _record_fields_equal(left.definition, right.definition) ||
        push!(mismatches, "$path definition differs.")
    _record_fields_equal(left.configuration, right.configuration) ||
        push!(mismatches, "$path configuration differs.")
    _record_fields_equal(left.policy, right.policy) ||
        push!(mismatches, "$path measurement policy differs.")
    _compare_execution(left.execution, right.execution, "$path execution", mismatches)
    length(left.samples) == length(right.samples) ||
        push!(mismatches, "$path retained sample count differs.")
    for (index, (left_sample, right_sample)) in enumerate(zip(left.samples, right.samples))
        sample_path = "$path.samples[$index]"
        left_sample.sample_index == right_sample.sample_index ||
            push!(mismatches, "$sample_path index differs.")
        # elapsed_seconds and gc_seconds are deliberately environment-dependent.
        for name in (:allocated_bytes, :allocation_count, :solver_statistics, :saved_states)
            _compare_evidence(
                getfield(left_sample, name), getfield(right_sample, name),
                "$sample_path.$name", mismatches, rtol, atol,
            )
        end
        left_ids = map(metric -> metric.metric_id, left_sample.measurements)
        right_ids = map(metric -> metric.metric_id, right_sample.measurements)
        left_ids == right_ids || push!(mismatches, "$sample_path measurement identities differ.")
        for (left_metric, right_metric) in zip(left_sample.measurements, right_sample.measurements)
            _compare_evidence(
                left_metric, right_metric,
                "$sample_path.measurements.$(left_metric.metric_id)", mismatches, rtol, atol,
            )
        end
    end
    # Elapsed-time summary fields are derived solely from excluded timing samples.
    for name in (
        :sample_count, :allocated_bytes_minimum, :allocated_bytes_median,
        :allocated_bytes_maximum, :allocation_count_minimum,
        :allocation_count_median, :allocation_count_maximum,
    )
        _compare_evidence(
            getfield(left.summary, name), getfield(right.summary, name),
            "$path.summary.$name", mismatches, rtol, atol,
        )
    end
    nothing
end

function compare_investigation_baselines(first_run, second_run;
    rtol=INVESTIGATION_REPRODUCIBILITY_RTOL,
    atol=INVESTIGATION_REPRODUCIBILITY_ATOL,
)
    mismatches = String[]
    length(first_run) == length(second_run) || push!(mismatches, "Series counts differ.")
    for (series_index, (left, right)) in enumerate(zip(first_run, second_run))
        prefix = "series[$series_index]"
        left.series_id == right.series_id || push!(mismatches, "$prefix identity differs.")
        _record_fields_equal(left.definition, right.definition) || push!(mismatches, "$prefix definition differs.")
        length(left.points) == length(right.points) || push!(mismatches, "$prefix point counts differ.")
        for (point_index, (left_point, right_point)) in enumerate(zip(left.points, right.points))
            point_path = "$prefix.points[$point_index]"
            left_point.point_id == right_point.point_id || push!(mismatches, "$point_path identity differs.")
            _record_fields_equal(left_point.configuration, right_point.configuration) || push!(mismatches, "$point_path configuration differs.")
            _record_fields_equal(left_point.independent_value, right_point.independent_value) ||
                push!(mismatches, "$point_path independent value differs.")
            _compare_execution(
                left_point.execution, right_point.execution, "$point_path execution", mismatches,
            )
            left_ids = map(metric -> metric.metric_id, left_point.metrics)
            right_ids = map(metric -> metric.metric_id, right_point.metrics)
            left_ids == right_ids || push!(mismatches, "$point_path metric identities differ.")
            for (left_metric, right_metric) in zip(left_point.metrics, right_point.metrics)
                _compare_evidence(
                    left_metric.value, right_metric.value,
                    "$point_path.metrics.$(left_metric.metric_id)", mismatches, rtol, atol,
                )
            end
            for name in (:accepted_steps, :rejected_steps, :rhs_evaluations, :saved_states, :segment_count, :switch_count)
                left_value = isnothing(left_point.solver_statistics) ? nothing : getfield(left_point.solver_statistics, name)
                right_value = isnothing(right_point.solver_statistics) ? nothing : getfield(right_point.solver_statistics, name)
                left_value == right_value || push!(mismatches, "$point_path solver work $name differs.")
            end
            _compare_evidence(
                left_point.supporting_evidence, right_point.supporting_evidence,
                "$point_path.supporting_evidence", mismatches, rtol, atol,
            )
            _compare_performance_report(
                left_point.performance_report, right_point.performance_report,
                "$point_path.performance_report", mismatches, rtol, atol,
            )
        end
    end
    InvestigationReproducibilityResult(true, isempty(mismatches), Float64(rtol), Float64(atol), Tuple(mismatches))
end

function _execute_baseline_once(
    working_directory, environment, policy, project_root;
    case_process_runner=nothing, performance_process_runner=nothing,
)
    failures = InvestigationOperationalFailure[]
    performance_result = run_performance_suite(
        representative_accuracy_work_entries(; policy);
        environment, report_directory=joinpath(working_directory, "performance"), project_root,
        process_runner=performance_process_runner,
        suite_id=:investigation_1_accuracy_work,
        title="Investigation 1 retained accuracy-versus-work measurements",
    )
    performance = performance_result.suite
    for (report, process) in zip(performance.benchmarks, performance_result.processes)
        report.execution.actual == actual_completed && continue
        push!(failures, InvestigationOperationalFailure(
            report.definition.benchmark_id, report.execution.actual,
            process.exit_code, something(report.execution.summary, process.message), nothing,
        ))
    end
    validation_directory = joinpath(working_directory, "validation")
    mkpath(validation_directory)
    figure_runs = Tuple(_run_baseline_case(
        joinpath(project_root, "examples", "validation", "figure_eight_benchmark.jl"),
        :figure_eight, environment, validation_directory;
        point, process_runner=case_process_runner,
    ) for point in FIGURE_EIGHT_INVESTIGATION_PROFILES)
    append!(failures, (run.failure for run in figure_runs if !isnothing(run.failure)))
    figure = _core_series_with_failures(:figure_eight, performance, figure_runs, environment)
    hierarchical_runs = Tuple(_run_baseline_case(
        joinpath(project_root, "examples", "validation", "hierarchical_triple_benchmark.jl"),
        :hierarchical_triple, environment, validation_directory;
        point, process_runner=case_process_runner,
    ) for point in HIERARCHICAL_TRIPLE_INVESTIGATION_PROFILES)
    append!(failures, (run.failure for run in hierarchical_runs if !isnothing(run.failure)))
    hierarchical = _core_series_with_failures(
        :hierarchical_triple, performance, hierarchical_runs, environment,
    )
    close_path = joinpath(working_directory, "close_encounter_representation.raw.toml")
    close_run = _run_baseline_case(
        joinpath(project_root, "examples", "validation", "close_encounter_comparison.jl"),
        :close_encounter_comparison, environment, validation_directory;
        series_path=close_path, process_runner=case_process_runner,
    )
    !isnothing(close_run.failure) && push!(failures, close_run.failure)
    close, close_failure = _read_child_series(close_path, :close_encounter, environment, close_run)
    !isnothing(close_failure) && push!(failures, close_failure)
    ks_path = joinpath(working_directory, "ks_switching_backend.raw.toml")
    ks_run = _run_baseline_case(
        joinpath(project_root, "examples", "validation", "ks_switching_comparison.jl"),
        :ks_switching_comparison, environment, validation_directory;
        series_path=ks_path, process_runner=case_process_runner,
    )
    !isnothing(ks_run.failure) && push!(failures, ks_run.failure)
    ks, ks_failure = _read_child_series(ks_path, :ks_switching, environment, ks_run)
    !isnothing(ks_failure) && push!(failures, ks_failure)
    raw_paths = String[
        failure.raw_report_path for failure in failures
        if !isnothing(failure.raw_report_path) && isfile(failure.raw_report_path)
    ]
    for (path, execution) in ((close_path, close_run), (ks_path, ks_run))
        !isnothing(execution.failure) && isfile(path) && push!(raw_paths, path)
    end
    unique!(raw_paths)
    raw_files = Tuple(
        (Symbol(splitext(basename(path))[1]), read(path))
        for path in raw_paths
    )
    (; series=(figure, hierarchical, close, ks), failures=Tuple(failures), raw_files)
end

function _write_raw_evidence_atomic(path, bytes)
    final_path = abspath(path)
    mkpath(dirname(final_path))
    temporary_path = final_path * ".tmp"
    try
        open(temporary_path, "w") do io
            write(io, bytes)
        end
        mv(temporary_path, final_path; force=true)
    catch
        isfile(temporary_path) && rm(temporary_path; force=true)
        rethrow()
    end
    final_path
end

"""Execute twice, compare, persist, and render the four Investigation 1 pilots."""
function run_investigation_1_baseline(
    output_directory::AbstractString;
    environment=nothing,
    policy::PerformanceMeasurementPolicy=StandardBenchmark(),
    project_root::AbstractString=normpath(joinpath(@__DIR__, "..", "..", "..")),
    case_process_runner=nothing,
    performance_process_runner=nothing,
)
    environment = isnothing(environment) ? _baseline_environment(project_root) : environment
    environment isa ValidationEnvironment || throw(ArgumentError(
        "environment must be a ValidationEnvironment record or nothing.",
    ))
    output = abspath(output_directory)
    mkpath(output)
    first_result = mktempdir() do directory
        _execute_baseline_once(
            directory, environment, policy, project_root;
            case_process_runner, performance_process_runner,
        )
    end
    approved_filenames = (
        "figure_eight_profile.toml", "hierarchical_triple_profile.toml",
        "close_encounter_representation.toml", "ks_switching_backend.toml",
    )
    paths = Tuple(write_investigation_series_atomic(
        joinpath(output, filename), series,
    ) for (filename, series) in zip(approved_filenames, first_result.series))
    for (label, bytes) in first_result.raw_files
        _write_raw_evidence_atomic(
            joinpath(output, "operational_evidence", "first_execution", string(label) * ".raw"), bytes,
        )
    end
    second_result = mktempdir() do directory
        _execute_baseline_once(
            directory, environment, policy, project_root;
            case_process_runner, performance_process_runner,
        )
    end
    for (label, bytes) in second_result.raw_files
        _write_raw_evidence_atomic(
            joinpath(output, "operational_evidence", "second_execution", string(label) * ".raw"), bytes,
        )
    end
    reproducibility = if isempty(first_result.failures) && isempty(second_result.failures)
        compare_investigation_baselines(first_result.series, second_result.series)
    else
        messages = (
            ("First execution incomplete: " * failure.message for failure in first_result.failures)...,
            ("Second execution incomplete: " * failure.message for failure in second_result.failures)...,
        )
        InvestigationReproducibilityResult(
            true, false, INVESTIGATION_REPRODUCIBILITY_RTOL,
            INVESTIGATION_REPRODUCIBILITY_ATOL, messages,
        )
    end
    failures = (first_result.failures..., second_result.failures...)
    markdown_path = write_investigation_baseline_atomic(
        joinpath(output, "INVESTIGATION_1_BASELINE_REPORT.md"),
        first_result.series; reproducibility,
    )
    exit_code = isempty(failures) && reproducibility.passed ? 0 : 1
    InvestigationBaselineResult(
        first_result.series, paths, markdown_path, reproducibility, failures, exit_code,
    )
end

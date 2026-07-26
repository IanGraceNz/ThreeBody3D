# Process-isolated orchestration for registered performance benchmarks.

"""One benchmark script and its fixed reproducible execution configuration."""
struct PerformanceBenchmarkEntry
    definition::PerformanceBenchmarkDefinition
    configuration::ValidationConfiguration
    policy::PerformanceMeasurementPolicy
    path::String

    function PerformanceBenchmarkEntry(
        definition::PerformanceBenchmarkDefinition,
        configuration::ValidationConfiguration,
        policy::PerformanceMeasurementPolicy,
        path,
    )
        policy.process_isolation || throw(ArgumentError(
            "Registered suite benchmarks must require process isolation.",
        ))
        normalized_path = abspath(_nonempty_string(path, "path"))
        new(definition, configuration, policy, normalized_path)
    end
end

"""Parent-process timing and diagnostic information for one child invocation."""
struct PerformanceProcessRecord
    entry::PerformanceBenchmarkEntry
    elapsed_seconds::Float64
    exit_code::Int
    message::String

    function PerformanceProcessRecord(entry, elapsed_seconds, exit_code, message="")
        elapsed = Float64(elapsed_seconds)
        isfinite(elapsed) && elapsed >= 0 || throw(ArgumentError(
            "elapsed_seconds must be finite and nonnegative.",
        ))
        exit_code isa Integer || throw(ArgumentError("exit_code must be an integer."))
        new(entry, elapsed, Int(exit_code), String(message))
    end
end

function _performance_command(entry::PerformanceBenchmarkEntry, project_root::AbstractString)
    `$(Base.julia_cmd()) --project=$(abspath(project_root)) $(entry.path)`
end

# Internal constructor helper used because the default process runner does not
# know the registry entry when it starts the child process.
function _execute_performance_process(entry, command; process_runner=nothing)
    if isnothing(process_runner)
        started = time_ns()
        exit_code = 0
        message = ""
        try
            run(command)
        catch error
            exit_code = 1
            message = sprint(showerror, error)
        end
        return PerformanceProcessRecord(
            entry,
            (time_ns() - started) / 1.0e9,
            exit_code,
            message,
        )
    end

    result = process_runner(command, entry)
    result isa PerformanceProcessRecord || throw(ArgumentError(
        "process_runner must return a PerformanceProcessRecord.",
    ))
    result.entry === entry || throw(ArgumentError(
        "process_runner returned a record for a different benchmark entry.",
    ))
    result
end

function _performance_report_with_environment(
    report::PerformanceBenchmarkReport,
    environment::ValidationEnvironment,
)
    build_performance_benchmark_report(
        report.definition,
        environment,
        report.configuration,
        report.policy,
        report.samples,
        report.execution,
    )
end

function _performance_runner_error_report(
    entry::PerformanceBenchmarkEntry,
    environment::ValidationEnvironment,
    actual::ActualExecutionOutcome,
    process::PerformanceProcessRecord,
    message::AbstractString,
)
    execution = ExecutionOutcome(
        actual;
        exit_code=process.exit_code,
        elapsed_seconds=process.elapsed_seconds,
        summary=_nonempty_string(message, "message"),
    )
    build_performance_benchmark_report(
        entry.definition,
        environment,
        entry.configuration,
        entry.policy,
        (),
        execution,
    )
end

function _validate_child_performance_report(
    entry::PerformanceBenchmarkEntry,
    report::PerformanceBenchmarkReport,
)
    _record_fields_equal(report.definition, entry.definition) || throw(ArgumentError(
        "Child report definition does not match the registered benchmark definition.",
    ))
    _record_fields_equal(report.configuration, entry.configuration) || throw(ArgumentError(
        "Child report configuration does not match the registered benchmark configuration.",
    ))
    _record_fields_equal(report.policy, entry.policy) || throw(ArgumentError(
        "Child report policy does not match the registered benchmark policy.",
    ))
    report
end

"""
    run_performance_entry(entry, environment, report_directory; ...)

Execute one registered benchmark in a child Julia process, read and validate its
atomic report, and return both the normalized benchmark report and parent-level
process record. Missing or malformed child evidence becomes an explicit
operational report rather than a scientific result.
"""
function run_performance_entry(
    entry::PerformanceBenchmarkEntry,
    environment::ValidationEnvironment,
    report_directory::AbstractString;
    project_root::AbstractString=normpath(joinpath(@__DIR__, "..", "..", "..")),
    process_runner=nothing,
)
    isfile(entry.path) || begin
        process = PerformanceProcessRecord(entry, 0.0, 1, "Benchmark file does not exist: $(entry.path)")
        return _performance_runner_error_report(
            entry,
            environment,
            actual_missing_report,
            process,
            process.message,
        ), process
    end

    mkpath(report_directory)
    report_path = joinpath(abspath(report_directory), string(entry.definition.benchmark_id) * ".toml")
    command = addenv(
        _performance_command(entry, project_root),
        PERFORMANCE_REPORT_ENV => report_path,
        PERFORMANCE_BENCHMARK_ID_ENV => string(entry.definition.benchmark_id),
        PERFORMANCE_SCHEMA_VERSION_ENV => environment.schema_version,
    )
    process = _execute_performance_process(entry, command; process_runner)

    if !isfile(report_path)
        message = isempty(process.message) ?
            "Performance benchmark did not write the requested report." :
            process.message * "; performance benchmark did not write the requested report."
        return _performance_runner_error_report(
            entry,
            environment,
            actual_missing_report,
            process,
            message,
        ), process
    end

    report = try
        parsed = read_performance_benchmark(report_path)
        _validate_child_performance_report(entry, parsed)
        expected_exit_code = performance_exit_code(parsed)
        process.exit_code == expected_exit_code || throw(ArgumentError(
            "Child process exit code $(process.exit_code) does not match report execution outcome $(parsed.execution.actual).",
        ))
        _performance_report_with_environment(parsed, environment)
    catch error
        message = sprint(showerror, error)
        combined = isempty(process.message) ? message : process.message * "; " * message
        return _performance_runner_error_report(
            entry,
            environment,
            actual_malformed_report,
            process,
            combined,
        ), process
    end

    report, process
end

"""Build an ordered suite report using the parent runner environment."""
function build_performance_suite_report(
    benchmarks,
    environment::ValidationEnvironment;
    suite_id::Symbol=:performance_benchmarks,
    title::AbstractString="ThreeBody3D performance benchmark suite",
)
    normalized = Tuple(
        _performance_report_with_environment(report, environment) for report in benchmarks
    )
    PerformanceSuiteReport(
        suite_id,
        title,
        environment.schema_version,
        environment,
        normalized,
    )
end

"""
    run_performance_suite(entries; ...)

Execute registered benchmarks sequentially in isolated Julia processes. The
returned suite describes execution completeness only; it never assigns a
performance or scientific acceptance status.
"""
function run_performance_suite(
    entries;
    environment::ValidationEnvironment=current_validation_environment(),
    report_directory=nothing,
    project_root::AbstractString=normpath(joinpath(@__DIR__, "..", "..", "..")),
    process_runner=nothing,
    report_path=nothing,
    suite_id::Symbol=:performance_benchmarks,
    title::AbstractString="ThreeBody3D performance benchmark suite",
)
    normalized_entries = Tuple(entries)
    isempty(normalized_entries) && throw(ArgumentError(
        "The performance suite must contain at least one registered benchmark.",
    ))
    all(entry -> entry isa PerformanceBenchmarkEntry, normalized_entries) || throw(
        ArgumentError("entries must contain PerformanceBenchmarkEntry records."),
    )
    _unique_identifiers(
        map(entry -> entry.definition.benchmark_id, normalized_entries),
        "performance suite entries",
    )

    execute = function(directory)
        executed = Tuple(
            run_performance_entry(
                entry,
                environment,
                directory;
                project_root,
                process_runner,
            ) for entry in normalized_entries
        )
        reports = first.(executed)
        processes = last.(executed)
        suite = build_performance_suite_report(
            reports,
            environment;
            suite_id,
            title,
        )
        isnothing(report_path) || write_report_atomic(String(report_path), suite)
        (; suite, processes)
    end

    if isnothing(report_directory)
        return mktempdir(execute)
    end
    execute(abspath(String(report_directory)))
end

# Run the complete ThreeBody3D scientific validation suite.
#
# Each validation case is executed in a separate Julia process. Structured
# cases publish deterministic case reports through the reserved environment
# protocol; the one remaining legacy process is represented explicitly by a
# process-level compatibility result.

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const VALIDATION_SUITE_ENTRIES = (
    ValidationSuiteEntry(
        :figure_eight,
        "Strongly coupled periodic three-body dynamics",
        joinpath(@__DIR__, "figure_eight_benchmark.jl"),
    ),
    ValidationSuiteEntry(
        :hierarchical_triple,
        "Weakly perturbed multiscale hierarchical dynamics",
        joinpath(@__DIR__, "hierarchical_triple_benchmark.jl"),
    ),
    ValidationSuiteEntry(
        :switching_diagnostics,
        "Conservation and continuity across representation switches",
        joinpath(@__DIR__, "..", "long_duration_switching_validation.jl");
        structured=false,
    ),
    ValidationSuiteEntry(
        :close_encounter_comparison,
        "Independent high-precision validation of close-encounter regularization",
        joinpath(@__DIR__, "close_encounter_comparison.jl"),
    ),
    ValidationSuiteEntry(
        :equilateral_triple_collision_reference,
        "Analytic homothetic reference approaching a triple collision",
        joinpath(@__DIR__, "equilateral_triple_collision_reference.jl"),
    ),
    ValidationSuiteEntry(
        :randomized_regression,
        "Deterministic-seed randomized robustness validation",
        joinpath(@__DIR__, "randomized_regression_validation.jl"),
    ),
    ValidationSuiteEntry(
        :ks_kepler,
        "Exact isolated Kepler propagation in KS coordinates",
        joinpath(@__DIR__, "ks_kepler_validation.jl"),
    ),
    ValidationSuiteEntry(
        :ks_collision_continuation,
        "Finite KS continuation through a radial binary collision",
        joinpath(@__DIR__, "ks_collision_continuation.jl"),
    ),
    ValidationSuiteEntry(
        :ks_levi_civita_comparison,
        "Independent KS and Levi-Civita physical-state comparison",
        joinpath(@__DIR__, "ks_levi_civita_comparison.jl"),
    ),
    ValidationSuiteEntry(
        :ks_hierarchical_triple,
        "Coupled pair-centred KS propagation in a hierarchical triple",
        joinpath(@__DIR__, "ks_hierarchical_triple.jl"),
    ),
    ValidationSuiteEntry(
        :ks_switching_comparison,
        "Automatic-switching comparison between KS and Levi-Civita",
        joinpath(@__DIR__, "ks_switching_comparison.jl"),
    ),
)

project_root() = normpath(joinpath(@__DIR__, "..", ".."))

function validation_command(path)
    `$(Base.julia_cmd()) --project=$(project_root()) $path`
end

function _run_process(command)
    started = time()
    message = ""
    completed = true
    try
        run(command)
    catch exception
        completed = false
        message = sprint(showerror, exception)
    end
    (; completed, elapsed_seconds=time() - started, message)
end

function run_validation_entry(
    entry::ValidationSuiteEntry,
    environment::ValidationEnvironment,
    report_directory::AbstractString,
)
    println()
    println("================================================================")
    println("Validation case: ", entry.case_id)
    println(entry.description)
    println("File: ", relpath(entry.path, pwd()))
    println("================================================================")

    if !isfile(entry.path)
        message = "Validation file does not exist: $(entry.path)"
        println("ERROR: ", message)
        result = ValidationFramework._structured_error_result(
            entry,
            environment,
            project_root(),
            0.0,
            message,
        )
        return result, ValidationProcessRecord(entry, 0.0, message)
    end

    if !entry.structured
        process = _run_process(validation_command(entry.path))
        result = ValidationFramework._process_case_result(
            entry,
            environment,
            project_root();
            completed=process.completed,
            elapsed_seconds=process.elapsed_seconds,
            message=process.message,
        )
        status = process.completed ? "PASS" : "FAIL"
        println()
        println("Result: $status (", round(process.elapsed_seconds; digits=3), " seconds)")
        !process.completed && println("Reason: ", process.message)
        return result, ValidationProcessRecord(
            entry,
            process.elapsed_seconds,
            process.message,
        )
    end

    report_path = joinpath(report_directory, string(entry.case_id) * ".toml")
    command = addenv(
        validation_command(entry.path),
        VALIDATION_REPORT_ENV => report_path,
        VALIDATION_CASE_ID_ENV => string(entry.case_id),
        VALIDATION_SCHEMA_VERSION_ENV => environment.schema_version,
    )
    process = _run_process(command)

    result = try
        isfile(report_path) || throw(ArgumentError("Structured case report was not written."))
        parsed = read_case_report(report_path)
        parsed.definition.case_id == entry.case_id || throw(ArgumentError(
            "Structured report case $(parsed.definition.case_id) does not match $(entry.case_id).",
        ))
        ValidationFramework._suite_case_environment(parsed, environment)
    catch exception
        report_message = sprint(showerror, exception)
        combined = isempty(process.message) ? report_message : process.message * "; " * report_message
        ValidationFramework._structured_error_result(
            entry,
            environment,
            project_root(),
            process.elapsed_seconds,
            combined,
        )
    end

    passed = result.status == case_pass
    message = if passed
        ""
    elseif !isempty(process.message)
        process.message
    elseif isnothing(result.execution.summary)
        "Structured validation case did not pass."
    else
        something(result.execution.summary)
    end
    println()
    println("Result: ", passed ? "PASS" : "FAIL", " (", round(process.elapsed_seconds; digits=3), " seconds)")
    !passed && !isempty(message) && println("Reason: ", message)
    result, ValidationProcessRecord(entry, process.elapsed_seconds, message)
end

function print_validation_suite_summary(
    result::ValidationSuiteResult,
    process_records,
)
    elapsed = sum(record -> record.elapsed_seconds, process_records)

    println()
    println("================================================================")
    println(result.title)
    println("================================================================")

    for (case_result, process_record) in zip(result.cases, process_records)
        status = case_result.status == case_pass ? "PASS" : "FAIL"
        println(
            rpad(string(case_result.definition.case_id), 43),
            rpad(status, 7),
            round(process_record.elapsed_seconds; digits=3),
            " seconds",
        )
    end

    println("----------------------------------------------------------------")
    println("Cases passed:   ", result.passed_count, "/", length(result.cases))
    println("Elapsed time:   ", round(elapsed; digits=3), " seconds")
    println("Overall status: ", result.status == suite_pass ? "PASS" : "FAIL")

    failures = [
        (case_result, process_record) for (case_result, process_record) in
        zip(result.cases, process_records) if case_result.status != case_pass
    ]
    if !isempty(failures)
        println()
        println("Failed cases")
        for (case_result, process_record) in failures
            message = isempty(process_record.message) ? string(case_result.status) : process_record.message
            println("  ", case_result.definition.case_id, ": ", message)
        end
    end

    result.status == suite_pass
end

function run_validation_suite(
    entries=VALIDATION_SUITE_ENTRIES;
    report_path=resolve_validation_suite_report_path(),
)
    isempty(entries) && throw(ArgumentError("The validation suite must contain at least one case."))

    environment = current_validation_environment()
    mktempdir() do report_directory
        executed = [
            run_validation_entry(entry, environment, report_directory) for entry in entries
        ]
        cases = first.(executed)
        process_records = last.(executed)
        result = build_validation_suite_result(cases, environment)
        written_report = write_validation_suite_report(result, report_path)
        passed = print_validation_suite_summary(result, process_records)
        !isnothing(written_report) && println("Structured report: ", written_report)
        (; passed, result, process_records, report_path=written_report)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    validation_suite = run_validation_suite()
    validation_suite.passed || exit(1)
end

# Run the complete ThreeBody3D scientific validation suite.
#
# Each validation case is executed in a separate Julia process. This preserves
# the behaviour of the existing standalone examples, prevents global names from
# leaking between cases, and makes a failing case easy to reproduce directly.

struct ValidationSuiteEntry
    name::Symbol
    description::String
    path::String
end

struct ValidationSuiteResult
    entry::ValidationSuiteEntry
    passed::Bool
    elapsed_seconds::Float64
    message::String
end

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
        joinpath(@__DIR__, "..", "long_duration_switching_validation.jl"),
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
)

function validation_command(path)
    project_root = normpath(joinpath(@__DIR__, "..", ".."))
    `$(Base.julia_cmd()) --project=$project_root $path`
end

function run_validation_entry(entry)
    println()
    println("================================================================")
    println("Validation case: ", entry.name)
    println(entry.description)
    println("File: ", relpath(entry.path, pwd()))
    println("================================================================")

    if !isfile(entry.path)
        message = "Validation file does not exist: $(entry.path)"
        println("ERROR: ", message)
        return ValidationSuiteResult(entry, false, 0.0, message)
    end

    started = time()
    try
        run(validation_command(entry.path))
        elapsed = time() - started
        println()
        println("Result: PASS (", round(elapsed; digits=3), " seconds)")
        ValidationSuiteResult(entry, true, elapsed, "")
    catch exception
        elapsed = time() - started
        message = sprint(showerror, exception)
        println()
        println("Result: FAIL (", round(elapsed; digits=3), " seconds)")
        println("Reason: ", message)
        ValidationSuiteResult(entry, false, elapsed, message)
    end
end

function print_validation_suite_summary(results)
    passed = count(result -> result.passed, results)
    total = length(results)
    elapsed = sum(result -> result.elapsed_seconds, results)

    println()
    println("================================================================")
    println("ThreeBody3D scientific validation suite")
    println("================================================================")

    for result in results
        status = result.passed ? "PASS" : "FAIL"
        println(
            rpad(string(result.entry.name), 43),
            rpad(status, 7),
            round(result.elapsed_seconds; digits=3),
            " seconds",
        )
    end

    println("----------------------------------------------------------------")
    println("Cases passed:   ", passed, "/", total)
    println("Elapsed time:   ", round(elapsed; digits=3), " seconds")
    println("Overall status: ", passed == total ? "PASS" : "FAIL")

    failures = filter(result -> !result.passed, results)
    if !isempty(failures)
        println()
        println("Failed cases")
        for result in failures
            println("  ", result.entry.name, ": ", result.message)
        end
    end

    passed == total
end

function run_validation_suite(entries=VALIDATION_SUITE_ENTRIES)
    isempty(entries) &&
        throw(ArgumentError("The validation suite must contain at least one case."))

    results = [run_validation_entry(entry) for entry in entries]
    passed = print_validation_suite_summary(results)
    (; passed, results)
end

validation_suite = run_validation_suite()

validation_suite.passed || exit(1)

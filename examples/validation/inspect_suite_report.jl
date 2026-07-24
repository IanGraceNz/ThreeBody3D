# Inspect the retained metric values in one deterministic validation-suite report.
#
# Usage from the repository root:
#
#   julia --project=. examples/validation/inspect_suite_report.jl \
#       validation_reports/current-suite.toml

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const INSPECT_SUITE_USAGE = """
Usage:
  julia --project=. examples/validation/inspect_suite_report.jl SUITE_REPORT

Print every validation case and metric in retained suite order, including the
metric identifier, value, kind, role, scale, aggregation, and units. This is a
review aid only; it does not create or modify a reference record.
"""

inspect_suite_usage() = INSPECT_SUITE_USAGE

function _review_value(value)
    value isa AbstractString && return repr(value)
    value isa Symbol && return ":" * String(value)
    repr(value)
end

function inspect_suite_report(source; io::IO=stdout)
    suite = read_suite_report(source)
    println(io, "Suite: ", suite.suite_id)
    println(io, "Status: ", stable_string(suite.status))
    println(io, "Cases: ", length(suite.cases))

    for case_result in suite.cases
        println(io)
        println(
            io,
            "[",
            case_result.definition.case_id,
            "] status=",
            stable_string(case_result.status),
        )
        for metric in case_result.metrics
            units = isnothing(metric.units) ? "-" : metric.units
            println(
                io,
                "  ",
                metric.metric_id,
                " = ",
                _review_value(metric.value),
                " | kind=",
                stable_string(metric.kind),
                " role=",
                stable_string(metric.role),
                " scale=",
                stable_string(metric.scale),
                " aggregation=",
                stable_string(metric.aggregation),
                " units=",
                units,
            )
        end
    end

    suite
end

if abspath(PROGRAM_FILE) == @__FILE__
    if isempty(ARGS) || ARGS[1] in ("-h", "--help")
        print(stderr, inspect_suite_usage())
        isempty(ARGS) && exit(2)
        exit(0)
    end
    length(ARGS) == 1 || throw(ArgumentError(
        "Expected exactly one SUITE_REPORT argument. Run with --help for usage.",
    ))
    inspect_suite_report(ARGS[1])
end

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const CLOSE_ENCOUNTER_WORKFLOW_USAGE =
    "Usage: julia --project=. examples/validation/run_investigation_2_close_encounter.jl [output-directory]"

if length(ARGS) > 1
    println(stderr, CLOSE_ENCOUNTER_WORKFLOW_USAGE)
    exit(2)
end

output_directory = isempty(ARGS) ?
    joinpath(@__DIR__, "..", "..", "validation_reports", "investigation_2") :
    only(ARGS)

result = run_investigation_2_close_encounter(; output_directory)

println("Retained reports:")
for path in result.report_paths
    println("  ", path)
end

println("Operational failures:")
if isempty(result.failures)
    println("  none")
else
    for failure in result.failures
        println("  ", failure.label, " [", failure.outcome, "]: ", failure.message)
        isnothing(failure.exit_code) ||
            println("    exit code: ", failure.exit_code)
        isnothing(failure.raw_report_path) ||
            println("    malformed report: ", failure.raw_report_path)
        isnothing(failure.diagnostic_path) ||
            println("    exception diagnostic: ", failure.diagnostic_path)
    end
end

exit(result.exit_code)

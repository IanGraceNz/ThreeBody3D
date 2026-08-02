include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

length(ARGS) <= 1 || error("Usage: julia --project=. examples/validation/run_investigation_2_core.jl [output-directory]")

output_directory = isempty(ARGS) ?
    joinpath(@__DIR__, "..", "..", "validation_reports", "investigation_2") :
    ARGS[1]

result = run_investigation_2_core(; output_directory)

println("Retained reports:")
for path in result.report_paths
    println("  ", path)
end
println("Precision trigger: ", isnothing(result.trigger) ? "unavailable" : result.trigger.status)
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

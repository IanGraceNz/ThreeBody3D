include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

output_directory = isempty(ARGS) ?
    joinpath("validation_reports", "investigation_1") : first(ARGS)

result = run_investigation_1_baseline(output_directory)
println("Investigation 1 series reports:")
for path in result.report_paths
    println("  ", path)
end
println("Investigation 1 baseline report: ", result.markdown_path)
println("Reproducibility: ", result.reproducibility.passed ? "PASS" : "FAIL")
for mismatch in result.reproducibility.mismatches
    println("  ", mismatch)
end
exit(result.exit_code)

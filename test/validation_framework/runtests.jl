using Test

include(joinpath(@__DIR__, "..", "..", "examples", "validation", "framework", "ValidationFramework.jl"))
using .ValidationFramework

include("types.jl")

include("criteria.jl")

include("case_results.jl")

include("suite_results.jl")

include("serialization.jl")

include("console_presentation.jl")

include("case_protocol.jl")

include("suite_runner.jl")

include("reference_records.jl")

include("reference_comparison.jl")

include("reference_workflow.jl")

include("core_benchmark_cases.jl")

include("close_encounter_case.jl")

include("triple_collision_case.jl")

include("randomized_regression_case.jl")

include("ks_kepler_case.jl")

include("ks_collision_continuation_case.jl")

include("ks_levi_civita_comparison_case.jl")

include("ks_hierarchical_triple_case.jl")

include("ks_switching_comparison_case.jl")

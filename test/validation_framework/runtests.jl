using Test

include(joinpath(@__DIR__, "..", "..", "examples", "validation", "framework", "ValidationFramework.jl"))
using .ValidationFramework

include("types.jl")

include("criteria.jl")

include("case_results.jl")

include("suite_results.jl")

include("serialization.jl")

include("console_presentation.jl")

include("Reports.jl")
include("FigureEight.jl")

"""Return the names currently supported by [`run_validation_benchmark`](@ref)."""
validation_benchmark_names() = (:figure_eight,)

"""
    run_validation_benchmark(:figure_eight; periods=1, solver=:accurate,
                             saveat=0.01, kwargs...)

Run a named scientific validation problem and return a common
[`ValidationBenchmarkReport`](@ref). The current implementation formalizes the
standard equal-mass figure-eight choreography. `periods` selects the number of
reference periods in the integration interval. Additional keywords are
forwarded to [`simulate`](@ref).
"""
function run_validation_benchmark(
    name::Symbol;
    periods::Integer=1,
    solver::Symbol=:accurate,
    saveat::Real=0.01,
    kwargs...,
)
    name in validation_benchmark_names() || throw(ArgumentError(
        "Unknown validation benchmark $name. Available benchmarks: " *
        join(string.(validation_benchmark_names()), ", "),
    ))
    periods > 0 || throw(ArgumentError("periods must be positive."))
    isfinite(saveat) && saveat > 0 || throw(ArgumentError("saveat must be finite and positive."))
    solver in (:fast, :accurate, :extreme) || throw(ArgumentError(
        "solver must be :fast, :accurate, or :extreme.",
    ))

    _run_figure_eight_benchmark(periods, solver, saveat; kwargs...)
end

include("Reports.jl")
include("FigureEight.jl")
include("HierarchicalTriple.jl")

"""Return the names currently supported by [`run_validation_benchmark`](@ref)."""
validation_benchmark_names() = (:figure_eight, :hierarchical_triple)

"""
    run_validation_benchmark(name; solver=:accurate, saveat=0.01, kwargs...)

Run a named scientific validation problem and return a common
[`ValidationBenchmarkReport`](@ref).

For `:figure_eight`, use `periods` to select the number of reference periods.
For `:hierarchical_triple`, use `duration` to select the physical integration
interval; its default is [`HIERARCHICAL_TRIPLE_DURATION`](@ref). Additional
keywords are forwarded to [`simulate`](@ref).
"""
function run_validation_benchmark(
    name::Symbol;
    periods::Integer=1,
    duration::Union{Nothing,Real}=nothing,
    solver::Symbol=:accurate,
    saveat::Real=0.01,
    kwargs...,
)
    name in validation_benchmark_names() || throw(ArgumentError(
        "Unknown validation benchmark $name. Available benchmarks: " *
        join(string.(validation_benchmark_names()), ", "),
    ))
    isfinite(saveat) && saveat > 0 || throw(ArgumentError("saveat must be finite and positive."))
    solver in (:fast, :accurate, :extreme) || throw(ArgumentError(
        "solver must be :fast, :accurate, or :extreme.",
    ))

    if name === :figure_eight
        periods > 0 || throw(ArgumentError("periods must be positive."))
        duration === nothing || throw(ArgumentError(
            "duration is not used by the figure-eight benchmark; specify periods instead.",
        ))
        return _run_figure_eight_benchmark(periods, solver, saveat; kwargs...)
    end

    benchmark_duration = duration === nothing ? HIERARCHICAL_TRIPLE_DURATION : duration
    isfinite(benchmark_duration) && benchmark_duration > 0 || throw(ArgumentError(
        "duration must be finite and positive.",
    ))
    _run_hierarchical_triple_benchmark(benchmark_duration, solver, saveat; kwargs...)
end

"""Repository-internal counterpart retaining the requested saved physical trajectory."""
function _run_validation_benchmark_execution(
    name::Symbol; periods::Integer=1, duration::Union{Nothing,Real}=nothing,
    solver::Symbol=:accurate, saveat::Real=0.01, kwargs...,
)
    name in validation_benchmark_names() || throw(ArgumentError("Unknown validation benchmark $name."))
    isfinite(saveat) && saveat > 0 || throw(ArgumentError("saveat must be finite and positive."))
    solver in (:fast, :accurate, :extreme) || throw(ArgumentError("Unsupported solver selector $solver."))
    if name === :figure_eight
        periods > 0 || throw(ArgumentError("periods must be positive."))
        isnothing(duration) || throw(ArgumentError("duration is not used by figure-eight."))
        return _run_figure_eight_benchmark_execution(periods, solver, saveat; kwargs...)
    end
    benchmark_duration = isnothing(duration) ? HIERARCHICAL_TRIPLE_DURATION : duration
    isfinite(benchmark_duration) && benchmark_duration > 0 || throw(ArgumentError("duration must be finite and positive."))
    _run_hierarchical_triple_benchmark_execution(benchmark_duration, solver, saveat; kwargs...)
end

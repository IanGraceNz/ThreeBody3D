const FIGURE_EIGHT_PERIOD = 6.32591398

"""Return the names currently supported by [`run_validation_benchmark`](@ref)."""
validation_benchmark_names() = (:figure_eight,)

"""
    ValidationBenchmarkReport

Common scientific and solver-work summary returned by
[`run_validation_benchmark`](@ref). `diagnostics` contains the full conservation
report for the run, while `periodicity_error` measures return to the initial
state after the complete requested interval.
"""
struct ValidationBenchmarkReport{T,D}
    name::Symbol
    status::Symbol
    profile::Symbol
    initial_time::T
    final_time::T
    expected_final_time::T
    diagnostics::D
    periodicity_error::T
    saved_states::Int
    accepted_steps::Int
    rejected_steps::Int
    rhs_evaluations::Int
end

function Base.show(io::IO, report::ValidationBenchmarkReport)
    println(io, "ThreeBody3D validation benchmark: ", report.name)
    println(io, "  status:                        ", report.status)
    println(io, "  profile:                       ", report.profile)
    println(io, "  initial time:                  ", report.initial_time)
    println(io, "  final time:                    ", report.final_time)
    println(io, "  expected final time:           ", report.expected_final_time)
    println(io, "  saved states:                  ", report.saved_states)
    println(io, "  accepted internal steps:       ", report.accepted_steps)
    println(io, "  rejected internal steps:       ", report.rejected_steps)
    println(io, "  RHS evaluations:               ", report.rhs_evaluations)
    println(io, "  maximum relative energy drift: ", report.diagnostics.maximum_relative_energy_drift)
    println(io, "  maximum momentum drift:        ", report.diagnostics.maximum_linear_momentum_drift)
    println(io, "  maximum angular momentum drift:", report.diagnostics.maximum_angular_momentum_drift)
    println(io, "  maximum COM residual:          ", report.diagnostics.maximum_center_of_mass_residual)
    println(io, "  minimum pair separation:       ", report.diagnostics.minimum_separation)
    print(io, "  periodicity error:              ", report.periodicity_error)
end

function _figure_eight_benchmark_inputs(::Type{T}=Float64) where {T<:AbstractFloat}
    system = ThreeBodySystem((one(T), one(T), one(T)); G=one(T))
    u0 = statevector(
        T[-0.97000436,  0.24308753, 0.0], T[ 0.466203685,  0.432365730, 0.0],
        T[ 0.97000436, -0.24308753, 0.0], T[ 0.466203685,  0.432365730, 0.0],
        T[0.0, 0.0, 0.0],             T[-0.93240737, -0.86473146, 0.0],
    )
    system, u0, T(FIGURE_EIGHT_PERIOD)
end

"""
    run_validation_benchmark(:figure_eight; periods=1, solver=:accurate,
                             saveat=0.01, kwargs...)

Run a named scientific validation problem and return a common
[`ValidationBenchmarkReport`](@ref). The initial implementation formalizes the
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

    system, u0, period = _figure_eight_benchmark_inputs()
    expected_final_time = periods * period
    result = simulate(
        system,
        u0,
        (zero(period), expected_final_time);
        solver,
        saveat,
        kwargs...,
    )
    diagnostics = diagnostics_report(result)
    stats = result.solution.stats
    final_time = last(result.solution.t)
    status = terminated_by_close_approach(result) ? :terminated_close_approach : :completed

    ValidationBenchmarkReport(
        name,
        status,
        solver,
        first(result.solution.t),
        final_time,
        expected_final_time,
        diagnostics,
        periodicity_error(result, expected_final_time),
        length(result.solution.t),
        Int(stats.naccept),
        Int(stats.nreject),
        Int(stats.nf),
    )
end

"""
    ValidationBenchmarkReport

Common scientific and solver-work summary returned by
[`run_validation_benchmark`](@ref). `diagnostics` contains the full conservation
report for the run. `periodicity_error` is finite for periodic benchmarks and
`NaN` otherwise; `benchmark_metrics` stores named benchmark-specific measures.
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
    benchmark_metrics::NamedTuple
    saved_states::Int
    accepted_steps::Int
    rejected_steps::Int
    rhs_evaluations::Int
end

"""Repository-internal benchmark result with transient saved trajectory evidence."""
struct CoreValidationBenchmarkExecution{R,T,S,Y,U}
    report::R
    times::T
    states::S
    system::Y
    initial_state::U
end

"""Repository-internal benchmark result retaining only direct grid evidence."""
struct CoreValidationBenchmarkObservation{R,T,Y,U}
    report::R
    times::T
    system::Y
    initial_state::U
end

function _snapshot_core_validation_execution(report, result)
    CoreValidationBenchmarkExecution(
        report,
        copy(result.solution.t),
        [copy(state) for state in result.solution.u],
        result.system,
        copy(first(result.solution.u)),
    )
end


function _snapshot_core_validation_observation(report, result)
    CoreValidationBenchmarkObservation(
        report, copy(result.solution.t), result.system, copy(first(result.solution.u)))
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
    if isfinite(report.periodicity_error)
        println(io, "  periodicity error:              ", report.periodicity_error)
    end
    for (name, value) in pairs(report.benchmark_metrics)
        label = replace(string(name), '_' => ' ')
        println(io, "  ", rpad(label * ":", 31), value)
    end
end

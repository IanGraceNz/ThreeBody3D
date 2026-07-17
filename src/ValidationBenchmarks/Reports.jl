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

"""
    periodicity_error(result, period; relative=true)

Measure how closely the interpolated state at one period returns to the initial
state. The requested period must lie within the integration interval. By
default, returns `norm(u(t₀ + period) - u(t₀)) / norm(u(t₀))`; set
`relative=false` for the absolute state-space norm.
"""
function periodicity_error(result::SimulationResult, period::Real; relative::Bool=true)
    period > 0 || throw(ArgumentError("period must be positive."))
    sol = result.solution
    t0 = first(sol.t)
    target = t0 + period
    target <= last(sol.t) || throw(ArgumentError("The requested period extends beyond the simulation interval."))
    u0 = first(sol.u)
    error_norm = norm(sol(target) - u0)
    relative || return error_norm
    scale = norm(u0)
    iszero(scale) ? error_norm : error_norm / scale
end

@inline function _pair_separations(u)
    (
        norm(body_position(u, 2) - body_position(u, 1)),
        norm(body_position(u, 3) - body_position(u, 1)),
        norm(body_position(u, 3) - body_position(u, 2)),
    )
end

"""
    CloseApproachReport

Closest sampled approach in a simulation. `pair` contains the body indices,
`time` is the corresponding saved time, and `detected` indicates whether the
minimum is at or below the requested threshold.
"""
struct CloseApproachReport{T}
    threshold::T
    detected::Bool
    minimum_separation::T
    time::T
    pair::Tuple{Int,Int}
end

"""
    close_approach_report(result; threshold)

Search all saved states for the closest pairwise approach and report whether it
crosses `threshold`. This is a sampled diagnostic, not collision
regularization; use a sufficiently dense `saveat` when resolving close
encounters.
"""
function close_approach_report(result::SimulationResult; threshold::Real)
    threshold > 0 || throw(ArgumentError("threshold must be positive."))
    sol = result.solution
    T = promote_type(eltype(first(sol.u)), typeof(float(threshold)), eltype(sol.t))
    best_distance = T(Inf)
    best_time = T(first(sol.t))
    best_pair = (1, 2)
    pairs = ((1, 2), (1, 3), (2, 3))

    for (t, u) in zip(sol.t, sol.u)
        distances = _pair_separations(u)
        index = argmin(distances)
        if distances[index] < best_distance
            best_distance = T(distances[index])
            best_time = T(t)
            best_pair = pairs[index]
        end
    end

    converted_threshold = T(threshold)
    CloseApproachReport(converted_threshold, best_distance <= converted_threshold,
                        best_distance, best_time, best_pair)
end

"""
    SolverBenchmark

Accuracy and work summary for one solver profile in [`benchmark_solvers`](@ref).
"""
struct SolverBenchmark{T}
    profile::Symbol
    algorithm::String
    saved_states::Int
    accepted_steps::Int
    rejected_steps::Int
    maximum_relative_energy_drift::T
    maximum_linear_momentum_drift::T
    maximum_angular_momentum_drift::T
    maximum_center_of_mass_residual::T
    minimum_separation::T
    periodicity_error::Union{Nothing,T}
end

"""
    benchmark_solvers(system, u0, tspan; profiles=(:fast, :accurate, :extreme),
                      saveat=nothing, period=nothing, kwargs...)

Run the same initial-value problem with each named accuracy profile and return a
vector of [`SolverBenchmark`](@ref) records. Optional `period` adds a
periodicity-return error. Remaining keywords are forwarded to [`simulate`](@ref).
"""
function benchmark_solvers(system::ThreeBodySystem, u0::AbstractVector,
                           tspan::Tuple{<:Real,<:Real};
                           profiles=(:fast, :accurate, :extreme), saveat=nothing,
                           period=nothing, kwargs...)
    isempty(profiles) && throw(ArgumentError("profiles must not be empty."))
    benchmarks = SolverBenchmark[]

    for profile_name in profiles
        profile_name isa Symbol || throw(ArgumentError("Each profile name must be a Symbol."))
        profile = accuracy_profile(profile_name)
        result = simulate(system, u0, tspan; solver=profile_name, saveat, kwargs...)
        report = diagnostics_report(result)
        stats = result.solution.destats
        periodic_error = isnothing(period) ? nothing : periodicity_error(result, period)
        T = typeof(report.maximum_relative_energy_drift)
        push!(benchmarks, SolverBenchmark{T}(
            profile_name,
            string(typeof(profile.algorithm)),
            length(result.solution.t),
            Int(stats.naccept),
            Int(stats.nreject),
            report.maximum_relative_energy_drift,
            report.maximum_linear_momentum_drift,
            report.maximum_angular_momentum_drift,
            report.maximum_center_of_mass_residual,
            report.minimum_separation,
            isnothing(periodic_error) ? nothing : T(periodic_error),
        ))
    end

    benchmarks
end

"""
    periodicity_error(result, period; relative=true)

Measure how closely the interpolated state at one period returns to the initial
state. The requested period must lie within the integration interval. By
default, returns `norm(u(t₀ + period) - u(t₀)) / norm(u(t₀))`; set
`relative=false` for the absolute state-space norm.

This measures consistency with the supplied initial conditions and period. It
cannot be more accurate than those benchmark values themselves.
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

@inline function _pair_separation(u, pair::Tuple{Int,Int})
    norm(body_position(u, pair[2]) - body_position(u, pair[1]))
end

function _golden_section_minimum(f, a, b; iterations::Int=48)
    T = promote_type(typeof(a), typeof(b))
    ϕ = (sqrt(T(5)) - one(T)) / T(2)
    c = b - ϕ * (b - a)
    d = a + ϕ * (b - a)
    fc, fd = f(c), f(d)
    for _ in 1:iterations
        if fc <= fd
            b, d, fd = d, c, fc
            c = b - ϕ * (b - a)
            fc = f(c)
        else
            a, c, fc = c, d, fd
            d = a + ϕ * (b - a)
            fd = f(d)
        end
    end
    t = (a + b) / 2
    t, f(t)
end

"""
    CloseApproachReport

Closest pairwise approach found in a simulation. `pair` contains the body
indices, `time` is the estimated time of closest approach, and `detected`
indicates whether the minimum is at or below the requested threshold.
"""
struct CloseApproachReport{T}
    threshold::T
    detected::Bool
    minimum_separation::T
    time::T
    pair::Tuple{Int,Int}
end

function Base.show(io::IO, report::CloseApproachReport)
    print(io, "CloseApproachReport(threshold=", report.threshold,
          ", detected=", report.detected,
          ", minimum_separation=", report.minimum_separation,
          ", time=", report.time,
          ", pair=", report.pair, ")")
end

"""
    close_approach_report(result; threshold, refine=true)

Find the closest pairwise approach and report whether it crosses `threshold`.
The saved states first identify a candidate interval and body pair. With
`refine=true` (the default), dense solution interpolation and a bounded
golden-section search refine the time and separation within the neighbouring
saved-time interval.

This is a diagnostic, not collision regularization. It assumes the candidate
minimum is bracketed by saved states; use a sufficiently dense `saveat` for
close-encounter studies.
"""
function close_approach_report(result::SimulationResult; threshold::Real,
                               refine::Bool=true)
    threshold > 0 || throw(ArgumentError("threshold must be positive."))
    sol = result.solution
    T = promote_type(eltype(first(sol.u)), typeof(float(threshold)), eltype(sol.t))
    best_distance = T(Inf)
    best_time = T(first(sol.t))
    best_pair = (1, 2)
    best_index = 1
    pairs = ((1, 2), (1, 3), (2, 3))

    for (index_t, (t, u)) in enumerate(zip(sol.t, sol.u))
        distances = _pair_separations(u)
        index_pair = argmin(distances)
        if distances[index_pair] < best_distance
            best_distance = T(distances[index_pair])
            best_time = T(t)
            best_pair = pairs[index_pair]
            best_index = index_t
        end
    end

    if refine && length(sol.t) >= 2
        left_index = max(1, best_index - 1)
        right_index = min(length(sol.t), best_index + 1)
        a, b = sol.t[left_index], sol.t[right_index]
        if b > a
            f(t) = _pair_separation(sol(t), best_pair)
            refined_time, refined_distance = _golden_section_minimum(f, a, b)
            if refined_distance < best_distance
                best_time = T(refined_time)
                best_distance = T(refined_distance)
            end
        end
    end

    converted_threshold = T(threshold)
    CloseApproachReport(converted_threshold, best_distance <= converted_threshold,
                        best_distance, best_time, best_pair)
end

"""
    SolverBenchmark

Accuracy and work summary for one solver profile in [`benchmark_solvers`](@ref).
`saved_states` is output storage, while `accepted_steps`, `rejected_steps`, and
`rhs_evaluations` describe internal integration work.
"""
struct SolverBenchmark{T}
    profile::Symbol
    algorithm::String
    saved_states::Int
    accepted_steps::Int
    rejected_steps::Int
    rhs_evaluations::Int
    elapsed_seconds::Float64
    maximum_relative_energy_drift::T
    maximum_linear_momentum_drift::T
    maximum_angular_momentum_drift::T
    maximum_center_of_mass_residual::T
    minimum_separation::T
    periodicity_error::Union{Nothing,T}
end

function Base.show(io::IO, benchmark::SolverBenchmark)
    println(io, "Solver benchmark: ", benchmark.profile)
    println(io, "  algorithm:                     ", benchmark.algorithm)
    println(io, "  saved states:                  ", benchmark.saved_states)
    println(io, "  accepted internal steps:       ", benchmark.accepted_steps)
    println(io, "  rejected internal steps:       ", benchmark.rejected_steps)
    println(io, "  RHS evaluations:               ", benchmark.rhs_evaluations)
    println(io, "  elapsed seconds:               ", benchmark.elapsed_seconds)
    println(io, "  maximum relative energy drift: ", benchmark.maximum_relative_energy_drift)
    println(io, "  maximum momentum drift:        ", benchmark.maximum_linear_momentum_drift)
    println(io, "  maximum angular momentum drift:", benchmark.maximum_angular_momentum_drift)
    println(io, "  maximum COM residual:          ", benchmark.maximum_center_of_mass_residual)
    println(io, "  minimum pair separation:       ", benchmark.minimum_separation)
    print(io, "  periodicity error:              ", benchmark.periodicity_error)
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
        started = time_ns()
        result = simulate(system, u0, tspan; solver=profile_name, saveat, kwargs...)
        elapsed_seconds = (time_ns() - started) / 1.0e9
        report = diagnostics_report(result)
        stats = result.solution.stats
        periodic_error = isnothing(period) ? nothing : periodicity_error(result, period)
        T = typeof(report.maximum_relative_energy_drift)
        push!(benchmarks, SolverBenchmark{T}(
            profile_name,
            string(typeof(profile.algorithm)),
            length(result.solution.t),
            Int(stats.naccept),
            Int(stats.nreject),
            Int(stats.nf),
            elapsed_seconds,
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

const _HIGH_PRECISION_ALGORITHMS = (
    vern9 = Vern9(),
    feagin12 = Feagin12(),
    feagin14 = Feagin14(),
)

"""
    benchmark_extreme_solvers(system, u0, tspan;
                              algorithms=(:vern9, :feagin12, :feagin14),
                              precision=256, reltol="1e-30", abstol="1e-30",
                              saveat=nothing, period=nothing, kwargs...)

Compare candidate arbitrary-precision reference solvers on the same problem.
All integrations use `BigFloat` inside a scoped `precision`-bit context.
`reltol` and `abstol` may be real numbers or decimal strings; strings are
recommended because they avoid prior Float64 rounding.

The returned [`SolverBenchmark`](@ref) records use profile labels `:vern9`,
`:feagin12`, and `:feagin14`. This routine benchmarks candidates; it does not
assume that the highest formal order is the most efficient or most accurate in
practice.
"""
function benchmark_extreme_solvers(system::ThreeBodySystem, u0::AbstractVector,
                                   tspan::Tuple{<:Real,<:Real};
                                   algorithms=(:vern9, :feagin12, :feagin14),
                                   precision::Integer=256,
                                   reltol="1e-30", abstol="1e-30",
                                   saveat=nothing, period=nothing, kwargs...)
    precision >= 64 || throw(ArgumentError("precision must be at least 64 bits."))
    isempty(algorithms) && throw(ArgumentError("algorithms must not be empty."))

    setprecision(BigFloat, precision) do
        rt = reltol isa AbstractString ? parse(BigFloat, reltol) : BigFloat(reltol)
        at = abstol isa AbstractString ? parse(BigFloat, abstol) : BigFloat(abstol)
        rt > 0 || throw(ArgumentError("reltol must be positive."))
        at > 0 || throw(ArgumentError("abstol must be positive."))
        converted_period = isnothing(period) ? nothing : BigFloat(period)
        benchmarks = SolverBenchmark[]

        for name in algorithms
            name isa Symbol || throw(ArgumentError("Each algorithm name must be a Symbol."))
            hasproperty(_HIGH_PRECISION_ALGORITHMS, name) ||
                throw(ArgumentError("Unknown high-precision algorithm $name. Use :vern9, :feagin12, or :feagin14."))
            algorithm = getproperty(_HIGH_PRECISION_ALGORITHMS, name)
            started = time_ns()
            result = _simulate_impl(system, u0, tspan;
                                    solver=algorithm, reltol=rt, abstol=at,
                                    precision, force_bigfloat=true, saveat,
                                    kwargs...)
            elapsed_seconds = (time_ns() - started) / 1.0e9
            report = diagnostics_report(result)
            stats = result.solution.stats
            periodic_error = isnothing(converted_period) ? nothing :
                periodicity_error(result, converted_period)
            T = typeof(report.maximum_relative_energy_drift)
            push!(benchmarks, SolverBenchmark{T}(
                name,
                string(typeof(algorithm)),
                length(result.solution.t),
                Int(stats.naccept),
                Int(stats.nreject),
                Int(stats.nf),
                elapsed_seconds,
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
end

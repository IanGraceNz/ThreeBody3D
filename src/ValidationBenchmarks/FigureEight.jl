const FIGURE_EIGHT_PERIOD = 6.32591398

function _figure_eight_benchmark_inputs(::Type{T}=Float64) where {T<:AbstractFloat}
    system = ThreeBodySystem((one(T), one(T), one(T)); G=one(T))
    u0 = statevector(
        T[-0.97000436,  0.24308753, 0.0], T[ 0.466203685,  0.432365730, 0.0],
        T[ 0.97000436, -0.24308753, 0.0], T[ 0.466203685,  0.432365730, 0.0],
        T[0.0, 0.0, 0.0],             T[-0.93240737, -0.86473146, 0.0],
    )
    system, u0, T(FIGURE_EIGHT_PERIOD)
end

function _run_figure_eight_benchmark(
    periods::Integer,
    solver::Symbol,
    saveat::Real;
    kwargs...,
)
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
        :figure_eight,
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

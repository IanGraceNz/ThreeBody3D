const FIGURE_EIGHT_PERIOD = 6.32591398
const _FIGURE_EIGHT_CANONICAL_DECIMALS = (
    masses=("1", "1", "1"), gravitational_constant="1",
    positions=(("-0.97000436", "0.24308753", "0.0"),
               ("0.97000436", "-0.24308753", "0.0"),
               ("0.0", "0.0", "0.0")),
    velocities=(("0.466203685", "0.432365730", "0.0"),
                ("0.466203685", "0.432365730", "0.0"),
                ("-0.93240737", "-0.86473146", "0.0")),
    initial_time="0.0", period="6.32591398", tolerance="1e-30", saveat="0.02",
)

function _figure_eight_benchmark_inputs(::Type{T}=Float64) where {T<:AbstractFloat}
    system = ThreeBodySystem((one(T), one(T), one(T)); G=one(T))
    u0 = statevector(
        T[-0.97000436,  0.24308753, 0.0], T[ 0.466203685,  0.432365730, 0.0],
        T[ 0.97000436, -0.24308753, 0.0], T[ 0.466203685,  0.432365730, 0.0],
        T[0.0, 0.0, 0.0],             T[-0.93240737, -0.86473146, 0.0],
    )
    system, u0, T(FIGURE_EIGHT_PERIOD)
end

function _figure_eight_canonical_inputs(precision::Integer)
    precision >= 64 || throw(ArgumentError("precision must be at least 64 bits."))
    setprecision(BigFloat, precision) do
        canonical = _FIGURE_EIGHT_CANONICAL_DECIMALS
        parse_vector(values) = BigFloat[parse(BigFloat, value) for value in values]
        masses = Tuple(parse(BigFloat, value) for value in canonical.masses)
        system = ThreeBodySystem(masses; G=parse(BigFloat, canonical.gravitational_constant))
        u0 = statevector(
            parse_vector(canonical.positions[1]), parse_vector(canonical.velocities[1]),
            parse_vector(canonical.positions[2]), parse_vector(canonical.velocities[2]),
            parse_vector(canonical.positions[3]), parse_vector(canonical.velocities[3]),
        )
        (; system, initial_state=u0,
            initial_time=parse(BigFloat, canonical.initial_time),
            period=parse(BigFloat, canonical.period),
            tolerance=parse(BigFloat, canonical.tolerance),
            saveat=parse(BigFloat, canonical.saveat),
            canonical, precision_bits=precision)
    end
end

function _solve_figure_eight_benchmark(
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

    report = ValidationBenchmarkReport(
        :figure_eight,
        status,
        solver,
        first(result.solution.t),
        final_time,
        expected_final_time,
        diagnostics,
        periodicity_error(result, expected_final_time),
        NamedTuple(),
        length(result.solution.t),
        Int(stats.naccept),
        Int(stats.nreject),
        Int(stats.nf),
    )
    (; report, result)
end

_run_figure_eight_benchmark(args...; kwargs...) =
    _solve_figure_eight_benchmark(args...; kwargs...).report

function _run_figure_eight_benchmark_execution(args...;
    snapshotter=_snapshot_core_validation_execution, kwargs...)
    calculation = _solve_figure_eight_benchmark(args...; kwargs...)
    snapshotter(calculation.report, calculation.result)
end

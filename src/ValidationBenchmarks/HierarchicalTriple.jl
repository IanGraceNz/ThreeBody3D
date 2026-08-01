const HIERARCHICAL_TRIPLE_DURATION = 25.0

function _hierarchical_triple_benchmark_inputs(::Type{T}=Float64) where {T<:AbstractFloat}
    system = ThreeBodySystem((one(T), one(T), one(T)); G=one(T))

    inner_separation = one(T)
    outer_separation = T(10)
    inner_orbital_speed = sqrt(T(2) / inner_separation) / T(2)
    outer_relative_speed = sqrt(T(3) / outer_separation)
    inner_center_speed = outer_relative_speed / T(3)
    outer_body_speed = T(2) * outer_relative_speed / T(3)

    inner_center_x = -outer_separation / T(3)
    outer_body_x = T(2) * outer_separation / T(3)
    half_inner_separation = inner_separation / T(2)

    u0 = statevector(
        T[inner_center_x - half_inner_separation, 0, 0],
        T[0, inner_center_speed - inner_orbital_speed, 0],
        T[inner_center_x + half_inner_separation, 0, 0],
        T[0, inner_center_speed + inner_orbital_speed, 0],
        T[outer_body_x, 0, 0],
        T[0, -outer_body_speed, 0],
    )
    system, u0, T(HIERARCHICAL_TRIPLE_DURATION)
end

@inline function _hierarchy_ratio(system::ThreeBodySystem, state::AbstractVector)
    m1, m2 = system.masses[1], system.masses[2]
    r1 = body_position(state, 1)
    r2 = body_position(state, 2)
    r3 = body_position(state, 3)
    inner_separation = norm(r2 - r1)
    inner_center = (m1 * r1 + m2 * r2) / (m1 + m2)
    norm(r3 - inner_center) / inner_separation
end

function _solve_hierarchical_triple_benchmark(
    duration::Real,
    solver::Symbol,
    saveat::Real;
    kwargs...,
)
    system, u0, _ = _hierarchical_triple_benchmark_inputs()
    expected_final_time = Float64(duration)
    result = simulate(
        system,
        u0,
        (0.0, expected_final_time);
        solver,
        saveat,
        kwargs...,
    )
    diagnostics = diagnostics_report(result)
    stats = result.solution.stats
    final_time = last(result.solution.t)
    status = terminated_by_close_approach(result) ? :terminated_close_approach : :completed
    hierarchy_ratios = map(state -> _hierarchy_ratio(system, state), result.solution.u)

    report = ValidationBenchmarkReport(
        :hierarchical_triple,
        status,
        solver,
        first(result.solution.t),
        final_time,
        expected_final_time,
        diagnostics,
        oftype(final_time, NaN),
        (
            initial_hierarchy_ratio=first(hierarchy_ratios),
            minimum_hierarchy_ratio=minimum(hierarchy_ratios),
            final_hierarchy_ratio=last(hierarchy_ratios),
        ),
        length(result.solution.t),
        Int(stats.naccept),
        Int(stats.nreject),
        Int(stats.nf),
    )
    (; report, result)
end

_run_hierarchical_triple_benchmark(args...; kwargs...) =
    _solve_hierarchical_triple_benchmark(args...; kwargs...).report

function _run_hierarchical_triple_benchmark_execution(args...;
    snapshotter=_snapshot_core_validation_execution, kwargs...)
    calculation = _solve_hierarchical_triple_benchmark(args...; kwargs...)
    snapshotter(calculation.report, calculation.result)
end


function _run_hierarchical_triple_benchmark_observation(args...;
    observer=_snapshot_core_validation_observation, kwargs...)
    calculation = _solve_hierarchical_triple_benchmark(args...; kwargs...)
    observer(calculation.report, calculation.result)
end

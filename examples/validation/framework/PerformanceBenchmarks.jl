# Representative numerical adapters for the internal performance framework.

import ThreeBody3D

const PERFORMANCE_BENCHMARK_DEFINITION_VERSION = "1.0.0"

function figure_eight_performance_definition()
    PerformanceBenchmarkDefinition(
        :figure_eight_performance,
        "Figure-eight performance benchmark",
        "Descriptive timing and solver-work evidence for the package-owned figure-eight workload.",
        "examples/validation/performance/figure_eight_performance.jl",
        (:periodic_orbit, :conservation, :solver_work),
        (:figure_eight, :core_benchmark, :performance),
        PERFORMANCE_BENCHMARK_DEFINITION_VERSION,
        (:elapsed_time, :solver_statistics, :saved_states),
        "V0_5_PERFORMANCE_BENCHMARK_DESIGN.md",
    )
end

function hierarchical_triple_performance_definition()
    PerformanceBenchmarkDefinition(
        :hierarchical_triple_performance,
        "Hierarchical-triple performance benchmark",
        "Descriptive timing and solver-work evidence for the package-owned hierarchical-triple workload.",
        "examples/validation/performance/hierarchical_triple_performance.jl",
        (:hierarchical_system, :multiscale, :solver_work),
        (:hierarchical_triple, :core_benchmark, :performance),
        PERFORMANCE_BENCHMARK_DEFINITION_VERSION,
        (:elapsed_time, :solver_statistics, :saved_states),
        "V0_5_PERFORMANCE_BENCHMARK_DESIGN.md",
    )
end

function figure_eight_performance_configuration(; periods=10, solver=:accurate, saveat=0.02)
    ValidationConfiguration(
        solver=solver,
        time_interval=(0.0, ThreeBody3D.FIGURE_EIGHT_PERIOD * periods),
        sampling="saveat=$(saveat)",
        parameters=(
            ValidationParameter(:periods, periods),
            ValidationParameter(:saveat, saveat),
        ),
    )
end

function hierarchical_triple_performance_configuration(;
    duration=100.0,
    solver=:accurate,
    saveat=0.02,
    reltol=1e-13,
    abstol=1e-13,
)
    ValidationConfiguration(
        solver=solver,
        absolute_tolerance=abstol,
        relative_tolerance=reltol,
        time_interval=(0.0, duration),
        sampling="saveat=$(saveat)",
        parameters=(
            ValidationParameter(:duration, duration),
            ValidationParameter(:saveat, saveat),
        ),
    )
end

function _performance_observation(report)
    PerformanceObservation(
        solver_statistics=SolverStatistics(
            accepted_steps=report.accepted_steps,
            rejected_steps=report.rejected_steps,
            rhs_evaluations=report.rhs_evaluations,
            saved_states=report.saved_states,
        ),
        saved_states=report.saved_states,
        measurements=(
            ValidationMetric(
                :maximum_relative_energy_drift,
                "Maximum relative energy drift",
                Float64(report.diagnostics.maximum_relative_energy_drift);
                scale=scale_relative,
                role=role_descriptive,
                aggregation=aggregation_maximum,
            ),
            ValidationMetric(
                :minimum_pair_separation,
                "Minimum pair separation",
                Float64(report.diagnostics.minimum_separation);
                scale=scale_dimensional,
                role=role_descriptive,
                aggregation=aggregation_minimum,
            ),
        ),
    )
end

function figure_eight_performance_operation(; periods=10, solver=:accurate, saveat=0.02)
    () -> _performance_observation(ThreeBody3D.run_validation_benchmark(
        :figure_eight;
        periods,
        solver,
        saveat,
    ))
end

function hierarchical_triple_performance_operation(;
    duration=100.0,
    solver=:accurate,
    saveat=0.02,
    reltol=1e-13,
    abstol=1e-13,
)
    () -> _performance_observation(ThreeBody3D.run_validation_benchmark(
        :hierarchical_triple;
        duration,
        solver,
        saveat,
        reltol,
        abstol,
    ))
end

function representative_performance_entries(;
    policy=StandardBenchmark(),
    performance_directory=joinpath(@__DIR__, "..", "performance"),
)
    (
        PerformanceBenchmarkEntry(
            figure_eight_performance_definition(),
            figure_eight_performance_configuration(),
            policy,
            joinpath(performance_directory, "figure_eight_performance.jl"),
        ),
        PerformanceBenchmarkEntry(
            hierarchical_triple_performance_definition(),
            hierarchical_triple_performance_configuration(),
            policy,
            joinpath(performance_directory, "hierarchical_triple_performance.jl"),
        ),
    )
end

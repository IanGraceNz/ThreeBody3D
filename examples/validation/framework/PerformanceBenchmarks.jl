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
    () -> begin
        report = if isnothing(reltol) && isnothing(abstol)
            ThreeBody3D.run_validation_benchmark(
                :hierarchical_triple; duration, solver, saveat,
            )
        elseif isnothing(reltol) || isnothing(abstol)
            throw(ArgumentError("reltol and abstol must both be provided or both be nothing."))
        else
            ThreeBody3D.run_validation_benchmark(
                :hierarchical_triple; duration, solver, saveat, reltol, abstol,
            )
        end
        _performance_observation(report)
    end
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

const FIGURE_EIGHT_ACCURACY_WORK_POINTS = (:fast, :accurate)
const HIERARCHICAL_TRIPLE_ACCURACY_WORK_POINTS = (:fast, :accurate)

function _accuracy_work_definition(family::Symbol, point::Symbol)
    point in (:fast, :accurate) || throw(ArgumentError("Unsupported accuracy-work point: $point."))
    if family == :figure_eight
        return PerformanceBenchmarkDefinition(
            Symbol("figure_eight_accuracy_work_", point),
            "Figure-eight accuracy-versus-work: $(point)",
            "One fixed figure-eight configuration in the descriptive accuracy-versus-work series.",
            "examples/validation/performance/figure_eight_accuracy_work.jl",
            (:periodic_orbit, :accuracy_work, :solver_work),
            (:figure_eight, :accuracy_work, point),
            PERFORMANCE_BENCHMARK_DEFINITION_VERSION,
            (:elapsed_time, :solver_statistics, :saved_states, :maximum_relative_energy_drift),
            "V0_5_PERFORMANCE_BENCHMARK_DESIGN.md",
        )
    elseif family == :hierarchical_triple
        return PerformanceBenchmarkDefinition(
            Symbol("hierarchical_triple_accuracy_work_", point),
            "Hierarchical-triple accuracy-versus-work: $(point)",
            "One fixed hierarchical-triple configuration in the descriptive accuracy-versus-work series.",
            "examples/validation/performance/hierarchical_triple_accuracy_work.jl",
            (:hierarchical_system, :accuracy_work, :solver_work),
            (:hierarchical_triple, :accuracy_work, point),
            PERFORMANCE_BENCHMARK_DEFINITION_VERSION,
            (:elapsed_time, :solver_statistics, :saved_states, :maximum_relative_energy_drift),
            "V0_5_PERFORMANCE_BENCHMARK_DESIGN.md",
        )
    end
    throw(ArgumentError("Unsupported accuracy-work family: $family."))
end

figure_eight_accuracy_work_definition(point::Symbol) = _accuracy_work_definition(:figure_eight, point)
hierarchical_triple_accuracy_work_definition(point::Symbol) = _accuracy_work_definition(:hierarchical_triple, point)

function figure_eight_accuracy_work_entries(;
    policy=StandardBenchmark(),
    performance_directory=joinpath(@__DIR__, "..", "performance"),
    periods=10,
    saveat=0.02,
)
    Tuple(
        PerformanceBenchmarkEntry(
            figure_eight_accuracy_work_definition(point),
            figure_eight_performance_configuration(; periods, solver=point, saveat),
            policy,
            joinpath(performance_directory, "figure_eight_accuracy_work.jl"),
        ) for point in FIGURE_EIGHT_ACCURACY_WORK_POINTS
    )
end

function hierarchical_triple_accuracy_work_entries(;
    policy=StandardBenchmark(),
    performance_directory=joinpath(@__DIR__, "..", "performance"),
    duration=100.0,
    saveat=0.02,
)
    Tuple(
        PerformanceBenchmarkEntry(
            hierarchical_triple_accuracy_work_definition(point),
            hierarchical_triple_performance_configuration(;
                duration,
                solver=point,
                saveat,
                reltol=point == :accurate ? 1e-13 : nothing,
                abstol=point == :accurate ? 1e-13 : nothing,
            ),
            policy,
            joinpath(performance_directory, "hierarchical_triple_accuracy_work.jl"),
        ) for point in HIERARCHICAL_TRIPLE_ACCURACY_WORK_POINTS
    )
end

function representative_accuracy_work_entries(; policy=StandardBenchmark(), performance_directory=joinpath(@__DIR__, "..", "performance"))
    (
        figure_eight_accuracy_work_entries(; policy, performance_directory)...,
        hierarchical_triple_accuracy_work_entries(; policy, performance_directory)...,
    )
end

function figure_eight_accuracy_work_series(suite::PerformanceSuiteReport)
    build_accuracy_work_series(
        suite,
        :figure_eight_accuracy_work,
        "Figure-eight accuracy versus work",
        "Fixed fast and accurate solver profiles for the ten-period figure-eight workload.",
        :maximum_relative_energy_drift,
        ((:fast, "Fast profile", :figure_eight_accuracy_work_fast),
         (:accurate, "Accurate profile", :figure_eight_accuracy_work_accurate)),
    )
end

function hierarchical_triple_accuracy_work_series(suite::PerformanceSuiteReport)
    build_accuracy_work_series(
        suite,
        :hierarchical_triple_accuracy_work,
        "Hierarchical-triple accuracy versus work",
        "Fixed fast and accurate solver profiles for the 100-time-unit hierarchical workload.",
        :maximum_relative_energy_drift,
        ((:fast, "Fast profile", :hierarchical_triple_accuracy_work_fast),
         (:accurate, "Accurate profile", :hierarchical_triple_accuracy_work_accurate)),
    )
end

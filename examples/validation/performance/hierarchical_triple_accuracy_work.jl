using ThreeBody3D

include(joinpath(@__DIR__, "..", "framework", "ValidationFramework.jl"))
using .ValidationFramework

benchmark_id = Symbol(get(ENV, PERFORMANCE_BENCHMARK_ID_ENV, ""))
point = benchmark_id == :hierarchical_triple_accuracy_work_fast ? :fast :
        benchmark_id == :hierarchical_triple_accuracy_work_accurate ? :accurate :
        throw(ArgumentError("Unsupported hierarchical-triple accuracy-work benchmark ID: $benchmark_id."))

const POLICY = StandardBenchmark()
definition = hierarchical_triple_accuracy_work_definition(point)
if point == :accurate
    configuration = hierarchical_triple_performance_configuration(
        duration=100.0, solver=:accurate, saveat=0.02, reltol=1e-13, abstol=1e-13,
    )
    operation = hierarchical_triple_performance_operation(
        duration=100.0, solver=:accurate, saveat=0.02, reltol=1e-13, abstol=1e-13,
    )
else
    configuration = hierarchical_triple_performance_configuration(
        duration=100.0, solver=:fast, saveat=0.02, reltol=nothing, abstol=nothing,
    )
    operation = hierarchical_triple_performance_operation(
        duration=100.0, solver=:fast, saveat=0.02, reltol=nothing, abstol=nothing,
    )
end
protocol = resolve_performance_protocol(definition, VALIDATION_SCHEMA_VERSION)
result = run_performance_measurements(operation, POLICY)
report = build_performance_benchmark_report(
    definition,
    current_validation_environment(),
    configuration,
    POLICY,
    result.samples,
    result.execution,
)
exit_code = publish_performance_report(protocol, report; render=false)
exit_code == 0 || exit(exit_code)

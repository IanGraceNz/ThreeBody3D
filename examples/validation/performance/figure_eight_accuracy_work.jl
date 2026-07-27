using ThreeBody3D

include(joinpath(@__DIR__, "..", "framework", "ValidationFramework.jl"))
using .ValidationFramework

benchmark_id = Symbol(get(ENV, PERFORMANCE_BENCHMARK_ID_ENV, ""))
point = benchmark_id == :figure_eight_accuracy_work_fast ? :fast :
        benchmark_id == :figure_eight_accuracy_work_accurate ? :accurate :
        throw(ArgumentError("Unsupported figure-eight accuracy-work benchmark ID: $benchmark_id."))

const POLICY = StandardBenchmark()
definition = figure_eight_accuracy_work_definition(point)
configuration = figure_eight_performance_configuration(periods=10, solver=point, saveat=0.02)
operation = figure_eight_performance_operation(periods=10, solver=point, saveat=0.02)
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

using ThreeBody3D

include(joinpath(@__DIR__, "..", "framework", "ValidationFramework.jl"))
using .ValidationFramework

benchmark_id = Symbol(get(ENV, PERFORMANCE_BENCHMARK_ID_ENV, ""))
configuration = ValidationFramework.decode_close_encounter_cartesian_benchmark_id(benchmark_id)
definition = ValidationFramework.close_encounter_cartesian_performance_definition(configuration)
policy = StandardBenchmark()
protocol = resolve_performance_protocol(definition, VALIDATION_SCHEMA_VERSION)
measurement = run_performance_measurements(
    ValidationFramework.close_encounter_cartesian_performance_operation(configuration),
    policy,
)
report = build_performance_benchmark_report(
    definition,
    current_validation_environment(),
    ValidationFramework._close_cartesian_validation_configuration(configuration),
    policy,
    measurement.samples,
    measurement.execution,
)
exit_code = publish_performance_report(protocol, report; render=false)
exit_code == 0 || exit(exit_code)

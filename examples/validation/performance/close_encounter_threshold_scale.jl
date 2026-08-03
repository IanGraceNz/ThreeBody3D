using ThreeBody3D
include(joinpath(@__DIR__, "..", "framework", "ValidationFramework.jl"))
using .ValidationFramework

id_text = get(ENV, PERFORMANCE_BENCHMARK_ID_ENV, "")
isempty(id_text) && error("A close-encounter threshold-scale benchmark ID is required.")
decoded = ValidationFramework.decode_close_encounter_threshold_benchmark_id(Symbol(id_text))
definition = ValidationFramework.close_encounter_threshold_performance_definition(
    decoded.method, decoded.configuration)
configuration = ValidationFramework._close_regularized_validation_configuration(
    decoded.configuration, decoded.method)
policy = StandardBenchmark()
protocol = resolve_performance_protocol(definition, VALIDATION_SCHEMA_VERSION)
measurement = run_performance_measurements(
    ValidationFramework.close_encounter_threshold_performance_operation(
        decoded.method, decoded.configuration), policy)
report = build_performance_benchmark_report(definition,
    current_validation_environment(), configuration, policy,
    measurement.samples, measurement.execution)
exit_code = publish_performance_report(protocol, report; render=false)
exit_code == 0 || exit(exit_code)

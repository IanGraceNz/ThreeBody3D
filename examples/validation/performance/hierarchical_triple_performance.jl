using ThreeBody3D

include(joinpath(@__DIR__, "..", "framework", "ValidationFramework.jl"))
using .ValidationFramework

const DEFINITION = hierarchical_triple_performance_definition()
const CONFIGURATION = hierarchical_triple_performance_configuration()
const POLICY = StandardBenchmark()

protocol = resolve_performance_protocol(DEFINITION, VALIDATION_SCHEMA_VERSION)
result = run_performance_measurements(hierarchical_triple_performance_operation(), POLICY)
report = build_performance_benchmark_report(
    DEFINITION,
    current_validation_environment(),
    CONFIGURATION,
    POLICY,
    result.samples,
    result.execution,
)
exit_code = publish_performance_report(protocol, report; render=false)
exit_code == 0 || exit(exit_code)

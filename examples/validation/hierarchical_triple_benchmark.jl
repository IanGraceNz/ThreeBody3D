using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

# Long-duration weakly perturbed hierarchical system. The benchmark tracks the
# ratio of the outer-body distance from the inner-binary centre of mass to the
# instantaneous inner separation. A ratio comfortably above one indicates that
# the system remains hierarchical throughout the integration.
protocol = resolve_case_protocol(hierarchical_triple_case_definition(), VALIDATION_SCHEMA_VERSION)

const HIERARCHICAL_RELTOL = 1e-13
const HIERARCHICAL_ABSTOL = 1e-13

report = run_validation_benchmark(
    :hierarchical_triple;
    duration=100.0,
    solver=:accurate,
    saveat=0.02,
    reltol=HIERARCHICAL_RELTOL,
    abstol=HIERARCHICAL_ABSTOL,
)
println(report)

include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

const HIERARCHICAL_ENERGY_DRIFT_LIMIT = 1e-11
const HIERARCHICAL_MOMENTUM_DRIFT_LIMIT = 1e-12
const HIERARCHICAL_ANGULAR_MOMENTUM_DRIFT_LIMIT = 1e-11
const HIERARCHICAL_COM_RESIDUAL_LIMIT = 1e-11
const HIERARCHICAL_MINIMUM_RATIO_LIMIT = 5.0
const HIERARCHICAL_FINAL_TIME_RESIDUAL_LIMIT = 1e-10

hierarchical_criteria = (
    validation_criterion(
        "integration completed",
        report.status,
        "== completed",
        report.status == :completed,
    ),
    validation_criterion(
        "final-time residual",
        abs(report.final_time - report.expected_final_time),
        "<= $(HIERARCHICAL_FINAL_TIME_RESIDUAL_LIMIT)",
        abs(report.final_time - report.expected_final_time) <= HIERARCHICAL_FINAL_TIME_RESIDUAL_LIMIT,
    ),
    validation_criterion(
        "maximum relative energy drift",
        report.diagnostics.maximum_relative_energy_drift,
        "<= $(HIERARCHICAL_ENERGY_DRIFT_LIMIT)",
        report.diagnostics.maximum_relative_energy_drift <= HIERARCHICAL_ENERGY_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum momentum drift",
        report.diagnostics.maximum_linear_momentum_drift,
        "<= $(HIERARCHICAL_MOMENTUM_DRIFT_LIMIT)",
        report.diagnostics.maximum_linear_momentum_drift <= HIERARCHICAL_MOMENTUM_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum angular-momentum drift",
        report.diagnostics.maximum_angular_momentum_drift,
        "<= $(HIERARCHICAL_ANGULAR_MOMENTUM_DRIFT_LIMIT)",
        report.diagnostics.maximum_angular_momentum_drift <= HIERARCHICAL_ANGULAR_MOMENTUM_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum centre-of-mass residual",
        report.diagnostics.maximum_center_of_mass_residual,
        "<= $(HIERARCHICAL_COM_RESIDUAL_LIMIT)",
        report.diagnostics.maximum_center_of_mass_residual <= HIERARCHICAL_COM_RESIDUAL_LIMIT,
    ),
    validation_criterion(
        "minimum hierarchy ratio",
        report.benchmark_metrics.minimum_hierarchy_ratio,
        ">= $(HIERARCHICAL_MINIMUM_RATIO_LIMIT)",
        report.benchmark_metrics.minimum_hierarchy_ratio >= HIERARCHICAL_MINIMUM_RATIO_LIMIT,
    ),
)

if report_requested(protocol)
    structured_result = build_hierarchical_triple_case_result(
        report,
        current_validation_environment();
        energy_limit=HIERARCHICAL_ENERGY_DRIFT_LIMIT,
        momentum_limit=HIERARCHICAL_MOMENTUM_DRIFT_LIMIT,
        angular_momentum_limit=HIERARCHICAL_ANGULAR_MOMENTUM_DRIFT_LIMIT,
        center_of_mass_limit=HIERARCHICAL_COM_RESIDUAL_LIMIT,
        minimum_ratio_limit=HIERARCHICAL_MINIMUM_RATIO_LIMIT,
        final_time_limit=HIERARCHICAL_FINAL_TIME_RESIDUAL_LIMIT,
        reltol=HIERARCHICAL_RELTOL,
        abstol=HIERARCHICAL_ABSTOL,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria(
        "Hierarchical-triple validation acceptance criteria",
        hierarchical_criteria,
    )
end

using ThreeBody3D

# Long-duration weakly perturbed hierarchical system. The benchmark tracks the
# ratio of the outer-body distance from the inner-binary centre of mass to the
# instantaneous inner separation. A ratio comfortably above one indicates that
# the system remains hierarchical throughout the integration.
report = run_validation_benchmark(
    :hierarchical_triple;
    duration=100.0,
    solver=:accurate,
    saveat=0.02,
    reltol=1e-13,
    abstol=1e-13,
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

validate_acceptance_criteria(
    "Hierarchical-triple validation acceptance criteria",
    hierarchical_criteria,
)

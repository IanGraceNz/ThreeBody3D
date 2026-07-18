using ThreeBody3D

# Stage 9 common-format baseline for the equal-mass figure-eight choreography.
# Increase `periods` to study long-duration phase and conservation behaviour.
report = run_validation_benchmark(
    :figure_eight;
    periods=10,
    solver=:accurate,
    saveat=0.02,
)

println(report)

include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

const FIGURE_EIGHT_ENERGY_DRIFT_LIMIT = 1e-11
const FIGURE_EIGHT_MOMENTUM_DRIFT_LIMIT = 1e-12
const FIGURE_EIGHT_ANGULAR_MOMENTUM_DRIFT_LIMIT = 1e-11
const FIGURE_EIGHT_COM_RESIDUAL_LIMIT = 1e-11
const FIGURE_EIGHT_PERIODICITY_ERROR_LIMIT = 1e-5
const FIGURE_EIGHT_FINAL_TIME_RESIDUAL_LIMIT = 1e-10

figure_eight_criteria = (
    validation_criterion(
        "integration completed",
        report.status,
        "== completed",
        report.status == :completed,
    ),
    validation_criterion(
        "final-time residual",
        abs(report.final_time - report.expected_final_time),
        "<= $(FIGURE_EIGHT_FINAL_TIME_RESIDUAL_LIMIT)",
        abs(report.final_time - report.expected_final_time) <= FIGURE_EIGHT_FINAL_TIME_RESIDUAL_LIMIT,
    ),
    validation_criterion(
        "maximum relative energy drift",
        report.diagnostics.maximum_relative_energy_drift,
        "<= $(FIGURE_EIGHT_ENERGY_DRIFT_LIMIT)",
        report.diagnostics.maximum_relative_energy_drift <= FIGURE_EIGHT_ENERGY_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum momentum drift",
        report.diagnostics.maximum_linear_momentum_drift,
        "<= $(FIGURE_EIGHT_MOMENTUM_DRIFT_LIMIT)",
        report.diagnostics.maximum_linear_momentum_drift <= FIGURE_EIGHT_MOMENTUM_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum angular-momentum drift",
        report.diagnostics.maximum_angular_momentum_drift,
        "<= $(FIGURE_EIGHT_ANGULAR_MOMENTUM_DRIFT_LIMIT)",
        report.diagnostics.maximum_angular_momentum_drift <= FIGURE_EIGHT_ANGULAR_MOMENTUM_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum centre-of-mass residual",
        report.diagnostics.maximum_center_of_mass_residual,
        "<= $(FIGURE_EIGHT_COM_RESIDUAL_LIMIT)",
        report.diagnostics.maximum_center_of_mass_residual <= FIGURE_EIGHT_COM_RESIDUAL_LIMIT,
    ),
    validation_criterion(
        "ten-period state periodicity error",
        report.periodicity_error,
        "<= $(FIGURE_EIGHT_PERIODICITY_ERROR_LIMIT)",
        report.periodicity_error <= FIGURE_EIGHT_PERIODICITY_ERROR_LIMIT,
    ),
)

validate_acceptance_criteria(
    "Figure-eight validation acceptance criteria",
    figure_eight_criteria,
)

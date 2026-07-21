using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

# Stage 9 common-format baseline for the equal-mass figure-eight choreography.
# Increase `periods` to study long-duration phase and conservation behaviour.
protocol = resolve_case_protocol(figure_eight_case_definition(), VALIDATION_SCHEMA_VERSION)

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

if report_requested(protocol)
    structured_result = build_figure_eight_case_result(
        report,
        current_validation_environment();
        energy_limit=FIGURE_EIGHT_ENERGY_DRIFT_LIMIT,
        momentum_limit=FIGURE_EIGHT_MOMENTUM_DRIFT_LIMIT,
        angular_momentum_limit=FIGURE_EIGHT_ANGULAR_MOMENTUM_DRIFT_LIMIT,
        center_of_mass_limit=FIGURE_EIGHT_COM_RESIDUAL_LIMIT,
        periodicity_limit=FIGURE_EIGHT_PERIODICITY_ERROR_LIMIT,
        final_time_limit=FIGURE_EIGHT_FINAL_TIME_RESIDUAL_LIMIT,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria(
        "Figure-eight validation acceptance criteria",
        figure_eight_criteria,
    )
end

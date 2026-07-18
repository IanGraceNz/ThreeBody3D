using ThreeBody3D

# Stage 9 baseline: extend the established automatic-switching encounter over a
# longer physical interval and measure conservation on a uniform physical-time
# grid. This is a controller hardening benchmark, not yet a difficult physical
# three-body validation case; later Stage 9 increments will add stronger systems.
system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)

u0 = statevector(
    [-0.5, 0.0, 0.0], [0.5, 0.0, 0.0],
    [0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
    [10.0, 0.0, 0.0], [0.0, 0.0, 0.0],
)

parameters = AutomaticSwitchingParameters(
    enter_threshold=0.2,
    exit_threshold=0.4,
    ambiguity_threshold=0.3,
    minimum_separation_ratio=2.0,
    maximum_switches=20,
)

trajectory = simulate_experimental_switching(
    system,
    u0,
    (0.0, 20.0),
    parameters;
    cartesian_kwargs=(saveat=0.1,),
    regularized_kwargs=(saveat=0.025,),
)

trajectory.status == :completed || error(
    "Automatic switching ended with status $(trajectory.status): " *
    "$(trajectory.failure)",
)

report = diagnostics_report(trajectory; dt=0.02)
println(report)

include(joinpath(@__DIR__, "validation", "AcceptanceCriteria.jl"))

const SWITCHING_ENERGY_DRIFT_LIMIT = 1e-5
const SWITCHING_MOMENTUM_DRIFT_LIMIT = 1e-12
const SWITCHING_ANGULAR_MOMENTUM_DRIFT_LIMIT = 1e-12
const SWITCHING_COM_RESIDUAL_LIMIT = 1e-12
const SWITCHING_TRANSITION_STATE_RESIDUAL_LIMIT = 1e-12
const SWITCHING_TRANSITION_ENERGY_JUMP_LIMIT = 1e-12

switching_criteria = (
    validation_criterion(
        "trajectory completed",
        trajectory.status,
        "== completed",
        trajectory.status == :completed,
    ),
    validation_criterion(
        "expected number of representation switches",
        report.switch_count,
        "== 2",
        report.switch_count == 2,
    ),
    validation_criterion(
        "maximum relative energy drift",
        report.maximum_relative_energy_drift,
        "<= $(SWITCHING_ENERGY_DRIFT_LIMIT)",
        report.maximum_relative_energy_drift <= SWITCHING_ENERGY_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum momentum drift",
        report.maximum_linear_momentum_drift,
        "<= $(SWITCHING_MOMENTUM_DRIFT_LIMIT)",
        report.maximum_linear_momentum_drift <= SWITCHING_MOMENTUM_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum angular-momentum drift",
        report.maximum_angular_momentum_drift,
        "<= $(SWITCHING_ANGULAR_MOMENTUM_DRIFT_LIMIT)",
        report.maximum_angular_momentum_drift <= SWITCHING_ANGULAR_MOMENTUM_DRIFT_LIMIT,
    ),
    validation_criterion(
        "maximum centre-of-mass residual",
        report.maximum_center_of_mass_residual,
        "<= $(SWITCHING_COM_RESIDUAL_LIMIT)",
        report.maximum_center_of_mass_residual <= SWITCHING_COM_RESIDUAL_LIMIT,
    ),
    validation_criterion(
        "maximum transition state residual",
        report.maximum_transition_state_residual,
        "<= $(SWITCHING_TRANSITION_STATE_RESIDUAL_LIMIT)",
        report.maximum_transition_state_residual <= SWITCHING_TRANSITION_STATE_RESIDUAL_LIMIT,
    ),
    validation_criterion(
        "maximum transition energy jump",
        report.maximum_transition_energy_jump,
        "<= $(SWITCHING_TRANSITION_ENERGY_JUMP_LIMIT)",
        report.maximum_transition_energy_jump <= SWITCHING_TRANSITION_ENERGY_JUMP_LIMIT,
    ),
)

validate_acceptance_criteria(
    "Automatic-switching validation acceptance criteria",
    switching_criteria,
)

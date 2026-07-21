using LinearAlgebra
using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const KS_KEPLER_POSITION_ERROR_LIMIT = 5e-10
const KS_KEPLER_VELOCITY_ERROR_LIMIT = 5e-10
const KS_KEPLER_TIME_ERROR_LIMIT = 5e-10
const KS_KEPLER_CONSTRAINT_RESIDUAL_LIMIT = 5e-11
const KS_KEPLER_ENERGY_RESIDUAL_LIMIT = 5e-11

protocol = resolve_case_protocol(ks_kepler_case_definition(), VALIDATION_SCHEMA_VERSION)

# Validate numerical KS propagation against the exact fictitious-time solution
# for a bound spatial Kepler orbit.
include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

function main()

problem = ThreeBody3D.KSTwoBodyProblem(
    1.0,
    [1.0, 0.2, -0.1],
    [-0.15, 0.85, 0.20],
)
sspan = (0.0, 6.0)
result = ThreeBody3D.integrate_ks_two_body(
    problem,
    sspan;
    reltol=1e-13,
    abstol=1e-13,
    saveat=range(sspan...; length=241),
)

maximum_u_error = 0.0
maximum_w_error = 0.0
maximum_time_error = 0.0
maximum_constraint_residual = 0.0
maximum_energy_residual = 0.0
binding_energy_constant = true

for (s, y) in zip(result.solution.t, result.solution.u)
    u, w, h, t = ThreeBody3D.ks_unpack_state(y)
    ue, we, he, te = ThreeBody3D.ks_exact_state(problem, s)
    maximum_u_error = max(maximum_u_error, norm(u - ue))
    maximum_w_error = max(maximum_w_error, norm(w - we))
    maximum_time_error = max(maximum_time_error, abs(t - te))
    maximum_constraint_residual = max(
        maximum_constraint_residual,
        ThreeBody3D.ks_scaled_constraint_residual(u, w),
    )
    maximum_energy_residual = max(
        maximum_energy_residual,
        ThreeBody3D.ks_energy_consistency_residual(
            u, w, h, problem.gravitational_parameter,
        ),
    )
    if h != he
        binding_energy_constant = false
        error("The unperturbed KS binding energy changed.")
    end
end

println("KS Kepler validation")
println("  saved states:                         ", length(result.solution.t))
println("  maximum KS position-coordinate error: ", maximum_u_error)
println("  maximum KS velocity-coordinate error: ", maximum_w_error)
println("  maximum physical-time error:           ", maximum_time_error)
println("  maximum gauge-constraint residual:     ", maximum_constraint_residual)
println("  maximum energy-consistency residual:   ", maximum_energy_residual)

criteria = (
    validation_criterion("maximum KS position-coordinate error", maximum_u_error,
        "<= 5e-10", maximum_u_error <= KS_KEPLER_POSITION_ERROR_LIMIT),
    validation_criterion("maximum KS velocity-coordinate error", maximum_w_error,
        "<= 5e-10", maximum_w_error <= KS_KEPLER_VELOCITY_ERROR_LIMIT),
    validation_criterion("maximum physical-time error", maximum_time_error,
        "<= 5e-10", maximum_time_error <= KS_KEPLER_TIME_ERROR_LIMIT),
    validation_criterion("maximum gauge-constraint residual", maximum_constraint_residual,
        "<= 5e-11", maximum_constraint_residual <= KS_KEPLER_CONSTRAINT_RESIDUAL_LIMIT),
    validation_criterion("maximum energy-consistency residual", maximum_energy_residual,
        "<= 5e-11", maximum_energy_residual <= KS_KEPLER_ENERGY_RESIDUAL_LIMIT),
)
if report_requested(protocol)
    structured_result = build_ks_kepler_case_result(
        maximum_u_error,
        maximum_w_error,
        maximum_time_error,
        maximum_constraint_residual,
        maximum_energy_residual,
        binding_energy_constant,
        SolverStatistics(saved_states=length(result.solution.t)),
        current_validation_environment();
        gravitational_parameter=problem.gravitational_parameter,
        initial_position=(1.0, 0.2, -0.1),
        initial_velocity=(-0.15, 0.85, 0.20),
        fictitious_time_interval=sspan,
        saved_state_count=length(result.solution.t),
        position_error_limit=KS_KEPLER_POSITION_ERROR_LIMIT,
        velocity_error_limit=KS_KEPLER_VELOCITY_ERROR_LIMIT,
        time_error_limit=KS_KEPLER_TIME_ERROR_LIMIT,
        constraint_residual_limit=KS_KEPLER_CONSTRAINT_RESIDUAL_LIMIT,
        energy_residual_limit=KS_KEPLER_ENERGY_RESIDUAL_LIMIT,
        algorithm=:vern9,
        relative_tolerance=1e-13,
        absolute_tolerance=1e-13,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria("KS Kepler validation acceptance criteria", criteria)
end
end

main()

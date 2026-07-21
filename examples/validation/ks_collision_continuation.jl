using LinearAlgebra
using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const KS_COLLISION_RADIUS_LIMIT = 5e-14
const KS_COLLISION_SYMMETRY_ERROR_LIMIT = 5e-10
const KS_COLLISION_POSITION_ERROR_LIMIT = 5e-10
const KS_COLLISION_VELOCITY_ERROR_LIMIT = 5e-10
const KS_COLLISION_TIME_ERROR_LIMIT = 5e-10
const KS_COLLISION_ENERGY_RESIDUAL_LIMIT = 5e-11

protocol = resolve_case_protocol(
    ks_collision_continuation_case_definition(),
    VALIDATION_SCHEMA_VERSION,
)

# Validate finite KS continuation through a radial binary collision. Cartesian
# velocity is intentionally not evaluated at the singular instant.
include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

function main()

problem = ThreeBody3D.KSTwoBodyProblem(1.0, [1.0, 0.0, 0.0], zeros(3))
collision_s = pi / sqrt(2.0)
end_s = collision_s + 0.25
result = ThreeBody3D.integrate_ks_two_body(
    problem,
    (0.0, end_s);
    reltol=1e-13,
    abstol=1e-13,
    tstops=[collision_s],
    saveat=range(0.0, end_s; length=301),
)

uc, wc, hc, tc = ThreeBody3D.ks_exact_state(problem, collision_s)
probe = 1e-3
ub, wb, _, tb = ThreeBody3D.ks_exact_state(problem, collision_s - probe)
ua, wa, _, ta = ThreeBody3D.ks_exact_state(problem, collision_s + probe)

maximum_u_error = 0.0
maximum_w_error = 0.0
maximum_time_error = 0.0
for (s, y) in zip(result.solution.t, result.solution.u)
    u, w, _, t = ThreeBody3D.ks_unpack_state(y)
    ue, we, _, te = ThreeBody3D.ks_exact_state(problem, s)
    maximum_u_error = max(maximum_u_error, norm(u - ue))
    maximum_w_error = max(maximum_w_error, norm(w - we))
    maximum_time_error = max(maximum_time_error, abs(t - te))
end

position_symmetry_error = norm(
    ThreeBody3D.ks_position(ub) - ThreeBody3D.ks_position(ua),
)
collision_radius = norm(ThreeBody3D.ks_position(uc))
collision_constraint = ThreeBody3D.ks_energy_consistency_residual(uc, wc, hc, 1.0)
postcollision_finite = all(isfinite, ua) && all(isfinite, wa) && isfinite(ta) && ta > tc

println("KS radial-collision continuation validation")
println("  collision fictitious time:             ", collision_s)
println("  collision physical time:               ", tc)
println("  reconstructed collision radius:        ", collision_radius)
println("  symmetric-position error:              ", position_symmetry_error)
println("  maximum numerical KS coordinate error: ", maximum_u_error)
println("  maximum numerical KS derivative error: ", maximum_w_error)
println("  maximum physical-time error:            ", maximum_time_error)
println("  collision energy residual:              ", collision_constraint)
println("  postcollision state finite:             ", postcollision_finite)

criteria = (
    validation_criterion("collision radius", collision_radius,
        "<= 5e-14", collision_radius <= KS_COLLISION_RADIUS_LIMIT),
    validation_criterion("symmetric Cartesian position across collision", position_symmetry_error,
        "<= 5e-10", position_symmetry_error <= KS_COLLISION_SYMMETRY_ERROR_LIMIT),
    validation_criterion("maximum numerical KS coordinate error", maximum_u_error,
        "<= 5e-10", maximum_u_error <= KS_COLLISION_POSITION_ERROR_LIMIT),
    validation_criterion("maximum numerical KS derivative error", maximum_w_error,
        "<= 5e-10", maximum_w_error <= KS_COLLISION_VELOCITY_ERROR_LIMIT),
    validation_criterion("maximum physical-time error", maximum_time_error,
        "<= 5e-10", maximum_time_error <= KS_COLLISION_TIME_ERROR_LIMIT),
    validation_criterion("collision energy-consistency residual", collision_constraint,
        "<= 5e-11", collision_constraint <= KS_COLLISION_ENERGY_RESIDUAL_LIMIT),
    validation_criterion("finite postcollision continuation", postcollision_finite,
        "== true", postcollision_finite),
)
if report_requested(protocol)
    structured_result = build_ks_collision_continuation_case_result(
        collision_radius,
        position_symmetry_error,
        maximum_u_error,
        maximum_w_error,
        maximum_time_error,
        collision_constraint,
        postcollision_finite,
        SolverStatistics(saved_states=length(result.solution.t)),
        current_validation_environment();
        gravitational_parameter=problem.gravitational_parameter,
        initial_position=(1.0, 0.0, 0.0),
        initial_velocity=(0.0, 0.0, 0.0),
        fictitious_time_interval=(0.0, end_s),
        collision_fictitious_time=collision_s,
        collision_physical_time=tc,
        symmetry_probe=probe,
        saved_state_count=length(result.solution.t),
        collision_radius_limit=KS_COLLISION_RADIUS_LIMIT,
        symmetry_error_limit=KS_COLLISION_SYMMETRY_ERROR_LIMIT,
        position_error_limit=KS_COLLISION_POSITION_ERROR_LIMIT,
        velocity_error_limit=KS_COLLISION_VELOCITY_ERROR_LIMIT,
        time_error_limit=KS_COLLISION_TIME_ERROR_LIMIT,
        energy_residual_limit=KS_COLLISION_ENERGY_RESIDUAL_LIMIT,
        algorithm=:vern9,
        relative_tolerance=1e-13,
        absolute_tolerance=1e-13,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria("KS collision-continuation acceptance criteria", criteria)
end
end

main()

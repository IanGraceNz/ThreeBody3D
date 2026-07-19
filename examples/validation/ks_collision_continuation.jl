using LinearAlgebra
using ThreeBody3D

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
        "<= 5e-14", collision_radius <= 5e-14),
    validation_criterion("symmetric Cartesian position across collision", position_symmetry_error,
        "<= 5e-10", position_symmetry_error <= 5e-10),
    validation_criterion("maximum numerical KS coordinate error", maximum_u_error,
        "<= 5e-10", maximum_u_error <= 5e-10),
    validation_criterion("maximum numerical KS derivative error", maximum_w_error,
        "<= 5e-10", maximum_w_error <= 5e-10),
    validation_criterion("maximum physical-time error", maximum_time_error,
        "<= 5e-10", maximum_time_error <= 5e-10),
    validation_criterion("collision energy-consistency residual", collision_constraint,
        "<= 5e-11", collision_constraint <= 5e-11),
    validation_criterion("finite postcollision continuation", postcollision_finite,
        "== true", postcollision_finite),
)
validate_acceptance_criteria("KS collision-continuation acceptance criteria", criteria)
end

main()

using LinearAlgebra
using ThreeBody3D

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
    h == he || error("The unperturbed KS binding energy changed.")
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
        "<= 5e-10", maximum_u_error <= 5e-10),
    validation_criterion("maximum KS velocity-coordinate error", maximum_w_error,
        "<= 5e-10", maximum_w_error <= 5e-10),
    validation_criterion("maximum physical-time error", maximum_time_error,
        "<= 5e-10", maximum_time_error <= 5e-10),
    validation_criterion("maximum gauge-constraint residual", maximum_constraint_residual,
        "<= 5e-11", maximum_constraint_residual <= 5e-11),
    validation_criterion("maximum energy-consistency residual", maximum_energy_residual,
        "<= 5e-11", maximum_energy_residual <= 5e-11),
)
validate_acceptance_criteria("KS Kepler validation acceptance criteria", criteria)
end

main()

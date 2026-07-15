using ThreeBody3D
using LinearAlgebra

system = ThreeBodySystem((1.0, 1.0, 0.01))
relative_speed = sqrt(2.0)
u0 = statevector(
    [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
    [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
    [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
)

problem = PerturbedLeviCivitaProblem(system, u0, (1, 2))
target_time = 0.5
targeted = perturbed_levi_civita_state_at_time(
    problem, target_time;
    initial_step=0.5,
    tolerance=1e-11,
    reltol=1e-13,
    abstol=1e-13,
)

cartesian = simulate(
    system, u0, (0.0, target_time);
    solver=:accurate,
    reltol=1e-13,
    abstol=1e-13,
)
reference_state = cartesian.solution(target_time)

println("Perturbed planar Levi-Civita binary at targeted physical time")
println("  selected pair:               ", problem.pair)
println("  requested physical time:     ", target_time)
println("  reconstructed physical time: ", targeted.physical_time)
println("  located fictitious time:     ", targeted.fictitious_time)
println("  Cartesian state discrepancy: ", norm(targeted.physical_state - reference_state))
println("  binary specific energy:      ", targeted.binary_specific_energy)
println("  regularized position:        ", targeted.regularized_position)
println("  regularized derivative:      ", targeted.regularized_derivative)

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
result = integrate_perturbed_levi_civita(
    problem, (0.0, 0.5); reltol=1e-13, abstol=1e-13,
)
state = perturbed_levi_civita_state(result, 0.5)

reference = simulate(
    system, u0, (0.0, state.physical_time);
    solver=:accurate, reltol=1e-13, abstol=1e-13,
)
reference_state = reference.solution(state.physical_time)

println("Perturbed planar Levi-Civita binary at fixed fictitious time")
println("  selected pair:             ", problem.pair)
println("  fictitious time:           ", 0.5)
println("  reconstructed physical time:", state.physical_time)
println("  Cartesian state discrepancy:", norm(state.physical_state - reference_state))
println("  binary specific energy:    ", state.binary_specific_energy)
println("  regularized position:      ", state.regularized_position)
println("  regularized derivative:    ", state.regularized_derivative)

using ThreeBody3D

system = ThreeBodySystem((1.0, 1.0, 0.01))
relative_speed = sqrt(2.0)
u0 = statevector(
    [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
    [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
    [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
)

result = compose_regularized_trajectory(
    system,
    u0,
    (0.0, 1.0),
    (1, 2),
    (0.2, 0.7);
    saveat=0.05,
    cartesian_reltol=1e-13,
    cartesian_abstol=1e-13,
    regularized_initial_step=0.5,
    regularized_tolerance=1e-11,
    regularized_reltol=1e-13,
    regularized_abstol=1e-13,
)

println("Composed regularized trajectory")
println("\nEntry continuity")
println(result.entry_continuity)
println("\nExit continuity")
println(result.exit_continuity)

reference = simulate(
    system, u0, (0.0, 1.0);
    solver=:accurate, reltol=1e-13, abstol=1e-13,
)
println("\nFinal-state discrepancy from all-Cartesian reference: ",
        maximum(abs, result.states[end] .- reference.solution(1.0)))
println("State samples: ", length(result))
println("\nSegment statistics")
for statistics in result.solver_statistics
    println(statistics)
end

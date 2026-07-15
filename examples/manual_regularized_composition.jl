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
    (0.0, 0.8),
    (1, 2),
    (0.2, 0.5);
    saveat=0.05,
    cartesian_reltol=1e-13,
    cartesian_abstol=1e-13,
    regularized_initial_step=0.4,
    regularized_tolerance=1e-11,
    regularized_reltol=1e-13,
    regularized_abstol=1e-13,
)

println("Manual Cartesian → Levi-Civita → Cartesian composition")
println("  full interval:          ", result.tspan)
println("  regularized interval:   ", result.regularized_interval)
println("  selected pair:          ", result.pair)
println("  unified sample count:   ", length(result))
println("  final state norm:        ", norm(result(last(result.tspan))))
println()
println("Entry continuity")
println(result.entry_continuity)
println()
println("Exit continuity")
println(result.exit_continuity)
println()
foreach(statistics -> println(statistics, '\n'), result.solver_statistics)

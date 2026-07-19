using ThreeBody3D
using LinearAlgebra

system = ThreeBodySystem((1.0, 1.0, 0.01))
relative_speed = sqrt(2.0)
u0 = statevector(
    [0.5, 0.0, 0.0], [0.0, relative_speed / 2, 0.0],
    [-0.5, 0.0, 0.0], [0.0, -relative_speed / 2, 0.0],
    [8.0, 0.5, 0.0], [0.0, 0.35, 0.0],
)

segment = propagate_regularized_segment(
    system, u0, (1, 2), 0.0, 0.5;
    initial_step=0.5,
    tolerance=1e-11,
    reltol=1e-13,
    abstol=1e-13,
)

println("Explicit Cartesian -> Levi-Civita -> Cartesian segment")
println("  selected pair:          ", segment.pair)
println("  physical interval:      ", (segment.entry_time, segment.exit_time))
println("  exit fictitious time:   ", segment.exit_fictitious_time)
println("\nEntry transition")
show(stdout, segment.entry_diagnostics)
println("\n\nExit transition")
show(stdout, segment.exit_diagnostics)
println()

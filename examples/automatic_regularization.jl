using ThreeBody3D
using LinearAlgebra

# A deliberately simple planar encounter used to demonstrate the experimental
# threshold-driven Cartesian ↔ Levi-Civita switching workflow. The very small
# masses make the switch geometry easy to inspect without making this example
# a scientific benchmark.
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
    maximum_switches=10,
)

trajectory = simulate_experimental_switching(
    system,
    u0,
    (0.0, 1.6),
    parameters;
    cartesian_kwargs=(saveat=0.09,),
    regularized_kwargs=(saveat=0.027,),
)

trajectory.status == :completed || error(
    "Automatic switching ended with status $(trajectory.status): $(trajectory.failure)",
)

samples = sample_experimental_switching(
    trajectory;
    dt=0.1,
    regularized_kwargs=(
        initial_step=trajectory.segments[2].location.fictitious_time / 4,
    ),
)

println("Experimental automatic regularization")
println("  status:                 ", trajectory.status)
println("  physical interval:      ", trajectory.tspan)
println("  segment count:          ", length(trajectory.segments))
println("  switch-event count:     ", length(trajectory.switch_events))
println("  sampled-state count:    ", length(samples))
println("  final state norm:        ", norm(trajectory.final_state))
println()

for (index, event) in enumerate(trajectory.switch_events)
    println(
        "  event ", index,
        ": kind=", event.kind,
        ", pair=", event.pair,
        ", t=", event.physical_time,
        ", isolation ratio=", event.isolation_ratio,
    )
end

println()
println("Transition diagnostics")
for (index, event) in enumerate(trajectory.switch_events)
    println("  event ", index, ": ", event.transition_diagnostics)
end

midpoint = sum(trajectory.tspan) / 2
println()
println("Dense state norm at t=", midpoint, ": ", norm(trajectory(midpoint)))
println("First sampled time:      ", first(samples.times))
println("Last sampled time:       ", last(samples.times))

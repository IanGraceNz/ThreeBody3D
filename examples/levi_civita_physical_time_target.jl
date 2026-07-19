using ThreeBody3D
using LinearAlgebra

oscillator = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 0.5])
target_time = 0.75
state = levi_civita_state_at_time(oscillator, target_time)

reference = KeplerReference(
    1.0,
    [1.0, 0.0, 0.0],
    [0.0, 0.5, 0.0],
)
r_reference, v_reference = kepler_state(reference, target_time)

println("Levi-Civita state at a requested physical time")
println("  requested physical time: ", target_time)
println("  solved fictitious time:  ", state.fictitious_time)
println("  reconstructed time:      ",
        levi_civita_physical_time(oscillator, state.fictitious_time))
println("  position error:          ", norm(state.position - r_reference[1:2]))
println("  velocity error:          ", norm(state.velocity - v_reference[1:2]))
println("  regularized position:    ", state.regularized_position)

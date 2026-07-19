using ThreeBody3D
using LinearAlgebra

oscillator = LeviCivitaOscillator(1.0, [1.0, 0.0], [0.0, 0.5])
final_s = 0.8
result = integrate_levi_civita_sundman(
    oscillator,
    (0.0, final_s);
    saveat=final_s / 8,
    reltol=1e-13,
    abstol=1e-13,
)

u, uprime, physical_time = levi_civita_sundman_state(result, final_s)
exact_time = levi_civita_physical_time(oscillator, final_s)
q, qdot = levi_civita_cartesian_state(result, final_s)

reference = KeplerReference(
    1.0,
    [1.0, 0.0, 0.0],
    [0.0, 0.5, 0.0],
)
r_reference, v_reference = kepler_state(reference, exact_time)

println("Levi-Civita Sundman reconstruction at fixed fictitious time")
println("  fictitious time:          ", final_s)
println("  numerical physical time: ", physical_time)
println("  exact physical time:     ", exact_time)
println("  physical-time error:     ", abs(physical_time - exact_time))
println("  position error:          ", norm(q - r_reference[1:2]))
println("  velocity error:          ", norm(qdot - v_reference[1:2]))
println("  regularized position:    ", u)
println("  regularized derivative:  ", uprime)

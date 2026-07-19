using ThreeBody3D
using LinearAlgebra

oscillator = LeviCivitaOscillator(
    1.0,
    [1.0, 0.0],
    [0.0, 1.0],
)

result = integrate_levi_civita_fictitious(
    oscillator,
    (0.0, π);
    saveat=π / 8,
    reltol=1e-13,
    abstol=1e-13,
)

u_exact, uprime_exact = levi_civita_fictitious_state(oscillator, π)
u_numeric, uprime_numeric = levi_civita_fictitious_state(result, π)
q, qdot = levi_civita_cartesian_state(oscillator, π)

println("Isolated Levi-Civita oscillator at s = pi")
println("  specific energy:             ", oscillator.specific_energy)
println("  regularized position error:  ", norm(u_numeric - u_exact))
println("  regularized velocity error:  ", norm(uprime_numeric - uprime_exact))
println("  reconstructed position:      ", q)
println("  reconstructed velocity:      ", qdot)
println("  saved fictitious-time states:", length(result.solution.t))

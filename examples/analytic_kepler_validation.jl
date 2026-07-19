using ThreeBody3D
using LinearAlgebra

μ = 1.0
reference = KeplerReference(μ, [1.0, 0.0, 0.0], [0.0, 1.0, 0.0])

println("Circular Kepler reference at quarter period")
r, v = kepler_state(reference, π / 2)
println("  position:         ", r)
println("  velocity:         ", v)
println("  specific energy:  ", kepler_specific_energy(μ, r, v))
println("  angular momentum: ", kepler_angular_momentum(r, v))

radial_initial = [2.0, 0.0, 0.0]
collision_time = radial_free_fall_time(μ, norm(radial_initial))
comparison_time = collision_time / 2
radial_reference = KeplerReference(μ, radial_initial, zeros(3))

r_universal, v_universal = kepler_state(radial_reference, comparison_time)
r_exact, v_exact = radial_free_fall_state(μ, radial_initial, comparison_time)

println("\nRadial free fall at half the collision time")
println("  collision time:       ", collision_time)
println("  position discrepancy: ", norm(r_universal - r_exact))
println("  velocity discrepancy: ", norm(v_universal - v_exact))

using LinearAlgebra
using ThreeBody3D

# Validate the coupled pair-centred KS equations in a hierarchical triple by
# comparison with an independent high-accuracy Cartesian propagation.
include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

function main()

system = ThreeBodySystem((1.0, 0.4, 0.2))
state = statevector(
    [-0.3, 0.0, 0.0], [0.0, -0.45, 0.08],
    [ 0.7, 0.0, 0.0], [0.0,  0.65,-0.12],
    [ 6.0, 1.0, 0.5], [-0.03, 0.02, 0.01],
)
t0, tf = 0.0, 0.5
segment = ThreeBody3D.propagate_ks_segment(
    system, state, (1,2), t0, tf;
    reltol=1e-13,
    abstol=1e-13,
)
direct = simulate(
    system, state, (t0, tf);
    solver=:accurate,
    reltol=1e-13,
    abstol=1e-13,
)

times = collect(range(t0, tf; length=101))
maximum_state_error = 0.0
maximum_energy_difference = 0.0
for time in times
    ks_state = segment(time)
    cartesian_state = direct.solution(time)
    scale = max(1.0, norm(cartesian_state))
    maximum_state_error = max(maximum_state_error, norm(ks_state - cartesian_state) / scale)
    maximum_energy_difference = max(
        maximum_energy_difference,
        abs(total_energy(system, ks_state) - total_energy(system, cartesian_state)) /
            max(1.0, abs(total_energy(system, cartesian_state))),
    )
end

println("KS hierarchical-triple validation")
println("  sampled physical states:             ", length(times))
println("  maximum scaled Cartesian-state error:", maximum_state_error)
println("  maximum relative energy difference:  ", maximum_energy_difference)
println("  maximum KS energy drift:              ", segment.diagnostics.maximum_relative_energy_drift)
println("  maximum KS gauge residual:            ", segment.diagnostics.maximum_scaled_constraint_residual)
println("  minimum nonselected separation:       ", segment.diagnostics.minimum_nonselected_separation)
println("  entry transition residual:            ", segment.diagnostics.entry_transition.state_residual)
println("  exit transition residual:             ", segment.diagnostics.exit_transition.state_residual)

criteria = (
    validation_criterion("maximum scaled Cartesian-state discrepancy", maximum_state_error,
        "<= 2e-8", maximum_state_error <= 2e-8),
    validation_criterion("maximum relative energy discrepancy", maximum_energy_difference,
        "<= 2e-9", maximum_energy_difference <= 2e-9),
    validation_criterion("maximum KS relative energy drift", segment.diagnostics.maximum_relative_energy_drift,
        "<= 2e-9", segment.diagnostics.maximum_relative_energy_drift <= 2e-9),
    validation_criterion("maximum KS gauge-constraint residual", segment.diagnostics.maximum_scaled_constraint_residual,
        "<= 2e-9", segment.diagnostics.maximum_scaled_constraint_residual <= 2e-9),
    validation_criterion("minimum nonselected-pair separation", segment.diagnostics.minimum_nonselected_separation,
        ">= 1.0", segment.diagnostics.minimum_nonselected_separation >= 1.0),
    validation_criterion("entry transition state residual", segment.diagnostics.entry_transition.state_residual,
        "<= 1e-12", segment.diagnostics.entry_transition.state_residual <= 1e-12),
    validation_criterion("exit transition state residual", segment.diagnostics.exit_transition.state_residual,
        "<= 1e-12", segment.diagnostics.exit_transition.state_residual <= 1e-12),
)
validate_acceptance_criteria("KS hierarchical-triple acceptance criteria", criteria)
end

main()

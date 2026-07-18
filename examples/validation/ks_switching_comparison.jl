using LinearAlgebra
using ThreeBody3D

# Compare the legacy Levi-Civita and new KS automatic-switching backends on the
# same controlled planar encounter. The tiny masses make the expected motion
# nearly ballistic while still exercising entry and exit events.
include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

function main()

system = ThreeBodySystem((1e-12, 1e-12, 1e-12); G=1.0)
parameters = ThreeBody3D.AutomaticSwitchingParameters(
    enter_threshold=0.2,
    exit_threshold=0.4,
    ambiguity_threshold=0.3,
    minimum_separation_ratio=2.0,
    maximum_switches=10,
)
state = statevector(
    [-0.5, 0.0, 0.0], [ 0.5, 0.0, 0.0],
    [ 0.5, 0.0, 0.0], [-0.5, 0.0, 0.0],
    [10.0, 0.0, 0.0], [ 0.0, 0.0, 0.0],
)
tspan = (0.0, 1.6)

lc = ThreeBody3D.simulate_experimental_switching(
    system, state, tspan, parameters;
    regularization_backend=:levi_civita,
)
ks = ThreeBody3D.simulate_experimental_switching(
    system, state, tspan, parameters;
    regularization_backend=:ks,
)

times = collect(range(tspan...; length=161))
maximum_state_difference = 0.0
for time in times
    lc_state = ThreeBody3D.experimental_switching_state(lc, time)
    ks_state = ThreeBody3D.experimental_switching_state(ks, time)
    maximum_state_difference = max(
        maximum_state_difference,
        norm(ks_state - lc_state) / max(1.0, norm(lc_state)),
    )
end

ks_transition_residual = maximum(
    event.transition_diagnostics.state_residual for event in ks.switch_events
)
lc_transition_residual = maximum(
    event.transition_diagnostics.state_residual for event in lc.switch_events
)
entry_time_difference = abs(ks.switch_events[1].physical_time - lc.switch_events[1].physical_time)
exit_time_difference = abs(ks.switch_events[2].physical_time - lc.switch_events[2].physical_time)

println("KS automatic-switching comparison")
println("  KS status:                          ", ks.status)
println("  Levi-Civita status:                ", lc.status)
println("  KS switches:                       ", length(ks.switch_events))
println("  Levi-Civita switches:              ", length(lc.switch_events))
println("  maximum scaled state difference:   ", maximum_state_difference)
println("  entry-time difference:             ", entry_time_difference)
println("  exit-time difference:              ", exit_time_difference)
println("  maximum KS transition residual:    ", ks_transition_residual)
println("  maximum Levi-Civita transition residual: ", lc_transition_residual)

criteria = (
    validation_criterion("KS trajectory completed", ks.status,
        "== completed", ks.status == :completed),
    validation_criterion("Levi-Civita trajectory completed", lc.status,
        "== completed", lc.status == :completed),
    validation_criterion("KS switch count", length(ks.switch_events),
        "== 2", length(ks.switch_events) == 2),
    validation_criterion("Levi-Civita switch count", length(lc.switch_events),
        "== 2", length(lc.switch_events) == 2),
    validation_criterion("maximum scaled backend state discrepancy", maximum_state_difference,
        "<= 2e-8", maximum_state_difference <= 2e-8),
    validation_criterion("entry-event time discrepancy", entry_time_difference,
        "<= 2e-6", entry_time_difference <= 2e-6),
    validation_criterion("exit-event time discrepancy", exit_time_difference,
        "<= 2e-6", exit_time_difference <= 2e-6),
    validation_criterion("maximum KS transition residual", ks_transition_residual,
        "<= 1e-11", ks_transition_residual <= 1e-11),
    validation_criterion("maximum Levi-Civita transition residual", lc_transition_residual,
        "<= 1e-11", lc_transition_residual <= 1e-11),
)
validate_acceptance_criteria("KS switching-comparison acceptance criteria", criteria)
end

main()

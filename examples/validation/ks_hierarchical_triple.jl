using LinearAlgebra
using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const KS_HIERARCHICAL_TRIPLE_STATE_ERROR_LIMIT = 2e-8
const KS_HIERARCHICAL_TRIPLE_ENERGY_DIFFERENCE_LIMIT = 2e-9
const KS_HIERARCHICAL_TRIPLE_KS_ENERGY_DRIFT_LIMIT = 2e-9
const KS_HIERARCHICAL_TRIPLE_GAUGE_RESIDUAL_LIMIT = 2e-9
const KS_HIERARCHICAL_TRIPLE_MINIMUM_SEPARATION_LIMIT = 1.0
const KS_HIERARCHICAL_TRIPLE_TRANSITION_RESIDUAL_LIMIT = 1e-12

protocol = resolve_case_protocol(
    ks_hierarchical_triple_case_definition(),
    VALIDATION_SCHEMA_VERSION,
)

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
selected_pair = (1, 2)
relative_tolerance = 1e-13
absolute_tolerance = 1e-13
segment = ThreeBody3D.propagate_ks_segment(
    system, state, selected_pair, t0, tf;
    reltol=relative_tolerance,
    abstol=absolute_tolerance,
)
direct = simulate(
    system, state, (t0, tf);
    solver=:accurate,
    reltol=relative_tolerance,
    abstol=absolute_tolerance,
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
        "<= 2e-8", maximum_state_error <= KS_HIERARCHICAL_TRIPLE_STATE_ERROR_LIMIT),
    validation_criterion("maximum relative energy discrepancy", maximum_energy_difference,
        "<= 2e-9", maximum_energy_difference <= KS_HIERARCHICAL_TRIPLE_ENERGY_DIFFERENCE_LIMIT),
    validation_criterion("maximum KS relative energy drift", segment.diagnostics.maximum_relative_energy_drift,
        "<= 2e-9", segment.diagnostics.maximum_relative_energy_drift <= KS_HIERARCHICAL_TRIPLE_KS_ENERGY_DRIFT_LIMIT),
    validation_criterion("maximum KS gauge-constraint residual", segment.diagnostics.maximum_scaled_constraint_residual,
        "<= 2e-9", segment.diagnostics.maximum_scaled_constraint_residual <= KS_HIERARCHICAL_TRIPLE_GAUGE_RESIDUAL_LIMIT),
    validation_criterion("minimum nonselected-pair separation", segment.diagnostics.minimum_nonselected_separation,
        ">= 1.0", segment.diagnostics.minimum_nonselected_separation >= KS_HIERARCHICAL_TRIPLE_MINIMUM_SEPARATION_LIMIT),
    validation_criterion("entry transition state residual", segment.diagnostics.entry_transition.state_residual,
        "<= 1e-12", segment.diagnostics.entry_transition.state_residual <= KS_HIERARCHICAL_TRIPLE_TRANSITION_RESIDUAL_LIMIT),
    validation_criterion("exit transition state residual", segment.diagnostics.exit_transition.state_residual,
        "<= 1e-12", segment.diagnostics.exit_transition.state_residual <= KS_HIERARCHICAL_TRIPLE_TRANSITION_RESIDUAL_LIMIT),
)
if report_requested(protocol)
    ks_work = segment.diagnostics.solver_statistics
    cartesian_work = direct.solution.stats
    structured_result = build_ks_hierarchical_triple_case_result(
        maximum_state_error,
        maximum_energy_difference,
        segment.diagnostics.maximum_relative_energy_drift,
        segment.diagnostics.maximum_scaled_constraint_residual,
        segment.diagnostics.minimum_nonselected_separation,
        segment.diagnostics.entry_transition.state_residual,
        segment.diagnostics.exit_transition.state_residual,
        SolverStatistics(
            accepted_steps=ks_work.accepted_steps + Int(cartesian_work.naccept),
            rejected_steps=ks_work.rejected_steps + Int(cartesian_work.nreject),
            rhs_evaluations=ks_work.rhs_evaluations + Int(cartesian_work.nf),
            saved_states=ks_work.saved_states + length(direct.solution.t),
            segment_count=2,
        ),
        current_validation_environment();
        masses=Tuple(system.masses),
        gravitational_constant=system.G,
        initial_state=Tuple(state),
        selected_pair=selected_pair,
        physical_time_interval=(t0, tf),
        comparison_sample_count=length(times),
        algorithm=:vern9,
        relative_tolerance=relative_tolerance,
        absolute_tolerance=absolute_tolerance,
        state_error_limit=KS_HIERARCHICAL_TRIPLE_STATE_ERROR_LIMIT,
        energy_difference_limit=KS_HIERARCHICAL_TRIPLE_ENERGY_DIFFERENCE_LIMIT,
        ks_energy_drift_limit=KS_HIERARCHICAL_TRIPLE_KS_ENERGY_DRIFT_LIMIT,
        gauge_residual_limit=KS_HIERARCHICAL_TRIPLE_GAUGE_RESIDUAL_LIMIT,
        minimum_separation_limit=KS_HIERARCHICAL_TRIPLE_MINIMUM_SEPARATION_LIMIT,
        transition_residual_limit=KS_HIERARCHICAL_TRIPLE_TRANSITION_RESIDUAL_LIMIT,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria("KS hierarchical-triple acceptance criteria", criteria)
end
end

main()

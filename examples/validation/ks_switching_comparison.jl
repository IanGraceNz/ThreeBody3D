using LinearAlgebra
using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const KS_SWITCHING_STATE_DIFFERENCE_LIMIT = 2e-8
const KS_SWITCHING_EVENT_TIME_DIFFERENCE_LIMIT = 2e-6
const KS_SWITCHING_TRANSITION_RESIDUAL_LIMIT = 1e-11

protocol = resolve_case_protocol(
    ks_switching_comparison_case_definition(),
    VALIDATION_SCHEMA_VERSION,
)

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
comparison_sample_count = 161
environment = current_validation_environment()
fixed_settings = ValidationFramework._ks_switching_fixed_settings(
    enter_threshold=parameters.enter_threshold,
)
configuration = ValidationFramework._ks_switching_comparison_configuration(
    masses=Tuple(system.masses), gravitational_constant=system.G,
    initial_state=Tuple(state), selected_pair=(1, 2), physical_time_interval=tspan,
    comparison_sample_count=comparison_sample_count, enter_threshold=parameters.enter_threshold,
    exit_threshold=parameters.exit_threshold,
    ambiguity_threshold=parameters.ambiguity_threshold,
    minimum_separation_ratio=parameters.minimum_separation_ratio,
    maximum_switches=parameters.maximum_switches,
    minimum_time_progress=parameters.minimum_time_progress,
    minimum_separation_excursion=parameters.minimum_separation_excursion,
    threshold_scale_kind=parameters.threshold_scale_kind,
    threshold_reference_scale=parameters.threshold_reference_scale,
    fixed_settings=fixed_settings,
    state_difference_limit=KS_SWITCHING_STATE_DIFFERENCE_LIMIT,
    event_time_difference_limit=KS_SWITCHING_EVENT_TIME_DIFFERENCE_LIMIT,
    transition_residual_limit=KS_SWITCHING_TRANSITION_RESIDUAL_LIMIT,
)

lc = ThreeBody3D.simulate_experimental_switching(
    system, state, tspan, parameters;
    regularization_backend=:levi_civita,
    cartesian_kwargs=fixed_settings.cartesian_kwargs,
    regularized_kwargs=fixed_settings.levi_civita_kwargs,
)
ks = ThreeBody3D.simulate_experimental_switching(
    system, state, tspan, parameters;
    regularization_backend=:ks,
    cartesian_kwargs=fixed_settings.cartesian_kwargs,
    regularized_kwargs=fixed_settings.ks_kwargs,
)

backend_reports = build_ks_switching_backend_reports(
    ks, lc, configuration, environment; comparison_sample_count, fixed_settings,
)
maximum_state_difference = backend_reports.maximum_scaled_backend_state_discrepancy
entry_time_difference = backend_reports.entry_event_time_discrepancy
exit_time_difference = backend_reports.exit_event_time_discrepancy

ks_transition_residual = ValidationFramework._ks_switching_maximum_transition_residual(ks)
lc_transition_residual = ValidationFramework._ks_switching_maximum_transition_residual(lc)

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

comparison_defined = ks.status == :completed && lc.status == :completed &&
    all(!isnothing, (
        maximum_state_difference, entry_time_difference, exit_time_difference,
        ks_transition_residual, lc_transition_residual,
    ))
criteria = comparison_defined ? (
    validation_criterion("KS trajectory completed", ks.status,
        "== completed", ks.status == :completed),
    validation_criterion("Levi-Civita trajectory completed", lc.status,
        "== completed", lc.status == :completed),
    validation_criterion("KS switch count", length(ks.switch_events),
        "== 2", length(ks.switch_events) == 2),
    validation_criterion("Levi-Civita switch count", length(lc.switch_events),
        "== 2", length(lc.switch_events) == 2),
    validation_criterion("maximum scaled backend state discrepancy", maximum_state_difference,
        "<= 2e-8", maximum_state_difference <= KS_SWITCHING_STATE_DIFFERENCE_LIMIT),
    validation_criterion("entry-event time discrepancy", entry_time_difference,
        "<= 2e-6", entry_time_difference <= KS_SWITCHING_EVENT_TIME_DIFFERENCE_LIMIT),
    validation_criterion("exit-event time discrepancy", exit_time_difference,
        "<= 2e-6", exit_time_difference <= KS_SWITCHING_EVENT_TIME_DIFFERENCE_LIMIT),
    validation_criterion("maximum KS transition residual", ks_transition_residual,
        "<= 1e-11", ks_transition_residual <= KS_SWITCHING_TRANSITION_RESIDUAL_LIMIT),
    validation_criterion("maximum Levi-Civita transition residual", lc_transition_residual,
        "<= 1e-11", lc_transition_residual <= KS_SWITCHING_TRANSITION_RESIDUAL_LIMIT),
) : ()
structured_result = build_ks_switching_comparison_case_result(
        ks.status,
        lc.status,
        length(ks.switch_events),
        length(lc.switch_events),
        maximum_state_difference,
        entry_time_difference,
        exit_time_difference,
        ks_transition_residual,
        lc_transition_residual,
        comparison_sample_count,
        SolverStatistics(
            segment_count=length(ks.segments) + length(lc.segments),
            switch_count=length(ks.switch_events) + length(lc.switch_events),
        ),
        environment;
        configuration,
        state_difference_limit=KS_SWITCHING_STATE_DIFFERENCE_LIMIT,
        event_time_difference_limit=KS_SWITCHING_EVENT_TIME_DIFFERENCE_LIMIT,
        transition_residual_limit=KS_SWITCHING_TRANSITION_RESIDUAL_LIMIT,
)

ks_switching_backend_investigation_series(
    structured_result, (backend_reports.levi_civita, backend_reports.ks),
)

if report_requested(protocol)
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    isempty(criteria) ||
        validate_acceptance_criteria("KS switching-comparison acceptance criteria", criteria)
    exit_code = validation_exit_code(structured_result)
    exit_code == 0 || exit(exit_code)
end
end

main()

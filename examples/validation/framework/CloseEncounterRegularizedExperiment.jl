# Shared automatic and explicit regularised operations for I2-C2.
const CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES = (1e-10, 1e-11, 1e-12, 1e-13)
const CLOSE_ENCOUNTER_CARTESIAN_TOLERANCE = 1e-13
const CLOSE_ENCOUNTER_STATE_EVALUATION_TOLERANCE = 1e-14
const CLOSE_ENCOUNTER_AUTOMATIC_AMBIGUITY_THRESHOLD = 0.25
const CLOSE_ENCOUNTER_AUTOMATIC_MINIMUM_SEPARATION_RATIO = 10.0
const CLOSE_ENCOUNTER_AUTOMATIC_MAXIMUM_SWITCHES = 10
const CLOSE_ENCOUNTER_REGULARIZED_INITIAL_STEP = 0.1
const CLOSE_ENCOUNTER_REGULARIZED_MAXIMUM_ITERATIONS = 256
const CLOSE_ENCOUNTER_STATE_EVALUATION_MAXIMUM_ITERATIONS = 256

struct CloseEncounterRegularizedExecutionControls
    regularized_relative_tolerance::Float64
    regularized_absolute_tolerance::Float64
    cartesian_relative_tolerance::Float64
    cartesian_absolute_tolerance::Float64
    entry_threshold::Float64
    ambiguity_threshold::Float64
    exit_threshold::Float64
    state_evaluation_tolerance::Float64
    regularized_initial_step::Float64
    regularized_maximum_iterations::Int
    state_evaluation_maximum_iterations::Int
end

function close_encounter_regularized_controls(tolerance::Real)
    value = Float64(tolerance)
    value in CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES || throw(ArgumentError("Unsupported regularised tolerance."))
    CloseEncounterRegularizedExecutionControls(
        value, value, 1e-13, 1e-13, 0.1, 0.25, 0.25, 1e-14, 0.1, 256, 256,
    )
end

close_encounter_automatic_parameters(c) = ThreeBody3D.AutomaticSwitchingParameters(
    enter_threshold=c.entry_threshold, ambiguity_threshold=c.ambiguity_threshold,
    exit_threshold=c.exit_threshold, minimum_separation_ratio=10.0, maximum_switches=10,
)

function close_encounter_automatic_propagation(problem, controls; runner=ThreeBody3D.simulate_experimental_switching)
    runner(problem.system, problem.u0, problem.tspan, close_encounter_automatic_parameters(controls);
        cartesian_kwargs=(solver=:accurate, reltol=controls.cartesian_relative_tolerance,
            abstol=controls.cartesian_absolute_tolerance),
        regularized_kwargs=(reltol=controls.regularized_relative_tolerance,
            abstol=controls.regularized_absolute_tolerance,
            initial_step=controls.regularized_initial_step))
end

function close_encounter_switch_events(trajectory)
    entries = filter(event -> event.kind == :entry, trajectory.switch_events)
    exits = filter(event -> event.kind == :exit, trajectory.switch_events)
    length(entries) == 1 || throw(ArgumentError("Automatic trajectory requires exactly one entry event."))
    length(exits) == 1 || throw(ArgumentError("Automatic trajectory requires exactly one exit event."))
    entry, exit = only(entries), only(exits)
    entry.pair == CLOSE_ENCOUNTER_SELECTED_PAIR || throw(ArgumentError("Automatic entry selected the wrong pair."))
    exit.pair == CLOSE_ENCOUNTER_SELECTED_PAIR || throw(ArgumentError("Automatic exit selected the wrong pair."))
    entry.physical_time < exit.physical_time || throw(ArgumentError("Automatic events are unordered."))
    entry, exit
end

function close_encounter_automatic_regularized_segment(trajectory)
    segments = filter(s -> s isa ThreeBody3D.AutomaticRegularizedSegment, trajectory.segments)
    length(segments) == 1 || throw(ArgumentError("Automatic trajectory requires exactly one regularised segment."))
    only(segments)
end

function close_encounter_automatic_interval(trajectory)
    trajectory.status == :completed || throw(ArgumentError("Automatic propagation did not complete."))
    entry, exit = close_encounter_switch_events(trajectory)
    interval = (Float64(entry.physical_time), Float64(exit.physical_time))
    0.0 < interval[1] < interval[2] < 1.6 || throw(ArgumentError("Automatic interval is invalid."))
    entry.radial_rates[1] < 0 || throw(ArgumentError("Automatic entry is not inbound."))
    exit.radial_rates[1] > 0 || throw(ArgumentError("Automatic exit is not outbound."))
    segment = close_encounter_automatic_regularized_segment(trajectory)
    segment.pair == (1, 2) || throw(ArgumentError("Automatic regularised segment selected the wrong pair."))
    (Float64(segment.start_time), Float64(segment.end_time)) == interval || throw(ArgumentError("Automatic segment interval differs from its events."))
    trajectory.final_time == 1.6 || throw(ArgumentError("Completed automatic trajectory did not reach final time."))
    interval
end

function close_encounter_explicit_propagation(problem, interval::Tuple{Float64,Float64}, controls;
    runner=ThreeBody3D.compose_regularized_trajectory, saveat=close_encounter_sample_times(problem.tspan))
    result = runner(problem.system, problem.u0, problem.tspan, (1, 2), interval;
        saveat, cartesian_solver=:accurate,
        cartesian_reltol=controls.cartesian_relative_tolerance,
        cartesian_abstol=controls.cartesian_absolute_tolerance,
        regularized_reltol=controls.regularized_relative_tolerance,
        regularized_abstol=controls.regularized_absolute_tolerance,
        regularized_initial_step=controls.regularized_initial_step,
        regularized_max_iterations=controls.regularized_maximum_iterations)
    result.pair == (1, 2) || throw(ArgumentError("Explicit trajectory selected the wrong pair."))
    result.regularized_interval == interval || throw(ArgumentError("Explicit trajectory altered the supplied automatic interval."))
    result
end

function close_encounter_automatic_state(trajectory, time, controls)
    Vector{Float64}(ThreeBody3D.experimental_switching_state(trajectory, Float64(time);
        regularized_kwargs=(tolerance=controls.state_evaluation_tolerance,
            max_iterations=controls.state_evaluation_maximum_iterations)))
end
close_encounter_explicit_state(trajectory, time, controls) = Vector{Float64}(
    ThreeBody3D.composed_regularized_state(trajectory, Float64(time);
        tolerance=controls.state_evaluation_tolerance))
close_encounter_automatic_states(t, times, c) = [close_encounter_automatic_state(t, x, c) for x in times]
close_encounter_explicit_states(t, times, c) = [close_encounter_explicit_state(t, x, c) for x in times]

function close_encounter_automatic_work(trajectory)
    close_encounter_sum_work([close_encounter_solution_work(
        s isa ThreeBody3D.AutomaticCartesianSegment ? s.location.simulation.solution :
        s.location.regularized_result.solution) for s in trajectory.segments])
end
close_encounter_explicit_work(trajectory) = close_encounter_sum_work([(
    saved_states=s.saved_states, accepted_steps=s.accepted_steps,
    rejected_steps=s.rejected_steps, rhs_evaluations=s.rhs_evaluations)
    for s in trajectory.solver_statistics])

function close_encounter_transition_tuple(value)
    names = (:physical_time, :pair, :state_residual, :position_residual, :velocity_residual,
        :energy_jump, :momentum_jump, :angular_momentum_jump,
        :center_of_mass_jump, :center_of_mass_velocity_jump)
    NamedTuple{names}(Tuple(getfield(value, name) for name in names))
end

function close_encounter_fictitious_endpoints(automatic, explicit, exit_time)
    segment = close_encounter_automatic_regularized_segment(automatic)
    automatic_s = Float64(segment.location.fictitious_time)
    explicit_s = Float64(explicit.regularized_segment.exit_fictitious_time)
    automatic_time = Float64(segment.location.regularized_result.solution(automatic_s)[14])
    explicit_time = Float64(explicit.regularized_segment.regularized_result.solution(explicit_s)[14])
    result = (automatic_terminal_fictitious_time=automatic_s,
        explicit_terminal_fictitious_time=explicit_s,
        fictitious_time_difference=explicit_s - automatic_s,
        automatic_terminal_physical_time=automatic_time,
        explicit_terminal_physical_time=explicit_time,
        automatic_terminal_physical_time_residual=automatic_time - exit_time,
        explicit_terminal_physical_time_residual=explicit_time - exit_time)
    all(isfinite, values(result)) || throw(ArgumentError("Fictitious endpoint evidence is nonfinite."))
    result
end

function close_encounter_state_difference(first_state, second_state)
    first = close_encounter_pair_components(first_state)
    second = close_encounter_pair_components(second_state)
    (pair_position=norm(second.position - first.position),
        pair_velocity=norm(second.velocity - first.velocity),
        full_state=maximum(abs, Float64.(second_state) .- Float64.(first_state)))
end

using LinearAlgebra
using Printf
using ThreeBody3D

# Publication-oriented comparison for one controlled planar close encounter.
#
# The three Float64 methods use the same physical problem, output epochs,
# Cartesian tolerances, and regularized tolerances:
#
#   1. Cartesian propagation throughout;
#   2. experimental automatic switching;
#   3. explicit Cartesian -> Levi-Civita -> Cartesian composition.
#
# An independent BigFloat Cartesian solution provides the state-error reference.
# The explicit composition uses the entry and exit epochs detected by the
# automatic run. This isolates propagation differences from threshold-location
# differences and makes the regularized intervals directly comparable. Its
# physical-time targeting tolerance is intentionally omitted so that this
# validation exercises the composition API's derived targeting tolerance.

const REFERENCE_PRECISION = 256
const SAMPLE_STEP = 0.002
const SELECTED_PAIR = (1, 2)
const ENTRY_THRESHOLD = 0.10
const EXIT_THRESHOLD = 0.25
const CARTESIAN_TOLERANCE = 1e-13
const REGULARIZED_TOLERANCE = 1e-12
const EVALUATION_TOLERANCE = 1e-14

@inline decimal(::Type{Float64}, value::AbstractString) = parse(Float64, value)
@inline decimal(::Type{BigFloat}, value::AbstractString) = parse(BigFloat, value)

function close_encounter_problem(::Type{T}) where {T<:AbstractFloat}
    m1 = decimal(T, "1")
    m2 = decimal(T, "1")
    m3 = decimal(T, "0.001")
    G = decimal(T, "1")

    apoapsis = decimal(T, "1")
    periapsis = decimal(T, "0.0001")
    semimajor_axis = (apoapsis + periapsis) / T(2)
    binary_mu = G * (m1 + m2)
    relative_speed = sqrt(
        binary_mu * (T(2) / apoapsis - one(T) / semimajor_axis),
    )

    third_offset = decimal(T, "10")
    total_mass_value = m1 + m2 + m3
    binary_com_x = -(m3 / total_mass_value) * third_offset
    third_x = binary_com_x + third_offset

    r1 = T[binary_com_x + apoapsis / T(2), zero(T), zero(T)]
    r2 = T[binary_com_x - apoapsis / T(2), zero(T), zero(T)]
    r3 = T[third_x, zero(T), zero(T)]

    v1 = T[zero(T), relative_speed / T(2), zero(T)]
    v2 = T[zero(T), -relative_speed / T(2), zero(T)]
    v3 = T[zero(T), zero(T), zero(T)]

    (
        system=ThreeBodySystem((m1, m2, m3); G=G),
        u0=statevector(r1, v1, r2, v2, r3, v3),
        tspan=(zero(T), decimal(T, "1.6")),
        nominal_periapsis=periapsis,
    )
end

function sample_times(tspan; step=SAMPLE_STEP)
    times = collect(range(first(tspan); step=step, stop=last(tspan)))
    times[end] == last(tspan) || push!(times, last(tspan))
    times
end

@inline function body_state_ranges(body)
    position = (6body - 5):(6body - 3)
    velocity = (6body - 2):(6body)
    position, velocity
end

function pair_relative_components(state, pair=SELECTED_PAIR)
    i, j = pair
    ri, vi = body_state_ranges(i)
    rj, vj = body_state_ranges(j)
    (
        position=state[ri] .- state[rj],
        velocity=state[vi] .- state[vj],
    )
end

function pair_errors(state, reference_state)
    actual = pair_relative_components(state)
    reference = pair_relative_components(reference_state)
    position_error = norm(Float64.(actual.position) .- Float64.(reference.position))
    velocity_error = norm(Float64.(actual.velocity) .- Float64.(reference.velocity))
    (
        position=position_error,
        velocity=velocity_error,
        combined=hypot(position_error, velocity_error),
    )
end

function trajectory_errors(states, reference_states)
    errors = map(pair_errors, states, reference_states)
    (
        maximum_position=maximum(error.position for error in errors),
        maximum_velocity=maximum(error.velocity for error in errors),
        maximum_combined=maximum(error.combined for error in errors),
        final_position=last(errors).position,
        final_velocity=last(errors).velocity,
        final_combined=last(errors).combined,
    )
end

function conservation_report(system, times, states)
    initial_state = first(states)
    initial_time = first(times)
    initial_energy = total_energy(system, initial_state)
    initial_momentum = linear_momentum(system, initial_state)
    initial_angular_momentum = angular_momentum(system, initial_state)
    initial_com = center_of_mass(system, initial_state)
    initial_com_velocity = center_of_mass_velocity(system, initial_state)

    maximum_relative_energy_drift = zero(initial_energy)
    maximum_momentum_drift = zero(initial_energy)
    maximum_angular_momentum_drift = zero(initial_energy)
    maximum_com_residual = zero(initial_energy)
    minimum_pair_separation = oftype(initial_energy, Inf)

    for (time, state) in zip(times, states)
        energy = total_energy(system, state)
        relative_energy_drift = iszero(initial_energy) ?
            abs(energy - initial_energy) :
            abs((energy - initial_energy) / initial_energy)
        expected_com = initial_com + (time - initial_time) * initial_com_velocity

        maximum_relative_energy_drift = max(
            maximum_relative_energy_drift,
            relative_energy_drift,
        )
        maximum_momentum_drift = max(
            maximum_momentum_drift,
            norm(linear_momentum(system, state) - initial_momentum),
        )
        maximum_angular_momentum_drift = max(
            maximum_angular_momentum_drift,
            norm(angular_momentum(system, state) - initial_angular_momentum),
        )
        maximum_com_residual = max(
            maximum_com_residual,
            norm(center_of_mass(system, state) - expected_com),
        )
        minimum_pair_separation = min(
            minimum_pair_separation,
            minimum_separation(state),
        )
    end

    (
        maximum_relative_energy_drift=maximum_relative_energy_drift,
        maximum_momentum_drift=maximum_momentum_drift,
        maximum_angular_momentum_drift=maximum_angular_momentum_drift,
        maximum_com_residual=maximum_com_residual,
        minimum_separation=minimum_pair_separation,
    )
end

@inline function solution_work(solution)
    statistics = solution.stats
    (
        saved_states=length(solution.t),
        accepted_steps=Int(statistics.naccept),
        rejected_steps=Int(statistics.nreject),
        rhs_evaluations=Int(statistics.nf),
    )
end

function sum_work(items)
    (
        saved_states=sum(item.saved_states for item in items),
        accepted_steps=sum(item.accepted_steps for item in items),
        rejected_steps=sum(item.rejected_steps for item in items),
        rhs_evaluations=sum(item.rhs_evaluations for item in items),
    )
end

function switching_work(trajectory)
    sum_work([
        solution_work(
            segment isa AutomaticCartesianSegment ?
                segment.location.simulation.solution :
                segment.location.regularized_result.solution,
        )
        for segment in trajectory.segments
    ])
end

function composed_work(trajectory)
    sum_work([
        (
            saved_states=statistics.saved_states,
            accepted_steps=statistics.accepted_steps,
            rejected_steps=statistics.rejected_steps,
            rhs_evaluations=statistics.rhs_evaluations,
        )
        for statistics in trajectory.solver_statistics
    ])
end

function first_event(trajectory, kind)
    index = findfirst(event -> event.kind == kind, trajectory.switch_events)
    isnothing(index) && error("No $(kind) switch event was recorded.")
    trajectory.switch_events[index]
end


@inline function pair_radial_numerator(state, pair=SELECTED_PAIR)
    relative = pair_relative_components(state, pair)
    dot(relative.position, relative.velocity)
end

function periapsis_state(
    state_at_time,
    left,
    right;
    iterations=160,
)
    a = left
    b = right
    fa = pair_radial_numerator(state_at_time(a))
    fb = pair_radial_numerator(state_at_time(b))
    fa < zero(fa) || error(
        "Periapsis bracket must start on the inbound branch; r⋅v=$(fa).",
    )
    fb > zero(fb) || error(
        "Periapsis bracket must end on the outbound branch; r⋅v=$(fb).",
    )

    for _ in 1:iterations
        midpoint = a + (b - a) / 2
        (midpoint == a || midpoint == b) && break
        fm = pair_radial_numerator(state_at_time(midpoint))
        if fm <= zero(fm)
            a = midpoint
        else
            b = midpoint
        end
    end

    time = a + (b - a) / 2
    state = state_at_time(time)
    (
        time=time,
        separation=norm(pair_relative_components(state).position),
        radial_numerator=pair_radial_numerator(state),
        state=state,
    )
end

function regularized_segment(trajectory)
    index = findfirst(segment -> segment isa AutomaticRegularizedSegment, trajectory.segments)
    isnothing(index) && error("No automatic regularized segment was retained.")
    trajectory.segments[index]
end

function boundary_state_difference(reference_state, comparison_state)
    reference = pair_relative_components(reference_state)
    comparison = pair_relative_components(comparison_state)
    (
        position=norm(comparison.position - reference.position),
        velocity=norm(comparison.velocity - reference.velocity),
        state=maximum(abs, comparison_state .- reference_state),
    )
end


function endpoint_reference_report(state, reference_state)
    errors = pair_errors(state, reference_state)
    relative = pair_relative_components(state)
    separation = norm(relative.position)
    radial_rate = dot(relative.position, relative.velocity) / separation
    (
        pair_position_error=errors.position,
        pair_velocity_error=errors.velocity,
        full_state_error=maximum(
            abs, Float64.(state) .- Float64.(reference_state),
        ),
        separation=Float64(separation),
        radial_rate=Float64(radial_rate),
    )
end

function regularized_endpoint_time_report(automatic_segment, explicit_segment, exit_time)
    automatic_s = Float64(automatic_segment.location.fictitious_time)
    explicit_s = Float64(explicit_segment.exit_fictitious_time)
    automatic_solution_time = Float64(
        automatic_segment.location.regularized_result.solution(automatic_s)[14],
    )
    explicit_solution_time = Float64(
        explicit_segment.regularized_result.solution(explicit_s)[14],
    )
    (
        automatic_s=automatic_s,
        explicit_s=explicit_s,
        fictitious_time_difference=abs(explicit_s - automatic_s),
        automatic_solution_time=automatic_solution_time,
        explicit_solution_time=explicit_solution_time,
        automatic_time_residual=automatic_solution_time - Float64(exit_time),
        explicit_time_residual=explicit_solution_time - Float64(exit_time),
    )
end

function run_cartesian(problem, times, reference_states)
    elapsed = @elapsed result = simulate(
        problem.system,
        problem.u0,
        problem.tspan;
        solver=:accurate,
        reltol=CARTESIAN_TOLERANCE,
        abstol=CARTESIAN_TOLERANCE,
        saveat=times,
    )
    states = result.solution.u
    (
        name="Cartesian",
        elapsed=elapsed,
        states=states,
        conservation=conservation_report(problem.system, times, states),
        errors=trajectory_errors(states, reference_states),
        work=solution_work(result.solution),
        segments=1,
        switches=0,
        transition_residual=0.0,
        state_at_time=time -> Vector{Float64}(result.solution(time)),
        result=result,
    )
end

function run_automatic(problem, times, reference_states)
    parameters = AutomaticSwitchingParameters(
        enter_threshold=ENTRY_THRESHOLD,
        exit_threshold=EXIT_THRESHOLD,
        ambiguity_threshold=EXIT_THRESHOLD,
        minimum_separation_ratio=10.0,
        maximum_switches=10,
    )

    elapsed = @elapsed trajectory = simulate_experimental_switching(
        problem.system,
        problem.u0,
        problem.tspan,
        parameters;
        cartesian_kwargs=(
            solver=:accurate,
            reltol=CARTESIAN_TOLERANCE,
            abstol=CARTESIAN_TOLERANCE,
        ),
        regularized_kwargs=(
            reltol=REGULARIZED_TOLERANCE,
            abstol=REGULARIZED_TOLERANCE,
            initial_step=0.1,
        ),
    )
    trajectory.status == :completed || error(
        "Automatic switching failed: $(trajectory.failure)",
    )

    samples = sample_experimental_switching(
        trajectory,
        times;
        include_switches=false,
        regularized_kwargs=(
            tolerance=EVALUATION_TOLERANCE,
            max_iterations=256,
        ),
    )
    diagnostics = diagnostics_report(trajectory, samples)

    (
        name="Automatic switching",
        elapsed=elapsed,
        states=samples.states,
        conservation=conservation_report(problem.system, times, samples.states),
        errors=trajectory_errors(samples.states, reference_states),
        work=switching_work(trajectory),
        segments=diagnostics.segment_count,
        switches=diagnostics.switch_count,
        transition_residual=diagnostics.maximum_transition_state_residual,
        state_at_time=time -> experimental_switching_state(
            trajectory,
            time;
            regularized_kwargs=(
                tolerance=EVALUATION_TOLERANCE,
                max_iterations=256,
            ),
        ),
        result=trajectory,
    )
end

function run_explicit(problem, times, reference_states, automatic)
    entry_time = Float64(first_event(automatic.result, :entry).physical_time)
    exit_time = Float64(first_event(automatic.result, :exit).physical_time)

    elapsed = @elapsed trajectory = compose_regularized_trajectory(
        problem.system,
        problem.u0,
        problem.tspan,
        SELECTED_PAIR,
        (entry_time, exit_time);
        saveat=times,
        cartesian_solver=:accurate,
        cartesian_reltol=CARTESIAN_TOLERANCE,
        cartesian_abstol=CARTESIAN_TOLERANCE,
        regularized_reltol=REGULARIZED_TOLERANCE,
        regularized_abstol=REGULARIZED_TOLERANCE,
        regularized_initial_step=0.1,
        regularized_max_iterations=256,
    )
    states = [
        composed_regularized_state(
            trajectory,
            time;
            tolerance=EVALUATION_TOLERANCE,
        )
        for time in times
    ]
    transition_residual = max(
        trajectory.entry_continuity.state_residual,
        trajectory.exit_continuity.state_residual,
    )

    (
        name="Explicit regularized",
        elapsed=elapsed,
        states=states,
        conservation=conservation_report(problem.system, times, states),
        errors=trajectory_errors(states, reference_states),
        work=composed_work(trajectory),
        segments=3,
        switches=2,
        transition_residual=transition_residual,
        state_at_time=time -> composed_regularized_state(
            trajectory,
            time;
            tolerance=EVALUATION_TOLERANCE,
        ),
        result=trajectory,
    )
end

function print_method_table(cases)
    println("Conservation and single-run cost")
    @printf(
        "%-21s %11s %11s %11s %11s %11s %9s %9s\n",
        "method", "energy", "momentum", "ang-mom", "COM", "sample-min",
        "seconds", "RHS",
    )
    for case in cases
        report = case.conservation
        @printf(
            "%-21s %11.3e %11.3e %11.3e %11.3e %11.3e %9.3f %9d\n",
            case.name,
            report.maximum_relative_energy_drift,
            report.maximum_momentum_drift,
            report.maximum_angular_momentum_drift,
            report.maximum_com_residual,
            report.minimum_separation,
            case.elapsed,
            case.work.rhs_evaluations,
        )
    end

    println()
    println("Pair-relative error against BigFloat reference")
    @printf(
        "%-21s %11s %11s %11s %11s %11s\n",
        "method", "max-pos", "max-vel", "max-state", "final-pos", "final-vel",
    )
    for case in cases
        errors = case.errors
        @printf(
            "%-21s %11.3e %11.3e %11.3e %11.3e %11.3e\n",
            case.name,
            errors.maximum_position,
            errors.maximum_velocity,
            errors.maximum_combined,
            errors.final_position,
            errors.final_velocity,
        )
    end

    println()
    println("Segmentation and solver work")
    @printf(
        "%-21s %8s %8s %11s %11s %11s %13s\n",
        "method", "segments", "switches", "accepted", "rejected", "saved",
        "handoff-resid",
    )
    for case in cases
        @printf(
            "%-21s %8d %8d %11d %11d %11d %13.3e\n",
            case.name,
            case.segments,
            case.switches,
            case.work.accepted_steps,
            case.work.rejected_steps,
            case.work.saved_states,
            case.transition_residual,
        )
    end
end

problem = close_encounter_problem(Float64)
times = sample_times(problem.tspan)

println("Computing independent BigFloat Cartesian reference...")
reference_elapsed = @elapsed reference = setprecision(BigFloat, REFERENCE_PRECISION) do
    reference_problem = close_encounter_problem(BigFloat)
    simulate(
        reference_problem.system,
        reference_problem.u0,
        reference_problem.tspan;
        solver=:extreme,
        precision=REFERENCE_PRECISION,
        reltol=parse(BigFloat, "1e-30"),
        abstol=parse(BigFloat, "1e-30"),
        dense=true,
        save_everystep=true,
    )
end
reference_states = [reference.solution(BigFloat(time)) for time in times]

println("Computing Float64 comparison runs...")
cartesian = run_cartesian(problem, times, reference_states)
automatic = run_automatic(problem, times, reference_states)
explicit = run_explicit(problem, times, reference_states, automatic)
cases = (cartesian, automatic, explicit)

entry_time = first_event(automatic.result, :entry).physical_time
exit_time = first_event(automatic.result, :exit).physical_time

println()
println("ThreeBody3D close-encounter comparison")
println("  selected pair:                 ", SELECTED_PAIR)
println("  integration interval:          ", problem.tspan)
println("  sample step:                   ", SAMPLE_STEP)
println("  entry / exit thresholds:       ", ENTRY_THRESHOLD, " / ", EXIT_THRESHOLD)
println("  detected regularized interval: ", (entry_time, exit_time))
println("  nominal unperturbed periapsis: ", problem.nominal_periapsis)
println("  Cartesian tolerance:           ", CARTESIAN_TOLERANCE)
println("  regularized tolerance:         ", REGULARIZED_TOLERANCE)
println("  state-evaluation tolerance:    ", EVALUATION_TOLERANCE)
println("  explicit targeting tolerance:  derived from regularized tolerance")
println("  reference precision:           ", REFERENCE_PRECISION, " bits")
println("  reference elapsed seconds:     ", reference_elapsed)
println("  timing note:                   single runs include compilation effects")
println()

automatic_segment = regularized_segment(automatic.result)
entry_difference = boundary_state_difference(
    automatic_segment.entry_state,
    explicit.result.regularized_segment.entry_state,
)
exit_difference = boundary_state_difference(
    automatic_segment.exit_state,
    explicit.result.regularized_segment.exit_state,
)

reference_periapsis = periapsis_state(
    time -> reference.solution(BigFloat(time)),
    BigFloat(entry_time),
    BigFloat(exit_time),
)
periapses = [
    (
        name=case.name,
        result=periapsis_state(
            case.state_at_time,
            Float64(entry_time),
            Float64(exit_time),
        ),
    )
    for case in cases
]

print_method_table(cases)

println()
println("Automatic versus explicit regularized boundary states")
@printf(
    "%-10s %13s %13s %13s\n",
    "boundary", "pair-pos", "pair-vel", "full-state",
)
@printf(
    "%-10s %13.3e %13.3e %13.3e\n",
    "entry", entry_difference.position, entry_difference.velocity,
    entry_difference.state,
)
@printf(
    "%-10s %13.3e %13.3e %13.3e\n",
    "exit", exit_difference.position, exit_difference.velocity,
    exit_difference.state,
)

println()
println("Dense periapsis location inside the detected regularized interval")
@printf(
    "%-21s %18s %13s %13s %13s\n",
    "method", "time", "separation", "time-error", "sep-error",
)
@printf(
    "%-21s %18.12f %13.5e %13s %13s\n",
    "BigFloat reference",
    Float64(reference_periapsis.time),
    Float64(reference_periapsis.separation),
    "-", "-",
)
for item in periapses
    @printf(
        "%-21s %18.12f %13.5e %13.3e %13.3e\n",
        item.name,
        Float64(item.result.time),
        Float64(item.result.separation),
        abs(Float64(item.result.time - reference_periapsis.time)),
        abs(Float64(item.result.separation - reference_periapsis.separation)),
    )
end

reference_exit_state = reference.solution(BigFloat(exit_time))
automatic_exit_report = endpoint_reference_report(
    automatic_segment.exit_state,
    reference_exit_state,
)
explicit_exit_report = endpoint_reference_report(
    explicit.result.regularized_segment.exit_state,
    reference_exit_state,
)
endpoint_times = regularized_endpoint_time_report(
    automatic_segment,
    explicit.result.regularized_segment,
    exit_time,
)

println()
println("Regularized exit states against BigFloat reference")
@printf(
    "%-21s %13s %13s %13s %13s %13s\n",
    "method", "pair-pos", "pair-vel", "full-state", "separation", "radial-rate",
)
for (name, report) in (
    ("Automatic switching", automatic_exit_report),
    ("Explicit regularized", explicit_exit_report),
)
    @printf(
        "%-21s %13.3e %13.3e %13.3e %13.5e %13.5e\n",
        name,
        report.pair_position_error,
        report.pair_velocity_error,
        report.full_state_error,
        report.separation,
        report.radial_rate,
    )
end

println()
println("Regularized endpoint physical-time consistency")
@printf("  requested exit time:                    %.17g\n", Float64(exit_time))
@printf("  automatic endpoint fictitious time:     %.17g\n", endpoint_times.automatic_s)
@printf("  explicit endpoint fictitious time:      %.17g\n", endpoint_times.explicit_s)
@printf("  fictitious-time endpoint difference:     %.3e\n", endpoint_times.fictitious_time_difference)
@printf("  automatic stored Sundman time:          %.17g\n", endpoint_times.automatic_solution_time)
@printf("  explicit stored Sundman time:           %.17g\n", endpoint_times.explicit_solution_time)
@printf("  automatic Sundman-time residual:         %.3e\n", endpoint_times.automatic_time_residual)
@printf("  explicit Sundman-time residual:          %.3e\n", endpoint_times.explicit_time_residual)

using LinearAlgebra
using Printf
using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

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
const AUTOMATIC_MINIMUM_SEPARATION_RATIO = 10.0
const AUTOMATIC_MAXIMUM_SWITCHES = 10
const REGULARIZED_INITIAL_STEP = 0.1
const REGULARIZED_MAX_ITERATIONS = 256
const EVALUATION_MAX_ITERATIONS = 256
const REFERENCE_TOLERANCE = "1e-30"
const CLOSE_ENCOUNTER_AUTOMATIC_MAXIMUM_STATE_ERROR_LIMIT = 1.0e-9
const CLOSE_ENCOUNTER_EXPLICIT_MAXIMUM_STATE_ERROR_LIMIT = 1.0e-9
const CLOSE_ENCOUNTER_EXIT_STATE_AGREEMENT_LIMIT = 1.0e-10
const CLOSE_ENCOUNTER_EXPLICIT_EXIT_TIME_RESIDUAL_LIMIT = 5.0e-12
const CLOSE_ENCOUNTER_AUTOMATIC_PERIAPSIS_ERROR_LIMIT = 1.0e-10
const CLOSE_ENCOUNTER_EXPLICIT_PERIAPSIS_ERROR_LIMIT = 1.0e-10
const CLOSE_ENCOUNTER_CARTESIAN_UNDER_RESOLUTION_MINIMUM = 1.0e-3
const CLOSE_ENCOUNTER_AUTOMATIC_IMPROVEMENT_RATIO_LIMIT = 0.5

case_definition = close_encounter_case_definition()
experiment_environment = current_validation_environment()
protocol = resolve_case_protocol(case_definition, VALIDATION_SCHEMA_VERSION)

function switching_work(trajectory)
    ValidationFramework.close_encounter_automatic_work(trajectory)
end
function composed_work(trajectory)
    ValidationFramework.close_encounter_explicit_work(trajectory)
end
function first_event(trajectory, kind)
    events = ValidationFramework.close_encounter_switch_events(trajectory)
    kind == :entry ? first(events) : kind == :exit ? last(events) : error("Unsupported event kind.")
end


function regularized_segment(trajectory)
    ValidationFramework.close_encounter_automatic_regularized_segment(trajectory)
end

function boundary_state_difference(reference_state, comparison_state)
    value = ValidationFramework.close_encounter_state_difference(reference_state, comparison_state)
    (position=value.pair_position, velocity=value.pair_velocity, state=value.full_state)
end
function endpoint_reference_report(state, reference_state)
    errors = ValidationFramework.close_encounter_state_errors(state, reference_state)
    relative = ValidationFramework.close_encounter_pair_components(state)
    separation = norm(relative.position)
    radial_rate = dot(relative.position, relative.velocity) / separation
    (
        pair_position_error=errors.position,
        pair_velocity_error=errors.velocity,
        full_state_error=errors.full_state,
        separation=Float64(separation),
        radial_rate=Float64(radial_rate),
    )
end

function regularized_endpoint_time_report(automatic, explicit, exit_time)
    evidence = ValidationFramework.close_encounter_fictitious_endpoints(
        automatic, explicit, Float64(exit_time))
    (
        automatic_s=evidence.automatic_terminal_fictitious_time,
        explicit_s=evidence.explicit_terminal_fictitious_time,
        fictitious_time_difference=abs(evidence.fictitious_time_difference),
        automatic_solution_time=evidence.automatic_terminal_physical_time,
        explicit_solution_time=evidence.explicit_terminal_physical_time,
        automatic_time_residual=evidence.automatic_terminal_physical_time_residual,
        explicit_time_residual=evidence.explicit_terminal_physical_time_residual,
    )
end

function run_cartesian(
    problem,
    times,
    reference_states,
    definition,
    configuration,
    environment,
)
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
        definition=definition,
        configuration=configuration,
        environment=environment,
        execution=ExecutionOutcome(actual_completed; exit_code=0),
        elapsed=elapsed,
        states=states,
        conservation=ValidationFramework.close_encounter_conservation(problem.system, times, states),
        errors=ValidationFramework.close_encounter_trajectory_errors(states, reference_states),
        work=ValidationFramework.close_encounter_solution_work(result.solution),
        segments=1,
        switches=0,
        final_time=last(result.solution.t),
        state_at_time=time -> Vector{Float64}(result.solution(time)),
        result=result,
    )
end

function run_automatic(
    problem,
    times,
    reference_states,
    definition,
    configuration,
    environment,
)
    controls = ValidationFramework.close_encounter_regularized_controls(REGULARIZED_TOLERANCE)
    elapsed = @elapsed trajectory = ValidationFramework.close_encounter_automatic_propagation(problem, controls)
    trajectory.status == :completed || error(
        "Automatic switching failed: $(trajectory.failure)",
    )

    samples = sample_experimental_switching(
        trajectory,
        times;
        include_switches=false,
        regularized_kwargs=(
            tolerance=EVALUATION_TOLERANCE,
            max_iterations=EVALUATION_MAX_ITERATIONS,
        ),
    )
    diagnostics = diagnostics_report(trajectory, samples)

    (
        name="Automatic switching",
        definition=definition,
        configuration=configuration,
        environment=environment,
        execution=ExecutionOutcome(actual_completed; exit_code=0),
        elapsed=elapsed,
        states=samples.states,
        conservation=ValidationFramework.close_encounter_conservation(problem.system, times, samples.states),
        errors=ValidationFramework.close_encounter_trajectory_errors(samples.states, reference_states),
        work=switching_work(trajectory),
        segments=diagnostics.segment_count,
        switches=diagnostics.switch_count,
        transition_residual=diagnostics.maximum_transition_state_residual,
        final_time=last(samples.times),
        state_at_time=time -> ValidationFramework.close_encounter_automatic_state(trajectory, time, controls),
        result=trajectory,
    )
end

function run_explicit(
    problem,
    times,
    reference_states,
    automatic,
    definition,
    configuration,
    environment,
)
    entry_time = Float64(first_event(automatic.result, :entry).physical_time)
    exit_time = Float64(first_event(automatic.result, :exit).physical_time)

    controls = ValidationFramework.close_encounter_regularized_controls(REGULARIZED_TOLERANCE)
    elapsed = @elapsed trajectory = ValidationFramework.close_encounter_explicit_propagation(
        problem, (entry_time, exit_time), controls; saveat=times)
    states = ValidationFramework.close_encounter_explicit_states(trajectory, times, controls)
    transition_residual = max(
        trajectory.entry_continuity.state_residual,
        trajectory.exit_continuity.state_residual,
    )

    (
        name="Explicit regularized",
        definition=definition,
        configuration=configuration,
        environment=environment,
        execution=ExecutionOutcome(actual_completed; exit_code=0),
        elapsed=elapsed,
        states=states,
        conservation=ValidationFramework.close_encounter_conservation(problem.system, times, states),
        errors=ValidationFramework.close_encounter_trajectory_errors(states, reference_states),
        work=composed_work(trajectory),
        segments=3,
        switches=2,
        transition_residual=transition_residual,
        final_time=last(times),
        state_at_time=time -> ValidationFramework.close_encounter_explicit_state(trajectory, time, controls),
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
        transition_residual = hasproperty(case, :transition_residual) ?
            @sprintf("%.3e", case.transition_residual) :
            "-"
        @printf(
            "%-21s %8d %8d %11d %11d %11d %13s\n",
            case.name,
            case.segments,
            case.switches,
            case.work.accepted_steps,
            case.work.rejected_steps,
            case.work.saved_states,
            transition_residual,
        )
    end
end

problem = ValidationFramework.close_encounter_problem(Float64)
times = ValidationFramework.close_encounter_sample_times(problem.tspan)
experiment_configuration = ValidationFramework._close_encounter_configuration(
    initial_state=Tuple(problem.u0),
    masses=problem.physical_parameters.masses,
    gravitational_constant=problem.physical_parameters.gravitational_constant,
    apoapsis=problem.physical_parameters.apoapsis,
    nominal_periapsis=problem.nominal_periapsis,
    third_body_offset=problem.physical_parameters.third_body_offset,
    reference_precision=REFERENCE_PRECISION,
    sample_step=SAMPLE_STEP,
    selected_pair=SELECTED_PAIR,
    entry_threshold=ENTRY_THRESHOLD,
    exit_threshold=EXIT_THRESHOLD,
    cartesian_tolerance=CARTESIAN_TOLERANCE,
    regularized_tolerance=REGULARIZED_TOLERANCE,
    evaluation_tolerance=EVALUATION_TOLERANCE,
    time_interval=problem.tspan,
    automatic_ambiguity_threshold=EXIT_THRESHOLD,
    automatic_minimum_separation_ratio=AUTOMATIC_MINIMUM_SEPARATION_RATIO,
    automatic_maximum_switches=AUTOMATIC_MAXIMUM_SWITCHES,
    regularized_initial_step=REGULARIZED_INITIAL_STEP,
    regularized_max_iterations=REGULARIZED_MAX_ITERATIONS,
    evaluation_max_iterations=EVALUATION_MAX_ITERATIONS,
    reference_tolerance=REFERENCE_TOLERANCE,
    automatic_maximum_state_error_limit=CLOSE_ENCOUNTER_AUTOMATIC_MAXIMUM_STATE_ERROR_LIMIT,
    explicit_maximum_state_error_limit=CLOSE_ENCOUNTER_EXPLICIT_MAXIMUM_STATE_ERROR_LIMIT,
    exit_state_agreement_limit=CLOSE_ENCOUNTER_EXIT_STATE_AGREEMENT_LIMIT,
    explicit_exit_time_residual_limit=CLOSE_ENCOUNTER_EXPLICIT_EXIT_TIME_RESIDUAL_LIMIT,
    automatic_periapsis_separation_error_limit=CLOSE_ENCOUNTER_AUTOMATIC_PERIAPSIS_ERROR_LIMIT,
    explicit_periapsis_separation_error_limit=CLOSE_ENCOUNTER_EXPLICIT_PERIAPSIS_ERROR_LIMIT,
    cartesian_under_resolution_minimum=CLOSE_ENCOUNTER_CARTESIAN_UNDER_RESOLUTION_MINIMUM,
    automatic_improvement_ratio_limit=CLOSE_ENCOUNTER_AUTOMATIC_IMPROVEMENT_RATIO_LIMIT,
)

println("Computing independent BigFloat Cartesian reference...")
reference_elapsed = @elapsed reference = build_close_encounter_reference()
reference_states = reference.sampled_states

println("Computing Float64 comparison runs...")
cartesian = run_cartesian(
    problem, times, reference_states,
    case_definition, experiment_configuration, experiment_environment,
)
automatic = run_automatic(
    problem, times, reference_states,
    case_definition, experiment_configuration, experiment_environment,
)
explicit = run_explicit(
    problem, times, reference_states, automatic,
    case_definition, experiment_configuration, experiment_environment,
)
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

reference_boundaries = reference.boundaries
reference_periapsis = (
    time=reference_boundaries.periapsis_time,
    separation=reference_boundaries.periapsis_separation,
    radial_numerator=reference_boundaries.periapsis_residual,
    state=ValidationFramework.close_encounter_reference_state(
        reference, reference_boundaries.periapsis_time,
    ),
)
periapses = [
    (
        name=case.name,
        result=ValidationFramework.close_encounter_periapsis(
            case.state_at_time,
            Float64(entry_time),
            Float64(exit_time),
        ),
    )
    for case in cases
]
periapsis_by_name = Dict(item.name => item.result for item in periapses)
cases = Tuple(
    (;
        case...,
        periapsis_time_error=abs(Float64(
            periapsis_by_name[case.name].time - reference_periapsis.time,
        )),
        periapsis_separation_error=abs(Float64(
            periapsis_by_name[case.name].separation - reference_periapsis.separation,
        )),
    )
    for case in cases
)
cartesian, automatic, explicit = cases

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

reference_exit_state = ValidationFramework.close_encounter_reference_state(reference, exit_time)
automatic_exit_report = endpoint_reference_report(
    automatic_segment.exit_state,
    reference_exit_state,
)
explicit_exit_report = endpoint_reference_report(
    explicit.result.regularized_segment.exit_state,
    reference_exit_state,
)
endpoint_times = regularized_endpoint_time_report(
    automatic.result,
    explicit.result,
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


function validate_close_encounter_comparison(
    cartesian,
    automatic,
    explicit,
    exit_difference,
    reference_periapsis,
    periapses,
    endpoint_times,
)
    periapsis_by_name = Dict(item.name => item.result for item in periapses)
    automatic_periapsis = periapsis_by_name["Automatic switching"]
    explicit_periapsis = periapsis_by_name["Explicit regularized"]
    cartesian_periapsis = periapsis_by_name["Cartesian"]

    checks = (
        (
            "automatic maximum state error",
            automatic.errors.maximum_combined <= CLOSE_ENCOUNTER_AUTOMATIC_MAXIMUM_STATE_ERROR_LIMIT,
            automatic.errors.maximum_combined,
            "<= 1e-9",
        ),
        (
            "explicit maximum state error",
            explicit.errors.maximum_combined <= CLOSE_ENCOUNTER_EXPLICIT_MAXIMUM_STATE_ERROR_LIMIT,
            explicit.errors.maximum_combined,
            "<= 1e-9",
        ),
        (
            "automatic-explicit exit-state agreement",
            exit_difference.state <= CLOSE_ENCOUNTER_EXIT_STATE_AGREEMENT_LIMIT,
            exit_difference.state,
            "<= 1e-10",
        ),
        (
            "explicit Sundman exit-time residual",
            abs(endpoint_times.explicit_time_residual) <= CLOSE_ENCOUNTER_EXPLICIT_EXIT_TIME_RESIDUAL_LIMIT,
            abs(endpoint_times.explicit_time_residual),
            "<= 5e-12",
        ),
        (
            "automatic periapsis separation error",
            abs(Float64(
                automatic_periapsis.separation - reference_periapsis.separation,
            )) <= CLOSE_ENCOUNTER_AUTOMATIC_PERIAPSIS_ERROR_LIMIT,
            abs(Float64(
                automatic_periapsis.separation - reference_periapsis.separation,
            )),
            "<= 1e-10",
        ),
        (
            "explicit periapsis separation error",
            abs(Float64(
                explicit_periapsis.separation - reference_periapsis.separation,
            )) <= CLOSE_ENCOUNTER_EXPLICIT_PERIAPSIS_ERROR_LIMIT,
            abs(Float64(
                explicit_periapsis.separation - reference_periapsis.separation,
            )),
            "<= 1e-10",
        ),
        (
            "Cartesian under-resolution is exposed",
            abs(Float64(
                cartesian_periapsis.separation - reference_periapsis.separation,
            )) >= CLOSE_ENCOUNTER_CARTESIAN_UNDER_RESOLUTION_MINIMUM,
            abs(Float64(
                cartesian_periapsis.separation - reference_periapsis.separation,
            )),
            ">= 1e-3",
        ),
        (
            "automatic regularization improves maximum state error",
            automatic.errors.maximum_combined <= CLOSE_ENCOUNTER_AUTOMATIC_IMPROVEMENT_RATIO_LIMIT * cartesian.errors.maximum_combined,
            automatic.errors.maximum_combined / cartesian.errors.maximum_combined,
            "<= 0.5 times Cartesian",
        ),
    )

    println()
    println("Close-encounter validation acceptance criteria")
    for (name, passed, value, criterion) in checks
        @printf(
            "  %-52s %4s  value=%10.3e  criterion %s\n",
            name,
            passed ? "PASS" : "FAIL",
            value,
            criterion,
        )
    end

    failures = filter(check -> !check[2], checks)
    isempty(failures) || error(
        "Close-encounter validation failed $(length(failures)) acceptance criterion/criteria.",
    )

    nothing
end

structured_result = build_close_encounter_case_result(
        cartesian,
        automatic,
        explicit,
        exit_difference,
        reference_periapsis,
        periapses,
        endpoint_times,
        experiment_environment;
        automatic_maximum_state_error_limit=CLOSE_ENCOUNTER_AUTOMATIC_MAXIMUM_STATE_ERROR_LIMIT,
        explicit_maximum_state_error_limit=CLOSE_ENCOUNTER_EXPLICIT_MAXIMUM_STATE_ERROR_LIMIT,
        exit_state_agreement_limit=CLOSE_ENCOUNTER_EXIT_STATE_AGREEMENT_LIMIT,
        explicit_exit_time_residual_limit=CLOSE_ENCOUNTER_EXPLICIT_EXIT_TIME_RESIDUAL_LIMIT,
        automatic_periapsis_separation_error_limit=CLOSE_ENCOUNTER_AUTOMATIC_PERIAPSIS_ERROR_LIMIT,
        explicit_periapsis_separation_error_limit=CLOSE_ENCOUNTER_EXPLICIT_PERIAPSIS_ERROR_LIMIT,
        cartesian_under_resolution_minimum=CLOSE_ENCOUNTER_CARTESIAN_UNDER_RESOLUTION_MINIMUM,
        automatic_improvement_ratio_limit=CLOSE_ENCOUNTER_AUTOMATIC_IMPROVEMENT_RATIO_LIMIT,
        configuration=experiment_configuration,
)
investigation_series = close_encounter_representation_investigation_series(
    structured_result, cases,
)
investigation_report_path = get(ENV, "THREEBODY3D_INVESTIGATION_SERIES_REPORT", "")
isempty(investigation_report_path) ||
    write_investigation_series_atomic(investigation_report_path, investigation_series)

if report_requested(protocol)
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_close_encounter_comparison(
        cartesian,
        automatic,
        explicit,
        exit_difference,
        reference_periapsis,
        periapses,
        endpoint_times,
    )
end

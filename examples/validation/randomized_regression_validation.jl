using Random
using LinearAlgebra
using ThreeBody3D

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

# Stage 9 randomized regression validation.
#
# This is deliberately an example-level research validation rather than a
# registered package benchmark. The deterministic seed makes failures
# reproducible while the generation rules are evaluated and refined.
#
# The generated systems:
#   * have three positive masses in a controlled range;
#   * begin with their centre of mass at the origin;
#   * begin with zero total linear momentum;
#   * have no initially close pair;
#   * are scaled to a negative total Newtonian energy.

const RANDOMIZED_VALIDATION_SEED = 0x3b0d_9a71
const RANDOMIZED_VALIDATION_TRIALS = 25
const RANDOMIZED_VALIDATION_DURATION = 5.0
const RANDOMIZED_VALIDATION_SAVEAT = 0.05
const RANDOMIZED_VALIDATION_MINIMUM_INITIAL_SEPARATION = 0.75
const RANDOMIZED_VALIDATION_ENERGY_DRIFT_LIMIT = 1e-8
const RANDOMIZED_VALIDATION_MOMENTUM_DRIFT_LIMIT = 1e-10
const RANDOMIZED_VALIDATION_ANGULAR_MOMENTUM_DRIFT_LIMIT = 1e-9
const RANDOMIZED_VALIDATION_COM_LIMIT = 1e-10

protocol = resolve_case_protocol(randomized_regression_case_definition(), VALIDATION_SCHEMA_VERSION)

struct RandomizedTrialResult
    trial::Int
    completed::Bool
    finite::Bool
    maximum_relative_energy_drift::Float64
    maximum_momentum_drift::Float64
    maximum_angular_momentum_drift::Float64
    maximum_com_residual::Float64
    minimum_separation::Float64
    message::String
end

function pair_separations(positions)
    (
        norm(positions[1] - positions[2]),
        norm(positions[1] - positions[3]),
        norm(positions[2] - positions[3]),
    )
end

function center_positions!(positions, masses)
    total_mass = sum(masses)
    center = sum(masses[i] .* positions[i] for i in 1:3) ./ total_mass
    for position in positions
        position .-= center
    end
    positions
end

function center_velocities!(velocities, masses)
    total_mass = sum(masses)
    center_velocity =
        sum(masses[i] .* velocities[i] for i in 1:3) ./ total_mass
    for velocity in velocities
        velocity .-= center_velocity
    end
    velocities
end

function gravitational_potential_energy(positions, masses; G=1.0)
    -G * (
        masses[1] * masses[2] / norm(positions[1] - positions[2]) +
        masses[1] * masses[3] / norm(positions[1] - positions[3]) +
        masses[2] * masses[3] / norm(positions[2] - positions[3])
    )
end

function kinetic_energy(velocities, masses)
    sum(0.5 * masses[i] * dot(velocities[i], velocities[i]) for i in 1:3)
end

function randomized_bound_initial_conditions(rng)
    masses = 0.5 .+ 1.5 .* rand(rng, 3)

    positions = Vector{Vector{Float64}}()
    while true
        positions = [randn(rng, 3) for _ in 1:3]
        center_positions!(positions, masses)
        minimum(pair_separations(positions)) >=
            RANDOMIZED_VALIDATION_MINIMUM_INITIAL_SEPARATION && break
    end

    velocities = [randn(rng, 3) for _ in 1:3]
    center_velocities!(velocities, masses)

    potential = gravitational_potential_energy(positions, masses)
    kinetic = kinetic_energy(velocities, masses)

    # Set K = |U| / 4. The total energy is therefore -3|U|/4, comfortably
    # negative without forcing every trial into an almost static collapse.
    target_kinetic = -potential / 4
    velocity_scale = sqrt(target_kinetic / kinetic)
    for velocity in velocities
        velocity .*= velocity_scale
    end
    center_velocities!(velocities, masses)

    system = ThreeBodySystem(masses; G=1.0)
    u0 = statevector(
        positions[1], velocities[1],
        positions[2], velocities[2],
        positions[3], velocities[3],
    )
    system, u0
end

function run_randomized_trial(rng, trial)
    try
        system, u0 = randomized_bound_initial_conditions(rng)
        # Use the public accuracy profile without forwarding tolerance
        # keywords that are not part of ThreeBody3D's user-facing API.
        result = simulate(
            system,
            u0,
            (0.0, RANDOMIZED_VALIDATION_DURATION);
            solver=:accurate,
            saveat=RANDOMIZED_VALIDATION_SAVEAT,
        )

        diagnostics = diagnostics_report(result)
        finite = all(state -> all(isfinite, state), result.solution.u)
        completed = isapprox(
            last(result.solution.t),
            RANDOMIZED_VALIDATION_DURATION;
            rtol=0,
            atol=100eps(RANDOMIZED_VALIDATION_DURATION),
        )

        RandomizedTrialResult(
            trial,
            completed,
            finite,
            Float64(diagnostics.maximum_relative_energy_drift),
            Float64(diagnostics.maximum_linear_momentum_drift),
            Float64(diagnostics.maximum_angular_momentum_drift),
            Float64(diagnostics.maximum_center_of_mass_residual),
            Float64(diagnostics.minimum_separation),
            "",
        )
    catch exception
        RandomizedTrialResult(
            trial,
            false,
            false,
            Inf,
            Inf,
            Inf,
            Inf,
            NaN,
            sprint(showerror, exception),
        )
    end
end

function trial_passed(result)
    result.completed &&
    result.finite &&
    result.maximum_relative_energy_drift <=
        RANDOMIZED_VALIDATION_ENERGY_DRIFT_LIMIT &&
    result.maximum_momentum_drift <=
        RANDOMIZED_VALIDATION_MOMENTUM_DRIFT_LIMIT &&
    result.maximum_angular_momentum_drift <=
        RANDOMIZED_VALIDATION_ANGULAR_MOMENTUM_DRIFT_LIMIT &&
    result.maximum_com_residual <= RANDOMIZED_VALIDATION_COM_LIMIT
end

function median_value(values)
    ordered = sort(collect(values))
    count = length(ordered)
    middle = fld(count, 2)
    isodd(count) ? ordered[middle + 1] :
        (ordered[middle] + ordered[middle + 1]) / 2
end

function run_randomized_regression_validation(;
    seed=RANDOMIZED_VALIDATION_SEED,
    trials=RANDOMIZED_VALIDATION_TRIALS,
)
    trials > 0 || throw(ArgumentError("trials must be positive."))
    rng = Xoshiro(seed)
    results = [run_randomized_trial(rng, trial) for trial in 1:trials]
    passing = count(trial_passed, results)
    completed = count(result -> result.completed, results)
    finite = count(result -> result.finite, results)

    energy_drifts =
        [result.maximum_relative_energy_drift for result in results if isfinite(result.maximum_relative_energy_drift)]
    momentum_drifts =
        [result.maximum_momentum_drift for result in results if isfinite(result.maximum_momentum_drift)]
    angular_momentum_drifts =
        [result.maximum_angular_momentum_drift for result in results if isfinite(result.maximum_angular_momentum_drift)]
    com_residuals =
        [result.maximum_com_residual for result in results if isfinite(result.maximum_com_residual)]
    separations =
        [result.minimum_separation for result in results if isfinite(result.minimum_separation)]

    println("ThreeBody3D randomized regression validation")
    println("  deterministic seed:                 ", seed)
    println("  trials:                             ", trials)
    println("  completed integrations:             ", completed)
    println("  finite trajectories:                ", finite)
    println("  trials within validation limits:    ", passing)
    if isempty(energy_drifts)
        println("  maximum relative energy drift:      unavailable")
        println("  median relative energy drift:       unavailable")
        println("  maximum momentum drift:             unavailable")
        println("  maximum angular momentum drift:     unavailable")
        println("  maximum COM residual:               unavailable")
        println("  closest encountered separation:     unavailable")
    else
        println("  maximum relative energy drift:      ", maximum(energy_drifts))
        println("  median relative energy drift:       ", median_value(energy_drifts))
        println("  maximum momentum drift:             ", maximum(momentum_drifts))
        println("  maximum angular momentum drift:     ", maximum(angular_momentum_drifts))
        println("  maximum COM residual:               ", maximum(com_residuals))
        println("  closest encountered separation:     ", minimum(separations))
    end

    failures = filter(result -> !trial_passed(result), results)
    if !isempty(failures)
        println()
        println("Trials outside validation limits")
        for result in failures
            println(
                "  trial ", result.trial,
                ": completed=", result.completed,
                ", finite=", result.finite,
                ", energy=", result.maximum_relative_energy_drift,
                ", momentum=", result.maximum_momentum_drift,
                ", angular_momentum=", result.maximum_angular_momentum_drift,
                ", COM=", result.maximum_com_residual,
                ", minimum_separation=", result.minimum_separation,
                isempty(result.message) ? "" : ", error=$(result.message)",
            )
        end
    end

    (; seed, trials, passing, completed, finite, results)
end

randomized_validation = run_randomized_regression_validation()

include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

randomized_criteria = (
    validation_criterion(
        "completed integrations",
        randomized_validation.completed,
        "== $(randomized_validation.trials)",
        randomized_validation.completed == randomized_validation.trials,
    ),
    validation_criterion(
        "finite trajectories",
        randomized_validation.finite,
        "== $(randomized_validation.trials)",
        randomized_validation.finite == randomized_validation.trials,
    ),
    validation_criterion(
        "trials within validation limits",
        randomized_validation.passing,
        "== $(randomized_validation.trials)",
        randomized_validation.passing == randomized_validation.trials,
    ),
)

if report_requested(protocol)
    structured_result = build_randomized_regression_case_result(
        randomized_validation,
        current_validation_environment();
        duration=RANDOMIZED_VALIDATION_DURATION,
        saveat=RANDOMIZED_VALIDATION_SAVEAT,
        minimum_initial_separation=RANDOMIZED_VALIDATION_MINIMUM_INITIAL_SEPARATION,
        energy_drift_limit=RANDOMIZED_VALIDATION_ENERGY_DRIFT_LIMIT,
        momentum_drift_limit=RANDOMIZED_VALIDATION_MOMENTUM_DRIFT_LIMIT,
        angular_momentum_drift_limit=RANDOMIZED_VALIDATION_ANGULAR_MOMENTUM_DRIFT_LIMIT,
        center_of_mass_limit=RANDOMIZED_VALIDATION_COM_LIMIT,
        solver=:accurate,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria(
        "Randomized-regression validation acceptance criteria",
        randomized_criteria,
    )
end

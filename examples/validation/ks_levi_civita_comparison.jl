using ThreeBody3D
using LinearAlgebra

include(joinpath(@__DIR__, "framework", "ValidationFramework.jl"))
using .ValidationFramework

const KS_LEVI_CIVITA_DISCREPANCY_LIMIT = 5e-10
const KS_LEVI_CIVITA_CONDITIONING_RATIO_LIMIT = 2.0

protocol = resolve_case_protocol(
    ks_levi_civita_comparison_case_definition(),
    VALIDATION_SCHEMA_VERSION,
)

# Cross-validate the independent planar Levi-Civita and spatial KS
# regularizations in physical Cartesian variables.
include(joinpath(@__DIR__, "AcceptanceCriteria.jl"))

function main()

mu = 1.0
q = [2.0, 0.0]
v = [0.0, 0.0]
oscillator = ThreeBody3D.LeviCivitaOscillator(mu, q, v)
collision_time = ThreeBody3D.levi_civita_physical_time(oscillator, pi)
times = [
    0.0,
    0.25collision_time,
    0.75collision_time,
    collision_time * (1 - 1e-6),
    collision_time * (1 + 1e-6),
    1.25collision_time,
]
report = ThreeBody3D.cross_validate_ks_levi_civita(mu, q, v, times)

println("KS and Levi-Civita cross-validation")
println("  samples:                         ", length(report.samples))
println("  maximum scaled position error:  ", report.maximum_position_error)
println("  maximum scaled velocity error:  ", report.maximum_velocity_error)
println("  maximum scaled time error:      ", report.maximum_time_error)
println("  maximum scaled energy error:    ", report.maximum_energy_error)
println("  final transition position error:", report.final_transition_position_error)
println("  final transition velocity error:", report.final_transition_velocity_error)

worst_velocity_index = argmax(sample.velocity_error for sample in report.samples)
worst_velocity_sample = report.samples[worst_velocity_index]
velocity_difference = worst_velocity_sample.ks_velocity - worst_velocity_sample.levi_civita_velocity
absolute_velocity_difference = norm(velocity_difference)
ks_velocity_norm = norm(worst_velocity_sample.ks_velocity)
levi_civita_velocity_norm = norm(worst_velocity_sample.levi_civita_velocity)
relative_velocity_difference = absolute_velocity_difference /
    max(ks_velocity_norm, levi_civita_velocity_norm, eps(report.numeric_type))
absolute_position_difference = norm(
    worst_velocity_sample.ks_position - worst_velocity_sample.levi_civita_position,
)

# Cartesian velocity becomes increasingly sensitive to position error near a
# binary collision. Keep the strict relative-velocity criterion for ordinary
# samples, but assess near-collision samples against the first-order velocity
# discrepancy predicted from their position discrepancy:
#
#     |δv| ≈ μ |δr| / (|v| r²).
#
# The near-collision boundary is deliberately tied to the initial length scale
# of this reproducible radial benchmark rather than to an absolute unit.
initial_radius = norm(report.initial_position)
near_collision_radius = initial_radius * 1e-3
conditioning_ratio_limit = KS_LEVI_CIVITA_CONDITIONING_RATIO_LIMIT
roundoff_floor = 64eps(report.numeric_type)

ordinary_velocity_errors = report.numeric_type[]
near_collision_conditioning_ratios = report.numeric_type[]
near_collision_diagnostics = NamedTuple[]

for (index, sample) in pairs(report.samples)
    ks_radius = norm(sample.ks_position)
    levi_civita_radius = norm(sample.levi_civita_position)
    reference_radius = max((ks_radius + levi_civita_radius) / 2, eps(report.numeric_type))
    ks_speed = norm(sample.ks_velocity)
    levi_civita_speed = norm(sample.levi_civita_velocity)
    reference_speed = max((ks_speed + levi_civita_speed) / 2, eps(report.numeric_type))
    position_difference = norm(sample.ks_position - sample.levi_civita_position)
    observed_velocity_difference = norm(sample.ks_velocity - sample.levi_civita_velocity)

    if reference_radius <= near_collision_radius
        predicted_velocity_difference = report.gravitational_parameter * position_difference /
            (reference_speed * reference_radius^2)
        velocity_scale = max(one(report.numeric_type), ks_speed, levi_civita_speed)
        absolute_floor = roundoff_floor * velocity_scale
        conditioning_ratio = observed_velocity_difference /
            max(predicted_velocity_difference, absolute_floor)
        push!(near_collision_conditioning_ratios, conditioning_ratio)
        push!(near_collision_diagnostics, (
            index=index,
            physical_time=sample.physical_time,
            radius=reference_radius,
            observed_velocity_difference=observed_velocity_difference,
            predicted_velocity_difference=predicted_velocity_difference,
            conditioning_ratio=conditioning_ratio,
        ))
    else
        push!(ordinary_velocity_errors, sample.velocity_error)
    end
end

maximum_ordinary_velocity_error = isempty(ordinary_velocity_errors) ?
    zero(report.numeric_type) : maximum(ordinary_velocity_errors)
maximum_near_collision_conditioning_ratio = isempty(near_collision_conditioning_ratios) ?
    zero(report.numeric_type) : maximum(near_collision_conditioning_ratios)

println()
println("Worst velocity-discrepancy sample")
println("  sample index:                    ", worst_velocity_index)
println("  physical time:                   ", worst_velocity_sample.physical_time)
println("  KS velocity:                     ", worst_velocity_sample.ks_velocity)
println("  Levi-Civita velocity:            ", worst_velocity_sample.levi_civita_velocity)
println("  velocity difference vector:      ", velocity_difference)
println("  absolute velocity difference:    ", absolute_velocity_difference)
println("  relative velocity difference:    ", relative_velocity_difference)
println("  KS velocity norm:                ", ks_velocity_norm)
println("  Levi-Civita velocity norm:       ", levi_civita_velocity_norm)
println("  absolute position difference:    ", absolute_position_difference)
println("  scaled position error:           ", worst_velocity_sample.position_error)

println()
println("Velocity-conditioning classification")
println("  near-collision radius threshold: ", near_collision_radius)
println("  ordinary samples:                ", length(ordinary_velocity_errors))
println("  near-collision samples:          ", length(near_collision_conditioning_ratios))
println("  maximum ordinary velocity error: ", maximum_ordinary_velocity_error)
println("  maximum conditioning ratio:      ", maximum_near_collision_conditioning_ratio)
for diagnostic in near_collision_diagnostics
    println("  near-collision sample ", diagnostic.index)
    println("    physical time:                 ", diagnostic.physical_time)
    println("    reference radius:              ", diagnostic.radius)
    println("    observed velocity difference:  ", diagnostic.observed_velocity_difference)
    println("    predicted velocity difference: ", diagnostic.predicted_velocity_difference)
    println("    conditioning ratio:            ", diagnostic.conditioning_ratio)
end

limit = KS_LEVI_CIVITA_DISCREPANCY_LIMIT
criteria = (
    validation_criterion("maximum scaled position discrepancy", report.maximum_position_error,
        "<= $(limit)", report.maximum_position_error <= limit),
    validation_criterion("maximum ordinary scaled velocity discrepancy", maximum_ordinary_velocity_error,
        "<= $(limit)", maximum_ordinary_velocity_error <= limit),
    validation_criterion("maximum near-collision velocity-conditioning ratio",
        maximum_near_collision_conditioning_ratio,
        "<= $(conditioning_ratio_limit)",
        maximum_near_collision_conditioning_ratio <= conditioning_ratio_limit),
    validation_criterion("maximum scaled physical-time discrepancy", report.maximum_time_error,
        "<= $(limit)", report.maximum_time_error <= limit),
    validation_criterion("maximum scaled specific-energy discrepancy", report.maximum_energy_error,
        "<= $(limit)", report.maximum_energy_error <= limit),
    validation_criterion("maximum KS specific-energy drift", report.maximum_ks_energy_drift,
        "<= $(limit)", report.maximum_ks_energy_drift <= limit),
    validation_criterion("maximum Levi-Civita specific-energy drift", report.maximum_levi_civita_energy_drift,
        "<= $(limit)", report.maximum_levi_civita_energy_drift <= limit),
    validation_criterion("final transition position discrepancy", report.final_transition_position_error,
        "<= $(limit)", report.final_transition_position_error <= limit),
    validation_criterion("final transition velocity discrepancy", report.final_transition_velocity_error,
        "<= $(limit)", report.final_transition_velocity_error <= limit),
)
if report_requested(protocol)
    structured_result = build_ks_levi_civita_comparison_case_result(
        report.maximum_position_error,
        maximum_ordinary_velocity_error,
        maximum_near_collision_conditioning_ratio,
        report.maximum_time_error,
        report.maximum_energy_error,
        report.maximum_ks_energy_drift,
        report.maximum_levi_civita_energy_drift,
        report.final_transition_position_error,
        report.final_transition_velocity_error,
        SolverStatistics(),
        current_validation_environment();
        gravitational_parameter=mu,
        initial_position=(q[1], q[2]),
        initial_velocity=(v[1], v[2]),
        collision_time=collision_time,
        sample_times=Tuple(times),
        near_collision_radius=near_collision_radius,
        ordinary_sample_count=length(ordinary_velocity_errors),
        near_collision_sample_count=length(near_collision_conditioning_ratios),
        discrepancy_limit=KS_LEVI_CIVITA_DISCREPANCY_LIMIT,
        conditioning_ratio_limit=KS_LEVI_CIVITA_CONDITIONING_RATIO_LIMIT,
    )
    exit_code = publish_case_result(protocol, structured_result; render=false)
    exit_code == 0 || exit(exit_code)
else
    validate_acceptance_criteria("KS/Levi-Civita comparison acceptance criteria", criteria)
end
end

main()

# Structured adapter for the KS radial-collision continuation validation.

const KS_COLLISION_CONTINUATION_DEFINITION_VERSION = "1.0.0"

function ks_collision_continuation_case_definition()
    ValidationCaseDefinition(
        :ks_collision_continuation,
        "KS collision-continuation validation",
        "Finite Kustaanheimo-Stiefel continuation through an exact radial binary collision, compared with the analytic fictitious-time solution on both sides of the singular instant.",
        (:ks, :collision, :continuation, :analytic_reference, :regularization),
        (:ks_collision_continuation, :ks_benchmark),
        "examples/validation/ks_collision_continuation.jl",
        (:standard,),
        expected_completed,
        true,
        KS_COLLISION_CONTINUATION_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_ks_collision_continuation_case_result(
    collision_radius,
    position_symmetry_error,
    maximum_u_error,
    maximum_w_error,
    maximum_time_error,
    collision_energy_residual,
    postcollision_finite::Bool,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    gravitational_parameter,
    initial_position,
    initial_velocity,
    fictitious_time_interval,
    collision_fictitious_time,
    collision_physical_time,
    symmetry_probe,
    saved_state_count,
    collision_radius_limit,
    symmetry_error_limit,
    position_error_limit,
    velocity_error_limit,
    time_error_limit,
    energy_residual_limit,
    algorithm,
    relative_tolerance,
    absolute_tolerance,
)
    builder = ValidationCaseResultBuilder(
        ks_collision_continuation_case_definition(),
        environment,
    )
    record_configuration!(builder, ValidationConfiguration(
        solver=algorithm,
        absolute_tolerance=absolute_tolerance,
        relative_tolerance=relative_tolerance,
        time_interval=fictitious_time_interval,
        sampling="$(saved_state_count) equally spaced fictitious-time samples with an exact collision tstop",
        thresholds=(
            ValidationParameter(:collision_radius_limit, collision_radius_limit),
            ValidationParameter(:position_symmetry_error_limit, symmetry_error_limit),
            ValidationParameter(:position_error_limit, position_error_limit),
            ValidationParameter(:velocity_error_limit, velocity_error_limit),
            ValidationParameter(:physical_time_error_limit, time_error_limit),
            ValidationParameter(:collision_energy_residual_limit, energy_residual_limit),
        ),
        parameters=(
            ValidationParameter(:gravitational_parameter, gravitational_parameter),
            ValidationParameter(:initial_position, initial_position),
            ValidationParameter(:initial_velocity, initial_velocity),
            ValidationParameter(:collision_fictitious_time, collision_fictitious_time),
            ValidationParameter(:collision_physical_time, collision_physical_time),
            ValidationParameter(:symmetry_probe, symmetry_probe),
        ),
    ))

    metrics = (
        ValidationMetric(:collision_radius, "Reconstructed collision radius", collision_radius;
            scale=scale_dimensional, role=role_acceptance),
        ValidationMetric(:position_symmetry_error, "Symmetric Cartesian-position error across collision", position_symmetry_error;
            scale=scale_absolute, role=role_acceptance),
        ValidationMetric(:maximum_u_error, "Maximum numerical KS coordinate error", maximum_u_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_w_error, "Maximum numerical KS derivative error", maximum_w_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_physical_time_error, "Maximum physical-time error", maximum_time_error;
            scale=scale_duration, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:collision_energy_residual, "Collision energy-consistency residual", collision_energy_residual;
            scale=scale_dimensionless, role=role_acceptance),
        ValidationMetric(:postcollision_finite, "Post-collision state remained finite", postcollision_finite;
            role=role_acceptance),
        ValidationMetric(:collision_physical_time, "Collision physical time", collision_physical_time;
            scale=scale_duration, role=role_descriptive),
        ValidationMetric(:saved_states, "Saved states", saved_state_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    for (criterion_id, label, metric_id, limit) in (
        (:collision_radius_within_limit, "Reconstructed collision radius", :collision_radius, collision_radius_limit),
        (:position_symmetry_within_limit, "Symmetric Cartesian position across collision", :position_symmetry_error, symmetry_error_limit),
        (:position_error_within_limit, "Maximum numerical KS coordinate error", :maximum_u_error, position_error_limit),
        (:velocity_error_within_limit, "Maximum numerical KS derivative error", :maximum_w_error, velocity_error_limit),
        (:physical_time_error_within_limit, "Maximum physical-time error", :maximum_physical_time_error, time_error_limit),
        (:collision_energy_within_limit, "Collision energy-consistency residual", :collision_energy_residual, energy_residual_limit),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id,
            label,
            metric_id,
            relation_less_than_or_equal;
            expected_value=limit,
        ))
    end
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :postcollision_continuation_finite,
        "Finite post-collision continuation",
        :postcollision_finite,
        relation_true,
    ))

    record_solver_statistics!(builder, solver_statistics)
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

# Structured adapter for the equilateral triple-collision reference validation.

const TRIPLE_COLLISION_DEFINITION_VERSION = "1.0.0"

function triple_collision_case_definition()
    ValidationCaseDefinition(
        :equilateral_triple_collision_reference,
        "Equilateral triple-collision reference",
        "Homothetic equal-mass triple collapse compared with the analytic radial free-fall solution up to a declared pre-collision separation cutoff.",
        (:triple_collision, :analytic_reference, :singular_limit),
        (:triple_collision, :core_benchmark),
        "examples/validation/equilateral_triple_collision_reference.jl",
        (:standard,),
        expected_stop,
        true,
        TRIPLE_COLLISION_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_triple_collision_case_result(
    terminated_at_close_approach::Bool,
    event_time,
    event_separation,
    maximum_scaled_position_error,
    maximum_scaled_velocity_error,
    validated_saved_states::Integer,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    collision_time,
    return_time,
    final_time,
    close_approach_threshold,
    validation_minimum_separation,
    position_error_limit,
    velocity_error_limit,
    event_separation_relative_limit,
    solver,
    absolute_tolerance,
    relative_tolerance,
    saveat,
    masses,
    gravitational_constant,
    side_length,
)
    event_separation_relative_residual =
        abs(event_separation - close_approach_threshold) / close_approach_threshold

    builder = ValidationCaseResultBuilder(triple_collision_case_definition(), environment)
    record_configuration!(builder, ValidationConfiguration(
        solver=solver,
        absolute_tolerance=absolute_tolerance,
        relative_tolerance=relative_tolerance,
        time_interval=(zero(collision_time), collision_time),
        sampling="saveat=$(saveat)",
        thresholds=(
            ValidationParameter(:close_approach_threshold, close_approach_threshold),
            ValidationParameter(:validation_minimum_separation, validation_minimum_separation),
            ValidationParameter(:position_error_limit, position_error_limit),
            ValidationParameter(:velocity_error_limit, velocity_error_limit),
            ValidationParameter(:event_separation_relative_limit, event_separation_relative_limit),
        ),
        parameters=(
            ValidationParameter(:masses, masses),
            ValidationParameter(:gravitational_constant, gravitational_constant),
            ValidationParameter(:side_length, side_length),
            ValidationParameter(:analytic_collision_time, collision_time),
            ValidationParameter(:analytic_return_time, return_time),
            ValidationParameter(:analytic_reference_final_time, final_time),
        ),
    ))

    metrics = (
        ValidationMetric(:terminated_at_close_approach, "Integration terminated at close-approach event", terminated_at_close_approach;
            role=role_acceptance),
        ValidationMetric(:event_separation_relative_residual, "Event-separation relative residual", event_separation_relative_residual;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_final),
        ValidationMetric(:maximum_scaled_position_error, "Maximum scaled position error", maximum_scaled_position_error;
            scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_scaled_velocity_error, "Maximum scaled velocity error", maximum_scaled_velocity_error;
            scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:numerical_stop_time, "Numerical stop time", event_time;
            scale=scale_duration, role=role_descriptive, aggregation=aggregation_final),
        ValidationMetric(:numerical_stop_separation, "Numerical stop separation", event_separation;
            scale=scale_dimensional, role=role_descriptive, aggregation=aggregation_final),
        ValidationMetric(:validated_saved_states, "Validated saved states", validated_saved_states;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :terminated_at_close_approach,
        "Integration terminated at close-approach event",
        :terminated_at_close_approach,
        relation_true,
    ))
    for (criterion_id, label, metric_id, expected_value) in (
        (:event_separation_within_limit, "Event-separation relative residual", :event_separation_relative_residual, event_separation_relative_limit),
        (:position_error_within_limit, "Maximum scaled position error", :maximum_scaled_position_error, position_error_limit),
        (:velocity_error_within_limit, "Maximum scaled velocity error", :maximum_scaled_velocity_error, velocity_error_limit),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id, label, metric_id, relation_less_than_or_equal; expected_value,
        ))
    end

    record_solver_statistics!(builder, solver_statistics)
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(
        terminated_at_close_approach ? actual_stopped : actual_completed;
        exit_code=terminated_at_close_approach ? 0 : 1,
        summary=terminated_at_close_approach ?
            "Integration stopped at the requested close-approach event." :
            "Integration completed without the required close-approach stop.",
    ))
    build_case_result(builder)
end

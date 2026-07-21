# Structured adapter for the unperturbed KS Kepler validation.

const KS_KEPLER_DEFINITION_VERSION = "1.0.0"

function ks_kepler_case_definition()
    ValidationCaseDefinition(
        :ks_kepler,
        "KS Kepler validation",
        "Numerical unperturbed Kustaanheimo-Stiefel propagation compared with the exact fictitious-time solution for a bound spatial Kepler orbit.",
        (:ks, :kepler, :analytic_reference, :regularization),
        (:ks_kepler, :ks_benchmark),
        "examples/validation/ks_kepler_validation.jl",
        (:standard,),
        expected_completed,
        true,
        KS_KEPLER_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_ks_kepler_case_result(
    maximum_u_error,
    maximum_w_error,
    maximum_time_error,
    maximum_constraint_residual,
    maximum_energy_residual,
    binding_energy_constant::Bool,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    gravitational_parameter,
    initial_position,
    initial_velocity,
    fictitious_time_interval,
    saved_state_count,
    position_error_limit,
    velocity_error_limit,
    time_error_limit,
    constraint_residual_limit,
    energy_residual_limit,
    algorithm,
    relative_tolerance,
    absolute_tolerance,
)
    builder = ValidationCaseResultBuilder(ks_kepler_case_definition(), environment)
    record_configuration!(builder, ValidationConfiguration(
        solver=algorithm,
        absolute_tolerance=absolute_tolerance,
        relative_tolerance=relative_tolerance,
        time_interval=fictitious_time_interval,
        sampling="$(saved_state_count) equally spaced fictitious-time samples",
        thresholds=(
            ValidationParameter(:position_error_limit, position_error_limit),
            ValidationParameter(:velocity_error_limit, velocity_error_limit),
            ValidationParameter(:physical_time_error_limit, time_error_limit),
            ValidationParameter(:gauge_constraint_residual_limit, constraint_residual_limit),
            ValidationParameter(:energy_consistency_residual_limit, energy_residual_limit),
        ),
        parameters=(
            ValidationParameter(:gravitational_parameter, gravitational_parameter),
            ValidationParameter(:initial_position, initial_position),
            ValidationParameter(:initial_velocity, initial_velocity),
        ),
    ))

    metrics = (
        ValidationMetric(:maximum_u_error, "Maximum KS position-coordinate error", maximum_u_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_w_error, "Maximum KS velocity-coordinate error", maximum_w_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_physical_time_error, "Maximum physical-time error", maximum_time_error;
            scale=scale_duration, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_gauge_constraint_residual, "Maximum gauge-constraint residual", maximum_constraint_residual;
            scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_energy_consistency_residual, "Maximum energy-consistency residual", maximum_energy_residual;
            scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:binding_energy_constant, "Unperturbed KS binding energy remained constant", binding_energy_constant;
            role=role_acceptance),
        ValidationMetric(:saved_states, "Saved states", saved_state_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    for (criterion_id, label, metric_id, limit) in (
        (:position_error_within_limit, "Maximum KS position-coordinate error", :maximum_u_error, position_error_limit),
        (:velocity_error_within_limit, "Maximum KS velocity-coordinate error", :maximum_w_error, velocity_error_limit),
        (:physical_time_error_within_limit, "Maximum physical-time error", :maximum_physical_time_error, time_error_limit),
        (:gauge_constraint_within_limit, "Maximum gauge-constraint residual", :maximum_gauge_constraint_residual, constraint_residual_limit),
        (:energy_consistency_within_limit, "Maximum energy-consistency residual", :maximum_energy_consistency_residual, energy_residual_limit),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id, label, metric_id, relation_less_than_or_equal; expected_value=limit,
        ))
    end
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :binding_energy_constant,
        "Unperturbed KS binding energy remained constant",
        :binding_energy_constant,
        relation_true,
    ))

    record_solver_statistics!(builder, solver_statistics)
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

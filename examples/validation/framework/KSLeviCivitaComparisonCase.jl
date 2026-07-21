# Structured adapter for the KS/Levi-Civita cross-validation benchmark.

const KS_LEVI_CIVITA_COMPARISON_DEFINITION_VERSION = "1.0.0"

function ks_levi_civita_comparison_case_definition()
    ValidationCaseDefinition(
        :ks_levi_civita_comparison,
        "KS/Levi-Civita comparison",
        "Independent planar Levi-Civita and spatial Kustaanheimo-Stiefel regularizations cross-validated in physical Cartesian variables across a radial collision.",
        (:ks, :levi_civita, :cross_validation, :collision, :regularization),
        (:ks_levi_civita_comparison, :ks_benchmark),
        "examples/validation/ks_levi_civita_comparison.jl",
        (:standard,),
        expected_completed,
        true,
        KS_LEVI_CIVITA_COMPARISON_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_ks_levi_civita_comparison_case_result(
    maximum_position_error,
    maximum_ordinary_velocity_error,
    maximum_near_collision_conditioning_ratio,
    maximum_time_error,
    maximum_energy_error,
    maximum_ks_energy_drift,
    maximum_levi_civita_energy_drift,
    final_transition_position_error,
    final_transition_velocity_error,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    gravitational_parameter,
    initial_position,
    initial_velocity,
    collision_time,
    sample_times,
    near_collision_radius,
    ordinary_sample_count,
    near_collision_sample_count,
    discrepancy_limit,
    conditioning_ratio_limit,
)
    builder = ValidationCaseResultBuilder(
        ks_levi_civita_comparison_case_definition(),
        environment,
    )
    record_configuration!(builder, ValidationConfiguration(
        time_interval=(first(sample_times), last(sample_times)),
        sampling="$(length(sample_times)) prescribed physical-time samples spanning the collision",
        thresholds=(
            ValidationParameter(:discrepancy_limit, discrepancy_limit),
            ValidationParameter(:conditioning_ratio_limit, conditioning_ratio_limit),
            ValidationParameter(:near_collision_radius, near_collision_radius),
        ),
        parameters=(
            ValidationParameter(:gravitational_parameter, gravitational_parameter),
            ValidationParameter(:initial_position, initial_position),
            ValidationParameter(:initial_velocity, initial_velocity),
            ValidationParameter(:collision_time, Float64(collision_time)),
            ValidationParameter(:sample_times, sample_times),
        ),
    ))

    metrics = (
        ValidationMetric(:maximum_position_error, "Maximum scaled position discrepancy", maximum_position_error;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_ordinary_velocity_error, "Maximum ordinary scaled velocity discrepancy", maximum_ordinary_velocity_error;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_near_collision_conditioning_ratio, "Maximum near-collision velocity-conditioning ratio", maximum_near_collision_conditioning_ratio;
            scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_physical_time_error, "Maximum scaled physical-time discrepancy", maximum_time_error;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_specific_energy_error, "Maximum scaled specific-energy discrepancy", maximum_energy_error;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_ks_energy_drift, "Maximum KS specific-energy drift", maximum_ks_energy_drift;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_levi_civita_energy_drift, "Maximum Levi-Civita specific-energy drift", maximum_levi_civita_energy_drift;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:final_transition_position_error, "Final transition position discrepancy", final_transition_position_error;
            scale=scale_relative, role=role_acceptance),
        ValidationMetric(:final_transition_velocity_error, "Final transition velocity discrepancy", final_transition_velocity_error;
            scale=scale_relative, role=role_acceptance),
        ValidationMetric(:ordinary_samples, "Ordinary velocity-comparison samples", ordinary_sample_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
        ValidationMetric(:near_collision_samples, "Near-collision conditioning samples", near_collision_sample_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    for (criterion_id, label, metric_id) in (
        (:position_discrepancy_within_limit, "Maximum scaled position discrepancy", :maximum_position_error),
        (:ordinary_velocity_discrepancy_within_limit, "Maximum ordinary scaled velocity discrepancy", :maximum_ordinary_velocity_error),
        (:physical_time_discrepancy_within_limit, "Maximum scaled physical-time discrepancy", :maximum_physical_time_error),
        (:energy_discrepancy_within_limit, "Maximum scaled specific-energy discrepancy", :maximum_specific_energy_error),
        (:ks_energy_drift_within_limit, "Maximum KS specific-energy drift", :maximum_ks_energy_drift),
        (:levi_civita_energy_drift_within_limit, "Maximum Levi-Civita specific-energy drift", :maximum_levi_civita_energy_drift),
        (:final_transition_position_within_limit, "Final transition position discrepancy", :final_transition_position_error),
        (:final_transition_velocity_within_limit, "Final transition velocity discrepancy", :final_transition_velocity_error),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id,
            label,
            metric_id,
            relation_less_than_or_equal;
            expected_value=discrepancy_limit,
        ))
    end
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :near_collision_conditioning_within_limit,
        "Maximum near-collision velocity-conditioning ratio",
        :maximum_near_collision_conditioning_ratio,
        relation_less_than_or_equal;
        expected_value=conditioning_ratio_limit,
    ))

    record_solver_statistics!(builder, solver_statistics)
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

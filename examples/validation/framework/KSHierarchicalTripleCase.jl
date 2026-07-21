# Structured adapter for the KS hierarchical-triple validation benchmark.

const KS_HIERARCHICAL_TRIPLE_DEFINITION_VERSION = "1.0.0"

function ks_hierarchical_triple_case_definition()
    ValidationCaseDefinition(
        :ks_hierarchical_triple,
        "KS hierarchical-triple validation",
        "Coupled pair-centred Kustaanheimo-Stiefel propagation in a hierarchical triple compared with an independent high-accuracy Cartesian integration.",
        (:ks, :hierarchical_triple, :cartesian_reference, :regularization),
        (:ks_hierarchical_triple, :ks_benchmark),
        "examples/validation/ks_hierarchical_triple.jl",
        (:standard,),
        expected_completed,
        true,
        KS_HIERARCHICAL_TRIPLE_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_ks_hierarchical_triple_case_result(
    maximum_state_error,
    maximum_energy_difference,
    maximum_ks_energy_drift,
    maximum_ks_gauge_residual,
    minimum_nonselected_separation,
    entry_transition_residual,
    exit_transition_residual,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    masses,
    gravitational_constant,
    initial_state,
    selected_pair,
    physical_time_interval,
    comparison_sample_count,
    algorithm,
    relative_tolerance,
    absolute_tolerance,
    state_error_limit,
    energy_difference_limit,
    ks_energy_drift_limit,
    gauge_residual_limit,
    minimum_separation_limit,
    transition_residual_limit,
)
    builder = ValidationCaseResultBuilder(
        ks_hierarchical_triple_case_definition(),
        environment,
    )
    record_configuration!(builder, ValidationConfiguration(
        solver=algorithm,
        absolute_tolerance=absolute_tolerance,
        relative_tolerance=relative_tolerance,
        time_interval=physical_time_interval,
        sampling="$(comparison_sample_count) equally spaced physical-time comparison samples",
        selected_pair=selected_pair,
        thresholds=(
            ValidationParameter(:state_error_limit, state_error_limit),
            ValidationParameter(:energy_difference_limit, energy_difference_limit),
            ValidationParameter(:ks_energy_drift_limit, ks_energy_drift_limit),
            ValidationParameter(:gauge_residual_limit, gauge_residual_limit),
            ValidationParameter(:minimum_nonselected_separation_limit, minimum_separation_limit),
            ValidationParameter(:transition_residual_limit, transition_residual_limit),
        ),
        parameters=(
            ValidationParameter(:masses, masses),
            ValidationParameter(:gravitational_constant, gravitational_constant),
            ValidationParameter(:initial_state, initial_state),
        ),
    ))

    metrics = (
        ValidationMetric(:maximum_scaled_cartesian_state_error, "Maximum scaled Cartesian-state discrepancy", maximum_state_error;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_relative_energy_difference, "Maximum relative energy discrepancy", maximum_energy_difference;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_ks_relative_energy_drift, "Maximum KS relative energy drift", maximum_ks_energy_drift;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_ks_gauge_constraint_residual, "Maximum KS gauge-constraint residual", maximum_ks_gauge_residual;
            scale=scale_dimensionless, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:minimum_nonselected_pair_separation, "Minimum nonselected-pair separation", minimum_nonselected_separation;
            scale=scale_dimensional, role=role_acceptance, aggregation=aggregation_minimum),
        ValidationMetric(:entry_transition_state_residual, "Entry transition state residual", entry_transition_residual;
            scale=scale_absolute, role=role_acceptance),
        ValidationMetric(:exit_transition_state_residual, "Exit transition state residual", exit_transition_residual;
            scale=scale_absolute, role=role_acceptance),
        ValidationMetric(:comparison_samples, "Physical-time comparison samples", comparison_sample_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    for (criterion_id, label, metric_id, limit) in (
        (:cartesian_state_discrepancy_within_limit, "Maximum scaled Cartesian-state discrepancy", :maximum_scaled_cartesian_state_error, state_error_limit),
        (:energy_discrepancy_within_limit, "Maximum relative energy discrepancy", :maximum_relative_energy_difference, energy_difference_limit),
        (:ks_energy_drift_within_limit, "Maximum KS relative energy drift", :maximum_ks_relative_energy_drift, ks_energy_drift_limit),
        (:ks_gauge_residual_within_limit, "Maximum KS gauge-constraint residual", :maximum_ks_gauge_constraint_residual, gauge_residual_limit),
        (:entry_transition_within_limit, "Entry transition state residual", :entry_transition_state_residual, transition_residual_limit),
        (:exit_transition_within_limit, "Exit transition state residual", :exit_transition_state_residual, transition_residual_limit),
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
        :nonselected_pair_separation_above_limit,
        "Minimum nonselected-pair separation",
        :minimum_nonselected_pair_separation,
        relation_greater_than_or_equal;
        expected_value=minimum_separation_limit,
    ))

    record_solver_statistics!(builder, solver_statistics)
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

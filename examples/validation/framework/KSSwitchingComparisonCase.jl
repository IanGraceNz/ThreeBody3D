# Structured adapter for the KS automatic-switching backend comparison.

const KS_SWITCHING_COMPARISON_DEFINITION_VERSION = "1.0.0"

function ks_switching_comparison_case_definition()
    ValidationCaseDefinition(
        :ks_switching_comparison,
        "KS switching comparison",
        "Automatic-switching comparison between Kustaanheimo-Stiefel and Levi-Civita regularization on the same controlled planar encounter.",
        (:ks, :levi_civita, :automatic_switching, :method_comparison),
        (:ks_switching_comparison, :ks_benchmark),
        "examples/validation/ks_switching_comparison.jl",
        (:standard,),
        expected_completed,
        true,
        KS_SWITCHING_COMPARISON_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_ks_switching_comparison_case_result(
    ks_status,
    levi_civita_status,
    ks_switch_count,
    levi_civita_switch_count,
    maximum_state_difference,
    entry_time_difference,
    exit_time_difference,
    ks_transition_residual,
    levi_civita_transition_residual,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    masses,
    gravitational_constant,
    initial_state,
    physical_time_interval,
    comparison_sample_count,
    enter_threshold,
    exit_threshold,
    ambiguity_threshold,
    minimum_separation_ratio,
    maximum_switches,
    minimum_time_progress,
    state_difference_limit,
    event_time_difference_limit,
    transition_residual_limit,
)
    builder = ValidationCaseResultBuilder(
        ks_switching_comparison_case_definition(),
        environment,
    )
    record_configuration!(builder, ValidationConfiguration(
        solver=:automatic_switching_comparison,
        time_interval=physical_time_interval,
        sampling="$(comparison_sample_count) equally spaced physical-time comparison samples",
        thresholds=(
            ValidationParameter(:enter_threshold, enter_threshold),
            ValidationParameter(:exit_threshold, exit_threshold),
            ValidationParameter(:ambiguity_threshold, ambiguity_threshold),
            ValidationParameter(:minimum_separation_ratio, minimum_separation_ratio),
            ValidationParameter(:maximum_switches, maximum_switches),
            ValidationParameter(:minimum_time_progress, minimum_time_progress),
            ValidationParameter(:state_difference_limit, state_difference_limit),
            ValidationParameter(:event_time_difference_limit, event_time_difference_limit),
            ValidationParameter(:transition_residual_limit, transition_residual_limit),
        ),
        parameters=(
            ValidationParameter(:masses, masses),
            ValidationParameter(:gravitational_constant, gravitational_constant),
            ValidationParameter(:initial_state, initial_state),
            ValidationParameter(:regularization_backends, (:ks, :levi_civita)),
        ),
    ))

    metrics = (
        ValidationMetric(:ks_status, "KS trajectory status", ks_status;
            role=role_acceptance),
        ValidationMetric(:levi_civita_status, "Levi-Civita trajectory status", levi_civita_status;
            role=role_acceptance),
        ValidationMetric(:ks_switch_count, "KS switch count", ks_switch_count;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:levi_civita_switch_count, "Levi-Civita switch count", levi_civita_switch_count;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:maximum_scaled_backend_state_discrepancy, "Maximum scaled backend state discrepancy", maximum_state_difference;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:entry_event_time_discrepancy, "Entry-event time discrepancy", entry_time_difference;
            scale=scale_duration, role=role_acceptance),
        ValidationMetric(:exit_event_time_discrepancy, "Exit-event time discrepancy", exit_time_difference;
            scale=scale_duration, role=role_acceptance),
        ValidationMetric(:maximum_ks_transition_residual, "Maximum KS transition residual", ks_transition_residual;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_levi_civita_transition_residual, "Maximum Levi-Civita transition residual", levi_civita_transition_residual;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:comparison_samples, "Physical-time comparison samples", comparison_sample_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :ks_trajectory_completed, "KS trajectory completed", :ks_status,
        relation_expected_status; expected_value=:completed,
    ))
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :levi_civita_trajectory_completed, "Levi-Civita trajectory completed", :levi_civita_status,
        relation_expected_status; expected_value=:completed,
    ))
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :ks_switch_count_correct, "KS switch count", :ks_switch_count,
        relation_equal; expected_value=2,
    ))
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :levi_civita_switch_count_correct, "Levi-Civita switch count", :levi_civita_switch_count,
        relation_equal; expected_value=2,
    ))
    for (criterion_id, label, metric_id, limit) in (
        (:backend_state_discrepancy_within_limit, "Maximum scaled backend state discrepancy", :maximum_scaled_backend_state_discrepancy, state_difference_limit),
        (:entry_event_time_discrepancy_within_limit, "Entry-event time discrepancy", :entry_event_time_discrepancy, event_time_difference_limit),
        (:exit_event_time_discrepancy_within_limit, "Exit-event time discrepancy", :exit_event_time_discrepancy, event_time_difference_limit),
        (:ks_transition_residual_within_limit, "Maximum KS transition residual", :maximum_ks_transition_residual, transition_residual_limit),
        (:levi_civita_transition_residual_within_limit, "Maximum Levi-Civita transition residual", :maximum_levi_civita_transition_residual, transition_residual_limit),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id, label, metric_id, relation_less_than_or_equal;
            expected_value=limit,
        ))
    end

    record_solver_statistics!(builder, solver_statistics)
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

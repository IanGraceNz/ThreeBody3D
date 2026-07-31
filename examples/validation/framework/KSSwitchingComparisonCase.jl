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

function _ks_switching_comparison_configuration(;
    masses,
    gravitational_constant,
    initial_state,
    selected_pair,
    physical_time_interval,
    comparison_sample_count,
    enter_threshold,
    exit_threshold,
    ambiguity_threshold,
    minimum_separation_ratio,
    maximum_switches,
    minimum_time_progress,
    minimum_separation_excursion,
    threshold_scale_kind,
    threshold_reference_scale,
    fixed_settings,
    state_difference_limit,
    event_time_difference_limit,
    transition_residual_limit,
)
    ValidationConfiguration(
        solver=:automatic_switching_comparison,
        time_interval=physical_time_interval,
        sampling="$(comparison_sample_count) equally spaced physical-time comparison samples",
        selected_pair=selected_pair,
        thresholds=(
            ValidationParameter(:enter_threshold, enter_threshold),
            ValidationParameter(:exit_threshold, exit_threshold),
            ValidationParameter(:ambiguity_threshold, ambiguity_threshold),
            ValidationParameter(:minimum_separation_ratio, minimum_separation_ratio),
            ValidationParameter(:maximum_switches, maximum_switches),
            ValidationParameter(:minimum_time_progress, minimum_time_progress),
            ValidationParameter(:minimum_separation_excursion, minimum_separation_excursion),
            ValidationParameter(:state_difference_limit, state_difference_limit),
            ValidationParameter(:event_time_difference_limit, event_time_difference_limit),
            ValidationParameter(:transition_residual_limit, transition_residual_limit),
        ),
        parameters=(
            ValidationParameter(:masses, masses),
            ValidationParameter(:gravitational_constant, gravitational_constant),
            ValidationParameter(:initial_state, initial_state),
            ValidationParameter(:regularization_backends, (:ks, :levi_civita)),
            ValidationParameter(:cartesian_solver_profile, fixed_settings.cartesian.solver),
            ValidationParameter(:cartesian_algorithm, fixed_settings.cartesian.algorithm),
            ValidationParameter(:cartesian_relative_tolerance, fixed_settings.cartesian.reltol),
            ValidationParameter(:cartesian_absolute_tolerance, fixed_settings.cartesian.abstol),
            ValidationParameter(:cartesian_maximum_iterations, fixed_settings.cartesian.maxiters),
            ValidationParameter(:cartesian_precision_bits, fixed_settings.cartesian.precision),
            ValidationParameter(:cartesian_sampling, fixed_settings.cartesian.sampling),
            ValidationParameter(:levi_civita_algorithm, fixed_settings.levi_civita.algorithm),
            ValidationParameter(:levi_civita_relative_tolerance, fixed_settings.levi_civita.reltol),
            ValidationParameter(:levi_civita_absolute_tolerance, fixed_settings.levi_civita.abstol),
            ValidationParameter(:levi_civita_targeting_initial_step, fixed_settings.levi_civita.initial_step),
            ValidationParameter(:levi_civita_targeting_tolerance, fixed_settings.levi_civita.targeting_tolerance),
            ValidationParameter(:levi_civita_targeting_maximum_iterations, fixed_settings.levi_civita.targeting_max_iterations),
            ValidationParameter(:levi_civita_sampling, fixed_settings.levi_civita.sampling),
            ValidationParameter(:ks_algorithm, fixed_settings.ks.algorithm),
            ValidationParameter(:ks_relative_tolerance, fixed_settings.ks.reltol),
            ValidationParameter(:ks_absolute_tolerance, fixed_settings.ks.abstol),
            ValidationParameter(:ks_maximum_fictitious_span_expansions, fixed_settings.ks.max_fictitious_span_expansions),
            ValidationParameter(:ks_initial_fictitious_span_rule, fixed_settings.ks.initial_fictitious_span_rule),
            ValidationParameter(:ks_initial_fictitious_span_inputs, fixed_settings.ks.initial_fictitious_span_inputs),
            ValidationParameter(:ks_nonselected_pair_threshold_rule, fixed_settings.ks.nonselected_pair_threshold_rule),
            ValidationParameter(:ks_nonselected_pair_threshold, fixed_settings.ks.nonselected_pair_threshold),
            ValidationParameter(:ks_sampling, fixed_settings.ks.sampling),
            ValidationParameter(:regularized_evaluation_tolerance, fixed_settings.evaluation.tolerance),
            ValidationParameter(:regularized_evaluation_maximum_iterations, fixed_settings.evaluation.max_iterations),
            ValidationParameter(:threshold_scale_kind, threshold_scale_kind),
            ValidationParameter(:threshold_reference_scale, threshold_reference_scale),
        ),
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
    comparison_sample_count,
    solver_statistics::SolverStatistics,
    environment::ValidationEnvironment;
    configuration::ValidationConfiguration,
    state_difference_limit,
    event_time_difference_limit,
    transition_residual_limit,
)
    builder = ValidationCaseResultBuilder(
        ks_switching_comparison_case_definition(),
        environment,
    )
    record_configuration!(builder, configuration)

    metrics = AbstractValidationMetric[
        ValidationMetric(:ks_status, "KS trajectory status", ks_status;
            role=role_acceptance),
        ValidationMetric(:levi_civita_status, "Levi-Civita trajectory status", levi_civita_status;
            role=role_acceptance),
        ValidationMetric(:ks_switch_count, "KS switch count", ks_switch_count;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:levi_civita_switch_count, "Levi-Civita switch count", levi_civita_switch_count;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:comparison_samples, "Physical-time comparison samples", comparison_sample_count;
            scale=scale_count, role=role_descriptive, aggregation=aggregation_count),
    ]
    for (value, metric_id, label, scale, aggregation) in (
        (maximum_state_difference, :maximum_scaled_backend_state_discrepancy, "Maximum scaled backend state discrepancy", scale_relative, aggregation_maximum),
        (entry_time_difference, :entry_event_time_discrepancy, "Entry-event time discrepancy", scale_duration, aggregation_none),
        (exit_time_difference, :exit_event_time_discrepancy, "Exit-event time discrepancy", scale_duration, aggregation_none),
        (ks_transition_residual, :maximum_ks_transition_residual, "Maximum KS transition residual", scale_absolute, aggregation_maximum),
        (levi_civita_transition_residual, :maximum_levi_civita_transition_residual, "Maximum Levi-Civita transition residual", scale_absolute, aggregation_maximum),
    )
        isnothing(value) && continue
        push!(metrics, ValidationMetric(metric_id, label, value;
            scale, role=role_acceptance, aggregation))
    end
    foreach(metric -> record_metric!(builder, metric), metrics)

    record_solver_statistics!(builder, solver_statistics)
    successful_comparison = ks_status == :completed && levi_civita_status == :completed &&
        all(!isnothing, (
            maximum_state_difference, entry_time_difference, exit_time_difference,
            ks_transition_residual, levi_civita_transition_residual,
        ))
    if successful_comparison
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
    end
    evaluate_criteria!(builder)

    execution = successful_comparison ? ExecutionOutcome(actual_completed; exit_code=0) :
        ExecutionOutcome(actual_terminated; exit_code=1,
            summary="KS switching comparison did not produce all required observations.")
    finish_execution!(builder, execution)
    build_case_result(builder)
end

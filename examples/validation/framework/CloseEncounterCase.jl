# Structured adapter for the close-encounter comparison validation.

const CLOSE_ENCOUNTER_DEFINITION_VERSION = "1.0.0"

function close_encounter_case_definition()
    ValidationCaseDefinition(
        :close_encounter_comparison,
        "Close-encounter comparison",
        "Controlled close encounter comparing Cartesian, automatic-switching, and explicit regularized propagation against an independent BigFloat reference.",
        (:close_encounter, :regularization, :reference_solution, :method_comparison),
        (:close_encounter, :core_benchmark),
        "examples/validation/close_encounter_comparison.jl",
        (:standard,),
        expected_completed,
        true,
        CLOSE_ENCOUNTER_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function _periapsis_by_name(periapses)
    Dict(item.name => item.result for item in periapses)
end

function _close_encounter_configuration(;
    initial_state,
    masses,
    gravitational_constant,
    apoapsis,
    nominal_periapsis,
    third_body_offset,
    reference_precision=256,
    sample_step=0.002,
    selected_pair=(1, 2),
    entry_threshold=0.10,
    exit_threshold=0.25,
    cartesian_tolerance=1e-13,
    regularized_tolerance=1e-12,
    evaluation_tolerance=1e-14,
    time_interval=(0.0, 1.6),
    automatic_ambiguity_threshold=0.25,
    automatic_minimum_separation_ratio=10.0,
    automatic_maximum_switches=10,
    regularized_initial_step=0.1,
    regularized_max_iterations=256,
    evaluation_max_iterations=256,
    reference_tolerance="1e-30",
    automatic_maximum_state_error_limit=1.0e-9,
    explicit_maximum_state_error_limit=1.0e-9,
    exit_state_agreement_limit=1.0e-10,
    explicit_exit_time_residual_limit=5.0e-12,
    automatic_periapsis_separation_error_limit=1.0e-10,
    explicit_periapsis_separation_error_limit=1.0e-10,
    cartesian_under_resolution_minimum=1.0e-3,
    automatic_improvement_ratio_limit=0.5,
)
    ValidationConfiguration(
        solver=:method_comparison,
        absolute_tolerance=cartesian_tolerance,
        relative_tolerance=cartesian_tolerance,
        precision_bits=reference_precision,
        time_interval=time_interval,
        sampling="step=$(sample_step)",
        selected_pair=selected_pair,
        thresholds=(
            ValidationParameter(:entry_threshold, entry_threshold),
            ValidationParameter(:exit_threshold, exit_threshold),
            ValidationParameter(:cartesian_tolerance, cartesian_tolerance),
            ValidationParameter(:regularized_tolerance, regularized_tolerance),
            ValidationParameter(:evaluation_tolerance, evaluation_tolerance),
            ValidationParameter(:automatic_maximum_state_error_limit, automatic_maximum_state_error_limit),
            ValidationParameter(:explicit_maximum_state_error_limit, explicit_maximum_state_error_limit),
            ValidationParameter(:exit_state_agreement_limit, exit_state_agreement_limit),
            ValidationParameter(:explicit_exit_time_residual_limit, explicit_exit_time_residual_limit),
            ValidationParameter(:automatic_periapsis_separation_error_limit, automatic_periapsis_separation_error_limit),
            ValidationParameter(:explicit_periapsis_separation_error_limit, explicit_periapsis_separation_error_limit),
            ValidationParameter(:cartesian_under_resolution_minimum, cartesian_under_resolution_minimum),
            ValidationParameter(:automatic_improvement_ratio_limit, automatic_improvement_ratio_limit),
        ),
        parameters=(
            ValidationParameter(:initial_state, initial_state),
            ValidationParameter(:masses, masses),
            ValidationParameter(:gravitational_constant, gravitational_constant),
            ValidationParameter(:apoapsis, apoapsis),
            ValidationParameter(:nominal_periapsis, nominal_periapsis),
            ValidationParameter(:third_body_offset, third_body_offset),
            ValidationParameter(:automatic_ambiguity_threshold, automatic_ambiguity_threshold),
            ValidationParameter(:automatic_minimum_separation_ratio, automatic_minimum_separation_ratio),
            ValidationParameter(:automatic_maximum_switches, automatic_maximum_switches),
            ValidationParameter(:regularized_initial_step, regularized_initial_step),
            ValidationParameter(:regularized_max_iterations, regularized_max_iterations),
            ValidationParameter(:evaluation_max_iterations, evaluation_max_iterations),
            ValidationParameter(:reference_tolerance, reference_tolerance),
            ValidationParameter(:reference_solver, :extreme),
            ValidationParameter(:reference_dense_output, true),
            ValidationParameter(:reference_save_everystep, true),
            ValidationParameter(:explicit_targeting_tolerance, :derived),
        ),
    )
end

function build_close_encounter_case_result(
    cartesian,
    automatic,
    explicit,
    exit_difference,
    reference_periapsis,
    periapses,
    endpoint_times,
    environment::ValidationEnvironment;
    automatic_maximum_state_error_limit,
    explicit_maximum_state_error_limit,
    exit_state_agreement_limit,
    explicit_exit_time_residual_limit,
    automatic_periapsis_separation_error_limit,
    explicit_periapsis_separation_error_limit,
    cartesian_under_resolution_minimum,
    automatic_improvement_ratio_limit,
    configuration::ValidationConfiguration,
)
    periapsis = _periapsis_by_name(periapses)
    automatic_periapsis = periapsis["Automatic switching"]
    explicit_periapsis = periapsis["Explicit regularized"]
    cartesian_periapsis = periapsis["Cartesian"]

    automatic_periapsis_error = abs(Float64(
        automatic_periapsis.separation - reference_periapsis.separation,
    ))
    explicit_periapsis_error = abs(Float64(
        explicit_periapsis.separation - reference_periapsis.separation,
    ))
    cartesian_periapsis_error = abs(Float64(
        cartesian_periapsis.separation - reference_periapsis.separation,
    ))
    automatic_periapsis_time_error = abs(Float64(
        automatic_periapsis.time - reference_periapsis.time,
    ))
    explicit_periapsis_time_error = abs(Float64(
        explicit_periapsis.time - reference_periapsis.time,
    ))
    cartesian_periapsis_time_error = abs(Float64(
        cartesian_periapsis.time - reference_periapsis.time,
    ))
    automatic_improvement_ratio =
        automatic.errors.maximum_combined / cartesian.errors.maximum_combined

    builder = ValidationCaseResultBuilder(close_encounter_case_definition(), environment)
    record_configuration!(builder, configuration)

    metrics = (
        ValidationMetric(:automatic_maximum_state_error, "Automatic maximum state error", automatic.errors.maximum_combined;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:explicit_maximum_state_error, "Explicit maximum state error", explicit.errors.maximum_combined;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_maximum),
        ValidationMetric(:automatic_explicit_exit_state_difference, "Automatic-explicit exit-state difference", exit_difference.state;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_final),
        ValidationMetric(:explicit_sundman_exit_time_residual, "Explicit Sundman exit-time residual", abs(endpoint_times.explicit_time_residual);
            scale=scale_duration, role=role_acceptance, aggregation=aggregation_final),
        ValidationMetric(:automatic_periapsis_separation_error, "Automatic periapsis separation error", automatic_periapsis_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_final),
        ValidationMetric(:explicit_periapsis_separation_error, "Explicit periapsis separation error", explicit_periapsis_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_final),
        ValidationMetric(:cartesian_periapsis_separation_error, "Cartesian periapsis separation error", cartesian_periapsis_error;
            scale=scale_absolute, role=role_acceptance, aggregation=aggregation_final),
        ValidationMetric(:automatic_periapsis_time_error, "Automatic periapsis time error", automatic_periapsis_time_error;
            scale=scale_duration, role=role_descriptive, aggregation=aggregation_final),
        ValidationMetric(:explicit_periapsis_time_error, "Explicit periapsis time error", explicit_periapsis_time_error;
            scale=scale_duration, role=role_descriptive, aggregation=aggregation_final),
        ValidationMetric(:cartesian_periapsis_time_error, "Cartesian periapsis time error", cartesian_periapsis_time_error;
            scale=scale_duration, role=role_descriptive, aggregation=aggregation_final),
        ValidationMetric(:automatic_to_cartesian_maximum_state_error_ratio, "Automatic-to-Cartesian maximum state-error ratio", automatic_improvement_ratio;
            scale=scale_relative, role=role_acceptance, aggregation=aggregation_none),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    criteria = (
        (:automatic_maximum_state_error_within_limit, "Automatic maximum state error", :automatic_maximum_state_error, relation_less_than_or_equal, automatic_maximum_state_error_limit),
        (:explicit_maximum_state_error_within_limit, "Explicit maximum state error", :explicit_maximum_state_error, relation_less_than_or_equal, explicit_maximum_state_error_limit),
        (:exit_state_agreement_within_limit, "Automatic-explicit exit-state agreement", :automatic_explicit_exit_state_difference, relation_less_than_or_equal, exit_state_agreement_limit),
        (:explicit_exit_time_residual_within_limit, "Explicit Sundman exit-time residual", :explicit_sundman_exit_time_residual, relation_less_than_or_equal, explicit_exit_time_residual_limit),
        (:automatic_periapsis_error_within_limit, "Automatic periapsis separation error", :automatic_periapsis_separation_error, relation_less_than_or_equal, automatic_periapsis_separation_error_limit),
        (:explicit_periapsis_error_within_limit, "Explicit periapsis separation error", :explicit_periapsis_separation_error, relation_less_than_or_equal, explicit_periapsis_separation_error_limit),
        (:cartesian_under_resolution_exposed, "Cartesian under-resolution is exposed", :cartesian_periapsis_separation_error, relation_greater_than_or_equal, cartesian_under_resolution_minimum),
        (:automatic_regularization_improves_error, "Automatic regularization improves maximum state error", :automatic_to_cartesian_maximum_state_error_ratio, relation_less_than_or_equal, automatic_improvement_ratio_limit),
    )
    for (criterion_id, label, metric_id, relation, expected_value) in criteria
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id, label, metric_id, relation; expected_value,
        ))
    end

    record_solver_statistics!(builder, SolverStatistics(
        accepted_steps=cartesian.work.accepted_steps + automatic.work.accepted_steps + explicit.work.accepted_steps,
        rejected_steps=cartesian.work.rejected_steps + automatic.work.rejected_steps + explicit.work.rejected_steps,
        rhs_evaluations=cartesian.work.rhs_evaluations + automatic.work.rhs_evaluations + explicit.work.rhs_evaluations,
        saved_states=cartesian.work.saved_states + automatic.work.saved_states + explicit.work.saved_states,
        elapsed_seconds=cartesian.elapsed + automatic.elapsed + explicit.elapsed,
        segment_count=cartesian.segments + automatic.segments + explicit.segments,
        switch_count=cartesian.switches + automatic.switches + explicit.switches,
    ))
    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

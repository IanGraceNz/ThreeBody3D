# Structured adapter for the deterministic randomized-regression validation.

const RANDOMIZED_REGRESSION_DEFINITION_VERSION = "1.0.0"

function randomized_regression_case_definition()
    ValidationCaseDefinition(
        :randomized_regression,
        "Randomized regression validation",
        "Deterministic ensemble of bound three-body initial conditions checked for completion, finite trajectories, and conservation limits.",
        (:randomized_regression, :ensemble, :conservation),
        (:randomized_regression, :core_benchmark),
        "examples/validation/randomized_regression_validation.jl",
        (:standard,),
        expected_completed,
        true,
        RANDOMIZED_REGRESSION_DEFINITION_VERSION,
        "V0_5_VALIDATION_ARCHITECTURE_DESIGN.md",
    )
end

function build_randomized_regression_case_result(
    validation,
    environment::ValidationEnvironment;
    duration,
    saveat,
    minimum_initial_separation,
    energy_drift_limit,
    momentum_drift_limit,
    angular_momentum_drift_limit,
    center_of_mass_limit,
    solver,
)
    results = validation.results
    trial_ids = Tuple(result.trial for result in results)
    completion_flags = Tuple(result.completed for result in results)
    finite_flags = Tuple(result.finite for result in results)
    energy_drifts = Tuple(result.maximum_relative_energy_drift for result in results)
    momentum_drifts = Tuple(result.maximum_momentum_drift for result in results)
    angular_momentum_drifts = Tuple(result.maximum_angular_momentum_drift for result in results)
    center_of_mass_residuals = Tuple(result.maximum_com_residual for result in results)
    minimum_separations = Tuple(result.minimum_separation for result in results)
    trial_within_limits(result) =
        result.completed &&
        result.finite &&
        result.maximum_relative_energy_drift <= energy_drift_limit &&
        result.maximum_momentum_drift <= momentum_drift_limit &&
        result.maximum_angular_momentum_drift <= angular_momentum_drift_limit &&
        result.maximum_com_residual <= center_of_mass_limit
    failing_trial_ids = Tuple(result.trial for result in results if !trial_within_limits(result))
    failure_messages = Tuple(result.message for result in results if !isempty(result.message))

    builder = ValidationCaseResultBuilder(randomized_regression_case_definition(), environment)
    record_configuration!(builder, ValidationConfiguration(
        solver=solver,
        time_interval=(0.0, duration),
        sampling="saveat=$(saveat)",
        thresholds=(
            ValidationParameter(:minimum_initial_separation, minimum_initial_separation),
            ValidationParameter(:energy_drift_limit, energy_drift_limit),
            ValidationParameter(:momentum_drift_limit, momentum_drift_limit),
            ValidationParameter(:angular_momentum_drift_limit, angular_momentum_drift_limit),
            ValidationParameter(:center_of_mass_residual_limit, center_of_mass_limit),
        ),
        parameters=(
            ValidationParameter(:deterministic_seed, validation.seed),
            ValidationParameter(:trial_count, validation.trials),
        ),
    ))

    metrics = (
        ValidationMetric(:completed_integrations, "Completed integrations", validation.completed;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:finite_trajectories, "Finite trajectories", validation.finite;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:trials_within_limits, "Trials within validation limits", validation.passing;
            scale=scale_count, role=role_acceptance, aggregation=aggregation_count),
        ValidationMetric(:trial_ids, "Trial identifiers", trial_ids;
            scale=scale_count, role=role_descriptive),
        ValidationMetric(:completion_flags, "Per-trial completion flags", completion_flags;
            role=role_diagnostic),
        ValidationMetric(:finite_flags, "Per-trial finite-trajectory flags", finite_flags;
            role=role_diagnostic),
        ValidationMetric(:energy_drifts, "Per-trial maximum relative energy drifts", energy_drifts;
            scale=scale_relative, role=role_diagnostic, aggregation=aggregation_maximum),
        ValidationMetric(:momentum_drifts, "Per-trial maximum momentum drifts", momentum_drifts;
            scale=scale_absolute, role=role_diagnostic, aggregation=aggregation_maximum),
        ValidationMetric(:angular_momentum_drifts, "Per-trial maximum angular-momentum drifts", angular_momentum_drifts;
            scale=scale_absolute, role=role_diagnostic, aggregation=aggregation_maximum),
        ValidationMetric(:center_of_mass_residuals, "Per-trial maximum centre-of-mass residuals", center_of_mass_residuals;
            scale=scale_absolute, role=role_diagnostic, aggregation=aggregation_maximum),
        ValidationMetric(:minimum_separations, "Per-trial minimum separations", minimum_separations;
            scale=scale_dimensional, role=role_diagnostic, aggregation=aggregation_minimum),
        ValidationMetric(:failing_trial_ids, "Trials outside validation limits", failing_trial_ids;
            scale=scale_count, role=role_diagnostic),
        ValidationMetric(:failure_messages, "Trial execution errors", failure_messages;
            role=role_diagnostic),
    )
    foreach(metric -> record_metric!(builder, metric), metrics)

    for (criterion_id, label, metric_id) in (
        (:all_integrations_completed, "All integrations completed", :completed_integrations),
        (:all_trajectories_finite, "All trajectories finite", :finite_trajectories),
        (:all_trials_within_limits, "All trials within validation limits", :trials_within_limits),
    )
        declare_criterion!(builder, AcceptanceCriterionSpecification(
            criterion_id,
            label,
            metric_id,
            relation_equal;
            expected_value=validation.trials,
        ))
    end

    evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0))
    build_case_result(builder)
end

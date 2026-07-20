module ValidationFramework

"""
Internal structured-result framework for the repository scientific validations.

Design principles:

1. Scientific results are immutable once measured.
2. Evaluation is deterministic and side-effect free.
3. Presentation never influences scientific evaluation.

This module belongs to repository validation infrastructure. It is deliberately
not included in, or exported from, the public `ThreeBody3D` package API.
"""

include("Types.jl")
include("Criteria.jl")
include("CaseResults.jl")
include("Serialization.jl")

export AbstractValidationMetric,
       actual_completed,
       actual_errored,
       actual_malformed_report,
       actual_missing_report,
       actual_stopped,
       actual_terminated,
       aggregation_count,
       aggregation_final,
       aggregation_initial,
       aggregation_maximum,
       aggregation_mean,
       aggregation_minimum,
       aggregation_none,
       aggregation_rms,
       AcceptanceCriterion,
       AcceptanceCriterionSpecification,
       ActualExecutionOutcome,
       AggregationKind,
       CriterionRelation,
       CriterionSeverity,
       CriterionStatus,
       criterion_error,
       criterion_fail,
       criterion_pass,
       build_case_result,
       CaseBuilderState,
       declare_criterion!,
       evaluate_criteria!,
       finish_execution!,
       evaluate_criteria,
       evaluate_criterion,
       ExecutionOutcome,
       ExpectedExecutionOutcome,
       expected_completed,
       expected_error,
       expected_stop,
       MetricKind,
       metric_boolean,
       metric_integer,
       metric_numeric,
       metric_sequence,
       metric_status,
       metric_text,
       MetricRole,
       role_acceptance,
       role_descriptive,
       role_diagnostic,
       role_performance,
       MetricScale,
       scale_absolute,
       scale_count,
       scale_dimensionless,
       scale_dimensional,
       scale_duration,
       scale_relative,
       SolverStatistics,
       ValidationCaseDefinition,
       ValidationCaseResult,
       ValidationCaseResultBuilder,
       ValidationCaseStatus,
       case_error,
       case_fail,
       case_pass,
       ValidationConfiguration,
       ValidationEnvironment,
       ValidationMetric,
       ValidationParameter,
       ValidationSuiteResult,
       ValidationSuiteStatus,
       suite_error,
       suite_fail,
       suite_pass,
       relation_approximately_equal,
       relation_equal,
       relation_expected_status,
       relation_finite,
       relation_greater_than,
       relation_greater_than_or_equal,
       relation_less_than,
       relation_less_than_or_equal,
       relation_true,
       record_configuration!,
       record_metric!,
       record_solver_statistics!,
       severity_advisory,
       severity_required,
       VALIDATION_SCHEMA_IDENTITY,
       case_report_text,
       read_case_report,
       read_suite_report,
       suite_report_text,
       write_case_report,
       write_report_atomic,
       write_suite_report,
       stable_string

end

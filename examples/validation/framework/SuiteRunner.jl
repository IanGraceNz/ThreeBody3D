# Isolated-process orchestration for the complete structured validation suite.

"""One registered validation script executed by the suite runner."""
struct ValidationSuiteEntry
    case_id::Symbol
    description::String
    path::String
    structured::Bool

    function ValidationSuiteEntry(case_id, description, path; structured::Bool=true)
        new(
            _validated_identifier(case_id, "case_id"),
            _nonempty_string(description, "description"),
            abspath(_nonempty_string(path, "path")),
            structured,
        )
    end
end

"""Wall-clock process information retained only for console presentation."""
struct ValidationProcessRecord
    entry::ValidationSuiteEntry
    elapsed_seconds::Float64
    message::String
end

function _suite_case_environment(
    result::ValidationCaseResult,
    environment::ValidationEnvironment,
)
    ValidationCaseResult(
        result.definition,
        environment,
        result.configuration,
        result.metrics,
        result.criteria,
        result.solver_statistics,
        result.execution,
    )
end

function _process_case_definition(entry::ValidationSuiteEntry, project_root::AbstractString)
    source_path = replace(relpath(entry.path, project_root), '\\' => '/')
    ValidationCaseDefinition(
        entry.case_id,
        string(entry.case_id),
        entry.description,
        (:process_execution,),
        (:validation_suite, :legacy_process),
        source_path,
        (:standard,),
        expected_completed,
        true,
        "1.0.0",
        "Temporary process-level compatibility result for a validation script without the structured case protocol.",
    )
end

function _process_case_result(
    entry::ValidationSuiteEntry,
    environment::ValidationEnvironment,
    project_root::AbstractString;
    completed::Bool,
    elapsed_seconds::Real,
    message::AbstractString="",
)
    definition = _process_case_definition(entry, project_root)
    metric = ValidationMetric(
        :process_completed,
        "Validation process completed successfully",
        completed;
        kind=metric_boolean,
        scale=scale_dimensionless,
        role=role_acceptance,
        aggregation=aggregation_final,
    )
    specification = AcceptanceCriterionSpecification(
        :process_completed,
        "Validation process completed successfully",
        metric.metric_id,
        relation_true,
    )
    criterion = AcceptanceCriterion(
        specification,
        completed ? criterion_pass : criterion_fail;
        message=completed ? nothing : _nonempty_string(message, "message"),
    )
    execution = ExecutionOutcome(
        completed ? actual_completed : actual_errored;
        exit_code=completed ? 0 : 1,
        elapsed_seconds=Float64(elapsed_seconds),
        summary=isempty(message) ? nothing : String(message),
    )
    ValidationCaseResult(
        definition,
        environment,
        ValidationConfiguration(),
        (metric,),
        (criterion,),
        nothing,
        execution,
    )
end

function _structured_error_result(
    entry::ValidationSuiteEntry,
    environment::ValidationEnvironment,
    project_root::AbstractString,
    elapsed_seconds::Real,
    message::AbstractString,
)
    definition = ValidationCaseDefinition(
        entry.case_id,
        string(entry.case_id),
        entry.description,
        (:reporting_error,),
        (:validation_suite, :structured_report),
        replace(relpath(entry.path, project_root), '\\' => '/'),
        (:standard,),
        expected_completed,
        true,
        "1.0.0",
        "Suite-runner error result created because no valid structured case report was available.",
    )
    execution = ExecutionOutcome(
        actual_malformed_report;
        exit_code=1,
        elapsed_seconds=Float64(elapsed_seconds),
        summary=_nonempty_string(message, "message"),
    )
    ValidationCaseResult(
        definition,
        environment,
        ValidationConfiguration(),
        (),
        (),
        nothing,
        execution,
    )
end

function build_validation_suite_result(
    cases,
    environment::ValidationEnvironment;
    suite_id::Symbol=:scientific_validation,
    title::AbstractString="ThreeBody3D scientific validation suite",
)
    builder = ValidationSuiteResultBuilder(
        suite_id,
        title,
        environment.schema_version,
        environment,
    )
    for result in cases
        record_case_result!(builder, _suite_case_environment(result, environment))
    end
    build_suite_result(builder)
end

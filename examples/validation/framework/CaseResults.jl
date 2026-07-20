# Mutable construction helper for immutable schema-1 case results.

@enum CaseBuilderState begin
    builder_collecting
    builder_evaluated
    builder_finished
    builder_built
end

"""
    ValidationCaseResultBuilder(definition, environment)

Create a mutable, single-use builder for one validation case. The builder owns
only construction state; completed scientific records remain immutable.
"""
mutable struct ValidationCaseResultBuilder
    definition::ValidationCaseDefinition
    environment::ValidationEnvironment
    configuration::Union{Nothing,ValidationConfiguration}
    metrics::Vector{AbstractValidationMetric}
    specifications::Vector{AcceptanceCriterionSpecification}
    criteria::Union{Nothing,Tuple{Vararg{AcceptanceCriterion}}}
    solver_statistics::Union{Nothing,SolverStatistics}
    execution::Union{Nothing,ExecutionOutcome}
    state::CaseBuilderState

    function ValidationCaseResultBuilder(
        definition::ValidationCaseDefinition,
        environment::ValidationEnvironment,
    )
        new(
            definition,
            environment,
            nothing,
            AbstractValidationMetric[],
            AcceptanceCriterionSpecification[],
            nothing,
            nothing,
            nothing,
            builder_collecting,
        )
    end
end

function _require_builder_state(builder::ValidationCaseResultBuilder, allowed, operation)
    builder.state in allowed || throw(
        ArgumentError("Cannot $(operation) while builder state is $(builder.state)."),
    )
    nothing
end

"""Record the complete numerical configuration exactly once."""
function record_configuration!(
    builder::ValidationCaseResultBuilder,
    configuration::ValidationConfiguration,
)
    _require_builder_state(builder, (builder_collecting,), "record configuration")
    isnothing(builder.configuration) || throw(ArgumentError("Configuration has already been recorded."))
    builder.configuration = configuration
    builder
end

"""Append one retained metric, rejecting duplicate metric identifiers."""
function record_metric!(builder::ValidationCaseResultBuilder, metric::ValidationMetric)
    _require_builder_state(builder, (builder_collecting,), "record a metric")
    any(existing -> existing.metric_id == metric.metric_id, builder.metrics) && throw(
        ArgumentError("Metric $(metric.metric_id) has already been recorded."),
    )
    push!(builder.metrics, metric)
    builder
end

"""Append one criterion specification, rejecting duplicate criterion identifiers."""
function declare_criterion!(
    builder::ValidationCaseResultBuilder,
    specification::AcceptanceCriterionSpecification,
)
    _require_builder_state(builder, (builder_collecting,), "declare a criterion")
    any(
        existing -> existing.criterion_id == specification.criterion_id,
        builder.specifications,
    ) && throw(ArgumentError("Criterion $(specification.criterion_id) has already been declared."))
    push!(builder.specifications, specification)
    builder
end

"""Record optional solver statistics exactly once."""
function record_solver_statistics!(
    builder::ValidationCaseResultBuilder,
    statistics::SolverStatistics,
)
    _require_builder_state(builder, (builder_collecting,), "record solver statistics")
    isnothing(builder.solver_statistics) || throw(
        ArgumentError("Solver statistics have already been recorded."),
    )
    builder.solver_statistics = statistics
    builder
end

"""
    evaluate_criteria!(builder)

Evaluate all declared criteria against the retained metric set in declaration
order. The evaluated records are retained and cannot be replaced.
"""
function evaluate_criteria!(builder::ValidationCaseResultBuilder)
    _require_builder_state(builder, (builder_collecting,), "evaluate criteria")
    isnothing(builder.configuration) && throw(
        ArgumentError("Configuration must be recorded before criterion evaluation."),
    )
    builder.criteria = evaluate_criteria(builder.specifications, builder.metrics)
    builder.state = builder_evaluated
    builder.criteria
end

"""Record the actual execution outcome after criteria have been evaluated."""
function finish_execution!(
    builder::ValidationCaseResultBuilder,
    execution::ExecutionOutcome,
)
    _require_builder_state(builder, (builder_evaluated,), "finish execution")
    builder.execution = execution
    builder.state = builder_finished
    builder
end

"""
    build_case_result(builder)

Construct the immutable `ValidationCaseResult`. A builder is single-use: after
successful construction it cannot be modified or built again.
"""
function build_case_result(builder::ValidationCaseResultBuilder)
    _require_builder_state(builder, (builder_finished,), "build a case result")
    configuration = something(builder.configuration)
    criteria = something(builder.criteria)
    execution = something(builder.execution)
    result = ValidationCaseResult(
        builder.definition,
        builder.environment,
        configuration,
        Tuple(builder.metrics),
        criteria,
        builder.solver_statistics,
        execution,
    )
    builder.state = builder_built
    result
end

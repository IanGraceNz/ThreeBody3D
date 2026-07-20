# Mutable construction helper for immutable schema-1 suite results.

@enum SuiteBuilderState begin
    suite_builder_collecting
    suite_builder_built
end

"""
    ValidationSuiteResultBuilder(suite_id, title, schema_version, environment)

Create a mutable, single-use builder for one validation suite. Cases are retained
in insertion order, which must match deterministic registry order.
"""
mutable struct ValidationSuiteResultBuilder
    suite_id::Symbol
    title::String
    schema_version::String
    environment::ValidationEnvironment
    cases::Vector{ValidationCaseResult}
    state::SuiteBuilderState

    function ValidationSuiteResultBuilder(
        suite_id,
        title,
        schema_version,
        environment::ValidationEnvironment,
    )
        # Reuse the immutable record constructor's validation rules immediately.
        validated = ValidationSuiteResult(
            suite_id,
            title,
            schema_version,
            environment,
            (),
        )
        new(
            validated.suite_id,
            validated.title,
            validated.schema_version,
            environment,
            ValidationCaseResult[],
            suite_builder_collecting,
        )
    end
end

function _require_suite_builder_state(
    builder::ValidationSuiteResultBuilder,
    allowed,
    operation,
)
    builder.state in allowed || throw(
        ArgumentError("Cannot $(operation) while suite builder state is $(builder.state)."),
    )
    nothing
end

"""
    record_case_result!(builder, result)

Append one completed immutable case result. Insertion order is retained exactly.
Duplicate case identifiers and environment mismatches are rejected.
"""
function record_case_result!(
    builder::ValidationSuiteResultBuilder,
    result::ValidationCaseResult,
)
    _require_suite_builder_state(
        builder,
        (suite_builder_collecting,),
        "record a case result",
    )
    case_id = result.definition.case_id
    any(existing -> existing.definition.case_id == case_id, builder.cases) && throw(
        ArgumentError("Case $(case_id) has already been recorded."),
    )
    result.environment == builder.environment || throw(
        ArgumentError("Case $(case_id) environment does not match the suite environment."),
    )
    push!(builder.cases, result)
    builder
end

"""
    build_suite_result(builder)

Construct the immutable `ValidationSuiteResult`. A suite builder is single-use:
after successful construction it cannot be modified or built again.
"""
function build_suite_result(builder::ValidationSuiteResultBuilder)
    _require_suite_builder_state(
        builder,
        (suite_builder_collecting,),
        "build a suite result",
    )
    result = ValidationSuiteResult(
        builder.suite_id,
        builder.title,
        builder.schema_version,
        builder.environment,
        Tuple(builder.cases),
    )
    builder.state = suite_builder_built
    result
end

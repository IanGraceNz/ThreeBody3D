function _protocol_definition(case_id=:protocol_case; expected_outcome=expected_completed)
    ValidationCaseDefinition(
        case_id,
        "Protocol case",
        "Synthetic case for shared reporting-protocol tests.",
        (:infrastructure,),
        (:protocol,),
        "examples/validation/$(case_id).jl",
        (:quick,),
        expected_outcome,
        true,
        "1.0.0",
    )
end

function _protocol_result(; case_id=:protocol_case, criterion_status=criterion_pass,
    expected_outcome=expected_completed, actual_outcome=actual_completed)
    definition = _protocol_definition(case_id; expected_outcome=expected_outcome)
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "9442737", false, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-21T08:00:00Z",
    )
    configuration = ValidationConfiguration(solver=:vern9, time_interval=(0.0, 1.0))
    metric = ValidationMetric(:completed, "Completed", criterion_status == criterion_pass;
        role=role_acceptance)
    specification = AcceptanceCriterionSpecification(
        :completion_required, "Case completed", :completed, relation_true,
    )
    criterion = AcceptanceCriterion(specification, criterion_status;
        message=criterion_status == criterion_error ? "Synthetic criterion error." : nothing)
    execution = ExecutionOutcome(
        actual_outcome;
        exit_code=actual_outcome == actual_completed ? 0 : 1,
        summary=actual_outcome in (actual_errored, actual_terminated) ? "Synthetic failure." : nothing,
    )
    ValidationCaseResult(
        definition, environment, configuration, (metric,), (criterion,), nothing, execution,
    )
end

@testset "Validation case environment protocol" begin
    definition = _protocol_definition()
    standalone = resolve_case_protocol(definition, "1.0.0"; environment=Dict{String,String}())
    @test !report_requested(standalone)
    @test standalone.report_path === nothing

    mktempdir() do directory
        requested_path = joinpath(directory, "case.toml")
        environment = Dict(
            VALIDATION_REPORT_ENV => requested_path,
            VALIDATION_CASE_ID_ENV => "protocol_case",
            VALIDATION_SCHEMA_VERSION_ENV => "1.0.0",
        )
        protocol = resolve_case_protocol(definition, "1.0.0"; environment=environment)
        @test report_requested(protocol)
        @test protocol.report_path == abspath(requested_path)
        @test protocol.requested_case_id == :protocol_case
        @test protocol.requested_schema_version == "1.0.0"
    end

    @test_throws ArgumentError resolve_case_protocol(definition, "1.0.0";
        environment=Dict(VALIDATION_CASE_ID_ENV => "protocol_case"))
    @test_throws ArgumentError resolve_case_protocol(definition, "1.0.0";
        environment=Dict(VALIDATION_REPORT_ENV => "case.toml"))
    @test_throws ArgumentError resolve_case_protocol(definition, "1.0.0";
        environment=Dict(
            VALIDATION_REPORT_ENV => "case.toml",
            VALIDATION_CASE_ID_ENV => "other_case",
            VALIDATION_SCHEMA_VERSION_ENV => "1.0.0",
        ))
    @test_throws ArgumentError resolve_case_protocol(definition, "1.0.0";
        environment=Dict(
            VALIDATION_REPORT_ENV => "case.toml",
            VALIDATION_CASE_ID_ENV => "protocol_case",
            VALIDATION_SCHEMA_VERSION_ENV => "2.0.0",
        ))
end

@testset "Requested report publication" begin
    result = _protocol_result()
    standalone = ValidationCaseProtocol(nothing, nothing, nothing)
    @test write_requested_report(standalone, result) === nothing

    mktempdir() do directory
        path = joinpath(directory, "nested", "case.toml")
        protocol = ValidationCaseProtocol(path, :protocol_case, "1.0.0")
        io = IOBuffer()
        @test publish_case_result(protocol, result; io=io) == 0
        @test isfile(path)
        @test !isfile(path * ".tmp")
        @test read_case_report(path).definition.case_id == :protocol_case
        @test occursin("Case status: PASS", String(take!(io)))
    end

    wrong_case = ValidationCaseProtocol("case.toml", :other_case, "1.0.0")
    @test_throws ArgumentError write_requested_report(wrong_case, result)
    wrong_schema = ValidationCaseProtocol("case.toml", :protocol_case, "2.0.0")
    @test_throws ArgumentError write_requested_report(wrong_schema, result)
end

@testset "Validation exit semantics" begin
    @test validation_exit_code(_protocol_result()) == 0
    @test validation_exit_code(_protocol_result(criterion_status=criterion_fail)) == 1
    @test validation_exit_code(_protocol_result(criterion_status=criterion_error)) == 1

    expected_stop_result = _protocol_result(
        expected_outcome=expected_stop,
        actual_outcome=actual_stopped,
    )
    @test expected_stop_result.status == case_pass
    @test validation_exit_code(expected_stop_result) == 0

    passing = _protocol_result()
    failing_optional = _protocol_result(case_id=:optional_protocol_case,
        criterion_status=criterion_fail)
    optional_definition = failing_optional.definition
    optional_definition = ValidationCaseDefinition(
        optional_definition.case_id, optional_definition.title, optional_definition.description,
        optional_definition.classifications, optional_definition.tags,
        optional_definition.source_path, optional_definition.tiers,
        optional_definition.expected_outcome, false, optional_definition.definition_version,
        optional_definition.provenance,
    )
    failing_optional = ValidationCaseResult(
        optional_definition, failing_optional.environment, failing_optional.configuration,
        failing_optional.metrics, failing_optional.criteria, failing_optional.solver_statistics,
        failing_optional.execution,
    )
    suite = ValidationSuiteResult(
        :protocol_suite, "Protocol suite", "1.0.0", passing.environment,
        (passing, failing_optional),
    )
    @test suite.status == suite_pass
    @test validation_exit_code(suite) == 0
end

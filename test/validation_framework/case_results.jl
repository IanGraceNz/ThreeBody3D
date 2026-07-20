@testset "Structured case-result builder" begin
    definition = ValidationCaseDefinition(
        :builder_case,
        "Builder case",
        "Exercises deterministic structured result construction.",
        (:regression,),
        (:framework,),
        "examples/validation/builder_case.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", "1b1fab8", false, "1.12.5", "Windows", "x86_64", 2,
        "2026-07-20T09:00:00Z",
    )
    configuration = ValidationConfiguration(
        solver=:accurate,
        absolute_tolerance=1e-12,
        relative_tolerance=1e-12,
    )
    energy = ValidationMetric(
        :energy_drift,
        "Maximum relative energy drift",
        1e-13;
        scale=scale_relative,
        role=role_acceptance,
        aggregation=aggregation_maximum,
    )
    finite_energy = AcceptanceCriterionSpecification(
        :energy_is_finite,
        "Energy drift is finite",
        :energy_drift,
        relation_finite,
    )
    bounded_energy = AcceptanceCriterionSpecification(
        :energy_within_limit,
        "Energy drift remains below the declared limit",
        :energy_drift,
        relation_less_than;
        expected_value=1e-10,
    )
    statistics = SolverStatistics(accepted_steps=12, rejected_steps=0)

    builder = ValidationCaseResultBuilder(definition, environment)
    @test record_configuration!(builder, configuration) === builder
    @test record_metric!(builder, energy) === builder
    @test declare_criterion!(builder, finite_energy) === builder
    @test declare_criterion!(builder, bounded_energy) === builder
    @test record_solver_statistics!(builder, statistics) === builder

    criteria = evaluate_criteria!(builder)
    @test map(result -> result.status, criteria) == (criterion_pass, criterion_pass)
    @test finish_execution!(builder, ExecutionOutcome(actual_completed; exit_code=0)) === builder

    result = build_case_result(builder)
    @test result.status == case_pass
    @test result.metrics == (energy,)
    @test result.criteria == criteria
    @test result.solver_statistics === statistics
    @test result.execution.actual == actual_completed
end

@testset "Case-result builder invariants" begin
    definition = ValidationCaseDefinition(
        :builder_invariants,
        "Builder invariants",
        "Rejects incomplete and ambiguous construction histories.",
        (:regression,),
        (),
        "examples/validation/builder_invariants.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T09:00:00Z",
    )
    configuration = ValidationConfiguration()
    metric = ValidationMetric(:completed, "Completed", true; role=role_acceptance)
    specification = AcceptanceCriterionSpecification(
        :completed,
        "Case completed",
        :completed,
        relation_true,
    )

    builder = ValidationCaseResultBuilder(definition, environment)
    @test_throws ArgumentError evaluate_criteria!(builder)
    record_configuration!(builder, configuration)
    @test_throws ArgumentError record_configuration!(builder, configuration)
    record_metric!(builder, metric)
    @test_throws ArgumentError record_metric!(builder, metric)
    declare_criterion!(builder, specification)
    @test_throws ArgumentError declare_criterion!(builder, specification)
    @test_throws ArgumentError finish_execution!(builder, ExecutionOutcome(actual_completed))

    evaluate_criteria!(builder)
    @test_throws ArgumentError record_metric!(
        builder,
        ValidationMetric(:late_metric, "Late metric", 1),
    )
    @test_throws ArgumentError evaluate_criteria!(builder)
    finish_execution!(builder, ExecutionOutcome(actual_completed))
    @test_throws ArgumentError finish_execution!(builder, ExecutionOutcome(actual_completed))

    result = build_case_result(builder)
    @test result.status == case_pass
    @test_throws ArgumentError build_case_result(builder)
end

@testset "Case-result builder propagates evaluated failure" begin
    definition = ValidationCaseDefinition(
        :builder_failure,
        "Builder failure",
        "Retains scientific failure independently of successful execution.",
        (:regression,),
        (),
        "examples/validation/builder_failure.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    environment = ValidationEnvironment(
        "1.0.0", "0.5.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T09:00:00Z",
    )
    builder = ValidationCaseResultBuilder(definition, environment)
    record_configuration!(builder, ValidationConfiguration())
    record_metric!(builder, ValidationMetric(:error, "Error", 2.0; role=role_acceptance))
    declare_criterion!(builder, AcceptanceCriterionSpecification(
        :error_limit,
        "Error remains below one",
        :error,
        relation_less_than;
        expected_value=1.0,
    ))
    evaluated = evaluate_criteria!(builder)
    @test only(evaluated).status == criterion_fail
    finish_execution!(builder, ExecutionOutcome(actual_completed))
    @test build_case_result(builder).status == case_fail
end

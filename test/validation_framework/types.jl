@testset "Structured validation result types" begin
    @test stable_string(metric_numeric) == "numeric"
    @test stable_string(relation_less_than) == "less_than"
    @test stable_string(case_pass) == "pass"

    definition = ValidationCaseDefinition(
        :figure_eight,
        "Figure-eight benchmark",
        "Checks periodic three-body motion and conservation diagnostics.",
        (:scientific_reference, :regression),
        (:periodic, :cartesian),
        "examples/validation/figure_eight_benchmark.jl",
        (:quick, :standard),
        expected_completed,
        true,
        "1.0.0",
        "Moore figure-eight orbit",
    )
    @test definition.case_id == :figure_eight
    @test definition.source_path == "examples/validation/figure_eight_benchmark.jl"
    @test definition.required

    environment = ValidationEnvironment(
        "1.0.0",
        "0.4.0",
        "506ee49",
        false,
        "1.12.5",
        "Windows",
        "x86_64",
        8,
        "2026-07-20T08:00:00Z",
    )
    @test environment.thread_count == 8

    configuration = ValidationConfiguration(
        solver=:accurate,
        absolute_tolerance=1e-12,
        relative_tolerance=1e-12,
        precision_bits=64,
        time_interval=(0.0, 1.0),
        sampling="saveat=0.01",
        selected_pair=(1, 2),
        thresholds=(ValidationParameter(:energy_limit, 1e-10),),
        seeds=(0x1234,),
        parameters=(ValidationParameter(:periods, 1),),
    )
    @test configuration.solver == :accurate
    @test configuration.selected_pair == (1, 2)
    @test first(configuration.parameters).value == 1

    energy = ValidationMetric(
        :maximum_relative_energy_drift,
        "Maximum relative energy drift",
        1.2e-13;
        scale=scale_relative,
        role=role_acceptance,
        aggregation=aggregation_maximum,
    )
    periodicity = ValidationMetric(
        :periodicity_error,
        "Periodicity error",
        3.5e-7;
        scale=scale_absolute,
        role=role_acceptance,
    )
    @test energy.kind == metric_numeric
    @test energy.value == 1.2e-13

    energy_specification = AcceptanceCriterionSpecification(
        :energy_drift_limit,
        "Energy drift remains below the declared limit",
        :maximum_relative_energy_drift,
        relation_less_than;
        expected_value=1e-10,
    )
    periodicity_specification = AcceptanceCriterionSpecification(
        :periodicity_limit,
        "Periodicity error remains below the declared limit",
        :periodicity_error,
        relation_less_than;
        expected_value=1e-5,
    )
    energy_criterion = AcceptanceCriterion(energy_specification, criterion_pass)
    periodicity_criterion = AcceptanceCriterion(periodicity_specification, criterion_pass)

    statistics = SolverStatistics(
        accepted_steps=100,
        rejected_steps=0,
        rhs_evaluations=1500,
        saved_states=500,
        elapsed_seconds=0.25,
    )
    execution = ExecutionOutcome(actual_completed; exit_code=0, elapsed_seconds=0.3)
    result = ValidationCaseResult(
        definition,
        environment,
        configuration,
        (energy, periodicity),
        (energy_criterion, periodicity_criterion),
        statistics,
        execution,
    )
    @test result.status == case_pass
    @test result.metrics[1] === energy

    suite = ValidationSuiteResult(
        :standard_suite,
        "Standard scientific validation suite",
        "1.0.0",
        environment,
        (result,),
    )
    @test suite.status == suite_pass
    @test suite.passed_count == 1
    @test suite.failed_count == 0
    @test suite.error_count == 0
end

@testset "Structured validation invariants" begin
    @test_throws ArgumentError ValidationCaseDefinition(
        :BadId,
        "Title",
        "Description",
        (:regression,),
        (),
        "examples/validation/case.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    @test_throws ArgumentError ValidationCaseDefinition(
        :valid_id,
        "Title",
        "Description",
        (:regression,),
        (),
        "../outside.jl",
        (:quick,),
        expected_completed,
        true,
        "1.0.0",
    )
    @test_throws ArgumentError ValidationConfiguration(time_interval=(1.0, 0.0))
    @test_throws ArgumentError ValidationConfiguration(selected_pair=(1, 1))
    @test_throws ArgumentError SolverStatistics(accepted_steps=-1)
    @test_throws ArgumentError ExecutionOutcome(actual_errored)
    @test_throws ArgumentError ValidationMetric(:bad_value, "Bad value", 1.0 + 2.0im)

    definition = ValidationCaseDefinition(
        :expected_stop_case,
        "Expected-stop case",
        "Exercises a declared stopping condition.",
        (:stress,),
        (),
        "examples/validation/close_encounter_comparison.jl",
        (:extended,),
        expected_stop,
        true,
        "1.0.0",
    )
    environment = ValidationEnvironment(
        "1.0.0", "0.4.0", nothing, nothing, "1.12.5", "Windows", "x86_64", 1,
        "2026-07-20T08:00:00Z",
    )
    configuration = ValidationConfiguration()
    metric = ValidationMetric(:stop_detected, "Stop detected", true; role=role_acceptance)
    passing_specification = AcceptanceCriterionSpecification(
        :stop_detected,
        "Expected stop was detected",
        :stop_detected,
        relation_true,
    )
    passing = AcceptanceCriterion(passing_specification, criterion_pass)

    stopped_result = ValidationCaseResult(
        definition,
        environment,
        configuration,
        (metric,),
        (passing,),
        nothing,
        ExecutionOutcome(actual_stopped),
    )
    @test stopped_result.status == case_pass

    mismatched_result = ValidationCaseResult(
        definition,
        environment,
        configuration,
        (metric,),
        (passing,),
        nothing,
        ExecutionOutcome(actual_completed),
    )
    @test mismatched_result.status == case_error

    failed = AcceptanceCriterion(passing_specification, criterion_fail)
    failed_result = ValidationCaseResult(
        definition,
        environment,
        configuration,
        (metric,),
        (failed,),
        nothing,
        ExecutionOutcome(actual_stopped),
    )
    @test failed_result.status == case_fail

    @test_throws ArgumentError ValidationCaseResult(
        definition,
        environment,
        configuration,
        (metric, metric),
        (passing,),
        nothing,
        ExecutionOutcome(actual_stopped),
    )
    missing_metric_specification = AcceptanceCriterionSpecification(
        :missing_metric,
        "Missing metric",
        :not_recorded,
        relation_true,
    )
    missing_metric_criterion = AcceptanceCriterion(
        missing_metric_specification,
        criterion_error;
        message="Metric was not recorded.",
    )
    @test_throws ArgumentError ValidationCaseResult(
        definition,
        environment,
        configuration,
        (metric,),
        (missing_metric_criterion,),
        nothing,
        ExecutionOutcome(actual_stopped),
    )
end

@testset "Structured validation criterion evaluation" begin
    numeric = ValidationMetric(:numeric_value, "Numeric value", 2.0; role=role_acceptance)
    integer = ValidationMetric(:integer_value, "Integer value", 2; role=role_acceptance)
    boolean = ValidationMetric(:boolean_value, "Boolean value", true; role=role_acceptance)
    status = ValidationMetric(:status_value, "Status value", :completed; role=role_acceptance)

    relations = (
        (relation_less_than, 3.0, criterion_pass),
        (relation_less_than_or_equal, 2.0, criterion_pass),
        (relation_greater_than, 1.0, criterion_pass),
        (relation_greater_than_or_equal, 2.0, criterion_pass),
        (relation_less_than, 2.0, criterion_fail),
    )
    for (index, (relation, expected, expected_status)) in enumerate(relations)
        specification = AcceptanceCriterionSpecification(
            Symbol("ordering_$index"),
            "Ordering criterion $index",
            :numeric_value,
            relation;
            expected_value=expected,
        )
        @test evaluate_criterion(specification, numeric).status == expected_status
    end

    exact_integer = AcceptanceCriterionSpecification(
        :integer_equality,
        "Integer equality",
        :integer_value,
        relation_equal;
        expected_value=2,
    )
    @test evaluate_criterion(exact_integer, integer).status == criterion_pass

    approximate = AcceptanceCriterionSpecification(
        :approximate_numeric,
        "Approximate numeric equality",
        :numeric_value,
        relation_approximately_equal;
        expected_value=2.01,
        absolute_tolerance=0.02,
        relative_tolerance=0.0,
    )
    @test evaluate_criterion(approximate, numeric).status == criterion_pass

    finite = AcceptanceCriterionSpecification(
        :finite_numeric,
        "Finite numeric value",
        :numeric_value,
        relation_finite,
    )
    @test evaluate_criterion(finite, numeric).status == criterion_pass

    true_specification = AcceptanceCriterionSpecification(
        :boolean_true,
        "Boolean is true",
        :boolean_value,
        relation_true,
    )
    @test evaluate_criterion(true_specification, boolean).status == criterion_pass

    expected_status = AcceptanceCriterionSpecification(
        :expected_completion,
        "Expected completion status",
        :status_value,
        relation_expected_status;
        expected_value=:completed,
    )
    @test evaluate_criterion(expected_status, status).status == criterion_pass
end

@testset "Criterion evaluation failures and errors" begin
    nonfinite = ValidationMetric(:numeric_value, "Numeric value", Inf; role=role_acceptance)
    less_than = AcceptanceCriterionSpecification(
        :finite_bound,
        "Finite bound",
        :numeric_value,
        relation_less_than;
        expected_value=1.0,
    )
    nonfinite_result = evaluate_criterion(less_than, nonfinite)
    @test nonfinite_result.status == criterion_fail
    @test nonfinite_result.message == "Observed numeric value is not finite."

    missing_tolerance = AcceptanceCriterionSpecification(
        :missing_tolerance,
        "Missing tolerance",
        :numeric_value,
        relation_approximately_equal;
        expected_value=1.0,
    )
    missing_tolerance_result = evaluate_criterion(missing_tolerance, nonfinite)
    @test missing_tolerance_result.status == criterion_error
    @test occursin("requires an absolute or relative tolerance", missing_tolerance_result.message)

    boolean = ValidationMetric(:boolean_value, "Boolean value", true; role=role_acceptance)
    wrong_type = AcceptanceCriterionSpecification(
        :wrong_type,
        "Wrong type",
        :boolean_value,
        relation_less_than;
        expected_value=1.0,
    )
    @test evaluate_criterion(wrong_type, boolean).status == criterion_error

    wrong_metric = AcceptanceCriterionSpecification(
        :wrong_metric,
        "Wrong metric",
        :different_metric,
        relation_true,
    )
    wrong_metric_result = evaluate_criterion(wrong_metric, boolean)
    @test wrong_metric_result.status == criterion_error
    @test occursin("references metric different_metric", wrong_metric_result.message)

    sequence = ValidationMetric(:sequence_value, "Sequence value", (1.0, 2.0))
    sequence_equal = AcceptanceCriterionSpecification(
        :sequence_equal,
        "Sequence equality",
        :sequence_value,
        relation_equal;
        expected_value=(1.0, 2.0),
    )
    @test evaluate_criterion(sequence_equal, sequence).status == criterion_error

    finite_boolean = AcceptanceCriterionSpecification(
        :finite_boolean,
        "Finite Boolean",
        :boolean_value,
        relation_finite,
    )
    @test evaluate_criterion(finite_boolean, boolean).status == criterion_error
end

@testset "Ordered criterion collection evaluation" begin
    metrics = (
        ValidationMetric(:energy_drift, "Energy drift", 1e-12; role=role_acceptance),
        ValidationMetric(:completed, "Completed", true; role=role_acceptance),
    )
    specifications = (
        AcceptanceCriterionSpecification(
            :energy_limit,
            "Energy limit",
            :energy_drift,
            relation_less_than;
            expected_value=1e-10,
        ),
        AcceptanceCriterionSpecification(
            :completion_required,
            "Completion required",
            :completed,
            relation_true,
        ),
    )
    results = evaluate_criteria(specifications, reverse(metrics))
    @test map(result -> result.specification.criterion_id, results) == (
        :energy_limit,
        :completion_required,
    )
    @test all(result -> result.status == criterion_pass, results)

    @test_throws ArgumentError evaluate_criteria(
        (specifications[1], specifications[1]),
        metrics,
    )
    @test_throws ArgumentError evaluate_criteria(
        specifications,
        (metrics[1], metrics[1]),
    )
    missing = AcceptanceCriterionSpecification(
        :missing,
        "Missing metric",
        :not_recorded,
        relation_true,
    )
    @test_throws ArgumentError evaluate_criteria((missing,), metrics)
end

function _investigation_fixture()
    benchmark = ValidationCaseDefinition(
        :figure_eight,
        "Figure-eight",
        "Periodic three-body benchmark.",
        (:periodic,),
        (:core,),
        "examples/validation/figure_eight.jl",
        (:standard,),
        expected_completed,
        true,
        "1.0.0",
    )
    definition = InvestigationDefinition(
        :figure_eight_tolerance,
        "Figure-eight tolerance series",
        "Vary tolerance while preserving the benchmark and fixed controls.",
        benchmark,
        :tolerance,
        (ValidationParameter(:duration, 10.0),),
        (:energy_drift,),
        (:rhs_evaluations,),
        "1.0.0",
    )
    environment = ValidationEnvironment(
        "1.0.0",
        "0.5.0",
        "abc123",
        false,
        "1.11.0",
        "Windows",
        "x86_64",
        1,
        "2026-07-31T00:00:00Z",
    )
    definition, environment
end

@testset "Investigation record types" begin
    definition, environment = _investigation_fixture()
    configuration = ValidationConfiguration(
        solver=:vern9,
        absolute_tolerance=1.0e-12,
        relative_tolerance=1.0e-12,
        time_interval=(0.0, 10.0),
    )
    metric = ValidationMetric(
        :energy_drift,
        "Maximum relative energy drift",
        1.0e-11;
        scale=scale_relative,
        role=role_descriptive,
        aggregation=aggregation_maximum,
    )
    point = InvestigationMeasurementPoint(
        :tolerance_1e_12,
        definition,
        configuration,
        ValidationParameter(:tolerance, 1.0e-12),
        environment,
        ExecutionOutcome(actual_completed),
        (metric,),
        SolverStatistics(accepted_steps=100, rhs_evaluations=1200);
        notes="Directly sampled endpoint.",
    )
    failed = InvestigationMeasurementPoint(
        :tolerance_1e_14,
        definition,
        configuration,
        ValidationParameter(:tolerance, 1.0e-14),
        environment,
        ExecutionOutcome(actual_errored; summary="Integration failed."),
        ();
        notes="No numerical metrics were produced.",
    )
    series = InvestigationMeasurementSeries(
        :figure_eight_tolerance,
        "Figure-eight tolerance series",
        "Ordered tolerance measurements.",
        definition,
        (point, failed),
    )

    @test isimmutable(definition)
    @test isimmutable(point)
    @test isimmutable(series)
    @test definition.fixed_controls isa Tuple
    @test point.metrics == (metric,)
    @test point.solver_statistics.accepted_steps == 100
    @test failed.metrics == ()
    @test series.points == (point, failed)
    @test map(item -> item.independent_value.value, series.points) == (1.0e-12, 1.0e-14)
end

@testset "Investigation record invariants" begin
    definition, environment = _investigation_fixture()
    configuration = ValidationConfiguration()
    completed = ExecutionOutcome(actual_completed)
    metric = ValidationMetric(:energy_drift, "Energy drift", 1.0e-11)

    @test_throws ArgumentError InvestigationDefinition(
        :bad_controls,
        "Bad controls",
        "Independent variable is also fixed.",
        definition.benchmark,
        :tolerance,
        (ValidationParameter(:tolerance, 1.0e-12),),
        (:energy_drift,),
        (),
        "1.0.0",
    )
    @test_throws ArgumentError InvestigationMeasurementPoint(
        :wrong_variable,
        definition,
        configuration,
        ValidationParameter(:duration, 1.0),
        environment,
        completed,
        (metric,),
    )
    @test_throws ArgumentError InvestigationMeasurementPoint(
        :missing_required,
        definition,
        configuration,
        ValidationParameter(:tolerance, 1.0e-12),
        environment,
        completed,
        (),
    )
    @test_throws ArgumentError InvestigationMeasurementPoint(
        :undeclared_metric,
        definition,
        configuration,
        ValidationParameter(:tolerance, 1.0e-12),
        environment,
        completed,
        (ValidationMetric(:position_error, "Position error", 1.0e-8),),
    )

    point = InvestigationMeasurementPoint(
        :valid_point,
        definition,
        configuration,
        ValidationParameter(:tolerance, 1.0e-12),
        environment,
        completed,
        (metric,),
    )
    @test_throws ArgumentError InvestigationMeasurementSeries(
        :empty_series,
        "Empty",
        "No points.",
        definition,
        (),
    )
    @test_throws ArgumentError InvestigationMeasurementSeries(
        :duplicate_points,
        "Duplicates",
        "Duplicate point identifiers.",
        definition,
        (point, point),
    )
end

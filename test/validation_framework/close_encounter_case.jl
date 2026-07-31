function _close_case_data(; automatic_error=2e-10, cartesian_error=1e-3, cartesian_periapsis_error=1.1e-3)
    work = (accepted_steps=10, rejected_steps=1, rhs_evaluations=100, saved_states=20)
    cartesian = (
        errors=(maximum_combined=cartesian_error,), work=work, elapsed=1.0,
        segments=1, switches=0,
    )
    automatic = (
        errors=(maximum_combined=automatic_error,), work=work, elapsed=2.0,
        segments=3, switches=2,
    )
    explicit = (
        errors=(maximum_combined=3e-10,), work=work, elapsed=3.0,
        segments=3, switches=2,
    )
    exit_difference = (state=4e-11,)
    reference_periapsis = (time=0.8, separation=1e-4,)
    periapses = (
        (name="Cartesian", result=(time=0.801, separation=1e-4 + cartesian_periapsis_error,)),
        (name="Automatic switching", result=(time=0.80000001, separation=1e-4 + 2e-11,)),
        (name="Explicit regularized", result=(time=0.80000002, separation=1e-4 + 3e-11,)),
    )
    endpoint_times = (explicit_time_residual=4e-12,)
    (; cartesian, automatic, explicit, exit_difference, reference_periapsis, periapses, endpoint_times)
end

function _build_close_case(data; automatic_improvement_ratio_limit=0.5)
    build_close_encounter_case_result(
        data.cartesian,
        data.automatic,
        data.explicit,
        data.exit_difference,
        data.reference_periapsis,
        data.periapses,
        data.endpoint_times,
        _pilot_environment();
        automatic_maximum_state_error_limit=1e-9,
        explicit_maximum_state_error_limit=1e-9,
        exit_state_agreement_limit=1e-10,
        explicit_exit_time_residual_limit=5e-12,
        automatic_periapsis_separation_error_limit=1e-10,
        explicit_periapsis_separation_error_limit=1e-10,
        cartesian_under_resolution_minimum=1e-3,
        automatic_improvement_ratio_limit,
        configuration=ValidationFramework._close_encounter_configuration(
            initial_state=ntuple(identity, 18),
            masses=(1.0, 1.0, 0.001),
            gravitational_constant=1.0,
            apoapsis=1.0,
            nominal_periapsis=0.0001,
            third_body_offset=10.0,
        ),
    )
end

@testset "Close-encounter structured adapter" begin
    result = _build_close_case(_close_case_data())
    @test result.status == case_pass
    @test result.definition.case_id == :close_encounter_comparison
    @test length(result.metrics) == 11
    @test length(result.criteria) == 8
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.criteria[7].specification.relation == relation_greater_than_or_equal
    @test result.solver_statistics.accepted_steps == 30
    @test result.solver_statistics.segment_count == 7
    @test result.solver_statistics.switch_count == 4
    @test only(filter(
        metric -> metric.metric_id == :automatic_periapsis_time_error,
        result.metrics,
    )).value ≈ 1e-8

    under_resolution_not_exposed = _build_close_case(
        _close_case_data(cartesian_periapsis_error=5e-4),
    )
    @test under_resolution_not_exposed.status == case_fail
    @test under_resolution_not_exposed.criteria[7].status == criterion_fail

    insufficient_improvement = _build_close_case(
        _close_case_data(automatic_error=6e-4, cartesian_error=1e-3),
    )
    @test insufficient_improvement.status == case_fail
    @test insufficient_improvement.criteria[8].status == criterion_fail
end

@testset "Close-encounter definition and protocol" begin
    definition = close_encounter_case_definition()
    @test definition.source_path == "examples/validation/close_encounter_comparison.jl"
    @test definition.expected_outcome == expected_completed
    @test_throws ArgumentError resolve_case_protocol(
        definition,
        VALIDATION_SCHEMA_VERSION;
        environment=Dict(
            VALIDATION_REPORT_ENV => "case.toml",
            VALIDATION_CASE_ID_ENV => "figure_eight",
            VALIDATION_SCHEMA_VERSION_ENV => VALIDATION_SCHEMA_VERSION,
        ),
    )
end

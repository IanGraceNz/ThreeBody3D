function _build_triple_collision_case(;
    terminated=true,
    event_separation=1.0e-5 * (1 + 5e-7),
    position_error=2e-11,
    velocity_error=3e-10,
)
    build_triple_collision_case_result(
        terminated,
        0.6412749,
        event_separation,
        position_error,
        velocity_error,
        500,
        SolverStatistics(
            accepted_steps=120,
            rejected_steps=4,
            rhs_evaluations=2100,
            saved_states=501,
        ),
        _pilot_environment();
        collision_time=0.641274915,
        return_time=1.28254983,
        final_time=1.31461358,
        close_approach_threshold=1e-5,
        validation_minimum_separation=1e-3,
        position_error_limit=1e-10,
        velocity_error_limit=1e-9,
        event_separation_relative_limit=1e-6,
        solver=:accurate,
        absolute_tolerance=1e-13,
        relative_tolerance=1e-13,
        saveat=0.641274915 / 500,
        masses=(1.0, 1.0, 1.0),
        gravitational_constant=1.0,
        side_length=1.0,
    )
end

@testset "Triple-collision structured adapter" begin
    result = _build_triple_collision_case()
    @test result.status == case_pass
    @test result.definition.case_id == :equilateral_triple_collision_reference
    @test result.definition.expected_outcome == expected_stop
    @test length(result.metrics) == 7
    @test length(result.criteria) == 4
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.execution.actual == actual_stopped
    @test result.solver_statistics.accepted_steps == 120

    missed_stop = _build_triple_collision_case(terminated=false)
    @test missed_stop.status == case_error
    @test missed_stop.criteria[1].status == criterion_fail
    @test missed_stop.execution.actual == actual_completed

    inaccurate_position = _build_triple_collision_case(position_error=2e-10)
    @test inaccurate_position.status == case_fail
    @test inaccurate_position.criteria[3].status == criterion_fail

    inaccurate_event = _build_triple_collision_case(event_separation=1.0e-5 * (1 + 2e-6))
    @test inaccurate_event.status == case_fail
    @test inaccurate_event.criteria[2].status == criterion_fail
end

@testset "Triple-collision definition and protocol" begin
    definition = triple_collision_case_definition()
    @test definition.source_path == "examples/validation/equilateral_triple_collision_reference.jl"
    @test :analytic_reference in definition.classifications
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

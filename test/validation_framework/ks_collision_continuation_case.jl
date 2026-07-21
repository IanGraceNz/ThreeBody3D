function _build_ks_collision_continuation_case(;
    collision_radius=2e-14,
    position_symmetry_error=2e-10,
    u_error=2e-10,
    w_error=3e-10,
    time_error=4e-10,
    collision_energy_residual=2e-11,
    postcollision_finite=true,
)
    build_ks_collision_continuation_case_result(
        collision_radius,
        position_symmetry_error,
        u_error,
        w_error,
        time_error,
        collision_energy_residual,
        postcollision_finite,
        SolverStatistics(saved_states=301),
        _pilot_environment();
        gravitational_parameter=1.0,
        initial_position=(1.0, 0.0, 0.0),
        initial_velocity=(0.0, 0.0, 0.0),
        fictitious_time_interval=(0.0, 2.5),
        collision_fictitious_time=2.2,
        collision_physical_time=1.1,
        symmetry_probe=1e-3,
        saved_state_count=301,
        collision_radius_limit=5e-14,
        symmetry_error_limit=5e-10,
        position_error_limit=5e-10,
        velocity_error_limit=5e-10,
        time_error_limit=5e-10,
        energy_residual_limit=5e-11,
        algorithm=:vern9,
        relative_tolerance=1e-13,
        absolute_tolerance=1e-13,
    )
end

@testset "KS collision-continuation structured adapter" begin
    result = _build_ks_collision_continuation_case()
    @test result.status == case_pass
    @test result.definition.case_id == :ks_collision_continuation
    @test length(result.metrics) == 9
    @test length(result.criteria) == 7
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.solver_statistics.saved_states == 301

    inaccurate_collision = _build_ks_collision_continuation_case(collision_radius=6e-14)
    @test inaccurate_collision.status == case_fail
    @test inaccurate_collision.criteria[1].status == criterion_fail

    inaccurate_symmetry = _build_ks_collision_continuation_case(position_symmetry_error=6e-10)
    @test inaccurate_symmetry.status == case_fail
    @test inaccurate_symmetry.criteria[2].status == criterion_fail

    invalid_continuation = _build_ks_collision_continuation_case(postcollision_finite=false)
    @test invalid_continuation.status == case_fail
    @test invalid_continuation.criteria[7].status == criterion_fail
end

@testset "KS collision-continuation definition and protocol" begin
    definition = ks_collision_continuation_case_definition()
    @test definition.source_path == "examples/validation/ks_collision_continuation.jl"
    @test :collision in definition.classifications
    @test_throws ArgumentError resolve_case_protocol(
        definition,
        VALIDATION_SCHEMA_VERSION;
        environment=Dict(
            VALIDATION_REPORT_ENV => "case.toml",
            VALIDATION_CASE_ID_ENV => "ks_kepler",
            VALIDATION_SCHEMA_VERSION_ENV => VALIDATION_SCHEMA_VERSION,
        ),
    )
end

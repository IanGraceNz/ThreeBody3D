function _build_ks_levi_civita_comparison_case(;
    position_error=2e-10,
    ordinary_velocity_error=3e-10,
    conditioning_ratio=1.5,
    time_error=2e-10,
    energy_error=2e-10,
    ks_energy_drift=2e-10,
    levi_civita_energy_drift=2e-10,
    transition_position_error=2e-10,
    transition_velocity_error=2e-10,
)
    build_ks_levi_civita_comparison_case_result(
        position_error,
        ordinary_velocity_error,
        conditioning_ratio,
        time_error,
        energy_error,
        ks_energy_drift,
        levi_civita_energy_drift,
        transition_position_error,
        transition_velocity_error,
        SolverStatistics(),
        _pilot_environment();
        gravitational_parameter=1.0,
        initial_position=(2.0, 0.0),
        initial_velocity=(0.0, 0.0),
        collision_time=pi,
        sample_times=(0.0, 0.25pi, 0.75pi, pi * (1 - 1e-6), pi * (1 + 1e-6), 1.25pi),
        near_collision_radius=2e-3,
        ordinary_sample_count=4,
        near_collision_sample_count=2,
        discrepancy_limit=5e-10,
        conditioning_ratio_limit=2.0,
    )
end

@testset "KS/Levi-Civita comparison structured adapter" begin
    result = _build_ks_levi_civita_comparison_case()
    @test result.status == case_pass
    @test result.definition.case_id == :ks_levi_civita_comparison
    @test length(result.metrics) == 11
    @test length(result.criteria) == 9
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)

    inaccurate_position = _build_ks_levi_civita_comparison_case(position_error=6e-10)
    @test inaccurate_position.status == case_fail
    @test inaccurate_position.criteria[1].status == criterion_fail

    ill_conditioned_velocity = _build_ks_levi_civita_comparison_case(conditioning_ratio=2.1)
    @test ill_conditioned_velocity.status == case_fail
    @test ill_conditioned_velocity.criteria[9].status == criterion_fail

    inaccurate_transition = _build_ks_levi_civita_comparison_case(transition_velocity_error=6e-10)
    @test inaccurate_transition.status == case_fail
    @test inaccurate_transition.criteria[8].status == criterion_fail
end

@testset "KS/Levi-Civita comparison definition and protocol" begin
    definition = ks_levi_civita_comparison_case_definition()
    @test definition.source_path == "examples/validation/ks_levi_civita_comparison.jl"
    @test :levi_civita in definition.classifications
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

function _build_ks_kepler_case(;
    u_error=2e-10,
    w_error=3e-10,
    time_error=4e-10,
    constraint_residual=2e-11,
    energy_residual=3e-11,
    binding_energy_constant=true,
)
    build_ks_kepler_case_result(
        u_error,
        w_error,
        time_error,
        constraint_residual,
        energy_residual,
        binding_energy_constant,
        SolverStatistics(
            accepted_steps=95,
            rejected_steps=2,
            rhs_evaluations=1500,
            saved_states=241,
        ),
        _pilot_environment();
        gravitational_parameter=1.0,
        initial_position=(1.0, 0.2, -0.1),
        initial_velocity=(-0.15, 0.85, 0.20),
        fictitious_time_interval=(0.0, 6.0),
        saved_state_count=241,
        position_error_limit=5e-10,
        velocity_error_limit=5e-10,
        time_error_limit=5e-10,
        constraint_residual_limit=5e-11,
        energy_residual_limit=5e-11,
        algorithm=:vern9,
        relative_tolerance=1e-13,
        absolute_tolerance=1e-13,
    )
end

@testset "KS Kepler structured adapter" begin
    result = _build_ks_kepler_case()
    @test result.status == case_pass
    @test result.definition.case_id == :ks_kepler
    @test length(result.metrics) == 7
    @test length(result.criteria) == 6
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.solver_statistics.saved_states == 241

    inaccurate_position = _build_ks_kepler_case(u_error=6e-10)
    @test inaccurate_position.status == case_fail
    @test inaccurate_position.criteria[1].status == criterion_fail

    inaccurate_constraint = _build_ks_kepler_case(constraint_residual=6e-11)
    @test inaccurate_constraint.status == case_fail
    @test inaccurate_constraint.criteria[4].status == criterion_fail

    changed_energy = _build_ks_kepler_case(binding_energy_constant=false)
    @test changed_energy.status == case_fail
    @test changed_energy.criteria[6].status == criterion_fail
end

@testset "KS Kepler definition and protocol" begin
    definition = ks_kepler_case_definition()
    @test definition.source_path == "examples/validation/ks_kepler_validation.jl"
    @test :ks in definition.classifications
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

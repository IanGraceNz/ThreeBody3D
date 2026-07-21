function _build_ks_hierarchical_triple_case(;
    state_error=1e-8,
    energy_difference=1e-9,
    ks_energy_drift=1e-9,
    gauge_residual=1e-9,
    minimum_separation=2.0,
    entry_residual=5e-13,
    exit_residual=5e-13,
)
    build_ks_hierarchical_triple_case_result(
        state_error,
        energy_difference,
        ks_energy_drift,
        gauge_residual,
        minimum_separation,
        entry_residual,
        exit_residual,
        SolverStatistics(
            accepted_steps=20,
            rejected_steps=1,
            rhs_evaluations=300,
            saved_states=40,
            segment_count=2,
        ),
        _pilot_environment();
        masses=(1.0, 0.4, 0.2),
        gravitational_constant=1.0,
        initial_state=Tuple(zeros(18)),
        selected_pair=(1, 2),
        physical_time_interval=(0.0, 0.5),
        comparison_sample_count=101,
        algorithm=:vern9,
        relative_tolerance=1e-13,
        absolute_tolerance=1e-13,
        state_error_limit=2e-8,
        energy_difference_limit=2e-9,
        ks_energy_drift_limit=2e-9,
        gauge_residual_limit=2e-9,
        minimum_separation_limit=1.0,
        transition_residual_limit=1e-12,
    )
end

@testset "KS hierarchical-triple structured adapter" begin
    result = _build_ks_hierarchical_triple_case()
    @test result.status == case_pass
    @test result.definition.case_id == :ks_hierarchical_triple
    @test length(result.metrics) == 8
    @test length(result.criteria) == 7
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.solver_statistics.segment_count == 2

    inaccurate_state = _build_ks_hierarchical_triple_case(state_error=3e-8)
    @test inaccurate_state.status == case_fail
    @test inaccurate_state.criteria[1].status == criterion_fail

    unsafe_nonselected_pair = _build_ks_hierarchical_triple_case(minimum_separation=0.9)
    @test unsafe_nonselected_pair.status == case_fail
    @test unsafe_nonselected_pair.criteria[7].status == criterion_fail

    discontinuous_exit = _build_ks_hierarchical_triple_case(exit_residual=2e-12)
    @test discontinuous_exit.status == case_fail
    @test discontinuous_exit.criteria[6].status == criterion_fail
end

@testset "KS hierarchical-triple definition and protocol" begin
    definition = ks_hierarchical_triple_case_definition()
    @test definition.source_path == "examples/validation/ks_hierarchical_triple.jl"
    @test :hierarchical_triple in definition.classifications
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

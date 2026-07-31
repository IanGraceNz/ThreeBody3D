function _build_ks_switching_comparison_case(;
    ks_status=:completed,
    levi_civita_status=:completed,
    ks_switch_count=2,
    levi_civita_switch_count=2,
    state_difference=1e-8,
    entry_time_difference=1e-6,
    exit_time_difference=1e-6,
    ks_transition_residual=5e-12,
    levi_civita_transition_residual=5e-12,
)
    configuration = ValidationFramework._ks_switching_comparison_configuration(
        masses=(1e-12, 1e-12, 1e-12), gravitational_constant=1.0,
        initial_state=Tuple(zeros(18)), selected_pair=(1, 2),
        physical_time_interval=(0.0, 1.6), comparison_sample_count=161,
        enter_threshold=0.2, exit_threshold=0.4, ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0, maximum_switches=10,
        minimum_time_progress=eps(Float64), minimum_separation_excursion=0.0,
        threshold_scale_kind=:absolute, threshold_reference_scale=1.0,
        fixed_settings=ValidationFramework._ks_switching_fixed_settings(),
        state_difference_limit=2e-8, event_time_difference_limit=2e-6,
        transition_residual_limit=1e-11,
    )
    build_ks_switching_comparison_case_result(
        ks_status,
        levi_civita_status,
        ks_switch_count,
        levi_civita_switch_count,
        state_difference,
        entry_time_difference,
        exit_time_difference,
        ks_transition_residual,
        levi_civita_transition_residual,
        161,
        SolverStatistics(segment_count=6, switch_count=4),
        _pilot_environment();
        configuration,
        state_difference_limit=2e-8,
        event_time_difference_limit=2e-6,
        transition_residual_limit=1e-11,
    )
end

@testset "KS switching-comparison structured adapter" begin
    result = _build_ks_switching_comparison_case()
    @test result.status == case_pass
    @test result.definition.case_id == :ks_switching_comparison
    @test length(result.metrics) == 10
    @test length(result.criteria) == 9
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.solver_statistics.switch_count == 4

    failed_ks = _build_ks_switching_comparison_case(ks_status=:failure)
    @test failed_ks.execution.actual == actual_terminated
    @test isempty(failed_ks.criteria)
    @test any(metric -> metric.metric_id == :ks_status, failed_ks.metrics)

    wrong_switch_count = _build_ks_switching_comparison_case(ks_switch_count=3)
    @test wrong_switch_count.status == case_fail
    @test wrong_switch_count.criteria[3].status == criterion_fail

    divergent_backends = _build_ks_switching_comparison_case(state_difference=3e-8)
    @test divergent_backends.status == case_fail
    @test divergent_backends.criteria[5].status == criterion_fail

    discontinuous_transition = _build_ks_switching_comparison_case(levi_civita_transition_residual=2e-11)
    @test discontinuous_transition.status == case_fail
    @test discontinuous_transition.criteria[9].status == criterion_fail
end

@testset "KS switching-comparison definition and protocol" begin
    definition = ks_switching_comparison_case_definition()
    @test definition.source_path == "examples/validation/ks_switching_comparison.jl"
    @test :automatic_switching in definition.classifications
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

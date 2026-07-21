function _synthetic_benchmark_report(; name=:figure_eight, periodicity_error=1e-7, minimum_ratio=10.0)
    diagnostics = (
        maximum_relative_energy_drift=1e-13,
        maximum_linear_momentum_drift=1e-14,
        maximum_angular_momentum_drift=1e-13,
        maximum_center_of_mass_residual=1e-14,
    )
    (
        name=name,
        status=:completed,
        profile=:accurate,
        initial_time=0.0,
        final_time=10.0,
        expected_final_time=10.0,
        diagnostics=diagnostics,
        periodicity_error=periodicity_error,
        benchmark_metrics=(minimum_hierarchy_ratio=minimum_ratio,),
        saved_states=101,
        accepted_steps=50,
        rejected_steps=2,
        rhs_evaluations=800,
    )
end

function _pilot_environment()
    ValidationEnvironment(
        VALIDATION_SCHEMA_VERSION, "0.4.0", nothing, nothing,
        "1.12.5", "Windows", "x86_64", 1, "2026-07-21T00:00:00Z",
    )
end

@testset "Pilot core benchmark structured adapters" begin
    environment = _pilot_environment()
    figure = build_figure_eight_case_result(
        _synthetic_benchmark_report(), environment;
        energy_limit=1e-11,
        momentum_limit=1e-12,
        angular_momentum_limit=1e-11,
        center_of_mass_limit=1e-11,
        periodicity_limit=1e-5,
        final_time_limit=1e-10,
    )
    @test figure.status == case_pass
    @test figure.definition.case_id == :figure_eight
    @test map(metric -> metric.metric_id, figure.metrics) == (
        :integration_status,
        :final_time_residual,
        :maximum_relative_energy_drift,
        :maximum_linear_momentum_drift,
        :maximum_angular_momentum_drift,
        :maximum_center_of_mass_residual,
        :periodicity_error,
    )
    @test all(criterion -> criterion.status == criterion_pass, figure.criteria)
    @test figure.solver_statistics.accepted_steps == 50

    hierarchy = build_hierarchical_triple_case_result(
        _synthetic_benchmark_report(name=:hierarchical_triple), environment;
        energy_limit=1e-11,
        momentum_limit=1e-12,
        angular_momentum_limit=1e-11,
        center_of_mass_limit=1e-11,
        minimum_ratio_limit=5.0,
        final_time_limit=1e-10,
    )
    @test hierarchy.status == case_pass
    @test hierarchy.definition.case_id == :hierarchical_triple
    @test only(filter(metric -> metric.metric_id == :minimum_hierarchy_ratio, hierarchy.metrics)).value == 10.0

    failing = build_figure_eight_case_result(
        _synthetic_benchmark_report(periodicity_error=1e-3), environment;
        energy_limit=1e-11,
        momentum_limit=1e-12,
        angular_momentum_limit=1e-11,
        center_of_mass_limit=1e-11,
        periodicity_limit=1e-5,
        final_time_limit=1e-10,
    )
    @test failing.status == case_fail
    @test failing.criteria[end].status == criterion_fail
end

@testset "Pilot definitions and protocol validation precede execution" begin
    @test figure_eight_case_definition().source_path == "examples/validation/figure_eight_benchmark.jl"
    @test hierarchical_triple_case_definition().source_path == "examples/validation/hierarchical_triple_benchmark.jl"
    @test_throws ArgumentError resolve_case_protocol(
        figure_eight_case_definition(), VALIDATION_SCHEMA_VERSION;
        environment=Dict(
            VALIDATION_REPORT_ENV => "case.toml",
            VALIDATION_CASE_ID_ENV => "hierarchical_triple",
            VALIDATION_SCHEMA_VERSION_ENV => VALIDATION_SCHEMA_VERSION,
        ),
    )
end

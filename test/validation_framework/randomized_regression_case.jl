struct _RandomizedSyntheticTrial
    trial::Int
    completed::Bool
    finite::Bool
    maximum_relative_energy_drift::Float64
    maximum_momentum_drift::Float64
    maximum_angular_momentum_drift::Float64
    maximum_com_residual::Float64
    minimum_separation::Float64
    message::String
end

trial_passed(result::_RandomizedSyntheticTrial) =
    result.completed && result.finite &&
    result.maximum_relative_energy_drift <= 1e-8 &&
    result.maximum_momentum_drift <= 1e-10 &&
    result.maximum_angular_momentum_drift <= 1e-9 &&
    result.maximum_com_residual <= 1e-10

function _randomized_validation(; failed=:none)
    results = [
        _RandomizedSyntheticTrial(
            trial,
            !(failed == :completion && trial == 2),
            !(failed == :finite && trial == 2),
            failed == :limits && trial == 2 ? 2e-8 : 1e-9,
            1e-11,
            1e-10,
            1e-11,
            0.5,
            failed == :completion && trial == 2 ? "integration failed" : "",
        ) for trial in 1:3
    ]
    completed = count(result -> result.completed, results)
    finite = count(result -> result.finite, results)
    passing = count(trial_passed, results)
    (; seed=UInt32(0x3b0d9a71), trials=3, passing, completed, finite, results)
end

function _build_randomized_case(validation)
    build_randomized_regression_case_result(
        validation,
        _pilot_environment();
        duration=5.0,
        saveat=0.05,
        minimum_initial_separation=0.75,
        energy_drift_limit=1e-8,
        momentum_drift_limit=1e-10,
        angular_momentum_drift_limit=1e-9,
        center_of_mass_limit=1e-10,
        solver=:accurate,
    )
end

@testset "Randomized-regression structured adapter" begin
    result = _build_randomized_case(_randomized_validation())
    @test result.status == case_pass
    @test result.definition.case_id == :randomized_regression
    @test length(result.metrics) == 13
    @test length(result.criteria) == 3
    @test all(criterion -> criterion.status == criterion_pass, result.criteria)
    @test result.metrics[12].value == ()
    @test result.metrics[13].value == ()

    incomplete = _build_randomized_case(_randomized_validation(failed=:completion))
    @test incomplete.status == case_fail
    @test incomplete.criteria[1].status == criterion_fail
    @test incomplete.criteria[3].status == criterion_fail
    @test incomplete.metrics[12].value == (2,)
    @test incomplete.metrics[13].value == ("integration failed",)

    nonfinite = _build_randomized_case(_randomized_validation(failed=:finite))
    @test nonfinite.status == case_fail
    @test nonfinite.criteria[2].status == criterion_fail
    @test nonfinite.criteria[3].status == criterion_fail

    outside_limits = _build_randomized_case(_randomized_validation(failed=:limits))
    @test outside_limits.status == case_fail
    @test outside_limits.criteria[1].status == criterion_pass
    @test outside_limits.criteria[2].status == criterion_pass
    @test outside_limits.criteria[3].status == criterion_fail
end

@testset "Randomized-regression definition and protocol" begin
    definition = randomized_regression_case_definition()
    @test definition.source_path == "examples/validation/randomized_regression_validation.jl"
    @test definition.expected_outcome == expected_completed
    @test :ensemble in definition.classifications
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

@testset "Close-encounter regularised experiment controls" begin
    tolerances = ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES
    @test tolerances == (1e-10, 1e-11, 1e-12, 1e-13)
    configurations = close_encounter_regularized_tolerance_configuration.(tolerances)
    @test map(c -> c.regularized_relative_tolerance, configurations) == tolerances
    @test map(c -> c.regularized_absolute_tolerance, configurations) == tolerances
    @test all(c -> c.cartesian_relative_tolerance == 1e-13, configurations)
    @test all(c -> c.cartesian_absolute_tolerance == 1e-13, configurations)
    @test all(c -> c.entry_threshold == 0.1, configurations)
    @test all(c -> c.ambiguity_threshold == 0.25, configurations)
    @test all(c -> c.exit_threshold == 0.25, configurations)
    @test all(c -> c.state_evaluation_tolerance == 1e-14, configurations)
    @test all(c -> c.regularized_initial_step == 0.1, configurations)
    @test all(c -> c.regularized_maximum_iterations == 256, configurations)
    @test all(c -> c.state_evaluation_maximum_iterations == 256, configurations)
    @test_throws ArgumentError close_encounter_regularized_tolerance_configuration(1e-9)
    @test_throws ArgumentError close_encounter_regularized_tolerance_configuration(5e-12)
    controls = ValidationFramework._close_regularized_controls(configurations[3])
    parameters = ValidationFramework.close_encounter_automatic_parameters(controls)
    @test parameters.enter_threshold == 0.1
    @test parameters.ambiguity_threshold == 0.25
    @test parameters.exit_threshold == 0.25
    @test parameters.minimum_separation_ratio == 10.0
    @test parameters.maximum_switches == 10
    entries = close_encounter_regularized_performance_entries()
    @test length(entries) == 8
    @test length(unique(entry.definition.benchmark_id for entry in entries)) == 8
    decoded = ValidationFramework.decode_close_encounter_regularized_benchmark_id(
        :close_encounter_explicit_regularized_tolerance_1e_12)
    @test decoded.method == :explicit
    @test decoded.configuration == configurations[3]
    @test_throws ArgumentError ValidationFramework.decode_close_encounter_regularized_benchmark_id(
        :close_encounter_automatic_regularized_tolerance_1e_9)
    automatic_observation = ValidationFramework.close_encounter_regularized_performance_operation(
        :automatic, configurations[3])()
    @test automatic_observation.solver_statistics.segment_count == 3
    @test automatic_observation.solver_statistics.switch_count == 2
    explicit_observation = ValidationFramework.close_encounter_regularized_performance_operation(
        :explicit, configurations[3])()
    @test explicit_observation.solver_statistics.segment_count == 3
    @test explicit_observation.solver_statistics.switch_count == 2
end

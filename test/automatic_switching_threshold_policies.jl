@testset "AS-2 automatic-switching threshold policies" begin
    @testset "absolute policy preserves legacy parameters" begin
        legacy = AutomaticSwitchingParameters(
            enter_threshold=0.2,
            exit_threshold=0.4,
            ambiguity_threshold=0.3,
            minimum_separation_ratio=2.5,
            maximum_switches=17,
            minimum_time_progress=1e-10,
        )
        policy = AbsoluteSwitchingThresholdPolicy(
            enter_threshold=0.2,
            exit_threshold=0.4,
            ambiguity_threshold=0.3,
        )
        resolved = automatic_switching_thresholds(policy)
        from_policy = AutomaticSwitchingParameters(
            policy;
            minimum_separation_ratio=2.5,
            maximum_switches=17,
            minimum_time_progress=1e-10,
        )

        @test resolved == (
            enter_threshold=0.2,
            exit_threshold=0.4,
            ambiguity_threshold=0.3,
            scale_kind=:absolute,
            reference_scale=1.0,
        )
        @test from_policy.enter_threshold == legacy.enter_threshold
        @test from_policy.exit_threshold == legacy.exit_threshold
        @test from_policy.ambiguity_threshold == legacy.ambiguity_threshold
        @test from_policy.minimum_separation_ratio == legacy.minimum_separation_ratio
        @test from_policy.maximum_switches == legacy.maximum_switches
        @test from_policy.minimum_time_progress == legacy.minimum_time_progress
        @test from_policy.threshold_scale_kind == :absolute
        @test from_policy.threshold_reference_scale == 1.0
    end

    @testset "characteristic-length policy resolves deterministically" begin
        policy = ScaleAwareSwitchingThresholdPolicy(
            characteristic_length=10.0,
            enter_factor=0.02,
            exit_factor=0.04,
            ambiguity_factor=0.03,
        )
        resolved = automatic_switching_thresholds(policy)
        parameters = AutomaticSwitchingParameters(policy)

        @test resolved.enter_threshold == 0.2
        @test resolved.exit_threshold == 0.4
        @test resolved.ambiguity_threshold == 0.3
        @test resolved.scale_kind == :characteristic_length
        @test resolved.reference_scale == 10.0
        @test parameters.enter_threshold == 0.2
        @test parameters.exit_threshold == 0.4
        @test parameters.ambiguity_threshold == 0.3
        @test parameters.threshold_scale_kind == :characteristic_length
        @test parameters.threshold_reference_scale == 10.0
    end

    @testset "equivalent policies preserve decisions" begin
        absolute = AutomaticSwitchingParameters(
            AbsoluteSwitchingThresholdPolicy(
                enter_threshold=0.2,
                exit_threshold=0.4,
                ambiguity_threshold=0.3,
            ),
        )
        scaled = AutomaticSwitchingParameters(
            ScaleAwareSwitchingThresholdPolicy(
                characteristic_length=10.0,
                enter_factor=0.02,
                exit_factor=0.04,
                ambiguity_factor=0.03,
            ),
        )

        entry_observables = PairObservables{Float64}(
            (0.2, 0.4, 1.0),
            (-1.0, 0.0, 0.0),
            (false, false, false),
            (1, 2, 3),
            (1, 2),
            (1, 3),
            2.0,
        )
        exit_observables = PairObservables{Float64}(
            (0.4, 0.8, 1.0),
            (1.0, 0.0, 0.0),
            (false, false, false),
            (1, 2, 3),
            (1, 2),
            (1, 3),
            2.0,
        )

        absolute_entry = automatic_entry_decision(entry_observables, absolute)
        scaled_entry = automatic_entry_decision(entry_observables, scaled)
        @test (scaled_entry.action, scaled_entry.pair, scaled_entry.reason) ==
              (absolute_entry.action, absolute_entry.pair, absolute_entry.reason)
        @test absolute_entry.evidence.scale_kind == :absolute
        @test absolute_entry.evidence.reference_scale == 1.0
        @test scaled_entry.evidence.scale_kind == :characteristic_length
        @test scaled_entry.evidence.reference_scale == 10.0
        @test scaled_entry.evidence.enter_threshold == absolute_entry.evidence.enter_threshold

        absolute_exit = automatic_exit_decision(exit_observables, absolute, (2, 1))
        scaled_exit = automatic_exit_decision(exit_observables, scaled, (2, 1))
        @test (scaled_exit.action, scaled_exit.pair, scaled_exit.reason) ==
              (absolute_exit.action, absolute_exit.pair, absolute_exit.reason)
        @test scaled_exit.evidence.scale_kind == :characteristic_length
        @test scaled_exit.evidence.reference_scale == 10.0
    end

    @testset "policy validation" begin
        @test_throws ArgumentError AbsoluteSwitchingThresholdPolicy(
            enter_threshold=0.0, exit_threshold=0.4,
        )
        @test_throws ArgumentError AbsoluteSwitchingThresholdPolicy(
            enter_threshold=0.4, exit_threshold=0.4,
        )
        @test_throws ArgumentError ScaleAwareSwitchingThresholdPolicy(
            characteristic_length=0.0, enter_factor=0.02, exit_factor=0.04,
        )
        @test_throws ArgumentError ScaleAwareSwitchingThresholdPolicy(
            characteristic_length=1.0, enter_factor=0.04, exit_factor=0.02,
        )
        @test_throws ArgumentError ScaleAwareSwitchingThresholdPolicy(
            characteristic_length=Inf, enter_factor=0.02, exit_factor=0.04,
        )
    end

    @testset "precision-generic scale resolution" begin
        setprecision(BigFloat, 256) do
            policy = ScaleAwareSwitchingThresholdPolicy(
                characteristic_length=big"10",
                enter_factor=big"0.02",
                exit_factor=big"0.04",
                ambiguity_factor=big"0.03",
            )
            parameters = AutomaticSwitchingParameters(policy)
            @test parameters isa AutomaticSwitchingParameters{BigFloat}
            @test parameters.enter_threshold == big"0.2"
            @test parameters.threshold_reference_scale == big"10"
        end
    end
end

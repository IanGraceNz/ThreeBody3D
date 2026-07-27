@testset "AS-3 automatic-switching progress safeguards" begin
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_time_progress=1e-6,
        minimum_separation_excursion=0.15,
    )

    @testset "first switch and first exit remain admissible" begin
        entry_evidence, entry_state = ThreeBody3D._certify_automatic_switching_progress(
            nothing, :entry, (1, 2), 0.8, 0.2, parameters,
        )
        @test entry_evidence.certified
        @test entry_evidence.reason == :progress_certified
        @test isnothing(entry_evidence.previous_kind)
        @test !entry_evidence.same_pair_reentry
        @test entry_state.last_kind == :entry

        exit_evidence, exit_state = ThreeBody3D._certify_automatic_switching_progress(
            entry_state, :exit, (2, 1), 1.4, 0.4, parameters,
        )
        @test exit_evidence.certified
        @test exit_evidence.same_unordered_pair
        @test !exit_evidence.same_pair_reentry
        @test exit_state.last_pair == (1, 2)
        @test exit_state.consecutive_same_pair_switches == 2
    end

    @testset "same-pair re-entry requires configured excursion" begin
        _, entry_state = ThreeBody3D._certify_automatic_switching_progress(
            nothing, :entry, (1, 2), 0.8, 0.2, parameters,
        )
        _, exit_state = ThreeBody3D._certify_automatic_switching_progress(
            entry_state, :exit, (1, 2), 1.4, 0.4, parameters,
        )

        rejected, _ = ThreeBody3D._certify_automatic_switching_progress(
            exit_state, :entry, (2, 1), 1.5, 0.30, parameters,
        )
        @test !rejected.certified
        @test rejected.reason == :insufficient_separation_excursion
        @test rejected.same_pair_reentry
        @test rejected.observed_separation_excursion ≈ 0.10
        @test rejected.required_separation_excursion == 0.15
        @test rejected.time_progress_satisfied
        @test !rejected.separation_excursion_satisfied

        accepted, next_state = ThreeBody3D._certify_automatic_switching_progress(
            exit_state, :entry, (1, 2), 1.6, 0.20, parameters,
        )
        @test accepted.certified
        @test accepted.observed_separation_excursion ≈ 0.20
        @test next_state.consecutive_same_pair_switches == 3
    end

    @testset "physically distinct pair changes are not suppressed" begin
        prior = AutomaticSwitchingProgressState(1.4, :exit, (1, 2), 0.4, 2)
        evidence, state = ThreeBody3D._certify_automatic_switching_progress(
            prior, :entry, (1, 3), 1.5, 0.19, parameters,
        )
        @test evidence.certified
        @test !evidence.same_unordered_pair
        @test !evidence.same_pair_reentry
        @test isnothing(evidence.observed_separation_excursion)
        @test state.consecutive_same_pair_switches == 1
    end

    @testset "zero default preserves existing behaviour" begin
        default_parameters = AutomaticSwitchingParameters(
            enter_threshold=0.2,
            exit_threshold=0.4,
        )
        @test default_parameters.minimum_separation_excursion == 0.0

        prior = AutomaticSwitchingProgressState(1.4, :exit, (1, 2), 0.4, 2)
        evidence, _ = ThreeBody3D._certify_automatic_switching_progress(
            prior, :entry, (1, 2), 1.5, 0.399999, default_parameters,
        )
        @test evidence.certified
        @test evidence.same_pair_reentry
    end

    @testset "time progress and failure evidence" begin
        prior = AutomaticSwitchingProgressState(1.4, :exit, (1, 2), 0.4, 2)
        evidence, _ = ThreeBody3D._certify_automatic_switching_progress(
            prior, :entry, (1, 2), 1.4, 0.2, parameters,
        )
        @test !evidence.certified
        @test evidence.reason == :insufficient_time_progress

        failure = AutomaticSwitchingFailure(
            1.4,
            evidence.reason,
            "Progress certification failed.";
            pair=(1, 2),
            progress_evidence=evidence,
        )
        @test failure.progress_evidence === evidence

        legacy = AutomaticSwitchingFailure(1.0, :legacy, "Legacy failure.")
        @test isnothing(legacy.progress_evidence)
    end

    @testset "validation and precision" begin
        @test_throws ArgumentError AutomaticSwitchingParameters(
            enter_threshold=0.2,
            exit_threshold=0.4,
            minimum_separation_excursion=-eps(),
        )

        setprecision(BigFloat, 256) do
            big_parameters = AutomaticSwitchingParameters(
                enter_threshold=big"0.2",
                exit_threshold=big"0.4",
                minimum_separation_excursion=big"0.15",
            )
            prior = AutomaticSwitchingProgressState(
                big"1.4", :exit, (1, 2), big"0.4", 2,
            )
            evidence, state = ThreeBody3D._certify_automatic_switching_progress(
                prior, :entry, (1, 2), big"1.6", big"0.2", big_parameters,
            )
            @test evidence isa AutomaticSwitchingProgressEvidence{BigFloat}
            @test state isa AutomaticSwitchingProgressState{BigFloat}
            @test evidence.certified
        end
    end
end

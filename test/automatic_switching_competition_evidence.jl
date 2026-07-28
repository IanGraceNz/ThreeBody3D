@testset "AS-4a pair-competition decision evidence" begin
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
    )
    pairs = ((1, 2), (1, 3), (2, 3))

    function competition_observables(
        separations::NTuple{3,T},
        radial_rates::NTuple{3,T};
        collisions::NTuple{3,Bool}=(false, false, false),
    ) where {T<:AbstractFloat}
        ordered = sortperm(1:3; by=index -> (separations[index], index))
        order = (ordered[1], ordered[2], ordered[3])
        smallest = separations[order[1]]
        second_smallest = separations[order[2]]
        isolation_ratio = if iszero(smallest)
            iszero(second_smallest) ? one(T) : T(Inf)
        else
            second_smallest / smallest
        end
        PairObservables{T}(
            separations,
            radial_rates,
            collisions,
            order,
            pairs[order[1]],
            pairs[order[2]],
            isolation_ratio,
        )
    end

    @testset "unique candidate evidence for every pair" begin
        cases = (
            ((0.1, 0.5, 1.0), (-1.0, 0.0, 0.0), (1, 2)),
            ((0.5, 0.1, 1.0), (0.0, -1.0, 0.0), (1, 3)),
            ((0.5, 1.0, 0.1), (0.0, 0.0, -1.0), (2, 3)),
        )
        for (separations, rates, expected_pair) in cases
            decision = automatic_entry_decision(
                competition_observables(separations, rates),
                parameters,
            )
            competition = decision.evidence.competition
            @test decision.action == :enter
            @test competition isa AutomaticSwitchingCompetitionEvidence
            @test competition.closest_pair == expected_pair
            @test competition.candidate_pairs == (expected_pair,)
            @test competition.candidate_is_closest === true
            @test competition.candidate_tied_for_closest === true
            @test competition.crossing_provenance == :algebraic
            @test competition.entry_margins == map(x -> x - 0.2, separations)
        end
    end

    @testset "unique tied candidate is not selected by canonical ordering" begin
        observables = competition_observables(
            (0.1, 0.1, 1.0),
            (0.0, -1.0, 0.0),
        )
        decision = automatic_entry_decision(observables, parameters)
        competition = decision.evidence.competition
        @test decision.action == :failure
        @test decision.reason == :candidate_not_closest
        @test competition.candidate_pairs == ((1, 3),)
        @test competition.candidate_is_closest === false
        @test competition.candidate_tied_for_closest === true
    end

    @testset "simultaneous candidates remain failures" begin
        observables = competition_observables(
            (0.1, 0.15, 1.0),
            (-1.0, -1.0, 0.0),
        )
        decision = automatic_entry_decision(observables, parameters)
        competition = decision.evidence.competition
        @test decision.action == :failure
        @test decision.reason == :simultaneous_entry_candidates
        @test competition.candidate_pairs == ((1, 2), (1, 3))
        @test competition.candidate_is_closest === nothing
        @test competition.candidate_tied_for_closest === nothing
    end

    @testset "exact ties and collision sentinel" begin
        tied = competition_observables(
            (0.1, 0.1, 1.0),
            (-1.0, 0.0, 0.0),
        )
        competition = automatic_entry_decision(tied, parameters).evidence.competition
        @test competition.exact_closest_tie
        @test competition.absolute_separation_gap == 0.0
        @test competition.relative_separation_gap == 0.0
        @test competition.candidate_is_closest === true
        @test competition.candidate_tied_for_closest === true

        collision = competition_observables(
            (0.0, 0.5, 1.0),
            (0.0, 0.0, 0.0);
            collisions=(true, false, false),
        )
        collision_competition = automatic_entry_decision(collision, parameters).evidence.competition
        @test collision_competition.relative_separation_gap === nothing
        @test isinf(collision_competition.isolation_ratio_margin)
    end

    @testset "boundary margins preserve AS-0 equality semantics" begin
        observables = competition_observables(
            (0.15, 0.3, 1.0),
            (-1.0, 0.0, 0.0),
        )
        decision = automatic_entry_decision(observables, parameters)
        competition = decision.evidence.competition
        @test decision.reason == :ambiguous_close_pairs
        @test competition.ambiguity_margin == 0.0
        @test competition.isolation_ratio_margin == 0.0
    end

    @testset "exit evidence records selected-pair margin" begin
        observables = competition_observables(
            (0.4, 1.0, 2.0),
            (1.0, 0.0, 0.0),
        )
        decision = automatic_exit_decision(observables, parameters, (2, 1))
        competition = decision.evidence.competition
        @test decision.action == :exit
        @test competition.exit_margin == 0.0
        @test competition.candidate_pairs == ()
        @test competition.closest_pair == (1, 2)
        @test competition.second_pair == (1, 3)
    end

    @testset "closed provenance validation" begin
        observables = competition_observables(
            (0.1, 0.5, 1.0),
            (-1.0, 0.0, 0.0),
        )
        @test_throws ArgumentError ThreeBody3D._competition_evidence(
            :entry,
            observables,
            parameters;
            candidate_mask=(true, false, false),
            candidate_pair=(1, 2),
            crossing_provenance=:unsupported,
        )
    end

    @testset "decision evidence threads crossing provenance" begin
        observables = competition_observables(
            (0.1, 0.5, 1.0),
            (-1.0, 0.0, 0.0),
        )
        default_evidence = ThreeBody3D._decision_evidence(
            :entry,
            observables,
            parameters;
            candidate_mask=(true, false, false),
            candidate_pair=(1, 2),
        )
        @test default_evidence.competition.crossing_provenance == :algebraic

        entry_evidence = ThreeBody3D._decision_evidence(
            :entry,
            observables,
            parameters;
            candidate_mask=(true, false, false),
            candidate_pair=(1, 2),
            crossing_provenance=:certified_cartesian_entry,
        )
        @test entry_evidence.competition.crossing_provenance ==
              :certified_cartesian_entry

        exit_evidence = ThreeBody3D._decision_evidence(
            :exit,
            observables,
            parameters;
            selected_pair=(1, 2),
            selected_index=1,
            crossing_provenance=:certified_regularized_exit,
        )
        @test exit_evidence.competition.crossing_provenance ==
              :certified_regularized_exit

        @test_throws ArgumentError ThreeBody3D._decision_evidence(
            :entry,
            observables,
            parameters;
            crossing_provenance=:unsupported,
        )
    end

    @testset "precision-generic competition evidence" begin
        setprecision(BigFloat, 256) do
            big_parameters = AutomaticSwitchingParameters(
                enter_threshold=big"0.2",
                exit_threshold=big"0.4",
                ambiguity_threshold=big"0.3",
                minimum_separation_ratio=big"2",
            )
            observables = competition_observables(
                (big"0.1", big"0.5", big"1.0"),
                (big"-1.0", big"0.0", big"0.0"),
            )
            competition = automatic_entry_decision(
                observables,
                big_parameters,
            ).evidence.competition
            @test competition isa AutomaticSwitchingCompetitionEvidence{BigFloat}
            @test competition.absolute_separation_gap == big"0.4"
            @test competition.relative_separation_gap == big"4"
            @test competition.entry_margins == (big"-0.1", big"0.3", big"0.8")
        end
    end
end

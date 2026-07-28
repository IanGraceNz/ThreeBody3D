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

        safety_evidence = ThreeBody3D._decision_evidence(
            :exit,
            observables,
            parameters;
            candidate_pair=(1, 3),
            selected_pair=(1, 2),
            selected_index=1,
            crossing_provenance=:certified_nonselected_pair_crossing,
        )
        @test safety_evidence.candidate_pair == (1, 3)
        @test safety_evidence.selected_pair == (1, 2)
        @test safety_evidence.competition.crossing_provenance ==
              :certified_nonselected_pair_crossing

        @test_throws ArgumentError ThreeBody3D._decision_evidence(
            :entry,
            observables,
            parameters;
            crossing_provenance=:unsupported,
        )
    end

    @testset "entry decisions thread crossing provenance" begin
        observables = competition_observables(
            (0.1, 0.5, 1.0),
            (-1.0, 0.0, 0.0),
        )
        decision = automatic_entry_decision(
            observables,
            parameters;
            crossing_provenance=:certified_cartesian_entry,
        )
        @test decision.action == :enter
        @test decision.evidence.competition.crossing_provenance ==
              :certified_cartesian_entry

        @test_throws ArgumentError automatic_entry_decision(
            observables,
            parameters;
            crossing_provenance=:unsupported,
        )
    end

    @testset "certified entry preserves state-derived competition" begin
        observables = competition_observables(
            (0.1, 0.5, 1.0),
            (-1.0, 0.0, 0.0),
        )
        algebraic = automatic_entry_decision(observables, parameters)
        certified = automatic_entry_decision(
            observables,
            parameters;
            crossing_provenance=:certified_cartesian_entry,
        )
        @test certified.action == algebraic.action
        @test certified.reason == algebraic.reason
        @test certified.pair == algebraic.pair
        for name in propertynames(algebraic.evidence)
            name === :competition && continue
            @test getproperty(certified.evidence, name) ==
                  getproperty(algebraic.evidence, name)
        end
        for name in propertynames(algebraic.evidence.competition)
            name === :crossing_provenance && continue
            @test getproperty(certified.evidence.competition, name) ==
                  getproperty(algebraic.evidence.competition, name)
        end
        @test algebraic.evidence.competition.crossing_provenance == :algebraic
        @test certified.evidence.competition.crossing_provenance ==
              :certified_cartesian_entry

        outside_threshold = nextfloat(parameters.enter_threshold)
        outside = competition_observables(
            (outside_threshold, 0.5, 1.0),
            (-1.0, 0.0, 0.0),
        )
        outside_decision = ThreeBody3D._certified_entry_decision(
            outside,
            parameters,
            (1, 2),
        )
        @test outside_decision.action == :enter
        @test outside_decision.reason == :certified_inward_threshold_crossing
        @test outside_decision.pair == (1, 2)
        @test outside_decision.evidence !== nothing
        @test outside_decision.evidence.competition.crossing_provenance ==
              :certified_cartesian_entry
        @test outside_decision.evidence.competition.entry_margins[1] ==
              outside_threshold - parameters.enter_threshold

        setprecision(BigFloat, 256) do
            big_parameters = AutomaticSwitchingParameters(
                enter_threshold=big"0.2",
                exit_threshold=big"0.4",
                ambiguity_threshold=big"0.3",
                minimum_separation_ratio=big"2",
            )
            big_outside = nextfloat(big_parameters.enter_threshold)
            big_observables = competition_observables(
                (big_outside, big"0.5", big"1.0"),
                (big"-1.0", big"0.0", big"0.0"),
            )
            big_decision = ThreeBody3D._certified_entry_decision(
                big_observables,
                big_parameters,
                (1, 2),
            )
            @test big_decision.action == :enter
            @test big_decision.evidence isa
                  AutomaticSwitchingDecisionEvidence{BigFloat}
            @test big_decision.evidence.competition.crossing_provenance ==
                  :certified_cartesian_entry
            @test big_decision.evidence.competition.entry_margins[1] ==
                  big_outside - big_parameters.enter_threshold
        end
    end

    @testset "certified entry does not override state validity" begin
        outside_threshold = nextfloat(parameters.enter_threshold)
        cases = (
            (
                competition_observables(
                    (outside_threshold, 0.1, 1.0),
                    (-1.0, 0.0, 0.0),
                ),
                :candidate_not_closest,
                (1, 2),
            ),
            (
                competition_observables(
                    (outside_threshold, 0.3, 1.0),
                    (-1.0, 0.0, 0.0),
                ),
                :ambiguous_close_pairs,
                (1, 2),
            ),
            (
                competition_observables(
                    (outside_threshold, 0.39, 1.0),
                    (-1.0, 0.0, 0.0),
                ),
                :insufficient_pair_isolation,
                (1, 2),
            ),
            (
                competition_observables(
                    (0.0, 0.5, 1.0),
                    (0.0, 0.0, 0.0);
                    collisions=(true, false, false),
                ),
                :collision_state,
                (1, 2),
            ),
            (
                competition_observables(
                    (outside_threshold, 0.5, 1.0),
                    (0.0, 0.0, 0.0),
                ),
                :entry_condition_not_met,
                (1, 2),
            ),
            (
                competition_observables(
                    (0.1, 0.15, 1.0),
                    (-1.0, -1.0, 0.0),
                ),
                :simultaneous_entry_candidates,
                (1, 2),
            ),
        )
        for (observables, reason, pair) in cases
            decision = ThreeBody3D._certified_entry_decision(
                observables,
                parameters,
                pair,
            )
            @test decision.action == :failure
            @test decision.reason == reason
            @test decision.evidence !== nothing
            @test decision.evidence.competition.crossing_provenance ==
                  :certified_cartesian_entry
        end
    end

    @testset "exit decisions thread crossing provenance" begin
        cases = (
            competition_observables((0.4, 1.0, 2.0), (1.0, 0.0, 0.0)),
            competition_observables((0.3, 1.0, 2.0), (1.0, 0.0, 0.0)),
            competition_observables((0.5, 0.45, 1.0), (1.0, 0.0, 0.0)),
            competition_observables((0.4, 0.3, 1.0), (1.0, 0.0, 0.0)),
            competition_observables(
                (0.0, 1.0, 2.0),
                (0.0, 0.0, 0.0);
                collisions=(true, false, false),
            ),
            competition_observables(
                (0.4, 0.0, 2.0),
                (1.0, 0.0, 0.0);
                collisions=(false, true, false),
            ),
        )
        for observables in cases
            algebraic = automatic_exit_decision(observables, parameters, (1, 2))
            certified = automatic_exit_decision(
                observables,
                parameters,
                (1, 2);
                crossing_provenance=:certified_regularized_exit,
            )
            @test certified.action == algebraic.action
            @test certified.reason == algebraic.reason
            @test certified.pair == algebraic.pair
            for name in propertynames(algebraic.evidence)
                name === :competition && continue
                @test getproperty(certified.evidence, name) ==
                      getproperty(algebraic.evidence, name)
            end
            for name in propertynames(algebraic.evidence.competition)
                name === :crossing_provenance && continue
                @test getproperty(certified.evidence.competition, name) ==
                      getproperty(algebraic.evidence.competition, name)
            end
            @test algebraic.evidence.competition.crossing_provenance == :algebraic
            @test certified.evidence.competition.crossing_provenance ==
                  :certified_regularized_exit
        end

        @test_throws ArgumentError automatic_exit_decision(
            first(cases),
            parameters,
            (1, 2);
            crossing_provenance=:unsupported,
        )
    end

    @testset "certified exit preserves state-derived competition" begin
        inside_threshold = prevfloat(parameters.exit_threshold)
        observables = competition_observables(
            (inside_threshold, 1.0, 2.0),
            (1.0, 0.0, 0.0),
        )
        algebraic = automatic_exit_decision(observables, parameters, (1, 2))
        certified = ThreeBody3D._certified_exit_decision(
            observables,
            parameters,
            (1, 2),
        )
        @test algebraic.action == :none
        @test algebraic.reason == :exit_condition_not_met
        @test certified.action == :exit
        @test certified.reason == :certified_outward_threshold_crossing
        @test certified.pair == (1, 2)
        @test certified.evidence.competition.crossing_provenance ==
              :certified_regularized_exit
        @test certified.evidence.competition.exit_margin ==
              inside_threshold - parameters.exit_threshold
        @test certified.evidence.competition.closest_pair == (1, 2)

        lost = competition_observables(
            (inside_threshold, 0.3, 2.0),
            (1.0, 0.0, 0.0),
        )
        lost_decision = ThreeBody3D._certified_exit_decision(
            lost,
            parameters,
            (1, 2),
        )
        @test lost_decision.action == :failure
        @test lost_decision.reason == :selected_pair_lost
        @test lost_decision.evidence.competition.crossing_provenance ==
              :certified_regularized_exit

        setprecision(BigFloat, 256) do
            big_parameters = AutomaticSwitchingParameters(
                enter_threshold=big"0.2",
                exit_threshold=big"0.4",
                ambiguity_threshold=big"0.3",
                minimum_separation_ratio=big"2",
            )
            big_inside = prevfloat(big_parameters.exit_threshold)
            big_observables = competition_observables(
                (big_inside, big"1.0", big"2.0"),
                (big"1.0", big"0.0", big"0.0"),
            )
            big_decision = ThreeBody3D._certified_exit_decision(
                big_observables,
                big_parameters,
                (1, 2),
            )
            @test big_decision.action == :exit
            @test big_decision.evidence isa
                  AutomaticSwitchingDecisionEvidence{BigFloat}
            @test big_decision.evidence.competition.crossing_provenance ==
                  :certified_regularized_exit
            @test big_decision.evidence.competition.exit_margin ==
                  big_inside - big_parameters.exit_threshold
        end
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

@testset "AS-0 automatic-switching policy inventory" begin
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
    )
    pairs = ((1, 2), (1, 3), (2, 3))

    function policy_observables(
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

    @testset "deterministic observable ordering" begin
        tied = policy_observables((1.0, 1.0, 1.0), (0.0, 0.0, 0.0))
        @test tied.order == (1, 2, 3)
        @test tied.closest_pair == (1, 2)
        @test tied.second_closest_pair == (1, 3)
        @test tied.isolation_ratio == 1.0

        isolated_collision = policy_observables(
            (0.0, 1.0, 2.0), (0.0, 0.0, 0.0);
            collisions=(true, false, false),
        )
        @test isinf(isolated_collision.isolation_ratio)

        multiple_collision = policy_observables(
            (0.0, 0.0, 1.0), (0.0, 0.0, 0.0);
            collisions=(true, true, false),
        )
        @test multiple_collision.isolation_ratio == 1.0
    end

    @testset "entry matrix for every canonical pair" begin
        for candidate_index in 1:3
            separations = ntuple(i -> i == candidate_index ? 0.2 : 1.0 + i, 3)
            rates = ntuple(i -> i == candidate_index ? -1.0 : 0.0, 3)
            decision = automatic_entry_decision(
                policy_observables(separations, rates), parameters,
            )
            @test decision.action == :enter
            @test decision.pair == pairs[candidate_index]
            @test decision.reason == :unique_approaching_pair
        end
    end

    entry_cases = [
        (
            name="outside entry threshold",
            observables=policy_observables((0.2000000001, 2.0, 2.1), (-1.0, 0.0, 0.0)),
            action=:none,
            pair=nothing,
            reason=:no_entry_candidate,
        ),
        (
            name="zero radial rate",
            observables=policy_observables((0.2, 2.0, 2.1), (0.0, 0.0, 0.0)),
            action=:none,
            pair=nothing,
            reason=:no_entry_candidate,
        ),
        (
            name="simultaneous candidates",
            observables=policy_observables((0.1, 0.2, 1.0), (-1.0, -1.0, 0.0)),
            action=:failure,
            pair=nothing,
            reason=:simultaneous_entry_candidates,
        ),
        (
            name="candidate is not closest",
            observables=policy_observables((0.1, 0.2, 1.0), (1.0, -1.0, 0.0)),
            action=:failure,
            pair=(1, 3),
            reason=:candidate_not_closest,
        ),
        (
            name="ambiguity boundary is inclusive",
            observables=policy_observables((0.1, 0.3, 1.0), (-1.0, 0.0, 0.0)),
            action=:failure,
            pair=(1, 2),
            reason=:ambiguous_close_pairs,
        ),
        (
            name="isolation below minimum",
            observables=policy_observables((0.2, 0.399, 1.0), (-1.0, 0.0, 0.0)),
            action=:failure,
            pair=(1, 2),
            reason=:insufficient_pair_isolation,
        ),
        (
            name="isolation equality is accepted",
            observables=policy_observables((0.2, 0.4, 1.0), (-1.0, 0.0, 0.0)),
            action=:enter,
            pair=(1, 2),
            reason=:unique_approaching_pair,
        ),
        (
            name="single collision",
            observables=policy_observables(
                (0.0, 1.0, 2.0), (0.0, 0.0, 0.0);
                collisions=(true, false, false),
            ),
            action=:failure,
            pair=(1, 2),
            reason=:collision_state,
        ),
        (
            name="triple collision",
            observables=policy_observables(
                (0.0, 0.0, 0.0), (0.0, 0.0, 0.0);
                collisions=(true, true, true),
            ),
            action=:failure,
            pair=(1, 2),
            reason=:collision_state,
        ),
    ]

    @testset "entry reason inventory" begin
        for case in entry_cases
            decision = automatic_entry_decision(case.observables, parameters)
            @test decision.action == case.action
            @test decision.pair == case.pair
            @test decision.reason == case.reason
        end
    end

    @testset "exit matrix for every pair orientation" begin
        for selected_index in 1:3
            separations = ntuple(i -> i == selected_index ? 0.4 : 1.0 + i, 3)
            rates = ntuple(i -> i == selected_index ? 1.0 : 0.0, 3)
            observables = policy_observables(separations, rates)
            i, j = pairs[selected_index]
            for selected_pair in ((i, j), (j, i))
                decision = automatic_exit_decision(
                    observables, parameters, selected_pair,
                )
                @test decision.action == :exit
                @test decision.pair == selected_pair
                @test decision.reason == :isolated_receding_pair
            end
        end
    end

    exit_cases = [
        (
            name="below exit threshold",
            observables=policy_observables((0.3999999999, 2.0, 2.1), (1.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:none,
            reason=:exit_condition_not_met,
        ),
        (
            name="zero radial rate",
            observables=policy_observables((0.4, 2.0, 2.1), (0.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:none,
            reason=:exit_condition_not_met,
        ),
        (
            name="approaching above exit threshold",
            observables=policy_observables((0.5, 2.0, 2.1), (-1.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:none,
            reason=:exit_condition_not_met,
        ),
        (
            name="selected collision continues",
            observables=policy_observables(
                (0.0, 1.0, 2.0), (0.0, 0.0, 0.0);
                collisions=(true, false, false),
            ),
            pair=(2, 1),
            action=:none,
            reason=:selected_pair_collision,
        ),
        (
            name="nonselected collision fails first",
            observables=policy_observables(
                (0.0, 0.0, 2.0), (0.0, 0.0, 0.0);
                collisions=(true, true, false),
            ),
            pair=(1, 2),
            action=:failure,
            reason=:nonselected_pair_collision,
        ),
        (
            name="selected pair hierarchy lost",
            observables=policy_observables((0.5, 0.45, 1.0), (1.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:failure,
            reason=:selected_pair_lost,
        ),
        (
            name="exit ambiguity boundary is inclusive",
            observables=policy_observables((0.2, 0.3, 1.0), (1.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:failure,
            reason=:ambiguous_close_pairs,
        ),
        (
            name="exit isolation below minimum",
            observables=policy_observables((0.2, 0.399, 1.0), (1.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:failure,
            reason=:insufficient_pair_isolation,
        ),
        (
            name="exit isolation equality is accepted",
            observables=policy_observables((0.4, 0.8, 1.0), (1.0, 0.0, 0.0)),
            pair=(1, 2),
            action=:exit,
            reason=:isolated_receding_pair,
        ),
    ]

    @testset "exit reason inventory" begin
        for case in exit_cases
            decision = automatic_exit_decision(
                case.observables, parameters, case.pair,
            )
            @test decision.action == case.action
            @test decision.pair == case.pair
            @test decision.reason == case.reason
        end
    end

    @testset "precision-generic boundaries" begin
        setprecision(BigFloat, 256) do
            big_parameters = AutomaticSwitchingParameters(
                enter_threshold=big"0.2",
                exit_threshold=big"0.4",
                ambiguity_threshold=big"0.3",
                minimum_separation_ratio=big"2",
            )
            entry = automatic_entry_decision(
                policy_observables(
                    (big"0.2", big"0.4", big"1.0"),
                    (big"-1.0", big"0.0", big"0.0"),
                ),
                big_parameters,
            )
            @test entry.action == :enter
            @test entry.reason == :unique_approaching_pair

            exit = automatic_exit_decision(
                policy_observables(
                    (big"0.4", big"0.8", big"1.0"),
                    (big"1.0", big"0.0", big"0.0"),
                ),
                big_parameters,
                (2, 1),
            )
            @test exit.action == :exit
            @test exit.pair == (2, 1)
        end
    end
end

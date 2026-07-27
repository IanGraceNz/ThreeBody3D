@testset "AS-1 automatic-switching decision evidence" begin
    parameters = AutomaticSwitchingParameters(
        enter_threshold=0.2,
        exit_threshold=0.4,
        ambiguity_threshold=0.3,
        minimum_separation_ratio=2.0,
    )
    pairs = ((1, 2), (1, 3), (2, 3))

    function evidence_observables(
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

    function assert_common_evidence(evidence, observables, expected_phase)
        @test evidence isa AutomaticSwitchingDecisionEvidence
        @test evidence.phase == expected_phase
        @test evidence.scale_kind == :absolute
        @test evidence.separations == observables.separations
        @test evidence.radial_rates == observables.radial_rates
        @test evidence.collisions == observables.collisions
        @test evidence.order == observables.order
        @test evidence.isolation_ratio == observables.isolation_ratio
        @test evidence.enter_threshold == parameters.enter_threshold
        @test evidence.exit_threshold == parameters.exit_threshold
        @test evidence.ambiguity_threshold == parameters.ambiguity_threshold
        @test evidence.minimum_separation_ratio == parameters.minimum_separation_ratio
        @test evidence.second_index == observables.order[2]
    end

    entry_cases = [
        evidence_observables((0.5, 1.0, 2.0), (-1.0, 0.0, 0.0)),
        evidence_observables((0.2, 1.0, 2.0), (-1.0, 0.0, 0.0)),
        evidence_observables((0.1, 0.2, 1.0), (-1.0, -1.0, 0.0)),
        evidence_observables((0.1, 0.2, 1.0), (1.0, -1.0, 0.0)),
        evidence_observables((0.1, 0.3, 1.0), (-1.0, 0.0, 0.0)),
        evidence_observables((0.2, 0.399, 1.0), (-1.0, 0.0, 0.0)),
        evidence_observables(
            (0.0, 1.0, 2.0), (0.0, 0.0, 0.0);
            collisions=(true, false, false),
        ),
    ]

    @testset "entry outcomes retain complete evidence" begin
        for observables in entry_cases
            decision = automatic_entry_decision(observables, parameters)
            evidence = decision.evidence
            assert_common_evidence(evidence, observables, :entry)

            expected_mask = ntuple(3) do index
                observables.separations[index] <= parameters.enter_threshold &&
                    observables.radial_rates[index] < 0
            end
            @test evidence.candidate_mask == expected_mask
            @test evidence.candidate_count == count(identity, expected_mask)
            @test evidence.selected_pair === nothing
            @test evidence.selected_index === nothing

            candidate_indices = findall(identity, expected_mask)
            expected_pair = length(candidate_indices) == 1 ?
                pairs[only(candidate_indices)] : nothing
            @test evidence.candidate_pair == expected_pair
        end
    end

    exit_cases = [
        (evidence_observables((0.4, 1.0, 2.0), (1.0, 0.0, 0.0)), (1, 2)),
        (evidence_observables((0.3, 1.0, 2.0), (1.0, 0.0, 0.0)), (2, 1)),
        (evidence_observables((0.5, 0.45, 1.0), (1.0, 0.0, 0.0)), (1, 2)),
        (
            evidence_observables(
                (0.0, 0.0, 2.0), (0.0, 0.0, 0.0);
                collisions=(true, true, false),
            ),
            (1, 2),
        ),
    ]

    @testset "exit outcomes retain selected-pair evidence" begin
        for (observables, selected_pair) in exit_cases
            decision = automatic_exit_decision(observables, parameters, selected_pair)
            evidence = decision.evidence
            assert_common_evidence(evidence, observables, :exit)
            @test evidence.candidate_mask == (false, false, false)
            @test evidence.candidate_count == 0
            @test evidence.candidate_pair === nothing
            @test evidence.selected_pair == selected_pair
            canonical_pair = selected_pair[1] < selected_pair[2] ?
                selected_pair : reverse(selected_pair)
            @test evidence.selected_index == findfirst(==(canonical_pair), pairs)
        end
    end

    @testset "legacy constructor remains source compatible" begin
        decision = AutomaticSwitchingDecision(:none, nothing, :manual_result)
        @test decision.action == :none
        @test decision.reason == :manual_result
        @test decision.evidence === nothing
    end

    @testset "precision-generic evidence" begin
        setprecision(BigFloat, 256) do
            big_parameters = AutomaticSwitchingParameters(
                enter_threshold=big"0.2",
                exit_threshold=big"0.4",
                ambiguity_threshold=big"0.3",
                minimum_separation_ratio=big"2",
            )
            observables = evidence_observables(
                (big"0.2", big"0.4", big"1.0"),
                (big"-1.0", big"0.0", big"0.0"),
            )
            evidence = automatic_entry_decision(observables, big_parameters).evidence
            @test evidence isa AutomaticSwitchingDecisionEvidence{BigFloat}
            @test evidence.enter_threshold == big"0.2"
            @test evidence.candidate_mask == (true, false, false)
        end
    end
end

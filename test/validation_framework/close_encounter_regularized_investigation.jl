function synthetic_regularized_evidence(method=:automatic, tolerance=1e-12)
    setprecision(BigFloat, 256) do
        boundaries = ValidationFramework.CloseEncounterReferenceBoundaries(
            parse(BigFloat, "0.7"), parse(BigFloat, "0.1"), parse(BigFloat, "0"),
            parse(BigFloat, "0.8"), parse(BigFloat, "0.0001"), parse(BigFloat, "0"),
            parse(BigFloat, "0.9"), parse(BigFloat, "0.25"), parse(BigFloat, "0"))
        transition(time) = ValidationFramework.CloseEncounterTransitionEvidence((
            physical_time=time, pair=(1, 2), state_residual=1e-15,
            position_residual=2e-15, velocity_residual=3e-15, energy_jump=4e-15,
            momentum_jump=5e-15, angular_momentum_jump=6e-15,
            center_of_mass_jump=7e-15, center_of_mass_velocity_jump=8e-15))
        errors = (maximum_position=1e-8, maximum_velocity=2e-8,
            maximum_full_state=3e-8, maximum_combined=4e-8,
            final_position=5e-9, final_velocity=6e-9,
            final_full_state=7e-9, final_combined=8e-9)
        dense = (time=0.8, separation=1e-4, radial_numerator=0.0,
            time_error=1e-12, separation_error=2e-12)
        conservation = (maximum_relative_energy_drift=1e-13,
            maximum_momentum_drift=2e-13, maximum_angular_momentum_drift=3e-13,
            maximum_com_residual=4e-13, minimum_separation=1e-4)
        work = (saved_states=14, accepted_steps=11, rejected_steps=2, rhs_evaluations=42)
        reference = ValidationFramework.CloseEncounterMethodReferenceEvidence(method,
            boundaries, errors, dense, conservation, work, method == :automatic ? 3 : 3,
            2, (transition(0.7), transition(0.9)))
        entry_time, exit_time = 0.7, 0.9
        entry_difference = BigFloat(entry_time) - boundaries.entry_time
        exit_difference = BigFloat(exit_time) - boundaries.exit_time
        events = ValidationFramework.CloseEncounterAutomaticEventEvidence(entry_time, exit_time,
            boundaries.entry_time, boundaries.exit_time, entry_difference,
            abs(entry_difference), exit_difference, abs(exit_difference), 0.1, 0.0,
            0.25, 0.0, -1.0, 1.0)
        locations = (:entry, :periapsis, :exit, :final)
        times = BigFloat[BigFloat(entry_time), boundaries.periapsis_time,
            BigFloat(exit_time), BigFloat(1.6)]
        samples = ntuple(4) do index
            difference = (pair_position=index * 1e-12,
                pair_velocity=index * 2e-12, full_state=index * 3e-12)
            ValidationFramework.CloseEncounterMethodDifferenceSample(
                locations[index], times[index], difference)
        end
        epochs = Float64[t for t in ValidationFramework.close_encounter_sample_times((0.0, 1.6))
            if entry_time <= t <= exit_time]
        append!(epochs, [entry_time, Float64(boundaries.periapsis_time), exit_time])
        sort!(unique!(epochs))
        comparison = ValidationFramework.CloseEncounterAutomaticExplicitComparisonEvidence(
            (entry_time, exit_time), samples,
            (pair_position=5e-12, pair_velocity=8e-12, full_state=12e-12), length(epochs))
        automatic_endpoint = ValidationFramework.CloseEncounterMethodFictitiousEndpointEvidence(
            :automatic, exit_time, 0.81, exit_time, 0.0)
        explicit_time = exit_time + 1e-14
        explicit_endpoint = ValidationFramework.CloseEncounterMethodFictitiousEndpointEvidence(
            :explicit, exit_time, 0.82, explicit_time, explicit_time - exit_time)
        endpoints = ValidationFramework.CloseEncounterMatchedEndpointEvidence(
            automatic_endpoint, explicit_endpoint, 0.82 - 0.81)
        configuration = close_encounter_regularized_tolerance_configuration(tolerance)
        ValidationFramework.CloseEncounterRegularizedPointEvidence(method, configuration,
            boundaries, (entry_time, exit_time), reference, events, comparison, endpoints)
    end
end

function synthetic_regularized_method_evidence(method=:automatic, tolerance=1e-12)
    point = synthetic_regularized_evidence(method, tolerance)
    states = ntuple(length(ValidationFramework.close_encounter_sample_times((0.0, 1.6)))) do _
        zeros(18)
    end
    endpoint = method == :automatic ? point.fictitious_endpoints.automatic :
        point.fictitious_endpoints.explicit
    propagation = ValidationFramework.CloseEncounterRegularizedPropagationEvidence(
        point.configuration, method, point.boundaries, point.automatic_interval, 1.6,
        point.event_evidence, point.method_reference.transitions, states,
        point.method_reference.work, point.method_reference.segment_count,
        point.method_reference.switch_count)
    ValidationFramework.CloseEncounterRegularizedMethodEvidence(
        propagation, point.method_reference, endpoint)
end

function synthetic_regularized_for_reference(method, tolerance, reference)
    setprecision(BigFloat, 256) do
        boundaries = reference.boundaries
        entry_time = Float64(boundaries.entry_time); exit_time = Float64(boundaries.exit_time)
        entry_difference = BigFloat(entry_time) - boundaries.entry_time
        exit_difference = BigFloat(exit_time) - boundaries.exit_time
        event = ValidationFramework.CloseEncounterAutomaticEventEvidence(entry_time,
            exit_time, boundaries.entry_time, boundaries.exit_time, entry_difference,
            abs(entry_difference), exit_difference, abs(exit_difference), 0.1, 0.0,
            0.25, 0.0, -1.0, 1.0)
        transition(time) = ValidationFramework.CloseEncounterTransitionEvidence((
            physical_time=time, pair=(1, 2), state_residual=1e-15,
            position_residual=2e-15, velocity_residual=3e-15, energy_jump=4e-15,
            momentum_jump=5e-15, angular_momentum_jump=6e-15,
            center_of_mass_jump=7e-15, center_of_mass_velocity_jump=8e-15))
        transitions = (transition(entry_time), transition(exit_time))
        errors = (maximum_position=1e-8, maximum_velocity=2e-8,
            maximum_full_state=3e-8, maximum_combined=4e-8,
            final_position=5e-9, final_velocity=6e-9,
            final_full_state=7e-9, final_combined=8e-9)
        dense = (time=Float64(boundaries.periapsis_time), separation=1e-4,
            radial_numerator=0.0, time_error=1e-12, separation_error=2e-12)
        conservation = (maximum_relative_energy_drift=1e-13,
            maximum_momentum_drift=2e-13, maximum_angular_momentum_drift=3e-13,
            maximum_com_residual=4e-13, minimum_separation=1e-4)
        work = (saved_states=14, accepted_steps=11, rejected_steps=2, rhs_evaluations=42)
        configuration = close_encounter_regularized_tolerance_configuration(tolerance)
        reference_evidence = ValidationFramework.CloseEncounterMethodReferenceEvidence(
            method, boundaries, errors, dense, conservation, work, 3, 2, transitions)
        states = ntuple(length(ValidationFramework.close_encounter_sample_times((0.0, 1.6)))) do _
            zeros(18)
        end
        propagation = ValidationFramework.CloseEncounterRegularizedPropagationEvidence(
            configuration, method, boundaries, (entry_time, exit_time), 1.6,
            event, transitions, states, work, 3, 2)
        s = method == :automatic ? 0.81 : 0.82
        physical_time = method == :automatic ? exit_time : exit_time + 1e-14
        endpoint = ValidationFramework.CloseEncounterMethodFictitiousEndpointEvidence(
            method, exit_time, s, physical_time, physical_time - exit_time)
        method_evidence = ValidationFramework.CloseEncounterRegularizedMethodEvidence(
            propagation, reference_evidence, endpoint)
        times = (BigFloat(entry_time), boundaries.periapsis_time,
            BigFloat(exit_time), BigFloat(1.6))
        samples = ntuple(4) do index
            ValidationFramework.CloseEncounterMethodDifferenceSample(
                (:entry, :periapsis, :exit, :final)[index], times[index],
                (pair_position=index * 1e-12, pair_velocity=index * 2e-12,
                    full_state=index * 3e-12))
        end
        epochs = Float64[t for t in ValidationFramework.close_encounter_sample_times((0.0, 1.6))
            if entry_time <= t <= exit_time]
        append!(epochs, [entry_time, Float64(boundaries.periapsis_time), exit_time]); sort!(unique!(epochs))
        comparison = ValidationFramework.CloseEncounterAutomaticExplicitComparisonEvidence(
            (entry_time, exit_time), samples,
            (pair_position=5e-12, pair_velocity=8e-12, full_state=12e-12), length(epochs))
        (method=method_evidence, comparison, event)
    end
end

@testset "Close-encounter regularised investigation evidence" begin
    automatic = synthetic_regularized_evidence(:automatic)
    explicit = synthetic_regularized_evidence(:explicit)
    @test map(x -> x.location, automatic.comparison.samples) ==
        (:entry, :periapsis, :exit, :final)
    @test automatic.comparison === automatic.comparison
    @test automatic.boundaries.precision_bits == 256
    @test precision(automatic.boundaries.periapsis_time) == 256
    @test automatic.automatic_interval == explicit.automatic_interval
    @test automatic.event_evidence.entry_radial_rate < 0
    @test automatic.event_evidence.exit_radial_rate > 0
    @test automatic.comparison.comparison_epoch_count == 101
    @test automatic.comparison.maximum_full_state_difference == 12e-12
    @test length(automatic.method_reference.transitions) == 2
    @test automatic.method_reference.work.rhs_evaluations == 42
    @test_throws ArgumentError ValidationFramework.CloseEncounterMethodDifferenceSample(
        :wrong, automatic.boundaries.periapsis_time,
        (pair_position=0.0, pair_velocity=0.0, full_state=0.0))
    automatic_method = synthetic_regularized_method_evidence(:automatic)
    propagation = automatic_method.propagation
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPropagationEvidence(
        propagation.configuration, :automatic, propagation.boundaries,
        propagation.automatic_interval, propagation.achieved_final_time,
        propagation.event_evidence, propagation.transitions,
        propagation.sampled_states, propagation.work, -1, 2)

    definition = ValidationFramework.close_encounter_regularized_investigation_definition(:automatic)
    metrics = Tuple(ValidationMetric(id, String(id), 0.0)
        for id in definition.required_metric_ids)
    point = InvestigationMeasurementPoint(:regularized_tolerance_1e_12, definition,
        ValidationFramework._close_regularized_validation_configuration(
            automatic.configuration, :automatic),
        ValidationParameter(:regularized_tolerance, 1e-12),
        current_validation_environment(), ExecutionOutcome(actual_completed; exit_code=0),
        metrics; supporting_evidence=automatic)
    series = InvestigationMeasurementSeries(definition.family_id, definition.title,
        definition.description, definition, (point,))
    first_text = investigation_series_report_text(series)
    restored = read_investigation_series(IOBuffer(first_text))
    second_text = investigation_series_report_text(restored)
    @test first_text == second_text
    restored_evidence = only(restored.points).supporting_evidence
    @test restored_evidence.method == :automatic
    @test precision(restored_evidence.boundaries.entry_time) == 256
    @test restored_evidence.automatic_interval == (0.7, 0.9)
    @test map(x -> x.location, restored_evidence.comparison.samples) ==
        (:entry, :periapsis, :exit, :final)
    malformed = replace(first_text,
        "kind = \"close_encounter_regularized_tolerance\"" => "kind = \"unsupported\"";
        count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(malformed))
end


@testset "Close-encounter regularised staged attempts" begin
    reference = synthetic_close_reference()
    configuration = close_encounter_regularized_tolerance_configuration(1e-12)
    automatic_fixture = synthetic_regularized_for_reference(:automatic, 1e-12, reference)
    explicit_fixture = synthetic_regularized_for_reference(:explicit, 1e-12, reference)
    automatic = automatic_fixture.method
    explicit = explicit_fixture.method
    point = (event_evidence=automatic_fixture.event,
        comparison=automatic_fixture.comparison,
        fictitious_endpoints=ValidationFramework.CloseEncounterMatchedEndpointEvidence(
            automatic.endpoint, explicit.endpoint,
            explicit.endpoint.terminal_fictitious_time - automatic.endpoint.terminal_fictitious_time))
    common = (interval_runner=_ -> (0.7, 0.9), event_runner=_ -> (nothing, nothing),
        event_evidence_runner=(_, _, _) -> point.event_evidence,
        automatic_propagation_facts_runner=(args...; kwargs...) ->
            (facts=automatic.propagation.facts, transition_failure=nothing),
        explicit_propagation_facts_runner=(args...; kwargs...) ->
            (facts=explicit.propagation.facts, transition_failure=nothing),
        automatic_propagation_evidence_runner=(args...) -> automatic.propagation,
        explicit_propagation_evidence_runner=(args...) -> explicit.propagation,
        automatic_method_measurement_runner=(propagation, args...) -> automatic.reference,
        explicit_method_measurement_runner=(propagation, args...) -> explicit.reference,
        automatic_endpoint_measurement_runner=(args...) -> automatic.endpoint,
        explicit_endpoint_measurement_runner=(args...) -> explicit.endpoint,
        comparison_runner=(args...) -> point.comparison,
        matched_endpoint_runner=(args...) -> point.fictitious_endpoints)
    successful = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit, common...)
    @test successful.automatic_execution.actual == actual_completed
    @test successful.explicit_execution.actual == actual_completed
    @test successful.automatic_evidence === automatic
    @test successful.explicit_evidence === explicit
    @test successful.comparison === point.comparison
    @test successful.matched_endpoints === point.fictitious_endpoints

    automatic_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> error("automatic propagation failed"), common...)
    @test automatic_failure.automatic_execution.actual == actual_errored
    @test automatic_failure.explicit_execution.actual == actual_terminated
    @test isnothing(automatic_failure.automatic_evidence)
    @test isnothing(automatic_failure.comparison)

    invalid_interval = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        interval_runner=_ -> error("invalid automatic interval"),
        Base.structdiff(common, NamedTuple{(:interval_runner,)}((common.interval_runner,)))...)
    @test invalid_interval.automatic_execution.actual == actual_terminated
    @test invalid_interval.explicit_execution.actual == actual_terminated

    explicit_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> error("explicit propagation failed"), common...)
    @test explicit_failure.automatic_execution.actual == actual_completed
    @test explicit_failure.explicit_execution.actual == actual_errored
    @test explicit_failure.automatic_evidence === automatic
    @test isnothing(explicit_failure.comparison)

    measurement_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        automatic_method_measurement_runner=(args...) -> error("automatic measurement failed"),
        Base.structdiff(common, NamedTuple{(:automatic_method_measurement_runner,)}(
            (common.automatic_method_measurement_runner,)))...)
    @test measurement_failure.automatic_execution.actual == actual_errored
    @test measurement_failure.explicit_execution.actual == actual_completed
    @test measurement_failure.automatic_partial === automatic.propagation
    @test measurement_failure.explicit_evidence === explicit

    comparison_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        comparison_runner=(args...) -> error("pair comparison failed"),
        Base.structdiff(common, NamedTuple{(:comparison_runner,)}((common.comparison_runner,)))...)
    @test comparison_failure.automatic_evidence === automatic
    @test comparison_failure.explicit_evidence === explicit
    @test isnothing(comparison_failure.comparison)
    @test occursin("pair comparison failed", comparison_failure.comparison_failure)

    endpoint_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        matched_endpoint_runner=(args...) -> error("endpoint construction failed"),
        Base.structdiff(common, NamedTuple{(:matched_endpoint_runner,)}((common.matched_endpoint_runner,)))...)
    @test endpoint_failure.automatic_evidence === automatic
    @test endpoint_failure.explicit_evidence === explicit
    @test endpoint_failure.comparison === point.comparison
    @test isnothing(endpoint_failure.matched_endpoints)
    @test occursin("endpoint construction failed", endpoint_failure.comparison_failure)

    explicit_was_attempted = Ref(false)
    event_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        event_runner=_ -> error("event extraction failed exactly"),
        explicit_runner=(args...) -> (explicit_was_attempted[] = true; :explicit),
        Base.structdiff(common, NamedTuple{(:event_runner, :explicit_runner)}(
            (common.event_runner, (args...) -> :explicit)))...)
    @test explicit_was_attempted[]
    @test occursin("event extraction failed exactly", event_failure.automatic_execution.summary)
    @test occursin("event extraction failed exactly", event_failure.explicit_execution.summary)
    @test event_failure.automatic_partial isa ValidationFramework.CloseEncounterRegularizedPropagationFacts
    @test event_failure.explicit_partial isa ValidationFramework.CloseEncounterRegularizedPropagationFacts
    @test length(event_failure.automatic_partial.sampled_states) == 801
    @test event_failure.automatic_partial.segment_count == 3
    @test event_failure.explicit_partial.switch_count == 2

    event_evidence_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        event_evidence_runner=(args...) -> error("event evidence failed exactly"),
        Base.structdiff(common, NamedTuple{(:event_evidence_runner,)}(
            (common.event_evidence_runner,)))...)
    @test occursin("event evidence failed exactly", event_evidence_failure.automatic_execution.summary)
    @test occursin("event evidence failed exactly", event_evidence_failure.explicit_execution.summary)
    @test event_evidence_failure.automatic_partial isa ValidationFramework.CloseEncounterRegularizedPropagationFacts
    @test event_evidence_failure.explicit_partial isa ValidationFramework.CloseEncounterRegularizedPropagationFacts

    transition_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic, explicit_runner=(args...) -> :explicit,
        automatic_propagation_facts_runner=(args...; kwargs...) ->
            (facts=ValidationFramework.CloseEncounterRegularizedPropagationFacts(
                automatic.propagation.configuration, :automatic,
                automatic.propagation.automatic_interval, 1.6, (),
                automatic.propagation.sampled_states, automatic.propagation.work,
                automatic.propagation.segment_count, automatic.propagation.switch_count),
             transition_failure="transition extraction failed exactly"),
        Base.structdiff(common, NamedTuple{(:automatic_propagation_facts_runner,)}(
            (common.automatic_propagation_facts_runner,)))...)
    @test transition_failure.automatic_partial isa ValidationFramework.CloseEncounterRegularizedPropagationFacts
    @test isempty(transition_failure.automatic_partial.transitions)
    @test length(transition_failure.automatic_partial.sampled_states) == 801
    @test transition_failure.automatic_partial.work.rhs_evaluations == 42
    @test occursin("transition extraction failed exactly", transition_failure.automatic_execution.summary)

    dual_failure = attempt_close_encounter_regularized_pair(configuration, reference;
        automatic_runner=(args...) -> :automatic, explicit_runner=(args...) -> :explicit,
        automatic_propagation_facts_runner=(args...; kwargs...) ->
            (facts=automatic.propagation.facts,
             transition_failure="first stage failed exactly"),
        event_evidence_runner=(args...) -> error("second stage failed exactly"),
        Base.structdiff(common, NamedTuple{(:automatic_propagation_facts_runner,
            :event_evidence_runner)}((common.automatic_propagation_facts_runner,
            common.event_evidence_runner)))...)
    @test occursin("first stage failed exactly", dual_failure.automatic_execution.summary)
    @test occursin("second stage failed exactly", dual_failure.automatic_execution.summary)

    automatic_propagation_evidence_failure = attempt_close_encounter_regularized_pair(
        configuration, reference; automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        automatic_propagation_evidence_runner=(args...) -> error("automatic evidence failed exactly"),
        Base.structdiff(common, NamedTuple{(:automatic_propagation_evidence_runner,)}(
            (common.automatic_propagation_evidence_runner,)))...)
    @test occursin("automatic evidence failed exactly",
        automatic_propagation_evidence_failure.automatic_execution.summary)

    automatic_measurements = Ref(0)
    explicit_propagation_evidence_failure = attempt_close_encounter_regularized_pair(
        configuration, reference; automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        automatic_method_measurement_runner=(args...) ->
            (automatic_measurements[] += 1; automatic.reference),
        explicit_propagation_evidence_runner=(args...) -> error("explicit evidence failed exactly"),
        Base.structdiff(common, NamedTuple{(:automatic_method_measurement_runner,
            :explicit_propagation_evidence_runner)}((common.automatic_method_measurement_runner,
            common.explicit_propagation_evidence_runner)))...)
    @test automatic_measurements[] == 1
    @test explicit_propagation_evidence_failure.automatic_evidence isa
        ValidationFramework.CloseEncounterRegularizedMethodEvidence
    @test explicit_propagation_evidence_failure.automatic_execution.actual == actual_completed
    @test occursin("explicit evidence failed exactly",
        explicit_propagation_evidence_failure.explicit_execution.summary)

    automatic_endpoint_failure = attempt_close_encounter_regularized_pair(configuration,
        reference; automatic_runner=(args...) -> :automatic,
        explicit_runner=(args...) -> :explicit,
        automatic_endpoint_measurement_runner=(args...) -> error("automatic endpoint failed exactly"),
        Base.structdiff(common, NamedTuple{(:automatic_endpoint_measurement_runner,)}(
            (common.automatic_endpoint_measurement_runner,)))...)
    @test automatic_endpoint_failure.automatic_evidence.reference === automatic.reference
    @test isnothing(automatic_endpoint_failure.automatic_evidence.endpoint)
    @test occursin("automatic endpoint failed exactly",
        automatic_endpoint_failure.automatic_execution.summary)

    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, ExecutionOutcome(actual_completed; exit_code=0),
        ExecutionOutcome(actual_terminated; summary="not executed"),
        nothing, nothing, nothing, nothing, nothing, nothing)

    errored = ExecutionOutcome(actual_errored; summary="paired stage failed")
    completed = ExecutionOutcome(actual_completed; exit_code=0)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, completed, automatic, explicit,
        nothing, nothing, nothing, point.fictitious_endpoints)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, completed, automatic, explicit,
        nothing, nothing, point.comparison, nothing)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, errored, errored, automatic, explicit,
        nothing, nothing, nothing, point.fictitious_endpoints, "paired stage failed")
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, errored, errored, automatic, explicit,
        nothing, nothing, nothing, nothing, "   ")
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, errored, completed, automatic, explicit,
        nothing, nothing, point.comparison, point.fictitious_endpoints)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, errored, automatic, explicit,
        nothing, nothing, point.comparison, point.fictitious_endpoints)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, errored, errored, automatic, explicit,
        nothing, nothing, point.comparison, point.fictitious_endpoints)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, completed, automatic, explicit,
        nothing, nothing, point.comparison, point.fictitious_endpoints,
        "comparison failed")
    retained_after_automatic_failure = ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, errored, completed, automatic, explicit,
        nothing, nothing, nothing, nothing, "comparison failed")
    @test retained_after_automatic_failure.automatic_evidence === automatic
    retained_after_endpoint_failure = ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, errored, errored, automatic, explicit,
        nothing, nothing, point.comparison, nothing, "matched endpoint failed")
    @test retained_after_endpoint_failure.comparison === point.comparison

    facts = automatic.propagation.facts
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, nothing, nothing, nothing, nothing, :propagation;
        summary="failure")
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, nothing, facts, nothing, nothing, :propagation)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, point.comparison, nothing, :measurement;
        summary="failure")
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, nothing, nothing, :comparison;
        summary="failure")
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, point.comparison, point.fictitious_endpoints,
        :complete; summary="failure")
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, point.comparison, nothing, :complete)
    @test ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, nothing, facts, nothing, nothing, :propagation;
        summary="event failure").stage == :propagation
    @test ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, nothing, nothing, :measurement;
        summary="comparison failure").stage == :measurement
    @test ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, point.comparison, nothing, :comparison;
        summary="matched endpoint failure").stage == :comparison

    mismatched_automatic_endpoint = ValidationFramework.CloseEncounterMethodFictitiousEndpointEvidence(
        :automatic, explicit.endpoint.automatic_exit_time, 0.811,
        explicit.endpoint.automatic_exit_time, 0.0)
    mismatched_endpoints = ValidationFramework.CloseEncounterMatchedEndpointEvidence(
        mismatched_automatic_endpoint, explicit.endpoint,
        explicit.endpoint.terminal_fictitious_time -
            mismatched_automatic_endpoint.terminal_fictitious_time)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, completed, automatic, explicit,
        nothing, nothing, point.comparison, mismatched_endpoints)
    mismatched_interval = (0.69, 0.91)
    mismatched_times = (BigFloat(mismatched_interval[1]),
        reference.boundaries.periapsis_time, BigFloat(mismatched_interval[2]), BigFloat(1.6))
    mismatched_samples = ntuple(4) do index
        ValidationFramework.CloseEncounterMethodDifferenceSample(
            (:entry, :periapsis, :exit, :final)[index], mismatched_times[index],
            (pair_position=index * 1e-12, pair_velocity=index * 2e-12,
                full_state=index * 3e-12))
    end
    mismatched_epochs = Float64[t for t in ValidationFramework.close_encounter_sample_times((0.0, 1.6))
        if mismatched_interval[1] <= t <= mismatched_interval[2]]
    append!(mismatched_epochs, [mismatched_interval[1],
        Float64(reference.boundaries.periapsis_time), mismatched_interval[2]])
    sort!(unique!(mismatched_epochs))
    mismatched_comparison = ValidationFramework.CloseEncounterAutomaticExplicitComparisonEvidence(
        mismatched_interval, mismatched_samples,
        (pair_position=5e-12, pair_velocity=8e-12, full_state=12e-12),
        length(mismatched_epochs))
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, completed, automatic, explicit,
        nothing, nothing, mismatched_comparison, point.fictitious_endpoints)
    foreign_periapsis = setprecision(BigFloat, 256) do
        reference.boundaries.periapsis_time + parse(BigFloat, "1e-30")
    end
    foreign_samples = Base.setindex(point.comparison.samples,
        ValidationFramework.CloseEncounterMethodDifferenceSample(:periapsis,
            foreign_periapsis,
            (pair_position=2e-12, pair_velocity=4e-12, full_state=6e-12)), 2)
    foreign_comparison = ValidationFramework.CloseEncounterAutomaticExplicitComparisonEvidence(
        point.comparison.automatic_interval, foreign_samples,
        (pair_position=5e-12, pair_velocity=8e-12, full_state=12e-12),
        point.comparison.comparison_epoch_count)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedPairAttempt(
        configuration, reference, completed, completed, automatic, explicit,
        nothing, nothing, foreign_comparison, point.fictitious_endpoints)
    @test_throws ArgumentError ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, automatic, nothing, foreign_comparison, point.fictitious_endpoints,
        :complete)

    setprecision(BigFloat, 128) do
        entry = BigFloat(0.7); exit = BigFloat(0.9)
        @test_throws ArgumentError ValidationFramework.CloseEncounterAutomaticEventEvidence(
            0.7, 0.9, automatic_fixture.event.reference_entry_time,
            automatic_fixture.event.reference_exit_time, entry, abs(entry), exit,
            abs(exit), 0.1, 0.0, 0.25, 0.0, -1.0, 1.0)
    end

    ambient_precision = precision(BigFloat)
    setprecision(BigFloat, 128) do
        rebuilt = synthetic_regularized_evidence(:automatic)
        @test precision(rebuilt.event_evidence.signed_entry_time_difference) == 256
        @test precision(rebuilt.boundaries.periapsis_time) == 256
    end
    @test precision(BigFloat) == ambient_precision
end

function synthetic_regularized_performance_report(method, configuration, environment;
    execution=ExecutionOutcome(actual_completed; exit_code=0),
    definition=ValidationFramework.close_encounter_regularized_performance_definition(method, configuration),
    recorded_configuration=ValidationFramework._close_regularized_validation_configuration(configuration, method),
    policy=StandardBenchmark())
    samples = execution.actual == actual_completed ? Tuple(
        PerformanceSample(index; elapsed_seconds=0.01index,
            solver_statistics=SolverStatistics(accepted_steps=11, rejected_steps=2,
                rhs_evaluations=42, saved_states=14), saved_states=14)
        for index in 1:policy.sample_runs) : ()
    build_performance_benchmark_report(definition, environment,
        recorded_configuration, policy, samples, execution)
end

function synthetic_regularized_suite(environment; reports=nothing)
    values = isnothing(reports) ? Tuple(
        synthetic_regularized_performance_report(method,
            close_encounter_regularized_tolerance_configuration(tolerance), environment)
        for method in (:automatic, :explicit)
        for tolerance in ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES) : Tuple(reports)
    PerformanceSuiteReport(:close_encounter_regularized_test,
        "Close-encounter regularised test", VALIDATION_SCHEMA_VERSION,
        environment, values)
end

function synthetic_regularized_attempt(reference, tolerance; comparison_failure=false,
    incomplete_stage=nothing)
    configuration = close_encounter_regularized_tolerance_configuration(tolerance)
    automatic_fixture = synthetic_regularized_for_reference(:automatic, tolerance, reference)
    explicit_fixture = synthetic_regularized_for_reference(:explicit, tolerance, reference)
    automatic = automatic_fixture.method
    explicit = explicit_fixture.method
    comparison = automatic_fixture.comparison
    endpoints = ValidationFramework.CloseEncounterMatchedEndpointEvidence(
        automatic.endpoint, explicit.endpoint,
        explicit.endpoint.terminal_fictitious_time - automatic.endpoint.terminal_fictitious_time)
    abnormal(summary) = ExecutionOutcome(actual_errored; summary)
    if incomplete_stage == :explicit_propagation
        summary = "explicit propagation failed"
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, ExecutionOutcome(actual_completed; exit_code=0), abnormal(summary),
            automatic, nothing, nothing, explicit.propagation.facts, nothing, nothing)
    elseif incomplete_stage == :automatic_measurement
        summary = "automatic measurement failed"
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, abnormal(summary), ExecutionOutcome(actual_completed; exit_code=0),
            nothing, explicit, automatic.propagation, nothing, nothing, nothing)
    elseif incomplete_stage == :automatic_endpoint
        summary = "automatic endpoint failed"
        automatic_without_endpoint = ValidationFramework.CloseEncounterRegularizedMethodEvidence(
            automatic.propagation, automatic.reference, nothing)
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, abnormal(summary), ExecutionOutcome(actual_completed; exit_code=0),
            automatic_without_endpoint, explicit, nothing, nothing, nothing, nothing, summary)
    elseif incomplete_stage == :transition
        summary = "transition evidence failed"
        facts = ValidationFramework.CloseEncounterRegularizedPropagationFacts(configuration,
            :automatic, automatic.propagation.automatic_interval, 1.6, (),
            automatic.propagation.sampled_states, automatic.propagation.work,
            automatic.propagation.segment_count, automatic.propagation.switch_count)
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, abnormal(summary), ExecutionOutcome(actual_completed; exit_code=0),
            nothing, explicit, facts, nothing, nothing, nothing)
    elseif incomplete_stage == :event_evidence
        summary = "event evidence failed"
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, abnormal(summary), abnormal(summary), nothing, nothing,
            automatic.propagation.facts, explicit.propagation.facts, nothing, nothing)
    elseif incomplete_stage == :dual_failure
        summary = "first stage failed exactly; second stage failed exactly"
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, abnormal(summary), abnormal(summary), nothing, nothing,
            automatic.propagation.facts, explicit.propagation.facts, nothing, nothing)
    end
    if comparison_failure
        summary = "synthetic pair comparison failed"
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, ExecutionOutcome(actual_errored; summary),
            ExecutionOutcome(actual_errored; summary), automatic, explicit,
            nothing, nothing, nothing, nothing, summary)
    end
    ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration, reference,
        ExecutionOutcome(actual_completed; exit_code=0),
        ExecutionOutcome(actual_completed; exit_code=0), automatic, explicit,
        nothing, nothing, comparison, endpoints)
end

@testset "Close-encounter regularised paired series" begin
    reference = synthetic_close_reference()
    environment = current_validation_environment()
    attempts = Tuple(synthetic_regularized_attempt(reference, tolerance)
        for tolerance in ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
    suite = synthetic_regularized_suite(environment)
    series = close_encounter_regularized_investigation_series(suite, attempts)
    @test series.automatic.series_id == :close_encounter_automatic_regularized_tolerance
    @test series.explicit.series_id == :close_encounter_explicit_regularized_tolerance
    @test length(series.automatic.points) == 4
    @test length(series.explicit.points) == 4
    @test all(point -> length(point.metrics) == 22, series.automatic.points)
    @test all(point -> point.solver_statistics.segment_count == 3, series.explicit.points)
    @test all(point -> point.solver_statistics.switch_count == 2, series.explicit.points)
    for (stage, automatic_metrics, explicit_metrics) in (
        (:explicit_propagation, 17, 0),
        (:automatic_measurement, 0, 17),
        (:automatic_endpoint, 16, 17),
        (:transition, 0, 17),
        (:event_evidence, 0, 0))
        incomplete_attempts = Base.setindex(attempts,
            synthetic_regularized_attempt(reference, 1e-12; incomplete_stage=stage), 3)
        incomplete = close_encounter_regularized_investigation_series(suite, incomplete_attempts)
        @test length(incomplete.automatic.points) == 4
        @test length(incomplete.explicit.points) == 4
        automatic_point = incomplete.automatic.points[3]
        explicit_point = incomplete.explicit.points[3]
        @test automatic_point.execution.actual != actual_completed
        @test explicit_point.execution.actual != actual_completed
        @test length(automatic_point.metrics) == automatic_metrics
        @test length(explicit_point.metrics) == explicit_metrics
        @test !isnothing(automatic_point.solver_statistics)
        @test !isnothing(explicit_point.solver_statistics)
    end
    dual_attempts = Base.setindex(attempts,
        synthetic_regularized_attempt(reference, 1e-12; incomplete_stage=:dual_failure), 3)
    dual_series = close_encounter_regularized_investigation_series(suite, dual_attempts).automatic
    dual_point = dual_series.points[3]
    @test occursin("first stage failed exactly", dual_point.execution.summary)
    @test occursin("second stage failed exactly", dual_point.execution.summary)
    dual_text = investigation_series_report_text(dual_series)
    restored_dual = read_investigation_series(IOBuffer(dual_text)).points[3]
    @test occursin("first stage failed exactly", restored_dual.supporting_evidence.summary)
    @test occursin("second stage failed exactly", restored_dual.supporting_evidence.summary)
    automatic_text = investigation_series_report_text(series.automatic)
    restored_automatic = read_investigation_series(IOBuffer(automatic_text))
    @test automatic_text == investigation_series_report_text(restored_automatic)
    complete_supporting = restored_automatic.points[1].supporting_evidence
    @test complete_supporting isa ValidationFramework.CloseEncounterRegularizedSupportingEvidence
    @test complete_supporting.stage == :complete
    @test isnothing(complete_supporting.summary)
    @test complete_supporting.method_evidence.propagation.achieved_final_time == 1.6
    @test length(complete_supporting.method_evidence.propagation.sampled_states) == 801
    @test complete_supporting.method_evidence.propagation.work.rhs_evaluations == 42
    @test complete_supporting.method_evidence.propagation.segment_count == 3
    @test complete_supporting.method_evidence.propagation.switch_count == 2
    @test !isnothing(complete_supporting.method_evidence.reference)
    @test !isnothing(complete_supporting.method_evidence.endpoint)
    @test !isnothing(complete_supporting.comparison)
    @test !isnothing(complete_supporting.matched_endpoints)
    function tamper_supporting_section(text, section, old, new)
        marker = "[points.supporting_evidence.$section]"
        location = findfirst(marker, text)
        isnothing(location) && error("Missing serialized section $section")
        prefix = text[firstindex(text):prevind(text, first(location))]
        suffix = text[first(location):end]
        prefix * replace(suffix, old => new; count=1)
    end
    mismatched_comparison_text = tamper_supporting_section(automatic_text,
        "comparison", r"automatic_entry_time_text = \"[^\"]+\"",
        "automatic_entry_time_text = \"0.69\"")
    @test_throws Exception read_investigation_series(IOBuffer(mismatched_comparison_text))
    mismatched_endpoint_text = tamper_supporting_section(automatic_text,
        "matched_endpoints", r"automatic_exit_time_text = \"[^\"]+\"",
        "automatic_exit_time_text = \"0.91\"")
    @test_throws Exception read_investigation_series(IOBuffer(mismatched_endpoint_text))
    complete_with_summary = replace(automatic_text, "stage = \"complete\"" =>
        "stage = \"complete\"\nsummary = \"contradictory\""; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(complete_with_summary))
    complete_without_endpoint = replace(automatic_text,
        "has_method_endpoint = true" => "has_method_endpoint = false"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(complete_without_endpoint))
    hidden_comparison = replace(automatic_text,
        "has_comparison = true" => "has_comparison = false"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(hidden_comparison))
    hidden_matched = replace(automatic_text,
        "has_matched_endpoints = true" => "has_matched_endpoints = false"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(hidden_matched))
    hidden_method_endpoint = replace(automatic_text,
        "has_method_endpoint = true" => "has_method_endpoint = false"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(hidden_method_endpoint))
    hidden_validated_event = replace(automatic_text,
        "has_validated_event_evidence = true" =>
            "has_validated_event_evidence = false"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(hidden_validated_event))
    events_only = replace(automatic_text,
        "[points.supporting_evidence.boundaries]" =>
            "[points.supporting_evidence.orphan_boundaries]"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(events_only))
    boundaries_only = replace(automatic_text,
        "[points.supporting_evidence.events]" =>
            "[points.supporting_evidence.orphan_events]"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(boundaries_only))
    extra_transition = automatic_text * "\n[points.supporting_evidence.transition_3]\n"
    @test_throws ArgumentError read_investigation_series(IOBuffer(extra_transition))
    extra_state = automatic_text * "\n[points.supporting_evidence.sampled_state_802]\n"
    @test_throws ArgumentError read_investigation_series(IOBuffer(extra_state))
    extra_comparison_sample_5 = automatic_text *
        "\n[points.supporting_evidence.comparison.sample_5]\n"
    @test_throws ArgumentError read_investigation_series(IOBuffer(extra_comparison_sample_5))
    extra_comparison_sample_0 = automatic_text *
        "\n[points.supporting_evidence.comparison.sample_0]\n"
    @test_throws ArgumentError read_investigation_series(IOBuffer(extra_comparison_sample_0))
    missing_comparison_sample_3 = replace(automatic_text,
        "[points.supporting_evidence.comparison.sample_3]" =>
            "[points.supporting_evidence.comparison.missing_sample_3]"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(missing_comparison_sample_3))
    renamed_comparison_sample_4 = replace(automatic_text,
        "[points.supporting_evidence.comparison.sample_4]" =>
            "[points.supporting_evidence.comparison.renamed_sample_4]"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(renamed_comparison_sample_4))
    missing_comparison_maximum = replace(automatic_text,
        "[points.supporting_evidence.comparison.maximum]" =>
            "[points.supporting_evidence.comparison.missing_maximum]"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(missing_comparison_maximum))
    extra_comparison_maximum = automatic_text *
        "\n[points.supporting_evidence.comparison.maximum_2]\n"
    @test_throws ArgumentError read_investigation_series(IOBuffer(extra_comparison_maximum))
    altered_periapsis = tamper_supporting_section(automatic_text,
        "comparison.sample_2", r"time_text = \"[^\"]+\"",
        "time_text = \"0.8000000000000001\"")
    @test_throws ArgumentError read_investigation_series(IOBuffer(altered_periapsis))

    propagation_supporting = ValidationFramework.CloseEncounterRegularizedSupportingEvidence(
        :automatic, nothing, attempts[1].automatic_evidence.propagation.facts,
        nothing, nothing, :propagation; summary="event extraction failed exactly")
    propagation_point = InvestigationMeasurementPoint(:regularized_tolerance_1e_10,
        series.automatic.definition,
        ValidationFramework._close_regularized_validation_configuration(
            attempts[1].configuration, :automatic),
        ValidationParameter(:regularized_tolerance, 1e-10), environment,
        ExecutionOutcome(actual_errored; summary="event extraction failed exactly"), ();
        supporting_evidence=propagation_supporting,
        notes="event extraction failed exactly")
    propagation_series = InvestigationMeasurementSeries(series.automatic.series_id,
        series.automatic.title, series.automatic.description,
        series.automatic.definition, (propagation_point,))
    propagation_text = investigation_series_report_text(propagation_series)
    restored_propagation_series = read_investigation_series(IOBuffer(propagation_text))
    @test propagation_text == investigation_series_report_text(restored_propagation_series)
    restored_facts = only(restored_propagation_series.points).supporting_evidence
    @test restored_facts.stage == :propagation
    @test restored_facts.propagation_evidence isa ValidationFramework.CloseEncounterRegularizedPropagationFacts
    @test restored_facts.propagation_evidence.achieved_final_time == 1.6
    @test length(restored_facts.propagation_evidence.sampled_states) == 801
    propagation_with_comparison = replace(propagation_text,
        "has_comparison = false" => "has_comparison = true"; count=1)
    @test_throws Exception read_investigation_series(IOBuffer(propagation_with_comparison))
    propagation_without_facts = replace(propagation_text,
        "has_propagation_evidence = true" => "has_propagation_evidence = false"; count=1)
    @test_throws ArgumentError read_investigation_series(IOBuffer(propagation_without_facts))

    partial_attempts = Base.setindex(attempts,
        synthetic_regularized_attempt(reference, 1e-12; comparison_failure=true), 3)
    partial = close_encounter_regularized_investigation_series(suite, partial_attempts)
    @test partial.automatic.points[3].execution.actual == actual_errored
    @test length(partial.automatic.points[3].metrics) == 17
    @test all(metric -> !(metric.metric_id in (:entry_full_state_difference,
        :maximum_interval_full_state_difference)), partial.automatic.points[3].metrics)
    partial_text = investigation_series_report_text(partial.automatic)
    restored_partial = read_investigation_series(IOBuffer(partial_text))
    @test partial_text == investigation_series_report_text(restored_partial)
    partial_supporting = restored_partial.points[3].supporting_evidence
    @test partial_supporting isa ValidationFramework.CloseEncounterRegularizedSupportingEvidence
    @test partial_supporting.method_evidence isa ValidationFramework.CloseEncounterRegularizedMethodEvidence
    @test partial_supporting.stage == :measurement
    @test occursin("synthetic pair comparison failed", partial_supporting.summary)

    comparison_configuration = attempts[3].configuration
    comparison_summary = "matched endpoint construction failed exactly"
    comparison_stage_attempt = ValidationFramework.CloseEncounterRegularizedPairAttempt(
        comparison_configuration, reference,
        ExecutionOutcome(actual_errored; summary=comparison_summary),
        ExecutionOutcome(actual_errored; summary=comparison_summary),
        attempts[3].automatic_evidence, attempts[3].explicit_evidence,
        nothing, nothing, attempts[3].comparison, nothing, comparison_summary)
    comparison_attempts = Base.setindex(attempts, comparison_stage_attempt, 3)
    comparison_series = close_encounter_regularized_investigation_series(
        suite, comparison_attempts).automatic
    comparison_text = investigation_series_report_text(comparison_series)
    restored_comparison_series = read_investigation_series(IOBuffer(comparison_text))
    @test comparison_text == investigation_series_report_text(restored_comparison_series)
    comparison_supporting = restored_comparison_series.points[3].supporting_evidence
    @test comparison_supporting.stage == :comparison
    @test !isnothing(comparison_supporting.method_evidence.endpoint)
    @test !isnothing(comparison_supporting.comparison)
    @test isnothing(comparison_supporting.matched_endpoints)
    @test comparison_supporting.summary == comparison_summary

    @test_throws ArgumentError close_encounter_regularized_investigation_series(
        PerformanceSuiteReport(:bad, "bad", VALIDATION_SCHEMA_VERSION,
            environment, reverse(suite.benchmarks)), attempts)
    @test_throws ArgumentError close_encounter_regularized_investigation_series(
        PerformanceSuiteReport(:bad, "bad", VALIDATION_SCHEMA_VERSION,
            environment, suite.benchmarks[1:7]), attempts)
    @test_throws ArgumentError close_encounter_regularized_investigation_series(
        PerformanceSuiteReport(:bad, "bad", VALIDATION_SCHEMA_VERSION,
            environment, (suite.benchmarks..., suite.benchmarks[end])), attempts)
    @test_throws ArgumentError close_encounter_regularized_investigation_series(suite, attempts[1:3])
    other_reference = synthetic_close_reference()
    mismatched = Base.setindex(attempts,
        synthetic_regularized_attempt(other_reference, 1e-13), 4)
    @test_throws ArgumentError close_encounter_regularized_investigation_series(suite, mismatched)

    failed_report = synthetic_regularized_performance_report(:automatic,
        close_encounter_regularized_tolerance_configuration(1e-10), environment;
        execution=ExecutionOutcome(actual_errored; summary="performance failed"))
    reports = collect(suite.benchmarks); reports[1] = failed_report
    failed_performance_series = close_encounter_regularized_investigation_series(
        synthetic_regularized_suite(environment; reports), attempts)
    point = failed_performance_series.automatic.points[1]
    @test point.execution.actual == actual_errored
    @test occursin("performance failed", point.execution.summary)
    @test length(point.metrics) == 22
    @test !isnothing(point.performance_report)

    partial_failed_performance = close_encounter_regularized_investigation_series(
        synthetic_regularized_suite(environment; reports),
        Base.setindex(attempts,
            synthetic_regularized_attempt(reference, 1e-10; comparison_failure=true), 1))
    combined = partial_failed_performance.automatic.points[1]
    @test combined.execution.actual == actual_errored
    @test occursin("synthetic pair comparison failed", combined.execution.summary)
    @test occursin("performance failed", combined.execution.summary)
    @test length(combined.metrics) == 17
end

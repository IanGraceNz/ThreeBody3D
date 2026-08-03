function synthetic_threshold_for_reference(method, scale, reference)
    configuration = close_encounter_threshold_scale_configuration(scale)
    base = synthetic_regularized_for_reference(method, 1e-12, reference)
    entry_time, exit_time = base.method.propagation.automatic_interval
    setprecision(BigFloat, 256) do
        entry_difference = BigFloat(entry_time) - reference.boundaries.entry_time
        exit_difference = BigFloat(exit_time) - reference.boundaries.exit_time
        event = ValidationFramework.CloseEncounterAutomaticEventEvidence(entry_time, exit_time,
            reference.boundaries.entry_time, reference.boundaries.exit_time,
            entry_difference, abs(entry_difference), exit_difference, abs(exit_difference),
            configuration.entry_threshold, 0.0, configuration.exit_threshold, 0.0,
            -1.0, 1.0; entry_threshold=configuration.entry_threshold,
            exit_threshold=configuration.exit_threshold)
        propagation = ValidationFramework.CloseEncounterRegularizedPropagationEvidence(
            configuration, method, reference.boundaries, (entry_time, exit_time), 1.6,
            event, base.method.propagation.transitions,
            base.method.propagation.sampled_states, base.method.propagation.work,
            base.method.propagation.segment_count, base.method.propagation.switch_count)
        evidence = ValidationFramework.CloseEncounterRegularizedMethodEvidence(
            propagation, base.method.reference, base.method.endpoint)
        (method=evidence, comparison=base.comparison, event)
    end
end

function synthetic_threshold_attempt(reference, scale; incomplete_stage=nothing)
    configuration = close_encounter_threshold_scale_configuration(scale)
    automatic = synthetic_threshold_for_reference(:automatic, scale, reference).method
    explicit = synthetic_threshold_for_reference(:explicit, scale, reference).method
    comparison = synthetic_threshold_for_reference(:automatic, scale, reference).comparison
    endpoints = ValidationFramework.CloseEncounterMatchedEndpointEvidence(
        automatic.endpoint, explicit.endpoint,
        explicit.endpoint.terminal_fictitious_time - automatic.endpoint.terminal_fictitious_time)
    completed = ExecutionOutcome(actual_completed; exit_code=0)
    failed(summary) = ExecutionOutcome(actual_errored; summary)
    if incomplete_stage == :propagation
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, failed("automatic propagation evidence failed"), completed,
            nothing, explicit, automatic.propagation.facts, nothing, nothing, nothing)
    elseif incomplete_stage == :measurement
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, failed("automatic measurement failed"), completed,
            nothing, explicit, automatic.propagation, nothing, nothing, nothing)
    elseif incomplete_stage == :comparison
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, failed("comparison failed"), failed("comparison failed"),
            automatic, explicit, nothing, nothing, nothing, nothing, "comparison failed")
    elseif incomplete_stage == :endpoints
        return ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration,
            reference, failed("matched endpoints failed"), failed("matched endpoints failed"),
            automatic, explicit, nothing, nothing, comparison, nothing,
            "matched endpoints failed")
    end
    ValidationFramework.CloseEncounterRegularizedPairAttempt(configuration, reference,
        completed, completed, automatic, explicit, nothing, nothing, comparison, endpoints)
end

function synthetic_threshold_performance_report(method, scale, environment;
    execution=ExecutionOutcome(actual_completed; exit_code=0))
    configuration = close_encounter_threshold_scale_configuration(scale)
    definition = ValidationFramework.close_encounter_threshold_performance_definition(
        method, configuration)
    policy = StandardBenchmark()
    samples = execution.actual == actual_completed ? Tuple(
        PerformanceSample(index; elapsed_seconds=0.01index,
            solver_statistics=SolverStatistics(accepted_steps=11, rejected_steps=2,
                rhs_evaluations=42, saved_states=14, segment_count=3, switch_count=2),
            saved_states=14) for index in 1:policy.sample_runs) : ()
    build_performance_benchmark_report(definition, environment,
        ValidationFramework._close_regularized_validation_configuration(configuration, method),
        policy, samples, execution)
end

function synthetic_threshold_suite(environment; reports=nothing)
    values = isnothing(reports) ? Tuple(synthetic_threshold_performance_report(
        method, scale, environment) for method in (:automatic, :explicit)
        for scale in ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES) : Tuple(reports)
    PerformanceSuiteReport(:close_encounter_threshold_test,
        "Close-encounter threshold test", VALIDATION_SCHEMA_VERSION,
        environment, values)
end

@testset "Close-encounter threshold-scale configurations" begin
    configurations = Tuple(close_encounter_threshold_scale_configuration(scale)
        for scale in ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    @test map(c -> c.threshold_scale, configurations) == (0.5, 1.0, 2.0)
    @test map(c -> (c.entry_threshold, c.ambiguity_threshold, c.exit_threshold),
        configurations) == ((0.05, 0.125, 0.125), (0.1, 0.25, 0.25),
            (0.2, 0.5, 0.5))
    @test all(c -> c.ambiguity_threshold == c.exit_threshold, configurations)
    @test_throws ArgumentError close_encounter_threshold_scale_configuration(0.25)
    base = configurations[2]
    for index in 2:12
        values = Any[getfield(base, name) for name in fieldnames(typeof(base))]
        values[index] = values[index] isa Int ? values[index] + 1 : values[index] * 1.01
        @test_throws ArgumentError ValidationFramework.CloseEncounterThresholdScaleConfiguration(
            values...)
    end
    controls = ValidationFramework._close_regularized_controls(configurations[1])
    @test controls.entry_threshold == 0.05
    @test controls.ambiguity_threshold == 0.125
    @test controls.exit_threshold == 0.125
    @test controls.regularized_relative_tolerance == 1e-12
    @test controls.cartesian_relative_tolerance == 1e-13
    @test controls.state_evaluation_tolerance == 1e-14
    definitions = Tuple(ValidationFramework.close_encounter_threshold_investigation_definition(m)
        for m in (:automatic, :explicit))
    @test all(d -> d.independent_variable == :threshold_scale, definitions)
    @test map(d -> d.family_id, definitions) ==
        (:close_encounter_automatic_threshold_scale,
            :close_encounter_explicit_threshold_scale)
end

@testset "Close-encounter threshold matched attempts and series" begin
    reference = synthetic_close_reference()
    attempts = Tuple(synthetic_threshold_attempt(reference, scale)
        for scale in ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    @test all(attempt -> attempt.reference === reference, attempts)
    @test all(attempt -> attempt.automatic_execution.actual == actual_completed &&
        attempt.explicit_execution.actual == actual_completed, attempts)
    for attempt in attempts
        configuration = attempt.configuration
        @test attempt.automatic_evidence.propagation.automatic_interval ==
            attempt.explicit_evidence.propagation.automatic_interval ==
            attempt.comparison.automatic_interval
        @test attempt.automatic_evidence.propagation.boundaries === reference.boundaries
        @test attempt.automatic_evidence.propagation.event_evidence.entry_threshold_residual ==
            attempt.automatic_evidence.propagation.event_evidence.entry_separation -
                configuration.entry_threshold
        @test attempt.automatic_evidence.propagation.event_evidence.exit_threshold_residual ==
            attempt.automatic_evidence.propagation.event_evidence.exit_separation -
                configuration.exit_threshold
        @test attempt.automatic_evidence.propagation.event_evidence.reference_entry_time ==
            reference.boundaries.entry_time
        @test attempt.automatic_evidence.propagation.event_evidence.reference_exit_time ==
            reference.boundaries.exit_time
        @test map(x -> x.location, attempt.comparison.samples) ==
            (:entry, :periapsis, :exit, :final)
        @test attempt.comparison.samples[2].time === reference.boundaries.periapsis_time
        @test !isnothing(attempt.matched_endpoints)
    end
    environment = current_validation_environment()
    suite = synthetic_threshold_suite(environment)
    series = close_encounter_threshold_investigation_series(suite, attempts)
    @test map(p -> p.point_id, series.automatic.points) ==
        (:threshold_scale_0_5, :threshold_scale_1_0, :threshold_scale_2_0)
    @test all(point -> length(point.metrics) == 22, series.automatic.points)
    @test all(point -> length(point.metrics) == 22, series.explicit.points)
    @test all(point -> point.supporting_evidence.stage == :complete,
        series.automatic.points)
    @test all(point -> point.independent_value.parameter_id == :threshold_scale,
        series.explicit.points)

    reports = suite.benchmarks
    @test map(r -> r.definition.benchmark_id, reports) == (
        :close_encounter_automatic_threshold_scale_0_5,
        :close_encounter_automatic_threshold_scale_1_0,
        :close_encounter_automatic_threshold_scale_2_0,
        :close_encounter_explicit_threshold_scale_0_5,
        :close_encounter_explicit_threshold_scale_1_0,
        :close_encounter_explicit_threshold_scale_2_0)
    @test_throws ArgumentError close_encounter_threshold_investigation_series(
        PerformanceSuiteReport(:bad, "bad", VALIDATION_SCHEMA_VERSION,
            environment, reverse(reports)), attempts)
    @test_throws ArgumentError close_encounter_threshold_investigation_series(
        PerformanceSuiteReport(:bad, "bad", VALIDATION_SCHEMA_VERSION,
            environment, reports[1:5]), attempts)
    @test_throws ArgumentError close_encounter_threshold_investigation_series(
        PerformanceSuiteReport(:bad, "bad", VALIDATION_SCHEMA_VERSION,
            environment, (reports..., reports[end])), attempts)
    @test_throws ArgumentError close_encounter_threshold_investigation_series(suite,
        reverse(attempts))

    failed = synthetic_threshold_performance_report(:automatic, 0.5, environment;
        execution=ExecutionOutcome(actual_errored; summary="performance failed"))
    altered_reports = collect(reports); altered_reports[1] = failed
    failed_series = close_encounter_threshold_investigation_series(
        synthetic_threshold_suite(environment; reports=altered_reports), attempts)
    @test failed_series.automatic.points[1].execution.actual == actual_errored
    @test length(failed_series.automatic.points[1].metrics) == 22
    @test failed_series.automatic.points[1].supporting_evidence.stage == :complete

    for (stage, expected_stage) in ((:propagation, :propagation),
        (:measurement, :propagation), (:comparison, :measurement),
        (:endpoints, :comparison))
        partial_attempts = Base.setindex(attempts,
            synthetic_threshold_attempt(reference, 1.0; incomplete_stage=stage), 2)
        partial = close_encounter_threshold_investigation_series(suite, partial_attempts)
        @test partial.automatic.points[2].execution.actual != actual_completed
        @test partial.explicit.points[2].execution.actual != actual_completed
        @test partial.automatic.points[2].supporting_evidence.stage == expected_stage
    end
end

@testset "Close-encounter threshold performance contracts" begin
    configuration = close_encounter_threshold_scale_configuration(0.5)
    automatic_calls = Ref(0)
    work = (saved_states=14, accepted_steps=11, rejected_steps=2, rhs_evaluations=42)
    automatic_operation = ValidationFramework.close_encounter_threshold_performance_operation(
        :automatic, configuration;
        automatic_runner=(args...) -> (automatic_calls[] += 1; :automatic),
        interval_runner=_ -> (0.7, 0.9), automatic_work_runner=_ -> work,
        automatic_count_runner=_ -> (3, 2))
    automatic_observation = automatic_operation()
    @test automatic_calls[] == 1
    @test automatic_observation.solver_statistics.segment_count == 3
    @test automatic_observation.solver_statistics.switch_count == 2
    @test automatic_observation.saved_states == 14

    setup_calls = Ref(0); explicit_calls = Ref(0); supplied_interval = Ref{Any}(nothing)
    explicit_operation = ValidationFramework.close_encounter_threshold_performance_operation(
        :explicit, configuration;
        automatic_runner=(args...) -> (setup_calls[] += 1; :automatic),
        interval_runner=_ -> (0.7, 0.9),
        explicit_runner=(problem, interval, controls) -> begin
            explicit_calls[] += 1; supplied_interval[] = interval; :explicit
        end, explicit_work_runner=_ -> work)
    @test setup_calls[] == 1
    @test explicit_calls[] == 0
    explicit_observation = explicit_operation()
    @test explicit_calls[] == 1
    @test supplied_interval[] == (0.7, 0.9)
    @test explicit_observation.solver_statistics.segment_count == 3
    @test explicit_observation.solver_statistics.switch_count == 2
    @test length(close_encounter_threshold_performance_entries()) == 6
    ids = map(e -> e.definition.benchmark_id,
        close_encounter_threshold_performance_entries())
    @test length(unique(ids)) == 6
    @test_throws ArgumentError ValidationFramework.decode_close_encounter_threshold_benchmark_id(
        :close_encounter_automatic_threshold_scale_3_0)
end

@testset "Close-encounter threshold serialization integrity" begin
    reference = synthetic_close_reference()
    attempts = Tuple(synthetic_threshold_attempt(reference, scale)
        for scale in ValidationFramework.CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    environment = current_validation_environment()
    series = close_encounter_threshold_investigation_series(
        synthetic_threshold_suite(environment), attempts).automatic
    text = investigation_series_report_text(series)
    restored = read_investigation_series(IOBuffer(text))
    @test text == investigation_series_report_text(restored)
    @test all(point -> point.supporting_evidence.method_evidence.propagation.configuration isa
        ValidationFramework.CloseEncounterThresholdScaleConfiguration, restored.points)

    partial_attempts = Base.setindex(attempts,
        synthetic_threshold_attempt(reference, 1.0; incomplete_stage=:endpoints), 2)
    partial = close_encounter_threshold_investigation_series(
        synthetic_threshold_suite(environment), partial_attempts).automatic
    partial_text = investigation_series_report_text(partial)
    @test partial_text == investigation_series_report_text(
        read_investigation_series(IOBuffer(partial_text)))

    tamper(old, new) = replace(text, old => new; count=1)
    function tamper_after(marker, pattern, replacement)
        location = findfirst(marker, text)
        isnothing(location) && error("Missing serialized marker $marker")
        prefix = text[firstindex(text):prevind(text, first(location))]
        suffix = text[first(location):end]
        prefix * replace(suffix, pattern => replacement; count=1)
    end
    function tamper_point_kind(source, point_id, replacement)
        point_marker = "point_id = \"$point_id\""
        point_location = findfirst(point_marker, source)
        isnothing(point_location) && error("Missing serialized point $point_id")
        point_suffix = source[first(point_location):end]
        evidence_location = findfirst("[points.supporting_evidence]", point_suffix)
        isnothing(evidence_location) && error("Missing supporting evidence for $point_id")
        absolute_evidence = first(point_location) + first(evidence_location) - 1
        prefix = source[firstindex(source):prevind(source, absolute_evidence)]
        suffix = source[absolute_evidence:end]
        prefix * replace(suffix,
            "kind = \"close_encounter_threshold_scale_staged\"" =>
                "kind = \"$replacement\""; count=1)
    end
    scale_one_as_tolerance = tamper_point_kind(text, "threshold_scale_1_0",
        "close_encounter_regularized_tolerance_staged")
    @test_throws ArgumentError read_investigation_series(IOBuffer(scale_one_as_tolerance))
    threshold_as_other_recognized = tamper_point_kind(text, "threshold_scale_0_5",
        "close_encounter_temporal_localization")
    @test_throws ArgumentError read_investigation_series(
        IOBuffer(threshold_as_other_recognized))

    tolerance_attempts = Tuple(synthetic_regularized_attempt(reference, tolerance)
        for tolerance in ValidationFramework.CLOSE_ENCOUNTER_REGULARIZED_TOLERANCES)
    tolerance_series = close_encounter_regularized_investigation_series(
        synthetic_regularized_suite(environment), tolerance_attempts).automatic
    tolerance_text = investigation_series_report_text(tolerance_series)
    @test tolerance_text == investigation_series_report_text(
        read_investigation_series(IOBuffer(tolerance_text)))
    threshold_kind_under_tolerance = replace(tolerance_text,
        "kind = \"close_encounter_regularized_tolerance_staged\"" =>
            "kind = \"close_encounter_threshold_scale_staged\""; count=1)
    @test_throws ArgumentError read_investigation_series(
        IOBuffer(threshold_kind_under_tolerance))
    for malformed in (
        tamper("threshold_scale_text = \"0.5\"", "threshold_scale_text = \"0.6\""),
        tamper("entry_threshold_text = \"0.05\"", "entry_threshold_text = \"0.06\""),
        tamper("ambiguity_threshold_text = \"0.125\"", "ambiguity_threshold_text = \"0.12\""),
        tamper("exit_threshold_text = \"0.125\"", "exit_threshold_text = \"0.13\""),
        tamper("regularized_tolerance_text = \"1.0e-12\"",
            "regularized_tolerance_text = \"1.0e-11\""),
        tamper("cartesian_tolerance_text = \"1.0e-13\"",
            "cartesian_tolerance_text = \"1.0e-12\""),
        tamper_after("[[points.independent_value]]", r"value_text = \"[^\"]+\"",
            "value_text = \"1.0\""),
        tamper_after("[[points.configuration.thresholds]]", r"value_text = \"[^\"]+\"",
            "value_text = \"0.06\""),
        text * "\n[points.supporting_evidence.comparison.sample_5]\n",
        text * "\n[points.supporting_evidence.comparison.sample_0]\n",
        tamper("[points.supporting_evidence.comparison.sample_3]",
            "[points.supporting_evidence.comparison.renamed_sample_3]"),
        tamper("[points.supporting_evidence.comparison.maximum]",
            "[points.supporting_evidence.comparison.renamed_maximum]"),
        text * "\n[points.supporting_evidence.comparison.maximum_2]\n",
        text * "\n[points.supporting_evidence.transition_3]\n",
        text * "\n[points.supporting_evidence.sampled_state_802]\n")
        @test_throws Exception read_investigation_series(IOBuffer(malformed))
    end
end

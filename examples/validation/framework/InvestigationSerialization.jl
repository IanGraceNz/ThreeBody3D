# Deterministic TOML persistence for Investigation 1 measurement series.

using StaticArrays: SVector

const INVESTIGATION_REPORT_KIND = "investigation_series"

function _write_investigation_definition(io, definition, heading)
    println(io, "[$heading]")
    _write_key_value(io, "family_id", definition.family_id)
    _write_key_value(io, "title", definition.title)
    _write_key_value(io, "description", definition.description)
    _write_key_value(io, "independent_variable", definition.independent_variable)
    _write_key_value(io, "required_metric_ids", definition.required_metric_ids)
    _write_key_value(io, "optional_metric_ids", definition.optional_metric_ids)
    _write_key_value(io, "definition_version", definition.definition_version)
    println(io)
    _write_definition(io, definition.benchmark, "$heading.benchmark")
    for control in definition.fixed_controls
        _write_parameter(io, control, "$heading.fixed_controls")
    end
end

function _write_performance_text(io, report, heading)
    println(io, "[$heading]")
    _write_key_value(io, "toml", performance_benchmark_text(report))
    println(io)
end

function _write_optional_tagged(io, name, value)
    isnothing(value) || _write_tagged_value(io, value; prefix=String(name))
end

function _read_optional_tagged(table, name)
    prefix = String(name)
    haskey(table, "$(prefix)_kind") ? _read_tagged_value(table; prefix) : nothing
end

function _write_transition_diagnostics(io, value, heading)
    value isa ThreeBody3D.RegularizationTransitionDiagnostics || throw(ArgumentError(
        "Unsupported transition diagnostics type $(typeof(value)).",
    ))
    println(io, "[$heading]")
    for name in fieldnames(typeof(value))
        _write_tagged_value(io, getfield(value, name); prefix=String(name))
    end
    println(io)
end

function _read_transition_diagnostics(table)
    values = map(fieldnames(ThreeBody3D.RegularizationTransitionDiagnostics)) do name
        _read_tagged_value(table; prefix=String(name))
    end
    ThreeBody3D.RegularizationTransitionDiagnostics(values...)
end

function _write_switch_event(io, event, heading)
    event isa ThreeBody3D.RegularizationSwitchEvent || throw(ArgumentError(
        "Unsupported switch-event type $(typeof(event)).",
    ))
    println(io, "[$heading]")
    for name in (:physical_time, :kind, :pair, :separations, :radial_rates, :isolation_ratio)
        _write_tagged_value(io, getfield(event, name); prefix=String(name))
    end
    println(io)
    _write_transition_diagnostics(io, event.transition_diagnostics, "$heading.transition_diagnostics")
end

function _read_switch_event(table)
    physical_time = _read_tagged_value(table; prefix="physical_time")
    diagnostics = _read_transition_diagnostics(table["transition_diagnostics"])
    T = typeof(physical_time)
    D = typeof(diagnostics)
    ThreeBody3D.RegularizationSwitchEvent{T,D}(
        physical_time,
        _read_tagged_value(table; prefix="kind"),
        _read_tagged_value(table; prefix="pair"),
        _read_tagged_value(table; prefix="separations"),
        _read_tagged_value(table; prefix="radial_rates"),
        _read_tagged_value(table; prefix="isolation_ratio"),
        diagnostics,
    )
end

function _write_competition_evidence(io, value, heading)
    value isa ThreeBody3D.AutomaticSwitchingCompetitionEvidence || throw(ArgumentError(
        "Unsupported competition-evidence type $(typeof(value)).",
    ))
    println(io, "[$heading]")
    for name in (
        :closest_index, :second_index, :closest_pair, :second_pair,
        :closest_separation, :second_separation, :absolute_separation_gap,
        :relative_separation_gap, :exact_closest_tie, :entry_margins,
        :exit_margin, :ambiguity_margin, :isolation_ratio_margin,
        :candidate_is_closest, :candidate_tied_for_closest, :crossing_provenance,
    )
        _write_optional_tagged(io, name, getfield(value, name))
    end
    _write_key_value(io, "candidate_pair_count", length(value.candidate_pairs))
    for (index, pair) in enumerate(value.candidate_pairs)
        _write_tagged_value(io, pair; prefix="candidate_pair_$index")
    end
    println(io)
end

function _read_competition_evidence(table)
    candidate_pairs = Tuple(
        _read_tagged_value(table; prefix="candidate_pair_$index")
        for index in 1:table["candidate_pair_count"]
    )
    closest_separation = _read_tagged_value(table; prefix="closest_separation")
    T = typeof(closest_separation)
    C = typeof(candidate_pairs)
    ThreeBody3D.AutomaticSwitchingCompetitionEvidence{T,C}(
        _read_tagged_value(table; prefix="closest_index"),
        _read_tagged_value(table; prefix="second_index"),
        _read_tagged_value(table; prefix="closest_pair"),
        _read_tagged_value(table; prefix="second_pair"),
        closest_separation,
        _read_tagged_value(table; prefix="second_separation"),
        _read_tagged_value(table; prefix="absolute_separation_gap"),
        _read_optional_tagged(table, :relative_separation_gap),
        _read_tagged_value(table; prefix="exact_closest_tie"),
        _read_tagged_value(table; prefix="entry_margins"),
        _read_optional_tagged(table, :exit_margin),
        _read_tagged_value(table; prefix="ambiguity_margin"),
        _read_tagged_value(table; prefix="isolation_ratio_margin"),
        candidate_pairs,
        _read_optional_tagged(table, :candidate_is_closest),
        _read_optional_tagged(table, :candidate_tied_for_closest),
        _read_tagged_value(table; prefix="crossing_provenance"),
    )
end

function _write_decision_evidence(io, value, heading)
    value isa ThreeBody3D.AutomaticSwitchingDecisionEvidence || throw(ArgumentError(
        "Unsupported decision-evidence type $(typeof(value)).",
    ))
    println(io, "[$heading]")
    for name in (
        :phase, :scale_kind, :reference_scale, :separations, :radial_rates,
        :collisions, :order, :isolation_ratio, :enter_threshold, :exit_threshold,
        :ambiguity_threshold, :minimum_separation_ratio, :candidate_mask,
        :candidate_count, :candidate_pair, :selected_pair, :selected_index, :second_index,
    )
        _write_optional_tagged(io, name, getfield(value, name))
    end
    println(io)
    _write_competition_evidence(io, value.competition, "$heading.competition")
end

function _read_decision_evidence(table)
    competition = _read_competition_evidence(table["competition"])
    reference_scale = _read_tagged_value(table; prefix="reference_scale")
    T = typeof(reference_scale)
    C = typeof(competition.candidate_pairs)
    ThreeBody3D.AutomaticSwitchingDecisionEvidence{T,C}(
        _read_tagged_value(table; prefix="phase"),
        _read_tagged_value(table; prefix="scale_kind"),
        reference_scale,
        _read_tagged_value(table; prefix="separations"),
        _read_tagged_value(table; prefix="radial_rates"),
        _read_tagged_value(table; prefix="collisions"),
        _read_tagged_value(table; prefix="order"),
        _read_tagged_value(table; prefix="isolation_ratio"),
        _read_tagged_value(table; prefix="enter_threshold"),
        _read_tagged_value(table; prefix="exit_threshold"),
        _read_tagged_value(table; prefix="ambiguity_threshold"),
        _read_tagged_value(table; prefix="minimum_separation_ratio"),
        _read_tagged_value(table; prefix="candidate_mask"),
        _read_tagged_value(table; prefix="candidate_count"),
        _read_optional_tagged(table, :candidate_pair),
        _read_optional_tagged(table, :selected_pair),
        _read_optional_tagged(table, :selected_index),
        _read_tagged_value(table; prefix="second_index"),
        competition,
    )
end

function _write_decision(io, value, heading)
    value isa ThreeBody3D.AutomaticSwitchingDecision || throw(ArgumentError(
        "Unsupported switching-decision type $(typeof(value)).",
    ))
    println(io, "[$heading]")
    _write_tagged_value(io, value.action; prefix="action")
    _write_optional_tagged(io, :pair, value.pair)
    _write_tagged_value(io, value.reason; prefix="reason")
    _write_key_value(io, "evidence_present", !isnothing(value.evidence))
    println(io)
    isnothing(value.evidence) || _write_decision_evidence(io, value.evidence, "$heading.evidence")
end

function _read_decision(table)
    evidence = table["evidence_present"] ? _read_decision_evidence(table["evidence"]) : nothing
    ThreeBody3D.AutomaticSwitchingDecision(
        _read_tagged_value(table; prefix="action"),
        _read_optional_tagged(table, :pair),
        _read_tagged_value(table; prefix="reason"),
        evidence,
    )
end

function _write_progress_evidence(io, value, heading)
    value isa ThreeBody3D.AutomaticSwitchingProgressEvidence || throw(ArgumentError(
        "Unsupported progress-evidence type $(typeof(value)).",
    ))
    println(io, "[$heading]")
    for name in fieldnames(typeof(value))
        _write_optional_tagged(io, name, getfield(value, name))
    end
    println(io)
end

function _read_progress_evidence(table)
    values = map(fieldnames(ThreeBody3D.AutomaticSwitchingProgressEvidence)) do name
        _read_optional_tagged(table, name)
    end
    ThreeBody3D.AutomaticSwitchingProgressEvidence(values...)
end

function _write_samples(io, samples, heading)
    samples isa ThreeBody3D.ExperimentalSwitchingSamples || throw(ArgumentError(
        "Unsupported switching-samples type $(typeof(samples)).",
    ))
    println(io, "[$heading]")
    _write_tagged_value(io, Tuple(samples.times); prefix="times")
    _write_key_value(io, "state_count", length(samples.states))
    for (index, state) in enumerate(samples.states)
        _write_tagged_value(io, Tuple(state); prefix="state_$index")
    end
    println(io)
end

function _read_samples(table)
    times_tuple = _read_tagged_value(table; prefix="times")
    T = eltype(times_tuple)
    times = T[times_tuple...]
    states = Vector{T}[
        T[_read_tagged_value(table; prefix="state_$index")...]
        for index in 1:table["state_count"]
    ]
    ThreeBody3D.ExperimentalSwitchingSamples(times, states)
end

function _write_diagnostics(io, diagnostics, heading)
    diagnostics isa ThreeBody3D.ExperimentalSwitchingDiagnosticsReport || throw(ArgumentError(
        "Unsupported switching-diagnostics type $(typeof(diagnostics)).",
    ))
    println(io, "[$heading]")
    for name in fieldnames(typeof(diagnostics))
        value = getfield(diagnostics, name)
        _write_tagged_value(io, value isa AbstractVector ? Tuple(value) : value; prefix=String(name))
    end
    println(io)
end

function _read_diagnostics(table)
    names = fieldnames(ThreeBody3D.ExperimentalSwitchingDiagnosticsReport)
    values = map(names) do name
        value = _read_tagged_value(table; prefix=String(name))
        name in (
            :initial_linear_momentum, :final_linear_momentum,
            :initial_angular_momentum, :final_angular_momentum,
        ) ? SVector(value...) : value
    end
    ThreeBody3D.ExperimentalSwitchingDiagnosticsReport(values...)
end

function _write_crossing_observation(io, observation, heading)
    observation isa KSSwitchingCrossingObservation || throw(ArgumentError(
        "Unsupported crossing-observation type $(typeof(observation)).",
    ))
    println(io, "[$heading]")
    for name in (:sequence_number, :kind, :successful_switch, :physical_time)
        _write_tagged_value(io, getfield(observation, name); prefix=String(name))
    end
    _write_optional_tagged(io, :sundman_time, observation.sundman_time)
    for name in (:event, :decision, :competition_evidence, :progress_evidence)
        _write_key_value(io, "$(name)_present", !isnothing(getfield(observation, name)))
    end
    println(io)
    isnothing(observation.event) || _write_switch_event(io, observation.event, "$heading.event")
    isnothing(observation.decision) || _write_decision(io, observation.decision, "$heading.decision")
    isnothing(observation.competition_evidence) || _write_competition_evidence(
        io, observation.competition_evidence, "$heading.competition_evidence",
    )
    isnothing(observation.progress_evidence) || _write_progress_evidence(
        io, observation.progress_evidence, "$heading.progress_evidence",
    )
end

function _read_crossing_observation(table)
    KSSwitchingCrossingObservation(
        _read_tagged_value(table; prefix="sequence_number"),
        _read_tagged_value(table; prefix="kind"),
        _read_tagged_value(table; prefix="successful_switch"),
        _read_tagged_value(table; prefix="physical_time"),
        _read_optional_tagged(table, :sundman_time),
        table["event_present"] ? _read_switch_event(table["event"]) : nothing,
        table["decision_present"] ? _read_decision(table["decision"]) : nothing,
        table["competition_evidence_present"] ?
            _read_competition_evidence(table["competition_evidence"]) : nothing,
        table["progress_evidence_present"] ?
            _read_progress_evidence(table["progress_evidence"]) : nothing,
    )
end

function _write_ks_supporting_evidence(io, report::KSSwitchingBackendReport, heading)
    println(io, "[$heading]")
    _write_key_value(io, "kind", "ks_switching_backend")
    _write_key_value(io, "backend", report.backend)
    _write_tagged_value(io, report.final_time; prefix="final_time")
    for name in (
        :maximum_scaled_backend_state_discrepancy,
        :entry_event_time_discrepancy,
        :exit_event_time_discrepancy,
    )
        _write_optional_tagged(io, name, getfield(report, name))
    end
    _write_key_value(io, "crossing_observation_count", length(report.crossing_observations))
    _write_key_value(io, "switch_event_count", length(report.switch_events))
    println(io)
    _write_execution(io, report.execution, "$heading.execution")
    _write_solver_statistics(io, report.solver_statistics, "$heading.solver_statistics")
    _write_samples(io, report.samples, "$heading.samples")
    _write_diagnostics(io, report.diagnostics, "$heading.diagnostics")
    for (index, observation) in enumerate(report.crossing_observations)
        _write_crossing_observation(io, observation, "$heading.crossing_observation_$index")
    end
    for (index, event) in enumerate(report.switch_events)
        _write_switch_event(io, event, "$heading.switch_event_$index")
    end
end

function _write_close_supporting_evidence(io, evidence::CloseEncounterTemporalLocalizationEvidence, heading)
    println(io, "[$heading]")
    _write_key_value(io, "kind", "close_encounter_temporal_localization")
    _write_key_value(io, "base_grid_convention", evidence.base_grid_convention)
    _write_key_value(io, "augmentation_convention", evidence.augmentation_convention)
    _write_key_value(io, "sample_count", length(evidence.samples))
    _write_key_value(io, "region_count", length(evidence.regions))
    println(io)
    boundaries = evidence.boundaries
    println(io, "[$heading.boundaries]")
    _write_key_value(io, "arithmetic", boundaries.arithmetic)
    _write_key_value(io, "precision_bits", boundaries.precision_bits)
    for name in (
        :entry_time, :entry_separation, :entry_residual,
        :periapsis_time, :periapsis_separation, :periapsis_residual,
        :exit_time, :exit_separation, :exit_residual,
    )
        _write_tagged_value(io, getfield(boundaries, name); prefix=String(name))
    end
    println(io)
    for (index, sample) in enumerate(evidence.samples)
        println(io, "[$heading.sample_$index]")
        _write_key_value(io, "location", sample.location)
        _write_key_value(io, "state_source", sample.state_source)
        for name in (:time, :pair_position_error, :pair_velocity_error, :full_state_error)
            _write_tagged_value(io, getfield(sample, name); prefix=String(name))
        end
        println(io)
    end
    for (index, region) in enumerate(evidence.regions)
        println(io, "[$heading.region_$index]")
        _write_key_value(io, "region", region.region)
        for name in (:pair_position_error, :pair_velocity_error, :full_state_error)
            _write_tagged_value(io, getfield(region, name); prefix=String(name))
        end
        println(io)
    end
end

function _write_regularized_transition(io, transition, heading)
    println(io, "[$heading]")
    _write_key_value(io, "pair", collect(transition.pair))
    for name in fieldnames(CloseEncounterTransitionEvidence)
        name == :pair && continue
        _write_tagged_value(io, getfield(transition, name); prefix=String(name))
    end
    println(io)
end

function _write_regularized_boundaries(io, boundaries, heading)
    println(io, "[$heading]")
    _write_key_value(io, "arithmetic", boundaries.arithmetic)
    _write_key_value(io, "precision_bits", boundaries.precision_bits)
    for name in (:entry_time, :entry_separation, :entry_residual,
        :periapsis_time, :periapsis_separation, :periapsis_residual,
        :exit_time, :exit_separation, :exit_residual)
        _write_tagged_value(io, getfield(boundaries, name); prefix=String(name))
    end
    println(io)
end

function _write_regularized_named_values(io, values, heading)
    println(io, "[$heading]")
    for name in keys(values)
        _write_tagged_value(io, getfield(values, name); prefix=String(name))
    end
    println(io)
end

function _write_regularized_supporting_evidence(io,
    evidence::CloseEncounterRegularizedPointEvidence, heading)
    println(io, "[$heading]")
    _write_key_value(io, "kind", "close_encounter_regularized_tolerance")
    _write_key_value(io, "method", evidence.method)
    _write_tagged_value(io, evidence.configuration.regularized_relative_tolerance;
        prefix="regularized_relative_tolerance")
    _write_tagged_value(io, evidence.configuration.regularized_absolute_tolerance;
        prefix="regularized_absolute_tolerance")
    _write_tagged_value(io, evidence.automatic_interval[1]; prefix="automatic_entry_time")
    _write_tagged_value(io, evidence.automatic_interval[2]; prefix="automatic_exit_time")
    _write_key_value(io, "comparison_grid_convention", evidence.comparison.comparison_grid_convention)
    _write_key_value(io, "comparison_epoch_count", evidence.comparison.comparison_epoch_count)
    _write_key_value(io, "periapsis_inside_interval", evidence.comparison.periapsis_inside_interval)
    _write_key_value(io, "sample_count", length(evidence.comparison.samples))
    _write_key_value(io, "transition_count", length(evidence.method_reference.transitions))
    println(io)
    _write_regularized_boundaries(io, evidence.boundaries, "$heading.boundaries")
    event = evidence.event_evidence
    println(io, "[$heading.events]")
    for name in fieldnames(CloseEncounterAutomaticEventEvidence)
        _write_tagged_value(io, getfield(event, name); prefix=String(name))
    end
    println(io)
    reference = evidence.method_reference
    println(io, "[$heading.method_reference]")
    _write_key_value(io, "method", reference.method)
    _write_key_value(io, "segment_count", reference.segment_count)
    _write_key_value(io, "switch_count", reference.switch_count)
    println(io)
    _write_regularized_named_values(io, reference.errors, "$heading.method_reference.errors")
    _write_regularized_named_values(io, reference.dense_periapsis, "$heading.method_reference.dense_periapsis")
    _write_regularized_named_values(io, reference.conservation, "$heading.method_reference.conservation")
    _write_regularized_named_values(io, reference.work, "$heading.method_reference.work")
    for (index, transition) in enumerate(reference.transitions)
        _write_regularized_transition(io, transition, "$heading.transition_$index")
    end
    for (index, sample) in enumerate(evidence.comparison.samples)
        println(io, "[$heading.sample_$index]")
        _write_key_value(io, "location", sample.location)
        for name in (:time, :pair_position_difference, :pair_velocity_difference, :full_state_difference)
            _write_tagged_value(io, getfield(sample, name); prefix=String(name))
        end
        println(io)
    end
    println(io, "[$heading.maximum_interval_difference]")
    for name in (:maximum_pair_position_difference, :maximum_pair_velocity_difference,
        :maximum_full_state_difference)
        _write_tagged_value(io, getfield(evidence.comparison, name); prefix=String(name))
    end
    println(io)
    endpoint = evidence.fictitious_endpoints
    println(io, "[$heading.fictitious_endpoints]")
    _write_tagged_value(io, endpoint.automatic.terminal_fictitious_time; prefix="automatic_terminal_fictitious_time")
    _write_tagged_value(io, endpoint.explicit.terminal_fictitious_time; prefix="explicit_terminal_fictitious_time")
    _write_tagged_value(io, endpoint.fictitious_time_difference; prefix="fictitious_time_difference")
    _write_tagged_value(io, endpoint.automatic.terminal_physical_time; prefix="automatic_terminal_physical_time")
    _write_tagged_value(io, endpoint.explicit.terminal_physical_time; prefix="explicit_terminal_physical_time")
    _write_tagged_value(io, endpoint.automatic.terminal_physical_time_residual; prefix="automatic_terminal_physical_time_residual")
    _write_tagged_value(io, endpoint.explicit.terminal_physical_time_residual; prefix="explicit_terminal_physical_time_residual")
    println(io)
end

function _write_staged_regularized_supporting_evidence(io,
    evidence::CloseEncounterRegularizedSupportingEvidence, heading)
    propagation = isnothing(evidence.method_evidence) ? evidence.propagation_evidence :
        evidence.method_evidence.propagation
    println(io, "[$heading]")
    threshold_family = propagation.configuration isa CloseEncounterThresholdScaleConfiguration
    _write_key_value(io, "kind", threshold_family ?
        "close_encounter_threshold_scale_staged" :
        "close_encounter_regularized_tolerance_staged")
    _write_key_value(io, "method", evidence.method)
    _write_key_value(io, "stage", evidence.stage)
    !isnothing(evidence.summary) && _write_key_value(io, "summary", evidence.summary)
    _write_key_value(io, "has_method_measurement", !isnothing(evidence.method_evidence))
    _write_key_value(io, "has_propagation_evidence", !isnothing(evidence.propagation_evidence))
    _write_key_value(io, "has_method_endpoint", !isnothing(evidence.method_evidence) &&
        !isnothing(evidence.method_evidence.endpoint))
    _write_key_value(io, "has_comparison", !isnothing(evidence.comparison))
    _write_key_value(io, "has_matched_endpoints", !isnothing(evidence.matched_endpoints))
    _write_key_value(io, "has_validated_event_evidence",
        propagation isa CloseEncounterRegularizedPropagationEvidence)
    _write_key_value(io, "sampled_state_count", length(propagation.sampled_states))
    _write_key_value(io, "transition_count", length(propagation.transitions))
    _write_tagged_value(io, propagation.configuration.regularized_relative_tolerance;
        prefix="regularized_tolerance")
    if threshold_family
        configuration = propagation.configuration
        _write_tagged_value(io, configuration.threshold_scale; prefix="threshold_scale")
        _write_tagged_value(io, configuration.entry_threshold; prefix="entry_threshold")
        _write_tagged_value(io, configuration.ambiguity_threshold; prefix="ambiguity_threshold")
        _write_tagged_value(io, configuration.exit_threshold; prefix="exit_threshold")
        _write_tagged_value(io, configuration.cartesian_relative_tolerance;
            prefix="cartesian_tolerance")
        _write_tagged_value(io, configuration.state_evaluation_tolerance;
            prefix="state_evaluation_tolerance")
    end
    _write_tagged_value(io, propagation.automatic_interval[1]; prefix="automatic_entry_time")
    _write_tagged_value(io, propagation.automatic_interval[2]; prefix="automatic_exit_time")
    _write_tagged_value(io, propagation.achieved_final_time; prefix="achieved_final_time")
    _write_key_value(io, "segment_count", propagation.segment_count)
    _write_key_value(io, "switch_count", propagation.switch_count)
    println(io)
    if propagation isa CloseEncounterRegularizedPropagationEvidence
        _write_regularized_boundaries(io, propagation.boundaries, "$heading.boundaries")
        println(io, "[$heading.events]")
        for name in fieldnames(CloseEncounterAutomaticEventEvidence)
            _write_tagged_value(io, getfield(propagation.event_evidence, name); prefix=String(name))
        end
        println(io)
    end
    _write_regularized_named_values(io, propagation.work, "$heading.work")
    for (index, transition) in enumerate(propagation.transitions)
        _write_regularized_transition(io, transition, "$heading.transition_$index")
    end
    for (index, state) in enumerate(propagation.sampled_states)
        println(io, "[$heading.sampled_state_$index]")
        _write_key_value(io, "component_count", length(state))
        for component in eachindex(state)
            _write_tagged_value(io, state[component]; prefix="component_$component")
        end
        println(io)
    end
    if !isnothing(evidence.method_evidence)
        method = evidence.method_evidence
        reference = method.reference
        println(io, "[$heading.method_reference]")
        _write_key_value(io, "method", reference.method)
        println(io)
        _write_regularized_named_values(io, reference.errors, "$heading.method_reference.errors")
        _write_regularized_named_values(io, reference.dense_periapsis, "$heading.method_reference.dense_periapsis")
        _write_regularized_named_values(io, reference.conservation, "$heading.method_reference.conservation")
        if !isnothing(method.endpoint)
            println(io, "[$heading.method_endpoint]")
            for name in (:automatic_exit_time, :terminal_fictitious_time,
                :terminal_physical_time, :terminal_physical_time_residual)
                _write_tagged_value(io, getfield(method.endpoint, name); prefix=String(name))
            end
            println(io)
        end
    end
    if !isnothing(evidence.comparison)
        comparison = evidence.comparison
        println(io, "[$heading.comparison]")
        _write_key_value(io, "comparison_grid_convention", comparison.comparison_grid_convention)
        _write_key_value(io, "comparison_epoch_count", comparison.comparison_epoch_count)
        _write_tagged_value(io, comparison.automatic_interval[1]; prefix="automatic_entry_time")
        _write_tagged_value(io, comparison.automatic_interval[2]; prefix="automatic_exit_time")
        println(io)
        for (index, sample) in enumerate(comparison.samples)
            println(io, "[$heading.comparison.sample_$index]")
            _write_key_value(io, "location", sample.location)
            for name in (:time, :pair_position_difference, :pair_velocity_difference, :full_state_difference)
                _write_tagged_value(io, getfield(sample, name); prefix=String(name))
            end
            println(io)
        end
        println(io, "[$heading.comparison.maximum]")
        for name in (:maximum_pair_position_difference, :maximum_pair_velocity_difference,
            :maximum_full_state_difference)
            _write_tagged_value(io, getfield(comparison, name); prefix=String(name))
        end
        println(io)
    end
    if !isnothing(evidence.matched_endpoints)
        endpoints = evidence.matched_endpoints
        println(io, "[$heading.matched_endpoints]")
        _write_tagged_value(io, endpoints.automatic.automatic_exit_time; prefix="automatic_exit_time")
        _write_tagged_value(io, endpoints.explicit.automatic_exit_time; prefix="explicit_exit_time")
        _write_tagged_value(io, endpoints.automatic.terminal_fictitious_time; prefix="automatic_terminal_fictitious_time")
        _write_tagged_value(io, endpoints.automatic.terminal_physical_time; prefix="automatic_terminal_physical_time")
        _write_tagged_value(io, endpoints.automatic.terminal_physical_time_residual; prefix="automatic_terminal_physical_time_residual")
        _write_tagged_value(io, endpoints.explicit.terminal_fictitious_time; prefix="explicit_terminal_fictitious_time")
        _write_tagged_value(io, endpoints.explicit.terminal_physical_time; prefix="explicit_terminal_physical_time")
        _write_tagged_value(io, endpoints.explicit.terminal_physical_time_residual; prefix="explicit_terminal_physical_time_residual")
        _write_tagged_value(io, endpoints.fictitious_time_difference; prefix="fictitious_time_difference")
        println(io)
    end
end

function _write_supporting_evidence(io, evidence, heading)
    isnothing(evidence) && return
    evidence isa KSSwitchingBackendReport &&
        return _write_ks_supporting_evidence(io, evidence, heading)
    evidence isa CloseEncounterTemporalLocalizationEvidence &&
        return _write_close_supporting_evidence(io, evidence, heading)
    evidence isa CloseEncounterRegularizedPointEvidence &&
        return _write_regularized_supporting_evidence(io, evidence, heading)
    if evidence isa CloseEncounterRegularizedSupportingEvidence
        return _write_staged_regularized_supporting_evidence(io, evidence, heading)
    end
    throw(ArgumentError("Unsupported investigation supporting evidence type $(typeof(evidence))."))
end

function _read_regularized_boundaries(table)
    names = (:entry_time, :entry_separation, :entry_residual,
        :periapsis_time, :periapsis_separation, :periapsis_residual,
        :exit_time, :exit_separation, :exit_residual)
    CloseEncounterReferenceBoundaries(
        (map(name -> _read_tagged_value(table; prefix=String(name)), names))...,
        Symbol(table["arithmetic"]), Int(table["precision_bits"]))
end

function _read_regularized_named_values(table, names)
    NamedTuple{names}(Tuple(_read_tagged_value(table; prefix=String(name)) for name in names))
end

function _read_regularized_transition(table)
    names = (:physical_time, :state_residual, :position_residual, :velocity_residual,
        :energy_jump, :momentum_jump, :angular_momentum_jump,
        :center_of_mass_jump, :center_of_mass_velocity_jump)
    values = _read_regularized_named_values(table, names)
    CloseEncounterTransitionEvidence(merge(values, (pair=Tuple(Int.(table["pair"])),)))
end

function _read_regularized_supporting_evidence(table)
    get(table, "sample_count", nothing) == 4 || throw(ArgumentError("Regularised evidence requires four ordered samples."))
    get(table, "transition_count", nothing) == 2 || throw(ArgumentError("Regularised evidence requires two transitions."))
    method = Symbol(table["method"])
    tolerance = _read_tagged_value(table; prefix="regularized_relative_tolerance")
    tolerance == _read_tagged_value(table; prefix="regularized_absolute_tolerance") || throw(ArgumentError("Regularised tolerances differ."))
    configuration = CloseEncounterRegularizedToleranceConfiguration(tolerance)
    boundaries = _read_regularized_boundaries(table["boundaries"])
    event_names = fieldnames(CloseEncounterAutomaticEventEvidence)
    event_values = _read_regularized_named_values(table["events"], event_names)
    # Reconstruct through the invariant-preserving field constructor because serialized
    # event evidence no longer contains raw controller events.
    event = CloseEncounterAutomaticEventEvidence(
        event_values.automatic_entry_time, event_values.automatic_exit_time,
        event_values.reference_entry_time, event_values.reference_exit_time,
        event_values.signed_entry_time_difference, event_values.absolute_entry_time_error,
        event_values.signed_exit_time_difference, event_values.absolute_exit_time_error,
        event_values.entry_separation, event_values.entry_threshold_residual,
        event_values.exit_separation, event_values.exit_threshold_residual,
        event_values.entry_radial_rate, event_values.exit_radial_rate)
    reference_table = table["method_reference"]
    Symbol(reference_table["method"]) == method || throw(ArgumentError("Serialized method identifiers differ."))
    error_names = (:maximum_position, :maximum_velocity, :maximum_full_state, :maximum_combined,
        :final_position, :final_velocity, :final_full_state, :final_combined)
    dense_names = (:time, :separation, :radial_numerator, :time_error, :separation_error)
    conservation_names = (:maximum_relative_energy_drift, :maximum_momentum_drift,
        :maximum_angular_momentum_drift, :maximum_com_residual, :minimum_separation)
    work_names = (:saved_states, :accepted_steps, :rejected_steps, :rhs_evaluations)
    transitions = ntuple(i -> _read_regularized_transition(table["transition_$i"]), 2)
    reference = CloseEncounterMethodReferenceEvidence(method, boundaries,
        _read_regularized_named_values(reference_table["errors"], error_names),
        _read_regularized_named_values(reference_table["dense_periapsis"], dense_names),
        _read_regularized_named_values(reference_table["conservation"], conservation_names),
        _read_regularized_named_values(reference_table["work"], work_names),
        Int(reference_table["segment_count"]), Int(reference_table["switch_count"]), transitions)
    samples = ntuple(4) do index
        sample = table["sample_$index"]
        differences = (pair_position=_read_tagged_value(sample; prefix="pair_position_difference"),
            pair_velocity=_read_tagged_value(sample; prefix="pair_velocity_difference"),
            full_state=_read_tagged_value(sample; prefix="full_state_difference"))
        CloseEncounterMethodDifferenceSample(Symbol(sample["location"]),
            _read_tagged_value(sample; prefix="time"), differences)
    end
    maximum_table = table["maximum_interval_difference"]
    maxima = (pair_position=_read_tagged_value(maximum_table; prefix="maximum_pair_position_difference"),
        pair_velocity=_read_tagged_value(maximum_table; prefix="maximum_pair_velocity_difference"),
        full_state=_read_tagged_value(maximum_table; prefix="maximum_full_state_difference"))
    interval = (Float64(_read_tagged_value(table; prefix="automatic_entry_time")),
        Float64(_read_tagged_value(table; prefix="automatic_exit_time")))
    comparison = CloseEncounterAutomaticExplicitComparisonEvidence(interval, samples, maxima,
        Int(table["comparison_epoch_count"]), table["comparison_grid_convention"],
        Bool(table["periapsis_inside_interval"]))
    endpoint_table = table["fictitious_endpoints"]
    automatic_endpoint = CloseEncounterMethodFictitiousEndpointEvidence(:automatic,
        interval[2], _read_tagged_value(endpoint_table; prefix="automatic_terminal_fictitious_time"),
        _read_tagged_value(endpoint_table; prefix="automatic_terminal_physical_time"),
        _read_tagged_value(endpoint_table; prefix="automatic_terminal_physical_time_residual"))
    explicit_endpoint = CloseEncounterMethodFictitiousEndpointEvidence(:explicit,
        interval[2], _read_tagged_value(endpoint_table; prefix="explicit_terminal_fictitious_time"),
        _read_tagged_value(endpoint_table; prefix="explicit_terminal_physical_time"),
        _read_tagged_value(endpoint_table; prefix="explicit_terminal_physical_time_residual"))
    endpoints = CloseEncounterMatchedEndpointEvidence(automatic_endpoint, explicit_endpoint,
        _read_tagged_value(endpoint_table; prefix="fictitious_time_difference"))
    CloseEncounterRegularizedPointEvidence(method, configuration, boundaries, interval,
        reference, event, comparison, endpoints)
end

function _read_staged_regularized_supporting_evidence(table; threshold_family=false)
    method = Symbol(table["method"])
    stage = Symbol(table["stage"])
    has_method_measurement = Bool(table["has_method_measurement"])
    has_method_endpoint = Bool(table["has_method_endpoint"])
    has_comparison = Bool(table["has_comparison"])
    has_matched_endpoints = Bool(table["has_matched_endpoints"])
    has_method_measurement == haskey(table, "method_reference") ||
        throw(ArgumentError("Method-measurement flag differs from serialized tables."))
    has_method_endpoint == haskey(table, "method_endpoint") ||
        throw(ArgumentError("Method-endpoint flag differs from serialized tables."))
    has_comparison == haskey(table, "comparison") ||
        throw(ArgumentError("Comparison flag differs from serialized tables."))
    has_matched_endpoints == haskey(table, "matched_endpoints") ||
        throw(ArgumentError("Matched-endpoint flag differs from serialized tables."))
    has_method_endpoint && !has_method_measurement &&
        throw(ArgumentError("Method endpoint cannot exist without method measurement."))
    has_propagation_evidence = Bool(get(table, "has_propagation_evidence",
        !has_method_measurement))
    has_method_measurement || has_propagation_evidence ||
        throw(ArgumentError("Serialized staged evidence retains no method or propagation evidence."))
    has_method_measurement && has_propagation_evidence &&
        throw(ArgumentError("Serialized staged evidence retains contradictory complete and partial evidence."))
    configuration = if threshold_family
        scale = _read_tagged_value(table; prefix="threshold_scale")
        regularized_tolerance = _read_tagged_value(table; prefix="regularized_tolerance")
        cartesian_tolerance = _read_tagged_value(table; prefix="cartesian_tolerance")
        CloseEncounterThresholdScaleConfiguration(scale,
            regularized_tolerance, regularized_tolerance,
            cartesian_tolerance, cartesian_tolerance,
            _read_tagged_value(table; prefix="entry_threshold"),
            _read_tagged_value(table; prefix="ambiguity_threshold"),
            _read_tagged_value(table; prefix="exit_threshold"),
            _read_tagged_value(table; prefix="state_evaluation_tolerance"),
            0.1, 256, 256)
    else
        CloseEncounterRegularizedToleranceConfiguration(
            _read_tagged_value(table; prefix="regularized_tolerance"))
    end
    interval = (Float64(_read_tagged_value(table; prefix="automatic_entry_time")),
        Float64(_read_tagged_value(table; prefix="automatic_exit_time")))
    transition_count = Int(get(table, "transition_count", 2))
    transition_count in (0, 2) || throw(ArgumentError("Staged transition count is invalid."))
    transition_keys = Set("transition_$index" for index in 1:transition_count)
    actual_transition_keys = Set(String(key) for key in keys(table)
        if occursin(r"^transition_\d+$", String(key)))
    actual_transition_keys == transition_keys ||
        throw(ArgumentError("Serialized transition tables differ from transition_count."))
    transitions = ntuple(index -> _read_regularized_transition(table["transition_$index"]),
        transition_count)
    work_names = (:saved_states, :accepted_steps, :rejected_steps, :rhs_evaluations)
    work = _read_regularized_named_values(table["work"], work_names)
    state_count = Int(table["sampled_state_count"])
    state_keys = Set("sampled_state_$index" for index in 1:state_count)
    actual_state_keys = Set(String(key) for key in keys(table)
        if occursin(r"^sampled_state_\d+$", String(key)))
    actual_state_keys == state_keys ||
        throw(ArgumentError("Serialized sampled-state tables differ from sampled_state_count."))
    states = ntuple(state_count) do index
        state_table = table["sampled_state_$index"]
        get(state_table, "component_count", nothing) == 18 ||
            throw(ArgumentError("Staged sampled state must contain 18 components."))
        Float64[_read_tagged_value(state_table; prefix="component_$component")
            for component in 1:18]
    end
    facts = CloseEncounterRegularizedPropagationFacts(configuration, method,
        interval, _read_tagged_value(table; prefix="achieved_final_time"),
        transitions, states, work, Int(table["segment_count"]), Int(table["switch_count"]))
    validated = Bool(get(table, "has_validated_event_evidence", true))
    has_boundaries = haskey(table, "boundaries")
    has_events = haskey(table, "events")
    has_boundaries == has_events ||
        throw(ArgumentError("Serialized boundaries and events tables must appear together."))
    validated == (has_boundaries && has_events) ||
        throw(ArgumentError("Validated-event flag differs from serialized tables."))
    boundaries = validated ? _read_regularized_boundaries(table["boundaries"]) : nothing
    propagation = if validated
        event_names = fieldnames(CloseEncounterAutomaticEventEvidence)
        event_values = _read_regularized_named_values(table["events"], event_names)
        event = CloseEncounterAutomaticEventEvidence(
            (getfield(event_values, name) for name in event_names)...;
            entry_threshold=configuration.entry_threshold,
            exit_threshold=configuration.exit_threshold)
        CloseEncounterRegularizedPropagationEvidence(facts, boundaries, event)
    else
        facts
    end
    method_evidence = if has_method_measurement
        propagation isa CloseEncounterRegularizedPropagationEvidence ||
            throw(ArgumentError("Method measurement requires validated propagation evidence."))
        reference_table = table["method_reference"]
        Symbol(reference_table["method"]) == method ||
            throw(ArgumentError("Staged method identifiers differ."))
        error_names = (:maximum_position, :maximum_velocity, :maximum_full_state,
            :maximum_combined, :final_position, :final_velocity, :final_full_state,
            :final_combined)
        dense_names = (:time, :separation, :radial_numerator, :time_error, :separation_error)
        conservation_names = (:maximum_relative_energy_drift, :maximum_momentum_drift,
            :maximum_angular_momentum_drift, :maximum_com_residual, :minimum_separation)
        reference = CloseEncounterMethodReferenceEvidence(method, boundaries,
            _read_regularized_named_values(reference_table["errors"], error_names),
            _read_regularized_named_values(reference_table["dense_periapsis"], dense_names),
            _read_regularized_named_values(reference_table["conservation"], conservation_names),
            work, propagation.segment_count, propagation.switch_count, transitions)
        endpoint = if has_method_endpoint
            endpoint_table = table["method_endpoint"]
            CloseEncounterMethodFictitiousEndpointEvidence(method,
                _read_tagged_value(endpoint_table; prefix="automatic_exit_time"),
                _read_tagged_value(endpoint_table; prefix="terminal_fictitious_time"),
                _read_tagged_value(endpoint_table; prefix="terminal_physical_time"),
                _read_tagged_value(endpoint_table; prefix="terminal_physical_time_residual"))
        else
            nothing
        end
        CloseEncounterRegularizedMethodEvidence(propagation, reference, endpoint)
    else
        nothing
    end
    comparison = if has_comparison
        comparison_table = table["comparison"]
        expected_ordered_tables = Set(["sample_1", "sample_2", "sample_3", "sample_4", "maximum"])
        actual_ordered_tables = Set(String(key) for key in keys(comparison_table)
            if occursin(r"^sample_\d+$", String(key)) ||
                String(key) == "maximum" || occursin(r"^maximum_\d+$", String(key)))
        actual_ordered_tables == expected_ordered_tables ||
            throw(ArgumentError("Serialized comparison tables are not the exact ordered evidence set."))
        samples = ntuple(4) do index
            sample = comparison_table["sample_$index"]
            differences = (pair_position=_read_tagged_value(sample; prefix="pair_position_difference"),
                pair_velocity=_read_tagged_value(sample; prefix="pair_velocity_difference"),
                full_state=_read_tagged_value(sample; prefix="full_state_difference"))
            CloseEncounterMethodDifferenceSample(Symbol(sample["location"]),
                _read_tagged_value(sample; prefix="time"), differences)
        end
        maximum_table = comparison_table["maximum"]
        maxima = (pair_position=_read_tagged_value(maximum_table; prefix="maximum_pair_position_difference"),
            pair_velocity=_read_tagged_value(maximum_table; prefix="maximum_pair_velocity_difference"),
            full_state=_read_tagged_value(maximum_table; prefix="maximum_full_state_difference"))
        comparison_interval = (
            Float64(_read_tagged_value(comparison_table; prefix="automatic_entry_time")),
            Float64(_read_tagged_value(comparison_table; prefix="automatic_exit_time")))
        CloseEncounterAutomaticExplicitComparisonEvidence(comparison_interval, samples, maxima,
            Int(comparison_table["comparison_epoch_count"]),
            comparison_table["comparison_grid_convention"], true)
    else
        nothing
    end
    matched = if has_matched_endpoints
        endpoint_table = table["matched_endpoints"]
        automatic = CloseEncounterMethodFictitiousEndpointEvidence(:automatic,
            _read_tagged_value(endpoint_table; prefix="automatic_exit_time"),
            _read_tagged_value(endpoint_table; prefix="automatic_terminal_fictitious_time"),
            _read_tagged_value(endpoint_table; prefix="automatic_terminal_physical_time"),
            _read_tagged_value(endpoint_table; prefix="automatic_terminal_physical_time_residual"))
        explicit = CloseEncounterMethodFictitiousEndpointEvidence(:explicit,
            _read_tagged_value(endpoint_table; prefix="explicit_exit_time"),
            _read_tagged_value(endpoint_table; prefix="explicit_terminal_fictitious_time"),
            _read_tagged_value(endpoint_table; prefix="explicit_terminal_physical_time"),
            _read_tagged_value(endpoint_table; prefix="explicit_terminal_physical_time_residual"))
        CloseEncounterMatchedEndpointEvidence(automatic, explicit,
            _read_tagged_value(endpoint_table; prefix="fictitious_time_difference"))
    else
        nothing
    end
    CloseEncounterRegularizedSupportingEvidence(method, method_evidence,
        isnothing(method_evidence) ? propagation : nothing, comparison, matched, stage;
        summary=get(table, "summary", nothing))
end

"""Write one investigation series in deterministic schema-1 TOML text."""
function write_investigation_series(io::IO, series::InvestigationMeasurementSeries)
    environments = Tuple(point.environment for point in series.points)
    schema_version = first(environments).schema_version
    all(environment -> environment.schema_version == schema_version, environments) || throw(
        ArgumentError("Every point environment must use the report schema version."),
    )
    _write_key_value(io, "schema_identity", VALIDATION_SCHEMA_IDENTITY)
    _write_key_value(io, "report_kind", INVESTIGATION_REPORT_KIND)
    _write_key_value(io, "schema_version", schema_version)
    _write_key_value(io, "series_id", series.series_id)
    _write_key_value(io, "title", series.title)
    _write_key_value(io, "description", series.description)
    println(io)
    _write_investigation_definition(io, series.definition, "definition")
    for point in series.points
        println(io, "[[points]]")
        _write_key_value(io, "point_id", point.point_id)
        !isnothing(point.notes) && _write_key_value(io, "notes", point.notes)
        println(io)
        _write_configuration(io, point.configuration, "points.configuration")
        _write_parameter(io, point.independent_value, "points.independent_value")
        _write_environment(io, point.environment, "points.environment")
        _write_execution(io, point.execution, "points.execution")
        for metric in point.metrics
            _write_metric(io, metric, "points.metrics")
        end
        !isnothing(point.solver_statistics) &&
            _write_solver_statistics(io, point.solver_statistics, "points.solver_statistics")
        !isnothing(point.performance_report) &&
            _write_performance_text(io, point.performance_report, "points.performance_report")
        _write_supporting_evidence(io, point.supporting_evidence, "points.supporting_evidence")
    end
    nothing
end

investigation_series_report_text(series::InvestigationMeasurementSeries) =
    _report_text(write_investigation_series, series)

function _read_investigation_definition(table)
    InvestigationDefinition(
        Symbol(table["family_id"]), table["title"], table["description"],
        _read_definition(table["benchmark"]), Symbol(table["independent_variable"]),
        Tuple(_read_parameter(item) for item in get(table, "fixed_controls", Any[])),
        Tuple(Symbol.(table["required_metric_ids"])),
        Tuple(Symbol.(table["optional_metric_ids"])), table["definition_version"],
    )
end

function _read_ks_supporting_evidence(table, definition, configuration, environment)
    observations = Tuple(
        _read_crossing_observation(table["crossing_observation_$index"])
        for index in 1:table["crossing_observation_count"]
    )
    switch_events = Tuple(
        _read_switch_event(table["switch_event_$index"])
        for index in 1:table["switch_event_count"]
    )
    KSSwitchingBackendReport(
        Symbol(table["backend"]), definition.benchmark, configuration, environment,
        _read_execution(table["execution"]),
        _read_tagged_value(table; prefix="final_time"), _read_samples(table["samples"]),
        _read_diagnostics(table["diagnostics"]),
        _read_solver_statistics(table["solver_statistics"]), observations, switch_events,
        _read_optional_tagged(table, :maximum_scaled_backend_state_discrepancy),
        _read_optional_tagged(table, :entry_event_time_discrepancy),
        _read_optional_tagged(table, :exit_event_time_discrepancy),
    )
end

function _read_close_supporting_evidence(table)
    get(table, "sample_count", nothing) == 4 ||
        throw(ArgumentError("Close-encounter evidence requires four samples."))
    get(table, "region_count", nothing) == 3 ||
        throw(ArgumentError("Close-encounter evidence requires three regions."))
    boundaries_table = get(table, "boundaries", nothing)
    isnothing(boundaries_table) && throw(ArgumentError("Close-encounter boundaries are missing."))
    boundary_names = (
        :entry_time, :entry_separation, :entry_residual,
        :periapsis_time, :periapsis_separation, :periapsis_residual,
        :exit_time, :exit_separation, :exit_residual,
    )
    values = map(name -> _read_tagged_value(boundaries_table; prefix=String(name)),
        boundary_names)
    boundaries = CloseEncounterReferenceBoundaries(
        values...,
        Symbol(boundaries_table["arithmetic"]),
        Int(boundaries_table["precision_bits"]),
    )
    samples = ntuple(4) do index
        sample = get(table, "sample_$index", nothing)
        isnothing(sample) && throw(ArgumentError("Close-encounter sample $index is missing."))
        values = map(name -> _read_tagged_value(sample; prefix=String(name)),
            (:time, :pair_position_error, :pair_velocity_error, :full_state_error))
        CloseEncounterLocalErrorSample(
            Symbol(sample["location"]), values[1], Symbol(sample["state_source"]),
            values[2], values[3], values[4],
        )
    end
    regions = ntuple(3) do index
        region = get(table, "region_$index", nothing)
        isnothing(region) && throw(ArgumentError("Close-encounter region $index is missing."))
        values = map(name -> _read_tagged_value(region; prefix=String(name)),
            (:pair_position_error, :pair_velocity_error, :full_state_error))
        CloseEncounterRegionMaximum(Symbol(region["region"]), values...)
    end
    CloseEncounterTemporalLocalizationEvidence(
        boundaries, samples, regions;
        base_grid_convention=table["base_grid_convention"],
        augmentation_convention=table["augmentation_convention"],
    )
end

"""Read and validate one deterministic investigation-series TOML report."""
function read_investigation_series(source)
    data = source isa IO ? TOML.parse(read(source, String)) : TOML.parsefile(source)
    _validate_report_header(data, INVESTIGATION_REPORT_KIND)
    definition = _read_investigation_definition(data["definition"])
    threshold_definition = definition.family_id in (
        :close_encounter_automatic_threshold_scale,
        :close_encounter_explicit_threshold_scale)
    points = map(get(data, "points", Any[])) do table
        configuration = _read_configuration(table["configuration"])
        environment = _read_environment(table["environment"])
        environment.schema_version == data["schema_version"] || throw(ArgumentError(
            "Point environment schema version does not match the report header.",
        ))
        execution = _read_execution(table["execution"])
        evidence = if haskey(table, "supporting_evidence")
            evidence_table = table["supporting_evidence"]
            kind = get(evidence_table, "kind", nothing)
            if threshold_definition
                kind == "close_encounter_threshold_scale_staged" ||
                    throw(ArgumentError(
                        "Threshold-scale definitions require threshold-scale staged evidence."))
            elseif kind == "close_encounter_threshold_scale_staged"
                throw(ArgumentError(
                    "Threshold-scale staged evidence requires a threshold-scale definition."))
            end
            if kind == "ks_switching_backend"
                _read_ks_supporting_evidence(
                    evidence_table, definition, configuration, environment,
                )
            elseif kind == "close_encounter_temporal_localization"
                _read_close_supporting_evidence(evidence_table)
            elseif kind == "close_encounter_regularized_tolerance"
                _read_regularized_supporting_evidence(evidence_table)
            elseif kind == "close_encounter_regularized_tolerance_staged"
                _read_staged_regularized_supporting_evidence(evidence_table)
            elseif kind == "close_encounter_threshold_scale_staged"
                _read_staged_regularized_supporting_evidence(evidence_table;
                    threshold_family=true)
            else
                throw(ArgumentError("Unsupported supporting evidence kind."))
            end
        else
            nothing
        end
        performance = haskey(table, "performance_report") ?
            read_performance_benchmark(IOBuffer(table["performance_report"]["toml"])) : nothing
        independent = only(get(table, "independent_value", Any[]))
        independent_parameter = _read_parameter(independent)
        threshold_definition && !isnothing(evidence) &&
            _validate_close_threshold_serialized_point(evidence, definition,
                configuration, independent_parameter)
        InvestigationMeasurementPoint(
            Symbol(table["point_id"]), definition, configuration, independent_parameter,
            environment, execution,
            Tuple(_read_metric(item) for item in get(table, "metrics", Any[])),
            haskey(table, "solver_statistics") ?
                _read_solver_statistics(table["solver_statistics"]) : nothing;
            performance_report=performance, supporting_evidence=evidence,
            notes=get(table, "notes", nothing),
        )
    end
    InvestigationMeasurementSeries(
        Symbol(data["series_id"]), data["title"], data["description"], definition, Tuple(points),
    )
end

write_investigation_series_atomic(path::AbstractString, series::InvestigationMeasurementSeries) =
    write_report_atomic(path, series)

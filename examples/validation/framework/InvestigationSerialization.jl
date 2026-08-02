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

function _write_supporting_evidence(io, evidence, heading)
    isnothing(evidence) && return
    evidence isa KSSwitchingBackendReport &&
        return _write_ks_supporting_evidence(io, evidence, heading)
    evidence isa CloseEncounterTemporalLocalizationEvidence &&
        return _write_close_supporting_evidence(io, evidence, heading)
    throw(ArgumentError("Unsupported investigation supporting evidence type $(typeof(evidence))."))
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
            if kind == "ks_switching_backend"
                _read_ks_supporting_evidence(
                    evidence_table, definition, configuration, environment,
                )
            elseif kind == "close_encounter_temporal_localization"
                _read_close_supporting_evidence(evidence_table)
            else
                throw(ArgumentError("Unsupported supporting evidence kind."))
            end
        else
            nothing
        end
        performance = haskey(table, "performance_report") ?
            read_performance_benchmark(IOBuffer(table["performance_report"]["toml"])) : nothing
        independent = only(get(table, "independent_value", Any[]))
        InvestigationMeasurementPoint(
            Symbol(table["point_id"]), definition, configuration, _read_parameter(independent),
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

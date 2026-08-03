# I2-C3: matched automatic/explicit switching-threshold evidence.

const CLOSE_ENCOUNTER_THRESHOLD_SCALES = (0.5, 1.0, 2.0)
const CLOSE_ENCOUNTER_THRESHOLD_DEFINITION_VERSION = "2.0.0"

function _close_threshold_values(scale::Float64)
    scale == 0.5 && return (0.05, 0.125, 0.125)
    scale == 1.0 && return (0.1, 0.25, 0.25)
    scale == 2.0 && return (0.2, 0.5, 0.5)
    throw(ArgumentError("Unsupported close-encounter threshold scale."))
end

struct CloseEncounterThresholdScaleConfiguration <: AbstractCloseEncounterRegularizedConfiguration
    threshold_scale::Float64
    regularized_relative_tolerance::Float64
    regularized_absolute_tolerance::Float64
    cartesian_relative_tolerance::Float64
    cartesian_absolute_tolerance::Float64
    entry_threshold::Float64
    ambiguity_threshold::Float64
    exit_threshold::Float64
    state_evaluation_tolerance::Float64
    regularized_initial_step::Float64
    regularized_maximum_iterations::Int
    state_evaluation_maximum_iterations::Int

    function CloseEncounterThresholdScaleConfiguration(scale::Real,
        regularized_relative_tolerance::Real, regularized_absolute_tolerance::Real,
        cartesian_relative_tolerance::Real, cartesian_absolute_tolerance::Real,
        entry_threshold::Real, ambiguity_threshold::Real, exit_threshold::Real,
        state_evaluation_tolerance::Real, regularized_initial_step::Real,
        regularized_maximum_iterations::Integer,
        state_evaluation_maximum_iterations::Integer)
        normalized_scale = Float64(scale)
        entry, ambiguity, exit = _close_threshold_values(normalized_scale)
        values = (Float64(regularized_relative_tolerance), Float64(regularized_absolute_tolerance),
            Float64(cartesian_relative_tolerance), Float64(cartesian_absolute_tolerance),
            Float64(entry_threshold), Float64(ambiguity_threshold), Float64(exit_threshold),
            Float64(state_evaluation_tolerance), Float64(regularized_initial_step),
            Int(regularized_maximum_iterations), Int(state_evaluation_maximum_iterations))
        expected = (1e-12, 1e-12, 1e-13, 1e-13, entry, ambiguity, exit,
            1e-14, 0.1, 256, 256)
        values == expected || throw(ArgumentError(
            "Threshold-scale configuration differs from its approved controls."))
        ambiguity == exit || throw(ArgumentError(
            "Ambiguity threshold must equal the exit threshold."))
        new(normalized_scale, values...)
    end
end

function CloseEncounterThresholdScaleConfiguration(scale::Real)
    value = Float64(scale)
    entry, ambiguity, exit = _close_threshold_values(value)
    CloseEncounterThresholdScaleConfiguration(value, 1e-12, 1e-12, 1e-13, 1e-13,
        entry, ambiguity, exit, 1e-14, 0.1, 256, 256)
end

close_encounter_threshold_scale_configuration(scale) =
    CloseEncounterThresholdScaleConfiguration(scale)

_close_regularized_configuration_is_approved(c::CloseEncounterThresholdScaleConfiguration) =
    c == CloseEncounterThresholdScaleConfiguration(c.threshold_scale)

_close_regularized_controls(c::CloseEncounterThresholdScaleConfiguration) =
    CloseEncounterRegularizedExecutionControls(c.regularized_relative_tolerance,
        c.regularized_absolute_tolerance, c.cartesian_relative_tolerance,
        c.cartesian_absolute_tolerance, c.entry_threshold, c.ambiguity_threshold,
        c.exit_threshold, c.state_evaluation_tolerance, c.regularized_initial_step,
        c.regularized_maximum_iterations, c.state_evaluation_maximum_iterations)

function _close_threshold_fixed_controls(method)
    (ValidationParameter(:method, method), ValidationParameter(:selected_pair, (1, 2)),
        ValidationParameter(:physical_interval, (0.0, 1.6)),
        ValidationParameter(:physical_sample_step, 0.002),
        ValidationParameter(:cartesian_algorithm, :Vern9),
        ValidationParameter(:cartesian_solver_selector, :accurate),
        ValidationParameter(:cartesian_relative_tolerance, 1e-13),
        ValidationParameter(:cartesian_absolute_tolerance, 1e-13),
        ValidationParameter(:regularized_relative_tolerance, 1e-12),
        ValidationParameter(:regularized_absolute_tolerance, 1e-12),
        ValidationParameter(:threshold_mapping,
            "0.5:0.05:0.125:0.125;1.0:0.1:0.25:0.25;2.0:0.2:0.5:0.5"),
        ValidationParameter(:minimum_separation_ratio, 10.0),
        ValidationParameter(:maximum_switches, 10),
        ValidationParameter(:state_evaluation_tolerance, 1e-14),
        ValidationParameter(:state_evaluation_maximum_iterations, 256),
        ValidationParameter(:regularized_representation, :planar_levi_civita),
        ValidationParameter(:regularized_initial_step, 0.1),
        ValidationParameter(:regularized_maximum_iterations, 256),
        ValidationParameter(:explicit_interval_source, :corresponding_automatic_run),
        ValidationParameter(:reference_boundary_convention, :fixed_section_7_1),
        ValidationParameter(:reference_arithmetic, :BigFloat),
        ValidationParameter(:reference_precision, 256),
        ValidationParameter(:reference_solver_selector, :extreme),
        ValidationParameter(:reference_relative_tolerance, "1e-30"),
        ValidationParameter(:reference_absolute_tolerance, "1e-30"),
        ValidationParameter(:reference_dense_output, true),
        ValidationParameter(:reference_save_everystep, true))
end

function close_encounter_threshold_investigation_definition(method::Symbol)
    method in (:automatic, :explicit) || throw(ArgumentError("Unsupported regularised method."))
    id = Symbol(:close_encounter_, method, :_threshold_scale)
    InvestigationDefinition(id, "Close-encounter $(method) threshold-scale series",
        "Descriptive matched switching-threshold evidence using one independent reference.",
        close_encounter_case_definition(), :threshold_scale,
        _close_threshold_fixed_controls(method), _CLOSE_REGULARIZED_REQUIRED_METRICS, (),
        CLOSE_ENCOUNTER_THRESHOLD_DEFINITION_VERSION)
end

function _close_threshold_token(scale)
    index = findfirst(==(Float64(scale)), CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    isnothing(index) && throw(ArgumentError("Unsupported close-encounter threshold scale."))
    ("0_5", "1_0", "2_0")[index]
end

close_encounter_threshold_performance_benchmark_id(method, scale) =
    Symbol(:close_encounter_, method, :_threshold_scale_, _close_threshold_token(scale))

function close_encounter_threshold_performance_definition(method, configuration)
    method in (:automatic, :explicit) || throw(ArgumentError("Unsupported regularised method."))
    _close_regularized_configuration_is_approved(configuration) ||
        throw(ArgumentError("Threshold performance configuration is not approved."))
    PerformanceBenchmarkDefinition(close_encounter_threshold_performance_benchmark_id(
        method, configuration.threshold_scale),
        "Close-encounter $(method) threshold-scale point",
        method == :automatic ? "Automatic switching propagation only." :
            "Explicit composition only; corresponding automatic interval is untimed setup.",
        "examples/validation/performance/close_encounter_threshold_scale.jl",
        (:close_encounter, method, :threshold_scale),
        (:close_encounter, :investigation_2), CLOSE_ENCOUNTER_THRESHOLD_DEFINITION_VERSION,
        (:elapsed_time, :solver_statistics, :saved_states),
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md")
end

close_encounter_threshold_performance_operation(method, configuration; kwargs...) =
    close_encounter_regularized_performance_operation(method, configuration; kwargs...)

function close_encounter_threshold_performance_entry(method, configuration;
    policy=StandardBenchmark(), performance_directory=joinpath(@__DIR__, "..", "performance"))
    PerformanceBenchmarkEntry(close_encounter_threshold_performance_definition(method, configuration),
        _close_regularized_validation_configuration(configuration, method), policy,
        joinpath(performance_directory, "close_encounter_threshold_scale.jl"))
end

function close_encounter_threshold_performance_entries(; kwargs...)
    Tuple(close_encounter_threshold_performance_entry(method,
        CloseEncounterThresholdScaleConfiguration(scale); kwargs...)
        for method in (:automatic, :explicit) for scale in CLOSE_ENCOUNTER_THRESHOLD_SCALES)
end

function decode_close_encounter_threshold_benchmark_id(id::Symbol)
    for method in (:automatic, :explicit), scale in CLOSE_ENCOUNTER_THRESHOLD_SCALES
        close_encounter_threshold_performance_benchmark_id(method, scale) == id &&
            return (method=method,
                configuration=CloseEncounterThresholdScaleConfiguration(scale))
    end
    throw(ArgumentError("Unsupported close-encounter threshold benchmark ID $(id)."))
end

function _close_threshold_suite_reports(suite)
    expected = Tuple(close_encounter_threshold_performance_benchmark_id(method, scale)
        for method in (:automatic, :explicit) for scale in CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    ids = Tuple(report.definition.benchmark_id for report in suite.benchmarks)
    ids == expected || throw(ArgumentError(
        "Threshold performance reports are missing, extra, duplicated, or reordered."))
    reports = Dict{Symbol,PerformanceBenchmarkReport}()
    for report in suite.benchmarks
        decoded = decode_close_encounter_threshold_benchmark_id(report.definition.benchmark_id)
        _record_fields_equal(report.definition,
            close_encounter_threshold_performance_definition(decoded.method,
                decoded.configuration)) || throw(ArgumentError("Threshold performance definition differs."))
        _record_fields_equal(report.configuration,
            _close_regularized_validation_configuration(decoded.configuration, decoded.method)) ||
            throw(ArgumentError("Threshold performance configuration differs."))
        _record_fields_equal(report.policy, StandardBenchmark()) ||
            throw(ArgumentError("Threshold performance policy differs."))
        _record_fields_equal(report.environment, suite.environment) ||
            throw(ArgumentError("Threshold performance environment differs."))
        reports[report.definition.benchmark_id] = report
    end
    reports
end

function close_encounter_threshold_investigation_series(suite::PerformanceSuiteReport, attempts)
    ordered = Tuple(attempts)
    length(ordered) == 3 || throw(ArgumentError("Exactly three matched threshold attempts are required."))
    map(x -> x.configuration.threshold_scale, ordered) == CLOSE_ENCOUNTER_THRESHOLD_SCALES ||
        throw(ArgumentError("Matched threshold attempts are reordered."))
    all(attempt -> attempt.configuration isa CloseEncounterThresholdScaleConfiguration,
        ordered) || throw(ArgumentError("Threshold series contains the wrong experiment family."))
    all(attempt -> attempt.reference === first(ordered).reference, ordered) ||
        throw(ArgumentError("All matched attempts must reuse one reference execution."))
    reports = _close_threshold_suite_reports(suite)
    function make_series(method)
        definition = close_encounter_threshold_investigation_definition(method)
        points = map(ordered) do attempt
            evidence = method == :automatic ? attempt.automatic_evidence : attempt.explicit_evidence
            partial = method == :automatic ? attempt.automatic_partial : attempt.explicit_partial
            direct = _close_regularized_paired_direct_execution(attempt, method)
            id = close_encounter_threshold_performance_benchmark_id(method,
                attempt.configuration.threshold_scale)
            performance = reports[id]
            execution = _close_regularized_combined_execution(direct, performance.execution)
            propagation = isnothing(evidence) ? partial : evidence.propagation
            metrics = isnothing(evidence) ? () : isnothing(attempt.comparison) ?
                _close_regularized_method_metrics(evidence) :
                (_close_regularized_method_metrics(evidence)...,
                    _close_regularized_comparison_metrics(attempt.comparison)...)
            statistics = isnothing(propagation) ? nothing : SolverStatistics(
                accepted_steps=propagation.work.accepted_steps,
                rejected_steps=propagation.work.rejected_steps,
                rhs_evaluations=propagation.work.rhs_evaluations,
                saved_states=propagation.work.saved_states,
                segment_count=propagation.segment_count,
                switch_count=propagation.switch_count)
            stage = !isnothing(evidence) && !isnothing(attempt.comparison) &&
                !isnothing(attempt.matched_endpoints) ? :complete :
                !isnothing(evidence) && !isnothing(attempt.comparison) ? :comparison :
                !isnothing(evidence) ? :measurement : :propagation
            supporting_summary = stage == :complete ? nothing :
                (!isnothing(attempt.comparison_failure) ? attempt.comparison_failure : direct.summary)
            supporting = isnothing(propagation) ? nothing :
                CloseEncounterRegularizedSupportingEvidence(method, evidence, partial,
                    attempt.comparison, attempt.matched_endpoints, stage;
                    summary=supporting_summary)
            InvestigationMeasurementPoint(Symbol(:threshold_scale_,
                _close_threshold_token(attempt.configuration.threshold_scale)), definition,
                _close_regularized_validation_configuration(attempt.configuration, method),
                ValidationParameter(:threshold_scale, attempt.configuration.threshold_scale),
                suite.environment, execution, metrics, statistics;
                performance_report=performance, supporting_evidence=supporting,
                notes=execution.actual == actual_completed ? nothing : execution.summary)
        end
        InvestigationMeasurementSeries(definition.family_id, definition.title,
            definition.description, definition, Tuple(points))
    end
    (automatic=make_series(:automatic), explicit=make_series(:explicit))
end

function close_encounter_threshold_investigation_series(; performance_runner,
    reference_runner=build_close_encounter_reference,
    attempt_runner=attempt_close_encounter_regularized_pair)
    reference = reference_runner()
    attempts = Tuple(attempt_runner(CloseEncounterThresholdScaleConfiguration(scale), reference)
        for scale in CLOSE_ENCOUNTER_THRESHOLD_SCALES)
    suite = performance_runner(close_encounter_threshold_performance_entries())
    close_encounter_threshold_investigation_series(suite, attempts)
end

function _validate_close_threshold_serialized_point(evidence, definition,
    validation_configuration, independent)
    evidence isa CloseEncounterRegularizedSupportingEvidence ||
        throw(ArgumentError("Threshold point requires staged threshold evidence."))
    retained = isnothing(evidence.method_evidence) ? evidence.propagation_evidence :
        evidence.method_evidence.propagation
    configuration = retained.configuration
    configuration isa CloseEncounterThresholdScaleConfiguration ||
        throw(ArgumentError("Threshold point retained the wrong experiment family."))
    definition.family_id == Symbol(:close_encounter_, evidence.method, :_threshold_scale) &&
        definition.independent_variable == :threshold_scale ||
        throw(ArgumentError("Threshold point definition differs from retained evidence."))
    independent.parameter_id == :threshold_scale &&
        independent.value == configuration.threshold_scale ||
        throw(ArgumentError("Threshold independent value differs from retained evidence."))
    _record_fields_equal(validation_configuration,
        _close_regularized_validation_configuration(configuration, evidence.method)) ||
        throw(ArgumentError("Threshold validation configuration differs from retained evidence."))
    nothing
end

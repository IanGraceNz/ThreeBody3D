# Conditional Investigation 2 figure-eight arbitrary-precision confirmation.

const FIGURE_EIGHT_PRECISION_BITS = (128, 256, 384)
const FIGURE_EIGHT_PRECISION_SERIES_ID = :figure_eight_precision_confirmation
const FIGURE_EIGHT_PRECISION_TRIGGER_STATUSES = (:triggered, :not_triggered, :unavailable)
const FIGURE_EIGHT_PRECISION_DEFINITION_VERSION = "1.0.0"

function _derive_precision_trigger_fields(p12, p13, e12, e13)
    periodicity_factor = periodicity_condition = nothing
    if !isnothing(p12) && !isnothing(p13)
        if p12 == 0 && p13 == 0
            periodicity_factor, periodicity_condition = 1.0, true
        elseif iszero(p12) || iszero(p13)
            periodicity_condition = false
        else
            ratio = max(p12, p13) / min(p12, p13)
            periodicity_factor = isfinite(ratio) ? ratio : nothing
            periodicity_condition = max(p12, p13) < 2 * min(p12, p13)
        end
    end

    energy_factor = energy_condition = nothing
    energy_unbounded = false
    if !isnothing(e12) && !isnothing(e13)
        if e12 > 0 && e13 == 0
            energy_unbounded, energy_condition = true, true
        elseif e13 > 0
            ratio = e12 / e13
            energy_unbounded = !isfinite(ratio)
            energy_factor = energy_unbounded ? nothing : ratio
            energy_condition = e12 > 0 && e12 >= 10 * e13
        else
            energy_condition = false
        end
    end
    status = isnothing(periodicity_condition) || isnothing(energy_condition) ? :unavailable :
        periodicity_condition && energy_condition ? :triggered : :not_triggered
    (; periodicity_factor, periodicity_condition, energy_factor,
        energy_unbounded, energy_condition, status)
end

struct FigureEightPrecisionTriggerAssessment
    schema_version::String
    source_series_id::Symbol
    source_definition_version::String
    source_environment::ValidationEnvironment
    point_1e12_id::Symbol
    point_1e13_id::Symbol
    point_1e12_execution::ExecutionOutcome
    point_1e13_execution::ExecutionOutcome
    periodicity_error_1e12::Union{Nothing,Float64}
    periodicity_error_1e13::Union{Nothing,Float64}
    periodicity_change_factor::Union{Nothing,Float64}
    periodicity_condition::Union{Nothing,Bool}
    energy_drift_1e12::Union{Nothing,Float64}
    energy_drift_1e13::Union{Nothing,Float64}
    energy_improvement_factor::Union{Nothing,Float64}
    energy_improvement_unbounded::Bool
    energy_condition::Union{Nothing,Bool}
    status::Symbol
    summary::String

    function FigureEightPrecisionTriggerAssessment(schema_version, source_series_id,
        source_definition_version, source_environment, point_1e12_id, point_1e13_id,
        point_1e12_execution, point_1e13_execution, p12, p13, p_factor,
        p_condition, e12, e13, e_factor, e_unbounded, e_condition, status, summary)
        schema_version == source_environment.schema_version || throw(ArgumentError(
            "Trigger schema version differs from its source environment."))
        source_series_id == :figure_eight_vern9_tolerance || throw(ArgumentError(
            "Trigger source series identity differs."))
        approved = core_tolerance_investigation_definition(:figure_eight, :vern9)
        source_definition_version == approved.definition_version || throw(ArgumentError(
            "Trigger source definition version differs."))
        point_1e12_id == :tolerance_1e_12 && point_1e13_id == :tolerance_1e_13 ||
            throw(ArgumentError("Trigger source point identities differ."))
        for value in (p12, p13, e12, e13)
            isnothing(value) || (value isa Float64 && isfinite(value) && value >= 0) ||
                throw(ArgumentError("Trigger numerical values must be finite nonnegative Float64 values."))
        end
        derived = _derive_precision_trigger_fields(p12, p13, e12, e13)
        p_factor == derived.periodicity_factor && p_condition == derived.periodicity_condition ||
            throw(ArgumentError("Retained periodicity trigger fields are inconsistent."))
        e_factor == derived.energy_factor && e_unbounded == derived.energy_unbounded &&
            e_condition == derived.energy_condition || throw(ArgumentError(
                "Retained energy trigger fields are inconsistent."))
        status == derived.status || throw(ArgumentError(
            "Retained precision-trigger status is mathematically inconsistent."))
        new(String(schema_version), source_series_id, String(source_definition_version),
            source_environment, point_1e12_id, point_1e13_id,
            point_1e12_execution, point_1e13_execution, p12, p13, p_factor,
            p_condition, e12, e13, e_factor, e_unbounded, e_condition, status,
            _nonempty_string(summary, "summary"))
    end
end

function _precision_trigger_metric(point, metric_id)
    matches = Tuple(metric for metric in point.metrics if metric.metric_id == metric_id)
    length(matches) <= 1 || throw(ArgumentError("Duplicate trigger metric $metric_id."))
    isempty(matches) && return nothing
    value = only(matches).value
    value isa Float64 && isfinite(value) && value >= 0 || throw(ArgumentError(
        "Trigger metric $metric_id must be finite nonnegative Float64 evidence."))
    value
end

function _validate_precision_trigger_source(series::InvestigationMeasurementSeries)
    definition = core_tolerance_investigation_definition(:figure_eight, :vern9)
    series.series_id == :figure_eight_vern9_tolerance || throw(ArgumentError(
        "Precision trigger requires the approved figure-eight Vern9 tolerance series."))
    _record_fields_equal(series.definition, definition) || throw(ArgumentError(
        "Precision-trigger source definition differs from the approved definition."))
    length(series.points) == length(CORE_TOLERANCE_VALUES) || throw(ArgumentError(
        "Precision-trigger source must contain all five points."))
    environment = first(series.points).environment
    for (index, (point, tolerance)) in enumerate(zip(series.points, CORE_TOLERANCE_VALUES))
        point.point_id == Symbol(:tolerance_, _core_tolerance_token(tolerance)) ||
            throw(ArgumentError("Precision-trigger point identity or order differs."))
        point.independent_value == ValidationParameter(:integration_tolerance, tolerance) ||
            throw(ArgumentError("Precision-trigger independent value differs."))
        _record_fields_equal(point.configuration,
            _core_validation_configuration(core_tolerance_configuration(
                :figure_eight, :vern9, tolerance))) || throw(ArgumentError(
                    "Precision-trigger source configuration differs at point $index."))
        _record_fields_equal(point.environment, environment) || throw(ArgumentError(
            "Precision-trigger source environments differ."))
        length(point.metrics) == length(unique(map(metric -> metric.metric_id, point.metrics))) ||
            throw(ArgumentError("Precision-trigger source contains duplicate metrics."))
        performance = point.performance_report
        isnothing(performance) && throw(ArgumentError(
            "Precision-trigger source performance evidence is missing."))
        configuration = core_tolerance_configuration(:figure_eight, :vern9, tolerance)
        _record_fields_equal(performance.definition,
            core_tolerance_performance_definition(configuration)) || throw(ArgumentError(
                "Precision-trigger performance definition differs at point $index."))
        _record_fields_equal(performance.configuration,
            _core_validation_configuration(configuration)) || throw(ArgumentError(
                "Precision-trigger performance configuration differs at point $index."))
        _record_fields_equal(performance.policy, StandardBenchmark()) || throw(ArgumentError(
            "Precision-trigger performance policy differs at point $index."))
        _record_fields_equal(performance.environment, environment) || throw(ArgumentError(
            "Precision-trigger performance environment differs at point $index."))
    end
    series
end

function _precision_trigger_direct_values(point)
    required_ids = point.definition.required_metric_ids
    ids = map(metric -> metric.metric_id, point.metrics)
    all(id -> count(==(id), ids) == 1, required_ids) || return nothing
    status_metric = only(metric for metric in point.metrics
        if metric.metric_id == :integration_status)
    status_metric.value == :completed || return nothing
    isnothing(point.solver_statistics) && return nothing
    _record_fields_equal(point.execution, point.performance_report.execution) || return nothing
    periodicity = _precision_trigger_metric(point, :periodicity_error)
    energy = _precision_trigger_metric(point, :maximum_relative_energy_drift)
    isnothing(periodicity) || isnothing(energy) ? nothing : (periodicity, energy)
end

function evaluate_figure_eight_precision_trigger(series::InvestigationMeasurementSeries)
    _validate_precision_trigger_source(series)
    p12_point, p13_point = series.points[4], series.points[5]
    values12 = _precision_trigger_direct_values(p12_point)
    values13 = _precision_trigger_direct_values(p13_point)
    p12, e12 = isnothing(values12) ? (nothing, nothing) : values12
    p13, e13 = isnothing(values13) ? (nothing, nothing) : values13
    environment = first(series.points).environment
    if any(isnothing, (p12, p13, e12, e13))
        return FigureEightPrecisionTriggerAssessment(environment.schema_version,
            series.series_id, series.definition.definition_version, environment,
            p12_point.point_id, p13_point.point_id, p12_point.execution,
            p13_point.execution, p12, p13, nothing, nothing, e12, e13, nothing,
            false, nothing, :unavailable,
            "Precision trigger unavailable because required direct numerical evidence is absent.")
    end
    derived = _derive_precision_trigger_fields(p12, p13, e12, e13)
    summary = derived.status == :triggered ? "Approved figure-eight precision trigger conditions were met." :
        "Approved figure-eight precision trigger conditions were not both met."
    FigureEightPrecisionTriggerAssessment(environment.schema_version, series.series_id,
        series.definition.definition_version, environment, p12_point.point_id,
        p13_point.point_id, p12_point.execution, p13_point.execution, p12, p13,
        derived.periodicity_factor, derived.periodicity_condition, e12, e13,
        derived.energy_factor, derived.energy_unbounded, derived.energy_condition,
        derived.status, summary)
end

struct FigureEightPrecisionConfiguration
    benchmark_family::Symbol
    algorithm_id::Symbol
    solver_selector::Symbol
    precision_bits::Int
    relative_tolerance::BigFloat
    absolute_tolerance::BigFloat
    periods::Int
    saveat::BigFloat
    arithmetic::Symbol
    canonical::NamedTuple

    function FigureEightPrecisionConfiguration(family, algorithm, selector, bits,
        reltol, abstol, periods, saveat, arithmetic, canonical)
        bits in FIGURE_EIGHT_PRECISION_BITS || throw(ArgumentError("Unapproved precision."))
        family == :figure_eight && algorithm == :vern9 && selector == :extreme ||
            throw(ArgumentError("Precision confirmation requires figure-eight Vern9 through :extreme."))
        arithmetic == :BigFloat && periods == 10 || throw(ArgumentError(
            "Precision confirmation controls differ."))
        canonical == ThreeBody3D._FIGURE_EIGHT_CANONICAL_DECIMALS || throw(ArgumentError(
            "Canonical figure-eight decimal strings differ."))
        all(value -> value isa BigFloat && precision(value) == bits,
            (reltol, abstol, saveat)) || throw(ArgumentError(
                "Precision controls must be directly parsed BigFloat values at the requested precision."))
        parsed = setprecision(BigFloat, bits) do
            (parse(BigFloat, canonical.tolerance), parse(BigFloat, canonical.tolerance),
             parse(BigFloat, canonical.saveat))
        end
        (reltol, abstol, saveat) == parsed || throw(ArgumentError(
            "Precision controls differ from canonical decimal strings."))
        new(family, algorithm, selector, bits, reltol, abstol, periods, saveat,
            arithmetic, canonical)
    end
end

Base.:(==)(left::FigureEightPrecisionConfiguration,
    right::FigureEightPrecisionConfiguration) = _record_fields_equal(left, right)

function figure_eight_precision_configuration(bits::Integer)
    bits in FIGURE_EIGHT_PRECISION_BITS || throw(ArgumentError("Unapproved precision."))
    setprecision(BigFloat, bits) do
        canonical = ThreeBody3D._FIGURE_EIGHT_CANONICAL_DECIMALS
        FigureEightPrecisionConfiguration(:figure_eight, :vern9, :extreme, bits,
            parse(BigFloat, canonical.tolerance), parse(BigFloat, canonical.tolerance),
            10, parse(BigFloat, canonical.saveat), :BigFloat, canonical)
    end
end

struct FigureEightPrecisionEvidence{C,R,T,Y,U,I}
    configuration::C
    report::R
    times::T
    system::Y
    initial_state::U
    canonical::I
    precision_bits::Int
end

struct FigureEightPrecisionAttempt
    configuration::FigureEightPrecisionConfiguration
    execution::ExecutionOutcome
    evidence::Union{Nothing,FigureEightPrecisionEvidence}
    notes::Union{Nothing,String}
    function FigureEightPrecisionAttempt(configuration, execution, evidence=nothing; notes=nothing)
        if isnothing(evidence)
            execution.actual in (actual_completed, actual_terminated) && throw(ArgumentError(
                "Completed or terminated precision outcomes require evidence."))
            isnothing(execution.summary) && throw(ArgumentError(
                "A precision outcome without evidence requires a factual summary."))
        else
            evidence.configuration == configuration || throw(ArgumentError("Precision evidence configuration differs."))
            evidence.report.status in (:completed, :terminated_close_approach) ||
                throw(ArgumentError("Unsupported precision report status."))
            evidence.report.status == :completed ?
                (execution.actual == actual_completed && isnothing(execution.summary)) :
                (execution.actual == actual_terminated && !isnothing(execution.summary)) ||
                    throw(ArgumentError("Precision evidence and execution outcome differ."))
        end
        new(configuration, execution, evidence,
            isnothing(notes) ? nothing : _nonempty_string(notes, "notes"))
    end
end

function run_figure_eight_precision_observation(configuration::FigureEightPrecisionConfiguration;
    runner=ThreeBody3D._run_figure_eight_precision_benchmark_observation)
    retained = runner(configuration.precision_bits)
    FigureEightPrecisionEvidence(configuration, retained.report, retained.times,
        retained.system, retained.initial_state, retained.canonical,
        retained.precision_bits)
end

function _precision_scalar_grid(configuration, final_time)
    setprecision(BigFloat, configuration.precision_bits) do
        initial = parse(BigFloat, configuration.canonical.initial_time)
        values = vcat(initial, collect(configuration.saveat:configuration.saveat:final_time))
        last(values) == final_time || push!(values, final_time)
        values
    end
end

function _validate_figure_eight_precision_evidence(evidence::FigureEightPrecisionEvidence,
    expected::FigureEightPrecisionConfiguration=evidence.configuration)
    evidence.configuration == expected == figure_eight_precision_configuration(expected.precision_bits) ||
        throw(ArgumentError("Precision evidence does not use the approved configuration."))
    evidence.precision_bits == expected.precision_bits || throw(ArgumentError(
        "Precision observation identity differs from its configuration."))
    canonical = ThreeBody3D._figure_eight_canonical_inputs(expected.precision_bits)
    report = evidence.report
    report.name == :figure_eight && report.profile == :extreme || throw(ArgumentError("Precision report identity differs."))
    report.status in (:completed, :terminated_close_approach) || throw(ArgumentError("Unsupported precision report status."))
    expected_final = setprecision(BigFloat, expected.precision_bits) do
        canonical.initial_time + 10 * canonical.period
    end
    report.initial_time == canonical.initial_time && report.expected_final_time == expected_final ||
        throw(ArgumentError("Precision report time controls differ."))
    report.status == :completed && report.final_time != expected_final && throw(ArgumentError("Completed precision report did not reach final time."))
    report.saved_states == length(evidence.times) || throw(ArgumentError("Precision saved-state count differs."))
    all(count -> count >= 0, (report.saved_states, report.accepted_steps,
        report.rejected_steps, report.rhs_evaluations)) || throw(ArgumentError("Precision solver statistics are negative."))
    evidence.canonical == canonical.canonical || throw(ArgumentError("Canonical identity differs."))
    evidence.system.masses == canonical.system.masses && evidence.system.G == canonical.system.G ||
        throw(ArgumentError("Canonical precision system differs."))
    evidence.initial_state == canonical.initial_state || throw(ArgumentError("Canonical precision initial state differs."))
    scalars = (report.initial_time, report.final_time, report.expected_final_time,
        report.periodicity_error, report.diagnostics.maximum_relative_energy_drift,
        report.diagnostics.maximum_linear_momentum_drift,
        report.diagnostics.maximum_angular_momentum_drift,
        report.diagnostics.maximum_center_of_mass_residual,
        report.diagnostics.minimum_separation, expected.relative_tolerance,
        expected.absolute_tolerance, expected.saveat, evidence.system.G)
    all(value -> value isa BigFloat && precision(value) == expected.precision_bits &&
        isfinite(value), scalars) || throw(ArgumentError("Precision evidence arithmetic differs."))
    all(value -> value >= 0, scalars[4:9]) || throw(ArgumentError("Precision diagnostics must be nonnegative."))
    all(value -> value isa BigFloat && precision(value) == expected.precision_bits && isfinite(value),
        evidence.system.masses) || throw(ArgumentError("Precision masses differ in arithmetic."))
    all(value -> value isa BigFloat && precision(value) == expected.precision_bits && isfinite(value),
        evidence.initial_state) || throw(ArgumentError("Precision initial state differs in arithmetic."))
    !isempty(evidence.times) && all(value -> value isa BigFloat &&
        precision(value) == expected.precision_bits && isfinite(value), evidence.times) ||
            throw(ArgumentError("Precision saved-time arithmetic differs."))
    all(evidence.times[index] < evidence.times[index + 1]
        for index in 1:length(evidence.times)-1) || throw(ArgumentError(
            "Precision saved times must be strictly increasing."))
    first(evidence.times) == canonical.initial_time && last(evidence.times) == report.final_time ||
        throw(ArgumentError("Precision saved-time endpoints differ."))
    evidence.times == _precision_scalar_grid(expected, report.final_time) ||
        throw(ArgumentError("Precision saved-time grid differs."))
    evidence
end

function attempt_figure_eight_precision(configuration::FigureEightPrecisionConfiguration;
    runner=run_figure_eight_precision_observation)
    original_precision = precision(BigFloat)
    try
        evidence = runner(configuration)
        _validate_figure_eight_precision_evidence(evidence, configuration)
        completed = evidence.report.status == :completed
        outcome = ExecutionOutcome(completed ? actual_completed : actual_terminated;
            exit_code=completed ? 0 : 1,
            summary=completed ? nothing : "Precision benchmark reported status $(evidence.report.status).")
        FigureEightPrecisionAttempt(configuration, outcome, evidence; notes=outcome.summary)
    catch error
        summary = "Figure-eight precision execution errored: $(sprint(showerror, error))"
        FigureEightPrecisionAttempt(configuration,
            ExecutionOutcome(actual_errored; exit_code=1, summary); notes=summary)
    finally
        precision(BigFloat) == original_precision || setprecision(BigFloat, original_precision)
    end
end

function _canonical_precision_parameters(canonical)
    parameters = ValidationParameter[
        ValidationParameter(:canonical_masses, canonical.masses),
        ValidationParameter(:canonical_gravitational_constant, canonical.gravitational_constant),
    ]
    for index in 1:3
        push!(parameters, ValidationParameter(Symbol(:canonical_position_, index), canonical.positions[index]))
        push!(parameters, ValidationParameter(Symbol(:canonical_velocity_, index), canonical.velocities[index]))
    end
    append!(parameters, (ValidationParameter(:canonical_initial_time, canonical.initial_time),
        ValidationParameter(:canonical_period, canonical.period),
        ValidationParameter(:canonical_tolerance, canonical.tolerance),
        ValidationParameter(:canonical_saveat, canonical.saveat)))
    Tuple(parameters)
end

function _figure_eight_precision_validation_configuration(configuration)
    inputs = ThreeBody3D._figure_eight_canonical_inputs(configuration.precision_bits)
    final_time = setprecision(BigFloat, configuration.precision_bits) do
        inputs.initial_time + 10 * inputs.period
    end
    ValidationConfiguration(solver=:extreme,
        relative_tolerance=configuration.relative_tolerance,
        absolute_tolerance=configuration.absolute_tolerance,
        precision_bits=configuration.precision_bits,
        time_interval=(inputs.initial_time, final_time),
        sampling="saveat=$(configuration.canonical.saveat)",
        parameters=(ValidationParameter(:algorithm_id, :vern9),
            ValidationParameter(:solver_selector, :extreme),
            ValidationParameter(:periods, 10), ValidationParameter(:arithmetic, :BigFloat),
            _canonical_precision_parameters(configuration.canonical)...))
end

function figure_eight_precision_investigation_definition()
    canonical = ThreeBody3D._FIGURE_EIGHT_CANONICAL_DECIMALS
    InvestigationDefinition(FIGURE_EIGHT_PRECISION_SERIES_ID,
        "Figure-eight precision confirmation",
        "Conditional descriptive confirmation using canonical arbitrary-precision inputs.",
        investigation_2_figure_eight_case_definition(), :precision_bits,
        (ValidationParameter(:algorithm_id, :vern9),
         ValidationParameter(:solver_selector, :extreme), ValidationParameter(:periods, 10),
         ValidationParameter(:arithmetic, :BigFloat),
         _canonical_precision_parameters(canonical)...),
        _core_tolerance_metric_ids(:figure_eight), (),
        FIGURE_EIGHT_PRECISION_DEFINITION_VERSION)
end

figure_eight_precision_performance_id(configuration) =
    Symbol(:figure_eight_precision_, configuration.precision_bits)

function figure_eight_precision_performance_definition(configuration)
    PerformanceBenchmarkDefinition(figure_eight_precision_performance_id(configuration),
        "Figure-eight $(configuration.precision_bits)-bit precision performance",
        "Canonical BigFloat Vern9 timing and deterministic solver-work evidence.",
        "examples/validation/performance/figure_eight_precision_work.jl",
        (:core_integration, :arbitrary_precision, :solver_work),
        (:figure_eight, :vern9, :extreme, :investigation_2), "1.0.0",
        (:elapsed_time, :solver_statistics, :saved_states, :maximum_relative_energy_drift),
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md")
end

function _figure_eight_precision_performance_observation(report)
    PerformanceObservation(
        solver_statistics=SolverStatistics(accepted_steps=report.accepted_steps,
            rejected_steps=report.rejected_steps, rhs_evaluations=report.rhs_evaluations,
            saved_states=report.saved_states),
        saved_states=report.saved_states,
        measurements=(ValidationMetric(:maximum_relative_energy_drift,
            "Maximum relative energy drift",
            report.diagnostics.maximum_relative_energy_drift; scale=scale_relative,
            role=role_descriptive, aggregation=aggregation_maximum),
            ValidationMetric(:minimum_pair_separation, "Minimum pair separation",
                report.diagnostics.minimum_separation; scale=scale_dimensional,
                role=role_descriptive, aggregation=aggregation_minimum)))
end

function figure_eight_precision_performance_operation(configuration;
    runner=ThreeBody3D._run_figure_eight_precision_benchmark)
    () -> _figure_eight_precision_performance_observation(
        runner(configuration.precision_bits))
end

function figure_eight_precision_performance_entry(configuration;
    policy=StandardBenchmark(), performance_directory=joinpath(@__DIR__, "..", "performance"))
    PerformanceBenchmarkEntry(figure_eight_precision_performance_definition(configuration),
        _figure_eight_precision_validation_configuration(configuration), policy,
        joinpath(performance_directory, "figure_eight_precision_work.jl"))
end

function decode_figure_eight_precision_id(id::Symbol)
    for bits in FIGURE_EIGHT_PRECISION_BITS
        configuration = figure_eight_precision_configuration(bits)
        figure_eight_precision_performance_id(configuration) == id && return configuration
    end
    throw(ArgumentError("Unsupported figure-eight precision benchmark ID $id."))
end

function _precision_performance_reports(suite)
    configurations = map(figure_eight_precision_configuration, FIGURE_EIGHT_PRECISION_BITS)
    reports = _performance_reports_by_id(suite.benchmarks)
    expected_ids = Set(map(figure_eight_precision_performance_id, configurations))
    Set(keys(reports)) == expected_ids || throw(ArgumentError("Precision performance suite is incomplete or contains additional reports."))
    suite.schema_version == VALIDATION_SCHEMA_VERSION || throw(ArgumentError("Precision performance schema differs."))
    for configuration in configurations
        report = reports[figure_eight_precision_performance_id(configuration)]
        _record_fields_equal(report.definition, figure_eight_precision_performance_definition(configuration)) || throw(ArgumentError("Precision performance definition differs."))
        _record_fields_equal(report.configuration, _figure_eight_precision_validation_configuration(configuration)) || throw(ArgumentError("Precision performance configuration differs."))
        _record_fields_equal(report.policy, StandardBenchmark()) || throw(ArgumentError("Precision performance policy differs."))
        _record_fields_equal(report.environment, suite.environment) || throw(ArgumentError("Precision performance environment differs."))
        expected_measurements = (:maximum_relative_energy_drift, :minimum_pair_separation)
        for sample in report.samples
            !isnothing(sample.solver_statistics) && !isnothing(sample.saved_states) ||
                throw(ArgumentError("Precision performance solver evidence is incomplete."))
            sample.solver_statistics.saved_states == sample.saved_states || throw(
                ArgumentError("Precision performance saved-state evidence differs."))
            map(metric -> metric.metric_id, sample.measurements) == expected_measurements ||
                throw(ArgumentError("Precision performance deterministic measurements differ."))
            all(metric -> metric.value isa BigFloat &&
                precision(metric.value) == configuration.precision_bits &&
                isfinite(metric.value) && metric.value >= 0, sample.measurements) ||
                    throw(ArgumentError("Precision performance measurement arithmetic differs."))
        end
    end
    reports
end

function figure_eight_precision_investigation_series(assessment::FigureEightPrecisionTriggerAssessment,
    suite::PerformanceSuiteReport, attempts)
    assessment.status == :triggered || throw(ArgumentError("Precision series requires a triggered assessment."))
    assessment.source_series_id == :figure_eight_vern9_tolerance &&
        assessment.source_definition_version == core_tolerance_investigation_definition(
            :figure_eight, :vern9).definition_version || throw(ArgumentError(
                "Precision trigger source identity differs."))
    ordered = Tuple(attempts)
    expected = map(figure_eight_precision_configuration, FIGURE_EIGHT_PRECISION_BITS)
    map(attempt -> attempt.configuration, ordered) == expected || throw(ArgumentError("Precision attempt order differs."))
    reports = _precision_performance_reports(suite)
    definition = figure_eight_precision_investigation_definition()
    points = map(eachindex(ordered)) do index
        attempt, configuration = ordered[index], expected[index]
        FigureEightPrecisionAttempt(configuration, attempt.execution, attempt.evidence; notes=attempt.notes)
        !isnothing(attempt.evidence) && _validate_figure_eight_precision_evidence(attempt.evidence, configuration)
        performance = reports[figure_eight_precision_performance_id(configuration)]
        evidence = attempt.evidence
        metrics = isnothing(evidence) ? () : setprecision(BigFloat,
            configuration.precision_bits) do
            _core_direct_metrics(evidence)
        end
        statistics = isnothing(evidence) ? nothing : SolverStatistics(
            accepted_steps=evidence.report.accepted_steps,
            rejected_steps=evidence.report.rejected_steps,
            rhs_evaluations=evidence.report.rhs_evaluations,
            saved_states=evidence.report.saved_states)
        execution = _core_combined_execution(attempt.execution, performance.execution)
        direct = _core_direct_attempt_detail(attempt)
        notes = String[]
        !isnothing(direct) && push!(notes, "Direct execution: $direct")
        !isnothing(performance.execution.summary) && push!(notes,
            "Performance execution: $(performance.execution.summary)")
        InvestigationMeasurementPoint(Symbol(:precision_, configuration.precision_bits),
            definition, _figure_eight_precision_validation_configuration(configuration),
            ValidationParameter(:precision_bits, configuration.precision_bits), suite.environment,
            execution, metrics, statistics; performance_report=performance,
            notes=isempty(notes) ? nothing : join(notes, "; "))
    end
    InvestigationMeasurementSeries(definition.family_id, definition.title,
        definition.description, definition, Tuple(points))
end

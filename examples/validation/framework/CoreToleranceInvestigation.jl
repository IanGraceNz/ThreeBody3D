# Foundational records and operations for Investigation 2 core tolerance experiments.

import ThreeBody3D
using LinearAlgebra: norm

const CORE_TOLERANCE_VALUES = (1e-9, 1e-10, 1e-11, 1e-12, 1e-13)
const CORE_TOLERANCE_ALGORITHMS = (:tsit5, :vern9)
const CORE_TOLERANCE_FAMILIES = (:figure_eight, :hierarchical_triple)
const CORE_TOLERANCE_COMPARISON_METRICS = (
    :maximum_position_difference, :maximum_velocity_difference,
    :maximum_scaled_state_difference, :final_position_difference,
    :final_velocity_difference, :final_scaled_state_difference,
)
const CORE_TOLERANCE_COMMON_METRICS = (
    :integration_status, :achieved_final_time, :final_time_residual,
    :maximum_relative_energy_drift, :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift, :maximum_center_of_mass_residual,
    :minimum_pair_separation,
)

_core_solver_selector(algorithm::Symbol) = algorithm == :tsit5 ? :fast :
    algorithm == :vern9 ? :accurate : throw(ArgumentError("Unsupported core algorithm $algorithm."))

struct CoreToleranceExperimentConfiguration
    benchmark_family::Symbol
    algorithm_id::Symbol
    solver_selector::Symbol
    relative_tolerance::Float64
    absolute_tolerance::Float64
    periods::Union{Nothing,Int}
    duration::Union{Nothing,Float64}
    saveat::Float64
    arithmetic::Symbol

    function CoreToleranceExperimentConfiguration(
        benchmark_family, algorithm_id, solver_selector, relative_tolerance,
        absolute_tolerance; periods=nothing, duration=nothing, saveat=0.02,
        arithmetic=:Float64,
    )
        benchmark_family in CORE_TOLERANCE_FAMILIES || throw(ArgumentError("Unsupported benchmark family."))
        algorithm_id in CORE_TOLERANCE_ALGORITHMS || throw(ArgumentError("Unsupported algorithm."))
        solver_selector == _core_solver_selector(algorithm_id) || throw(ArgumentError("Algorithm-to-selector mapping is inconsistent."))
        all(value -> value isa Real && isfinite(value) && value > 0,
            (relative_tolerance, absolute_tolerance)) || throw(ArgumentError("Tolerances must be finite and positive."))
        relative_tolerance == absolute_tolerance || throw(ArgumentError("Approved tolerance series require equal tolerances."))
        saveat isa Real && isfinite(saveat) && saveat > 0 || throw(ArgumentError("saveat must be finite and positive."))
        arithmetic == :Float64 || throw(ArgumentError("This increment supports only Float64 arithmetic."))
        if benchmark_family == :figure_eight
            periods isa Integer && periods > 0 || throw(ArgumentError("Figure-eight requires positive periods."))
            isnothing(duration) || throw(ArgumentError("Figure-eight does not use duration."))
        else
            duration isa Real && isfinite(duration) && duration > 0 || throw(ArgumentError("Hierarchical triple requires positive duration."))
            isnothing(periods) || throw(ArgumentError("Hierarchical triple does not use periods."))
        end
        new(
            benchmark_family, algorithm_id, solver_selector,
            Float64(relative_tolerance), Float64(absolute_tolerance),
            isnothing(periods) ? nothing : Int(periods),
            isnothing(duration) ? nothing : Float64(duration), Float64(saveat), arithmetic,
        )
    end
end

function core_tolerance_configuration(family::Symbol, algorithm::Symbol, tolerance::Real)
    selector = _core_solver_selector(algorithm)
    family == :figure_eight && return CoreToleranceExperimentConfiguration(
        family, algorithm, selector, tolerance, tolerance; periods=10, saveat=0.02,
    )
    family == :hierarchical_triple && return CoreToleranceExperimentConfiguration(
        family, algorithm, selector, tolerance, tolerance; duration=100.0, saveat=0.02,
    )
    throw(ArgumentError("Unsupported benchmark family $family."))
end

struct CoreToleranceExecution{C,R,T,S,Y,U}
    configuration::C
    report::R
    times::T
    states::S
    system::Y
    initial_state::U
end

struct CoreToleranceAttempt
    configuration::CoreToleranceExperimentConfiguration
    execution::ExecutionOutcome
    evidence::Union{Nothing,CoreToleranceExecution}
    notes::Union{Nothing,String}

    function CoreToleranceAttempt(configuration, execution, evidence=nothing; notes=nothing)
        execution isa ExecutionOutcome || throw(ArgumentError("execution must be an ExecutionOutcome."))
        if isnothing(evidence)
            execution.actual in (actual_completed, actual_terminated) && throw(ArgumentError(
                "Completed or terminated direct outcomes require retained benchmark evidence."))
            isnothing(execution.summary) && throw(ArgumentError(
                "A direct outcome without evidence requires a factual execution summary."))
        else
            evidence.configuration == configuration || throw(ArgumentError(
                "Attempt evidence configuration differs from the declared configuration."))
            status = evidence.report.status
            status in (:completed, :terminated_close_approach) || throw(ArgumentError(
                "Unsupported direct benchmark report status $status."))
            if status == :completed
                execution.actual == actual_completed || throw(ArgumentError(
                    "Completed benchmark evidence requires actual_completed execution."))
                isnothing(execution.summary) || throw(ArgumentError(
                    "Completed direct execution must not retain an abnormal summary."))
            else
                execution.actual == actual_terminated || throw(ArgumentError(
                    "Terminated benchmark evidence requires actual_terminated execution."))
                isnothing(execution.summary) && throw(ArgumentError(
                    "Terminated direct execution requires a factual summary."))
            end
        end
        new(configuration, execution, evidence,
            isnothing(notes) ? nothing : _nonempty_string(notes, "notes"))
    end
end

function _validate_core_tolerance_attempt(attempt::CoreToleranceAttempt)
    CoreToleranceAttempt(attempt.configuration, attempt.execution, attempt.evidence;
        notes=attempt.notes)
    attempt
end

function run_core_tolerance_experiment(configuration::CoreToleranceExperimentConfiguration;
    runner=ThreeBody3D._run_validation_benchmark_execution)
    execution = runner(
        configuration.benchmark_family;
        periods=something(configuration.periods, 1), duration=configuration.duration,
        solver=configuration.solver_selector, saveat=configuration.saveat,
        reltol=configuration.relative_tolerance,
        abstol=configuration.absolute_tolerance,
    )
    CoreToleranceExecution(
        configuration, execution.report, execution.times, execution.states,
        execution.system, execution.initial_state,
    )
end

function attempt_core_tolerance_experiment(configuration::CoreToleranceExperimentConfiguration;
    runner=run_core_tolerance_experiment)
    try
        evidence = runner(configuration)
        _validate_core_tolerance_execution(evidence, configuration)
        completed = evidence.report.status == :completed
        outcome = ExecutionOutcome(completed ? actual_completed : actual_terminated;
            exit_code=completed ? 0 : 1,
            summary=completed ? nothing : "Core benchmark reported status $(evidence.report.status).")
        CoreToleranceAttempt(configuration, outcome, evidence; notes=outcome.summary)
    catch exception
        summary = "Core tolerance execution errored: $(sprint(showerror, exception))"
        CoreToleranceAttempt(configuration,
            ExecutionOutcome(actual_errored; exit_code=1, summary); notes=summary)
    end
end

function _core_characteristic_scales(system, initial_state)
    positions = Tuple(ThreeBody3D.body_position(initial_state, index) for index in 1:3)
    velocities = Tuple(ThreeBody3D.velocity(initial_state, index) for index in 1:3)
    position_scale = maximum(norm(positions[j] - positions[i]) for (i, j) in ((1,2),(1,3),(2,3)))
    velocity_scale = maximum(norm(velocities[j] - velocities[i]) for (i, j) in ((1,2),(1,3),(2,3)))
    position_fallback = iszero(position_scale)
    velocity_fallback = iszero(velocity_scale)
    (
        position_scale=position_fallback ? one(position_scale) : position_scale,
        velocity_scale=velocity_fallback ? one(velocity_scale) : velocity_scale,
        position_scale_fallback=position_fallback,
        velocity_scale_fallback=velocity_fallback,
    )
end

function _core_scalar_saveat_grid(final_time::Float64, saveat::Float64)
    times = vcat(0.0, collect(saveat:saveat:final_time))
    last(times) == final_time || push!(times, final_time)
    times
end

function _validate_core_saved_times(times, report, saveat)
    isempty(times) && throw(ArgumentError("Saved physical-time grid is empty."))
    all(isfinite, times) || throw(ArgumentError("Saved times must be finite."))
    all(time -> time isa Float64, times) || throw(ArgumentError(
        "Approved core saved times must use Float64 arithmetic."))
    all(times[index] < times[index + 1] for index in 1:length(times)-1) ||
        throw(ArgumentError("Saved times must be strictly increasing."))
    first(times) == 0.0 || throw(ArgumentError("Saved trajectory must begin at the approved initial time."))
    last(times) == report.final_time || throw(ArgumentError("Achieved final time differs from the saved grid."))
    expected = _core_scalar_saveat_grid(report.final_time, saveat)
    times == expected || throw(ArgumentError("Saved trajectory does not use the exact approved physical-time grid."))
    nothing
end

function _validate_core_trajectory(execution::CoreToleranceExecution)
    length(execution.times) == length(execution.states) || throw(ArgumentError("Saved time/state lengths differ."))
    _validate_core_saved_times(execution.times, execution.report,
        execution.configuration.saveat)
    all(state -> length(state) == ThreeBody3D.STATE_SIZE && all(isfinite, state), execution.states) ||
        throw(ArgumentError("Saved states must be finite physical states."))
    all(state -> eltype(state) == Float64, execution.states) || throw(ArgumentError(
        "Approved core saved states must use Float64 arithmetic."))
    nothing
end

function _validate_core_report_evidence(report, family::Symbol)
    report.status in (:completed, :terminated_close_approach) || throw(ArgumentError(
        "Unsupported direct benchmark report status $(report.status)."))
    all(value -> value isa Float64 && isfinite(value),
        (report.initial_time, report.final_time, report.expected_final_time)) ||
        throw(ArgumentError("Core benchmark report times must be finite Float64 values."))
    diagnostic_names = (
        :maximum_relative_energy_drift,
        :maximum_linear_momentum_drift,
        :maximum_angular_momentum_drift,
        :maximum_center_of_mass_residual,
        :minimum_separation,
    )
    all(name -> hasproperty(report.diagnostics, name), diagnostic_names) ||
        throw(ArgumentError("Core benchmark diagnostics are missing required fields."))
    diagnostic_values = Tuple(getproperty(report.diagnostics, name) for name in diagnostic_names)
    all(value -> value isa Float64 && isfinite(value) && value >= 0, diagnostic_values) ||
        throw(ArgumentError("Core benchmark diagnostics must be finite nonnegative Float64 values."))
    if family == :figure_eight
        isempty(propertynames(report.benchmark_metrics)) || throw(ArgumentError(
            "Figure-eight report must not retain hierarchical benchmark metrics."))
        report.periodicity_error isa Float64 && isfinite(report.periodicity_error) &&
            report.periodicity_error >= 0 || throw(ArgumentError(
                "Figure-eight periodicity error must be a finite nonnegative Float64 value."))
    else
        hierarchy_names = (:initial_hierarchy_ratio, :minimum_hierarchy_ratio,
            :final_hierarchy_ratio)
        propertynames(report.benchmark_metrics) == hierarchy_names || throw(ArgumentError(
            "Hierarchical-triple report must retain exactly the approved hierarchy fields."))
        hierarchy_values = Tuple(getproperty(report.benchmark_metrics, name)
            for name in hierarchy_names)
        all(value -> value isa Float64 && isfinite(value) && value > 0,
            hierarchy_values) || throw(ArgumentError(
                "Hierarchy ratios must be finite positive Float64 values."))
        report.periodicity_error isa Float64 && isnan(report.periodicity_error) ||
            throw(ArgumentError("Hierarchical-triple unused periodicity must retain its Float64 NaN convention."))
    end
    report
end


function _validate_core_tolerance_execution(execution::CoreToleranceExecution,
    expected::CoreToleranceExperimentConfiguration=execution.configuration)
    execution.configuration == expected || throw(ArgumentError("Core execution configuration does not match the approved point."))
    approved = core_tolerance_configuration(expected.benchmark_family,
        expected.algorithm_id, expected.relative_tolerance)
    expected == approved || throw(ArgumentError("Core execution does not use the approved fixed configuration."))
    report = execution.report
    _validate_core_report_evidence(report, expected.benchmark_family)
    report.name == expected.benchmark_family || throw(ArgumentError("Benchmark report family differs from the configured family."))
    report.profile == expected.solver_selector || throw(ArgumentError("Benchmark report solver selector differs from the configured algorithm."))
    report.initial_time == 0.0 || throw(ArgumentError("Benchmark report initial time is not approved."))
    expected_final = expected.benchmark_family == :figure_eight ?
        ThreeBody3D.FIGURE_EIGHT_PERIOD * expected.periods : expected.duration
    report.expected_final_time == expected_final || throw(ArgumentError("Benchmark report expected final time is inconsistent."))
    report.saved_states == length(execution.states) == length(execution.times) ||
        throw(ArgumentError("Benchmark saved-state count differs from the retained trajectory."))
    report.status == :completed && report.final_time != expected_final &&
        throw(ArgumentError("Completed benchmark did not reach the approved final time."))
    all(count -> count >= 0, (report.accepted_steps, report.rejected_steps,
        report.rhs_evaluations, report.saved_states)) || throw(ArgumentError("Solver-work counts must be nonnegative."))
    execution.system.G isa Float64 || throw(ArgumentError("Approved core gravitational constant must use Float64 arithmetic."))
    eltype(execution.system.masses) == Float64 || throw(ArgumentError("Approved core masses must use Float64 arithmetic."))
    eltype(execution.initial_state) == Float64 || throw(ArgumentError("Approved core initial state must use Float64 arithmetic."))
    authoritative = expected.benchmark_family == :figure_eight ?
        ThreeBody3D._figure_eight_benchmark_inputs() : ThreeBody3D._hierarchical_triple_benchmark_inputs()
    execution.system.masses == authoritative[1].masses && execution.system.G == authoritative[1].G ||
        throw(ArgumentError("Retained physical system differs from the authoritative benchmark input."))
    execution.initial_state == authoritative[2] ||
        throw(ArgumentError("Retained initial state differs from the authoritative benchmark input."))
    _validate_core_trajectory(execution)
    first(execution.states) == execution.initial_state || throw(ArgumentError(
        "First saved state differs from the retained authoritative initial state."))
    execution
end

function _adjacent_tolerances(loose, tight)
    index = findfirst(==(loose), CORE_TOLERANCE_VALUES)
    !isnothing(index) && index < length(CORE_TOLERANCE_VALUES) &&
        tight == CORE_TOLERANCE_VALUES[index + 1]
end

function compare_adjacent_core_tolerances(loose::CoreToleranceExecution, tight::CoreToleranceExecution)
    _validate_core_tolerance_execution(loose)
    _validate_core_tolerance_execution(tight)
    left, right = loose.configuration, tight.configuration
    left.benchmark_family == right.benchmark_family || throw(ArgumentError("Benchmark families differ."))
    left.algorithm_id == right.algorithm_id || throw(ArgumentError("Algorithms differ."))
    left.solver_selector == right.solver_selector || throw(ArgumentError("Solver selectors differ."))
    left.arithmetic == right.arithmetic || throw(ArgumentError("Arithmetic differs."))
    _adjacent_tolerances(left.relative_tolerance, right.relative_tolerance) ||
        throw(ArgumentError("Tolerance points must be approved, adjacent, and loose-to-tight."))
    left.periods == right.periods && left.duration == right.duration || throw(ArgumentError("Benchmark controls differ."))
    left.saveat == right.saveat == 0.02 || throw(ArgumentError("The approved saveat=0.02 control is required."))
    loose.system.masses == tight.system.masses && loose.system.G == tight.system.G ||
        throw(ArgumentError("Physical systems differ."))
    loose.initial_state == tight.initial_state || throw(ArgumentError("Initial states differ."))
    length(loose.times) == length(tight.times) || throw(ArgumentError("Time-grid lengths differ."))
    loose.times == tight.times || throw(ArgumentError("Physical time grids differ."))
    scales = _core_characteristic_scales(loose.system, loose.initial_state)
    position_values = Float64[]
    velocity_values = Float64[]
    masses = loose.system.masses
    total_mass = sum(masses)
    for (left_state, right_state) in zip(loose.states, tight.states)
        left_com = sum(masses[i] * ThreeBody3D.body_position(left_state, i) for i in 1:3) / total_mass
        right_com = sum(masses[i] * ThreeBody3D.body_position(right_state, i) for i in 1:3) / total_mass
        left_velocity = sum(masses[i] * ThreeBody3D.velocity(left_state, i) for i in 1:3) / total_mass
        right_velocity = sum(masses[i] * ThreeBody3D.velocity(right_state, i) for i in 1:3) / total_mass
        push!(position_values, maximum(norm(
            (ThreeBody3D.body_position(left_state, i) - left_com) -
            (ThreeBody3D.body_position(right_state, i) - right_com)
        ) for i in 1:3) / scales.position_scale)
        push!(velocity_values, maximum(norm(
            (ThreeBody3D.velocity(left_state, i) - left_velocity) -
            (ThreeBody3D.velocity(right_state, i) - right_velocity)
        ) for i in 1:3) / scales.velocity_scale)
    end
    values = (
        maximum_position_difference=maximum(position_values),
        maximum_velocity_difference=maximum(velocity_values),
        maximum_scaled_state_difference=max(maximum(position_values), maximum(velocity_values)),
        final_position_difference=last(position_values),
        final_velocity_difference=last(velocity_values),
        final_scaled_state_difference=max(last(position_values), last(velocity_values)),
    )
    all(isfinite, values) || throw(ArgumentError("Adjacent-tolerance comparison produced a nonfinite result."))
    (; values..., scales...)
end

function _core_validation_configuration(configuration::CoreToleranceExperimentConfiguration)
    control = isnothing(configuration.periods) ?
        ValidationParameter(:duration, configuration.duration) :
        ValidationParameter(:periods, configuration.periods)
    final_time = isnothing(configuration.periods) ? configuration.duration :
        ThreeBody3D.FIGURE_EIGHT_PERIOD * configuration.periods
    ValidationConfiguration(
        solver=configuration.solver_selector,
        relative_tolerance=configuration.relative_tolerance,
        absolute_tolerance=configuration.absolute_tolerance,
        time_interval=(0.0, final_time), sampling="saveat=$(configuration.saveat)",
        parameters=(
            ValidationParameter(:algorithm_id, configuration.algorithm_id),
            ValidationParameter(:solver_selector, configuration.solver_selector), control,
            ValidationParameter(:saveat, configuration.saveat),
            ValidationParameter(:arithmetic, configuration.arithmetic),
        ),
    )
end

function _core_tolerance_metric_ids(family)
    family == :figure_eight ?
        (CORE_TOLERANCE_COMMON_METRICS..., :periodicity_error) :
        (CORE_TOLERANCE_COMMON_METRICS..., :initial_hierarchy_ratio,
         :minimum_hierarchy_ratio, :final_hierarchy_ratio)
end

function core_tolerance_investigation_definition(family::Symbol, algorithm::Symbol)
    configuration = core_tolerance_configuration(family, algorithm, first(CORE_TOLERANCE_VALUES))
    scales = let inputs = family == :figure_eight ? ThreeBody3D._figure_eight_benchmark_inputs() : ThreeBody3D._hierarchical_triple_benchmark_inputs()
        _core_characteristic_scales(inputs[1], inputs[2])
    end
    duration_control = family == :figure_eight ? ValidationParameter(:periods, 10) : ValidationParameter(:duration, 100.0)
    series_id = Symbol(family, :_, algorithm, :_tolerance)
    InvestigationDefinition(
        series_id, "$(replace(string(family), '_' => ' ')) $(algorithm) tolerance series",
        "Matched-algorithm descriptive core tolerance experiment.",
        family == :figure_eight ? figure_eight_case_definition() : hierarchical_triple_case_definition(),
        :integration_tolerance,
        (
            ValidationParameter(:algorithm_id, algorithm),
            ValidationParameter(:solver_selector, configuration.solver_selector), duration_control,
            ValidationParameter(:saveat, 0.02), ValidationParameter(:arithmetic, :Float64),
            ValidationParameter(:position_scale, scales.position_scale),
            ValidationParameter(:velocity_scale, scales.velocity_scale),
            ValidationParameter(:position_scale_fallback, scales.position_scale_fallback),
            ValidationParameter(:velocity_scale_fallback, scales.velocity_scale_fallback),
        ),
        _core_tolerance_metric_ids(family), CORE_TOLERANCE_COMPARISON_METRICS, "1.0.0",
    )
end

function _core_direct_metrics(execution)
    report = execution.report
    common = (
        ValidationMetric(:integration_status, "Integration status", report.status),
        ValidationMetric(:achieved_final_time, "Achieved final time", report.final_time; aggregation=aggregation_final),
        ValidationMetric(:final_time_residual, "Final-time residual", abs(report.final_time-report.expected_final_time); aggregation=aggregation_final),
        ValidationMetric(:maximum_relative_energy_drift, "Maximum relative energy drift", report.diagnostics.maximum_relative_energy_drift; scale=scale_relative, aggregation=aggregation_maximum),
        ValidationMetric(:maximum_linear_momentum_drift, "Maximum linear-momentum drift", report.diagnostics.maximum_linear_momentum_drift; aggregation=aggregation_maximum),
        ValidationMetric(:maximum_angular_momentum_drift, "Maximum angular-momentum drift", report.diagnostics.maximum_angular_momentum_drift; aggregation=aggregation_maximum),
        ValidationMetric(:maximum_center_of_mass_residual, "Maximum centre-of-mass residual", report.diagnostics.maximum_center_of_mass_residual; aggregation=aggregation_maximum),
        ValidationMetric(:minimum_pair_separation, "Minimum pair separation", report.diagnostics.minimum_separation; aggregation=aggregation_minimum),
    )
    execution.configuration.benchmark_family == :figure_eight && return (
        common..., ValidationMetric(:periodicity_error, "Periodicity error", report.periodicity_error; aggregation=aggregation_final),
    )
    (common...,
     ValidationMetric(:initial_hierarchy_ratio, "Initial hierarchy ratio", report.benchmark_metrics.initial_hierarchy_ratio; aggregation=aggregation_initial),
     ValidationMetric(:minimum_hierarchy_ratio, "Minimum hierarchy ratio", report.benchmark_metrics.minimum_hierarchy_ratio; aggregation=aggregation_minimum),
     ValidationMetric(:final_hierarchy_ratio, "Final hierarchy ratio", report.benchmark_metrics.final_hierarchy_ratio; aggregation=aggregation_final))
end

function _core_performance_reports(suite::PerformanceSuiteReport, family, algorithm)
    suite.schema_version == VALIDATION_SCHEMA_VERSION || throw(ArgumentError("Performance suite schema version differs."))
    reports = Dict{Symbol,PerformanceBenchmarkReport}()
    for report in suite.benchmarks
        id = report.definition.benchmark_id
        haskey(reports, id) && throw(ArgumentError("Duplicate performance report $id."))
        reports[id] = report
    end
    expected_ids = Tuple(core_tolerance_performance_benchmark_id(family, algorithm, tolerance)
        for tolerance in CORE_TOLERANCE_VALUES)
    Set(keys(reports)) == Set(expected_ids) || throw(ArgumentError("Performance suite must contain exactly the five approved tolerance reports."))
    for tolerance in CORE_TOLERANCE_VALUES
        configuration = core_tolerance_configuration(family, algorithm, tolerance)
        report = reports[core_tolerance_performance_benchmark_id(family, algorithm, tolerance)]
        _record_fields_equal(report.definition, core_tolerance_performance_definition(configuration)) ||
            throw(ArgumentError("Performance benchmark definition differs from the approved point."))
        _record_fields_equal(report.configuration, _core_validation_configuration(configuration)) ||
            throw(ArgumentError("Performance benchmark configuration differs from the approved point."))
        _record_fields_equal(report.policy, StandardBenchmark()) ||
            throw(ArgumentError("Performance measurement policy differs from the approved policy."))
        _record_fields_equal(report.environment, suite.environment) ||
            throw(ArgumentError("Performance benchmark environment differs from the suite environment."))
    end
    reports
end

function _core_combined_execution(direct::ExecutionOutcome, performance::ExecutionOutcome)
    direct.actual != actual_completed && return direct
    performance
end

function _core_direct_attempt_detail(attempt)
    notes, summary = attempt.notes, attempt.execution.summary
    isnothing(notes) && return summary
    (isnothing(summary) || notes == summary) ? notes : "$notes; $summary"
end

function _core_attempt_notes(attempt::CoreToleranceAttempt, performance::PerformanceBenchmarkReport)
    parts = String[]
    direct_summary = _core_direct_attempt_detail(attempt)
    !isnothing(direct_summary) && push!(parts, "Direct execution: $direct_summary")
    !isnothing(performance.execution.summary) && push!(parts,
        "Performance execution: $(performance.execution.summary)")
    isempty(parts) ? nothing : join(parts, "; ")
end

function core_tolerance_investigation_series(suite::PerformanceSuiteReport, attempts)
    ordered = Tuple(attempts)
    length(ordered) == length(CORE_TOLERANCE_VALUES) || throw(ArgumentError("All five tolerance points are required."))
    all(attempt -> attempt isa CoreToleranceAttempt, ordered) || throw(ArgumentError("Series inputs must be CoreToleranceAttempt records."))
    family = first(ordered).configuration.benchmark_family
    algorithm = first(ordered).configuration.algorithm_id
    map(item -> item.configuration.relative_tolerance, ordered) == CORE_TOLERANCE_VALUES || throw(ArgumentError("Tolerance point order is not approved."))
    all(item -> item.configuration.benchmark_family == family && item.configuration.algorithm_id == algorithm, ordered) || throw(ArgumentError("Series configurations differ."))
    for (attempt, tolerance) in zip(ordered, CORE_TOLERANCE_VALUES)
        _validate_core_tolerance_attempt(attempt)
        attempt.configuration == core_tolerance_configuration(family, algorithm, tolerance) ||
            throw(ArgumentError("Direct attempt configuration differs from the approved point contract."))
        isnothing(attempt.evidence) || _validate_core_tolerance_execution(attempt.evidence, attempt.configuration)
    end
    reports = _core_performance_reports(suite, family, algorithm)
    definition = core_tolerance_investigation_definition(family, algorithm)
    points = map(eachindex(ordered)) do index
        attempt = ordered[index]
        evidence = attempt.evidence
        next_evidence = index < length(ordered) ? ordered[index+1].evidence : nothing
        comparison_metrics = if index < length(ordered) &&
            !isnothing(evidence) && !isnothing(next_evidence) &&
            attempt.execution.actual == actual_completed && ordered[index+1].execution.actual == actual_completed
            comparison = compare_adjacent_core_tolerances(evidence, next_evidence)
            Tuple(ValidationMetric(id, replace(string(id), '_' => ' '), getproperty(comparison, id)) for id in CORE_TOLERANCE_COMPARISON_METRICS)
        else
            ()
        end
        benchmark_id = core_tolerance_performance_benchmark_id(family, algorithm, attempt.configuration.relative_tolerance)
        performance = reports[benchmark_id]
        metrics = isnothing(evidence) ? () : (_core_direct_metrics(evidence)..., comparison_metrics...)
        statistics = isnothing(evidence) ? nothing : SolverStatistics(
            accepted_steps=evidence.report.accepted_steps,
            rejected_steps=evidence.report.rejected_steps,
            rhs_evaluations=evidence.report.rhs_evaluations,
            saved_states=evidence.report.saved_states)
        InvestigationMeasurementPoint(
            Symbol(:tolerance_, _core_tolerance_token(attempt.configuration.relative_tolerance)), definition,
            _core_validation_configuration(attempt.configuration),
            ValidationParameter(:integration_tolerance, attempt.configuration.relative_tolerance),
            suite.environment,
            _core_combined_execution(attempt.execution, performance.execution),
            metrics, statistics;
            performance_report=performance,
            notes=_core_attempt_notes(attempt, performance),
        )
    end
    InvestigationMeasurementSeries(definition.family_id, definition.title, definition.description, definition, Tuple(points))
end

function _core_tolerance_token(tolerance)
    index = findfirst(==(Float64(tolerance)), CORE_TOLERANCE_VALUES)
    isnothing(index) && throw(ArgumentError("Tolerance is not an approved core point."))
    ("1e_9", "1e_10", "1e_11", "1e_12", "1e_13")[index]
end

core_tolerance_performance_benchmark_id(family, algorithm, tolerance) =
    Symbol(family, :_, algorithm, :_tolerance_, _core_tolerance_token(tolerance))

function core_tolerance_performance_definition(configuration::CoreToleranceExperimentConfiguration)
    PerformanceBenchmarkDefinition(
        core_tolerance_performance_benchmark_id(configuration.benchmark_family, configuration.algorithm_id, configuration.relative_tolerance),
        "Core tolerance performance point", "Parameterized retained timing and deterministic work evidence.",
        "examples/validation/performance/core_tolerance_accuracy_work.jl",
        (:core_integration, :tolerance, :solver_work),
        (configuration.benchmark_family, configuration.algorithm_id, :investigation_2), "1.0.0",
        (:elapsed_time, :solver_statistics, :saved_states, :maximum_relative_energy_drift),
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md",
    )
end

function core_tolerance_performance_operation(configuration::CoreToleranceExperimentConfiguration;
    runner=ThreeBody3D.run_validation_benchmark)
    () -> begin
        report = runner(configuration.benchmark_family;
            periods=something(configuration.periods, 1), duration=configuration.duration,
            solver=configuration.solver_selector, saveat=configuration.saveat,
            reltol=configuration.relative_tolerance,
            abstol=configuration.absolute_tolerance)
        _performance_observation(report)
    end
end

function core_tolerance_performance_entry(configuration::CoreToleranceExperimentConfiguration;
    policy=StandardBenchmark(), performance_directory=joinpath(@__DIR__, "..", "performance"))
    PerformanceBenchmarkEntry(
        core_tolerance_performance_definition(configuration),
        _core_validation_configuration(configuration), policy,
        joinpath(performance_directory, "core_tolerance_accuracy_work.jl"),
    )
end

function decode_core_tolerance_benchmark_id(id::Symbol)
    text = string(id)
    for family in CORE_TOLERANCE_FAMILIES, algorithm in CORE_TOLERANCE_ALGORITHMS, tolerance in CORE_TOLERANCE_VALUES
        configuration = core_tolerance_configuration(family, algorithm, tolerance)
        core_tolerance_performance_benchmark_id(family, algorithm, tolerance) == id && return configuration
    end
    throw(ArgumentError("Unsupported core tolerance benchmark ID $text."))
end

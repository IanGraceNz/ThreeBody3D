# I2-C1: Cartesian tolerance and reference-localisation foundation.

const CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES = (1e-9, 1e-10, 1e-11, 1e-12, 1e-13)
const CLOSE_ENCOUNTER_CARTESIAN_DEFINITION_VERSION = "1.0.0"
const CLOSE_ENCOUNTER_LOCAL_SAMPLE_ORDER = (:entry, :periapsis, :exit, :final)
const CLOSE_ENCOUNTER_REGION_ORDER = (:before, :during, :after)
const CLOSE_ENCOUNTER_BASE_GRID_CONVENTION = "0.0:0.002:1.6 including final"
const CLOSE_ENCOUNTER_AUGMENTATION_CONVENTION =
    "entry, periapsis, exit, final; sorted and deduplicated"

struct CloseEncounterCartesianConfiguration
    relative_tolerance::Float64
    absolute_tolerance::Float64

    function CloseEncounterCartesianConfiguration(tolerance::Real)
        normalized = Float64(tolerance)
        normalized in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES ||
            throw(ArgumentError("Tolerance is not an approved Cartesian point."))
        new(normalized, normalized)
    end
end

close_encounter_cartesian_configuration(tolerance) =
    CloseEncounterCartesianConfiguration(tolerance)

struct CloseEncounterLocalErrorSample{T,E}
    location::Symbol
    time::T
    state_source::Symbol
    pair_position_error::E
    pair_velocity_error::E
    full_state_error::E

    function CloseEncounterLocalErrorSample(
        location,
        time::T,
        source,
        position::E,
        velocity::E,
        full::E,
    ) where {T,E}
        location in CLOSE_ENCOUNTER_LOCAL_SAMPLE_ORDER ||
            throw(ArgumentError("Unsupported local-sample location."))
        time isa BigFloat || throw(ArgumentError("Local sample times must use BigFloat."))
        precision(time) == CLOSE_ENCOUNTER_REFERENCE_PRECISION ||
            throw(ArgumentError("Local sample time must retain 256-bit precision."))
        source in (:saved_direct, :dense_interpolation) ||
            throw(ArgumentError("Unsupported Cartesian state source."))
        all(value -> value isa Real && isfinite(value) && value >= 0,
            (position, velocity, full)) ||
            throw(ArgumentError("Local errors must be finite and nonnegative."))
        new{T,E}(location, time, source, position, velocity, full)
    end
end

struct CloseEncounterRegionMaximum{E}
    region::Symbol
    pair_position_error::E
    pair_velocity_error::E
    full_state_error::E

    function CloseEncounterRegionMaximum(region, position::E, velocity::E, full::E) where E
        region in CLOSE_ENCOUNTER_REGION_ORDER ||
            throw(ArgumentError("Unsupported temporal region."))
        all(value -> value isa Real && isfinite(value) && value >= 0,
            (position, velocity, full)) ||
            throw(ArgumentError("Regional errors must be finite and nonnegative."))
        new{E}(region, position, velocity, full)
    end
end

struct CloseEncounterTemporalLocalizationEvidence{S,R}
    boundaries::CloseEncounterReferenceBoundaries
    samples::S
    regions::R
    base_grid_convention::String
    augmentation_convention::String

    function CloseEncounterTemporalLocalizationEvidence(
        boundaries::CloseEncounterReferenceBoundaries,
        samples,
        regions;
        base_grid_convention=CLOSE_ENCOUNTER_BASE_GRID_CONVENTION,
        augmentation_convention=CLOSE_ENCOUNTER_AUGMENTATION_CONVENTION,
    )
        normalized_samples = Tuple(samples)
        normalized_regions = Tuple(regions)
        length(normalized_samples) == 4 ||
            throw(ArgumentError("Temporal localisation requires exactly four samples."))
        length(normalized_regions) == 3 ||
            throw(ArgumentError("Temporal localisation requires exactly three regions."))
        map(sample -> sample.location, normalized_samples) ==
            CLOSE_ENCOUNTER_LOCAL_SAMPLE_ORDER ||
            throw(ArgumentError("Local samples are not in the approved order."))
        map(region -> region.region, normalized_regions) == CLOSE_ENCOUNTER_REGION_ORDER ||
            throw(ArgumentError("Regional maxima are not in the approved order."))
        expected_times = (
            boundaries.entry_time,
            boundaries.periapsis_time,
            boundaries.exit_time,
        )
        all(index -> normalized_samples[index].time == expected_times[index], 1:3) ||
            throw(ArgumentError("Local sample times differ from reference boundaries."))
        setprecision(BigFloat, CLOSE_ENCOUNTER_REFERENCE_PRECISION) do
            normalized_samples[4].time == _close_reference_time(
                last(CLOSE_ENCOUNTER_INTERVAL), CLOSE_ENCOUNTER_REFERENCE_PRECISION,
            ) ||
                throw(ArgumentError("Final local sample time is not 1.6."))
        end
        all(index -> normalized_samples[index].time < normalized_samples[index + 1].time,
            1:3) || throw(ArgumentError("Local sample times must be strictly ordered."))
        base_grid_convention == CLOSE_ENCOUNTER_BASE_GRID_CONVENTION ||
            throw(ArgumentError("Base-grid convention is not approved."))
        augmentation_convention == CLOSE_ENCOUNTER_AUGMENTATION_CONVENTION ||
            throw(ArgumentError("Augmentation convention is not approved."))
        new{typeof(normalized_samples),typeof(normalized_regions)}(
            boundaries,
            normalized_samples,
            normalized_regions,
            String(base_grid_convention),
            String(augmentation_convention),
        )
    end
end

struct CloseEncounterCartesianBaseEvidence{R,P,S}
    configuration::CloseEncounterCartesianConfiguration
    reference::R
    problem::P
    solution::S
    times::Vector{Float64}
    states::Vector{Vector{Float64}}
    achieved_final_time::Float64
    final_time_residual::Float64
    errors::NamedTuple
    conservation::NamedTuple
    work::NamedTuple

    function CloseEncounterCartesianBaseEvidence(
        configuration::CloseEncounterCartesianConfiguration,
        reference::CloseEncounterReferenceExecution,
        problem,
        solution,
        times,
        states,
        achieved_final_time,
        final_time_residual,
        errors,
        conservation,
        work,
    )
        _validate_close_encounter_problem(problem, Float64)
        normalized_times = Float64.(times)
        _validate_close_encounter_sample_grid(normalized_times)
        normalized_states = Vector{Float64}[Vector{Float64}(state) for state in states]
        length(normalized_states) == length(normalized_times) ||
            throw(ArgumentError("Cartesian sample counts differ."))
        achieved = Float64(achieved_final_time)
        residual = Float64(final_time_residual)
        isfinite(achieved) && isfinite(residual) && residual >= 0 ||
            throw(ArgumentError("Cartesian final-time evidence is invalid."))
        achieved == 1.6 && residual == 0.0 ||
            throw(ArgumentError("Completed Cartesian propagation must reach 1.6 exactly."))
        all(value -> value isa Real && isfinite(value) && value >= 0,
            values(errors)) || throw(ArgumentError("Cartesian global errors are invalid."))
        all(value -> value isa Real && isfinite(value) && value >= 0,
            values(conservation)) || throw(ArgumentError("Cartesian invariants are invalid."))
        all(value -> value isa Integer && value >= 0,
            values(work)) || throw(ArgumentError("Cartesian solver work is invalid."))
        new{typeof(reference),typeof(problem),typeof(solution)}(
            configuration, reference, problem, solution, normalized_times,
            normalized_states, achieved, residual, errors, conservation, work,
        )
    end
end

struct CloseEncounterCartesianExecution{B}
    base::B
    dense_periapsis::NamedTuple
    localization::CloseEncounterTemporalLocalizationEvidence

    function CloseEncounterCartesianExecution(
        base::CloseEncounterCartesianBaseEvidence,
        dense_periapsis::NamedTuple,
        localization::CloseEncounterTemporalLocalizationEvidence,
    )
        _record_fields_equal(base.reference.boundaries, localization.boundaries) ||
            throw(ArgumentError("Localisation boundaries differ from the shared reference."))
        all(value -> value isa Real && isfinite(value),
            (dense_periapsis.time, dense_periapsis.separation,
             dense_periapsis.radial_numerator)) ||
            throw(ArgumentError("Dense Cartesian periapsis evidence is invalid."))
        dense_periapsis.separation >= 0 ||
            throw(ArgumentError("Dense Cartesian periapsis separation is negative."))
        new{typeof(base)}(base, dense_periapsis, localization)
    end
end

struct CloseEncounterCartesianAttempt
    configuration::CloseEncounterCartesianConfiguration
    execution::ExecutionOutcome
    evidence::Union{Nothing,CloseEncounterCartesianExecution}
    partial_evidence::Union{Nothing,CloseEncounterCartesianBaseEvidence}
    notes::Union{Nothing,String}

    function CloseEncounterCartesianAttempt(
        configuration::CloseEncounterCartesianConfiguration,
        execution::ExecutionOutcome,
        evidence=nothing,
        partial_evidence=nothing;
        notes=nothing,
    )
        isnothing(evidence) || evidence isa CloseEncounterCartesianExecution ||
            throw(ArgumentError("Complete evidence has the wrong type."))
        isnothing(partial_evidence) || partial_evidence isa CloseEncounterCartesianBaseEvidence ||
            throw(ArgumentError("Partial evidence has the wrong type."))
        (isnothing(evidence) || isnothing(partial_evidence)) ||
            throw(ArgumentError("Complete and partial evidence are mutually exclusive."))
        normalized_notes = isnothing(notes) ? nothing : _nonempty_string(notes, "notes")
        if execution.actual == actual_completed
            !isnothing(evidence) || throw(ArgumentError("Completed attempts require complete evidence."))
            isnothing(partial_evidence) || throw(ArgumentError("Completed attempts cannot be partial."))
            isnothing(execution.summary) ||
                throw(ArgumentError("Completed attempts cannot have an abnormal summary."))
            isnothing(normalized_notes) ||
                throw(ArgumentError("Completed attempts cannot have abnormal notes."))
        else
            isnothing(evidence) || throw(ArgumentError("Abnormal attempts cannot have complete evidence."))
            !isnothing(execution.summary) ||
                throw(ArgumentError("Abnormal attempts require a factual summary."))
        end
        retained = isnothing(evidence) ? partial_evidence : evidence.base
        isnothing(retained) || retained.configuration == configuration ||
            throw(ArgumentError("Attempt evidence configuration differs."))
        new(configuration, execution, evidence, partial_evidence, normalized_notes)
    end
end

function _close_cartesian_base_measurement(
    configuration::CloseEncounterCartesianConfiguration,
    reference::CloseEncounterReferenceExecution;
    runner=ThreeBody3D.simulate,
)
    problem = close_encounter_problem(Float64)
    times = reference.sample_times
    result = runner(
        problem.system,
        problem.u0,
        problem.tspan;
        solver=:accurate,
        reltol=configuration.relative_tolerance,
        abstol=configuration.absolute_tolerance,
        saveat=times,
    )
    states = Vector{Float64}[Vector{Float64}(state) for state in result.solution.u]
    achieved_final_time = Float64(last(result.solution.t))
    final_time_residual = abs(achieved_final_time - last(problem.tspan))
    achieved_final_time == last(problem.tspan) ||
        throw(ErrorException("Cartesian propagation did not reach final time."))
    errors = close_encounter_trajectory_errors(states, reference.sampled_states)
    conservation = close_encounter_conservation(problem.system, times, states)
    boundaries = reference.boundaries
    CloseEncounterCartesianBaseEvidence(
        configuration, reference, problem, result.solution, times, states,
        achieved_final_time, final_time_residual, errors, conservation,
        close_encounter_solution_work(result.solution),
    )
end

function _close_cartesian_dense_periapsis(base::CloseEncounterCartesianBaseEvidence)
    boundaries = base.reference.boundaries
    close_encounter_periapsis(
        time -> Vector{Float64}(base.solution(time)),
        Float64(boundaries.entry_time),
        Float64(boundaries.exit_time),
    )
end

function _close_cartesian_saved_index(
    base::CloseEncounterCartesianBaseEvidence,
    evaluation_time::BigFloat,
)
    findfirst(eachindex(base.times)) do index
        close_encounter_reference_time(
            base.reference, base.times[index],
        ) == evaluation_time
    end
end

function _close_cartesian_states_at_time(
    base::CloseEncounterCartesianBaseEvidence,
    evaluation_time::BigFloat,
)
    index = _close_cartesian_saved_index(base, evaluation_time)
    if isnothing(index)
        return (
            method=Vector{Float64}(base.solution(Float64(evaluation_time))),
            reference=close_encounter_reference_state(base.reference, evaluation_time),
            source=:dense_interpolation,
        )
    end
    (
        method=base.states[index],
        reference=base.reference.sampled_states[index],
        source=:saved_direct,
    )
end

function _close_cartesian_localization(base::CloseEncounterCartesianBaseEvidence)
    reference = base.reference
    boundaries = reference.boundaries
    augmented_times = close_encounter_augmented_times(reference)
    special_times = setprecision(BigFloat, reference.precision_bits) do
        (
            BigFloat(boundaries.entry_time),
            BigFloat(boundaries.periapsis_time),
            BigFloat(boundaries.exit_time),
            close_encounter_reference_time(reference, last(base.times)),
        )
    end
    samples = map(CLOSE_ENCOUNTER_LOCAL_SAMPLE_ORDER, special_times) do location, time
        states = _close_cartesian_states_at_time(base, time)
        errors = close_encounter_state_errors(states.method, states.reference)
        CloseEncounterLocalErrorSample(
            location,
            time,
            states.source,
            errors.position,
            errors.velocity,
            errors.full_state,
        )
    end
    region_times = (BigFloat[], BigFloat[], BigFloat[])
    for time in augmented_times
        region_index = time < boundaries.entry_time ? 1 :
            time <= boundaries.exit_time ? 2 : 3
        push!(region_times[region_index], time)
    end
    regions = map(CLOSE_ENCOUNTER_REGION_ORDER, region_times) do region, times
        isempty(times) && throw(ArgumentError("A temporal region has no comparison samples."))
        errors = map(times) do time
            states = _close_cartesian_states_at_time(base, time)
            close_encounter_state_errors(states.method, states.reference)
        end
        CloseEncounterRegionMaximum(
            region,
            maximum(value.position for value in errors),
            maximum(value.velocity for value in errors),
            maximum(value.full_state for value in errors),
        )
    end
    CloseEncounterTemporalLocalizationEvidence(boundaries, samples, regions)
end

function run_close_encounter_cartesian(
    configuration::CloseEncounterCartesianConfiguration,
    reference::CloseEncounterReferenceExecution;
    runner=ThreeBody3D.simulate,
    periapsis_localizer=_close_cartesian_dense_periapsis,
    localizer=_close_cartesian_localization,
)
    base = _close_cartesian_base_measurement(configuration, reference; runner=runner)
    CloseEncounterCartesianExecution(
        base, periapsis_localizer(base), localizer(base),
    )
end

function attempt_close_encounter_cartesian(
    configuration::CloseEncounterCartesianConfiguration,
    reference::CloseEncounterReferenceExecution;
    runner=ThreeBody3D.simulate,
    periapsis_localizer=_close_cartesian_dense_periapsis,
    localizer=_close_cartesian_localization,
)
    base = try
        _close_cartesian_base_measurement(configuration, reference; runner=runner)
    catch error
        summary = "Cartesian propagation/global measurement failed: $(sprint(showerror, error))"
        return CloseEncounterCartesianAttempt(
            configuration,
            ExecutionOutcome(actual_errored; exit_code=1, summary=summary),
            nothing,
            nothing;
            notes=summary,
        )
    end
    dense_periapsis = try
        periapsis_localizer(base)
    catch error
        summary = "Cartesian dense-periapsis localisation failed: $(sprint(showerror, error))"
        return CloseEncounterCartesianAttempt(
            configuration,
            ExecutionOutcome(actual_errored; exit_code=1, summary=summary),
            nothing,
            base;
            notes=summary,
        )
    end
    try
        evidence = CloseEncounterCartesianExecution(base, dense_periapsis, localizer(base))
        CloseEncounterCartesianAttempt(
            configuration, ExecutionOutcome(actual_completed; exit_code=0), evidence,
        )
    catch error
        summary = "Cartesian temporal localisation failed: $(sprint(showerror, error))"
        CloseEncounterCartesianAttempt(
            configuration,
            ExecutionOutcome(actual_errored; exit_code=1, summary=summary),
            nothing,
            base;
            notes=summary,
        )
    end
end

const CLOSE_ENCOUNTER_CARTESIAN_METRICS = (
    :integration_status,
    :achieved_final_time,
    :final_time_residual,
    :maximum_pair_relative_position_error,
    :maximum_pair_relative_velocity_error,
    :maximum_full_state_error,
    :final_pair_relative_position_error,
    :final_pair_relative_velocity_error,
    :final_full_state_error,
    :dense_periapsis_time_error,
    :dense_periapsis_separation_error,
    :maximum_relative_energy_drift,
    :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift,
    :maximum_center_of_mass_residual,
    :minimum_sampled_pair_separation,
)

function _close_cartesian_validation_configuration(configuration)
    ValidationConfiguration(
        solver=:accurate,
        relative_tolerance=configuration.relative_tolerance,
        absolute_tolerance=configuration.absolute_tolerance,
        time_interval=CLOSE_ENCOUNTER_INTERVAL,
        sampling="step=0.002",
        selected_pair=CLOSE_ENCOUNTER_SELECTED_PAIR,
        thresholds=(
            ValidationParameter(:entry_threshold, CLOSE_ENCOUNTER_ENTRY_THRESHOLD),
            ValidationParameter(:exit_threshold, CLOSE_ENCOUNTER_EXIT_THRESHOLD),
        ),
        parameters=(
            ValidationParameter(:algorithm, :Vern9),
            ValidationParameter(:arithmetic, :Float64),
            ValidationParameter(:reference_arithmetic, :BigFloat),
            ValidationParameter(:reference_precision, CLOSE_ENCOUNTER_REFERENCE_PRECISION),
            ValidationParameter(:reference_solver, :extreme),
            ValidationParameter(:reference_tolerance, CLOSE_ENCOUNTER_REFERENCE_TOLERANCE),
            ValidationParameter(:reference_dense_output, true),
            ValidationParameter(:reference_save_everystep, true),
        ),
    )
end

function close_encounter_cartesian_investigation_definition()
    InvestigationDefinition(
        :close_encounter_cartesian_tolerance,
        "Close-encounter Cartesian tolerance series",
        "Reference-localised descriptive Cartesian accuracy and work measurements.",
        close_encounter_case_definition(),
        :tolerance,
        (
            ValidationParameter(:selected_pair, CLOSE_ENCOUNTER_SELECTED_PAIR),
            ValidationParameter(:physical_interval, CLOSE_ENCOUNTER_INTERVAL),
            ValidationParameter(:sample_step, CLOSE_ENCOUNTER_SAMPLE_STEP),
            ValidationParameter(:scientific_algorithm, :Vern9),
            ValidationParameter(:solver_selector, :accurate),
            ValidationParameter(:arithmetic, :Float64),
            ValidationParameter(:reference_arithmetic, :BigFloat),
            ValidationParameter(:reference_precision, CLOSE_ENCOUNTER_REFERENCE_PRECISION),
            ValidationParameter(:reference_solver_selector, :extreme),
            ValidationParameter(:reference_relative_tolerance, CLOSE_ENCOUNTER_REFERENCE_TOLERANCE),
            ValidationParameter(:reference_absolute_tolerance, CLOSE_ENCOUNTER_REFERENCE_TOLERANCE),
            ValidationParameter(:reference_dense_output, true),
            ValidationParameter(:reference_save_everystep, true),
            ValidationParameter(:reference_entry_threshold, CLOSE_ENCOUNTER_ENTRY_THRESHOLD),
            ValidationParameter(:reference_exit_threshold, CLOSE_ENCOUNTER_EXIT_THRESHOLD),
        ),
        CLOSE_ENCOUNTER_CARTESIAN_METRICS,
        (),
        CLOSE_ENCOUNTER_CARTESIAN_DEFINITION_VERSION,
    )
end

function _close_cartesian_metrics(
    base::CloseEncounterCartesianBaseEvidence;
    dense_periapsis=nothing,
)
    errors = base.errors
    conservation = base.conservation
    boundaries = base.reference.boundaries
    common = (
        ValidationMetric(:integration_status, "Integration status", :completed),
        ValidationMetric(:achieved_final_time, "Achieved final time", base.achieved_final_time;
            scale=scale_duration, aggregation=aggregation_final),
        ValidationMetric(:final_time_residual, "Final-time residual", base.final_time_residual;
            scale=scale_duration, aggregation=aggregation_final),
        ValidationMetric(:maximum_pair_relative_position_error, "Maximum pair-relative position error", errors.maximum_position;
            aggregation=aggregation_maximum),
        ValidationMetric(:maximum_pair_relative_velocity_error, "Maximum pair-relative velocity error", errors.maximum_velocity;
            aggregation=aggregation_maximum),
        ValidationMetric(:maximum_full_state_error, "Maximum full-state error", errors.maximum_full_state;
            aggregation=aggregation_maximum),
        ValidationMetric(:final_pair_relative_position_error, "Final pair-relative position error", errors.final_position;
            aggregation=aggregation_final),
        ValidationMetric(:final_pair_relative_velocity_error, "Final pair-relative velocity error", errors.final_velocity;
            aggregation=aggregation_final),
        ValidationMetric(:final_full_state_error, "Final full-state error", errors.final_full_state;
            aggregation=aggregation_final),
        ValidationMetric(:maximum_relative_energy_drift, "Maximum relative energy drift",
            conservation.maximum_relative_energy_drift; scale=scale_relative,
            aggregation=aggregation_maximum),
        ValidationMetric(:maximum_linear_momentum_drift, "Maximum linear-momentum drift",
            conservation.maximum_momentum_drift; aggregation=aggregation_maximum),
        ValidationMetric(:maximum_angular_momentum_drift, "Maximum angular-momentum drift",
            conservation.maximum_angular_momentum_drift; aggregation=aggregation_maximum),
        ValidationMetric(:maximum_center_of_mass_residual, "Maximum centre-of-mass residual",
            conservation.maximum_com_residual; aggregation=aggregation_maximum),
        ValidationMetric(:minimum_sampled_pair_separation, "Minimum sampled pair separation",
            conservation.minimum_separation; aggregation=aggregation_minimum),
    )
    isnothing(dense_periapsis) && return common
    periapsis_metrics = (
        ValidationMetric(:dense_periapsis_time_error, "Dense periapsis time error",
            abs(Float64(dense_periapsis.time - boundaries.periapsis_time));
            scale=scale_duration, aggregation=aggregation_final),
        ValidationMetric(:dense_periapsis_separation_error, "Dense periapsis separation error",
            abs(Float64(dense_periapsis.separation - boundaries.periapsis_separation));
            aggregation=aggregation_final),
    )
    (common[1:9]..., periapsis_metrics..., common[10:end]...)
end

function _close_tolerance_token(tolerance)
    index = findfirst(==(Float64(tolerance)), CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
    isnothing(index) && throw(ArgumentError("Unsupported Cartesian tolerance."))
    ("1e_9", "1e_10", "1e_11", "1e_12", "1e_13")[index]
end

close_encounter_cartesian_performance_benchmark_id(tolerance) =
    Symbol(:close_encounter_cartesian_tolerance_, _close_tolerance_token(tolerance))

function close_encounter_cartesian_performance_definition(configuration)
    PerformanceBenchmarkDefinition(
        close_encounter_cartesian_performance_benchmark_id(configuration.relative_tolerance),
        "Close-encounter Cartesian tolerance point",
        "Float64 Cartesian propagation only.",
        "examples/validation/performance/close_encounter_cartesian_tolerance.jl",
        (:close_encounter, :cartesian, :tolerance),
        (:close_encounter, :investigation_2),
        "1.0.0",
        (:elapsed_time, :solver_statistics, :saved_states),
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md",
    )
end

function close_encounter_cartesian_performance_operation(
    configuration::CloseEncounterCartesianConfiguration;
    runner=ThreeBody3D.simulate,
)
    problem = close_encounter_problem(Float64)
    times = close_encounter_sample_times(problem.tspan)
    () -> begin
        result = runner(
            problem.system,
            problem.u0,
            problem.tspan;
            solver=:accurate,
            reltol=configuration.relative_tolerance,
            abstol=configuration.absolute_tolerance,
            saveat=times,
        )
        last(result.solution.t) == last(problem.tspan) ||
            throw(ErrorException("Timed Cartesian propagation did not reach final time."))
        work = close_encounter_solution_work(result.solution)
        statistics = SolverStatistics(
            accepted_steps=work.accepted_steps,
            rejected_steps=work.rejected_steps,
            rhs_evaluations=work.rhs_evaluations,
            saved_states=work.saved_states,
        )
        PerformanceObservation(solver_statistics=statistics, saved_states=work.saved_states)
    end
end

function close_encounter_cartesian_performance_entry(
    configuration::CloseEncounterCartesianConfiguration;
    policy=StandardBenchmark(),
    performance_directory=joinpath(@__DIR__, "..", "performance"),
)
    PerformanceBenchmarkEntry(
        close_encounter_cartesian_performance_definition(configuration),
        _close_cartesian_validation_configuration(configuration),
        policy,
        joinpath(performance_directory, "close_encounter_cartesian_tolerance.jl"),
    )
end

function decode_close_encounter_cartesian_benchmark_id(id::Symbol)
    for tolerance in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES
        close_encounter_cartesian_performance_benchmark_id(tolerance) == id &&
            return CloseEncounterCartesianConfiguration(tolerance)
    end
    throw(ArgumentError("Unsupported close-encounter Cartesian benchmark ID $(id)."))
end

function _close_cartesian_performance_reports(suite::PerformanceSuiteReport)
    suite.schema_version == VALIDATION_SCHEMA_VERSION ||
        throw(ArgumentError("Performance suite schema version differs."))
    reports = Dict{Symbol,PerformanceBenchmarkReport}()
    for report in suite.benchmarks
        id = report.definition.benchmark_id
        haskey(reports, id) && throw(ArgumentError("Duplicate performance report $id."))
        reports[id] = report
    end
    expected_ids = Tuple(close_encounter_cartesian_performance_benchmark_id(tolerance)
        for tolerance in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
    Set(keys(reports)) == Set(expected_ids) ||
        throw(ArgumentError("Performance suite must contain exactly five approved reports."))
    for tolerance in CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES
        configuration = CloseEncounterCartesianConfiguration(tolerance)
        report = reports[close_encounter_cartesian_performance_benchmark_id(tolerance)]
        _record_fields_equal(report.definition,
            close_encounter_cartesian_performance_definition(configuration)) ||
            throw(ArgumentError("Performance definition differs from the approved point."))
        _record_fields_equal(report.configuration,
            _close_cartesian_validation_configuration(configuration)) ||
            throw(ArgumentError("Performance configuration differs from the approved point."))
        _record_fields_equal(report.policy, StandardBenchmark()) ||
            throw(ArgumentError("Performance policy must be StandardBenchmark."))
        _record_fields_equal(report.environment, suite.environment) ||
            throw(ArgumentError("Performance report environment differs from the suite."))
    end
    reports
end

function _close_combined_execution(direct::ExecutionOutcome, performance::ExecutionOutcome)
    direct.actual == actual_completed ? performance : direct
end

function _close_attempt_notes(attempt, performance)
    parts = String[]
    direct_detail = isnothing(attempt.notes) ? attempt.execution.summary : attempt.notes
    !isnothing(direct_detail) && push!(parts, "Direct execution: $direct_detail")
    !isnothing(performance.execution.summary) &&
        push!(parts, "Performance execution: $(performance.execution.summary)")
    isempty(parts) ? nothing : join(parts, "; ")
end

function close_encounter_cartesian_investigation_series(suite::PerformanceSuiteReport, attempts)
    ordered = Tuple(attempts)
    length(ordered) == length(CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES) ||
        throw(ArgumentError("All five Cartesian tolerance points are required."))
    all(attempt -> attempt isa CloseEncounterCartesianAttempt, ordered) ||
        throw(ArgumentError("Series inputs must be Cartesian attempt records."))
    map(attempt -> attempt.configuration.relative_tolerance, ordered) ==
        CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES ||
        throw(ArgumentError("Cartesian tolerance point order is not approved."))
    references = Any[]
    for (attempt, tolerance) in zip(ordered, CLOSE_ENCOUNTER_CARTESIAN_TOLERANCES)
        attempt.configuration == CloseEncounterCartesianConfiguration(tolerance) ||
            throw(ArgumentError("Attempt configuration differs from its declared point."))
        retained = isnothing(attempt.evidence) ? attempt.partial_evidence : attempt.evidence.base
        !isnothing(retained) && push!(references, retained.reference)
    end
    isempty(references) || all(reference -> reference === first(references), references) ||
        throw(ArgumentError("All measured points must reuse one reference execution."))
    reports = _close_cartesian_performance_reports(suite)
    definition = close_encounter_cartesian_investigation_definition()
    points = map(ordered) do attempt
        configuration = attempt.configuration
        performance = reports[close_encounter_cartesian_performance_benchmark_id(
            configuration.relative_tolerance)]
        base = isnothing(attempt.evidence) ? attempt.partial_evidence : attempt.evidence.base
        metrics = isnothing(base) ? () : _close_cartesian_metrics(
            base;
            dense_periapsis=isnothing(attempt.evidence) ? nothing :
                attempt.evidence.dense_periapsis,
        )
        statistics = isnothing(base) ? nothing : SolverStatistics(
            accepted_steps=base.work.accepted_steps,
            rejected_steps=base.work.rejected_steps,
            rhs_evaluations=base.work.rhs_evaluations,
            saved_states=base.work.saved_states,
        )
        InvestigationMeasurementPoint(
            Symbol(:tolerance_, _close_tolerance_token(configuration.relative_tolerance)),
            definition,
            _close_cartesian_validation_configuration(configuration),
            ValidationParameter(:tolerance, configuration.relative_tolerance),
            suite.environment,
            _close_combined_execution(attempt.execution, performance.execution),
            metrics,
            statistics;
            performance_report=performance,
            supporting_evidence=isnothing(attempt.evidence) ? nothing :
                attempt.evidence.localization,
            notes=_close_attempt_notes(attempt, performance),
        )
    end
    InvestigationMeasurementSeries(
        :close_encounter_cartesian_tolerance,
        definition.title,
        definition.description,
        definition,
        Tuple(points),
    )
end

# Investigation 2 core duration and diagnostic-sampling experiments.

const CORE_DURATION_PERIODS = (1, 2, 5, 10, 20)
const CORE_DURATION_VALUES = (25.0, 50.0, 100.0, 200.0)
const CORE_DIAGNOSTIC_SAVEATS = (0.1, 0.02, 0.004)
const CORE_DURATION_SAMPLING_KINDS = (:duration, :diagnostic_sampling)

struct CoreDurationSamplingConfiguration
    experiment_kind::Symbol
    benchmark_family::Symbol
    algorithm_id::Symbol
    solver_selector::Symbol
    relative_tolerance::Float64
    absolute_tolerance::Float64
    periods::Union{Nothing,Int}
    duration::Union{Nothing,Float64}
    saveat::Float64
    arithmetic::Symbol

    function CoreDurationSamplingConfiguration(kind, family, algorithm, selector,
        reltol, abstol; periods=nothing, duration=nothing, saveat=0.02,
        arithmetic=:Float64)
        kind in CORE_DURATION_SAMPLING_KINDS || throw(ArgumentError("Unsupported core experiment kind."))
        family in CORE_TOLERANCE_FAMILIES || throw(ArgumentError("Unsupported core benchmark family."))
        algorithm == :vern9 && selector == :accurate || throw(ArgumentError(
            "Duration and sampling experiments require Vern9 through :accurate."))
        reltol isa Real && abstol isa Real && isfinite(reltol) && isfinite(abstol) &&
            reltol > 0 && abstol > 0 || throw(ArgumentError("Tolerances must be finite and positive."))
        saveat isa Real && isfinite(saveat) && saveat > 0 || throw(ArgumentError("saveat must be finite and positive."))
        arithmetic == :Float64 || throw(ArgumentError("Only Float64 is approved."))
        if family == :figure_eight
            periods isa Integer && periods > 0 && isnothing(duration) || throw(ArgumentError(
                "Figure-eight requires periods and does not use duration."))
        else
            duration isa Real && isfinite(duration) && duration > 0 && isnothing(periods) ||
                throw(ArgumentError("Hierarchical triple requires duration and does not use periods."))
        end
        expected_tolerance = family == :figure_eight ? 1e-12 : 1e-13
        reltol == abstol == expected_tolerance || throw(ArgumentError(
            "Configuration does not use the approved family tolerance."))
        if kind == :duration
            family == :figure_eight ? periods in CORE_DURATION_PERIODS : duration in CORE_DURATION_VALUES
        else
            saveat in CORE_DIAGNOSTIC_SAVEATS &&
                (family == :figure_eight ? periods == 10 : duration == 100.0)
        end || throw(ArgumentError("Configuration is not an approved duration/sampling point."))
        kind == :duration && saveat != 0.02 && throw(ArgumentError(
            "Duration points require saveat=0.02."))
        new(kind, family, algorithm, selector, Float64(reltol), Float64(abstol),
            isnothing(periods) ? nothing : Int(periods),
            isnothing(duration) ? nothing : Float64(duration), Float64(saveat), arithmetic)
    end
end

function core_duration_sampling_configuration(kind::Symbol, family::Symbol, value)
    tolerance = family == :figure_eight ? 1e-12 : 1e-13
    if kind == :duration
        family == :figure_eight && return CoreDurationSamplingConfiguration(kind, family,
            :vern9, :accurate, tolerance, tolerance; periods=value, saveat=0.02)
        family == :hierarchical_triple && return CoreDurationSamplingConfiguration(kind,
            family, :vern9, :accurate, tolerance, tolerance; duration=value, saveat=0.02)
    elseif kind == :diagnostic_sampling
        family == :figure_eight && return CoreDurationSamplingConfiguration(kind, family,
            :vern9, :accurate, tolerance, tolerance; periods=10, saveat=value)
        family == :hierarchical_triple && return CoreDurationSamplingConfiguration(kind,
            family, :vern9, :accurate, tolerance, tolerance; duration=100.0, saveat=value)
    end
    throw(ArgumentError("Unsupported duration/sampling configuration."))
end

_core_duration_sampling_values(kind, family) = kind == :duration ?
    (family == :figure_eight ? CORE_DURATION_PERIODS : CORE_DURATION_VALUES) :
    CORE_DIAGNOSTIC_SAVEATS

struct CoreBenchmarkObservation{C,R,T,Y,U}
    configuration::C
    report::R
    times::T
    system::Y
    initial_state::U
end

struct CoreDurationSamplingAttempt
    configuration::CoreDurationSamplingConfiguration
    execution::ExecutionOutcome
    evidence::Union{Nothing,CoreBenchmarkObservation}
    notes::Union{Nothing,String}

    function CoreDurationSamplingAttempt(configuration, execution, evidence=nothing; notes=nothing)
        execution isa ExecutionOutcome || throw(ArgumentError("execution must be an ExecutionOutcome."))
        if isnothing(evidence)
            execution.actual in (actual_completed, actual_terminated) && throw(ArgumentError(
                "Completed or terminated outcomes require observation evidence."))
            isnothing(execution.summary) && throw(ArgumentError(
                "An observation outcome without evidence requires a factual execution summary."))
        else
            evidence.configuration == configuration || throw(ArgumentError("Observation configuration differs."))
            status = evidence.report.status
            status in (:completed, :terminated_close_approach) || throw(ArgumentError("Unsupported report status $status."))
            if status == :completed
                execution.actual == actual_completed && isnothing(execution.summary) ||
                    throw(ArgumentError("Completed observation requires a clean completed outcome."))
            else
                execution.actual == actual_terminated && !isnothing(execution.summary) ||
                    throw(ArgumentError("Terminated observation requires a factual terminated outcome."))
            end
        end
        new(configuration, execution, evidence,
            isnothing(notes) ? nothing : _nonempty_string(notes, "notes"))
    end
end

function investigation_2_figure_eight_case_definition()
    ValidationCaseDefinition(
        :figure_eight_parameterized,
        "Parameterized figure-eight core benchmark",
        "Periodic equal-mass figure-eight benchmark propagated for the explicitly recorded integer number of periods.",
        (:periodic_orbit, :conservation, :reference_state),
        (:figure_eight, :core_benchmark, :investigation_2, :parameterized_experiment),
        "examples/validation/figure_eight_benchmark.jl",
        (:standard,), expected_completed, true, "1.0.0",
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md")
end

function investigation_2_hierarchical_triple_case_definition()
    ValidationCaseDefinition(
        :hierarchical_triple_parameterized,
        "Parameterized hierarchical-triple core benchmark",
        "Hierarchical-triple benchmark propagated for the explicitly recorded physical duration.",
        (:hierarchical_system, :conservation, :multiscale),
        (:hierarchical_triple, :core_benchmark, :investigation_2, :parameterized_experiment),
        "examples/validation/hierarchical_triple_benchmark.jl",
        (:standard,), expected_completed, true, "1.0.0",
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md")
end

function run_core_benchmark_observation(configuration::CoreDurationSamplingConfiguration;
    runner=ThreeBody3D._run_validation_benchmark_observation)
    observation = runner(configuration.benchmark_family;
        periods=something(configuration.periods, 1), duration=configuration.duration,
        solver=configuration.solver_selector, saveat=configuration.saveat,
        reltol=configuration.relative_tolerance, abstol=configuration.absolute_tolerance)
    CoreBenchmarkObservation(configuration, observation.report, observation.times,
        observation.system, observation.initial_state)
end

function _validate_core_benchmark_observation(observation::CoreBenchmarkObservation,
    expected::CoreDurationSamplingConfiguration=observation.configuration)
    observation.configuration == expected || throw(ArgumentError("Observation configuration differs from the expected point."))
    value = expected.experiment_kind == :duration ?
        (expected.benchmark_family == :figure_eight ? expected.periods : expected.duration) : expected.saveat
    expected == core_duration_sampling_configuration(expected.experiment_kind,
        expected.benchmark_family, value) || throw(ArgumentError("Observation does not use an approved point configuration."))
    report = observation.report
    _validate_core_report_evidence(report, expected.benchmark_family)
    report.name == expected.benchmark_family || throw(ArgumentError("Report family differs."))
    report.profile == :accurate || throw(ArgumentError("Report profile differs."))
    report.initial_time == 0.0 || throw(ArgumentError("Report initial time differs."))
    expected_final = expected.benchmark_family == :figure_eight ?
        ThreeBody3D.FIGURE_EIGHT_PERIOD * expected.periods : expected.duration
    report.expected_final_time == expected_final || throw(ArgumentError("Expected final time differs."))
    report.status == :completed && report.final_time != expected_final && throw(ArgumentError("Completed report did not reach final time."))
    report.saved_states == length(observation.times) || throw(ArgumentError("Saved-state count differs from saved times."))
    all(count -> count >= 0, (report.accepted_steps, report.rejected_steps,
        report.rhs_evaluations, report.saved_states)) || throw(ArgumentError("Solver-work counts must be nonnegative."))
    observation.system.G isa Float64 && eltype(observation.system.masses) == Float64 ||
        throw(ArgumentError("Observation system must use Float64 arithmetic."))
    eltype(observation.initial_state) == Float64 || throw(ArgumentError("Observation initial state must use Float64 arithmetic."))
    authoritative = expected.benchmark_family == :figure_eight ?
        ThreeBody3D._figure_eight_benchmark_inputs() : ThreeBody3D._hierarchical_triple_benchmark_inputs()
    observation.system.masses == authoritative[1].masses && observation.system.G == authoritative[1].G ||
        throw(ArgumentError("Observation system differs from authoritative inputs."))
    observation.initial_state == authoritative[2] || throw(ArgumentError("Observation initial state differs from authoritative inputs."))
    _validate_core_saved_times(observation.times, report, expected.saveat)
    observation
end

function attempt_core_benchmark_observation(configuration::CoreDurationSamplingConfiguration;
    runner=run_core_benchmark_observation)
    try
        evidence = runner(configuration)
        _validate_core_benchmark_observation(evidence, configuration)
        completed = evidence.report.status == :completed
        outcome = ExecutionOutcome(completed ? actual_completed : actual_terminated;
            exit_code=completed ? 0 : 1,
            summary=completed ? nothing : "Core benchmark reported status $(evidence.report.status).")
        CoreDurationSamplingAttempt(configuration, outcome, evidence; notes=outcome.summary)
    catch exception
        summary = "Core $(configuration.experiment_kind) execution errored: $(sprint(showerror, exception))"
        CoreDurationSamplingAttempt(configuration,
            ExecutionOutcome(actual_errored; exit_code=1, summary); notes=summary)
    end
end

function _core_duration_sampling_validation_configuration(configuration)
    final_time = configuration.benchmark_family == :figure_eight ?
        ThreeBody3D.FIGURE_EIGHT_PERIOD * configuration.periods : configuration.duration
    control = configuration.benchmark_family == :figure_eight ?
        ValidationParameter(:periods, configuration.periods) :
        ValidationParameter(:duration, configuration.duration)
    ValidationConfiguration(solver=configuration.solver_selector,
        relative_tolerance=configuration.relative_tolerance,
        absolute_tolerance=configuration.absolute_tolerance,
        time_interval=(0.0, final_time), sampling="saveat=$(configuration.saveat)",
        parameters=(ValidationParameter(:experiment_kind, configuration.experiment_kind),
            ValidationParameter(:algorithm_id, configuration.algorithm_id),
            ValidationParameter(:solver_selector, configuration.solver_selector), control,
            ValidationParameter(:saveat, configuration.saveat),
            ValidationParameter(:arithmetic, configuration.arithmetic)))
end

function core_duration_sampling_investigation_definition(kind::Symbol, family::Symbol)
    values = _core_duration_sampling_values(kind, family)
    configuration = core_duration_sampling_configuration(kind, family, first(values))
    independent = kind == :duration ? (family == :figure_eight ? :periods : :duration) : :saveat
    common = (ValidationParameter(:experiment_kind, kind),
        ValidationParameter(:algorithm_id, :vern9), ValidationParameter(:solver_selector, :accurate),
        ValidationParameter(:relative_tolerance, configuration.relative_tolerance),
        ValidationParameter(:absolute_tolerance, configuration.absolute_tolerance),
        ValidationParameter(:arithmetic, :Float64))
    fixed_control = kind == :duration ? ValidationParameter(:saveat, 0.02) :
        (family == :figure_eight ? ValidationParameter(:periods, 10) :
         ValidationParameter(:duration, 100.0))
    fixed = (common..., fixed_control)
    InvestigationDefinition(Symbol(family, :_, kind),
        "$(replace(string(family), '_' => ' ')) $(replace(string(kind), '_' => ' ')) series",
        "Descriptive core $(replace(string(kind), '_' => ' ')) experiment.",
        family == :figure_eight ? investigation_2_figure_eight_case_definition() :
            investigation_2_hierarchical_triple_case_definition(),
        independent, fixed, _core_tolerance_metric_ids(family), (), "1.0.0")
end

function _core_duration_sampling_token(kind, family, value)
    values = _core_duration_sampling_values(kind, family)
    index = findfirst(==(value), values)
    isnothing(index) && throw(ArgumentError("Point value is not approved."))
    kind == :diagnostic_sampling && return ("0_1", "0_02", "0_004")[index]
    family == :figure_eight ? string(CORE_DURATION_PERIODS[index]) :
        ("25", "50", "100", "200")[index]
end

function core_duration_sampling_performance_benchmark_id(configuration)
    Symbol(configuration.benchmark_family, :_, configuration.experiment_kind,
        :_vern9_, _core_duration_sampling_token(configuration.experiment_kind,
            configuration.benchmark_family,
            configuration.experiment_kind == :duration ?
                (configuration.benchmark_family == :figure_eight ? configuration.periods : configuration.duration) : configuration.saveat))
end

function core_duration_sampling_performance_definition(configuration)
    PerformanceBenchmarkDefinition(core_duration_sampling_performance_benchmark_id(configuration),
        "Core $(configuration.experiment_kind) performance point",
        "Parameterized timing and deterministic work evidence.",
        "examples/validation/performance/core_duration_sampling_work.jl",
        (:core_integration, configuration.experiment_kind, :solver_work),
        (configuration.benchmark_family, :vern9, :investigation_2), "1.0.0",
        (:elapsed_time, :solver_statistics, :saved_states, :maximum_relative_energy_drift),
        "docs/design/V0_6_INVESTIGATION_2_EXPERIMENTAL_PLAN.md")
end

function core_duration_sampling_performance_operation(configuration; runner=ThreeBody3D.run_validation_benchmark)
    () -> _performance_observation(runner(configuration.benchmark_family;
        periods=something(configuration.periods, 1), duration=configuration.duration,
        solver=configuration.solver_selector, saveat=configuration.saveat,
        reltol=configuration.relative_tolerance, abstol=configuration.absolute_tolerance))
end

function core_duration_sampling_performance_entry(configuration;
    policy=StandardBenchmark(), performance_directory=joinpath(@__DIR__, "..", "performance"))
    PerformanceBenchmarkEntry(core_duration_sampling_performance_definition(configuration),
        _core_duration_sampling_validation_configuration(configuration), policy,
        joinpath(performance_directory, "core_duration_sampling_work.jl"))
end

function decode_core_duration_sampling_benchmark_id(id::Symbol)
    for kind in CORE_DURATION_SAMPLING_KINDS, family in CORE_TOLERANCE_FAMILIES,
        value in _core_duration_sampling_values(kind, family)
        configuration = core_duration_sampling_configuration(kind, family, value)
        core_duration_sampling_performance_benchmark_id(configuration) == id && return configuration
    end
    throw(ArgumentError("Unsupported duration/sampling benchmark ID $id."))
end

function _core_duration_sampling_reports(suite, kind, family)
    expected = Tuple(core_duration_sampling_configuration(kind, family, value)
        for value in _core_duration_sampling_values(kind, family))
    reports = _performance_reports_by_id(suite.benchmarks)
    expected_ids = Tuple(core_duration_sampling_performance_benchmark_id(config) for config in expected)
    Set(keys(reports)) == Set(expected_ids) || throw(ArgumentError("Performance suite does not contain exactly the approved reports."))
    suite.schema_version == VALIDATION_SCHEMA_VERSION || throw(ArgumentError("Performance suite schema differs."))
    for configuration in expected
        report = reports[core_duration_sampling_performance_benchmark_id(configuration)]
        _record_fields_equal(report.definition, core_duration_sampling_performance_definition(configuration)) || throw(ArgumentError("Performance definition differs."))
        _record_fields_equal(report.configuration, _core_duration_sampling_validation_configuration(configuration)) || throw(ArgumentError("Performance configuration differs."))
        _record_fields_equal(report.policy, StandardBenchmark()) || throw(ArgumentError("Performance policy differs."))
        _record_fields_equal(report.environment, suite.environment) || throw(ArgumentError("Performance environment differs."))
    end
    reports
end

function core_duration_sampling_investigation_series(suite::PerformanceSuiteReport, attempts)
    ordered = Tuple(attempts)
    isempty(ordered) && throw(ArgumentError("Attempts are required."))
    all(attempt -> attempt isa CoreDurationSamplingAttempt, ordered) || throw(ArgumentError("Invalid attempt record."))
    kind, family = first(ordered).configuration.experiment_kind, first(ordered).configuration.benchmark_family
    values = _core_duration_sampling_values(kind, family)
    length(ordered) == length(values) || throw(ArgumentError("Every approved point is required."))
    expected = Tuple(core_duration_sampling_configuration(kind, family, value) for value in values)
    map(attempt -> attempt.configuration, ordered) == expected || throw(ArgumentError("Attempt order or configuration differs."))
    reports = _core_duration_sampling_reports(suite, kind, family)
    definition = core_duration_sampling_investigation_definition(kind, family)
    points = map(eachindex(ordered)) do index
        attempt, configuration = ordered[index], expected[index]
        CoreDurationSamplingAttempt(attempt.configuration, attempt.execution,
            attempt.evidence; notes=attempt.notes)
        !isnothing(attempt.evidence) && _validate_core_benchmark_observation(attempt.evidence, configuration)
        report = reports[core_duration_sampling_performance_benchmark_id(configuration)]
        evidence = attempt.evidence
        independent = kind == :duration ? (family == :figure_eight ? configuration.periods : configuration.duration) : configuration.saveat
        metrics = isnothing(evidence) ? () : _core_direct_metrics(evidence)
        statistics = isnothing(evidence) ? nothing : SolverStatistics(
            accepted_steps=evidence.report.accepted_steps, rejected_steps=evidence.report.rejected_steps,
            rhs_evaluations=evidence.report.rhs_evaluations, saved_states=evidence.report.saved_states)
        execution = attempt.execution.actual == actual_completed ? report.execution : attempt.execution
        summaries = String[]
        direct_summary = _core_direct_attempt_detail(attempt)
        !isnothing(direct_summary) && push!(summaries, "Direct execution: $direct_summary")
        !isnothing(report.execution.summary) && push!(summaries,
            "Performance execution: $(report.execution.summary)")
        notes = isempty(summaries) ? nothing : join(summaries, "; ")
        InvestigationMeasurementPoint(Symbol(definition.independent_variable, :_,
            _core_duration_sampling_token(kind, family, independent)), definition,
            _core_duration_sampling_validation_configuration(configuration),
            ValidationParameter(definition.independent_variable, independent), suite.environment,
            execution, metrics, statistics; performance_report=report, notes)
    end
    InvestigationMeasurementSeries(definition.family_id, definition.title,
        definition.description, definition, Tuple(points))
end

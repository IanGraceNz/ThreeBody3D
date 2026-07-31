# Figure-eight adapter for the first Investigation 1 pilot series.

const FIGURE_EIGHT_INVESTIGATION_DEFINITION_VERSION = "1.0.0"
const FIGURE_EIGHT_INVESTIGATION_PROFILES = (:fast, :accurate)
const FIGURE_EIGHT_INVESTIGATION_PERIODS = 10
const FIGURE_EIGHT_INVESTIGATION_SAVEAT = 0.02
const FIGURE_EIGHT_INVESTIGATION_METRICS = (
    :periodicity_error,
    :maximum_relative_energy_drift,
    :maximum_linear_momentum_drift,
    :maximum_angular_momentum_drift,
    :maximum_center_of_mass_residual,
    :minimum_pair_separation,
)

"""Define the fixed-profile figure-eight experiment approved for Investigation 1."""
function figure_eight_profile_investigation_definition()
    InvestigationDefinition(
        :figure_eight_profile,
        "Figure-eight solver-profile comparison",
        "Compare the package-owned fast and accurate solver profiles over the fixed ten-period figure-eight workload.",
        figure_eight_case_definition(),
        :solver_profile,
        (
            ValidationParameter(:periods, FIGURE_EIGHT_INVESTIGATION_PERIODS),
            ValidationParameter(:saveat, FIGURE_EIGHT_INVESTIGATION_SAVEAT),
        ),
        FIGURE_EIGHT_INVESTIGATION_METRICS,
        (),
        FIGURE_EIGHT_INVESTIGATION_DEFINITION_VERSION,
    )
end

function _parameter_value(parameters, parameter_id::Symbol)
    matches = Tuple(parameter for parameter in parameters if parameter.parameter_id == parameter_id)
    length(matches) == 1 || throw(ArgumentError(
        "Configuration must retain exactly one $parameter_id parameter.",
    ))
    first(matches).value
end

function _validate_figure_eight_performance_report(
    report::PerformanceBenchmarkReport,
    profile::Symbol,
)
    expected_definition = figure_eight_accuracy_work_definition(profile)
    _record_fields_equal(report.definition, expected_definition) || throw(ArgumentError(
        "Figure-eight performance benchmark definition does not match profile $profile.",
    ))
    expected_configuration = figure_eight_performance_configuration(
        periods=FIGURE_EIGHT_INVESTIGATION_PERIODS,
        solver=profile,
        saveat=FIGURE_EIGHT_INVESTIGATION_SAVEAT,
    )
    _record_fields_equal(report.configuration, expected_configuration) || throw(ArgumentError(
        "Figure-eight performance configuration does not match the approved fixed controls.",
    ))
    report
end

function _validate_figure_eight_case_result(
    result::ValidationCaseResult,
    environment::ValidationEnvironment,
    profile::Symbol,
)
    _record_fields_equal(result.definition, figure_eight_case_definition()) || throw(ArgumentError(
        "Figure-eight validation benchmark definition or version does not match the approved experiment.",
    ))
    _record_fields_equal(result.environment, environment) || throw(ArgumentError(
        "Figure-eight validation and performance provenance must match.",
    ))
    configuration = result.configuration
    configuration.solver == profile || throw(ArgumentError(
        "Figure-eight validation configuration does not match profile $profile.",
    ))
    expected_interval = figure_eight_performance_configuration(
        periods=FIGURE_EIGHT_INVESTIGATION_PERIODS,
        solver=profile,
        saveat=FIGURE_EIGHT_INVESTIGATION_SAVEAT,
    ).time_interval
    configuration.time_interval == expected_interval || throw(ArgumentError(
        "Figure-eight validation time interval does not match ten periods.",
    ))
    configuration.sampling == "saveat=$(FIGURE_EIGHT_INVESTIGATION_SAVEAT)" || throw(
        ArgumentError("Figure-eight validation sampling does not match the approved saveat."),
    )
    _parameter_value(configuration.parameters, :periods) ==
        FIGURE_EIGHT_INVESTIGATION_PERIODS || throw(ArgumentError(
        "Figure-eight validation period count does not match the approved fixed control.",
    ))
    result
end

function _figure_eight_metrics(result::ValidationCaseResult)
    metrics = Tuple(
        metric for metric_id in FIGURE_EIGHT_INVESTIGATION_METRICS
        for metric in result.metrics if metric.metric_id == metric_id
    )
    metric_ids = map(metric -> metric.metric_id, metrics)
    _unique_identifiers(metric_ids, "figure-eight investigation metrics")
    if result.execution.actual == actual_completed &&
       metric_ids != FIGURE_EIGHT_INVESTIGATION_METRICS
        throw(ArgumentError(
        "Figure-eight validation result does not retain the complete investigation metrics.",
        ))
    end
    metrics
end

function _retained_solver_statistics(
    result::ValidationCaseResult,
    report::PerformanceBenchmarkReport,
)
    !isnothing(result.solver_statistics) && return result.solver_statistics
    isempty(report.samples) && return nothing
    statistics = first(report.samples).solver_statistics
    isnothing(statistics) && return nothing
    all(
        sample -> !isnothing(sample.solver_statistics) &&
                  _record_fields_equal(sample.solver_statistics, statistics),
        report.samples,
    ) || throw(ArgumentError(
        "Retained integer solver statistics differ across performance samples.",
    ))
    statistics
end

"""
Select the measurement point's primary execution outcome.

An unsuccessful core outcome takes precedence. Otherwise the performance
outcome is primary. The complete performance outcome remains retained in the
point's `performance_report`.
"""
function _investigation_execution(
    result::ValidationCaseResult,
    report::PerformanceBenchmarkReport,
)
    result.execution.actual != actual_completed && return result.execution
    report.execution
end

function _investigation_notes(
    result::ValidationCaseResult,
    report::PerformanceBenchmarkReport,
)
    summaries = filter(
        !isnothing,
        (result.execution.summary, report.execution.summary),
    )
    isempty(summaries) ? nothing : join(summaries, "; ")
end

function _figure_eight_investigation_point(
    result::ValidationCaseResult,
    report::PerformanceBenchmarkReport,
    definition::InvestigationDefinition,
    profile::Symbol,
)
    _validate_figure_eight_performance_report(report, profile)
    _validate_figure_eight_case_result(result, report.environment, profile)
    InvestigationMeasurementPoint(
        profile,
        definition,
        report.configuration,
        ValidationParameter(:solver_profile, profile),
        report.environment,
        _investigation_execution(result, report),
        _figure_eight_metrics(result),
        _retained_solver_statistics(result, report);
        performance_report=report,
        notes=_investigation_notes(result, report),
    )
end

function _figure_eight_reports_by_id(reports)
    indexed = Dict{Symbol,PerformanceBenchmarkReport}()
    for report in reports
        benchmark_id = report.definition.benchmark_id
        haskey(indexed, benchmark_id) && throw(ArgumentError(
            "Duplicate performance report for benchmark $benchmark_id.",
        ))
        indexed[benchmark_id] = report
    end
    indexed
end

"""
Build the ordered fast/accurate figure-eight Investigation 1 pilot series.

`case_results` are the existing structured core benchmark results. `suite` is
produced by the existing accuracy-versus-work runner. Unsuccessful execution
outcomes and any evidence retained before them remain factual measurements.
"""
function figure_eight_profile_investigation_series(
    suite::PerformanceSuiteReport,
    case_results,
)
    reports = _figure_eight_reports_by_id(suite.benchmarks)
    normalized_results = Tuple(case_results)
    all(result -> result isa ValidationCaseResult, normalized_results) || throw(
        ArgumentError("case_results must contain ValidationCaseResult records."),
    )
    results = Dict{Symbol,ValidationCaseResult}()
    for result in normalized_results
        profile = result.configuration.solver
        profile isa Symbol || throw(ArgumentError(
            "Every figure-eight case result must declare a solver profile.",
        ))
        haskey(results, profile) && throw(ArgumentError(
            "Duplicate figure-eight case result for profile $profile.",
        ))
        results[profile] = result
    end

    definition = figure_eight_profile_investigation_definition()
    points = map(FIGURE_EIGHT_INVESTIGATION_PROFILES) do profile
        benchmark_id = Symbol("figure_eight_accuracy_work_", profile)
        haskey(reports, benchmark_id) || throw(ArgumentError(
            "Performance suite does not contain benchmark $benchmark_id.",
        ))
        haskey(results, profile) || throw(ArgumentError(
            "Core validation results do not contain profile $profile.",
        ))
        _figure_eight_investigation_point(
            results[profile],
            reports[benchmark_id],
            definition,
            profile,
        )
    end
    InvestigationMeasurementSeries(
        :figure_eight_profile,
        "Figure-eight solver-profile comparison",
        "Ordered Investigation 1 measurements for the fast and accurate solver profiles.",
        definition,
        Tuple(points),
    )
end
